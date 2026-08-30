import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Comprehensive SRD 5.1 (2014) and SRD 5.2 (2024) Feat Library.
@immutable
class SrdFeatsLibrary {
  // --------------------------------------------------------------------------
  // 2024 ORIGIN FEATS (SRD 5.2)
  // --------------------------------------------------------------------------

  static final Feat alert2024 = Feat(
    id: const EntityId(slug: 'alert', ruleset: RulesetVersion.v2024),
    name: 'Alert',
    category: 'Origin',
    descriptionMarkdown:
        '**Initiative Proficiency.** Add your Proficiency Bonus to Initiative rolls.\n\n'
        '**Initiative Swap.** Immediately after rolling Initiative, you can swap your Initiative with a willing ally who rolled Initiative.',
    customProperties: const {
      'isOriginFeat': true,
      'initiativeBonus': 'profBonus',
      'canSwapInitiative': true,
    },
  );

  static final Feat crafter2024 = Feat(
    id: const EntityId(slug: 'crafter', ruleset: RulesetVersion.v2024),
    name: 'Crafter',
    category: 'Origin',
    descriptionMarkdown:
        '**Tool Proficiency.** You gain proficiency with three different Artisan\'s Tools of your choice.\n\n'
        '**Discount.** Whenever you buy a nonmagical item, you receive a 20 percent discount on it.\n\n'
        '**Fast Crafting.** Craft nonmagical items in 20% less time.',
    customProperties: const {
      'isOriginFeat': true,
      'toolProficienciesCount': 3,
      'shoppingDiscountPercent': 20,
    },
  );

  static final Feat healer2024 = Feat(
    id: const EntityId(slug: 'healer', ruleset: RulesetVersion.v2024),
    name: 'Healer',
    category: 'Origin',
    descriptionMarkdown:
        '**Battle Medic.** As an action, you can spend one use of a Healer\'s Kit to tend to a creature and expend one of its Hit Dice. The creature regains HP equal to the roll + your Proficiency Bonus.\n\n'
        '**Healing Rerolls.** Whenever you roll dice to determine the HP a creature regains from a spell or healing ability, you can reroll any 1s.',
    customProperties: const {
      'isOriginFeat': true,
      'rerollHealingOnes': true,
    },
  );

  static final Feat lucky2024 = Feat(
    id: const EntityId(slug: 'lucky', ruleset: RulesetVersion.v2024),
    name: 'Lucky',
    category: 'Origin',
    descriptionMarkdown:
        '**Luck Points.** You have a number of Luck Points equal to your Proficiency Bonus. You regain all spent points on a Long Rest.\n\n'
        '**Advantage / Disadvantage.** Spend 1 Luck Point to gain Advantage on a D20 Test, or force an attacker against you to roll with Disadvantage.',
    customProperties: const {
      'isOriginFeat': true,
      'luckPointsFormula': 'profBonus',
    },
  );

  static final Feat magicInitiate2024 = Feat(
    id: const EntityId(slug: 'magic-initiate', ruleset: RulesetVersion.v2024),
    name: 'Magic Initiate',
    category: 'Origin',
    descriptionMarkdown:
        '**Two Cantrips.** Choose two cantrips from the Cleric, Druid, or Wizard spell list.\n\n'
        '**1st-Level Spell.** Choose one 1st-level spell from the same list. You always have it prepared and can cast it once per Long Rest without expending a spell slot, or using your available spell slots.',
    customProperties: const {
      'isOriginFeat': true,
      'cantripsCount': 2,
      'level1SpellsCount': 1,
    },
  );

  static final Feat musician2024 = Feat(
    id: const EntityId(slug: 'musician', ruleset: RulesetVersion.v2024),
    name: 'Musician',
    category: 'Origin',
    descriptionMarkdown:
        '**Instrument Training.** You gain proficiency with three Musical Instruments of your choice.\n\n'
        '**Inspiring Song.** As a Short or Long Rest activity, play music for your allies. A number of allies up to your Proficiency Bonus gain Heroic Inspiration.',
    customProperties: const {
      'isOriginFeat': true,
      'grantsHeroicInspiration': true,
    },
  );

