// ignore_for_file: avoid_print

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
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'application/services/room_sync_orchestrator_test.dart' as h;

class _DelayRecordingDatabaseService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  int delayMs = 0;

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
}

String delta(String node, int gp) => jsonEncode({
      'type': 'crdt_purse_delta',
      'origin_node_id': node,
      'origin_seq': 1,
      'campaign_id': 'c1',
      'payload': const PartyPurse.empty()
          .modifyDenomination('gp', gp, replicaId: ReplicaId(node))
          .toMap(),
      'timestamp': 1700000001000,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    IRoomSyncPayloadPort.defaultProvider = () => const RoomSyncPayloadMapper();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();
  });

  tearDown(() {
    AppServices.reset();
  });

  group('Pass 5.0 Regression Probes (R1, R2, R3)', () {
    // R1: Concurrent inbound purse deltas vs repository save delay
    for (final concurrent in [false, true]) {
      test('R1 concurrent=$concurrent', () async {
        final mockDb = _DelayRecordingDatabaseService()..delayMs = 20;
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

        if (concurrent) {
          await Future.wait([
            orchestrator.handleIncomingPayload(delta('peerA', 100)),
            orchestrator.handleIncomingPayload(delta('peerB', 50)),
          ]);
        } else {
          await orchestrator.handleIncomingPayload(delta('peerA', 100));
          await orchestrator.handleIncomingPayload(delta('peerB', 50));
        }

        final finalGp = repo.activeProfile!.partyPurse.getBalance('gp');
        final pad = concurrent ? ' ' : '';
        print('R1 concurrent=$concurrent$pad final gp=$finalGp (expected 150)');
        expect(finalGp, equals(150));
        orchestrator.stopSynchronization();
        repo.dispose();
      });
    }

    // R2: Dashboard controller edits current record, not stale cached copy
    for (final reload in [true, false]) {
      test('R2 reload=$reload', () async {
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

        final controller = DmDashboardController(
          campaignRepository: repo,
          characterRepository: charRepo,
          replicaId: ReplicaId('me'),
          clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        );
        await controller.loadData();

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

        // Inbound remote delta +100 gp
        await orchestrator.handleIncomingPayload(delta('peerA', 100));

        if (reload) {
          await controller.loadData();
        }

        // DM local edit +5 gp
        await controller.modifyPartyPurseCoin('gp', 5);

        final finalGp = repo.activeProfile!.partyPurse.getBalance('gp');
        final pad = reload ? ' ' : '';
        print('R2 reload=$reload$pad final gp=$finalGp (expected 105)');
        expect(finalGp, equals(105));
        controller.dispose();
        orchestrator.stopSynchronization();
        repo.dispose();
      });
    }

    // R3: Local edits are never dropped during an inbound save
    for (final inboundPending in [false, true]) {
      test('R3 inboundPending=$inboundPending', () async {
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

        final mockTransport = h.MockTransportPort();
        final router = CascadingTransportRouter(
          localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
          webRtcAdapter: mockTransport,
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
        final controller = DmDashboardController(
          campaignRepository: repo,
          characterRepository: charRepo,
          replicaId: ReplicaId('me'),
          clock: StatefulHlcClock(replicaId: ReplicaId('me')),
        );
        await controller.loadData();

        orchestrator.startSynchronization();

        if (inboundPending) {
          // Slow down DB to simulate in-flight save window
          mockDb.delayMs = 30;
          final inboundFuture =
              orchestrator.handleIncomingPayload(delta('peerA', 100));

          // While inbound save is in flight, local edit arrives
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final localFuture = controller.modifyPartyPurseCoin('gp', 5);

          await Future.wait<dynamic>([inboundFuture, localFuture]);
          mockDb.delayMs = 0;
        } else {
          mockDb.delayMs = 0;
          await controller.modifyPartyPurseCoin('gp', 5);
        }

        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Count how many payloads broadcasted originate from local edits
        int localBroadcasts = 0;
        for (final p in mockTransport.broadcastedPayloads) {
          final decoded = jsonDecode(p) as Map<String, dynamic>;
          if (decoded['origin_node_id'] == 'me') {
            localBroadcasts++;
          }
        }

        final pad = inboundPending ? ' ' : '';
        print('R3 inboundPending=$inboundPending$pad local broadcasts=$localBroadcasts (expected 1)');
        expect(localBroadcasts, equals(1));

        controller.dispose();
        orchestrator.stopSynchronization();
        repo.dispose();
      });
    }
  });
}
