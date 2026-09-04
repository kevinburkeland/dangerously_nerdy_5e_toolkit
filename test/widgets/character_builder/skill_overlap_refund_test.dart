import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_builder_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CharacterBuilderController Skill Overlap & Refund State Tests', () {
    late CharacterBuilderController controller;

    setUp(() {
      controller = CharacterBuilderController();
    });

    test('Initial state has zero refunds and empty replacement skills', () {
      expect(controller.refundedSkillChoices, equals(0));
      expect(controller.bonusReplacementSkills, isEmpty);
      expect(controller.collidingSkills, isEmpty);
    });

    test('Selecting class skills and overlapping background grants refunds', () {
      // Fighter selects Athletics and History
      controller.setSelectedSkills({SkillType.athletics, SkillType.history});
      expect(controller.refundedSkillChoices, equals(0));

      // Soldier grants Athletics and Intimidation -> Overlap: Athletics
      controller.setBackgroundSlug('soldier');

      expect(controller.grantedBackgroundSkills, contains(SkillType.athletics));
      expect(controller.grantedBackgroundSkills, contains(SkillType.intimidation));
      expect(controller.collidingSkills, equals({SkillType.athletics}));
      expect(controller.refundedSkillChoices, equals(1));
    });

    test('Resolving refunded skill adds to bonusReplacementSkills and decrements counter', () {
      controller.setSelectedSkills({SkillType.athletics, SkillType.history});
      controller.setBackgroundSlug('soldier');
      expect(controller.refundedSkillChoices, equals(1));

      // Pick Stealth as replacement
      controller.resolveRefundedSkill(SkillType.stealth);

      expect(controller.bonusReplacementSkills, contains(SkillType.stealth));
      expect(controller.refundedSkillChoices, equals(0));
    });

    test('Unresolving refunded skill removes from replacements and restores refund count', () {
      controller.setSelectedSkills({SkillType.athletics, SkillType.history});
      controller.setBackgroundSlug('soldier');
      controller.resolveRefundedSkill(SkillType.stealth);
      expect(controller.refundedSkillChoices, equals(0));

      controller.unresolveRefundedSkill(SkillType.stealth);
      expect(controller.bonusReplacementSkills.contains(SkillType.stealth), isFalse);
      expect(controller.refundedSkillChoices, equals(1));
    });

    test('Multiple overlaps from background grant corresponding refund count', () {
      // Rogue/Fighter selects Athletics AND Intimidation
      controller.setSelectedSkills({SkillType.athletics, SkillType.intimidation});
      controller.setBackgroundSlug('soldier'); // grants Athletics & Intimidation

      expect(controller.collidingSkills, equals({SkillType.athletics, SkillType.intimidation}));
      expect(controller.refundedSkillChoices, equals(2));

      controller.resolveRefundedSkill(SkillType.survival);
      expect(controller.refundedSkillChoices, equals(1));

      controller.resolveRefundedSkill(SkillType.acrobatics);
      expect(controller.refundedSkillChoices, equals(0));
      expect(controller.bonusReplacementSkills, equals({SkillType.survival, SkillType.acrobatics}));
    });

    test('Species granted skills collision generates refunds', () {
      // Character selects Perception via class
      controller.setSelectedSkills({SkillType.perception, SkillType.athletics});
      expect(controller.refundedSkillChoices, equals(0));

      // Elf grants Keen Senses (Perception)
      controller.setSpeciesSlug('elf');
      expect(controller.grantedSpeciesSkills, contains(SkillType.perception));
      expect(controller.collidingSkills, contains(SkillType.perception));
      expect(controller.refundedSkillChoices, equals(1));

      controller.resolveRefundedSkill(SkillType.insight);
      expect(controller.refundedSkillChoices, equals(0));
      expect(controller.bonusReplacementSkills, contains(SkillType.insight));
    });

    test('Switching to non-colliding background clears unneeded refunds', () {
      controller.setSelectedSkills({SkillType.athletics, SkillType.history});
      controller.setBackgroundSlug('soldier'); // collides on Athletics
      expect(controller.refundedSkillChoices, equals(1));

      // Switch to Acolyte (Insight, Religion) -> No collision with Athletics/History
      controller.setBackgroundSlug('acolyte');
      expect(controller.collidingSkills, isEmpty);
      expect(controller.refundedSkillChoices, equals(0));
    });

    test('availableReplacementSkills excludes class, background, species, and selected replacements', () {
      controller.setSelectedSkills({SkillType.athletics});
      controller.setBackgroundSlug('soldier'); // grants athletics, intimidation
      controller.setSpeciesSlug('elf'); // grants perception
      controller.resolveRefundedSkill(SkillType.stealth);

      final available = controller.availableReplacementSkills;
      expect(available.contains(SkillType.athletics), isFalse);
      expect(available.contains(SkillType.intimidation), isFalse);
      expect(available.contains(SkillType.perception), isFalse);
      expect(available.contains(SkillType.stealth), isFalse);
      expect(available.contains(SkillType.arcana), isTrue);
    });
  });

  group('CharacterBuilderScreen Skill Overlap & Wizard Progression Widget Tests', () {
    testWidgets('Soldier background colliding with Fighter Athletics locks Next Step until replacement is chosen', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human -> Next Step
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();

      // Unselect Acrobatics first so Fighter has an open skill slot (2/2 quota)
      final acrobaticsChipFinder = find.widgetWithText(FilterChip, 'Acrobatics').first;
      await tester.tap(acrobaticsChipFinder);
      await tester.pumpAndSettle();

      // Select Athletics chip for Fighter
      final athleticsChipFinder = find.widgetWithText(FilterChip, 'Athletics').first;
      await tester.tap(athleticsChipFinder);
      await tester.pumpAndSettle();

      // Advance to next step (Fighting style if present)
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      if (find.text('Defense').evaluate().isNotEmpty) {
        await tester.tap(find.text('Defense'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
        await tester.pumpAndSettle();
      }

      // We are now on Step 4: Background!
      expect(find.textContaining('Choose Background'), findsOneWidget);

      // Tap Soldier background (grants Athletics & Intimidation)
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();

      // VERIFY: Collision alert is displayed!
      expect(find.textContaining('Skill Proficiency Overlap Detected!'), findsOneWidget);
      expect(find.textContaining('Please select 1 replacement skill(s)'), findsOneWidget);

      // VERIFY: Next Step button is DISABLED!
      final nextStepFinder = find.widgetWithText(ElevatedButton, 'Next Step');
      ElevatedButton nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNull);

      // Pick an eligible replacement skill from the action chips (e.g. Stealth)
      final stealthChipFinder = find.widgetWithText(ActionChip, 'Stealth');
      expect(stealthChipFinder, findsOneWidget);
      await tester.tap(stealthChipFinder);
      await tester.pumpAndSettle();

      // VERIFY: Alert updates to resolved state
      expect(find.textContaining('All skill overlap replacements resolved!'), findsOneWidget);

      // VERIFY: Next Step button is now ENABLED!
      nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNotNull);

      // Tap Next Step -> successfully advances past Background to Ability Score Allocation!
      await tester.tap(nextStepFinder);
      await tester.pumpAndSettle();

      expect(find.text('Step 5: Ability Score Allocation'), findsOneWidget);
    });
  });
}
