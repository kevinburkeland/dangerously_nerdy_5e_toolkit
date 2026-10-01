# Application Distributed State & Transport Directives

This document details the application-level synchronization services, transport waterfall, and state reconciliation rules connecting local persistence with peer-to-peer and cloud networks.

## 1. Architectural Ownership
- **Agnostic CRDT Mathematics (`vtt_engine_core`):** Pure CRDT primitives (`HybridLogicalClock`, `CrdtOrSet`, `PnCounter`, `CrdtLwwRegister`) and transport port contracts (`IP2pTransportPort`, `TransportState`) reside in `vtt_engine_core`.
- **Application Coordination (Toolkit):** Multi-device synchronization orchestration (`RoomSyncOrchestrator`), transport cascading (`CascadingTransportRouter`), and room state reconciliation (`RoomStateReconciliationService`) reside in `lib/application/services/`.

---

## 2. Core Convergence & Correctness Invariants
- **CvRDT Convergence:** Replicated state must converge deterministically across all nodes under supported join-semilattice merge operations ($A \sqcup B = B \sqcup A$ and $A \sqcup A = A$).
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
