import 'dart:isolate';
import 'dart:math';

import 'precomputed_attack.dart';

class DprSimulationResult {
  final int iterations;
  final int hitCount;
  final int critCount;
  final int missCount;
  final int totalDamage;
  final double meanDamage;
  final int minDamage;
  final int maxDamage;

  const DprSimulationResult({
    required this.iterations,
    required this.hitCount,
    required this.critCount,
    required this.missCount,
    required this.totalDamage,
    required this.meanDamage,
    required this.minDamage,
    required this.maxDamage,
  });

  double get hitRate => iterations > 0 ? hitCount / iterations : 0.0;
  double get critRate => iterations > 0 ? critCount / iterations : 0.0;
  double get dpr => meanDamage;

  Map<String, dynamic> toMap() => {
        'iterations': iterations,
        'hitCount': hitCount,
        'critCount': critCount,
        'missCount': missCount,
        'totalDamage': totalDamage,
        'meanDamage': meanDamage,
        'minDamage': minDamage,
        'maxDamage': maxDamage,
        'hitRate': hitRate,
        'critRate': critRate,
      };
}

class DprSimulator {
  const DprSimulator();

  /// Runs Monte Carlo simulation synchronously with zero intermediate heap allocations in loop.
  DprSimulationResult run({
    required PrecomputedAttack attack,
    required int targetAc,
    int iterations = 10000,
    Random? rng,
  }) {
    final random = rng ?? Random();
    var hitCount = 0;
    var critCount = 0;
    var missCount = 0;
    var totalDamage = 0;
    var minDamage = 999999;
    var maxDamage = 0;

    final attackBonus = attack.attackBonus;

    for (var i = 0; i < iterations; i++) {
      final d20 = random.nextInt(20) + 1;

      if (d20 == 20) {
        // Critical hit
        hitCount++;
        critCount++;
        final dmg = attack.rollDamage(random, isCrit: true);
        totalDamage += dmg;
        if (dmg < minDamage) minDamage = dmg;
        if (dmg > maxDamage) maxDamage = dmg;
      } else if (d20 == 1) {
        // Critical miss
        missCount++;
        if (0 < minDamage) minDamage = 0;
      } else if (d20 + attackBonus >= targetAc) {
        // Regular hit
        hitCount++;
        final dmg = attack.rollDamage(random, isCrit: false);
        totalDamage += dmg;
        if (dmg < minDamage) minDamage = dmg;
        if (dmg > maxDamage) maxDamage = dmg;
      } else {
        // Regular miss
        missCount++;
        if (0 < minDamage) minDamage = 0;
      }
    }

    if (iterations == 0 || minDamage == 999999) {
      minDamage = 0;
    }

    final meanDamage = iterations > 0 ? totalDamage / iterations : 0.0;

    return DprSimulationResult(
      iterations: iterations,
      hitCount: hitCount,
      critCount: critCount,
      missCount: missCount,
      totalDamage: totalDamage,
      meanDamage: meanDamage,
      minDamage: minDamage,
      maxDamage: maxDamage,
    );
  }

  /// Runs Monte Carlo simulation in a separate background Isolate.
  Future<DprSimulationResult> runInIsolate({
    required PrecomputedAttack attack,
    required int targetAc,
    int iterations = 10000,
  }) async {
    return await Isolate.run(() {
      const simulator = DprSimulator();
      return simulator.run(
        attack: attack,
        targetAc: targetAc,
        iterations: iterations,
        rng: Random(),
      );
    });
  }
}
