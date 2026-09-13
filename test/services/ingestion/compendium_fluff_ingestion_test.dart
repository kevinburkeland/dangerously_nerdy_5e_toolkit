import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/models/homebrew_entity.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_bundle.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

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

    test('ingests single-entity fluff payload with artificial flags', () {
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

    test('ingests authentic community compendium single fluff without artificial flags', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final authenticSingle = {
        'name': 'Aarakocra',
        'source': 'MM',
        'entries': [
          'Aarakocra range the Howling Gyre, an endless storm of elemental air.',
        ],
        'images': [
          {
            'type': 'image',
            'href': {
              'type': 'internal',
              'path': 'bestiary/MM/Aarakocra.webp',
            }
          }
        ]
      };

      final result = pipeline.ingestJsonMap(authenticSingle);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(1));

      final aarakocraFluff = EntityFluffService().getFluff('monster', 'aarakocra');
      expect(aarakocraFluff, isNotNull);
      expect(aarakocraFluff!.loreMarkdown, contains('Howling Gyre'));
      expect(aarakocraFluff.images, contains('bestiary/MM/Aarakocra.webp'));
    });

    test('ingests subclassFluff alongside classFluff from class fluff bundles', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final classBundle = {
        'classFluff': [
          {
            'name': 'Artificer',
            'source': 'TCE',
            'entries': [
              'Masters of invention, artificers use ingenuity and magic to unlock extraordinary capabilities in objects.',
            ]
          }
        ],
        'subclassFluff': [
          {
            'name': 'Alchemist',
            'className': 'Artificer',
            'source': 'TCE',
            'entries': [
              'An Alchemist is an expert at combining reagents to produce mystical effects.',
            ]
          }
        ]
      };

      final result = pipeline.ingestJsonMap(classBundle);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(2));

      final artificerFluff = EntityFluffService().getFluff('class', 'artificer');
      expect(artificerFluff, isNotNull);
      expect(artificerFluff!.loreMarkdown, contains('Masters of invention'));

      final alchemistFluff = EntityFluffService().getFluff('subclass', 'alchemist');
      expect(alchemistFluff, isNotNull);
      expect(alchemistFluff!.loreMarkdown, contains('combining reagents'));
    });

    test('resolves _copy inheritance across entities in fluff bundles', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final copyBundle = {
        'itemFluff': [
          {
            'name': "Fate Dealer's Deck",
            'source': 'BMT',
            'entries': [
              'A magnificent deck of painted parchment cards charged with astral divination power.',
            ],
            'images': [
              'items/BMT/FateDealersDeck.webp'
            ]
          },
          {
            'name': "+1 Fate Dealer's Deck",
            'source': 'BMT',
            '_copy': {
              'name': "Fate Dealer's Deck",
              'source': 'BMT'
            }
          }
        ]
      };

      final result = pipeline.ingestJsonMap(copyBundle);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(2));

      final baseDeck = EntityFluffService().getFluff('item', 'fate-dealer-s-deck');
      expect(baseDeck, isNotNull);
      expect(baseDeck!.loreMarkdown, contains('astral divination power'));

      final copyDeck = EntityFluffService().getFluff('item', '1-fate-dealer-s-deck');
      expect(copyDeck, isNotNull);
      expect(copyDeck!.loreMarkdown, contains('astral divination power'));
      expect(copyDeck.images, contains('items/BMT/FateDealersDeck.webp'));
    });

    test('ingests JSON list of fluff entries via ingestJsonString', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      const rawList = '''
      [
        {
          "name": "Astral Dreadnought",
          "source": "MTF",
          "entries": ["Enormous monstrosities patrolling the silvery void."],
          "images": ["bestiary/MTF/AstralDreadnought.webp"]
        },
        {
          "name": "Baphomet",
          "source": "MTF",
          "entries": ["The Horned King and Prince of Beasts."],
          "images": ["bestiary/MTF/Baphomet.webp"]
        }
      ]
      ''';

      final result = pipeline.ingestJsonString(rawList);
      expect(result.hasErrors, isFalse);
      expect(result.attachedFluffCount, equals(2));

      final dreadnought = EntityFluffService().getFluff('monster', 'astral-dreadnought');
      expect(dreadnought, isNotNull);
      expect(dreadnought!.loreMarkdown, contains('silvery void'));

      final baphomet = EntityFluffService().getFluff('monster', 'baphomet');
      expect(baphomet, isNotNull);
      expect(baphomet!.loreMarkdown, contains('Prince of Beasts'));
    });

    test('saveHomebrewEntitiesBatch persists remote fluff entities into EntityFluffService', () async {
      const remoteFluffEntity = HomebrewEntity(
        id: 'ancient-brass-dragon',
        name: 'Ancient Brass Dragon',
        entityType: 'monsterfluff',
        ruleset: RulesetVersion.srd2014,
        rawPayload: {
          'name': 'Ancient Brass Dragon',
          'source': 'MM',
          'entries': [
            'Brass dragons are talkative and love conversation with mortals.',
          ],
          'images': [
            'bestiary/MM/AncientBrassDragon.webp',
          ]
        },
      );

      await HomebrewPersistenceService().saveHomebrewEntitiesBatch(
        [remoteFluffEntity],
        syncLibraries: false,
        excludeSrdCanon: false,
      );

      final dragonFluff = EntityFluffService().getFluff('monster', 'ancient-brass-dragon');
      expect(dragonFluff, isNotNull);
      expect(dragonFluff!.loreMarkdown, contains('love conversation with mortals'));
      expect(dragonFluff.images, contains('bestiary/MM/AncientBrassDragon.webp'));
    });

    test('HomebrewBundle serialization and deserialization retains attached fluff', () {
      const sampleFluff = EntityFluff(
        entityType: 'spell',
        slug: 'moonbeam',
        loreMarkdown: 'A silvery beam of pale light shines down in a 5-foot-radius cylinder.',
        images: ['spells/PHB/Moonbeam.webp'],
        source: 'PHB',
      );

      final bundle = HomebrewBundle(
        appVersion: '1.0.0',
        exportedAt: DateTime.now(),
        fluff: const [sampleFluff],
      );

      expect(bundle.fluff.length, equals(1));
      expect(bundle.totalCount, equals(1));

      final serialized = bundle.toMap();
      expect(serialized['fluff'], isNotNull);
      expect((serialized['fluff'] as List).length, equals(1));

      final deserialized = HomebrewBundle.fromMap(serialized);
      expect(deserialized.fluff.length, equals(1));
      expect(deserialized.fluff.first.slug, equals('moonbeam'));
      expect(deserialized.fluff.first.loreMarkdown, contains('silvery beam'));
      expect(deserialized.fluff.first.images, contains('spells/PHB/Moonbeam.webp'));
    });
  });
}
