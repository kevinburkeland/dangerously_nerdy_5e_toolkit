import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/simulation/dpr_simulator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/simulation/precomputed_attack.dart';

void main() {
  group('DprSimulator', () {
    const testAttack = PrecomputedAttack(
      attackId: 'halberd_strike',
      attackBonus: 7, // +7 to hit
      flatBonus: 4,
      damageGroups: [
        DamageDieGroup(count: 1, faces: 10), // 1d10 + 4
      ],
    );

    test('runs 10,000 iterations synchronously with reasonable statistics', () {
      const simulator = DprSimulator();
      // Target AC 15: needs 8 on d20. (13 faces out of 20 = 65% hit rate, 5% crit rate)
      final result = simulator.run(
        attack: testAttack,
        targetAc: 15,
        iterations: 10000,
        rng: Random(42),
      );

      expect(result.iterations, equals(10000));
      // Hit rate should be around 0.65 +/- 0.03
      expect(result.hitRate, closeTo(0.65, 0.03));
      // Crit rate should be around 0.05 +/- 0.015
      expect(result.critRate, closeTo(0.05, 0.015));
      expect(result.missCount + result.hitCount, equals(10000));
      expect(result.meanDamage, isPositive);
      expect(result.dpr, equals(result.meanDamage));
      expect(result.toMap()['iterations'], equals(10000));
    });

    test('handles extreme AC cases (nat 20 hit, nat 1 miss)', () {
      const simulator = DprSimulator();

      // AC 999: Only nat 20 can hit (5% hit rate, all hits are crits)
      final highAcResult = simulator.run(
        attack: testAttack,
        targetAc: 999,
        iterations: 10000,
        rng: Random(42),
      );
      expect(highAcResult.hitCount, equals(highAcResult.critCount));
      expect(highAcResult.critRate, closeTo(0.05, 0.015));

      // AC 0: Everything hits except nat 1 (95% hit rate)
      final lowAcResult = simulator.run(
        attack: testAttack,
        targetAc: 0,
        iterations: 10000,
        rng: Random(42),
      );
      expect(lowAcResult.hitRate, closeTo(0.95, 0.015));
    });

    test('executes in background Isolate without throwing', () async {
      const simulator = DprSimulator();
      final result = await simulator.runInIsolate(
        attack: testAttack,
        targetAc: 16,
        iterations: 10000,
      );

      expect(result.iterations, equals(10000));
      expect(result.hitCount, isPositive);
      expect(result.meanDamage, isPositive);
    });
  });
}
