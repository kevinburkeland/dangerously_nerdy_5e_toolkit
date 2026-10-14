// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'room_sync_orchestrator_test.dart' as h;

class _DelayRecordingDatabaseService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  int delayMs = 20;
  bool throwOnIndexReadOnce = false;

  _DelayRecordingDatabaseService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    writtenData.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    if (throwOnIndexReadOnce && key == LocalCampaignRepository.profileIndexKey) {
      throwOnIndexReadOnce = false;
      throw StateError('Simulated index read failure');
    }
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    writtenData[boxName]?.remove(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    for (final k in keys) {
      writtenData[boxName]?.remove(k);
    }
  }

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  List<String> getKeys(String boxName) {
    return writtenData[boxName]?.keys.toList() ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppServices.instance.debouncedStorage.flushAll();
    SharedPreferences.setMockInitialValues({});
  });

  String purseDelta(String peer, int gp) => jsonEncode({
        'type': 'crdt_purse_delta',
        'origin_node_id': peer,
        'origin_seq': 1,
        'campaign_id': 'c1',
        'payload': const PartyPurse.empty()
            .modifyDenomination('gp', gp, replicaId: ReplicaId(peer))
            .toMap(),
        'timestamp': 1700000000000,
      });

  group('Pass 5.0.1 Review Probes (R1real, E1, E2, K1, U1)', () {
    // R1real: concurrent inbound purse deltas against real repository with I/O delay
    for (final concurrent in [false, true]) {
      test('R1real concurrent=$concurrent', () async {
        final mockDb = _DelayRecordingDatabaseService();
        final charRepo = LocalCharacterRepository(db: mockDb);
        final repo = LocalCampaignRepository(
          replicaId: ReplicaId('me'),
          clock: StatefulHlcClock(replicaId: ReplicaId('me')),
          db: mockDb,
          characterRepo: charRepo,
        );

        final initialProfile = CampaignProfile(
          id: 'c1',
          name: 'Campaign 1',
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2026),
          lastPlayedAt: DateTime.utc(2026),
          roomState: RoomNodeState(roomId: 'r', roomCode: 'CR-1', title: 't'),
          nodeId: 'me',
        );
        await repo.putProfile(initialProfile);
        await repo.setActiveProfileId('c1');

        final router = CascadingTransportRouter(
          localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
          webRtcAdapter: h.MockTransportPort(),
          firebaseFallbackAdapter: h.MockTransportPort(),
        );
        await router.initializeRoom('CR-1', 'me');

        final clock = ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: 1700000000000),
          localTimeProvider: () => 1700000000000,
        );

        final orchestrator = RoomSyncOrchestrator(
          router: router,
          campaignRepo: repo,
          reconciliationService: RoomStateReconciliationService(
            networkTimeProvider: () => 1700000000000,
          ),
          clockSyncService: clock,
          localTimeProvider: () => 1700000000000,
          payloadMapper: const RoomSyncPayloadMapper(),
          replicaId: ReplicaId('me'),
          clock: StatefulHlcClock(replicaId: ReplicaId('me')),
          isHost: false,
          telemetryInterval: const Duration(seconds: 5),
        );

        orchestrator.startSynchronization();

        if (concurrent) {
          await Future.wait([
            orchestrator.handleIncomingPayload(purseDelta('peerA', 100)),
            orchestrator.handleIncomingPayload(purseDelta('peerB', 50)),
          ]);
        } else {
          await orchestrator.handleIncomingPayload(purseDelta('peerA', 100));
          await orchestrator.handleIncomingPayload(purseDelta('peerB', 50));
        }

        final finalGp = repo.activeProfile!.partyPurse.getBalance('gp');
        final pad = concurrent ? ' ' : '';
        print('R1real concurrent=$concurrent$pad final gp=$finalGp (expected 150)');
        expect(finalGp, equals(150));
        orchestrator.stopSynchronization();
        repo.dispose();
      });
    }

    // E1: remote inbound change produces zero echoes
    test('E1 no echo on inbound delta vs local edit', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final clock = StatefulHlcClock(
        replicaId: ReplicaId('me'),
        timeProvider: () => 1700000000000,
      );
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      final initialProfile = CampaignProfile(
        id: 'c1',
        name: 'Campaign 1',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r', roomCode: 'CR-1', title: 't'),
        nodeId: 'me',
      );
      await repo.putProfile(initialProfile);
      await repo.setActiveProfileId('c1');

      final mockTransport = h.MockTransportPort();
      final router = CascadingTransportRouter(
        localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
        webRtcAdapter: mockTransport,
        firebaseFallbackAdapter: h.MockTransportPort(),
      );
      await router.initializeRoom('CR-1', 'me');

      final orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: repo,
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => 1700000000000,
        ),
        clockSyncService: ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: 1700000000000),
          localTimeProvider: () => 1700000000000,
        ),
        localTimeProvider: () => 1700000000000,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('me'),
        clock: clock,
        isHost: false,
        telemetryInterval: const Duration(seconds: 5),
      );

      final controller = DmDashboardController(
        campaignRepository: repo,
        characterRepository: charRepo,
        replicaId: ReplicaId('me'),
        clock: clock,
      );
      await controller.loadData();
      orchestrator.startSynchronization();

      // Inbound delta: must not echo
      await orchestrator.handleIncomingPayload(purseDelta('peerA', 100));
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final inboundBroadcasts = mockTransport.broadcastedPayloads.length;
      print('E1 inbound delta broadcasts=$inboundBroadcasts (expected 0)');
      expect(inboundBroadcasts, equals(0));

      // Control: local edit broadcasts
      await controller.modifyPartyPurseCoin('gp', 5);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final localBroadcasts = mockTransport.broadcastedPayloads.length;
      print('E1 local edit broadcasts=$localBroadcasts (expected 1)');
      expect(localBroadcasts, equals(1));

      controller.dispose();
      orchestrator.stopSynchronization();
      repo.dispose();
    });

    // E2: host milestone flush produces zero broadcasts
    test('E2 milestone flush does not echo', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final clock = StatefulHlcClock(
        replicaId: ReplicaId('host'),
        timeProvider: () => 1700000000000,
      );
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('host'),
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      final initialProfile = CampaignProfile(
        id: 'c1',
        name: 'Campaign 1',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r', roomCode: 'CR-1', title: 't'),
        nodeId: 'host',
      );
      await repo.putProfile(initialProfile);
      await repo.setActiveProfileId('c1');

      final mockTransport = h.MockTransportPort();
      final router = CascadingTransportRouter(
        localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
        webRtcAdapter: mockTransport,
        firebaseFallbackAdapter: h.MockTransportPort(),
      );
      await router.initializeRoom('CR-1', 'host');

      final orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: repo,
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => 1700000000000,
        ),
        clockSyncService: ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: 1700000000000),
          localTimeProvider: () => 1700000000000,
        ),
        localTimeProvider: () => 1700000000000,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('host'),
        clock: clock,
        isHost: true,
        telemetryInterval: const Duration(seconds: 5),
      );

      orchestrator.startSynchronization();

      await orchestrator.executeHostMilestoneFlush();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final broadcasts = mockTransport.broadcastedPayloads.length;
      print('E2 broadcasts after milestone flush=$broadcasts (expected 0)');
      expect(broadcasts, equals(0));

      orchestrator.stopSynchronization();
      repo.dispose();
    });

    // K1: fresh LocalCampaignRepository with empty store
    test('K1 putProfile writes only restored record and does not tick clock', () async {
      final freshDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final freshClock = StatefulHlcClock(
        replicaId: ReplicaId('k1_node'),
        timeProvider: () => 1700000000000,
      );
      final initialHlc = freshClock.latest;
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('k1_node'),
        clock: freshClock,
        db: freshDb,
        characterRepo: LocalCharacterRepository(db: freshDb),
      );

      final restored = CampaignProfile(
        id: 'restored',
        name: 'Restored Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r_res', roomCode: 'CR-RES', title: 't'),
        nodeId: 'k1_node',
      );

      await repo.putProfile(restored);

      final clockTicked = freshClock.latest != initialHlc;
      final profileIds = repo.allProfiles.map((p) => p.id).toList();
      print('K1 clock ticked=$clockTicked profiles=$profileIds   (expected false, [restored])');
      expect(clockTicked, isFalse);
      expect(profileIds, equals(['restored']));

      repo.dispose();
    });

    // C0: storage holds A. Call loadAllProfiles()
    test('C0 baseline: storage holds A, loadAllProfiles returns [A]', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Campaign A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
        nodeId: 'me',
      );
      final jsonA = CampaignProfileDto.fromDomain(profileA).toJson();
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}A'
      ] = jsonA;
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        LocalCampaignRepository.profileIndexKey
      ] = ['A'];
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        LocalCampaignRepository.activeProfileIdKey
      ] = 'A';

      final loaded = await repo.loadAllProfiles();
      final ids = loaded.map((p) => p.id).toList();
      final active = repo.activeProfileId;
      final index = mockDb.get(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey);

      print('C0: ids $ids, active $active, index $index');
      expect(ids, equals(['A']));
      expect(active, equals('A'));
      expect(index, equals(['A']));

      repo.dispose();
    });

    // C1: repo loaded with A. Storage gains B + index [A, B] + active id B. Call loadAllProfiles()
    test('C1: repo loaded with A. Storage gains B + index [A, B] + active id B. Call loadAllProfiles()', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Campaign A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
        nodeId: 'me',
      );
      final jsonA = CampaignProfileDto.fromDomain(profileA).toJson();
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}A'
      ] = jsonA;
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        LocalCampaignRepository.profileIndexKey
      ] = ['A'];
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        LocalCampaignRepository.activeProfileIdKey
      ] = 'A';

      // First load: loaded with A
      await repo.loadAllProfiles();

      // Storage gains B + index [A, B] + active id B
      final profileB = CampaignProfile(
        id: 'B',
        name: 'Campaign B',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rB', roomCode: 'CR-B', title: 'tB'),
        nodeId: 'me',
      );
      final jsonB = CampaignProfileDto.fromDomain(profileB).toJson();
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        '${LocalCampaignRepository.profileKeyPrefix}B'
      ] = jsonB;
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['A', 'B'];
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.activeProfileIdKey
      ] = 'B';

      // Call loadAllProfiles()
      final loaded = await repo.loadAllProfiles();
      final ids = loaded.map((p) => p.id).toList();
      final active = repo.activeProfileId;
      final index = mockDb.get(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey);

      print('C1: ids $ids, active $active, index $index');
      expect(ids, equals(['A', 'B']));
      expect(active, equals('B'));
      expect(index, equals(['A', 'B']));

      repo.dispose();
    });

    // C2: repo loaded with A, B. Storage deletes B, index [A]. Call loadAllProfiles()
    test('C2: repo loaded with A, B. Storage deletes B, index [A]. Call loadAllProfiles()', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Campaign A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
        nodeId: 'me',
      );
      final profileB = CampaignProfile(
        id: 'B',
        name: 'Campaign B',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rB', roomCode: 'CR-B', title: 'tB'),
        nodeId: 'me',
      );
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}A'
      ] = CampaignProfileDto.fromDomain(profileA).toJson();
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        '${LocalCampaignRepository.profileKeyPrefix}B'
      ] = CampaignProfileDto.fromDomain(profileB).toJson();
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['A', 'B'];
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.activeProfileIdKey
      ] = 'A';

      // First load: loaded with A, B
      await repo.loadAllProfiles();

      // Storage deletes B, index [A]
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]!.remove(
        '${LocalCampaignRepository.profileKeyPrefix}B',
      );
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['A'];

      // Call loadAllProfiles()
      final loaded = await repo.loadAllProfiles();
      final ids = loaded.map((p) => p.id).toList();
      final index = mockDb.get(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey);

      print('C2: ids $ids, index $index');
      expect(ids, equals(['A']));
      expect(index, equals(['A']));

      repo.dispose();
    });

    // F1: storage holds A. The first index read throws once. Call loadAllProfiles() twice
    test('F1: storage holds A. The first index read throws once. Call loadAllProfiles() twice', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Campaign A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
        nodeId: 'me',
      );
      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}A'
      ] = CampaignProfileDto.fromDomain(profileA).toJson();
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['A'];
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.activeProfileIdKey
      ] = 'A';

      // First index read throws once
      mockDb.throwOnIndexReadOnce = true;

      // Call loadAllProfiles() twice
      final firstLoaded = await repo.loadAllProfiles();
      final firstIds = firstLoaded.map((p) => p.id).toList();

      final secondLoaded = await repo.loadAllProfiles();
      final secondIds = secondLoaded.map((p) => p.id).toList();

      final index = mockDb.get(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey);

      print('F1: first $firstIds, second $secondIds, index $index');
      expect(firstIds, equals([]));
      expect(secondIds, equals(['A']));
      expect(index, equals(['A']));

      repo.dispose();
    });

    // Required test 2: A reload during an in-flight updateProfile (slow DB) keeps the update (G1)
    test('G1: A reload during an in-flight updateProfile (slow DB) keeps the update', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 30;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profile = CampaignProfile(
        id: 'c1',
        name: 'Campaign 1',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r1', roomCode: 'CR-1', title: 't1'),
        nodeId: 'me',
      );
      await repo.putProfile(profile);
      await repo.setActiveProfileId('c1');

      // Start updateProfile (+10 gp)
      final updateFuture = repo.updateProfile('c1', (current) {
        return current.copyWith(
          partyPurse: current.partyPurse.modifyDenomination(
            'gp',
            10,
            replicaId: repo.replicaId,
          ),
        );
      });

      // Call loadAllProfiles() before updateProfile finishes
      final loadFuture = repo.loadAllProfiles();

      await Future.wait([updateFuture, loadFuture]);

      final finalGp = repo.activeProfile!.partyPurse.getBalance('gp');
      print('In-flight reload test (G1): final gp=$finalGp (expected 10)');
      expect(finalGp, equals(10));

      final persistedProfile = await repo.getProfile('c1');
      expect(persistedProfile!.partyPurse.getBalance('gp'), equals(10));

      repo.dispose();
    });

    // D1: a delete while a reload runs stays deleted
    test('D1: a delete while a reload runs stays deleted', () async {
      final mockDb = _DelayRecordingDatabaseService()..delayMs = 25;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('me'),
        clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final profileA = CampaignProfile(
        id: 'A',
        name: 'Campaign A',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
        nodeId: 'me',
      );
      final profileB = CampaignProfile(
        id: 'B',
        name: 'Campaign B',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'rB', roomCode: 'CR-B', title: 'tB'),
        nodeId: 'me',
      );
      await repo.putProfile(profileA);
      await repo.putProfile(profileB);
      await repo.setActiveProfileId('A');

      // Start reload
      final reloadFuture = repo.loadAllProfiles();
      // Immediately call deleteProfile('A') while reload is in-flight
      final deleteFuture = repo.deleteProfile('A');

      await Future.wait([reloadFuture, deleteFuture]);

      final remainingIds = repo.allProfiles.map((p) => p.id).toList();
      print('D1 remaining ids: $remainingIds (expected [B])');
      expect(remainingIds, equals(['B']));
      expect(repo.activeProfileId, equals('B'));

      final storedProfileA = await repo.getProfile('A');
      expect(storedProfileA, isNull);

      repo.dispose();
    });

    // S1: a reload doesn't wait behind a write stream
    test('S1: a reload finishes after writes queued before it, while write stream continues', () async {
      for (final stream in [false, true]) {
        final mockDb = _DelayRecordingDatabaseService()..delayMs = 5;
        final charRepo = LocalCharacterRepository(db: mockDb);
        final repo = LocalCampaignRepository(
          replicaId: ReplicaId('me'),
          clock: StatefulHlcClock(replicaId: ReplicaId('me')),
          db: mockDb,
          characterRepo: charRepo,
        );

        final profile = CampaignProfile(
          id: 'c1',
          name: 'Campaign 1',
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2026),
          lastPlayedAt: DateTime.utc(2026),
          roomState: RoomNodeState(roomId: 'r1', roomCode: 'CR-1', title: 't1'),
          nodeId: 'me',
        );
        await repo.putProfile(profile);

        bool writesActive = true;
        bool reloadFinishedWhileWritesContinued = false;
        final writeFutures = <Future<void>>[];

        if (stream) {
          final endWritesAt = DateTime.now().add(const Duration(milliseconds: 300));
          unawaited(() async {
            while (DateTime.now().isBefore(endWritesAt)) {
              writeFutures.add(repo.updateProfile('c1', (p) => p.copyWith(
                partyPurse: p.partyPurse.modifyDenomination('gp', 1, replicaId: repo.replicaId),
              )));
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
            writesActive = false;
          }());

          // Wait 20ms so writes are active
          await Future<void>.delayed(const Duration(milliseconds: 20));
        } else {
          writesActive = false;
        }

        final sw = Stopwatch()..start();
        final reloadFuture = repo.loadAllProfiles();
        await reloadFuture;
        sw.stop();

        if (stream) {
          reloadFinishedWhileWritesContinued = writesActive;
        } else {
          reloadFinishedWhileWritesContinued = true;
        }

        print('S1 stream=$stream reload finished while writes continued=$reloadFinishedWhileWritesContinued   total=${sw.elapsedMilliseconds}ms');
        expect(reloadFinishedWhileWritesContinued, isTrue);

        await Future.wait(writeFutures.map((f) => f.catchError((_) {})));
        repo.dispose();
      }
    });
  });
}
