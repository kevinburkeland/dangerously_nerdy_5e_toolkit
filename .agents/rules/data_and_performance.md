# Data Safety, DTOs & Performance Directives

## 1. DTO Isolation & Anti-Corruption Layer (ACL)

External JSON (network streams, local Hive databases, compendium bundles) must NEVER be cast directly into Domain entities.

- **DTO Mapping:** Parse incoming JSON into Data Transfer Objects (`lib/infrastructure/dtos/`) first, then convert to Domain models via `.toDomain()`.
- **Fault-Tolerant Defaults:** If a field is missing, null, or has an unexpected type, DTOs must provide safe tabletop fallback defaults instead of crashing.
- **Unparsed Payload Preservation:**
  - Users frequently import homebrew with custom attributes, extra tags, or future schema additions.
  - Every DTO must retain unrecognized keys in an `unparsedPayload` map (`Map<String, dynamic>`).
  - When re-serializing to JSON (`toJson()`), merge `unparsedPayload` back into the output map to prevent data loss across schema migrations.
- **Infrastructure DTO Purity:**
  - Files in `lib/infrastructure/dtos/` must remain completely decoupled from the Flutter engine runtime.
  - Import `package:meta/meta.dart` for `@immutable` annotations; never import `package:flutter/...`.
  - Automatically audited by `test/infrastructure/dtos/dto_purity_test.dart`.
- **Zero Third-Party Tool (5etools) Schema Coupling:**
  - Strict prohibition against hardcoded 5etools bundle lists (e.g. `monsterfluff`, `racefluffmeta`, `subclassfeature`) or proprietary site keys in ingestion workflows.
  - All remote bundle ingestion (`GithubIngestorAdapter`) must recursively inspect JSON structures using generic indicators (`name`, `entries`, `hitDie`, `stats`, `type`, `level`, actions) rather than specific third-party site keys.
  - Pipe-delimited external tokens (`Feature|Class|Source|Level`, `Spell|Source#c`) must be parsed at the ACL boundary via `CompendiumPipeParser` and converted into clean `FeatureGrant` and domain models. Unmapped attributes are preserved in `unparsedPayload`.

## 2. Tabletop Bounds & Numeric Clamping

Never trust raw numeric values from JSON or user input:
- HP: Clamp to `0..999`
- Character Level: Clamp to `1..20`
- Ability Scores: Clamp to `1..30` (or `1..20` for standard character limits)
- Currency: Clamped to non-negative integers (`value >= 0`); overdraft spends must be clamped to zero and flagged.
- Spell Slot Level: Clamp to `0..9`

## 3. Performance & Pre-Computation

- **Zero Runtime Regex in Hot Loops:**
  - DO NOT execute regular expressions (`RegExp`) inside combat loops, Monte Carlo simulations (500x/1,000x runs), or DPR binomial calculations.
  - String traits and action syntax (e.g., multiattack text, attack dice strings) must be pre-parsed and cached as numeric value objects or structs during ingestion/initialization.
- **Combat Action Rider AST & ACL Extraction:**
  - Action descriptions are parsed at the ACL boundary (`StatBlockAclParser.extractRiders`) using pre-compiled regex into strongly-typed `CombatEffectRider` ASTs (`ConditionRider`, `AttributeDrainRider`, `MaxHpReductionRider`, `ForcedMovementRider`, `HealingSupressionRider`, `PeriodicDamageRider`).
  - During combat simulation (`ArenaCombatant.applyAttackHit`), composite riders execute with zero runtime regex, clamping `effectiveMaxHp` and dynamically scaling down attribute-dependent attack and saving throw modifiers.
- **Background Isolates for Large Imports:**
  - When ingesting multi-megabyte community or homebrew compendiums, offload parsing to background isolates (`compute()` or dedicated isolates) to maintain 60/120fps UI responsiveness.
- **Search Pre-computation:**
  - Spellbook and compendium searches must use tokenized search indices rather than filtering full text collections on every keystroke.

## 4. Single-Source Persistence & Debounced Disk I/O

- **Single Storage Engine Truth:**
  - Repositories (`LocalCampaignRepository`, `LocalCharacterRepository`) must persist strictly to Hive/IndexedDB boxes (`AppDatabaseService`). Dual-writing to `SharedPreferences` during regular saves is prohibited.
  - `SharedPreferences` reads are strictly isolated as legacy fallback inside `loadAllProfiles()` / `loadCharacters()` when the primary database box is empty.
- **Debounced Disk Writes & In-Memory Caching:**
  - Rapid character mutations must update an in-memory cache immediately and debounce disk persistence via `AppServices.instance.debouncedStorage.scheduleWrite` (300ms default) to avoid main-thread I/O bottlenecks.
  - When widget tests trigger state changes, ensure test frames advance past debounce durations (`pump(const Duration(milliseconds: 400))`) and always invoke `AppServices.reset()` in `tearDown()` to cancel pending debounce timers.

## 5. Spell Normalization & Ingestor ACL Pre-Computation

To ensure regex-free simulation in hot loops (DPR Monte Carlo runs):
- **Levelled Scaling Extraction:** `higherLevelsMarkdown` dice formulas (e.g. `1d6`) must be extracted into `damageMath.scalingFormula` during ingestion rather than parsed at runtime.
- **Variable Damage Types:** Spells with selectable or randomized damage types (e.g. Chromatic Orb, Chaos Bolt) must resolve `damageType` to `variable` / `DamageType.variable` to avoid false defaults like `acid`.
- **Range & Spatial Geometry:** Natural language ranges (e.g. `"30-foot line"`, `{"type": "line", "distance": {"amount": 30}}`) must normalize into `rangeDistanceFeet` (int) and `rangeType` (string/enum: `"line"`, `"cone"`, `"radius"`, `"self"`, `"touch"`, `"ranged"`). Touch and self default to 0 feet.
- **Multi-Stage Delivery Flags:** Multi-stage damage payloads (e.g., Ice Knife) must pre-tag delivery mechanisms on `EvaluationMath` (`isAttackRoll`, `requiresSave`) to avoid runtime NLP during combat resolution.

