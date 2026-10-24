import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

class InMemCampaignRepo implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final StreamController<CampaignProfile?> _controller =
      StreamController<CampaignProfile?>.broadcast();

  InMemCampaignRepo([CampaignProfile? initial]) : _activeProfile = initial;

  @override
  CampaignProfile? get activeProfile => _activeProfile;
  set activeProfile(CampaignProfile? profile) => _activeProfile = profile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles =>
      _activeProfile != null ? [_activeProfile!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _activeProfile?.id == id ? _activeProfile : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = (_activeProfile?.id == id)
        ? _activeProfile!
        : throw StateError('Profile not found: $id');
    final updated = transform(current);
    _activeProfile = updated;
    _controller.add(updated);
    return updated;
  }

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    _activeProfile = profile;
    _controller.add(profile);
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _controller.add(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _controller.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      Stream.value(allProfiles);

  void dispose() {
    _controller.close();
  }
}

class TestP2pBus {
  final Map<String, TestP2pBusNode> _nodes = {};
  final Set<String> _cutLinks = {};
  double dropRate = 0.0;
  final math.Random random;

  TestP2pBus({int seed = 42}) : random = math.Random(seed);

  String _linkKey(String a, String b) =>
      a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';

  void cutLink(String a, String b) {
    _cutLinks.add(_linkKey(a, b));
  }

  void healLink(String a, String b) {
    _cutLinks.remove(_linkKey(a, b));
  }

  void healAll() {
    _cutLinks.clear();
  }

  bool isCut(String a, String b) => _cutLinks.contains(_linkKey(a, b));

  void registerNode(TestP2pBusNode node) {
    _nodes[node.nodeId] = node;
  }

  void broadcast(String fromNodeId, String payload) {
    final sender = _nodes[fromNodeId];
    if (sender == null || !sender.isAttached) return;

    for (final recipient in _nodes.values) {
      if (recipient.nodeId == fromNodeId) continue;
      if (!recipient.isAttached) continue;
      if (isCut(fromNodeId, recipient.nodeId)) continue;
      if (dropRate > 0 && random.nextDouble() < dropRate) continue;

      Timer.run(() {
        if (recipient.isAttached && !recipient._incomingController.isClosed) {
          recipient._incomingController.add(payload);
        }
      });
    }
  }
}

class TestP2pBusNode implements IP2pTransportPort {
  final String nodeId;
  final TestP2pBus bus;
  String roomCode;
  bool isAttached = true;
  int messageCount = 0;
  TransportState? stateOverride;

  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  TestP2pBusNode({
    required this.nodeId,
    required this.bus,
    required this.roomCode,
  }) {
    bus.registerNode(this);
  }

  @override
  TransportState get currentState {
    if (stateOverride != null) return stateOverride!;
    if (!isAttached) return TransportState.offline;
    final canReachAny = bus._nodes.values.any((other) =>
        other.nodeId != nodeId &&
        other.isAttached &&
        !bus.isCut(nodeId, other.nodeId));
    return canReachAny ? TransportState.webRtc : TransportState.offline;
  }

  @override
  Map<String, int> get peerLastSeen {
    if (!isAttached) return const {};
    final peers = <String, int>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final other in bus._nodes.values) {
      if (other.nodeId != nodeId &&
          other.isAttached &&
          !bus.isCut(nodeId, other.nodeId)) {
        peers[other.nodeId] = now;
      }
    }
    return peers;
  }

  @override
  Duration get heartbeatTtl => const Duration(seconds: 30);

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    messageCount++;
    bus.broadcast(nodeId, jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      isAttached;

  @override
  Future<void> prepareSession() async {}

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    isAttached = false;
  }

  void dispose() {
    _incomingController.close();
  }
}

class TestTimePort implements INetworkTimePort {
  int timeMs;
  TestTimePort({this.timeMs = 1700000000000});

  @override
  Future<int> getNetworkTimeMs() async => timeMs;
}

