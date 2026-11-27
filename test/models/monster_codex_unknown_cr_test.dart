import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/monster_golden_serializer.dart';

void main() {
  group('Fix 7.2 codex test: unreadable and missing CR are unknown, not CR 0', () {
    tearDown(() {
      MonsterCodexLibrary.clearHomebrewMonsters();
    });

    testWidgets(
      'unreadable CR "varies" and missing CR appear in All CR only, sorted last, with raw text and em dash',
      (tester) async {
        final variesMonster = Monster.fromMap(const {
          'id': {'slug': 'hb-codex-varies', 'ruleset': 'homebrew'},
          'name': 'Zeta Varies Mimic',
          'size': 'Medium',
          'monsterType': 'Aberration',
          'alignment': 'chaotic neutral',
          'armorClass': 14,
          'hitPoints': 58,
          'hitDieFormula': '9d8 + 18',
          'challengeRating': 'varies',
          'actionsMarkdown': '',
          'customProperties': <String, dynamic>{},
        });
        final missingCrMonster = Monster.fromMap(const {
          'id': {'slug': 'hb-codex-missing-cr', 'ruleset': 'homebrew'},
          'name': 'Alpha Missing CR Entity',
          'size': 'Medium',
          'monsterType': 'Aberration',
          'alignment': 'unaligned',
          'armorClass': 12,
          'hitPoints': 30,
          'hitDieFormula': '4d8 + 12',
          'actionsMarkdown': '',
          'customProperties': <String, dynamic>{},
        });

        MonsterCodexLibrary.setHomebrewMonsters([variesMonster, missingCrMonster]);

        // 1. Both appear in All CR
        final allMonsters = MonsterCodexLibrary.allMonsters;
        expect(allMonsters.any((m) => m.id.slug == 'hb-codex-varies'), isTrue);
        expect(allMonsters.any((m) => m.id.slug == 'hb-codex-missing-cr'), isTrue);

        // 2. Neither appears in any numeric CR band
        final numericBands = <MonsterCrBand, List<Monster>>{
          MonsterCrBand.cr0ToQuarter: MonsterCodexLibrary.getCr0ToQuarterMonsters(),
          MonsterCrBand.crHalfToOne: MonsterCodexLibrary.getCrHalfToOneMonsters(),
          MonsterCrBand.crTwoToFour: MonsterCodexLibrary.getCrTwoToFourMonsters(),
          MonsterCrBand.crFiveToEight: MonsterCodexLibrary.getCrFiveToEightMonsters(),
          MonsterCrBand.crNinePlus: MonsterCodexLibrary.getCrNinePlusMonsters(),
        };
        for (final entry in numericBands.entries) {
          for (final target in [variesMonster, missingCrMonster]) {
            if (entry.value.any((m) => m.id.slug == target.id.slug)) {
              fail(
                'Monster "${target.name}" (${target.id.slug}) with unknown CR '
                'appeared in band ${entry.key.name} (${entry.key.label}); expected All CR only.',
              );
            }
          }
        }

        // 3. Both appear AFTER every known CR in BOTH crAscending and crDescending,
        // with unknown-CR ties broken by name ascending (Alpha before Zeta).
        for (final mode in [
          MonsterSortMode.crAscending,
          MonsterSortMode.crDescending,
        ]) {
          final sortedIds = sortMonsterIdsByMode(
            allMonsters,
            mode,
            DmRulesEdition.v2024,
          );
          final lastTwoSlugs = sortedIds.skip(sortedIds.length - 2).toList();
          expect(
            lastTwoSlugs,
            equals(['hb-codex-missing-cr', 'hb-codex-varies']),
            reason: 'Expected unknown-CR monsters last (ties by name) in ${mode.name}, '
                'got last two=$lastTwoSlugs',
          );
        }

        // 4. Card display text & XP unknown
        expect(variesMonster.challengeRatingValue, isNull);
        expect(variesMonster.xp, isNull);
        expect(missingCrMonster.challengeRatingValue, isNull);
        expect(missingCrMonster.xp, isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    MonsterCard(
                      monster: variesMonster,
                      isPinned: false,
                      onTogglePin: () {},
                      onTap: () {},
                    ),
                    MonsterCard(
                      monster: missingCrMonster,
                      isPinned: false,
                      onTogglePin: () {},
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('CR varies'), findsOneWidget);
        expect(find.text('CR —'), findsOneWidget);
      },
    );
  });
}
