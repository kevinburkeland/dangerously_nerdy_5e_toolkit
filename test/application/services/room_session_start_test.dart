import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/fake_campaign_repository.dart';

class _CountingTransport implements IP2pTransportPort {
  int watchIncomingCount = 0;
  final StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  Stream<String> watchIncomingPayloads() {
    watchIncomingCount++;
    return _controller.stream;
  }

  @override
  TransportState get currentState => TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => false;

  void dispose() {
    _controller.close();
  }
}

class _CountingCampaignRepo extends FakeCampaignRepository {
  int watchActiveProfileCount = 0;

  @override
  Stream<CampaignProfile?> watchActiveProfile() {
    watchActiveProfileCount++;
    return super.watchActiveProfile();
  }
}

class _MockNetworkTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => DateTime.now().millisecondsSinceEpoch;
}

class _FakePartyRoomService extends Fake implements PartyRoomService {
  @override
  Future<CampaignProfile> openRoomProfile(
    String roomCode, [
    String? lobbyCampaignId,
    String? lobbyRulesetId,
  ]) async {
    return CampaignProfile.placeholder(
      id: 'campaign_$roomCode',
      roomCode: roomCode,
      name: 'Test Campaign',
      stagingTitle: 'Test Campaign Staging',
      createdAt: DateTime.now(),
      lastPlayedAt: DateTime.now(),
    );
  }

  @override
  Future<PartySessionState> ensureRoomExists({
    required String roomCode,
    String? campaignName,
    String? hostKey,
    bool isStateless = false,
  }) async {
    return PartySessionState(
      roomCode: roomCode,
      campaignName: campaignName ?? 'Camp',
      hostKeyHash: 'hash',
      lastUpdated: DateTime.now(),
      expiresAt: DateTime.now(),
    );
  }

  @override
  Future<void> flushOutbox(String roomCode) async {}

  @override
  Stream<ClaimConflictEvent> get claimConflictStream => const Stream.empty();

  @override
  Stream<PurseOverdraftEvent> get overdraftStream => const Stream.empty();

  @override
  Stream<PartySessionState?> streamSession(String roomCode) => const Stream.empty();

  @override
  Stream<List<PartyLootItem>> streamLoot(String roomCode, {bool includeArchived = false}) =>
      const Stream.empty();

  @override
  Stream<List<PartyEvent>> streamEvents(String roomCode) => const Stream.empty();

  @override
  ValueNotifier<int> get pendingOutboxCount => ValueNotifier<int>(0);

