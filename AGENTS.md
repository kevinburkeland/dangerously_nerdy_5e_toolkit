# DangerouslyNerdy 5e Toolkit: AI Coding & Agent Master Directives

Welcome, AI Agent / Software Architect. When generating, refactoring, or reviewing code in this repository, you must strictly follow the architectural boundaries, mechanical rules, and engineering directives described below.

---

## 🧭 Fast Codebase Navigation Index

Before executing file operations, use this map to find the exact component you need:

```
dangerously_nerdy_5e_toolkit/
├── lib/
│   ├── domain/                         # Pure Dart Core (ZERO Flutter imports)
│   │   ├── crdt/                       # Distributed state: HybridLogicalClock, CrdtLwwRegister, CrdtOrSet
│   │   ├── homebrew/                   # Homebrew domain: RulesetVersion, GithubRepoSource, IGithubIngestorPort, HomebrewEntity
│   │   ├── models/                     # Immutable entities: AnimatedObject, CampaignProfile, WeaponMastery
│   │   │   └── value_objects/          # Value objects: HitPoints
│   │   ├── ports/                      # Abstract interfaces: ICampaignRepository, ICharacterRepository, IP2pTransportPort, INetworkTimePort
│   │   ├── rules/                      # Pure mechanical contracts: RulesetContext, CharacterValidationEngine
│   │   └── simulation/                 # Simulation contracts: DprSimulator, PrecomputedAttack
│   ├── application/                    # Use Cases & Orchestration
│   │   └── services/                   # CascadingTransportRouter, RoomStateReconciliationService, ClockSyncService, CombatEncounterService, PartyRoomService, RoomSyncOrchestrator, HomebrewImportOrchestrator
│   ├── infrastructure/                 # Adapters, DTOs & Concrete I/O
│   │   ├── adapters/                   # Transport, Remote & Time Adapters: LocalWifiTransportAdapter, WebRtcMeshAdapter, GithubIngestorAdapter, HttpFetchClient
│   │   ├── di/                         # Service Locator: injection_container.dart (sl)
│   │   ├── dtos/                       # CharacterDto, SpellDto, CampaignProfileDto, AnimatedObjectDto, HomebrewEntityDto
│   │   │   └── crdt/                   # HybridLogicalClockDto, CrdtLwwRegisterDto, CrdtOrSetDto
│   │   ├── mappers/                    # Anti-Corruption Layer Mappers: HomebrewIngestor
│   │   ├── repositories/               # LocalCampaignRepository, LocalCharacterRepository
│   │   └── resolvers/                  # CharacterTelemetryResolver
│   ├── presentation/
│   │   ├── core/                       # Accessible core widgets: AccessibleActionTile
│   │   ├── screens/                    # Sub-screens: homebrew/HomebrewExpertOptionsView
│   │   └── widgets/                    # Accessible badges & widgets: RoomConnectionBadge
│   ├── providers/                      # CharacterSheetController, SettingsProvider
│   ├── screens/                        # Top-level screen layouts (Character Sheet, Arena, DPR, Compendiums, Homebrew Studio)
│   ├── services/                       # Legacy services, ACL parsers, rules engines, persistence
│   │   ├── acl/                        # 5etools AST transformers & JSON ingestion pipeline
│   │   ├── persistence/                # Hive / IndexedDB storage & web lifecycle flusher
│   │   ├── repository/                 # LayeredPriorityStore (SRD / Homebrew / Campaign)
│   │   └── rules/                      # AcEngineAndInventory, CombatRulesEngine, Dnd5eRulesEngine, etc.
│   ├── theme/                          # AppTheme: 9 fantasy accent themes & OLED black
│   ├── utils/                          # SecureRandom, CryptoUtils, DiceFormatters
│   └── widgets/                        # Modular UI components (AbilitiesAndTraitsTab, SpellUpcastSheet, dialogs, charts)
├── test/                               # Comprehensive test suite (1,567 passing tests)
│   ├── domain/                         # Domain purity & CRDT logic tests
│   ├── application/                    # Application service tests
│   ├── infrastructure/                 # DTO serialization & repository tests
│   ├── accessibility/                  # A11y & dynamic type scaling tests
│   └── widgets/                        # Widget interaction & visual tests
├── docs/                               # System architecture & CRDT safety guidelines
└── .agents/rules/                      # Modular AI agent rule definitions
```

---

## 🛡️ Core Engineering Directives

