import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../infrastructure/di/injection_container.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces cryptographically unique UUIDv4 node IDs to eliminate tie-breaker collisions.
class PartyRoomService {
  final ReplicaId replicaId;
  String get localNodeId => replicaId.value;

  static ReplicaId _resolveReplicaId(ReplicaId? replicaId, [String? nodeId]) {
    if (replicaId != null) return replicaId;
    if (nodeId != null &&
        nodeId.trim().isNotEmpty &&
        nodeId.trim().toLowerCase() != 'local') {
      return ReplicaId(nodeId.trim());
    }
    if (sl.isRegistered<ReplicaId>()) return sl<ReplicaId>();
    throw StateError(
      'PartyRoomService requires an authoritative ReplicaId. '
      'Ensure initServiceLocator() has completed or inject ReplicaId explicitly.',
    );
  }

  PartyRoomService({
    ReplicaId? replicaId,
    @Deprecated('Use replicaId instead') String? nodeId,
  }) : replicaId = _resolveReplicaId(replicaId, nodeId);

  /// Creates a new [HybridLogicalClock] timestamp anchored to this node's unique ID.
  HybridLogicalClock createLocalTimestamp() {
    return HybridLogicalClock.now(localNodeId);
  }
}
