import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';

import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    await harness.setUp('party_room_char_test_');
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
  });

  group('PartyRoomService Characterization Test', () {
    test(
        'PartyRoomService built through DI uses the DI clock and registered IRoomDocumentPort',
        () async {
      final fakeRoomDocPort = RecordingRoomDocumentPort();
      await initServiceLocator(roomDocumentPort: fakeRoomDocPort);

      final partyService = sl<PartyRoomService>();
      final diClock = sl<StatefulHlcClock>();
      final diReplicaId = sl<ReplicaId>();

      // 1. Proves uses the DI clock and DI replica ID
      expect(identical(partyService.clock, diClock), isTrue);
      expect(partyService.replicaId, equals(diReplicaId));

      // 2. Proves uses registered IRoomDocumentPort by watching one write call land on the fake
      partyService.setFirebaseAvailableForTesting(true);

      await partyService.createCampaign(
        campaignName: 'Dragon Heist',
        playerName: 'DungeonMaster',
        customRoomCode: 'ROOM-ABC',
      );

      expect(fakeRoomDocPort.createRoomCalls.length, equals(1));
      expect(fakeRoomDocPort.createRoomCalls.first.roomCode, equals('ROOM-ABC'));
    });
  });
}
