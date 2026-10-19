import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/party_ledger_legacy_import.dart';

class IncrementMarker {
  final num value;
  const IncrementMarker(this.value);
}

Map<String, dynamic> applyMergeSet(
  Map<String, dynamic> doc,
  Map<String, dynamic> payload,
) {
  Map<String, dynamic> mergeMaps(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
  ) {
    final result = Map<String, dynamic>.from(target);
    for (final entry in source.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is IncrementMarker) {
        final current = (result[key] is num) ? result[key] as num : 0;
        result[key] = current + val.value;
      } else if (val is Map && result[key] is Map) {
        result[key] = mergeMaps(
          Map<String, dynamic>.from(result[key] as Map),
          Map<String, dynamic>.from(val),
        );
      } else {
        result[key] = val;
      }
    }
    return result;
  }

  final merged = mergeMaps(doc, payload);
  return jsonDecode(jsonEncode(merged)) as Map<String, dynamic>;
}

class _MockNetworkTimePort implements INetworkTimePort {
  int networkTimeMs = 1700000000000;
  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

class _MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  String? roomCode;

  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      true;

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) {
    _incomingController.add(payload);
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    this.roomCode = roomCode;
  }

  @override
  Future<void> disconnect() async {
    await _incomingController.close();
  }
}

class _MockCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final Map<String, CampaignProfile> profiles = {};
  final StreamController<CampaignProfile?> _activeController =
      StreamController<CampaignProfile?>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;
  set activeProfile(CampaignProfile? p) {
    _activeProfile = p;
    if (p != null) profiles[p.id] = p;
  }

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id] ??
        (_activeProfile?.id == id ? _activeProfile! : null);
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      Stream.value(allProfiles);
}

