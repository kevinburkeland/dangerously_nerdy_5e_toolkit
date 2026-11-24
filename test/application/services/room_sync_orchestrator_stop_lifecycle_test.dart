import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

class _FakeTransport implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incoming = StreamController<String>.broadcast();

  @override
  TransportState currentState = TransportState.localWifi;

  @override
  Map<String, int> peerLastSeen = {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incoming.stream;

  void emitIncoming(String payload) => _incoming.add(payload);

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    await _incoming.close();
  }
}

class _FakeCampaignRepo implements ICampaignRepository {
  CampaignProfile? _active;
  final StreamController<CampaignProfile?> _ctrl =
      StreamController<CampaignProfile?>.broadcast();

  @override
  CampaignProfile? get activeProfile => _active;

  @override
  String? get activeProfileId => _active?.id;

  @override
  List<CampaignProfile> get allProfiles => _active != null ? [_active!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _active;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _active?.id == id ? _active : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final updated = transform(_active!);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    _active = profile;
  }

  @override
  Future<void> deleteProfile(String id) async {}

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _ctrl.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();

  void emitLocal(CampaignProfile profile) {
    _active = profile;
    _ctrl.add(profile);
  }

  void dispose() => _ctrl.close();
}

class _FakeTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => 1700000000000;
}

CampaignProfile _makeCampaign({
  required String id,
  required String name,
  required Set<String> pinnedRules,
  required HybridLogicalClock ts,
  required String nodeId,
}) {
  final rulesCrdt = const CrdtOrSet<String>.empty().addBatch(
    pinnedRules.map((r) => (id: r, item: r, timestamp: ts)),
  );
  return CampaignProfile(
    id: id,
    name: name,
    edition: DmRulesEdition.v2024,
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    nodeId: nodeId,
    roomState: RoomNodeState(
      roomId: 'room_$id',
      roomCode: 'ROOM-${id.toUpperCase()}',
      title: name,
      titleTimestamp: ts,
    ),
    pinnedRules: rulesCrdt,
  );
}

void main() {
  group('Fix 5.2: RoomSyncOrchestrator.stopSynchronization forgets old campaign', () {
    test(
      'stopping campaign A and starting campaign B emits no rule or tombstone from A and leaks no dead letters',
      () async {
        final transport = _FakeTransport();
        final repo = _FakeCampaignRepo();
        final replica = ReplicaId('node_lifecycle_1');
        final clock = StatefulHlcClock(
          replicaId: replica,
          timeProvider: () => 1700000000000,
        );
        final clockSync = ClockSyncService(networkTimePort: _FakeTimePort());
        final reconciliation = RoomStateReconciliationService(
          networkTimeProvider: () => 1700000000000,
        );

        final orchestrator = RoomSyncOrchestrator(
          transportPort: transport,
          campaignRepo: repo,
          reconciliationService: reconciliation,
          clockSyncService: clockSync,
          payloadMapper: const RoomSyncPayloadMapper(),
          replicaId: replica,
          clock: clock,
          localTimeProvider: () => 1700000000000,
        );

        // 1. Start campaign A, emit initial sync, then pin rule 'a' so _trackedRulesSet records it
        final tsA = clock.nextTimestamp();
        final campaignAEmpty = _makeCampaign(
          id: 'cmp_a',
          name: 'Campaign A',
          pinnedRules: const {},
          ts: tsA,
          nodeId: replica.value,
        );
        final tsA2 = clock.nextTimestamp();
        final campaignA = campaignAEmpty.copyWith(
          pinnedRules: campaignAEmpty.pinnedRules.add('a', 'a', tsA2),
        );
        repo.emitLocal(campaignAEmpty);
        orchestrator.startSynchronization(isHost: true);
        repo.emitLocal(campaignAEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        repo.emitLocal(campaignA);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Emit a malformed incoming payload during A (dead letter for A)
        transport.emitIncoming('not-valid-json-during-A');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(transport.broadcastedPayloads, isNotEmpty);

        // 2. Stop synchronization
        orchestrator.stopSynchronization();
        transport.broadcastedPayloads.clear();

        // Attach a dead-letter listener for campaign B after stopSynchronization
        final bDeadLetters = <SyncErrorEvent>[];
        final dlSub = orchestrator.deadLetterStream.listen(bDeadLetters.add);

        // 3. Start campaign B with pinned rules {'b'}
        final tsB = clock.nextTimestamp();
        final campaignB = _makeCampaign(
          id: 'cmp_b',
          name: 'Campaign B',
          pinnedRules: {'b'},
          ts: tsB,
          nodeId: replica.value,
        );
        repo.emitLocal(campaignB);
        orchestrator.startSynchronization(isHost: true);
        repo.emitLocal(campaignB);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          transport.broadcastedPayloads,
          isNotEmpty,
          reason: 'Campaign B must emit its full sync payload',
        );

        final rawB = transport.broadcastedPayloads.first;
        final decodedB = jsonDecode(rawB) as Map<String, dynamic>;
        final payloadJson = jsonEncode(decodedB);

        expect(
          decodedB['type'],
          equals('room_sync_full'),
          reason: 'First emission for Campaign B must be a room_sync_full',
        );

        final profileMap = decodedB['payload'] as Map<String, dynamic>?;
        expect(profileMap, isNotNull, reason: 'Payload: $payloadJson');
        final pinnedRulesCrdt =
            profileMap!['pinnedRules_crdt'] as Map<String, dynamic>?;
        final items =
            (pinnedRulesCrdt?['items'] as Map<String, dynamic>?) ?? const {};
        final tombstones =
            (pinnedRulesCrdt?['tombstones'] as Map<String, dynamic>?) ??
                const {};

        expect(
          items.containsKey('a'),
          isFalse,
          reason: 'Campaign B payload must not contain rule "a" from Campaign A',
        );
        expect(
          tombstones.containsKey('a'),
          isFalse,
          reason:
              'Campaign B payload must not contain tombstone for "a" from Campaign A',
        );
        // Also check top-level tracked pinned_rules_crdt envelope field!
        final envelopeRules =
            decodedB['pinned_rules_crdt'] as Map<String, dynamic>?;
        final envItems =
            (envelopeRules?['items'] as Map<String, dynamic>?) ?? const {};
        final envTombstones =
            (envelopeRules?['tombstones'] as Map<String, dynamic>?) ??
                const {};
        expect(
          envItems.containsKey('a'),
          isFalse,
          reason:
              'Campaign B envelope pinned_rules_crdt must not leak rule "a" from Campaign A (got $envelopeRules)',
        );
        expect(
          envTombstones.containsKey('a'),
          isFalse,
          reason:
              'Campaign B envelope pinned_rules_crdt must not leak tombstone "a" from Campaign A',
        );
        expect(
          items.containsKey('b'),
          isTrue,
          reason: 'Campaign B payload must contain rule "b"',
        );
        expect(
          bDeadLetters,
          isEmpty,
          reason: 'Dead-letter listener for B must see nothing from A',
        );

        await dlSub.cancel();
        orchestrator.dispose();
        repo.dispose();
        await transport.disconnect();
      },
    );
  });
}
