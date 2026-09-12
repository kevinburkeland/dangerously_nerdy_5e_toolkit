import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';

void main() {
  group('CampaignProfile Deep Equality Tests', () {
    final baseDate = DateTime.utc(2024, 1, 1);
    const room = RoomNodeState(
      roomId: 'room-1',
      roomCode: 'CR-101',
      title: 'Dungeon Room',
    );

    final profileA = CampaignProfile(
      id: 'camp-1',
      name: 'Dragon Hunt',
      edition: DmRulesEdition.v2024,
      createdAt: baseDate,
      lastPlayedAt: baseDate,
      roomState: room,
      partyCharacterIds: const ['char-1', 'char-2'],
      pinnedRuleIds: const {'cover', 'grapple_shove'},
      notesMarkdown: 'Session 1 notes',
      partyPurse: const PartyPurse(gp: 50, sp: 10),
    );

    test('identical or cloned instance with matching fields evaluates equal', () {
      final profileB = CampaignProfile(
        id: 'camp-1',
        name: 'Dragon Hunt',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025, 1, 1), // timestamps differ but aren't equality gated
        lastPlayedAt: DateTime.utc(2025, 1, 2),
        roomState: room,
        partyCharacterIds: const ['char-1', 'char-2'],
        pinnedRuleIds: const {'cover', 'grapple_shove'},
        notesMarkdown: 'Session 1 notes',
        partyPurse: const PartyPurse(gp: 50, sp: 10),
      );

      expect(profileA, equals(profileB));
      expect(profileA.hashCode, equals(profileB.hashCode));
    });

    test('detects differences in name despite same id', () {
      final modified = profileA.copyWith(name: 'Dragon Hunt (Renamed)');
      expect(profileA == modified, isFalse);
    });

    test('detects differences in edition despite same id', () {
      final modified = profileA.copyWith(edition: DmRulesEdition.v2014);
      expect(profileA == modified, isFalse);
    });

    test('detects differences in partyCharacterIds despite same id', () {
      final modified = profileA.copyWith(partyCharacterIds: ['char-1', 'char-3']);
      expect(profileA == modified, isFalse);
    });

    test('detects differences in pinnedRuleIds despite same id', () {
      final modified = profileA.copyWith(pinnedRuleIds: {'cover'});
      expect(profileA == modified, isFalse);
    });

    test('detects differences in notesMarkdown despite same id', () {
      final modified = profileA.copyWith(notesMarkdown: 'Updated notes');
      expect(profileA == modified, isFalse);
    });

    test('detects differences in partyPurse despite same id', () {
      final modified = profileA.copyWith(partyPurse: const PartyPurse(gp: 100));
      expect(profileA == modified, isFalse);
    });
  });
}
