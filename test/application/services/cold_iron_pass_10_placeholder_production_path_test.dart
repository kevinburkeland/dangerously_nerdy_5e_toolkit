import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/room_code_relink.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import '../../test_doubles/fake_room_document_port.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReplicaId rep;
  late StatefulHlcClock clock;
  late _InMemoryCampaignRepo repo;
  late RecordingRoomDocumentPort recordingPort;
  late PartyRoomService service;
  final recon = RoomStateReconciliationService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    CampaignProfileService.resetForTesting();
    PartyRoomService.setCustomInstanceForTesting(null);

    rep = ReplicaId('joiner_device');
    clock = StatefulHlcClock(replicaId: rep);
    repo = _InMemoryCampaignRepo();
    recordingPort = RecordingRoomDocumentPort();

    sl.registerSingleton<ReplicaId>(rep);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(repo);
    sl.registerSingleton<IRoomDocumentPort>(recordingPort);

    service = PartyRoomService(replicaId: rep, clock: clock);
  });

  String randomText(Random rng, List<String> defaults) {
    final choice = rng.nextInt(defaults.length + 3);
    if (choice < defaults.length) {
      return defaults[choice];
    }
    const words = ['Dragon', 'Dungeon', 'Quest', 'Treasure', 'Gold', 'Secret', 'Lair', 'Cavern'];
    return List.generate(rng.nextInt(4) + 1, (_) => words[rng.nextInt(words.length)]).join(' ');
  }

  void runReconciliationLaw({
    required CampaignProfile placeholder,
    required String pathName,
    required String lobbyOrMembershipName,
  }) {
    final roomCode = placeholder.roomState.roomCode;
    final defaults = [
      '',
      'Campaign $roomCode',
      'Campaign $roomCode Staging',
      lobbyOrMembershipName,
    ];

    for (var seed = 0; seed < 200; seed++) {
      final rng = Random(seed);
      try {
        final dmName = randomText(rng, defaults);
        final dmTitle = randomText(rng, defaults);
        final dmDesc = randomText(rng, defaults);
        final dmNotes = randomText(rng, defaults);

        final nameTs = HybridLogicalClock(
          physicalTime: rng.nextInt(1000000) + 1,
          logicalCounter: rng.nextInt(50),
          nodeId: 'dm_node_${rng.nextInt(100)}',
        );
        final titleTs = HybridLogicalClock(
          physicalTime: rng.nextInt(1000000) + 1,
          logicalCounter: rng.nextInt(50),
          nodeId: 'dm_node_${rng.nextInt(100)}',
        );
        final descTs = HybridLogicalClock(
          physicalTime: rng.nextInt(1000000) + 1,
          logicalCounter: rng.nextInt(50),
          nodeId: 'dm_node_${rng.nextInt(100)}',
        );
        final notesTs = HybridLogicalClock(
          physicalTime: rng.nextInt(1000000) + 1,
          logicalCounter: rng.nextInt(50),
          nodeId: 'dm_node_${rng.nextInt(100)}',
        );

        final dmProfile = CampaignProfile.raw(
          id: placeholder.id,
          nameRegister: CrdtLwwRegister<String>(value: dmName, timestamp: nameTs),
          edition: placeholder.edition,
          createdAt: DateTime.utc(2025, 1, 1),
          lastPlayedAt: DateTime.utc(2025, 1, 1),
          roomState: RoomNodeState(
            roomId: 'room_$roomCode',
            roomCode: roomCode,
            title: dmTitle,
            titleTimestamp: titleTs,
            description: dmDesc,
            descriptionTimestamp: descTs,
          ),
          partyPurse: const PartyPurse.empty(),
          memberPurses: const {},
          partyRoster: const CrdtOrSet<String>.empty(),
          pinnedRules: const CrdtOrSet<String>.empty(),
          notesRegister: CrdtLwwRegister<String>(value: dmNotes, timestamp: notesTs),
          changeLog: const [],
        );

        // Order 1: local: placeholder, remote: dm
        final res1 = recon.reconcileProfileSafely(
          local: placeholder,
          remote: dmProfile,
        );

        // Order 2: local: dm, remote: placeholder
        final res2 = recon.reconcileProfileSafely(
          local: dmProfile,
          remote: placeholder,
        );

        expect(res1.fieldFaults, isEmpty, reason: '$pathName failed at seed $seed: res1 has field faults');
        expect(res2.fieldFaults, isEmpty, reason: '$pathName failed at seed $seed: res2 has field faults');

        expect(res1.profile.name, equals(dmName), reason: '$pathName failed at seed $seed: name mismatch in order 1');
        expect(res2.profile.name, equals(dmName), reason: '$pathName failed at seed $seed: name mismatch in order 2');

        expect(res1.profile.roomState.title, equals(dmTitle), reason: '$pathName failed at seed $seed: title mismatch in order 1');
        expect(res2.profile.roomState.title, equals(dmTitle), reason: '$pathName failed at seed $seed: title mismatch in order 2');

        expect(res1.profile.roomState.description, equals(dmDesc), reason: '$pathName failed at seed $seed: description mismatch in order 1');
        expect(res2.profile.roomState.description, equals(dmDesc), reason: '$pathName failed at seed $seed: description mismatch in order 2');

        expect(res1.profile.notesMarkdown, equals(dmNotes), reason: '$pathName failed at seed $seed: notes mismatch in order 1');
        expect(res2.profile.notesMarkdown, equals(dmNotes), reason: '$pathName failed at seed $seed: notes mismatch in order 2');

        expect(res1.profile, equals(res2.profile), reason: '$pathName failed at seed $seed: merge order asymmetry');
      } catch (e) {
        // Seed printed on failure as required
        fail('$pathName failed at seed $seed: $e');
      }
    }
  }

  void runPropagationCase({
    required CampaignProfile placeholder,
    required StatefulHlcClock joinerClock,
  }) {
    const dmNotesTs = HybridLogicalClock(
      physicalTime: 1000,
      logicalCounter: 0,
      nodeId: 'dm_device',
    );
    final dmProfile = CampaignProfile.raw(
      id: placeholder.id,
      nameRegister: const CrdtLwwRegister<String>(
        value: 'DM Name',
        timestamp: dmNotesTs,
      ),
      edition: placeholder.edition,
      createdAt: DateTime.utc(2025, 1, 1),
      lastPlayedAt: DateTime.utc(2025, 1, 1),
      roomState: RoomNodeState(
        roomId: 'room_${placeholder.roomState.roomCode}',
        roomCode: placeholder.roomState.roomCode,
        title: 'DM Title',
        titleTimestamp: dmNotesTs,
        description: 'DM Description',
        descriptionTimestamp: dmNotesTs,
      ),
      partyPurse: const PartyPurse.empty(),
      memberPurses: const {},
      partyRoster: const CrdtOrSet<String>.empty(),
      pinnedRules: const CrdtOrSet<String>.empty(),
      notesRegister: const CrdtLwwRegister<String>(
        value: 'DM Notes',
        timestamp: dmNotesTs,
      ),
      changeLog: const [],
    );

    // Initial merge
    final merged = recon.reconcileProfileSafely(
      local: placeholder,
      remote: dmProfile,
    );
    expect(merged.profile.notesMarkdown, equals('DM Notes'));

    // Joiner makes a real edit after observing the DM stamp
    joinerClock.observeRemote(dmNotesTs);
    final joinerEditTs = joinerClock.nextTimestamp();
    expect(joinerEditTs.physicalTime, greaterThanOrEqualTo(dmNotesTs.physicalTime));
    expect(joinerEditTs.compareTo(dmNotesTs), greaterThan(0));

    final joinerEdited = merged.profile.copyWith(
      notesRegister: CrdtLwwRegister<String>(
        value: 'Joiner updated notes',
        timestamp: joinerEditTs,
      ),
    );

    // Joiner edit wins on both sides
    final side1 = recon.reconcileProfileSafely(
      local: joinerEdited,
      remote: dmProfile,
    );
    final side2 = recon.reconcileProfileSafely(
      local: dmProfile,
      remote: joinerEdited,
    );

    expect(side1.fieldFaults, isEmpty);
    expect(side2.fieldFaults, isEmpty);
    expect(side1.profile.notesMarkdown, equals('Joiner updated notes'));
    expect(side2.profile.notesMarkdown, equals('Joiner updated notes'));
    expect(side1.profile, equals(side2.profile));
  }

  group('Cold Iron Birdcage — Pass 10: Production-Path Placeholder Laws', () {
    test('P1: openRoomProfile with lobby campaignId, rulesetId, and campaignName', () async {
      const code = 'JOIN1';
      recordingPort.roomDataByCode[code] = {
        'campaignName': 'Lobby Name',
        'rulesetId': 'dnd5e_2024',
        'campaignId': 'camp_p1_target',
      };

      final profile = await service.openRoomProfile(code);

      // Check registers before merge
      expect(profile.id, equals('camp_p1_target'));
      expect(profile.name, equals('Lobby Name'));
      expect(profile.roomState.roomCode, equals(code));
      expect(profile.roomState.title, equals('Campaign $code Staging'));
      expect(profile.roomState.description, equals(''));
      expect(profile.notesMarkdown, equals(''));

      expect(profile.nameRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.roomState.descriptionRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.notesRegister.timestamp, equals(HybridLogicalClock.genesis));

      // Law over 200+ seeds
      runReconciliationLaw(
        placeholder: profile,
        pathName: 'P1',
        lobbyOrMembershipName: 'Lobby Name',
      );

      // Propagation case
      runPropagationCase(
        placeholder: profile,
        joinerClock: clock,
      );
    });

    test('P2: openRoomProfile without lobby campaignId (legacy shape creates campaign_<CODE>)', () async {
      const code = 'JOIN2';
      recordingPort.roomDataByCode[code] = {
        'campaignName': 'Lobby Name Legacy',
        'rulesetId': 'dnd5e_2024',
      };

      final profile = await service.openRoomProfile(code);

      // Check registers before merge
      expect(profile.id, equals('campaign_$code'));
      expect(profile.name, equals('Lobby Name Legacy'));
      expect(profile.roomState.roomCode, equals(code));
      expect(profile.roomState.title, equals('Campaign $code Staging'));
      expect(profile.roomState.description, equals(''));
      expect(profile.notesMarkdown, equals(''));

      expect(profile.nameRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.roomState.descriptionRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(profile.notesRegister.timestamp, equals(HybridLogicalClock.genesis));

      // Law over 200+ seeds
      runReconciliationLaw(
        placeholder: profile,
        pathName: 'P2',
        lobbyOrMembershipName: 'Lobby Name Legacy',
      );

      // Propagation case
      runPropagationCase(
        placeholder: profile,
        joinerClock: clock,
      );
    });

    test('P3: adoptRegistryMemberships with non-host memberships (with and without name)', () async {
      final mNamed = CampaignMembership(
        roomCode: 'JOIN3A',
        campaignName: 'Membership Campaign Name',
        role: CampaignRole.player,
        lastPlayed: DateTime.now(),
      );
      final mUnnamed = CampaignMembership(
        roomCode: 'JOIN3B',
        campaignName: '',
        role: CampaignRole.player,
        lastPlayed: DateTime.now(),
      );

      final regService = CampaignRegistryService.newInstance();
      await regService.saveMembership(mNamed);
      await regService.saveMembership(mUnnamed);

      await CampaignStorageMigration.adoptRegistryMemberships(
        repo,
        clock: clock,
        nodeId: rep.value,
        registryService: regService,
      );

      final pNamed = await repo.getProfile('campaign_JOIN3A');
      final pUnnamed = await repo.getProfile('campaign_JOIN3B');

      expect(pNamed, isNotNull);
      expect(pUnnamed, isNotNull);

      // Verify pNamed before merge
      expect(pNamed!.name, equals('Membership Campaign Name'));
      expect(pNamed.roomState.title, equals('Membership Campaign Name Staging Area'));
      expect(pNamed.roomState.description, equals(''));
      expect(pNamed.notesMarkdown, equals(''));
      expect(pNamed.nameRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pNamed.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pNamed.roomState.descriptionRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pNamed.notesRegister.timestamp, equals(HybridLogicalClock.genesis));

      // Verify pUnnamed before merge
      expect(pUnnamed!.name, equals('Campaign JOIN3B'));
      expect(pUnnamed.roomState.title, equals('Campaign JOIN3B Staging'));
      expect(pUnnamed.roomState.description, equals(''));
      expect(pUnnamed.notesMarkdown, equals(''));
      expect(pUnnamed.nameRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pUnnamed.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pUnnamed.roomState.descriptionRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(pUnnamed.notesRegister.timestamp, equals(HybridLogicalClock.genesis));

      // Law over 200+ seeds for pNamed
      runReconciliationLaw(
        placeholder: pNamed,
        pathName: 'P3 Named',
        lobbyOrMembershipName: 'Membership Campaign Name',
      );

      // Law over 200+ seeds for pUnnamed
      runReconciliationLaw(
        placeholder: pUnnamed,
        pathName: 'P3 Unnamed',
        lobbyOrMembershipName: 'Campaign JOIN3B',
      );

      // Propagation cases
      runPropagationCase(
        placeholder: pNamed,
        joinerClock: clock,
      );
      runPropagationCase(
        placeholder: pUnnamed,
        joinerClock: clock,
      );
    });

    test('P4: createCampaign relinking placeholder preserves genesis title; control stamps real title', () async {
      const codeP1 = 'JOIN4P1';
      recordingPort.roomDataByCode[codeP1] = {
        'campaignName': 'Original Lobby Name',
        'rulesetId': 'dnd5e_2024',
        'campaignId': 'camp_p4_orig',
      };

      final placeholderP1 = await service.openRoomProfile(codeP1);
      expect(placeholderP1.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));

      // P4: createCampaign with linkProfileId of placeholder
      const newCode = 'JOIN4NEW';
      await service.createCampaign(
        campaignName: 'New Campaign',
        playerName: 'DM',
        customRoomCode: newCode,
        linkProfileId: 'camp_p4_orig',
      );

      final p4 = (await repo.getProfile('camp_p4_orig'))!;
      expect(p4.id, equals('camp_p4_orig'));
      expect(p4.roomState.roomCode, equals(newCode));
      expect(p4.roomState.title, equals('Campaign $newCode Staging'));
      expect(p4.name, equals('Original Lobby Name'));
      expect(p4.roomState.description, equals(''));
      expect(p4.notesMarkdown, equals(''));

      expect(p4.nameRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(p4.roomState.titleRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(p4.roomState.descriptionRegister.timestamp, equals(HybridLogicalClock.genesis));
      expect(p4.notesRegister.timestamp, equals(HybridLogicalClock.genesis));

      // Law over 200+ seeds
      runReconciliationLaw(
        placeholder: p4,
        pathName: 'P4',
        lobbyOrMembershipName: 'Original Lobby Name',
      );

      // Propagation case
      runPropagationCase(
        placeholder: p4,
        joinerClock: clock,
      );

      // Control for P4: relink a profile whose title was written at physical time 1000
      const authoredTitleTs = HybridLogicalClock(
        physicalTime: 1000,
        logicalCounter: 0,
        nodeId: 'dm_device',
      );
      final authoredProfile = p4.copyWith(
        roomState: p4.roomState.copyWith(
          title: 'Authored Staging Title',
          titleTimestamp: authoredTitleTs,
        ),
      );

      final relinkedControl = RoomCodeRelink.relink(
        authoredProfile,
        'JOIN4CTRL',
        clock,
        stampStagingTitle: true,
      );

      expect(relinkedControl.roomState.title, equals('Campaign JOIN4CTRL Staging'));
      expect(relinkedControl.roomState.titleRegister.timestamp.physicalTime, greaterThan(0));
      expect(relinkedControl.roomState.titleRegister.timestamp, isNot(equals(HybridLogicalClock.genesis)));
      expect(relinkedControl.roomState.titleRegister.timestamp.nodeId, equals('joiner_device'));
    });
  });
}
