import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/signaling_message.dart';
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

class FakeRTCPeerConnection implements RTCPeerConnection {
  final FakeRTCDataChannel dataChannel;
  bool isClosed = false;
  RTCSessionDescription? localDescription;
  RTCSessionDescription? remoteDescription;

  FakeRTCPeerConnection({FakeRTCDataChannel? channel})
      : dataChannel = channel ?? FakeRTCDataChannel();

  @override
  void Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  void Function(RTCIceConnectionState state)? onIceConnectionState;

  @override
  Future<RTCDataChannel> createDataChannel(String label, RTCDataChannelInit dataChannelDict) async {
    return dataChannel;
  }

  @override
  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? constraints]) async {
    return RTCSessionDescription('v=0\r\no=fake-offer-sdp', 'offer');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    localDescription = description;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    remoteDescription = description;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRtcPeerConnectionFactory implements IRtcPeerConnectionFactory {
  FakeRTCPeerConnection? nextConnection;

  @override
  Future<RTCPeerConnection> createConnection(Map<String, dynamic> configuration) async {
    return nextConnection ?? FakeRTCPeerConnection();
  }
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

    test('Emits onPeersChanged stream when data channels are registered and closed', () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final peerEvents = <Set<String>>[];
      final sub = adapter.onPeersChanged.listen(peerEvents.add);

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-live', fakeChannel);

      // Trigger data channel open state
      fakeChannel.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);

      expect(peerEvents, isNotEmpty);
      expect(peerEvents.last, contains('peer-live'));

      // Close data channel
      adapter.prunePeer('peer-live');
      await Future<void>.delayed(Duration.zero);

      expect(peerEvents.last, isEmpty);

      await sub.cancel();
    });

    test('Late-Joiner Re-Signaling Test: peerJoin triggers fresh targeted SDP offer and deletes join signal', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final adapterWithFactory = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await adapterWithFactory.initializeRoom('ROOM-REJOIN', 'node-A');

      // Inject peerJoin signal from late-joining node B
      final joinMessage = SignalingMessage(
        id: 'join-signal-node-b',
        roomCode: 'ROOM-REJOIN',
        fromNodeId: 'node-B',
        toNodeId: '*',
        type: SignalingType.peerJoin,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      signalingAdapter.emitIncomingSignal(joinMessage);
      await Future<void>.delayed(Duration.zero);

      // Verify targeted offer was sent to node-B
      expect(signalingAdapter.trackedDocPaths.any((p) => p.contains('rooms/ROOM-REJOIN/signaling/')), isTrue);
      // Verify join signal was deleted
      expect(deletedSignalingDocs, contains('rooms/ROOM-REJOIN/signaling/join-signal-node-b'));

      await adapterWithFactory.disconnect();
    });
  });
}
