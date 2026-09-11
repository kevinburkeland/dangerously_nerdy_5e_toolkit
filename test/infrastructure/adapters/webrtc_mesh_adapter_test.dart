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
  RTCDataChannelState? state = RTCDataChannelState.RTCDataChannelConnecting;

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    if (isClosed) throw StateError('Channel closed');
    sentMessages.add(message);
  }

  @override
  Future<void> close() async {
    isClosed = true;
    state = RTCDataChannelState.RTCDataChannelClosed;
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
  void Function(RTCDataChannel channel)? onDataChannel;

  @override
  Future<RTCDataChannel> createDataChannel(String label, RTCDataChannelInit dataChannelDict) async {
    return dataChannel;
  }

  @override
  Future<RTCSessionDescription> createOffer([Map<String, dynamic>? constraints]) async {
    return RTCSessionDescription('v=0\r\no=fake-offer-sdp', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer([Map<String, dynamic>? constraints]) async {
    return RTCSessionDescription('v=0\r\no=fake-answer-sdp', 'answer');
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

    test('broadcastPayload is a silent no-op when data channels are empty and does not throw', () async {
      await adapter.initializeRoom('ROOM-EMPTY', 'local-node');
      expect(adapter.connectedPeers, isEmpty);

      // Must succeed cleanly without throwing StateError so CascadingTransportRouter does not step down
      await expectLater(
        adapter.broadcastPayload('{"type":"dice_roll","total":18}'),
        completes,
      );
    });

    test('Transient ICE disconnection does not prune peer; only failed state prunes peer', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-ICE', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      expect(testAdapter.connectedPeers, contains('node-remote'));

      // Transient disconnected event (packet loss / mobile radio power save)
      fakePc.onIceConnectionState?.call(RTCIceConnectionState.RTCIceConnectionStateDisconnected);
      await Future<void>.delayed(Duration.zero);

      // Peer must NOT be pruned on transient disconnection
      expect(testAdapter.connectedPeers, contains('node-remote'));

      // Permanent failure event
      fakePc.onIceConnectionState?.call(RTCIceConnectionState.RTCIceConnectionStateFailed);
      await Future<void>.delayed(Duration.zero);

      // Peer must be pruned on failed state
      expect(testAdapter.connectedPeers.contains('node-remote'), isFalse);

      await testAdapter.disconnect();
    });

    test('WebRTC Glare Resolution: Higher node ID retains outbound offer and drops colliding offer', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final adapterNodeZ = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      // Node Z > Node A
      await adapterNodeZ.initializeRoom('ROOM-GLARE', 'node-Z');
      await adapterNodeZ.connectToPeer('node-A');

      // Colliding offer arrives from node-A
      final collidingOffer = SignalingMessage(
        id: 'offer-signal-from-a',
        roomCode: 'ROOM-GLARE',
        fromNodeId: 'node-A',
        toNodeId: 'node-Z',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-from-a',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      signalingAdapter.emitIncomingSignal(collidingOffer);
      await Future<void>.delayed(Duration.zero);

      // Node Z is higher rank -> drops colliding offer and consumes/deletes signal
      expect(deletedSignalingDocs, contains('rooms/ROOM-GLARE/signaling/offer-signal-from-a'));
      // In-flight connection to node-A was NOT closed
      expect(fakePc.isClosed, isFalse);

      await adapterNodeZ.disconnect();
    });

    test('WebRTC Glare Resolution: Lower node ID yields in-flight connection and accepts colliding offer', () async {
      final inFlightPc = FakeRTCPeerConnection();
      final replacementPc = FakeRTCPeerConnection();

      var connectionCount = 0;
      final multiFactory = _DynamicFactory((_) {
        connectionCount++;
        return connectionCount == 1 ? inFlightPc : replacementPc;
      });

      final adapterNodeA = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: multiFactory,
      );

      // Node A < Node Z
      await adapterNodeA.initializeRoom('ROOM-GLARE-2', 'node-A');
      await adapterNodeA.connectToPeer('node-Z');

      // Node A has in-flight connection
      expect(inFlightPc.isClosed, isFalse);

      // Colliding offer arrives from higher-ranked node-Z
      final collidingOffer = SignalingMessage(
        id: 'offer-signal-from-z',
        roomCode: 'ROOM-GLARE-2',
        fromNodeId: 'node-Z',
        toNodeId: 'node-A',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-from-z',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      signalingAdapter.emitIncomingSignal(collidingOffer);
      await Future<void>.delayed(Duration.zero);

      // Node A yielded its in-flight connection to node-Z
      expect(inFlightPc.isClosed, isTrue);
      // Replacement PC accepted remote offer and created answer
      expect(replacementPc.remoteDescription?.sdp, 'v=0\r\no=sdp-from-z');
      expect(replacementPc.localDescription?.type, 'answer');

      await adapterNodeA.disconnect();
    });

    test('3-node mesh room preserves Node C signaling documents when Node B establishes connection', () async {
      final fakePcB = FakeRTCPeerConnection();
      final fakePcC = FakeRTCPeerConnection();

      var connectionCount = 0;
      final multiFactory = _DynamicFactory((_) {
        connectionCount++;
        return connectionCount == 1 ? fakePcB : fakePcC;
      });

      final multiMeshAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: multiFactory,
      );

      await multiMeshAdapter.initializeRoom('ROOM-MULTI-3', 'node-A');

      // Initiate connection to Node B and Node C
      await multiMeshAdapter.connectToPeer('node-B');
      await multiMeshAdapter.connectToPeer('node-C');

      // Check that both peer-B and peer-C have tracked documents in signaling
      expect(signalingAdapter.peerTrackedDocPaths.containsKey('node-B'), isTrue);
      expect(signalingAdapter.peerTrackedDocPaths.containsKey('node-C'), isTrue);
      final docCountB = signalingAdapter.peerTrackedDocPaths['node-B']!.length;
      final docCountC = signalingAdapter.peerTrackedDocPaths['node-C']!.length;
      expect(docCountB, greaterThan(0));
      expect(docCountC, greaterThan(0));

      // Node B establishes ICE connection & DataChannel opens
      fakePcB.onIceConnectionState?.call(RTCIceConnectionState.RTCIceConnectionStateConnected);
      fakePcB.dataChannel.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);

      // Node B's signaling documents are purged
      expect(signalingAdapter.peerTrackedDocPaths.containsKey('node-B'), isFalse);
      for (final path in deletedSignalingDocs) {
        expect(path, isNot(contains('node-C')));
      }

      // Node C's signaling documents are PRESERVED!
      expect(signalingAdapter.peerTrackedDocPaths.containsKey('node-C'), isTrue);
      expect(signalingAdapter.peerTrackedDocPaths['node-C']!.length, equals(docCountC));

      await multiMeshAdapter.disconnect();
    });
  });
}

class _DynamicFactory implements IRtcPeerConnectionFactory {
  final RTCPeerConnection Function(Map<String, dynamic> config) _builder;
  _DynamicFactory(this._builder);

  @override
  Future<RTCPeerConnection> createConnection(Map<String, dynamic> configuration) async {
    return _builder(configuration);
  }
}
