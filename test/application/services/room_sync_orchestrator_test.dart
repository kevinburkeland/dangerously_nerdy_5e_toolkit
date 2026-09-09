import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/crdt_or_set.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/crdt/hybrid_logical_clock.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_network_time_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

class MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incomingController = StreamController<String>.broadcast();
  bool broadcastShouldThrow = false;
  bool isDisconnected = false;

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (broadcastShouldThrow) {
      throw StateError('Simulated transport broadcast failure');
    }
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) {
    _incomingController.add(payload);
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    isDisconnected = true;
    await _incomingController.close();
  }
}

class MockCampaignRepository implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final StreamController<CampaignProfile?> _activeProfileController =
      StreamController<CampaignProfile?>.broadcast();
  final List<CampaignProfile> savedImmediateProfiles = [];
  bool emitOnSaveImmediate = false;

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
    savedImmediateProfiles.add(profile);
    if (emitOnSaveImmediate) {
      _activeProfileController.add(profile);
    }
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeProfileController.add(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeProfileController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();

  void emitProfile(CampaignProfile? profile) {
    _activeProfile = profile;
    _activeProfileController.add(profile);
  }

  void dispose() {
    _activeProfileController.close();
  }
}

class MockNetworkTimePort implements INetworkTimePort {
  int networkTimeMs;
  MockNetworkTimePort({this.networkTimeMs = 1700000000000});

  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

void main() {
  group('RoomSyncOrchestrator Tests', () {
    late MockTransportPort mockTransport;
    late MockCampaignRepository mockRepo;
    late RoomStateReconciliationService reconciliationService;
    late MockNetworkTimePort mockTimePort;
    late ClockSyncService clockSyncService;
    late RoomSyncOrchestrator orchestrator;

    final initialProfile = CampaignProfile(
      id: 'campaign-123',
      name: 'Curse of the Frost',
      edition: DmRulesEdition.v2024,
      createdAt: DateTime.utc(2026, 1, 1),
      lastPlayedAt: DateTime.utc(2026, 1, 1),
      roomState: const RoomNodeState(
        roomId: 'room-123',
        roomCode: 'CR-101',
        title: 'Tavern Staging',
      ),
      pinnedRuleIds: const {'concentration', 'cover'},
    );

    setUp(() async {
      mockTransport = MockTransportPort();
      mockRepo = MockCampaignRepository();
      mockRepo.emitProfile(initialProfile);

      reconciliationService = RoomStateReconciliationService();
      mockTimePort = MockNetworkTimePort(networkTimeMs: 1700000000500);
      clockSyncService = ClockSyncService(
        networkTimePort: mockTimePort,
        localTimeProvider: () => 1700000000000, // 500ms skew
      );
      await clockSyncService.synchronizeClock();

      orchestrator = RoomSyncOrchestrator(
        transportPort: mockTransport,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        isHost: false,
      );
    });

    tearDown(() {
      orchestrator.stopSynchronization();
      mockRepo.dispose();
    });

    test('Echo Cancellation Test: inbound save does not echo back to transport mesh', () async {
      mockRepo.emitOnSaveImmediate = true;
      orchestrator.startSynchronization();

      // Remote profile update
      final remoteProfile = initialProfile.copyWith(
        name: 'Curse of the Frost - Chapter 2',
      );
      final remoteDto = CampaignProfileDto.fromDomain(remoteProfile);
      final inboundJson = jsonEncode({
        'type': 'room_sync_full',
        'payload': remoteDto.toMap(),
        'timestamp': 1700000001000,
      });

      // Inject inbound network payload
      await orchestrator.handleIncomingPayload(inboundJson);

      // Verify profile was saved locally
      expect(mockRepo.savedImmediateProfiles.length, equals(1));
      expect(mockRepo.savedImmediateProfiles.first.name, equals('Curse of the Frost - Chapter 2'));

      // Assert that echo loop prevention mutex suppressed broadcastPayload()
      expect(mockTransport.broadcastedPayloads, isEmpty);
    });

    test('Outbound Sync Test: genuine local UI mutation triggers mesh broadcast', () async {
      orchestrator.startSynchronization();

      final updatedProfile = initialProfile.copyWith(
        name: 'Locally Mutated Campaign Title',
        pinnedRuleIds: {'concentration', 'cover', 'resting'},
      );

      // Trigger local mutation
      mockRepo.emitProfile(updatedProfile);

      // Allow event loop to process stream listener
      await Future<void>.delayed(Duration.zero);

      expect(mockTransport.broadcastedPayloads.length, equals(1));

      final broadcasted = jsonDecode(mockTransport.broadcastedPayloads.first) as Map<String, dynamic>;
      expect(broadcasted['type'], equals('room_sync_full'));
      expect(broadcasted['payload'], isNotNull);
      expect(broadcasted['payload']['name'], equals('Locally Mutated Campaign Title'));
      // Clock offset (500ms) should be reflected in timestamp
      expect(broadcasted['timestamp'], greaterThan(1700000000000));
    });

    test('Microtask Lock Release Test: mutex unlocks after inbound cycle allowing subsequent broadcasts', () async {
      mockRepo.emitOnSaveImmediate = true;
      orchestrator.startSynchronization();

      final remoteProfile = initialProfile.copyWith(
        name: 'Inbound Remote Update',
      );
      final inboundJson = jsonEncode({
        'type': 'room_sync_full',
        'payload': CampaignProfileDto.fromDomain(remoteProfile).toMap(),
        'timestamp': 1700000001000,
      });

      await orchestrator.handleIncomingPayload(inboundJson);

      // Mutex should be locked or immediately releasing via microtask
      await Future<void>.microtask(() {});

      // After microtask drain, mutex must be reset to false
      expect(orchestrator.isProcessingNetworkPayload, isFalse);

      // Subsequent local UI change must now broadcast freely
      final userEditProfile = remoteProfile.copyWith(name: 'Subsequent Local User Edit');
      mockRepo.emitProfile(userEditProfile);

      await Future<void>.delayed(Duration.zero);

      expect(mockTransport.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockTransport.broadcastedPayloads.first) as Map<String, dynamic>;
      expect(decoded['payload']['name'], equals('Subsequent Local User Edit'));
    });

    test('CvRDT Delta Merge Test: crdt_or_set_delta reconciles active values and tombstones', () async {
      orchestrator.startSynchronization();

      // Setup local tracked CRDT set with item 'grapple'
      const ts1 = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const ts2 = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');

      orchestrator.trackedRulesSet = const CrdtOrSet<String>().add('grapple', 'grapple', ts1);

      // Inbound remote delta has 'cover' (newer) and a tombstone for 'grapple' (newer ts2)
      final remoteSet = const CrdtOrSet<String>()
          .add('cover', 'cover', ts2)
          .add('grapple', 'grapple', ts1)
          .remove('grapple', ts2);

      final deltaMap = CrdtOrSetDto.toMap<String>(remoteSet, (v) => v);
      final inboundJson = jsonEncode({
        'type': 'crdt_or_set_delta',
        'payload': deltaMap,
        'timestamp': 1700000002000,
      });

      await orchestrator.handleIncomingPayload(inboundJson);

      // Verify convergence: 'grapple' tombstoned, 'cover' active
      expect(orchestrator.trackedRulesSet.items.containsKey('cover'), isTrue);
      expect(orchestrator.trackedRulesSet.items.containsKey('grapple'), isFalse);
      expect(orchestrator.trackedRulesSet.tombstones.containsKey('grapple'), isTrue);
      expect(orchestrator.trackedRulesSet.activeValues, equals(['cover']));

      // Profile pinnedRuleIds updated
      expect(mockRepo.savedImmediateProfiles.isNotEmpty, isTrue);
      final lastSaved = mockRepo.savedImmediateProfiles.last;
      expect(lastSaved.pinnedRuleIds, contains('cover'));
      expect(lastSaved.pinnedRuleIds, isNot(contains('grapple')));
    });

    test('Host Milestone Prune Test: host flushes snapshot and prunes historical tombstones', () async {
      final hostOrchestrator = RoomSyncOrchestrator(
        transportPort: mockTransport,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        isHost: true,
        hostNodeId: 'dm-host-prime',
        milestoneInterval: const Duration(milliseconds: 100),
      );

      // Pre-seed tombstones in past (older than snapshot) and in future (relative to snapshot)
      const oldTombstoneTs = HybridLogicalClock(
        physicalTime: 1000000,
        logicalCounter: 0,
        nodeId: 'node-remote',
      );
      const recentTombstoneTs = HybridLogicalClock(
        physicalTime: 9999999999999, // far future
        logicalCounter: 0,
        nodeId: 'node-remote',
      );

      hostOrchestrator.trackedRulesSet = const CrdtOrSet<String>(
        items: {},
        tombstones: {
          'old_rule': oldTombstoneTs,
          'recent_rule': recentTombstoneTs,
        },
      );

      // Execute host milestone flush
      await hostOrchestrator.executeHostMilestoneFlush();

      // Verify old tombstone was pruned, recent tombstone preserved
      expect(hostOrchestrator.trackedRulesSet.tombstones.containsKey('old_rule'), isFalse);
      expect(hostOrchestrator.trackedRulesSet.tombstones.containsKey('recent_rule'), isTrue);

      // Verify active profile was immediately saved
      expect(mockRepo.savedImmediateProfiles.isNotEmpty, isTrue);

      hostOrchestrator.stopSynchronization();
    });

    test('Teardown & Cleanup Test: stopSynchronization releases subscriptions and timers cleanly', () {
      orchestrator.startSynchronization();
      expect(orchestrator.isSynchronizing, isTrue);

      orchestrator.stopSynchronization();
      expect(orchestrator.isSynchronizing, isFalse);
    });
  });
}
