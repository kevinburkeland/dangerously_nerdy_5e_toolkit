import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../repository/reference_resolver.dart';
import 'dnd_5e_rules_engine.dart';
import 'spellcasting_rules_engine.dart';

/// Computed Attack Profile for equipped weapons and unarmed strikes
@immutable
class ComputedAttackProfile {
  final String weaponName;
  final int attackBonus;
  final String attackBonusString;
  final String damageFormula; // e.g. "1d8 + 3"
  final DamageType damageType;
  final String range;
  final bool isOffhand;
  final String? notes;

  const ComputedAttackProfile({
    required this.weaponName,
    required this.attackBonus,
    required this.attackBonusString,
    required this.damageFormula,
    required this.damageType,
    this.range = '5 ft',
    this.isOffhand = false,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'weaponName': weaponName,
        'attackBonus': attackBonus,
        'attackBonusString': attackBonusString,
        'damageFormula': damageFormula,
        'damageType': damageType.name,
        'range': range,
        'isOffhand': isOffhand,
        'notes': notes,
      };
}

/// Fully Evaluated, Reactive Stat Projection for a Character
@immutable
class ComputedCharacterStats {
  final AbilityScores effectiveScores;
  final Map<AbilityType, int> abilityModifiers;
  final int proficiencyBonus;
  final int armorClass;
  final String armorClassBreakdown;
  final int maxHp;
  final int speedFeet;
  final int initiativeBonus;
  final Map<AbilityType, int> savingThrowModifiers;
  final Map<SkillType, int> skillModifiers;
  final int passivePerception;
  final int passiveInvestigation;
  final int passiveInsight;
  final Map<String, int> spellSaveDcs;
  final Map<String, int> spellAttackBonuses;
  final SpellSlotPool computedSpellSlots;
  final List<ComputedAttackProfile> attackProfiles;
  final List<UnresolvedReference> unresolvedReferences;
  final List<String> activeBuffNotes;

