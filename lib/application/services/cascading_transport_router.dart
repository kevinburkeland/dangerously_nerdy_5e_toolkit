import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:meta/meta.dart';
import '../../domain/ports/i_p2p_transport_port.dart';
import '../../utils/crypto_utils.dart';

export '../../domain/ports/transport_state.dart';

/// Application service orchestrating a 4-tier cost-optimized cascading transport model:
/// 1. Tier 1: Local Wi-Fi / LAN (Zero Cost)
/// 2. Tier 2: WebRTC P2P DataChannel mesh with Ephemeral Firebase Signaling (Zero Cost)
/// 3. Tier 3: Firebase Firestore Cloud Relay (Metered Fallback)
/// 4. Tier 4: Total Offline (Disconnected)
class CascadingTransportRouter implements IP2pTransportPort {
  final IP2pTransportPort localWifiAdapter;
  final IP2pTransportPort webRtcAdapter;
  final IP2pTransportPort firebaseFallbackAdapter;
  @override
  final Duration heartbeatTtl;
  final Duration checkInterval;
  final Duration stepUpProbeInterval;
  final Map<String, int> Function()? peerTimestampProvider;
  final void Function(String peerId)? onPeerPruned;
  final String Function(String payload) payloadHasher;

  static const int maxProcessedPayloadHashes = 500;
  final LinkedHashMap<String, bool> _processedPayloadHashes = LinkedHashMap<String, bool>();

  TransportState _currentState = TransportState.connecting;
  IP2pTransportPort? _activeAdapter;
  String? _roomCode;
  String? _localNodeId;

  StreamController<String> _payloadController =
      StreamController<String>.broadcast(sync: false);
  StreamController<TransportState> _stateController =
      StreamController<TransportState>.broadcast(sync: false);

  StreamSubscription<String>? _activeSubscription;
  Timer? _heartbeatTimer;
  Timer? _fallbackHeartbeatTimer;
  Timer? _stepUpProbeTimer;
  bool _isProbing = false;

  final Duration stepUpCooldown;
  final Duration stepUpHoldoff;
  final int sequentialFailureThreshold;
  int _lastStepDownTimestamp = 0;
  int _lastStepUpTimestamp = 0;
  int _stepDownCountInWindow = 0;
  int _consecutiveFailureCount = 0;

  final Map<String, int> _peerLastSeen = {};

  CascadingTransportRouter({
    required this.localWifiAdapter,
    required this.webRtcAdapter,
    required this.firebaseFallbackAdapter,
    this.heartbeatTtl = const Duration(seconds: 15),
    this.checkInterval = const Duration(seconds: 1),
    this.stepUpProbeInterval = const Duration(seconds: 30),
    this.stepUpCooldown = const Duration(seconds: 15),
    this.stepUpHoldoff = const Duration(seconds: 5),
    this.sequentialFailureThreshold = 3,
    this.peerTimestampProvider,
    this.onPeerPruned,
    this.payloadHasher = CryptoUtils.sha256Hex,
  });

  @override
  TransportState get currentState => _currentState;
  Stream<TransportState> get onStateChanged => _stateController.stream;
  @override
  Map<String, int> get peerLastSeen => Map.unmodifiable(_peerLastSeen);
  IP2pTransportPort? get activeAdapter => _activeAdapter;
  String? get roomCode => _roomCode;
  String? get localNodeId => _localNodeId;

  /// Visible for testing failure counter state.
  @visibleForTesting
  int get consecutiveFailureCount => _consecutiveFailureCount;

  /// Visible for testing step up timestamp.
  @visibleForTesting
  int get lastStepUpTimestamp => _lastStepUpTimestamp;

  /// Tracked payload hashes for deduplication (exposed for testing).
  @visibleForTesting
  Set<String> get processedPayloadHashes =>
      Set.unmodifiable(_processedPayloadHashes.keys);

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    final cleanCode = roomCode.trim().toUpperCase();
    if (_roomCode == cleanCode &&
        _activeAdapter != null &&
        _currentState != TransportState.offline) {
      return;
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _fallbackHeartbeatTimer?.cancel();
    _fallbackHeartbeatTimer = null;
    _stepUpProbeTimer?.cancel();
    _stepUpProbeTimer = null;

    if (_payloadController.isClosed) {
      _payloadController = StreamController<String>.broadcast(sync: false);
    }
    if (_stateController.isClosed) {
      _stateController = StreamController<TransportState>.broadcast(sync: false);
    }

    await _activeSubscription?.cancel();
    _activeSubscription = null;
    await _activeAdapter?.disconnect();
    _activeAdapter = null;

    _roomCode = cleanCode;
    _localNodeId = localNodeId;
    _peerLastSeen.clear();
    _processedPayloadHashes.clear();
    _lastStepDownTimestamp = 0;
    _lastStepUpTimestamp = 0;
    _stepDownCountInWindow = 0;
    _consecutiveFailureCount = 0;
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
    // Ephemeral session guarantee: clean up any stale signaling docs from prior sessions
    await adapter.prepareSession();

    await adapter.initializeRoom(_roomCode!, _localNodeId!);

    await _activeSubscription?.cancel();
    _activeAdapter = adapter;
    _changeState(targetState);

    _activeSubscription =
        _activeAdapter!.watchIncomingPayloads().listen(_handleIncomingPayload);

    if (targetState == TransportState.fallbackRelay) {
      _startFallbackHeartbeats();
    } else {
      _fallbackHeartbeatTimer?.cancel();
      _fallbackHeartbeatTimer = null;
    }

    _startHeartbeatMonitor();
    _startStepUpRecoveryMonitor();
  }

