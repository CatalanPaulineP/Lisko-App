import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

import '../firebase_options.dart';
import 'firebase_service.dart';
import 'geofence_service.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'sms_alert_service.dart';

Future<void> initializeBackgroundService() async {
  debugPrint('[LisKo-BG-Diag] initializeBackgroundService() configuring FlutterBackgroundService');
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'lisko_trip_channel',
    'Lisko Trip Monitoring',
    description: 'Ongoing background monitoring for your active travel.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'lisko_trip_channel',
      initialNotificationTitle: 'Lisko Trip Active',
      initialNotificationContent: 'Monitoring your travel...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

Timer? _bgPeriodicTimer;
Timer? _bgSafetyCheckTimer;
Timer? _bgDeadlineTimer;
Timer? _bgVibrationPhaseTimer;
bool _isBgEscalating = false;

/// Cancels active background safety vibration and phase timers.
void _cancelBackgroundSafetyVibration(String reason) {
  _bgVibrationPhaseTimer?.cancel();
  _bgVibrationPhaseTimer = null;
  Vibration.cancel();
  debugPrint('[LisKo-BG-Diag] Safety vibration cancelled reason=$reason');
}

/// Generates the haptic pulse pattern (2s on, 2s off) for a given active duration in milliseconds.
List<int> _buildPulsePattern(int activeDurationMs) {
  final List<int> pattern = [0];
  int remaining = activeDurationMs;
  while (remaining > 0) {
    final pulseOn = remaining >= 2000 ? 2000 : remaining;
    pattern.add(pulseOn);
    remaining -= pulseOn;
    if (remaining > 0) {
      final pulseOff = remaining >= 2000 ? 2000 : remaining;
      pattern.add(pulseOff);
      remaining -= pulseOff;
    }
  }
  return pattern;
}

/// Schedules and executes timestamp-based vibration phases for the 90-second safety window.
void _scheduleNextVibrationPhase(int safetyDeadlineMs) {
  _bgVibrationPhaseTimer?.cancel();

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (nowMs >= safetyDeadlineMs) {
    Vibration.cancel();
    return;
  }

  final remainingWindowMs = safetyDeadlineMs - nowMs;
  final elapsedMs = 90000 - remainingWindowMs;
  final currentElapsed = elapsedMs < 0 ? 0 : elapsedMs;

  int phaseRemainingMs = 0;
  bool isVibratingPhase = false;
  String phaseName = '';

  if (currentElapsed < 20000) {
    // Phase 1 Active: 0s - 20s
    isVibratingPhase = true;
    phaseRemainingMs = 20000 - currentElapsed;
    phaseName = 'Phase 1 Active (0-20s)';
  } else if (currentElapsed < 30000) {
    // Phase 1 Silent: 20s - 30s
    isVibratingPhase = false;
    phaseRemainingMs = 30000 - currentElapsed;
    phaseName = 'Phase 1 Silent (20-30s)';
  } else if (currentElapsed < 50000) {
    // Phase 2 Active: 30s - 50s
    isVibratingPhase = true;
    phaseRemainingMs = 50000 - currentElapsed;
    phaseName = 'Phase 2 Active (30-50s)';
  } else if (currentElapsed < 60000) {
    // Phase 2 Silent: 50s - 60s
    isVibratingPhase = false;
    phaseRemainingMs = 60000 - currentElapsed;
    phaseName = 'Phase 2 Silent (50-60s)';
  } else if (currentElapsed < 80000) {
    // Phase 3 Active: 60s - 80s
    isVibratingPhase = true;
    phaseRemainingMs = 80000 - currentElapsed;
    phaseName = 'Phase 3 Active (60-80s)';
  } else {
    // Phase 3 Silent: 80s - 90s
    isVibratingPhase = false;
    phaseRemainingMs = safetyDeadlineMs - nowMs;
    phaseName = 'Phase 3 Silent (80-90s)';
  }

  debugPrint('[LisKo-BG-Diag] Safety vibration restore elapsed=${currentElapsed}ms phase=$phaseName remainingMs=$phaseRemainingMs');

  if (isVibratingPhase && phaseRemainingMs > 0) {
    debugPrint('[LisKo-BG-Diag] Safety vibration ACTIVE remainingMs=$phaseRemainingMs');
    final pattern = _buildPulsePattern(phaseRemainingMs);
    Vibration.vibrate(pattern: pattern);
  } else {
    debugPrint('[LisKo-BG-Diag] Safety vibration SILENT remainingMs=$phaseRemainingMs');
    Vibration.cancel();
  }

  _bgVibrationPhaseTimer = Timer(Duration(milliseconds: phaseRemainingMs), () {
    _scheduleNextVibrationPhase(safetyDeadlineMs);
  });
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  debugPrint('[LisKo-BG-Diag] BackgroundService onStart() entered');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('[LisKo-BG-Diag] Firebase initialized in BackgroundService isolate');
    }
  } catch (e) {
    debugPrint('[LisKo-BG-Diag] Firebase initialization notice in BackgroundService isolate: $e');
  }

  try {
    await NotificationService().initializeForBackgroundService();
  } catch (e) {
    debugPrint('[LisKo-BG-Diag] NotificationService background init notice: $e');
  }

  service.on('stopService').listen((event) async {
    debugPrint('[LisKo-BG-Diag] BackgroundService received stopService event, stopping monitoring and calling stopSelf()');
    _bgPeriodicTimer?.cancel();
    _bgSafetyCheckTimer?.cancel();
    _bgDeadlineTimer?.cancel();
    _cancelBackgroundSafetyVibration('stopService');
    debugPrint('[LisKo-BG-Diag] Deadline timer cancelled reason=end');
    GeofenceService().stopMonitoring();
    await NotificationService().cancelPersistentTripNotification();
    service.stopSelf();
  });

  service.on('startTripMonitoring').listen((event) async {
    debugPrint('[LisKo-BG-Diag] BackgroundService received startTripMonitoring event: $event');
    await _checkAndResumeActiveTripInBackground(service);
  });

  service.on('notificationAction').listen((event) async {
    debugPrint('[LisKo-BG-Diag] BackgroundService received notificationAction event: $event');
    final actionId = event?['actionId'] as String? ?? '';
    await _handleBackgroundNotificationAction(service, actionId);
  });

  service.on('updateNotification').listen((event) {
    if (event == null) return;
    final title = event['title'] as String?;
    final content = event['content'] as String?;
    final expMs = event['expectedArrivalAtMs'] as int?;
    if (title != null && content != null) {
      _showNotification888(title: title, content: content, expectedArrivalAtMs: expMs);
    }
  });

  // Execute autonomous background restore check on entry (handles START_STICKY process death restarts)
  await _checkAndResumeActiveTripInBackground(service);
}

