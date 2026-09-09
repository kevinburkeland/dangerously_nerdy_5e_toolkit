# CvRDT & Distributed State Directives

This project uses Convergent Replicated Data Types (CvRDTs) backed by Hybrid Logical Clocks (HLC) to power real-time, peer-to-peer and cloud campaign synchronization without data loss or race conditions.

## 1. Hybrid Logical Clock (HLC) Specifications

Located at `lib/domain/crdt/hybrid_logical_clock.dart`:
- **Structure:** Combines physical millisecond timestamp (`l`), logical counter (`c`), and unique node identifier (`nodeId`).
- **Comparable & Deterministic:**
  - Order priority: `l` (timestamp) first, then `c` (counter) if timestamps are equal.
  - **Tie-breaker:** If both `l` and `c` are identical across competing updates, `nodeId` (device ID string) is used as the strict lexicographical tie-breaker (`nodeId.compareTo(other.nodeId)`).
  - **Rule:** Never use random values or non-deterministic tie-breakers.

## 2. Register Primitives (LWW Register)

Located at `lib/domain/crdt/crdt_lww_register.dart`:
- Last-Write-Wins (LWW) Register stores a value paired with an HLC timestamp.
- **Deep Immutability:** Updating the register via `set(newValue, newTimestamp)` or merging two registers via `merge(other)` MUST return a new instance. Never mutate registers in place.
- **DTO:** `lib/infrastructure/dtos/crdt/crdt_lww_register_dto.dart` maps to/from JSON with robust null safety and fallback defaults.

## 3. Collection Primitives (Observed-Remove Set)

Located at `lib/domain/crdt/crdt_or_set.dart`:
- Used for synchronized collections (e.g., active room minions, inventory items, characters).
- **Tombstones:** Deleting an element adds a tombstone record with an HLC timestamp rather than physically removing the entry immediately.
- **Tombstone Pruning:**
  - Infinite tombstone growth causes memory leaks and ballooning network payloads.
  - Every `CrdtOrSet` MUST implement a `prune(HybridLogicalClock threshold)` method to purge tombstones older than the specified synchronization horizon.
- **Querying Active Elements:** `.elements` returns only entries whose addition timestamp is strictly greater than their tombstone deletion timestamp.

## 4. State Reconciliation & Snapshot Checkpoints

Located at `lib/application/services/room_state_reconciliation_service.dart`:
- Event logs grow unbounded over time.
- **Delta Fast-Forward Pattern:** Clients receive incremental state deltas. To derive current room state, the client takes the last stable milestone snapshot and applies incoming CRDT deltas on top using deterministic `merge()` logic.
- **Fault-Tolerant Serialization:** All CRDT DTOs in `lib/infrastructure/dtos/crdt/` must gracefully handle missing keys, malformed timestamps, or unexpected types without throwing uncaught exceptions.
