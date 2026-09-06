import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
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
        name: 'The Vampire Must Fall',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: RoomNodeState(
          roomId: 'room_101',
          roomCode: 'CR-101',
          title: 'Shadow Gates',
          description: 'Dark fog surrounds the gates.',
          entityLinks: const [
            RoomEntityLink(
              refType: SessionRefType.monster,
              entityId: 'monster_wolf',
              displayName: 'Dire Wolf',
            ),
          ],
          activeEncounter: const [
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
          activeMinions: [
            AnimatedObjectInstance(
              id: 'minion_sword',
              name: 'Flying Longsword',
              size: ObjectSize.small,
              currentHp: 25,
              maxHp: 25,
            ),
          ],
        ),
        partyCharacterIds: const ['cleric_1'],
        pinnedRuleIds: const {'concentration', 'falling', 'cover'},
        notesMarkdown: '# Session 1 Log\nThe party entered the Barovian woods.',
      );

      final map = profile.toMap();
      final restored = CampaignProfile.fromMap(map);

      expect(restored.id, equals('camp_test_101'));
      expect(restored.name, equals('The Vampire Must Fall'));
      expect(restored.edition, equals(DmRulesEdition.v2024));
      expect(restored.roomState.activeEncounter.length, equals(1));
      expect(restored.partyCharacterIds.length, equals(1));
      expect(restored.partyCharacterIds.first, equals('cleric_1'));
      expect(restored.roomState.activeMinions.length, equals(1));
      expect(restored.roomState.activeMinions.first.name, equals('Flying Longsword'));
      expect(restored.pinnedRuleIds.contains('concentration'), isTrue);
      expect(restored.notesMarkdown, contains('Session 1 Log'));
      expect(map.containsKey('partyRoster'), isFalse);
      expect(map.containsKey('activeMinions'), isFalse);
      expect(map['partyCharacterIds'], equals(['cleric_1']));
    });

    test('Legacy migration gateway extracts nested characters and root minions safely', () {
      final legacyCharacterMap = {
        'id': {'slug': 'fighter_legacy', 'ruleset': 'v2024'},
        'name': 'Grom the Barbarian',
        'speciesRef': {'slug': 'human', 'refType': 'species', 'displayName': 'Human'},
        'progression': {
          'classes': [
            {
              'classRef': {'slug': 'barbarian', 'refType': 'classDefinition', 'displayName': 'Barbarian'},
              'level': 4,
              'hitDie': 'd12',
            }
          ]
        },
        'baseScores': {'strength': 18, 'dexterity': 14, 'constitution': 16, 'intelligence': 8, 'wisdom': 12, 'charisma': 10},
        'resources': {'currentHp': 45},
      };

      final legacyMinionMap = {
        'id': 'minion_coin',
        'name': 'Silver Coin',
        'size': 'tiny',
        'currentHp': 20,
        'maxHp': 20,
      };

      final legacyPayload = {
        'id': 'campaign_legacy_1',
        'name': 'Legacy Dungeon Campaign',
        'edition': 'v2024',
        'createdAt': DateTime.now().toIso8601String(),
        'lastPlayedAt': DateTime.now().toIso8601String(),
        'partyRoster': [legacyCharacterMap],
        'activeMinions': [legacyMinionMap],
        'notesMarkdown': '# Old Notes',
      };

      final profile = CampaignProfile.fromMap(legacyPayload);

      // Verify migration gateway extracted character and minion
      expect(profile.partyCharacterIds, equals(['fighter_legacy']));
      expect(profile.migratedCharacters.length, equals(1));
      expect(profile.migratedCharacters.first.name, equals('Grom the Barbarian'));
      expect(profile.roomState.activeMinions.length, equals(1));
      expect(profile.roomState.activeMinions.first.name, equals('Silver Coin'));

      // Reserialization must output flat structure
      final flattened = profile.toMap();
      expect(flattened['partyCharacterIds'], equals(['fighter_legacy']));
      expect(flattened.containsKey('partyRoster'), isFalse);
      expect(flattened.containsKey('activeMinions'), isFalse);
    });

    test('Default factory initializes staging area and core pinned rules', () {
      final def = CampaignProfile.defaultProfile(name: 'Lost Mine Explorers');
      expect(def.id, startsWith('campaign_'));
      expect(def.name, equals('Lost Mine Explorers'));
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
        roomCode: 'NORTH-1',
        campaignName: 'Northern Citadel Table',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      final service = CampaignProfileService();
      final profiles = await service.loadAllProfiles();

      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('Northern Citadel Table'));
      expect(profiles.first.roomState.roomCode, equals('NORTH-1'));
    });

    test('Saves, loads, and switches multiple campaign profiles', () async {
      final service = CampaignProfileService();

      final p1 = CampaignProfile.defaultProfile(id: 'camp_1', name: 'Crown City Vault Heist');
      final p2 = CampaignProfile.defaultProfile(id: 'camp_2', name: 'Tomb of the Serpent King');

      await service.saveProfileImmediate(p1);
      await service.saveProfileImmediate(p2);

      final all = await service.loadAllProfiles();
      expect(all.length, equals(2));

      await service.switchProfile('camp_2');
      final active = await service.getActiveProfile();
      expect(active.id, equals('camp_2'));
      expect(active.name, equals('Tomb of the Serpent King'));
    });

    test('Clones profile with isolated ID and title', () async {
      final service = CampaignProfileService();

      final source = CampaignProfile.defaultProfile(
        id: 'source_1',
        name: 'Shadows of the Vampire',
      ).copyWith(
        notesMarkdown: 'Secret DM notes: The vampire is in the chapel.',
      );

      await service.saveProfileImmediate(source);
      final cloned = await service.cloneProfile('source_1', 'Shadows of the Vampire - Second Group');

      expect(cloned.id, isNot(equals('source_1')));
      expect(cloned.name, equals('Shadows of the Vampire - Second Group'));
      expect(cloned.notesMarkdown, equals('Secret DM notes: The vampire is in the chapel.'));

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
        name: 'Starfarer Odyssey',
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
      expect(imported!.name, equals('Starfarer Odyssey'));
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
