import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_rules.dart';

String _tokId(int i) => 'tok_${i.toRadixString(16).padLeft(32, '0')}';
const _testMapSha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  group('Map slice 1.5: Token Rules Suite', () {
    test('TR1 (law over 500 seeds): canMoveToken matches independent reference predicate', () {
      int countDmTrue = 0;
      int countCharTrue = 0;
      int countCharFalse = 0;
      int countMinionTrue = 0;
      int countMinionFalse = 0;
      int countMonsterFalse = 0;
      int countBadSlugFalse = 0;

      for (int seed = 0; seed < 500; seed++) {
        final rand = Random(seed);

        // 1. Roster of 0 to 4 slugs
        final allSlugs = ['slug_a', 'slug_b', 'slug_c', 'slug_d'];
        final rosterCount = rand.nextInt(5);
        final rosterSlugs = allSlugs.take(rosterCount).toSet();

        const ts100 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        const ts150 = HybridLogicalClock(physicalTime: 150, logicalCounter: 0, nodeId: 'n1');
        const ts200 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');

        var roster = const CrdtOrSet<String>.empty();
        for (final s in rosterSlugs) {
          roster = roster.add(s, s, ts100);
        }

        // 2. Minions (0 to 4 active and some removed)
        var minions = const CrdtOrSet<dynamic>.empty();
        final activeMinionIds = <String>{};
        final totalMinions = rand.nextInt(5);
        for (int m = 0; m < totalMinions; m++) {
          final mId = 'minion_$m';
          minions = minions.add(mId, {'id': mId, 'name': 'Minion $m'}, ts100);
          activeMinionIds.add(mId);
        }
        // Maybe remove some
        final removedCount = rand.nextInt(3);
        for (int r = 0; r < removedCount; r++) {
          final rId = 'rem_minion_$r';
          minions = minions.add(rId, {'id': rId}, ts100);
          minions = minions.remove(rId, ts200);
        }

        // 3. Minion owners: random owners, including not on roster, of removed minions, and cleared
        var owners = const CrdtOrSet<String>.empty();
        final referenceOwners = <String, String?>{};
        for (int m = 0; m < totalMinions + removedCount; m++) {
          final mId = m < totalMinions ? 'minion_$m' : 'rem_minion_${m - totalMinions}';
          if (rand.nextBool()) {
            final chosen = rosterSlugs.isNotEmpty && rand.nextInt(4) != 0
                ? rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))
                : (rand.nextBool() ? 'off_roster_slug' : null);
            if (chosen != null) {
              owners = owners.add(mId, chosen, ts150);
              referenceOwners[mId] = chosen;
            } else {
              owners = owners.remove(mId, ts150);
              referenceOwners[mId] = null;
            }
          }
        }

        // 4. Combatants: 0 to 3
        var encounter = const CrdtOrSet<EncounterParticipant>.empty();
        final combatantIds = <String>{};
        final encCount = rand.nextInt(4);
        for (int e = 0; e < encCount; e++) {
          final pId = 'p_$e';
          combatantIds.add(pId);
          encounter = encounter.add(
            pId,
            EncounterParticipant(
              participantId: pId,
              entityLink: RoomEntityLink(entityId: pId, displayName: pId),
              currentHp: 10,
              maxHp: 10,
              defense: 10,
              initiativeScore: 10,
            ),
            ts100,
          );
        }

        // 5. Tokens: of all three kinds, including some that point at things that no longer exist
        final tokens = <MapToken>[];
        for (int t = 0; t < 6; t++) {
          final kind = MapTokenKind.values[rand.nextInt(MapTokenKind.values.length)];
          final String refId;
          switch (kind) {
            case MapTokenKind.character:
              refId = rand.nextBool() && rosterSlugs.isNotEmpty
                  ? rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))
                  : 'non_existent_char';
            case MapTokenKind.minion:
              refId = rand.nextBool() && activeMinionIds.isNotEmpty
                  ? activeMinionIds.elementAt(rand.nextInt(activeMinionIds.length))
                  : (rand.nextBool() ? 'rem_minion_0' : 'non_existent_minion');
            case MapTokenKind.monster:
              refId = rand.nextBool() && combatantIds.isNotEmpty
                  ? combatantIds.elementAt(rand.nextInt(combatantIds.length))
                  : 'non_existent_monster';
          }
          tokens.add(MapToken(
            id: _tokId(t + 1),
            mapSha256Hex: _testMapSha,
            kind: kind,
            refId: refId,
            label: 'T$t',
          ));
        }

        // Profile
        final profile = CampaignProfile.raw(
          id: 'camp_rules_$seed',
          nameRegister: const CrdtLwwRegister<String>(value: 'Camp', timestamp: ts100),
          notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: ts100),
          partyRoster: roster,
          minionOwners: owners,
          roomState: const RoomNodeState.empty().copyWith(
            activeEncounter: encounter,
            activeMinions: minions,
          ),
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
        );

        // Random actors: DM, a player with a roster slug, a player with a slug that isn't on the roster, a player with null
        final actors = <MapTokenActor>[
          const MapTokenActor.dm(),
          if (rosterSlugs.isNotEmpty) MapTokenActor.player(rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))),
          const MapTokenActor.player('off_roster_slug'),
          const MapTokenActor.player(null),
        ];

        for (final token in tokens) {
          for (final actor in actors) {
            final actual = canMoveToken(profile, token, actor);

            // Reference predicate (pure independent test logic)
            final bool expected;
            if (actor is DmActor) {
              expected = true;
              countDmTrue++;
            } else {
              final playerSlug = (actor as PlayerActor).rosterSlug;
              if (playerSlug == null || !rosterSlugs.contains(playerSlug)) {
                expected = false;
                countBadSlugFalse++;
              } else {
                switch (token.kind) {
                  case MapTokenKind.character:
                    expected = token.refId == playerSlug;
                    if (expected) {
                      countCharTrue++;
                    } else {
                      countCharFalse++;
                    }
                  case MapTokenKind.minion:
                    final isAct = activeMinionIds.contains(token.refId);
                    final owner = referenceOwners[token.refId];
                    expected = isAct && owner == playerSlug;
                    if (expected) {
                      countMinionTrue++;
                    } else {
                      countMinionFalse++;
                    }
                  case MapTokenKind.monster:
                    expected = false;
                    countMonsterFalse++;
                }
              }
            }

            expect(actual, equals(expected), reason: 'Mismatch for token $token and actor $actor on seed $seed');
          }
        }
      }

      // ignore: avoid_print
      print('TR1 Coverage Counts: DM_true=$countDmTrue, Char_true=$countCharTrue, Char_false=$countCharFalse, '
          'Minion_true=$countMinionTrue, Minion_false=$countMinionFalse, Monster_false=$countMonsterFalse, BadSlug_false=$countBadSlugFalse');

      expect(countDmTrue, greaterThanOrEqualTo(30));
      expect(countCharTrue, greaterThanOrEqualTo(30));
      expect(countCharFalse, greaterThanOrEqualTo(30));
      expect(countMinionTrue, greaterThanOrEqualTo(30));
      expect(countMinionFalse, greaterThanOrEqualTo(30));
      expect(countMonsterFalse, greaterThanOrEqualTo(30));
      expect(countBadSlugFalse, greaterThanOrEqualTo(30));
    });

    test('TR2 tokenInitials: examples and 200 random strings', () {
      expect(tokenInitials('Thorin Oakenshield'), equals('TO'));
      expect(tokenInitials('goblin'), equals('G'));
      expect(tokenInitials('thorin-oakenshield'), equals('TO'));
      expect(tokenInitials('Éowyn'), equals('O'));
      expect(tokenInitials('  '), equals('X'));
      expect(tokenInitials('Goblin Scout 3'), equals('GS'));

      final rand = Random(42);
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_!@#\$%^&*()Éøñ';
      final validRegex = RegExp(r'^[A-Z0-9]{1,2}$');

      for (int i = 0; i < 200; i++) {
        final len = rand.nextInt(30);
        final str = List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
        final initials = tokenInitials(str);
        expect(initials == 'X' || validRegex.hasMatch(initials), isTrue,
            reason: 'Failed for "$str" -> "$initials"');
      }
    });

    test('TR3 uniqueTokenLabel: examples and random base/taken sets', () {
      expect(uniqueTokenLabel('G', {'G'}), equals('G2'));
      expect(uniqueTokenLabel('G', {'G', 'G2'}), equals('G3'));
      expect(uniqueTokenLabel('GS', {'GS'}), equals('GS2'));
      expect(uniqueTokenLabel('ABC', {'ABC'}), equals('AB2'));

      final rand = Random(123);
      final labelRegex = RegExp(r'^[A-Z0-9]{1,3}$');
      for (int i = 0; i < 200; i++) {
        final base = 'T${rand.nextInt(10)}';
        final taken = <String>{};
        final takenCount = rand.nextInt(12);
        for (int k = 0; k < takenCount; k++) {
          taken.add(rand.nextBool() ? base : '$base${rand.nextInt(10)}');
        }

        final res = uniqueTokenLabel(base, taken);
        expect(labelRegex.hasMatch(res), isTrue);

        final prefix = base.length > 2 ? base.substring(0, 2) : base;
        final allDigitsTaken = [2, 3, 4, 5, 6, 7, 8, 9].every((d) => taken.contains('$prefix$d'));

        if (taken.contains(base) && !allDigitsTaken) {
          expect(taken.contains(res), isFalse, reason: 'Collision for base $base, taken $taken, got $res');
        } else if (allDigitsTaken) {
          expect(res, equals(base));
        }
      }
    });

    test('TR4 myRosterSlug: membership, local characters, and special name rules', () {
      final roster = {'thorin_slug', 'bilbo_slug', 'gandalf_slug'};

      // 1. Membership ID on roster
      expect(
        myRosterSlug(
          rosterSlugs: roster,
          membershipCharacterId: 'thorin_slug',
          playerName: 'Whatever',
          localCharacters: [],
        ),
        equals('thorin_slug'),
      );

      // 2. Membership ID off roster but local character name matches with whitespace/case
      expect(
        myRosterSlug(
          rosterSlugs: roster,
          membershipCharacterId: 'off_roster',
          playerName: '  thorin ',
          localCharacters: [(slug: 'thorin_slug', name: 'Thorin')],
        ),
        equals('thorin_slug'),
      );

      // 3. Local character matching by name whose slug isn't on the roster -> null
      expect(
        myRosterSlug(
          rosterSlugs: roster,
          membershipCharacterId: null,
          playerName: 'Gimli',
          localCharacters: [(slug: 'gimli_slug', name: 'Gimli')],
        ),
        isNull,
      );

      // 4. 'DM', 'Adventurer' and empty -> null
      for (final name in ['DM', 'dm', ' Adventurer ', 'adventurer', '', '   ']) {
        expect(
          myRosterSlug(
            rosterSlugs: roster,
            membershipCharacterId: null,
            playerName: name,
            localCharacters: [
              (slug: 'thorin_slug', name: name.trim()),
            ],
          ),
          isNull,
          reason: 'Failed for name "$name"',
        );
      }

      // 5. Two matching local characters -> the first one
      expect(
        myRosterSlug(
          rosterSlugs: roster,
          membershipCharacterId: null,
          playerName: 'Bilbo',
          localCharacters: [
            (slug: 'bilbo_slug', name: 'Bilbo'),
            (slug: 'gandalf_slug', name: 'Bilbo'),
          ],
        ),
        equals('bilbo_slug'),
      );
    });

    test('TR5 (law over 500 seeds): canMoveTokenWith equals canMoveToken and reference', () {
      for (int seed = 0; seed < 500; seed++) {
        final rand = Random(seed + 1000);

        final allSlugs = ['slug_a', 'slug_b', 'slug_c', 'slug_d'];
        final rosterCount = rand.nextInt(5);
        final rosterSlugs = allSlugs.take(rosterCount).toSet();

        const ts100 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        const ts150 = HybridLogicalClock(physicalTime: 150, logicalCounter: 0, nodeId: 'n1');
        const ts200 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');

        var roster = const CrdtOrSet<String>.empty();
        for (final s in rosterSlugs) {
          roster = roster.add(s, s, ts100);
        }

        var minions = const CrdtOrSet<dynamic>.empty();
        final activeMinionIds = <String>{};
        final totalMinions = rand.nextInt(5);
        for (int m = 0; m < totalMinions; m++) {
          final mId = 'minion_$m';
          minions = minions.add(mId, {'id': mId, 'name': 'Minion $m'}, ts100);
          activeMinionIds.add(mId);
        }
        final removedCount = rand.nextInt(3);
        for (int r = 0; r < removedCount; r++) {
          final rId = 'rem_minion_$r';
          minions = minions.add(rId, {'id': rId}, ts100);
          minions = minions.remove(rId, ts200);
        }

        var owners = const CrdtOrSet<String>.empty();
        final referenceOwners = <String, String?>{};
        for (int m = 0; m < totalMinions + removedCount; m++) {
          final mId = m < totalMinions ? 'minion_$m' : 'rem_minion_${m - totalMinions}';
          if (rand.nextBool()) {
            final chosen = rosterSlugs.isNotEmpty && rand.nextInt(4) != 0
                ? rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))
                : (rand.nextBool() ? 'off_roster_slug' : null);
            if (chosen != null) {
              owners = owners.add(mId, chosen, ts150);
              referenceOwners[mId] = chosen;
            } else {
              owners = owners.remove(mId, ts150);
              referenceOwners[mId] = null;
            }
          }
        }

        var encounter = const CrdtOrSet<EncounterParticipant>.empty();
        final combatantIds = <String>{};
        final encCount = rand.nextInt(4);
        for (int e = 0; e < encCount; e++) {
          final pId = 'p_$e';
          combatantIds.add(pId);
          encounter = encounter.add(
            pId,
            EncounterParticipant(
              participantId: pId,
              entityLink: RoomEntityLink(entityId: pId, displayName: pId),
              currentHp: 10,
              maxHp: 10,
              defense: 10,
              initiativeScore: 10,
            ),
            ts100,
          );
        }

        final tokens = <MapToken>[];
        for (int t = 0; t < 6; t++) {
          final kind = MapTokenKind.values[rand.nextInt(MapTokenKind.values.length)];
          final String refId;
          switch (kind) {
            case MapTokenKind.character:
              refId = rand.nextBool() && rosterSlugs.isNotEmpty
                  ? rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))
                  : 'non_existent_char';
            case MapTokenKind.minion:
              refId = rand.nextBool() && activeMinionIds.isNotEmpty
                  ? activeMinionIds.elementAt(rand.nextInt(activeMinionIds.length))
                  : (rand.nextBool() ? 'rem_minion_0' : 'non_existent_minion');
            case MapTokenKind.monster:
              refId = rand.nextBool() && combatantIds.isNotEmpty
                  ? combatantIds.elementAt(rand.nextInt(combatantIds.length))
                  : 'non_existent_monster';
          }
          tokens.add(MapToken(
            id: _tokId(t + 1),
            mapSha256Hex: _testMapSha,
            kind: kind,
            refId: refId,
            label: 'T$t',
          ));
        }

        final profile = CampaignProfile.raw(
          id: 'camp_rules_tr5_$seed',
          nameRegister: const CrdtLwwRegister<String>(value: 'Camp', timestamp: ts100),
          notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: ts100),
          partyRoster: roster,
          minionOwners: owners,
          roomState: const RoomNodeState.empty().copyWith(
            activeEncounter: encounter,
            activeMinions: minions,
          ),
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
        );

        final testRosterSlugs = profile.partyRoster.activeValues.toSet();
        final testMinionOwners = <String, String>{};
        for (final mId in profile.roomState.activeMinions.items.keys) {
          final o = profile.minionOwner(mId);
          if (o != null) testMinionOwners[mId] = o;
        }

        final actors = <MapTokenActor>[
          const MapTokenActor.dm(),
          if (rosterSlugs.isNotEmpty) MapTokenActor.player(rosterSlugs.elementAt(rand.nextInt(rosterSlugs.length))),
          const MapTokenActor.player('off_roster_slug'),
          const MapTokenActor.player(null),
        ];

        for (final token in tokens) {
          for (final actor in actors) {
            final fromProfile = canMoveToken(profile, token, actor);
            final fromInputs = canMoveTokenWith(
              rosterSlugs: testRosterSlugs,
              minionOwners: testMinionOwners,
              token: token,
              actor: actor,
            );

            // Independent reference
            final bool expected;
            if (actor is DmActor) {
              expected = true;
            } else {
              final playerSlug = (actor as PlayerActor).rosterSlug;
              if (playerSlug == null || !rosterSlugs.contains(playerSlug)) {
                expected = false;
              } else {
                switch (token.kind) {
                  case MapTokenKind.character:
                    expected = token.refId == playerSlug;
                  case MapTokenKind.minion:
                    final isAct = activeMinionIds.contains(token.refId);
                    final owner = referenceOwners[token.refId];
                    expected = isAct && owner == playerSlug;
                  case MapTokenKind.monster:
                    expected = false;
                }
              }
            }

            expect(fromInputs, equals(fromProfile), reason: 'Seed $seed mismatch between canMoveToken and canMoveTokenWith');
            expect(fromInputs, equals(expected), reason: 'Seed $seed mismatch with reference');
          }
        }
      }
    });
  });
}
