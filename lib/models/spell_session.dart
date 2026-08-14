import 'dart:math';
import 'animated_object.dart';
import 'dice_roll.dart';
import 'srd_summons/srd_summons_library.dart';
import '../utils/secure_random.dart';

class AttackRollResult {
  final AnimatedObjectInstance object;
  final int d20Roll1;
  final int? d20Roll2;
  final int finalD20;
  final int totalToHit;
  final bool isCrit;
  final bool isNat1;
  final bool isHit;
  final List<int> damageRolls;
  final List<int>? secondaryDamageRolls;
  final List<int>? maxedRolls;
  final bool isMaximizedCrit;
  final int damageBonus;
  final int totalDamage;

  AttackRollResult({
    required this.object,
    required this.d20Roll1,
    this.d20Roll2,
    required this.finalD20,
    required this.totalToHit,
    required this.isCrit,
    required this.isNat1,
    required this.isHit,
    required this.damageRolls,
    this.secondaryDamageRolls,
    this.maxedRolls,
    this.isMaximizedCrit = false,
    required this.damageBonus,
    required this.totalDamage,
  });
}

class BatchAttackSummary {
  final int targetAc;
  final RollMode advantageMode;
  final bool useMaximizedCrits;
  final List<AttackRollResult> results;
  final int totalAttacks;
  final int totalHits;
  final int totalCrits;
  final int totalDamage;

  BatchAttackSummary({
    required this.targetAc,
    required this.advantageMode,
    this.useMaximizedCrits = false,
    required this.results,
    required this.totalAttacks,
    required this.totalHits,
    required this.totalCrits,
    required this.totalDamage,
  });
}

class SpellSession {
  SummonPreset activePreset;
  int spellLevel; // 1 to 9
  List<AnimatedObjectInstance> activeObjects;
  Random get _rng => SecureRng.instance;

  SpellSession({
    SummonPreset? activePreset,
    this.spellLevel = 5,
    List<AnimatedObjectInstance>? activeObjects,
  })  : activePreset = activePreset ?? SrdSummonsLibrary.allPresets.first,
        activeObjects = activeObjects ?? [];

  int get maxPoints {
    switch (activePreset.id) {
      case 'animate_objects':
        return 10 + (spellLevel - 5).clamp(0, 4) * 2;
      case 'conjure_animals':
        if (spellLevel < 5) return 8;
        if (spellLevel < 7) return 16;
        if (spellLevel < 9) return 24;
        return 32;
      case 'animate_dead':
        return 1 + (spellLevel - 3).clamp(0, 6) * 2;
      case 'create_undead':
        return (3 + (spellLevel - 6).clamp(0, 3));
      case 'conjure_minor_elementals':
        if (spellLevel < 6) return 8;
        if (spellLevel < 8) return 16;
        return 24;
      case 'conjure_elemental':
        return 1;
      case 'giant_insect':
        return 10;
      default:
        return 50;
    }
  }

  int get usedPoints {
    if (activePreset.id == 'animate_objects') {
      int total = 0;
      for (var obj in activeObjects) {
        total += obj.size.pointCost;
      }
      return total;
    }
    return activeObjects.length;
  }

  int get remainingPoints => maxPoints - usedPoints;

  int getMaxAllowedCount(String statBlockId) {
    if (activePreset.id == 'create_undead') {
      switch (statBlockId) {
        case 'undead_ghoul':
          return 3 + (spellLevel - 6).clamp(0, 3); // 3 (6th), 4 (7th), 5 (8th), 6 (9th)
        case 'undead_ghast':
        case 'undead_wight':
          if (spellLevel < 7) return 0;
          return 2 + (spellLevel - 7).clamp(0, 2); // 2 (7th), 3 (8th), 4 (9th)
        case 'undead_mummy':
          if (spellLevel < 8) return 0;
          return 2 + (spellLevel - 8).clamp(0, 1); // 2 (8th), 3 (9th)
        default:
          return 0;
      }
    }
    if (activePreset.id == 'giant_insect') {
      switch (statBlockId) {
        case 'insect_centipede':
          return 10;
        case 'insect_wasp':
          return 5;
        case 'beast_giant_spider':
          return 3;
        case 'insect_scorpion':
          return 1;
        default:
          return 1;
      }
    }
    return maxPoints;
  }

