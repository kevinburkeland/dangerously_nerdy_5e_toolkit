import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  setUp(() {
    installRulesetCatalog();
  });

  group('Homebrew Import Resilience Law (R1)', () {
    test('fixed case: probe background with empty feats map preserves good race', () {
      const json = '''
{
  "race": [
    {
      "name": "Astral Elf Good",
      "size": ["M"],
      "speed": 30
    }
  ],
  "background": [
    {
      "name": "Fz923",
      "feats": [{}]
    }
  ]
}
''';

      final pipeline = CompendiumJsonIngestionPipeline();
      final result = pipeline.ingestJsonString(json);

      expect(result.races.length, equals(1));
      expect(result.races.first.name, equals('Astral Elf Good'));
      expect(result.backgrounds.length, equals(0));
      expect(result.errors.length, equals(1));
      expect(result.errors.first, contains('Background error (Fz923): Bad state: No element'));
    });

    test('fuzz law: 2,500 seeded malformed entities never throw and good race is always imported', () {
      final rng = Random(1337);
      final entityRoots = [
        'race',
        'spell',
        'monster',
        'class',
        'subclass',
        'feat',
        'background',
        'item',
      ];

      dynamic generateMalformed(int depth) {
        if (depth > 2) return rng.nextBool() ? 'str' : rng.nextInt(100);
        switch (rng.nextInt(7)) {
          case 0:
            return {};
          case 1:
            return [];
          case 2:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'feats': [{}]};
          case 3:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'additionalSpells': []};
          case 4:
            return {
              'name': 'Broken_${rng.nextInt(1000)}',
              'subraces': [{}],
              'subclasses': [{}]
            };
          case 5:
            return {'invalid': null, 'broken_list': [null, {}, []]};
          case 6:
          default:
            return {
              for (var i = 0; i < rng.nextInt(4); i++)
                'key_${rng.nextInt(10)}': generateMalformed(depth + 1)
            };
        }
      }

      const totalInputs = 2500;
      final pipeline = CompendiumJsonIngestionPipeline();

      for (int i = 0; i < totalInputs; i++) {
        final root = entityRoots[rng.nextInt(entityRoots.length)];
        final malformed = generateMalformed(0);
        final jsonMap = <String, dynamic>{
          'race': [
            {
              'name': 'Known Good Race',
              'size': ['M'],
              'speed': 30,
            },
            if (root == 'race') malformed,
          ],
          if (root != 'race') root: [malformed],
        };
        final jsonStr = jsonEncode(jsonMap);

        final result = pipeline.ingestJsonString(jsonStr);
        expect(
          result.races.any((r) => r.name == 'Known Good Race'),
          isTrue,
          reason: 'Known good race must always be imported even alongside malformed $root at iteration $i',
        );
      }
    });
  });
}
