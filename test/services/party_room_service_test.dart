import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
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
  });
}
