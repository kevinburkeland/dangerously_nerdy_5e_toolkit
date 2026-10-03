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

    test(
        'Realistic PartySessionState.sharedCharacters deep nested immutability & anti-aliasing',
        () {
      final itemProps = <String, dynamic>{
        'magic': false,
      };
      final itemMap = <String, dynamic>{
        'name': 'Sword',
        'properties': itemProps,
      };
      final inventoryList = <dynamic>[itemMap];
      final resourcesMap = <String, dynamic>{
        'hp': 20,
      };
      final characterData = <String, dynamic>{
        'name': 'Aragorn',
        'resources': resourcesMap,
        'inventory': inventoryList,
      };

      final shared = <String, Map<String, dynamic>>{
        'char-1': characterData,
      };

      final state = PartySessionState(
        roomCode: 'ROOM1',
        campaignName: 'Fellowship',
        hostKeyHash: 'hash',
        sharedCharacters: shared,
        lastUpdated: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 1, 2),
      );

      // Mutate external nested maps and lists after construction
      resourcesMap['hp'] = 999;
      itemProps['magic'] = true;
      itemMap['name'] = 'Broken Hilt';
      inventoryList.add({'name': 'Shield'});
      shared['char-2'] = {'name': 'Legolas'};

      // Verify PartySessionState remains completely unmodified
      final storedChar = state.sharedCharacters['char-1']!;
      expect(storedChar['name'], 'Aragorn');
      expect((storedChar['resources'] as Map)['hp'], 20);

      final storedInventory = storedChar['inventory'] as List;
      expect(storedInventory.length, 1);
      final storedItem = storedInventory.first as Map;
      expect(storedItem['name'], 'Sword');
      expect((storedItem['properties'] as Map)['magic'], false);
      expect(state.sharedCharacters.containsKey('char-2'), isFalse);

      // Verify nested collections cannot be mutated through the public object
      expect(
        () => (storedChar['resources'] as Map)['hp'] = 999,
        throwsUnsupportedError,
      );
      expect(
        () => (storedChar['inventory'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => (storedItem['properties'] as Map)['magic'] = true,
        throwsUnsupportedError,
      );
    });
  });
}
