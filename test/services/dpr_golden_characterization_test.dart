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
          critThreshold: critThreshold,
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

    test('old vs new DPR golden only changes in groups (a), (b), and (c)', () {
      final oldData = jsonDecode(File('test/fixtures/dpr_golden_pre_step7.json').readAsStringSync())
          as Map<String, dynamic>;
      final newData = jsonDecode(File('test/fixtures/dpr_golden.json').readAsStringSync())
          as Map<String, dynamic>;

      final oldAtk = (oldData['attackRows'] as List<dynamic>).cast<Map<String, dynamic>>();
      final newAtk = (newData['attackRows'] as List<dynamic>).cast<Map<String, dynamic>>();
      final oldSave = (oldData['saveRows'] as List<dynamic>).cast<Map<String, dynamic>>();
      final newSave = (newData['saveRows'] as List<dynamic>).cast<Map<String, dynamic>>();

      expect(newAtk.length, equals(oldAtk.length));
      expect(newSave.length, equals(oldSave.length));

      var groupA = 0; // crit threshold < 20 and face needed to hit > threshold
      var groupB = 0; // save needed face <= 1 or > 20
      var groupC = 0; // value was clamped at 0.9975 (Halfling Luck on hit when needed <= 2)
      final outside = <String>[];

      for (var i = 0; i < oldAtk.length; i++) {
        final o = oldAtk[i];
        final n = newAtk[i];
        final changed = ((o['hit'] as num) - (n['hit'] as num)).abs() > 1e-12 ||
            ((o['crit'] as num) - (n['crit'] as num)).abs() > 1e-12 ||
            ((o['dprHit'] as num) - (n['dprHit'] as num)).abs() > 1e-12 ||
            ((o['dprCrit'] as num) - (n['dprCrit'] as num)).abs() > 1e-12 ||
            ((o['dpr'] as num) - (n['dpr'] as num)).abs() > 1e-12;
        if (!changed) continue;

        final bonus = (o['bonus'] as num).toDouble();
        final ac = o['ac'] as int;
        final thr = o['critThreshold'] as int;
        final luck = o['halflingLuck'] as bool;
        final needed = (ac - bonus).ceil();

        final inA = thr < 20 && needed > thr;
        // Group (c): old code had baseSingleHitP = (21 - needed.clamp(2,20))/20;
        // with Halfling Luck and needed <= 2, baseSingleHitP = 0.95 + 0.05*0.95 = 0.9975,
        // which was clamped at 0.9975 (actually 0.9975 == 0.95 * 1.05, wait: what if needed <= 2 without luck? No, 0.95! With luck: 0.9975! Wait: if needed <= 2, old code already gave 0.9975 which matches new code? Wait: let's see what changed!)
        final inC = luck && needed <= 2;

        if (inA) groupA++;
        if (inC) groupC++;
        if (!inA && !inC) {
          outside.add('ATK[$i]: bonus=$bonus ac=$ac thr=$thr luck=$luck old=${o['hit']}/${o['dpr']} new=${n['hit']}/${n['dpr']}');
        }
      }

      for (var i = 0; i < oldSave.length; i++) {
        final o = oldSave[i];
        final n = newSave[i];
        final changed = ((o['fail'] as num) - (n['fail'] as num)).abs() > 1e-12;
        if (!changed) continue;

        final dc = o['dc'] as int;
        final bonus = o['saveBonus'] as int;
        final needed = dc - bonus;
        final inB = needed <= 1 || needed > 20;
        if (inB) {
          groupB++;
        } else {
          outside.add('SAVE[$i]: dc=$dc bonus=$bonus mode=${o['mode']} old=${o['fail']} new=${n['fail']}');
        }
      }

      stdout.writeln('DPR golden diff counts: groupA=$groupA, groupB=$groupB, groupC=$groupC, outside=${outside.length}');
      expect(outside, isEmpty, reason: 'Changed rows outside (a),(b),(c):\n${outside.take(10).join('\n')}');
    });
  });
}
