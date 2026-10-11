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
- **Exact-Timestamp Collision Fail-Loud Policy:** An HLC tuple identifies a logical write only under the application invariant that each active writer uses a unique ReplicaId and a stateful monotonic HLC source. An identical HLC timestamp across two replicas MUST represent the same logical write. For both `CrdtLwwRegister` and `CrdtOrSet`, merging two states with identical HLC timestamps but divergent payload values is an invariant violation and must fail loudly and symmetrically (`StateError`).
- **Differential Decrement Enforcement & Signed Math:** All coin mutations in `partyPurse` calculate differentials against the underlying signed mathematical value of the PN-counter (`positiveSum - negativeSum`) and record negative decrements (`counter.decrement(delta, replicaId: replicaId)`). Never re-seed counters with positive scalars. Currency non-negativity is a domain/presentation projection clamped at the boundary (`math.max(0, signedValue)`).
- **Fail-Loud CRDT Deserialization:** If a CRDT field (e.g. `activeMinions_crdt`, `activeEncounter_crdt`, map-shaped CRDTs, or counter fields) is present, malformed contents must fail loudly (`FormatException` / `StateError`). Replicas must never silently treat corrupted structures as empty state or fall back to legacy representations. All present counter representations (nested and legacy `*Counter` fields) must be structurally validated before applying precedence.
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

---

## 7. Writer Authority & Clock Trust Invariants (Pass 3.2)
- **One Shared `StatefulHlcClock` Per Runtime Writer:** The runtime generates a single `ReplicaId` per process execution. Exactly ONE `StatefulHlcClock` is constructed for that `ReplicaId` and registered as a singleton in DI (`sl<StatefulHlcClock>()`). All services originating replicated writes (`CombatEncounterService`, `PartyRoomService`, `HomebrewImportOrchestrator`, `RoomSyncOrchestrator`, `LocalCampaignRepository`, `DmDashboardController`) must receive this identical shared clock instance. Services must never construct private clocks when DI is active.
- **Clock Identity & Writer Attribution:** Replicated writes always carry the active runtime `ReplicaId` via `clock.nextTimestamp()`. Historical node IDs in deserialized or loaded state are DATA, not authority; the runtime must never reuse historical timestamps or raw node IDs to stamp active local mutations.
- **Domain Models Do Not Manufacture Timestamps:** Domain models (such as `CampaignProfile`) must NEVER construct active HLCs, call `DateTime.now()`, or accept a raw `nodeId` in mutation methods. Any mutation altering replicated fields (e.g. `copyWith(notesRegister: ...)` or `copyWith(notesMarkdown: ..., notesTimestamp: ...)`) requires an already-stamped register or explicit caller timestamp.
- **Accepted Remote & Loaded Local History Observation:** When remote replicated state is accepted or when local persisted profile state is loaded, relevant timestamps are observed into the shared clock (`clock.observeRemote(...)`). This ensures the next local write is strictly after all causally observed history.
- **Bounded Remote Future Drift & Typed Skew Rejection:** `StatefulHlcClock.observeRemote()` enforces an explicit maximum future drift bound (`maxFutureDrift`, default 1 minute). When an inbound remote physical timestamp exceeds `localPhysicalTime + maxFutureDrift`, the clock rejects the observation by throwing a typed `HlcFutureDriftException(remotePhysicalTime, localPhysicalTime, maxDrift, remoteNodeId)`. The rejected timestamp does NOT mutate `_latest`, leaving the local clock invariant and monotonic.
- **Clock Validation & State Acceptance as a Single Trust Boundary (Pass 3.2.1):** A timestamp rejected by the runtime HLC trust policy must NEVER enter accepted replicated state. Clock validation and state acceptance are one trust decision. Replicas must validate all timestamps before admitting state into memory, reconciling CRDTs, or persisting updates.
- **Atomic Aggregate Observation Closure (Pass 3.2.1):** Inbound remote envelopes (`FullProfileSyncMessage`, `OrSetDeltaSyncMessage`) and loaded persisted records (`LocalCampaignRepository`) atomically validate all candidate HLCs (`validateAllRemote`) before mutating `_latest`. Candidate timestamps are gathered comprehensively via `extractCampaignProfileTimestamps` (extracting notes register, minion set items & tombstones, and encounter participant items & tombstones) and `CrdtOrSet.extractTimestamps()`. If ANY timestamp within an aggregate violates the drift policy, the entire aggregate is rejected atomically without mutating the clock, merging CRDT lattices, or applying side effects.
- **Loaded Persisted State Quarantine Semantics (Pass 3.2.1):** If a persisted campaign profile contains any timestamp violating future drift validation upon startup or reload, `LocalCampaignRepository` quarantines the record into `_rejectedProfileIds`. The record is preserved on disk and retained in the index, but excluded from in-memory cache and query results, preventing clock poisoning from corrupted local storage without causing data loss.
- **Strict Active Writer Constructor Injection:** Active writer service and controller constructors (`CombatEncounterService`, `PartyRoomService`, `HomebrewImportOrchestrator`, `RoomSyncOrchestrator`, `LocalCampaignRepository`, `DmDashboardController`) strictly require `StatefulHlcClock clock` (or resolve `sl<StatefulHlcClock>()`). Private fallback clocks synthesized in production code paths are strictly prohibited.
- **Exact-HLC Collision Policy Remains Fail-Loud:** Exact identical HLC timestamps with divergent logical payloads fail loudly with `StateError` at the primitive layer (`CrdtLwwRegister`, `CrdtOrSet`). Application fault isolation (quarantining offending subresources to prevent dead-lettering unrelated progress) is handled in orchestration (Pass 4), without weakening primitive algebra.

