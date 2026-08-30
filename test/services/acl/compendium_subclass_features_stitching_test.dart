import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';

void main() {
  group('Compendium Subclass Features Extraction & Stitching Tests', () {
    late CompendiumJsonIngestionPipeline pipeline;
    late CompendiumClassParser classParser;

    setUp(() {
      pipeline = CompendiumJsonIngestionPipeline();
      classParser = CompendiumClassParser();
    });

    test('stitches external subclassFeature array into Subclass featuresMarkdown', () {
      const jsonCompendium = '''
{
  "subclass": [
    {
      "name": "Echo Knight",
      "className": "Fighter",
      "shortName": "Echo Knight",
      "source": "EGtW",
      "subclassFeatures": [
        "Echo Knight|Fighter||Echo Knight|EGtW|3",
        "Manifest Echo|Fighter||Echo Knight|EGtW|3",
        "Unleash Incarnation|Fighter||Echo Knight|EGtW|3",
        "Echo Avatar|Fighter||Echo Knight|EGtW|7"
      ]
    }
  ],
  "subclassFeature": [
    {
      "name": "Manifest Echo",
      "className": "Fighter",
      "subclassShortName": "Echo Knight",
      "level": 3,
      "entries": [
        "You can use a bonus action to magically manifest an echo of yourself in an unoccupied space you can see within 15 feet of you.",
        "This echo is a translucent, gray figure of you that lasts until it is destroyed."
      ]
    },
    {
      "name": "Unleash Incarnation",
      "className": "Fighter",
      "subclassShortName": "Echo Knight",
      "level": 3,
      "entries": [
        "You can heighten your echo's fury. Whenever you take the Attack action, you can make one additional melee attack."
      ]
    },
    {
      "name": "Echo Avatar",
      "className": "Fighter",
      "subclassShortName": "Echo Knight",
      "level": 7,
      "entries": [
        "You can temporarily transfer your consciousness to your echo for up to 10 minutes."
      ]
    }
  ]
}
''';

      final result = pipeline.ingestJsonString(jsonCompendium);
      expect(result.hasErrors, isFalse);
      expect(result.subclasses.length, equals(1));

      final echoKnight = result.subclasses.first;
      expect(echoKnight.name, equals('Echo Knight'));
      expect(echoKnight.classSlug, equals('fighter'));
      expect(echoKnight.featuresMarkdown, contains('Manifest Echo (Level 3)'));
      expect(echoKnight.featuresMarkdown, contains('bonus action to magically manifest an echo'));
      expect(echoKnight.featuresMarkdown, contains('Unleash Incarnation (Level 3)'));
      expect(echoKnight.featuresMarkdown, contains('Echo Avatar (Level 7)'));
    });

    test('parses nested 2D array and map structures in subclassFeatures', () {
      final subclassMap = {
        'name': 'Circle of the Moon',
        'className': 'Druid',
        'source': 'PHB',
        'subclassFeatures': [
          [
            {
              'name': 'Combat Wild Shape',
              'entries': [
                'You gain the ability to use Wild Shape on your turn as a bonus action.'
              ]
            },
            {
              'name': 'Circle Forms',
              'entries': [
                'The rites of your circle grant you the ability to transform into more dangerous animal forms.'
              ]
            }
          ],
          [
            {
              'name': 'Primal Strike',
              'entries': [
                'Starting at 6th level, your attacks in beast form count as magical.'
              ]
            }
          ]
        ]
      };

      final sub = classParser.parseSubclass(subclassMap);
      expect(sub.name, equals('Circle of the Moon'));
      expect(sub.classSlug, equals('druid'));
      expect(sub.featuresMarkdown, contains('Combat Wild Shape'));
      expect(sub.featuresMarkdown, contains('bonus action'));
      expect(sub.featuresMarkdown, contains('Circle Forms'));
      expect(sub.featuresMarkdown, contains('Primal Strike'));
      expect(sub.featuresMarkdown, contains('beast form count as magical'));
    });

    test('parses class with dynamic map subclasses list', () {
      final classMap = <dynamic, dynamic>{
        'name': 'Rogue',
        'source': 'PHB',
        'hd': {'faces': 8},
        'proficiency': ['DEX', 'INT'],
        'subclasses': <dynamic>[
          <dynamic, dynamic>{
            'name': 'Arcane Trickster',
            'source': 'PHB',
            'desc': [
              'Some rogues enhance their fine-honed skills of stealth and agility with magic.',
              '### Spellcasting',
              'You gain the ability to cast spells from the wizard spell list.'
            ]
          }
        ]
      };

      final parsed = classParser.parseClass(Map<String, dynamic>.from(classMap));
      expect(parsed.name, equals('Rogue'));
      expect(parsed.subclasses.length, equals(1));

      final sub = parsed.subclasses.first;
      expect(sub.name, equals('Arcane Trickster'));
      expect(sub.classSlug, equals('rogue'));
      expect(sub.featuresMarkdown, contains('stealth and agility with magic'));
      expect(sub.featuresMarkdown, contains('Spellcasting'));
    });
  });
}
