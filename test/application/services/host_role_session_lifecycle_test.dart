import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';

import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/service_test_configurator.dart';

class _FakeTransport implements IP2pTransportPort {
  final StreamController<String> _incoming = StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.localWifi;

  @override
  Map<String, int> peerLastSeen = const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    await _incoming.close();
  }
}

class _CountingCampaignRepo extends FakeCampaignRepository {
  int updateProfileCount = 0;

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    updateProfileCount++;
    return super.updateProfile(id, transform);
  }
}

class _FakeTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => 1700000000000;
}

class _FakeActiveMapController extends Fake implements ActiveMapController {
  int startCalls = 0;

  @override
  void start() {
    startCalls++;
  }
}

class _RecordingRoomSessionStarter extends Fake implements RoomSessionStarter {
  final List<bool> recordedIsHost = <bool>[];
  final List<({String caller, bool isHost})> recordedStarts =
      <({String caller, bool isHost})>[];
  final RoomSyncOrchestrator? _orchestrator;

  _RecordingRoomSessionStarter([this._orchestrator]);

  static String _classifyCaller(StackTrace st) {
    final frames = st.toString();
    if (frames.contains('party_room_screen.dart')) {
      return 'party_room_screen';
    }
    if (frames.contains('room_banner_widget.dart')) {
      return 'room_banner_widget';
    }
    if (frames.contains('dice_room_service.dart')) {
      return 'dice_room_service';
    }
    return 'other';
  }

  List<bool> isHostCallsFor(String caller) => recordedStarts
      .where((entry) => entry.caller == caller)
      .map((entry) => entry.isHost)
      .toList();

  @override
  void start({required bool isHost}) {
    recordedIsHost.add(isHost);
    recordedStarts.add((caller: _classifyCaller(StackTrace.current), isHost: isHost));
    _orchestrator?.startSynchronization(isHost: isHost);
  }
}

class _StubPartyRoomService extends PartyRoomService {
  final Map<String, PartySessionState> sessionsByCode =
      <String, PartySessionState>{};

  _StubPartyRoomService({
    required super.replicaId,
    required super.clock,
    required super.registry,
    required super.diceRoomService,
  }) : super.newInstance();

  @override
  PartySessionState? getCachedSession(String roomCode) =>
      sessionsByCode[roomCode.toUpperCase()];

  @override
  Stream<PartySessionState?> streamSession(String roomCode) =>
      Stream<PartySessionState?>.value(sessionsByCode[roomCode.toUpperCase()]);

  @override
  Future<CampaignProfile> openRoomProfile(
    String roomCode, [
    String? lobbyCampaignId,
    String? lobbyRulesetId,
  ]) async {
    return CampaignProfile.placeholder(
      id: 'profile-$roomCode',
      name: 'Campaign $roomCode',
      roomCode: roomCode,
      stagingTitle: 'Staging',
    );
  }
}

