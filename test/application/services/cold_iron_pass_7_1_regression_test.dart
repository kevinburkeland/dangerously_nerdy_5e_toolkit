import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_ledger_operations.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import '../../test_doubles/fake_room_document_port.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final Map<String, CampaignProfile> profiles = {};
  final StreamController<CampaignProfile?> _activeController =
      StreamController<CampaignProfile?>.broadcast();
  final StreamController<List<CampaignProfile>> _allController =
      StreamController<List<CampaignProfile>>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

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
    final current = profiles[id] ?? (_activeProfile?.id == id ? _activeProfile! : null);
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

Character _createTestHero(String slug, String name, {int gp = 0}) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    purse: PartyPurse(gp: gp),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    sl.registerSingleton<IRoomDocumentPort>(RecordingRoomDocumentPort());
    CampaignProfileService.resetForTesting();
  });

  group('Cold Iron Birdcage — Pass 7.1 Regression Suite', () {
    test('V1: Live sync drops member purses in reconcileProfileSafely', () async {
      final repA = ReplicaId('node_a');
      final clockA = StatefulHlcClock(replicaId: repA);
      final repoA = _InMemoryCampaignRepo();

      final repB = ReplicaId('node_b');
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoB = _InMemoryCampaignRepo();

      // Register A in DI initially to build A's state
      sl.registerSingleton<ReplicaId>(repA);
      sl.registerSingleton<StatefulHlcClock>(clockA);
      sl.registerSingleton<ICampaignRepository>(repoA);

      final partyServiceA = PartyRoomService(
        replicaId: repA,
        clock: clockA,
      );

      final sessionA = await partyServiceA.createCampaign(
        campaignName: 'Fellowship',
        customRoomCode: 'FELLOW',
        playerName: 'DM',
      );

      // Deposit 7 gp into reserve on A
      await partyServiceA.depositCoins(
        roomCode: sessionA.roomCode,
        playerName: 'DM',
        gp: 7,
      );

      // Add Aria and deposit 50 gp for Aria
      await partyServiceA.addCharacterToRoster(
        roomCode: sessionA.roomCode,
        characterName: 'aria',
        playerName: 'DM',
      );
      await partyServiceA.updateMemberPurse(
        roomCode: sessionA.roomCode,
        characterName: 'Aria',
        characterSlug: 'aria',
        newPurse: PartyPurse(gp: 50),
        performedBy: 'DM',
      );

      final profileA = await partyServiceA.profileForRoom(
        sessionA.roomCode,
        allowCreate: false,
      );
      expect(profileA.partyPurse.getBalance('gp'), equals(7));
      expect(profileA.memberPurses['aria']?.getBalance('gp'), equals(50));

      // Now set up Replica B with the same campaign ID
      final profileB = CampaignProfile(
        id: profileA.id,
        name: 'Fellowship',
        edition: profileA.edition,
        createdAt: profileA.createdAt,
        lastPlayedAt: profileA.lastPlayedAt,
        roomState: RoomNodeState(
          roomId: 'room_FELLOW',
          roomCode: 'FELLOW',
          title: 'Fellowship Staging',
          titleTimestamp: clockB.nextTimestamp(),
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        nodeId: repB.value,
      );
      await repoB.putProfile(profileB);

      // Control: CampaignProfile.join includes aria gp=50
      final joined = CampaignProfile.join(profileB, profileA);
      expect(joined.partyPurse.getBalance('gp'), equals(7));
      expect(joined.memberPurses['aria']?.getBalance('gp'), equals(50));

      // Live path: RoomStateReconciliationService.reconcileProfileSafely
      final recon = RoomStateReconciliationService();
      final reconResult = recon.reconcileProfileSafely(
        local: profileB,
        remote: profileA,
      );

      // In V1 at a7fba17, reconResult.profile.memberPurses drops Aria's purse!
      expect(reconResult.profile.partyPurse.getBalance('gp'), equals(7));
      expect(
        reconResult.profile.memberPurses['aria']?.getBalance('gp'),
        equals(50),
        reason: 'Live sync via reconcileProfileSafely must preserve member purses',
      );
    });

    test('V3: updateCharacterTelemetry doubles coins after legacy import', () async {
      final repA = ReplicaId('node_dm');
      final clockA = StatefulHlcClock(replicaId: repA);
      final repoA = _InMemoryCampaignRepo();

      final repB = ReplicaId('node_player');
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoB = _InMemoryCampaignRepo();

      sl.registerSingleton<ReplicaId>(repA);
      sl.registerSingleton<StatefulHlcClock>(clockA);
      sl.registerSingleton<ICampaignRepository>(repoA);

      final partyServiceA = PartyRoomService(
        replicaId: repA,
        clock: clockA,
      );

      final legacyDoc = {
        'roomCode': 'LEGACY1',
        'campaignId': 'camp_legacy',
        'campaignName': 'Legacy Fellowship',
        'partyPurse': {'gp': 100},
        'memberPurses': {'aria': {'gp': 50}},
        'characterRoster': ['aria'],
        'partyTelemetry': {
          'aria': {
            'id': 'aria',
            'name': 'Aria',
            'hp': 20,
            'maxHp': 20,
          }
        },
      };

      // Replica A joins and imports legacy document
      await partyServiceA.joinCampaign(
        roomCode: 'LEGACY1',
        playerName: 'DM',
        rawDoc: legacyDoc,
      );

      var profA = await repoA.getProfile('camp_legacy');
      expect(profA, isNotNull);
      expect(profA!.memberPurses['aria']?.getBalance('gp'), equals(50));

      // Now A updates character telemetry for Aria whose local Character.purse has 50 gp
      final ariaHero = _createTestHero('aria', 'Aria', gp: 50);
      await partyServiceA.updateCharacterTelemetry(
        roomCode: 'LEGACY1',
        character: ariaHero,
      );

      profA = await repoA.getProfile('camp_legacy');

      // Now Replica B also joins/imports the legacy doc
      sl.unregister<ReplicaId>();
      sl.unregister<StatefulHlcClock>();
      sl.unregister<ICampaignRepository>();
      sl.registerSingleton<ReplicaId>(repB);
      sl.registerSingleton<StatefulHlcClock>(clockB);
      sl.registerSingleton<ICampaignRepository>(repoB);

      final partyServiceB = PartyRoomService(
        replicaId: repB,
        clock: clockB,
      );

      await partyServiceB.joinCampaign(
        roomCode: 'LEGACY1',
        playerName: 'Player',
        rawDoc: legacyDoc,
      );

      final profB = await repoB.getProfile('camp_legacy');
      expect(profB!.memberPurses['aria']?.getBalance('gp'), equals(50));

      // Now merge A into B via join
      final merged = CampaignProfile.join(profB, profA!);

      // At a7fba17, profA replaced aria's purse with Character.purse, creating a second counter key
      // which merges to 100 gp instead of 50 gp!
      expect(
        merged.memberPurses['aria']?.getBalance('gp'),
        equals(50),
        reason: 'Telemetry update must not rewrite member purse with duplicate counter',
      );
    });

    test('V3b: Character purse seed uses character-seed:<slug> to prevent duplicate coin merge', () {
      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'init');
      final base = CampaignProfile.raw(
        id: 'c1',
        nameRegister: const CrdtLwwRegister(value: 'C', timestamp: genesisTs),
        edition: const RulesetIdentifier('generic_tabletop'),
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: const RoomNodeState.empty(),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );

      final seededA = PartyLedgerOperations.seedCharacterPurse(
        profile: base,
        characterSlug: 'bram',
        openingPurse: PartyPurse(gp: 40),
      );
      final seededB = PartyLedgerOperations.seedCharacterPurse(
        profile: base,
        characterSlug: 'bram',
        openingPurse: PartyPurse(gp: 40),
      );

      final bramPurse = seededA.memberPurses['bram']!;
      expect(bramPurse.gpCounter.positive.keys, contains('character-seed:bram'));

      final merged = CampaignProfile.join(seededA, seededB);
      expect(merged.memberPurses['bram']?.getBalance('gp'), equals(40));
    });

    test('V4: Re-running legacy import removes characters from roster', () async {
      final repA = ReplicaId('node_import');
      final clockA = StatefulHlcClock(replicaId: repA);
      final repoA = _InMemoryCampaignRepo();

      sl.registerSingleton<ReplicaId>(repA);
      sl.registerSingleton<StatefulHlcClock>(clockA);
      sl.registerSingleton<ICampaignRepository>(repoA);

      final partyService = PartyRoomService(
        replicaId: repA,
        clock: clockA,
      );

      final legacyDoc = {
        'roomCode': 'ROSTER1',
        'campaignId': 'camp_roster',
        'campaignName': 'Roster Campaign',
        'characterRoster': ['aria'],
        'partyTelemetry': {
          'aria': {'id': 'aria', 'name': 'Aria', 'hp': 10, 'maxHp': 10}
        },
      };

      // 1. Initial join & import
      await partyService.joinCampaign(roomCode: 'ROSTER1', playerName: 'DM', rawDoc: legacyDoc);
      var prof = await repoA.getProfile('camp_roster');
      expect(prof!.partyRoster.activeValues, contains('aria'));

      // 2. Add Bram through public service method
      await partyService.addCharacterToRoster(
        roomCode: 'ROSTER1',
        characterName: 'bram',
        playerName: 'DM',
      );
      prof = await repoA.getProfile('camp_roster');
      expect(prof!.partyRoster.activeValues, containsAll(['aria', 'bram']));

      // 3. Re-run joinCampaign with the same legacy document
      await partyService.joinCampaign(roomCode: 'ROSTER1', playerName: 'DM', rawDoc: legacyDoc);
      prof = await repoA.getProfile('camp_roster');

      // In V4 at a7fba17, the import prunes bram because bram is missing from legacyDoc['characterRoster']!
      expect(
        prof!.partyRoster.activeValues,
        containsAll(['aria', 'bram']),
        reason: 'Re-running legacy import must not prune characters added after import',
      );
    });

    test('V5: profileForRoom overwrites lobby campaignId when local profile has different ID', () async {
      final rep = ReplicaId('node_joiner');
      final clock = StatefulHlcClock(replicaId: rep);
      final repo = _InMemoryCampaignRepo();

      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final partyService = PartyRoomService(
        replicaId: rep,
        clock: clock,
      );

      // Joiner holds one local profile claiming room CR-X with id 'campaign_CR-X'
      final localProfile = CampaignProfile(
        id: 'campaign_CR-X',
        name: 'Local Claimant',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_CR-X',
          roomCode: 'CR-X',
          title: 'Claimant Staging',
          titleTimestamp: clock.nextTimestamp(),
        ),
        nodeId: rep.value,
      );
      await repo.putProfile(localProfile);

      // Lobby exists with a different campaign ID: campaign_1760000000000
      final lobbyDoc = {
        'roomCode': 'CR-X',
        'campaignId': 'campaign_1760000000000',
        'campaignName': 'DM Campaign',
        'hostKeyHash': 'hash123',
        'activePlayers': ['DM'],
      };

      // Expected: profileForRoom / joinCampaign throws an error naming both IDs
      // At a7fba17, it resolves 'campaign_CR-X' without throwing!
      expect(
        () => partyService.joinCampaign(roomCode: 'CR-X', playerName: 'Joiner', rawDoc: lobbyDoc),
        throwsA(isA<StateError>()),
        reason: 'Joining a lobby with conflicting local profile claiming room code must fail with error naming both IDs',
      );
    });

    test('V6: Edition mismatch and genesis title fault on DM adopted profile vs player join', () async {
      final repA = ReplicaId('dm_node');
      final clockA = StatefulHlcClock(replicaId: repA);
      final repoA = _InMemoryCampaignRepo();

      final repB = ReplicaId('player_node');
      final clockB = StatefulHlcClock(replicaId: repB);
      final repoB = _InMemoryCampaignRepo();

      // DM adopts profile from registry: default edition is generic_tabletop, title is genesis
      final reg = CampaignRegistryService.newInstance();
      await reg.saveMembership(CampaignMembership(
        roomCode: 'EDITION1',
        campaignName: 'Adopted Fellowship',
        characterId: 'hero-1',
        role: CampaignRole.host,
        lastPlayed: DateTime.now(),
      ));

      await CampaignStorageMigration.adoptRegistryMemberships(
        repoA,
        clock: clockA,
        nodeId: repA.value,
        registryService: reg,
      );

      final dmProfile = (await repoA.loadAllProfiles()).first;
      expect(dmProfile.rulesetId, equals('generic_tabletop'));

      // Player creates profile via profileForRoom (at a7fba17 it uses v2024)
      sl.registerSingleton<ReplicaId>(repB);
      sl.registerSingleton<StatefulHlcClock>(clockB);
      sl.registerSingleton<ICampaignRepository>(repoB);

      final partyServiceB = PartyRoomService(
        replicaId: repB,
        clock: clockB,
      );

      final playerProfile = await partyServiceB.profileForRoom(
        'EDITION1',
        allowCreate: true,
      );

      // Reconcile fails at a7fba17 due to Incompatible ruleset edition: "generic_tabletop" vs "v2024"
      final recon = RoomStateReconciliationService();
      expect(
        () {
          final res = recon.reconcileProfileSafely(
            local: dmProfile,
            remote: playerProfile,
          );
          if (res.fieldFaults.any((f) => f.field.contains('title'))) {
            throw StateError('Genesis title fault on roomState.title');
          }
        },
        returnsNormally,
        reason: 'Sync between adopted DM and joining player must not fail on edition or genesis title',
      );
    });

    test('Link path: createCampaign(linkProfileId: ...) links existing profile', () async {
      final rep = ReplicaId('node_creator');
      final clock = StatefulHlcClock(replicaId: rep);
      final repo = _InMemoryCampaignRepo();

      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final partyService = PartyRoomService(
        replicaId: rep,
        clock: clock,
      );

      // Existing profile with no room code
      final existing = CampaignProfile(
        id: 'camp_unlinked',
        name: 'Unlinked Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: const RoomNodeState.empty(),
        nodeId: rep.value,
      );
      await repo.putProfile(existing);

      // At a7fba17, createCampaign(linkProfileId: 'camp_unlinked') throws ArgumentError
      // because copyWith(title: ...) is called without titleTimestamp
      expect(
        () => partyService.createCampaign(
          campaignName: 'Linked Room',
          customRoomCode: 'LINK1',
          playerName: 'DM',
          linkProfileId: 'camp_unlinked',
        ),
        returnsNormally,
        reason: 'createCampaign with linkProfileId must link the profile and stamp titleTimestamp without throwing',
      );
    });

    test('Activation: Ledger and stream operations do not switch DM active profile', () async {
      final rep = ReplicaId('node_dm');
      final clock = StatefulHlcClock(replicaId: rep);
      final repo = _InMemoryCampaignRepo();

      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final partyService = PartyRoomService(
        replicaId: rep,
        clock: clock,
      );

      // DM has campaign X active
      final profX = CampaignProfile(
        id: 'campaign_X',
        name: 'Campaign X',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_ROOMX',
          roomCode: 'ROOMX',
          title: 'Room X',
          titleTimestamp: clock.nextTimestamp(),
        ),
        nodeId: rep.value,
      );
      await repo.putProfile(profX);
      await repo.setActiveProfileId(profX.id);
      expect(repo.activeProfileId, equals('campaign_X'));

      // Create Campaign Y
      final profY = CampaignProfile(
        id: 'campaign_Y',
        name: 'Campaign Y',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
        roomState: RoomNodeState(
          roomId: 'room_ROOMY',
          roomCode: 'ROOMY',
          title: 'Room Y',
          titleTimestamp: clock.nextTimestamp(),
        ),
        nodeId: rep.value,
      );
      await repo.putProfile(profY);

      // Ensure active is X
      await repo.setActiveProfileId(profX.id);
      expect(repo.activeProfileId, equals('campaign_X'));

      // A ledger operation for Room Y arrives (e.g. depositCoins on ROOMY)
      await partyService.depositCoins(
        roomCode: 'ROOMY',
        playerName: 'DM',
        gp: 10,
      );

      // At a7fba17, profileForRoom('ROOMY') called setActiveProfileId('campaign_Y')!
      expect(
        repo.activeProfileId,
        equals('campaign_X'),
        reason: 'Ledger operation on Room Y must not switch DM active profile away from Campaign X',
      );
    });
  });
}
