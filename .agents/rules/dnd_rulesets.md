# D&D 5e Dual-Ruleset & Mechanics Directives

## 1. Dual-Edition Awareness (2014 RAW vs 2024 Revised)

The toolkit natively supports both the **2014 Rules As Written (SRD 5.1)** and the **2024 Revised Rules (SRD 5.2)**.

- **Rule:** Never assume 2014 or 2024 mechanics as the sole truth.
- Always check or pass the `DmRulesEdition` enum (`DmRulesEdition.dnd2014` vs `DmRulesEdition.dnd2024`) or inspect `RulesetContext` when evaluating rules.

### Key Edition Differences Matrix

| Mechanic | 2014 RAW (SRD 5.1) | 2024 Revised (SRD 5.2) |
|---|---|---|
| **Drinking a Potion** | Standard Action | Bonus Action |
| **Exhaustion** | 6 Discrete Penalties (Speed halved, Disadvantage on saves, Death at level 6) | 10 Linear Steps (-2 to D20 tests and spell save DC per level; Speed reduced by 5ft per level; Death at 10) |
| **Counterspell** | Automatic vs 3rd level, Ability check vs higher | Constitution saving throw by caster to retain spell |
| **Cure Wounds** | 1d8 + Mod base healing | 2d8 + Mod base healing |
| **Healing Word** | 1d4 + Mod base healing | 2d4 + Mod base healing |
| **Divine Smite** | Free trigger on melee hit (No action cost, slot expended) | Bonus Action immediately after hit (Concentration, 1/turn) |
| **Spiritual Weapon** | No concentration required | Requires Concentration |
| **Conjure Animals** | Summons physical creature statblocks (up to 8/16/32) | Summons 10-ft spectral emanation aura dealing radiant/slashing damage on turn start |
| **Great Weapon Master (GWM)** | -5 attack penalty for +10 flat damage | Adds Proficiency Bonus (PB) damage to heavy weapon attacks on hit |
| **Great Weapon Fighting (GWF)**| Reroll 1s and 2s on damage dice once | Any die roll of 1 or 2 is treated as a 3 |
| **Weapon Masteries** | None | Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex |

## 2. Action Economy & Combat Modeling

- Use `CharacterActionsResolver` (`lib/services/rules/character_actions_resolver.dart`) and `CombatAction` model for classifying actions:
  - `CombatActionType.action`
  - `CombatActionType.bonusAction`
  - `CombatActionType.reaction`
  - `CombatActionType.freeAction`
  - `CombatActionType.movement`
  - `CombatActionType.special`
- Always respect multiattack routines: creatures execute defined multiattack sequences (e.g. 1 bite + 2 claws), NOT firing all attack profiles simultaneously.

## 3. Legal & SRD Compliance

- **No WotC Product Identity:** Never generate code, tests, fixtures, or mock data referencing Product Identity monsters, characters, or locations.
  - Prohibited: Beholder, Gauth, Carrion Crawler, Displacer Beast, Githyanki, Githzerai, Kuotoa, Mind Flayer, Illithid, Slaad, Umber Hulk, Yuan-ti, Strahd, Elminster, Hexblade, etc.
  - Permitted: SRD 5.1 & SRD 5.2 monsters and subclasses (e.g., Red Dragon, Knight, Wolf, Skeleton, Zombie, Ogre, Mage, Champion, Evoker, etc.).
- Attribution is governed by `LEGAL_ATTRIBUTION_MODAL.md` under CC-BY-4.0.

## 4. Character Edition Locking & Pipeline Invariant Reconciliation

- **Edition-Locked Sheets:** Character sheets are locked to their initial edition (`DmRulesEdition.v2014` vs `DmRulesEdition.v2024`). Do not build ad-hoc runtime cross-edition translation engines into `CharacterSheetController`.
- **Builder / Draft Reconciliation:** Invariant reconciliation belongs in the draft compilation pipeline via `CharacterValidationEngine.reconcileDraft` and `CharacterDraft.reconcile()`:
  - 2014 mode automatically prunes origin feats and resets background ability bonuses to zero.
  - Feat prerequisites (e.g. Grappler requiring STR or DEX 13+) are evaluated via `CharacterValidationEngine.validateDraft(draft)` and surfaced in `CharacterBuilderController.validationIssues`.
  - Orphaned skill refunds are pruned whenever overlapping skills or backgrounds change.

## 5. Warlock Pact Magic & Spell Upcasting Conventions

- **Pact Magic Slot Purity (RAW 5e):**
  - All Warlock spell slots share a uniform level (`pactMagicSlotLevel`).
  - Casting any lower-level spell using Pact Magic automatically upcasts the spell to `pactMagicSlotLevel`.
  - **Pure Warlock Auto-Upcasting:** Characters with only Pact Magic slots (no regular spell slots $\ge$ spell level) MUST NOT be blocked by missing lower-level slots or prompted with superfluous slot picker modals. The engine auto-upcasts the spell to `pactMagicSlotLevel` and decrements `pactMagicCurrent`.
  - **Slot-Level Effect Scaling:** Spells with slot-level scaling (e.g. *Armor of Agathys* awarding 5 Temp HP and 5 Cold Retaliation damage per slot level) dynamically scale their effect values to `pactMagicSlotLevel`.
  - **Multiclass Disambiguation:** Multiclass characters with both standard spell slots and Pact Magic slots present both options in `SpellUpcastSheet`, clearly distinguishing Pact Magic with the `(Pact)` badge, short-rest recharge annotations, and separate pool tracking.

## 6. Subclass Archetype Milestones (2014 RAW vs 2024 Revised)

