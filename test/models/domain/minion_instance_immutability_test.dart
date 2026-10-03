import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

void main() {
  group('Pass 2.2 Task 1: MinionInstance customProperties Deep Immutability', () {
    test('nested maps and lists are deep-frozen and isolated from external mutation', () {
      final Map<String, dynamic> nested = {
        'effects': <String, dynamic>{
          'tags': <dynamic>['flying'],
        },
      };

      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Gargoyle',
        size: EntitySize.medium,
        customProperties: nested,
      );

      // Mutate the original caller-owned nested structure
      ((nested['effects'] as Map)['tags'] as List).add('invisible');
      (nested['effects'] as Map)['newKey'] = 'malicious';
      nested['added'] = 123;

      // minion.customProperties must remain intact and isolated
      final minionEffects = minion.customProperties['effects'] as Map<String, dynamic>;
      final minionTags = minionEffects['tags'] as List<String>;

      expect(minionTags, equals(['flying']));
      expect(minionEffects.containsKey('newKey'), isFalse);
      expect(minion.customProperties.containsKey('added'), isFalse);

      // Mutating exposed nested structures must throw UnsupportedError
      expect(() => minionTags.add('invisible'), throwsA(isA<UnsupportedError>()));
      expect(() => minionEffects['newKey'] = 'fail', throwsA(isA<UnsupportedError>()));
      expect(() => minion.customProperties['added'] = 456, throwsA(isA<UnsupportedError>()));
    });

    test('copyWith path routes through deepFreezeMap and rejects external mutation', () {
      final initial = MinionInstance(
        id: 'minion-2',
        name: 'Homunculus',
        size: EntitySize.tiny,
        customProperties: {'status': 'dormant'},
      );

      final Map<String, dynamic> newNested = {
        'auras': [
          {'name': 'healing', 'radius': 10}
        ],
      };

      final updated = initial.copyWith(customProperties: newNested);

      // Mutate the caller map
      ((newNested['auras'] as List).first as Map)['radius'] = 999;
      (newNested['auras'] as List).add({'name': 'fire', 'radius': 5});

      final updatedAuras = updated.customProperties['auras'] as List;
      final firstAura = updatedAuras.first as Map;

      expect(firstAura['radius'], equals(10));
      expect(updatedAuras.length, equals(1));
      expect(() => updatedAuras.add({'evil': true}), throwsA(isA<UnsupportedError>()));
      expect(() => firstAura['radius'] = 100, throwsA(isA<UnsupportedError>()));
    });
  });

  group('Pass 2.2 Task 2: Transitive EntityReference Immutability in Toolkit', () {
    test('direct: mutating original map/list does not alter EntityReference', () {
      final Map<String, dynamic> props = {
        'weapon': {
          'tags': ['magic'],
        },
      };
      final List<dynamic> skills = ['Arcana', 'History'];

      final ref = EntityReference<DomainEntity>(
        refType: EntityType.equipment,
        slug: 'staff-of-power',
        displayName: 'Staff of Power',
        grantedSkills: skills,
        customProperties: props,
      );

      ((props['weapon'] as Map)['tags'] as List).clear();
      skills.add('Stealth');

      final refWeapon = ref.customProperties['weapon'] as Map<String, dynamic>;
      final refTags = refWeapon['tags'] as List<String>;

      expect(refTags, equals(['magic']));
      expect(ref.grantedSkills, equals(['Arcana', 'History']));
      expect(() => refTags.clear(), throwsA(isA<UnsupportedError>()));
      expect(() => ref.grantedSkills.add('Hacking'), throwsA(isA<UnsupportedError>()));
    });

    test('transitive: mutating EntityReference collections does not alter CRDT-stamped LootContainer', () {
      final Map<String, dynamic> itemProps = {
        'charges': {'max': 10, 'current': 10},
      };

      final ref = EntityReference<DomainEntity>(
        refType: EntityType.equipment,
        slug: 'wand-of-fireballs',
        displayName: 'Wand of Fireballs',
        customProperties: itemProps,
      );

      final item = InventoryItemInstance(
        instanceId: 'item-1',
        itemRef: ref,
      );

      final container = LootContainer(
        containerId: 'chest-1',
        name: 'Treasure Chest',
        items: [item],
      );

      const hlc = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 1,
        nodeId: 'node-a',
      );

      var crdt = const CrdtOrSet<RoomNodeState>.empty();
      final roomNode = RoomNodeState(
        roomId: 'room-1',
        roomCode: 'RM-01',
        title: 'Vault',
        containers: [container],
      );
      crdt = crdt.add(roomNode.roomId, roomNode, hlc);

      // Mutate original itemProps map
      ((itemProps['charges'] as Map)['current'] = 0);
      itemProps['tampered'] = true;

      final stampedRoom = crdt.activeValues.first;
      final stampedContainer = stampedRoom.containers.first;
      final stampedItem = stampedContainer.items.first;
      final stampedProps = stampedItem.itemRef.customProperties;

      expect((stampedProps['charges'] as Map)['current'], equals(10));
      expect(stampedProps.containsKey('tampered'), isFalse);
    });
  });

  group('Pass 2.2 Task 6: End-to-End Active Minion Regression', () {
    test('mutable nested map -> MinionInstance -> RoomNodeState.activeMinions -> CrdtOrSet', () {
      final Map<String, dynamic> mutableInput = {
        'tactics': <String, dynamic>{
          'conditions': <dynamic>['invisible', 'hovering'],
          'priorityTarget': 'caster',
        },
        'metadata': <String, dynamic>{
          'source': 'animate_objects',
        },
      };

      final minion = MinionInstance(
        id: 'minion-obj-1',
        name: 'Animated Dagger',
        size: EntitySize.tiny,
        customProperties: mutableInput,
      );

      const hlc = HybridLogicalClock(
        physicalTime: 2000,
        logicalCounter: 42,
        nodeId: 'peer-test-1',
      );

      var activeMinionsSet = const CrdtOrSet<dynamic>.empty();
      activeMinionsSet = activeMinionsSet.add(minion.id, minion, hlc);

      final room = RoomNodeState(
        roomId: 'room-active-node',
        roomCode: 'ACT-01',
        title: 'Arena Node',
        activeMinions: activeMinionsSet,
      );

      final beforeMap = room.toMap();

      // Mutate original nested input collections afterward
      ((mutableInput['tactics'] as Map)['conditions'] as List).add('compromised');
      ((mutableInput['tactics'] as Map)['conditions'] as List).remove('invisible');
      (mutableInput['tactics'] as Map)['priorityTarget'] = 'tank';
      (mutableInput['metadata'] as Map)['hacked'] = true;
      mutableInput['injected'] = 'payload';

      // 1. Stamped value did not change
      final stampedMinion = room.activeMinions.activeValues.first as MinionInstance;
      final stampedTactics = stampedMinion.customProperties['tactics'] as Map<String, dynamic>;
      final stampedConditions = stampedTactics['conditions'] as List<String>;

      expect(stampedConditions, equals(['invisible', 'hovering']));
      expect(stampedTactics['priorityTarget'], equals('caster'));
      expect((stampedMinion.customProperties['metadata'] as Map).containsKey('hacked'), isFalse);
      expect(stampedMinion.customProperties.containsKey('injected'), isFalse);

      // 2. Nested mutation through stamped value throws UnsupportedError
      expect(() => stampedConditions.add('fail'), throwsA(isA<UnsupportedError>()));
      expect(() => stampedTactics['newKey'] = 'fail', throwsA(isA<UnsupportedError>()));
      expect(() => (stampedMinion.customProperties['metadata'] as Map)['newKey'] = 'fail',
          throwsA(isA<UnsupportedError>()));

      // 3. Equality / serialization observed before and after external mutation is unchanged
      final afterMap = room.toMap();
      expect(afterMap, equals(beforeMap));
    });
  });
}
