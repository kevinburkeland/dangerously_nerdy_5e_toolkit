import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampaignProfile Model Unit Tests', () {
    test('Round-trip serialization toMap and fromMap preserves all fields', () {
      final now = DateTime.now();
      final profile = CampaignProfile(
        id: 'camp_test_101',
        name: 'Strahd Must Die',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: const RoomNodeState(
          roomId: 'room_101',
          roomCode: 'CR-101',
          title: 'Ravenloft Gates',
          description: 'Dark fog surrounds the gates.',
          entityLinks: [
            RoomEntityLink(
              refType: SessionRefType.monster,
              entityId: 'monster_wolf',
              displayName: 'Dire Wolf',
            ),
          ],
          activeEncounter: [
            EncounterParticipant(
              participantId: 'p_1',
              entityLink: RoomEntityLink(
                refType: SessionRefType.monster,
                entityId: 'monster_wolf',
                displayName: 'Dire Wolf',
              ),
              initiativeScore: 15,
              currentHp: 37,
              maxHp: 37,
              armorClass: 14,
              isActiveTurn: true,
            ),
          ],
        ),
        partyRoster: [
          Character(
            id: const EntityId(slug: 'cleric_1', ruleset: RulesetVersion.v2024),
            name: 'Cleric of Light',
            speciesRef: const EntityReference(slug: 'elf', refType: EntityType.species, displayName: 'Elf'),
            progression: const CharacterProgression(
              classes: [
                ClassLevelProgression(
                  classRef: EntityReference(slug: 'cleric', refType: EntityType.classDefinition, displayName: 'Cleric'),
                  level: 3,
                  hitDie: 'd8',
                ),
              ],
            ),
            baseScores: const AbilityScores.standardArray(),
            resources: const CharacterResourcePool(
              currentHp: 24,
              spellSlots: SpellSlotPool(
                maxSlots: {1: 4, 2: 2},
                currentSlots: {1: 3, 2: 2},
              ),
            ),
            purse: const PartyPurse(gp: 150, sp: 20),
          ),
        ],
        activeMinions: [
          AnimatedObjectInstance(
            id: 'minion_sword',
            name: 'Flying Longsword',
            size: ObjectSize.small,
            currentHp: 25,
            maxHp: 25,
          ),
        ],
        pinnedRuleIds: const {'concentration', 'falling', 'cover'},
        notesMarkdown: '# Session 1 Log\nThe party entered the Barovian woods.',
      );

      final map = profile.toMap();
      final restored = CampaignProfile.fromMap(map);

      expect(restored.id, equals('camp_test_101'));
      expect(restored.name, equals('Strahd Must Die'));
      expect(restored.edition, equals(DmRulesEdition.v2024));
      expect(restored.roomState.activeEncounter.length, equals(1));
      expect(restored.partyRoster.length, equals(1));
      expect(restored.partyRoster.first.name, equals('Cleric of Light'));
      expect(restored.activeMinions.length, equals(1));
      expect(restored.activeMinions.first.name, equals('Flying Longsword'));
      expect(restored.pinnedRuleIds.contains('concentration'), isTrue);
      expect(restored.notesMarkdown, contains('Session 1 Log'));
    });

    test('Default factory initializes staging area and core pinned rules', () {
      final def = CampaignProfile.defaultProfile(name: 'Phandelver Group');
      expect(def.id, startsWith('campaign_'));
      expect(def.name, equals('Phandelver Group'));
      expect(def.edition, equals(DmRulesEdition.v2024));
      expect(def.pinnedRuleIds.contains('concentration'), isTrue);
      expect(def.pinnedRuleIds.contains('grapple_shove'), isTrue);
      expect(def.notesMarkdown, isEmpty);
    });
  });

  group('CampaignProfileService Persistence Lifecycle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppServices.reset();
    });

    test('loadAllProfiles creates default My Campaign when storage is empty', () async {
      final service = CampaignProfileService();
      final profiles = await service.loadAllProfiles();

      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('My Campaign'));

      final active = await service.getActiveProfile();
      expect(active.id, equals(profiles.first.id));
    });

    test('loadAllProfiles seamlessly adopts existing campaign from CampaignRegistryService', () async {
      final reg = CampaignRegistryService.newInstance();
      await reg.saveMembership(CampaignMembership(
        roomCode: 'NEVER-1',
        campaignName: 'Neverwinter Nights Table',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      final service = CampaignProfileService();
      final profiles = await service.loadAllProfiles();

      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('Neverwinter Nights Table'));
      expect(profiles.first.roomState.roomCode, equals('NEVER-1'));
    });

    test('Saves, loads, and switches multiple campaign profiles', () async {
      final service = CampaignProfileService();

      final p1 = CampaignProfile.defaultProfile(id: 'camp_1', name: 'Waterdeep Dragon Heist');
      final p2 = CampaignProfile.defaultProfile(id: 'camp_2', name: 'Tomb of Annihilation');

      await service.saveProfileImmediate(p1);
      await service.saveProfileImmediate(p2);

      final all = await service.loadAllProfiles();
      expect(all.length, equals(2));

      await service.switchProfile('camp_2');
      final active = await service.getActiveProfile();
      expect(active.id, equals('camp_2'));
      expect(active.name, equals('Tomb of Annihilation'));
    });

    test('Clones profile with isolated ID and title', () async {
      final service = CampaignProfileService();

      final source = CampaignProfile.defaultProfile(
        id: 'source_1',
        name: 'Curse of Strahd',
      ).copyWith(
        notesMarkdown: 'Secret DM notes: Strahd is in the chapel.',
      );

      await service.saveProfileImmediate(source);
      final cloned = await service.cloneProfile('source_1', 'Curse of Strahd - Second Group');

      expect(cloned.id, isNot(equals('source_1')));
      expect(cloned.name, equals('Curse of Strahd - Second Group'));
      expect(cloned.notesMarkdown, equals('Secret DM notes: Strahd is in the chapel.'));

      final all = await service.loadAllProfiles();
      expect(all.length, equals(2));
    });

    test('Deletes profile and safely fallback switches active pointer', () async {
      final service = CampaignProfileService();

      final p1 = CampaignProfile.defaultProfile(id: 'camp_a', name: 'Campaign Alpha');
      final p2 = CampaignProfile.defaultProfile(id: 'camp_b', name: 'Campaign Beta');

      await service.saveProfileImmediate(p1);
      await service.saveProfileImmediate(p2);
      await service.switchProfile('camp_a');

      await service.deleteProfile('camp_a');

      final all = await service.loadAllProfiles();
      expect(all.length, equals(1));
      expect(all.first.id, equals('camp_b'));

      final active = await service.getActiveProfile();
      expect(active.id, equals('camp_b'));
    });
  });

  group('DmBackupService Snapshot Import & Export Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppServices.reset();
    });

    test('Exports and hydrates valid profile snapshot JSON', () async {
      final backupService = DmBackupService();
      final profile = CampaignProfile.defaultProfile(
        id: 'camp_export_test',
        name: 'Spelljammer Odyssey',
      ).copyWith(notesMarkdown: 'Asteroid base coordinates: 42.88');

      final jsonStr = backupService.exportProfileJson(profile);
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      expect(decoded['schemaVersion'], equals(1));
      expect(decoded['type'], equals('campaign_profile'));
      expect(decoded['appVersion'], equals('1.0.0'));
      expect(decoded['campaign'], isNotNull);

      // Hydrate & Import
      final imported = await backupService.validateAndImportProfile(jsonStr);
      expect(imported, isNotNull);
      expect(imported!.name, equals('Spelljammer Odyssey'));
      expect(imported.notesMarkdown, contains('Asteroid base'));
      expect(imported.id, isNot(equals('camp_export_test'))); // Unique reassigned imported ID
    });

    test('Handles corrupted, malformed, or empty snapshot JSON gracefully', () async {
      final backupService = DmBackupService();

      expect(await backupService.validateAndImportProfile(''), isNull);
      expect(await backupService.validateAndImportProfile('{ invalid json }'), isNull);
      expect(await backupService.validateAndImportProfile('{"wrongKey": 123}'), isNull);
      expect(await backupService.validateAndImportProfile('["array", "not", "object"]'), isNull);
    });

    test('Exports full system snapshot bundle', () async {
      final backupService = DmBackupService();
      final snapshot = await backupService.exportFullSystemSnapshot();
      final decoded = json.decode(snapshot) as Map<String, dynamic>;

      expect(decoded['type'], equals('full_system_snapshot'));
      expect(decoded['campaignProfiles'], isList);
      expect(decoded['dicePresets'], isList);
      expect(decoded['dprProfiles'], isList);
      expect(decoded['customSpells'], isList);
    });
  });
}
