import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/creature_dpr_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Monster _makeIncompleteMonster({
  required String slug,
  required String name,
  int? armorClass = 14,
  int? hitPoints = 45,
  String? challengeRating = '2',
}) {
  return Monster.singleEdition(
    id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
    name: name,
    size: 'Medium',
    monsterType: 'Aberration',
    alignment: 'unaligned',
    armorClass: armorClass,
    hitPoints: hitPoints,
    hitDieFormula: '6d8 + 18',
    challengeRating: challengeRating,
    actionsMarkdown:
        '**Slam.** Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 8 (1d8 + 4) bludgeoning damage.',
  );
}

void main() {
  group('Fix 7.1 arena refusal and DPR behavior for monsters with unknown facts', () {
    test('arena refuses monster missing armor class before match naming armor class', () {
      final noAcMonster = _makeIncompleteMonster(
        slug: 'hb-no-ac',
        name: 'Glass Phantom',
        armorClass: null,
      );
      final goblin = MonsterCodexLibrary.allMonsters.firstWhere(
        (m) => m.name.toLowerCase().contains('goblin'),
      );

      final combatantA = ArenaCombatant.fromMonster(
        id: 'a_no_ac',
        monster: noAcMonster,
        team: ArenaTeam.teamA,
      );
      final combatantB = ArenaCombatant.fromMonster(
        id: 'b_goblin',
        monster: goblin,
        team: ArenaTeam.teamB,
      );

      final engine = ArenaCombatEngine(rng: Random(1));
      expect(
        () => engine.simulateMatch(
          initialTeamA: [combatantA],
          initialTeamB: [combatantB],
          maxRounds: 3,
        ),
        throwsA(
          isA<InvalidArenaChallengeRatingException>()
              .having((e) => e.combatantName, 'combatantName', 'Glass Phantom')
              .having((e) => e.missingFacts, 'missingFacts', contains('armor class'))
              .having((e) => e.message, 'message', contains('armor class')),
        ),
      );
    });

    test('arena refuses monster missing hit points or challenge rating or unreadable CR', () {
      final goblin = MonsterCodexLibrary.allMonsters.firstWhere(
        (m) => m.name.toLowerCase().contains('goblin'),
      );
      final combatantB = ArenaCombatant.fromMonster(
        id: 'b_goblin',
        monster: goblin,
        team: ArenaTeam.teamB,
      );
      final engine = ArenaCombatEngine(rng: Random(2));

      final noHpMonster = _makeIncompleteMonster(
        slug: 'hb-no-hp',
        name: 'Hollow Husk',
        hitPoints: null,
      );
      expect(
        () => engine.simulateMatch(
          initialTeamA: [
            ArenaCombatant.fromMonster(
              id: 'a_no_hp',
              monster: noHpMonster,
              team: ArenaTeam.teamA,
            ),
          ],
          initialTeamB: [combatantB],
          maxRounds: 3,
        ),
        throwsA(
          isA<InvalidArenaChallengeRatingException>()
              .having((e) => e.missingFacts, 'missingFacts', contains('hit points'))
              .having((e) => e.message, 'message', contains('hit points')),
        ),
      );

      final variesCrMonster = _makeIncompleteMonster(
        slug: 'hb-varies-cr',
        name: 'Varies Mimic',
        challengeRating: 'varies',
      );
      expect(
        () => engine.simulateMatch(
          initialTeamA: [
            ArenaCombatant.fromMonster(
              id: 'a_varies',
              monster: variesCrMonster,
              team: ArenaTeam.teamA,
            ),
          ],
          initialTeamB: [combatantB],
          maxRounds: 3,
        ),
        throwsA(
          isA<InvalidArenaChallengeRatingException>()
              .having((e) => e.challengeRatingText, 'challengeRatingText', 'varies')
              .having((e) => e.message, 'message', contains('varies')),
        ),
      );
    });

    testWidgets('DPR view shows no DPR and DPR sort puts unknown-fact monsters last', (tester) async {
      final incomplete = _makeIncompleteMonster(
        slug: 'hb-no-dpr',
        name: 'Aaa Incomplete Wraith',
        armorClass: null,
      );
      final wolf = MonsterCodexLibrary.getMonsterByName('Wolf')!;

      expect(incomplete.calculateBaselineDpr(DmRulesEdition.v2024), isNull);
      expect(wolf.calculateBaselineDpr(DmRulesEdition.v2024), isNotNull);

      final sorted = [incomplete, wolf]
        ..sort((a, b) => compareMonstersByDprDescending(a, b, DmRulesEdition.v2024));
      expect(sorted.last.id.slug, equals('hb-no-dpr'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatureDprView(statBlock: incomplete.statBlock2024),
          ),
        ),
      );
      expect(find.textContaining('DPR unavailable'), findsOneWidget);
    });
  });
}
