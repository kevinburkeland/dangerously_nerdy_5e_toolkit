import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  group('Cold Iron Birdcage — Pass 9.1: Placeholder Invariants & Merge Laws (F1)', () {
    const zeroTs = HybridLogicalClock(
      physicalTime: 0,
      logicalCounter: 0,
      nodeId: 'genesis',
    );

    test(
        'Regression: DM values beat joiner placeholders through reconcileProfileSafely in both merge orders',
        () {
      final recon = RoomStateReconciliationService();

      const dmTs = HybridLogicalClock(
        physicalTime: 1000000,
        logicalCounter: 0,
        nodeId: 'dm_device',
      );

      final dmProfile = CampaignProfile.raw(
        id: 'campaign_ABC123',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'The Dragon Hunt',
          timestamp: dmTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_ABC123',
          roomCode: 'ABC123',
          title: 'Dragon Lair Staging',
          titleTimestamp: dmTs,
          description: 'A cavern full of gold and danger.',
          descriptionTimestamp: dmTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Secret DM notes for the session.',
          timestamp: dmTs,
        ),
        changeLog: const [],
      );

      // Joiner placeholder stamped at zero timestamp
      final joinerPlaceholder = CampaignProfile.raw(
        id: 'campaign_ABC123',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Campaign ABC123',
          timestamp: zeroTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000000, isUtc: true),
        lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(2000000, isUtc: true),
        roomState: RoomNodeState(
          roomId: 'room_ABC123',
          roomCode: 'ABC123',
          title: 'Campaign ABC123 Staging',
          titleTimestamp: zeroTs,
          description: '',
          descriptionTimestamp: zeroTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: zeroTs,
        ),
        changeLog: const [],
      );

      // Order 1: local is DM, remote is joiner placeholder
      final resDmFirst = recon.reconcileProfileSafely(
        local: dmProfile,
        remote: joinerPlaceholder,
      );
      expect(resDmFirst.fieldFaults, isEmpty);
      expect(resDmFirst.profile.name, equals('The Dragon Hunt'));
      expect(resDmFirst.profile.roomState.title, equals('Dragon Lair Staging'));
      expect(resDmFirst.profile.roomState.description,
          equals('A cavern full of gold and danger.'));
      expect(resDmFirst.profile.notesMarkdown,
          equals('Secret DM notes for the session.'));

      // Order 2: local is joiner placeholder, remote is DM
      final resJoinerFirst = recon.reconcileProfileSafely(
        local: joinerPlaceholder,
        remote: dmProfile,
      );
      expect(resJoinerFirst.fieldFaults, isEmpty);
      expect(resJoinerFirst.profile.name, equals('The Dragon Hunt'));
      expect(resJoinerFirst.profile.roomState.title, equals('Dragon Lair Staging'));
      expect(resJoinerFirst.profile.roomState.description,
          equals('A cavern full of gold and danger.'));
      expect(resJoinerFirst.profile.notesMarkdown,
          equals('Secret DM notes for the session.'));

      // Invariant: Both merge orders yield identical state
      expect(resDmFirst.profile.nameRegister,
          equals(resJoinerFirst.profile.nameRegister));
      expect(resDmFirst.profile.notesRegister,
          equals(resJoinerFirst.profile.notesRegister));
      expect(resDmFirst.profile.roomState.titleRegister,
          equals(resJoinerFirst.profile.roomState.titleRegister));
      expect(resDmFirst.profile.roomState.descriptionRegister,
          equals(resJoinerFirst.profile.roomState.descriptionRegister));
    });

    test('Two joiners placeholders merge without a fault', () {
      final recon = RoomStateReconciliationService();

      final joiner1 = CampaignProfile.raw(
        id: 'campaign_ABC123',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Campaign ABC123',
          timestamp: zeroTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_ABC123',
          roomCode: 'ABC123',
          title: 'Campaign ABC123 Staging',
          titleTimestamp: zeroTs,
          description: '',
          descriptionTimestamp: zeroTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: zeroTs,
        ),
        changeLog: const [],
      );

      final joiner2 = CampaignProfile.raw(
        id: 'campaign_ABC123',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Campaign ABC123',
          timestamp: zeroTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025, 1, 2),
        lastPlayedAt: DateTime.utc(2025, 1, 2),
        roomState: RoomNodeState(
          roomId: 'room_ABC123',
          roomCode: 'ABC123',
          title: 'Campaign ABC123 Staging',
          titleTimestamp: zeroTs,
          description: '',
          descriptionTimestamp: zeroTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: '',
          timestamp: zeroTs,
        ),
        changeLog: const [],
      );

      final res12 = recon.reconcileProfileSafely(local: joiner1, remote: joiner2);
      final res21 = recon.reconcileProfileSafely(local: joiner2, remote: joiner1);

      expect(res12.fieldFaults, isEmpty);
      expect(res21.fieldFaults, isEmpty);
      expect(res12.profile.name, equals('Campaign ABC123'));
      expect(res12.profile.roomState.title, equals('Campaign ABC123 Staging'));
      expect(res12.profile.roomState.description, equals(''));
      expect(res12.profile.notesMarkdown, equals(''));
      expect(res12.profile.nameRegister, equals(res21.profile.nameRegister));
    });

    test(
        'Legacy divergent zero-timestamp values converge identically in every merge order',
        () {
      final recon = RoomStateReconciliationService();

      final legacyA = CampaignProfile.raw(
        id: 'camp_crx',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Camp Alpha',
          timestamp: zeroTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_crx',
          roomCode: 'CR-X',
          title: 'Campaign CR-X Staging',
          titleTimestamp: zeroTs,
          description: 'Description Alpha',
          descriptionTimestamp: zeroTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Notes Alpha',
          timestamp: zeroTs,
        ),
        changeLog: const [],
      );

      final legacyB = CampaignProfile.raw(
        id: 'camp_crx',
        nameRegister: const CrdtLwwRegister<String>(
          value: 'Camp Beta',
          timestamp: zeroTs,
        ),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_crx',
          roomCode: 'CR-X',
          title: 'Main Hall Staging Area',
          titleTimestamp: zeroTs,
          description: 'Description Beta',
          descriptionTimestamp: zeroTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister<String>(
          value: 'Notes Beta',
          timestamp: zeroTs,
        ),
        changeLog: const [],
      );

      final resAB = recon.reconcileProfileSafely(local: legacyA, remote: legacyB);
      final resBA = recon.reconcileProfileSafely(local: legacyB, remote: legacyA);

      expect(resAB.fieldFaults, isEmpty);
      expect(resBA.fieldFaults, isEmpty);

      // Deterministic total order resolution
      expect(resAB.profile.name, equals(resBA.profile.name));
      expect(resAB.profile.notesMarkdown, equals(resBA.profile.notesMarkdown));
      expect(resAB.profile.roomState.title, equals(resBA.profile.roomState.title));
      expect(resAB.profile.roomState.description,
          equals(resBA.profile.roomState.description));
    });

    test(
        'Law test over seeded random profiles mixing placeholder registers and real writes',
        () {
      final random = Random(1337);
      final clock = StatefulHlcClock(replicaId: ReplicaId('author-node'));

      CampaignProfile generateProfile(String id, int seedOffset) {
        final r = Random(seedOffset);
        // Decide for each register whether it is a placeholder (zero ts) or real write
        final bool isNamePlaceholder = r.nextBool();
        final bool isNotesPlaceholder = r.nextBool();
        final bool isTitlePlaceholder = r.nextBool();
        final bool isDescPlaceholder = r.nextBool();

        final nameTs = isNamePlaceholder ? zeroTs : clock.nextTimestamp();
        final notesTs = isNotesPlaceholder ? zeroTs : clock.nextTimestamp();
        final titleTs = isTitlePlaceholder ? zeroTs : clock.nextTimestamp();
        final descTs = isDescPlaceholder ? zeroTs : clock.nextTimestamp();

        return CampaignProfile.raw(
          id: id,
          nameRegister: CrdtLwwRegister<String>(
            value: isNamePlaceholder ? 'Placeholder Name' : 'Real Name ${r.nextInt(100)}',
            timestamp: nameTs,
          ),
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2025, 1, 1),
          lastPlayedAt: DateTime.utc(2025, 1, 1),
          roomState: RoomNodeState(
            roomId: 'room_$id',
            roomCode: id,
            title: isTitlePlaceholder ? 'Placeholder Title' : 'Real Title ${r.nextInt(100)}',
            titleTimestamp: titleTs,
            description: isDescPlaceholder ? '' : 'Real Desc ${r.nextInt(100)}',
            descriptionTimestamp: descTs,
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: CrdtLwwRegister<String>(
            value: isNotesPlaceholder ? '' : 'Real Notes ${r.nextInt(100)}',
            timestamp: notesTs,
          ),
          changeLog: const [],
        );
      }

      for (var iter = 0; iter < 100; iter++) {
        final pA = generateProfile('law_room', random.nextInt(1000000));
        final pB = generateProfile('law_room', random.nextInt(1000000));
        final pC = generateProfile('law_room', random.nextInt(1000000));

        // 1. Idempotence: merge(A, A) == A
        final joinAA = CampaignProfile.join(pA, pA);
        expect(joinAA.nameRegister, equals(pA.nameRegister));
        expect(joinAA.notesRegister, equals(pA.notesRegister));
        expect(joinAA.roomState.titleRegister, equals(pA.roomState.titleRegister));
        expect(joinAA.roomState.descriptionRegister,
            equals(pA.roomState.descriptionRegister));

        // 2. Commutativity: merge(A, B) == merge(B, A)
        final joinAB = CampaignProfile.join(pA, pB);
        final joinBA = CampaignProfile.join(pB, pA);
        expect(joinAB.nameRegister, equals(joinBA.nameRegister));
        expect(joinAB.notesRegister, equals(joinBA.notesRegister));
        expect(joinAB.roomState.titleRegister,
            equals(joinBA.roomState.titleRegister));
        expect(joinAB.roomState.descriptionRegister,
            equals(joinBA.roomState.descriptionRegister));

        // 3. Associativity: merge(merge(A, B), C) == merge(A, merge(B, C))
        final joinAbThenC = CampaignProfile.join(joinAB, pC);
        final joinAThenBc = CampaignProfile.join(pA, CampaignProfile.join(pB, pC));
        expect(joinAbThenC.nameRegister, equals(joinAThenBc.nameRegister));
        expect(joinAbThenC.notesRegister, equals(joinAThenBc.notesRegister));
        expect(joinAbThenC.roomState.titleRegister,
            equals(joinAThenBc.roomState.titleRegister));
        expect(joinAbThenC.roomState.descriptionRegister,
            equals(joinAThenBc.roomState.descriptionRegister));

        // 4. Invariant: Every real write survives against any placeholder
        void verifyRealWriteSurvives(
          CrdtLwwRegister<String> regA,
          CrdtLwwRegister<String> regB,
          CrdtLwwRegister<String> mergedReg,
        ) {
          if (regA.timestamp.physicalTime > 0 && regB.timestamp.physicalTime == 0) {
            expect(mergedReg, equals(regA));
          } else if (regB.timestamp.physicalTime > 0 && regA.timestamp.physicalTime == 0) {
            expect(mergedReg, equals(regB));
          }
        }

        verifyRealWriteSurvives(pA.nameRegister, pB.nameRegister, joinAB.nameRegister);
        verifyRealWriteSurvives(pA.notesRegister, pB.notesRegister, joinAB.notesRegister);
        verifyRealWriteSurvives(pA.roomState.titleRegister, pB.roomState.titleRegister,
            joinAB.roomState.titleRegister);
        verifyRealWriteSurvives(pA.roomState.descriptionRegister,
            pB.roomState.descriptionRegister, joinAB.roomState.descriptionRegister);
      }
    });
  });
}
