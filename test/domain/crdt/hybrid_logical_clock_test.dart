import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';

void main() {
  group('HybridLogicalClock Tests', () {
    test('Clock Increment: tick() increments logicalCounter when within same millisecond', () {
      // Create a clock set to a future physical time so DateTime.now() will not exceed it
      const futureTime = 2500000000000;
      const clock0 = HybridLogicalClock(
        physicalTime: futureTime,
        logicalCounter: 0,
        nodeId: 'nodeA',
      );

      final clock1 = clock0.tick();
      expect(clock1.physicalTime, equals(futureTime));
      expect(clock1.logicalCounter, equals(1));
      expect(clock1.nodeId, equals('nodeA'));

      final clock2 = clock1.tick();
      expect(clock2.physicalTime, equals(futureTime));
      expect(clock2.logicalCounter, equals(2));

      final clock3 = clock2.tick();
      expect(clock3.physicalTime, equals(futureTime));
      expect(clock3.logicalCounter, equals(3));
    });

    test('tick() resets logicalCounter to 0 when physical time moves forward', () {
      // Clock in the past
      const pastClock = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 42,
        nodeId: 'nodeA',
      );

      final nextClock = pastClock.tick();
      expect(nextClock.physicalTime, greaterThan(1000));
      expect(nextClock.logicalCounter, equals(0));
      expect(nextClock.nodeId, equals('nodeA'));
    });

    test('Deterministic Tie-Breaking: compareTo() uses lexicographical nodeId when time and counter match', () {
      const fixedPt = 1700000000000;
      const fixedCounter = 5;

      const clockA = HybridLogicalClock(
        physicalTime: fixedPt,
        logicalCounter: fixedCounter,
        nodeId: 'nodeA',
      );

      const clockB = HybridLogicalClock(
        physicalTime: fixedPt,
        logicalCounter: fixedCounter,
        nodeId: 'nodeB',
      );

      // 'nodeB' > 'nodeA', so clockB is after clockA
      expect(clockB.isAfter(clockA), isTrue);
      expect(clockA.isBefore(clockB), isTrue);
      expect(clockA.compareTo(clockB), lessThan(0));
      expect(clockB.compareTo(clockA), greaterThan(0));
      expect(clockA.compareTo(clockA), equals(0));
    });

    test('compareTo() prioritizes physicalTime over logicalCounter and nodeId', () {
      const earlierClock = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 99,
        nodeId: 'nodeZ',
      );
      const laterClock = HybridLogicalClock(
        physicalTime: 2000,
        logicalCounter: 0,
        nodeId: 'nodeA',
      );

      expect(laterClock.isAfter(earlierClock), isTrue);
      expect(earlierClock.isBefore(laterClock), isTrue);
    });

    test('compareTo() prioritizes logicalCounter over nodeId when physicalTime is equal', () {
      const clock1 = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 1,
        nodeId: 'nodeZ',
      );
      const clock2 = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 2,
        nodeId: 'nodeA',
      );

      expect(clock2.isAfter(clock1), isTrue);
      expect(clock1.isBefore(clock2), isTrue);
    });

    test('merge() takes maximum physical time and updates logical counter causality', () {
      const futureTime = 3000000000000;

      // Case 1: remote physical time is higher
      const local1 = HybridLogicalClock(
        physicalTime: 2000000000000,
        logicalCounter: 10,
        nodeId: 'nodeLocal',
      );
      const remote1 = HybridLogicalClock(
        physicalTime: futureTime,
        logicalCounter: 3,
        nodeId: 'nodeRemote',
      );

      final merged1 = local1.merge(remote1);
      expect(merged1.physicalTime, equals(futureTime));
      expect(merged1.logicalCounter, equals(4));
      expect(merged1.nodeId, equals('nodeLocal'));

      // Case 2: both clocks at the same physical time (in future)
      const local2 = HybridLogicalClock(
        physicalTime: futureTime,
        logicalCounter: 5,
        nodeId: 'nodeLocal',
      );
      const remote2 = HybridLogicalClock(
        physicalTime: futureTime,
        logicalCounter: 8,
        nodeId: 'nodeRemote',
      );

      final merged2 = local2.merge(remote2);
      expect(merged2.physicalTime, equals(futureTime));
      expect(merged2.logicalCounter, equals(9)); // max(5, 8) + 1
      expect(merged2.nodeId, equals('nodeLocal'));
    });

    test('Value equality and hash code', () {
      const c1 = HybridLogicalClock(physicalTime: 100, logicalCounter: 1, nodeId: 'n1');
      const c2 = HybridLogicalClock(physicalTime: 100, logicalCounter: 1, nodeId: 'n1');
      const c3 = HybridLogicalClock(physicalTime: 100, logicalCounter: 2, nodeId: 'n1');

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1, isNot(equals(c3)));
    });
  });
}