## 6. Strict Entity Resolution & Anti-Collision Directives

- **Priority Exact Equality:** Telemetry and codex lookup methods (`CharacterTelemetryResolver`, `MonsterCodexLibrary.getMonsterByName`, `SrdSummonsLibrary.findStatBlockByName`) must prioritize exact `==` equality matches first against canonical and homebrew IDs and names.
- **Prohibition of Loose Substring Matching:** Loose substring checks (e.g. `contains('plate')`) are strictly prohibited because they cause cross-category stat collisions (e.g., Breastplate incorrectly binding to Full Plate). Use strict slug normalization (`armorBase`, `weaponBase`, exact slug equality).
- **Word-Boundary Regex on Fallbacks:** When fuzzy or partial fallback matching is necessary, enforce word-boundary tokens (`\b`) and disallow binding generic tokens (e.g., `'Dragon'`) to compound boss monsters (e.g., `'Dragon Turtle'`).

## 7. Monte Carlo Simulation Structural Sharing (fast_immutable_collections)

- **Zero-Allocation Cloning:** In simulation loops (`ArenaCombatEngine`, `DprSimulator`) running thousands of iterations (e.g., 500x/1,000x/10,000x runs), mutable Dart collections (`List`, `Set`, `Map`) produce excessive GC pressure and memory spikes when copied (`Set.from()`, `List.from()`).
- **Defensive State Deep-Copying (Immutable Data Sharing):** State instances in simulation rounds must use immutable data structures (`fast_immutable_collections`) or immutable copy-transforms (`applyDamage`, `applyHealing`, `applyTempHp`) to prevent state corruption across iterations.
- **Instantaneous `.clone()` and `.reset()`:** `.clone()` and `.reset()` pass collections directly by reference without re-allocating memory.
- **Collection Agnosticism:** UI components displaying these collections (e.g. `ArenaConditionChipsBar`) must accept generic `Iterable<T>` to seamlessly render both standard and immutable collections.

## 8. Explicit-Ruleset Homebrew Ingestion Directives

- **Explicit Ruleset Pre-Selection Mandate:**
  - Remote repository ingestion (`IGithubIngestorPort`, `GithubIngestorAdapter`) requires explicit user pre-selection of `RulesetVersion.srd2014` or `RulesetVersion.srd2024`.
  - Heuristic ruleset auto-detection is strictly forbidden to protect CRDT ledger health.
- **Strict Anti-Corruption Layer (ACL) Schema Validation:**
  - `HomebrewEntityDto` validates incoming JSON strictly against the target ruleset.
  - `srd2014`: Must reject 2024 Weapon Masteries, linear 10-step exhaustion models, and Background-bound ASIs / Origin Feats.
  - `srd2024`: Must reject legacy bonus-action spell restriction clauses and Species/Race-bound ASIs.
  - Rejected or corrupted entries must return `IngestionSkipResult` containing failure metadata without terminating the batch import stream.
- **Repository Manifest Filtering & Bundle Unpacking:**
  - Remote git repositories contain metadata and build artifacts (`package.json`, `tsconfig.json`, `.github/`). Manifest discovery must filter out non-content tooling configs.
  - Community JSON files are bundles whose root maps contain entity collections (`"monster": [...]`, `"spell": [...]`, `"item": [...]`) or root JSON arrays (`[{...}]`), lacking a top-level `name` attribute. Ingestors must unpack each individual entity rather than treating the file root map as a single entity.
  - Files containing only metadata (such as `_meta` blocks) without valid tabletop entities must cleanly yield `IngestionSkipResult` rather than throwing missing `name` attribute validation errors.
  - Support fallback entity name properties (`title`, `label`, `header`) when canonical `name` is omitted.
- **Batch Ingestion Persistence & Deferred Library Sync:**
  - Ingested entities must be persisted in batches (default 50 entities per batch + final flush on completion) via `HomebrewPersistenceService.saveHomebrewEntitiesBatch(..., syncLibraries: false)` to eliminate redundant disk scans.
  - Upon batch completion, trigger `HomebrewPersistenceService.syncToLibraries()` once to hydrate all runtime codices (`MonsterCodexLibrary`, `SpellbookLibrary`, `ItemCodexLibrary`, etc.).
- **Bounded Concurrency & Isolate Threshold:**
  - Remote file downloads use a bounded worker pool limited to maximum **6 concurrent HTTP connections**.
  - Offload JSON decoding and schema validation to `Isolate.run()` on native platforms only when payload size $\ge$ 64 KB (`isolateThresholdBytes`). Payloads smaller than 64 KB are decoded directly on the event loop to avoid isolate spawn overhead.
  - Telemetry updates emitted by `HomebrewImportOrchestrator` are throttled to at most 10Hz (100ms interval) to prevent UI thread frame drops.
- CRDT Ledger Integration:
  - Validated entities are stamped with monotonic `HybridLogicalClock` timestamps and committed to `CrdtOrSet<HomebrewEntity>`.
  - Outbound telemetry and progress streams must enforce `sync: false` to prevent re-entrant deadlocks.

## 9. Subclass Expanded Spell & Query Filter Resolution Directives

- **Compendium Filter Expression Parsing:**
  - Community compendium and homebrew formats encode subclass expanded spell options using `additionalSpells` containing query filter expressions under `'all'` or `'choose'` keys (e.g., `{"all": "level=0|class=Cleric"}`).
  - `SubclassSpellsLibrary` extracts filter strings via `extractFilterStrings()` and evaluates them against registered spells via `resolveFilterSpells()`, matching by `level`, `class`, `school`, and `ritual` clauses.
- **Canonical Full-List Grants (Divine Soul Sorcerers):**
  - Divine Soul Sorcerers (5e RAW Divine Magic) learn spells from both the Sorcerer and Cleric spell lists (cantrips through 9th level).
  - `SubclassSpellsLibrary.isExpandedSpell()` and `getExpandedSpells()` provide canonical fast-paths (`classSlug == 'sorcerer' && cleanSub.contains('divine')`) returning `true` for Cleric spells with O(1) enum lookups, avoiding runtime regex loops.
