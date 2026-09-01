import 'package:flutter/foundation.dart';
import '../domain/core_types.dart';
import '../domain/homebrew_extended_entities.dart';

/// Canonical Fighting Style feature options shared between Fighter, Paladin, Ranger, and Feats.
class SrdFeatureOptions {
  static const List<FeatureOption> fightingStyles = [
    FeatureOption(
      id: 'archery',
      name: 'Archery',
      descriptionMarkdown: 'You gain a +2 bonus to attack rolls you make with ranged weapons.',
      grants: {'rangedAttackBonus': 2},
    ),
    FeatureOption(
      id: 'defense',
      name: 'Defense',
      descriptionMarkdown: 'While you are wearing armor, you gain a +1 bonus to AC.',
      grants: {'acBonus': 1, 'requiresArmor': true},
    ),
    FeatureOption(
      id: 'dueling',
      name: 'Dueling',
      descriptionMarkdown:
          'When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.',
      grants: {'meleeOneHandedDamageBonus': 2},
    ),
    FeatureOption(
      id: 'great_weapon_fighting',
      name: 'Great Weapon Fighting',
      descriptionMarkdown:
          'When you roll a 1 or 2 on a damage die for an attack you make with a melee weapon that you are wielding with two hands, you can reroll the die.',
      grants: {'rerollDamageOn1or2': true},
    ),
    FeatureOption(
      id: 'protection',
      name: 'Protection',
      descriptionMarkdown:
          'When a creature you can see attacks a target other than you within 5 feet, you can use your reaction to impose Disadvantage on the attack roll (requires shield).',
      grants: {'hasProtectionReaction': true},
    ),
    FeatureOption(
      id: 'two_weapon_fighting',
      name: 'Two-Weapon Fighting',
      descriptionMarkdown:
          'When you engage in two-weapon fighting, you can add your ability modifier to the damage of the second attack.',
      grants: {'offhandDamageModifier': true},
    ),
  ];

  static const List<FeatureOption> clericDivineOrders = [
    FeatureOption(
      id: 'protector',
      name: 'Protector',
      descriptionMarkdown:
          'Trained for battle, you gain Martial weapon proficiency and Heavy armor training.',
      grants: {
        'bonusArmorProficiencies': ['Heavy Armor'],
        'bonusWeaponProficiencies': ['Martial Weapons'],
      },
    ),
    FeatureOption(
      id: 'thaumaturge',
      name: 'Thaumaturge',
      descriptionMarkdown:
          'Delving into sacred mysteries, you learn one extra Cleric cantrip and gain a bonus to Religion and Arcana/Insight checks equal to your Wisdom modifier.',
      grants: {
        'bonusCantripCount': 1,
        'skillAbilityBonus': {'religion': 'wisdom', 'insight': 'wisdom'},
      },
    ),
  ];

  static const List<FeatureOption> druidPrimalOrders = [
    FeatureOption(
      id: 'magician',
      name: 'Magician',
      descriptionMarkdown:
          'You know one extra Druid cantrip. In addition, you gain a bonus to Nature and Animal Handling checks equal to your Wisdom modifier.',
      grants: {
        'bonusCantripCount': 1,
        'skillAbilityBonus': {'nature': 'wisdom', 'animalHandling': 'wisdom'},
      },
    ),
    FeatureOption(
      id: 'warden',
      name: 'Warden',
      descriptionMarkdown:
          'Trained for resilience, you gain Martial weapon proficiency and Medium armor training.',
      grants: {
        'bonusArmorProficiencies': ['Medium Armor'],
        'bonusWeaponProficiencies': ['Martial Weapons'],
      },
    ),
  ];

