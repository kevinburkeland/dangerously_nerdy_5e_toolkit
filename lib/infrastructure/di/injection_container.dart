import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../services/party/party_room_service.dart';
import '../../application/services/party_room_service.dart' as app_party;
import '../../application/services/homebrew_import_orchestrator.dart';
import '../storage/local_replica_identity_store.dart';
import '../../application/services/cascading_transport_router.dart';
import '../../application/services/clock_sync_service.dart';
import '../../application/services/combat_encounter_service.dart';
import '../../application/services/room_state_reconciliation_service.dart';
import '../../application/services/room_sync_orchestrator.dart';
import '../../application/services/room_session_starter.dart';
import '../../application/storage/storage_durability_coordinator.dart';
import '../../services/dice_room_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../../services/persistence/campaign_profile_service.dart';
import '../adapters/p2p/firebase_fallback_adapter.dart';
import '../adapters/p2p/firebase_signaling_adapter.dart';
import '../adapters/p2p/local_wifi_adapter.dart';
import '../adapters/p2p/webrtc_mesh_adapter.dart';
import '../adapters/storage/campaign_snapshot_serializer_adapter.dart';
import '../adapters/storage/firestore_room_document_adapter.dart';
import '../../application/services/room_document_port.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../modules/dnd5e/dnd5e_ruleset_catalog.dart';
import '../adapters/remote/github_ingestor_adapter.dart';
import '../adapters/system_network_time_port.dart';
import '../mappers/room_sync_payload_mapper.dart';
import '../repositories/local_campaign_repository.dart';
import '../repositories/local_character_repository.dart';
import '../storage/physical_snapshot_adapter.dart';
import '../storage/storage_durability_adapter.dart';
import '../../application/blob/blob_channel_port.dart';
import '../../application/blob/blob_store_port.dart';
import '../../application/blob/blob_transfer_service.dart';
import '../../application/map/active_map_controller.dart';
import '../../application/map/map_image_intake_port.dart';
import '../../application/map/map_intake_service.dart';
import '../../application/map/map_grid_service.dart';
import '../../application/map/map_token_service.dart';
import 'package:uuid/uuid.dart';
import '../map/map_image_intake_adapter.dart';
import '../storage/blob_store_adapter.dart';

/// Lightweight, type-safe Service Locator for Dependency Injection.
/// Eradicates singleton constructors in domain/infrastructure repositories
/// while providing zero-dependency IoC resolution.
class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic> _singletons = {};


  /// Registers a factory that is resolved once into a cached singleton on first access.
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Registers an existing instance as a singleton.
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
  }

  /// Registers a factory that creates a fresh instance on every resolution.
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Resolves an instance of type [T].
  T get<T>() {
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!();
      _singletons[T] = instance;
      return instance as T;
    }
    throw StateError('Type $T is not registered in InjectionContainer.');
  }

  /// Callable syntax: `sl<T>()`
  T call<T>() => get<T>();

  /// Checks if a type is registered.
  bool isRegistered<T>() =>
      _singletons.containsKey(T) || _factories.containsKey(T);

  /// Unregisters a type if registered.
  void unregister<T>() {
    _singletons.remove(T);
    _factories.remove(T);
  }

  /// Clears all registrations (primarily used in test teardowns).
  void reset() {
    _factories.clear();
    _singletons.clear();
  }
}

/// Global Service Locator instance.
final sl = InjectionContainer();

