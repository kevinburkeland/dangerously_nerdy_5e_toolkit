import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/languages_tools_section.dart';

void main() {
  group('LanguagesToolsSection Widget Tests', () {
    late Character testCharacter;
    late CharacterSheetController controller;

    setUp(() {
      testCharacter = const Character(
        id: EntityId(slug: 'rogue-tester', ruleset: RulesetVersion.v2024),
        name: 'Shadowfoot',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        languages: ['Common', 'Elvish'],
        toolProficiencies: ["Thieves' Tools"],
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
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
          dexterity: 16, // +3
          intelligence: 12,
          wisdom: 10,
        ),
        resources: CharacterResourcePool(currentHp: 20),
      );

      controller = CharacterSheetController(character: testCharacter);
    });

    testWidgets('Renders languages and tool proficiencies cards properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LanguagesToolsSection(controller: controller),
            ),
          ),
        ),
      );

      expect(find.text('Languages Known'), findsOneWidget);
      expect(find.text('Tool Proficiencies'), findsOneWidget);

      // Verify language chips
      expect(find.text('Common'), findsOneWidget);
      expect(find.text('Elvish'), findsOneWidget);

      // Verify tool proficiency card
      expect(find.text("Thieves' Tools"), findsOneWidget);
      expect(find.textContaining('Kits & Specialized Tools'), findsOneWidget);
      expect(find.textContaining('DEX check'), findsOneWidget);
      expect(find.textContaining('Roll'), findsOneWidget);
    });

    testWidgets('Tapping Roll executes a d20 tool check and shows SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LanguagesToolsSection(controller: controller),
            ),
          ),
        ),
      );

      // Tap the Roll button for Thieves' Tools
      final rollBtn = find.textContaining('Roll');
      expect(rollBtn, findsOneWidget);
      await tester.tap(rollBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining("Thieves' Tools Check:"), findsOneWidget);
    });

    testWidgets('Can add a new language via dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LanguagesToolsSection(controller: controller),
            ),
          ),
        ),
      );

      // Open Add Language dialog
      await tester.tap(find.text('Add Language'));
      await tester.pumpAndSettle();

      expect(find.text('Add Language Known'), findsOneWidget);

      // Select 'Draconic' from options
      await tester.tap(find.text('Draconic'));
      await tester.pumpAndSettle();

      expect(controller.character.languages, contains('Draconic'));
    });

    testWidgets('Can add a new tool proficiency via dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LanguagesToolsSection(controller: controller),
            ),
          ),
        ),
      );

      // Open Add Tool dialog
      await tester.tap(find.text('Add Tool'));
      await tester.pumpAndSettle();

      // Search for Smith's Tools in the dialog filter
      await tester.enterText(find.byType(TextField), "Smith's Tools");
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, "Smith's Tools"));
      await tester.pumpAndSettle();

      expect(controller.character.toolProficiencies, contains("Smith's Tools"));
    });

    testWidgets('Can delete a language and a tool proficiency', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LanguagesToolsSection(controller: controller),
            ),
          ),
        ),
      );

      // Delete 'Elvish'
      final elvishDelete = find.byTooltip('Remove Elvish');
      expect(elvishDelete, findsOneWidget);
      await tester.tap(elvishDelete);
      await tester.pumpAndSettle();

      expect(controller.character.languages, isNot(contains('Elvish')));

      // Delete "Thieves' Tools"
      final toolDelete = find.byTooltip("Remove Thieves' Tools");
      expect(toolDelete, findsOneWidget);
      await tester.tap(toolDelete);
      await tester.pumpAndSettle();

      expect(controller.character.toolProficiencies, isNot(contains("Thieves' Tools")));
    });
  });
}
