import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'screens/landing_screen.dart';
import 'services/logging_service.dart';
import 'theme/app_theme.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final logger = LoggingService();

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

    final settingsProvider = SettingsProvider();

    runApp(
      SettingsScope(
        notifier: settingsProvider,
        child: const DangerouslyNerdy5eToolkitApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    LoggingService().logFatal(error, stack, reason: 'runZonedGuarded uncaught zone exception');
  });
}

class DangerouslyNerdy5eToolkitApp extends StatelessWidget {
  const DangerouslyNerdy5eToolkitApp({super.key});

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
