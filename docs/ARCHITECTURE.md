# System Architecture

This repository strictly follows **Domain-Driven Design (DDD)** combined with **Hexagonal Architecture (Ports and Adapters)**. Following the extraction of the system-agnostic engine `vtt_engine_core` and the standalone D&D 5e ruleset module `vtt_ruleset_dnd5e`, this codebase serves as an application orchestration, infrastructure adapter, and tabletop presentation layer.

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│       lib/presentation/, lib/screens/, lib/widgets/    │
└───────────────────────────┬────────────────────────────┘
                            │ uses
┌───────────────────────────▼────────────────────────────┐
│                    Application Layer                   │
│    lib/application/ (services/, storage/, blob/, map/) │
└──────────────┬───────────────────────────┬─────────────┘
               │ uses                      │ orchestrates
┌──────────────▼─────────────┐ ┌───────────▼─────────────┐
│        Domain Layer        │ │  Infrastructure Layer   │
│ lib/domain/ & lib/models/  │ │  lib/infrastructure/    │
│  - domain/ingestion/ ASTs  │ │   - adapters/ (p2p/etc) │
│  - lib/models/ (5e domain) │ │   - dtos/ & dtos/crdt/  │
│  - package:vtt_engine_core │ │   - repositories/       │
│  - package:vtt_ruleset...  │ │   - modules/dnd5e/      │
└────────────────────────────┘ └─────────────────────────┘
```

The codebase contains modern layered folders (`lib/application/`, `lib/domain/`, `lib/infrastructure/`, `lib/presentation/`) alongside older flat folders (`lib/models/`, `lib/screens/`, `lib/services/`, `lib/widgets/`, `lib/providers/`, `lib/theme/`, `lib/utils/`). The older folders represent the pre-extraction layout that is progressively migrated into the hexagonal architecture.

Decision records are indexed in [docs/decisions/README.md](decisions/README.md).
The complete component index is maintained in [.agents/rules/codebase_map.md](../.agents/rules/codebase_map.md).

Pure Dart folders (checked by test/domain/domain_purity_test.dart): lib/domain/ lib/application/ lib/infrastructure/dtos/

## Directory Structure & Layer Responsibilities

| Folder | Responsibilities |
|---|---|
| `lib/application` | Top-level application workflows and use-case coordination. |
| `lib/application/blob` | Large asset transfer protocol, chunking, verification, and data channel messaging. |
| `lib/application/map` | Battle map intake, grid manipulation, token rules, candidate resolution, and view states. |
| `lib/application/services` | Replicated room state reconciliation, encounter lifecycles, and clock synchronization. |
| `lib/application/storage` | Durability coordination, atomic physical snapshot import/export, and checksum verification. |
| `lib/domain` | Pure Dart tabletop domain logic with zero platform dependencies. |
| `lib/domain/ingestion` | Structural document parsing, candidate identification, and field extraction ASTs. |
| `lib/domain/ingestion/capability` | Ingestion capability descriptors and structural pattern evaluators. |
| `lib/domain/ingestion/descriptors` | Structural document descriptors and entity metadata definitions. |
| `lib/domain/ingestion/engine` | Ingestion parser engines, section dividers, and structural token matchers. |
| `lib/domain/ingestion/models` | Document AST nodes, extraction results, and structural candidate models. |
| `lib/domain/ingestion/services` | Ingestion workbench orchestration and document candidate detection services. |
| `lib/infrastructure` | Concrete infrastructure implementations of domain and engine ports. |
| `lib/infrastructure/adapters` | Platform and network adapters for peer-to-peer transport, storage, and remote ingestion. |
| `lib/infrastructure/adapters/dtos` | Internal DTO structures for network and serialization transport adapters. |
| `lib/infrastructure/adapters/p2p` | WebRTC mesh networking, Firestore fallback relay, and signaling adapters. |
| `lib/infrastructure/adapters/remote` | HTTP fetching and remote GitHub compendium ingestion clients. |
| `lib/infrastructure/adapters/storage` | Campaign snapshot file serialization adapters. |
| `lib/infrastructure/di` | Service locator registry and dependency injection container (`sl`). |
| `lib/infrastructure/dtos` | Wire and disk serialization DTOs enforcing bounds clamping. |
| `lib/infrastructure/dtos/crdt` | Serialization DTOs for CvRDT primitives and hybrid logical clocks. |
| `lib/infrastructure/map` | Battle map image intake, encoding, and storage adapters. |
| `lib/infrastructure/map/stub` | Fallback platform stub for map intake and image decoding. |
| `lib/infrastructure/map/web` | Web canvas map image re-encoding and dimension scaling adapter. |
| `lib/infrastructure/mappers` | Anti-corruption layer mappers for external homebrew and room sync payloads. |
| `lib/infrastructure/migration` | Data store migration scripts and schema evolution utilities. |
| `lib/infrastructure/modules` | Modular game system adapters for the engine SPI. |
| `lib/infrastructure/modules/dnd5e` | Concrete D&D 5e engine plug-ins bridging the toolkit to `vtt_ruleset_dnd5e`. |
| `lib/infrastructure/repositories` | Local campaign and character persistence repositories implementing engine ports. |
| `lib/infrastructure/resolvers` | Runtime telemetry resolvers and character state evaluators. |
| `lib/infrastructure/storage` | Storage durability and snapshot platform adapters. |
| `lib/infrastructure/storage/stub` | Unsupported platform stub for storage durability snapshotting. |
| `lib/infrastructure/storage/web` | Web IndexedDB blob store and snapshot download/upload adapters. |
| `lib/models` | D&D 5e domain models and backward-compatible re-export barrels. |
| `lib/presentation` | Tabletop user interface presentation components and feature shells. |
| `lib/presentation/codex` | Reusable codex shells, search bars, mode selectors, and filter strips. |
| `lib/presentation/common` | Common presentation widgets, status indicators, and responsive containers. |
| `lib/presentation/core` | Core accessible action tiles and formatted text presentation widgets. |
| `lib/presentation/screens` | Dedicated presentation screen layouts. |
| `lib/presentation/screens/homebrew` | Homebrew studio views, expert options, and creator workspaces. |
| `lib/presentation/screens/map` | Dedicated full-screen tabletop battle map view (`MapScreen`). |
| `lib/presentation/storage` | Durability status banners and storage persistence management widgets. |
| `lib/presentation/widgets` | Modular presentation UI components and modals. |
| `lib/presentation/widgets/map` | Battle map rendering canvas, grid overlay, token layer, and control panels. |
| `lib/providers` | State controllers and change notifiers (`CharacterSheetController`, `SettingsProvider`). |
| `lib/screens` | Feature screen layouts (Character Sheet, Builder, DM Dashboard, Compendiums). |
| `lib/services` | Rules engines, persistence services, and Anti-Corruption Layer parsers. |
| `lib/theme` | Fantasy accent color palettes, OLED black theme, and typography styles. |
| `lib/utils` | Cryptographic utilities, secure random generation, and platform helpers. |
| `lib/widgets` | Modular UI components, dialogs, and compendium cards. |

## The Battle Map

The battle map subsystem provides tactical grid maps and token movement for shared multiplayer sessions.

```
DM Image Pick ──> MapIntakeService ──> WebBlobStoreAdapter (IndexedDB)
                         │                          │
                         ▼                          ▼
                   CampaignProfile          BlobTransferService (WebRTC)
                 (BlobRef SHA-256)                  │
                         │                          ▼
                         └─────────────> ActiveMapController ──> MapView
