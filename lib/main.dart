import 'dart:async';
import 'dart:ui';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'infrastructure/di/injection_container.dart';
import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'screens/landing_screen.dart';
import 'services/app_services.dart';
import 'services/logging_service.dart';
import 'services/persistence/app_database_service.dart';
import 'services/persistence/homebrew_persistence_service.dart';
import 'services/persistence/web_lifecycle.dart';
import 'application/storage/storage_durability_coordinator.dart';
import 'package:vtt_engine_core/storage/models/engine_profile.dart';
import 'infrastructure/storage/storage_durability_adapter.dart';
import 'infrastructure/repositories/campaign_storage_migration.dart';
import 'services/dice_room_service.dart';
import 'theme/app_theme.dart';

/// Restores persisted application startup state including homebrew libraries and remembered dice room session.
Future<void> restoreApplicationStartupState({
  HomebrewPersistenceService? homebrewService,
  DiceRoomService? diceRoomService,
}) async {
  await (homebrewService ?? HomebrewPersistenceService()).syncToLibraries();
  await (diceRoomService ?? DiceRoomService()).restorePersistedSession();
}

enum StartupStorageStatus { success, unavailable }

/// Result of trying to open durable storage during startup.
class StartupStorageResult {
  final StartupStorageStatus status;
  final StorageUnavailableException? error;

  const StartupStorageResult.success()
      : status = StartupStorageStatus.success,
        error = null;

  const StartupStorageResult.unavailable(this.error)
      : status = StartupStorageStatus.unavailable;

  bool get isSuccess => status == StartupStorageStatus.success;
}

/// Attempts to open durable storage, returning [StartupStorageResult.unavailable] if storage cannot be opened.
Future<StartupStorageResult> openStorage(AppDatabaseService db) async {
  try {
    await db.init();
    return const StartupStorageResult.success();
  } on StorageUnavailableException catch (e) {
    return StartupStorageResult.unavailable(e);
  } catch (e, st) {
    return StartupStorageResult.unavailable(StorageUnavailableException(e, st));
  }
}

/// Full-screen view shown when application startup fails after storage has opened.
class StartupFailedPage extends StatelessWidget {
  final Object error;

