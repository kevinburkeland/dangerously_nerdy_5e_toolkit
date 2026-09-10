import '../../application/services/cascading_transport_router.dart';
import '../../application/services/clock_sync_service.dart';
import '../../application/services/combat_encounter_service.dart';
import '../../application/services/room_state_reconciliation_service.dart';
import '../../application/services/room_sync_orchestrator.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../domain/ports/i_character_repository.dart';
import '../../domain/ports/i_network_time_port.dart';
import '../../domain/ports/i_p2p_transport_port.dart';
import '../../services/dice_room_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../adapters/p2p/firebase_fallback_adapter.dart';
import '../adapters/p2p/firebase_signaling_adapter.dart';
import '../adapters/p2p/webrtc_mesh_adapter.dart';
import '../adapters/system_network_time_port.dart';
import '../repositories/local_campaign_repository.dart';
import '../repositories/local_character_repository.dart';

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
  bool isRegistered<T>() => _singletons.containsKey(T) || _factories.containsKey(T);

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
}) async {
  final db = databaseService ?? AppDatabaseService.instance;
  sl.registerSingleton<AppDatabaseService>(db);

  final charRepo = characterRepo ?? LocalCharacterRepository(db: db);
  sl.registerSingleton<ICharacterRepository>(charRepo);

  final campRepo = campaignRepo ?? LocalCampaignRepository(db: db, characterRepo: charRepo);
  sl.registerSingleton<ICampaignRepository>(campRepo);

  sl.registerLazySingleton<CombatEncounterService>(() => CombatEncounterService(
        characterRepo: sl<ICharacterRepository>(),
        campaignRepo: sl<ICampaignRepository>(),
      ));

  sl.registerLazySingleton<RoomStateReconciliationService>(() => RoomStateReconciliationService());

  sl.registerLazySingleton<INetworkTimePort>(() => const SystemNetworkTimePort());

  sl.registerLazySingleton<ClockSyncService>(() => ClockSyncService(
        networkTimePort: sl<INetworkTimePort>(),
      ));

  if (p2pTransport != null) {
    sl.registerSingleton<IP2pTransportPort>(p2pTransport);
  } else {
    sl.registerLazySingleton<CascadingTransportRouter>(() => CascadingTransportRouter(
          webRtcAdapter: WebRtcMeshAdapter(signalingAdapter: FirebaseSignalingAdapter()),
          firebaseFallbackAdapter: FirebaseFallbackAdapter(),
        ));
    sl.registerLazySingleton<IP2pTransportPort>(() => sl<CascadingTransportRouter>());
  }

  sl.registerLazySingleton<RoomSyncOrchestrator>(() => RoomSyncOrchestrator(
        transportPort: sl<IP2pTransportPort>(),
        campaignRepo: sl<ICampaignRepository>(),
        reconciliationService: sl<RoomStateReconciliationService>(),
        clockSyncService: sl<ClockSyncService>(),
        diceRoomService: DiceRoomService(),
      ));
}
