import 'package:uuid/uuid.dart';
import '../../application/services/cascading_transport_router.dart';
import '../../application/services/clock_sync_service.dart';
import '../../application/services/combat_encounter_service.dart';
import '../../application/services/room_state_reconciliation_service.dart';
import '../../application/services/room_sync_orchestrator.dart';
import '../../application/storage/storage_durability_coordinator.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:vtt_engine_core/storage/ports/i_campaign_snapshot_serializer_port.dart';
import 'package:vtt_engine_core/storage/ports/i_physical_snapshot_port.dart';
import 'package:vtt_engine_core/storage/ports/i_storage_durability_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import '../../services/dice_room_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../adapters/p2p/firebase_fallback_adapter.dart';
import '../modules/dnd5e/dnd_5e_animated_object_adapter.dart';
import '../adapters/p2p/firebase_signaling_adapter.dart';
import '../adapters/p2p/local_wifi_adapter.dart';
import '../adapters/p2p/webrtc_mesh_adapter.dart';
import '../adapters/storage/campaign_snapshot_serializer_adapter.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import '../modules/dnd5e/dnd_5e_combat_resolver.dart';
import '../adapters/system_network_time_port.dart';
import '../mappers/room_sync_payload_mapper.dart';
import '../repositories/local_campaign_repository.dart';
import '../repositories/local_character_repository.dart';
import '../storage/physical_snapshot_adapter.dart';
import '../storage/storage_durability_adapter.dart';

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
}) async {
  final db = databaseService ?? AppDatabaseService.instance;
  sl.registerSingleton<AppDatabaseService>(db);

  final charRepo = characterRepo ?? LocalCharacterRepository(db: db);
  sl.registerSingleton<ICharacterRepository>(charRepo);

  final campRepo =
      campaignRepo ?? LocalCampaignRepository(db: db, characterRepo: charRepo);
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
  CampaignSnapshotSerializerAdapter.registerDefault();

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

  sl.registerLazySingleton<ICombatResolver>(() => const Dnd5eCombatResolver());

  final localNodeId = const Uuid().v4();

  sl.registerLazySingleton<CombatEncounterService>(() => CombatEncounterService(
        characterRepo: sl<ICharacterRepository>(),
        campaignRepo: sl<ICampaignRepository>(),
        combatResolver: sl<ICombatResolver>(),
        networkTimeProvider: () => sl<ClockSyncService>().currentNetworkTimeMs,
        localNodeId: localNodeId,
      ));

  sl.registerLazySingleton<RoomStateReconciliationService>(
    () => RoomStateReconciliationService(
      networkTimeProvider: () => sl<ClockSyncService>().currentNetworkTimeMs,
    ),
  );

  sl.registerLazySingleton<IRoomSyncPayloadPort>(
      () => const RoomSyncPayloadMapper());
  IRoomSyncPayloadPort.defaultProvider = () => sl<IRoomSyncPayloadPort>();

  // Injected ruleset baseline provider for animated objects
  AnimatedObjectStats.defaultProvider = Dnd5eAnimatedObjectAdapter.getStats;

  if (p2pTransport != null) {
    sl.registerSingleton<IP2pTransportPort>(p2pTransport);
  } else {
    sl.registerLazySingleton<CascadingTransportRouter>(() =>
        CascadingTransportRouter(
          localWifiAdapter: LocalWifiTransportAdapter(),
          webRtcAdapter:
              WebRtcMeshAdapter(signalingAdapter: FirebaseSignalingAdapter()),
          firebaseFallbackAdapter: FirebaseFallbackAdapter(),
        ));
    sl.registerLazySingleton<IP2pTransportPort>(
        () => sl<CascadingTransportRouter>());
  }

  sl.registerLazySingleton<RoomSyncOrchestrator>(() => RoomSyncOrchestrator(
        transportPort: sl<IP2pTransportPort>(),
        campaignRepo: sl<ICampaignRepository>(),
        reconciliationService: sl<RoomStateReconciliationService>(),
        clockSyncService: sl<ClockSyncService>(),
        diceRoomService: DiceRoomService(),
        payloadMapper: sl<IRoomSyncPayloadPort>(),
        localNodeId: localNodeId,
      ));
}
