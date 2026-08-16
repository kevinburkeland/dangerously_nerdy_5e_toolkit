import 'package:flutter/material.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import 'dm_screen_data.dart';

export '../widgets/glyphs/glyph_tokens.dart';

enum SpellClass {
  bard('Bard', Icons.music_note),
  cleric('Cleric', Icons.health_and_safety_outlined),
  druid('Druid', Icons.eco_outlined),
  paladin('Paladin', Icons.shield),
  ranger('Ranger', Icons.track_changes),
  sorcerer('Sorcerer', Icons.flash_on),
  warlock('Warlock', Icons.dark_mode_outlined),
  wizard('Wizard', Icons.auto_awesome),
  artificer('Artificer', Icons.handyman_outlined);

  final String label;
  final IconData icon;

  const SpellClass(this.label, this.icon);
}

/// Detailed rules information for a specific rules edition of a spell.
class SpellEditionDetails {
  final String castingTime;
  final String range;
  final String components; // e.g. "V, S, M (a tiny ball of bat guano and pitch)"
  final String duration;
  final bool concentration;
  final bool ritual;
  final List<String> description;
  final String? higherLevels;
  final List<SpellClass> classes;
  final String? rollFormula; // e.g. "8d6" or "2d8 + mod"
  final String? damageOrHealType; // e.g. "Fire", "Healing", "Radiant"
  final String? savingThrow; // e.g. "Dexterity", "Wisdom"

  const SpellEditionDetails({
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    this.concentration = false,
    this.ritual = false,
    required this.description,
    this.higherLevels,
    required this.classes,
    this.rollFormula,
    this.damageOrHealType,
    this.savingThrow,
  });
}

/// Represents an SRD Spell with 2014 & 2024 comparison metadata and rules definitions.
class SpellItem {
  final String id;
  final String name;
  final String? name2014;
  final String? name2024;
  final int level; // 0 = Cantrip, 1-9 = Spell Level
  final SpellSchool school;
  final SpellEditionDetails rules2014;
  final SpellEditionDetails rules2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final List<String> tags;

  const SpellItem({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.level,
    required this.school,
    required this.rules2014,
    required this.rules2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.tags = const [],
  });

  String getName(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014 && name2014 != null) return name2014!;
    if (edition == DmRulesEdition.v2024 && name2024 != null) return name2024!;
    return name;
  }

  SpellEditionDetails getRules(DmRulesEdition edition) {
    return edition == DmRulesEdition.v2014 ? rules2014 : rules2024;
  }

  String get levelLabel {
    if (level == 0) return 'Cantrip';
    switch (level) {
      case 1:
        return '1st Level';
      case 2:
        return '2nd Level';
      case 3:
        return '3rd Level';
      default:
        return '${level}th Level';
    }
  }

  String get fullTypeLabel => '$levelLabel ${school.label}';

  bool matches(
    String query, {
    SpellSchool? schoolFilter,
    int? levelFilter,
    SpellClass? classFilter,
    bool? changedOnly,
    bool? ritualOnly,
    bool? concentrationOnly,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    if (schoolFilter != null && school != schoolFilter) return false;
    if (levelFilter != null && level != levelFilter) return false;
    if (changedOnly == true && !isChangedIn2024) return false;

    final currentRules = getRules(edition);
    if (classFilter != null && !currentRules.classes.contains(classFilter)) return false;
    if (ritualOnly == true && !currentRules.ritual) return false;
    if (concentrationOnly == true && !currentRules.concentration) return false;

    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();

    if (name.toLowerCase().contains(q)) return true;
    if (name2014 != null && name2014!.toLowerCase().contains(q)) return true;
    if (name2024 != null && name2024!.toLowerCase().contains(q)) return true;
    if (school.label.toLowerCase().contains(q)) return true;
    if (levelLabel.toLowerCase().contains(q)) return true;
    if (diffSummary != null && diffSummary!.toLowerCase().contains(q)) return true;
    if (currentRules.damageOrHealType != null && currentRules.damageOrHealType!.toLowerCase().contains(q)) return true;
    if (currentRules.savingThrow != null && currentRules.savingThrow!.toLowerCase().contains(q)) return true;

    if (currentRules.components.toLowerCase().contains(q)) return true;
    if (currentRules.range.toLowerCase().contains(q)) return true;
    if (currentRules.castingTime.toLowerCase().contains(q)) return true;
    if (currentRules.duration.toLowerCase().contains(q)) return true;
    if (currentRules.rollFormula != null && currentRules.rollFormula!.toLowerCase().contains(q)) return true;
    if (currentRules.higherLevels != null && currentRules.higherLevels!.toLowerCase().contains(q)) return true;

    for (final tag in tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    for (final cls in currentRules.classes) {
      if (cls.label.toLowerCase().contains(q)) return true;
    }
    for (final line in currentRules.description) {
      if (line.toLowerCase().contains(q)) return true;
    }

    return false;
  }

  /// Dynamic action rings for DndGlyph HUD rendering conforming to the Glyph Style Guide.
  List<ActionTraitRing> getGlyphActionRings(DmRulesEdition edition) {
    final rings = <ActionTraitRing>[];
    final rules = getRules(edition);

    if (rules.concentration) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.concentration));
    }

    final dmg = rules.damageOrHealType?.toLowerCase() ?? '';
    if (dmg.contains('fire')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire));
    } else if (dmg.contains('radiant')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.radiant));
    } else if (dmg.contains('necrotic')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.necrotic));
    } else if (dmg.contains('lightning')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.lightning));
    } else if (dmg.contains('cold')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.cold));
    } else if (dmg.contains('poison')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.poison));
    } else if (dmg.contains('acid')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.acid));
    } else if (dmg.contains('psychic')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.psychic));
    } else if (dmg.contains('force')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.force));
    } else if (dmg.contains('thunder')) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.thunder));
    }

    return rings;
  }
}

/// Comprehensive SRD Spell Library featuring core cantrips and spells with 2014 & 2024 comparison data.
class SpellbookLibrary {
  SpellbookLibrary._();

