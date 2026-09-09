import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';

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

void main() {
  group('CascadingTransportRouter Architectural Verification', () {
    late MockTransportAdapter mockWebRtc;
    late MockTransportAdapter mockFirebase;
    late CascadingTransportRouter router;

    setUp(() {
      mockWebRtc = MockTransportAdapter();
      mockFirebase = MockTransportAdapter();
      router = CascadingTransportRouter(
        webRtcAdapter: mockWebRtc,
        firebaseFallbackAdapter: mockFirebase,
        heartbeatTtl: const Duration(seconds: 6),
        checkInterval: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      await router.disconnect();
    });

    test('Initializes WebRTC first and enters p2pEstablished state', () async {
      expect(router.currentState, TransportState.connecting);

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(mockWebRtc.isInitialized, isTrue);
      expect(mockFirebase.isInitialized, isFalse);
      expect(router.currentState, TransportState.p2pEstablished);
    });

    test('Falls back immediately to Firebase if WebRTC initialization fails', () async {
      mockWebRtc.initializeShouldThrow = true;

      await router.initializeRoom('ROOM-1234', 'node-player-1');

      expect(router.currentState, TransportState.fallbackRelay);
      expect(mockFirebase.isInitialized, isTrue);
    });

    group('Transport Abstraction Test', () {
      test('Relays incoming payloads from WebRTC when p2pEstablished is active', () async {
        await router.initializeRoom('ROOM-1234', 'node-player-1');

        final receivedPayloads = <String>[];
        final sub = router.watchIncomingPayloads().listen(receivedPayloads.add);

        const dummyJson = '{"type":"crdt_delta","field":"hp","value":35}';
        mockWebRtc.emitPayload(dummyJson);
        await Future<void>.delayed(Duration.zero);

        expect(receivedPayloads, [dummyJson]);

        // Broadcasting also uses WebRTC
        await router.broadcastPayload('{"type":"attack_roll","d20":18}');
        expect(mockWebRtc.broadcastedPayloads, ['{"type":"attack_roll","d20":18}']);
        expect(mockFirebase.broadcastedPayloads, isEmpty);

        await sub.cancel();
      });

      test('Relays incoming payloads from Firebase when fallbackRelay is active', () async {
        mockWebRtc.initializeShouldThrow = true;
        await router.initializeRoom('ROOM-1234', 'node-player-1');

        expect(router.currentState, TransportState.fallbackRelay);

        final receivedPayloads = <String>[];
        final sub = router.watchIncomingPayloads().listen(receivedPayloads.add);

        const dummyFallbackJson = '{"type":"relay_event","details":"dm_update"}';
        mockFirebase.emitPayload(dummyFallbackJson);
        await Future<void>.delayed(Duration.zero);

        expect(receivedPayloads, [dummyFallbackJson]);

        // Broadcasting uses Firebase fallback relay
        await router.broadcastPayload('{"type":"chat","msg":"hello"}');
        expect(mockFirebase.broadcastedPayloads, ['{"type":"chat","msg":"hello"}']);
        expect(mockWebRtc.broadcastedPayloads, isEmpty);

        await sub.cancel();
      });

      test('Broadcast failure on WebRTC automatically triggers fallback to Firebase', () async {
        await router.initializeRoom('ROOM-1234', 'node-player-1');
        expect(router.currentState, TransportState.p2pEstablished);

        // Make WebRTC fail on sending
        mockWebRtc.broadcastShouldThrow = true;

        const payload = '{"type":"save_throw","stat":"DEX","val":15}';
        await router.broadcastPayload(payload);

        // State transitioned to fallbackRelay and broadcasted via Firebase
        expect(router.currentState, TransportState.fallbackRelay);
        expect(mockFirebase.broadcastedPayloads, [payload]);
      });
    });

    group('Zombie Node Pruning & Heartbeat Test', () {
      test('Prunes peer nodes exceeding 6-second TTL and transitions to fallbackRelay', () async {
        final prunedPeers = <String>[];

        final testRouter = CascadingTransportRouter(
          webRtcAdapter: mockWebRtc,
          firebaseFallbackAdapter: mockFirebase,
          heartbeatTtl: const Duration(seconds: 6),
          checkInterval: const Duration(milliseconds: 50),
          onPeerPruned: prunedPeers.add,
        );

        await testRouter.initializeRoom('ROOM-ZOMBIE', 'node-local');
        expect(testRouter.currentState, TransportState.p2pEstablished);

        final initialTime = DateTime(2026, 9, 9, 12, 0, 0);

        // Record active peer heartbeats at t = 0s
        testRouter.recordPeerHeartbeat('peer-fighter', timestamp: initialTime.millisecondsSinceEpoch);
        testRouter.recordPeerHeartbeat('peer-wizard', timestamp: initialTime.millisecondsSinceEpoch);

        expect(testRouter.peerLastSeen.length, 2);

        // Simulate time advancing by 5 seconds (within 6-second TTL)
        final at5Seconds = initialTime.add(const Duration(seconds: 5));
        testRouter.checkHeartbeats(at5Seconds);

        // Peers should NOT be pruned yet; state remains p2pEstablished
        expect(testRouter.peerLastSeen.containsKey('peer-fighter'), isTrue);
        expect(testRouter.peerLastSeen.containsKey('peer-wizard'), isTrue);
        expect(prunedPeers, isEmpty);
        expect(testRouter.currentState, TransportState.p2pEstablished);

        // Wizard sends a fresh heartbeat at 5 seconds
        testRouter.recordPeerHeartbeat('peer-wizard', timestamp: at5Seconds.millisecondsSinceEpoch);

        // Simulate time advancing to exactly 6.0 seconds from initial time
        final at6Seconds = initialTime.add(const Duration(seconds: 6));
        testRouter.checkHeartbeats(at6Seconds);

        // Fighter exceeded 6s TTL and is pruned! Wizard remains active
        expect(prunedPeers, contains('peer-fighter'));
        expect(testRouter.peerLastSeen.containsKey('peer-fighter'), isFalse);
        expect(testRouter.peerLastSeen.containsKey('peer-wizard'), isTrue);
        expect(testRouter.currentState, TransportState.p2pEstablished);

        // Simulate time advancing to 11.0 seconds (Wizard has now been silent for 6s since t=5s)
        final at11Seconds = initialTime.add(const Duration(seconds: 11));
        testRouter.checkHeartbeats(at11Seconds);

        // Wizard also pruned! All peers are now zombies. Router transitions to fallbackRelay
        expect(prunedPeers, contains('peer-wizard'));
        expect(testRouter.peerLastSeen.isEmpty, isTrue);
        expect(testRouter.currentState, TransportState.fallbackRelay);

        await testRouter.disconnect();
      });

      test('Timer-driven periodic heartbeat monitor prunes dead peers after 6s of inactivity', () async {
        final prunedPeers = <String>[];

        final testRouter = CascadingTransportRouter(
          webRtcAdapter: mockWebRtc,
          firebaseFallbackAdapter: mockFirebase,
          heartbeatTtl: const Duration(milliseconds: 100), // scaled down for fast test
          checkInterval: const Duration(milliseconds: 20),
          onPeerPruned: prunedPeers.add,
        );

        await testRouter.initializeRoom('ROOM-FAST-TTL', 'node-local');
        testRouter.recordPeerHeartbeat('peer-silence');

        expect(testRouter.currentState, TransportState.p2pEstablished);

        // Wait for TTL to expire via active timer
        await Future<void>.delayed(const Duration(milliseconds: 160));

        expect(prunedPeers, contains('peer-silence'));
        expect(testRouter.currentState, TransportState.fallbackRelay);

        await testRouter.disconnect();
      });
    });

    test('Clean disconnect tears down all adapters and controllers', () async {
      await router.initializeRoom('ROOM-TEARDOWN', 'node-local');
      await router.disconnect();

      expect(mockWebRtc.isDisconnected, isTrue);
      expect(mockFirebase.isDisconnected, isTrue);
      expect(router.peerLastSeen, isEmpty);
    });
  });
}
