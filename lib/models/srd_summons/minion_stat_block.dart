import 'package:flutter/material.dart';

enum SummonCategory { spell, magicItem }

class CreatureTrait {
  final String name;
  final String description;

  const CreatureTrait({
    required this.name,
    required this.description,
  });
}

class CreatureAction {
  final String name;
  final String description;
  final String? attackType; // e.g. "Melee Weapon Attack"
  final int? attackBonus;
  final String? reach; // e.g. "reach 5 ft." or "range 20/60 ft."
  final String? hitDamage; // e.g. "7 (1d8 + 3) piercing damage"

  const CreatureAction({
    required this.name,
    required this.description,
    this.attackType,
    this.attackBonus,
    this.reach,
    this.hitDamage,
  });
}

class MinionStatBlock {
  final String id;
  final String name;
  final String sizeDisplay;
  final String crDisplay;
  final String typeDisplay; // e.g. "Beast", "Undead", "Elemental", "Construct"
  final String alignment;   // e.g. "unaligned", "lawful evil", "neutral"
  final int ac;
  final String? armorType;  // e.g. "natural armor", "leather armor"
  final int maxHp;
  final String? hitDice;    // e.g. "2d8 + 2"
  final String speed;       // e.g. "40 ft., climb 30 ft."
  final int strScore;
  final int dexScore;
  final int conScore;
  final int intScore;
  final int wisScore;
  final int chaScore;
  final String? savingThrows;
  final String? skills;
  final String? damageVulnerabilities;
  final String? damageResistances;
  final String? damageImmunities;
  final String? conditionImmunities;
  final String senses;
  final String languages;
  final int? xp;
  final List<CreatureTrait> traits;
  final List<CreatureAction> actions;
  final List<CreatureAction> reactions;

  // Rapid Batch Dice Roller Fields
  final int attackBonus;
  final int damageDiceCount;
  final int damageDiceSides;
  final int damageBonus;
  final String damageType;
  final int secondaryDamageDiceCount;
  final int secondaryDamageDiceSides;
  final String? secondaryDamageType;
  final bool hasPackTactics;
  final String? specialTrait;
  final Color accentColor;

  const MinionStatBlock({
    required this.id,
    required this.name,
    required this.sizeDisplay,
    required this.crDisplay,
    this.typeDisplay = 'Beast',
    this.alignment = 'unaligned',
    required this.ac,
    this.armorType,
    required this.maxHp,
    this.hitDice,
    this.speed = '30 ft.',
    this.strScore = 10,
    this.dexScore = 10,
    this.conScore = 10,
    this.intScore = 10,
    this.wisScore = 10,
    this.chaScore = 10,
    this.savingThrows,
    this.skills,
    this.damageVulnerabilities,
    this.damageResistances,
    this.damageImmunities,
    this.conditionImmunities,
    this.senses = 'passive Perception 10',
    this.languages = '—',
    this.xp,
    this.traits = const [],
    this.actions = const [],
    this.reactions = const [],
    required this.attackBonus,
    required this.damageDiceCount,
    required this.damageDiceSides,
    required this.damageBonus,
    required this.damageType,
    this.secondaryDamageDiceCount = 0,
    this.secondaryDamageDiceSides = 0,
    this.secondaryDamageType,
    this.hasPackTactics = false,
    this.specialTrait,
    this.accentColor = const Color(0xFF673AB7),
  });

  // Ability Score Modifiers
  static int calcModifier(int score) => ((score - 10) / 2).floor();

  int get strMod => calcModifier(strScore);
  int get dexMod => calcModifier(dexScore);
  int get conMod => calcModifier(conScore);
  int get intMod => calcModifier(intScore);
  int get wisMod => calcModifier(wisScore);
  int get chaMod => calcModifier(chaScore);

  static String formatMod(int mod) => mod >= 0 ? '+$mod' : '$mod';

  String get primaryDamageFormula =>
      '${damageDiceCount}d$damageDiceSides${damageBonus >= 0 ? "+$damageBonus" : "$damageBonus"}';

  String get fullDamageFormula {
    if (secondaryDamageDiceCount > 0 && secondaryDamageType != null) {
      return '$primaryDamageFormula $damageType + ${secondaryDamageDiceCount}d$secondaryDamageDiceSides $secondaryDamageType';
    }
    return '$primaryDamageFormula $damageType';
  }
}
