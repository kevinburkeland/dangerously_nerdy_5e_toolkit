# Hexagonal Architecture & Clean DDD Rules

## 1. Architectural Layers & Boundaries

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│       lib/presentation/, lib/screens/, lib/widgets/    │
└───────────────────────────┬────────────────────────────┘
                            │ uses
┌───────────────────────────▼────────────────────────────┐
│                    Application Layer                   │
│        lib/application/services/, lib/application/storage/
└──────────────┬───────────────────────────┬─────────────┘
               │ uses                      │ orchestrates
┌──────────────▼─────────────┐ ┌───────────▼─────────────┐
│    Domain & Rules Layer    │ │  Infrastructure Layer   │
│ - lib/domain/ingestion/    │ │  lib/infrastructure/    │
│ - lib/models/ (5e Models)  │ │   - dtos/ & dtos/crdt/  │
│ - lib/services/rules/      │ │   - repositories/       │
│ - lib/infrastructure/      │ │   - adapters/ & mappers/│
│     modules/dnd5e/         │ │   - storage/ & di/      │
│  (consumes vtt_engine_core)│ └─────────────────────────┘
└──────────────▲─────────────┘
               │ implements SPI / consumes
┌──────────────┴─────────────┐
│      vtt_engine_core       │
│ (Agnostic tabletop engine: │
│  crdt, models, ports,      │
│  rules SPI, simulation)    │
└────────────────────────────┘
```

### 1.1. Upstream Engine & Ruleset Boundaries & Semantic Ownership
- **Semantic Ownership Principle:** Reusable D&D mechanics belong in `vtt-ruleset-dnd5e`. Application orchestration and platform integration belong in the toolkit. Generic tabletop concepts belong in `vtt-engine-core`. Ownership follows semantics, not convenience or current call-site count. The toolkit should not silently re-grow a second internal D&D rules engine.
- **Engine Extension Rule:** Do not reimplement generic engine infrastructure locally merely because the toolkit needs customization. Extend or adapt engine contracts (`IRulesetModule`, `ICombatResolver`, `ISimulationStrategy`, `IP2pTransportPort`) at the ruleset/application boundary.
- **Agnostic Core (`vtt_engine_core`):** Standalone tabletop domain models (`HitPoints`, `CoreTypes`, `CampaignProfile`, `PartyPurse`), CvRDT primitives (`HybridLogicalClock`, `CrdtOrSet`, `PnCounter`, `CrdtLwwRegister`), storage durability contracts, and ruleset SPI reside in `vtt_engine_core`.
- **Reusable Ruleset Module (`vtt_ruleset_dnd5e`):** Canonical D&D 5e dual-ruleset implementation, progression engines, spellcasting rules, combat arbitration, and canonical 5e domain models reside in `vtt_ruleset_dnd5e`.

### 1.2. Domain Layer (`lib/domain/`, `lib/models/`, `lib/services/rules/`)
- **Zero Flutter Engine Runtime:** Files in `lib/domain/` MUST NOT import `package:flutter/...`. Use pure Dart (`package:meta/meta.dart`). Enforced by `test/domain/domain_purity_test.dart`.
- **Domain Ingestion Engine (`lib/domain/ingestion/`):** Pure Dart document structure parser, candidate detector, and field extraction ASTs.
- **D&D 5e Domain Models (`lib/models/`):** Strongly typed 5e entities (`characters/`, `spells/`, `monster_codex/`, `magic_items/`, `weapon_mastery.dart`, `animated_object.dart`, `exhaustion_state.dart`).
- **Compatibility Re-export Barrels (`lib/models/domain/`):** Provide backward-compatible re-exports for historical import paths. These barrels must not be confused with canonical ownership.
- **D&D 5e Rules Engines (`lib/services/rules/`):** Concrete rules evaluation (`Dnd5eRulesEngine`, `AcEngineAndInventory`, `CharacterActionsResolver`, `CharacterProgressionEngine`, `CharacterReparseEngine`, `SpellcastingRulesEngine`).
- **Pure Models & Copy-Transforms:** Entities and value objects must have `const` constructors and `copyWith()` mutators. In-place mutating methods (`takeDamage`, `heal`, `applyHeal`, `grantTempHp`) are strictly forbidden; use pure copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`).

### 1.3. Application Layer (`lib/application/`)
- Orchestrates workflows between domain rules, engine abstractions, and infrastructure ports.
- Application services (e.g., `RoomStateReconciliationService`, `CombatEncounterService`, `RoomSyncOrchestrator`, `StorageDurabilityCoordinator`, `PartyRoomService`) hold no long-term persistent state; they process domain events, coordinate CRDT state, invoke rules, and delegate I/O to ports.
- Application services MUST NOT import infrastructure DTOs or concrete adapters directly.

