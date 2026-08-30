import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';

Widget createTestApp() {
  return const MaterialApp(
    home: CharacterBuilderScreen(),
  );
}

Character _createTestHero(String slug, String name) {
  return CharacterFactory.createLevel1Character(
    CharacterCreationRequest(
      characterName: name,
      ruleset: RulesetVersion.v2024,
      speciesRef: const EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      backgroundRef: const EntityReference(
        refType: EntityType.background,
        slug: 'soldier',
        displayName: 'Soldier',
      ),
      startingClassSlug: 'fighter',
      startingClassDisplayName: 'Fighter',
      startingClassHitDie: 'd10',
      baseScores: const AbilityScores.standardArray(),
      bonusScores: const AbilityScores(strength: 2, constitution: 1),
      savingThrowProficiencies: const {
        AbilityType.strength,
        AbilityType.constitution,
      },
      skillProficiencies: const {
        SkillType.athletics: SkillProficiencyLevel.proficient,
        SkillType.stealth: SkillProficiencyLevel.none,
      },
    ),
  ).copyWith(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CharacterBuilderScreen Live Sheet & Wizard UI Tests', () {
    testWidgets('Renders empty roster state when no characters are created', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Top edition toggle
      expect(find.byType(RulesEditionToggle), findsOneWidget);
      expect(find.text('2024'), findsWidgets);
      expect(find.text('2014'), findsWidgets);

      // Tabs: in selector/empty state, only Live Sheet and Guided Builder are shown
      expect(find.text('Live Sheet'), findsOneWidget);
      expect(find.text('Guided Builder'), findsOneWidget);
      expect(find.text('Inventory & Loot'), findsNothing);
      expect(find.text('Level Up'), findsNothing);

      // Default Character Selector View with empty state
      expect(find.text('5e Character Roster'), findsOneWidget);
      expect(find.text('No characters in roster yet.'), findsOneWidget);
      expect(find.text('Create New Character'), findsOneWidget);
    });

    testWidgets('Tapping Open Sheet on character opens Live Sheet with vitals and skills', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHero = _createTestHero('valeros-ironclad', 'Valeros Ironclad');
      await CharacterPersistenceService().saveRoster([testHero]);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // In selector view, only 2 tabs
      expect(find.text('Live Sheet'), findsOneWidget);
      expect(find.text('Guided Builder'), findsOneWidget);
      expect(find.text('Inventory & Loot'), findsNothing);
      expect(find.text('Level Up'), findsNothing);

      // Tap Open Sheet on Valeros Ironclad
      final openSheetBtn = find.byKey(const ValueKey('open_sheet_valeros-ironclad'));
      expect(openSheetBtn, findsOneWidget);
      await tester.tap(openSheetBtn);
      await tester.pumpAndSettle();

      // Now actively viewing a character -> all 4 tabs present
      expect(find.text('Live Sheet'), findsOneWidget);
      expect(find.text('Guided Builder'), findsOneWidget);
      expect(find.text('Inventory & Loot'), findsOneWidget);
      expect(find.text('Level Up'), findsOneWidget);

      // Vitals
      expect(find.text('ARMOR CLASS'), findsOneWidget);
      expect(find.text('PROF BONUS'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);

      // Saving Throws Card
      expect(find.text('SAVING THROWS'), findsOneWidget);
      expect(find.text('STR'), findsWidgets);
      expect(find.text('DEX'), findsWidgets);
      expect(find.text('CON'), findsWidgets);

      // Skills Card
      expect(find.text('SKILLS & PROFICIENCIES'), findsOneWidget);
      expect(find.text('Athletics'), findsOneWidget);
      expect(find.text('Stealth'), findsOneWidget);

      // Switch Hero button exists in active header
      expect(find.textContaining('Switch Hero'), findsOneWidget);
    });

    testWidgets('Tapping Switch Hero in Live Sheet returns to Character Selector', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHero = _createTestHero('valeros-ironclad', 'Valeros Ironclad');
      await CharacterPersistenceService().saveRoster([testHero]);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Open sheet
      final openSheetBtn = find.byKey(const ValueKey('open_sheet_valeros-ironclad'));
      await tester.tap(openSheetBtn);
      await tester.pumpAndSettle();

      // Tap Switch Hero
      final switchHeroBtn = find.textContaining('Switch Hero');
      await tester.tap(switchHeroBtn);
      await tester.pumpAndSettle();

      // Back to roster
      expect(find.text('5e Character Roster'), findsOneWidget);
      expect(find.text('Valeros Ironclad'), findsOneWidget);
    });

    testWidgets('Deleting a character prompts confirmation and removes from roster', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hero1 = _createTestHero('valeros-ironclad', 'Valeros Ironclad');
      final hero2 = _createTestHero('lyra-sunseeker', 'Lyra Sunseeker');
      await CharacterPersistenceService().saveRoster([hero1, hero2]);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Delete Lyra Sunseeker
      final deleteBtn = find.byKey(const ValueKey('delete_character_lyra-sunseeker'));
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Delete Lyra Sunseeker?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify removed
      expect(find.text('Lyra Sunseeker'), findsNothing);
      expect(find.text('Valeros Ironclad'), findsOneWidget);
    });

    testWidgets('Tapping a saving throw triggers roll feedback', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testHero = _createTestHero('valeros-ironclad', 'Valeros Ironclad');
      await CharacterPersistenceService().saveRoster([testHero]);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Open sheet
      final openSheetBtn = find.byKey(const ValueKey('open_sheet_valeros-ironclad'));
      await tester.tap(openSheetBtn);
      await tester.pumpAndSettle();

      // Tap STR saving throw tile
      final strSaveTile = find.byKey(const ValueKey('save_tile_strength'));
      await tester.tap(strSaveTile);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SnackBar with roll result appeared
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Saving Throw'), findsOneWidget);
    });

    testWidgets('Switching to Guided Builder tab displays 8-step wizard', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Guided Builder Tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1: Character Identity & Edition'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);

      // Tap Next Step to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      expect(find.text('Human'), findsOneWidget);
      expect(find.text('Elf'), findsOneWidget);

      // Tap Next Step to Step 3: Class
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
    });

    testWidgets('Toggling RulesEditionToggle updates edition state and SettingsProvider', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(rulesEdition: DmRulesEdition.v2024),
        autoLoad: false,
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

      // Verify initial edition is 2024
      expect(settingsProvider.settings.rulesEdition, DmRulesEdition.v2024);

      // Switch to 2014 via AppBar toggle
      final toggleFinder = find.byType(RulesEditionToggle);
      await tester.tap(find.descendant(of: toggleFinder, matching: find.text('2014')));
      await tester.pumpAndSettle();

      // Verify settingsProvider updated to 2014
      expect(settingsProvider.settings.rulesEdition, DmRulesEdition.v2014);

      // Switch back to 2024
      await tester.tap(find.descendant(of: toggleFinder, matching: find.text('2024')));
      await tester.pumpAndSettle();

      expect(settingsProvider.settings.rulesEdition, DmRulesEdition.v2024);
    });

    testWidgets('Guided Builder Step 1 ruleset switch updates global SettingsProvider and species speed', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(rulesEdition: DmRulesEdition.v2024),
        autoLoad: false,
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

      // Switch to Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Select 2014 SRD (5.1 Classic)
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      expect(settingsProvider.settings.rulesEdition, DmRulesEdition.v2014);

      // Proceed to Step 2: Species
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      // Gnome/Dwarf speed in 2014 should show 25 ft.
      expect(find.textContaining('Speed: 25 ft.'), findsWidgets);
    });

    testWidgets('2014 character creation skips Feat step and creates character with no origin feats', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(rulesEdition: DmRulesEdition.v2014),
        autoLoad: false,
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

      // Go to Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Ensure 2014 is selected
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Species)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);

      // Select standard Human
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Class)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);

      // Step 3 -> Step 4 (Background)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4: Choose Background'), findsOneWidget);
      expect(find.textContaining('Origin Feat:'), findsNothing);

      // Step 4 -> Step 5 (Ability Scores)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5: Ability Score Allocation'), findsOneWidget);

      // Step 5 -> Step 6 (Equipment - Feats step was skipped!)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 6: Starting Equipment'), findsOneWidget);

      // Step 6 -> Step 7 (Review)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 7: Review & Finalize'), findsOneWidget);
      expect(find.textContaining('Origin Feat:'), findsNothing);

      // Create character
      await tester.tap(find.text('CREATE & LAUNCH SHEET'));
      await tester.pumpAndSettle();

      final roster = await CharacterPersistenceService().loadCharacters();
      expect(roster.length, equals(1));
      expect(roster.first.feats, isEmpty);
    });

    testWidgets('2014 Variant Human character creation includes Feat step and saves starting feat', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(rulesEdition: DmRulesEdition.v2014),
        autoLoad: false,
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

      // Go to Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Species)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Select Human (Variant)
      await tester.tap(find.text('Human (Variant)'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Class)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3 -> Step 4 (Background)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4 -> Step 5 (Ability Scores)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 5 -> Step 6 (Variant Human Feat)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 6: Human (Variant) Bonus Feat'), findsOneWidget);

      // Step 6 -> Step 7 (Equipment)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 7: Starting Equipment'), findsOneWidget);

      // Step 7 -> Step 8 (Review)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 8: Review & Finalize'), findsOneWidget);
    });
  });
}
