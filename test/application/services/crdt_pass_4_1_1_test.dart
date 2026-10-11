import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/aggregate_hlc_extractor.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';

class _FakeCharRepo implements ICharacterRepository<Character> {
  final Map<String, Character> _storage = {};
  @override
  Future<List<Character>> loadCharacters() async => _storage.values.toList();
  @override
  Future<void> saveCharacter(Character c) async => _storage[c.id.slug] = c;
  @override
  Future<void> saveCharacters(List<Character> list) async {
    for (final c in list) {
      _storage[c.id.slug] = c;
    }
  }
  @override
  Future<void> saveRoster(List<Character> r) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async {
    _storage.remove(slug);
    return _storage.values.toList();
  }
  @override
  Future<Character?> getCharacter(String id) async => _storage[id];
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async =>
      ids.map((id) => _storage[id]).whereType<Character>().toList();
  @override
  Future<String?> loadActiveCharacterId() async => null;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<Character> reparseCharacter(Character c) async => c;
  @override
  Future<List<Character>> reparseAllCharacters() async => _storage.values.toList();
}

class _MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incoming = StreamController<String>.broadcast();
  @override
  TransportState currentState = TransportState.webRtc;
  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);
  @override
  Map<String, int> peerLastSeen = {};
  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }
  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;
  @override
  Future<void> prepareSession() async {}
  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;
  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}
  @override
  Future<void> disconnect() async {
    await _incoming.close();
  }
  void dispose() {
    _incoming.close();
  }
}

