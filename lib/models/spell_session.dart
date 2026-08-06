import 'dart:math';
import 'animated_object.dart';

enum RollAdvantage { normal, advantage, disadvantage }

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
    required this.damageBonus,
    required this.totalDamage,
  });
}

class BatchAttackSummary {
  final int targetAc;
  final RollAdvantage advantageMode;
  final List<AttackRollResult> results;
  final int totalAttacks;
  final int totalHits;
  final int totalCrits;
  final int totalDamage;

  BatchAttackSummary({
    required this.targetAc,
    required this.advantageMode,
    required this.results,
    required this.totalAttacks,
    required this.totalHits,
    required this.totalCrits,
    required this.totalDamage,
  });
}

class SpellSession {
  int spellLevel; // 5 to 9
  List<AnimatedObjectInstance> activeObjects;
  final Random _rng = Random();

  SpellSession({
    this.spellLevel = 5,
    List<AnimatedObjectInstance>? activeObjects,
  }) : activeObjects = activeObjects ?? [];

  int get maxPoints {
    // 5th level = 10 points. +2 points per level above 5th.
    return 10 + (spellLevel - 5) * 2;
  }

  int get usedPoints {
    int total = 0;
    for (var obj in activeObjects) {
      total += obj.size.pointCost;
    }
    return total;
  }

  int get remainingPoints => maxPoints - usedPoints;

  bool canAddObject(ObjectSize size) {
    return remainingPoints >= size.pointCost;
  }

  void addObject(ObjectSize size, {String? customName, String damageType = 'Bludgeoning'}) {
    if (!canAddObject(size)) return;

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

  BatchAttackSummary performBatchAttack({
    required int targetAc,
    RollAdvantage advantageMode = RollAdvantage.normal,
  }) {
    List<AttackRollResult> results = [];
    int totalHits = 0;
    int totalCrits = 0;
    int totalDamageSum = 0;

    final livingObjects = activeObjects.where((o) => !o.isDead).toList();

    for (var obj in livingObjects) {
      int roll1 = _rng.nextInt(20) + 1;
      int? roll2;
      int finalD20 = roll1;

      if (advantageMode == RollAdvantage.advantage) {
        roll2 = _rng.nextInt(20) + 1;
        finalD20 = max(roll1, roll2);
      } else if (advantageMode == RollAdvantage.disadvantage) {
        roll2 = _rng.nextInt(20) + 1;
        finalD20 = min(roll1, roll2);
      }

      bool isCrit = (finalD20 == 20);
      bool isNat1 = (finalD20 == 1);
      int toHit = finalD20 + obj.size.attackBonus;
      bool isHit = !isNat1 && (isCrit || toHit >= targetAc);

      List<int> dmgRolls = [];
      int totalDmg = 0;

      if (isHit) {
        totalHits++;
        if (isCrit) totalCrits++;

        int diceCount = obj.size.damageDiceCount;
        if (isCrit) diceCount *= 2; // Critical hit doubles damage dice

        for (int i = 0; i < diceCount; i++) {
          int d = _rng.nextInt(obj.size.damageDiceSides) + 1;
          dmgRolls.add(d);
          totalDmg += d;
        }

        totalDmg += obj.size.damageBonus;
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
          damageBonus: obj.size.damageBonus,
          totalDamage: totalDmg,
        ),
      );
    }

    return BatchAttackSummary(
      targetAc: targetAc,
      advantageMode: advantageMode,
      results: results,
      totalAttacks: livingObjects.length,
      totalHits: totalHits,
      totalCrits: totalCrits,
      totalDamage: totalDamageSum,
    );
  }
}
