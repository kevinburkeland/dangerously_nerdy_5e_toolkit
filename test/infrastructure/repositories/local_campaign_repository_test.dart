import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutex/mutex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';

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

  group('LocalCampaignRepository Reactive Streams Tests', () {
    test(
        'broadcasts state updates through watchActiveProfile and watchAllProfiles on save',
        () async {
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      final activeProfileEvents = <CampaignProfile?>[];
      final allProfilesEvents = <List<CampaignProfile>>[];

      final subActive =
          repo.watchActiveProfile().listen(activeProfileEvents.add);
      final subAll = repo.watchAllProfiles().listen(allProfilesEvents.add);
      addTearDown(() {
        subActive.cancel();
        subAll.cancel();
      });

      final p1 = CampaignProfile.defaultProfile(
          name: 'Campaign Alpha', nodeId: 'test_node');
      await repo.saveProfileImmediate(p1);
      await Future<void>.delayed(Duration.zero);

      expect(activeProfileEvents.isNotEmpty, isTrue);
      expect(allProfilesEvents.isNotEmpty, isTrue);
      expect(allProfilesEvents.last.map((p) => p.name),
          contains('Campaign Alpha'));
    });

    test('setActiveProfileId updates active profile stream', () async {
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      final p1 =
          CampaignProfile.defaultProfile(name: 'Camp 1', nodeId: 'test_node');
      final p2 =
          CampaignProfile.defaultProfile(name: 'Camp 2', nodeId: 'test_node');
      await repo.saveProfileImmediate(p1);
      await repo.saveProfileImmediate(p2);

      final activeIds = <String?>[];
      final sub = repo.watchActiveProfile().listen((p) => activeIds.add(p?.id));
      addTearDown(sub.cancel);

      await repo.setActiveProfileId(p2.id);
      await Future<void>.delayed(Duration.zero);

      expect(activeIds.contains(p2.id), isTrue);
      expect(repo.activeProfileId, equals(p2.id));
    });

    test(
        'saveProfileImmediate emits profile updates asynchronously on microtask queue',
        () async {
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      bool synchronousFlag = false;
      bool eventReceivedDuringCall = false;

      final sub = repo.watchAllProfiles().listen((_) {
        if (synchronousFlag) {
          eventReceivedDuringCall = true;
        }
      });
      addTearDown(sub.cancel);

      synchronousFlag = true;
      final saveFuture = repo.saveProfileImmediate(
          CampaignProfile.defaultProfile(
              name: 'Async Test', nodeId: 'test_node'));
      synchronousFlag = false;

      await saveFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        eventReceivedDuringCall,
        isFalse,
        reason:
            'StreamController must emit asynchronously on the microtask queue, not synchronously in-frame',
      );
    });

    test(
        'rapidly chaining saveProfileImmediate within a Mutex does not deadlock or throw StateError',
        () async {
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      final mutex = Mutex();
      final receivedRosters = <List<CampaignProfile>>[];

      final sub = repo.watchAllProfiles().listen((profiles) {
        receivedRosters.add(profiles);
      });
      addTearDown(sub.cancel);

      final futures = <Future<void>>[];
      for (int i = 0; i < 20; i++) {
        futures.add(mutex.protect(() async {
          final profile = CampaignProfile.defaultProfile(
            id: 'mutex_profile_$i',
            name: 'Mutex Profile $i',
            nodeId: 'test_node',
          );
          await repo.saveProfileImmediate(profile);
        }));
      }

      await Future.wait(futures);
      await Future<void>.delayed(Duration.zero);

      expect(receivedRosters.isNotEmpty, isTrue);
      expect(receivedRosters.last.map((p) => p.name),
          contains('Mutex Profile 19'));
    });
  });

  group('LocalCampaignRepository Corrupt Record Preservation (Pass 3.2)', () {
    test(
        'preserves raw corrupt profile in storage and index across load, unrelated saves, and restart',
        () async {
      final healthy = CampaignProfile.defaultProfile(
        id: 'healthy-id',
        name: 'Healthy Campaign',
        nodeId: 'test_node',
      );
      final healthyDtoMap = CampaignProfileDto.fromDomain(healthy).toMap();
      const corruptPayload = '{"id":"corrupt-id", "broken": [invalid json syntax';

      // 1. Seed storage with [healthy-id, corrupt-id]
      SharedPreferences.setMockInitialValues({
        'dn5e_campaign_profile_index': ['healthy-id', 'corrupt-id'],
        'dn5e_campaign_profile_healthy-id': json.encode(healthyDtoMap),
        'dn5e_campaign_profile_corrupt-id': corruptPayload,
      });

      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      // 2. loadAllProfiles() loads healthy, isolates corrupt
      final loaded = await repo.loadAllProfiles();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('healthy-id'));

      // 3. Inspect raw stored index: corrupt-id STILL exists
      final rawIndexAfterLoad = AppDatabaseService.instance.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      );
      expect(rawIndexAfterLoad, containsAll(['healthy-id', 'corrupt-id']));

      // 4. Save unrelated healthy profile
      final p2 = CampaignProfile.defaultProfile(
        id: 'healthy-id-2',
        name: 'Healthy Campaign 2',
        nodeId: 'test_node',
      );
      await repo.saveProfileImmediate(p2);

      // 5. Inspect raw index again: corrupt-id STILL exists alongside healthy-id and healthy-id-2
      final rawIndexAfterSave = AppDatabaseService.instance.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      );
      expect(rawIndexAfterSave,
          containsAll(['healthy-id', 'healthy-id-2', 'corrupt-id']));

      // 6. Raw corrupt payload remains unchanged
      final rawCorruptPayload = AppDatabaseService.instance.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}corrupt-id',
      );
      expect(rawCorruptPayload, equals(corruptPayload));

      // 7. Restart / recreate repository and verify it is still preserved
      final restartedRepo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(restartedRepo.dispose);

      final reloaded = await restartedRepo.loadAllProfiles();
      expect(reloaded.map((p) => p.id),
          containsAll(['healthy-id', 'healthy-id-2']));
      expect(reloaded.any((p) => p.id == 'corrupt-id'), isFalse);

      final rawIndexAfterRestart = AppDatabaseService.instance.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      );
      expect(rawIndexAfterRestart, contains('corrupt-id'));
      expect(
          AppDatabaseService.instance.get(
            AppDatabaseService.boxCampaignProfiles,
            '${LocalCampaignRepository.profileKeyPrefix}corrupt-id',
          ),
          equals(corruptPayload));

      // 8. Explicit deleteProfile(corrupt-id) removes it
      await restartedRepo.deleteProfile('corrupt-id');
      final finalIndex = AppDatabaseService.instance.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      ) as List?;
      expect(finalIndex?.contains('corrupt-id') ?? false, isFalse);
      expect(
          AppDatabaseService.instance.get(
            AppDatabaseService.boxCampaignProfiles,
            '${LocalCampaignRepository.profileKeyPrefix}corrupt-id',
          ),
          isNull);
    });

    test(
        'activeProfileId pointing to corrupt profile falls back at runtime without deleting record',
        () async {
      final healthy = CampaignProfile.defaultProfile(
        id: 'healthy-id',
        name: 'Healthy Campaign',
        nodeId: 'test_node',
      );
      final healthyDtoMap = CampaignProfileDto.fromDomain(healthy).toMap();
      const corruptPayload = '{"id":"corrupt-id", "broken": [invalid json syntax';

      SharedPreferences.setMockInitialValues({
        'dn5e_campaign_profile_index': ['healthy-id', 'corrupt-id'],
        'dn5e_campaign_profile_healthy-id': json.encode(healthyDtoMap),
        'dn5e_campaign_profile_corrupt-id': corruptPayload,
        'dn5e_active_campaign_profile_id': 'corrupt-id',
      });

      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('test_repo_node'),
        characterRepo: _FakeCharRepo(),
      );
      addTearDown(repo.dispose);

      // getActiveProfile() should fall back to healthy profile
      final active = await repo.getActiveProfile();
      expect(active?.id, equals('healthy-id'));

      // Verify corrupt profile was NOT deleted from index or payload
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('dn5e_campaign_profile_index'),
          contains('corrupt-id'));
      expect(prefs.getString('dn5e_campaign_profile_corrupt-id'),
          equals(corruptPayload));
    });
  });
}