  void _handleIncomingPayload(String payload) {
    final payloadHash = payloadHasher(payload);
    if (_processedPayloadHashes.containsKey(payloadHash)) {
      _processedPayloadHashes.remove(payloadHash);
      _processedPayloadHashes[payloadHash] = true;
      return;
    }
    _processedPayloadHashes[payloadHash] = true;
    if (_processedPayloadHashes.length > maxProcessedPayloadHashes) {
      _processedPayloadHashes.remove(_processedPayloadHashes.keys.first);
    }

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
    scheduleMicrotask(() {
      if (!_payloadController.isClosed) {
        _payloadController.add(payload);
      }
    });
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
      _consecutiveFailureCount = 0;
    } catch (_) {
      _consecutiveFailureCount++;
      if (_consecutiveFailureCount >= sequentialFailureThreshold) {
        _consecutiveFailureCount = 0;
        await _stepDownWaterfall();
        try {
          await _activeAdapter?.broadcastPayload(jsonPayload);
        } catch (_) {
          _changeState(TransportState.offline);
        }
      }
    }
  }

  Future<void> _stepDownWaterfall({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        _lastStepUpTimestamp > 0 &&
        (now - _lastStepUpTimestamp < stepUpHoldoff.inMilliseconds)) {
      // Holdoff dampening active; suppress step-down to prevent ping-pong flapping
      return;
    }

    _lastStepDownTimestamp = now;
    _stepDownCountInWindow++;
    _consecutiveFailureCount = 0;

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
      await _stepDownWaterfall(force: true);
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

  void _startStepUpRecoveryMonitor() {
    _stepUpProbeTimer?.cancel();
    if (_currentState == TransportState.localWifi ||
        _currentState == TransportState.offline) {
      _stepUpProbeTimer = null;
      return;
    }

    _stepUpProbeTimer = Timer.periodic(stepUpProbeInterval, (_) async {
      await _attemptStepUpRecovery();
    });
  }

  @override
  Future<void> prepareSession() async {
    await _activeAdapter?.prepareSession();
  }

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async {
    return _currentState != TransportState.offline &&
        _currentState != TransportState.connecting;
  }

  /// Triggers a non-disruptive probe of higher-tier transport adapters.
  @visibleForTesting
  Future<void> probeHigherTiers({bool force = true}) => _attemptStepUpRecovery(force: force);

  Future<void> _attemptStepUpRecovery({bool force = false}) async {
    if (_isProbing || _roomCode == null || _localNodeId == null) return;
    if (_currentState == TransportState.localWifi ||
        _currentState == TransportState.offline) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final dynamicCooldownMs = stepUpCooldown.inMilliseconds *
        (_stepDownCountInWindow > 3 ? 3 : (_stepDownCountInWindow > 0 ? _stepDownCountInWindow : 1));
    if (!force && (now - _lastStepDownTimestamp < dynamicCooldownMs)) {
      // Cooldown active; decouple transient step-downs to prevent rapid channel flapping glare
      return;
    }

    _isProbing = true;
    try {
      // 1. Probe Local Wi-Fi (Tier 1 - Zero Cost) first
      final wifiViable =
          await localWifiAdapter.probeViability(_roomCode!, _localNodeId!);
      if (wifiViable) {
        await _promoteAdapter(localWifiAdapter, TransportState.localWifi);
        return;
      }

      // 2. If in fallbackRelay, probe WebRTC (Tier 2 - Zero Cost Mesh)
      if (_currentState == TransportState.fallbackRelay) {
        final webRtcViable =
            await webRtcAdapter.probeViability(_roomCode!, _localNodeId!);
        if (webRtcViable) {
          await _promoteAdapter(webRtcAdapter, TransportState.webRtc);
          return;
        }
      }
    } catch (_) {
      // Probing failure is non-fatal; the active fallback stream continues unhindered
    } finally {
      _isProbing = false;
    }
  }

  Future<void> _promoteAdapter(
    IP2pTransportPort higherAdapter,
    TransportState newState,
  ) async {
    _stepDownCountInWindow = 0;
    _lastStepUpTimestamp = DateTime.now().millisecondsSinceEpoch;
    _consecutiveFailureCount = 0;
    final previousAdapter = _activeAdapter;
    await _activateAdapter(higherAdapter, newState);
    if (previousAdapter != null && previousAdapter != higherAdapter) {
      try {
        await previousAdapter.disconnect();
      } catch (_) {}
    }
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
    _stepUpProbeTimer?.cancel();
    _stepUpProbeTimer = null;

    await _activeSubscription?.cancel();
    _activeSubscription = null;

    await localWifiAdapter.disconnect();
    await webRtcAdapter.disconnect();
    await firebaseFallbackAdapter.disconnect();

    _activeAdapter = null;
    _peerLastSeen.clear();
    _processedPayloadHashes.clear();
    _changeState(TransportState.offline);

    await _payloadController.close();
    await _stateController.close();
  }
}
