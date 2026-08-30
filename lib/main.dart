import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'screens/landing_screen.dart';
import 'services/app_services.dart';
import 'services/persistence/homebrew_persistence_service.dart';
import 'theme/app_theme.dart';

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
      logger.logFatal(error, stack, reason: 'PlatformDispatcher.instance.onError');
      return true;
    };

    // 1. Synchronously pre-hydrate SharedPreferences & run schema migrations
    // prior to rendering Frame 1 to eliminate any flash-of-unstyled-content (FOUC).
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await services.migrationService.runMigrations(prefs);
      await HomebrewPersistenceService().syncToLibraries();
    } catch (e, stackTrace) {
      logger.logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to initialize SharedPreferences / migrations / homebrew during startup',
      );
    }

    final initialSettings = prefs != null
        ? SettingsProvider.hydrateFromPrefs(prefs)
        : const AppSettings();
    final settingsProvider = SettingsProvider(initialSettings: initialSettings);

    // 2. Initialize Firebase & App Check
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.logInfo('Firebase initialized successfully.');
    } catch (e, stackTrace) {
      logger.logNonFatal(
        e,
        stackTrace,
        reason: 'Firebase initialization failed; falling back to in-memory dice room mode',
      );
    }

    try {
      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaEnterpriseProvider('6LfoR4gtAAAAAHcbNHAO3f8maSKPf7rBeWbbDdUF'),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
        );
      }
      logger.logInfo('Firebase App Check initialized successfully.');
    } catch (e, stackTrace) {
      logger.logNonFatal(
        e,
        stackTrace,
        reason: 'Firebase App Check initialization failed; falling back to standard Firestore access',
      );
    }

    runApp(
      SettingsScope(
        notifier: settingsProvider,
        child: const DangerouslyNerdy5eToolkitApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    AppServices.instance.logger.logFatal(error, stack, reason: 'runZonedGuarded uncaught zone exception');
  });
}

class DangerouslyNerdy5eToolkitApp extends StatefulWidget {
  const DangerouslyNerdy5eToolkitApp({super.key});

  @override
  State<DangerouslyNerdy5eToolkitApp> createState() => _DangerouslyNerdy5eToolkitAppState();
}

class _DangerouslyNerdy5eToolkitAppState extends State<DangerouslyNerdy5eToolkitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Immediately flush all debounced disk writes to avoid data loss on background kill
      unawaited(
        AppServices.instance.debouncedStorage.flushAll().catchError((e, stackTrace) {
          AppServices.instance.logger.logNonFatal(
            e,
            stackTrace,
            reason: 'Lifecycle flushAll failed during state: $state',
          );
        }),
      );
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
