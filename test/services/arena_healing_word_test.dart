import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena/arena_combat_context.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena/arena_spellcasting_ai.dart';

MonsterItem _makeHealerMonster() {
  const sb = MinionStatBlock(
    id: 'test_healer',
    name: 'Test Healer',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 5', // PB +3
    ac: 14,
    maxHp: 60,
    wisScore: 18, // +4
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 6,
    damageBonus: 2,
    damageType: 'bludgeoning',
    spellSaveDc: 15, // 8 + 3 (PB) + 4 (WIS)
    spellAttackBonus: 7, // 3 (PB) + 4 (WIS)
  );
  return MonsterItem.simple(
    id: 'test_healer',
    name: 'Test Healer',
    statBlock: sb,
  );
}

ArenaCombatant _makeCombatant({
  required String id,
  required MonsterItem monster,
  required ArenaTeam team,
  required int maxHp,
  required int currentHp,
  Map<int, int> slots = const {},
  List<String> spells = const [],
}) {
  return ArenaCombatant(
    id: id,
    monster: monster,
    team: team,
    displayName: id,
    maxHp: maxHp,
    currentHp: currentHp,
    ac: 14,
    initiativeBonus: 0,
    maxSpellSlots: slots,
    currentSpellSlots: slots,
    knownSpellIds: spells,
    spellSaveDc: 15, // 8 + PB(3) + mod(4)
    spellAttackBonus: 7, // PB(3) + mod(4) — intentionally != mod(4)
  );
}

int _rollDiceWithSeed(int seed, int count, int sides) {
  final rng = Random(seed);
  var sum = 0;
  for (var i = 0; i < count; i++) {
    sum += rng.nextInt(sides) + 1;
  }
  return sum;
}

void main() {
  group('Fix 4.1: Arena Healing Word uses spell dice + spellcasting ability modifier',
      () {
    final monster = _makeHealerMonster();
    const expectedMod = 4; // DC 15 - 8 - PB(3 for CR 5) = +4 (NOT spellAttackBonus +7)

    for (final edition in DmRulesEdition.values) {
      for (final slotLevel in const [1, 2]) {
        test(
            '${edition.name} slot $slotLevel heals exact edition dice + spellcasting ability modifier',
            () {
          const seed = 41001;
          final expectedDiceCount =
              edition == DmRulesEdition.v2014 ? slotLevel : slotLevel * 2;
          final expectedRoll = _rollDiceWithSeed(seed, expectedDiceCount, 4);
          final expectedHeal = expectedRoll + expectedMod;

          final caster = _makeCombatant(
            id: 'caster',
            monster: monster,
            team: ArenaTeam.teamA,
            maxHp: 60,
            currentHp: 60,
            slots: {slotLevel: 1},
            spells: const ['spell_healing_word'],
          );
          final ally = _makeCombatant(
            id: 'ally',
            monster: monster,
            team: ArenaTeam.teamA,
            maxHp: 100,
            currentHp: 20, // < 60% HP, plenty of headroom
          );
          final enemy = _makeCombatant(
            id: 'enemy',
            monster: monster,
            team: ArenaTeam.teamB,
            maxHp: 100,
            currentHp: 100,
          );

          final ai = ArenaSpellcastingAi(ArenaCombatContext(rng: Random(seed)));
          final result = ai.evaluateTacticalSpellcasting(
            attacker: caster,
            allCombatants: [caster, ally, enemy],
            strategy: ArenaTargetingStrategy.focusLowestHp,
            edition: edition,
            environment: ArenaEnvironment.colosseum,
          );

          expect(result, isNotNull);
          expect(result!.specialSummary, contains('Healing Word (Slot $slotLevel)'));
          expect(
            ally.currentHp - 20,
            equals(expectedHeal),
            reason:
                '${edition.name} slot $slotLevel should heal ${expectedDiceCount}d4 ($expectedRoll) + mod ($expectedMod) = $expectedHeal, not spellAttackBonus (7)',
          );
        });
      }
    }
  });
}