void _showNotification888({
  required String title,
  required String content,
  int? expectedArrivalAtMs,
}) {
  debugPrint('[LisKo-BG-Diag] Notification 888 native countdown target=$expectedArrivalAtMs');
  final plugin = FlutterLocalNotificationsPlugin();
  plugin.show(
    id: 888,
    title: title,
    body: content,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'lisko_trip_channel',
        'Lisko Trip Monitoring',
        icon: 'ic_bg_service_small',
        ongoing: true,
        autoCancel: false,
        showWhen: expectedArrivalAtMs != null,
        when: expectedArrivalAtMs,
        usesChronometer: expectedArrivalAtMs != null,
        chronometerCountDown: expectedArrivalAtMs != null,
        importance: Importance.low,
        priority: Priority.low,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.status,
      ),
    ),
  );
}

Future<void> _handleBackgroundNotificationAction(ServiceInstance service, String actionId) async {
  if (actionId == kNotifActionSafe) {
    debugPrint('[LisKo-BG-Diag] BackgroundService handling kNotifActionSafe ("I\'m Safe")');
    _bgPeriodicTimer?.cancel();
    _bgSafetyCheckTimer?.cancel();
    _bgDeadlineTimer?.cancel();
    _cancelBackgroundSafetyVibration('kNotifActionSafe');
    debugPrint('[LisKo-BG-Diag] Deadline timer cancelled reason=safe_action');
    GeofenceService().stopMonitoring();

    // Read active trip state BEFORE marking inactive
    final activeTrip = await const LocalStorageService().readActiveTrip();
    final String dest = activeTrip?['destination'] as String? ?? '';
    final String tId = activeTrip?['tripId'] as String? ?? '';
    final int totalSecs = activeTrip?['totalDurationSeconds'] as int? ?? 0;
    final int? startedMs = activeTrip?['startedAtMs'] as int?;
    final int? expectedMs = activeTrip?['expectedArrivalAtMs'] as int?;
    final bool isArrived = activeTrip?['isArrived'] as bool? ?? false;
    final bool isTimeoutWarning = activeTrip?['isTimeoutWarning'] as bool? ?? false;

    // Immediate local safety shutdown
    await const LocalStorageService().saveActiveTrip(isActive: false);
    await NotificationService().cancelPersistentTripNotification();
    await NotificationService().cancelArrivalAlarm();

    // Perform safe-arrival completion work if trip was in an active safety check state
    if (isArrived || isTimeoutWarning) {
      try {
        final storage = const LocalStorageService();
        final history = await storage.readTripHistory();
        history.add(TripRecord(
          id: tId.isNotEmpty ? tId : DateTime.now().millisecondsSinceEpoch.toString(),
          destination: dest,
          durationMinutes: totalSecs ~/ 60,
          status: 'Arrived Safely',
          timestamp: startedMs != null ? DateTime.fromMillisecondsSinceEpoch(startedMs) : DateTime.now(),
        ));
        await storage.saveTripHistory(history);

        if (tId.isNotEmpty && startedMs != null) {
          await FirebaseService().saveOrUpdateTrip(
            tripId: tId,
            destination: dest,
            estimatedTravelMinutes: totalSecs ~/ 60,
            startedAt: DateTime.fromMillisecondsSinceEpoch(startedMs),
            expectedArrivalAt: expectedMs != null ? DateTime.fromMillisecondsSinceEpoch(expectedMs) : null,
            completedAt: DateTime.now(),
            status: 'arrived',
          );
        }

        if (dest.isNotEmpty) {
          try {
            await SmsAlertService().dispatchPrimaryArrivalSms(destination: dest);
          } catch (e) {
            debugPrint('[LisKo-BG-Diag] Primary safe arrival SMS notice: $e');
          }
        }

        await const LocalStorageService().saveTripCompletedFeedback(true);
      } catch (e) {
        debugPrint('[LisKo-BG-Diag] Error completing safe arrival in background: $e');
      }
    }

    await const LocalStorageService().consumePendingActionIfMatches(actionId);
    service.stopSelf();
  } else if (actionId == kNotifActionExtend) {
    debugPrint('[LisKo-BG-Diag] BackgroundService handling kNotifActionExtend ("+15 min")');
    _bgSafetyCheckTimer?.cancel();
    _cancelBackgroundSafetyVibration('kNotifActionExtend');
    await NotificationService().cancelArrivalAlarm();
    await _checkAndResumeActiveTripInBackground(service);
  } else if (actionId == kNotifActionSos) {
    debugPrint('[LisKo-BG-Diag] BackgroundService handling kNotifActionSos ("Need Help")');
    _bgSafetyCheckTimer?.cancel();
    _cancelBackgroundSafetyVibration('kNotifActionSos');
    final activeTrip = await const LocalStorageService().readActiveTrip();
    final dest = activeTrip?['destination'] as String? ?? 'Need Help';
    final tId = activeTrip?['tripId'] as String? ?? '';
    final totalSecs = activeTrip?['totalDurationSeconds'] as int? ?? 0;
    final startedMs = activeTrip?['startedAtMs'] as int?;
    final expMs = activeTrip?['expectedArrivalAtMs'] as int?;

    await _executeBackgroundEmergencyEscalation(
      service: service,
      destination: dest,
      tripId: tId,
      totalDurationSeconds: totalSecs,
      startedAtMs: startedMs,
      expectedArrivalAtMs: expMs,
      isManualSos: true,
    );
  }
}

