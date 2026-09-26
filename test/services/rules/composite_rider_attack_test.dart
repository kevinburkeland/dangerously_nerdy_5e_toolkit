import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/simulation/precomputed_attack.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';

void main() {
  const testStatBlock = MinionStatBlock(
    id: 'test_target_sb',
    name: 'Target Gladiator',
    sizeDisplay: 'Medium',
    crDisplay: '5',
    ac: 16,
    maxHp: 100,
    strScore: 16, // STR 16 (+3 mod)
    dexScore: 14,
    conScore: 14,
    intScore: 10,
    wisScore: 12,
    chaScore: 10,
    attackBonus: 5, // Melee attack bonus: +5 (PB 2 + STR 3)
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 3,
    damageType: 'slashing',
  );

  const testMonster = MonsterItem(
    id: 'test_target_monster',
    name: 'Target Gladiator',
    statBlock2014: testStatBlock,
    statBlock2024: testStatBlock,
    sourcePresetId: 'test',
    sourcePresetName: 'Test',
    sourceCategory: SummonCategory.spell,
  );

  ArenaCombatant createTarget(
      {int tempHp = 15, int altitude = 30, bool hasHover = true}) {
    return ArenaCombatant(
      id: 'target_gladiator',
      monster: testMonster,
      team: ArenaTeam.teamB,
      displayName: 'Target Gladiator',
      maxHp: 100,
      currentHp: 100,
      tempHp: tempHp,
      ac: 16,
      initiativeBonus: 2,
      altitudeInFeet: altitude,
      isAirborne: altitude > 0,
      hasHover: hasHover,
    );
  }

  group('Composite Action Rider AST & Multi-Effect Execution Pipeline', () {
    test('PrecomputedAttack enforces riders.length <= 8 invariant', () {
      final validAttack = PrecomputedAttack(
        attackId: 'valid_attack',
        attackBonus: 10,
        flatBonus: 5,
        damageGroups: const [DamageDieGroup(count: 2, faces: 6)],
        riders: const [
          ConditionRider(condition: ArenaCondition.grappled),
          ConditionRider(condition: ArenaCondition.restrained),
          ForcedMovementRider(pullDistanceFeet: 25),
          AttributeDrainRider(targetAttributeKey: 'strength'),
          MaxHpReductionRider(),
          HealingSupressionRider(),
        ],
      );
      expect(validAttack.riders.length, equals(6));

      expect(
        () => PrecomputedAttack(
          attackId: 'oversized_attack',
          attackBonus: 10,
          flatBonus: 5,
          damageGroups: const [],
          riders: const [
            ConditionRider(condition: ArenaCondition.grappled),
            ConditionRider(condition: ArenaCondition.restrained),
            ConditionRider(condition: ArenaCondition.prone),
            ConditionRider(condition: ArenaCondition.poisoned),
            ConditionRider(condition: ArenaCondition.blinded),
            ForcedMovementRider(pullDistanceFeet: 10),
            AttributeDrainRider(targetAttributeKey: 'strength'),
            MaxHpReductionRider(),
            HealingSupressionRider(), // 9th rider
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
        'Executes Kraken/Vampire synthetic composite attack with 6 stacked riders upon hit',
        () {
      final target = createTarget(tempHp: 15, altitude: 30);
      expect(target.effectiveMaxHp, equals(100));
      expect(target.currentHp, equals(100));
      expect(target.tempHp, equals(15));
      expect(target.getAbilityScore(AbilityType.strength), equals(16));
      expect(target.getAbilityModifier(AbilityType.strength), equals(3));
      expect(target.meleeAttackBonus, equals(5));
      expect(
          target.getAbilitySavingThrowBonus(AbilityType.strength), equals(3));

      // Synthetic composite attack with 6 stacked riders:
      // 1. Bludgeoning damage: 25 flat (using 0 dice for determinism)
      // 2. Grappled condition
      // 3. Restrained condition
      // 4. 25-ft Reel
      // 5. 1d4 Strength Drain (death at 0)
      // 6. Necrotic Max HP reduction
      final compositeAttack = PrecomputedAttack(
        attackId: 'kraken_vampire_strike',
        attackBonus: 17,
        flatBonus: 25,
        damageGroups: const [],
        riders: const [
          ConditionRider(condition: ArenaCondition.grappled),
          ConditionRider(condition: ArenaCondition.restrained),
          ForcedMovementRider(pullDistanceFeet: 25, toMeleeReach: true),
          AttributeDrainRider(
            targetAttributeKey: 'strength',
            diceCount: 0,
            flatBonus:
                3, // Drains exactly 3 STR for deterministic scaling assertion
            deathAtZero: true,
          ),
          MaxHpReductionRider(
            reductionEqualsDamage: true,
            deathAtZero: true,
          ),
          HealingSupressionRider(),
        ],
      );

      // Execute attack hit against target
      final hitResult = target.applyAttackHit(compositeAttack);
      expect(hitResult.damageDealt, equals(25));
      expect(hitResult.riderLogs, isNotEmpty);
      expect(hitResult.conditionsApplied,
          containsAll([ArenaCondition.grappled, ArenaCondition.restrained]));

      // 1. Assert damage absorption:
      // 15 tempHp absorbed all 15 tempHp -> tempHp == 0.
      // Spillover 10 damage hits currentHp (100 - 10 = 90).
      expect(target.tempHp, equals(0));

      // 2. Assert both Grappled and Restrained conditions are applied
      expect(target.hasCondition(ArenaCondition.grappled), isTrue);
      expect(target.hasCondition(ArenaCondition.restrained), isTrue);

      // 3. Assert Forced Movement (Reel 25 ft straight toward creature)
      // Started at 30 ft altitude, pulled 25 ft down -> altitude is 5 ft
      expect(target.altitudeInFeet, equals(5));

      // 4. Assert Strength drain scales down melee attack and saving throw bonuses
      // STR drained by 3: 16 -> 13.
      // STR modifier: +3 -> +1 (delta of -2).
      expect(target.getAbilityScore(AbilityType.strength), equals(13));
      expect(target.getAbilityModifier(AbilityType.strength), equals(1));
      // Melee attack bonus was 5, now scaled down by 2 -> 3.
      expect(target.meleeAttackBonus, equals(3));
      // STR saving throw bonus was 3, now scaled down by 2 -> 1.
      expect(
          target.getAbilitySavingThrowBonus(AbilityType.strength), equals(1));

      // 5. Assert effectiveMaxHp decreases
      // Max HP reduction equals damage (25).
      // Max HP: 100 - 25 = 75.
      expect(target.maxHpReduction, equals(25));
      expect(target.effectiveMaxHp, equals(75));
      // Since currentHp was 90, it is clamped to effectiveMaxHp (75).
      expect(target.currentHp, equals(75));

      // 6. Assert healing suppression blocks healing
      expect(target.isHealingSuppressed, isTrue);
      final healed = target.applyHealing(20);
      expect(healed, equals(0));
      expect(target.currentHp, equals(75));

      // Target is still alive at 75 HP
      expect(target.isAlive, isTrue);
      expect(target.isDefeated, isFalse);
    });

    test(
        'Triggers instant death when Strength drops to 0 regardless of current HP',
        () {
      final target = createTarget();
      expect(target.currentHp, equals(100));
      expect(target.isAlive, isTrue);

      // Target has 16 Strength. Drain 16 Strength.
      target.applyAttributeDrain(AbilityType.strength, 16, deathAtZero: true);

      expect(target.getAbilityScore(AbilityType.strength), equals(0));
      expect(target.isDefeated, isTrue);
      expect(target.isAlive, isFalse);
      expect(target.currentHp, equals(0));
    });

    test(
        'Triggers instant death when effectiveMaxHp drops to 0 regardless of current HP',
        () {
      final target = createTarget();
      expect(target.currentHp, equals(100));
      expect(target.isAlive, isTrue);

      // Target has 100 Max HP. Reduce Max HP by 100.
      target.applyMaxHpReduction(100, deathAtZero: true);

      expect(target.effectiveMaxHp, equals(0));
      expect(target.isDefeated, isTrue);
      expect(target.isAlive, isFalse);
      expect(target.currentHp, equals(0));
    });

    test(
        'StatBlockAclParser extracts all 6 stacked riders from unstructured action text',
        () {
      const rawAction =
          'Tentacle Bite. Melee Weapon Attack: +17 to hit, reach 30 ft., one target. '
          'Hit: 20 (3d6 + 10) bludgeoning damage, and the target is grappled (escape DC 18). '
          'Until this grapple ends, the target is restrained. '
          'The target is pulled up to 25 feet straight toward the kraken. '
          "The target's Strength score is reduced by 1d4. The target dies if this reduces its Strength to 0. "
          "The target's hit point maximum is reduced by an amount equal to the necrotic damage taken, and the target dies if this reduces its hit point maximum to 0. "
          "The target can't regain hit points until it finishes a long rest.";

      final riders = StatBlockAclParser.extractRiders(rawAction);

      expect(riders.length, equals(6));

      // 1. Grappled
      expect(riders[0], isA<ConditionRider>());
      final grappleRider = riders[0] as ConditionRider;
      expect(grappleRider.condition, equals(ArenaCondition.grappled));
      expect(grappleRider.saveDc, equals(18));

      // 2. Restrained
      expect(riders[1], isA<ConditionRider>());
      final restrainedRider = riders[1] as ConditionRider;
      expect(restrainedRider.condition, equals(ArenaCondition.restrained));

      // 3. Forced Movement Reel
      expect(riders[2], isA<ForcedMovementRider>());
      final reelRider = riders[2] as ForcedMovementRider;
      expect(reelRider.pullDistanceFeet, equals(25));
      expect(reelRider.toMeleeReach, isTrue);

      // 4. Attribute Drain
      expect(riders[3], isA<AttributeDrainRider>());
      final drainRider = riders[3] as AttributeDrainRider;
      expect(drainRider.targetAttributeKey, equals('strength'));
      expect(drainRider.diceCount, equals(1));
      expect(drainRider.diceSides, equals(4));
      expect(drainRider.deathAtZero, isTrue);

      // 5. Max HP Reduction
      expect(riders[4], isA<MaxHpReductionRider>());
      final maxHpRider = riders[4] as MaxHpReductionRider;
      expect(maxHpRider.reductionEqualsDamage, isTrue);
      expect(maxHpRider.deathAtZero, isTrue);

      // 6. Healing Suppression
      expect(riders[5], isA<HealingSupressionRider>());
      final healRider = riders[5] as HealingSupressionRider;
      expect(healRider.cureViaRemoveCurse, isFalse);
    });
  });
}