  static const List<SpellItem> allSpells = [
    // ---------------------------------------------------------
    // CANTRIPS (LEVEL 0)
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_true_strike',
      name: 'True Strike',
      level: 0,
      school: SpellSchool.divination,
      isChangedIn2024: true,
      diffSummary: 'Completely redesigned: Now makes an immediate weapon attack using your spellcasting modifier for attack and damage, dealing radiant damage.',
      diffHighlights: [
        '2014: 1 Action, Concentration (1 round), grants advantage on your NEXT turn’s first attack roll.',
        '2024: 1 Action, Instantaneous. Immediately make a weapon attack using your spellcasting ability for attack & damage rolls (deals Radiant damage). Damage scales with +1d6 Radiant at 5th, 11th, and 17th level.',
        'Now available to Bards, Sorcerers, Warlocks, and Wizards.',
      ],
      tags: ['attack', 'weapon', 'radiant', 'cantrip', 'redesign'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '30 feet',
        components: 'S',
        duration: 'Concentration, up to 1 round',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You point a finger at a target in range. Your magic grants you a brief insight into the target’s defenses.',
          'On your next turn, you gain advantage on your first attack roll against the target, provided the spell hasn’t ended.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self',
        components: 'S, M (a weapon with which you have proficiency and that is worth at least 1 CP)',
        duration: 'Instantaneous',
        concentration: false,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        rollFormula: '1d6',
        damageOrHealType: 'Radiant',
        description: [
          'Guided by a flash of magical insight, you make one attack with the weapon used in the spell’s casting.',
          'The attack uses your spellcasting ability modifier instead of Strength or Dexterity for the attack and damage rolls.',
          'On a hit, the target suffers the weapon attack’s normal effects, and the damage dealt by the weapon is Radiant damage instead of its normal damage type.',
          'Cantrip Upgrade: The attack deals an extra 1d6 Radiant damage at 5th level, 2d6 at 11th level, and 3d6 at 17th level.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_blade_ward',
      name: 'Blade Ward',
      level: 0,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Changed from an Action granting weapon resistance for 1 round to a Reaction/Concentration spell subtracting 1d4 from enemy attack rolls.',
      diffHighlights: [
        '2014: 1 Action, Self, 1 round duration. Grants resistance to bludgeoning, piercing, and slashing damage from weapon attacks until the end of your next turn.',
        '2024: 1 Reaction (when an enemy within 30 ft attacks you/ally) or 1 Action Concentration (1 minute). Subtracted 1d4 from the attacker’s d20 roll.',
      ],
      tags: ['defense', 'ward', 'cantrip', 'reaction', 'abjuration'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self',
        components: 'V, S',
        duration: '1 round',
        concentration: false,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You extend your hand and trace a sigil of warding in the air.',
          'Until the end of your next turn, you have resistance against bludgeoning, piercing, and slashing damage dealt by weapon attacks.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Reaction, which you take in response to a creature you can see within 30 feet of you making an attack roll',
        range: '30 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You trace a shimmering ward in the air. The target creature subtracts 1d4 from the triggering attack roll and any attack rolls it makes against you or other creatures while the spell lasts.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_guidance',
      name: 'Guidance',
      level: 0,
      school: SpellSchool.divination,
      isChangedIn2024: true,
      diffSummary: 'Now cast as a Reaction within 30 feet when an ally fails an ability check, instead of pre-casting via Touch as an Action.',
      diffHighlights: [
        '2014: 1 Action, Touch, Concentration up to 1 min. Target adds 1d4 to one ability check of its choice before the spell ends.',
        '2024: 1 Reaction (or Action), Range 30 ft, Concentration up to 1 min. Can be triggered when a creature fails an ability check to add 1d4 potentially turning failure into success. Once used, a creature is immune for 1 hour.',
      ],
      tags: ['support', 'buff', 'ability check', 'reaction', 'cantrip'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.cleric, SpellClass.druid, SpellClass.artificer],
        description: [
          'You touch one willing creature. Once before the spell ends, the target can roll a d4 and add the number rolled to one ability check of its choice.',
          'It can roll the die before or after making the ability check. The spell then ends.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Reaction, which you take when a creature you can see within 30 feet of you fails an ability check',
        range: '30 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.cleric, SpellClass.druid, SpellClass.artificer],
        description: [
          'You channel divine guidance to aid a creature. The target rolls 1d4 and adds the number rolled to the check, potentially turning failure into success.',
          'A creature can benefit from this spell only once per hour.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_friends',
      name: 'Friends',
      level: 0,
      school: SpellSchool.enchantment,
      isChangedIn2024: true,
      diffSummary: 'No longer causes the target to automatically become hostile after the duration expires.',
      diffHighlights: [
        '2014: Gives advantage on Charisma checks against one non-hostile creature. When the spell ends, the creature realizes it was magically influenced and becomes hostile.',
        '2024: Target makes a Wisdom save; on failure, target gains the Charmed condition for the duration. When it ends, target does not automatically become hostile unless provoked.',
      ],
      tags: ['social', 'charm', 'enchantment', 'cantrip'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self',
        components: 'S, M (a amount of makeup applied to the face as this spell is cast)',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        description: [
          'For the duration, you have advantage on all Charisma checks directed at one creature of your choice that isn’t hostile toward you.',
          'When the spell ends, the creature realizes that you used magic to influence its mood and becomes hostile toward you. A creature prone to violence might attack you.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '10 feet',
        components: 'S, M (a piece of makeup)',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        savingThrow: 'Wisdom',
        description: [
          'One creature of your choice within range must make a Wisdom saving throw. On a failed save, the target has the Charmed condition for the duration.',
          'While charmed, the target is friendly to you and regards you as a trusted friend. When the spell ends, the creature knows you charmed it, but does not automatically become violent.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_shocking_grasp',
      name: 'Shocking Grasp',
      level: 0,
      school: SpellSchool.evocation,
      isChangedIn2024: true,
      diffSummary: 'Removes the target’s ability to make Opportunity Attacks instead of completely stripping all Reactions.',
      diffHighlights: [
        '2014: On hit, target takes 1d8 lightning damage and CANNOT TAKE REACTIONS until the start of its next turn. Advantage if target is wearing armor made of metal.',
        '2024: On hit, target takes 1d8 lightning damage and CANNOT MAKE OPPORTUNITY ATTACKS until the start of its next turn. Gives tactical disengage while preserving non-opportunity reactions like Counterspell or Shield.',
      ],
      tags: ['melee', 'lightning', 'reaction-denial', 'cantrip', 'evocation'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.artificer, SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '1d8',
        damageOrHealType: 'Lightning',
        description: [
          'Lightning springs from your hand to deliver a shock to a creature you try to touch. Make a melee spell attack against the target. You have advantage on the attack roll if the target is wearing armor made of metal.',
          'On a hit, the target takes 1d8 lightning damage, and it can’t take reactions until the start of its next turn.',
          'Cantrip Upgrade: Damage increases by 1d8 at 5th, 11th, and 17th levels.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.artificer, SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '1d8',
        damageOrHealType: 'Lightning',
        description: [
          'Lightning springs from your hand to deliver a shock. Make a melee spell attack against the target. You have Advantage if the target is wearing metal armor.',
          'On a hit, the target takes 1d8 Lightning damage, and it can’t make Opportunity Attacks until the start of its next turn.',
          'Cantrip Upgrade: Damage increases by 1d8 at 5th (2d8), 11th (3d8), and 17th (4d8) levels.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_eldritch_blast',
      name: 'Eldritch Blast',
      level: 0,
      school: SpellSchool.evocation,
      isChangedIn2024: false,
      diffSummary: 'Remains the staple 1d10 force damage cantrip with scaling beam count at 5th, 11th, and 17th levels.',
      tags: ['force', 'ranged', 'beams', 'cantrip', 'warlock'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.warlock],
        rollFormula: '1d10',
        damageOrHealType: 'Force',
        description: [
          'A beam of crackling energy streaks toward a creature within range. Make a ranged spell attack against the target. On a hit, the target takes 1d10 force damage.',
          'The spell creates more than one beam when you reach higher levels: two beams at 5th level, three beams at 11th level, and four beams at 17th level.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.warlock],
        rollFormula: '1d10',
        damageOrHealType: 'Force',
        description: [
          'A beam of crackling energy streaks toward a creature within range. Make a ranged spell attack against the target. On a hit, the target takes 1d10 Force damage.',
          'Cantrip Upgrade: You launch an additional beam at 5th level (2 beams), 11th level (3 beams), and 17th level (4 beams). You can direct the beams at the same target or at different ones.',
        ],
      ),
    ),

    // ---------------------------------------------------------
    // 1ST LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_cure_wounds',
      name: 'Cure Wounds',
      level: 1,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Massive healing buff: Base healing increased from 1d8 + modifier to 2d8 + modifier, scaling by +2d8 per slot level.',
      diffHighlights: [
        '2014: Heals 1d8 + spellcasting ability modifier. +1d8 per slot level above 1st.',
        '2024: Heals 2d8 + spellcasting ability modifier. +2d8 per slot level above 1st.',
        'School shifted to Abjuration in 2024 SRD classification.',
      ],
      tags: ['healing', 'support', 'buffed', 'level 1'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.bard, SpellClass.cleric, SpellClass.druid, SpellClass.paladin, SpellClass.ranger, SpellClass.artificer],
        rollFormula: '1d8 + mod',
        damageOrHealType: 'Healing',
        description: [
          'A creature you touch regains a number of hit points equal to 1d8 + your spellcasting ability modifier.',
          'This spell has no effect on undead or constructs.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 2nd level or higher, the healing increases by 1d8 for each slot level above 1st.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S',
        duration: 'Instantaneous',
        classes: [SpellClass.bard, SpellClass.cleric, SpellClass.druid, SpellClass.paladin, SpellClass.ranger, SpellClass.artificer],
        rollFormula: '2d8 + mod',
        damageOrHealType: 'Healing',
        description: [
          'A creature you touch regains a number of Hit Points equal to 2d8 + your spellcasting ability modifier.',
          'This spell has no effect on Constructs or Undead.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 2nd level or higher, the healing increases by 2d8 for each slot level above 1st.',
      ),
    ),

    SpellItem(
      id: 'spell_healing_word',
      name: 'Healing Word',
      level: 1,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Healing doubled: Base healing increased from 1d4 + modifier to 2d4 + modifier, scaling by +2d4 per slot level.',
      diffHighlights: [
        '2014: Bonus Action, 60 ft range. Heals 1d4 + modifier (+1d4 per slot above 1st).',
        '2024: Bonus Action, 60 ft range. Heals 2d4 + modifier (+2d4 per slot above 1st).',
      ],
      tags: ['healing', 'bonus action', 'ranged', 'buffed', 'level 1'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '60 feet',
        components: 'V',
        duration: 'Instantaneous',
        classes: [SpellClass.bard, SpellClass.cleric, SpellClass.druid],
        rollFormula: '1d4 + mod',
        damageOrHealType: 'Healing',
        description: [
          'A creature of your choice that you can see within range regains hit points equal to 1d4 + your spellcasting ability modifier.',
          'This spell has no effect on undead or constructs.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 2nd level or higher, the healing increases by 1d4 for each slot level above 1st.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '60 feet',
        components: 'V',
        duration: 'Instantaneous',
        classes: [SpellClass.bard, SpellClass.cleric, SpellClass.druid],
        rollFormula: '2d4 + mod',
        damageOrHealType: 'Healing',
        description: [
          'A creature of your choice that you can see within range regains Hit Points equal to 2d4 + your spellcasting ability modifier.',
          'This spell has no effect on Constructs or Undead.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 2nd level or higher, the healing increases by 2d4 for each slot level above 1st.',
      ),
    ),

    SpellItem(
      id: 'spell_divine_smite',
      name: 'Divine Smite',
      level: 1,
      school: SpellSchool.evocation,
      isChangedIn2024: true,
      diffSummary: 'Changed from a free class feature applied on hit into a 1st-level Bonus Action spell with Verbal component.',
      diffHighlights: [
        '2014: Class Feature (not a spell). When you hit with a melee weapon attack, expend a spell slot to deal 2d8 radiant (+1d8 per slot above 1st, +1d8 vs undead/fiends). No action cost, cannot be counterspelled.',
        '2024: 1st-level Spell. Casting time 1 Bonus Action immediately after hitting a target with a melee weapon or unarmed strike. Can be Counterspelled, consumes Bonus Action, prevents casting another level 1+ spell on that turn.',
      ],
      tags: ['paladin', 'smite', 'radiant', 'bonus action', 'nerfed', 'level 1'],
      rules2014: SpellEditionDetails(
        castingTime: 'No Action (Upon hitting with melee weapon)',
        range: 'Self',
        components: 'None',
        duration: 'Instantaneous',
        classes: [SpellClass.paladin],
        rollFormula: '2d8',
        damageOrHealType: 'Radiant',
        description: [
          'Starting at 2nd level, when you hit a creature with a melee weapon attack, you can expend one spell slot to deal radiant damage to the target, in addition to the weapon’s damage.',
          'The extra damage is 2d8 for a 1st-level spell slot, plus 1d8 for each spell level higher than 1st, to a maximum of 5d8. The damage increases by 1d8 if the target is an undead or a fiend, to a maximum of 6d8.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action, which you take immediately after hitting a target with a melee weapon or an Unarmed Strike',
        range: 'Self',
        components: 'V',
        duration: 'Instantaneous',
        classes: [SpellClass.paladin],
        rollFormula: '2d8',
        damageOrHealType: 'Radiant',
        description: [
          'As you strike, your weapon bursts with divine radiance. The target takes an extra 2d8 Radiant damage from the attack.',
          'The damage increases by 1d8 for each slot level above 1st. The extra damage increases by 1d8 if the target is a Fiend or an Undead.',
        ],
        higherLevels: 'Using a higher spell slot increases damage by 1d8 for each slot level above 1st.',
      ),
    ),

    SpellItem(
      id: 'spell_hunters_mark',
      name: "Hunter's Mark",
      level: 1,
      school: SpellSchool.divination,
      isChangedIn2024: true,
      diffSummary: 'Damage changed from weapon-attacks-only to any attack hit, and ranger class features enhance it at higher levels.',
      diffHighlights: [
        '2014: 1 Bonus Action, Concentration (up to 1 hr). Deals 1d6 extra weapon damage when you hit with a weapon attack. Move to new target with Bonus Action when target drops to 0 HP.',
        '2024: 1 Bonus Action, Concentration (up to 1 hr). Deals 1d6 Force damage (or extra damage) whenever you hit the target with ANY attack roll. Directly keyed to Ranger core progression.',
      ],
      tags: ['ranger', 'mark', 'damage', 'tracking', 'level 1'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '90 feet',
        components: 'V',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.ranger],
        rollFormula: '1d6',
        damageOrHealType: 'Weapon Damage',
        description: [
          'You choose a creature you can see within range and mystically mark it as your quarry. Until the spell ends, you deal an extra 1d6 damage to the target whenever you hit it with a weapon attack.',
          'You have advantage on any Wisdom (Perception) or Wisdom (Survival) check you make to find it.',
          'If the target drops to 0 hit points before this spell ends, you can use a bonus action on a subsequent turn to mark a new creature.',
        ],
        higherLevels: 'Slot 3rd-4th: duration up to 8 hours. Slot 5th+: duration up to 24 hours.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '90 feet',
        components: 'V',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.ranger],
        rollFormula: '1d6',
        damageOrHealType: 'Force',
        description: [
          'You mystically mark a creature as your quarry. Until the spell ends, you deal an extra 1d6 Force damage to the target whenever you hit it with an attack roll.',
          'You also have Advantage on any Wisdom (Perception) or Wisdom (Survival) check you make to find the quarry.',
          'If the target drops to 0 Hit Points before the spell ends, you can use a Bonus Action to move the mark to a new creature within range.',
        ],
        higherLevels: 'When cast with a 3rd- or 4th-level slot, duration is up to 8 hours. With a 5th-level slot or higher, duration is up to 24 hours.',
      ),
    ),

    SpellItem(
      id: 'spell_shield',
      name: 'Shield',
      level: 1,
      school: SpellSchool.abjuration,
      isChangedIn2024: false,
      diffSummary: 'Remains the staple +5 AC reaction spell that completely nullifies Magic Missile.',
      tags: ['defense', 'ac', 'reaction', 'abjuration', 'level 1'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Reaction, which you take when you are hit by an attack or targeted by the magic missile spell',
        range: 'Self',
        components: 'V, S',
        duration: '1 round',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        description: [
          'An invisible barrier of magical force appears and protects you.',
          'Until the start of your next turn, you have a +5 bonus to AC, including against the triggering attack, and you take no damage from magic missile.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Reaction, which you take when you are hit by an attack roll or targeted by the Magic Missile spell',
        range: 'Self',
        components: 'V, S',
        duration: '1 round',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        description: [
          'An invisible barrier of magical force appears and protects you.',
          'Until the start of your next turn, you have a +5 bonus to AC, including against the triggering attack, and you take no damage from Magic Missile.',
        ],
      ),
    ),

    // ---------------------------------------------------------
    // 2ND LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_barkskin',
      name: 'Barkskin',
      level: 2,
      school: SpellSchool.transmutation,
      isChangedIn2024: true,
      diffSummary: 'Completely redesigned: Now casts as a Bonus Action and grants temporary hit points each turn instead of setting a minimum AC 16.',
      diffHighlights: [
        '2014: 1 Action, Concentration (1 hr). Target’s AC can’t be less than 16 regardless of armor.',
        '2024: 1 Bonus Action, Concentration (1 hr). Target gains Temporary HP equal to your spellcasting modifier + 10 (and replenishes each round).',
      ],
      tags: ['buff', 'defense', 'temp hp', 'bonus action', 'level 2'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Touch',
        components: 'V, S, M (a handful of oak bark)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        description: [
          'You touch a willing creature. Until the spell ends, the target’s skin has a rough, bark-like appearance, and the target’s AC can’t be less than 16, regardless of what kind of armor it is wearing.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: 'Touch',
        components: 'V, S, M (a handful of oak bark)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        rollFormula: '10 + mod',
        damageOrHealType: 'Temporary HP',
        description: [
          'You touch a willing creature. Until the spell ends, the target’s skin is protected by bark. The target gains Temporary Hit Points equal to 10 + your spellcasting ability modifier.',
          'At the start of each of its turns while the spell lasts, if the target has fewer than that number of Temporary Hit Points, it regains Temporary Hit Points up to that amount.',
        ],
        higherLevels: 'When cast with a 3rd-level or higher slot, the Temporary Hit Points increase by 5 for each slot level above 2nd.',
      ),
    ),

    SpellItem(
      id: 'spell_spiritual_weapon',
      name: 'Spiritual Weapon',
      level: 2,
      school: SpellSchool.evocation,
      isChangedIn2024: true,
      diffSummary: 'Now requires Concentration! No longer allows free non-concentration passive bonus action attacks for 1 minute.',
      diffHighlights: [
        '2014: 1 Bonus Action, 1 minute duration (NO CONCENTRATION). Bonus action to attack each turn for 1d8 + modifier Force damage.',
        '2024: 1 Bonus Action, Concentration (up to 1 minute). Deals 1d8 + modifier Force damage on bonus action attacks.',
      ],
      tags: ['cleric', 'force', 'concentration-added', 'nerfed', 'level 2'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '60 feet',
        components: 'V, S',
        duration: '1 minute',
        concentration: false,
        classes: [SpellClass.cleric],
        rollFormula: '1d8 + mod',
        damageOrHealType: 'Force',
        description: [
          'You create a floating, spectral weapon within range that lasts for the duration or until you cast this spell again. When you cast the spell, you can make a melee spell attack against a creature within 5 feet of the weapon. On a hit, the target takes force damage equal to 1d8 + your spellcasting ability modifier.',
          'As a bonus action on your turn, you can move the weapon up to 20 feet and repeat the attack against a creature within 5 feet of it.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 3rd level or higher, the damage increases by 1d8 for every two slot levels above 2nd.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: '60 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.cleric],
        rollFormula: '1d8 + mod',
        damageOrHealType: 'Force',
        description: [
          'You create a floating, spectral weapon within range that lasts for the duration. When you cast the spell, you can make a melee spell attack against a creature within 5 feet of the weapon. On a hit, the target takes Force damage equal to 1d8 + your spellcasting ability modifier.',
          'As a Bonus Action on subsequent turns, you can move the weapon up to 20 feet and repeat the attack against a creature within 5 feet of it.',
        ],
        higherLevels: 'When cast with a 3rd-level or higher slot, damage increases by 1d8 for every two slot levels above 2nd.',
      ),
    ),

    SpellItem(
      id: 'spell_pass_without_trace',
      name: 'Pass without Trace',
      level: 2,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Changed from a passive +10 Stealth aura into granting Advantage on Stealth checks with a +10 bonus on specific rolls.',
      diffHighlights: [
        '2014: +10 bonus to Dexterity (Stealth) checks for you and companions within 30 ft, cannot be tracked except by magical means.',
        '2024: Clarified interaction with new Hide action mechanics (giving +10 bonus or Advantage depending on conditions).',
      ],
      tags: ['stealth', 'druid', 'ranger', 'concentration', 'level 2'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (30-foot radius)',
        components: 'V, S, M (ashes from a burned leaf of mistletoe and a sprig of spruce)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        description: [
          'A veil of shadows and silence radiates from you, masking you and your companions from detection.',
          'For the duration, each creature you choose within 30 feet of you (including you) has a +10 bonus to Dexterity (Stealth) checks and can’t be tracked except by magical means.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (30-foot radius)',
        components: 'V, S, M (ashes from a burned leaf of mistletoe)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        description: [
          'A veil of shadows and silence radiates from you. For the duration, you and each creature you choose within 30 feet of you gain a +10 bonus to Dexterity (Stealth) checks and leave no tracks or other traces of passage.',
        ],
      ),
    ),

    // ---------------------------------------------------------
    // 3RD LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_counterspell',
      name: 'Counterspell',
      level: 3,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Major redesign: Instead of an ability check vs DC (10 + level), the opposing caster makes a Constitution saving throw. On failure, the spell is wasted.',
      diffHighlights: [
        '2014: Automatic success against 3rd level or lower. For 4th+ level spells, roll an ability check using your spellcasting modifier (DC = 10 + spell’s level).',
        '2024: Target caster makes a Constitution saving throw against your Spell Save DC. On a failure, the spell is interrupted and has no effect, and the spell slot is consumed.',
        'Affects all spell levels equally through the save DC, making High-Constitution enemy bosses harder to counterspell.',
      ],
      tags: ['abjuration', 'reaction', 'counter', 'con-save', 'major-rebalance', 'level 3'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Reaction, which you take when you see a creature within 60 feet of you casting a spell',
        range: '60 feet',
        components: 'S',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You attempt to interrupt a creature in the process of casting a spell. If the creature is casting a spell of 3rd level or lower, its spell fails and has no effect.',
          'If it is casting a spell of 4th level or higher, make an ability check using your spellcasting ability. The DC equals 10 + the spell’s level. On a success, the creature’s spell fails and has no effect.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 4th level or higher, the interrupted spell has no effect if its level is less than or equal to the level of the spell slot you used.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Reaction, which you take when you see a creature within 60 feet of you casting a spell',
        range: '60 feet',
        components: 'S',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        savingThrow: 'Constitution',
        description: [
          'You attempt to interrupt a creature in the process of casting a spell.',
          'The creature must make a Constitution saving throw against your Spell Save DC. On a failed save, the spell is interrupted and has no effect, and the creature’s action or reaction used to cast the spell is wasted along with any spell slot expended.',
        ],
        higherLevels: 'Casting with higher slots does not alter the saving throw DC.',
      ),
    ),

    SpellItem(
      id: 'spell_spirit_guardians',
      name: 'Spirit Guardians',
      level: 3,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Harmonized damage trigger: Damage triggers once per turn when a creature enters or ends its turn in the area, resolving "double-dipping" movement exploits.',
      diffHighlights: [
        '2014: 15 ft emanation, deals 3d8 Radiant/Necrotic on Wisdom save when target enters area or starts turn there.',
        '2024: 15 ft emanation, clarifies once per turn trigger upon entry or end of turn, dealing 3d8 Radiant/Necrotic damage.',
      ],
      tags: ['cleric', 'aoe', 'radiant', 'necrotic', 'concentration', 'level 3'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (15-foot radius)',
        components: 'V, S, M (a holy symbol)',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.cleric],
        rollFormula: '3d8',
        damageOrHealType: 'Radiant or Necrotic',
        savingThrow: 'Wisdom',
        description: [
          'You call forth spirits to protect you. They flit around you to a distance of 15 feet for the duration. When you cast this spell, you can designate any number of creatures you can see to be unaffected by it.',
          'An affected creature’s speed is halved in the area, and when the creature enters the area for the first time on a turn or starts its turn there, it must make a Wisdom saving throw. On a failed save, it takes 3d8 radiant damage (if good or neutral) or 3d8 necrotic damage (if evil). Half damage on success.',
        ],
        higherLevels: 'Slot 4th+: Damage increases by 1d8 for each slot level above 3rd.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (15-foot emanation)',
        components: 'V, S, M (a holy symbol)',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.cleric],
        rollFormula: '3d8',
        damageOrHealType: 'Radiant or Necrotic',
        savingThrow: 'Wisdom',
        description: [
          'Spirits flit around you in a 15-foot Emanation. You designate creatures to be unaffected. An affected creature’s speed is halved within the emanation.',
          'When a creature enters the emanation for the first time on a turn or ends its turn there, it must make a Wisdom saving throw, taking 3d8 Radiant or Necrotic damage on a failure, or half as much on a success (a creature can take this damage only once per turn).',
        ],
        higherLevels: 'Damage increases by 1d8 for each slot level above 3rd.',
      ),
    ),

    SpellItem(
      id: 'spell_fireball',
      name: 'Fireball',
      level: 3,
      school: SpellSchool.evocation,
      isChangedIn2024: false,
      diffSummary: 'The iconic 8d6 fire AOE remains mechanically identical in 2024 with modernized wording.',
      tags: ['fire', 'aoe', 'damage', 'evocation', 'level 3'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '150 feet',
        components: 'V, S, M (a tiny ball of bat guano and pitch)',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '8d6',
        damageOrHealType: 'Fire',
        savingThrow: 'Dexterity',
        description: [
          'A bright streak flashes from your pointing finger to a point you choose within range and then blossoms with a low roar into an explosion of flame.',
          'Each creature in a 20-foot-radius sphere centered on that point must make a Dexterity saving throw. A target takes 8d6 fire damage on a failed save, or half as much damage on a successful one.',
          'The fire spreads around corners. It ignites flammable objects in the area that aren’t being worn or carried.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 4th level or higher, the damage increases by 1d6 for each slot level above 3rd.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '150 feet',
        components: 'V, S, M (a ball of bat guano and pitch)',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '8d6',
        damageOrHealType: 'Fire',
        savingThrow: 'Dexterity',
        description: [
          'A bright streak flashes from you to a point you choose within range and blossoms into an explosion of flame.',
          'Each creature in a 20-foot-radius Sphere centered on that point must make a Dexterity saving throw. A target takes 8d6 Fire damage on a failed save, or half as much on a successful one.',
          'The fire spreads around corners and ignites flammable objects in the area that aren’t being worn or carried.',
        ],
        higherLevels: 'Damage increases by 1d6 for each slot level above 3rd.',
      ),
    ),

    // ---------------------------------------------------------
    // 4TH LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_polymorph',
      name: 'Polymorph',
      level: 4,
      school: SpellSchool.transmutation,
      isChangedIn2024: true,
      diffSummary: 'Changed from giving a fresh full pool of Beast HP into giving Temporary Hit Points based on the new form.',
      diffHighlights: [
        '2014: Target takes on the beast’s full HP. Damage dealt first reduces the beast’s HP; excess damage carries over to the original form. Acted as a massive second health bar.',
        '2024: Target gains Temporary Hit Points equal to the Beast form’s HP. When those temporary HP run out or the spell ends, the form reverts.',
      ],
      tags: ['transmutation', 'beast', 'temp-hp', 'major-rebalance', 'level 4'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (a caterpillar cocoon)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.druid, SpellClass.sorcerer, SpellClass.wizard],
        savingThrow: 'Wisdom',
        description: [
          'This spell transforms a creature with at least 1 hit point that you can see within range into a new form.',
          'An unwilling creature must make a Wisdom saving throw to avoid the effect.',
          'The transformation lasts for the duration, or until the target drops to 0 hit points or dies. The new form can be any beast whose challenge rating is equal to or less than the target’s CR/level.',
          'The target assumes the hit points of its new form. When it reverts to its normal form, the creature returns to the number of hit points it had before it transformed.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (a caterpillar cocoon)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.bard, SpellClass.druid, SpellClass.sorcerer, SpellClass.wizard],
        savingThrow: 'Wisdom',
        description: [
          'This spell transforms a creature you can see within range into a Beast of equal or lower Challenge Rating.',
          'An unwilling creature must make a Wisdom saving throw to resist.',
          'The target gains Temporary Hit Points equal to the Beast form’s Hit Points. When the Temporary Hit Points drop to 0, the spell ends and the creature reverts to its true form.',
        ],
      ),
    ),

    SpellItem(
      id: 'spell_banishment',
      name: 'Banishment',
      level: 4,
      school: SpellSchool.abjuration,
      isChangedIn2024: true,
      diffSummary: 'Banished creatures now get a repeated saving throw at the end of each of their turns, preventing single-failed-save permanent combat removals.',
      diffHighlights: [
        '2014: Single Charisma save. If failed, banished for full 1-minute concentration. If native to another plane and spell lasts full minute, permanently banished.',
        '2024: Banished target can repeat the Charisma saving throw at the end of each of its turns, ending the spell early on a success.',
      ],
      tags: ['abjuration', 'banish', 'charisma-save', 'concentration', 'level 4'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (an item distasteful to the target)',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.cleric, SpellClass.paladin, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        savingThrow: 'Charisma',
        description: [
          'You attempt to send one creature that you can see within range to another plane of existence. The target must succeed on a Charisma saving throw or be banished.',
          'If the target is native to the plane of existence you’re on, you banish the target to a harmless demiplane. While there, the target is incapacitated. The target remains there until the spell ends, at which point the target reappears in the space it left.',
          'If the target is native to a different plane of existence, it is banished there. If the spell lasts for its full duration, the target doesn’t return.',
        ],
        higherLevels: 'Target one additional creature for each slot level above 4th.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (an item distasteful to the target)',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.cleric, SpellClass.paladin, SpellClass.sorcerer, SpellClass.warlock, SpellClass.wizard],
        savingThrow: 'Charisma',
        description: [
          'You attempt to send one creature within range to another plane of existence. The target must make a Charisma saving throw or be banished.',
          'While banished, the target is Incapacitated. At the end of each of its turns, the target can repeat the save, ending the spell on a success.',
          'If the spell lasts the full 1 minute and the creature is not native to this plane, it remains on its home plane.',
        ],
        higherLevels: 'Target one additional creature for each slot level above 4th.',
      ),
    ),

    // ---------------------------------------------------------
    // 5TH LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_cloudkill',
      name: 'Cloudkill',
      level: 5,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Harmonized damage trigger once per turn when entering or ending turn in toxic fog.',
      tags: ['poison', 'fog', 'aoe', 'concentration', 'level 5'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '5d8',
        damageOrHealType: 'Poison',
        savingThrow: 'Constitution',
        description: [
          'You create a 20-foot-radius sphere of poisonous, yellow-green fog centered on a point you choose within range.',
          'The fog moves 10 feet away from you at the start of each of your turns.',
          'When a creature enters the spell’s area for the first time on a turn or starts its turn there, it must make a Constitution saving throw, taking 5d8 poison damage on a failed save, or half as much on a successful one.',
        ],
        higherLevels: 'Damage increases by 1d8 for each slot level above 5th.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '5d8',
        damageOrHealType: 'Poison',
        savingThrow: 'Constitution',
        description: [
          'You create a 20-foot-radius Sphere of poisonous yellow-green fog. The fog moves 10 feet away from you at the start of each of your turns.',
          'When a creature enters the area for the first time on a turn or ends its turn there, it must make a Constitution saving throw, taking 5d8 Poison damage on a failed save, or half as much on a success (damage applies once per turn).',
        ],
        higherLevels: 'Damage increases by 1d8 for each slot level above 5th.',
      ),
    ),

    // ---------------------------------------------------------
    // SUMMON & MINION COMPANION SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_conjure_animals',
      name: 'Conjure Animals',
      level: 3,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Complete redesign: No longer summons 1-8 individual creature tokens that flood combat initiative. Now creates a 10-ft spiritual pack emanation that deals 3d10 radiant damage on Dexterity save and grants advantage on Opportunity Attacks.',
      diffHighlights: [
        '2014: 1 Action, 60 ft, Concentration (1 hr). Summons 1-8 physical beast stat blocks (e.g. 8 wolves/velociraptors with Pack Tactics) rolling separate initiatives.',
        '2024: 1 Action, 60 ft (10-ft emanation), Concentration (10 min). Summons spectral nature spirits that move with you or to a point. Deals 3d10 Radiant damage on failed Dex save (+1d10 per slot above 3rd). Prevents initiative clutter.',
      ],
      tags: ['summon', 'beasts', 'druid', 'ranger', 'emanation', 'redesign', 'level 3'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        rollFormula: '2d4',
        damageOrHealType: 'Beast Minions',
        description: [
          'You summon fey spirits that take the form of beasts and appear in unoccupied spaces that you can see within range.',
          'Choose one of the following options: One beast of CR 2 or lower, Two beasts of CR 1 or lower, Four beasts of CR 1/2 or lower, or Eight beasts of CR 1/4 or lower.',
          'Each beast is considered fey, and it disappears when it drops to 0 hit points or when the spell ends. The summoned creatures are friendly to you and your companions, roll initiative as a group, and obey verbal commands.',
        ],
        higherLevels: 'Slot 5th: twice the creatures. Slot 7th: three times the creatures. Slot 9th: four times the creatures.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet (10-foot emanation)',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        rollFormula: '3d10',
        damageOrHealType: 'Radiant',
        savingThrow: 'Dexterity',
        description: [
          'You summon spirits of nature that take the form of a pack of spectral animals in a 10-foot-radius Emanation centered on a point you choose within range.',
          'When the emanation appears and whenever a creature hostile to you enters the area for the first time on a turn or ends its turn there, it must make a Dexterity saving throw, taking 3d10 Radiant damage on a failure, or half as much on a success.',
          'Once on your turn, you can move the spirits up to 30 feet to an unoccupied space within range as a Bonus Action.',
        ],
        higherLevels: 'When cast using a 4th-level slot or higher, damage increases by 1d10 for each slot level above 3rd.',
      ),
    ),

    SpellItem(
      id: 'spell_animate_dead',
      name: 'Animate Dead',
      level: 3,
      school: SpellSchool.necromancy,
      isChangedIn2024: false,
      diffSummary: 'Classic necromancy spell that creates a Skeleton or Zombie servant from a pile of bones or corpse for 24 hours.',
      tags: ['undead', 'skeleton', 'zombie', 'necromancy', 'minion', 'level 3'],
      rules2014: SpellEditionDetails(
        castingTime: '1 minute',
        range: '10 feet',
        components: 'V, S, M (a drop of blood, a piece of flesh, and a pinch of bone dust)',
        duration: 'Instantaneous (24 hours control)',
        classes: [SpellClass.cleric, SpellClass.wizard],
        description: [
          'This spell creates an undead servant. Choose a pile of bones or a corpse of a Medium or Small humanoid within range.',
          'Your spell imbues the target with a foul mimicry of life, raising it as an undead creature (a skeleton if bones, or a zombie if corpse).',
          'On each of your turns, you can use a bonus action to mentally command any creature you made with this spell if the creature is within 60 feet of you. The creature is under your control for 24 hours, after which you must cast this spell again to reassert control.',
        ],
        higherLevels: 'When you cast this spell using a spell slot of 4th level or higher, you animate or assert control over two additional undead creatures for each slot level above 3rd.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 minute',
        range: '10 feet',
        components: 'V, S, M (a drop of blood, flesh, and bone dust)',
        duration: 'Instantaneous (24 hours control)',
        classes: [SpellClass.cleric, SpellClass.wizard],
        description: [
          'This spell creates an undead servant. Choose a pile of bones or a corpse of a Medium or Small humanoid within range.',
          'The spell raises it as a Skeleton (from bones) or Zombie (from corpse).',
          'You can use a Bonus Action to mentally command the creature if it is within 60 feet. Control lasts 24 hours before reassertion is required.',
        ],
        higherLevels: 'Cast with a 4th-level slot or higher to animate or reassert control over two additional undead per slot level above 3rd.',
      ),
    ),

    SpellItem(
      id: 'spell_conjure_minor_elementals',
      name: 'Conjure Minor Elementals',
      level: 4,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Complete redesign: Instead of summoning 1-8 small elementals (like Mephits), it creates a personal elemental shroud that adds 2d8 elemental damage to all your attacks (+2d8 per upcast slot).',
      diffHighlights: [
        '2014: 1 minute casting time, Concentration (1 hr). Summons 1-8 minor elementals (e.g. 8 steam mephits).',
        '2024: 1 Action casting time, Concentration (10 min). Creates a 15-ft emanation of swirling spirits around you. Whenever you hit with an attack roll, you deal an extra 2d8 damage of chosen elemental type (+2d8 per slot level above 4th).',
      ],
      tags: ['elemental', 'buff', 'emanation', 'redesign', 'level 4'],
      rules2014: SpellEditionDetails(
        castingTime: '1 minute',
        range: '90 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.wizard],
        description: [
          'You summon elementals that appear in unoccupied spaces that you can see within range.',
          'Choose one option: One elemental of CR 2 or lower, Two elementals of CR 1 or lower, Four elementals of CR 1/2 or lower, or Eight elementals of CR 1/4 or lower.',
          'An elemental summoned by this spell disappears when it drops to 0 hit points or when the spell ends.',
        ],
        higherLevels: 'Slot 6th: twice the creatures. Slot 8th: three times the creatures.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (15-foot emanation)',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.wizard],
        rollFormula: '2d8',
        damageOrHealType: 'Acid, Cold, Fire, or Lightning',
        description: [
          'You summon spirits of nature that flit around you in a 15-foot Emanation.',
          'Until the spell ends, any attack roll you make deals an extra 2d8 damage of a type chosen from Acid, Cold, Fire, or Lightning on a hit.',
          'The area within the emanation is also Difficult Terrain for your enemies.',
        ],
        higherLevels: 'When cast using a 5th-level slot or higher, the extra damage increases by 2d8 for each slot level above 4th.',
      ),
    ),

    SpellItem(
      id: 'spell_conjure_woodland_beings',
      name: 'Conjure Woodland Beings',
      level: 4,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Complete redesign: Replaces the 8-Pixie polymorph army exploit with a 10-ft aura dealing 5d8 force/radiant damage and enabling Disengage.',
      diffHighlights: [
        '2014: 1 Action, Concentration (1 hr). Summons 1-8 fey creatures (CR 2 down to 8 Pixies with individual spell slots).',
        '2024: 1 Action, Concentration (10 min). Creates a 10-ft emanation that deals 5d8 Force damage on failed Wisdom save (+1d8 per slot level above 4th) and lets you Disengage as a Bonus Action.',
      ],
      tags: ['fey', 'emanation', 'druid', 'ranger', 'redesign', 'level 4'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (one holly berry per creature summoned)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        description: [
          'You summon fey creatures that appear in unoccupied spaces that you can see within range.',
          'Choose one option: One fey creature of CR 2 or lower, Two fey of CR 1 or lower, Four fey of CR 1/2 or lower, or Eight fey of CR 1/4 or lower.',
          'Summoned creatures obey your verbal commands.',
        ],
        higherLevels: 'Slot 6th: twice the creatures. Slot 8th: three times the creatures.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self (10-foot emanation)',
        components: 'V, S, M (a sprig of holly)',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.ranger],
        rollFormula: '5d8',
        damageOrHealType: 'Force',
        savingThrow: 'Wisdom',
        description: [
          'You summon fey spirits that flit around you in a 10-foot Emanation.',
          'When a creature hostile to you enters the emanation for the first time on a turn or ends its turn there, it must make a Wisdom saving throw, taking 5d8 Force damage on a failed save, or half as much on a successful one.',
          'You can also take the Disengage action as a Bonus Action while the spell is active.',
        ],
        higherLevels: 'Damage increases by 1d8 for each slot level above 4th.',
      ),
    ),

    SpellItem(
      id: 'spell_giant_insect',
      name: 'Giant Insect',
      level: 4,
      school: SpellSchool.transmutation,
      isChangedIn2024: true,
      diffSummary: 'Standardized into a single versatile Giant Insect companion stat block with customizable traits (Centipede, Spider, Wasp, Scorpion).',
      tags: ['insect', 'transmutation', 'druid', 'level 4'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '30 feet',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid],
        description: [
          'You transform up to ten centipedes, three spiders, five wasps, or one scorpion within range into giant versions of their natural forms.',
          'A centipede becomes a giant centipede, a spider becomes a giant spider, a wasp becomes a giant wasp, and a scorpion becomes a giant scorpion.',
          'The DM will have the statistics for these creatures and resolves their actions and movements.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '30 feet',
        components: 'V, S',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid],
        description: [
          'You transform an insect within range into a Large Giant Insect.',
          'The creature uses the Giant Insect stat block and takes on traits of a Centipede, Spider, Wasp, or Scorpion.',
          'It is friendly to you and obeys your verbal commands.',
        ],
        higherLevels: 'Using higher spell slots increases the creature’s AC, HP, and damage bonuses.',
      ),
    ),

    SpellItem(
      id: 'spell_animate_objects',
      name: 'Animate Objects',
      level: 5,
      school: SpellSchool.transmutation,
      isChangedIn2024: true,
      diffSummary: 'Standardized into a single Animated Object swarm/companion stat block with customizable sizes and attacks, reducing 10 separate attack rolls to streamlined action economy.',
      diffHighlights: [
        '2014: Animates up to 10 separate non-magical objects (Tiny to Huge) with individual HP pools, making up to 10 separate attack rolls (+8 to hit, 1d4+4 each).',
        '2024: Creates animated object constructs using modernized scaling mechanics to preserve high damage without slowing down table turns.',
      ],
      tags: ['construct', 'transmutation', 'objects', 'artificer', 'bard', 'sorcerer', 'wizard', 'level 5'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.artificer, SpellClass.bard, SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '1d4 + 4',
        damageOrHealType: 'Bludgeoning',
        description: [
          'Objects come to life at your command. Choose up to ten nonmagical objects within range that are not being worn or carried.',
          'Medium targets count as two objects, Large targets count as four objects, Huge targets count as eight objects.',
          'Each animated object is a construct with statistics determined by its size (Tiny AC 18 HP 20, Small AC 16 HP 25, Medium AC 13 HP 40, Large AC 10 HP 50, Huge AC 10 HP 80).',
          'As a bonus action, you can mentally command any object you made with this spell.',
        ],
        higherLevels: 'If you cast this spell using a spell slot of 6th level or higher, you can animate two additional objects for each slot level above 5th.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '120 feet',
        components: 'V, S',
        duration: 'Concentration, up to 1 minute',
        concentration: true,
        classes: [SpellClass.artificer, SpellClass.bard, SpellClass.sorcerer, SpellClass.wizard],
        rollFormula: '1d4 + 4',
        damageOrHealType: 'Bludgeoning',
        description: [
          'You bring objects to life within range.',
          'Choose up to 10 Tiny or Small nonmagical objects (or equivalent Medium, Large, or Huge budget).',
          'The objects gain the statistics and traits of Animated Objects and attack at your command.',
        ],
        higherLevels: 'You can animate 2 additional objects per slot level above 5th.',
      ),
    ),

    SpellItem(
      id: 'spell_conjure_elemental',
      name: 'Conjure Elemental',
      level: 5,
      school: SpellSchool.conjuration,
      isChangedIn2024: true,
      diffSummary: 'Casting time reduced from 1 minute to 1 Action! Removes the catastrophic concentration failure where elementals turn uncontrollably hostile.',
      diffHighlights: [
        '2014: 1 minute casting time. Summons an Elemental of CR 5 (Air, Earth, Fire, or Water). If your concentration is broken, the elemental does NOT disappear; it becomes hostile to you and your companions.',
        '2024: 1 Action casting time. Summons an elemental spirit that remains cooperative and disappears when concentration ends.',
      ],
      tags: ['elemental', 'conjuration', 'druid', 'wizard', 'level 5'],
      rules2014: SpellEditionDetails(
        castingTime: '1 minute',
        range: '90 feet',
        components: 'V, S, M (burning incense for air, soft clay for earth, sulfur for fire, or water in a bowl)',
        duration: 'Concentration, up to 1 hour',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.wizard],
        description: [
          'You call forth an elemental servant. Choose an area of air, earth, fire, or water that fills a 10-foot cube within range. An elemental of challenge rating 5 or lower appropriate to the element you chose appears in an unoccupied space within 10 feet of it.',
          'If your concentration is broken, the elemental doesn’t disappear. Instead, you lose control of the elemental, it becomes hostile toward you and your companions, and it might attack.',
        ],
        higherLevels: 'Slot 6th or higher: CR increases by 1 for each slot level above 5th.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V, S, M (an elemental offering)',
        duration: 'Concentration, up to 10 minutes',
        concentration: true,
        classes: [SpellClass.druid, SpellClass.wizard],
        description: [
          'You call forth an elemental servant in an unoccupied space within range.',
          'The elemental is friendly to you and your companions and disappears when the spell ends.',
        ],
        higherLevels: 'When cast using higher spell slots, elemental attributes and challenge rating scale accordingly.',
      ),
    ),

    SpellItem(
      id: 'spell_create_undead',
      name: 'Create Undead',
      level: 6,
      school: SpellSchool.necromancy,
      isChangedIn2024: false,
      diffSummary: 'High-tier necromancy: Animates 3 Ghouls (or Ghasts, Wights, and Mummies with higher spell slots) for 24 hours.',
      tags: ['undead', 'ghoul', 'ghast', 'wight', 'mummy', 'necromancy', 'level 6'],
      rules2014: SpellEditionDetails(
        castingTime: '1 minute',
        range: '10 feet',
        components: 'V, S, M (one clay pot filled with grave dirt, one clay pot filled with brackish water, and 150 gp black onyx per corpse)',
        duration: 'Instantaneous (24 hours control)',
        classes: [SpellClass.cleric, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You can cast this spell only at night. Choose up to three corpses of Medium or Small humanoids within range.',
          'Each corpse becomes a ghoul under your control.',
          'As a bonus action on each of your turns, you can mentally command any creature you animated with this spell if within 120 feet.',
        ],
        higherLevels: 'Slot 7th: 4 Ghouls. Slot 8th: 5 Ghouls or 2 Ghasts/Wights. Slot 9th: 6 Ghouls, 3 Ghasts/Wights, or 2 Mummies.',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 minute',
        range: '10 feet',
        components: 'V, S, M (grave dirt, brackish water, and black onyx worth 150+ gp per corpse)',
        duration: 'Instantaneous (24 hours control)',
        classes: [SpellClass.cleric, SpellClass.warlock, SpellClass.wizard],
        description: [
          'You animate up to three Medium or Small corpses into Ghouls under your mental command.',
          'Control lasts 24 hours before reassertion is required.',
        ],
        higherLevels: 'Slot 7th: 4 Ghouls. Slot 8th: 5 Ghouls or 2 Ghasts/Wights. Slot 9th: 6 Ghouls, 3 Ghasts/Wights, or 2 Mummies.',
      ),
    ),

    // ---------------------------------------------------------
    // 9TH LEVEL SPELLS
    // ---------------------------------------------------------
    SpellItem(
      id: 'spell_wish',
      name: 'Wish',
      level: 9,
      school: SpellSchool.conjuration,
      isChangedIn2024: false,
      diffSummary: 'The pinnacle of mortal magic: Duplicates any spell of 8th level or lower with no components or costs, or produces reality-altering custom effects with severe stress.',
      tags: ['ultimate', 'duplicate', 'reality-warping', 'level 9'],
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self',
        components: 'V',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        description: [
          'Wish is the mightiest spell a mortal creature can cast. By simply speaking aloud, you can alter the very foundations of reality in accord with your desires.',
          'The basic use of this spell is to duplicate any other spell of 8th level or lower. You don’t need to meet any requirements in that spell, including costly components. The spell simply takes effect.',
          'Alternatively, you can create other effects (create an object up to 25,000 gp, allow 20 creatures to recover all HP, grant 10 creatures resistance, etc.). The stress of casting this for non-spell duplication causes strength drop to 3 for 2d4 days, necrotic damage on subsequent casting, and a 33 percent chance you can never cast Wish again.',
        ],
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: 'Self',
        components: 'V',
        duration: 'Instantaneous',
        classes: [SpellClass.sorcerer, SpellClass.wizard],
        description: [
          'Wish is the mightiest spell a mortal creature can cast.',
          'The basic use of this spell is to duplicate any other spell of level 8 or lower. You don’t need to meet any requirements in that spell, including costly components. The spell simply takes effect.',
          'Alternatively, you can produce other powerful effects with the stress penalty (Strength drops to 3 for 2d4 days, 1d10 Necrotic damage per spell level when casting until long rest, and a 33% chance of never being able to cast Wish again).',
        ],
      ),
    ),
  ];

  static SpellItem? getSpellById(String id) {
    try {
      return allSpells.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<SpellItem> getChangedSpells() {
    return allSpells.where((s) => s.isChangedIn2024).toList();
  }

  static List<SpellItem> getSpellsByLevel(int level) {
    return allSpells.where((s) => s.level == level).toList();
  }

  static List<SpellItem> getSpellsByClass(SpellClass cls, {DmRulesEdition edition = DmRulesEdition.v2024}) {
    return allSpells.where((s) => s.getRules(edition).classes.contains(cls)).toList();
  }
}
