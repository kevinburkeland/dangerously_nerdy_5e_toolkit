import 'dart:async';
import '../../../domain/ports/i_p2p_transport_port.dart';

/// Transport adapter for Tier 1 Local Wi-Fi / LAN communication.
///
/// Implements [IP2pTransportPort] for zero-cost, zero-latency local communication.
/// In environments where local network discovery/sockets are unavailable or disabled,
/// [initializeRoom] fails, allowing [CascadingTransportRouter] to step down
/// to WebRTC mesh (Tier 2).
class LocalWifiAdapter implements IP2pTransportPort {
  final Future<void> Function(String roomCode, String localNodeId)? onInitialize;
  final Future<void> Function(String jsonPayload)? onBroadcast;
  final Future<void> Function()? onDisconnect;

  String? _roomCode;
  String? _localNodeId;
  bool _isInitialized = false;

  final StreamController<String> _incomingPayloadsController =
      StreamController<String>.broadcast();

  LocalWifiAdapter({
    this.onInitialize,
    this.onBroadcast,
    this.onDisconnect,
  });

  bool get isInitialized => _isInitialized;
  String? get roomCode => _roomCode;
  String? get localNodeId => _localNodeId;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;

    if (onInitialize != null) {
      await onInitialize!(_roomCode!, _localNodeId!);
      _isInitialized = true;
      return;
    }

    // Default behavior: Local Wi-Fi requires platform socket or LAN multicast setup.
    // If no custom handler is provided, throw so the router cascades to WebRTC (Tier 2).
    throw UnsupportedError(
      'Local Wi-Fi transport is not enabled on this host; falling back to WebRTC.',
    );
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (!_isInitialized) {
      throw StateError('LocalWifiAdapter must be initialized before broadcasting.');
    }

    if (onBroadcast != null) {
      await onBroadcast!(jsonPayload);
    }
  }

  /// Injects an incoming payload from a local LAN peer.
  void emitIncomingPayload(String payload) {
    _incomingPayloadsController.add(payload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingPayloadsController.stream;

  @override
  Future<void> disconnect() async {
    _isInitialized = false;
    _roomCode = null;
    _localNodeId = null;

    if (onDisconnect != null) {
      await onDisconnect!();
    }
    await _incomingPayloadsController.close();
  }
}
