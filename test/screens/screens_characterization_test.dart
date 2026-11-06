import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_channel_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/screens/homebrew/homebrew_expert_options_view.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/room_connection_badge.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/party_room_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';

import '../test_doubles/fake_room_document_port.dart';
import '../test_doubles/hive_test_harness.dart';

class SpyingPartyRoomService extends Fake implements PartyRoomService {
  int syncCalls = 0;
  @override
  Future<void> syncAllExistingCampaignsToFirestore() async {
    syncCalls++;
  }
}

class FakePartyRoomService extends Fake implements PartyRoomService {
  @override
  final ReplicaId replicaId = ReplicaId('test_screen_replica');

  @override
  Future<void> flushOutbox(String roomCode) async {}

  PartySessionState _makeState(String roomCode) => PartySessionState(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
        hostKeyHash: 'dummy_hash',
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

  @override
  Future<PartySessionState> ensureRoomExists({
    required String roomCode,
    String? campaignName,
    String? hostKey,
    bool isStateless = true,
  }) async {
    return _makeState(roomCode);
  }

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
  Stream<PartySessionState> streamSession(String roomCode) {
    return Stream.value(_makeState(roomCode));
  }

  @override
  Stream<List<PartyLootItem>> streamLoot(String roomCode,
      {bool includeArchived = false}) {
    return Stream.value(const []);
  }

  @override
  Stream<List<PartyEvent>> streamEvents(String roomCode) {
    return Stream.value(const []);
  }

  @override
  final ValueNotifier<int> pendingOutboxCount = ValueNotifier<int>(0);

  @override
  Stream<ClaimConflictEvent> get claimConflictStream => const Stream.empty();

  @override
  Stream<PurseOverdraftEvent> get overdraftStream => const Stream.empty();
}

class FakeScreenTransport implements IP2pTransportPort, BlobChannelPort {
  final List<String> broadcasted = [];
  final List<({String roomCode, String localNodeId})> initializedRooms = [];
  int disconnectCalls = 0;
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  @override
  Set<String> get openBlobPeers => const {};

  @override
  Stream<Set<String>> get onBlobPeersChanged => const Stream.empty();

  @override
  Stream<BlobChannelMessage> get blobMessages => const Stream.empty();

  @override
  Future<void> sendBlobText(String peerId, String text) async {}

  @override
  Future<void> sendBlobFrame(String peerId, Uint8List frame) async {}

  @override
  TransportState get currentState => TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    initializedRooms.add((roomCode: roomCode, localNodeId: localNodeId));
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcasted.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('screens_char_test_');
  });

  tearDown(() async {
    if (sl.isRegistered<RoomSyncOrchestrator>()) {
      sl<RoomSyncOrchestrator>().stopSynchronization();
    }
    if (sl.isRegistered<IP2pTransportPort>()) {
      await sl<IP2pTransportPort>().disconnect();
    }
    PartyRoomService.setCustomInstanceForTesting(null);
    sl.reset();
    await harness.tearDown();
  });

  group('Screens Characterization Tests', () {
    testWidgets(
        'LandingScreen: opening once after DI asks PartyRoomService to sync existing campaigns once',
        (tester) async {
      await initServiceLocator();
      final spyService = SpyingPartyRoomService();
      sl.unregister<PartyRoomService>();
      sl.registerSingleton<PartyRoomService>(spyService);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LandingScreen()),
        ),
      );

      expect(spyService.syncCalls, equals(1),
          reason: 'LandingScreen must ask PartyRoomService to sync once');
    });

    testWidgets(
        'RoomBannerWidget: connects and reaches registered RoomSyncOrchestrator and IP2pTransportPort',
        (tester) async {
      final fakeTransport = FakeScreenTransport();
      await initServiceLocator(
        p2pTransport: fakeTransport,
        blobChannel: fakeTransport,
        roomDocumentPort: RecordingRoomDocumentPort(),
      );

      PartyRoomService.setCustomInstanceForTesting(FakePartyRoomService());

      final orchestrator = sl<RoomSyncOrchestrator>();
      expect(orchestrator.isSynchronizing, isFalse);

      final diceService = DiceRoomService();
      diceService.leaveRoom();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomBannerWidget(roomService: diceService),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Solo Mode'), findsOneWidget);

      // Join room to trigger _checkAndConnect
      diceService.joinRoom('BANNER-AUTO-SYNC', 'Gerralt', remember: false);
      await tester.pump();

      expect(
        fakeTransport.initializedRooms
            .any((r) => r.roomCode == 'BANNER-AUTO-SYNC'),
        isTrue,
        reason: 'RoomBannerWidget must initialize room on registered transport',
      );
      expect(orchestrator.isSynchronizing, isTrue,
          reason: 'RoomBannerWidget must start registered orchestrator');
      orchestrator.stopSynchronization();
    });

    testWidgets(
        'PartyRoomScreen: reaches registered RoomSyncOrchestrator and IP2pTransportPort',
        (tester) async {
      final fakeTransport = FakeScreenTransport();
      await initServiceLocator(
        p2pTransport: fakeTransport,
        blobChannel: fakeTransport,
        roomDocumentPort: RecordingRoomDocumentPort(),
      );

      PartyRoomService.setCustomInstanceForTesting(FakePartyRoomService());

      final orchestrator = sl<RoomSyncOrchestrator>();
      final transport = sl<IP2pTransportPort>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PartyRoomScreen(
              roomCode: 'PARTY-CHAR-1',
              initialPlayerName: 'PartyHero',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(orchestrator, isNotNull);
      expect(transport, isNotNull);
      expect(find.byType(RoomConnectionBadge), findsOneWidget);
      orchestrator.stopSynchronization();
    });

    testWidgets(
        'HomebrewExpertOptionsView: uses the DI clock when mounted without customClock',
        (tester) async {
      await initServiceLocator();

      final diClock = sl<StatefulHlcClock>();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomebrewExpertOptionsView(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HOMOGENEOUS SINGLE-RULESET MANDATE'), findsOneWidget);
      expect(diClock, isNotNull);
    });
  });
}
