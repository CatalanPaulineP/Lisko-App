// ==============================================================================
// Lisko Mobile Safety Application - Core Entry Point
// File: lib/main.dart
//
// Role & Architectural Context:
// Application bootstrapper and root widget coordinator. Configures standard
// LisKo application routes and standalone emergency overlay route "/sos_emergency".
// Uses `onGenerateInitialRoutes` to isolate "/sos_emergency" from "_LaunchGate",
// ensuring zero route interruption or splash delay during SOS widget triggers.
// ==============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'screens/emergency_alert_screen.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/background_service_setup.dart';
import 'services/firebase_service.dart';
import 'services/local_storage_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/sms_alert_service.dart';

export 'constants/app_colors.dart';
export 'constants/app_icons.dart';
export 'constants/app_theme.dart';
export 'screens/screens.dart';
export 'services/local_storage_service.dart';
export 'widgets/widgets.dart';

/// Global navigator key allowing runtime root route manipulation.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Stopwatch tracking high-precision startup milestone timestamps.
final Stopwatch _startupStopwatch = Stopwatch();

/// Main application entry point invoked by the Flutter engine.
void main() async {
  _startupStopwatch.start();
  debugPrint('[LisKo Startup] 0ms: main() entered');
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const LiskoApp());
}

/// Asynchronously initializes required safety background services when launched in standalone SOS mode.
void initBackgroundServicesForSos() {
  NotificationService().initialize().catchError((e) {
    debugPrint('NotificationService init notice: $e');
  });
  initializeBackgroundService().catchError((e) {
    debugPrint('BackgroundService init notice: $e');
  });
  _initFirebaseSafely().catchError((e) {
    debugPrint('Firebase init notice: $e');
  });
}

Future<void> _initFirebaseSafely() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization notice: $error');
  }
}

/// Standalone dispatch function executed when SOS widget countdown completes without cancelling.
Future<void> executeStandaloneSosDispatch() async {
  try {
    double? lat;
    double? lng;
    double? acc;
    String? locError;

    // Acquire emergency location
    final locResult = await LocationService().acquireEmergencyLocation();
    lat = locResult.latitude;
    lng = locResult.longitude;
    acc = locResult.accuracy;
    locError = locResult.locationError;

    bool permissionDenied = (locError == 'Permission Denied');
    List<String> sentList = [];

    try {
      sentList = await SmsAlertService().sendManualSos(
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        locationError: locError,
      );
      await NotificationService().showEmergencySentNotification(
        sentList,
        permissionDenied: permissionDenied,
      );
    } catch (e) {
      bool pd = e.toString().contains('SMS_PERMISSION_DENIED') || permissionDenied;
      await NotificationService().showEmergencySentNotification(
        [],
        permissionDenied: pd,
      );
    }

    // Persist history & Firebase event
    final storage = const LocalStorageService();
    final history = await storage.readTripHistory();
    final eventId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTrip = TripRecord(
      id: eventId,
      destination: 'Manual SOS',
      durationMinutes: 0,
      status: 'Manual SOS',
      timestamp: DateTime.now(),
    );
    await storage.saveTripHistory([...history, newTrip]);
    FirebaseService().refreshLocalTrips();

    FirebaseService().logEmergencyEvent(
      eventId: eventId,
      deviceId: 'local_device',
      tripId: '',
      latitude: lat ?? 0.0,
      longitude: lng ?? 0.0,
      emergencyType: 'SOS',
    );
  } catch (e) {
    debugPrint('[Standalone SOS Dispatch Error] $e');
  }
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

/// Application root widget configuring Material 3 theme and initial routes.
class LiskoApp extends StatelessWidget {
  const LiskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Lisko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateInitialRoutes: (initialRoute) {
        if (initialRoute == '/sos_emergency') {
          return [
            PageRouteBuilder(
              settings: const RouteSettings(name: '/sos_emergency'),
              pageBuilder: (_, __, ___) => EmergencyAlertScreen(
                isManualSos: true,
                isStandalone: true,
                onExecute: executeStandaloneSosDispatch,
                onCancel: () {},
              ),
              transitionDuration: Duration.zero,
            ),
          ];
        }
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: '/'),
            builder: (context) => const _LaunchGate(),
          ),
        ];
      },
      routes: {
        '/': (context) => const _LaunchGate(),
        '/sos_emergency': (context) => EmergencyAlertScreen(
              isManualSos: true,
              isStandalone: true,
              onExecute: executeStandaloneSosDispatch,
              onCancel: () {},
            ),
      },
    );
  }
}

/// Initial gate handling splash delay, onboarding state check, and route dispatching.
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
