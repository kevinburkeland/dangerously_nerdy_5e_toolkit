# CvRDT & Distributed State Directives

This project uses Convergent Replicated Data Types (CvRDTs) backed by Hybrid Logical Clocks (HLC) to power real-time, peer-to-peer and cloud campaign synchronization without data loss or race conditions.

## 1. Hybrid Logical Clock (HLC) Specifications

Located at `lib/domain/crdt/hybrid_logical_clock.dart`:
- **Structure:** Combines physical millisecond timestamp (`l`), logical counter (`c`), and unique node identifier (`nodeId`).
- **Cryptographic Node Identity Enforcement & Uniformity:** Orchestrators and services stamping CRDT registers (including `HomebrewImportOrchestrator` and `PartyRoomService`) must generate pure cryptographically secure UUID v4 fallback identifiers (e.g. via `package:uuid/uuid.dart` `const Uuid().v4()`) rather than physical wall-clock timestamps or prefixed strings to guarantee HLC tie-breaker determinism across simultaneous offline mesh imports.
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
- **Convergence & Obsolete Tombstone Suppression:**
  - When merging remote tombstones into a local set containing an active item whose insertion timestamp is strictly newer than the incoming tombstone (`localItem.timestamp.isAfter(remoteTs)`), the remote tombstone is obsolete (the item was revived) and MUST NOT be recorded. This preserves algebraic commutativity ($A \sqcup B = B \sqcup A$) and prevents active items from coexisting with stale tombstones under out-of-order delivery.
- **Unconditional Tombstone Recording on Removal (Out-of-Order Add Suppression):**
  - `remove(id, timestamp)` unconditionally records a tombstone even if the item does not currently exist in the local `_items` map (provided `timestamp.isAfter(currentTombstone)`). This guarantees that an out-of-order `add` created earlier by another peer cannot revive an item that was already deleted.
- **Value Equality & MapEntry Hash Safety:**
  - In Dart, `MapEntry` does not override `operator ==` or `hashCode`. To satisfy the contract that equal sets yield equal hash codes, `CrdtOrSet.hashCode` must hash entry tuples using `Object.hash(e.key, e.value)` prior to `Object.hashAllUnordered()`.
- **Querying Active Elements:** `.activeValues` returns only entries whose addition timestamp is strictly greater than their tombstone deletion timestamp.

## 4. State Reconciliation & Snapshot Checkpoints

Located at `lib/application/services/room_state_reconciliation_service.dart`:
- Event logs grow unbounded over time.
- **Delta Fast-Forward Pattern:** Clients receive incremental state deltas. To derive current room state, the client takes the last stable milestone snapshot and applies incoming CRDT deltas on top using deterministic `merge()` logic.
- **Strict Network Time Injection & Authoritative Milestone Pruning:** Pruning must be decoupled from local client clocks to protect against clock drift or spoofing. Use `RoomStateReconciliationService.executeMilestonePrune(targetSet, serverAcknowledgedEpochMs, hostNodeId)` where the threshold is anchored strictly to an authoritative server/ledger snapshot timestamp. `RoomStateReconciliationService` requires constructor injection of `networkTimeProvider` (sourced from `ClockSyncService.currentNetworkTimeMs`), eliminating local wall-clock spoofing vulnerabilities during pruning.
- **Network Time Synchronization:**
  - `INetworkTimePort` in `lib/domain/ports/i_network_time_port.dart` abstracts external time resolution.
  - `ClockSyncService` calculates physical time skew (`offsetMs = networkTime - localTime`) and caches it, falling back to 0 on transport failure.
  - `HybridLogicalClock.now()`, `tick()`, and `merge()` accept `offsetMs` to guarantee causal ordering immune to client clock spoofing.
- **Defensive Type Casting & Anti-Corruption:** All CRDT DTOs (`CrdtOrSetDto`, `CrdtLwwRegisterDto`) must enforce strict `Map<String, dynamic>.from(...)` casting on nested maps to avoid runtime `_Map<dynamic, dynamic>` type-erasure exceptions during deserialization.

