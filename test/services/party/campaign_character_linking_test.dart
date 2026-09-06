import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Campaign Character Linking & Vault Payout Synchronization', () {
    late CampaignRegistryService registry;
    late DiceRoomService diceService;
    late CharacterPersistenceService characterService;
    late CampaignProfileService campaignProfileService;
    late PartyRoomService partyService;

    const testCharacter1 = Character(
      id: EntityId(slug: 'hero_valeros', ruleset: RulesetVersion.v2024),
      name: 'Valeros the Fighter',
      speciesRef: EntityReference(
        slug: 'human',
        refType: EntityType.species,
        displayName: 'Human',
      ),
      progression: CharacterProgression(classes: []),
      baseScores: AbilityScores.standardArray(),
      resources: CharacterResourcePool(currentHp: 45),
      purse: PartyPurse(gp: 15, sp: 5),
    );

    const testCharacter2 = Character(
      id: EntityId(slug: 'hero_seward', ruleset: RulesetVersion.v2024),
      name: 'Dr. Seward',
      speciesRef: EntityReference(
        slug: 'human',
        refType: EntityType.species,
        displayName: 'Human',
      ),
      progression: CharacterProgression(classes: []),
      baseScores: AbilityScores.standardArray(),
      resources: CharacterResourcePool(currentHp: 32),
      purse: PartyPurse(gp: 50),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService.newInstance();
      diceService = DiceRoomService.newInstance();
      characterService = CharacterPersistenceService();
      campaignProfileService = CampaignProfileService();

      partyService = PartyRoomService.newInstance(
        registry: registry,
        diceRoomService: diceService,
        characterPersistenceService: characterService,
        campaignProfileService: campaignProfileService,
      );

      // Save starting characters
      await characterService.saveCharacters([testCharacter1, testCharacter2]);
    });

    test('Player links character by importing as a new character on join', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Curse of Strahd',
        playerName: 'DM Kevin',
      );

      // Player joins and imports character
      final joined = await partyService.joinCampaign(
        roomCode: session.roomCode,
        playerName: testCharacter1.name,
        characterId: testCharacter1.id.slug,
        characterSnapshot: testCharacter1,
        isNewImport: true,
      );

      // 1. Roster contains character
      expect(joined.characterRoster, contains('Valeros the Fighter'));

      // 2. Character sheet snapshot shared with DM in room state
      expect(joined.sharedCharacters.containsKey('hero_valeros'), isTrue);
      expect(joined.sharedCharacters['hero_valeros']?['name'], equals('Valeros the Fighter'));

      // 3. Player membership has characterId foreign key
      final membership = registry.getMembership(session.roomCode);
      expect(membership, isNotNull);
      expect(membership!.characterId, equals('hero_valeros'));
    });

    test('Player links character to an existing campaign roster slot', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Tomb of Annihilation',
        playerName: 'DM Kevin',
      );

      // DM sets up pre-existing roster slots
      await partyService.addCharacterToRoster(
        roomCode: session.roomCode,
        characterName: 'Fighter Slot',
        playerName: 'DM Kevin',
      );

      // Player joins and links their character to "Fighter Slot"
      final linked = await partyService.linkCharacterToCampaign(
        roomCode: session.roomCode,
        character: testCharacter2,
        existingRosterName: 'Fighter Slot',
        isNewImport: false,
      );

      // Roster retains Fighter Slot
      expect(linked.characterRoster, contains('Fighter Slot'));

      // Shared characters map contains Seward's sheet mapped to both ID and slot
      expect(linked.sharedCharacters.containsKey('hero_seward'), isTrue);
      expect(linked.sharedCharacters['hero_seward']?['name'], equals('Dr. Seward'));
      expect(linked.sharedCharacters['Fighter Slot']?['name'], equals('Dr. Seward'));

      // Membership stores hero_seward
      final membership = registry.getMembership(session.roomCode);
      expect(membership?.characterId, equals('hero_seward'));
    });

    test('Coin dispersal automatically reflects on linked character purse', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Dragon Heist',
        playerName: 'DM Kevin',
      );

      // Link character
      await partyService.linkCharacterToCampaign(
        roomCode: session.roomCode,
        character: testCharacter1,
        isNewImport: true,
      );

      // Disperse 100 GP across Valeros and Party Reserve (50 GP each)
      await partyService.disperseCoinsToParty(
        roomCode: session.roomCode,
        purseToDisperse: const PartyPurse(gp: 100),
        recipientCharacters: ['Valeros the Fighter'],
        performedBy: 'DM Kevin',
        includePartyReserve: true,
      );

      // Check character in persistence: initial 15 GP + 50 GP = 65 GP
      final updatedChars = await characterService.loadCharacters();
      final valeros = updatedChars.firstWhere((c) => c.id.slug == 'hero_valeros');
      expect(valeros.purse.gp, equals(65));
      expect(valeros.purse.sp, equals(5));

      // Check room session sharedCharacters updated with new purse
      final cached = partyService.getCachedSession(session.roomCode);
      final sharedMap = cached?.sharedCharacters['hero_valeros'];
      expect(sharedMap?['purse']?['gp'], equals(65));
    });

    test('Liquidated coin split reflects on linked character purse', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Dungeon of the Mad Mage',
        playerName: 'DM Vlad',
      );

      await partyService.linkCharacterToCampaign(
        roomCode: session.roomCode,
        character: testCharacter2, // 50 GP initial
        isNewImport: true,
      );

      // Disperse 200 GP liquidated without party reserve
      await partyService.disperseCoinsToParty(
        roomCode: session.roomCode,
        purseToDisperse: const PartyPurse(gp: 200),
        recipientCharacters: ['Dr. Seward'],
        performedBy: 'DM Vlad',
        includePartyReserve: false,
        liquidatedGemsAndArtGp: 100.0,
        includeLiquidatedInSplit: true,
      );

      final updatedChars = await characterService.loadCharacters();
      final seward = updatedChars.firstWhere((c) => c.id.slug == 'hero_seward');
      // 50 GP initial + 300 GP split = 350 GP
      expect(seward.purse.gp, equals(350));
    });

    test('Claiming a loot item adds it to linked character inventory', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Sunless Citadel',
        playerName: 'DM Kevin',
      );

      await partyService.linkCharacterToCampaign(
        roomCode: session.roomCode,
        character: testCharacter1,
        isNewImport: true,
      );

      // DM adds a magic item to party vault
      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM Kevin',
        item: PartyLootItem(
          id: 'loot_sunblade_1',
          name: 'Sun Blade',
          category: 'magicItem',
          count: 1,
          gpValue: 5000.0,
          requiresAttunement: true,
          description: 'A glowing blade of pure radiant solar energy.',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );

      // Valeros claims the loot item
      await partyService.claimLootItem(
        roomCode: session.roomCode,
        lootId: 'loot_sunblade_1',
        playerName: 'Valeros the Fighter',
      );

      // Verify item instance in character inventory
      final updatedChars = await characterService.loadCharacters();
      final valeros = updatedChars.firstWhere((c) => c.id.slug == 'hero_valeros');
      expect(valeros.inventory.length, equals(1));
      final claimedItem = valeros.inventory.first;
      expect(claimedItem.instanceId, equals('loot_loot_sunblade_1'));
      expect(claimedItem.displayName, equals('Sun Blade'));
      expect(claimedItem.requiresAttunement, isTrue);
      expect(claimedItem.notes, equals('A glowing blade of pure radiant solar energy.'));

      // Now unclaim the item (return to vault)
      await partyService.claimLootItem(
        roomCode: session.roomCode,
        lootId: 'loot_sunblade_1',
        playerName: null,
      );

      final unclaimChars = await characterService.loadCharacters();
      final valerosAfterUnclaim = unclaimChars.firstWhere((c) => c.id.slug == 'hero_valeros');
      expect(valerosAfterUnclaim.inventory.isEmpty, isTrue);
    });

    test('Direct member purse update synchronizes with character purse', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Lost Mine',
        playerName: 'DM Kevin',
      );

      await partyService.linkCharacterToCampaign(
        roomCode: session.roomCode,
        character: testCharacter1,
        isNewImport: true,
      );

      // Direct override to personal purse
      await partyService.updateMemberPurse(
        roomCode: session.roomCode,
        characterName: 'Valeros the Fighter',
        newPurse: const PartyPurse(pp: 2, gp: 100, sp: 20),
        performedBy: 'DM Kevin',
      );

      final updatedChars = await characterService.loadCharacters();
      final valeros = updatedChars.firstWhere((c) => c.id.slug == 'hero_valeros');
      expect(valeros.purse.pp, equals(2));
      expect(valeros.purse.gp, equals(100));
      expect(valeros.purse.sp, equals(20));
    });
  });
}
