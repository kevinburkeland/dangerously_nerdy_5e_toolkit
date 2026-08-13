import 'package:flutter/material.dart';

enum SummonCategory { spell, magicItem }

class MinionStatBlock {
  final String id;
  final String name;
  final String sizeDisplay;
  final String crDisplay;
  final int ac;
  final int maxHp;
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
    required this.ac,
    required this.maxHp,
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

  String get primaryDamageFormula => '${damageDiceCount}d$damageDiceSides${damageBonus >= 0 ? "+$damageBonus" : "$damageBonus"}';

  String get fullDamageFormula {
    if (secondaryDamageDiceCount > 0 && secondaryDamageType != null) {
      return '$primaryDamageFormula $damageType + ${secondaryDamageDiceCount}d$secondaryDamageDiceSides $secondaryDamageType';
    }
    return '$primaryDamageFormula $damageType';
  }
}
