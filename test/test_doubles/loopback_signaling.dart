import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_signaling_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/signaling_message.dart';

class LoopbackSignalingHub {
  final Map<String, List<LoopbackSignaling>> _rooms = {};

  void register(LoopbackSignaling signaling) {
    final room = signaling.currentRoomCode;
    if (room != null) {
      _rooms.putIfAbsent(room, () => []).add(signaling);
    }
  }

  void unregister(LoopbackSignaling signaling) {
    final room = signaling.currentRoomCode;
    if (room != null) {
      _rooms[room]?.remove(signaling);
    }
  }

  void deliver({
    required String roomCode,
    required String fromNodeId,
    required String toNodeId,
    required SignalingType type,
    String? sdp,
    Map<String, dynamic>? candidate,
  }) {
    final peers = _rooms[roomCode] ?? [];
    for (final peer in List<LoopbackSignaling>.from(peers)) {
      if (peer.localNodeId == fromNodeId) continue;
      if (toNodeId == '*' || peer.localNodeId == toNodeId) {
        final signalId = const Uuid().v4();
        final message = SignalingMessage(
          id: signalId,
          roomCode: roomCode,
          fromNodeId: fromNodeId,
          toNodeId: peer.localNodeId!,
          type: type,
          sdp: sdp,
          candidate: candidate,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        Timer.run(() {
          peer.emitIncomingSignal(message);
        });
      }
    }
  }
}

class LoopbackSignaling extends FirebaseSignalingAdapter {
  final LoopbackSignalingHub hub;
  String? _loopbackRoomCode;
  String? _loopbackLocalNodeId;

  LoopbackSignaling(this.hub);

  @override
  bool get isFirebaseAvailable => false;

  @override
  String? get currentRoomCode => _loopbackRoomCode;

  @override
  String? get localNodeId => _loopbackLocalNodeId;

  @override
  Future<void> initialize({
    required String roomCode,
    required String localNodeId,
  }) async {
    _loopbackRoomCode = roomCode.trim().toUpperCase();
    _loopbackLocalNodeId = localNodeId;
    hub.register(this);
    await broadcastJoin();
  }

  @override
  Future<String> sendOffer({
    required String toNodeId,
    required String sdp,
  }) async {
    final id = const Uuid().v4();
    hub.deliver(
      roomCode: _loopbackRoomCode!,
      fromNodeId: _loopbackLocalNodeId!,
      toNodeId: toNodeId,
      type: SignalingType.offer,
      sdp: sdp,
    );
    return id;
  }

  @override
  Future<String> sendAnswer({
    required String toNodeId,
    required String sdp,
  }) async {
    final id = const Uuid().v4();
    hub.deliver(
      roomCode: _loopbackRoomCode!,
      fromNodeId: _loopbackLocalNodeId!,
      toNodeId: toNodeId,
      type: SignalingType.answer,
      sdp: sdp,
    );
    return id;
  }

  @override
  Future<String> sendIceCandidate({
    required String toNodeId,
    required Map<String, dynamic> candidate,
  }) async {
    final id = const Uuid().v4();
    hub.deliver(
      roomCode: _loopbackRoomCode!,
      fromNodeId: _loopbackLocalNodeId!,
      toNodeId: toNodeId,
      type: SignalingType.candidate,
      candidate: candidate,
    );
    return id;
  }

  @override
  Future<String> broadcastJoin() async {
    final id = const Uuid().v4();
    hub.deliver(
      roomCode: _loopbackRoomCode!,
      fromNodeId: _loopbackLocalNodeId!,
      toNodeId: '*',
      type: SignalingType.peerJoin,
    );
    return id;
  }

  @override
  Future<String> sendPeerJoin() async {
    return broadcastJoin();
  }

  @override
  Future<String> sendTargetedJoin({required String toNodeId}) async {
    final id = const Uuid().v4();
    hub.deliver(
      roomCode: _loopbackRoomCode!,
      fromNodeId: _loopbackLocalNodeId!,
      toNodeId: toNodeId,
      type: SignalingType.peerJoin,
    );
    return id;
  }

  @override
  Future<void> deleteSignal(String docId) async {}

  @override
  Future<void> cleanUpPeerSignaling(String peerId) async {}

  @override
  Future<void> cleanUpSignalingSession() async {}

  @override
  Future<void> dispose() async {
    hub.unregister(this);
  }
}