Future<void> _checkAndResumeActiveTripInBackground(ServiceInstance service) async {
  debugPrint('[LisKo-BG-Diag] BackgroundService _checkAndResumeActiveTripInBackground() executing');

  // Process any pending persisted action first
  final pendingAction = await const LocalStorageService().readAndClearPendingAction();
  if (pendingAction != null && pendingAction.isNotEmpty) {
    debugPrint('[LisKo-BG-Diag] BackgroundService: Found pending notification action "$pendingAction"');
    await _handleBackgroundNotificationAction(service, pendingAction);
    if (pendingAction == kNotifActionSafe || pendingAction == kNotifActionSos) {
      return;
    }
  }

  final activeTrip = await const LocalStorageService().readActiveTrip();

  if (activeTrip == null) {
    debugPrint('[LisKo-BG-Diag] BackgroundService: No active trip record found in LocalStorageService (null). Stopping monitoring.');
    _bgPeriodicTimer?.cancel();
    _bgSafetyCheckTimer?.cancel();
    GeofenceService().stopMonitoring();
    await NotificationService().cancelPersistentTripNotification();
    service.stopSelf();
    return;
  }

  if (activeTrip['isActive'] != true) {
    debugPrint('[LisKo-BG-Diag] BackgroundService: Active trip record marked inactive in LocalStorageService. Stopping monitoring.');
    _bgPeriodicTimer?.cancel();
    _bgSafetyCheckTimer?.cancel();
    GeofenceService().stopMonitoring();
    await NotificationService().cancelPersistentTripNotification();
    service.stopSelf();
    return;
  }

  final String destination = activeTrip['destination'] as String? ?? 'Campus';
  final int? expMs = activeTrip['expectedArrivalAtMs'] as int?;
  final int? safetyMs = activeTrip['safetyCheckDeadlineMs'] as int?;
  final bool isArrived = activeTrip['isArrived'] as bool? ?? false;
  final bool isTimeout = activeTrip['isTimeoutWarning'] as bool? ?? false;
  final bool suppressArrivalUntilExit = activeTrip['suppressArrivalUntilExit'] as bool? ?? false;
  final String tripId = activeTrip['tripId'] as String? ?? '';
  final int totalSecs = activeTrip['totalDurationSeconds'] as int? ?? 45 * 60;
  final int? startedMs = activeTrip['startedAtMs'] as int?;

  final now = DateTime.now();
  final nowMs = now.millisecondsSinceEpoch;

  debugPrint(
    '[LisKo-BG-Diag] BackgroundService restoring trip: destination=$destination, '
    'expMs=$expMs, safetyMs=$safetyMs, isArrived=$isArrived, isTimeout=$isTimeout, '
    'suppressArrivalUntilExit=$suppressArrivalUntilExit, tripId=$tripId',
  );

  // CASE 4: Safety check active and expired (now >= safetyCheckDeadlineMs) -> Catch-up Emergency Escalation
  if (safetyMs != null && nowMs >= safetyMs && !_isBgEscalating) {
    debugPrint('[LisKo-BG-Diag] BackgroundService: Catch-up 90s safety check expired while closed. Escalating emergency alert.');
    await _executeBackgroundEmergencyEscalation(
      service: service,
      destination: destination,
      tripId: tripId,
      totalDurationSeconds: totalSecs,
      startedAtMs: startedMs,
      expectedArrivalAtMs: expMs,
      isManualSos: false,
    );
    return;
  }

  // CASE 3: Safety check active and window still open (now < safetyCheckDeadlineMs) -> Restore 90s response window
  if (safetyMs != null && nowMs < safetyMs) {
    final remainingWindowSecs = ((safetyMs - nowMs) / 1000).ceil();
    debugPrint('[LisKo-BG-Diag] BackgroundService: Catch-up 90s safety check active with $remainingWindowSecs s remaining.');
    await NotificationService().showTimeoutAlarm(destination);

    _scheduleNextVibrationPhase(safetyMs);

    _bgSafetyCheckTimer?.cancel();
    _bgSafetyCheckTimer = Timer(Duration(seconds: remainingWindowSecs), () async {
      await _executeBackgroundEmergencyEscalation(
        service: service,
        destination: destination,
        tripId: tripId,
        totalDurationSeconds: totalSecs,
        startedAtMs: startedMs,
        expectedArrivalAtMs: expMs,
        isManualSos: false,
      );
    });
    return;
  }

  // CASE 2: Trip active and now >= expectedArrivalAtMs without safety check -> Catch-up Timeout
  if (expMs != null && nowMs >= expMs && !isArrived && !isTimeout) {
    debugPrint('[LisKo-BG-Diag] BackgroundService: Catch-up Trip deadline expired while closed. Entering 90s timeout safety check.');
    await _handleBackgroundTimeoutDetected(
      service: service,
      destination: destination,
      tripId: tripId,
      totalDurationSeconds: totalSecs,
      startedAtMs: startedMs,
      expectedArrivalAtMs: expMs,
    );
    return;
  }

  // CASE 1: Trip active and ongoing (now < expectedArrivalAtMs, not arrived/timeout) -> Continuous Monitoring
  if (expMs != null && nowMs < expMs && !isArrived && !isTimeout) {
    _showNotification888(
      title: 'Lisko: Active Travel Timer',
      content: 'Heading to $destination',
      expectedArrivalAtMs: expMs,
    );

    // Start GPS Location Stream in Background Isolate
    await GeofenceService().startMonitoring(
      destination: destination,
      suppressArrivalUntilExit: suppressArrivalUntilExit,
      onArrival: (target, distance) async {
        debugPrint('[LisKo-BG-Diag] BackgroundService: Geofence arrival detected at ${distance.toStringAsFixed(1)}m from ${target.name}');
        await _handleBackgroundArrivalDetected(
          service: service,
          destination: target.name,
          tripId: tripId,
          totalDurationSeconds: totalSecs,
          startedAtMs: startedMs,
          expectedArrivalAtMs: expMs,
        );
      },
    );

    // Schedule exact one-shot deadline timer for remaining duration
    final remainingMs = expMs - nowMs;
    if (remainingMs > 0) {
      _bgDeadlineTimer?.cancel();
      debugPrint('[LisKo-BG-Diag] Deadline timer scheduled expMs=$expMs remainingMs=$remainingMs');
      _bgDeadlineTimer = Timer(Duration(milliseconds: remainingMs), () async {
        debugPrint('[LisKo-BG-Diag] Deadline timer fired');
        await _handleBackgroundTimeoutDetected(
          service: service,
          destination: destination,
          tripId: tripId,
          totalDurationSeconds: totalSecs,
          startedAtMs: startedMs,
          expectedArrivalAtMs: expMs,
        );
      });
    }

    // Secondary 30-second periodic timer fallback to catch missed timers or state recovery
    _bgPeriodicTimer?.cancel();
    _bgPeriodicTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final currentNow = DateTime.now();
      final currentMs = currentNow.millisecondsSinceEpoch;

      if (currentMs >= expMs) {
        _bgPeriodicTimer?.cancel();
        debugPrint('[LisKo-BG-Diag] BackgroundService: Periodic deadline check expired. Entering timeout.');
        await _handleBackgroundTimeoutDetected(
          service: service,
          destination: destination,
          tripId: tripId,
          totalDurationSeconds: totalSecs,
          startedAtMs: startedMs,
          expectedArrivalAtMs: expMs,
        );
      }
    });
  }
}

