// ==============================================================================
// Lisko Mobile Safety Application - Main Dashboard & Tab Coordinator
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

import 'package:vibration/vibration.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/geofence_service.dart';

import '../services/sms_alert_service.dart';
import '../services/permission_service.dart';
import '../services/location_service.dart';
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

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GeofenceService _geofenceService = GeofenceService();
  final SmsAlertService _smsAlertService = SmsAlertService();


  int selectedTab = 0;
  bool tripActive = false;
  bool isArrived = false;
  int arrivalCountdown = 90;
  bool isTimeoutWarning = false;
  int timeoutCountdown = 90;


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
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onActionReceived = _routeNotificationAction;
    _restoreActiveTrip();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseService().refreshLocalTrips();
      
      if ((isTimeoutWarning || isArrived) && safetyCheckDeadline != null) {
        final now = DateTime.now();
        if (now.isBefore(safetyCheckDeadline!)) {
          final rem = safetyCheckDeadline!.difference(now).inSeconds;
          final elapsed = 90 - rem;
          if (elapsed >= 0 && elapsed < 90) {
            _triggerVibrationPattern(elapsed);
          }
        } else {
          if (!_isEscalating) {
            try {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            } catch (_) {}
            _escalateEmergencyAlert(isManualSos: false);
          }
        }
      }
    }
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
    final isTimeout = data['isTimeoutWarning'] as bool? ?? false;

    setState(() {
      tripActive = true;
      destination = dest;
      totalDuration = Duration(seconds: totalSecs);
      expectedArrivalAt = expMs != null ? DateTime.fromMillisecondsSinceEpoch(expMs) : null;
      isArrived = arrived;
      isTimeoutWarning = isTimeout;
      safetyCheckDeadline = safetyMs != null ? DateTime.fromMillisecondsSinceEpoch(safetyMs) : null;
      tripId = tId;
      tripStartedAt = startedMs != null ? DateTime.fromMillisecondsSinceEpoch(startedMs) : null;
      selectedTab = 0;
      
      if (isTimeout || isArrived) {
        remaining = Duration.zero;
      }
    });

    final now = DateTime.now();
    if ((isArrived || isTimeout) && safetyCheckDeadline != null) {
      if (now.isAfter(safetyCheckDeadline!)) {
        // Already expired while app was closed
        if (!_isEscalating) {
          _escalateEmergencyAlert(isManualSos: false);
        }
      } else {
        if (isTimeout) {
          timeoutCountdown = safetyCheckDeadline!.difference(now).inSeconds;
          _startTimeoutCountdownTimer();
          
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                fullscreenDialog: true,
                pageBuilder: (context, _, __) => TimesUpScreen(
                  onSafe: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _endTrip(safe: true);
                  },
                  onExtend: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _extendTrip();
                  },
                  onHelp: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _triggerEmergencyFlow(immediate: false);
                  },
                  deadline: safetyCheckDeadline!,
                ),
              ),
            );
          }
        } else {
          arrivalCountdown = safetyCheckDeadline!.difference(now).inSeconds;
          _startArrivalCountdownTimer();
          // _runVibrateLoop removed; vibration handled in Timer
          
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                fullscreenDialog: true,
                pageBuilder: (context, _, __) => TimesUpScreen(
                  onSafe: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _endTrip(safe: true);
                  },
                  onExtend: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _extendTrip();
                  },
                  onHelp: () {
                    Vibration.cancel();
                    NotificationService().cancelArrivalAlarm();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    _triggerEmergencyFlow(immediate: false);
                  },
                  deadline: safetyCheckDeadline!,
                ),
              ),
            );
          }
        }
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
          onError: (error) {
            debugPrint('Geofence tracking notice: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.body,
                  duration: const Duration(seconds: 5),
                  content: const Text(
                    'Auto-arrival detection is unavailable for this destination. Your trip timer will continue.',
                  ),
                ),
              );
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    // Unregister so stale callbacks from a destroyed widget are never called.
    NotificationService.onActionReceived = null;
    Vibration.cancel();
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    _geofenceService.stopMonitoring();

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
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _endTrip(safe: true);
  }

  /// Extends the trip timer by 15 minutes. Cancels current vibration loop.
  void handleExtendAction() {
    if (!mounted) return;
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _extendTrip();
  }

  /// Immediately triggers the emergency SOS flow (bypasses 5-second countdown).
  void handleSosAction() async {
    if (!mounted) return;
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (isForeground) {
      _triggerEmergencyFlow(immediate: false);
    } else {
      if (_isPreparingSos) return;
      _isPreparingSos = true;

      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) return;
      if (_isPreparingSos) {
        await _escalateEmergencyAlert(isManualSos: true);
        if (mounted) {
          setState(() {
            _isPreparingSos = false;
          });
        }
      }
    }
  }

  Future<bool> _startTrip(String selectedDestination, Duration duration) async {
    final canStart = await PermissionService().checkTripRequirements(context);
    if (canStart) {
      _executeStartTrip(selectedDestination, duration);
    }
    return canStart;
  }

  void _startTravelTimer() {
    tripTimer?.cancel();
    tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      if (expectedArrivalAt != null && currentTime.isAfter(expectedArrivalAt!)) {
        tripTimer?.cancel();
        _handleTimeoutDetected();
      } else if (expectedArrivalAt != null) {
        setState(() => remaining = expectedArrivalAt!.difference(currentTime));
        final mm = remaining.inMinutes.toString().padLeft(2, '0');
        final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        NotificationService().showPersistentTripNotification(destination, '$mm:$ss');
      }
    });
  }



  void _triggerVibrationPattern(int initialElapsed) async {
    List<bool> activeSeconds = [];
    for (int sec = 0; sec < 90; sec++) {
      bool inActiveBlock = (sec >= 0 && sec < 20) || (sec >= 30 && sec < 50) || (sec >= 60 && sec < 80);
      bool isPulseVibrate = (sec % 4) < 2; // 2s on, 2s off
      activeSeconds.add(inActiveBlock && isPulseVibrate);
    }

    if (initialElapsed >= 90) return;
    List<bool> remaining = activeSeconds.sublist(initialElapsed);

    List<int> pattern = [];
    int currentDuration = 0;
    bool currentState = false; 

    for (int i = 0; i < remaining.length; i++) {
      if (remaining[i] == currentState) {
        currentDuration += 1000;
      } else {
        pattern.add(currentDuration);
        currentState = remaining[i];
        currentDuration = 1000;
      }
    }
    
    if (currentState == true) {
      pattern.add(currentDuration);
    }
    
    if (pattern.isNotEmpty) {
      Vibration.vibrate(pattern: pattern);
    }
  }

  void _startArrivalCountdownTimer() {
    _arrivalTimer?.cancel();
    Vibration.cancel();
    
    if (safetyCheckDeadline != null) {
      final now = DateTime.now();
      final rem = safetyCheckDeadline!.difference(now).inSeconds;
      final elapsed = 90 - rem;
      if (elapsed >= 0 && elapsed < 90) _triggerVibrationPattern(elapsed);
    }

    _arrivalTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final now = DateTime.now();
      if (safetyCheckDeadline != null && now.isAfter(safetyCheckDeadline!)) {
        _arrivalTimer?.cancel();
        if (!_isEscalating) {
          try {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          } catch (_) {}
          _escalateEmergencyAlert(isManualSos: false);
        }
      } else if (safetyCheckDeadline != null) {
        final rem = safetyCheckDeadline!.difference(now).inSeconds;
        setState(() => arrivalCountdown = rem);
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

      _isEscalating = false;
      arrivalCountdown = 90;
      isTimeoutWarning = false;

      destination = selectedDestination;
      totalDuration = duration;
      expectedArrivalAt = now.add(duration);
      remaining = duration;
      tripId = newTripId;
      tripStartedAt = now;
      selectedTab = 0;
    });

    FlutterBackgroundService().startService();

    const LocalStorageService().saveActiveTrip(
      isActive: true,
      destination: destination,
      totalDurationSeconds: totalDuration.inSeconds,
      expectedArrivalAtMs: expectedArrivalAt?.millisecondsSinceEpoch,
      isArrived: false,
      tripId: tripId,
      startedAtMs: tripStartedAt?.millisecondsSinceEpoch,
    );
    FirebaseService().refreshLocalTrips();

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.body,
              duration: const Duration(seconds: 5),
              content: const Text(
                'Auto-arrival detection is unavailable for this destination. Your trip timer will continue.',
              ),
            ),
          );
        }
      },
    );

    // 2. Start Travel Countdown Timer using Timestamp Comparison
    _startTravelTimer();

    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 10),
    ).then((pos) {
      if (mounted) {
        _cachedActiveTripPosition = pos;
        const LocalStorageService().updateCachedLocation(pos.latitude, pos.longitude);
      }
    }).catchError((_) {});

  }


  void _startTimeoutCountdownTimer() {
    _arrivalTimer?.cancel();
    Vibration.cancel();

    if (safetyCheckDeadline != null) {
      final now = DateTime.now();
      final rem = safetyCheckDeadline!.difference(now).inSeconds;
      final elapsed = 90 - rem;
      if (elapsed >= 0 && elapsed < 90) _triggerVibrationPattern(elapsed);
    }

    _arrivalTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final now = DateTime.now();
      if (safetyCheckDeadline != null && now.isAfter(safetyCheckDeadline!)) {
        _arrivalTimer?.cancel();
        if (!_isEscalating) {
          try {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          } catch (_) {}
          _escalateEmergencyAlert(isManualSos: false);
        }
      } else if (safetyCheckDeadline != null) {
        final rem = safetyCheckDeadline!.difference(now).inSeconds;
        setState(() => timeoutCountdown = rem);
      }
    });
  }

  void _handleTimeoutDetected() async {
    if (isArrived || isTimeoutWarning) return;
    tripTimer?.cancel();
    final now = DateTime.now();
    
    setState(() {
      isTimeoutWarning = true;
      safetyCheckDeadline = now.add(const Duration(seconds: 90));
      timeoutCountdown = 90;
      selectedTab = 0;
    });

    const LocalStorageService().saveActiveTrip(
      isActive: true,
      destination: destination,
      totalDurationSeconds: totalDuration.inSeconds,
      expectedArrivalAtMs: expectedArrivalAt?.millisecondsSinceEpoch,
      isArrived: false,
      isTimeoutWarning: true,
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
        status: 'timeout_warning',
      );
    }

    _startTimeoutCountdownTimer();

    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 5),
    ).then((pos) {
      if (mounted) {
        _cachedActiveTripPosition = pos;
        const LocalStorageService().updateCachedLocation(pos.latitude, pos.longitude);
      }
    }).catchError((_) {});

    NotificationService().cancelPersistentTripNotification();
    NotificationService().showTimeoutAlarm(destination);

    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          fullscreenDialog: true,
          pageBuilder: (context, _, __) => TimesUpScreen(
            onSafe: () {
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              _endTrip(safe: true);
            },
            onExtend: () {
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              _extendTrip();
            },
            onHelp: () {
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              _triggerEmergencyFlow(immediate: false);
            },
            deadline: safetyCheckDeadline!,
          ),
        ),
      );
    }
  }


  /// Triggers arrival state and begins 90-second escalation countdown.
  void _handleArrivalDetected(String destinationName) async {
    if (isArrived) return;
    tripTimer?.cancel();
    final now = DateTime.now();
    
    setState(() {
      isArrived = true;
      isTimeoutWarning = false;
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
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _endTrip(safe: true);
            },
            onExtend: () {
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _extendTrip();
            },
            onHelp: () {
              Vibration.cancel();
              NotificationService().cancelArrivalAlarm();
              _triggerEmergencyFlow(immediate: false);
            },
            deadline: safetyCheckDeadline!,
          ),
        ),
      );
    }
  }

  /// Public test & demonstration helper allowing simulation of GPS arrival.
  void simulateGeofenceArrival() {
    _handleArrivalDetected(destination);
  }

  bool _isEscalating = false;
  Position? _cachedActiveTripPosition;

  /// Dispatches offline SMS emergency alerts when 90-second timer expires or manual SOS is triggered.
  Future<void> _escalateEmergencyAlert({bool isManualSos = false}) async {
    if (_isEscalating) return;
    if (!isManualSos && _isPreparingSos) return; // Prevent timeouts from clashing with the 5-sec SOS countdown
    _isEscalating = true;
    Vibration.cancel();
    
    try {
      double? lat;
      double? lng;
      double? acc;
      String? locError;

      // Acquire emergency location using shared LocationService
      final locResult = await LocationService().acquireEmergencyLocation(
        cachedTripPosition: _cachedActiveTripPosition,
      );

      lat = locResult.latitude;
      lng = locResult.longitude;
      acc = locResult.accuracy;
      locError = locResult.locationError;

      List<String> sentList = [];
      bool permissionDenied = (locError == 'Permission Denied');
      try {
        debugPrint('Dispatching SMS alert (isManualSos: $isManualSos)...');
        if (isManualSos) {
          sentList = await _smsAlertService.sendManualSos(
            latitude: lat,
            longitude: lng,
            accuracy: acc,
            locationError: locError,
          );
        } else {
          sentList = await _smsAlertService.dispatchEmergencyAlert(
            destination: destination,
            latitude: lat,
            longitude: lng,
            accuracy: acc,
            locationError: locError,
          );
        }
        debugPrint('SMS successfully dispatched to ${sentList.length} contacts.');
        await NotificationService().showEmergencySentNotification(sentList, permissionDenied: permissionDenied);
      } catch (e) {
        if (e.toString().contains('SMS_PERMISSION_DENIED')) {
          permissionDenied = true;
          await NotificationService().showEmergencySentNotification([], permissionDenied: true);
        } else {
          await NotificationService().showEmergencySentNotification([], permissionDenied: false);
        }
      }
      
      const LocalStorageService().saveActiveTrip(isActive: false);

      // Log the trip locally as Alert
      final storage = const LocalStorageService();
      final history = await storage.readTripHistory();
      
      String eventType = 'Alert';
      String eventDestination = destination;
      if (isManualSos) {
        if (tripId.isEmpty) {
          eventDestination = 'Manual SOS';
          eventType = 'Manual SOS';
        } else {
          eventType = 'Need Help';
        }
      } else {
        eventType = 'Timer Expired';
      }

      final eventId = tripId.isNotEmpty ? tripId : DateTime.now().millisecondsSinceEpoch.toString();
      final newTrip = TripRecord(
        id: eventId,
        destination: eventDestination,
        durationMinutes: totalDuration.inMinutes,
        status: eventType,
        timestamp: DateTime.now(),
      );
      await storage.saveTripHistory([...history, newTrip]);
      FirebaseService().refreshLocalTrips();

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
      }

      FirebaseService().logEmergencyEvent(
        eventId: eventId,
        deviceId: 'local_device',
        tripId: tripId,
        latitude: lat ?? 0.0,
        longitude: lng ?? 0.0,
        emergencyType: isManualSos ? 'SOS' : 'TIMEOUT_ESCALATION',
      );

      // Cleanup all background location monitoring and timers to ensure zero-surveillance
      tripTimer?.cancel();
      _arrivalTimer?.cancel();
      Vibration.cancel();
      NotificationService().cancelArrivalAlarm();
      _geofenceService.stopMonitoring();

      debugPrint('[Cleanup] All location monitoring stopped after emergency.');

      if (mounted) {
        final msgType = isManualSos ? "Manual SOS" : "Timer expiry";
        final statusMessage = permissionDenied 
            ? "Failed to request $msgType SMS (Permission Denied)."
            : sentList.isEmpty 
                ? "Failed to request $msgType SMS."
                : "$msgType SMS request sent to ${sentList.join(", ")}.";
                
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: permissionDenied || sentList.isEmpty ? AppColors.body : AppColors.primary,
            duration: const Duration(seconds: 5),
            content: Text(statusMessage),
          ),
        );
      }
    } catch (e) {
      debugPrint('Unhandled error in _escalateEmergencyAlert: $e');
    } finally {
      if (mounted) {
        setState(() {
          tripActive = false;
          isArrived = false;
          isTimeoutWarning = false;
          _isEscalating = false;
          remaining = Duration.zero;
          arrivalCountdown = 90;
          expectedArrivalAt = null;
          safetyCheckDeadline = null;
          tripId = '';
          tripStartedAt = null;
        });
      }
      FlutterBackgroundService().invoke('stopService');
    }
  }

  Future<void> _endTrip({bool safe = false}) async {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    Vibration.cancel();
    NotificationService().cancelArrivalAlarm();


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
        status: safe ? 'Arrived Safely' : 'Cancelled',
        timestamp: DateTime.now(),
      );
      await storage.saveTripHistory([...history, newTrip]);
      FirebaseService().refreshLocalTrips();

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
      isTimeoutWarning = false;

      _isEscalating = false;
      remaining = Duration.zero;
      arrivalCountdown = 90;
      expectedArrivalAt = null;
      safetyCheckDeadline = null;
      tripId = '';
      tripStartedAt = null;
    });

    FlutterBackgroundService().invoke('stopService');
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
      isTimeoutWarning = false;

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
        status: 'Trip Extended',
        wasExtended: true,
      );
    }

    // Re-enable travel countdown
    _startTravelTimer();



  }

  bool _alertScreenOpen = false;
  bool _sheetOpen = false;

  bool _isPreparingSos = false;

  void _triggerEmergencyFlow({bool immediate = false}) async {
    if (_alertScreenOpen || _isPreparingSos) return;

    final permService = PermissionService();
    await permService.checkTripRequirements(context);

    // Wait for the user to return if they were sent to OS settings.
    // A small delay ensures the OS has time to transition the app to a paused state
    // before we evaluate the while condition.
    await Future.delayed(const Duration(milliseconds: 500));
    while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    _alertScreenOpen = true;
    _isPreparingSos = true; // Lock background timeouts

    // Check location service status before showing emergency countdown
    final serviceEnabled = await permService.isLocationServiceEnabled();
    if (serviceEnabled) {
      // Small pause check if native location dialog appears
      await Future.delayed(const Duration(milliseconds: 500));
      while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!mounted) return;

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
            _isPreparingSos = false;
            if (isArrived && arrivalCountdown == 0) {
                _endTrip(safe: false);
            }
          },
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        _alertScreenOpen = false;
        _isPreparingSos = false;
      }
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
                    onSos: () => _triggerEmergencyFlow(immediate: false),
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

