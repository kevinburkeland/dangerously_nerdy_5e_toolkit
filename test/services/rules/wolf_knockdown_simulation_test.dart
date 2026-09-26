import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_action_result.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

/// Predictable pseudo-random generator for deterministic testing.
class DeterministicRandom implements math.Random {
  final List<int> _values;
  int _idx = 0;

  DeterministicRandom(this._values);

  @override
  int nextInt(int max) {
    if (_values.isEmpty) return 0;
    final val = _values[_idx % _values.length];
    _idx++;
    return val % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(100) / 100.0;
}

void main() {
  const wolfStatBlock = MinionStatBlock(
    id: 'srd_wolf',
    name: 'Wolf',
    sizeDisplay: 'Medium',
    crDisplay: '1/4',
    typeDisplay: 'Beast',
    alignment: 'unaligned',
    ac: 13,
    armorType: 'natural armor',
    maxHp: 11,
    hitDice: '2d8 + 2',
    speed: '40 ft.',
    strScore: 12,
    dexScore: 15,
    conScore: 12,
    intScore: 3,
    wisScore: 12,
    chaScore: 6,
    skills: 'Perception +3, Stealth +4',
    attackBonus: 4,
    damageDiceCount: 2,
    damageDiceSides: 4,
    damageBonus: 2,
    damageType: 'piercing',
    actions: [
      CreatureAction(
        name: 'Bite',
        description: 'Melee Weapon Attack: +4 to hit, reach 5 ft., one target. '
            'Hit: 7 (2d4 + 2) piercing damage. If the target is a creature, '
            'it must succeed on a DC 11 Strength saving throw or be knocked prone.',
        attackBonus: 4,
      ),
    ],
  );

  const defenderStatBlock = MinionStatBlock(
    id: 'defender_target',
    name: 'Defender',
    sizeDisplay: 'Medium',
    crDisplay: '1',
    typeDisplay: 'Humanoid',
    alignment: 'neutral',
    ac: 14,
    maxHp: 30,
    speed: '30 ft.',
    strScore: 10, // STR mod = +0
    dexScore: 12,
    conScore: 12,
    intScore: 10,
    wisScore: 10,
    chaScore: 10,
    attackBonus: 2,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 0,
    damageType: 'slashing',
  );

  const defenderMonster = MonsterItem(
    id: 'defender_target',
    name: 'Defender',
    statBlock2014: defenderStatBlock,
    statBlock2024: defenderStatBlock,
    sourcePresetId: 'srd',
    sourcePresetName: 'SRD',
    sourceCategory: SummonCategory.spell,
  );

  ArenaCombatant createDefender() {
    return ArenaCombatant(
      id: 'defender_1',
      monster: defenderMonster,
      team: ArenaTeam.teamB,
      displayName: 'Defender Target',
      maxHp: 30,
      currentHp: 30,
      ac: 14,
      initiativeBonus: 1,
    );
  }

  group('Wolf Knockdown Action Rider & Saving Throw Simulation Tests', () {
    test(
        'StatBlockAclParser extracts PrecomputedAttack with ConditionRider(prone) from Wolf bite',
        () {
      final parsed = StatBlockAclParser.parseStatBlockBoundary(wolfStatBlock,
          challengeRating: 0.25);

      expect(parsed.attacks.containsKey('bite'), isTrue);
      final bite = parsed.attacks['bite']!;

      expect(bite.attackId, equals('bite'));
      expect(bite.attackBonus, equals(4));
      expect(bite.damageGroups.length, equals(1));
      expect(bite.damageGroups[0].count, equals(2));
      expect(bite.damageGroups[0].faces, equals(4));
      expect(bite.flatBonus, equals(2));

      // Assert ConditionRider extraction for Prone with DC 11 Strength saving throw
      expect(bite.riders.length, equals(1));
      expect(bite.riders.first, isA<ConditionRider>());
      final proneRider = bite.riders.first as ConditionRider;
      expect(proneRider.condition, equals(ArenaCondition.prone));
      expect(proneRider.requiresSave, isTrue);
      expect(proneRider.saveDc, equals(11));
      expect(proneRider.saveAttributeKey, equals('strength'));
    });

    test('MonsterCombatProfile.fromStatBlock populates attacks map seamlessly',
        () {
      final profile = MonsterCombatProfile.fromStatBlock(wolfStatBlock,
          challengeRating: 0.25);
      expect(profile.attacks.containsKey('bite'), isTrue);
      final bite = profile.attacks['bite']!;
      expect(
          bite.riders.any((r) =>
              r is ConditionRider && r.condition == ArenaCondition.prone),
          isTrue);
    });

    test(
        'Defender fails DC 11 STR save -> falls Prone, logs event and updates summaryText',
        () {
      final target = createDefender();
      expect(target.isProne, isFalse);

      final parsed = StatBlockAclParser.parseStatBlockBoundary(wolfStatBlock,
          challengeRating: 0.25);
      final bite = parsed.attacks['bite']!;

      // RNG sequence:
      // 1. Damage rolls (2d4): nextInt(4) -> 2 (die=3), nextInt(4) -> 1 (die=2) => 5 + 2 = 7 damage.
      // 2. Saving throw d20: nextInt(20) -> 3 (roll=4, total 4 + 0 STR mod = 4 < 11 -> FAIL).
      final rngFail = DeterministicRandom([2, 1, 3]);

      final result = target.applyAttackHit(bite, rng: rngFail);

      expect(result.damageDealt, equals(7));
      expect(target.currentHp, equals(23));
      expect(target.isProne, isTrue);
      expect(result.conditionsApplied, contains(ArenaCondition.prone));
      expect(result.riderLogs.length, equals(1));
      expect(result.riderLogs.first, contains('failed DC 11 STR save'));
      expect(result.riderLogs.first, contains('fell Prone'));

      // Verify ArenaAttackEvent appends rider logs to summaryText
      final attackEvent = ArenaAttackEvent(
        attackerId: 'wolf_1',
        attackerName: 'Wolf',
        attackerTeam: ArenaTeam.teamA,
        defenderId: target.id,
        defenderName: target.displayName,
        defenderTeam: target.team,
        attackName: 'Bite',
        d20Roll: 15,
        attackBonus: 4,
        totalAttack: 19,
        targetAc: 14,
        isHit: true,
        damageDealt: result.damageDealt,
        damageType: 'piercing',
        defenderRemainingHp: target.currentHp,
        defenderMaxHp: target.maxHp,
        summaryText:
            'Wolf hits Defender Target with Bite for 7 piercing damage.',
        appliedRiderLogs: result.riderLogs,
      );

      expect(
          attackEvent.summaryText,
          contains(
              'Wolf hits Defender Target with Bite for 7 piercing damage.'));
      expect(
          attackEvent.summaryText,
          contains(
              'Defender Target failed DC 11 STR save (4) and fell Prone!'));
    });

    test(
        'Defender succeeds on DC 11 STR save -> resists knockdown and remains standing',
        () {
      final target = createDefender();
      expect(target.isProne, isFalse);

      final parsed = StatBlockAclParser.parseStatBlockBoundary(wolfStatBlock,
          challengeRating: 0.25);
      final bite = parsed.attacks['bite']!;

      // RNG sequence:
      // 1. Damage rolls (2d4): nextInt(4) -> 0 (die=1), nextInt(4) -> 2 (die=3) => 4 + 2 = 6 damage.
      // 2. Saving throw d20: nextInt(20) -> 14 (roll=15, total 15 + 0 STR mod = 15 >= 11 -> SUCCESS).
      final rngSuccess = DeterministicRandom([0, 2, 14]);

      final result = target.applyAttackHit(bite, rng: rngSuccess);

      expect(result.damageDealt, equals(6));
      expect(target.currentHp, equals(24));
      expect(target.isProne, isFalse);
      expect(result.conditionsApplied, isEmpty);
      expect(result.riderLogs.length, equals(1));
      expect(result.riderLogs.first, contains('succeeded on DC 11 STR save'));
      expect(result.riderLogs.first, contains('against Prone'));
    });

    test(
        'ArenaCombatEngine turn execution wires applyAttackHit rider logs into ArenaAttackEvent',
        () {
      final attacker = ArenaCombatant(
        id: 'wolf_1',
        monster: const MonsterItem(
          id: 'srd_wolf',
          name: 'Wolf',
          statBlock2014: wolfStatBlock,
          statBlock2024: wolfStatBlock,
          sourcePresetId: 'srd',
          sourcePresetName: 'SRD',
          sourceCategory: SummonCategory.spell,
        ),
        team: ArenaTeam.teamA,
        displayName: 'Wolf',
        maxHp: 11,
        currentHp: 11,
        ac: 13,
        initiativeBonus: 2,
      );
      final defender = createDefender();

      // Deterministic sequence:
      // 1. Attack roll d20: nextInt(20) -> 14 (roll 15 + 4 = 19 vs AC 14 -> HIT)
      // 2. Damage roll (2d4): nextInt(4) -> 2 (die=3), nextInt(4) -> 1 (die=2) => 5 + 2 = 7
      // 3. Saving throw d20: nextInt(20) -> 3 (roll 4 + 0 = 4 < 11 -> FAIL)
      final rng = DeterministicRandom([14, 2, 1, 3]);
      final engine = ArenaCombatEngine(rng: rng);

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: attacker,
        allCombatants: [attacker, defender],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(step.attackEvents.isNotEmpty, isTrue);
      final event = step.attackEvents.first;
      expect(event.isHit, isTrue);
      expect(event.appliedRiderLogs, isNotEmpty);
      expect(event.appliedRiderLogs.first, contains('failed DC 11 STR save'));
      expect(event.appliedRiderLogs.first, contains('fell Prone'));
      expect(event.summaryText, contains('fell Prone'));
      expect(defender.isProne, isTrue);
    });
  });
}
