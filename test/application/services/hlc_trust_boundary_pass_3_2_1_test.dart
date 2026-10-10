import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/aggregate_hlc_extractor.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

class _FakeCharRepo implements ICharacterRepository<Character> {
  @override
  Future<List<Character>> loadCharacters() async => [];
  @override
  Future<void> saveCharacter(Character c) async => [c];
  @override
  Future<void> saveCharacters(List<Character> c) async {}
  @override
  Future<void> saveRoster(List<Character> r) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
  @override
  Future<Character?> getCharacter(String id) async => null;
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async => [];
  @override
  Future<String?> loadActiveCharacterId() async => null;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<Character> reparseCharacter(Character c) async => c;
  @override
  Future<List<Character>> reparseAllCharacters() async => [];
}

class _MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Map<String, int> peerLastSeen = {};

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    await _incoming.close();
  }

  void dispose() {
    _incoming.close();
  }
}

class _MockNetworkTimePort implements INetworkTimePort {
  final int networkTimeMs;
  _MockNetworkTimePort({required this.networkTimeMs});
  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int basePhysicalMs = 1700000000000;
  final localNode = ReplicaId('node_local');
  final remoteNode = ReplicaId('node_remote');
  final rogueNode = ReplicaId('node_rogue');

  setUpAll(() {
    IRoomSyncPayloadPort.defaultProvider = () => const RoomSyncPayloadMapper();
  });

  setUp(() async {
    sl.reset();
    sl.registerSingleton<ReplicaId>(localNode);
    await AppDatabaseService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    sl.reset();
  });

