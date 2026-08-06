import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization info/warning: $e');
  }
  runApp(const DangerouslyNerdy5eToolkitApp());
}

class DangerouslyNerdy5eToolkitApp extends StatelessWidget {
  const DangerouslyNerdy5eToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DangerouslyNerdy 5e Toolkit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14121E),
        primaryColor: Colors.amber,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF1E1B2E),
        ),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}