- **2014 RAW Subclass Milestones:**
  - **Level 1:** Cleric (Divine Domain), Sorcerer (Sorcerous Origin), Warlock (Otherworldly Patron).
  - **Level 2:** Druid (Druid Circle), Wizard (Arcane Tradition).
  - **Level 3:** Barbarian, Bard, Fighter, Monk, Paladin, Ranger, Rogue, Artificer.
  - When evaluating subclass milestones, always call `characterClass.getSubclassLevel(ruleset)` rather than reading static default fields.
- **2024 Revised Standard:**
  - All classes standardize subclass selection to **Level 3**.

## 7. Spell Slot Allocation: Single-Class vs. Multiclass

- **Single-Class Half & Third Casters:**
  - Single-class Paladins, Rangers, Artificers, and 1/3-casters (Eldritch Knight, Arcane Trickster) MUST use their dedicated class tables (`_halfCasterSlots2014`, `_halfCasterSlots2024`, `_thirdCasterSlots`, `_artificerSlots`).
  - Do NOT route single-class half/third casters into the generic multiclass slot table via floor division (`lvl ~/ 2` or `lvl ~/ 3`), which deprives Paladins and Rangers of 2nd-level slots at Level 5 and Eldritch Knights of 3rd 1st-level slots at Level 4.
- **Multiclass Slot Matrix:**
  - The Multiclass Spellcaster Table (`calculateEffectiveCasterLevel`) is strictly reserved for characters with 2 or more spellcasting classes.
- **Initial Wizard Scribe on Multiclass:**
  - Multiclassing into Wizard at level 1 grants 6 starting 1st-level spells in the spellbook (`maxSpellbookInitialScribe`), not the 2-per-level incremental scribe.

## 8. Ability Scores: Inherent vs Overrides & Dynamic Maximums

- **Inherent Score vs. Temporary Overrides:**
  - Inherent scores (`rawAbilityScores = baseScores + bonusScores`) are modified by Species, Level-Up ASIs, and permanent magical treatises/tomes.
  - Item overrides (e.g. *Gauntlets of Ogre Power* = 19, *Belts of Giant Strength* = 21–29) set `effectiveAbilityScores` without mutating inherent scores.
  - Multiclass prerequisites evaluate inherent scores (`rawAbilityScores`), never item overrides.
- **Dynamic Inherent Maximums (`Character.getAbilityScoreMaximum`):**
  - Normal inherent maximum is **20**.
  - Level 20 Barbarian capstone (*Primal Champion*) raises the inherent maximum for Strength and Constitution to **24**.
  - Permanent magical treatises/tomes expand inherent maximums via `customProperties['abilityMaximums']` (e.g. `{'strength': 22}`).
  - When referencing non-SRD tomes or manuals, always use generic SRD-compliant/homebrew names (e.g. "Treatise of Inherent Might").
  - Inherent ability score increases clamp against `getAbilityScoreMaximum(ability)` (ceiling of 30). Dual +1 ASI increases must be allocated to two distinct ability scores.

## 9. Lineage Spell Tables & Starting Tool Proficiencies

- **Lineage Spell Ingestion & Extraction:**
  - Species and subraces with `additionalSpells` define innate cantrips (`_`), innate daily spells (`daily`), and expanded spell lists (`expanded.s1`..`s5`).
  - All spells are extracted via `FeatureGrant.extractBonusSpells` with `isCantrip: true` parsed for `#c` tokens or level 0 cantrips.
  - In `SkillTraitResolver.getInnateSpeciesSpells`, `innate` and `known` level keys represent character levels, whereas `expanded` level keys represent spell slot levels (`s1`..`s5`).
  - During character compilation, `CharacterFactory.buildFromDraft` auto-merges species/subrace cantrips into `character.cantrips` and innate/expanded spells into `character.spellsKnown`.
- **Artificer Starting Tool Proficiencies:**
  - Artificers receive Thieves' Tools, Tinker's Tools, and one artisan's tool of choice.
  - `CharacterBuilderScreen._buildClassToolsPrompt` renders an interactive artisan's tool selection chip group while displaying granted tools.
  - `SkillTraitResolver.resolveTools` and `CharacterDraft.reconcile` ensure starting tools for Artificers (`Thieves' Tools`, `Tinker's Tools`), Rogues (`Thieves' Tools`), and Druids (`Herbalism Kit`) are never dropped.

## 10. Class Starting Skills & Attributes-First Flexible Lineage Architecture

- **Class Starting Skills Ingestion:**
  - Class definitions ingest starting skill proficiencies via `CompendiumClassParser.parseClassSkills` from 5eTools `startingProficiencies.skills` (handling `choose.from`, `any`, lists, and `{@skill}` tags) into `customProperties['allowedSkills']` and `customProperties['skillChoiceCount']`.
  - `CharacterClass` exposes domain getters `allowedSkills` (falling back safely to all skills) and `skillChoiceCount` (defaulting to 2).
- **Flexible Lineage Attributes Compilation:**
  - `CharacterDraft.reconcile()` reconciles `pendingFlexibleAbilityChoices` into `speciesBonusScores` for base species (`speciesRef`) as well as subraces (`subraceRef`), honoring `flexibleAbilityPool` bounds.
- **Attributes-First Ordering & Inline Lineage Prompting:**
  - In `CharacterBuilderScreen`, when ability scores are allocated prior to species (`WizardOrderingPreset.attributesFirst` or manual step navigation), selecting a lineage with flexible choices (Half-Elf, Variant Human, Custom Lineage) renders the flexible choices prompt inline directly inside the selected species card.
  - The inline prompt renders a live preview of resulting attributes, updates draft bonuses in real time, and gates advancement until all choices are made.
  - In standard wizard ordering where species precedes attributes, flexible choices can be selected at the species step or finalized at the ability scores step.

