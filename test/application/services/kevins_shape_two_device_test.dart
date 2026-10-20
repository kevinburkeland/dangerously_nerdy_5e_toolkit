import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/migration/party_ledger_legacy_import.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';

class _CountingRepo implements ICampaignRepository {
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (sl.isRegistered<ICampaignRepository>()) sl.unregister<ICampaignRepository>();
    if (sl.isRegistered<ReplicaId>()) sl.unregister<ReplicaId>();
    if (sl.isRegistered<StatefulHlcClock>()) sl.unregister<StatefulHlcClock>();
  });

  tearDown(() {
    if (sl.isRegistered<ICampaignRepository>()) sl.unregister<ICampaignRepository>();
    if (sl.isRegistered<ReplicaId>()) sl.unregister<ReplicaId>();
    if (sl.isRegistered<StatefulHlcClock>()) sl.unregister<StatefulHlcClock>();
  });

  group('Kevin\'s Shape Two-Device Test (Required Test 3)', () {
    test('Device A & Device B resolve, reconcile with zero faults, match balances, and third open writes nothing', () async {
      const roomCode = 'CR-KEV';
      const genesisTs = HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'genesis');

      // Legacy room document with ledger fields and no campaignId or rulesetId
      final legacyDoc = {
        'roomCode': roomCode,
        'code': roomCode,
        'campaignName': 'Dragon Heist',
        'partyPurse': {'gp': 200, 'sp': 50, 'cp': 10},
        'characterRoster': ['Thorin', 'Elrond'],
        'memberPurses': {
          'thorin': {'gp': 25},
        },
      };

      // -------------------------------------------------------------
      // Device A Setup:
      // - adopted campaign_CR-KEV profile (core default v2014, genesis title 'Dragon Heist Staging Area')
      // - clone claiming same room code
      // - room-less 'My Campaign' default
      // -------------------------------------------------------------
      final repoA = _CountingRepo();
      final repA = ReplicaId('dev-a');
      final clockA = StatefulHlcClock(replicaId: repA);

      final adoptedProfileA = CampaignProfile.raw(
        id: 'campaign_$roomCode',
        nameRegister: const CrdtLwwRegister(
          value: 'Dragon Heist',
          timestamp: HybridLogicalClock(physicalTime: 1700000000000, logicalCounter: 0, nodeId: 'dev-a'),
        ),
        edition: DmRulesEdition.v2014,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_$roomCode',
          roomCode: roomCode,
          title: 'Dragon Heist Staging Area',
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

      final cloneProfileA = CampaignProfile.raw(
        id: 'campaign_${roomCode}_clone',
        nameRegister: const CrdtLwwRegister(value: 'Dragon Heist Clone', timestamp: genesisTs),
        edition: DmRulesEdition.v2014,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_${roomCode}_clone',
          roomCode: roomCode,
          title: 'Dragon Heist Staging Area Clone',
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

      final defaultRoomlessA = CampaignProfile.raw(
        id: 'campaign_default',
        nameRegister: const CrdtLwwRegister(value: 'My Campaign', timestamp: genesisTs),
        edition: DmRulesEdition.v2014,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_default',
          roomCode: '',
          title: 'Default Staging',
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

      await repoA.putProfile(adoptedProfileA);
      await repoA.putProfile(cloneProfileA);
      await repoA.putProfile(defaultRoomlessA);
      repoA.updateProfileCalls = 0;

      // -------------------------------------------------------------
      // Device B Setup:
      // - campaign_CR-KEV as Pass 7 created it (genesis title 'Campaign CR-KEV Staging', same edition)
      // -------------------------------------------------------------
      final repoB = _CountingRepo();
      final repB = ReplicaId('dev-b');
      final clockB = StatefulHlcClock(replicaId: repB);

      final pass7ProfileB = CampaignProfile.raw(
        id: 'campaign_$roomCode',
        nameRegister: CrdtLwwRegister(value: 'Campaign $roomCode', timestamp: clockB.nextTimestamp()),
        edition: DmRulesEdition.v2014,
        createdAt: DateTime.utc(2025, 1, 1),
        lastPlayedAt: DateTime.utc(2025, 1, 1),
        roomState: RoomNodeState(
          roomId: 'room_$roomCode',
          roomCode: roomCode,
          title: 'Campaign $roomCode Staging',
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

      await repoB.putProfile(pass7ProfileB);
      repoB.updateProfileCalls = 0;

      // -------------------------------------------------------------
      // 1. Both open the room through openRoomProfile and run legacy import
      // -------------------------------------------------------------
      // Device A open:
      sl.registerSingleton<ReplicaId>(repA);
      sl.registerSingleton<ICampaignRepository>(repoA);
      sl.registerSingleton<StatefulHlcClock>(clockA);

      final serviceA = PartyRoomService(replicaId: repA, clock: clockA);
      var resolvedA = await serviceA.openRoomProfile(roomCode);
      expect(resolvedA.id, equals('campaign_$roomCode'), reason: 'Device A resolves adopted campaign_<ROOMCODE>');

      // Run legacy import on Device A
      if (PartyLedgerLegacyImport.hasLegacyLedgerFields(legacyDoc)) {
        resolvedA = await repoA.updateProfile(resolvedA.id, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: legacyDoc,
            clock: clockA,
          );
        });
      }

      // Switch DI to Device B
      sl.unregister<ReplicaId>();
      sl.unregister<ICampaignRepository>();
      sl.unregister<StatefulHlcClock>();
      sl.registerSingleton<ReplicaId>(repB);
      sl.registerSingleton<ICampaignRepository>(repoB);
      sl.registerSingleton<StatefulHlcClock>(clockB);

      final serviceB = PartyRoomService(replicaId: repB, clock: clockB);
      var resolvedB = await serviceB.openRoomProfile(roomCode);
      expect(resolvedB.id, equals('campaign_$roomCode'), reason: 'Device B resolves campaign_<ROOMCODE>');

      // Run legacy import on Device B (or simulate sync)
      if (PartyLedgerLegacyImport.hasLegacyLedgerFields(legacyDoc)) {
        resolvedB = await repoB.updateProfile(resolvedB.id, (p) {
          return PartyLedgerLegacyImport.importLegacyLedger(
            profile: p,
            rawDoc: legacyDoc,
            clock: clockB,
          );
        });
      }

      // -------------------------------------------------------------
      // 2. Full-sync both ways twice through RoomStateReconciliationService
      // -------------------------------------------------------------
      final reconciler = RoomStateReconciliationService();

      // Pass 1: A -> B, then B -> A
      final sync1B = reconciler.reconcileProfileSafely(local: resolvedB, remote: resolvedA);
      expect(sync1B.fieldFaults, isEmpty, reason: 'Sync 1B faults must be empty: ${sync1B.fieldFaults}');
      await repoB.putProfile(sync1B.profile);

      final sync1A = reconciler.reconcileProfileSafely(local: resolvedA, remote: sync1B.profile);
      expect(sync1A.fieldFaults, isEmpty, reason: 'Sync 1A faults must be empty: ${sync1A.fieldFaults}');
      await repoA.putProfile(sync1A.profile);

      // Pass 2: A -> B, then B -> A
      final sync2B = reconciler.reconcileProfileSafely(local: sync1B.profile, remote: sync1A.profile);
      expect(sync2B.fieldFaults, isEmpty, reason: 'Sync 2B faults must be empty: ${sync2B.fieldFaults}');
      await repoB.putProfile(sync2B.profile);

      final sync2A = reconciler.reconcileProfileSafely(local: sync1A.profile, remote: sync2B.profile);
      expect(sync2A.fieldFaults, isEmpty, reason: 'Sync 2A faults must be empty: ${sync2A.fieldFaults}');
      await repoA.putProfile(sync2A.profile);

      // Asserts:
      // Both resolve campaign_<ROOMCODE>
      expect(sync2A.profile.id, equals('campaign_$roomCode'));
      expect(sync2B.profile.id, equals('campaign_$roomCode'));

      // Zero reconcile faults
      expect(sync2A.fieldFaults, isEmpty);
      expect(sync2B.fieldFaults, isEmpty);

      // Equal titles
      expect(sync2A.profile.roomState.title, equals(sync2B.profile.roomState.title));

      // Every imported balance counted once
      expect(sync2A.profile.partyPurse.getBalance('gp'), equals(200));
      expect(sync2A.profile.partyPurse.getBalance('sp'), equals(50));
      expect(sync2A.profile.partyPurse.getBalance('cp'), equals(10));
      expect(sync2B.profile.partyPurse.getBalance('gp'), equals(200));
      expect(sync2B.profile.partyPurse.getBalance('sp'), equals(50));
      expect(sync2B.profile.partyPurse.getBalance('cp'), equals(10));

      final memberPurseThorinA = sync2A.profile.memberPurses['legacy-name:thorin'];
      expect(memberPurseThorinA, isNotNull);
      expect(memberPurseThorinA!.getBalance('gp'), equals(25));

      final memberPurseThorinB = sync2B.profile.memberPurses['legacy-name:thorin'];
      expect(memberPurseThorinB, isNotNull);
      expect(memberPurseThorinB!.getBalance('gp'), equals(25));

      // -------------------------------------------------------------
      // 3. A third openRoomProfile on each device writes nothing
      // -------------------------------------------------------------
      // Device A:
      sl.unregister<ReplicaId>();
      sl.unregister<ICampaignRepository>();
      sl.unregister<StatefulHlcClock>();
      sl.registerSingleton<ReplicaId>(repA);
      sl.registerSingleton<ICampaignRepository>(repoA);
      sl.registerSingleton<StatefulHlcClock>(clockA);

      repoA.updateProfileCalls = 0;
      final thirdOpenA = await serviceA.openRoomProfile(roomCode);
      expect(thirdOpenA.id, equals('campaign_$roomCode'));
      expect(repoA.updateProfileCalls, equals(0), reason: 'Third openRoomProfile on Device A must write nothing (0 updateProfile calls)');

      // Device B:
      sl.unregister<ReplicaId>();
      sl.unregister<ICampaignRepository>();
      sl.unregister<StatefulHlcClock>();
      sl.registerSingleton<ReplicaId>(repB);
      sl.registerSingleton<ICampaignRepository>(repoB);
      sl.registerSingleton<StatefulHlcClock>(clockB);

      repoB.updateProfileCalls = 0;
      final thirdOpenB = await serviceB.openRoomProfile(roomCode);
      expect(thirdOpenB.id, equals('campaign_$roomCode'));
      expect(repoB.updateProfileCalls, equals(0), reason: 'Third openRoomProfile on Device B must write nothing (0 updateProfile calls)');
    });
  });
}
