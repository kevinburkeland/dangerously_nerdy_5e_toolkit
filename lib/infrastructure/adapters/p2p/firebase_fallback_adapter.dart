import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import '../../../utils/crypto_utils.dart';

/// Firebase Firestore-backed relay transport adapter implementing [IP2pTransportPort].
/// Serves as the robust, reliable 3rd-tier fallback when P2P WebRTC mesh traversal
/// (STUN/TURN) fails or peers are partitioned.
class FirebaseFallbackAdapter implements IP2pTransportPort {
  final FirebaseFirestore? _firestore;
  final Future<void> Function(String path, Map<String, dynamic> data)?
      _onWriteMessage;

  String? _roomCode;
  String? _localNodeId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamController<String> _incomingPayloadsController =
      StreamController<String>.broadcast(sync: false);

  static const int maxProcessedPayloadHashes = 500;
  static const int maxProcessedMessageIds = maxProcessedPayloadHashes;
  final Set<String> _processedPayloadHashes = <String>{};
  final Map<String, Set<String>> _peerPayloadHashes = <String, Set<String>>{};
  int? _lastQueryThreshold;

  FirebaseFallbackAdapter({
    FirebaseFirestore? firestore,
    Future<void> Function(String path, Map<String, dynamic> data)?
        onWriteMessage,
  })  : _firestore = firestore,
        _onWriteMessage = onWriteMessage;

  bool get isFirebaseAvailable =>
      _firestore != null || Firebase.apps.isNotEmpty;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  TransportState get currentState => _subscription != null
      ? TransportState.fallbackRelay
      : TransportState.offline;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async {
    return isFirebaseAvailable;
  }

  /// Set of tracked payload hashes processed to prevent duplicate emission.
  Set<String> get processedPayloadHashes =>
      Set.unmodifiable(_processedPayloadHashes);

  /// Backwards-compatible alias for [processedPayloadHashes].
  @Deprecated('Use processedPayloadHashes instead')
  Set<String> get processedMessageIds => processedPayloadHashes;

  /// Map of payload hashes tracked per peer ID.
  Map<String, Set<String>> get peerPayloadHashes => Map.unmodifiable(
      _peerPayloadHashes.map((k, v) => MapEntry(k, Set.unmodifiable(v))));

  /// The timestamp threshold used in the Firestore query constraint.
  int? get lastQueryThreshold => _lastQueryThreshold;

  /// Prunes the specific [peerId] from tracked payload hashes without
  /// indiscriminately wiping the entire relay session, satisfying the N >= 3 topology mandate.
  void cleanUpPeerRelay(String peerId) {
    final peerHashes = _peerPayloadHashes.remove(peerId);
    if (peerHashes != null) {
      _processedPayloadHashes.removeAll(peerHashes);
    }
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    await _subscription?.cancel();
    _subscription = null;

    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    if (_incomingPayloadsController.isClosed) {
      _incomingPayloadsController =
          StreamController<String>.broadcast(sync: false);
    }

    // 30-second skew tolerance buffer (now - 30000)
    final queryThreshold = DateTime.now().millisecondsSinceEpoch - 30000;
    _lastQueryThreshold = queryThreshold;

    if (isFirebaseAvailable) {
      // Rehydrate room stub and reset the 30-day lease on Firestore
      try {
        final now = DateTime.now();
        final expiresAt = now.add(const Duration(days: 30));
        await _effectiveFirestore.collection('rooms').doc(_roomCode).set({
          'roomCode': _roomCode,
          'code': _roomCode,
          'campaignName': 'Campaign $_roomCode',
          'isStateless': true,
          'lastUpdated': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}

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
              final senderId = data['senderId']?.toString();
              final payload = data['payload'] as String?;
              if (payload != null && payload.isNotEmpty) {
                _handleRelayMessage(messageId, payload, senderId: senderId);
              }
            }
          }
        }
      });
    }
  }

  bool _handleRelayMessage(String messageId, String payload,
      {String? senderId}) {
    final payloadHash = CryptoUtils.sha256Hex(payload);
    if (_processedPayloadHashes.contains(payloadHash)) {
      return false;
    }
    _processedPayloadHashes.add(payloadHash);
    if (senderId != null && senderId.isNotEmpty) {
      _peerPayloadHashes
          .putIfAbsent(senderId, () => <String>{})
          .add(payloadHash);
    }
    if (_processedPayloadHashes.length > maxProcessedPayloadHashes) {
      final evicted = _processedPayloadHashes.first;
      _processedPayloadHashes.remove(evicted);
      for (final peerHashes in _peerPayloadHashes.values) {
        peerHashes.remove(evicted);
      }
    }
    if (!_incomingPayloadsController.isClosed) {
      _incomingPayloadsController.add(payload);
    }
    return true;
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (_roomCode == null || _localNodeId == null) {
      throw StateError(
          'FirebaseFallbackAdapter must be initialized before broadcasting.');
    }

    final messageId = const Uuid().v4();
    final messageData = {
      'id': messageId,
      'senderId': _localNodeId,
      'payload': jsonPayload,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expireAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1))),
    };

    final path = 'rooms/$_roomCode/relay_messages/$messageId';

    if (_onWriteMessage != null) {
      await _onWriteMessage(path, messageData);
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
  void emitIncomingPayload(String payload,
      {String? messageId, String? senderId}) {
    _handleRelayMessage(messageId ?? const Uuid().v4(), payload,
        senderId: senderId);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingPayloadsController.stream;

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _roomCode = null;
    _localNodeId = null;
    _processedPayloadHashes.clear();
    _peerPayloadHashes.clear();
    if (!_incomingPayloadsController.isClosed) {
      await _incomingPayloadsController.close();
    }
  }
}
