# Application Distributed State & Transport Directives

This document details the application-level synchronization services, transport waterfall, and state reconciliation rules connecting local persistence with peer-to-peer and cloud networks.

## 1. Architectural Ownership
- **Agnostic CRDT Mathematics (`vtt_engine_core`):** Pure CRDT primitives (`HybridLogicalClock`, `CrdtOrSet`, `PnCounter`, `CrdtLwwRegister`) and transport port contracts (`IP2pTransportPort`, `TransportState`) reside in `vtt_engine_core`.
- **Application Coordination (Toolkit):** Multi-device synchronization orchestration (`RoomSyncOrchestrator`), transport cascading (`CascadingTransportRouter`), and room state reconciliation (`RoomStateReconciliationService`) reside in `lib/application/services/`.

---

## 2. Core Convergence & Correctness Invariants
- **CvRDT Convergence:** Replicated state must converge deterministically across all nodes under supported join-semilattice merge operations ($A \sqcup B = B \sqcup A$, $(A \sqcup B) \sqcup C = A \sqcup (B \sqcup C)$, and $A \sqcup A = A$).
- **Mathematically Signed PN-Counters & Monotonic Vectors:** A PN-counter's mathematical value is signed: `positiveSum - negativeSum`. Individual vector component totals are monotonically non-negative ($\ge 0$); direct construction or deserialization with negative or fractional component totals fails loudly (`ArgumentError` / `FormatException`). Currency non-negativity is a domain/presentation concern clamped at the `PartyPurse` or UI boundary (`math.max(0, counter.value)`), while mutations (e.g. `setDenomination`) calculate differentials against the underlying signed value to safely satisfy targets even in the presence of hidden negative debt.
- **Authoritative Counter Migration & Fail-Loud Parsing:** Redundant legacy scalar fields in serialized purse payloads are compatibility/display data; when an authoritative PN-counter exists for a denomination, the counter is strictly authoritative and redundant scalars must never synthesize new pseudo-writer mutations (e.g. "cloud" repair writes). If an authoritative counter field exists and is malformed, deserialization must fail loudly rather than falling back silently to redundant scalar fields.
- **Active Writer Monotonicity & HLC Authority:** ReplicaId uniqueness alone does NOT guarantee HLC uniqueness. An active writer runtime must maintain monotonic state (`StatefulHlcClock`), ticking causality forward even across identical milliseconds or backward wall-clock shifts. `HybridLogicalClock.now()` is an initial clock constructor, not a per-write timestamp API.
- **Deterministic Reconstruction Invariant:** Reconstructing serialized historical state (`fromMap`) must NEVER consult the current wall clock (`DateTime.now()`). Legacy list conversions use deterministic migration timestamps (`physicalTime: 0, logicalCounter: 0, nodeId: "genesis"`). Duplicate IDs in legacy lists with divergent payloads fail loudly with `StateError`.
- **Structural CRDT Payload Equivalence:** Generic CRDT primitives (`CrdtLwwRegister`, `CrdtOrSet`) enforce deep structural equality (`DeepCollectionEquality`) across JSON-like payloads (`Map`, `List`, `Set`). Map key insertion order is irrelevant. Equal payloads compare equal and yield identical hash codes; exact identical HLC timestamps with divergent logical payloads represent invalid state and fail loudly and symmetrically.
- **Explicit Add-Wins & Canonical OR-Set State:** When an item addition and tombstone share identical exact HLC timestamps, the item addition wins (`item timestamp >= tombstone timestamp`). Contradictory serialized state where an ID exists in both items and tombstones must be canonicalized immediately upon construction and deserialization (`fromMap`). Stale local additions older than an existing item's timestamp do not overwrite newer items.
- **Deterministic HLC Deserialization:** Serialized replicated timestamps must never depend on wall-clock time during reconstruction. If `physicalTime` (`pt`) is missing, fractional, or malformed, deserialization fails loudly (`FormatException`) rather than silently substituting `DateTime.now()`.
- **Exact-Timestamp Collision Fail-Loud Policy:** Because an HLC uniquely identifies a logical write via cryptographic writer identity, an identical HLC timestamp across two replicas MUST represent the same logical write. For both `CrdtLwwRegister` and `CrdtOrSet`, merging two states with identical HLC timestamps but divergent payload values is an invariant violation and must fail loudly and symmetrically (`StateError`).
- **Differential Decrement Enforcement:** All coin reductions in `partyPurse` MUST calculate the delta against `effectiveCounter` and record negative decrements (`counter.decrement(nodeId, delta)`). Never re-seed counters with positive scalars via `PnCounter.withInitialValue()`.
- **Causal Tombstone Retention:** OR-Set tombstones must NOT be pruned based solely on wall-clock time, network time, heartbeat horizons, or milestone timestamps. Elapsed time does not prove causal acknowledgement by offline replicas. Tombstones are retained indefinitely to prevent deleted state from resurrecting when an offline replica reconnects. Causal compaction requires protocol-level stability proofs (such as version vectors), not elapsed time.
- **Local Persistence Authority:** Local persistence (Hive / IndexedDB) is the single source of truth. Remote mesh and cloud sync operate via CvRDT lattice merge before disk write; direct remote overwrites are prohibited.
- **Narrow Mutex Critical Section:** `RoomSyncOrchestrator` uses `_syncMutex.protect()` strictly for in-memory CRDT joins and profile reconciliation. Disk persistence (`saveProfileImmediate`) executes asynchronously *outside* the mutex lock to prevent lock contention and re-entrant deadlocks.
- **Deadlock Immunity via Asynchronous Microtasks:** Reactive broadcast `StreamController`s across persistence repositories and transport services MUST specify `sync: false`. Inbound transport payloads must be dispatched asynchronously via `scheduleMicrotask()`.