  static final List<FeatureOption> _baseWarlockInvocations = [
    const FeatureOption(
      id: 'agonizing_blast',
      name: 'Agonizing Blast',
      descriptionMarkdown:
          'When you cast Eldritch Blast, add your Charisma modifier to the damage it deals on a hit.',
      grants: {'eldritchBlastChaDamage': true},
    ),
    const FeatureOption(
      id: 'armor_of_shadows',
      name: 'Armor of Shadows',
      descriptionMarkdown:
          'You can cast Mage Armor on yourself at will, without expending a spell slot or material components.',
      grants: {'atWillSpells': ['mage-armor']},
    ),
    const FeatureOption(
      id: 'ascendant_step',
      name: 'Ascendant Step',
      descriptionMarkdown:
          'Prerequisite: 9th level. You can cast Levitate on yourself at will, without expending a spell slot or material components.',
      grants: {'atWillSpells': ['levitate']},
    ),
    const FeatureOption(
      id: 'beast_speech',
      name: 'Beast Speech',
      descriptionMarkdown:
          'You can cast Speak with Animals at will, without expending a spell slot.',
      grants: {'atWillSpells': ['speak-with-animals']},
    ),
    const FeatureOption(
      id: 'beguiling_influence',
      name: 'Beguiling Influence',
      descriptionMarkdown:
          'You gain proficiency in the Deception and Persuasion skills.',
      grants: {'bonusSkills': ['deception', 'persuasion']},
    ),
    const FeatureOption(
      id: 'book_of_ancient_secrets',
      name: 'Book of Ancient Secrets',
      descriptionMarkdown:
          'Prerequisite: Pact of the Tome feature. You can inscribe magical rituals in your Book of Shadows and cast ritual spells from any class list.',
      grants: {'ritualCasting': true},
    ),
    const FeatureOption(
      id: 'chains_of_carceri',
      name: 'Chains of Carceri',
      descriptionMarkdown:
          'Prerequisite: 15th level, Pact of the Chain feature. You can cast Hold Monster at will targeting a celestial, fiend, or elemental without expending a spell slot.',
      grants: {'atWillSpells': ['hold-monster']},
    ),
    const FeatureOption(
      id: 'devils_sight',
      name: 'Devil\'s Sight',
      descriptionMarkdown:
          'You can see normally in darkness, both magical and nonmagical, to a distance of 120 feet.',
      grants: {'darkvisionFeet': 120, 'seeMagicalDarkness': true},
    ),
    const FeatureOption(
      id: 'dreadful_word',
      name: 'Dreadful Word',
      descriptionMarkdown:
          'Prerequisite: 7th level. You can cast Confusion once using a warlock spell slot.',
      grants: {'bonusSpells': ['confusion']},
    ),
    const FeatureOption(
      id: 'eldritch_sight',
      name: 'Eldritch Sight',
      descriptionMarkdown:
          'You can cast Detect Magic at will, without expending a spell slot.',
      grants: {'atWillSpells': ['detect-magic']},
    ),
    const FeatureOption(
      id: 'eldritch_spear',
      name: 'Eldritch Spear',
      descriptionMarkdown:
          'Prerequisite: Eldritch Blast cantrip. When you cast Eldritch Blast, its range increases to 300 feet.',
      grants: {'eldritchBlastRangeFeet': 300},
    ),
    const FeatureOption(
      id: 'eyes_of_the_rune_keeper',
      name: 'Eyes of the Rune Keeper',
      descriptionMarkdown:
          'You can read all writing.',
      grants: {'readAllWriting': true},
    ),
    const FeatureOption(
      id: 'fiendish_vigor',
      name: 'Fiendish Vigor',
      descriptionMarkdown:
          'You can cast False Life on yourself at will as a 1st-level spell, without expending a spell slot or material components.',
      grants: {'atWillSpells': ['false-life']},
    ),
    const FeatureOption(
      id: 'gaze_of_two_minds',
      name: 'Gaze of Two Minds',
      descriptionMarkdown:
          'You can use your action to touch a willing humanoid and perceive through its senses until the end of your next turn.',
      grants: {'gazeOfTwoMinds': true},
    ),
    const FeatureOption(
      id: 'lessons_of_the_first_ones',
      name: 'Lessons of the First Ones',
      descriptionMarkdown:
          'You receive an Origin Feat of your choice from the feat library.',
      grants: {'bonusOriginFeat': true},
    ),
    const FeatureOption(
      id: 'lifedrinker',
      name: 'Lifedrinker',
      descriptionMarkdown:
          'Prerequisite: 9th/12th level, Pact of the Blade feature. When you hit a creature with your pact weapon, the creature takes extra necrotic or radiant damage equal to your Charisma modifier.',
      grants: {'lifedrinkerDamage': true},
    ),
    const FeatureOption(
      id: 'mask_of_many_faces',
      name: 'Mask of Many Faces',
      descriptionMarkdown:
          'You can cast Disguise Self at will, without expending a spell slot.',
      grants: {'atWillSpells': ['disguise-self']},
    ),
    const FeatureOption(
      id: 'misty_visions',
      name: 'Misty Visions',
      descriptionMarkdown:
          'You can cast Silent Image at will, without expending a spell slot or material components.',
      grants: {'atWillSpells': ['silent-image']},
    ),
    const FeatureOption(
      id: 'one_with_shadows',
      name: 'One with Shadows',
      descriptionMarkdown:
          'Prerequisite: 5th level. When you are in an area of dim light or darkness, you can use your action to become invisible until you move or take an action or a reaction.',
      grants: {'oneWithShadows': true},
    ),
    const FeatureOption(
      id: 'otherworldly_leap',
      name: 'Otherworldly Leap',
      descriptionMarkdown:
          'Prerequisite: 9th level. You can cast Jump on yourself at will, without expending a spell slot.',
      grants: {'atWillSpells': ['jump']},
    ),
    const FeatureOption(
      id: 'pact_of_the_blade',
      name: 'Pact of the Blade',
      descriptionMarkdown:
          'You can conjure or bond with a magical melee weapon. You can use your Charisma modifier instead of Strength or Dexterity for attack and damage rolls with that weapon.',
      grants: {'chaWeaponAttacks': true, 'bladePact': true},
    ),
    const FeatureOption(
      id: 'pact_of_the_chain',
      name: 'Pact of the Chain',
      descriptionMarkdown:
          'You learn the Find Familiar spell and can summon special forms: Imp, Pseudodragon, Quasit, or Sprite.',
      grants: {'bonusSpells': ['find-familiar']},
    ),
    const FeatureOption(
      id: 'pact_of_the_tome',
      name: 'Pact of the Tome',
      descriptionMarkdown:
          'Your patron bestows a grimoire called the Book of Shadows. You learn 3 cantrips from any class list and can cast ritual spells.',
      grants: {'bonusCantripCount': 3, 'ritualCasting': true},
    ),
    const FeatureOption(
      id: 'repelling_blast',
      name: 'Repelling Blast',
      descriptionMarkdown:
          'Prerequisite: Eldritch Blast cantrip. When you hit a creature with Eldritch Blast, you can push the creature up to 10 feet away from you in a straight line.',
      grants: {'repellingBlast': true},
    ),
    const FeatureOption(
      id: 'sculptor_of_flesh',
      name: 'Sculptor of Flesh',
      descriptionMarkdown:
          'Prerequisite: 7th level. You can cast Polymorph once using a warlock spell slot.',
      grants: {'bonusSpells': ['polymorph']},
    ),
    const FeatureOption(
      id: 'sign_of_ill_omen',
      name: 'Sign of Ill Omen',
      descriptionMarkdown:
          'Prerequisite: 5th level. You can cast Bestow Curse once using a warlock spell slot.',
      grants: {'bonusSpells': ['bestow-curse']},
    ),
    const FeatureOption(
      id: 'thief_of_five_fates',
      name: 'Thief of Five Fates',
      descriptionMarkdown:
          'You can cast Bane once using a warlock spell slot.',
      grants: {'bonusSpells': ['bane']},
    ),
    const FeatureOption(
      id: 'thirsting_blade',
      name: 'Thirsting Blade',
      descriptionMarkdown:
          'Prerequisite: 5th level, Pact of the Blade feature. You can attack with your pact weapon twice whenever you take the Attack action on your turn.',
      grants: {'extraAttack': true},
    ),
    const FeatureOption(
      id: 'visions_of_distant_realms',
      name: 'Visions of Distant Realms',
      descriptionMarkdown:
          'Prerequisite: 15th level. You can cast Arcane Eye at will, without expending a spell slot.',
      grants: {'atWillSpells': ['arcane-eye']},
    ),
    const FeatureOption(
      id: 'whispers_of_the_grave',
      name: 'Whispers of the Grave',
      descriptionMarkdown:
          'Prerequisite: 9th level. You can cast Speak with Dead at will, without expending a spell slot.',
      grants: {'atWillSpells': ['speak-with-dead']},
    ),
    const FeatureOption(
      id: 'witch_sight',
      name: 'Witch Sight',
      descriptionMarkdown:
          'Prerequisite: 15th level. You can see the true form of any shapechanger or creature concealed by illusion or transmutation magic within 30 feet of you.',
      grants: {'truesightFeet': 30},
    ),
  ];

