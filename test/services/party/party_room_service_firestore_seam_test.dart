import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';

import '../../test_doubles/fake_room_document_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingRoomDocumentPort fakeRoomDocPort;
  late ReplicaId replicaId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    replicaId = ReplicaId('replica-dm-1');
    fakeRoomDocPort = RecordingRoomDocumentPort();

    await initServiceLocator(
      replicaId: replicaId,
      roomDocumentPort: fakeRoomDocPort,
    );
  });

  tearDown(() {
    sl.reset();
  });

  group('PartyRoomService Firestore Seam & Invariants (R2 & R6)', () {
    test('deleteCampaign sends host proof and room delete; denies throw and preserve membership', () async {
      const roomCode = 'ROOM_DEL1';
      const hostKey = 'd28d0bb5-f129-43c2-bf72-a1b7396c21e4';
      final hostKeyHash = CryptoUtils.sha256Hex(CryptoUtils.extractHostKey(hostKey));

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);
      final registry = CampaignRegistryService();

      // Pre-seed local membership
      await registry.saveMembership(CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
        role: CampaignRole.host,
        hostKey: hostKey,
        characterId: 'DM',
        lastPlayed: DateTime.now(),
      ));

      service.cacheLobbyForTesting(PartyRoomLobby(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
        hostKeyHash: hostKeyHash,
        activePlayers: const ['DM'],
        partyTelemetry: const {},
        sharedCharacters: const {},
        version: 1,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ));

      // 1. Simulate server denial
      fakeRoomDocPort.shouldThrowOnDelete =
          UnauthorizedHostActionException('Server denied room deletion.');

      await expectLater(
        () => service.deleteCampaign(roomCode: roomCode, hostKey: hostKey),
        throwsA(isA<UnauthorizedHostActionException>()),
      );

      // Invariant: membership and local state are preserved on server denial!
      expect(registry.getMembership(roomCode), isNotNull);
      expect(service.getCachedLobby(roomCode), isNotNull);
      expect(fakeRoomDocPort.deleteRoomCalls.length, equals(1));
      expect(fakeRoomDocPort.deleteRoomCalls.first.roomCode, equals(roomCode));
      expect(fakeRoomDocPort.deleteRoomCalls.first.hostKey, equals(hostKey));

      // 2. Simulate server approval
      fakeRoomDocPort.shouldThrowOnDelete = null;
      await service.deleteCampaign(roomCode: roomCode, hostKey: hostKey);

      // Invariant: membership and local state are purged on server success!
      expect(registry.getMembership(roomCode), isNull);
      expect(service.getCachedLobby(roomCode), isNull);
      expect(fakeRoomDocPort.deleteRoomCalls.length, equals(2));
    });

    test('createCampaign is create-only; throws RoomAlreadyExistsException if doc exists', () async {
      const roomCode = 'ROOM_EXISTING';
      fakeRoomDocPort.existingRooms.add(roomCode);

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);
      final registry = CampaignRegistryService();

      await expectLater(
        () => service.createCampaign(
          customRoomCode: roomCode,
          campaignName: 'New Campaign',
          playerName: 'DM',
        ),
        throwsA(isA<RoomAlreadyExistsException>()),
      );

      // Invariant: local registry is NOT updated if server rejected code
      expect(registry.getMembership(roomCode), isNull);
      expect(service.getCachedLobby(roomCode), isNull);
    });

    test('ensureRoomExists without hostKey refreshes lease and NEVER creates doc', () async {
      const roomCode = 'ROOM_PLAYER1';
      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);

      await service.ensureRoomExists(
        roomCode: roomCode,
        campaignName: 'Player Room',
        hostKey: null, // Membership without host key
        isStateless: false,
      );

      expect(fakeRoomDocPort.touchRoomLeaseCalls.length, equals(1));
      final call = fakeRoomDocPort.touchRoomLeaseCalls.first;
      expect(call.roomCode, equals(roomCode));
      expect(call.createIfAbsent, isFalse); // Invariant: never create if absent
      expect(fakeRoomDocPort.existingRooms.contains(roomCode), isFalse);
    });

    test('ensureRoomExists with hostKey sets createIfAbsent: true', () async {
      const roomCode = 'ROOM_HOST1';
      const hostKey = 'c7a202d0-0000-0000-0000-000000000000';
      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);

      await service.ensureRoomExists(
        roomCode: roomCode,
        campaignName: 'Host Room',
        hostKey: hostKey,
        isStateless: false,
      );

      expect(fakeRoomDocPort.touchRoomLeaseCalls.length, equals(1));
      final call = fakeRoomDocPort.touchRoomLeaseCalls.first;
      expect(call.roomCode, equals(roomCode));
      expect(call.createIfAbsent, isTrue);
    });

    test('flushOutbox drops createRoom action when room already exists and does not block queue', () async {
      const roomCode = 'ROOM_FLUSH_EXIST';
      fakeRoomDocPort.existingRooms.add(roomCode);

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);

      // Add a createRoom action directly to the outbox
      service.queueOutboxActionForTesting(PartyOutboxAction(
        id: 'action_1',
        roomCode: roomCode,
        actionType: 'createRoom',
        payload: {'roomCode': roomCode},
        timestamp: DateTime.now(),
      ));

      expect(service.getOutboxCountForTesting(roomCode), equals(1));

      await service.flushOutbox(roomCode);

      // Invariant: action is dropped from outbox so it does not retry forever
      expect(service.getOutboxCountForTesting(roomCode), equals(0));
    });
  });
}
