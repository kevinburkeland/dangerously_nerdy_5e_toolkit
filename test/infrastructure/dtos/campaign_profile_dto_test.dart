import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

void main() {
  group('CampaignProfileDto Round-Trip & Migration Tests', () {
    test('Round-trip serialization preserves all fields', () {
      final now = DateTime.now();
      final domain = CampaignProfile(
        id: 'camp_roundtrip_1',
        name: 'The Lost Tomb',
        edition: DmRulesEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'TOMB',
          title: 'Tomb Entrance',
          activeEncounter: [
            EncounterParticipant(
              participantId: 'c1',
              entityLink: RoomEntityLink(
                refType: SessionRefType.monster,
                entityId: 'skeleton',
                displayName: 'Skeleton',
              ),
              currentHp: 13,
              maxHp: 13,
              initiativeScore: 14,
            ),
          ],
          activeMinions: [
            AnimatedObjectInstance(
              id: 'min1',
              name: 'Tiny Dagger',
              size: ObjectSize.tiny,
              currentHp: 20,
              maxHp: 20,
            ),
          ],
        ),
        partyCharacterIds: const ['char_alpha', 'char_beta'],
        pinnedRuleIds: const {'cover', 'flanking'},
        notesMarkdown: '# Note Heading',
        nodeId: 'test_node',
      );

      final dto = CampaignProfileDto.fromDomain(domain);
      final map = dto.toMap();
      final restoredDto = CampaignProfileDto.fromMap(map);
      final restoredDomain = restoredDto.toDomain();

      expect(restoredDomain.id, equals('camp_roundtrip_1'));
      expect(restoredDomain.name, equals('The Lost Tomb'));
      expect(restoredDomain.edition, equals(DmRulesEdition.v2024));
      expect(restoredDomain.partyCharacterIds,
          equals(['char_alpha', 'char_beta']));
      expect(restoredDomain.pinnedRuleIds, contains('cover'));
      expect(restoredDomain.notesMarkdown, equals('# Note Heading'));
      expect(restoredDomain.roomState.activeEncounter.length, equals(1));
      expect(restoredDomain.roomState.activeMinions.length, equals(1));
      expect(restoredDomain.roomState.activeMinions.first.name,
          equals('Tiny Dagger'));
    });

    test(
        'Migrates legacy partyRoster and activeMinions from root into proper locations',
        () {
      final legacyRaw = {
        'id': 'legacy_camp',
        'name': 'Old School Vault',
        'partyRoster': [
          {
            'id': {'slug': 'fighter_old', 'ruleset': 'v2024'},
            'name': 'Old Fighter',
            'speciesRef': {
              'slug': 'human',
              'refType': 'species',
              'displayName': 'Human'
            },
          },
        ],
        'activeMinions': [
          {
            'id': 'coin_1',
            'name': 'Flying Coin',
            'size': 'tiny',
            'currentHp': 20,
            'maxHp': 20,
          }
        ],
      };

      final dto = CampaignProfileDto.fromMap(legacyRaw);
      final domain = dto.toDomain();

      expect(domain.partyCharacterIds, equals(['fighter_old']));
      final legacyChars = CampaignProfileDto.extractLegacyCharacters(legacyRaw);
      expect(legacyChars.length, equals(1));
      expect(legacyChars.first.name, equals('Old Fighter'));
      expect(domain.roomState.activeMinions.length, equals(1));
      expect(domain.roomState.activeMinions.first.name, equals('Flying Coin'));
    });

    test('Preserves unparsed payload when character data is corrupted', () {
      final corruptRaw = {
        'id': 'corrupt_camp',
        'name': 'Corrupted Run',
        'partyRoster': [
          {'invalid_schema': true, 'id': 'broken_999'},
        ],
      };

      final dto = CampaignProfileDto.fromMap(corruptRaw);
      expect(dto.unparsedPartyRoster.length, equals(1));
      expect(dto.unparsedPartyRoster.first['id'], equals('broken_999'));

      final domain = dto.toDomain();
      expect(domain.partyCharacterIds.isEmpty, isTrue);
    });

    group('Strict Root Register Null Rejection (Pass 4.2.3)', () {
      final baseMap = {
        'id': 'camp_1',
        'name': 'Campaign One',
        'createdAt': DateTime.now().toIso8601String(),
        'lastPlayedAt': DateTime.now().toIso8601String(),
      };

      test('nameRegister: explicit null value throws FormatException', () {
        final map = {
          ...baseMap,
          'nameRegister': {
            'v': null,
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('nameRegister: missing value throws FormatException', () {
        final map = {
          ...baseMap,
          'nameRegister': {
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('nameRegister: valid non-null string is accepted', () {
        final map = {
          ...baseMap,
          'nameRegister': {
            'v': 'Authoritative Campaign Name',
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();
        expect(profile.nameRegister.value, equals('Authoritative Campaign Name'));
        expect(profile.nameRegister.timestamp.physicalTime, equals(100));
      });

      test('nameRegister: absent register triggers deterministic legacy/genesis migration', () {
        final map = {...baseMap};
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();
        expect(profile.nameRegister.value, equals('Campaign One'));
        expect(profile.nameRegister.timestamp.nodeId, equals('genesis'));
      });

      test('Campaign notesRegister: explicit null value throws FormatException', () {
        final map = {
          ...baseMap,
          'notesRegister': {
            'v': null,
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('Campaign notesRegister: missing value throws FormatException', () {
        final map = {
          ...baseMap,
          'notesRegister': {
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('Campaign notesRegister: valid non-null string is accepted', () {
        final map = {
          ...baseMap,
          'notesRegister': {
            'v': 'Secret campaign GM notes',
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();
        expect(profile.notesRegister.value, equals('Secret campaign GM notes'));
        expect(profile.notesRegister.timestamp.physicalTime, equals(100));
      });

      test('Campaign notesRegister: absent register triggers deterministic legacy/genesis migration', () {
        final map = {...baseMap};
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();
        expect(profile.notesRegister.value, equals(''));
        expect(profile.notesRegister.timestamp.nodeId, equals('genesis'));
      });

      test('RoomEntityLink.notesRegister keeps explicit null as valid authoritative clear', () {
        final linkMap = {
          'entityId': 'link_1',
          'notesRegister': {
            'v': null,
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        final link = RoomEntityLink.fromMap(linkMap);
        expect(link.notesRegister.value, isNull);
        expect(link.notes, isNull);
        expect(link.notesRegister.timestamp.physicalTime, equals(100));
      });

      test('RoomEntityLink.notesRegister: missing value key throws FormatException', () {
        final linkMap = {
          'entityId': 'link_1',
          'notesRegister': {
            'ts': {'physicalTime': 100, 'logicalCounter': 0, 'nodeId': 'n1'},
          },
        };
        expect(() => RoomEntityLink.fromMap(linkMap), throwsA(isA<FormatException>()));
      });
    });
  });
}
