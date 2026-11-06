import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_connection_telemetry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'fake_blob_store.dart';
import 'fake_campaign_repository.dart';

class NoOpP2pTransportPort implements IP2pTransportPort {
  @override
  TransportState get currentState => TransportState.offline;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async =>
      false;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => const Stream.empty();

  @override
  Future<void> disconnect() async {}
}

class NoOpRoomSyncOrchestrator extends Fake implements RoomSyncOrchestrator {
  bool _synchronizing = false;

  @override
  bool get isSynchronizing => _synchronizing;

  @override
  void startSynchronization() {
    _synchronizing = true;
  }

  @override
  void stopSynchronization() {
    _synchronizing = false;
  }

  @override
  Stream<RoomConnectionTelemetry> watchTelemetry() => const Stream.empty();

  @override
  RoomConnectionTelemetry get currentTelemetry =>
      const RoomConnectionTelemetry(state: TransportState.offline, peerCount: 0);
}

class NoOpRoomSessionStarter extends Fake implements RoomSessionStarter {
  final RoomSyncOrchestrator? _orchestrator;
  NoOpRoomSessionStarter([this._orchestrator]);

  @override
  void start() {
    _orchestrator?.startSynchronization();
  }
}

/// Shared test helper for tests that register collaborators by hand instead of
/// running [initServiceLocator]. Calls the same public `configure` and
/// `...ForTesting` reset methods on the services.
void configureTestServices({
  ICampaignRepository? repository,
  ReplicaId? replicaId,
  StatefulHlcClock? clock,
  CampaignRegistryService? registryService,
  BlobStorePort? blobStore,
  BlobStorePort Function()? blobStoreProvider,
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  final effectiveRepo = repository ?? FakeCampaignRepository();
  final effectiveReplicaId = replicaId ?? ReplicaId('test_replica');
  final effectiveClock =
      clock ?? StatefulHlcClock(replicaId: effectiveReplicaId);
  final effectiveRegistry =
      registryService ?? CampaignRegistryService.newInstance();
  final effectiveBlobStoreProvider = blobStoreProvider ??
      (() {
        final store = blobStore ?? FakeBlobStore();
        return () => store;
      })();

  CampaignProfileService.configure(
    repository: effectiveRepo,
    clock: effectiveClock,
    replicaId: effectiveReplicaId,
    registryService: effectiveRegistry,
    blobStoreProvider: effectiveBlobStoreProvider,
  );
  DmBackupService.configure(clock: effectiveClock);
  CampaignStorageMigration.configure(
    repository: effectiveRepo,
    clock: effectiveClock,
    replicaId: effectiveReplicaId,
    registryService: effectiveRegistry,
  );
  configureTestDiceRoomService(
    transport: transport,
    orchestrator: orchestrator,
    sessionStarter: sessionStarter,
  );
}

/// Configures [CampaignProfileService] singleton with its runtime collaborators.
void configureTestCampaignProfileService({
  ICampaignRepository? repository,
  ReplicaId? replicaId,
  StatefulHlcClock? clock,
  CampaignRegistryService? registryService,
  BlobStorePort? blobStore,
  BlobStorePort Function()? blobStoreProvider,
}) {
  final effectiveRepo = repository ?? FakeCampaignRepository();
  final effectiveReplicaId = replicaId ?? ReplicaId('test_replica');
  final effectiveClock =
      clock ?? StatefulHlcClock(replicaId: effectiveReplicaId);
  final effectiveRegistry =
      registryService ?? CampaignRegistryService.newInstance();
  final effectiveBlobStoreProvider = blobStoreProvider ??
      (() {
        final store = blobStore ?? FakeBlobStore();
        return () => store;
      })();
  CampaignProfileService.configure(
    repository: effectiveRepo,
    clock: effectiveClock,
    replicaId: effectiveReplicaId,
    registryService: effectiveRegistry,
    blobStoreProvider: effectiveBlobStoreProvider,
  );
}

/// Configures [DmBackupService] singleton with its runtime collaborator.
void configureTestDmBackupService({
  StatefulHlcClock? clock,
  ReplicaId? replicaId,
}) {
  final effectiveReplicaId = replicaId ?? ReplicaId('test_replica');
  final effectiveClock =
      clock ?? StatefulHlcClock(replicaId: effectiveReplicaId);
  DmBackupService.configure(clock: effectiveClock);
}

/// Binds an existing [DiceRoomService] instance with test collaborators.
void bindTestDiceRoomInstance(
  DiceRoomService instance, {
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  final effectiveTransport = transport ?? NoOpP2pTransportPort();
  final effectiveOrchestrator = orchestrator ?? NoOpRoomSyncOrchestrator();
  final effectiveStarter =
      sessionStarter ?? NoOpRoomSessionStarter(effectiveOrchestrator);
  instance.bind(
    transport: effectiveTransport,
    orchestrator: effectiveOrchestrator,
    sessionStarter: effectiveStarter,
  );
}

/// Configures [DiceRoomService] singleton with its runtime collaborators.
void configureTestDiceRoomService({
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  final effectiveTransport = transport ?? NoOpP2pTransportPort();
  final effectiveOrchestrator = orchestrator ?? NoOpRoomSyncOrchestrator();
  final effectiveStarter =
      sessionStarter ?? NoOpRoomSessionStarter(effectiveOrchestrator);
  DiceRoomService.configure(
    transport: effectiveTransport,
    orchestrator: effectiveOrchestrator,
    sessionStarter: effectiveStarter,
  );
}

/// Creates a bound [DiceRoomService.newInstance] for isolated tests.
DiceRoomService createBoundTestDiceRoomService({
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  final effectiveTransport = transport ?? NoOpP2pTransportPort();
  final effectiveOrchestrator = orchestrator ?? NoOpRoomSyncOrchestrator();
  final effectiveStarter =
      sessionStarter ?? NoOpRoomSessionStarter(effectiveOrchestrator);
  return DiceRoomService.newInstance()
    ..bind(
      transport: effectiveTransport,
      orchestrator: effectiveOrchestrator,
      sessionStarter: effectiveStarter,
    );
}

/// Resets all singleton service test bindings via their `@visibleForTesting`
/// reset methods.
void resetTestServices() {
  CampaignProfileService.fullResetForTesting();
  DmBackupService.resetForTesting();
  DiceRoomService.resetForTesting();
  CampaignStorageMigration.resetForTesting();
}
