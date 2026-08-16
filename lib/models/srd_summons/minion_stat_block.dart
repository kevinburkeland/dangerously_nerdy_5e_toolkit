import 'package:flutter/material.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';
import '../../utils/dice_formatters.dart';
import '../../widgets/glyphs/glyph_tokens.dart';

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

  int get strMod => strScore.dndModifier;
  int get dexMod => dexScore.dndModifier;
  int get conMod => conScore.dndModifier;
  int get intMod => intScore.dndModifier;
  int get wisMod => wisScore.dndModifier;
  int get chaMod => chaScore.dndModifier;

  String get primaryDamageFormula => DiceFormatters.formatFormula(
        count: damageDiceCount,
        sides: damageDiceSides,
        bonus: damageBonus,
      );

  String get fullDamageFormula => DiceFormatters.formatCompositeFormula(
        primaryCount: damageDiceCount,
        primarySides: damageDiceSides,
        primaryBonus: damageBonus,
        primaryDamageType: damageType,
        secondaryCount: secondaryDamageDiceCount,
        secondarySides: secondaryDamageDiceSides,
        secondaryDamageType: secondaryDamageType,
      );
}

/// Helper extension mapping MinionStatBlock to DndGlyph parameters.
extension MinionStatBlockGlyphExt on MinionStatBlock {
  CreatureType get glyphCreatureType {
    final lower = typeDisplay.toLowerCase();
    if (lower.contains('beast')) return CreatureType.beast;
    if (lower.contains('undead')) return CreatureType.undead;
    if (lower.contains('elemental')) return CreatureType.elemental;
    if (lower.contains('construct')) return CreatureType.construct;
    if (lower.contains('monstrosity')) return CreatureType.monstrosity;
    if (lower.contains('plant')) return CreatureType.plant;
    if (lower.contains('humanoid')) return CreatureType.humanoid;
    if (lower.contains('dragon')) return CreatureType.dragon;
    if (lower.contains('fiend')) return CreatureType.fiend;
    if (lower.contains('celestial')) return CreatureType.celestial;
    if (lower.contains('fey')) return CreatureType.fey;
    if (lower.contains('giant')) return CreatureType.giant;
    if (lower.contains('ooze')) return CreatureType.ooze;
    if (lower.contains('aberration')) return CreatureType.aberration;
    return CreatureType.beast;
  }

  int get glyphCrTier {
    if (crDisplay.contains('/') || crDisplay == '0' || crDisplay == '1' || crDisplay == '2' || crDisplay == '3' || crDisplay == '4') {
      return 1;
    }
    final num = int.tryParse(crDisplay) ?? 1;
    if (num <= 4) return 1;
    if (num <= 10) return 2;
    if (num <= 16) return 3;
    return 4;
  }

  List<ActionTraitRing> get glyphActionRings {
    final rings = <ActionTraitRing>[];
    final dmgAccent = _mapDamageType(damageType);

    bool hasMelee = false;
    bool hasRanged = false;
    bool hasRecharge = false;

    for (final act in actions) {
      final actLower = (act.attackType ?? '').toLowerCase() + (act.description).toLowerCase();
      if (actLower.contains('melee') || actLower.contains('reach')) {
        hasMelee = true;
      }
      if (actLower.contains('ranged') || actLower.contains('range') || actLower.contains('bow') || actLower.contains('web')) {
        hasRanged = true;
      }
      if (actLower.contains('recharge') || actLower.contains('breath')) {
        hasRecharge = true;
      }
    }

    if (reactions.isNotEmpty) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.reaction));
    }

    if (hasRecharge) {
      rings.add(ActionTraitRing(ringType: ActionRingType.recharge, damageType: dmgAccent));
    }

    if (hasMelee) {
      rings.add(ActionTraitRing(ringType: ActionRingType.melee, damageType: dmgAccent));
    }

    if (hasRanged) {
      rings.add(ActionTraitRing(
        ringType: ActionRingType.ranged,
        damageType: secondaryDamageType != null ? _mapDamageType(secondaryDamageType!) : DamageAccent.physical,
      ));
    }

    if (rings.isEmpty) {
      rings.add(ActionTraitRing(ringType: ActionRingType.melee, damageType: dmgAccent));
    }

    return rings;
  }

  DamageAccent _mapDamageType(String dmg) {
    final d = dmg.toLowerCase();
    if (d.contains('fire')) return DamageAccent.fire;
    if (d.contains('cold') || d.contains('ice')) return DamageAccent.cold;
    if (d.contains('lightning')) return DamageAccent.lightning;
    if (d.contains('acid')) return DamageAccent.acid;
    if (d.contains('poison')) return DamageAccent.poison;
    if (d.contains('necrotic')) return DamageAccent.necrotic;
    if (d.contains('radiant')) return DamageAccent.radiant;
    if (d.contains('psychic')) return DamageAccent.psychic;
    if (d.contains('force')) return DamageAccent.force;
    if (d.contains('thunder')) return DamageAccent.thunder;
    return DamageAccent.physical;
  }
}
