import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/feature_grant.dart';
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
    grants: [
      FeatureGrant.passiveBonus(
        grantId: 'feat_alert_initiative',
        stat: 'initiative',
        formula: 'profBonus',
        label: 'Alert: +Prof to Initiative',
      ),
    ],
    customProperties: const {
      'isOriginFeat': true,
      'initiativeBonus': 'profBonus',
      'canSwapInitiative': true,
    },
  );

  static const Feat crafter2024 = Feat(
    id: EntityId(slug: 'crafter', ruleset: RulesetVersion.v2024),
    name: 'Crafter',
    category: 'Origin',
    descriptionMarkdown:
        '**Tool Proficiency.** You gain proficiency with three different Artisan\'s Tools of your choice.\n\n'
        '**Discount.** Whenever you buy a nonmagical item, you receive a 20 percent discount on it.\n\n'
        '**Fast Crafting.** Craft nonmagical items in 20% less time.',
    customProperties: {
      'isOriginFeat': true,
      'toolProficienciesCount': 3,
      'shoppingDiscountPercent': 20,
    },
  );

  static const Feat healer2024 = Feat(
    id: EntityId(slug: 'healer', ruleset: RulesetVersion.v2024),
    name: 'Healer',
    category: 'Origin',
    descriptionMarkdown:
        '**Battle Medic.** As an action, you can spend one use of a Healer\'s Kit to tend to a creature and expend one of its Hit Dice. The creature regains HP equal to the roll + your Proficiency Bonus.\n\n'
        '**Healing Rerolls.** Whenever you roll dice to determine the HP a creature regains from a spell or healing ability, you can reroll any 1s.',
    customProperties: {
      'isOriginFeat': true,
      'rerollHealingOnes': true,
    },
  );

  static const Feat lucky2024 = Feat(
    id: EntityId(slug: 'lucky', ruleset: RulesetVersion.v2024),
    name: 'Lucky',
    category: 'Origin',
    descriptionMarkdown:
        '**Luck Points.** You have a number of Luck Points equal to your Proficiency Bonus. You regain all spent points on a Long Rest.\n\n'
        '**Advantage / Disadvantage.** Spend 1 Luck Point to gain Advantage on a D20 Test, or force an attacker against you to roll with Disadvantage.',
    customProperties: {
      'isOriginFeat': true,
      'luckPointsFormula': 'profBonus',
    },
  );

  static const Feat magicInitiate2024 = Feat(
    id: EntityId(slug: 'magic-initiate', ruleset: RulesetVersion.v2024),
    name: 'Magic Initiate',
    category: 'Origin',
    descriptionMarkdown:
        '**Two Cantrips.** Choose two cantrips from the Cleric, Druid, or Wizard spell list.\n\n'
        '**1st-Level Spell.** Choose one 1st-level spell from the same list. You always have it prepared and can cast it once per Long Rest without expending a spell slot, or using your available spell slots.',
    customProperties: {
      'isOriginFeat': true,
      'cantripsCount': 2,
      'level1SpellsCount': 1,
    },
  );

  static const Feat musician2024 = Feat(
    id: EntityId(slug: 'musician', ruleset: RulesetVersion.v2024),
    name: 'Musician',
    category: 'Origin',
    descriptionMarkdown:
        '**Instrument Training.** You gain proficiency with three Musical Instruments of your choice.\n\n'
        '**Inspiring Song.** As a Short or Long Rest activity, play music for your allies. A number of allies up to your Proficiency Bonus gain Heroic Inspiration.',
    customProperties: {
      'isOriginFeat': true,
      'grantsHeroicInspiration': true,
    },
  );

  static const Feat savageAttacker2024 = Feat(
    id: EntityId(slug: 'savage-attacker', ruleset: RulesetVersion.v2024),
    name: 'Savage Attacker',
    category: 'Origin',
    descriptionMarkdown:
        '**Brutal Damage.** Once per turn when you hit a target with a weapon, you can roll the weapon’s damage dice twice and use either total.',
    customProperties: {
      'isOriginFeat': true,
      'rerollWeaponDamage': true,
    },
  );

  static const Feat skilled2024 = Feat(
    id: EntityId(slug: 'skilled', ruleset: RulesetVersion.v2024),
    name: 'Skilled',
    category: 'Origin',
    descriptionMarkdown:
        '**Versatile Expertise.** You gain proficiency in any combination of three skills or tools of your choice.',
    customProperties: {
      'isOriginFeat': true,
      'bonusProficienciesCount': 3,
    },
  );

  static const Feat tavernBrawler2024 = Feat(
    id: EntityId(slug: 'tavern-brawler', ruleset: RulesetVersion.v2024),
    name: 'Tavern Brawler',
    category: 'Origin',
    descriptionMarkdown:
        '**Enhanced Unarmed Strike.** Your unarmed strike deals 1d4 + STR modifier damage.\n\n'
        '**Damage Rerolls.** Whenever you roll a 1 on a damage die for an unarmed strike, you can reroll the die.\n\n'
        '**Pushing Strike.** When you hit with an unarmed strike on your turn, you can deal damage and push the target 5 feet away.',
    customProperties: {
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
    grants: [
      FeatureGrant.hpBonus(
        grantId: 'feat_tough_hp',
        perLevel: 2,
        label: 'Tough: +2 HP/level',
      ),
    ],
    customProperties: const {
      'isOriginFeat': true,
      'hpPerLevelBonus': 2,
    },
  );

  // --------------------------------------------------------------------------
  // GENERAL & COMBAT FEATS (SRD 5.1 & SRD 5.2)
  // --------------------------------------------------------------------------

  static const Feat greatWeaponMaster = Feat(
    id: EntityId(slug: 'great-weapon-master', ruleset: RulesetVersion.v2024),
    name: 'Great Weapon Master',
    prerequisite: 'Strength 13+ or Level 4+',
    category: 'General',
    descriptionMarkdown:
        '**Heavy Weapon Mastery.** On your turn, when you score a critical hit with a melee weapon or reduce a creature to 0 HP, you can make one melee weapon attack as a bonus action.\n\n'
        '**Heavy Power Attack / Heavy Weapon Mastery.** When attacking with a Heavy weapon, you can add your Proficiency Bonus to damage rolls.',
    customProperties: {
      'bonusAttackOnCrit': true,
      'addsProficiencyToHeavyDamage': true,
    },
  );

  static const Feat sharpshooter = Feat(
    id: EntityId(slug: 'sharpshooter', ruleset: RulesetVersion.v2024),
    name: 'Sharpshooter',
    prerequisite: 'Dexterity 13+ or Level 4+',
    category: 'General',
    descriptionMarkdown:
        '**Bypass Cover.** Your ranged weapon attacks ignore Half Cover and Three-Quarters Cover.\n\n'
        '**Point Blank Shots.** Being within 5 feet of a hostile creature doesn’t impose disadvantage on your ranged attack rolls.\n\n'
        '**Extreme Range.** Attacking at long range doesn\'t impose disadvantage on your ranged weapon attack rolls.',
    customProperties: {
      'ignoresCover': true,
      'noMeleeRangeDisadvantage': true,
    },
  );

  static const Feat warCaster = Feat(
    id: EntityId(slug: 'war-caster', ruleset: RulesetVersion.v2024),
    name: 'War Caster',
    prerequisite: 'Spellcasting or Pact Magic feature',
    category: 'General',
    descriptionMarkdown:
        '**Concentration Advantage.** You have Advantage on Constitution saving throws that you make to maintain Concentration on a spell when taking damage.\n\n'
        '**Somatic Weaponry.** You can perform the somatic components of spells even when you have weapons or a shield in one or both hands.\n\n'
        '**Reactive Spell.** When a hostile creature triggers an Opportunity Attack from you, you can use your Reaction to cast a spell targeting only that creature instead.',
    customProperties: {
      'concentrationAdvantage': true,
      'somaticWithWeapons': true,
      'opportunitySpell': true,
    },
  );

  static const Feat sentinel = Feat(
    id: EntityId(slug: 'sentinel', ruleset: RulesetVersion.v2024),
    name: 'Sentinel',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Zero Speed on Hit.** When you hit a creature with an Opportunity Attack, the creature\'s speed becomes 0 for the rest of the turn.\n\n'
        '**Ignore Disengage.** Creatures provoke Opportunity Attacks from you even if they take the Disengage action.\n\n'
        '**Guardian Reaction.** When a creature within 5 feet makes an attack against an ally, you can use your Reaction to make a melee weapon attack against the attacking creature.',
    customProperties: {
      'sentinelPin': true,
      'ignoresDisengage': true,
    },
  );

  static const Feat polearmMaster = Feat(
    id: EntityId(slug: 'polearm-master', ruleset: RulesetVersion.v2024),
    name: 'Polearm Master',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Butt Strike.** When you take the Attack action and attack with only a Glaive, Halberd, Pike, Quarterstaff, or Spear, you can use a Bonus Action to make a melee attack with the opposite end (deals 1d4 bludgeoning).\n\n'
        '**Reach Opportunity Attack.** While you are wielding one of these weapons, other creatures provoke an Opportunity Attack from you when they enter your reach.',
    customProperties: {
      'bonusButtAttack': true,
      'provokeOnEnterReach': true,
    },
  );

  static const Feat shieldMaster = Feat(
    id: EntityId(slug: 'shield-master', ruleset: RulesetVersion.v2024),
    name: 'Shield Master',
    prerequisite: 'Shield Proficiency',
    category: 'General',
    descriptionMarkdown:
        '**Shield Bash.** If you take the Attack action on your turn, you can use a Bonus Action to shove a creature within 5 feet of you with your shield.\n\n'
        '**Interposing Shield.** If you aren\'t incapacitated, you can add your shield\'s AC bonus to any Dexterity saving throw you make against a spell or harmful effect targeting only you.\n\n'
        '**Shield Evasion.** When an effect allows a DEX save for half damage, use your Reaction to take no damage on a success.',
    customProperties: {
      'bonusShieldShove': true,
      'addShieldToDexSave': true,
    },
  );

  static const Feat resilient = Feat(
    id: EntityId(slug: 'resilient', ruleset: RulesetVersion.v2024),
    name: 'Resilient',
    category: 'General',
    descriptionMarkdown:
        '**Stat & Save Mastery.** Choose one ability score: increase the chosen score by 1, and you gain proficiency in saving throws using that chosen ability score.',
    customProperties: {
      'selectableAbilities': [
        'strength',
        'dexterity',
        'constitution',
        'intelligence',
        'wisdom',
        'charisma',
      ],
      'grantsSavingThrowProficiency': true,
      'statIncrease': 1,
      'riderDescription': 'Gain saving throw proficiency in the chosen ability.',
    },
  );

  static const Feat mobile = Feat(
    id: EntityId(slug: 'mobile', ruleset: RulesetVersion.v2014),
    name: 'Mobile',
    category: 'General',
    descriptionMarkdown:
        '**Fleet of Foot.** Your speed increases by 10 feet.\n\n'
        '**Agile Dash.** When you use the Dash action, difficult terrain doesn\'t cost you extra movement.\n\n'
        '**Hit and Run.** When you make a melee attack against a creature, you don\'t provoke Opportunity Attacks from that creature for the rest of the turn, whether you hit or not.',
    customProperties: {
      'speedBonus': 10,
      'freeDisengageOnAttack': true,
    },
  );

  static const Feat dualWielder = Feat(
    id: EntityId(slug: 'dual-wielder', ruleset: RulesetVersion.v2024),
    name: 'Dual Wielder',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Defensive Pair.** You gain a +1 bonus to AC while you are wielding a separate melee weapon in each hand.\n\n'
        '**Non-Light Dual Wielding.** You can use Two-Weapon Fighting even when the one-handed melee weapons you are wielding aren\'t Light.\n\n'
        '**Quick Draw.** You can draw or stow two one-handed weapons when you would normally be able to draw or stow only one.',
    customProperties: {
      'dualWieldAcBonus': 1,
      'allowNonLightOffhand': true,
    },
  );

  static const Feat heavyArmorMaster = Feat(
    id: EntityId(slug: 'heavy-armor-master', ruleset: RulesetVersion.v2024),
    name: 'Heavy Armor Master',
    prerequisite: 'Heavy Armor Proficiency',
    category: 'General',
    descriptionMarkdown:
        '**Damage Reduction.** While wearing Heavy Armor, nonmagical bludgeoning, piercing, and slashing damage that you take from attacks is reduced by your Proficiency Bonus (or 3 in 2014).\n\n'
        '**Strength Increase.** Increase your Strength score by 1, to a maximum of 20.',
    customProperties: {
      'selectableAbilities': ['strength'],
      'statIncrease': 1,
      'damageReductionProfBonus': true,
    },
  );

  static const Feat grappler = Feat(
    id: EntityId(slug: 'grappler', ruleset: RulesetVersion.v2024),
    name: 'Grappler',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Advantage on Grappled Targets.** You have Advantage on attack rolls against a creature you are grappling.\n\n'
        '**Fast Grappler.** You can move at your full speed rather than half speed when carrying or dragging a creature grappled by you.\n\n'
        '**Free Strike.** Once per turn when you hit a creature with an Unarmed Strike, you can deal damage and grapple the target.',
    customProperties: {
      'advantageOnGrappled': true,
      'fastDrag': true,
    },
  );

  static const Feat crossbowExpert = Feat(
    id: EntityId(slug: 'crossbow-expert', ruleset: RulesetVersion.v2024),
    name: 'Crossbow Expert',
    prerequisite: 'Dexterity 13+ or Level 4+',
    category: 'General',
    descriptionMarkdown:
        '**Ignore Loading.** You ignore the loading property of crossbows with which you are proficient.\n\n'
        '**Close Combat Shooter.** Being within 5 feet of a hostile creature doesn’t impose disadvantage on your ranged attack rolls.\n\n'
        '**Hand Crossbow Bonus Attack.** When you use the Attack action and attack with a one-handed weapon, you can use a bonus action to attack with a hand crossbow you are holding.',
    customProperties: {
      'ignoreLoading': true,
      'noMeleeRangeDisadvantage': true,
    },
  );

  static const Feat defensiveDuelist = Feat(
    id: EntityId(slug: 'defensive-duelist', ruleset: RulesetVersion.v2024),
    name: 'Defensive Duelist',
    prerequisite: 'Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Parry.** When you are wielding a finesse weapon with which you are proficient and another creature hits you with a melee attack, you can use your reaction to add your proficiency bonus to your AC for that attack, potentially causing the attack to miss you.',
    customProperties: {
      'reactionAcBonus': 'profBonus',
    },
  );

  static const Feat elementalAdept = Feat(
    id: EntityId(slug: 'elemental-adept', ruleset: RulesetVersion.v2024),
    name: 'Elemental Adept',
    prerequisite: 'Spellcasting feature',
    category: 'General',
    descriptionMarkdown:
        '**Resistance Bypass.** Spells you cast ignore resistance to damage of the chosen type (Acid, Cold, Fire, Lightning, or Thunder).\n\n'
        '**Damage Floor.** When you roll damage for a spell you cast that deals damage of that type, you can treat any 1 on a damage die as a 2.',
    customProperties: {
      'bypassesElementalResistance': true,
      'onesAsTwos': true,
    },
  );

  static const Feat inspiringLeader = Feat(
    id: EntityId(slug: 'inspiring-leader', ruleset: RulesetVersion.v2024),
    name: 'Inspiring Leader',
    prerequisite: 'Charisma 13+',
    category: 'General',
    descriptionMarkdown:
        '**Inspiring Speech.** Spend 10 minutes inspiring your companions. Choose up to 6 friendly creatures (which can include yourself) within 30 feet. Each creature gains Temporary HP equal to your level + your Charisma modifier once per Short or Long Rest.',
    customProperties: {
      'tempHpFormula': 'level+chaMod',
    },
  );

  static const Feat mageSlayer = Feat(
    id: EntityId(slug: 'mage-slayer', ruleset: RulesetVersion.v2024),
    name: 'Mage Slayer',
    category: 'General',
    descriptionMarkdown:
        '**Spell Disruption.** When a creature within 5 feet of you casts a spell, you can use your reaction to make a melee weapon attack against that creature.\n\n'
        '**Concentration Breaker.** When you damage a creature that is concentrating on a spell, that creature has disadvantage on the saving throw it makes to maintain its concentration.\n\n'
        '**Spell Resistance.** You have advantage on saving throws against spells cast by creatures within 5 feet of you.',
    customProperties: {
      'reactionAttackOnSpellCast': true,
      'disadvantageOnConcentration': true,
      'advantageOnCloseSpellSaves': true,
    },
  );

  static const Feat mediumArmorMaster = Feat(
    id: EntityId(slug: 'medium-armor-master', ruleset: RulesetVersion.v2024),
    name: 'Medium Armor Master',
    prerequisite: 'Medium Armor Proficiency',
    category: 'General',
    descriptionMarkdown:
        '**No Stealth Disadvantage.** Wearing medium armor doesn’t impose disadvantage on your Dexterity (Stealth) checks.\n\n'
        '**Dexterity Cap Increase.** When you wear medium armor, you can add 3, rather than 2, to your AC if you have a Dexterity of 16 or higher.',
    customProperties: {
      'noStealthDisadvantage': true,
      'maxMediumArmorDexBonus': 3,
    },
  );

  static const Feat mountedCombatant = Feat(
    id: EntityId(slug: 'mounted-combatant', ruleset: RulesetVersion.v2024),
    name: 'Mounted Combatant',
    category: 'General',
    descriptionMarkdown:
        '**Advantage from High Ground.** You have advantage on melee attack rolls against any unmounted creature that is smaller than your mount.\n\n'
        '**Mount Redirection.** You can force an attack targeted at your mount to target you instead.\n\n'
        '**Mount Evasion.** If your mount is subjected to an effect that allows a Dexterity saving throw to take only half damage, it instead takes no damage if it succeeds on the saving throw, and only half damage if it fails.',
    customProperties: {
      'advantageMounted': true,
      'mountEvasion': true,
    },
  );

  static const Feat observant = Feat(
    id: EntityId(slug: 'observant', ruleset: RulesetVersion.v2024),
    name: 'Observant',
    prerequisite: 'Intelligence or Wisdom 13+',
    category: 'General',
    descriptionMarkdown:
        '**Stat Increase.** Increase your Intelligence or Wisdom score by 1, to a maximum of 20.\n\n'
        '**Lip Reading.** If you can see a creature’s mouth while it is speaking a language you understand, you can interpret what it’s saying by reading its lips.\n\n'
        '**Passive Senses Bonus.** You have a +5 bonus to your passive Wisdom (Perception) and passive Intelligence (Investigation) scores.',
    customProperties: {
      'selectableAbilities': ['intelligence', 'wisdom'],
      'statIncrease': 1,
      'passivePerceptionBonus': 5,
      'passiveInvestigationBonus': 5,
    },
  );

  static const Feat ritualCaster = Feat(
    id: EntityId(slug: 'ritual-caster', ruleset: RulesetVersion.v2024),
    name: 'Ritual Caster',
    prerequisite: 'Intelligence or Wisdom 13+',
    category: 'General',
    descriptionMarkdown:
        '**Ritual Book.** You acquire a ritual book holding two 1st-level spells of your choice with the ritual tag from a chosen class spell list. You can cast these spells as rituals.\n\n'
        '**Copying Rituals.** You can add other ritual spells to your ritual book if you find them on scrolls or spellbooks.',
    customProperties: {
      'grantsRitualBook': true,
    },
  );

  static const Feat spellSniper = Feat(
    id: EntityId(slug: 'spell-sniper', ruleset: RulesetVersion.v2024),
    name: 'Spell Sniper',
    prerequisite: 'The ability to cast at least one spell',
    category: 'General',
    descriptionMarkdown:
        '**Double Range.** When you cast a spell that requires you to make an attack roll, the spell’s range is doubled.\n\n'
        '**Bypass Cover.** Your ranged spell attacks ignore half cover and three-quarters cover.\n\n'
        '**Bonus Attack Cantrip.** You learn one cantrip that requires an attack roll.',
    customProperties: {
      'doubleSpellRange': true,
      'ignoresSpellCover': true,
    },
  );

  static const Feat athlete = Feat(
    id: EntityId(slug: 'athlete', ruleset: RulesetVersion.v2024),
    name: 'Athlete',
    prerequisite: 'Strength or Dexterity 13+',
    category: 'General',
    descriptionMarkdown:
        '**Stat Increase.** Increase your Strength or Dexterity score by 1, to a maximum of 20.\n\n'
        '**Quick Stand.** When you are prone, standing up uses only 5 feet of your movement.\n\n'
        '**Swift Climb.** Climbing doesn’t cost you extra movement.\n\n'
        '**Running Jump.** You can make a running long jump or a running high jump after moving only 5 feet on foot, rather than 10 feet.',
    customProperties: {
      'selectableAbilities': ['strength', 'dexterity'],
      'statIncrease': 1,
      'quickStandFeet': 5,
      'climbNoExtraCost': true,
    },
  );

  static const Feat actor = Feat(
    id: EntityId(slug: 'actor', ruleset: RulesetVersion.v2024),
    name: 'Actor',
    prerequisite: 'Charisma 13+',
    category: 'General',
    descriptionMarkdown:
        '**Stat Increase.** Increase your Charisma score by 1, to a maximum of 20.\n\n'
        '**Impersonation Advantage.** You have advantage on Charisma (Deception) and Charisma (Performance) checks when trying to pass yourself off as a different person.\n\n'
        '**Vocal Mimicry.** You can mimic the speech of another person or the sounds made by other creatures that you have heard for at least 1 minute.',
    customProperties: {
      'selectableAbilities': ['charisma'],
      'statIncrease': 1,
      'advantageOnDeceptionImpersonation': true,
    },
  );

  static const Feat dungeonDelver = Feat(
    id: EntityId(slug: 'dungeon-delver', ruleset: RulesetVersion.v2024),
    name: 'Dungeon Delver',
    category: 'General',
    descriptionMarkdown:
        '**Trap Detection.** You have advantage on Wisdom (Perception) and Intelligence (Investigation) checks made to detect the presence of secret doors.\n\n'
        '**Trap Saves & Resistance.** You have advantage on saving throws made to avoid or resist traps, and resistance to the damage dealt by traps.\n\n'
        '**Pace Freedom.** Searching for traps doesn’t slow your travel pace.',
    customProperties: {
      'advantageSecretDoors': true,
      'advantageTrapSaves': true,
      'trapDamageResistance': true,
    },
  );

  static const Feat durable = Feat(
    id: EntityId(slug: 'durable', ruleset: RulesetVersion.v2024),
    name: 'Durable',
    prerequisite: 'Constitution 13+',
    category: 'General',
    descriptionMarkdown:
        '**Stat Increase.** Increase your Constitution score by 1, to a maximum of 20.\n\n'
        '**Minimum HP Recovery.** When you roll a Hit Die to regain hit points, the minimum number of hit points you regain from the roll equals twice your Constitution modifier (minimum of 2).',
    customProperties: {
      'selectableAbilities': ['constitution'],
      'statIncrease': 1,
      'minHitDieRecoveryTwiceCon': true,
    },
  );

  static const Feat keenMind = Feat(
    id: EntityId(slug: 'keen-mind', ruleset: RulesetVersion.v2024),
    name: 'Keen Mind',
    prerequisite: 'Intelligence 13+',
    category: 'General',
    descriptionMarkdown:
        '**Stat Increase.** Increase your Intelligence score by 1, to a maximum of 20.\n\n'
        '**Direction Sense.** You always know which way is north.\n\n'
        '**Time Sense.** You always know the number of hours left before the next sunrise or sunset.\n\n'
        '**Perfect Recall.** You can accurately recall anything you have seen or heard within the past month.',
    customProperties: {
      'selectableAbilities': ['intelligence'],
      'statIncrease': 1,
      'perfectRecall': true,
    },
  );

  /// Base Core SRD Feats
  static final List<Feat> _baseFeats = [
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
    crossbowExpert,
    defensiveDuelist,
    elementalAdept,
    inspiringLeader,
    mageSlayer,
    mediumArmorMaster,
    mountedCombatant,
    observant,
    ritualCaster,
    spellSniper,
    athlete,
    actor,
    dungeonDelver,
    durable,
    keenMind,
  ];

  static List<Feat> _customFeats = [];

  /// Dynamic list of all available feats (Base SRD + Custom Homebrew)
  static List<Feat> get allFeats => [..._baseFeats, ..._customFeats];

  /// Sets the list of custom/homebrew feats
  static void setCustomFeats(List<Feat> custom) {
    _customFeats = List<Feat>.from(custom);
  }

  /// Adds or replaces a custom feat in the library
  static void addCustomFeat(Feat feat) {
    _customFeats.removeWhere((f) => f.id.slug == feat.id.slug);
    _customFeats.add(feat);
  }

  /// Removes a custom feat by slug
  static void removeCustomFeat(String slug) {
    _customFeats.removeWhere((f) => f.id.slug == slug);
  }

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
