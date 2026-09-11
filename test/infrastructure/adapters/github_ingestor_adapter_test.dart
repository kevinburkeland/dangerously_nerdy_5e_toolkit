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
  });
}
