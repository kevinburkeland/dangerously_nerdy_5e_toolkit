import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'signaling_message.dart';

/// Adapter managing ephemeral WebRTC signaling (SDP offers, answers, ICE candidates)
/// via Cloud Firestore with strict zero-persistence lifecycle guarantees.
class FirebaseSignalingAdapter {
  final FirebaseFirestore? _firestore;
  final Future<void> Function(String path)? _onDeleteDocument;

  String? _roomCode;
  String? _localNodeId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;
  final StreamController<SignalingMessage> _incomingSignalsController =
      StreamController<SignalingMessage>.broadcast();

  /// Tracks all document paths created or received during signaling,
  /// partitioned by peer ID (or '*' for broadcasts) to isolate cleanup.
  final Map<String, Set<String>> _peerTrackedDocPaths = {};
  final int slidingTtlMs;
  int? _lastPruningThreshold;

  FirebaseSignalingAdapter({
    FirebaseFirestore? firestore,
    Future<void> Function(String path)? onDeleteDocument,
    this.slidingTtlMs = 60000,
  })  : _firestore = firestore,
        _onDeleteDocument = onDeleteDocument;

  bool get isFirebaseAvailable =>
      _firestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  String? get currentRoomCode => _roomCode;
  String? get localNodeId => _localNodeId;
  Set<String> get trackedDocPaths =>
      Set.unmodifiable(_peerTrackedDocPaths.values.expand((s) => s).toSet());
  Map<String, Set<String>> get peerTrackedDocPaths =>
      Map.unmodifiable(_peerTrackedDocPaths.map((k, v) => MapEntry(k, Set.unmodifiable(v))));
  int? get lastPruningThreshold => _lastPruningThreshold;

  /// Initializes signaling for the given room and node ID.
  Future<void> initialize({
    required String roomCode,
    required String localNodeId,
  }) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    // Strict 60-second sliding TTL window to prune historical signaling residue
    final pruningThreshold = DateTime.now().millisecondsSinceEpoch - slidingTtlMs;
    _lastPruningThreshold = pruningThreshold;