```

### State & Storage Separation
- **References in Replicated State:** The campaign state stores only metadata references, never raw image bytes. `CampaignProfile` in `vtt-engine-core/lib/models/campaign_profile.dart` holds `activeMapRegister` (`CrdtLwwRegister<BlobRef?>`), `mapGridRegister` (`CrdtLwwRegister<MapGrid?>`), `mapTokens` (`CrdtOrSet<MapToken>`, token identity), and `mapTokenCells` (`CrdtOrSet<MapTokenCell>`, token position). `BlobRef`, `MapGrid`, and `MapToken` reside in `vtt-engine-core/lib/models/value_objects/`.
- **Local Content-Addressed Store:** Blobs are stored locally on each device via `BlobStorePort`. `BlobStoreAdapter` (`lib/infrastructure/storage/web/web_blob_store_adapter.dart`) stores chunks in IndexedDB keyed by their SHA-256 hash. If IndexedDB fails to open, the store fails closed, transitioning the controller to `MapStoreUnavailable`.

### Intake Pipeline
- **Validation & Transcoding:** When a DM selects an image, `MapIntakeService` (`lib/application/map/map_intake_service.dart`) validates header limits before decoding via `lib/application/map/map_image_header.dart`.
- **Intake Limits:** Constants enforce safety: `kMapInputMaxBytes = 209715200` (200 MiB file size limit), `kMapInputMaxLongestSidePx = 8192` (maximum input dimension), `kMapHeaderScanMaxBytes = 16777216` (16 MiB header scan window), and `kMapOutputMaxLongestSidePx = 4096` (maximum output dimension).
- **Web Intake Adapter:** On web (`lib/infrastructure/map/web/web_map_image_intake_adapter.dart`), images larger than 4,096 px on their longest side are scaled down and re-encoded to WebP or JPEG. The image's content ID is the SHA-256 hash of the resulting bytes.

### Peer-to-Peer Transfer
- **Dedicated Data Channel:** `BlobTransferService` (`lib/application/blob/blob_transfer_service.dart`) coordinates file distribution over a dedicated WebRTC data channel (`kBlobChannelLabel = 'dn5e_blob'`) defined in `lib/application/blob/blob_transfer_protocol.dart`.
- **Swarm Pull Model:** Peers pull missing chunks from any connected peer that holds the complete blob.
- **Integrity Verification:** `verifyBlob` (`lib/application/blob/blob_verifier.dart`) checks both byte length, format signature, and SHA-256 checksum (returning `BlobVerdict`) before committing received bytes to the local store.
- **Relay Fallback Behavior:** Only `WebRtcMeshAdapter` implements `BlobChannelPort`. Devices connected exclusively through the Firestore fallback relay cannot transfer or receive large binary assets. When an un-cached map is active over relay, `ActiveMapController` transitions to `MapRelayOnly`, and `MapView` informs the player: `"This map can't reach you over the relay connection. Ask the DM to connect you directly."`.

### Controller & View State
- **State Machine:** `ActiveMapController` (`lib/application/map/active_map_controller.dart`) manages lifecycle transitions across `MapNone`, `MapLoading`, `MapDownloading`, `MapWaitingForPeer`, `MapConnecting`, `MapRelayOnly`, `MapStoreUnavailable`, `MapReady`, and `MapFailed`.
- **Grid Geometry:** `MapGridService`, `MapGridEditor` (`lib/application/map/map_grid_editor.dart`), and `lib/application/map/grid_geometry.dart` handle grid cell dimensions, pixel offsets, and Chebyshev 5e distance calculations ("every square counts once").
- **Token Rules & Placement:** `MapTokenService`, `MapTokenMover` (`lib/application/map/map_token_mover.dart`), `lib/application/map/map_token_rules.dart`, and `lib/application/map/map_token_candidates.dart` govern token authorization: DMs can move any token, while players are restricted to tokens linked to their assigned characters or owned minions.
- **UI Components:** The map is accessed via `MapScreen` in `lib/presentation/screens/map/map_screen.dart`, launched directly from buttons in `lib/screens/party_room_screen.dart` and `lib/screens/dm_dashboard_screen.dart`. Canvas rendering, token interaction layers, and control toolbars reside in `lib/presentation/widgets/map/` (`MapView`, `MapTokenLayer`, `MapGridOverlay`, `MapGridControls`, `MapTokenPanel`).

## Synchronization & Transport Topology

Party synchronization operates without central authority using a multi-tier transport architecture:

1. **WebRTC Mesh (`WebRtcMeshAdapter`):**
   - Direct peer-to-peer data channels established via polite peer glare handling.
   - Carries bidirectional CvRDT state deltas and high-throughput blob transfer.
2. **Cloud Firestore Fallback Relay (`FirebaseFallbackAdapter`):**
   - Activated automatically when symmetric NATs or restrictive firewalls prevent direct WebRTC negotiation.
   - Relays JSON state payloads with an upper bound limit (`maxRelayPayloadLength = 999999` characters).
   - Inbound frames undergo SHA-256 LRU deduplication and sliding lookback filtering to prevent reflection loops.
3. **Offline Persistence & Anti-Entropy:**
   - When disconnected from all network transports, changes persist locally in IndexedDB / Hive.
   - Upon reconnecting, convergence executes via anti-entropy mechanisms (sync on start, transport activation, new peer connection, reply when behind, and periodic 30-second sweeps).
4. **Local Wi-Fi Stub (`LocalWifiAdapter`):**
   - `LocalWifiAdapter.initializeRoom` throws `UnsupportedError`. LAN discovery is currently a non-functional stub.

### Firestore Security & Data Paths
The Firestore database structure declared in `firestore.rules` enforces capability isolation:
- `rooms/{roomCode}`: Public lobby document containing `roomCode`, `campaignName`, `hostKeyHash`, `expiresAt`, `createdAt`, `lastUpdated`, `version`, `activePlayers`, `partyTelemetry`, and `sharedCharacters`.
- `rooms/{roomCode}/hostProof/current`: Write-only administrative proof. Rules verify `effectiveHash(hostProof.key) == room.hostKeyHash` before allowing room deletion or modification of core identity fields (`campaignId`, `rulesetId`).
- `rooms/{roomCode}/signaling/{signalId}` and `rooms/{roomCode}/nodes/{toNodeId}/signals/{signalId}`: Ephemeral signaling exchange for WebRTC session descriptions and ICE candidates.
- `rooms/{roomCode}/relay_messages/{messageId}`: Relayed sync messages for devices unable to negotiate direct P2P connections.
- `rooms/{roomCode}/loot/{lootId}`: Shared party loot log entries.
- `rooms/{roomCode}/events/{eventId}`: Campaign room activity event log.
- `rooms/{roomCode}/rolls/{rollId}`: Real-time 3D dice roll results broadcast to party members.

## Trust model as built

- **No User Accounts:** There is no authentication system, sign-in screen, or Firebase Auth integration. The project avoids collecting personal identifying information.
- **Room Code as Capability:** The 6-character room code represents the capability to discover, read, and join a multiplayer session. Anyone holding the code can participate in room chat, view shared characters, and exchange state deltas.
- **Host Key & DM Passkey:** The DM device generates a cryptographically secure random UUID v4 (`CryptoUtils.generateHostKey()`). The Firestore room document stores only its SHA-256 hash (`hostKeyHash`). The raw UUID acts as the DM passkey. `PartyRoomService.claimDmRole()` verifies this passkey against `hostKeyHash` to grant co-DM capabilities.
- **Open Player Writing:** Any client holding the room code can write player presence (`activePlayers`), character summary projections (`sharedCharacters`), and WebRTC signaling documents. This design ensures joining requires no administrative approval or host credentials.
- **Non-Authoritative P2P Messaging:** State deltas exchanged peer-to-peer or over relay are not authorised per writer; any connected device can emit CRDT joins. DM-specific controls (such as moving any token or modifying foreign characters) are enforced solely in the client UI.
- **App Check:** reCAPTCHA-based App Check is enabled in the Firebase console to mitigate automated abuse.

## State-Based Distributed Synchronization (CvRDT)

- **Join-Semilattice Convergence:** Replicated state converges deterministically via commutative, associative, and idempotent join functions (`CampaignProfile.join`, `RoomNodeState.join`).
- **Logical Time:** Causality is ordered using Hybrid Logical Clocks (`HybridLogicalClock`) with lexicographical `nodeId` tie-breaking.
- **Granular Fault Isolation:** Replicated state merges isolate errors per subresource (`entityInstances`, `containers`, `characters`). A malformed or unresolvable entity is preserved without aborting the join of other valid entities.
- **Currency Counters:** Party currency balances replicate using Positive-Negative Counters (`PnCounter`), decrementing via signed differential adjustments rather than absolute scalars.

## Legacy Data

Pre-CRDT campaign records stored coins in scalar fields, which map to an initial PN-counter slot (`init`). When two replicas that both hold legacy balances merge, identical balances converge to that balance, while differing balances resolve to the per-denomination maximum rather than their sum. This prevents doubling coins across normal two-device baselines of the same campaign; subsequent credits and debits via CRDT operations mutate independent replica slots and add normally.
