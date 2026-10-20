import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/room_profile_genesis_restamper.dart';

void main() {
  group('RoomProfileGenesisRestamper Law Tests (Required Test 1)', () {
    test('250 random seeds satisfy all restamper invariants', () {
      final random = Random(424242);
      final clock = StatefulHlcClock(replicaId: ReplicaId('test-clock-node'));

      for (var seed = 0; seed < 250; seed++) {
        final id = 'camp_seed_$seed';
        final name = 'Campaign Name $seed';
        final roomCode = 'ROOM$seed';
        final titleText = 'Title Text $seed random=${random.nextInt(10000)}';
        final descText = 'Desc Text $seed random=${random.nextInt(10000)}';

        final bool isTitleGenesis = random.nextBool();
        final bool isDescGenesis = random.nextBool();

        final titleStamp = isTitleGenesis
            ? (random.nextBool()
                ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'node_zero_pt')
                : const HybridLogicalClock(physicalTime: 12345, logicalCounter: 0, nodeId: 'genesis'))
            : HybridLogicalClock(
                physicalTime: 50000 + random.nextInt(50000),
                logicalCounter: random.nextInt(10),
                nodeId: 'real_node_a',
              );

        final descStamp = isDescGenesis
            ? (random.nextBool()
                ? const HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'node_zero_pt2')
                : const HybridLogicalClock(physicalTime: 54321, logicalCounter: 0, nodeId: 'genesis'))
            : HybridLogicalClock(
                physicalTime: 50000 + random.nextInt(50000),
                logicalCounter: random.nextInt(10),
                nodeId: 'real_node_b',
              );

        final initialProfile = CampaignProfile.raw(
          id: id,
          nameRegister: CrdtLwwRegister<String>(
            value: name,
            timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'init'),
          ),
          edition: random.nextBool() ? DmRulesEdition.v2014 : DmRulesEdition.v2024,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000000 + seed, isUtc: true),
          lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(2000000 + seed, isUtc: true),
          roomState: RoomNodeState(
            roomId: 'room_$roomCode',
            roomCode: roomCode,
            titleRegister: CrdtLwwRegister<String>(
              value: titleText,
              timestamp: titleStamp,
            ),
            descriptionRegister: CrdtLwwRegister<String>(
              value: descText,
              timestamp: descStamp,
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

        final restamped = RoomProfileGenesisRestamper.restampIfNeeded(
          profile: initialProfile,
          clock: clock,
        );

        // Invariant 1: No genesis stamps remain
        expect(
          RoomProfileGenesisRestamper.isGenesisTimestamp(restamped.roomState.titleRegister.timestamp),
          isFalse,
          reason: 'Seed $seed title timestamp must not be genesis',
        );
        expect(
          RoomProfileGenesisRestamper.isGenesisTimestamp(restamped.roomState.descriptionRegister.timestamp),
          isFalse,
          reason: 'Seed $seed description timestamp must not be genesis',
        );

        // Invariant 2: Values unchanged
        expect(restamped.roomState.title, equals(initialProfile.roomState.title));
        expect(restamped.roomState.description, equals(initialProfile.roomState.description));

        // Invariant 3: Registers that were already stamped are identical
        if (!isTitleGenesis) {
          expect(restamped.roomState.titleRegister, equals(initialProfile.roomState.titleRegister));
        }
        if (!isDescGenesis) {
          expect(restamped.roomState.descriptionRegister, equals(initialProfile.roomState.descriptionRegister));
        }

        // Invariant 4: Every other field of the profile is equal to input
        expect(restamped.id, equals(initialProfile.id));
        expect(restamped.name, equals(initialProfile.name));
        expect(restamped.nameRegister, equals(initialProfile.nameRegister));
        expect(restamped.edition, equals(initialProfile.edition));
        expect(restamped.createdAt, equals(initialProfile.createdAt));
        expect(restamped.lastPlayedAt, equals(initialProfile.lastPlayedAt));
        expect(restamped.partyPurse, equals(initialProfile.partyPurse));
        expect(restamped.memberPurses, equals(initialProfile.memberPurses));
        expect(restamped.partyRoster, equals(initialProfile.partyRoster));
        expect(restamped.pinnedRules, equals(initialProfile.pinnedRules));
        expect(restamped.notesRegister, equals(initialProfile.notesRegister));
        expect(restamped.changeLog, equals(initialProfile.changeLog));
        expect(restamped.roomState.roomId, equals(initialProfile.roomState.roomId));
        expect(restamped.roomState.roomCode, equals(initialProfile.roomState.roomCode));
        expect(restamped.roomState.entityLinksCrdt, equals(initialProfile.roomState.entityLinksCrdt));
        expect(restamped.roomState.entityInstances, equals(initialProfile.roomState.entityInstances));
        expect(restamped.roomState.containers, equals(initialProfile.roomState.containers));
        expect(restamped.roomState.activeEncounter, equals(initialProfile.roomState.activeEncounter));
        expect(restamped.roomState.activeMinions, equals(initialProfile.roomState.activeMinions));
        expect(restamped.roomState.customProperties, equals(initialProfile.roomState.customProperties));

        // Invariant 5: Idempotent - second run returns equal profile and draws NO new timestamps
        final hlcBeforeSecond = clock.latest;
        final secondRun = RoomProfileGenesisRestamper.restampIfNeeded(
          profile: restamped,
          clock: clock,
        );
        expect(secondRun, equals(restamped), reason: 'Second run must equal first run');
        expect(clock.latest, equals(hlcBeforeSecond), reason: 'Second run must draw 0 timestamps');
      }
    });
  });
}
