import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';

void main() {
  group('Pass 4.0: Aggregate Replicated-State Convergence Tests', () {
    late RoomStateReconciliationService reconciliationService;

    setUp(() {
      reconciliationService = RoomStateReconciliationService(
        networkTimeProvider: () => 1700000000000,
      );
    });

    CampaignProfile createBaseProfile() {
      final purse = const PartyPurse.empty().depositCoins(
        gp: 100,
        replicaId: ReplicaId('genesis'),
      );
      return CampaignProfile(
        id: 'camp-convergence-test',
        nodeId: 'genesis',
        name: 'The Sunless Citadel',
        edition: RulesetEdition.v2024,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room-1',
          roomCode: 'SC-100',
          title: 'Citadel Core',
        ),
        partyCharacterIds: const ['char-fighter', 'char-wizard'],
        pinnedRuleIds: const {'cover', 'resting'},
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Initial briefing in Oakhaven.',
          timestamp: HybridLogicalClock(
            physicalTime: 1000,
            logicalCounter: 0,
            nodeId: 'genesis',
          ),
        ),
        partyPurse: purse,
      );
    }

    test('Aggregate Laws: Idempotence, Commutativity, Associativity with forked histories', () {
      final base = createBaseProfile();

      // Replica A: updates notes and adds character to party
      final repAClock = StatefulHlcClock(replicaId: ReplicaId('replica-a'), timeProvider: () => 2000);
      final tsA1 = repAClock.nextTimestamp();
      final replicaA = base.copyWith(
        notesRegister: base.notesRegister.set('A updated notes with map clues.', tsA1),
        partyCharacterIds: [...base.partyCharacterIds, 'char-rogue'],
      );

      // Replica B: deposits GP and adds pinned rule
      final repBClock = StatefulHlcClock(replicaId: ReplicaId('replica-b'), timeProvider: () => 2100);
      final tsB1 = repBClock.nextTimestamp();
      final replicaB = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(gp: 50, replicaId: ReplicaId('replica-b')),
        pinnedRuleIds: {...base.pinnedRuleIds, 'grapple_shove'},
        notesRegister: base.notesRegister.set('B noted a secret door.', tsB1),
      );

      // Replica C: spends GP and removes a pinned rule
      final repCClock = StatefulHlcClock(replicaId: ReplicaId('replica-c'), timeProvider: () => 2200);
      final tsC1 = repCClock.nextTimestamp();
      final replicaC = base.copyWith(
        partyPurse: base.partyPurse.withdrawCoins(gp: 25, replicaId: ReplicaId('replica-c')),
        pinnedRuleIds: base.pinnedRuleIds.where((r) => r != 'cover').toSet(),
        notesRegister: base.notesRegister.set('C noticed goblin tracks.', tsC1),
      );

      // IDEMPOTENCE: join(A, A) == A
      expect(CampaignProfile.join(replicaA, replicaA), equals(replicaA));
      expect(CampaignProfile.join(replicaB, replicaB), equals(replicaB));

      // COMMUTATIVITY: join(A, B) == join(B, A)
      final ab = CampaignProfile.join(replicaA, replicaB);
      final ba = CampaignProfile.join(replicaB, replicaA);
      expect(ab, equals(ba));

      // ASSOCIATIVITY: join(join(A, B), C) == join(A, join(B, C))
      final abC = CampaignProfile.join(ab, replicaC);
      final bc = CampaignProfile.join(replicaB, replicaC);
      final aBc = CampaignProfile.join(replicaA, bc);
      expect(abC, equals(aBc));
    });

    test('Three-Replica Reconnection: Converges to identical state under all gossip permutations', () {
      final base = createBaseProfile();

      // Replica A offline: edits notes and deposits SP
      final clockA = StatefulHlcClock(replicaId: ReplicaId('replica-a'), timeProvider: () => 3000);
      final tsA = clockA.nextTimestamp();
      final repA = base.copyWith(
        notesRegister: base.notesRegister.set('Replica A offline expedition notes.', tsA),
        partyPurse: base.partyPurse.depositCoins(sp: 40, replicaId: ReplicaId('replica-a')),
      );

      // Replica B offline: deposits GP and adds minion
      final clockB = StatefulHlcClock(replicaId: ReplicaId('replica-b'), timeProvider: () => 3100);
      final tsB = clockB.nextTimestamp();
      final minion1 = MinionInstance(
        id: 'minion-wolf-1',
        name: 'Wolf Companion',
        size: EntitySize.medium,
        currentHp: 11,
        maxHp: 11,
      );
      final repB = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(gp: 75, replicaId: ReplicaId('replica-b')),
        roomState: base.roomState.copyWith(
          activeMinions: base.roomState.activeMinions.add(minion1.id, minion1, tsB),
        ),
      );

      // Replica C offline: spends GP and adds encounter participant
      final clockC = StatefulHlcClock(replicaId: ReplicaId('replica-c'), timeProvider: () => 3200);
      final tsC = clockC.nextTimestamp();
      final encounterOrc = EncounterParticipant(
        participantId: 'orc-scout-1',
        entityLink: RoomEntityLink(
          entityId: 'orc-1',
          displayName: 'Orc Scout',
        ),
        initiativeScore: 14,
      );
      final repC = base.copyWith(
        partyPurse: base.partyPurse.withdrawCoins(gp: 30, replicaId: ReplicaId('replica-c')),
        roomState: base.roomState.copyWith(
          activeEncounter: base.roomState.activeEncounter.add(
            encounterOrc.participantId,
            encounterOrc,
            tsC,
          ),
        ),
      );

      // Test all pairwise and transitive gossip permutations:
      // Permutation 1: (A * B) * C
      final perm1 = CampaignProfile.join(CampaignProfile.join(repA, repB), repC);

      // Permutation 2: (B * C) * A
      final perm2 = CampaignProfile.join(CampaignProfile.join(repB, repC), repA);

      // Permutation 3: (C * A) * B
      final perm3 = CampaignProfile.join(CampaignProfile.join(repC, repA), repB);

      // Permutation 4: A * (B * C)
      final perm4 = CampaignProfile.join(repA, CampaignProfile.join(repB, repC));

      // Permutation 5: B * (C * A)
      final perm5 = CampaignProfile.join(repB, CampaignProfile.join(repC, repA));

      // Permutation 6: C * (A * B)
      final perm6 = CampaignProfile.join(repC, CampaignProfile.join(repA, repB));

      expect(perm1, equals(perm2));
      expect(perm2, equals(perm3));
      expect(perm3, equals(perm4));
      expect(perm4, equals(perm5));
      expect(perm5, equals(perm6));

      // Assert converged values
      expect(perm1.notesMarkdown, equals('Replica A offline expedition notes.'));
      // Purse: base 100 GP + 75 GP (B) - 30 GP (C) = 145 GP; 40 SP (A)
      expect(perm1.partyPurse.gp, equals(145));
      expect(perm1.partyPurse.sp, equals(40));
      expect(perm1.roomState.activeMinions.activeValues.map((m) => m.id), contains('minion-wolf-1'));
      expect(perm1.roomState.activeEncounter.activeValues.map((e) => e.participantId), contains('orc-scout-1'));
    });

    test('Party Purse Convergence at Aggregate Level: Signed PN-counters survive join in all orders', () {
      final base = createBaseProfile();

      // Replica A deposits 50 GP
      final repA = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(gp: 50, replicaId: ReplicaId('node-A')),
      );

      // Replica B spends 20 GP
      final repB = base.copyWith(
        partyPurse: base.partyPurse.withdrawCoins(gp: 20, replicaId: ReplicaId('node-B')),
      );

      // Replica C changes SP: deposits 35 SP
      final repC = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(sp: 35, replicaId: ReplicaId('node-C')),
      );

      final order1 = CampaignProfile.join(CampaignProfile.join(repA, repB), repC);
      final order2 = CampaignProfile.join(CampaignProfile.join(repC, repB), repA);

      expect(order1.partyPurse, equals(order2.partyPurse));
      expect(order1.partyPurse.gp, equals(130));
      expect(order1.partyPurse.sp, equals(35));
    });

    test('Notes + Other Field Independence: Concurrent edits to different fields all survive', () {
      final base = createBaseProfile();

      // Replica A edits notes
      final clockA = StatefulHlcClock(replicaId: ReplicaId('node-a'), timeProvider: () => 4000);
      final repA = base.copyWith(
        notesRegister: base.notesRegister.set('Secret passage behind throne.', clockA.nextTimestamp()),
      );

      // Replica B changes purse
      final repB = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(gp: 200, replicaId: ReplicaId('node-b')),
      );

      // Replica C updates minion
      final clockC = StatefulHlcClock(replicaId: ReplicaId('node-c'), timeProvider: () => 4100);
      final minion = MinionInstance(
        id: 'minion-scout-1',
        name: 'Scout Crow',
        size: EntitySize.tiny,
        currentHp: 1,
        maxHp: 1,
      );
      final repC = base.copyWith(
        roomState: base.roomState.copyWith(
          activeMinions: base.roomState.activeMinions.add(minion.id, minion, clockC.nextTimestamp()),
        ),
      );

      final converged = CampaignProfile.join(CampaignProfile.join(repA, repB), repC);

      expect(converged.notesMarkdown, equals('Secret passage behind throne.'));
      expect(converged.partyPurse.gp, equals(300));
      expect(converged.roomState.activeMinions.activeValues.map((m) => m.id), contains('minion-scout-1'));
    });

    test('Same Field with Explicit Causal Semantics: Later HLC timestamp wins symmetrically', () {
      final base = createBaseProfile();

      const earlyTs = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'peer-1');
      const lateTs = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'peer-2');

      final profileEarly = base.copyWith(
        notesRegister: const CrdtLwwRegister<String>(value: 'Early text', timestamp: earlyTs),
      );
      final profileLate = base.copyWith(
        notesRegister: const CrdtLwwRegister<String>(value: 'Late authoritative text', timestamp: lateTs),
      );

      final join1 = CampaignProfile.join(profileEarly, profileLate);
      final join2 = CampaignProfile.join(profileLate, profileEarly);

      expect(join1.notesMarkdown, equals('Late authoritative text'));
      expect(join2.notesMarkdown, equals('Late authoritative text'));
      expect(join1, equals(join2));
    });

    test('Narrow Per-Subresource Fault Isolation: Single subresource collision isolates without destroying healthy progress', () {
      final base = createBaseProfile();

      // Create an exact-HLC collision in activeMinions (invalid replicated state)
      const collisionTs = HybridLogicalClock(physicalTime: 5000, logicalCounter: 0, nodeId: 'collision-node');
      final minionLocal = MinionInstance(id: 'm1', name: 'Local Minion', size: EntitySize.small);
      final minionRemote = MinionInstance(id: 'm1', name: 'Divergent Remote Minion', size: EntitySize.huge);

      // Local profile has valid notes update and minionLocal
      final clockLocal = StatefulHlcClock(replicaId: ReplicaId('local-node'), timeProvider: () => 5100);
      final localProfile = base.copyWith(
        notesRegister: base.notesRegister.set('Local valid notes update.', clockLocal.nextTimestamp()),
        partyPurse: base.partyPurse.depositCoins(gp: 50, replicaId: ReplicaId('local-node')),
        roomState: base.roomState.copyWith(
          activeMinions: base.roomState.activeMinions.add(minionLocal.id, minionLocal, collisionTs),
        ),
      );

      // Remote profile has valid purse update and minionRemote with exact collision HLC
      final remoteProfile = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(sp: 80, replicaId: ReplicaId('remote-node')),
        roomState: base.roomState.copyWith(
          activeMinions: base.roomState.activeMinions.add(minionRemote.id, minionRemote, collisionTs),
        ),
      );

      // Assert that pure canonical join fails loudly due to exact-HLC divergent payload
      expect(
        () => CampaignProfile.join(localProfile, remoteProfile),
        throwsA(isA<StateError>()),
      );

      // Reconcile safely via application-level fault isolation
      final result = reconciliationService.reconcileProfileSafely(
        local: localProfile,
        remote: remoteProfile,
      );

      // Assert fault isolation:
      // 1. Fault was captured for activeMinions
      expect(result.hasFaults, isTrue);
      expect(result.fieldFaults.any((f) => f.field == 'roomState.activeMinions'), isTrue);

      // 2. Offending subresource remains unchanged/quarantined (local value preserved)
      expect(result.profile.roomState.activeMinions.activeValues.first.name, equals('Local Minion'));

      // 3. Unrelated healthy sub-resources (notes, partyPurse) merged cleanly!
      expect(result.profile.notesMarkdown, equals('Local valid notes update.'));
      expect(result.profile.partyPurse.gp, equals(150));
      expect(result.profile.partyPurse.sp, equals(80));
    });

    test('Input Immutability: Join does not mutate input profile instances or nested structures', () {
      final base = createBaseProfile();

      final repA = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(gp: 25, replicaId: ReplicaId('node-a')),
        partyCharacterIds: [...base.partyCharacterIds, 'char-paladin'],
      );
      final repB = base.copyWith(
        partyPurse: base.partyPurse.depositCoins(sp: 50, replicaId: ReplicaId('node-b')),
        pinnedRuleIds: {...base.pinnedRuleIds, 'underwater_combat'},
      );

      final serializedABefore = jsonEncode(CampaignProfileDto.fromDomain(repA).toMap());
      final serializedBBefore = jsonEncode(CampaignProfileDto.fromDomain(repB).toMap());

      final joined = CampaignProfile.join(repA, repB);

      final serializedAAfter = jsonEncode(CampaignProfileDto.fromDomain(repA).toMap());
      final serializedBAfter = jsonEncode(CampaignProfileDto.fromDomain(repB).toMap());

      expect(serializedAAfter, equals(serializedABefore));
      expect(serializedBAfter, equals(serializedBBefore));
      expect(joined.partyCharacterIds, contains('char-paladin'));
      expect(joined.pinnedRuleIds, contains('underwater_combat'));
    });

    test('Serialization Round-Trip: Preserves join semantics and equality', () {
      final base = createBaseProfile();

      final repA = base.copyWith(
        notesRegister: base.notesRegister.set('Notes from A', const HybridLogicalClock(physicalTime: 1200, logicalCounter: 0, nodeId: 'a')),
        partyPurse: base.partyPurse.depositCoins(gp: 30, replicaId: ReplicaId('a')),
      );
      final repB = base.copyWith(
        notesRegister: base.notesRegister.set('Notes from B', const HybridLogicalClock(physicalTime: 1300, logicalCounter: 0, nodeId: 'b')),
        partyPurse: base.partyPurse.withdrawCoins(gp: 10, replicaId: ReplicaId('b')),
      );

      final directJoin = CampaignProfile.join(repA, repB);

      final deserializedA = CampaignProfileDto.fromMap(CampaignProfileDto.fromDomain(repA).toMap()).toDomain();
      final deserializedB = CampaignProfileDto.fromMap(CampaignProfileDto.fromDomain(repB).toMap()).toDomain();

      final deserializedJoin = CampaignProfile.join(deserializedA, deserializedB);
      expect(directJoin, equals(deserializedJoin));

      final roundTripJoined = CampaignProfileDto.fromMap(CampaignProfileDto.fromDomain(directJoin).toMap()).toDomain();
      expect(roundTripJoined, equals(directJoin));
    });

    test('Symmetric Fail-Loud on Invalid States: Direction independence of errors', () {
      final base = createBaseProfile();

      // 1. Immutable ID mismatch
      final idMismatchA = base;
      final idMismatchB = base.copyWith(id: 'camp-different-id');
      expect(() => CampaignProfile.join(idMismatchA, idMismatchB), throwsA(isA<StateError>()));
      expect(() => CampaignProfile.join(idMismatchB, idMismatchA), throwsA(isA<StateError>()));

      // 2. Incompatible edition identity
      final editionA = base.copyWith(edition: const RulesetIdentifier('5e_2014'));
      final editionB = base.copyWith(edition: const RulesetIdentifier('5e_2024'));
      expect(() => CampaignProfile.join(editionA, editionB), throwsA(isA<StateError>()));
      expect(() => CampaignProfile.join(editionB, editionA), throwsA(isA<StateError>()));

      // 3. Divergent unversioned campaign name
      final nameA = base.copyWith(name: 'Adventure One');
      final nameB = base.copyWith(name: 'Adventure Two');
      expect(() => CampaignProfile.join(nameA, nameB), throwsA(isA<StateError>()));
      expect(() => CampaignProfile.join(nameB, nameA), throwsA(isA<StateError>()));
    });

    test('Randomized Aggregate Laws: 100 iterations of seeded concurrent forks converge idempotently, commutatively, and associatively', () {
      const seed = 0xCAFE40;
      final rand = math.Random(seed);
      final base = createBaseProfile();

      for (var iteration = 0; iteration < 100; iteration++) {
        var repA = base;
        var repB = base;
        var repC = base;

        // Mutate A
        final timeA = 1000 + rand.nextInt(500);
        final clockA = StatefulHlcClock(replicaId: ReplicaId('node-a'), timeProvider: () => timeA);
        final gpDepositA = rand.nextInt(50) + 1;
        final tsA2 = clockA.nextTimestamp();
        repA = repA.copyWith(
          partyPurse: repA.partyPurse.depositCoins(gp: gpDepositA, replicaId: ReplicaId('node-a')),
          notesRegister: repA.notesRegister.set('Note from A iter $iteration', clockA.nextTimestamp()),
          partyRoster: repA.partyRoster.add('hero_a_$iteration', 'hero_a_$iteration', tsA2),
        );

        // Mutate B
        final timeB = 1600 + rand.nextInt(500);
        final clockB = StatefulHlcClock(replicaId: ReplicaId('node-b'), timeProvider: () => timeB);
        final spDepositB = rand.nextInt(100) + 1;
        final tsB2 = clockB.nextTimestamp();
        repB = repB.copyWith(
          partyPurse: repB.partyPurse.depositCoins(sp: spDepositB, replicaId: ReplicaId('node-b')),
          notesRegister: repB.notesRegister.set('Note from B iter $iteration', clockB.nextTimestamp()),
          pinnedRuleIds: {...repB.pinnedRuleIds, 'rule_b_$iteration'},
          partyRoster: repB.partyRoster.remove('char-fighter', tsB2),
        );

        // Mutate C
        final timeC = 2200 + rand.nextInt(500);
        final clockC = StatefulHlcClock(replicaId: ReplicaId('node-c'), timeProvider: () => timeC);
        final gpSpendC = rand.nextInt(20);
        final tsC2 = clockC.nextTimestamp();
        repC = repC.copyWith(
          partyPurse: repC.partyPurse.withdrawCoins(gp: gpSpendC, replicaId: ReplicaId('node-c')),
          notesRegister: repC.notesRegister.set('Note from C iter $iteration', clockC.nextTimestamp()),
          pinnedRuleIds: repC.pinnedRuleIds.where((r) => r != 'cover').toSet(),
          partyRoster: repC.partyRoster.add('char-fighter', 'char-fighter', tsC2),
        );

        // IDEMPOTENCE
        final idA = CampaignProfile.join(repA, repA);
        expect(idA, equals(repA), reason: 'Idempotence failed at iter $iteration (seed: $seed)');

        // COMMUTATIVITY
        final ab = CampaignProfile.join(repA, repB);
        final ba = CampaignProfile.join(repB, repA);
        expect(ab, equals(ba), reason: 'Commutativity failed at iter $iteration (seed: $seed)');

        // ASSOCIATIVITY
        final abC = CampaignProfile.join(ab, repC);
        final aBc = CampaignProfile.join(repA, CampaignProfile.join(repB, repC));
        expect(abC, equals(aBc), reason: 'Associativity failed at iter $iteration (seed: $seed)');
      }
    });
  });
}
