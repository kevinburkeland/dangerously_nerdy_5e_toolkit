import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/homebrew/ports/i_github_ingestor_port.dart';
import 'package:vtt_engine_core/homebrew/value_objects/github_repo_source.dart';
import 'package:vtt_engine_core/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/github_ingestor_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/http_fetcher.dart';

/// Test mock implementation of HttpFetchClient.
class MockHttpFetchClient implements HttpFetchClient {
  final Map<String, String> endpointResponses;

  MockHttpFetchClient(this.endpointResponses);

  @override
  Future<String> get(Uri uri) async {
    final uriStr = uri.toString();
    if (endpointResponses.containsKey(uriStr)) {
      return endpointResponses[uriStr]!;
    }
    throw Exception('Mock 404: No response mocked for $uriStr');
  }
}

void main() {
  group('GithubIngestorAdapter & ACL Tests', () {
    final source =
        GithubRepoSource.parse('https://github.com/dnd-vault/spells-and-gear');

    test(
        'Manifest discovery filters strictly for .json files, ignoring media and docs',
        () async {
      final mockTreeResponse = jsonEncode({
        'sha': 'commit_sha_123',
        'tree': [
          {'path': 'README.md', 'type': 'blob'},
          {'path': 'license.txt', 'type': 'blob'},
          {'path': 'spells/eldritch_lance.json', 'type': 'blob'},
          {'path': 'assets/icon.png', 'type': 'blob'},
          {'path': 'items/flame_blade.JSON', 'type': 'blob'},
          {'path': 'config.yaml', 'type': 'blob'},
          {'path': 'monsters/void_stalker.json', 'type': 'blob'},
        ],
      });

      final client = MockHttpFetchClient({
        source.apiTreeUri.toString(): mockTreeResponse,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final manifest = await adapter.discoverJsonManifest(source);

      expect(manifest.length, equals(3));
      expect(
        manifest,
        contains(
            'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/spells/eldritch_lance.json'),
      );
      expect(
        manifest,
        contains(
            'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/items/flame_blade.JSON'),
      );
      expect(
        manifest,
        contains(
            'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/monsters/void_stalker.json'),
      );
    });

    test('Rejects 2024 Weapon Mastery when target ruleset is srd2014',
        () async {
      final weapon2024Json = jsonEncode({
        'name': 'Masterwork Halberd',
        'type': 'equipment',
        'rarity': 'uncommon',
        'weaponMastery': 'Cleave',
        'damage': '1d10',
      });

      const url =
          'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/items/masterwork_halberd.json';

      final client = MockHttpFetchClient({
        url: weapon2024Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(1));
      final result = results.first;
      expect(result, isA<IngestionSkipResult>());

      final skip = result as IngestionSkipResult;
      expect(skip.sourceUrl, equals(url));
      expect(skip.ruleset, equals(RulesetVersion.srd2014));
      expect(skip.reason, contains('Weapon Mastery declarations'));
    });

    test('Rejects 2014 Species ASI when target ruleset is srd2024', () async {
      final race2014Json = jsonEncode({
        'name': 'High Elf Variant',
        'type': 'race',
        'speed': 30,
        'asi': {'dex': 2, 'int': 1},
      });

      const url =
          'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/races/high_elf.json';

      final client = MockHttpFetchClient({
        url: race2014Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2024).toList();

      expect(results.length, equals(1));
      final result = results.first;
      expect(result, isA<IngestionSkipResult>());

      final skip = result as IngestionSkipResult;
      expect(skip.ruleset, equals(RulesetVersion.srd2024));
      expect(skip.reason,
          contains('Species / Race cannot define Ability Score Increases'));
    });

    test('Successfully ingests compliant 2024 background schema', () async {
      final background2024Json = jsonEncode({
        'name': 'Acolyte',
        'type': 'background',
        'asi': {'dex': 2, 'wis': 1},
        'originFeat': 'Lucky',
      });

      const url =
          'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/backgrounds/acolyte.json';

      final client = MockHttpFetchClient({
        url: background2024Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2024).toList();

      expect(results.length, equals(1));
      final result = results.first;
      expect(result, isA<IngestionSuccessResult>());

      final success = result as IngestionSuccessResult;
      expect(success.entity.name, equals('Acolyte'));
      expect(success.entity.entityType, equals('background'));
      expect(success.ruleset, equals(RulesetVersion.srd2024));
    });

    test('Gracefully skips corrupted JSON without terminating stream',
        () async {
      const url1 = 'https://raw.githubusercontent.com/dnd/core/main/bad.json';
      const url2 = 'https://raw.githubusercontent.com/dnd/core/main/good.json';

      final goodSpell = jsonEncode({
        'name': 'Arcane Bolt',
        'level': 1,
        'school': 'evocation',
        'time': '1 action',
      });

      final client = MockHttpFetchClient({
        url1: '{ corrupt json: missing quotes ...',
        url2: goodSpell,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url1, url2], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(2));
      expect(results.any((r) => r is IngestionSkipResult), isTrue);
      expect(results.any((r) => r is IngestionSuccessResult), isTrue);
    });

    test(
        'Unpacks compendium bundle file containing monster and spell collections into individual entities',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/bestiary-and-spells.json';
      final bundlePayload = jsonEncode({
        '_meta': {
          'sources': [
            {'json': 'HomebrewCore', 'abbreviation': 'HC'}
          ],
        },
        'monster': [
          {
            'name': 'Void Stalker',
            'type': 'aberration',
            'cr': '5',
            'hp': 85,
            'ac': 15,
          },
          {
            'name': 'Astral Drake',
            'type': {
              'type': 'dragon',
              'tags': ['titan']
            },
            'cr': '8',
            'hp': 130,
            'ac': 17,
          },
        ],
        'spell': [
          {
            'name': 'Nether Wave',
            'level': 3,
            'school': 'evocation',
            'time': '1 action',
          },
        ],
      });

      final client = MockHttpFetchClient({url: bundlePayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(3));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);

      final successResults =
          results.whereType<IngestionSuccessResult>().toList();
      final names = successResults.map((s) => s.entity.name).toList();
      expect(
          names, containsAll(['Void Stalker', 'Astral Drake', 'Nether Wave']));
      expect(
          successResults
              .firstWhere((s) => s.entity.name == 'Void Stalker')
              .entity
              .entityType,
          equals('monster'));
      expect(
          successResults
              .firstWhere((s) => s.entity.name == 'Astral Drake')
              .entity
              .entityType,
          equals('monster'));
      expect(
          successResults
              .firstWhere((s) => s.entity.name == 'Nether Wave')
              .entity
              .entityType,
          equals('spell'));
    });

    test('Unpacks root JSON array of entities', () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/monsters_list.json';
      final arrayPayload = jsonEncode([
        {'name': 'Hill Troll', 'cr': '6', 'hp': 90},
        {'name': 'Moss Elemental', 'cr': '4', 'hp': 60},
      ]);

      final client = MockHttpFetchClient({url: arrayPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(2));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final names = results
          .whereType<IngestionSuccessResult>()
          .map((s) => s.entity.name)
          .toList();
      expect(names, containsAll(['Hill Troll', 'Moss Elemental']));
    });

    test(
        'Cleanly skips repository metadata or index file without throwing name attribute error',
        () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/_meta.json';
      final metaPayload = jsonEncode({
        '_meta': {
          'sources': [
            {'json': 'OnlyMeta', 'full': 'Only Metadata'}
          ],
          'dateAdded': 1600000000,
        },
      });

      final client = MockHttpFetchClient({url: metaPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(1));
      expect(results.first, isA<IngestionSkipResult>());
      final skip = results.first as IngestionSkipResult;
      expect(skip.reason, contains('metadata or index file'));
      expect(skip.reason.contains('missing a valid "name" attribute'), isFalse);
    });

    test('Accepts entity with title fallback when name key is absent',
        () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/item.json';
      final itemPayload = jsonEncode({
        'title': 'Amulet of the Deep',
        'type': 'equipment',
        'rarity': 'rare',
      });

      final client = MockHttpFetchClient({url: itemPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(1));
      expect(results.first, isA<IngestionSuccessResult>());
      final success = results.first as IngestionSuccessResult;
      expect(success.entity.name, equals('Amulet of the Deep'));
    });

    test(
        'Successfully ingests community compendium fluff bundles from remote files',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/data/fluff-bestiary-srd.json';
      final fluffPayload = jsonEncode({
        'monsterFluff': [
          {
            'name': 'Aboleth',
            'source': 'SRD',
            'entries': [
              'Before the coming of the gods, aboleths lurked in primordial oceans.'
            ],
            'images': [
              {
                'type': 'image',
                'href': {
                  'type': 'internal',
                  'path': 'bestiary/SRD/Aboleth.webp'
                }
              }
            ]
          },
          {
            'name': 'Adult Red Dragon',
            'source': 'SRD',
            'entries': ['Most covetous of all dragons.'],
          }
        ]
      });

      final client = MockHttpFetchClient({url: fluffPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(2));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final success0 = results[0] as IngestionSuccessResult;
      expect(success0.entity.name, equals('Aboleth'));
      expect(success0.entity.entityType, equals('monsterfluff'));
    });

    test(
        'Manifest discovery skips Foundry duplicates, index files, and book prose while preserving tabletop content',
        () async {
      final mockTree = jsonEncode({
        'sha': 'tree_sha_content',
        'tree': [
          {'path': 'data/optionalfeatures.json', 'type': 'blob'},
          {'path': 'data/psionics.json', 'type': 'blob'},
          {'path': 'data/languages.json', 'type': 'blob'},
          {'path': 'data/decks.json', 'type': 'blob'},
          {'path': 'data/tables.json', 'type': 'blob'},
          // VTT / Foundry duplicates (must be skipped)
          {'path': 'data/foundry-items.json', 'type': 'blob'},
          {'path': 'data/bestiary/foundry.json', 'type': 'blob'},
          // Index and tooling manifests (must be skipped)
          {'path': 'data/index.json', 'type': 'blob'},
          {'path': 'data/fluff-index.json', 'type': 'blob'},
          {'path': 'data/sources.json', 'type': 'blob'},
          {'path': 'data/template.json', 'type': 'blob'},
          {'path': 'data/converter.json', 'type': 'blob'},
          {
            'path': 'data/generated/gendata-spell-source-lookup.json',
            'type': 'blob'
          },
          // Narrative prose books (must be skipped)
          {'path': 'data/book/book-core-rules.json', 'type': 'blob'},
          {'path': 'data/adventure/adventure-dark-castle.json', 'type': 'blob'},
          {'path': 'data/books.json', 'type': 'blob'},
          // Non-tabletop craft / crochet recipes (must be skipped)
          {'path': 'data/recipes.json', 'type': 'blob'},
        ],
      });

      final client =
          MockHttpFetchClient({source.apiTreeUri.toString(): mockTree});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final manifest = await adapter.discoverJsonManifest(source);

      expect(manifest.length, equals(5));
      expect(manifest.any((u) => u.contains('optionalfeatures.json')), isTrue);
      expect(manifest.any((u) => u.contains('psionics.json')), isTrue);
      expect(manifest.any((u) => u.contains('languages.json')), isTrue);
      expect(manifest.any((u) => u.contains('decks.json')), isTrue);
      expect(manifest.any((u) => u.contains('tables.json')), isTrue);

      // Verify exclusions
      expect(manifest.any((u) => u.contains('foundry')), isFalse);
      expect(manifest.any((u) => u.contains('index.json')), isFalse);
      expect(manifest.any((u) => u.contains('fluff-index.json')), isFalse);
      expect(manifest.any((u) => u.contains('sources.json')), isFalse);
      expect(manifest.any((u) => u.contains('book-core-rules')), isFalse);
      expect(manifest.any((u) => u.contains('adventure-dark-castle')), isFalse);
      expect(manifest.any((u) => u.contains('recipes')), isFalse);
    });

    test(
        'Unpacks optionalfeatures, psionics, languages, and decks into individual entities',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/data/optionalfeatures.json';
      final payload = jsonEncode({
        'optionalfeature': [
          {
            'name': 'Agonizing Blast',
            'source': 'SRD',
            'featureType': ['EI'],
            'prerequisite': [
              {
                'spell': ['eldritch blast#srd']
              }
            ],
            'entries': [
              'When you cast eldritch blast, add your Charisma modifier to the damage.'
            ],
          },
          {
            'name': 'Pact of the Blade',
            'source': 'SRD',
            'featureType': ['PB'],
            'entries': [
              'You can use your action to create a pact weapon in your empty hand.'
            ],
          },
          {
            'name': 'Infused Warding',
            'source': 'HOMEBREW',
            'featureType': ['AI'],
            'entries': [
              'A creature gains a +1 bonus to Armor Class while wearing (armor) or wielding (a shield) the infused item.'
            ],
          },
        ]
      });
      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(3));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final success0 = results[0] as IngestionSuccessResult;
      expect(success0.entity.name, equals('Agonizing Blast'));
      expect(success0.entity.entityType, equals('optionalfeature'));
      expect(success0.entity.normalizedData['featureType'], equals(['EI']));
    });

    test(
        'Unpacks and parses classes with startingProficiencies.tools and no additionalSpells (Druid, Monk, Rogue pattern)',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/data/class/class-druid.json';
      final payload = jsonEncode({
        'class': [
          {
            'name': 'Druid',
            'source': 'SRD',
            'page': 64,
            'srd': true,
            'hd': {'number': 1, 'faces': 8},
            'proficiency': ['int', 'wis'],
            'spellcastingAbility': 'wis',
            'casterProgression': 'full',
            'startingProficiencies': {
              'armor': ['light', 'medium', 'shields'],
              'weapons': ['clubs', 'daggers'],
              'tools': ['{@item Herbalism kit|srd}'],
            },
          }
        ],
        'classFeature': [
          {
            'name': 'Druidic',
            'source': 'SRD',
            'className': 'Druid',
            'classSource': 'SRD',
            'level': 1,
            'entries': ['You know Druidic, the secret language of druids.'],
          }
        ],
        'subclass': [
          {
            'name': 'Circle of the Land',
            'shortName': 'Land',
            'source': 'SRD',
            'className': 'Druid',
            'classSource': 'SRD',
            'subclassFeatures': [
              'Circle of the Land|Druid|SRD|Land||2',
            ],
          }
        ],
        'subclassFeature': [
          {
            'name': 'Bonus Cantrip',
            'source': 'SRD',
            'className': 'Druid',
            'classSource': 'SRD',
            'subclassShortName': 'Land',
            'subclassSource': 'SRD',
            'level': 2,
            'entries': [
              'When you choose this circle at 2nd level, you learn one additional druid cantrip of your choice.'
            ],
          }
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(4));
      expect(results.whereType<IngestionSkipResult>(), isEmpty);
      expect(results.whereType<IngestionSuccessResult>().length, equals(4));

      final classSuccess = results
          .whereType<IngestionSuccessResult>()
          .firstWhere((r) => r.entity.name == 'Druid');
      expect(classSuccess.entity.entityType, equals('class'));
    });

    test(
        'Composite structural fingerprinting rejects non-tabletop JSON while accepting valid shapes',
        () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/mixed.json';
      final payload = jsonEncode({
        'content': [
          // Generic web/package manifest object with 'name' and 'level' but no tabletop indicators (must be rejected)
          {
            'name': 'LoggingModule',
            'level': 3,
            'version': '1.0.0',
          },
          // Valid Monster: hp AND cr
          {
            'name': 'Dread Wolf',
            'hp': 45,
            'cr': '2',
          },
          // Valid Spell: level AND school
          {
            'name': 'Shadow Flare',
            'level': 2,
            'school': 'evocation',
          },
          // Valid Item: rarity
          {
            'name': 'Cloak of the Shadow',
            'rarity': 'uncommon',
          },
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      final successes = results.whereType<IngestionSuccessResult>().toList();
      final names = successes.map((s) => s.entity.name).toList();

      expect(names,
          containsAll(['Dread Wolf', 'Shadow Flare', 'Cloak of the Shadow']));
      expect(names.contains('LoggingModule'), isFalse);
      expect(
          successes
              .firstWhere((s) => s.entity.name == 'Dread Wolf')
              .entity
              .entityType,
          equals('monster'));
      expect(
          successes
              .firstWhere((s) => s.entity.name == 'Shadow Flare')
              .entity
              .entityType,
          equals('spell'));
      expect(
          successes
              .firstWhere((s) => s.entity.name == 'Cloak of the Shadow')
              .entity
              .entityType,
          equals('equipment'));
    });

    test(
        'Robust Category Inference accurately stitches class/subclass progression under generic wrappers',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/wrapped_classes.json';
      // Entities nested under generic wrapper 'data' without explicit entityType
      final payload = jsonEncode({
        'data': [
          {
            'name': 'Arcane Warrior',
            'hitDie': 10,
            'proficiency': ['str', 'int'],
          },
          {
            'name': 'Arcane Vanguard',
            'className': 'Arcane Warrior',
            'shortName': 'Vanguard',
            'subclassFeatures': [
              'Arcane Strike|Arcane Warrior||Vanguard||3',
            ],
          },
          {
            'name': 'Arcane Strike',
            'className': 'Arcane Warrior',
            'subclassShortName': 'Vanguard',
            'level': 3,
            'entries': ['You infuse your weapon with raw magical force.'],
          },
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      final successes = results.whereType<IngestionSuccessResult>().toList();
      expect(successes.length, equals(3));

      final classEntity =
          successes.firstWhere((s) => s.entity.name == 'Arcane Warrior');
      expect(classEntity.entity.entityType, equals('class'));

      final subclassEntity =
          successes.firstWhere((s) => s.entity.name == 'Arcane Vanguard');
      expect(subclassEntity.entity.entityType, equals('subclass'));
      // Verify subclass features were stitched into featuresMarkdown without being dropped
      expect(subclassEntity.entity.rawPayload['featuresMarkdown'],
          contains('Arcane Strike'));
    });

    test(
        'GenericTagScrubber sanitizes inline markup tags across all string fields and preserves unparsedPayload',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/tagged_monster.json';
      final payload = jsonEncode({
        'name': 'Infernal Champion',
        'hp': 120,
        'cr': '7',
        'ac': 18,
        'entries': [
          'The champion strikes with its {@item hellfire blade|srd}, dealing {@damage 2d8 + 4} slashing damage.',
          'Targets must succeed on a {@dc 15} Constitution save or be {@condition poisoned}.',
          'Can cast {@spell misty step|srd|Hellish Step} once per turn.',
          'Recharge: {@recharge 5-6}',
        ],
        'customVendorMeta': {
          'proprietaryKey': 'preserved-value',
        }
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(1));
      final success = results.first as IngestionSuccessResult;
      expect(success.entity.name, equals('Infernal Champion'));

      final entries =
          (success.entity.rawPayload['entries'] as List).cast<String>();
      expect(
          entries[0],
          equals(
              'The champion strikes with its hellfire blade, dealing 2d8 + 4 slashing damage.'));
      expect(
          entries[1],
          equals(
              'Targets must succeed on a DC 15 Constitution save or be poisoned.'));
      expect(entries[2], equals('Can cast Hellish Step once per turn.'));
      expect(entries[3], equals('Recharge: (Recharge 5-6)'));

      // Verify unparsed payload was preserved without data loss
      expect(success.entity.unparsedPayload.containsKey('customVendorMeta'),
          isTrue);
      expect(
        (success.entity.unparsedPayload['customVendorMeta']
            as Map)['proprietaryKey'],
        equals('preserved-value'),
      );
    });

    test(
        'Two-pass linker resolves local \$ref pointers and definition schemas before entity emission',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/referenced_entities.json';
      final payload = jsonEncode({
        'definitions': {
          'baseBlade': {
            'type': 'equipment',
            'rarity': 'rare',
            'weaponCategory': 'martial',
            'reqAttune': true,
          },
          'poisonRider': {
            'damage': '1d6 poison',
          }
        },
        'items': [
          {
            'name': 'Venomous Rapier',
            r'$ref': '#/definitions/baseBlade',
            'damageRider': {
              r'$ref': '#/definitions/poisonRider',
            },
            'entries': ['A gleaming rapier coated with sleeping poison.'],
          }
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(1));
      final success = results.first as IngestionSuccessResult;
      expect(success.entity.name, equals('Venomous Rapier'));
      expect(success.entity.entityType, equals('equipment'));
      // Verify properties inherited from #/definitions/baseBlade
      expect(success.entity.rawPayload['rarity'], equals('rare'));
      expect(success.entity.rawPayload['weaponCategory'], equals('martial'));
      expect(success.entity.rawPayload['reqAttune'], equals(true));
      // Verify nested $ref resolved from #/definitions/poisonRider
      final rider = success.entity.rawPayload['damageRider'] as Map;
      expect(rider['damage'], equals('1d6 poison'));
    });

    test(
        'Classifies Generic Town Guard and Shadowcat as monsters and strictly rejects classification as race',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/npc_bestiary.json';
      final payload = jsonEncode({
        'monster': [
          {
            'name': 'Generic Town Guard',
            'source': 'HOMEBREW_ADVENTURE',
            'size': ['S'],
            'type': 'humanoid (strongheart halfling)',
            'race': 'Strongheart Halfling',
            'speed': {'walk': 25},
            '_copy': {
              'name': 'Commoner',
              'source': 'SRD',
            },
          },
          {
            'name': 'Shadowcat',
            'source': 'HOMEBREW_COMPENDIUM',
            'size': ['T'],
            'speed': {'walk': 40, 'climb': 30},
            'trait': [
              {
                'name': 'Nimble',
                'entries': [
                  'Shadowcat can move through the space of any hostile creature.'
                ],
              }
            ],
            '_copy': {
              'name': 'Cat',
              'source': 'SRD',
            },
          }
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter.ingestPayloadStream(
          rawUrls: [url], ruleset: RulesetVersion.srd2014).toList();

      expect(results.length, equals(2));
      final bepis = results[0] as IngestionSuccessResult;
      expect(bepis.entity.name, equals('Generic Town Guard'));
      expect(bepis.entity.entityType, equals('monster'));
      expect(bepis.entity.entityType, isNot(equals('race')));

      final onyx = results[1] as IngestionSuccessResult;
      expect(onyx.entity.name, equals('Shadowcat'));
      expect(onyx.entity.entityType, equals('monster'));
      expect(onyx.entity.entityType, isNot(equals('race')));
    });

    test('Streams results in chunks without starving the event loop', () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/large_monsters.json';
      final payload = jsonEncode({
        'monster': List.generate(
          60,
          (i) => {
            'name': 'Monster $i',
            'cr': '1',
            'hp': {'average': 10, 'formula': '2d8+2'},
            'ac': [12],
          },
        ),
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(
        client: client,
        useIsolate: false,
        streamChunkSize: 20,
      );

      final stream = adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014);
      final emitted = <IngestionResult>[];
      await for (final res in stream) {
        emitted.add(res);
      }

      expect(emitted.length, equals(60));
      expect(emitted.whereType<IngestionSuccessResult>().length, equals(60));
    });

    test(
        'Disambiguates subclass features from full subclasses during ingestion',
        () async {
      const url =
          'https://raw.githubusercontent.com/dnd/core/main/subclass_pack.json';
      final payload = jsonEncode({
        'subclass': [
          {
            'name': 'The Nethermancer',
            'shortName': 'Nethermancer',
            'className': 'Warlock',
            'source': 'CUSTOM',
            'subclassFeatures': [
              'The Nethermancer|Warlock|CUSTOM|Nethermancer|CUSTOM|1',
              'Void Grip|Warlock|CUSTOM|Nethermancer|CUSTOM|1',
              'Shadow Ward|Warlock|CUSTOM|Nethermancer|CUSTOM|6',
            ],
          }
        ],
        'subclassFeature': [
          {
            'name': 'The Nethermancer',
            'className': 'Warlock',
            'subclassShortName': 'Nethermancer',
            'level': 1,
            'entries': ['You bind yourself to shadowy depths.'],
          },
          {
            'name': 'Void Grip',
            'className': 'Warlock',
            'subclassShortName': 'Nethermancer',
            'level': 1,
            'entries': [
              'As a bonus action, you summon a void tentacle that attacks an enemy.',
            ],
          },
          {
            'name': 'Shadow Ward',
            'className': 'Warlock',
            'subclassShortName': 'Nethermancer',
            'level': 6,
            'entries': [
              'As a reaction, you reduce incoming damage by 1d10.',
            ],
          },
        ],
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final stream = adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014);
      final emitted = await stream.toList();

      expect(emitted.length, equals(4));
      final successes = emitted.whereType<IngestionSuccessResult>().toList();
      expect(successes.length, equals(4));

      final subclasses =
          successes.where((r) => r.entity.entityType == 'subclass').toList();
      expect(subclasses.length, equals(1),
          reason:
              'Only the actual subclass should have entityType == subclass');
      expect(subclasses.first.entity.name, equals('The Nethermancer'));

      final features = successes
          .where((r) => r.entity.entityType == 'subclassfeature')
          .toList();
      expect(features.length, equals(3),
          reason: 'All 3 features should have entityType == subclassfeature');
      expect(features.any((f) => f.entity.name == 'Void Grip'), isTrue);
      expect(features.any((f) => f.entity.name == 'Shadow Ward'), isTrue);
    });
  });
}
