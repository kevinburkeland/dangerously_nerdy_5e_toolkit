import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';

void main() {
  group('PartyRoomService Tests', () {
    test('initializes with a valid node ID and creates local timestamps',
        () {
      final service1 = PartyRoomService(replicaId: ReplicaId('node-alpha-1'));
      final service2 = PartyRoomService(replicaId: ReplicaId('node-beta-2'));

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
    final service = RoomStateReconciliationService(
      networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    test(
        'Tombstone Safety: safePrune retains tombstones indefinitely even when candidate threshold is safely in past',
        () {
      const pastTs1 = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const pastTs2 = HybridLogicalClock(
          physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');
      const recentTs = HybridLogicalClock(
          physicalTime: 4000, logicalCounter: 0, nodeId: 'nodeA');

      const historicalThreshold = HybridLogicalClock(
        physicalTime: 3000,
        logicalCounter: 0,
        nodeId: 'nodeLeader',
      );

      final setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          'tomb-1': pastTs1,
          'tomb-2': pastTs2,
          'tomb-3': recentTs,
        },
      );

      final result = service.safePrune(setWithTombstones, historicalThreshold);

      // Elapsed time does not prove causal acknowledgement; all tombstones are retained
      expect(result.tombstones.containsKey('tomb-1'), isTrue);
      expect(result.tombstones.containsKey('tomb-2'), isTrue);
      expect(result.tombstones.containsKey('tomb-3'), isTrue);
      expect(result.tombstones['tomb-3'], equals(recentTs));
    });

    test(
        'Tombstone Safety: executeMilestonePrune retains tombstones indefinitely without time-based garbage collection',
        () {
      const pastTs1 = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const pastTs2 = HybridLogicalClock(
          physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');
      const recentTs = HybridLogicalClock(
          physicalTime: 5000, logicalCounter: 0, nodeId: 'nodeC');

      final setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          'old-tomb-1': pastTs1,
          'old-tomb-2': pastTs2,
          'active-tomb': recentTs,
        },
      );

      // Milestone timestamp in past (3000 ms)
      final result = service.executeMilestonePrune(
        setWithTombstones,
        3000,
        'server-host',
      );

      // Milestone age does not prove causal observation across offline replicas; all tombstones retained
      expect(result.tombstones.containsKey('old-tomb-1'), isTrue);
      expect(result.tombstones.containsKey('old-tomb-2'), isTrue);
      expect(result.tombstones.containsKey('active-tomb'), isTrue);
      expect(result.tombstones['active-tomb'], equals(recentTs));
    });

    test(
        'Network time advancement alone cannot make a tombstone eligible for deletion',
        () {
      // Network clock advances far into future (days / years ahead)
      final farFutureService = RoomStateReconciliationService(
        networkTimeProvider: () => 9999999999999,
      );

      const pastTs = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      final setWithTombstones = CrdtOrSet<String>(
        tombstones: {'tomb-1': pastTs},
      );

      final result1 = farFutureService.safePrune(
        setWithTombstones,
        const HybridLogicalClock(
            physicalTime: 5000000, logicalCounter: 0, nodeId: 'host'),
      );
      final result2 = farFutureService.executeMilestonePrune(
        setWithTombstones,
        5000000,
        'host',
      );

      expect(result1.tombstones.containsKey('tomb-1'), isTrue);
      expect(result2.tombstones.containsKey('tomb-1'), isTrue);
    });

    test(
        'Heartbeat expiry / TTL lookback alone cannot make a tombstone eligible for deletion',
        () {
      const now = 100000;
      final serviceWithClock = RoomStateReconciliationService(
        networkTimeProvider: () => now,
      );

      // Ancient tombstone 10x past standard heartbeat TTL
      const ancientTombstoneTs = HybridLogicalClock(
          physicalTime: 0, logicalCounter: 0, nodeId: 'nodeA');
      final setWithTombstones = CrdtOrSet<String>(
        tombstones: {'expired-heartbeat-tomb': ancientTombstoneTs},
      );

      final result = serviceWithClock.safePrune(
        setWithTombstones,
        const HybridLogicalClock(
            physicalTime: 80000, logicalCounter: 0, nodeId: 'host'),
        safeBufferMs: 20000,
      );

      expect(
          result.tombstones.containsKey('expired-heartbeat-tomb'), isTrue);
    });

    test(
        'Causal Safety: retainTombstones explicitly retains all set entries without modification',
        () {
      final setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          't1': const HybridLogicalClock(
              physicalTime: 100, logicalCounter: 0, nodeId: 'n1'),
          't2': const HybridLogicalClock(
              physicalTime: 200, logicalCounter: 0, nodeId: 'n2'),
        },
      );

      final retained = service.retainTombstones(setWithTombstones);
      expect(retained.tombstones.length, equals(2));
      expect(retained.tombstones.containsKey('t1'), isTrue);
      expect(retained.tombstones.containsKey('t2'), isTrue);
    });

    test(
        'Regression: Stale offline replica cannot resurrect deleted entity after maintenance cycle',
        () {
      // 1. Replica A adds entity X
      const tsAdd = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 0, nodeId: 'replica-A');
      var setA = const CrdtOrSet<String>.empty().add('entity-x', 'entity-x', tsAdd);
      expect(setA.items.containsKey('entity-x'), isTrue);
      expect(setA.activeValues, contains('entity-x'));

      // 2. Replica B learns about X
      var setB = const CrdtOrSet<String>.empty().merge(setA);
      expect(setB.items.containsKey('entity-x'), isTrue);
      expect(setB.activeValues, contains('entity-x'));

      // 3. Replica B removes X, creating a tombstone
      const tsRemove = HybridLogicalClock(
          physicalTime: 2000, logicalCounter: 0, nodeId: 'replica-B');
      setB = setB.remove('entity-x', tsRemove);
      expect(setB.items.containsKey('entity-x'), isFalse);
      expect(setB.activeValues, isNot(contains('entity-x')));
      expect(setB.tombstones.containsKey('entity-x'), isTrue);

      // 4. Replica A goes offline before learning about the removal.
      // Replica A still has setA with entity X at tsAdd (1000).

      // 5. Significant simulated time passes (e.g. 60 seconds)
      const simulatedNow = 60000;
      final hostReconciliation = RoomStateReconciliationService(
        networkTimeProvider: () => simulatedNow,
      );

      // 6. Host milestone / maintenance path runs on Replica B
      setB = hostReconciliation.executeMilestonePrune(
        setB,
        simulatedNow - 20000,
        'replica-B',
      );

      // 7. Replica A reconnects carrying its stale pre-deletion add
      final reconciledOnB = setB.merge(setA);

      // 8. Invariant: entity X MUST remain deleted
      expect(reconciledOnB.items.containsKey('entity-x'), isFalse,
          reason: 'Entity X must not be resurrected by stale offline replica');
      expect(reconciledOnB.activeValues, isNot(contains('entity-x')));
      expect(reconciledOnB.tombstones.containsKey('entity-x'), isTrue);

      // Contrast: Demonstrate that the old time-based pruning behavior would fail this test
      const flawedPruneThreshold = HybridLogicalClock(
          physicalTime: 40000, logicalCounter: 0, nodeId: 'replica-B');
      final flawedSetB = setB.prune(flawedPruneThreshold);
      expect(flawedSetB.tombstones.isEmpty, isTrue,
          reason: 'Low-level prune deleted the tombstone based on elapsed time');
      final flawedReconciliation = flawedSetB.merge(setA);
      expect(flawedReconciliation.items.containsKey('entity-x'), isTrue,
          reason: 'Proves the flaw: old time-based pruning resurrected deleted state');
      expect(flawedReconciliation.activeValues, contains('entity-x'));
    });

    test(
        'Legitimate newer re-add succeeds when re-add has a strictly newer HLC than the tombstone',
        () {
      // 1. Entity X deleted at T2
      const tsRemove = HybridLogicalClock(
          physicalTime: 2000, logicalCounter: 0, nodeId: 'peerA');
      var set = const CrdtOrSet<String>.empty()
          .add('item-1', 'item-1', const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'peerA'))
          .remove('item-1', tsRemove);
      expect(set.items.containsKey('item-1'), isFalse);
      expect(set.activeValues, isEmpty);
      expect(set.tombstones.containsKey('item-1'), isTrue);

      // 2. Entity X legitimately re-added with strictly newer HLC at T3 (3000 > 2000)
      const tsReAdd = HybridLogicalClock(
          physicalTime: 3000, logicalCounter: 0, nodeId: 'peerB');
      set = set.add('item-1', 'item-1-revived', tsReAdd);

      // 3. New add wins because tsReAdd > tsRemove
      expect(set.items.containsKey('item-1'), isTrue);
      expect(set.activeValues, equals(['item-1-revived']));
      expect(set.items['item-1']!.timestamp, equals(tsReAdd));
    });

    test(
        'Ordinary CRDT merge convergence remains commutative, associative, and idempotent',
        () {
      const ts1 = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'n1');
      const ts2 = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'n2');
      const ts3 = HybridLogicalClock(physicalTime: 3000, logicalCounter: 0, nodeId: 'n3');

      final setA = const CrdtOrSet<String>.empty()
          .add('a', 'a', ts1)
          .add('b', 'b', ts2)
          .remove('b', ts3);
      final setB = const CrdtOrSet<String>.empty()
          .add('b', 'b', ts1)
          .add('c', 'c', ts2);
      final setC = const CrdtOrSet<String>.empty()
          .add('d', 'd', ts3)
          .remove('a', ts2);

      // Commutativity: A ⊔ B == B ⊔ A
      final ab = setA.merge(setB);
      final ba = setB.merge(setA);
      expect(ab.items, equals(ba.items));
      expect(ab.tombstones, equals(ba.tombstones));
      expect(ab.activeValues.toSet(), equals(ba.activeValues.toSet()));

      // Idempotence: A ⊔ A == A
      final aa = setA.merge(setA);
      expect(aa.items, equals(setA.items));
      expect(aa.tombstones, equals(setA.tombstones));

      // Associativity: (A ⊔ B) ⊔ C == A ⊔ (B ⊔ C)
      final abThenC = (setA.merge(setB)).merge(setC);
      final aThenBc = setA.merge(setB.merge(setC));
      expect(abThenC.items, equals(aThenBc.items));
      expect(abThenC.tombstones, equals(aThenBc.tombstones));
      expect(abThenC.activeValues.toSet(), equals(aThenBc.activeValues.toSet()));
    });

    test(
        'PartyPurse Reconciliation: Spending money to 0 does not resurrect remote currency',
        () {
      // Local spent all 100 GP
      final local = const PartyPurse.empty()
          .depositCoins(gp: 100, replicaId: ReplicaId('host'))
          .withdrawCoins(gp: 100, replicaId: ReplicaId('peer_local'));
      expect(local.gp, 0);

      // Remote still has the unspent 100 GP
      final remote = const PartyPurse.empty()
          .depositCoins(gp: 100, replicaId: ReplicaId('host'));
      expect(remote.gp, 100);

      // Merge local and remote
      final merged = service.reconcileProfile(
        local: CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
            .copyWith(partyPurse: local),
        remote: CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
            .copyWith(partyPurse: remote),
        inboundTimestampMs: 2000,
        localTimestampMs: 1000,
      );

      // The 100 GP spent by local MUST NOT be resurrected!
      expect(merged.partyPurse.gp, 0);
    });

    test(
        'PartyPurse Reconciliation: Concurrent deposits across peers converge via PN-counter',
        () {
      // Peer A deposits 100 GP
      final purseA = const PartyPurse.empty()
          .depositCoins(gp: 100, replicaId: ReplicaId('peerA'));

      // Peer B deposits 50 GP
      final purseB = const PartyPurse.empty()
          .depositCoins(gp: 50, replicaId: ReplicaId('peerB'));

      final merged = service.reconcileProfile(
        local: CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
            .copyWith(partyPurse: purseA),
        remote: CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
            .copyWith(partyPurse: purseB),
        inboundTimestampMs: 2000,
        localTimestampMs: 1000,
      );

      // Both deposits converge: 100 + 50 = 150 GP
      expect(merged.partyPurse.gp, 150);
    });

    test(
        'Zero-Loss Partition Convergence: Offline minion and encounter removal merges without entity resurrection',
        () {
      const tsInitial = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 0, nodeId: 'host');
      const tsLocalRemoval = HybridLogicalClock(
          physicalTime: 2000, logicalCounter: 0, nodeId: 'clientA');

      final minion1 = MinionInstance(
        id: 'minion-wolf-1',
        name: 'Dire Wolf Minion',
        size: EntitySize.large,
        currentHp: 37,
        maxHp: 37,
        tempHp: 0,
      );
      final minion2 = MinionInstance(
        id: 'minion-hawk-1',
        name: 'Blood Hawk Minion',
        size: EntitySize.tiny,
        currentHp: 7,
        maxHp: 7,
        tempHp: 0,
      );

      final encounterParticipant = EncounterParticipant(
        participantId: 'goblin-scout-1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin-1',
          displayName: 'Goblin Scout',
        ),
        currentHp: 12,
        maxHp: 12,
        defense: 15,
        initiativeScore: 18,
      );

      // Both host and client initially had minion1, minion2, and encounterParticipant
      final initialMinions = const CrdtOrSet<MinionInstance>.empty()
          .add(minion1.id, minion1, tsInitial)
          .add(minion2.id, minion2, tsInitial);

      final initialEncounter = const CrdtOrSet<EncounterParticipant>.empty()
          .add(encounterParticipant.participantId, encounterParticipant,
              tsInitial);

      // Client A enters network partition, dismisses/kills minion1 and defeats encounterParticipant (producing tombstones)
      final clientMinions = initialMinions.remove(minion1.id, tsLocalRemoval);
      final clientEncounter = initialEncounter.remove(
          encounterParticipant.participantId, tsLocalRemoval);

      final clientProfile = CampaignProfile.defaultProfile(
              id: 'camp-partition', nodeId: 'test_node')
          .copyWith(
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-101',
          title: 'Client Node',
          activeMinions: clientMinions,
          activeEncounter: clientEncounter,
        ),
      );

      // Remote host remained online, but only has original un-dismissed minions/encounter state
      final hostProfile = CampaignProfile.defaultProfile(
              id: 'camp-partition', nodeId: 'test_node')
          .copyWith(
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-101',
          title: 'Host Node',
          activeMinions: initialMinions,
          activeEncounter: initialEncounter,
        ),
      );

      // Reconcile client state with remote host state
      final reconciled = service.reconcileProfile(
        local: clientProfile,
        remote: hostProfile,
        inboundTimestampMs: 2500,
        localTimestampMs: 1500,
      );

      // Assert that minion1 was NOT resurrected by remote host's older state
      expect(reconciled.roomState.activeMinions.items.containsKey(minion1.id),
          isFalse);
      expect(
          reconciled.roomState.activeMinions.tombstones.containsKey(minion1.id),
          isTrue);
      expect(reconciled.roomState.activeMinions.activeValues.map((m) => m.id),
          contains('minion-hawk-1'));
      expect(reconciled.roomState.activeMinions.activeValues.map((m) => m.id),
          isNot(contains('minion-wolf-1')));

      // Assert that encounterParticipant was NOT resurrected
      expect(
          reconciled.roomState.activeEncounter.items
              .containsKey(encounterParticipant.participantId),
          isFalse);
      expect(
          reconciled.roomState.activeEncounter.tombstones
              .containsKey(encounterParticipant.participantId),
          isTrue);
      expect(reconciled.roomState.activeEncounter.activeValues, isEmpty);
    });

    test(
        'Notes Convergence: Concurrent edits resolve via deterministic LWW with dropped delta logged to changeLog',
        () {
      const tsA = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 1, nodeId: 'peerA');
      const tsB = HybridLogicalClock(
          physicalTime: 1000, logicalCounter: 2, nodeId: 'peerB');

      final profileA =
          CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
              .copyWith(
        notesRegister: const CrdtLwwRegister<String>(
            value: 'Local notes: Discovered hidden cave.', timestamp: tsA),
      );
      final profileB =
          CampaignProfile.defaultProfile(id: 'camp1', nodeId: 'test_node')
              .copyWith(
        notesRegister: const CrdtLwwRegister<String>(
            value: 'Remote notes: Trapped the chest.', timestamp: tsB),
      );

      final merged = service.reconcileProfile(
        local: profileA,
        remote: profileB,
        inboundTimestampMs: 1500,
        localTimestampMs: 1200,
      );

      // Higher HLC timestamp wins deterministically without string concatenation bloat
      expect(merged.notesMarkdown, equals('Remote notes: Trapped the chest.'));
      // Dropped delta is recorded in changeLog for audit and recovery
      expect(
        merged.changeLog.any((e) =>
            e.type == 'notesConflictOverwrite' &&
            e.details == 'Local notes: Discovered hidden cave.'),
        isTrue,
      );
    });
  });
}
