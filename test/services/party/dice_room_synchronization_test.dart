import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/room_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';

class MockP2pTransport implements IP2pTransportPort {
  final List<String> broadcasted = [];
  final StreamController<String> _incomingController = StreamController<String>.broadcast();

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcasted.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) => _incomingController.add(payload);

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    await _incomingController.close();
  }
}

class MockCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => _activeProfile != null ? [_activeProfile!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _activeProfile?.id == id ? _activeProfile : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> saveProfile(CampaignProfile profile) async => saveProfileImmediate(profile);

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    _activeProfile = profile;
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) _activeProfile = null;
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();
}

class MockNetworkTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => DateTime.now().millisecondsSinceEpoch;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
  });

  tearDown(() {
    sl.reset();
  });

  group('RoomRoll Serialization & Firestore Rule Safety', () {
    test('toMap omits null details and null droppedRolls to prevent Firestore permission-denied', () {
      final rollResult = DiceRollResult.roll(dieType: DieType.d20, modifier: 3);
      final roll = RoomRoll.fromDiceRollResult(
        id: 'roll-123',
        roomCode: 'ROOM-ALPHA',
        playerName: 'Gimli',
        result: rollResult,
      );

      final map = roll.toMap(useFirestoreTimestamp: false);

      expect(map['id'], 'roll-123');
      expect(map['roomCode'], 'ROOM-ALPHA');
      expect(map['playerName'], 'Gimli');
      expect(map['total'], rollResult.total);
      // Critical check: keys must not exist with null values
      expect(map.containsKey('details'), isFalse);
      expect(map.containsKey('droppedRolls'), isFalse);
    });

    test('toMap includes details and droppedRolls only when populated and clamps bounds', () {
      final roll = RoomRoll(
        id: 'roll-456',
        roomCode: 'ROOM-BETA',
        playerName: 'A' * 100, // Exceeds 80 chars
        timestamp: DateTime(2026, 9, 9, 12, 0, 0),
        formulaString: 'X' * 250, // Exceeds 200 chars
        total: 25,
        individualRolls: [20, 5],
        droppedRolls: [3],
        details: List.generate(60, (i) => 'Detail $i'), // Exceeds 50 items
        isCrit: true,
        isFumble: false,
      );

      final map = roll.toMap(useFirestoreTimestamp: false);

      expect((map['playerName'] as String).length, 80);
      expect((map['formulaString'] as String).length, 200);
      expect(map['droppedRolls'], [3]);
      expect((map['details'] as List).length, 50);
    });

    test('fromMap parses various timestamp types safely (String, Timestamp, int, DateTime)', () {
      final now = DateTime.now();

      // String ISO
      final fromString = RoomRoll.fromMap({
        'id': '1',
        'timestamp': now.toIso8601String(),
      });
      expect(fromString.timestamp.difference(now).inSeconds.abs(), lessThanOrEqualTo(1));

      // Int epoch ms
      final fromInt = RoomRoll.fromMap({
        'id': '2',
        'timestamp': now.millisecondsSinceEpoch,
      });
      expect(fromInt.timestamp.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

      // DateTime
      final fromDt = RoomRoll.fromMap({
        'id': '3',
        'timestamp': now,
      });
      expect(fromDt.timestamp, now);

      // Null fallback
      final fromNull = RoomRoll.fromMap({
        'id': '4',
        'timestamp': null,
      });
      expect(fromNull.timestamp, isNotNull);
    });
  });

  group('DiceRoomService Unified Stream & Ingestion Tests', () {
    test('broadcasting roll updates active room stream subscriber', () async {
      final service = DiceRoomService();
      const roomCode = 'ROOM-SYNC-1';

      final roll = RoomRoll(
        id: 'r-1',
        roomCode: roomCode,
        playerName: 'Legolas',
        timestamp: DateTime.now(),
        formulaString: '1d20 + 7',
        total: 22,
        individualRolls: [15],
        isCrit: false,
        isFumble: false,
      );

      final stream = service.streamRoomRolls(roomCode);

      expectLater(
        stream,
        emits(predicate<List<RoomRoll>>((rolls) =>
            rolls.isNotEmpty && rolls.first.id == 'r-1' && rolls.first.playerName == 'Legolas')),
      );

      await service.broadcastRoll(roll);
    });

    test('ingestRemoteRoll pushes remote roll to subscribers and dedupes entries', () async {
      final service = DiceRoomService();
      const roomCode = 'ROOM-P2P-2';

      final roll = RoomRoll(
        id: 'remote-1',
        roomCode: roomCode,
        playerName: 'Gandalf',
        timestamp: DateTime.now(),
        formulaString: '8d6',
        total: 28,
        individualRolls: [3, 4, 2, 5, 6, 1, 4, 3],
        isCrit: false,
        isFumble: false,
      );

      final stream = service.streamRoomRolls(roomCode);

      final emissions = <List<RoomRoll>>[];
      final sub = stream.listen(emissions.add);

      // Ingest remote roll
      service.ingestRemoteRoll(roll);
      await pumpEventQueue();

      expect(emissions.last.any((r) => r.id == 'remote-1'), isTrue);

      // Ingest duplicate
      service.ingestRemoteRoll(roll);
      await pumpEventQueue();

      final matches = emissions.last.where((r) => r.id == 'remote-1').length;
      expect(matches, 1);

      await sub.cancel();
      service.disposeRoomStream(roomCode);
    });

    test('broadcastRoll forwards to IP2pTransportPort when registered in Service Locator', () async {
      final mockTransport = MockP2pTransport();
      sl.registerSingleton<IP2pTransportPort>(mockTransport);

      final service = DiceRoomService();
      const roomCode = 'ROOM-MESH-3';

      final roll = RoomRoll(
        id: 'mesh-1',
        roomCode: roomCode,
        playerName: 'Aragorn',
        timestamp: DateTime.now(),
        formulaString: '1d8 + 5',
        total: 12,
        individualRolls: [7],
        isCrit: false,
        isFumble: false,
      );

      await service.broadcastRoll(roll);

      expect(mockTransport.broadcasted, isNotEmpty);
      final decoded = jsonDecode(mockTransport.broadcasted.first) as Map<String, dynamic>;
      expect(decoded['type'], 'dice_roll');
      expect(decoded['roomCode'], 'ROOM-MESH-3');
      expect(decoded['payload']['id'], 'mesh-1');
      expect(decoded['payload']['playerName'], 'Aragorn');

      service.disposeRoomStream(roomCode);
    });
  });

  group('RoomSyncOrchestrator P2P Dice Roll Routing', () {
    test('receives type == "dice_roll" payload and ingests into DiceRoomService', () async {
      final mockTransport = MockP2pTransport();
      final diceService = DiceRoomService();
      const roomCode = 'ROOM-ORCH-4';

      final orchestrator = RoomSyncOrchestrator(
        transportPort: mockTransport,
        campaignRepo: MockCampaignRepo(),
        reconciliationService: RoomStateReconciliationService(),
        clockSyncService: ClockSyncService(networkTimePort: MockNetworkTimePort()),
        diceRoomService: diceService,
      );

      orchestrator.startSynchronization();

      final stream = diceService.streamRoomRolls(roomCode);
      final emissions = <List<RoomRoll>>[];
      final sub = stream.listen(emissions.add);

      final remotePayload = jsonEncode({
        'type': 'dice_roll',
        'roomCode': roomCode,
        'payload': {
          'id': 'orch-roll-99',
          'roomCode': roomCode,
          'playerName': 'Boromir',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'formulaString': '1d20 + 4',
          'total': 19,
          'individualRolls': [15],
          'isCrit': false,
          'isFumble': false,
        },
      });

      mockTransport.emitIncoming(remotePayload);
      await pumpEventQueue();

      expect(emissions.any((list) => list.any((r) => r.id == 'orch-roll-99')), isTrue);

      await sub.cancel();
      orchestrator.stopSynchronization();
      diceService.disposeRoomStream(roomCode);
    });
  });
}
