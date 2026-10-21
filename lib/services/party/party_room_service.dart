import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_purse.dart';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../models/party/party_session_state.dart';
import '../../models/party/party_room_lobby.dart';
import '../../infrastructure/migration/party_ledger_legacy_import.dart';
import '../../infrastructure/migration/room_profile_genesis_restamper.dart';
import '../../infrastructure/di/injection_container.dart';
import '../../utils/crypto_utils.dart';
import '../../utils/secure_random.dart';
import '../../application/services/room_document_port.dart';
import '../logging_service.dart';
import '../dice_room_service.dart';
import '../persistence/character_persistence_service.dart';
import '../persistence/campaign_profile_service.dart';
import 'campaign_registry_service.dart';
import 'party_ledger_operations.dart';
import 'room_code_relink.dart';

class CampaignNotFoundException implements Exception {
  final String message;
  CampaignNotFoundException(
      [this.message = 'Campaign not found. Please check code with your DM.']);
  @override
  String toString() => message;
}

class UnauthorizedHostActionException implements Exception {
  final String message;
  UnauthorizedHostActionException(
      [this.message =
          'Unauthorized: DM Passkey required for this administrative action.']);
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

  factory PartyOutboxAction.fromMap(Map<String, dynamic> map) =>
      PartyOutboxAction(
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

  static PartyRoomService get _instance {
    if (sl.isRegistered<PartyRoomService>()) {
      return sl<PartyRoomService>();
    }
    throw StateError(
      'PartyRoomService requires an authoritative ReplicaId. '
      'Ensure initServiceLocator() has completed or inject ReplicaId explicitly.',
    );
  }

  factory PartyRoomService({
    ReplicaId? replicaId,
    StatefulHlcClock? clock,
    CampaignRegistryService? registry,
    DiceRoomService? diceRoomService,
    CharacterPersistenceService? characterPersistenceService,
    CampaignProfileService? campaignProfileService,
    IRoomDocumentPort? roomDocumentPort,
  }) {
    if (replicaId != null) {
      return PartyRoomService._internal(
        replicaId: replicaId,
        clock: clock,
        registry: registry,
        diceRoomService: diceRoomService,
        characterPersistenceService: characterPersistenceService,
        campaignProfileService: campaignProfileService,
        roomDocumentPort: roomDocumentPort,
      );
    }
    return _instance;
  }

  final ReplicaId replicaId;
  String get localNodeId => replicaId.value;
  final StatefulHlcClock _clock;
  StatefulHlcClock get clock => _clock;
  final CampaignRegistryService _registry;
  final DiceRoomService _diceRoomService;
  final CharacterPersistenceService _characterPersistenceService;
  final CampaignProfileService _campaignProfileService;
  final IRoomDocumentPort _roomDocPort;
  IRoomDocumentPort get roomDocPort => _roomDocPort;

  PartyRoomService._internal({
    required this.replicaId,
    StatefulHlcClock? clock,
    CampaignRegistryService? registry,
    DiceRoomService? diceRoomService,
    CharacterPersistenceService? characterPersistenceService,
    CampaignProfileService? campaignProfileService,
    IRoomDocumentPort? roomDocumentPort,
  })  : _clock = clock ??
            (sl.isRegistered<StatefulHlcClock>()
                ? sl<StatefulHlcClock>()
                : throw StateError(
                    'Authoritative StatefulHlcClock is required but not registered in DI. '
                    'Pass clock explicitly or register StatefulHlcClock in DI.',
                  )),
        _registry = registry ?? CampaignRegistryService(),
        _diceRoomService = diceRoomService ?? DiceRoomService(),
        _characterPersistenceService =
            characterPersistenceService ?? CharacterPersistenceService(),
        _campaignProfileService =
            campaignProfileService ?? CampaignProfileService(),
        _roomDocPort = roomDocumentPort ??
            (sl.isRegistered<IRoomDocumentPort>()
                ? sl<IRoomDocumentPort>()
                : throw StateError(
                    'Authoritative IRoomDocumentPort is required but not registered in DI. '
                    'Pass roomDocumentPort explicitly or register IRoomDocumentPort in DI.',
                  )) {
    if (_clock.replicaId != replicaId) {
      throw ArgumentError(
        'PartyRoomService writer identity mismatch: '
        'replicaId ($replicaId) does not match clock.replicaId (${_clock.replicaId}).',
      );
    }
  }

  @visibleForTesting
  PartyRoomService.newInstance({
    ReplicaId? replicaId,
    StatefulHlcClock? clock,
    CampaignRegistryService? registry,
    DiceRoomService? diceRoomService,
    CharacterPersistenceService? characterPersistenceService,
    CampaignProfileService? campaignProfileService,
    IRoomDocumentPort? roomDocumentPort,
  })  : replicaId = replicaId ??
            (throw StateError(
              'PartyRoomService requires an authoritative ReplicaId. '
              'Pass replicaId explicitly.',
            )),
        _clock = clock ??
            (sl.isRegistered<StatefulHlcClock>()
                ? sl<StatefulHlcClock>()
                : throw StateError(
                    'PartyRoomService requires an authoritative StatefulHlcClock. '
                    'Register StatefulHlcClock in DI or pass clock explicitly.',
                  )),
        _registry = registry ??
            // ignore: invalid_use_of_visible_for_testing_member
            CampaignRegistryService.newInstance(),
        _diceRoomService = diceRoomService ??
            // ignore: invalid_use_of_visible_for_testing_member
            DiceRoomService.newInstance(),
        _characterPersistenceService =
            characterPersistenceService ?? CharacterPersistenceService(),
        _campaignProfileService =
            campaignProfileService ?? CampaignProfileService(),
        _roomDocPort = roomDocumentPort ??
            (sl.isRegistered<IRoomDocumentPort>()
                ? sl<IRoomDocumentPort>()
                : throw StateError(
                    'PartyRoomService requires an authoritative IRoomDocumentPort. '
                    'Register IRoomDocumentPort in DI or pass roomDocumentPort explicitly.',
                  )) {
    if (_clock.replicaId != this.replicaId) {
      throw ArgumentError(
        'PartyRoomService writer identity mismatch: '
        'replicaId (${this.replicaId}) does not match clock.replicaId (${_clock.replicaId}).',
      );
    }
  }

  static void resetCustomInstanceForTesting() {
    if (sl.isRegistered<PartyRoomService>()) {
      sl.unregister<PartyRoomService>();
    }
  }

  @visibleForTesting
  static void setCustomInstanceForTesting(PartyRoomService? instance) {
    if (sl.isRegistered<PartyRoomService>()) {
      sl.unregister<PartyRoomService>();
    }
    if (instance != null) {
      sl.registerSingleton<PartyRoomService>(instance);
    }
  }

  bool? _isFirebaseAvailableOverride;
  bool get isFirebaseAvailable =>
      _isFirebaseAvailableOverride ?? Firebase.apps.isNotEmpty;

  @visibleForTesting
  void setFirebaseAvailableForTesting(bool? value) {
    _isFirebaseAvailableOverride = value;
  }

  @visibleForTesting
  void queueOutboxActionForTesting(PartyOutboxAction action) {
    _queueOutbox(action);
  }

  @visibleForTesting
  int getOutboxCountForTesting(String roomCode) {
    return _outbox[roomCode.trim().toUpperCase()]?.length ?? 0;
  }

  // Local in-memory store for tests, offline mode, or fallback
  final Map<String, PartySessionState> _localRooms = {};
  final Map<String, PartyRoomLobby> _localLobbies = {};
  final Map<String, Map<String, dynamic>> _rawLegacyDocs = {};
  final Map<String, Map<String, PartyLootItem>> _localLoot = {};
  final Map<String, List<PartyEvent>> _localEvents = {};

  final Map<String, StreamController<PartySessionState?>> _sessionControllers =
      {};
  final Map<String, StreamSubscription> _sessionSubscriptions = {};
  final Map<String, StreamController<List<PartyLootItem>>> _lootControllers =
      {};
  final Map<String, StreamController<List<PartyEvent>>> _eventControllers = {};

  final StreamController<ClaimConflictEvent> _claimConflictController =
      StreamController<ClaimConflictEvent>.broadcast();
  Stream<ClaimConflictEvent> get claimConflictStream =>
      _claimConflictController.stream;

  final StreamController<PurseOverdraftEvent> _overdraftController =
      StreamController<PurseOverdraftEvent>.broadcast();
  Stream<PurseOverdraftEvent> get overdraftStream =>
      _overdraftController.stream;

  // Offline Outbox Queue (roomCode -> list of actions)
  final Map<String, List<PartyOutboxAction>> _outbox = {};
  final ValueNotifier<int> pendingOutboxCount = ValueNotifier<int>(0);
  Timer? _autoFlushTimer;

  /// Extracts the deterministic campaign ID for a room lobby or raw lobby map.
  static String campaignIdForRoom(dynamic lobby) {
    if (lobby is PartyRoomLobby) {
      if (lobby.campaignId != null && lobby.campaignId!.trim().isNotEmpty) {
        return lobby.campaignId!.trim();
      }
      return 'campaign_${lobby.roomCode.trim().toUpperCase()}';
    }
    if (lobby is PartySessionState) {
      return 'campaign_${lobby.roomCode.trim().toUpperCase()}';
    }
    if (lobby is Map) {
      final cid = lobby['campaignId'] as String?;
      if (cid != null && cid.trim().isNotEmpty) {
        return cid.trim();
      }
      final rawCode = (lobby['roomCode'] ?? lobby['code'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return 'campaign_$rawCode';
    }
    return '';
  }

  static dynamic _parseRulesetEdition(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('2024') || clean == 'v2024' || clean.contains('5.2')) {
      return RulesetEdition.v2024;
    } else if (clean.contains('2014') || clean == 'v2014' || clean.contains('5.1')) {
      return RulesetEdition.v2014;
    }
    return RulesetIdentifier(raw);
  }

  /// Deterministically locates or initializes the single campaign profile bound to [roomCode].
  ///
  /// Invariants:
  /// - A room code maps to exactly one campaign id, and every replica of that campaign uses the same id.
  /// - Among local profiles whose roomState.roomCode equals the code, it picks the one whose
  ///   id equals the lobby campaignId, else the one whose id is `campaign_<ROOMCODE>`.
  /// - Only if neither exists and 2 or more profiles claim the code does opening the room fail,
  /// Resolves the campaign profile for a room deterministically.
  ///
  /// Resolution invariants (Cold Iron Birdcage Pass 7.1 Q4):
  /// - When the lobby names a campaign id:
  ///   - Pick the local profile with that id (linking its room code if it has none).
  ///   - If no local profile has that id and no local profile claims the code, create it with that id.
  ///   - If no local profile has that id but one or more other profiles claim the code,
  ///     fail with an error naming the lobby id and every claiming id.
  ///   - Never pick a profile whose id differs from the lobby's, and never create a second claimant silently.
  /// - When the lobby names no campaign id:
  /// Resolves or deterministically creates a campaign profile for [roomCode].
  ///
  /// - Edition determination:
  ///   - A creating device uses [RulesEdition.currentRulesetId] ('generic_tabletop' or active).
  ///   - A joining device creates its empty profile with the lobby's rulesetId.
  ///   - A legacy lobby without rulesetId means the core default (generic_tabletop).
  /// - Room code linking:
  ///   - If a local profile matches the lobby's campaign ID but has a different or empty room code,
  ///     it is relinked to the current room code using [RoomCodeRelink.relink].
  /// - Stamping:
  ///   - Every site that creates stamps each register with the injected clock.
  /// - Resolution only:
  ///   - Does NOT set active profile. Call [openRoomProfile] on room-entry paths to set active profile.
  Future<CampaignProfile> profileForRoom(
    String roomCode, {
    String? lobbyCampaignId,
    String? lobbyRulesetId,
    required bool allowCreate,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final allProfiles = await _campaignProfileService.repo.loadAllProfiles();
    final claimants = allProfiles
        .where((p) => p.roomState.roomCode.trim().toUpperCase() == clean)
        .toList();

    final targetId = (lobbyCampaignId != null && lobbyCampaignId.trim().isNotEmpty)
        ? lobbyCampaignId.trim()
        : _localLobbies[clean]?.campaignId;

    CampaignProfile resolved;

    if (targetId != null && targetId.isNotEmpty) {
      final matchingById =
          allProfiles.where((p) => p.id == targetId).firstOrNull;
      if (matchingById != null) {
        if (matchingById.roomState.roomCode.trim().toUpperCase() != clean) {
          final linked = RoomCodeRelink.relink(
            matchingById,
            clean,
            _clock,
            stampStagingTitle: false,
          );
          await _campaignProfileService.repo.putProfile(linked);
          resolved = linked;
        } else {
          resolved = matchingById;
        }
      } else if (claimants.isNotEmpty) {
        final claimantIds = claimants.map((p) => p.id).toList();
        throw StateError(
          'Campaign profile mismatch for room $clean: lobby specifies campaign "$targetId", '
          'but local profiles claim room code with different IDs: $claimantIds.',
        );
      } else {
        if (!allowCreate) {
          throw StateError(
            'No campaign profile found or lobby readable for room $clean',
          );
        }
        final targetRuleset = (lobbyRulesetId != null && lobbyRulesetId.trim().isNotEmpty)
            ? lobbyRulesetId.trim()
            : (_localLobbies[clean]?.rulesetId ?? 'generic_tabletop');
        final edition = _parseRulesetEdition(targetRuleset);

        final nowTs = _clock.nextTimestamp();
        final newProfile = CampaignProfile.raw(
          id: targetId,
          nameRegister: CrdtLwwRegister<String>(
            value: 'Campaign $clean',
            timestamp: nowTs,
          ),
          edition: edition,
          createdAt: DateTime.now(),
          lastPlayedAt: DateTime.now(),
          roomState: RoomNodeState(
            roomId: 'room_$clean',
            roomCode: clean,
            title: 'Campaign $clean Staging',
            titleTimestamp: nowTs,
            description: '',
            descriptionTimestamp: nowTs,
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: CrdtLwwRegister<String>(
            value: '',
            timestamp: nowTs,
          ),
          changeLog: const [],
        );
        await _campaignProfileService.repo.putProfile(newProfile);
        resolved = newProfile;
      }
    } else {
      final legacyId = 'campaign_$clean';
      final byLegacy = claimants.where((p) => p.id == legacyId).firstOrNull;
      if (byLegacy != null) {
        resolved = byLegacy;
      } else if (claimants.length == 1) {
        resolved = claimants.first;
      } else if (claimants.length > 1) {
        final claimantIds = claimants.map((p) => p.id).toList();
        throw StateError(
          'Multiple campaign profiles claim room code $clean without lobby campaignId: $claimantIds',
        );
      } else {
        if (!allowCreate) {
          throw StateError(
            'No campaign profile found or lobby readable for room $clean',
          );
        }
        final targetRuleset =
            _localLobbies[clean]?.rulesetId ?? 'generic_tabletop';
        final edition = _parseRulesetEdition(targetRuleset);

        final nowTs = _clock.nextTimestamp();
        final newProfile = CampaignProfile.raw(
          id: legacyId,
          nameRegister: CrdtLwwRegister<String>(
            value: 'Campaign $clean',
            timestamp: nowTs,
          ),
          edition: edition,
          createdAt: DateTime.now(),
          lastPlayedAt: DateTime.now(),
          roomState: RoomNodeState(
            roomId: 'room_$clean',
            roomCode: clean,
            title: 'Campaign $clean Staging',
            titleTimestamp: nowTs,
            description: '',
            descriptionTimestamp: nowTs,
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: CrdtLwwRegister<String>(
            value: '',
            timestamp: nowTs,
          ),
          changeLog: const [],
        );
        await _campaignProfileService.repo.putProfile(newProfile);
        resolved = newProfile;
      }
    }

    return resolved;
  }

  /// Resolves the campaign profile for [roomCode], re-stamps genesis titles if present,
  /// and sets it as the active profile.
  /// Only room-entry paths call this (create, join, rehydrate, PartyRoomScreen, RoomBannerWidget).
  /// Reads the room document from Firestore, records legacy ledger fields in [_rawLegacyDocs],
  /// caches the lobby in [_localLobbies], and returns `null` when the room is absent.
  /// A read failure is logged with LoggingService().logNonFatal and returns `null`.
  Future<PartyRoomLobby?> _fetchRoomLobbyFromFirestore(String roomCode) async {
    final clean = roomCode.trim().toUpperCase();
    try {
      final data = await _roomDocPort.getRoomDocument(roomCode: clean);
      if (data != null) {
        if (PartyLedgerLegacyImport.hasLegacyLedgerFields(data)) {
          _rawLegacyDocs[clean] = data;
        }
        final lobby = PartyRoomLobby.fromMap(data);
        _localLobbies[clean] = lobby;
        return lobby;
      }
      return null;
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to read Firestore room document for $clean',
      );
      return null;
    }
  }

  /// Resolves the campaign profile for [roomCode], re-stamps genesis titles if present,
  /// and sets it as the active profile.
  /// Only room-entry paths call this (create, join, rehydrate, PartyRoomScreen, RoomBannerWidget).
  Future<CampaignProfile> openRoomProfile(
    String roomCode, [
    String? lobbyCampaignId,
    String? lobbyRulesetId,
  ]) async {
    final clean = roomCode.trim().toUpperCase();

    String? effectiveCampaignId = (lobbyCampaignId != null && lobbyCampaignId.trim().isNotEmpty)
        ? lobbyCampaignId.trim()
        : null;
    String? effectiveRulesetId = (lobbyRulesetId != null && lobbyRulesetId.trim().isNotEmpty)
        ? lobbyRulesetId.trim()
        : null;
    bool allowCreate = effectiveCampaignId != null;

    if (effectiveCampaignId == null) {
      PartyRoomLobby? readLobby = _localLobbies[clean];
      readLobby ??= await _fetchRoomLobbyFromFirestore(clean);

      if (readLobby != null) {
        if (readLobby.campaignId != null && readLobby.campaignId!.trim().isNotEmpty) {
          effectiveCampaignId = readLobby.campaignId!.trim();
        }
        effectiveRulesetId ??= readLobby.rulesetId;
        allowCreate = true;
      }
    }

    var profile = await profileForRoom(
      clean,
      lobbyCampaignId: effectiveCampaignId,
      lobbyRulesetId: effectiveRulesetId,
      allowCreate: allowCreate,
    );

    if (RoomProfileGenesisRestamper.isGenesisTimestamp(
            profile.roomState.titleRegister.timestamp) ||
        RoomProfileGenesisRestamper.isGenesisTimestamp(
            profile.roomState.descriptionRegister.timestamp)) {
      profile =
          await _campaignProfileService.repo.updateProfile(profile.id, (p) {
        return RoomProfileGenesisRestamper.restampIfNeeded(
          profile: p,
          clock: _clock,
        );
      });
    }

    await _campaignProfileService.repo.setActiveProfileId(profile.id);
    return profile;
  }

  Future<PartyRoomLobby> _getOrFetchLobby(String roomCode) async {
    final clean = roomCode.trim().toUpperCase();
    if (_localLobbies.containsKey(clean)) {
      return _localLobbies[clean]!;
    }
    final fetched = await _fetchRoomLobbyFromFirestore(clean);
    if (fetched != null) {
      return fetched;
    }
    final existingSession = _localRooms[clean];
    final lobby = PartyRoomLobby(
      roomCode: clean,
      campaignName: existingSession?.campaignName ?? 'Campaign $clean',
      hostKeyHash: existingSession?.hostKeyHash ?? '',
      activePlayers: existingSession?.activePlayers ?? const [],
      partyTelemetry: existingSession?.partyTelemetry ?? const {},
      sharedCharacters: existingSession?.sharedCharacters ?? const {},
      version: existingSession?.version ?? 1,
      lastUpdated: DateTime.now(),
      expiresAt: DateTime.now().add(defaultLootExpiration),
    );
    _localLobbies[clean] = lobby;
    return lobby;
  }

  PartySessionState _buildSessionState(
    PartyRoomLobby lobby,
    CampaignProfile profile,
  ) {
    PartyPurse displayedReserve = profile.partyPurse;
    final displayedMemberPurses = <String, PartyPurse>{};

    for (final entry in profile.memberPurses.entries) {
      if (profile.partyRoster.activeValues.contains(entry.key)) {
        displayedMemberPurses[entry.key] = entry.value;
        final tele = lobby.partyTelemetry[entry.key];
        if (tele != null && tele.name.trim().isNotEmpty) {
          displayedMemberPurses[tele.name.trim()] = entry.value;
        }
      } else {
        // Off roster: folds into reserve view
        displayedReserve = displayedReserve.add(entry.value, replicaId: replicaId);
      }
    }

    final displayedRoster = <String>[];
    for (final slug in profile.partyRoster.activeValues) {
      final tele = lobby.partyTelemetry[slug];
      if (tele != null && tele.id == slug && tele.name.trim().isNotEmpty) {
        displayedRoster.add(tele.name.trim());
      } else {
        displayedRoster.add(slug);
      }
    }

    return PartySessionState(
      roomCode: lobby.roomCode,
      campaignName: lobby.campaignName,
      hostKeyHash: lobby.hostKeyHash,
      partyPurse: displayedReserve,
      memberPurses: displayedMemberPurses,
      activePlayers: lobby.activePlayers,
      characterRoster: displayedRoster,
      sharedCharacters: lobby.sharedCharacters,
      partyTelemetry: lobby.partyTelemetry,
      version: lobby.version,
      lastUpdated: lobby.lastUpdated,
      expiresAt: lobby.expiresAt,
    );
  }

  String _resolveSlugForName(
    String nameOrSlug,
    PartyRoomLobby? lobby,
    CampaignProfile profile,
  ) {
    final clean = nameOrSlug.trim();
    if (clean.isEmpty) return clean;
    final lower = clean.toLowerCase();

    // 1. Check if profile.partyRoster already has this exact slug
    if (profile.partyRoster.activeValues.contains(clean)) return clean;
    for (final slug in profile.partyRoster.activeValues) {
      if (slug.toLowerCase() == lower) return slug;
    }

    // 2. Check telemetry in lobby
    if (lobby != null) {
      for (final entry in lobby.partyTelemetry.entries) {
        if (entry.key.toLowerCase() == lower ||
            entry.value.id.toLowerCase() == lower) {
          return entry.value.id;
        }
        if (entry.value.name.toLowerCase() == lower) {
          return entry.value.id;
        }
      }
    }

    // 3. Check existing memberPurses keys
    for (final key in profile.memberPurses.keys) {
      if (key.toLowerCase() == lower) return key;
    }

    return clean;
  }

  // =========================================================================
  // 1. EXPLICIT CREATE VS JOIN WORKFLOWS
  // =========================================================================

  /// Explicit Room Creation: Generates fresh room code + private hostKey,
  /// saves DM membership locally, and creates Firestore root document.
  Future<PartySessionState> createCampaign({
    required String campaignName,
    required String playerName,
    String? customRoomCode,
    String? linkProfileId,
  }) async {
    final cleanName =
        campaignName.trim().isEmpty ? 'My 5e Campaign' : campaignName.trim();
    final cleanPlayer = playerName.trim().isEmpty ? 'DM' : playerName.trim();
    final roomCode =
        customRoomCode?.trim().toUpperCase() ?? CryptoUtils.generateRoomCode();
    final hostKey = CryptoUtils.generateHostKey();
    final hostKeyHash = CryptoUtils.sha256Hex(hostKey);

    final now = DateTime.now();
    final expiresAt = now.add(defaultLootExpiration);

    // P1: Link caller's active profile if provided, else deterministically find or create profile
    CampaignProfile profile;
    if (linkProfileId != null && linkProfileId.trim().isNotEmpty) {
      final existing =
          await _campaignProfileService.repo.getProfile(linkProfileId.trim());
      if (existing != null) {
        profile = RoomCodeRelink.relink(
          existing,
          roomCode,
          _clock,
          stampStagingTitle: true,
        );
        await _campaignProfileService.repo.putProfile(profile);
      } else {
        profile = await profileForRoom(
          roomCode,
          lobbyCampaignId: linkProfileId.trim(),
          allowCreate: true,
        );
      }
    } else {
      profile = await profileForRoom(roomCode, allowCreate: true);
    }
    profile = await openRoomProfile(roomCode, profile.id, profile.rulesetId);

    final lobby = PartyRoomLobby(
      roomCode: roomCode,
      campaignName: cleanName,
      hostKeyHash: hostKeyHash,
      activePlayers: [cleanPlayer],
      version: 1,
      lastUpdated: now,
      expiresAt: expiresAt,
      campaignId: profile.id,
      rulesetId: profile.rulesetId,
    );
    _localLobbies[roomCode] = lobby;

    final session = _buildSessionState(lobby, profile);

    // 1. Write lobby to Firestore if available (create-only guard)
    if (isFirebaseAvailable) {
      try {
        await _roomDocPort.createRoom(
          roomCode: roomCode,
          data: lobby.toMap(),
        );
      } on RoomAlreadyExistsException {
        _localLobbies.remove(roomCode);
        rethrow;
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason:
              'Failed to write new room $roomCode lobby to Firestore; fallback to local',
        );
        _queueOutbox(PartyOutboxAction(
          id: 'outbox_create_${DateTime.now().millisecondsSinceEpoch}',
          roomCode: roomCode,
          actionType: 'createRoom',
          payload: lobby.toMap(),
          timestamp: DateTime.now(),
        ));
      }
    }

    // 2. Save host membership in local registry with private hostKey
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
    @visibleForTesting Map<String, dynamic>? rawDoc,
  }) async {
    final cleanCode = roomCode.trim().toUpperCase().replaceAll(' ', '');
    final cleanPlayer =
        playerName.trim().isEmpty ? 'Adventurer' : playerName.trim();
    final providedHostKey = hostKey != null && hostKey.trim().isNotEmpty
        ? CryptoUtils.extractHostKey(hostKey)
        : null;

    if (cleanCode.isEmpty) {
      throw CampaignNotFoundException('Please enter a valid room code.');
    }

    // Support both prefixed (ROOM-A1B2C3) and raw 6-character (A1B2C3) formats interchangeably
    final codeCandidates = <String>{
      cleanCode,
      if (cleanCode.startsWith('ROOM-'))
        cleanCode.replaceFirst('ROOM-', '')
      else
        'ROOM-$cleanCode',
      if (cleanCode.startsWith('ROOM_'))
        cleanCode.replaceFirst('ROOM_', '')
      else
        'ROOM_$cleanCode',
    }.toList();

    PartyRoomLobby? cloudLobby;
    String matchedCode = cleanCode;

    if (rawDoc != null) {
      try {
        cloudLobby = PartyRoomLobby.fromMap(rawDoc);
        _localLobbies[cleanCode] = cloudLobby;
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to parse lobby from raw document for $cleanCode',
        );
      }
    }

    for (final code in codeCandidates) {
      try {
        final data = await _roomDocPort.getRoomDocument(roomCode: code);
        if (data != null) {
          rawDoc = data;
          cloudLobby = PartyRoomLobby.fromMap(rawDoc);
          matchedCode = code;
          break;
        }
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason:
              'Room document read failed for room $code; fallback to local check',
        );
      }
    }

    // In-memory lookup for testing/offline
    if (cloudLobby == null) {
      for (final code in codeCandidates) {
        if (_localLobbies.containsKey(code)) {
          cloudLobby = _localLobbies[code];
          matchedCode = code;
          break;
        }
        if (_localRooms.containsKey(code)) {
          final s = _localRooms[code]!;
          cloudLobby = PartyRoomLobby(
            roomCode: code,
            campaignName: s.campaignName,
            hostKeyHash: s.hostKeyHash,
            activePlayers: s.activePlayers,
            partyTelemetry: s.partyTelemetry,
            sharedCharacters: s.sharedCharacters,
            version: s.version,
            lastUpdated: s.lastUpdated,
            expiresAt: s.expiresAt,
          );
          matchedCode = code;
          break;
        }
      }
    }

    // Stateless presence check: If root document doesn't exist, check active signaling or relay presence
    if (cloudLobby == null && isFirebaseAvailable) {
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
            cloudLobby = PartyRoomLobby(
              roomCode: matchedCode,
              campaignName: 'Party Campaign ($matchedCode)',
              hostKeyHash: '',
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
            cloudLobby = PartyRoomLobby(
              roomCode: matchedCode,
              campaignName: 'Party Campaign ($matchedCode)',
              hostKeyHash: '',
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
    if (cloudLobby != null) {
      final existingMembership = _registry.getMembership(matchedCode);

      CampaignRole role = existingMembership?.role ?? CampaignRole.player;
      String? savedHostKey = existingMembership?.hostKey;

      if (providedHostKey != null && providedHostKey.isNotEmpty) {
        final expectedHash = cloudLobby.hostKeyHash;
        if (expectedHash.isNotEmpty) {
          final actualHash = CryptoUtils.sha256Hex(providedHostKey);
          if (actualHash != expectedHash) {
            throw UnauthorizedHostActionException(
                'Invalid DM passkey. Please check the code provided by your Dungeon Master.');
          }
        }
        role = CampaignRole.host;
        savedHostKey = providedHostKey;
      }

      final targetCharId =
          characterId ?? characterSnapshot?.id.slug ?? cleanPlayer;

      final membership = CampaignMembership(
        roomCode: matchedCode,
        campaignName: cloudLobby.campaignName,
        role: role,
        hostKey: savedHostKey,
        characterId: targetCharId,
        lastPlayed: DateTime.now(),
      );
      await _registry.saveMembership(membership);
      await _registry.setActiveCampaign(membership);

      if (rawDoc != null) {
        _rawLegacyDocs[matchedCode] = rawDoc;
      }

      // P1: Deterministically resolve room profile
      final lobbyCampaignId = campaignIdForRoom(cloudLobby);
      var profile = await openRoomProfile(matchedCode, lobbyCampaignId, cloudLobby.rulesetId);

      // P5: Check and run legacy import if raw doc has legacy ledger fields
      if (rawDoc != null &&
          PartyLedgerLegacyImport.hasLegacyLedgerFields(rawDoc)) {
        profile = await _campaignProfileService.repo.updateProfile(profile.id, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: rawDoc!,
            clock: _clock,
          );
        });
      }

      // Update lobby fields
      final updatedPlayers = List<String>.from(cloudLobby.activePlayers);
      if (!updatedPlayers.contains(cleanPlayer)) {
        updatedPlayers.add(cleanPlayer);
      }

      final updatedShared = Map<String, Map<String, dynamic>>.from(
          cloudLobby.sharedCharacters);
      final updatedTelemetry = Map<String, CharacterTelemetryDto>.from(
          cloudLobby.partyTelemetry);

      if (characterSnapshot != null) {
        final telemetry = characterSnapshot.toTelemetryDto();
        updatedTelemetry[characterSnapshot.id.slug] = telemetry;
        updatedShared[characterSnapshot.id.slug] = characterSnapshot.toMap();
        await _characterPersistenceService.saveCharacter(characterSnapshot);

        // Update profile with character roster & purse in one transform
        profile = await _campaignProfileService.repo
            .updateProfile(profile.id, (p) {
          var roster = p.partyRoster;
          if (isNewImport &&
              !roster.activeValues.contains(characterSnapshot.id.slug)) {
            roster = roster.add(
              characterSnapshot.id.slug,
              characterSnapshot.id.slug,
              _clock.nextTimestamp(),
            );
          }
          final withRoster = p.copyWith(partyRoster: roster);
          return PartyLedgerOperations.seedCharacterPurse(
            profile: withRoster,
            characterSlug: characterSnapshot.id.slug,
            openingPurse: characterSnapshot.purse,
            rawDoc: rawDoc,
            characterName: characterSnapshot.name,
          );
        });
      }

      final now = DateTime.now();
      final expiresAt = now.add(defaultLootExpiration);

      final updatedLobby = cloudLobby.copyWith(
        activePlayers: updatedPlayers,
        sharedCharacters: updatedShared,
        partyTelemetry: updatedTelemetry,
        version: cloudLobby.version + 1,
        lastUpdated: now,
        expiresAt: expiresAt,
      );

      _localLobbies[matchedCode] = updatedLobby;
      final session = _buildSessionState(updatedLobby, profile);
      _localRooms[matchedCode] = session;

      if (isFirebaseAvailable) {
        try {
          final Map<String, dynamic> joinPayload = updatedLobby.toMap();
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(matchedCode)
              .set(joinPayload, SetOptions(merge: true));
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to record player union into room $matchedCode',
          );
        }
      }

      _emitSession(matchedCode);
      _diceRoomService.joinRoom(matchedCode, cleanPlayer);

      // Flush any pending outbox items
      unawaited(flushOutbox(matchedCode));

      return session;
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
    throw CampaignNotFoundException(
        'Campaign not found. Please check code with your DM.');
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

    final profile = await profileForRoom(cleanCode, allowCreate: false);
    final existingLobby = _localLobbies[cleanCode];
    final cName = campaignName ??
        existingLobby?.campaignName ??
        'Shared Campaign ($cleanCode)';
    final hostKeyHash = hostKey != null && hostKey.isNotEmpty
        ? CryptoUtils.sha256Hex(CryptoUtils.extractHostKey(hostKey))
        : (existingLobby?.hostKeyHash ?? '');

    final lobby = existingLobby != null
        ? existingLobby.copyWith(
            campaignName: cName,
            hostKeyHash: hostKeyHash,
            version: existingLobby.version + 1,
            lastUpdated: now,
            expiresAt: expiresAt,
          )
        : PartyRoomLobby(
            roomCode: cleanCode,
            campaignName: cName,
            hostKeyHash: hostKeyHash,
            activePlayers: const [],
            partyTelemetry: const {},
            sharedCharacters: const {},
            version: 1,
            lastUpdated: now,
            expiresAt: expiresAt,
          );
    _localLobbies[cleanCode] = lobby;

    final session = _buildSessionState(lobby, profile);
    _localRooms[cleanCode] = session;
    _emitSession(cleanCode);

    final hasHostKey = hostKey != null && hostKey.isNotEmpty;
    if (isFirebaseAvailable) {
      try {
        final Map<String, dynamic> updateData = {
          'roomCode': cleanCode,
          'code': cleanCode,
          'campaignName': cName,
          'isStateless': isStateless,
          'lastUpdated': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          if (lobby.campaignId != null && lobby.campaignId!.isNotEmpty)
            'campaignId': lobby.campaignId,
          if (lobby.rulesetId != null && lobby.rulesetId!.isNotEmpty)
            'rulesetId': lobby.rulesetId,
        };
        if (hostKeyHash.isNotEmpty) {
          updateData['hostKeyHash'] = hostKeyHash;
        }
        await _roomDocPort.touchRoomLease(
          roomCode: cleanCode,
          data: updateData,
          createIfAbsent: hasHostKey,
        );
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason:
              'Failed to touch room stub in ensureRoomExists for $cleanCode',
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
    final targetName =
        (existingRosterName != null && existingRosterName.trim().isNotEmpty)
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

    // 3. P1 & P3: Update profile ledger in ONE transform
    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final rawDoc = _rawLegacyDocs[clean];

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      var roster = p.partyRoster;
      if (isNewImport && !roster.activeValues.contains(character.id.slug)) {
        roster = roster.add(
          character.id.slug,
          character.id.slug,
          _clock.nextTimestamp(),
        );
      }
      final withRoster = p.copyWith(partyRoster: roster);
      return PartyLedgerOperations.seedCharacterPurse(
        profile: withRoster,
        characterSlug: character.id.slug,
        openingPurse: character.purse,
        rawDoc: rawDoc,
        characterName: character.name,
      );
    });

    // 4. Update lobby state
    final telemetry = character.toTelemetryDto();
    final updatedPlayers = List<String>.from(lobby.activePlayers);
    if (!updatedPlayers.contains(targetName)) {
      updatedPlayers.add(targetName);
    }

    final updatedShared =
        Map<String, Map<String, dynamic>>.from(lobby.sharedCharacters);
    final updatedTelemetry =
        Map<String, CharacterTelemetryDto>.from(lobby.partyTelemetry);
    updatedShared[character.id.slug] = telemetry.toMap();
    updatedShared[targetName] = telemetry.toMap();
    updatedTelemetry[character.id.slug] = telemetry;
    updatedTelemetry[targetName] = telemetry;

    final updatedLobby = lobby.copyWith(
      activePlayers: updatedPlayers,
      sharedCharacters: updatedShared,
      partyTelemetry: updatedTelemetry,
      version: lobby.version + 1,
      lastUpdated: DateTime.now(),
    );
    _localLobbies[clean] = updatedLobby;

    final current = _buildSessionState(updatedLobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    // 5. Cloud update: write only lobby fields (NO ledger fields)
    if (isFirebaseAvailable) {
      try {
        final docRef =
            FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'activePlayers': current.activePlayers,
          'sharedCharacters': {
            character.id.slug: character.toMap(),
          },
          'partyTelemetry': {
            character.id.slug: telemetry.toMap(),
          },
          'version': FieldValue.increment(1),
          'lastUpdated': DateTime.now().toIso8601String(),
          'expiresAt': current.expiresAt.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore linkCharacterToCampaign failed for $clean');
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
    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );

    // 1. Update local lobby
    final telemetry = character.toTelemetryDto();
    final name = existingRosterName ?? character.name;
    final updatedTelemetry =
        Map<String, CharacterTelemetryDto>.from(lobby.partyTelemetry);
    updatedTelemetry[character.id.slug] = telemetry;
    updatedTelemetry[name] = telemetry;

    final updatedShared =
        Map<String, Map<String, dynamic>>.from(lobby.sharedCharacters);
    updatedShared[character.id.slug] = telemetry.toMap();
    updatedShared[name] = telemetry.toMap();

    final updatedLobby = lobby.copyWith(
      partyTelemetry: updatedTelemetry,
      sharedCharacters: updatedShared,
      lastUpdated: DateTime.now(),
    );
    _localLobbies[clean] = updatedLobby;

    final current = _buildSessionState(updatedLobby, profile);
    _localRooms[clean] = current;
    _emitSession(clean);

    // 3. P4: Write ONLY this character's keys to Firestore, and NO memberPurses
    if (isFirebaseAvailable) {
      try {
        final docRef =
            FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'partyTelemetry': {
            character.id.slug: telemetry.toMap(),
          },
          'sharedCharacters': {
            character.id.slug: character.toMap(),
          },
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore updateCharacterTelemetry failed for $clean');
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
      if (cleanCode.startsWith('ROOM-'))
        cleanCode.replaceFirst('ROOM-', '')
      else
        'ROOM-$cleanCode',
      if (cleanCode.startsWith('ROOM_'))
        cleanCode.replaceFirst('ROOM_', '')
      else
        'ROOM_$cleanCode',
    }.toList();

    PartySessionState? session;
    String matchedCode = cleanCode;

    if (isFirebaseAvailable) {
      for (final code in codeCandidates) {
        try {
          final docRef =
              FirebaseFirestore.instance.collection('rooms').doc(code);
          final snapshot = await docRef.get();
          if (snapshot.exists && snapshot.data() != null) {
            session = PartySessionState.fromMap(snapshot.data()!);
            matchedCode = code;
            break;
          }
        } catch (e, stackTrace) {
          LoggingService().logNonFatal(e, stackTrace,
              reason: 'Firestore check failed for room $code');
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
          throw UnauthorizedHostActionException(
              'Invalid DM passkey. Please check the code provided by your Dungeon Master.');
        }
      }

      final existing = _registry.getMembership(matchedCode);
      final charName = (playerName != null && playerName.trim().isNotEmpty)
          ? playerName.trim()
          : (existing?.characterId ?? 'DM');

      final updated = (existing ??
              CampaignMembership(
                roomCode: matchedCode,
                campaignName: session.campaignName,
                lastPlayed: DateTime.now(),
              ))
          .copyWith(
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
    PartyRoomLobby? existingLobby = _localLobbies[cleanCode];
    existingLobby ??= await _fetchRoomLobbyFromFirestore(cleanCode);

    final cName =
        campaignName ?? existingLobby?.campaignName ?? 'Rehydrated Campaign';

    final lobby = existingLobby != null
        ? existingLobby.copyWith(
            campaignName: cName,
            hostKeyHash: hostKeyHash,
            activePlayers: [playerName],
            version: existingLobby.version + 1,
            lastUpdated: now,
            expiresAt: expiresAt,
          )
        : PartyRoomLobby(
            roomCode: cleanCode,
            campaignName: cName,
            hostKeyHash: hostKeyHash,
            activePlayers: [playerName],
            version: 1,
            lastUpdated: now,
            expiresAt: expiresAt,
          );

    final resolvedCampaignId = campaignIdForRoom(lobby);
    final profile = await openRoomProfile(
      cleanCode,
      resolvedCampaignId,
      lobby.rulesetId,
    );

    _localLobbies[cleanCode] = lobby;
    final rehydrated = _buildSessionState(lobby, profile);
    _localRooms[cleanCode] = rehydrated;
    _emitSession(cleanCode);

    if (isFirebaseAvailable) {
      try {
        final docRef =
            FirebaseFirestore.instance.collection('rooms').doc(cleanCode);
        await docRef.set(lobby.toMap(), SetOptions(merge: true));

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
      details:
          'Campaign rehydrated and renewed with fresh 30-day cloud lease by DM ($playerName).',
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

    // 2. Profile and in-memory update
    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = _resolveSlugForName(trimmedPlayer, lobby, profile);

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      return p.copyWith(
        partyRoster: p.partyRoster.remove(slug, _clock.nextTimestamp()),
      );
    });

    final updatedPlayers = List<String>.from(lobby.activePlayers)
      ..remove(trimmedPlayer);
    final updatedLobby = lobby.copyWith(activePlayers: updatedPlayers);
    _localLobbies[clean] = updatedLobby;

    final current = _buildSessionState(updatedLobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

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
        final docRef =
            FirebaseFirestore.instance.collection('rooms').doc(clean);
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          'campaignName': current.campaignName,
          'activePlayers': FieldValue.arrayRemove([trimmedPlayer]),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore leaveCampaign failed for $clean');
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
        throw UnauthorizedHostActionException(
            'DM passkey is required to delete this campaign.');
      }
      final cleanKey = CryptoUtils.extractHostKey(keyToVerify);
      final actualHash = CryptoUtils.sha256Hex(cleanKey);
      if (actualHash != expectedHash) {
        throw UnauthorizedHostActionException(
            'Invalid DM passkey. Cannot delete campaign.');
      }
    }

    // 1. Server deletion with host proof (must succeed before mutating local state)
    if (isFirebaseAvailable) {
      try {
        await _roomDocPort.deleteRoomWithHostProof(
          roomCode: clean,
          hostKey: keyToVerify,
        );
      } on UnauthorizedHostActionException {
        rethrow;
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore deleteCampaign failed for $clean');
        rethrow;
      }
    }

    // 2. Remove from local membership registry
    await _registry.removeMembership(clean);

    // 3. In-memory cleanup
    _localRooms.remove(clean);
    _localLobbies.remove(clean);
    _localLoot.remove(clean);
    _localEvents.remove(clean);
    _outbox.remove(clean);
    _sessionSubscriptions[clean]?.cancel();
    _sessionSubscriptions.remove(clean);
    _sessionControllers[clean]?.close();
    _sessionControllers.remove(clean);
    _updateOutboxCount();
    _emitSession(clean);

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
          LoggingService().logNonFatal(e, st,
              reason:
                  'Failed to sync existing campaign ${m.roomCode} to Firestore');
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'syncAllExistingCampaignsToFirestore error');
    }
  }

  // =========================================================================
  // 3. SUBCOLLECTION-BASED STREAMING
  // =========================================================================

  /// Returns the current in-memory cached state of a room if available
  PartySessionState? getCachedSession(String roomCode) {
    final clean = roomCode.trim().toUpperCase();
    if (_localRooms.containsKey(clean)) {
      return _localRooms[clean];
    }
    final lobby = _localLobbies[clean];
    if (lobby != null) {
      final prof = _campaignProfileService.repo.allProfiles.where((p) {
        return p.roomState.roomCode.trim().toUpperCase() == clean;
      }).firstOrNull;
      if (prof != null) {
        final state = _buildSessionState(lobby, prof);
        _localRooms[clean] = state;
        return state;
      }
    }
    return null;
  }

  /// Returns the current in-memory cached lobby of a room if available
  PartyRoomLobby? getCachedLobby(String roomCode) {
    return _localLobbies[roomCode.trim().toUpperCase()];
  }

  @visibleForTesting
  void cacheLobbyForTesting(PartyRoomLobby lobby) {
    _localLobbies[lobby.roomCode.trim().toUpperCase()] = lobby;
  }

  /// Fetches or retrieves the lobby for a room
  Future<PartyRoomLobby> getLobby(String roomCode) {
    return _getOrFetchLobby(roomCode);
  }

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
            .listen((snap) async {
          if (!snap.exists || snap.data() == null) {
            if (!controller.isClosed) controller.add(null);
            return;
          }
          try {
            final lobby = PartyRoomLobby.fromMap(snap.data()!);
            _localLobbies[clean] = lobby;
            final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
            final state = _buildSessionState(lobby, profile);
            _localRooms[clean] = state;
            if (!controller.isClosed) controller.add(state);
          } catch (e, st) {
            LoggingService().logNonFatal(e, st,
                reason: 'PartyRoomLobby snapshot error for $clean');
            if (!controller.isClosed && _localRooms.containsKey(clean)) {
              controller.add(_localRooms[clean]);
            }
          }
        }, onError: (e, st) {
          LoggingService()
              .logNonFatal(e, st, reason: 'streamSession error for $clean');
          if (!controller.isClosed && _localRooms.containsKey(clean)) {
            controller.add(_localRooms[clean]);
          }
        });
      });
    }

