import 'package:flutter/material.dart';

enum DmRulesEdition {
  v2014,
  v2024,
  comparative;

  String get label => switch (this) {
        DmRulesEdition.v2014 => '2014',
        DmRulesEdition.v2024 => '2024',
        DmRulesEdition.comparative => 'Diff',
      };
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

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        DmCategory.actions => const Color(0xFFB45309),
        DmCategory.conditions => const Color(0xFF0E7490),
        DmCategory.environment => const Color(0xFF15803D),
        DmCategory.exploration => const Color(0xFFC2410C),
        DmCategory.magicAndResting => const Color(0xFF7E22CE),
        DmCategory.tables => const Color(0xFFBE185D),
      };
    }
    return color;
  }
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
  final String? interactiveTool;
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
    this.interactiveTool,
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

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      if (color == Colors.amber) return const Color(0xFFB45309);
      if (color == Colors.cyanAccent) return const Color(0xFF0E7490);
      if (color == Colors.lightGreenAccent) return const Color(0xFF15803D);
      if (color == Colors.orangeAccent) return const Color(0xFFC2410C);
      if (color == Colors.purpleAccent) return const Color(0xFF7E22CE);
      if (color == Colors.pinkAccent) return const Color(0xFFBE185D);
      return category.getLegibleColor(isDarkMode);
    }
    return color;
  }

  static final Map<String, String> _corpusCache = {};

  String _getCorpus() {
    final cached = _corpusCache[id];
    if (cached != null) return cached;
    final buffer = StringBuffer()
      ..write('$id ')
      ..write('$title ')
      ..write('${title2014 ?? ""} ')
      ..write('${title2024 ?? ""} ')
      ..write('$summary ')
      ..write('${category.name} ')
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

  /// Multi-field tokenized search with operator parsing (e.g. tag:action, edition:diff, category:combat)
  bool matches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return true;

    final tokens = trimmed.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final corpus = _getCorpus();

    for (final token in tokens) {
      if (token.startsWith('tag:')) {
        final tagQuery = token.substring(4);
        if (!tags.any((t) => t.toLowerCase().contains(tagQuery))) {
          return false;
        }
      } else if (token.startsWith('category:')) {
        final catQuery = token.substring(9);
        final matchesCat = category.name.toLowerCase().contains(catQuery) ||
            category.label.toLowerCase().contains(catQuery);
        if (!matchesCat) return false;
      } else if (token.startsWith('edition:')) {
        final edQuery = token.substring(8);
        if (edQuery == 'diff' || edQuery == 'changed') {
          if (!isChangedIn2024) return false;
        } else if (edQuery == '2024') {
          // Valid in 2024
        } else if (edQuery == '2014') {
          // Valid in 2014
        }
      } else if (token.startsWith('cost:')) {
        final costQuery = token.substring(5);
        final c = (cost ?? cost2024 ?? cost2014 ?? '').toLowerCase();
        if (!c.contains(costQuery)) return false;
      } else {
        if (!corpus.contains(token)) {
          return false;
        }
      }
    }
    return true;
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
      tags: ['attack', 'melee', 'ranged', 'extra attack', 'weapon', 'unarmed', 'standard_action', 'combat'],
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
      title: 'Cast a Spell / Magic Action',
      title2014: 'Cast a Spell',
      title2024: 'Magic Action (2024 Slot Limit)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      summary: 'Cast a spell or activate a magic item with slot restrictions.',
      tags: ['cast a spell', 'magic action', 'spell', 'magic', 'cantrip', 'spell slot', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 codifies this as the "Magic Action" and limits you to expending only ONE spell slot on your turn (allowing Cantrip + Leveled, but preventing Double Leveled Slots).',
      rules2014: [
        'Cast a spell with a casting time of 1 Action.',
        'Observe V, S, M component rules and concentration limits.',
        'If you cast a Bonus Action spell, you can only cast Cantrips with your Action.',
      ],
      rules2024: [
        'Magic Action: Cast a spell or activate a magical item/feature.',
        'Spell Slot Limitation: On your turn, you can expend only ONE spell slot (you may cast multiple spells if only one uses a slot, e.g., slot + cantrip).',
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
      title: 'Use an Object / Utilize',
      title2014: 'Use an Object',
      title2024: 'Utilize (2024)',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.touch_app,
      color: Colors.pinkAccent,
      summary: 'Interact with a second object or operate complex mechanical apparatuses.',
      tags: ['use an object', 'utilize', 'interact', 'item', 'mechanism', 'standard_action'],
      isChangedIn2024: true,
      diffSummary: '2024 renames Use an Object to Utilize and standardizes equipping/using non-magic gear and apparatuses.',
      rules2014: [
        'Interact with a second object on your turn, or use a complex item (like applying a potion or pulling a lever).',
      ],
      rules2024: [
        'Utilize action: Interact with a second object, use specialized non-magic adventuring gear, or operate complex devices.',
      ],
    ),
    DmReferenceItem(
      id: 'action_improvise',
      title: 'Improvising an Action',
      category: DmCategory.actions,
      subCategory: 'Standard Action',
      cost: '1 Action',
      icon: Icons.lightbulb_outline,
      color: Colors.amber,
      summary: 'Perform unlisted stunts, tricks, or environmental maneuvers.',
      tags: ['improvise', 'stunt', 'dm ruling', 'action', 'standard_action'],
      isChangedIn2024: false,
      rules2014: [
        'When you describe an action not detailed elsewhere in the rules, the DM tells you whether that action is possible and what kind of roll you need to make (if any).',
      ],
      rules2024: [
        'Perform unique maneuvers not covered by standard actions. DM assigns appropriate ability check and DC.',
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
      tags: ['grapple', 'shove', 'push', 'prone', 'unarmed strike', 'athletics', 'save dc', 'standard_action', 'calculator'],
      isChangedIn2024: true,
      interactiveTool: 'grapple_shove',
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
      id: 'action_damage_rolls_crit',
      title: 'Attack Rolls, Advantage & Critical Hits',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Per Attack',
      icon: Icons.gps_fixed,
      color: Colors.redAccent,
      summary: 'd20 + modifier + PB vs AC, natural 20 critical hits, natural 1 automatic miss.',
      tags: ['attack roll', 'ac', 'advantage', 'disadvantage', 'critical hit', 'nat 20', 'nat 1', 'fumble', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'Attack Roll: 1d20 + Ability Modifier + Proficiency Bonus (if proficient) vs target AC.',
        'Natural 20: Always hits regardless of AC, and rolls all damage dice TWICE.',
        'Natural 1: Always misses regardless of modifiers.',
        'Advantage/Disadvantage: Multiple instances do not stack; 1 advantage and 1 disadvantage cancel each other out completely.',
      ],
      rules2024: [
        'Attack Roll: 1d20 + Mod + PB vs AC.',
        'Natural 20 (Critical Hit): Automatic hit, roll damage dice twice.',
        'Natural 1: Automatic miss.',
        'Advantage/Disadvantage cancel completely regardless of quantity.',
      ],
    ),
    DmReferenceItem(
      id: 'action_damage_types',
      title: 'Damage Types, Resistance & Vulnerability',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Damage Resolution',
      icon: Icons.whatshot,
      color: Colors.orangeAccent,
      summary: 'Acid, Bludgeoning, Cold, Fire, Force, Lightning, Necrotic, Piercing, Poison, Psychic, Radiant, Slashing, Thunder.',
      tags: ['damage types', 'resistance', 'vulnerability', 'immunity', 'acid', 'fire', 'force', 'radiant', 'necrotic', 'psychic'],
      isChangedIn2024: false,
      rules2014: [
        'Resistance: Reduces damage of that type by HALF (round down).',
        'Vulnerability: DOUBLES damage of that type.',
        'Immunity: Creature takes 0 damage from that type.',
        'Order of Application: Flat modifiers applied FIRST, then Resistance, then Vulnerability.',
      ],
      rules2024: [
        'Resistance halves damage.',
        'Vulnerability doubles damage.',
        'Immunity prevents all damage.',
        'Order: Add/subtract modifiers -> Resistance -> Vulnerability.',
      ],
    ),
    DmReferenceItem(
      id: 'action_unseen_attackers',
      title: 'Unseen Attackers & Targets',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Continuous',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      summary: 'Advantage on attacks when unseen; disadvantage against unseen targets.',
      tags: ['unseen', 'hidden', 'invisible', 'advantage', 'disadvantage', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'When you make an attack against a target you can\'t see, you have Disadvantage on the attack roll.',
        'When a creature can\'t see you, you have Advantage on attack rolls against it.',
        'If you are hidden, making an attack reveals your location whether you hit or miss.',
      ],
      rules2024: [
        'Attacking unseen targets gives Disadvantage.',
        'Attacking while unseen gives Advantage.',
        'Making an attack ends stealth/hidden location.',
      ],
    ),
    DmReferenceItem(
      id: 'action_ranged_in_melee',
      title: 'Ranged Attacks in Close Combat',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Within 5 ft',
      icon: Icons.crisis_alert,
      color: Colors.deepOrange,
      summary: 'Disadvantage on ranged attack rolls when a hostile creature is within 5 ft.',
      tags: ['ranged', 'melee range', '5 ft', 'disadvantage', 'bow', 'spell attack', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'When you make a ranged attack with a weapon, a spell, or another means, you have Disadvantage on the attack roll if you are within 5 feet of a hostile creature who can see you and isn\'t Incapacitated.',
      ],
      rules2024: [
        'Ranged attacks suffer Disadvantage if an active hostile creature is within 5 ft of you.',
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
    DmReferenceItem(
      id: 'action_nonlethal_knockout',
      title: 'Knocking a Creature Out (Nonlethal Damage)',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Upon Dropping to 0 HP',
      icon: Icons.bedtime_outlined,
      color: Colors.indigoAccent,
      summary: 'Declare nonlethal damage with melee attacks to knock unconscious instead of killing.',
      tags: ['knockout', 'nonlethal', 'unconscious', 'stable', '0 hp', 'melee'],
      isChangedIn2024: false,
      rules2014: [
        'When an attacker reduces a creature to 0 HP with a MELEE attack, the attacker can choose to knock the creature out.',
        'The decision is made at the instant damage is dealt.',
        'The creature falls Unconscious and is immediately Stable (does not make death saves).',
      ],
      rules2024: [
        'When reducing a creature to 0 HP with a melee attack, choose to knock unconscious (Stable at 0 HP) instead of killing.',
      ],
    ),
    DmReferenceItem(
      id: 'action_temporary_hp',
      title: 'Temporary Hit Points (THP Rules)',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Continuous',
      icon: Icons.shield_outlined,
      color: Colors.cyanAccent,
      summary: 'Buffer HP that absorbs damage; do not stack, cannot be healed.',
      tags: ['temporary hp', 'thp', 'buffer', 'healing', 'stacking', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'Temporary HP are not actual HP; they are a separate buffer against damage.',
        'Do Not Stack: If you gain temporary HP while already having some, choose whether to keep your current amount or replace with the new amount.',
        'Cannot be Healed: Healing spells and potions do not restore temporary HP.',
        'Dropping to 0 HP removes all temporary HP.',
      ],
      rules2024: [
        'Temporary HP absorbs incoming damage first.',
        'Never stacks; choose highest value.',
        'Cannot be restored by healing.',
      ],
    ),
    DmReferenceItem(
      id: 'action_movement_combat',
      title: 'Movement in Combat, Difficult Terrain & Squeezing',
      category: DmCategory.actions,
      subCategory: 'Movement Rule',
      cost: 'During Your Turn',
      icon: Icons.alt_route,
      color: Colors.tealAccent,
      summary: 'Splitting movement, double cost terrain, and squeezing through small openings.',
      tags: ['movement', 'difficult terrain', 'squeezing', 'half speed', 'climbing', 'swimming'],
      isChangedIn2024: false,
      rules2014: [
        'Breaking Up Move: You can split your movement before, between, and after attacks.',
        'Difficult Terrain: Moving 1 foot costs 2 feet of movement (+1 extra foot per foot moved).',
        'Climbing & Swimming: Costs 1 extra foot per foot moved unless you have climb/swim speed.',
        'Crawling: Costs 1 extra foot per foot moved.',
        'Squeezing: A creature can squeeze through a space one size smaller. While squeezing: costs 1 extra foot per foot moved, Disadvantage on attacks and Dex saves, attacks against have Advantage.',
      ],
      rules2024: [
        'Split movement freely around attacks and actions.',
        'Difficult terrain, climbing, and swimming cost 1 extra foot of movement per foot moved.',
        'Squeezing through smaller spaces confers Disadvantage on attacks and Dex saves.',
      ],
    ),
    DmReferenceItem(
      id: 'action_jumping',
      title: 'Jumping Rules (Long Jump & High Jump)',
      category: DmCategory.actions,
      subCategory: 'Movement Rule',
      cost: 'Part of Movement',
      icon: Icons.nordic_walking,
      color: Colors.greenAccent,
      summary: 'Long Jump (STR score ft) & High Jump (3 + STR mod ft) with 10ft running start.',
      tags: ['jumping', 'long jump', 'high jump', 'strength', 'athletics', 'movement'],
      isChangedIn2024: true,
      diffSummary: '2024 makes Jumping an active check (DC 10 Athletics/Acrobatics) to clear obstacles or gain extra height beyond standard baseline.',
      rules2014: [
        'Long Jump: With a 10-foot running start, jump horizontal feet equal to your STR score (half from standing). DC 10 Athletics to clear low obstacles (height = 1/4 jump distance).',
        'High Jump: With a 10-foot running start, leap into air vertical feet equal to 3 + STR modifier (half from standing). Reach extends arms 1.5x height above yourself.',
      ],
      rules2024: [
        'Long Jump: Jump distance equals STR score in feet (10ft run). Half from standing.',
        'High Jump: 3 + STR modifier in feet.',
        '2024 Jump Action: DC 10 Strength (Athletics) or Dexterity (Acrobatics) check to leap extra distance.',
      ],
    ),
    DmReferenceItem(
      id: 'action_flying_falling',
      title: 'Flying Movement & Aerial Falls',
      category: DmCategory.actions,
      subCategory: 'Movement Rule',
      cost: 'Continuous',
      icon: Icons.flight,
      color: Colors.lightBlueAccent,
      summary: 'Hover capability, falling when speed is 0 or knocked prone.',
      tags: ['flying', 'fly speed', 'hover', 'aerial', 'falling', 'prone', 'movement'],
      isChangedIn2024: false,
      rules2014: [
        'A flying creature falls if it is knocked Prone, has its speed reduced to 0, or is deprived of the ability to move (unless it can Hover or is held aloft by magic like the Fly spell).',
        'Falling rate: 500 feet per round instantly.',
      ],
      rules2024: [
        'Flying creatures fall if knocked Prone or speed drops to 0 unless they have the Hover trait.',
      ],
    ),
    DmReferenceItem(
      id: 'action_underwater_combat',
      title: 'Underwater Combat',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Continuous',
      icon: Icons.water,
      color: Colors.cyan,
      summary: 'Weapon restrictions, movement penalties, and fire resistance submerged.',
      tags: ['underwater', 'submerged', 'swimming', 'dagger', 'javelin', 'trident', 'spear', 'crossbow', 'fire resistance', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'Melee Attack: Disadvantage unless weapon is Dagger, Javelin, Shortsword, Spear, Trident, or creature has a swimming speed.',
        'Ranged Attack: Automatically misses beyond normal range. Disadvantage within normal range unless Crossbow, Net, Dart, Javelin, Spear, Trident.',
        'Submerged creatures and objects have Resistance to fire damage.',
      ],
      rules2024: [
        'Melee attacks have Disadvantage unless using Dagger, Javelin, Shortsword, Spear, Trident, or creature has swim speed.',
        'Ranged attacks auto-miss beyond normal range, and have Disadvantage within normal range unless using a Crossbow or underwater thrown weapon.',
        'Fully submerged creatures and objects have Resistance to fire damage.',
      ],
    ),
    DmReferenceItem(
      id: 'action_mounted_combat',
      title: 'Mounted Combat',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Half Speed to Mount/Dismount',
      icon: Icons.cruelty_free,
      color: Colors.brown,
      summary: 'Mounting, dismounting, controlled vs independent mounts.',
      tags: ['mounted', 'horse', 'mount', 'dismount', 'controlled mount', 'independent mount', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'Mounting/Dismounting: Costs half your speed. If knocked Prone while mounted, make DC 10 Dex save or land Prone 5ft away.',
        'Controlled Mount: Matches your initiative. Only takes Dash, Disengage, Dodge. Can move while you take actions.',
        'Independent Mount: Retains its own initiative and takes actions normally. Provokes opportunity attacks against itself or rider.',
      ],
      rules2024: [
        'Mounting/Dismounting costs half your Speed.',
        'Controlled Mount matches your initiative order; can only Dash, Disengage, or Dodge.',
        'Independent Mount retains initiative and full action economy.',
      ],
    ),
    DmReferenceItem(
      id: 'action_flanking',
      title: 'Flanking (Optional Rule)',
      category: DmCategory.actions,
      subCategory: 'Combat Rule',
      cost: 'Tactical Positioning',
      icon: Icons.join_inner,
      color: Colors.amber,
      summary: 'Advantage on melee attacks when ally is on direct opposite side of enemy.',
      tags: ['flanking', 'optional', 'advantage', 'positioning', 'grid', 'combat'],
      isChangedIn2024: false,
      rules2014: [
        'Optional Rule (DMG p. 251): When a creature and at least one ally are on opposite sides/corners of an enemy in melee reach, they have Advantage on melee attack rolls against that enemy.',
      ],
      rules2024: [
        'Optional positioning rule giving Advantage to attackers on opposite sides of a target.',
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
    // CONDITIONS & STATUSES
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
      tags: ['grappled', 'speed 0', 'escape', 'disadvantage', 'movement', 'calculator'],
      isChangedIn2024: true,
      interactiveTool: 'grapple_shove',
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
    DmReferenceItem(
      id: 'cond_poisons_diseases',
      title: 'Poisons & Diseases (SRD)',
      category: DmCategory.conditions,
      subCategory: 'Hazards',
      icon: Icons.coronavirus_outlined,
      color: Colors.green,
      summary: 'Contact, Ingested, Inhaled, and Injury poison mechanics and sample afflictions.',
      tags: ['poison', 'disease', 'toxic', 'cackle fever', 'sewer plague', 'sight rot', 'paralysis'],
      isChangedIn2024: false,
      rules2014: [
        'Contact: Applied to an object; takes effect on skin contact.',
        'Ingested: Consumed in food or liquid.',
        'Inhaled: Dispersed in air; affects creatures in 5ft cloud.',
        'Injury: Delivered through piercing or slashing weapon damage.',
        'Sample Diseases: Sewer Plague (DC 11 Con save or 1 level exhaustion and regain 0 HP on rest), Cackle Fever (DC 13 Con save or 1d10 psychic damage and laughing fits), Sight Rot (DC 15 Con save or blindness).',
      ],
      rules2024: [
        'Poisons function by method of exposure (Contact, Ingested, Inhaled, Injury).',
        'Diseases require recurring Constitution saving throws at the end of each Long Rest to recover.',
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
      tags: ['falling', 'bludgeoning', '1d6 per 10ft', 'max 20d6', 'landing on creature', 'hazard', 'calculator'],
      isChangedIn2024: true,
      interactiveTool: 'falling',
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
      tags: ['vision', 'light', 'dim light', 'darkness', 'darkvision', 'blindsight', 'truesight', 'tremorsense', 'perception'],
      isChangedIn2024: false,
      diffSummary: 'Lighting categories and sight rules remain consistent.',
      rules2014: [
        'Bright Light: Normal vision.',
        'Dim Light: Lightly obscured. Disadvantage on Wisdom (Perception) checks relying on sight.',
        'Darkness: Heavily obscured. Blinded status for creatures without darkvision/special senses.',
        'Darkvision: See in Dim Light within range as Bright Light, and Darkness as Dim Light (grayscale only).',
        'Blindsight: Perceive surroundings without relying on sight within specified radius.',
        'Truesight: See in normal and magical darkness, perceive invisible creatures, illusions, and shapechangers.',
        'Tremorsense: Detect and pinpoint the origin of vibrations within range along the same surface.',
      ],
      rules2024: [
        'Bright Light: Clear visibility.',
        'Dim Light: Lightly Obscured. Disadvantage on Perception checks relying on sight.',
        'Darkness: Heavily Obscured. Creatures without special senses have the Blinded condition.',
        'Darkvision: Treats Darkness within radius as Dim Light, Dim Light as Bright Light.',
        'Blindsight & Truesight: Function identically to 2014 definitions.',
        'Tremorsense: Pinpoints location of creatures touching ground/substance.',
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
    DmReferenceItem(
      id: 'env_extreme_temperatures',
      title: 'Extreme Heat & Extreme Cold',
      category: DmCategory.environment,
      icon: Icons.thermostat,
      color: Colors.deepOrangeAccent,
      summary: 'Environmental temperature hazards and exhaustion saves.',
      tags: ['extreme heat', 'extreme cold', 'con save', 'exhaustion', 'freezing', 'heatstroke', 'environment'],
      isChangedIn2024: false,
      rules2014: [
        'Extreme Cold (0°F or lower): DC 10 Constitution save at the end of each hour or gain 1 level of Exhaustion (auto-succeeds with cold weather gear).',
        'Extreme Heat (100°F or higher): DC 5 Constitution save at the end of each hour (+1 DC per hour), Disadvantage if in medium/heavy armor; gain 1 level of Exhaustion on fail.',
        'Creatures need twice as much water in extreme heat.',
      ],
      rules2024: [
        'Extreme Cold: DC 10 Con save per hour without cold gear or gain 1 level of Exhaustion.',
        'Extreme Heat: DC 5 (+1 per hour) Con save or gain 1 level of Exhaustion. Disadvantage if wearing Medium or Heavy armor.',
      ],
    ),
    DmReferenceItem(
      id: 'env_weather_hazards',
      title: 'Severe Weather (Precipitation, Wind, Altitude)',
      category: DmCategory.environment,
      icon: Icons.storm,
      color: Colors.blueAccent,
      summary: 'Heavy rain/snow, strong winds, and high altitude thin air penalties.',
      tags: ['weather', 'heavy rain', 'snow', 'strong wind', 'altitude', 'visibility', 'hazard'],
      isChangedIn2024: false,
      rules2014: [
        'Heavy Precipitation: Rain or heavy snow lightly obscures the area and imposes Disadvantage on Wisdom (Perception) checks relying on sight and hearing. Extinguishes open flames.',
        'Strong Wind: Disadvantage on ranged weapon attack rolls and Wisdom (Perception) checks relying on hearing. Extinguishes unprotected flames; flying creatures must land at end of turn or fall.',
        'High Altitude: At elevations above 10,000 feet, creatures can travel only half as far before suffering exhaustion unless acclimated.',
      ],
      rules2024: [
        'Precipitation imposes Lightly Obscured condition and Disadvantage on Perception.',
        'Strong winds impose Disadvantage on ranged attacks and hearing Perception.',
        'High altitude halves overland travel distances.',
      ],
    ),
    DmReferenceItem(
      id: 'env_wilderness_hazards',
      title: 'Wilderness Hazards (Quicksand, Ice, Desecrated Ground)',
      category: DmCategory.environment,
      icon: Icons.warning_amber_rounded,
      color: Colors.lime,
      summary: 'Quicksand sinking DCs, slippery ice acrobatics, and unholy ground buffs.',
      tags: ['quicksand', 'slippery ice', 'desecrated ground', 'razorvine', 'hazard', 'environment'],
      isChangedIn2024: false,
      rules2014: [
        'Quicksand: Spot with DC 15 Survival/Perception. When entering, sink 1d4+1 feet. Sinks 1d4 feet each turn. DC 10 + feet sunk Athletics check to escape.',
        'Slippery Ice: Difficult terrain. DC 10 Dexterity (Acrobatics) check when moving across ice on foot or fall Prone.',
        'Desecrated Ground: Undead have Advantage on all saving throws while in the area. Dispel Evil and Good purifies.',
        'Razorvine: Difficult terrain. DC 10 Dex save or take 1d10 piercing damage (1d10 slashing for unarmored).',
      ],
      rules2024: [
        'Quicksand sinks creatures; requires Athletics checks to climb out.',
        'Slippery ice requires DC 10 Acrobatics checks when dashing/moving rapidly.',
        'Desecrated ground bolsters undead saving throws with Advantage.',
      ],
    ),
    DmReferenceItem(
      id: 'env_survival_foraging',
      title: 'Wilderness Survival & Foraging',
      category: DmCategory.environment,
      icon: Icons.eco,
      color: Colors.green,
      summary: 'Food and water requirements, foraging DCs, and starvation.',
      tags: ['foraging', 'survival', 'food', 'water', 'starvation', 'dehydration', 'environment'],
      isChangedIn2024: false,
      rules2014: [
        'Food: 1 pound of food per day. Can go without food for 3 + Con mod days before suffering 1 level of exhaustion per day.',
        'Water: 1 gallon of water per day (2 gallons in extreme heat). If half water consumed: DC 15 Con save or 1 level exhaustion. If less: automatic exhaustion.',
        'Foraging: Wisdom (Survival) check while traveling. Abundant (DC 10), Typical (DC 15), Scarce (DC 20). Success yields 1d6 + WIS lbs food and 1d6 + WIS gallons water.',
      ],
      rules2024: [
        'Characters require 1 lb food and 1 gallon water daily.',
        'Foraging check: DC 10 (lush) to DC 20 (barren desert). Success yields 1d6 + WIS mod lbs of food and gallons of water.',
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
      tags: ['dc', 'difficulty', 'checks', 'very easy', 'easy', 'medium', 'hard', 'very hard', 'nearly impossible', 'calculator'],
      isChangedIn2024: false,
      interactiveTool: 'dc_benchmark',
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
      id: 'exp_ability_scores_skills',
      title: '6 Ability Scores & 18 Skills Matrix',
      category: DmCategory.exploration,
      icon: Icons.psychology_alt,
      color: Colors.cyanAccent,
      summary: 'STR (Athletics), DEX (Acrobatics, Sleight of Hand, Stealth), INT (Arcana, History, Investigation, Nature, Religion), WIS (Animal Handling, Insight, Medicine, Perception, Survival), CHA (Deception, Intimidation, Performance, Persuasion).',
      tags: ['skills', 'ability check', 'athletics', 'acrobatics', 'stealth', 'perception', 'investigation', 'insight', 'persuasion', 'arcana'],
      isChangedIn2024: false,
      rules2014: [
        'Strength: Athletics (Climbing, jumping, swimming, shoving).',
        'Dexterity: Acrobatics (Balance, flips), Sleight of Hand (Pickpocket, conceal), Stealth (Hiding).',
        'Constitution: Concentration, stamina, forced march, breath holding.',
        'Intelligence: Arcana (Spells, lore), History (Events, kingdoms), Investigation (Deduction, searching clues), Nature (Flora, fauna), Religion (Deities, rites).',
        'Wisdom: Animal Handling (Calming beasts), Insight (Discerning lies), Medicine (Stabilizing, diagnosing), Perception (Spotting, hearing), Survival (Tracking, foraging).',
        'Charisma: Deception (Lying), Intimidation (Threats), Performance (Entertainment), Persuasion (Honest influence).',
      ],
      rules2024: [
        'Skills map to the six ability scores identically.',
        'Tool proficiencies add your Proficiency Bonus when crafting or utilizing specialized equipment.',
      ],
    ),
    DmReferenceItem(
      id: 'exp_passive_checks',
      title: 'Passive Checks & Contested Rolls',
      category: DmCategory.exploration,
      icon: Icons.remove_red_eye_outlined,
      color: Colors.teal,
      summary: 'Formula: 10 + all modifiers (+5 with advantage, -5 with disadvantage).',
      tags: ['passive check', 'passive perception', 'contested roll', 'stealth vs perception', 'exploration'],
      isChangedIn2024: false,
      rules2014: [
        'Passive Check = 10 + all modifiers normally applied to the check.',
        'If the character has Advantage: add +5 to passive score.',
        'If the character has Disadvantage: subtract -5 from passive score.',
        'Contested Checks: Both sides roll d20 + modifiers. Highest total wins. Ties mean the status quo remains unchanged.',
      ],
      rules2024: [
        'Passive score = 10 + modifier (+5 Advantage / -5 Disadvantage).',
        'Contested rolls resolve simultaneous opposing efforts.',
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
      id: 'exp_forced_march',
      title: 'Forced March & Travel Exhaustion',
      category: DmCategory.exploration,
      icon: Icons.hiking,
      color: Colors.deepOrangeAccent,
      summary: 'Traveling beyond 8 hours daily requires progressive Constitution saving throws.',
      tags: ['forced march', 'travel', 'exhaustion', 'con save', 'overland', 'exploration'],
      isChangedIn2024: false,
      rules2014: [
        'The travel pace assumes 8 hours of travel per day.',
        'For each additional hour of travel beyond 8 hours, each character makes a Constitution saving throw at the end of the hour.',
        'DC = 10 + 1 for each hour past 8 hours.',
        'On a failed save, a character gains 1 level of Exhaustion.',
      ],
      rules2024: [
        'Traveling beyond 8 hours daily requires DC 10 (+1/hour) Constitution saves against gaining Exhaustion.',
      ],
    ),
    DmReferenceItem(
      id: 'exp_marching_order_nav',
      title: 'Marching Order & Navigation DCs',
      category: DmCategory.exploration,
      icon: Icons.navigation,
      color: Colors.deepPurpleAccent,
      summary: 'Ranks (front, middle, rear) and navigation checks.',
      tags: ['marching order', 'ranks', 'navigation', 'lost', 'wilderness', 'exploration'],
      isChangedIn2024: false,
      rules2014: [
        'Front Rank: Spots traps, first target of frontal ambushes, rolls active/passive Perception in front.',
        'Middle Rank: Protected core for navigators, mapmakers, and vulnerable allies.',
        'Rear Rank: Spots enemies approaching from behind; notices sneak attacks from the rear.',
        'Navigating: Wisdom (Survival) check at the start of travel. Forest DC 15, Swamp DC 15, Desert DC 15, Mountain DC 15. On failure, party travels in random direction.',
      ],
      rules2024: [
        'Marching order establishes front, middle, and rear lines.',
        'Characters navigating make a Survival check (DC 10-20 depending on terrain visibility). Failure causes the party to become lost.',
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
    DmReferenceItem(
      id: 'exp_traps_detection',
      title: 'Traps: Spotting, Disarming & Triggering',
      category: DmCategory.exploration,
      icon: Icons.dangerous_outlined,
      color: Colors.redAccent,
      summary: 'Perception / Investigation DCs to find traps; Thieves\' Tools to disarm.',
      tags: ['traps', 'spotting', 'disarming', 'thieves tools', 'perception', 'investigation', 'hazard'],
      isChangedIn2024: false,
      rules2014: [
        'Spotting: Wisdom (Perception) passive or active check vs trap Stealth DC.',
        'Understanding Mechanism: Intelligence (Investigation) check to deduce trigger mechanism.',
        'Disarming: Dexterity check using Thieves\' Tools vs trap Disarm DC. Failure by 5 or more triggers the trap immediately.',
      ],
      rules2024: [
        'Search action (Wisdom/Perception) locates hidden triggers.',
        'Utilize action with Thieves\' Tools disarms mechanical traps.',
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
      tags: ['concentration', 'save', 'con save', 'damage', 'dc 10', 'incapacitated', 'spellcasting', 'calculator'],
      isChangedIn2024: false,
      interactiveTool: 'concentration',
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
      id: 'magic_spell_components',
      title: 'Spell Components (V, S, M & GP Costs)',
      category: DmCategory.magicAndResting,
      icon: Icons.grain,
      color: Colors.tealAccent,
      summary: 'Verbal, Somatic, and Material component requirements.',
      tags: ['components', 'verbal', 'somatic', 'material', 'focus', 'component pouch', 'gp cost', 'magic'],
      isChangedIn2024: false,
      rules2014: [
        'Verbal (V): Audible chanting. Cannot be cast while Gagged or in a Silence spell.',
        'Somatic (S): Forceful hand gestures. Requires at least one free hand.',
        'Material (M): Specific objects. A Component Pouch or Spellcasting Focus can replace non-consumed materials without GP cost.',
        'Consumed / Priced Materials: If a material specifies a gold cost (e.g. 100 GP diamond), it must be provided and cannot be substituted by a focus.',
      ],
      rules2024: [
        'Verbal (V): Spoken incantations.',
        'Somatic (S): Hand gestures requiring a free hand (hand holding focus can fulfill somatic component).',
        'Material (M): Specific items. Focus replaces materials unless cost is specified or consumed.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_casting_times_rituals',
      title: 'Casting Times, Areas of Effect & Rituals',
      category: DmCategory.magicAndResting,
      icon: Icons.hourglass_bottom,
      color: Colors.deepPurpleAccent,
      summary: 'Action, Bonus Action, Reaction, Areas (Cone, Cube, Cylinder, Line, Sphere), and Rituals.',
      tags: ['casting time', 'ritual', 'aoe', 'cone', 'cube', 'cylinder', 'line', 'sphere', 'magic'],
      isChangedIn2024: false,
      rules2014: [
        'Casting Times: 1 Action, 1 Bonus Action, 1 Reaction, 1 Minute to 24 Hours.',
        'Ritual Casting: If a spell has the Ritual tag and you have ritual capability, you can cast it without expending a spell slot by adding 10 minutes to the casting time.',
        'Areas of Effect: Cone (width = length at base), Cube (face = length), Cylinder (radius + height), Line (length x 5ft width), Sphere (radius from origin).',
        'Cover and AoE: Spells originate from a point; total cover blocks the line of effect unless specified otherwise.',
      ],
      rules2024: [
        'Standard casting times apply.',
        'Ritual casting adds 10 minutes to casting time to cast without expending a spell slot.',
        'Areas of Effect (Cone, Cube, Cylinder, Line, Sphere) remain standard geometries.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_combining_effects',
      title: 'Combining Magical Effects & Spell Stacking',
      category: DmCategory.magicAndResting,
      icon: Icons.layers,
      color: Colors.indigoAccent,
      summary: 'Stacking spells and resolving identical magical effects.',
      tags: ['combining', 'stacking', 'spells', 'buffs', 'magic effects', 'magic'],
      isChangedIn2024: false,
      rules2014: [
        'Different Spells: The effects of different spells add together while their durations overlap (e.g. Bless + Shield of Faith).',
        'Same Spell Twice: The effects of the same spell cast multiple times do NOT combine. Only the most potent effect (e.g. highest bonus or highest spell slot level) applies while durations overlap.',
      ],
      rules2024: [
        'Different spells combine normally.',
        'Identical spells do not stack; only the strongest/most potent casting takes effect.',
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
      id: 'magic_counterspell_dispel',
      title: 'Counterspelling & Dispelling Magic',
      category: DmCategory.magicAndResting,
      icon: Icons.flash_off,
      color: Colors.purple,
      summary: 'Resolving spell counter attempts and removing magical effects.',
      tags: ['counterspell', 'dispel magic', 'abjuration', 'dc 10 + level', 'reaction', 'magic'],
      isChangedIn2024: true,
      diffSummary: '2014 Counterspell used an ability check (DC 10 + spell level). 2024 makes Counterspell force a Constitution saving throw from the caster to prevent the slot from being wasted.',
      rules2014: [
        'Counterspell: Automatically cancels spells of 3rd level or lower. For higher level spells, make an ability check (DC = 10 + spell level) using your spellcasting ability.',
        'Dispel Magic: Automatically ends spells of 3rd level or lower on target. For higher level spells, make an ability check (DC = 10 + spell level).',
      ],
      rules2024: [
        'Counterspell: Target makes a Constitution saving throw. On failed save, spell fails and spell slot is expended.',
        'Dispel Magic: Automatically dispels 3rd level or lower; higher level requires DC 10 + spell level check.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_attunement',
      title: 'Magic Item Attunement & Identification',
      category: DmCategory.magicAndResting,
      icon: Icons.auto_fix_high,
      color: Colors.cyanAccent,
      summary: '3-item attunement limit, Short Rest attunement/identification rules.',
      tags: ['attunement', 'identify', 'magic items', 'short rest', '3 items', 'magic'],
      isChangedIn2024: false,
      rules2014: [
        'Attunement Limit: A creature can be attuned to no more than 3 magic items simultaneously.',
        'Attuning: Requires a creature to spend a Short Rest focused on only that item in physical contact.',
        'Ending Attunement: Requires a Short Rest, or ends if the creature dies or is separated by 100+ feet for 24 hours.',
        'Identifying: Cast Identify spell, or spend a Short Rest focusing on one item to learn its properties.',
      ],
      rules2024: [
        'Maximum 3 attuned magic items at once.',
        'Attuning takes 1 Short Rest.',
        'Short rest focus or Identify spell reveals magic properties.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_resting',
      title: 'Short Rest & Long Rest Rules',
      category: DmCategory.magicAndResting,
      icon: Icons.bed,
      color: Colors.indigoAccent,
      summary: 'Hit Dice recovery, HP restoration, and interruption rules.',
      tags: ['short rest', 'long rest', 'hit dice', 'recovery', 'exhaustion', 'interruption', 'resting'],
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
    DmReferenceItem(
      id: 'magic_downtime_expenses',
      title: 'Lifestyle Expenses & Downtime',
      category: DmCategory.magicAndResting,
      icon: Icons.monetization_on,
      color: Colors.amber,
      summary: 'Daily living expenses from Wretched to Aristocratic.',
      tags: ['lifestyle', 'expenses', 'gp per day', 'wretched', 'squalid', 'poor', 'modest', 'comfortable', 'wealthy', 'aristocratic', 'downtime'],
      isChangedIn2024: false,
      rules2014: [
        'Wretched (0 GP/day): Homeless, destitute, disease risk.',
        'Squalid (1 SP/day): Shared room in rundown district, filthy.',
        'Poor (2 SP/day): Simple tavern room, plain food.',
        'Modest (1 GP/day): Basic lodging, clean water and food.',
        'Comfortable (2 GP/day): Private room, hearty meals, well maintained gear.',
        'Wealthy (4 GP/day): Luxurious quarters, fine wine, prestigious staff.',
        'Aristocratic (10+ GP/day): Opulent estate, royal treatment, lavish feasts.',
      ],
      rules2024: [
        'Living expenses range from Wretched (free) to Aristocratic (10+ GP/day).',
        'Determines access to resources, NPC connections, and recovery comfort during downtime.',
      ],
    ),
    DmReferenceItem(
      id: 'magic_downtime_activities',
      title: 'Downtime Activities & Crafting',
      category: DmCategory.magicAndResting,
      icon: Icons.construction,
      color: Colors.tealAccent,
      summary: 'Crafting non-magic items, potions, scrolls, training languages, and recuperating.',
      tags: ['downtime', 'crafting', 'training', 'recuperating', 'research', 'professions', 'magic'],
      isChangedIn2024: false,
      rules2014: [
        'Crafting: Craft non-magic items at a rate of 5 GP per day (costs half in raw materials). Multiple characters can combine efforts.',
        'Practicing a Profession: Earn enough to maintain a Modest lifestyle for free, or Comfortable if in a guild.',
        'Recuperating: 3 days of downtime allows an extra saving throw to end a debilitating disease or poison.',
        'Training: Spend 250 days and 1 GP per day with a trainer to learn a new language or set of tools.',
      ],
      rules2024: [
        'Downtime rules provide standard crafting speeds, spell scroll scribing, and language/tool training with dedicated proficiencies.',
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
    DmReferenceItem(
      id: 'table_size_space_carrying',
      title: 'Creature Sizes, Space & Carrying Capacity',
      category: DmCategory.tables,
      icon: Icons.aspect_ratio,
      color: Colors.blueAccent,
      summary: 'Grid space control, carrying capacity, push/drag/lift formulas.',
      tags: ['size', 'space', 'carrying capacity', 'push', 'drag', 'lift', 'tiny', 'small', 'medium', 'large', 'huge', 'gargantuan'],
      isChangedIn2024: false,
      rules2014: [
        'Tiny: 2½ by 2½ ft (Space) • Carrying Capacity = STR × 15 × 0.5 lbs.',
        'Small: 5 by 5 ft (Space) • Carrying Capacity = STR × 15 lbs.',
        'Medium: 5 by 5 ft (Space) • Carrying Capacity = STR × 15 lbs.',
        'Large: 10 by 10 ft (Space) • Carrying Capacity = STR × 15 × 2 lbs.',
        'Huge: 15 by 15 ft (Space) • Carrying Capacity = STR × 15 × 4 lbs.',
        'Gargantuan: 20 by 20 ft or larger • Carrying Capacity = STR × 15 × 8 lbs.',
        'Push, Drag, or Lift: Up to twice your carrying capacity (STR × 30 lbs, modified by size). Speed drops to 5 ft if exceeding carrying capacity.',
      ],
      rules2024: [
        'Creature sizes control grid space: Tiny (2.5x2.5 ft), Small (5x5 ft), Medium (5x5 ft), Large (10x10 ft), Huge (15x15 ft), Gargantuan (20x20+ ft).',
        'Carrying capacity = STR score × 15 lbs (multiplied for Large+ or halved for Tiny).',
        'Push / Drag / Lift = STR score × 30 lbs.',
      ],
    ),
    DmReferenceItem(
      id: 'table_weapon_properties_masteries',
      title: 'Weapon Properties & 2024 Masteries Matrix',
      category: DmCategory.tables,
      icon: Icons.colorize,
      color: Colors.redAccent,
      summary: 'Standard properties (Finesse, Light, Heavy, Reach) & 2024 Masteries (Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex).',
      tags: ['weapon properties', 'finesse', 'heavy', 'light', 'masteries', 'cleave', 'graze', 'nick', 'push', 'sap', 'slow', 'topple', 'vex'],
      isChangedIn2024: true,
      diffSummary: '2024 adds codified Weapon Masteries: Cleave (extra attack on adjacent), Graze (damage on miss), Nick (extra light attack without bonus action), Push (10ft knockback), Sap (enemy disadvantage), Slow (-10ft speed), Topple (Prone save), Vex (advantage on next attack).',
      rules2014: [
        'Ammunition: Requires projectiles and free hand to load.',
        'Finesse: Choose STR or DEX modifier for attack and damage.',
        'Heavy: Small creatures have Disadvantage on attack rolls.',
        'Light: Ideal for two-weapon fighting.',
        'Loading: Only 1 attack per action/bonus/reaction regardless of Extra Attack.',
        'Reach: Adds 5 feet to melee attack reach.',
        'Thrown: Can be thrown for ranged attack using same modifier as melee.',
        'Two-Handed: Requires two hands to make an attack.',
        'Versatile: Can be used with one or two hands (larger damage die).',
      ],
      rules2024: [
        '2024 Weapon Masteries (Class Feature):',
        '• Cleave: On hit, make another melee attack against adjacent creature within 5ft dealing weapon damage (no ability mod).',
        '• Graze: On miss, deal damage equal to your ability modifier to the target.',
        '• Nick: Extra light weapon attack is part of Attack action instead of Bonus Action.',
        '• Push: On hit, push a creature up to 10 feet away (size Large or smaller).',
        '• Sap: On hit, target has Disadvantage on its next attack roll before start of your next turn.',
        '• Slow: On hit, reduce target speed by 10 feet until start of your next turn.',
        '• Topple: On hit, target must succeed on a Con save (DC = 8 + Stat + PB) or fall Prone.',
        '• Vex: On hit, gain Advantage on your next attack roll against that target before end of next turn.',
      ],
    ),
    DmReferenceItem(
      id: 'table_armor_don_doff',
      title: 'Armor Table & Donning / Doffing Times',
      category: DmCategory.tables,
      icon: Icons.shield,
      color: Colors.amber,
      summary: 'AC formulas, stealth penalties, Strength minimums, and equip times.',
      tags: ['armor', 'shield', 'don', 'doff', 'light armor', 'medium armor', 'heavy armor', 'stealth disadvantage'],
      isChangedIn2024: false,
      rules2014: [
        'Light Armor: Padded (11+DEX, Disadv Stealth), Leather (11+DEX), Studded Leather (12+DEX). Don: 1 min • Doff: 1 min.',
        'Medium Armor: Hide (12+DEX max 2), Chain Shirt (13+DEX max 2), Scale Mail (14+DEX max 2, Disadv), Breastplate (14+DEX max 2), Half Plate (15+DEX max 2, Disadv). Don: 5 min • Doff: 1 min.',
        'Heavy Armor: Ring Mail (14, Disadv), Chain Mail (16, STR 13, Disadv), Splint (17, STR 15, Disadv), Plate (18, STR 15, Disadv). Don: 10 min • Doff: 5 min.',
        'Shield: +2 AC. Don: 1 Action • Doff: 1 Action.',
      ],
      rules2024: [
        'Light Armor: Don 1 min, Doff 1 min.',
        'Medium Armor: Don 5 min, Doff 1 min.',
        'Heavy Armor: Don 10 min, Doff 5 min.',
        'Shield: Don/Doff takes 1 Action (+2 AC).',
      ],
    ),
    DmReferenceItem(
      id: 'table_currency_exchange',
      title: 'Standard Currency Exchange & Coin Weight',
      category: DmCategory.tables,
      icon: Icons.paid_outlined,
      color: Colors.amberAccent,
      summary: '1 PP = 10 GP = 20 EP = 100 SP = 1,000 CP; 50 coins weigh 1 lb.',
      tags: ['currency', 'gold', 'silver', 'copper', 'electrum', 'platinum', 'coins', 'weight'],
      isChangedIn2024: false,
      rules2014: [
        'Copper Piece (CP): 1/100 GP.',
        'Silver Piece (SP): 1/10 GP (10 CP).',
        'Electrum Piece (EP): 1/2 GP (50 CP or 5 SP).',
        'Gold Piece (GP): Standard currency (10 SP or 100 CP).',
        'Platinum Piece (PP): 10 GP (100 SP or 1,000 CP).',
        'Coin Weight: 50 coins of any denomination weigh exactly 1 pound.',
      ],
      rules2024: [
        'Standard denominations: 1 PP = 10 GP = 20 EP = 100 SP = 1,000 CP.',
        'Weight: 50 coins = 1 lb.',
      ],
    ),
    DmReferenceItem(
      id: 'table_standard_languages',
      title: 'Standard & Exotic Languages Matrix',
      category: DmCategory.tables,
      icon: Icons.translate,
      color: Colors.lightGreenAccent,
      summary: 'Common, Dwarvish, Elvish, Draconic, Undercommon, Sylvan, Celestial, Abyssal, Infernal.',
      tags: ['languages', 'common', 'elvish', 'dwarvish', 'draconic', 'celestial', 'infernal', 'abyssal', 'undercommon'],
      isChangedIn2024: false,
      rules2014: [
        'Standard Languages: Common (Humans), Dwarvish (Dwarves), Elvish (Elves), Giant (Ogres, Giants), Gnomish (Gnomes), Goblin (Goblins), Halfling (Halflings), Orc (Orcs).',
        'Exotic Languages: Abyssal (Demons), Celestial (Celestials), Draconic (Dragons, Dragonborn), Deep Speech (Mind Flayers, Beholders), Infernal (Devils), Primordial (Elementals, Aquan, Auran, Ignan, Terran), Sylvan (Fey), Undercommon (Underdark dwellers).',
      ],
      rules2024: [
        'Standard and Exotic languages remain consistent for communication, ancient scripts, and planar interactions.',
      ],
    ),
    DmReferenceItem(
      id: 'table_adventuring_gear_lighting',
      title: 'Adventuring Gear & Light Sources',
      category: DmCategory.tables,
      icon: Icons.flashlight_on_outlined,
      color: Colors.orangeAccent,
      summary: 'Torches, Lanterns, Flasks, Ropes, and Container capacities.',
      tags: ['lighting', 'torch', 'lantern', 'bullseye', 'hooded lantern', 'backpack', 'pouch', 'gear'],
      isChangedIn2024: false,
      rules2014: [
        'Torch (1 CP): Burns 1 hr • 20ft Bright Light + 20ft Dim Light. Melee weapon 1 fire damage.',
        'Hooded Lantern (5 GP): Burns 6 hrs per 1 pint oil • 30ft Bright Light + 30ft Dim Light. Lower hood reduces to 5ft Dim Light.',
        'Bullseye Lantern (10 GP): Burns 6 hrs per pint oil • 60ft cone Bright Light + 60ft cone Dim Light.',
        'Candle (1 CP): Burns 1 hr • 5ft Bright Light + 5ft Dim Light.',
        'Container Capacities: Backpack (1 cubic ft / 30 lbs), Pouch (1/5 cubic ft / 6 lbs), Sack (1 cubic ft / 30 lbs), Chest (12 cubic ft / 300 lbs).',
      ],
      rules2024: [
        'Torches provide 20/20ft light for 1 hour.',
        'Hooded Lantern provides 30/30ft light; Bullseye provides 60/60ft cone light.',
        'Standard container capacities govern equipment loads.',
      ],
    ),
  ];
}
