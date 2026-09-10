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
- **Authoritative Milestone Pruning:** Pruning must be decoupled from local client clocks to protect against clock drift or spoofing. Use `RoomStateReconciliationService.executeMilestonePrune(targetSet, serverAcknowledgedEpochMs, hostNodeId)` where the threshold is anchored strictly to an authoritative server/ledger snapshot timestamp.
- **Network Time Synchronization:**
  - `INetworkTimePort` in `lib/domain/ports/i_network_time_port.dart` abstracts external time resolution.
  - `ClockSyncService` calculates physical time skew (`offsetMs = networkTime - localTime`) and caches it, falling back to 0 on transport failure.
  - `HybridLogicalClock.now()`, `tick()`, and `merge()` accept `offsetMs` to guarantee causal ordering immune to client clock spoofing.
- **Defensive Type Casting & Anti-Corruption:** All CRDT DTOs (`CrdtOrSetDto`, `CrdtLwwRegisterDto`) must enforce strict `Map<String, dynamic>.from(...)` casting on nested maps to avoid runtime `_Map<dynamic, dynamic>` type-erasure exceptions during deserialization.

## 5. Transport Orchestration & Echo Loop Prevention

Located at `lib/application/services/room_sync_orchestrator.dart`:
- **Bidirectional Wiring:** Glues `IP2pTransportPort` with local persistence `ICampaignRepository` (`watchIncomingPayloads()` and `watchActiveProfile()`).
- **Echo Loop Prevention Mutex:** Setting `_isProcessingNetworkPayload = true` during inbound payload deserialization and persistence prevents local database stream listeners from echoing received state back to the mesh. The lock is safely released in a `finally` block via `scheduleMicrotask(() => _isProcessingNetworkPayload = false)`.
- **Clock-Skew Corrected Outbound Sync:** Outbound broadcasts inject `clockSyncService.currentOffsetMs` into timestamps.
- **Host Periodic Milestone Pruning:** Host DM nodes periodically execute milestone flushes and prune expired tombstones via `RoomStateReconciliationService.executeMilestonePrune()`.
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
- **Transport Lifecycle Bootstrap:**
  - `initServiceLocator()` MUST be invoked during application startup in `main.dart` to ensure `CascadingTransportRouter` and `RoomSyncOrchestrator` are registered.
  - Interactive room screens (`PartyRoomScreen`) automatically attach `RoomSyncOrchestrator.watchTelemetry()` to `RoomConnectionBadge` and cleanly disconnect upon screen disposal.
