import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/candidate_detector.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_field.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_section.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_span.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/spell_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_class_field_extractor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_other_category.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_quick_roll_dialog.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/simulation/precomputed_attack.dart';

import '../test_doubles/service_test_configurator.dart';

final _testReplica = ReplicaId('test_runner_replica');

const _baseCharacter = Character(
  id: EntityId(slug: 'char-test', ruleset: RulesetVersion.v2024),
  name: 'Test Hero',
  speciesRef: EntityReference.empty(
    refType: EntityType.species,
    slug: 'human',
    displayName: 'Human',
  ),
  progression: CharacterProgression(
    classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
          refType: EntityType.classDefinition,
          slug: 'fighter',
          displayName: 'Fighter',
        ),
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
      cost: 1,
      actionType: ActionType.action,
      triggerCondition: '1 Action',
    ),
    duration: const SpellDuration(
      type: DurationType.instantaneous,
      rawText: 'Instantaneous',
    ),
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
    test(
      'Site 1: character_sheet_controller.dart:952 (rollSpellDamage base)',
      () {
        final controller = CharacterSheetController(
          replicaId: _testReplica,
          character: _baseCharacter,
        );

        // 1. plain NdS
        final r1 = controller.rollSpellDamage(_makeSpell(formula: '2d6'));
        expect(r1.diceEntries.first.count, 2);
        expect(r1.diceEntries.first.sides, 6);
        expect(r1.modifier, 0);

        // 2. NdS + k
        final r2 = controller.rollSpellDamage(_makeSpell(formula: '1d8+3'));
        expect(r2.diceEntries.first.count, 1);
        expect(r2.diceEntries.first.sides, 8);
        expect(r2.modifier, 3); // Cleanup slice 11: was 0, dropped a term

        // 3. two dice terms
        final r3 = controller.rollSpellDamage(_makeSpell(formula: '2d6 + 1d8'));
        expect(r3.diceEntries.first.count, 2);
        expect(r3.diceEntries.first.sides, 6);
        expect(
          r3.diceEntries.length,
          2,
        ); // Cleanup slice 11: was 1, dropped a term

        // 4. text around it: starts with dice notation
        final r4 = controller.rollSpellDamage(_makeSpell(formula: '3d6 fire'));
        expect(r4.diceEntries.first.count, 3);
        expect(r4.diceEntries.first.sides, 6);

        // 5. garbage: falls back to 1d10
        final r5 = controller.rollSpellDamage(
          _makeSpell(formula: 'invalid_garbage'),
        );
        expect(r5.diceEntries, isEmpty); // Cleanup slice 12: was 1d10, invented a d10
      },
    );

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
      expect(r5?.diceEntries.first.sides, 6); // Cleanup slice 12: was 1d10, invented a d10
    });

    // -------------------------------------------------------------------------
    // Site 3: character_sheet_controller.dart line 1128 (scalingStr)
    // -------------------------------------------------------------------------
    test(
      'Site 3: character_sheet_controller.dart:1128 (scalingStr in damageMath)',
      () async {
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
      },
    );

    // -------------------------------------------------------------------------
    // Site 4: character_sheet_controller.dart line 1141 (higherLevelsMarkdown)
    // -------------------------------------------------------------------------
    test(
      'Site 4: character_sheet_controller.dart:1141 (higherLevelsMarkdown)',
      () async {
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
            higherLevelsMarkdown:
                'When cast using higher slot, increases by 1d10.',
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
      },
    );

    // -------------------------------------------------------------------------
    // Site 5: homebrew_persistence_service.dart line 414 (colLabels firstCol)
    // -------------------------------------------------------------------------
    test(
      'Site 5: homebrew_persistence_service.dart:414 (colLabels firstCol)',
      () {
        HomebrewCompendiumEntry makeEntry(String colHeader) =>
            HomebrewCompendiumEntry(
              id: const EntityId(
                slug: 'table-test',
                ruleset: RulesetVersion.v2024,
              ),
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
        final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('2d6'),
        );
        expect(t1.diceFormula, '2d6');

        // 2. NdS + k
        final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('1d8+3'),
        );
        expect(
          t2.diceFormula,
          '1d8 + 3',
        ); // Cleanup slice 11: was 1d2, dropped a term

        // 3. two dice terms
        final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('2d6 + 1d8'),
        );
        expect(
          t3.diceFormula,
          '2d6 + 1d8',
        ); // Cleanup slice 11: was 1d2, dropped a term

        // 4. text around it
        final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('roll 1d20'),
        );
        expect(
          t4.diceFormula,
          '1d20',
        ); // Cleanup slice 11: was 1d2, dropped a term

        // 5. garbage
        final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('garbage'),
        );
        expect(t5.diceFormula, '1d2');
      },
    );

    // -------------------------------------------------------------------------
    // Site 6: homebrew_persistence_service.dart line 490 (markdown table row 1)
    // -------------------------------------------------------------------------
    test('Site 6: homebrew_persistence_service.dart:490 (markdown table row 1)', () {
      HomebrewCompendiumEntry makeMdEntry(
        String cell0,
      ) => HomebrewCompendiumEntry(
        id: const EntityId(slug: 'table-md', ruleset: RulesetVersion.v2024),
        name: 'Markdown Table',
        category: 'tables',
        descriptionMarkdown:
            '| $cell0 | Result |\n|---|---|\n| 1 | Outcome A |\n| 2 | Outcome B |',
        customProperties: {},
      );

      // 1. plain NdS starting with d
      final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(
        makeMdEntry('d20'),
      );
      expect(t1.diceFormula, '1d20');

      // 2. NdS + k
      final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(
        makeMdEntry('d20+2'),
      );
      expect(
        t2.diceFormula,
        '1d20 + 2',
      ); // Cleanup slice 11: was 1d2, dropped a term

      // 3. two dice terms
      final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(
        makeMdEntry('2d6 + 1d8'),
      );
      expect(
        t3.diceFormula,
        '2d6 + 1d8',
      ); // Cleanup slice 11: was 1d2, dropped a term

      // 4. text around it
      final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(
        makeMdEntry('roll d20'),
      );
      expect(
        t4.diceFormula,
        '1d20',
      ); // Cleanup slice 11: was 1d2, dropped a term

      // 5. garbage
      final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(
        makeMdEntry('xyz'),
      );
      expect(t5.diceFormula, '1d2');
    });

    // -------------------------------------------------------------------------
    // Site 7: homebrew_persistence_service.dart line 538 (inferredDice sides)
    // -------------------------------------------------------------------------
    test(
      'Site 7: homebrew_persistence_service.dart:538 (inferredDice sides)',
      () {
        HomebrewCompendiumEntry makeEntry(String colHeader) =>
            HomebrewCompendiumEntry(
              id: const EntityId(
                slug: 'table-sides',
                ruleset: RulesetVersion.v2024,
              ),
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
        final t1 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('1d12'),
        );
        expect(t1.diceSides, 12);

        // 2. NdS + k
        final t2 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('1d8+3'),
        );
        expect(t2.diceSides, 8); // Cleanup slice 11: was 1, dropped a term

        // 3. two dice terms
        final t3 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('2d6 + 1d8'),
        );
        expect(t3.diceSides, 8); // Cleanup slice 11: was 1, dropped a term

        // 4. text around it
        final t4 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('roll 1d20'),
        );
        expect(t4.diceSides, 20); // Cleanup slice 11: was 1, dropped a term

        // 5. garbage
        final t5 = HomebrewPersistenceService.compendiumEntryToRollableTable(
          makeEntry('garbage'),
        );
        expect(t5.diceSides, 1);
      },
    );

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

      // 3. two dice terms
      final s3 = makeMonster('2d6 + 1d8').toMinionStatBlock();
      expect(s3.damageDiceCount, 2);
      expect(s3.damageDiceSides, 6);
      expect(
        s3.damageBonus,
        0,
      ); // Cleanup slice 11: was 1, read garbage as dice

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
        id: const EntityId(
          slug: 'test-math-monster',
          ruleset: RulesetVersion.v2024,
        ),
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
        attackMath: [
          EvaluationMath(diceFormula: formula, damageType: DamageType.slashing),
        ],
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

      // 3. two dice terms
      final s3 = makeMonsterMath('2d6 + 1d8').toMinionStatBlock();
      expect(s3.damageDiceCount, 2);
      expect(s3.damageDiceSides, 6);
      expect(
        s3.damageBonus,
        0,
      ); // Cleanup slice 11: was 1, read garbage as dice

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
    test(
      'Site 10: homebrew_other_category.dart:85 (colLabels isRollingTable)',
      () {
        bool check(String col) => HomebrewOtherCategory.isRollingTable(
          category: 'other',
          name: 'Custom',
          customProperties: {
            'colLabels': [col],
          },
        );

        // 1. plain NdS
        expect(check('d20'), isTrue);

        // 2. NdS + k
        expect(check('d20+2'), isTrue);

        // 3. two dice terms
        expect(
          check('2d6 + 1d8'),
          isTrue,
        ); // Cleanup slice 11: was false, dropped a term

        // 4. text around it (word list 'Roll')
        expect(check('Roll'), isTrue);

        // 5. garbage
        expect(check('Armor Type'), isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // Site 11: homebrew_other_category.dart line 111 (rows firstCell isRollingTable)
    // -------------------------------------------------------------------------
    test('Site 11: homebrew_other_category.dart:111 (rows firstCell isRollingTable)', () {
      bool check(String cell) => HomebrewOtherCategory.isRollingTable(
        category: 'other',
        name: 'Custom',
        customProperties: {
          'rows': [
            [cell, 'Result'],
          ],
        },
      );

      // 1. plain NdS
      expect(check('d20'), isTrue);

      // 2. NdS + k
      expect(
        check('d20+2'),
        isTrue,
      ); // Cleanup slice 11: was false, dropped a term

      // 3. two dice terms
      expect(
        check('2d6 + 1d8'),
        isTrue,
      ); // Cleanup slice 11: was false, dropped a term

      // 4. text around it (numeric range 1-10)
      expect(check('1-10'), isTrue);

      // 5. garbage
      expect(check('Item Name'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Site 12: character_actions_resolver.dart line 1761 (resolve action formula)
    // -------------------------------------------------------------------------
    test(
      'Site 12: character_actions_resolver.dart:1761 (resolve action formula)',
      () {
        String? resolveFormula(String desc) {
          final character = _baseCharacter.copyWith(
            progression: CharacterProgression(
              classes: [
                ClassLevelProgression(
                  classRef: const EntityReference.empty(
                    refType: EntityType.classDefinition,
                    slug: 'paladin',
                    displayName: 'Paladin',
                  ),
                  subclassRef: EntityReference(
                    refType: EntityType.subclass,
                    slug: 'custom-sub',
                    displayName: 'Custom Subclass',
                    customProperties: {
                      'featuresMarkdown':
                          '### Smite Power\nAs an action, you $desc.',
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
          final action = res.actions
              .where((a) => a.name == 'Smite Power')
              .firstOrNull;
          return action?.damageFormula;
        }

        // 1. plain NdS
        expect(resolveFormula('deal 2d6 radiant damage'), '2d6');

        // 2. NdS + k
        expect(resolveFormula('deal 1d8+3 radiant damage'), '1d8 + 3');

        // 3. two dice terms
        expect(
          resolveFormula('deal 2d6 + 1d8 radiant damage'),
          '2d6 + 1d8',
        ); // Cleanup slice 11: was 2d6 + 1, dropped a term

        // 4. text around it
        expect(resolveFormula('deal 3d6 extra fire damage'), '3d6');

        // 5. garbage
        expect(resolveFormula('take no damage at all'), isNull);
      },
    );

    // -------------------------------------------------------------------------
    // Site 13: homebrew_ingestor.dart line 207 (extractHigherLevelsDice)
    // -------------------------------------------------------------------------
    test('Site 13: homebrew_ingestor.dart:207 (extractHigherLevelsDice)', () {
      // 1. plain NdS
      expect(HomebrewIngestor.extractHigherLevelsDice('1d6')?.format(), '1d6');

      // 2. NdS + k
      expect(
        HomebrewIngestor.extractHigherLevelsDice('1d8+2')?.format(),
        '1d8 + 2',
      ); // Cleanup slice 11: was 1d8, dropped a term

      // 3. two dice terms
      expect(
        HomebrewIngestor.extractHigherLevelsDice('2d6 + 1d4')?.format(),
        '2d6 + 1d4',
      ); // Cleanup slice 11: was 2d6, dropped a term

      // 4. text around it
      expect(
        HomebrewIngestor.extractHigherLevelsDice(
          'increases by 1d10 at 5th level',
        )?.format(),
        '1d10',
      );

      // 5. garbage
      expect(
        HomebrewIngestor.extractHigherLevelsDice('no dice notation'),
        isNull,
      );
    });

    // -------------------------------------------------------------------------
    // Site 14: ingestion_field_descriptor.dart line 77 (validate diceFormula)
    // -------------------------------------------------------------------------
    test(
      'Site 14: ingestion_field_descriptor.dart:77 (validate diceFormula)',
      () {
        const descriptor = IngestionFieldDescriptor(
          key: 'dmg',
          label: 'Damage',
          valueType: FieldValueType.diceFormula,
        );

        // 1. plain NdS
        expect(descriptor.validateSyntactic('2d6'), isNull);

        // 2. NdS + k
        expect(descriptor.validateSyntactic('1d8+3'), isNull);

        // 3. two dice terms (Cleanup slice 11: previously rejected by single-term regex, now accepted)
        expect(descriptor.validateSyntactic('2d6 + 1d8'), isNull);

        // 4. text around it (rejected)
        expect(descriptor.validateSyntactic('2d6 fire'), isNotNull);

        // 5. garbage (rejected)
        expect(descriptor.validateSyntactic('garbage'), isNotNull);
      },
    );

    // -------------------------------------------------------------------------
    // Site 15: monster_quick_roll_dialog.dart line 287 (quick roll damage)
    // -------------------------------------------------------------------------
    testWidgets(
      'Site 15: monster_quick_roll_dialog.dart:287 (quick roll damage)',
      (tester) async {
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
          Navigator.of(tester.element(find.byType(MonsterQuickRollDialog)))
              .pop();
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

        // 3. two dice terms (Cleanup slice 11: previously dropped 1d8, now rolls all 3 dice)
        final r3 = await rollWithDamage('2d6 + 1d8');
        expect(r3?.damageResult, isNotNull);
        expect(r3!.damageResult!.individualDice.length, 3);

        // 4. text around it
        final r4 = await rollWithDamage('Hit: 3d6 fire damage');
        expect(r4?.damageResult, isNotNull);
        expect(r4!.damageResult!.individualDice.length, 3);

        // 5. garbage (no regex match -> damageResult is null)
        final r5 = await rollWithDamage('garbage');
        expect(r5?.damageResult, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // Site 16: stat_block_acl_parser.dart line 489 (.split('d') attribute drain)
    // -------------------------------------------------------------------------
    test(
      'Site 16: stat_block_acl_parser.dart:489 (.split("d") attribute drain)',
      () {
        List<CombatEffectRider> parseDrain(String amount) =>
            StatBlockAclParser.extractRiders(
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
      },
    );

    // =========================================================================
    // Cleanup Slice 12: 12 Sites Under H1 Characterization (Sites 17 to 28)
    // =========================================================================
    group('Cleanup Slice 12: 12 Sites Under H1 Characterization', () {
      SourceBlock makeBlock(String text) {
        return SourceBlock(
          id: 'b1',
          rawText: text,
          normalizedText: text,
          span: const SourceSpan.empty(),
        );
      }

      MinionStatBlock makeMinion(List<CreatureAction> actions) {
        return MinionStatBlock(
          id: 'test',
          name: 'Wolf',
          sizeDisplay: 'Medium',
          crDisplay: '1',
          ac: 12,
          maxHp: 20,
          attackBonus: 4,
          damageDiceCount: 1,
          damageDiceSides: 6,
          damageBonus: 2,
          damageType: 'Piercing',
          accentArgb: const Argb(0xFF000000),
          actions: actions,
        );
      }

      // -----------------------------------------------------------------------
      // Site 17: stat_block_acl_parser.dart line 57 (_attributeDrainPattern)
      // -----------------------------------------------------------------------
      test('Site 17: stat_block_acl_parser.dart:57 (_attributeDrainPattern)', () {
        List<CombatEffectRider> parse(String text) => StatBlockAclParser.extractRiders(text);

        // 1. plain NdS
        final r1 = parse("target's Strength score is reduced by 1d4 until a rest")
            .whereType<AttributeDrainRider>()
            .firstOrNull;
        expect(r1, isNotNull);
        expect(r1!.diceCount, 1);
        expect(r1.diceSides, 4);

        // 2. NdS + k
        final r2 = parse("target's Strength score is reduced by 1d6+2 until a rest")
            .whereType<AttributeDrainRider>()
            .firstOrNull;
        expect(r2, isNotNull);
        expect(r2!.diceCount, 1);
        expect(r2.diceSides, 6);

        // 3. two dice terms
        final r3 = parse("target's Strength score is reduced by 1d4 + 1d6 until a rest")
            .whereType<AttributeDrainRider>()
            .firstOrNull;
        expect(r3, isNotNull);
        expect(r3!.diceCount, 1);
        expect(r3.diceSides, 4);

        // 4. flat number
        final r4 = parse("target's Strength score is reduced by 3 until a rest")
            .whereType<AttributeDrainRider>()
            .firstOrNull;
        expect(r4, isNotNull);
        expect(r4!.diceCount, 0);
        expect(r4.flatBonus, 3);

        // 5. garbage
        final r5 = parse("target's Strength score is reduced by xyz until a rest")
            .whereType<AttributeDrainRider>()
            .firstOrNull;
        expect(r5, isNull);
      });

      // -----------------------------------------------------------------------
      // Site 18: stat_block_acl_parser.dart line 66 (_maxHpReductionPattern)
      // -----------------------------------------------------------------------
      test('Site 18: stat_block_acl_parser.dart:66 (_maxHpReductionPattern)', () {
        List<CombatEffectRider> parse(String text) => StatBlockAclParser.extractRiders(text);

        // 1. damage amount equals damage
        final r1 = parse("target's hit point maximum is reduced by an amount equal to the necrotic damage")
            .whereType<MaxHpReductionRider>()
            .firstOrNull;
        expect(r1, isNotNull);
        expect(r1!.reductionEqualsDamage, isTrue);

        // 2. flat reduction
        final r2 = parse("target's hit point maximum is reduced by 10")
            .whereType<MaxHpReductionRider>()
            .firstOrNull;
        expect(r2, isNotNull);
        expect(r2!.reductionEqualsDamage, isFalse);
        expect(r2.flatReduction, 10);

        // 3. plain NdS (matches group 1, int.tryParse yields null)
        final r3 = parse("target's hit point maximum is reduced by 1d10")
            .whereType<MaxHpReductionRider>()
            .firstOrNull;
        expect(r3, isNotNull);
        expect(r3!.reductionEqualsDamage, isFalse);
        expect(r3.flatReduction, isNull);

        // 4. NdS + k
        final r4 = parse("target's hit point maximum is reduced by 1d8+2")
            .whereType<MaxHpReductionRider>()
            .firstOrNull;
        expect(r4, isNotNull);
        expect(r4!.reductionEqualsDamage, isFalse);
        expect(r4.flatReduction, isNull);

        // 5. garbage
        final r5 = parse("target's hit point maximum is reduced by nothing")
            .whereType<MaxHpReductionRider>()
            .firstOrNull;
        expect(r5, isNull);
      });

      // -----------------------------------------------------------------------
      // Site 19: stat_block_acl_parser.dart line 78 (_periodicDamagePattern)
      // -----------------------------------------------------------------------
      test('Site 19: stat_block_acl_parser.dart:78 (_periodicDamagePattern)', () {
        List<CombatEffectRider> parse(String text) => StatBlockAclParser.extractRiders(text);

        // 1. plain NdS
        final r1 = parse("takes 2d6 acid damage at the start of its turn")
            .whereType<PeriodicDamageRider>()
            .firstOrNull;
        expect(r1, isNotNull);
        expect(r1!.diceCount, 2);
        expect(r1.diceSides, 6);
        expect(r1.damageType, 'acid');
        expect(r1.onTurnStart, isTrue);

        // 2. NdS + k
        final r2 = parse("takes 1d8 + 3 fire damage at the end of its turn")
            .whereType<PeriodicDamageRider>()
            .firstOrNull;
        expect(r2, isNotNull);
        expect(r2!.diceCount, 1);
        expect(r2.diceSides, 8);
        expect(r2.flatBonus, 3);
        expect(r2.damageType, 'fire');
        expect(r2.onTurnStart, isFalse);

        // 3. with parenthesized average (dropped by old regex: expected paren around both average and dice)
        final r3 = parse("takes (7) 2d6 cold damage at the start of each of its turns")
            .whereType<PeriodicDamageRider>()
            .firstOrNull;
        expect(r3, isNotNull); // Cleanup slice 12: was null, dropped a term
        expect(r3!.diceCount, 2);
        expect(r3.diceSides, 6);
        expect(r3.damageType, 'cold');

        // 4. text around it: end of turn
        final r4 = parse("takes 1d4 poison damage at the end of each of its turns.")
            .whereType<PeriodicDamageRider>()
            .firstOrNull;
        expect(r4, isNotNull);
        expect(r4!.diceCount, 1);
        expect(r4.diceSides, 4);
        expect(r4.damageType, 'poison');
        expect(r4.onTurnStart, isFalse);

        // 5. garbage
        final r5 = parse("takes some damage next turn")
            .whereType<PeriodicDamageRider>()
            .firstOrNull;
        expect(r5, isNull);
      });

      // -----------------------------------------------------------------------
      // Site 20: stat_block_acl_parser.dart line 95 (_damageDicePattern)
      // -----------------------------------------------------------------------
      test('Site 20: stat_block_acl_parser.dart:95 (_damageDicePattern)', () {
        PrecomputedAttack? parseAttack(String desc) {
          final parsed = StatBlockAclParser.parseStatBlockBoundary(
            makeMinion([
              CreatureAction(name: 'Bite', description: desc),
            ]),
          );
          return parsed.attacks['bite'];
        }

        // 1. plain NdS
        final a1 = parseAttack('Hit: 2d6 slashing damage');
        expect(a1, isNotNull);
        expect(a1!.damageGroups.length, 1);
        expect(a1.damageGroups.first.count, 2);
        expect(a1.damageGroups.first.faces, 6);

        // 2. NdS + k
        final a2 = parseAttack('Hit: 1d8 + 3 piercing damage');
        expect(a2, isNotNull);
        expect(a2!.damageGroups.first.count, 1);
        expect(a2.damageGroups.first.faces, 8);
        expect(a2.flatBonus, 3);

        // 3. two dice terms (old code reads '+ 1' as flatBonus, dropping 'd8')
        final a3 = parseAttack('Hit: 2d6 + 1d8 damage');
        expect(a3, isNotNull);
        expect(a3!.damageGroups.length, 2); // Cleanup slice 12: was 1, dropped a term
        expect(a3.flatBonus, 0); // Cleanup slice 12: was 1, read garbage as dice

        // 4. full attack text
        final a4 = parseAttack('Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 3d10 force damage.');
        expect(a4, isNotNull);
        expect(a4!.damageGroups.first.count, 3);
        expect(a4.damageGroups.first.faces, 10);

        // 5. garbage
        final a5 = parseAttack('Hit: no dice here');
        expect(a5, isNotNull);
        expect(a5!.damageGroups, isEmpty);
      });

      // -----------------------------------------------------------------------
      // Site 21: dpr_models.dart line 1407 (_primaryDicePattern)
      // -----------------------------------------------------------------------
      test('Site 21: dpr_models.dart:1407 (_primaryDicePattern)', () {
        DprAttackAction? parseAction(String? hitDamage, String desc) {
          final block = makeMinion([
            CreatureAction(name: 'Claw', hitDamage: hitDamage, description: desc),
          ]);
          return block.extractDprAttacks().firstOrNull;
        }

        // 1. plain NdS
        final a1 = parseAction('2d6', 'Hit: 2d6 slashing damage');
        expect(a1, isNotNull);
        expect(a1!.diceCount, 2);
        expect(a1.diceSides, 6);
        expect(a1.damageBonus, 0);

        // 2. NdS + k
        final a2 = parseAction('1d8 + 3', 'Hit: 1d8+3 piercing damage');
        expect(a2, isNotNull);
        expect(a2!.diceCount, 1);
        expect(a2.diceSides, 8);
        expect(a2.damageBonus, 3);

        // 3. two dice terms (primary matches first)
        final a3 = parseAction('2d6 + 1d8', 'Hit: 2d6+1d8 damage');
        expect(a3, isNotNull);
        expect(a3!.diceCount, 2);
        expect(a3.diceSides, 6);

        // 4. from description when hitDamage is null
        final a4 = parseAction(null, 'Melee Weapon Attack: +5 to hit. Hit: 3d10 + 4 force damage');
        expect(a4, isNotNull);
        expect(a4!.diceCount, 3);
        expect(a4.diceSides, 10);
        expect(a4.damageBonus, 4);

        // 5. garbage
        final a5 = parseAction('garbage', 'Attack does not hit');
        expect(a5, isNotNull);
        expect(a5!.diceCount, 0);
        expect(a5.diceSides, 0);
      });

      // -----------------------------------------------------------------------
      // Site 22: dpr_models.dart line 1417 (_secondaryDicePattern)
      // -----------------------------------------------------------------------
      test('Site 22: dpr_models.dart:1417 (_secondaryDicePattern)', () {
        DprAttackAction? parseAction(String desc) {
          final block = makeMinion([
            CreatureAction(name: 'Bite', description: desc),
          ]);
          return block.extractDprAttacks().firstOrNull;
        }

        // 1. plus NdS type damage
        final a1 = parseAction('Melee Weapon Attack: +5 to hit. Hit: 1d8 piercing damage plus 2d6 fire damage');
        expect(a1, isNotNull);
        expect(a1!.secondaryDiceCount, 2);
        expect(a1.secondaryDiceSides, 6);
        expect(a1.secondaryDamageType, 'fire');

        // 2. and the target takes NdS type damage
        final a2 = parseAction('Melee Weapon Attack: +5 to hit. Hit: 1d8 piercing damage and the target takes 1d6 radiant damage');
        expect(a2, isNotNull);
        expect(a2!.secondaryDiceCount, 1);
        expect(a2.secondaryDiceSides, 6);
        expect(a2.secondaryDamageType, 'radiant');

        // 3. plus (average) NdS type damage
        final a3 = parseAction('Melee Weapon Attack: +5 to hit. Hit: 1d8 piercing damage plus 7 (2d6) cold damage');
        expect(a3, isNotNull);
        expect(a3!.secondaryDiceCount, 2);
        expect(a3.secondaryDiceSides, 6);
        expect(a3.secondaryDamageType, 'cold');

        // 4. extra NdS type damage
        final a4 = parseAction('Melee Weapon Attack: +5 to hit. Hit: 1d8 damage extra 1d4 poison damage');
        expect(a4, isNotNull);
        expect(a4!.secondaryDiceCount, 1);
        expect(a4.secondaryDiceSides, 4);
        expect(a4.secondaryDamageType, 'poison');

        // 5. garbage
        final a5 = parseAction('Melee Weapon Attack: +5 to hit. Hit: 1d8 damage plus no extra damage');
        expect(a5, isNotNull);
        expect(a5!.secondaryDiceCount, 0);
      });

      // -----------------------------------------------------------------------
      // Site 23: spell_dto.dart line 180 (SpellDto.fromJson description extraction)
      // -----------------------------------------------------------------------
      test('Site 23: spell_dto.dart:180 (SpellDto.fromJson)', () {
        Spell parseSpell(String desc) {
          final dto = SpellDto.fromJson({
            'name': 'Test Spell',
            'description': desc,
          });
          return dto.toDomain();
        }

        // 1. plain NdS with damage type
        final s1 = parseSpell('The target takes 3d6 fire damage.');
        expect(s1.damageMath.first.diceFormula, '3d6');
        expect(s1.damageMath.first.damageType, DamageType.fire);

        // 2. NdS + k
        final s2 = parseSpell('Deals 1d8 radiant damage on impact.');
        expect(s2.damageMath.first.diceFormula, '1d8');
        expect(s2.damageMath.first.damageType, DamageType.radiant);

        // 3. {@damage ...} tag
        final s3 = parseSpell('Inflicts {@damage 4d6|cold} to all creatures.');
        expect(s3.damageMath.first.diceFormula, '4d6');
        expect(s3.damageMath.first.damageType, DamageType.cold);

        // 4. two dice terms
        final s4 = parseSpell('Deals 2d6 cold damage and 1d8 radiant damage.');
        expect(s4.damageMath.length, 2);

        // 5. garbage
        final s5 = parseSpell('This spell heals without damage.');
        expect(s5.damageMath, isEmpty);
      });

      // -----------------------------------------------------------------------
      // Site 24: homebrew_ingestor.dart line 150 (correctDamageTypesFromDescription)
      // -----------------------------------------------------------------------
      test('Site 24: homebrew_ingestor.dart:150 (correctDamageTypesFromDescription)', () {
        // 1. plain NdS correction
        final res1 = HomebrewIngestor.correctDamageTypesFromDescription(
          [const EvaluationMath(diceFormula: '1d10', damageType: DamageType.slashing)],
          'deals 1d10 piercing damage',
        );
        expect(res1.first.damageType, DamageType.piercing);

        // 2. overwrite mislabeled type
        final res2 = HomebrewIngestor.correctDamageTypesFromDescription(
          [const EvaluationMath(diceFormula: '2d6', damageType: DamageType.acid)],
          'deals 2d6 fire damage',
        );
        expect(res2.first.damageType, DamageType.fire);

        // 3. two dice terms
        final res3 = HomebrewIngestor.correctDamageTypesFromDescription(
          [
            const EvaluationMath(diceFormula: '1d8', damageType: DamageType.slashing),
            const EvaluationMath(diceFormula: '1d6', damageType: DamageType.acid),
          ],
          '1d8 slashing damage and 1d6 cold damage',
        );
        expect(res3[1].damageType, DamageType.cold);

        // 4. text around it
        final res4 = HomebrewIngestor.correctDamageTypesFromDescription(
          [const EvaluationMath(diceFormula: '3d6', damageType: DamageType.acid)],
          'On a hit, the weapon deals 3d6 lightning damage.',
        );
        expect(res4.first.damageType, DamageType.lightning);

        // 5. garbage
        final res5 = HomebrewIngestor.correctDamageTypesFromDescription(
          [const EvaluationMath(diceFormula: '1d4', damageType: DamageType.acid)],
          'unrelated text without damage',
        );
        expect(res5.first.damageType, DamageType.acid);
      });

      // -----------------------------------------------------------------------
      // Site 25: candidate_detector.dart line 123 (_classHitDiePattern in identifyCluster)
      // -----------------------------------------------------------------------
      test('Site 25: candidate_detector.dart:123 (CandidateDetector)', () {
        bool hasHitDieEvidence(String text) {
          final block = makeBlock(text);
          final ident = const CandidateDetector().identifyCluster([block]);
          return ident.evidence.any((e) => e.category == 'Hit Die');
        }

        // 1. d8
        expect(hasHitDieEvidence('Hit Die: d8'), isTrue);

        // 2. 1d8
        expect(hasHitDieEvidence('Hit Dice: 1d8 per level'), isTrue);

        // 3. Hit Die: d10
        expect(hasHitDieEvidence('Hit Die: d10'), isTrue);

        // 4. Hit Dice: 1d12 per barbarian level
        expect(hasHitDieEvidence('Hit Dice: 1d12 per barbarian level'), isTrue);

        // 5. garbage
        expect(hasHitDieEvidence('No hit dice mentioned here'), isFalse);
      });

      // -----------------------------------------------------------------------
      // Site 26: dnd5e_ingestion_capability.dart line 106 (_classHitDiePattern in classifySections)
      // -----------------------------------------------------------------------
      test('Site 26: dnd5e_ingestion_capability.dart:106 (classifySections)', () {
        bool isClassSection(String text) {
          final block = makeBlock(text);
          final sec = IngestionSection(
            id: 'sec1',
            headingText: 'Class Section',
            span: block.span,
            blocks: [block],
            rawSource: text,
          );
          final classified = const Dnd5eIngestionCapability().classifySections([sec]);
          return classified.first.classification == 'class';
        }

        // 1. d8
        expect(isClassSection('Hit Die: d8'), isTrue);

        // 2. 1d8
        expect(isClassSection('Hit Dice: 1d8 per level'), isTrue);

        // 3. Hit Die: d10
        expect(isClassSection('Hit Die: d10'), isTrue);

        // 4. Hit Dice: 1d12 per level
        expect(isClassSection('Hit Dice: 1d12 per level'), isTrue);

        // 5. garbage
        expect(isClassSection('Regular story text without class clues'), isFalse);
      });

      // -----------------------------------------------------------------------
      // Site 27: dnd5e_ingestion_capability.dart line 1042 (_checkRequiredHitDie in validateCandidate)
      // -----------------------------------------------------------------------
      test('Site 27: dnd5e_ingestion_capability.dart:1042 (validateCandidate)', () {
        List<String> validateHitDie(String val) {
          const span = SourceSpan.empty();
          const ident = CandidateIdentification(
            identifiedTypeKey: 'class',
            confidence: 0.9,
            evidence: [],
          );
          final candidate = IngestionCandidate(
            id: 'c1',
            targetTypeKey: 'class',
            rawSource: 'class Warrior',
            normalizedSource: 'class warrior',
            blocks: const [],
            identification: ident,
            span: span,
            fields: {
              'hitDie': IngestionField<String>.extracted(
                key: 'hitDie',
                label: 'Hit Die',
                value: val,
                rawText: val,
                span: span,
                isRequired: true,
              ),
              'primaryAbility': IngestionField<List<String>>.extracted(
                key: 'primaryAbility',
                label: 'Primary Ability',
                value: const ['Strength'],
                rawText: 'Strength',
                span: span,
                isRequired: true,
              ),
              'savingThrows': IngestionField<List<String>>.extracted(
                key: 'savingThrows',
                label: 'Saving Throws',
                value: const ['Strength', 'Constitution'],
                rawText: 'Strength, Constitution',
                span: span,
                isRequired: true,
              ),
            },
          );
          final result = const Dnd5eIngestionCapability().validateCandidate(candidate);
          return result.blockingErrors;
        }

        // 1. d8 -> valid
        expect(validateHitDie('d8').where((e) => e.contains('Hit Die')), isEmpty);

        // 2. 1d8 -> valid
        expect(validateHitDie('1d8').where((e) => e.contains('Hit Die')), isEmpty);

        // 3. d10 -> valid
        expect(validateHitDie('d10').where((e) => e.contains('Hit Die')), isEmpty);

        // 4. d12 -> valid
        expect(validateHitDie('d12').where((e) => e.contains('Hit Die')), isEmpty);

        // 5. garbage / invalid die
        expect(validateHitDie('d20').any((e) => e.contains('Hit Die')), isTrue);
      });

      // -----------------------------------------------------------------------
      // Site 28: dnd5e_class_field_extractor.dart line 15 (Dnd5eClassFieldExtractor)
      // -----------------------------------------------------------------------
      test('Site 28: dnd5e_class_field_extractor.dart:15 (Dnd5eClassFieldExtractor)', () {
        String? extract(String text) {
          final block = makeBlock(text);
          final desc = const Dnd5eIngestionCapability().getTargetDescriptor('class')!;
          final result = const Dnd5eClassFieldExtractor().extract(
            blocks: [
              makeBlock('Fighter'),
              block,
            ],
            descriptor: desc,
          );
          return result.fields['hitDie']?.value as String?;
        }

        // 1. d8
        expect(extract('Hit Die: d8'), 'd8');

        // 2. 1d8
        expect(extract('Hit Die: 1d8'), 'd8');

        // 3. Hit Die: d10
        expect(extract('Hit Die: d10'), 'd10');

        // 4. Hit Die: 1d12
        expect(extract('Hit Die: 1d12'), 'd12');

        // 5. garbage
        expect(extract('Just some regular text'), isNull);
      });
    });
  });
}
