import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_reparse_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  setUp(() {
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
  });

  tearDown(() {
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
  });

  group('Generic Subclass Linking & Sheet Propagation Diagnostics', () {
    test(
        'links generic custom subclass to Warlock class across slug variations',
        () {
      final parser = CompendiumClassParser();
      // Generic compendium raw JSON for an invented custom homebrew subclass
      final raw = {
        'name': 'The Abyssal Mariner',
        'shortName': 'Mariner',
        'source': 'HOMEBREW_CUSTOM',
        'className': 'Warlock',
        'classSource': 'SRD',
        'subclassFeatures': [
          {
            'name': 'Spectral Grasp',
            'level': 1,
            'entries': [
              'You can magically summon a spectral grasp as a bonus action that deals 1d8 cold damage.',
            ],
          },
          {
            'name': 'Aquatic Adaptation',
            'level': 1,
            'entries': [
              'You gain a swimming speed of 40 feet and can breathe underwater.',
            ],
          },
        ],
      };

      final sub = parser.parseSubclass(raw);
      expect(sub.name, equals('The Abyssal Mariner'));
      expect(sub.classSlug, equals('warlock'));
      SrdClassesLibrary.addCustomSubclass(sub);

      // 1. Is it in allSubclasses?
      expect(
          SrdClassesLibrary.allSubclasses
              .any((s) => s.name == 'The Abyssal Mariner'),
          isTrue);

      // 2. Is it in warlockClass.subclasses?
      final warlockClass = SrdClassesLibrary.allClasses.firstWhere(
        (c) => c.slug == 'warlock',
      );
      expect(
        warlockClass.subclasses.any((s) => s.name == 'The Abyssal Mariner'),
        isTrue,
      );

      // 3. Does findSubclass find it with short slug 'mariner'?
      expect(SrdClassesLibrary.findSubclass('mariner', classSlug: 'warlock'),
          isNotNull);

      // 4. Does findSubclass find it with 'the-abyssal-mariner'?
      expect(
          SrdClassesLibrary.findSubclass('the-abyssal-mariner',
              classSlug: 'warlock'),
          isNotNull);

      // 5. Does findSubclass find it with class-prefixed 'warlock-the-abyssal-mariner'?
      expect(
          SrdClassesLibrary.findSubclass('warlock-the-abyssal-mariner',
              classSlug: 'warlock'),
          isNotNull);
    });

    test(
        'links subclass when className has source pipe like Warlock|SRD or Warlock|CUSTOM',
        () {
      final parser = CompendiumClassParser();
      final raw = {
        'name': 'The Abyssal Mariner',
        'shortName': 'Mariner',
        'source': 'CUSTOM_SRC',
        'className': 'Warlock|SRD',
        'subclassFeatures': [
          'Spectral Grasp|Warlock|SRD|The Abyssal Mariner|CUSTOM_SRC|1',
        ],
      };

      final sub = parser.parseSubclass(raw);
      expect(sub.classSlug, equals('warlock'));
      SrdClassesLibrary.addCustomSubclass(sub);

      final warlockClass =
          SrdClassesLibrary.allClasses.firstWhere((c) => c.slug == 'warlock');
      expect(
          warlockClass.subclasses.any((s) => s.name == 'The Abyssal Mariner'),
          isTrue);
    });

    test(
        'infers classSlug from subclassFeatures or slug prefix when className is missing',
        () {
      final parser = CompendiumClassParser();
      final raw = {
        'name': 'The Abyssal Mariner',
        'shortName': 'Mariner',
        'source': 'CUSTOM_SRC',
        // className missing
        'subclassFeatures': [
          'Spectral Grasp|Warlock|SRD|The Abyssal Mariner|CUSTOM_SRC|1',
        ],
      };

      final sub = parser.parseSubclass(raw);
      expect(sub.classSlug, equals('warlock'));
      SrdClassesLibrary.addCustomSubclass(sub);

      final warlockClass =
          SrdClassesLibrary.allClasses.firstWhere((c) => c.slug == 'warlock');
      expect(
          warlockClass.subclasses.any((s) => s.name == 'The Abyssal Mariner'),
          isTrue);
    });

    test('character.allGrants collects grants from linked custom subclass', () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'warlock-the-abyssal-mariner',
            ruleset: RulesetVersion.homebrew),
        name: 'The Abyssal Mariner',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown:
            '### Spectral Grasp (Level 1)\n\nBonus action spectral grasp.\n\n### Aquatic Adaptation (Level 1)\n\nSwim speed 40ft.',
        grants: [
          FeatureGrant(
            grantId: 'mariner-swim-speed',
            label: 'Aquatic Adaptation Swim Speed',
            type: GrantType.speedModifier,
            payload: {'amount': 40},
          ),
        ],
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      final character = Character(
        id: const EntityId(
            slug: 'my-custom-warlock', ruleset: RulesetVersion.v2014),
        name: 'Generic Custom Warlock',
        speciesRef: const EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: const EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'warlock',
                  displayName: 'Warlock'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'the-abyssal-mariner', // slug without class prefix
                displayName: 'The Abyssal Mariner',
                customProperties: {
                  'grants': customSub.grants,
                },
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
            strength: 10,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 16),
        resources: const CharacterResourcePool(currentHp: 10),
      );

      // Verify activeGrants finds the subclass and includes the grant
      expect(
          character.activeGrants.any((g) => g.grantId == 'mariner-swim-speed'),
          isTrue);
    });

    test('CharacterActionsResolver resolves action for 2014 Level 1 Warlock',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'warlock-the-abyssal-mariner',
            ruleset: RulesetVersion.homebrew),
        name: 'The Abyssal Mariner',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown:
            '### Spectral Grasp (Level 1)\n\n*Abyssal Mariner Feature*\n\nYou can summon a spectral grasp as a bonus action.',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      const character = Character(
        id: EntityId(slug: 'my-custom-warlock', ruleset: RulesetVersion.v2014),
        name: 'Generic Custom Warlock',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'warlock',
                  displayName: 'Warlock'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'the-abyssal-mariner',
                displayName: 'The Abyssal Mariner',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 10,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 16),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final controller = CharacterSheetController(character: character);
      final stats = CharacterEvaluationEngine.evaluate(character);
      final resolved = CharacterActionsResolver.resolve(
        character: character,
        stats: stats,
        controller: controller,
      );

      final bonusActions =
          resolved.bonusActions.map((a) => a.name.toLowerCase()).toList();
      expect(
          bonusActions.any((name) => name.contains('spectral grasp')), isTrue);
    });

    test(
        'SubclassSpellsLibrary returns expanded spells for custom Warlock archetype',
        () {
      final parser = CompendiumClassParser();
      final raw = {
        'name': 'The Abyssal Mariner',
        'shortName': 'Mariner',
        'source': 'CUSTOM_SRC',
        'className': 'Warlock',
        'subclassSpells': [
          'fog cloud',
          'gust of wind',
          'sleet storm',
          'control water',
          'cone of cold',
        ],
        'subclassFeatures': [
          'Spectral Grasp|Warlock|SRD|The Abyssal Mariner|CUSTOM_SRC|1',
        ],
      };

      final sub = parser.parseSubclass(raw);
      SrdClassesLibrary.addCustomSubclass(sub);

      // Check with 'mariner'
      final spellsWithShort =
          SubclassSpellsLibrary.getExpandedSpells('warlock', 'mariner');
      expect(spellsWithShort, contains('fog cloud'));

      // Check with 'the-abyssal-mariner'
      final spellsWithThe = SubclassSpellsLibrary.getExpandedSpells(
          'warlock', 'the-abyssal-mariner');
      expect(spellsWithThe, contains('fog cloud'));

      // Check with 'warlock-the-abyssal-mariner'
      final spellsWithFull = SubclassSpellsLibrary.getExpandedSpells(
          'warlock', 'warlock-the-abyssal-mariner');
      expect(spellsWithFull, contains('fog cloud'));
    });

    test('CharacterReparseEngine self-heals un-hydrated subclass on character',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'warlock-the-abyssal-mariner',
            ruleset: RulesetVersion.homebrew),
        name: 'The Abyssal Mariner',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown: '### Spectral Grasp (Level 1)\n\nBonus action grasp.',
        grants: [
          FeatureGrant(
            grantId: 'mariner-swim-speed',
            label: 'Aquatic Adaptation Swim Speed',
            type: GrantType.speedModifier,
            payload: {'amount': 40},
          ),
        ],
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      // A legacy or un-hydrated character with no customProperties on subclassRef
      const unhydratedChar = Character(
        id: EntityId(slug: 'legacy-warlock', ruleset: RulesetVersion.v2014),
        name: 'Legacy Warlock',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'warlock',
                  displayName: 'Warlock'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug:
                    'the-abyssal-mariner', // partial slug, no customProperties
                displayName: 'The Abyssal Mariner',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 10,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 16),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final healedChar = CharacterReparseEngine.reparse(unhydratedChar);

      // Reparse should have healed customProperties on subclassRef
      final healedSubRef = healedChar.progression.classes.first.subclassRef;
      expect(healedSubRef, isNotNull);
      expect(healedSubRef!.customProperties['featuresMarkdown'], isNotNull);
      expect(
        healedSubRef.customProperties['featuresMarkdown'].toString(),
        contains('Spectral Grasp'),
      );
      expect(healedSubRef.customProperties['grants'], isNotNull);
    });

    test(
        'relational feature pointers with prefix discrepancies resolve and stitch into rich descriptions',
        () {
      SrdClassesLibrary.clearCustomSubclassFeatures();
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Spectral Grasp',
        'className': 'Warlock',
        'subclassShortName': 'Mariner',
        'level': 1,
        'entries': [
          'You can magically summon a spectral grasp as a bonus action to deal 1d8 cold damage.',
        ],
      });
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Oceanic Ward',
        'className': 'Warlock',
        'subclassShortName': 'Mariner',
        'level': 6,
        'entries': [
          'As a reaction when you or a nearby ally takes damage, you can reduce the damage by 2d8.',
        ],
      });

      final parser = CompendiumClassParser();
      // Notice pointer uses "The Abyssal Mariner" while registered feature uses "Mariner"
      final rawSub = {
        'name': 'The Abyssal Mariner',
        'shortName': 'Mariner',
        'className': 'Warlock',
        'source': 'CUSTOM_SRC',
        'subclassFeatures': [
          'Spectral Grasp|Warlock|SRD|The Abyssal Mariner|CUSTOM_SRC|1',
          'Oceanic Ward|Warlock|SRD|The Abyssal Mariner|CUSTOM_SRC|6',
        ],
      };

      final sub = parser.parseSubclass(rawSub);
      expect(sub.featuresMarkdown, contains('Spectral Grasp'));
      expect(sub.featuresMarkdown, contains('bonus action'));
      expect(sub.featuresMarkdown, contains('Oceanic Ward'));
      expect(sub.featuresMarkdown, contains('reaction'));

      SrdClassesLibrary.addCustomSubclass(sub);

      final stitched = SrdClassesLibrary.buildFeaturesMarkdownForSubclass(sub);
      expect(stitched, contains('Spectral Grasp'));
      expect(stitched, contains('Oceanic Ward'));
    });

    test(
        'subclass with stub markdown dynamically re-stitches and produces bonus actions and reactions',
        () {
      SrdClassesLibrary.clearCustomSubclassFeatures();
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Spectral Grasp',
        'className': 'Warlock',
        'subclassShortName': 'Mariner',
        'level': 1,
        'entries': [
          'You can magically summon a spectral grasp as a bonus action to deal 1d8 cold damage.',
        ],
      });
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Oceanic Ward',
        'className': 'Warlock',
        'subclassShortName': 'Mariner',
        'level': 6,
        'entries': [
          'As a reaction when you or an ally takes damage, you reduce the damage by 2d8.',
        ],
      });

      // Subclass that previously had only stubs (e.g. from separated batch import)
      const stubSub = Subclass(
        id: EntityId(
            slug: 'the-abyssal-mariner', ruleset: RulesetVersion.homebrew),
        name: 'The Abyssal Mariner',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown:
            '### Spectral Grasp (Level 1)\n*Mariner Subclass Feature*\n\nGranted at level 1.\n\n### Oceanic Ward (Level 6)\n*Mariner Subclass Feature*\n\nGranted at level 6.',
      );
      SrdClassesLibrary.addCustomSubclass(stubSub);

      const charLevel6 = Character(
        id: EntityId(slug: 'mariner-warlock-6', ruleset: RulesetVersion.v2014),
        name: 'Mariner Warlock',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'warlock',
                  displayName: 'Warlock'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'the-abyssal-mariner',
                displayName: 'The Abyssal Mariner',
              ),
              level: 6,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 10,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 16),
        resources: CharacterResourcePool(currentHp: 40),
      );

      final controller = CharacterSheetController(character: charLevel6);
      final stats = CharacterEvaluationEngine.evaluate(charLevel6);
      final resolved = CharacterActionsResolver.resolve(
        character: charLevel6,
        stats: stats,
        controller: controller,
      );

      final bonusActions = resolved.bonusActions;
      final reactions = resolved.reactions;

      expect(
          bonusActions
              .any((a) => a.name.toLowerCase().contains('spectral grasp')),
          isTrue,
          reason:
              'Spectral Grasp must be extracted as a Bonus Action from stitched feature data');
      expect(
          reactions.any((a) => a.name.toLowerCase().contains('oceanic ward')),
          isTrue,
          reason:
              'Oceanic Ward must be extracted as a Reaction from stitched feature data');
    });

    test(
        'works uniformly across other classes and archetypes (Druid Circle, Paladin Oath, Rogue)',
        () {
      SrdClassesLibrary.clearCustomSubclassFeatures();

      // 1. Druid archetype with "Circle of " prefix stripped in pointer/feature
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Blight Bloom',
        'className': 'Druid',
        'subclassShortName': 'Blight',
        'level': 2,
        'entries': [
          'As a bonus action, you summon toxic spores within 10 feet.',
        ],
      });

      // 2. Paladin archetype with "Oath of "
      SrdClassesLibrary.registerSubclassFeature({
        'name': 'Rebuke the Unjust',
        'className': 'Paladin',
        'subclassShortName': 'Justice',
        'level': 3,
        'entries': [
          'As a reaction when an enemy strikes an innocent, you deal 2d10 radiant damage.',
        ],
      });

      final parser = CompendiumClassParser();

      // Subclass with full name "Circle of the Blight" matching shortName "Blight"
      final druidSub = parser.parseSubclass({
        'name': 'Circle of the Blight',
        'shortName': 'Blight',
        'className': 'Druid',
        'source': 'CUSTOM_SRC',
        'subclassFeatures': [
          'Blight Bloom|Druid|SRD|Circle of the Blight|CUSTOM_SRC|2',
        ],
      });

      expect(druidSub.featuresMarkdown, contains('Blight Bloom'));
      expect(druidSub.featuresMarkdown, contains('bonus action'));

      // Subclass with full name "Oath of Justice"
      final paladinSub = parser.parseSubclass({
        'name': 'Oath of Justice',
        'shortName': 'Justice',
        'className': 'Paladin',
        'source': 'CUSTOM_SRC',
        'subclassFeatures': [
          'Rebuke the Unjust|Paladin|SRD|Oath of Justice|CUSTOM_SRC|3',
        ],
      });

      expect(paladinSub.featuresMarkdown, contains('Rebuke the Unjust'));
      expect(paladinSub.featuresMarkdown, contains('reaction'));

      SrdClassesLibrary.addCustomSubclass(druidSub);
      SrdClassesLibrary.addCustomSubclass(paladinSub);

      // Verify druid character gets the bonus action
      const druidChar = Character(
        id: EntityId(slug: 'blight-druid-2', ruleset: RulesetVersion.v2014),
        name: 'Blight Druid',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'druid',
                  displayName: 'Druid'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'circle-of-the-blight',
                displayName: 'Circle of the Blight',
              ),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 10,
            dexterity: 12,
            constitution: 14,
            intelligence: 10,
            wisdom: 16,
            charisma: 10),
        resources: CharacterResourcePool(currentHp: 16),
      );

      final druidController = CharacterSheetController(character: druidChar);
      final druidStats = CharacterEvaluationEngine.evaluate(druidChar);
      final druidResolved = CharacterActionsResolver.resolve(
        character: druidChar,
        stats: druidStats,
        controller: druidController,
      );

      expect(
          druidResolved.bonusActions
              .any((a) => a.name.toLowerCase().contains('blight bloom')),
          isTrue,
          reason: 'Druid Blight Bloom should be extracted as a Bonus Action');

      // Verify paladin character gets the reaction
      const paladinChar = Character(
        id: EntityId(slug: 'justice-paladin-3', ruleset: RulesetVersion.v2014),
        name: 'Justice Paladin',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'paladin',
                  displayName: 'Paladin'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'oath-of-justice',
                displayName: 'Oath of Justice',
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 16,
            dexterity: 10,
            constitution: 14,
            intelligence: 10,
            wisdom: 10,
            charisma: 14),
        resources: CharacterResourcePool(currentHp: 28),
      );

      final paladinController =
          CharacterSheetController(character: paladinChar);
      final paladinStats = CharacterEvaluationEngine.evaluate(paladinChar);
      final paladinResolved = CharacterActionsResolver.resolve(
        character: paladinChar,
        stats: paladinStats,
        controller: paladinController,
      );

      expect(
          paladinResolved.reactions
              .any((a) => a.name.toLowerCase().contains('rebuke the unjust')),
          isTrue,
          reason:
              'Paladin Rebuke the Unjust should be extracted as a Reaction');
    });

    test(
        'Single subclass feature JSON is parsed as generic entry, not as a full Subclass',
        () {
      final featureJson = {
        'name': 'Tentacle of the Deeps',
        'className': 'Warlock',
        'subclassShortName': 'Mariner',
        'level': 1,
        'entries': [
          'You can summon a spectral tentacle that lashes out at your command.',
        ],
      };

      final pipeline = CompendiumJsonIngestionPipeline();
      final result = pipeline.ingestJsonMap(featureJson);

      expect(result.hasErrors, isFalse);
      expect(result.subclasses, isEmpty,
          reason: 'A subclass feature MUST NOT be parsed as a full Subclass');
      expect(result.otherEntries.length, equals(1),
          reason: 'Feature should be ingested as otherEntries');
      expect(result.otherEntries.first.name, equals('Tentacle of the Deeps'));
      expect(result.otherEntries.first.category, equals('Subclass Feature'));

      // Verify the feature was registered into SrdClassesLibrary for relational lookup
      expect(
          SrdClassesLibrary.isRegisteredSubclassFeature(
              'Tentacle of the Deeps'),
          isTrue);
    });

    test(
        'SrdClassesLibrary.setCustomSubclasses filters out pseudo-subclasses that are features',
        () {
      const genuineSub = Subclass(
        id: EntityId(slug: 'warlock-mariner', ruleset: RulesetVersion.v2014),
        name: 'The Mariner',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown: '### Features\n\nGranted at level 1.',
        customProperties: {
          'subclassFeatures': [
            'The Mariner|Warlock|CUSTOM|Mariner|CUSTOM|1',
            'Tentacle of the Deeps|Warlock|CUSTOM|Mariner|CUSTOM|1',
          ],
        },
      );

      const featureAsSub = Subclass(
        id: EntityId(
            slug: 'warlock-tentacle-of-the-deeps',
            ruleset: RulesetVersion.v2014),
        name: 'Tentacle of the Deeps',
        classSlug: 'warlock',
        shortName: 'Mariner',
        featuresMarkdown: '',
        customProperties: {
          'subclassShortName': 'Mariner',
          'level': 1,
        },
      );

      SrdClassesLibrary.setCustomSubclasses([genuineSub, featureAsSub]);

      expect(SrdClassesLibrary.customSubclasses.length, equals(1));
      expect(
          SrdClassesLibrary.customSubclasses.first.name, equals('The Mariner'));
      expect(
          SrdClassesLibrary.customSubclasses
              .any((s) => s.name == 'Tentacle of the Deeps'),
          isFalse,
          reason: 'Subclass features should be excluded from customSubclasses');

      // Verify Warlock class subclasses list only has genuineSub
      final warlock = SrdClassesLibrary.findBySlug('warlock')!;
      expect(warlock.subclasses.any((s) => s.name == 'The Mariner'), isTrue);
      expect(warlock.subclasses.any((s) => s.name == 'Tentacle of the Deeps'),
          isFalse);
    });
  });
}
