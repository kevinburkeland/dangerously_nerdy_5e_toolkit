import 'package:uuid/uuid.dart';
import '../../domain/crdt/hybrid_logical_clock.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces cryptographically unique UUIDv4 node IDs to eliminate tie-breaker collisions.
class PartyRoomService {
  final String localNodeId;

  PartyRoomService({String? nodeId}) : localNodeId = nodeId ?? const Uuid().v4();

  /// Creates a new [HybridLogicalClock] timestamp anchored to this node's unique ID.
  HybridLogicalClock createLocalTimestamp() {
    return HybridLogicalClock.now(localNodeId);
  }
}