---

## 8. Campaign Persistence & Corrupt Record Durability (Pass 3.2)
- **Parse Failure != Delete:** Deserialization failure of a stored campaign profile must never cause record deletion or index orphaning. `LocalCampaignRepository` isolates malformed profile IDs into `_rejectedProfileIds` and preserves both the raw corrupt payload and its index membership across all loads, unrelated profile saves, index rewrites, and process restarts.
- **Explicit Delete Only:** A malformed record is removed from disk only upon an explicit call to `deleteProfile(id)`.
- **Active Profile Corrupt Record Handling:** If `activeProfileId` points to a corrupted record, the repository selects a healthy fallback profile in memory for current runtime use, but preserves the corrupt record and its index pointer without silently clobbering disk state.
- **Mandatory Production Caller Audit:** Any change to hardened architectural contracts (`StatefulHlcClock`, `CampaignProfile` mutation, repository error handling) requires an exhaustive production caller audit classifying every callsite before completion.

---

## 9. Permanent Birdcage Bars & Hard Invariants (Pass 3.3)
1. **Single Authoritative Writer Clock:** Exactly one authoritative `StatefulHlcClock` instance exists per running application process, created in DI (`lib/infrastructure/di/injection_container.dart`) and injected into active writer services.
2. **Static Source Bar: No Clock Manufacture in Production Code:** Production code under `lib/` must never construct `StatefulHlcClock(` outside `lib/infrastructure/di/` (enforced by `test/infrastructure/compliance/source_bars_test.dart`). Missing clock composition in production paths must fail loudly (`StateError`) rather than synthesizing private fallback clocks.
3. **Static Source Bar: No Literal ReplicaId Synthesis in Production Code:** Production code under `lib/` must never synthesize literal replica IDs (such as `ReplicaId('...')`). Active writes strictly obtain `clock.replicaId`. Enforced by `test/infrastructure/compliance/source_bars_test.dart`.
4. **Untrusted Remote Input Drift Validation:** Inbound remote envelopes (`FullProfileSyncMessage`, `OrSetDeltaSyncMessage`) are strictly untrusted. All incoming timestamps must be validated against `maxFutureDrift` before observation (`validateAllRemote`). If any timestamp exceeds future drift bounds, the envelope is rejected atomically without mutating local clock state.
5. **Trusted Local Persisted History Semantics:** Persisted local storage is trusted history. When loading local campaign profiles, timestamps are observed causally via `observeTrustedHistory` / `observeAllTrustedHistory` without rejecting profiles due to backward local wall-clock shifts or offline dormancy. Structural corruption or malformed payloads remain strictly quarantined.
6. **Corrupt Record Durability:** Corrupt stored records are preserved on disk and retained in indexes; startup or reload never deletes, clobbers, or overwrites malformed records.
7. **Primitive CRDT Algebraic Closure:** Primitive CRDT mathematics (`CrdtLwwRegister`, `CrdtOrSet`, `PnCounter`) in `vtt_engine_core` remain strictly fail-loud on invariant violations (e.g., identical HLC with divergent payload throws `StateError`).
8. **Test Harness Discipline:** Tests must conform to production invariants via explicit test DI or parameter injection (constructing clocks within test files or test helpers). Production code must never weaken its boundaries or maintain fallback crutches to accommodate tests.

