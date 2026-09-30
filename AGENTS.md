# DangerouslyNerdy 5e Toolkit: Architecture & Navigation Operating Manual

Welcome, AI Agent / Software Architect. This document serves as the primary operating manual and navigation index for the `dangerously_nerdy_5e_toolkit` codebase.

Following the extraction of the system-agnostic engine `vtt_engine_core` (`../vtt-engine-core`) and the standalone D&D 5e ruleset module `vtt_ruleset_dnd5e` (`../vtt-ruleset-dnd5e`), this repository is:
- A consuming application of `vtt_engine_core` and `vtt_ruleset_dnd5e`
- An application orchestration and synchronization layer
- An infrastructure and transport adapter layer
- A Flutter-based tabletop presentation layer

---

## 🧭 Fast Codebase Navigation Index

Use this map to locate components and understand ownership boundaries:

```
dangerously_nerdy_5e_toolkit/
├── lib/
│   ├── domain/                         # Pure Dart domain logic (ZERO Flutter imports)
│   │   └── ingestion/                  # Structural document parsing, candidate detection, field extraction ASTs
│   ├── models/                         # D&D 5e domain models & compatibility re-exports
│   │   ├── characters/                 # Character, CharacterClass, Subclass, Background, Species, Feat, HitDice
│   │   ├── spells/                     # Spell, SpellSchool, SpellComponent, SpellSlot
│   │   ├── magic_items/                # MagicItem, ItemRarity, ItemCategory, AttunementRequirement
│   │   ├── monster_codex/              # Monster, MonsterAction, MonsterTrait, CreatureSize
│   │   ├── party/                      # CampaignSession, SharedCharacter
│   │   ├── arena/                      # ArenaCombatant, ClashSimulationResult
│   │   ├── dpr/                        # DprBuildProfile, WeaponPreset
│   │   ├── tables/                     # RollableTable, RollableTableRow
│   │   ├── domain/                     # Compatibility re-export barrels (bridges legacy imports to engine or models)
│   │   ├── animated_object.dart        # Animate Objects 5e spell entity
│   │   ├── weapon_mastery.dart         # 2024 Weapon Mastery properties
│   │   └── exhaustion_state.dart       # Dual-ruleset exhaustion tracking
│   ├── application/                    # Application orchestration & use cases
│   │   ├── services/                   # CascadingTransportRouter, RoomStateReconciliationService, ClockSyncService,
│   │   │                               # CombatEncounterService, PartyRoomService, RoomSyncOrchestrator, HomebrewImportOrchestrator
│   │   └── storage/                    # StorageDurabilityCoordinator (snapshot lifecycle & durability orchestration)
│   ├── infrastructure/                 # Adapters, DTOs & concrete I/O
│   │   ├── adapters/                   # Transport & remote adapters:
│   │   │   ├── p2p/                    # LocalWifiAdapter, WebRtcMeshAdapter, FirebaseFallbackAdapter, FirebaseSignalingAdapter
│   │   │   ├── remote/                 # GithubIngestorAdapter, HttpFetchClient
│   │   │   └── storage/                # CampaignSnapshotSerializerAdapter
│   │   ├── di/                         # Service locator: injection_container.dart (sl)
│   │   ├── dtos/                       # Wire/disk serialization: CharacterDto, CampaignProfileDto, AnimatedObjectDto, HomebrewEntityDto
│   │   │   └── crdt/                   # HybridLogicalClockDto, CrdtLwwRegisterDto, CrdtOrSetDto
│   │   ├── mappers/                    # Anti-Corruption Layer: HomebrewIngestor, RoomSyncPayloadMapper
│   │   ├── modules/dnd5e/              # Concrete D&D 5e engine plug-ins: Dnd5e2014Module, Dnd5e2024Module,
│   │   │                               # Dnd5eCombatResolver, Dnd5eCurrencySystem, Dnd5eAnimatedObjectAdapter
│   │   ├── repositories/               # LocalCampaignRepository, LocalCharacterRepository
│   │   ├── resolvers/                  # CharacterTelemetryResolver
│   │   └── storage/                    # PhysicalSnapshotAdapter, StorageDurabilityAdapter
│   ├── presentation/                   # Reusable accessible UI components
│   │   ├── codex/                      # CodexPageShell, CodexHeaderConfig, CodexModeSelector, CodexFilterStrip
│   │   ├── core/                       # AccessibleActionTile
│   │   ├── screens/homebrew/           # HomebrewExpertOptionsView
│   │   └── widgets/                    # RoomConnectionBadge
│   ├── providers/                      # CharacterSheetController, SettingsProvider
│   ├── screens/                        # Primary screen layouts (Character Sheet, Builder, Arena, DPR, Codices, Compendiums, Party Room, DM Dashboard)
│   ├── services/                       # Persistence, ACL parsers & legacy rules engines
│   │   ├── acl/                        # CompendiumJsonIngestionPipeline, CompendiumPipeParser, StatBlockAclParser, EntryNodeTransformer
│   │   ├── party/                      # CampaignRegistryService, PartyRoomService, SessionGraphService
│   │   ├── persistence/                # AppDatabaseService (Hive/IndexedDB), CharacterPersistenceService, HomebrewPersistenceService, AppBackupService
│   │   ├── repository/                 # LayeredPriorityRepository (SRD / Homebrew / Campaign)
│   │   └── rules/                      # Dnd5eRulesEngine, AcEngineAndInventory, CharacterActionsResolver, CharacterProgressionEngine,
│   │                                   # CharacterReparseEngine, CharacterStatCalculator, CharacterValidationEngine, SpellcastingRulesEngine
│   ├── theme/                          # AppTheme: 9 fantasy accent palettes, OLED pitch black, domain UI extensions
│   ├── utils/                          # SecureRandom, CryptoUtils, DiceFormatters, PWA helpers
│   └── widgets/                        # Modular Flutter UI components
└── test/                               # Automated test suite
    ├── accessibility/                  # A11y touch targets & 2.0x dynamic type scaling tests
    ├── application/                    # Application service & orchestration tests
    ├── domain/                         # Domain purity & ingestion engine tests
    ├── infrastructure/                 # Adapters, DTOs, compliance, repositories, & D&D 5e module tests
    │   └── compliance/                 # SRD Legal Compliance & Product Identity Invariant Suite
    ├── services/                       # Persistence, ACL ingestion, & rules engine tests
    ├── theme/                          # Theme contrast & palette tests
    ├── utils/                          # Formatting & math utility tests
    └── widgets/                        # Widget interaction & modal tests
```

