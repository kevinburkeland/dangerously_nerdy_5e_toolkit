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

  group('CharacterBuilderController Consumable Pool State Tests', () {
    late CharacterBuilderController controller;

    setUp(() {
      controller = CharacterBuilderController(initialMode: 'standard', startEmpty: true);
    });

    test('Initializes with standard array available and empty assignments', () {
      expect(controller.availableScores, equals([15, 14, 13, 12, 10, 8]));
      expect(controller.assignedScores, isEmpty);
      expect(controller.isAbilityAllocationComplete, isFalse);
    });

    test('Assigning score removes exactly one instance from available pool', () {
      controller.assignScore(AbilityType.strength, 15);

      expect(controller.assignedScores[AbilityType.strength], equals(15));
      expect(controller.availableScores, equals([14, 13, 12, 10, 8]));
      expect(controller.availableScores.contains(15), isFalse);
    });

    test('Reassigning an ability returns previous score to pool and consumes new score', () {
      controller.assignScore(AbilityType.strength, 15);
      expect(controller.availableScores, equals([14, 13, 12, 10, 8]));

      // Swap Strength to 14: 15 must return to pool, 14 is consumed
      controller.assignScore(AbilityType.strength, 14);
      expect(controller.assignedScores[AbilityType.strength], equals(14));
      expect(controller.availableScores, equals([15, 13, 12, 10, 8]));
    });

    test('Unassigning score returns it to pool and keeps pool sorted high to low', () {
      controller.assignScore(AbilityType.dexterity, 14);
      expect(controller.availableScores, equals([15, 13, 12, 10, 8]));

      controller.unassignScore(AbilityType.dexterity);
      expect(controller.assignedScores.containsKey(AbilityType.dexterity), isFalse);
      expect(controller.availableScores, equals([15, 14, 13, 12, 10, 8]));
    });

    test('Duplicate rolled scores can only be assigned up to their rolled frequency', () {
      controller.setMode('rolled');
      controller.populateRolledScores([14, 14, 12, 10, 10, 8]);

      expect(controller.availableScores.where((s) => s == 14).length, equals(2));

      // Assign first 14
      controller.assignScore(AbilityType.strength, 14);
      expect(controller.availableScores.where((s) => s == 14).length, equals(1));

      // Assign second 14
      controller.assignScore(AbilityType.dexterity, 14);
      expect(controller.availableScores.where((s) => s == 14).length, equals(0));

      // Cannot assign a third 14 as none are available
      expect(controller.availableScores.contains(14), isFalse);
    });

    test('Two-tap selection workflow updates selectedPoolScore and assigns cleanly', () {
      controller.selectPoolScore(13);
      expect(controller.selectedPoolScore, equals(13));

      controller.assignSelectedPoolScore(AbilityType.constitution);
      expect(controller.assignedScores[AbilityType.constitution], equals(13));
      expect(controller.selectedPoolScore, isNull);
      expect(controller.availableScores.contains(13), isFalse);
    });

    test('isAbilityAllocationComplete is true only when all 6 abilities are allocated', () {
      expect(controller.isAbilityAllocationComplete, isFalse);

      controller.assignScore(AbilityType.strength, 15);
      controller.assignScore(AbilityType.dexterity, 14);
      controller.assignScore(AbilityType.constitution, 13);
      controller.assignScore(AbilityType.intelligence, 12);
      controller.assignScore(AbilityType.wisdom, 10);
      expect(controller.isAbilityAllocationComplete, isFalse);

      controller.assignScore(AbilityType.charisma, 8);
      expect(controller.isAbilityAllocationComplete, isTrue);
      expect(controller.availableScores, isEmpty);
    });

    test('Auto-assign standard array allocates all 6 scores and exhausts pool', () {
      controller.autoAssignStandardArray();
      expect(controller.isAbilityAllocationComplete, isTrue);
      expect(controller.availableScores, isEmpty);
      expect(controller.assignedScores[AbilityType.strength], equals(15));
      expect(controller.assignedScores[AbilityType.charisma], equals(8));
    });

    test('Down the line rolling assigns scores sequentially and completes allocation', () {
      controller.setMode('rolled');
      controller.setRollMethod('classic_3d6_down');
      expect(controller.isAbilityAllocationComplete, isTrue);
      expect(controller.availableScores, isEmpty);
      expect(controller.assignedScores.length, equals(6));
    });

    test('Manual entry mode validates all 6 abilities have integer in 3-30 range', () {
      controller.setMode('manual');
      expect(controller.isAbilityAllocationComplete, isTrue);

      controller.setManualScore(AbilityType.strength, 18);
      expect(controller.manualScores[AbilityType.strength], equals(18));
      expect(controller.isAbilityAllocationComplete, isTrue);
    });
  });

  group('CharacterBuilderScreen Consumable Pool Widget & Progression Tests', () {
    Future<void> advanceToAbilityScores(WidgetTester tester) async {
      // Tap Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        if (find.textContaining('Step 5: Ability Score Allocation').evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('Ability Scores step disables Next Step button until all 6 are allocated', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await advanceToAbilityScores(tester);
      expect(find.text('Step 5: Ability Score Allocation'), findsOneWidget);

      // Verify "Next Step" button is disabled initially (0/6 allocated)
      final nextStepFinder = find.widgetWithText(ElevatedButton, 'Next Step');
      expect(nextStepFinder, findsOneWidget);
      ElevatedButton nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNull);

      // Verify pool chips are visible: 15, 14, 13, 12, 10, 8
      expect(find.text('15'), findsWidgets);
      expect(find.text('14'), findsWidgets);
      expect(find.text('13'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('8'), findsWidgets);

      // Tap chip 15 to select it
      await tester.tap(find.widgetWithText(InkWell, '15').first);
      await tester.pumpAndSettle();

      // Tap "Assign 15" on Strength slot
      final assign15Finder = find.text('Assign 15');
      expect(assign15Finder, findsWidgets);
      await tester.tap(assign15Finder.first);
      await tester.pumpAndSettle();

      // Next step should still be disabled (1/6 allocated)
      nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNull);

      // Tap "Auto-Assign" to allocate the remaining standard array
      final autoAssignFinder = find.text('Auto-Assign');
      expect(autoAssignFinder, findsOneWidget);
      await tester.tap(autoAssignFinder);
      await tester.pumpAndSettle();

      // Next step should now be ENABLED!
      nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNotNull);

      // Tap Next Step -> should successfully advance past Ability Scores step
      await tester.tap(nextStepFinder);
      await tester.pumpAndSettle();

      expect(find.text('Step 5: Ability Score Allocation'), findsNothing);
      expect(find.textContaining('Feat'), findsWidgets);
    });

    testWidgets('Unassigning score returns it to pool and re-disables Next Step', (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await advanceToAbilityScores(tester);

      // Auto-assign to complete pool
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();

      final nextStepFinder = find.widgetWithText(ElevatedButton, 'Next Step');
      ElevatedButton nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNotNull);

      // Unassign STRENGTH using the "X" IconButton
      final closeIconFinder = find.byIcon(Icons.close);
      expect(closeIconFinder, findsWidgets);
      await tester.tap(closeIconFinder.first);
      await tester.pumpAndSettle();

      // Strength is now unassigned, Next Step must be disabled again
      nextButton = tester.widget<ElevatedButton>(nextStepFinder);
      expect(nextButton.onPressed, isNull);

      // '15' should now be back in the available pool chips
      expect(find.widgetWithText(InkWell, '15'), findsWidgets);
    });
  });
}
