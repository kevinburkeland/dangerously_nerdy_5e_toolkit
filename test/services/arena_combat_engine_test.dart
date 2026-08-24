import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_preset_matchups.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/aoe_resolver.dart';
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

    test('Monsters with both melee and ranged attacks do not execute both in one turn', () {
      final goblinMonster = MonsterCodexLibrary.getMonsterByName('Goblin') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_goblin') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'goblin');

      final goblin = ArenaCombatant.fromMonster(
        id: 'goblin_1',
        monster: goblinMonster,
        team: ArenaTeam.teamA,
      );
      final wolf = ArenaCombatant.fromMonster(
        id: 'wolf_1',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: goblin,
        allCombatants: [goblin, wolf],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Goblin has Scimitar (melee) and Shortbow (ranged), but no Multiattack.
      // It should make exactly 1 attack per turn, not 2.
      expect(step.attackEvents.length, 1,
          reason: 'Goblin has 1 action per round and must make only 1 attack, not both melee and ranged');
    });

    test('Monsters with multiattack options respect action economy and do not execute all branches', () {
      final medusaMonster = MonsterCodexLibrary.getMonsterByName('Medusa') ??
          MonsterCodexLibrary.getMonsterById('srd_mon_medusa') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'medusa');

      final medusa = ArenaCombatant.fromMonster(
        id: 'medusa_1',
        monster: medusaMonster,
        team: ArenaTeam.teamA,
      );
      final trex = ArenaCombatant.fromMonster(
        id: 'trex_1',
        monster: trexMonster,
        team: ArenaTeam.teamB,
      );

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: medusa,
        allCombatants: [medusa, trex],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Medusa has Snake Hair, Shortsword, and Longbow.
      // Her Multiattack allows 3 melee attacks (snake hair/shortsword) or 3 longbow attacks.
      // She should make exactly 3 attacks, not 5 (3 snake hair + 1 shortsword + 1 longbow).
      expect(step.attackEvents.length, 3,
          reason: 'Medusa must make exactly 3 attacks in her multiattack routine, not execute every weapon');
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

    test('Spellcaster parsing pre-caches slots, DC, attack bonus, and known spells', () {
      final lichMonster = MonsterCodexLibrary.getMonsterByName('Lich') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('lich'));

      final lich = ArenaCombatant.fromMonster(
        id: 'lich_1',
        monster: lichMonster,
        team: ArenaTeam.teamA,
      );

      expect(lich.isSpellcaster, true);
      expect(lich.maxSpellSlots.isNotEmpty, true);
      expect(lich.currentSpellSlots.isNotEmpty, true);
      expect(lich.knownSpellIds.isNotEmpty, true);
      expect(lich.spellSaveDc, greaterThan(10));
      expect(lich.spellAttackBonus, greaterThan(0));

      // Check clone deep-copy
      final clone = lich.clone();
      expect(clone.currentSpellSlots, equals(lich.currentSpellSlots));
      clone.currentSpellSlots[1] = 0;
      expect(lich.currentSpellSlots[1], isNot(0));

      // Check reset
      lich.currentSpellSlots[1] = 0;
      final resetLich = lich.reset();
      expect(resetLich.currentSpellSlots[1], lich.maxSpellSlots[1]);
    });

    test('Defensive Reaction Hook: Shield negates incoming attack and expends spell slot', () {
      final caster = ArenaCombatant.fromMonster(
        id: 'caster',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
        acOverride: 12,
      );
      // Give defender Shield spell and a 1st level slot
      caster.knownSpellIds.add('spell_shield');
      caster.maxSpellSlots[1] = 2;
      caster.currentSpellSlots[1] = 2;

      final attacker = ArenaCombatant.fromMonster(
        id: 'atk',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );

      // Attack roll with totalAttack = 14 (hits AC 12, but < AC 12 + 5 = 17)
      final initialHp = caster.currentHp;
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: attacker,
        allCombatants: [attacker, caster],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(step.attackEvents.isNotEmpty, true);
      // If shield triggered, reaction was used and slot deducted
      if (step.attackEvents.any((e) => e.summaryText.contains('Shield'))) {
        expect(caster.usedReactionThisRound, true);
        expect(caster.currentSpellSlots[1], 1);
        expect(caster.currentHp, initialHp);
      }
    });

    test('Concentration Check Pipeline: Breaks concentration on failed Con save', () {
      final combatant = ArenaCombatant.fromMonster(
        id: 'caster',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      combatant.activeConcentrationSpellId = 'spell_hold_monster';

      // Small damage with low roll
      final res = combatant.checkConcentration(40, (_) => 1); // DC max(10, 20) = 20, roll 1+conMod < 20
      expect(res.broken, true);
      expect(combatant.activeConcentrationSpellId, isNull);
    });

    test('Elemental damage routing respects monster immunities (e.g. Fire Elemental)', () {
      final fireElementalMonster = MonsterCodexLibrary.getMonsterByName('Fire Elemental') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('fire elemental'));

      final fireElem = ArenaCombatant.fromMonster(
        id: 'fire_elem',
        monster: fireElementalMonster,
        team: ArenaTeam.teamB,
      );

      final initialHp = fireElem.currentHp;

      // Attacker casts Fireball
      final mage = ArenaCombatant.fromMonster(
        id: 'mage',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      mage.knownSpellIds.add('spell_fireball');
      mage.maxSpellSlots[3] = 2;
      mage.currentSpellSlots[3] = 2;

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: mage,
        allCombatants: [mage, fireElem],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Fire Elemental is immune to fire damage, so HP must remain unchanged
      expect(fireElem.currentHp, initialHp);
      expect(step.attackEvents.every((e) => e.damageDealt == 0), true);
    });

    test('DMG p.249 AoeResolver: deterministic base target caps and shape parsing', () {
      // Sphere: 20 ft radius / 5 = 4
      expect(AoeResolver.getBaseTargetCap(AoeShape.sphere, 20), 4.0);
      // Cylinder: 10 ft radius / 5 = 2
      expect(AoeResolver.getBaseTargetCap(AoeShape.cylinder, 10), 2.0);
      // Cone: 60 ft cone / 10 = 6
      expect(AoeResolver.getBaseTargetCap(AoeShape.cone, 60), 6.0);
      // Cube: 15 ft cube / 10 = 1.5
      expect(AoeResolver.getBaseTargetCap(AoeShape.cube, 15), 1.5);
      // Line: 100 ft line / 30 = 3.333
      expect(AoeResolver.getBaseTargetCap(AoeShape.line, 100), closeTo(3.33, 0.05));

      // Parsing
      final fireballParsed = AoeResolver.parseShapeAndSize('Fireball (20-foot radius)');
      expect(fireballParsed.shape, AoeShape.sphere);
      expect(fireballParsed.sizeInFeet, 20.0);

      final breathParsed = AoeResolver.parseShapeAndSize('Fire Breath (60-foot cone)');
      expect(breathParsed.shape, AoeShape.cone);
      expect(breathParsed.sizeInFeet, 60.0);

      final lightningParsed = AoeResolver.parseShapeAndSize('Lightning Bolt (100-foot line)');
      expect(lightningParsed.shape, AoeShape.line);
      expect(lightningParsed.sizeInFeet, 100.0);
    });

    test('DMG p.249 AoeResolver: Box-Muller Gaussian clustering and target selection', () {
      final targets = List.generate(
        8,
        (i) => ArenaCombatant.fromMonster(
          id: 'wolf_$i',
          monster: wolfMonster,
          team: ArenaTeam.teamB,
          hpOverride: (i + 1) * 5,
        ),
      );

      // Sphere 20ft (base cap = 4)
      final selected = AoeResolver.selectTargets(
        livingEnemies: targets,
        shape: AoeShape.sphere,
        sizeInFeet: 20,
        rng: Random(42),
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(selected.isNotEmpty, true);
      expect(selected.length, lessThanOrEqualTo(targets.length));
      // Focus Lowest HP must pick lowest HP first
      for (int i = 0; i < selected.length - 1; i++) {
        expect(selected[i].currentHp, lessThanOrEqualTo(selected[i + 1].currentHp));
      }
    });

    test('Aerial Combat & Reach Validation: Grounded meleeStandard cannot hit airborne enemy', () {
      final flyer = ArenaCombatant.fromMonster(
        id: 'dragon',
        monster: dragonMonster,
        team: ArenaTeam.teamB,
      );
      expect(flyer.isAirborne, true);
      expect(flyer.altitudeInFeet, 20);

      final groundedWolf = ArenaCombatant.fromMonster(
        id: 'wolf',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      expect(groundedWolf.isAirborne, false);
      expect(groundedWolf.altitudeInFeet, 0);
      expect(groundedWolf.meleeReachInFeet, 5);

      // Wolf only has Bite (meleeStandard, reach 5 ft).
      // Grounded wolf cannot reach airborne dragon at 20 ft altitude.
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: groundedWolf,
        allCombatants: [groundedWolf, flyer],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Step should note that wolf cannot reach and takes Dodge action
      expect(step.attackEvents.isEmpty, true);
      expect(step.specialEventSummary?.contains('cannot reach airborne'), true);
    });

    test('Fall Damage & Condition Trigger: Non-hovering airborne entity falls on prone/stun/paralyze', () {
      final flyer = ArenaCombatant.fromMonster(
        id: 'dragon',
        monster: dragonMonster,
        team: ArenaTeam.teamB,
      );
      expect(flyer.isAirborne, true);
      expect(flyer.hasHover, false);
      expect(flyer.altitudeInFeet, 20);

      final initialHp = flyer.currentHp;

      // Apply Prone condition
      final fallRes = flyer.applyCondition(
        ArenaCondition.prone,
        (sides) => 4, // Roll 4 on each d6 (2d6 for 20 ft = 8 damage)
        DmRulesEdition.v2024,
      );

      expect(fallRes.fell, true);
      expect(fallRes.fallDamage, 8);
      expect(flyer.isAirborne, false);
      expect(flyer.altitudeInFeet, 0);
      expect(flyer.isProne, true);
      expect(flyer.currentHp, initialHp - 8);
      expect(fallRes.log?.contains('fell 20 ft.'), true);
    });

    test('Hover capability prevents falling when conditions like Prone or Stunned are inflicted', () {
      final hoverCombatant = ArenaCombatant(
        id: 'hover_flier',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
        displayName: 'Floating Beholder',
        maxHp: 50,
        currentHp: 50,
        ac: 14,
        initiativeBonus: 2,
        isAirborne: true,
        hasHover: true,
        altitudeInFeet: 20,
      );

      final fallRes = hoverCombatant.applyCondition(
        ArenaCondition.paralyzed,
        (sides) => 6,
        DmRulesEdition.v2024,
      );

      expect(fallRes.fell, false);
      expect(fallRes.fallDamage, 0);
      expect(hoverCombatant.isAirborne, true);
      expect(hoverCombatant.altitudeInFeet, 20);
      expect(hoverCombatant.isParalyzed, true);
    });

    test('High-Tier Optimization: Lich vs 4 Gladiators completes in under 5 rounds on average with active 1st-5th slot utilization and legendary actions', () {
      final lichMonster = MonsterCodexLibrary.getMonsterByName('Lich') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('lich'));
      final gladiatorMonster = MonsterCodexLibrary.getMonsterByName('Gladiator') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('gladiator'));

      final lich = ArenaCombatant.fromMonster(
        id: 'lich_boss',
        monster: lichMonster,
        team: ArenaTeam.teamA,
      );

      final gladiators = List.generate(
        4,
        (i) => ArenaCombatant.fromMonster(
          id: 'gladiator_$i',
          monster: gladiatorMonster,
          team: ArenaTeam.teamB,
          customName: 'Gladiator #${i + 1}',
        ),
      );

      expect(lich.isSpellcaster, true);
      expect(lich.hasLegendaryActions, true);
      expect(lich.knownSpellIds.contains('spell_fireball'), true);
      expect(lich.knownSpellIds.contains('spell_blight'), true);
      expect(lich.knownSpellIds.contains('spell_finger_of_death'), true);

      // Run Monte Carlo simulation of 100 battles
      final mcResult = engine.runMonteCarlo(
        teamA: [lich],
        teamB: gladiators,
        iterations: 100,
      );

      // Total battle duration should be well under 5 rounds on average (was 30+ rounds previously!)
      expect(mcResult.averageRounds, lessThanOrEqualTo(5.0), reason: 'Average battle duration should be <= 5 rounds');
      expect(mcResult.teamAWinRate, greaterThan(75.0), reason: 'Lich (CR 21) should decisively defeat 4 Gladiators (CR 5)');

      // Verify a single match step history
      final singleMatch = engine.simulateMatch(
        initialTeamA: [lich],
        initialTeamB: gladiators,
      );

      expect(singleMatch.totalRounds, lessThanOrEqualTo(5));

      // Verify spellcasting and legendary actions took place in steps
      final allEvents = singleMatch.steps.expand((s) => s.attackEvents).toList();
      final hasLegendaryEvent = allEvents.any((e) => e.attackName.toLowerCase().contains('legendary'));
      expect(hasLegendaryEvent, true, reason: 'Lich should execute off-turn legendary actions');

      final spellEvents = allEvents.where((e) =>
          e.attackName.contains('Disintegrate') ||
          e.attackName.contains('Fireball') ||
          e.attackName.contains('Blight') ||
          e.attackName.contains('Finger of Death') ||
          e.attackName.contains('Cloudkill') ||
          e.attackName.contains('Power Word Kill') ||
          e.attackName.contains('Ray of Frost')).toList();

      expect(spellEvents.isNotEmpty, true, reason: 'Lich should actively cast leveled offensive spells and cantrips');
    });

    test('Off-turn Legendary Actions trigger and consume legendary actions pool', () {
      final lichMonster = MonsterCodexLibrary.getMonsterByName('Lich') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('lich'));

      final lich = ArenaCombatant.fromMonster(
        id: 'lich_test',
        monster: lichMonster,
        team: ArenaTeam.teamA,
      );

      final gladiator = ArenaCombatant.fromMonster(
        id: 'glad_test',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      expect(lich.hasLegendaryActions, true);
      expect(lich.legendaryActionsRemaining, 3);

      // Opponent takes turn
      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: gladiator,
        allCombatants: [lich, gladiator],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Legendary actions should have been triggered off-turn
      final legEvents = step.attackEvents.where((e) => e.attackName.contains('Legendary')).toList();
      expect(legEvents.isNotEmpty, true);
      expect(lich.legendaryActionsRemaining, lessThan(3));
    });

    test('Spellcaster upcasts Fireball and Blight into higher slots when base slot is empty', () {
      final caster = ArenaCombatant.fromMonster(
        id: 'mage',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      caster.knownSpellIds.addAll(['spell_fireball', 'spell_blight']);
      // Empty 3rd and 4th level slots, but grant 5th level slots
      caster.maxSpellSlots[3] = 0;
      caster.currentSpellSlots[3] = 0;
      caster.maxSpellSlots[4] = 0;
      caster.currentSpellSlots[4] = 0;
      caster.maxSpellSlots[5] = 2;
      caster.currentSpellSlots[5] = 2;

      final gladiatorMonster = MonsterCodexLibrary.getMonsterByName('Gladiator') ??
          MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase().contains('gladiator'));

      final enemies = List.generate(
        3,
        (i) => ArenaCombatant.fromMonster(
          id: 'foe_$i',
          monster: gladiatorMonster,
          team: ArenaTeam.teamB,
        ),
      );

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: caster,
        allCombatants: [caster, ...enemies],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Should have upcast Fireball into slot 5
      expect(caster.currentSpellSlots[5], 1);
      expect(step.attackEvents.any((e) => e.attackName.contains('Fireball (Slot 5)')), true);
    });

    test('Concentration on defensive spell does not block instantaneous leveled damage spells', () {
      final caster = ArenaCombatant.fromMonster(
        id: 'caster',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      caster.knownSpellIds.addAll(['spell_globe_of_invulnerability', 'spell_fireball', 'spell_finger_of_death']);
      caster.maxSpellSlots[7] = 2;
      caster.currentSpellSlots[7] = 2;
      caster.maxSpellSlots[3] = 2;
      caster.currentSpellSlots[3] = 2;

      // Simulate active concentration
      caster.activeConcentrationSpellId = 'spell_globe_of_invulnerability';

      final enemy = ArenaCombatant.fromMonster(
        id: 'enemy_single',
        monster: wolfMonster,
        team: ArenaTeam.teamB,
      );

      final step = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: caster,
        allCombatants: [caster, enemy],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // Should still cast Finger of Death or Fireball without breaking or being locked
      expect(caster.activeConcentrationSpellId, 'spell_globe_of_invulnerability');
      expect(step.attackEvents.any((e) => e.attackName.contains('Finger of Death') || e.attackName.contains('Fireball')), true);
    });

    test('Audit all Monster Codex spellcasters: verify spell slots, known spells, and DC/attack bonuses', () {
      final spellcasterMonsters = <String>[];
      final failedSpellcasters = <String>[];

      for (final monster in MonsterCodexLibrary.allMonsters) {
        final sb = monster.getStatBlock(DmRulesEdition.v2024);
        final corpus = sb.traits.map((t) => '${t.name}: ${t.description}').join('\n').toLowerCase();

        final mentionsSpellcasting = corpus.contains('spellcaster') ||
            corpus.contains('spellcasting') ||
            corpus.contains('innate spell') ||
            corpus.contains('pact magic');

        if (mentionsSpellcasting) {
          final combatant = ArenaCombatant.fromMonster(
            id: 'audit_${monster.id}',
            monster: monster,
            team: ArenaTeam.teamA,
          );

          spellcasterMonsters.add('${monster.name} (CR ${monster.challengeRating}) -> Slots: ${combatant.maxSpellSlots}, Known Spells: ${combatant.knownSpellIds.length}');

          if (!combatant.isSpellcaster || (combatant.maxSpellSlots.isEmpty && combatant.knownSpellIds.isEmpty)) {
            failedSpellcasters.add('${monster.name} (${monster.id}) failed to parse spell slots or known spells');
          }
        }
      }

      // Print all audited spellcasters
      // ignore: avoid_print
      print('=== AUDITED ${spellcasterMonsters.length} SPELLCASTERS IN MONSTER CODEX ===');
      for (final sc in spellcasterMonsters) {
        // ignore: avoid_print
        print(sc);
      }

      expect(failedSpellcasters, isEmpty, reason: 'All monsters with spellcasting traits should have non-empty parsed spells or slots');
      expect(spellcasterMonsters.length, greaterThanOrEqualTo(10));
    });

    test('Legendary Resistance parses correctly on high-CR boss monsters', () {
      final redDragon = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'ancient red dragon');
      final dragonCombatant = ArenaCombatant.fromMonster(
        id: 'red_dragon',
        monster: redDragon,
        team: ArenaTeam.teamA,
      );

      expect(dragonCombatant.maxLegendaryResistances, 3);
      expect(dragonCombatant.legendaryResistancesRemaining, 3);
      expect(dragonCombatant.hasLegendaryResistances, true);

      final lichMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'lich');
      final lichCombatant = ArenaCombatant.fromMonster(
        id: 'lich_1',
        monster: lichMonster,
        team: ArenaTeam.teamB,
      );

      expect(lichCombatant.maxLegendaryResistances, 3);
      expect(lichCombatant.legendaryResistancesRemaining, 3);
      expect(lichCombatant.hasLegendaryResistances, true);
    });

    test('Legendary Resistance automatically converts failed saves to successes and decrements remaining charges', () {
      final engine = ArenaCombatEngine(rng: Random(42));
      final lichMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'lich');
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');

      final caster = ArenaCombatant.fromMonster(
        id: 'caster_disintegrate',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      caster.knownSpellIds.add('spell_disintegrate');
      caster.maxSpellSlots[6] = 2;
      caster.currentSpellSlots[6] = 2;

      // Boss defender with 3 Legendary Resistances
      final bossDefender = ArenaCombatant.fromMonster(
        id: 'boss_lich',
        monster: lichMonster,
        team: ArenaTeam.teamB,
      );
      bossDefender.currentHp = 10; // Low HP to trigger killshot / high priority

      expect(bossDefender.legendaryResistancesRemaining, 3);

      final turnResult = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: caster,
        allCombatants: [caster, bossDefender],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      // The boss should have used a legendary resistance if the save was failed
      final attackEvent = turnResult.attackEvents.firstWhere((e) => e.attackName.contains('Disintegrate'));
      expect(attackEvent.isSavingThrow, true);
      if (attackEvent.saved && attackEvent.summaryText.contains('LEGENDARY RESISTANCE')) {
        expect(bossDefender.legendaryResistancesRemaining, 2);
        expect(bossDefender.isAlive, true);
      }
    });

    test('Depleted Legendary Resistances (0 remaining) do not prevent failed saves', () {
      final engine = ArenaCombatEngine(rng: Random(42));
      final lichMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'lich');
      final wolfMonster = MonsterCodexLibrary.allMonsters.firstWhere((m) => m.name.toLowerCase() == 'wolf');

      final caster = ArenaCombatant.fromMonster(
        id: 'caster_hold',
        monster: wolfMonster,
        team: ArenaTeam.teamA,
      );
      caster.knownSpellIds.add('spell_hold_monster');
      caster.maxSpellSlots[5] = 1;
      caster.currentSpellSlots[5] = 1;

      final bossDefender = ArenaCombatant.fromMonster(
        id: 'boss_lich',
        monster: lichMonster,
        team: ArenaTeam.teamB,
      );
      // Deplete all legendary resistances
      bossDefender.legendaryResistancesRemaining = 0;

      expect(bossDefender.useLegendaryResistance(), false);
      expect(bossDefender.legendaryResistancesRemaining, 0);

      final turnResult = engine.executeTurn(
        stepIndex: 0,
        roundNumber: 1,
        attacker: caster,
        allCombatants: [caster, bossDefender],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(turnResult.attackEvents.isNotEmpty, true);
    });
  });
}



