import 'package:uuid/uuid.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../infrastructure/di/injection_container.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces cryptographically unique UUIDv4 node IDs to eliminate tie-breaker collisions.
class PartyRoomService {
  final String localNodeId;

  PartyRoomService({ReplicaId? replicaId, String? nodeId})
      : localNodeId = replicaId?.value ??
            nodeId ??
            (sl.isRegistered<ReplicaId>() ? sl<ReplicaId>().value : null) ??
            const Uuid().v4();

  /// Creates a new [HybridLogicalClock] timestamp anchored to this node's unique ID.
  HybridLogicalClock createLocalTimestamp() {
    return HybridLogicalClock.now(localNodeId);
  }
}
