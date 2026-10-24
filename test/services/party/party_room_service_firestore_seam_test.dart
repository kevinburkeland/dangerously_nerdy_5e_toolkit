import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/adapters/storage/firestore_room_document_adapter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/crypto_utils.dart';

import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/hive_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingRoomDocumentPort fakeRoomDocPort;
  late ReplicaId replicaId;
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUp('party_firestore_');
    sl.reset();
    replicaId = ReplicaId('replica-dm-1');
    fakeRoomDocPort = RecordingRoomDocumentPort();

    await initServiceLocator(
      replicaId: replicaId,
      roomDocumentPort: fakeRoomDocPort,
    );
  });

  tearDown(() async {
    sl.reset();
    await harness.tearDown();
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

      final ts = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: replicaId.value);
      await sl<ICampaignRepository>().putProfile(CampaignProfile.defaultProfile(
        id: 'campaign_$roomCode',
        nodeId: replicaId.value,
        timestamp: ts,
      ).copyWith(
        roomState: RoomNodeState(
          roomId: 'room_$roomCode',
          roomCode: roomCode,
          title: 'Player Room',
          titleTimestamp: ts,
          description: '',
          descriptionTimestamp: ts,
        ),
      ));

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

      final ts = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: replicaId.value);
      await sl<ICampaignRepository>().putProfile(CampaignProfile.defaultProfile(
        id: 'campaign_$roomCode',
        nodeId: replicaId.value,
        timestamp: ts,
      ).copyWith(
        roomState: RoomNodeState(
          roomId: 'room_$roomCode',
          roomCode: roomCode,
          title: 'Host Room',
          titleTimestamp: ts,
          description: '',
          descriptionTimestamp: ts,
        ),
      ));

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

    test('planRoomDelete example cases: absent, hostless with and without key, empty hash, hosted with right key, hosted with no key', () {
      // 1. Absent room
      expect(planRoomDelete(null, 'key-123'), equals(RoomDeletePlan.none));
      expect(planRoomDelete(null, null), equals(RoomDeletePlan.none));

      // 2. Hostless without a key
      expect(planRoomDelete({'roomCode': 'ROOM1'}, null), equals(RoomDeletePlan.plainDelete));
      expect(planRoomDelete({'roomCode': 'ROOM1'}, ''), equals(RoomDeletePlan.plainDelete));

      // 3. Hostless with a key
      expect(planRoomDelete({'roomCode': 'ROOM1'}, 'some-key'), equals(RoomDeletePlan.plainDelete));

      // 4. '' hash with a key
      expect(planRoomDelete({'roomCode': 'ROOM1', 'hostKeyHash': ''}, 'some-key'), equals(RoomDeletePlan.plainDelete));
      expect(planRoomDelete({'roomCode': 'ROOM1', 'hostKeyHash': ''}, null), equals(RoomDeletePlan.plainDelete));

      // 5. Hosted with the right key
      expect(planRoomDelete({'roomCode': 'ROOM1', 'hostKeyHash': 'a' * 64}, 'right-key'), equals(RoomDeletePlan.proofAndDelete));

      // 6. Hosted with no key
      expect(planRoomDelete({'roomCode': 'ROOM1', 'hostKeyHash': 'a' * 64}, null), equals(RoomDeletePlan.unauthorized));
      expect(planRoomDelete({'roomCode': 'ROOM1', 'hostKeyHash': 'a' * 64}, ''), equals(RoomDeletePlan.unauthorized));
    });

    test('planRoomDelete law test: 300+ seeded random inputs verify decision invariants', () {
      final rand = math.Random(1337);
      const totalSeeds = 320;

      for (int seed = 1; seed <= totalSeeds; seed++) {
        // Room absent or present
        final isAbsent = rand.nextBool();
        Map<String, dynamic>? roomData;

        // Hash absent, '', or 64 hex characters
        final hashChoice = rand.nextInt(3); // 0: absent, 1: '', 2: 64 hex
        String? hashValue;
        if (hashChoice == 1) {
          hashValue = '';
        } else if (hashChoice == 2) {
          hashValue = List.generate(64, (_) => rand.nextInt(16).toRadixString(16)).join();
        }

        if (!isAbsent) {
          roomData = <String, dynamic>{
            'roomCode': 'ROOM_$seed',
            'campaignName': 'Campaign $seed',
          };
          if (hashValue != null) {
            roomData['hostKeyHash'] = hashValue;
          }
        }

        // Key absent, '', or random string
        final keyChoice = rand.nextInt(3); // 0: null, 1: '', 2: random string
        String? hostKey;
        if (keyChoice == 1) {
          hostKey = '';
        } else if (keyChoice == 2) {
          hostKey = 'key_${rand.nextInt(100000)}_${rand.nextDouble()}';
        }

        final plan = planRoomDelete(roomData, hostKey);

        final isRoomPresent = roomData != null;
        final hasNonEmptyHash = isRoomPresent &&
            roomData['hostKeyHash'] is String &&
            (roomData['hostKeyHash'] as String).isNotEmpty;
        final hasNonEmptyKey = hostKey != null && hostKey.isNotEmpty;

        // Law assertion 1: includes proof exactly when room is present with non-empty hash and non-empty key
        final expectedProofAndDelete = hasNonEmptyHash && hasNonEmptyKey;
        expect(
          plan == RoomDeletePlan.proofAndDelete,
          equals(expectedProofAndDelete),
          reason: 'Seed $seed failed proofAndDelete invariant',
        );

        // Law assertion 2: unauthorized exactly when room is hosted and key is absent or empty
        final expectedUnauthorized = hasNonEmptyHash && !hasNonEmptyKey;
        expect(
          plan == RoomDeletePlan.unauthorized,
          equals(expectedUnauthorized),
          reason: 'Seed $seed failed unauthorized invariant',
        );

        // Law assertion 3: writes nothing exactly when room is absent
        expect(
          plan == RoomDeletePlan.none,
          equals(!isRoomPresent),
          reason: 'Seed $seed failed none (absent) invariant',
        );

        // Law assertion 4: plain delete when room is present and hostless
        if (isRoomPresent && !hasNonEmptyHash) {
          expect(
            plan,
            equals(RoomDeletePlan.plainDelete),
            reason: 'Seed $seed failed plainDelete invariant',
          );
        }
      }
    });

    test('buildHostProofPayload produces exactly keys hostKey and at (FieldValue)', () {
      const hostKey = 'c7a202d0-9f5b-4e6f-8d2a-112233445566';
      final payload = buildHostProofPayload(hostKey);

      expect(payload.keys.toSet(), equals({'hostKey', 'at'}));
      expect(payload['hostKey'], equals(CryptoUtils.extractHostKey(hostKey)));
      expect(payload['at'], isA<FieldValue>());
    });

    test('G1: deleteCampaign when room is already gone on server removes local membership', () async {
      const roomCode = 'ROOM_GONE';
      const hostKey = 'd28d0bb5-f129-43c2-bf72-a1b7396c21e4';
      final hostKeyHash = CryptoUtils.sha256Hex(CryptoUtils.extractHostKey(hostKey));

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);
      final registry = CampaignRegistryService();

      await registry.saveMembership(CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Gone Campaign',
        role: CampaignRole.host,
        hostKey: hostKey,
        characterId: 'DM',
        lastPlayed: DateTime.now(),
      ));

      service.cacheLobbyForTesting(PartyRoomLobby(
        roomCode: roomCode,
        campaignName: 'Gone Campaign',
        hostKeyHash: hostKeyHash,
        activePlayers: const ['DM'],
        partyTelemetry: const {},
        sharedCharacters: const {},
        version: 1,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ));

      // Room is NOT in fakeRoomDocPort.existingRooms -> deleteRoomWithHostProof returns alreadyGone
      expect(fakeRoomDocPort.existingRooms.contains(roomCode), isFalse);

      await service.deleteCampaign(roomCode: roomCode, hostKey: hostKey);

      // Invariant: local state and membership are purged
      expect(registry.getMembership(roomCode), isNull);
      expect(service.getCachedLobby(roomCode), isNull);
    });

    test('deleteCampaign on server denial throws UnauthorizedHostActionException and preserves membership', () async {
      const roomCode = 'ROOM_DENIED';
      const hostKey = 'd28d0bb5-f129-43c2-bf72-a1b7396c21e4';

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);
      final registry = CampaignRegistryService();

      await registry.saveMembership(CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Denied Campaign',
        role: CampaignRole.host,
        hostKey: hostKey,
        characterId: 'DM',
        lastPlayed: DateTime.now(),
      ));

      fakeRoomDocPort.shouldThrowOnDelete =
          UnauthorizedHostActionException('Server denied room deletion.');

      await expectLater(
        () => service.deleteCampaign(roomCode: roomCode, hostKey: hostKey),
        throwsA(isA<UnauthorizedHostActionException>()),
      );

      // Invariant: membership preserved
      expect(registry.getMembership(roomCode), isNotNull);
    });

    test('deleteCampaign on network error rethrows original error and preserves membership', () async {
      const roomCode = 'ROOM_NET_ERR';
      const hostKey = 'd28d0bb5-f129-43c2-bf72-a1b7396c21e4';

      final service = sl<PartyRoomService>();
      service.setFirebaseAvailableForTesting(true);
      final registry = CampaignRegistryService();

      await registry.saveMembership(CampaignMembership(
        roomCode: roomCode,
        campaignName: 'Network Error Campaign',
        role: CampaignRole.host,
        hostKey: hostKey,
        characterId: 'DM',
        lastPlayed: DateTime.now(),
      ));

      fakeRoomDocPort.shouldThrowOnDelete =
          const SocketException('Connection reset by peer');

      await expectLater(
        () => service.deleteCampaign(roomCode: roomCode, hostKey: hostKey),
        throwsA(isA<SocketException>()),
      );

      // Invariant: membership preserved
      expect(registry.getMembership(roomCode), isNotNull);
    });
  });
}