## 5. Transport Orchestration, Mutex Concurrency & Echo Loop Prevention

Located at `lib/application/services/room_sync_orchestrator.dart` and `cascading_transport_router.dart`:
- **Bidirectional Wiring:** Glues `IP2pTransportPort` with local persistence `ICampaignRepository` (`watchIncomingPayloads()` and `watchActiveProfile()`).
- **Echo Loop Prevention Mutex & Narrowed Critical Section:** Uses `final Mutex _syncMutex = Mutex();` and `_lastInboundProfile` deduplication. `_syncMutex.protect()` is strictly narrowed to in-memory CRDT joins and profile reconciliation. Storage persistence (`saveProfileImmediate`) executes asynchronously outside the mutex lock to eliminate re-entrant deadlocks with incoming network frames. Outbound broadcasts skip synchronization if the emitted profile matches `_lastInboundProfile` or if the mutex is locked (`_syncMutex.isLocked`), eliminating microtask race conditions and recursive echo storms. Domain entities (`CampaignProfile`, `PartyPurse`) must provide deep value-based `operator ==` and `hashCode` implementations so that identical reconstructed state is safely skipped.
- **Sliding Lookback Window, Bounded LRU Deduplication & Pre-Lock Cache Protection:** In `CascadingTransportRouter._handleIncomingPayload` and `RoomSyncOrchestrator._handleIncomingPayload`, incoming payloads enforce an asymmetric bounded 500-entry LRU deduplication cache tracking payload SHA-256 digests (`_processedPayloadHashes`), silently dropping duplicates while updating LRU order. `RoomSyncOrchestrator` applies a 30-second sliding lookback window (`inboundTimestamp >= localTime - 30000`). Crucially, malformed or unrecognized payloads (`UnknownSyncMessage`) are rejected before caching their SHA-256 digests, guarding against LRU cache poisoning and denial-of-service against legitimate subsequent messages.
- **Clock-Skew Corrected Outbound Sync:** Outbound broadcasts inject `clockSyncService.currentOffsetMs` into timestamps.
- **Host Buffered Milestone Pruning Horizon:** Host DM nodes periodically execute milestone flushes via `executeHostMilestoneFlush()`. The pruning horizon is calculated by subtracting twice the heartbeat TTL (`heartbeatTtl.inMilliseconds * 2`) from the network-synchronized physical time (`nowEpoch - 2 * TTL`). This lookback buffer preserves tombstones for peers undergoing transient reconnection while safely pruning ancient tombstones.
- **Connection Telemetry & Accessible Badge:** `RoomSyncOrchestrator.watchTelemetry()` combines transport state transitions and periodic peer heartbeat counts into `RoomConnectionTelemetry` (`isOffline`, `connectionLabel`, `peerCount`). Rendered via `RoomConnectionBadge` (`lib/presentation/widgets/room_connection_badge.dart`) with `Semantics` label expansion for screen readers.

## 6. Real-Time Dice Roll Broadcast & Security Rules Guardrails
- **Unified Stream Controller:** `DiceRoomService.streamRoomRolls` maintains a unified broadcast controller per room (`_localControllers[cleanCode]`). Real-time cloud listeners (Firestore snapshots) and P2P mesh payloads feed directly into `_localControllers[cleanCode]`. Local optimistic updates and remote sync share the exact same stream, eliminating detached listeners or UI flickering.
- **CEL / Firestore Security Rules Null-Key Safety:** In Firestore Security Rules (Common Expression Language), `'field' in request.resource.data` evaluates to `true` even when `'field': null` is present in the payload. If an allow condition specifies `(!('field' in request.resource.data) || (request.resource.data.field is list))`, documents with `'field': null` will evaluate to `false` and throw `PERMISSION_DENIED`. Always:
  1. Omit null optional keys during DTO serialization (`RoomRoll.toMap()`), and
  2. Include explicit null allowances in security rules: `(!('field' in request.resource.data) || request.resource.data.field == null || request.resource.data.field is list)`.
