import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';

void main() {
  group('LevelUpWizardDialog Selection List Omission Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SrdFeatureOptions.setCustomInvocations([]);
      SrdFeatureOptions.setCustomInfusions([]);
    });

    testWidgets('Already selected invocations are omitted and unselected/novel invocations appear', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Register custom invocation Lance of Lethargy from homebrew
      const lance = FeatureOption(
        id: 'lance-of-lethargy',
        name: 'Lance of Lethargy',
        descriptionMarkdown: 'Once on each of your turns when you hit a creature with your eldritch blast, reduce speed by 10 ft.',
        customProperties: {
          'page': 57,
          'featureType': ['EI'],
          'prerequisite': [
            {
              'spell': ['eldritch blast#c'],
            }
          ],
        },
      );
      SrdFeatureOptions.setCustomInvocations([lance]);

      // Character: Level 4 Warlock leveling to Level 5.
      // Already selected: Armor of Shadows and Fiendish Vigor at Level 2.
      // Already known spells: Eldritch Blast (cantrip), Hex (level 1), Hellish Rebuke (level 1).
      const character = Character(
        id: EntityId(slug: 'test-warlock', ruleset: RulesetVersion.v2014),
        name: 'Test Warlock',
        speciesRef: EntityReference(slug: 'human', displayName: 'Human', refType: EntityType.species),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(slug: 'warlock', displayName: 'Warlock', refType: EntityType.classDefinition),
              level: 4,
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {
                'warlock-invocations-2': ['armor_of_shadows', 'fiendish_vigor'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 10, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 12, charisma: 16),
        cantrips: [
          EntityReference(slug: 'eldritch-blast', displayName: 'Eldritch Blast', refType: EntityType.spell),
        ],
        spellsKnown: [
          EntityReference(slug: 'hex', displayName: 'Hex', refType: EntityType.spell),
          EntityReference(slug: 'hellish-rebuke', displayName: 'Hellish Rebuke', refType: EntityType.spell),
        ],
        resources: CharacterResourcePool(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => LevelUpWizardDialog(
                      character: character,
                      onLevelUpApplied: (_) {},
                    ),
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Step 1: Target Class
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: HP
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class features (Level 5 Warlock invocation decision)
      expect(find.text('Step 3 of 6: Class Features & Subclass Archetype'), findsOneWidget);

      // Armor of Shadows and Fiendish Vigor were ALREADY SELECTED at level 2 -> MUST BE OMITTED!
      expect(find.text('Armor of Shadows'), findsNothing);
      expect(find.text('Fiendish Vigor'), findsNothing);

      // Lance of Lethargy (unselected homebrew invocation) MUST BE PRESENT!
      expect(find.text('Lance of Lethargy'), findsOneWidget);

      // Other unselected invocations (e.g. Devil's Sight, Eldritch Spear) MUST BE PRESENT!
      expect(find.text("Devil's Sight"), findsOneWidget);
      expect(find.text('Eldritch Spear'), findsOneWidget);

      // Step 4: ASI/Feat
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 5: Spells
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 6: Spells & Invocations Management'), findsOneWidget);

      // Spells already known (Hex, Hellish Rebuke) MUST BE OMITTED from available leveled spells list!
      // (They only appear in the "Replace a Known Spell" row, not in "Available Leveled Spells")
      expect(find.text('Replacing: Hex'), findsNothing); // not clicked yet
      // Available Leveled Spells grid header
      expect(find.textContaining('Available Leveled Spells'), findsOneWidget);
      // In the available spells list, Hex (L1) and Hellish Rebuke (L1) are omitted:
      expect(find.text('Hex (L1)'), findsNothing);
      expect(find.text('Hellish Rebuke (L1)'), findsNothing);

      // Unlearned 1st-level spells like Illusory Script (L1) and Charm Person (L1) are available:
      expect(find.text('Illusory Script (L1)'), findsOneWidget);
      expect(find.text('Charm Person (L1)'), findsOneWidget);
    });

    test('Ingests custom homebrew Infusions and Invocations and syncs to runtime libraries', () async {
      final pipeline = CompendiumJsonIngestionPipeline();
      const resolver = HomebrewMergeResolver();
      final persistence = HomebrewPersistenceService();

      const jsonCompendium = '''
{
  "infusion": [
    {
      "name": "Boots of the Winding Path",
      "source": "TCE",
      "entries": [
        "A creature wearing these boots can teleport up to 15 feet as a bonus action."
      ]
    }
  ],
  "invocation": [
    {
      "name": "Lance of Lethargy",
      "source": "XGE",
      "entries": [
        "Prerequisite: Eldritch Blast cantrip. Once on each of your turns when you hit a creature with your Eldritch Blast, you can reduce that creature's speed by 10 feet until the end of your next turn."
      ]
    }
  ]
}
''';

      final ingestion = pipeline.ingestJsonString(jsonCompendium);
      expect(ingestion.hasErrors, isFalse);
      expect(ingestion.otherEntries.length, equals(2));

      final infusionEntry = ingestion.otherEntries.firstWhere((e) => e.name == 'Boots of the Winding Path');
      expect(infusionEntry.category, equals('Infusion'));

      final invocationEntry = ingestion.otherEntries.firstWhere((e) => e.name == 'Lance of Lethargy');
      expect(invocationEntry.category, equals('Eldritch Invocation'));

      final bundle = ingestion.toBundle();
      final analysis = resolver.analyzeBundle(incomingBundle: bundle);
      await persistence.importResolvedBundle(analysis);

      // Verify custom Invocations includes Lance of Lethargy
      expect(SrdFeatureOptions.warlockInvocations.any((i) => i.name == 'Lance of Lethargy'), isTrue);

      // Verify custom Infusions includes Boots of the Winding Path
      expect(SrdFeatureOptions.artificerInfusions.any((i) => i.name == 'Boots of the Winding Path'), isTrue);
    });
  });
}