RoomSyncOrchestrator _buildOrchestrator({
  required _FakeTransport transport,
  required _CountingCampaignRepo repo,
  required ReplicaId replica,
  required StatefulHlcClock clock,
}) {
  return RoomSyncOrchestrator(
    transportPort: transport,
    campaignRepo: repo,
    reconciliationService: RoomStateReconciliationService(),
    clockSyncService: ClockSyncService(networkTimePort: _FakeTimePort()),
    payloadMapper: const RoomSyncPayloadMapper(),
    replicaId: replica,
    clock: clock,
    milestoneInterval: const Duration(milliseconds: 50),
    telemetryInterval: const Duration(seconds: 60),
    antiEntropyInterval: const Duration(seconds: 60),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fix 3.1 & 3.2: host role per session lifecycle', () {
    test(
      'Fix 3.1: RoomSessionStarter passes host role for room A (telemetry true + milestone flush) and player role for room B (telemetry false + no flush)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final registry = CampaignRegistryService.newInstance();
        await registry.saveMembership(
          CampaignMembership(
            roomCode: 'ROOM-A',
            campaignName: 'Host Campaign',
            role: CampaignRole.host,
            hostKey: 'host-key-a',
            lastPlayed: DateTime.utc(2026, 1, 1),
          ),
        );
        await registry.saveMembership(
          CampaignMembership(
            roomCode: 'ROOM-B',
            campaignName: 'Player Campaign',
            role: CampaignRole.player,
            lastPlayed: DateTime.utc(2026, 1, 1),
          ),
        );

        // Session A (host)
        fakeAsync((async) {
          final replica = ReplicaId('host_role_a');
          final clock = StatefulHlcClock(replicaId: replica);
          final transport = _FakeTransport();
          final repo = _CountingCampaignRepo();
          repo.putProfile(CampaignProfile.placeholder(id: 'camp-a', name: 'Camp A', roomCode: 'ROOM-A', stagingTitle: 'Staging'));
          async.flushMicrotasks();

          final orch = _buildOrchestrator(
            transport: transport,
            repo: repo,
            replica: replica,
            clock: clock,
          );
          final starter = RoomSessionStarter(
            orchestrator: orch,
            maps: _FakeActiveMapController(),
          );

          expect(orch.currentTelemetry.isHost, isFalse);

          final isHostA = registry.getMembership('ROOM-A')?.isHost ?? false;
          starter.start(isHost: isHostA);

          expect(orch.currentTelemetry.isHost, isTrue);
          expect(repo.updateProfileCount, equals(0));

          async.elapse(const Duration(milliseconds: 55));
          expect(repo.updateProfileCount, greaterThanOrEqualTo(1));

          orch.dispose();
        });

        // Session B (player)
        fakeAsync((async) {
          final replica = ReplicaId('host_role_b');
          final clock = StatefulHlcClock(replicaId: replica);
          final transport = _FakeTransport();
          final repo = _CountingCampaignRepo();
          repo.putProfile(CampaignProfile.placeholder(id: 'camp-b', name: 'Camp B', roomCode: 'ROOM-B', stagingTitle: 'Staging'));
          async.flushMicrotasks();

          final orch = _buildOrchestrator(
            transport: transport,
            repo: repo,
            replica: replica,
            clock: clock,
          );
          final starter = RoomSessionStarter(
            orchestrator: orch,
            maps: _FakeActiveMapController(),
          );

          final isHostB = registry.getMembership('ROOM-B')?.isHost ?? false;
          starter.start(isHost: isHostB);

          expect(orch.currentTelemetry.isHost, isFalse);
          async.elapse(const Duration(milliseconds: 120));
          expect(repo.updateProfileCount, equals(0));

          orch.dispose();
        });
      },
    );

    test(
      'Fix 3.2: stopSynchronization forgets host role so a subsequent player session has isHost false and no milestone flush',
      () {
        fakeAsync((async) {
          final replica = ReplicaId('host_role_reset');
          final clock = StatefulHlcClock(replicaId: replica);
          final transport = _FakeTransport();
          final repo = _CountingCampaignRepo();
          repo.putProfile(CampaignProfile.placeholder(id: 'camp-switch', name: 'Camp Switch', roomCode: 'ROOM-A', stagingTitle: 'Staging'));
          async.flushMicrotasks();

          final orch = _buildOrchestrator(
            transport: transport,
            repo: repo,
            replica: replica,
            clock: clock,
          );
          final starter = RoomSessionStarter(
            orchestrator: orch,
            maps: _FakeActiveMapController(),
          );

          // Start room A as host.
          starter.start(isHost: true);
          expect(orch.currentTelemetry.isHost, isTrue);
          async.elapse(const Duration(milliseconds: 55));
          final flushesAfterA = repo.updateProfileCount;
          expect(flushesAfterA, greaterThanOrEqualTo(1));

          // Stop sync -> must forget host role.
          orch.stopSynchronization();
          expect(orch.currentTelemetry.isHost, isFalse);

          // Start room B as player -> must stay false and never flush.
          starter.start(isHost: false);
          expect(orch.currentTelemetry.isHost, isFalse);
          async.elapse(const Duration(milliseconds: 150));
          expect(repo.updateProfileCount, equals(flushesAfterA));

          orch.dispose();
        });
      },
    );
  });

  group('Fix 3.1 callers pass host role from CampaignRegistryService', () {
    late CampaignRegistryService registry;
    late _RecordingRoomSessionStarter spyStarter;
    late NoOpRoomSyncOrchestrator noOpOrch;
    late NoOpP2pTransportPort noOpTransport;
    late DiceRoomService diceService;
    late _StubPartyRoomService stubPartyService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sl.reset();

      registry = CampaignRegistryService.newInstance();
      CampaignRegistryService.instance = registry;
      await registry.saveMembership(
        CampaignMembership(
          roomCode: 'HOST-ROOM',
          campaignName: 'Host Realm',
          role: CampaignRole.host,
          hostKey: 'host-key-123',
          lastPlayed: DateTime.utc(2026, 1, 1),
        ),
      );

      noOpTransport = NoOpP2pTransportPort();
      noOpOrch = NoOpRoomSyncOrchestrator();
      spyStarter = _RecordingRoomSessionStarter(noOpOrch);

      final replica = ReplicaId('caller_test_replica');
      final clock = StatefulHlcClock(replicaId: replica);
      final fakeRepo = FakeCampaignRepository();
      await fakeRepo.putProfile(CampaignProfile.placeholder(id: 'camp-host', name: 'Camp Host', roomCode: 'HOST-ROOM', stagingTitle: 'Staging'));

      sl.registerSingleton<ICampaignRepository>(fakeRepo);
      sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
      sl.registerSingleton<IP2pTransportPort>(noOpTransport);
      sl.registerSingleton<RoomSyncOrchestrator>(noOpOrch);
      sl.registerSingleton<RoomSessionStarter>(spyStarter);

      configureTestServices(
        repository: fakeRepo,
        replicaId: replica,
        clock: clock,
        registryService: registry,
        transport: noOpTransport,
        orchestrator: noOpOrch,
        sessionStarter: spyStarter,
      );

      diceService = DiceRoomService.newInstance();
      diceService.bind(
        transport: noOpTransport,
        orchestrator: noOpOrch,
        sessionStarter: spyStarter,
      );

      stubPartyService = _StubPartyRoomService(
        replicaId: replica,
        clock: clock,
        registry: registry,
        diceRoomService: diceService,
      );
      stubPartyService.sessionsByCode['HOST-ROOM'] = PartySessionState(
        roomCode: 'HOST-ROOM',
        campaignName: 'Host Realm',
        hostKeyHash: 'hash',
        activePlayers: const ['DM'],
        characterRoster: const ['Aldric'],
        lastUpdated: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 2, 1),
      );
      PartyRoomService.setCustomInstanceForTesting(stubPartyService);

      addTearDown(() async {
        PartyRoomService.resetCustomInstanceForTesting();
        CampaignRegistryService.resetInstanceForTesting();
        sl.reset();
      });
    });

    testWidgets('PartyRoomScreen passes isHost: true for a host membership',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PartyRoomScreen(
            roomCode: 'HOST-ROOM',
            initialPlayerName: 'DM',
            partyService: stubPartyService,
            registry: registry,
            diceService: diceService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calls = spyStarter.isHostCallsFor('party_room_screen');
      expect(calls, isNotEmpty,
          reason: 'PartyRoomScreen must invoke RoomSessionStarter.start');
      expect(calls, everyElement(isTrue),
          reason: 'PartyRoomScreen must pass isHost: true for a host membership');
    });

    testWidgets('RoomBannerWidget passes isHost: true for a host membership',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomBannerWidget(
              roomService: diceService,
              activeRoomCode: 'HOST-ROOM',
              playerName: 'DM',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calls = spyStarter.isHostCallsFor('room_banner_widget');
      expect(calls, isNotEmpty,
          reason: 'RoomBannerWidget must invoke RoomSessionStarter.start');
      expect(calls, everyElement(isTrue),
          reason: 'RoomBannerWidget must pass isHost: true for a host membership');
    });

    test('DiceRoomService passes isHost: true for a host membership', () async {
      diceService.joinRoom('HOST-ROOM', 'DM', remember: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final calls = spyStarter.isHostCallsFor('dice_room_service');
      expect(calls, isNotEmpty,
          reason: 'DiceRoomService must invoke RoomSessionStarter.start');
      expect(calls, everyElement(isTrue),
          reason: 'DiceRoomService must pass isHost: true for a host membership');
    });
  });
}
