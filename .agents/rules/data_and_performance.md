# Data Safety, DTOs & Performance Directives

## 1. DTO Isolation & Anti-Corruption Layer (ACL)

External JSON (network streams, local Hive databases, 5etools bundles) must NEVER be cast directly into Domain entities.

- **DTO Mapping:** Parse incoming JSON into Data Transfer Objects (`lib/infrastructure/dtos/`) first, then convert to Domain models via `.toDomain()`.
- **Fault-Tolerant Defaults:** If a field is missing, null, or has an unexpected type, DTOs must provide safe tabletop fallback defaults instead of crashing.
- **Unparsed Payload Preservation:**
  - Users frequently import homebrew with custom attributes, extra tags, or future schema additions.
  - Every DTO must retain unrecognized keys in an `unparsedPayload` map (`Map<String, dynamic>`).
  - When re-serializing to JSON (`toJson()`), merge `unparsedPayload` back into the output map to prevent data loss across schema migrations.

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

