import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';

class _FailingTransportPort implements IP2pTransportPort {
  bool broadcastShouldThrow = true;
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  String? get roomCode => 'ROOM-R7TEST';

  @override
  TransportState currentState = TransportState.connecting;

  @override
  Map<String, int> peerLastSeen = {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (broadcastShouldThrow) {
      throw StateError('Simulated transport broadcast failure');
    }
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;
}

class _FixedNetworkTimePort implements INetworkTimePort {
  const _FixedNetworkTimePort();

  @override
  Future<int> getNetworkTimeMs() async => 1700000000000;
}

class _FailingAppDatabaseService extends AppDatabaseService {
  final Set<String> failingPuts = {};

  _FailingAppDatabaseService() : super.custom();

  @override
  bool get isInitialized => true;

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    if (failingPuts.contains('$boxName:$key')) {
      throw StateError('Simulated database disk failure for put $boxName:$key');
    }
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) => defaultValue;

  @override
  Future<void> delete(String boxName, String key) async {}

  Future<void> clear(String boxName) async {}
}

class _MockInMemoryCampaignRepository implements ICampaignRepository {
  CampaignProfile? _activeProfile;

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles =>
      _activeProfile != null ? [_activeProfile!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _activeProfile?.id == id ? _activeProfile : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = (_activeProfile?.id == id)
        ? _activeProfile!
        : throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    _activeProfile = profile;
  }

  Future<void> saveProfile(CampaignProfile profile) async {
    await putProfile(profile);
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();

  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Pass 9 (R7): No Empty Catches & Failure Visibility', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      LoggingService.onNonFatalForTesting = null;
    });

    test(
        'Orchestrator: a transport whose broadcastPayload throws produces exactly one logged non-fatal per failed send',
        () async {
      final nonFatals = <String>[];
      LoggingService.onNonFatalForTesting = (exception, stackTrace, reason) {
        nonFatals.add('$reason: $exception');
      };

      final failingPort = _FailingTransportPort();
      final router = CascadingTransportRouter(
        localWifiAdapter: failingPort,
        webRtcAdapter: _FailingTransportPort()..broadcastShouldThrow = false,
        firebaseFallbackAdapter: _FailingTransportPort()..broadcastShouldThrow = false,
      );
      await router.initializeRoom('ROOM-R7TEST', 'node_test_r7');

      final clockSync = ClockSyncService(
        networkTimePort: const _FixedNetworkTimePort(),
        localTimeProvider: () => 1700000000000,
      );
      await clockSync.synchronizeClock();

      final mockRepo = _MockInMemoryCampaignRepository();

      final orchestrator = RoomSyncOrchestrator(
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('node_test_r7'),
        transportPort: failingPort,
        campaignRepo: mockRepo,
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => clockSync.currentNetworkTimeMs,
        ),
        clockSyncService: clockSync,
        clock: StatefulHlcClock(replicaId: ReplicaId('node_test_r7')),
        localTimeProvider: () => 1700000000000,
        isHost: false,
        telemetryInterval: const Duration(milliseconds: 50),
      );

      final profile = CampaignProfile(
        id: 'camp_r7_test',
        name: 'R7 Test Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        roomState: RoomNodeState(
          roomCode: 'ROOM-R7TEST',
          roomId: 'room_ROOM-R7TEST',
          title: 'Staging',
        ),
        nodeId: 'node_test_r7',
      );

      // Trigger local profile change which causes broadcastPayload
      await orchestrator.handleLocalProfileChange(profile);

      expect(nonFatals.length, equals(1),
          reason: 'Expected exactly one logged non-fatal for failed broadcast send');
      expect(
        nonFatals.first,
        contains('Failed to broadcast sync payload via transportPort'),
      );
      expect(
        nonFatals.first,
        contains('Simulated transport broadcast failure'),
      );

      orchestrator.stopSynchronization();
    });

    test(
        'setActiveProfileId with a failing disk write logs one non-fatal. The in-memory active id still changes, as today.',
        () async {
      final nonFatals = <String>[];
      LoggingService.onNonFatalForTesting = (exception, stackTrace, reason) {
        nonFatals.add('$reason: $exception');
      };

      final failingDb = _FailingAppDatabaseService();
      failingDb.failingPuts.add(
        '${AppDatabaseService.boxCampaignProfiles}:${LocalCampaignRepository.activeProfileIdKey}',
      );

      final repo = LocalCampaignRepository(
        db: failingDb,
        replicaId: ReplicaId('node_repo_test'),
        clock: StatefulHlcClock(replicaId: ReplicaId('node_repo_test')),
      );

      expect(repo.activeProfileId, isNull);

      await repo.setActiveProfileId('camp_active_fail_disk');

      // 1. One non-fatal logged
      expect(nonFatals.length, equals(1));
      expect(
        nonFatals.first,
        contains('Failed to persist active campaign profile ID: camp_active_fail_disk'),
      );

      // 2. In-memory active profile id still changed
      expect(repo.activeProfileId, equals('camp_active_fail_disk'));

      repo.dispose();
    });

    test(
        'Payload mapper: a full-profile message whose pinned-rules block is malformed logs a non-fatal, and the rest of the message is still applied as today',
        () {
      final nonFatals = <String>[];
      LoggingService.onNonFatalForTesting = (exception, stackTrace, reason) {
        nonFatals.add('$reason: $exception');
      };

      const mapper = RoomSyncPayloadMapper();

      final fullProfilePayload = json.encode({
        'type': 'room_sync_full',
        'origin_node_id': 'node_remote',
        'origin_seq': 10,
        'timestamp': 1700000000000,
        'payload': {
          'id': 'camp_mapper_test',
          'name': 'Mapper Test',
          'edition': 'dnd5e_2024',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'lastPlayedAt': '2024-01-01T00:00:00.000Z',
          'recordVersion': 1,
          'roomState': {
            'roomCode': 'ROOM-TEST1',
            'roomId': 'room_ROOM-TEST1',
          },
        },
        // Malformed pinned_rules_crdt: not a valid CRDT OR-set structure
        'pinned_rules_crdt': {
          'entries': 'this_should_be_a_map_not_a_string',
        },
      });

      final message = mapper.parsePayload(fullProfilePayload);

      expect(message, isA<FullProfileSyncMessage>());
      final fullMsg = message as FullProfileSyncMessage;

      // Malformed pinned-rules delta produced one logged non-fatal
      expect(nonFatals.length, equals(1));
      expect(
        nonFatals.first,
        contains('Failed to decode pinned_rules_crdt in full profile payload'),
      );

      // pinnedRulesDelta is null because decoding failed
      expect(fullMsg.pinnedRulesDelta, isNull);

      // Rest of the message was parsed successfully
      expect(fullMsg.profile.id, equals('camp_mapper_test'));
      expect(fullMsg.originNodeId, equals('node_remote'));
      expect(fullMsg.originSeq, equals(10));
    });
  });
}