  static final Feat savageAttacker2024 = Feat(
    id: const EntityId(slug: 'savage-attacker', ruleset: RulesetVersion.v2024),
    name: 'Savage Attacker',
    category: 'Origin',
    descriptionMarkdown:
        '**Brutal Damage.** Once per turn when you hit a target with a weapon, you can roll the weapon’s damage dice twice and use either total.',
    customProperties: const {
      'isOriginFeat': true,
      'rerollWeaponDamage': true,
    },
  );

  static final Feat skilled2024 = Feat(
    id: const EntityId(slug: 'skilled', ruleset: RulesetVersion.v2024),
    name: 'Skilled',
    category: 'Origin',
    descriptionMarkdown:
        '**Versatile Expertise.** You gain proficiency in any combination of three skills or tools of your choice.',
    customProperties: const {
      'isOriginFeat': true,
      'bonusProficienciesCount': 3,
    },
  );

  static final Feat tavernBrawler2024 = Feat(
    id: const EntityId(slug: 'tavern-brawler', ruleset: RulesetVersion.v2024),
    name: 'Tavern Brawler',
    category: 'Origin',
    descriptionMarkdown:
        '**Enhanced Unarmed Strike.** Your unarmed strike deals 1d4 + STR modifier damage.\n\n'
        '**Damage Rerolls.** Whenever you roll a 1 on a damage die for an unarmed strike, you can reroll the die.\n\n'
        '**Pushing Strike.** When you hit with an unarmed strike on your turn, you can deal damage and push the target 5 feet away.',
    customProperties: const {
      'isOriginFeat': true,
      'unarmedDie': '1d4',
      'pushOnHit': true,
    },
  );

  static final Feat tough2024 = Feat(
    id: const EntityId(slug: 'tough', ruleset: RulesetVersion.v2024),
    name: 'Tough',
    category: 'Origin',
    descriptionMarkdown:
        '**Enduring Vitality.** Your hit point maximum increases by an amount equal to twice your character level when you gain this feat. Whenever you gain a level thereafter, your HP maximum increases by an additional 2 hit points.',
    customProperties: const {
      'isOriginFeat': true,
      'hpPerLevelBonus': 2,
    },
  );

  // --------------------------------------------------------------------------
  // GENERAL & COMBAT FEATS (SRD 5.1 & SRD 5.2)
  // --------------------------------------------------------------------------

  static final Feat greatWeaponMaster = Feat(
    id: const EntityId(slug: 'great-weapon-master', ruleset: RulesetVersion.v2024),
    name: 'Great Weapon Master',
    prerequisite: 'Strength 13+ or Level 4+',
    category: 'General',
    descriptionMarkdown:
        '**Heavy Weapon Mastery.** On your turn, when you score a critical hit with a melee weapon or reduce a creature to 0 HP, you can make one melee weapon attack as a bonus action.\n\n'
        '**Heavy Power Attack / Heavy Weapon Mastery.** When attacking with a Heavy weapon, you can add your Proficiency Bonus to damage rolls.',
    customProperties: const {
      'bonusAttackOnCrit': true,
      'addsProficiencyToHeavyDamage': true,
    },
  );

  static final Feat sharpshooter = Feat(
    id: const EntityId(slug: 'sharpshooter', ruleset: RulesetVersion.v2024),
    name: 'Sharpshooter',
    prerequisite: 'Dexterity 13+ or Level 4+',
    category: 'General',
    descriptionMarkdown:
        '**Bypass Cover.** Your ranged weapon attacks ignore Half Cover and Three-Quarters Cover.\n\n'
        '**Point Blank Shots.** Being within 5 feet of a hostile creature doesn’t impose disadvantage on your ranged attack rolls.\n\n'
        '**Extreme Range.** Attacking at long range doesn\'t impose disadvantage on your ranged weapon attack rolls.',
    customProperties: const {
      'ignoresCover': true,
      'noMeleeRangeDisadvantage': true,
    },
  );

