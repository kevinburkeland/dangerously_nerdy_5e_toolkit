// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

class _FailingDatabaseService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  int failuresRemaining = 0;

  _FailingDatabaseService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    writtenData.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    if (key == LocalCampaignRepository.profileIndexKey && failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Simulated index read failure');
    }
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    writtenData[boxName]?.remove(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    for (final k in keys) {
      writtenData[boxName]?.remove(k);
    }
  }

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  List<String> getKeys(String boxName) {
    return writtenData[boxName]?.keys.toList() ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pass 5.1.1 Required Test 1: F2 failure counts 0, 1, 2, 3', () {
    for (final k in [0, 1, 2, 3]) {
      test('F2 fails=$k: index stays [A], A unchanged, no default exists', () async {
        final mockDb = _FailingDatabaseService();
        mockDb.failuresRemaining = k;

        final replicaId = ReplicaId('dm_node');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final charRepo = LocalCharacterRepository(db: mockDb);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: mockDb,
          characterRepo: charRepo,
        );

        final profileA = CampaignProfile(
          id: 'A',
          name: 'Campaign A',
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2026),
          lastPlayedAt: DateTime.utc(2026),
          roomState: RoomNodeState(roomId: 'rA', roomCode: 'CR-A', title: 'tA'),
          nodeId: 'dm_node',
        );
        final rawAJson = CampaignProfileDto.fromDomain(profileA).toJson();

        mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
          '${LocalCampaignRepository.profileKeyPrefix}A'
        ] = rawAJson;
        mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
          LocalCampaignRepository.profileIndexKey
        ] = ['A'];
        mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
          LocalCampaignRepository.activeProfileIdKey
        ] = 'A';

        // Run startup migration
        await CampaignStorageMigration.runStartupMigration(
          repository: repo,
          databaseService: mockDb,
          characterPersistenceService: CharacterPersistenceService(),
          registryService: CampaignRegistryService.newInstance(),
          clock: clock,
          nodeId: replicaId.value,
        );

        final index = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
          LocalCampaignRepository.profileIndexKey
        ];
        final storedA = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
          '${LocalCampaignRepository.profileKeyPrefix}A'
        ];

        expect(index, equals(['A']));
        expect(storedA, equals(rawAJson));
        expect(
          mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]!.keys
              .where((k) =>
                  k.startsWith(LocalCampaignRepository.profileKeyPrefix) &&
                  k != LocalCampaignRepository.profileIndexKey)
              .length,
          equals(1),
        );

        repo.dispose();
      });
    }
  });

  group('Pass 5.1.1 Required Test 3: write on unreadable store fails and touches nothing', () {
    test('putProfile on unreadable store throws and leaves storage byte-for-byte unchanged', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 999;

      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}orig'
      ] = '{"id":"orig","name":"Original"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['orig'];
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.activeProfileIdKey
      ] = 'orig';

      final beforeSnapshot = jsonEncode(mockDb.writtenData);

      final newProf = CampaignProfile(
        id: 'new_p',
        name: 'New Profile',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r_new', roomCode: 'NEW-1', title: 'New'),
        nodeId: 'dm_node',
      );

      expect(() => repo.putProfile(newProf), throwsA(isA<StateError>()));

      final afterSnapshot = jsonEncode(mockDb.writtenData);
      expect(afterSnapshot, equals(beforeSnapshot));

      repo.dispose();
    });

    test('updateProfile on unreadable store throws and leaves storage byte-for-byte unchanged', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 999;

      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}orig'
      ] = '{"id":"orig","name":"Original"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['orig'];

      final beforeSnapshot = jsonEncode(mockDb.writtenData);

      expect(
        () => repo.updateProfile('orig', (p) => p.copyWith(name: 'Updated')),
        throwsA(isA<StateError>()),
      );

      final afterSnapshot = jsonEncode(mockDb.writtenData);
      expect(afterSnapshot, equals(beforeSnapshot));

      repo.dispose();
    });

    test('deleteProfile on unreadable store throws and leaves storage byte-for-byte unchanged', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 999;

      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}orig'
      ] = '{"id":"orig","name":"Original"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['orig'];

      final beforeSnapshot = jsonEncode(mockDb.writtenData);

      expect(() => repo.deleteProfile('orig'), throwsA(isA<StateError>()));

      final afterSnapshot = jsonEncode(mockDb.writtenData);
      expect(afterSnapshot, equals(beforeSnapshot));

      repo.dispose();
    });
  });

  group('Pass 5.1.1 Required Test 2: Law test over 200+ seeded random inputs', () {
    test('Law test: stored IDs never lost and default only created after successful empty read', () async {
      const iterations = 220;

      for (int seed = 0; seed < iterations; seed++) {
        final rand = Random(seed * 7919 + 31);
        final mockDb = _FailingDatabaseService();
        final initialCount = rand.nextInt(5); // 0 to 4 campaigns
        final readFailures = rand.nextInt(6); // 0 to 5 failures

        final storedIds = <String>{};
        final storedPayloads = <String, String>{};

        for (int i = 0; i < initialCount; i++) {
          final id = 'camp_s${seed}_$i';
          storedIds.add(id);
          final prof = CampaignProfile(
            id: id,
            name: 'Campaign $id',
            edition: DmRulesEdition.v2024,
            createdAt: DateTime.utc(2026),
            lastPlayedAt: DateTime.utc(2026),
            roomState: RoomNodeState(roomId: 'r_$id', roomCode: 'ROOM-$i', title: 'Title $id'),
            nodeId: 'node_$seed',
          );
          final json = CampaignProfileDto.fromDomain(prof).toJson();
          storedPayloads[id] = json;
          mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
            '${LocalCampaignRepository.profileKeyPrefix}$id'
          ] = json;
        }

        final shuffledIndex = storedIds.toList()..shuffle(rand);
        mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
          LocalCampaignRepository.profileIndexKey
        ] = List<String>.from(shuffledIndex);

        if (shuffledIndex.isNotEmpty) {
          mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
            LocalCampaignRepository.activeProfileIdKey
          ] = shuffledIndex.first;
        }

        mockDb.failuresRemaining = readFailures;

        sl.reset();
        final replicaId = ReplicaId('node_$seed');
        sl.registerSingleton<ReplicaId>(replicaId);
        final clock = StatefulHlcClock(replicaId: replicaId);
        sl.registerSingleton<StatefulHlcClock>(clock);

        final charRepo = LocalCharacterRepository(db: mockDb);
        sl.registerSingleton<LocalCharacterRepository>(charRepo);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: mockDb,
          characterRepo: charRepo,
        );
        sl.registerSingleton<ICampaignRepository>(repo);

        final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

        // 1. Run startup migration
        await CampaignStorageMigration.runStartupMigration(
          repository: repo,
          databaseService: mockDb,
          characterPersistenceService: CharacterPersistenceService(),
          registryService: CampaignRegistryService.newInstance(),
          clock: clock,
          nodeId: replicaId.value,
        );

        // Validate index after startup migration
        List<String> currentIndex = List<String>.from(
          mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
                  LocalCampaignRepository.profileIndexKey] ??
              [],
        );

        for (final id in storedIds) {
          expect(currentIndex, contains(id),
              reason: 'Seed $seed: ID $id lost during startup migration (failures=$readFailures)');
        }
        if (storedIds.isNotEmpty) {
          expect(currentIndex.length, equals(storedIds.length),
              reason: 'Seed $seed: Extra profile created during startup migration on non-empty store');
        } else {
          // Empty store: startup migration must NEVER create a default campaign
          expect(currentIndex, isEmpty,
              reason: 'Seed $seed: Default campaign created during startup migration on empty store');
        }

        // 2. Perform a random mix of facade operations
        final numOps = 5 + rand.nextInt(6); // 5 to 10 operations
        for (int op = 0; op < numOps; op++) {
          final opType = rand.nextInt(4);

          switch (opType) {
            case 0:
              // loadAllProfiles
              final loaded = await facade.loadAllProfiles();
              if (mockDb.failuresRemaining == 0 && repo.isInitialized) {
                if (storedIds.isEmpty) {
                  // If store was empty and read succeeded, default profile is created
                  expect(loaded.length, equals(1));
                  storedIds.add(loaded.first.id);
                }
              }

            case 1:
              // putProfile
              final newId = 'put_s${seed}_$op';
              final newProf = CampaignProfile(
                id: newId,
                name: 'Put Profile $newId',
                edition: DmRulesEdition.v2024,
                createdAt: DateTime.utc(2026),
                lastPlayedAt: DateTime.utc(2026),
                roomState: RoomNodeState(roomId: 'r_$newId', roomCode: 'P-$op', title: 'Put $newId'),
                nodeId: 'node_$seed',
              );
              try {
                await facade.saveProfileImmediate(newProf);
                storedIds.add(newId);
              } catch (_) {
                // Expected failure if uninitialized and failuresRemaining > 0
              }

            case 2:
              // updateProfile
              if (storedIds.isNotEmpty) {
                final targetId = storedIds.elementAt(rand.nextInt(storedIds.length));
                try {
                  await facade.updateProfile(targetId, (current) {
                    return current.copyWith(name: '${current.name} (Updated)');
                  });
                } catch (_) {
                  // Expected failure if uninitialized and failuresRemaining > 0
                }
              }

            case 3:
              // deleteProfile
              if (storedIds.isNotEmpty) {
                final targetId = storedIds.elementAt(rand.nextInt(storedIds.length));
                try {
                  await facade.deleteProfile(targetId);
                  storedIds.remove(targetId);
                  if (storedIds.isEmpty) {
                    // deleteProfile creates a default profile when last profile deleted
                    final remaining = repo.allProfiles;
                    if (remaining.isNotEmpty) {
                      storedIds.add(remaining.first.id);
                    }
                  }
                } catch (_) {
                  // Expected failure if uninitialized and failuresRemaining > 0
                }
              }
          }

          // Check index invariant after each step
          currentIndex = List<String>.from(
            mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
                    LocalCampaignRepository.profileIndexKey] ??
                [],
          );

          for (final id in storedIds) {
            expect(currentIndex, contains(id),
                reason: 'Seed $seed op $op: Stored ID $id missing from index');
          }

          if (storedIds.isEmpty) {
            expect(currentIndex, isEmpty);
          }
        }

        repo.dispose();
      }
    });
  });
}
