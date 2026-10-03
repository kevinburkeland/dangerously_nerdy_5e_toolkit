import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_session_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';

void main() {
  group('PartySessionState Immutability & Anti-Aliasing', () {
    test('Constructor defensively copies all collection inputs', () {
      final memberPurses = <String, PartyPurse>{
        'Fighter': const PartyPurse.empty(),
      };
      final activePlayers = <String>['Alice'];
      final characterRoster = <String>['Char1'];
      final sharedCharacters = <String, Map<String, dynamic>>{
        'Char1': {'name': 'Aragorn'},
      };
      final partyTelemetry = <String, CharacterTelemetryDto>{
        'Char1': CharacterTelemetryDto(
          id: 'Char1',
          name: 'Aragorn',
          speciesSlug: 'human',
          currentHp: 20,
          maxHp: 20,
          armorClass: 16,
          passivePerception: 12,
          conditions: [],
          exhaustionLevel: 0,
          spellSlots: {},
          timestamp: 1000,
        ),
      };

      final state = PartySessionState(
        roomCode: 'ABCD',
        campaignName: 'Test Campaign',
        hostKeyHash: 'hash123',
        memberPurses: memberPurses,
        activePlayers: activePlayers,
        characterRoster: characterRoster,
        sharedCharacters: sharedCharacters,
        partyTelemetry: partyTelemetry,
        lastUpdated: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 2),
      );

      // Mutate inputs after construction
      memberPurses['Wizard'] = const PartyPurse.empty();
      activePlayers.add('Bob');
      characterRoster.add('Char2');
      sharedCharacters['Char1']!['name'] = 'Strider';
      sharedCharacters['Char2'] = {'name': 'Legolas'};
      partyTelemetry['Char2'] = CharacterTelemetryDto(
        id: 'Char2',
        name: 'Legolas',
        speciesSlug: 'elf',
        currentHp: 15,
        maxHp: 15,
        armorClass: 15,
        passivePerception: 15,
        conditions: [],
        exhaustionLevel: 0,
        spellSlots: {},
        timestamp: 1000,
      );

      // Verify state was not affected
      expect(state.memberPurses.keys, ['Fighter']);
      expect(state.activePlayers, ['Alice']);
      expect(state.characterRoster, ['Char1']);
      expect(state.sharedCharacters['Char1']!['name'], 'Aragorn');
      expect(state.sharedCharacters.containsKey('Char2'), isFalse);
      expect(state.partyTelemetry.keys, ['Char1']);
    });

    test('Public collection fields are unmodifiable', () {
      final state = PartySessionState(
        roomCode: 'ABCD',
        campaignName: 'Test Campaign',
        hostKeyHash: 'hash123',
        lastUpdated: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 2),
      );

      expect(() => state.memberPurses['X'] = const PartyPurse.empty(),
          throwsUnsupportedError);
      expect(() => (state.activePlayers as dynamic).add('Alice'),
          throwsUnsupportedError);
      expect(() => (state.characterRoster as dynamic).add('Char1'),
          throwsUnsupportedError);
      expect(() => state.sharedCharacters['Char1'] = {},
          throwsUnsupportedError);
      expect(
          () => state.partyTelemetry['Char1'] = CharacterTelemetryDto(
                id: 'Char1',
                name: 'Aragorn',
                speciesSlug: 'human',
                currentHp: 20,
                maxHp: 20,
                armorClass: 16,
                passivePerception: 12,
                conditions: [],
                exhaustionLevel: 0,
                spellSlots: {},
                timestamp: 1000,
              ),
          throwsUnsupportedError);
    });

    test('copyWith defensively copies overridden collections', () {
      final state = PartySessionState(
        roomCode: 'ABCD',
        campaignName: 'Test Campaign',
        hostKeyHash: 'hash123',
        lastUpdated: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 2),
      );

      final newPlayers = <String>['Charlie'];
      final copied = state.copyWith(activePlayers: newPlayers);
      newPlayers.add('Dave');

      expect(copied.activePlayers, ['Charlie']);
      expect(() => (copied.activePlayers as dynamic).add('Eve'),
          throwsUnsupportedError);
    });
  });
}