Future<void> _handleBackgroundArrivalDetected({
  required ServiceInstance service,
  required String destination,
  required String tripId,
  required int totalDurationSeconds,
  int? startedAtMs,
  int? expectedArrivalAtMs,
}) async {
  final current = await const LocalStorageService().readActiveTrip();
  if (current == null || current['isArrived'] == true) return;

  _bgDeadlineTimer?.cancel();
  debugPrint('[LisKo-BG-Diag] Deadline timer cancelled reason=arrival');

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final safetyDeadlineMs = nowMs + 90000;

  await const LocalStorageService().saveActiveTrip(
    isActive: true,
    destination: destination,
    totalDurationSeconds: totalDurationSeconds,
    expectedArrivalAtMs: expectedArrivalAtMs,
    isArrived: true,
    isTimeoutWarning: false,
    safetyCheckDeadlineMs: safetyDeadlineMs,
    tripId: tripId,
    startedAtMs: startedAtMs,
  );

  await NotificationService().showArrivalAlarm(destination);
  service.invoke('arrivalDetected', {'destination': destination});

  _scheduleNextVibrationPhase(safetyDeadlineMs);

  _bgSafetyCheckTimer?.cancel();
  _bgSafetyCheckTimer = Timer(const Duration(seconds: 90), () async {
    await _executeBackgroundEmergencyEscalation(
      service: service,
      destination: destination,
      tripId: tripId,
      totalDurationSeconds: totalDurationSeconds,
      startedAtMs: startedAtMs,
      expectedArrivalAtMs: expectedArrivalAtMs,
      isManualSos: false,
    );
  });
}

