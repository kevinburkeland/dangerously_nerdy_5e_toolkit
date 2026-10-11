import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';

void main() {
  group('Cold Iron Birdcage — Pass 4.1.2.1: Authoritative Presence & Pass-4 Closure', () {
    const genesisHlc = HybridLogicalClock(
      physicalTime: 0,
      logicalCounter: 0,
      nodeId: 'genesis',
    );

    // =========================================================================
    // C. REQUIRED PARTY ROSTER REGRESSIONS
    // =========================================================================
    group('C. Party Roster Authoritative Presence Regressions', () {
      test('1. authoritative absent + legacy nonempty -> fighter migrated into genesis partyRoster', () {
        final map = {
          'id': 'camp-c1',
          'name': 'Legacy Roster Campaign',
          'partyCharacterIds': ['fighter'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPartyRosterCrdt, isFalse);
        final domain = dto.toDomain();

        expect(domain.partyCharacterIds, equals(['fighter']));
        expect(domain.partyRoster.activeValues, equals(['fighter']));
        expect(domain.partyRoster.items['fighter']!.timestamp, equals(genesisHlc));
      });

      test('2. authoritative present nonempty + legacy divergent -> cleric only (authoritative wins)', () {
        final map = {
          'id': 'camp-c2',
          'name': 'Divergent Roster Campaign',
          'partyRoster_crdt': {
            'items': {
              'cleric': {
                'v': 'cleric',
                'ts': {
                  'physicalTime': 100,
                  'logicalCounter': 0,
                  'nodeId': 'nodeA',
                },
              },
            },
            'tombstones': {},
          },
          'partyCharacterIds': ['fighter'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPartyRosterCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.partyCharacterIds, equals(['cleric']));
        expect(domain.partyRoster.activeValues, equals(['cleric']));
        expect(domain.partyRoster.items.containsKey('fighter'), isFalse);
      });

      test('3. authoritative present EMPTY ({}) + legacy nonempty -> final authoritative roster EMPTY', () {
        final map = {
          'id': 'camp-c3',
          'name': 'Empty CRDT Map Campaign',
          'partyRoster_crdt': <String, dynamic>{},
          'partyCharacterIds': ['should-not-return'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPartyRosterCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.partyCharacterIds, isEmpty);
        expect(domain.partyRoster.activeValues, isEmpty);
        expect(domain.partyRoster.items, isEmpty);
      });

      test('4. authoritative present canonical empty + legacy nonempty -> final authoritative roster EMPTY', () {
        final map = {
          'id': 'camp-c4',
          'name': 'Canonical Empty CRDT Campaign',
          'partyRoster_crdt': {
            'items': <String, dynamic>{},
            'tombstones': <String, dynamic>{},
          },
          'partyCharacterIds': ['should-not-return'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPartyRosterCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.partyCharacterIds, isEmpty);
        expect(domain.partyRoster.activeValues, isEmpty);
        expect(domain.partyRoster.items, isEmpty);
      });

      test('5. roundtrip an explicitly empty authoritative roster preserves empty and forbids resurrection', () {
        final domain = CampaignProfile.initial(
          id: 'camp-c5',
          name: 'Roundtrip Empty Campaign',
          nodeId: 'node-roundtrip',
        );
        expect(domain.partyRoster.isEmpty, isTrue);

        final dto = CampaignProfileDto.fromDomain(domain);
        expect(dto.hasPartyRosterCrdt, isTrue);

        final rawMap = dto.toMap();
        expect(rawMap.containsKey('partyRoster_crdt'), isTrue);

        // Inject stale legacy character into map to simulate hostile/stale wire data
        rawMap['partyCharacterIds'] = ['stale-ghost-character'];

        final restoredDto = CampaignProfileDto.fromMap(rawMap);
        expect(restoredDto.hasPartyRosterCrdt, isTrue);
        final restoredDomain = restoredDto.toDomain();

        expect(restoredDomain.partyCharacterIds, isEmpty);
        expect(restoredDomain.partyRoster.isEmpty, isTrue);
        expect(restoredDomain.partyRoster.activeValues, isEmpty);
      });
    });

    // =========================================================================
    // E. REQUIRED PINNED RULE REGRESSIONS
    // =========================================================================
    group('E. Pinned Rules Authoritative Presence Regressions', () {
      test('1. authoritative absent + legacy pinnedRuleIds -> deterministic legacy genesis migration', () {
        final map = {
          'id': 'camp-e1',
          'name': 'Legacy Pinned Rules Campaign',
          'pinnedRuleIds': ['cover', 'resting'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPinnedRulesCrdt, isFalse);
        final domain = dto.toDomain();

        expect(domain.pinnedRuleIds, equals({'cover', 'resting'}));
        expect(domain.pinnedRules.activeValues, equals({'cover', 'resting'}));
        expect(domain.pinnedRules.items['cover']!.timestamp, equals(genesisHlc));
      });

      test('2. authoritative present nonempty + legacy divergent -> authoritative wins', () {
        final map = {
          'id': 'camp-e2',
          'name': 'Divergent Pinned Rules Campaign',
          'pinnedRules_crdt': {
            'items': {
              'concentration': {
                'v': 'concentration',
                'ts': {
                  'physicalTime': 200,
                  'logicalCounter': 0,
                  'nodeId': 'nodeA',
                },
              },
            },
            'tombstones': {},
          },
          'pinnedRuleIds': ['cover', 'resting'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPinnedRulesCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.pinnedRuleIds, equals({'concentration'}));
        expect(domain.pinnedRules.activeValues, equals({'concentration'}));
        expect(domain.pinnedRules.items.containsKey('cover'), isFalse);
      });

      test('3. authoritative present EMPTY ({}) + legacy nonempty -> final pinnedRules EMPTY', () {
        final map = {
          'id': 'camp-e3',
          'name': 'Empty CRDT Pinned Rules Campaign',
          'pinnedRules_crdt': <String, dynamic>{},
          'pinnedRuleIds': ['cover', 'resting'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPinnedRulesCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.pinnedRuleIds, isEmpty);
        expect(domain.pinnedRules.activeValues, isEmpty);
        expect(domain.pinnedRules.items, isEmpty);
      });

      test('4. canonical empty CRDT + stale legacy list -> final pinnedRules EMPTY', () {
        final map = {
          'id': 'camp-e4',
          'name': 'Canonical Empty Pinned Rules Campaign',
          'pinnedRules_crdt': {
            'items': <String, dynamic>{},
            'tombstones': <String, dynamic>{},
          },
          'pinnedRuleIds': ['cover', 'resting'],
        };

        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasPinnedRulesCrdt, isTrue);
        final domain = dto.toDomain();

        expect(domain.pinnedRuleIds, isEmpty);
        expect(domain.pinnedRules.activeValues, isEmpty);
        expect(domain.pinnedRules.items, isEmpty);
      });

      test('5. explicitly empty authoritative pinnedRules roundtrip remains empty', () {
        final domain = CampaignProfile.initial(
          id: 'camp-e5',
          name: 'Roundtrip Empty Pinned Campaign',
          nodeId: 'node-pinned-roundtrip',
        );
        expect(domain.pinnedRules.isEmpty, isTrue);

        final dto = CampaignProfileDto.fromDomain(domain);
        expect(dto.hasPinnedRulesCrdt, isTrue);

        final rawMap = dto.toMap();
        expect(rawMap.containsKey('pinnedRules_crdt'), isTrue);

        // Inject stale legacy pinned rules into map
        rawMap['pinnedRuleIds'] = ['cover', 'grapple_shove'];

        final restoredDto = CampaignProfileDto.fromMap(rawMap);
        expect(restoredDto.hasPinnedRulesCrdt, isTrue);
        final restoredDomain = restoredDto.toDomain();

        expect(restoredDomain.pinnedRuleIds, isEmpty);
        expect(restoredDomain.pinnedRules.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // N. PERMANENT BAR: AUTHORITATIVE EMPTY BEATS STALE LEGACY NONEMPTY
    // =========================================================================
    group('N. Permanent Architectural Bar', () {
      test('authoritative empty beats stale legacy nonempty for both partyRoster_crdt and pinnedRules_crdt', () {
        final dualEmptyPayload = {
          'id': 'camp-permanent-bar',
          'name': 'Permanent Bar Verification',
          'partyRoster_crdt': <String, dynamic>{},
          'partyCharacterIds': ['stale-char-1', 'stale-char-2'],
          'pinnedRules_crdt': <String, dynamic>{},
          'pinnedRuleIds': ['cover', 'falling', 'concentration'],
        };

        final dto = CampaignProfileDto.fromMap(dualEmptyPayload);
        expect(dto.hasPartyRosterCrdt, isTrue);
        expect(dto.hasPinnedRulesCrdt, isTrue);

        final profile = dto.toDomain();
        expect(profile.partyCharacterIds, isEmpty);
        expect(profile.partyRoster.activeValues, isEmpty);
        expect(profile.pinnedRuleIds, isEmpty);
        expect(profile.pinnedRules.activeValues, isEmpty);
      });
    });

    // =========================================================================
    // FAIL-LOUD ON PRESENT MALFORMED AUTHORITATIVE REPRESENTATION
    // =========================================================================
    group('Fail-Loud Malformed Authoritative Representation', () {
      test('malformed partyRoster_crdt (not a map) throws FormatException', () {
        final badMap = {
          'id': 'camp-bad-roster',
          'partyRoster_crdt': 'not-a-map',
        };
        expect(() => CampaignProfileDto.fromMap(badMap), throwsA(isA<FormatException>()));
      });

      test('malformed partyRoster_crdt (items not a map) throws FormatException', () {
        final badMap = {
          'id': 'camp-bad-roster-items',
          'partyRoster_crdt': {
            'items': 'corrupt-string',
          },
        };
        expect(() => CampaignProfileDto.fromMap(badMap), throwsA(isA<FormatException>()));
      });

      test('malformed pinnedRules_crdt (not a map) throws FormatException', () {
        final badMap = {
          'id': 'camp-bad-pinned',
          'pinnedRules_crdt': 12345,
        };
        expect(() => CampaignProfileDto.fromMap(badMap), throwsA(isA<FormatException>()));
      });

      test('malformed pinnedRules_crdt (tombstones not a map) throws FormatException', () {
        final badMap = {
          'id': 'camp-bad-pinned-ts',
          'pinnedRules_crdt': {
            'items': {},
            'tombstones': ['corrupt-list'],
          },
        };
        expect(() => CampaignProfileDto.fromMap(badMap), throwsA(isA<FormatException>()));
      });
    });

    // =========================================================================
    // J. PartyEvent IS AUDIT-ONLY FOR ROSTER MEMBERSHIP
    // =========================================================================
    group('J. PartyEvent Audit-Only Membership Invariant', () {
      test('PartyEvent removal does not derive membership when partyRoster CRDT has active entry', () {
        const nowHlc = HybridLogicalClock(physicalTime: 500, logicalCounter: 0, nodeId: 'nodeA');
        final base = CampaignProfile.initial(
          id: 'camp-audit-test',
          name: 'Audit Test',
          nodeId: 'nodeA',
        ).copyWith(
          partyRoster: const CrdtOrSet<String>.empty().add('hero-1', 'hero-1', nowHlc),
          changeLog: [
            PartyEvent(
              id: 'ev-rm-1',
              roomCode: 'RC-1',
              type: 'characterRemove',
              playerName: 'DM',
              details: 'Retired hero',
              entityId: 'hero-1',
              timestamp: DateTime.utc(2026, 1, 1),
            ),
          ],
        );

        // Even with characterRemove event in changeLog, partyRoster CRDT active values dictates membership
        expect(base.partyRoster.activeValues, contains('hero-1'));
        expect(base.partyCharacterIds, equals(['hero-1']));
      });
    });

    // =========================================================================
    // ROOMSTATE AUTHORITATIVE PRESENCE REGRESSIONS (PASS 4.1.2.1a)
    // =========================================================================
    group('RoomState Authoritative Presence Regressions', () {
      test('1. roomState absent -> deterministic legacy/default room migration', () {
        final map = {
          'id': 'camp-room-1',
          'name': 'Dungeon Run',
        };
        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasRoomState, isFalse);
        final domain = dto.toDomain();

        expect(domain.roomState.roomId, equals('room_camp-room-1'));
        expect(domain.roomState.roomCode, equals('CR-101'));
        expect(domain.roomState.title, equals('Dungeon Run Staging'));
      });

      test('2. roomState present nonempty -> authoritative room used', () {
        final map = {
          'id': 'camp-room-2',
          'name': 'Dungeon Run',
          'roomState': {
            'roomId': 'custom-room-id',
            'roomCode': 'ALPHA-99',
            'title': 'The Iron Citadel',
            'description': 'A towering fortress of cold iron.',
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasRoomState, isTrue);
        final domain = dto.toDomain();

        expect(domain.roomState.roomId, equals('custom-room-id'));
        expect(domain.roomState.roomCode, equals('ALPHA-99'));
        expect(domain.roomState.title, equals('The Iron Citadel'));
        expect(domain.roomState.description, equals('A towering fortress of cold iron.'));
      });

      test('3. roomState present null -> FormatException', () {
        final map = {
          'id': 'camp-room-3',
          'name': 'Null Room Campaign',
          'roomState': null,
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('4. roomState present wrong type -> FormatException', () {
        final map = {
          'id': 'camp-room-4',
          'name': 'Invalid Type Room Campaign',
          'roomState': 'not-a-map-room',
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('5. roomState present malformed nested CRDT -> FormatException', () {
        final map = {
          'id': 'camp-room-5',
          'name': 'Malformed Nested CRDT Campaign',
          'roomState': {
            'roomId': 'room-bad-crdt',
            'entityLinks_crdt': 'not-a-valid-crdt-map',
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('6. roomState present EMPTY {} -> authoritative empty RoomNodeState semantics preserved (no synthetic fallback)', () {
        final map = {
          'id': 'camp-room-6',
          'name': 'Empty Room Campaign',
          'roomState': <String, dynamic>{},
        };
        final dto = CampaignProfileDto.fromMap(map);
        expect(dto.hasRoomState, isTrue);
        final domain = dto.toDomain();

        // Must preserve authoritative empty room semantics; MUST NOT synthesize room_id / CR-101 / Staging
        expect(domain.roomState.roomId, equals(''));
        expect(domain.roomState.roomCode, equals(''));
        expect(domain.roomState.title, equals(''));
        expect(domain.roomState.description, equals(''));
        expect(domain.roomState.entityLinks, isEmpty);
        expect(domain.roomState.entityInstances, isEmpty);
        expect(domain.roomState.containers, isEmpty);
        expect(domain.roomState.activeEncounterList, isEmpty);
        expect(domain.roomState.activeMinionsList, isEmpty);
      });

      test('7. roomState present {} roundtrip preserves presence exactly without synthetic fallback', () {
        final rawMap = {
          'id': 'camp-room-7',
          'name': 'Roundtrip Empty Room Campaign',
          'roomState': <String, dynamic>{},
        };

        final dto1 = CampaignProfileDto.fromMap(rawMap);
        expect(dto1.hasRoomState, isTrue);

        final serializedMap = dto1.toMap();
        expect(serializedMap.containsKey('roomState'), isTrue);
        expect(serializedMap['roomState'], equals(<String, dynamic>{}));

        final dto2 = CampaignProfileDto.fromMap(serializedMap);
        expect(dto2.hasRoomState, isTrue);

        final domain = dto2.toDomain();
        expect(domain.roomState.roomId, equals(''));
        expect(domain.roomState.roomCode, equals(''));
        expect(domain.roomState.title, equals(''));
      });
    });
  });
}
