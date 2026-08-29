import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Imported Character & Monster Optimal Attack Pattern Tests', () {
    test('extracts optimal multiattack branch when creature has multiple weapon options', () {
      // Gladiator-style monster with choice between Scimitar + Shield Bash melee branch vs Javelin ranged branch
      const statBlock = MinionStatBlock(
        id: 'test_gladiator',
        name: 'Gladiator',
        crDisplay: '5',
        sizeDisplay: 'Medium',
        typeDisplay: 'Humanoid',
        ac: 16,
        maxHp: 112,
        speed: '30 ft.',
        strScore: 18,
        dexScore: 15,
        conScore: 16,
        intScore: 10,
        wisScore: 12,
        chaScore: 15,
        attackBonus: 7,
        damageBonus: 4,
        damageDiceCount: 1,
        damageDiceSides: 6,
        damageType: 'slashing',
        actions: [
          CreatureAction(
            name: 'Multiattack',
            description:
                'The gladiator makes three melee attacks: two with its scimitar and one with its shield bash. Or it makes two ranged attacks with its javelins.',
          ),
          CreatureAction(
            name: 'Scimitar',
            description: 'Melee Weapon Attack: +7 to hit, reach 5 ft., one target. Hit: 7 (1d6 + 4) slashing damage.',
            attackBonus: 7,
            hitDamage: '1d6 + 4',
          ),
          CreatureAction(
            name: 'Shield Bash',
            description: 'Melee Weapon Attack: +7 to hit, reach 5 ft., one creature. Hit: 9 (2d4 + 4) bludgeoning damage.',
            attackBonus: 7,
            hitDamage: '2d4 + 4',
          ),
          CreatureAction(
            name: 'Javelin',
            description: 'Ranged Weapon Attack: +7 to hit, range 30/120 ft., one target. Hit: 7 (1d6 + 4) piercing damage.',
            attackBonus: 7,
            hitDamage: '1d6 + 4',
          ),
        ],
      );

      final attacks = statBlock.extractDprAttacks();
      final scimitar = attacks.firstWhere((a) => a.name.toLowerCase().contains('scimitar'));
      final shieldBash = attacks.firstWhere((a) => a.name.toLowerCase().contains('shield bash'));
      final javelin = attacks.firstWhere((a) => a.name.toLowerCase().contains('javelin'));

      // Melee branch yields 2 Scimitar + 1 Shield Bash (Total 3 attacks) vs 2 Javelins (Total 2 attacks)
      // The engine should select the higher DPR 3-attack melee branch!
      expect(scimitar.attacksPerRound, equals(2));
      expect(shieldBash.attacksPerRound, equals(1));
      expect(javelin.attacksPerRound, equals(0));
    });

    test('picks the highest DPR attack when an imported character has multiple single-attack weapons', () {
      // Monster with a weak Dagger vs strong Greatsword without multiattack
      const statBlock = MinionStatBlock(
        id: 'test_warrior',
        name: 'Warrior',
        crDisplay: '1',
        sizeDisplay: 'Medium',
        typeDisplay: 'Humanoid',
        ac: 14,
        maxHp: 30,
        speed: '30 ft.',
        strScore: 16,
        dexScore: 12,
        conScore: 14,
        intScore: 10,
        wisScore: 10,
        chaScore: 10,
        attackBonus: 5,
        damageBonus: 3,
        damageDiceCount: 1,
        damageDiceSides: 4,
        damageType: 'piercing',
        actions: [
          CreatureAction(
            name: 'Dagger',
            description: 'Melee Weapon Attack: +3 to hit, reach 5 ft., one target. Hit: 5 (1d4 + 3) piercing damage.',
            attackBonus: 3,
            hitDamage: '1d4 + 3',
          ),
          CreatureAction(
            name: 'Greatsword',
            description: 'Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 10 (2d6 + 3) slashing damage.',
            attackBonus: 5,
            hitDamage: '2d6 + 3',
          ),
        ],
      );

      final attacks = statBlock.extractDprAttacks();
      final dagger = attacks.firstWhere((a) => a.name.toLowerCase().contains('dagger'));
      final greatsword = attacks.firstWhere((a) => a.name.toLowerCase().contains('greatsword'));

      // The engine selects Greatsword as the active attack (attacksPerRound = 1) and Dagger as inactive (0)
      expect(greatsword.attacksPerRound, equals(1));
      expect(dagger.attacksPerRound, equals(0));
    });

    test('DprCombatantProfile.fromMonsterItem accurately extracts multiattacks and riders', () {
      final monster = MonsterItem.simple(
        id: 'wyvern',
        name: 'Wyvern',
        statBlock: const MinionStatBlock(
          id: 'wyvern',
          name: 'Wyvern',
          crDisplay: '6',
          sizeDisplay: 'Large',
          typeDisplay: 'Dragon',
          ac: 13,
          maxHp: 110,
          speed: '20 ft., fly 80 ft.',
          strScore: 19,
          dexScore: 10,
          conScore: 16,
          intScore: 5,
          wisScore: 12,
          chaScore: 6,
          attackBonus: 7,
          damageBonus: 4,
          damageDiceCount: 2,
          damageDiceSides: 6,
          damageType: 'piercing',
          actions: [
            CreatureAction(
              name: 'Multiattack',
              description: 'The wyvern makes two attacks: one with its bite and one with its stinger. While flying, it can use its claws in place of its bite.',
            ),
            CreatureAction(
              name: 'Bite',
              description: 'Melee Weapon Attack: +7 to hit, reach 10 ft., one target. Hit: 11 (2d6 + 4) piercing damage.',
              attackBonus: 7,
              hitDamage: '2d6 + 4',
            ),
            CreatureAction(
              name: 'Stinger',
              description: 'Melee Weapon Attack: +7 to hit, reach 10 ft., one creature. Hit: 11 (2d6 + 4) piercing damage plus 24 (7d6) poison damage.',
              attackBonus: 7,
              hitDamage: '2d6 + 4',
            ),
          ],
        ),
      );

      final profile = DprCombatantProfile.fromMonsterItem(monster);
      expect(profile.attacks, isNotEmpty);
      
      final bite = profile.attacks.firstWhere((a) => a.name.toLowerCase().contains('bite'));
      final stinger = profile.attacks.firstWhere((a) => a.name.toLowerCase().contains('stinger'));

      expect(bite.attacksPerRound, equals(1));
      expect(stinger.attacksPerRound, equals(1));
      expect(stinger.secondaryDiceCount, equals(7));
      expect(stinger.secondaryDiceSides, equals(6));
    });

    test('ArenaCombatEngine selects most efficient fallback attack', () {
      final engine = ArenaCombatEngine();

      final combatant = ArenaCombatant.fromMonster(
        id: 'bandit_1',
        monster: MonsterItem.simple(
          id: 'bandit',
          name: 'Bandit',
          statBlock: const MinionStatBlock(
            id: 'bandit',
            name: 'Bandit',
            crDisplay: '1/8',
            sizeDisplay: 'Medium',
            typeDisplay: 'Humanoid',
            ac: 12,
            maxHp: 11,
            speed: '30 ft.',
            strScore: 11,
            dexScore: 12,
            conScore: 12,
            intScore: 10,
            wisScore: 10,
            chaScore: 10,
            attackBonus: 3,
            damageBonus: 1,
            damageDiceCount: 1,
            damageDiceSides: 6,
            damageType: 'slashing',
            actions: [
              CreatureAction(
                name: 'Scimitar',
                description: 'Melee Weapon Attack: +3 to hit, reach 5 ft., one target. Hit: 4 (1d6 + 1) slashing damage.',
                attackBonus: 3,
                hitDamage: '1d6 + 1',
              ),
              CreatureAction(
                name: 'Light Crossbow',
                description: 'Ranged Weapon Attack: +3 to hit, range 80/320 ft., one target. Hit: 5 (1d8 + 1) piercing damage.',
                attackBonus: 3,
                hitDamage: '1d8 + 1',
              ),
            ],
          ),
        ),
        team: ArenaTeam.teamA,
      );

      final enemy = ArenaCombatant.fromMonster(
        id: 'dummy_1',
        monster: MonsterItem.simple(
          id: 'target_dummy',
          name: 'Target Dummy',
          statBlock: const MinionStatBlock(
            id: 'target_dummy',
            name: 'Target Dummy',
            crDisplay: '0',
            sizeDisplay: 'Medium',
            typeDisplay: 'Construct',
            ac: 10,
            maxHp: 30,
            speed: '0 ft.',
            strScore: 10,
            dexScore: 10,
            conScore: 10,
            intScore: 1,
            wisScore: 1,
            chaScore: 1,
            attackBonus: 0,
            damageBonus: 0,
            damageDiceCount: 0,
            damageDiceSides: 0,
            damageType: 'none',
          ),
        ),
        team: ArenaTeam.teamB,
      );

      final step = engine.executeTurn(
        stepIndex: 1,
        roundNumber: 1,
        attacker: combatant,
        allCombatants: [combatant, enemy],
        strategy: ArenaTargetingStrategy.focusLowestHp,
      );

      expect(step.attackEvents, isNotEmpty);
      // Light Crossbow deals 1d8+1 (5.5 avg) vs Scimitar 1d6+1 (4.5 avg); engine selects Light Crossbow
      expect(step.attackEvents.first.attackName, equals('Light Crossbow'));
    });

    test('compendium JSON ingestion parses actions, bonus actions, and multiattacks', () {
      const monsterJson = '''
{
  "monster": [
    {
      "name": "Death Knight Captain",
      "source": "HOMEBREW",
      "size": "Medium",
      "type": "undead",
      "ac": [{"ac": 18}],
      "hp": {"average": 180, "formula": "19d8 + 95"},
      "cr": "17",
      "action": [
        {
          "name": "Multiattack",
          "entries": [
            "The death knight makes three longsword attacks."
          ]
        },
        {
          "name": "Longsword",
          "entries": [
            "Melee Weapon Attack: +11 to hit, reach 5 ft., one target. Hit: 9 (1d8 + 5) slashing damage plus 18 (4d8) necrotic damage."
          ]
        }
      ],
      "bonus": [
        {
          "name": "Command Undead",
          "entries": ["Commands an undead ally within 30 ft. to make a reaction strike."]
        }
      ]
    }
  ]
}
''';

      final result = CompendiumJsonIngestionPipeline().ingestJsonString(monsterJson);
      expect(result.monsters.length, equals(1));
      
      final m = result.monsters.first;
      expect(m.name, equals('Death Knight Captain'));
      expect(m.actionsMarkdown, contains('Multiattack'));
      expect(m.actionsMarkdown, contains('Longsword'));
      expect(m.actionsMarkdown, contains('### Bonus Actions'));
      expect(m.actionsMarkdown, contains('Command Undead'));

      final item = m.toMonsterItem();
      final attacks = item.getStatBlock(DmRulesEdition.v2024).extractDprAttacks();
      final longsword = attacks.firstWhere((a) => a.name.toLowerCase().contains('longsword'));

      expect(longsword.attacksPerRound, equals(3));
      expect(longsword.secondaryDiceCount, equals(4));
      expect(longsword.secondaryDiceSides, equals(8));
      expect(longsword.secondaryDamageType, equals('necrotic'));
    });
  });
}
