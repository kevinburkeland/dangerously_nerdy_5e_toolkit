import 'package:meta/meta.dart';
import 'cascading_transport_router.dart';

/// Telemetry state snapshot of the active P2P room connection.
@immutable
class RoomConnectionTelemetry {
  final TransportState state;
  final int peerCount;
  final bool isHost;

  const RoomConnectionTelemetry({
    this.state = TransportState.connecting,
    this.peerCount = 0,
    this.isHost = false,
  });

  /// Human-readable label representing the active network tier.
  String get connectionLabel {
    switch (state) {
      case TransportState.connecting:
        return 'Connecting...';
      case TransportState.localWifi:
        return 'Local Wi-Fi';
      case TransportState.webRtc:
        return 'WebRTC P2P';
      case TransportState.fallbackRelay:
        return 'Firebase Relay';
      case TransportState.offline:
        return 'Offline';
    }
  }

  /// Whether the connection is offline or unestablished with zero connected peers.
  bool get isOffline =>
      state == TransportState.offline ||
      (state == TransportState.connecting && peerCount == 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomConnectionTelemetry &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          peerCount == other.peerCount &&
          isHost == other.isHost;

  @override
  int get hashCode => Object.hash(state, peerCount, isHost);

  @override
  String toString() =>
      'RoomConnectionTelemetry(state: $state, peerCount: $peerCount, isHost: $isHost)';
}
