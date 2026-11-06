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

