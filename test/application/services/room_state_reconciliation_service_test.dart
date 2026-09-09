import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_or_set.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';

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

    test('Pruning Safety Test: throws StateError when threshold physical time >= current time', () {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final futureThreshold = HybridLogicalClock(
        physicalTime: now + 60000,
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );
      final equalThreshold = HybridLogicalClock(
        physicalTime: now + 50, // slightly in future or exact current
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );

      const targetSet = CrdtOrSet<String>();

      expect(
        () => service.safePrune(targetSet, futureThreshold),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot prune CRDT tombstones using an unverified current/future timestamp.'),
        )),
      );

      expect(
        () => service.safePrune(targetSet, equalThreshold),
        throwsA(isA<StateError>()),
      );
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
  });
}
