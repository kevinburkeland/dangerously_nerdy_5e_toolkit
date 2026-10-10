import 'package:vtt_engine_core/vtt_engine_core.dart';

/// Application service managing local party session node identity and timestamping.
/// Enforces unique ReplicaId identity (UUIDv4) and maintains monotonic HLC timestamp
/// state for active local writes to eliminate timestamp collisions.
class PartyRoomService {
  final ReplicaId replicaId;
  final StatefulHlcClock _clock;

  String get localNodeId => replicaId.value;
  StatefulHlcClock get clock => _clock;

  PartyRoomService({
    required this.replicaId,
    required StatefulHlcClock clock,
  }) : _clock = clock;

  /// Generates the next monotonic [HybridLogicalClock] timestamp anchored to this node.
  HybridLogicalClock createLocalTimestamp({int offsetMs = 0}) {
    return _clock.nextTimestamp(offsetMs: offsetMs);
  }

  /// Observes a remote timestamp from another node and reconciles local clock causality.
  void observeRemoteTimestamp(HybridLogicalClock remote, {int offsetMs = 0}) {
    _clock.observeRemote(remote, offsetMs: offsetMs);
  }
}