- **UI Presentation for Expansive Lists (>25 Spells):**
  - In subclass detail cards (`ClassDetailDialog._buildSubclassSpellsChips`), expansive subclass grants (>25 spells) must render a concise summary banner ("DIVINE MAGIC: FULL CLERIC SPELL LIST") alongside distinct affinity/bonus spells, rather than overwhelming the card with 100+ wrapped chips, while fully populating the class's master spell list table.

## 10. Homebrew Spell Class Preservation & Collision Synchronization Directives

- **Nested `customProperties` Elimination:**
  - When deserializing homebrew spells via `CompendiumSpellParser.parseSpell` or `Spell.fromMap`, explicitly unpack nested `customProperties` maps (`cp['customProperties']`) and exclude `'customProperties'` from auxiliary capture in `_standardSpellKeys` to prevent recursive nesting during re-serialization.
- **Robust Class Extraction across Formats:**
  - `CompendiumSpellParser` and `HomebrewPersistenceService.spellToSpellItem` must inspect root `classes`, nested `customProperties.classes`, and auxiliary `customProperties['classes']`.
  - When `classes` is a Map, parse `fromClassList`, `fromClassListVariant` (optional class features), and `fromSubclass` (`sub['class']`).
  - When `classes` is a List or String, strip any `SpellClass.` prefix and match against canonical `SpellClass` enum labels and names.
  - If a spell lacks classes after ingestion, fall back to canonical SRD or known expansion tables (`extractClassesForSpell`) to dynamically revitalize class associations.
- **Import Collision Selection Synchronization:**
  - In `HomebrewMergeResolver.applyResolutionToAllCollisions` and `HomebrewImportPreviewDialog`, changing collision resolution to `overwrite` or `duplicateRename` must automatically synchronize `isSelected = true`, and toggling `isSelected = true` on a collision item must elevate resolution from `keepLocal` to `overwrite` to prevent silent omissions during batch imports.

## 11. Community Bundle Ingestion Remediation Directives

- **Spell Spatial Range Revitalization:**
  - Community compendiums frequently serialize `range` as natural text (`"150 feet"`, `"30 feet"`) or structured maps (`{"type": "point", "distance": {"type": "feet", "amount": 150}}`) while leaving `rangeDistanceFeet: 0`.
  - `HomebrewIngestor.normalizeRange` and `Spell.fromMap` must evaluate distance and type whenever `rangeDistanceFeet <= 0`.
  - Deserialization must extract geometric shapes (`line`, `cone`, `radius`, `sphere`) from description markdown when the raw range type is ambiguous.
- **Deep Feat Grant Extraction:**
  - Feats with `additionalSpells` or `spells` encode spell pools inside nested sub-maps (such as `innate` / `known` -> `daily`, `ritual`, `will`, `_`).
  - Parsers must recursively extract all spell identifiers across nested dictionary tiers, creating atomic `FeatureGrant.bonusSpell` entries.
  - Skill choices (`skillProficiencies` with `choose`) and tool proficiencies (`toolProficiencies`) must be converted to `FeatureGrant.bonusSkillChoice` and `FeatureGrant.weaponArmorProficiency` rather than dropped.
- **Background `_copy` Fallback Non-Empty Guarding:**
  - Background entries in community packs often inherit from base backgrounds (e.g. `_copy: {"name": "Acolyte"}`) while providing empty collections (`skillProficiencies: []`, `toolProficiencies: []`, `languageProficiencies: []`, `originFeat: null`).
  - `CompendiumBackgroundParser` and `CompendiumJsonIngestionPipeline` must guard lookups with `_isNonEmpty` checks, ensuring that empty collections on child entries do not shadow or overwrite non-empty proficiencies, tools, languages, and origin feats on the parent base.
- **Subclass Expansion & Dunamancy Filter Expansion:**
  - Subclasses containing source queries (e.g., `{"all": "source=EGW"}`) must resolve against tagged spells.
  - `SubclassSpellsLibrary.resolveFilterSpells` expands `source=EGW` and `dunamancy` to match spells tagged with `dft`, `sgt`, `sct`, `dunamancy`, or `source:egw`.
  - `HomebrewPersistenceService.spellToSpellItem` automatically enriches tags with source identifiers and dunamancy school tags to ensure dynamic subclass filters match seamlessly.
- **SRD Background Purity & In-Bundle Resolution:**
  - `SrdBackgroundsLibrary._baseBackgrounds` strictly contains `acolyte` (the sole background published in SRD 5.1 & 5.2 under CC-BY-4.0). Hardcoding non-SRD backgrounds into base libraries is strictly forbidden.
  - `_resolveBaseBackground` checks in-bundle / local compendium lookups (`localLookup`) and registered custom backgrounds.
  - When copying an external un-imported background leaving `skillProficiencies: []`, apply the canonical SRD 5.1 "Customizing a Background" rule (*SRD 5.1 p. 60: "choose any two skills"*), granting a flexible 2-skill choice (`FeatureGrant.skillChoice`) so the background remains playable during character creation.
- **Round-Trip Lossless Serialization (`Spell.toMap` & `Feat.fromMap`):**
  - `Spell.toMap()` explicitly serializes top-level `'classes'` from `customProperties['classes']` and numeric `rangeDistanceFeet` so exported bundles retain root attributes without degradation across re-downloads.
  - `Feat.fromMap()` auto-heals empty `grants` from `additionalSpells` or `spells` upon bundle deserialization.
  - `CompendiumJsonIngestionPipeline._revitalizeBundle` preserves `grants: reparsed.grants.isNotEmpty ? reparsed.grants : f.grants` when revitalizing feats.

## 9. Homebrew Compendium Ingestion, SRD Deduplication & Category Routing

