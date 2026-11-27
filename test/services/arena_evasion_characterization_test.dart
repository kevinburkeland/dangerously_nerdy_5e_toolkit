import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

MonsterItem _buildEvasionMonster(MonsterItem base, {required bool withEvasion}) {
  final sb = base.statBlock2024;
  final traits = withEvasion
      ? [
          ...sb.traits,
          const CreatureTrait(
            name: 'Evasion',
            description:
                'If subjected to an effect that allows a Dexterity saving throw to take only half damage, takes no damage on a success and half damage on a failure.',
          ),
        ]
      : sb.traits;
  final modifiedSb = MonsterStatBlock(
    id: withEvasion ? '${sb.id}_evasion' : '${sb.id}_no_evasion',
    name: withEvasion ? 'Evasive Target' : 'Standard Target',
    sizeDisplay: sb.sizeDisplay,
    crDisplay: sb.crDisplay,
    typeDisplay: sb.typeDisplay,
    alignment: sb.alignment,
    ac: sb.ac,
    maxHp: 200,
    speed: sb.speed,
    strScore: sb.strScore,
    dexScore: sb.dexScore,
    conScore: sb.conScore,
    intScore: sb.intScore,
    wisScore: sb.wisScore,
    chaScore: sb.chaScore,
    savingThrows: sb.savingThrows,
    skills: sb.skills,
    damageResistances: sb.damageResistances,
    damageImmunities: sb.damageImmunities,
    conditionImmunities: sb.conditionImmunities,
    senses: sb.senses,
    languages: sb.languages,
    traits: traits,
    actions: sb.actions,
    reactions: sb.reactions,
    legendaryActions: sb.legendaryActions,
    attackBonus: sb.attackBonus,
    damageDiceCount: sb.damageDiceCount,
    damageDiceSides: sb.damageDiceSides,
    damageBonus: sb.damageBonus,
    damageType: sb.damageType,
  );
  return MonsterItem(
    id: withEvasion ? '${base.id}_evasion' : '${base.id}_no_evasion',
    name: withEvasion ? 'Evasive Target' : 'Standard Target',
    statBlock2014: modifiedSb,
    statBlock2024: modifiedSb,
  );
}

