import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_channel_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

import '../test_doubles/hive_test_harness.dart';

class FakeP2pTransport implements IP2pTransportPort, BlobChannelPort {
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
    await harness.setUp('dice_room_char_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('DiceRoomService Characterization Test', () {
    test(
        'broadcastRoll sends dice_roll payload, restorePersistedSession initializes transport and starts sync, leaveRoom stops sync and disconnects',
        () async {
      final fakeTransport = FakeP2pTransport();
      await initServiceLocator(
        p2pTransport: fakeTransport,
        blobChannel: fakeTransport,
      );

      final diceService = DiceRoomService();
      final orchestrator = sl<RoomSyncOrchestrator>();

      // 1. Local roll in a joined room broadcasts exactly one payload with type: 'dice_roll'
      diceService.joinRoom('TEST1', 'Player1', remember: false);
      final roll = RoomRoll(
        id: 'roll_char_1',
        roomCode: 'TEST1',
        playerName: 'Player1',
        formulaString: '1d20+5',
        total: 18,
        individualRolls: const [13],
        isCrit: false,
        isFumble: false,
        timestamp: DateTime.now(),
      );
      await diceService.broadcastRoll(roll);

      expect(fakeTransport.broadcasted.length, equals(1));
      final payload =
          jsonDecode(fakeTransport.broadcasted.first) as Map<String, dynamic>;
      expect(payload['type'], equals('dice_roll'));
      expect(payload['roomCode'], equals('TEST1'));

      // 2. Restoring a remembered session initializes room on fake transport and starts room sync
      diceService.leaveRoom();
      await Future<void>.delayed(Duration.zero);
      expect(orchestrator.isSynchronizing, isFalse);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dice_room_persisted_remember', true);
      await prefs.setString('dice_room_persisted_code', 'REMEMBER1');
      await prefs.setString('dice_room_persisted_player_name', 'SavedPlayer');

      await diceService.restorePersistedSession();
      // Allow unawaited async calls in _connectTransport to execute
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        fakeTransport.initializedRooms
            .any((r) => r.roomCode == 'REMEMBER1'),
        isTrue,
        reason: 'Restoring remembered session must initialize room on transport',
      );
      expect(orchestrator.isSynchronizing, isTrue,
          reason: 'Restoring remembered session must start sync once');

      // 3. Leaving the room stops synchronization and calls disconnect on the fake
      await diceService.leaveRoomAsync();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(orchestrator.isSynchronizing, isFalse,
          reason: 'Leaving room must stop synchronization');
      expect(fakeTransport.disconnectCalls, greaterThanOrEqualTo(1),
          reason: 'Leaving room must call disconnect on transport');
    });
  });
}
