import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../repository/reference_resolver.dart';
import 'character_stat_calculator.dart' show ComputedAttackProfile;
import 'dnd_5e_rules_engine.dart';

export 'character_stat_calculator.dart' show ComputedAttackProfile;

/// Fully evaluated and reactive stat calculation result for a Character.
@immutable
class EvaluatedCharacterStats {
  final AbilityScores effectiveScores;
  final Map<AbilityType, int> abilityModifiers;
  final int proficiencyBonus;
  final int effectiveMaxAttunementSlots;
  final int attunedItemCount;
  final int armorClass;
  final String armorClassBreakdown;
  final int maxHp;
  final int speedFeet;
  final int initiativeBonus;
  final String initiativeBonusString;
  final Map<AbilityType, int> savingThrowModifiers;
  final Map<SkillType, int> skillModifiers;
  final int passivePerception;
  final int passiveInsight;
  final int passiveInvestigation;
  final Map<String, int> spellSaveDcs;
  final Map<String, int> spellAttackBonuses;
  final SpellSlotPool computedSpellSlots;
  final List<ComputedAttackProfile> attackProfiles;
  final List<String> activeBuffNotes;

  const EvaluatedCharacterStats({
    required this.effectiveScores,
    required this.abilityModifiers,
    required this.proficiencyBonus,
    required this.effectiveMaxAttunementSlots,
    required this.attunedItemCount,
    required this.armorClass,
    required this.armorClassBreakdown,
    required this.maxHp,
    required this.speedFeet,
    required this.initiativeBonus,
    required this.initiativeBonusString,
    required this.savingThrowModifiers,
    required this.skillModifiers,
    required this.passivePerception,
    required this.passiveInsight,
    required this.passiveInvestigation,
    required this.spellSaveDcs,
    required this.spellAttackBonuses,
    required this.computedSpellSlots,
    required this.attackProfiles,
    required this.activeBuffNotes,
  });
}

