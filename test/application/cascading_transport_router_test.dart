import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';

/// Mock transport adapter implementing [IP2pTransportPort] for deterministic testing.
class MockTransportAdapter implements IP2pTransportPort {
  bool initializeShouldThrow = false;
  bool broadcastShouldThrow = false;
  bool isInitialized = false;
  bool isDisconnected = false;
  String? currentRoomCode;
  String? currentLocalNodeId;

  final List<String> broadcastedPayloads = [];
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.connecting;

  @override
  Map<String, int> peerLastSeen = const {};

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    if (initializeShouldThrow) {
      throw StateError('Simulated network initialization failure');
    }
    isInitialized = true;
    currentRoomCode = roomCode;
    currentLocalNodeId = localNodeId;
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (broadcastShouldThrow) {
      throw StateError('Simulated transport broadcast failure');
    }
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _payloadController.stream;

  void emitPayload(String payload) {
    _payloadController.add(payload);
  }

  @override
  Future<void> disconnect() async {
    isDisconnected = true;
    await _payloadController.close();
  }
}

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
  group('CascadingTransportRouter 4-Tier Waterfall Verification', () {
    late MockTransportAdapter mockLocalWifi;
    late MockTransportAdapter mockWebRtc;
    late MockTransportAdapter mockFirebase;
    late CascadingTransportRouter router;

    setUp(() {
      mockLocalWifi = MockTransportAdapter();
      mockWebRtc = MockTransportAdapter();
      mockFirebase = MockTransportAdapter();

      router = CascadingTransportRouter(
        localWifiAdapter: mockLocalWifi,
        webRtcAdapter: mockWebRtc,
        firebaseFallbackAdapter: mockFirebase,
        heartbeatTtl: const Duration(seconds: 6),
        checkInterval: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      await router.disconnect();
    });

    test('Tier 1: Initializes Local Wi-Fi first and enters localWifi state (Zero Cost)', () async {
      expect(router.currentState, TransportState.connecting);

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(mockLocalWifi.isInitialized, isTrue);
      expect(mockWebRtc.isInitialized, isFalse);
      expect(mockFirebase.isInitialized, isFalse);
      expect(router.currentState, TransportState.localWifi);
    });

    test('Tier 2: Steps down to WebRTC mesh when Local Wi-Fi fails', () async {
      mockLocalWifi.initializeShouldThrow = true;

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(mockLocalWifi.isInitialized, isFalse);
      expect(mockWebRtc.isInitialized, isTrue);
      expect(mockFirebase.isInitialized, isFalse);
      expect(router.currentState, TransportState.webRtc);
      // Deprecated alias compatibility
      expect(router.currentState, TransportState.p2pEstablished);
    });

    test('Tier 3: Steps down to Firebase relay when both Local Wi-Fi and WebRTC fail', () async {
      mockLocalWifi.initializeShouldThrow = true;
      mockWebRtc.initializeShouldThrow = true;

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(mockLocalWifi.isInitialized, isFalse);
      expect(mockWebRtc.isInitialized, isFalse);
      expect(mockFirebase.isInitialized, isTrue);
      expect(router.currentState, TransportState.fallbackRelay);
    });

    test('Tier 4: Enters offline state when all 3 adapters fail initialization', () async {
      mockLocalWifi.initializeShouldThrow = true;
      mockWebRtc.initializeShouldThrow = true;
      mockFirebase.initializeShouldThrow = true;

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(router.currentState, TransportState.offline);
      expect(router.activeAdapter, isNull);
    });

    group('Signaling Lifecycle Verification', () {
      test('Wipes ephemeral signaling documents upon WebRTC connection established', () async {
        final deletedDocPaths = <String>[];
        final signalingAdapter = FirebaseSignalingAdapter(
          onDeleteDocument: (path) async {
            deletedDocPaths.add(path);
          },
        );

        await signalingAdapter.initialize(roomCode: 'ROOM-SIG', localNodeId: 'local-node');
        final offerId = await signalingAdapter.sendOffer(toNodeId: 'remote-node', sdp: 'fake-sdp');
        expect(signalingAdapter.trackedDocPaths, contains('rooms/ROOM-SIG/signaling/$offerId'));
        expect(deletedDocPaths, isEmpty);

        final realWebRtcAdapter = WebRtcMeshAdapter(signalingAdapter: signalingAdapter);
        mockLocalWifi.initializeShouldThrow = true; // Cascade to WebRTC

        final sigRouter = CascadingTransportRouter(
          localWifiAdapter: mockLocalWifi,
          webRtcAdapter: realWebRtcAdapter,
          firebaseFallbackAdapter: mockFirebase,
        );

        await sigRouter.initializeRoom('ROOM-SIG', 'local-node');
        expect(sigRouter.currentState, TransportState.webRtc);

        // Verify cleanUpSignalingSession() was triggered and wiped prior handshake docs
        expect(deletedDocPaths, contains('rooms/ROOM-SIG/signaling/$offerId'));
        expect(signalingAdapter.trackedDocPaths, isNot(contains('rooms/ROOM-SIG/signaling/$offerId')));
        expect(signalingAdapter.trackedDocPaths.isNotEmpty, isTrue);

        await sigRouter.disconnect();
      });
    });

    group('Failover Step-Down & Payload Routing Test', () {
      test('Relays incoming payloads from active adapter and filters protocol heartbeats', () async {
        mockLocalWifi.initializeShouldThrow = true; // WebRTC tier
        await router.initializeRoom('ROOM-1234', 'node-player-1');
        expect(router.currentState, TransportState.webRtc);

        final receivedPayloads = <String>[];
        final sub = router.watchIncomingPayloads().listen(receivedPayloads.add);

        // Protocol heartbeat message should be filtered out from application stream
        mockWebRtc.emitPayload('{"_protocol":"heartbeat_ping","from":"peer-2"}');
        await Future<void>.delayed(Duration.zero);
        expect(receivedPayloads, isEmpty);

        // Application payload should be passed through
        const appPayload = '{"type":"crdt_delta","field":"hp","value":35}';
        mockWebRtc.emitPayload(appPayload);
        await Future<void>.delayed(Duration.zero);
        expect(receivedPayloads, [appPayload]);

        await sub.cancel();
      });

      test('Broadcast failure on WebRTC steps down to Firebase Relay and routes payloads through it', () async {
        mockLocalWifi.initializeShouldThrow = true; // Start in WebRTC tier
        await router.initializeRoom('ROOM-1234', 'node-player-1');
        expect(router.currentState, TransportState.webRtc);
        expect(mockFirebase.isInitialized, isFalse);

        // Make WebRTC fail on sending
        mockWebRtc.broadcastShouldThrow = true;

        const payload = '{"type":"save_throw","stat":"DEX","val":15}';
        await router.broadcastPayload(payload);

        // Verify router stepped down to Firebase relay
        expect(router.currentState, TransportState.fallbackRelay);
        expect(mockFirebase.isInitialized, isTrue);
        expect(mockFirebase.broadcastedPayloads, [payload]);

        // Subsequent broadcasts route through Firebase relay without WebRTC
        mockFirebase.broadcastedPayloads.clear();
        mockWebRtc.broadcastedPayloads.clear();

        const followUpPayload = '{"type":"chat","text":"fallover succeeded"}';
        await router.broadcastPayload(followUpPayload);

        expect(mockFirebase.broadcastedPayloads, [followUpPayload]);
        expect(mockWebRtc.broadcastedPayloads, isEmpty);
      });

      test('Broadcast failure on Firebase relay steps down to total offline', () async {
        mockLocalWifi.initializeShouldThrow = true;
        mockWebRtc.initializeShouldThrow = true;
        await router.initializeRoom('ROOM-1234', 'node-player-1');
        expect(router.currentState, TransportState.fallbackRelay);

        // Firebase broadcast fails
        mockFirebase.broadcastShouldThrow = true;
        await router.broadcastPayload('{"type":"fail"}');

        expect(router.currentState, TransportState.offline);
      });
    });

    group('Zombie Node Pruning & Heartbeat Cascade Test', () {
      test('Prunes dead peer nodes exceeding TTL and cascades waterfall when all peers expire', () async {
        final prunedPeers = <String>[];
        mockLocalWifi.initializeShouldThrow = true; // Start in WebRTC

        final testRouter = CascadingTransportRouter(
          localWifiAdapter: mockLocalWifi,
          webRtcAdapter: mockWebRtc,
          firebaseFallbackAdapter: mockFirebase,
          heartbeatTtl: const Duration(seconds: 6),
          checkInterval: const Duration(milliseconds: 50),
          onPeerPruned: prunedPeers.add,
        );

        await testRouter.initializeRoom('ROOM-ZOMBIE', 'node-local');
        expect(testRouter.currentState, TransportState.webRtc);

        final initialTime = DateTime(2026, 9, 9, 12, 0, 0);

        // Record active peer heartbeats at t = 0s
        testRouter.recordPeerHeartbeat('peer-fighter', timestamp: initialTime.millisecondsSinceEpoch);
        testRouter.recordPeerHeartbeat('peer-wizard', timestamp: initialTime.millisecondsSinceEpoch);
        expect(testRouter.peerLastSeen.length, 2);

        // Simulate t = 5s (within TTL)
        final at5Seconds = initialTime.add(const Duration(seconds: 5));
        await testRouter.checkHeartbeats(at5Seconds);
        expect(testRouter.peerLastSeen.containsKey('peer-fighter'), isTrue);
        expect(testRouter.peerLastSeen.containsKey('peer-wizard'), isTrue);
        expect(prunedPeers, isEmpty);
        expect(testRouter.currentState, TransportState.webRtc);

        // Wizard sends a fresh heartbeat at 5s
        testRouter.recordPeerHeartbeat('peer-wizard', timestamp: at5Seconds.millisecondsSinceEpoch);

        // Advance to 6.0s: fighter pruned, wizard stays active
        final at6Seconds = initialTime.add(const Duration(seconds: 6));
        await testRouter.checkHeartbeats(at6Seconds);
        expect(prunedPeers, contains('peer-fighter'));
        expect(testRouter.peerLastSeen.containsKey('peer-fighter'), isFalse);
        expect(testRouter.peerLastSeen.containsKey('peer-wizard'), isTrue);
        expect(testRouter.currentState, TransportState.webRtc);

        // Advance to 11.0s: wizard pruned, all peers dead -> cascades to fallbackRelay
        final at11Seconds = initialTime.add(const Duration(seconds: 11));
        await testRouter.checkHeartbeats(at11Seconds);
        expect(prunedPeers, contains('peer-wizard'));
        expect(testRouter.peerLastSeen.isEmpty, isTrue);
        expect(testRouter.currentState, TransportState.fallbackRelay);

        await testRouter.disconnect();
      });

      test('Synchronizes peerLastSeen from active adapter preventing premature eviction during silent ping/pongs', () async {
        mockLocalWifi.initializeShouldThrow = true; // Cascade to WebRTC tier
        await router.initializeRoom('ROOM-SILENT', 'node-local');
        expect(router.currentState, TransportState.webRtc);

        final initialTime = DateTime(2026, 9, 9, 12, 0, 0);

        // Record peer heartbeat initially at t = 0s
        router.recordPeerHeartbeat('peer-silent', timestamp: initialTime.millisecondsSinceEpoch);
        expect(router.peerLastSeen['peer-silent'], initialTime.millisecondsSinceEpoch);

        // Simulate active WebRtcMeshAdapter updating its internal peerLastSeen at t = 5s via silent ping/pong
        final at5Seconds = initialTime.add(const Duration(seconds: 5));
        mockWebRtc.peerLastSeen = {
          'peer-silent': at5Seconds.millisecondsSinceEpoch,
        };

        // Advance to t = 7s (past initial 6s TTL from t = 0s)
        final at7Seconds = initialTime.add(const Duration(seconds: 7));
        await router.checkHeartbeats(at7Seconds);

        // Verify router synced the timestamp from active adapter and did NOT prune the peer
        expect(router.peerLastSeen.containsKey('peer-silent'), isTrue);
        expect(router.peerLastSeen['peer-silent'], at5Seconds.millisecondsSinceEpoch);
        expect(router.currentState, TransportState.webRtc);

        // Advance to t = 12s (> 6s after the 5s update): peer should now be pruned
        final at12Seconds = initialTime.add(const Duration(seconds: 12));
        await router.checkHeartbeats(at12Seconds);
        expect(router.peerLastSeen.containsKey('peer-silent'), isFalse);
      });

      test('Default heartbeat TTL is 15 seconds to prevent premature mobile fallback', () {
        final defaultRouter = CascadingTransportRouter(
          localWifiAdapter: mockLocalWifi,
          webRtcAdapter: mockWebRtc,
          firebaseFallbackAdapter: mockFirebase,
        );
        expect(defaultRouter.heartbeatTtl, const Duration(seconds: 15));
      });

      test('Architecture Test: UI state stays locked at 1 peer when left idle for 15 seconds with silent ping/pongs', () async {
        final archRouter = CascadingTransportRouter(
          localWifiAdapter: mockLocalWifi,
          webRtcAdapter: mockWebRtc,
          firebaseFallbackAdapter: mockFirebase,
          heartbeatTtl: const Duration(seconds: 15),
        );
        mockLocalWifi.initializeShouldThrow = true;
        await archRouter.initializeRoom('ROOM-ARCH-IDLE', 'node-local');

        final initialTime = DateTime(2026, 9, 9, 12, 0, 0);
        archRouter.recordPeerHeartbeat('peer-party-member', timestamp: initialTime.millisecondsSinceEpoch);
        expect(archRouter.peerLastSeen.length, 1);

        // Simulate 15 seconds passing with silent adapter heartbeats every 4 seconds
        for (int sec = 4; sec <= 15; sec += 4) {
          final checkpoint = initialTime.add(Duration(seconds: sec));
          mockWebRtc.peerLastSeen = {
            'peer-party-member': checkpoint.millisecondsSinceEpoch,
          };
          await archRouter.checkHeartbeats(checkpoint);
          // UI state stays locked at 1 peer
          expect(archRouter.peerLastSeen.length, 1);
          expect(archRouter.currentState, TransportState.webRtc);
        }

        // Final evaluation at 15.0 seconds
        final at15Seconds = initialTime.add(const Duration(seconds: 15));
        await archRouter.checkHeartbeats(at15Seconds);
        expect(archRouter.peerLastSeen.length, 1);
        expect(archRouter.currentState, TransportState.webRtc);

        await archRouter.disconnect();
      });
    });

    test('Clean disconnect tears down all adapters, subscriptions, and clears state', () async {
      await router.initializeRoom('ROOM-TEARDOWN', 'node-local');
      await router.disconnect();

      expect(mockLocalWifi.isDisconnected, isTrue);
      expect(mockWebRtc.isDisconnected, isTrue);
      expect(mockFirebase.isDisconnected, isTrue);
      expect(router.peerLastSeen, isEmpty);
      expect(router.currentState, TransportState.offline);
    });
  });
}
