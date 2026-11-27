import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../../utils/dice_formatters.dart';
import '../monster_codex/monster_presentation_registry.dart';
import '../visual/glyph_kinds.dart';

import 'srd_summons_library.dart';

export 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show CreatureAction, CreatureTrait, MonsterStatBlock, SummonCategory;
export '../visual/argb.dart';

/// App-layer presentation and dice-formatting helpers on [MonsterStatBlock].
extension MonsterStatBlockDisplayExt on MonsterStatBlock {
  Argb get accentArgb => resolveMonsterAccentArgb(
        id: id,
        typeDisplay: typeDisplay,
      );

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

/// Helper extension mapping [MonsterStatBlock] to DndGlyph parameters.
extension MonsterStatBlockGlyphExt on MonsterStatBlock {
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

  double get crValue => parseChallengeRating(crDisplay) ?? 0;

  int get glyphCrTier {
    final cr = crValue;
    if (cr <= 4) return 1;
    if (cr <= 10) return 2;
    if (cr <= 16) return 3;
    return 4;
  }

  List<ActionTraitRing> get glyphActionRings {
    final rings = <ActionTraitRing>[];
    final dmgAccent = _mapDamageType(damageType);
    final allAccents = <DamageAccent>{};
    if (dmgAccent != DamageAccent.physical) allAccents.add(dmgAccent);
    if (secondaryDamageType != null) {
      final sec = _mapDamageType(secondaryDamageType!);
      if (sec != DamageAccent.physical) allAccents.add(sec);
    }

    bool hasMelee = false;
    bool hasRanged = false;
    bool hasRecharge = false;
    bool hasLegendary = false;
    bool hasControl = false;
    bool hasSustain = false;

    for (final act in actions) {
      final actLower = '${act.name} ${act.attackType ?? ""} ${act.description}'
          .toLowerCase();
      if (actLower.contains('melee') || actLower.contains('reach')) {
        hasMelee = true;
      }
      if (actLower.contains('ranged') ||
          actLower.contains('range') ||
          actLower.contains('bow') ||
          actLower.contains('web')) {
        hasRanged = true;
      }
      if (actLower.contains('recharge') || actLower.contains('breath')) {
        hasRecharge = true;
      }
      if (actLower.contains('grapple') ||
          actLower.contains('restrain') ||
          actLower.contains('paralyz') ||
          actLower.contains('frighten') ||
          actLower.contains('petrif') ||
          actLower.contains('swallow') ||
          actLower.contains('charm')) {
        hasControl = true;
      }
      if (actLower.contains('heal') || actLower.contains('regain')) {
        hasSustain = true;
      }
      _extractDamageAccents(actLower, allAccents);
    }

    for (final trait in traits) {
      final traitLower = '${trait.name} ${trait.description}'.toLowerCase();
      if (traitLower.contains('legendary')) {
        hasLegendary = true;
      }
      if (traitLower.contains('recharge') || traitLower.contains('breath')) {
        hasRecharge = true;
      }
      if (traitLower.contains('regeneration') ||
          traitLower.contains('regenerate')) {
        hasSustain = true;
      }
      if (traitLower.contains('frightening presence') ||
          traitLower.contains('charm') ||
          traitLower.contains('petrif') ||
          traitLower.contains('paralyz')) {
        hasControl = true;
      }
      _extractDamageAccents(traitLower, allAccents);
    }

    for (final act in legendaryActions) {
      hasLegendary = true;
      final actLower = '${act.name} ${act.attackType ?? ""} ${act.description}'
          .toLowerCase();
      if (actLower.contains('melee') || actLower.contains('reach')) {
        hasMelee = true;
      }
      if (actLower.contains('ranged') ||
          actLower.contains('range') ||
          actLower.contains('bow') ||
          actLower.contains('web')) {
        hasRanged = true;
      }
      if (actLower.contains('recharge') || actLower.contains('breath')) {
        hasRecharge = true;
      }
      if (actLower.contains('grapple') ||
          actLower.contains('restrain') ||
          actLower.contains('paralyz') ||
          actLower.contains('frighten') ||
          actLower.contains('petrif') ||
          actLower.contains('swallow') ||
          actLower.contains('charm')) {
        hasControl = true;
      }
      _extractDamageAccents(actLower, allAccents);
    }

    if (hasLegendary ||
        hasLegendaryResistance ||
        hasLegendaryActions ||
        legendaryActions.isNotEmpty) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.legendary));
    }

    if (reactions.isNotEmpty && rings.length < 3) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.reaction));
    }

    if (hasRecharge && rings.length < 3) {
      final rechargeDamage =
          allAccents.isNotEmpty && allAccents.first != DamageAccent.physical
              ? allAccents.first
              : (dmgAccent != DamageAccent.physical ? dmgAccent : null);
      rings.add(ActionTraitRing(
        ringType: ActionRingType.recharge,
        damageType: rechargeDamage,
        damageTypes: allAccents.toList(),
      ));
    }

    if (hasControl && rings.length < 3) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.control));
    }

    if (hasSustain && rings.length < 3) {
      rings.add(const ActionTraitRing(ringType: ActionRingType.sustain));
    }

    if (hasMelee && rings.length < 3) {
      rings.add(ActionTraitRing(
          ringType: ActionRingType.melee, damageType: dmgAccent));
    }

    if (hasRanged && rings.length < 3) {
      rings.add(ActionTraitRing(
        ringType: ActionRingType.ranged,
        damageType: secondaryDamageType != null
            ? _mapDamageType(secondaryDamageType!)
            : DamageAccent.physical,
      ));
    }

    if (rings.isEmpty) {
      rings.add(ActionTraitRing(
          ringType: ActionRingType.melee, damageType: dmgAccent));
    }

    return rings.take(3).toList(growable: false);
  }

  void _extractDamageAccents(String text, Set<DamageAccent> target) {
    if (text.contains('fire')) target.add(DamageAccent.fire);
    if (text.contains('cold') || text.contains('ice')) {
      target.add(DamageAccent.cold);
    }
    if (text.contains('lightning')) target.add(DamageAccent.lightning);
    if (text.contains('acid')) target.add(DamageAccent.acid);
    if (text.contains('poison')) target.add(DamageAccent.poison);
    if (text.contains('necrotic')) target.add(DamageAccent.necrotic);
    if (text.contains('radiant')) target.add(DamageAccent.radiant);
    if (text.contains('psychic')) target.add(DamageAccent.psychic);
    if (text.contains('force')) target.add(DamageAccent.force);
    if (text.contains('thunder')) target.add(DamageAccent.thunder);
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

/// Extension resolving concrete [MonsterStatBlock] from outer-layer SRD summons libraries
/// without leaking outer-layer dependencies into the pure domain AnimatedObjectInstance entity.
extension AnimatedObjectStatBlockX on AnimatedObjectInstance {
  /// Resolves the full 5e SRD [MonsterStatBlock] for this creature instance.
  MonsterStatBlock get statBlock {
    if (statBlockId != null) {
      final found = SrdSummonsLibrary.findStatBlockById(statBlockId!);
      if (found != null) return found;
    }
    final byName = SrdSummonsLibrary.findStatBlockByName(name);
    if (byName != null) return byName;

    // Fallback to synthetic Animate Object stat block matching size
    return switch (size) {
      ObjectSize.tiny => SrdSummonsLibrary.tinyObject,
      ObjectSize.small => SrdSummonsLibrary.smallObject,
      ObjectSize.medium => SrdSummonsLibrary.mediumObject,
      ObjectSize.large => SrdSummonsLibrary.largeObject,
      ObjectSize.huge => SrdSummonsLibrary.hugeObject,
    };
  }
}

/// Factory extension to construct AnimatedObjectInstance from an SRD [MonsterStatBlock].
extension MonsterStatBlockInstanceFactory on MonsterStatBlock {
  AnimatedObjectInstance toInstance({
    required String id,
    String? customName,
    int tempHp = 0,
  }) {
    return AnimatedObjectInstance(
      id: id,
      name: customName ?? name,
      size: ObjectSize.fromString(sizeDisplay),
      currentHp: maxHp,
      maxHp: maxHp,
      tempHp: tempHp,
      damageType: damageType,
      statBlockId: this.id,
      customAc: ac,
      customAttackBonus: attackBonus,
      customDamageDiceCount: damageDiceCount,
      customDamageDiceSides: damageDiceSides,
      customDamageBonus: damageBonus,
      secondaryDamageDiceCount: secondaryDamageDiceCount,
      secondaryDamageDiceSides: secondaryDamageDiceSides,
      secondaryDamageType: secondaryDamageType,
      customProperties: {
        if (hasPackTactics) 'hasPackTactics': true,
      },
      specialTrait: specialTrait,
    );
  }
}
