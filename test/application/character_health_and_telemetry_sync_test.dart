import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterPersistenceService characterRepo;
  late CampaignRegistryService registry;
  late PartyRoomService roomService;

  final testHero = Character(
    id: const EntityId(slug: 'gimli-hero', ruleset: RulesetVersion.v2024),
    name: 'Gimli',
    speciesRef: const EntityReference<DomainEntity>(
      refType: EntityType.species,
      slug: 'dwarf',
      displayName: 'Dwarf',
    ),
    progression: const CharacterProgression(
      classes: [
        ClassLevelProgression(
          classRef: EntityReference<DomainEntity>(
            refType: EntityType.classDefinition,
            slug: 'fighter',
            displayName: 'Fighter',
          ),
          level: 4,
          hitDie: 'd10',
          isStartingClass: true,
        ),
      ],
    ),
    baseScores: const AbilityScores(
      strength: 16,
      dexterity: 12,
      constitution: 16,
      intelligence: 10,
      wisdom: 12,
      charisma: 8,
    ),
    resources: const CharacterResourcePool(
      currentHp: 38,
      tempHp: 5,
    ),
    purse: const PartyPurse().setCoins(gp: 75, sp: 20, nodeId: 'init'),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    characterRepo = CharacterPersistenceService();
    await characterRepo.saveCharacter(testHero);

    registry = CampaignRegistryService();
    roomService = PartyRoomService();

    // Create a mock campaign membership linking Gimli
    final membership = CampaignMembership(
      roomCode: 'MINAS123',
      campaignName: 'War of the Ring',
      role: CampaignRole.player,
      characterId: testHero.id.slug,
      lastPlayed: DateTime.now(),
    );
    await registry.saveMembership(membership);

    // Link character to room
    await roomService.linkCharacterToCampaign(
      roomCode: 'MINAS123',
      character: testHero,
      existingRosterName: testHero.name,
      isNewImport: true,
    );
  });

  group('Character Health & Telemetry Synchronization Tests', () {
    test('sharedCharacters in PartyRoomService stores full Character, not truncated telemetry', () async {
      final session = roomService.getCachedSession('MINAS123');
      expect(session, isNotNull);

      final rawMap = session!.sharedCharacters[testHero.name];
      expect(rawMap, isNotNull);

      // Verify full character serialization fields are present
      expect(rawMap!['progression'], isNotNull, reason: 'sharedCharacters must store full Character progression');
      expect(rawMap['baseScores'], isNotNull, reason: 'sharedCharacters must store full Character baseScores');
      expect(rawMap['resources'], isNotNull, reason: 'sharedCharacters must store full Character resources');

      // Hydrate Character from rawMap
      final hydrated = Character.fromMap(rawMap);
      expect(hydrated.resources.currentHp, 38, reason: 'Hydrated character must NOT reset HP to 10');
      expect(hydrated.resources.tempHp, 5);
      expect(hydrated.progression.totalLevel, 4);
    });

    test('CharacterSheetController.takeDamage syncs telemetry directly to PartyRoomService', () async {
      final controller = CharacterSheetController(
        character: testHero,
        persistenceService: characterRepo,
      );

      // Initial state in room
      var session = roomService.getCachedSession('MINAS123');
      expect(session!.partyTelemetry[testHero.id.slug]!.currentHp, 38);

      // Take 10 damage: 5 tempHp absorbed, 5 currentHp lost => currentHp 33, tempHp 0
      await controller.takeDamage(10);
      await controller.flush();

      // Verify controller updated
      expect(controller.character.resources.currentHp, 33);
      expect(controller.character.resources.tempHp, 0);

      // Verify disk updated
      final fromDisk = await characterRepo.getCharacter(testHero.id.slug);
      expect(fromDisk!.resources.currentHp, 33);
      expect(fromDisk.resources.tempHp, 0);

      // Verify PartyRoomService telemetry updated automatically!
      session = roomService.getCachedSession('MINAS123');
      final telemetry = session!.partyTelemetry[testHero.id.slug];
      expect(telemetry, isNotNull);
      expect(telemetry!.currentHp, 33, reason: 'Party telemetry must reflect damage without waiting for manual resync');
      expect(telemetry.tempHp, 0);
    });

    test('CharacterSheetController.modifyPurseCoin syncs purse to PartyRoomService', () async {
      final controller = CharacterSheetController(
        character: testHero,
        persistenceService: characterRepo,
      );

      // Spend 25 GP (75 -> 50)
      await controller.modifyPurseCoin('gp', -25);
      await controller.flush();

      expect(controller.character.purse.gp, 50);

      final session = roomService.getCachedSession('MINAS123');
      final memberPurse = session!.getMemberPurse(testHero.name);
      expect(memberPurse.gp, 50, reason: 'Room memberPurse must reflect modified coin balance');
    });

    test('Character.fromMap gracefully parses legacy map with top-level hp without dropping to 10', () {
      final legacyMap = {
        'id': 'legacy-hero',
        'name': 'Old Hero',
        'hp': 42,
        'thp': 8,
      };

      final char = Character.fromMap(legacyMap);
      expect(char.resources.currentHp, 42);
      expect(char.resources.tempHp, 8);
    });
  });
}
