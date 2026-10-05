import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';

void main() {
  group('Pass 2.3 Section A: MinionInstance Value Semantics & Equality', () {
    test('1. Two otherwise identical MinionInstances with different customProperties are NOT equal', () {
      final a = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: const {'status': 'active'},
      );
      final b = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: const {'status': 'dormant'},
      );

      expect(a == b, isFalse);
      expect(b == a, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('2. Independently allocated but structurally identical nested metadata are equal and have identical hashCodes', () {
      final a = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'fire', 'value': 3}
          ]
        },
      );
      final b = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'fire', 'value': 3}
          ]
        },
      );

      expect(identical(a, b), isFalse);
      expect(identical(a.customProperties, b.customProperties), isFalse);
      expect(a, equals(b));
      expect(b, equals(a));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('3. Same nested map entries inserted in different map order remain equal and have equal hashes', () {
      // Map A: 'a' then 'b'
      final mapA = <String, dynamic>{
        'meta': <String, dynamic>{'alpha': 1, 'beta': 2},
        'tags': ['blade', 'keen'],
      };
      // Map B: 'b' then 'a'
      final mapB = <String, dynamic>{
        'tags': ['blade', 'keen'],
        'meta': <String, dynamic>{'beta': 2, 'alpha': 1},
      };

      final a = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: mapA,
      );
      final b = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: mapB,
      );

      expect(a, equals(b));
      expect(b, equals(a));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('4. Nested list element order differences remain unequal', () {
      final a = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'fire', 'value': 3},
            {'type': 'cold', 'value': 2},
          ]
        },
      );
      final b = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'cold', 'value': 2},
            {'type': 'fire', 'value': 3},
          ]
        },
      );

      expect(a == b, isFalse);
      expect(b == a, isFalse);
    });

    test('5. copyWith(customProperties: ...) changes equality and hash when logical metadata changes', () {
      final original = MinionInstance(
        id: 'minion-1',
        name: 'Dagger',
        size: EntitySize.tiny,
        customProperties: const {'power': 10},
      );
      final updated = original.copyWith(
        customProperties: {'power': 20},
      );

      expect(original == updated, isFalse);
      expect(original.hashCode == updated.hashCode, isFalse);

      final reverted = updated.copyWith(
        customProperties: {'power': 10},
      );
      expect(original, equals(reverted));
      expect(original.hashCode, equals(reverted.hashCode));
    });
  });

  group('Pass 2.3 Section D: deepFreezeMap Key Integrity in Toolkit', () {
    test('nested string-key map succeeds', () {
      final frozen = deepFreezeMap({
        'nested': {'validKey': 123}
      });
      expect(frozen['nested'], equals({'validKey': 123}));
    });

    test('integer key throws ArgumentError', () {
      expect(
        () => deepFreezeMap({1: 'val'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mixed String and int keys throw ArgumentError', () {
      expect(
        () => deepFreezeMap({'ok': 'v', 42: 'bad'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('colliding key types {1: "a", "1": "b"} throw rather than collapsing', () {
      expect(
        () => deepFreezeMap({1: 'a', '1': 'b'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Pass 2.3 Section F: Hash/Equality Law Tests', () {
    test('Reflexive: a == a', () {
      final a = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'traits': ['pack tactics', 'keen smell'],
          'stats': {'bonus': 2},
        },
      );
      expect(a == a, isTrue);
    });

    test('Symmetric: a == b iff b == a', () {
      final a = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'traits': ['pack tactics'],
        },
      );
      final b = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'traits': ['pack tactics'],
        },
      );
      final c = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'traits': ['keen smell'],
        },
      );

      expect(a == b, isTrue);
      expect(b == a, isTrue);
      expect(a == c, isFalse);
      expect(c == a, isFalse);
    });

    test('Transitive: a == b and b == c implies a == c for independent allocations', () {
      final a = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'map': {'x': 1, 'y': 2},
          'list': [1, 2, 3],
        },
      );
      final b = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'map': {'y': 2, 'x': 1},
          'list': [1, 2, 3],
        },
      );
      final c = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'map': {'x': 1, 'y': 2},
          'list': [1, 2, 3],
        },
      );

      expect(a == b, isTrue);
      expect(b == c, isTrue);
      expect(a == c, isTrue);
      expect(a.hashCode, equals(b.hashCode));
      expect(b.hashCode, equals(c.hashCode));
    });

    test('Set and Map key lookups work reliably with structural hashing', () {
      final a = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'map': {'x': 1, 'y': 2},
        },
      );
      final b = MinionInstance(
        id: 'm1',
        name: 'Hound',
        size: EntitySize.medium,
        customProperties: {
          'map': {'y': 2, 'x': 1},
        },
      );

      final set = <MinionInstance>{a};
      expect(set.contains(b), isTrue);

      final map = <MinionInstance, String>{a: 'found'};
      expect(map[b], equals('found'));
    });
  });

  group('Pass 2.3 Section G: Sync / Echo-Suppression Regression', () {
    test('MinionInstance nested metadata mutation produces observable difference in RoomNodeState & CrdtOrSet', () {
      final minionA = MinionInstance(
        id: 'minion-dagger-1',
        name: 'Animated Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'poison', 'stacks': 1}
          ]
        },
      );

      final minionB = MinionInstance(
        id: 'minion-dagger-1',
        name: 'Animated Dagger',
        size: EntitySize.tiny,
        customProperties: {
          'effects': [
            {'type': 'poison', 'stacks': 2}
          ]
        },
      );

      // Verify Minions are not equal
      expect(minionA == minionB, isFalse);

      const hlc = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 1,
        nodeId: 'node-dm',
      );

      var setA = const CrdtOrSet<MinionInstance>.empty();
      setA = setA.add(minionA.id, minionA, hlc);

      var setB = const CrdtOrSet<MinionInstance>.empty();
      setB = setB.add(minionB.id, minionB, hlc);

      // CrdtOrSet elements differ
      expect(setA == setB, isFalse);

      final roomStateA = RoomNodeState(
        roomId: 'room-1',
        roomCode: 'RM-01',
        title: 'Throne Room',
        activeMinions: setA,
      );

      final roomStateB = RoomNodeState(
        roomId: 'room-1',
        roomCode: 'RM-01',
        title: 'Throne Room',
        activeMinions: setB,
      );

      // Crucial: roomState equality check in RoomSyncOrchestrator change detection
      // MUST NOT be suppressed when only nested metadata mutated!
      expect(roomStateA == roomStateB, isFalse);
      expect(roomStateA.hashCode == roomStateB.hashCode, isFalse);

      final now = DateTime.utc(2026, 1, 1);
      final profileA = CampaignProfile(
        id: 'camp-1',
        name: 'Campaign 1',
        createdAt: now,
        lastPlayedAt: now,
        nodeId: 'test_node',
        roomState: roomStateA,
      );

      final profileB = CampaignProfile(
        id: 'camp-1',
        name: 'Campaign 1',
        createdAt: now,
        lastPlayedAt: now,
        nodeId: 'test_node',
        roomState: roomStateB,
      );

      // Profile comparison or change detection is aware of the change
      expect(profileA.roomState == profileB.roomState, isFalse);
    });
  });
}
