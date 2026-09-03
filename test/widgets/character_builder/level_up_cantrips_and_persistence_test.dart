import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_header_banner.dart';

class _MockPersistenceService implements CharacterPersistenceService {
  Character? savedCharacter;
  List<Character> roster = [];

  @override
  Future<List<Character>> saveCharacter(Character character) async {
    savedCharacter = character;
    roster.removeWhere((c) => c.id.slug == character.id.slug);
    roster.add(character);
    return roster;
  }

  @override
  Future<List<Character>> loadCharacters() async => roster;

  @override
  Future<String?> loadActiveCharacterId() async => savedCharacter?.id.slug;

  @override
  Future<void> saveActiveCharacterId(String slug) async {}

  @override
  Future<void> saveRoster(List<Character> newRoster) async {
    roster = List.from(newRoster);
  }

  @override
  Future<List<Character>> deleteCharacter(String slug) async {
    roster.removeWhere((c) => c.id.slug == slug);
    return roster;
  }
}

void main() {
  group('Level Up Cantrip Quotas & Persistence Verification Tests', () {
    late Character level1Wizard;
    late _MockPersistenceService mockPersistence;

    setUp(() {
      mockPersistence = _MockPersistenceService();

      level1Wizard = const Character(
        id: EntityId(slug: 'gandalf', ruleset: RulesetVersion.v2024),
        name: 'Gandalf',
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
                slug: 'wizard',
                displayName: 'Wizard',
              ),
              level: 1,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
          intelligence: 16, // +3 mod
          constitution: 14,
        ),
        resources: CharacterResourcePool(
          currentHp: 8,
          currentHitDice: {'d6': 1},
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_fire_bolt', displayName: 'Fire Bolt'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_mage_hand', displayName: 'Mage Hand'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_light', displayName: 'Light'),
        ],
      );

      mockPersistence.saveCharacter(level1Wizard);
    });

    testWidgets('Leveling Wizard from 1 to 2 strictly blocks selecting any new cantrips (quota 0)', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(
              character: level1Wizard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Class (Wizard) -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: HP -> Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Features -> Step 4
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4: ASI/Feat -> Step 5
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // We are now on Step 5 (Spells & Cantrips Advancement)
      expect(find.textContaining('Step 5 of 6: Spells & Invocations Management'), findsOneWidget);

      // Verify quota clearly displays 0 new cantrips allowed
      expect(find.textContaining('0 New Cantrips allowed (3/3 already known)'), findsOneWidget);
      expect(find.text('0 New Allowed (3/3 known)'), findsOneWidget);

      // Ray of Frost is an available wizard cantrip not already known
      final rayOfFrostFinder = find.text('Ray of Frost');
      expect(rayOfFrostFinder, findsOneWidget);

      // Attempt to select Ray of Frost
      await tester.tap(rayOfFrostFinder);
      await tester.pump();

      // SnackBar should appear informing the user that no new cantrips are granted
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('No new cantrips granted at Level 2'), findsOneWidget);

      // Ray of Frost should NOT be selected in the candidate list
      expect(find.text('Cantrip: Ray of Frost'), findsNothing);
    });

    testWidgets('CharacterHeaderBanner Level Up immediately persists upgraded character to persistence service', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CharacterSheetController(
        character: level1Wizard,
        persistenceService: mockPersistence,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterHeaderBanner(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);

      // Tap Level Up action button
      await tester.tap(find.byKey(const Key('character_sheet_level_up_button')));
      await tester.pumpAndSettle();

      // Step 1 to 5
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step 6: Review & Final Confirmation
      expect(find.text('CONFIRM LEVEL UP'), findsOneWidget);
      await tester.tap(find.text('CONFIRM LEVEL UP'));
      await tester.pumpAndSettle();

      // Dialog dismissed, header banner updated to Level 2
      expect(find.text('Level 2'), findsOneWidget);
      expect(controller.character.totalLevel, equals(2));

      // Verify persistence service immediately saved the upgraded character
      final storedRoster = await mockPersistence.loadCharacters();
      expect(storedRoster.length, equals(1));
      final persistedGandalf = storedRoster.first;
      expect(persistedGandalf.totalLevel, equals(2));
      expect(persistedGandalf.resources.currentHitDice['d6'], equals(2));
    });

    test('CharacterSheetController.setCharacter persists immediately when persist is true', () async {
      final controller = CharacterSheetController(
        character: level1Wizard,
        persistenceService: mockPersistence,
      );

      final levelUpCandidate = level1Wizard.copyWith(
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'wizard',
                displayName: 'Wizard',
              ),
              level: 3,
              hitDie: 'd6',
            ),
          ],
        ),
      );

      await controller.setCharacter(levelUpCandidate, persist: true);

      final loaded = await mockPersistence.loadCharacters();
      expect(loaded.first.totalLevel, equals(3));
    });
  });
}
