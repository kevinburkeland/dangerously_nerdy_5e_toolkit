import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/skills_saves_matrix.dart';

Character _createTestWarlock({
  Map<SkillType, SkillProficiencyLevel> skillProficiencies = const {},
}) {
  return Character(
    id: const EntityId(slug: 'warlock-test-char', ruleset: RulesetVersion.v2014),
    name: 'Eldritch Envoy',
    speciesRef: const EntityReference<DomainEntity>(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    baseScores: const AbilityScores(
      strength: 10,
      dexterity: 14,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 18, // +4 CHA modifier
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference(
            refType: EntityType.classDefinition,
            slug: 'warlock',
            displayName: 'Warlock',
          ),
          level: 11, // Level 11 -> prof bonus = +4
          hitDie: 'd8',
          isStartingClass: true,
        ),
      ],
    ),
    skillProficiencies: skillProficiencies,
    resources: const CharacterResourcePool(),
  );
}

void main() {
  group('Skill Expertise Controller & UI Tests', () {
    test('CharacterSheetController.setSkillProficiency updates stats to 2x proficiency bonus', () async {
      final character = _createTestWarlock();
      final controller = CharacterSheetController(character: character);

      // Initially no proficiency in persuasion -> modifier is just +4 (CHA)
      expect(controller.stats.proficiencyBonus, equals(4));
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(4));
      expect(controller.character.skillProficiencies[SkillType.persuasion], isNull);

      // Set to Proficient -> modifier is 4 + 4 = +8
      await controller.setSkillProficiency(SkillType.persuasion, SkillProficiencyLevel.proficient);
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.proficient));
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(8));

      // Set to Expertise -> modifier is 4 + (4 * 2) = +12
      await controller.setSkillProficiency(SkillType.persuasion, SkillProficiencyLevel.expertise);
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.expertise));
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(12));

      // Remove / set to None -> modifier is back to +4
      await controller.setSkillProficiency(SkillType.persuasion, SkillProficiencyLevel.none);
      expect(controller.character.skillProficiencies.containsKey(SkillType.persuasion), isFalse);
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(4));
    });

    test('CharacterSheetController.cycleSkillProficiency cycles through none, proficient, expertise', () async {
      final character = _createTestWarlock();
      final controller = CharacterSheetController(character: character);

      expect(controller.character.skillProficiencies[SkillType.persuasion], isNull);

      // 1st cycle: None -> Proficient
      await controller.cycleSkillProficiency(SkillType.persuasion);
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.proficient));
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(8));

      // 2nd cycle: Proficient -> Expertise
      await controller.cycleSkillProficiency(SkillType.persuasion);
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.expertise));
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(12));

      // 3rd cycle: Expertise -> None
      await controller.cycleSkillProficiency(SkillType.persuasion);
      expect(controller.character.skillProficiencies.containsKey(SkillType.persuasion), isFalse);
      expect(controller.stats.skillModifiers[SkillType.persuasion], equals(4));
    });

    testWidgets('SkillsSavesMatrix displays EXPERTISE badge and amber star for Persuasion with expertise', (tester) async {
      final character = _createTestWarlock(
        skillProficiencies: {
          SkillType.persuasion: SkillProficiencyLevel.expertise,
        },
      );
      final controller = CharacterSheetController(character: character);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkillsSavesMatrix(controller: controller),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Persuasion'));
      await tester.pumpAndSettle();

      // Verify Persuasion text is present
      expect(find.text('Persuasion'), findsOneWidget);

      // Verify EXPERTISE badge chip is rendered
      expect(find.text('EXPERTISE'), findsOneWidget);

      // Verify modifier shows +12 (CHA +4 plus doubled proficiency +8)
      expect(find.text('+12'), findsOneWidget);

      // Verify star icon is present for expertise
      expect(find.byIcon(Icons.stars), findsOneWidget);
    });

    testWidgets('Tapping the skill pip cycles proficiency level directly in the UI', (tester) async {
      final character = _createTestWarlock();
      final controller = CharacterSheetController(character: character);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => SkillsSavesMatrix(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially +4 modifier, no EXPERTISE badge
      expect(find.text('+4'), findsWidgets);
      expect(find.text('EXPERTISE'), findsNothing);

      // Tap pip for persuasion to cycle to proficient
      final pipFinder = find.byKey(const Key('skill_pip_persuasion'));
      expect(pipFinder, findsOneWidget);
      await tester.ensureVisible(pipFinder);
      await tester.pumpAndSettle();

      await tester.tap(pipFinder);
      await tester.pumpAndSettle();

      // Now proficient -> checkmark icon, +8 modifier
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.proficient));
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('EXPERTISE'), findsNothing);

      // Tap pip again to cycle to expertise
      await tester.ensureVisible(pipFinder);
      await tester.tap(pipFinder);
      await tester.pumpAndSettle();

      // Now expertise -> star icon, EXPERTISE badge, +12 modifier
      expect(controller.character.skillProficiencies[SkillType.persuasion], equals(SkillProficiencyLevel.expertise));
      expect(find.text('EXPERTISE'), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
    });

    test('CharacterEvaluationEngine applies FeatureGrant.expertise to skillModifiers', () {
      final grantFeat = Feat(
        id: const EntityId(slug: 'custom-persuasion-master', ruleset: RulesetVersion.v2014),
        name: 'Custom Persuasion Master',
        category: 'General',
        descriptionMarkdown: 'Grants expertise in persuasion.',
        grants: [
          FeatureGrant.expertise(
            'persuasion',
            grantId: 'feat_persuasion_expertise',
            label: 'Persuasion Expertise',
          ),
        ],
      );
      SrdFeatsLibrary.addCustomFeat(grantFeat);

      final character = _createTestWarlock().copyWith(
        feats: const [
          EntityReference(
            refType: EntityType.feat,
            slug: 'custom-persuasion-master',
            displayName: 'Custom Persuasion Master',
          ),
        ],
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // Base CHA 18 (+4) + double prof bonus (+8) = +12
      expect(stats.skillModifiers[SkillType.persuasion], equals(12));

      // Clean up custom feat from library
      SrdFeatsLibrary.removeCustomFeat('custom-persuasion-master');
    });
  });
}
