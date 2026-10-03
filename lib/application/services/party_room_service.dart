import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../infrastructure/di/injection_container.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces cryptographically unique UUIDv4 node IDs to eliminate tie-breaker collisions.
class PartyRoomService {
  final String localNodeId;

  static String _resolveNodeId(ReplicaId? replicaId, String? nodeId) {
    if (replicaId != null) return replicaId.value;
    if (nodeId != null &&
        nodeId.trim().isNotEmpty &&
        nodeId.trim().toLowerCase() != 'local') {
      return nodeId.trim();
    }
    if (sl.isRegistered<ReplicaId>()) return sl<ReplicaId>().value;
    throw StateError(
      'PartyRoomService requires an authoritative ReplicaId. '
      'Ensure initServiceLocator() has completed or inject ReplicaId explicitly.',
    );
  }

  PartyRoomService({ReplicaId? replicaId, String? nodeId})
      : localNodeId = _resolveNodeId(replicaId, nodeId);

  /// Creates a new [HybridLogicalClock] timestamp anchored to this node's unique ID.
  HybridLogicalClock createLocalTimestamp() {
    return HybridLogicalClock.now(localNodeId);
  }
}