### 1. Hexagonal Architecture & Domain Purity
- **Zero Flutter in Domain:** Files in `lib/domain/` MUST NOT import `package:flutter/...`. Use `package:meta/meta.dart` for annotations like `@immutable`.
- **Enforced via Automated Test:** `test/domain/domain_purity_test.dart` automatically audits `lib/domain/` on every CI run.
- **Infrastructure DTO Purity:** Files in `lib/infrastructure/dtos/` MUST NOT import `package:flutter/...`. Use pure `package:meta/meta.dart` for `@immutable` annotations to preserve decoupling from the Flutter engine runtime. Verified by `test/infrastructure/dtos/dto_purity_test.dart`.
- **Ports & Adapters:** Define abstract interfaces in `lib/domain/ports/`. Implementations live in `lib/infrastructure/repositories/`.
- **Immutability:** All domain models and value objects must have `const` constructors and `copyWith()` mutators. Never expose mutable lists or maps directly.

### 2. Decentralized State & CvRDT Directives
- **Hybrid Logical Clock (HLC):** Implements `Comparable`. When physical timestamps (`l`) and counters (`c`) collide, use `nodeId` (device ID string) as the deterministic lexicographical tie-breaker. Random tie-breakers are strictly forbidden.
- **HLC Node Identity Uniformity:** Orchestrators and services stamping CRDT registers must ensure local node IDs and internal `HybridLogicalClock` instances share the exact same dynamic identifier (resolving dynamic fallback IDs once before HLC instantiation) to prevent deterministic tie-breaker collision or static constant divergence.
- **Clock Spoofing & Skew Mitigation:** Network time synchronization via `INetworkTimePort` and `ClockSyncService` computes physical clock offsets (`offsetMs`). Fallback message queries (such as in `FirebaseFallbackAdapter`) buffer queries by 30 seconds into the past to tolerate physical device clock skew, and enforce bounded LRU deduplication caches (max 500 entries) cleared upon disconnection.
- **Observed-Remove Set (`CrdtOrSet`):** Deletions create tombstones. Always implement `prune(threshold)` to prevent memory leaks from unbounded tombstone accumulation.
- **Milestone Pruning Decoupling:** Prune tombstones via `RoomStateReconciliationService.executeMilestonePrune` using authoritative server/ledger timestamps, decoupled from unverified local clock estimations.
- **LWW Register (`CrdtLwwRegister`):** Modifications return a new immutable instance.
- **Minion Immutability in CRDT Collections:** Minions and summon entities (`AnimatedObjectInstance`) within `CampaignProfile.roomState.activeMinions` are immutable entities. Modifications MUST use pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`) and map into a new immutable list. In-place mutating operations are deprecated and strictly prohibited.
- **Delta Fast-Forward:** Base room state is hydrated from snapshot milestones, with incremental CRDT deltas reconciled on top via `RoomStateReconciliationService`.
- **Peer-Scoped Ephemeral Signaling Isolation:** WebRTC signaling and mesh adapters must partition tracked signaling documents by peer ID (`_peerTrackedDocPaths`). When an individual peer connection is established or opens its DataChannel, invoke `cleanUpPeerSignaling(peerId)` rather than wiping all room signaling documents (`cleanUpSignalingSession()`), preventing premature deletion of in-flight handshakes in multi-peer rooms.
- **Echo Loop Prevention Mutex:** `RoomSyncOrchestrator` locks outbound broadcasts (`_isProcessingNetworkPayload = true`) while ingesting and saving incoming network payloads, releasing via `scheduleMicrotask()` to prevent reactive database listeners from echoing inbound changes back to the transport mesh.
- **Asynchronous Stream Emission (Deadlock Prevention):** Reactive broadcast `StreamController`s in persistence repositories (e.g., `LocalCampaignRepository`) MUST NOT use `sync: true`. Asynchronous microtask queue emission prevents re-entrant deadlocks when inbound network synchronization holds mutexes (such as `_syncMutex`).
- **Asynchronous Microtask Payload Dispatch & Timer Teardown:** Inbound transport router payloads (`CascadingTransportRouter._handleIncomingPayload`) must be dispatched asynchronously via `scheduleMicrotask()` to prevent synchronous re-entrant `_syncMutex` deadlocks when adapters failover or receive inbound frames during broadcast execution stacks. Room re-initialization in `CascadingTransportRouter` must explicitly cancel and nullify prior heartbeat timers (`_heartbeatTimer`, `_fallbackHeartbeatTimer`) before activating new adapters.

### 3. Dual-Ruleset Awareness (2014 RAW vs 2024 Revised)
- The engine supports both **2014 (SRD 5.1)** and **2024 (SRD 5.2)** D&D mechanics.
- Always check or pass the `DmRulesEdition` enum (`DmRulesEdition.dnd2014` vs `DmRulesEdition.dnd2024`) or inspect `RulesetContext`.
- Key differences:
  - Drinking Potions: Action (2014) vs Bonus Action (2024).
  - Exhaustion: 6 discrete tiers (2014) vs 10 linear -2 penalty steps (2024).
  - Counterspell: Spell save DC check (2014) vs CON saving throw by caster (2024).
  - Cure Wounds / Healing Word: 1d8/1d4 (2014) vs 2d8/2d4 (2024).
  - GWM / GWF: -5/+10 & reroll 1s/2s (2014) vs +PB damage & floor 3 (2024).
  - Weapon Masteries: Absent in 2014; active in 2024.

### 4. Anti-Corruption Layer & Data Safety
- **DTO Isolation:** Network/Disk JSON must map to DTOs in `lib/infrastructure/dtos/` before conversion to Domain models.
- **Fault-Tolerance:** Missing or malformed keys must deserialize into safe tabletop defaults without throwing uncaught exceptions.
- **Unparsed Payload Preservation:** Always preserve unrecognized JSON keys in an `unparsedPayload` map to avoid discarding custom homebrew attributes during round-trip serialization.
- **Strict Bounds Clamping:** All numeric stats must be clamped (HP `0..999`, Level `1..20`, Ability Scores `1..30`, Currency `>= 0`).
- **Deserialization Priority:** Computationally normalized or resolved fields (e.g., spatial range and variable damage math) must strictly take precedence over raw fallback JSON keys during DTO deserialization.
- **Strict Entity Resolution & Anti-Collision:** Resolvers and codex lookups must prioritize exact `==` equality matches first. Substring fuzzy matching (e.g. `.contains('plate')`) is strictly prohibited to prevent collision regressions (such as Breastplate inheriting Full Plate AC 18). Fallbacks must enforce word-boundary regex (`\b`) and disallow binding generic tokens (e.g. `'Dragon'`) to distinct compound boss monsters (`'Dragon Turtle'`).

### 5. Performance & Pre-Computation
- **Zero Runtime Regex in Hot Loops:** Never execute `RegExp` inside combat rounds, Monte Carlo loops, or DPR calculations. Parse traits into precomputed numeric profiles during ingestion.
- **Background Isolates:** Multi-megabyte JSON compendium bundles must be processed in background isolates.

### 6. Accessibility (a11y) & UI Standards
- **Touch Targets:** All interactive widgets MUST be at least **48x48dp** (`minSize: const Size(48, 48)`).
- **Semantics:** Wrap icons and action triggers in `Semantics` widgets with expanded abbreviation labels (e.g., "STR" -> "Strength", "AC" -> "Armor Class").
- **Dynamic Type Scaling:** All UI must render cleanly without `RenderFlex` overflow errors up to `TextScaler.linear(2.0)`.
- **Reduced Motion:** Wrap intensive animations in `if (!MediaQuery.disableAnimationsOf(context))` checks.

### 7. Legal & SRD Compliance
- **Zero Product Identity:** Prohibited terms: Beholder, Mind Flayer, Illithid, Displacer Beast, Strahd, Hexblade, etc. Use generic SRD equivalents only (CC-BY-4.0).

### 8. Continuous Documentation & Living AI Rules Protocol (Definition of Done)
Before completing any engineering task, the agent MUST perform this two-gate audit:
- **Gate 1: README.md Synchronization:**
  - Verify if test counts changed (update badges and metrics across documentation).
  - Update feature matrices, architecture notes, and CLI commands if new capabilities or endpoints were added.
- **Gate 2: Self-Refining Rules Audit:**
  - If a new architecture pattern, port/adapter convention, or mechanical rule was established, codify it into `.agents/rules/<topic>.md` and update index maps.
  - If a non-obvious bug, framework quirk (Flutter web, IndexedDB/Hive, a11y overflow), or user correction was encountered, add a preventative directive to avoid future regressions.
  - Keep the Fast Codebase Navigation Index in `AGENTS.md` up to date.

---

## ⚡ Fast Development & Test Workflows

```bash
# Run targeted domain purity test (< 1s)
flutter test test/domain/domain_purity_test.dart

# Run CRDT and distributed state tests (< 2s)
flutter test test/domain/crdt/ test/infrastructure/dtos/crdt/ test/application/services/room_state_reconciliation_service_test.dart

# Run application & infrastructure tests (< 3s)
flutter test test/application/ test/infrastructure/

# Run static analysis (must report zero issues)
flutter analyze

# Verify web PWA bundle compilation
./scripts/build_web.sh
```

---

## 📚 Related Documentation & Detailed Rules

- [.agents/rules/architecture.md](file:///.agents/rules/architecture.md): In-depth DDD & Hexagonal guidelines.
- [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md): CvRDT, HLC, and reconciliation logic.
- [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md): 2014 vs 2024 comparison matrix.
- [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md): Accessibility and UI standards.
- [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md): DTO safety and pre-computation.
- [docs/ARCHITECTURE.md](file:///docs/ARCHITECTURE.md): System architecture and data flow.
- [docs/DATA_SAFETY_AND_CRDT.md](file:///docs/DATA_SAFETY_AND_CRDT.md): CRDT implementation rules.
