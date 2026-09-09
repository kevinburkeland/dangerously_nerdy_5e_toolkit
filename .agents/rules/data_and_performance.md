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
