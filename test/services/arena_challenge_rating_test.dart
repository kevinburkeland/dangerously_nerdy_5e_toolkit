import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/arena_simulator_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Monster _makeHomebrewMonster({
  required String name,
  required String crText,
  String actionsMarkdown =
      '**Bite.** Melee Weapon Attack: +19 to hit, reach 10 ft., one target. Hit: 36 (4d12 + 10) piercing damage. Target must make a Dexterity saving throw or be knocked prone.',
}) {
  return Monster.singleEdition(
    id: EntityId(
      slug: 'hb_${name.toLowerCase().replaceAll(' ', '_')}',
      ruleset: RulesetVersion.v2024,
    ),
    name: name,
    size: 'Gargantuan',
    monsterType: 'Monstrosity',
    alignment: 'Unaligned',
    armorClass: 25,
    hitPoints: 676,
    hitDieFormula: '33d20+330',
    challengeRating: crText,
    actionsMarkdown: actionsMarkdown,
    customProperties: const {
      'str': 30,
      'dex': 11,
      'con': 30,
      'int': 3,
      'wis': 11,
      'cha': 11,
    },
  );
}

void main() {
  group('Fix 2.2: homebrew CR with XP tail in arena', () {
    test(
      'homebrew monster with CR "30 (155,000 XP)" parses to CR 30 and PB +9 without throwing',
      () {
        final hb = _makeHomebrewMonster(
          name: 'Iron Behemoth',
          crText: '30 (155,000 XP)',
        );
        final item = hb;
        expect(item.challengeRatingValue, 30.0);
        expect(proficiencyBonusForChallengeRating(item.challengeRatingValue), 9);

        final combatantA = ArenaCombatant.fromMonster(
          id: 'hb_a',
          monster: item,
          team: ArenaTeam.teamA,
          edition: DmRulesEdition.v2024,
        );
        final goblin = MonsterCodexLibrary.allMonsters.firstWhere(
          (m) => m.name.toLowerCase().contains('goblin'),
        );
        final combatantB = ArenaCombatant.fromMonster(
          id: 'goblin_b',
          monster: goblin,
          team: ArenaTeam.teamB,
          edition: DmRulesEdition.v2024,
        );

        final engine = ArenaCombatEngine(rng: Random(42));
        final result = engine.simulateMatch(
          initialTeamA: [combatantA],
          initialTeamB: [combatantB],
          edition: DmRulesEdition.v2024,
          maxRounds: 3,
        );
        expect(result.steps, isNotEmpty);
      },
    );
  });

  group('Fix 2.3: arena refuses out-of-range challenge ratings before the match', () {
    test(
      'engine entry points throw InvalidArenaChallengeRatingException naming creature and CR text for "CR 31"',
      () async {
        final titan = _makeHomebrewMonster(
          name: 'Astral Titan',
          crText: 'CR 31',
          actionsMarkdown:
              '**Starburst Cone.** Each creature in a 30-foot cone must make a Dexterity saving throw, taking 28 (8d6) fire damage on a failed save.',
        );
        final combatantA = ArenaCombatant(
          id: 'titan_a',
          monster: titan,
          team: ArenaTeam.teamA,
          displayName: titan.name,
          maxHp: titan.hp,
          currentHp: titan.hp,
          ac: titan.ac,
          initiativeBonus: 0,
        );
        final goblin = MonsterCodexLibrary.allMonsters.firstWhere(
          (m) => m.name.toLowerCase().contains('goblin'),
        );
        final combatantB = ArenaCombatant.fromMonster(
          id: 'goblin_b',
          monster: goblin,
          team: ArenaTeam.teamB,
          edition: DmRulesEdition.v2024,
        );

        final engine = ArenaCombatEngine(rng: Random(7));
        final matcher = throwsA(
          isA<InvalidArenaChallengeRatingException>()
              .having((e) => e.combatantName, 'combatantName', 'Astral Titan')
              .having((e) => e.challengeRatingText, 'challengeRatingText', 'CR 31')
              .having((e) => e.message, 'message', contains('Astral Titan'))
              .having((e) => e.message, 'message', contains('CR 31')),
        );

        expect(
          () => engine.simulateMatch(
            initialTeamA: [combatantA],
            initialTeamB: [combatantB],
            edition: DmRulesEdition.v2024,
            maxRounds: 3,
          ),
          matcher,
        );
        expect(
          () => engine.runMonteCarlo(
            teamA: [combatantA],
            teamB: [combatantB],
            edition: DmRulesEdition.v2024,
            iterations: 5,
            maxRounds: 3,
          ),
          matcher,
        );
        await expectLater(
          engine.simulateMatchAsync(
            initialTeamA: [combatantA],
            initialTeamB: [combatantB],
            edition: DmRulesEdition.v2024,
            maxRounds: 3,
            seed: 7,
          ),
          matcher,
        );
        await expectLater(
          engine.runMonteCarloAsync(
            teamA: [combatantA],
            teamB: [combatantB],
            edition: DmRulesEdition.v2024,
            iterations: 5,
            maxRounds: 3,
            seed: 7,
          ),
          matcher,
        );
      },
    );

    testWidgets(
      'ArenaSimulatorScreen shows error message when starting a match with a "CR 31" creature',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final titan = _makeHomebrewMonster(
          name: 'Astral Titan',
          crText: 'CR 31',
        );
        final combatantA = ArenaCombatant(
          id: 'titan_ui',
          monster: titan,
          team: ArenaTeam.teamA,
          displayName: titan.name,
          maxHp: titan.hp,
          currentHp: titan.hp,
          ac: titan.ac,
          initiativeBonus: 0,
        );
        final goblin = MonsterCodexLibrary.allMonsters.firstWhere(
          (m) => m.name.toLowerCase().contains('goblin'),
        );
        final combatantB = ArenaCombatant.fromMonster(
          id: 'goblin_ui',
          monster: goblin,
          team: ArenaTeam.teamB,
          edition: DmRulesEdition.v2024,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ArenaSimulatorScreen(
              initialEdition: DmRulesEdition.v2024,
              initialTeamA: [combatantA],
              initialTeamB: [combatantB],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start Battle'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Astral Titan'), findsWidgets);
        expect(find.textContaining('CR 31'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
