import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
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
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import '../test_doubles/fake_blob_store.dart';
import '../test_doubles/hive_test_harness.dart';

Character _createTestHero(String slug, String name) {
  return CharacterFactory.createLevel1Character(
    CharacterCreationRequest(
      characterName: name,
      ruleset: RulesetVersion.v2024,
      speciesRef: const EntityReference.empty(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      backgroundRef: const EntityReference.empty(
        refType: EntityType.background,
        slug: 'acolyte',
        displayName: 'Acolyte',
      ),
      startingClassSlug: 'fighter',
      startingClassDisplayName: 'Fighter',
      startingClassHitDie: 'd10',
      baseScores: const AbilityScores.standardArray(),
      bonusScores: const AbilityScores(strength: 2, constitution: 1),
    ),
  ).copyWith(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    CampaignProfile.defaultRulesetEdition = DmRulesEdition.v2024;
    CampaignProfile.defaultPinnedRulesFallback = const {
      'concentration',
      'grapple_shove',
    };
  });

  group('CampaignProfile Model Unit Tests', () {
    test('Round-trip serialization toMap and fromMap preserves all fields', () {
      final now = DateTime.now();
      final profile = CampaignProfile(
        id: 'camp_test_101',
        name: 'The Vampire Must Fall',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: RoomNodeState.fromLists(
          roomId: 'room_101',
          roomCode: 'CR-101',
          title: 'Shadow Gates',
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
              defense: 14,
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
        notesMarkdown: '# Session 1 Log\nThe party entered the shadowy woods.',
        nodeId: 'test_node',
      );

      final map = CampaignProfileDto.fromDomain(profile).toMap();
      final restored = CampaignProfileDto.fromMap(map).toDomain();

      expect(restored.id, equals('camp_test_101'));
      expect(restored.name, equals('The Vampire Must Fall'));
      expect(restored.edition, equals(DmRulesEdition.v2024));
      expect(restored.roomState.activeEncounter.length, equals(1));
      expect(restored.partyCharacterIds.length, equals(1));
      expect(restored.partyCharacterIds.first, equals('cleric_1'));
      expect(restored.roomState.activeMinions.length, equals(1));
      expect(restored.roomState.activeMinions.first.name,
          equals('Flying Longsword'));
      expect(restored.pinnedRuleIds.contains('concentration'), isTrue);
      expect(restored.notesMarkdown, contains('Session 1 Log'));
      expect(map.containsKey('partyRoster'), isFalse);
      expect(map.containsKey('activeMinions'), isFalse);
      expect(map['partyCharacterIds'], equals(['cleric_1']));
    });

    test(
        'Legacy migration gateway extracts nested characters and root minions safely',
        () {
      final legacyCharacterMap = {
        'id': {'slug': 'fighter_legacy', 'ruleset': 'v2024'},
        'name': 'Grom the Barbarian',
        'speciesRef': {
          'slug': 'human',
          'refType': 'species',
          'displayName': 'Human'
        },
        'progression': {
          'classes': [
            {
              'classRef': {
                'slug': 'barbarian',
                'refType': 'classDefinition',
                'displayName': 'Barbarian'
              },
              'level': 4,
              'hitDie': 'd12',
            }
          ]
        },
        'baseScores': {
          'strength': 18,
          'dexterity': 14,
          'constitution': 16,
          'intelligence': 8,
          'wisdom': 12,
          'charisma': 10
        },
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

      final profile = CampaignProfileDto.fromMap(legacyPayload).toDomain();

      // Verify migration gateway extracted character and minion
      expect(profile.partyCharacterIds, equals(['fighter_legacy']));
      final legacyChars =
          CampaignProfileDto.extractLegacyCharacters(legacyPayload);
      expect(legacyChars.length, equals(1));
      expect(legacyChars.first.name, equals('Grom the Barbarian'));
      expect(profile.roomState.activeMinions.length, equals(1));
      expect(profile.roomState.activeMinions.first.name, equals('Silver Coin'));

      // Reserialization must output flat structure
      final flattened = CampaignProfileDto.fromDomain(profile).toMap();
      expect(flattened['partyCharacterIds'], equals(['fighter_legacy']));
      expect(flattened.containsKey('partyRoster'), isFalse);
      expect(flattened.containsKey('activeMinions'), isFalse);
    });

    test('Default factory initializes staging area and core pinned rules', () {
      final def = CampaignProfile.defaultProfile(
          name: 'Lost Mine Explorers', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));
      expect(def.id, startsWith('campaign_'));
      expect(def.name, equals('Lost Mine Explorers'));
      expect(def.edition, equals(DmRulesEdition.v2024));
      expect(def.pinnedRuleIds.contains('concentration'), isTrue);
      expect(def.pinnedRuleIds.contains('grapple_shove'), isTrue);
      expect(def.notesMarkdown, isEmpty);
    });
  });

  group('CampaignProfileService Persistence Lifecycle Tests', () {
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUpInMemory();
      AppServices.reset();
      sl.reset();
      final testReplica = ReplicaId('campaign_profile_test_replica');
      await initServiceLocator(
        replicaId: testReplica,
        blobStore: FakeBlobStore(),
      );
    });

    tearDown(() async {
      sl.reset();
      await harness.tearDown();
    });

    test('loadAllProfiles creates default My Campaign when storage is empty',
        () async {
      final service = CampaignProfileService();
      final profiles = await service.loadAllProfiles();

      expect(profiles.length, equals(1));
      expect(profiles.first.name, equals('My Campaign'));

      final active = await service.getActiveProfile();
      expect(active!.id, equals(profiles.first.id));
    });

    test(
        'loadAllProfiles seamlessly adopts existing campaign from CampaignRegistryService',
        () async {
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

    test(
        'loadAllProfiles registry adoption authors partyRoster with runtime clock causality (never genesis)',
        () async {
      final hero1 = _createTestHero('hero-aragorn', 'Aragorn');
      final hero2 = _createTestHero('hero-legolas', 'Legolas');
      await CharacterPersistenceService().saveRoster([hero1, hero2]);

      final reg = CampaignRegistryService.newInstance();
      await reg.saveMembership(CampaignMembership(
        roomCode: 'REG-SYNTH-1',
        campaignName: 'Synthesized Fellowship',
        characterId: 'hero-aragorn',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      final service = CampaignProfileService();
      final profiles = await service.loadAllProfiles();

      final adopted = profiles.firstWhere((p) => p.roomState.roomCode == 'REG-SYNTH-1');
      expect(adopted.name, equals('Synthesized Fellowship'));

      // partyRoster contains the expected character IDs
      expect(adopted.partyRoster.activeValues, containsAll(['hero-aragorn']));
      expect(adopted.partyRoster.length, equals(1));

      // partyCharacterIds is only the derived projection of partyRoster
      expect(adopted.partyCharacterIds, equals(adopted.partyRoster.activeValues));

      // Timestamps must use the runtime writer authority, NOT genesis
      for (final entry in adopted.partyRoster.items.values) {
        expect(entry.timestamp.nodeId, equals('campaign_profile_test_replica'));
        expect(entry.timestamp.nodeId, isNot(equals('genesis')));
        expect(entry.timestamp.physicalTime, greaterThan(0));
      }
    });

    test('Saves, loads, and switches multiple campaign profiles', () async {
      final service = CampaignProfileService();

      final p1 = CampaignProfile.defaultProfile(
          id: 'camp_1', name: 'Crown City Vault Heist', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));
      final p2 = CampaignProfile.defaultProfile(
          id: 'camp_2', name: 'Tomb of the Serpent King', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));

      await service.saveProfileImmediate(p1);
      await service.saveProfileImmediate(p2);

      final all = await service.loadAllProfiles();
      expect(all.length, equals(2));

      await service.switchProfile('camp_2');
      final active = await service.getActiveProfile();
      expect(active!.id, equals('camp_2'));
      expect(active.name, equals('Tomb of the Serpent King'));
    });

    test('Clones profile with isolated ID and title', () async {
      final service = CampaignProfileService();

      final source = CampaignProfile.defaultProfile(
        id: 'source_1',
        name: 'Shadows of the Vampire',
        nodeId: 'test_node',
        timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'),
      ).copyWith(
        notesMarkdown: 'Secret DM notes: The vampire is in the chapel.',
        notesTimestamp: const HybridLogicalClock(
          physicalTime: 10,
          logicalCounter: 0,
          nodeId: 'test_node',
        ),
      );

      await service.saveProfileImmediate(source);
      final cloned = await service.cloneProfile(
          'source_1', 'Shadows of the Vampire - Second Group');

      expect(cloned.id, isNot(equals('source_1')));
      expect(cloned.name, equals('Shadows of the Vampire - Second Group'));
      expect(cloned.notesMarkdown,
          equals('Secret DM notes: The vampire is in the chapel.'));

      final all = await service.loadAllProfiles();
      expect(all.length, equals(2));
    });

    test('Deletes profile and safely fallback switches active pointer',
        () async {
      final service = CampaignProfileService();

      final p1 = CampaignProfile.defaultProfile(
          id: 'camp_a', name: 'Campaign Alpha', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));
      final p2 = CampaignProfile.defaultProfile(
          id: 'camp_b', name: 'Campaign Beta', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));

      await service.saveProfileImmediate(p1);
      await service.saveProfileImmediate(p2);
      await service.switchProfile('camp_a');

      await service.deleteProfile('camp_a');

      final all = await service.loadAllProfiles();
      expect(all.length, equals(1));
      expect(all.first.id, equals('camp_b'));

      final active = await service.getActiveProfile();
      expect(active!.id, equals('camp_b'));
    });
  });

  group('DmBackupService Snapshot Import & Export Tests', () {
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUpInMemory();
      AppServices.reset();
      sl.reset();
      final testReplica = ReplicaId('campaign_profile_test_replica');
      await initServiceLocator(
        replicaId: testReplica,
      );
    });

    tearDown(() async {
      sl.reset();
      await harness.tearDown();
    });

    test('Exports and hydrates valid profile snapshot JSON', () async {
      final backupService = DmBackupService();
      final profile = CampaignProfile.defaultProfile(
        id: 'camp_export_test',
        name: 'Starfarer Odyssey',
        nodeId: 'test_node',
        timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'),
      ).copyWith(
        notesMarkdown: 'Asteroid base coordinates: 42.88',
        notesTimestamp: const HybridLogicalClock(
          physicalTime: 10,
          logicalCounter: 0,
          nodeId: 'test_node',
        ),
      );

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
      expect(imported.id,
          isNot(equals('camp_export_test'))); // Unique reassigned imported ID
    });

    test('Handles corrupted, malformed, or empty snapshot JSON gracefully',
        () async {
      final backupService = DmBackupService();

      expect(await backupService.validateAndImportProfile(''), isNull);
      expect(await backupService.validateAndImportProfile('{ invalid json }'),
          isNull);
      expect(await backupService.validateAndImportProfile('{"wrongKey": 123}'),
          isNull);
      expect(
          await backupService
              .validateAndImportProfile('["array", "not", "object"]'),
          isNull);
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