  static List<FeatureOption> _customInvocations = [];

  /// Dynamic list of all available Eldritch Invocations (Base SRD + Custom Homebrew)
  static List<FeatureOption> get warlockInvocationsAndBoons => [
        ..._baseWarlockInvocations,
        ..._customInvocations,
      ];

  /// All feature options across all classes and custom invocations
  static List<FeatureOption> get allOptions => [
        ...fightingStyles,
        ...clericDivineOrders,
        ...druidPrimalOrders,
        ...warlockInvocationsAndBoons,
      ];

  /// Sets the list of custom homebrew Eldritch Invocations
  static void setCustomInvocations(List<FeatureOption> custom) {
    _customInvocations = List<FeatureOption>.from(custom);
  }

  /// Adds or replaces a custom homebrew invocation
  static void addCustomInvocation(FeatureOption opt) {
    _customInvocations.removeWhere((o) => o.id == opt.id);
    _customInvocations.add(opt);
  }

  /// Removes a custom homebrew invocation by id
  static void removeCustomInvocation(String id) {
    _customInvocations.removeWhere((o) => o.id == id);
  }
}

/// Comprehensive SRD 5.1 and 5.2 Classes Library containing all 12 core classes.
@immutable
class SrdClassesLibrary {
  static const CharacterClass barbarian = CharacterClass(
    id: EntityId(slug: 'barbarian', ruleset: RulesetVersion.v2024),
    name: 'Barbarian',
    hitDie: 'd12',
    primaryAbility: 'Strength',
    savingThrows: ['Strength', 'Constitution'],
    armorProficiencies: ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: ['Simple Weapons', 'Martial Weapons'],
    featuresMarkdown:
        '**Rage.** Gain Advantage on STR checks/saves, bonus melee damage (+2 to +4), and resistance to bludgeoning, piercing, and slashing damage.\n\n'
        '**Unarmored Defense.** When not wearing armor, AC = 10 + DEX mod + CON mod + Shield.\n\n'
        '**Reckless Attack.** Gain Advantage on melee weapon attack rolls using STR, but attack rolls against you have Advantage until your next turn.\n\n'
        '**Danger Sense.** Advantage on DEX saving throws against effects you can see.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'animalHandling',
        'athletics',
        'intimidation',
        'nature',
        'perception',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'path-of-the-berserker', ruleset: RulesetVersion.v2024),
        name: 'Path of the Berserker',
        classSlug: 'barbarian',
        featuresMarkdown:
            '**Frenzy.** While in a Rage, make a bonus melee attack or deal extra frenzy damage on hit.',
      ),
    ],
  );

  static const CharacterClass bard = CharacterClass(
    id: EntityId(slug: 'bard', ruleset: RulesetVersion.v2024),
    name: 'Bard',
    hitDie: 'd8',
    primaryAbility: 'Charisma',
    savingThrows: ['Dexterity', 'Charisma'],
    armorProficiencies: ['Light Armor'],
    weaponProficiencies: [
      'Simple Weapons',
      'Hand Crossbows',
      'Longswords',
      'Rapiers',
      'Shortswords'
    ],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Bardic Inspiration.** Grant an ally an inspiration die (d6-d12) to add to an attack roll, ability check, or saving throw.\n\n'
        '**Spellcasting.** Charisma-based full caster prepared spells.\n\n'
        '**Jack of All Trades.** Add half your Proficiency Bonus to any ability check that doesn\'t already include it.\n\n'
        '**Song of Rest / Restorative Rhythm.** Heal allies during Short Rests.\n\n'
        '**Expertise.** Double proficiency bonus on two chosen skills.',
    customProperties: {
      'skillChoiceCount': 3,
      'allowedSkills': [
        'acrobatics',
        'animalHandling',
        'arcana',
        'athletics',
        'deception',
        'history',
        'insight',
        'intimidation',
        'investigation',
        'medicine',
        'nature',
        'perception',
        'performance',
        'persuasion',
        'religion',
        'sleightOfHand',
        'stealth',
        'survival'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'college-of-lore', ruleset: RulesetVersion.v2024),
        name: 'College of Lore',
        classSlug: 'bard',
        featuresMarkdown:
            '**Cutting Words.** Use Reaction and Bardic Inspiration to subtract from enemy attack rolls, ability checks, or damage.',
      ),
    ],
  );

  static const CharacterClass cleric = CharacterClass(
    id: EntityId(slug: 'cleric', ruleset: RulesetVersion.v2024),
    name: 'Cleric',
    hitDie: 'd8',
    primaryAbility: 'Wisdom',
    savingThrows: ['Wisdom', 'Charisma'],
    armorProficiencies: ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: ['Simple Weapons'],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Spellcasting.** Full divine spellcaster using Wisdom.\n\n'
        '**Divine Order.** Specialization in Protector (Heavy Armor & Martial Weapons) or Thaumaturge (Extra Cantrip & Skill Bonus).\n\n'
        '**Channel Divinity.** Powerful divine surges (e.g. Turn Undead, Divine Spark).\n\n'
        '**Turn Undead.** Undead must flee from you on failed WIS saving throw.\n\n'
        '**Divine Intervention.** Call upon your deity for direct miraculous intervention.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': ['history', 'insight', 'medicine', 'persuasion', 'religion'],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'cleric-divine-order-1',
        name: 'Divine Order',
        prompt: 'Choose your Cleric Divine Order (Protector or Thaumaturge)',
        levelRequired: 1,
        type: FeatureChoiceType.divineOrder,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.clericDivineOrders,
        ruleset: RulesetVersion.v2024,
      ),
    ],
    subclasses: [
      Subclass(
        id: EntityId(slug: 'life-domain', ruleset: RulesetVersion.v2024),
        name: 'Life Domain',
        classSlug: 'cleric',
        featuresMarkdown:
            '**Disciple of Life.** Healing spells restore an additional 2 + spell level HP.\n\n'
            '**Preserve Life.** Channel Divinity to heal injured allies within 30 feet.',
      ),
      Subclass(
        id: EntityId(slug: 'light-domain', ruleset: RulesetVersion.v2024),
        name: 'Light Domain',
        classSlug: 'cleric',
        featuresMarkdown:
            '**Warding Flare.** Impose Disadvantage on an attacker within 30 feet.\n\n'
            '**Radiance of the Dawn.** Channel Divinity to blast radiant energy 30 ft around you.',
      ),
    ],
  );

  static const CharacterClass druid = CharacterClass(
    id: EntityId(slug: 'druid', ruleset: RulesetVersion.v2024),
    name: 'Druid',
    hitDie: 'd8',
    primaryAbility: 'Wisdom',
    savingThrows: ['Intelligence', 'Wisdom'],
    armorProficiencies: ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: [
      'Clubs',
      'Daggers',
      'Darts',
      'Javelins',
      'Maces',
      'Quarterstaffs',
      'Scimitars',
      'Sickles',
      'Slings',
      'Spears'
    ],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Spellcasting.** Nature-based full spellcaster with ritual casting.\n\n'
        '**Primal Order.** Choose Magician (extra cantrip & skill bonus) or Warden (Medium armor & martial weapons).\n\n'
        '**Wild Shape.** Magically transform into the form of a beast or elemental.\n\n'
        '**Wild Companion.** Summon a familiar spirit using your Wild Shape charges.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'animalHandling',
        'insight',
        'medicine',
        'nature',
        'perception',
        'religion',
        'survival'
      ],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'druid-primal-order-1',
        name: 'Primal Order',
        prompt: 'Choose your Druidic Primal Order (Magician or Warden)',
        levelRequired: 1,
        type: FeatureChoiceType.primalOrder,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.druidPrimalOrders,
        ruleset: RulesetVersion.v2024,
      ),
    ],
    subclasses: [
      Subclass(
        id: EntityId(slug: 'circle-of-the-land', ruleset: RulesetVersion.v2024),
        name: 'Circle of the Land',
        classSlug: 'druid',
        featuresMarkdown:
            '**Natural Recovery.** Regain spell slots on Short Rest.\n\n'
            '**Circle Spells.** Gain bonus domain spells based on chosen biome.',
      ),
      Subclass(
        id: EntityId(slug: 'circle-of-the-moon', ruleset: RulesetVersion.v2024),
        name: 'Circle of the Moon',
        classSlug: 'druid',
        featuresMarkdown:
            '**Combat Wild Shape.** Transform as a Bonus Action and assume higher CR beast forms.',
      ),
    ],
  );

  static const CharacterClass fighter = CharacterClass(
    id: EntityId(slug: 'fighter', ruleset: RulesetVersion.v2024),
    name: 'Fighter',
    hitDie: 'd10',
    primaryAbility: 'Strength or Dexterity',
    savingThrows: ['Strength', 'Constitution'],
    armorProficiencies: ['All Armor', 'Shields'],
    weaponProficiencies: ['Simple Weapons', 'Martial Weapons'],
    featuresMarkdown:
        '**Fighting Style.** Select a specialized combat style (Archery, Defense, Dueling, Great Weapon Fighting, Two-Weapon Fighting).\n\n'
        '**Second Wind.** Bonus action to regain 1d10 + Fighter Level HP.\n\n'
        '**Action Surge.** Take an additional Action on your turn once per short or long rest.\n\n'
        '**Extra Attack.** Attack two, three, or four times whenever you take the Attack action.\n\n'
        '**Indomitable.** Reroll a failed saving throw.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'acrobatics',
        'animalHandling',
        'athletics',
        'history',
        'insight',
        'intimidation',
        'perception',
        'survival'
      ],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'fighter-fighting-style-1',
        name: 'Fighting Style',
        prompt: 'Select your 1st-level Fighter Fighting Style',
        levelRequired: 1,
        type: FeatureChoiceType.fightingStyle,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.fightingStyles,
        ruleset: RulesetVersion.v2024,
      ),
      ClassFeatureDecision(
        id: 'fighter-fighting-style-1-2014',
        name: 'Fighting Style',
        prompt: 'Select your 1st-level Fighter Fighting Style',
        levelRequired: 1,
        type: FeatureChoiceType.fightingStyle,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.fightingStyles,
        ruleset: RulesetVersion.v2014,
      ),
    ],
    subclasses: [
      Subclass(
        id: EntityId(slug: 'champion', ruleset: RulesetVersion.v2024),
        name: 'Champion',
        classSlug: 'fighter',
        featuresMarkdown:
            '**Improved Critical.** Your weapon attacks score a critical hit on a roll of 19 or 20.\n\n'
            '**Remarkable Athlete.** Bonus to non-proficient STR, DEX, and CON checks; increased jump distance.',
      ),
      Subclass(
        id: EntityId(slug: 'battle-master', ruleset: RulesetVersion.v2024),
        name: 'Battle Master',
        classSlug: 'fighter',
        featuresMarkdown:
            '**Combat Superiority.** Superiority dice (d8-d12) to fuel tactical battle maneuvers.',
      ),
    ],
  );

  static const CharacterClass monk = CharacterClass(
    id: EntityId(slug: 'monk', ruleset: RulesetVersion.v2024),
    name: 'Monk',
    hitDie: 'd8',
    primaryAbility: 'Dexterity and Wisdom',
    savingThrows: ['Strength', 'Dexterity'],
    armorProficiencies: [],
    weaponProficiencies: ['Simple Weapons', 'Shortswords'],
    featuresMarkdown:
        '**Unarmored Defense.** When not wearing armor or wielding a shield, AC = 10 + DEX mod + WIS mod.\n\n'
        '**Martial Arts.** Use DEX for monk weapons and unarmed strikes; unarmed die scales from 1d6 to 1d12; bonus unarmed attack.\n\n'
        '**Ki / Focus Points.** Flurry of Blows, Patient Defense, Step of the Wind, Stunning Strike.\n\n'
        '**Deflect Attacks.** Reaction to reduce damage from ranged/melee attacks and deflect them back.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'acrobatics',
        'athletics',
        'history',
        'insight',
        'religion',
        'stealth'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'warrior-of-the-open-hand', ruleset: RulesetVersion.v2024),
        name: 'Warrior of the Open Hand',
        classSlug: 'monk',
        featuresMarkdown:
            '**Open Hand Technique.** Flurry of Blows can knock targets prone, push them 15 feet, or remove their reactions.',
      ),
    ],
  );

  static const CharacterClass paladin = CharacterClass(
    id: EntityId(slug: 'paladin', ruleset: RulesetVersion.v2024),
    name: 'Paladin',
    hitDie: 'd10',
    primaryAbility: 'Strength and Charisma',
    savingThrows: ['Wisdom', 'Charisma'],
    armorProficiencies: ['All Armor', 'Shields'],
    weaponProficiencies: ['Simple Weapons', 'Martial Weapons'],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Divine Sense.** Detect celestials, fiends, and undead.\n\n'
        '**Lay on Hands.** Pool of healing points equal to 5 × Paladin Level.\n\n'
        '**Divine Smite.** Channel holy wrath to deal extra radiant damage on melee hits.\n\n'
        '**Aura of Protection.** Add Charisma bonus to all saving throws for you and nearby allies.\n\n'
        '**Extra Attack.** Attack twice per Attack action.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'athletics',
        'insight',
        'intimidation',
        'medicine',
        'persuasion',
        'religion'
      ],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'paladin-fighting-style-2',
        name: 'Fighting Style',
        prompt: 'Select your Paladin Fighting Style',
        levelRequired: 2,
        type: FeatureChoiceType.fightingStyle,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: [
          FeatureOption(
            id: 'defense',
            name: 'Defense',
            descriptionMarkdown: 'While you are wearing armor, you gain a +1 bonus to AC.',
            grants: {'acBonus': 1, 'requiresArmor': true},
          ),
          FeatureOption(
            id: 'dueling',
            name: 'Dueling',
            descriptionMarkdown:
                'When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.',
            grants: {'meleeOneHandedDamageBonus': 2},
          ),
          FeatureOption(
            id: 'great_weapon_fighting',
            name: 'Great Weapon Fighting',
            descriptionMarkdown:
                'When you roll a 1 or 2 on a damage die for an attack you make with a melee weapon that you are wielding with two hands, you can reroll the die.',
            grants: {'rerollDamageOn1or2': true},
          ),
          FeatureOption(
            id: 'protection',
            name: 'Protection',
            descriptionMarkdown:
                'When a creature you can see attacks a target other than you within 5 feet, you can use your reaction to impose Disadvantage on the attack roll (requires shield).',
            grants: {'hasProtectionReaction': true},
          ),
        ],
      ),
    ],
    subclasses: [
      Subclass(
        id: EntityId(slug: 'oath-of-devotion', ruleset: RulesetVersion.v2024),
        name: 'Oath of Devotion',
        classSlug: 'paladin',
        featuresMarkdown:
            '**Sacred Weapon.** Add CHA modifier to weapon attack rolls and emit bright light.\n\n'
            '**Aura of Devotion.** Allies within 10 feet cannot be Charmed.',
      ),
    ],
  );

  static const CharacterClass ranger = CharacterClass(
    id: EntityId(slug: 'ranger', ruleset: RulesetVersion.v2024),
    name: 'Ranger',
    hitDie: 'd10',
    primaryAbility: 'Dexterity and Wisdom',
    savingThrows: ['Strength', 'Dexterity'],
    armorProficiencies: ['Light Armor', 'Medium Armor', 'Shields'],
    weaponProficiencies: ['Simple Weapons', 'Martial Weapons'],
    spellcastingAbility: 'Wisdom',
    featuresMarkdown:
        '**Deft Explorer / Natural Explorer.** Expertise in one skill, climbing and swimming speeds.\n\n'
        '**Favored Enemy / Hunter\'s Mark.** Cast Hunter\'s Mark without expending spell slots and track targets with Advantage.\n\n'
        '**Spellcasting.** Half-caster with primal nature spells.\n\n'
        '**Extra Attack.** Attack twice per Attack action.',
    customProperties: {
      'skillChoiceCount': 3,
      'allowedSkills': [
        'animalHandling',
        'athletics',
        'insight',
        'investigation',
        'nature',
        'perception',
        'stealth',
        'survival'
      ],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'ranger-fighting-style-2',
        name: 'Fighting Style',
        prompt: 'Select your Ranger Fighting Style',
        levelRequired: 2,
        type: FeatureChoiceType.fightingStyle,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: [
          FeatureOption(
            id: 'archery',
            name: 'Archery',
            descriptionMarkdown: 'You gain a +2 bonus to attack rolls you make with ranged weapons.',
            grants: {'rangedAttackBonus': 2},
          ),
          FeatureOption(
            id: 'defense',
            name: 'Defense',
            descriptionMarkdown: 'While you are wearing armor, you gain a +1 bonus to AC.',
            grants: {'acBonus': 1, 'requiresArmor': true},
          ),
          FeatureOption(
            id: 'dueling',
            name: 'Dueling',
            descriptionMarkdown:
                'When you are wielding a melee weapon in one hand and no other weapons, you gain a +2 bonus to damage rolls with that weapon.',
            grants: {'meleeOneHandedDamageBonus': 2},
          ),
          FeatureOption(
            id: 'two_weapon_fighting',
            name: 'Two-Weapon Fighting',
            descriptionMarkdown:
                'When you engage in two-weapon fighting, you can add your ability modifier to the damage of the second attack.',
            grants: {'offhandDamageModifier': true},
          ),
        ],
      ),
    ],
    subclasses: [
      Subclass(
        id: EntityId(slug: 'hunter', ruleset: RulesetVersion.v2024),
        name: 'Hunter',
        classSlug: 'ranger',
        featuresMarkdown:
            '**Hunter\'s Prey.** Choose Colossus Slayer (+1d8 damage on injured foes), Giant Killer, or Horde Breaker.',
      ),
    ],
  );

  static const CharacterClass rogue = CharacterClass(
    id: EntityId(slug: 'rogue', ruleset: RulesetVersion.v2024),
    name: 'Rogue',
    hitDie: 'd8',
    primaryAbility: 'Dexterity',
    savingThrows: ['Dexterity', 'Intelligence'],
    armorProficiencies: ['Light Armor'],
    weaponProficiencies: [
      'Simple Weapons',
      'Hand Crossbows',
      'Longswords',
      'Rapiers',
      'Shortswords'
    ],
    featuresMarkdown:
        '**Sneak Attack.** Deal extra damage (+1d6 to +10d6) once per turn when attacking with Advantage or an ally is within 5 feet.\n\n'
        '**Thieves\' Cant.** Secret dialect and symbols of the underworld.\n\n'
        '**Cunning Action.** Bonus Action to Dash, Disengage, or Hide.\n\n'
        '**Uncanny Dodge.** Reaction to halve incoming attack damage.\n\n'
        '**Evasion.** Take no damage on successful DEX saves against area effects, and half damage on failure.',
    customProperties: {
      'skillChoiceCount': 4,
      'allowedSkills': [
        'acrobatics',
        'athletics',
        'deception',
        'insight',
        'intimidation',
        'investigation',
        'perception',
        'performance',
        'persuasion',
        'sleightOfHand',
        'stealth'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'thief', ruleset: RulesetVersion.v2024),
        name: 'Thief',
        classSlug: 'rogue',
        featuresMarkdown:
            '**Fast Hands.** Use Cunning Action to pick locks, disarm traps, or Use an Object.\n\n'
            '**Second-Story Work.** Climb without movement penalties and jump further.',
      ),
    ],
  );

  static const CharacterClass sorcerer = CharacterClass(
    id: EntityId(slug: 'sorcerer', ruleset: RulesetVersion.v2024),
    name: 'Sorcerer',
    hitDie: 'd6',
    primaryAbility: 'Charisma',
    savingThrows: ['Constitution', 'Charisma'],
    armorProficiencies: [],
    weaponProficiencies: [
      'Daggers',
      'Darts',
      'Slings',
      'Quarterstaffs',
      'Light Crossbows'
    ],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Innate Sorcery.** Innate magic flares to grant Advantage on spell attacks and increase spell save DC by 1.\n\n'
        '**Font of Magic.** Sorcery Points pool for creating spell slots or fueling Metamagic.\n\n'
        '**Metamagic.** Twinned Spell, Quickened Spell, Subtle Spell, Heightened Spell, Empowered Spell, Distant Spell.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'deception',
        'insight',
        'intimidation',
        'persuasion',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'draconic-sorcery', ruleset: RulesetVersion.v2024),
        name: 'Draconic Sorcery',
        classSlug: 'sorcerer',
        featuresMarkdown:
            '**Draconic Resilience.** Base AC 13 + DEX mod, and +1 Max HP per Sorcerer level.\n\n'
            '**Elemental Affinity.** Add CHA modifier to damage matching draconic ancestry.',
        customProperties: {
          'acFormula': '13 + DEX',
          'baseAc': 13,
        },
      ),
      Subclass(
        id: EntityId(slug: 'wild-magic', ruleset: RulesetVersion.v2024),
        name: 'Wild Magic',
        classSlug: 'sorcerer',
        featuresMarkdown:
            '**Tides of Chaos.** Gain Advantage on one d20 roll before taking a long rest.\n\n'
            '**Wild Magic Surge.** Rolling a 1 on a d20 test triggers chaotic surges.',
      ),
    ],
  );

  static CharacterClass get warlock => CharacterClass(
    id: const EntityId(slug: 'warlock', ruleset: RulesetVersion.v2024),
    name: 'Warlock',
    hitDie: 'd8',
    primaryAbility: 'Charisma',
    savingThrows: const ['Wisdom', 'Charisma'],
    armorProficiencies: const ['Light Armor'],
    weaponProficiencies: const ['Simple Weapons'],
    spellcastingAbility: 'Charisma',
    featuresMarkdown:
        '**Pact Magic.** Recharges all max-level spell slots on a Short Rest.\n\n'
        '**Eldritch Invocations.** Agonizing Blast, Repelling Blast, Armor of Shadows, Devil\'s Sight, Mask of Many Faces, etc.\n\n'
        '**Pact Boon.** Pact of the Blade, Pact of the Tome, or Pact of the Chain.\n\n'
        '**Mystic Arcanum.** Cast 6th through 9th level spells once per long rest.',
    customProperties: const {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'deception',
        'history',
        'intimidation',
        'investigation',
        'nature',
        'religion'
      ],
    },
    featureDecisions: [
      ClassFeatureDecision(
        id: 'warlock-invocations-1',
        name: 'Eldritch Invocations',
        prompt: 'Choose your 1st-level Eldritch Invocation or Pact Boon',
        levelRequired: 1,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
        ruleset: RulesetVersion.v2024,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-2',
        name: 'Eldritch Invocations',
        prompt: 'Choose 2 Eldritch Invocations',
        levelRequired: 2,
        type: FeatureChoiceType.invocations,
        minSelections: 2,
        maxSelections: 2,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      const ClassFeatureDecision(
        id: 'warlock-pact-boon-3-2014',
        name: 'Pact Boon',
        prompt: 'Choose your 3rd-level Pact Boon',
        levelRequired: 3,
        type: FeatureChoiceType.pactBoon,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: [
          FeatureOption(
            id: 'pact_of_the_blade',
            name: 'Pact of the Blade',
            descriptionMarkdown:
                'You can conjure or bond with a magical melee weapon.',
            grants: {'bladePact': true},
          ),
          FeatureOption(
            id: 'pact_of_the_tome',
            name: 'Pact of the Tome',
            descriptionMarkdown:
                'Your patron bestows the Book of Shadows with 3 extra cantrips.',
            grants: {'bonusCantripCount': 3},
          ),
          FeatureOption(
            id: 'pact_of_the_chain',
            name: 'Pact of the Chain',
            descriptionMarkdown:
                'You learn Find Familiar with special forms: Imp, Pseudodragon, Quasit, Sprite.',
            grants: {'bonusSpells': ['find-familiar']},
          ),
        ],
        ruleset: RulesetVersion.v2014,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-5',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 5,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-7',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 7,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-9',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 9,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-12',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 12,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-15',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 15,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
      ClassFeatureDecision(
        id: 'warlock-invocations-18',
        name: 'Eldritch Invocations',
        prompt: 'Choose an additional Eldritch Invocation',
        levelRequired: 18,
        type: FeatureChoiceType.invocations,
        minSelections: 1,
        maxSelections: 1,
        availableOptions: SrdFeatureOptions.warlockInvocationsAndBoons,
      ),
    ],
    subclasses: [
      const Subclass(
        id: EntityId(slug: 'fiend-patron', ruleset: RulesetVersion.v2024),
        name: 'The Fiend',
        classSlug: 'warlock',
        featuresMarkdown:
            '**Dark One\'s Blessing.** Gain temporary HP equal to CHA mod + Warlock Level upon reducing a hostile creature to 0 HP.\n\n'
            '**Dark One\'s Own Luck.** Add 1d10 to an ability check or saving throw.',
      ),
      const Subclass(
        id: EntityId(slug: 'archfey-patron', ruleset: RulesetVersion.v2024),
        name: 'The Archfey',
        classSlug: 'warlock',
        featuresMarkdown:
            '**Fey Presence.** Cause creatures in a 10-foot cube to become charmed or frightened.\n\n'
            '**Misty Escape.** Turn invisible and teleport 60 ft as a Reaction upon taking damage.',
      ),
    ],
  );

  static const CharacterClass wizard = CharacterClass(
    id: EntityId(slug: 'wizard', ruleset: RulesetVersion.v2024),
    name: 'Wizard',
    hitDie: 'd6',
    primaryAbility: 'Intelligence',
    savingThrows: ['Intelligence', 'Wisdom'],
    armorProficiencies: [],
    weaponProficiencies: [
      'Daggers',
      'Darts',
      'Slings',
      'Quarterstaffs',
      'Light Crossbows'
    ],
    spellcastingAbility: 'Intelligence',
    featuresMarkdown:
        '**Spellbook.** Copy and master spells found in ancient scrolls and arcane tomes.\n\n'
        '**Ritual Casting.** Cast any ritual spell from your spellbook without preparing it.\n\n'
        '**Arcane Recovery.** Regain expended spell slots equal to half Wizard level on a Short Rest.\n\n'
        '**Spell Mastery.** Cast selected 1st and 2nd level spells at will.',
    customProperties: {
      'skillChoiceCount': 2,
      'allowedSkills': [
        'arcana',
        'history',
        'insight',
        'investigation',
        'medicine',
        'religion'
      ],
    },
    subclasses: [
      Subclass(
        id: EntityId(slug: 'school-of-evocation', ruleset: RulesetVersion.v2024),
        name: 'School of Evocation',
        classSlug: 'wizard',
        featuresMarkdown:
            '**Sculpt Spells.** Protect allies from taking damage or failing saving throws in your area of effect evocation spells.\n\n'
            '**Potent Cantrip.** Foes take half damage even on successful saves against your cantrips.\n\n'
            '**Overchannel.** Maximize damage dice for 1st-5th level spells.',
      ),
    ],
  );

  /// Base Core 12 SRD Classes
  static List<CharacterClass> get _baseClasses => [
    barbarian,
    bard,
    cleric,
    druid,
    fighter,
    monk,
    paladin,
    ranger,
    rogue,
    sorcerer,
    warlock,
    wizard,
  ];

  static List<CharacterClass> _customClasses = [];
  static List<Subclass> _customSubclasses = [];

  /// Dynamic list of all available classes (Base SRD + Custom Homebrew) with their custom subclasses attached
  static List<CharacterClass> get allClasses {
    return [..._baseClasses, ..._customClasses].map((c) {
      final cleanClassSlug = c.id.slug.toLowerCase().trim();
      final cleanClassName = c.name.toLowerCase().trim();

      final matchingCustomSubs = _customSubclasses.where((s) {
        final subClassSlug = s.classSlug.toLowerCase().trim();
        return subClassSlug == cleanClassSlug ||
            subClassSlug == cleanClassName ||
            subClassSlug.replaceAll('-', ' ') == cleanClassName ||
            subClassSlug.replaceAll(' ', '-') == cleanClassSlug;
      }).toList();

      if (matchingCustomSubs.isEmpty) return c;

      final existingSlugs = c.subclasses.map((s) => s.id.slug.toLowerCase().trim()).toSet();
      final newSubs = matchingCustomSubs.where((s) => !existingSlugs.contains(s.id.slug.toLowerCase().trim())).toList();

      if (newSubs.isEmpty) return c;
      return c.copyWith(subclasses: [...c.subclasses, ...newSubs]);
    }).toList();
  }

  /// Dynamic list of all available subclasses across all classes
  static List<Subclass> get allSubclasses {
    final all = <Subclass>[];
    for (final c in allClasses) {
      all.addAll(c.subclasses);
    }
    return all;
  }

  /// Sets the list of custom/homebrew classes
  static void setCustomClasses(List<CharacterClass> custom) {
    _customClasses = List<CharacterClass>.from(custom);
  }

  /// Sets the list of standalone custom/homebrew subclasses
  static void setCustomSubclasses(List<Subclass> custom) {
    _customSubclasses = List<Subclass>.from(custom);
  }

  /// Adds or replaces a custom class in the library
  static void addCustomClass(CharacterClass cls) {
    _customClasses.removeWhere((c) => c.id.slug == cls.id.slug);
    _customClasses.add(cls);
  }

  /// Adds or replaces a custom subclass in the library
  static void addCustomSubclass(Subclass sub) {
    _customSubclasses.removeWhere((s) => s.id.slug == sub.id.slug);
    _customSubclasses.add(sub);
  }

  /// Removes a custom class by slug
  static void removeCustomClass(String slug) {
    _customClasses.removeWhere((c) => c.id.slug == slug);
  }

  /// Removes a custom subclass by slug
  static void removeCustomSubclass(String slug) {
    _customSubclasses.removeWhere((s) => s.id.slug == slug);
  }

  static CharacterClass? findBySlug(String slug, {RulesetVersion? ruleset}) {
    final clean = slug.toLowerCase().trim();
    if (ruleset != null) {
      final match = allClasses.where((c) => (c.id.slug == clean || c.name.toLowerCase() == clean) && c.id.ruleset == ruleset).firstOrNull;
      if (match != null) return match;
    }
    return allClasses.where((c) => c.id.slug == clean || c.name.toLowerCase() == clean).firstOrNull;
  }
}
