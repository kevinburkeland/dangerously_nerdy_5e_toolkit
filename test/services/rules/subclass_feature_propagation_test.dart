import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_importer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_homebrew_validator.dart';

void main() {
  setUp(() {
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
  });

  tearDown(() {
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
  });

  group('SrdClassesLibrary.findSubclass & Subclass Pool Tests', () {
    test('resolves core SRD subclass by slug and stripped slug', () {
      final sub =
          SrdClassesLibrary.findSubclass('champion', classSlug: 'fighter');
      expect(sub, isNotNull);
      expect(sub!.name.toLowerCase(), contains('champion'));

      final subWithPrefix = SrdClassesLibrary.findSubclass('fighter-champion');
      expect(subWithPrefix, isNotNull);
      expect(subWithPrefix!.name.toLowerCase(), contains('champion'));
    });

    test(
        'resolves custom homebrew subclass across prefix variations and underscores',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'fighter-rift-warden', ruleset: RulesetVersion.homebrew),
        name: 'Rift Warden',
        classSlug: 'fighter',
        shortName: 'Rift Warden',
        featuresMarkdown:
            '### Rift Step (Level 3)\nYou can step through a planar rift.',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      // Match with prefix
      expect(SrdClassesLibrary.findSubclass('fighter-rift-warden'), isNotNull);
      // Match without prefix
      expect(SrdClassesLibrary.findSubclass('rift-warden'), isNotNull);
      // Match with underscores
      expect(SrdClassesLibrary.findSubclass('rift_warden'), isNotNull);
      // Match with spaces
      expect(SrdClassesLibrary.findSubclass('rift warden'), isNotNull);
      // Match by displayName
      expect(
          SrdClassesLibrary.findSubclass('unknown-slug',
              displayName: 'Rift Warden'),
          isNotNull);
    });

    test(
        'retains standalone custom subclasses in allSubclasses even if unlinked to class',
        () {
      const standaloneSub = Subclass(
        id: EntityId(
            slug: 'warden-alchemist', ruleset: RulesetVersion.homebrew),
        name: 'Order of the Alchemist',
        classSlug: 'warden',
        featuresMarkdown:
            '### Transmutation Craft (Level 3)\nYou craft elixirs.',
      );
      SrdClassesLibrary.addCustomSubclass(standaloneSub);

      expect(
          SrdClassesLibrary.allSubclasses
              .any((s) => s.id.slug == 'warden-alchemist'),
          isTrue);
      expect(
          SrdClassesLibrary.findSubclass('order-of-the-alchemist'), isNotNull);
      expect(SrdClassesLibrary.findSubclass('alchemist', classSlug: 'warden'),
          isNotNull);
    });
  });

  group('CompendiumClassParser & Ingestion Feature Resolution', () {
    test('parses subclass with inline feature maps maintaining level headers',
        () {
      final parser = CompendiumClassParser();
      final json = {
        'name': 'Astral Striker',
        'className': 'Fighter',
        'source': 'HOMEBREW',
        'subclassFeatures': [
          {
            'name': 'Astral Strike',
            'level': 3,
            'entries': ['Infuse attacks with astral force.']
          },
          {
            'name': 'Planar Step',
            'level': 7,
            'entries': ['Teleport up to 30 feet as a bonus action.']
          }
        ]
      };

      final sub = parser.parseSubclass(json);
      expect(sub.name, equals('Astral Striker'));
      expect(sub.featuresMarkdown, contains('### Astral Strike (Level 3)'));
      expect(
          sub.featuresMarkdown, contains('Infuse attacks with astral force.'));
      expect(sub.featuresMarkdown, contains('### Planar Step (Level 7)'));
      expect(sub.featuresMarkdown, contains('Teleport up to 30 feet'));
    });

    test(
        'resolves compendium pointer strings against subclassFeatureMap and creates fallback if missing',
        () {
      final parser = CompendiumClassParser();
      final featureMap = <String, Map<String, dynamic>>{
        'rift step|fighter|rift warden|3': {
          'name': 'Rift Step',
          'level': 3,
          'entries': ['Call forth a planar rift across space.']
        }
      };

      final jsonWithFeature = {
        'name': 'Rift Warden',
        'className': 'Fighter',
        'source': 'HOMEBREW',
        'subclassFeatures': [
          'Rift Step|Fighter|HOMEBREW|Rift Warden|HOMEBREW|3',
          'Spatial Beacon|Fighter|HOMEBREW|Rift Warden|HOMEBREW|7' // Missing from featureMap -> fallback block
        ]
      };

      final sub =
          parser.parseSubclass(jsonWithFeature, subclassFeatureMap: featureMap);
      expect(sub.featuresMarkdown, contains('### Rift Step (Level 3)'));
      expect(sub.featuresMarkdown,
          contains('Call forth a planar rift across space.'));
      expect(sub.featuresMarkdown, contains('### Spatial Beacon (Level 7)'));
      expect(sub.featuresMarkdown, contains('*Rift Warden Feature*'));
    });

    test('CompendiumJsonIngestionPipeline stitches external subclass features',
        () {
      final pipeline = CompendiumJsonIngestionPipeline();
      final bundle = {
        'subclass': [
          {
            'name': 'Chrono Blade',
            'className': 'Fighter',
            'shortName': 'Chrono Blade',
            'source': 'HOMEBREW'
          }
        ],
        'subclassFeature': [
          {
            'name': 'Temporal Shift',
            'className': 'Fighter',
            'subclassShortName': 'Chrono Blade',
            'level': 3,
            'entries': ['Alter the flow of time around you.']
          },
          {
            'name': 'Time Stride',
            'className': 'Fighter',
            'subclassShortName': 'Chrono Blade',
            'level': 7,
            'entries': ['Step through brief moments in time.']
          }
        ]
      };

      final result = pipeline.ingestJsonMap(bundle);
      expect(result.subclasses.length, equals(1));
      final sub = result.subclasses.first;
      expect(sub.featuresMarkdown, contains('Temporal Shift'));
      expect(sub.featuresMarkdown, contains('Time Stride'));
    });
  });

  group('Character Sheet Subclass Feature Propagation & Validation', () {
    test(
        'CharacterHomebrewValidator does not report installed homebrew subclass as missing with prefix difference',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'fighter-rift-warden', ruleset: RulesetVersion.homebrew),
        name: 'Rift Warden',
        classSlug: 'fighter',
        featuresMarkdown: '### Rift Step (Level 3)\nRift step feature.',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      const character = Character(
        id: EntityId(slug: 'test-fighter', ruleset: RulesetVersion.homebrew),
        name: 'Test Fighter',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'fighter',
                  displayName: 'Fighter'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'rift-warden', // without class prefix
                displayName: 'Rift Warden',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 28),
      );

      final report = CharacterHomebrewValidator.validate(character);
      expect(
          report.missingItems
              .any((m) => m.type == HomebrewEntityType.subclassType),
          isFalse);
    });

    test(
        'AbilitiesAndTraitsTab resolves and displays subclass features matching character level',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'fighter-rift-warden', ruleset: RulesetVersion.homebrew),
        name: 'Rift Warden',
        classSlug: 'fighter',
        featuresMarkdown: '''
### Rift Step (3rd Level)
You can use a bonus action to magically step through a planar rift.

#### Spatial Beacon (Level 7)
You can anchor a spatial beacon in space.

**Void Shield (10th Level):**
You can absorb ambient dimensional force to regain vitality.
''',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      final sub =
          SrdClassesLibrary.findSubclass('rift-warden', classSlug: 'fighter');
      expect(sub, isNotNull);
      expect(sub!.featuresMarkdown, contains('Rift Step'));
      expect(sub.featuresMarkdown, contains('Spatial Beacon'));
      expect(sub.featuresMarkdown, contains('Void Shield'));
    });

    test(
        'CommunityCompendiumImporterService preserves subclass feature rules text from external feature map',
        () async {
      final service = CommunityCompendiumImporterService(
          adapters: CommunityCompendiumAdapters());
      final payload = {
        'subclass': [
          {
            'name': 'Void Warden',
            'className': 'Fighter',
            'shortName': 'Void Warden',
            'source': 'Homebrew',
            'subclassFeatures': [
              'Void Step|Fighter|Homebrew|Void Warden|Homebrew|3',
              'Shadow Barrier|Fighter|Homebrew|Void Warden|Homebrew|3',
            ],
          }
        ],
        'subclassFeature': [
          {
            'name': 'Void Step',
            'className': 'Fighter',
            'subclassShortName': 'Void Warden',
            'level': 3,
            'source': 'Homebrew',
            'entries': [
              'You can use a bonus action to magically teleport up to 30 feet to an unoccupied space you can see.',
            ],
          },
          {
            'name': 'Shadow Barrier',
            'className': 'Fighter',
            'subclassShortName': 'Void Warden',
            'level': 3,
            'source': 'Homebrew',
            'entries': [
              'When an attacker hits you with an attack, you can use your reaction to halve the attack damage against you.',
            ],
          }
        ],
      };

      final result = await service.importJsonString(json.encode(payload),
          persistAndSync: false);
      expect(result.subclasses, hasLength(1));
      final importedSub = result.subclasses.first;
      expect(importedSub.name, equals('Void Warden'));
      expect(importedSub.featuresMarkdown, contains('### Void Step (Level 3)'));
      expect(importedSub.featuresMarkdown,
          contains('You can use a bonus action to magically teleport'));
      expect(importedSub.featuresMarkdown,
          contains('### Shadow Barrier (Level 3)'));
      expect(importedSub.featuresMarkdown,
          contains('you can use your reaction to halve the attack damage'));
      expect(
          importedSub.featuresMarkdown, isNot(contains('Granted at level 3.')));
    });

    test(
        'CharacterActionsResolver extracts Action, Bonus Action, and Reaction from subclass features markdown',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'fighter-void-warden', ruleset: RulesetVersion.homebrew),
        name: 'Void Warden',
        classSlug: 'fighter',
        shortName: 'Void Warden',
        featuresMarkdown: '''
### Void Step (Level 3)
You can use a bonus action to magically teleport up to 30 feet to an unoccupied space.

### Shadow Barrier (Level 3)
When an attacker hits you with an attack, you can use your reaction to deflect the attack.

### Void Blast (Level 3)
As an action, you unleash spatial distortion dealing 2d8 force damage to all nearby creatures.
''',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      const character = Character(
        id: EntityId(slug: 'test-char', ruleset: RulesetVersion.homebrew),
        name: 'Void Warrior',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'fighter',
                  displayName: 'Fighter'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'void-warden',
                displayName: 'Void Warden',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
            strength: 16,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 8),
        resources: CharacterResourcePool(currentHp: 28),
      );

      final controller = CharacterSheetController(character: character);
      final stats = CharacterEvaluationEngine.evaluate(character);
      final resolved = CharacterActionsResolver.resolve(
        character: character,
        stats: stats,
        controller: controller,
      );

      final bonusActions = resolved.bonusActions.map((a) => a.name).toList();
      final reactions = resolved.reactions.map((a) => a.name).toList();
      final actions = resolved.actions.map((a) => a.name).toList();

      expect(bonusActions, contains('Void Step'));
      expect(reactions, contains('Shadow Barrier'));
      expect(actions, contains('Void Blast'));

      final voidBlastAction =
          resolved.actions.firstWhere((a) => a.name == 'Void Blast');
      expect(voidBlastAction.damageFormula, equals('2d8'));
      expect(voidBlastAction.damageType, equals(DamageType.force));
      expect(voidBlastAction.description,
          contains('As an action, you unleash spatial distortion'));
    });

    test(
        'CharacterActionsResolver extracts bold sub-actions inside a single header block',
        () {
      const customSub = Subclass(
        id: EntityId(
            slug: 'fighter-astral-knight', ruleset: RulesetVersion.homebrew),
        name: 'Astral Knight',
        classSlug: 'fighter',
        shortName: 'Astral Knight',
        featuresMarkdown: '''
### Astral Knight Specializations (Level 3)
*Astral Knight Feature*

**Astral Jaunt.** You can use a bonus action to shift ethereal planes.
**Starlight Aegis.** In response to taking damage, you can use your reaction to gain 10 temporary hit points.
''',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      const character = Character(
        id: EntityId(
            slug: 'test-astral-char', ruleset: RulesetVersion.homebrew),
        name: 'Astral Sentinel',
        speciesRef: EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'fighter',
                  displayName: 'Fighter'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'astral-knight',
                displayName: 'Astral Knight',
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 28),
      );

      final controller = CharacterSheetController(character: character);
      final stats = CharacterEvaluationEngine.evaluate(character);
      final resolved = CharacterActionsResolver.resolve(
        character: character,
        stats: stats,
        controller: controller,
      );

      final bonusActions = resolved.bonusActions.map((a) => a.name).toList();
      final reactions = resolved.reactions.map((a) => a.name).toList();

      expect(bonusActions, contains('Astral Jaunt'));
      expect(reactions, contains('Starlight Aegis'));
    });

    test(
        'CharacterActionsResolver resolves actions from stitched subclass features with nested references',
        () {
      final parser = CompendiumClassParser();
      final subclassMap = {
        'name': 'Solar Vanguard',
        'className': 'Fighter',
        'shortName': 'Solar Vanguard',
        'source': 'HOMEBREW',
        'subclassFeatures': [
          'Solar Vanguard|Fighter||Solar Vanguard||3',
          'Solar Flare|Fighter||Solar Vanguard||3',
          'Dawn Ward|Fighter||Solar Vanguard||3',
        ]
      };

      final featureMap = <String, Map<String, dynamic>>{
        'solar vanguard|solar vanguard|3': {
          'name': 'Solar Vanguard',
          'className': 'Fighter',
          'subclassShortName': 'Solar Vanguard',
          'level': 3,
          'entries': [
            'Warriors who channel the enduring light of the dawn.',
            {
              'type': 'refSubclassFeature',
              'subclassFeature': 'Solar Surge|Fighter||Solar Vanguard||3',
            },
          ]
        },
        'solar surge|solar vanguard|3': {
          'name': 'Solar Surge',
          'className': 'Fighter',
          'subclassShortName': 'Solar Vanguard',
          'level': 3,
          'entries': [
            'Starting at 3rd level, you can use a bonus action to infuse your strikes with blazing solar fury.',
          ]
        },
        'solar flare|solar vanguard|3': {
          'name': 'Solar Flare',
          'className': 'Fighter',
          'subclassShortName': 'Solar Vanguard',
          'level': 3,
          'entries': [
            'As an action, you release a burst of daylight dealing 2d6 radiant damage to hostile creatures.',
          ]
        },
        'dawn ward|solar vanguard|3': {
          'name': 'Dawn Ward',
          'className': 'Fighter',
          'subclassShortName': 'Solar Vanguard',
          'level': 3,
          'entries': [
            'When a creature hits you with a melee attack, you can use your reaction to interpose a shield of dawnlight.',
          ]
        },
      };

      final customSub =
          parser.parseSubclass(subclassMap, subclassFeatureMap: featureMap);
      SrdClassesLibrary.addCustomSubclass(customSub);

      final character = Character(
        id: const EntityId(
            slug: 'test-solar-char', ruleset: RulesetVersion.homebrew),
        name: 'Solar Champion',
        speciesRef: const EntityReference(
            refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: const EntityReference(
                  refType: EntityType.classDefinition,
                  slug: 'fighter',
                  displayName: 'Fighter'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: customSub.id.slug,
                displayName: customSub.name,
                rulesetPreferred: RulesetVersion.homebrew,
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores.standardArray(),
        resources: const CharacterResourcePool(currentHp: 28),
      );

      final controller = CharacterSheetController(character: character);
      final stats = CharacterEvaluationEngine.evaluate(character);
      final resolved = CharacterActionsResolver.resolve(
        character: character,
        stats: stats,
        controller: controller,
      );

      final bonusActions = resolved.bonusActions.map((a) => a.name).toList();
      final actions = resolved.actions.map((a) => a.name).toList();
      final reactions = resolved.reactions.map((a) => a.name).toList();

      expect(bonusActions, contains('Solar Surge'));
      expect(actions, contains('Solar Flare'));
      expect(reactions, contains('Dawn Ward'));
    });
  });
}
