import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SRD Equipment & Inventory Character Builder Tests', () {
    test('SrdEquipmentLibrary returns class-tailored packages for all core classes', () {
      final wizardPackages = SrdEquipmentLibrary.getPackagesForClass('wizard');
      expect(wizardPackages.any((p) => p.name.contains('Spellweaver')), isTrue);
      expect(wizardPackages.any((p) => p.name.contains('Starting Wealth')), isTrue);

      final roguePackages = SrdEquipmentLibrary.getPackagesForClass('rogue');
      expect(roguePackages.any((p) => p.name.contains('Infiltrator')), isTrue);

      final barbarianPackages = SrdEquipmentLibrary.getPackagesForClass('barbarian');
      expect(barbarianPackages.any((p) => p.name.contains('Greataxe')), isTrue);
      expect(barbarianPackages.last.startingGold, equals(50));
    });

    testWidgets('Wizard class displays Wizard SRD starting equipment packages and starts with spellbook', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
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

      // Step 1 Basics -> Step 2 Species
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 Species -> Step 3 Class
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Select Wizard from dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Wizard (d6').last);
      await tester.pumpAndSettle();

      // Step 3 Class -> Step 4 Background
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4 Background -> Step 5 Ability Scores
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 5 Ability Scores -> Step 6 Feats
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 6 Feats -> Step 7 Equipment
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 7: Starting Equipment & Inventory (SRD)'), findsOneWidget);
      expect(find.text('Spellweaver: Quarterstaff, Arcane Focus & Spellbook'), findsOneWidget);
      expect(find.text('Arcane Explorer: Dagger, Component Pouch & Spellbook'), findsOneWidget);
      expect(find.text('Starting Wealth (Gold Only Option)'), findsOneWidget);

      // Select Arcane Explorer package
      await tester.tap(find.text('Arcane Explorer: Dagger, Component Pouch & Spellbook'));
      await tester.pumpAndSettle();

      // Advance to Review
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Arcane Explorer: Dagger, Component Pouch & Spellbook'), findsOneWidget);

      // Finalize and create character
      await tester.tap(find.text('CREATE & LAUNCH SHEET'));
      await tester.pumpAndSettle();

      final roster = await CharacterPersistenceService().loadCharacters();
      expect(roster.length, equals(1));
      final wizard = roster.first;
      expect(wizard.progression.startingClass?.classRef.displayName, equals('Wizard'));
      expect(wizard.inventory.any((i) => i.displayName == 'Spellbook'), isTrue);
      expect(wizard.inventory.any((i) => i.displayName == 'Dagger'), isTrue);
      expect(wizard.inventory.any((i) => i.displayName == 'Potion of Healing'), isTrue);
    });

    testWidgets('Starting Wealth (Gold Only) option assigns class gold to purse and zero initial gear', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
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

      // Switch to 2014 ruleset
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Advance to Class Step
      await tester.tap(find.text('Next Step')); // Step 1 -> 2
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 2 -> 3
      await tester.pumpAndSettle();

      // Select Rogue from dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Rogue (d8').last);
      await tester.pumpAndSettle();

      // Advance to Equipment Step
      await tester.tap(find.text('Next Step')); // Step 3 -> 4
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4 -> 5
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 -> 6 (Equipment in 2014)
      await tester.pumpAndSettle();

      expect(find.text('Starting Wealth (Gold Only Option)'), findsOneWidget);
      expect(find.text('100 GP'), findsOneWidget);

      // Select Starting Wealth
      await tester.tap(find.text('Starting Wealth (Gold Only Option)'));
      await tester.pumpAndSettle();

      // Advance to Review
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('100 GP'), findsWidgets);

      // Create character
      await tester.tap(find.text('CREATE & LAUNCH SHEET'));
      await tester.pumpAndSettle();

      final roster = await CharacterPersistenceService().loadCharacters();
      expect(roster.length, equals(1));
      final rogue = roster.first;
      expect(rogue.purse.gp, equals(100));
      expect(rogue.inventory, isEmpty);
    });
  });
}
