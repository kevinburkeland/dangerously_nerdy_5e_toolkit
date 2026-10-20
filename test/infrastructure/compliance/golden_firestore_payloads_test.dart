import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/firebase_fallback_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/p2p/signaling_message.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_loot_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';

void main() {
  const fixturesDir = 'test/fixtures/firestore_payloads';

  group('Golden Firestore Payloads Generator & Integrity Test', () {
    setUpAll(() {
      Directory(fixturesDir).createSync(recursive: true);
    });

    test('lobby_hosted.json payload matches real PartyRoomLobby.toMap()', () {
      final lobby = PartyRoomLobby(
        roomCode: 'GOLDEN1',
        campaignName: "Kevin's Campaign",
        hostKeyHash:
            '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
        activePlayers: const ['Thorin', 'Gandalf'],
        partyTelemetry: {
          'thorin-slug': CharacterTelemetryDto(
            id: 'thorin-id',
            name: 'Thorin Oakenshield',
            speciesSlug: 'dwarf',
            currentHp: 45,
            maxHp: 52,
            armorClass: 18,
            passivePerception: 14,
            spellSlots: const {'1': 2},
            deathSaveSuccesses: 0,
            deathSaveFailures: 0,
            exhaustionLevel: 0,
            conditions: const ['blessed'],
            tempHp: 5,
            timestamp: 1729425600000,
          ),
        },
        sharedCharacters: const {
          'thorin-slug': {'name': 'Thorin', 'level': 5},
        },
        version: 1,
        createdAt: DateTime.utc(2026, 10, 20, 12, 0, 0),
        lastUpdated: DateTime.utc(2026, 10, 20, 12, 0, 0),
        expiresAt: DateTime.utc(2026, 11, 20, 12, 0, 0),
        campaignId: 'camp-golden-1',
        rulesetId: 'dnd5e_2024',
      );

      final map = lobby.toMap();
      _assertOrWriteFixture('$fixturesDir/lobby_hosted.json', map);
    });

    test('lobby_hostless.json payload matches real PartyRoomLobby.toMap()', () {
      final lobby = PartyRoomLobby(
        roomCode: 'GOLDEN2',
        campaignName: 'Dice Room GOLDEN2',
        hostKeyHash: '',
        activePlayers: const ['Thorin'],
        partyTelemetry: const {},
        sharedCharacters: const {},
        version: 1,
        createdAt: DateTime.utc(2026, 10, 20, 12, 0, 0),
        lastUpdated: DateTime.utc(2026, 10, 20, 12, 0, 0),
        expiresAt: DateTime.utc(2026, 11, 20, 12, 0, 0),
        campaignId: 'camp-golden-2',
        rulesetId: 'dnd5e_2024',
      );

      final map = lobby.toMap();
      _assertOrWriteFixture('$fixturesDir/lobby_hostless.json', map);
    });

    test('party_loot_item.json payload matches real PartyLootItem.toMap()', () {
      final item = PartyLootItem(
        id: 'loot_golden_1',
        name: 'Bag of Holding',
        category: 'gear',
        count: 1,
        gpValue: 500.0,
        description: 'A wondrous bag of holding items.',
        claimedByPlayer: 'Thorin',
        isIdentified: true,
        requiresAttunement: false,
        isAttuned: false,
        isArchived: false,
        createdAt: DateTime.utc(2026, 10, 20, 12, 0, 0),
        expiresAt: DateTime.utc(2026, 11, 20, 12, 0, 0),
      );

      final map = item.toMap();
      _assertOrWriteFixture('$fixturesDir/party_loot_item.json', map);
    });

    test('party_event.json payload matches real PartyEvent.toMap()', () {
      final event = PartyEvent(
        id: 'evt_golden_1',
        roomCode: 'GOLDEN1',
        type: 'itemAdd',
        playerName: 'Thorin',
        details: 'Thorin added Bag of Holding to party vault.',
        timestamp: DateTime.utc(2026, 10, 20, 12, 0, 0),
      );

      final map = event.toMap();
      _assertOrWriteFixture('$fixturesDir/party_event.json', map);
    });

    test('signaling_message.json payload matches real SignalingMessage.toMap()', () {
      const signal = SignalingMessage(
        id: 'sig_golden_1',
        roomCode: 'GOLDEN1',
        fromNodeId: 'node-alice',
        toNodeId: 'node-bob',
        type: SignalingType.offer,
        sdp: 'v=0\r\no=- 123456 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n',
        candidate: {'candidate': 'dummy-candidate', 'sdpMid': '0', 'sdpMLineIndex': 0},
        timestamp: 1729425600000,
      );

      final map = signal.toMap();
      _assertOrWriteFixture('$fixturesDir/signaling_message.json', map);
    });

    test('room_roll.json payload matches real RoomRoll.toFirestoreMap()', () {
      final roll = RoomRoll(
        id: 'roll_golden_1',
        roomCode: 'GOLDEN1',
        playerName: 'Thorin',
        total: 18,
        individualRolls: const [13],
        formulaString: '1d20+5',
        details: const ['d20: 13 + 5 = 18'],
        isCrit: false,
        isFumble: false,
        timestamp: DateTime.utc(2026, 10, 20, 12, 0, 0),
      );

      final map = roll.toFirestoreMap(
        (dt) => {'__timestamp__': dt.toUtc().toIso8601String()},
      );
      _assertOrWriteFixture('$fixturesDir/room_roll.json', map);
    });

    test('relay_message.json payload matches FirebaseFallbackAdapter onWriteMessage seam', () async {
      Map<String, dynamic>? capturedData;
      final adapter = FirebaseFallbackAdapter(
        onWriteMessage: (path, data) async {
          capturedData = Map<String, dynamic>.from(data);
        },
      );

      await adapter.initializeRoom('GOLDEN1', 'node-alice');
      await adapter.broadcastPayload('{"type":"ping","clock":1234}');

      expect(capturedData, isNotNull);
      final rawExpireAt = capturedData!['expireAt'];
      expect(rawExpireAt, isA<Timestamp>());

      final normalizedMap = Map<String, dynamic>.from(capturedData!)
        ..['id'] = 'relay_golden_1'
        ..['timestamp'] = 1729425600000
        ..['expireAt'] = {'__timestamp__': '2026-10-20T04:30:00.000Z'};

      _assertOrWriteFixture('$fixturesDir/relay_message.json', normalizedMap);
    });
  });
}

void _assertOrWriteFixture(String filePath, Map<String, dynamic> actual) {
  const encoder = JsonEncoder.withIndent('  ');
  final expectedJson = encoder.convert(actual);
  final file = File(filePath);

  if (!file.existsSync()) {
    file.writeAsStringSync('$expectedJson\n');
    return;
  }

  final existingContent = file.readAsStringSync().trim();
  expect(
    existingContent,
    equals(expectedJson),
    reason: 'Golden fixture at $filePath is stale! Regenerate or update the fixture.',
  );
}
