import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

class _FixedD20Random implements Random {
  final int fixedD20;
  _FixedD20Random(this.fixedD20);

  @override
  int nextInt(int max) => max == 20 ? fixedD20 - 1 : 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}

void main() {
  group(
    'Fix 5.4: Arena & ACL default save DC uses full SRD CR 0-30 proficiency ladder',
    () {
      test(
        'CR 20-30 StatBlockAclParser default spell DC, attack bonus, and fallback rider DC use PB +6/+7/+8/+9',
        () {
          final base = MonsterCodexLibrary.allMonsters
              .firstWhere((m) => m.id == 'srd_mon_tarrasque')
              .statBlock2014;
          final sb = MonsterStatBlock(
            id: 'test_titan',
            name: 'Test Titan',
            sizeDisplay: base.sizeDisplay,
            crDisplay: base.crDisplay,
            typeDisplay: base.typeDisplay,
            alignment: base.alignment,
            ac: 25,
            maxHp: 500,
            speed: '40 ft.',
            strScore: 30, // +10
            dexScore: 10, // +0
            conScore: 30, // +10
            intScore: 16, // +3
            wisScore: 16, // +3
            chaScore: 16, // +3
            actions: const [
              CreatureAction(
                name: 'Earthshaker',
                description:
                    'Melee Weapon Attack: +19 to hit, reach 10 ft., one target. Hit: 20 (2d10 + 9) bludgeoning damage and the target is knocked prone.',
              ),
            ],
            attackBonus: 19,
            damageDiceCount: 2,
            damageDiceSides: 10,
            damageBonus: 9,
            damageType: 'bludgeoning',
          );

          final expectedPbs = <double, int>{
            20.0: 6,
            21.0: 7,
            24.0: 7,
            25.0: 8,
            28.0: 8,
            29.0: 9,
            30.0: 9,
          };

          for (final entry in expectedPbs.entries) {
            final cr = entry.key;
            final expectedPb = entry.value;
            final parsed = StatBlockAclParser.parseStatBlockBoundary(
              sb,
              challengeRating: cr,
            );
            expect(
              parsed.spellSaveDc,
              8 + expectedPb + 3,
              reason: 'CR $cr spellSaveDc should use PB +$expectedPb',
            );
            expect(
              parsed.spellAttackBonus,
              expectedPb + 3,
              reason: 'CR $cr spellAttackBonus should use PB +$expectedPb',
            );
            final riderDc = parsed.attacks['earthshaker']?.riders
                .whereType<ConditionRider>()
                .firstOrNull
                ?.saveDc;
            expect(
              riderDc,
              8 + expectedPb + 10,
              reason: 'CR $cr fallback rider DC should use PB +$expectedPb',
            );
          }
        },
      );

      test(
        'ArenaCombatEngine default AoE save DC for CR 30 attacker uses PB +9 (DC 27, not DC 24)',
        () {
          // Attacker: CR 30, STR/CON = 30 (+10 mod).
          // With PB +9: default save DC = 8 + 9 + 10 = 27.
          // With old capped PB +6: default save DC was 8 + 6 + 10 = 24.
          final tarrasque = MonsterCodexLibrary.allMonsters
              .firstWhere((m) => m.id == 'srd_mon_tarrasque');
          final base = tarrasque.statBlock2014;
          final titanSb = MonsterStatBlock(
            id: 'test_cr30_titan',
            name: 'Default-DC Titan',
            sizeDisplay: base.sizeDisplay,
            crDisplay: base.crDisplay,
            typeDisplay: base.typeDisplay,
            alignment: base.alignment,
            ac: 25,
            maxHp: 500,
            speed: '40 ft.',
            strScore: 30,
            dexScore: 10,
            conScore: 30,
            intScore: 10,
            wisScore: 10,
            chaScore: 10,
            actions: const [
              CreatureAction(
                name: 'Shockwave Breath (Recharge 5-6)',
                description:
                    'Each creature in a 30-foot cone must make a Dexterity saving throw, taking 28 (8d6) force damage on a failed save, or half as much damage on a successful one.',
              ),
            ],
            attackBonus: 19,
            damageDiceCount: 2,
            damageDiceSides: 10,
            damageBonus: 9,
            damageType: 'bludgeoning',
          );
          final titanMonster = MonsterItem(
            id: 'test_cr30_titan',
            name: 'Default-DC Titan',
            statBlock2014: titanSb,
            statBlock2024: titanSb,
          );

          final wolf = MonsterCodexLibrary.allMonsters
              .firstWhere((m) => m.id == 'srd_mon_wolf');
          final targetSb = MonsterStatBlock(
            id: 'test_target',
            name: 'Sturdy Target',
            sizeDisplay: wolf.statBlock2014.sizeDisplay,
            crDisplay: '5',
            typeDisplay: wolf.statBlock2014.typeDisplay,
            alignment: wolf.statBlock2014.alignment,
            ac: 10,
            maxHp: 200,
            speed: '30 ft.',
            strScore: 20,
            dexScore: 20,
            conScore: 20,
            intScore: 20,
            wisScore: 20,
            chaScore: 20,
            savingThrows: 'Dex +10',
            actions: const [],
            attackBonus: 5,
            damageDiceCount: 1,
            damageDiceSides: 4,
            damageBonus: 2,
            damageType: 'bludgeoning',
          );
          final targetMonster = MonsterItem(
            id: 'test_target',
            name: 'Sturdy Target',
            statBlock2014: targetSb,
            statBlock2024: targetSb,
          );

          final attacker = ArenaCombatant.fromMonster(
            id: 'titan',
            monster: titanMonster,
            team: ArenaTeam.teamA,
          );
          final defender = ArenaCombatant.fromMonster(
            id: 'target',
            monster: targetMonster,
            team: ArenaTeam.teamB,
          );

          // Defender rolls 15 + 10 = 25: beats old DC 24, fails new DC 27.
          final engine = ArenaCombatEngine(rng: _FixedD20Random(15));
          final step = engine.executeTurn(
            stepIndex: 0,
            roundNumber: 1,
            attacker: attacker,
            allCombatants: [attacker, defender],
            strategy: ArenaTargetingStrategy.focusLowestHp,
          );

          final shockwaveEvent = step.attackEvents
              .firstWhere((e) => e.attackName.contains('Shockwave'));
          expect(
            shockwaveEvent.summaryText,
            contains('DC 27'),
            reason: 'CR 30 default save DC must be 8 + 9 + 10 = 27',
          );
          expect(
            shockwaveEvent.isHit,
            isTrue,
            reason: 'Save total 25 fails DC 27',
          );
          expect(proficiencyBonusForChallengeRating(30.0), 9);
        },
      );
    },
  );
}