  const ComputedCharacterStats({
    required this.effectiveScores,
    required this.abilityModifiers,
    required this.proficiencyBonus,
    required this.armorClass,
    required this.armorClassBreakdown,
    required this.maxHp,
    required this.speedFeet,
    required this.initiativeBonus,
    required this.savingThrowModifiers,
    required this.skillModifiers,
    required this.passivePerception,
    required this.passiveInvestigation,
    required this.passiveInsight,
    required this.spellSaveDcs,
    required this.spellAttackBonuses,
    required this.computedSpellSlots,
    required this.attackProfiles,
    required this.unresolvedReferences,
    required this.activeBuffNotes,
  });
}

/// Pure Evaluation Pipeline for Character Stats
class CharacterStatCalculator {
  /// Evaluates a Character and its equipped items against the priority store
  static ComputedCharacterStats compute(
    Character character,
    ReferenceResolver resolver,
  ) {
    final unresolved = <UnresolvedReference>[];
    final buffNotes = <String>[];

    // 1. Resolve Equipped Items
    final List<EquipmentItem> resolvedEquippedItems = [];
    for (final instance in character.equippedItems) {
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
      if (res.isResolved) {
        resolvedEquippedItems.add(res.entity!);
      } else {
        unresolved.add(res.unresolved!);
      }
    }

    // 2. Evaluate Effective Ability Scores
    var str = character.baseScores.strength + character.bonusScores.strength;
    var dex = character.baseScores.dexterity + character.bonusScores.dexterity;
    var con = character.baseScores.constitution + character.bonusScores.constitution;
    var intl = character.baseScores.intelligence + character.bonusScores.intelligence;
    var wis = character.baseScores.wisdom + character.bonusScores.wisdom;
    var cha = character.baseScores.charisma + character.bonusScores.charisma;

    // Apply item stat bonuses and overrides
    for (int i = 0; i < character.equippedItems.length; i++) {
      final instance = character.equippedItems[i];
      if (instance.requiresAttunement && !instance.isAttuned) continue;

      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
      if (!res.isResolved) continue;
      final item = res.entity!;

      final props = item.customProperties;
      if (props['abilityBonuses'] is Map) {
        final bonuses = props['abilityBonuses'] as Map;
        str += (bonuses['strength'] as num?)?.toInt() ?? 0;
        dex += (bonuses['dexterity'] as num?)?.toInt() ?? 0;
        con += (bonuses['constitution'] as num?)?.toInt() ?? 0;
        intl += (bonuses['intelligence'] as num?)?.toInt() ?? 0;
        wis += (bonuses['wisdom'] as num?)?.toInt() ?? 0;
        cha += (bonuses['charisma'] as num?)?.toInt() ?? 0;
      }

      if (props['abilityOverrides'] is Map) {
        final overrides = props['abilityOverrides'] as Map;
        if (overrides['strength'] is num) {
          str = math.max(str, (overrides['strength'] as num).toInt());
        }
        if (overrides['dexterity'] is num) {
          dex = math.max(dex, (overrides['dexterity'] as num).toInt());
        }
        if (overrides['constitution'] is num) {
          con = math.max(con, (overrides['constitution'] as num).toInt());
        }
        if (overrides['intelligence'] is num) {
          intl = math.max(intl, (overrides['intelligence'] as num).toInt());
        }
        if (overrides['wisdom'] is num) {
          wis = math.max(wis, (overrides['wisdom'] as num).toInt());
        }
        if (overrides['charisma'] is num) {
          cha = math.max(cha, (overrides['charisma'] as num).toInt());
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

    // 3. Armor Class (AC) Pipeline
    int baseAc = 10;
    String acFormula = '10 (Base)';
    int dexContribution = abilityMods[AbilityType.dexterity]!;
    int shieldBonus = 0;
    int magicAcBonus = 0;
    bool hasEquippedArmor = false;

    // Detect equipped armor and shields
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
      if (!res.isResolved) continue;
      final item = res.entity!;
      final props = item.customProperties;

      if (instance.equippedSlot == EquipmentSlot.armor) {
        hasEquippedArmor = true;
        final itemBaseAc = (props['baseAc'] as num?)?.toInt() ?? 10;
        final armorType = props['armorType']?.toString().toLowerCase() ?? 'light';
        final maxDex = (props['maxDexBonus'] as num?)?.toInt();

        baseAc = itemBaseAc;
        if (armorType == 'heavy') {
          dexContribution = 0;
          acFormula = '$itemBaseAc (${item.name})';
        } else if (armorType == 'medium') {
          final cap = maxDex ?? 2;
          dexContribution = math.min(abilityMods[AbilityType.dexterity]!, cap);
          acFormula = '$itemBaseAc (${item.name}) + $dexContribution (DEX capped at $cap)';
        } else {
          // Light armor
          dexContribution = abilityMods[AbilityType.dexterity]!;
          acFormula = '$itemBaseAc (${item.name}) + $dexContribution (DEX)';
        }
      } else if (instance.equippedSlot == EquipmentSlot.shield || props['isShield'] == true) {
        final sBonus = (props['acBonus'] as num?)?.toInt() ?? 2;
        shieldBonus += sBonus;
      } else if (props['acBonus'] is num) {
        magicAcBonus += (props['acBonus'] as num).toInt();
      }
    }

    // If unarmored, check Unarmored Defense
    if (!hasEquippedArmor) {
      final classSlugs = character.progression.classes.map((c) => c.classRef.slug.toLowerCase()).toSet();
      if (classSlugs.contains('barbarian')) {
        baseAc = 10;
        final conBonus = abilityMods[AbilityType.constitution]!;
        dexContribution = abilityMods[AbilityType.dexterity]!;
        acFormula = '10 (Unarmored) + $dexContribution (DEX) + $conBonus (CON Barbarian)';
        baseAc += conBonus;
      } else if (classSlugs.contains('monk') && shieldBonus == 0) {
        baseAc = 10;
        final wisBonus = abilityMods[AbilityType.wisdom]!;
        dexContribution = abilityMods[AbilityType.dexterity]!;
        acFormula = '10 (Unarmored) + $dexContribution (DEX) + $wisBonus (WIS Monk)';
        baseAc += wisBonus;
      } else {
        acFormula = '10 (Unarmored) + $dexContribution (DEX)';
      }
    }

    if (shieldBonus > 0) {
      acFormula += ' + $shieldBonus (Shield)';
    }
    if (magicAcBonus > 0) {
      acFormula += ' + $magicAcBonus (Magic Bonus)';
    }

    final totalAc = baseAc + (hasEquippedArmor && propsArmorHeavy(character, resolver) ? 0 : dexContribution) + shieldBonus + magicAcBonus;

    // 4. Max HP Computation
    int computedMaxHp = 0;
    final conMod = abilityMods[AbilityType.constitution]!;
    for (int i = 0; i < character.progression.classes.length; i++) {
      final cls = character.progression.classes[i];
      if (cls.isStartingClass || i == 0) {
        // Level 1 max hit die
        computedMaxHp += cls.hitDieSides + conMod;
        // Remaining levels
        for (int l = 1; l < cls.level; l++) {
          final rolledIndex = l - 1;
          final rolled = (rolledIndex < cls.hitPointsRolled.length)
              ? cls.hitPointsRolled[rolledIndex]
              : cls.averageHpPerLevel;
          computedMaxHp += math.max(1, rolled + conMod);
        }
      } else {
        // Multiclass levels
        for (int l = 0; l < cls.level; l++) {
          final rolled = (l < cls.hitPointsRolled.length)
              ? cls.hitPointsRolled[l]
              : cls.averageHpPerLevel;
          computedMaxHp += math.max(1, rolled + conMod);
        }
      }
    }

    // Feat adjustments (e.g. Toughness: +2 HP per level)
    for (final featRef in character.feats) {
      if (featRef.slug == 'tough' || featRef.slug == 'toughness') {
        computedMaxHp += character.totalLevel * 2;
        buffNotes.add('Tough Feat: +${character.totalLevel * 2} HP');
      }
    }

    // 5. Speed & Initiative
    var speed = character.baseSpeedFeet;
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
      if (res.isResolved && res.entity!.customProperties['speedBonus'] is num) {
        speed += (res.entity!.customProperties['speedBonus'] as num).toInt();
      }
    }
    final initiativeBonus = abilityMods[AbilityType.dexterity]!;

    // 6. Saving Throws
    final savingThrows = <AbilityType, int>{};
    for (final ability in AbilityType.values) {
      var save = abilityMods[ability]!;
      if (character.savingThrowProficiencies.contains(ability)) {
        save += profBonus;
      }
      savingThrows[ability] = save;
    }

    // 7. Skills & Passives
    final skills = <SkillType, int>{};
    for (final skill in SkillType.values) {
      final ability = skill.defaultAbility;
      final baseMod = abilityMods[ability]!;
      final profLevel = character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;
      final skillMod = baseMod + (profLevel.multiplier * profBonus).floor();
      skills[skill] = skillMod;
    }

    final passivePerception = 10 + (skills[SkillType.perception] ?? 0);
    final passiveInvestigation = 10 + (skills[SkillType.investigation] ?? 0);
    final passiveInsight = 10 + (skills[SkillType.insight] ?? 0);

    // 8. Spellcasting Profile & Multiclass Spell Slots
    final spellSaveDcs = <String, int>{};
    final spellAttackBonuses = <String, int>{};

    for (final cls in character.progression.classes) {
      final classSlug = cls.classRef.slug.toLowerCase();
      final castingAbility = _inferCastingAbility(classSlug);
      if (castingAbility != null) {
        final mod = abilityMods[castingAbility]!;
        spellSaveDcs[classSlug] = 8 + profBonus + mod;
        spellAttackBonuses[classSlug] = profBonus + mod;
      }
    }

    final computedSpellSlots = _computeMulticlassSpellSlots(character.progression.classes);

    // 9. Attack Profiles
    final attackProfiles = <ComputedAttackProfile>[];
    bool hasEquippedWeapon = false;

    for (final instance in character.equippedItems) {
      if (instance.equippedSlot == EquipmentSlot.mainHand ||
          instance.equippedSlot == EquipmentSlot.offHand ||
          instance.equippedSlot == EquipmentSlot.twoHand) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
        if (res.isResolved) {
          final item = res.entity!;
          final props = item.customProperties;
          final isWeapon = props['isWeapon'] == true || item.itemType.toLowerCase().contains('weapon');
          if (isWeapon) {
            hasEquippedWeapon = true;
            final isFinesse = props['isFinesse'] == true;
            final isRanged = props['isRanged'] == true;
            final baseDamageFormula = props['damageFormula']?.toString() ?? '1d6';
            final dmgTypeStr = props['damageType']?.toString() ?? 'slashing';
            final dmgType = DamageType.values.firstWhere(
              (d) => d.name == dmgTypeStr,
              orElse: () => DamageType.slashing,
            );
            final magicBonus = (props['attackBonus'] as num?)?.toInt() ?? 0;

            final chosenAbilityMod = (isRanged || (isFinesse && abilityMods[AbilityType.dexterity]! > abilityMods[AbilityType.strength]!))
                ? abilityMods[AbilityType.dexterity]!
                : abilityMods[AbilityType.strength]!;

            final toHit = profBonus + chosenAbilityMod + magicBonus;
            final damageBonus = (instance.equippedSlot == EquipmentSlot.offHand)
                ? magicBonus
                : chosenAbilityMod + magicBonus;

            final damageString = damageBonus == 0
                ? baseDamageFormula
                : (damageBonus > 0 ? '$baseDamageFormula + $damageBonus' : '$baseDamageFormula - ${damageBonus.abs()}');

            attackProfiles.add(ComputedAttackProfile(
              weaponName: instance.displayName,
              attackBonus: toHit,
              attackBonusString: toHit >= 0 ? '+$toHit' : '$toHit',
              damageFormula: damageString,
              damageType: dmgType,
              range: props['range']?.toString() ?? (isRanged ? '80/320 ft' : '5 ft'),
              isOffhand: instance.equippedSlot == EquipmentSlot.offHand,
              notes: props['propertiesMarkdown']?.toString(),
            ));
          }
        }
      }
    }

    if (!hasEquippedWeapon) {
      final strMod = abilityMods[AbilityType.strength]!;
      final toHit = profBonus + strMod;
      final dmg = math.max(1, 1 + strMod);
      attackProfiles.add(ComputedAttackProfile(
        weaponName: 'Unarmed Strike',
        attackBonus: toHit,
        attackBonusString: toHit >= 0 ? '+$toHit' : '$toHit',
        damageFormula: '$dmg',
        damageType: DamageType.bludgeoning,
      ));
    }

    return ComputedCharacterStats(
      effectiveScores: effectiveScores,
      abilityModifiers: abilityMods,
      proficiencyBonus: profBonus,
      armorClass: totalAc,
      armorClassBreakdown: acFormula,
      maxHp: computedMaxHp,
      speedFeet: speed,
      initiativeBonus: initiativeBonus,
      savingThrowModifiers: savingThrows,
      skillModifiers: skills,
      passivePerception: passivePerception,
      passiveInvestigation: passiveInvestigation,
      passiveInsight: passiveInsight,
      spellSaveDcs: spellSaveDcs,
      spellAttackBonuses: spellAttackBonuses,
      computedSpellSlots: computedSpellSlots,
      attackProfiles: attackProfiles,
      unresolvedReferences: unresolved,
      activeBuffNotes: buffNotes,
    );
  }

