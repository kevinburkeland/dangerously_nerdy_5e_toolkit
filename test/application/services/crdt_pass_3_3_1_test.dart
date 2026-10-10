import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character;
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart'
    as app_party;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/homebrew_import_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_combat_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart'
    as svc_party;

class _FakeCharRepo implements ICharacterRepository<Character> {
  final Map<String, Character> storage = {};

  @override
  Future<List<Character>> loadCharacters() async => storage.values.toList();
  @override
  Future<void> saveCharacter(Character character) async =>
      storage[character.id.slug] = character;
  @override
  Future<void> deleteCharacter(String characterSlug) async =>
      storage.remove(characterSlug);
  @override
  Future<Character?> getCharacter(String id) async => storage[id];
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async =>
      ids.map((id) => storage[id]).whereType<Character>().toList();
  @override
  Future<void> saveCharacters(List<Character> characters) async {
    for (final c in characters) {
      storage[c.id.slug] = c;
    }
  }
  @override
  Future<void> saveRoster(List<Character> roster) async {
    storage.clear();
    for (final c in roster) {
      storage[c.id.slug] = c;
    }
  }
  @override
  Future<String?> loadActiveCharacterId() async => storage.keys.firstOrNull;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<Character> reparseCharacter(Character character) async => character;
  @override
  Future<List<Character>> reparseAllCharacters() async => storage.values.toList();
}

class _FakeCampaignRepo implements ICampaignRepository {
  CampaignProfile? currentProfile;

  @override
  String? get activeProfileId => currentProfile?.id;
  @override
  CampaignProfile? get activeProfile => currentProfile;
  @override
  List<CampaignProfile> get allProfiles =>
      currentProfile != null ? [currentProfile!] : [];
  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;
  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      currentProfile?.id == id ? currentProfile : null;
  @override
  Future<CampaignProfile?> getActiveProfile() async => currentProfile;
  @override
  Future<void> saveProfile(CampaignProfile profile) async {
    currentProfile = profile;
  }
  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    currentProfile = profile;
  }
  @override
  Future<void> deleteProfile(String id) async {
    if (currentProfile?.id == id) currentProfile = null;
  }
  @override
  Future<void> setActiveProfileId(String id) async {}
  @override
  Stream<CampaignProfile?> watchActiveProfile() => Stream.value(currentProfile);
  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => Stream.value(allProfiles);
}

class _FakeGithubIngestor implements IGithubIngestorPort {
  @override
  Future<List<String>> discoverJsonManifest(GithubRepoSource source) async => [];

  @override
  Stream<IngestionResult> ingestPayloadStream({
    required List<String> rawUrls,
    required RulesetVersion ruleset,
  }) async* {}
}

class _FakeTransportPort implements IP2pTransportPort {
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Map<String, int> peerLastSeen = {};

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  @override
  Future<void> prepareSession() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}
}

class _FakeNetworkTimePort implements INetworkTimePort {
  int time = 1000000;
  @override
  Future<int> getNetworkTimeMs() async => time;
}

