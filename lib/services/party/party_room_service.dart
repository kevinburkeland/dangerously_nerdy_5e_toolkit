import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_purse.dart';
import '../../models/party/party_session_state.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/secure_random.dart';
import '../logging_service.dart';
import '../dice_room_service.dart';
import 'campaign_registry_service.dart';

class CampaignNotFoundException implements Exception {
  final String message;
  CampaignNotFoundException([this.message = 'Campaign not found. Please check code with your DM.']);
  @override
  String toString() => message;
}

class UnauthorizedHostActionException implements Exception {
  final String message;
  UnauthorizedHostActionException([this.message = 'Unauthorized: DM Passkey required for this administrative action.']);
  @override
  String toString() => message;
}

class ClaimConflictEvent {
  final String roomCode;
  final String lootId;
  final String itemName;
  final String winnerPlayer;
  final String attemptedPlayer;

  const ClaimConflictEvent({
    required this.roomCode,
    required this.lootId,
    required this.itemName,
    required this.winnerPlayer,
    required this.attemptedPlayer,
  });
}

class PurseOverdraftEvent {
  final String roomCode;
  final String denomination;
  final int requestedDeduct;
  final int previousBalance;
  final String playerName;

  const PurseOverdraftEvent({
    required this.roomCode,
    required this.denomination,
    required this.requestedDeduct,
    required this.previousBalance,
    required this.playerName,
  });
}

/// Outbox item for queuing offline sync operations
class PartyOutboxAction {
  final String id;
  final String roomCode;
  final String actionType; // 'addLoot', 'coinDelta', 'claimItem', 'archiveItem'
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  PartyOutboxAction({
    required this.id,
    required this.roomCode,
    required this.actionType,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'roomCode': roomCode,
    'actionType': actionType,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PartyOutboxAction.fromMap(Map<String, dynamic> map) => PartyOutboxAction(
    id: map['id'] as String? ?? '',
    roomCode: map['roomCode'] as String? ?? '',
    actionType: map['actionType'] as String? ?? '',
    payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

/// Central service managing multi-campaign Party Rooms, subcollection streams,
/// offline outbox queueing, passwordless host key authorization, and soft-delete recovery.
class PartyRoomService {
  static const Duration defaultLootExpiration = Duration(days: 30);

  static final PartyRoomService _instance = PartyRoomService._internal();
  factory PartyRoomService() => _instance;

  final CampaignRegistryService _registry;
  final DiceRoomService _diceRoomService;

  PartyRoomService._internal()
      : _registry = CampaignRegistryService(),
        _diceRoomService = DiceRoomService();

  @visibleForTesting
  PartyRoomService.newInstance({
    CampaignRegistryService? registry,
    DiceRoomService? diceRoomService,
  })  : _registry = registry ??
            // ignore: invalid_use_of_visible_for_testing_member
            CampaignRegistryService.newInstance(),
        _diceRoomService = diceRoomService ??
            // ignore: invalid_use_of_visible_for_testing_member
            DiceRoomService.newInstance();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  // Local in-memory store for tests, offline mode, or fallback
  final Map<String, PartySessionState> _localRooms = {};
  final Map<String, Map<String, PartyLootItem>> _localLoot = {};
  final Map<String, List<PartyEvent>> _localEvents = {};

  final Map<String, StreamController<PartySessionState?>> _sessionControllers = {};
  final Map<String, StreamController<List<PartyLootItem>>> _lootControllers = {};
  final Map<String, StreamController<List<PartyEvent>>> _eventControllers = {};

  final StreamController<ClaimConflictEvent> _claimConflictController = StreamController<ClaimConflictEvent>.broadcast();
  Stream<ClaimConflictEvent> get claimConflictStream => _claimConflictController.stream;

  final StreamController<PurseOverdraftEvent> _overdraftController = StreamController<PurseOverdraftEvent>.broadcast();
  Stream<PurseOverdraftEvent> get overdraftStream => _overdraftController.stream;

  // Offline Outbox Queue (roomCode -> list of actions)
  final Map<String, List<PartyOutboxAction>> _outbox = {};
  final ValueNotifier<int> pendingOutboxCount = ValueNotifier<int>(0);

  // =========================================================================
  // 1. EXPLICIT CREATE VS JOIN WORKFLOWS
  // =========================================================================

  /// Explicit Room Creation: Generates fresh room code + private hostKey,
  /// saves DM membership locally, and creates Firestore root document.
  Future<PartySessionState> createCampaign({
    required String campaignName,
    required String playerName,
    String? customRoomCode,
  }) async {
    final cleanName = campaignName.trim().isEmpty ? 'My 5e Campaign' : campaignName.trim();
    final cleanPlayer = playerName.trim().isEmpty ? 'DM' : playerName.trim();
    final roomCode = customRoomCode?.trim().toUpperCase() ?? CryptoUtils.generateRoomCode();
    final hostKey = CryptoUtils.generateHostKey();
    final hostKeyHash = CryptoUtils.sha256Hex(hostKey);

    final now = DateTime.now();
    final expiresAt = now.add(defaultLootExpiration);

    final session = PartySessionState(
      roomCode: roomCode,
      campaignName: cleanName,
      hostKeyHash: hostKeyHash,
      partyPurse: const PartyPurse(),
      activePlayers: [cleanPlayer],
      version: 1,
      lastUpdated: now,
      expiresAt: expiresAt,
    );

    // 1. Save host membership in local registry with private hostKey
    final membership = CampaignMembership(
      roomCode: roomCode,
      campaignName: cleanName,
      role: CampaignRole.host,
      hostKey: hostKey,
      characterId: cleanPlayer,
      lastPlayed: now,
    );
    await _registry.saveMembership(membership);
    await _registry.setActiveCampaign(membership);

    // 2. Write to Firestore if available
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomCode);
        await docRef.set(session.toMap(), SetOptions(merge: true));
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Failed to write new room $roomCode to Firestore; fallback to local',
        );
      }
    }

    // 3. Update local in-memory state
    _localRooms[roomCode] = session;
    _localLoot[roomCode] = {};
    _localEvents[roomCode] = [];
    _emitSession(roomCode);

    // 4. Log initial event
    await logEvent(
      roomCode: roomCode,
      type: 'roomCreate',
      playerName: cleanPlayer,
      details: 'Campaign "$cleanName" created by $cleanPlayer (DM).',
    );

    // 5. Connect dice room service
    _diceRoomService.joinRoom(roomCode, cleanPlayer);

    return session;
  }

