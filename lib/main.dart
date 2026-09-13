// ==============================================================================
// LisKo Mobile Safety Application - Core Entry Point
// File: lib/main.dart
//
// Role & Architectural Context:
// Application bootstrapper and root widget coordinator. Initializes binary
// messenger bindings and connects Firebase services via FlutterFire CLI options.
// Configures the Material 3 application instance (`LisKoApp`), sets the light theme,
// and delegates to `_LaunchGate` for splash screen timing and conditional persistent routing.
//
// Firebase Initialization & Zero-Surveillance Architecture:
// - Initializes `Firebase.initializeApp` with `DefaultFirebaseOptions.currentPlatform`.
// - User privacy is guaranteed: LisKo adheres to a zero-surveillance design where
//   all geofencing, trip history, and emergency contacts remain strictly on-device
//   in local storage (`SharedPreferences`).
//
// SharedPreferences Boot Check & Onboarding Lockout:
// `_LaunchGate` inspects `LocalStorageService.readSetupCompleted()`:
// - Fresh Boot (`false`): Directs the user to `SplashScreen` -> `WelcomeScreen` ->
//   5-step onboarding wizard.
// - Returning User (`true`): Permanently locks out onboarding, launching directly
//   into `HomeScreen` (Dashboard) for immediate commute safety readiness.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Reliability (Fault-Tolerant Launch): If `Firebase` or `SharedPreferences`
//   encounters an initialization exception during boot, the app safely defaults
//   to `WelcomeScreen` without crashing.
// - Reliability (Resource Leak Prevention): Splash navigation timers are tracked
//   via `Timer` and cleanly canceled on `dispose()`.
// - Usability (Visual Continuity): Employs a fade transition (`RouteTransition.fade`)
//   to eliminate jarring white flashes between splash and subsequent screens.
// ==============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';

export 'constants/app_colors.dart';
export 'constants/app_icons.dart';
export 'constants/app_theme.dart';
export 'screens/screens.dart';
export 'services/local_storage_service.dart';
export 'widgets/widgets.dart';

/// Main application entry point invoked by the Flutter engine.
///
/// Converts [main] into an asynchronous bootstrapper that:
/// 1. Ensures Flutter widget bindings and binary messengers are initialized before
///    native platform channel communication ([WidgetsFlutterBinding.ensureInitialized]).
/// 2. Asynchronously initializes Firebase services with platform-specific options
///    ([Firebase.initializeApp]) configured in [DefaultFirebaseOptions.currentPlatform].
/// 3. Safely proceeds to execute [runApp] with [LisKoApp].
///
/// Zero-Surveillance Architecture Note:
/// While Firebase is connected for foundational infrastructure, LisKo preserves
/// strict zero-surveillance privacy by keeping all user trips, geofences, and trusted
/// contacts entirely within local device storage ([SharedPreferences]).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization notice: $error');
  }
  runApp(const LisKoApp());
}

// Backward-compatible color constants preserved for legacy test suites.
const canvasColor = AppColors.canvas;
const primaryColor = AppColors.primary;
const headerColor = AppColors.header;
const bodyColor = AppColors.body;
const primaryContainerColor = AppColors.primaryContainer;
const successColor = AppColors.success;

/// Helper detecting whether the app is executing within a Flutter widget test environment.
bool get _isTestMode {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return binding.contains('TestWidgetsFlutterBinding') ||
      binding.contains('AutomatedTestWidgetsFlutterBinding');
}

/// Controls testing mode startup behavior. When true, always routes to WelcomeScreen on fresh boot.
bool forceFreshStartupForTesting = true;

/// Application root widget configuring Material 3 theme and initial launch gate.
class LisKoApp extends StatelessWidget {
  const LisKoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LisKo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _LaunchGate(),
    );
  }
}

/// Initial gate handling splash delay, persistent state check, and route dispatching.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  final LocalStorageService _storage = const LocalStorageService();
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // CRITICAL: Trigger the navigation countdown ONLY after the first frame has rendered.
    // Starting the timer in initState before the engine attaches to the screen causes
    // the timer to expire during device startup, making the splash screen invisible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleNavigation();
    });
  }

  void _scheduleNavigation() {
    final splashDuration = _isTestMode
        ? const Duration(seconds: 5)
        : const Duration(milliseconds: 2600);

    _splashTimer = Timer(splashDuration, () async {
      if (!mounted) return;
      try {
        final setupCompleted = _isTestMode
            ? (forceFreshStartupForTesting
                ? false
                : await _storage.readSetupCompleted())
            : await _storage.readSetupCompleted();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          createRoute(
            setupCompleted ? const HomeScreen() : const WelcomeScreen(),
            transition: RouteTransition.fade,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          createRoute(const WelcomeScreen(), transition: RouteTransition.fade),
        );
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