### External Engine Ownership (`vtt_engine_core`)
The following components reside in `../vtt-engine-core` and are consumed via `package:vtt_engine_core`:
- **CvRDT Primitives:** `HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`, `PnCounter`
- **Abstract Currency:** `ICurrencySystem`, `CurrencyDenomination`
- **Generic Domain Models & Value Objects:** `HitPoints`, `CoreTypes`, `EntityReference`, `LootContainer`, `CampaignProfile`, `PartyPurse`, `SessionGraphModels`, `RoomRoll`
- **Abstract Ports:** `ICampaignRepository`, `ICharacterRepository`, `IP2pTransportPort`, `INetworkTimePort`, `IRoomSyncPayloadPort`, `TransportState`
- **Ruleset SPI:** `IRulesetModule`, `ICombatResolver`, `RulesetEdition`
- **Agnostic Simulation:** `ISimulationStrategy`, `DprSimulator`, `PrecomputedAttack`, `CombatEffectRider`
- **Storage Durability Contracts:** `IStorageDurabilityPort`, `IPhysicalSnapshotPort`, `ICampaignSnapshotSerializerPort`, `EngineProfile`, `StorageSnapshotBundle`

### External Ruleset Ownership (`vtt_ruleset_dnd5e`)
The following components reside in `../vtt-ruleset-dnd5e` and are consumed via `package:vtt_ruleset_dnd5e`:
- **Ruleset Module & Capabilities:** `Dnd5eRulesetModule`, `Dnd5e2014Module`, `Dnd5e2024Module`
- **Combat Resolution:** `Dnd5eCombatResolver`, attack declaration & hit/damage resolution
- **Currency & Attributes:** `Dnd5eCurrencySystem`, `Dnd5eAttributeSystem`, `Dnd5eScoreMath`
- **Character Progression & Evaluation:** `CharacterProgressionEngine`, `CharacterEvaluationEngine`, `CharacterStatCalculator`
- **Spellcasting Engine:** `SpellcastingRulesEngine`, `SpellAllocationValidator`, multiclass slot progression
- **Mechanics & States:** `ExhaustionState`, `WeaponMastery`, rest mechanics, action economy
- **Canonical Domain Models:** `CharacterProgression`, `FeatureGrant`, `DndActionCost`, `SpellSchool`, `SpellClass`

