import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/landing_screen.dart';
import 'services/logging_service.dart';
import 'theme/app_theme.dart';

void main() {
  // Global Zone Error Wrapper for uncaught asynchronous exceptions
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final logger = LoggingService();

    // 1. Intercept Flutter Framework UI Errors (Widget Build/Render crashes)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.logFatal(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'FlutterError.onError: ${details.context}',
      );
    };

    // 2. Intercept Asynchronous Platform Engine Errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.logFatal(error, stack, reason: 'PlatformDispatcher.instance.onError');
      return true; // Prevents crash bubbling if safely handled
    };

    // Initialize Firebase Services
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.logInfo('Firebase initialized successfully.');
    } catch (e) {
      logger.logWarning('Firebase initialization warning', e);
    }

    runApp(const DangerouslyNerdy5eToolkitApp());
  }, (Object error, StackTrace stack) {
    // 3. Intercept Uncaught Async Zone Errors
    LoggingService().logFatal(error, stack, reason: 'runZonedGuarded uncaught zone exception');
  });
}

class DangerouslyNerdy5eToolkitApp extends StatelessWidget {
  const DangerouslyNerdy5eToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DangerouslyNerdy 5e Toolkit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LandingScreen(),
    );
  }
}
