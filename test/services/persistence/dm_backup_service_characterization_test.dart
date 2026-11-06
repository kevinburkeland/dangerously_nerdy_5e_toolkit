import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';

import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('dm_backup_char_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('DmBackupService Characterization Test', () {
    test(
        'whatever DmBackupService stamps with a clock uses the DI clock replica id',
        () async {
      await initServiceLocator();

      final diClock = sl<StatefulHlcClock>();
      final campaignService = CampaignProfileService();
      final backupService = DmBackupService();

      // Create a profile, then update its name to empty string
      final profile = await campaignService.createProfile(name: 'Initial Campaign');
      final emptyNameProfile = await campaignService.updateProfile(
        profile.id,
        (current) => current.copyWith(
          name: '',
          nameTimestamp: diClock.nextTimestamp(),
        ),
      );

      final exportJson = backupService.exportProfileJson(emptyNameProfile);

      // Import via DmBackupService() without passing an explicit clock
      final imported = await backupService.validateAndImportProfile(exportJson);

      expect(imported, isNotNull);
      expect(imported!.name, equals('Imported Campaign'));
      expect(imported.nameRegister.timestamp.nodeId,
          equals(diClock.replicaId.value));
    });
  });
}
