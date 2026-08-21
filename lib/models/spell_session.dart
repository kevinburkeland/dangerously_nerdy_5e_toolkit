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
  Random get _rng => secureRandom;

  SpellSession({
    SummonPreset? activePreset,
    this.spellLevel = 5,
    List<AnimatedObjectInstance>? activeObjects,
  })  : activePreset = activePreset ?? SrdSummonsLibrary.allPresets.first,
        activeObjects = activeObjects ?? [];

  int get maxPoints => activePreset.calculateMaxPoints(spellLevel);

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

  void renameObject(String id, String name) {
    final obj = activeObjects.firstWhere((o) => o.id == id);
    obj.name = name;
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

    final poolResult = DiceRollResult.rollPool(
      diceEntries: [
        DiceEntry(
          dieType: DieType.custom,
          count: diceCount,
          customSides: diceSides,
        ),
      ],
      isCritDamage: isCrit,
      useMaximizedCrits: isMaximizedCrit,
    );

    if (isCrit && isMaximizedCrit) {
      final maxed = List<int>.filled(diceCount, diceSides);
      final rolled = poolResult.individualRolls.sublist(diceCount);
      return (rolls: rolled, maxedRolls: maxed, damage: poolResult.total);
    }

    return (rolls: poolResult.individualRolls, maxedRolls: null, damage: poolResult.total);
  }

  /// Evaluates an attack for a single squad minion against a target AC.
  AttackRollResult resolveIndividualAttack({
    required AnimatedObjectInstance object,
    required int targetAc,
    RollMode requestedAdvantage = RollMode.normal,
    bool useMaximizedCrits = false,
  }) {
    RollMode effectiveAdv = requestedAdvantage;
    if (effectiveAdv == RollMode.normal && object.hasPackTactics) {
      effectiveAdv = RollMode.advantage;
    }

    final roll1 = _rng.nextInt(20) + 1;
    final roll2 = (effectiveAdv != RollMode.normal) ? _rng.nextInt(20) + 1 : null;
    
    final finalD20 = switch (effectiveAdv) {
      RollMode.advantage => max(roll1, roll2!),
      RollMode.disadvantage => min(roll1, roll2!),
      RollMode.normal => roll1,
    };

    final isCrit = (finalD20 == 20);
    final isNat1 = (finalD20 == 1);
    final totalToHit = finalD20 + object.attackBonus;
    final isHit = !isNat1 && (isCrit || totalToHit >= targetAc);

    List<int> dmgRolls = const [];
    List<int>? secDmgRolls;
    List<int>? maxedRolls;
    bool isMaxedCrit = false;
    int totalDmg = 0;

    if (isHit) {
      if (isCrit) {
        isMaxedCrit = useMaximizedCrits;
      }

      final primaryResult = _rollDiceDamage(
        diceCount: object.damageDiceCount,
        diceSides: object.damageDiceSides,
        isCrit: isCrit,
        isMaximizedCrit: useMaximizedCrits,
      );
      dmgRolls = primaryResult.rolls;
      maxedRolls = primaryResult.maxedRolls;
      totalDmg += primaryResult.damage;

      if (object.secondaryDamageDiceCount > 0 && object.secondaryDamageDiceSides > 0) {
        final secondaryResult = _rollDiceDamage(
          diceCount: object.secondaryDamageDiceCount,
          diceSides: object.secondaryDamageDiceSides,
          isCrit: isCrit,
          isMaximizedCrit: useMaximizedCrits,
        );
        secDmgRolls = secondaryResult.rolls;
        totalDmg += secondaryResult.damage;
      }

      totalDmg += object.damageBonus;
    }

    return AttackRollResult(
      object: object,
      d20Roll1: roll1,
      d20Roll2: roll2,
      finalD20: finalD20,
      totalToHit: totalToHit,
      isCrit: isCrit,
      isNat1: isNat1,
      isHit: isHit,
      damageRolls: dmgRolls,
      secondaryDamageRolls: secDmgRolls,
      maxedRolls: maxedRolls,
      isMaximizedCrit: isMaxedCrit,
      damageBonus: object.damageBonus,
      totalDamage: totalDmg,
    );
  }

  /// Evaluates batch attacks across all currently living minions.
  BatchAttackSummary performBatchAttack({
    required int targetAc,
    RollMode advantageMode = RollMode.normal,
    bool useMaximizedCrits = false,
  }) {
    final livingObjects = activeObjects.where((o) => !o.isDead).toList(growable: false);
    final results = livingObjects
        .map((obj) => resolveIndividualAttack(
              object: obj,
              targetAc: targetAc,
              requestedAdvantage: advantageMode,
              useMaximizedCrits: useMaximizedCrits,
            ))
        .toList(growable: false);

    return BatchAttackSummary(
      targetAc: targetAc,
      advantageMode: advantageMode,
      useMaximizedCrits: useMaximizedCrits,
      results: results,
      totalAttacks: livingObjects.length,
      totalHits: results.where((r) => r.isHit).length,
      totalCrits: results.where((r) => r.isCrit).length,
      totalDamage: results.fold<int>(0, (sum, r) => sum + r.totalDamage),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'presetId': activePreset.id,
      'spellLevel': spellLevel,
      'activeObjects': activeObjects.map((o) => o.toMap()).toList(),
    };
  }

  factory SpellSession.fromMap(Map<String, dynamic> map) {
    final presetId = map['presetId']?.toString() ?? 'animate_objects';
    final preset = SrdSummonsLibrary.allPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => SrdSummonsLibrary.allPresets.first,
    );
    final rawObjects = map['activeObjects'];
    List<AnimatedObjectInstance> objects = [];
    if (rawObjects is List) {
      objects = rawObjects
          .whereType<Map>()
          .map((m) => AnimatedObjectInstance.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    return SpellSession(
      activePreset: preset,
      spellLevel: (map['spellLevel'] as num?)?.toInt() ?? 5,
      activeObjects: objects,
    );
  }
}
