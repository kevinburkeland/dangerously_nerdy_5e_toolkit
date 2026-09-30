# D&D 5e Dual-Ruleset & Mechanics Directives

## 1. Dual-Edition Architectural Invariants
The toolkit natively supports both the **2014 Rules As Written (SRD 5.1)** and the **2024 Revised Rules (SRD 5.2.1)**.
- **Never Assume a Single Edition:** Rules logic must never assume 2014 or 2024 as the sole truth. Always resolve edition-specific behavior through explicit edition context (`RulesetEdition` / `DmRulesEdition`).
- **Engine Core Decoupling:** D&D mechanics belong outside the generic engine core. Agnostic contracts reside in `vtt_engine_core`; all 5e rules live in `lib/infrastructure/modules/dnd5e/` and `lib/services/rules/`.
- **Immutable Character Edition:** Character sheets are locked to their initial edition (`dnd2014` vs `dnd2024`). Silent runtime cross-edition translation of existing characters is strictly prohibited.
- **Unknown Stays Unknown (Anti-Hallucination):** Rules logic must never infer, hallucinate, or synthesize tabletop defaults for missing attributes.

---

## 2. Key Ruleset Divergence Patterns

Rather than maintaining a redundant second copy of the SRD in rule text, mechanics are canonically enforced in code (`DndRulesetStrategy`, `CharacterEvaluationEngine`) and verified by `test/services/rules/dual_ruleset_divergence_test.dart`. Agents must uphold these primary divergence patterns:

- **Action Economy & Consumption:**
  - Potion drinking is a standard Action in 2014 RAW, but a Bonus Action in 2024.
  - Bonus Action spellcasting rules restrict other spells cast on the same turn according to edition-specific rules.
- **Condition & Exhaustion Mechanics:**
  - 2014 Exhaustion uses 6 discrete qualitative tiers (disadvantage, speed halved, HP maximum halved, death at tier 6).
  - 2024 Exhaustion uses 10 linear quantitative penalty steps (-2 per level to D20 tests/DC, -5ft speed per level, death at tier 10) tracked via `ExhaustionState`.
- **Spell Slot & Multiclass Progression:**
  - Multiclass half-caster spell slot calculation diverges: 2014 applies floor division (`paladinLevels ~/ 2`), while 2024 applies ceiling division (`(paladinLevels + 1) ~/ 2`).
  - Single-class half-casters and 1/3-casters strictly use dedicated class progression tables; never route single-class characters through multiclass spell tables.
- **Weapon Masteries:**
  - Absent in 2014 rules.
  - Active in 2024 as discrete property riders on weapons (`Cleave`, `Graze`, `Nick`, `Push`, `Sap`, `Slow`, `Topple`, `Vex`) evaluated during attack resolution.
- **Subclass Progression Milestones:**
  - 2014 subclass selection milestones vary by class (Level 1 for Cleric/Sorcerer/Warlock, Level 2 for Druid/Wizard, Level 3 for others).
  - 2024 standardizes subclass selection to Level 3 across all classes.

---

## 3. Character Compilation & Progression Invariants
- **Draft Reconciliation (`CharacterValidationEngine.reconcileDraft`):**
  - 2014 mode automatically prunes origin feats and resets background ability bonuses to zero.
  - Feat prerequisites evaluate inherent ability scores (`rawAbilityScores = base + bonus`), never temporary item overrides.
  - In 2014 mode, subrace mechanical attributes (ASIs, speed, darkvision) replace base species attributes rather than stacking. Flexible choices are constrained by `flexibleAbilityPool`.
  - Innate lineage cantrips and spells auto-register into `character.cantrips` and `character.spellsKnown`.
- **Ability Score Ceiling Dynamics:**
  - Standard inherent score ceiling is 20 (Barbarian capstone raises STR/CON to 24).
  - Hard inherent ceiling is 30. Dual +1 ASI increases must be allocated to distinct abilities.
- **Warlock Pact Magic Slot Purity:**
  - All Warlock spell slots share a uniform level (`pactMagicSlotLevel`).
  - Casting lower-level spells automatically upcasts to `pactMagicSlotLevel` and decrements `pactMagicCurrent`.
  - Spells with slot-level scaling dynamically scale effect values to `pactMagicSlotLevel`.
  - Multiclass characters with both standard and Pact Magic slots track separate short-rest recharge pools.

---

## 4. RAW Health & Instant Death Decoupling
Located at `lib/models/value_objects/hit_points.dart` (consumed from `vtt_engine_core`):
- **Downed vs Dead:** 0 HP unconsciousness (`isDowned => currentHp <= 0`) is decoupled from permanent death (`isDead`). Standard healing revives downed actors at 0 HP per 5e RAW. Massive damage instant death requires explicit revival (`allowRevive: true` or `revive()`).
- **Instant Death on Stat Drain:** Reducing Strength or `effectiveMaxHp` to 0 sets `currentHp = 0`, logs instant death, and defeats the actor (`isAlive` returns false if Strength $\le 0$).

---

## 5. Legal & SRD Compliance Invariant
- **Strict CC-BY-4.0 SRD 5.1 & 5.2.1 Content:** Bundled compendiums, fixtures, and code must contain ZERO Wizards of the Coast Product Identity terms.
- **Prohibited Tokens:** Beholder, Gauth, Carrion Crawler, Displacer Beast, Githyanki, Githzerai, Kuotoa, Mind Flayer, Illithid, Slaad, Umber Hulk, Yuan-ti, Strahd, Elminster, Drizzt, Acererak, Faerûn, Toril, Eberron, Ravnica, Krynn, Athas, Barovia, Spelljammer, Planescape, Waterdeep, Baldur's Gate, Neverwinter, Harpers, Zhentarim, Dragonmark, Warforged, Hexblade, Artificer.
- **Permitted Equivalents:** SRD monsters, open-content subclasses, generic variant lineages (`Human (Lineage of the Forge)`, `CUSTOM_LINEAGE`), and original homebrew names. Enforced by `test/infrastructure/compliance/srd_legal_compliance_test.dart`.