    Future.microtask(() async {
      if (!controller.isClosed) {
        if (_localRooms.containsKey(clean)) {
          controller.add(_localRooms[clean]);
        } else {
          try {
            final lobby = await _getOrFetchLobby(clean);
            final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
            final state = _buildSessionState(lobby, profile);
            _localRooms[clean] = state;
            if (!controller.isClosed) controller.add(state);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to build session state for room $clean in watchSession',
            );
          }
        }
      }
    });
    return controller.stream;
  }

  /// Stream loot items from /rooms/{roomCode}/loot/{lootId}
  Stream<List<PartyLootItem>> streamLoot(String roomCode,
      {bool includeArchived = false}) {
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
          final items = snapshot.docs
              .map((d) => PartyLootItem.fromMap(d.data()))
              .toList();
          final lootMap = _localLoot.putIfAbsent(clean, () => {});
          for (final item in items) {
            lootMap[item.id] = item;
          }
          return items;
        }).handleError((e, st) {
          LoggingService()
              .logNonFatal(e, st, reason: 'streamLoot error for $clean');
          final list = _localLoot[clean]?.values.toList() ?? [];
          return includeArchived
              ? list
              : list.where((i) => !i.isArchived).toList();
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore streamLoot init failed for $clean');
      }
    }

    final controller = _lootControllers.putIfAbsent(
      clean,
      () => StreamController<List<PartyLootItem>>.broadcast(),
    );
    Future.microtask(() {
      if (!controller.isClosed) {
        final list = _localLoot[clean]?.values.toList() ?? [];
        controller.add(
            includeArchived ? list : list.where((i) => !i.isArchived).toList());
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
          final events =
              snap.docs.map((d) => PartyEvent.fromMap(d.data())).toList();
          _localEvents[clean] = events;
          return events;
        }).handleError((e, st) {
          LoggingService()
              .logNonFatal(e, st, reason: 'streamEvents error for $clean');
          return _localEvents[clean] ?? [];
        });
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore streamEvents init failed for $clean');
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
        partyPurse: const PartyPurse.empty(),
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
      final lobby = _localLobbies[clean];
      if (lobby != null) {
        _localLobbies[clean] = lobby.copyWith(activePlayers: updatedPlayers);
      }
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
        final docRef =
            FirebaseFirestore.instance.collection('rooms').doc(clean);
        final session = _localRooms[clean];
        await docRef.set({
          'roomCode': clean,
          'code': clean,
          if (session != null) 'campaignName': session.campaignName,
          'activePlayers': FieldValue.arrayUnion([trimmedName]),
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e, st) {
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore setActiveCharacter failed for $clean');
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

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = _resolveSlugForName(trimmed, lobby, profile);

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      final updatedRoster =
          p.partyRoster.add(slug, slug, _clock.nextTimestamp());
      return p.copyWith(partyRoster: updatedRoster);
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    await logEvent(
      roomCode: clean,
      type: 'rosterUpdate',
      playerName: playerName,
      details: '$playerName added "$trimmed" to the party roster',
    );
  }

  /// Removes a player/character name from the shared campaign roster.
  /// Moves the member's whole signed balance to the reserve in the same transform.
  Future<void> removeCharacterFromRoster({
    required String roomCode,
    required String characterName,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmed = characterName.trim();
    if (trimmed.isEmpty) return;

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = _resolveSlugForName(trimmed, lobby, profile);

    PartyPurse? deletedPurse;

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      deletedPurse = p.memberPurses[slug];
      return PartyLedgerOperations.removeMemberFromRoster(
        profile: p,
        characterSlug: slug,
        replicaId: replicaId,
        clock: _clock,
      );
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    final transferredSuffix = (deletedPurse != null && !deletedPurse!.isEmpty)
        ? ' (transferred ~${deletedPurse!.totalGpEquivalent.toStringAsFixed(1)} GP to Party Reserve)'
        : '';
    await logEvent(
      roomCode: clean,
      type: 'rosterUpdate',
      playerName: playerName,
      details:
          '$playerName removed "$trimmed" from the party roster$transferredSuffix',
    );
  }

  /// Updates the complete campaign character roster.
  Future<void> updateCharacterRoster({
    required String roomCode,
    required List<String> roster,
    required String playerName,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final cleanedRoster =
        roster.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final targetSlugs =
        cleanedRoster.map((s) => _resolveSlugForName(s, lobby, profile)).toSet();

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      return PartyLedgerOperations.restoreMembersToRoster(
        profile: p,
        targetSlugs: targetSlugs,
        replicaId: replicaId,
        clock: _clock,
      );
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    await logEvent(
      roomCode: clean,
      type: 'rosterUpdate',
      playerName: playerName,
      details:
          '$playerName updated the party roster (${cleanedRoster.length} members)',
    );
  }

  // =========================================================================
  // 4. ATOMIC COIN OPERATIONS & MERGING
  // =========================================================================

  /// Atomically deposits coins to the party purse via campaign profile CRDT
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
    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      return PartyLedgerOperations.depositToReserve(
        profile: p,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        replicaId: replicaId,
      );
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    // Audit Event
    final coinParts = <String>[];
    if (pp > 0) coinParts.add('+$pp PP');
    if (gp > 0) coinParts.add('+$gp GP');
    if (ep > 0) coinParts.add('+$ep EP');
    if (sp > 0) coinParts.add('+$sp SP');
    if (cp > 0) coinParts.add('+$cp CP');
    final desc = coinParts.join(', ') +
        (note != null && note.isNotEmpty ? ' ($note)' : '');

    await logEvent(
      roomCode: clean,
      type: 'coinDeposit',
      playerName: playerName,
      details: '$playerName deposited $desc',
    );
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
    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final currentDisplay = _buildSessionState(lobby, profile);

    // Detect overdrafts comparing against displayed balance before update
    final overdrafts = <String>[];
    if (pp > currentDisplay.partyPurse.pp) {
      overdrafts.add('PP (tried -$pp, had ${currentDisplay.partyPurse.pp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'PP',
        requestedDeduct: pp,
        previousBalance: currentDisplay.partyPurse.pp,
        playerName: playerName,
      ));
    }
    if (gp > currentDisplay.partyPurse.gp) {
      overdrafts.add('GP (tried -$gp, had ${currentDisplay.partyPurse.gp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'GP',
        requestedDeduct: gp,
        previousBalance: currentDisplay.partyPurse.gp,
        playerName: playerName,
      ));
    }
    if (ep > currentDisplay.partyPurse.ep) {
      overdrafts.add('EP (tried -$ep, had ${currentDisplay.partyPurse.ep})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'EP',
        requestedDeduct: ep,
        previousBalance: currentDisplay.partyPurse.ep,
        playerName: playerName,
      ));
    }
    if (sp > currentDisplay.partyPurse.sp) {
      overdrafts.add('SP (tried -$sp, had ${currentDisplay.partyPurse.sp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'SP',
        requestedDeduct: sp,
        previousBalance: currentDisplay.partyPurse.sp,
        playerName: playerName,
      ));
    }
    if (cp > currentDisplay.partyPurse.cp) {
      overdrafts.add('CP (tried -$cp, had ${currentDisplay.partyPurse.cp})');
      _overdraftController.add(PurseOverdraftEvent(
        roomCode: clean,
        denomination: 'CP',
        requestedDeduct: cp,
        previousBalance: currentDisplay.partyPurse.cp,
        playerName: playerName,
      ));
    }

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      return PartyLedgerOperations.withdrawFromReserve(
        profile: p,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        replicaId: replicaId,
      );
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    // Audit Event
    final coinParts = <String>[];
    if (pp > 0) coinParts.add('-$pp PP');
    if (gp > 0) coinParts.add('-$gp GP');
    if (ep > 0) coinParts.add('-$ep EP');
    if (sp > 0) coinParts.add('-$sp SP');
    if (cp > 0) coinParts.add('-$cp CP');
    final desc = coinParts.join(', ') +
        (note != null && note.isNotEmpty ? ' ($note)' : '');

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
        details:
            'Purse overdraft: ${overdrafts.join(', ')} clamped to 0 after spend by $playerName',
      );
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
          if (c.id.slug.toLowerCase() ==
              membership!.characterId!.toLowerCase()) {
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
          replicaId: replicaId,
        );
        final updatedChar = matched.copyWith(purse: updatedPurse);
        await _characterPersistenceService.saveCharacter(updatedChar);

        final clean = roomCode.trim().toUpperCase();
        final current = _localRooms[clean];
        if (current != null) {
          final updatedShared =
              Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
          updatedShared[updatedChar.id.slug] = updatedChar.toMap();
          updatedShared[characterIdentifier] = updatedChar.toMap();
          _localRooms[clean] = current.copyWith(
            sharedCharacters: updatedShared,
          );
          final lobby = _localLobbies[clean];
          if (lobby != null) {
            _localLobbies[clean] =
                lobby.copyWith(sharedCharacters: updatedShared);
          }
          if (emitSession) {
            _emitSession(clean);
          }
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to sync coins to character $characterIdentifier');
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
          if (c.id.slug.toLowerCase() ==
              membership!.characterId!.toLowerCase()) {
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
          final updatedShared =
              Map<String, Map<String, dynamic>>.from(current.sharedCharacters);
          updatedShared[updatedChar.id.slug] = updatedChar.toMap();
          updatedShared[characterIdentifier] = updatedChar.toMap();
          _localRooms[clean] = current.copyWith(
            sharedCharacters: updatedShared,
          );
          final lobby = _localLobbies[clean];
          if (lobby != null) {
            _localLobbies[clean] =
                lobby.copyWith(sharedCharacters: updatedShared);
          }
          _emitSession(clean);
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason:
              'Failed to sync purse override to character $characterIdentifier');
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
            if (c.id.slug.toLowerCase() ==
                membership!.characterId!.toLowerCase()) {
              matched = c;
              break;
            }
          }
        }

        if (matched != null) {
          final itemSlug =
              item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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

          final updatedInventory =
              List<InventoryItemInstance>.from(matched.inventory)
                ..removeWhere((i) => i.instanceId == instanceId)
                ..add(instance);

          final updatedChar = matched.copyWith(inventory: updatedInventory);
          await _characterPersistenceService.saveCharacter(updatedChar);

          final current = _localRooms[cleanRoom];
          if (current != null) {
            final updatedShared = Map<String, Map<String, dynamic>>.from(
                current.sharedCharacters);
            updatedShared[updatedChar.id.slug] = updatedChar.toMap();
            _localRooms[cleanRoom] =
                current.copyWith(sharedCharacters: updatedShared);
            _emitSession(cleanRoom);
          }
        }
      } else {
        // Returned to vault: remove item instance from any character
        for (final c in allChars) {
          if (c.inventory.any((i) => i.instanceId == instanceId)) {
            final updatedInv =
                c.inventory.where((i) => i.instanceId != instanceId).toList();
            final updatedChar = c.copyWith(inventory: updatedInv);
            await _characterPersistenceService.saveCharacter(updatedChar);

            final current = _localRooms[cleanRoom];
            if (current != null) {
              final updatedShared = Map<String, Map<String, dynamic>>.from(
                  current.sharedCharacters);
              updatedShared[updatedChar.id.slug] = updatedChar.toMap();
              _localRooms[cleanRoom] =
                  current.copyWith(sharedCharacters: updatedShared);
              _emitSession(cleanRoom);
            }
          }
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to sync loot claim for item ${item.id}');
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
    final recipients = recipientCharacters
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (recipients.isEmpty && !includePartyReserve) return;

    final shareCount = recipients.length + (includePartyReserve ? 1 : 0);
    if (shareCount <= 0) return;

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );

    final perRecipientSyncs = <String, Map<String, int>>{};

    final recipientSlugs =
        recipients.map((r) => _resolveSlugForName(r, lobby, profile)).toList();

    if (includeLiquidatedInSplit && liquidatedGemsAndArtGp > 0) {
      final totalGp =
          purseToDisperse.totalGpEquivalent + liquidatedGemsAndArtGp;
      final perShareGp = (totalGp / shareCount).floor();
      for (final recipient in recipients) {
        perRecipientSyncs[recipient] = {'gp': perShareGp};
      }
    } else {
      final ppPerShare = purseToDisperse.pp ~/ shareCount;
      final gpPerShare = purseToDisperse.gp ~/ shareCount;
      final epPerShare = purseToDisperse.ep ~/ shareCount;
      final spPerShare = purseToDisperse.sp ~/ shareCount;
      final cpPerShare = purseToDisperse.cp ~/ shareCount;
      for (final recipient in recipients) {
        perRecipientSyncs[recipient] = {
          'pp': ppPerShare,
          'gp': gpPerShare,
          'ep': epPerShare,
          'sp': spPerShare,
          'cp': cpPerShare,
        };
      }
    }

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      final dispersed = PartyLedgerOperations.disperseCoins(
        profile: p,
        purseToDisperse: purseToDisperse,
        recipientSlugs: recipientSlugs,
        replicaId: replicaId,
        includePartyReserve: includePartyReserve,
        liquidatedGemsAndArtGp: liquidatedGemsAndArtGp,
        includeLiquidatedInSplit: includeLiquidatedInSplit,
        isVaultDispersal: isVaultDispersal,
      );

      var updatedRoster = dispersed.partyRoster;
      for (final slug in recipientSlugs) {
        if (!updatedRoster.activeValues.contains(slug)) {
          updatedRoster = updatedRoster.add(slug, slug, _clock.nextTimestamp());
        }
      }

      return dispersed.copyWith(partyRoster: updatedRoster);
    });

    // Mirror to local character persistence
    for (final entry in perRecipientSyncs.entries) {
      final coins = entry.value;
      await _syncCoinsToCharacter(
        roomCode: clean,
        characterIdentifier: entry.key,
        pp: coins['pp'] ?? 0,
        gp: coins['gp'] ?? 0,
        ep: coins['ep'] ?? 0,
        sp: coins['sp'] ?? 0,
        cp: coins['cp'] ?? 0,
        emitSession: false,
      );
    }

    final updatedLobby = _localLobbies[clean] ?? lobby;
    final current = _buildSessionState(updatedLobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    final totalGpVal = purseToDisperse.totalGpEquivalent +
        (includeLiquidatedInSplit ? liquidatedGemsAndArtGp : 0);
    final reserveSuffix =
        includePartyReserve ? ' (+ 1 share to Party Reserve)' : '';
    final desc =
        '$performedBy dispersed ~${totalGpVal.toStringAsFixed(1)} GP across ${recipients.length} characters$reserveSuffix';

    await logEvent(
      roomCode: clean,
      type: 'lootDispersal',
      playerName: performedBy,
      details: desc,
    );
  }

  /// Direct deposit/withdraw/update to an individual character's personal coin purse
  Future<void> updateMemberPurse({
    required String roomCode,
    required String characterName,
    String? characterSlug,
    required PartyPurse newPurse,
    required String performedBy,
    String? note,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final trimmedName = characterName.trim();
    if (trimmedName.isEmpty && (characterSlug == null || characterSlug.trim().isEmpty)) return;

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = (characterSlug != null && characterSlug.trim().isNotEmpty)
        ? characterSlug.trim()
        : _resolveSlugForName(trimmedName, lobby, profile);

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      return PartyLedgerOperations.overrideMemberPurse(
        profile: p,
        characterSlug: slug,
        newPurse: newPurse,
        replicaId: replicaId,
        clock: _clock,
      );
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    await _syncPurseOverrideToCharacter(
      roomCode: clean,
      characterIdentifier: slug.isNotEmpty ? slug : trimmedName,
      newPurse: newPurse,
    );

    final noteSuffix = note != null ? ' ($note)' : '';
    await logEvent(
      roomCode: clean,
      type: 'memberPurseUpdate',
      playerName: performedBy,
      details:
          '$performedBy updated personal purse for $trimmedName (~${newPurse.totalGpEquivalent.toStringAsFixed(1)} GP)$noteSuffix',
    );
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

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = _resolveSlugForName(trimmedName, lobby, profile);

    PartyPurse updatedMemberPurse = const PartyPurse.empty();

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      final res = PartyLedgerOperations.transferMemberToReserve(
        profile: p,
        characterSlug: slug,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        replicaId: replicaId,
        clock: _clock,
      );
      updatedMemberPurse = res.memberPurses[slug] ?? const PartyPurse.empty();
      return res;
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    await _syncPurseOverrideToCharacter(
      roomCode: clean,
      characterIdentifier: trimmedName,
      newPurse: updatedMemberPurse,
    );

    final desc =
        '$performedBy transferred coins from $trimmedName to Party Reserve ($gp GP, $sp SP, $cp CP)';
    await logEvent(
      roomCode: clean,
      type: 'coinTransfer',
      playerName: performedBy,
      details: desc,
    );
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

    final lobby = await _getOrFetchLobby(clean);
    final profile = await profileForRoom(
      clean,
      lobbyCampaignId: lobby.campaignId,
      allowCreate: false,
    );
    final slug = _resolveSlugForName(trimmedName, lobby, profile);

    PartyPurse updatedMemberPurse = const PartyPurse.empty();

    final updatedProfile =
        await _campaignProfileService.repo.updateProfile(profile.id, (p) {
      final res = PartyLedgerOperations.transferReserveToMember(
        profile: p,
        characterSlug: slug,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        replicaId: replicaId,
        clock: _clock,
      );
      updatedMemberPurse = res.memberPurses[slug] ?? const PartyPurse.empty();
      return res;
    });

    final current = _buildSessionState(lobby, updatedProfile);
    _localRooms[clean] = current;
    _emitSession(clean);

    await _syncPurseOverrideToCharacter(
      roomCode: clean,
      characterIdentifier: trimmedName,
      newPurse: updatedMemberPurse,
    );

    final desc =
        '$performedBy withdrew coins from Party Reserve to $trimmedName ($gp GP, $sp SP, $cp CP)';
    await logEvent(
      roomCode: clean,
      type: 'coinTransfer',
      playerName: performedBy,
      details: desc,
    );
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
      details:
          '$playerName added ${item.count}x "${item.name}" to the vault (${item.gpValue} GP each).',
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
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore addLootItem failed; queuing outbox');
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
      item: existing ??
          PartyLootItem(
              id: lootId,
              name: lootId,
              createdAt: DateTime.now(),
              expiresAt: DateTime.now()),
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
              final restored =
                  existing?.copyWith(claimedByPlayer: remoteWinner) ??
                      PartyLootItem.fromMap(remoteData!);
              lootMap?[lootId] = restored;
              _emitLoot(clean);

              await _syncLootClaimToCharacter(
                roomCode: clean,
                item: restored,
                claimingPlayer: remoteWinner,
              );

              final itemName =
                  existing?.name ?? (remoteData?['name'] as String? ?? 'Item');
              await logEvent(
                roomCode: clean,
                type: 'claimConflict',
                playerName: playerName,
                details:
                    'Claim conflict on "$itemName": assigned to $remoteWinner (first to server)',
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
        LoggingService().logNonFatal(e, st,
            reason: 'Firestore claimLootItem failed; queuing outbox');
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
  void flagItemConflict(
      String roomCode, String lootId, Map<String, dynamic> remotePayload) {
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
      final cloudItem =
          PartyLootItem.fromMap(existing.conflictPayload!).copyWith(
        clearConflict: true,
      );
      lootMap![lootId] = cloudItem;
      _emitLoot(clean);

      await logEvent(
        roomCode: clean,
        type: 'conflictResolution',
        playerName: playerName,
        details:
            'DM $playerName resolved conflict: accepted Cloud Version for "${cloudItem.name}".',
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
          LoggingService().logNonFatal(e, st,
              reason: 'Firestore resolveConflictWithCloud failed');
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
        details:
            'DM $playerName resolved conflict: overwrote cloud with Local Version of "${resolved.name}".',
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
          LoggingService().logNonFatal(e, st,
              reason: 'Firestore resolveConflictWithLocal failed');
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
          ? PartyLootItem.fromMap(existing.conflictPayload!)
              .copyWith(clearConflict: true)
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
        details:
            'DM $playerName resolved conflict: kept both "${cloudItem.name}" and "${localCopy.name}".',
      );

      if (isFirebaseAvailable) {
        try {
          final batch = FirebaseFirestore.instance.batch();
          final roomDoc =
              FirebaseFirestore.instance.collection('rooms').doc(clean);
          batch.set(roomDoc.collection('loot').doc(lootId), cloudItem.toMap());
          batch.set(roomDoc.collection('loot').doc(copyId), localCopy.toMap());
          await batch.commit();
        } catch (e, st) {
          LoggingService().logNonFatal(e, st,
              reason: 'Firestore resolveConflictKeepBoth failed');
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
      details:
          '$playerName ${isAttuned ? 'attuned to' : 'broke attunement with'} "${existing?.name ?? lootId}".',
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
        LoggingService()
            .logNonFatal(e, st, reason: 'Firestore toggleAttunement failed');
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
        LoggingService()
            .logNonFatal(e, st, reason: 'Firestore archiveLootItem failed');
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
      details:
          'DM $playerName restored "${existing?.name ?? lootId}" from trash.',
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
        LoggingService()
            .logNonFatal(e, st, reason: 'Firestore restoreLootItem failed');
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
    final eventId =
        'evt_${DateTime.now().millisecondsSinceEpoch}_${secureRandom.nextInt(9999)}';
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
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to write event $eventId to room $clean',
        );
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
    final List<PartyOutboxAction> batchActions = [];

    for (final action in toProcess) {
      if (action.actionType == 'createRoom') {
        try {
          await _roomDocPort.createRoom(
            roomCode: clean,
            data: action.payload,
          );
          pending.remove(action);
          _updateOutboxCount();
        } on RoomAlreadyExistsException catch (e, st) {
          // Document now exists: drop that action from outbox and log as fault
          LoggingService().logNonFatal(
            e,
            st,
            reason:
                'Dropping createRoom outbox replay: room $clean already exists',
          );
          pending.remove(action);
          _updateOutboxCount();
        } catch (e, st) {
          LoggingService().logNonFatal(e, st,
              reason: 'createRoom outbox replay failed for room $clean');
          action.retryCount++;
          if (action.retryCount >= 3) {
            pending.remove(action);
            _updateOutboxCount();
          }
        }
      } else {
        batchActions.add(action);
      }
    }

    if (batchActions.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final docRef = FirebaseFirestore.instance.collection('rooms').doc(clean);

    for (final action in batchActions) {
      if (action.actionType == 'addLoot') {
        final lootDoc =
            docRef.collection('loot').doc(action.payload['id'] as String);
        batch.set(lootDoc, action.payload);
      } else if (action.actionType == 'claimLoot') {
        final lootDoc =
            docRef.collection('loot').doc(action.payload['lootId'] as String);
        batch.set(
            lootDoc,
            {'claimedByPlayer': action.payload['claimedByPlayer']},
            SetOptions(merge: true));
      }
    }

    try {
      await batch.commit();
      pending.removeWhere((a) => batchActions.contains(a));
      _updateOutboxCount();
    } catch (e, st) {
      LoggingService()
          .logNonFatal(e, st, reason: 'Failed to flush outbox for room $clean');
      for (final action in batchActions) {
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
