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

  static const int maxProcessedMessageIds = 500;
  final Set<String> _processedMessageIds = <String>{};
  int? _lastQueryThreshold;

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

  /// Set of tracked message IDs processed to prevent duplicate emission.
  Set<String> get processedMessageIds => Set.unmodifiable(_processedMessageIds);

  /// The timestamp threshold used in the Firestore query constraint.
  int? get lastQueryThreshold => _lastQueryThreshold;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    await _subscription?.cancel();
    _subscription = null;

    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    if (_incomingPayloadsController.isClosed) {
      _incomingPayloadsController = StreamController<String>.broadcast();
    }

    // 30-second skew tolerance buffer (now - 30000)
    final queryThreshold = DateTime.now().millisecondsSinceEpoch - 30000;
    _lastQueryThreshold = queryThreshold;

    if (isFirebaseAvailable) {
      final collection = _effectiveFirestore
          .collection('rooms')
          .doc(_roomCode)
          .collection('relay_messages');

      _subscription = collection
          .where('timestamp', isGreaterThanOrEqualTo: queryThreshold)
          .snapshots()
          .listen((snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null && data['senderId'] != _localNodeId) {
                  final messageId = data['id']?.toString() ?? change.doc.id;
                  final payload = data['payload'] as String?;
                  if (payload != null && payload.isNotEmpty) {
                    _handleRelayMessage(messageId, payload);
                  }
                }
              }
            }
          });
    }
  }

  bool _handleRelayMessage(String messageId, String payload) {
    if (_processedMessageIds.contains(messageId)) {
      return false;
    }
    _processedMessageIds.add(messageId);
    if (_processedMessageIds.length > maxProcessedMessageIds) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }
    if (!_incomingPayloadsController.isClosed) {
      _incomingPayloadsController.add(payload);
    }
    return true;
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
      'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
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
  void emitIncomingPayload(String payload, {String? messageId}) {
    _handleRelayMessage(messageId ?? const Uuid().v4(), payload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingPayloadsController.stream;

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _roomCode = null;
    _localNodeId = null;
    _processedMessageIds.clear();
    if (!_incomingPayloadsController.isClosed) {
      await _incomingPayloadsController.close();
    }
  }
}