Future<void> _handleBackgroundTimeoutDetected({
  required ServiceInstance service,
  required String destination,
  required String tripId,
  required int totalDurationSeconds,
  int? startedAtMs,
  int? expectedArrivalAtMs,
}) async {
  final current = await const LocalStorageService().readActiveTrip();
  if (current == null || current['isActive'] != true) {
    debugPrint('[LisKo-BG-Diag] Timeout validation rejected reason=no_active_trip');
    return;
  }
  if (current['isArrived'] == true) {
    debugPrint('[LisKo-BG-Diag] Timeout validation rejected reason=already_arrived');
    return;
  }
  if (current['isTimeoutWarning'] == true) {
    debugPrint('[LisKo-BG-Diag] Timeout validation rejected reason=already_in_timeout_warning');
    return;
  }
  if (expectedArrivalAtMs != null && current['expectedArrivalAtMs'] != null) {
    final storedExp = current['expectedArrivalAtMs'] as int;
    if (storedExp != expectedArrivalAtMs) {
      debugPrint('[LisKo-BG-Diag] Timeout validation rejected reason=expectedArrivalAtMs_mismatch (storedExp=$storedExp != expectedArrivalAtMs=$expectedArrivalAtMs)');
      return;
    }
  }

  debugPrint('[LisKo-BG-Diag] Timeout validation accepted');

  _bgDeadlineTimer?.cancel();
  _bgPeriodicTimer?.cancel();

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final safetyDeadlineMs = nowMs + 90000;

  await const LocalStorageService().saveActiveTrip(
    isActive: true,
    destination: destination,
    totalDurationSeconds: totalDurationSeconds,
    expectedArrivalAtMs: expectedArrivalAtMs,
    isArrived: false,
    isTimeoutWarning: true,
    safetyCheckDeadlineMs: safetyDeadlineMs,
    tripId: tripId,
    startedAtMs: startedAtMs,
  );

  await NotificationService().showTimeoutAlarm(destination);
  service.invoke('timeoutDetected', {'destination': destination});

  _scheduleNextVibrationPhase(safetyDeadlineMs);

  _bgSafetyCheckTimer?.cancel();
  _bgSafetyCheckTimer = Timer(const Duration(seconds: 90), () async {
    await _executeBackgroundEmergencyEscalation(
      service: service,
      destination: destination,
      tripId: tripId,
      totalDurationSeconds: totalDurationSeconds,
      startedAtMs: startedAtMs,
      expectedArrivalAtMs: expectedArrivalAtMs,
      isManualSos: false,
    );
  });
}

