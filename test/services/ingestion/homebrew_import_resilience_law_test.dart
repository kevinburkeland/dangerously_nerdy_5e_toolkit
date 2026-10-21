import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show CatalogNotInstalledError, Dnd5eRuleset;

bool _hasParsedEntity(IngestionBatchResult result) {
  return result.spells.isNotEmpty ||
      result.monsters.isNotEmpty ||
      result.items.isNotEmpty ||
      result.classes.isNotEmpty ||
      result.subclasses.isNotEmpty ||
      result.races.isNotEmpty ||
      result.feats.isNotEmpty ||
      result.backgrounds.isNotEmpty ||
      result.otherEntries.isNotEmpty ||
      result.fluff.isNotEmpty;
}

Map<String, dynamic> _makeSingleEntity(String root, dynamic malformed) {
  final base = malformed is Map<String, dynamic>
      ? malformed
      : (malformed is Map
          ? Map<String, dynamic>.from(malformed)
          : <String, dynamic>{'payload': malformed});
  switch (root) {
    case 'spell':
      return {'school': 'V', 'name': 'Probe Spell', ...base};
    case 'monster':
      return {'cr': '1', 'name': 'Probe Monster', ...base};
    case 'class':
      return {'hd': 'd8', 'name': 'Probe Class', ...base};
    case 'subclass':
      return {'subclassFeatures': [], 'name': 'Probe Subclass', ...base};
    case 'subclassfeature':
      return {'subclassFeature': true, 'name': 'Probe Subclass Feature', ...base};
    case 'classfeature':
      return {'classFeature': true, 'name': 'Probe Class Feature', ...base};
    case 'race':
      return {'size': ['M'], 'speed': 30, 'name': 'Probe Race', ...base};
    case 'feat':
      return {'prerequisite': [], 'name': 'Probe Feat', ...base};
    case 'background':
      return {'skillProficiencies': [], 'name': 'Probe Background', ...base};
    case 'item':
      return {'rarity': 'common', 'name': 'Probe Item', ...base};
    case 'custom':
    default:
      return {'name': 'Probe Custom', ...base};
  }
}

