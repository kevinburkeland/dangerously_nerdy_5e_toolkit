import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_channel_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/signaling_message.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';

class FakeRTCDataChannel implements RTCDataChannel {
  @override
  String? label;

  @override
  void Function(RTCDataChannelMessage message)? onMessage;

  @override
  void Function(RTCDataChannelState state)? onDataChannelState;

  @override
  int? bufferedAmount;

  @override
  int? bufferedAmountLowThreshold;

  @override
  void Function(int currentAmount)? onBufferedAmountLow;

  final List<RTCDataChannelMessage> sentMessages = [];
  bool isClosed = false;

  @override
  RTCDataChannelState? state = RTCDataChannelState.RTCDataChannelConnecting;

  FakeRTCDataChannel({
    this.label,
    this.bufferedAmount = 0,
    this.bufferedAmountLowThreshold = 0,
  });

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

class ChannelCreationRecord {
  final String label;
  final RTCDataChannelInit init;
  final FakeRTCDataChannel channel;

  const ChannelCreationRecord(this.label, this.init, this.channel);
}

class FakeRTCPeerConnection implements RTCPeerConnection {
  FakeRTCDataChannel dataChannel;
  final List<ChannelCreationRecord> createdChannels = [];
  final Map<String, FakeRTCDataChannel> channelsByLabel = {};
  final List<String> operationOrder = [];
  bool isClosed = false;
  RTCSessionDescription? localDescription;
  RTCSessionDescription? remoteDescription;

  FakeRTCPeerConnection({FakeRTCDataChannel? channel})
      : dataChannel = channel ?? FakeRTCDataChannel(label: 'dn5e_mesh');

  @override
  void Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  void Function(RTCIceConnectionState state)? onIceConnectionState;

  @override
  void Function(RTCDataChannel channel)? onDataChannel;

  @override
  Future<RTCDataChannel> createDataChannel(
      String label, RTCDataChannelInit dataChannelDict) async {
    operationOrder.add('createDataChannel:$label');
    final ch = FakeRTCDataChannel(label: label);
    createdChannels.add(ChannelCreationRecord(label, dataChannelDict, ch));
    channelsByLabel[label] = ch;
    if (label == 'dn5e_mesh') {
      dataChannel = ch;
    }
    return ch;
  }

