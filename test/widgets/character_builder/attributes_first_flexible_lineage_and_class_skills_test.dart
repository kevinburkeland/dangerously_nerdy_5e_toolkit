import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Attributes-First Lineage Flexible Choices & Class Skills Tests', () {
    testWidgets('Selecting Half-Elf in 2014 mode prompts flexible choices inside card and gates progression', (tester) async {
      tester.view.physicalSize = const Size(1280, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(
          wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
        ),
      );

      await tester.pumpWidget(
        SettingsScope(
          notifier: settingsProvider,
          child: const MaterialApp(
            home: CharacterBuilderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 2014 ruleset
      final rulesetFinder = find.text('2014');
      if (rulesetFinder.evaluate().isNotEmpty) {
        await tester.tap(rulesetFinder.first);
        await tester.pumpAndSettle();
      }

      // Open Guided Builder tab
      final guidedTabFinder = find.text('Guided Builder');
      await tester.tap(guidedTabFinder);
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Step 2 in Attributes-First: Ability Scores step
      final autoAssignFinder = find.text('Auto-Assign');
      expect(autoAssignFinder, findsOneWidget);
      await tester.tap(autoAssignFinder);
      await tester.pumpAndSettle();

      // Proceed to Step 3 in Attributes-First: Class
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Select Barbarian (no level 1 decisions, direct to Species)
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Barbarian (').last);
      await tester.pumpAndSettle();

      // Proceed to Species step
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Choose Species / Race'), findsOneWidget);

      // Select Half-Elf
      final halfElfFinder = find.text('Half-Elf');
      expect(halfElfFinder, findsOneWidget);
      await tester.tap(halfElfFinder);
      await tester.pumpAndSettle();

      // Verify the prompt rendered directly inside the card:
      // "Half-Elf Lineage Ability Choices (+1):"
      expect(find.textContaining('Half-Elf Lineage Ability Choices (+1):'), findsOneWidget);
      expect(find.textContaining('Species Bonus Skills (Half-Elf):'), findsOneWidget);

      // Verify that CHA is fixed (+2 Fixed) and cannot be chosen as flexible
      expect(find.textContaining('CHARISMA (+2 Fixed)'), findsOneWidget);

      // Verify Next Step button is disabled because 0 of 2 flexible choices are selected
      final nextButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next Step'));
      expect(nextButton.onPressed, isNull);

      // Select Dexterity (+1 Bonus)
      final dexChip = find.textContaining('DEXTERITY (+1 Bonus)');
      expect(dexChip, findsOneWidget);
      await tester.tap(dexChip);
      await tester.pumpAndSettle();

      final nextButtonStillDisabled = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next Step'));
      expect(nextButtonStillDisabled.onPressed, isNull);

      // Select Constitution (+1 Bonus)
      final conChip = find.textContaining('CONSTITUTION (+1 Bonus)');
      expect(conChip, findsOneWidget);
      await tester.tap(conChip);
      await tester.pumpAndSettle();

      // Now Next Step button should be enabled!
      final nextButtonEnabled = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next Step'));
      expect(nextButtonEnabled.onPressed, isNotNull);
    });

    testWidgets('Imported class starting skills populate allowed skills and choice count', (tester) async {
      tester.view.physicalSize = const Size(1280, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Ingest a custom class with 3 skill choices from Arcana, History, Nature, Religion
      final customClassRaw = {
        'name': 'Archivist',
        'hd': {'number': 1, 'faces': 8},
        'proficiency': ['int', 'wis'],
        'primaryAbility': 'Intelligence',
        'startingProficiencies': {
          'skills': [
            {
              'choose': {
                'from': ['arcana', 'history', 'nature', 'religion'],
                'count': 3
              }
            }
          ]
        }
      };
      final parsedClass = CompendiumClassParser().parseClass(customClassRaw);
      await HomebrewPersistenceService().saveCustomClassesBatch([parsedClass]);
      addTearDown(() async {
        await HomebrewPersistenceService().saveCustomClassesBatch([]);
        SrdClassesLibrary.setCustomClasses([]);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      final guidedTabFinder = find.text('Guided Builder');
      await tester.tap(guidedTabFinder);
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human -> Next Step
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Archivist (now sorted first alphabetically)
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Archivist (').last);
      await tester.pumpAndSettle();

      // Verify that Class Skills header shows (Pick 3)
      expect(find.text('Class Skills (Pick 3):'), findsOneWidget);

      // Verify Arcana, History, Nature, Religion are available chips
      expect(find.widgetWithText(FilterChip, 'Arcana'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'History'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'Nature'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'Religion'), findsWidgets);

      // Verify initially automatically populated with 3 of 3 allowed skills
      expect(find.text('3 / 3 selected'), findsOneWidget);

      // Deselect Arcana
      await tester.tap(find.widgetWithText(FilterChip, 'Arcana').first);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3 selected'), findsOneWidget);

      // Select Religion as the 3rd skill
      await tester.tap(find.widgetWithText(FilterChip, 'Religion').first);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3 selected'), findsOneWidget);
    });
  });
}
