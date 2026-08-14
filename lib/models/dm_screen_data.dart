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
  final DmCategory category;
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
    required this.category,
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

  List<String> getRules(DmRulesEdition edition) {
    return edition == DmRulesEdition.v2014 ? rules2014 : rules2024;
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) return true;
    if (summary.toLowerCase().contains(q)) return true;
    if (category.label.toLowerCase().contains(q)) return true;
    if (diffSummary != null && diffSummary!.toLowerCase().contains(q)) return true;
    for (final t in tags) {
      if (t.toLowerCase().contains(q)) return true;
    }
    for (final r in rules2014) {
      if (r.toLowerCase().contains(q)) return true;
    }
    for (final r in rules2024) {
      if (r.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class DmScreenLibrary {
  static const List<DmReferenceItem> allItems = [
    // ==========================================
    // ACTIONS & COMBAT
    // ==========================================
    DmReferenceItem(
      id: 'action_attack',
      title: 'Attack Action & Extra Attack',
      category: DmCategory.actions,
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      summary: 'Make one melee or ranged weapon/unarmed attack.',
      tags: ['attack', 'melee', 'ranged', 'extra attack', 'weapon', 'unarmed'],
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
      id: 'action_grapple_shove',
      title: 'Grapple & Shove (Unarmed Strikes)',
      category: DmCategory.actions,
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      summary: 'Grab or knock down / push a creature.',
      tags: ['grapple', 'shove', 'push', 'prone', 'unarmed strike', 'athletics', 'save dc'],
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
      id: 'action_two_weapon_fighting',
      title: 'Two-Weapon Fighting & Light Property',
      category: DmCategory.actions,
      icon: Icons.content_cut,
      color: Colors.amberAccent,
      summary: 'Attacking with dual-wielded weapons.',
      tags: ['dual wield', 'light weapon', 'off-hand', 'bonus action', 'nick mastery', 'two-weapon'],
      isChangedIn2024: true,
      diffSummary: '2014 strictly required a Bonus Action for the off-hand attack. 2024 codifies this in the Light weapon property (and weapon masteries like Nick can make it part of the Attack action with no Bonus Action used).',
      rules2014: [
        'When you take the Attack action with a Light melee weapon in one hand, you can use a Bonus Action to attack with a different Light melee weapon in the other hand.',
        'Do NOT add your ability modifier to the damage of the bonus attack unless that modifier is negative (or you have the Two-Weapon Fighting Style).',
      ],
      rules2024: [
        'When you take the Attack action and attack with a Light weapon, you can make one extra attack with a different Light weapon as a Bonus Action.',
        'With the Nick weapon mastery property, this extra attack is made as part of the Attack action itself rather than costing a Bonus Action.',
        'Ability modifier is not added to damage unless negative or with Two-Weapon Fighting style.',
      ],
    ),
    DmReferenceItem(
      id: 'action_dash_disengage_dodge',
      title: 'Dash, Disengage & Dodge',
      category: DmCategory.actions,
      icon: Icons.directions_run,
      color: Colors.greenAccent,
      summary: 'Core tactical movement and defense actions.',
      tags: ['dash', 'disengage', 'dodge', 'speed', 'opportunity attack', 'advantage'],
      isChangedIn2024: false,
      diffSummary: 'Core mechanics remain virtually identical across both editions.',
      rules2014: [
        'Dash (1 Action): Gain extra movement equal to your Speed for the current turn.',
        'Disengage (1 Action): Your movement does not provoke opportunity attacks for the rest of your turn.',
        'Dodge (1 Action): Until your next turn, attacks against you have Disadvantage (if you can see attacker), and you have Advantage on DEX saving throws. Lost if Incapacitated or speed drops to 0.',
      ],
      rules2024: [
        'Dash (1 Action): Gain extra movement equal to your Speed for the current turn.',
        'Disengage (1 Action): Your movement does not provoke opportunity attacks for the rest of the turn.',
        'Dodge (1 Action): Until the start of your next turn, attacks against you have Disadvantage (if visible), and you have Advantage on DEX saves. Benefits end if you have the Incapacitated condition or speed is 0.',
      ],
    ),
    DmReferenceItem(
      id: 'action_hide',
      title: 'Hide Action & Stealth',
      category: DmCategory.actions,
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      summary: 'Conceal yourself from enemies.',
      tags: ['hide', 'stealth', 'invisible', 'passive perception', 'dc 15', 'unseen'],
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
        'On a success, you gain the Invisible condition until you make a sound louder than a whisper, hit/miss an attack, cast a spell with verbal components, or an enemy spots you (Passive Perception beats your check roll).',
      ],
    ),
    DmReferenceItem(
      id: 'action_study_influence',
      title: 'Study & Influence Actions',
      category: DmCategory.actions,
      icon: Icons.menu_book,
      color: Colors.tealAccent,
      summary: 'Recall knowledge, analyze monsters, and social interactions.',
      tags: ['study', 'influence', 'arcana', 'history', 'nature', 'religion', 'persuasion', 'deception', 'intimidation'],
      isChangedIn2024: true,
      diffSummary: '2024 introduces codified Study and Influence standard actions for analyzing monster stat traits and formal social interactions.',
      rules2014: [
        'Ad-hoc DM rulings for knowledge checks (Arcana, History, Nature, Religion) and social checks (Persuasion, Deception, Intimidation) during combat.',
        'Usually handled under "Other Activity on Your Turn" or DM discretion.',
      ],
      rules2024: [
        'Study Action (1 Action): Make an Intelligence check (Arcana, History, Nature, Religion, or Investigation) to deduce monster weaknesses, traits, or decipher magical/historical lore.',
        'Influence Action (1 Action): Attempt to adjust an NPC\'s attitude (Friendly DC 10, Indifferent DC 15, Hostile DC 20) with Animal Handling, Deception, Intimidation, or Persuasion.',
      ],
    ),
    DmReferenceItem(
      id: 'action_help_search_ready',
      title: 'Help, Search & Ready Actions',
      category: DmCategory.actions,
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      summary: 'Assisting allies, finding hidden objects, and triggering reactions.',
      tags: ['help', 'search', 'ready', 'reaction', 'trigger', 'perception', 'investigation'],
      isChangedIn2024: true,
      diffSummary: '2024 codifies Search under Wisdom checks (Perception, Insight, Survival) and specifies Help action proficiency interactions.',
      rules2014: [
        'Help (1 Action): Feint to grant an ally Advantage on next attack roll against a foe within 5 ft, or grant Advantage on an ability check.',
        'Search (1 Action): Devote attention to find something (DM calls for Perception or Investigation).',
        'Ready (1 Action + 1 Reaction): Specify a perceivable trigger and action/spell. If readying a spell, cast it on your turn (uses slot) and hold concentration until reaction triggers.',
      ],
      rules2024: [
        'Help (1 Action): Assist an ally with an ability check (if you have proficiency in the skill) or feint against a creature within 5 ft to give ally Advantage on their next attack before your next turn.',
        'Search (1 Action): Make a Wisdom check (Insight, Perception, or Survival) to locate hidden creatures, tracks, or discern motives.',
        'Ready (1 Action + 1 Reaction): Choose a trigger and action. Spells require concentration while readied; if trigger does not occur before your next turn, the spell slot is lost.',
      ],
    ),
    DmReferenceItem(
      id: 'action_potions',
      title: 'Drinking & Administering Potions',
      category: DmCategory.actions,
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
      icon: Icons.favorite_border,
      color: Colors.red,
      summary: 'Dying, death saves, criticals, and stabilization.',
      tags: ['death saves', 'dying', 'unconscious', 'stabilize', 'medicine', 'nat 20', 'nat 1', '0 hp'],
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
    // CONDITIONS & STATUSES
    // ==========================================
    DmReferenceItem(
      id: 'cond_exhaustion',
      title: 'Exhaustion (Fatigue)',
      category: DmCategory.conditions,
      icon: Icons.battery_alert,
      color: Colors.red,
      summary: 'Severe physical fatigue and magical drain.',
      tags: ['exhaustion', 'levels', 'death', 'speed', 'd20 test', 'penalty', 'long rest'],
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
        'Cumulative penalty: 10 total levels.',
        'D20 Tests: Subtract 2 × your exhaustion level from all D20 Tests (attack rolls, ability checks, saving throws) and your spell save DC.',
        'Speed: Reduce speed by 5 feet × your exhaustion level.',
        'Level 10: Death.',
        'Finishing a Long Rest with food and water removes 1 level of exhaustion.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_incapacitated',
      title: 'Incapacitated',
      category: DmCategory.conditions,
      icon: Icons.do_not_disturb_on,
      color: Colors.redAccent,
      summary: 'Cannot take actions or reactions.',
      tags: ['incapacitated', 'actions', 'reactions', 'bonus actions', 'initiative', 'concentration'],
      isChangedIn2024: true,
      diffSummary: '2024 explicitly mentions Bonus Actions, gives incoming attacks Advantage, and gives Disadvantage on Initiative rolls!',
      rules2014: [
        'An incapacitated creature can\'t take Actions or Reactions.',
        'Concentration on spells is immediately broken.',
      ],
      rules2024: [
        'You can\'t take Actions, Bonus Actions, or Reactions.',
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
      icon: Icons.blur_on,
      color: Colors.cyanAccent,
      summary: 'Unseen by ordinary vision.',
      tags: ['invisible', 'advantage', 'disadvantage', 'stealth', 'initiative', 'concealed'],
      isChangedIn2024: true,
      diffSummary: '2024 clarifies that Invisible grants Advantage on Initiative rolls, and you are Concealed from standard sight and darkvision.',
      rules2014: [
        'An invisible creature is impossible to see without magic or special senses. Heavily obscured for hiding.',
        'Attack rolls against the creature have Disadvantage.',
        'The creature\'s attack rolls have Advantage.',
      ],
      rules2024: [
        'Concealed: You aren\'t affected by any effect that requires its target to be seen unless the creator has a way to see invisible creatures.',
        'Attacks against you have Disadvantage, and your attack rolls have Advantage.',
        'Initiative: If you are invisible when rolling Initiative, you have Advantage on the roll.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_grappled',
      title: 'Grappled',
      category: DmCategory.conditions,
      icon: Icons.sports_mma,
      color: Colors.amber,
      summary: 'Held in place by an opponent.',
      tags: ['grappled', 'speed 0', 'escape', 'disadvantage', 'movement'],
      isChangedIn2024: true,
      diffSummary: '2024 grappled creatures suffer Disadvantage on attacks against anyone other than the grappler, and make saves at the end of each turn.',
      rules2014: [
        'A grappled creature\'s Speed becomes 0, and it cannot benefit from bonuses to speed.',
        'Condition ends if the grappler is Incapacitated or if an effect moves the grappled creature out of reach.',
        'Grappler can move with target at half speed.',
      ],
      rules2024: [
        'Speed is 0 and cannot increase.',
        'Attacks: You have Disadvantage on attack rolls against any target other than the grappler.',
        'Movable: The grappler can drag or carry you at half speed (full speed if you are Tiny or 2+ sizes smaller).',
        'Escape: Make a STR or DEX saving throw at the end of each of your turns against the grapple DC.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_surprise',
      title: 'Surprise / Surprised',
      category: DmCategory.conditions,
      icon: Icons.sentiment_very_dissatisfied,
      color: Colors.deepPurpleAccent,
      summary: 'Caught off-guard at the start of combat.',
      tags: ['surprise', 'surprised', 'initiative', 'disadvantage', 'ambush', 'round 1'],
      isChangedIn2024: true,
      diffSummary: '2014: Skipped whole turn on round 1. 2024: No "surprised condition" — surprised creatures simply roll Initiative with Disadvantage!',
      rules2014: [
        'If surprised on combat start: You cannot move or take an Action on your first turn.',
        'You cannot take a Reaction until that first turn ends.',
      ],
      rules2024: [
        'There is no Surprised condition in 2024.',
        'If a creature is surprised when Initiative is rolled, it has Disadvantage on its Initiative roll.',
        'Creatures can act normally on their turn in round 1.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_blinded_deafened',
      title: 'Blinded & Deafened',
      category: DmCategory.conditions,
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      summary: 'Loss of vision or hearing senses.',
      tags: ['blinded', 'deafened', 'sight', 'hearing', 'advantage', 'disadvantage'],
      isChangedIn2024: false,
      diffSummary: 'Rules remain consistent across both 2014 and 2024.',
      rules2014: [
        'Blinded: Cannot see. Auto-fails ability checks requiring sight. Attacks against creature have Advantage; creature\'s attacks have Disadvantage.',
        'Deafened: Cannot hear. Auto-fails ability checks requiring hearing.',
      ],
      rules2024: [
        'Blinded: Can\'t see. Fails checks requiring sight. Attack rolls against have Advantage; its attack rolls have Disadvantage.',
        'Deafened: Can\'t hear. Fails checks requiring hearing.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_charmed_frightened',
      title: 'Charmed & Frightened',
      category: DmCategory.conditions,
      icon: Icons.favorite,
      color: Colors.pinkAccent,
      summary: 'Mental compulsion and terrifying dread.',
      tags: ['charmed', 'frightened', 'social', 'fear', 'disadvantage', 'line of sight'],
      isChangedIn2024: false,
      diffSummary: 'Mechanics remain consistent across both editions.',
      rules2014: [
        'Charmed: Cannot attack or target the charmer with harmful effects. Charmer has Advantage on social checks.',
        'Frightened: Disadvantage on ability checks and attack rolls while source of fear is in line of sight. Cannot willingly move closer.',
      ],
      rules2024: [
        'Charmed: Can\'t cast harmful spells or make attacks targeting the charmer. Charmer has Advantage on ability checks to interact socially.',
        'Frightened: Disadvantage on ability checks and attack rolls while the source is visible. Can\'t willingly move closer.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_paralyzed_petrified_stunned',
      title: 'Paralyzed, Petrified & Stunned',
      category: DmCategory.conditions,
      icon: Icons.offline_bolt,
      color: Colors.yellowAccent,
      summary: 'Severe bodily immobilization and stone transformation.',
      tags: ['paralyzed', 'petrified', 'stunned', 'incapacitated', 'auto-fail', 'critical hit', 'resistance'],
      isChangedIn2024: false,
      diffSummary: 'Mechanics remain consistent across both editions.',
      rules2014: [
        'Paralyzed: Incapacitated. Can\'t move or speak. Auto-fails STR and DEX saves. Attacks against have Advantage. Hits within 5 ft are Critical Hits.',
        'Petrified: Transformed into solid stone (10× weight). Incapacitated, unaware. Auto-fails STR/DEX saves. Resistance to all damage, immune to poison/disease. Attacks against have Advantage.',
        'Stunned: Incapacitated. Can speak only falteringly. Auto-fails STR/DEX saves. Attacks against have Advantage.',
      ],
      rules2024: [
        'Paralyzed: Incapacitated. Can\'t move or speak. Auto-fails STR/DEX saving throws. Attacks have Advantage. Hits from within 5 ft are Critical Hits.',
        'Petrified: Incapacitated, weight ×10. Auto-fails STR/DEX saves. Resistance to all damage, immune to poison. Attacks against have Advantage.',
        'Stunned: Incapacitated. Can speak only falteringly. Auto-fails STR/DEX saves. Attacks against have Advantage.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_poisoned_prone_restrained',
      title: 'Poisoned, Prone & Restrained',
      category: DmCategory.conditions,
      icon: Icons.airline_seat_flat,
      color: Colors.lightGreenAccent,
      summary: 'Toxicity, knocked down, and physical bondage.',
      tags: ['poisoned', 'prone', 'restrained', 'crawl', 'stand up', 'dex save', 'disadvantage'],
      isChangedIn2024: false,
      diffSummary: 'Standing up costs half speed in both. Prone grants melee advantage / ranged disadvantage.',
      rules2014: [
        'Poisoned: Disadvantage on attack rolls and ability checks.',
        'Prone: Crawling costs double. Standing up costs half Speed. Disadvantage on attacks. Attacks within 5 ft have Advantage; attacks beyond 5 ft have Disadvantage.',
        'Restrained: Speed 0. Attacks against have Advantage; its attacks have Disadvantage. Disadvantage on DEX saves.',
      ],
      rules2024: [
        'Poisoned: Disadvantage on attack rolls and ability checks.',
        'Prone: Must crawl (costs extra movement) or stand up (costs half Speed). Disadvantage on attack rolls. Attacks from within 5 ft have Advantage; other attacks have Disadvantage.',
        'Restrained: Speed 0. Attacks against have Advantage; its attacks have Disadvantage. Disadvantage on DEX saves.',
      ],
    ),
    DmReferenceItem(
      id: 'cond_unconscious',
      title: 'Unconscious',
      category: DmCategory.conditions,
      icon: Icons.bedtime,
      color: Colors.indigoAccent,
      summary: 'Knocked out, asleep, or reduced to 0 HP.',
      tags: ['unconscious', 'asleep', 'incapacitated', 'critical hit', '0 hp', 'prone'],
      isChangedIn2024: true,
      diffSummary: '2024 clarifies that unconscious creatures roll Initiative with Disadvantage if asleep when combat starts.',
      rules2014: [
        'Incapacitated, can\'t move or speak, unaware of surroundings.',
        'Drops held items and falls Prone.',
        'Auto-fails STR and DEX saves.',
        'Attacks against have Advantage. Hits within 5 ft are Critical Hits.',
      ],
      rules2024: [
        'Incapacitated, Prone, unaware of surroundings.',
        'Drops held items. Auto-fails STR and DEX saves.',
        'Attacks against have Advantage; hits from within 5 ft are Critical Hits.',
        'If asleep when combat begins, roll Initiative with Disadvantage.',
      ],
    ),

    // ==========================================
    // ENVIRONMENT & HAZARDS
    // ==========================================
    DmReferenceItem(
      id: 'env_cover',
      title: 'Cover Rules (+2, +5, Total)',
      category: DmCategory.environment,
      icon: Icons.shield,
      color: Colors.tealAccent,
      summary: 'AC and Dexterity saving throw modifiers from physical obstacles.',
      tags: ['cover', 'half cover', 'three-quarters', 'total cover', 'ac bonus', 'dex save'],
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
      id: 'env_falling',
      title: 'Falling Damage & Falling on Creatures',
      category: DmCategory.environment,
      icon: Icons.south,
      color: Colors.deepOrange,
      summary: 'Impact bludgeoning damage and landing on other creatures.',
      tags: ['falling', 'bludgeoning', '1d6 per 10ft', 'max 20d6', 'landing on creature', 'tasha'],
      isChangedIn2024: true,
      diffSummary: '2024 standardizes falling onto another creature: DC 15 Dex save, damage is split evenly between both creatures on fail!',
      rules2014: [
        '1d6 bludgeoning damage for every 10 feet fallen (max 20d6).',
        'Lands Prone unless damage is completely prevented.',
        'Landing on another creature was an optional rule in Tasha\'s (DC 15 Dex save to divide damage).',
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

class ConditionItem {
  final String name;
  final String category;
  final IconData icon;
  final Color color;
  final List<String> points2014;
  final List<String> points2024;

  const ConditionItem({
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.points2014,
    required this.points2024,
  });
}

class ConditionLibrary {
  static const categories = ['All', 'Incapacitating', 'Movement', 'Combat / Checks', 'Exhaustion'];

  static const List<ConditionItem> allConditions = [
    ConditionItem(
      name: 'Blinded',
      category: 'Combat / Checks',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      points2014: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
      points2024: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
    ),
    ConditionItem(
      name: 'Charmed',
      category: 'Combat / Checks',
      icon: Icons.favorite,
      color: Colors.pinkAccent,
      points2014: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
      points2024: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
    ),
    ConditionItem(
      name: 'Deafened',
      category: 'Combat / Checks',
      icon: Icons.hearing_disabled,
      color: Colors.tealAccent,
      points2014: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
      points2024: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
    ),
    ConditionItem(
      name: 'Frightened',
      category: 'Combat / Checks',
      icon: Icons.sentiment_very_dissatisfied,
      color: Colors.deepOrangeAccent,
      points2014: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
      points2024: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is visible.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
    ),
    ConditionItem(
      name: 'Grappled',
      category: 'Movement',
      icon: Icons.sports_mma,
      color: Colors.amber,
      points2014: [
        'A grappled creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'The condition ends if the grappler is Incapacitated.',
        'The condition also ends if an effect removes the grappled creature from reach (e.g. Thunderwave).',
        'Grappler can move with target at half speed.',
      ],
      points2024: [
        'Speed becomes 0 and cannot increase.',
        'Attacks: You have Disadvantage on attack rolls against anyone other than the grappler.',
        'Movable: The grappler can drag or carry you at half speed (full speed if you are Tiny or 2+ sizes smaller).',
        'Escape: Make a STR or DEX saving throw at the end of each of your turns against the escape DC.',
      ],
    ),
    ConditionItem(
      name: 'Incapacitated',
      category: 'Incapacitating',
      icon: Icons.do_not_disturb_on,
      color: Colors.redAccent,
      points2014: [
        'An incapacitated creature can’t take Actions or Reactions.',
        'Concentration on active spells is immediately broken.',
      ],
      points2024: [
        'You can’t take Actions, Bonus Actions, or Reactions.',
        'Your Concentration is immediately broken.',
        'Attack rolls against you have Advantage.',
        'You have Disadvantage on Initiative rolls.',
        'You cannot speak.',
      ],
    ),
    ConditionItem(
      name: 'Invisible',
      category: 'Combat / Checks',
      icon: Icons.blur_on,
      color: Colors.cyanAccent,
      points2014: [
        'An invisible creature is impossible to see without the aid of magic or a special sense. Heavily obscured for hiding purposes.',
        'Attack rolls against the creature have Disadvantage.',
        'The creature’s attack rolls have Advantage.',
      ],
      points2024: [
        'Concealed: You aren’t affected by any effect that requires its target to be seen (unless special sight).',
        'Attack rolls against you have Disadvantage; your attack rolls have Advantage.',
        'Initiative: If invisible when rolling Initiative, you have Advantage on the roll.',
      ],
    ),
    ConditionItem(
      name: 'Paralyzed',
      category: 'Incapacitating',
      icon: Icons.offline_bolt,
      color: Colors.yellowAccent,
      points2014: [
        'A paralyzed creature is Incapacitated (can’t take actions or reactions) and can’t move or speak.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet.',
      ],
      points2024: [
        'Incapacitated, can’t move or speak.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
        'Any attack that hits from within 5 feet is a Critical Hit.',
      ],
    ),
    ConditionItem(
      name: 'Petrified',
      category: 'Incapacitating',
      icon: Icons.terrain,
      color: Colors.brown,
      points2014: [
        'Transformed into a solid inanimate substance (usually stone). Weight increases by a factor of ten, and ceases aging.',
        'The creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'Attack rolls against the creature have Advantage.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'The creature has Resistance to all damage and is Immune to poison and disease.',
      ],
      points2024: [
        'Transformed into solid stone (weight ×10), ceases aging.',
        'Incapacitated, can’t move or speak, unaware of surroundings.',
        'Attack rolls against have Advantage. Auto-fails STR and DEX saves.',
        'Resistance to all damage; Immune to poison damage and the Poisoned condition.',
      ],
    ),
    ConditionItem(
      name: 'Poisoned',
      category: 'Combat / Checks',
      icon: Icons.science,
      color: Colors.greenAccent,
      points2014: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
      points2024: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
    ),
    ConditionItem(
      name: 'Prone',
      category: 'Movement',
      icon: Icons.airline_seat_flat,
      color: Colors.lightGreenAccent,
      points2014: [
        'A prone creature’s only movement option is to crawl, unless it stands up and thereby ends the condition.',
        'Standing up costs an amount of movement equal to half the creature’s speed.',
        'The creature has Disadvantage on attack rolls.',
        'An attack roll against the creature has Advantage if the attacker is within 5 feet of the creature. Otherwise, the attack roll has Disadvantage.',
      ],
      points2024: [
        'Only movement options are crawling (costs extra movement) or standing up (costs half Speed).',
        'Disadvantage on attack rolls.',
        'Attack rolls from within 5 feet have Advantage; other attack rolls have Disadvantage.',
      ],
    ),
    ConditionItem(
      name: 'Restrained',
      category: 'Movement',
      icon: Icons.lock,
      color: Colors.orangeAccent,
      points2014: [
        'A restrained creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'Attack rolls against the creature have Advantage, and the creature’s attack rolls have Disadvantage.',
        'The creature has Disadvantage on Dexterity saving throws.',
      ],
      points2024: [
        'Speed becomes 0 and cannot increase.',
        'Attack rolls against have Advantage, and creature’s attack rolls have Disadvantage.',
        'Disadvantage on Dexterity saving throws.',
      ],
    ),
    ConditionItem(
      name: 'Stunned',
      category: 'Incapacitating',
      icon: Icons.flash_on,
      color: Colors.purpleAccent,
      points2014: [
        'A stunned creature is Incapacitated, can’t move, and can speak only falteringly.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
      ],
      points2024: [
        'Incapacitated, can’t move, can speak only falteringly.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
      ],
    ),
    ConditionItem(
      name: 'Unconscious',
      category: 'Incapacitating',
      icon: Icons.bedtime,
      color: Colors.indigoAccent,
      points2014: [
        'An unconscious creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'The creature drops whatever it’s holding and falls Prone.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet of the creature.',
      ],
      points2024: [
        'Incapacitated, drops held items, falls Prone, unaware of surroundings.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage; hits from within 5 feet are Critical Hits.',
        'If asleep when combat begins, rolls Initiative with Disadvantage.',
      ],
    ),
    ConditionItem(
      name: 'Exhaustion',
      category: 'Exhaustion',
      icon: Icons.battery_alert,
      color: Colors.red,
      points2014: [
        'Level 1: Disadvantage on ability checks',
        'Level 2: Speed halved',
        'Level 3: Disadvantage on attack rolls and saving throws',
        'Level 4: Hit point maximum halved',
        'Level 5: Speed reduced to 0',
        'Level 6: Death',
        'Finishing a Long Rest with food/drink reduces exhaustion level by 1.',
      ],
      points2024: [
        'Cumulative penalty across 10 total levels.',
        'D20 Tests: Subtract 2 × exhaustion level from all D20 Tests (attack rolls, ability checks, saves) and spell save DC.',
        'Speed: Reduce speed by 5 feet × exhaustion level.',
        'Level 10: Death.',
        'Finishing a Long Rest with food/drink removes 1 exhaustion level.',
      ],
    ),
    ConditionItem(
      name: 'Surprise / Surprised',
      category: 'Combat / Checks',
      icon: Icons.priority_high,
      color: Colors.deepPurpleAccent,
      points2014: [
        'If surprised: You cannot move or take an Action on your first turn of combat.',
        'You cannot take a Reaction until that first turn ends.',
      ],
      points2024: [
        'No "Surprised" condition exists in 2024.',
        'If surprised when Initiative is rolled, you have Disadvantage on your Initiative roll.',
        'You can act normally on your first turn.',
      ],
    ),
  ];
}

class CombatActionItem {
  final String title;
  final String cost;
  final IconData icon;
  final Color color;
  final String desc;

  const CombatActionItem({
    required this.title,
    required this.cost,
    required this.icon,
    required this.color,
    required this.desc,
  });
}

class ActionEconomyLibrary {
  static const standardActions2014 = [
    CombatActionItem(
      title: 'Attack',
      cost: '1 Action',
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      desc: 'Make one melee or ranged weapon/unarmed attack. Features like Extra Attack allow multiple attacks per Attack action. Draw/sheathe only 1 weapon for free on your turn.',
    ),
    CombatActionItem(
      title: 'Cast a Spell',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      desc: 'Cast a spell with a casting time of 1 Action. Observe V, S, M component rules and concentration limits.',
    ),
    CombatActionItem(
      title: 'Dash',
      cost: '1 Action',
      icon: Icons.directions_run,
      color: Colors.cyanAccent,
      desc: 'Gain extra movement for the current turn equal to your Speed (e.g. 30 ft becomes 60 ft total).',
    ),
    CombatActionItem(
      title: 'Disengage',
      cost: '1 Action',
      icon: Icons.transit_enterexit,
      color: Colors.greenAccent,
      desc: 'Your movement does not provoke opportunity attacks for the rest of the turn.',
    ),
    CombatActionItem(
      title: 'Dodge',
      cost: '1 Action',
      icon: Icons.shield,
      color: Colors.blueAccent,
      desc: 'Until your next turn, attack rolls against you have Disadvantage (if you can see the attacker), and you have Advantage on DEX saves.',
    ),
    CombatActionItem(
      title: 'Help',
      cost: '1 Action',
      icon: Icons.handshake,
      color: Colors.tealAccent,
      desc: 'Give an ally Advantage on their next ability check, or Advantage on their next attack roll against a creature within 5 ft of you.',
    ),
    CombatActionItem(
      title: 'Hide',
      cost: '1 Action',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      desc: 'Make a Dexterity (Stealth) check contested by enemies\' Passive Perception to become unseen and unheard.',
    ),
    CombatActionItem(
      title: 'Ready',
      cost: '1 Action + Reaction',
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      desc: 'Specify a perceivable trigger and an action (or spell) to execute as a Reaction before your next turn.',
    ),
    CombatActionItem(
      title: 'Search',
      cost: '1 Action',
      icon: Icons.search,
      color: Colors.lightGreenAccent,
      desc: 'Devote attention to finding something. The DM might call for a Wisdom (Perception) or Intelligence (Investigation) check.',
    ),
    CombatActionItem(
      title: 'Use an Object',
      cost: '1 Action',
      icon: Icons.touch_app,
      color: Colors.pinkAccent,
      desc: 'Interact with a second object on your turn, or use a complex item (like applying a potion or pulling a lever).',
    ),
    CombatActionItem(
      title: 'Drink / Administer a Potion (2014 RAW)',
      cost: '1 Action',
      icon: Icons.liquor,
      color: Colors.redAccent,
      desc: 'Drinking a potion or administering a potion to an unconscious ally requires 1 Action in 2014 rules.',
    ),
    CombatActionItem(
      title: 'Grapple (2014 Contested)',
      cost: '1 Attack (Part of Attack Action)',
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      desc: 'Strength (Athletics) check contested by target Athletics or Acrobatics. Target Speed becomes 0 if successful.',
    ),
    CombatActionItem(
      title: 'Shove / Push (2014 Contested)',
      cost: '1 Attack (Part of Attack Action)',
      icon: Icons.swipe_right,
      color: Colors.deepOrange,
      desc: 'Strength (Athletics) check contested by target Athletics or Acrobatics. Knock the target Prone or push it 5 feet away.',
    ),
  ];

  static const standardActions2024 = [
    CombatActionItem(
      title: 'Attack & Weapon Swapping',
      cost: '1 Action',
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      desc: 'Make one attack with a weapon or Unarmed Strike (Damage, Grapple, or Shove). You can draw or stow one weapon before or after EACH attack.',
    ),
    CombatActionItem(
      title: 'Cast a Spell (2024 Slot Limit)',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      desc: 'Cast a spell. On your turn, you can expend only ONE spell slot (you may cast multiple spells if only one uses a slot, e.g., slot + cantrip).',
    ),
    CombatActionItem(
      title: 'Dash',
      cost: '1 Action',
      icon: Icons.directions_run,
      color: Colors.cyanAccent,
      desc: 'Gain extra movement for the current turn equal to your Speed.',
    ),
    CombatActionItem(
      title: 'Disengage',
      cost: '1 Action',
      icon: Icons.transit_enterexit,
      color: Colors.greenAccent,
      desc: 'Your movement does not provoke opportunity attacks for the rest of the turn.',
    ),
    CombatActionItem(
      title: 'Dodge',
      cost: '1 Action',
      icon: Icons.shield,
      color: Colors.blueAccent,
      desc: 'Until your next turn, attacks against you have Disadvantage (if visible), and you have Advantage on DEX saves.',
    ),
    CombatActionItem(
      title: 'Help',
      cost: '1 Action',
      icon: Icons.handshake,
      color: Colors.tealAccent,
      desc: 'Give an ally Advantage on their next ability check (if you are proficient), or Advantage on an attack roll against a creature within 5 ft.',
    ),
    CombatActionItem(
      title: 'Hide (2024 DC 15)',
      cost: '1 Action',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      desc: 'Make a DC 15 Dexterity (Stealth) check while heavily obscured or behind 3/4+ cover. On success, you gain the Invisible condition!',
    ),
    CombatActionItem(
      title: 'Study (2024 New Action)',
      cost: '1 Action',
      icon: Icons.menu_book,
      color: Colors.teal,
      desc: 'Make an Intelligence check (Arcana, History, Nature, Religion, Investigation) to deduce monster stats, traits, weaknesses, or lore.',
    ),
    CombatActionItem(
      title: 'Influence (2024 New Action)',
      cost: '1 Action',
      icon: Icons.record_voice_over,
      color: Colors.pinkAccent,
      desc: 'Influence an NPC attitude: Friendly DC 10, Indifferent DC 15, Hostile DC 20 with Persuasion, Deception, Animal Handling, or Intimidation.',
    ),
    CombatActionItem(
      title: 'Search (2024 Codified)',
      cost: '1 Action',
      icon: Icons.search,
      color: Colors.lightGreenAccent,
      desc: 'Make a Wisdom check (Insight, Perception, Survival) to discern motives or locate concealed creatures/items.',
    ),
    CombatActionItem(
      title: 'Ready',
      cost: '1 Action + Reaction',
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      desc: 'Specify a trigger and action. Readied spells require concentration until released as a reaction.',
    ),
    CombatActionItem(
      title: 'Grapple (2024 Save DC)',
      cost: '1 Unarmed Strike (Attack Action)',
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      desc: 'Target makes STR/DEX save vs DC = 8 + STR + Prof. On fail, gains Grappled (Disadvantage on attacks against anyone other than grappler).',
    ),
    CombatActionItem(
      title: 'Shove (2024 Save DC)',
      cost: '1 Unarmed Strike (Attack Action)',
      icon: Icons.swipe_right,
      color: Colors.deepOrange,
      desc: 'Target makes STR/DEX save vs DC = 8 + STR + Prof. On fail, target is knocked Prone or pushed 5 feet away.',
    ),
  ];

  static const bonusActions2014 = [
    CombatActionItem(
      title: 'Two-Weapon Fighting (Off-Hand)',
      cost: '1 Bonus Action',
      icon: Icons.content_cut,
      color: Colors.amber,
      desc: 'When you take the Attack action with a light melee weapon in one hand, attack with a different light melee weapon in the other hand (no ability mod to damage unless negative).',
    ),
    CombatActionItem(
      title: 'Bonus Action Spells (2014 Rule)',
      cost: '1 Bonus Action',
      icon: Icons.bolt,
      color: Colors.purpleAccent,
      desc: 'If you cast a Bonus Action spell (e.g. Healing Word, Misty Step), you cannot cast another spell on the same turn except for a Cantrip with a casting time of 1 Action.',
    ),
    CombatActionItem(
      title: 'Class & Item Features',
      cost: '1 Bonus Action',
      icon: Icons.star,
      color: Colors.cyanAccent,
      desc: 'Features explicitly designated as Bonus Actions (Cunning Action, Bardic Inspiration, Rage, Second Wind, Command Minions).',
    ),
  ];

  static const bonusActions2024 = [
    CombatActionItem(
      title: 'Drink or Administer a Potion (2024)',
      cost: '1 Bonus Action',
      icon: Icons.liquor,
      color: Colors.redAccent,
      desc: 'In the 2024 rules, drinking any potion or administering a potion to an ally requires only 1 Bonus Action!',
    ),
    CombatActionItem(
      title: 'Two-Weapon Fighting (Light Property)',
      cost: '1 Bonus Action (or Part of Attack with Nick)',
      icon: Icons.content_cut,
      color: Colors.amber,
      desc: 'Attack with an off-hand Light weapon. With the Nick weapon mastery property, this extra attack is part of the Attack action itself without using a Bonus Action.',
    ),
    CombatActionItem(
      title: 'Bonus Action Spells',
      cost: '1 Bonus Action',
      icon: Icons.bolt,
      color: Colors.purpleAccent,
      desc: 'Cast a spell with a casting time of 1 Bonus Action. Follows the 1-spell-slot-per-turn limitation.',
    ),
    CombatActionItem(
      title: 'Class Features',
      cost: '1 Bonus Action',
      icon: Icons.star,
      color: Colors.cyanAccent,
      desc: 'Cunning Action, Bardic Inspiration, Second Wind, Rage, and specialized bonus action spells/abilities.',
    ),
  ];

  static const reactions = [
    CombatActionItem(
      title: 'Opportunity Attack',
      cost: '1 Reaction',
      icon: Icons.front_hand,
      color: Colors.redAccent,
      desc: 'When a hostile creature that you can see leaves your reach without Disengaging, make one melee weapon attack against it.',
    ),
    CombatActionItem(
      title: 'Reaction Spells',
      cost: '1 Reaction',
      icon: Icons.security,
      color: Colors.purpleAccent,
      desc: 'Triggered by specific circumstances (e.g. Shield triggered by being hit, Absorb Elements by taking elemental damage, Counterspell by seeing a creature cast a spell).',
    ),
    CombatActionItem(
      title: 'Readied Action Trigger',
      cost: '1 Reaction',
      icon: Icons.alarm_on,
      color: Colors.orangeAccent,
      desc: 'Execute your previously Readied action when its designated trigger condition occurs.',
    ),
  ];

  static const coverRules = [
    CombatActionItem(
      title: 'Half Cover (+2 AC / +2 DEX Saves)',
      cost: 'Environmental',
      icon: Icons.table_restaurant,
      color: Colors.lightGreenAccent,
      desc: 'A target has half cover if an obstacle blocks at least half of its body (e.g. low wall, large furniture, another creature).',
    ),
    CombatActionItem(
      title: 'Three-Quarters Cover (+5 AC / +5 DEX Saves)',
      cost: 'Environmental',
      icon: Icons.fence,
      color: Colors.amber,
      desc: 'A target has three-quarters cover if about three-quarters of its body is covered (e.g. portcullis, arrow slit, thick tree trunk).',
    ),
    CombatActionItem(
      title: 'Total Cover (Untargetable)',
      cost: 'Environmental',
      icon: Icons.door_front_door,
      color: Colors.redAccent,
      desc: 'A target with total cover cannot be targeted directly by an attack or spell, though some spells can reach it within an area of effect.',
    ),
  ];
}