### 1.4. Infrastructure Layer (`lib/infrastructure/`)
- Implements engine and toolkit ports.
- **Pluggable D&D 5e Ruleset Module (`lib/infrastructure/modules/dnd5e/`):** Implements `vtt_engine_core`'s `IRulesetModule` and `ICombatResolver` (`Dnd5e2014Module`, `Dnd5e2024Module`, `Dnd5eCombatResolver`, `Dnd5eCurrencySystem`).
- **Repositories (`lib/infrastructure/repositories/`):** Persistence implementations (`LocalCampaignRepository`, `LocalCharacterRepository`) satisfying `ICampaignRepository` and `ICharacterRepository`.
- **Adapters (`lib/infrastructure/adapters/`):** Transport (`LocalWifiAdapter`, `WebRtcMeshAdapter`, `FirebaseFallbackAdapter`), signaling (`FirebaseSignalingAdapter`), storage serializers (`CampaignSnapshotSerializerAdapter`), and remote ingestors (`GithubIngestorAdapter`).
- **DTOs (`lib/infrastructure/dtos/`):** Translate wire/disk JSON to domain models and vice versa. Files in `lib/infrastructure/dtos/` must not import Flutter; use `package:meta/meta.dart` for `@immutable` (enforced by `test/infrastructure/dtos/dto_purity_test.dart`).
- **Dependency Injection (`lib/infrastructure/di/`):** Service Locator (`injection_container.dart` / `sl`) registers singletons and factories. Downcasting ports to concrete implementations (e.g., `transportPort as CascadingTransportRouter`) is strictly prohibited.

### 1.5. Presentation Layer (`lib/presentation/`, `lib/screens/`, `lib/widgets/`)
- User interface and rendering only.
- Zero business logic, rule evaluations, or raw dice math. All mechanics are delegated to application services or domain rules. State consumption routes through providers and controllers (`lib/providers/`).

### 1.6. Clean Room Anti-Corruption Layer (ACL)
- **Zero Third-Party Tool Coupling:** Core logic must not contain proprietary site keys, splatbook abbreviations, or tool-specific bundle names.
- **Agnostic Structural Ingestion:** Ingestion adapters dynamically traverse payloads using generic structural indicators (`name`, `entries`, `hitDie`, `stats`, `type`, `level`, `actions`).
- **External Syntax Isolation:** External pipe-delimited syntax (`Feature|Class|Source|Level`, `Spell|Source#c`) is isolated into dedicated infrastructure ACL parsers (`CompendiumPipeParser`).
- **Capability-Driven Mechanics:** Combat calculations, attack substitutions, and capabilities must resolve via domain `FeatureGrant`s (`GrantType.attackAbilitySubstitution`, `GrantType.capabilityFlag`) or normalized capability flags (`flags['initiativeBonusMode']`). Never pattern match on non-SRD class, subclass, or feat names.

### 1.7. Cross-Boundary Repository Pivot Protocol
When inspecting, editing, or executing commands in an external repository (such as `../vtt-engine-core`):
1. **Mandatory Ingestion:** The agent MUST view and parse `../<target-repo>/.antigravityrules` and `../<target-repo>/AGENTS.md` before making any modifications.
2. **Context Suspension:** For any code inside that target repository, the agent MUST explicitly suspend and disregard host-specific guidelines (e.g., Flutter UI widgets, D&D 5e mechanics, 48dp touch targets, SRD legal compendiums).
3. **Local Governance:** The target repository's rules, pure Dart constraints, and compliance gates (`test/compliance/`) take absolute precedence for that directory.
4. **Core Isolation:** Never introduce D&D 5e mechanics or Flutter UI into `vtt_engine_core` merely to simplify toolkit code.

### 1.8. Upstream Pinned Git Dependency Synchronization
- `vtt_engine_core` and `vtt_ruleset_dnd5e` are consumed strictly via pinned Git dependencies (`ref: <commit-sha>`) in `pubspec.yaml`.
- Whenever upstream changes occur:
  1. Commit upstream changes with DCO sign-off (`git commit -s`) to produce concrete commit SHAs on `main` in `../vtt-engine-core` or `../vtt-ruleset-dnd5e`.
  2. If engine changed, update and verify `vtt-ruleset-dnd5e` first and commit.
  3. Update `pubspec.yaml` with the new commit SHAs in `vtt_engine_core.git.ref` and `vtt_ruleset_dnd5e.git.ref`.
  4. Ensure `pubspec_overrides.yaml` and `dependency_overrides` are eliminated.
  5. Run `flutter pub get` so the pinned Git commits are actually fetched into the pub cache and locked in `pubspec.lock`.
  6. Run `flutter analyze` and `flutter test` against the fetched Git dependencies before considering work complete.