- **SRD Index Isolation from Homebrew Pollution:**
  - `SrdEquivalenceIndex.build()` MUST ONLY query base canonical SRD collections (`SpellbookLibrary.srdSpells`, `SrdClassesLibrary.baseClasses`, `SrdSpeciesLibrary.baseSpecies`, `SrdFeatsLibrary.baseFeats`, `SrdBackgroundsLibrary.baseBackgrounds`, and `MonsterCodexLibrary.allMonsters.where(!m.isHomebrew)`).
  - Never query `.all*` getters that combine SRD and `_custom*` entities; doing so causes active homebrew to be indexed as SRD canon and subsequently purged during re-parsing.
- **Slug Normalization & Prefix Tolerance:**
  - Slug generation must consistently strip apostrophes (e.g., `_slugify("Hunter's Mark")` -> `hunters-mark`).
  - Deduplication matching (`SrdEquivalenceIndex.checkEntity`) must unify hyphenated possessives (`-s-` -> `s-`) and strip class prefixes from subclasses (`rogue-thief` -> `thief`).
- **Batch Deduplication by Default:**
  - `HomebrewPersistenceService.saveHomebrewEntitiesBatch` enforces `excludeSrdCanon: true` by default to prevent third-party JSON dumps from saving hundreds of duplicate base SRD entries into user homebrew storage.
- **Compendium Category Routing:**
  - `baseitem` and `magicvariant` must route into `items` (`saveCustomItemsBatch`).
  - `subrace` must route into `races` (`saveCustomRacesBatch`) and attach to parent race definitions.
  - `table` entries must be rendered into markdown tables using `colLabels` and rows.
  - `deity` entries must format structured metadata headers (Pantheon, Alignment, Domains, Symbol).
- **Codex & Rules Cross-Tool Runtime Propagation & Individual Toggling:**
  - `HomebrewPersistenceService._hydrateCustomOtherSubsystems` automatically projects generic compendium entries (`HomebrewOtherCategory`) across the entire toolkit:
    - `HomebrewOtherCategory.tables` map via `compendiumEntryToRollableTable` to `SrdTablesLibrary.setCustomTables` with dynamic dice formula detection, rendering under the `TableCategory.custom` ("Homebrew & Codex") chip in `TableIndexScreen`.
    - `trapsAndHazards`, `conditionsAndDiseases`, `deities`, `vehicles`, `charmsAndRewards`, and `rulesAndReference` map via `compendiumEntryToDmReferenceItem` to `DmScreenLibrary.setCustomItems`, rendering in `RulesCompendiumScreen` and `DmDashboardScreen`.
    - `characterOptions` (maneuvers, metamagic, boons) map to `SrdFeatureOptions.setCustomCharacterOptions`, resolving through `SrdFeatureOptions.allOptions` in `CharacterActionsResolver` and Character Sheet ability traits.
    - Hydration runs automatically on startup (`initLibraries`), single/batch saves, single/batch deletes, and granular category prunes (`clearOtherEntriesByCategories`).
  - **Individual Rule Toggling (`isEnabled`):**
    - Every `HomebrewCompendiumEntry` includes an `isEnabled` boolean flag (default `true`).
    - Disabled rules remain stored in persistence but are strictly filtered out (`activeOthers = others.where((e) => e.isEnabled).toList()`) during `_hydrateCustomOtherSubsystems`.
    - `HomebrewPersistenceService.toggleOtherEntryEnabled(slug, {isEnabled})` updates the entry, persists to disk, and triggers immediate re-hydration.
    - `HomebrewStudioScreen` (Codex & Rules tab) displays adaptive toggle switches on each rule tile and detail dialog, dimmed visual indicators and 'Disabled' badges on inactive items, and contextual `Active` / `Disabled` filter chips when disabled rules are present.
    - `DmRuleComparisonDialog` and `DmRuleCard` visually highlight homebrew rules with pink badges and provide one-tap deactivation.
- **Strict Avoidance of Non-SRD WotC Product Identity:**
  - All test fixtures, mock data, and documentation must strictly use generic SRD content or invented homebrew names (e.g., "Chronoblast", "Astral Knight", "Sand Corsair Captain").

## 10. Complete Homebrew Bundle Export & Nested Species Ability Extraction

- **Comprehensive Bundle Exporter:**
  - `HomebrewPersistenceService.exportBundle` and `exportHomebrewBundle` serialize all active homebrew registries (`races`, `subraces`, `classes`, `subclasses`, `backgrounds`, `feats`, `items`, `spells`, `monsters`, `otherEntries`).
  - Subraces are extracted from `races.expand((r) => r.subraces)` and serialized as a sibling array (`subraces`) in the root export map and within `HomebrewBundle.subraces`.
- **Nested Species Ability Parsing (Variant Lineage Support):**
  - Subraces and species entries containing `raceName` or `subrace` keys must be classified as `'race'` by `HomebrewEntityDto._detectEntityType`.
  - `_extractSpeciesAbilities` in `HomebrewEntityDto` extracts both fixed stat boosts (root-level `str..cha`, nested maps, and array items) into `normalizedData['abilities']` and flexible choice blocks (`choose: { from: [...], count: ..., amount: ... }`) into `normalizedData['flexibleAbilities']`.
  - `HomebrewIngestor.mapRaceFromDto` maps `abilities` to `Race.fixedAbilityBonuses` and `flexibleAbilities` to `Race.flexibleAbilityCount`, `flexibleAbilityBonus`, and preserves the complete choice pool under `customProperties['flexibleAbilities']` without data loss.

## 11. System-Wide Backup Parity & Subrace Reconciliation

- **System-Wide Backup Parity:**
  - `AppBackupService`, `DmBackupService`, and `HomebrewPersistenceService` must maintain 100% coverage across all potential homebrew categories: `customSpells`, `customMonsters`, `customItems`, `customClasses`, `customSubclasses`, `customRaces`, `customSubraces`, `customFeats`, `customBackgrounds`, and `customOtherEntries`.
