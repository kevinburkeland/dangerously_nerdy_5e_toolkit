# D&D 5e Dual-Ruleset & Mechanics Directives

## 1. Dual-Edition Architecture (2014 RAW vs 2024 Revised)

The toolkit natively supports both the **2014 Rules As Written (SRD 5.1)** and the **2024 Revised Rules (SRD 5.2.1)**.
- Never assume 2014 or 2024 mechanics as the sole truth.
- Inspect `RulesetEdition` / `DmRulesEdition` (`dnd2014` vs `dnd2024`) or `RulesetContext` when evaluating mechanics.
- Core domain engine primitives must remain ruleset-agnostic; all edition branching lives in `lib/domain/rules/` and `lib/infrastructure/modules/dnd5e/`.

### Key Edition Differences Matrix

| Mechanic | 2014 RAW (SRD 5.1) | 2024 Revised (SRD 5.2.1) |
|---|---|---|
| **Drinking a Potion** | Standard Action | Bonus Action |
| **Exhaustion** | 6 Discrete Tiers (Speed halved, Disadvantage, Death at 6) | 10 Linear Steps (-2 to D20 tests/DC per level; -5ft speed per level; Death at 10) |
| **Counterspell** | Automatic vs $\le$ 3rd, Ability check vs higher | Constitution saving throw by caster to retain spell |
| **Cure Wounds / Healing Word** | 1d8 / 1d4 + Mod base healing | 2d8 / 2d4 + Mod base healing |
| **Divine Smite** | Free trigger on melee hit (no action, slot expended) | Bonus Action after hit (Concentration, 1/turn) |
| **Spiritual Weapon** | No concentration required | Requires Concentration |
| **Conjure Animals** | Summons physical creature statblocks (up to 8/16/32) | 10-ft spectral emanation aura dealing damage on turn start |
| **Heavy Weapon / Power Attack** | -5 attack penalty for +10 flat damage | Adds Proficiency Bonus (PB) damage on hit |
| **Great Weapon Fighting (GWF)**| Reroll 1s and 2s on damage dice once | Any damage die roll of 1 or 2 is treated as a 3 |
| **Weapon Masteries** | None | Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex |
| **Subclass Milestones** | Varies by class (L1 Cleric/Sorcerer/Warlock, L2 Druid/Wizard, L3 others) | Standardized to Level 3 for all classes |

## 2. Character Compilation & Edition Invariants
- **Edition-Locked Characters:** Character sheets are locked to their initial edition (`dnd2014` vs `dnd2024`). Ad-hoc cross-edition runtime translation on character sheets is prohibited.
- **Draft Reconciliation (`CharacterValidationEngine.reconcileDraft`):**
  - 2014 mode automatically prunes origin feats and resets background ability bonuses to zero.
  - Feat prerequisites evaluate inherent ability scores (`rawAbilityScores = base + bonus`), never temporary item overrides.
  - In 2014 mode, subrace mechanical attributes (ASIs, speed, darkvision) replace base species attributes rather than stacking. Flexible choices are constrained by `flexibleAbilityPool`.
  - Innate lineage cantrips and spells auto-register into `character.cantrips` and `character.spellsKnown`.
- **Ability Score Ceiling Dynamics:** Standard inherent score ceiling is 20 (Barbarian capstone raises STR/CON to 24). Manuals/treatises expand inherent maximums via `customProperties['abilityMaximums']` up to the hard ceiling of 30. Dual +1 ASI increases must be allocated to distinct abilities.

## 3. RAW Health & Instant Death Decoupling
Located at `lib/domain/models/value_objects/hit_points.dart`:
- **Downed vs Dead:** 0 HP unconsciousness (`isDowned => currentHp <= 0`) is decoupled from permanent death (`isDead`). Standard healing revives downed actors at 0 HP per 5e RAW. Massive damage instant death requires explicit revival (`allowRevive: true` or `revive()`).
- **Instant Death on Stat Drain:** Reducing Strength or `effectiveMaxHp` to 0 sets `currentHp = 0`, logs instant death, and defeats the actor (`isAlive` returns false if Strength $\le 0$).

## 4. Spellcasting & Action Economy Mechanics
- **Warlock Pact Magic Slot Purity:**
  - All Warlock spell slots share a uniform level (`pactMagicSlotLevel`).
  - Casting lower-level spells automatically upcasts to `pactMagicSlotLevel` and decrements `pactMagicCurrent`.
  - Spells with slot-level scaling (e.g. *Armor of Agathys*) dynamically scale effect values to `pactMagicSlotLevel`.
  - Multiclass characters with both standard and Pact Magic slots distinguish them via the `(Pact)` badge and track separate short-rest recharge pools.
- **Single-Class vs Multiclass Spell Slots:** Single-class half-casters (Paladin, Ranger) and 1/3-casters (Eldritch Knight, Arcane Trickster) MUST use dedicated class slot tables, NOT generic multiclass floor division (`lvl ~/ 2`). Multiclass spellcaster tables apply strictly to characters with 2+ spellcasting classes.
- **Action Economy Typing:** Use `CharacterActionsResolver` and `CombatActionType` (`action`, `bonusAction`, `reaction`, `freeAction`, `movement`, `special`). Multiattack executes defined sequences, not all attacks simultaneously.

## 5. Legal & SRD Compliance Invariant
- **Strict CC-BY-4.0 SRD 5.1 & 5.2.1 Content:** Bundled compendiums, fixtures, and code must contain ZERO Wizards of the Coast Product Identity terms.
- **Prohibited Tokens:** Beholder, Gauth, Carrion Crawler, Displacer Beast, Githyanki, Githzerai, Kuotoa, Mind Flayer, Illithid, Slaad, Umber Hulk, Yuan-ti, Strahd, Elminster, Drizzt, Acererak, Faerûn, Toril, Eberron, Ravnica, Krynn, Athas, Barovia, Spelljammer, Planescape, Waterdeep, Baldur's Gate, Neverwinter, Harpers, Zhentarim, Dragonmark, Warforged, Hexblade.
- **Permitted Equivalents:** SRD monsters, open-content subclasses, generic lineages (`Human (Lineage of the Forge)`), and original homebrew names. Enforced by `srd_legal_compliance_test.dart`.
