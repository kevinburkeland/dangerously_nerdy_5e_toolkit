import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../../../application/services/cascading_transport_router.dart' show TransportState;
import '../../../domain/ports/i_p2p_transport_port.dart';

/// Firebase Firestore-backed relay transport adapter implementing [IP2pTransportPort].
/// Serves as the robust, reliable 3rd-tier fallback when P2P WebRTC mesh traversal
/// (STUN/TURN) fails or peers are partitioned.
class FirebaseFallbackAdapter implements IP2pTransportPort {
  final FirebaseFirestore? _firestore;
  final Future<void> Function(String path, Map<String, dynamic> data)? _onWriteMessage;

  String? _roomCode;
  String? _localNodeId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamController<String> _incomingPayloadsController =
      StreamController<String>.broadcast();

  FirebaseFallbackAdapter({
    FirebaseFirestore? firestore,
    Future<void> Function(String path, Map<String, dynamic> data)? onWriteMessage,
  })  : _firestore = firestore,
        _onWriteMessage = onWriteMessage;

  bool get isFirebaseAvailable =>
      _firestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  TransportState get currentState =>
      _subscription != null ? TransportState.fallbackRelay : TransportState.offline;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    if (_incomingPayloadsController.isClosed) {
      _incomingPayloadsController = StreamController<String>.broadcast();
    }

    if (isFirebaseAvailable) {
      final collection = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('relay_messages');

      final now = DateTime.now().millisecondsSinceEpoch;

      _subscription = collection
          .where('timestamp', isGreaterThanOrEqualTo: now)
          .snapshots()
          .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null && data['senderId'] != _localNodeId) {
                  final payload = data['payload'] as String?;
                  if (payload != null && payload.isNotEmpty) {
                    _incomingPayloadsController.add(payload);
                  }
                }
              }
            }
          });
    }
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (_roomCode == null || _localNodeId == null) {
      throw StateError('FirebaseFallbackAdapter must be initialized before broadcasting.');
    }

    final messageId = const Uuid().v4();
    final messageData = {
      'id': messageId,
      'senderId': _localNodeId,
      'payload': jsonPayload,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final path = 'rooms/$_roomCode/relay_messages/$messageId';

    if (_onWriteMessage != null) {
      await _onWriteMessage!(path, messageData);
    }

    if (isFirebaseAvailable) {
      await _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('relay_messages')
          .doc(messageId)
          .set(messageData);
    }
  }

  /// Injects an incoming payload (used in tests or local in-memory fallback).
  void emitIncomingPayload(String payload) {
    _incomingPayloadsController.add(payload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingPayloadsController.stream;

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _roomCode = null;
    _localNodeId = null;
  }
}
