import 'package:vtt_engine_core/vtt_engine_core.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces cryptographically unique UUIDv4 node IDs to eliminate tie-breaker collisions.
class PartyRoomService {
  final ReplicaId replicaId;
  String get localNodeId => replicaId.value;

  const PartyRoomService({required this.replicaId});

  /// Creates a new [HybridLogicalClock] timestamp anchored to this node's unique ID.
  HybridLogicalClock createLocalTimestamp() {
    return HybridLogicalClock.now(localNodeId);
  }
}
