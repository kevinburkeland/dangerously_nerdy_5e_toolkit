import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_or_set.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/animated_object_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_lww_register_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/hybrid_logical_clock_dto.dart';

void main() {
  group('HybridLogicalClockDto Tests', () {
    test('toMap and fromMap serialize and deserialize accurately', () {
      const hlc = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 5,
        nodeId: 'node-abc-123',
      );

      final map = HybridLogicalClockDto.toMap(hlc);
      expect(map['pt'], equals(1700000000000));
      expect(map['lc'], equals(5));
      expect(map['node'], equals('node-abc-123'));

      final reconstructed = HybridLogicalClockDto.fromMap(map);
      expect(reconstructed, equals(hlc));
    });

    test('fromMap handles string values and missing fields with robust fallbacks', () {
      final stringMap = {
        'pt': '1700000000000',
        'lc': '42',
        'node': 'node-string',
      };

      final hlc = HybridLogicalClockDto.fromMap(stringMap);
      expect(hlc.physicalTime, equals(1700000000000));
      expect(hlc.logicalCounter, equals(42));
      expect(hlc.nodeId, equals('node-string'));

      final emptyMap = <String, dynamic>{};
      final fallbackHlc = HybridLogicalClockDto.fromMap(emptyMap);
      expect(fallbackHlc.physicalTime, greaterThan(0));
      expect(fallbackHlc.logicalCounter, equals(0));
      expect(fallbackHlc.nodeId, equals('unknown_node'));
    });
  });

  group('CrdtLwwRegisterDto Tests', () {
    test('Clamping Enforcement Test: parses and clamps numeric values strictly within bounds', () {
      int hpDecoder(dynamic raw) {
        if (raw is num) {
          return raw.toInt().clamp(0, 999);
        }
        throw const FormatException('Invalid HP value');
      }

      final jsonPayloadNegative = {
        'v': -50,
        'ts': {'pt': 1000, 'lc': 0, 'node': 'nodeA'},
      };

      final regNegative = CrdtLwwRegisterDto.fromMap<int>(jsonPayloadNegative, hpDecoder);
      expect(regNegative, isNotNull);
      expect(regNegative!.value, equals(0));

      final jsonPayloadExorbitant = {
        'v': 1500,
        'ts': {'pt': 1000, 'lc': 0, 'node': 'nodeA'},
      };

      final regExorbitant = CrdtLwwRegisterDto.fromMap<int>(jsonPayloadExorbitant, hpDecoder);
      expect(regExorbitant, isNotNull);
      expect(regExorbitant!.value, equals(999));
    });

    test('fromMap returns null on malformed timestamp or decoder error', () {
      final malformedPayload = {
        'v': 100,
        'ts': 'not_a_map',
      };

      final reg = CrdtLwwRegisterDto.fromMap<int>(malformedPayload, (v) => v as int);
      expect(reg, isNull);
    });
  });

  group('CrdtOrSetDto Tests', () {
    test('Fault Isolation Test: corrupted item 2 does not crash set and preserves items 1 and 3', () {
      int strictIntDecoder(dynamic raw) {
        if (raw is int) return raw;
        throw const FormatException('Expected integer');
      }

      final jsonPayload = {
        'items': {
          'item-1': {
            'v': 10,
            'ts': {'pt': 1000, 'lc': 0, 'node': 'node1'},
          },
          'item-2': {
            'v': 'corrupted_string_where_int_expected',
            'ts': {'pt': 2000, 'lc': 0, 'node': 'node2'},
          },
          'item-3': {
            'v': 30,
            'ts': {'pt': 3000, 'lc': 0, 'node': 'node3'},
          },
        },
        'tombstones': {
          'tomb-1': {'pt': 500, 'lc': 0, 'node': 'node1'},
          'tomb-corrupt': 'not_a_valid_tombstone_map',
        },
      };

      final orSet = CrdtOrSetDto.fromMap<int>(jsonPayload, strictIntDecoder);

      // Fault isolation: item-2 was discarded, item-1 and item-3 preserved
      expect(orSet.items.length, equals(2));
      expect(orSet.items.containsKey('item-1'), isTrue);
      expect(orSet.items['item-1']!.value, equals(10));
      expect(orSet.items.containsKey('item-2'), isFalse);
      expect(orSet.items.containsKey('item-3'), isTrue);
      expect(orSet.items['item-3']!.value, equals(30));

      expect(orSet.activeValues, containsAll([10, 30]));

      // Corrupt tombstone discarded, valid tombstone kept
      expect(orSet.tombstones.length, equals(1));
      expect(orSet.tombstones.containsKey('tomb-1'), isTrue);
    });

    test('Round-Trip Fidelity: CrdtOrSet<AnimatedObjectInstance> survives full serialization cycle', () {
      final minion1 = AnimatedObjectInstance(
        id: 'minion-uuid-1',
        name: 'Flying Sword 1',
        size: ObjectSize.small,
        currentHp: 25,
        maxHp: 25,
        marker: MinionMarker.alpha,
      );

      final minion2 = AnimatedObjectInstance(
        id: 'minion-uuid-2',
        name: 'Animated Table',
        size: ObjectSize.large,
        currentHp: 42,
        maxHp: 50,
        marker: MinionMarker.beta,
      );

      const ts1 = HybridLogicalClock(physicalTime: 1700000001000, logicalCounter: 1, nodeId: 'nodeA');
      const ts2 = HybridLogicalClock(physicalTime: 1700000002000, logicalCounter: 0, nodeId: 'nodeB');
      const tombstoneTs = HybridLogicalClock(physicalTime: 1700000000500, logicalCounter: 0, nodeId: 'nodeA');

      var originalSet = const CrdtOrSet<AnimatedObjectInstance>();
      originalSet = originalSet.add(minion1.id, minion1, ts1);
      originalSet = originalSet.add(minion2.id, minion2, ts2);
      // Simulate tombstone
      originalSet = CrdtOrSet<AnimatedObjectInstance>(
        items: originalSet.items,
        tombstones: {'minion-deleted-3': tombstoneTs},
      );

      // Serialize to Map
      final rawMap = CrdtOrSetDto.toMap<AnimatedObjectInstance>(
        originalSet,
        (minion) => AnimatedObjectDto.fromDomain(minion).toMap(),
      );

      // Full JSON encode / decode cycle
      final jsonString = jsonEncode(rawMap);
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;

      // Deserialize from Map
      final restoredSet = CrdtOrSetDto.fromMap<AnimatedObjectInstance>(
        decodedMap,
        (raw) => AnimatedObjectDto.fromMap(raw as Map<String, dynamic>).toDomain(),
      );

      // Verify Items
      expect(restoredSet.items.length, equals(2));
      expect(restoredSet.items.containsKey('minion-uuid-1'), isTrue);
      expect(restoredSet.items.containsKey('minion-uuid-2'), isTrue);

      final restoredMinion1 = restoredSet.items['minion-uuid-1']!;
      expect(restoredMinion1.timestamp, equals(ts1));
      expect(restoredMinion1.value.id, equals('minion-uuid-1'));
      expect(restoredMinion1.value.name, equals('Flying Sword 1'));
      expect(restoredMinion1.value.size, equals(ObjectSize.small));
      expect(restoredMinion1.value.currentHp, equals(25));
      expect(restoredMinion1.value.marker, equals(MinionMarker.alpha));

      final restoredMinion2 = restoredSet.items['minion-uuid-2']!;
      expect(restoredMinion2.timestamp, equals(ts2));
      expect(restoredMinion2.value.id, equals('minion-uuid-2'));
      expect(restoredMinion2.value.name, equals('Animated Table'));
      expect(restoredMinion2.value.size, equals(ObjectSize.large));
      expect(restoredMinion2.value.currentHp, equals(42));
      expect(restoredMinion2.value.marker, equals(MinionMarker.beta));

      // Verify Tombstones
      expect(restoredSet.tombstones.length, equals(1));
      expect(restoredSet.tombstones['minion-deleted-3'], equals(tombstoneTs));
    });
  });
}