void main() {
  group('Arena Evasion Save-Site Characterization', () {
    late MonsterItem wolfMonster;
    late MonsterItem dragonMonster;

    setUp(() {
      wolfMonster = MonsterCodexLibrary.allMonsters
          .firstWhere((m) => m.name.toLowerCase() == 'wolf');
      dragonMonster = MonsterCodexLibrary.allMonsters
          .firstWhere((m) => m.name.toLowerCase() == 'young red dragon');
    });

    test('Site 1: Caster multi-target AoE spell records exact damage and logs', () {
      final evasiveBase = _buildEvasionMonster(wolfMonster, withEvasion: true);
      final standardBase = _buildEvasionMonster(wolfMonster, withEvasion: false);

      // Seed 1: t_ev saves (0 dmg), t_std fails (29 dmg)
      {
        final engine = ArenaCombatEngine(rng: Random(1));
        final caster = ArenaCombatant.fromMonster(
            id: 'caster', monster: wolfMonster, team: ArenaTeam.teamA);
        caster.knownSpellIds.add('spell_fireball');
        caster.setMaxSpellSlot(3, 2);
        caster.setSpellSlot(3, 2);
        final tEvasive = ArenaCombatant.fromMonster(
            id: 't_ev', monster: evasiveBase, team: ArenaTeam.teamB);
        final tStd = ArenaCombatant.fromMonster(
            id: 't_std', monster: standardBase, team: ArenaTeam.teamB);

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: caster,
          allCombatants: [caster, tEvasive, tStd],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(2));
        expect(step.attackEvents[0].defenderId, equals('t_ev'));
        expect(step.attackEvents[0].damageDealt, equals(0));
        expect(
          step.attackEvents[0].summaryText,
          equals('EVADED! (Rolled 14 + 2 = 16 vs DC 11) took 0 fire damage via Evasion!'),
        );
        expect(step.attackEvents[1].defenderId, equals('t_std'));
        expect(step.attackEvents[1].damageDealt, equals(29));
        expect(
          step.attackEvents[1].summaryText,
          equals('Failed Save (Rolled 5 + 2 = 7 vs DC 11) took full: 29 fire damage'),
        );
      }

      // Seed 2: t_ev fails (17 half dmg), t_std saves (17 half dmg)
      {
        final engine = ArenaCombatEngine(rng: Random(2));
        final caster = ArenaCombatant.fromMonster(
            id: 'caster', monster: wolfMonster, team: ArenaTeam.teamA);
        caster.knownSpellIds.add('spell_fireball');
        caster.setMaxSpellSlot(3, 2);
        caster.setSpellSlot(3, 2);
        final tEvasive = ArenaCombatant.fromMonster(
            id: 't_ev', monster: evasiveBase, team: ArenaTeam.teamB);
        final tStd = ArenaCombatant.fromMonster(
            id: 't_std', monster: standardBase, team: ArenaTeam.teamB);

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: caster,
          allCombatants: [caster, tEvasive, tStd],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(2));
        expect(step.attackEvents[0].defenderId, equals('t_ev'));
        expect(step.attackEvents[0].damageDealt, equals(17));
        expect(
          step.attackEvents[0].summaryText,
          // Cleanup slice 12: was "Failed Save (Rolled 8 + 2 = 10 vs DC 11) took full: 17 fire damage"
          equals('Failed Save (Rolled 8 + 2 = 10 vs DC 11) took half: 17 fire damage (Evasion)'),
        );
        expect(step.attackEvents[1].defenderId, equals('t_std'));
        expect(step.attackEvents[1].damageDealt, equals(17));
        expect(
          step.attackEvents[1].summaryText,
          equals('Saved (Rolled 11 + 2 = 13 vs DC 11) took half: 17 fire damage'),
        );
      }
    });

    test('Site 2: Caster single-target AoE fallback records exact damage and logs', () {
      final evasiveBase = _buildEvasionMonster(wolfMonster, withEvasion: true);
      final standardBase = _buildEvasionMonster(wolfMonster, withEvasion: false);

      // Seed 1: failed save (evasive takes 15 half, standard takes 30 full)
      for (final useEvasion in [true, false]) {
        final engine = ArenaCombatEngine(rng: Random(1));
        final caster = ArenaCombatant.fromMonster(
            id: 'caster', monster: wolfMonster, team: ArenaTeam.teamA);
        caster.knownSpellIds.add('spell_fireball');
        caster.setMaxSpellSlot(3, 2);
        caster.setSpellSlot(3, 2);
        final target = ArenaCombatant.fromMonster(
          id: useEvasion ? 't_ev' : 't_std',
          monster: useEvasion ? evasiveBase : standardBase,
          team: ArenaTeam.teamB,
        );

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: caster,
          allCombatants: [caster, target],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(1));
        expect(step.attackEvents[0].damageDealt, equals(useEvasion ? 15 : 30));
        expect(
          step.attackEvents[0].summaryText,
          // Cleanup slice 12: was "Failed Save (Rolled 5 + 2 = 7 vs DC 11) took full: 15 fire damage"
          equals(useEvasion
              ? 'Failed Save (Rolled 5 + 2 = 7 vs DC 11) took half: 15 fire damage (Evasion)'
              : 'Failed Save (Rolled 5 + 2 = 7 vs DC 11) took full: 30 fire damage'),
        );
      }

      // Seed 3: successful save (evasive takes 0, standard takes 15 half)
      for (final useEvasion in [true, false]) {
        final engine = ArenaCombatEngine(rng: Random(3));
        final caster = ArenaCombatant.fromMonster(
            id: 'caster', monster: wolfMonster, team: ArenaTeam.teamA);
        caster.knownSpellIds.add('spell_fireball');
        caster.setMaxSpellSlot(3, 2);
        caster.setSpellSlot(3, 2);
        final target = ArenaCombatant.fromMonster(
          id: useEvasion ? 't_ev' : 't_std',
          monster: useEvasion ? evasiveBase : standardBase,
          team: ArenaTeam.teamB,
        );

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: caster,
          allCombatants: [caster, target],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(1));
        expect(step.attackEvents[0].damageDealt, equals(useEvasion ? 0 : 15));
        expect(
          step.attackEvents[0].summaryText,
          equals(useEvasion
              ? 'EVADED! Fireball dealt 0 fire damage via Evasion!'
              : 'Saved (Rolled 12 + 2 = 14 vs DC 11) took half: 15 fire damage'),
        );
      }
    });

    test('Site 3: Monster AoE breath weapon records exact damage and logs', () {
      final evasiveBase = _buildEvasionMonster(wolfMonster, withEvasion: true);
      final standardBase = _buildEvasionMonster(wolfMonster, withEvasion: false);

      // Seed 1: t_ev fails (33 half dmg), t_std fails (66 full dmg)
      {
        final engine = ArenaCombatEngine(rng: Random(1));
        final dragon = ArenaCombatant.fromMonster(
            id: 'dragon', monster: dragonMonster, team: ArenaTeam.teamA);
        final tEvasive = ArenaCombatant.fromMonster(
            id: 't_ev', monster: evasiveBase, team: ArenaTeam.teamB);
        final tStd = ArenaCombatant.fromMonster(
            id: 't_std', monster: standardBase, team: ArenaTeam.teamB);

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: dragon,
          allCombatants: [dragon, tEvasive, tStd],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(2));
        expect(step.attackEvents[0].defenderId, equals('t_ev'));
        expect(step.attackEvents[0].damageDealt, equals(33));
        expect(
          step.attackEvents[0].summaryText,
          // Cleanup slice 12: was "EVADED! (Rolled 13 + 2 = 15 vs DC 17) took 0 fire damage via Evasion!"
          equals('Failed Save (Rolled 13 + 2 = 15 vs DC 17) took half: 33 fire damage (Evasion)'),
        );
        expect(step.attackEvents[1].defenderId, equals('t_std'));
        expect(step.attackEvents[1].damageDealt, equals(66));
        expect(
          step.attackEvents[1].summaryText,
          equals('Failed Save (Rolled 1 + 2 = 3 vs DC 17) took full: 66 fire damage'),
        );
      }

      // Seed 2: t_ev saves (0 dmg), t_std fails (56 full dmg)
      {
        final engine = ArenaCombatEngine(rng: Random(2));
        final dragon = ArenaCombatant.fromMonster(
            id: 'dragon', monster: dragonMonster, team: ArenaTeam.teamA);
        final tEvasive = ArenaCombatant.fromMonster(
            id: 't_ev', monster: evasiveBase, team: ArenaTeam.teamB);
        final tStd = ArenaCombatant.fromMonster(
            id: 't_std', monster: standardBase, team: ArenaTeam.teamB);

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: dragon,
          allCombatants: [dragon, tEvasive, tStd],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.length, equals(2));
        expect(step.attackEvents[0].defenderId, equals('t_ev'));
        expect(step.attackEvents[0].damageDealt, equals(0));
        expect(
          step.attackEvents[0].summaryText,
          equals('EVADED! (Rolled 20 + 2 = 22 vs DC 17) took 0 fire damage via Evasion!'),
        );
        expect(step.attackEvents[1].defenderId, equals('t_std'));
        expect(step.attackEvents[1].damageDealt, equals(56));
        expect(
          step.attackEvents[1].summaryText,
          equals('Failed Save (Rolled 13 + 2 = 15 vs DC 17) took full: 56 fire damage'),
        );
      }
    });
  });
}
