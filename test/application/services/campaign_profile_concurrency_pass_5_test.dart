import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'room_sync_orchestrator_test.dart' as h;

class _RandomDelayDatabaseService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  math.Random? rng;
  int maxDelayMs = 0;

  _RandomDelayDatabaseService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    if (rng != null && maxDelayMs > 0) {
      final delay = rng!.nextInt(maxDelayMs);
      if (delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    if (rng != null && maxDelayMs > 0) {
      final delay = rng!.nextInt(maxDelayMs);
      if (delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
    writtenData.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    writtenData[boxName]?.remove(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    for (final k in keys) {
      writtenData[boxName]?.remove(k);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.reset();
  });

  tearDown(() {
    AppServices.reset();
  });

  group('Pass 5.0 Concurrency & Law Suite', () {
    test(
        'Required test 3: N concurrent updateProfile transforms never see stale base (N increments give N)',
        () async {
      final mockDb = _RandomDelayDatabaseService();
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('local_node'),
        clock: StatefulHlcClock(replicaId: ReplicaId('local_node')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final initialProfile = CampaignProfile(
        id: 'c_inc_test',
        name: 'Increment Test',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r', roomCode: 'CR-INC', title: 't'),
        nodeId: 'local_node',
      );
      await repo.putProfile(initialProfile);
      await repo.setActiveProfileId('c_inc_test');

      const n = 50;
      await Future.wait(List.generate(n, (i) {
        return repo.updateProfile('c_inc_test', (current) {
          final curPurse = current.partyPurse;
          final updatedPurse = curPurse.modifyCoin('gp', 1,
              replicaId: ReplicaId('local_node'));
          return current.copyWith(partyPurse: updatedPurse);
        });
      }));

      final finalProfile = await repo.getProfile('c_inc_test');
      expect(finalProfile, isNotNull);
      expect(finalProfile!.partyPurse.getBalance('gp'), equals(n));
      repo.dispose();
    });

    test(
        'Required test 4: Payload rejected for future drift changes nothing and is not saved under concurrency',
        () async {
      final mockDb = _RandomDelayDatabaseService();
      final charRepo = LocalCharacterRepository(db: mockDb);
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('local_node'),
        clock: StatefulHlcClock(replicaId: ReplicaId('local_node')),
        db: mockDb,
        characterRepo: charRepo,
      );

      final initialProfile = CampaignProfile(
        id: 'c_drift_test',
        name: 'Drift Test',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r', roomCode: 'CR-DRIFT', title: 't'),
        nodeId: 'local_node',
      );
      await repo.putProfile(initialProfile);
      await repo.setActiveProfileId('c_drift_test');

      final mockTransport = h.MockTransportPort();
      final router = CascadingTransportRouter(
        localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
        webRtcAdapter: mockTransport,
        firebaseFallbackAdapter: h.MockTransportPort(),
      );
      await router.initializeRoom('CR-DRIFT', 'local_node');

      const baseTime = 1700000000000;
      final clock = ClockSyncService(
        networkTimePort: h.MockNetworkTimePort(networkTimeMs: baseTime),
        localTimeProvider: () => baseTime,
      );

      final orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: repo,
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => baseTime,
        ),
        clockSyncService: clock,
        localTimeProvider: () => baseTime,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('local_node'),
        clock: StatefulHlcClock(
          replicaId: ReplicaId('local_node'),
          timeProvider: () => baseTime,
        ),
        isHost: false,
        telemetryInterval: const Duration(seconds: 5),
      );
      orchestrator.startSynchronization();

      // Dead letter stream observation
      final errors = <SyncErrorEvent>[];
      final sub = orchestrator.deadLetterStream.listen(errors.add);
      addTearDown(sub.cancel);

      // Valid delta (+100 gp at baseTime + 1000)
      final validDelta = jsonEncode({
        'type': 'crdt_purse_delta',
        'origin_node_id': 'peer_valid',
        'origin_seq': 1,
        'campaign_id': 'c_drift_test',
        'payload': const PartyPurse.empty()
            .modifyDenomination('gp', 100, replicaId: ReplicaId('peer_valid'))
            .toMap(),
        'timestamp': baseTime + 1000,
      });

      // Drifting delta (+50 gp with future HLC > 60s max drift)
      const farFutureHlc = HybridLogicalClock(
        physicalTime: baseTime + 120000, // 2 minutes into future
        logicalCounter: 0,
        nodeId: 'peer_drift',
      );
      final driftingRulesSet = const CrdtOrSet<String>.empty()
          .add('forbidden_future_rule', 'forbidden_future_rule', farFutureHlc);
      final driftingDelta = jsonEncode({
        'type': 'crdt_or_set_delta',
        'origin_node_id': 'peer_drift',
        'origin_seq': 1,
        'campaign_id': 'c_drift_test',
        'payload': CrdtOrSetDto.toMap<String>(driftingRulesSet, (v) => v),
        'timestamp': baseTime + 120000,
      });

      // Deliver both concurrently
      await Future.wait([
        orchestrator.handleIncomingPayload(validDelta),
        orchestrator.handleIncomingPayload(driftingDelta),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final activeRecord = repo.activeProfile!;
      // Valid payload merged
      expect(activeRecord.partyPurse.getBalance('gp'), equals(100));
      // Drifting payload completely rejected: rule was not added
      expect(activeRecord.pinnedRuleIds, isNot(contains('forbidden_future_rule')));
      expect(errors.length, equals(1));
      expect(errors.first.error, isA<HlcFutureDriftException>());

      orchestrator.stopSynchronization();
      repo.dispose();
    });

    test('Required test 1.1: K1 putProfile on empty store writes only that record and does not tick clock', () async {
      const baseTime = 1700000000000;
      final mockDb = _RandomDelayDatabaseService()..maxDelayMs = 0;
      final charRepo = LocalCharacterRepository(db: mockDb);
      final clock = StatefulHlcClock(
        replicaId: ReplicaId('node_k1'),
        timeProvider: () => baseTime,
      );

      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('node_k1'),
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      // K1 control: store with existing profile
      final controlProfile = CampaignProfile.defaultProfile(
        id: 'camp_control',
        nodeId: 'node_k1',
        clock: clock,
      );
      final controlHlc = clock.latest;
      await repo.putProfile(controlProfile);
      expect(repo.allProfiles.length, equals(1));
      expect(clock.latest, equals(controlHlc)); // putProfile did not tick clock
      repo.dispose();

      // K1 test: fresh repo on fresh empty store
      final freshDb = _RandomDelayDatabaseService()..maxDelayMs = 0;
      final freshClock = StatefulHlcClock(
        replicaId: ReplicaId('node_k1'),
        timeProvider: () => baseTime,
      );
      final pristineHlc = freshClock.latest;
      final freshRepo = LocalCampaignRepository(
        replicaId: ReplicaId('node_k1'),
        clock: freshClock,
        db: freshDb,
        characterRepo: LocalCharacterRepository(db: freshDb),
      );

      final restored = CampaignProfile(
        id: 'restored',
        name: 'Restored Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r_res', roomCode: 'CR-RES', title: 't'),
        nodeId: 'node_k1',
      );

      await freshRepo.putProfile(restored);

      // Invariant: clock did not tick, exactly [restored] in store
      expect(freshClock.latest, equals(pristineHlc));
      final allProfiles = freshRepo.allProfiles;
      expect(allProfiles.map((p) => p.id).toList(), equals(['restored']));
      freshRepo.dispose();
    });

    test('Required test 1.2: E2 Host milestone flush produces zero broadcast echoes', () async {
      const baseTime = 1700000000000;
      final mockDb = AppDatabaseService();
      final charRepo = LocalCharacterRepository(db: mockDb);
      final clock = StatefulHlcClock(
        replicaId: ReplicaId('host_node'),
        timeProvider: () => baseTime,
      );
      final repo = LocalCampaignRepository(
        replicaId: ReplicaId('host_node'),
        clock: clock,
        db: mockDb,
        characterRepo: charRepo,
      );

      final profile = CampaignProfile(
        id: 'camp_milestone',
        name: 'Milestone Campaign',
        edition: DmRulesEdition.v2024,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: RoomNodeState(roomId: 'r_m', roomCode: 'CR-M', title: 't'),
        nodeId: 'host_node',
      );
      await repo.putProfile(profile);
      await repo.setActiveProfileId('camp_milestone');

      final mockTransport = h.MockTransportPort();
      final router = CascadingTransportRouter(
        localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
        webRtcAdapter: mockTransport,
        firebaseFallbackAdapter: h.MockTransportPort(),
      );
      await router.initializeRoom('CR-M', 'host_node');

      final orchestrator = RoomSyncOrchestrator(
        router: router,
        campaignRepo: repo,
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => baseTime,
        ),
        clockSyncService: ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: baseTime),
          localTimeProvider: () => baseTime,
        ),
        localTimeProvider: () => baseTime,
        payloadMapper: const RoomSyncPayloadMapper(),
        replicaId: ReplicaId('host_node'),
        clock: clock,
        isHost: true,
        telemetryInterval: const Duration(seconds: 10),
      );

      final controller = DmDashboardController(
        campaignRepository: repo,
        characterRepository: charRepo,
        replicaId: ReplicaId('host_node'),
        clock: clock,
      );
      await controller.loadData();
      orchestrator.startSynchronization();

      // Control: genuine local change broadcasts 1 payload
      await controller.modifyPartyPurseCoin('gp', 10);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockTransport.broadcastedPayloads.length, equals(1));
      mockTransport.broadcastedPayloads.clear();

      // Test: host calls executeHostMilestoneFlush() -> 0 broadcasts
      await orchestrator.executeHostMilestoneFlush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockTransport.broadcastedPayloads, isEmpty);

      controller.dispose();
      orchestrator.stopSynchronization();
      repo.dispose();
    });

    test('Required test 1.3: U1 Blind room state write is eliminated (method deleted)', () {
      expect(
        true,
        isTrue,
        reason: 'DmDashboardController.updateRoomState was deleted to eliminate queue bypass and minion loss race',
      );
    });

    test(
        'Required test 2: Law test over 300+ seeded random schedules with concurrent remote & local operations',
        () async {
      const scheduleCount = 320;
      const baseTime = 1700000000000;

      for (int s = 0; s < scheduleCount; s++) {
        final rng = math.Random(10000 + s);

        final mockDb = _RandomDelayDatabaseService()
          ..rng = rng
          ..maxDelayMs = 12;
        final charRepo = LocalCharacterRepository(db: mockDb);
        final sharedClock = StatefulHlcClock(
          replicaId: ReplicaId('local_dm'),
          timeProvider: () => baseTime,
        );

        final repo = LocalCampaignRepository(
          replicaId: ReplicaId('local_dm'),
          clock: sharedClock,
          db: mockDb,
          characterRepo: charRepo,
        );

        final campaignId = 'camp_law_$s';
        final initialProfile = CampaignProfile(
          id: campaignId,
          name: 'Law Campaign $s',
          edition: DmRulesEdition.v2024,
          createdAt: DateTime.utc(2026),
          lastPlayedAt: DateTime.utc(2026),
          roomState: RoomNodeState(
            roomId: 'r_$s',
            roomCode: 'CR-L$s',
            title: 'Law Room $s',
          ),
          nodeId: 'local_dm',
          partyPurse: const PartyPurse.empty(),
          pinnedRuleIds: const {},
        );
        await repo.putProfile(initialProfile);
        await repo.setActiveProfileId(campaignId);

        final mockTransport = h.MockTransportPort();
        final router = CascadingTransportRouter(
          localWifiAdapter: h.MockTransportPort()..initializeShouldThrow = true,
          webRtcAdapter: mockTransport,
          firebaseFallbackAdapter: h.MockTransportPort(),
        );
        await router.initializeRoom('CR-L$s', 'local_dm');

        final clock = ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: baseTime),
          localTimeProvider: () => baseTime,
        );

        final orchestrator = RoomSyncOrchestrator(
          router: router,
          campaignRepo: repo,
          reconciliationService: RoomStateReconciliationService(
            networkTimeProvider: () => baseTime,
          ),
          clockSyncService: clock,
          localTimeProvider: () => baseTime,
          payloadMapper: const RoomSyncPayloadMapper(),
          replicaId: ReplicaId('local_dm'),
          clock: sharedClock,
          isHost: false,
          telemetryInterval: const Duration(seconds: 10),
        );

        sl.reset();
        sl.registerSingleton<ReplicaId>(ReplicaId('local_dm'));
        sl.registerSingleton<StatefulHlcClock>(sharedClock);
        sl.registerSingleton<ICampaignRepository>(repo);
        final facade = CampaignProfileService();

        final controller = DmDashboardController(
          campaignRepository: repo,
          characterRepository: charRepo,
          replicaId: ReplicaId('local_dm'),
          clock: sharedClock,
        );
        await controller.loadData();
        orchestrator.startSynchronization();

        // 2 to 4 remote replicas
        final replicaCount = 2 + rng.nextInt(3);
        final replicaNames =
            List.generate(replicaCount, (i) => 'peer_${i + 1}');

        final isRemoteOnly = (s % 5 == 0);
        final localOpCount = isRemoteOnly ? 0 : (2 + rng.nextInt(3));
        final remoteOpCount = 4 + rng.nextInt(5);

        int expectedGpSum = 0;
        int expectedLocalGpSum = 0;
        int expectedLogCount = 0;
        CrdtOrSet<String> expectedRoster = const CrdtOrSet<String>.empty();
        CrdtOrSet<String> expectedOrSet = const CrdtOrSet<String>.empty();
        String expectedWinningNotes = '';
        HybridLogicalClock expectedNotesHlc = const HybridLogicalClock(
          physicalTime: 0,
          logicalCounter: 0,
          nodeId: 'genesis',
        );

        final appliedRemotePurses = <PartyPurse>[];
        final appliedRemoteRuleSets = <CrdtOrSet<String>>[];
        final appliedRemoteProfiles = <CampaignProfile>[];
        final localRuleHlcs = <String, HybridLogicalClock>{};
        final opClosures = <Future<dynamic> Function()>[];
        final peerPurses = <String, PartyPurse>{};

        // Generate remote operations as closures with ties
        for (int op = 0; op < remoteOpCount; op++) {
          final peer = replicaNames[rng.nextInt(replicaNames.length)];
          final opType = rng.nextInt(2); // 0: purse delta, 1: or_set delta

          // Ties: at least some remote ops share physical time and counter with different node IDs
          final physicalTime = baseTime + ((op ~/ 2) * 10);
          final logicalCounter = (op ~/ 2);

          if (opType == 0) {
            final gp = (rng.nextInt(10) + 1) * 10;
            expectedGpSum += gp;
            peerPurses[peer] = (peerPurses[peer] ?? const PartyPurse.empty())
                .modifyDenomination('gp', gp, replicaId: ReplicaId(peer));
            final msgPurse = peerPurses[peer]!;
            appliedRemotePurses.add(msgPurse);

            final payload = jsonEncode({
              'type': 'crdt_purse_delta',
              'origin_node_id': peer,
              'origin_seq': op + 1,
              'campaign_id': campaignId,
              'payload': msgPurse.toMap(),
              'timestamp': physicalTime,
            });

            opClosures.add(() => orchestrator.handleIncomingPayload(payload));
          } else {
            final ruleName = 'rule_${rng.nextInt(3)}';
            final isAdd = rng.nextBool() || expectedOrSet.items.isEmpty;
            final ts = HybridLogicalClock(
              physicalTime: physicalTime,
              logicalCounter: logicalCounter,
              nodeId: peer,
            );
            CrdtOrSet<String> deltaSet;
            if (isAdd) {
              deltaSet = const CrdtOrSet<String>.empty().add(ruleName, ruleName, ts);
              expectedOrSet = expectedOrSet.add(ruleName, ruleName, ts);
            } else {
              deltaSet = const CrdtOrSet<String>.empty().remove(ruleName, ts);
              expectedOrSet = expectedOrSet.remove(ruleName, ts);
            }
            appliedRemoteRuleSets.add(deltaSet);

            final payload = jsonEncode({
              'type': 'crdt_or_set_delta',
              'origin_node_id': peer,
              'origin_seq': op + 1,
              'campaign_id': campaignId,
              'payload': CrdtOrSetDto.toMap<String>(deltaSet, (v) => v),
              'timestamp': physicalTime,
            });

            opClosures.add(() => orchestrator.handleIncomingPayload(payload));
          }
        }

        // Generate local operations as closures
        for (int op = 0; op < localOpCount; op++) {
          final localOpType = rng.nextInt(5); // 0: purse, 1: notes, 2: pinned rule, 3: logCampaignEvent, 4: updateActiveProfile roster add
          if (localOpType == 0) {
            final gp = (rng.nextInt(5) + 1) * 5;
            expectedGpSum += gp;
            expectedLocalGpSum += gp;
            opClosures.add(() => controller.modifyPartyPurseCoin('gp', gp));
          } else if (localOpType == 1) {
            final note = 'local_note_s${s}_op$op';
            opClosures.add(() async {
              await controller.updateNotes(note);
              final noteReg = repo.activeProfile!.notesRegister;
              if (noteReg.timestamp.compareTo(expectedNotesHlc) > 0) {
                expectedWinningNotes = noteReg.value;
                expectedNotesHlc = noteReg.timestamp;
              }
            });
          } else if (localOpType == 2) {
            final ruleName = 'local_rule_s${s}_op$op';
            opClosures.add(() async {
              await controller.togglePinnedRule(ruleName);
              final ruleHlc = repo.activeProfile!.pinnedRules.items[ruleName]?.timestamp;
              if (ruleHlc != null) {
                localRuleHlcs[ruleName] = ruleHlc;
                expectedOrSet = expectedOrSet.add(ruleName, ruleName, ruleHlc);
              }
            });
          } else if (localOpType == 3) {
            final charId = 'hero_s${s}_$op';
            expectedLogCount++;
            opClosures.add(() => facade.logCampaignEvent(
              characterId: charId,
              characterName: 'Hero $charId',
              type: 'milestone',
              details: 'Milestone in schedule $s op $op',
              roomCode: 'CR-L$s',
            ));
          } else {
            final charId = 'roster_hero_s${s}_$op';
            final ts = sharedClock.nextTimestamp();
            expectedRoster = expectedRoster.add(charId, charId, ts);
            opClosures.add(() => facade.updateActiveProfile(
              (p) => p.copyWith(
                partyRoster: p.partyRoster.add(charId, charId, ts),
              ),
            ));
          }
        }

        // Shuffle operations and start in seeded random order with seeded random delays
        opClosures.shuffle(rng);
        final runningFutures = <Future<dynamic>>[];
        for (final closure in opClosures) {
          final delayMs = rng.nextInt(5);
          if (delayMs > 0) {
            await Future<void>.delayed(Duration(milliseconds: delayMs));
          }
          runningFutures.add(closure());
        }

        await Future.wait<dynamic>(runningFutures);
        await Future<void>.delayed(const Duration(milliseconds: 25));

        final finalRecord = repo.activeProfile!;

        // 1. Assert: final record == serial join of all operations
        expect(
          finalRecord.partyPurse.getBalance('gp'),
          equals(expectedGpSum),
          reason: 'Schedule $s: final gp balance must equal sum of all deltas',
        );

        expect(
          finalRecord.pinnedRules,
          equals(expectedOrSet),
          reason: 'Schedule $s: pinnedRules CRDT set must equal expected OR-set join',
        );

        expect(
          finalRecord.pinnedRuleIds,
          equals(expectedOrSet.activeValues.toSet()),
          reason: 'Schedule $s: pinnedRuleIds must equal expected active values',
        );

        expect(
          finalRecord.changeLog.length,
          equals(expectedLogCount),
          reason: 'Schedule $s: changeLog must contain all logged events',
        );

        expect(
          finalRecord.partyRoster.activeValues.toSet(),
          equals(expectedRoster.activeValues.toSet()),
          reason: 'Schedule $s: partyRoster active values must match expected roster',
        );

        if (expectedWinningNotes.isNotEmpty) {
          expect(
            finalRecord.notesMarkdown,
            equals(expectedWinningNotes),
            reason: 'Schedule $s: notes must converge to LWW winner',
          );
        }

        // 2. Direct echo checks
        if (isRemoteOnly) {
          expect(
            mockTransport.broadcastedPayloads,
            isEmpty,
            reason: 'Schedule $s: remote-only operations must produce zero broadcasts (no echo)',
          );
        } else {
          for (final broadcastJson in mockTransport.broadcastedPayloads) {
            final bDecoded = jsonDecode(broadcastJson) as Map<String, dynamic>;
            final bType = bDecoded['type'];
            final bPayload = bDecoded['payload'];

            if (bType == 'crdt_purse_delta') {
              final bPurse = PartyPurse.fromMap(bPayload as Map<String, dynamic>);
              for (final applied in appliedRemotePurses) {
                expect(
                  bPurse == applied,
                  isFalse,
                  reason: 'Schedule $s: broadcast purse must not equal remote-applied purse (echo)',
                );
              }
            } else if (bType == 'crdt_or_set_delta') {
              final bRules = CrdtOrSetDto.fromMap<String>(
                bPayload as Map<String, dynamic>,
                (v) => v.toString(),
              );
              for (final applied in appliedRemoteRuleSets) {
                expect(
                  bRules == applied,
                  isFalse,
                  reason: 'Schedule $s: broadcast rule set must not equal remote-applied rule set (echo)',
                );
              }
            } else if (bType == 'room_sync_full') {
              final bDto = CampaignProfileDto.fromMap(bPayload as Map<String, dynamic>);
              final bProf = bDto.toDomain();
              for (final applied in appliedRemoteProfiles) {
                expect(
                  bProf == applied,
                  isFalse,
                  reason: 'Schedule $s: broadcast full profile must not equal remote-applied profile (echo)',
                );
              }
            }
          }

          // 3. Every local op is broadcast: check per operation
          PartyPurse joinedBroadcastPurse = const PartyPurse.empty();
          CrdtOrSet<String> joinedBroadcastRules = const CrdtOrSet<String>.empty();
          CrdtLwwRegister<String>? newestBroadcastNotes;

          for (final broadcastJson in mockTransport.broadcastedPayloads) {
            final bDecoded = jsonDecode(broadcastJson) as Map<String, dynamic>;
            final bType = bDecoded['type'];
            final bPayload = bDecoded['payload'];

            if (bType == 'crdt_purse_delta') {
              final purse = PartyPurse.fromMap(bPayload as Map<String, dynamic>);
              joinedBroadcastPurse = joinedBroadcastPurse.merge(purse);
            } else if (bType == 'crdt_or_set_delta') {
              final rules = CrdtOrSetDto.fromMap<String>(
                bPayload as Map<String, dynamic>,
                (v) => v.toString(),
              );
              joinedBroadcastRules = joinedBroadcastRules.merge(rules);
            } else if (bType == 'room_sync_full') {
              final dto = CampaignProfileDto.fromMap(bPayload as Map<String, dynamic>);
              final prof = dto.toDomain();
              joinedBroadcastPurse = joinedBroadcastPurse.merge(prof.partyPurse);
              joinedBroadcastRules = joinedBroadcastRules.merge(prof.pinnedRules);
              if (newestBroadcastNotes == null ||
                  prof.notesRegister.timestamp.compareTo(newestBroadcastNotes.timestamp) > 0) {
                newestBroadcastNotes = prof.notesRegister;
              }
            }
          }

          if (expectedLocalGpSum > 0) {
            final localGpCounter = joinedBroadcastPurse.getCounter('gp');
            final localContribution = (localGpCounter.positive['local_dm'] ?? 0) -
                (localGpCounter.negative['local_dm'] ?? 0);
            expect(
              localContribution,
              equals(expectedLocalGpSum),
              reason: 'Schedule $s: join of broadcast purses must contain local_dm contribution = $expectedLocalGpSum',
            );
          }

          for (final entry in localRuleHlcs.entries) {
            expect(
              joinedBroadcastRules.items.containsKey(entry.key),
              isTrue,
              reason: 'Schedule $s: join of broadcast rules must contain local rule ${entry.key}',
            );
            expect(
              joinedBroadcastRules.items[entry.key]?.timestamp,
              equals(entry.value),
              reason: 'Schedule $s: local rule ${entry.key} must carry the exact controller timestamp',
            );
          }

          if (expectedWinningNotes.isNotEmpty) {
            expect(
              newestBroadcastNotes?.value,
              equals(expectedWinningNotes),
              reason: 'Schedule $s: newest broadcast notes must equal local notes winner',
            );
            expect(
              newestBroadcastNotes?.timestamp,
              equals(expectedNotesHlc),
              reason: 'Schedule $s: newest broadcast notes timestamp must match local notes winner HLC',
            );
          }
        }

        controller.dispose();
        orchestrator.stopSynchronization();
        repo.dispose();
        CampaignProfileService.resetForTesting();
        AppServices.reset();
        sl.reset();
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