  static final Feat warCaster = Feat(
    id: const EntityId(slug: 'war-caster', ruleset: RulesetVersion.v2024),
    name: 'War Caster',
    prerequisite: 'Spellcasting or Pact Magic feature',
    category: 'General',
    descriptionMarkdown:
        '**Concentration Advantage.** You have Advantage on Constitution saving throws that you make to maintain Concentration on a spell when taking damage.\n\n'
        '**Somatic Weaponry.** You can perform the somatic components of spells even when you have weapons or a shield in one or both hands.\n\n'
        '**Reactive Spell.** When a hostile creature triggers an Opportunity Attack from you, you can use your Reaction to cast a spell targeting only that creature instead.',
    customProperties: const {
      'concentrationAdvantage': true,
      'somaticWithWeapons': true,
      'opportunitySpell': true,
    },
  );

  static final Feat sentinel = Feat(
    id: const EntityId(slug: 'sentinel', ruleset: RulesetVersion.v2024),
    name: 'Sentinel',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Zero Speed on Hit.** When you hit a creature with an Opportunity Attack, the creature\'s speed becomes 0 for the rest of the turn.\n\n'
        '**Ignore Disengage.** Creatures provoke Opportunity Attacks from you even if they take the Disengage action.\n\n'
        '**Guardian Reaction.** When a creature within 5 feet makes an attack against an ally, you can use your Reaction to make a melee weapon attack against the attacking creature.',
    customProperties: const {
      'sentinelPin': true,
      'ignoresDisengage': true,
    },
  );

  static final Feat polearmMaster = Feat(
    id: const EntityId(slug: 'polearm-master', ruleset: RulesetVersion.v2024),
    name: 'Polearm Master',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Butt Strike.** When you take the Attack action and attack with only a Glaive, Halberd, Pike, Quarterstaff, or Spear, you can use a Bonus Action to make a melee attack with the opposite end (deals 1d4 bludgeoning).\n\n'
        '**Reach Opportunity Attack.** While you are wielding one of these weapons, other creatures provoke an Opportunity Attack from you when they enter your reach.',
    customProperties: const {
      'bonusButtAttack': true,
      'provokeOnEnterReach': true,
    },
  );

  static final Feat shieldMaster = Feat(
    id: const EntityId(slug: 'shield-master', ruleset: RulesetVersion.v2024),
    name: 'Shield Master',
    prerequisite: 'Shield Proficiency',
    category: 'General',
    descriptionMarkdown:
        '**Shield Bash.** If you take the Attack action on your turn, you can use a Bonus Action to shove a creature within 5 feet of you with your shield.\n\n'
        '**Interposing Shield.** If you aren\'t incapacitated, you can add your shield\'s AC bonus to any Dexterity saving throw you make against a spell or harmful effect targeting only you.\n\n'
        '**Shield Evasion.** When an effect allows a DEX save for half damage, use your Reaction to take no damage on a success.',
    customProperties: const {
      'bonusShieldShove': true,
      'addShieldToDexSave': true,
    },
  );

  static final Feat resilient = Feat(
    id: const EntityId(slug: 'resilient', ruleset: RulesetVersion.v2024),
    name: 'Resilient',
    category: 'General',
    descriptionMarkdown:
        '**Stat & Save Mastery.** Choose one ability score: increase the chosen score by 1, and you gain proficiency in saving throws using that chosen ability score.',
    customProperties: const {
      'grantsSavingThrowProficiency': true,
      'statIncrease': 1,
    },
  );

