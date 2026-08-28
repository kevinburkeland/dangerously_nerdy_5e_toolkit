import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';

void main() {
  group('Party Models & Mathematical Integrity', () {
    test('PartyPurse GP conversion math is exact according to 5e rules', () {
      const purse = PartyPurse(
        pp: 10,  // 100 GP
        gp: 50,  // 50 GP
        ep: 20,  // 10 GP
        sp: 100, // 10 GP
        cp: 500, // 5 GP
      );

      expect(purse.totalGpEquivalent, equals(175.0));
      expect(purse.isEmpty, isFalse);

      const empty = PartyPurse();
      expect(empty.isEmpty, isTrue);
      expect(empty.totalGpEquivalent, equals(0.0));
    });

    test('PartyPurse coin deposit and withdraw operations clamp correctly', () {
      var purse = const PartyPurse(gp: 100, sp: 50);
      purse = purse.depositCoins(gp: 25, cp: 100);
      expect(purse.gp, equals(125));
      expect(purse.cp, equals(100));

      purse = purse.withdrawCoins(gp: 200, sp: 20); // 200 > 125, clamps at 0
      expect(purse.gp, equals(0));
      expect(purse.sp, equals(30));
    });

    test('PartyPurse splitShares evenly distributes coins and calculates remainders', () {
      const purse = PartyPurse(
        pp: 10,
        gp: 25,
        ep: 5,
        sp: 11,
        cp: 9,
      );

      final split = purse.splitShares(4);
      expect(split.playerCount, equals(4));
      expect(split.ppPerPlayer, equals(2)); // 10 ~/ 4 = 2, rem = 2
      expect(split.gpPerPlayer, equals(6)); // 25 ~/ 4 = 6, rem = 1
      expect(split.epPerPlayer, equals(1)); // 5 ~/ 4 = 1, rem = 1
      expect(split.spPerPlayer, equals(2)); // 11 ~/ 4 = 2, rem = 3
      expect(split.cpPerPlayer, equals(2)); // 9 ~/ 4 = 2, rem = 1

      expect(split.remainderPurse.pp, equals(2));
      expect(split.remainderPurse.gp, equals(1));
      expect(split.remainderPurse.ep, equals(1));
      expect(split.remainderPurse.sp, equals(3));
      expect(split.remainderPurse.cp, equals(1));
    });

    test('PartyPurse splitShares with liquidated gems and art objects', () {
      const purse = PartyPurse(gp: 100);
      final split = purse.splitShares(4, includeLiquidatedGemsAndArt: true, liquidatedGemsAndArtGp: 300.0);

      expect(split.liquidatedGemsAndArtIncluded, isTrue);
      expect(split.totalGpEquivalent, equals(400.0));
      expect(split.gpPerPlayer, equals(100));
      expect(split.remainderPurse.gp, equals(0));
    });

    test('PartyLootItem serialization and copyWith', () {
      final now = DateTime.now();
      final item = PartyLootItem(
        id: 'loot_1',
        name: 'Sun Blade',
        category: 'magicItem',
        count: 1,
        gpValue: 5000.0,
        requiresAttunement: true,
        isAttuned: true,
        claimedByPlayer: 'Thorin',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      expect(item.isClaimed, isTrue);
      expect(item.totalGpValue, equals(5000.0));

      final jsonMap = item.toMap();
      final restored = PartyLootItem.fromMap(jsonMap);
      expect(restored.name, equals('Sun Blade'));
      expect(restored.category, equals('magicItem'));
      expect(restored.claimedByPlayer, equals('Thorin'));
      expect(restored.isAttuned, isTrue);

      final unclaimed = item.copyWith(clearClaimedByPlayer: true);
      expect(unclaimed.claimedByPlayer, isNull);
      expect(unclaimed.isClaimed, isFalse);
    });

    test('CampaignMembership role checks and serialization', () {
      final membership = CampaignMembership(
        roomCode: 'ROOM-123456',
        campaignName: 'Curse of Strahd',
        role: CampaignRole.host,
        hostKey: 'secret-uuid-123',
        characterId: 'Kevin',
        lastPlayed: DateTime.now(),
      );

      expect(membership.isHost, isTrue);
      expect(membership.isDmOrCoDm, isTrue);
      expect(membership.hasHostKey, isTrue);

      final map = membership.toMap();
      final restored = CampaignMembership.fromMap(map);
      expect(restored.roomCode, equals('ROOM-123456'));
      expect(restored.role, equals(CampaignRole.host));
      expect(restored.hostKey, equals('secret-uuid-123'));
    });

    test('PartySessionState monotonic version and serialization', () {
      final now = DateTime.now();
      final session = PartySessionState(
        roomCode: 'ROOM-ABCDEF',
        campaignName: 'Waterdeep Dragon Heist',
        hostKeyHash: 'hash-abc-123',
        partyPurse: const PartyPurse(gp: 500),
        activePlayers: ['Alice', 'Bob'],
        version: 3,
        lastUpdated: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      final map = session.toMap();
      final restored = PartySessionState.fromMap(map);
      expect(restored.roomCode, equals('ROOM-ABCDEF'));
      expect(restored.version, equals(3));
      expect(restored.partyPurse.gp, equals(500));
      expect(restored.activePlayers.length, equals(2));
    });

    test('PartyEvent serialization and copyWith', () {
      final event = PartyEvent(
        id: 'evt_1',
        roomCode: 'ROOM-123456',
        type: 'coinDeposit',
        playerName: 'Gimli',
        details: 'Gimli deposited +50 GP',
        timestamp: DateTime.now(),
      );

      final map = event.toMap();
      final restored = PartyEvent.fromMap(map);
      expect(restored.type, equals('coinDeposit'));
      expect(restored.playerName, equals('Gimli'));
      expect(restored.details, contains('50 GP'));
    });
  });
}
