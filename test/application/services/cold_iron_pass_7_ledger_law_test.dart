import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';

void main() {
  group('Cold Iron Birdcage: Pass 7 — Ledger Law Suite (P3)', () {
    const denominations = ['cp', 'sp', 'ep', 'gp', 'pp'];

    PartyPurse depositHelper(PartyPurse p, String denom, int amount, ReplicaId replicaId) {
      return p.modifyDenomination(denom, amount, replicaId: replicaId);
    }

    PartyPurse withdrawHelper(PartyPurse p, String denom, int amount, ReplicaId replicaId) {
      return p.modifyDenomination(denom, -amount, replicaId: replicaId);
    }

    PartySessionState buildSessionView(CampaignProfile profile) {
      PartyPurse displayedReserve = profile.partyPurse;
      final displayedMemberPurses = <String, PartyPurse>{};

      for (final entry in profile.memberPurses.entries) {
        if (profile.partyRoster.activeValues.contains(entry.key)) {
          displayedMemberPurses[entry.key] = entry.value;
        } else {
          // Off roster: folds into reserve view
          displayedReserve = displayedReserve.add(
            entry.value,
            replicaId: ReplicaId('view-node'),
          );
        }
      }

      return PartySessionState(
        roomCode: profile.roomState.roomCode,
        campaignName: profile.name,
        hostKeyHash: 'hash',
        partyPurse: displayedReserve,
        memberPurses: displayedMemberPurses,
        activePlayers: const [],
        characterRoster: profile.partyRoster.activeValues,
        lastUpdated: DateTime.utc(2026),
        expiresAt: DateTime.utc(2026, 2),
      );
    }

    int signedBalance(PartyPurse p, String denom) {
      return p.denominationCounters[denom]?.value ?? 0;
    }

    test('Ledger Law: 350 random seeds converge, conserve signed totals, and hide no coins', () {
      const totalSeeds = 350;

      for (int seed = 0; seed < totalSeeds; seed++) {
        final rng = Random(seed + 1000);

        final repIdA = ReplicaId('node_a_$seed');
        final repIdB = ReplicaId('node_b_$seed');
        final repIdC = ReplicaId('node_c_$seed');

        final clockA = StatefulHlcClock(replicaId: repIdA);
        final clockB = StatefulHlcClock(replicaId: repIdB);
        final clockC = StatefulHlcClock(replicaId: repIdC);

        final genesisClock = StatefulHlcClock(replicaId: ReplicaId('node_init'));
        final initialProfile = CampaignProfile.defaultProfile(
          id: 'camp_seed_$seed',
          nodeId: 'node_init',
          clock: genesisClock,
        ).copyWith(
          roomState: RoomNodeState(roomId: 'r_$seed', roomCode: 'ROOM$seed'),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
        );

        var repA = initialProfile;
        var repB = initialProfile;
        var repC = initialProfile;

        final externalNet = <String, int>{
          'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0,
        };

        final membersPool = ['aria', 'boromir', 'cyrus', 'daelen', 'elena'];

        // Initial roster
        for (final m in ['aria', 'boromir']) {
          repA = repA.copyWith(
            partyRoster: repA.partyRoster.add(m, m, clockA.nextTimestamp()),
          );
        }
        repB = repB.merge(repA);
        repC = repC.merge(repA);

        final numOps = 30 + rng.nextInt(30);

        for (int op = 0; op < numOps; op++) {
          final replicaChoice = rng.nextInt(3);
          final denom = denominations[rng.nextInt(denominations.length)];
          final member = membersPool[rng.nextInt(membersPool.length)];

          final targetReplicaId = replicaChoice == 0
              ? repIdA
              : (replicaChoice == 1 ? repIdB : repIdC);
          final targetClock = replicaChoice == 0
              ? clockA
              : (replicaChoice == 1 ? clockB : clockC);

          CampaignProfile mutate(CampaignProfile p) {
            final action = rng.nextInt(9);
            switch (action) {
              case 0:
                // External deposit to reserve
                final delta = 1 + rng.nextInt(100);
                externalNet[denom] = externalNet[denom]! + delta;
                return p.copyWith(
                  partyPurse: depositHelper(p.partyPurse, denom, delta, targetReplicaId),
                );

              case 1:
                // External withdrawal from reserve (including overdraft)
                final delta = 1 + rng.nextInt(100);
                externalNet[denom] = externalNet[denom]! - delta;
                return p.copyWith(
                  partyPurse: withdrawHelper(p.partyPurse, denom, delta, targetReplicaId),
                );

              case 2:
                // External deposit to member
                final delta = 1 + rng.nextInt(50);
                externalNet[denom] = externalNet[denom]! + delta;
                final cur = p.memberPurses[member] ?? const PartyPurse.empty();
                final updated = depositHelper(cur, denom, delta, targetReplicaId);
                final updatedMap = Map<String, PartyPurse>.from(p.memberPurses);
                updatedMap[member] = updated;
                return p.copyWith(memberPurses: updatedMap);

              case 3:
                // External withdrawal from member (including overdraft)
                final delta = 1 + rng.nextInt(50);
                externalNet[denom] = externalNet[denom]! - delta;
                final cur = p.memberPurses[member] ?? const PartyPurse.empty();
                final updated = withdrawHelper(cur, denom, delta, targetReplicaId);
                final updatedMap = Map<String, PartyPurse>.from(p.memberPurses);
                updatedMap[member] = updated;
                return p.copyWith(memberPurses: updatedMap);

              case 4:
                // Transfer from member to reserve (internal conservation: 0 external net)
                final cur = p.memberPurses[member] ?? const PartyPurse.empty();
                final bal = signedBalance(cur, denom);
                if (bal <= 0) return p;
                final transferAmount = 1 + rng.nextInt(bal);
                final updatedMember = withdrawHelper(cur, denom, transferAmount, targetReplicaId);
                final updatedReserve = depositHelper(p.partyPurse, denom, transferAmount, targetReplicaId);
                final updatedMap = Map<String, PartyPurse>.from(p.memberPurses);
                updatedMap[member] = updatedMember;
                return p.copyWith(partyPurse: updatedReserve, memberPurses: updatedMap);

              case 5:
                // Transfer from reserve to member (internal conservation: 0 external net)
                final reserveBal = signedBalance(p.partyPurse, denom);
                if (reserveBal <= 0) return p;
                final transferAmount = 1 + rng.nextInt(reserveBal);
                final updatedReserve = withdrawHelper(p.partyPurse, denom, transferAmount, targetReplicaId);
                final curMember = p.memberPurses[member] ?? const PartyPurse.empty();
                final updatedMember = depositHelper(curMember, denom, transferAmount, targetReplicaId);
                final updatedMap = Map<String, PartyPurse>.from(p.memberPurses);
                updatedMap[member] = updatedMember;
                return p.copyWith(partyPurse: updatedReserve, memberPurses: updatedMap);

              case 6:
                // Disperse coins from reserve (internal conservation: 0 external net)
                // Mode A: with reserve share. Mode B: members only.
                final activeRoster = p.partyRoster.activeValues.toList();
                if (activeRoster.isEmpty) return p;
                final reserveBal = signedBalance(p.partyPurse, denom);
                if (reserveBal <= 0) return p;
                final disperseAmount = 1 + rng.nextInt(reserveBal);
                final includeReserveShare = rng.nextBool();
                final totalShares = activeRoster.length + (includeReserveShare ? 1 : 0);
                final share = disperseAmount ~/ totalShares;
                if (share <= 0) return p;
                final distributedToMembers = share * activeRoster.length;

                final updatedReserve = withdrawHelper(p.partyPurse, denom, distributedToMembers, targetReplicaId);
                final updatedMap = Map<String, PartyPurse>.from(p.memberPurses);
                for (final m in activeRoster) {
                  final curM = updatedMap[m] ?? const PartyPurse.empty();
                  updatedMap[m] = depositHelper(curM, denom, share, targetReplicaId);
                }
                return p.copyWith(partyPurse: updatedReserve, memberPurses: updatedMap);

              case 7:
                // Add or Re-add member to roster
                return p.copyWith(
                  partyRoster: p.partyRoster.add(member, member, targetClock.nextTimestamp()),
                );

              case 8:
                // Remove member from roster (moves member's entire balance to reserve in same transform)
                final memberPurse = p.memberPurses[member];
                var updatedReserve = p.partyPurse;
                final updatedPurses = Map<String, PartyPurse>.from(p.memberPurses);
                if (memberPurse != null && !memberPurse.isEmpty) {
                  for (final d in denominations) {
                    final dBal = signedBalance(memberPurse, d);
                    if (dBal > 0) {
                      updatedReserve = depositHelper(updatedReserve, d, dBal, targetReplicaId);
                      updatedPurses[member] = withdrawHelper(updatedPurses[member] ?? memberPurse, d, dBal, targetReplicaId);
                    }
                  }
                }
                final updatedRoster = p.partyRoster.remove(member, targetClock.nextTimestamp());
                return p.copyWith(
                  partyRoster: updatedRoster,
                  partyPurse: updatedReserve,
                  memberPurses: updatedPurses,
                );

              default:
                return p;
            }
          }

          if (replicaChoice == 0) {
            repA = mutate(repA);
          } else if (replicaChoice == 1) {
            repB = mutate(repB);
          } else {
            repC = mutate(repC);
          }

          // Random intermediate sync (including concurrent edit on member being removed)
          if (rng.nextBool()) {
            final syncKind = rng.nextInt(4);
            if (syncKind == 0) repB = repB.merge(repA);
            if (syncKind == 1) repC = repC.merge(repB);
            if (syncKind == 2) repA = repA.merge(repC);
            if (syncKind == 3) {
              // Concurrent edit on member being removed:
              // repA removes member, while repB deposits coins onto that member
              final removeTarget = membersPool[rng.nextInt(membersPool.length)];
              repA = repA.copyWith(
                partyRoster: repA.partyRoster.remove(removeTarget, clockA.nextTimestamp()),
              );
              final delta = 1 + rng.nextInt(20);
              externalNet[denom] = externalNet[denom]! + delta;
              final cur = repB.memberPurses[removeTarget] ?? const PartyPurse.empty();
              final updatedMap = Map<String, PartyPurse>.from(repB.memberPurses);
              updatedMap[removeTarget] = depositHelper(cur, denom, delta, repIdB);
              repB = repB.copyWith(memberPurses: updatedMap);
            }
          }
        }

        // Deliver resulting profiles to each other in random order with duplicates
        final deliveryList = [repA, repB, repC, repA, repB, repC];
        deliveryList.shuffle(rng);

        var converged = deliveryList.first;
        for (final p in deliveryList.skip(1)) {
          converged = converged.merge(p);
        }

        repA = repA.merge(converged);
        repB = repB.merge(converged);
        repC = repC.merge(converged);

        // (a) All replicas converge to equal profiles
        expect(repA, equals(repB), reason: 'Seed $seed: Replicas A and B must converge to equal profiles');
        expect(repB, equals(repC), reason: 'Seed $seed: Replicas B and C must converge to equal profiles');

        // (b) Conservation on signed values:
        // reserve plus all member counters (on and off the roster) equals external deposits minus withdrawals
        for (final d in denominations) {
          int memberSum = 0;
          for (final mPurse in converged.memberPurses.values) {
            memberSum += signedBalance(mPurse, d);
          }
          final totalCoins = signedBalance(converged.partyPurse, d) + memberSum;
          expect(
            totalCoins,
            equals(externalNet[d]),
            reason: 'Seed $seed: Conservation violated for denomination $d. Total $totalCoins != Expected ${externalNet[d]}',
          );
        }

        // (c) The ledger view hides no coins:
        // displayed reserve plus displayed roster members equals the signed total whenever no counter is negative
        final sessionView = buildSessionView(converged);
        bool hasNegativeCounter = false;
        for (final d in denominations) {
          if (signedBalance(converged.partyPurse, d) < 0) {
            hasNegativeCounter = true;
            break;
          }
          for (final mPurse in converged.memberPurses.values) {
            if (signedBalance(mPurse, d) < 0) {
              hasNegativeCounter = true;
              break;
            }
          }
        }

        if (!hasNegativeCounter) {
          for (final d in denominations) {
            int displayedMemberSum = 0;
            for (final mPurse in sessionView.memberPurses.values) {
              displayedMemberSum += mPurse.getBalance(d);
            }
            final displayedTotal = sessionView.partyPurse.getBalance(d) + displayedMemberSum;
            expect(
              displayedTotal,
              equals(externalNet[d]),
              reason: 'Seed $seed: Ledger view hid coins for denomination $d. Displayed $displayedTotal != Expected ${externalNet[d]}',
            );
          }
        }
      }
    });
  });
}
