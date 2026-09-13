# Gemini / Antigravity AI Directives

This project enforces strict **Domain-Driven Design (DDD)**, **Hexagonal Architecture (Ports and Adapters)**, **CvRDT Distributed State Synchronization**, and **SRD 5.1 / 5.2 Dual-Ruleset Compliance**.

For full codebase documentation, directory maps, and engineering directives, see:
- [AGENTS.md](file:///AGENTS.md): Master AI Directives & Codebase Fast Navigation Index
- [.agents/rules/architecture.md](file:///.agents/rules/architecture.md): Hexagonal Architecture & Domain Purity
- [.agents/rules/crdt_and_sync.md](file:///.agents/rules/crdt_and_sync.md): CvRDT & Distributed State Directives
- [.agents/rules/dnd_rulesets.md](file:///.agents/rules/dnd_rulesets.md): 2014 RAW vs 2024 Revised Rules Matrix
- [.agents/rules/a11y_and_ui.md](file:///.agents/rules/a11y_and_ui.md): Accessibility (48x48dp, Semantics, 2.0x Dynamic Type)
- [.agents/rules/data_and_performance.md](file:///.agents/rules/data_and_performance.md): DTOs, `unparsedPayload`, and Precomputation
- [.agents/rules/testing_and_workflows.md](file:///.agents/rules/testing_and_workflows.md): Targeted Test & Build Commands

## Quick Rules Summary
1. **Domain & DTO Purity:** Files in `lib/domain/` and `lib/infrastructure/dtos/` MUST NOT import `package:flutter/...`. Use pure Dart annotations (`package:meta/meta.dart`). Verified by `domain_purity_test.dart` and `dto_purity_test.dart`.
2. **Ports & Adapters:** Interfaces go in `lib/domain/ports/`; implementations go in `lib/infrastructure/repositories/`.
3. **CvRDT Immutability & Safety:** `HybridLogicalClock`, `CrdtLwwRegister`, `CrdtOrSet`, and minion summons (`AnimatedObjectInstance`) mutations return new immutable instances. Use deterministic `nodeId` tie-breakers and implement `prune(threshold)`.
4. **DTO Safety:** Map JSON to DTOs in `lib/infrastructure/dtos/` with numeric bounds clamping and `unparsedPayload` retention.
5. **Asynchronous Stream Emission:** Broadcast StreamControllers in repositories MUST NOT use `sync: true` to prevent re-entrant deadlocks during mutex lock acquisition.
6. **A11y:** 48x48dp touch targets minimum, expand abbreviations in `Semantics` labels, support `TextScaler.linear(2.0)`.
7. **No Product Identity:** Strictly SRD 5.1 & 5.2 open content (CC-BY-4.0). Tests and code must use generic or invented homebrew names.
8. **Compendium Deduplication:** SrdEquivalenceIndex uses base SRD collections (`srdSpells`, `baseClasses`, etc.) unpolluted by homebrew; batch imports filter SRD canon by default (`excludeSrdCanon: true`); re-parse updates both Hive and SharedPreferences.
9. **Continuous Documentation & Living Rules Protocol:** Before completing any run, sync [README.md](file:///README.md) (features, tests, architecture) and audit/codify newly learned patterns or corrections into [AGENTS.md](file:///AGENTS.md), [GEMINI.md](file:///GEMINI.md), and [.agents/rules/](file:///.agents/rules/).
10. **System-Wide Backup Parity:** All backup services (`DmBackupService`, `AppBackupService`, `HomebrewPersistenceService`) must export and restore all 10 homebrew categories (`spells`, `monsters`, `items`, `classes`, `subclasses`, `races`, `subraces`, `feats`, `backgrounds`, `otherEntries`), reconciling standalone and orphan subraces without data loss.
11. **Combat Action Rider AST & Zero Runtime Regex:** Attack action descriptions are parsed at the ingestion boundary (`StatBlockAclParser.extractRiders`) into strongly-typed `CombatEffectRider` ASTs. During combat simulation (`ArenaCombatant.applyAttackHit`), attacks execute composite riders (`ConditionRider`, `AttributeDrainRider`, `MaxHpReductionRider`, `ForcedMovementRider`, `HealingSupressionRider`, `PeriodicDamageRider`) with zero runtime regex, clamping `effectiveMaxHp` and dynamically scaling down attack and saving throw modifiers.
12. **Subrace Character Builder Integration & Retention:** Character drafts track `subraceRef` (`EntityReference`), validated in `CharacterBuilderScreen` and resolved through `SkillTraitResolver.getSpeciesTraits(subraceSlug: draft.subraceRef?.slug)`. Subraces attached to SRD canon are indexed in `SrdSpeciesLibrary.customSubraces` and gathered during bundle exports to ensure zero loss of species lineages. Subrace selection UI wraps list items in `Material(color: ..., shape: RoundedRectangleBorder(...))` (without conflicting `borderRadius`) to prevent Flutter background assertions.
13. **Universal Item Codex & Character Sheet Cross-Loading:** `MagicItemLibrary.allItems` serves as the centralized source of truth synchronized from `HomebrewPersistenceService.syncToLibraries()` (`equipmentItemToMagicItem`). Homebrew items are browsable in `ItemCompendiumScreen`, assignable to any character roster sheet directly via `ItemDetailDialog`, addable within `CharacterSheetController.addItem()`, and selectable in the Character Builder equipment dialog.
14. **Universal Fluff & Lore Ingestion Pipeline:** Community compendium fluff bundles (including `monsterFluff`, `spellFluff`, `itemFluff`, `raceFluff`, `classFluff`, `subclassFluff`, etc.) and standalone fluff entries are recognized without artificial schema markers. Pure fluff maps infer entity categories from attributes (`className` -> `subclass`), image paths (`bestiary/` -> `monster`), or codex libraries. Two-pass deferred resolution resolves `_copy` references so variant lore and artwork are fully inherited. `IngestionBatchResult` and `HomebrewBundle` carry `List<EntityFluff> fluff`, seamlessly bridging background compute isolate boundaries into `EntityFluffService` and remote repository ingestion.

