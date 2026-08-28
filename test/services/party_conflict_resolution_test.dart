import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PartyRoomService partyService;
  late CampaignRegistryService registry;
  late DiceRoomService diceService;

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    registry = CampaignRegistryService.newInstance();
    // ignore: invalid_use_of_visible_for_testing_member
    diceService = DiceRoomService.newInstance();
    partyService = PartyRoomService.newInstance(
      registry: registry,
      diceRoomService: diceService,
    );
  });

  group('Multi-Tier Conflict & Race Resolution Tests', () {
    test('Tier 1: Document Appends and Incremental Coin Deltas', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Delta Vault Campaign',
        playerName: 'DM',
      );

      final item1 = PartyLootItem(
        id: 'item_dagger_1',
        name: 'Dagger of Venom',
        category: 'magicItem',
        gpValue: 500,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      final item2 = PartyLootItem(
        id: 'item_ruby_2',
        name: 'Star Ruby',
        category: 'gem',
        gpValue: 1000,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: item1,
      );

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: item2,
      );

      final loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.length, equals(2));
      expect(loot.any((i) => i.id == 'item_dagger_1'), isTrue);
      expect(loot.any((i) => i.id == 'item_ruby_2'), isTrue);

      // Incremental deposits
      await partyService.depositCoins(
        roomCode: session.roomCode,
        playerName: 'Alice',
        gp: 50,
      );
      await partyService.depositCoins(
        roomCode: session.roomCode,
        playerName: 'Bob',
        gp: 30,
      );

      final liveSession = await partyService.streamSession(session.roomCode).first;
      expect(liveSession!.partyPurse.gp, equals(80));
    });

    test('Tier 2: Deterministic Claim Race Fallback & Stream Event', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Race Campaign',
        playerName: 'DM',
      );

      final sword = PartyLootItem(
        id: 'item_flametongue',
        name: 'Flame Tongue Longsword',
        category: 'magicItem',
        requiresAttunement: true,
        gpValue: 2000,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: sword,
      );

      // Player A (Winner) claims the sword
      await partyService.claimLootItem(
        roomCode: session.roomCode,
        lootId: sword.id,
        playerName: 'Aragorn',
      );

      var loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.firstWhere((i) => i.id == sword.id).claimedByPlayer, equals('Aragorn'));

      // Player B attempts to claim the same sword
      // In offline / race simulation with existing claim
      final conflictEvents = <ClaimConflictEvent>[];
      final sub = partyService.claimConflictStream.listen((e) => conflictEvents.add(e));

      // Re-claiming with Aragorn already set
      await partyService.claimLootItem(
        roomCode: session.roomCode,
        lootId: sword.id,
        playerName: 'Boromir',
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.firstWhere((i) => i.id == sword.id).isClaimed, isTrue);
    });

    test('Purse Overdraft Clamping and Audit Event Logging', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Overdraft Campaign',
        playerName: 'DM',
      );

      // Initial deposit of 20 GP
      await partyService.depositCoins(
        roomCode: session.roomCode,
        playerName: 'DM',
        gp: 20,
      );

      final overdraftEvents = <PurseOverdraftEvent>[];
      final sub = partyService.overdraftStream.listen((e) => overdraftEvents.add(e));

      // Withdraw 50 GP (overdraft by 30 GP)
      await partyService.withdrawCoins(
        roomCode: session.roomCode,
        playerName: 'Rogue',
        gp: 50,
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      final liveSession = await partyService.streamSession(session.roomCode).first;
      // Clamped to 0
      expect(liveSession!.partyPurse.gp, equals(0));

      // Overdraft event received
      expect(overdraftEvents.isNotEmpty, isTrue);
      expect(overdraftEvents.first.denomination, equals('GP'));
      expect(overdraftEvents.first.requestedDeduct, equals(50));
      expect(overdraftEvents.first.previousBalance, equals(20));

      // Audit events contain high-priority overdraft warning
      final events = await partyService.streamEvents(session.roomCode).first;
      expect(events.any((e) => e.type == 'purseOverdraftWarning'), isTrue);
      expect(events.firstWhere((e) => e.type == 'purseOverdraftWarning').details, contains('clamped to 0'));
    });

    test('Tier 3: Structural Fork & Host Diff Resolution 1 (Accept Cloud Version)', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Conflict Campaign',
        playerName: 'DM',
      );
      final membership = registry.getMembership(session.roomCode);
      final hostKey = membership!.hostKey!;

      final localItem = PartyLootItem(
        id: 'ring_protection',
        name: 'Ring of Protection (Offline Edit)',
        category: 'magicItem',
        gpValue: 1500,
        description: 'Modified locally while disconnected',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      final cloudPayload = {
        'id': 'ring_protection',
        'name': 'Ring of Protection +2 (Cloud Authoritative)',
        'category': 'magicItem',
        'gpValue': 3500.0,
        'description': 'Updated by Co-DM online with +2 bonus',
        'requiresAttunement': true,
        'isAttuned': true,
        'claimedByPlayer': 'Wizard',
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: localItem,
      );

      // Flag structural conflict
      partyService.flagItemConflict(session.roomCode, localItem.id, cloudPayload);

      var loot = await partyService.streamLoot(session.roomCode).first;
      var conflicted = loot.firstWhere((i) => i.id == localItem.id);
      expect(conflicted.hasConflict, isTrue);
      expect(conflicted.conflictPayload, isNotNull);

      // Resolve with Cloud Version
      await partyService.resolveConflictWithCloud(
        roomCode: session.roomCode,
        lootId: localItem.id,
        hostKey: hostKey,
        playerName: 'DM',
      );

      loot = await partyService.streamLoot(session.roomCode).first;
      var resolved = loot.firstWhere((i) => i.id == localItem.id);
      expect(resolved.hasConflict, isFalse);
      expect(resolved.name, equals('Ring of Protection +2 (Cloud Authoritative)'));
      expect(resolved.gpValue, equals(3500.0));
      expect(resolved.claimedByPlayer, equals('Wizard'));
    });

    test('Tier 3: Structural Fork & Host Diff Resolution 2 (Overwrite with Local)', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Local Overwrite Campaign',
        playerName: 'DM',
      );
      final membership = registry.getMembership(session.roomCode);
      final hostKey = membership!.hostKey!;

      final localItem = PartyLootItem(
        id: 'amulet_health',
        name: 'Amulet of Health (Custom 5e Stats)',
        category: 'magicItem',
        gpValue: 4000,
        description: 'Sets CON to 19',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      final cloudPayload = {
        'id': 'amulet_health',
        'name': 'Generic Amulet',
        'category': 'gear',
        'gpValue': 100.0,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: localItem,
      );

      partyService.flagItemConflict(session.roomCode, localItem.id, cloudPayload);

      // Resolve with Local Overwrite
      await partyService.resolveConflictWithLocal(
        roomCode: session.roomCode,
        lootId: localItem.id,
        hostKey: hostKey,
        playerName: 'DM',
      );

      final loot = await partyService.streamLoot(session.roomCode).first;
      final resolved = loot.firstWhere((i) => i.id == localItem.id);
      expect(resolved.hasConflict, isFalse);
      expect(resolved.name, equals('Amulet of Health (Custom 5e Stats)'));
      expect(resolved.gpValue, equals(4000.0));
      expect(resolved.description, equals('Sets CON to 19'));
    });

    test('Tier 3: Structural Fork & Host Diff Resolution 3 (Keep Both / Duplicate)', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Keep Both Campaign',
        playerName: 'DM',
      );
      final membership = registry.getMembership(session.roomCode);
      final hostKey = membership!.hostKey!;

      final localItem = PartyLootItem(
        id: 'staff_power',
        name: 'Staff of Power',
        category: 'magicItem',
        gpValue: 5000,
        description: 'Local custom version',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      final cloudPayload = {
        'id': 'staff_power',
        'name': 'Staff of Power (Attuned to Archmage)',
        'category': 'magicItem',
        'gpValue': 6000.0,
        'claimedByPlayer': 'Archmage',
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: localItem,
      );

      partyService.flagItemConflict(session.roomCode, localItem.id, cloudPayload);

      // Resolve with Keep Both
      await partyService.resolveConflictKeepBoth(
        roomCode: session.roomCode,
        lootId: localItem.id,
        hostKey: hostKey,
        playerName: 'DM',
      );

      final loot = await partyService.streamLoot(session.roomCode).first;
      expect(loot.length, equals(2));

      final cloudRetained = loot.firstWhere((i) => i.id == 'staff_power');
      expect(cloudRetained.hasConflict, isFalse);
      expect(cloudRetained.name, equals('Staff of Power (Attuned to Archmage)'));
      expect(cloudRetained.claimedByPlayer, equals('Archmage'));

      final duplicatedLocal = loot.firstWhere((i) => i.name.contains('(Copy)'));
      expect(duplicatedLocal.hasConflict, isFalse);
      expect(duplicatedLocal.name, equals('Staff of Power (Copy)'));
      expect(duplicatedLocal.gpValue, equals(5000));
    });

    test('Unauthorized user cannot execute Host Diff resolutions without valid hostKey', () async {
      final session = await partyService.createCampaign(
        campaignName: 'Auth Security Campaign',
        playerName: 'DM',
      );

      final localItem = PartyLootItem(
        id: 'cloak_elvenkind',
        name: 'Cloak of Elvenkind',
        category: 'magicItem',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await partyService.addLootItem(
        roomCode: session.roomCode,
        playerName: 'DM',
        item: localItem,
      );

      partyService.flagItemConflict(session.roomCode, localItem.id, {
        'id': 'cloak_elvenkind',
        'name': 'Cloud Cloak',
      });

      expect(
        () => partyService.resolveConflictWithCloud(
          roomCode: session.roomCode,
          lootId: localItem.id,
          hostKey: 'INVALID_HOST_KEY',
          playerName: 'HackerPlayer',
        ),
        throwsA(isA<UnauthorizedHostActionException>()),
      );

      expect(
        () => partyService.resolveConflictWithLocal(
          roomCode: session.roomCode,
          lootId: localItem.id,
          hostKey: 'INVALID_HOST_KEY',
          playerName: 'HackerPlayer',
        ),
        throwsA(isA<UnauthorizedHostActionException>()),
      );

      expect(
        () => partyService.resolveConflictKeepBoth(
          roomCode: session.roomCode,
          lootId: localItem.id,
          hostKey: 'INVALID_HOST_KEY',
          playerName: 'HackerPlayer',
        ),
        throwsA(isA<UnauthorizedHostActionException>()),
      );
    });
  });
}
