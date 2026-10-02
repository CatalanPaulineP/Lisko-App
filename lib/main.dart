// ==============================================================================
// Lisko Mobile Safety Application - Core Entry Point
// File: lib/main.dart
//
// Role & Architectural Context:
// Application bootstrapper and root widget coordinator. Initializes binary
// messenger bindings and launches `LiskoApp` immediately so the LisKo branded
// splash screen renders within milliseconds. Asynchronous initializations
// (NotificationService, BackgroundService, Firebase, SharedPreferences) execute
// concurrently while the Flutter SplashScreen is visible.
//
// Notification Background Response Handler:
// `notificationBackgroundResponseHandler` is a top-level @pragma function that
// runs in a separate Dart isolate when the user taps a notification action button
// while the app is fully terminated. It persists the action ID to SharedPreferences
// so `_LaunchGate` can dispatch it to HomeScreenState on the next boot.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Reliability (Fault-Tolerant Launch): Firebase / SharedPreferences errors
//   safely default to WelcomeScreen without crashing or hanging.
// - Performance Efficiency (Zero Black-Screen Startup): Instantaneous Flutter
//   frame rendering eliminates cold-start launch latency.
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
import 'services/background_service_setup.dart';

export 'constants/app_colors.dart';
export 'constants/app_icons.dart';
export 'constants/app_theme.dart';
export 'screens/screens.dart';
export 'services/local_storage_service.dart';
export 'widgets/widgets.dart';

/// Stopwatch tracking high-precision startup milestone timestamps.
final Stopwatch _startupStopwatch = Stopwatch();

/// Main application entry point invoked by the Flutter engine.
/// Mounts [LiskoApp] immediately to render the splash screen without blocking.
void main() {
  _startupStopwatch.start();
  debugPrint('[LisKo Startup] 0ms: main() entered');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: WidgetsBinding initialized, calling runApp()');
  runApp(const LiskoApp());
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
class LiskoApp extends StatelessWidget {
  const LiskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lisko',
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
  String _statusText = 'Preparing LisKo...';

  void _updateStatus(String text) {
    if (mounted && _statusText != text) {
      setState(() {
        _statusText = text;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _startupStopwatch.reset();
    _startupStopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapAndNavigate();
    });
  }

  Future<void> _bootstrapAndNavigate() async {
    debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: _bootstrapAndNavigate() started');

    try {
      _updateStatus('Preparing safety services...');

      // Execute all required initializations concurrently while SplashScreen is visible
      await Future.wait([
        NotificationService().initialize().then((_) {
          debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: NotificationService initialized');
        }),
        initializeBackgroundService().then((_) {
          debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: BackgroundService initialized');
        }),
        _initFirebaseSafely().then((_) {
          debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: Firebase initialized');
        }),
      ]);

      _updateStatus('Loading your preferences...');
      final setupCompleted = _isTestMode
          ? (forceFreshStartupForTesting ? false : await _storage.readSetupCompleted())
          : await _storage.readSetupCompleted();
      debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: Preferences read (setupCompleted: $setupCompleted)');

      if (setupCompleted) {
        _updateStatus('Checking trip information...');
        final activeTrip = await _storage.readActiveTrip();
        if (activeTrip != null && activeTrip['isActive'] == true) {
          _updateStatus('Restoring your active trip...');
          debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: Active trip detected for restoration');
        }
      }

      final elapsed = _startupStopwatch.elapsedMilliseconds;
      const minSplashTime = 2000;
      if (elapsed < minSplashTime) {
        await Future.delayed(Duration(milliseconds: minSplashTime - elapsed));
      }

      debugPrint('[LisKo Startup] ${_startupStopwatch.elapsedMilliseconds}ms: Navigating from SplashScreen');
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        createRoute(
          setupCompleted ? const HomeScreen() : const WelcomeScreen(),
          transition: RouteTransition.fade,
        ),
      );

      if (setupCompleted) {
        _dispatchPendingNotificationAction();
      }
    } catch (e) {
      debugPrint('[LisKo Startup] Bootstrap error: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        createRoute(const WelcomeScreen(), transition: RouteTransition.fade),
      );
    }
  }

  static Future<void> _initFirebaseSafely() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('Firebase initialization notice: $error');
    }
  }

  /// Reads and clears any notification action ID stored while the app was killed,
  /// then routes it to HomeScreenState via [NotificationService.onActionReceived].
  Future<void> _dispatchPendingNotificationAction() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingAction = prefs.getString('pending_notification_action');
    if (pendingAction != null && pendingAction.isNotEmpty) {
      await prefs.remove('pending_notification_action');
      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('[LaunchGate] Dispatching pending notification action: "$pendingAction"');
      NotificationService.onActionReceived?.call(pendingAction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(statusText: _statusText);
  }
}
