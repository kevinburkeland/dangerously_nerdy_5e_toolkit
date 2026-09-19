import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
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
      final sub = SrdClassesLibrary.findSubclass('champion', classSlug: 'fighter');
      expect(sub, isNotNull);
      expect(sub!.name.toLowerCase(), contains('champion'));

      final subWithPrefix = SrdClassesLibrary.findSubclass('fighter-champion');
      expect(subWithPrefix, isNotNull);
      expect(subWithPrefix!.name.toLowerCase(), contains('champion'));
    });

    test('resolves custom homebrew subclass across prefix variations and underscores', () {
      const customSub = Subclass(
        id: EntityId(slug: 'fighter-echo-knight', ruleset: RulesetVersion.homebrew),
        name: 'Echo Knight',
        classSlug: 'fighter',
        shortName: 'Echo Knight',
        featuresMarkdown: '### Manifest Echo (Level 3)\nYou can manifest an echo of your desires.',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      // Match with prefix
      expect(SrdClassesLibrary.findSubclass('fighter-echo-knight'), isNotNull);
      // Match without prefix
      expect(SrdClassesLibrary.findSubclass('echo-knight'), isNotNull);
      // Match with underscores
      expect(SrdClassesLibrary.findSubclass('echo_knight'), isNotNull);
      // Match with spaces
      expect(SrdClassesLibrary.findSubclass('echo knight'), isNotNull);
      // Match by displayName
      expect(SrdClassesLibrary.findSubclass('unknown-slug', displayName: 'Echo Knight'), isNotNull);
    });

    test('retains standalone custom subclasses in allSubclasses even if unlinked to class', () {
      const standaloneSub = Subclass(
        id: EntityId(slug: 'blood-hunter-mutant', ruleset: RulesetVersion.homebrew),
        name: 'Order of the Mutant',
        classSlug: 'blood-hunter',
        featuresMarkdown: '### Mutagenecraft (Level 3)\nYou craft mutagens.',
      );
      SrdClassesLibrary.addCustomSubclass(standaloneSub);

      expect(SrdClassesLibrary.allSubclasses.any((s) => s.id.slug == 'blood-hunter-mutant'), isTrue);
      expect(SrdClassesLibrary.findSubclass('order-of-the-mutant'), isNotNull);
      expect(SrdClassesLibrary.findSubclass('mutant', classSlug: 'blood-hunter'), isNotNull);
    });
  });

  group('CompendiumClassParser & Ingestion Feature Resolution', () {
    test('parses subclass with inline feature maps maintaining level headers', () {
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
      expect(sub.featuresMarkdown, contains('Infuse attacks with astral force.'));
      expect(sub.featuresMarkdown, contains('### Planar Step (Level 7)'));
      expect(sub.featuresMarkdown, contains('Teleport up to 30 feet'));
    });

    test('resolves 5etools pointer strings against subclassFeatureMap and creates fallback if missing', () {
      final parser = CompendiumClassParser();
      final featureMap = <String, Map<String, dynamic>>{
        'manifest echo|fighter|echo knight|3': {
          'name': 'Manifest Echo',
          'level': 3,
          'entries': ['Call forth an echo of your unrealized timelines.']
        }
      };

      final jsonWithFeature = {
        'name': 'Echo Knight',
        'className': 'Fighter',
        'source': 'EGW',
        'subclassFeatures': [
          'Manifest Echo|Fighter|EGW|Echo Knight|EGW|3',
          'Echo Avatar|Fighter|EGW|Echo Knight|EGW|7' // Missing from featureMap -> fallback block
        ]
      };

      final sub = parser.parseSubclass(jsonWithFeature, subclassFeatureMap: featureMap);
      expect(sub.featuresMarkdown, contains('### Manifest Echo (Level 3)'));
      expect(sub.featuresMarkdown, contains('Call forth an echo of your unrealized timelines.'));
      expect(sub.featuresMarkdown, contains('### Echo Avatar (Level 7)'));
      expect(sub.featuresMarkdown, contains('*Echo Knight Feature*'));
    });

    test('CompendiumJsonIngestionPipeline stitches external subclass features', () {
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
    test('CharacterHomebrewValidator does not report installed homebrew subclass as missing with prefix difference', () {
      const customSub = Subclass(
        id: EntityId(slug: 'fighter-echo-knight', ruleset: RulesetVersion.homebrew),
        name: 'Echo Knight',
        classSlug: 'fighter',
        featuresMarkdown: '### Manifest Echo (Level 3)\nEcho feature.',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      const character = Character(
        id: EntityId(slug: 'test-fighter', ruleset: RulesetVersion.homebrew),
        name: 'Test Fighter',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              subclassRef: EntityReference(
                refType: EntityType.subclass,
                slug: 'echo-knight', // without class prefix
                displayName: 'Echo Knight',
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
      expect(report.missingItems.any((m) => m.type == HomebrewEntityType.subclassType), isFalse);
    });

    test('AbilitiesAndTraitsTab resolves and displays subclass features matching character level', () {
      const customSub = Subclass(
        id: EntityId(slug: 'fighter-echo-knight', ruleset: RulesetVersion.homebrew),
        name: 'Echo Knight',
        classSlug: 'fighter',
        featuresMarkdown: '''
### Manifest Echo (3rd Level)
You can use a bonus action to magically manifest an echo of yourself.

#### Shadow Martyr (Level 7)
You can make your echo throw itself in front of an attack.

**Reclaim Potential (10th Level):**
You can absorb the ephemeral energy of your echo to regain hit points.
''',
      );
      SrdClassesLibrary.addCustomSubclass(customSub);

      final sub = SrdClassesLibrary.findSubclass('echo-knight', classSlug: 'fighter');
      expect(sub, isNotNull);
      expect(sub!.featuresMarkdown, contains('Manifest Echo'));
      expect(sub.featuresMarkdown, contains('Shadow Martyr'));
      expect(sub.featuresMarkdown, contains('Reclaim Potential'));
    });
  });
}
