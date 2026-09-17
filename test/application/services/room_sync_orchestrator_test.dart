import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_connection_telemetry.dart';
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
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';

class MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incomingController = StreamController<String>.broadcast();
  bool broadcastShouldThrow = false;
  bool initializeShouldThrow = false;
  bool isDisconnected = false;
  void Function(String payload)? onBroadcast;

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
    broadcastedPayloads.add(jsonPayload);
    onBroadcast?.call(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) {
    _incomingController.add(payload);
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    if (initializeShouldThrow) {
      throw StateError('Simulated initialization failure');
    }
  }

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
  set activeProfile(CampaignProfile? profile) => _activeProfile = profile;

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
  setUpAll(() {
    IRoomSyncPayloadPort.defaultProvider = () => const RoomSyncPayloadMapper();
  });

  group('RoomSyncOrchestrator Tests', () {
    late MockTransportPort mockWifi;
    late MockTransportPort mockWebRtc;
    late MockTransportPort mockFallback;
    late CascadingTransportRouter router;
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
      mockWifi = MockTransportPort()..initializeShouldThrow = true;
      mockWebRtc = MockTransportPort();
      mockFallback = MockTransportPort();
      router = CascadingTransportRouter(
        localWifiAdapter: mockWifi,
        webRtcAdapter: mockWebRtc,
        firebaseFallbackAdapter: mockFallback,
      );
      await router.initializeRoom('CR-101', 'localNode1');

      mockRepo = MockCampaignRepository();
      mockRepo.emitProfile(initialProfile);

      mockTimePort = MockNetworkTimePort(networkTimeMs: 1700000000500);
      clockSyncService = ClockSyncService(
        networkTimePort: mockTimePort,
        localTimeProvider: () => 1700000000000, // 500ms skew
      );
      await clockSyncService.synchronizeClock();

      reconciliationService = RoomStateReconciliationService(
        networkTimeProvider: () => clockSyncService.currentNetworkTimeMs,
      );

      orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        localTimeProvider: () => 1700000000500,
        isHost: false,
        telemetryInterval: const Duration(milliseconds: 50),
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
      expect(mockWebRtc.broadcastedPayloads, isEmpty);
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

      expect(mockWebRtc.broadcastedPayloads.length, equals(1));

      final broadcasted = jsonDecode(mockWebRtc.broadcastedPayloads.first) as Map<String, dynamic>;
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

      expect(mockWebRtc.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockWebRtc.broadcastedPayloads.first) as Map<String, dynamic>;
      expect(decoded['payload']['name'], equals('Subsequent Local User Edit'));
    });

    test('CvRDT Delta Merge Test: crdt_or_set_delta reconciles active values and tombstones', () async {
      orchestrator.startSynchronization();

      // Setup local tracked CRDT set with item 'grapple'
      const ts1 = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'nodeA');
      const ts2 = HybridLogicalClock(physicalTime: 2000, logicalCounter: 0, nodeId: 'nodeB');

      orchestrator.trackedRulesSet = const CrdtOrSet<String>.empty().add('grapple', 'grapple', ts1);

      // Inbound remote delta has 'cover' (newer) and a tombstone for 'grapple' (newer ts2)
      final remoteSet = const CrdtOrSet<String>.empty()
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
        router: router,
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

      hostOrchestrator.trackedRulesSet = CrdtOrSet<String>(
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

    test('Telemetry Stream Test: watchTelemetry emits periodic telemetry reflecting router state and peerCount', () async {
      router.recordPeerHeartbeat('peer-1');
      router.recordPeerHeartbeat('peer-2');

      final emittedTelemetry = <RoomConnectionTelemetry>[];
      final sub = orchestrator.watchTelemetry().listen(emittedTelemetry.add);

      orchestrator.startSynchronization();

      // Initial emission happens immediately on startSynchronization
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emittedTelemetry.isNotEmpty, isTrue);
      expect(emittedTelemetry.first.state, equals(TransportState.p2pEstablished));
      expect(emittedTelemetry.first.peerCount, equals(2));
      expect(emittedTelemetry.first.connectionLabel, equals('WebRTC P2P'));
      expect(emittedTelemetry.first.isOffline, isFalse);

      // Wait for periodic timer (50ms)
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(emittedTelemetry.length, greaterThanOrEqualTo(2));

      await sub.cancel();
    });

    test('Teardown & Cleanup Test: stopSynchronization releases subscriptions and timers cleanly', () {
      orchestrator.startSynchronization();
      expect(orchestrator.isSynchronizing, isTrue);

      orchestrator.stopSynchronization();
      expect(orchestrator.isSynchronizing, isFalse);
    });

    test('TransportPort fallback test: generic IP2pTransportPort defaults to connecting and peerCount 0', () async {
      final genericMock = MockTransportPort();
      final genericOrchestrator = RoomSyncOrchestrator(
        transportPort: genericMock,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        telemetryInterval: const Duration(milliseconds: 20),
      );

      expect(genericOrchestrator.router, isNull);
      expect(genericOrchestrator.telemetryInterval, equals(const Duration(milliseconds: 20)));

      final telemetrySnapshots = <RoomConnectionTelemetry>[];
      final sub = genericOrchestrator.watchTelemetry().listen(telemetrySnapshots.add);

      genericOrchestrator.startSynchronization();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(telemetrySnapshots.isNotEmpty, isTrue);
      expect(telemetrySnapshots.first.state, equals(TransportState.connecting));
      expect(telemetrySnapshots.first.peerCount, equals(0));
      expect(telemetrySnapshots.first.isOffline, isTrue);

      await sub.cancel();
      genericOrchestrator.stopSynchronization();
    });

    test('Interface Polymorphism Verification: generic mock IP2pTransportPort directly drives currentTelemetry', () {
      final genericMock = MockTransportPort()
        ..currentState = TransportState.localWifi
        ..peerLastSeen = {'peerA': 1000, 'peerB': 2000};

      final genericOrchestrator = RoomSyncOrchestrator(
        transportPort: genericMock,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
      );

      // Verify that currentTelemetry accurately reflects port state without casting
      final telemetry = genericOrchestrator.currentTelemetry;
      expect(telemetry.state, equals(TransportState.localWifi));
      expect(telemetry.peerCount, equals(2));
      expect(telemetry.isOffline, isFalse);
    });

    test('Deadlock Prevention Test: broadcast failure steps down to fallbackRelay while fallback adapter emits inbound packet without deadlock', () async {
      // Re-initialize router with sequentialFailureThreshold: 1 to simulate immediate step-down failover
      router = CascadingTransportRouter(
        localWifiAdapter: mockWifi,
        webRtcAdapter: mockWebRtc,
        firebaseFallbackAdapter: mockFallback,
        sequentialFailureThreshold: 1,
      );
      await router.initializeRoom('CR-101', 'localNode1');

      orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        localTimeProvider: () => 1700000000500,
        isHost: false,
        telemetryInterval: const Duration(milliseconds: 50),
      );

      mockRepo.emitOnSaveImmediate = false;
      orchestrator.startSynchronization();

      expect(router.currentState, equals(TransportState.webRtc));

      // Force WebRTC adapter broadcast to fail, triggering waterfall failover to fallbackRelay
      mockWebRtc.broadcastShouldThrow = true;

      // Inbound payload to be emitted by the fallback adapter when broadcast is retried on it
      final remoteProfile = initialProfile.copyWith(
        name: 'Curse of the Frost - Reconciled In Fallback',
      );
      final remoteDto = CampaignProfileDto.fromDomain(remoteProfile);
      final inboundJson = jsonEncode({
        'type': 'room_sync_full',
        'payload': remoteDto.toMap(),
        'timestamp': 1700000005000,
      });

      // When fallback adapter receives the retry broadcastPayload, emit an inbound packet in the same tick
      mockFallback.onBroadcast = (payload) {
        mockFallback.emitIncoming(inboundJson);
      };

      // Trigger a local profile update that broadcasts
      final localProfileUpdate = initialProfile.copyWith(
        name: 'Curse of the Frost - Local Outbound',
      );

      // Await local profile broadcast handling - must complete cleanly without deadlocking on _syncMutex
      await orchestrator.handleLocalProfileChange(localProfileUpdate).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException(
          'Deadlock detected during broadcast failover with concurrent inbound payload',
        ),
      );

      // Drain event queue so microtask-dispatched incoming payload is processed
      await pumpEventQueue();

      // Assert router transitioned to fallbackRelay
      expect(router.currentState, equals(TransportState.fallbackRelay));

      // Assert fallback adapter received the broadcasted outbound payload
      expect(mockFallback.broadcastedPayloads, isNotEmpty);

      // Assert inbound payload from fallback was reconciled into the repository
      expect(
        mockRepo.savedImmediateProfiles.any(
          (p) => p.name == 'Curse of the Frost - Reconciled In Fallback',
        ),
        isTrue,
      );

      // Assert mutex was fully released
      expect(orchestrator.isProcessingNetworkPayload, isFalse);
    });

    test('Default telemetryInterval is 2 seconds', () {
      final defaultOrchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
      );

      expect(defaultOrchestrator.telemetryInterval, equals(const Duration(seconds: 2)));
    });

    test('Causality Tracking & Offline Edits: valid offline edits older than 30s reconnect and reconcile cleanly while duplicate/stale sequence packets are dropped', () async {
      orchestrator.startSynchronization();
      const localTime = 1700000000500;

      // 1. Process initial inbound profile at t = localTime - 500ms (1700000000000) with origin sequence 1
      final profile1 = initialProfile.copyWith(name: 'Authoritative Title at 1700000000000');
      final inbound1 = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote-1',
        'origin_seq': 1,
        'payload': CampaignProfileDto.fromDomain(profile1).toMap(),
        'timestamp': 1700000000000,
      });
      await orchestrator.handleIncomingPayload(inbound1);

      expect(mockRepo.savedImmediateProfiles.length, equals(1));
      expect(mockRepo.savedImmediateProfiles.last.name, equals('Authoritative Title at 1700000000000'));
      expect(orchestrator.lastProfileSyncTimestamp, equals(1700000000000));
      expect(orchestrator.processedPayloadHashes.length, equals(1));

      // 2. Attempt to apply exact duplicate payload (same SHA-256)
      await orchestrator.handleIncomingPayload(inbound1);

      // Dropped as duplicate by LRU cache; repo count remains 1
      expect(mockRepo.savedImmediateProfiles.length, equals(1));
      expect(orchestrator.processedPayloadHashes.length, equals(1));

      // 3. Valid offline edits made >30s ago (localTime - 35000ms = 1699965000500) reconnecting with sequence 2
      // Must NOT be silently dropped by arbitrary 30s window; must reconcile cleanly via causality tracking
      final offlineProfile = initialProfile.copyWith(
        name: 'Reconnecting Offline Edits',
        partyCharacterIds: ['char-offline-reconnect'],
      );
      final inboundOffline = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote-1',
        'origin_seq': 2,
        'payload': CampaignProfileDto.fromDomain(offlineProfile).toMap(),
        'timestamp': localTime - 35000,
      });
      await orchestrator.handleIncomingPayload(inboundOffline);

      // Successfully processed and reconciled without silent drop
      expect(mockRepo.savedImmediateProfiles.length, equals(2));
      expect(mockRepo.savedImmediateProfiles.last.partyCharacterIds, contains('char-offline-reconnect'));
      expect(orchestrator.processedPayloadHashes.length, equals(2));

      // 4. Out-of-order sequence packet from partitioned node (origin_seq: 1 arriving after seq 2)
      // Must NOT be dropped by strict scalar checks; CRDT state merges deterministically
      final outOfOrderProfile = initialProfile.copyWith(
        name: 'Out-of-Order Partition Packet',
        pinnedRuleIds: {'underwater_combat'},
      );
      final inboundOutOfOrder = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote-1',
        'origin_seq': 1,
        'payload': CampaignProfileDto.fromDomain(outOfOrderProfile).toMap(),
        'timestamp': localTime - 30000,
      });
      await orchestrator.handleIncomingPayload(inboundOutOfOrder);

      // Successfully processed and CRDT merged instead of dropped; repo count becomes 3
      expect(mockRepo.savedImmediateProfiles.length, equals(3));
      expect(mockRepo.savedImmediateProfiles.last.pinnedRuleIds, contains('underwater_combat'));

      // 5. Strictly newer packet at sequence 3
      final newerProfile = initialProfile.copyWith(name: 'Newer Packet at 1700000002500');
      final inboundNewer = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote-1',
        'origin_seq': 3,
        'payload': CampaignProfileDto.fromDomain(newerProfile).toMap(),
        'timestamp': localTime + 2000,
      });
      await orchestrator.handleIncomingPayload(inboundNewer);

      expect(mockRepo.savedImmediateProfiles.length, equals(4));
      expect(mockRepo.savedImmediateProfiles.last.name, equals('Newer Packet at 1700000002500'));
      expect(orchestrator.lastProfileSyncTimestamp, equals(localTime + 2000));
    });

    test('LRU Cache Eviction: caps at 500 entries and evicts least recently used', () async {
      orchestrator.startSynchronization();
      const localTime = 1700000000500;

      // Inject 501 unique payloads within sliding lookback window
      for (int i = 0; i < 501; i++) {
        final profile = initialProfile.copyWith(name: 'Bulk Item $i');
        final payload = jsonEncode({
          'type': 'room_sync_full',
          'payload': CampaignProfileDto.fromDomain(profile).toMap(),
          'timestamp': localTime - 1000,
          'nonce': i,
        });
        await orchestrator.handleIncomingPayload(payload);
      }

      // Max cache size is bounded at 500 entries
      expect(orchestrator.processedPayloadHashes.length, equals(500));
    });

    test('Buffered Milestone Pruning Horizon: subtracts 2x heartbeat TTL from authoritative timestamp', () async {
      final now = clockSyncService.currentNetworkTimeMs;
      final hostOrchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: mockRepo,
        reconciliationService: reconciliationService,
        clockSyncService: clockSyncService,
        localTimeProvider: () => now,
        isHost: true,
        hostNodeId: 'dm-host-1',
        heartbeatTtl: const Duration(seconds: 10), // lookback = 20,000 ms
      );

      // 2 * 10s TTL = 20,000 ms lookback window:
      // veryOldTs: 50,000ms in the past (older than lookback window) -> pruned
      // recentTombstoneWithinLookback: 5,000ms in the past (within lookback window) -> PRESERVED
      final veryOldTs = HybridLogicalClock(physicalTime: now - 50000, logicalCounter: 0, nodeId: 'dm-host-1');
      final recentTombstoneWithinLookback = HybridLogicalClock(physicalTime: now - 5000, logicalCounter: 0, nodeId: 'dm-host-1');

      var setWithTombstones = CrdtOrSet<String>(
        tombstones: {
          'rule-ancient': veryOldTs,
          'rule-recent-disconnect': recentTombstoneWithinLookback,
        },
      );
      hostOrchestrator.trackedRulesSet = setWithTombstones;

      await hostOrchestrator.executeHostMilestoneFlush();

      // Ancient tombstone older than lookback horizon is pruned
      expect(hostOrchestrator.trackedRulesSet.tombstones.containsKey('rule-ancient'), isFalse);
      // Recent tombstone within the 2x TTL window is PRESERVED for transient reconnects
      expect(hostOrchestrator.trackedRulesSet.tombstones.containsKey('rule-recent-disconnect'), isTrue);
    });

    test('Concurrent Conflict Resolution: concurrent edits to notes and purse merge without wholesale overwrite', () async {
      final baseProfile = CampaignProfile.defaultProfile(id: 'camp_conflict');
      // Local has updated notes
      final localProfile = baseProfile.copyWith(notesMarkdown: 'Local draft notes by DM');
      mockRepo.activeProfile = localProfile;

      final now = DateTime.now().millisecondsSinceEpoch;
      // Remote payload has updated party purse
      final remoteProfile = baseProfile.copyWith(
        partyPurse: const PartyPurse(gp: 750, pp: 5),
        notesMarkdown: '', // Remote did not edit notes (blank)
      );

      final inboundConflict = jsonEncode({
        'type': 'room_sync_full',
        'payload': CampaignProfileDto.fromDomain(remoteProfile).toMap(),
        'timestamp': now + 500,
      });

      await orchestrator.handleIncomingPayload(inboundConflict);

      expect(mockRepo.savedImmediateProfiles.isNotEmpty, isTrue);
      final merged = mockRepo.savedImmediateProfiles.last;
      // Notes preserved from local rather than wiped out
      expect(merged.notesMarkdown, equals('Local draft notes by DM'));
      // Purse updated from remote
      expect(merged.partyPurse.gp, equals(750));
      expect(merged.partyPurse.pp, equals(5));
    });

    test('Causality Tracking: drops self-broadcast packets matching origin_node_id', () async {
      final initialCount = mockRepo.savedImmediateProfiles.length;
      final selfEchoPayload = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': orchestrator.hostNodeId,
        'payload': CampaignProfileDto.fromDomain(initialProfile).toMap(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await orchestrator.handleIncomingPayload(selfEchoPayload);

      // Dropped at ingress; repo was not invoked
      expect(mockRepo.savedImmediateProfiles.length, equals(initialCount));
    });

    test('LRU Poisoning Prevention: Unknown or malformed payloads are discarded without polluting LRU cache', () async {
      final initialHashes = orchestrator.processedPayloadHashes.length;

      // Malformed JSON
      await orchestrator.handleIncomingPayload('{not_valid_json');
      expect(orchestrator.processedPayloadHashes.length, equals(initialHashes));

      // Unknown message type
      final unknownTypePayload = jsonEncode({
        'type': 'unsupported_message_type_xyz',
        'origin_node_id': 'rogue-node',
        'payload': {'foo': 'bar'},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await orchestrator.handleIncomingPayload(unknownTypePayload);
      expect(orchestrator.processedPayloadHashes.length, equals(initialHashes));
    });
  });
}
