import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import '../../test_doubles/fake_blob_store.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DM Screen Flows Through Facade Test', () {
    late LocalCampaignRepository repo;
    late ReplicaId replicaId;
    late StatefulHlcClock clock;
    late CharacterPersistenceService charService;
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUp('dm_facade_');
      sl.reset();

      replicaId = ReplicaId('dm_screen_flow_node');
      sl.registerSingleton<ReplicaId>(replicaId);
      clock = StatefulHlcClock(replicaId: replicaId);
      sl.registerSingleton<StatefulHlcClock>(clock);

      final charRepo = LocalCharacterRepository();
      sl.registerSingleton<LocalCharacterRepository>(charRepo);
      charService = CharacterPersistenceService();

      repo = LocalCampaignRepository(
        replicaId: replicaId,
        clock: clock,
        characterRepo: charRepo,
      );
      sl.registerSingleton<ICampaignRepository>(repo);
      sl.registerSingleton<BlobStorePort>(FakeBlobStore());
    });

    tearDown(() async {
      repo.dispose();
      sl.reset();
      await harness.tearDown();
    });

    test('Create, clone, delete, switch via facade then DmDashboardController.loadData reflects exact state', () async {
      final facade = CampaignProfileService();

      // 1. Create Profile Alpha
      final alpha = await facade.createProfile(name: 'Campaign Alpha');
      expect(alpha.name, equals('Campaign Alpha'));

      // 2. Clone Profile Alpha into Cloned Alpha
      final cloned = await facade.cloneProfile(alpha.id, 'Campaign Alpha Cloned');
      expect(cloned.name, equals('Campaign Alpha Cloned'));
      expect(cloned.id, isNot(equals(alpha.id)));

      // 3. Create Profile Beta
      final beta = await facade.createProfile(name: 'Campaign Beta');
      expect(beta.name, equals('Campaign Beta'));

      // 4. Switch to Alpha
      await facade.switchProfile(alpha.id);
      expect((await facade.getActiveProfile())?.id, equals(alpha.id));

      // 5. Delete Alpha (which is active) -> facade deletes and switches active to remaining profile
      await facade.deleteProfile(alpha.id);

      // Verify via DmDashboardController reading through ICampaignRepository
      final controller = DmDashboardController(
        campaignRepository: repo,
        characterPersistenceService: charService,
        replicaId: replicaId,
        clock: clock,
      );
      addTearDown(controller.dispose);

      await controller.loadData();

      final controllerProfileNames = controller.allProfiles.map((p) => p.name).toList();
      expect(controllerProfileNames, containsAll(['Campaign Alpha Cloned', 'Campaign Beta']));
      expect(controllerProfileNames, isNot(contains('Campaign Alpha')));
      expect(controller.allProfiles.length, equals(2));

      // Active campaign should be one of the remaining profiles
      expect(controller.activeProfile?.id, isIn([cloned.id, beta.id]));

      // 6. Switch to Beta through facade, controller reflects it
      await facade.switchProfile(beta.id);
      await controller.loadData(initialCampaignId: beta.id);
      expect(controller.activeProfile?.id, equals(beta.id));
      expect(controller.activeProfile?.name, equals('Campaign Beta'));
    });
  });
}