---

## 3. Deliberate Application Protocol Policies
- **Sub-Resource Merging Over Full-Document Overwrite:** Inbound `room_sync_full` payloads merge sub-resources independently via `reconcileProfile()` (notes via LWW, currency via PN-Counter, minions keyed by `m.id`, encounters keyed by `participantId`, change logs) rather than replacing the entire `CampaignProfile`.
- **`crdt_purse_delta` Protocol:** Routine currency modifications broadcast lightweight `crdt_purse_delta` packets, merging directly into the local profile via `RoomSyncOrchestrator._handleIncomingPurseDelta` without requiring full document broadcasts.
- **Vault Dispersal Wealth Conservation:** Dispersing coins from the shared party vault reserve (`isVaultDispersal: true`) withdraws shares from `partyPurse` via `withdrawCoins(...)`, strictly conserving total party wealth without currency inflation.
- **4-Tier Transport Waterfall & Dynamic Step-Up:**
  1. Tier 1: Local Wi-Fi (`LocalWifiAdapter`)
  2. Tier 2: WebRTC P2P Mesh (`WebRtcMeshAdapter`)
  3. Tier 3: Firebase Cloud Relay (`FirebaseFallbackAdapter`)
  4. Tier 4: Offline Mode
  When operating on Tier 3 or 4, the router periodically probes higher-tier viability (`probeHigherTiers()`) via `IP2pTransportPort.probeViability()`, stepping back up to WebRTC mesh when available.
- **W3C Polite Peer Glare Rollback:** On crossing offers (`have-local-offer` when receiving an inbound remote offer), collisions resolve using deterministic lexicographical node ID comparison (`localNodeId.compareTo(peerId)`). The polite peer rolls back its local offer (`RTCSessionDescription('', 'rollback')`) and accepts the incoming offer.
- **Stateless Room Stub Rehydration & 30-Day Lease:** Whenever a participant connects (host init, player join, or screen mount), touch `/rooms/{roomCode}` with `isStateless: true` and reset the 30-day lease (`expiresAt: now + 30 days`) via `SetOptions(merge: true)`. Confirmed non-existent rooms without active presence reject cleanly without phantom record creation.

