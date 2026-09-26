import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:vtt_engine_core/models/character_models.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_currency_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CharacterPersistenceService characterRepo;
  late CampaignRegistryService registry;
  late PartyRoomService roomService;

  final testHero = Character(
    id: const EntityId(slug: 'dwarf-fighter-1', ruleset: RulesetVersion.v2024),
    name: 'Barek',
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

    // Create a mock campaign membership linking Barek
    final membership = CampaignMembership(
      roomCode: 'ROOM-A1B2',
      campaignName: "The Dragon's Hoard",
      role: CampaignRole.player,
      characterId: testHero.id.slug,
      lastPlayed: DateTime.now(),
    );
    await registry.saveMembership(membership);

    // Link character to room
    await roomService.linkCharacterToCampaign(
      roomCode: 'ROOM-A1B2',
      character: testHero,
      existingRosterName: testHero.name,
      isNewImport: true,
    );
  });

  group('Character Health & Telemetry Synchronization Tests', () {
    test(
        'sharedCharacters in PartyRoomService preserves vitals and does NOT reset HP to 10',
        () async {
      final session = roomService.getCachedSession('ROOM-A1B2');
      expect(session, isNotNull);

      final rawMap = session!.sharedCharacters[testHero.name];
      expect(rawMap, isNotNull);

      // Verify telemetry vitals are present
      expect(rawMap!['hp'], 38);
      expect(rawMap['thp'], 5);

      // Hydrate Character from rawMap
      final hydrated = Character.fromMap(rawMap);
      expect(hydrated.resources.currentHp, 38,
          reason: 'Hydrated character must NOT reset HP to 10');
      expect(hydrated.resources.tempHp, 5);
    });

    test(
        'CharacterSheetController.takeDamage syncs telemetry directly to PartyRoomService',
        () async {
      final controller = CharacterSheetController(
        character: testHero,
        persistenceService: characterRepo,
      );

      // Initial state in room
      var session = roomService.getCachedSession('ROOM-A1B2');
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
      session = roomService.getCachedSession('ROOM-A1B2');
      final telemetry = session!.partyTelemetry[testHero.id.slug];
      expect(telemetry, isNotNull);
      expect(telemetry!.currentHp, 33,
          reason:
              'Party telemetry must reflect damage without waiting for manual resync');
      expect(telemetry.tempHp, 0);
    });

    test(
        'CharacterSheetController.modifyPurseCoin syncs purse to PartyRoomService',
        () async {
      final controller = CharacterSheetController(
        character: testHero,
        persistenceService: characterRepo,
      );

      // Spend 25 GP (75 -> 50)
      await controller.modifyPurseCoin('gp', -25);
      await controller.flush();

      expect(controller.character.purse.gp, 50);

      final session = roomService.getCachedSession('ROOM-A1B2');
      final memberPurse = session!.getMemberPurse(testHero.name);
      expect(memberPurse.gp, 50,
          reason: 'Room memberPurse must reflect modified coin balance');
    });

    test(
        'Character.fromMap gracefully parses legacy map with top-level hp without dropping to 10',
        () {
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
