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
│        lib/application/services/, storage/             │
└──────────────┬───────────────────────────┬─────────────┘
               │ uses                      │ orchestrates
┌──────────────▼─────────────┐ ┌───────────▼─────────────┐
│        Domain Layer        │ │  Infrastructure Layer   │
│ lib/domain/ & lib/models/  │ │  lib/infrastructure/    │
│  - models/ & value_objects │ │   - adapters/ (p2p/etc) │
│  - domain/ingestion/ ASTs  │ │   - dtos/ & dtos/crdt/  │
│  - package:vtt_engine_core │ │   - repositories/       │
│  - package:vtt_ruleset...  │ │   - modules/dnd5e/      │
└────────────────────────────┘ └─────────────────────────┘
```

## Directory Structure & Layer Responsibilities

### `lib/domain/` & `lib/models/` (The Core Domain)
The pure Dart center of the application (zero `package:flutter/...` imports).
- **`lib/domain/ingestion/`**: Structural document parsing, candidate detection, and field extraction ASTs.
- **`lib/models/`**: D&D 5e domain models (`characters/`, `spells/`, `magic_items/`, `monster_codex/`, `party/`, `arena/`, `dpr/`, `tables/`, `animated_object.dart`, `weapon_mastery.dart`, `exhaustion_state.dart`).
- **`package:vtt_engine_core`**: System-agnostic tabletop engine primitives:
  - CvRDT types (`HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`, `PnCounter`).
  - Value objects & models (`HitPoints`, `CampaignProfile`, `PartyPurse`, `SessionGraphModels`).
  - Abstract ports (`ICampaignRepository`, `ICharacterRepository`, `IP2pTransportPort`, `INetworkTimePort`, `IRoomSyncPayloadPort`).
  - Ruleset SPI (`IRulesetModule`, `ICombatResolver`, `RulesetEdition`).
  - Agnostic simulation (`DprSimulator`, `PrecomputedAttack`, `CombatEffectRider`).
  - Storage durability contracts (`IStorageDurabilityPort`, `IPhysicalSnapshotPort`, `StorageSnapshotBundle`).
- **`package:vtt_ruleset_dnd5e`**: Reusable D&D 5e mechanics:
  - Ruleset module & progression (`Dnd5eRulesetModule`, `CharacterProgressionEngine`, `CharacterStatCalculator`).
  - Combat resolution (`Dnd5eCombatResolver`).
  - Spellcasting rules engine (`SpellcastingRulesEngine`).
  - Mechanics & states (`ExhaustionState`, `WeaponMastery`).
- **RULE:** Pure Dart only. Zero Flutter imports in `lib/domain/` and DTOs, verified by `test/domain/domain_purity_test.dart` and `test/infrastructure/dtos/dto_purity_test.dart`.

### `lib/application/` (Use Cases & Orchestration)
The orchestration layer coordinating domain logic and infrastructure ports.
- **`services/`**:
  - `RoomStateReconciliationService`: Merges replicated room state deltas with fault isolation.
  - `CascadingTransportRouter`: Manages the 4-tier transport waterfall (LAN, WebRTC, Firebase relay, offline).
  - `ClockSyncService`: Maintains authoritative logical time across peers.
  - `CombatEncounterService`: Manages multi-creature encounter lifecycles and turn execution.
  - `PartyRoomService`: Handles campaign room connectivity, peer discovery, and state streaming.
  - `HomebrewImportOrchestrator`: Coordinates safe ingestion and schema migration of external content.
- **`storage/`**:
  - `StorageDurabilityCoordinator`: Orchestrates atomic physical snapshot exports and imports with SHA-256 checksum verification.

### `lib/infrastructure/` (Adapters & External I/O)
Implementations of abstract domain ports, remote gateways, and concrete I/O.
- **`adapters/`**:
  - `p2p/`: Transport implementations (`LocalWifiAdapter`, `WebRtcMeshAdapter`, `FirebaseFallbackAdapter`, `FirebaseSignalingAdapter`).
  - `remote/`: Remote fetch clients (`GithubIngestorAdapter`, `HttpFetchClient`).
  - `storage/`: `CampaignSnapshotSerializerAdapter`.
- **`dtos/`**: Wire and disk serialization (`CharacterDto`, `CampaignProfileDto`, `AnimatedObjectDto`, `HomebrewEntityDto`, `crdt/`). Enforces bounds clamping and unparsed payload preservation.
- **`modules/dnd5e/`**: Concrete plug-ins bridging the toolkit to `vtt_ruleset_dnd5e`.
- **`repositories/`**: Concrete persistence adapters (`LocalCampaignRepository`, `LocalCharacterRepository`).
- **`storage/`**: Durability adapters (`PhysicalSnapshotAdapter`, `StorageDurabilityAdapter`).
- **`di/`**: Service locator registry (`injection_container.dart` via `sl`).

### `lib/presentation/`, `lib/screens/`, `lib/widgets/` (The Tabletop UI)
Flutter presentation layer adhering to strict accessibility standards (minimum 48dp touch targets, `TextScaler.linear(2.0)` scalability).
- **`presentation/`**: Reusable codex components (`CodexPageShell`, `CodexModeSelector`), accessible action tiles, and connection badges.
- **`screens/`**: Primary application views (`CharacterSheetView`, `CharacterBuilderScreen`, `ArenaScreen`, `DprCalculatorScreen`, `PartyRoomScreen`, `DmDashboardScreen`).
- **`widgets/`**: Modular components, dice animations, and modal sheets.
- **`providers/`**: State controllers (`CharacterSheetController`, `SettingsProvider`).
- **`theme/`**: Fantasy accent palettes, OLED pitch black mode, and typography.
- **RULE:** UI code must not contain core business logic or dice simulation math.

---

## State-Based Distributed Synchronization (CvRDT)

Network and room state is state-based and conflict-free (CvRDT):
- **Join-Semilattice Convergence:** State mutations are structured as Convergent Replicated Data Types (CvRDTs) merged via commutative, associative, and idempotent join functions (`CampaignProfile.join`, `RoomNodeState.join`).
- **Causality & Ordering:** Monotonic causality is tracked via **Hybrid Logical Clocks (HLC)** with deterministic `nodeId` lexicographical tie-breaking.
- **Granular Fault Isolation:** Replicated state merges isolate errors per subresource (`entityInstances`, `containers`, `characters`). A malformed or unresolvable entity is preserved without aborting the join of other valid entities.
- **Currency PN-Counters:** Currency balances replicate across peers using Positive-Negative Counters (`PnCounter`), decrementing via signed differential adjustments rather than positive scalars.
- Detailed implementation rules are documented in `docs/DATA_SAFETY_AND_CRDT.md` and `.agents/rules/crdt_and_sync.md`.

---

## Legacy Data

Pre-CRDT campaign records stored coins in scalar fields, which map to an initial PN-counter slot (`init`). When two replicas that both hold legacy balances merge, identical balances converge to that balance, while differing balances resolve to the per-denomination maximum rather than their sum. This prevents doubling coins across normal two-device baselines of the same campaign; subsequent credits and debits via CRDT operations mutate independent replica slots and add normally.

---

## Trust Model & Transport Topology

1. **4-Tier Transport Waterfall:**
   - Peers discover each other via local LAN multicast when on the same network (`LocalWifiAdapter`).
   - Peer-to-peer data channels are established using WebRTC mesh networking (`WebRtcMeshAdapter`) with polite peer glare handling.
   - If direct P2P connections cannot be negotiated (symmetric NATs, firewalls), traffic seamlessly falls back to Cloud Firestore relay channels (`FirebaseFallbackAdapter`).
   - If completely disconnected, state changes persist locally and converge automatically upon reconnection.
2. **Relay Hardening & Deduplication:**
   - Fallback relay messages enforce an explicit upper payload limit (`maxRelayPayloadLength = 999999` characters) enforced by both client adapters and Firestore security rules.
   - Inbound transport frames undergo SHA-256 LRU deduplication and sliding lookback filtering to prevent reflection loops and replay attacks.
3. **Integrity & Authorization:**
   - Physical storage snapshots include constant-time SHA-256 payload checksums.
   - Writer authority is partitioned: clients can only publish updates to entities they own or have explicit DM delegate authority to modify.