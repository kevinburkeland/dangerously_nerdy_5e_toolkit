import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_purse.dart';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../models/party/party_session_state.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/secure_random.dart';
import '../logging_service.dart';
import '../dice_room_service.dart';
import '../persistence/character_persistence_service.dart';
import '../persistence/campaign_profile_service.dart';
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
  int retryCount;

  PartyOutboxAction({
    required this.id,
    required this.roomCode,
    required this.actionType,
    required this.payload,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'roomCode': roomCode,
    'actionType': actionType,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PartyOutboxAction.fromMap(Map<String, dynamic> map) => PartyOutboxAction(
    id: map['id'] as String? ?? '',
    roomCode: map['roomCode'] as String? ?? '',
    actionType: map['actionType'] as String? ?? '',
    payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
    retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
  );
}

/// Central service managing multi-campaign Party Rooms, subcollection streams,
/// offline outbox queueing, passwordless host key authorization, and soft-delete recovery.
class PartyRoomService {
  static const Duration defaultLootExpiration = Duration(days: 30);

  static final PartyRoomService _instance = PartyRoomService._internal();
  factory PartyRoomService() => _instance;

  final String localNodeId;
  final CampaignRegistryService _registry;
  final DiceRoomService _diceRoomService;
  final CharacterPersistenceService _characterPersistenceService;
  final CampaignProfileService _campaignProfileService;

  PartyRoomService._internal({String? localNodeId})
      : localNodeId = localNodeId ?? const Uuid().v4(),
        _registry = CampaignRegistryService(),
        _diceRoomService = DiceRoomService(),
        _characterPersistenceService = CharacterPersistenceService(),
        _campaignProfileService = CampaignProfileService();

  @visibleForTesting
  PartyRoomService.newInstance({
    String? localNodeId,
    CampaignRegistryService? registry,
    DiceRoomService? diceRoomService,
    CharacterPersistenceService? characterPersistenceService,
    CampaignProfileService? campaignProfileService,
  })  : localNodeId = localNodeId ?? const Uuid().v4(),
        _registry = registry ??
            // ignore: invalid_use_of_visible_for_testing_member
            CampaignRegistryService.newInstance(),
        _diceRoomService = diceRoomService ??
            // ignore: invalid_use_of_visible_for_testing_member
            DiceRoomService.newInstance(),
        _characterPersistenceService =
            characterPersistenceService ?? CharacterPersistenceService(),
        _campaignProfileService =
            campaignProfileService ?? CampaignProfileService();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  // Local in-memory store for tests, offline mode, or fallback
  final Map<String, PartySessionState> _localRooms = {};
  final Map<String, Map<String, PartyLootItem>> _localLoot = {};
  final Map<String, List<PartyEvent>> _localEvents = {};

  final Map<String, StreamController<PartySessionState?>> _sessionControllers = {};
  final Map<String, StreamSubscription> _sessionSubscriptions = {};
  final Map<String, StreamController<List<PartyLootItem>>> _lootControllers = {};
  final Map<String, StreamController<List<PartyEvent>>> _eventControllers = {};

  final StreamController<ClaimConflictEvent> _claimConflictController = StreamController<ClaimConflictEvent>.broadcast();
  Stream<ClaimConflictEvent> get claimConflictStream => _claimConflictController.stream;

  final StreamController<PurseOverdraftEvent> _overdraftController = StreamController<PurseOverdraftEvent>.broadcast();
  Stream<PurseOverdraftEvent> get overdraftStream => _overdraftController.stream;

  // Offline Outbox Queue (roomCode -> list of actions)
  final Map<String, List<PartyOutboxAction>> _outbox = {};
  final ValueNotifier<int> pendingOutboxCount = ValueNotifier<int>(0);
  Timer? _autoFlushTimer;

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
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_create_${DateTime.now().millisecondsSinceEpoch}',
          roomCode: roomCode,
          actionType: 'createRoom',
          payload: session.toMap(),
          timestamp: DateTime.now(),
        ));
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
  /// 1. If exists in Firestore -> Join session, register as player (or preserve/claim DM role if hostKey provided).
  /// 2. If NOT in Firestore BUT exists with valid hostKey -> Rehydrate.
  /// 3. If NOT in Firestore AND NO valid key/record -> Throw CampaignNotFoundException (Zero Ghost Documents).
  Future<PartySessionState> joinCampaign({
    required String roomCode,
    required String playerName,
    String? hostKey,
    String? characterId,
    Character? characterSnapshot,
    String? existingRosterName,
    bool isNewImport = true,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase().replaceAll(' ', '');
    final cleanPlayer = playerName.trim().isEmpty ? 'Adventurer' : playerName.trim();
    final providedHostKey = hostKey != null && hostKey.trim().isNotEmpty
        ? CryptoUtils.extractHostKey(hostKey)
        : null;

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

      // If not found on immediate check, brief retry with propagation delay
      if (cloudSession == null) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        for (final code in codeCandidates) {
          try {
            final docRef = FirebaseFirestore.instance.collection('rooms').doc(code);
            final snapshot = await docRef.get();
            if (snapshot.exists && snapshot.data() != null) {
              cloudSession = PartySessionState.fromMap(snapshot.data()!);
              matchedCode = code;
              break;
            }
          } catch (_) {}
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

    // Stateless presence check: If root document doesn't exist, check active signaling or relay presence
    if (cloudSession == null && isFirebaseAvailable) {
      for (final code in codeCandidates) {
        try {
          final signals = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(code)
              .collection('nodes')
              .doc('*')
              .collection('signals')
              .limit(1)
              .get();
          if (signals.docs.isNotEmpty) {
            matchedCode = code;
            cloudSession = PartySessionState(
              roomCode: matchedCode,
              campaignName: 'Party Campaign ($matchedCode)',
              hostKeyHash: '',
              partyPurse: const PartyPurse(),
              activePlayers: const [],
              lastUpdated: DateTime.now(),
              expiresAt: DateTime.now().add(defaultLootExpiration),
            );
            break;
          }

          final relays = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(code)
              .collection('relay_messages')
              .limit(1)
              .get();
          if (relays.docs.isNotEmpty) {
            matchedCode = code;
            cloudSession = PartySessionState(
              roomCode: matchedCode,
              campaignName: 'Party Campaign ($matchedCode)',
              hostKeyHash: '',
              partyPurse: const PartyPurse(),
              activePlayers: const [],
              lastUpdated: DateTime.now(),
              expiresAt: DateTime.now().add(defaultLootExpiration),
            );
            break;
          }
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Stateless presence check failed for room $code',
          );
        }
      }
    }

    // Case 1: Room exists in Cloud / In-Memory
    if (cloudSession != null) {
      final existingMembership = _registry.getMembership(matchedCode);

      CampaignRole role = existingMembership?.role ?? CampaignRole.player;
      String? savedHostKey = existingMembership?.hostKey;

      if (providedHostKey != null && providedHostKey.isNotEmpty) {
        final expectedHash = cloudSession.hostKeyHash;
        if (expectedHash.isNotEmpty) {
          final actualHash = CryptoUtils.sha256Hex(providedHostKey);
          if (actualHash != expectedHash) {
            throw UnauthorizedHostActionException('Invalid DM passkey. Please check the code provided by your Dungeon Master.');
          }
        }
        role = CampaignRole.host;
        savedHostKey = providedHostKey;
      }

      final targetCharId = characterId ?? characterSnapshot?.id.slug ?? cleanPlayer;
      final targetRosterName = (existingRosterName != null && existingRosterName.trim().isNotEmpty)
          ? existingRosterName.trim()
          : cleanPlayer;

      final membership = CampaignMembership(
        roomCode: matchedCode,
        campaignName: cloudSession.campaignName,
        role: role,
        hostKey: savedHostKey,
        characterId: targetCharId,
        lastPlayed: DateTime.now(),
      );
      await _registry.saveMembership(membership);
      await _registry.setActiveCampaign(membership);

      var updatedSession = cloudSession;
      final updatedPlayers = List<String>.from(updatedSession.activePlayers);
      if (!updatedPlayers.contains(cleanPlayer)) {
        updatedPlayers.add(cleanPlayer);
      }

      final updatedRoster = List<String>.from(updatedSession.characterRoster);
      if (isNewImport && !updatedRoster.contains(targetRosterName)) {
        updatedRoster.add(targetRosterName);
      }

      final updatedShared = Map<String, Map<String, dynamic>>.from(updatedSession.sharedCharacters);
      final updatedTelemetry = Map<String, CharacterTelemetryDto>.from(updatedSession.partyTelemetry);
      if (characterSnapshot != null) {
        final telemetry = characterSnapshot.toTelemetryDto();
        updatedTelemetry[characterSnapshot.id.slug] = telemetry;
        updatedTelemetry[targetRosterName] = telemetry;
        updatedShared[characterSnapshot.id.slug] = telemetry.toMap();
        updatedShared[targetRosterName] = telemetry.toMap();
        await _characterPersistenceService.saveCharacter(characterSnapshot);

        // Sync with DM profile if active profile matches
        try {
          final activeDmProfile = _campaignProfileService.activeProfile;
          if (activeDmProfile != null) {
            final matchesRoom = activeDmProfile.id == matchedCode ||
                activeDmProfile.name.toLowerCase() == cloudSession.campaignName.toLowerCase();
            if (matchesRoom && !activeDmProfile.partyCharacterIds.contains(characterSnapshot.id.slug)) {
              final updatedPartyIds = [...activeDmProfile.partyCharacterIds, characterSnapshot.id.slug];
              await _campaignProfileService.updateActiveProfile(
                (p) => p.copyWith(partyCharacterIds: updatedPartyIds),
              );
            }
          }
        } catch (_) {}
      }

      final now = DateTime.now();
      final expiresAt = now.add(defaultLootExpiration);

      updatedSession = updatedSession.copyWith(
        activePlayers: updatedPlayers,
        characterRoster: updatedRoster,
        sharedCharacters: updatedShared,
        partyTelemetry: updatedTelemetry,
        version: updatedSession.version + 1,
        lastUpdated: now,
        expiresAt: expiresAt,
      );

      _localRooms[matchedCode] = updatedSession;
      if (isFirebaseAvailable) {
        try {
          final Map<String, dynamic> joinPayload = {
            'roomCode': matchedCode,
            'code': matchedCode,
            'campaignName': updatedSession.campaignName,
            'activePlayers': updatedSession.activePlayers,
            'characterRoster': updatedSession.characterRoster,
            'sharedCharacters': updatedSession.sharedCharacters,
            'partyTelemetry': updatedSession.partyTelemetry.map((k, v) => MapEntry(k, v.toMap())),
            'version': FieldValue.increment(1),
            'lastUpdated': now.toIso8601String(),
            'expiresAt': expiresAt.toIso8601String(),
          };
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(matchedCode)
              .set(joinPayload, SetOptions(merge: true));
        } catch (e) {
          // Non-critical player union error
        }
      }

      _emitSession(matchedCode);
      _diceRoomService.joinRoom(matchedCode, cleanPlayer);

      // Flush any pending outbox items
      unawaited(flushOutbox(matchedCode));

      return updatedSession;
    }

    // Case 2: Room not found in Cloud, BUT exists locally with a valid hostKey (or provided hostKey)
    if (providedHostKey != null && providedHostKey.isNotEmpty) {
      return await rehydrateCampaign(
        roomCode: matchedCode,
        hostKey: providedHostKey,
        playerName: cleanPlayer,
      );
    }

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

  /// Ensures the room stub exists in Firestore and local cache, renewing the 30-day lease whenever called.
  Future<PartySessionState> ensureRoomExists({
    required String roomCode,
    String? campaignName,
    String? hostKey,
    bool isStateless = true,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase().replaceAll(' ', '');
    final now = DateTime.now();
    final expiresAt = now.add(defaultLootExpiration);

    var existing = _localRooms[cleanCode];
    if (existing == null && isFirebaseAvailable) {
      try {
        final doc = await FirebaseFirestore.instance.collection('rooms').doc(cleanCode).get();
        if (doc.exists && doc.data() != null) {
          existing = PartySessionState.fromMap(doc.data()!);
          _localRooms[cleanCode] = existing;
        }
      } catch (_) {}
    }

    final cName = campaignName ?? existing?.campaignName ?? 'Shared Campaign ($cleanCode)';
    final hostKeyHash = hostKey != null && hostKey.isNotEmpty
        ? CryptoUtils.sha256Hex(CryptoUtils.extractHostKey(hostKey))
        : (existing?.hostKeyHash ?? '');

    final session = existing?.copyWith(
          campaignName: cName,
          hostKeyHash: hostKeyHash.isNotEmpty ? hostKeyHash : (existing.hostKeyHash),
          lastUpdated: now,
          expiresAt: expiresAt,
        ) ??
        PartySessionState(
          roomCode: cleanCode,
          campaignName: cName,
          hostKeyHash: hostKeyHash,
          partyPurse: const PartyPurse(),
          activePlayers: const [],
          version: 1,
          lastUpdated: now,
          expiresAt: expiresAt,
        );

    _localRooms[cleanCode] = session;
    _emitSession(cleanCode);

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(cleanCode);
        final Map<String, dynamic> updateData = {
          'roomCode': cleanCode,
          'code': cleanCode,
          'campaignName': cName,
          'isStateless': isStateless,
          'lastUpdated': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        };
        if (hostKeyHash.isNotEmpty) {
          updateData['hostKeyHash'] = hostKeyHash;
        }
        // CRITICAL: NEVER overwrite partyPurse with zeroes on lease renewal/stub touch
        await docRef.set(updateData, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to touch room stub in ensureRoomExists for $cleanCode',
        );
      }
    }

    return session;
  }

  /// Links a player's saved character to a campaign room.
  /// If [isNewImport] is true, adds the character to the shared campaign roster.
  /// If [existingRosterName] is provided, associates with that existing roster name.
  /// Shares character state with the DM via [PartySessionState.sharedCharacters].
  Future<PartySessionState> linkCharacterToCampaign({
    required String roomCode,
    required Character character,
    String? existingRosterName,
    bool isNewImport = true,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final targetName = (existingRosterName != null && existingRosterName.trim().isNotEmpty)
        ? existingRosterName.trim()
        : character.name.trim();

    // 1. Ensure membership is updated with this character's ID
    final existingMembership = _registry.getMembership(clean);
    if (existingMembership != null) {
      final updatedMembership = existingMembership.copyWith(
        characterId: character.id.slug,
        lastPlayed: DateTime.now(),
      );
      await _registry.saveMembership(updatedMembership);
      await _registry.setActiveCampaign(updatedMembership);
    }

    // 2. Persist character locally
    await _characterPersistenceService.saveCharacter(character);

    // 3. Update session
    var current = _localRooms[clean];
    if (current == null && isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        final snapshot = await docRef.get();
        if (snapshot.exists && snapshot.data() != null) {
          current = PartySessionState.fromMap(snapshot.data()!);
        }
      } catch (_) {}
    }

    if (current == null) {
      final membership = _registry.getMembership(clean);
      final telemetry = character.toTelemetryDto();
      current = PartySessionState(
        roomCode: clean,
        campaignName: membership?.campaignName ?? 'Party Campaign',
        hostKeyHash: '',
        partyPurse: const PartyPurse(),
        activePlayers: [targetName],
        characterRoster: [targetName],
        memberPurses: {
          targetName: character.purse,
          character.id.slug: character.purse,
        },
        sharedCharacters: {
          character.id.slug: telemetry.toMap(),
          targetName: telemetry.toMap(),
        },
        partyTelemetry: {
          character.id.slug: telemetry,
          targetName: telemetry,
        },
        version: 1,
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(defaultLootExpiration),
      );
    } else {
      final updatedRoster = List<String>.from(current.characterRoster);
      if (isNewImport && !updatedRoster.contains(targetName)) {
        updatedRoster.add(targetName);
      }
      final telemetry = character.toTelemetryDto();
      final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
      final updatedTelemetry = Map<String, CharacterTelemetryDto>.from(current.partyTelemetry);
      updatedShared[character.id.slug] = telemetry.toMap();
      updatedShared[targetName] = telemetry.toMap();
      updatedTelemetry[character.id.slug] = telemetry;
      updatedTelemetry[targetName] = telemetry;

      final updatedPlayers = List<String>.from(current.activePlayers);
      if (!updatedPlayers.contains(targetName)) {
        updatedPlayers.add(targetName);
      }

      final updatedMemberPurses = Map<String, PartyPurse>.from(current.memberPurses);
      updatedMemberPurses[targetName] = character.purse;
      updatedMemberPurses[character.id.slug] = character.purse;

      current = current.copyWith(
        characterRoster: updatedRoster,
        sharedCharacters: updatedShared,
        partyTelemetry: updatedTelemetry,
        activePlayers: updatedPlayers,
        memberPurses: updatedMemberPurses,
        version: current.version + 1,
        lastUpdated: DateTime.now(),
      );
    }

    _localRooms[clean] = current;
    _emitSession(clean);

    // 4. Sync with DM profile if active profile belongs to this campaign
    try {
      final activeDmProfile = _campaignProfileService.activeProfile;
      if (activeDmProfile != null) {
        final matchesRoom = activeDmProfile.id == clean ||
            activeDmProfile.name.toLowerCase() == current.campaignName.toLowerCase();
        if (matchesRoom && !activeDmProfile.partyCharacterIds.contains(character.id.slug)) {
          final updatedPartyIds = [...activeDmProfile.partyCharacterIds, character.id.slug];
          await _campaignProfileService.updateActiveProfile(
            (p) => p.copyWith(partyCharacterIds: updatedPartyIds),
          );
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed linking character to DM profile');
    }

    // 5. Cloud update: update roster, telemetry, and member purses without clobbering shared party vault
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'activePlayers': current.activePlayers,
          'characterRoster': current.characterRoster,
          'memberPurses': current.memberPurses.map((k, v) => MapEntry(k, v.toMap())),
          'sharedCharacters': current.sharedCharacters,
          'partyTelemetry': current.partyTelemetry.map((k, v) => MapEntry(k, v.toMap())),
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
          'expiresAt': current.expiresAt.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore linkCharacterToCampaign failed for $clean');
      }
    }

    await logEvent(
      roomCode: clean,
      type: 'characterLinked',
      playerName: targetName,
      details: '$targetName (${character.name}) linked to campaign session',
    );

    return current;
  }

  /// Updates real-time telemetry and shared character snapshot for a character in an active room.
  /// Seamlessly synchronizes HP, Temp HP, spell slots, conditions, and death saves across all peers.
  Future<void> updateCharacterTelemetry({
    required String roomCode,
    required Character character,
    String? existingRosterName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final targetName = (existingRosterName != null && existingRosterName.trim().isNotEmpty)
        ? existingRosterName.trim()
        : character.name.trim();

    var current = _localRooms[clean];
    if (current == null && isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        final snapshot = await docRef.get();
        if (snapshot.exists && snapshot.data() != null) {
          current = PartySessionState.fromMap(snapshot.data()!);
        }
      } catch (_) {}
    }

    if (current == null) return;

    final telemetry = character.toTelemetryDto();
    final updatedTelemetry = Map<String, CharacterTelemetryDto>.from(current.partyTelemetry);
    updatedTelemetry[character.id.slug] = telemetry;
    updatedTelemetry[targetName] = telemetry;

    final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
    updatedShared[character.id.slug] = character.toMap();
    updatedShared[targetName] = character.toMap();

    final updatedMemberPurses = Map<String, PartyPurse>.from(current.memberPurses);
    updatedMemberPurses[targetName] = character.purse;
    updatedMemberPurses[character.id.slug] = character.purse;

    final updated = current.copyWith(
      partyTelemetry: updatedTelemetry,
      sharedCharacters: updatedShared,
      memberPurses: updatedMemberPurses,
      lastUpdated: DateTime.now(),
    );

    _localRooms[clean] = updated;
    _emitSession(clean);

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'partyTelemetry': updated.partyTelemetry.map((k, v) => MapEntry(k, v.toMap())),
          'sharedCharacters': updated.sharedCharacters,
          'memberPurses': updated.memberPurses.map((k, v) => MapEntry(k, v.toMap())),
          'lastUpdated': updated.lastUpdated.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore updateCharacterTelemetry failed for $clean');
      }
    }
  }

  /// Validates a DM passkey / host key against a room session and promotes local membership to DM / Co-DM
  Future<CampaignMembership> claimDmRole({
    required String roomCode,
    required String hostKeyOrPasskey,
    CampaignRole targetRole = CampaignRole.host,
    String? playerName,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase().replaceAll(' ', '');
    final cleanKey = CryptoUtils.extractHostKey(hostKeyOrPasskey);

    if (cleanCode.isEmpty) {
      throw CampaignNotFoundException('Please enter a valid room code.');
    }
    if (cleanKey.isEmpty) {
      throw Exception('Please enter a valid DM passkey.');
    }

    final codeCandidates = <String>{
      cleanCode,
      if (cleanCode.startsWith('ROOM-')) cleanCode.replaceFirst('ROOM-', '') else 'ROOM-$cleanCode',
      if (cleanCode.startsWith('ROOM_')) cleanCode.replaceFirst('ROOM_', '') else 'ROOM_$cleanCode',
    }.toList();

    PartySessionState? session;
    String matchedCode = cleanCode;

    if (isFirebaseAvailable) {
      for (final code in codeCandidates) {
        try {
          final docRef = FirebaseFirestore.instance.collection('rooms').doc(code);
          final snapshot = await docRef.get();
          if (snapshot.exists && snapshot.data() != null) {
            session = PartySessionState.fromMap(snapshot.data()!);
            matchedCode = code;
            break;
          }
        } catch (e, stackTrace) {
          LoggingService().logNonFatal(e, stackTrace, reason: 'Firestore check failed for room $code');
        }
      }
    }

    if (session == null) {
      for (final code in codeCandidates) {
        if (_localRooms.containsKey(code)) {
          session = _localRooms[code];
          matchedCode = code;
          break;
        }
      }
    }

    if (session != null) {
      final expectedHash = session.hostKeyHash;
      if (expectedHash.isNotEmpty) {
        final actualHash = CryptoUtils.sha256Hex(cleanKey);
        if (actualHash != expectedHash) {
          throw UnauthorizedHostActionException('Invalid DM passkey. Please check the code provided by your Dungeon Master.');
        }
      }

      final existing = _registry.getMembership(matchedCode);
      final charName = (playerName != null && playerName.trim().isNotEmpty)
          ? playerName.trim()
          : (existing?.characterId ?? 'DM');

      final updated = (existing ?? CampaignMembership(
        roomCode: matchedCode,
        campaignName: session.campaignName,
        lastPlayed: DateTime.now(),
      )).copyWith(
        campaignName: session.campaignName,
        role: targetRole,
        hostKey: cleanKey,
        characterId: charName,
        lastPlayed: DateTime.now(),
      );

      await _registry.saveMembership(updated);
      await _registry.setActiveCampaign(updated);
      _emitSession(matchedCode);
      return updated;
    }

    // If not in cloud/memory, attempt rehydration with this hostKey
    final localRecord = _registry.getMembership(matchedCode);
    final charName = (playerName != null && playerName.trim().isNotEmpty)
        ? playerName.trim()
        : (localRecord?.characterId ?? 'DM');

    final rehydrated = await rehydrateCampaign(
      roomCode: matchedCode,
      hostKey: cleanKey,
      playerName: charName,
      campaignName: localRecord?.campaignName,
    );

    final membership = CampaignMembership(
      roomCode: matchedCode,
      campaignName: rehydrated.campaignName,
      role: targetRole,
      hostKey: cleanKey,
      characterId: charName,
      lastPlayed: DateTime.now(),
    );
    await _registry.saveMembership(membership);
    await _registry.setActiveCampaign(membership);
    return membership;
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

  /// Leaves a campaign: removes player from active session and purges local membership
  Future<void> leaveCampaign({
    required String roomCode,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedPlayer = playerName.trim();

    // 1. Remove from local membership registry
    await _registry.removeMembership(clean);

    // 2. In-memory update
    final current = _localRooms[clean];
    if (current != null) {
      final updatedPlayers = List<String>.from(current.activePlayers)..remove(trimmedPlayer);
      final updatedRoster = List<String>.from(current.characterRoster)..remove(trimmedPlayer);
      final updatedSession = current.copyWith(
        activePlayers: updatedPlayers,
        characterRoster: updatedRoster,
        lastUpdated: DateTime.now(),
      );
      _localRooms[clean] = updatedSession;
      _emitSession(clean);
    }

    // 3. Log leave audit event
    await logEvent(
      roomCode: clean,
      type: 'playerLeave',
      playerName: trimmedPlayer.isNotEmpty ? trimmedPlayer : 'Player',
      details: '$trimmedPlayer left the campaign session.',
    );

    // 4. Update Firestore
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          if (current != null) 'campaignName': current.campaignName,
          'activePlayers': FieldValue.arrayRemove([trimmedPlayer]),
          'characterRoster': FieldValue.arrayRemove([trimmedPlayer]),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore leaveCampaign failed for $clean');
      }
    }

    // 5. Cleanup dice room stream
    _diceRoomService.disposeRoomStream(clean);
  }

  /// Permanently deletes a campaign: verifies host authority if key exists,
  /// deletes from Firestore, and purges all local state and memberships.
  Future<void> deleteCampaign({
    required String roomCode,
    String? hostKey,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final membership = _registry.getMembership(clean);

    // Verify DM authority if hostKey is tracked
    final keyToVerify = hostKey ?? membership?.hostKey;
    final session = _localRooms[clean];
    final expectedHash = session?.hostKeyHash ?? '';
    if (expectedHash.isNotEmpty) {
      if (keyToVerify == null || keyToVerify.isEmpty) {
        throw UnauthorizedHostActionException('DM passkey is required to delete this campaign.');
      }
      final cleanKey = CryptoUtils.extractHostKey(keyToVerify);
      final actualHash = CryptoUtils.sha256Hex(cleanKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException('Invalid DM passkey. Cannot delete campaign.');
      }
    }

    // 1. Remove from local membership registry
    await _registry.removeMembership(clean);

    // 2. In-memory cleanup
    _localRooms.remove(clean);
    _localLoot.remove(clean);
    _localEvents.remove(clean);
    _outbox.remove(clean);
    _sessionSubscriptions[clean]?.cancel();
    _sessionSubscriptions.remove(clean);
    _sessionControllers[clean]?.close();
    _sessionControllers.remove(clean);
    _updateOutboxCount();
    _emitSession(clean);

    // 3. Firestore deletion
    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.delete();
      } catch (e, st) {
        LoggingService().logNonFatal(e, st, reason: 'Firestore deleteCampaign failed for $clean');
      }
    }

    // 4. Cleanup dice room stream
    _diceRoomService.disposeRoomStream(clean);
  }

  /// Automatically synchronizes all local campaign memberships into Firestore rooms
  Future<void> syncAllExistingCampaignsToFirestore() async {
    if (!isFirebaseAvailable) return;
    try {
      final memberships = _registry.memberships;
      for (final m in memberships) {
        try {
          await ensureRoomExists(
            roomCode: m.roomCode,
            campaignName: m.campaignName,
            hostKey: m.hostKey,
            isStateless: false,
          );
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Failed to sync existing campaign ${m.roomCode} to Firestore');
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'syncAllExistingCampaignsToFirestore error');
    }
  }

  // =========================================================================
  // 3. SUBCOLLECTION-BASED STREAMING
  // =========================================================================

  /// Returns the current in-memory cached state of a room if available
  PartySessionState? getCachedSession(String roomCode) =>
      _localRooms[roomCode.trim().toUpperCase()];

  /// Stream root session state
  Stream<PartySessionState?> streamSession(String roomCode) {
    final clean = roomCode.trim().toUpperCase();

    final controller = _sessionControllers.putIfAbsent(
      clean,
      () => StreamController<PartySessionState?>.broadcast(),
    );

    if (isFirebaseAvailable) {
      _sessionSubscriptions.putIfAbsent(clean, () {
        return FirebaseFirestore.instance
            .collection('rooms')
            .doc(clean)
            .snapshots()
            .listen((snap) {
          if (!snap.exists || snap.data() == null) {
            if (!controller.isClosed) controller.add(null);
            return;
          }
          try {
            final state = PartySessionState.fromMap(snap.data()!);
            _localRooms[clean] = state;
            if (!controller.isClosed) controller.add(state);
          } catch (e, st) {
            LoggingService().logNonFatal(e, st, reason: 'PartySessionState.fromMap error for $clean');
            if (!controller.isClosed && _localRooms.containsKey(clean)) {
              controller.add(_localRooms[clean]);
            }
          }
        }, onError: (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'streamSession error for $clean');
          if (!controller.isClosed && _localRooms.containsKey(clean)) {
            controller.add(_localRooms[clean]);
          }
        });
      });
    }

    Future.microtask(() {
      if (!controller.isClosed && _localRooms.containsKey(clean)) {
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
        final session = _localRooms[clean];
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          if (session != null) 'campaignName': session.campaignName,
          'activePlayers': FieldValue.arrayUnion([trimmedName]),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
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
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'characterRoster': FieldValue.arrayUnion([trimmed]),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
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
          final payload = <String, dynamic>{
            'roomCode': clean,
            'code': clean,
            'campaignName': current.campaignName,
            'characterRoster': updatedRoster,
            'memberPurses': updatedPurses.map((k, v) => MapEntry(k, v.toMap())),
            'version': FieldValue.increment(1),
            'lastUpdated': DateTime.now().toIso8601String(),
          };
          if (deletedPurse != null && !deletedPurse.isEmpty) {
            payload['partyPurse'] = updatedPartyPurse.toMap();
          }
          await docRef.set(payload, SetOptions(merge: true));
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
          final payload = <String, dynamic>{
            'roomCode': clean,
            'code': clean,
            'campaignName': current.campaignName,
            'characterRoster': cleanedRoster,
            'memberPurses': updatedPurses.map((k, v) => MapEntry(k, v.toMap())),
            'version': FieldValue.increment(1),
            'lastUpdated': DateTime.now().toIso8601String(),
          };
          if (updatedPartyPurse != current.partyPurse) {
            payload['partyPurse'] = updatedPartyPurse.toMap();
          }
          await docRef.set(payload, SetOptions(merge: true));
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
    final updatedPurse = current.partyPurse.depositCoins(
      cp: cp,
      sp: sp,
      ep: ep,
      gp: gp,
      pp: pp,
      nodeId: localNodeId,
    );
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
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'partyPurse': {
            'cp': FieldValue.increment(cp),
            'sp': FieldValue.increment(sp),
            'ep': FieldValue.increment(ep),
            'gp': FieldValue.increment(gp),
            'pp': FieldValue.increment(pp),
          },
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
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

    final updatedPurse = current.partyPurse.withdrawCoins(
      cp: cp,
      sp: sp,
      ep: ep,
      gp: gp,
      pp: pp,
      nodeId: localNodeId,
    );
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
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'partyPurse': {
            'cp': FieldValue.increment(-cp),
            'sp': FieldValue.increment(-sp),
            'ep': FieldValue.increment(-ep),
            'gp': FieldValue.increment(-gp),
            'pp': FieldValue.increment(-pp),
          },
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
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

  // =========================================================================
  // CHARACTER VAULT SYNCHRONIZATION HELPERS
  // =========================================================================

  Future<void> _syncCoinsToCharacter({
    required String roomCode,
    required String characterIdentifier,
    int pp = 0,
    int gp = 0,
    int ep = 0,
    int sp = 0,
    int cp = 0,
    bool emitSession = true,
  }) async {
    try {
      final all = await _characterPersistenceService.loadCharacters();
      final cleanIdent = characterIdentifier.trim().toLowerCase();
      final membership = _registry.getMembership(roomCode);

      Character? matched;
      for (final c in all) {
        if (c.id.slug.toLowerCase() == cleanIdent ||
            c.name.trim().toLowerCase() == cleanIdent) {
          matched = c;
          break;
        }
      }

      if (matched == null && membership?.characterId != null) {
        for (final c in all) {
          if (c.id.slug.toLowerCase() == membership!.characterId!.toLowerCase()) {
            matched = c;
            break;
          }
        }
      }

      if (matched != null) {
        final updatedPurse = matched.purse.depositCoins(
          pp: pp,
          gp: gp,
          ep: ep,
          sp: sp,
          cp: cp,
          nodeId: localNodeId,
        );
        final updatedChar = matched.copyWith(purse: updatedPurse);
        await _characterPersistenceService.saveCharacter(updatedChar);

        final clean = roomCode.trim().toUpperCase();
        final current = _localRooms[clean];
        if (current != null) {
          final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
          updatedShared[updatedChar.id.slug] = updatedChar.toMap();
          updatedShared[characterIdentifier] = updatedChar.toMap();
          final updatedPurses = Map<String, PartyPurse>.from(current.memberPurses);
          updatedPurses[characterIdentifier] = updatedPurse;
          updatedPurses[updatedChar.id.slug] = updatedPurse;
          _localRooms[clean] = current.copyWith(
            sharedCharacters: updatedShared,
            memberPurses: updatedPurses,
          );
          if (emitSession) {
            _emitSession(clean);
          }
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to sync coins to character $characterIdentifier');
    }
  }

  Future<void> _syncPurseOverrideToCharacter({
    required String roomCode,
    required String characterIdentifier,
    required PartyPurse newPurse,
  }) async {
    try {
      final all = await _characterPersistenceService.loadCharacters();
      final cleanIdent = characterIdentifier.trim().toLowerCase();
      final membership = _registry.getMembership(roomCode);

      Character? matched;
      for (final c in all) {
        if (c.id.slug.toLowerCase() == cleanIdent ||
            c.name.trim().toLowerCase() == cleanIdent) {
          matched = c;
          break;
        }
      }

      if (matched == null && membership?.characterId != null) {
        for (final c in all) {
          if (c.id.slug.toLowerCase() == membership!.characterId!.toLowerCase()) {
            matched = c;
            break;
          }
        }
      }

      if (matched != null) {
        final updatedChar = matched.copyWith(purse: newPurse);
        await _characterPersistenceService.saveCharacter(updatedChar);

        final clean = roomCode.trim().toUpperCase();
        final current = _localRooms[clean];
        if (current != null) {
          final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
          updatedShared[updatedChar.id.slug] = updatedChar.toMap();
          updatedShared[characterIdentifier] = updatedChar.toMap();
          final updatedPurses = Map<String, PartyPurse>.from(current.memberPurses);
          updatedPurses[characterIdentifier] = newPurse;
          updatedPurses[updatedChar.id.slug] = newPurse;
          _localRooms[clean] = current.copyWith(
            sharedCharacters: updatedShared,
            memberPurses: updatedPurses,
          );
          _emitSession(clean);
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to sync purse override to character $characterIdentifier');
    }
  }

  Future<void> _syncLootClaimToCharacter({
    required String roomCode,
    required PartyLootItem item,
    required String? claimingPlayer,
  }) async {
    try {
      final instanceId = 'loot_${item.id}';
      final allChars = await _characterPersistenceService.loadCharacters();
      final cleanRoom = roomCode.trim().toUpperCase();
      final membership = _registry.getMembership(cleanRoom);

      if (claimingPlayer != null && claimingPlayer.trim().isNotEmpty) {
        final cleanPlayer = claimingPlayer.trim().toLowerCase();
        Character? matched;
        for (final c in allChars) {
          if (c.id.slug.toLowerCase() == cleanPlayer ||
              c.name.trim().toLowerCase() == cleanPlayer) {
            matched = c;
            break;
          }
        }
        if (matched == null && membership?.characterId != null) {
          for (final c in allChars) {
            if (c.id.slug.toLowerCase() == membership!.characterId!.toLowerCase()) {
              matched = c;
              break;
            }
          }
        }

        if (matched != null) {
          final itemSlug = item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          final instance = InventoryItemInstance(
            instanceId: instanceId,
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: itemSlug.isNotEmpty ? itemSlug : 'vault_item_${item.id}',
              displayName: item.name,
            ),
            quantity: item.count > 0 ? item.count : 1,
            requiresAttunement: item.requiresAttunement,
            isAttuned: item.isAttuned,
            customName: item.name,
            notes: item.description,
          );

          final updatedInventory = List<InventoryItemInstance>.from(matched.inventory)
            ..removeWhere((i) => i.instanceId == instanceId)
            ..add(instance);

          final updatedChar = matched.copyWith(inventory: updatedInventory);
          await _characterPersistenceService.saveCharacter(updatedChar);

          final current = _localRooms[cleanRoom];
          if (current != null) {
            final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
            updatedShared[updatedChar.id.slug] = updatedChar.toMap();
            _localRooms[cleanRoom] = current.copyWith(sharedCharacters: updatedShared);
            _emitSession(cleanRoom);
          }
        }
      } else {
        // Returned to vault: remove item instance from any character
        for (final c in allChars) {
          if (c.inventory.any((i) => i.instanceId == instanceId)) {
            final updatedInv = c.inventory.where((i) => i.instanceId != instanceId).toList();
            final updatedChar = c.copyWith(inventory: updatedInv);
            await _characterPersistenceService.saveCharacter(updatedChar);

            final current = _localRooms[cleanRoom];
            if (current != null) {
              final updatedShared = Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
              updatedShared[updatedChar.id.slug] = updatedChar.toMap();
              _localRooms[cleanRoom] = current.copyWith(sharedCharacters: updatedShared);
              _emitSession(cleanRoom);
            }
          }
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to sync loot claim for item ${item.id}');
    }
  }

  /// Disperses coins/valuables among selected party member stores, with an optional share for the party reserve.
  /// When [isVaultDispersal] is true, coins are distributed OUT OF the shared party vault (withdrawing
  /// the shares given to characters), rather than being deposited as new external hoard loot.
  Future<void> disperseCoinsToParty({
    required String roomCode,
    required PartyPurse purseToDisperse,
    required List<String> recipientCharacters,
    required String performedBy,
    bool includePartyReserve = true,
    double liquidatedGemsAndArtGp = 0.0,
    bool includeLiquidatedInSplit = false,
    bool isVaultDispersal = false,
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
        updatedMemberPurses[recipient] = prev.depositCoins(gp: perShareGp, nodeId: localNodeId);
        await _syncCoinsToCharacter(
          roomCode: clean,
          characterIdentifier: recipient,
          gp: perShareGp,
          emitSession: false,
        );
      }

      if (isVaultDispersal) {
        // Vault funds distributed to characters: withdraw disbursed character shares from vault
        final totalGpWithdrawn = perShareGp * recipients.length;
        updatedPartyPurse = updatedPartyPurse.withdrawCoins(
          gp: math.min(updatedPartyPurse.gp, totalGpWithdrawn),
          nodeId: localNodeId,
        );
      } else {
        // External loot drop: deposit reserve share or remainder
        if (includePartyReserve) {
          updatedPartyPurse = updatedPartyPurse.depositCoins(gp: perShareGp + remainderGp, nodeId: localNodeId);
        } else if (remainderGp > 0) {
          updatedPartyPurse = updatedPartyPurse.depositCoins(gp: remainderGp, nodeId: localNodeId);
        }
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
          nodeId: localNodeId,
        );
        await _syncCoinsToCharacter(
          roomCode: clean,
          characterIdentifier: recipient,
          pp: ppPerShare,
          gp: gpPerShare,
          ep: epPerShare,
          sp: spPerShare,
          cp: cpPerShare,
          emitSession: false,
        );
      }

      if (isVaultDispersal) {
        // Vault funds distributed to characters: withdraw distributed shares from the vault
        final ppWithdrawn = ppPerShare * recipients.length;
        final gpWithdrawn = gpPerShare * recipients.length;
        final epWithdrawn = epPerShare * recipients.length;
        final spWithdrawn = spPerShare * recipients.length;
        final cpWithdrawn = cpPerShare * recipients.length;
        updatedPartyPurse = updatedPartyPurse.withdrawCoins(
          pp: ppWithdrawn,
          gp: gpWithdrawn,
          ep: epWithdrawn,
          sp: spWithdrawn,
          cp: cpWithdrawn,
          nodeId: localNodeId,
        );
      } else {
        // External loot drop: deposit reserve share or remainder
        if (includePartyReserve) {
          updatedPartyPurse = updatedPartyPurse.depositCoins(
            pp: ppPerShare + ppRem,
            gp: gpPerShare + gpRem,
            ep: epPerShare + epRem,
            sp: spPerShare + spRem,
            cp: cpPerShare + cpRem,
            nodeId: localNodeId,
          );
        } else {
          // Remainder always goes to party reserve so nothing is lost
          updatedPartyPurse = updatedPartyPurse.depositCoins(
            pp: ppRem,
            gp: gpRem,
            ep: epRem,
            sp: spRem,
            cp: cpRem,
            nodeId: localNodeId,
          );
        }
      }
    }

    final latestSession = _localRooms[clean] ?? current;
    final updatedSession = latestSession.copyWith(
      partyPurse: updatedPartyPurse,
      memberPurses: updatedMemberPurses,
      version: latestSession.version + 1,
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

      await _syncPurseOverrideToCharacter(
        roomCode: clean,
        characterIdentifier: trimmedName,
        newPurse: newPurse,
      );

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
          await docRef.set({
            'roomCode': clean,
            'code': clean,
            'campaignName': current.campaignName,
            'memberPurses': updatedMap.map((k, v) => MapEntry(k, v.toMap())),
            'version': FieldValue.increment(1),
            'lastUpdated': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
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
      final updatedMemberPurse = currentMemberPurse.withdrawCoins(
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        nodeId: localNodeId,
      );
      final updatedPartyPurse = current.partyPurse.depositCoins(
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        nodeId: localNodeId,
      );

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

      await _syncPurseOverrideToCharacter(
        roomCode: clean,
        characterIdentifier: trimmedName,
        newPurse: updatedMemberPurse,
      );

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
      final updatedPartyPurse = currentPartyPurse.withdrawCoins(
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        nodeId: localNodeId,
      );
      final currentMemberPurse = current.getMemberPurse(trimmedName);
      final updatedMemberPurse = currentMemberPurse.depositCoins(
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        nodeId: localNodeId,
      );

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

      await _syncPurseOverrideToCharacter(
        roomCode: clean,
        characterIdentifier: trimmedName,
        newPurse: updatedMemberPurse,
      );

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

    await _syncLootClaimToCharacter(
      roomCode: clean,
      item: existing ?? PartyLootItem(id: lootId, name: lootId, createdAt: DateTime.now(), expiresAt: DateTime.now()),
      claimingPlayer: playerName,
    );

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

              await _syncLootClaimToCharacter(
                roomCode: clean,
                item: restored,
                claimingPlayer: remoteWinner,
              );

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
    _scheduleAutoFlush(action.roomCode);
  }

  void _scheduleAutoFlush(String roomCode) {
    _autoFlushTimer?.cancel();
    _autoFlushTimer = Timer(const Duration(milliseconds: 1500), () {
      if (isFirebaseAvailable) {
        flushOutbox(roomCode);
      }
    });
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

    int aggregateCp = 0;
    int aggregateSp = 0;
    int aggregateEp = 0;
    int aggregateGp = 0;
    int aggregatePp = 0;
    bool hasCoinDelta = false;

    for (final action in toProcess) {
      if (action.actionType == 'createRoom') {
        batch.set(docRef, action.payload, SetOptions(merge: true));
      } else if (action.actionType == 'addLoot') {
        final lootDoc = docRef.collection('loot').doc(action.payload['id'] as String);
        batch.set(lootDoc, action.payload);
      } else if (action.actionType == 'claimLoot') {
        final lootDoc = docRef.collection('loot').doc(action.payload['lootId'] as String);
        batch.set(lootDoc, {'claimedByPlayer': action.payload['claimedByPlayer']}, SetOptions(merge: true));
      } else if (action.actionType == 'coinDeposit' || action.actionType == 'coinWithdraw') {
        hasCoinDelta = true;
        aggregateCp += (action.payload['cp'] as num?)?.toInt() ?? 0;
        aggregateSp += (action.payload['sp'] as num?)?.toInt() ?? 0;
        aggregateEp += (action.payload['ep'] as num?)?.toInt() ?? 0;
        aggregateGp += (action.payload['gp'] as num?)?.toInt() ?? 0;
        aggregatePp += (action.payload['pp'] as num?)?.toInt() ?? 0;
      }
    }

    if (hasCoinDelta) {
      final session = _localRooms[clean];
      batch.set(docRef, {
        'roomCode': clean,
        'code': clean,
        if (session != null) 'campaignName': session.campaignName,
        'partyPurse': {
          'cp': FieldValue.increment(aggregateCp),
          'sp': FieldValue.increment(aggregateSp),
          'ep': FieldValue.increment(aggregateEp),
          'gp': FieldValue.increment(aggregateGp),
          'pp': FieldValue.increment(aggregatePp),
        },
        'version': FieldValue.increment(1),
        'lastUpdated': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      pending.removeWhere((a) => toProcess.contains(a));
      _updateOutboxCount();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to flush outbox for room $clean');
      for (final action in toProcess) {
        action.retryCount++;
      }
      // Purge actions that failed repeatedly (max 3 retries) to unwedge the UI
      pending.removeWhere((a) => a.retryCount >= 3);
      _updateOutboxCount();
      if (pending.isNotEmpty) {
        _scheduleAutoFlush(clean);
      }
    }
  }

  /// Clears pending outbox queue for a room
  void clearOutbox(String roomCode) {
    final clean = roomCode.trim().toUpperCase();
    _outbox.remove(clean);
    _updateOutboxCount();
    _autoFlushTimer?.cancel();
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