  @override
  Future<RTCSessionDescription> createOffer(
      [Map<String, dynamic>? constraints]) async {
    operationOrder.add('createOffer');
    return RTCSessionDescription('v=0\r\no=fake-offer-sdp', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer(
      [Map<String, dynamic>? constraints]) async {
    operationOrder.add('createAnswer');
    return RTCSessionDescription('v=0\r\no=fake-answer-sdp', 'answer');
  }

  bool rollbackCalled = false;
  bool throwOnRollback = false;

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    operationOrder.add('setLocalDescription:${description.type}');
    localDescription = description;
    if (description.type == 'rollback') {
      rollbackCalled = true;
      if (throwOnRollback) {
        throw StateError('Platform channel rollback failed');
      }
    }
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    operationOrder.add('setRemoteDescription:${description.type}');
    remoteDescription = description;
  }

  @override
  Future<void> close() async {
    operationOrder.add('close');
    isClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRtcPeerConnectionFactory implements IRtcPeerConnectionFactory {
  FakeRTCPeerConnection? nextConnection;

  @override
  Future<RTCPeerConnection> createConnection(
      Map<String, dynamic> configuration) async {
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

    test('Handles incoming payloads and filters heartbeat protocol messages',
        () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-1', fakeChannel);

      final receivedPayloads = <String>[];
      final sub = adapter.watchIncomingPayloads().listen(receivedPayloads.add);

      // Heartbeat ping should be consumed, respond with pong, and NOT emitted to payload stream
      fakeChannel.onMessage?.call(RTCDataChannelMessage(
        '{"_protocol":"heartbeat_ping","from":"peer-1","timestamp":100}',
      ));

      expect(
          fakeChannel.sentMessages
              .any((m) => m.text.contains('heartbeat_pong')),
          isTrue);
      expect(receivedPayloads, isEmpty);

      // Real CRDT payload should be emitted to incoming stream
      const appData = '{"crdt":"character_sync","name":"Thorek"}';
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
      expect(adapter.peerLastActiveTimestamps.containsKey('peer-to-close'),
          isFalse);
    });

    test(
        'Emits onPeersChanged stream when data channels are registered and closed',
        () async {
      await adapter.initializeRoom('ROOM-MESH', 'local-node');

      final peerEvents = <Set<String>>[];
      final sub = adapter.onPeersChanged.listen(peerEvents.add);

      final fakeChannel = FakeRTCDataChannel();
      adapter.registerMockDataChannel('peer-live', fakeChannel);

      // Trigger data channel open state
      fakeChannel.onDataChannelState
          ?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);

      expect(peerEvents, isNotEmpty);
      expect(peerEvents.last, contains('peer-live'));

      // Close data channel
      adapter.prunePeer('peer-live');
      await Future<void>.delayed(Duration.zero);

      expect(peerEvents.last, isEmpty);

      await sub.cancel();
    });

    test(
        'Late-Joiner Re-Signaling Test: peerJoin triggers fresh targeted SDP offer and deletes join signal',
        () async {
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
      expect(
          signalingAdapter.trackedDocPaths
              .any((p) => p.contains('rooms/ROOM-REJOIN/nodes/')),
          isTrue);
      // Verify join signal was deleted
      expect(deletedSignalingDocs,
          contains('rooms/ROOM-REJOIN/nodes/*/signals/join-signal-node-b'));

      await adapterWithFactory.disconnect();
    });

    test(
        'broadcastPayload throws StateError when data channels are empty to signal failover cascade',
        () async {
      await adapter.initializeRoom('ROOM-EMPTY', 'local-node');
      expect(adapter.connectedPeers, isEmpty);

      // Must throw StateError so CascadingTransportRouter steps down to cloud relay
      await expectLater(
        adapter.broadcastPayload('{"type":"dice_roll","total":18}'),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'Transient ICE disconnection does not prune peer; only failed state prunes peer',
        () async {
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
      fakePc.onIceConnectionState
          ?.call(RTCIceConnectionState.RTCIceConnectionStateDisconnected);
      await Future<void>.delayed(Duration.zero);

      // Peer must NOT be pruned on transient disconnection
      expect(testAdapter.connectedPeers, contains('node-remote'));

      // Permanent failure event
      fakePc.onIceConnectionState
          ?.call(RTCIceConnectionState.RTCIceConnectionStateFailed);
      await Future<void>.delayed(Duration.zero);

      // Peer must be pruned on failed state
      expect(testAdapter.connectedPeers.contains('node-remote'), isFalse);

      await testAdapter.disconnect();
    });

    test(
        'WebRTC Glare Resolution: Higher node ID retains outbound offer and drops colliding offer',
        () async {
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
      expect(
          deletedSignalingDocs,
          contains(
              'rooms/ROOM-GLARE/nodes/node-Z/signals/offer-signal-from-a'));
      // In-flight connection to node-A was NOT closed
      expect(fakePc.isClosed, isFalse);

      await adapterNodeZ.disconnect();
    });

    test(
        'WebRTC Glare Resolution: Lower node ID yields in-flight connection and accepts colliding offer',
        () async {
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

      // Polite Node A executed rollback on its in-flight connection rather than deadlocking
      expect(inFlightPc.rollbackCalled, isTrue);
      // Existing PC accepted remote offer and created answer cleanly
      expect(inFlightPc.remoteDescription?.sdp, 'v=0\r\no=sdp-from-z');
      expect(inFlightPc.localDescription?.type, 'answer');

      await adapterNodeA.disconnect();
    });

    test(
        'WebRTC Glare Resolution: Rollback failure triggers peer pruning and clean connection re-initialization',
        () async {
      final inFlightPc = FakeRTCPeerConnection()..throwOnRollback = true;
      final cleanPc = FakeRTCPeerConnection();
      var connectionCount = 0;
      final dynamicFactory = _DynamicFactory((_) {
        connectionCount++;
        return connectionCount == 1 ? inFlightPc : cleanPc;
      });

      final adapterNodeA = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: dynamicFactory,
      );

      await adapterNodeA.initializeRoom('ROOM-GLARE-THROW', 'node-A');
      await adapterNodeA.connectToPeer('node-Z');

      expect(inFlightPc.isClosed, isFalse);

      final collidingOffer = SignalingMessage(
        id: 'offer-signal-from-z',
        roomCode: 'ROOM-GLARE-THROW',
        fromNodeId: 'node-Z',
        toNodeId: 'node-A',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-from-z',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      signalingAdapter.emitIncomingSignal(collidingOffer);
      await Future<void>.delayed(Duration.zero);

      // Rollback was attempted and threw
      expect(inFlightPc.rollbackCalled, isTrue);
      // In-flight PC was pruned and closed
      expect(inFlightPc.isClosed, isTrue);
      // Clean PC was created and accepted the remote offer
      expect(cleanPc.remoteDescription?.sdp, 'v=0\r\no=sdp-from-z');
      expect(cleanPc.localDescription?.type, 'answer');

      await adapterNodeA.disconnect();
    });

    test(
        '3-node mesh room preserves Node C signaling documents when Node B establishes connection',
        () async {
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
      expect(
          signalingAdapter.peerTrackedDocPaths.containsKey('node-B'), isTrue);
      expect(
          signalingAdapter.peerTrackedDocPaths.containsKey('node-C'), isTrue);
      final docCountB = signalingAdapter.peerTrackedDocPaths['node-B']!.length;
      final docCountC = signalingAdapter.peerTrackedDocPaths['node-C']!.length;
      expect(docCountB, greaterThan(0));
      expect(docCountC, greaterThan(0));

      // Node B establishes ICE connection & DataChannel opens
      fakePcB.onIceConnectionState
          ?.call(RTCIceConnectionState.RTCIceConnectionStateConnected);
      fakePcB.dataChannel.onDataChannelState
          ?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);

      // Node B's signaling documents are purged
      expect(
          signalingAdapter.peerTrackedDocPaths.containsKey('node-B'), isFalse);
      for (final path in deletedSignalingDocs) {
        expect(path, isNot(contains('node-C')));
      }

      // Node C's signaling documents are PRESERVED!
      expect(
          signalingAdapter.peerTrackedDocPaths.containsKey('node-C'), isTrue);
      expect(signalingAdapter.peerTrackedDocPaths['node-C']!.length,
          equals(docCountC));

      await multiMeshAdapter.disconnect();
    });

    test('R1: connectToPeer: connection gets exactly two channels: dn5e_mesh and dn5e_blob', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R1', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      expect(fakePc.createdChannels, hasLength(2));
      final meshRecord = fakePc.createdChannels.firstWhere((r) => r.label == 'dn5e_mesh');
      expect(meshRecord.init.ordered, isTrue);
      expect(meshRecord.init.maxRetransmits, equals(30));

      final blobRecord = fakePc.createdChannels.firstWhere((r) => r.label == 'dn5e_blob');
      expect(blobRecord.init.negotiated, isTrue);
      expect(blobRecord.init.id, equals(7));
      expect(blobRecord.init.ordered, isTrue);
      expect(blobRecord.init.maxRetransmits, equals(-1));
      expect(blobRecord.init.maxRetransmitTime, equals(-1));

      await testAdapter.disconnect();
    });

    test('R2: exactly one dn5e_blob per connection on each path', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();

      // Path 1: answering a fresh offer (created before setRemoteDescription)
      final freshPc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = freshPc;

      final adapterPath1 = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );
      await adapterPath1.initializeRoom('ROOM-R2', 'node-local');

      final freshOffer = SignalingMessage(
        id: 'offer-fresh',
        roomCode: 'ROOM-R2',
        fromNodeId: 'node-remote-1',
        toNodeId: 'node-local',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-fresh',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      signalingAdapter.emitIncomingSignal(freshOffer);
      await Future<void>.delayed(Duration.zero);

      expect(freshPc.createdChannels.where((c) => c.label == 'dn5e_blob'), hasLength(1));
      final blobCreateIdx = freshPc.operationOrder.indexOf('createDataChannel:dn5e_blob');
      final remoteDescIdx = freshPc.operationOrder.indexOf('setRemoteDescription:offer');
      expect(blobCreateIdx, greaterThanOrEqualTo(0));
      expect(remoteDescIdx, greaterThan(blobCreateIdx)); // created BEFORE setRemoteDescription
      await adapterPath1.disconnect();

      // Path 2: rollback-failure path's new connection
      final inFlightPc = FakeRTCPeerConnection()..throwOnRollback = true;
      final replacementPc = FakeRTCPeerConnection();
      var pcCount = 0;
      final dynamicFactory = _DynamicFactory((_) {
        pcCount++;
        return pcCount == 1 ? inFlightPc : replacementPc;
      });

      final adapterPath2 = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: dynamicFactory,
      );
      await adapterPath2.initializeRoom('ROOM-R2-RB', 'node-A'); // Node A < Node Z -> polite
      await adapterPath2.connectToPeer('node-Z'); // inFlightPc created

      final collidingOffer = SignalingMessage(
        id: 'offer-colliding',
        roomCode: 'ROOM-R2-RB',
        fromNodeId: 'node-Z',
        toNodeId: 'node-A',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-colliding',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      signalingAdapter.emitIncomingSignal(collidingOffer);
      await Future<void>.delayed(Duration.zero);

      expect(inFlightPc.createdChannels.where((c) => c.label == 'dn5e_blob'), hasLength(1));
      expect(replacementPc.createdChannels.where((c) => c.label == 'dn5e_blob'), hasLength(1));
      await adapterPath2.disconnect();

      // Path 3: polite-glare path that reuses an existing connection
      final politeExistingPc = FakeRTCPeerConnection()..throwOnRollback = false;
      connectionFactory.nextConnection = politeExistingPc;

      final adapterPath3 = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );
      await adapterPath3.initializeRoom('ROOM-R2-POLITE', 'node-A');
      await adapterPath3.connectToPeer('node-Z'); // politeExistingPc created with 1 blob channel

      final collidingOffer2 = SignalingMessage(
        id: 'offer-colliding-2',
        roomCode: 'ROOM-R2-POLITE',
        fromNodeId: 'node-Z',
        toNodeId: 'node-A',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=sdp-colliding-2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      signalingAdapter.emitIncomingSignal(collidingOffer2);
      await Future<void>.delayed(Duration.zero);

      // Reused existing connection without creating another blob channel
      expect(politeExistingPc.createdChannels.where((c) => c.label == 'dn5e_blob'), hasLength(1));
      await adapterPath3.disconnect();
    });

    test('R3: onDataChannel with label dn5e_blob and other: not registered, closed, connectedPeers unchanged', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R3', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      // The mesh channel opened
      fakePc.dataChannel.state = RTCDataChannelState.RTCDataChannelOpen;
      fakePc.dataChannel.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);

      final peersBefore = Set<String>.from(testAdapter.connectedPeers);

      // Unsolicited in-band dn5e_blob from broken peer
      final brokenBlobChannel = FakeRTCDataChannel(label: 'dn5e_blob');
      fakePc.onDataChannel?.call(brokenBlobChannel);
      expect(brokenBlobChannel.isClosed, isTrue);
      expect(testAdapter.connectedPeers, equals(peersBefore));

      // Unsolicited other label
      final otherChannel = FakeRTCDataChannel(label: 'other');
      fakePc.onDataChannel?.call(otherChannel);
      expect(otherChannel.isClosed, isTrue);
      expect(testAdapter.connectedPeers, equals(peersBefore));

      await testAdapter.disconnect();
    });