  bool canAddMinion(MinionStatBlock statBlock) {
    if (activeObjects.length >= 50) return false;
    if (activePreset.category == SummonCategory.magicItem) {
      return true;
    }
    if (activePreset.id == 'create_undead') {
      final maxAllowed = getMaxAllowedCount(statBlock.id);
      if (maxAllowed <= 0) return false;
      return activeObjects.length < maxAllowed;
    }
    if (activePreset.id == 'giant_insect') {
      final maxAllowed = getMaxAllowedCount(statBlock.id);
      final currentCount = activeObjects.where((o) => o.name.toLowerCase().contains(statBlock.name.toLowerCase())).length;
      return currentCount < maxAllowed && remainingPoints > 0;
    }
    return remainingPoints > 0;
  }

  bool canAddObject(ObjectSize size) {
    if (activePreset.id == 'animate_objects') {
      return remainingPoints >= size.pointCost;
    }
    return remainingPoints > 0;
  }

  void switchPreset(SummonPreset newPreset) {
    activePreset = newPreset;
    activeObjects.clear();
  }

  void addObject(ObjectSize size, {String? customName, String damageType = 'Bludgeoning'}) {
    if (!canAddObject(size)) return;
    if (activeObjects.length >= 50) return;

    int count = activeObjects.where((o) => o.size == size).length + 1;
    String name = customName ?? '${size.displayName} Object #$count';

    activeObjects.add(
      AnimatedObjectInstance(
        id: '${DateTime.now().microsecondsSinceEpoch}_${activeObjects.length}',
        name: name,
        size: size,
        currentHp: size.maxHp,
        maxHp: size.maxHp,
        damageType: damageType,
      ),
    );
  }

  void addMinionFromStatBlock(MinionStatBlock statBlock, {String? customName}) {
    if (!canAddMinion(statBlock)) return;
    if (activeObjects.length >= 50) return;
    int count = activeObjects.where((o) => o.name.startsWith(statBlock.name)).length + 1;
    String name = customName ?? '${statBlock.name} #$count';

    activeObjects.add(
      AnimatedObjectInstance.fromStatBlock(
        statBlock,
        id: '${DateTime.now().microsecondsSinceEpoch}_${activeObjects.length}',
        customName: name,
      ),
    );
  }

  // Bag of Tricks Random Pull Generator (d8 on active bag variant table)
  MinionStatBlock rollBagOfTricks() {
    final list = activePreset.statBlocks.isNotEmpty
        ? activePreset.statBlocks
        : BagOfTricksSummons.grayBagPreset.statBlocks;
    final selected = list[_rng.nextInt(list.length)];
    addMinionFromStatBlock(selected, customName: '${activePreset.name}: ${selected.name}');
    return selected;
  }

  // Horn of Valhalla Variant Roller (Silver: 2d4+2, Brass: 3d4+3, Bronze: 4d4+4, Iron: 5d4+5)
  int rollHornOfValhalla(String variant) {
    int diceCount = 2;
    int bonus = 2;
    if (variant == 'brass') {
      diceCount = 3;
      bonus = 3;
    } else if (variant == 'bronze') {
      diceCount = 4;
      bonus = 4;
    } else if (variant == 'iron') {
      diceCount = 5;
      bonus = 5;
    }

    int count = bonus;
    for (int i = 0; i < diceCount; i++) {
      count += _rng.nextInt(4) + 1;
    }

    String variantTitle = '${variant[0].toUpperCase()}${variant.substring(1)}';
    for (int i = 0; i < count; i++) {
      addMinionFromStatBlock(
        SrdSummonsLibrary.berserker,
        customName: '$variantTitle Berserker #${activeObjects.length + 1}',
      );
    }
    return count;
  }

  void removeObject(String id) {
    activeObjects.removeWhere((obj) => obj.id == id);
  }

  void clearAll() {
    activeObjects.clear();
  }

  void healAll() {
    for (var obj in activeObjects) {
      obj.currentHp = obj.maxHp;
    }
  }

  void applyGroupDamage(int amount) {
    for (var obj in activeObjects) {
      obj.takeDamage(amount);
    }
  }