- **Subrace Reconciling & Shell Generation:**
  - When importing bundles or restoring snapshots, `HomebrewBundle.fromMap`, `AppBackupService.importFullBackupJson`, and `DmBackupService.restoreFullSystemSnapshot` must reconcile standalone `subraces` with parent `races`, and synthesize parent shells for orphan subraces referencing base SRD species (such as Human, Elf, Dwarf), guaranteeing zero entity loss.
  - Sibling serialization ensures both flat array lookups (`customSubraces`) and parent-child hierarchy (`race.subraces`) remain in sync across all backup and export formats.

## 12. Universal Fluff & Lore Ingestion Pipeline & Isolate Bridging

- **Dynamic Fluff Bundle Key Detection:**
  - Ingestion manifests and JSON bundle parsers (`CompendiumJsonIngestionPipeline.hasBundleKeys`, `GithubIngestorAdapter.foundBundleKeys`) dynamically accept any key where `lower.endsWith('fluff') && map[k] is List` along with specific compendium keys (`monsterfluff`, `spellfluff`, `itemfluff`, `racefluff`, `classfluff`, `subclassfluff`, `featfluff`, `backgroundfluff`, `optionalfeaturefluff`, `conditionfluff`, `trapfluff`, etc.).
  - Remote file discovery in `GithubIngestorAdapter` must not treat fluff bundles as repository tooling or metadata artifacts.
- **Authentic Single Fluff Map Detection:**
  - Standalone fluff files often contain pure lore maps (`name`, `entries`, `images`, `_copy`) without artificial `_fluff` or `fluffType` marker keys.
  - `isSingleFluff` inspects keys: if the object possesses name/title and lore structures (`entries`, `entry`, `images`, `_copy`, `lore`) while completely lacking mechanical statblock identifiers (`cr`, `school`, `hd`, `rarity`, `classFeatures`, `subclassFeatures`, `speed`, `size`), it is accurately classified as fluff.
  - Entity types are inferred from context (`className` -> subclass, image paths -> monster, or codex lookup fallbacks).
- **Two-Pass Deferred `_copy` Resolution:**
  - Ingestors must not discard fluff entries utilizing community compendium `_copy` mechanics (e.g. referencing a base creature or spell).
  - Fluff ingestion parses self-contained entries first, followed by a second pass that copies `loreMarkdown` and `images` from target base entities.
- **Isolate Port Fluff Bridging:**
  - Background isolate parsing (`compute(_parseJsonInIsolate, ...)`) cannot mutate in-memory singleton state (`EntityFluffService`) across isolate memory boundaries.
  - `IngestionBatchResult` must carry `final List<EntityFluff> fluff;` across the isolate port, allowing the main UI thread to call `EntityFluffService().batchRegisterFluff(ingestion.fluff)` upon receiving the computed batch.
- **Universal Bundle & Backup Persistence:**
  - `HomebrewBundle` and persistence services serialize registered lore via `HomebrewBundle.fluff`, maintaining parity across import/export, cloud backups, and local storage.

## 13. SRD Index Decoupling, Subrace/Fluff Persistence Parity, & Resilient Deserialization

- **SRD Equipment Index Decoupling:**
  - `MagicItemLibrary.allItems` dynamically combines base SRD items with runtime homebrew items synchronized via `syncToLibraries()`.
  - `SrdEquivalenceIndex` must strictly index `SrdEquipmentLibrary.baseEquipmentItems` rather than `allEquipmentItems`. Referencing dynamic item collections in the SRD index causes all custom items to be marked as SRD canon and purged during `reparseAllHomebrew()`.
- **Subrace & Fluff Persistence Parity:**
  - `HomebrewPersistenceService` manages dedicated storage keys (`_keyHomebrewSubraces`, `_keyHomebrewSubracesRaw`, `_keyHomebrewFluff`, `_keyHomebrewFluffRaw`).
  - Batch operations (`saveHomebrewEntitiesBatch`) persist subraces directly, register them into `SrdSpeciesLibrary.addCustomSubrace`, and only generate parent race entries when the parent is non-SRD canon (`srdIndex.checkEntity(...) == SrdMatchResult.notSrd`).
  - `exportHomebrewBundle` and `exportBundle` gather and export both standalone `subraces` and `fluff` alongside core categories.
- **Resilient Compendium Deserialization:**
  - Deserialization in all `loadCustom*` methods must wrap per-entity map operations in individual `try-catch` blocks.
  - A single corrupted or malformed record must be logged and bypassed without discarding the rest of the collection.

## 14. Table Classification, Remote Manifest Filtering, & Tabular UI Rendering

- **Rolling vs Data Table Classification:**
  - Compendium tables are dynamically categorized into `HomebrewOtherCategory.tables` (Rollable Tables) vs `HomebrewOtherCategory.dataTables` (Data & Reference Tables) using `isRollingTable`.
  - `isRollingTable` inspects `colLabels` for dice patterns (`d\d+`, `d%`, `roll`, `die`, `dice`, `result`), `rows` for numeric roll range bounds (`01-20`, `1-4`), and explicit dice configuration attributes (`dice`, `roll`, `diceType`).
  - Tables with non-numeric descriptive headers and text rows (such as Material Hardness & AC or Carrying Capacities) are designated as data tables.
- **Sanitized Remote Manifest Discovery & Non-Tabletop Exclusion:**
  - `GithubIngestorAdapter.discoverJsonManifest` filters out non-entity tooling files (`foundry-*.json`, `index.json`, `fluff-index.json`, `sources.json`, `books.json`, `adventures.json`, book/adventure narrative chapters, generator indices, and non-tabletop assets like `recipes.json` / crochet patterns).
  - Unpacking expands bundle keys for secondary tabletop categories (`optionalfeature`, `psionic`, `language`, `sense`, `skill`, `deck`, `tablegroup`, `monsterfeature`). Non-tabletop recipe/crochet patterns are strictly ignored.