    test('R4: binary and text on blob channel arrive on blobMessages and never on watchIncomingPayloads; mesh messages never on blobMessages; text > 8192 dropped', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R4', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      final meshDc = fakePc.dataChannel;
      final blobDc = fakePc.channelsByLabel['dn5e_blob']!;

      final receivedBlobMessages = <BlobChannelMessage>[];
      final blobSub = testAdapter.blobMessages.listen(receivedBlobMessages.add);

      final receivedMeshPayloads = <String>[];
      final meshSub = testAdapter.watchIncomingPayloads().listen(receivedMeshPayloads.add);

      // 1. Binary on blob channel arrives on blobMessages with peer id, never on watchIncomingPayloads
      final binaryPayload = Uint8List.fromList([1, 2, 3, 4]);
      blobDc.onMessage?.call(RTCDataChannelMessage.fromBinary(binaryPayload));
      await Future<void>.delayed(Duration.zero);

      expect(receivedBlobMessages, hasLength(1));
      expect(receivedBlobMessages.first.isBinary, isTrue);
      expect(receivedBlobMessages.first.bytes, equals(binaryPayload));
      expect(receivedBlobMessages.first.peerId, equals('node-remote'));
      expect(receivedMeshPayloads, isEmpty);

      // 2. Text on blob channel (<= 8192 chars) arrives on blobMessages, never on watchIncomingPayloads
      const shortText = '{"t":"none","h":"abc"}';
      blobDc.onMessage?.call(RTCDataChannelMessage(shortText));
      await Future<void>.delayed(Duration.zero);

      expect(receivedBlobMessages, hasLength(2));
      expect(receivedBlobMessages.last.isText, isTrue);
      expect(receivedBlobMessages.last.text, equals(shortText));
      expect(receivedMeshPayloads, isEmpty);

      // 3. Text over 8,192 chars on blob channel is dropped
      final longText = 'a' * 8193;
      blobDc.onMessage?.call(RTCDataChannelMessage(longText));
      await Future<void>.delayed(Duration.zero);

      expect(receivedBlobMessages, hasLength(2)); // Still 2, long text was dropped

      // 4. Text on mesh channel arrives on watchIncomingPayloads and never on blobMessages
      const meshMsg = '{"type":"game_state"}';
      meshDc.onMessage?.call(RTCDataChannelMessage(meshMsg));
      await Future<void>.delayed(Duration.zero);

      expect(receivedMeshPayloads, contains(meshMsg));
      expect(receivedBlobMessages, hasLength(2)); // Blob channel still 2

      await blobSub.cancel();
      await meshSub.cancel();
      await testAdapter.disconnect();
    });

    test('R5: with bufferedAmount at 2 MiB, sendBlobFrame waits until onBufferedAmountLow fires, sets threshold 262,144; two calls send in order', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R5', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      final blobDc = fakePc.channelsByLabel['dn5e_blob']!;
      blobDc.state = RTCDataChannelState.RTCDataChannelOpen;
      blobDc.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);

      blobDc.bufferedAmount = 2 * 1024 * 1024; // 2 MiB > kBlobHighWaterBytes (1 MiB)

      final frame1 = Uint8List.fromList([1, 1, 1]);
      final frame2 = Uint8List.fromList([2, 2, 2]);

      var send1Completed = false;
      var send2Completed = false;

      final f1 = testAdapter.sendBlobFrame('node-remote', frame1).then((_) => send1Completed = true);
      final f2 = testAdapter.sendBlobFrame('node-remote', frame2).then((_) => send2Completed = true);

      await Future<void>.delayed(Duration.zero);

      // Threshold was set to 262,144 (kBlobLowWaterBytes)
      expect(blobDc.bufferedAmountLowThreshold, equals(262144));
      // Frame 1 and 2 not sent yet
      expect(send1Completed, isFalse);
      expect(send2Completed, isFalse);
      expect(blobDc.sentMessages, isEmpty);

      // Fire onBufferedAmountLow for frame1
      blobDc.bufferedAmount = 0;
      blobDc.onBufferedAmountLow?.call(0);
      await Future<void>.delayed(Duration.zero);

      // Frame 1 sent, Frame 2 can send immediately since bufferedAmount is now 0
      await f1;
      await f2;
      expect(send1Completed, isTrue);
      expect(send2Completed, isTrue);
      expect(blobDc.sentMessages, hasLength(2));
      expect(blobDc.sentMessages[0].binary, equals(frame1));
      expect(blobDc.sentMessages[1].binary, equals(frame2));

      await testAdapter.disconnect();
    });

    test('R6: sendBlobFrame throws StateError when peer blob channel is not open or closes during wait; frame > 36 + 65,536 throws ArgumentError', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R6', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      final blobDc = fakePc.channelsByLabel['dn5e_blob']!;
      // Not open yet (connecting)
      final validFrame = Uint8List.fromList([1, 2, 3]);
      expect(
        () => testAdapter.sendBlobFrame('node-remote', validFrame),
        throwsA(isA<StateError>()),
      );

      // Open channel
      blobDc.state = RTCDataChannelState.RTCDataChannelOpen;
      blobDc.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);

      // Frame longer than 36 + 65,536 bytes throws ArgumentError
      final oversizedFrame = Uint8List(36 + 65536 + 1);
      expect(
        () => testAdapter.sendBlobFrame('node-remote', oversizedFrame),
        throwsA(isA<ArgumentError>()),
      );
      expect(blobDc.sentMessages, isEmpty);

      // Channel closes while waiting on bufferedAmount
      blobDc.bufferedAmount = 2 * 1024 * 1024;
      final waitFuture = testAdapter.sendBlobFrame('node-remote', validFrame);
      await Future<void>.delayed(Duration.zero);

      blobDc.close();
      await expectLater(waitFuture, throwsA(isA<StateError>()));

      await testAdapter.disconnect();
    });

    test('R7: prunePeer and disconnect close the blob channel, and openBlobPeers updates and emits', () async {
      final connectionFactory = FakeRtcPeerConnectionFactory();
      final fakePc = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc;

      final testAdapter = WebRtcMeshAdapter(
        signalingAdapter: signalingAdapter,
        connectionFactory: connectionFactory,
      );

      await testAdapter.initializeRoom('ROOM-R7', 'node-local');
      await testAdapter.connectToPeer('node-remote');

      final blobDc = fakePc.channelsByLabel['dn5e_blob']!;

      final emittedOpenPeers = <Set<String>>[];
      final peerSub = testAdapter.onBlobPeersChanged.listen(emittedOpenPeers.add);

      // Open blob channel
      blobDc.state = RTCDataChannelState.RTCDataChannelOpen;
      blobDc.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);

      expect(testAdapter.openBlobPeers, contains('node-remote'));
      expect(emittedOpenPeers.last, contains('node-remote'));

      // prunePeer closes blob channel and updates openBlobPeers
      testAdapter.prunePeer('node-remote');
      await Future<void>.delayed(Duration.zero);

      expect(blobDc.isClosed, isTrue);
      expect(testAdapter.openBlobPeers.contains('node-remote'), isFalse);
      expect(emittedOpenPeers.last.contains('node-remote'), isFalse);

      // Test disconnect on new peer
      final fakePc2 = FakeRTCPeerConnection();
      connectionFactory.nextConnection = fakePc2;
      await testAdapter.connectToPeer('node-remote-2');
      final blobDc2 = fakePc2.channelsByLabel['dn5e_blob']!;
      blobDc2.state = RTCDataChannelState.RTCDataChannelOpen;
      blobDc2.onDataChannelState?.call(RTCDataChannelState.RTCDataChannelOpen);
      await Future<void>.delayed(Duration.zero);
      expect(testAdapter.openBlobPeers, contains('node-remote-2'));

      await testAdapter.disconnect();
      expect(blobDc2.isClosed, isTrue);
      expect(testAdapter.openBlobPeers, isEmpty);

      await peerSub.cancel();
    });
  });
}

class _DynamicFactory implements IRtcPeerConnectionFactory {
  final RTCPeerConnection Function(Map<String, dynamic> config) _builder;
  _DynamicFactory(this._builder);

  @override
  Future<RTCPeerConnection> createConnection(
      Map<String, dynamic> configuration) async {
    return _builder(configuration);
  }
}
