import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';

void main() {
  group('Summon Preset Budget Characterization Test', () {
    test(
        'records budget for spell levels 1 to 9 across all presets with custom budget calculations',
        () {
      final expectedBudgets = <String, Map<int, int>>{
        'conjure_animals': {
          1: 8,
          2: 8,
          3: 8,
          4: 8,
          5: 16,
          6: 16,
          7: 24,
          8: 24,
          9: 32,
        },
        'animate_dead': {
          1: 1,
          2: 1,
          3: 1,
          4: 3,
          5: 5,
          6: 7,
          7: 9,
          8: 11,
          9: 13,
        },
        'create_undead': {
          1: 3,
          2: 3,
          3: 3,
          4: 3,
          5: 3,
          6: 3,
          7: 4,
          8: 5,
          9: 6,
        },
        'animate_objects': {
          1: 10,
          2: 10,
          3: 10,
          4: 10,
          5: 10,
          6: 12,
          7: 14,
          8: 16,
          9: 18,
        },
        'conjure_elemental': {
          1: 1,
          2: 1,
          3: 1,
          4: 1,
          5: 1,
          6: 1,
          7: 1,
          8: 1,
          9: 1,
        },
        'conjure_minor_elementals': {
          1: 8,
          2: 8,
          3: 8,
          4: 8,
          5: 8,
          6: 16,
          7: 16,
          8: 24,
          9: 24,
        },
        'giant_insect': {
          1: 10,
          2: 10,
          3: 10,
          4: 10,
          5: 10,
          6: 10,
          7: 10,
          8: 10,
          9: 10,
        },
      };

      for (final entry in expectedBudgets.entries) {
        final preset = SrdSummonsLibrary.allPresets.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => throw StateError('Preset ${entry.key} not found'),
        );

        for (int lvl = 1; lvl <= 9; lvl++) {
          final actual = preset.calculateMaxPoints(lvl);
          final expected = entry.value[lvl]!;
          expect(
            actual,
            equals(expected),
            reason:
                '${entry.key} at spell level $lvl should have budget $expected but got $actual',
          );
        }
      }
    });
  });
}
