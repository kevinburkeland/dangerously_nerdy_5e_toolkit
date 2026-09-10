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

  /// Tracks all document paths created or received during signaling
  /// to ensure total cleanup after P2P handshake completion.
  final Set<String> _trackedDocPaths = {};

  FirebaseSignalingAdapter({
    FirebaseFirestore? firestore,
    Future<void> Function(String path)? onDeleteDocument,
  })  : _firestore = firestore,
        _onDeleteDocument = onDeleteDocument;

  bool get isFirebaseAvailable =>
      _firestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  String? get currentRoomCode => _roomCode;
  String? get localNodeId => _localNodeId;
  Set<String> get trackedDocPaths => Set.unmodifiable(_trackedDocPaths);

  /// Initializes signaling for the given room and node ID.
  Future<void> initialize({
    required String roomCode,
    required String localNodeId,
  }) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    if (isFirebaseAvailable) {
      final collection = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('signaling');

      // Listen for signals targeted at this node or broadcast
      _firestoreSubscription = collection
          .where('toNodeId', whereIn: [_localNodeId, '*'])
          .snapshots()
          .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  final message = SignalingMessage.fromMap(data, docId: change.doc.id);
                  if (message.fromNodeId != _localNodeId) {
                    _trackedDocPaths.add(change.doc.reference.path);
                    _incomingSignalsController.add(message);
                  }
                }
              }
            }
          });
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
    _trackedDocPaths.add(path);

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
  void emitIncomingSignal(SignalingMessage message) {
    final path = 'rooms/${message.roomCode}/signaling/${message.id}';
    _trackedDocPaths.add(path);
    _incomingSignalsController.add(message);
  }

  /// Deletes a specific signaling document from Firestore.
  Future<void> deleteSignal(String docId) async {
    if (_roomCode == null) return;
    final path = 'rooms/$_roomCode/signaling/$docId';
    await _deletePath(path, docId);
  }

  /// Explicitly cleans up and deletes all ephemeral signaling documents
  /// once P2P connection is established (`p2pEstablished`), leaving ZERO
  /// persistent signaling residue in Firestore.
  Future<void> cleanUpSignalingSession() async {
    final pathsToDelete = Set<String>.from(_trackedDocPaths);
    for (final path in pathsToDelete) {
      final docId = path.split('/').last;
      await _deletePath(path, docId);
    }
  }

  Future<void> _deletePath(String path, String docId) async {
    _trackedDocPaths.remove(path);

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
