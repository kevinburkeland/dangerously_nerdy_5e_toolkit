import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutex/mutex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character;
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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
        clock: StatefulHlcClock(replicaId: ReplicaId('test_repo_node')),
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

    group('Cold Iron Birdcage — Pass 3.3 Trusted Local History & Invariant Tests', () {
      const baseTimeT = 1700000000000;
      const oneHourMs = 3600 * 1000;
      const sixHoursMs = 6 * 3600 * 1000;

      test(
          'Section K: Clock-correction regression: local profile at T + 6h loads normally without drift rejection',
          () async {
        final oldDmReplica = ReplicaId('old-dm-session');
        final newRuntimeReplica = ReplicaId('new-runtime-dm');

        final historicalHlc = HybridLogicalClock(
          physicalTime: baseTimeT + sixHoursMs,
          logicalCounter: 10,
          nodeId: oldDmReplica.value,
        );

        final profileWithFutureHlc = CampaignProfile(
          id: 'camp-future-history',
          name: 'Future History Campaign',
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          nodeId: oldDmReplica.value,
          roomState: RoomNodeState(
            roomId: 'r1',
            roomCode: 'RC1',
            title: 'Future Chamber',
          ),
          notesRegister: CrdtLwwRegister<String>(
            value: 'Historical notes from the future',
            timestamp: historicalHlc,
          ),
        );

        final dto = CampaignProfileDto.fromDomain(profileWithFutureHlc);
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          LocalCampaignRepository.profileIndexKey,
          ['camp-future-history'],
        );
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}camp-future-history',
          dto.toJson(),
        );

        // Start new runtime whose wall clock is T
        final runtimeClock = StatefulHlcClock(
          replicaId: newRuntimeReplica,
          maxFutureDrift: const Duration(minutes: 1),
          timeProvider: () => baseTimeT,
        );

        final repo = LocalCampaignRepository(
          replicaId: newRuntimeReplica,
          characterRepo: _FakeCharRepo(),
          clock: runtimeClock,
        );
        addTearDown(repo.dispose);

        final loaded = await repo.loadAllProfiles();

        // Assert: profile loads normally and remains active/available
        expect(loaded.length, equals(1));
        expect(loaded.first.id, equals('camp-future-history'));
        expect(repo.activeProfile?.id, equals('camp-future-history'));

        // Runtime clock advances to historical causality
        expect(runtimeClock.latest.physicalTime, equals(baseTimeT + sixHoursMs));
        expect(runtimeClock.latest.logicalCounter, equals(11));

        // Next local write is > historical HLC and uses NEW runtime ReplicaId
        final nextWrite = runtimeClock.nextTimestamp();
        expect(nextWrite.isAfter(historicalHlc), isTrue);
        expect(nextWrite.nodeId, equals(newRuntimeReplica.value));
        expect(nextWrite.physicalTime, equals(baseTimeT + sixHoursMs));
        expect(nextWrite.logicalCounter, equals(12));
      });

      test(
          'Section L: Mixed local history regression: notes T+1h, minion T+2h, encounter tombstone T+3h all load and clock advances',
          () async {
        final oldNode = ReplicaId('old-writer-node');
        final newRuntimeReplica = ReplicaId('new-local-writer');

        final tsNotes = HybridLogicalClock(
          physicalTime: baseTimeT + oneHourMs,
          logicalCounter: 1,
          nodeId: oldNode.value,
        );
        final tsMinion = HybridLogicalClock(
          physicalTime: baseTimeT + (2 * oneHourMs),
          logicalCounter: 2,
          nodeId: oldNode.value,
        );
        final tsEncounterTombstone = HybridLogicalClock(
          physicalTime: baseTimeT + (3 * oneHourMs),
          logicalCounter: 3,
          nodeId: oldNode.value,
        );

        final minionSet = CrdtOrSet<dynamic>(
          items: {
            'minion-1': CrdtLwwRegister<dynamic>(
              value: {'name': 'Skeleton'},
              timestamp: tsMinion,
            ),
          },
        );

        final encounterSet = CrdtOrSet<EncounterParticipant>(
          tombstones: {
            'participant-dead': tsEncounterTombstone,
          },
        );

        final roomState = RoomNodeState(
          roomId: 'room-mixed',
          roomCode: 'MIX-1',
          title: 'Mixed Chamber',
          activeMinions: minionSet,
          activeEncounter: encounterSet,
        );

        final mixedProfile = CampaignProfile.raw(
          id: 'camp-mixed-history',
          name: 'Mixed History Campaign',
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: roomState,
          notesRegister: CrdtLwwRegister<String>(
            value: 'T+1h Notes',
            timestamp: tsNotes,
          ),
        );

        // Verify aggregate extraction helper extracts all 3 timestamps
        final extracted = extractCampaignProfileTimestamps(mixedProfile);
        expect(extracted, containsAll([tsNotes, tsMinion, tsEncounterTombstone]));

        final dto = CampaignProfileDto.fromDomain(mixedProfile);
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          LocalCampaignRepository.profileIndexKey,
          ['camp-mixed-history'],
        );
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}camp-mixed-history',
          dto.toJson(),
        );

        // Load under wall clock T
        final runtimeClock = StatefulHlcClock(
          replicaId: newRuntimeReplica,
          maxFutureDrift: const Duration(minutes: 1),
          timeProvider: () => baseTimeT,
        );

        final repo = LocalCampaignRepository(
          replicaId: newRuntimeReplica,
          characterRepo: _FakeCharRepo(),
          clock: runtimeClock,
        );
        addTearDown(repo.dispose);

        final loaded = await repo.loadAllProfiles();
        expect(loaded.length, equals(1));
        final loadedProfile = loaded.first;

        // Assert all profile state loads, no field dropped
        expect(loadedProfile.notesRegister.value, equals('T+1h Notes'));
        expect(loadedProfile.roomState.activeMinions.items.containsKey('minion-1'),
            isTrue);
        expect(
            loadedProfile.roomState.activeEncounter.tombstones
                .containsKey('participant-dead'),
            isTrue);

        // Runtime clock causality reaches the maximum historical HLC (T+3h)
        expect(runtimeClock.latest.physicalTime,
            equals(tsEncounterTombstone.physicalTime));

        // Next local write is after all three
        final nextWrite = runtimeClock.nextTimestamp();
        expect(nextWrite.isAfter(tsNotes), isTrue);
        expect(nextWrite.isAfter(tsMinion), isTrue);
        expect(nextWrite.isAfter(tsEncounterTombstone), isTrue);
        expect(nextWrite.nodeId, equals(newRuntimeReplica.value));
      });

      test(
          'Section M: Malformed local state still fails loudly and is quarantined/preserved',
          () async {
        final runtimeReplica = ReplicaId('test-runtime-replica');

        // 1. Structurally malformed HLC structure in CRDT encounter set
        const malformedHlcPayload =
            '{"id":"camp-bad-hlc","name":"Bad HLC","roomState":{"roomId":"r1","roomCode":"RC","activeEncounter":{"items":{"e1":{"v":{"participantId":"e1","entityLink":{"entityId":"e1","displayName":"Goblin"}},"ts":{"pt":"not-a-number","node":"n1"}}}}}}';

        // 2. Malformed CRDT map structure
        const malformedCrdtMapPayload =
            '{"id":"camp-bad-crdt","name":"Bad CRDT","roomState":{"roomId":"r1","roomCode":"RC","activeMinions":"not-a-map"}}';

        final healthyProfile = CampaignProfile.defaultProfile(
          id: 'camp-healthy',
          name: 'Healthy Campaign',
          nodeId: runtimeReplica.value,
        );
        final healthyDto = CampaignProfileDto.fromDomain(healthyProfile);

        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          LocalCampaignRepository.profileIndexKey,
          ['camp-healthy', 'camp-bad-hlc', 'camp-bad-crdt'],
        );
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}camp-healthy',
          healthyDto.toJson(),
        );
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}camp-bad-hlc',
          malformedHlcPayload,
        );
        AppDatabaseService.instance.put(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}camp-bad-crdt',
          malformedCrdtMapPayload,
        );

        final clock = StatefulHlcClock(
          replicaId: runtimeReplica,
          timeProvider: () => baseTimeT,
        );
        final repo = LocalCampaignRepository(
          replicaId: runtimeReplica,
          characterRepo: _FakeCharRepo(),
          clock: clock,
        );
        addTearDown(repo.dispose);

        final loaded = await repo.loadAllProfiles();

        // Malformed profiles are rejected from loaded memory; only healthy profile loads
        expect(loaded.length, equals(1));
        expect(loaded.first.id, equals('camp-healthy'));
        expect(loaded.any((p) => p.id == 'camp-bad-hlc'), isFalse);
        expect(loaded.any((p) => p.id == 'camp-bad-crdt'), isFalse);

        // Both records are preserved in raw disk storage
        expect(
            AppDatabaseService.instance.get(
              AppDatabaseService.boxCampaignProfiles,
              '${LocalCampaignRepository.profileKeyPrefix}camp-bad-hlc',
            ),
            equals(malformedHlcPayload));
        expect(
            AppDatabaseService.instance.get(
              AppDatabaseService.boxCampaignProfiles,
              '${LocalCampaignRepository.profileKeyPrefix}camp-bad-crdt',
            ),
            equals(malformedCrdtMapPayload));
      });
    });
  });
}
