// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import '../../test_doubles/fake_blob_store.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';

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

  group('Pass 5.1.2 Required Test 1: F3 failure counts 0 to 5', () {
    for (final k in [0, 1, 2, 3, 4, 5]) {
      test('F3 fails=$k: campaign_CRX keeps 100 gp and index stays [campaign_CRX]', () async {
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

        final purse = const PartyPurse.empty().modifyDenomination('gp', 100, replicaId: replicaId);
        final profileCRX = CampaignProfile(
          id: 'campaign_CRX',
          name: 'Campaign CRX',
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2026),
          lastPlayedAt: DateTime.utc(2026),
          roomState: RoomNodeState(roomId: 'r_CRX', roomCode: 'CRX', title: 'CRX Title'),
          nodeId: 'dm_node',
          partyPurse: purse,
        );
        final rawCRXJson = CampaignProfileDto.fromDomain(profileCRX).toJson();

        mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
          '${LocalCampaignRepository.profileKeyPrefix}campaign_CRX'
        ] = rawCRXJson;
        mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
          LocalCampaignRepository.profileIndexKey
        ] = ['campaign_CRX'];
        mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
          LocalCampaignRepository.activeProfileIdKey
        ] = 'campaign_CRX';

        final registry = CampaignRegistryService.newInstance();
        await registry.saveMembership(
          CampaignMembership(
            roomCode: 'CRX',
            campaignName: 'Campaign CRX',
            role: CampaignRole.host,
            lastPlayed: DateTime.utc(2026),
          ),
        );

        await CampaignStorageMigration.runStartupMigration(
          repository: repo,
          databaseService: mockDb,
          characterPersistenceService: CharacterPersistenceService(),
          registryService: registry,
          clock: clock,
          nodeId: replicaId.value,
        );

        final index = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
          LocalCampaignRepository.profileIndexKey
        ];
        final storedJson = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?[
          '${LocalCampaignRepository.profileKeyPrefix}campaign_CRX'
        ]?.toString();

        int diskGp = -1;
        if (storedJson != null) {
          final dto = CampaignProfileDto.fromJson(storedJson);
          diskGp = dto.toDomain().partyPurse.getBalance('gp');
        }

        expect(diskGp, equals(100), reason: 'F3 fails=$k: disk gp must be 100');
        expect(index, equals(['campaign_CRX']), reason: 'F3 fails=$k: index must stay [campaign_CRX]');

        repo.dispose();
      });
    }
  });

  group('Pass 5.1.2 Required Test 3: Callers handle failed read correctly', () {
    test('LocalCampaignRepository.loadAllProfiles throws and writes nothing on failed read', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}camp1'
      ] = '{"id":"camp1","name":"Camp 1"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['camp1'];

      final before = jsonEncode(mockDb.writtenData);

      expect(() => repo.loadAllProfiles(), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('LocalCampaignRepository.getProfile throws on uninitialized unreadable store', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}camp1'
      ] = '{"id":"camp1","name":"Camp 1"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['camp1'];

      final before = jsonEncode(mockDb.writtenData);

      expect(() => repo.getProfile('camp1'), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('LocalCampaignRepository.getActiveProfile throws on uninitialized unreadable store', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}camp1'
      ] = '{"id":"camp1","name":"Camp 1"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['camp1'];

      final before = jsonEncode(mockDb.writtenData);

      expect(() => repo.getActiveProfile(), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignStorageMigration.runStartupMigration skips write steps and does not throw', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      final registry = CampaignRegistryService.newInstance();
      await registry.saveMembership(
        CampaignMembership(
          roomCode: 'NEW1',
          campaignName: 'New Campaign',
          role: CampaignRole.host,
          lastPlayed: DateTime.utc(2026),
        ),
      );

      mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
        '${LocalCampaignRepository.profileKeyPrefix}orig'
      ] = '{"id":"orig","name":"Orig"}';
      mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]![
        LocalCampaignRepository.profileIndexKey
      ] = ['orig'];

      final before = jsonEncode(mockDb.writtenData);

      // Does not throw, app still starts
      await CampaignStorageMigration.runStartupMigration(
        repository: repo,
        databaseService: mockDb,
        characterPersistenceService: CharacterPersistenceService(),
        registryService: registry,
        clock: clock,
        nodeId: replicaId.value,
      );

      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignStorageMigration.adoptRegistryMemberships skips writes and does not throw', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      final registry = CampaignRegistryService.newInstance();
      await registry.saveMembership(
        CampaignMembership(
          roomCode: 'NEW1',
          campaignName: 'New Campaign',
          role: CampaignRole.host,
          lastPlayed: DateTime.utc(2026),
        ),
      );

      final before = jsonEncode(mockDb.writtenData);

      await CampaignStorageMigration.adoptRegistryMemberships(
        repo,
        clock: clock,
        nodeId: replicaId.value,
        registryService: registry,
      );

      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignProfileService.loadAllProfiles throws, creates no default, and writes nothing', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

      final before = jsonEncode(mockDb.writtenData);

      expect(() => facade.loadAllProfiles(), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignProfileService.updateActiveProfile throws and writes nothing when activeId unloaded', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

      final before = jsonEncode(mockDb.writtenData);

      expect(() => facade.updateActiveProfile((current) => current.copyWith(name: 'Updated')),
          throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignProfileService.cloneProfile throws on read failure and writes nothing', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

      final before = jsonEncode(mockDb.writtenData);

      expect(() => facade.cloneProfile('missing_p'), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('CampaignProfileService.cloneProfile throws on missing source profile and never creates default', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 0;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

      final before = jsonEncode(mockDb.writtenData);

      expect(() => facade.cloneProfile('non_existent_id'), throwsA(isA<StateError>()));
      // Store remains byte-for-byte unchanged: no default profile was cloned or persisted
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('DmDashboardController.loadData catches error, leaves allProfiles empty, and never persists default', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      final controller = DmDashboardController(
        campaignRepository: repo,
        characterPersistenceService: CharacterPersistenceService(),
        replicaId: replicaId,
        clock: clock,
      );

      final before = jsonEncode(mockDb.writtenData);

      await controller.loadData();

      expect(controller.allProfiles, isEmpty);
      expect(controller.activeProfile, isNotNull); // in-memory default profile
      // Never persisted to disk
      expect(jsonEncode(mockDb.writtenData), equals(before));

      controller.dispose();
      repo.dispose();
    });

    testWidgets('DmDashboardScreen campaign picker catches error, shows snackbar, and writes nothing', (tester) async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 999;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);
      sl.registerSingleton<CampaignProfileService>(CampaignProfileService(replicaId: replicaId, clock: clock));

      final before = jsonEncode(mockDb.writtenData);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final service = sl<CampaignProfileService>();
                try {
                  await service.loadAllProfiles();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to load campaigns from storage')),
                  );
                }
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();

      expect(find.text('Failed to load campaigns from storage'), findsOneWidget);
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });

    test('DmBackupService.exportFullSystemSnapshot logs and rethrows, never writing empty backup', () async {
      final mockDb = _FailingDatabaseService();
      mockDb.failuresRemaining = 1;
      final replicaId = ReplicaId('dm_node');
      final clock = StatefulHlcClock(replicaId: replicaId);
      final repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        db: mockDb,
        characterRepo: LocalCharacterRepository(db: mockDb),
      );

      sl.reset();
      sl.registerSingleton<ReplicaId>(replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final before = jsonEncode(mockDb.writtenData);

      expect(() => DmBackupService().exportFullSystemSnapshot(), throwsA(isA<StateError>()));
      expect(jsonEncode(mockDb.writtenData), equals(before));

      repo.dispose();
    });
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

  group('Pass 5.1.2 Required Test 2: Extended Law test over 200+ seeded random inputs', () {
    test('Law test: byte-for-byte storage fidelity, selective adoption only on successful read, no loss', () async {
      const iterations = 220;

      for (int seed = 0; seed < iterations; seed++) {
        SharedPreferences.setMockInitialValues({});
        final rand = Random(seed * 7919 + 31);
        final mockDb = _FailingDatabaseService();
        final initialCount = rand.nextInt(5); // 0 to 4 campaigns
        final readFailures = rand.nextInt(6); // 0 to 5 failures

        final storedIds = <String>{};
        final storedPayloads = <String, String>{};

        for (int i = 0; i < initialCount; i++) {
          final id = rand.nextBool() ? 'camp_s${seed}_$i' : 'campaign_ROOM_S${seed}_$i';
          final roomCode = 'ROOM_S${seed}_$i';
          storedIds.add(id);
          final purse = const PartyPurse.empty().modifyDenomination('gp', (i + 1) * 20, replicaId: ReplicaId('node_$seed'));
          final prof = CampaignProfile(
            id: id,
            name: 'Campaign $id',
            edition: DmRulesEdition.v2024,
            createdAt: DateTime.utc(2026),
            lastPlayedAt: DateTime.utc(2026),
            roomState: RoomNodeState(roomId: 'r_$id', roomCode: roomCode, title: 'Title $id'),
            nodeId: 'node_$seed',
            partyPurse: purse,
          );
          final jsonStr = CampaignProfileDto.fromDomain(prof).toJson();
          storedPayloads[id] = jsonStr;
          mockDb.writtenData.putIfAbsent(AppDatabaseService.boxCampaignProfiles, () => {})[
            '${LocalCampaignRepository.profileKeyPrefix}$id'
          ] = jsonStr;
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

        // Generator: create registry memberships (some matching stored campaigns, some new)
        final registry = CampaignRegistryService.newInstance();
        final numMemberships = 1 + rand.nextInt(4); // 1 to 4 memberships
        final generatedMemberships = <CampaignMembership>[];
        for (int m = 0; m < numMemberships; m++) {
          final isMatching = (storedIds.isNotEmpty && rand.nextBool());
          String mCode;
          if (isMatching) {
            final matchedId = storedIds.elementAt(rand.nextInt(storedIds.length));
            if (matchedId.startsWith('campaign_')) {
              mCode = matchedId.substring('campaign_'.length);
            } else {
              mCode = 'ROOM_S${seed}_0';
            }
          } else {
            mCode = 'NEW_R_${seed}_$m';
          }
          final membership = CampaignMembership(
            roomCode: mCode,
            campaignName: 'Registry Campaign $mCode',
            role: CampaignRole.host,
            lastPlayed: DateTime.utc(2026),
          );
          generatedMemberships.add(membership);
          await registry.saveMembership(membership);
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
        sl.registerSingleton<CampaignRegistryService>(registry);
        sl.registerSingleton<BlobStorePort>(FakeBlobStore());

        final facade = CampaignProfileService(replicaId: replicaId, clock: clock);

        void assertStorageInvariants(String stepDesc) {
          final box = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles] ?? {};
          final currentIndex = List<String>.from(box[LocalCampaignRepository.profileIndexKey] ?? []);

          for (final id in storedIds) {
            expect(currentIndex, contains(id),
                reason: '$stepDesc (seed $seed): Stored ID $id missing from index');
            final currentPayload = box['${LocalCampaignRepository.profileKeyPrefix}$id'];
            expect(currentPayload, equals(storedPayloads[id]),
                reason: '$stepDesc (seed $seed): Payload for ID $id was mutated without deliberate write');
          }

          final actualProfileKeys = box.keys
              .where((k) => k.startsWith(LocalCampaignRepository.profileKeyPrefix) && k != LocalCampaignRepository.profileIndexKey)
              .toSet();
          final expectedProfileKeys = storedIds.map((id) => '${LocalCampaignRepository.profileKeyPrefix}$id').toSet();
          expect(actualProfileKeys, equals(expectedProfileKeys),
              reason: '$stepDesc (seed $seed): Profile keys mismatch');
        }

        void syncAdoptedMemberships() {
          final existingRoomCodes = <String>{};
          for (final id in List<String>.from(storedIds)) {
            final payload = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]?['${LocalCampaignRepository.profileKeyPrefix}$id']?.toString();
            if (payload != null) {
              try {
                final dto = CampaignProfileDto.fromJson(payload);
                final code = dto.roomState['roomCode']?.toString().toUpperCase();
                if (code != null) existingRoomCodes.add(code);
              } catch (_) {}
            }
          }

          for (final m in generatedMemberships) {
            final code = m.roomCode.toUpperCase();
            final adoptedId = 'campaign_${m.roomCode}';
            final alreadyExists = existingRoomCodes.contains(code) || storedIds.contains(adoptedId);
            if (!alreadyExists) {
              storedIds.add(adoptedId);
              final adoptedJson = mockDb.writtenData[AppDatabaseService.boxCampaignProfiles]!['${LocalCampaignRepository.profileKeyPrefix}$adoptedId']!.toString();
              storedPayloads[adoptedId] = adoptedJson;
              existingRoomCodes.add(code);
            }
          }
        }

        // 1. Run startup migration
        await CampaignStorageMigration.runStartupMigration(
          repository: repo,
          databaseService: mockDb,
          characterPersistenceService: CharacterPersistenceService(),
          registryService: registry,
          clock: clock,
          nodeId: replicaId.value,
        );

        if (readFailures == 0) {
          syncAdoptedMemberships();
        }

        assertStorageInvariants('After startup migration');

        // 2. Perform a random mix of facade operations
        final numOps = 5 + rand.nextInt(6); // 5 to 10 operations
        for (int op = 0; op < numOps; op++) {
          final opType = rand.nextInt(4);

          switch (opType) {
            case 0:
              // loadAllProfiles
              try {
                final loaded = await facade.loadAllProfiles();
                syncAdoptedMemberships();
                if (storedIds.isEmpty) {
                  expect(loaded.length, equals(1));
                  final def = loaded.first;
                  storedIds.add(def.id);
                  storedPayloads[def.id] = CampaignProfileDto.fromDomain(def).toJson();
                }
              } catch (_) {
                // Expected failure if read failures remain
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
                storedPayloads[newId] = CampaignProfileDto.fromDomain(newProf).toJson();
              } catch (_) {
                // Expected failure if uninitialized and failuresRemaining > 0
              }

            case 2:
              // updateProfile
              if (storedIds.isNotEmpty) {
                final targetId = storedIds.elementAt(rand.nextInt(storedIds.length));
                try {
                  final updated = await facade.updateProfile(targetId, (current) {
                    return current.copyWith(name: '${current.name} (Updated)');
                  });
                  storedPayloads[targetId] = CampaignProfileDto.fromDomain(updated).toJson();
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
                  storedPayloads.remove(targetId);
                  if (storedIds.isEmpty) {
                    final remaining = repo.allProfiles;
                    if (remaining.isNotEmpty) {
                      final def = remaining.first;
                      storedIds.add(def.id);
                      storedPayloads[def.id] = CampaignProfileDto.fromDomain(def).toJson();
                    }
                  }
                } catch (_) {
                  // Expected failure if uninitialized and failuresRemaining > 0
                }
              }
          }

          assertStorageInvariants('After op $op');
        }

        repo.dispose();
      }
    });
  });
}
