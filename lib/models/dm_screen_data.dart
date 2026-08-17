import 'package:flutter/material.dart';

enum DmRulesEdition {
  v2014,
  v2024,
}

enum DmCategory {
  actions('Actions & Combat', Icons.sports_kabaddi, Colors.amber),
  conditions('Conditions & Statuses', Icons.medical_information_outlined, Colors.cyanAccent),
  environment('Environment & Hazards', Icons.landscape_outlined, Colors.lightGreenAccent),
  exploration('Exploration & DCs', Icons.explore_outlined, Colors.orangeAccent),
  magicAndResting('Magic & Resting', Icons.auto_awesome, Colors.purpleAccent),
  tables('Quick Reference Tables', Icons.table_chart_outlined, Colors.pinkAccent);

  final String label;
  final IconData icon;
  final Color color;

  const DmCategory(this.label, this.icon, this.color);
}

class DmReferenceItem {
  final String id;
  final String title;
  final String? title2014;
  final String? title2024;
  final DmCategory category;
  final String? subCategory;
  final String? cost;
  final String? cost2014;
  final String? cost2024;
  final IconData icon;
  final Color color;
  final String summary;
  final List<String> rules2014;
  final List<String> rules2024;
  final String? diffSummary;
  final List<String> tags;
  final bool isChangedIn2024;
  final Map<String, dynamic>? extraData;

  const DmReferenceItem({
    required this.id,
    required this.title,
    this.title2014,
    this.title2024,
    required this.category,
    this.subCategory,
    this.cost,
    this.cost2014,
    this.cost2024,
    required this.icon,
    required this.color,
    required this.summary,
    required this.rules2014,
    required this.rules2024,
    this.diffSummary,
    required this.tags,
    this.isChangedIn2024 = false,
    this.extraData,
  });

  String getTitle(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014 && title2014 != null) return title2014!;
    if (edition == DmRulesEdition.v2024 && title2024 != null) return title2024!;
    return title;
  }

  String? getCost(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014 && cost2014 != null) return cost2014;
    if (edition == DmRulesEdition.v2024 && cost2024 != null) return cost2024;
    return cost;
  }

  List<String> getRules(DmRulesEdition edition) {
    return edition == DmRulesEdition.v2014 ? rules2014 : rules2024;
  }

  static final Map<String, String> _corpusCache = {};

  String _getCorpus() {
    final cached = _corpusCache[id];
    if (cached != null) return cached;
    final buffer = StringBuffer()
      ..write('$title ')
      ..write('${title2014 ?? ""} ')
      ..write('${title2024 ?? ""} ')
      ..write('$summary ')
      ..write('${category.label} ')
      ..write('${subCategory ?? ""} ')
      ..write('${cost ?? ""} ')
      ..write('${cost2014 ?? ""} ')
      ..write('${cost2024 ?? ""} ')
      ..write('${diffSummary ?? ""} ');
    for (final t in tags) {
      buffer.write('$t ');
    }
    for (final r in rules2014) {
      buffer.write('$r ');
    }
    for (final r in rules2024) {
      buffer.write('$r ');
    }
    final corpus = buffer.toString().toLowerCase();
    _corpusCache[id] = corpus;
    return corpus;
  }

  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;
    final q = trimmed.toLowerCase();
    return _getCorpus().contains(q);
  }
}

class DmScreenLibrary {
  static const List<String> conditionCategories = [
    'All',
    'Incapacitating',
    'Movement',
    'Combat / Checks',
    'Exhaustion',
  ];

  static List<DmReferenceItem> get conditions =>
      allItems.where((i) => i.category == DmCategory.conditions).toList();

  static List<DmReferenceItem> standardActions(DmRulesEdition edition) => allItems
      .where((i) =>
          i.tags.contains('standard_action') ||
          (i.id == 'action_potions' && edition == DmRulesEdition.v2014))
      .toList();

  static List<DmReferenceItem> bonusActions(DmRulesEdition edition) => allItems
      .where((i) =>
          i.tags.contains('bonus_action') ||
          (i.id == 'action_potions' && edition == DmRulesEdition.v2024))
      .toList();

  static List<DmReferenceItem> get reactions =>
      allItems.where((i) => i.tags.contains('reaction')).toList();

  static List<DmReferenceItem> get coverRules =>
      allItems.where((i) => i.tags.contains('cover_rule')).toList();

