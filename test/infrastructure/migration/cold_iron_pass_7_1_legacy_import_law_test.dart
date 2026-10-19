import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/party_ledger_legacy_import.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  group('Cold Iron Birdcage: Pass 7.1 — Legacy Import Law Suite (Q3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const denominations = ['cp', 'sp', 'ep', 'gp', 'pp'];
    final recon = RoomStateReconciliationService();

    test('Legacy Import Law: 220 random seeds satisfy confluence, no double counting, and no roster pruning of active user additions', () async {
      const totalSeeds = 220;

      for (int seed = 1; seed <= totalSeeds; seed++) {
        final rng = Random(seed + 3000);
        final roomCode = 'ROOM_$seed';

        final charPool = [
          {'name': 'Aria', 'slug': 'aria'},
          {'name': 'Boromir', 'slug': 'boromir'},
          {'name': 'Cyrus', 'slug': 'cyrus'},
          {'name': 'Daelen', 'slug': 'daelen'},
          {'name': 'Elena', 'slug': 'elena'},
          {'name': 'Faramir', 'slug': 'faramir'},
        ];

        // 1. Build random telemetry
        final partyTelemetry = <String, dynamic>{};
        for (final c in charPool) {
          partyTelemetry[c['slug']!] = {
            'id': c['slug'],
            'name': c['name'],
            'characterClass': 'Fighter',
            'currentHp': 20,
            'maxHp': 20,
          };
        }

        // 2. Build random roster (subset of charPool)
        final rosterCharCount = 1 + rng.nextInt(3); // 1 to 3 characters
        final rosterChars = charPool.take(rosterCharCount).toList();
        final characterRoster = rosterChars.map((c) => c['name']!).toList();

        // 3. Build random reserve and member purses
        final expectedReserveScalars = <String, int>{};
        final legacyPartyPurse = <String, dynamic>{};
        for (final d in denominations) {
          final scalarVal = rng.nextInt(100);
          expectedReserveScalars[d] = scalarVal;
          legacyPartyPurse[d] = scalarVal;
        }

        final expectedMemberScalars = <String, Map<String, int>>{};
        final legacyMemberPurses = <String, dynamic>{};
        for (final c in rosterChars) {
          final slug = c['slug']!;
          final memberScalars = <String, int>{};
          for (final d in denominations) {
            memberScalars[d] = rng.nextInt(50);
          }
          expectedMemberScalars[slug] = memberScalars;
          legacyMemberPurses[slug] = Map<String, dynamic>.from(memberScalars);
        }

        final legacyDoc = <String, dynamic>{
          'roomCode': roomCode,
          'partyTelemetry': partyTelemetry,
          'characterRoster': characterRoster,
          'partyPurse': legacyPartyPurse,
          'memberPurses': legacyMemberPurses,
        };

        // Initialize 2 replicas
        final repIdA = ReplicaId('rep_a_$seed');
        final repIdB = ReplicaId('rep_b_$seed');

        final clockA = StatefulHlcClock(replicaId: repIdA);
        final clockB = StatefulHlcClock(replicaId: repIdB);

        final repoA = _InMemoryCampaignRepo();
        final repoB = _InMemoryCampaignRepo();

        final profileServiceA = CampaignProfileService(repo: repoA, clock: clockA, replicaId: repIdA);
        final profileServiceB = CampaignProfileService(repo: repoB, clock: clockB, replicaId: repIdB);

        final regA = CampaignRegistryService.newInstance();
        final regB = CampaignRegistryService.newInstance();

        final serviceA = PartyRoomService(
          replicaId: repIdA,
          clock: clockA,
          registry: regA,
          campaignProfileService: profileServiceA,
        );
        final serviceB = PartyRoomService(
          replicaId: repIdB,
          clock: clockB,
          registry: regB,
          campaignProfileService: profileServiceB,
        );

        // Setup campaign on A
        await serviceA.createCampaign(
          campaignName: 'Campaign $seed',
          customRoomCode: roomCode,
          playerName: 'DM_A',
        );
        final profileA0 = repoA.allProfiles.first;
        final profileId = profileA0.id;

        // Step 1: Import on Replica A
        await repoA.updateProfile(profileId, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: legacyDoc,
            clock: clockA,
          );
        });

        // Sync A to B
        final profAAfterFirstImport = (await repoA.getProfile(profileId))!;
        final joinB0 = recon.reconcileProfileSafely(
          local: CampaignProfile.raw(
            id: profileId,
            nameRegister: CrdtLwwRegister(value: profAAfterFirstImport.name, timestamp: clockB.nextTimestamp()),
            edition: profAAfterFirstImport.edition,
            createdAt: profAAfterFirstImport.createdAt,
            lastPlayedAt: profAAfterFirstImport.lastPlayedAt,
            roomState: RoomNodeState(
              roomId: profAAfterFirstImport.roomState.roomId,
              roomCode: roomCode,
              titleTimestamp: clockB.nextTimestamp(),
            ),
            partyPurse: const PartyPurse.empty(),
            memberPurses: const {},
            partyRoster: const CrdtOrSet<String>.empty(),
            pinnedRules: const CrdtOrSet<String>.empty(),
            notesRegister: CrdtLwwRegister(value: '', timestamp: clockB.nextTimestamp()),
            changeLog: const [],
          ),
          remote: profAAfterFirstImport,
        );
        expect(joinB0.hasFaults, isFalse);
        await repoB.putProfile(joinB0.profile);

        Future<void> syncReplicas(
          _InMemoryCampaignRepo fromRepo,
          _InMemoryCampaignRepo toRepo,
          StatefulHlcClock toClock,
        ) async {
          final from = await fromRepo.getProfile(profileId);
          final to = await toRepo.getProfile(profileId);
          if (from == null || to == null) return;

          final remoteHlcs = <HybridLogicalClock>[
            from.nameRegister.timestamp,
            from.notesRegister.timestamp,
            from.roomState.titleRegister.timestamp,
            from.roomState.descriptionRegister.timestamp,
            for (final reg in from.partyRoster.items.values) reg.timestamp,
            for (final ts in from.partyRoster.tombstones.values) ts,
          ];
          toClock.observeAllRemote(remoteHlcs);

          final res = recon.reconcileProfileSafely(local: to, remote: from);
          expect(res.hasFaults, isFalse);
          await toRepo.putProfile(res.profile);
        }

        // Step 2: Random number of roster adds and removes through PartyRoomService on A and B,
        // including characters NOT on the legacy roster
        final expectedRoster = Set<String>.from(profAAfterFirstImport.partyRoster.activeValues);
        final allTestChars = [...charPool.map((c) => c['slug']!)];

        final numOps = 5 + rng.nextInt(10);
        for (int op = 0; op < numOps; op++) {
          final onA = rng.nextBool();
          final targetService = onA ? serviceA : serviceB;

          final charToModify = allTestChars[rng.nextInt(allTestChars.length)];
          final doAdd = expectedRoster.contains(charToModify) ? rng.nextBool() : true;

          if (doAdd) {
            await targetService.addCharacterToRoster(
              roomCode: roomCode,
              characterName: charToModify,
              playerName: 'Player',
            );
            expectedRoster.add(charToModify);
          } else {
            await targetService.removeCharacterFromRoster(
              roomCode: roomCode,
              characterName: charToModify,
              playerName: 'Player',
            );
            expectedRoster.remove(charToModify);
          }

          // Sync both ways so subsequent operations are causally ordered
          await syncReplicas(repoA, repoB, clockB);
          await syncReplicas(repoB, repoA, clockA);
        }

        // Final pre-import sync so both replicas are coordinated
        await syncReplicas(repoA, repoB, clockB);
        await syncReplicas(repoB, repoA, clockA);

        // Step 3: Import again on A and on B
        final profABeforeSecondImport = (await repoA.getProfile(profileId))!;
        final profBBeforeFirstImport = (await repoB.getProfile(profileId))!;
        final rosterBBeforeImport = Set<String>.from(profBBeforeFirstImport.partyRoster.activeValues);

        // Second import on A
        final profAAfterSecondImport = await repoA.updateProfile(profileId, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: legacyDoc,
            clock: clockA,
          );
        });

        // First import on B
        final profBAfterFirstImport = await repoB.updateProfile(profileId, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: legacyDoc,
            clock: clockB,
          );
        });

        expect(
          profAAfterSecondImport,
          equals(profABeforeSecondImport),
          reason: 'Seed $seed: Second import on Replica A must change nothing',
        );

        // (b) B\'s first import removes nothing that A or B added through PartyRoomService
        for (final item in rosterBBeforeImport) {
          expect(
            profBAfterFirstImport.partyRoster.activeValues,
            contains(item),
            reason: 'Seed $seed: B\'s first import must not remove $item added by A or B',
          );
        }

        // Step 4: Sync both ways
        await syncReplicas(repoA, repoB, clockB);
        await syncReplicas(repoB, repoA, clockA);

        final finalA = (await repoA.getProfile(profileId))!;
        final finalB = (await repoB.getProfile(profileId))!;

        // (c) Final rosters are equal and contain every character added after the import and not removed by a user operation
        expect(
          finalA.partyRoster.activeValues.toSet(),
          equals(finalB.partyRoster.activeValues.toSet()),
          reason: 'Seed $seed: Final rosters on A and B must converge to equal sets',
        );
        expect(
          finalA.partyRoster.activeValues.toSet(),
          equals(expectedRoster),
          reason: 'Seed $seed: Final roster must equal expected roster',
        );

        // (d) No character\'s coins count twice
        final importKey = 'legacy-import:${roomCode.trim().toUpperCase()}';
        for (final entry in expectedMemberScalars.entries) {
          final slug = entry.key;
          final purse = finalA.memberPurses[slug];
          if (purse != null) {
            for (final d in denominations) {
              final counter = purse.denominationCounters[d];
              if (counter != null) {
                // The import key should have exactly the expected scalar, never 2x
                final importedPositive = counter.positive[importKey] ?? 0;
                expect(
                  importedPositive,
                  equals(entry.value[d] ?? 0),
                  reason: 'Seed $seed: Member $slug denom $d was double-counted! Positive is $importedPositive != ${entry.value[d]}',
                );
              }
            }
          }
        }
      }
    });
  });
}
