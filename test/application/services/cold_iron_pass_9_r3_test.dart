import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/models/loot_models.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';

class _NoOpSubclassReconciliationService extends RoomStateReconciliationService {}

CampaignProfile _buildTestProfile({
  required String id,
  String roomCode = 'ROOM1',
  String roomId = 'room_ROOM1',
  required StatefulHlcClock clock,
  List<EntityInstance> entityInstances = const [],
  List<LootContainer> containers = const [],
  String notes = '',
  int gp = 0,
}) {
  final nowTs = clock.nextTimestamp();
  return CampaignProfile.raw(
    id: id,
    nameRegister: CrdtLwwRegister<String>(value: 'Campaign $id', timestamp: nowTs),
    edition: RulesetEdition.v2024,
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    roomState: RoomNodeState(
      roomId: roomId,
      roomCode: roomCode,
      title: 'Staging',
      titleTimestamp: nowTs,
      description: '',
      descriptionTimestamp: nowTs,
      entityInstances: entityInstances,
      containers: containers,
    ),
    partyPurse: PartyPurse(gp: gp),
    memberPurses: const {},
    partyRoster: const CrdtOrSet<String>.empty(),
    pinnedRules: const CrdtOrSet<String>.empty(),
    notesRegister: CrdtLwwRegister<String>(value: notes, timestamp: nowTs),
    changeLog: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatefulHlcClock clockA;
  late StatefulHlcClock clockB;
  late RoomStateReconciliationService service;

  setUp(() {
    clockA = StatefulHlcClock(replicaId: ReplicaId('node_A'));
    clockB = StatefulHlcClock(replicaId: ReplicaId('node_B'));
    service = RoomStateReconciliationService();
  });

  group('Part B: R3 - Granular Merge Fault Isolation and Subclass Recursion Fix', () {
    test('Entity instances: tok / new_on_b example in both directions', () {
      final tokA = EntityInstance(
        instanceId: 'tok',
        displayName: 'Token A',
        displayNameTimestamp: clockA.nextTimestamp(),
        isVisible: true,
      );
      final tokB = EntityInstance(
        instanceId: 'tok',
        displayName: 'Token B',
        displayNameTimestamp: clockB.nextTimestamp(),
        isVisible: false,
      );
      final newOnB = EntityInstance(
        instanceId: 'new_on_b',
        displayName: 'New On B',
        displayNameTimestamp: clockB.nextTimestamp(),
        isVisible: true,
      );

      final profileA = _buildTestProfile(
        id: 'camp_tok',
        clock: clockA,
        entityInstances: [tokA],
      );
      final profileB = _buildTestProfile(
        id: 'camp_tok',
        clock: clockB,
        entityInstances: [tokB, newOnB],
      );

      // Reconcile on A: local = A, remote = B
      final resA = service.reconcileProfileSafely(local: profileA, remote: profileB);
      expect(resA.fieldFaults.map((f) => f.field), equals(['roomState.entityInstances[tok]']));
      final instancesOnA = resA.profile.roomState.entityInstances;
      expect(instancesOnA, hasLength(2));
      final instMapA = {for (final i in instancesOnA) i.instanceId: i};
      expect(instMapA.containsKey('tok'), isTrue);
      expect(instMapA.containsKey('new_on_b'), isTrue);
      expect(instMapA['tok']!.isVisible, isTrue, reason: 'A keeps local value on fault');
      expect(instMapA['new_on_b']!.isVisible, isTrue);

      // Reconcile on B: local = B, remote = A
      final resB = service.reconcileProfileSafely(local: profileB, remote: profileA);
      expect(resB.fieldFaults.map((f) => f.field), equals(['roomState.entityInstances[tok]']));
      final instancesOnB = resB.profile.roomState.entityInstances;
      expect(instancesOnB, hasLength(2));
      final instMapB = {for (final i in instancesOnB) i.instanceId: i};
      expect(instMapB.containsKey('tok'), isTrue);
      expect(instMapB.containsKey('new_on_b'), isTrue);
      expect(instMapB['tok']!.isVisible, isFalse, reason: 'B keeps local value on fault');
      expect(instMapB['new_on_b']!.isVisible, isTrue);
    });

    test('Containers: chest1 / new_on_b example in both directions', () {
      final chestA = LootContainer(
        containerId: 'chest1',
        name: 'Chest A',
        nameTimestamp: clockA.nextTimestamp(),
        isLocked: true,
      );
      final chestB = LootContainer(
        containerId: 'chest1',
        name: 'Chest B',
        nameTimestamp: clockB.nextTimestamp(),
        isLocked: false,
      );
      final newOnB = LootContainer(
        containerId: 'chest_new_b',
        name: 'New Container',
        nameTimestamp: clockB.nextTimestamp(),
        isLocked: false,
      );

      final profileA = _buildTestProfile(
        id: 'camp_chest',
        clock: clockA,
        containers: [chestA],
      );
      final profileB = _buildTestProfile(
        id: 'camp_chest',
        clock: clockB,
        containers: [chestB, newOnB],
      );

      // Direction 1: local = A, remote = B
      final resA = service.reconcileProfileSafely(local: profileA, remote: profileB);
      expect(resA.fieldFaults.map((f) => f.field), equals(['roomState.containers[chest1]']));
      final containersA = resA.profile.roomState.containers;
      expect(containersA, hasLength(2));
      final contMapA = {for (final c in containersA) c.containerId: c};
      expect(contMapA['chest1']!.isLocked, isTrue, reason: 'A keeps local value on fault');
      expect(contMapA['chest_new_b']!.name, equals('New Container'));

      // Direction 2: local = B, remote = A
      final resB = service.reconcileProfileSafely(local: profileB, remote: profileA);
      expect(resB.fieldFaults.map((f) => f.field), equals(['roomState.containers[chest1]']));
      final containersB = resB.profile.roomState.containers;
      expect(containersB, hasLength(2));
      final contMapB = {for (final c in containersB) c.containerId: c};
      expect(contMapB['chest1']!.isLocked, isFalse, reason: 'B keeps local value on fault');
      expect(contMapB['chest_new_b']!.name, equals('New Container'));
    });

    test('Subclass recursion: a subclass overriding nothing produces identical results without stack overflow', () {
      final subclassService = _NoOpSubclassReconciliationService();
      final pA = _buildTestProfile(id: 'camp_sub', notes: 'Notes A', clock: clockA);
      final pB = _buildTestProfile(id: 'camp_sub', notes: 'Notes B', clock: clockB);

      final baseResult = service.reconcileProfileSafely(local: pA, remote: pB);
      final subResult = subclassService.reconcileProfileSafely(local: pA, remote: pB);

      expect(subResult.fieldFaults.length, equals(baseResult.fieldFaults.length));
      expect(subResult.profile, equals(baseResult.profile));

      final baseProfile = service.reconcileProfile(local: pA, remote: pB);
      final subProfile = subclassService.reconcileProfile(local: pA, remote: pB);
      expect(subProfile, equals(baseProfile));
    });

    test('Fault-path law across 350 seeded random pairs', () {
      for (int seed = 0; seed < 350; seed++) {
        try {
          final rand = Random(seed);
          final clock1 = StatefulHlcClock(replicaId: ReplicaId('node_seed_${seed}_1'));
          final clock2 = StatefulHlcClock(replicaId: ReplicaId('node_seed_${seed}_2'));

          final category = seed % 3;

          String roomCodeA = 'ROOM-$seed';
          String roomCodeB = 'ROOM-$seed';
          String roomIdA = 'room_ROOM-$seed';
          String roomIdB = 'room_ROOM-$seed';

          final instancesA = <EntityInstance>[];
          final instancesB = <EntityInstance>[];
          final containersA = <LootContainer>[];
          final containersB = <LootContainer>[];

          if (category == 0) {
            // Category 0: No conflict
            // Some shared non-conflicting instances
            if (rand.nextBool()) {
              final ts1 = clock1.nextTimestamp();
              final ts2 = clock2.nextTimestamp();
              instancesA.add(EntityInstance(
                instanceId: 'inst_shared',
                displayName: 'Shared 1',
                displayNameTimestamp: ts1,
                isVisible: true,
              ));
              instancesB.add(EntityInstance(
                instanceId: 'inst_shared',
                displayName: 'Shared 2',
                displayNameTimestamp: ts2,
                isVisible: true,
              ));
            }
            // Some items on one side only
            if (rand.nextBool()) {
              instancesA.add(EntityInstance(
                instanceId: 'inst_only_a',
                displayName: 'Only A',
                displayNameTimestamp: clock1.nextTimestamp(),
                isVisible: rand.nextBool(),
              ));
            }
            if (rand.nextBool()) {
              instancesB.add(EntityInstance(
                instanceId: 'inst_only_b',
                displayName: 'Only B',
                displayNameTimestamp: clock2.nextTimestamp(),
                isVisible: rand.nextBool(),
              ));
            }
            if (rand.nextBool()) {
              containersA.add(LootContainer(
                containerId: 'cont_only_a',
                name: 'Container A',
                nameTimestamp: clock1.nextTimestamp(),
                isLocked: rand.nextBool(),
              ));
            }
            if (rand.nextBool()) {
              containersB.add(LootContainer(
                containerId: 'cont_only_b',
                name: 'Container B',
                nameTimestamp: clock2.nextTimestamp(),
                isLocked: rand.nextBool(),
              ));
            }
          } else if (category == 1) {
            // Category 1: One conflicting instance or container
            if (rand.nextBool()) {
              // Conflicting instance isVisible
              instancesA.add(EntityInstance(
                instanceId: 'inst_conflict',
                displayName: 'Conflict Inst',
                displayNameTimestamp: clock1.nextTimestamp(),
                isVisible: true,
              ));
              instancesB.add(EntityInstance(
                instanceId: 'inst_conflict',
                displayName: 'Conflict Inst',
                displayNameTimestamp: clock2.nextTimestamp(),
                isVisible: false,
              ));
            } else {
              // Conflicting container isLocked
              containersA.add(LootContainer(
                containerId: 'cont_conflict',
                name: 'Conflict Cont',
                nameTimestamp: clock1.nextTimestamp(),
                isLocked: true,
              ));
              containersB.add(LootContainer(
                containerId: 'cont_conflict',
                name: 'Conflict Cont',
                nameTimestamp: clock2.nextTimestamp(),
                isLocked: false,
              ));
            }
            // Also include some non-conflicting items
            if (rand.nextBool()) {
              instancesB.add(EntityInstance(
                instanceId: 'extra_b',
                displayName: 'Extra B',
                displayNameTimestamp: clock2.nextTimestamp(),
                isVisible: true,
              ));
            }
          } else {
            // Category 2: Conflicting immutable field
            final subcase = rand.nextInt(4);
            switch (subcase) {
              case 0:
                roomCodeA = 'ROOM-A-$seed';
                roomCodeB = 'ROOM-B-$seed';
                break;
              case 1:
                roomIdA = 'room_alpha_$seed';
                roomIdB = 'room_beta_$seed';
                break;
              case 2:
                instancesA.add(EntityInstance(
                  instanceId: 'inst_diff_vis',
                  displayName: 'Token',
                  displayNameTimestamp: clock1.nextTimestamp(),
                  isVisible: true,
                ));
                instancesB.add(EntityInstance(
                  instanceId: 'inst_diff_vis',
                  displayName: 'Token',
                  displayNameTimestamp: clock2.nextTimestamp(),
                  isVisible: false,
                ));
                break;
              case 3:
                containersA.add(LootContainer(
                  containerId: 'cont_diff_lock',
                  name: 'Box',
                  nameTimestamp: clock1.nextTimestamp(),
                  isLocked: true,
                ));
                containersB.add(LootContainer(
                  containerId: 'cont_diff_lock',
                  name: 'Box',
                  nameTimestamp: clock2.nextTimestamp(),
                  isLocked: false,
                ));
                break;
            }
          }

          final profA = _buildTestProfile(
            id: 'camp_law',
            roomCode: roomCodeA,
            roomId: roomIdA,
            clock: clock1,
            entityInstances: instancesA,
            containers: containersA,
            notes: 'Notes A $seed',
            gp: 10 + (seed % 5),
          );
          final profB = _buildTestProfile(
            id: 'camp_law',
            roomCode: roomCodeB,
            roomId: roomIdB,
            clock: clock2,
            entityInstances: instancesB,
            containers: containersB,
            notes: 'Notes B $seed',
            gp: 12 + (seed % 3),
          );

          final r1 = service.reconcileProfileSafely(local: profA, remote: profB);
          final r2 = service.reconcileProfileSafely(local: profB, remote: profA);

          // 1. r1 and r2 report the same set of fault field names
          final faults1 = r1.fieldFaults.map((f) => f.field).toSet();
          final faults2 = r2.fieldFaults.map((f) => f.field).toSet();
          expect(faults1, equals(faults2), reason: 'Seed $seed: Fault sets must match');

          // 2. Every field and every list item not named by a fault is equal in r1 and r2
          if (!faults1.contains('roomState.roomCode')) {
            expect(r1.profile.roomState.roomCode, equals(r2.profile.roomState.roomCode));
          }
          if (!faults1.contains('roomState.roomId')) {
            expect(r1.profile.roomState.roomId, equals(r2.profile.roomState.roomId));
          }
          expect(r1.profile.name, equals(r2.profile.name));
          expect(r1.profile.notesRegister.value, equals(r2.profile.notesRegister.value));
          expect(r1.profile.partyPurse, equals(r2.profile.partyPurse));

          for (final inst in r1.profile.roomState.entityInstances) {
            if (!faults1.contains('roomState.entityInstances[${inst.instanceId}]')) {
              final matchingInR2 = r2.profile.roomState.entityInstances
                  .firstWhere((i) => i.instanceId == inst.instanceId);
              expect(inst, equals(matchingInR2));
            }
          }
          for (final cont in r1.profile.roomState.containers) {
            if (!faults1.contains('roomState.containers[${cont.containerId}]')) {
              final matchingInR2 = r2.profile.roomState.containers
                  .firstWhere((c) => c.containerId == cont.containerId);
              expect(cont, equals(matchingInR2));
            }
          }

          // 3. Every faulted field or item equals the local side's value (a in r1, b in r2)
          if (faults1.contains('roomState.roomCode')) {
            expect(r1.profile.roomState.roomCode, equals(profA.roomState.roomCode));
            expect(r2.profile.roomState.roomCode, equals(profB.roomState.roomCode));
          }
          if (faults1.contains('roomState.roomId')) {
            expect(r1.profile.roomState.roomId, equals(profA.roomState.roomId));
            expect(r2.profile.roomState.roomId, equals(profB.roomState.roomId));
          }
          for (final f in faults1) {
            if (f.startsWith('roomState.entityInstances[')) {
              final instId = f.substring('roomState.entityInstances['.length, f.length - 1);
              final itemR1 = r1.profile.roomState.entityInstances
                  .firstWhere((i) => i.instanceId == instId);
              final itemR2 = r2.profile.roomState.entityInstances
                  .firstWhere((i) => i.instanceId == instId);
              final itemA = profA.roomState.entityInstances
                  .firstWhere((i) => i.instanceId == instId);
              final itemB = profB.roomState.entityInstances
                  .firstWhere((i) => i.instanceId == instId);
              expect(itemR1, equals(itemA));
              expect(itemR2, equals(itemB));
            } else if (f.startsWith('roomState.containers[')) {
              final contId = f.substring('roomState.containers['.length, f.length - 1);
              final itemR1 = r1.profile.roomState.containers
                  .firstWhere((c) => c.containerId == contId);
              final itemR2 = r2.profile.roomState.containers
                  .firstWhere((c) => c.containerId == contId);
              final itemA = profA.roomState.containers
                  .firstWhere((c) => c.containerId == contId);
              final itemB = profB.roomState.containers
                  .firstWhere((c) => c.containerId == contId);
              expect(itemR1, equals(itemA));
              expect(itemR2, equals(itemB));
            }
          }

          // 4. When there are no faults, r1.profile == CampaignProfile.join(a, b)
          if (faults1.isEmpty) {
            final canonicalJoin = CampaignProfile.join(profA, profB);
            expect(r1.profile, equals(canonicalJoin), reason: 'Seed $seed: Reconcile must equal canonical join');
          }

          // 5. Every item present on either side appears in both results (no item is dropped)
          final allExpectedInstanceIds = {
            ...profA.roomState.entityInstances.map((i) => i.instanceId),
            ...profB.roomState.entityInstances.map((i) => i.instanceId),
          };
          final allExpectedContainerIds = {
            ...profA.roomState.containers.map((c) => c.containerId),
            ...profB.roomState.containers.map((c) => c.containerId),
          };

          expect(
            r1.profile.roomState.entityInstances.map((i) => i.instanceId).toSet(),
            equals(allExpectedInstanceIds),
            reason: 'Seed $seed: No instances dropped in r1',
          );
          expect(
            r2.profile.roomState.entityInstances.map((i) => i.instanceId).toSet(),
            equals(allExpectedInstanceIds),
            reason: 'Seed $seed: No instances dropped in r2',
          );
          expect(
            r1.profile.roomState.containers.map((c) => c.containerId).toSet(),
            equals(allExpectedContainerIds),
            reason: 'Seed $seed: No containers dropped in r1',
          );
          expect(
            r2.profile.roomState.containers.map((c) => c.containerId).toSet(),
            equals(allExpectedContainerIds),
            reason: 'Seed $seed: No containers dropped in r2',
          );
        } catch (e) {
          // Print seed on failure as required by spec
          // ignore: avoid_print
          print('FAILED AT SEED $seed: $e');
          rethrow;
        }
      }
    });
  });
}