  ({List<int> rolls, List<int>? maxedRolls, int damage}) _rollDiceDamage({
    required int diceCount,
    required int diceSides,
    required bool isCrit,
    required bool isMaximizedCrit,
  }) {
    if (diceCount <= 0 || diceSides <= 0) {
      return (rolls: const <int>[], maxedRolls: null, damage: 0);
    }

    if (isCrit && isMaximizedCrit) {
      final maxed = List<int>.generate(diceCount, (_) => diceSides);
      final rolled = List<int>.generate(diceCount, (_) => _rng.nextInt(diceSides) + 1);
      final int rolledSum = rolled.fold<int>(0, (int a, int b) => a + b);
      final int total = (diceCount * diceSides) + rolledSum;
      return (rolls: rolled, maxedRolls: maxed, damage: total);
    }

    final totalDice = isCrit ? diceCount * 2 : diceCount;
    final rolled = List<int>.generate(totalDice, (_) => _rng.nextInt(diceSides) + 1);
    final int total = rolled.fold<int>(0, (int a, int b) => a + b);
    return (rolls: rolled, maxedRolls: null, damage: total);
  }

  BatchAttackSummary performBatchAttack({
    required int targetAc,
    RollMode advantageMode = RollMode.normal,
    bool useMaximizedCrits = false,
  }) {
    List<AttackRollResult> results = [];
    int totalHits = 0;
    int totalCrits = 0;
    int totalDamageSum = 0;

    final livingObjects = activeObjects.where((o) => !o.isDead).toList();

    for (var obj in livingObjects) {
      RollMode effectiveAdv = advantageMode;
      if (effectiveAdv == RollMode.normal && obj.hasPackTactics) {
        effectiveAdv = RollMode.advantage;
      }

      int roll1 = _rng.nextInt(20) + 1;
      int? roll2;
      int finalD20 = roll1;

      if (effectiveAdv == RollMode.advantage) {
        roll2 = _rng.nextInt(20) + 1;
        finalD20 = max(roll1, roll2);
      } else if (effectiveAdv == RollMode.disadvantage) {
        roll2 = _rng.nextInt(20) + 1;
        finalD20 = min(roll1, roll2);
      }

      bool isCrit = (finalD20 == 20);
      bool isNat1 = (finalD20 == 1);
      int toHit = finalD20 + obj.attackBonus;
      bool isHit = !isNat1 && (isCrit || toHit >= targetAc);

      List<int> dmgRolls = [];
      List<int>? secDmgRolls;
      List<int>? maxedRolls;
      bool isMaxedCrit = false;
      int totalDmg = 0;

      if (isHit) {
        totalHits++;
        if (isCrit) {
          totalCrits++;
          isMaxedCrit = useMaximizedCrits;
        }

        final primaryResult = _rollDiceDamage(
          diceCount: obj.damageDiceCount,
          diceSides: obj.damageDiceSides,
          isCrit: isCrit,
          isMaximizedCrit: useMaximizedCrits,
        );
        dmgRolls = primaryResult.rolls;
        maxedRolls = primaryResult.maxedRolls;
        totalDmg += primaryResult.damage;

        if (obj.secondaryDamageDiceCount > 0 && obj.secondaryDamageDiceSides > 0) {
          final secondaryResult = _rollDiceDamage(
            diceCount: obj.secondaryDamageDiceCount,
            diceSides: obj.secondaryDamageDiceSides,
            isCrit: isCrit,
            isMaximizedCrit: useMaximizedCrits,
          );
          secDmgRolls = secondaryResult.rolls;
          totalDmg += secondaryResult.damage;
        }

        totalDmg += obj.damageBonus;
        totalDamageSum += totalDmg;
      }

      results.add(
        AttackRollResult(
          object: obj,
          d20Roll1: roll1,
          d20Roll2: roll2,
          finalD20: finalD20,
          totalToHit: toHit,
          isCrit: isCrit,
          isNat1: isNat1,
          isHit: isHit,
          damageRolls: dmgRolls,
          secondaryDamageRolls: secDmgRolls,
          maxedRolls: maxedRolls,
          isMaximizedCrit: isMaxedCrit,
          damageBonus: obj.damageBonus,
          totalDamage: totalDmg,
        ),
      );
    }

    return BatchAttackSummary(
      targetAc: targetAc,
      advantageMode: advantageMode,
      useMaximizedCrits: useMaximizedCrits,
      results: results,
      totalAttacks: livingObjects.length,
      totalHits: totalHits,
      totalCrits: totalCrits,
      totalDamage: totalDamageSum,
    );
  }
}