- **String & Int Cross-Format Deserialization:** Robust tabletop payloads may be serialized as Firestore `Timestamp`, numeric millisecond timestamps, ISO 8601 strings, or native `DateTime`. Deserializers (`RoomRoll.fromMap`) must handle all variations seamlessly.

## 7. WebRTC P2P Peer Discovery, Glare Prevention & Transport Lifecycle
- **Peer Join Announcements:** When initializing a room mesh (`WebRtcMeshAdapter.initializeRoom`), the local node immediately dispatches an ephemeral broadcast `SignalingType.peerJoin` message (`toNodeId: '*'`) to announce its arrival to active peers.
- **Deterministic Glare Prevention:** To eliminate race conditions where two peers simultaneously create SDP offers for each other ("glare"), peer discovery uses a strict lexicographical tie-breaker:
  - If `localNodeId.compareTo(peerId) > 0`, the local node acts as the offerer and invokes `connectToPeer(peerId)`.
  - If `localNodeId.compareTo(peerId) < 0`, the local node sends a targeted `peerJoin` acknowledgment (`toNodeId: peerId`), signaling the higher-ranked peer to initiate the offer.
- **Cascading Heartbeat & Fallback Tracking:**
  - P2P DataChannels exchange periodic heartbeat pings every 2 seconds to update `peerLastSeen` timestamps.
  - When in `TransportState.fallbackRelay`, clients periodically broadcast `relay_heartbeat` pings so cloud-relayed participants maintain accurate peer counts and active room awareness.
- **Transport Lifecycle Bootstrap & Reconnect Resilience:**
  - `initServiceLocator()` MUST be invoked during application startup in `main.dart` to ensure `CascadingTransportRouter` and `RoomSyncOrchestrator` are registered.
  - Interactive room screens (`PartyRoomScreen`) and global room banners (`RoomBannerWidget`) automatically attach `RoomSyncOrchestrator.watchTelemetry()` to `RoomConnectionBadge`.
  - `DiceRoomService.joinRoom()` and `_restorePersistedSession()` automatically initialize `IP2pTransportPort` and activate `RoomSyncOrchestrator.startSynchronization()`, ensuring that joining a room from the Dice Roller or restored sessions connects the P2P mesh and streams telemetry without requiring a visit to the DM/Party screen.
  - `CascadingTransportRouter`, `WebRtcMeshAdapter`, `LocalWifiAdapter`, and `FirebaseFallbackAdapter` must ensure stream controllers (`_incomingPayloadsController`, `_payloadController`, `_stateController`) are cleanly reopened if closed during a prior `disconnect()`, preventing `Bad state: Cannot add new events after calling close` errors on reconnect.

## 8. 4-Tier Cost-Optimized Transport Waterfall & Ephemeral Signaling
Located at `lib/application/services/cascading_transport_router.dart`:
- **Waterfall Sequence:**
  1. **Tier 1 (Local Wi-Fi / LAN)**: `LocalWifiAdapter` provides zero-latency, zero-cloud-cost direct local network communication. If unavailable on the platform or unconfigured, throws `UnsupportedError` to cascade down.
  2. **Tier 2 (WebRTC P2P Mesh)**: `WebRtcMeshAdapter` creates full-mesh WebRTC DataChannels using Firestore strictly for ephemeral SDP/ICE signaling.
  3. **Tier 3 (Firebase Cloud Relay)**: `FirebaseFallbackAdapter` serves as metered fallback, strictly dormant during healthy local Wi-Fi or WebRTC sessions. Activated only upon unhandled transmission failure, timeout, or total zombie peer pruning.
  4. **Tier 4 (Offline Mode)**: Complete offline isolation when all transports fail.
- **Ephemeral Signaling Zero-Persistence Guarantee:**
  - `FirebaseSignalingAdapter.cleanUpSignalingSession()` is invoked immediately upon P2P connection establishment (`TransportState.webRtc` / DataChannel open), deleting all offers, answers, and ICE candidates from Firestore. Handshake documents are NEVER retained in cloud storage.