class _MockNetworkTimePort implements INetworkTimePort {
  final int networkTimeMs;
  _MockNetworkTimePort({required this.networkTimeMs});
  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

Character _createTestChar(String slug, String name) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    speciesRef: const EntityReference.empty(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage — Pass 4.1.1: New-CRDT Boundary & Authoritative Deserialization Tests', () {
    final testReplica = ReplicaId('node_test_411');
    late StatefulHlcClock clock;
    late LocalCampaignRepository campaignRepo;
    late _FakeCharRepo characterRepo;
    late CampaignProfileService profileService;
    late CharacterPersistenceService charPersistence;
    late RoomStateReconciliationService reconciliationService;
    late RoomSyncPayloadMapper payloadMapper;
    late _MockTransportPort mockTransport;
    late ClockSyncService clockSync;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppServices.reset();
      sl.reset();

      CampaignProfileService.resetForTesting();

      await AppDatabaseService.instance.resetForTesting();

      clock = StatefulHlcClock(
        replicaId: testReplica,
        maxFutureDrift: const Duration(minutes: 5),
      );
      sl.registerSingleton<ReplicaId>(testReplica);
      sl.registerSingleton<StatefulHlcClock>(clock);

      characterRepo = _FakeCharRepo();
      sl.registerSingleton<ICharacterRepository>(characterRepo);

      campaignRepo = LocalCampaignRepository(
        replicaId: testReplica,
        clock: clock,
        characterRepo: characterRepo,
      );
      sl.registerSingleton<ICampaignRepository>(campaignRepo);

      profileService = CampaignProfileService(
        replicaId: testReplica,
      );
      charPersistence = CharacterPersistenceService();
      reconciliationService = RoomStateReconciliationService();
      payloadMapper = const RoomSyncPayloadMapper();

      mockTransport = _MockTransportPort();
      clockSync = ClockSyncService(
        networkTimePort: _MockNetworkTimePort(networkTimeMs: DateTime.now().millisecondsSinceEpoch),
      );
    });

    tearDown(() {
      mockTransport.dispose();
      sl.reset();
    });

    test('B. Remote drift regression for pinnedRules: far-future item or tombstone HLC rejected before reconciliation', () async {
      final orchestrator = RoomSyncOrchestrator(
        replicaId: testReplica,
        transportPort: mockTransport,
        campaignRepo: campaignRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSync,
        clock: clock,
        payloadMapper: payloadMapper,
      );
      addTearDown(orchestrator.dispose);

      final initialProfile = CampaignProfile.raw(
        id: 'camp_drift_test',
        name: 'Drift Campaign',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        roomState: RoomNodeState(
          roomId: 'room_drift',
          roomCode: 'DRIFT1',
          title: 'Drift Room',
        ),
      );
      await campaignRepo.saveProfileImmediate(initialProfile);
      await campaignRepo.setActiveProfileId('camp_drift_test');

      final deadLetters = <SyncErrorEvent>[];
      orchestrator.deadLetterStream.listen(deadLetters.add);

      final initialClockTs = clock.latest;

      // Inbound remote profile with pinnedRules item HLC 10 years in the future
      final farFutureItemHlc = HybridLogicalClock(
        physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(days: 3650).inMilliseconds,
        logicalCounter: 0,
        nodeId: 'remote_malicious',
      );
      final badItemRules = CrdtOrSet<String>(
        items: {
          'evil_rule': CrdtLwwRegister<String>(
            value: 'evil_rule',
            timestamp: farFutureItemHlc,
          ),
        },
      );
      final remoteProfileBadItem = initialProfile.copyWith(pinnedRules: badItemRules);
      final payloadBadItem = payloadMapper.serializeFullProfileSync(
        profile: remoteProfileBadItem,
        originNodeId: 'remote_peer',
        originSeq: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await orchestrator.handleIncomingPayload(payloadBadItem);

      expect(deadLetters.length, equals(1));
      expect(deadLetters.first.error, isA<HlcFutureDriftException>());
      expect(clock.latest, equals(initialClockTs), reason: 'Clock must not advance on rejected remote drift');
      expect(campaignRepo.activeProfile!.pinnedRules.activeValues, isEmpty);

      // Inbound remote profile with pinnedRules tombstone HLC 10 years in the future
      final farFutureTombstoneHlc = HybridLogicalClock(
        physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(days: 3650).inMilliseconds,
        logicalCounter: 0,
        nodeId: 'remote_malicious',
      );
      final badTombstoneRules = CrdtOrSet<String>(
        tombstones: {
          'tombstoned_rule': farFutureTombstoneHlc,
        },
      );
      final remoteProfileBadTombstone = initialProfile.copyWith(pinnedRules: badTombstoneRules);
      final payloadBadTombstone = payloadMapper.serializeFullProfileSync(
        profile: remoteProfileBadTombstone,
        originNodeId: 'remote_peer',
        originSeq: 2,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await orchestrator.handleIncomingPayload(payloadBadTombstone);

      expect(deadLetters.length, equals(2));
      expect(deadLetters.last.error, isA<HlcFutureDriftException>());
      expect(clock.latest, equals(initialClockTs));
    });

    test('C. Remote drift regression for entityLinksCrdt: far-future item or tombstone rejected before reconciliation', () async {
      final orchestrator = RoomSyncOrchestrator(
        replicaId: testReplica,
        transportPort: mockTransport,
        campaignRepo: campaignRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSync,
        clock: clock,
        payloadMapper: payloadMapper,
      );
      addTearDown(orchestrator.dispose);

      final initialProfile = CampaignProfile.raw(
        id: 'camp_links_drift',
        name: 'Links Drift Campaign',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        roomState: RoomNodeState(
          roomId: 'room_links',
          roomCode: 'LINKS1',
          title: 'Links Room',
        ),
      );
      await campaignRepo.saveProfileImmediate(initialProfile);
      await campaignRepo.setActiveProfileId('camp_links_drift');

      final deadLetters = <SyncErrorEvent>[];
      orchestrator.deadLetterStream.listen(deadLetters.add);
      final initialClockTs = clock.latest;

      // Far future entity link item HLC
      final farFutureLinkHlc = HybridLogicalClock(
        physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(days: 3650).inMilliseconds,
        logicalCounter: 0,
        nodeId: 'remote_malicious',
      );
      final badLinkCrdt = CrdtOrSet<RoomEntityLink>(
        items: {
          'evil_entity': CrdtLwwRegister<RoomEntityLink>(
            value: RoomEntityLink(entityId: 'evil_entity', displayName: 'Evil Entity'),
            timestamp: farFutureLinkHlc,
          ),
        },
      );
      final remoteBadRoom = initialProfile.roomState.copyWith(entityLinksCrdt: badLinkCrdt);
      final remoteProfileBadLink = initialProfile.copyWith(roomState: remoteBadRoom);
      final payloadBadLink = payloadMapper.serializeFullProfileSync(
        profile: remoteProfileBadLink,
        originNodeId: 'remote_peer',
        originSeq: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await orchestrator.handleIncomingPayload(payloadBadLink);

      expect(deadLetters.length, equals(1));
      expect(deadLetters.first.error, isA<HlcFutureDriftException>());
      expect(clock.latest, equals(initialClockTs));
      expect(campaignRepo.activeProfile!.roomState.entityLinks, isEmpty);

      // Far future entity link tombstone HLC
      final farFutureLinkTombstoneHlc = HybridLogicalClock(
        physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(days: 3650).inMilliseconds,
        logicalCounter: 0,
        nodeId: 'remote_malicious',
      );
      final badTombstoneLinkCrdt = CrdtOrSet<RoomEntityLink>(
        tombstones: {
          'tombstoned_entity': farFutureLinkTombstoneHlc,
        },
      );
      final remoteBadRoomTombstone = initialProfile.roomState.copyWith(entityLinksCrdt: badTombstoneLinkCrdt);
      final remoteProfileBadLinkTombstone = initialProfile.copyWith(roomState: remoteBadRoomTombstone);
      final payloadBadLinkTombstone = payloadMapper.serializeFullProfileSync(
        profile: remoteProfileBadLinkTombstone,
        originNodeId: 'remote_peer',
        originSeq: 2,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await orchestrator.handleIncomingPayload(payloadBadLinkTombstone);

      expect(deadLetters.length, equals(2));
      expect(deadLetters.last.error, isA<HlcFutureDriftException>());
      expect(clock.latest, equals(initialClockTs));
    });

    test('D. Trusted local history observation: historical pinnedRules and entityLinksCrdt observed causally without drift rejection', () async {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final tsPinned = HybridLogicalClock(
        physicalTime: nowMs + const Duration(hours: 6).inMilliseconds,
        logicalCounter: 10,
        nodeId: 'past_author',
      );
      final tsLink = HybridLogicalClock(
        physicalTime: nowMs + const Duration(hours: 8).inMilliseconds,
        logicalCounter: 20,
        nodeId: 'past_author',
      );

      final trustedProfile = CampaignProfile.raw(
        id: 'camp_trusted_history',
        name: 'Trusted History',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        pinnedRules: CrdtOrSet<String>(
          items: {
            'cover': CrdtLwwRegister<String>(value: 'cover', timestamp: tsPinned),
          },
        ),
        roomState: RoomNodeState(
          roomId: 'room_trusted',
          roomCode: 'TRUST1',
          title: 'Trusted Room',
          entityLinksCrdt: CrdtOrSet<RoomEntityLink>(
            items: {
              'hero': CrdtLwwRegister<RoomEntityLink>(
                value: RoomEntityLink(entityId: 'hero', displayName: 'Hero'),
                timestamp: tsLink,
              ),
            },
          ),
        ),
      );

      // Persist directly to database simulating valid local disk history
      final dto = CampaignProfileDto.fromDomain(trustedProfile);
      final db = AppDatabaseService.instance;
      await db.put(AppDatabaseService.boxCampaignProfiles, '${LocalCampaignRepository.profileKeyPrefix}camp_trusted_history', dto.toJson());
      await db.put(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey, ['camp_trusted_history']);
      await db.put(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.activeProfileIdKey, 'camp_trusted_history');

      // Fresh repository initialized with clean runtime clock
      final freshClock = StatefulHlcClock(
        replicaId: ReplicaId('fresh_runtime_replica'),
        maxFutureDrift: const Duration(minutes: 5),
      );
      final freshRepo = LocalCampaignRepository(
        replicaId: ReplicaId('fresh_runtime_replica'),
        clock: freshClock,
        characterRepo: characterRepo,
      );
      final loaded = await freshRepo.getActiveProfile();
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('camp_trusted_history'));
      expect(loaded.pinnedRuleIds, contains('cover'));
      expect(loaded.roomState.entityLinks.map((l) => l.entityId), contains('hero'));

      // Shared StatefulHlcClock observed both trusted histories causally
      final nextTs = freshClock.nextTimestamp();
      expect(nextTs.physicalTime, greaterThanOrEqualTo(tsLink.physicalTime));
      expect(nextTs.nodeId, equals('fresh_runtime_replica'));
    });

    test('G & H. Pinned-rule mutation produces tombstone, preserves CRDT history, and survives sync without resurrection', () async {
      final controller = DmDashboardController(
        replicaId: testReplica,
        clock: clock,
        campaignProfileService: profileService,
        characterPersistenceService: charPersistence,
      );

      final initialProfile = CampaignProfile.raw(
        id: 'camp_pin_mut',
        name: 'Pin Mutation Campaign',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        roomState: RoomNodeState(
          roomId: 'room_pm',
          roomCode: 'PM1',
          title: 'Room PM',
        ),
      );
      await profileService.saveProfileImmediate(initialProfile);
      await campaignRepo.saveProfileImmediate(initialProfile);
      await controller.switchProfile('camp_pin_mut');

      // Pin a rule
      await controller.togglePinnedRule('cover');
      expect(controller.activeProfile!.pinnedRuleIds, contains('cover'));
      expect(controller.activeProfile!.pinnedRules.tombstones.containsKey('cover'), isFalse);

      // Unpin the rule
      await controller.togglePinnedRule('cover');
      final unpinnedProfile = controller.activeProfile!;
      expect(unpinnedProfile.pinnedRuleIds.contains('cover'), isFalse);
      expect(unpinnedProfile.pinnedRules.tombstones.containsKey('cover'), isTrue,
          reason: 'Unpin must author a CRDT tombstone');

      // Ingest remote delta or state from stale peer that still has 'cover' at older timestamp
      final olderTs = HybridLogicalClock(
        physicalTime: clock.latest.physicalTime - 1000,
        logicalCounter: 0,
        nodeId: 'stale_peer',
      );
      final stalePeerRules = CrdtOrSet<String>(
        items: {
          'cover': CrdtLwwRegister<String>(value: 'cover', timestamp: olderTs),
        },
      );
      final merged = unpinnedProfile.pinnedRules.merge(stalePeerRules);
      expect(merged.activeValues.contains('cover'), isFalse, reason: 'Newer tombstone wins over older stale add');
      expect(merged.tombstones.containsKey('cover'), isTrue);
    });

    test('J & L. Roster removal authors typed PartyEvent with entityId and prevents resurrection', () async {
      final controller = DmDashboardController(
        replicaId: testReplica,
        clock: clock,
        campaignProfileService: profileService,
        characterPersistenceService: charPersistence,
      );

      final charCleric = _createTestChar('cleric-1', 'Cleric One');
      final charRogue = _createTestChar('rogue-1', 'Rogue One');
      await charPersistence.saveCharacters([charCleric, charRogue]);
      await characterRepo.saveCharacter(charCleric);
      await characterRepo.saveCharacter(charRogue);

      final initialProfile = CampaignProfile.raw(
        id: 'camp_roster_test',
        name: 'Roster Campaign',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        partyCharacterIds: const ['cleric-1', 'rogue-1'],
        roomState: RoomNodeState(
          roomId: 'room_roster',
          roomCode: 'ROST1',
          title: 'Roster Room',
        ),
      );
      await profileService.saveProfileImmediate(initialProfile);
      await campaignRepo.saveProfileImmediate(initialProfile);
      await controller.switchProfile('camp_roster_test');

      // Call controller removal path
      await controller.removeCharacterFromParty('cleric-1');

      final updatedProfile = controller.activeProfile!;
      expect(updatedProfile.partyCharacterIds, equals(['rogue-1']));
      expect(updatedProfile.changeLog, isNotEmpty);

      final removalEvent = updatedProfile.changeLog.firstWhere((e) => e.type == 'characterRemove');
      expect(removalEvent.entityId, equals('cleric-1'), reason: 'Typed removal event must author entityId');

      // Stale replica still contains cleric-1
      final staleProfile = initialProfile;
      final joined = CampaignProfile.join(updatedProfile, staleProfile);

      expect(joined.partyCharacterIds, equals(['rogue-1']),
          reason: 'Stale replica cannot resurrect character with typed removal event');
    });

    test('M. Malformed authoritative pinnedRules_crdt fails loudly when present; legacy migration only on absence', () {
      // 1. Key absent + legacy pinnedRuleIds -> deterministic migration succeeds
      final legacyMap = {
        'id': 'c_legacy',
        'name': 'Legacy',
        'pinnedRuleIds': ['cover', 'resting'],
      };
      final dtoLegacy = CampaignProfileDto.fromMap(legacyMap);
      final profileLegacy = dtoLegacy.toDomain();
      expect(profileLegacy.pinnedRuleIds, containsAll(['cover', 'resting']));

      // 2. Key present valid -> authoritative CRDT used
      final validCrdt = CrdtOrSet<String>(
        items: {
          'cover': const CrdtLwwRegister<String>(
            value: 'cover',
            timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'n1'),
          ),
        },
      );
      final validMap = {
        'id': 'c_valid',
        'name': 'Valid',
        'pinnedRules_crdt': validCrdt.toMap((v) => v),
      };
      final dtoValid = CampaignProfileDto.fromMap(validMap);
      expect(dtoValid.toDomain().pinnedRuleIds, equals({'cover'}));

      // 3. Key present null -> fails FormatException
      final nullMap = {
        'id': 'c_null',
        'name': 'Null CRDT',
        'pinnedRules_crdt': null,
      };
      expect(() => CampaignProfileDto.fromMap(nullMap), throwsA(isA<FormatException>()));

      // 4. Key present wrong type -> fails FormatException
      final wrongTypeMap = {
        'id': 'c_wrong',
        'name': 'Wrong Type CRDT',
        'pinnedRules_crdt': 'not_a_map',
      };
      expect(() => CampaignProfileDto.fromMap(wrongTypeMap), throwsA(isA<FormatException>()));

      // 5. Key present malformed internal CRDT -> fails FormatException in toDomain()
      final badInternalMap = {
        'id': 'c_bad_internal',
        'name': 'Bad Internal CRDT',
        'pinnedRules_crdt': {
          'items': {'bad_entry': 'not_a_register_map'},
          'tombstones': {},
        },
      };
      final dtoBadInternal = CampaignProfileDto.fromMap(badInternalMap);
      expect(() => dtoBadInternal.toDomain(), throwsA(isA<FormatException>()));

      // 6. Both authoritative and legacy present -> validates authoritative and uses authoritative
      final bothMap = {
        'id': 'c_both',
        'name': 'Both Present',
        'pinnedRuleIds': ['flanking'],
        'pinnedRules_crdt': validCrdt.toMap((v) => v),
      };
      final dtoBoth = CampaignProfileDto.fromMap(bothMap);
      final profileBoth = dtoBoth.toDomain();
      expect(profileBoth.pinnedRuleIds, equals({'cover'}),
          reason: 'Authoritative CRDT must take precedence over legacy pinnedRuleIds');
    });

    test('N. Malformed changeLog entry fails whole profile record and preserves raw entry in quarantine', () async {
      final badChangeLogMap = {
        'id': 'c_bad_log',
        'name': 'Bad Log Campaign',
        'changeLog': [
          {
            'id': 'evt_1',
            'roomCode': 'R1',
            'type': 'note',
            'playerName': 'Alice',
            'details': 'Valid event',
            'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
          {
            'id': 'evt_2',
            // Missing timestamp -> malformed PartyEvent
            'roomCode': 'R1',
            'type': 'note',
            'playerName': 'Bob',
            'details': 'Malformed event',
          },
        ],
      };

      final dto = CampaignProfileDto.fromMap(badChangeLogMap);
      expect(() => dto.toDomain(), throwsA(isA<FormatException>()));

      final healthyMap = {
        'id': 'c_healthy',
        'name': 'Healthy Campaign',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      // Persist raw to database
      final db = AppDatabaseService.instance;
      await db.put(AppDatabaseService.boxCampaignProfiles, '${LocalCampaignRepository.profileKeyPrefix}c_bad_log', jsonEncode(badChangeLogMap));
      await db.put(AppDatabaseService.boxCampaignProfiles, '${LocalCampaignRepository.profileKeyPrefix}c_healthy', jsonEncode(healthyMap));
      await db.put(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey, ['c_healthy', 'c_bad_log']);
      await db.put(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.activeProfileIdKey, 'c_healthy');

      // Load through repository: must quarantine rather than silently dropping bad event
      final freshRepo = LocalCampaignRepository(
        replicaId: testReplica,
        clock: clock,
        characterRepo: characterRepo,
      );
      final all = await freshRepo.loadAllProfiles();
      expect(all.map((p) => p.id), equals(['c_healthy']));
      expect(await freshRepo.getProfile('c_bad_log'), isNull);
      // Raw corrupted record remains in database untouched
      expect(db.get(AppDatabaseService.boxCampaignProfiles, '${LocalCampaignRepository.profileKeyPrefix}c_bad_log'), isNotNull);
    });

    test('O. Malformed authoritative PartyPurse fails loudly and is preserved in quarantine', () async {
      final absentPurseMap = {
        'id': 'c_absent_purse',
        'name': 'Absent Purse',
      };
      final dtoAbsent = CampaignProfileDto.fromMap(absentPurseMap);
      expect(dtoAbsent.toDomain().partyPurse, equals(const PartyPurse.empty()));

      final malformedPurseMap = {
        'id': 'c_bad_purse',
        'name': 'Bad Purse',
        'partyPurse': 'not_a_map',
      };
      expect(() => CampaignProfileDto.fromMap(malformedPurseMap), throwsA(isA<FormatException>()));
    });

    test('Q & R. Strict createdAt and lastPlayedAt parsing without DateTime.now', () {
      final validMap = {
        'id': 'c_dates',
        'name': 'Dates Campaign',
        'createdAt': '2026-06-01T12:00:00.000Z',
        'lastPlayedAt': '2026-06-02T12:00:00.000Z',
      };
      final dto = CampaignProfileDto.fromMap(validMap);
      final p1 = dto.toDomain();
      final p2 = dto.toDomain();
      expect(p1.createdAt, equals(DateTime.utc(2026, 6, 1, 12)));
      expect(p1.lastPlayedAt, equals(DateTime.utc(2026, 6, 2, 12)));
      expect(p1.createdAt, equals(p2.createdAt), reason: 'Reconstruction must be deterministic');

      final badCreatedMap = {
        'id': 'c_bad_created',
        'name': 'Bad Created',
        'createdAt': 'not_a_date',
      };
      expect(() => CampaignProfileDto.fromMap(badCreatedMap), throwsA(isA<FormatException>()));

      final badPlayedMap = {
        'id': 'c_bad_played',
        'name': 'Bad Played',
        'createdAt': '2026-06-01T12:00:00.000Z',
        'lastPlayedAt': 'not_a_date',
      };
      expect(() => CampaignProfileDto.fromMap(badPlayedMap), throwsA(isA<FormatException>()));

      // Missing createdAt deterministically defaults to Unix epoch UTC
      final missingDateMap = {
        'id': 'c_missing_dates',
        'name': 'Missing Dates',
      };
      final dtoMissing = CampaignProfileDto.fromMap(missingDateMap);
      expect(dtoMissing.toDomain().createdAt, equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
      expect(dtoMissing.toDomain().lastPlayedAt, equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    });

    test('S. Campaign id must be present and non-empty; no wall clock fallback', () {
      final missingIdMap = {
        'name': 'No Id Campaign',
      };
      expect(() => CampaignProfileDto.fromMap(missingIdMap), throwsA(isA<FormatException>()));

      final emptyIdMap = {
        'id': '   ',
        'name': 'Empty Id Campaign',
      };
      expect(() => CampaignProfileDto.fromMap(emptyIdMap), throwsA(isA<FormatException>()));
    });

    test('U & V. DTO roundtrip preserves tombstones for pinnedRules and entityLinksCrdt', () {
      const tsAdd = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'n1');
      const tsDel = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'n1');

      final profileWithTombstones = CampaignProfile.raw(
        id: 'camp_tombstone_roundtrip',
        name: 'Tombstone Roundtrip',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis'),
        ),
        pinnedRules: CrdtOrSet<String>(
          items: {
            'flanking': const CrdtLwwRegister<String>(value: 'flanking', timestamp: tsAdd),
          },
          tombstones: {
            'cover': tsDel,
          },
        ),
        roomState: RoomNodeState(
          roomId: 'r_tomb',
          roomCode: 'TOMB1',
          title: 'Tomb Room',
          entityLinksCrdt: CrdtOrSet<RoomEntityLink>(
            items: {
              'link_active': CrdtLwwRegister<RoomEntityLink>(
                value: RoomEntityLink(entityId: 'link_active', displayName: 'Active Link'),
                timestamp: tsAdd,
              ),
            },
            tombstones: {
              'link_deleted': tsDel,
            },
          ),
        ),
      );

      final dto = CampaignProfileDto.fromDomain(profileWithTombstones);
      final jsonStr = dto.toJson();
      final restored = CampaignProfileDto.fromJson(jsonStr).toDomain();

      expect(restored, equals(profileWithTombstones));
      expect(restored.pinnedRules.tombstones.containsKey('cover'), isTrue);
      expect(restored.pinnedRuleIds.contains('cover'), isFalse);
      expect(restored.pinnedRuleIds, equals({'flanking'}));

      expect(restored.roomState.entityLinksCrdt.tombstones.containsKey('link_deleted'), isTrue);
      expect(restored.roomState.entityLinks.map((l) => l.entityId), equals(['link_active']));

      // Idempotent join
      expect(CampaignProfile.join(profileWithTombstones, restored), equals(profileWithTombstones));
    });

    test('W. Aggregate HLC extractor roundtrip extracts all 9 distinct CRDT timestamps', () {
      const tsNotes = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'n1');
      const tsPinnedItem = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'n1');
      const tsPinnedTombstone = HybridLogicalClock(physicalTime: 3000, logicalCounter: 0, nodeId: 'n1');
      const tsLinkItem = HybridLogicalClock(physicalTime: 4000, logicalCounter: 0, nodeId: 'n1');
      const tsLinkTombstone = HybridLogicalClock(physicalTime: 5000, logicalCounter: 0, nodeId: 'n1');
      const tsMinionItem = HybridLogicalClock(physicalTime: 6000, logicalCounter: 0, nodeId: 'n1');
      const tsMinionTombstone = HybridLogicalClock(physicalTime: 7000, logicalCounter: 0, nodeId: 'n1');
      const tsEncounterItem = HybridLogicalClock(physicalTime: 8000, logicalCounter: 0, nodeId: 'n1');
      const tsEncounterTombstone = HybridLogicalClock(physicalTime: 9000, logicalCounter: 0, nodeId: 'n1');

      final profile = CampaignProfile.raw(
        id: 'camp_hlc_9',
        name: 'All 9 HLCs',
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        notesRegister: const CrdtLwwRegister<String>(value: 'note', timestamp: tsNotes),
        pinnedRules: CrdtOrSet<String>(
          items: {
            'rule_1': const CrdtLwwRegister<String>(value: 'rule_1', timestamp: tsPinnedItem),
          },
          tombstones: {
            'rule_2': tsPinnedTombstone,
          },
        ),
        roomState: RoomNodeState(
          roomId: 'r_9',
          roomCode: 'R9',
          title: 'Room 9',
          entityLinksCrdt: CrdtOrSet<RoomEntityLink>(
            items: {
              'link_1': CrdtLwwRegister<RoomEntityLink>(
                value: RoomEntityLink(entityId: 'link_1', displayName: 'L1'),
                timestamp: tsLinkItem,
              ),
            },
            tombstones: {
              'link_2': tsLinkTombstone,
            },
          ),
          activeMinions: CrdtOrSet<dynamic>(
            items: {
              'm1': const CrdtLwwRegister<dynamic>(value: {'name': 'M1'}, timestamp: tsMinionItem),
            },
            tombstones: {
              'm2': tsMinionTombstone,
            },
          ),
          activeEncounter: CrdtOrSet<EncounterParticipant>(
            items: {
              'e1': CrdtLwwRegister<EncounterParticipant>(
                value: EncounterParticipant(
                  participantId: 'e1',
                  entityLink: RoomEntityLink(entityId: 'e1', displayName: 'E1'),
                ),
                timestamp: tsEncounterItem,
              ),
            },
            tombstones: {
              'e2': tsEncounterTombstone,
            },
          ),
        ),
      );

      final extracted = extractCampaignProfileTimestamps(profile);
      final expected = {
        tsNotes,
        tsPinnedItem,
        tsPinnedTombstone,
        tsLinkItem,
        tsLinkTombstone,
        tsMinionItem,
        tsMinionTombstone,
        tsEncounterItem,
        tsEncounterTombstone,
      };

      expect(extracted.toSet(), equals(expected));
      expect(extracted.length, equals(9));
    });
  });
}
