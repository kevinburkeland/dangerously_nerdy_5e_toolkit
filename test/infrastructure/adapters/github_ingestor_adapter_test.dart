import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/ports/i_github_ingestor_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/github_repo_source.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
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
    final source = GithubRepoSource.parse('https://github.com/dnd-vault/spells-and-gear');

    test('Manifest discovery filters strictly for .json files, ignoring media and docs', () async {
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
        contains('https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/spells/eldritch_lance.json'),
      );
      expect(
        manifest,
        contains('https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/items/flame_blade.JSON'),
      );
      expect(
        manifest,
        contains('https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/monsters/void_stalker.json'),
      );
    });

    test('Rejects 2024 Weapon Mastery when target ruleset is srd2014', () async {
      final weapon2024Json = jsonEncode({
        'name': 'Masterwork Halberd',
        'type': 'equipment',
        'rarity': 'uncommon',
        'weaponMastery': 'Cleave',
        'damage': '1d10',
      });

      const url = 'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/items/masterwork_halberd.json';

      final client = MockHttpFetchClient({
        url: weapon2024Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

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

      const url = 'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/races/high_elf.json';

      final client = MockHttpFetchClient({
        url: race2014Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2024)
          .toList();

      expect(results.length, equals(1));
      final result = results.first;
      expect(result, isA<IngestionSkipResult>());

      final skip = result as IngestionSkipResult;
      expect(skip.ruleset, equals(RulesetVersion.srd2024));
      expect(skip.reason, contains('Species / Race cannot define Ability Score Increases'));
    });

    test('Successfully ingests compliant 2024 background schema', () async {
      final background2024Json = jsonEncode({
        'name': 'Wayfarer',
        'type': 'background',
        'asi': {'dex': 2, 'wis': 1},
        'originFeat': 'Lucky',
      });

      const url = 'https://raw.githubusercontent.com/dnd-vault/spells-and-gear/main/backgrounds/wayfarer.json';

      final client = MockHttpFetchClient({
        url: background2024Json,
      });

      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2024)
          .toList();

      expect(results.length, equals(1));
      final result = results.first;
      expect(result, isA<IngestionSuccessResult>());

      final success = result as IngestionSuccessResult;
      expect(success.entity.name, equals('Wayfarer'));
      expect(success.entity.entityType, equals('background'));
      expect(success.ruleset, equals(RulesetVersion.srd2024));
    });

    test('Gracefully skips corrupted JSON without terminating stream', () async {
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
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url1, url2], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(2));
      expect(results.any((r) => r is IngestionSkipResult), isTrue);
      expect(results.any((r) => r is IngestionSuccessResult), isTrue);
    });

    test('Unpacks compendium bundle file containing monster and spell collections into individual entities', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/bestiary-and-spells.json';
      final bundlePayload = jsonEncode({
        '_meta': {
          'sources': [{'json': 'HomebrewCore', 'abbreviation': 'HC'}],
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
            'type': {'type': 'dragon', 'tags': ['titan']},
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
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(3));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);

      final successResults = results.whereType<IngestionSuccessResult>().toList();
      final names = successResults.map((s) => s.entity.name).toList();
      expect(names, containsAll(['Void Stalker', 'Astral Drake', 'Nether Wave']));
      expect(successResults.firstWhere((s) => s.entity.name == 'Void Stalker').entity.entityType, equals('monster'));
      expect(successResults.firstWhere((s) => s.entity.name == 'Astral Drake').entity.entityType, equals('monster'));
      expect(successResults.firstWhere((s) => s.entity.name == 'Nether Wave').entity.entityType, equals('spell'));
    });

    test('Unpacks root JSON array of entities', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/monsters_list.json';
      final arrayPayload = jsonEncode([
        {'name': 'Cave Troll', 'cr': '6', 'hp': 90},
        {'name': 'Moss Elemental', 'cr': '4', 'hp': 60},
      ]);

      final client = MockHttpFetchClient({url: arrayPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(2));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final names = results.whereType<IngestionSuccessResult>().map((s) => s.entity.name).toList();
      expect(names, containsAll(['Cave Troll', 'Moss Elemental']));
    });

    test('Cleanly skips repository metadata or index file without throwing name attribute error', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/_meta.json';
      final metaPayload = jsonEncode({
        '_meta': {
          'sources': [{'json': 'OnlyMeta', 'full': 'Only Metadata'}],
          'dateAdded': 1600000000,
        },
      });

      final client = MockHttpFetchClient({url: metaPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(1));
      expect(results.first, isA<IngestionSkipResult>());
      final skip = results.first as IngestionSkipResult;
      expect(skip.reason, contains('metadata or index file'));
      expect(skip.reason.contains('missing a valid "name" attribute'), isFalse);
    });

    test('Accepts entity with title fallback when name key is absent', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/item.json';
      final itemPayload = jsonEncode({
        'title': 'Amulet of the Deep',
        'type': 'equipment',
        'rarity': 'rare',
      });

      final client = MockHttpFetchClient({url: itemPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(1));
      expect(results.first, isA<IngestionSuccessResult>());
      final success = results.first as IngestionSuccessResult;
      expect(success.entity.name, equals('Amulet of the Deep'));
    });

    test('Successfully ingests community compendium fluff bundles from remote files', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/data/fluff-bestiary-mm.json';
      final fluffPayload = jsonEncode({
        'monsterFluff': [
          {
            'name': 'Aboleth',
            'source': 'MM',
            'entries': ['Before the coming of the gods, aboleths lurked in primordial oceans.'],
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
            'entries': ['Most covetous of all dragons.'],
          }
        ]
      });

      final client = MockHttpFetchClient({url: fluffPayload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(2));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final success0 = results[0] as IngestionSuccessResult;
      expect(success0.entity.name, equals('Aboleth'));
      expect(success0.entity.entityType, equals('monsterfluff'));
    });

    test('Manifest discovery skips Foundry duplicates, index files, and book prose while preserving tabletop content', () async {
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
          {'path': 'data/generated/gendata-spell-source-lookup.json', 'type': 'blob'},
          // Narrative prose books (must be skipped)
          {'path': 'data/book/book-phb.json', 'type': 'blob'},
          {'path': 'data/adventure/adventure-cos.json', 'type': 'blob'},
          {'path': 'data/books.json', 'type': 'blob'},
        ],
      });

      final client = MockHttpFetchClient({source.apiTreeUri.toString(): mockTree});
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
      expect(manifest.any((u) => u.contains('book-phb')), isFalse);
      expect(manifest.any((u) => u.contains('adventure-cos')), isFalse);
    });

    test('Unpacks optionalfeatures, psionics, languages, and decks into individual entities', () async {
      const url = 'https://raw.githubusercontent.com/dnd/core/main/data/optionalfeatures.json';
      final payload = jsonEncode({
        'optionalfeature': [
          {
            'name': 'Agonizing Blast',
            'source': 'PHB',
            'featureType': ['EI'],
            'prerequisite': [{'spell': ['eldritch blast#phb']}],
            'entries': ['When you cast eldritch blast, add your Charisma modifier to the damage.'],
          },
          {
            'name': 'Pact of the Blade',
            'source': 'PHB',
            'featureType': ['PB'],
            'entries': ['You can use your action to create a pact weapon in your empty hand.'],
          },
          {
            'name': 'Enhanced Defense',
            'source': 'TCE',
            'featureType': ['AI'],
            'entries': ['A creature gains a +1 bonus to Armor Class while wearing (armor) or wielding (a shield) the infused item.'],
          },
        ]
      });

      final client = MockHttpFetchClient({url: payload});
      final adapter = GithubIngestorAdapter(client: client, useIsolate: false);
      final results = await adapter
          .ingestPayloadStream(rawUrls: [url], ruleset: RulesetVersion.srd2014)
          .toList();

      expect(results.length, equals(3));
      expect(results.every((r) => r is IngestionSuccessResult), isTrue);
      final success0 = results[0] as IngestionSuccessResult;
      expect(success0.entity.name, equals('Agonizing Blast'));
      expect(success0.entity.entityType, equals('optionalfeature'));
      expect(success0.entity.normalizedData['featureType'], equals(['EI']));
    });
  });
}