---

## 🛡️ Core Engineering Directives

### 1. Architectural Boundaries & Semantic Ownership
- **Semantic Ownership Principle:** Reusable D&D mechanics belong in `vtt-ruleset-dnd5e`. Application orchestration and platform integration belong in the toolkit. Generic tabletop concepts belong in `vtt-engine-core`. Ownership follows semantics, not convenience or current call-site count. The toolkit should not silently re-grow a second internal D&D rules engine. Do not reimplement generic engine infrastructure locally merely because the toolkit needs customization; extend or adapt engine contracts at the ruleset/application boundary.
- **Architectural Dependency Direction:**
  ```
  vtt_engine_core (Agnostic Core)
  ↑
  vtt_ruleset_dnd5e (Reusable D&D 5e Domain & Rules Engine)
  ↑
  Application Orchestration (lib/application/services/, lib/application/storage/)
  ↑
  Presentation (lib/presentation/, lib/screens/, lib/widgets/)
  ```
- **Hexagonal Purity:**
  - Files in `lib/domain/` and `lib/infrastructure/dtos/` MUST NOT import `package:flutter/...`. Use pure Dart (`package:meta/meta.dart`). Verified by `test/domain/domain_purity_test.dart` and `test/infrastructure/dtos/dto_purity_test.dart`.
  - Application services orchestrate domain logic through abstract ports; they must never import concrete infrastructure adapters or DTOs directly.
  - Immutability: Domain entities and value objects must have `const` constructors and `copyWith()` mutators. In-place mutating methods are forbidden; use pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`).
  - Compatibility barrels in `lib/models/domain/` exist solely to preserve legacy import paths; do not treat them as canonical domain definitions.

### 2. Upstream Pinned Git Dependency Synchronization Protocol
`vtt_engine_core` and `vtt_ruleset_dnd5e` are consumed strictly via pinned Git dependencies (`ref: <commit-sha>`) in `pubspec.yaml`. Never treat the repositories as integrated merely because local working trees are compatible. When making upstream changes:
1. Complete and verify changes in the upstream repository (`../vtt-engine-core` or `../vtt-ruleset-dnd5e`) with `dart analyze` and `dart test`.
2. Commit upstream changes with DCO sign-off (`git commit -s`) to produce concrete commit SHAs on `main`.
3. If `vtt-engine-core` changed, synchronize `vtt-ruleset-dnd5e` first, verify it, and commit.
4. Update `pubspec.yaml` in this repository with the exact commit SHAs in `vtt_engine_core.git.ref` and `vtt_ruleset_dnd5e.git.ref`.
5. Ensure `pubspec_overrides.yaml` and `dependency_overrides` are eliminated.
6. Run `flutter pub get` so the pinned Git commits are actually fetched into the pub cache and locked in `pubspec.lock`.
7. Run `flutter analyze` and the test suite against the fetched Git dependencies before considering work complete.

### 3. Cross-Boundary Repository Pivot Protocol
When inspecting, editing, refactoring, or running commands inside `../vtt-engine-core`:
1. **Mandatory Ingestion:** The agent MUST read `../vtt-engine-core/.antigravityrules` and `../vtt-engine-core/AGENTS.md` before making any edits.
2. **Context Suspension:** For all files inside that target boundary, the agent MUST explicitly suspend and disregard host-specific guidelines (e.g., Flutter UI widgets, D&D 5e mechanics, 48dp touch targets, SRD compendiums) unless the engine's own rules independently require them.
3. **Local Governance:** The target repository's rules, pure Dart constraints, and compliance gates (`test/compliance/`) take absolute precedence for that directory.
4. **Core Isolation:** Never introduce D&D 5e mechanics, terminology, or Flutter UI into `vtt_engine_core` merely to simplify toolkit code.

### 4. Legal & SRD Compliance (Clean Room Policy)
- **Strict CC-BY-4.0 SRD 5.1 & 5.2.1 Content:** Bundled compendiums, fixtures, and code must contain ZERO Wizards of the Coast Product Identity terms (e.g., Beholder, Mind Flayer, Faerûn, Eberron, Hexblade, Artificer). Use generic SRD equivalents only.
- **Enforced via Invariant Suite:** `test/infrastructure/compliance/srd_legal_compliance_test.dart` audits all bundled static compendiums (`SrdClassesLibrary`, `SrdBackgroundsLibrary`, `SrdSpeciesLibrary`, `MonsterCodexLibrary`, `MagicItemLibrary`) on every run.
- **Zero Third-Party Tool Coupling:** Core logic must not contain proprietary site keys, splatbook abbreviations, or tool-specific bundle names. External pipe syntax (`Spell|Source#c`) is isolated into dedicated infrastructure ACL parsers (`CompendiumPipeParser`).
- **Unknown Stays Unknown (Anti-Hallucination):** Never synthesize or assume plausible tabletop defaults. Missing attributes remain `null`. Retain all unrecognized incoming keys in `unparsedPayload`.