    if (isFirebaseAvailable) {
      final collection = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('signaling');

      // Listen for signals targeted at this node or broadcast wildcard.
      // Filter sliding TTL in memory to eliminate composite index requirement in Firestore.
      _firestoreSubscription = collection
          .where('toNodeId', whereIn: [_localNodeId, '*'])
          .snapshots()
          .listen(
            (snapshot) {
              final now = DateTime.now().millisecondsSinceEpoch;
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final data = change.doc.data();
                  if (data != null) {
                    final message = SignalingMessage.fromMap(data, docId: change.doc.id);
                    if (message.fromNodeId != _localNodeId) {
                      if (now - message.timestamp > slidingTtlMs) {
                        continue;
                      }
                      _peerTrackedDocPaths
                          .putIfAbsent(message.fromNodeId, () => <String>{})
                          .add(change.doc.reference.path);
                      _incomingSignalsController.add(message);
                    }
                  }
                }
              }
            },
            onError: (error) {
              // Silently handle stream error
            },
          );

      // Broadcast join presence for late-joiner detection
      try {
        await broadcastJoin();
      } catch (_) {}
    }
  }

  /// Sends an SDP offer to a target node.
  Future<String> sendOffer({
    required String toNodeId,
    required String sdp,
  }) async {
    return _sendSignal(
      toNodeId: toNodeId,
      type: SignalingType.offer,
      sdp: sdp,
    );
  }

  /// Sends an SDP answer to a target node.
  Future<String> sendAnswer({
    required String toNodeId,
    required String sdp,
  }) async {
    return _sendSignal(
      toNodeId: toNodeId,
      type: SignalingType.answer,
      sdp: sdp,
    );
  }

  /// Sends an ICE candidate to a target node.
  Future<String> sendIceCandidate({
    required String toNodeId,
    required Map<String, dynamic> candidate,
  }) async {
    return _sendSignal(
      toNodeId: toNodeId,
      type: SignalingType.candidate,
      candidate: candidate,
    );
  }

  /// Broadcasts a peerJoin signal to all peers in the room (`toNodeId: '*'`).
  Future<String> broadcastJoin() async {
    return _sendSignal(
      toNodeId: '*',
      type: SignalingType.peerJoin,
    );
  }

  /// Sends a targeted peerJoin response signal to a specific peer.
  Future<String> sendTargetedJoin({required String toNodeId}) async {
    return _sendSignal(
      toNodeId: toNodeId,
      type: SignalingType.peerJoin,
    );
  }

  Future<String> _sendSignal({
    required String toNodeId,
    required SignalingType type,
    String? sdp,
    Map<String, dynamic>? candidate,
  }) async {
    if (_roomCode == null || _localNodeId == null) {
      throw StateError('FirebaseSignalingAdapter must be initialized before sending signals.');
    }

    final signalId = const Uuid().v4();
    final message = SignalingMessage(
      id: signalId,
      roomCode: _roomCode!,
      fromNodeId: _localNodeId!,
      toNodeId: toNodeId,
      type: type,
      sdp: sdp,
      candidate: candidate,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final path = 'rooms/$_roomCode/signaling/$signalId';
    _peerTrackedDocPaths.putIfAbsent(toNodeId, () => <String>{}).add(path);

    if (isFirebaseAvailable) {
      await _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('signaling')
          .doc(signalId)
          .set(message.toMap());
    }

    return signalId;
  }

  /// Stream of incoming signaling messages intended for this node.
  Stream<SignalingMessage> watchIncomingSignals() =>
      _incomingSignalsController.stream;

  /// Injects an incoming signal (used for testing or non-cloud signaling).
  /// Enforces sliding TTL to discard expired signaling residue.
  void emitIncomingSignal(SignalingMessage message) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - message.timestamp > slidingTtlMs) {
      // Discard stale signaling residue beyond sliding TTL
      return;
    }
    final path = 'rooms/${message.roomCode}/signaling/${message.id}';
    _peerTrackedDocPaths.putIfAbsent(message.fromNodeId, () => <String>{}).add(path);
    _incomingSignalsController.add(message);
  }

  /// Deletes a specific signaling document from Firestore.
  Future<void> deleteSignal(String docId) async {
    if (_roomCode == null) return;
    final path = 'rooms/$_roomCode/signaling/$docId';
    await _deletePath(path, docId);
  }

  /// Cleans up and deletes all ephemeral signaling documents associated
  /// with a specific peer once that peer's P2P handshake completes,
  /// preserving in-flight signaling documents for other peers.
  Future<void> cleanUpPeerSignaling(String peerId) async {
    final pathsToDelete = _peerTrackedDocPaths.remove(peerId);
    if (pathsToDelete == null || pathsToDelete.isEmpty) return;
    for (final path in List<String>.from(pathsToDelete)) {
      final docId = path.split('/').last;
      await _deletePath(path, docId);
    }
  }

  /// Explicitly cleans up and deletes all ephemeral signaling documents
  /// across all peers and wildcard channels, leaving ZERO persistent
  /// signaling residue in Firestore.
  Future<void> cleanUpSignalingSession() async {
    final pathsToDelete = _peerTrackedDocPaths.values.expand((s) => s).toList();
    for (final path in pathsToDelete) {
      final docId = path.split('/').last;
      await _deletePath(path, docId);
    }
    _peerTrackedDocPaths.clear();
  }

  Future<void> _deletePath(String path, String docId) async {
    for (final entry in _peerTrackedDocPaths.entries) {
      entry.value.remove(path);
    }
    _peerTrackedDocPaths.removeWhere((_, set) => set.isEmpty);

    if (_onDeleteDocument != null) {
      await _onDeleteDocument!(path);
    }

    if (isFirebaseAvailable && _roomCode != null) {
      try {
        await _effectiveFirestore
            .collection('rooms')
            .doc(_roomCode)
            .collection('signaling')
            .doc(docId)
            .delete();
      } catch (_) {
        // Silently ignore if already deleted by peer
      }
    }
  }

  /// Cleans up subscriptions and deletes all remaining tracked signaling documents.
  Future<void> dispose() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    await cleanUpSignalingSession();
    await _incomingSignalsController.close();
  }
}
