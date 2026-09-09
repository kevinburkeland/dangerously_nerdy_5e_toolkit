import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';

class FakeRTCDataChannel implements RTCDataChannel {
  @override
  void Function(RTCDataChannelMessage message)? onMessage;

  @override
  void Function(RTCDataChannelState state)? onDataChannelState;

  final List<RTCDataChannelMessage> sentMessages = [];
  bool isClosed = false;

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    if (isClosed) throw StateError('Channel closed');
    sentMessages.add(message);
  }

  @override
  Future<void> close() async {
    isClosed = true;
    onDataChannelState?.call(RTCDataChannelState.RTCDataChannelClosed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WebRtcMeshAdapter Unit Tests', () {
    late FirebaseSignalingAdapter signalingAdapter;
    late WebRtcMeshAdapter adapter;
    late List<String> deletedSignalingDocs;

    setUp(() {
      deletedSignalingDocs = [];
      signalingAdapter = FirebaseSignalingAdapter(
        onDeleteDocument: (path) async {
          deletedSignalingDocs.add(path);
        },
      );
      adapter = WebRtcMeshAdapter(signalingAdapter: signalingAdapter);
    });

    tearDown(() async {
      await adapter.disconnect();
    });

    test('Initializes room and manages data channels for peers', () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-1', fakeChannel);

      expect(adapter.connectedPeers, contains('peer-1'));
      expect(adapter.peerLastActiveTimestamps.containsKey('peer-1'), isTrue);
    });

    test('Broadcasts payload across all connected data channels', () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final channel1 = FakeRTCDataChannel();
      final channel2 = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-1', channel1);
      adapter.registerMockDataChannel('peer-2', channel2);

      const payload = '{"crdt":"delta","v":1}';
      await adapter.broadcastPayload(payload);

      expect(channel1.sentMessages.length, 1);
      expect(channel1.sentMessages.first.text, payload);
      expect(channel2.sentMessages.length, 1);
      expect(channel2.sentMessages.first.text, payload);
    });

    test('Handles incoming payloads and filters heartbeat protocol messages', () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-1', fakeChannel);

      final receivedPayloads = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(receivedPayloads.add);

      // Heartbeat ping should be consumed, respond with pong, and NOT emitted to payload stream
      fakeChannel.onMessage?.call(RTCDataChannelMessage(
        '{"_protocol":"heartbeat_ping","from":"peer-1","timestamp":100}',
      ));

      expect(fakeChannel.sentMessages.any((m) => m.text.contains('heartbeat_pong')), isTrue);
      expect(receivedPayloads, isEmpty);

      // Real CRDT payload should be emitted to incoming stream
      const appData = '{"crdt":"character_sync","name":"Thorin"}';
      fakeChannel.onMessage?.call(RTCDataChannelMessage(appData));

      await Future<void>.delayed(Duration.zero);
      expect(receivedPayloads, [appData]);

      await sub.cancel();
    });

    test('Prunes peer when data channel is closed', () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-to-close', fakeChannel);
      expect(adapter.connectedPeers, contains('peer-to-close'));

      await fakeChannel.close();

      expect(adapter.connectedPeers.contains('peer-to-close'), isFalse);
      expect(adapter.peerLastActiveTimestamps.containsKey('peer-to-close'), isFalse);
    });
  });
}
