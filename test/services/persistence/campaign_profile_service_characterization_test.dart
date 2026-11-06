import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';

import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/hive_test_harness.dart';

class RecordingBlobStore extends FakeBlobStore {
  final List<String> releasedCampaigns = [];

  @override
  Future<void> releaseCampaign(String campaignId) async {
    releasedCampaigns.add(campaignId);
    await super.releaseCampaign(campaignId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('camp_prof_char_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('CampaignProfileService Characterization Test', () {
    test(
        'profile created through CampaignProfileService() is visible via repository, stamps node ID with DI clock, logs events, and releaseCampaign on delete',
        () async {
      final fakeBlobStore = RecordingBlobStore();
      await initServiceLocator(blobStore: fakeBlobStore);

      final service = CampaignProfileService();
      final repo = sl<ICampaignRepository>();
      final diClock = sl<StatefulHlcClock>();

      // 1. Profile created is visible through sl<ICampaignRepository>()
      final profile =
          await service.createProfile(name: 'Sword Coast Expedition');
      final fetched = await repo.getProfile(profile.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Sword Coast Expedition'));

      // 2. Node id it uses equals the DI StatefulHlcClock's replica id
      expect(profile.nameRegister.timestamp.nodeId,
          equals(diClock.replicaId.value));

      // 3. logCampaignEvent writes one event through that repository
      await service.updateProfile(
        profile.id,
        (current) => current.copyWith(partyCharacterIds: ['hero_1']),
      );

      await service.logCampaignEvent(
        characterId: 'hero_1',
        characterName: 'Thorin',
        type: 'combat_action',
        details: 'Attacked goblin with warhammer',
      );

      final afterLog = await repo.getProfile(profile.id);
      expect(afterLog, isNotNull);
      expect(afterLog!.changeLog.length, equals(1));
      expect(afterLog.changeLog.first.type, equals('combat_action'));
      expect(afterLog.changeLog.first.details,
          equals('Attacked goblin with warhammer'));

      // 4. Deleting a profile asks the registered BlobStorePort to release that campaign
      await service.deleteProfile(profile.id);
      expect(fakeBlobStore.releasedCampaigns, contains(profile.id));
    });
  });
}
