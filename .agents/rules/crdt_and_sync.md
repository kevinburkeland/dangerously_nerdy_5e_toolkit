# Application Distributed State & Transport Directives

This document details the application-level synchronization services, transport waterfall, and state reconciliation rules connecting local persistence with peer-to-peer and cloud networks.

## 1. Application State Reconciliation
Located at `lib/application/services/room_state_reconciliation_service.dart`:
- **Sub-Resource Merging Over Full-Document Overwrite:** Inbound `room_sync_full` payloads merge sub-resources independently via `reconcileProfile()` (notes via LWW, currency via PN-Counter, minions keyed by `m.id`, encounters keyed by `participantId`, change logs).
- **Authoritative Milestone Pruning:** Pruning must be decoupled from unverified local clocks. Pruning thresholds are anchored to authoritative server/ledger snapshot timestamps via `executeMilestonePrune`. When extreme clock drift causes `threshold >= networkTime`, pruning is deferred gracefully via `safePrune`.
- **Clock Skew Compensation:** `ClockSyncService` calculates physical time skew (`offsetMs = networkTime - localTime`) and injects it into outbound broadcast timestamps.

## 2. Currency Convergence & crdt_purse_delta Protocol
Located at `lib/models/party/party_purse.dart` and `lib/application/services/room_sync_orchestrator.dart`:
- **Differential Decrement Enforcement:** All coin reductions MUST calculate delta against `effectiveCounter` and record negative decrements (`counter.decrement(nodeId, delta)`). Never re-seed counters with positive scalars via `PnCounter.withInitialValue()`.
- **Focused Delta Protocol:** Routine currency modifications broadcast lightweight `crdt_purse_delta` packets, merging directly into the local profile via `RoomSyncOrchestrator._handleIncomingPurseDelta` without full document dumps.
- **Vault Dispersal Wealth Conservation:** Dispersing coins from the party vault reserve (`isVaultDispersal: true`) withdraws shares from `partyPurse` via `withdrawCoins(...)`, strictly conserving total party wealth.

## 3. Concurrency Mutex & Re-entrant Deadlock Immunity
Located at `lib/application/services/room_sync_orchestrator.dart`:
- **Narrow Critical Section:** `RoomSyncOrchestrator` uses `_syncMutex.protect()` strictly for in-memory CRDT joins and profile reconciliation. Disk persistence (`saveProfileImmediate`) executes asynchronously outside the mutex lock.
- **Echo Loop Suppression:** Outbound frames are stamped with monotonic sequence numbers and originating node IDs. Outbound sync is skipped if the profile matches `_lastInboundProfile` or if the mutex is locked. Reconstructed entities implement value-based `operator ==` and `hashCode`.
- **Asymmetric LRU Deduplication:** Payloads enforce a 500-entry `LinkedHashMap<String, bool>` SHA-256 LRU cache and a 30-second sliding lookback window (`inboundTimestamp >= localTime - 30000`). Unrecognized payloads (`UnknownSyncMessage`) are rejected before updating the cache.
- **Asynchronous Microtask Dispatch:** Reactive broadcast `StreamController`s in persistence and transport layers MUST specify `sync: false`. Inbound transport payloads are dispatched via `scheduleMicrotask()`.

## 4. 4-Tier Transport Waterfall & WebRTC Signaling
Located at `lib/application/services/cascading_transport_router.dart` and `lib/infrastructure/adapters/p2p/`:
- **Waterfall Sequence:**
  1. Tier 1: Local Wi-Fi (`LocalWifiAdapter`)
  2. Tier 2: WebRTC P2P Mesh (`WebRtcMeshAdapter`)
  3. Tier 3: Firebase Cloud Relay (`FirebaseFallbackAdapter`)
  4. Tier 4: Offline Mode
- **Dynamic Step-Up Probing:** When degraded to Tier 3 or 4, periodically probe higher-tier adapters (`probeHigherTiers()`) via `IP2pTransportPort.probeViability()`.
- **Ephemeral Signaling Cleanup:** Handshake documents in Firestore are strictly ephemeral. `cleanUpPeerSignaling(peerId)` is partitioned per peer and triggered only after the DataChannel reaches `RTCDataChannelState.RTCDataChannelOpen` or ICE reaches `completed`.
- **W3C Polite Peer Glare Rollback:** On crossing offers (`have-local-offer` when receiving a remote offer), resolve collisions using lexicographical node ID comparison (`localNodeId.compareTo(peerId)`). The polite peer rolls back its local offer (`RTCSessionDescription('', 'rollback')`) and accepts the incoming offer.
- **Transient ICE Resilience:** Prune peer connections strictly on `RTCIceConnectionStateFailed`. Never prune on transient `RTCIceConnectionStateDisconnected`.

## 5. Local Persistence Authority & Stateless Rehydration
- **Local Storage Priority:** UI consumers opening character sheets in party rooms query local persistent storage (`CharacterPersistenceService.getCharacter`) first before remote `session.sharedCharacters`.
- **Complete Character Serialization:** Shared party sessions serialize the full `character.toMap()` payload (including evaluated vitals `maxHp`, `currentHp`, `tempHp`, `armorClass`) to prevent remote default hydration leaks.
- **Stateless Room Stub Rehydration:** Any participant connect touches `/rooms/{roomCode}` with `isStateless: true` and resets the 30-day lease (`expiresAt: now + 30 days`) via `SetOptions(merge: true)`. Confirmed empty rooms reject cleanly without phantom record generation.
