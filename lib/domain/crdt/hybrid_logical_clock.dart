import 'dart:math' as math;
import 'package:meta/meta.dart';

/// Value object tracking physical time and logical causality for distributed state reconciliation.
/// Implements deterministic lexicographical tie-breaking by [nodeId] when physical time
/// and logical counter are identical.
@immutable
class HybridLogicalClock implements Comparable<HybridLogicalClock> {
  final int physicalTime;
  final int logicalCounter;
  final String nodeId;

  const HybridLogicalClock({
    required this.physicalTime,
    required this.logicalCounter,
    required this.nodeId,
  });

  factory HybridLogicalClock.now(String nodeId) {
    return HybridLogicalClock(
      physicalTime: DateTime.now().toUtc().millisecondsSinceEpoch,
      logicalCounter: 0,
      nodeId: nodeId,
    );
  }

  /// Advances the clock locally. If physical time has moved forward, resets
  /// the logical counter to 0; otherwise increments the logical counter.
  HybridLogicalClock tick() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (now > physicalTime) {
      return HybridLogicalClock(
        physicalTime: now,
        logicalCounter: 0,
        nodeId: nodeId,
      );
    }
    return HybridLogicalClock(
      physicalTime: physicalTime,
      logicalCounter: logicalCounter + 1,
      nodeId: nodeId,
    );
  }

  /// Reconciles local clock with a remote clock, taking the max physical time
  /// and resolving the logical counter causality.
  HybridLogicalClock merge(HybridLogicalClock remote) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final maxPhysical = math.max(physicalTime, remote.physicalTime);
    final nextPhysical = math.max(maxPhysical, now);

    int nextCounter = 0;
    if (nextPhysical == physicalTime && nextPhysical == remote.physicalTime) {
      nextCounter = math.max(logicalCounter, remote.logicalCounter) + 1;
    } else if (nextPhysical == physicalTime) {
      nextCounter = logicalCounter + 1;
    } else if (nextPhysical == remote.physicalTime) {
      nextCounter = remote.logicalCounter + 1;
    }

    return HybridLogicalClock(
      physicalTime: nextPhysical,
      logicalCounter: nextCounter,
      nodeId: nodeId,
    );
  }

  @override
  int compareTo(HybridLogicalClock other) {
    if (physicalTime == other.physicalTime) {
      if (logicalCounter == other.logicalCounter) {
        return nodeId.compareTo(other.nodeId); // Lexicographical tie-breaker
      }
      return logicalCounter.compareTo(other.logicalCounter);
    }
    return physicalTime.compareTo(other.physicalTime);
  }

  bool isAfter(HybridLogicalClock other) => compareTo(other) > 0;
  bool isBefore(HybridLogicalClock other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HybridLogicalClock &&
          runtimeType == other.runtimeType &&
          physicalTime == other.physicalTime &&
          logicalCounter == other.logicalCounter &&
          nodeId == other.nodeId;

  @override
  int get hashCode =>
      physicalTime.hashCode ^ logicalCounter.hashCode ^ nodeId.hashCode;

  @override
  String toString() =>
      'HybridLogicalClock(pt: $physicalTime, lc: $logicalCounter, node: $nodeId)';
}
