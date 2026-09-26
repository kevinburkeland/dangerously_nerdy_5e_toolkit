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
        pp: 10, // 100 GP
        gp: 50, // 50 GP
        ep: 20, // 10 GP
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

    test(
        'PartyPurse splitShares evenly distributes coins and calculates remainders',
        () {
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
      final split = purse.splitShares(4,
          includeLiquidatedGemsAndArt: true, liquidatedGemsAndArtGp: 300.0);

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
        claimedByPlayer: 'Thorek',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      expect(item.isClaimed, isTrue);
      expect(item.totalGpValue, equals(5000.0));

      expect(item.categoryLabel, equals('Magic Item'));

      final jsonMap = item.toMap();
      final restored = PartyLootItem.fromMap(jsonMap);
      expect(restored.name, equals('Sun Blade'));
      expect(restored.category, equals('magicItem'));
      expect(restored.claimedByPlayer, equals('Thorek'));
      expect(restored.isAttuned, isTrue);

      final unclaimed = item.copyWith(clearClaimedByPlayer: true);
      expect(unclaimed.claimedByPlayer, isNull);
      expect(unclaimed.isClaimed, isFalse);
    });

    test('CampaignMembership role checks and serialization', () {
      final membership = CampaignMembership(
        roomCode: 'ROOM-123456',
        campaignName: 'Tomb of Annihilation',
        role: CampaignRole.host,
        hostKey: 'secret-uuid-123',
        characterId: 'DM Kevin',
        lastPlayed: DateTime.now(),
      );

      expect(membership.isHost, isTrue);
      expect(membership.isDmOrCoDm, isTrue);

      final map = membership.toMap();
      final restored = CampaignMembership.fromMap(map);
      expect(restored.roomCode, equals('ROOM-123456'));
      expect(restored.role, equals(CampaignRole.host));
    });

    test('PartySessionState monotonic version and serialization', () {
      final now = DateTime.now();
      final session = PartySessionState(
        roomCode: 'ROOM-ABCDEF',
        campaignName: 'Crown City Vault Heist',
        hostKeyHash: 'hash-abc-123',
        partyPurse: const PartyPurse(gp: 500),
        activePlayers: ['Alice', 'Bob'],
        characterRoster: ['Alice (Rogue)', 'Bob (Cleric)', 'Charlie (Wizard)'],
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
      expect(restored.characterRoster, contains('Charlie (Wizard)'));
    });

    test('PartyEvent serialization and copyWith', () {
      final event = PartyEvent(
        id: 'evt_1',
        roomCode: 'ROOM-123456',
        type: 'coinDeposit',
        playerName: 'Dain',
        details: 'Dain deposited +50 GP',
        timestamp: DateTime.now(),
      );

      final map = event.toMap();
      final restored = PartyEvent.fromMap(map);
      expect(restored.type, equals('coinDeposit'));
      expect(restored.playerName, equals('Dain'));
      expect(restored.details, contains('50 GP'));
    });

    test('PartyPurse add and deduct methods combine coin denominations cleanly',
        () {
      const purse1 = PartyPurse(pp: 2, gp: 50, ep: 10, sp: 20, cp: 100);
      const purse2 = PartyPurse(pp: 1, gp: 25, ep: 5, sp: 10, cp: 50);

      final sum = purse1.add(purse2);
      expect(sum.pp, equals(3));
      expect(sum.gp, equals(75));
      expect(sum.ep, equals(15));
      expect(sum.sp, equals(30));
      expect(sum.cp, equals(150));

      final diff = sum.deduct(purse2);
      expect(diff.pp, equals(2));
      expect(diff.gp, equals(50));
      expect(diff.ep, equals(10));
      expect(diff.sp, equals(20));
      expect(diff.cp, equals(100));

      // Overdrawing clamps at 0
      const largePurse = PartyPurse(gp: 500);
      final overdrawn = diff.deduct(largePurse);
      expect(overdrawn.gp, equals(0));
      expect(overdrawn.pp, equals(2));
    });

    test(
        'PartyPurse deductGpEquivalent makes change and repacks into optimal denominations',
        () {
      // Coin Breakdown Deduct Test: 1 PP = 10 GP; deduct 0.5 GP (5 SP) => 9.5 GP (9 GP, 1 EP)
      const purse = PartyPurse(pp: 1);
      final result = purse.deductGpEquivalent(0.5);

      expect(result.pp, equals(0));
      expect(result.gp, equals(9));
      expect(result.ep, equals(1));
      expect(result.sp, equals(0));
      expect(result.cp, equals(0));
      expect(result.totalGpEquivalent, equals(9.5));

      // Deduct zero or negative cost returns same purse
      expect(purse.deductGpEquivalent(0), equals(purse));
      expect(purse.deductGpEquivalent(-5.0), equals(purse));

      // Exact balance deduction returns empty purse
      final exactResult = purse.deductGpEquivalent(10.0);
      expect(exactResult.isEmpty, isTrue);

      // Insufficient funds throws StateError
      expect(
        () => purse.deductGpEquivalent(15.0),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient funds'),
        )),
      );
    });

    test(
        'PartySessionState memberPurses serialization and helper getMemberPurse',
        () {
      final now = DateTime.now();
      final session = PartySessionState(
        roomCode: 'ROOM-123456',
        campaignName: 'Shadows of the Vampire',
        hostKeyHash: 'hash-123',
        partyPurse: const PartyPurse(gp: 1000),
        memberPurses: const {
          'Iselde': PartyPurse(gp: 150, sp: 20),
          'Kaelen': PartyPurse(pp: 5, gp: 300),
        },
        characterRoster: ['Iselde', 'Kaelen', 'Valeros'],
        lastUpdated: now,
        expiresAt: now.add(const Duration(days: 30)),
      );

      expect(session.getMemberPurse('Iselde').gp, equals(150));
      expect(session.getMemberPurse('Iselde').sp, equals(20));
      expect(session.getMemberPurse('Kaelen').pp, equals(5));
      // Uninitialized character returns empty purse
      expect(session.getMemberPurse('Valeros').isEmpty, isTrue);

      final map = session.toMap();
      final restored = PartySessionState.fromMap(map);

      expect(restored.memberPurses.length, equals(2));
      expect(restored.getMemberPurse('Iselde').gp, equals(150));
      expect(
          restored.getMemberPurse('Kaelen').totalGpEquivalent, equals(350.0));
    });

    test(
        'PartyPurse.fromMap prioritizes scalar increment over stale counter and re-seeds',
        () {
      // Simulate Firestore snapshot after FieldValue.increment added 20 GP (total 30 GP),
      // while the nested gpCounter still had old {local: 10}.
      final staleMap = <String, dynamic>{
        'cp': 0,
        'sp': 0,
        'ep': 0,
        'gp': 30, // Updated by atomic increment
        'pp': 0,
        'gpCounter': {
          'positive': {'deviceA': 10},
          'negative': {},
        },
      };

      final purse = PartyPurse.fromMap(staleMap);
      expect(purse.gp, equals(30),
          reason: 'Scalar value must take precedence over stale counter');
      expect(purse.effectiveGpCounter.value, equals(30),
          reason: 'PN-counter must be re-seeded to 30');

      // Subsequent deposit of 5 GP should compute 35 GP
      final updated = purse.depositCoins(gp: 5, nodeId: 'deviceB');
      expect(updated.gp, equals(35));
    });

    test(
        'PartyPurse.fromMap safely parses generic Map<dynamic, dynamic> counters without TypeError',
        () {
      final dynamicMap = <dynamic, dynamic>{
        'gp': 25,
        'gpCounter': <dynamic, dynamic>{
          'positive': <dynamic, dynamic>{'deviceA': 25},
          'negative': <dynamic, dynamic>{},
        },
      };

      final purse = PartyPurse.fromMap(Map<String, dynamic>.from(dynamicMap));
      expect(purse.gp, equals(25));
      expect(purse.effectiveGpCounter.value, equals(25));
    });

    test(
        'PartyPurse CvRDT merge does not compound or double balances across snapshots',
        () {
      final p1 = PartyPurse.fromMap(const {
        'gp': 100,
      });
      final p2 = PartyPurse.fromMap(const {
        'gp': 100,
      });

      // Lattice join of identical snapshots must yield exactly 100 GP, NOT 200 GP
      final merged = p1.merge(p2);
      expect(merged.gp, equals(100));
      expect(merged.effectiveGpCounter.value, equals(100));

      // Merging repeatedly must remain strictly idempotent
      final mergedAgain = merged.merge(p1).merge(p2);
      expect(mergedAgain.gp, equals(100));
      expect(mergedAgain.effectiveGpCounter.value, equals(100));
    });
  });
}
