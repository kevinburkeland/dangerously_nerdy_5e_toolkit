import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_preset_matchups.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

import '../support/arena_goldens_codec.dart';

void main() {
  group('Fix 4.1: Arena match goldens for fixed seeds', () {
    test('determinism control: preset matchup run twice with Random(7) is identical',
        () {
      final preset = ArenaPresetMatchup.defaultPresets.first;
      final run1 = runPresetMatchRecord(
        preset: preset,
        edition: DmRulesEdition.v2024,
        environment: ArenaEnvironment.colosseum,
        strategy: ArenaTargetingStrategy.focusLowestHp,
        seed: 7,
      );
      final run2 = runPresetMatchRecord(
        preset: preset,
        edition: DmRulesEdition.v2024,
        environment: ArenaEnvironment.colosseum,
        strategy: ArenaTargetingStrategy.focusLowestHp,
        seed: 7,
      );
      final diff = compareMatchRecords(run1, run2);
      expect(diff, isNull, reason: diff ?? '');
    });

    test('preset matches golden matches engine output field by field', () {
      final expected = readJsonListFixture(kPresetMatchesFile);
      final actual = buildAllPresetMatchRecords();
      expect(actual.length, equals(expected.length));

      for (var i = 0; i < expected.length; i++) {
        final diff = compareMatchRecords(expected[i], actual[i]);
        if (diff != null) {
          fail(diff);
        }
      }
    });

    test('all arena monster picker creatures 1v1 duels golden matches field by field',
        () {
      final expected = readJsonListFixture(kCreatureDuelsFile);
      final actual = buildAllCreatureDuelRecords();
      expect(actual.length, equals(expected.length));

      for (var i = 0; i < expected.length; i++) {
        final diff = compareMatchRecords(expected[i], actual[i]);
        if (diff != null) {
          fail(diff);
        }
      }
    });

    test('synchronous runMonteCarlo (200 iterations) golden matches every non-clock field',
        () {
      final expected = readJsonListFixture(kMonteCarloFile);
      final actual = buildAllMonteCarloRecords();
      expect(actual.length, equals(expected.length));

      const fields = <String>[
        'matchKey',
        'matchup',
        'iterations',
        'teamAWins',
        'teamBWins',
        'draws',
        'averageRounds',
        'minRounds',
        'maxRounds',
        'avgTeamASurvivors',
        'avgTeamBSurvivors',
        'avgTeamASurvivingHpPercent',
        'avgTeamBSurvivingHpPercent',
      ];
      for (var i = 0; i < expected.length; i++) {
        final key = expected[i]['matchKey'];
        for (final f in fields) {
          expect(
            actual[i][f],
            equals(expected[i][f]),
            reason: 'Monte Carlo mismatch in $key field "$f"',
          );
        }
      }
    });
  });
}