- **Tabular UI Rendering & RenderFlex Overflow Protection:**
  - Markdown table rows (`| ... |`) in `DmRuleCard` are parsed into native Flutter `Table` widgets via `FormattedMarkdownText` with header formatting, alternating surface shading, and horizontal scrolling.
  - Roll buttons and `Rollable` badges appear exclusively on dice-driven rolling tables.
  - To prevent horizontal `RenderFlex` overflow on small mobile displays (320-352px) or under 2.0x dynamic type scaling, card badges (`Rollable`, `Data Table`, `Homebrew`, `EditionDiffBadge`) are placed in a responsive `Wrap` inside an `Expanded` column.

## 15. Monster Feature ACL Discrepancy Resolution & Internal Parser Precedence

- **Evaluation at Ingestion & Deserialization Boundaries:**
  - Monster features, traits, actions, and combat properties are evaluated against `StatBlockAclParser.parseMonsterFeature` and `StatBlockAclParser.parseStatBlockBoundary`.
  - When hydrating `MonsterCombatProfile.fromStatBlock` or creating generic compendium entries (`CompendiumGenericEntryParser`), the engine compares raw incoming declarations with the internal ACL parser's extracted values.
- **Strict Discrepancy Precedence:**
  - Any conflict between raw external declarations and the internal ACL parser MUST strictly favor the internal ACL parser:
    - Mobility capabilities (`canFly`, `canSwim`, `canClimb`, `canBurrow`, `hasHover`)
    - Combat traits (`hasEvasion`, `hasFlyby`, `hasNimbleEscape`, `hasPackTactics`)
    - Attack reach (melee reach feet, ranged distance feet)
    - Saving throw proficiencies and spellcasting attributes (spell save DC, spell attack bonus, spell slots)
    - Action effect riders (`CombatEffectRider` AST)
- **Natural Language Swimming & Amphibious Recognition:**
  - The ACL parser recognizes phrases such as `"breathe air and water"`, `"breathe water"`, and `"breathes underwater"` as conferring `canSwim: true`, ensuring amphibious and aquatic creatures possess accurate mobility flags even when raw speed blocks omit an explicit swimming speed.

## 16. CvRDT Ledger Batching & High-Volume Compendium Ingestion Performance

- **Eliminating $O(N^2)$ Map Re-allocations with `CrdtOrSet.addBatch`:**
  - When importing large compendium packs or remote manifests containing tens of thousands of entities, iteratively adding items via single-item `.add()` calls creates an immutable copy of the ledger map on each addition. For 15,000 items, this resulted in ~112 million entity copies, severely degrading import throughput.
  - Ingestors and streaming synchronizers (`HomebrewImportOrchestrator`) must collect ledger entries into micro-batches (`pendingLedgerEntries`) and invoke `CrdtOrSet.addBatch`, cloning the map only once per batch and processing all entries in a single pass while respecting individual tombstones.
- **Import Dialog UI Virtualization & Throttled Progress:**
  - In `HomebrewImportPreviewDialog`, compendium categories must be pre-bucketed during analysis into `_bucketedOtherEntries` rather than running classification regexes (`HomebrewOtherCategory.classify`) tens of thousands of times per build frame.
  - `ExpansionTile.initiallyExpanded` must only default to `true` for small lists (`items.length <= 50`). Large collections must start collapsed to avoid instantiating thousands of unvirtualized widget subtrees simultaneously.
  - Progress callbacks (`onProgress`) during bundle writes must be throttled to fire at most once every 50 saved entities or 80ms, eliminating UI thread locking caused by thousands of synchronous `setState` calls.
- **Index Rebuild Guarding:**
  - `SrdEquivalenceIndex.build()` checks `isBuilt` before execution. Batch persistence routines (`saveHomebrewEntitiesBatch`) must check `if (excludeSrdCanon && !srdIndex.isBuilt) srdIndex.build()` to prevent rebuilding the full SRD canonical equivalence tree on every chunk of 50 entities.

## 17. Markdown Table Normalization, Escaped Pipe Isolation, & Detail Dialog Parity

- **Table Isolation from Surrounding Paragraphs:**
  - Markdown descriptions often contain tables immediately following headings or introductory text without double linebreaks (`\n\n`).
  - `FormattedMarkdownText` preprocesses text with `_isolateMarkdownTables` to detect table blocks (header line, delimiter line matching `_tableSepRegex`, and data rows) and insert paragraph breaks before and after, preventing tables from being swallowed into text or heading spans.
- **Escaped Pipe Protection & Column Count Normalization:**
  - Table cells frequently contain escaped pipes (`\|`) for dice ranges or alternate options. Splitting on unescaped pipes causes cell misalignment and uneven row column counts.
  - `_splitTableRow` temporarily replaces `\|` before splitting and restores `|` in parsed cell text.
  - All table rows are normalized to `maxCols` (padding shorter rows with empty cells) before passing to Flutter's `Table` widget, completely eliminating fatal framework assertions (`'Every TableRow in a Table must have the same number of children'`).
- **Detail & Comparison Dialog Tabular Parity:**
  - Modal detail views displaying multi-edition rules (`DmRuleComparisonDialog._buildRuleWidgets`) must group consecutive lines starting with `|` into markdown tables and render them via `FormattedMarkdownText` with zebra-striping and horizontal scrolling, rather than naively mapping every row to a plain bullet point (`• | d10 | Encounter |`).

## 18. Universal Compendium & Codex Markdown Formatting (`FormattedMarkdownText`)

- **Eliminating Raw Markdown Formatting Tokens in UI Cards & Detail Views:**
  - When rendering compendium entities (Magic Items, Spells, Feats, Creatures, Rules, Homebrew Entries), avoid plain `Text` widgets for description fields or summaries that contain markdown tokens (`**`, `*`, `###`, `|`).
  - Cards and detail sheets (`ItemCard`, `ItemDetailDialog`, `SpellCard`, `SpellComparisonDialog`, `CreatureStatBlockDialog`, `FeatCard`, `HomebrewStudioScreen` entry preview dialog, `CharacterBuilderScreen`, and `AddFeatDialog`) must route description text through `FormattedMarkdownText`.
