import 'package:flutter/material.dart';
import '../../application/services/cascading_transport_router.dart';
import '../../application/services/room_connection_telemetry.dart';

/// Semantic, accessible status badge showing active P2P room connection state and peer count.
class RoomConnectionBadge extends StatelessWidget {
  final Stream<RoomConnectionTelemetry> telemetryStream;
  final RoomConnectionTelemetry? initialTelemetry;
  final bool compact;

  const RoomConnectionBadge({
    super.key,
    required this.telemetryStream,
    this.initialTelemetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoomConnectionTelemetry>(
      stream: telemetryStream,
      initialData: initialTelemetry ?? const RoomConnectionTelemetry(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const RoomConnectionTelemetry();

        IconData icon;
        Color color;

        if (data.isOffline) {
          icon = Icons.cloud_off;
          color = Colors.redAccent;
        } else if (data.state == TransportState.localWifi) {
          icon = Icons.wifi;
          color = Colors.green;
        } else if (data.state == TransportState.webRtc) {
          icon = Icons.lan;
          color = Colors.green;
        } else if (data.state == TransportState.fallbackRelay) {
          icon = Icons.cloud_queue;
          color = Colors.orange;
        } else {
          icon = Icons.sync;
          color = Colors.grey;
        }

        final semanticText = data.isOffline
            ? 'Network Status: Offline.'
            : 'Network Status: ${data.connectionLabel}, ${data.peerCount} peers connected.';

        return Semantics(
          label: semanticText,
          container: true,
          excludeSemantics: true,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 28.0 : 48.0),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8.0 : 12.0,
              vertical: compact ? 3.0 : 8.0,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(compact ? 14.0 : 24.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: compact ? 14 : 20),
                SizedBox(width: compact ? 5.0 : 8.0),
                Flexible(
                  child: Text(
                    '${data.connectionLabel} (${data.peerCount})',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 11 : 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

