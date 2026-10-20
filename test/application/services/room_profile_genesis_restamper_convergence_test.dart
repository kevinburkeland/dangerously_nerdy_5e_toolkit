import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/room_profile_genesis_restamper.dart';

void main() {
  group('RoomProfileGenesisRestamper Convergence Tests (Required Test 2)', () {
    test('250 random seeds converge with zero faults across all opening schedules', () {
      final random = Random(88888);
      final reconciler = RoomStateReconciliationService();

      for (var seed = 0; seed < 250; seed++) {
        final clockA = StatefulHlcClock(replicaId: ReplicaId('dev-a'));
        final clockB = StatefulHlcClock(replicaId: ReplicaId('dev-b'));

        final id = 'camp_conv_$seed';
        final roomCode = 'CR-$seed';
        final edition = random.nextBool() ? DmRulesEdition.v2014 : DmRulesEdition.v2024;

        final isTitleGenesisA = random.nextBool();
        final isDescGenesisA = random.nextBool();
        final isTitleGenesisB = random.nextBool();
        final isDescGenesisB = random.nextBool();

        final titleStampA = isTitleGenesisA
            ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis')
            : clockA.nextTimestamp();
        final descStampA = isDescGenesisA
            ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis')
            : clockA.nextTimestamp();

        final titleStampB = isTitleGenesisB
            ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis')
            : clockB.nextTimestamp();
        final descStampB = isDescGenesisB
            ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis')
            : clockB.nextTimestamp();

        var profA = CampaignProfile.raw(
          id: id,
          nameRegister: const CrdtLwwRegister<String>(
            value: 'Campaign Common Name',
            timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'init'),
          ),
          edition: edition,
          createdAt: DateTime.utc(2025, 1, 1),
          lastPlayedAt: DateTime.utc(2025, 1, 1),
          roomState: RoomNodeState(
            roomId: 'room_$roomCode',
            roomCode: roomCode,
            titleRegister: CrdtLwwRegister<String>(
              value: 'Title A seed $seed (${random.nextInt(1000)})',
              timestamp: titleStampA,
            ),
            descriptionRegister: CrdtLwwRegister<String>(
              value: 'Desc A seed $seed (${random.nextInt(1000)})',
              timestamp: descStampA,
            ),
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: const CrdtLwwRegister<String>(
            value: '',
            timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'init'),
          ),
          changeLog: const [],
        );

        var profB = CampaignProfile.raw(
          id: id,
          nameRegister: const CrdtLwwRegister<String>(
            value: 'Campaign Common Name',
            timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'init'),
          ),
          edition: edition,
          createdAt: DateTime.utc(2025, 1, 1),
          lastPlayedAt: DateTime.utc(2025, 1, 1),
          roomState: RoomNodeState(
            roomId: 'room_$roomCode',
            roomCode: roomCode,
            titleRegister: CrdtLwwRegister<String>(
              value: 'Title B seed $seed (${random.nextInt(1000)})',
              timestamp: titleStampB,
            ),
            descriptionRegister: CrdtLwwRegister<String>(
              value: 'Desc B seed $seed (${random.nextInt(1000)})',
              timestamp: descStampB,
            ),
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: const CrdtLwwRegister<String>(
            value: '',
            timestamp: HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'init'),
          ),
          changeLog: const [],
        );

        final schedule = random.nextInt(3);

        if (schedule == 0) {
          // Both open (re-stamp) before syncing
          profA = RoomProfileGenesisRestamper.restampIfNeeded(profile: profA, clock: clockA);
          profB = RoomProfileGenesisRestamper.restampIfNeeded(profile: profB, clock: clockB);

          final resA = reconciler.reconcileProfileSafely(local: profA, remote: profB);
          final resB = reconciler.reconcileProfileSafely(local: profB, remote: profA);

          expect(resA.fieldFaults, isEmpty, reason: 'Seed $seed schedule 0 resA faults: ${resA.fieldFaults}');
          expect(resB.fieldFaults, isEmpty, reason: 'Seed $seed schedule 0 resB faults: ${resB.fieldFaults}');

          // Sync back
          final resA2 = reconciler.reconcileProfileSafely(local: resA.profile, remote: resB.profile);
          final resB2 = reconciler.reconcileProfileSafely(local: resB.profile, remote: resA.profile);

          expect(resA2.profile, equals(resB2.profile), reason: 'Seed $seed must converge to identical profile');
        } else if (schedule == 1) {
          // Side A opens first, syncs, then side B opens and syncs
          profA = RoomProfileGenesisRestamper.restampIfNeeded(profile: profA, clock: clockA);

          final resA = reconciler.reconcileProfileSafely(local: profA, remote: profB);
          final resB = reconciler.reconcileProfileSafely(local: profB, remote: profA);

          expect(resA.fieldFaults, isEmpty, reason: 'Seed $seed schedule 1 resA faults: ${resA.fieldFaults}');
          expect(resB.fieldFaults, isEmpty, reason: 'Seed $seed schedule 1 resB faults: ${resB.fieldFaults}');

          // Now side B opens the room
          var profBOpened = RoomProfileGenesisRestamper.restampIfNeeded(profile: resB.profile, clock: clockB);

          final resA2 = reconciler.reconcileProfileSafely(local: resA.profile, remote: profBOpened);
          final resB2 = reconciler.reconcileProfileSafely(local: profBOpened, remote: resA2.profile);

          expect(resA2.fieldFaults, isEmpty, reason: 'Seed $seed schedule 1 resA2 faults: ${resA2.fieldFaults}');
          expect(resB2.fieldFaults, isEmpty, reason: 'Seed $seed schedule 1 resB2 faults: ${resB2.fieldFaults}');
          expect(resA2.profile, equals(resB2.profile), reason: 'Seed $seed must converge after both opened');
        } else {
          // Side B opens first, syncs, then side A opens and syncs
          profB = RoomProfileGenesisRestamper.restampIfNeeded(profile: profB, clock: clockB);

          final resA = reconciler.reconcileProfileSafely(local: profA, remote: profB);
          final resB = reconciler.reconcileProfileSafely(local: profB, remote: profA);

          expect(resA.fieldFaults, isEmpty, reason: 'Seed $seed schedule 2 resA faults: ${resA.fieldFaults}');
          expect(resB.fieldFaults, isEmpty, reason: 'Seed $seed schedule 2 resB faults: ${resB.fieldFaults}');

          // Now side A opens the room
          var profAOpened = RoomProfileGenesisRestamper.restampIfNeeded(profile: resA.profile, clock: clockA);

          final resB2 = reconciler.reconcileProfileSafely(local: resB.profile, remote: profAOpened);
          final resA2 = reconciler.reconcileProfileSafely(local: profAOpened, remote: resB2.profile);

          expect(resA2.fieldFaults, isEmpty, reason: 'Seed $seed schedule 2 resA2 faults: ${resA2.fieldFaults}');
          expect(resB2.fieldFaults, isEmpty, reason: 'Seed $seed schedule 2 resB2 faults: ${resB2.fieldFaults}');
          expect(resA2.profile, equals(resB2.profile), reason: 'Seed $seed must converge after both opened');
        }
      }
    });
  });
}