class DeviceHarness {
  final String nodeId;
  final ReplicaId replicaId;
  final StatefulHlcClock clock;
  final InMemCampaignRepo repo;
  final TestP2pBusNode node;
  final RoomSyncOrchestrator orchestrator;
  final List<SyncErrorEvent> deadLetters = <SyncErrorEvent>[];
  late final StreamSubscription<SyncErrorEvent> _deadLetterSub;

  DeviceHarness._({
    required this.nodeId,
    required this.replicaId,
    required this.clock,
    required this.repo,
    required this.node,
    required this.orchestrator,
  }) {
    _deadLetterSub = orchestrator.deadLetterStream.listen(deadLetters.add);
  }

  static DeviceHarness create({
    required String nodeId,
    required TestP2pBus bus,
    required String roomCode,
    required Duration telemetryInterval,
    required Duration antiEntropyInterval,
    CampaignProfile? initialProfile,
    bool isHost = false,
  }) {
    final repId = ReplicaId(nodeId);
    final clk = StatefulHlcClock(replicaId: repId);
    final rp = InMemCampaignRepo(initialProfile);
    final nd = TestP2pBusNode(nodeId: nodeId, bus: bus, roomCode: roomCode);
    final timePort = TestTimePort();
    final clkSync = ClockSyncService(networkTimePort: timePort);
    final reconciler = RoomStateReconciliationService(
      networkTimeProvider: () => clkSync.currentNetworkTimeMs,
    );
    final orch = RoomSyncOrchestrator(
      transportPort: nd,
      campaignRepo: rp,
      reconciliationService: reconciler,
      clockSyncService: clkSync,
      payloadMapper: const RoomSyncPayloadMapper(),
      replicaId: repId,
      clock: clk,
      telemetryInterval: telemetryInterval,
      antiEntropyInterval: antiEntropyInterval,
      isHost: isHost,
    );

    return DeviceHarness._(
      nodeId: nodeId,
      replicaId: repId,
      clock: clk,
      repo: rp,
      node: nd,
      orchestrator: orch,
    );
  }

  void dispose() {
    _deadLetterSub.cancel();
    orchestrator.dispose();
    node.dispose();
    repo.dispose();
  }
}

