import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_lww_register.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_or_set.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
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
    final service = RoomStateReconciliationService(
      networkTimeProvider: () => DateTime.now().toUtc().millisecondsSinceEpoch,
    );

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

      final targetSet = CrdtOrSet<String>(
        tombstones: {
          'item-1': const HybridLogicalClock(physicalTime: 50000, logicalCounter: 0, nodeId: 'nodeA'),
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

      final setWithTombstones = CrdtOrSet<String>(
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

      final setWithTombstones = CrdtOrSet<String>(
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
      final setWithTombstones = CrdtOrSet<String>(
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

    test('Zero-Loss Partition Convergence: Offline minion and encounter removal merges without entity resurrection', () {
      const tsInitial = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'host');
      const tsLocalRemoval = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'clientA');

      final minion1 = AnimatedObjectInstance(
        id: 'minion-wolf-1',
        name: 'Dire Wolf Minion',
        size: ObjectSize.large,
        currentHp: 37,
        maxHp: 37,
        tempHp: 0,
      );
      final minion2 = AnimatedObjectInstance(
        id: 'minion-hawk-1',
        name: 'Blood Hawk Minion',
        size: ObjectSize.tiny,
        currentHp: 7,
        maxHp: 7,
        tempHp: 0,
      );

      const encounterParticipant = EncounterParticipant(
        participantId: 'goblin-scout-1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin-1',
          displayName: 'Goblin Scout',
        ),
        currentHp: 12,
        maxHp: 12,
        armorClass: 15,
        initiativeScore: 18,
      );

      // Both host and client initially had minion1, minion2, and encounterParticipant
      final initialMinions = const CrdtOrSet<AnimatedObjectInstance>.empty()
          .add(minion1.id, minion1, tsInitial)
          .add(minion2.id, minion2, tsInitial);

      final initialEncounter = const CrdtOrSet<EncounterParticipant>.empty()
          .add(encounterParticipant.participantId, encounterParticipant, tsInitial);

      // Client A enters network partition, dismisses/kills minion1 and defeats encounterParticipant (producing tombstones)
      final clientMinions = initialMinions.remove(minion1.id, tsLocalRemoval);
      final clientEncounter = initialEncounter.remove(encounterParticipant.participantId, tsLocalRemoval);

      final clientProfile = CampaignProfile.defaultProfile(id: 'camp-partition').copyWith(
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'CR-101',
          title: 'Client Node',
          activeMinions: clientMinions,
          activeEncounter: clientEncounter,
        ),
      );

      // Remote host remained online, but only has original un-dismissed minions/encounter state
      final hostProfile = CampaignProfile.defaultProfile(id: 'camp-partition').copyWith(
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
      expect(reconciled.roomState.activeMinions.items.containsKey(minion1.id), isFalse);
      expect(reconciled.roomState.activeMinions.tombstones.containsKey(minion1.id), isTrue);
      expect(reconciled.roomState.activeMinions.activeValues.map((m) => m.id), contains('minion-hawk-1'));
      expect(reconciled.roomState.activeMinions.activeValues.map((m) => m.id), isNot(contains('minion-wolf-1')));

      // Assert that encounterParticipant was NOT resurrected
      expect(reconciled.roomState.activeEncounter.items.containsKey(encounterParticipant.participantId), isFalse);
      expect(reconciled.roomState.activeEncounter.tombstones.containsKey(encounterParticipant.participantId), isTrue);
      expect(reconciled.roomState.activeEncounter.activeValues, isEmpty);
    });

    test('Notes Convergence: Concurrent edits resolve via deterministic LWW with dropped delta logged to changeLog', () {
      const tsA = HybridLogicalClock(physicalTime: 1000, logicalCounter: 1, nodeId: 'peerA');
      const tsB = HybridLogicalClock(physicalTime: 1000, logicalCounter: 2, nodeId: 'peerB');

      final profileA = CampaignProfile.defaultProfile(id: 'camp1').copyWith(
        notesRegister: const CrdtLwwRegister<String>(value: 'Local notes: Discovered hidden cave.', timestamp: tsA),
      );
      final profileB = CampaignProfile.defaultProfile(id: 'camp1').copyWith(
        notesRegister: const CrdtLwwRegister<String>(value: 'Remote notes: Trapped the chest.', timestamp: tsB),
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
