import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'
    show CatalogNotInstalledError;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_preview_dialog.dart';

void main() {
  setUp(() {
    installRulesetCatalog();
  });

  group('Worker isolate catalog ingestion (I1 & R1)', () {
    const raceWithAdditionalSpellsJson = '''
{
  "race": [
    {
      "name": "Astral Elf Homebrew",
      "size": ["M"],
      "speed": 30,
      "additionalSpells": [
        {
          "innate": {
            "_": ["light#c", "dancing lights#c"]
          }
        }
      ]
    }
  ]
}
''';

    test('parseHomebrewJsonInIsolate yields identical results in worker isolate vs main isolate', () async {
      // 1. Run in main isolate
      final mainResult = parseHomebrewJsonInIsolate(
        const HomebrewParseRequest(raceWithAdditionalSpellsJson, null),
      );

      // 2. Run in a fresh worker isolate via Isolate.run
      final workerResult = await Isolate.run(() {
        return parseHomebrewJsonInIsolate(
          const HomebrewParseRequest(raceWithAdditionalSpellsJson, null),
        );
      });

      // Verify parity
      expect(workerResult.errors, isEmpty);
      expect(workerResult.errors, equals(mainResult.errors));
      expect(workerResult.races.length, equals(1));
      expect(workerResult.races.length, equals(mainResult.races.length));
      expect(workerResult.races.first.name, equals('Astral Elf Homebrew'));
      expect(workerResult.races.first.grants.length, equals(mainResult.races.first.grants.length));
    });

    test('missing catalog in fresh isolate propagates as CatalogNotInstalledError and never schema error', () async {
      // In a fresh isolate without installing the catalog, pipeline must throw CatalogNotInstalledError
      final result = await Isolate.run(() {
        try {
          final pipeline = CompendiumJsonIngestionPipeline();
          pipeline.ingestJsonString(raceWithAdditionalSpellsJson);
          return 'no_error';
        } on CatalogNotInstalledError catch (e) {
          return e.message.contains('catalog') ? 'catalog_error' : 'other_catalog_error';
        } catch (e) {
          return e.runtimeType.toString();
        }
      });

      expect(result, equals('catalog_error'),
          reason: 'A missing catalog in a fresh isolate must surface as a CatalogNotInstalledError.');
    });

    test('missing catalog during single entity map parsing also surfaces as CatalogNotInstalledError', () async {
      final result = await Isolate.run(() {
        try {
          final pipeline = CompendiumJsonIngestionPipeline();
          pipeline.ingestJsonMap({
            'name': 'Astral Elf Single',
            'size': ['M'],
            'speed': 30,
            'additionalSpells': [
              {
                'innate': {
                  '_': ['light#c']
                }
              }
            ]
          });
          return 'no_error';
        } on CatalogNotInstalledError catch (e) {
          return e.message.contains('catalog') ? 'catalog_error' : 'other_catalog_error';
        } catch (e) {
          return e.runtimeType.toString();
        }
      });

      expect(result, equals('catalog_error'));
    });

    test('table-driven missing catalog behavior across entity shapes in uninstalled isolate', () async {
      const raceJson = raceWithAdditionalSpellsJson;
      const raceWithSubraceJson = '''
{
  "race": [
    {
      "name": "Base Elf Homebrew",
      "size": ["M"],
      "speed": 30,
      "subraces": [
        {
          "name": "Sub Elf Homebrew",
          "additionalSpells": [
            {
              "innate": {
                "_": ["light#c"]
              }
            }
          ]
        }
      ]
    }
  ]
}
''';
      const classWithSubclassJson = '''
{
  "class": [
    {
      "name": "Base Mage Homebrew",
      "hd": 6,
      "subclasses": [
        {
          "name": "Sub Mage Homebrew",
          "additionalSpells": [
            {
              "prepared": {
                "1": ["magic missile#c"]
              }
            }
          ]
        }
      ]
    }
  ]
}
''';

      final results = await Isolate.run(() {
        final pipeline = CompendiumJsonIngestionPipeline();

        String testShape(void Function() fn) {
          try {
            fn();
            return 'completed_without_throwing';
          } on CatalogNotInstalledError {
            return 'threw_CatalogNotInstalledError';
          } catch (e) {
            return 'threw_${e.runtimeType}';
          }
        }

        return {
          'race_additionalSpells_string': testShape(() => pipeline.ingestJsonString(raceJson)),
          'race_additionalSpells_map': testShape(() => pipeline.ingestJsonMap({
                'name': 'Astral Elf Single',
                'size': ['M'],
                'speed': 30,
                'additionalSpells': [
                  {
                    'innate': {
                      '_': ['light#c']
                    }
                  }
                ]
              })),
          'subrace_additionalSpells': testShape(() => pipeline.ingestJsonString(raceWithSubraceJson)),
          'subclass_additionalSpells': testShape(() => pipeline.ingestJsonString(classWithSubclassJson)),
        };
      });

      // 1. Race with additionalSpells throws CatalogNotInstalledError
      expect(results['race_additionalSpells_string'], equals('threw_CatalogNotInstalledError'));
      // 2. Race via ingestJsonMap throws CatalogNotInstalledError
      expect(results['race_additionalSpells_map'], equals('threw_CatalogNotInstalledError'));
      // 3. Subrace with additionalSpells throws CatalogNotInstalledError
      expect(results['subrace_additionalSpells'], equals('threw_CatalogNotInstalledError'));
      // 4. Subclass with additionalSpells does NOT reach catalog (uses pure string-based extractSpellsGrants)
      expect(results['subclass_additionalSpells'], equals('completed_without_throwing'));
    });
  });
}
