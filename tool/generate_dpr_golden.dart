import 'dart:convert';
import 'dart:io';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/dpr_calculator_engine.dart';

void main() {
  final attackRows = <Map<String, dynamic>>[];
  final bonuses = <double>[
    for (int b = -2; b <= 15; b++) b.toDouble(),
    2.5, // Fractional Bless-style bonus (0 + 1d4 expected 2.5)
  ];

  for (final bonus in bonuses) {
    final isBless = bonus == 2.5;
    final action = DprAttackAction(
      id: 'golden_atk',
      name: 'Golden Attack',
      attackBonus: isBless ? 0 : bonus.toInt(),
      diceCount: 1,
      diceSides: 8,
      damageBonus: 4,
      damageType: 'slashing',
      attackBuffDiceSides: isBless ? 4 : 0,
    );

    for (int ac = 8; ac <= 30; ac++) {
      for (final critThreshold in const [18, 19, 20]) {
        final actionWithCrit = action.copyWith(critThreshold: critThreshold);
        for (final adv in AdvantageType.values) {
          for (final halflingLuck in const [false, true]) {
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
              actionWithCrit,
              ac,
              adv,
              hasHalflingLuck: halflingLuck,
            );

            attackRows.add({
              'bonus': bonus,
              'ac': ac,
              'critThreshold': critThreshold,
              'advantage': adv.name,
              'halflingLuck': halflingLuck,
              'hit': hit,
              'crit': crit,
              'dprHit': point.hitChance,
              'dprCrit': point.critChance,
              'dpr': point.dpr,
            });
          }
        }
      }
    }
  }

  final saveRows = <Map<String, dynamic>>[];
  for (int dc = 5; dc <= 30; dc++) {
    for (int saveBonus = -5; saveBonus <= 15; saveBonus++) {
      for (final mode in const ['normal', 'advantage', 'disadvantage']) {
        final fail = DprCalculatorEngine.calculateSaveFailureProbability(
          saveDc: dc,
          targetSaveBonus: saveBonus,
          targetHasAdvantage: mode == 'advantage',
          targetHasDisadvantage: mode == 'disadvantage',
        );
        saveRows.add({
          'dc': dc,
          'saveBonus': saveBonus,
          'mode': mode,
          'fail': fail,
        });
      }
    }
  }

  final payload = {
    'attackRows': attackRows,
    'saveRows': saveRows,
  };

  final file = File('test/fixtures/dpr_golden.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
  stdout.writeln('Wrote ${attackRows.length} attackRows and ${saveRows.length} saveRows to ${file.path}');
}