/// Bootstraps core repositories, ports, and application services into the container.
Future<void> initServiceLocator({
  AppDatabaseService? databaseService,
  ICharacterRepository? characterRepo,
  ICampaignRepository? campaignRepo,
  IP2pTransportPort? p2pTransport,
  IStorageDurabilityPort? storageDurabilityPort,
  IPhysicalSnapshotPort? physicalSnapshotPort,
  IRoomDocumentPort? roomDocumentPort,
  ReplicaId? replicaId,
  BlobStorePort? blobStore,
  BlobChannelPort? blobChannel,
  MapImageIntakePort? mapImageIntake,
}) async {
  installRulesetCatalog();

  final db = databaseService ?? AppDatabaseService.instance;
  sl.registerSingleton<AppDatabaseService>(db);

  final resolvedReplicaId = replicaId ??
      LocalReplicaIdentityStore.createRuntimeReplicaId();
  sl.registerSingleton<ReplicaId>(resolvedReplicaId);

  final hlcClock = StatefulHlcClock(
    replicaId: resolvedReplicaId,
    timeProvider: () => sl.isRegistered<ClockSyncService>()
        ? sl<ClockSyncService>().currentNetworkTimeMs
        : DateTime.now().toUtc().millisecondsSinceEpoch,
  );
  sl.registerSingleton<StatefulHlcClock>(hlcClock);

  CampaignProfileService(replicaId: resolvedReplicaId, clock: hlcClock);

  final charRepo = characterRepo ?? LocalCharacterRepository(db: db);
  sl.registerSingleton<ICharacterRepository>(charRepo);

  final campRepo = campaignRepo ??
      LocalCampaignRepository(
        db: db,
        characterRepo: charRepo,
        replicaId: resolvedReplicaId,
        clock: hlcClock,
      );
  sl.registerSingleton<ICampaignRepository>(campRepo);

  sl.registerLazySingleton<IStorageDurabilityPort>(
    () => storageDurabilityPort ?? const StorageDurabilityAdapter(),
  );

  sl.registerLazySingleton<IPhysicalSnapshotPort>(
    () => physicalSnapshotPort ?? const PhysicalSnapshotAdapter(),
  );

  sl.registerLazySingleton<ICampaignSnapshotSerializerPort>(
    () => const CampaignSnapshotSerializerAdapter(),
  );
  sl.registerLazySingleton<StorageDurabilityCoordinator>(
    () => StorageDurabilityCoordinator(
      storagePort: sl<IStorageDurabilityPort>(),
      snapshotPort: sl<IPhysicalSnapshotPort>(),
      campaignRepo: sl<ICampaignRepository>(),
      serializer: sl<ICampaignSnapshotSerializerPort>(),
    ),
  );

  sl.registerLazySingleton<INetworkTimePort>(
      () => const SystemNetworkTimePort());

  sl.registerLazySingleton<ClockSyncService>(() => ClockSyncService(
        networkTimePort: sl<INetworkTimePort>(),
      ));

  final roomDocPort =
      roomDocumentPort ?? const FirestoreRoomDocumentAdapter();
  sl.registerSingleton<IRoomDocumentPort>(roomDocPort);

  sl.registerLazySingleton<ICombatResolver>(() => const Dnd5eCombatResolver());

  sl.registerLazySingleton<CombatEncounterService>(() => CombatEncounterService(
        characterRepo: sl<ICharacterRepository>(),
        campaignRepo: sl<ICampaignRepository>(),
        combatResolver: sl<ICombatResolver>(),
        networkTimeProvider: () => sl<ClockSyncService>().currentNetworkTimeMs,
        replicaId: resolvedReplicaId,
        clock: sl<StatefulHlcClock>(),
      ));

  final partyRoomService = PartyRoomService(
    replicaId: resolvedReplicaId,
    clock: sl<StatefulHlcClock>(),
    roomDocumentPort: roomDocPort,
  );
  sl.registerSingleton<PartyRoomService>(partyRoomService);

  sl.registerLazySingleton<app_party.PartyRoomService>(
    () => app_party.PartyRoomService(
      replicaId: resolvedReplicaId,
      clock: sl<StatefulHlcClock>(),
    ),
  );

  sl.registerLazySingleton<IGithubIngestorPort>(
    () => GithubIngestorAdapter(),
  );

  sl.registerLazySingleton<HomebrewImportOrchestrator>(
    () => HomebrewImportOrchestrator(
      ingestorPort: sl<IGithubIngestorPort>(),
      nodeId: resolvedReplicaId.value,
      clock: sl<StatefulHlcClock>(),
    ),
  );

  sl.registerLazySingleton<RoomStateReconciliationService>(
    () => RoomStateReconciliationService(
      networkTimeProvider: () => sl<ClockSyncService>().currentNetworkTimeMs,
    ),
  );

  sl.registerLazySingleton<IRoomSyncPayloadPort>(
      () => const RoomSyncPayloadMapper());

  if (blobChannel != null) {
    sl.registerSingleton<BlobChannelPort>(blobChannel);
  }

  if (p2pTransport != null) {
    sl.registerSingleton<IP2pTransportPort>(p2pTransport);
  } else {
    final webRtcAdapter =
        WebRtcMeshAdapter(signalingAdapter: FirebaseSignalingAdapter());
    sl.registerSingleton<WebRtcMeshAdapter>(webRtcAdapter);
    if (blobChannel == null) {
      sl.registerLazySingleton<BlobChannelPort>(() => sl<WebRtcMeshAdapter>());
    }
    sl.registerLazySingleton<CascadingTransportRouter>(() =>
        CascadingTransportRouter(
          localWifiAdapter: LocalWifiTransportAdapter(),
          webRtcAdapter: sl<WebRtcMeshAdapter>(),
          firebaseFallbackAdapter: FirebaseFallbackAdapter(),
        ));
    sl.registerLazySingleton<IP2pTransportPort>(
        () => sl<CascadingTransportRouter>());
  }

  sl.registerLazySingleton<BlobStorePort>(
    // ignore: prefer_const_constructors
    () => blobStore ?? BlobStoreAdapter(),
  );

  sl.registerLazySingleton<MapImageIntakePort>(
    () => mapImageIntake ?? const MapImageIntakeAdapter(),
  );

  sl.registerLazySingleton<BlobTransferService>(
    () => BlobTransferService(
      channel: sl<BlobChannelPort>(),
      store: sl<BlobStorePort>(),
      servableRefs: () => activeMapServableRefs(sl<ICampaignRepository>()),
    ),
  );

  sl.registerLazySingleton<MapIntakeService>(
    () => MapIntakeService(
      intake: sl<MapImageIntakePort>(),
      store: sl<BlobStorePort>(),
      campaignRepo: sl<ICampaignRepository>(),
      clock: sl<StatefulHlcClock>(),
    ),
  );

  sl.registerLazySingleton<MapGridService>(
    () => MapGridService(
      campaignRepo: sl<ICampaignRepository>(),
      clock: sl<StatefulHlcClock>(),
    ),
  );

  sl.registerLazySingleton<MapTokenService>(
    () => MapTokenService(
      campaignRepo: sl<ICampaignRepository>(),
      clock: sl<StatefulHlcClock>(),
      newTokenId: () => 'tok_${const Uuid().v4().replaceAll('-', '')}',
    ),
  );

  sl.registerLazySingleton<ActiveMapController>(
    () => ActiveMapController(
      campaignRepo: sl<ICampaignRepository>(),
      transfer: sl<BlobTransferService>(),
      store: sl<BlobStorePort>(),
      channel: sl<BlobChannelPort>(),
      transportState: () => sl<IP2pTransportPort>().currentState,
    ),
  );

  sl.registerLazySingleton<RoomSyncOrchestrator>(() => RoomSyncOrchestrator(
        transportPort: sl<IP2pTransportPort>(),
        campaignRepo: sl<ICampaignRepository>(),
        reconciliationService: sl<RoomStateReconciliationService>(),
        clockSyncService: sl<ClockSyncService>(),
        diceRoomService: DiceRoomService(),
        payloadMapper: sl<IRoomSyncPayloadPort>(),
        replicaId: resolvedReplicaId,
        clock: sl<StatefulHlcClock>(),
      ));

  sl.registerLazySingleton<RoomSessionStarter>(() => RoomSessionStarter(
        orchestrator: sl<RoomSyncOrchestrator>(),
        maps: sl<ActiveMapController>(),
      ));
}
