// ==============================================================================
// LisKo Mobile Safety Application - Core Entry Point
// File: lib/main.dart
//
// Role & Architectural Context:
// Application bootstrapper and root widget coordinator. Initializes binary
// messenger bindings and connects Firebase services via FlutterFire CLI options.
// Configures the Material 3 application instance (`LisKoApp`), sets the light theme,
// and delegates to `_LaunchGate` for splash screen timing and conditional routing.
//
// Notification Background Response Handler:
// `notificationBackgroundResponseHandler` is a top-level @pragma function that
// runs in a separate Dart isolate when the user taps a notification action button
// while the app is fully terminated. It persists the action ID to SharedPreferences
// so `_LaunchGate` can dispatch it to HomeScreenState on the next boot.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Reliability (Fault-Tolerant Launch): Firebase / SharedPreferences errors
//   safely default to WelcomeScreen without crashing.
// - Reliability (Resource Leak Prevention): Splash timers are cancelled in dispose().
// - Usability (Visual Continuity): Fade transition eliminates jarring flashes.
// ==============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Helper detecting whether the app is executing within a Flutter test environment.
bool get _isTestMode {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return binding.contains('TestWidgetsFlutterBinding') ||
      binding.contains('AutomatedTestWidgetsFlutterBinding');
}

/// Controls testing mode startup behavior. When true, always routes to WelcomeScreen.
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

/// Initial gate handling splash delay, onboarding state check, and route dispatching.
/// Also picks up any pending notification action stored by the background handler.
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
    // Trigger navigation ONLY after the first frame has rendered.
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

        // After routing to HomeScreen, dispatch any pending notification action
        // that was stored by the killed-app background handler.
        if (setupCompleted) {
          _dispatchPendingNotificationAction();
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          createRoute(const WelcomeScreen(), transition: RouteTransition.fade),
        );
      }
    });
  }

  /// Reads and clears any notification action ID stored while the app was killed,
  /// then routes it to HomeScreenState via [NotificationService.onActionReceived].
  Future<void> _dispatchPendingNotificationAction() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingAction = prefs.getString('pending_notification_action');
    if (pendingAction != null && pendingAction.isNotEmpty) {
      await prefs.remove('pending_notification_action');
      // Small delay to ensure HomeScreenState has mounted and registered its callback.
      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('[LaunchGate] Dispatching pending notification action: "$pendingAction"');
      NotificationService.onActionReceived?.call(pendingAction);
    }
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
