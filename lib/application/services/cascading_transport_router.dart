import 'dart:async';
import 'dart:convert';
import '../../domain/ports/i_p2p_transport_port.dart';

/// Connection states for the cascading transport hierarchy.
enum TransportState {
  connecting,
  p2pEstablished,
  fallbackRelay,
}

/// Application service orchestrating a 3-tier cascading transport model:
/// 1. P2P WebRTC DataChannel mesh.
/// 2. Automatic heartbeat tracking with 6-second Zombie Node Pruning.
/// 3. Transparent fallback to Firebase cloud relay when P2P is lost or fails.
class CascadingTransportRouter implements IP2pTransportPort {
  final IP2pTransportPort webRtcAdapter;
  final IP2pTransportPort firebaseFallbackAdapter;
  final Duration heartbeatTtl;
  final Duration checkInterval;
  final Map<String, int> Function()? peerTimestampProvider;
  final void Function(String peerId)? onPeerPruned;

  TransportState _currentState = TransportState.connecting;
  String? _roomCode;
  String? _localNodeId;

  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  final StreamController<TransportState> _stateController =
      StreamController<TransportState>.broadcast();

  StreamSubscription<String>? _webRtcSubscription;
  StreamSubscription<String>? _fallbackSubscription;
  Timer? _heartbeatMonitorTimer;

  /// Internal tracking of peer last seen timestamps (nodeId -> epoch ms).
  final Map<String, int> _peerLastSeen = {};

  CascadingTransportRouter({
    required this.webRtcAdapter,
    required this.firebaseFallbackAdapter,
    this.heartbeatTtl = const Duration(seconds: 6),
    this.checkInterval = const Duration(seconds: 1),
    this.peerTimestampProvider,
    this.onPeerPruned,
  });

  TransportState get currentState => _currentState;
  Stream<TransportState> get onStateChanged => _stateController.stream;
  Map<String, int> get peerLastSeen => Map.unmodifiable(_peerLastSeen);

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;
    _changeState(TransportState.connecting);

    try {
      await webRtcAdapter.initializeRoom(_roomCode!, _localNodeId!);
      _changeState(TransportState.p2pEstablished);

      _webRtcSubscription = webRtcAdapter
          .watchIncomingPayloads()
          .listen(_handleIncomingWebRtcPayload);
    } catch (_) {
      // Immediate fallback to Firebase relay if WebRTC setup fails
      await _triggerFallback();
    }

    _startHeartbeatMonitor();
  }

  void _changeState(TransportState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  void _handleIncomingWebRtcPayload(String payload) {
    // Inspect payload for sender identity and heartbeat updates
    try {
      if (payload.startsWith('{')) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          final sender = decoded['from'] ?? decoded['senderId'];
          if (sender is String && sender.isNotEmpty) {
            recordPeerHeartbeat(sender);
          }
        }
      }
    } catch (_) {}

    _payloadController.add(payload);
  }

  /// Manually records a heartbeat from a peer node (or updates timestamp).
  void recordPeerHeartbeat(String peerId, {int? timestamp}) {
    _peerLastSeen[peerId] = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (_currentState == TransportState.p2pEstablished) {
      try {
        await webRtcAdapter.broadcastPayload(jsonPayload);
      } catch (_) {
        await _triggerFallback();
        await firebaseFallbackAdapter.broadcastPayload(jsonPayload);
      }
    } else {
      await firebaseFallbackAdapter.broadcastPayload(jsonPayload);
    }
  }

  @override
  Stream<String> watchIncomingPayloads() => _payloadController.stream;

  /// Transitions transport to Firebase fallback relay, initializing it if necessary.
  Future<void> _triggerFallback() async {
    if (_currentState == TransportState.fallbackRelay) return;

    _changeState(TransportState.fallbackRelay);

    if (_fallbackSubscription == null && _roomCode != null && _localNodeId != null) {
      try {
        await firebaseFallbackAdapter.initializeRoom(_roomCode!, _localNodeId!);
      } catch (_) {}

      _fallbackSubscription = firebaseFallbackAdapter
          .watchIncomingPayloads()
          .listen(_payloadController.add);
    }
  }

  /// Starts the periodic heartbeat monitor that prunes nodes exceeding the 6-second TTL.
  void _startHeartbeatMonitor() {
    _heartbeatMonitorTimer?.cancel();
    _heartbeatMonitorTimer = Timer.periodic(checkInterval, (_) {
      checkHeartbeats();
    });
  }

  /// Evaluates peer heartbeats against the 6-second TTL.
  /// Prunes zombie nodes and triggers fallback if active peers drop to zero.
  void checkHeartbeats([DateTime? currentTime]) {
    if (_currentState != TransportState.p2pEstablished) return;

    final now = (currentTime ?? DateTime.now()).millisecondsSinceEpoch;
    final ttlMs = heartbeatTtl.inMilliseconds;

    // Merge external provider timestamps if available
    if (peerTimestampProvider != null) {
      final externalTimestamps = peerTimestampProvider!();
      for (final entry in externalTimestamps.entries) {
        final existing = _peerLastSeen[entry.key] ?? 0;
        if (entry.value > existing) {
          _peerLastSeen[entry.key] = entry.value;
        }
      }
    }

    final zombieNodes = <String>[];
    for (final entry in _peerLastSeen.entries) {
      if (now - entry.value >= ttlMs) {
        zombieNodes.add(entry.key);
      }
    }

    for (final zombieId in zombieNodes) {
      _peerLastSeen.remove(zombieId);
      onPeerPruned?.call(zombieId);
    }

    // If all peers went zombie, trigger fallback to cloud relay
    if (_peerLastSeen.isEmpty && zombieNodes.isNotEmpty) {
      _triggerFallback();
    }
  }

  @override
  Future<void> disconnect() async {
    _heartbeatMonitorTimer?.cancel();
    _heartbeatMonitorTimer = null;

    await _webRtcSubscription?.cancel();
    _webRtcSubscription = null;

    await _fallbackSubscription?.cancel();
    _fallbackSubscription = null;

    _peerLastSeen.clear();

    await webRtcAdapter.disconnect();
    await firebaseFallbackAdapter.disconnect();

    await _payloadController.close();
    await _stateController.close();
  }
}