void main() {
  setUp(() {
    installRulesetCatalog();
  });

  tearDown(() {
    installRulesetCatalog();
  });

  group('Homebrew Import Resilience Law (R1 & R10)', () {
    test('fixed case: probe background with empty feats map preserves good race in bundle and reports errors on single entity', () {
      const bundleJson = '''
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
      final bundleResult = pipeline.ingestJsonString(bundleJson);

      expect(bundleResult.races.length, equals(1));
      expect(bundleResult.races.first.name, equals('Astral Elf Good'));
      expect(bundleResult.backgrounds.length, equals(0));
      expect(bundleResult.errors.length, equals(1));
      expect(bundleResult.errors.first, contains('Background error (Fz923): Bad state: No element'));

      // Single entity via string
      const singleBgJson = '''
{
  "name": "Fz923",
  "skillProficiencies": [],
  "originFeat": [{}]
}
''';
      final singleResult = pipeline.ingestJsonString(singleBgJson);
      expect(singleResult.backgrounds.length, equals(0));
      expect(singleResult.errors.length, equals(1));
      expect(singleResult.errors.first, contains('Failed to parse background'));

      // Single entity via map
      final singleMapResult = pipeline.ingestJsonMap({
        'name': 'Fz923',
        'skillProficiencies': [],
        'originFeat': [{}],
      });
      expect(singleMapResult.backgrounds.length, equals(0));
      expect(singleMapResult.errors.length, equals(1));
      expect(singleMapResult.errors.first, contains('Failed to parse background'));
    });

    test('fuzz law: 2,500 seeded malformed entities never throw and good race is always imported across bundles and single entities', () {
      final rng = Random(1337);
      final entityRoots = [
        'race',
        'spell',
        'monster',
        'class',
        'subclass',
        'subclassfeature',
        'classfeature',
        'feat',
        'background',
        'item',
        'custom',
      ];

      dynamic generateMalformed(int depth) {
        if (depth > 2) return rng.nextBool() ? 'str' : rng.nextInt(100);
        switch (rng.nextInt(11)) {
          case 0:
            return {};
          case 1:
            return [];
          case 2:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'feats': [{}]};
          case 3:
            return {
              'name': 'Broken_${rng.nextInt(1000)}',
              'additionalSpells': [
                {
                  'innate': {
                    '_': ['light#c']
                  }
                }
              ]
            };
          case 4:
            return {
              'name': 'Broken_${rng.nextInt(1000)}',
              'subraces': [{}],
              'subclasses': [{}]
            };
          case 5:
            return {'invalid': null, 'broken_list': [null, {}, []]};
          case 6:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'time': []};
          case 7:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'size': []};
          case 8:
            return {'name': 'Broken_${rng.nextInt(1000)}', 'featType': []};
          case 9:
            return {
              'name': 'Broken_${rng.nextInt(1000)}',
              'action': [
                {
                  'name': 'Bite',
                  'entries': ['*Melee Weapon Attack:* +4 to hit. *Hit:* 5 piercing damage.']
                }
              ]
            };
          case 10:
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

        // 1. Bundle ingestion
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

        final bundleResult = pipeline.ingestJsonString(jsonStr);
        expect(
          bundleResult.races.any((r) => r.name == 'Known Good Race'),
          isTrue,
          reason: 'Known good race must always be imported even alongside malformed $root at iteration $i',
        );

        // 2. Single entity ingestion via ingestJsonString
        final singleMap = _makeSingleEntity(root, malformed);
        final singleStr = jsonEncode(singleMap);

        final singleStrResult = pipeline.ingestJsonString(singleStr);
        expect(
          singleStrResult.errors.isNotEmpty || _hasParsedEntity(singleStrResult),
          isTrue,
          reason: 'Single entity $root via string must be reported (parsed or errored) at iteration $i',
        );

        // 3. Single entity ingestion via ingestJsonMap
        final singleMapResult = pipeline.ingestJsonMap(singleMap);
        expect(
          singleMapResult.errors.isNotEmpty || _hasParsedEntity(singleMapResult),
          isTrue,
          reason: 'Single entity $root via map must be reported (parsed or errored) at iteration $i',
        );
      }
    });

    test('single-entity law: uninstalled catalog surfaces CatalogNotInstalledError on catalog dependencies and never crashes', () {
      Dnd5eRuleset.resetForTesting();
      try {
        final pipeline = CompendiumJsonIngestionPipeline();

        final catalogRequiredEntities = [
          {
            'type': 'race',
            'data': {
              'name': 'Catalog Race',
              'size': ['M'],
              'speed': 30,
              'additionalSpells': [
                {
                  'innate': {
                    '_': ['light#c']
                  }
                }
              ]
            }
          },
        ];

        for (final entry in catalogRequiredEntities) {
          final type = entry['type'];
          final map = entry['data'] as Map<String, dynamic>;
          final str = jsonEncode(map);

          expect(
            () => pipeline.ingestJsonMap(map),
            throwsA(isA<CatalogNotInstalledError>()),
            reason: 'Single entity $type via map must throw CatalogNotInstalledError when catalog is uninstalled',
          );

          expect(
            () => pipeline.ingestJsonString(str),
            throwsA(isA<CatalogNotInstalledError>()),
            reason: 'Single entity $type via string must throw CatalogNotInstalledError when catalog is uninstalled',
          );
        }

        // Multi-entity bundle containing entity that reaches catalog
        final bundleMap = {
          'race': [
            {
              'name': 'Catalog Race In Bundle',
              'size': ['M'],
              'speed': 30,
              'additionalSpells': [
                {
                  'innate': {
                    '_': ['light#c']
                  }
                }
              ]
            }
          ]
        };
        expect(
          () => pipeline.ingestJsonMap(bundleMap),
          throwsA(isA<CatalogNotInstalledError>()),
          reason: 'Bundle containing race with additionalSpells must throw CatalogNotInstalledError',
        );
        expect(
          () => pipeline.ingestJsonString(jsonEncode(bundleMap)),
          throwsA(isA<CatalogNotInstalledError>()),
          reason: 'Bundle string containing race with additionalSpells must throw CatalogNotInstalledError',
        );

        // Native HomebrewBundle envelope with race having additionalSpells
        final envelopeMap = {
          'races': [
            {
              'name': 'Catalog Race In Envelope',
              'size': ['M'],
              'speed': 30,
              'additionalSpells': [
                {
                  'innate': {
                    '_': ['light#c']
                  }
                }
              ]
            }
          ]
        };
        expect(
          () => pipeline.ingestJsonMap(envelopeMap),
          throwsA(isA<CatalogNotInstalledError>()),
          reason: 'HomebrewBundle envelope with catalog dependency must throw CatalogNotInstalledError',
        );
        expect(
          () => pipeline.ingestJsonString(jsonEncode(envelopeMap)),
          throwsA(isA<CatalogNotInstalledError>()),
          reason: 'HomebrewBundle envelope string with catalog dependency must throw CatalogNotInstalledError',
        );
      } finally {
        installRulesetCatalog();
      }
    });

    test('single-entity law: StateError probes are caught and reported as errors, never escaping as unhandled errors', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final stateErrorProbes = [
        {
          'type': 'background',
          'data': {
            'name': 'Fz923',
            'skillProficiencies': [],
            'originFeat': [{}],
          }
        },
      ];

      for (final probe in stateErrorProbes) {
        final type = probe['type'];
        final map = probe['data'] as Map<String, dynamic>;
        final str = jsonEncode(map);

        final mapResult = pipeline.ingestJsonMap(map);
        expect(mapResult.errors.isNotEmpty, isTrue,
            reason: 'Probe $type via map must report error and not throw');

        final strResult = pipeline.ingestJsonString(str);
        expect(strResult.errors.isNotEmpty, isTrue,
            reason: 'Probe $type via string must report error and not throw');
      }
    });
  });
}