void main() {
  group('Cold Iron Birdcage — Pass 3.3.1 Regressions & Identity Invariants', () {
    const wallClockT = 1000000;
    final replicaA = ReplicaId('node-A');
    final replicaB = ReplicaId('node-B');

    // =========================================================================
    // SECTION C: MINION FUTURE-HISTORY MUTATION REGRESSION
    // =========================================================================
    test('Section C: Minion future-history mutation succeeds without drift rejection', () async {
      final clockA = StatefulHlcClock(
        replicaId: replicaA,
        timeProvider: () => wallClockT,
      );
      final charRepo = _FakeCharRepo();
      final campaignRepo = _FakeCampaignRepo();
      final combatService = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        replicaId: replicaA,
        combatResolver: const Dnd5eCombatResolver(),
        clock: clockA,
        networkTimeProvider: () => wallClockT,
      );

      // Historical timestamp T + 6 hours
      final futurePhysical = wallClockT + const Duration(hours: 6).inMilliseconds;
      final historicalTs = HybridLogicalClock(
        physicalTime: futurePhysical,
        logicalCounter: 0,
        nodeId: 'node-historical',
      );

      final initialMinion = MinionInstance(
        id: 'minion_1',
        name: 'Animated Armor',
        size: EntitySize.medium,
        currentHp: 20,
        maxHp: 20,
      );

      final initialMinions = const CrdtOrSet<MinionInstance>.empty()
          .add('minion_1', initialMinion, historicalTs);

      final profile = CampaignProfile.defaultProfile(nodeId: replicaA.value).copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'R1',
          title: 'Future Dungeon',
        ).copyWith(activeMinions: initialMinions),
      );
      campaignRepo.currentProfile = profile;

      // Mutate minion HP through production CombatEncounterService
      final updatedProfile = await combatService.modifyMinionHp(
        profile: profile,
        minionId: 'minion_1',
        delta: -5,
      );

      final updatedMinionItem = updatedProfile.roomState.activeMinions.items['minion_1'];
      expect(updatedMinionItem, isNotNull);
      expect(updatedMinionItem!.value.currentHp, equals(15));

      // Assertions per Section C:
      // 1. Mutation succeeds without HlcFutureDriftException
      // 2. New minion register timestamp > historical timestamp
      expect(updatedMinionItem.timestamp.isAfter(historicalTs), isTrue);
      // 3. New timestamp nodeId == A
      expect(updatedMinionItem.timestamp.nodeId, equals(replicaA.value));
      // 4. Historical timestamp remains unchanged
      expect(historicalTs.nodeId, equals('node-historical'));
      expect(historicalTs.physicalTime, equals(futurePhysical));
      // 5. Resulting CRDT item authored by runtime A
      expect(updatedProfile.roomState.activeMinions.items['minion_1']!.timestamp.nodeId,
          equals(replicaA.value));
    });

    // =========================================================================
    // SECTION D: MINION TOMBSTONE RE-ADD REGRESSION
    // =========================================================================
    test('Section D: Minion tombstone re-add succeeds and wins under OR-set semantics', () async {
      final clockA = StatefulHlcClock(
        replicaId: replicaA,
        timeProvider: () => wallClockT,
      );
      final charRepo = _FakeCharRepo();
      final campaignRepo = _FakeCampaignRepo();
      final combatService = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        replicaId: replicaA,
        combatResolver: const Dnd5eCombatResolver(),
        clock: clockA,
        networkTimeProvider: () => wallClockT,
      );

      // Minion tombstone timestamp at T + 6h
      final futurePhysical = wallClockT + const Duration(hours: 6).inMilliseconds;
      final historicalTombstone = HybridLogicalClock(
        physicalTime: futurePhysical,
        logicalCounter: 5,
        nodeId: 'node-historical',
      );

      final initialMinions = CrdtOrSet<MinionInstance>(
        tombstones: {'minion_1': historicalTombstone},
      );

      final profile = CampaignProfile.defaultProfile(nodeId: replicaA.value).copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'R1',
          title: 'Future Dungeon',
        ).copyWith(activeMinions: initialMinions),
      );
      campaignRepo.currentProfile = profile;

      final newMinion = MinionInstance(
        id: 'minion_1',
        name: 'Resurrected Armor',
        size: EntitySize.medium,
        currentHp: 25,
        maxHp: 25,
      );

      // Re-add minion through real addMinion code
      final updatedProfile = await combatService.addMinion(
        profile: profile,
        minion: newMinion,
      );

      final updatedMinionItem = updatedProfile.roomState.activeMinions.items['minion_1'];
      expect(updatedMinionItem, isNotNull);

      // Assertions per Section D:
      // 1. No drift rejection
      // 2. New add timestamp > tombstone
      expect(updatedMinionItem!.timestamp.isAfter(historicalTombstone), isTrue);
      // 3. Writer nodeId == A
      expect(updatedMinionItem.timestamp.nodeId, equals(replicaA.value));
      // 4. Add wins correctly under OR-set semantics
      expect(updatedProfile.roomState.activeMinions.activeValues.map((m) => m.id),
          contains('minion_1'));
    });

    // =========================================================================
    // SECTION E: ENCOUNTER FUTURE-HISTORY MUTATION REGRESSION
    // =========================================================================
    test('Section E: Encounter future-history mutation paths succeed causally after history', () async {
      final clockA = StatefulHlcClock(
        replicaId: replicaA,
        timeProvider: () => wallClockT,
      );
      final charRepo = _FakeCharRepo();
      final campaignRepo = _FakeCampaignRepo();
      final combatService = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        replicaId: replicaA,
        combatResolver: const Dnd5eCombatResolver(),
        clock: clockA,
        networkTimeProvider: () => wallClockT,
      );

      final futurePhysical = wallClockT + const Duration(hours: 4).inMilliseconds;
      final p1Hlc = HybridLogicalClock(
        physicalTime: futurePhysical,
        logicalCounter: 0,
        nodeId: 'node-historical',
      );

      final p1 = EncounterParticipant(
        participantId: 'part_1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'gob-1',
          displayName: 'Goblin Boss',
        ),
        initiativeScore: 15,
        currentHp: 20,
        maxHp: 20,
        defense: 13,
      );

      final initialEncounter = const CrdtOrSet<EncounterParticipant>.empty()
          .add('part_1', p1, p1Hlc);

      final profile = CampaignProfile.defaultProfile(nodeId: replicaA.value).copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'R1',
          title: 'Boss Room',
        ).copyWith(activeEncounter: initialEncounter),
      );
      campaignRepo.currentProfile = profile;

      // Update encounter participants with updated participant HP
      final updatedP1 = p1.copyWith(currentHp: 12);
      final updatedProfile = await combatService.updateEncounterParticipants(
        profile: profile,
        encounter: [updatedP1],
      );

      final item = updatedProfile.roomState.activeEncounter.items['part_1'];
      expect(item, isNotNull);
      expect(item!.value.currentHp, equals(12));
      // Assertions per Section E:
      // 1. No remote-drift rejection
      // 2. New timestamp > existing history
      expect(item.timestamp.isAfter(p1Hlc), isTrue);
      // 3. NodeId is current runtime ReplicaId
      expect(item.timestamp.nodeId, equals(replicaA.value));
      // 4. Resulting encounter state remains valid
      expect(updatedProfile.roomState.activeEncounter.activeValues.length, equals(1));
    });

    // =========================================================================
    // SECTION F: MULTI-HISTORY ENCOUNTER ORDERING REGRESSION
    // =========================================================================
    test('Section F: Multi-history encounter mutation stamps strictly after max accepted history', () async {
      final clockA = StatefulHlcClock(
        replicaId: replicaA,
        timeProvider: () => wallClockT,
      );
      final charRepo = _FakeCharRepo();
      final campaignRepo = _FakeCampaignRepo();
      final combatService = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        replicaId: replicaA,
        combatResolver: const Dnd5eCombatResolver(),
        clock: clockA,
        networkTimeProvider: () => wallClockT,
      );

      final tsA = HybridLogicalClock(
        physicalTime: wallClockT + const Duration(hours: 1).inMilliseconds,
        logicalCounter: 0,
        nodeId: 'node-x',
      );
      final tsB = HybridLogicalClock(
        physicalTime: wallClockT + const Duration(hours: 3).inMilliseconds,
        logicalCounter: 2,
        nodeId: 'node-y',
      );
      final tsC = HybridLogicalClock(
        physicalTime: wallClockT + const Duration(hours: 5).inMilliseconds,
        logicalCounter: 4,
        nodeId: 'node-z',
      );

      final pA = EncounterParticipant(
        participantId: 'pA',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'orc-1',
          displayName: 'Orc 1',
        ),
        initiativeScore: 10,
        currentHp: 15,
        maxHp: 15,
        defense: 12,
      );
      final pB = EncounterParticipant(
        participantId: 'pB',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'orc-2',
          displayName: 'Orc 2',
        ),
        initiativeScore: 12,
        currentHp: 15,
        maxHp: 15,
        defense: 12,
      );

      var initialEncounter = const CrdtOrSet<EncounterParticipant>.empty()
          .add('pA', pA, tsA)
          .add('pB', pB, tsB);
      initialEncounter = CrdtOrSet<EncounterParticipant>(
        items: initialEncounter.items,
        tombstones: {'pC': tsC},
      );

      final profile = CampaignProfile.defaultProfile(nodeId: replicaA.value).copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'R1',
          title: 'Orc Camp',
        ).copyWith(activeEncounter: initialEncounter),
      );
      campaignRepo.currentProfile = profile;

      // Mutate by adding a new participant pD while retaining pA and pB
      final pD = EncounterParticipant(
        participantId: 'pD',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'orc-3',
          displayName: 'Orc Shaman',
        ),
        initiativeScore: 18,
        currentHp: 20,
        maxHp: 20,
        defense: 14,
      );

      final updatedProfile = await combatService.updateEncounterParticipants(
        profile: profile,
        encounter: [pA, pB, pD],
      );

      final itemD = updatedProfile.roomState.activeEncounter.items['pD'];
      expect(itemD, isNotNull);

      // Assert newly issued HLC is strictly after the maximum relevant accepted history (tsC at T+5h)
      expect(itemD!.timestamp.isAfter(tsC), isTrue);
      expect(itemD.timestamp.isAfter(tsB), isTrue);
      expect(itemD.timestamp.isAfter(tsA), isTrue);
      expect(itemD.timestamp.nodeId, equals(replicaA.value));
    });

    // =========================================================================
    // SECTION J: PN-COUNTER / HLC SPLIT-BRAIN REGRESSION
    // =========================================================================
    test('Section J: Split-brain mismatched ReplicaId and Clock throws ArgumentError immediately', () {
      final clockB = StatefulHlcClock(
        replicaId: replicaB,
        timeProvider: () => wallClockT,
      );

      // Passing replicaA with clockB MUST throw immediately at construction time
      expect(
        () => CombatEncounterService(
          characterRepo: _FakeCharRepo(),
          campaignRepo: _FakeCampaignRepo(),
          replicaId: replicaA,
          combatResolver: const Dnd5eCombatResolver(),
          clock: clockB,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('CombatEncounterService writer identity mismatch'),
        )),
      );
    });

    // =========================================================================
    // SECTION K: TEST EVERY GUARDED DUAL-INPUT CONSTRUCTOR
    // =========================================================================
    group('Section K: Guarded Constructor Writer Identity Tests', () {
      final clockA = StatefulHlcClock(replicaId: replicaA);
      final clockB = StatefulHlcClock(replicaId: replicaB);

      test('CombatEncounterService validates identity', () {
        expect(
          () => CombatEncounterService(
            characterRepo: _FakeCharRepo(),
            campaignRepo: _FakeCampaignRepo(),
            replicaId: replicaA,
            combatResolver: const Dnd5eCombatResolver(),
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => CombatEncounterService(
            characterRepo: _FakeCharRepo(),
            campaignRepo: _FakeCampaignRepo(),
            replicaId: replicaA,
            combatResolver: const Dnd5eCombatResolver(),
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('RoomSyncOrchestrator validates identity', () {
        final clockSync = ClockSyncService(networkTimePort: _FakeNetworkTimePort());
        expect(
          () => RoomSyncOrchestrator(
            transportPort: _FakeTransportPort(),
            campaignRepo: _FakeCampaignRepo(),
            reconciliationService: RoomStateReconciliationService(
              networkTimeProvider: () => 1000000,
            ),
            clockSyncService: clockSync,
            replicaId: replicaA,
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => RoomSyncOrchestrator(
            transportPort: _FakeTransportPort(),
            campaignRepo: _FakeCampaignRepo(),
            reconciliationService: RoomStateReconciliationService(
              networkTimeProvider: () => 1000000,
            ),
            clockSyncService: clockSync,
            replicaId: replicaA,
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('application PartyRoomService validates identity', () {
        expect(
          () => app_party.PartyRoomService(
            replicaId: replicaA,
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => app_party.PartyRoomService(
            replicaId: replicaA,
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('services/party PartyRoomService.newInstance validates identity', () {
        expect(
          () => svc_party.PartyRoomService.newInstance(
            replicaId: replicaA,
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => svc_party.PartyRoomService.newInstance(
            replicaId: replicaA,
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('LocalCampaignRepository validates identity', () {
        expect(
          () => LocalCampaignRepository(
            replicaId: replicaA,
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => LocalCampaignRepository(
            replicaId: replicaA,
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('DmDashboardController validates identity', () {
        expect(
          () => DmDashboardController(
            replicaId: replicaA,
            clock: clockA,
            campaignRepository: _FakeCampaignRepo(),
            characterRepository: _FakeCharRepo(),
          ),
          returnsNormally,
        );

        expect(
          () => DmDashboardController(
            replicaId: replicaA,
            clock: clockB,
            campaignRepository: _FakeCampaignRepo(),
            characterRepository: _FakeCharRepo(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('HomebrewImportOrchestrator validates identity', () {
        expect(
          () => HomebrewImportOrchestrator(
            ingestorPort: _FakeGithubIngestor(),
            nodeId: replicaA.value,
            clock: clockA,
          ),
          returnsNormally,
        );

        expect(
          () => HomebrewImportOrchestrator(
            ingestorPort: _FakeGithubIngestor(),
            nodeId: replicaA.value,
            clock: clockB,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // SECTION L: DI IDENTITY CONSISTENCY TEST
    // =========================================================================
    test('Section L: DI identity consistency verifies all resolved services match runtime clock', () async {
      SharedPreferences.setMockInitialValues({});
      sl.reset();
      initServiceLocator(replicaId: replicaA);

      final resolvedId = sl<ReplicaId>();
      final resolvedClock = sl<StatefulHlcClock>();

      expect(resolvedId, equals(replicaA));
      expect(resolvedClock.replicaId, equals(replicaA));
      expect(resolvedClock.replicaId, equals(resolvedId));

      // Inspect resolved services
      final combatService = sl<CombatEncounterService>();
      expect(combatService.replicaId, equals(resolvedId));
      expect(combatService.clock.replicaId, equals(resolvedId));

      final partyRoomService = sl<svc_party.PartyRoomService>();
      expect(partyRoomService.replicaId, equals(resolvedId));
      expect(partyRoomService.clock.replicaId, equals(resolvedId));

      final appPartyService = sl<app_party.PartyRoomService>();
      expect(appPartyService.replicaId, equals(resolvedId));
      expect(appPartyService.clock.replicaId, equals(resolvedId));

      final roomSync = sl<RoomSyncOrchestrator>();
      expect(roomSync.replicaId, equals(resolvedId));
      expect(roomSync.clock.replicaId, equals(resolvedId));

      final campaignRepo = sl<ICampaignRepository>() as LocalCampaignRepository;
      expect(campaignRepo.replicaId, equals(resolvedId));
      expect(campaignRepo.clock.replicaId, equals(resolvedId));

      final homebrewOrchestrator = sl<HomebrewImportOrchestrator>();
      expect(homebrewOrchestrator.nodeId, equals(resolvedId.value));
      expect(homebrewOrchestrator.clock.replicaId, equals(resolvedId));

      sl.reset();
    });
  });
}
