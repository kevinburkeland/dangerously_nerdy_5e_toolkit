import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PartyRoomService & Conflict Resolution Engine', () {
    late CampaignRegistryService registry;
    late DiceRoomService diceService;
    late PartyRoomService partyService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      registry = CampaignRegistryService.newInstance();
      diceService = DiceRoomService.newInstance();
      partyService = PartyRoomService.newInstance(
        registry: registry,
        diceRoomService: diceService,
      );
    });

    test('Explicit Create Campaign generates roomCode, hostKey, and stores DM membership', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Waterdeep Dragon Heist',
        playerName: 'DM Kevin',
      );

      expect(session.roomCode, startsWith('ROOM-'));
      expect(session.campaignName, equals('Waterdeep Dragon Heist'));
      expect(session.hostKeyHash.length, equals(64));
      expect(session.activePlayers, contains('DM Kevin'));

      // Check registry
      final membership = registry.getMembership(session.roomCode);
      expect(membership, isNotNull);
      expect(membership!.isHost, isTrue);
      expect(membership.hasHostKey, isTrue);
      expect(registry.activeCampaign?.roomCode, equals(session.roomCode));
    });

    test('Explicit Join Campaign joins existing live room as Player', () async {
      // 1. DM creates room
      final created = await partyService.createCampaign(
        campaignName: 'Curse of Strahd',
        playerName: 'DM Strahd',
      );

      // 2. Player joins room
      final joined = await partyService.joinCampaign(
        roomCode: created.roomCode,
        playerName: 'Van Richten',
      );

      expect(joined.roomCode, equals(created.roomCode));
      expect(joined.activePlayers, contains('Van Richten'));

      // Player registry check
      final playerMembership = registry.getMembership(created.roomCode);
      expect(playerMembership, isNotNull);
      expect(playerMembership!.characterId, equals('Van Richten'));

      // 3. Player joins using raw 6-character code without 'ROOM-' prefix
      final rawCode = created.roomCode.replaceFirst('ROOM-', '');
      final joinedRaw = await partyService.joinCampaign(
        roomCode: rawCode.toLowerCase(),
        playerName: 'Ezmerelda',
      );
      expect(joinedRaw.roomCode, equals(created.roomCode));
      expect(joinedRaw.activePlayers, contains('Ezmerelda'));
    });

    test('Explicit Join Campaign rejects non-existent room without creating ghost document', () async {
      expect(
        () => partyService.joinCampaign(
          roomCode: 'ROOM-NONEXISTENT',
          playerName: 'Lost Player',
        ),
        throwsA(isA<CampaignNotFoundException>()),
      );

      // Verify no membership was saved in registry
      expect(registry.getMembership('ROOM-NONEXISTENT'), isNull);
    });

    test('Automatic Rehydration of dormant campaign when valid hostKey exists locally', () async {
      const dormantCode = 'ROOM-DORMANT1';
      const hostKey = 'sample-host-uuid-1234';

      // Simulate dormant campaign saved in local registry before remote TTL expired
      final localDormant = CampaignMembership(
        roomCode: dormantCode,
        campaignName: 'Out of the Abyss',
        role: CampaignRole.host,
        hostKey: hostKey,
        characterId: 'DM Kevin',
        lastPlayed: DateTime.now().subtract(const Duration(days: 45)),
      );
      await registry.saveMembership(localDormant);

      // Join call triggers automatic local rehydration
      final rehydrated = await partyService.joinCampaign(
        roomCode: dormantCode,
        playerName: 'DM Kevin',
      );

      expect(rehydrated.roomCode, equals(dormantCode));
      expect(rehydrated.campaignName, equals('Out of the Abyss'));
      expect(rehydrated.expiresAt.isAfter(DateTime.now().add(const Duration(days: 28))), isTrue);
    });

    test('Atomic Coin Deposits & Withdrawals merge additively', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Gold Test Campaign',
        playerName: 'DM',
      );

      await partyService.depositCoins(
        roomCode: session.roomCode,
        playerName: 'Alice',
        gp: 100,
        pp: 10,
        note: 'Quest Reward',
      );

      // Stream / session update check
      var currentSession = await partyService.streamSession(session.roomCode).first;
      expect(currentSession?.partyPurse.gp, equals(100));
      expect(currentSession?.partyPurse.pp, equals(10));
      expect(currentSession?.partyPurse.totalGpEquivalent, equals(200.0));

      await partyService.withdrawCoins(
        roomCode: session.roomCode,
        playerName: 'Bob',
        gp: 30,
        note: 'Supplies',
      );

      currentSession = await partyService.streamSession(session.roomCode).first;
      expect(currentSession?.partyPurse.gp, equals(70));
    });

    test('Loot Item Add, Claim, Attunement, and Soft-Delete', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Loot Test',
        playerName: 'DM',
      );

      final item = PartyLootItem(
        id: 'cloak_of_elvenkind_1',
        name: 'Cloak of Elvenkind',
        category: 'magicItem',
        count: 1,
        gpValue: 500.0,
        requiresAttunement: true,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      // 1. Add item
      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: item,
      );

      var loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.length, equals(1));
      expect(loot.first.name, equals('Cloak of Elvenkind'));
      expect(loot.first.isClaimed, isFalse);

      // 2. Claim item
      await partyService.claimLootItem(
        roomCode: session.roomCode,
        lootId: item.id,
        playerName: 'Legolas',
      );

      loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.first.isClaimed, isTrue);
      expect(loot.first.claimedByPlayer, equals('Legolas'));

      // 3. Attune
      await partyService.toggleAttunement(
        roomCode: session.roomCode,
        lootId: item.id,
        isAttuned: true,
        playerName: 'Legolas',
      );

      loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.first.isAttuned, isTrue);

      // 4. Soft Delete (Archive)
      await partyService.archiveLootItem(
        roomCode: session.roomCode,
        lootId: item.id,
        playerName: 'Legolas',
      );

      // Active vault stream hides archived items
      loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.isEmpty, isTrue);

      // Trash stream includes archived items
      final trash = await partyService.streamLoot(session.roomCode, includeArchived: true).first;
      expect(trash.length, equals(1));
      expect(trash.first.isArchived, isTrue);
      expect(trash.first.archivedBy, equals('Legolas'));
    });

    test('Host-Only Item Restore requires valid hostKey', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Restore Test',
        playerName: 'DM',
      );

      final membership = registry.getMembership(session.roomCode);
      final validHostKey = membership!.hostKey!;

      final item = PartyLootItem(
        id: 'potion_healing_1',
        name: 'Potion of Healing',
        category: 'gear',
        count: 2,
        gpValue: 50.0,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await partyService.addLootItem(roomCode: session.roomCode, playerName: 'DM', item: item);
      await partyService.archiveLootItem(roomCode: session.roomCode, lootId: item.id, playerName: 'Player');

      // Invalid hostKey throws UnauthorizedHostActionException
      expect(
        () => partyService.restoreLootItem(
          roomCode: session.roomCode,
          lootId: item.id,
          hostKey: 'wrong-invalid-key',
          playerName: 'Player',
        ),
        throwsA(isA<UnauthorizedHostActionException>()),
      );

      // Valid hostKey restores item
      await partyService.restoreLootItem(
        roomCode: session.roomCode,
        lootId: item.id,
        hostKey: validHostKey,
        playerName: 'DM',
      );

      final loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.length, equals(1));
      expect(loot.first.isArchived, isFalse);
    });

    test('Event Audit Stream logs deposits, additions, claims, and archives', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Audit Test',
        playerName: 'DM',
      );

      await partyService.depositCoins(
        roomCode: session.roomCode,
        playerName: 'Gimli',
        gp: 50,
      );

      final events = await partyService.streamEvents(session.roomCode).first;
      expect(events.isNotEmpty, isTrue);
      expect(events.any((e) => e.type == 'coinDeposit'), isTrue);
      expect(events.any((e) => e.type == 'roomCreate'), isTrue);
    });

    test('Character Roster and Active Session Identity management', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Roster Test Campaign',
        playerName: 'DM Kevin',
      );

      // Add characters to campaign roster
      await partyService.addCharacterToRoster(
        roomCode: session.roomCode,
        characterName: 'Thorin (Fighter)',
        playerName: 'DM Kevin',
      );
      await partyService.addCharacterToRoster(
        roomCode: session.roomCode,
        characterName: 'Elrond (Wizard)',
        playerName: 'DM Kevin',
      );

      var liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession?.characterRoster, contains('Thorin (Fighter)'));
      expect(liveSession?.characterRoster, contains('Elrond (Wizard)'));

      // Switch active character
      await partyService.setActiveCharacter(
        roomCode: session.roomCode,
        characterName: 'Thorin (Fighter)',
      );

      liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession?.activePlayers, contains('Thorin (Fighter)'));

      // Verify membership characterId updated
      final membership = registry.getMembership(session.roomCode);
      expect(membership?.characterId, equals('Thorin (Fighter)'));

      // Remove character from roster
      await partyService.removeCharacterFromRoster(
        roomCode: session.roomCode,
        characterName: 'Elrond (Wizard)',
        playerName: 'Thorin (Fighter)',
      );

      liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession?.characterRoster.contains('Elrond (Wizard)'), isFalse);
    });

    test('Disperse Coins to Party with Share for Party Reserve and Remainders', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Treasure Dispersal Campaign',
        playerName: 'DM Kevin',
      );

      final recipients = ['Thorin', 'Elrond', 'Gimli'];

      // Disperse 100 GP, 10 PP, 11 SP across 3 characters + 1 reserve (4 shares)
      // 10 PP / 4 = 2 PP each, 2 PP remainder -> Reserve gets 2+2 = 4 PP
      // 100 GP / 4 = 25 GP each, 0 remainder -> Reserve gets 25 GP
      // 11 SP / 4 = 2 SP each, 3 SP remainder -> Reserve gets 2+3 = 5 SP
      const purseToDisperse = PartyPurse(
        pp: 10,
        gp: 100,
        sp: 11,
      );

      await partyService.disperseCoinsToParty(
        roomCode: session.roomCode,
        purseToDisperse: purseToDisperse,
        recipientCharacters: recipients,
        performedBy: 'DM Kevin',
        includePartyReserve: true,
      );

      final liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession, isNotNull);

      // Check characters
      for (final char in recipients) {
        final charPurse = liveSession!.getMemberPurse(char);
        expect(charPurse.pp, equals(2));
        expect(charPurse.gp, equals(25));
        expect(charPurse.sp, equals(2));
      }

      // Check Party Reserve
      expect(liveSession!.partyPurse.pp, equals(4)); // 2 share + 2 rem
      expect(liveSession.partyPurse.gp, equals(25)); // 25 share + 0 rem
      expect(liveSession.partyPurse.sp, equals(5));  // 2 share + 3 rem
    });

    test('Disperse Coins with liquidated gems/art objects evenly into GP stores', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Liquidated Loot Campaign',
        playerName: 'DM',
      );

      final recipients = ['Legolas', 'Aragorn'];
      // 100 GP in coins + 300 GP in liquidated gems = 400 GP total
      // 2 players + 1 reserve = 3 shares: 400 / 3 = 133 GP each, 1 GP remainder
      await partyService.disperseCoinsToParty(
        roomCode: session.roomCode,
        purseToDisperse: const PartyPurse(gp: 100),
        liquidatedGemsAndArtGp: 300.0,
        includeLiquidatedInSplit: true,
        recipientCharacters: recipients,
        performedBy: 'DM',
        includePartyReserve: true,
      );

      final liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession!.getMemberPurse('Legolas').gp, equals(133));
      expect(liveSession.getMemberPurse('Aragorn').gp, equals(133));
      expect(liveSession.partyPurse.gp, equals(134)); // 133 share + 1 remainder
    });

    test('Transfer between Member Store and Party Reserve', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Vault Transfer Campaign',
        playerName: 'DM',
      );

      // Give Gimli 100 GP initially
      await partyService.updateMemberPurse(
        roomCode: session.roomCode,
        characterName: 'Gimli',
        newPurse: const PartyPurse(gp: 100),
        performedBy: 'Gimli',
      );

      var live = await partyService.streamSession(session.roomCode).first;
      expect(live!.getMemberPurse('Gimli').gp, equals(100));
      expect(live.partyPurse.gp, equals(0));

      // Transfer 40 GP from Gimli to Party Reserve
      await partyService.transferMemberToReserve(
        roomCode: session.roomCode,
        characterName: 'Gimli',
        performedBy: 'Gimli',
        gp: 40,
      );

      live = await partyService.streamSession(session.roomCode).first;
      expect(live!.getMemberPurse('Gimli').gp, equals(60));
      expect(live.partyPurse.gp, equals(40));

      // Withdraw 15 GP from Party Reserve back to Gimli
      await partyService.transferReserveToMember(
        roomCode: session.roomCode,
        characterName: 'Gimli',
        performedBy: 'Gimli',
        gp: 15,
      );

      live = await partyService.streamSession(session.roomCode).first;
      expect(live!.getMemberPurse('Gimli').gp, equals(75));
      expect(live.partyPurse.gp, equals(25));
    });
  });
}
