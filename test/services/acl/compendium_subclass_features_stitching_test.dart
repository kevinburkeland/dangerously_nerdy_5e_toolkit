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

    test(
        'stitches external subclassFeature array into Subclass featuresMarkdown',
        () {
      const jsonCompendium = '''
{
  "subclass": [
    {
      "name": "Rift Warden",
      "className": "Fighter",
      "shortName": "Rift Warden",
      "source": "HOMEBREW",
      "subclassFeatures": [
        "Rift Warden|Fighter||Rift Warden|HOMEBREW|3",
        "Rift Step|Fighter||Rift Warden|HOMEBREW|3",
        "Rift Strike|Fighter||Rift Warden|HOMEBREW|3",
        "Spatial Beacon|Fighter||Rift Warden|HOMEBREW|7"
      ]
    }
  ],
  "subclassFeature": [
    {
      "name": "Rift Step",
      "className": "Fighter",
      "subclassShortName": "Rift Warden",
      "level": 3,
      "entries": [
        "You can use a bonus action to magically step through a tear in space to an unoccupied spot within 15 feet of you.",
        "This tear leaves a faint shimmer that dissipates immediately."
      ]
    },
    {
      "name": "Rift Strike",
      "className": "Fighter",
      "subclassShortName": "Rift Warden",
      "level": 3,
      "entries": [
        "You channel planar energy into your attacks. Whenever you take the Attack action, you can make one additional melee attack."
      ]
    },
    {
      "name": "Spatial Beacon",
      "className": "Fighter",
      "subclassShortName": "Rift Warden",
      "level": 7,
      "entries": [
        "You can temporarily project your senses through a spatial beacon for up to 10 minutes."
      ]
    }
  ]
}
''';

      final result = pipeline.ingestJsonString(jsonCompendium);
      expect(result.hasErrors, isFalse);
      expect(result.subclasses.length, equals(1));

      final riftWarden = result.subclasses.first;
      expect(riftWarden.name, equals('Rift Warden'));
      expect(riftWarden.classSlug, equals('fighter'));
      expect(riftWarden.featuresMarkdown, contains('Rift Step (Level 3)'));
      expect(riftWarden.featuresMarkdown,
          contains('bonus action to magically step through a tear'));
      expect(riftWarden.featuresMarkdown, contains('Rift Strike (Level 3)'));
      expect(riftWarden.featuresMarkdown, contains('Spatial Beacon (Level 7)'));
    });

    test('parses nested 2D array and map structures in subclassFeatures', () {
      final subclassMap = {
        'name': 'Circle of the Primal Warden',
        'className': 'Druid',
        'source': 'HOMEBREW',
        'subclassFeatures': [
          [
            {
              'name': 'Primal Wild Shape',
              'entries': [
                'You gain the ability to use Wild Shape on your turn as a bonus action.'
              ]
            },
            {
              'name': 'Apex Forms',
              'entries': [
                'The rites of your circle grant you the ability to transform into formidable beasts.'
              ]
            }
          ],
          [
            {
              'name': 'Primal Strike',
              'entries': [
                'Starting at 6th level, your natural strikes count as magical.'
              ]
            }
          ]
        ]
      };

      final sub = classParser.parseSubclass(subclassMap);
      expect(sub.name, equals('Circle of the Primal Warden'));
      expect(sub.classSlug, equals('druid'));
      expect(sub.featuresMarkdown, contains('Primal Wild Shape'));
      expect(sub.featuresMarkdown, contains('bonus action'));
      expect(sub.featuresMarkdown, contains('Apex Forms'));
      expect(sub.featuresMarkdown, contains('Primal Strike'));
      expect(
          sub.featuresMarkdown, contains('natural strikes count as magical'));
    });

    test('parses class with dynamic map subclasses list', () {
      final classMap = <dynamic, dynamic>{
        'name': 'Rogue',
        'source': 'SRD',
        'hd': {'faces': 8},
        'proficiency': ['DEX', 'INT'],
        'subclasses': <dynamic>[
          <dynamic, dynamic>{
            'name': 'Spellblade Trickster',
            'source': 'HOMEBREW',
            'desc': [
              'Some rogues enhance their fine-honed stealth with arcane tricks.',
              '### Spellcasting',
              'You gain the ability to cast spells from the arcane spell list.'
            ]
          }
        ]
      };

      final parsed =
          classParser.parseClass(Map<String, dynamic>.from(classMap));
      expect(parsed.name, equals('Rogue'));
      expect(parsed.subclasses.length, equals(1));

      final sub = parsed.subclasses.first;
      expect(sub.name, equals('Spellblade Trickster'));
      expect(sub.classSlug, equals('rogue'));
      expect(sub.featuresMarkdown, contains('stealth with arcane tricks'));
      expect(sub.featuresMarkdown, contains('Spellcasting'));
    });

    test(
        'recursively resolves nested refSubclassFeature pointers and options blocks',
        () {
      final subclassMap = {
        'name': 'Astral Champion',
        'className': 'Fighter',
        'shortName': 'Astral Champion',
        'source': 'HOMEBREW',
        'subclassFeatures': [
          'Astral Champion|Fighter||Astral Champion||3',
          'Starlight Aegis|Fighter||Astral Champion||7',
        ]
      };

      final featureMap = <String, Map<String, dynamic>>{
        'astral champion|astral champion|3': {
          'name': 'Astral Champion',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 3,
          'entries': [
            'You channel cosmic energy through your martial form.',
            {
              'type': 'refSubclassFeature',
              'subclassFeature': 'Astral Surge|Fighter||Astral Champion||3',
            },
            {
              'type': 'refSubclassFeature',
              'subclassFeature': 'Astral Alignment|Fighter||Astral Champion||3',
            },
          ]
        },
        'astral surge|astral champion|3': {
          'name': 'Astral Surge',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 3,
          'entries': [
            'Starting when you adopt this archetype at 3rd level, you can use a bonus action to empower your strikes with astral energy for 1 minute.',
          ]
        },
        'astral alignment|astral champion|3': {
          'name': 'Astral Alignment',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 3,
          'entries': [
            'At 3rd level, you choose a cosmic alignment:',
            {
              'type': 'options',
              'count': 1,
              'entries': [
                {
                  'type': 'refSubclassFeature',
                  'subclassFeature': 'Solar Aspect|Fighter||Astral Champion||3',
                },
                {
                  'type': 'refSubclassFeature',
                  'subclassFeature': 'Lunar Aspect|Fighter||Astral Champion||3',
                },
              ]
            }
          ]
        },
        'solar aspect|astral champion|3': {
          'name': 'Solar Aspect',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 3,
          'entries': [
            'While empowered, your melee weapon attacks deal an extra 1d6 radiant damage.',
          ]
        },
        'lunar aspect|astral champion|3': {
          'name': 'Lunar Aspect',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 3,
          'entries': [
            'When a creature attacks you, you can use your reaction to impose disadvantage on the attack roll.',
          ]
        },
        'starlight aegis|astral champion|7': {
          'name': 'Starlight Aegis',
          'className': 'Fighter',
          'subclassShortName': 'Astral Champion',
          'level': 7,
          'entries': [
            'Beginning at 7th level, as an action you can manifest a protective shield of starfire.',
          ]
        },
      };

      final parsed = classParser.parseSubclass(subclassMap,
          subclassFeatureMap: featureMap);

      expect(parsed.name, equals('Astral Champion'));
      expect(
          parsed.featuresMarkdown, contains('### Astral Champion (Level 3)'));
      expect(parsed.featuresMarkdown,
          contains('channel cosmic energy through your martial form'));
      expect(parsed.featuresMarkdown, contains('### Astral Surge (Level 3)'));
      expect(parsed.featuresMarkdown,
          contains('use a bonus action to empower your strikes'));
      expect(
          parsed.featuresMarkdown, contains('### Astral Alignment (Level 3)'));
      expect(parsed.featuresMarkdown, contains('Solar Aspect'));
      expect(parsed.featuresMarkdown, contains('extra 1d6 radiant damage'));
      expect(parsed.featuresMarkdown, contains('Lunar Aspect'));
      expect(parsed.featuresMarkdown,
          contains('use your reaction to impose disadvantage'));
      expect(
          parsed.featuresMarkdown, contains('### Starlight Aegis (Level 7)'));
      expect(parsed.featuresMarkdown,
          contains('as an action you can manifest a protective shield'));
    });
  });
}
