import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
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
  });
}
