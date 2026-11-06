import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/main.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('startup_mig_char_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('Startup Migration Characterization Test', () {
    test(
        'runStartupMigration() extracts embedded character and adopts registry membership stamped with DI ReplicaId',
        () async {
      await initServiceLocator();

      final db = sl<AppDatabaseService>();
      final diReplicaId = sl<ReplicaId>();
      final repo = sl<ICampaignRepository>();

      // 1. Create a legacy campaign with an embedded character map
      const hero = Character(
        id: EntityId(slug: 'strider-ranger', ruleset: RulesetVersion.v2024),
        name: 'Strider',
        speciesRef: EntityReference.empty(
          slug: 'human',
          refType: EntityType.species,
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 28),
      );
      final heroDto = CharacterDto.fromDomain(hero);

      final legacyRawMap = {
        'id': 'camp_embedded_char',
        'name': 'The Prancing Pony',
        'edition': 'v2024',
        'createdAt': DateTime.utc(2024, 7, 1).toIso8601String(),
        'lastPlayedAt': DateTime.utc(2024, 7, 1).toIso8601String(),
        'partyCharacterIds': [heroDto.toMap()],
        'roomState': {
          'roomId': 'r_pony',
          'roomCode': 'PONY-1',
          'title': 'Bree Room',
        },
        'nodeId': 'old_node',
      };

      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp_embedded_char'],
      );
      await db.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_embedded_char',
        jsonEncode(legacyRawMap),
      );

      // 2. Add an un-adopted registry membership
      final registry = CampaignRegistryService();
      await registry.saveMembership(CampaignMembership(
        roomCode: 'ADOPT-ROOM',
        campaignName: 'Adopted Stronghold',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      // 3. Run migration through the composition root, relying strictly on DI
      await runStartupMigrationFromServices();

      // Verify character was extracted into CharacterPersistenceService
      final charService = CharacterPersistenceService();
      final chars = await charService.loadCharacters();
      expect(chars.any((c) => c.id.slug == 'strider-ranger'), isTrue);

      // Verify legacy profile was cleaned up
      final diskRaw = db.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_embedded_char',
      ) as String;
      final diskMap = jsonDecode(diskRaw) as Map<String, dynamic>;
      final diskParty = diskMap['partyCharacterIds'] as List;
      expect(diskParty, contains('strider-ranger'));
      expect(diskParty.every((item) => item is String), isTrue);

      // Verify adopted profile exists in repository and is stamped with DI ReplicaId
      final allProfiles = await repo.loadAllProfiles();
      final adopted = allProfiles
          .firstWhere((p) => p.roomState.roomCode == 'ADOPT-ROOM');
      expect(adopted.name, equals('Adopted Stronghold'));
      expect(adopted.nameRegister.timestamp.nodeId, equals(diReplicaId.value));
    });
  });
}
