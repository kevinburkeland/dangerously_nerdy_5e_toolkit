import 'package:meta/meta.dart';
import 'crdt_lww_register.dart';
import 'hybrid_logical_clock.dart';

/// Observed-Remove Set (OR-Set) with explicit Tombstone tracking.
/// Provides deterministic reconciliation for collections (e.g., active conditions,
/// minion rosters) and prevents resurrection of deleted items across distributed nodes.
@immutable
class CrdtOrSet<T> {
  /// Maps item ID to the Register containing the item and its insertion timestamp.
  final Map<String, CrdtLwwRegister<T>> items;

  /// Maps item ID to the HLC timestamp of when it was removed.
  final Map<String, HybridLogicalClock> tombstones;

  const CrdtOrSet({
    this.items = const {},
    this.tombstones = const {},
  });

  /// Returns the current list of active (non-tombstoned) values.
  List<T> get activeValues => items.values.map((r) => r.value).toList();

  /// Adds or updates an item with the given [id] and [timestamp].
  /// If a tombstone exists for [id] that is newer than [timestamp], the addition is rejected.
  CrdtOrSet<T> add(String id, T item, HybridLogicalClock timestamp) {
    final newItems = Map<String, CrdtLwwRegister<T>>.from(items);
    final newTombstones = Map<String, HybridLogicalClock>.from(tombstones);

    // Only add if we don't have a newer or equal tombstone for this item
    if (!newTombstones.containsKey(id) || timestamp.isAfter(newTombstones[id]!)) {
      newItems[id] = CrdtLwwRegister(value: item, timestamp: timestamp);
      newTombstones.remove(id);
    }

    return CrdtOrSet(items: newItems, tombstones: newTombstones);
  }

  /// Removes an item with the given [id] at [timestamp], recording a tombstone.
  /// Only succeeds if the timestamp is newer than the item's insertion timestamp.
  CrdtOrSet<T> remove(String id, HybridLogicalClock timestamp) {
    final newItems = Map<String, CrdtLwwRegister<T>>.from(items);
    final newTombstones = Map<String, HybridLogicalClock>.from(tombstones);

    final currentItem = newItems[id];
    if (currentItem != null && timestamp.isAfter(currentItem.timestamp)) {
      newItems.remove(id);
      newTombstones[id] = timestamp;
    }

    return CrdtOrSet(items: newItems, tombstones: newTombstones);
  }

  /// Merges this OR-Set with a [remote] OR-Set deterministically.
  CrdtOrSet<T> merge(CrdtOrSet<T> remote) {
    final mergedItems = Map<String, CrdtLwwRegister<T>>.from(items);
    final mergedTombstones = Map<String, HybridLogicalClock>.from(tombstones);

    // Merge tombstones
    remote.tombstones.forEach((id, remoteTs) {
      final localTs = mergedTombstones[id];
      final localItem = mergedItems[id];

      // If local item is strictly newer than the remote tombstone,
      // the tombstone is obsolete (the item was revived) and must not be added.
      if (localItem != null && localItem.timestamp.isAfter(remoteTs)) {
        return;
      }

      if (localTs == null || remoteTs.isAfter(localTs)) {
        mergedTombstones[id] = remoteTs;
        // If remote tombstone is newer than our item, delete our item
        if (localItem != null && remoteTs.isAfter(localItem.timestamp)) {
          mergedItems.remove(id);
        }
      }
    });

    // Merge items
    remote.items.forEach((id, remoteReg) {
      final localTombstone = mergedTombstones[id];
      // Only merge if the item is newer than the local tombstone
      if (localTombstone == null || remoteReg.timestamp.isAfter(localTombstone)) {
        final localReg = mergedItems[id];
        if (localReg == null || remoteReg.timestamp.isAfter(localReg.timestamp)) {
          mergedItems[id] = remoteReg;
          mergedTombstones.remove(id);
        }
      }
    });

    return CrdtOrSet(items: mergedItems, tombstones: mergedTombstones);
  }

  /// Garbage-collects tombstones with timestamps older than [threshold] HLC.
  CrdtOrSet<T> pruneTombstones(HybridLogicalClock threshold) {
    final prunedTombstones = Map<String, HybridLogicalClock>.from(tombstones)
      ..removeWhere((_, ts) => ts.isBefore(threshold));

    return CrdtOrSet(items: items, tombstones: prunedTombstones);
  }

  /// Alias for [pruneTombstones] conforming to DATA_SAFETY_AND_CRDT.md directives.
  CrdtOrSet<T> prune(HybridLogicalClock threshold) => pruneTombstones(threshold);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrdtOrSet<T> &&
          runtimeType == other.runtimeType &&
          _mapsEqual(items, other.items) &&
          _mapsEqual(tombstones, other.tombstones);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(
          items.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(
          tombstones.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _mapsEqual<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'CrdtOrSet(items: ${items.length}, tombstones: ${tombstones.length})';
}