/// Pure Dart derivation engine for computing dynamic stats from base Character models,
/// equipped & attuned inventory items, and class progression.
class CharacterEvaluationEngine {
  /// Evaluates a [Character] model into [EvaluatedCharacterStats].
  /// Optionally accepts a [ReferenceResolver] if item references need compendium fallback.
  static EvaluatedCharacterStats evaluate(
    Character character, {
    ReferenceResolver? resolver,
  }) {
    final buffNotes = <String>[];

    // 1. Calculate Attunement Slot Limits (Standard 3, scaling with Artificer features)
    int maxAttunement = character.maxAttunementSlots;
    int artificerLevel = 0;
    for (final c in character.progression.classes) {
      final nameOrSlug = c.classRef.slug.toLowerCase();
      if (nameOrSlug.contains('artificer') || c.classRef.displayName.toLowerCase().contains('artificer')) {
        artificerLevel += c.level;
      }
    }

    if (artificerLevel >= 18) {
      maxAttunement = math.max(maxAttunement, 6);
      buffNotes.add('Magic Item Master: 6 Attunement Slots');
    } else if (artificerLevel >= 14) {
      maxAttunement = math.max(maxAttunement, 5);
      buffNotes.add('Magic Item Savant: 5 Attunement Slots');
    } else if (artificerLevel >= 10) {
      maxAttunement = math.max(maxAttunement, 4);
      buffNotes.add('Magic Item Adept: 4 Attunement Slots');
    }

    // Check custom properties for attunement overrides
    if (character.customProperties['overrideMaxAttunementSlots'] is num) {
      maxAttunement = (character.customProperties['overrideMaxAttunementSlots'] as num).toInt();
    }
    if (character.customProperties['attunementSlotBonus'] is num) {
      maxAttunement += (character.customProperties['attunementSlotBonus'] as num).toInt();
    }

    final attunedCount = character.inventory.where((i) => i.isAttuned).length;

    // 2. Helper to get merged custom properties for an inventory item
    Map<String, dynamic> getItemProperties(InventoryItemInstance instance) {
      final merged = Map<String, dynamic>.from(instance.customProperties);
      if (resolver != null) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
        if (res.isResolved && res.entity != null) {
          for (final entry in res.entity!.customProperties.entries) {
            merged.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }
      return merged;
    }

    // 3. Ability Score Derivation (Base + Bonus + Item Bonuses / Overrides)
    var str = character.baseScores.strength + character.bonusScores.strength;
    var dex = character.baseScores.dexterity + character.bonusScores.dexterity;
    var con = character.baseScores.constitution + character.bonusScores.constitution;
    var intl = character.baseScores.intelligence + character.bonusScores.intelligence;
    var wis = character.baseScores.wisdom + character.bonusScores.wisdom;
    var cha = character.baseScores.charisma + character.bonusScores.charisma;

    // Accumulate item bonuses & overrides
    for (final instance in character.equippedItems) {
      // Must be attuned if attunement is required
      if (instance.requiresAttunement && !instance.isAttuned) continue;

      final props = getItemProperties(instance);

      // Direct bonus keys (e.g., strengthBonus: 2 or bonusStrength: 2)
      str += (props['strengthBonus'] as num?)?.toInt() ?? (props['bonusStrength'] as num?)?.toInt() ?? 0;
      dex += (props['dexterityBonus'] as num?)?.toInt() ?? (props['bonusDexterity'] as num?)?.toInt() ?? 0;
      con += (props['constitutionBonus'] as num?)?.toInt() ?? (props['bonusConstitution'] as num?)?.toInt() ?? 0;
      intl += (props['intelligenceBonus'] as num?)?.toInt() ?? (props['bonusIntelligence'] as num?)?.toInt() ?? 0;
      wis += (props['wisdomBonus'] as num?)?.toInt() ?? (props['bonusWisdom'] as num?)?.toInt() ?? 0;
      cha += (props['charismaBonus'] as num?)?.toInt() ?? (props['bonusCharisma'] as num?)?.toInt() ?? 0;

      // Nested abilityBonuses map
      if (props['abilityBonuses'] is Map) {
        final bonuses = props['abilityBonuses'] as Map;
        str += (bonuses['strength'] as num?)?.toInt() ?? 0;
        dex += (bonuses['dexterity'] as num?)?.toInt() ?? 0;
        con += (bonuses['constitution'] as num?)?.toInt() ?? 0;
        intl += (bonuses['intelligence'] as num?)?.toInt() ?? 0;
        wis += (bonuses['wisdom'] as num?)?.toInt() ?? 0;
        cha += (bonuses['charisma'] as num?)?.toInt() ?? 0;
      }

      // Direct override keys (e.g., overrideStrength: 21)
      if (props['overrideStrength'] is num) {
        final overrideVal = (props['overrideStrength'] as num).toInt();
        if (overrideVal > str) {
          str = overrideVal;
          buffNotes.add('${instance.displayName}: STR set to $overrideVal');
        }
      }
      if (props['overrideDexterity'] is num) {
        final overrideVal = (props['overrideDexterity'] as num).toInt();
        if (overrideVal > dex) {
          dex = overrideVal;
          buffNotes.add('${instance.displayName}: DEX set to $overrideVal');
        }
      }
      if (props['overrideConstitution'] is num) {
        final overrideVal = (props['overrideConstitution'] as num).toInt();
        if (overrideVal > con) {
          con = overrideVal;
          buffNotes.add('${instance.displayName}: CON set to $overrideVal');
        }
      }
      if (props['overrideIntelligence'] is num) {
        final overrideVal = (props['overrideIntelligence'] as num).toInt();
        if (overrideVal > intl) {
          intl = overrideVal;
          buffNotes.add('${instance.displayName}: INT set to $overrideVal');
        }
      }
      if (props['overrideWisdom'] is num) {
        final overrideVal = (props['overrideWisdom'] as num).toInt();
        if (overrideVal > wis) {
          wis = overrideVal;
          buffNotes.add('${instance.displayName}: WIS set to $overrideVal');
        }
      }
      if (props['overrideCharisma'] is num) {
        final overrideVal = (props['overrideCharisma'] as num).toInt();
        if (overrideVal > cha) {
          cha = overrideVal;
          buffNotes.add('${instance.displayName}: CHA set to $overrideVal');
        }
      }

      // Nested abilityOverrides map
      if (props['abilityOverrides'] is Map) {
        final overrides = props['abilityOverrides'] as Map;
        if (overrides['strength'] is num) {
          final o = (overrides['strength'] as num).toInt();
          if (o > str) str = o;
        }
        if (overrides['dexterity'] is num) {
          final o = (overrides['dexterity'] as num).toInt();
          if (o > dex) dex = o;
        }
        if (overrides['constitution'] is num) {
          final o = (overrides['constitution'] as num).toInt();
          if (o > con) con = o;
        }
        if (overrides['intelligence'] is num) {
          final o = (overrides['intelligence'] as num).toInt();
          if (o > intl) intl = o;
        }
        if (overrides['wisdom'] is num) {
          final o = (overrides['wisdom'] as num).toInt();
          if (o > wis) wis = o;
        }
        if (overrides['charisma'] is num) {
          final o = (overrides['charisma'] as num).toInt();
          if (o > cha) cha = o;
        }
      }
    }

    final effectiveScores = AbilityScores(
      strength: str,
      dexterity: dex,
      constitution: con,
      intelligence: intl,
      wisdom: wis,
      charisma: cha,
    );

    final abilityMods = <AbilityType, int>{
      AbilityType.strength: effectiveScores.strength.dndModifier,
      AbilityType.dexterity: effectiveScores.dexterity.dndModifier,
      AbilityType.constitution: effectiveScores.constitution.dndModifier,
      AbilityType.intelligence: effectiveScores.intelligence.dndModifier,
      AbilityType.wisdom: effectiveScores.wisdom.dndModifier,
      AbilityType.charisma: effectiveScores.charisma.dndModifier,
    };

    final profBonus = character.proficiencyBonus;

    // 4. Armor Class Calculation
    int baseAc = 10;
    String armorDesc = '10 (Base Unarmored)';
    int dexAcBonus = abilityMods[AbilityType.dexterity]!;
    int shieldBonus = 0;
    String? shieldDesc;
    int magicAcBonus = 0;
    final List<String> magicAcSources = [];
    bool hasEquippedArmor = false;

    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final props = getItemProperties(instance);

      final isArmorSlot = instance.equippedSlot == EquipmentSlot.armor;
      final isArmorType = props['armorType'] != null || props['baseAc'] != null;

      if (isArmorSlot || (isArmorType && instance.equippedSlot != EquipmentSlot.shield && props['isShield'] != true)) {
        hasEquippedArmor = true;
        final itemBaseAc = (props['baseAc'] as num?)?.toInt() ?? 10;
        final armorType = (props['armorType']?.toString() ?? 'light').toLowerCase();
        final maxDex = (props['maxDexBonus'] as num?)?.toInt();

        baseAc = itemBaseAc;
        if (armorType == 'heavy') {
          dexAcBonus = 0;
          armorDesc = '$itemBaseAc (${instance.displayName})';
        } else if (armorType == 'medium') {
          final cap = maxDex ?? 2;
          dexAcBonus = math.min(abilityMods[AbilityType.dexterity]!, cap);
          armorDesc = '$itemBaseAc (${instance.displayName}) + $dexAcBonus DEX (capped at $cap)';
        } else {
          // Light armor
          dexAcBonus = abilityMods[AbilityType.dexterity]!;
          armorDesc = '$itemBaseAc (${instance.displayName}) + $dexAcBonus DEX';
        }

        if (props['acBonus'] is num) {
          final bonus = (props['acBonus'] as num).toInt();
          if (bonus > 0) {
            magicAcBonus += bonus;
            magicAcSources.add('+$bonus (${instance.displayName})');
          }
        }
      } else if (instance.equippedSlot == EquipmentSlot.shield || props['isShield'] == true) {
        final sBonus = (props['acBonus'] as num?)?.toInt() ?? (props['shieldBonus'] as num?)?.toInt() ?? 2;
        shieldBonus += sBonus;
        shieldDesc = '+$sBonus (${instance.displayName})';
      } else if (props['acBonus'] is num) {
        final bonus = (props['acBonus'] as num).toInt();
        if (bonus != 0) {
          magicAcBonus += bonus;
          magicAcSources.add('${bonus >= 0 ? "+$bonus" : "$bonus"} (${instance.displayName})');
        }
      }
    }

    // Unarmored Defense check if no armor is equipped
    if (!hasEquippedArmor) {
      final classSlugs = character.progression.classes
          .map((c) => c.classRef.slug.toLowerCase())
          .toSet();

      if (classSlugs.contains('barbarian')) {
        final conBonus = abilityMods[AbilityType.constitution]!;
        baseAc = 10;
        dexAcBonus = abilityMods[AbilityType.dexterity]!;
        armorDesc = '10 (Unarmored) + $dexAcBonus DEX + $conBonus CON (Barbarian)';
        baseAc += conBonus;
      } else if (classSlugs.contains('monk') && shieldBonus == 0) {
        final wisBonus = abilityMods[AbilityType.wisdom]!;
        baseAc = 10;
        dexAcBonus = abilityMods[AbilityType.dexterity]!;
        armorDesc = '10 (Unarmored) + $dexAcBonus DEX + $wisBonus WIS (Monk)';
        baseAc += wisBonus;
      } else {
        armorDesc = '10 (Unarmored) + $dexAcBonus DEX';
      }
    }

    final totalAc = baseAc + dexAcBonus + shieldBonus + magicAcBonus;
    final breakdownParts = <String>[armorDesc];
    if (shieldBonus > 0 && shieldDesc != null) breakdownParts.add(shieldDesc);
    for (final src in magicAcSources) {
      breakdownParts.add(src);
    }
    final breakdownString = '${breakdownParts.join(' + ')} = $totalAc AC';

    // 5. HP, Speed, and Initiative
    var maxHp = 0;
    final conMod = abilityMods[AbilityType.constitution]!;
    for (int i = 0; i < character.progression.classes.length; i++) {
      final c = character.progression.classes[i];
      if (c.isStartingClass || i == 0) {
        // Starting class level 1 gets max hit die + CON
        maxHp += c.hitDieSides + conMod;
        // Remaining levels
        for (int l = 1; l < c.level; l++) {
          final rolledIndex = l - 1;
          final rolled = (rolledIndex < c.hitPointsRolled.length)
              ? c.hitPointsRolled[rolledIndex]
              : c.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      } else {
        // Multiclass slices: all levels gain rolled/average + CON
        for (int l = 0; l < c.level; l++) {
          final rolled = (l < c.hitPointsRolled.length)
              ? c.hitPointsRolled[l]
              : c.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      }
    }
    if (maxHp <= 0) maxHp = 10;

    var speed = character.baseSpeedFeet;
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final props = getItemProperties(instance);
      if (props['speedBonus'] is num) {
        speed += (props['speedBonus'] as num).toInt();
      }
    }

    final initBonus = abilityMods[AbilityType.dexterity]!;
    final initBonusString = initBonus >= 0 ? '+$initBonus' : '$initBonus';

    // 6. Saving Throws
    final savingThrows = <AbilityType, int>{};
    for (final ability in AbilityType.values) {
      var saveMod = abilityMods[ability]!;
      if (character.savingThrowProficiencies.contains(ability)) {
        saveMod += profBonus;
      }
      // Check magic item save bonuses
      for (final instance in character.equippedItems) {
        if (instance.requiresAttunement && !instance.isAttuned) continue;
        final props = getItemProperties(instance);
        if (props['savingThrowBonus'] is num) {
          saveMod += (props['savingThrowBonus'] as num).toInt();
        }
      }
      savingThrows[ability] = saveMod;
    }

    // 7. Skill Modifiers
    final skillMods = <SkillType, int>{};
    for (final skill in SkillType.values) {
      final ability = skill.defaultAbility;
      final mod = abilityMods[ability]!;
      final profLevel = character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;
      final skillTotal = mod + (profBonus * profLevel.multiplier).floor();
      skillMods[skill] = skillTotal;
    }

    final passivePerc = 10 + (skillMods[SkillType.perception] ?? abilityMods[AbilityType.wisdom]!);
    final passiveIns = 10 + (skillMods[SkillType.insight] ?? abilityMods[AbilityType.wisdom]!);
    final passiveInvest = 10 + (skillMods[SkillType.investigation] ?? abilityMods[AbilityType.intelligence]!);

    // 8. Spell Save DCs & Attack Bonuses
    final spellSaveDcs = <String, int>{};
    final spellAttackBonuses = <String, int>{};

    for (final c in character.progression.classes) {
      final className = c.classRef.displayName;
      final slug = c.classRef.slug.toLowerCase();

      AbilityType castingAbility;
      if (slug.contains('wizard') || slug.contains('artificer')) {
        castingAbility = AbilityType.intelligence;
      } else if (slug.contains('cleric') || slug.contains('druid') || slug.contains('ranger')) {
        castingAbility = AbilityType.wisdom;
      } else if (slug.contains('bard') || slug.contains('paladin') || slug.contains('sorcerer') || slug.contains('warlock')) {
        castingAbility = AbilityType.charisma;
      } else {
        castingAbility = AbilityType.intelligence;
      }

      var itemSpellBonus = 0;
      for (final instance in character.equippedItems) {
        if (instance.requiresAttunement && !instance.isAttuned) continue;
        final props = getItemProperties(instance);
        if (props['spellDcBonus'] is num) {
          itemSpellBonus += (props['spellDcBonus'] as num).toInt();
        }
      }

      final castMod = abilityMods[castingAbility]!;
      spellSaveDcs[className] = 8 + profBonus + castMod + itemSpellBonus;
      spellAttackBonuses[className] = profBonus + castMod + itemSpellBonus;
    }

    // 9. Attack Profiles
    final attackProfiles = <ComputedAttackProfile>[];
    for (final instance in character.equippedItems) {
      final isWeaponSlot = instance.equippedSlot == EquipmentSlot.mainHand ||
          instance.equippedSlot == EquipmentSlot.offHand ||
          instance.equippedSlot == EquipmentSlot.twoHand;
      final props = getItemProperties(instance);
      final isWeapon = isWeaponSlot || props['weaponType'] != null || props['damageDice'] != null;

      if (isWeapon) {
        final weaponName = instance.displayName;
        final isFinesse = props['isFinesse'] == true || props['finesse'] == true;
        final isRanged = props['isRanged'] == true || props['ranged'] == true;
        final magicWeaponBonus = (props['attackBonus'] as num?)?.toInt() ??
            (props['magicBonus'] as num?)?.toInt() ?? 0;

        int abilityMod;
        if (isRanged) {
          abilityMod = abilityMods[AbilityType.dexterity]!;
        } else if (isFinesse) {
          abilityMod = math.max(
            abilityMods[AbilityType.strength]!,
            abilityMods[AbilityType.dexterity]!,
          );
        } else {
          abilityMod = abilityMods[AbilityType.strength]!;
        }

        final isProficient = props['isProficient'] != false;
        final totalAttackBonus = abilityMod + (isProficient ? profBonus : 0) + magicWeaponBonus;
        final attackBonusStr = totalAttackBonus >= 0 ? '+$totalAttackBonus' : '$totalAttackBonus';

        final baseDice = props['damageDice']?.toString() ?? '1d8';
        final isOffhand = instance.equippedSlot == EquipmentSlot.offHand;
        final damageMod = isOffhand ? magicWeaponBonus : (abilityMod + magicWeaponBonus);
        final damageModStr = damageMod > 0 ? ' + $damageMod' : (damageMod < 0 ? ' - ${damageMod.abs()}' : '');
        final formula = '$baseDice$damageModStr';

        final dmgTypeStr = props['damageType']?.toString() ?? 'slashing';
        final dmgType = DamageType.values.firstWhere(
          (d) => d.name.toLowerCase() == dmgTypeStr.toLowerCase(),
          orElse: () => DamageType.slashing,
        );

        attackProfiles.add(ComputedAttackProfile(
          weaponName: weaponName,
          attackBonus: totalAttackBonus,
          attackBonusString: attackBonusStr,
          damageFormula: formula,
          damageType: dmgType,
          range: props['range']?.toString() ?? (isRanged ? '80/320 ft' : '5 ft'),
          isOffhand: isOffhand,
          notes: props['notes']?.toString(),
        ));
      }
    }

    // Default Unarmed Strike if no weapons equipped
    if (attackProfiles.isEmpty) {
      final strMod = abilityMods[AbilityType.strength]!;
      final atkBonus = strMod + profBonus;
      final atkBonusStr = atkBonus >= 0 ? '+$atkBonus' : '$atkBonus';
      final dmg = math.max(1, 1 + strMod);
      attackProfiles.add(ComputedAttackProfile(
        weaponName: 'Unarmed Strike',
        attackBonus: atkBonus,
        attackBonusString: atkBonusStr,
        damageFormula: '$dmg',
        damageType: DamageType.bludgeoning,
        range: '5 ft',
      ));
    }

    return EvaluatedCharacterStats(
      effectiveScores: effectiveScores,
      abilityModifiers: abilityMods,
      proficiencyBonus: profBonus,
      effectiveMaxAttunementSlots: maxAttunement,
      attunedItemCount: attunedCount,
      armorClass: totalAc,
      armorClassBreakdown: breakdownString,
      maxHp: maxHp,
      speedFeet: speed,
      initiativeBonus: initBonus,
      initiativeBonusString: initBonusString,
      savingThrowModifiers: savingThrows,
      skillModifiers: skillMods,
      passivePerception: passivePerc,
      passiveInsight: passiveIns,
      passiveInvestigation: passiveInvest,
      spellSaveDcs: spellSaveDcs,
      spellAttackBonuses: spellAttackBonuses,
      computedSpellSlots: character.resources.spellSlots,
      attackProfiles: attackProfiles,
      activeBuffNotes: buffNotes,
    );
  }
}
