// ==============================================================================
// LisKo Mobile Safety Application - Main Dashboard & Tab Coordinator
// File: lib/screens/main_dashboard_screen.dart
//
// Role & Architectural Context:
// Root screen container (`HomeScreen`) coordinating the four bottom navigation tabs:
// - Tab 0: Home Dashboard (`HomeDashboardTab` when idle, `ActiveTripTab` when commuting)
// - Tab 1: Trips History & Metrics (`TripsTab`)
// - Tab 2: Trusted Contacts Directory (`ContactsTab`)
// - Tab 3: Security & Preferences (`SettingsTab`)
//
// Trip State Management & Countdown Lifecycle:
// Manages the active commute countdown (`tripActive`, `remaining`, `totalDuration`):
// - Starting a Trip: Cancels any lingering timers, sets active duration, and ticks every 1 second.
// - Auto-Completion: When countdown expires (`remaining <= Duration.zero`), timer cancels
//   and trip state automatically terminates.
// - Trip Extension (+15 min): Safely increments remaining duration without resetting the timer.
// - Modal & Dialog Guards (`_sheetOpen`, `_dialogOpen`): Enforces re-entrancy protection
//   preventing duplicate modals during rapid user interaction.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Reliability: Timers are strictly canceled inside `dispose()` and state updates
//   verify `mounted` prior to invoking `setState()`.
// - Usability (Smooth Transitions): Tab switches utilize `AnimatedSwitcher` (120ms easeOut)
//   retaining steady 60fps rendering without route navigation overhead.
// ==============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'times_up_screen.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/geofence_service.dart';
import '../services/stationary_detection_service.dart';
import '../services/sms_alert_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_icon.dart';
import '../widgets/set_trip_timer_bottom_sheet.dart';
import 'active_trip_screen.dart';
import 'contacts_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';
import 'trips_tab.dart';
import 'emergency_alert_screen.dart';

