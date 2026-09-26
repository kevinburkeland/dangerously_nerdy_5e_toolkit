# Data Safety & CRDT Implementation Rules

When implementing network synchronization, offline capabilities, or multi-user features, adhere to these constraints:

## 1. Tombstone Pruning
Collections (like active room minions) use an Observed-Remove Set (`CrdtOrSet`). Deleting an item requires leaving a Tombstone. 
- **Rule:** The AI must always implement a `prune(HybridLogicalClock threshold)` method to prevent memory leaks from infinite tombstone accumulation.

## 2. Deterministic Tie-Breaking
When two offline devices mutate the same field at the exact same physical millisecond:
- **Rule:** `HybridLogicalClock` must implement `Comparable` and use the `nodeId` (Device ID string) as a lexicographical tie-breaker. Random tie-breakers are strictly forbidden.

## 3. Immutability in State Reconciliation
Dart lacks deep immutability by default.
- **Rule:** CRDT wrappers must never expose direct references to mutable lists or maps. Mutations must occur via `.set(newValue, newTimestamp)` or `.add(newItem, newTimestamp)` which return a completely new instance of the CRDT wrapper.

## 4. Snapshot Checkpoints (Delta Fast-Forward)
Event-sourced logs become too large to parse over time.
- **Rule:** Network payloads represent incremental deltas. Full room state is derived by grabbing the last milestone JSON snapshot and applying the deltas on top using CRDT `merge()` logic.