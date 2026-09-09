import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/signaling_message.dart';

void main() {
  group('FirebaseSignalingAdapter Ephemeral Lifecycle Tests', () {
    late List<String> deletedPaths;
    late FirebaseSignalingAdapter adapter;

    setUp(() {
      deletedPaths = [];
      adapter = FirebaseSignalingAdapter(
        onDeleteDocument: (path) async {
          deletedPaths.add(path);
        },
      );
    });

    tearDown(() async {
      await adapter.dispose();
    });

    test('Initializes correctly with roomCode and localNodeId', () async {
      await adapter.initialize(roomCode: 'TEST-1234', localNodeId: 'node-alpha');
      expect(adapter.currentRoomCode, 'TEST-1234');
      expect(adapter.localNodeId, 'node-alpha');
    });

    test('Creates offer, answer, and ICE candidate signals with tracked paths', () async {
      await adapter.initialize(roomCode: 'TEST-1234', localNodeId: 'node-alpha');

      final offerId = await adapter.sendOffer(toNodeId: 'node-beta', sdp: 'v=0\r\no=...');
      expect(offerId.isNotEmpty, isTrue);
      expect(adapter.trackedDocPaths, contains('rooms/TEST-1234/signaling/$offerId'));

      final answerId = await adapter.sendAnswer(toNodeId: 'node-beta', sdp: 'v=0\r\no=answer...');
      expect(adapter.trackedDocPaths, contains('rooms/TEST-1234/signaling/$answerId'));

      final candidateId = await adapter.sendIceCandidate(
        toNodeId: 'node-beta',
        candidate: {'candidate': 'candidate:1 1 UDP ...', 'sdpMid': '0', 'sdpMLineIndex': 0},
      );
      expect(adapter.trackedDocPaths, contains('rooms/TEST-1234/signaling/$candidateId'));
      expect(adapter.trackedDocPaths.length, 3);
    });

    test('Ephemeral Signaling Verification: explicitly calls delete on all documents post-handshake', () async {
      await adapter.initialize(roomCode: 'ROOM-ALPHA', localNodeId: 'node-alpha');

      final offerId = await adapter.sendOffer(toNodeId: 'node-beta', sdp: 'sdp-offer-data');
      final answerId = await adapter.sendAnswer(toNodeId: 'node-beta', sdp: 'sdp-answer-data');
      final candId = await adapter.sendIceCandidate(
        toNodeId: 'node-beta',
        candidate: {'candidate': 'ice-1'},
      );

      expect(adapter.trackedDocPaths.length, 3);
      expect(deletedPaths, isEmpty);

      // Simulate handshake completion (p2pEstablished) -> cleanUpSignalingSession()
      await adapter.cleanUpSignalingSession();

      // All documents MUST be deleted, leaving zero persistent signaling data in the cloud
      expect(deletedPaths, contains('rooms/ROOM-ALPHA/signaling/$offerId'));
      expect(deletedPaths, contains('rooms/ROOM-ALPHA/signaling/$answerId'));
      expect(deletedPaths, contains('rooms/ROOM-ALPHA/signaling/$candId'));
      expect(deletedPaths.length, 3);
      expect(adapter.trackedDocPaths, isEmpty);
    });

    test('deleteSignal deletes individual signal documents immediately upon consumption', () async {
      await adapter.initialize(roomCode: 'ROOM-BETA', localNodeId: 'node-alpha');

      final signalId = await adapter.sendOffer(toNodeId: 'node-beta', sdp: 'sdp-offer');
      expect(adapter.trackedDocPaths, contains('rooms/ROOM-BETA/signaling/$signalId'));

      await adapter.deleteSignal(signalId);
      expect(deletedPaths, contains('rooms/ROOM-BETA/signaling/$signalId'));
      expect(adapter.trackedDocPaths.contains('rooms/ROOM-BETA/signaling/$signalId'), isFalse);
    });

    test('watchIncomingSignals receives emitted signals and tracks them for cleanup', () async {
      await adapter.initialize(roomCode: 'ROOM-BETA', localNodeId: 'node-alpha');

      final receivedSignals = <SignalingMessage>[];
      final sub = adapter.watchIncomingSignals().listen(receivedSignals.add);

      const incoming = SignalingMessage(
        id: 'incoming-signal-1',
        roomCode: 'ROOM-BETA',
        fromNodeId: 'node-beta',
        toNodeId: 'node-alpha',
        type: SignalingType.offer,
        sdp: 'remote-sdp-offer',
        timestamp: 1000,
      );

      adapter.emitIncomingSignal(incoming);
      await Future<void>.delayed(Duration.zero);

      expect(receivedSignals.length, 1);
      expect(receivedSignals.first.sdp, 'remote-sdp-offer');
      expect(adapter.trackedDocPaths, contains('rooms/ROOM-BETA/signaling/incoming-signal-1'));

      await adapter.cleanUpSignalingSession();
      expect(deletedPaths, contains('rooms/ROOM-BETA/signaling/incoming-signal-1'));

      await sub.cancel();
    });
  });
}