- **Late-Joiner Re-Signaling & 60-Second Sliding TTL:**
  - When initializing signaling (`FirebaseSignalingAdapter.initialize`), Firestore queries enforce a strict 60-second sliding window (`timestamp >= now - 60000`) on incoming signals, discarding stale handshake residue.
  - Late-joining clients broadcast an ephemeral `SignalingType.peerJoin` message (`toNodeId: '*'`).
  - Active peers in `WebRtcMeshAdapter` receive `peerJoin`, automatically call `connectToPeer(lateJoinerNodeId)` to dispatch a fresh, targeted SDP offer, and consume/delete the join message immediately, eliminating fallback to metered cloud relay.
- **Failover Step-Down & Payload Routing:**
  - Broadcast failures on the active adapter invoke `_stepDownWaterfall()`, cleanly disconnecting the failing adapter and activating the next tier down before retrying transmission.
  - `checkHeartbeats()` continuously monitors peer activity against `heartbeatTtl` (default 15 seconds to safely accommodate mobile browser background timer throttling); if active peers drop to zero in Tier 1 or Tier 2, the router automatically steps down to Tier 3 cloud relay.
  - **Adapter Peer Last-Seen Synchronization:** The underlying `WebRtcMeshAdapter` maintains connections via silent internal ping/pong protocol messages that are withheld from the application payload stream. To prevent the router from starving and prematurely evicting peers (causing UI peer count flickering between 0 and 1), `checkHeartbeats()` explicitly polls and synchronizes `_activeAdapter?.peerLastSeen` into the router's `_peerLastSeen` registry before evaluating zombie nodes against the TTL.
  - **Empty Channels Failover Cascade:** In `WebRtcMeshAdapter.broadcastPayload`, if `_dataChannels.isEmpty`, it throws a `StateError` to signal `CascadingTransportRouter` to trigger immediate waterfall step-down to Tier 3 Firebase cloud relay rather than silently dropping outgoing payloads when P2P peer connections have not formed.
  - **WebRTC Glare Arbitration & Rollback Failure Recovery:** When multiple devices join simultaneously and send crossing offers (`_peerConnections` already contains in-flight connection for target peer), resolve collisions deterministically using lexicographical comparison of node IDs (`localNodeId.compareTo(peerId)`):
    - Higher rank node (impolite peer) drops the colliding offer, deletes the signal, and retains its outbound offer.
    - Lower rank node (polite peer) yields, prunes its in-flight connection, and answers the incoming offer. If `setRemoteDescription` fails during polite rollback, the corrupted peer connection is pruned, closed, and immediately recreated as a clean `RTCPeerConnection` instance to prevent terminal channel loss.
  - **Transient ICE Disconnection Resilience:** In `WebRtcMeshAdapter`, peer connections MUST ONLY be pruned on `RTCIceConnectionState.RTCIceConnectionStateFailed`. Never prune on `RTCIceConnectionState.RTCIceConnectionStateDisconnected`, which represents transient packet loss, radio power save, or temporary routing adjustments.
  - **Multi-Provider STUN Redundancy:** Default RTC configuration must provide diverse STUN servers (`stun:stun.l.google.com:19302`, `stun:stun1.l.google.com:19302`, `stun:stun2.l.google.com:19302`, and `stun:stun.cloudflare.com:3478`) to guarantee local/reflective ICE candidate generation across NAT environments.
  - **In-Memory Signaling TTL & Index Independence:** In `FirebaseSignalingAdapter`, signaling queries must avoid combining inequality range filters (`timestamp >= threshold`) with `whereIn` equality filters (`toNodeId in [_localNodeId, '*']`), which requires custom Firestore composite indexes. Instead, query strictly on `toNodeId` and evaluate the sliding 60-second TTL window in-memory, ensuring zero-configuration operation on default Firestore rules.
  - **Signaling Cleanup Sequence & Bounded Teardown:** In `CascadingTransportRouter._activateAdapter`, invocation of `cleanUpSignalingSession()` to clear stale session residue must occur *before* calling `adapter.initializeRoom(...)`. Executing cleanup after initialization erases the newly dispatched `peerJoin` broadcast document before other nodes can receive it. In `FirebaseSignalingAdapter._deletePath`, document deletions are bounded by a 5-second timeout (`.timeout(Duration(seconds: 5))`) to guard against hung network connections during session teardown.

