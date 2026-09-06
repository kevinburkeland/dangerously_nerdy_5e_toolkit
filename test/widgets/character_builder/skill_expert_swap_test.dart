import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/add_feat_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Character createTestRogueLvl3() {
    return const Character(
      id: EntityId(slug: 'rogue-hero', ruleset: RulesetVersion.v2014),
      name: 'Rogue Hero',
      speciesRef: EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      progression: CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'rogue',
              displayName: 'Rogue',
            ),
            level: 3,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(
        strength: 10,
        dexterity: 16,
        constitution: 14,
        intelligence: 12,
        wisdom: 10,
        charisma: 12,
      ),
      skillProficiencies: {
        SkillType.stealth: SkillProficiencyLevel.proficient,
        SkillType.sleightOfHand: SkillProficiencyLevel.proficient,
      },
      resources: CharacterResourcePool(),
    );
  }

  group('Skill Expert Feat Swapping Tests', () {
    testWidgets('AddFeatDialog: swapping skill from default updates expertise to swapped skill', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final char = createTestRogueLvl3();
      final controller = CharacterSheetController(character: char);

      const skillExpert = Feat(
        id: EntityId(slug: 'skill-expert', ruleset: RulesetVersion.v2014),
        name: 'Skill Expert',
        category: 'General',
        descriptionMarkdown: 'Increase ability, gain skill proficiency and expertise.',
        customProperties: {
          'hasAbilityScoreIncrease': true,
          'hasSkillChoice': true,
          'hasExpertiseChoice': true,
        },
      );
      SrdFeatsLibrary.addCustomFeat(skillExpert);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddFeatDialog(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for Skill Expert
      await tester.enterText(find.byType(TextField).first, 'Skill Expert');
      await tester.pumpAndSettle();

      // Tap Skill Expert in the feat list
      final featTile = find.widgetWithText(ListTile, 'Skill Expert');
      expect(featTile, findsOneWidget);
      await tester.tap(featTile);
      await tester.pumpAndSettle();

      // Find skill dropdown and swap to Deception
      final skillDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<SkillType> && !w.key.toString().contains('add_feat_expertise_'),
      ).first;

      await tester.ensureVisible(skillDropdown);
      await tester.pumpAndSettle();
      await tester.tap(skillDropdown);
      await tester.pumpAndSettle();

      final deceptionOption = find.text('Deception (CHA)').last;
      await tester.tap(deceptionOption);
      await tester.pumpAndSettle();

      // Expertise dropdown should show Deception
      expect(find.textContaining('Deception'), findsWidgets);

      // Submit Add Feat
      final addButton = find.widgetWithText(ElevatedButton, 'Add Feat');
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Deception receives expertise!
      expect(
        controller.character.skillProficiencies[SkillType.deception],
        equals(SkillProficiencyLevel.expertise),
      );
      // Athletics / Acrobatics do not
      expect(controller.character.skillProficiencies[SkillType.athletics], isNull);
      expect(controller.character.skillProficiencies[SkillType.acrobatics], isNull);
    });

    testWidgets('LevelUpWizardDialog: swapping skill updates expertise to swapped skill and not athletics', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final char = createTestRogueLvl3();
      Character? updatedChar;

      const skillExpert = Feat(
        id: EntityId(slug: 'skill-expert', ruleset: RulesetVersion.v2014),
        name: 'Skill Expert',
        category: 'General',
        descriptionMarkdown: 'Increase ability, gain skill proficiency and expertise.',
        customProperties: {
          'hasAbilityScoreIncrease': true,
          'hasSkillChoice': true,
          'hasExpertiseChoice': true,
        },
      );
      SrdFeatsLibrary.addCustomFeat(skillExpert);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => LevelUpWizardDialog(
                      character: char,
                      onLevelUpApplied: (c) {
                        updatedChar = c;
                      },
                    ),
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Step 1: Class -> Next Step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: HP -> Next Step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class Features -> Next Step (Rogue 4 is ASI/Feat)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4: Feat / ASI Choice -> Switch to Choose Feat
      final chooseFeatSegment = find.text('Choose Feat');
      expect(chooseFeatSegment, findsOneWidget);
      await tester.tap(chooseFeatSegment);
      await tester.pumpAndSettle();

      // Select Skill Expert
      final featPicker = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(featPicker);
      await tester.pumpAndSettle();

      final skillExpertItem = find.text('Skill Expert').last;
      await tester.tap(skillExpertItem);
      await tester.pumpAndSettle();

      // Find Skill dropdown and swap to Insight
      final skillDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<SkillType> && w.key.toString().contains('levelup_feat_skill_'),
      );
      expect(skillDropdown, findsOneWidget);

      await tester.tap(skillDropdown);
      await tester.pumpAndSettle();

      final insightItem = find.text('Insight').last;
      await tester.tap(insightItem);
      await tester.pumpAndSettle();

      // Expertise dropdown should show Insight
      expect(find.text('Insight (From this Feat)'), findsOneWidget);

      // Advance through remaining steps
      while (find.text('Next Step').evaluate().isNotEmpty) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Finalize
      final finishBtn = find.text('CONFIRM LEVEL UP');
      expect(finishBtn, findsOneWidget);
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      expect(updatedChar, isNotNull);
      // Insight receives expertise!
      expect(
        updatedChar!.skillProficiencies[SkillType.insight],
        equals(SkillProficiencyLevel.expertise),
      );
      expect(updatedChar!.skillProficiencies[SkillType.athletics], isNull);
      expect(updatedChar!.skillProficiencies[SkillType.acrobatics], isNull);
    });
  });
}