---

## 📖 Subsystem Operating Rules

Detailed subsystem policies reside in `.agents/rules/`. Refer to each document for in-depth engineering directives:

- **Architecture & DDD:** [.agents/rules/architecture.md](file:///.agents/rules/architecture.md)
  - Detailed hexagonal boundaries, port/adapter structure, dependency injection with `get_it`, and clean-room ACL guidelines.
- **Distributed State & Sync:** [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md)
  - Convergence invariants, sub-resource reconciliation (`RoomStateReconciliationService`), `crdt_purse_delta` protocol, narrow mutex critical sections, 4-tier transport waterfall, and W3C polite peer glare handling.
- **D&D 5e Dual-Ruleset Mechanics:** [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md)
  - 2014 RAW vs 2024 Revised rules divergence, edition-locked characters, draft reconciliation, multiclass spellcaster progression math, action economy typing, and instant death decoupling.
- **Data Safety & Performance:** [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md)
  - Mandatory DTO isolation, bounds clamping, zero runtime regex in hot loops, `CombatEffectRider` numeric ASTs, isolate offloading, debounced storage, and 11-category backup parity.
- **Accessibility & UI Standards:** [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md)
  - 48x48dp minimum hit targets, screen reader semantics abbreviation expansion, responsive layouts up to `TextScaler.linear(2.0)`, and universal markdown table scrolling via `FormattedMarkdownText`.
- **Testing & Workflows:** [.agents/rules/testing_and_workflows.md](file:///.agents/rules/testing_and_workflows.md)
  - Fast feedback test targets, static analysis quality gates, production PWA build verification, and test suite setup reliability.
- **Codebase Fast Lookup Map:** [.agents/rules/codebase_map.md](file:///.agents/rules/codebase_map.md)
  - Quick-lookup directory and class index.

---

## ⚡ Fast Development & Test Workflows

```bash
# Domain purity & DTO purity (< 1s)
flutter test test/domain/domain_purity_test.dart test/infrastructure/dtos/dto_purity_test.dart

# SRD legal compliance & product identity invariant suite (< 2s)
flutter test test/infrastructure/compliance/srd_legal_compliance_test.dart

# Application state reconciliation & CRDT DTOs (< 2s)
flutter test test/application/services/room_state_reconciliation_service_test.dart test/infrastructure/dtos/crdt_dtos_test.dart

# Rules engine & dual-ruleset divergence tests (< 3s)
flutter test test/services/rules/dual_ruleset_divergence_test.dart test/services/rules/character_evaluation_engine_test.dart

# Static analysis (must report zero warnings/errors)
flutter analyze

# Verify web PWA bundle compilation
./scripts/build_web.sh
```

---

## 🔄 Living Documentation Protocol (Definition of Done)

Before completing any engineering task:
1. **Verification:** Ensure static analysis (`flutter analyze`) reports zero issues and relevant test suites pass.
2. **Living Documentation:** Update living documentation (`README.md`, `AGENTS.md`, or `.agents/rules/`) when architecture, public behavior, or documented capabilities change. Do not perform documentation churn for routine internal code changes.
