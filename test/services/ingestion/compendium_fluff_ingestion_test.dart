import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Compendium Fluff Ingestion Pipeline Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      EntityFluffService().clearAll();
      await EntityFluffService().init();
    });

    test('ingests monsterFluff bundle and additively attaches lore to SRD creatures', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final fluffJson = {
        'monsterFluff': [
          {
            'name': 'Aboleth',
            'source': 'MM',
            'entries': [
              'Before the coming of the gods, aboleths lurked in primordial oceans.',
              'They possess eternal memories passed down through generations.',
            ],
            'images': [
              {
                'type': 'image',
                'href': {'type': 'internal', 'path': 'bestiary/MM/Aboleth.webp'}
              }
            ]
          },
          {
            'name': 'Adult Red Dragon',
            'source': 'MM',
            'entries': [
              'The most covetous of the true dragons, red dragons tirelessly seek to increase their hoards.',
            ]
          }
        ]
      };

      final result = pipeline.ingestJsonMap(fluffJson);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(2));

      final abolethFluff = EntityFluffService().getFluff('monster', 'aboleth');
      expect(abolethFluff, isNotNull);
      expect(abolethFluff!.loreMarkdown, contains('Before the coming of the gods'));
      expect(abolethFluff.loreMarkdown, contains('eternal memories'));
      expect(abolethFluff.images, contains('bestiary/MM/Aboleth.webp'));

      final dragonFluff = EntityFluffService().getFluff('monster', 'adult-red-dragon');
      expect(dragonFluff, isNotNull);
      expect(dragonFluff!.loreMarkdown, contains('most covetous of the true dragons'));
    });

    test('ingests spellFluff and itemFluff bundles seamlessly', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final bundleJson = {
        'spellFluff': [
          {
            'name': 'Fireball',
            'source': 'PHB',
            'entries': [
              'A bright streak flashes from your pointing finger to a destination you choose.',
            ]
          }
        ],
        'itemFluff': [
          {
            'name': 'Bag of Holding',
            'source': 'DMG',
            'entries': [
              'This bag has an interior space considerably larger than its outside dimensions.',
            ]
          }
        ]
      };

      final result = pipeline.ingestJsonMap(bundleJson);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(2));

      final fireballFluff = EntityFluffService().getFluff('spell', 'fireball');
      expect(fireballFluff, isNotNull);
      expect(fireballFluff!.loreMarkdown, contains('bright streak flashes'));

      final bagFluff = EntityFluffService().getFluff('item', 'bag-of-holding');
      expect(bagFluff, isNotNull);
      expect(bagFluff!.loreMarkdown, contains('interior space considerably larger'));
    });

    test('ingests single-entity fluff payload', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final singleFluff = {
        'name': 'Elf',
        'source': 'PHB',
        '_fluff': true,
        'fluffType': 'race',
        'entries': [
          'Elves are a magical people of otherworldly grace, living in places of ethereal beauty.',
        ]
      };

      final result = pipeline.ingestJsonMap(singleFluff);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(1));

      final elfFluff = EntityFluffService().getFluff('race', 'elf');
      expect(elfFluff, isNotNull);
      expect(elfFluff!.loreMarkdown, contains('magical people of otherworldly grace'));
    });
  });
}
