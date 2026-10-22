import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/ability_score_step.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_dashboard/dm_dashboard_party_hud.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('F2 Ability Modifier Regression Tests on Both Screens', () {
    const testScores = [1, 8, 9, 10, 11, 20, 30];
    const expectedModifiers = [-5, -1, -1, 0, 0, 5, 10];

    testWidgets(
        'DmDashboardPartyHud: scores 1, 8, 9, 10, 11, 20, 30 give −5, −1, −1, 0, 0, +5, +10 (via AC and PP)',
        (tester) async {
      for (var i = 0; i < testScores.length; i++) {
        final score = testScores[i];
        final expectedMod = expectedModifiers[i];

        final character = Character(
          id: EntityId(slug: 'test_char_$score', ruleset: RulesetVersion.v2024),
          name: 'Hero $score',
          speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'human',
            displayName: 'Human',
          ),
          baseScores: AbilityScores(
            strength: 10,
            dexterity: score,
            constitution: 10,
            intelligence: 10,
            wisdom: score,
            charisma: 10,
          ),
          resources: const CharacterResourcePool(currentHp: 20),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DmDashboardPartyHud(partyRoster: [character]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedAc = 10 + expectedMod;
        final expectedPp = 10 + expectedMod;

        expect(
          find.text('AC $expectedAc'),
          findsOneWidget,
          reason: 'Score $score should produce modifier $expectedMod for Dex resulting in AC $expectedAc',
        );
        expect(
          find.text('PP $expectedPp'),
          findsOneWidget,
          reason: 'Score $score should produce modifier $expectedMod for Wis resulting in PP $expectedPp',
        );
      }
    });

    Future<void> advanceToAbilityScores(WidgetTester tester) async {
      for (int i = 0; i < 10; i++) {
        if (find.textContaining('Ability Score Allocation').evaluate().isNotEmpty) {
          break;
        }
        if (find.text('Step 2: Choose Species / Race').evaluate().isNotEmpty) {
          if (find.byIcon(Icons.radio_button_checked).evaluate().isEmpty) {
            final human = find.widgetWithText(ListTile, 'Human');
            if (human.evaluate().isNotEmpty) {
              await tester.tap(human.first);
              await tester.pumpAndSettle();
            }
          }
        } else if (find.text('Step 3: Choose Class & Starting Skills').evaluate().isNotEmpty) {
          final dropdown = find.byType(DropdownButtonFormField<String>);
          if (dropdown.evaluate().isNotEmpty) {
            await tester.tap(dropdown.first);
            await tester.pumpAndSettle();
            await tester.tap(find.textContaining('Fighter (').last);
            await tester.pumpAndSettle();
          }
        } else if (find.text('Fighter Decisions & Specializations').evaluate().isNotEmpty) {
          final defense = find.widgetWithText(ListTile, 'Defense');
          if (defense.evaluate().isNotEmpty) {
            await tester.tap(defense.first);
            await tester.pumpAndSettle();
          }
        } else if (find.textContaining('Choose Background').evaluate().isNotEmpty) {
          final acolyte = find.widgetWithText(ListTile, 'Acolyte');
          if (acolyte.evaluate().isNotEmpty) {
            await tester.tap(acolyte.first);
            await tester.pumpAndSettle();
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
        'CharacterBuilderScreen: scores 1, 8, 9, 10, 11, 20, 30 give −5, −1, −1, 0, 0, +5, +10',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      await advanceToAbilityScores(tester);

      // Select 'Enter Own' manual entry
      await tester.tap(find.text('Enter Own'));
      await tester.pumpAndSettle();

      final stepWidget = tester.widget<AbilityScoreStep>(find.byType(AbilityScoreStep));
      final controller = stepWidget.controller;

      for (var i = 0; i < testScores.length; i++) {
        final score = testScores[i];
        final expectedMod = expectedModifiers[i];
        final expectedModStr = expectedMod >= 0 ? '+$expectedMod' : '$expectedMod';

        controller.setManualScore(AbilityType.strength, score);
        await tester.pumpAndSettle();

        // In AbilityScoreStep manual section:
        expect(
          find.text('STRENGTH ($expectedModStr)'),
          findsOneWidget,
          reason: 'Score $score should produce modifier $expectedModStr for STRENGTH in CharacterBuilder',
        );
      }
    });
  });
}
