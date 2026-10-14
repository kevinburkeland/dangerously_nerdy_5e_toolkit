import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

class _FakeCharRepo implements ICharacterRepository<Character> {
  @override
  Future<List<Character>> loadCharacters() async => [];
  @override
  Future<void> saveCharacter(Character c) async => [c];
  @override
  Future<void> saveCharacters(List<Character> c) async {}
  @override
  Future<void> saveRoster(List<Character> r) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
  @override
  Future<Character?> getCharacter(String id) async => null;
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async => [];
  @override
  Future<String?> loadActiveCharacterId() async => null;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<Character> reparseCharacter(Character c) async => c;
  @override
  Future<List<Character>> reparseAllCharacters() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppDatabaseService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('Legacy Entity Links in Full Campaign Record (Pass 4.2.7)', () {
    // Fixtures directory in test/fixtures/legacy_entity_links, falling back to vtt_engine_core
    File resolveFixture(String filename) {
      final local = File('test/fixtures/legacy_entity_links/$filename');
      if (local.existsSync()) return local;
      final fallback = File('../vtt-engine-core/test/fixtures/legacy_entity_links/$filename');
      if (fallback.existsSync()) return fallback;
      throw StateError('Fixture $filename not found in test/fixtures/legacy_entity_links or ../vtt-engine-core');
    }

    Map<String, dynamic> loadFixtureJson(String filename) {
      final file = resolveFixture(filename);
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }

    Map<String, dynamic> wrapInCampaign(String id, Map<String, dynamic> roomJson) {
      return {
        'id': id,
        'name': 'Campaign $id',
        'nodeId': 'node_test',
        'createdAt': DateTime.utc(2026, 10, 10).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2026, 10, 11).toIso8601String(),
        'roomState': roomJson,
      };
    }

    test('item_only fixture wrapped in CampaignProfileDto loads cleanly to domain', () {
      final roomJson = loadFixtureJson('item_only.json');
      final campaignJson = wrapInCampaign('c_item_only', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.length, 1);
      final link = domain.roomState.entityLinks.first;
      expect(link.entityId, 'X');
      expect(link.displayName, 'Goblin');
      expect(link.incarnationTimestamp.physicalTime, 30);
    });

    test('tombstone_only fixture wrapped in CampaignProfileDto loads cleanly to domain with X removed', () {
      final roomJson = loadFixtureJson('tombstone_only.json');
      final campaignJson = wrapInCampaign('c_tomb_only', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.isEmpty, isTrue);
      expect(domain.roomState.entityLinksCrdt.isRemoved('X'), isTrue);
      final tomb = domain.roomState.entityLinksCrdt.tombstones['X']!;
      expect(tomb.targetGeneration.physicalTime, 20);
      expect(tomb.legacyAddWins, isTrue);
    });

    test('item30_tomb20 fixture wrapped in CampaignProfileDto loads with item winning', () {
      final roomJson = loadFixtureJson('item30_tomb20.json');
      final campaignJson = wrapInCampaign('c_item30_tomb20', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.length, 1);
      expect(domain.roomState.entityLinks.first.entityId, 'X');
      expect(domain.roomState.entityLinks.first.incarnationTimestamp.physicalTime, 30);
    });

    test('item20_tomb20 fixture wrapped in CampaignProfileDto loads with item winning on tie', () {
      final roomJson = loadFixtureJson('item20_tomb20.json');
      final campaignJson = wrapInCampaign('c_item20_tomb20', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.length, 1);
      expect(domain.roomState.entityLinks.first.entityId, 'X');
      expect(domain.roomState.entityLinks.first.incarnationTimestamp.physicalTime, 20);
    });

    test('item10_tomb20 fixture wrapped in CampaignProfileDto loads with tombstone winning (removed)', () {
      final roomJson = loadFixtureJson('item10_tomb20.json');
      final campaignJson = wrapInCampaign('c_item10_tomb20', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.isEmpty, isTrue);
      expect(domain.roomState.entityLinksCrdt.isRemoved('X'), isTrue);
    });

    test('mixed.json fixture wrapped in CampaignProfileDto loads with all IDs reconciled', () {
      final roomJson = loadFixtureJson('mixed.json');
      final campaignJson = wrapInCampaign('c_mixed', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      final activeIds = domain.roomState.entityLinks.map((l) => l.entityId).toSet();
      expect(activeIds, contains('id_item_only'));
      expect(activeIds, contains('id_item30_tomb20'));
      expect(activeIds, contains('id_item20_tomb20'));
      expect(activeIds, isNot(contains('id_tomb_only')));
      expect(activeIds, isNot(contains('id_item10_tomb20')));
    });

    test('native_starting_head.json fixture wrapped in CampaignProfileDto loads unchanged', () {
      final roomJson = loadFixtureJson('native_starting_head.json');
      final campaignJson = wrapInCampaign('c_native', roomJson);

      final domain = CampaignProfileDto.fromJson(jsonEncode(campaignJson)).toDomain();
      expect(domain.roomState.entityLinks.length, 1);
      expect(domain.roomState.entityLinks.first.entityId, 'native_1');
      expect(domain.roomState.entityLinksCrdt.isRemoved('native_tomb'), isTrue);
    });

    test('LocalCampaignRepository loads legacy tombstone campaign record without rejection', () async {
      final roomJson = loadFixtureJson('tombstone_only.json');
      final campaignJson = wrapInCampaign('camp_tombstone_legacy', roomJson);

      // Save directly into AppDatabaseService storage
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp_tombstone_legacy'],
      );
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_tombstone_legacy',
        jsonEncode(campaignJson),
      );

      final runtimeReplica = ReplicaId('runtime_node');
      final clock = StatefulHlcClock(
        replicaId: runtimeReplica,
        timeProvider: () => 1700000000000,
      );
      final repo = LocalCampaignRepository(
        replicaId: runtimeReplica,
        characterRepo: _FakeCharRepo(),
        clock: clock,
      );
      addTearDown(repo.dispose);

      final loaded = await repo.loadAllProfiles();

      // Campaign must be successfully loaded and NOT rejected
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('camp_tombstone_legacy'));
      expect(loaded.first.roomState.entityLinksCrdt.isRemoved('X'), isTrue);
    });
  });
}