---

## 10. Migration-ID vs Active-Writer-ID Policy
- **Historical & Migration Identifiers:** Fixed identifiers such as `'genesis'`, `'init'`, `'migration'`, or deterministic replay node IDs in `fromMap`/deserializers represent read-only historical or migration attribution. They are immutable data artifacts.
- **Active Writer Identifiers:** An active runtime writer must NEVER use fixed migration IDs or synthesize arbitrary replica strings to stamp new live mutations. All active writes originating on a device must strictly use the process's authoritative `ReplicaId` obtained from the runtime's single `StatefulHlcClock` via `clock.nextTimestamp()` (or `clock.replicaId`).

---

## 11. Pass 4 Entry Note: Per-Item Collision Fault Isolation
- **Algebraic Invariance vs Application Isolation:** Primitive CRDT algebra in `vtt_engine_core` strictly enforces fail-loud behavior on identical-timestamp divergent-payload collisions.
- **Application Fault Isolation Scope:** In Pass 4, application orchestration (`RoomStateReconciliationService` and `RoomSyncOrchestrator`) will implement per-item fault isolation. When a collision occurs within a compound or set-based sync envelope, the orchestration layer isolates and quarantines the offending item or sub-resource without dead-lettering the entire envelope or aborting unrelated healthy items. The underlying primitive CRDT layer remains unmodified and algebraically pure.

---

## 12. Provenance Rule & Writer-Clock Identity Consistency (Pass 3.3.1)
- **Provenance-Dependent Timestamp Handling:** Timestamp handling depends strictly on provenance, not timestamp magnitude or value:
  - **Untrusted Remote Input:** Remote envelopes received over network transports are untrusted; all candidate timestamps must be drift-validated against `maxFutureDrift` before observation (`validateAllRemote` / `observeRemote`).
  - **Trusted Local Persisted History:** Records loaded from local storage are trusted; all timestamps are observed causally without drift rejection (`observeAllTrustedHistory`), preserving local durability across offline dormancy or backward local clock corrections.
  - **Accepted In-Memory Replicated State:** Predecessor timestamps extracted from already-accepted local state (e.g., active minions, active encounters, notes registers) represent trusted local history when used to sequence subsequent local mutations. They must be observed causally via `observeTrustedHistory(...)`. A timestamp does not become untrusted remote input again merely because it originally arrived from a peer; once accepted, its causal predecessor is local trusted history.
- **Writer / Clock Identity Consistency Invariant:** Any production class accepting both `ReplicaId` and `StatefulHlcClock` (`CombatEncounterService`, `RoomSyncOrchestrator`, `LocalCampaignRepository`, `DmDashboardController`, `PartyRoomService`, `HomebrewImportOrchestrator`) must enforce at construction time:
  ```dart
  clock.replicaId == replicaId
  ```
  If they diverge, the constructor must fail loudly immediately by throwing `ArgumentError`. No service may attribute HLC writes to one writer while attributing PN-counter or domain operations to another.

---

## 13. Aggregate Replicated-State Convergence & Deterministic Join Semantics (Pass 4.0)

### 13.1 Canonical Aggregate Join Owner
- **Domain/Engine Location:** Canonical aggregate joins reside in `package:vtt_engine_core`:
  - `CampaignProfile.join(CampaignProfile a, CampaignProfile b)`
  - `RoomNodeState.join(RoomNodeState a, RoomNodeState b)`
- **Mathematical Invariants:** For any valid pair of independently evolved states $A$, $B$, and $C$:
  - **Idempotence:** `join(A, A) == A`
  - **Commutativity:** `join(A, B) == join(B, A)`
  - **Associativity:** `join(join(A, B), C) == join(A, join(B, C))`
- **Pure Join Invariants:**
  - Zero I/O, zero `DateTime.now()`, zero `StatefulHlcClock`, zero `ReplicaId`, zero service locator or repository writes.
  - Direction independence: `join(a, b)` produces identical results regardless of which argument is named "local" or "remote".
  - Input immutability: neither input profile, nested collection, nor CRDT payload is mutated during join.