- **Card-Surface Truncation & Preview Configuration:**
  - On compact card surfaces, pass `maxLines` (e.g. `2` or `3`) and `overflow: TextOverflow.ellipsis` to `FormattedMarkdownText`.
  - When markdown descriptions contain tables or multi-block structures, `FormattedMarkdownText` prioritizes the first block element when truncated and safely isolates markdown tables without throwing runtime rendering errors.
- **Fallback Summary Generation Parity:**
  - In entity converters (e.g., `equipmentItemToMagicItem` in `HomebrewPersistenceService`), `summary` fallback generation filters out leading `#` heading lines and `|` table lines to pick the first substantive narrative line, while keeping the full markdown payload in `description` intact.

## 19. Legal Compliance & Product Identity Invariant Enforcement

- **OGL 1.0a & CC-BY-4.0 Asset Hygiene:**
  - Bundled compendiums and codebases must strictly exclude proprietary Wizards of the Coast Product Identity terms, campaign settings, factions, and non-SRD trademarks.
  - Prohibited tokens include: Eberron, Faerûn, Toril, Ravnica, Krynn, Athas, Barovia, Spelljammer, Planescape, Waterdeep, Baldur's Gate, Neverwinter, Harpers, Zhentarim, Lord's Alliance, Emerald Enclave, Order of the Gauntlet, Dragonmark, Warforged, Kalashtar, Shifter, Changeling, Simic Hybrid, Vedalken, Githyanki, Githzerai, Beholder, Mind Flayer, Illithid, Gith, Displacer Beast, Gauth, Carrion Crawler, Umber Hulk, Slaad, Yuan-ti, Beholderkin, Bigby, Tasha, Mordenkainen, Otiluke, Drawmij, Rary, Leomund, Evard, Tenser, Aganazzar, Melf, Elminster, Drizzt, Strahd, Acererak.
- **Automated Compliance Test Suite (`srd_legal_compliance_test.dart`):**
  - An automated regression test scans all static compendiums:
    - `SrdClassesLibrary.allOptions`
    - `SrdBackgroundsLibrary.allBackgrounds`
    - `SrdSpeciesLibrary.allSpecies`
    - `MonsterCodexLibrary.allMonsters`
    - `MagicItemLibrary.allItems`
  - Asserts that all names, summaries, traits, and markdown descriptions yield zero matches against the word-boundary Product Identity regular expression.
- **Test Fixture Cleansing:**
  - Test fixtures simulating homebrew ingestion must never introduce proprietary tokens. Use generic labels and custom lineages (e.g. `Human (Lineage of the Forge)` with `'source': 'CUSTOM_LINEAGE'` and `'lineageType': 'Forge'`) rather than setting-specific dragonmark or Eberron tokens.

## 20. Action Rider Execution, Subrace Pool Constraints, & Background Compilation

- **Saving Throw Action Riders & Dynamic Fallbacks:**
  - `StatBlockAclParser.extractRiders()` captures conditions from actions and spells with explicit saving throw DCs (e.g. `succeed on a DC 11 Strength saving throw or be knocked prone`) and implicit DCs where $\text{DC} = 8 + \text{PB} + \text{AbilityMod}$.
  - Precomputed attacks (`attacks` on `MonsterCombatProfile`) carry composite `CombatEffectRider` ASTs that execute without runtime regular expressions during combat simulations.
  - `ArenaCombatant.applyAttackHit()` delegates HP management to domain `HitPoints`, evaluates saving throws with d20 rolls, applies conditions, and logs outcomes into `ArenaAttackEvent.summaryText`.
- **Subrace Flexible Choice Pool Constraints:**
  - `Subrace` models store `flexibleAbilityPool`, `flexibleAbilityCount`, and `flexibleAbilityBonus`.
  - In 2014 mode, `CharacterDraft.reconcile()` enforces that unselected flexible choices are populated from `flexibleAbilityPool` (e.g. `['dex', 'int']`), preventing unwanted fallbacks to `AbilityType.strength`.
  - `CharacterBuilderScreen` and `AbilityScoreStep` filter selectable option chips strictly to the subrace's allowed ability pool.
- **Background Ingestion & Character Compilation:**
  - `HomebrewEntityDto._normalizeAndClamp()` normalizes background `skillProficiencies`, `startingEquipment`, and 2024 ASIs.
  - `HomebrewIngestor.mapBackgroundFromDto()` and `parseCustomBackgrounds()` map raw JSON into domain `Background` entities.
  - `CharacterFactory.buildFromDraft()` grants background skills into `character.skillProficiencies`, instantiates background starting equipment into `character.inventory`, applies 2024 ASIs (`bonusScores`), and factors Constitution modifiers into starting HP calculation.

## 21. Subclass Feature Propagation, Ingestion Stitching, & Unified Multi-Permutation Resolution

- **Multi-Permutation Subclass Matching (`SrdClassesLibrary.findSubclass`):**
  - In community compendiums and homebrew packs, subclasses may be identified by plain slug (`echo-knight`), class-prefixed slug (`fighter-echo-knight`), display name (`Echo Knight`), or short name.
  - `SrdClassesLibrary.findSubclass(query, {classSlug, displayName, ruleset})` tests exact slug, class-prefix stripped slugs, name/shortName matches, space/hyphen/underscore normalization, and optional ruleset filtering.
  - Custom subclasses (`_customSubclasses`) remain indexed in `allSubclasses` even if unattached to a known base class, ensuring orphan and standalone subclasses resolve cleanly.
  - In `SrdClassesLibrary.allClasses`, subclasses match parent classes using normalized clean slugs (`_classSlugsMatch`) as well as slug prefixes (`$cleanClassSlug-` or `${cleanClassName}-`), guaranteeing that subclasses attach to their parent classes even if naming conventions vary.
