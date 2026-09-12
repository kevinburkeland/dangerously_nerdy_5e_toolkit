# Data Safety, DTOs & Performance Directives

## 1. DTO Isolation & Anti-Corruption Layer (ACL)

External JSON (network streams, local Hive databases, 5etools bundles) must NEVER be cast directly into Domain entities.

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
- **Background Isolates for Large Imports:**
  - When ingesting multi-megabyte 5etools or homebrew compendiums, offload parsing to background isolates (`compute()` or dedicated isolates) to maintain 60/120fps UI responsiveness.
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
  - 5etools and community JSON files are bundles whose root maps contain entity collections (`"monster": [...]`, `"spell": [...]`, `"item": [...]`) or root JSON arrays (`[{...}]`), lacking a top-level `name` attribute. Ingestors must unpack each individual entity rather than treating the file root map as a single entity.
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
  - 5eTools and community homebrew formats encode subclass expanded spell options using `additionalSpells` containing query filter expressions under `'all'` or `'choose'` keys (e.g., `{"all": "level=0|class=Cleric"}`).
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
