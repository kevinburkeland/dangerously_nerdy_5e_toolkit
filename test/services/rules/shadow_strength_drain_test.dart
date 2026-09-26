import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/simulation/precomputed_attack.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';

void main() {
  group('Shadow Strength Drain & Instant Death Hardening', () {
    const fireGiantStatBlock = MinionStatBlock(
      id: 'fire_giant_sb',
      name: 'Fire Giant',
      sizeDisplay: 'Huge',
      crDisplay: '9',
      ac: 18,
      maxHp: 162,
      strScore: 25, // STR 25 (+7)
      dexScore: 9,
      conScore: 23,
      intScore: 10,
      wisScore: 14,
      chaScore: 13,
      attackBonus: 11,
      damageDiceCount: 6,
      damageDiceSides: 6,
      damageBonus: 7,
      damageType: 'slashing',
    );

    const fireGiantMonster = MonsterItem(
      id: 'fire_giant',
      name: 'Fire Giant',
      statBlock2014: fireGiantStatBlock,
      statBlock2024: fireGiantStatBlock,
      sourcePresetId: 'srd',
      sourcePresetName: 'SRD',
      sourceCategory: SummonCategory.spell,
    );

    ArenaCombatant createFireGiant() {
      return ArenaCombatant(
        id: 'fire_giant_1',
        monster: fireGiantMonster,
        team: ArenaTeam.teamB,
        displayName: 'Fire Giant',
        maxHp: 162,
        currentHp: 162,
        ac: 18,
        initiativeBonus: -1,
      );
    }

    test(
        'StatBlockAclParser parses Shadow Strength Drain action text with deathAtZero=true',
        () {
      const shadowAction =
          'Strength Drain. Melee Weapon Attack: +4 to hit, reach 5 ft., one creature. '
          'Hit: 9 (2d6 + 2) necrotic damage, and the target\'s Strength score is reduced by 1d4. '
          'The target dies if this reduces its Strength to 0. Otherwise, the reduction lasts until '
          'the target finishes a short or long rest.';

      final riders = StatBlockAclParser.extractRiders(shadowAction);
      expect(riders, isNotEmpty);

      final drainRider = riders.whereType<AttributeDrainRider>().firstOrNull;
      expect(drainRider, isNotNull);
      expect(drainRider!.targetAttributeKey, equals('strength'));
      expect(drainRider.diceCount, equals(1));
      expect(drainRider.diceSides, equals(4));
      expect(drainRider.deathAtZero, isTrue);
    });

    test(
        'StatBlockAclParser flags deathAtZero=true on regex variations of ability score death',
        () {
      const variations = [
        "the target's Strength score is reduced by 2. The target dies if this reduces its Strength to 0.",
        "target's Constitution score is reduced by 1d6. Target dies if this reduces score to 0.",
        "target's Dexterity score is reduced by 3. dies if this reduces its score to 0.",
        "target's Strength score is reduced by 1d4. dies if this reduces ability to 0.",
      ];

      for (final text in variations) {
        final riders = StatBlockAclParser.extractRiders(text);
        final drainRider = riders.whereType<AttributeDrainRider>().firstOrNull;
        expect(drainRider, isNotNull,
            reason: 'Failed to extract drain from: $text');
        expect(drainRider!.deathAtZero, isTrue,
            reason: 'deathAtZero should be true for: $text');
      }
    });

    test(
        'Reducing Fire Giant Strength (25) to 0 forces currentHp = 0, isAlive = false, isDefeated = true',
        () {
      final giant = createFireGiant();
      expect(giant.currentHp, equals(162));
      expect(giant.getAbilityScore(AbilityType.strength), equals(25));
      expect(giant.isAlive, isTrue);
      expect(giant.isDefeated, isFalse);

      // Drain 25 Strength directly with deathAtZero: true
      giant.applyAttributeDrain(AbilityType.strength, 25, deathAtZero: true);

      expect(giant.getAbilityScore(AbilityType.strength), equals(0));
      expect(giant.currentHp, equals(0));
      expect(giant.hitPoints.currentHp, equals(0));
      expect(giant.isAlive, isFalse);
      expect(giant.isDefeated, isTrue);
    });

    test(
        'Shadow Strength Drain via applyAttackHit logs instant death when Strength reaches 0',
        () {
      final giant = createFireGiant();
      expect(giant.isAlive, isTrue);

      // Weaken giant to 2 STR first
      giant.applyAttributeDrain(AbilityType.strength, 23, deathAtZero: true);
      expect(giant.getAbilityScore(AbilityType.strength), equals(2));
      expect(giant.isAlive, isTrue);

      final fatalDrainAttack = PrecomputedAttack(
        attackId: 'shadow_fatal_drain',
        attackBonus: 4,
        flatBonus: 2,
        damageGroups: const [
          DamageDieGroup(count: 2, faces: 6),
        ],
        riders: const [
          AttributeDrainRider(
            targetAttributeKey: 'strength',
            diceCount: 0,
            diceSides: 0,
            flatBonus: 4, // 4 > 2, reducing STR to 0
            deathAtZero: true,
          ),
        ],
      );

      final result = giant.applyAttackHit(fatalDrainAttack);

      expect(giant.getAbilityScore(AbilityType.strength), lessThanOrEqualTo(0));
      expect(giant.currentHp, equals(0));
      expect(giant.isAlive, isFalse);
      expect(giant.isDefeated, isTrue);

      expect(
          result.riderLogs,
          anyElement(
              contains("STR was reduced to 0! Fire Giant dies instantly!")));
    });

    test(
        'ArenaCombatant.isAlive immediately returns false whenever Strength is <= 0',
        () {
      final giant = createFireGiant();
      expect(giant.isAlive, isTrue);

      giant.applyAttributeDrain(AbilityType.strength, 30, deathAtZero: false);
      expect(giant.getAbilityScore(AbilityType.strength), lessThanOrEqualTo(0));
      expect(giant.isAlive, isFalse);
      expect(giant.isDefeated, isTrue);
    });
  });
}