/// Main container screen hosting the bottom navigation bar and active trip state.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final SmsAlertService _smsAlertService = SmsAlertService();
  final StationaryDetectionService _stationaryService = StationaryDetectionService();

  int selectedTab = 0;
  bool tripActive = false;
  bool isArrived = false;
  int arrivalCountdown = 90;
  Duration remaining = const Duration(minutes: 45);
  DateTime? expectedArrivalAt;
  DateTime? safetyCheckDeadline;
  Duration totalDuration = const Duration(minutes: 45);
  String destination = 'Campus';
  String tripId = '';
  DateTime? tripStartedAt;
  Timer? tripTimer;
  Timer? _arrivalTimer;

  // Global cancellation flag for the vibration alarm loop.
  // Set true when the alarm fires; set false INSTANTLY by any action button so
  // every pending await in _runVibrateLoop aborts before its next vibration burst.
  bool _alarmActive = false;

  // -------------------------------------------------------------------------
  // Lifecycle — register / unregister notification response callback.
  //
  // By setting NotificationService.onActionReceived here, the notification
  // response router (both foreground and killed-app) can call trip methods
  // directly on the live HomeScreenState without a GlobalKey.
  // -------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    NotificationService.onActionReceived = _routeNotificationAction;
    _restoreActiveTrip();
  }

  Future<void> _restoreActiveTrip() async {
    const storage = LocalStorageService();
    final data = await storage.readActiveTrip();
    if (data == null || !mounted) return;

    final dest = data['destination'] as String? ?? 'Campus';
    final totalSecs = data['totalDurationSeconds'] as int? ?? 45 * 60;
    final expMs = data['expectedArrivalAtMs'] as int?;
    final arrived = data['isArrived'] as bool? ?? false;
    final safetyMs = data['safetyCheckDeadlineMs'] as int?;
    final tId = data['tripId'] as String? ?? '';
    final startedMs = data['startedAtMs'] as int?;

    setState(() {
      tripActive = true;
      destination = dest;
      totalDuration = Duration(seconds: totalSecs);
      expectedArrivalAt = expMs != null ? DateTime.fromMillisecondsSinceEpoch(expMs) : null;
      isArrived = arrived;
      safetyCheckDeadline = safetyMs != null ? DateTime.fromMillisecondsSinceEpoch(safetyMs) : null;
      tripId = tId;
      tripStartedAt = startedMs != null ? DateTime.fromMillisecondsSinceEpoch(startedMs) : null;
      selectedTab = 0;
    });

    final now = DateTime.now();
    if (isArrived && safetyCheckDeadline != null) {
      if (now.isAfter(safetyCheckDeadline!)) {
        // Already expired while app was closed
        _escalateEmergencyAlert(isManualSos: false);
      } else {
        arrivalCountdown = safetyCheckDeadline!.difference(now).inSeconds;
        _startArrivalCountdownTimer();
        _runVibrateLoop(cycles: 3);
      }
    } else if (expectedArrivalAt != null) {
      if (now.isAfter(expectedArrivalAt!)) {
        _handleArrivalDetected(destination);
      } else {
        remaining = expectedArrivalAt!.difference(now);
        _startTravelTimer();
        _geofenceService.startMonitoring(
          destination: destination,
          onArrival: (target, distance) {
            if (!mounted) return;
            _handleArrivalDetected(target.name);
          },
          onError: (error) => debugPrint('Geofence tracking notice: $error'),
        );
      }
    }
  }

  @override
  void dispose() {
    // Unregister so stale callbacks from a destroyed widget are never called.
    NotificationService.onActionReceived = null;
    _alarmActive = false;           // Abort any running vibration loop.
    Vibration.cancel();
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    _geofenceService.stopMonitoring();
    _stationaryService.stopMonitoring();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Notification action router
  //
  // Called by NotificationService._handleNotificationResponse() (foreground /
  // background-resumed) and by _LaunchGate._dispatchPendingNotificationAction()
  // (killed-app restart path).
  // -------------------------------------------------------------------------
  void _routeNotificationAction(String actionId) {
    if (!mounted) return;
    debugPrint('[HomeScreenState] Routing notification action: "$actionId"');
    switch (actionId) {
      case kNotifActionSafe:
        handleSafeAction();
        break;
      case kNotifActionExtend:
        handleExtendAction();
        break;
      case kNotifActionSos:
        handleSosAction();
        break;
      default:
        debugPrint('[HomeScreenState] Unknown notification actionId: "$actionId"');
    }
  }

  // -------------------------------------------------------------------------
  // Public trip action handlers — callable from outside the widget tree via
  // NotificationService.onActionReceived.
  // -------------------------------------------------------------------------

  /// Marks the trip as safely completed. Cancels vibration and alarm notification.
  void handleSafeAction() {
    if (!mounted) return;
    _alarmActive = false;         // Signal the vibration loop to abort immediately.
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    _endTrip(safe: true);
  }

  /// Extends the trip timer by 15 minutes. Cancels current vibration loop.
  void handleExtendAction() {
    if (!mounted) return;
    _alarmActive = false;         // Signal the vibration loop to abort immediately.
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    _extendTrip();
  }

  /// Immediately triggers the emergency SOS flow (bypasses 5-second countdown).
  void handleSosAction() {
    if (!mounted) return;
    _alarmActive = false;         // Signal the vibration loop to abort immediately.
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    _triggerEmergencyFlow(immediate: true);
  }

  void _startTrip(String selectedDestination, Duration duration) async {
    final canStart = await PermissionService().checkTripRequirements(context);
    if (canStart) {
      _executeStartTrip(selectedDestination, duration);
    }
  }

  void _startTravelTimer() {
    tripTimer?.cancel();
    tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      if (expectedArrivalAt != null && currentTime.isAfter(expectedArrivalAt!)) {
        tripTimer?.cancel();
        _handleArrivalDetected(destination);
      } else if (expectedArrivalAt != null) {
        setState(() => remaining = expectedArrivalAt!.difference(currentTime));
        final mm = remaining.inMinutes.toString().padLeft(2, '0');
        final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        NotificationService().showPersistentTripNotification(destination, '$mm:$ss');
      }
    });
  }

  void _startArrivalCountdownTimer() {
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (safetyCheckDeadline != null && now.isAfter(safetyCheckDeadline!)) {
        _arrivalTimer?.cancel();
        _escalateEmergencyAlert(isManualSos: false);
      } else if (safetyCheckDeadline != null) {
        setState(() => arrivalCountdown = safetyCheckDeadline!.difference(now).inSeconds);
      }
    });
  }

  void _executeStartTrip(String selectedDestination, Duration duration) {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    final now = DateTime.now();
    final newTripId = now.millisecondsSinceEpoch.toString();
    setState(() {
      tripActive = true;
      isArrived = false;
      arrivalCountdown = 90;
      destination = selectedDestination;
      totalDuration = duration;
      expectedArrivalAt = now.add(duration);
      remaining = duration;
      tripId = newTripId;
      tripStartedAt = now;
      selectedTab = 0;
    });

    const LocalStorageService().saveActiveTrip(
      isActive: true,
      destination: destination,
      totalDurationSeconds: totalDuration.inSeconds,
      expectedArrivalAtMs: expectedArrivalAt?.millisecondsSinceEpoch,
      isArrived: false,
      tripId: tripId,
      startedAtMs: tripStartedAt?.millisecondsSinceEpoch,
    );

    // Sync to Firebase
    FirebaseService().saveOrUpdateTrip(
      tripId: tripId,
      destination: destination,
      estimatedTravelMinutes: totalDuration.inMinutes,
      startedAt: tripStartedAt ?? now,
      expectedArrivalAt: expectedArrivalAt,
      status: 'active',
    );

    // 1. Activate Conditional GPS Geofence Monitoring (strictly inactive when idle)
    _geofenceService.startMonitoring(
      destination: selectedDestination,
      onArrival: (target, distance) {
        if (!mounted) return;
        _handleArrivalDetected(target.name);
      },
      onError: (error) {
        debugPrint('Geofence tracking notice: $error');
      },
    );

    // 2. Start Travel Countdown Timer using Timestamp Comparison
    _startTravelTimer();

    // 3. Stationary Detection & Inactivity Geofence Algorithm
    // Capture the student's GPS position at trip start as the anchor coordinate.
    // After 10 minutes, re-sample and compare via Haversine. If the student
    // hasn't moved ≥ 20m, trigger the safety heads-up banner.
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then((startPosition) {
      _stationaryService.startMonitoring(
        anchorLat: startPosition.latitude,
        anchorLon: startPosition.longitude,
        onInactivityDetected: () {
          // Only trigger if the trip is still running (not already arrived/ended)
          if (mounted && tripActive && !isArrived) {
            _handleArrivalDetected(destination);
          }
        },
      );
    }).catchError((e) {
      debugPrint('[StationaryDetection] Could not capture start position: $e');
    });
  }

  /// Triggers arrival state and begins 90-second escalation countdown.
  void _handleArrivalDetected(String destinationName) async {
    if (isArrived) return;
    tripTimer?.cancel();
    final now = DateTime.now();
    
    setState(() {
      isArrived = true;
      safetyCheckDeadline = now.add(const Duration(seconds: 90));
      arrivalCountdown = 90;
      selectedTab = 0;
    });

    const LocalStorageService().saveActiveTrip(
      isActive: true,
      destination: destination,
      totalDurationSeconds: totalDuration.inSeconds,
      expectedArrivalAtMs: expectedArrivalAt?.millisecondsSinceEpoch,
      isArrived: true,
      safetyCheckDeadlineMs: safetyCheckDeadline?.millisecondsSinceEpoch,
      tripId: tripId,
      startedAtMs: tripStartedAt?.millisecondsSinceEpoch,
    );

    if (tripId.isNotEmpty && tripStartedAt != null) {
      FirebaseService().saveOrUpdateTrip(
        tripId: tripId,
        destination: destination,
        estimatedTravelMinutes: totalDuration.inMinutes,
        startedAt: tripStartedAt!,
        expectedArrivalAt: expectedArrivalAt,
        status: 'arrived',
      );
    }

    _startArrivalCountdownTimer();

    final storage = const LocalStorageService();
    final alertMode = await storage.readAlertMode();
    
    if (alertMode != 'Silent') {
      // Arm the cancellation flag BEFORE starting the loop so the first
      // guard check inside _runVibrateLoop sees an active alarm state.
      _alarmActive = true;
      // Pulsing vibration loop: 3 outer cycles × (20s pulse window + 10s silent) = 90s.
      // Each 20s window is itself a rapid zz-zz-zz pulse (500ms on / 500ms off).
      // Any action button sets _alarmActive = false + calls Vibration.cancel(),
      // which causes the next await in the loop to abort before the next burst.
      _runVibrateLoop(cycles: 3);
    }

    NotificationService().cancelPersistentTripNotification();
    NotificationService().showArrivalAlarm(destinationName);

    // Show full-screen intent when the app is brought to foreground (e.g. by native notification)
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          fullscreenDialog: true,
          pageBuilder: (context, _, __) => TimesUpScreen(
            onSafe: () {
              _alarmActive = false;
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _endTrip(safe: true);
            },
            onExtend: () {
              _alarmActive = false;
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _extendTrip();
            },
            onHelp: () {
              _alarmActive = false;
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _triggerEmergencyFlow(immediate: true);
            },
            onTimeout: () {
              _alarmActive = false;
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _escalateEmergencyAlert(isManualSos: false);
            },
          ),
        ),
      );
    }
  }

  /// Public test & demonstration helper allowing simulation of GPS arrival.
  void simulateGeofenceArrival() {
    _handleArrivalDetected(destination);
  }

  /// Drives a pulsing vibration alarm: [cycles] outer rounds (20s pulse window + 10s silent).
  /// Total for 3 cycles = 90 seconds - matching the safety-check countdown.
  ///
  /// Each 20-second "active" window is NOT a solid buzz. Instead it fires a rapid
  /// pulse: 1000ms vibrate + 1000ms pause + repeat 10 times = 20 seconds.
  ///
  /// The `_alarmActive` flag is checked before EVERY await. Any action button sets
  /// `_alarmActive = false` then calls `Vibration.cancel()`, which causes this loop
  /// to detect the flag and return immediately - eliminating ghost vibrations.
  ///
  /// This method is fire-and-forget (no await at the call site).
  void _runVibrateLoop({int cycles = 3}) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!_alarmActive) return;    // Guard: cancelled before hardware check finished.
    if (hasVibrator != true) {
      // Devices without a vibrator fall back to a single HapticFeedback burst.
      HapticFeedback.heavyImpact();
      return;
    }

    for (int outer = 0; outer < cycles; outer++) {
      // -- 20-second pulsing window: 10 x (1000ms ON + 1000ms OFF) --
      for (int pulse = 0; pulse < 10; pulse++) {
        if (!_alarmActive) {
          Vibration.cancel();
          return;
        }

        // Short vibration burst (1000 ms = 1 second).
        try {
          await Vibration.vibrate(duration: 1000);
        } catch (_) {}

        if (!_alarmActive) {
          Vibration.cancel();
          return;
        }

        // 1000 ms silent gap.
        // Checked in 100ms increments to instantly abort if a button is tapped mid-pause.
        for (int i = 0; i < 10; i++) {
          if (!_alarmActive) {
            Vibration.cancel();
            return;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // -- 10-second silent inter-cycle gap --
      // Applied to EVERY cycle, including the final 3rd cycle (1:20 to 1:30) as a grace period.
      for (int s = 0; s < 10; s++) {
        if (!_alarmActive) {
          Vibration.cancel();
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  bool _isEscalating = false;

  /// Dispatches offline SMS emergency alerts when 90-second timer expires or manual SOS is triggered.
  Future<void> _escalateEmergencyAlert({bool isManualSos = false}) async {
    if (_isEscalating) return;
    _isEscalating = true;
    
    try {
      double? lat = _geofenceService.activeTarget?.latitude;
      double? lng = _geofenceService.activeTarget?.longitude;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (e) {
        debugPrint('Failed to fetch live GPS for emergency escalation: $e');
      }

      List<String> sentList = [];
      bool permissionDenied = false;
      try {
        sentList = await _smsAlertService.dispatchEmergencyAlert(
          destination: destination,
          latitude: lat,
          longitude: lng,
          isManualSos: isManualSos,
        );
        NotificationService().showEmergencySentNotification(sentList, permissionDenied: false);
      } catch (e) {
        if (e.toString().contains('SMS_PERMISSION_DENIED')) {
          permissionDenied = true;
          NotificationService().showEmergencySentNotification([], permissionDenied: true);
        } else {
          NotificationService().showEmergencySentNotification([], permissionDenied: false);
        }
      }
      
      const LocalStorageService().saveActiveTrip(isActive: false);

      // Log the trip locally as Alert
      final storage = const LocalStorageService();
      final history = await storage.readTripHistory();
      final newTrip = TripRecord(
        id: tripId.isNotEmpty ? tripId : DateTime.now().millisecondsSinceEpoch.toString(),
        destination: destination,
        durationMinutes: totalDuration.inMinutes,
        status: 'Alert',
        timestamp: tripStartedAt ?? DateTime.now(),
      );
      await storage.saveTripHistory([...history, newTrip]);

      if (tripId.isNotEmpty && tripStartedAt != null) {
        FirebaseService().saveOrUpdateTrip(
          tripId: tripId,
          destination: destination,
          estimatedTravelMinutes: totalDuration.inMinutes,
          startedAt: tripStartedAt!,
          expectedArrivalAt: expectedArrivalAt,
          completedAt: DateTime.now(),
          status: isManualSos ? 'help_requested' : 'expired',
        );
        FirebaseService().logEmergencyEvent(
          deviceId: 'local_device',
          tripId: tripId,
          latitude: lat ?? 0.0,
          longitude: lng ?? 0.0,
          emergencyType: isManualSos ? 'SOS' : 'TIMEOUT_ESCALATION',
        );
      }

      if (mounted) {
        setState(() {
          tripActive = false;
          isArrived = false;
          remaining = Duration.zero;
          arrivalCountdown = 90;
          expectedArrivalAt = null;
          safetyCheckDeadline = null;
          tripId = '';
          tripStartedAt = null;
        });

        final msgType = isManualSos ? "Manual SOS" : "Timer expiry";
        final statusMessage = permissionDenied 
            ? "Failed to dispatch $msgType (SMS Permission Denied)."
            : sentList.isEmpty 
                ? "Failed to dispatch $msgType to contacts."
                : "$msgType alert dispatched to ${sentList.join(", ")}.";
                
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: permissionDenied || sentList.isEmpty ? AppColors.body : AppColors.primary,
            duration: const Duration(seconds: 5),
            content: Text('🚨 $statusMessage'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Unhandled error in _escalateEmergencyAlert: $e');
    } finally {
      _isEscalating = false;
    }
  }

  Future<void> _endTrip({bool safe = false}) async {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    // Stop stationary detection immediately to prevent stale inactivity warnings
    _stationaryService.stopMonitoring();
    // Immediate GPS shutdown preserving Zero-Surveillance privacy
    _geofenceService.stopMonitoring();
    
    const LocalStorageService().saveActiveTrip(isActive: false);

    // Log the trip locally
    final storage = const LocalStorageService();
    final history = await storage.readTripHistory();
    final newTrip = TripRecord(
      id: tripId.isNotEmpty ? tripId : DateTime.now().millisecondsSinceEpoch.toString(),
      destination: destination,
      durationMinutes: totalDuration.inMinutes,
      status: safe ? 'Completed' : 'Cancelled',
      timestamp: tripStartedAt ?? DateTime.now(),
    );
    await storage.saveTripHistory([...history, newTrip]);

    if (tripId.isNotEmpty && tripStartedAt != null) {
      FirebaseService().saveOrUpdateTrip(
        tripId: tripId,
        destination: destination,
        estimatedTravelMinutes: totalDuration.inMinutes,
        startedAt: tripStartedAt!,
        expectedArrivalAt: expectedArrivalAt,
        completedAt: DateTime.now(),
        status: safe ? 'arrived' : 'cancelled', // Changed 'arrived' string to represent successfully completed trip in the DB model based on user requirement
      );
    }
    
    setState(() {
      tripActive = false;
      isArrived = false;
      remaining = Duration.zero;
      arrivalCountdown = 90;
      expectedArrivalAt = null;
      safetyCheckDeadline = null;
      tripId = '';
      tripStartedAt = null;
    });
  }

  void _extendTrip() {
    _arrivalTimer?.cancel();
    
    final currentTime = DateTime.now();
    // If we've already passed expectedArrivalAt, or it's null, base it on now
    if (expectedArrivalAt == null || currentTime.isAfter(expectedArrivalAt!)) {
        expectedArrivalAt = currentTime.add(const Duration(minutes: 15));
    } else {
        expectedArrivalAt = expectedArrivalAt!.add(const Duration(minutes: 15));
    }

    setState(() {
      isArrived = false;
      arrivalCountdown = 90;
      remaining = expectedArrivalAt!.difference(currentTime);
    });

    const LocalStorageService().saveActiveTrip(
      isActive: true,
      destination: destination,
      totalDurationSeconds: totalDuration.inSeconds,
      expectedArrivalAtMs: expectedArrivalAt?.millisecondsSinceEpoch,
      isArrived: false,
      tripId: tripId,
      startedAtMs: tripStartedAt?.millisecondsSinceEpoch,
    );

    if (tripId.isNotEmpty && tripStartedAt != null) {
      FirebaseService().saveOrUpdateTrip(
        tripId: tripId,
        destination: destination,
        estimatedTravelMinutes: totalDuration.inMinutes,
        startedAt: tripStartedAt!,
        expectedArrivalAt: expectedArrivalAt,
        status: 'extended',
      );
    }

    // Re-enable travel countdown
    _startTravelTimer();

    // Re-anchor stationary detection from the current position for the extended leg.
    // This prevents a stale position from triggering a false inactivity warning.
    _stationaryService.stopMonitoring();
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    ).then((extendPosition) {
      _stationaryService.startMonitoring(
        anchorLat: extendPosition.latitude,
        anchorLon: extendPosition.longitude,
        onInactivityDetected: () {
          if (mounted && tripActive && !isArrived) {
            _handleArrivalDetected(destination);
          }
        },
      );
    }).catchError((e) {
      debugPrint('[StationaryDetection] Could not re-anchor on extend: $e');
    });
  }

  bool _alertScreenOpen = false;
  bool _sheetOpen = false;

  void _triggerEmergencyFlow({bool immediate = false}) {
    if (_alertScreenOpen) return;
    _alertScreenOpen = true;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        fullscreenDialog: true,
        pageBuilder: (context, _, __) => EmergencyAlertScreen(
          isManualSos: true,
          immediateExecute: immediate,
          onExecute: () => _escalateEmergencyAlert(isManualSos: true),
          onCancel: () {
            if (isArrived && arrivalCountdown == 0) {
                _endTrip(safe: false);
            }
          },
        ),
      ),
    ).whenComplete(() {
      if (mounted) _alertScreenOpen = false;
    });
  }

  void _openTripScheduler() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripSchedulerSheet(onStart: _startTrip),
    ).whenComplete(() {
      if (mounted) _sheetOpen = false;
    });
  }

  Key _homeKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: null,
      body: IndexedStack(
        index: selectedTab,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: tripActive
                ? ActiveTripTab(
                    key: const ValueKey('active-trip'),
                    destination: destination,
                    remaining: remaining,
                    totalDuration: totalDuration,
                    onSafe: () => _endTrip(safe: true),
                    onExtend: _extendTrip,
                    onSos: _triggerEmergencyFlow,
                    isArrived: isArrived,
                    arrivalRemainingSeconds: arrivalCountdown,
                  )
                : HomeDashboardTab(
                    key: _homeKey,
                    onStartTrip: _openTripScheduler,
                    onSos: () => _triggerEmergencyFlow(immediate: true),
                  ),
          ),
            TripsTab(
              key: const ValueKey('trips'),
              onStartNewTrip: () {
                setState(() {
                  selectedTab = 0;
                  _homeKey = UniqueKey();
                });
              },
            ),
          const ContactsTab(key: ValueKey('contacts')),
          const SettingsTab(key: ValueKey('settings')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) {
          if (selectedTab == index) return;
          setState(() {
            selectedTab = index;
            if (index == 0) _homeKey = UniqueKey(); // Force home refresh to sync settings
          });
        },
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.body,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        iconSize: 22,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.homeOutline,
              color: AppColors.body,
              semanticIcon: Icons.home_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.home,
              color: AppColors.primary,
              semanticIcon: Icons.home_rounded,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.mapOutline,
              color: AppColors.body,
              semanticIcon: Icons.map_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.map,
              color: AppColors.primary,
              semanticIcon: Icons.map_rounded,
            ),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.peopleOutline,
              color: AppColors.body,
              semanticIcon: Icons.people_outline_rounded,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.people,
              color: AppColors.primary,
              semanticIcon: Icons.people_rounded,
            ),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.settingsOutline,
              color: AppColors.body,
              semanticIcon: Icons.settings_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.settings,
              color: AppColors.primary,
              semanticIcon: Icons.settings_rounded,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