## 9. IP2pTransportPort Unification & Interface Polymorphism
Located at `lib/domain/ports/i_p2p_transport_port.dart`:
- **Single Domain Transport Contract:**
  - `IP2pTransportPort` is the unified domain interface for all real-time mesh networking and state propagation.
  - Enriched with `TransportState get currentState;` and `Map<String, int> get peerLastSeen;`.
- **Zero Downcasting Invariant:**
  - Downcasting `transportPort as CascadingTransportRouter` is strictly prohibited.
  - Application services (`RoomSyncOrchestrator`) must interact exclusively with the polymorphic `IP2pTransportPort` contract.
- **IPartySyncPort Deprecation:**
  - `IPartySyncPort` is deprecated (`@Deprecated('Use RoomSyncOrchestrator and IP2pTransportPort instead.')`).
  - DI container (`injection_container.dart`) registers `IP2pTransportPort -> CascadingTransportRouter`, and consumers inject `RoomSyncOrchestrator` and `IP2pTransportPort`.

## 10. Concurrency, Minion Immutability & Stream Controller Hygiene
- **Asynchronous Repository Broadcast Streams:** Broadcast `StreamController`s in persistence layers (such as `LocalCampaignRepository._activeProfileController` and `_allProfilesController`) MUST NOT set `sync: true`. Asynchronous microtask delivery decouples reactive stream notifications from internal mutex acquisitions (e.g. `_syncMutex`), preventing re-entrant deadlock and `StateError`.
- **Asynchronous Microtask Inbound Payload Dispatch & Router Timer Teardown:** In `CascadingTransportRouter`, `_handleIncomingPayload` dispatches payload delivery to `_payloadController` via `scheduleMicrotask()`. This decouples inbound transport delivery from active outbound broadcast execution stacks, preventing synchronous re-entrant acquisition of `_syncMutex` in `RoomSyncOrchestrator` when failover cascades immediately receive inbound frames. Furthermore, `initializeRoom` must explicitly cancel and nullify `_heartbeatTimer` and `_fallbackHeartbeatTimer` before resetting adapter references to prevent timer leak accumulations across room transitions.
- **CRDT Minion Entity Immutability:** Minions and summon instances (`AnimatedObjectInstance`) within `CampaignProfile.roomState.activeMinions` are immutable value entities. Modifying minion vitals MUST use pure copy-transform methods (`applyDamage`, `applyHealing`, `applyTempHp`) and map into a new list. In-place mutating setters and methods are deprecated.
- **Transport Adapter Resource Hygiene:** Transport adapters implementing `IP2pTransportPort` (e.g., `FirebaseFallbackAdapter`) MUST close their incoming payload stream controllers in `disconnect()` (`if (!_incomingPayloadsController.isClosed) await _incomingPayloadsController.close();`) and cleanly recreate them upon subsequent `initializeRoom(...)` calls, preventing zombie listener memory leaks across room transitions.
- **WebRTC Mesh Async Microtask Inbound Dispatch:** In `WebRtcMeshAdapter`, `_incomingPayloadsController` is initialized with `StreamController<String>.broadcast(sync: false)` and DataChannel message arrivals in `_registerDataChannel` are dispatched via `scheduleMicrotask(() { if (!_incomingPayloadsController.isClosed) _incomingPayloadsController.add(text); })` to eliminate synchronous event-loop contention and prevent re-entrant mutex deadlocks during inbound mesh cascades.