  /// Explicit Room Join:
  /// 1. If exists in Firestore -> Join session, register as player (or preserve DM role).
  /// 2. If NOT in Firestore BUT exists in local registry with valid hostKey -> Rehydrate.
  /// 3. If NOT in Firestore AND NO local record -> Throw CampaignNotFoundException (Zero Ghost Documents).
  Future<PartySessionState> joinCampaign({
    required String roomCode,
    required String playerName,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase().replaceAll(' ', '');
    final cleanPlayer = playerName.trim().isEmpty ? 'Adventurer' : playerName.trim();

    if (cleanCode.isEmpty) {
      throw CampaignNotFoundException('Please enter a valid room code.');
    }

    // Support both prefixed (ROOM-A1B2C3) and raw 6-character (A1B2C3) formats interchangeably
    final codeCandidates = <String>{
      cleanCode,
      if (cleanCode.startsWith('ROOM-')) cleanCode.replaceFirst('ROOM-', '') else 'ROOM-$cleanCode',
      if (cleanCode.startsWith('ROOM_')) cleanCode.replaceFirst('ROOM_', '') else 'ROOM_$cleanCode',
    }.toList();

    PartySessionState? cloudSession;
    String matchedCode = cleanCode;

    if (isFirebaseAvailable) {
      for (final code in codeCandidates) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(code);
          final snapshot = await docRef.get();
          if (snapshot.exists && snapshot.data() != null) {
            cloudSession = PartySessionState.fromMap(snapshot.data()!);
            matchedCode = code;
            break;
          }
        } catch (e, stackTrace) {
          LoggingService().logNonFatal(
            e,
            stackTrace,
            reason: 'Firestore check failed for room $code; fallback to local check',
          );
        }
      }
    }

    // In-memory lookup for testing/offline
    if (cloudSession == null) {
      for (final code in codeCandidates) {
        if (_localRooms.containsKey(code)) {
          cloudSession = _localRooms[code];
          matchedCode = code;
          break;
        }
      }
    }

