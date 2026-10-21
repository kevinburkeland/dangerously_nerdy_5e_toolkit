import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';

void main() {
  group('Cold Iron Birdcage — Pass 7.1 Required Test 1: Reconcile Equals Join Law', () {
    test('reconcileProfileSafely(a, b).profile == CampaignProfile.join(a, b) across 350 seeds', () {
      final recon = RoomStateReconciliationService();

      const requiredVaryingKeys = <String>{
        'id',
        'name',
        'nameRegister',
        'edition',
        'createdAt',
        'lastPlayedAt',
        'roomState',
        'partyCharacterIds',
        'partyRoster_crdt',
        'pinnedRuleIds',
        'pinnedRules_crdt',
        'notesMarkdown',
        'notesRegister',
        'partyPurse',
        'memberPurses',
        'changeLog',
        'recordVersion',
      };

      for (int seed = 0; seed < 350; seed++) {
        final rand = Random(seed);

        final tsA1 = HybridLogicalClock(physicalTime: 1000 + rand.nextInt(100), logicalCounter: 0, nodeId: 'node_a');
        final tsA2 = HybridLogicalClock(physicalTime: 1200 + rand.nextInt(100), logicalCounter: 0, nodeId: 'node_a');
        final tsB1 = HybridLogicalClock(physicalTime: 1050 + rand.nextInt(100), logicalCounter: 0, nodeId: 'node_b');
        final tsB2 = HybridLogicalClock(physicalTime: 1250 + rand.nextInt(100), logicalCounter: 0, nodeId: 'node_b');

        // 1. Name registers
        final nameA = CrdtLwwRegister<String>(value: 'Name A $seed', timestamp: tsA1);
        final nameB = CrdtLwwRegister<String>(value: 'Name B $seed', timestamp: tsB1);

        // 2. Notes registers
        final notesA = CrdtLwwRegister<String>(value: 'Notes A $seed', timestamp: tsA2);
        final notesB = CrdtLwwRegister<String>(value: 'Notes B $seed', timestamp: tsB2);

        // 3. Reserve PartyPurse (PN-counters with both positive and negative values)
        final purseA = PartyPurse.fromCounters({
          'gp': PnCounter(
            positive: {'node_a': 100 + rand.nextInt(50)},
            negative: {'node_a': 10 + rand.nextInt(20)},
          ),
          'sp': PnCounter(
            positive: {'node_a': 50 + rand.nextInt(25)},
            negative: {'node_a': 5 + rand.nextInt(10)},
          ),
        });

        final purseB = PartyPurse.fromCounters({
          'gp': PnCounter(
            positive: {'node_b': 80 + rand.nextInt(60)},
            negative: {'node_b': 15 + rand.nextInt(15)},
          ),
          'ep': PnCounter(
            positive: {'node_b': 30 + rand.nextInt(20)},
            negative: const {},
          ),
        });

        // 4. Member Purses: overlapping ('aria', 'bram') and disjoint ('caleb', 'dorian'), negative counters
        final memberPursesA = <String, PartyPurse>{
          'aria': PartyPurse.fromCounters({
            'gp': PnCounter(
              positive: {'node_a': 50 + rand.nextInt(20)},
              negative: {'node_a': 5 + rand.nextInt(10)},
            ),
          }),
          'bram': PartyPurse.fromCounters({
            'sp': PnCounter(
              positive: {'node_a': 20 + rand.nextInt(10)},
              negative: {'node_a': 25 + rand.nextInt(10)}, // net negative
            ),
          }),
          'caleb': PartyPurse.fromCounters({
            'cp': PnCounter(
              positive: {'node_a': 200},
              negative: const {},
            ),
          }),
        };

        final memberPursesB = <String, PartyPurse>{
          'aria': PartyPurse.fromCounters({
            'gp': PnCounter(
              positive: {'node_b': 40 + rand.nextInt(30)},
              negative: {'node_b': 10 + rand.nextInt(10)},
            ),
          }),
          'bram': PartyPurse.fromCounters({
            'sp': PnCounter(
              positive: {'node_b': 30 + rand.nextInt(10)},
              negative: {'node_b': 5},
            ),
            'gp': PnCounter(
              positive: {'node_b': 15},
              negative: const {},
            ),
          }),
          'dorian': PartyPurse.fromCounters({
            'pp': PnCounter(
              positive: {'node_b': 10},
              negative: const {},
            ),
          }),
        };

        // 5. Party Roster: CRDT OR-set
        var rosterA = const CrdtOrSet<String>.empty()
            .add('aria', 'aria', tsA1)
            .add('bram', 'bram', tsA1)
            .add('temp_char', 'temp_char', tsA1)
            .remove('temp_char', tsA2);

        var rosterB = const CrdtOrSet<String>.empty()
            .add('bram', 'bram', tsB1)
            .add('dorian', 'dorian', tsB1);

        // 6. Pinned Rules: CRDT OR-set
        var rulesA = const CrdtOrSet<String>.empty()
            .add('flanking', 'flanking', tsA1)
            .add('cover', 'cover', tsA1);

        var rulesB = const CrdtOrSet<String>.empty()
            .add('cover', 'cover', tsB1)
            .add('grapple', 'grapple', tsB1);

        // 7. Change Log
        final List<PartyEvent> logA = [
          PartyEvent(
            id: 'ev_shared',
            roomCode: 'LAW-1',
            timestamp: DateTime.utc(2026, 1, 1, 12, 0),
            playerName: 'Player Shared',
            type: 'deposit',
            details: 'Shared deposit',
          ),
          PartyEvent(
            id: 'ev_a_$seed',
            roomCode: 'LAW-1',
            timestamp: DateTime.utc(2026, 1, 1, 12, 5),
            playerName: 'Player A',
            type: 'withdraw',
            details: 'A withdrawal',
          ),
        ];

        final List<PartyEvent> logB = [
          PartyEvent(
            id: 'ev_shared',
            roomCode: 'LAW-1',
            timestamp: DateTime.utc(2026, 1, 1, 12, 0),
            playerName: 'Player Shared',
            type: 'deposit',
            details: 'Shared deposit',
          ),
          PartyEvent(
            id: 'ev_b_$seed',
            roomCode: 'LAW-1',
            timestamp: DateTime.utc(2026, 1, 1, 12, 10),
            playerName: 'Player B',
            type: 'disperse',
            details: 'B dispersion',
          ),
        ];

        // 8. RoomNodeState
        final roomA = RoomNodeState(
          roomId: 'room_LAW-1',
          roomCode: 'LAW-1',
          title: 'Room Title A $seed',
          titleTimestamp: tsA1,
          description: 'Desc A $seed',
          descriptionTimestamp: tsA2,
          customProperties: {'prop_a': 'val_a_$seed', 'shared_prop': 'same'},
          activeEncounter: const CrdtOrSet<EncounterParticipant>.empty().add(
            'p1',
            EncounterParticipant(
              participantId: 'p1',
              entityLink: RoomEntityLink(
                entityId: 'goblin_1',
                displayName: 'Goblin 1',
              ),
              currentHp: 7,
              maxHp: 7,
              defense: 15,
              initiativeScore: 12,
            ),
            tsA1,
          ),
        );

        final roomB = RoomNodeState(
          roomId: 'room_LAW-1',
          roomCode: 'LAW-1',
          title: 'Room Title B $seed',
          titleTimestamp: tsB1,
          description: 'Desc B $seed',
          descriptionTimestamp: tsB2,
          customProperties: {'prop_b': 'val_b_$seed', 'shared_prop': 'same'},
          activeEncounter: const CrdtOrSet<EncounterParticipant>.empty().add(
            'p2',
            EncounterParticipant(
              participantId: 'p2',
              entityLink: RoomEntityLink(
                entityId: 'orc_1',
                displayName: 'Orc 1',
              ),
              currentHp: 15,
              maxHp: 15,
              defense: 13,
              initiativeScore: 9,
            ),
            tsB1,
          ),
        );

        final profA = CampaignProfile.raw(
          id: 'camp_law_1',
          nameRegister: nameA,
          edition: const RulesetIdentifier('dnd5e_2024'),
          createdAt: DateTime.utc(2026, 1, 1, 10, 0),
          lastPlayedAt: DateTime.utc(2026, 1, 1, 14, 0),
          roomState: roomA,
          partyRoster: rosterA,
          pinnedRules: rulesA,
          notesRegister: notesA,
          partyPurse: purseA,
          memberPurses: memberPursesA,
          changeLog: logA,
        );

        final profB = CampaignProfile.raw(
          id: 'camp_law_1',
          nameRegister: nameB,
          edition: const RulesetIdentifier('dnd5e_2024'),
          createdAt: DateTime.utc(2026, 1, 1, 9, 0),
          lastPlayedAt: DateTime.utc(2026, 1, 1, 15, 0),
          roomState: roomB,
          partyRoster: rosterB,
          pinnedRules: rulesB,
          notesRegister: notesB,
          partyPurse: purseB,
          memberPurses: memberPursesB,
          changeLog: logB,
        );

        // Coverage guard: check on seed 0 that all DTO map keys are tracked and varied
        if (seed == 0) {
          final dtoMapA = CampaignProfileDto.fromDomain(profA).toMap();
          for (final key in dtoMapA.keys) {
            expect(
              requiredVaryingKeys,
              contains(key),
              reason: 'Coverage guard: CampaignProfile gained key "$key" not covered by law generator',
            );
          }
          for (final key in requiredVaryingKeys) {
            expect(
              dtoMapA.containsKey(key),
              isTrue,
              reason: 'Coverage guard: required varying key "$key" missing from DTO map',
            );
          }
        }

        // Forward: reconcileProfileSafely(profA, profB) == CampaignProfile.join(profA, profB)
        final resAB = recon.reconcileProfileSafely(local: profA, remote: profB);
        expect(resAB.fieldFaults, isEmpty, reason: 'Seed $seed forward produced unexpected faults');
        final joinAB = CampaignProfile.join(profA, profB);
        expect(resAB.profile, equals(joinAB), reason: 'Seed $seed forward failed reconcile == join');

        // Reverse: reconcileProfileSafely(profB, profA) == CampaignProfile.join(profB, profA)
        final resBA = recon.reconcileProfileSafely(local: profB, remote: profA);
        expect(resBA.fieldFaults, isEmpty, reason: 'Seed $seed reverse produced unexpected faults');
        final joinBA = CampaignProfile.join(profB, profA);
        expect(resBA.profile, equals(joinBA), reason: 'Seed $seed reverse failed reconcile == join');
      }
    });
  });
}