  @override
  ReplicaId get replicaId => ReplicaId('node');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PartyRoomService.setCustomInstanceForTesting(_FakePartyRoomService());
  });

  tearDown(() {
    PartyRoomService.setCustomInstanceForTesting(null);
    sl.reset();
  });

  test('SS2: DiceRoomService restoring a remembered room starts sync and map controller', () async {
    SharedPreferences.setMockInitialValues({
      'dice_room_persisted_remember': true,
      'dice_room_persisted_code': 'ROOM-SS2',
      'dice_room_persisted_player_name': 'PlayerSS2',
    });

    final transport = _CountingTransport();
    sl.registerSingleton<IP2pTransportPort>(transport);

    final repo = FakeCampaignRepository();
    final orchestrator = RoomSyncOrchestrator(
      replicaId: ReplicaId('node-ss2'),
      transportPort: transport,
      payloadMapper: const RoomSyncPayloadMapper(),
      campaignRepo: repo,
      reconciliationService: RoomStateReconciliationService(
        networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      clockSyncService: ClockSyncService(networkTimePort: _MockNetworkTimePort()),
      diceRoomService: DiceRoomService(),
      clock: StatefulHlcClock(replicaId: ReplicaId('node-ss2')),
      telemetryInterval: const Duration(milliseconds: 100),
    );
    sl.registerSingleton<RoomSyncOrchestrator>(orchestrator);

    final network = FakeBlobNetwork();
    final channel = network.createChannel('node');
    final store = FakeBlobStore();
    final transfer = BlobTransferService(
      channel: channel,
      store: store,
      servableRefs: () => activeMapServableRefs(repo),
    );
    final mapController = ActiveMapController(
      campaignRepo: repo,
      transfer: transfer,
      store: store,
      channel: channel,
      transportState: () => TransportState.webRtc,
    );
    sl.registerSingleton<ActiveMapController>(mapController);

    final starter = RoomSessionStarter(
      orchestrator: orchestrator,
      maps: mapController,
    );
    sl.registerSingleton<RoomSessionStarter>(starter);

    addTearDown(() {
      orchestrator.stopSynchronization();
      mapController.dispose();
      transfer.dispose();
      transport.dispose();
    });

    expect(orchestrator.isSynchronizing, isFalse);
    expect(mapController.isStarted, isFalse);

    final diceService = DiceRoomService();
    await diceService.restorePersistedSession();
    // Allow asynchronous connectTransport microtasks to complete
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(orchestrator.isSynchronizing, isTrue);
    expect(mapController.isStarted, isTrue);
  });

  testWidgets('SS3: PartyRoomScreen opening a room starts sync and map controller', (tester) async {
    final transport = _CountingTransport();
    sl.registerSingleton<IP2pTransportPort>(transport);

    final repo = FakeCampaignRepository();
    final orchestrator = RoomSyncOrchestrator(
      replicaId: ReplicaId('node-ss3'),
      transportPort: transport,
      payloadMapper: const RoomSyncPayloadMapper(),
      campaignRepo: repo,
      reconciliationService: RoomStateReconciliationService(
        networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      clockSyncService: ClockSyncService(networkTimePort: _MockNetworkTimePort()),
      diceRoomService: DiceRoomService(),
      clock: StatefulHlcClock(replicaId: ReplicaId('node-ss3')),
      telemetryInterval: const Duration(milliseconds: 100),
    );
    sl.registerSingleton<RoomSyncOrchestrator>(orchestrator);

    final network = FakeBlobNetwork();
    final channel = network.createChannel('node');
    final store = FakeBlobStore();
    final transfer = BlobTransferService(
      channel: channel,
      store: store,
      servableRefs: () => activeMapServableRefs(repo),
    );
    final mapController = ActiveMapController(
      campaignRepo: repo,
      transfer: transfer,
      store: store,
      channel: channel,
      transportState: () => TransportState.webRtc,
    );
    sl.registerSingleton<ActiveMapController>(mapController);

    final starter = RoomSessionStarter(
      orchestrator: orchestrator,
      maps: mapController,
    );
    sl.registerSingleton<RoomSessionStarter>(starter);

    addTearDown(() {
      mapController.dispose();
      transfer.dispose();
      transport.dispose();
    });

    expect(orchestrator.isSynchronizing, isFalse);
    expect(mapController.isStarted, isFalse);

    await tester.pumpWidget(MaterialApp(
      home: PartyRoomScreen(
        roomCode: 'ROOM-SS3',
        initialPlayerName: 'Hero',
        diceService: DiceRoomService(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(orchestrator.isSynchronizing, isTrue);
    expect(mapController.isStarted, isTrue);

    orchestrator.stopSynchronization();
    await tester.pump();
  });

  test('SS4: Calling start() three times starts sync once and controller once', () {
    final transport = _CountingTransport();
    final repo = _CountingCampaignRepo();
    final orchestrator = RoomSyncOrchestrator(
      replicaId: ReplicaId('node-ss4'),
      transportPort: transport,
      payloadMapper: const RoomSyncPayloadMapper(),
      campaignRepo: repo,
      reconciliationService: RoomStateReconciliationService(
        networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      clockSyncService: ClockSyncService(networkTimePort: _MockNetworkTimePort()),
      diceRoomService: DiceRoomService(),
      clock: StatefulHlcClock(replicaId: ReplicaId('node-ss4')),
      telemetryInterval: const Duration(milliseconds: 100),
    );

    final network = FakeBlobNetwork();
    final channel = network.createChannel('node');
    final store = FakeBlobStore();
    final transfer = BlobTransferService(
      channel: channel,
      store: store,
      servableRefs: () => activeMapServableRefs(repo),
    );
    final mapController = ActiveMapController(
      campaignRepo: repo,
      transfer: transfer,
      store: store,
      channel: channel,
      transportState: () => TransportState.webRtc,
    );

    final starter = RoomSessionStarter(
      orchestrator: orchestrator,
      maps: mapController,
    );

    addTearDown(() {
      orchestrator.stopSynchronization();
      mapController.dispose();
      transfer.dispose();
      transport.dispose();
    });

    expect(transport.watchIncomingCount, equals(0));
    expect(repo.watchActiveProfileCount, equals(0));

    starter.start();
    starter.start();
    starter.start();

    expect(orchestrator.isSynchronizing, isTrue);
    expect(mapController.isStarted, isTrue);
    expect(transport.watchIncomingCount, equals(1));
    expect(repo.watchActiveProfileCount, equals(2));
  });
}
