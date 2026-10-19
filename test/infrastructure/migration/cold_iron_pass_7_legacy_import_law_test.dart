import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/party_ledger_legacy_import.dart';

void main() {
  group('Cold Iron Birdcage: Pass 7 — Legacy Import Law Suite (P5)', () {
    const denominations = ['cp', 'sp', 'ep', 'gp', 'pp'];

    test('Legacy Import Law: 250 random seeds satisfy confluence, scalar fidelity, deduplication, and idempotence', () {
      const totalSeeds = 250;

      for (int seed = 0; seed < totalSeeds; seed++) {
        final rng = Random(seed + 2000);
        final roomCode = 'ROOM_$seed';

        // Available characters
        final charPool = [
          {'name': 'Aria', 'slug': 'aria'},
          {'name': 'Boromir', 'slug': 'boromir'},
          {'name': 'Cyrus', 'slug': 'cyrus'},
          {'name': 'Daelen', 'slug': 'daelen'},
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

        // 2. Build random roster
        final rosterCharCount = 1 + rng.nextInt(charPool.length);
        final rosterChars = charPool.take(rosterCharCount).toList();
        final characterRoster = rosterChars.map((c) => c['name']!).toList();

        // 3. Build random partyPurse (scalars and optional counter-form F1 shadow)
        final expectedReserveScalars = <String, int>{};
        final legacyPartyPurse = <String, dynamic>{};
        final isCounterForm = rng.nextBool();

        for (final d in denominations) {
          final scalarVal = rng.nextInt(200);
          expectedReserveScalars[d] = scalarVal;
          legacyPartyPurse[d] = scalarVal;

          if (isCounterForm) {
            // Shadow with older/stale counter map
            legacyPartyPurse['${d}Counter'] = {
              'positive': {'stale_node': scalarVal ~/ 2},
              'negative': {},
            };
          }
        }

        // 4. Build random memberPurses
        // Characters may appear under slug, name, or both
        final expectedMemberScalars = <String, Map<String, int>>{};
        final legacyMemberPurses = <String, dynamic>{};

        for (final c in rosterChars) {
          final slug = c['slug']!;
          final name = c['name']!;

          final keyChoice = rng.nextInt(3); // 0: slug, 1: name, 2: both
          final memberScalars = <String, int>{};
          for (final d in denominations) {
            memberScalars[d] = rng.nextInt(100);
          }
          expectedMemberScalars[slug] = memberScalars;

          final memberMap = Map<String, dynamic>.from(memberScalars);
          if (isCounterForm) {
            memberMap['gpCounter'] = {'positive': {'stale': 5}, 'negative': {}};
          }

          if (keyChoice == 0) {
            legacyMemberPurses[slug] = memberMap;
          } else if (keyChoice == 1) {
            legacyMemberPurses[name] = memberMap;
          } else {
            // Both keys present
            final differ = rng.nextBool();
            legacyMemberPurses[slug] = memberMap;
            if (differ) {
              // Different scalars for name: slug should be prioritized
              final nameMap = <String, dynamic>{'gp': memberScalars['gp']! + 10};
              legacyMemberPurses[name] = nameMap;
            } else {
              legacyMemberPurses[name] = Map<String, dynamic>.from(memberMap);
            }
          }
        }

        // Add an unrostered member purse (which should be skipped to prevent F2 double-counting)
        if (rosterCharCount < charPool.length) {
          final unrosteredChar = charPool.last;
          legacyMemberPurses[unrosteredChar['slug']!] = {'gp': 77, 'sp': 22};
        }

        final legacyDoc = <String, dynamic>{
          'roomCode': roomCode,
          'partyTelemetry': partyTelemetry,
          'characterRoster': characterRoster,
          'partyPurse': legacyPartyPurse,
          'memberPurses': legacyMemberPurses,
        };

        // Initialize 3 replicas
        final repIdA = ReplicaId('rep_a_$seed');
        final repIdB = ReplicaId('rep_b_$seed');
        final repIdC = ReplicaId('rep_c_$seed');

        final clockA = StatefulHlcClock(replicaId: repIdA);
        final clockB = StatefulHlcClock(replicaId: repIdB);
        final clockC = StatefulHlcClock(replicaId: repIdC);

        final genesisProfile = CampaignProfile.defaultProfile(
          id: 'camp_import_$seed',
          nodeId: 'node_init',
          clock: StatefulHlcClock(replicaId: ReplicaId('node_init')),
        ).copyWith(
          roomState: RoomNodeState(roomId: 'r_$seed', roomCode: roomCode),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
        );

        // Import on N=3 replicas
        final importedA = PartyLedgerLegacyImport.importLegacyLedger(
          profile: genesisProfile,
          rawDoc: legacyDoc,
          clock: clockA,
        );
        final importedB = PartyLedgerLegacyImport.importLegacyLedger(
          profile: genesisProfile,
          rawDoc: legacyDoc,
          clock: clockB,
        );
        final importedC = PartyLedgerLegacyImport.importLegacyLedger(
          profile: genesisProfile,
          rawDoc: legacyDoc,
          clock: clockC,
        );

        // Merge N replicas together
        final merged = importedA.merge(importedB).merge(importedC);

        // Import once on a single replica
        final singleImportClock = StatefulHlcClock(replicaId: ReplicaId('rep_single_$seed'));
        final importedOnce = PartyLedgerLegacyImport.importLegacyLedger(
          profile: genesisProfile,
          rawDoc: legacyDoc,
          clock: singleImportClock,
        );

        // (a) Import on N replicas then merge equals import once
        expect(
          merged.partyPurse,
          equals(importedOnce.partyPurse),
          reason: 'Seed $seed: Merged partyPurse across N replicas must equal import once',
        );
        expect(
          merged.memberPurses,
          equals(importedOnce.memberPurses),
          reason: 'Seed $seed: Merged memberPurses across N replicas must equal import once',
        );
        expect(
          merged.partyRoster.activeValues.toSet(),
          equals(importedOnce.partyRoster.activeValues.toSet()),
          reason: 'Seed $seed: Merged roster across N replicas must equal import once',
        );

        // (b) Imported balances equal the scalars (not shaded by counter maps)
        for (final d in denominations) {
          expect(
            merged.partyPurse.getBalance(d),
            equals(expectedReserveScalars[d]),
            reason: 'Seed $seed: Reserve denomination $d must equal scalar balance',
          );
        }

        // (c) No character is counted twice & member scalars match
        for (final c in rosterChars) {
          final slug = c['slug']!;
          final memberPurse = merged.memberPurses[slug];
          expect(memberPurse, isNotNull, reason: 'Seed $seed: Member $slug must be imported');

          final expectedScalars = expectedMemberScalars[slug]!;
          for (final d in denominations) {
            expect(
              memberPurse!.getBalance(d),
              equals(expectedScalars[d] ?? 0),
              reason: 'Seed $seed: Member $slug denom $d must match scalar value',
            );
          }
        }

        // Unrostered member must not be in memberPurses (skips unrostered to prevent F2 double count)
        if (rosterCharCount < charPool.length) {
          final unrosteredSlug = charPool.last['slug']!;
          expect(
            merged.memberPurses.containsKey(unrosteredSlug),
            isFalse,
            reason: 'Seed $seed: Unrostered member $unrosteredSlug must not be imported',
          );
        }

        // (d) Re-running the import changes nothing (Idempotent)
        final reimported = PartyLedgerLegacyImport.importLegacyLedger(
          profile: importedOnce,
          rawDoc: legacyDoc,
          clock: singleImportClock,
        );
        expect(
          reimported,
          equals(importedOnce),
          reason: 'Seed $seed: Re-running import on already imported profile must change nothing',
        );
      }
    });
  });
}
