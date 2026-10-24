// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';

import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final harness = HiveTestHarness();
  late StatefulHlcClock clock;
  late LocalCampaignRepository repo;
  late ReplicaId replicaId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUp('two_cache_t1_');

    sl.reset();
    replicaId = ReplicaId('dm_node_t1');
    sl.registerSingleton<ReplicaId>(replicaId);
    clock = StatefulHlcClock(replicaId: replicaId);
    sl.registerSingleton<StatefulHlcClock>(clock);

    final charRepo = LocalCharacterRepository();
    sl.registerSingleton<LocalCharacterRepository>(charRepo);

    repo = LocalCampaignRepository(
      replicaId: replicaId,
      clock: clock,
      characterRepo: charRepo,
    );
    sl.registerSingleton<ICampaignRepository>(repo);
  });

  tearDown(() async {
    repo.dispose();
    sl.reset();
    await harness.tearDown();
  });

  CampaignProfile createCampaignA() {
    final heroRoster = const CrdtOrSet<String>.empty().add('hero', 'hero', clock.nextTimestamp());
    return CampaignProfile(
      id: 'camp_A',
      name: 'Campaign A',
      edition: DmRulesEdition.v2024,
      createdAt: DateTime.utc(2026),
      lastPlayedAt: DateTime.utc(2026),
      partyRoster: heroRoster,
      roomState: RoomNodeState(roomId: 'rA', roomCode: 'ROOM-A', title: 'Room A'),
      nodeId: replicaId.value,
    );
  }

  int readDiskGold(String campaignId) {
    final box = Hive.box<dynamic>(AppDatabaseService.boxCampaignProfiles);
    final rawJson = box.get('${LocalCampaignRepository.profileKeyPrefix}$campaignId') as String?;
    if (rawJson == null) return -1;
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    final dto = CampaignProfileDto.fromMap(map);
    return dto.toDomain().partyPurse.getBalance('gp');
  }

  int readDiskEventCount(String campaignId) {
    final box = Hive.box<dynamic>(AppDatabaseService.boxCampaignProfiles);
    final rawJson = box.get('${LocalCampaignRepository.profileKeyPrefix}$campaignId') as String?;
    if (rawJson == null) return -1;
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    final dto = CampaignProfileDto.fromMap(map);
    return dto.toDomain().changeLog.length;
  }

  group('T1 Regression: One Owner for Campaign Records (Real Hive)', () {
    test('Control (twoCaches=false): both edits through repository survive', () async {
      await repo.putProfile(createCampaignA());
      await repo.setActiveProfileId('camp_A');
      await repo.loadAllProfiles();

      // Inbound purse merge adds 100 gp
      await repo.updateProfile('camp_A', (p) => p.copyWith(
        partyPurse: p.partyPurse.modifyDenomination('gp', 100, replicaId: replicaId),
      ));

      // Event logged through repository updateProfile
      final evt = PartyEvent(
        id: 'evt_1',
        roomCode: 'ROOM-A',
        type: 'milestone',
        playerName: 'Hero',
        details: 'Hero reached level 2',
        timestamp: DateTime.now(),
      );
      await repo.updateProfile('camp_A', (p) => p.copyWith(
        changeLog: [evt, ...p.changeLog],
      ));

      final diskGp = readDiskGold('camp_A');
      final eventCount = readDiskEventCount('camp_A');
      print('T1 twoCaches=false disk gp=$diskGp (expected 100) events=$eventCount (expected 1)');
      expect(diskGp, equals(100));
      expect(eventCount, equals(1));
    });

    test('T1 (twoCaches=true facade): merge then logCampaignEvent both survive', () async {
      final facade = CampaignProfileService();
      await repo.putProfile(createCampaignA());
      await repo.setActiveProfileId('camp_A');
      await facade.loadAllProfiles();

      // Inbound purse merge adds 100 gp through LocalCampaignRepository
      await repo.updateProfile('camp_A', (p) => p.copyWith(
        partyPurse: p.partyPurse.modifyDenomination('gp', 100, replicaId: replicaId),
      ));

      // Character sheet calls logCampaignEvent on CampaignProfileService facade
      await facade.logCampaignEvent(
        characterId: 'hero',
        characterName: 'Hero',
        type: 'milestone',
        details: 'Hero reached level 2',
      );

      final diskGp = readDiskGold('camp_A');
      final eventCount = readDiskEventCount('camp_A');
      print('T1 twoCaches=true  disk gp=$diskGp (expected 100) events=$eventCount (expected 1)');
      expect(diskGp, equals(100));
      expect(eventCount, equals(1));
    });

    test('T1 reverse order: logCampaignEvent then merge both survive', () async {
      final facade = CampaignProfileService();
      await repo.putProfile(createCampaignA());
      await repo.setActiveProfileId('camp_A');
      await facade.loadAllProfiles();

      // Character sheet calls logCampaignEvent first
      await facade.logCampaignEvent(
        characterId: 'hero',
        characterName: 'Hero',
        type: 'milestone',
        details: 'Hero reached level 2',
      );

      // Then inbound purse merge adds 100 gp
      await repo.updateProfile('camp_A', (p) => p.copyWith(
        partyPurse: p.partyPurse.modifyDenomination('gp', 100, replicaId: replicaId),
      ));

      final diskGp = readDiskGold('camp_A');
      final eventCount = readDiskEventCount('camp_A');
      print('T1 reverse order disk gp=$diskGp (expected 100) events=$eventCount (expected 1)');
      expect(diskGp, equals(100));
      expect(eventCount, equals(1));
    });
  });
}