  const StartupFailedPage({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final errorType = error.runtimeType.toString();
    final errorMessage = switch (error) {
      StateError e => e.message,
      ArgumentError e => e.message?.toString() ?? '',
      _ => error.toString(),
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Color(0xFFE57373),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "The app couldn't start",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong while loading your saved data. Your data has not been deleted. Reload the page to try again. If this keeps happening, copy the details below and report it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            errorType,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF9A9A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            errorMessage,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: Color(0xFFEF9A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<Widget> completeNormalStartup(
  AppServices services,
  LoggingService logger, {
  @visibleForTesting Future<void> Function()? initServices,
  @visibleForTesting Future<void> Function()? runMigration,
  @visibleForTesting Future<void> Function()? setupFirebase,
}) async {
  try {
    await (initServices ?? initServiceLocator)();
    await (runMigration ?? CampaignStorageMigration.runStartupMigration)();
    try {
      await sl<StorageDurabilityCoordinator>().executeSilentPreflight();
    } catch (e, st) {
      logger.logNonFatal(e, st,
          reason: 'StorageDurabilityCoordinator silent preflight failed');
    }
    setupWebLifecycle(services.debouncedStorage);

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await services.migrationService.runMigrations(prefs);
      await restoreApplicationStartupState();
    } catch (e, stackTrace) {
      logger.logNonFatal(
        e,
        stackTrace,
        reason:
            'Failed to initialize SharedPreferences / migrations / startup state during startup',
      );
    }

    final initialSettings = prefs != null
        ? SettingsProvider.hydrateFromPrefs(prefs)
        : const AppSettings();
    final settingsProvider = SettingsProvider(initialSettings: initialSettings);

    if (setupFirebase != null) {
      try {
        await setupFirebase();
      } catch (e, stackTrace) {
        logger.logNonFatal(
          e,
          stackTrace,
          reason:
              'Firebase initialization failed; falling back to in-memory dice room mode',
        );
      }
    } else {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        logger.logInfo('Firebase initialized successfully.');
      } catch (e, stackTrace) {
        logger.logNonFatal(
          e,
          stackTrace,
          reason:
              'Firebase initialization failed; falling back to in-memory dice room mode',
        );
      }

      try {
        if (kIsWeb) {
          const recaptchaSiteKey = String.fromEnvironment(
            'RECAPTCHA_ENTERPRISE_KEY',
            defaultValue: '6LfoR4gtAAAAAHcbNHAO3f8maSKPf7rBeWbbDdUF',
          );
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaEnterpriseProvider(recaptchaSiteKey),
          );
        } else {
          await FirebaseAppCheck.instance.activate(
            providerAndroid: const AndroidPlayIntegrityProvider(),
          );
        }
        logger.logInfo('Firebase App Check initialized successfully.');
      } catch (e, stackTrace) {
        logger.logNonFatal(
          e,
          stackTrace,
          reason:
              'Firebase App Check initialization failed; falling back to standard Firestore access',
        );
      }
    }

    return SettingsScope(
      notifier: settingsProvider,
      child: const DangerouslyNerdy5eToolkitApp(),
    );
  } catch (error, stack) {
    logger.logFatal(
      error,
      stack,
      reason: 'completeNormalStartup failed',
    );
    return StartupFailedPage(error: error);
  }
}

/// Full-screen view shown when durable browser storage cannot be opened.
class StorageUnavailablePage extends StatefulWidget {
  final AppDatabaseService databaseService;
  final Future<void> Function() onRetrySuccess;

  const StorageUnavailablePage({
    super.key,
    required this.databaseService,
    required this.onRetrySuccess,
  });

  @override
  State<StorageUnavailablePage> createState() => _StorageUnavailablePageState();
}

class _StorageUnavailablePageState extends State<StorageUnavailablePage> {
  bool _isRetrying = false;
  String? _errorMessage;

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    final result = await openStorage(widget.databaseService);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isRetrying = false;
      });
      await widget.onRetrySuccess();
    } else {
      setState(() {
        _isRetrying = false;
        _errorMessage =
            'Storage is still unavailable. Please check your browser settings and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 64,
                    color: Color(0xFFE57373),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Storage unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The browser would not let the app save data, so nothing typed now would be kept.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Common causes:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Private browsing or incognito mode blocking local storage\n'
                          '• Storage or cookies blocked for this site in site settings\n'
                          '• Disk full or storage quota exceeded',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('storage_unavailable_try_again_button'),
                      onPressed: _isRetrying ? null : _handleRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Try again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final services = AppServices.instance;
    final logger = services.logger;

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.logFatal(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'FlutterError.onError: ${details.context}',
      );
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.logFatal(error, stack,
          reason: 'PlatformDispatcher.instance.onError');
      return true;
    };

    // 0. Storage durability silent preflight (Must complete before initializing IndexedDB / Hive connection pools)
    try {
      const storagePort = StorageDurabilityAdapter();
      final preflightProfile = storagePort.detectProfile();
      if (preflightProfile.engine == BrowserEngine.chromium ||
          ((preflightProfile.engine == BrowserEngine.webkit ||
                  preflightProfile.os == PlatformOs.ios) &&
              preflightProfile.isStandalonePwa)) {
        await storagePort.requestPersistence();
      }
    } catch (e, stackTrace) {
      logger.logNonFatal(
        e,
        stackTrace,
        reason:
            'Storage durability silent preflight failed during early startup',
      );
    }

    // 1. Initialize local NoSQL database. If unavailable, do not start normal app or call initServiceLocator.
    final storageResult = await openStorage(AppDatabaseService.instance);
    if (!storageResult.isSuccess) {
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: StorageUnavailablePage(
            databaseService: AppDatabaseService.instance,
            onRetrySuccess: () async {
              runApp(await completeNormalStartup(services, logger));
            },
          ),
        ),
      );
      return;
    }

    runApp(await completeNormalStartup(services, logger));
  }, (Object error, StackTrace stack) {
    AppServices.instance.logger.logFatal(error, stack,
        reason: 'runZonedGuarded uncaught zone exception');
  });
}

class DangerouslyNerdy5eToolkitApp extends StatefulWidget {
  const DangerouslyNerdy5eToolkitApp({super.key});

  @override
  State<DangerouslyNerdy5eToolkitApp> createState() =>
      _DangerouslyNerdy5eToolkitAppState();
}

class _DangerouslyNerdy5eToolkitAppState
    extends State<DangerouslyNerdy5eToolkitApp> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(
      onPause: _flushStorage,
      onHide: _flushStorage,
      onDetach: _flushStorage,
      onExitRequested: () async {
        await _flushStorage();
        return AppExitResponse.exit;
      },
    );
  }

  Future<void> _flushStorage() async {
    try {
      await AppServices.instance.debouncedStorage.flushAll();
    } catch (e, stackTrace) {
      AppServices.instance.logger.logNonFatal(
        e,
        stackTrace,
        reason: 'Storage flush failed during lifecycle state change',
      );
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _flushStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.of(context);
    final s = settingsProvider.settings;

    return MaterialApp(
      title: 'DangerouslyNerdy 5e Toolkit',
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: AppTheme.buildTheme(
        brightness: Brightness.light,
        accent: s.fantasyAccent,
      ),
      darkTheme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        accent: s.fantasyAccent,
        oledPitchBlack: s.oledPitchBlack,
      ),
      home: const LandingScreen(),
    );
  }
}
