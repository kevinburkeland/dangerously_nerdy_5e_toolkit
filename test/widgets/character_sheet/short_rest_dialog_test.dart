import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_vitals_hud.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/short_rest_dialog.dart';

void main() {
  group('ShortRestDialog Widget Tests', () {
    late Character baseCharacter;
    late CharacterSheetController controller;

    setUp(() {
      baseCharacter = const Character(
        id: EntityId(slug: 'fighter-short-rest', ruleset: RulesetVersion.v2024),
        name: 'Gareth',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 4,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(
          constitution: 14, // Mod +2
        ),
        resources: CharacterResourcePool(
          currentHp: 15,
          currentHitDice: {'d10': 4},
        ),
      );

      controller = CharacterSheetController(character: baseCharacter);
    });

    testWidgets('Renders Hit Dice steppers and allows incrementing spent dice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ShortRestDialog.show(context, controller: controller),
                child: const Text('Open Short Rest'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Short Rest'));
      await tester.pumpAndSettle();

      expect(find.text('Short Rest'), findsOneWidget);
      expect(find.text('Die: d10'), findsOneWidget);
      expect(find.text('+2 CON'), findsOneWidget);
      expect(find.text('4 of 4 available'), findsOneWidget);

      // Tap '+' to spend 1 hit die
      final addIcon = find.byIcon(Icons.add_circle_outline);
      expect(addIcon, findsOneWidget);

      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Roll & Heal'), findsOneWidget);

      // Tap 'Roll & Heal'
      await tester.tap(find.text('Roll & Heal'));
      await tester.pumpAndSettle();

      // Verify HP increased and hit dice decreased
      expect(controller.character.resources.currentHitDice['d10'], equals(3));
      expect(controller.character.resources.currentHp, greaterThan(15));
    });

    testWidgets('Prevents incrementing beyond available Hit Dice count', (tester) async {
      // Character with only 1 hit die available
      final singleDieChar = baseCharacter.copyWith(
        resources: baseCharacter.resources.copyWith(currentHitDice: {'d10': 1}),
      );
      final singleDieController = CharacterSheetController(character: singleDieChar);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ShortRestDialog.show(context, controller: singleDieController),
                child: const Text('Open Short Rest'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Short Rest'));
      await tester.pumpAndSettle();

      final addIcon = find.byIcon(Icons.add_circle_outline);
      // Increment 1 die
      await tester.tap(addIcon);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Attempting to increment further when max is 1 should not change spent count
      await tester.tap(addIcon);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('CharacterVitalsHud Long Rest opens confirmation dialog and restores character vitals', (tester) async {
      // Set character with damaged HP and spent dice
      final damagedChar = baseCharacter.copyWith(
        resources: baseCharacter.resources.copyWith(
          currentHp: 5,
          tempHp: 4,
          deathSaveSuccesses: 2,
          currentHitDice: {'d10': 1},
          exhaustionLevel: 1,
        ),
      );
      final testController = CharacterSheetController(character: damagedChar);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CharacterVitalsHud(controller: testController),
            ),
          ),
        ),
      );

      // Verify Short Rest and Long Rest action buttons are present below HP bar
      expect(find.text('Short Rest'), findsWidgets);
      expect(find.text('Long Rest'), findsWidgets);

      // Tap Long Rest button
      await tester.tap(find.text('Long Rest').first);
      await tester.pumpAndSettle();

      // Check confirmation dialog content
      expect(find.text('Begin Long Rest?'), findsWidgets);
      expect(
        find.text('Begin Long Rest? This will restore HP, spell slots, half your hit dice, and reduce Exhaustion.'),
        findsOneWidget,
      );

      // Confirm Long Rest
      await tester.tap(find.widgetWithText(FilledButton, 'Begin Long Rest'));
      await tester.pumpAndSettle();

      // Check vitals fully restored
      expect(testController.character.resources.currentHp, equals(testController.stats.maxHp));
      expect(testController.character.resources.tempHp, equals(0));
      expect(testController.character.resources.deathSaveSuccesses, equals(0));
      expect(testController.character.resources.exhaustionLevel, equals(0));
      expect(testController.character.resources.currentHitDice['d10'], equals(3));
    });
  });
}
