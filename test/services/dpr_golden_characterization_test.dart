import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dpr_calculator_engine.dart';

void main() {
  group('DPR Golden Characterization', () {
    test('matches all attack and save rows in test/fixtures/dpr_golden.json', () {
      final raw = File('test/fixtures/dpr_golden.json').readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final attackRows = (data['attackRows'] as List<dynamic>).cast<Map<String, dynamic>>();
      final saveRows = (data['saveRows'] as List<dynamic>).cast<Map<String, dynamic>>();

      expect(attackRows.length, equals(10488));
      expect(saveRows.length, equals(1638));

      for (final row in attackRows) {
        final bonus = (row['bonus'] as num).toDouble();
        final ac = row['ac'] as int;
        final critThreshold = row['critThreshold'] as int;
        final adv = AdvantageType.values.byName(row['advantage'] as String);
        final halflingLuck = row['halflingLuck'] as bool;

        final isBless = bonus == 2.5;
        final action = DprAttackAction(
          id: 'golden_atk',
          name: 'Golden Attack',
          attackBonus: isBless ? 0 : bonus.toInt(),
          diceCount: 1,
          diceSides: 8,
          damageBonus: 4,
          damageType: 'slashing',
          critThreshold: critThreshold,
          attackBuffDiceSides: isBless ? 4 : 0,
        );

        final hit = DprCalculatorEngine.calculateHitProbability(
          bonus,
          ac,
          adv,
          hasHalflingLuck: halflingLuck,
        );
        final crit = DprCalculatorEngine.calculateCritProbability(
          adv,
          critThreshold: critThreshold,
          hasHalflingLuck: halflingLuck,
        );
        final point = DprCalculatorEngine.calculateSingleAttackDpr(
          action,
          ac,
          adv,
          hasHalflingLuck: halflingLuck,
        );

        expect(hit, closeTo((row['hit'] as num).toDouble(), 1e-12),
            reason: 'hit mismatch at $row');
        expect(crit, closeTo((row['crit'] as num).toDouble(), 1e-12),
            reason: 'crit mismatch at $row');
        expect(point.hitChance, closeTo((row['dprHit'] as num).toDouble(), 1e-12),
            reason: 'dprHit mismatch at $row');
        expect(point.critChance, closeTo((row['dprCrit'] as num).toDouble(), 1e-12),
            reason: 'dprCrit mismatch at $row');
        expect(point.dpr, closeTo((row['dpr'] as num).toDouble(), 1e-12),
            reason: 'dpr mismatch at $row');
      }

      for (final row in saveRows) {
        final dc = row['dc'] as int;
        final saveBonus = row['saveBonus'] as int;
        final mode = row['mode'] as String;

        final fail = DprCalculatorEngine.calculateSaveFailureProbability(
          saveDc: dc,
          targetSaveBonus: saveBonus,
          targetHasAdvantage: mode == 'advantage',
          targetHasDisadvantage: mode == 'disadvantage',
        );

        expect(fail, closeTo((row['fail'] as num).toDouble(), 1e-12),
            reason: 'save fail mismatch at $row');
      }
    });
  });
}