  group('Pass 3.2.1: HLC Trust Boundary & Atomic Aggregate Observation', () {
    test(
        'Section O & P: Inbound notes HLC drift validation and clock isolation',
        () async {
      int simulatedNow = basePhysicalMs;
      final clock = StatefulHlcClock(
        replicaId: localNode,
        maxFutureDrift: const Duration(minutes: 1),
        timeProvider: () => simulatedNow,
      );

      final baselineHlc = clock.nextTimestamp();
      expect(baselineHlc.physicalTime, equals(basePhysicalMs));

      final initialProfile = CampaignProfile(
        id: 'camp-1',
        name: 'Trust Boundary Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        nodeId: localNode.value,
        roomState: RoomNodeState(
          roomId: 'room-1',
          roomCode: 'CR-101',
          title: 'Camp Staging',
        ),
        notesRegister: CrdtLwwRegister(
          value: 'Original pristine notes',
          timestamp: baselineHlc,
        ),
      );

      final repo = LocalCampaignRepository(
        replicaId: localNode,
        characterRepo: _FakeCharRepo(),
        clock: clock,
      );
      addTearDown(repo.dispose);
      await repo.saveProfileImmediate(initialProfile);
      await repo.setActiveProfileId(initialProfile.id);

      final mockTransport = _MockTransportPort();
      addTearDown(mockTransport.dispose);

      final clockSync = ClockSyncService(
        networkTimePort: _MockNetworkTimePort(networkTimeMs: simulatedNow),
        localTimeProvider: () => simulatedNow,
      );

      final recon = RoomStateReconciliationService(
        networkTimeProvider: () => simulatedNow,
      );

      final orchestrator = RoomSyncOrchestrator(
        replicaId: localNode,
        transportPort: mockTransport,
        campaignRepo: repo,
        reconciliationService: recon,
        clockSyncService: clockSync,
        clock: clock,
        localTimeProvider: () => simulatedNow,
      );
      addTearDown(orchestrator.dispose);

      // --- SECTION O: Notes far-future rejection (+10 years) ---
      final tenYearsFarFutureMs = simulatedNow + (10 * 365 * 24 * 3600 * 1000);
      final maliciousHlc = HybridLogicalClock(
        physicalTime: tenYearsFarFutureMs,
        logicalCounter: 0,
        nodeId: rogueNode.value,
      );

      final rogueProfile = initialProfile.copyWith(
        notesRegister: CrdtLwwRegister(
          value: 'Malicious future poisoned notes',
          timestamp: maliciousHlc,
        ),
      );

      final roguePayload = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': rogueNode.value,
        'origin_seq': 1,
        'timestamp': simulatedNow,
        'payload': CampaignProfileDto.fromDomain(rogueProfile).toMap(),
      });

      final deadLetters = <SyncErrorEvent>[];
      final deadLetterSub = orchestrator.deadLetterStream.listen(deadLetters.add);
      addTearDown(deadLetterSub.cancel);

      // Ingest malicious payload
      await orchestrator.handleIncomingPayload(roguePayload);

      // Verify rejection: local notes unchanged, clock unchanged, dead-letter emitted
      expect(deadLetters.length, equals(1));
      expect(deadLetters.first.error, isA<HlcFutureDriftException>());

      final profileAfterRogue = repo.activeProfile!;
      expect(profileAfterRogue.notesRegister.value,
          equals('Original pristine notes'));
      expect(profileAfterRogue.notesRegister.timestamp, equals(baselineHlc));
      expect(clock.latest, equals(baselineHlc));

      // Subsequent local note edit succeeds with local ReplicaId and normal timestamp
      final localEditHlc = clock.nextTimestamp();
      expect(localEditHlc.physicalTime, equals(simulatedNow));
      expect(localEditHlc.logicalCounter,
          equals(baselineHlc.logicalCounter + 1));
      expect(localEditHlc.nodeId, equals(localNode.value));

      final updatedLocalProfile = profileAfterRogue.copyWith(
        notesRegister: CrdtLwwRegister(
          value: 'Legitimate local note edit',
          timestamp: localEditHlc,
        ),
      );
      await repo.saveProfileImmediate(updatedLocalProfile);
      expect(repo.activeProfile!.notesRegister.value,
          equals('Legitimate local note edit'));

      // --- SECTION P: Within-bound skew acceptance (+30s with 60s maxDrift) ---
      final validSkewMs = simulatedNow + 30000;
      final validRemoteHlc = HybridLogicalClock(
        physicalTime: validSkewMs,
        logicalCounter: 0,
        nodeId: remoteNode.value,
      );

      final remoteProfile = updatedLocalProfile.copyWith(
        notesRegister: CrdtLwwRegister(
          value: 'Valid remote collaborator notes',
          timestamp: validRemoteHlc,
        ),
      );

      final remotePayload = jsonEncode({
        'type': 'room_sync_full',
        'origin_node_id': remoteNode.value,
        'origin_seq': 2,
        'timestamp': simulatedNow,
        'payload': CampaignProfileDto.fromDomain(remoteProfile).toMap(),
      });

      await orchestrator.handleIncomingPayload(remotePayload);

      // Verify acceptance: remote notes applied, clock observed the remote HLC
      expect(repo.activeProfile!.notesRegister.value,
          equals('Valid remote collaborator notes'));
      expect(clock.latest.physicalTime, equals(validSkewMs));

      // Next local tick must be strictly after the remote HLC with local ReplicaId
      final nextLocalTick = clock.nextTimestamp();
      expect(nextLocalTick.physicalTime, equals(validSkewMs));
      expect(nextLocalTick.isAfter(validRemoteHlc), isTrue);
      expect(nextLocalTick.nodeId, equals(localNode.value));
    });