  static const List<DmReferenceItem> allItems = [
    // ==========================================
    // ACTIONS & COMBAT (STANDARD ACTIONS)
    // ==========================================
    DmReferenceItem(
      id: 'action_attack',
      title: 'Attack Action & Extra Attack',
      title2014: 'Attack',
      title2024: 'Attack & Weapon Swapping',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      summary: 'Make one melee or ranged weapon/unarmed attack.',
      tags: ['attack', 'melee', 'ranged', 'extra attack', 'weapon', 'unarmed', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 lets you draw/stow a weapon before or after EACH attack, and Unarmed Strikes now offer Damage, Grapple, or Shove options directly.',
      rules2014: [
        'Make one melee or ranged attack with a weapon, spell attack, or unarmed strike.',
        'Extra Attack (class feature) allows making 2 or more attacks with this action.',
        'You may draw or sheathe only ONE weapon for free as your object interaction on your turn; subsequent swaps cost an action.',
      ],
      rules2024: [
        'Make one attack with a weapon or an Unarmed Strike (which can deal damage, Grapple, or Shove).',
        'Extra Attack allows multiple attacks per Attack action.',
        'Weapon Swapping: You can draw or stow one weapon before or after each attack you make as part of the Attack action.',
        'Equipping/unequipping a shield still costs an entire Action.',
      ],
    ),
    DmReferenceItem(
      id: 'action_cast_spell',
      title: 'Cast a Spell',
      title2014: 'Cast a Spell',
      title2024: 'Cast a Spell (2024 Slot Limit)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      summary: 'Cast a spell with standard casting time and slot restrictions.',
      tags: ['cast a spell', 'spell', 'magic', 'cantrip', 'spell slot', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 limits you to expending only ONE spell slot on your turn (allowing Cantrip + Leveled, but preventing Double Leveled Slots).',
      rules2014: [
        'Cast a spell with a casting time of 1 Action.',
        'Observe V, S, M component rules and concentration limits.',
        'If you cast a Bonus Action spell, you can only cast Cantrips with your Action.',
      ],
      rules2024: [
        'Cast a spell. On your turn, you can expend only ONE spell slot (you may cast multiple spells if only one uses a slot, e.g., slot + cantrip).',
        'Observe V, S, M components and concentration rules.',
      ],
    ),
    DmReferenceItem(
      id: 'action_dash',
      title: 'Dash',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.directions_run,
      color: Colors.cyanAccent,
      summary: 'Gain extra movement equal to your Speed for the current turn.',
      tags: ['dash', 'speed', 'movement', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'Gain extra movement for the current turn equal to your Speed (e.g. 30 ft becomes 60 ft total).',
      ],
      rules2024: [
        'Gain extra movement for the current turn equal to your Speed.',
      ],
    ),
    DmReferenceItem(
      id: 'action_disengage',
      title: 'Disengage',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.transit_enterexit,
      color: Colors.greenAccent,
      summary: 'Movement does not provoke opportunity attacks for the rest of your turn.',
      tags: ['disengage', 'movement', 'opportunity attack', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'Your movement does not provoke opportunity attacks for the rest of the turn.',
      ],
      rules2024: [
        'Your movement does not provoke opportunity attacks for the rest of the turn.',
      ],
    ),
    DmReferenceItem(
      id: 'action_dodge',
      title: 'Dodge',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.shield,
      color: Colors.blueAccent,
      summary: 'Focus entirely on evading incoming attacks and hazard reflex saves.',
      tags: ['dodge', 'defense', 'advantage', 'disadvantage', 'dex save', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'Until your next turn, attacks against you have Disadvantage (if you can see the attacker), and you have Advantage on DEX saves.',
        'Benefits lost if you are Incapacitated or your speed drops to 0.',
      ],
      rules2024: [
        'Until your next turn, attacks against you have Disadvantage (if visible), and you have Advantage on DEX saves.',
        'Benefits end if you have the Incapacitated condition or speed is 0.',
      ],
    ),
    DmReferenceItem(
      id: 'action_help',
      title: 'Help',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.handshake,
      color: Colors.tealAccent,
      summary: 'Give an ally Advantage on an ability check or their next attack roll.',
      tags: ['help', 'assist', 'advantage', 'feint', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 specifies that helping on an ability check requires proficiency in the relevant skill.',
      rules2014: [
        'Give an ally Advantage on their next ability check, or Advantage on their next attack roll against a creature within 5 ft of you.',
      ],
      rules2024: [
        'Give an ally Advantage on their next ability check (if you are proficient), or Advantage on an attack roll against a creature within 5 ft.',
      ],
    ),
    DmReferenceItem(
      id: 'action_hide',
      title: 'Hide Action & Stealth',
      title2014: 'Hide',
      title2024: 'Hide (2024 DC 15)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      summary: 'Conceal yourself from enemies.',
      tags: ['hide', 'stealth', 'invisible', 'passive perception', 'dc 15', 'unseen', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2014 was a contested check against enemy Passive Perception. 2024 sets a standardized DC 15 Dexterity (Stealth) check to immediately gain the Invisible condition!',
      rules2014: [
        'Make a Dexterity (Stealth) check contested by enemies\' Passive Perception (Wisdom).',
        'You cannot hide from a creature that can see you clearly.',
        'Gives you unseen attacker benefits (Advantage on attacks, Disadvantage on attacks against you).',
        'Revealed immediately if you make noise or make an attack.',
      ],
      rules2024: [
        'Take the Hide action: Make a DC 15 Dexterity (Stealth) check while heavily obscured or behind 3/4 or total cover.',
        'On a success, you gain the Invisible condition until you make a sound louder than a whisper, hit/miss an attack, cast a spell with verbal components, or an enemy spots you.',
      ],
    ),
    DmReferenceItem(
      id: 'action_ready',
      title: 'Ready',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action + Reaction',
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      summary: 'Specify a perceivable trigger and an action to execute as a Reaction.',
      tags: ['ready', 'reaction', 'trigger', 'concentration', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'Specify a perceivable trigger and an action (or spell) to execute as a Reaction before your next turn.',
        'Spells require concentration while readied; if trigger does not occur, the spell slot is lost.',
      ],
      rules2024: [
        'Specify a trigger and action. Readied spells require concentration until released as a reaction.',
      ],
    ),
    DmReferenceItem(
      id: 'action_search',
      title: 'Search',
      title2014: 'Search',
      title2024: 'Search (2024 Codified)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.search,
      color: Colors.lightGreenAccent,
      summary: 'Devote attention to finding something or tracking hidden creatures.',
      tags: ['search', 'perception', 'investigation', 'survival', 'insight', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 codifies Search under Wisdom checks (Insight, Perception, Survival) to discern motives or locate concealed creatures/items.',
      rules2014: [
        'Devote attention to finding something. The DM might call for a Wisdom (Perception) or Intelligence (Investigation) check.',
      ],
      rules2024: [
        'Make a Wisdom check (Insight, Perception, Survival) to discern motives or locate concealed creatures/items.',
      ],
    ),
    DmReferenceItem(
      id: 'action_study',
      title: 'Study (2024 New Action)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.menu_book,
      color: Colors.teal,
      summary: 'Deduce monster traits, weaknesses, or historical/arcane lore.',
      tags: ['study', 'arcana', 'history', 'nature', 'religion', 'investigation', 'monster lore', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 introduces a codified Study action using Intelligence checks to deduce monster stats and weaknesses.',
      rules2014: [
        'Handled ad-hoc at DM discretion under knowledge skill checks (Arcana, History, Nature, Religion).',
      ],
      rules2024: [
        'Make an Intelligence check (Arcana, History, Nature, Religion, Investigation) to deduce monster stats, traits, weaknesses, or lore.',
      ],
    ),
    DmReferenceItem(
      id: 'action_influence',
      title: 'Influence (2024 New Action)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.record_voice_over,
      color: Colors.pinkAccent,
      summary: 'Social interaction to adjust NPC attitudes and request favors.',
      tags: ['influence', 'persuasion', 'deception', 'intimidation', 'animal handling', 'social', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 standardizes DCs for social influence: Friendly DC 10, Indifferent DC 15, Hostile DC 20.',
      rules2014: [
        'Handled via DM judgment and social check guidelines in the DMG.',
      ],
      rules2024: [
        'Influence an NPC attitude: Friendly DC 10, Indifferent DC 15, Hostile DC 20 with Persuasion, Deception, Animal Handling, or Intimidation.',
      ],
    ),
    DmReferenceItem(
      id: 'action_use_object',
      title: 'Use an Object',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.touch_app,
      color: Colors.pinkAccent,
      summary: 'Interact with a second object or operate complex mechanical apparatuses.',
      tags: ['use an object', 'interact', 'item', 'mechanism', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'Interact with a second object on your turn, or use a complex item (like applying a potion or pulling a lever).',
      ],
      rules2024: [
        'Interact with a second object or use complex specialized gear.',
      ],
    ),
    DmReferenceItem(
      id: 'action_grapple_shove',
      title: 'Grapple & Shove (Unarmed Strikes)',
      title2014: 'Grapple & Shove (2014 Contested)',
      title2024: 'Grapple & Shove (2024 Save DC)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Attack (Part of Attack Action)',
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      summary: 'Grab or knock down / push a creature.',
      tags: ['grapple', 'shove', 'push', 'prone', 'unarmed strike', 'athletics', 'save dc', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2014 used contested Athletics checks. 2024 makes Grapple/Shove a saving throw (DC = 8 + STR + Prof) against the target\'s STR/DEX save!',
      rules2014: [
        'Contested Check: Attacker rolls Strength (Athletics) contested by target\'s Strength (Athletics) or Dexterity (Acrobatics).',
        'Grapple: On success, target gains Grappled condition (speed = 0). Target must be no more than 1 size larger than you.',
        'Shove: On success, knock target Prone or push it 5 feet away.',
        'Escaping: The grappled creature uses an Action to repeat the contested Athletics/Acrobatics check.',
      ],
      rules2024: [
        'Saving Throw DC: DC = 8 + your Strength modifier + your Proficiency Bonus.',
        'Target makes a Strength or Dexterity saving throw (target\'s choice).',
        'Grapple: Target gains Grappled condition on failed save. Grappled creature has Disadvantage on attacks against anyone other than the grappler.',
        'Shove: Target is pushed 5 feet away or knocked Prone on failed save.',
        'Escaping: Target makes a STR/DEX save at the END of each of its turns against the escape DC (no action required on its turn).',
        'Target must be no more than one size larger than you.',
      ],
    ),
    DmReferenceItem(
      id: 'action_potions',
      title: 'Drinking & Administering Potions',
      title2014: 'Drink / Administer a Potion (2014 RAW)',
      title2024: 'Drink or Administer a Potion (2024)',
      category: DmCategory.actions,
      subCategory: 'Standard / Bonus Action',
      cost: '1 Action (2014) / 1 Bonus Action (2024)',
      cost2014: '1 Action',
      cost2024: '1 Bonus Action',
      icon: Icons.liquor,
      color: Colors.redAccent,
      summary: 'Using healing potions and magical elixirs.',
      tags: ['potion', 'healing', 'bonus action', 'action', 'magic item', 'elixir'],
      isChangedIn2024: true,
      diffSummary: '2014 required a full Action to drink or administer a potion. 2024 makes drinking or administering a potion a Bonus Action!',
      rules2014: [
        'Drinking a potion requires 1 Action (PHB p. 153, DMG p. 139).',
        'Administering a potion to another creature (e.g. an unconscious ally) requires 1 Action.',
      ],
      rules2024: [
        'Drinking a potion takes 1 Bonus Action.',
        'Administering a potion to another creature takes 1 Bonus Action.',
      ],
    ),
    DmReferenceItem(
      id: 'action_death_saves',
      title: 'Death Saving Throws & Stabilizing',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: 'At Start of Turn',
      icon: Icons.favorite_border,
      color: Colors.red,
      summary: 'Dying, death saves, criticals, and stabilization.',
      tags: ['death saves', 'dying', 'unconscious', 'stabilize', 'medicine', 'nat 20', 'nat 1', '0 hp', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: 'In 2024, rolling a Natural 20 on a death save lets you regain 1 HP AND immediately stand up / act without losing your turn.',
      rules2014: [
        'Roll d20 at start of turn at 0 HP. No modifiers apply. DC 10.',
        'Success on 10+, Fail on 9 or lower. 3 successes = Stable. 3 failures = Dead.',
        'Natural 1: Counts as TWO failures.',
        'Natural 20: Regain 1 HP and regain consciousness.',
        'Damage at 0 HP: Causes 1 death save failure (or 2 failures if damage is from a critical hit).',
        'Massive Damage: Damage equal to or exceeding max HP kills instantly.',
        'Stabilize: An ally uses an Action for a DC 10 Wisdom (Medicine) check or expends a Healer\'s Kit use.',
      ],
      rules2024: [
        'Roll d20 at start of turn at 0 HP. DC 10.',
        '3 successes = Stable; 3 failures = Dead.',
        'Natural 1 = 2 failures.',
        'Natural 20 = Regain 1 HP immediately, stand up, and take your turn normally.',
        'Damage at 0 HP = 1 failure (critical hit damage = 2 failures).',
        'Stabilize: Action for DC 10 Wisdom (Medicine) check or Healer\'s Kit. Creature stays stable at 0 HP.',
      ],
    ),

    // ==========================================
    // ACTIONS & COMBAT (BONUS ACTIONS)
    // ==========================================
    DmReferenceItem(
      id: 'action_two_weapon_fighting',
      title: 'Two-Weapon Fighting & Light Property',
      title2014: 'Two-Weapon Fighting (Off-Hand)',
      title2024: 'Two-Weapon Fighting (Light Property)',
      category: DmCategory.actions,
      subCategory: 'Bonus Action',
      cost: '1 Bonus Action',
      cost2024: '1 Bonus Action (or Part of Attack with Nick)',
      icon: Icons.content_cut,
      color: Colors.amber,
      summary: 'Attacking with dual-wielded light weapons.',
      tags: ['dual wield', 'light weapon', 'off-hand', 'bonus action', 'nick mastery', 'two-weapon', 'bonus_action'],
      isChangedIn2024: true,
      diffSummary: '2014 strictly required a Bonus Action for the off-hand attack. 2024 codifies this in the Light weapon property (and weapon masteries like Nick can make it part of the Attack action with no Bonus Action used).',
      rules2014: [
        'When you take the Attack action with a Light melee weapon in one hand, attack with a different Light melee weapon in the other hand (no ability mod to damage unless negative).',
      ],
      rules2024: [
        'When you take the Attack action and attack with a Light weapon, you can make one extra attack with a different Light weapon as a Bonus Action.',
        'With the Nick weapon mastery property, this extra attack is part of the Attack action itself without using a Bonus Action.',
        'Ability modifier is not added to damage unless negative or with Two-Weapon Fighting style.',
      ],
    ),
    DmReferenceItem(
      id: 'action_bonus_action_spells',
      title: 'Bonus Action Spells',
      title2014: 'Bonus Action Spells (2014 Rule)',
      title2024: 'Bonus Action Spells',
      category: DmCategory.actions,
      subCategory: 'Bonus Action',
      cost: '1 Bonus Action',
      icon: Icons.bolt,
      color: Colors.purpleAccent,
      summary: 'Casting swift bonus action spells.',
      tags: ['bonus action spell', 'healing word', 'misty step', 'slot limit', 'bonus_action'],
      isChangedIn2024: true,
      diffSummary: '2014 Bonus Action spell rule limited your Action to Cantrips. 2024 limits you to 1 spell slot per turn.',
      rules2014: [
        'If you cast a Bonus Action spell (e.g. Healing Word, Misty Step), you cannot cast another spell on the same turn except for a Cantrip with a casting time of 1 Action.',
      ],
      rules2024: [
        'Cast a spell with a casting time of 1 Bonus Action. Follows the 1-spell-slot-per-turn limitation.',
      ],
    ),
    DmReferenceItem(
      id: 'action_class_features',
      title: 'Class & Item Features',
      title2014: 'Class & Item Features',
      title2024: 'Class Features',
      category: DmCategory.actions,
      subCategory: 'Bonus Action',
      cost: '1 Bonus Action',
      icon: Icons.star,
      color: Colors.cyanAccent,
      summary: 'Features explicitly designated as Bonus Actions.',
      tags: ['cunning action', 'bardic inspiration', 'rage', 'second wind', 'command minions', 'bonus_action'],
      isChangedIn2024: false,
      rules2014: [
        'Features explicitly designated as Bonus Actions (Cunning Action, Bardic Inspiration, Rage, Second Wind, Command Minions).',
      ],
      rules2024: [
        'Cunning Action, Bardic Inspiration, Second Wind, Rage, and specialized bonus action spells/abilities.',
      ],
    ),

    // ==========================================
    // ACTIONS & COMBAT (REACTIONS)
    // ==========================================
    DmReferenceItem(
      id: 'action_opportunity_attack',
      title: 'Opportunity Attack',
      category: DmCategory.actions,
      subCategory: 'Reaction',
      cost: '1 Reaction',
      icon: Icons.front_hand,
      color: Colors.redAccent,
      summary: 'Melee weapon strike when an enemy leaves your reach without Disengaging.',
      tags: ['opportunity attack', 'reach', 'disengage', 'melee', 'reaction'],
      isChangedIn2024: false,
      rules2014: [
        'When a hostile creature that you can see leaves your reach without Disengaging, make one melee weapon attack against it.',
      ],
      rules2024: [
        'When a hostile creature that you can see leaves your reach without Disengaging, make one melee weapon attack against it.',
      ],
    ),
    DmReferenceItem(
      id: 'action_reaction_spells',
      title: 'Reaction Spells',
      category: DmCategory.actions,
      subCategory: 'Reaction',
      cost: '1 Reaction',
      icon: Icons.security,
      color: Colors.purpleAccent,
      summary: 'Triggered magical defenses like Shield, Absorb Elements, or Counterspell.',
      tags: ['shield', 'absorb elements', 'counterspell', 'feather fall', 'reaction', 'spells'],
      isChangedIn2024: false,
      rules2014: [
        'Triggered by specific circumstances (e.g. Shield triggered by being hit, Absorb Elements by taking elemental damage, Counterspell by seeing a creature cast a spell).',
      ],
      rules2024: [
        'Triggered by specific circumstances (e.g. Shield triggered by being hit, Absorb Elements by taking elemental damage, Counterspell by seeing a creature cast a spell).',
      ],
    ),
    DmReferenceItem(
      id: 'action_readied_action_trigger',
      title: 'Readied Action Trigger',
      category: DmCategory.actions,
      subCategory: 'Reaction',
      cost: '1 Reaction',
      icon: Icons.alarm_on,
      color: Colors.orangeAccent,
      summary: 'Execute your previously Readied action when its designated trigger condition occurs.',
      tags: ['readied trigger', 'trigger', 'reaction'],
      isChangedIn2024: false,
      rules2014: [
        'Execute your previously Readied action when its designated trigger condition occurs.',
      ],
      rules2024: [
        'Execute your previously Readied action when its designated trigger condition occurs.',
      ],
    ),

    // ==========================================
    // CONDITIONS & STATUSES (INDIVIDUAL ITEMS)
    // ==========================================
    DmReferenceItem(
      id: 'cond_blinded',
      title: 'Blinded',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      summary: 'Cannot see and auto-fails checks requiring sight.',
      tags: ['blinded', 'sight', 'advantage', 'disadvantage', 'combat / checks'],
      isChangedIn2024: false,
      rules2014: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
      rules2024: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_charmed',
      title: 'Charmed',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.favorite,
      color: Colors.pinkAccent,
      summary: 'Cannot harm charmer; charmer has social advantage.',
      tags: ['charmed', 'social', 'charmer', 'combat / checks'],
      isChangedIn2024: false,
      rules2014: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
      rules2024: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_deafened',
      title: 'Deafened',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.hearing_disabled,
      color: Colors.tealAccent,
      summary: 'Cannot hear and auto-fails checks requiring hearing.',
      tags: ['deafened', 'hearing', 'auditory', 'combat / checks'],
      isChangedIn2024: false,
      rules2014: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
      rules2024: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_frightened',
      title: 'Frightened',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.sentiment_very_dissatisfied,
      color: Colors.deepOrangeAccent,
      summary: 'Disadvantage while source is in sight; cannot willingly move closer.',
      tags: ['frightened', 'fear', 'disadvantage', 'line of sight', 'combat / checks'],
      isChangedIn2024: false,
      rules2014: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
      rules2024: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is visible.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_grappled',
      title: 'Grappled',
      category: DmCategory.conditions,
      subCategory: 'Movement',
      icon: Icons.sports_mma,
      color: Colors.amber,
      summary: 'Speed is 0 and held in place by opponent.',
      tags: ['grappled', 'speed 0', 'escape', 'disadvantage', 'movement'],
      isChangedIn2024: true,
      diffSummary: '2024 grappled creatures suffer Disadvantage on attacks against anyone other than the grappler, and make saves at the end of each turn.',
      rules2014: [
        'A grappled creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'The condition ends if the grappler is Incapacitated.',
        'The condition also ends if an effect removes the grappled creature from reach (e.g. Thunderwave).',
        'Grappler can move with target at half speed.',
      ],
      rules2024: [
        'Speed becomes 0 and cannot increase.',
        'Attacks: You have Disadvantage on attack rolls against anyone other than the grappler.',
        'Movable: The grappler can drag or carry you at half speed (full speed if you are Tiny or 2+ sizes smaller).',
        'Escape: Make a STR or DEX saving throw at the end of each of your turns against the escape DC.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_incapacitated',
      title: 'Incapacitated',
      category: DmCategory.conditions,
      subCategory: 'Incapacitating',
      icon: Icons.do_not_disturb_on,
      color: Colors.redAccent,
      summary: 'Cannot take actions, bonus actions, or reactions.',
      tags: ['incapacitated', 'actions', 'reactions', 'bonus actions', 'initiative', 'concentration', 'incapacitating'],
      isChangedIn2024: true,
      diffSummary: '2024 explicitly mentions Bonus Actions, gives incoming attacks Advantage, and gives Disadvantage on Initiative rolls!',
      rules2014: [
        'An incapacitated creature can’t take Actions or Reactions.',
        'Concentration on active spells is immediately broken.',
      ],
      rules2024: [
        'You can’t take Actions, Bonus Actions, or Reactions.',
        'Your Concentration is immediately broken.',
        'Attack rolls against you have Advantage.',
        'You have Disadvantage on Initiative rolls.',
        'You cannot speak.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_invisible',
      title: 'Invisible',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.blur_on,
      color: Colors.cyanAccent,
      summary: 'Unseen by ordinary vision, advantage on attacks & initiative.',
      tags: ['invisible', 'advantage', 'disadvantage', 'stealth', 'initiative', 'concealed', 'combat / checks'],
      isChangedIn2024: true,
      diffSummary: '2024 clarifies that Invisible grants Advantage on Initiative rolls, and you are Concealed from standard sight and darkvision.',
      rules2014: [
        'An invisible creature is impossible to see without the aid of magic or a special sense. Heavily obscured for hiding purposes.',
        'Attack rolls against the creature have Disadvantage.',
        'The creature’s attack rolls have Advantage.',
      ],
      rules2024: [
        'Concealed: You aren’t affected by any effect that requires its target to be seen (unless special sight).',
        'Attack rolls against you have Disadvantage; your attack rolls have Advantage.',
        'Initiative: If invisible when rolling Initiative, you have Advantage on the roll.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_paralyzed',
      title: 'Paralyzed',
      category: DmCategory.conditions,
      subCategory: 'Incapacitating',
      icon: Icons.offline_bolt,
      color: Colors.yellowAccent,
      summary: 'Incapacitated, cannot move or speak, auto-fails STR/DEX saves, melee hits are crits.',
      tags: ['paralyzed', 'incapacitated', 'auto-fail', 'critical hit', '5 ft', 'incapacitating'],
      isChangedIn2024: false,
      rules2014: [
        'A paralyzed creature is Incapacitated (can’t take actions or reactions) and can’t move or speak.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet.',
      ],
      rules2024: [
        'Incapacitated, can’t move or speak.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
        'Any attack that hits from within 5 feet is a Critical Hit.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_petrified',
      title: 'Petrified',
      category: DmCategory.conditions,
      subCategory: 'Incapacitating',
      icon: Icons.terrain,
      color: Colors.brown,
      summary: 'Transformed into solid stone (weight ×10), damage resistance, poison immunity.',
      tags: ['petrified', 'stone', 'resistance', 'immune', 'incapacitated', 'incapacitating'],
      isChangedIn2024: false,
      rules2014: [
        'Transformed into a solid inanimate substance (usually stone). Weight increases by a factor of ten, and ceases aging.',
        'The creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'Attack rolls against the creature have Advantage.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'The creature has Resistance to all damage and is Immune to poison and disease.',
      ],
      rules2024: [
        'Transformed into solid stone (weight ×10), ceases aging.',
        'Incapacitated, can’t move or speak, unaware of surroundings.',
        'Attack rolls against have Advantage. Auto-fails STR and DEX saves.',
        'Resistance to all damage; Immune to poison damage and the Poisoned condition.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_poisoned',
      title: 'Poisoned',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.science,
      color: Colors.greenAccent,
      summary: 'Disadvantage on attack rolls and ability checks.',
      tags: ['poisoned', 'toxicity', 'disadvantage', 'combat / checks'],
      isChangedIn2024: false,
      rules2014: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
      rules2024: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_prone',
      title: 'Prone',
      category: DmCategory.conditions,
      subCategory: 'Movement',
      icon: Icons.airline_seat_flat,
      color: Colors.lightGreenAccent,
      summary: 'Lying on ground; crawling costs extra, standing costs half speed.',
      tags: ['prone', 'crawl', 'stand up', 'melee advantage', 'ranged disadvantage', 'movement'],
      isChangedIn2024: false,
      rules2014: [
        'A prone creature’s only movement option is to crawl, unless it stands up and thereby ends the condition.',
        'Standing up costs an amount of movement equal to half the creature’s speed.',
        'The creature has Disadvantage on attack rolls.',
        'An attack roll against the creature has Advantage if the attacker is within 5 feet of the creature. Otherwise, the attack roll has Disadvantage.',
      ],
      rules2024: [
        'Only movement options are crawling (costs extra movement) or standing up (costs half Speed).',
        'Disadvantage on attack rolls.',
        'Attack rolls from within 5 feet have Advantage; other attack rolls have Disadvantage.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_restrained',
      title: 'Restrained',
      category: DmCategory.conditions,
      subCategory: 'Movement',
      icon: Icons.lock,
      color: Colors.orangeAccent,
      summary: 'Speed is 0, attacks against have advantage, disadvantage on DEX saves.',
      tags: ['restrained', 'speed 0', 'dex save', 'disadvantage', 'movement'],
      isChangedIn2024: false,
      rules2014: [
        'A restrained creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'Attack rolls against the creature have Advantage, and the creature’s attack rolls have Disadvantage.',
        'The creature has Disadvantage on Dexterity saving throws.',
      ],
      rules2024: [
        'Speed becomes 0 and cannot increase.',
        'Attack rolls against have Advantage, and creature’s attack rolls have Disadvantage.',
        'Disadvantage on Dexterity saving throws.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_stunned',
      title: 'Stunned',
      category: DmCategory.conditions,
      subCategory: 'Incapacitating',
      icon: Icons.flash_on,
      color: Colors.purpleAccent,
      summary: 'Incapacitated, faltering speech, auto-fails STR/DEX saves, attacks have advantage.',
      tags: ['stunned', 'incapacitated', 'auto-fail', 'incapacitating'],
      isChangedIn2024: false,
      rules2014: [
        'A stunned creature is Incapacitated, can’t move, and can speak only falteringly.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
      ],
      rules2024: [
        'Incapacitated, can’t move, can speak only falteringly.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_unconscious',
      title: 'Unconscious',
      category: DmCategory.conditions,
      subCategory: 'Incapacitating',
      icon: Icons.bedtime,
      color: Colors.indigoAccent,
      summary: 'Knocked out, asleep, or reduced to 0 HP; hits within 5 ft are criticals.',
      tags: ['unconscious', 'asleep', 'incapacitated', 'critical hit', '0 hp', 'prone', 'incapacitating'],
      isChangedIn2024: true,
      diffSummary: '2024 clarifies that unconscious creatures roll Initiative with Disadvantage if asleep when combat starts.',
      rules2014: [
        'An unconscious creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'The creature drops whatever it’s holding and falls Prone.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet of the creature.',
      ],
      rules2024: [
        'Incapacitated, drops held items, falls Prone, unaware of surroundings.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage; hits from within 5 feet are Critical Hits.',
        'If asleep when combat begins, rolls Initiative with Disadvantage.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_exhaustion',
      title: 'Exhaustion (Fatigue)',
      category: DmCategory.conditions,
      subCategory: 'Exhaustion',
      icon: Icons.battery_alert,
      color: Colors.red,
      summary: 'Severe physical fatigue and magical drain.',
      tags: ['exhaustion', 'levels', 'death', 'speed', 'd20 test', 'penalty', 'long rest', 'fatigue'],
      isChangedIn2024: true,
      diffSummary: 'MASSIVE CHANGE: 2014 had 6 rigid tiers (disadvantage, half speed, death). 2024 uses 10 levels with a uniform -2 penalty to D20 tests and -5 ft speed reduction per level!',
      rules2014: [
        'Level 1: Disadvantage on ability checks.',
        'Level 2: Speed halved.',
        'Level 3: Disadvantage on attack rolls and saving throws.',
        'Level 4: Hit point maximum halved.',
        'Level 5: Speed reduced to 0.',
        'Level 6: Death.',
        'Finishing a Long Rest with food & water reduces exhaustion level by 1.',
      ],
      rules2024: [
        'Cumulative penalty across 10 total levels.',
        'D20 Tests: Subtract 2 × your exhaustion level from all D20 Tests (attack rolls, ability checks, saving throws) and your spell save DC.',
        'Speed: Reduce speed by 5 feet × your exhaustion level.',
        'Level 10: Death.',
        'Finishing a Long Rest with food and water removes 1 level of exhaustion.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_surprise',
      title: 'Surprise / Surprised',
      category: DmCategory.conditions,
      subCategory: 'Combat / Checks',
      icon: Icons.priority_high,
      color: Colors.deepPurpleAccent,
      summary: 'Caught off-guard at the start of combat.',
      tags: ['surprise', 'surprised', 'initiative', 'disadvantage', 'ambush', 'round 1', 'combat / checks'],
      isChangedIn2024: true,
      diffSummary: '2014: Skipped whole turn on round 1. 2024: No "surprised condition" — surprised creatures simply roll Initiative with Disadvantage!',
      rules2014: [
        'If surprised: You cannot move or take an Action on your first turn of combat.',
        'You cannot take a Reaction until that first turn ends.',
      ],
      rules2024: [
        'No "Surprised" condition exists in 2024.',
        'If surprised when Initiative is rolled, you have Disadvantage on your Initiative roll.',
        'You can act normally on your first turn.',
      ],
    ),

    // ==========================================
    // ENVIRONMENT & HAZARDS / COVER
    // ==========================================
    DmReferenceItem(
      id: 'env_cover',
      title: 'Cover Rules (+2, +5, Total)',
      category: DmCategory.environment,
      subCategory: 'Cover',
      icon: Icons.shield,
      color: Colors.tealAccent,
      summary: 'AC and Dexterity saving throw modifiers from physical obstacles.',
      tags: ['cover', 'half cover', 'three-quarters', 'total cover', 'ac bonus', 'dex save', 'cover_rule'],
      isChangedIn2024: false,
      diffSummary: 'Cover bonuses (+2, +5, Total) remain identical in 2014 and 2024.',
      rules2014: [
        'Half Cover: +2 bonus to AC and Dexterity saving throws (e.g. low wall, large furniture, another creature).',
        'Three-Quarters Cover: +5 bonus to AC and Dexterity saving throws (e.g. portcullis, arrow slit, tree trunk).',
        'Total Cover: Target cannot be targeted directly by attacks or targeted spells (AoE may still affect area if path is clear).',
      ],
      rules2024: [
        'Half Cover: +2 bonus to AC and Dexterity saving throws.',
        'Three-Quarters Cover: +5 bonus to AC and Dexterity saving throws.',
        'Total Cover: Can\'t be targeted directly by an attack or a spell.',
      ],
    ),
    DmReferenceItem(
      id: 'env_cover_half',
      title: 'Half Cover (+2 AC / +2 DEX Saves)',
      category: DmCategory.environment,
      subCategory: 'Cover',
      cost: 'Environmental',
      icon: Icons.table_restaurant,
      color: Colors.lightGreenAccent,
      summary: 'Target has half cover if an obstacle blocks at least half of its body.',
      tags: ['half cover', 'ac +2', 'dex save +2', 'obstacle', 'cover_rule'],
      isChangedIn2024: false,
      rules2014: [
        'A target has half cover if an obstacle blocks at least half of its body (e.g. low wall, large furniture, another creature).',
      ],
      rules2024: [
        'A target has half cover if an obstacle blocks at least half of its body (e.g. low wall, large furniture, another creature).',
      ],
    ),
    DmReferenceItem(
      id: 'env_cover_three_quarters',
      title: 'Three-Quarters Cover (+5 AC / +5 DEX Saves)',
      category: DmCategory.environment,
      subCategory: 'Cover',
      cost: 'Environmental',
      icon: Icons.fence,
      color: Colors.amber,
      summary: 'Target has three-quarters cover if about three-quarters of its body is covered.',
      tags: ['three-quarters cover', 'ac +5', 'dex save +5', 'portcullis', 'arrow slit', 'cover_rule'],
      isChangedIn2024: false,
      rules2014: [
        'A target has three-quarters cover if about three-quarters of its body is covered (e.g. portcullis, arrow slit, thick tree trunk).',
      ],
      rules2024: [
        'A target has three-quarters cover if about three-quarters of its body is covered (e.g. portcullis, arrow slit, thick tree trunk).',
      ],
    ),
    DmReferenceItem(
      id: 'env_cover_total',
      title: 'Total Cover (Untargetable)',
      category: DmCategory.environment,
      subCategory: 'Cover',
      cost: 'Environmental',
      icon: Icons.door_front_door,
      color: Colors.redAccent,
      summary: 'Target completely concealed by obstacle; cannot be targeted directly.',
      tags: ['total cover', 'untargetable', 'barrier', 'cover_rule'],
      isChangedIn2024: false,
      rules2014: [
        'A target with total cover cannot be targeted directly by an attack or spell, though some spells can reach it within an area of effect.',
      ],
      rules2024: [
        'A target with total cover cannot be targeted directly by an attack or spell, though some spells can reach it within an area of effect.',
      ],
    ),
    DmReferenceItem(
      id: 'env_falling',
      title: 'Falling Damage & Falling on Creatures',
      category: DmCategory.environment,
      icon: Icons.south,
      color: Colors.deepOrange,
      summary: 'Impact bludgeoning damage and landing on other creatures.',
      tags: ['falling', 'bludgeoning', '1d6 per 10ft', 'max 20d6', 'landing on creature', 'hazard'],
      isChangedIn2024: true,
      diffSummary: '2024 standardizes falling onto another creature: DC 15 Dex save, damage is split evenly between both creatures on fail!',
      rules2014: [
        '1d6 bludgeoning damage for every 10 feet fallen (max 20d6).',
        'Lands Prone unless damage is completely prevented.',
        'Landing on another creature was an optional rule in 5e rulebooks (DC 15 Dex save to divide damage).',
      ],
      rules2024: [
        '1d6 bludgeoning damage per 10 feet fallen (max 20d6). Lands Prone unless damage is negated.',
        'Falling on a Creature: If a creature falls into the space of another creature that is no more than one size smaller, the target must make a DC 15 Dexterity save.',
        'On a failed save, the falling damage is split evenly between the two creatures, and both land Prone.',
      ],
    ),
    DmReferenceItem(
      id: 'env_vision_lighting',
      title: 'Vision, Lighting & Obscurement',
      category: DmCategory.environment,
      icon: Icons.lightbulb_outline,
      color: Colors.amber,
      summary: 'Bright, Dim Light, Darkness, Darkvision, Blindsight, and Truesight.',
      tags: ['vision', 'light', 'dim light', 'darkness', 'darkvision', 'blindsight', 'truesight', 'perception'],
      isChangedIn2024: false,
      diffSummary: 'Lighting categories and sight rules remain consistent.',
      rules2014: [
        'Bright Light: Normal vision.',
        'Dim Light: Lightly obscured. Disadvantage on Wisdom (Perception) checks relying on sight.',
        'Darkness: Heavily obscured. Blinded status for creatures without darkvision/special senses.',
        'Darkvision: See in Dim Light within range as Bright Light, and Darkness as Dim Light (grayscale only).',
        'Blindsight: Perceive surroundings without relying on sight within specified radius.',
        'Truesight: See in normal and magical darkness, perceive invisible creatures, illusions, and shapechangers.',
      ],
      rules2024: [
        'Bright Light: Clear visibility.',
        'Dim Light: Lightly Obscured. Disadvantage on Perception checks relying on sight.',
        'Darkness: Heavily Obscured. Creatures without special senses have the Blinded condition.',
        'Darkvision: Treats Darkness within radius as Dim Light, Dim Light as Bright Light.',
        'Blindsight & Truesight: Function identically to 2014 definitions.',
      ],
    ),
    DmReferenceItem(
      id: 'env_suffocation',
      title: 'Suffocation & Holding Breath',
      category: DmCategory.environment,
      icon: Icons.air,
      color: Colors.cyan,
      summary: 'Underwater, vacuum, or choked air duration.',
      tags: ['suffocation', 'breath', 'con modifier', 'choking', '0 hp', 'drowning'],
      isChangedIn2024: false,
      diffSummary: 'Holding breath duration and drowning countdown remain identical.',
      rules2014: [
        'Holding Breath: 1 + Constitution modifier minutes (minimum 30 seconds).',
        'Running Out of Breath: Survive for Constitution modifier rounds (minimum 1 round). At the start of its next turn, drops to 0 HP and is dying.',
      ],
      rules2024: [
        'Holding Breath: 1 + Constitution modifier minutes (minimum 30 seconds).',
        'Suffocating: Survives for Constitution modifier rounds (minimum 1 round). After that, drops to 0 HP and begins making death saves.',
      ],
    ),

    // ==========================================
    // EXPLORATION & DCS
    // ==========================================
    DmReferenceItem(
      id: 'exp_dc_scale',
      title: 'Difficulty Class (DC) Benchmarks',
      category: DmCategory.exploration,
      icon: Icons.speed,
      color: Colors.lightGreenAccent,
      summary: 'Standard task difficulty ratings from Very Easy to Impossible.',
      tags: ['dc', 'difficulty', 'checks', 'very easy', 'easy', 'medium', 'hard', 'very hard', 'nearly impossible'],
      isChangedIn2024: false,
      diffSummary: 'Standard DC scale (5, 10, 15, 20, 25, 30) is the foundational benchmark for all 5e editions.',
      rules2014: [
        'DC 5: Very Easy (e.g. noticing a loud noise, climbing a knotted rope).',
        'DC 10: Easy (e.g. hearing an approaching guard, climbing a rough wall).',
        'DC 15: Medium (e.g. picking a standard lock, spotting a concealed door).',
        'DC 20: Hard (e.g. tracking across solid rock, swimming through a stormy sea).',
        'DC 25: Very Hard (e.g. deciphering ancient cyphers, leaping across a 30-foot chasm).',
        'DC 30: Nearly Impossible (e.g. tracking an invisible flyer, surviving a lethal volcano dive).',
      ],
      rules2024: [
        'DC 5: Very Easy.',
        'DC 10: Easy.',
        'DC 15: Medium (standard adventuring challenge).',
        'DC 20: Hard.',
        'DC 25: Very Hard.',
        'DC 30: Nearly Impossible.',
      ],
    ),
    DmReferenceItem(
      id: 'exp_travel_pace',
      title: 'Travel Pace & Exploration Speed',
      category: DmCategory.exploration,
      icon: Icons.directions_walk,
      color: Colors.orangeAccent,
      summary: 'Overland travel speed, stealth capability, and passive perception penalties.',
      tags: ['travel', 'pace', 'fast', 'normal', 'slow', 'overland', 'miles per day', 'stealth'],
      isChangedIn2024: false,
      diffSummary: 'Travel rates (30, 24, 18 miles/day) and stealth penalties match in both editions.',
      rules2014: [
        'Fast Pace: 400 ft/min • 4 mph • 30 miles/day. Penalty: -5 to Passive Perception.',
        'Normal Pace: 300 ft/min • 3 mph • 24 miles/day. Standard tracking and perception.',
        'Slow Pace: 200 ft/min • 2 mph • 18 miles/day. Advantage: Party can move stealthily and use Stealth checks.',
        'Difficult Terrain: Halves travel speed.',
      ],
      rules2024: [
        'Fast Pace: 4 mph (30 miles/day). -5 penalty to Passive Perception.',
        'Normal Pace: 3 mph (24 miles/day).',
        'Slow Pace: 2 mph (18 miles/day). Able to use Stealth while traveling.',
        'Difficult Terrain: Halves travel pace.',
      ],
    ),
    DmReferenceItem(
      id: 'exp_social_influence',
      title: 'Social Interaction & NPC Attitudes',
      category: DmCategory.exploration,
      icon: Icons.record_voice_over,
      color: Colors.pinkAccent,
      summary: 'Friendly, Indifferent, and Hostile DC resolution.',
      tags: ['social', 'attitude', 'friendly', 'indifferent', 'hostile', 'persuasion', 'deception', 'intimidation'],
      isChangedIn2024: true,
      diffSummary: '2024 codifies exact DC thresholds for the Influence action: Friendly DC 10, Indifferent DC 15, Hostile DC 20.',
      rules2014: [
        'Friendly: Wants to help (DC 0 to accept minor risk, DC 10 for significant risk, DC 20 for sacrifice).',
        'Indifferent: Might help if profitable/fair (DC 0 for no cost, DC 10 for minor help, DC 20 for significant effort).',
        'Hostile: Opposes party (DC 10 for no immediate harm, DC 20 for minor concession).',
      ],
      rules2024: [
        'Influence Action standardized DCs:',
        '• Friendly NPC: DC 10 Charisma (Persuasion/Deception) or Strength (Intimidation) check.',
        '• Indifferent NPC: DC 15 check.',
        '• Hostile NPC: DC 20 check.',
        'Success grants the requested favor or changes the NPC\'s immediate stance.',
      ],
    ),

    // ==========================================
    // MAGIC & RESTING
    // ==========================================
    DmReferenceItem(
      id: 'magic_concentration',
      title: 'Concentration Rules & Damage Checks',
      category: DmCategory.magicAndResting,
      icon: Icons.psychology,
      color: Colors.purpleAccent,
      summary: 'Maintaining active spells, saving throws, and simultaneous spell rules.',
      tags: ['concentration', 'save', 'con save', 'damage', 'dc 10', 'incapacitated', 'spellcasting'],
      isChangedIn2024: false,
      diffSummary: 'DC formula (max of 10 or half damage) is identical in both editions.',
      rules2014: [
        'You can only concentrate on ONE spell at a time.',
        'Taking Damage: Make a Constitution saving throw. DC = max(10, floor(damage taken / 2)). Separate check per damage instance.',
        'Incapacitated or Killed: Concentration ends instantly.',
        'Environmental Distraction: DM may call for a DC 10 Con save (e.g. wave crashing over deck).',
      ],
      rules2024: [
        'Concentrate on 1 spell at a time.',
        'Taking Damage: Con saving throw. DC = max(10, floor(damage taken / 2)). Separate roll for each damage source.',
        'Incapacitated condition or Death immediately ends Concentration.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_spell_limits',
      title: 'Multiple Spells on a Turn (Bonus Action Spells)',
      category: DmCategory.magicAndResting,
      icon: Icons.bolt,
      color: Colors.deepPurpleAccent,
      summary: 'Restrictions on casting more than one leveled spell per turn.',
      tags: ['bonus action spell', 'cantrip', 'leveled spell', 'action surge', 'reaction', 'slot limit'],
      isChangedIn2024: true,
      diffSummary: '2014 Bonus Action spell rule strictly limited your Action to Cantrips. 2024 limits you to expending only ONE spell slot on your turn (allowing Cantrip + Leveled, but preventing Double Leveled Slots).',
      rules2014: [
        'If you cast a spell with a casting time of 1 Bonus Action (e.g. Healing Word, Misty Step):',
        'You CANNOT cast another spell on the same turn, EXCEPT for a Cantrip with a casting time of 1 Action.',
        'Action Surge allows two Action spells if neither was a Bonus Action spell.',
      ],
      rules2024: [
        'Spell Slot Limitation: On a single turn, you can expend only ONE spell slot to cast a spell.',
        'You can freely cast a Leveled Spell using a slot AND any number of Cantrips (e.g., Leveled Bonus Action + Action Cantrip, or Action Leveled + Cantrip).',
        'Prevents burning two spell slots via Action Surge on the same turn.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_resting',
      title: 'Short Rest & Long Rest Rules',
      category: DmCategory.magicAndResting,
      icon: Icons.bed,
      color: Colors.indigoAccent,
      summary: 'Hit Dice recovery, HP restoration, and interruption rules.',
      tags: ['short rest', 'long rest', 'hit dice', 'recovery', 'exhaustion', 'interruption'],
      isChangedIn2024: false,
      diffSummary: 'Short Rest (1 hr) and Long Rest (8 hrs, regain all HP, half Hit Dice, 1 Exhaustion level) are consistent.',
      rules2014: [
        'Short Rest (At least 1 hour): Spend 1 or more Hit Dice. Roll Hit Die + Con mod per die to regain HP.',
        'Long Rest (At least 8 hours, 1 per 24 hrs): Regain ALL missing HP. Regain spent Hit Dice up to half total number (min 1). Reduces Exhaustion level by 1 (if food & water consumed).',
        'Interruption: 1+ hour of walking, fighting, or spellcasting aborts the rest.',
      ],
      rules2024: [
        'Short Rest (1 hour): Spend Hit Dice to heal (Hit Die + Con mod).',
        'Long Rest (8 hours, max 1 per 24h): Regain all HP, half total Hit Dice (min 1), remove 1 Exhaustion level.',
        'Interrupted if combat or strenuous activity exceeds 1 hour.',
      ],
    ),

    // ==========================================
    // QUICK REFERENCE TABLES
    // ==========================================
    DmReferenceItem(
      id: 'table_improvised_damage',
      title: 'Improvised Damage Table',
      category: DmCategory.tables,
      icon: Icons.local_fire_department,
      color: Colors.deepOrangeAccent,
      summary: 'DM reference for environmental and trap damage on the fly.',
      tags: ['improvised damage', 'traps', 'fire', 'lava', 'lightning', 'acid', 'fall'],
      isChangedIn2024: false,
      rules2014: [
        '1d10: Burned by coals, hit by falling bookcase, stepped in bear trap.',
        '2d10: Struck by lightning, crushed by collapsing tunnel wall.',
        '4d10: Hit by falling ceiling slab, tumbling through rocky gorge.',
        '10d10: Crushed by rolling boulder, submerged in acid vat.',
        '18d10: Hit by flying meteor, wading through molten lava.',
        '24d10: Submerged in lake of molten lava, crushed by ancient collapsing temple.',
      ],
      rules2024: [
        '1d10: Minor environmental hazard (coals, falling debris).',
        '2d10: Dangerous trap / lightning strike.',
        '4d10: Severe catastrophe (cave collapse, stone slab).',
        '10d10: Deadly hazard (acid pool, rolling boulder).',
        '18d10: Molten lava wading / meteor impact.',
        '24d10: Submerged in core of volcano / planar destruction.',
      ],
    ),
    DmReferenceItem(
      id: 'table_object_ac_hp',
      title: 'Object Armor Class & Hit Points',
      category: DmCategory.tables,
      icon: Icons.crop_square,
      color: Colors.brown,
      summary: 'AC and HP for doors, chests, barriers, and inanimate structures.',
      tags: ['object ac', 'object hp', 'wood', 'stone', 'iron', 'fragile', 'resilient'],
      isChangedIn2024: false,
      rules2014: [
        'Object AC: Cloth/Paper (11) • Glass/Crystal (13) • Wood/Bone (15) • Stone (17) • Iron/Steel (19) • Mithral (21) • Adamantine (23).',
        'Tiny Object (Bottle, lock): Fragile 2 (1d4) • Resilient 5 (2d4).',
        'Small Object (Chest, lute): Fragile 3 (1d6) • Resilient 10 (3d6).',
        'Medium Object (Door, barrel): Fragile 4 (1d8) • Resilient 18 (4d8).',
        'Large Object (Cart, 10ft wall section): Fragile 5 (1d10) • Resilient 27 (5d10).',
        'Immunity: Poison and Psychic damage.',
      ],
      rules2024: [
        'Object AC: Cloth (11), Glass (13), Wood (15), Stone (17), Iron/Steel (19), Adamantine (23).',
        'Tiny HP: Fragile 2 / Resilient 5.',
        'Small HP: Fragile 3 / Resilient 10.',
        'Medium HP: Fragile 4 / Resilient 18.',
        'Large HP: Fragile 5 / Resilient 27.',
        'Immune to Poison and Psychic damage.',
      ],
    ),
  ];
}
