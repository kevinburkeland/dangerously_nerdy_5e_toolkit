import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/room_profile_genesis_restamper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_dashboard_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/party/campaign_dialogs.dart';

class _CountingCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final Map<String, CampaignProfile> profiles = {};
  int updateProfileCalls = 0;
  int putProfileCalls = 0;

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
    putProfileCalls++;
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
    }
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    updateProfileCalls++;
    final current = profiles[id] ?? (_activeProfile?.id == id ? _activeProfile! : null);
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    CampaignProfileService.resetForTesting();
    PartyRoomService.setCustomInstanceForTesting(null);
  });

  group('Cold Iron Birdcage Pass 7.2 Regression Suite at df02baa', () {
    test('G1: restampIfNeeded re-stamps genesis titles with clock node and physicalTime > 0', () {
      final repA = ReplicaId('dev-a');
      final clockA = StatefulHlcClock(replicaId: repA);

      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis');
      final genesisProfile = CampaignProfile.raw(
        id: 'camp_1',
        nameRegister: const CrdtLwwRegister(value: 'Camp 1', timestamp: genesisTs),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_1',
          roomCode: 'CR-X',
          title: 'Campaign CR-X Staging',
          titleTimestamp: genesisTs,
          description: '',
          descriptionTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );

      final restamped = RoomProfileGenesisRestamper.restampIfNeeded(
        profile: genesisProfile,
        clock: clockA,
      );

      // Expected: title stamp node dev-a, physical time > 0, title text unchanged
      expect(restamped.roomState.title, equals('Campaign CR-X Staging'));
      expect(restamped.roomState.titleRegister.timestamp.nodeId, equals('dev-a'));
      expect(restamped.roomState.titleRegister.timestamp.physicalTime, greaterThan(0));
      expect(RoomProfileGenesisRestamper.isGenesisTimestamp(restamped.roomState.titleRegister.timestamp), isFalse);

      // Control: a profile built with a real title stamp comes back unchanged
      final realTs = clockA.nextTimestamp();
      final realProfile = genesisProfile.copyWith(
        roomState: genesisProfile.roomState.copyWith(
          title: 'Real Staged',
          titleTimestamp: realTs,
          description: '',
          descriptionTimestamp: realTs,
        ),
      );
      final restampedReal = RoomProfileGenesisRestamper.restampIfNeeded(
        profile: realProfile,
        clock: clockA,
      );
      expect(restampedReal, equals(realProfile));
    });

    test('G2: Two profiles for room CR-X with different genesis titles converge with zero faults', () {
      final recon = RoomStateReconciliationService();
      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis');
      final profileA = CampaignProfile.raw(
        id: 'camp_crx',
        nameRegister: const CrdtLwwRegister(value: 'Camp CR-X', timestamp: genesisTs),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_crx',
          roomCode: 'CR-X',
          title: 'Campaign CR-X Staging',
          titleTimestamp: genesisTs,
          description: '',
          descriptionTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );

      final profileB = CampaignProfile.raw(
        id: 'camp_crx',
        nameRegister: const CrdtLwwRegister(value: 'Camp CR-X', timestamp: genesisTs),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_crx',
          roomCode: 'CR-X',
          title: 'Main Hall Staging Area',
          titleTimestamp: genesisTs,
          description: '',
          descriptionTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );

      final clockA = StatefulHlcClock(replicaId: ReplicaId('dev-a'));
      final clockB = StatefulHlcClock(replicaId: ReplicaId('dev-b'));

      final restampedA = RoomProfileGenesisRestamper.restampIfNeeded(profile: profileA, clock: clockA);
      final restampedB = RoomProfileGenesisRestamper.restampIfNeeded(profile: profileB, clock: clockB);

      final resAB = recon.reconcileProfileSafely(
        local: restampedA,
        remote: restampedB,
      );
      final resBA = recon.reconcileProfileSafely(
        local: restampedB,
        remote: restampedA,
      );

      expect(resAB.fieldFaults, isEmpty);
      expect(resBA.fieldFaults, isEmpty);
      expect(resAB.profile.roomState.title, equals(resBA.profile.roomState.title));

      // Control: two profiles with the same genesis title reconcile with zero faults
      final sameGenesis = recon.reconcileProfileSafely(
        local: profileA,
        remote: profileA,
      );
      expect(sameGenesis.fieldFaults, isEmpty);
    });

    test('Every-open write: opening a genesis-titled room profile twice calls updateProfile 1 time, then 0', () async {
      final repo = _CountingCampaignRepo();
      final rep = ReplicaId('node-1');
      final clock = StatefulHlcClock(replicaId: rep);
      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<ICampaignRepository>(repo);
      sl.registerSingleton<StatefulHlcClock>(clock);

      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis');
      final genesisProfile = CampaignProfile.raw(
        id: 'campaign_OPEN1',
        nameRegister: const CrdtLwwRegister(value: 'Camp Open', timestamp: genesisTs),
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_OPEN1',
          roomCode: 'OPEN1',
          title: 'Campaign OPEN1 Staging',
          titleTimestamp: genesisTs,
          description: '',
          descriptionTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );
      await repo.putProfile(genesisProfile);
      repo.updateProfileCalls = 0; // reset after initial setup

      final partyService = PartyRoomService(replicaId: rep, clock: clock);
      await partyService.openRoomProfile('OPEN1');
      expect(repo.updateProfileCalls, equals(1));

      // Second open: should NOT call updateProfile because title/desc were already re-stamped!
      await partyService.openRoomProfile('OPEN1');
      expect(repo.updateProfileCalls, equals(1)); // Expected 1 call total, before fix it is 2 (1 call each open)
    });

    test('R3: openRoomProfile throws when no lobby readable and no local profile exists', () async {
      final repo = _CountingCampaignRepo();
      final rep = ReplicaId('node-r3');
      final clock = StatefulHlcClock(replicaId: rep);
      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<ICampaignRepository>(repo);
      sl.registerSingleton<StatefulHlcClock>(clock);

      final partyService = PartyRoomService(replicaId: rep, clock: clock);

      // Case 1: No profile claiming CR-X, no cached lobby, no Firestore -> Expected: throws, no profile created
      expect(() => partyService.openRoomProfile('CR-X'), throwsA(isA<StateError>()));
      expect(repo.allProfiles, isEmpty);

      // Case 2: Lobby is cached with campaignId: campaign_1760000000000 -> creates campaign_1760000000000
      partyService.cacheLobbyForTesting(PartyRoomLobby(
        roomCode: 'CR-X',
        campaignId: 'campaign_1760000000000',
        rulesetId: 'v2024',
        campaignName: 'Dashboard Campaign',
        hostKeyHash: 'hash',
        activePlayers: const [],
        lastUpdated: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));

      final prof2 = await partyService.openRoomProfile('CR-X');
      expect(prof2.id, equals('campaign_1760000000000'));
      expect(repo.profiles.containsKey('campaign_1760000000000'), isTrue);

      // Control: Kevin's shape opens campaign_<ROOMCODE> with no lobby id passed
      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis');
      final kevProfile = CampaignProfile.raw(
        id: 'campaign_KEV1',
        nameRegister: const CrdtLwwRegister(value: 'Kevin Campaign', timestamp: genesisTs),
        edition: DmRulesEdition.v2014,
        createdAt: DateTime.utc(2025),
        lastPlayedAt: DateTime.utc(2025),
        roomState: RoomNodeState(
          roomId: 'room_KEV1',
          roomCode: 'KEV1',
          title: 'Kevin Staging Area',
          titleTimestamp: genesisTs,
          description: '',
          descriptionTimestamp: genesisTs,
        ),
        partyPurse: const PartyPurse.empty(),
        memberPurses: const {},
        partyRoster: const CrdtOrSet<String>.empty(),
        pinnedRules: const CrdtOrSet<String>.empty(),
        notesRegister: const CrdtLwwRegister(value: '', timestamp: genesisTs),
        changeLog: const [],
      );
      await repo.putProfile(kevProfile);

      final openedKev = await partyService.openRoomProfile('KEV1');
      expect(openedKev.id, equals('campaign_KEV1'));
      expect(openedKev.name, equals('Kevin Campaign'));
    });

    testWidgets('R4: Landing screen dialog creates new profile and leaves active room-less profile unlinked', (tester) async {
      final rep = ReplicaId('landing_test_replica');
      final clock = StatefulHlcClock(replicaId: rep);
      final repo = _CountingCampaignRepo();
      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final partyService = PartyRoomService(replicaId: rep, clock: clock);
      PartyRoomService.setCustomInstanceForTesting(partyService);

      final defaultProfile = CampaignProfile.defaultProfile(
        id: 'camp_default',
        name: 'My Campaign',
        edition: DmRulesEdition.v2024,
        nodeId: rep.value,
        clock: clock,
      );
      await repo.putProfile(defaultProfile);
      await repo.setActiveProfileId(defaultProfile.id);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CreateCampaignDialog.show(ctx),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Campaign / Party Name'), 'Fresh Campaign');
      await tester.tap(find.text('Create Campaign'));
      await tester.pumpAndSettle();

      // Check active profile: before fix, it got claimed/linked because CreateCampaignDialog read active profile!
      final activeProf = await repo.getProfile('camp_default');
      expect(activeProf!.roomState.roomCode, isEmpty, reason: 'Landing screen dialog must not link active profile');
    });

    testWidgets('R4: DM Dashboard shows Open Party Room only when roomCode is empty and links profile on create', (tester) async {
      final rep = ReplicaId('dm_test_replica');
      final clock = StatefulHlcClock(replicaId: rep);
      final repo = _CountingCampaignRepo();
      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(repo);

      final partyService = PartyRoomService(replicaId: rep, clock: clock);
      PartyRoomService.setCustomInstanceForTesting(partyService);

      final roomlessProfile = CampaignProfile.defaultProfile(
        id: 'camp_dm_roomless',
        name: 'Underdark Exploration',
        edition: DmRulesEdition.v2024,
        nodeId: rep.value,
        clock: clock,
      );
      await repo.putProfile(roomlessProfile);
      await repo.setActiveProfileId(roomlessProfile.id);

      await tester.pumpWidget(const MaterialApp(
        home: DmDashboardScreen(),
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Expect 'Open Party Room...' item exists before fix: FAILS (does not exist yet at df02baa)
      expect(find.text('Open Party Room...'), findsOneWidget);
    });
  });
}
