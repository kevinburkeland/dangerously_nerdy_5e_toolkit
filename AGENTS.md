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
│   │   ├── models/                     # Immutable entities: AnimatedObject, CampaignProfile, WeaponMastery
│   │   │   └── value_objects/          # Value objects: HitPoints
│   │   ├── ports/                      # Abstract interfaces: ICampaignRepository, ICharacterRepository, IPartySyncPort
│   │   ├── rules/                      # Pure mechanical contracts: RulesetContext
│   │   └── simulation/                 # Simulation contracts: DprSimulator, PrecomputedAttack
│   ├── application/                    # Use Cases & Orchestration
│   │   └── services/                   # RoomStateReconciliationService, CombatEncounterService, PartyRoomService
│   ├── infrastructure/                 # Adapters, DTOs & Concrete I/O
│   │   ├── di/                         # Service Locator: injection_container.dart (sl)
│   │   ├── dtos/                       # CharacterDto, CampaignProfileDto, AnimatedObjectDto
│   │   │   └── crdt/                   # HybridLogicalClockDto, CrdtLwwRegisterDto, CrdtOrSetDto
│   │   ├── repositories/               # LocalCampaignRepository, LocalCharacterRepository
│   │   └── resolvers/                  # CharacterTelemetryResolver
│   ├── presentation/
│   │   └── core/                       # Accessible core widgets: AccessibleActionTile
│   ├── providers/                      # CharacterSheetController, SettingsProvider
│   ├── screens/                        # Top-level screen layouts (Character Sheet, Arena, DPR, Compendiums)
│   ├── services/                       # Legacy services, ACL parsers, rules engines, persistence
│   │   ├── acl/                        # 5etools AST transformers & JSON ingestion pipeline
│   │   ├── persistence/                # Hive / IndexedDB storage & web lifecycle flusher
│   │   ├── repository/                 # LayeredPriorityStore (SRD / Homebrew / Campaign)
│   │   └── rules/                      # AcEngineAndInventory, CombatRulesEngine, Dnd5eRulesEngine, etc.
│   ├── theme/                          # AppTheme: 9 fantasy accent themes & OLED black
│   ├── utils/                          # SecureRandom, CryptoUtils, DiceFormatters
│   └── widgets/                        # Modular UI components, dialogs, charts, and vector glyphs
├── test/                               # Comprehensive test suite (1,297 passing tests)
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
- **Ports & Adapters:** Define abstract interfaces in `lib/domain/ports/`. Implementations live in `lib/infrastructure/repositories/`.
- **Immutability:** All domain models and value objects must have `const` constructors and `copyWith()` mutators. Never expose mutable lists or maps directly.

### 2. Decentralized State & CvRDT Directives
- **Hybrid Logical Clock (HLC):** Implements `Comparable`. When physical timestamps (`l`) and counters (`c`) collide, use `nodeId` (device ID string) as the deterministic lexicographical tie-breaker. Random tie-breakers are strictly forbidden.
- **Observed-Remove Set (`CrdtOrSet`):** Deletions create tombstones. Always implement `prune(threshold)` to prevent memory leaks from unbounded tombstone accumulation.
- **LWW Register (`CrdtLwwRegister`):** Modifications return a new immutable instance.
- **Delta Fast-Forward:** Base room state is hydrated from snapshot milestones, with incremental CRDT deltas reconciled on top via `RoomStateReconciliationService`.

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
