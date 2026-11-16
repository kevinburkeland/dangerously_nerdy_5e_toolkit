import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math_random;
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';

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

  String? roomCode;

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      true;

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
  List<CampaignProfile> get allProfiles =>
      _activeProfile != null ? [_activeProfile!] : [];

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _profileController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      _allProfilesController.stream;

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
    savedProfiles.add(profile);
    _profileController.add(profile);
    _allProfilesController.add(allProfiles);
  }

  Future<void> saveProfile(CampaignProfile profile) async =>
      saveProfileImmediate(profile);

  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await putProfile(profile);
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
        replicaId: ReplicaId('node-orchestrator'),
        clock: StatefulHlcClock(replicaId: ReplicaId('node-orchestrator')),
        payloadMapper: const RoomSyncPayloadMapper(),
      );
    });

    test('PartyPurse PN-Counter CvRDT convergence across network partitions',
        () {
      // Both nodes start with an initial shared purse of 100 GP
      final initialPurse = const PartyPurse.empty()
          .setCoins(gp: 100, replicaId: ReplicaId('node_init'));

      // Node A deposits 50 GP and withdraws 10 GP during partition
      var purseA = initialPurse
          .modifyCoin('gp', 50, replicaId: ReplicaId('node_a'))
          .modifyCoin('gp', -10, replicaId: ReplicaId('node_a'));

      // Node B concurrently deposits 30 GP and withdraws 5 GP during partition
      var purseB = initialPurse
          .modifyCoin('gp', 30, replicaId: ReplicaId('node_b'))
          .modifyCoin('gp', -5, replicaId: ReplicaId('node_b'));

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

    test(
        'Granular CRDT Delta: mutating partyPurse emits crdt_purse_delta rather than full profile',
        () async {
      final baseProfile =
          CampaignProfile.defaultProfile(id: 'camp_delta', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'));
      mockRepo.activeProfile = baseProfile;

      // Seed orchestrator baseline
      await orchestrator.handleLocalProfileChange(baseProfile);
      mockTransport.broadcastedPayloads.clear();

      // Mutate only partyPurse
      final updatedPurse = baseProfile.partyPurse
          .modifyCoin('gp', 250, replicaId: ReplicaId('node-orchestrator'));
      final updatedProfile = baseProfile.copyWith(partyPurse: updatedPurse);

      await orchestrator.handleLocalProfileChange(updatedProfile);

      expect(mockTransport.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockTransport.broadcastedPayloads.first)
          as Map<String, dynamic>;

      expect(decoded['type'], equals('crdt_purse_delta'));
      expect(decoded['origin_node_id'], equals('node-orchestrator'));
      expect(decoded['campaign_id'], equals('camp_delta'));
      expect(decoded['payload']['gp'], equals(250));
      expect(decoded['payload'].containsKey('gpCounter'), isTrue);
    });

    test(
        'Mutating purse and minionOwners together triggers full sync instead of purse delta',
        () async {
      final baseProfile = CampaignProfile.defaultProfile(
        id: 'camp_delta',
        nodeId: 'test_node',
        timestamp: const HybridLogicalClock(
          physicalTime: 1000,
          logicalCounter: 0,
          nodeId: 'test_node',
        ),
      );
      mockRepo.activeProfile = baseProfile;

      // Seed orchestrator baseline
      await orchestrator.handleLocalProfileChange(baseProfile);
      mockTransport.broadcastedPayloads.clear();

      // Mutate partyPurse AND minionOwners together
      final updatedPurse = baseProfile.partyPurse
          .modifyCoin('gp', 250, replicaId: ReplicaId('node-orchestrator'));
      final updatedProfile = baseProfile
          .copyWith(partyPurse: updatedPurse)
          .withMinionOwner(
            'minion_1',
            'player_1',
            const HybridLogicalClock(
              physicalTime: 2000,
              logicalCounter: 0,
              nodeId: 'node-orchestrator',
            ),
          );

      await orchestrator.handleLocalProfileChange(updatedProfile);

      expect(mockTransport.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockTransport.broadcastedPayloads.first)
          as Map<String, dynamic>;

      expect(decoded['type'], equals('room_sync_full'));
    });

    test(
        'Granular CRDT Delta: mutating pinnedRules emits crdt_or_set_delta rather than full profile',
        () async {
      final baseProfile = CampaignProfile.defaultProfile(
        id: 'camp_rules',
        nodeId: 'test_node',
        timestamp: const HybridLogicalClock(
          physicalTime: 1000,
          logicalCounter: 0,
          nodeId: 'test_node',
        ),
      );
      mockRepo.activeProfile = baseProfile;

      // Seed orchestrator baseline
      await orchestrator.handleLocalProfileChange(baseProfile);
      mockTransport.broadcastedPayloads.clear();

      // Mutate only pinnedRules
      final updatedRules = baseProfile.pinnedRules.add(
        'rule-grapple',
        'Grappling',
        const HybridLogicalClock(
          physicalTime: 2000,
          logicalCounter: 0,
          nodeId: 'node-orchestrator',
        ),
      );
      final updatedProfile = baseProfile.copyWith(pinnedRules: updatedRules);

      await orchestrator.handleLocalProfileChange(updatedProfile);

      expect(mockTransport.broadcastedPayloads.length, equals(1));
      final decoded = jsonDecode(mockTransport.broadcastedPayloads.first)
          as Map<String, dynamic>;

      expect(decoded['type'], equals('crdt_or_set_delta'));
      expect(decoded['origin_node_id'], equals('node-orchestrator'));
      expect(decoded['campaign_id'], equals('camp_rules'));
      expect(decoded['payload'].containsKey('items'), isTrue);
    });

    test('Sync delta law: 300 seeded profile mutation pairs converge and emit exact delta or full sync', () async {
      final rand = math_random.Random(1337);
      final payloadCounts = <String, int>{};
      const totalSeeds = 300;

      for (int seed = 0; seed < totalSeeds; seed++) {
        final clockBaseTime = 1000000 + seed * 1000;
        final localClock = StatefulHlcClock(replicaId: ReplicaId('local-$seed'));
        final peerClock = StatefulHlcClock(replicaId: ReplicaId('peer-$seed'));
        final localTransport = MockTransportPort();
        final peerTransport = MockTransportPort();
        final localRepo = MockCampaignRepository();
        final peerRepo = MockCampaignRepository();
        final timePort = MockNetworkTimePort(networkTimeMs: clockBaseTime);
        final localClockSync = ClockSyncService(networkTimePort: timePort);
        final peerClockSync = ClockSyncService(networkTimePort: timePort);
        final recon = RoomStateReconciliationService(networkTimeProvider: () => clockBaseTime);

        final localOrch = RoomSyncOrchestrator(
          transportPort: localTransport,
          campaignRepo: localRepo,
          reconciliationService: recon,
          clockSyncService: localClockSync,
          replicaId: ReplicaId('local-$seed'),
          clock: localClock,
          payloadMapper: const RoomSyncPayloadMapper(),
        );

        final peerOrch = RoomSyncOrchestrator(
          transportPort: peerTransport,
          campaignRepo: peerRepo,
          reconciliationService: recon,
          clockSyncService: peerClockSync,
          replicaId: ReplicaId('peer-$seed'),
          clock: peerClock,
          payloadMapper: const RoomSyncPayloadMapper(),
        );

        final initHlc = HybridLogicalClock(physicalTime: clockBaseTime, logicalCounter: 0, nodeId: 'init');
        final baseProfile = CampaignProfile.defaultProfile(
          id: 'camp_$seed',
          nodeId: 'init',
          timestamp: initHlc,
        ).copyWith(
          name: 'Campaign $seed',
          nameTimestamp: initHlc,
          notesMarkdown: 'Notes $seed',
          notesTimestamp: initHlc,
        );

        localRepo.activeProfile = baseProfile;
        peerRepo.activeProfile = baseProfile;

        // Baseline both orchestrators
        await localOrch.handleLocalProfileChange(baseProfile);
        localTransport.broadcastedPayloads.clear();
        await peerOrch.handleLocalProfileChange(baseProfile);
        peerTransport.broadcastedPayloads.clear();

        // Determine mutation category for this seed
        // Guarantee coverage: purse alone, rules alone, purse+rules, and random combinations with other fields
        final mutatePurse = (seed % 3 == 0) || (seed < 50);
        final mutateRules = (seed % 3 == 1) || (seed >= 50 && seed < 100);
        final mutateMinions = (seed % 5 == 0) && (seed >= 100);
        final mutateName = (seed % 7 == 0) && (seed >= 100);
        final mutateNotes = (seed % 11 == 0) && (seed >= 100);

        // Ensure at least one field mutates
        final actualMutatePurse = mutatePurse || (!mutateRules && !mutateMinions && !mutateName && !mutateNotes);
        final actualMutateRules = mutateRules;
        final actualMutateMinions = mutateMinions;
        final actualMutateName = mutateName;
        final actualMutateNotes = mutateNotes;

        var mutated = baseProfile;
        final mutateTs = HybridLogicalClock(physicalTime: clockBaseTime + 10, logicalCounter: 1, nodeId: 'local-$seed');

        if (actualMutatePurse) {
          final delta = 10 + rand.nextInt(100);
          mutated = mutated.copyWith(
            partyPurse: mutated.partyPurse.modifyCoin('gp', delta, replicaId: ReplicaId('local-$seed')),
          );
        }
        if (actualMutateRules) {
          mutated = mutated.copyWith(
            pinnedRules: mutated.pinnedRules.add('rule-$seed', 'Rule $seed', mutateTs),
          );
        }
        if (actualMutateMinions) {
          mutated = mutated.withMinionOwner('minion-$seed', 'player-$seed', mutateTs);
        }
        if (actualMutateName) {
          mutated = mutated.copyWith(
            name: 'Updated Campaign $seed',
            nameTimestamp: mutateTs,
          );
        }
        if (actualMutateNotes) {
          mutated = mutated.copyWith(
            notesMarkdown: 'Updated Notes $seed',
            notesTimestamp: mutateTs,
          );
        }

        // Local orchestrator emits payload
        await localOrch.handleLocalProfileChange(mutated);
        expect(localTransport.broadcastedPayloads.length, equals(1));
        final payloadJson = localTransport.broadcastedPayloads.first;
        final payloadMap = jsonDecode(payloadJson) as Map<String, dynamic>;
        final type = payloadMap['type'] as String;

        payloadCounts[type] = (payloadCounts[type] ?? 0) + 1;

        final isPurseOnly = actualMutatePurse && !actualMutateRules && !actualMutateMinions && !actualMutateName && !actualMutateNotes;
        final isRulesOnly = !actualMutatePurse && actualMutateRules && !actualMutateMinions && !actualMutateName && !actualMutateNotes;

        if (isPurseOnly) {
          expect(type, equals('crdt_purse_delta'));
        } else if (isRulesOnly) {
          expect(type, equals('crdt_or_set_delta'));
        } else {
          expect(type, equals('room_sync_full'));
        }

        // Peer receives and applies payload
        await peerOrch.handleIncomingPayload(payloadJson);
        final peerProfile = peerRepo.savedProfiles.isNotEmpty
            ? peerRepo.savedProfiles.last
            : peerRepo.activeProfile;

        expect(peerProfile, equals(mutated),
            reason: 'Peer profile must equal mutated profile for seed $seed ($type)');
      }

      stdout.writeln('Sync law: checked $totalSeeds pairs. Payload counts: $payloadCounts');
      expect(payloadCounts.containsKey('crdt_purse_delta'), isTrue);
      expect(payloadCounts.containsKey('crdt_or_set_delta'), isTrue);
      expect(payloadCounts.containsKey('room_sync_full'), isTrue);
      expect(payloadCounts.values.reduce((a, b) => a + b), equals(totalSeeds));
    });

    test(
        'Ingress of crdt_purse_delta reconciles party purse via CvRDT lattice join',
        () async {
      final baseProfile =
          CampaignProfile.defaultProfile(id: 'camp_delta', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'))
              .copyWith(
        partyPurse: const PartyPurse.empty()
            .setCoins(gp: 100, replicaId: ReplicaId('node_init'))
            .modifyCoin('gp', 50, replicaId: ReplicaId('node-orchestrator')),
      );
      mockRepo.activeProfile = baseProfile;

      // Remote peer concurrently deposited 35 GP
      final remotePurse = const PartyPurse.empty()
          .setCoins(gp: 100, replicaId: ReplicaId('node_init'))
          .modifyCoin('gp', 35, replicaId: ReplicaId('node-remote'));

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

    test(
        'Full room_sync_full carries party_purse_crdt delta and converges without scalar LWW',
        () async {
      final baseProfile =
          CampaignProfile.defaultProfile(id: 'camp_full', nodeId: 'test_node', timestamp: const HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'test_node'))
              .copyWith(
        partyPurse: const PartyPurse.empty()
            .setCoins(gp: 50, replicaId: ReplicaId('node_init'))
            .modifyCoin('gp', 20, replicaId: ReplicaId('node-local')),
      );
      mockRepo.activeProfile = baseProfile;

      final remotePurse = const PartyPurse.empty()
          .setCoins(gp: 50, replicaId: ReplicaId('node_init'))
          .modifyCoin('gp', 80, replicaId: ReplicaId('node-remote'));
      final remoteProfile = baseProfile.copyWith(
        partyPurse: remotePurse,
      );

      final fullSyncPayload = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': 'node-remote',
        'origin_seq': 10,
        'payload': {
          'id': remoteProfile.id,
          'name': remoteProfile.name,
          'edition': remoteProfile.edition.rulesetId,
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

      expect(reconciled.name, equals(baseProfile.name));
      // 50 (init) + 20 (local) + 80 (remote) = 150 GP
      expect(reconciled.partyPurse.gp, equals(150));
    });
  });
}
