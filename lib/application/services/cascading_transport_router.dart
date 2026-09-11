import 'dart:async';
import 'dart:convert';
import '../../domain/ports/i_p2p_transport_port.dart';
import '../../infrastructure/adapters/p2p/webrtc_mesh_adapter.dart';

/// Connection states for the 4-tier cascading transport hierarchy.
enum TransportState {
  connecting,
  localWifi,
  webRtc,
  fallbackRelay,
  offline;

  /// Backwards compatibility alias for code expecting [p2pEstablished].
  @Deprecated('Use webRtc instead')
  static const TransportState p2pEstablished = TransportState.webRtc;
}

/// Application service orchestrating a 4-tier cost-optimized cascading transport model:
/// 1. Tier 1: Local Wi-Fi / LAN (Zero Cost)
/// 2. Tier 2: WebRTC P2P DataChannel mesh with Ephemeral Firebase Signaling (Zero Cost)
/// 3. Tier 3: Firebase Firestore Cloud Relay (Metered Fallback)
/// 4. Tier 4: Total Offline (Disconnected)
class CascadingTransportRouter implements IP2pTransportPort {
  final IP2pTransportPort localWifiAdapter;
  final IP2pTransportPort webRtcAdapter;
  final IP2pTransportPort firebaseFallbackAdapter;
  final Duration heartbeatTtl;
  final Duration checkInterval;
  final Map<String, int> Function()? peerTimestampProvider;
  final void Function(String peerId)? onPeerPruned;

  TransportState _currentState = TransportState.connecting;
  IP2pTransportPort? _activeAdapter;
  String? _roomCode;
  String? _localNodeId;

  StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  StreamController<TransportState> _stateController =
      StreamController<TransportState>.broadcast();

  StreamSubscription<String>? _activeSubscription;
  Timer? _heartbeatTimer;
  Timer? _fallbackHeartbeatTimer;

  final Map<String, int> _peerLastSeen = {};

  CascadingTransportRouter({
    required this.localWifiAdapter,
    required this.webRtcAdapter,
    required this.firebaseFallbackAdapter,
    this.heartbeatTtl = const Duration(seconds: 15),
    this.checkInterval = const Duration(seconds: 1),
    this.peerTimestampProvider,
    this.onPeerPruned,
  });

  @override
  TransportState get currentState => _currentState;
  Stream<TransportState> get onStateChanged => _stateController.stream;
  @override
  Map<String, int> get peerLastSeen => Map.unmodifiable(_peerLastSeen);
  IP2pTransportPort? get activeAdapter => _activeAdapter;
  String? get roomCode => _roomCode;
  String? get localNodeId => _localNodeId;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    final cleanCode = roomCode.trim().toUpperCase();
    if (_roomCode == cleanCode &&
        _activeAdapter != null &&
        _currentState != TransportState.offline) {
      return;
    }

    if (_payloadController.isClosed) {
      _payloadController = StreamController<String>.broadcast();
    }
    if (_stateController.isClosed) {
      _stateController = StreamController<TransportState>.broadcast();
    }

    await _activeSubscription?.cancel();
    _activeSubscription = null;
    await _activeAdapter?.disconnect();
    _activeAdapter = null;

    _roomCode = cleanCode;
    _localNodeId = localNodeId;
    _peerLastSeen.clear();
    _changeState(TransportState.connecting);

    // Tier 1: Local Wi-Fi (Zero Cost)
    try {
      await _activateAdapter(localWifiAdapter, TransportState.localWifi);
      return;
    } catch (_) {}

    // Tier 2: WebRTC P2P Mesh (Zero Cost Data Channel, Ephemeral Signaling)
    try {
      await _activateAdapter(webRtcAdapter, TransportState.webRtc);
      return;
    } catch (_) {}

    // Tier 3: Firebase Cloud Relay (Incurs Cost)
    try {
      await _activateAdapter(firebaseFallbackAdapter, TransportState.fallbackRelay);
      return;
    } catch (_) {}

