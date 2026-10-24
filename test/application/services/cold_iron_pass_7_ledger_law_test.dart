import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;
  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id];
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}

Character _createHero(String slug, String name, {PartyPurse purse = const PartyPurse.empty()}) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    purse: purse,
    speciesRef: const EntityReference.empty(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
    progression: const CharacterProgression(classes: []),
    baseScores: const AbilityScores.standardArray(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
    sl.reset();
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
    CampaignProfileService.resetForTesting();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  group('Cold Iron Birdcage: Pass 7.1 — Ledger Law Suite through Live Path (Q5)', () {
    const denominations = ['cp', 'sp', 'ep', 'gp', 'pp'];

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

    test('Ledger Law: 350 random seeds through PartyRoomService converge, conserve signed totals, and hide no coins', () async {
      const totalSeeds = 350;
      final recon = RoomStateReconciliationService();

      for (int seed = 0; seed < totalSeeds; seed++) {
        final rng = Random(seed + 1000);
        final roomCode = 'ROOM$seed';

        final repIdA = ReplicaId('node_a_$seed');
        final repIdB = ReplicaId('node_b_$seed');
        final repIdC = ReplicaId('node_c_$seed');

        final clockA = StatefulHlcClock(replicaId: repIdA);
        final clockB = StatefulHlcClock(replicaId: repIdB);
        final clockC = StatefulHlcClock(replicaId: repIdC);

        final repoA = _InMemoryCampaignRepo();
        final repoB = _InMemoryCampaignRepo();
        final repoC = _InMemoryCampaignRepo();

        final profileServiceA = CampaignProfileService(repo: repoA, clock: clockA, replicaId: repIdA);
        final profileServiceB = CampaignProfileService(repo: repoB, clock: clockB, replicaId: repIdB);
        final profileServiceC = CampaignProfileService(repo: repoC, clock: clockC, replicaId: repIdC);

        final serviceA = PartyRoomService(
          replicaId: repIdA,
          clock: clockA,
          campaignProfileService: profileServiceA,
        );
        final serviceB = PartyRoomService(
          replicaId: repIdB,
          clock: clockB,
          campaignProfileService: profileServiceB,
        );
        final serviceC = PartyRoomService(
          replicaId: repIdC,
          clock: clockC,
          campaignProfileService: profileServiceC,
        );

        // 1. Initialize room on Replica A
        await serviceA.createCampaign(
          campaignName: 'Campaign $seed',
          customRoomCode: roomCode,
          playerName: 'DM_A',
        );
        final profileA0 = repoA.allProfiles.first;
        final profileId = profileA0.id;

        // Initialize Replica B and C with matching ID via safe reconciliation
        final joinB0 = recon.reconcileProfileSafely(
          local: CampaignProfile.raw(
            id: profileId,
            nameRegister: CrdtLwwRegister(value: profileA0.name, timestamp: clockB.nextTimestamp()),
            edition: profileA0.edition,
            createdAt: profileA0.createdAt,
            lastPlayedAt: profileA0.lastPlayedAt,
            roomState: RoomNodeState(
              roomId: 'room_$roomCode',
              roomCode: roomCode,
              title: 'Title',
              titleTimestamp: clockB.nextTimestamp(),
            ),
            partyPurse: const PartyPurse.empty(),
            memberPurses: const {},
            partyRoster: const CrdtOrSet<String>.empty(),
            pinnedRules: const CrdtOrSet<String>.empty(),
            notesRegister: CrdtLwwRegister(value: '', timestamp: clockB.nextTimestamp()),
            changeLog: const [],
          ),
          remote: profileA0,
        );
        expect(joinB0.hasFaults, isFalse);
        await repoB.putProfile(joinB0.profile);

        final joinC0 = recon.reconcileProfileSafely(
          local: CampaignProfile.raw(
            id: profileId,
            nameRegister: CrdtLwwRegister(value: profileA0.name, timestamp: clockC.nextTimestamp()),
            edition: profileA0.edition,
            createdAt: profileA0.createdAt,
            lastPlayedAt: profileA0.lastPlayedAt,
            roomState: RoomNodeState(
              roomId: 'room_$roomCode',
              roomCode: roomCode,
              title: 'Title',
              titleTimestamp: clockC.nextTimestamp(),
            ),
            partyPurse: const PartyPurse.empty(),
            memberPurses: const {},
            partyRoster: const CrdtOrSet<String>.empty(),
            pinnedRules: const CrdtOrSet<String>.empty(),
            notesRegister: CrdtLwwRegister(value: '', timestamp: clockC.nextTimestamp()),
            changeLog: const [],
          ),
          remote: profileA0,
        );
        expect(joinC0.hasFaults, isFalse);
        await repoC.putProfile(joinC0.profile);

        final externalNet = <String, int>{
          'cp': 0, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 0,
        };
        final seededSlugs = <String>{};
        final membersPool = ['aria', 'boromir', 'cyrus', 'daelen', 'elena'];

        // Each member has a canonical opening purse on their character sheet
        final memberCanonicalPurses = <String, PartyPurse>{
          'aria': PartyPurse(gp: 20 + rng.nextInt(30), sp: rng.nextInt(20)),
          'boromir': PartyPurse(gp: 10 + rng.nextInt(20), cp: rng.nextInt(50)),
          'cyrus': PartyPurse(ep: 5 + rng.nextInt(15), gp: rng.nextInt(25)),
          'daelen': PartyPurse(pp: 2 + rng.nextInt(5), sp: rng.nextInt(30)),
          'elena': PartyPurse(cp: 50 + rng.nextInt(50), gp: rng.nextInt(20)),
        };

        // Helper to sync from one replica repo to another
        Future<void> syncReplicas(_InMemoryCampaignRepo fromRepo, _InMemoryCampaignRepo toRepo) async {
          final from = await fromRepo.getProfile(profileId);
          final to = await toRepo.getProfile(profileId);
          if (from == null || to == null) return;
          final res = recon.reconcileProfileSafely(local: to, remote: from);
          expect(res.hasFaults, isFalse, reason: 'Sync reconciliation must have zero faults');
          await toRepo.putProfile(res.profile);
        }

        // Link initial roster members
        for (final m in ['aria', 'boromir']) {
          final hero = _createHero(m, m.toUpperCase(), purse: memberCanonicalPurses[m]!);
          seededSlugs.add(m);
          for (final d in denominations) {
            externalNet[d] = externalNet[d]! + memberCanonicalPurses[m]!.getBalance(d);
          }
          await serviceA.linkCharacterToCampaign(
            roomCode: roomCode,
            character: hero,
          );
        }
        await syncReplicas(repoA, repoB);
        await syncReplicas(repoA, repoC);

        final numOps = 20 + rng.nextInt(15);

        for (int op = 0; op < numOps; op++) {
          final replicaChoice = rng.nextInt(3);
          final targetService = replicaChoice == 0
              ? serviceA
              : (replicaChoice == 1 ? serviceB : serviceC);
          final targetRepo = replicaChoice == 0
              ? repoA
              : (replicaChoice == 1 ? repoB : repoC);

          final denom = denominations[rng.nextInt(denominations.length)];
          final member = membersPool[rng.nextInt(membersPool.length)];

          final action = rng.nextInt(10);
          switch (action) {
            case 0:
              // External deposit to reserve
              final delta = 1 + rng.nextInt(50);
              externalNet[denom] = externalNet[denom]! + delta;
              await targetService.depositCoins(
                roomCode: roomCode,
                playerName: 'Player',
                cp: denom == 'cp' ? delta : 0,
                sp: denom == 'sp' ? delta : 0,
                ep: denom == 'ep' ? delta : 0,
                gp: denom == 'gp' ? delta : 0,
                pp: denom == 'pp' ? delta : 0,
              );

            case 1:
              // External withdrawal from reserve (including overdraft)
              final delta = 1 + rng.nextInt(50);
              externalNet[denom] = externalNet[denom]! - delta;
              await targetService.withdrawCoins(
                roomCode: roomCode,
                playerName: 'Player',
                cp: denom == 'cp' ? delta : 0,
                sp: denom == 'sp' ? delta : 0,
                ep: denom == 'ep' ? delta : 0,
                gp: denom == 'gp' ? delta : 0,
                pp: denom == 'pp' ? delta : 0,
              );

            case 2:
              // Transfer from member to reserve (internal movement: 0 external net)
              final curProf = (await targetRepo.getProfile(profileId))!;
              final curMemberPurse = curProf.memberPurses[member] ?? const PartyPurse.empty();
              final bal = signedBalance(curMemberPurse, denom);
              if (bal > 0) {
                final amount = 1 + rng.nextInt(bal);
                await targetService.transferMemberToReserve(
                  roomCode: roomCode,
                  characterName: member,
                  performedBy: 'DM',
                  cp: denom == 'cp' ? amount : 0,
                  sp: denom == 'sp' ? amount : 0,
                  ep: denom == 'ep' ? amount : 0,
                  gp: denom == 'gp' ? amount : 0,
                  pp: denom == 'pp' ? amount : 0,
                );
              }

            case 3:
              // Transfer from reserve to member (internal movement: 0 external net)
              final curProf = (await targetRepo.getProfile(profileId))!;
              final reserveBal = signedBalance(curProf.partyPurse, denom);
              if (reserveBal > 0) {
                final amount = 1 + rng.nextInt(reserveBal);
                await targetService.transferReserveToMember(
                  roomCode: roomCode,
                  characterName: member,
                  performedBy: 'DM',
                  cp: denom == 'cp' ? amount : 0,
                  sp: denom == 'sp' ? amount : 0,
                  ep: denom == 'ep' ? amount : 0,
                  gp: denom == 'gp' ? amount : 0,
                  pp: denom == 'pp' ? amount : 0,
                );
              }

            case 4:
              // Disperse coins (both modes: includePartyReserve true/false, vault vs external)
              final curProf = (await targetRepo.getProfile(profileId))!;
              final activeRoster = curProf.partyRoster.activeValues.toList();
              if (activeRoster.isNotEmpty) {
                final isVault = rng.nextBool();
                final includeReserve = rng.nextBool();
                final delta = 1 + rng.nextInt(30);
                final purseToDisperse = PartyPurse.fromCounters({
                  denom: PnCounter(positive: {'reward': delta}),
                });
                if (!isVault) {
                  externalNet[denom] = externalNet[denom]! + delta;
                }
                await targetService.disperseCoinsToParty(
                  roomCode: roomCode,
                  purseToDisperse: purseToDisperse,
                  recipientCharacters: activeRoster,
                  performedBy: 'DM',
                  includePartyReserve: includeReserve,
                  isVaultDispersal: isVault,
                );
              }

            case 5:
              // Add or re-add member
              await targetService.addCharacterToRoster(
                roomCode: roomCode,
                characterName: member,
                playerName: 'DM',
              );

            case 6:
              // Remove member from roster (moves member coins to reserve in same transform)
              await targetService.removeCharacterFromRoster(
                roomCode: roomCode,
                characterName: member,
                playerName: 'DM',
              );

            case 7:
              // linkCharacterToCampaign with character's canonical purse
              // or random purse on subsequent link
              final curProf = (await targetRepo.getProfile(profileId))!;
              final isFirstSeedGlobally = !seededSlugs.contains(member);
              final heroPurse = curProf.memberPurses.containsKey(member)
                  ? PartyPurse.fromCounters({
                      denom: PnCounter(positive: {'random_subsequent': rng.nextInt(100)}),
                    })
                  : memberCanonicalPurses[member]!;
              final hero = _createHero(member, member.toUpperCase(), purse: heroPurse);
              if (!curProf.memberPurses.containsKey(member) && isFirstSeedGlobally) {
                seededSlugs.add(member);
                for (final d in denominations) {
                  externalNet[d] = externalNet[d]! + memberCanonicalPurses[member]!.getBalance(d);
                }
              }
              await targetService.linkCharacterToCampaign(
                roomCode: roomCode,
                character: hero,
              );

            case 8:
              // updateCharacterTelemetry with random Character.purse
              // Invariant: Telemetry NEVER alters memberPurses (0 net change)
              final bogusBal = rng.nextInt(500);
              final bogusPurse = PartyPurse.fromCounters({
                denom: PnCounter(positive: {'bogus': bogusBal}),
              });
              final heroTelemetry = _createHero(member, member.toUpperCase(), purse: bogusPurse);
              await targetService.updateCharacterTelemetry(
                roomCode: roomCode,
                character: heroTelemetry,
              );

            case 9:
              // Concurrent edit on member being removed:
              // Replica A removes member while Replica B transfers reserve to member
              await serviceA.removeCharacterFromRoster(
                roomCode: roomCode,
                characterName: member,
                playerName: 'DM_A',
              );
              final curB = (await repoB.getProfile(profileId))!;
              final rBal = signedBalance(curB.partyPurse, denom);
              if (rBal > 0) {
                final amt = 1 + rng.nextInt(rBal);
                await serviceB.transferReserveToMember(
                  roomCode: roomCode,
                  characterName: member,
                  performedBy: 'DM_B',
                  cp: denom == 'cp' ? amt : 0,
                  sp: denom == 'sp' ? amt : 0,
                  ep: denom == 'ep' ? amt : 0,
                  gp: denom == 'gp' ? amt : 0,
                  pp: denom == 'pp' ? amt : 0,
                );
              }
          }

          // Random intermediate sync (prob ~ 0.5)
          if (rng.nextBool()) {
            final syncKind = rng.nextInt(6);
            if (syncKind == 0) await syncReplicas(repoA, repoB);
            if (syncKind == 1) await syncReplicas(repoB, repoC);
            if (syncKind == 2) await syncReplicas(repoC, repoA);
            if (syncKind == 3) await syncReplicas(repoB, repoA);
            if (syncKind == 4) await syncReplicas(repoC, repoB);
            if (syncKind == 5) await syncReplicas(repoA, repoC);
          }
        }

        // Deliver resulting profiles in random order with duplicates through reconcileProfileSafely
        final deliveryQueue = [
          (repoA, repoB),
          (repoB, repoC),
          (repoC, repoA),
          (repoB, repoA),
          (repoC, repoB),
          (repoA, repoC),
          (repoA, repoB),
          (repoB, repoC),
          (repoC, repoA),
        ];
        deliveryQueue.shuffle(rng);

        for (int round = 0; round < 2; round++) {
          for (final pair in deliveryQueue) {
            await syncReplicas(pair.$1, pair.$2);
          }
        }

        final finalA = (await repoA.getProfile(profileId))!;
        final finalB = (await repoB.getProfile(profileId))!;
        final finalC = (await repoC.getProfile(profileId))!;

        // (a) All replicas converge to equal profiles with zero faults
        expect(finalA, equals(finalB), reason: 'Seed $seed: Replicas A and B must converge to equal profiles');
        expect(finalB, equals(finalC), reason: 'Seed $seed: Replicas B and C must converge to equal profiles');

        // (b) Signed conservation: reserve plus all member counters equals seeds plus external deposits minus withdrawals
        for (final d in denominations) {
          int memberSum = 0;
          for (final mPurse in finalA.memberPurses.values) {
            memberSum += signedBalance(mPurse, d);
          }
          final totalCoins = signedBalance(finalA.partyPurse, d) + memberSum;
          expect(
            totalCoins,
            equals(externalNet[d]),
            reason: 'Seed $seed: Conservation violated for denomination $d. Total $totalCoins != Expected ${externalNet[d]}',
          );
        }

        // (c) The ledger view hides no coins when no counter is negative
        final sessionView = buildSessionView(finalA);
        bool hasNegativeCounter = false;
        for (final d in denominations) {
          if (signedBalance(finalA.partyPurse, d) < 0) {
            hasNegativeCounter = true;
            break;
          }
          for (final mPurse in finalA.memberPurses.values) {
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
