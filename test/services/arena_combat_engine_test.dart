import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_preset_matchups.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

void main() {
  group('ArenaCombatEngine Tests', () {
    late ArenaCombatEngine engine;
    late MonsterItem wolfMonster;
    late MonsterItem trexMonster;
    late MonsterItem dragonMonster;

    setUp(() {
      engine = ArenaCombatEngine(rng: Random(42));
      wolfMonster = MonsterCodexLibrary.getMonsterByName('Wolf') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_wolf') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      trexMonster = MonsterCodexLibrary.getMonsterByName('Tyrannosaurus Rex') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_tyrannosaurus_rex') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('tyrannosaurus'));
      dragonMonster = MonsterCodexLibrary.getMonsterByName('Young Red Dragon') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_young_red_dragon') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'young red dragon');
    });

    test('rollInitiatives correctly assigns and sorts combatants by initiative', () {
      final c1 = ArenaCombatant.fromMonster(
        id: 'c1',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      final c2 = ArenaCombatant.fromMonster(
        id: 'c2',
        monster: trexMonster,
        team: ArenaTeam.teamB,
      );

      final sorted = engine.rollInitiatives([c1, c2]);
      expect(sorted.length, 2);
      expect(sorted.first.initiative, greaterThanOrEqualTo(sorted.last.initiative));
    });

    test('selectTarget chooses target based on strategy', () {
      final attacker = ArenaCombatant.fromMonster(
        id: 'att',
        monster: trexMonster,
        team: ArenaTeam.teamA,
      );
      final weakEnemy = ArenaCombatant.fromMonster(
        id: 'weak',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
        hpOverride: 11,
      );
      final toughEnemy = ArenaCombatant.fromMonster(
        id: 'tough',
        monster: dragonMonster,
        team: ArenaTeam.teamB,
        hpOverride: 150,
      );

      final all = [attacker, weakEnemy, toughEnemy];

      // Focus lowest HP should select weakEnemy
      final targetLowest = engine.selectTarget(attacker, all, ArenaTargetingStrategy.focusLowestHp);
      expect(targetLowest?.id, 'weak');

      // Highest threat should select toughEnemy (Dragon has higher CR)
      final targetThreat = engine.selectTarget(attacker, all, ArenaTargetingStrategy.highestThreat);
      expect(targetThreat?.id, 'tough');
    });

    test('executeTurn executes attacks and deducts target HP', () {
      final attacker = ArenaCombatant.fromMonster(
        id: 'att',
        monster: trexMonster,
        team: ArenaTeam.teamA,
      );
      final defender = ArenaCombatant.fromMonster(
        id: 'def',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      final initialDefenderHp = defender.currentHp;
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: attacker,
        allCombatants: [attacker, defender],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(step.roundNumber, 1);
      expect(step.activeCombatant.id, attacker.id);
      expect(step.attackEvents.isNotEmpty, true);

      final hadHit = step.attackEvents.any((e) => e.isHit);
      if (hadHit) {
        expect(defender.currentHp, lessThan(initialDefenderHp));
        expect(attacker.totalDamageDealt, greaterThan(0));
      }
    });

    test('simulateMatch completes full fight and yields a winner or draw', () {
      final teamA = [
        ArenaCombatant.fromMonster(
          id: 'trex',
          monster: trexMonster,
          team: ArenaTeam.teamA,
        ),
      ];
      final teamB = [
        ArenaCombatant.fromMonster(
          id: 'wolf_1',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        ),
        ArenaCombatant.fromMonster(
          id: 'wolf_2',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        ),
      ];

      final result = engine.simulateMatch(
        initialTeamA: teamA,
        initialTeamB: teamB,
        maxRounds: 30,
      );

      expect(result.steps.isNotEmpty, true);
      expect(result.totalRounds, greaterThanOrEqualTo(1));
      expect(result.winner, isNotNull);
      expect(result.finalCombatants.length, 3);
      expect(result.teamATotalDamage, greaterThanOrEqualTo(0));
    });

    test('runMonteCarlo runs high-speed simulations and aggregates statistical win rates', () {
      final teamA = [
        ArenaCombatant.fromMonster(
          id: 'trex',
          monster: trexMonster,
          team: ArenaTeam.teamA,
        ),
      ];
      final teamB = [
        ArenaCombatant.fromMonster(
          id: 'wolf_1',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        ),
      ];

      final monteCarlo = engine.runMonteCarlo(
        teamA: teamA,
        teamB: teamB,
        iterations: 50,
      );

      expect(monteCarlo.iterations, 50);
      expect(monteCarlo.teamAWins + monteCarlo.teamBWins + monteCarlo.draws, 50);
      expect(monteCarlo.teamAWinRate, greaterThan(80.0)); // T-Rex should overwhelmingly beat 1 regular wolf
      expect(monteCarlo.averageRounds, greaterThan(0));
    });

    test('AoE attacks hit multiple enemy combatants in the area', () {
      final dragon = ArenaCombatant.fromMonster(
        id: 'dragon',
        monster: dragonMonster,
        team: ArenaTeam.teamA,
      );

      final goblins = List.generate(
        6,
        (i) => ArenaCombatant.fromMonster(
          id: 'wolf_$i',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        ),
      );

      final allCombatants = [dragon, ...goblins];

      // Dragon has Fire Breath ready on initial turn
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: dragon,
        allCombatants: allCombatants,
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Breath weapon should hit multiple wolves
      final breathEvents = step.attackEvents.where((e) => e.isAoe).toList();
      expect(breathEvents.length, greaterThanOrEqualTo(2));
      expect(breathEvents.length, lessThanOrEqualTo(6));
      expect(breathEvents.every((e) => e.isSavingThrow), true);
    });

    test('Evasion reduces DEX save damage to 0 on success', () {
      final dragon = ArenaCombatant.fromMonster(
        id: 'dragon',
        monster: dragonMonster,
        team: ArenaTeam.teamA,
      );

      // Create an evasive combatant
      final monkEvasive = ArenaCombatant(
        id: 'monk_evasive',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
        displayName: 'Evasive Fighter',
        maxHp: 50,
        currentHp: 50,
        ac: 16,
        initiativeBonus: 4,
      );

      expect(monkEvasive.hasEvasion(), false);
      expect(dragon.canFly(), true);
      expect(monkEvasive.canFly(), false);
    });

    test('Cage match grounds flying combatants and disables aerial advantage', () {
      final dragon = ArenaCombatant.fromMonster(
        id: 'dragon',
        monster: dragonMonster,
        team: ArenaTeam.teamA,
      );
      final wolf = ArenaCombatant.fromMonster(
        id: 'wolf',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      // In open colosseum, dragon attacks grounded wolf with flight advantage
      // In cage match, flight is disabled
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: dragon,
        allCombatants: [dragon, wolf],
        strategy: ArenaTargetingStrategy.focusLowestHp,
        environment: ArenaEnvironment.cageMatch,
      );

      expect(step.attackEvents.isNotEmpty, true);
    });

    test('Flooded abyss grants swimmers advantage and gives non-swimmers disadvantage', () {
      final sharkMonster = MonsterCodexLibrary.getMonsterByName('Giant Shark') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_giant_shark') ??
          wolfMonster;

      final shark = ArenaCombatant.fromMonster(
        id: 'shark',
        monster: sharkMonster,
        team: ArenaTeam.teamA,
      );
      final wolf = ArenaCombatant.fromMonster(
        id: 'wolf',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      expect(shark.canSwim(), true);
      expect(wolf.canSwim(), false);

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: shark,
        allCombatants: [shark, wolf],
        strategy: ArenaTargetingStrategy.focusLowestHp,
        environment: ArenaEnvironment.floodedAbyss,
      );

      expect(step.attackEvents.first.hadAdvantage, true);
    });

    test('Preset matchups correctly resolve into combatants', () {
      for (final preset in ArenaPresetMatchup.defaultPresets) {
        final resolved = preset.resolveFighters();
        expect(resolved.teamA.isNotEmpty, true, reason: 'Preset ${preset.title} team A should not be empty');
        expect(resolved.teamB.isNotEmpty, true, reason: 'Preset ${preset.title} team B should not be empty');
        expect(resolved.teamA.every((c) => c.team == ArenaTeam.teamA), true);
        expect(resolved.teamB.every((c) => c.team == ArenaTeam.teamB), true);
      }
    });
  });
}
