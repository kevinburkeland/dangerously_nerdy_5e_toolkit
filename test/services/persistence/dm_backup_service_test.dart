import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/dm_backup_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
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
          'name': 'Shadows of the Vampire',
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

    test('exports and restores full system master backup with all potential homebrew categories', () async {
      // 1. Seed data across all categories
      final profile = CampaignProfile.defaultProfile(name: 'Dragonfire');
      await campaignService.saveProfileImmediate(profile);

      const spell = Spell(
        id: EntityId(slug: 'time-stop-plus', ruleset: RulesetVersion.v2024),
        name: 'Time Stop Plus',
        level: 9,
        school: 'Transmutation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: 'Self',
        components: SpellComponents(v: true),
        descriptionMarkdown: 'Freezes time for 1 minute.',
      );
      await homebrewService.saveCustomSpell(spell);

      const monster = Monster(
        id: EntityId(slug: 'void-drake', ruleset: RulesetVersion.v2024),
        name: 'Void Drake',
        size: 'Large',
        monsterType: 'Dragon',
        alignment: 'Chaotic Neutral',
        armorClass: 17,
        hitPoints: 120,
        hitDieFormula: '16d10 + 32',
        challengeRating: '8',
        actionsMarkdown: '**Void Breath**: 8d6 necrotic damage.',
      );
      await homebrewService.saveCustomMonster(monster);

      const item = EquipmentItem(
        id: EntityId(slug: 'blade-of-eternity', ruleset: RulesetVersion.v2024),
        name: 'Blade of Eternity',
        itemType: 'Weapon',
        rarity: 'Legendary',
        requiresAttunement: false,
        descriptionMarkdown: 'Slays immortal beings.',
      );
      await homebrewService.saveCustomItem(item);

      const cl = CharacterClass(
        id: EntityId(slug: 'chronomancer', ruleset: RulesetVersion.v2024),
        name: 'Chronomancer',
        hitDie: 'd8',
        featuresMarkdown: 'Master of temporal threads.',
      );
      await homebrewService.saveCustomClass(cl);

      const sub = Subclass(
        id: EntityId(slug: 'time-weaver', ruleset: RulesetVersion.v2024),
        name: 'Time Weaver',
        classSlug: 'chronomancer',
        shortName: 'Weaver',
        featuresMarkdown: 'Rewind fate once per rest.',
      );
      await homebrewService.saveCustomSubclass(sub);

      const subrace = Subrace(
        id: EntityId(slug: 'astral-human', ruleset: RulesetVersion.v2024),
        name: 'Astral Human',
        raceSlug: 'human-custom',
        traitsMarkdown: 'Floating speed 30 ft.',
      );
      final race = Race(
        id: const EntityId(slug: 'human-custom', ruleset: RulesetVersion.v2024),
        name: 'Custom Human',
        traitsMarkdown: 'Versatile.',
        subraces: const [subrace],
      );
      await homebrewService.saveCustomRace(race);

      const feat = Feat(
        id: EntityId(slug: 'temporal-reflexes', ruleset: RulesetVersion.v2024),
        name: 'Temporal Reflexes',
        descriptionMarkdown: '+5 to initiative.',
      );
      await homebrewService.saveCustomFeat(feat);

      const bg = Background(
        id: EntityId(slug: 'time-traveler', ruleset: RulesetVersion.v2024),
        name: 'Time Traveler',
        descriptionMarkdown: 'From the far future.',
      );
      await homebrewService.saveCustomBackground(bg);

      const other = HomebrewCompendiumEntry(
        id: EntityId(slug: 'madness-table', ruleset: RulesetVersion.v2024),
        name: 'Temporal Madness',
        category: 'tables',
        descriptionMarkdown: 'Roll 1d20 for temporal delirium.',
      );
      await homebrewService.saveCustomOtherEntry(other);

      // 2. Export full system
      final fullBackupJson = await backupService.exportFullSystemSnapshot();
      expect(fullBackupJson, contains('full_system_snapshot'));
      expect(fullBackupJson, contains('Dragonfire'));
      expect(fullBackupJson, contains('time-stop-plus'));
      expect(fullBackupJson, contains('void-drake'));
      expect(fullBackupJson, contains('blade-of-eternity'));
      expect(fullBackupJson, contains('chronomancer'));
      expect(fullBackupJson, contains('time-weaver'));
      expect(fullBackupJson, contains('human-custom'));
      expect(fullBackupJson, contains('astral-human'));
      expect(fullBackupJson, contains('temporal-reflexes'));
      expect(fullBackupJson, contains('time-traveler'));
      expect(fullBackupJson, contains('madness-table'));

      // 3. Clear data
      await homebrewService.clearAllHomebrew();
      campaignService.clearCacheForTesting();

      // 4. Restore full system
      final restoreSuccess = await backupService.restoreFullSystemSnapshot(fullBackupJson);
      expect(restoreSuccess, isTrue);

      final restoredProfiles = await campaignService.loadAllProfiles();
      expect(restoredProfiles.any((p) => p.name == 'Dragonfire'), isTrue);

      final restoredSpells = await homebrewService.loadCustomSpells();
      expect(restoredSpells.any((s) => s.id.slug == 'time-stop-plus'), isTrue);

      final restoredMonsters = await homebrewService.loadCustomMonsters();
      expect(restoredMonsters.any((m) => m.id.slug == 'void-drake'), isTrue);

      final restoredItems = await homebrewService.loadCustomItems();
      expect(restoredItems.any((i) => i.id.slug == 'blade-of-eternity'), isTrue);

      final restoredClasses = await homebrewService.loadCustomClasses();
      expect(restoredClasses.any((c) => c.id.slug == 'chronomancer'), isTrue);

      final restoredSubs = await homebrewService.loadCustomSubclasses();
      expect(restoredSubs.any((s) => s.id.slug == 'time-weaver'), isTrue);

      final restoredRaces = await homebrewService.loadCustomRaces();
      expect(restoredRaces.any((r) => r.id.slug == 'human-custom'), isTrue);
      final restoredRace = restoredRaces.firstWhere((r) => r.id.slug == 'human-custom');
      expect(restoredRace.subraces.any((s) => s.id.slug == 'astral-human'), isTrue);

      final restoredFeats = await homebrewService.loadCustomFeats();
      expect(restoredFeats.any((f) => f.id.slug == 'temporal-reflexes'), isTrue);

      final restoredBgs = await homebrewService.loadCustomBackgrounds();
      expect(restoredBgs.any((b) => b.id.slug == 'time-traveler'), isTrue);

      final restoredOthers = await homebrewService.loadCustomOtherEntries();
      expect(restoredOthers.any((o) => o.id.slug == 'madness-table'), isTrue);
    });
  });
}