  static bool propsArmorHeavy(Character character, ReferenceResolver resolver) {
    for (final instance in character.equippedItems) {
      if (instance.equippedSlot == EquipmentSlot.armor) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef);
        if (res.isResolved && res.entity!.customProperties['armorType']?.toString().toLowerCase() == 'heavy') {
          return true;
        }
      }
    }
    return false;
  }

  static AbilityType? _inferCastingAbility(String classSlug) {
    switch (classSlug.toLowerCase()) {
      case 'wizard':
      case 'artificer':
        return AbilityType.intelligence;
      case 'cleric':
      case 'druid':
      case 'ranger':
        return AbilityType.wisdom;
      case 'bard':
      case 'paladin':
      case 'sorcerer':
      case 'warlock':
        return AbilityType.charisma;
      default:
        return null;
    }
  }

  static SpellSlotPool _computeMulticlassSpellSlots(List<ClassLevelProgression> classes) {
    double totalEffectiveLevel = 0.0;
    int warlockLevel = 0;

    for (final cls in classes) {
      final slug = cls.classRef.slug.toLowerCase();
      switch (slug) {
        case 'wizard':
        case 'cleric':
        case 'druid':
        case 'bard':
        case 'sorcerer':
          totalEffectiveLevel += cls.level;
          break;
        case 'paladin':
        case 'ranger':
          totalEffectiveLevel += (cls.level / 2).floor();
          break;
        case 'artificer':
          totalEffectiveLevel += (cls.level / 2).ceil();
          break;
        case 'warlock':
          warlockLevel += cls.level;
          break;
      }
    }

    final ecl = totalEffectiveLevel.floor();
    final Map<int, int> maxSlots = {};
    if (ecl > 0) {
      final slotList = MulticlassSlotMatrix.getSpellSlots(ecl);
      for (int i = 0; i < slotList.length; i++) {
        final slotLevel = i + 1;
        final count = slotList[i];
        if (count > 0) {
          maxSlots[slotLevel] = count;
        }
      }
    }

    // Pact Magic
    int pactSlotLevel = 0;
    int pactCount = 0;
    if (warlockLevel > 0) {
      final pactData = PactMagicPool.fromWarlockLevel(warlockLevel);
      pactSlotLevel = pactData.slotLevel;
      pactCount = pactData.totalSlots;
    }

    return SpellSlotPool(
      currentSlots: Map<int, int>.from(maxSlots),
      maxSlots: maxSlots,
      pactMagicSlotLevel: pactSlotLevel,
      pactMagicMax: pactCount,
      pactMagicCurrent: pactCount,
    );
  }
}