    test(
        'Section Q: Loaded profile active encounter items and tombstones observation and quarantine',
        () async {
      int simulatedNow = basePhysicalMs;
      final clock = StatefulHlcClock(
        replicaId: localNode,
        maxFutureDrift: const Duration(minutes: 1),
        timeProvider: () => simulatedNow,
      );

      final validEncounterHlc = HybridLogicalClock(
        physicalTime: simulatedNow + 10000,
        logicalCounter: 0,
        nodeId: remoteNode.value,
      );
      final validTombstoneHlc = HybridLogicalClock(
        physicalTime: simulatedNow + 12000,
        logicalCounter: 1,
        nodeId: remoteNode.value,
      );

      final p1 = EncounterParticipant(
        participantId: 'p-goblin',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin-1',
          displayName: 'Goblin Scout',
        ),
        currentHp: 10,
        maxHp: 10,
        defense: 12,
        initiativeScore: 14,
      );
      final p2 = EncounterParticipant(
        participantId: 'p-hobgoblin',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'hobgoblin-1',
          displayName: 'Hobgoblin Leader',
        ),
        currentHp: 20,
        maxHp: 20,
        defense: 16,
        initiativeScore: 12,
      );

      // Build CrdtOrSet with both active item and tombstone
      var encounterSet = const CrdtOrSet<EncounterParticipant>.empty();
      encounterSet = encounterSet.add(p1.participantId, p1, validEncounterHlc);
      encounterSet =
          encounterSet.add(p2.participantId, p2, validEncounterHlc);
      encounterSet =
          encounterSet.remove(p2.participantId, validTombstoneHlc);

      expect(encounterSet.activeValues.map((p) => p.participantId),
          contains('p-goblin'));
      expect(encounterSet.tombstones.keys, contains('p-hobgoblin'));

      final healthyProfile = CampaignProfile(
        id: 'camp-healthy-enc',
        name: 'Healthy Encounter Profile',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        nodeId: localNode.value,
        roomState: RoomNodeState(
          roomId: 'room-1',
          roomCode: 'CR-101',
          title: 'Battle Room',
          activeEncounter: encounterSet,
        ),
      );