  static final Feat mobile = Feat(
    id: const EntityId(slug: 'mobile', ruleset: RulesetVersion.v2014),
    name: 'Mobile',
    category: 'General',
    descriptionMarkdown:
        '**Fleet of Foot.** Your speed increases by 10 feet.\n\n'
        '**Agile Dash.** When you use the Dash action, difficult terrain doesn\'t cost you extra movement.\n\n'
        '**Hit and Run.** When you make a melee attack against a creature, you don\'t provoke Opportunity Attacks from that creature for the rest of the turn, whether you hit or not.',
    customProperties: const {
      'speedBonus': 10,
      'freeDisengageOnAttack': true,
    },
  );

  static final Feat dualWielder = Feat(
    id: const EntityId(slug: 'dual-wielder', ruleset: RulesetVersion.v2024),
    name: 'Dual Wielder',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Defensive Pair.** You gain a +1 bonus to AC while you are wielding a separate melee weapon in each hand.\n\n'
        '**Non-Light Dual Wielding.** You can use Two-Weapon Fighting even when the one-handed melee weapons you are wielding aren\'t Light.\n\n'
        '**Quick Draw.** You can draw or stow two one-handed weapons when you would normally be able to draw or stow only one.',
    customProperties: const {
      'dualWieldAcBonus': 1,
      'allowNonLightOffhand': true,
    },
  );

  static final Feat heavyArmorMaster = Feat(
    id: const EntityId(slug: 'heavy-armor-master', ruleset: RulesetVersion.v2024),
    name: 'Heavy Armor Master',
    prerequisite: 'Heavy Armor Proficiency',
    category: 'General',
    descriptionMarkdown:
        '**Damage Reduction.** While wearing Heavy Armor, nonmagical bludgeoning, piercing, and slashing damage that you take from attacks is reduced by your Proficiency Bonus (or 3 in 2014).\n\n'
        '**Strength Increase.** Increase your Strength score by 1, to a maximum of 20.',
    customProperties: const {
      'statIncrease': 1,
      'damageReductionProfBonus': true,
    },
  );

  static final Feat grappler = Feat(
    id: const EntityId(slug: 'grappler', ruleset: RulesetVersion.v2024),
    name: 'Grappler',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Advantage on Grappled Targets.** You have Advantage on attack rolls against a creature you are grappling.\n\n'
        '**Fast Grappler.** You can move at your full speed rather than half speed when carrying or dragging a creature grappled by you.\n\n'
        '**Free Strike.** Once per turn when you hit a creature with an Unarmed Strike, you can deal damage and grapple the target.',
    customProperties: const {
      'advantageOnGrappled': true,
      'fastDrag': true,
    },
  );

  /// Complete list of SRD Feats
  static final List<Feat> allFeats = [
    alert2024,
    crafter2024,
    healer2024,
    lucky2024,
    magicInitiate2024,
    musician2024,
    savageAttacker2024,
    skilled2024,
    tavernBrawler2024,
    tough2024,
    greatWeaponMaster,
    sharpshooter,
    warCaster,
    sentinel,
    polearmMaster,
    shieldMaster,
    resilient,
    mobile,
    dualWielder,
    heavyArmorMaster,
    grappler,
  ];

  /// Filter feats by category
  static List<Feat> getOriginFeats({RulesetVersion ruleset = RulesetVersion.v2024}) {
    if (ruleset == RulesetVersion.v2014) {
      return const []; // 2014 rules have no Origin Feats
    }
    return allFeats.where((f) => f.category == 'Origin').toList();
  }

  static List<Feat> getGeneralFeats() {
    return allFeats.where((f) => f.category == 'General').toList();
  }

  static List<Feat> getFeatsForRuleset(RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2014) {
      // In 2014, feats are General (combat / utility) feats; no Origin feats
      return allFeats.where((f) => f.category != 'Origin').toList();
    }
    return allFeats;
  }

  static Feat? findBySlug(String slug) {
    final clean = slug.toLowerCase().trim();
    return allFeats.where((f) => f.id.slug == clean || f.name.toLowerCase() == clean).firstOrNull;
  }
}