---

## 4. Current Implementation Notes (Operational Parameters)
- **Sliding Lookback Window & LRU Deduplication:** Inbound transport frames enforce a 30-second sliding lookback window (`inboundTimestamp >= localTime - 30000`) and a 500-entry `LinkedHashMap<String, bool>` SHA-256 LRU cache. Malformed or unrecognized payloads (`UnknownSyncMessage`) are discarded before updating the LRU cache.
- **Clock Skew Compensation:** `ClockSyncService` calculates physical time skew (`offsetMs = networkTime - localTime`) and injects it into outbound broadcast timestamps.
- **Echo Loop Suppression:** Outbound frames are stamped with monotonic sequence numbers and originating node IDs. Outbound sync is skipped if the profile matches `_lastInboundProfile` or if the mutex is locked. Reconstructed entities implement value-based `operator ==` and `hashCode`.
- **Ephemeral Signaling Cleanup:** Handshake documents in Firestore are partitioned by peer ID (`cleanUpPeerSignaling(peerId)`) and triggered only after the DataChannel reaches `RTCDataChannelState.RTCDataChannelOpen` or ICE reaches `completed`.
- **Transient ICE Resilience:** Peer connections are pruned strictly on `RTCIceConnectionStateFailed`. Pruning is avoided during transient `RTCIceConnectionStateDisconnected`.

---

## 5. CRDT Structural Immutability vs Transitive Payload Immutability
- **CRDT Structural Immutability:** Generic CRDT primitives (`CrdtOrSet<T>`, `CrdtLwwRegister<T>`, `PnCounter`) enforce structural immutability of the container itself; elements, registers, and tombstones cannot be mutated in place, and operations produce new unmodifiable containers.
- **Transitive Payload Immutability:** Generic CRDTs do not clone arbitrary payload objects of type `T`. It is not sufficient for the immediate CRDT wrapper or immediate parent object to be immutable if a child value still retains mutable aliases. A value already incorporated into replicated state must not be logically alterable through any caller-owned mutable collection reachable through that value graph.
- **Boundary Responsibility:** Concrete replicated payload models (`MinionInstance`, `RoomNodeState`, `EntityReference`, `InventoryItemInstance`, `LootContainer`) and ingestion/deserialization boundaries (`RoomNodeState.fromMap`, `RoomNodeState.fromLists`, `RoomNodeState.copyWith`) must deeply defensively freeze nested collections (`deepFreezeMap`, `deepFreezeList`, `deepFreezeSet`, `deepFreezeValue`) before CRDT stamping. Raw mutable collections or un-frozen JSON maps must never enter replicated state graphs.

---

## 6. Transitive Immutability vs Value Equality
- **Separate Invariants:** "Transitive immutability and value equality are separate invariants." An object may be impossible to mutate through aliases and still be incorrect for replicated state if equality/hash ignore logical fields or compare nested collections by identity.
- **Replicated Value Object Contracts:** Replicated value objects must satisfy:
  1. `same logical serialized value -> equal`
  2. `equal -> same hashCode`
  3. `logical replicated change -> observable inequality where equality participates in synchronization/change detection`
- **Structural Semantics:** Replicated objects bearing nested JSON-like metadata maps or lists (`customProperties`, `runtimeData`, `normalizedData`, `rawPayload`, `unparsedPayload`, `grantedSkills`) must utilize recursive deep structural equality (`DeepCollectionEquality`) in both `operator ==` and `hashCode`. Map entry insertion order must not alter equality or hash, whereas list item order remains significant.
- **Key Integrity Invariant:** `deepFreezeMap` enforces that nested map keys MUST be `String`. Non-string keys fail loudly with `ArgumentError`; keys are never silently stringified, dropped, or collapsed.