CampaignProfile createBaseProfile(
    String roomCode, StatefulHlcClock clock, String nodeId) {
  final t = clock.nextTimestamp();
  return CampaignProfile(
    id: 'campaign-pass11-test',
    nameRegister: CrdtLwwRegister<String>(value: 'Base Campaign', timestamp: t),
    notesRegister: CrdtLwwRegister<String>(value: 'Base Notes', timestamp: t),
    roomState: RoomNodeState(
      roomId: 'room-$roomCode',
      roomCode: roomCode,
      titleRegister:
          CrdtLwwRegister<String>(value: 'Base Title', timestamp: t),
      descriptionRegister:
          CrdtLwwRegister<String>(value: 'Base Desc', timestamp: t),
    ),
    partyPurse: const PartyPurse.empty(),
    pinnedRules: const CrdtOrSet<String>.empty(),
    rulesetId: 'v2024',
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
    nodeId: nodeId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shortTick = Duration(milliseconds: 10);
  const longPeriod = Duration(hours: 1);
  const fastPeriod = Duration(milliseconds: 40);

  group('Cold Iron Pass 11 - Sync Liveness Suite', () {
    test('E1 late joiner (trigger C)', () async {
      // Control: with the bus fully down, player attaches but nothing arrives (the harness can fail)
      {
        final busCtrl = TestP2pBus(seed: 100);
        busCtrl.dropRate = 1.0;
        final dmCtrl = DeviceHarness.create(
          nodeId: 'dm',
          bus: busCtrl,
          roomCode: 'ROOM1',
          telemetryInterval: shortTick,
          antiEntropyInterval: longPeriod,
          isHost: true,
        );
        final baseCtrl = createBaseProfile('ROOM1', dmCtrl.clock, 'dm');
        final stampCtrl = dmCtrl.clock.nextTimestamp();
        final dmEditedCtrl = baseCtrl.copyWith(
          nameRegister: CrdtLwwRegister<String>(value: 'Dragon Heist', timestamp: stampCtrl),
        );
        await dmCtrl.repo.putProfile(dmEditedCtrl);
        dmCtrl.orchestrator.startSynchronization();

        // Player attaches later while bus is down
        final playerCtrl = DeviceHarness.create(
          nodeId: 'player',
          bus: busCtrl,
          roomCode: 'ROOM1',
          telemetryInterval: shortTick,
          antiEntropyInterval: longPeriod,
        );
        await playerCtrl.repo.putProfile(baseCtrl);
        playerCtrl.orchestrator.startSynchronization();

        await Future<void>.delayed(shortTick * 2 + const Duration(milliseconds: 15));
        expect(playerCtrl.repo.activeProfile!.name, 'Base Campaign');

        dmCtrl.dispose();
        playerCtrl.dispose();
      }

      // Main: DM is attached with edited profile and already active with dummy peer.
      final bus = TestP2pBus(seed: 1);
      final dummy = DeviceHarness.create(
        nodeId: 'dummy',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      final dm = DeviceHarness.create(
        nodeId: 'dm',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
        isHost: true,
      );

      // DM edits name, notes, room title and purse
      final base = createBaseProfile('ROOM1', dm.clock, 'dm');
      final stamp = dm.clock.nextTimestamp();
      final editedPurse =
          const PartyPurse.empty().modifyDenomination('gp', 500, replicaId: dm.replicaId);
      final dmEdited = base.copyWith(
        nameRegister:
            CrdtLwwRegister<String>(value: 'Dragon Heist', timestamp: stamp),
        notesRegister: CrdtLwwRegister<String>(
            value: 'the vault is under the tavern', timestamp: stamp),
        roomState: base.roomState.copyWith(
          titleRegister:
              CrdtLwwRegister<String>(value: 'Vault Room', timestamp: stamp),
        ),
        partyPurse: editedPurse,
      );
      await dm.repo.putProfile(dmEdited);
      dm.orchestrator.startSynchronization();

      // Small delay so DM is established
      await Future<void>.delayed(shortTick);

      // A player attaches later with transport connecting (can receive, does not send).
      // This strictly proves DM's Trigger C is what sends the profile to the late joiner.
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      player.node.stateOverride = TransportState.connecting;
      final playerInitial = base;
      await player.repo.putProfile(playerInitial);
      player.orchestrator.startSynchronization();

      final dmCountBefore = dm.node.messageCount;

      // Within two telemetry ticks the DM detects the new peer (Trigger C) and sends
      await Future<void>.delayed(shortTick * 2 + const Duration(milliseconds: 15));

      expect(dm.node.messageCount, greaterThan(dmCountBefore));
      final finalPlayer = player.repo.activeProfile!;
      expect(finalPlayer.name, 'Dragon Heist');
      expect(finalPlayer.notesMarkdown, 'the vault is under the tavern');
      expect(finalPlayer.roomState.title, 'Vault Room');
      expect(finalPlayer.partyPurse.getBalance('gp'), 500);

      dummy.dispose();
      dm.dispose();
      player.dispose();
    });

    test('E2 join write (trigger A)', () async {
      final bus = TestP2pBus(seed: 2);
      final dm = DeviceHarness.create(
        nodeId: 'dm',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
        isHost: true,
      );
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', dm.clock, 'dm');
      await dm.repo.putProfile(base);
      dm.orchestrator.startSynchronization();

      // Write player's profile to its repository BEFORE startSynchronization
      final pStamp = player.clock.nextTimestamp();
      final playerProfile = base.copyWith(
        nameRegister:
            CrdtLwwRegister<String>(value: 'Player Campaign', timestamp: pStamp),
      );
      await player.repo.putProfile(playerProfile);

      // Start player synchronization (Trigger A must fire on start)
      player.orchestrator.startSynchronization();

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(dm.repo.activeProfile!.name, 'Player Campaign');

      dm.dispose();
      player.dispose();
    });

    test('E3 transport becomes active (trigger B)', () async {
      final bus = TestP2pBus(seed: 3);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      final stamp = devA.clock.nextTimestamp();
      final edited = base.copyWith(
        nameRegister:
            CrdtLwwRegister<String>(value: 'Trigger B Test', timestamp: stamp),
      );
      await devA.repo.putProfile(edited);
      await devB.repo.putProfile(base);

      // devA starts while transport is connecting
      devA.node.stateOverride = TransportState.connecting;
      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      await Future<void>.delayed(const Duration(milliseconds: 25));
      // devB should not have received it yet
      expect(devB.repo.activeProfile!.name, 'Base Campaign');

      // Now devA becomes webRtc with the same peer set
      devA.node.stateOverride = TransportState.webRtc;

      // Advance by telemetry tick to trigger B
      await Future<void>.delayed(shortTick * 2 + const Duration(milliseconds: 15));

      expect(devB.repo.activeProfile!.name, 'Trigger B Test');

      devA.dispose();
      devB.dispose();
    });

    test('E4 healed partition', () async {
      final bus = TestP2pBus(seed: 4);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      await devB.repo.putProfile(base);
      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      // Cut link A-B
      bus.cutLink('devA', 'devB');

      // A edits notes, B edits name while cut
      final stampA = devA.clock.nextTimestamp();
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            notesRegister:
                CrdtLwwRegister<String>(value: 'Notes from A', timestamp: stampA),
          ));

      final stampB = devB.clock.nextTimestamp();
      await devB.repo.updateProfile(base.id, (c) => c.copyWith(
            nameRegister:
                CrdtLwwRegister<String>(value: 'Name from B', timestamp: stampB),
          ));

      // Verify they differ while cut
      expect(devA.repo.activeProfile!.notesMarkdown, 'Notes from A');
      expect(devA.repo.activeProfile!.name, 'Base Campaign');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Base Notes');
      expect(devB.repo.activeProfile!.name, 'Name from B');

      // Heal link
      bus.healLink('devA', 'devB');

      // Wait two telemetry ticks for peer detection / reply
      await Future<void>.delayed(shortTick * 2 + const Duration(milliseconds: 30));

      expect(devA.repo.activeProfile!.name, 'Name from B');
      expect(devA.repo.activeProfile!.notesMarkdown, 'Notes from A');
      expect(devB.repo.activeProfile!.name, 'Name from B');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Notes from A');

      devA.dispose();
      devB.dispose();
    });

    test('E5 reply when behind (trigger D)', () async {
      final bus = TestP2pBus(seed: 5);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod,
        antiEntropyInterval: longPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      // A is ahead of B
      final stampA = devA.clock.nextTimestamp();
      final aheadProfile = base.copyWith(
        nameRegister:
            CrdtLwwRegister<String>(value: 'Ahead Name', timestamp: stampA),
        notesRegister:
            CrdtLwwRegister<String>(value: 'Ahead Notes', timestamp: stampA),
      );
      await devA.repo.putProfile(aheadProfile);
      await devB.repo.putProfile(base);

      // Start with link cut so A does not send on start to B
      bus.cutLink('devA', 'devB');
      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(devB.repo.activeProfile!.name, 'Base Campaign');

      // Now heal link so A's reply can reach B
      bus.healLink('devA', 'devB');

      // B sends its older full profile to A
      final aCountBefore = devA.node.messageCount;
      final oldPayload = const RoomSyncPayloadMapper().serializeFullProfileSync(
        profile: base,
        originNodeId: 'devB',
        originSeq: 10,
        timestamp: 1700000000000,
        trackedRulesSet: const CrdtOrSet<String>.empty(),
      );
      await devA.orchestrator.handleIncomingPayload(oldPayload);

      // Wait for reply from A
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(devA.node.messageCount, greaterThan(aCountBefore));
      expect(devB.repo.activeProfile!.name, 'Ahead Name');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Ahead Notes');

      // Control: when A and B are already equal, A sends nothing in reply
      final aCountBeforeEqual = devA.node.messageCount;
      final equalPayload = const RoomSyncPayloadMapper().serializeFullProfileSync(
        profile: devB.repo.activeProfile!,
        originNodeId: 'devB',
        originSeq: 2,
        timestamp: 1700000000001,
        trackedRulesSet: const CrdtOrSet<String>.empty(),
      );
      await devA.orchestrator.handleIncomingPayload(equalPayload);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(devA.node.messageCount, equals(aCountBeforeEqual));

      devA.dispose();
      devB.dispose();
    });

    test('E6 no ping-pong', () async {
      final bus = TestP2pBus(seed: 6);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      await devB.repo.putProfile(base);
      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      // Cut link, edit both sides, heal (E4 flow)
      bus.cutLink('devA', 'devB');
      final stampA = devA.clock.nextTimestamp();
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            notesRegister:
                CrdtLwwRegister<String>(value: 'Notes A', timestamp: stampA),
          ));
      final stampB = devB.clock.nextTimestamp();
      await devB.repo.updateProfile(base.id, (c) => c.copyWith(
            nameRegister:
                CrdtLwwRegister<String>(value: 'Name B', timestamp: stampB),
          ));

      bus.healLink('devA', 'devB');
      await Future<void>.delayed(shortTick * 3 + const Duration(milliseconds: 30));

      expect(devA.repo.activeProfile!.name, 'Name B');
      expect(devA.repo.activeProfile!.notesMarkdown, 'Notes A');
      expect(devB.repo.activeProfile!.name, 'Name B');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Notes A');

      // Record message counts
      final countA = devA.node.messageCount;
      final countB = devB.node.messageCount;

      // Run 20 more telemetry ticks with periodic interval long
      await Future<void>.delayed(shortTick * 20 + const Duration(milliseconds: 10));

      expect(devA.node.messageCount, equals(countA));
      expect(devB.node.messageCount, equals(countB));

      devA.dispose();
      devB.dispose();
    });

    test('E7 periodic repair (trigger E)', () async {
      final bus = TestP2pBus(seed: 7);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod, // long telemetry interval so C doesn't fire
        antiEntropyInterval: fastPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod,
        antiEntropyInterval: fastPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      await devB.repo.putProfile(base);

      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      // Drop every message for a while
      bus.dropRate = 1.0;

      // Edit on both sides
      final stampA = devA.clock.nextTimestamp();
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            notesRegister:
                CrdtLwwRegister<String>(value: 'Periodic Notes A', timestamp: stampA),
          ));
      final stampB = devB.clock.nextTimestamp();
      await devB.repo.updateProfile(base.id, (c) => c.copyWith(
            nameRegister:
                CrdtLwwRegister<String>(value: 'Periodic Name B', timestamp: stampB),
          ));

      // Wait while dropRate is 1.0 to ensure the edit broadcasts were dropped
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(devA.repo.activeProfile!.name, 'Base Campaign');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Base Notes');

      // Stop dropping
      bus.dropRate = 0.0;

      // With no edits, they converge within one antiEntropyInterval
      await Future<void>.delayed(fastPeriod * 2 + const Duration(milliseconds: 30));

      expect(devA.repo.activeProfile!.name, 'Periodic Name B');
      expect(devA.repo.activeProfile!.notesMarkdown, 'Periodic Notes A');
      expect(devB.repo.activeProfile!.name, 'Periodic Name B');
      expect(devB.repo.activeProfile!.notesMarkdown, 'Periodic Notes A');

      devA.dispose();
      devB.dispose();
    });

    test('E8 lost delta repaired', () async {
      final bus = TestP2pBus(seed: 8);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod,
        antiEntropyInterval: fastPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: longPeriod,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      await devB.repo.putProfile(base);

      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      // Drop messages while deltas are emitted
      bus.dropRate = 1.0;

      // Purse-only change on A
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            partyPurse: c.partyPurse.modifyDenomination('gp', 150, replicaId: devA.replicaId),
          ));

      // Pinned-rules change on B
      final rStamp = devB.clock.nextTimestamp();
      await devB.repo.updateProfile(base.id, (c) => c.copyWith(
            pinnedRules: c.pinnedRules.add('rule_grappling', 'rule_grappling', rStamp),
          ));

      // Wait while dropRate is 1.0 to ensure the delta broadcasts were dropped
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(devB.repo.activeProfile!.partyPurse.getBalance('gp'), 0);
      expect(devA.repo.activeProfile!.pinnedRules.activeValues, isNot(contains('rule_grappling')));

      // Restore bus so anti-entropy send gets through
      bus.dropRate = 0.0;

      // After the next anti-entropy send, purse and pinned rules match on both devices
      await Future<void>.delayed(fastPeriod * 2 + const Duration(milliseconds: 30));

      expect(devB.repo.activeProfile!.partyPurse.getBalance('gp'), 150);
      expect(devB.repo.activeProfile!.pinnedRules.activeValues, contains('rule_grappling'));
      expect(devA.repo.activeProfile!.partyPurse, equals(devB.repo.activeProfile!.partyPurse));
      expect(devA.repo.activeProfile!.pinnedRules, equals(devB.repo.activeProfile!.pinnedRules));

      devA.dispose();
      devB.dispose();
    });

    test('E9 room isolation', () async {
      final bus = TestP2pBus(seed: 9);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM_ALPHA',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastPeriod,
      );

      // devA has a profile whose roomCode is ROOM_BETA != ROOM_ALPHA
      final base = createBaseProfile('ROOM_BETA', devA.clock, 'devA');
      await devA.repo.putProfile(base);

      final msgCountBefore = devA.node.messageCount;
      devA.orchestrator.startSynchronization();

      await Future<void>.delayed(fastPeriod * 2 + const Duration(milliseconds: 20));

      // Sends nothing from any trigger
      expect(devA.node.messageCount, equals(msgCountBefore));

      devA.dispose();
    });

    test('E10 stop', () async {
      final bus = TestP2pBus(seed: 10);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      devA.orchestrator.startSynchronization();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      devA.orchestrator.stopSynchronization();

      final countAtStop = devA.node.messageCount;

      // Local edit
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            nameRegister: CrdtLwwRegister<String>(
                value: 'Stopped Edit', timestamp: devA.clock.nextTimestamp()),
          ));

      // Wait multiple antiEntropyIntervals and telemetry ticks
      await Future<void>.delayed(fastPeriod * 3 + const Duration(milliseconds: 30));

      expect(devA.node.messageCount, equals(countAtStop));

      devA.dispose();
    });

    test('E11 local edit still propagates', () async {
      final bus = TestP2pBus(seed: 11);
      final devA = DeviceHarness.create(
        nodeId: 'devA',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );
      final devB = DeviceHarness.create(
        nodeId: 'devB',
        bus: bus,
        roomCode: 'ROOM1',
        telemetryInterval: shortTick,
        antiEntropyInterval: longPeriod,
      );

      final base = createBaseProfile('ROOM1', devA.clock, 'devA');
      await devA.repo.putProfile(base);
      await devB.repo.putProfile(base);
      devA.orchestrator.startSynchronization();
      devB.orchestrator.startSynchronization();

      // Wait for start trigger / sync
      await Future<void>.delayed(const Duration(milliseconds: 25));

      // After an anti-entropy send, perform an ordinary local purse-only edit
      await devA.repo.updateProfile(base.id, (c) => c.copyWith(
            partyPurse: c.partyPurse.modifyDenomination('gp', 25, replicaId: devA.replicaId),
          ));

      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(devB.repo.activeProfile!.partyPurse.getBalance('gp'), 25);

      devA.dispose();
      devB.dispose();
    });

    test('Liveness law over 100 seeds with 3 devices', () async {
      const seedCount = 100;
      const minSteps = 20;
      const maxSteps = 40;

      for (int seed = 0; seed < seedCount; seed++) {
        final rand = math.Random(seed);
        final bus = TestP2pBus(seed: seed);

        final devices = <String, DeviceHarness>{
          'dm': DeviceHarness.create(
            nodeId: 'dm',
            bus: bus,
            roomCode: 'LAW_ROOM',
            telemetryInterval: const Duration(milliseconds: 5),
            antiEntropyInterval: const Duration(milliseconds: 20),
            isHost: true,
          ),
          'p1': DeviceHarness.create(
            nodeId: 'p1',
            bus: bus,
            roomCode: 'LAW_ROOM',
            telemetryInterval: const Duration(milliseconds: 5),
            antiEntropyInterval: const Duration(milliseconds: 20),
          ),
          'p2': DeviceHarness.create(
            nodeId: 'p2',
            bus: bus,
            roomCode: 'LAW_ROOM',
            telemetryInterval: const Duration(milliseconds: 5),
            antiEntropyInterval: const Duration(milliseconds: 20),
          ),
        };

        final base = createBaseProfile('LAW_ROOM', devices['dm']!.clock, 'dm');
        for (final d in devices.values) {
          await d.repo.putProfile(base);
          d.orchestrator.startSynchronization();
        }

        // Recorded edits for verification
        CrdtLwwRegister<String> maxName = base.nameRegister;
        CrdtLwwRegister<String> maxNotes = base.notesRegister;
        CrdtLwwRegister<String> maxTitle = base.roomState.titleRegister;
        CrdtLwwRegister<String> maxDesc = base.roomState.descriptionRegister;
        PartyPurse expectedPurse = base.partyPurse;
        final expectedRuleAdds = <String, HybridLogicalClock>{};
        final expectedRuleRemoves = <String, HybridLogicalClock>{};

        final stepCount = minSteps + rand.nextInt(maxSteps - minSteps + 1);

        for (int step = 0; step < stepCount; step++) {
          final action = rand.nextInt(6);
          final devKeys = devices.keys.toList();
          final chosenKey = devKeys[rand.nextInt(devKeys.length)];
          final chosenDev = devices[chosenKey]!;

          switch (action) {
            case 0:
              // Cut or heal link
              final otherKey = devKeys[rand.nextInt(devKeys.length)];
              if (chosenKey != otherKey) {
                if (bus.isCut(chosenKey, otherKey)) {
                  bus.healLink(chosenKey, otherKey);
                } else {
                  bus.cutLink(chosenKey, otherKey);
                }
              }
            case 1:
              // Drop rate
              bus.dropRate = rand.nextDouble() * 0.5;
            case 2:
              // Detach or re-attach
              chosenDev.node.isAttached = !chosenDev.node.isAttached;
            case 3:
              // Name or notes edit (including empty string)
              final editNotes = rand.nextBool();
              final newVal = rand.nextInt(5) == 0
                  ? ''
                  : 'val_${seed}_${step}_${rand.nextInt(100)}';
              final stamp = chosenDev.clock.nextTimestamp();
              await chosenDev.repo.updateProfile(base.id, (c) {
                if (editNotes) {
                  final reg =
                      CrdtLwwRegister<String>(value: newVal, timestamp: stamp);
                  return c.copyWith(notesRegister: reg);
                } else {
                  final reg =
                      CrdtLwwRegister<String>(value: newVal, timestamp: stamp);
                  return c.copyWith(nameRegister: reg);
                }
              });
              final readBack = chosenDev.repo.activeProfile!;
              if (editNotes) {
                final wrote = readBack.notesRegister;
                if (wrote.timestamp.compareTo(maxNotes.timestamp) > 0) {
                  maxNotes = wrote;
                }
              } else {
                final wrote = readBack.nameRegister;
                if (wrote.timestamp.compareTo(maxName.timestamp) > 0) {
                  maxName = wrote;
                }
              }
            case 4:
              // Room title or description edit
              final editDesc = rand.nextBool();
              final newVal = rand.nextInt(5) == 0
                  ? ''
                  : 'room_${seed}_${step}_${rand.nextInt(100)}';
              final stamp = chosenDev.clock.nextTimestamp();
              await chosenDev.repo.updateProfile(base.id, (c) {
                if (editDesc) {
                  final reg =
                      CrdtLwwRegister<String>(value: newVal, timestamp: stamp);
                  return c.copyWith(
                    roomState: c.roomState.copyWith(descriptionRegister: reg),
                  );
                } else {
                  final reg =
                      CrdtLwwRegister<String>(value: newVal, timestamp: stamp);
                  return c.copyWith(
                    roomState: c.roomState.copyWith(titleRegister: reg),
                  );
                }
              });
              final readBack = chosenDev.repo.activeProfile!;
              if (editDesc) {
                final wrote = readBack.roomState.descriptionRegister;
                if (wrote.timestamp.compareTo(maxDesc.timestamp) > 0) {
                  maxDesc = wrote;
                }
              } else {
                final wrote = readBack.roomState.titleRegister;
                if (wrote.timestamp.compareTo(maxTitle.timestamp) > 0) {
                  maxTitle = wrote;
                }
              }
            case 5:
              // Purse credit/debit or pinned rule add/remove
              if (rand.nextBool()) {
                final isCredit = rand.nextBool();
                final amt = rand.nextInt(50) + 1;
                final delta = isCredit ? amt : -amt;
                await chosenDev.repo.updateProfile(base.id, (c) {
                  final p = c.partyPurse.modifyDenomination(
                    'gp',
                    delta,
                    replicaId: chosenDev.replicaId,
                  );
                  return c.copyWith(partyPurse: p);
                });
                expectedPurse = expectedPurse.modifyDenomination(
                  'gp',
                  delta,
                  replicaId: chosenDev.replicaId,
                );
              } else {
                final ruleId = 'rule_${rand.nextInt(4)}';
                final isAdd = rand.nextBool();
                final rStamp = chosenDev.clock.nextTimestamp();
                await chosenDev.repo.updateProfile(base.id, (c) {
                  final s = isAdd
                      ? c.pinnedRules.add(ruleId, ruleId, rStamp)
                      : c.pinnedRules.remove(ruleId, rStamp);
                  return c.copyWith(pinnedRules: s);
                });
                if (isAdd) {
                  expectedRuleAdds[ruleId] = rStamp;
                } else {
                  expectedRuleRemoves[ruleId] = rStamp;
                }
              }
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        // 4. Heal every link, set drop rate to 0, attach every device. Make no further edits.
        bus.healAll();
        bus.dropRate = 0.0;
        for (final d in devices.values) {
          d.node.isAttached = true;
          d.node.stateOverride = null;
        }

        // Advance time by two antiEntropyIntervals (2 * 20ms = 40ms + buffer)
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // 5. Assert: all three profiles are equal
        final dmProfile = devices['dm']!.repo.activeProfile!;
        final p1Profile = devices['p1']!.repo.activeProfile!;
        final p2Profile = devices['p2']!.repo.activeProfile!;

        try {
          expect(dmProfile, equals(p1Profile),
              reason: 'dm != p1 at seed $seed');
          expect(p1Profile, equals(p2Profile),
              reason: 'p1 != p2 at seed $seed');

          // Each register equals recorded edit with greatest HLC stamp
          expect(dmProfile.nameRegister.value, equals(maxName.value),
              reason: 'name value mismatch at seed $seed');
          expect(dmProfile.notesRegister.value, equals(maxNotes.value),
              reason: 'notes value mismatch at seed $seed');
          expect(
              dmProfile.roomState.titleRegister.value, equals(maxTitle.value),
              reason: 'title value mismatch at seed $seed');
          expect(dmProfile.roomState.descriptionRegister.value,
              equals(maxDesc.value),
              reason: 'desc value mismatch at seed $seed');

          // Purse equals base plus every recorded credit and debit
          expect(dmProfile.partyPurse.getBalance('gp'),
              equals(expectedPurse.getBalance('gp')),
              reason: 'purse mismatch at seed $seed');

          // Pinned rules equal the set implied by recorded adds and removes
          final expectedRules = <String>{};
          for (final entry in expectedRuleAdds.entries) {
            final removeStamp = expectedRuleRemoves[entry.key];
            if (removeStamp == null ||
                entry.value.compareTo(removeStamp) > 0) {
              expectedRules.add(entry.key);
            }
          }
          expect(dmProfile.pinnedRules.activeValues.toSet(), equals(expectedRules),
              reason: 'pinned rules mismatch at seed $seed');

          // No dead-letter events
          for (final d in devices.values) {
            expect(d.deadLetters, isEmpty,
                reason:
                    'dead letters on ${d.nodeId} at seed $seed: ${d.deadLetters.map((e) => e.error).toList()}');
          }
        } catch (_) {
          // ignore: avoid_print
          print('FAILED AT SEED: $seed');
          rethrow;
        } finally {
          for (final d in devices.values) {
            d.dispose();
          }
        }
      }
    });
  });
}