Future<void> _executeBackgroundEmergencyEscalation({
  required ServiceInstance service,
  required String destination,
  required String tripId,
  required int totalDurationSeconds,
  int? startedAtMs,
  int? expectedArrivalAtMs,
  required bool isManualSos,
}) async {
  // Synchronous re-entrant guard acquired BEFORE any await
  if (_isBgEscalating) return;
  _isBgEscalating = true;
  _cancelBackgroundSafetyVibration('escalation');

  try {
    // Non-destructive peek at pending notification action
    final pendingAction = await const LocalStorageService().peekPendingAction();

    // Abort automatic escalation if user selected "I'm Safe" or "+15 MIN"
    // Do NOT erase pendingAction so the SAFE or EXTEND handler can take full ownership.
    if (!isManualSos && pendingAction == kNotifActionSafe) {
      debugPrint('[LisKo-BG-Diag] Escalation aborted: Pending "I\'m Safe" action detected.');
      return;
    }
    if (!isManualSos && pendingAction == kNotifActionExtend) {
      debugPrint('[LisKo-BG-Diag] Escalation aborted: Pending "+15 MIN" action detected.');
      return;
    }

    final bool effectiveIsManualSos = isManualSos || (pendingAction == kNotifActionSos);
    if (pendingAction == kNotifActionSos) {
      await const LocalStorageService().consumePendingActionIfMatches(kNotifActionSos);
    }

    // Immediate pre-SMS fresh state verification
    final freshTrip = await const LocalStorageService().readActiveTrip();
    if (freshTrip == null || freshTrip['isActive'] != true) {
      debugPrint('[LisKo-BG-Diag] Pre-SMS verification failed: trip is no longer active. Aborting escalation.');
      return;
    }
    if (!effectiveIsManualSos && freshTrip['isArrived'] != true && freshTrip['isTimeoutWarning'] != true) {
      debugPrint('[LisKo-BG-Diag] Pre-SMS verification failed: safety check is no longer active. Aborting escalation.');
      return;
    }

    debugPrint('[LisKo-BG-Diag] BackgroundService executing emergency SMS escalation.');

    double? lat;
    double? lng;
    double? acc;
    String? locationError;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      acc = pos.accuracy;
    } catch (e) {
      locationError = 'GPS acquisition timeout';
    }

    final sentList = await SmsAlertService().dispatchEmergencyAlert(
      destination: destination,
      latitude: lat,
      longitude: lng,
      accuracy: acc,
      locationError: locationError,
      isArrived: false,
    );

    await NotificationService().showEmergencySentNotification(sentList, permissionDenied: false);

    // Save trip record locally
    final storage = const LocalStorageService();
    final history = await storage.readTripHistory();
    final eventId = tripId.isNotEmpty ? tripId : DateTime.now().millisecondsSinceEpoch.toString();

    final newTrip = TripRecord(
      id: eventId,
      destination: destination,
      durationMinutes: totalDurationSeconds ~/ 60,
      status: effectiveIsManualSos ? 'Need Help' : 'Timer Expired',
      timestamp: DateTime.now(),
    );
    await storage.saveTripHistory([...history, newTrip]);

    if (tripId.isNotEmpty && startedAtMs != null) {
      FirebaseService().saveOrUpdateTrip(
        tripId: tripId,
        destination: destination,
        estimatedTravelMinutes: totalDurationSeconds ~/ 60,
        startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
        expectedArrivalAt: expectedArrivalAtMs != null ? DateTime.fromMillisecondsSinceEpoch(expectedArrivalAtMs) : null,
        completedAt: DateTime.now(),
        status: effectiveIsManualSos ? 'help_requested' : 'expired',
      );
    }

    FirebaseService().logEmergencyEvent(
      eventId: eventId,
      deviceId: 'local_device',
      tripId: tripId,
      latitude: lat ?? 0.0,
      longitude: lng ?? 0.0,
      emergencyType: effectiveIsManualSos ? 'SOS' : 'TIMEOUT_ESCALATION',
    );

    await storage.saveActiveTrip(isActive: false);
    _bgPeriodicTimer?.cancel();
    _bgSafetyCheckTimer?.cancel();
    GeofenceService().stopMonitoring();
    await NotificationService().cancelPersistentTripNotification();
    await NotificationService().cancelArrivalAlarm();
    service.stopSelf();
  } catch (e) {
    debugPrint('[LisKo-BG-Diag] Background emergency escalation error: $e');
  } finally {
    _isBgEscalating = false;
  }
}
