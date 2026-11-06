import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_store_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_session_starter.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/campaign_storage_migration.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'fake_blob_store.dart';

/// Shared test helper for tests that register collaborators by hand instead of
/// running [initServiceLocator]. Calls the same public `configure` and
/// `...ForTesting` reset methods on the services.
void configureTestServices({
  required ICampaignRepository repository,
  ReplicaId? replicaId,
  StatefulHlcClock? clock,
  CampaignRegistryService? registryService,
  BlobStorePort? blobStore,
  BlobStorePort Function()? blobStoreProvider,
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  final effectiveReplicaId = replicaId ?? ReplicaId('test_replica');
  final effectiveClock =
      clock ?? StatefulHlcClock(replicaId: effectiveReplicaId);
  final effectiveRegistry = registryService ?? CampaignRegistryService();
  final effectiveBlobStoreProvider = blobStoreProvider ??
      (() {
        final store = blobStore ?? FakeBlobStore();
        return () => store;
      })();

  CampaignProfileService.configure(
    repository: repository,
    clock: effectiveClock,
    replicaId: effectiveReplicaId,
    registryService: effectiveRegistry,
    blobStoreProvider: effectiveBlobStoreProvider,
  );
  DmBackupService.configure(clock: effectiveClock);
  CampaignStorageMigration.configure(
    repository: repository,
    clock: effectiveClock,
    replicaId: effectiveReplicaId,
    registryService: effectiveRegistry,
  );
  if (transport != null || orchestrator != null || sessionStarter != null) {
    DiceRoomService.configure(
      transport: transport,
      orchestrator: orchestrator,
      sessionStarter: sessionStarter,
    );
  }
}

/// Configures [DiceRoomService] singleton with its runtime collaborators.
void configureTestDiceRoomService({
  IP2pTransportPort? transport,
  RoomSyncOrchestrator? orchestrator,
  RoomSessionStarter? sessionStarter,
}) {
  DiceRoomService.configure(
    transport: transport,
    orchestrator: orchestrator,
    sessionStarter: sessionStarter,
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

