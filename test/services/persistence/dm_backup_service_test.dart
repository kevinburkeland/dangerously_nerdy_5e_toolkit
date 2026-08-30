import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/dm_backup_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DmBackupService', () {
    late DmBackupService backupService;
    late CampaignProfileService campaignService;
    late HomebrewPersistenceService homebrewService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backupService = DmBackupService();
      campaignService = CampaignProfileService();
      campaignService.clearCacheForTesting();
      homebrewService = HomebrewPersistenceService();
    });

    test('validates valid campaign payload format', () {
      final validJson = json.encode({
        'schemaVersion': 1,
        'appVersion': '1.0.0',
        'type': 'campaign_profile',
        'campaign': {
          'id': 'c1',
          'name': 'Curse of Strahd',
        }
      });

      final report = backupService.validatePayload(validJson);
      expect(report.isValid, isTrue);
      expect(report.status, equals(ImportValidationStatus.valid));
      expect(report.payloadType, equals('campaign_profile'));
    });

    test('rejects corrupted and malformed JSON payloads', () {
      const invalidJson = '{ not valid json }';
      final report = backupService.validatePayload(invalidJson);
      expect(report.isValid, isFalse);
      expect(report.status, equals(ImportValidationStatus.corrupt));
      expect(report.errors.first, contains('JSON parse error'));
    });

    test('exports and restores full system master backup', () async {
      // 1. Seed data
      final profile = CampaignProfile.defaultProfile(name: 'Dragonlance');
      await campaignService.saveProfileImmediate(profile);

      final spell = Spell(
        id: const EntityId(slug: 'time-stop-plus', ruleset: RulesetVersion.v2024),
        name: 'Time Stop Plus',
        level: 9,
        school: 'Transmutation',
        castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
        duration: const SpellDuration(type: DurationType.instantaneous),
        range: 'Self',
        components: const SpellComponents(v: true),
        descriptionMarkdown: 'Freezes time for 1 minute.',
      );
      await homebrewService.saveCustomSpell(spell);

      // 2. Export full system
      final fullBackupJson = await backupService.exportFullSystemSnapshot();
      expect(fullBackupJson, contains('full_system_snapshot'));
      expect(fullBackupJson, contains('Dragonlance'));
      expect(fullBackupJson, contains('time-stop-plus'));

      // 3. Clear data
      await homebrewService.clearAllHomebrew();
      campaignService.clearCacheForTesting();

      // 4. Restore full system
      final restoreSuccess = await backupService.restoreFullSystemSnapshot(fullBackupJson);
      expect(restoreSuccess, isTrue);

      final restoredProfiles = await campaignService.loadAllProfiles();
      expect(restoredProfiles.any((p) => p.name == 'Dragonlance'), isTrue);

      final restoredSpells = await homebrewService.loadCustomSpells();
      expect(restoredSpells.any((s) => s.id.slug == 'time-stop-plus'), isTrue);
    });
  });
}
