import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_or_set.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';

void main() {
  group('PartyRoomService Tests', () {
    test('initializes with a valid UUIDv4 node ID and creates local timestamps', () {
      final service1 = PartyRoomService();
      final service2 = PartyRoomService();

      expect(service1.localNodeId, isNotEmpty);
      expect(service2.localNodeId, isNotEmpty);
      expect(service1.localNodeId, isNot(equals(service2.localNodeId)));

      final ts = service1.createLocalTimestamp();
      expect(ts.nodeId, equals(service1.localNodeId));
      expect(ts.logicalCounter, equals(0));
      expect(ts.physicalTime, greaterThan(0));
    });
  });

  group('RoomStateReconciliationService Tests', () {
    final service = RoomStateReconciliationService();

    test('Pruning Safety Test: gracefully defers pruning when threshold physical time >= current network time', () {
      const now = 100000;
      final timeSyncedService = RoomStateReconciliationService(
        networkTimeProvider: () => now,
      );

      const futureThreshold = HybridLogicalClock(
        physicalTime: 160000,
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );
      const equalThreshold = HybridLogicalClock(
        physicalTime: 100000,
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );

      const targetSet = CrdtOrSet<String>(
        tombstones: {
          'item-1': HybridLogicalClock(physicalTime: 50000, logicalCounter: 0, nodeId: 'nodeA'),
        },
      );

      // Does not throw StateError; defers pruning and preserves targetSet
      final deferred1 = timeSyncedService.safePrune(targetSet, futureThreshold);
      expect(deferred1.tombstones.containsKey('item-1'), isTrue);

      final deferred2 = timeSyncedService.safePrune(targetSet, equalThreshold);
      expect(deferred2.tombstones.containsKey('item-1'), isTrue);
    });

    test('safePrune successfully prunes historical tombstones when threshold is safely in past', () {
      const pastTs1 = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const pastTs2 = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');
      const recentTs = HybridLogicalClock(physicalTime: 4000, logicalCounter: 0, nodeId: 'nodeA');

      const historicalThreshold = HybridLogicalClock(
        physicalTime: 3000,
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );

      const setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          'tomb-1': pastTs1,
          'tomb-2': pastTs2,
          'tomb-3': recentTs,
        },
      );

      final pruned = service.safePrune(setWithTombstones, historicalThreshold);

      expect(pruned.tombstones.containsKey('tomb-1'), isFalse);
      expect(pruned.tombstones.containsKey('tomb-2'), isFalse);
      expect(pruned.tombstones.containsKey('tomb-3'), isTrue);
      expect(pruned.tombstones['tomb-3'], equals(recentTs));
    });

    test('Milestone Pruning Safety: executeMilestonePrune translates epoch ms and prunes tombstones', () {
      const pastTs1 = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const pastTs2 = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');
      const recentTs = HybridLogicalClock(physicalTime: 5000, logicalCounter: 0, nodeId: 'nodeC');

      const setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          'old-tomb-1': pastTs1,
          'old-tomb-2': pastTs2,
          'active-tomb': recentTs,
        },
      );

      // Server acknowledges snapshot at epoch 3000
      final pruned = service.executeMilestonePrune(
        setWithTombstones,
        3000,
        'server-host',
      );

      expect(pruned.tombstones.containsKey('old-tomb-1'), isFalse);
      expect(pruned.tombstones.containsKey('old-tomb-2'), isFalse);
      expect(pruned.tombstones.containsKey('active-tomb'), isTrue);
      expect(pruned.tombstones['active-tomb'], equals(recentTs));
    });

    test('Milestone Pruning Safety: executeMilestonePrune defers pruning when epoch >= network time', () {
      final skewService = RoomStateReconciliationService(
        networkTimeProvider: () => 5000,
      );

      const pastTs = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const setWithTombstones = CrdtOrSet<String>(
        tombstones: {'tomb-1': pastTs},
      );

      // Server acknowledges snapshot at epoch 6000 (ahead of network time 5000 due to skew)
      final deferred = skewService.executeMilestonePrune(
        setWithTombstones,
        6000,
        'server-host',
      );

      // Must not wipe tombstones up to currentNetworkTime - 1; must defer pruning
      expect(deferred.tombstones.containsKey('tomb-1'), isTrue);
      expect(deferred.tombstones.length, equals(1));
    });

    test('PartyPurse Reconciliation: Spending money to 0 does not resurrect remote currency', () {
      // Local spent all 100 GP
      final local = const PartyPurse()
          .depositCoins(gp: 100, nodeId: 'host')
          .withdrawCoins(gp: 100, nodeId: 'local');
      expect(local.gp, 0);

      // Remote still has the unspent 100 GP
      final remote = const PartyPurse().depositCoins(gp: 100, nodeId: 'host');
      expect(remote.gp, 100);

      // Merge local and remote
      final merged = service.reconcileProfile(
        local: CampaignProfile.defaultProfile(id: 'camp1').copyWith(partyPurse: local),
        remote: CampaignProfile.defaultProfile(id: 'camp1').copyWith(partyPurse: remote),
        inboundTimestampMs: 2000,
        localTimestampMs: 1000,
      );

      // The 100 GP spent by local MUST NOT be resurrected!
      expect(merged.partyPurse.gp, 0);
    });

    test('PartyPurse Reconciliation: Concurrent deposits across peers converge via PN-counter', () {
      // Peer A deposits 100 GP
      final purseA = const PartyPurse().depositCoins(gp: 100, nodeId: 'peerA');

      // Peer B deposits 50 GP
      final purseB = const PartyPurse().depositCoins(gp: 50, nodeId: 'peerB');

      final merged = service.reconcileProfile(
        local: CampaignProfile.defaultProfile(id: 'camp1').copyWith(partyPurse: purseA),
        remote: CampaignProfile.defaultProfile(id: 'camp1').copyWith(partyPurse: purseB),
        inboundTimestampMs: 2000,
        localTimestampMs: 1000,
      );

      // Both deposits converge: 100 + 50 = 150 GP
      expect(merged.partyPurse.gp, 150);
    });
  });
}
