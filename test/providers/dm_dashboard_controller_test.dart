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
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DmDashboardController Relational & Performance Tests', () {
    late CampaignProfileService campaignService;
    late CharacterPersistenceService characterService;
    late DmDashboardController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppServices.reset();
      campaignService = CampaignProfileService();
      characterService = CharacterPersistenceService();
      controller = DmDashboardController(
        campaignProfileService: campaignService,
        characterPersistenceService: characterService,
      );
    });

    test('Initial loadData resolves relational characters by foreign key IDs', () async {
      // 1. Seed Character database with top-level characters
      const hero1 = Character(
        id: EntityId(slug: 'hero_aragorn', ruleset: RulesetVersion.v2024),
        name: 'Aragorn',
        speciesRef: EntityReference(slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 50),
      );
      const hero2 = Character(
        id: EntityId(slug: 'hero_legolas', ruleset: RulesetVersion.v2024),
        name: 'Legolas',
        speciesRef: EntityReference(slug: 'elf', refType: EntityType.species, displayName: 'Elf'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 40),
      );
      await characterService.saveCharacters([hero1, hero2]);

      // 2. Seed CampaignProfile with only string foreign keys
      final now = DateTime.now();
      final campaign = CampaignProfile(
        id: 'camp_lotr',
        name: 'Fellowship',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: const RoomNodeState(roomId: 'r_1', roomCode: 'R-1', title: 'Rivendell'),
        partyCharacterIds: const ['hero_aragorn', 'hero_legolas'],
        notesMarkdown: '# Secret Ring Lore',
      );
      await campaignService.saveProfileImmediate(campaign);
      await campaignService.switchProfile(campaign.id);

      // 3. Controller loads data
      await controller.loadData();

      expect(controller.activeProfile?.id, equals('camp_lotr'));
      expect(controller.partyCharacters.length, equals(2));
      expect(controller.partyCharacters[0].name, equals('Aragorn'));
      expect(controller.partyCharacters[1].name, equals('Legolas'));
      expect(controller.partyCharactersMap.containsKey('hero_aragorn'), isTrue);
      expect(controller.partyCharactersMap.containsKey('hero_legolas'), isTrue);
    });

    test('modifyCharacterHp updates Character in persistence without re-saving CampaignProfile', () async {
      const hero = Character(
        id: EntityId(slug: 'hero_gimli', ruleset: RulesetVersion.v2024),
        name: 'Gimli',
        speciesRef: EntityReference(slug: 'dwarf', refType: EntityType.species, displayName: 'Dwarf'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(currentHp: 60),
      );
      await characterService.saveCharacter(hero);

      final now = DateTime(2025, 1, 1);
      final campaign = CampaignProfile(
        id: 'camp_moria',
        name: 'Moria Expedition',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: const RoomNodeState(roomId: 'r_moria', roomCode: 'MOR-1', title: 'Moria Gates'),
        partyCharacterIds: const ['hero_gimli'],
        notesMarkdown: '# Initial Undisturbed Notes',
      );
      await campaignService.saveProfileImmediate(campaign);
      await campaignService.switchProfile(campaign.id);

      await controller.loadData();

      // Timestamp of campaign before HP modification
      final lastPlayedBefore = controller.activeProfile!.lastPlayedAt;

      // Mutate HP by -15
      await controller.modifyCharacterHp('hero_gimli', -15);

      // Character HP in controller is updated
      expect(controller.partyCharacters.first.resources.currentHp, equals(45));

      // Character in Character database is updated
      final fromDb = await characterService.getCharactersByIds(['hero_gimli']);
      expect(fromDb.first.resources.currentHp, equals(45));

      // CRITICAL: CampaignProfile lastPlayedAt was NOT modified and notes was NOT re-serialized
      expect(controller.activeProfile!.lastPlayedAt, equals(lastPlayedBefore));
      expect(controller.activeProfile!.notesMarkdown, equals('# Initial Undisturbed Notes'));
    });

    test('toggleSpellSlot mutates spell slots in Character without touching CampaignProfile', () async {
      const wizard = Character(
        id: EntityId(slug: 'hero_gandalf', ruleset: RulesetVersion.v2024),
        name: 'Gandalf',
        speciesRef: EntityReference(slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
        resources: CharacterResourcePool(
          currentHp: 30,
          spellSlots: SpellSlotPool(
            maxSlots: {1: 4, 2: 3},
            currentSlots: {1: 4, 2: 3},
          ),
        ),
      );
      await characterService.saveCharacter(wizard);

      final campaign = CampaignProfile(
        id: 'camp_isengard',
        name: 'Isengard Watch',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime(2025, 1, 1),
        roomState: const RoomNodeState(roomId: 'r_orthanc', roomCode: 'ORT-1', title: 'Orthanc Tower'),
        partyCharacterIds: const ['hero_gandalf'],
        notesMarkdown: '# Wizard Council',
      );
      await campaignService.saveProfileImmediate(campaign);
      await campaignService.switchProfile(campaign.id);

      await controller.loadData();

      // Toggle level 1 slot: 4 -> 3
      await controller.toggleSpellSlot('hero_gandalf', 1);

      expect(controller.partyCharacters.first.resources.spellSlots.currentSlots[1], equals(3));
      final fromDb = await characterService.getCharactersByIds(['hero_gandalf']);
      expect(fromDb.first.resources.spellSlots.currentSlots[1], equals(3));
    });

    test('Minions in RoomNodeState mutate and persist correctly', () async {
      final campaign = CampaignProfile(
        id: 'camp_summon',
        name: 'Summoners Circle',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: const RoomNodeState(roomId: 'r_s', roomCode: 'S-1', title: 'Chamber'),
        partyCharacterIds: const [],
      );
      await campaignService.saveProfileImmediate(campaign);
      await campaignService.switchProfile(campaign.id);

      await controller.loadData();
      expect(controller.activeMinions.isEmpty, isTrue);

      // Add minion
      final minion = AnimatedObjectInstance(
        id: 'minion_broom',
        name: 'Flying Broom',
        size: ObjectSize.small,
        currentHp: 25,
        maxHp: 25,
      );
      await controller.addMinion(minion);

      expect(controller.activeMinions.length, equals(1));
      expect(controller.activeMinions.first.name, equals('Flying Broom'));

      // Modify minion HP (-10)
      await controller.modifyMinionHp('minion_broom', -10);
      expect(controller.activeMinions.first.currentHp, equals(15));

      // Verify persisted in roomState
      final reloaded = await campaignService.getActiveProfile();
      expect(reloaded.roomState.activeMinions.first.currentHp, equals(15));

      // Remove minion
      await controller.removeMinion('minion_broom');
      expect(controller.activeMinions.isEmpty, isTrue);
    });

    test('Full legacy migration in CampaignProfileService flattens JSON in storage', () async {
      final prefs = await SharedPreferences.getInstance();

      final legacyCharacterMap = {
        'id': {'slug': 'cleric_nested', 'ruleset': 'v2024'},
        'name': 'Nested Cleric',
        'speciesRef': {'slug': 'human', 'refType': 'species', 'displayName': 'Human'},
        'progression': {'classes': []},
        'resources': {'currentHp': 28},
      };

      final legacyPayload = {
        'id': 'legacy_campaign_test',
        'name': 'Old Legacy Campaign',
        'edition': 'v2024',
        'createdAt': DateTime.now().toIso8601String(),
        'lastPlayedAt': DateTime.now().toIso8601String(),
        'roomState': {
          'roomId': 'room_old',
          'roomCode': 'OLD-1',
          'title': 'Old Chamber',
        },
        'partyRoster': [legacyCharacterMap],
        'notesMarkdown': '# Old Notes',
      };

      // Seed directly into SharedPreferences as raw legacy JSON
      await prefs.setString(
        'dn5e_campaign_profile_legacy_campaign_test',
        json.encode(legacyPayload),
      );
      await prefs.setStringList('dn5e_campaign_profile_index', ['legacy_campaign_test']);

      // Call loadAllProfiles() which triggers automatic migration
      final loadedProfiles = await campaignService.loadAllProfiles();
      expect(loadedProfiles.length, equals(1));

      final loaded = loadedProfiles.first;
      expect(loaded.partyCharacterIds, equals(['cleric_nested']));

      // Verify character was saved to top-level Character database
      final savedChars = await characterService.getCharactersByIds(['cleric_nested']);
      expect(savedChars.length, equals(1));
      expect(savedChars.first.name, equals('Nested Cleric'));

      // Verify the campaign JSON saved back to disk was flattened
      final savedBackJson = prefs.getString('dn5e_campaign_profile_legacy_campaign_test')!;
      final savedBackMap = json.decode(savedBackJson) as Map<String, dynamic>;
      expect(savedBackMap['partyCharacterIds'], equals(['cleric_nested']));
      expect(savedBackMap.containsKey('partyRoster'), isFalse);
    });
  });
}
