import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

import '../../test_doubles/fake_campaign_repository.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';
import '../../test_doubles/service_test_configurator.dart';

class _RecordingTransport implements IP2pTransportPort {
  final List<({String roomCode, String localNodeId})> initializedRooms = [];
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();

  @override
  TransportState get currentState => TransportState.offline;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      false;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    initializedRooms.add((roomCode: roomCode, localNodeId: localNodeId));
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  @override
  Future<void> disconnect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    resetTestServices();
    await harness.setUp('party_room_dice_iso_');
  });

  tearDown(() async {
    resetTestServices();
    sl.reset();
    await harness.tearDown();
  });

  group('PartyRoomService DiceRoomService Isolation', () {
    test(
        'PartyRoomService.newInstance does not use global DiceRoomService and throws when unbound',
        () async {
      final globalTransport = _RecordingTransport();
      configureTestDiceRoomService(transport: globalTransport);

      final repId = ReplicaId('iso_replica_1');
      final clock = StatefulHlcClock(replicaId: repId);
      final repo = FakeCampaignRepository();
      final roomDocPort = RecordingRoomDocumentPort();
      configureTestServices(
        repository: repo,
        replicaId: repId,
        clock: clock,
      );

      // Build PartyRoomService.newInstance WITHOUT passing a diceRoomService
      final isolatedParty = PartyRoomService.newInstance(
        replicaId: repId,
        clock: clock,
        roomDocumentPort: roomDocPort,
      );

      // Call public method that reaches _diceRoomService.joinRoom
      expect(
        () => isolatedParty.createCampaign(
          campaignName: 'Unbound Test',
          playerName: 'Player1',
          customRoomCode: 'UNBOUND1',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('DiceRoomService'),
          ),
        ),
      );

      // Verify global fake transport was NEVER touched
      expect(globalTransport.initializedRooms, isEmpty);

      // Control case: build another PartyRoomService.newInstance passing createBoundTestDiceRoomService
      final isolatedTransport = _RecordingTransport();
      final boundDiceService = createBoundTestDiceRoomService(
        transport: isolatedTransport,
      );

      final repId2 = ReplicaId('iso_replica_2');
      final clock2 = StatefulHlcClock(replicaId: repId2);

      final controlledParty = PartyRoomService.newInstance(
        replicaId: repId2,
        clock: clock2,
        roomDocumentPort: roomDocPort,
        diceRoomService: boundDiceService,
      );

      await controlledParty.createCampaign(
        campaignName: 'Bound Test',
        playerName: 'Player2',
        customRoomCode: 'BOUND01',
      );

      // Wait a microtask / tick if transport connection is async
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Reaches isolated transport once
      expect(isolatedTransport.initializedRooms.length, equals(1));
      expect(
          isolatedTransport.initializedRooms.first.roomCode, equals('BOUND01'));

      // Global fake transport still untouched
      expect(globalTransport.initializedRooms, isEmpty);
    });
  });
}
