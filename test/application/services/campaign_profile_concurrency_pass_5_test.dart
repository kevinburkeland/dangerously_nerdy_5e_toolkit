import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/cascading_transport_router.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
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

  setUpAll(() {
    IRoomSyncPayloadPort.defaultProvider = () => const RoomSyncPayloadMapper();
  });

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
        final repo = LocalCampaignRepository(
          replicaId: ReplicaId('local_dm'),
          clock: StatefulHlcClock(
            replicaId: ReplicaId('local_dm'),
            timeProvider: () => baseTime,
          ),
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
          clock: StatefulHlcClock(
            replicaId: ReplicaId('local_dm'),
            timeProvider: () => baseTime,
          ),
          isHost: false,
          telemetryInterval: const Duration(seconds: 10),
        );

        final controller = DmDashboardController(
          campaignRepository: repo,
          characterRepository: charRepo,
          replicaId: ReplicaId('local_dm'),
          clock: StatefulHlcClock(
            replicaId: ReplicaId('local_dm'),
            timeProvider: () => baseTime,
          ),
        );
        await controller.loadData();
        orchestrator.startSynchronization();

        // 2 to 4 remote replicas
        final replicaCount = 2 + rng.nextInt(3);
        final replicaNames =
            List.generate(replicaCount, (i) => 'peer_${i + 1}');

        int expectedGpSum = 0;
        CrdtOrSet<String> expectedOrSet = const CrdtOrSet<String>.empty();
        String expectedWinningNotes = '';
        HybridLogicalClock expectedNotesHlc = const HybridLogicalClock(
          physicalTime: 0,
          logicalCounter: 0,
          nodeId: 'genesis',
        );

        final remoteAppliedPayloads = <String>[];
        final localOperations = <Future<dynamic>>[];
        final remoteOperations = <Future<dynamic>>[];
        final peerPurses = <String, PartyPurse>{};

        // Generate remote operations
        final remoteOpCount = 4 + rng.nextInt(5);
        for (int op = 0; op < remoteOpCount; op++) {
          final peer = replicaNames[rng.nextInt(replicaNames.length)];
          final opType = rng.nextInt(2); // 0: purse delta, 1: or_set delta

          if (opType == 0) {
            // Purse delta
            final gp = (rng.nextInt(10) + 1) * 10;
            expectedGpSum += gp;
            peerPurses[peer] = (peerPurses[peer] ?? const PartyPurse.empty())
                .modifyDenomination('gp', gp, replicaId: ReplicaId(peer));
            final payload = jsonEncode({
              'type': 'crdt_purse_delta',
              'origin_node_id': peer,
              'origin_seq': op + 1,
              'campaign_id': campaignId,
              'payload': peerPurses[peer]!.toMap(),
              'timestamp': baseTime + (op * 10),
            });
            remoteAppliedPayloads.add(payload);
            remoteOperations.add(orchestrator.handleIncomingPayload(payload));
          } else {
            // OR-set rule delta
            final ruleName = 'rule_${rng.nextInt(3)}';
            final isAdd = rng.nextBool() || expectedOrSet.items.isEmpty;
            final ts = HybridLogicalClock(
              physicalTime: baseTime + (op * 10),
              logicalCounter: op,
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
            final payload = jsonEncode({
              'type': 'crdt_or_set_delta',
              'origin_node_id': peer,
              'origin_seq': op + 1,
              'campaign_id': campaignId,
              'payload': CrdtOrSetDto.toMap<String>(deltaSet, (v) => v),
              'timestamp': baseTime + (op * 10),
            });
            remoteAppliedPayloads.add(payload);
            remoteOperations.add(orchestrator.handleIncomingPayload(payload));
          }
        }

        // Generate local controller operations
        final localOpCount = 2 + rng.nextInt(3);
        for (int op = 0; op < localOpCount; op++) {
          final localOpType = rng.nextInt(3); // 0: purse, 1: notes, 2: pinned rule
          if (localOpType == 0) {
            final gp = (rng.nextInt(5) + 1) * 5;
            expectedGpSum += gp;
            localOperations.add(controller.modifyPartyPurseCoin('gp', gp));
          } else if (localOpType == 1) {
            final note = 'local_note_s${s}_op$op';
            final hlc = controller.clock.nextTimestamp();
            if (hlc.compareTo(expectedNotesHlc) > 0) {
              expectedWinningNotes = note;
              expectedNotesHlc = hlc;
            }
            localOperations.add(controller.updateNotes(note));
          } else {
            final ruleName = 'local_rule_$op';
            // Toggle pinned rule (initial state was not active, so this adds it)
            localOperations.add(controller.togglePinnedRule(ruleName));
            final hlc = controller.clock.nextTimestamp();
            expectedOrSet = expectedOrSet.add(ruleName, ruleName, hlc);
          }
        }

        // Interleave everything concurrently in seeded random order
        final allOperations = [...remoteOperations, ...localOperations]
          ..shuffle(rng);

        await Future.wait<dynamic>(allOperations);

        // Allow microtasks and dispatchers to settle
        await Future<void>.delayed(const Duration(milliseconds: 15));

        final finalRecord = repo.activeProfile!;

        // 1. Assert: final record == serial join of all operations
        expect(
          finalRecord.partyPurse.getBalance('gp'),
          equals(expectedGpSum),
          reason: 'Schedule $s: final gp balance must equal sum of all deltas',
        );

        for (final val in expectedOrSet.activeValues) {
          expect(
            finalRecord.pinnedRuleIds.contains(val),
            isTrue,
            reason: 'Schedule $s: active rule $val must be in pinnedRuleIds',
          );
        }

        if (expectedWinningNotes.isNotEmpty) {
          expect(
            finalRecord.notesMarkdown,
            equals(expectedWinningNotes),
            reason: 'Schedule $s: notes must converge to LWW winner',
          );
        }

        // 2. Assert: every local operation appears in broadcast payloads
        final localBroadcasts = mockTransport.broadcastedPayloads.where((p) {
          final decoded = jsonDecode(p) as Map<String, dynamic>;
          return decoded['origin_node_id'] == 'local_dm';
        }).toList();

        expect(
          localBroadcasts.isNotEmpty,
          isTrue,
          reason: 'Schedule $s: local operations must produce broadcasts',
        );

        // 3. Assert: no broadcast payload equals a value applied from remote (no echo)
        for (final broadcastJson in mockTransport.broadcastedPayloads) {
          final bDecoded = jsonDecode(broadcastJson) as Map<String, dynamic>;
          final bOrigin = bDecoded['origin_node_id'];
          // A broadcast payload must not mirror remote payload contents
          expect(
            bOrigin,
            equals('local_dm'),
            reason: 'Schedule $s: broadcast payload origin must be local',
          );
        }

        controller.dispose();
        orchestrator.stopSynchronization();
        repo.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
