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
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subscriptions = [];
  final StreamController<SignalingMessage> _incomingSignalsController =
      StreamController<SignalingMessage>.broadcast();

  /// Maps docId -> full document path for rapid lookup on delete.
  final Map<String, String> _docIdToPath = {};

  /// Tracks all document paths created or received during signaling,
  /// partitioned by peer ID (or '*' for broadcasts) to isolate cleanup.
  final Map<String, Set<String>> _peerTrackedDocPaths = {};

  /// Tracks documents authored and sent by this node, partitioned by target peer ID.
  final Map<String, Set<String>> _peerAuthoredDocPaths = {};

  /// Tracks active in-flight deletions to prevent simultaneous double-deletion races.
  final Set<String> _deletingDocPaths = {};

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
  Set<String> get trackedDocPaths => Set.unmodifiable({
        ..._peerTrackedDocPaths.values.expand((s) => s),
        ..._peerAuthoredDocPaths.values.expand((s) => s),
      });
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
    _peerTrackedDocPaths.clear();
    _peerAuthoredDocPaths.clear();
    _deletingDocPaths.clear();
    _docIdToPath.clear();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Strict 60-second sliding TTL window to prune historical signaling residue
    final pruningThreshold = DateTime.now().millisecondsSinceEpoch - slidingTtlMs;
    _lastPruningThreshold = pruningThreshold;

    if (isFirebaseAvailable) {
      final localMailbox = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('nodes')
          .doc(_localNodeId)
          .collection('signals');

      final broadcastMailbox = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('nodes')
          .doc('*')
          .collection('signals');

      void handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
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
                final path = change.doc.reference.path;
                _docIdToPath[change.doc.id] = path;
                _peerTrackedDocPaths
                    .putIfAbsent(message.fromNodeId, () => <String>{})
                    .add(path);
                _incomingSignalsController.add(message);
              }
            }
          }
        }
      }

      _subscriptions.add(localMailbox.snapshots().listen(handleSnapshot, onError: (_) {}));
      _subscriptions.add(broadcastMailbox.snapshots().listen(handleSnapshot, onError: (_) {}));

      // Rehydrate room stub and reset the 30-day lease on Firestore
      try {
        final now = DateTime.now();
        final expiresAt = now.add(const Duration(days: 30));
        await _effectiveFirestore.collection('rooms').doc(_roomCode).set({
          'roomCode': _roomCode,
          'code': _roomCode,
          'campaignName': 'Campaign $_roomCode',
          'isStateless': true,
          'partyPurse': const {'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0},
          'lastUpdated': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}

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

  /// Broadcasts a join signal to all peers in the room.
  Future<String> broadcastJoin() async {
    return _sendSignal(
      toNodeId: '*',
      type: SignalingType.peerJoin,
    );
  }

  /// Broadcasts a peerJoin signal to all peers in the room (`toNodeId: '*'`).
  Future<String> sendPeerJoin() async {
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

  /// Internal helper to send a signal to Firestore and track authored paths.
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

    final path = 'rooms/$_roomCode/nodes/$toNodeId/signals/$signalId';

    if (isFirebaseAvailable) {
      await _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('nodes')
          .doc(toNodeId)
          .collection('signals')
          .doc(signalId)
          .set(message.toMap());
    }

    _docIdToPath[signalId] = path;
    _peerTrackedDocPaths.putIfAbsent(toNodeId, () => <String>{}).add(path);
    _peerAuthoredDocPaths.putIfAbsent(toNodeId, () => <String>{}).add(path);

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
    final path = 'rooms/${message.roomCode}/nodes/${message.toNodeId}/signals/${message.id}';
    _docIdToPath[message.id] = path;
    _peerTrackedDocPaths.putIfAbsent(message.fromNodeId, () => <String>{}).add(path);
    _incomingSignalsController.add(message);
  }

  /// Deletes a specific signaling document from Firestore.
  Future<void> deleteSignal(String docId) async {
    if (_roomCode == null) return;
    final path = _docIdToPath[docId] ??
        'rooms/$_roomCode/nodes/$_localNodeId/signals/$docId';
    await _deletePath(path, docId);
  }

  /// Cleans up and deletes all ephemeral signaling documents associated
  /// with a specific peer once that peer's P2P handshake completes,
  /// preserving in-flight signaling documents for other peers.
  ///
  /// Prevents cross-deletion race conditions: each peer deletes the documents that
  /// it authored and sent for [peerId]. If this node did not author documents for [peerId]
  /// (such as in receiver-only test fixtures), it falls back to deleting the tracked documents.
  Future<void> cleanUpPeerSignaling(String peerId) async {
    final authored = _peerAuthoredDocPaths.remove(peerId);
    final allForPeer = _peerTrackedDocPaths.remove(peerId);

    final pathsToDelete = (authored != null && authored.isNotEmpty)
        ? authored
        : (allForPeer ?? <String>{});
    if (pathsToDelete.isEmpty) return;

    for (final path in List<String>.from(pathsToDelete)) {
      final docId = path.split('/').last;
      await _deletePath(path, docId);
    }
  }

  /// Explicitly cleans up and deletes all ephemeral signaling documents
  /// across all peers and wildcard channels, leaving ZERO persistent
  /// signaling residue in Firestore.
  Future<void> cleanUpSignalingSession() async {
    final allPaths = <String>{
      ..._peerTrackedDocPaths.values.expand((s) => s),
      ..._peerAuthoredDocPaths.values.expand((s) => s),
    };
    final pathsToDelete = allPaths.toList();
    for (final path in pathsToDelete) {
      final docId = path.split('/').last;
      await _deletePath(path, docId);
    }
    _peerTrackedDocPaths.clear();
    _peerAuthoredDocPaths.clear();
  }

  Future<void> _deletePath(String path, String docId) async {
    if (_deletingDocPaths.contains(path)) return;
    _deletingDocPaths.add(path);
    try {
      _docIdToPath.remove(docId);
      final trackedEntries =
          List<MapEntry<String, Set<String>>>.from(_peerTrackedDocPaths.entries);
      for (final entry in trackedEntries) {
        entry.value.remove(path);
      }
      _peerTrackedDocPaths.removeWhere((_, set) => set.isEmpty);

      final authoredEntries =
          List<MapEntry<String, Set<String>>>.from(_peerAuthoredDocPaths.entries);
      for (final entry in authoredEntries) {
        entry.value.remove(path);
      }
      _peerAuthoredDocPaths.removeWhere((_, set) => set.isEmpty);

      if (_onDeleteDocument != null) {
        try {
          await _onDeleteDocument!(path);
        } catch (_) {}
      }

      if (isFirebaseAvailable && _roomCode != null) {
        try {
          await _effectiveFirestore.doc(path).delete();
        } catch (_) {
          // Silently ignore if already deleted by peer or Firestore not-found
        }
      }
    } finally {
      _deletingDocPaths.remove(path);
    }
  }

  /// Cleans up subscriptions and deletes all remaining tracked signaling documents.
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await cleanUpSignalingSession();
    await _incomingSignalsController.close();
  }
}
