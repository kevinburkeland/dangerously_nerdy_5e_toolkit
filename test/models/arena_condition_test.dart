import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  group('ArenaCondition & ActiveCondition Model Tests', () {
    test('ArenaCondition properties and metadata are defined for all 5e conditions', () {
      expect(ArenaCondition.values.length, greaterThanOrEqualTo(15));

      for (final cond in ArenaCondition.values) {
        expect(cond.label.isNotEmpty, true);
        expect(cond.shortCode.isNotEmpty, true);
        expect(cond.shortCode.length, lessThanOrEqualTo(4));
        expect(cond.penaltySummary.isNotEmpty, true);
      }

      expect(ArenaCondition.poisoned.shortCode, 'POI');
      expect(ArenaCondition.prone.shortCode, 'PRN');
      expect(ArenaCondition.stunned.shortCode, 'STN');
      expect(ArenaCondition.paralyzed.shortCode, 'PAR');
      expect(ArenaCondition.restrained.shortCode, 'RST');
      expect(ArenaCondition.concentration.shortCode, 'CNC');
    });

    test('ActiveCondition duration tracking, badges, and turn ticking', () {
      const infiniteCondition = ActiveCondition(condition: ArenaCondition.poisoned);
      expect(infiniteCondition.hasFiniteDuration, false);
      expect(infiniteCondition.durationBadge, '∞');
      expect(infiniteCondition.durationDisplay, contains('Until End of Combat'));
      expect(infiniteCondition.isExpired, false);

      final tickedInfinite = infiniteCondition.tickTurn();
      expect(tickedInfinite.durationRounds, null);

      const timedCondition = ActiveCondition(
        condition: ArenaCondition.stunned,
        durationRounds: 2,
        source: 'Monk Stunning Strike',
      );
      expect(timedCondition.hasFiniteDuration, true);
      expect(timedCondition.durationBadge, '2r');
      expect(timedCondition.durationDisplay, '2 rounds remaining');
      expect(timedCondition.isExpired, false);

      final round1 = timedCondition.tickTurn();
      expect(round1.durationRounds, 1);
      expect(round1.durationBadge, '1r');
      expect(round1.durationDisplay, '1 round remaining');
      expect(round1.isExpired, false);

      final round2 = round1.tickTurn();
      expect(round2.durationRounds, 0);
      expect(round2.isExpired, true);
    });

    test('ArenaCombatant applies, toggles, ticks, and expires conditions', () {
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      final combatant = ArenaCombatant.fromMonster(
        id: 'test_wolf_1',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
        customName: 'Dire Wolf Test',
      );

      expect(combatant.conditions.isEmpty, true);
      expect(combatant.activeConditions.isEmpty, true);

      // Apply condition with duration
      combatant.applyCondition(
        ArenaCondition.stunned,
        (sides) => 4,
        DmRulesEdition.v2024,
        durationRounds: 1,
        source: 'Stunning Strike',
      );

      expect(combatant.hasCondition(ArenaCondition.stunned), true);
      expect(combatant.isStunned, true);
      expect(combatant.isIncapacitated, true);
      expect(combatant.activeConditions.length, 1);
      expect(combatant.activeConditions.first.durationRounds, 1);

      // Apply ActiveCondition
      combatant.applyActiveCondition(
        const ActiveCondition(
          condition: ArenaCondition.poisoned,
          durationRounds: 3,
        ),
      );

      expect(combatant.hasCondition(ArenaCondition.poisoned), true);
      expect(combatant.conditions.length, 2);
      expect(combatant.activeConditions.length, 2);

      // Tick turn: Stunned should expire (1 -> 0), Poisoned decreases (3 -> 2)
      final expired = combatant.tickTurnConditions();
      expect(expired, contains(ArenaCondition.stunned));
      expect(combatant.hasCondition(ArenaCondition.stunned), false);
      expect(combatant.hasCondition(ArenaCondition.poisoned), true);
      expect(combatant.activeConditions.first.durationRounds, 2);

      // Toggle condition on / off
      final toggledOn = combatant.toggleCondition(ArenaCondition.prone);
      expect(toggledOn, true);
      expect(combatant.isProne, true);

      final toggledOff = combatant.toggleCondition(ArenaCondition.prone);
      expect(toggledOff, false);
      expect(combatant.isProne, false);

      // Clear all
      combatant.clearConditions();
      expect(combatant.conditions.isEmpty, true);
      expect(combatant.activeConditions.isEmpty, true);
    });

    test('ArenaCombatant clone and reset preserve and isolate condition collections', () {
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      final original = ArenaCombatant.fromMonster(
        id: 'test_wolf_2',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );
      original.applyActiveCondition(
        const ActiveCondition(condition: ArenaCondition.frightened, durationRounds: 2),
      );

      final cloned = original.clone();
      expect(cloned.hasCondition(ArenaCondition.frightened), true);
      expect(cloned.activeConditions.length, 1);

      // Mutate clone
      cloned.removeCondition(ArenaCondition.frightened);
      expect(cloned.hasCondition(ArenaCondition.frightened), false);
      expect(original.hasCondition(ArenaCondition.frightened), true); // Original unaffected

      final reset = original.reset();
      expect(reset.conditions.isEmpty, true);
      expect(reset.activeConditions.isEmpty, true);
    });
  });
}
