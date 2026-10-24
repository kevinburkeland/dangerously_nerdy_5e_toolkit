import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import '../../test_doubles/hive_test_harness.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;
  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id];
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}

Character _createHero(String slug, String name, {PartyPurse purse = const PartyPurse.empty()}) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    purse: purse,
    speciesRef: const EntityReference.empty(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
    progression: const CharacterProgression(classes: []),
    baseScores: const AbilityScores.standardArray(),
  );
}

void main() {
  group('Cold Iron Birdcage: Pass 7.1 — Two-Device Create/Join/Sync Suite (Q4)', () {
    final recon = RoomStateReconciliationService();
    final harness = HiveTestHarness();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await harness.setUpInMemory();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    Future<void> syncReplicas(
      _InMemoryCampaignRepo fromRepo,
      _InMemoryCampaignRepo toRepo,
      StatefulHlcClock toClock,
      String profileId,
    ) async {
      final from = await fromRepo.getProfile(profileId);
      final to = await toRepo.getProfile(profileId);
      if (from == null || to == null) return;

      final remoteHlcs = <HybridLogicalClock>[
        from.nameRegister.timestamp,
        from.notesRegister.timestamp,
        from.roomState.titleRegister.timestamp,
        from.roomState.descriptionRegister.timestamp,
        for (final reg in from.partyRoster.items.values) reg.timestamp,
        for (final ts in from.partyRoster.tombstones.values) ts,
      ];
      toClock.observeAllRemote(remoteHlcs);

      final res = recon.reconcileProfileSafely(local: to, remote: from);
      expect(res.hasFaults, isFalse, reason: 'Sync reconciliation must have zero faults');
      await toRepo.putProfile(res.profile);
    }

    test('Case (i): Created by createCampaign with no link', () async {
      const roomCode = 'CR-ORIGIN1';
      final repA = ReplicaId('rep_a_i');
      final repB = ReplicaId('rep_b_i');
      final clockA = StatefulHlcClock(replicaId: repA);
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoA = _InMemoryCampaignRepo();
      final repoB = _InMemoryCampaignRepo();

      final serviceA = PartyRoomService(
        replicaId: repA,
        clock: clockA,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: CampaignProfileService(repo: repoA, clock: clockA, replicaId: repA),
      );
      final serviceB = PartyRoomService(
        replicaId: repB,
        clock: clockB,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: CampaignProfileService(repo: repoB, clock: clockB, replicaId: repB),
      );

      // DM creates campaign on Device A
      await serviceA.createCampaign(
        campaignName: 'Origin 1 Campaign',
        customRoomCode: roomCode,
        playerName: 'DM',
      );

      final cachedSession = serviceA.getCachedSession(roomCode)!;
      final cachedLobby = serviceA.getCachedLobby(roomCode)!;
      final lobbyDoc = <String, dynamic>{
        'roomCode': roomCode,
        'code': roomCode,
        'campaignName': cachedSession.campaignName,
        'campaignId': cachedLobby.campaignId,
        'rulesetId': cachedLobby.rulesetId,
        'hostKeyHash': cachedSession.hostKeyHash,
        'activePlayers': cachedSession.activePlayers,
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      final lobbyCampaignIdBeforeJoin = cachedLobby.campaignId;
      expect(lobbyCampaignIdBeforeJoin, isNotNull);

      // Device B joins with no local profiles
      await serviceB.joinCampaign(
        roomCode: roomCode,
        playerName: 'Player_B',
        rawDoc: lobbyDoc,
      );

      // Character links on B
      final heroB = _createHero('bram', 'Bram', purse: PartyPurse(gp: 40));
      await serviceB.linkCharacterToCampaign(
        roomCode: roomCode,
        character: heroB,
      );

      // DM pushes telemetry for it from A
      await serviceA.updateCharacterTelemetry(
        roomCode: roomCode,
        character: heroB,
      );

      final profAId = (await serviceA.profileForRoom(
        roomCode,
        lobbyCampaignId: lobbyCampaignIdBeforeJoin,
        allowCreate: false,
      )).id;

      // Full syncs go both ways twice
      await syncReplicas(repoA, repoB, clockB, profAId);
      await syncReplicas(repoB, repoA, clockA, profAId);
      await syncReplicas(repoA, repoB, clockB, profAId);
      await syncReplicas(repoB, repoA, clockA, profAId);

      // Assertions
      final profA = (await repoA.getProfile(profAId))!;
      final profB = (await repoB.getProfile(profAId))!;

      // 1. Both devices resolve the same campaign id
      expect(profA.id, equals(profB.id));
      expect(profA.id, equals(lobbyCampaignIdBeforeJoin));

      // 2. The lobby's campaignId is unchanged by the join
      expect(serviceA.getCachedLobby(roomCode)!.campaignId, equals(lobbyCampaignIdBeforeJoin));
      expect(serviceB.getCachedLobby(roomCode)!.campaignId, equals(lobbyCampaignIdBeforeJoin));

      // 3. Editions match
      expect(profA.edition, equals(profB.edition));

      // 4. Profiles are equal with zero reconcile faults
      final reconResult = recon.reconcileProfileSafely(local: profA, remote: profB);
      expect(reconResult.hasFaults, isFalse);
      expect(profA, equals(profB));
      expect(profA.partyRoster.activeValues, contains('bram'));
      expect(profA.memberPurses['bram']?.getBalance('gp'), equals(40));
    });

    test('Case (ii): Linked from DM dashboard via linkProfileId', () async {
      const roomCode = 'CR-ORIGIN2';
      final repA = ReplicaId('rep_a_ii');
      final repB = ReplicaId('rep_b_ii');
      final clockA = StatefulHlcClock(replicaId: repA);
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoA = _InMemoryCampaignRepo();
      final repoB = _InMemoryCampaignRepo();

      final profileServiceA = CampaignProfileService(repo: repoA, clock: clockA, replicaId: repA);
      final serviceA = PartyRoomService(
        replicaId: repA,
        clock: clockA,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: profileServiceA,
      );
      final serviceB = PartyRoomService(
        replicaId: repB,
        clock: clockB,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: CampaignProfileService(repo: repoB, clock: clockB, replicaId: repB),
      );

      // Create an existing profile on Device A (as from DM dashboard)
      final existingProfile = await profileServiceA.createProfile(
        name: 'Linked DM Campaign',
        edition: DmRulesEdition.v2014,
      );
      final linkedId = existingProfile.id;

      // DM creates room linking this profile
      await serviceA.createCampaign(
        campaignName: 'Linked Room',
        customRoomCode: roomCode,
        playerName: 'DM',
        linkProfileId: linkedId,
      );

      final cachedSession = serviceA.getCachedSession(roomCode)!;
      final cachedLobby = serviceA.getCachedLobby(roomCode)!;
      expect(cachedLobby.campaignId, equals(linkedId));
      expect(cachedLobby.rulesetId, equals(existingProfile.rulesetId));

      final lobbyDoc = <String, dynamic>{
        'roomCode': roomCode,
        'code': roomCode,
        'campaignName': cachedSession.campaignName,
        'campaignId': cachedLobby.campaignId,
        'rulesetId': cachedLobby.rulesetId,
        'hostKeyHash': cachedSession.hostKeyHash,
        'activePlayers': cachedSession.activePlayers,
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      // Device B joins with no local profiles
      await serviceB.joinCampaign(
        roomCode: roomCode,
        playerName: 'Player_B',
        rawDoc: lobbyDoc,
      );

      // Character links on B
      final heroB = _createHero('bram', 'Bram', purse: PartyPurse(gp: 60));
      await serviceB.linkCharacterToCampaign(
        roomCode: roomCode,
        character: heroB,
      );

      // DM pushes telemetry for it from A
      await serviceA.updateCharacterTelemetry(
        roomCode: roomCode,
        character: heroB,
      );

      // Full syncs go both ways twice
      await syncReplicas(repoA, repoB, clockB, linkedId);
      await syncReplicas(repoB, repoA, clockA, linkedId);
      await syncReplicas(repoA, repoB, clockB, linkedId);
      await syncReplicas(repoB, repoA, clockA, linkedId);

      // Assertions
      final profA = (await repoA.getProfile(linkedId))!;
      final profB = (await repoB.getProfile(linkedId))!;

      // 1. Both devices resolve the same campaign id
      expect(profA.id, equals(profB.id));
      expect(profA.id, equals(linkedId));

      // 2. The lobby's campaignId is unchanged by the join
      expect(serviceA.getCachedLobby(roomCode)!.campaignId, equals(linkedId));
      expect(serviceB.getCachedLobby(roomCode)!.campaignId, equals(linkedId));

      // 3. Editions match (both 2014)
      expect(profA.edition, equals(existingProfile.edition));
      expect(profB.edition, equals(existingProfile.edition));

      // 4. Profiles are equal with zero reconcile faults
      final reconResult = recon.reconcileProfileSafely(local: profA, remote: profB);
      expect(reconResult.hasFaults, isFalse);
      expect(profA, equals(profB));
      expect(profA.partyRoster.activeValues, contains('bram'));
      expect(profA.memberPurses['bram']?.getBalance('gp'), equals(60));
    });

    test('Case (iii): Kevin\'s shape: legacy room document with no campaignId/rulesetId and adopted profile', () async {
      const roomCode = 'CR-KEV1';
      final repA = ReplicaId('rep_a_iii');
      final repB = ReplicaId('rep_b_iii');
      final clockA = StatefulHlcClock(replicaId: repA);
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoA = _InMemoryCampaignRepo();
      final repoB = _InMemoryCampaignRepo();

      final serviceA = PartyRoomService(
        replicaId: repA,
        clock: clockA,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: CampaignProfileService(repo: repoA, clock: clockA, replicaId: repA),
      );
      final serviceB = PartyRoomService(
        replicaId: repB,
        clock: clockB,
        registry: CampaignRegistryService.newInstance(),
        campaignProfileService: CampaignProfileService(repo: repoB, clock: clockB, replicaId: repB),
      );

      // Legacy room document with ledger fields and no campaignId or rulesetId
      final legacyDoc = <String, dynamic>{
        'roomCode': roomCode,
        'code': roomCode,
        'campaignName': 'My Campaign',
        'hostKeyHash': 'hash_kev',
        'activePlayers': ['DM'],
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'partyPurse': {'gp': 200, 'sp': 50},
        'characterRoster': ['Aria'],
        'memberPurses': {'aria': {'gp': 75}},
        'partyTelemetry': {
          'aria': {
            'id': 'aria',
            'name': 'Aria',
            'characterClass': 'Fighter',
            'currentHp': 20,
            'maxHp': 20,
          },
        },
      };

      // Device A holds 3 profiles named "My Campaign":
      // 1. Adopted campaign_CR-KEV1 with core default edition and genesis-stamped title
      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'init');
      final adoptedProfile = CampaignProfile.raw(
        id: 'campaign_$roomCode',
        nameRegister: const CrdtLwwRegister(value: 'My Campaign', timestamp: genesisTs),
        edition: const RulesetIdentifier('generic_tabletop'),
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_CR-KEV1',
          roomCode: roomCode,
          title: 'My Campaign',
          titleTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );
      await repoA.putProfile(adoptedProfile);

      // 2. Clone that claims the same room code
      final cloneProfile = CampaignProfile.raw(
        id: 'campaign_clone_CR-KEV1',
        nameRegister: CrdtLwwRegister(value: 'My Campaign', timestamp: clockA.nextTimestamp()),
        edition: const RulesetIdentifier('generic_tabletop'),
        createdAt: DateTime.utc(2025, 2),
        lastPlayedAt: DateTime.utc(2025, 2),
        roomState: RoomNodeState(
          roomId: 'room_clone',
          roomCode: roomCode,
          title: 'My Campaign',
          titleTimestamp: clockA.nextTimestamp(),
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister(value: '', timestamp: clockA.nextTimestamp()),
        changeLog: const [],
      );
      await repoA.putProfile(cloneProfile);

      // 3. Room-less "My Campaign" default
      final defaultProfile = CampaignProfile.raw(
        id: 'campaign_default_no_room',
        nameRegister: CrdtLwwRegister(value: 'My Campaign', timestamp: clockA.nextTimestamp()),
        edition: const RulesetIdentifier('generic_tabletop'),
        createdAt: DateTime.utc(2025, 3),
        lastPlayedAt: DateTime.utc(2025, 3),
        roomState: const RoomNodeState.empty(),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: CrdtLwwRegister(value: '', timestamp: clockA.nextTimestamp()),
        changeLog: const [],
      );
      await repoA.putProfile(defaultProfile);

      // Device A joins and imports legacy document
      await serviceA.joinCampaign(
        roomCode: roomCode,
        playerName: 'DM',
        rawDoc: legacyDoc,
      );

      // Device B joins with no local profiles
      await serviceB.joinCampaign(
        roomCode: roomCode,
        playerName: 'Player_B',
        rawDoc: legacyDoc,
      );

      // Character links on B
      final heroB = _createHero('bram', 'Bram', purse: PartyPurse(gp: 40));
      await serviceB.linkCharacterToCampaign(
        roomCode: roomCode,
        character: heroB,
      );

      // DM pushes telemetry for it from A
      await serviceA.updateCharacterTelemetry(
        roomCode: roomCode,
        character: heroB,
      );

      const campaignId = 'campaign_$roomCode';

      // Full syncs go both ways twice
      await syncReplicas(repoA, repoB, clockB, campaignId);
      await syncReplicas(repoB, repoA, clockA, campaignId);
      await syncReplicas(repoA, repoB, clockB, campaignId);
      await syncReplicas(repoB, repoA, clockA, campaignId);

      // Assertions
      final profA = (await repoA.getProfile(campaignId))!;
      final profB = (await repoB.getProfile(campaignId))!;

      // 1. Both devices resolve the same campaign id
      expect(profA.id, equals(profB.id));
      expect(profA.id, equals('campaign_$roomCode'));

      // 2. In case (iii), A still opens campaign_<ROOMCODE>
      expect(profA.id, equals('campaign_$roomCode'));

      // 3. Editions match (v2024)
      expect(profA.edition, equals(RulesetEdition.v2024));
      expect(profB.edition, equals(RulesetEdition.v2024));

      // 4. Profiles are equal with zero reconcile faults
      final reconResult = recon.reconcileProfileSafely(local: profA, remote: profB);
      expect(reconResult.hasFaults, isFalse);
      expect(profA, equals(profB));

      // 5. Every imported balance is counted once
      expect(profA.partyPurse.getBalance('gp'), equals(200));
      expect(profA.partyPurse.getBalance('sp'), equals(50));
      expect(profA.memberPurses['aria']?.getBalance('gp'), equals(75));

      // And bram's linked balance is counted once
      expect(profA.memberPurses['bram']?.getBalance('gp'), equals(40));
      expect(profA.partyRoster.activeValues, containsAll(['aria', 'bram']));
    });
  });
}
