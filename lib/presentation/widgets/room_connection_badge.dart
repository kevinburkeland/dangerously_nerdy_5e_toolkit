import 'package:flutter/material.dart';
import '../../application/services/cascading_transport_router.dart';
import '../../application/services/room_connection_telemetry.dart';

/// Semantic, accessible status badge showing active P2P room connection state and peer count.
class RoomConnectionBadge extends StatelessWidget {
  final Stream<RoomConnectionTelemetry> telemetryStream;
  final RoomConnectionTelemetry? initialTelemetry;

  const RoomConnectionBadge({
    super.key,
    required this.telemetryStream,
    this.initialTelemetry,
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
          color = Colors.red;
        } else if (data.state == TransportState.p2pEstablished) {
          icon = Icons.lan;
          color = Colors.green;
        } else if (data.state == TransportState.fallbackRelay) {
          icon = Icons.cloud_queue;
          color = Colors.orange;
        } else {
          icon = Icons.sync;
          color = Colors.grey;
        }

        return Semantics(
          label:
              'Network Status: ${data.connectionLabel}, ${data.peerCount} peers connected.',
          container: true,
          child: Chip(
            avatar: Icon(icon, color: color, size: 16),
            label: Text(
              '${data.connectionLabel} (${data.peerCount})',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            backgroundColor: color.withValues(alpha: 0.1),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
        );
      },
    );
  }
}