### 13.2 RoomNodeState Merge Policy Table (Pass 4.1)
| Field | Replicated? | Type | Merge Rule | Deletion Rule | Conflict Behavior | Legacy Behavior | Equality Checked? | Test Coverage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `roomId` | Yes | `String` | Immutable ID (`joinImmutableId`) | N/A | Divergence throws `StateError` (isolated at app layer) | Empty string takes non-empty string | Yes (`==`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |
| `roomCode` | Yes | `String` | Immutable ID (`joinImmutableId`) | N/A | Divergence throws `StateError` (isolated at app layer) | Empty string takes non-empty string | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `title` | Yes | `String` | Unversioned scalar (`joinUnversionedString`) | N/A | Divergence throws `StateError` (isolated at app layer) | Empty takes non-empty | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `description` | Yes | `String` | Unversioned scalar (`joinUnversionedString`) | N/A | Divergence throws `StateError` (isolated at app layer) | Empty takes non-empty | Yes (`==`) | `campaign_profile_test.dart`, `aggregate_join_laws_test.dart` |
| `entityLinks` | Yes | `CrdtOrSet<RoomEntityLink>` | CRDT OR-set merge (`joinEntityLinks`) | Tombstoned remove (`unbindEntityFromRoom`), Add-wins | Exact-HLC collision throws `StateError` | List batch-added with genesis HLC | Yes (`entityLinksCrdt == other.entityLinksCrdt`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |
| `entityInstances` | Yes | `List<EntityInstance>` | Grow-only map-by-instanceId recursion (`joinEntityInstances`) | Grow-only (no application removal in Pass 4) | Field-level divergence throws `StateError` | Deserialized from List | Yes (`_deepEquality`) | `campaign_profile_test.dart`, `aggregate_join_laws_test.dart` |
| `containers` | Yes | `List<LootContainer>` | Grow-only map-by-containerId recursion (`joinContainers`) | Grow-only (no application removal in Pass 4) | Field-level divergence throws `StateError` | Deserialized from List | Yes (`_deepEquality`) | `aggregate_join_laws_test.dart` |
| `activeEncounter` | Yes | `CrdtOrSet<EncounterParticipant>` | CRDT OR-set merge | Tombstoned remove, Add-wins | Exact-HLC collision throws `StateError` | List batch-added with genesis HLC | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `activeMinions` | Yes | `CrdtOrSet<dynamic>` | CRDT OR-set merge | Tombstoned remove, Add-wins | Exact-HLC collision throws `StateError` | List batch-added with genesis HLC | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `customProperties` | Yes | `Map<String, dynamic>` | Per-key map join (`joinCustomProperties`) | N/A | Disjoint keys union; same key + deep equality preserved; divergent value throws `StateError` | Deserialized from Map | Yes (`_deepEquality`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |

### 13.3 CampaignProfile Merge Policy Table (Pass 4.1)
| Field | Replicated? | Type | Merge Rule | Deletion Rule | Conflict Behavior | Legacy Behavior | Equality Checked? | Test Coverage |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `id` | Yes | `String` | Immutable ID (`joinImmutableId`) | N/A | Divergence throws `StateError` | Fallback default id | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `name` | Yes | `String` | Unversioned scalar (`joinUnversionedString`) | N/A | Divergence throws `StateError` (isolated at app layer) | Empty takes non-empty | Yes (`==`) | `aggregate_join_laws_test.dart` |
| `edition` | Yes | `dynamic` / `RulesetIdentifier` | Schema identity (`a.rulesetId == b.rulesetId`), canonicalizes to stable `RulesetIdentifier` if runtime forms differ | N/A | Differing `rulesetId` throws `StateError` | String or enum mapped to rulesetId | Yes (`rulesetId == other.rulesetId`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |
| `createdAt` | Yes | `DateTime` | Causal minimum (`a.isBefore(b) ? a : b`) | N/A | Deterministic min | Default now | Yes (`createdAt.isAtSameMomentAs(other.createdAt)`) | `campaign_profile_test.dart` |
| `lastPlayedAt` | Yes | `DateTime` | Derived/metadata max (`a.isAfter(b) ? a : b`) | N/A | Deterministic max | Default createdAt | Yes (`lastPlayedAt.isAtSameMomentAs(other.lastPlayedAt)`) | `campaign_profile_test.dart` |
| `roomState` | Yes | `RoomNodeState` | Recursive aggregate join (`RoomNodeState.join(a.roomState, b.roomState)`) | See RoomNodeState table | Delegates to roomState join | Default empty RoomNodeState | Yes (`roomState == other.roomState`) | `aggregate_join_laws_test.dart` |
| `partyCharacterIds` | Yes | `List<String>` | Union minus removals tracked by typed `PartyEvent.entityId` in changelog (`joinPartyRoster`) | Authoritative typed `characterRemove` / `playerLeave` events with `entityId` | Removal in changelog removes ID; deterministic sorted list | Deduplicated union | Yes (`_listStringEquality`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |
| `pinnedRules` | Yes | `CrdtOrSet<String>` | Canonical CRDT OR-set merge (`joinPinnedRules`) | Tombstoned remove (`pinnedRules.remove`), Add-wins | Exact-HLC collision throws `StateError` | `pinnedRuleIds` Set batch-added with genesis HLC | Yes (`pinnedRules == other.pinnedRules`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |
| `notesRegister` | Yes | `CrdtLwwRegister<String>` | CRDT LWW register merge | Empty string overwrite via newer HLC | Later HLC wins; exact-HLC collision throws `StateError` | Markdown wrapped at genesis HLC | Yes (`notesRegister == other.notesRegister`) | `aggregate_join_laws_test.dart` |
| `partyPurse` | Yes | `PartyPurse` | CRDT PN-counters lattice join across denominations | Signed decrements on PN-counters | Monotonic join of positive and negative vectors | Default empty purse | Yes (`partyPurse == other.partyPurse`) | `aggregate_join_laws_test.dart` |
| `changeLog` | Yes | `List<PartyEvent>` | Deduplicated by event ID, sorted by timestamp & ID (`joinChangeLog`) | Append-only event history | Divergent payload under same event ID throws `StateError` | Fallback default events | Yes (`_listEventEquality`) | `aggregate_join_laws_test.dart`, `aggregate_convergence_pass_4_1_test.dart` |

### 13.4 Narrow Per-Subresource Fault Isolation at Application Layer
- Application-level reconciliation (`RoomStateReconciliationService.reconcileProfileSafely`) delegates each subresource join directly to canonical engine helpers (`joinChangeLog`, `joinPartyRoster`, `joinPinnedRules`, `joinCustomProperties`, `joinEntityLinks`, `joinEntityInstances`, `joinContainers`).
- Sub-resources are joined independently within isolated try-catch blocks.
- If an invalid collision occurs in one subresource (e.g. an exact-HLC divergent payload in `activeMinions` or divergent unversioned custom property), only that offending subresource is isolated (retaining the local value) and recorded as a typed `ReconciliationFieldFault`, while all unrelated healthy sub-resources (`notes`, `partyPurse`, `changeLog`) continue to merge safely without loss of progress.
- Safe reconciliation never mints new synthetic replicated `PartyEvent`s during merge, and never consults wall/network clock for merged state.
- `RoomSyncOrchestrator` routes isolated field faults to `deadLetterStream` for telemetry and alerting.
- Pure aggregate join in `vtt_engine_core` remains total and fail-loud for invalid states without operational compromises.

---

## 14. Authoritative vs Derived Fields (Pass 4.1.1)

Replicated aggregate entities distinguish between **authoritative replicated CRDT state** and **derived read-only convenience views**:

### 14.1 CampaignProfile
- **Authoritative:** `pinnedRules` (`CrdtOrSet<String>`). Stores full causal history (item registers with HLCs, tombstones with HLCs). Active production mutations MUST target `pinnedRules` using authoritative HLC-stamped `add(...)` and `remove(...)` operations.
- **Derived View:** `pinnedRuleIds` (`Set<String>`). Read-only derived active values view (`pinnedRules.activeValues.toSet()`). Calling `copyWith(pinnedRuleIds: ...)` in active production code is strictly forbidden (enforced by permanent architectural Source Bar F), as it destroys tombstones and causal history.
- **Migration Only:** Legacy list/set forms in DTOs (`pinnedRuleIds`) are accepted solely as backward-compatibility migration inputs when the authoritative `pinnedRules_crdt` key is absent from the wire/disk record.

### 14.2 RoomNodeState
- **Authoritative:** `entityLinksCrdt` (`CrdtOrSet<RoomEntityLink>`). Stores full causal history of room entity links, item HLCs, and tombstones. Active production binding/unbinding mutations MUST operate on `entityLinksCrdt` using authoritative HLCs.
- **Derived View:** `entityLinks` (`List<RoomEntityLink>`). Read-only derived view of active links (`entityLinksCrdt.activeValues.toList()`).

---

## 15. Aggregate HLC Trust & Timestamp Extraction (Pass 4.1.1)

All HLC-bearing replicated fields participate in the Pass-3 causality, trust, and future-drift validation machinery:

### 15.1 Replicated Fields in Aggregate Extraction
Aggregate timestamp extraction (`extractCampaignProfileTimestamps`, `extractRoomNodeTimestamps`) extracts every HLC across all CRDT fields:
1. `notesRegister.timestamp`
2. `partyRoster` (active item HLCs and tombstones via `partyRoster.extractTimestamps()`)
3. `pinnedRules` (active item HLCs and tombstones via `pinnedRules.extractTimestamps()`)
4. `roomState.entityLinksCrdt` (active item HLCs and tombstones via `entityLinksCrdt.extractTimestamps()`)
5. `roomState.activeMinions` (active item HLCs and tombstones via `activeMinions.extractTimestamps()`)
6. `roomState.activeEncounter` (active item HLCs and tombstones via `activeEncounter.extractTimestamps()`)

**Definition of Done Mandate:** Any future HLC-bearing replicated field added to `CampaignProfile` or `RoomNodeState` MUST be added to aggregate timestamp extraction in the same schema change commit. No HLC-bearing replicated field may remain outside aggregate timestamp extraction.

### 15.2 Inbound Remote Drift vs Trusted Local History
- **Inbound Remote Validation:** Remote frames containing any HLC exceeding the local clock by more than `maxFutureDrift` (1 minute, matching `StatefulHlcClock.defaultMaxFutureDrift`) in any extracted field (item or tombstone) reject the entire aggregate before reconciliation, advance no local clocks, and route to `deadLetterStream` as `HlcFutureDriftException`.
- **Trusted Local History Observation:** Persisted/accepted local state is trusted; when loaded from storage or accepted from authoritative history, all timestamps (even if historically ahead of local physical time) are observed into `StatefulHlcClock.observeAllTrustedHistory()` without future-drift quarantine, ensuring local clocks tick forward strictly monotonically beyond historical causality.

---

## 16. Production Deletion & Membership Authoring Policies (Pass 4.1.1 / Pass 4.1.2)

No deletion or membership semantics may exist only in merge code without a production writer. Active mutations must author explicit replicated CRDT facts:

- **Pinned Rule Removal:** Unpinning a rule (`DmDashboardController.togglePinnedRule`) authors a direct CRDT tombstone via `pinnedRules.remove(ruleId, timestamp: clock.nextTimestamp())`.
- **Entity Link Removal:** Unbinding an entity link authors a direct CRDT tombstone in `entityLinksCrdt` via `unbindEntityFromRoom(entityId, clock: clock)`.
- **Roster Membership (Pass 4.1.2):** Campaign roster causal authority belongs exclusively to `CrdtOrSet<String> partyRoster`.
  - **Add Character:** Authors `partyRoster.add(characterId, characterId, clock.nextTimestamp())`.
  - **Remove Character:** Authors `partyRoster.remove(characterId, clock.nextTimestamp())`.
  - **Re-add Character:** Authors a new add with a later HLC, cleanly superseding prior tombstones across all replicas.
  - **Audit vs Causality:** `PartyEvent` records (e.g. `type: 'characterRemove'`, `type: 'playerLeave'`) are strictly audit history. Aggregate join (`CampaignProfile.join`, `RoomStateReconciliationService`) derives membership solely from the OR-set lattice merge (`joinPartyRosterCrdt`).
  - **Derived View:** `partyCharacterIds` is an unmodifiable, sorted projection of `partyRoster.activeValues`. Direct mutation via `CampaignProfile.copyWith(partyCharacterIds: ...)` is permanently banned in production code (Source Bar G).