    // Case 1: Room exists in Cloud / In-Memory
    if (cloudSession != null) {
      final existingMembership = _registry.getMembership(matchedCode);
      final role = existingMembership?.role ?? CampaignRole.player;
      final hostKey = existingMembership?.hostKey;

      final membership = CampaignMembership(
        roomCode: matchedCode,
        campaignName: cloudSession.campaignName,
        role: role,
        hostKey: hostKey,
        characterId: cleanPlayer,
        lastPlayed: DateTime.now(),
      );
      await _registry.saveMembership(membership);
      await _registry.setActiveCampaign(membership);

      // Add player to active players list if not present
      if (!cloudSession.activePlayers.contains(cleanPlayer)) {
        final updatedPlayers = [...cloudSession.activePlayers, cleanPlayer];
        final updatedSession = cloudSession.copyWith(
          activePlayers: updatedPlayers,
          version: cloudSession.version + 1,
          lastUpdated: DateTime.now(),
        );
        _localRooms[matchedCode] = updatedSession;
        if (isFirebaseAvailable) {
          try {
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(matchedCode)
                .update({
              'activePlayers': FieldValue.arrayUnion([cleanPlayer]),
              'version': FieldValue.increment(1),
              'lastUpdated': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            // Non-critical player union error
          }
        }
        cloudSession = updatedSession;
      }

      _localRooms[matchedCode] = cloudSession;
      _emitSession(matchedCode);
      _diceRoomService.joinRoom(matchedCode, cleanPlayer);

      // Flush any pending outbox items
      unawaited(flushOutbox(matchedCode));

      return cloudSession;
    }

    // Case 2: Room not found in Cloud, BUT exists locally with a valid hostKey (Dormant TTL expired)
    for (final code in codeCandidates) {
      final localRecord = _registry.getMembership(code);
      if (localRecord != null && localRecord.hasHostKey) {
        return await rehydrateCampaign(
          roomCode: code,
          hostKey: localRecord.hostKey!,
          playerName: cleanPlayer,
          campaignName: localRecord.campaignName,
        );
      }
    }

    // Case 3: Does NOT exist anywhere -> Reject without creating documents
    throw CampaignNotFoundException('Campaign not found. Please check code with your DM.');
  }

  // =========================================================================
  // 2. REHYDRATION & TTL RENEWAL
  // =========================================================================

  /// Rehydrates an expired/dormant campaign back to Firestore with a fresh 30-day lease
  Future<PartySessionState> rehydrateCampaign({
    required String roomCode,
    required String hostKey,
    required String playerName,
    String? campaignName,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase();
    final hostKeyHash = CryptoUtils.sha256Hex(hostKey);
    final now = DateTime.now();
    final expiresAt = now.add(defaultLootExpiration);

    // Retrieve any locally cached session or construct fresh rehydration state
    final existing = _localRooms[cleanCode];
    final cName = campaignName ?? existing?.campaignName ?? 'Rehydrated Campaign';

    final rehydrated = PartySessionState(
      roomCode: cleanCode,
      campaignName: cName,
      hostKeyHash: hostKeyHash,
      partyPurse: existing?.partyPurse ?? const PartyPurse(),
      activePlayers: [playerName],
      version: (existing?.version ?? 0) + 1,
      lastUpdated: now,
      expiresAt: expiresAt,
    );

    _localRooms[cleanCode] = rehydrated;
    _emitSession(cleanCode);

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(cleanCode);
        await docRef.set(rehydrated.toMap(), SetOptions(merge: true));

        // Also re-publish local loot items if any exist
        final lootMap = _localLoot[cleanCode] ?? {};
        if (lootMap.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final item in lootMap.values) {
            final lootDoc = docRef.collection('loot').doc(item.id);
            batch.set(lootDoc, item.toMap());
          }
          await batch.commit();
        }
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Failed to rehydrate room $cleanCode in Firestore',
        );
      }
    }

    // Update local membership
    final membership = CampaignMembership(
      roomCode: cleanCode,
      campaignName: cName,
      role: CampaignRole.host,
      hostKey: hostKey,
      characterId: playerName,
      lastPlayed: now,
    );
    await _registry.saveMembership(membership);
    await _registry.setActiveCampaign(membership);

    await logEvent(
      roomCode: cleanCode,
      type: 'roomRehydrate',
      playerName: playerName,
      details: 'Campaign rehydrated and renewed with fresh 30-day cloud lease by DM ($playerName).',
    );

    _diceRoomService.joinRoom(cleanCode, playerName);
    return rehydrated;
  }

  // =========================================================================
  // 3. SUBCOLLECTION-BASED STREAMING
  // =========================================================================

  /// Stream root session state
  Stream<PartySessionState?> streamSession(String roomCode) {
    final clean = roomCode.trim().toUpperCase();

    if (isFirebaseAvailable) {
      try {
        return FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .snapshots()
            .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          final state = PartySessionState.fromMap(snap.data()!);
          _localRooms[clean] = state;
          return state;
        }).handleError((e, st) {
          LoggingService().logNonFatal(e, st, reason: 'streamSession error for $clean');
          return _localRooms[clean];
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore streamSession init failed for $clean');
      }
    }

    final controller = _sessionControllers.putIfAbsent(
      clean,
      () => StreamController<PartySessionState?>.broadcast(),
    );
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(_localRooms[clean]);
      }
    });
    return controller.stream;
  }

  /// Stream loot items from /rooms/{roomCode}/loot/{lootId}
  Stream<List<PartyLootItem>> streamLoot(String roomCode, {bool includeArchived = false}) {
    final clean = roomCode.trim().toUpperCase();

    if (isFirebaseAvailable) {
      try {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot');

        if (!includeArchived) {
          query = query.where('isArchived', isEqualTo: false);
        }

        return query.snapshots().map((snapshot) {
          final items = snapshot.docs.map((d) => PartyLootItem.fromMap(d.data())).toList();
          final lootMap = _localLoot.putIfAbsent(clean, () => {});
          for (final item in items) {
            lootMap[item.id] = item;
          }
          return items;
        }).handleError((e, st) {
          LoggingService().logNonFatal(e, st, reason: 'streamLoot error for $clean');
          final list = _localLoot[clean]?.values.toList() ?? [];
          return includeArchived ? list : list.where((i) => !i.isArchived).toList();
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore streamLoot init failed for $clean');
      }
    }

    final controller = _lootControllers.putIfAbsent(
      clean,
      () => StreamController<List<PartyLootItem>>.broadcast(),
    );
    Future.microtask(() {
      if (!controller.isClosed) {
        final list = _localLoot[clean]?.values.toList() ?? [];
        controller.add(includeArchived ? list : list.where((i) => !i.isArchived).toList());
      }
    });
    return controller.stream;
  }

  /// Stream immutable audit events from /rooms/{roomCode}/events/{eventId}
  Stream<List<PartyEvent>> streamEvents(String roomCode) {
    final clean = roomCode.trim().toUpperCase();

    if (isFirebaseAvailable) {
      try {
        return FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('events')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots()
            .map((snap) {
          final events = snap.docs.map((d) => PartyEvent.fromMap(d.data())).toList();
          _localEvents[clean] = events;
          return events;
        }).handleError((e, st) {
          LoggingService().logNonFatal(e, st, reason: 'streamEvents error for $clean');
          return _localEvents[clean] ?? [];
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore streamEvents init failed for $clean');
      }
    }

    final controller = _eventControllers.putIfAbsent(
      clean,
      () => StreamController<List<PartyEvent>>.broadcast(),
    );
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(_localEvents[clean] ?? []);
      }
    });
    return controller.stream;
  }

  // =========================================================================
  // 3.5 CHARACTER ROSTER & ACTIVE PLAYER SESSIONS
  // =========================================================================

  /// Assigns an active character/player name to the current local session and room
  Future<void> setActiveCharacter({
    required String roomCode,
    required String characterName,
    bool updateRegistryDefault = true,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedName = characterName.trim();
    if (trimmedName.isEmpty) return;

    // Update local membership in registry
    if (updateRegistryDefault) {
      final membership = _registry.getMembership(clean);
      if (membership != null) {
        await _registry.saveMembership(membership.copyWith(
          characterId: trimmedName,
          lastPlayed: DateTime.now(),
        ));
      }
    }

    // In-memory session state update
    var current = _localRooms[clean];
    if (current == null) {
      final membership = _registry.getMembership(clean);
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [trimmedName],
        characterRoster: [trimmedName],
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
      _localRooms[clean] = current;
      _emitSession(clean);
    } else {
      final updatedPlayers = List<String>.from(current.activePlayers);
      if (!updatedPlayers.contains(trimmedName)) {
        updatedPlayers.add(trimmedName);
      }
      _localRooms[clean] = current.copyWith(
        activePlayers: updatedPlayers,
        lastUpdated: DateTime.now(),
      );
      _emitSession(clean);
    }

    await logEvent(
      roomCode: clean,
      type: 'playerJoin',
      playerName: trimmedName,
      details: '$trimmedName is now active in the campaign session',
    );

    // Firestore update
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.update({
          'activePlayers': FieldValue.arrayUnion([trimmedName]),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore setActiveCharacter failed for $clean');
      }
    }
  }

  /// Adds a player/character name to the shared campaign roster
  Future<void> addCharacterToRoster({
    required String roomCode,
    required String characterName,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmed = characterName.trim();
    if (trimmed.isEmpty) return;

    // In-memory update
    var current = _localRooms[clean];
    if (current == null) {
      final membership = _registry.getMembership(clean);
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [playerName],
        characterRoster: [trimmed],
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
      _localRooms[clean] = current;
      _emitSession(clean);
    } else {
      final updatedRoster = List<String>.from(current.characterRoster);
      if (!updatedRoster.contains(trimmed)) {
        updatedRoster.add(trimmed);
      }
      _localRooms[clean] = current.copyWith(
        characterRoster: updatedRoster,
        lastUpdated: DateTime.now(),
      );
      _emitSession(clean);
    }

    await logEvent(
      roomCode: clean,
      type: 'rosterUpdate',
      playerName: playerName,
      details: '$playerName added "$trimmed" to the party roster',
    );

    // Firestore update
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.update({
          'characterRoster': FieldValue.arrayUnion([trimmed]),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore addCharacterToRoster failed for $clean');
      }
    }
  }

  /// Removes a player/character name from the shared campaign roster
  Future<void> removeCharacterFromRoster({
    required String roomCode,
    required String characterName,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmed = characterName.trim();

    // In-memory update
    var current = _localRooms[clean];
    if (current != null) {
      final updatedRoster = List<String>.from(current.characterRoster)..remove(trimmed);
      final updatedPurses = Map<String, PartyPurse>.from(current.memberPurses);
      var updatedPartyPurse = current.partyPurse;

      // Transfer any remaining personal coins of the deleted character into the party reserve
      final deletedPurse = updatedPurses.remove(trimmed);
      if (deletedPurse != null && !deletedPurse.isEmpty) {
        updatedPartyPurse = updatedPartyPurse.add(deletedPurse);
      }

      final updatedSession = current.copyWith(
        characterRoster: updatedRoster,
        memberPurses: updatedPurses,
        partyPurse: updatedPartyPurse,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);

      final transferredSuffix = (deletedPurse != null && !deletedPurse.isEmpty)
          ? ' (transferred ~${deletedPurse.totalGpEquivalent.toStringAsFixed(1)} GP to Party Reserve)'
          : '';
      await logEvent(
        roomCode: clean,
        type: 'rosterUpdate',
        playerName: playerName,
        details: '$playerName removed "$trimmed" from the party roster$transferredSuffix',
      );

      // Firestore update
      if (isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
          await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore removeCharacterFromRoster failed for $clean');
        }
      }
    }
  }

  /// Updates the complete campaign character roster
  Future<void> updateCharacterRoster({
    required String roomCode,
    required List<String> roster,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final cleanedRoster = roster.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

    // In-memory update
    var current = _localRooms[clean];
    if (current != null) {
      final updatedPurses = Map<String, PartyPurse>.from(current.memberPurses);
      var updatedPartyPurse = current.partyPurse;

      // Clean up purses of any characters no longer in roster
      final removedKeys = updatedPurses.keys.where((k) => !cleanedRoster.contains(k)).toList();
      for (final removedKey in removedKeys) {
        final deletedPurse = updatedPurses.remove(removedKey);
        if (deletedPurse != null && !deletedPurse.isEmpty) {
          updatedPartyPurse = updatedPartyPurse.add(deletedPurse);
        }
      }

      final updatedSession = current.copyWith(
        characterRoster: cleanedRoster,
        memberPurses: updatedPurses,
        partyPurse: updatedPartyPurse,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);

      await logEvent(
        roomCode: clean,
        type: 'rosterUpdate',
        playerName: playerName,
        details: '$playerName updated the party roster (${cleanedRoster.length} members)',
      );

      // Firestore update
      if (isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
          await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore updateCharacterRoster failed for $clean');
        }
      }
    }
  }

  // =========================================================================
  // 4. ATOMIC COIN OPERATIONS & MERGING
  // =========================================================================

  /// Atomically deposits coins to the party purse via FieldValue.increment
  Future<void> depositCoins({
    required String roomCode,
    required String playerName,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String? note,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // In-memory update
    var current = _localRooms[clean];
    if (current == null) {
      final membership = _registry.getMembership(clean);
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [playerName],
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
    }
    final updatedPurse = current.partyPurse.depositCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);
    _localRooms[clean] = current.copyWith(
      partyPurse: updatedPurse,
      version: current.version + 1,
      lastUpdated: DateTime.now(),
    );
    _emitSession(clean);

    // Audit Event
    final coinParts = <String>[];
    if (pp > 0) coinParts.add('+$pp PP');
    if (gp > 0) coinParts.add('+$gp GP');
    if (ep > 0) coinParts.add('+$ep EP');
    if (sp > 0) coinParts.add('+$sp SP');
    if (cp > 0) coinParts.add('+$cp CP');
    final desc = coinParts.join(', ') + (note != null && note.isNotEmpty ? ' ($note)' : '');

    await logEvent(
      roomCode: clean,
      type: 'coinDeposit',
      playerName: playerName,
      details: '$playerName deposited $desc',
    );

    // Firestore atomic increment
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.update({
          'partyPurse.cp': FieldValue.increment(cp),
          'partyPurse.sp': FieldValue.increment(sp),
          'partyPurse.ep': FieldValue.increment(ep),
          'partyPurse.gp': FieldValue.increment(gp),
          'partyPurse.pp': FieldValue.increment(pp),
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore coin deposit failed; queuing outbox');
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_coin_${DateTime.now().millisecondsSinceEpoch}',
          roomCode: clean,
          actionType: 'coinDeposit',
          payload: {'cp': cp, 'sp': sp, 'ep': ep, 'gp': gp, 'pp': pp},
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Atomically withdraws coins from the party purse
  Future<void> withdrawCoins({
    required String roomCode,
    required String playerName,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    String? note,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // In-memory update
    var current = _localRooms[clean];
    if (current == null) {
      final membership = _registry.getMembership(clean);
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [playerName],
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
    }

    // Detect overdrafts
    final overdrafts = <String>[];
    if (pp > current.partyPurse.pp) {
      overdrafts.add('PP (tried -$pp, had ${current.partyPurse.pp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'PP',
        requestedDeduct: pp,
        previousBalance: current.partyPurse.pp,
        playerName: playerName,
      ));
    }
    if (gp > current.partyPurse.gp) {
      overdrafts.add('GP (tried -$gp, had ${current.partyPurse.gp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'GP',
        requestedDeduct: gp,
        previousBalance: current.partyPurse.gp,
        playerName: playerName,
      ));
    }
    if (ep > current.partyPurse.ep) {
      overdrafts.add('EP (tried -$ep, had ${current.partyPurse.ep})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'EP',
        requestedDeduct: ep,
        previousBalance: current.partyPurse.ep,
        playerName: playerName,
      ));
    }
    if (sp > current.partyPurse.sp) {
      overdrafts.add('SP (tried -$sp, had ${current.partyPurse.sp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'SP',
        requestedDeduct: sp,
        previousBalance: current.partyPurse.sp,
        playerName: playerName,
      ));
    }
    if (cp > current.partyPurse.cp) {
      overdrafts.add('CP (tried -$cp, had ${current.partyPurse.cp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'CP',
        requestedDeduct: cp,
        previousBalance: current.partyPurse.cp,
        playerName: playerName,
      ));
    }

    final updatedPurse = current.partyPurse.withdrawCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);
    _localRooms[clean] = current.copyWith(
      partyPurse: updatedPurse,
      version: current.version + 1,
      lastUpdated: DateTime.now(),
    );
    _emitSession(clean);

    // Audit Event
    final coinParts = <String>[];
    if (pp > 0) coinParts.add('-$pp PP');
    if (gp > 0) coinParts.add('-$gp GP');
    if (ep > 0) coinParts.add('-$ep EP');
    if (sp > 0) coinParts.add('-$sp SP');
    if (cp > 0) coinParts.add('-$cp CP');
    final desc = coinParts.join(', ') + (note != null && note.isNotEmpty ? ' ($note)' : '');

    await logEvent(
      roomCode: clean,
      type: 'coinWithdraw',
      playerName: playerName,
      details: '$playerName withdrew $desc',
    );

    if (overdrafts.isNotEmpty) {
      await logEvent(
        roomCode: clean,
        type: 'purseOverdraftWarning',
        playerName: playerName,
        details: 'Purse overdraft: ${overdrafts.join(', ')} clamped to 0 after spend by $playerName',
      );
    }

    // Firestore atomic decrement
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.update({
          'partyPurse.cp': FieldValue.increment(-cp),
          'partyPurse.sp': FieldValue.increment(-sp),
          'partyPurse.ep': FieldValue.increment(-ep),
          'partyPurse.gp': FieldValue.increment(-gp),
          'partyPurse.pp': FieldValue.increment(-pp),
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore coin withdraw failed; queuing outbox');
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_coin_w_${DateTime.now().millisecondsSinceEpoch}',
          roomCode: clean,
          actionType: 'coinWithdraw',
          payload: {'cp': -cp, 'sp': -sp, 'ep': -ep, 'gp': -gp, 'pp': -pp},
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Disperses coins/valuables among selected party member stores, with an optional share for the party reserve.
  Future<void> disperseCoinsToParty({
    required String roomCode,
    required PartyPurse purseToDisperse,
    required List<String> recipientCharacters,
    required String performedBy,
    bool includePartyReserve = true,
    double liquidatedGemsAndArtGp = 0.0,
    bool includeLiquidatedInSplit = false,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final recipients = recipientCharacters.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (recipients.isEmpty && !includePartyReserve) return;

    final shareCount = recipients.length + (includePartyReserve ? 1 : 0);
    if (shareCount <= 0) return;

    var current = _localRooms[clean];
    if (current == null) {
      final membership = _registry.getMembership(clean);
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [performedBy],
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
    }

    final Map<String, PartyPurse> updatedMemberPurses = Map.from(current.memberPurses);
    PartyPurse updatedPartyPurse = current.partyPurse;

    if (includeLiquidatedInSplit && liquidatedGemsAndArtGp > 0) {
      // Liquidate coins + gems/art into GP equivalent split
      final totalGp = purseToDisperse.totalGpEquivalent + liquidatedGemsAndArtGp;
      final perShareGp = (totalGp / shareCount).floor();
      final remainderGp = (totalGp - (perShareGp * shareCount)).round();

      for (final recipient in recipients) {
        final prev = updatedMemberPurses[recipient] ?? const PartyPurse();
        updatedMemberPurses[recipient] = prev.depositCoins(gp: perShareGp);
      }

      if (includePartyReserve) {
        updatedPartyPurse = updatedPartyPurse.depositCoins(gp: perShareGp + remainderGp);
      } else if (remainderGp > 0) {
        updatedPartyPurse = updatedPartyPurse.depositCoins(gp: remainderGp);
      }
    } else {
      // Even denomination split across PP, GP, EP, SP, CP
      final ppPerShare = purseToDisperse.pp ~/ shareCount;
      final gpPerShare = purseToDisperse.gp ~/ shareCount;
      final epPerShare = purseToDisperse.ep ~/ shareCount;
      final spPerShare = purseToDisperse.sp ~/ shareCount;
      final cpPerShare = purseToDisperse.cp ~/ shareCount;

      final ppRem = purseToDisperse.pp % shareCount;
      final gpRem = purseToDisperse.gp % shareCount;
      final epRem = purseToDisperse.ep % shareCount;
      final spRem = purseToDisperse.sp % shareCount;
      final cpRem = purseToDisperse.cp % shareCount;

      for (final recipient in recipients) {
        final prev = updatedMemberPurses[recipient] ?? const PartyPurse();
        updatedMemberPurses[recipient] = prev.depositCoins(
          pp: ppPerShare,
          gp: gpPerShare,
          ep: epPerShare,
          sp: spPerShare,
          cp: cpPerShare,
        );
      }

      if (includePartyReserve) {
        updatedPartyPurse = updatedPartyPurse.depositCoins(
          pp: ppPerShare + ppRem,
          gp: gpPerShare + gpRem,
          ep: epPerShare + epRem,
          sp: spPerShare + spRem,
          cp: cpPerShare + cpRem,
        );
      } else {
        // Remainder always goes to party reserve so nothing is lost
        updatedPartyPurse = updatedPartyPurse.depositCoins(
          pp: ppRem,
          gp: gpRem,
          ep: epRem,
          sp: spRem,
          cp: cpRem,
        );
      }
    }

    final updatedSession = current.copyWith(
      partyPurse: updatedPartyPurse,
      memberPurses: updatedMemberPurses,
      version: current.version + 1,
      lastUpdated: DateTime.now(),
    );

    _localRooms[clean] = updatedSession;
    _emitSession(clean);

    final totalGpVal = purseToDisperse.totalGpEquivalent + (includeLiquidatedInSplit ? liquidatedGemsAndArtGp : 0);
    final reserveSuffix = includePartyReserve ? ' (+ 1 share to Party Reserve)' : '';
    final desc = '$performedBy dispersed ~${totalGpVal.toStringAsFixed(1)} GP across ${recipients.length} characters$reserveSuffix';

    await logEvent(
      roomCode: clean,
      type: 'lootDispersal',
      playerName: performedBy,
      details: desc,
    );

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore disperseCoinsToParty failed for $clean');
      }
    }
  }

  /// Direct deposit/withdraw/update to an individual character's personal coin purse
  Future<void> updateMemberPurse({
    required String roomCode,
    required String characterName,
    required PartyPurse newPurse,
    required String performedBy,
    String? note,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedName = characterName.trim();
    if (trimmedName.isEmpty) return;

    var current = _localRooms[clean];
    if (current != null) {
      final updatedMap = Map<String, PartyPurse>.from(current.memberPurses);
      updatedMap[trimmedName] = newPurse;
      final updatedSession = current.copyWith(
        memberPurses: updatedMap,
        version: current.version + 1,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);

      final noteSuffix = note != null ? ' ($note)' : '';
      await logEvent(
        roomCode: clean,
        type: 'memberPurseUpdate',
        playerName: performedBy,
        details: '$performedBy updated personal purse for $trimmedName (~${newPurse.totalGpEquivalent.toStringAsFixed(1)} GP)$noteSuffix',
      );

      if (isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
          await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore updateMemberPurse failed for $clean');
        }
      }
    }
  }

  /// Transfers coins from personal member store into the shared Party Reserve
  Future<void> transferMemberToReserve({
    required String roomCode,
    required String characterName,
    required String performedBy,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedName = characterName.trim();
    if (trimmedName.isEmpty) return;

    var current = _localRooms[clean];
    if (current != null) {
      final currentMemberPurse = current.getMemberPurse(trimmedName);
      final updatedMemberPurse = currentMemberPurse.withdrawCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);
      final updatedPartyPurse = current.partyPurse.depositCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);

      final updatedMap = Map<String, PartyPurse>.from(current.memberPurses);
      updatedMap[trimmedName] = updatedMemberPurse;

      final updatedSession = current.copyWith(
        partyPurse: updatedPartyPurse,
        memberPurses: updatedMap,
        version: current.version + 1,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);

      final desc = '$performedBy transferred coins from $trimmedName to Party Reserve ($gp GP, $sp SP, $cp CP)';
      await logEvent(
        roomCode: clean,
        type: 'coinTransfer',
        playerName: performedBy,
        details: desc,
      );

      if (isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
          await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore transferMemberToReserve failed for $clean');
        }
      }
    }
  }

  /// Transfers coins from the shared Party Reserve into a personal member store
  Future<void> transferReserveToMember({
    required String roomCode,
    required String characterName,
    required String performedBy,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedName = characterName.trim();
    if (trimmedName.isEmpty) return;

    var current = _localRooms[clean];
    if (current != null) {
      final currentPartyPurse = current.partyPurse;
      final updatedPartyPurse = currentPartyPurse.withdrawCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);
      final currentMemberPurse = current.getMemberPurse(trimmedName);
      final updatedMemberPurse = currentMemberPurse.depositCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);

      final updatedMap = Map<String, PartyPurse>.from(current.memberPurses);
      updatedMap[trimmedName] = updatedMemberPurse;

      final updatedSession = current.copyWith(
        partyPurse: updatedPartyPurse,
        memberPurses: updatedMap,
        version: current.version + 1,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);

      final desc = '$performedBy withdrew coins from Party Reserve to $trimmedName ($gp GP, $sp SP, $cp CP)';
      await logEvent(
        roomCode: clean,
        type: 'coinTransfer',
        playerName: performedBy,
        details: desc,
      );

      if (isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
          await docRef.set(updatedSession.toMap(), SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore transferReserveToMember failed for $clean');
        }
      }
    }
  }

  // =========================================================================
  // 5. LOOT ITEM ACTIONS & SOFT DELETION
  // =========================================================================

  /// Adds a new loot item or hoard drop to /rooms/{roomCode}/loot/{lootId}
  Future<void> addLootItem({
    required String roomCode,
    required String playerName,
    required PartyLootItem item,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // Local in-memory store
    final lootMap = _localLoot.putIfAbsent(clean, () => {});
    lootMap[item.id] = item;
    _emitLoot(clean);

    await logEvent(
      roomCode: clean,
      type: 'itemAdd',
      playerName: playerName,
      details: '$playerName added ${item.count}x "${item.name}" to the vault (${item.gpValue} GP each).',
    );

    // Firestore write
    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot')
            .doc(item.id)
            .set(item.toMap());
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore addLootItem failed; queuing outbox');
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_loot_${item.id}',
          roomCode: clean,
          actionType: 'addLoot',
          payload: item.toMap(),
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Claims or unclaims a loot item with deterministic Last-Write-Wins claim race fallback
  Future<void> claimLootItem({
    required String roomCode,
    required String lootId,
    required String? playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final updated = existing.copyWith(
        claimedByPlayer: playerName,
        clearClaimedByPlayer: playerName == null || playerName.isEmpty,
      );
      lootMap![lootId] = updated;
      _emitLoot(clean);
    }

    final isClaim = playerName != null && playerName.isNotEmpty;
    await logEvent(
      roomCode: clean,
      type: isClaim ? 'itemClaim' : 'itemUnclaim',
      playerName: playerName ?? 'Unclaimed',
      details: isClaim
          ? '$playerName claimed "${existing?.name ?? lootId}".'
          : 'Item "${existing?.name ?? lootId}" was returned to party vault.',
    );

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot')
            .doc(lootId);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(docRef);
          if (snap.exists) {
            final remoteData = snap.data();
            final remoteClaim = remoteData?['claimedByPlayer'] as String?;

            // If someone else already claimed it online while this client was attempting to claim:
            if (playerName != null &&
                playerName.isNotEmpty &&
                remoteClaim != null &&
                remoteClaim.isNotEmpty &&
                remoteClaim != playerName) {
              // Unbind local claim and revert to remote winner
              final remoteWinner = remoteClaim;
              final restored = existing?.copyWith(claimedByPlayer: remoteWinner) ??
                  PartyLootItem.fromMap(remoteData!);
              lootMap?[lootId] = restored;
              _emitLoot(clean);

              final itemName = existing?.name ?? (remoteData?['name'] as String? ?? 'Item');
              await logEvent(
                roomCode: clean,
                type: 'claimConflict',
                playerName: playerName,
                details: 'Claim conflict on "$itemName": assigned to $remoteWinner (first to server)',
              );

              _claimConflictController.add(ClaimConflictEvent(
                roomCode: clean,
                lootId: lootId,
                itemName: itemName,
                winnerPlayer: remoteWinner,
                attemptedPlayer: playerName,
              ));
              return; // Exit transaction without overwriting winner
            }
          }

          tx.update(docRef, {'claimedByPlayer': playerName});
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore claimLootItem failed; queuing outbox');
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_claim_${lootId}_${DateTime.now().millisecondsSinceEpoch}',
          roomCode: clean,
          actionType: 'claimLoot',
          payload: {'lootId': lootId, 'claimedByPlayer': playerName},
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Manually flags an item conflict for testing or offline conflict detection
  void flagItemConflict(String roomCode, String lootId, Map<String, dynamic> remotePayload) {
    final clean = roomCode.trim().toUpperCase();
    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      lootMap![lootId] = existing.copyWith(
        hasConflict: true,
        conflictPayload: remotePayload,
      );
      _emitLoot(clean);
    }
  }

  /// Discards local offline edits and accepts the remote/cloud version
  Future<void> resolveConflictWithCloud({
    required String roomCode,
    required String lootId,
    required String hostKey,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // Verify host authorization
    final session = _localRooms[clean];
    final expectedHash = session?.hostKeyHash;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = CryptoUtils.sha256Hex(hostKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException();
      }
    }

    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null && existing.conflictPayload != null) {
      final cloudItem = PartyLootItem.fromMap(existing.conflictPayload!).copyWith(
        clearConflict: true,
      );
      lootMap![lootId] = cloudItem;
      _emitLoot(clean);

      await logEvent(
        roomCode: clean,
        type: 'conflictResolution',
        playerName: playerName,
        details: 'DM $playerName resolved conflict: accepted Cloud Version for "${cloudItem.name}".',
      );

      if (isFirebaseAvailable) {
        try {
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(clean)
              .collection('loot')
              .doc(lootId)
              .set(cloudItem.toMap());
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore resolveConflictWithCloud failed');
        }
      }
    }
  }

  /// Overwrites the cloud version with local offline edits
  Future<void> resolveConflictWithLocal({
    required String roomCode,
    required String lootId,
    required String hostKey,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // Verify host authorization
    final session = _localRooms[clean];
    final expectedHash = session?.hostKeyHash;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = CryptoUtils.sha256Hex(hostKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException();
      }
    }

    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final resolved = existing.copyWith(clearConflict: true);
      lootMap![lootId] = resolved;
      _emitLoot(clean);

      await logEvent(
        roomCode: clean,
        type: 'conflictResolution',
        playerName: playerName,
        details: 'DM $playerName resolved conflict: overwrote cloud with Local Version of "${resolved.name}".',
      );

      if (isFirebaseAvailable) {
        try {
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(clean)
              .collection('loot')
              .doc(lootId)
              .set(resolved.toMap());
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore resolveConflictWithLocal failed');
        }
      }
    }
  }

  /// Keeps both versions: accepts cloud item and clones local edits as a new item with (Copy)
  Future<void> resolveConflictKeepBoth({
    required String roomCode,
    required String lootId,
    required String hostKey,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // Verify host authorization
    final session = _localRooms[clean];
    final expectedHash = session?.hostKeyHash;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = CryptoUtils.sha256Hex(hostKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException();
      }
    }

    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final cloudItem = existing.conflictPayload != null
          ? PartyLootItem.fromMap(existing.conflictPayload!).copyWith(clearConflict: true)
          : existing.copyWith(clearConflict: true);

      final copyId = '${lootId}_copy_${DateTime.now().millisecondsSinceEpoch}';
      final localCopy = existing.copyWith(
        id: copyId,
        name: '${existing.name} (Copy)',
        clearConflict: true,
      );

      lootMap![lootId] = cloudItem;
      lootMap[copyId] = localCopy;
      _emitLoot(clean);

      await logEvent(
        roomCode: clean,
        type: 'conflictResolution',
        playerName: playerName,
        details: 'DM $playerName resolved conflict: kept both "${cloudItem.name}" and "${localCopy.name}".',
      );

      if (isFirebaseAvailable) {
        try {
          final batch = FirebaseFirestore.instance.batch();
          final roomDoc = FirebaseFirestore.instance.collection('rooms').doc(clean);
          batch.set(roomDoc.collection('loot').doc(lootId), cloudItem.toMap());
          batch.set(roomDoc.collection('loot').doc(copyId), localCopy.toMap());
          await batch.commit();
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Firestore resolveConflictKeepBoth failed');
        }
      }
    }
  }

  /// Toggles attunement on a magic item
  Future<void> toggleAttunement({
    required String roomCode,
    required String lootId,
    required bool isAttuned,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final updated = existing.copyWith(isAttuned: isAttuned);
      lootMap![lootId] = updated;
      _emitLoot(clean);
    }

    await logEvent(
      roomCode: clean,
      type: 'itemAttune',
      playerName: playerName,
      details: '$playerName ${isAttuned ? 'attuned to' : 'broke attunement with'} "${existing?.name ?? lootId}".',
    );

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot')
            .doc(lootId)
            .update({'isAttuned': isAttuned});
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore toggleAttunement failed');
      }
    }
  }

  /// Soft-deletes a loot item (sets isArchived: true, archivedBy, archivedAt)
  Future<void> archiveLootItem({
    required String roomCode,
    required String lootId,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final now = DateTime.now();

    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final updated = existing.copyWith(
        isArchived: true,
        archivedBy: playerName,
        archivedAt: now,
      );
      lootMap![lootId] = updated;
      _emitLoot(clean);
    }

    await logEvent(
      roomCode: clean,
      type: 'itemArchive',
      playerName: playerName,
      details: '$playerName moved "${existing?.name ?? lootId}" to the trash.',
    );

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot')
            .doc(lootId)
            .update({
          'isArchived': true,
          'archivedBy': playerName,
          'archivedAt': now.toIso8601String(),
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore archiveLootItem failed');
      }
    }
  }

  /// Restores a soft-deleted loot item (Requires valid hostKey)
  Future<void> restoreLootItem({
    required String roomCode,
    required String lootId,
    required String hostKey,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();

    // Verify hostKey authorization
    final session = _localRooms[clean];
    final expectedHash = session?.hostKeyHash;
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = CryptoUtils.sha256Hex(hostKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException();
      }
    }

    final lootMap = _localLoot[clean];
    final existing = lootMap?[lootId];
    if (existing != null) {
      final updated = existing.copyWith(
        isArchived: false,
        archivedBy: null,
        archivedAt: null,
      );
      lootMap![lootId] = updated;
      _emitLoot(clean);
    }

    await logEvent(
      roomCode: clean,
      type: 'itemRestore',
      playerName: playerName,
      details: 'DM $playerName restored "${existing?.name ?? lootId}" from trash.',
    );

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('loot')
            .doc(lootId)
            .update({
          'isArchived': false,
          'archivedBy': null,
          'archivedAt': null,
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore restoreLootItem failed');
      }
    }
  }

  // =========================================================================
  // 6. EVENT AUDIT LOGGING
  // =========================================================================

  Future<void> logEvent({
    required String roomCode,
    required String type,
    required String playerName,
    required String details,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}_${secureRandom.nextInt(9999)}';
    final event = PartyEvent(
      id: eventId,
      roomCode: clean,
      type: type,
      playerName: playerName,
      details: details,
      timestamp: DateTime.now(),
    );

    final eventList = _localEvents.putIfAbsent(clean, () => []);
    eventList.insert(0, event);
    _emitEvents(clean);

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .collection('events')
            .doc(eventId)
            .set(event.toMap());
      } catch (e) {
        // Non-fatal event write failure
      }
    }
  }

  // =========================================================================
  // 7. OFFLINE OUTBOX QUEUE & FLUSH
  // =========================================================================

  void _queueOutbox(PartyOutboxAction action) {
    final list = _outbox.putIfAbsent(action.roomCode, () => []);
    list.add(action);
    _updateOutboxCount();
  }

  void _updateOutboxCount() {
    int total = 0;
    for (final actions in _outbox.values) {
      total += actions.length;
    }
    pendingOutboxCount.value = total;
  }

  /// Flushes queued outbox operations to Firestore
  Future<void> flushOutbox(String roomCode) async {
    final clean = roomCode.trim().toUpperCase();
    final pending = _outbox[clean];
    if (pending == null || pending.isEmpty || !isFirebaseAvailable) return;

    final List<PartyOutboxAction> toProcess = List.from(pending);
    final batch = FirebaseFirestore.instance.batch();
    final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);

    for (final action in toProcess) {
      if (action.actionType == 'addLoot') {
        final lootDoc = docRef.collection('loot').doc(action.payload['id'] as String);
        batch.set(lootDoc, action.payload);
      } else if (action.actionType == 'claimLoot') {
        final lootDoc = docRef.collection('loot').doc(action.payload['lootId'] as String);
        batch.update(lootDoc, {'claimedByPlayer': action.payload['claimedByPlayer']});
      } else if (action.actionType == 'coinDeposit' || action.actionType == 'coinWithdraw') {
        final cp = (action.payload['cp'] as num?)?.toInt() ?? 0;
        final sp = (action.payload['sp'] as num?)?.toInt() ?? 0;
        final ep = (action.payload['ep'] as num?)?.toInt() ?? 0;
        final gp = (action.payload['gp'] as num?)?.toInt() ?? 0;
        final pp = (action.payload['pp'] as num?)?.toInt() ?? 0;

        batch.update(docRef, {
          'partyPurse.cp': FieldValue.increment(cp),
          'partyPurse.sp': FieldValue.increment(sp),
          'partyPurse.ep': FieldValue.increment(ep),
          'partyPurse.gp': FieldValue.increment(gp),
          'partyPurse.pp': FieldValue.increment(pp),
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    }

    try {
      await batch.commit();
      pending.removeWhere((a) => toProcess.contains(a));
      _updateOutboxCount();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to flush outbox for room $clean');
    }
  }

  // =========================================================================
  // HELPER EMITTERS
  // =========================================================================

  void _emitSession(String roomCode) {
    final controller = _sessionControllers[roomCode];
    if (controller != null && !controller.isClosed) {
      controller.add(_localRooms[roomCode]);
    }
  }

  void _emitLoot(String roomCode) {
    final controller = _lootControllers[roomCode];
    if (controller != null && !controller.isClosed) {
      final list = _localLoot[roomCode]?.values.toList() ?? [];
      controller.add(list.where((i) => !i.isArchived).toList());
    }
  }

  void _emitEvents(String roomCode) {
    final controller = _eventControllers[roomCode];
    if (controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(_localEvents[roomCode] ?? []));
    }
  }
}