class _FailingIndexDbService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> store = {};
  bool failIndexWrites = false;

  _FailingIndexDbService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    if (key == LocalCampaignRepository.profileIndexKey && failIndexWrites) {
      throw StateError('Simulated index write failure');
    }
    store.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    return store[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    if (entries.containsKey(LocalCampaignRepository.profileIndexKey) &&
        failIndexWrites) {
      throw StateError('Simulated index write failure in putAll');
    }
    store.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  Future<void> delete(String boxName, String key) async {
    store[boxName]?.remove(key);
  }

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  List<String> getKeys(String boxName) =>
      store[boxName]?.keys.toList() ?? [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage: Pass 7 Regression Tests (054efe3 baseline)', () {
    test('F1, counter shadows increments', () {
      final payload = {
        'partyPurse': {'gp': const IncrementMarker(100)},
      };

      // Control: scalar-only legacy doc
      final docControl = {
        'roomCode': 'CR-P7F1',
        'campaignName': 'Control',
        'hostKeyHash': 'hash1',
        'partyPurse': {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0},
      };
      final mergedControl = applyMergeSet(docControl, payload);
      final clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      final dummyProfile = CampaignProfile.defaultProfile(
        id: 'camp_f1',
        nodeId: 'node-1',
        clock: clock,
      ).copyWith(roomState: RoomNodeState(roomId: 'r1', roomCode: 'CR-P7F1'));
      final importedControl = PartyLedgerLegacyImport.importLegacyLedger(
        profile: dummyProfile,
        rawDoc: mergedControl,
        clock: clock,
      );
      expect(importedControl.partyPurse.getBalance('gp'), equals(100));

      final now = DateTime.utc(2026);
      final expires = now.add(const Duration(days: 30));

      // Failing shape: doc written by PartySessionState.toMap() with 50 gp (contains counter maps)
      final state50 = PartySessionState(
        roomCode: 'CR-P7F1',
        campaignName: 'F1 Failing',
        hostKeyHash: 'hash1',
        lastUpdated: now,
        expiresAt: expires,
        partyPurse: const PartyPurse.empty().setDenomination(
          'gp',
          50,
          replicaId: ReplicaId('node-1'),
        ),
      );
      final docFailing = state50.toMap();
      final mergedFailing = applyMergeSet(docFailing, payload);

      // Stored scalar is 150
      expect((mergedFailing['partyPurse'] as Map)['gp'], equals(150));
      // After the fix, the legacy import reads 150 from scalar balances
      final importedFailing = PartyLedgerLegacyImport.importLegacyLedger(
        profile: dummyProfile,
        rawDoc: mergedFailing,
        clock: clock,
      );
      expect(importedFailing.partyPurse.getBalance('gp'), equals(150));
    });

    test('F2, removed member comes back', () {
      final now = DateTime.utc(2026);
      final expires = now.add(const Duration(days: 30));

      final state = PartySessionState(
        roomCode: 'CR-P7F2',
        campaignName: 'F2 Failing',
        hostKeyHash: 'hash1',
        lastUpdated: now,
        expiresAt: expires,
        partyPurse: const PartyPurse.empty(),
        memberPurses: {
          'Aria': const PartyPurse.empty().setDenomination(
            'gp',
            50,
            replicaId: ReplicaId('node-1'),
          ),
        },
        characterRoster: ['Aria'],
      );
      final doc = state.toMap();

      // removeCharacterFromRoster payload with merge semantics
      final removePayload = {
        'characterRoster': <String>[],
        'memberPurses': <String, dynamic>{},
        'partyPurse': const PartyPurse.empty()
            .setDenomination('gp', 50, replicaId: ReplicaId('node-1'))
            .toMap(),
      };
      final merged = applyMergeSet(doc, removePayload);

      // After the fix, the ledger never comes from that document again;
      // the import of the merged document must count Aria once (total 50)
      final clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      final dummyProfile = CampaignProfile.defaultProfile(
        id: 'camp_f2',
        nodeId: 'node-1',
        clock: clock,
      ).copyWith(roomState: RoomNodeState(roomId: 'r2', roomCode: 'CR-P7F2'));
      final imported = PartyLedgerLegacyImport.importLegacyLedger(
        profile: dummyProfile,
        rawDoc: merged,
        clock: clock,
      );
      final total = imported.partyPurse.getBalance('gp') +
          imported.memberPurses.values
              .fold<int>(0, (sum, p) => sum + p.getBalance('gp'));
      expect(total, equals(50));
    });

    test('F3, stale whole-document write', () {
      // After the fix both deposits go through the profile:
      // Two replicas, each updateProfile, merged, give 111.
      final clockA = StatefulHlcClock(replicaId: ReplicaId('node-A'));
      var repA = CampaignProfile.defaultProfile(
        id: 'camp_f3',
        nodeId: 'node-A',
        clock: clockA,
      ).copyWith(
        roomState: RoomNodeState(roomId: 'r3', roomCode: 'CR-P7F3'),
        partyPurse: const PartyPurse.empty().setDenomination(
          'gp',
          10,
          replicaId: ReplicaId('node-genesis'),
        ),
      );
      var repB = repA;

      // Device B increments by 100 through profile
      repB = repB.copyWith(
        partyPurse: repB.partyPurse
            .modifyCoin('gp', 100, replicaId: ReplicaId('node-B')),
      );

      // Device A deposits 1 through profile
      repA = repA.copyWith(
        partyPurse: repA.partyPurse
            .modifyCoin('gp', 1, replicaId: ReplicaId('node-A')),
      );

      final merged = repA.merge(repB);
      expect(merged.partyPurse.getBalance('gp'), equals(111));
    });

    test('F4, wrong campaign', () async {
      final clock = StatefulHlcClock(replicaId: ReplicaId('local-node'));
      final transport = _MockTransportPort();
      final repo = _MockCampaignRepo();
      final timePort = _MockNetworkTimePort();
      final clockSync = ClockSyncService(networkTimePort: timePort);
      final reconciliation = RoomStateReconciliationService(
        networkTimeProvider: () => clockSync.currentNetworkTimeMs,
      );

      final profileC1 = CampaignProfile(
        id: 'c1',
        name: 'Campaign C1',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        partyPurse: const PartyPurse.empty(),
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-C1',
          title: 'Room C1',
        ),
        nodeId: 'local-node',
      );
      repo.activeProfile = profileC1;

      final orchestrator = RoomSyncOrchestrator(
        transportPort: transport,
        campaignRepo: repo,
        reconciliationService: reconciliation,
        clockSyncService: clockSync,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('local-node'),
        clock: clock,
      );
      orchestrator.startSynchronization();

      // Control: matching campaign_id: c1 -> gp becomes 100
      final controlPayload = jsonEncode({
        'type': 'crdt_purse_delta',
        'campaign_id': 'c1',
        'origin_node_id': 'peer-1',
        'origin_seq': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': const PartyPurse.empty()
            .setDenomination('gp', 100, replicaId: ReplicaId('peer-1'))
            .toMap(),
      });
      transport.emitIncoming(controlPayload);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.activeProfile!.partyPurse.getBalance('gp'), equals(100));

      // Reset profile to 0 gp
      repo.activeProfile = profileC1;

      // Failing shape: campaign_id: other-campaign
      final wrongPayload = jsonEncode({
        'type': 'crdt_purse_delta',
        'campaign_id': 'other-campaign',
        'origin_node_id': 'peer-2',
        'origin_seq': 2,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': const PartyPurse.empty()
            .setDenomination('gp', 100, replicaId: ReplicaId('peer-2'))
            .toMap(),
      });
      transport.emitIncoming(wrongPayload);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // At 054efe3: orchestrator applies delta to active profile regardless of campaign_id. Expected: 0
      expect(repo.activeProfile!.partyPurse.getBalance('gp'), equals(0),
          reason: 'F4 delta campaign_id=other-campaign -> active c1 gp=${repo.activeProfile!.partyPurse.getBalance('gp')} (expected 0)');

      orchestrator.dispose();
    });

    test('F5, DM purse edit lands nowhere', () async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
      AppServices.reset();
      sl.reset();

      final repId = ReplicaId('dm-node');
      final clock = StatefulHlcClock(replicaId: repId);
      sl.registerSingleton<ReplicaId>(repId);
      sl.registerSingleton<StatefulHlcClock>(clock);

      final characterService = CharacterPersistenceService();
      final campaignRepo = LocalCampaignRepository(
        replicaId: repId,
        clock: clock,
        characterRepo: LocalCharacterRepository(),
      );
      sl.registerSingleton<ICampaignRepository>(campaignRepo);

      final roomService = PartyRoomService(
        replicaId: repId,
        clock: clock,
      );
      sl.registerSingleton<PartyRoomService>(roomService);
      const roomCode = 'CR-P7DM';

      await roomService.createCampaign(
        campaignName: 'Pass 7 Campaign',
        playerName: 'DM',
        customRoomCode: roomCode,
      );

      const character = Character(
        id: EntityId(slug: 'aria', ruleset: RulesetVersion.v2024),
        name: 'Aria',
        speciesRef: EntityReference.empty(
          slug: 'human',
          refType: EntityType.species,
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );
      await characterService.saveCharacter(character);

      await roomService.joinCampaign(
        roomCode: roomCode,
        playerName: 'Aria',
        characterSnapshot: character,
        characterId: 'aria',
      );

      final activeProfile = CampaignProfile(
        id: 'campaign_9999999999',
        name: 'Pass 7 Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(
          roomId: 'r_p7dm',
          roomCode: roomCode,
          title: 'Pass 7 Room',
        ),
        partyCharacterIds: const ['aria'],
        nodeId: 'dm-node',
      );
      await campaignRepo.putProfile(activeProfile);
      await campaignRepo.setActiveProfileId(activeProfile.id);

      final controller = DmDashboardController(
        campaignRepository: campaignRepo,
        characterPersistenceService: characterService,
        replicaId: repId,
        clock: clock,
      );
      await controller.loadData();

      final targetPurse = const PartyPurse.empty().setDenomination(
        'gp',
        25,
        replicaId: repId,
      );

      // Drive updateCharacterPurse
      await controller.updateCharacterPurse('aria', targetPurse);

      final roomSession = roomService.getCachedSession(roomCode);
      final ariaGp = roomSession?.memberPurses['aria']?.getBalance('gp') ??
          roomSession?.memberPurses['Aria']?.getBalance('gp');

      // At 054efe3: updateMemberPurse received roomCode: activeProfile.id ('campaign_9999999999'),
      // so the write never landed on CR-P7DM and ariaGp is null. Expected: 25.
      expect(ariaGp, equals(25),
          reason: 'F5 key=profile -> room $roomCode Aria gp=$ariaGp threw=null (expected 25)');
    });

    test('P1 identity: clone resets room code, adoption seeds only member character', () async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
      AppServices.reset();
      sl.reset();

      final repId = ReplicaId('test-node');
      final clock = StatefulHlcClock(replicaId: repId);
      sl.registerSingleton<ReplicaId>(repId);
      sl.registerSingleton<StatefulHlcClock>(clock);

      final characterRepo = LocalCharacterRepository();
      final campaignRepo = LocalCampaignRepository(
        replicaId: repId,
        clock: clock,
        characterRepo: characterRepo,
      );
      sl.registerSingleton<ICampaignRepository>(campaignRepo);

      final characterService = CharacterPersistenceService();
      final campaignService = CampaignProfileService(
        replicaId: repId,
        clock: clock,
      );

      // 1. Clone test: cloneProfile must reset roomState (no room code)
      final sourceProfile = CampaignProfile(
        id: 'camp_source',
        name: 'Source Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(
          roomId: 'r_source',
          roomCode: 'CR-SOURCE',
          title: 'Source Room',
        ),
        nodeId: 'test-node',
      );
      await campaignRepo.putProfile(sourceProfile);

      final cloned = await campaignService.cloneProfile('camp_source');
      // At 054efe3: cloneProfile copies roomState.roomCode ('CR-SOURCE'). Expected: empty
      expect(cloned.roomState.roomCode, isEmpty,
          reason: 'P1 cloneProfile copied roomCode: ${cloned.roomState.roomCode} (expected empty)');

      // 2. Adoption test: seeds roster with only membership's own character
      const charA = Character(
        id: EntityId(slug: 'aria', ruleset: RulesetVersion.v2024),
        name: 'Aria',
        speciesRef: EntityReference.empty(slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );
      const charB = Character(
        id: EntityId(slug: 'boris', ruleset: RulesetVersion.v2024),
        name: 'Boris',
        speciesRef: EntityReference.empty(slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );
      await characterService.saveCharacter(charA);
      await characterService.saveCharacter(charB);

      // Clean profiles to test adoption
      await campaignRepo.deleteProfile(sourceProfile.id);
      await campaignRepo.deleteProfile(cloned.id);

      final registry = CampaignRegistryService();
      await registry.saveMembership(CampaignMembership(
        roomCode: 'CR-ADOPT',
        campaignName: 'Adopt Campaign',
        role: CampaignRole.player,
        characterId: 'aria',
        lastPlayed: DateTime.now(),
      ));

      await CampaignStorageMigration.adoptRegistryMemberships(
        campaignRepo,
        clock: clock,
        nodeId: 'test-node',
        registryService: registry,
        characterPersistenceService: characterService,
      );

      final adopted = await campaignRepo.getProfile('campaign_CR-ADOPT');
      // At 054efe3: adoption seeds roster with every saved character (['aria', 'boris']).
      // Expected: ['aria'] (only membership's character).
      expect(adopted!.partyCharacterIds, equals(['aria']),
          reason: 'P1 adoption seeded roster with: ${adopted.partyCharacterIds} (expected [aria])');
    });

    test('P2 outbound: profile with different room code does not broadcast', () async {
      final clock = StatefulHlcClock(replicaId: ReplicaId('local-node'));
      final transport = _MockTransportPort();
      await transport.initializeRoom('CR-A', 'local-node');

      final repo = _MockCampaignRepo();
      final timePort = _MockNetworkTimePort();
      final clockSync = ClockSyncService(networkTimePort: timePort);
      final reconciliation = RoomStateReconciliationService(
        networkTimeProvider: () => clockSync.currentNetworkTimeMs,
      );

      final orchestrator = RoomSyncOrchestrator(
        transportPort: transport,
        campaignRepo: repo,
        reconciliationService: reconciliation,
        clockSyncService: clockSync,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('local-node'),
        clock: clock,
      );
      orchestrator.startSynchronization();

      // Active profile with room code CR-B
      final profileB = CampaignProfile(
        id: 'camp_b',
        name: 'Campaign B',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(
          roomId: 'r_b',
          roomCode: 'CR-B',
          title: 'Room B',
        ),
        nodeId: 'local-node',
      );

      await orchestrator.handleLocalProfileChange(profileB);

      // At 054efe3: orchestrator broadcasts profileB even though transport is in CR-A. Expected: isEmpty
      expect(transport.broadcastedPayloads, isEmpty,
          reason: 'P2 outbound: transport in CR-A broadcasted profile with roomCode CR-B');

      orchestrator.dispose();
    });

    test('AR1: delete rollback preserves memory and disk activeProfileId', () async {
      SharedPreferences.setMockInitialValues({});
      final clock = StatefulHlcClock(replicaId: ReplicaId('test-node'));
      final db = _FailingIndexDbService();
      final repo = LocalCampaignRepository(
        db: db,
        replicaId: ReplicaId('test-node'),
        clock: clock,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Profile A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: const RoomNodeState.empty(),
        nodeId: 'test-node',
      );
      final profileB = CampaignProfile(
        id: 'B',
        name: 'Profile B',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: const RoomNodeState.empty(),
        nodeId: 'test-node',
      );
      final profileC = CampaignProfile(
        id: 'C',
        name: 'Profile C',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: const RoomNodeState.empty(),
        nodeId: 'test-node',
      );

      await repo.putProfile(profileA);
      await repo.putProfile(profileB);
      await repo.putProfile(profileC);
      await repo.setActiveProfileId('A');

      // Fail index writes during delete
      db.failIndexWrites = true;

      // Start deleteProfile(B)
      final deleteFuture = repo.deleteProfile('B');

      // Before delete completes, call setActiveProfileId('C')
      await repo.setActiveProfileId('C');

      // Delete should throw
      try {
        await deleteFuture;
        fail('deleteProfile should have thrown');
      } catch (_) {}

      final diskActive = await db.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.activeProfileIdKey,
      );

      // At 054efe3: deleteProfile rollback restores _activeProfileId to A, so memory is A and disk is C!
      // Expected: memory is C and disk is C.
      expect(repo.activeProfileId, equals('C'),
          reason: 'AR1 failing: delete=threw memory active=${repo.activeProfileId} disk active=$diskActive (expected C/C)');
      expect(diskActive, equals('C'));
    });
  });
}
