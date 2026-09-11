import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/homebrew_import_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/models/homebrew_entity.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/github_repo_source.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/homebrew/value_objects/ruleset_version.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/github_ingestor_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/remote/http_fetcher.dart';

class MockHttpFetchClient implements HttpFetchClient {
  final Map<String, String> responses;

  MockHttpFetchClient(this.responses);

  @override
  Future<String> get(Uri uri) async {
    final key = uri.toString();
    if (responses.containsKey(key)) {
      return responses[key]!;
    }
    throw Exception('Not found: $key');
  }
}

void main() {
  group('HomebrewImportOrchestrator CRDT Integration Tests', () {
    final source = GithubRepoSource.parse('https://github.com/my-group/campaign-homebrew');

    test('Coordinates manifest discovery, ACL filtering, and commits to CRDT ledger', () async {
      final treeManifest = jsonEncode({
        'tree': [
          {'path': 'spells/frost_lance.json', 'type': 'blob'},
          {'path': 'items/vorpal_dagger.json', 'type': 'blob'},
          {'path': 'notes.txt', 'type': 'blob'},
        ],
      });

      final frostLanceJson = jsonEncode({
        'name': 'Frost Lance',
        'level': 2,
        'school': 'evocation',
        'time': '1 action',
      });

      // Vorpal Dagger violates 2014 by declaring 2024 weapon mastery
      final vorpalDaggerJson = jsonEncode({
        'name': 'Vorpal Dagger',
        'type': 'equipment',
        'weaponMastery': 'Nick',
      });

      final mockClient = MockHttpFetchClient({
        source.apiTreeUri.toString(): treeManifest,
        'https://raw.githubusercontent.com/my-group/campaign-homebrew/main/spells/frost_lance.json':
            frostLanceJson,
        'https://raw.githubusercontent.com/my-group/campaign-homebrew/main/items/vorpal_dagger.json':
            vorpalDaggerJson,
      });

      final persistedEntities = <HomebrewEntity>[];
      final adapter = GithubIngestorAdapter(client: mockClient, useIsolate: false);
      final orchestrator = HomebrewImportOrchestrator(
        ingestorPort: adapter,
        nodeId: 'test_node_42',
        persister: (entity) async {
          persistedEntities.add(entity);
        },
      );

      final telemetrySnapshots = <HomebrewImportTelemetry>[];
      final stream = orchestrator.runImport(
        source: source,
        ruleset: RulesetVersion.srd2014,
      );

      await for (final t in stream) {
        telemetrySnapshots.add(t);
      }

      // Assert discovery and processing
      expect(telemetrySnapshots, isNotEmpty);
      final finalTelemetry = telemetrySnapshots.last;
      expect(finalTelemetry.isCompleted, isTrue);
      expect(finalTelemetry.filesDiscovered, equals(2)); // Only .json files
      expect(finalTelemetry.filesImported, equals(1)); // frost_lance
      expect(finalTelemetry.filesSkipped, equals(1)); // vorpal_dagger with mastery
      expect(finalTelemetry.errors.length, equals(1));
      expect(finalTelemetry.errors.first, contains('Weapon Mastery'));

      // Assert CRDT Ledger commitment
      final ledger = orchestrator.ledger;
      expect(ledger.activeValues.length, equals(1));
      final item = ledger.activeValues.first;
      expect(item.name, equals('Frost Lance'));
      expect(item.ruleset, equals(RulesetVersion.srd2014));

      // Assert HLC stamp exists in CRDT register
      final register = ledger.items[item.id];
      expect(register, isNotNull);
      expect(register!.timestamp.nodeId, equals('test_node_42'));

      // Assert secondary persister callback was called
      expect(persistedEntities.length, equals(1));
      expect(persistedEntities.first.name, equals('Frost Lance'));
    });
  });
}
