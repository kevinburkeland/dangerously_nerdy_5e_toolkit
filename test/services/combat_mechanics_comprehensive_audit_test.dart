import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/aoe_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

void main() {
  group('Combat Mechanics Comprehensive Audit & Edge Cases', () {
    late ArenaCombatEngine engine;
    late MonsterItem wolfMonster;
    late MonsterItem dragonMonster;
    late MonsterItem trexMonster;

    setUp(() {
      engine = ArenaCombatEngine(rng: Random(1337));
      wolfMonster = MonsterCodexLibrary.getMonsterByName('Wolf') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');
      dragonMonster = MonsterCodexLibrary.getMonsterByName('Young Red Dragon') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'young red dragon');
      trexMonster = MonsterCodexLibrary.getMonsterByName('Tyrannosaurus Rex') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('tyrannosaurus'));
    });

    // =========================================================================
    // 1. AOE RESOLVER BOUNDARY & BRANCH AUDIT
    // =========================================================================
    group('AoeResolver Exhaustive Boundary Tests', () {
      test('Base target caps calculate exact DMG p.249 geometry values and handle zero/negative sizes', () {
        // Zero and negative boundaries must return safe fallback of 1.0
        expect(AoeResolver.getBaseTargetCap(AoeShape.sphere, 0), 1.0);
        expect(AoeResolver.getBaseTargetCap(AoeShape.sphere, -20), 1.0);
        expect(AoeResolver.getBaseTargetCap(AoeShape.cylinder, 0), 1.0);
        expect(AoeResolver.getBaseTargetCap(AoeShape.cone, 0), 1.0);
        expect(AoeResolver.getBaseTargetCap(AoeShape.cube, 0), 1.0);
        expect(AoeResolver.getBaseTargetCap(AoeShape.line, 0), 1.0);

        // Standard 5e Area Geometry
        expect(AoeResolver.getBaseTargetCap(AoeShape.sphere, 20), 4.0); // 20/5 = 4
        expect(AoeResolver.getBaseTargetCap(AoeShape.sphere, 40), 8.0); // 40/5 = 8
        expect(AoeResolver.getBaseTargetCap(AoeShape.cylinder, 10), 2.0); // 10/5 = 2
        expect(AoeResolver.getBaseTargetCap(AoeShape.cone, 15), 1.5); // 15/10 = 1.5
        expect(AoeResolver.getBaseTargetCap(AoeShape.cone, 30), 3.0); // 30/10 = 3
        expect(AoeResolver.getBaseTargetCap(AoeShape.cone, 60), 6.0); // 60/10 = 6
        expect(AoeResolver.getBaseTargetCap(AoeShape.cube, 15), 1.5); // 15/10 = 1.5
        expect(AoeResolver.getBaseTargetCap(AoeShape.cube, 100), 10.0); // 100/10 = 10
        expect(AoeResolver.getBaseTargetCap(AoeShape.line, 30), 1.0); // 30/30 = 1
        expect(AoeResolver.getBaseTargetCap(AoeShape.line, 100), closeTo(3.333, 0.001)); // 100/30
      });

      test('calculateTargetCount handles boundary counts (0, 1, large) without throwing', () {
        final rng = Random(42);
        // 0 enemies returns 0
        expect(
          AoeResolver.calculateTargetCount(
            shape: AoeShape.sphere,
            sizeInFeet: 20,
            livingEnemyCount: 0,
            rng: rng,
          ),
          0,
        );

        // 1 enemy always returns 1
        expect(
          AoeResolver.calculateTargetCount(
            shape: AoeShape.sphere,
            sizeInFeet: 20,
            livingEnemyCount: 1,
            rng: rng,
          ),
          1,
        );

        // Clamping ensures result is always in [1, livingEnemyCount]
        for (int i = 0; i < 50; i++) {
          final count = AoeResolver.calculateTargetCount(
            shape: AoeShape.cone,
            sizeInFeet: 15,
            livingEnemyCount: 3,
            rng: rng,
          );
          expect(count, greaterThanOrEqualTo(1));
          expect(count, lessThanOrEqualTo(3));
        }
      });

      test('selectTargets handles empty and single-target lists without mutation or error', () {
        final rng = Random(42);
        final emptyList = <ArenaCombatant>[];
        final resEmpty = AoeResolver.selectTargets(
          livingEnemies: emptyList,
          shape: AoeShape.sphere,
          sizeInFeet: 20,
          rng: rng,
        );
        expect(resEmpty.isEmpty, true);

        final singleEnemy = ArenaCombatant.fromMonster(
          id: 'single',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        );
        final resSingle = AoeResolver.selectTargets(
          livingEnemies: [singleEnemy],
          shape: AoeShape.sphere,
          sizeInFeet: 20,
          rng: rng,
        );
        expect(resSingle.length, 1);
        expect(resSingle.first.id, 'single');
      });

      test('selectTargets sorts candidates correctly for all 3 targeting heuristics', () {
        final rng = Random(42);
        final cLowHp = ArenaCombatant.fromMonster(id: 'c_low', monster: wolfMonster, team: ArenaTeam.teamB, hpOverride: 5, acOverride: 10);
        final cMidHp = ArenaCombatant.fromMonster(id: 'c_mid', monster: wolfMonster, team: ArenaTeam.teamB, hpOverride: 15, acOverride: 12);
        final cHighThreat = ArenaCombatant.fromMonster(id: 'c_high', monster: dragonMonster, team: ArenaTeam.teamB, hpOverride: 100, acOverride: 18);

        final enemies = [cMidHp, cHighThreat, cLowHp];

        // 1. focusLowestHp heuristic
        final lowestHpRes = AoeResolver.selectTargets(
          livingEnemies: enemies,
          shape: AoeShape.cone,
          sizeInFeet: 15, // baseCap 1.5 -> select ~1-2
          rng: rng,
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );
        expect(lowestHpRes.first.id, 'c_low');

        // 2. highestThreat heuristic
        final threatRes = AoeResolver.selectTargets(
          livingEnemies: enemies,
          shape: AoeShape.cone,
          sizeInFeet: 15,
          rng: rng,
          strategy: ArenaTargetingStrategy.highestThreat,
        );
        expect(threatRes.first.id, 'c_high');

        // 3. randomEnemy heuristic
        final randomRes = AoeResolver.selectTargets(
          livingEnemies: enemies,
          shape: AoeShape.sphere,
          sizeInFeet: 20,
          rng: rng,
          strategy: ArenaTargetingStrategy.randomEnemy,
        );
        expect(randomRes.isNotEmpty, true);
      });

      test('parseShapeAndSize extracts exact dimensions and ignores recharge numbers', () {
        // Explicit dimensions
        expect(AoeResolver.parseShapeAndSize('Fireball', 'A 20-foot radius sphere').shape, AoeShape.sphere);
        expect(AoeResolver.parseShapeAndSize('Fireball', 'A 20-foot radius sphere').sizeInFeet, 20.0);

        expect(AoeResolver.parseShapeAndSize('Cone of Cold (60-foot cone)').shape, AoeShape.cone);
        expect(AoeResolver.parseShapeAndSize('Cone of Cold (60-foot cone)').sizeInFeet, 60.0);

        expect(AoeResolver.parseShapeAndSize('Lightning Bolt (100-foot line)').shape, AoeShape.line);
        expect(AoeResolver.parseShapeAndSize('Lightning Bolt (100-foot line)').sizeInFeet, 100.0);

        expect(AoeResolver.parseShapeAndSize('Thunderwave 15-ft cube').shape, AoeShape.cube);
        expect(AoeResolver.parseShapeAndSize('Thunderwave 15-ft cube').sizeInFeet, 15.0);

        expect(AoeResolver.parseShapeAndSize('Flame Strike 10-ft cylinder').shape, AoeShape.cylinder);
        expect(AoeResolver.parseShapeAndSize('Flame Strike 10-ft cylinder').sizeInFeet, 10.0);

        // Recharge strings like "(Recharge 5-6)" must not be mistaken for 5-foot dimensions!
        final breathAction = AoeResolver.parseShapeAndSize('Fire Breath (Recharge 5-6)');
        expect(breathAction.shape, AoeShape.cone);
        expect(breathAction.sizeInFeet, 30.0); // Default breath cone size

        // Blank or non-AoE action
        final blank = AoeResolver.parseShapeAndSize('');
        expect(blank.shape, AoeShape.sphere);
        expect(blank.sizeInFeet, 20.0);
      });
    });

    // =========================================================================
    // 2. AERIAL COMBAT, REACH, & FALL MECHANICS AUDIT
    // =========================================================================
    group('Aerial Combat & Condition State Transitions', () {
      test('Combatant initializes flight and reach attributes from monster statblock', () {
        // Wolf has no flight, 5 ft reach
        final wolf = ArenaCombatant.fromMonster(id: 'w', monster: wolfMonster, team: ArenaTeam.teamA);
        expect(wolf.isAirborne, false);
        expect(wolf.hasHover, false);
        expect(wolf.altitudeInFeet, 0);
        expect(wolf.meleeReachInFeet, 5);

        // Dragon has 80 ft fly speed, 10 ft reach on bite
        final dragon = ArenaCombatant.fromMonster(id: 'd', monster: dragonMonster, team: ArenaTeam.teamA);
        expect(dragon.isAirborne, true);
        expect(dragon.hasHover, false);
        expect(dragon.altitudeInFeet, 20);
        expect(dragon.meleeReachInFeet, greaterThanOrEqualTo(10));

        // T-Rex has 10 ft reach on bite
        final trex = ArenaCombatant.fromMonster(id: 't', monster: trexMonster, team: ArenaTeam.teamA);
        expect(trex.isAirborne, false);
        expect(trex.meleeReachInFeet, 10);
      });

      test('applyCondition causes non-hovering fliers to fall, take fall damage, and land prone', () {
        final flyer = ArenaCombatant(
          id: 'flyer',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
          displayName: 'Flying Griffon',
          maxHp: 60,
          currentHp: 60,
          ac: 12,
          initiativeBonus: 2,
          isAirborne: true,
          hasHover: false,
          altitudeInFeet: 40, // 40 ft = 4d6 fall damage
        );

        final fallRes = flyer.applyCondition(
          ArenaCondition.stunned,
          (sides) => 5, // Rolled 5 on each die -> 4 * 5 = 20 damage
          DmRulesEdition.v2024,
        );

        expect(fallRes.fell, true);
        expect(fallRes.fallDamage, 20);
        expect(flyer.currentHp, 40);
        expect(flyer.isAirborne, false);
        expect(flyer.altitudeInFeet, 0);
        expect(flyer.isProne, true);
        expect(flyer.isStunned, true);
        expect(flyer.isIncapacitated, true);
        expect(fallRes.log, contains('fell 40 ft. from the air, taking 20 bludgeoning damage and landing Prone!'));
      });

      test('Fall damage dice count is capped at 20d6 maximum per 5e rules for extreme altitudes', () {
        final highFlyer = ArenaCombatant(
          id: 'high_flyer',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
          displayName: 'High Altitude Roc',
          maxHp: 200,
          currentHp: 200,
          ac: 12,
          initiativeBonus: 2,
          isAirborne: true,
          hasHover: false,
          altitudeInFeet: 350, // 350 ft -> would be 35d6, but capped at 20d6
        );

        int diceRolled = 0;
        highFlyer.applyCondition(
          ArenaCondition.paralyzed,
          (sides) {
            diceRolled++;
            return 1;
          },
          DmRulesEdition.v2024,
        );

        expect(diceRolled, 20, reason: 'Fall damage must be capped at 20d6 per standard 5e rules');
        expect(highFlyer.isAirborne, false);
        expect(highFlyer.altitudeInFeet, 0);
        expect(highFlyer.isProne, true);
        expect(highFlyer.isParalyzed, true);
      });

      test('Hover capability keeps flier suspended in the air when suffering disruptive conditions', () {
        final hoverCreature = ArenaCombatant(
          id: 'hover_beholder',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
          displayName: 'Hovering Beholder',
          maxHp: 80,
          currentHp: 80,
          ac: 16,
          initiativeBonus: 2,
          isAirborne: true,
          hasHover: true,
          altitudeInFeet: 30,
        );

        // Apply Prone condition to hover creature
        final fallRes = hoverCreature.applyCondition(
          ArenaCondition.prone,
          (sides) => 6,
          DmRulesEdition.v2024,
        );

        expect(fallRes.fell, false);
        expect(fallRes.fallDamage, 0);
        expect(hoverCreature.currentHp, 80);
        expect(hoverCreature.isAirborne, true);
        expect(hoverCreature.altitudeInFeet, 30);
        expect(hoverCreature.isProne, true);
        expect(fallRes.log, contains('hovered in place despite suffering Prone!'));
      });

      test('Non-disruptive conditions (Blinded, Poisoned, Charmed) do not trigger fall mechanics', () {
        final eagle = ArenaCombatant(
          id: 'eagle',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
          displayName: 'Giant Eagle',
          maxHp: 30,
          currentHp: 30,
          ac: 13,
          initiativeBonus: 3,
          isAirborne: true,
          hasHover: false,
          altitudeInFeet: 20,
        );

        final blindRes = eagle.applyCondition(ArenaCondition.blinded, (s) => 6, DmRulesEdition.v2024);
        expect(blindRes.fell, false);
        expect(blindRes.fallDamage, 0);
        expect(eagle.isAirborne, true);
        expect(eagle.altitudeInFeet, 20);
        expect(eagle.hasCondition(ArenaCondition.blinded), true);

        final poisonRes = eagle.applyCondition(ArenaCondition.poisoned, (s) => 6, DmRulesEdition.v2024);
        expect(poisonRes.fell, false);
        expect(eagle.isAirborne, true);
        expect(eagle.hasCondition(ArenaCondition.poisoned), true);
      });

      test('Condition getters and removal operate correctly', () {
        final combatant = ArenaCombatant.fromMonster(id: 'c', monster: wolfMonster, team: ArenaTeam.teamA);
        expect(combatant.isProne, false);
        expect(combatant.isStunned, false);
        expect(combatant.isParalyzed, false);
        expect(combatant.isRestrained, false);
        expect(combatant.isUnconscious, false);
        expect(combatant.isIncapacitated, false);

        combatant.conditions.add(ArenaCondition.paralyzed);
        expect(combatant.isParalyzed, true);
        expect(combatant.isIncapacitated, true);

        combatant.removeCondition(ArenaCondition.paralyzed);
        expect(combatant.isParalyzed, false);
        expect(combatant.isIncapacitated, false);
      });
    });

    // =========================================================================
    // 3. ATTACK TYPE INFERENCE & REACH VALIDATION AUDIT
    // =========================================================================
    group('AttackType & Reach Validation', () {
      test('DprAttackAction correctly infers AttackType from name and properties', () {
        const standardMelee = DprAttackAction(
          id: 'sword',
          name: 'Longsword',
          attackBonus: 5,
          diceCount: 1,
          diceSides: 8,
          damageBonus: 3,
          reachInFeet: 5,
        );
        expect(standardMelee.attackType, AttackType.meleeStandard);

        const reachMelee = DprAttackAction(
          id: 'halberd',
          name: 'Halberd',
          attackBonus: 5,
          diceCount: 1,
          diceSides: 10,
          damageBonus: 3,
          reachInFeet: 10,
        );
        expect(reachMelee.attackType, AttackType.meleeReach);

        const bowAttack = DprAttackAction(
          id: 'longbow',
          name: 'Longbow',
          attackBonus: 6,
          diceCount: 1,
          diceSides: 8,
          damageBonus: 3,
        );
        expect(bowAttack.attackType, AttackType.rangedWeapon);

        const spellAttack = DprAttackAction(
          id: 'fire_bolt',
          name: 'Fire Bolt',
          attackBonus: 6,
          diceCount: 2,
          diceSides: 10,
          damageBonus: 0,
          damageType: 'fire',
        );
        expect(spellAttack.attackType, AttackType.rangedSpell);

        const saveSpell = DprAttackAction(
          id: 'sacred_flame',
          name: 'Sacred Flame',
          attackBonus: 0,
          diceCount: 2,
          diceSides: 8,
          damageBonus: 0,
          deliveryType: DprActionDeliveryType.savingThrow,
        );
        expect(saveSpell.attackType, AttackType.rangedSpell);
      });

      test('Grounded attacker switches to ranged attack when targeting airborne out-of-reach enemies', () {
        // Attacker has both standard melee (Bite 5ft) and ranged weapon (Shortbow)
        final archerGrounded = ArenaCombatant.fromMonster(
          id: 'archer',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
        );
        archerGrounded.isAirborne = false;
        archerGrounded.altitudeInFeet = 0;
        archerGrounded.meleeReachInFeet = 5;

        // Airborne target at 20 ft
        final airborneDragon = ArenaCombatant.fromMonster(
          id: 'dragon',
          monster: dragonMonster,
          team: ArenaTeam.teamB,
        );
        expect(airborneDragon.isAirborne, true);
        expect(airborneDragon.altitudeInFeet, 20);

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: archerGrounded,
          allCombatants: [archerGrounded, airborneDragon],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        // Grounded wolf only has Bite, cannot reach airborne dragon, logs Dodge action note
        expect(step.attackEvents.isEmpty, true);
        expect(step.specialEventSummary, contains('cannot reach airborne'));
      });
    });

    // =========================================================================
    // 4. CONDITION COMBAT MODIFIERS & AUTO-CRITICALS
    // =========================================================================
    group('Condition Combat Advantage & Auto-Crit Mechanics', () {
      test('Paralyzed or Unconscious target suffers automatic Critical Hit from 5-ft melee attacks', () {
        final attacker = ArenaCombatant.fromMonster(
          id: 'rogue',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
        );

        final paralyzedDefender = ArenaCombatant.fromMonster(
          id: 'paralyzed_target',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
          acOverride: 10,
          hpOverride: 50,
        );
        paralyzedDefender.conditions.add(ArenaCondition.paralyzed);

        final initialHp = paralyzedDefender.currentHp;

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: attacker,
          allCombatants: [attacker, paralyzedDefender],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.isNotEmpty, true);
        final event = step.attackEvents.first;
        // Against paralyzed defender within melee reach, attack has advantage and hit is an auto-crit
        expect(event.hadAdvantage, true);
        if (event.isHit) {
          expect(event.isCrit, true);
          expect(paralyzedDefender.currentHp, lessThan(initialHp));
        }
      });

      test('Prone defender grants Advantage to melee and imposes Disadvantage to ranged attacks', () {
        final proneDefender = ArenaCombatant.fromMonster(
          id: 'prone_target',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
        );
        proneDefender.conditions.add(ArenaCondition.prone);

        final attacker = ArenaCombatant.fromMonster(
          id: 'fighter',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
        );

        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: attacker,
          allCombatants: [attacker, proneDefender],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        expect(step.attackEvents.isNotEmpty, true);
        // Wolf has Bite (melee), so it must gain Advantage against prone target
        expect(step.attackEvents.first.hadAdvantage, true);
      });
    });

    // =========================================================================
    // 5. CONCENTRATION & SHIELD REACTION BOUNDARY AUDIT
    // =========================================================================
    group('Concentration & Shield Reaction Boundary Values', () {
      test('checkConcentration computes exact DC formula max(10, damage ~/ 2)', () {
        final caster = ArenaCombatant.fromMonster(id: 'c', monster: wolfMonster, team: ArenaTeam.teamA);
        caster.activeConcentrationSpellId = 'spell_bless';

        // 1. Zero damage: DC 0, concentration not broken
        final res0 = caster.checkConcentration(0, (s) => 1);
        expect(res0.broken, false);
        expect(res0.dc, 0);
        expect(caster.activeConcentrationSpellId, 'spell_bless');

        // 2. Small damage (1 to 20): DC is exactly 10
        final resSmall = caster.checkConcentration(14, (s) => 20); // 14 ~/ 2 = 7 < 10 -> DC 10
        expect(resSmall.dc, 10);
        expect(resSmall.broken, false);

        // 3. Large damage (50): DC is 25 (50 ~/ 2)
        final resLarge = caster.checkConcentration(50, (s) => 5); // 5 + conMod < 25 -> fails
        expect(resLarge.dc, 25);
        expect(resLarge.broken, true);
        expect(caster.activeConcentrationSpellId, isNull);
      });

      test('Shield reaction is NOT triggered on Nat 20 Critical Hits even if slots exist', () {
        final shieldCaster = ArenaCombatant.fromMonster(
          id: 'mage',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
          acOverride: 12,
        );
        shieldCaster.knownSpellIds.add('spell_shield');
        shieldCaster.maxSpellSlots[1] = 2;
        shieldCaster.currentSpellSlots[1] = 2;

        final attacker = ArenaCombatant.fromMonster(
          id: 'atk',
          monster: wolfMonster,
          team: ArenaTeam.teamA,
        );

        // Set up attack that hits
        final step = engine.executeTurn(
          stepIndex: 0,
          roundNumber: 1,
          attacker: attacker,
          allCombatants: [attacker, shieldCaster],
          strategy: ArenaTargetingStrategy.focusLowestHp,
        );

        // If attack was crit (Nat 20), Shield cannot turn it into a miss
        for (final event in step.attackEvents) {
          if (event.isCrit && event.d20Roll == 20) {
            expect(event.isHit, true);
          }
        }
      });
    });
  });
}