    // Tier 4: Total Offline
    _changeState(TransportState.offline);
  }

  Future<void> _activateAdapter(
    IP2pTransportPort adapter,
    TransportState targetState,
  ) async {
    await adapter.initializeRoom(_roomCode!, _localNodeId!);

    await _activeSubscription?.cancel();
    _activeAdapter = adapter;
    _changeState(targetState);

    _activeSubscription =
        _activeAdapter!.watchIncomingPayloads().listen(_handleIncomingPayload);

    // Ephemeral signaling guarantee: aggressively wipe handshake docs upon WebRTC connection
    if (targetState == TransportState.webRtc && adapter is WebRtcMeshAdapter) {
      await adapter.signalingAdapter?.cleanUpSignalingSession();
    }

    if (targetState == TransportState.fallbackRelay) {
      _startFallbackHeartbeats();
    } else {
      _fallbackHeartbeatTimer?.cancel();
      _fallbackHeartbeatTimer = null;
    }

    _startHeartbeatMonitor();
  }

  void _handleIncomingPayload(String payload) {
    try {
      if (payload.startsWith('{')) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final sender = decoded['from'] ?? decoded['senderId'];
          if (sender is String && sender.isNotEmpty && sender != _localNodeId) {
            _peerLastSeen[sender] = DateTime.now().millisecondsSinceEpoch;
          }
          if (decoded['_protocol'] == 'relay_heartbeat' ||
              decoded['_protocol'] == 'heartbeat_ping' ||
              decoded['_protocol'] == 'heartbeat_pong') {
            return;
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
    if (_activeAdapter == null || _currentState == TransportState.offline) return;

    try {
      await _activeAdapter!.broadcastPayload(jsonPayload);
    } catch (_) {
      // Failover step down waterfall if transmission fails
      await _stepDownWaterfall();
      try {
        await _activeAdapter?.broadcastPayload(jsonPayload);
      } catch (_) {
        _changeState(TransportState.offline);
      }
    }
  }

  Future<void> _stepDownWaterfall() async {
    await _activeSubscription?.cancel();
    _activeSubscription = null;
    await _activeAdapter?.disconnect();
    _activeAdapter = null;

    if (_currentState == TransportState.localWifi) {
      try {
        await _activateAdapter(webRtcAdapter, TransportState.webRtc);
        return;
      } catch (_) {}
    }

    if (_currentState == TransportState.localWifi ||
        _currentState == TransportState.webRtc) {
      try {
        await _activateAdapter(
          firebaseFallbackAdapter,
          TransportState.fallbackRelay,
        );
        return;
      } catch (_) {}
    }

    _changeState(TransportState.offline);
  }

  void _startHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(checkInterval, (_) {
      checkHeartbeats();
    });
  }

  /// Evaluates peer heartbeats against the TTL.
  /// Prunes zombie nodes and steps down the waterfall if active peers drop to zero.
  Future<void> checkHeartbeats([DateTime? currentTime]) async {
    final now = (currentTime ?? DateTime.now()).millisecondsSinceEpoch;
    final ttl = heartbeatTtl.inMilliseconds;

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

    if (_activeAdapter != null) {
      final adapterPeers = _activeAdapter!.peerLastSeen;
      for (final entry in adapterPeers.entries) {
        final existing = _peerLastSeen[entry.key] ?? 0;
        if (entry.value > existing) {
          _peerLastSeen[entry.key] = entry.value;
        }
      }
    }

    final zombieNodes = <String>[];
    for (final entry in _peerLastSeen.entries) {
      if (now - entry.value >= ttl) {
        zombieNodes.add(entry.key);
      }
    }

    for (final zombieId in zombieNodes) {
      _peerLastSeen.remove(zombieId);
      onPeerPruned?.call(zombieId);
    }

    // Step down waterfall if all peers went zombie during local or P2P session
    if ((_currentState == TransportState.localWifi ||
            _currentState == TransportState.webRtc) &&
        _peerLastSeen.isEmpty &&
        zombieNodes.isNotEmpty) {
      await _stepDownWaterfall();
    }
  }

  void _startFallbackHeartbeats() {
    _fallbackHeartbeatTimer?.cancel();
    _fallbackHeartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_currentState != TransportState.fallbackRelay || _localNodeId == null) {
        return;
      }
      try {
        final ping = jsonEncode({
          '_protocol': 'relay_heartbeat',
          'from': _localNodeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        firebaseFallbackAdapter.broadcastPayload(ping);
      } catch (_) {}
    });
  }

  void _changeState(TransportState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  @override
  Stream<String> watchIncomingPayloads() => _payloadController.stream;

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _fallbackHeartbeatTimer?.cancel();
    _fallbackHeartbeatTimer = null;

    await _activeSubscription?.cancel();
    _activeSubscription = null;

    await localWifiAdapter.disconnect();
    await webRtcAdapter.disconnect();
    await firebaseFallbackAdapter.disconnect();

    _activeAdapter = null;
    _peerLastSeen.clear();
    _changeState(TransportState.offline);

    await _payloadController.close();
    await _stateController.close();
  }
}