## 11. HLC Node Identity Uniformity & Deterministic Tie-Breaking
- **Dynamic Node ID Consistency:** When application services (such as `HomebrewImportOrchestrator`) stamp CRDT operations without an explicitly injected node identifier, they must resolve a dynamic node identifier (e.g. `'node_homebrew_${DateTime.now().millisecondsSinceEpoch}'`) *once* and share that exact string between the service's `nodeId` and internal `HybridLogicalClock.now(nodeId)`. Never allow HLC constructors to fall back to a static constant string (e.g., `'node_homebrew'`), which risks deterministic tie-breaker divergence or collisions across independent nodes.

## 12. Clock-Skew Tolerant Relays & Peer-Scoped Signaling Isolation
- **Physical Clock Skew in Fallback Relays:** In `FirebaseFallbackAdapter`, Firestore relay message queries must buffer the timestamp threshold by 30 seconds into the past (`DateTime.now().millisecondsSinceEpoch - 30000`) to tolerate physical clock drift between participating devices. To prevent duplicate deliveries resulting from this wider query window, the adapter must maintain an in-memory bounded LRU set of processed message IDs (maximum 500 entries) that is cleared on `disconnect()`.
- **Peer-Scoped WebRTC Signaling Isolation:** Ephemeral signaling documents in `FirebaseSignalingAdapter` must be tracked and partitioned per peer (`Map<String, Set<String>> _peerTrackedDocPaths`). In multi-peer mesh topologies, establishing a connection or opening a DataChannel with peer B must call `cleanUpPeerSignaling(peerId)` rather than wiping all session documents (`cleanUpSignalingSession()`), ensuring in-flight signaling handshakes with peer C are never prematurely purged. Full session cleanup is reserved exclusively for adapter disposal and room disconnect.

## 13. Field-Level Sub-Resource Profile Reconciliation & Explicit Causality
Located at `lib/application/services/room_state_reconciliation_service.dart` and `room_sync_orchestrator.dart`:
- **Sub-Resource Merging Over Full-Document LWW:** Receiving `room_sync_full` updates reconciles local and remote `CampaignProfile` instances field-by-field via `RoomStateReconciliationService.reconcileProfile()` rather than overwriting wholesale. Notes, party purse, party rosters, room metadata, change logs, active encounters (keyed by `participantId`), and active minions (keyed by `m.id`) merge independently with LWW registers and tombstone-safe sets.
- **Explicit Causality & Echo Loop Suppression:** State synchronization payloads are tagged with `origin_node_id` and monotonic `sequence_number`. Incoming payloads from the local node are discarded immediately (`originNodeId == _localNodeId`). Outbound broadcasts are suppressed during inbound remote payload application via microtask-scoped mutex flag `_isApplyingRemoteSync`.

## 14. Bi-Directional Step-Up Waterfall Recovery & Transport Port Polymorphism
Located at `lib/application/services/cascading_transport_router.dart`:
- **Dynamic Step-Up Probing:** When degraded to Tier 3 (Cloud Relay) or Tier 4 (Offline), `CascadingTransportRouter` initiates a 30-second periodic recovery monitor (`_startStepUpRecoveryMonitor()`). Higher-tier adapters are probed for viability (`probeHigherTiers()`) via the abstract contract `IP2pTransportPort.probeViability(roomCode, localNodeId)`.
- **Zero Concrete Downcasting:** Eliminates concrete downcasting (`adapter is WebRtcMeshAdapter`). `IP2pTransportPort` declares `heartbeatTtl`, `prepareSession()`, and `probeViability()` polymorphically.

## 15. W3C Polite Peer Glare Rollback & Clock Skew Safe Pruning Deferral
Located at `lib/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart` and `room_state_reconciliation_service.dart`:
- **W3C Polite Peer Rollback:** When signaling collisions occur (receiving an SDP offer while in `have-local-offer`), the polite peer rolls back its local offer (`await connection.setLocalDescription(RTCSessionDescription('', 'rollback'))`) and accepts the incoming offer without tearing down the connection.
- **Clock Skew Inversion Defense:** In `RoomStateReconciliationService.safePrune`, the pruning threshold is checked against monotonic network-synchronized physical time (`INetworkTimePort`). If local clock drift or inversion would cause `threshold >= networkTime`, pruning is deferred gracefully (returning the unpruned set) rather than throwing `StateError`.

