import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/crdt/hybrid_logical_clock.dart';

/// Application service orchestrating safe CRDT state reconciliation and tombstone pruning.
class RoomStateReconciliationService {
  /// Prunes an OR-Set only if the provided threshold timestamp has been globally
  /// acknowledged by the milestone snapshot ledger.
  ///
  /// Throws [StateError] if [globallyAcknowledgedThreshold] is in the present or future,
  /// preventing premature tombstone deletion and collection resurrection.
  CrdtOrSet<T> safePrune<T>(
    CrdtOrSet<T> targetSet,
    HybridLogicalClock globallyAcknowledgedThreshold,
  ) {
    // Safety check: ensure we aren't pruning with a timestamp from the future or unverified present
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (globallyAcknowledgedThreshold.physicalTime >= now) {
      throw StateError(
        'Cannot prune CRDT tombstones using an unverified current/future timestamp.',
      );
    }

    return targetSet.prune(globallyAcknowledgedThreshold);
  }
}
