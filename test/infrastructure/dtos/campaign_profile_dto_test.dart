import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
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
        roomState: RoomNodeState(
          roomId: 'r1',
          roomCode: 'TOMB',
          title: 'Tomb Entrance',
          activeEncounter: const [
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
      );

      final dto = CampaignProfileDto.fromDomain(domain);
      final map = dto.toMap();
      final restoredDto = CampaignProfileDto.fromMap(map);
      final restoredDomain = restoredDto.toDomain();

      expect(restoredDomain.id, equals('camp_roundtrip_1'));
      expect(restoredDomain.name, equals('The Lost Tomb'));
      expect(restoredDomain.edition, equals(DmRulesEdition.v2024));
      expect(restoredDomain.partyCharacterIds, equals(['char_alpha', 'char_beta']));
      expect(restoredDomain.pinnedRuleIds, contains('cover'));
      expect(restoredDomain.notesMarkdown, equals('# Note Heading'));
      expect(restoredDomain.roomState.activeEncounter.length, equals(1));
      expect(restoredDomain.roomState.activeMinions.length, equals(1));
      expect(restoredDomain.roomState.activeMinions.first.name, equals('Tiny Dagger'));
    });

    test('Migrates legacy partyRoster and activeMinions from root into proper locations', () {
      final legacyRaw = {
        'id': 'legacy_camp',
        'name': 'Old School Vault',
        'partyRoster': [
          {
            'id': {'slug': 'fighter_old', 'ruleset': 'v2024'},
            'name': 'Old Fighter',
            'speciesRef': {'slug': 'human', 'refType': 'species', 'displayName': 'Human'},
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
      expect(domain.migratedCharacters.length, equals(1));
      expect(domain.migratedCharacters.first.name, equals('Old Fighter'));
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
      final domain = dto.toDomain();

      expect(domain.partyCharacterIds.isEmpty, isTrue);
      expect(domain.unparsedPartyRoster.length, equals(1));
      expect(domain.unparsedPartyRoster.first['id'], equals('broken_999'));
    });
  });
}
