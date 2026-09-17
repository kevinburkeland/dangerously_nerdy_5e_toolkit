import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';

class MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Map<String, int> peerLastSeen = const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _payloadController.stream;

  void emitPayload(String payload) {
    _payloadController.add(payload);
  }

  @override
  Future<void> disconnect() async {
    await _payloadController.close();
  }
}

class MockCampaignRepository implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final List<CampaignProfile> savedProfiles = [];
  final StreamController<CampaignProfile?> _profileController =
      StreamController<CampaignProfile?>.broadcast();
  final StreamController<List<CampaignProfile>> _allProfilesController =
      StreamController<List<CampaignProfile>>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;
  set activeProfile(CampaignProfile? profile) => _activeProfile = profile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => _activeProfile != null ? [_activeProfile!] : [];

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _profileController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allProfilesController.stream;

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _activeProfile?.id == id ? _activeProfile : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> saveProfile(CampaignProfile profile) async =>
      saveProfileImmediate(profile);

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    _activeProfile = profile;
    savedProfiles.add(profile);
    _profileController.add(profile);
    _allProfilesController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _profileController.add(null);
      _allProfilesController.add([]);
    }
  }

  Future<void> close() async {
    await _profileController.close();
    await _allProfilesController.close();
  }
}

class MockNetworkTimePort implements INetworkTimePort {
  int networkTimeMs;
  MockNetworkTimePort({this.networkTimeMs = 1000000});

  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

void main() {
  group('Authentic CRDT Synchronization & Delta Tests', () {
    late MockTransportPort mockTransport;
    late MockCampaignRepository mockRepo;
    late RoomStateReconciliationService reconciliationService;
    late MockNetworkTimePort mockTimePort;
    late ClockSyncService clockSyncService;
    late RoomSyncOrchestrator orchestrator;

    setUp(() {
      mockTransport = MockTransportPort();
      mockRepo = MockCampaignRepository();
      reconciliationService = RoomStateReconciliationService(
        networkTimeProvider: () => 1000000,
      );
      mockTimePort = MockNetworkTimePort();
      clockSyncService = ClockSyncService(networkTimePort: mockTimePort);

      orchestrator = RoomSyncOrchestrator(
        transportPort: mockTransport,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        hostNodeId: 'node-orchestrator',
        payloadMapper: const RoomSyncPayloadMapper(),
      );
    });

    test('PartyPurse PN-Counter CvRDT convergence across network partitions', () {
      // Both nodes start with an initial shared purse of 100 GP
      const initialPurse = PartyPurse(gp: 100);

      // Node A deposits 50 GP and withdraws 10 GP during partition
      var purseA = initialPurse
          .modifyCoin('gp', 50, nodeId: 'node_a')
          .modifyCoin('gp', -10, nodeId: 'node_a');

      // Node B concurrently deposits 30 GP and withdraws 5 GP during partition
      var purseB = initialPurse
          .modifyCoin('gp', 30, nodeId: 'node_b')
          .modifyCoin('gp', -5, nodeId: 'node_b');

      // Individual partitioned balances
      expect(purseA.gp, equals(140)); // 100 + 50 - 10
      expect(purseB.gp, equals(125)); // 100 + 30 - 5

      // Reconnect and converge: CvRDT lattice join
      final mergedPurse = purseA.merge(purseB);

      // Total expected: 100 (init) + 50 (A) + 30 (B) - 10 (A) - 5 (B) = 165 GP
      expect(mergedPurse.gp, equals(165));

      // Commutativity: B.merge(A) == A.merge(B)
      final mergedReverse = purseB.merge(purseA);
      expect(mergedReverse.gp, equals(165));
      expect(mergedReverse, equals(mergedPurse));
    });

    test('Granular CRDT Delta: mutating partyPurse emits crdt_purse_delta rather than full profile', () async {
      final baseProfile = CampaignProfile.defaultProfile(id: 'camp_delta');
      mockRepo.activeProfile = baseProfile;

      // Seed orchestrator baseline
      await orchestrator.handleLocalProfileChange(baseProfile);
      mockTransport.broadcastedPayloads.clear();

      // Mutate only partyPurse
      final updatedPurse = baseProfile.partyPurse.modifyCoin('gp', 250, nodeId: 'node-orchestrator');
      final updatedProfile = baseProfile.copyWith(partyPurse: updatedPurse);

      await orchestrator.handleLocalProfileChange(updatedProfile);

      expect(mockTransport.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockTransport.broadcastedPayloads.first) as Map<String, dynamic>;

      expect(decoded['type'], equals('crdt_purse_delta'));
      expect(decoded['origin_node_id'], equals('node-orchestrator'));
      expect(decoded['campaign_id'], equals('camp_delta'));
      expect(decoded['payload']['gp'], equals(250));
      expect(decoded['payload'].containsKey('gpCounter'), isTrue);
    });

    test('Ingress of crdt_purse_delta reconciles party purse via CvRDT lattice join', () async {
      final baseProfile = CampaignProfile.defaultProfile(id: 'camp_delta').copyWith(
        partyPurse: const PartyPurse(gp: 100).modifyCoin('gp', 50, nodeId: 'node-orchestrator'),
      );
      mockRepo.activeProfile = baseProfile;

      // Remote peer concurrently deposited 35 GP
      final remotePurse = const PartyPurse(gp: 100).modifyCoin('gp', 35, nodeId: 'node-remote');

      final deltaPayload = jsonEncode({
        'type': 'crdt_purse_delta',
        'origin_node_id': 'node-remote',
        'origin_seq': 42,
        'campaign_id': 'camp_delta',
        'payload': remotePurse.toMap(),
        'timestamp': 1005000,
      });

      await orchestrator.handleIncomingPayload(deltaPayload);

      expect(mockRepo.savedProfiles.isNotEmpty, isTrue);
      final converged = mockRepo.savedProfiles.last;

      // Converged GP: 100 (init) + 50 (orchestrator) + 35 (remote) = 185 GP
      expect(converged.partyPurse.gp, equals(185));
    });

    test('Full room_sync_full carries party_purse_crdt delta and converges without scalar LWW', () async {
      final baseProfile = CampaignProfile.defaultProfile(id: 'camp_full').copyWith(
        partyPurse: const PartyPurse(gp: 50).modifyCoin('gp', 20, nodeId: 'node-local'),
      );
      mockRepo.activeProfile = baseProfile;

      final remotePurse = const PartyPurse(gp: 50).modifyCoin('gp', 80, nodeId: 'node-remote');
      final remoteProfile = baseProfile.copyWith(
        name: 'Updated Campaign Title',
        partyPurse: remotePurse,
      );

      final fullSyncPayload = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote',
        'origin_seq': 10,
        'payload': {
          'id': remoteProfile.id,
          'name': remoteProfile.name,
          'edition': remoteProfile.edition.name,
          'createdAt': remoteProfile.createdAt.toIso8601String(),
          'lastPlayedAt': remoteProfile.lastPlayedAt.toIso8601String(),
          'roomState': remoteProfile.roomState.toMap(),
          'partyPurse': remotePurse.toMap(),
        },
        'party_purse_crdt': remotePurse.toMap(),
        'timestamp': 1002000,
      });

      await orchestrator.handleIncomingPayload(fullSyncPayload);

      expect(mockRepo.savedProfiles.isNotEmpty, isTrue);
      final reconciled = mockRepo.savedProfiles.last;

      expect(reconciled.name, equals('Updated Campaign Title'));
      // 50 (init) + 20 (local) + 80 (remote) = 150 GP
      expect(reconciled.partyPurse.gp, equals(150));
    });
  });
}
