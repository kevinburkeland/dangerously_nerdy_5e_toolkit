import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/crdt/crdt_or_set_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';

class _MockNetworkTimePort implements INetworkTimePort {
  int networkTimeMs = 1700000000000;
  @override
  Future<int> getNetworkTimeMs() async => networkTimeMs;
}

class _MockTransportPort implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  String? roomCode;

  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

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
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) {
    _incomingController.add(payload);
  }

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    this.roomCode = roomCode;
  }

  @override
  Future<void> disconnect() async {
    await _incomingController.close();
  }
}

class _MockCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final Map<String, CampaignProfile> profiles = {};
  final StreamController<CampaignProfile?> _activeController =
      StreamController<CampaignProfile?>.broadcast();
  final List<CampaignProfile> savedImmediateProfiles = [];

  @override
  CampaignProfile? get activeProfile => _activeProfile;
  set activeProfile(CampaignProfile? p) {
    _activeProfile = p;
    if (p != null) profiles[p.id] = p;
  }

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
    savedImmediateProfiles.add(profile);
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id] ??
        (_activeProfile?.id == id ? _activeProfile! : null);
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
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      Stream.value(allProfiles);
}

void main() {
  group('Cold Iron Birdcage: Pass 7 — Campaign Isolation Law Suite (P2)', () {
    test('Campaign Isolation Law: 250 random seeds enforce campaign isolation and dead-letter mismatches', () async {
      const totalSeeds = 250;

      for (int seed = 0; seed < totalSeeds; seed++) {
        final rng = Random(seed + 3000);
        final activeCampId = 'camp_active_$seed';
        final roomCode = 'ROOM_$seed';

        final clock = StatefulHlcClock(replicaId: ReplicaId('local_node_$seed'));
        final transport = _MockTransportPort();
        final repo = _MockCampaignRepo();
        final timePort = _MockNetworkTimePort();
        final clockSync = ClockSyncService(networkTimePort: timePort);
        final reconciliation = RoomStateReconciliationService(
          networkTimeProvider: () => clockSync.currentNetworkTimeMs,
        );

        final initialProfile = CampaignProfile.defaultProfile(
          id: activeCampId,
          nodeId: 'node_init',
          clock: StatefulHlcClock(replicaId: ReplicaId('node_init')),
        ).copyWith(
          roomState: RoomNodeState(roomId: 'r_$seed', roomCode: roomCode),
          partyPurse: const PartyPurse.empty().setDenomination(
            'gp',
            10,
            replicaId: ReplicaId('node_init'),
          ),
          pinnedRules: const CrdtOrSet<String>.empty(),
        );

        repo.activeProfile = initialProfile;

        final orchestrator = RoomSyncOrchestrator(
          transportPort: transport,
          campaignRepo: repo,
          reconciliationService: reconciliation,
          clockSyncService: clockSync,
          payloadMapper: const RoomSyncPayloadMapper(),
          replicaId: ReplicaId('local_node_$seed'),
          clock: clock,
        );
        orchestrator.startSynchronization();

        final deadLetters = <SyncErrorEvent>[];
        final sub = orchestrator.deadLetterStream.listen(deadLetters.add);

        // 3 Message Types:
        // 0: full_profile ('room_sync_full')
        // 1: crdt_purse_delta
        // 2: crdt_or_set_delta
        final msgTypeChoice = rng.nextInt(3);

        // Campaign ID Category:
        // 0: matching
        // 1: other
        // 2: empty string
        // 3: whitespace
        final idCategory = rng.nextInt(4);
        final isMatching = idCategory == 0;
        final candidateCampId = isMatching
            ? activeCampId
            : (idCategory == 1 ? 'other_camp_$seed' : (idCategory == 2 ? '' : '   '));

        final now = DateTime.now().millisecondsSinceEpoch;
        final String rawPayload;

        if (msgTypeChoice == 0) {
          // Full profile
          final remoteProfile = CampaignProfile.defaultProfile(
            id: candidateCampId,
            nodeId: 'remote_node',
            timestamp: HybridLogicalClock(physicalTime: now, logicalCounter: 1, nodeId: 'remote_node'),
          ).copyWith(
            roomState: RoomNodeState(roomId: 'r_$seed', roomCode: roomCode),
            notesMarkdown: 'Remote updated notes seed $seed',
            notesTimestamp: HybridLogicalClock(physicalTime: now, logicalCounter: 1, nodeId: 'remote_node'),
            partyPurse: const PartyPurse.empty().setDenomination('gp', 50, replicaId: ReplicaId('remote_node')),
          );
          rawPayload = jsonEncode({
            'type': 'room_sync_full',
            'origin_node_id': 'remote_node_$seed',
            'payload': CampaignProfileDto.fromDomain(remoteProfile).toMap(),
            'timestamp': now + 10,
          });
        } else if (msgTypeChoice == 1) {
          // Purse delta
          final purseDelta = const PartyPurse.empty().setDenomination(
            'gp',
            100,
            replicaId: ReplicaId('remote_node_$seed'),
          );
          rawPayload = jsonEncode({
            'type': 'crdt_purse_delta',
            'origin_node_id': 'remote_node_$seed',
            'origin_seq': seed + 1,
            'campaign_id': candidateCampId,
            'payload': purseDelta.toMap(),
            'timestamp': now + 10,
          });
        } else {
          // OrSet delta
          final ruleDelta = const CrdtOrSet<String>.empty().add(
            'rule_$seed',
            'tag_$seed',
            HybridLogicalClock(physicalTime: now, logicalCounter: 1, nodeId: 'remote_node_$seed'),
          );
          rawPayload = jsonEncode({
            'type': 'crdt_or_set_delta',
            'origin_node_id': 'remote_node_$seed',
            'origin_seq': seed + 1,
            'campaign_id': candidateCampId,
            'payload': CrdtOrSetDto.toMap(ruleDelta, (v) => v),
            'timestamp': now + 10,
          });
        }

        final initialSavedCount = repo.savedImmediateProfiles.length;
        final initialGp = repo.activeProfile!.partyPurse.getBalance('gp');

        transport.emitIncoming(rawPayload);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        if (isMatching) {
          // Matching: Accepted and applied
          expect(deadLetters, isEmpty, reason: 'Seed $seed: Matching campaign ID must not dead-letter');
          expect(
            repo.savedImmediateProfiles.length,
            greaterThan(initialSavedCount),
            reason: 'Seed $seed: Matching campaign ID must update repository',
          );
        } else {
          // Mismatch or empty: Must dead-letter and change nothing
          expect(deadLetters, isNotEmpty, reason: 'Seed $seed: Non-matching campaign ID must dead-letter');
          expect(
            deadLetters.last.error.toString(),
            contains('Campaign ID mismatch'),
            reason: 'Seed $seed: Dead letter error must state campaign ID mismatch',
          );
          expect(
            repo.savedImmediateProfiles.length,
            equals(initialSavedCount),
            reason: 'Seed $seed: Non-matching campaign must NOT save profile',
          );
          expect(
            repo.activeProfile!.partyPurse.getBalance('gp'),
            equals(initialGp),
            reason: 'Seed $seed: Non-matching campaign must not mutate active profile',
          );
        }

        await sub.cancel();
        orchestrator.dispose();
      }
    });
  });
}