- **Robust Subclass Feature Ingestion, Source Pipe Stripping & Class Inference:**
  - `CompendiumClassParser.parseSubclass` cleanly strips compendium source pipes from `className` (e.g., `Warlock|PHB` -> `warlock`, `Cleric|DMG` -> `cleric`).
  - When `className` is missing or blank, `CompendiumClassParser` infers the parent class from `subclassFeatures` or `entries` pipe entries (`Feature|Class|...`) and falls back to standard tabletop class slug prefixes on the subclass slug/ID.
  - In external compendium schemas, subclass feature pointers are typically 6-part or 4-part pipe-delimited strings (`Name|Class|ClassSource|SubShort|SubSource|Level`). External feature records associate via `subclassShortName`, `subclassName`, `shortName`, or `subclass` map rather than the feature's own name (`f['name']`).
  - `CompendiumClassParser` and `CompendiumJsonIngestionPipeline` resolve external features against candidate permutations:
    1. Exact normalized key (`name.toLowerCase()`)
    2. `$name|$subShort|$level`
    3. `$name|$className|$subShort|$level`
    4. `$name|$subShort`
    5. `$name|$className`
    6. Subclass-prefixed slug name
  - Inline feature maps (`name` + `entries` + optional `level`) are parsed directly into `### $name (Level $level)`.
  - Unresolved pointers generate formatted fallback feature cards (`### $name (Level $level)\n*Subclass feature from $subShort.*`) rather than being dropped silently.
- **Character Sheet Feature Propagation, 2014 Level 1 Milestones & Self-Contained References:**
  - `AbilitiesAndTraitsTab` and `FeaturesTraitsSection` resolve subclasses using `SrdClassesLibrary.findSubclass` and fall back to `cls.subclassRef.customProperties['featuresMarkdown']` when compendium library caches are unhydrated.
  - When evaluating 2014 subclass milestones, if parent class metadata is unhydrated, Level 1 subclasses (Warlock, Cleric, Sorcerer) correctly evaluate milestone minimum level as 1 (Druid/Wizard as 2, others as 3) rather than defaulting to level 3.
  - `CharacterBuilderScreen` and `LevelUpWizardDialog` store `featuresMarkdown`, `classSlug`, `shortName`, and `grants` into `subclassRef.customProperties` at selection time so characters carry their abilities self-contained.
  - `CharacterReparseEngine.reparse` self-heals un-hydrated or legacy subclass references: dynamically queries `SrdClassesLibrary.findSubclass`, updates the reference to the canonical slug, and hydrates `featuresMarkdown` and `grants` into `customProperties`.
  - `CharacterHomebrewValidator`, `CharacterActionsResolver`, `CharacterTelemetryResolver`, and `SubclassSpellsLibrary` utilize `SrdClassesLibrary.findSubclass` to eliminate false "Missing Homebrew" reports and propagate actions and spells accurately.

## 22. Compendium Class Starting Tools & Growable Grants Invariant

- **Growable Grants Invariant:**
  - In `CompendiumClassParser.extractSpellsGrants()`, the return value must be a mutable list (`<FeatureGrant>[]`) rather than a compile-time constant (`const []`).
  - Callers in `parseClass()` and `parseSubclass()` wrap extracted grants in `List<FeatureGrant>.from(...)` to guarantee that subsequent additions do not trigger `Unsupported operation: Cannot add to an unmodifiable list`.
- **Class Starting Tool Proficiencies & Inline Tag Cleaning:**
  - In 2014 rules and imported external compendiums, classes and imported archetypes (such as Monk, Druid, Rogue, or imported third-party classes) declare starting tool proficiencies in `startingProficiencies['tools']` (e.g. `['{@item Herbalism kit|PHB}']`, `["{@item thieves' tools|PHB}"]`, or artisan tool choices) without carrying an `additionalSpells` key on the class definition.
  - When parsing tool strings, `CompendiumClassParser` strips inline item tags (`{@item Herbalism kit|PHB}` -> `Herbalism kit`) and registers them as `FeatureGrant.bonusTool(...)`.
  - Imported third-party or homebrew class data may contain arbitrary class names and optional feature structures; the ACL must parse these without treating them as bundled canonical content, ensuring arbitrary imported class payloads parse cleanly with 100% success.

## 23. High-Volume Compendium Import Memory Safety & Stability

- **Bounded Download Concurrency:**
  - `GithubIngestorAdapter` defaults to sequential processing (`concurrentDownloads = 1`) with event-loop yields between files and stream chunks (`streamChunkSize = 25`). Parallel downloading of multi-megabyte JSON compendium files floods mobile memory heaps and socket channels, triggering operating system kills and ANR crashes.
- **Copy-On-Write Ingestion Transforms:**
  - `GenericTagScrubber.scrubMap` and `_resolveRefs` return original instances unmodified when no tags or pointers are mutated, eliminating hundreds of thousands of intermediate heap object allocations.
- **$O(N)$ Batch Persistence via String Indexing (`_saveEntitiesBatchFast`):**
  - In `HomebrewPersistenceService`, routine entity batch persistence must NOT re-deserialize the entire historical database into heap domain models or re-encode existing items on every batch.
  - Using a cached slug-to-index map (`_categorySlugIndex`), incoming entities overwrite or append directly into the cached JSON string list in $O(N)$ amortized time.
- **Ledger Suppression & Sliding Error Windows:**
  - `HomebrewImportOrchestrator` allows suppressing the historical in-memory `_ledger` (`retainLedger: false`) during high-volume imports, and caps error tracking to a sliding window of 100 entries.
- **Dual-Layer SharedPreferences OOM Shield:**
  - When primary Hive storage is open, `_saveStringList` and `_saveRawPayloadsBatch` skip mirroring collections with `> 20` items to `SharedPreferences`, avoiding Android `TransactionTooLargeException` and web local-storage quota crashes.
- **Cache Synchronization & Category Invalidation:**
  - All deletion and clearing operations (`deleteCustomEntitiesBatch`, `clearOtherEntriesByCategories`, `clearAllHomebrew`) must invalidate or synchronize `_categorySlugIndex` and purge corresponding raw keys across all 11 categories.

