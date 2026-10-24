import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Pass 9 — R5: Stored Campaign Record Versioning', () {
    late StatefulHlcClock clock;
    late AppDatabaseService db;
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUp('pass9_r5_');
      await initServiceLocator();
      clock = sl<StatefulHlcClock>();
      db = sl<AppDatabaseService>();
    });

    tearDown(() async {
      sl.reset();
      await harness.tearDown();
    });

    test('1. Legacy record with no recordVersion loads exactly as before (assert field by field)', () {
      final legacyRawMap = <String, dynamic>{
        // NO 'recordVersion' field
        'id': 'legacy_campaign_kevin',
        'name': 'The Kevin Campaign',
        'edition': 'v2024',
        'createdAt': '2025-01-01T12:00:00.000Z',
        'lastPlayedAt': '2025-01-02T15:30:00.000Z',
        'notesMarkdown': '# Historical Notes\nWritten in the ancient times.',
        'partyCharacterIds': ['char_thorin', 'char_elrond'],
        'pinnedRuleIds': ['cover', 'grappling'],
        'roomState': {
          'roomId': 'room_CR-101',
          'roomCode': 'CR-101',
          'title': 'Ancient Chamber',
          'activeEncounter': [
            {
              'participantId': 'part_1',
              'entityLink': {
                'refType': 'monster',
                'entityId': 'goblin_archer',
                'displayName': 'Goblin Archer',
              },
              'currentHp': 7,
              'maxHp': 7,
              'initiativeScore': 15,
            }
          ],
          'activeMinions': [
            {
              'id': 'minion_1',
              'name': 'Dancing Dagger',
              'size': 'tiny',
              'currentHp': 20,
              'maxHp': 20,
            }
          ],
        },
        'partyPurse': {
          'cp': 50,
          'sp': 20,
          'gp': 150,
          'pp': 2,
        },
      };

      final dto = CampaignProfileDto.fromMap(legacyRawMap);
      expect(dto.recordVersion, equals(0), reason: 'Absence of recordVersion means legacy record (0)');

      final domain = dto.toDomain();
      expect(domain.id, equals('legacy_campaign_kevin'));
      expect(domain.name, equals('The Kevin Campaign'));
      expect(domain.edition, equals(RulesetEdition.v2024));
      expect(domain.createdAt.toUtc().toIso8601String(), equals('2025-01-01T12:00:00.000Z'));
      expect(domain.lastPlayedAt.toUtc().toIso8601String(), equals('2025-01-02T15:30:00.000Z'));
      expect(domain.notesMarkdown, equals('# Historical Notes\nWritten in the ancient times.'));
      expect(domain.partyCharacterIds, containsAll(['char_thorin', 'char_elrond']));
      expect(domain.pinnedRuleIds, containsAll(['cover', 'grappling']));
      expect(domain.roomState.roomId, equals('room_CR-101'));
      expect(domain.roomState.roomCode, equals('CR-101'));
      expect(domain.roomState.title, equals('Ancient Chamber'));
      expect(domain.roomState.activeEncounter.length, equals(1));
      expect(domain.roomState.activeEncounter.first.entityLink.displayName, equals('Goblin Archer'));
      expect(domain.roomState.activeEncounter.first.currentHp, equals(7));
      expect(domain.roomState.activeMinions.length, equals(1));
      expect(domain.roomState.activeMinions.first.name, equals('Dancing Dagger'));
      expect(domain.partyPurse.gp, equals(150));
      expect(domain.partyPurse.sp, equals(20));
      expect(domain.partyPurse.cp, equals(50));
      expect(domain.partyPurse.pp, equals(2));
    });

    test('2. Round trip writes recordVersion: 1 and reads back equal', () {
      final base = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Versioned Campaign',
      );
      final profile = base.copyWith(
        id: 'camp_v1_rt',
        notesRegister: CrdtLwwRegister(
          value: 'Version 1 notes',
          timestamp: clock.nextTimestamp(),
        ),
      );

      final dto = CampaignProfileDto.fromDomain(profile);
      final map = dto.toMap();

      expect(map['recordVersion'], equals(1), reason: 'toMap must explicitly write recordVersion: 1');

      final readDto = CampaignProfileDto.fromMap(map);
      expect(readDto.recordVersion, equals(1));

      final restored = readDto.toDomain();
      expect(restored.id, equals(profile.id));
      expect(restored.name, equals(profile.name));
      expect(restored.notesMarkdown, equals(profile.notesMarkdown));
      expect(restored.notesRegister.timestamp, equals(profile.notesRegister.timestamp));
    });

    test('3. recordVersion: 2 is not loaded, preserved on disk, index, and after new write', () async {
      final repo = LocalCampaignRepository(
        db: db,
        clock: clock,
        replicaId: clock.replicaId,
      );

      // Seed storage with a valid campaign v1 and a future campaign v2
      final validV1 = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Valid V1 Campaign',
      ).copyWith(id: 'camp_v1');

      final futureV2Map = <String, dynamic>{
        'recordVersion': 2,
        'id': 'camp_v2_future',
        'name': 'Future V2 Campaign',
        'edition': 'v2024',
        'createdAt': DateTime.now().toIso8601String(),
        'lastPlayedAt': DateTime.now().toIso8601String(),
      };

      await db.putAll(
        AppDatabaseService.boxCampaignProfiles,
        {
          '${LocalCampaignRepository.profileKeyPrefix}camp_v1':
              CampaignProfileDto.fromDomain(validV1).toJson(),
          '${LocalCampaignRepository.profileKeyPrefix}camp_v2_future':
              json.encode(futureV2Map),
          LocalCampaignRepository.profileIndexKey: ['camp_v1', 'camp_v2_future'],
        },
      );

      // 1. Initial load
      final loaded = await repo.loadAllProfiles();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('camp_v1'));
      expect(loaded.any((p) => p.id == 'camp_v2_future'), isFalse,
          reason: 'recordVersion 2 must be refused and not shown');

      // 2. Still exists in storage after reload
      final rawV2OnDisk = db.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_v2_future',
      );
      expect(rawV2OnDisk, isNotNull);
      expect(rawV2OnDisk.toString(), contains('Future V2 Campaign'));

      // 3. Write another campaign to trigger index re-persistence
      final newV1 = CampaignProfile.defaultProfile(
        nodeId: clock.replicaId.value,
        clock: clock,
        name: 'Another V1 Campaign',
      ).copyWith(id: 'camp_v1_second');

      await repo.putProfile(newV1);

      // Verify future campaign still exists in storage and stays in the index
      final rawV2AfterWrite = db.get(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp_v2_future',
      );
      expect(rawV2AfterWrite, isNotNull, reason: 'v2 record must not be deleted or overwritten');

      final indexAfterWrite = db.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      );
      expect(indexAfterWrite, isA<List>());
      final indexList = (indexAfterWrite as List).cast<String>();
      expect(indexList, contains('camp_v2_future'),
          reason: 'v2 record id must remain in the persistent index');
      expect(indexList, contains('camp_v1'));
      expect(indexList, contains('camp_v1_second'));
    });
  });
}