## 16. PN-Counter Currency Convergence & crdt_purse_delta Protocol
Located at `lib/domain/crdt/pn_counter.dart`, `lib/models/party/party_purse.dart`, and `lib/application/services/room_sync_orchestrator.dart`:
- **State-Based Positive-Negative Counter:** Party currency denominations (`cp`, `sp`, `ep`, `gp`, `pp`) converge using `PnCounter`, which tracks positive increments (`P`) and negative decrements (`N`) per node ID.
- **Eradication of Scalar LWW Overwrites:** In `RoomStateReconciliationService._mergePartyPurse`, currency convergence unconditionally performs a CvRDT lattice join (`local.merge(remote)`). Legacy scalar field LWW overwrites are strictly eradicated to prevent stale remote balances from overwriting or resurrecting spent funds.
- **Granular Coin Modification:** `PartyPurse.modifyCoin(denomination, delta, {required String nodeId})` dynamically routes positive deltas to `counter.increment(nodeId, delta)` and negative deltas to `counter.decrement(nodeId, -delta)`.
- **Focused Delta Protocol:** In `RoomSyncOrchestrator._broadcastActiveProfile`, purse changes emit lightweight, focused `crdt_purse_delta` packets containing the serialized `party_purse_crdt` payload, avoiding full profile document dumps on routine currency transactions. Inbound `crdt_purse_delta` packets are directly merged into the local profile via `_handleIncomingPurseDelta`.

## 17. WebRTC DataChannel Readiness Signaling Gate
Located at `lib/infrastructure/adapters/p2p/webrtc_mesh_adapter.dart`:
- **Preserving Signaling During Early ICE Transitions:** `onIceConnectionState` transitions to `RTCIceConnectionState.RTCIceConnectionStateConnected` must not immediately purge peer signaling documents. Transient connection states can occur before the underlying `RTCDataChannel` is confirmed open.
- **Readiness Gate:** Signaling cleanup (`_signalingAdapter.cleanUpPeerSignaling(peerId)`) is only triggered once `_dataChannels[peerId]?.state == RTCDataChannelState.RTCDataChannelOpen` or when the ICE connection state reaches `RTCIceConnectionState.RTCIceConnectionStateCompleted`, preventing premature teardown of in-flight handshake exchanges.

## 18. Stateless Room Stub Rehydration & 30-Day Lease Auto-Renewal
Located at `lib/services/party/party_room_service.dart`, `lib/infrastructure/adapters/p2p/firebase_signaling_adapter.dart`, and `lib/infrastructure/adapters/p2p/firebase_fallback_adapter.dart`:
- **Stateless Room Presence Discovery:** In pure P2P mesh and stateless architectures, signaling documents exist in subcollections (`rooms/{roomCode}/nodes` and `rooms/{roomCode}/relay_messages`) without requiring a pre-existing root document. `PartyRoomService.joinCampaign()` checks subcollection presence when `/rooms/{roomCode}` is absent, allowing incoming peers to connect cleanly rather than throwing false `CampaignNotFoundException` errors.
- **30-Day Lease Auto-Renewal on Connect:** Whenever any participant connects (host room initialization, player join, or `PartyRoomScreen` mount), `PartyRoomService.ensureRoomExists`, `FirebaseSignalingAdapter.initialize`, and `FirebaseFallbackAdapter.initializeRoom` rehydrate/touch `/rooms/{roomCode}` with `isStateless: true` and reset the 30-day lease (`expiresAt: now + 30 days`, `lastUpdated: now`) via `SetOptions(merge: true)`.
- **Anti-Ghost Record Defense:** Rooms with no root document, no active signaling nodes, no relay messages, and no local DM credentials are confirmed non-existent and throw `CampaignNotFoundException`, ensuring invalid room codes never generate phantom database stubs.
- **Security Rules Parity:** `firestore.rules` allows `partyPurse` PN-counter map structures (`cpCounter`, etc.) and stateless lease renewals without permission failures.