      // Persist directly to DB
      final healthyDto = CampaignProfileDto.fromDomain(healthyProfile);
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp-healthy-enc'],
      );
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp-healthy-enc',
        healthyDto.toJson(),
      );

      final repo = LocalCampaignRepository(
        replicaId: localNode,
        characterRepo: _FakeCharRepo(),
        clock: clock,
      );
      addTearDown(repo.dispose);

      final loadedProfiles = await repo.loadAllProfiles();
      expect(loadedProfiles.length, equals(1));
      expect(loadedProfiles.first.id, equals('camp-healthy-enc'));

      // Both item and tombstone timestamps were observed into the clock
      expect(clock.latest.physicalTime, equals(validTombstoneHlc.physicalTime));

      // Now create a corrupted profile with far-future tombstone (+10 years)
      final farFutureTombstoneHlc = HybridLogicalClock(
        physicalTime: simulatedNow + (10 * 365 * 24 * 3600 * 1000),
        logicalCounter: 0,
        nodeId: rogueNode.value,
      );

      var poisonedEncounterSet = const CrdtOrSet<EncounterParticipant>.empty();
      poisonedEncounterSet =
          poisonedEncounterSet.add(p1.participantId, p1, validEncounterHlc);
      poisonedEncounterSet =
          poisonedEncounterSet.remove(p1.participantId, farFutureTombstoneHlc);

      final poisonedProfile = CampaignProfile(
        id: 'camp-poisoned-tombstone',
        name: 'Poisoned Encounter Profile',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        nodeId: localNode.value,
        roomState: RoomNodeState(
          roomId: 'room-2',
          roomCode: 'CR-102',
          title: 'Lich Lair',
          activeEncounter: poisonedEncounterSet,
        ),
      );

      final poisonedDto = CampaignProfileDto.fromDomain(poisonedProfile);
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp-healthy-enc', 'camp-poisoned-tombstone'],
      );
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp-poisoned-tombstone',
        poisonedDto.toJson(),
      );

      final poisonedClock = StatefulHlcClock(
        replicaId: localNode,
        maxFutureDrift: const Duration(minutes: 1),
        timeProvider: () => simulatedNow,
      );

      final poisonedRepo = LocalCampaignRepository(
        replicaId: localNode,
        characterRepo: _FakeCharRepo(),
        clock: poisonedClock,
      );
      addTearDown(poisonedRepo.dispose);
      final reloadedProfiles = await poisonedRepo.loadAllProfiles();

      // Persisted future history is accepted and causally observed under Pass 3.3
      expect(reloadedProfiles.length, equals(2));
      expect(reloadedProfiles.map((p) => p.id),
          containsAll(['camp-healthy-enc', 'camp-poisoned-tombstone']));

      // Clock causality was advanced to the maximum historical tombstone timestamp
      expect(poisonedClock.latest.physicalTime,
          equals(farFutureTombstoneHlc.physicalTime));

      // Next local tick must be strictly after the historical tombstone with runtime writer authority
      final nextTick = poisonedClock.nextTimestamp();
      expect(nextTick.isAfter(farFutureTombstoneHlc), isTrue);
      expect(nextTick.nodeId, equals(localNode.value));

      // Now verify that genuinely malformed serialized state is still quarantined and preserved
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        '${LocalCampaignRepository.profileKeyPrefix}camp-malformed-json',
        '{"id": "camp-malformed-json", "corrupt_syntax": ',
      );
      AppDatabaseService.instance.put(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
        ['camp-healthy-enc', 'camp-poisoned-tombstone', 'camp-malformed-json'],
      );

      final malformedRepo = LocalCampaignRepository(
        replicaId: localNode,
        characterRepo: _FakeCharRepo(),
        clock: StatefulHlcClock(
          replicaId: localNode,
          maxFutureDrift: const Duration(minutes: 1),
          timeProvider: () => simulatedNow,
        ),
      );
      addTearDown(malformedRepo.dispose);

      final withMalformedProfiles = await malformedRepo.loadAllProfiles();
      expect(withMalformedProfiles.length, equals(2));
      expect(withMalformedProfiles.any((p) => p.id == 'camp-malformed-json'),
          isFalse);
    });

    test(
        'Section R: Atomic Aggregate Validation rejects whole profile when one field drifts',
        () async {
      int simulatedNow = basePhysicalMs;
      final clock = StatefulHlcClock(
        replicaId: localNode,
        maxFutureDrift: const Duration(minutes: 1),
        timeProvider: () => simulatedNow,
      );

      final baselineHlc = clock.nextTimestamp();
      expect(baselineHlc.physicalTime, equals(basePhysicalMs));

      final validNotesHlc = HybridLogicalClock(
        physicalTime: simulatedNow + 20000,
        logicalCounter: 0,
        nodeId: remoteNode.value,
      );
      final validEncounterHlc = HybridLogicalClock(
        physicalTime: simulatedNow + 25000,
        logicalCounter: 0,
        nodeId: remoteNode.value,
      );
      final farFutureEncounterHlc = HybridLogicalClock(
        physicalTime: simulatedNow + (10 * 365 * 24 * 3600 * 1000),
        logicalCounter: 0,
        nodeId: rogueNode.value,
      );

      final p1 = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'e1',
          displayName: 'D1',
        ),
        currentHp: 10,
        maxHp: 10,
        defense: 10,
        initiativeScore: 10,
      );

      var testEncounter = const CrdtOrSet<EncounterParticipant>.empty();
      testEncounter = testEncounter.add(p1.participantId, p1, validEncounterHlc);
      // Remove with far-future tombstone
      testEncounter =
          testEncounter.remove(p1.participantId, farFutureEncounterHlc);

      // Profile has valid notes, but invalid encounter tombstone
      final atomicProfile = CampaignProfile(
        id: 'camp-atomic-test',
        name: 'Atomic Aggregate Test',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        nodeId: localNode.value,
        notesRegister: CrdtLwwRegister(
          value: 'Validly timestamped notes',
          timestamp: validNotesHlc,
        ),
        roomState: RoomNodeState(
          roomId: 'room-atomic',
          roomCode: 'CR-103',
          title: 'Arena',
          activeEncounter: testEncounter,
        ),
      );

      // Verify that timestamps are extracted properly
      final extracted = extractCampaignProfileTimestamps(atomicProfile);
      expect(extracted, contains(validNotesHlc));
      expect(extracted, contains(farFutureEncounterHlc));

      // Attempt validateAllRemote directly
      expect(
        () => clock.validateAllRemote(extracted),
        throwsA(isA<HlcFutureDriftException>()),
      );

      // CRITICAL INVARIANT: clock.latest MUST remain exactly unchanged!
      expect(clock.latest, equals(baselineHlc));
      expect(clock.latest.physicalTime, equals(basePhysicalMs));
    });

    test(
        'Section E & F: FullProfileSyncMessage rejects purse and profile atomically, OrSetDeltaSyncMessage rejects delta on drift',
        () async {
      int simulatedNow = basePhysicalMs;
      final clock = StatefulHlcClock(
        replicaId: localNode,
        maxFutureDrift: const Duration(minutes: 1),
        timeProvider: () => simulatedNow,
      );

      final baselineHlc = clock.nextTimestamp();

      final initialProfile = CampaignProfile(
        id: 'camp-full-sync',
        name: 'Full Sync Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 1, 1),
        nodeId: localNode.value,
        partyPurse: PartyPurse(
          gp: 100,
          sp: 10,
          cp: 10,
        ),
        pinnedRuleIds: const {'cover'},
        roomState: RoomNodeState(
          roomId: 'room-init',
          roomCode: 'CR-100',
          title: 'Base Room',
        ),
      );

      final repo = LocalCampaignRepository(
        replicaId: localNode,
        characterRepo: _FakeCharRepo(),
        clock: clock,
      );
      addTearDown(repo.dispose);
      await repo.saveProfileImmediate(initialProfile);
      await repo.setActiveProfileId(initialProfile.id);

      final mockTransport = _MockTransportPort();
      addTearDown(mockTransport.dispose);

      final clockSync = ClockSyncService(
        networkTimePort: _MockNetworkTimePort(networkTimeMs: simulatedNow),
        localTimeProvider: () => simulatedNow,
      );

      final recon = RoomStateReconciliationService(
        networkTimeProvider: () => simulatedNow,
      );

      final orchestrator = RoomSyncOrchestrator(
        replicaId: localNode,
        transportPort: mockTransport,
        campaignRepo: repo,
        reconciliationService: recon,
        clockSyncService: clockSync,
        clock: clock,
        localTimeProvider: () => simulatedNow,
      );
      addTearDown(orchestrator.dispose);

      final deadLetters = <SyncErrorEvent>[];
      final deadLetterSub = orchestrator.deadLetterStream.listen(deadLetters.add);
      addTearDown(deadLetterSub.cancel);

      // --- SECTION E: FullProfileSyncMessage with far-future encounter ---
      final farFutureEncounterHlc = HybridLogicalClock(
        physicalTime: simulatedNow + (10 * 365 * 24 * 3600 * 1000),
        logicalCounter: 0,
        nodeId: rogueNode.value,
      );

      final pBomb = EncounterParticipant(
        participantId: 'drift-bomb',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'bomb-1',
          displayName: 'Drift Bomb',
        ),
        currentHp: 1,
        maxHp: 1,
        defense: 10,
        initiativeScore: 0,
      );

      final rogueProfile = initialProfile.copyWith(
        roomState: RoomNodeState(
          roomId: 'room-rogue',
          roomCode: 'CR-999',
          title: 'Rogue Chamber',
          activeEncounter: const CrdtOrSet<EncounterParticipant>.empty().add(
            pBomb.participantId,
            pBomb,
            farFutureEncounterHlc,
          ),
        ),
      );

      // Inbound full profile envelope also carries a purse delta of 500 gold
      final purseDelta = PartyPurse(
        gp: 500,
      );

      final envelope = {
        'type': 'room_sync_full',
        'origin_node_id': rogueNode.value,
        'origin_seq': 1,
        'timestamp': simulatedNow,
        'purse_delta': purseDelta.toMap(),
        'payload': CampaignProfileDto.fromDomain(rogueProfile).toMap(),
      };

      await orchestrator.handleIncomingPayload(jsonEncode(envelope));

      // Verify entire aggregate rejection:
      // 1. Clock is unchanged
      expect(clock.latest, equals(baselineHlc));
      // 2. Profile in repo is unchanged
      final currentProfile = repo.activeProfile!;
      expect(currentProfile.partyPurse.gp, equals(100)); // Purse NOT updated
      expect(currentProfile.roomState.activeEncounter.activeValues, isEmpty);
      // 3. Dead letter contains HlcFutureDriftException
      expect(deadLetters.length, equals(1));
      expect(deadLetters[0].error, isA<HlcFutureDriftException>());

      // --- SECTION F.1: OrSetDeltaSyncMessage with far-future item ---
      final farFutureRuleHlc = HybridLogicalClock(
        physicalTime: simulatedNow + (10 * 365 * 24 * 3600 * 1000),
        logicalCounter: 0,
        nodeId: rogueNode.value,
      );

      var rogueRulesDelta = const CrdtOrSet<String>.empty();
      rogueRulesDelta = rogueRulesDelta.add('grapple', 'grapple', farFutureRuleHlc);

      final deltaEnvelope = {
        'type': 'crdt_or_set_delta',
        'origin_node_id': rogueNode.value,
        'origin_seq': 2,
        'timestamp': simulatedNow,
        'campaign_id': 'campaign_1',
        'payload': CrdtOrSetDto.toMap<String>(
          rogueRulesDelta,
          (item) => item,
        ),
      };

      await orchestrator.handleIncomingPayload(jsonEncode(deltaEnvelope));

      // Verify OrSet item delta rejection:
      // 1. Clock is unchanged
      expect(clock.latest, equals(baselineHlc));
      // 2. Tracked rules set unchanged
      expect(orchestrator.trackedRulesSet.activeValues, isEmpty);
      // 3. Pinned rules unchanged
      expect(repo.activeProfile!.pinnedRuleIds, equals({'cover'}));
      // 4. Dead letter contains HlcFutureDriftException
      expect(deadLetters.length, equals(2));
      expect(deadLetters[1].error, isA<HlcFutureDriftException>());

      // --- SECTION F.2: OrSetDeltaSyncMessage with genuine far-future tombstone ---
      final rogueTombstoneDelta = CrdtOrSet<String>(
        tombstones: {'shove': farFutureRuleHlc},
      );

      final tombstoneEnvelope = {
        'type': 'crdt_or_set_delta',
        'origin_node_id': rogueNode.value,
        'origin_seq': 3,
        'timestamp': simulatedNow,
        'campaign_id': 'campaign_1',
        'payload': CrdtOrSetDto.toMap<String>(
          rogueTombstoneDelta,
          (item) => item,
        ),
      };

      await orchestrator.handleIncomingPayload(jsonEncode(tombstoneEnvelope));

      // Verify OrSet tombstone delta rejection:
      // 1. Clock is unchanged
      expect(clock.latest, equals(baselineHlc));
      // 2. Tracked rules set tombstones unchanged
      expect(orchestrator.trackedRulesSet.tombstones, isEmpty);
      // 3. Pinned rules unchanged
      expect(repo.activeProfile!.pinnedRuleIds, equals({'cover'}));
      // 4. Dead letter contains HlcFutureDriftException
      expect(deadLetters.length, equals(3));
      expect(deadLetters[2].error, isA<HlcFutureDriftException>());
    });
  });
}
