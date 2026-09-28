# Data Safety, DTOs & Ingestion Directives

## 1. DTO Boundaries & Anti-Corruption Layer (ACL)
- **Mandatory DTO Isolation:** External JSON (network streams, local storage, compendium bundles) must NEVER be cast directly into Domain entities. Ingest into DTOs (`lib/infrastructure/dtos/`) first, then convert via `.toDomain()`.
- **Unknown Stays Unknown (Anti-Hallucination):** Never synthesize or assume missing attributes (e.g., speed, size, saving throws). Missing fields must remain `null`. Retain all unrecognized JSON keys in an `unparsedPayload` map (`Map<String, dynamic>`) and merge them back on serialization (`toJson()`).
- **Tabletop Bounds Clamping:** Clamping rules for numeric input:
  - HP: `0..999`
  - Character Level: `1..20`
  - Ability Scores: `1..30` (or `1..20` for standard non-epic limits)
  - Currency: Non-negative integers (`value >= 0`); overdrafts clamp to 0 and flag errors.
  - Spell Slot Level: `0..9`
- **Zero Third-Party Tool Coupling:** Strict prohibition of third-party bundle lists, proprietary schemas, or site keys in core logic. Remote ingestion (`GithubIngestorAdapter`) inspects generic tabletop indicators (`name`, `entries`, `hitDie`, `stats`, `type`, `level`, `actions`).
- **External Pipe Isolation:** Pipe-delimited syntax (`Feature|Class|Source|Level`, `Spell|Source#c`) must be parsed at the ACL boundary via `CompendiumPipeParser`.

## 2. Performance & Hot-Loop Pre-Computation
- **Zero Runtime Regex in Hot Loops:**
  - Regular expressions (`RegExp`) are STRICTLY FORBIDDEN inside combat loops, Monte Carlo simulations (500x/1,000x runs), and DPR calculations.
  - Action descriptions and spell scaling must be parsed into numeric value objects or ASTs during ingestion/initialization.
- **Combat Action Rider AST:**
  - Action descriptions are parsed at the ACL boundary (`StatBlockAclParser.extractRiders`) into strongly typed `CombatEffectRider` ASTs (`ConditionRider`, `AttributeDrainRider`, `MaxHpReductionRider`, `ForcedMovementRider`, `HealingSupressionRider`, `PeriodicDamageRider`).
  - Simulations (`ArenaCombatant.applyAttackHit`) execute riders directly without regex, dynamically modifying vitals and scaling modifiers.
- **Isolate Offloading for Large Imports:**
  - Offload JSON decoding and schema validation to `Isolate.run()` on native platforms when payload size $\ge$ 64 KB (`isolateThresholdBytes`). Payloads $< 64$ KB decode on the event loop to avoid isolate spawn overhead.
  - Search fields must use tokenized search indices rather than filtering full text collections on keystroke.

## 3. Persistence Architecture & Storage Durability
- **Single Storage Engine Truth:**
  - Repositories persist strictly to Hive / IndexedDB boxes (`AppDatabaseService`). Dual-writing to `SharedPreferences` during normal saves is prohibited.
  - `SharedPreferences` reads are strictly isolated as legacy fallback on first launch when primary boxes are uninitialized.
  - Large collections (`list.length > 20`) skip mirroring to `SharedPreferences` when Hive storage is active to prevent OS transaction overflow crashes.
- **Debounced Disk Writes:**
  - Rapid mutations update in-memory caches immediately and debounce disk persistence via `debouncedStorage.scheduleWrite` (300ms default). Test frames must advance past debounce durations (`pump(const Duration(milliseconds: 400))`) and invoke `AppServices.reset()` in `tearDown()`.
- **$O(N)$ Batch Persistence via Slug Indexing:**
  - Routine batch saves (`HomebrewPersistenceService._saveEntitiesBatchFast`) must not re-decode historical databases. Incoming entities overwrite or append using cached slug-to-index maps (`_categorySlugIndex`) in $O(N)$ amortized time.
- **Resilient Compendium Deserialization:**
  - Entity deserialization in `loadCustom*` methods must wrap individual records in isolated `try-catch` blocks. Corrupted records are logged and bypassed without discarding the remaining collection.

## 4. Homebrew Ingestion Engine & Pipeline Isolation
- **Explicit Ruleset Pre-Selection Mandate:** Remote repository ingestion (`IGithubIngestorPort`) requires explicit user pre-selection of `RulesetVersion.srd2014` or `RulesetVersion.srd2024`. Heuristic auto-detection is strictly forbidden.
- **Bounded Ingestion Concurrency:** Download concurrency is bounded to sequential processing (`concurrentDownloads: 1`) with cooperative event-loop yields (`Future.delayed(Duration.zero)`) between files and stream chunks (`streamChunkSize: 25`).
- **Copy-On-Write Ingestion Transforms:** `GenericTagScrubber.scrubMap` and reference resolvers apply copy-on-write semantics, returning original instances unmodified if no child tokens were mutated.
- **Batch Ingestion & Deferred Library Sync:** Entities persist in batches (50 entities + final flush) via `saveHomebrewEntitiesBatch(..., syncLibraries: false)`. `syncToLibraries()` is invoked once upon batch completion.
- **Canonical SRD Index Isolation:**
  - `SrdEquivalenceIndex.build()` MUST ONLY query base canonical SRD collections (`SpellbookLibrary.srdSpells`, `SrdClassesLibrary.baseClasses`, `SrdSpeciesLibrary.baseSpecies`, etc.). Never query `.all*` getters that combine SRD and custom entities, which causes active homebrew to be indexed as SRD canon and purged during re-parsing.
  - Batch saves enforce `excludeSrdCanon: true` by default to prevent third-party JSON dumps from saving duplicate base SRD entries.
- **Full 11-Category Backup & Export Parity:** All backup, export, and clearing services (`AppBackupService`, `DmBackupService`, `HomebrewPersistenceService`) must maintain 100% coverage across all 11 categories: `spells`, `monsters`, `items`, `classes`, `subclasses`, `races`, `subraces`, `feats`, `backgrounds`, `otherEntries`, and `fluff`.
