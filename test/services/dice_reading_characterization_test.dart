import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_other_category.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_quick_roll_dialog.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/simulation/combat_rider.dart';
import '../test_doubles/service_test_configurator.dart';

final _testReplica = ReplicaId('test_runner_replica');

const _baseCharacter = Character(
  id: EntityId(slug: 'char-test', ruleset: RulesetVersion.v2024),
  name: 'Test Hero',
  speciesRef: EntityReference.empty(
      refType: EntityType.species, slug: 'human', displayName: 'Human'),
  progression: CharacterProgression(
    classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
        level: 5,
        hitDie: 'd10',
        isStartingClass: true,
      ),
    ],
  ),
  baseScores: AbilityScores(strength: 16, charisma: 14),
  resources: CharacterResourcePool(),
);

Spell _makeSpell({
  required String formula,
  String? scalingFormula,
  String? higherLevelsMarkdown,
  int level = 1,
}) {
  return Spell(
    id: const EntityId(slug: 'spell-test', ruleset: RulesetVersion.v2024),
    name: 'Test Spell',
    level: level,
    school: 'evocation',
    castingTime: const CastingTime(
        cost: 1, actionType: ActionType.action, triggerCondition: '1 Action'),
    duration: const SpellDuration(
        type: DurationType.instantaneous, rawText: 'Instantaneous'),
    range: '60 ft.',
    components: const SpellComponents(v: true, s: true),
    descriptionMarkdown: 'A test spell description.',
    damageMath: [
      EvaluationMath(
        diceFormula: formula,
        scalingFormula: scalingFormula,
        damageType: DamageType.force,
      ),
    ],
    higherLevelsMarkdown: higherLevelsMarkdown,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureTestDiceRoomService();
  });

  group('Step 7 Characterization Tests: 16 Sites Across 9 Files', () {
    // -------------------------------------------------------------------------
    // Site 1: character_sheet_controller.dart line 952 (rollSpellDamage base)
    // -------------------------------------------------------------------------
    test('Site 1: character_sheet_controller.dart:952 (rollSpellDamage base)', () {
      final controller = CharacterSheetController(
        replicaId: _testReplica,
        character: _baseCharacter,
      );

      // 1. plain NdS
      final r1 = controller.rollSpellDamage(_makeSpell(formula: '2d6'));
      expect(r1.diceEntries.first.count, 2);
      expect(r1.diceEntries.first.sides, 6);
      expect(r1.modifier, 0);

      // 2. NdS + k (today drops +3)
      final r2 = controller.rollSpellDamage(_makeSpell(formula: '1d8+3'));
      expect(r2.diceEntries.first.count, 1);
      expect(r2.diceEntries.first.sides, 8);
      expect(r2.modifier, 0);

      // 3. two dice terms (today drops + 1d8)
      final r3 = controller.rollSpellDamage(_makeSpell(formula: '2d6 + 1d8'));
      expect(r3.diceEntries.first.count, 2);
      expect(r3.diceEntries.first.sides, 6);
      expect(r3.diceEntries.length, 1);

      // 4. text around it: starts with dice notation
      final r4 = controller.rollSpellDamage(_makeSpell(formula: '3d6 fire'));
      expect(r4.diceEntries.first.count, 3);
      expect(r4.diceEntries.first.sides, 6);

      // 5. garbage: falls back to 1d10
      final r5 = controller.rollSpellDamage(_makeSpell(formula: 'invalid_garbage'));
      expect(r5.diceEntries.first.count, 1);
      expect(r5.diceEntries.first.sides, 10);
    });

    // -------------------------------------------------------------------------
    // Site 2: character_sheet_controller.dart line 1101 (_rollUpcastSpellDamage base)
    // -------------------------------------------------------------------------
    test('Site 2: character_sheet_controller.dart:1101 (_rollUpcastSpellDamage base)', () async {
      final controller = CharacterSheetController(
        replicaId: _testReplica,
        character: _baseCharacter,
      );

      // 1. plain NdS (slot level 2 -> delta 1, base 2d6 + scale 1d6 = 3d6)
      final r1 = await controller.castSpell(
        _makeSpell(formula: '2d6', scalingFormula: '1d6'),
        castLevel: 2,
      );
      expect(r1?.diceEntries.first.count, 3);
      expect(r1?.diceEntries.first.sides, 6);

      // 2. NdS + k (today drops +3)
      final r2 = await controller.castSpell(
        _makeSpell(formula: '1d8+3', scalingFormula: '1d6'),
        castLevel: 2,
      );
      expect(r2?.diceEntries.first.sides, 8);

      // 3. two dice terms (today drops 1d8)
      final r3 = await controller.castSpell(
        _makeSpell(formula: '2d6 + 1d8', scalingFormula: '1d6'),
        castLevel: 2,
      );
      expect(r3?.diceEntries.first.sides, 6);

      // 4. text around it
      final r4 = await controller.castSpell(
        _makeSpell(formula: '3d6 fire', scalingFormula: '1d6'),
        castLevel: 2,
      );
      expect(r4?.diceEntries.first.sides, 6);

      // 5. garbage (base defaults to 1d10)
      final r5 = await controller.castSpell(
        _makeSpell(formula: 'garbage', scalingFormula: '1d6'),
        castLevel: 2,
      );
      expect(r5?.diceEntries.first.sides, 10);
    });

    // -------------------------------------------------------------------------
    // Site 3: character_sheet_controller.dart line 1128 (scalingStr)
    // -------------------------------------------------------------------------
    test('Site 3: character_sheet_controller.dart:1128 (scalingStr in damageMath)', () async {
      final controller = CharacterSheetController(
        replicaId: _testReplica,
        character: _baseCharacter,
      );

      // 1. plain NdS (delta 2 * 1d10 = 3d10 total)
      final r1 = await controller.castSpell(
        _makeSpell(formula: '1d10', scalingFormula: '1d10'),
        castLevel: 3,
      );
      expect(r1?.diceEntries.first.count, 3);

      // 2. NdS + k
      final r2 = await controller.castSpell(
        _makeSpell(formula: '1d10', scalingFormula: '1d10+2'),
        castLevel: 3,
      );
      expect(r2?.diceEntries.first.count, 3);

      // 3. two dice terms (today drops second term)
      final r3 = await controller.castSpell(
        _makeSpell(formula: '1d10', scalingFormula: '1d10 + 1d4'),
        castLevel: 3,
      );
      expect(r3?.diceEntries.first.count, 3);

      // 4. text around it
      final r4 = await controller.castSpell(
        _makeSpell(formula: '1d10', scalingFormula: 'deals 1d10 extra'),
        castLevel: 3,
      );
      expect(r4?.diceEntries.first.count, 3);

      // 5. garbage (no scaling applied, base 1d10 remains 1d10)
      final r5 = await controller.castSpell(
        _makeSpell(formula: '1d10', scalingFormula: 'garbage'),
        castLevel: 3,
      );
      expect(r5?.diceEntries.first.count, 1);
    });

    // -------------------------------------------------------------------------
    // Site 4: character_sheet_controller.dart line 1141 (higherLevelsMarkdown)
    // -------------------------------------------------------------------------
    test('Site 4: character_sheet_controller.dart:1141 (higherLevelsMarkdown)', () async {
      final controller = CharacterSheetController(
        replicaId: _testReplica,
        character: _baseCharacter,
      );

      // 1. plain NdS (delta 2 * 1d10 = 3d10 total)
      final r1 = await controller.castSpell(
        _makeSpell(formula: '1d10', higherLevelsMarkdown: '1d10'),
        castLevel: 3,
      );
      expect(r1?.diceEntries.first.count, 3);

      // 2. NdS + k
      final r2 = await controller.castSpell(
        _makeSpell(formula: '1d10', higherLevelsMarkdown: '1d10+2'),
        castLevel: 3,
      );
      expect(r2?.diceEntries.first.count, 3);

      // 3. two dice terms (today drops 1d4)
      final r3 = await controller.castSpell(
        _makeSpell(formula: '1d10', higherLevelsMarkdown: '1d10 + 1d4'),
        castLevel: 3,
      );
      expect(r3?.diceEntries.first.count, 3);

      // 4. text around it
      final r4 = await controller.castSpell(
        _makeSpell(
          formula: '1d10',
          higherLevelsMarkdown: 'When cast using higher slot, increases by 1d10.',
        ),
        castLevel: 3,
      );
      expect(r4?.diceEntries.first.count, 3);

      // 5. garbage (no scaling)
      final r5 = await controller.castSpell(
        _makeSpell(formula: '1d10', higherLevelsMarkdown: 'garbage text'),
        castLevel: 3,
      );
      expect(r5?.diceEntries.first.count, 1);
    });

    // -------------------------------------------------------------------------
    // Site 5: homebrew_persistence_service.dart line 414 (colLabels firstCol)
    // -------------------------------------------------------------------------
    test('Site 5: homebrew_persistence_service.dart:414 (colLabels firstCol)', () {
      HomebrewCompendiumEntry makeEntry(String colHeader) => HomebrewCompendiumEntry(
            id: const EntityId(slug: 'table-test', ruleset: RulesetVersion.v2024),
            name: 'Test Table',
            category: 'tables',
            descriptionMarkdown: '',
            customProperties: {
              'colLabels': [colHeader, 'Result'],
              'rows': [
                ['1', 'Outcome A'],
                ['2', 'Outcome B'],
              ],
            },
          );

      // 1. plain NdS
      final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('2d6'));
      expect(t1.diceFormula, '2d6');

      // 2. NdS + k (today not matched by ^\d*d\d+$)
      final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('1d8+3'));
      expect(t2.diceFormula, '1d2');

      // 3. two dice terms
      final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('2d6 + 1d8'));
      expect(t3.diceFormula, '1d2');

      // 4. text around it
      final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('roll 1d20'));
      expect(t4.diceFormula, '1d2');

      // 5. garbage
      final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('garbage'));
      expect(t5.diceFormula, '1d2');
    });

    // -------------------------------------------------------------------------
    // Site 6: homebrew_persistence_service.dart line 490 (markdown table row 1)
    // -------------------------------------------------------------------------
    test('Site 6: homebrew_persistence_service.dart:490 (markdown table row 1)', () {
      HomebrewCompendiumEntry makeMdEntry(String cell0) => HomebrewCompendiumEntry(
            id: const EntityId(slug: 'table-md', ruleset: RulesetVersion.v2024),
            name: 'Markdown Table',
            category: 'tables',
            descriptionMarkdown: '| $cell0 | Result |\n|---|---|\n| 1 | Outcome A |\n| 2 | Outcome B |',
            customProperties: {},
          );

      // 1. plain NdS starting with d
      final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeMdEntry('d20'));
      expect(t1.diceFormula, '1d20');

      // 2. NdS + k
      final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeMdEntry('d20+2'));
      expect(t2.diceFormula, '1d2');

      // 3. two dice terms
      final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeMdEntry('2d6 + 1d8'));
      expect(t3.diceFormula, '1d2');

      // 4. text around it
      final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeMdEntry('roll d20'));
      expect(t4.diceFormula, '1d2');

      // 5. garbage
      final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeMdEntry('xyz'));
      expect(t5.diceFormula, '1d2');
    });

    // -------------------------------------------------------------------------
    // Site 7: homebrew_persistence_service.dart line 538 (inferredDice sides)
    // -------------------------------------------------------------------------
    test('Site 7: homebrew_persistence_service.dart:538 (inferredDice sides)', () {
      HomebrewCompendiumEntry makeEntry(String colHeader) => HomebrewCompendiumEntry(
            id: const EntityId(slug: 'table-sides', ruleset: RulesetVersion.v2024),
            name: 'Sides Table',
            category: 'tables',
            descriptionMarkdown: '',
            customProperties: {
              'colLabels': [colHeader, 'Result'],
              'rows': [
                ['1', 'Outcome A'],
              ],
            },
          );

      // 1. plain NdS
      final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('1d12'));
      expect(t1.diceSides, 12);

      // 2. NdS + k
      final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('1d8+3'));
      expect(t2.diceSides, 1);

      // 3. two dice terms
      final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('2d6 + 1d8'));
      expect(t3.diceSides, 1);

      // 4. text around it
      final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('roll 1d20'));
      expect(t4.diceSides, 1);

      // 5. garbage
      final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(makeEntry('garbage'));
      expect(t5.diceSides, 1);
    });

    // -------------------------------------------------------------------------
    // Site 8: monster_codex_data.dart line 769 (action hitDamage & description)
    // -------------------------------------------------------------------------
    test('Site 8: monster_codex_data.dart:769 (action hitDamage & description)', () {
      Monster makeMonster(String hitDamage) => Monster(
            id: const EntityId(slug: 'test-monster', ruleset: RulesetVersion.v2024),
            name: 'Test Monster',
            size: 'Medium',
            monsterType: 'beast',
            alignment: 'unaligned',
            armorClass: 12,
            hitPoints: 10,
            hitDieFormula: '2d8+2',
            challengeRating: '1',
            actionsMarkdown:
                '***Bite.*** *Melee Weapon Attack:* +4 to hit, reach 5 ft., one target. *Hit:* 7 ($hitDamage) piercing damage.',
            innateSpells: const [],
            attackMath: const [],
          );

      // 1. plain NdS
      final s1 = makeMonster('2d6').toMinionStatBlock();
      expect(s1.damageDiceCount, 2);
      expect(s1.damageDiceSides, 6);
      expect(s1.damageBonus, 0);

      // 2. NdS + k
      final s2 = makeMonster('1d8+3').toMinionStatBlock();
      expect(s2.damageDiceCount, 1);
      expect(s2.damageDiceSides, 8);
      expect(s2.damageBonus, 3);

      // 3. two dice terms (today drops 1d8)
      final s3 = makeMonster('2d6 + 1d8').toMinionStatBlock();
      expect(s3.damageDiceCount, 2);
      expect(s3.damageDiceSides, 6);
      expect(s3.damageBonus, 1); // Today regex matches '+ 1' as bonus from '1d8'

      // 4. text around it
      final s4 = makeMonster('Hit: 3d6 slashing damage').toMinionStatBlock();
      expect(s4.damageDiceCount, 3);
      expect(s4.damageDiceSides, 6);

      // 5. garbage (defaults to 1d6+2)
      final s5 = makeMonster('garbage').toMinionStatBlock();
      expect(s5.damageDiceCount, 1);
      expect(s5.damageDiceSides, 6);
      expect(s5.damageBonus, 2);
    });

    // -------------------------------------------------------------------------
    // Site 9: monster_codex_data.dart line 787 (attackMath diceFormula)
    // -------------------------------------------------------------------------
    test('Site 9: monster_codex_data.dart:787 (attackMath diceFormula)', () {
      Monster makeMonsterMath(String formula) => Monster(
            id: const EntityId(slug: 'test-math-monster', ruleset: RulesetVersion.v2024),
            name: 'Math Monster',
            size: 'Medium',
            monsterType: 'beast',
            alignment: 'unaligned',
            armorClass: 12,
            hitPoints: 10,
            hitDieFormula: '2d8+2',
            challengeRating: '1',
            actionsMarkdown: '',
            innateSpells: const [],
            attackMath: [EvaluationMath(diceFormula: formula, damageType: DamageType.slashing)],
          );

      // 1. plain NdS
      final s1 = makeMonsterMath('2d6').toMinionStatBlock();
      expect(s1.damageDiceCount, 2);
      expect(s1.damageDiceSides, 6);
      expect(s1.damageBonus, 0);

      // 2. NdS + k
      final s2 = makeMonsterMath('1d8+3').toMinionStatBlock();
      expect(s2.damageDiceCount, 1);
      expect(s2.damageDiceSides, 8);
      expect(s2.damageBonus, 3);

      // 3. two dice terms (today drops 1d8)
      final s3 = makeMonsterMath('2d6 + 1d8').toMinionStatBlock();
      expect(s3.damageDiceCount, 2);
      expect(s3.damageDiceSides, 6);
      expect(s3.damageBonus, 1); // Today regex matches '+ 1' as bonus from '1d8'

      // 4. text around it
      final s4 = makeMonsterMath('3d6 fire').toMinionStatBlock();
      expect(s4.damageDiceCount, 3);
      expect(s4.damageDiceSides, 6);

      // 5. garbage (defaults to 1d6+2)
      final s5 = makeMonsterMath('garbage').toMinionStatBlock();
      expect(s5.damageDiceCount, 1);
      expect(s5.damageDiceSides, 6);
      expect(s5.damageBonus, 2);
    });

    // -------------------------------------------------------------------------
    // Site 10: homebrew_other_category.dart line 85 (colLabels isRollingTable)
    // -------------------------------------------------------------------------
    test('Site 10: homebrew_other_category.dart:85 (colLabels isRollingTable)', () {
      bool check(String col) => HomebrewOtherCategory.isRollingTable(
            category: 'other',
            name: 'Custom',
            customProperties: {
              'colLabels': [col]
            },
          );

      // 1. plain NdS
      expect(check('d20'), isTrue);

      // 2. NdS + k
      expect(check('d20+2'), isTrue);

      // 3. two dice terms
      expect(check('2d6 + 1d8'), isFalse); // Today \bd\d+\b does not match 2d6 because 2 is a word char

      // 4. text around it (word list 'Roll')
      expect(check('Roll'), isTrue);

      // 5. garbage
      expect(check('Armor Type'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Site 11: homebrew_other_category.dart line 111 (rows firstCell isRollingTable)
    // -------------------------------------------------------------------------
    test('Site 11: homebrew_other_category.dart:111 (rows firstCell isRollingTable)', () {
      bool check(String cell) => HomebrewOtherCategory.isRollingTable(
            category: 'other',
            name: 'Custom',
            customProperties: {
              'rows': [
                [cell, 'Result']
              ]
            },
          );

      // 1. plain NdS
      expect(check('d20'), isTrue);

      // 2. NdS + k (today not matched by ^\s*(?:\d{1,3}\s*[-–—]\s*\d{1,3}|\d{1,3}|d\d+)\s*$)
      expect(check('d20+2'), isFalse);

      // 3. two dice terms
      expect(check('2d6 + 1d8'), isFalse);

      // 4. text around it (numeric range 1-10)
      expect(check('1-10'), isTrue);

      // 5. garbage
      expect(check('Item Name'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Site 12: character_actions_resolver.dart line 1761 (resolve action formula)
    // -------------------------------------------------------------------------
    test('Site 12: character_actions_resolver.dart:1761 (resolve action formula)', () {
      String? resolveFormula(String desc) {
        final character = _baseCharacter.copyWith(
          progression: CharacterProgression(
            classes: [
              ClassLevelProgression(
                classRef: const EntityReference.empty(
                    refType: EntityType.classDefinition, slug: 'paladin', displayName: 'Paladin'),
                subclassRef: EntityReference(
                  refType: EntityType.subclass,
                  slug: 'custom-sub',
                  displayName: 'Custom Subclass',
                  customProperties: {
                    'featuresMarkdown': '### Smite Power\nAs an action, you $desc.',
                  },
                ),
                level: 3,
                hitDie: 'd10',
                isStartingClass: true,
              ),
            ],
          ),
        );
        final controller = CharacterSheetController(
          replicaId: _testReplica,
          character: character,
        );
        final stats = CharacterEvaluationEngine.evaluate(character);
        final res = CharacterActionsResolver.resolve(
          character: character,
          stats: stats,
          controller: controller,
        );
        final action = res.actions.where((a) => a.name == 'Smite Power').firstOrNull;
        return action?.damageFormula;
      }

      // 1. plain NdS
      expect(resolveFormula('deal 2d6 radiant damage'), '2d6');

      // 2. NdS + k
      expect(resolveFormula('deal 1d8+3 radiant damage'), '1d8+3');

      // 3. two dice terms (today drops + 1d8)
      expect(resolveFormula('deal 2d6 + 1d8 radiant damage'), '2d6 + 1'); // Today regex matches '+ 1' from 1d8

      // 4. text around it
      expect(resolveFormula('deal 3d6 extra fire damage'), '3d6');

      // 5. garbage
      expect(resolveFormula('take no damage at all'), isNull);
    });

    // -------------------------------------------------------------------------
    // Site 13: homebrew_ingestor.dart line 207 (extractHigherLevelsDice)
    // -------------------------------------------------------------------------
    test('Site 13: homebrew_ingestor.dart:207 (extractHigherLevelsDice)', () {
      // 1. plain NdS
      expect(HomebrewIngestor.extractHigherLevelsDice('1d6'), '1d6');

      // 2. NdS + k
      expect(HomebrewIngestor.extractHigherLevelsDice('1d8+2'), '1d8');

      // 3. two dice terms (today drops 1d4)
      expect(HomebrewIngestor.extractHigherLevelsDice('2d6 + 1d4'), '2d6');

      // 4. text around it
      expect(HomebrewIngestor.extractHigherLevelsDice('increases by 1d10 at 5th level'), '1d10');

      // 5. garbage
      expect(HomebrewIngestor.extractHigherLevelsDice('no dice notation'), isNull);
    });

    // -------------------------------------------------------------------------
    // Site 14: ingestion_field_descriptor.dart line 77 (validate diceFormula)
    // -------------------------------------------------------------------------
    test('Site 14: ingestion_field_descriptor.dart:77 (validate diceFormula)', () {
      const descriptor = IngestionFieldDescriptor(
        key: 'dmg',
        label: 'Damage',
        valueType: FieldValueType.diceFormula,
      );

      // 1. plain NdS
      expect(descriptor.validateSyntactic('2d6'), isNull);

      // 2. NdS + k
      expect(descriptor.validateSyntactic('1d8+3'), isNull);

      // 3. two dice terms (today rejected by single term regex)
      expect(descriptor.validateSyntactic('2d6 + 1d8'), isNotNull);

      // 4. text around it (rejected)
      expect(descriptor.validateSyntactic('2d6 fire'), isNotNull);

      // 5. garbage (rejected)
      expect(descriptor.validateSyntactic('garbage'), isNotNull);
    });

    // -------------------------------------------------------------------------
    // Site 15: monster_quick_roll_dialog.dart line 287 (quick roll damage)
    // -------------------------------------------------------------------------
    testWidgets('Site 15: monster_quick_roll_dialog.dart:287 (quick roll damage)', (tester) async {
      Future<MonsterActionResult?> rollWithDamage(String hitDamage) async {
        MonsterActionResult? captured;
        final monster = MonsterItem.simple(
          id: 'test-wolf',
          name: 'Test Wolf',
          statBlock: MinionStatBlock(
            id: 'test-wolf',
            name: 'Test Wolf',
            sizeDisplay: 'Medium',
            crDisplay: '1/4',
            typeDisplay: 'Beast',
            alignment: 'unaligned',
            ac: 13,
            maxHp: 11,
            speed: '40 ft.',
            strScore: 12,
            dexScore: 15,
            conScore: 12,
            intScore: 3,
            wisScore: 12,
            chaScore: 6,
            senses: 'passive Perception 13',
            languages: '—',
            traits: const [],
            actions: [
              CreatureAction(
                name: 'Bite',
                attackBonus: 4,
                hitDamage: hitDamage,
                description: 'Bite attack.',
              ),
            ],
            attackBonus: 4,
            damageDiceCount: 2,
            damageDiceSides: 4,
            damageBonus: 2,
            damageType: 'Piercing',
            hasPackTactics: true,
            accentColor: const Argb(0xFF388E3C),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    MonsterQuickRollDialog.show(
                      context,
                      monster: monster,
                      initialAction: monster.statBlock2024.actions.first,
                      onRollCompleted: (res, _) {
                        captured = res;
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Dismiss dialog for next run
        Navigator.of(tester.element(find.byType(MonsterQuickRollDialog))).pop();
        await tester.pumpAndSettle();

        return captured;
      }

      // 1. plain NdS
      final r1 = await rollWithDamage('2d6');
      expect(r1?.damageResult, isNotNull);
      expect(r1!.damageResult!.individualDice.length, 2);

      // 2. NdS + k
      final r2 = await rollWithDamage('1d8+3');
      expect(r2?.damageResult, isNotNull);
      expect(r2!.damageResult!.modifier, 3);

      // 3. two dice terms (today regex matches 2d6 and drops 1d8)
      final r3 = await rollWithDamage('2d6 + 1d8');
      expect(r3?.damageResult, isNotNull);
      expect(r3!.damageResult!.individualDice.length, 2);

      // 4. text around it
      final r4 = await rollWithDamage('Hit: 3d6 fire damage');
      expect(r4?.damageResult, isNotNull);
      expect(r4!.damageResult!.individualDice.length, 3);

      // 5. garbage (no regex match -> damageResult is null)
      final r5 = await rollWithDamage('garbage');
      expect(r5?.damageResult, isNull);
    });

    // -------------------------------------------------------------------------
    // Site 16: stat_block_acl_parser.dart line 489 (.split('d') attribute drain)
    // -------------------------------------------------------------------------
    test('Site 16: stat_block_acl_parser.dart:489 (.split("d") attribute drain)', () {
      List<CombatEffectRider> parseDrain(String amount) => StatBlockAclParser.extractRiders(
            "target's Strength score is reduced by $amount until a rest",
          );

      // 1. plain NdS
      final riders1 = parseDrain('1d4');
      final r1 = riders1.whereType<AttributeDrainRider>().firstOrNull;
      expect(r1, isNotNull);
      expect(r1!.diceCount, 1);
      expect(r1.diceSides, 4);

      // 2. NdS + k (drain regex matches '1d6', split('d') -> sides 6)
      final riders2 = parseDrain('1d6+2');
      final r2 = riders2.whereType<AttributeDrainRider>().firstOrNull;
      expect(r2, isNotNull);
      expect(r2!.diceCount, 1);
      expect(r2.diceSides, 6);

      // 3. two dice terms
      final riders3 = parseDrain('1d4 + 1d6');
      final r3 = riders3.whereType<AttributeDrainRider>().firstOrNull;
      expect(r3, isNotNull);
      expect(r3!.diceCount, 1);
      expect(r3.diceSides, 4);

      // 4. flat number
      final riders4 = parseDrain('2');
      final r4 = riders4.whereType<AttributeDrainRider>().firstOrNull;
      expect(r4, isNotNull);
      expect(r4!.flatBonus, 2);
      expect(r4.diceCount, 0);

      // 5. garbage
      final riders5 = parseDrain('xyz');
      final r5 = riders5.whereType<AttributeDrainRider>().firstOrNull;
      expect(r5, isNull);
    });
  });
}
