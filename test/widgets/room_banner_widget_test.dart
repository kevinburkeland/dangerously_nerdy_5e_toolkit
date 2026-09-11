import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_connection_telemetry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/room_connection_badge.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/room_banner_widget.dart';

class MockP2pTransport implements IP2pTransportPort {
  String? currentRoomCode;
  String? currentLocalNodeId;
  bool isDisconnected = false;
  Map<String, int> _peerLastSeen = const {};
  final StreamController<String> _incomingController = StreamController<String>.broadcast();

  @override
  TransportState get currentState => isDisconnected ? TransportState.offline : TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => _peerLastSeen;

  void setPeerLastSeen(Map<String, int> peers) {
    _peerLastSeen = peers;
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    currentRoomCode = roomCode;
    currentLocalNodeId = localNodeId;
    isDisconnected = false;
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  @override
  Future<void> disconnect() async {
    isDisconnected = true;
  }
}

class MockCampaignRepo implements ICampaignRepository {
  @override
  CampaignProfile? get activeProfile => null;
  @override
  String? get activeProfileId => null;
  @override
  List<CampaignProfile> get allProfiles => [];
  @override
  Future<void> deleteProfile(String id) async {}
  @override
  Future<CampaignProfile?> getActiveProfile() async => null;
  @override
  Future<CampaignProfile?> getProfile(String id) async => null;
  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => [];
  @override
  Future<void> saveProfile(CampaignProfile profile) async {}
  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {}
  @override
  Future<void> setActiveProfileId(String id) async {}
  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();
  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();
}

class MockNetworkTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => DateTime.now().millisecondsSinceEpoch;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('RoomBannerWidget renders Solo Mode when disconnected', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: null,
        playerName: null,
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    expect(find.text('Solo Mode'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
  });

  testWidgets('RoomBannerWidget renders Room Code and Player Name when connected', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: 'ROOM-1234',
        playerName: 'Gandalf',
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    expect(find.text('ROOM-1234'), findsOneWidget);
    expect(find.textContaining('Gandalf'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
  });

  testWidgets('Tapping Join Room opens dialog modal and handles cancel action', (WidgetTester tester) async {
    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: null,
        playerName: null,
        onJoinRoom: (r, p) {},
        onLeaveRoom: () {},
      ),
    ));

    await tester.tap(find.text('Join Room'));
    await tester.pumpAndSettle();

    expect(find.text('Shared Dice Room'), findsOneWidget);
    expect(find.text('Your Display Name'), findsOneWidget);
    expect(find.text('Room Code'), findsOneWidget);
    expect(find.text('Remember room on this device'), findsOneWidget);
    expect(find.text('Enter Room'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Shared Dice Room'), findsNothing);
  });

  testWidgets('RoomBannerWidget updates automatically when DiceRoomService session changes', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(roomService: roomService),
    ));

    expect(find.text('Solo Mode'), findsOneWidget);

    roomService.joinRoom('ROOM-TEST99', 'Aragorn');
    await tester.pumpAndSettle();

    expect(find.text('ROOM-TEST99'), findsOneWidget);
    expect(find.textContaining('Aragorn'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    roomService.leaveRoom();
    await tester.pumpAndSettle();

    expect(find.text('Solo Mode'), findsOneWidget);
  });

  testWidgets('JoinCreateRoomDialog submits and joins room with persistence', (WidgetTester tester) async {
    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(roomService: roomService),
    ));

    await tester.tap(find.text('Join Room'));
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.widgetWithText(TextField, 'Your Display Name'), 'Legolas');
    // Enter room code and submit via Enter (onSubmitted)
    await tester.enterText(find.widgetWithText(TextField, 'Room Code'), 'ROOM-ELVEN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('ROOM-ELVEN'), findsOneWidget);
    expect(find.textContaining('Legolas'), findsOneWidget);
    expect(roomService.activeRoomCode, 'ROOM-ELVEN');
    expect(roomService.playerName, 'Legolas');
    expect(roomService.isSessionRemembered, isTrue);

    roomService.leaveRoom();
  });

  testWidgets('RoomBannerWidget renders RoomConnectionBadge with active telemetry when connected', (WidgetTester tester) async {
    final telemetryController = StreamController<RoomConnectionTelemetry>.broadcast();
    addTearDown(() => telemetryController.close());

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(
        activeRoomCode: 'ROOM-CONNECTED',
        playerName: 'Gimli',
        telemetryStream: telemetryController.stream,
        initialTelemetry: const RoomConnectionTelemetry(
          state: TransportState.webRtc,
          peerCount: 3,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RoomConnectionBadge), findsOneWidget);
    expect(find.text('WebRTC P2P (3)'), findsOneWidget);

    // Update telemetry dynamically
    telemetryController.add(const RoomConnectionTelemetry(
      state: TransportState.localWifi,
      peerCount: 5,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Local Wi-Fi (5)'), findsOneWidget);
  });

  testWidgets('RoomBannerWidget automatically connects transport and reflects live peer count when room is joined', (WidgetTester tester) async {
    final mockTransport = MockP2pTransport();
    sl.registerSingleton<IP2pTransportPort>(mockTransport);
    final orchestrator = RoomSyncOrchestrator(
      transportPort: mockTransport,
      campaignRepo: MockCampaignRepo(),
      reconciliationService: RoomStateReconciliationService(),
      clockSyncService: ClockSyncService(networkTimePort: MockNetworkTimePort()),
      diceRoomService: DiceRoomService(),
      telemetryInterval: const Duration(milliseconds: 100),
    );
    sl.registerSingleton<RoomSyncOrchestrator>(orchestrator);
    addTearDown(() {
      orchestrator.stopSynchronization();
      sl.reset();
    });

    final roomService = DiceRoomService();
    roomService.leaveRoom();

    await tester.pumpWidget(createTestableWidget(
      RoomBannerWidget(roomService: roomService),
    ));

    expect(find.text('Solo Mode'), findsOneWidget);

    // Join room
    roomService.joinRoom('ROOM-AUTO-SYNC', 'Faramir');
    await tester.pumpAndSettle();

    expect(find.text('ROOM-AUTO-SYNC'), findsOneWidget);
    expect(find.textContaining('Faramir'), findsOneWidget);
    expect(find.byType(RoomConnectionBadge), findsOneWidget);
    expect(mockTransport.currentRoomCode, 'ROOM-AUTO-SYNC');
    expect(orchestrator.isSynchronizing, isTrue);

    // Simulate remote peer connecting
    mockTransport.setPeerLastSeen({'peer-remote-1': DateTime.now().millisecondsSinceEpoch});
    // Wait for telemetry monitor to poll
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.text('WebRTC P2P (1)'), findsOneWidget);

    roomService.leaveRoom();
    await tester.pumpAndSettle();

    expect(find.text('Solo Mode'), findsOneWidget);
    expect(mockTransport.isDisconnected, isTrue);
  });
}
