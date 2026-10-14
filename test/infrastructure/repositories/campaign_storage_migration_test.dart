import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCampaignRepository repo;
  late ReplicaId replicaId;
  late StatefulHlcClock clock;
  late CharacterPersistenceService charService;
  late AppDatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabaseService.instance;
    await db.resetForTesting();
    sl.reset();

    replicaId = ReplicaId('migration_test_node');
    sl.registerSingleton<ReplicaId>(replicaId);
    clock = StatefulHlcClock(replicaId: replicaId);
    sl.registerSingleton<StatefulHlcClock>(clock);

    final charRepo = LocalCharacterRepository(db: db);
    sl.registerSingleton<LocalCharacterRepository>(charRepo);
    charService = CharacterPersistenceService();

    repo = LocalCampaignRepository(
      replicaId: replicaId,
      clock: clock,
      db: db,
      characterRepo: charRepo,
    );
    sl.registerSingleton<ICampaignRepository>(repo);
  });

  tearDown(() {
    repo.dispose();
    sl.reset();
  });

  group('Campaign Storage Legacy Migrations', () {
    test('Step 1: Prefs-only record ends up in Hive and loads', () async {
      final prefs = await SharedPreferences.getInstance();

      // Old-shape campaign in SharedPreferences only
      final prefsProfileMap = {
        'id': 'camp_prefs_1',
        'name': 'Prefs Only Campaign',
        'edition': 'v2024',
        'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2025, 1, 1).toIso8601String(),
        'partyCharacterIds': <String>[],
        'roomState': {
          'roomId': 'r_prefs',
          'roomCode': 'PREFS-1',
          'title': 'Prefs Room',
        },
        'nodeId': 'prefs_node',
      };

      // Set in prefs only; Hive is completely empty
      await prefs.setStringList(LocalCampaignRepository.profileIndexKey, ['camp_prefs_1']);
      await prefs.setString(
        '${LocalCampaignRepository.profileKeyPrefix}camp_prefs_1',
        jsonEncode(prefsProfileMap),
      );

      // Verify Hive doesn't have it yet
      expect(db.get(AppDatabaseService.boxCampaignProfiles, LocalCampaignRepository.profileIndexKey), isNull);

      // Load via repository
      final loaded = await repo.loadAllProfiles();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('camp_prefs_1'));
      expect(loaded.first.name, equals('Prefs Only Campaign'));

      // Verify it was copied into Hive
      final hiveRaw = db.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_prefs_1',
      );
      expect(hiveRaw, isNotNull);
    });

    test('Step 2: Embedded legacy characters saved to character service and profile re-saved without them', () async {
      const hero = Character(
        id: EntityId(slug: 'aragorn-strider', ruleset: RulesetVersion.v2024),
        name: 'Aragorn Strider',
        speciesRef: EntityReference.empty(slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 35),
      );

      final heroDto = CharacterDto.fromDomain(hero);

      // Old-shape fixture: full character map inside partyCharacterIds
      final legacyRawMap = {
        'id': 'camp_legacy_party',
        'name': 'Fellowship Table',
        'edition': 'v2024',
        'createdAt': DateTime.utc(2024, 6, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 6, 1).toIso8601String(),
        'partyCharacterIds': [heroDto.toMap()], // Embedded map fixture
        'roomState': {
          'roomId': 'r_fellowship',
          'roomCode': 'FELLOW-1',
          'title': 'Fellowship Room',
        },
        'nodeId': 'genesis_node',
      };

      // Put legacy record directly in storage box
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp_legacy_party'],
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_legacy_party',
        jsonEncode(legacyRawMap),
      );

      // Verify CharacterPersistenceService has zero characters initially
      final initialChars = await charService.loadCharacters();
      expect(initialChars.any((c) => c.id.slug == 'aragorn-strider'), isFalse);

      // Run migration
      await CampaignStorageMigration.migrateLegacyCharacters(
        repo: repo,
        db: db,
        characterPersistenceService: charService,
      );

      // 1. Verify character is now saved in CharacterPersistenceService
      final migratedChars = await charService.loadCharacters();
      expect(migratedChars.any((c) => c.id.slug == 'aragorn-strider'), isTrue);

      // 2. Verify profile is re-saved on disk without embedded character maps
      final diskRaw = db.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_legacy_party',
      ) as String;
      final diskMap = jsonDecode(diskRaw) as Map<String, dynamic>;

      // partyCharacterIds must now only contain string IDs, not Maps
      final diskParty = diskMap['partyCharacterIds'] as List;
      expect(diskParty, contains('aragorn-strider'));
      for (final item in diskParty) {
        expect(item, isA<String>());
      }
    });

    test('Step 3: Registry membership with no profile gets one; later membership adopted on loadAllProfiles', () async {
      final reg = CampaignRegistryService.newInstance();

      // Membership present at startup
      await reg.saveMembership(CampaignMembership(
        roomCode: 'REG-ALPHA',
        campaignName: 'Alpha Citadel',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      // Startup adoption
      await CampaignStorageMigration.adoptRegistryMemberships(
        repo,
        clock: clock,
        nodeId: replicaId.value,
        registryService: reg,
        characterPersistenceService: charService,
      );

      final profilesAfterStartup = await repo.loadAllProfiles();
      expect(profilesAfterStartup.any((p) => p.name == 'Alpha Citadel'), isTrue);
      expect(profilesAfterStartup.any((p) => p.roomState.roomCode == 'REG-ALPHA'), isTrue);

      // Add a second membership mid-session (after startup)
      await reg.saveMembership(CampaignMembership(
        roomCode: 'REG-BETA',
        campaignName: 'Beta Outpost',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      // Facade loadAllProfiles triggers adoption
      final facade = CampaignProfileService();
      final profilesAfterFacadeLoad = await facade.loadAllProfiles();

      expect(profilesAfterFacadeLoad.any((p) => p.name == 'Beta Outpost'), isTrue);
      expect(profilesAfterFacadeLoad.any((p) => p.roomState.roomCode == 'REG-BETA'), isTrue);
    });

    test('Adoption & migration are idempotent; edit made between runs survives second run', () async {
      final reg = CampaignRegistryService.newInstance();
      await reg.saveMembership(CampaignMembership(
        roomCode: 'IDEM-ROOM',
        campaignName: 'Idempotence Keep',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      // First run
      await CampaignStorageMigration.runStartupMigration(
        repository: repo,
        databaseService: db,
        clock: clock,
        nodeId: replicaId.value,
        registryService: reg,
        characterPersistenceService: charService,
      );

      final profilesAfterFirst = await repo.loadAllProfiles();
      final keepProfile = profilesAfterFirst.firstWhere((p) => p.roomState.roomCode == 'IDEM-ROOM');
      expect(keepProfile.name, equals('Idempotence Keep'));

      // Edit made between two runs
      await repo.updateProfile(keepProfile.id, (p) => p.copyWith(
        notesMarkdown: 'Modified secret notes between migration runs',
        notesTimestamp: clock.nextTimestamp(),
      ));

      // Second run of migration
      await CampaignStorageMigration.runStartupMigration(
        repository: repo,
        databaseService: db,
        clock: clock,
        nodeId: replicaId.value,
        registryService: reg,
        characterPersistenceService: charService,
      );

      final profilesAfterSecond = await repo.loadAllProfiles();
      final keepAfterSecond = profilesAfterSecond.firstWhere((p) => p.id == keepProfile.id);

      // Edit survived!
      expect(keepAfterSecond.notesMarkdown, equals('Modified secret notes between migration runs'));
      // Profile was not duplicated or overwritten
      expect(profilesAfterSecond.where((p) => p.id == keepProfile.id).length, equals(1));
    });
  });
}
