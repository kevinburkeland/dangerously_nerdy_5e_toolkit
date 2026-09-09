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
