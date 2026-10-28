import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

void main() {
  group('Arena Damage Defensive Modifiers Laws (AD-A to AD-E)', () {
    const fireAction = CreatureAction(
      name: 'Fire Blast',
      attackBonus: 100,
      attackType: 'Melee Weapon Attack',
      description:
          'Melee Weapon Attack: +100 to hit, reach 5 ft., one target. Hit: 22 (2d6 + 15) fire damage.',
      hitDamage: '22 (2d6 + 15) fire damage',
    );

    const attackerStatBlock = MinionStatBlock(
      id: 'attacker_mob',
      name: 'Fire Attacker',
      sizeDisplay: 'Medium',
      crDisplay: '1',
      ac: 10,
      maxHp: 200,
      attackBonus: 100,
      damageDiceCount: 2,
      damageDiceSides: 6,
      damageBonus: 15,
      damageType: 'fire',
      actions: [fireAction],
    );

    const attackerMob = MonsterItem(
      id: 'attacker_mob',
      name: 'Fire Attacker',
      statBlock2014: attackerStatBlock,
      statBlock2024: attackerStatBlock,
    );

    MonsterItem createDefender({
      String? vulnerabilities,
      String? resistances,
      String? immunities,
    }) {
      final statBlock = MinionStatBlock(
        id: 'defender_mob',
        name: 'Defender Mob',
        sizeDisplay: 'Medium',
        crDisplay: '1',
        ac: 10,
        maxHp: 500,
        attackBonus: 0,
        damageDiceCount: 0,
        damageDiceSides: 0,
        damageBonus: 0,
        damageType: 'bludgeoning',
        damageVulnerabilities: vulnerabilities,
        damageResistances: resistances,
        damageImmunities: immunities,
      );
      return MonsterItem(
        id: 'defender_mob',
        name: 'Defender Mob',
        statBlock2014: statBlock,
        statBlock2024: statBlock,
      );
    }

    int executeSingleAttack({
      required MonsterItem defenderMob,
      required ArenaEnvironment environment,
      int seed = 1,
    }) {
      final engine = ArenaCombatEngine(rng: Random(seed));
      final attacker = ArenaCombatant.fromMonster(
        id: 'att',
        monster: attackerMob,
        team: ArenaTeam.teamA,
      );
      final defender = ArenaCombatant.fromMonster(
        id: 'def',
        monster: defenderMob,
        team: ArenaTeam.teamB,
      );

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: attacker,
        allCombatants: [attacker, defender],
        strategy: ArenaTargetingStrategy.focusLowestHp,
        environment: environment,
      );

      expect(step.attackEvents, isNotEmpty);
      expect(step.attackEvents.first.isHit, isTrue);
      return step.attackEvents.first.damageDealt;
    }

    test('AD-A (control): no defenses, colosseum -> records odd fire damage X > 0', () {
      final x = executeSingleAttack(
        defenderMob: createDefender(),
        environment: ArenaEnvironment.colosseum,
      );
      expect(x > 0 && x.isOdd, isTrue,
          reason: 'Setup must yield positive odd damage to distinguish ordering; got $x');
    });

    test('AD-B: fire resistance and fire vulnerability, colosseum -> 2 * (X ~/ 2)', () {
      final x = executeSingleAttack(
        defenderMob: createDefender(),
        environment: ArenaEnvironment.colosseum,
      );
      final actual = executeSingleAttack(
        defenderMob: createDefender(
          resistances: 'fire',
          vulnerabilities: 'fire',
        ),
        environment: ArenaEnvironment.colosseum,
      );
      final expected = 2 * (x ~/ 2);
      expect(actual, equals(expected),
          reason:
              'Resistance before vulnerability on odd damage $x should yield $expected, but got $actual');
    });

    test('AD-C: fire resistance, Flooded Abyss -> X ~/ 2', () {
      final x = executeSingleAttack(
        defenderMob: createDefender(),
        environment: ArenaEnvironment.colosseum,
      );
      final actual = executeSingleAttack(
        defenderMob: createDefender(resistances: 'fire'),
        environment: ArenaEnvironment.floodedAbyss,
      );
      final expected = x ~/ 2;
      expect(actual, equals(expected),
          reason:
              'Multiple resistance sources count once in Flooded Abyss; expected $expected, got $actual');
    });

    test('AD-D (control): no defenses, Flooded Abyss -> X ~/ 2', () {
      final x = executeSingleAttack(
        defenderMob: createDefender(),
        environment: ArenaEnvironment.colosseum,
      );
      final actual = executeSingleAttack(
        defenderMob: createDefender(),
        environment: ArenaEnvironment.floodedAbyss,
      );
      final expected = x ~/ 2;
      expect(actual, equals(expected));
    });

    test('AD-E (control): fire immunity and fire vulnerability, colosseum -> 0', () {
      final actual = executeSingleAttack(
        defenderMob: createDefender(
          immunities: 'fire',
          vulnerabilities: 'fire',
        ),
        environment: ArenaEnvironment.colosseum,
      );
      expect(actual, equals(0));
    });
  });
}
