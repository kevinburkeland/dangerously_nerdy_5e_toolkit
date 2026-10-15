import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/homebrew_import_preview_dialog.dart';

void main() {
  setUp(() {
    installRulesetCatalog();
  });

  group('Worker isolate catalog ingestion (I1)', () {
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

    test('missing catalog in fresh isolate propagates as StateError and never schema error', () async {
      // In a fresh isolate without installing the catalog, pipeline must throw StateError
      final threwStateError = await Isolate.run(() {
        try {
          final pipeline = CompendiumJsonIngestionPipeline();
          pipeline.ingestJsonString(raceWithAdditionalSpellsJson);
          return false;
        } on StateError catch (e) {
          // Verify it mentions catalog
          return e.message.contains('catalog');
        } catch (_) {
          return false;
        }
      });

      expect(threwStateError, isTrue,
          reason: 'A missing catalog in a fresh isolate must surface as a StateError, never "Unrecognized compendium schema".');
    });

    test('missing catalog during single entity map parsing also surfaces as StateError', () async {
      final threwStateError = await Isolate.run(() {
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
          return false;
        } on StateError catch (e) {
          return e.message.contains('catalog');
        } catch (_) {
          return false;
        }
      });

      expect(threwStateError, isTrue);
    });
  });
}
