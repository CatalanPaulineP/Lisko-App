// ==============================================================================
// Lisko Mobile Safety Application — Notification Service
// File: lib/services/notification_service.dart
//
// Manages all system notification channels and alarm intents.
//
// Response Routing Architecture:
//   When the user taps an action button on the alarm notification (whether the
//   app is foregrounded, backgrounded, or terminated), the response flows through:
//
//   Foreground / Resumed:
//     onDidReceiveNotificationResponse → _handleNotificationResponse()
//       → NotificationService.onActionReceived (registered by HomeScreenState)
//
//   App Killed (terminated):
//     onDidReceiveBackgroundNotificationResponse → notificationBackgroundResponseHandler()
//       (top-level @pragma function in main.dart)
//       → SharedPreferences stores 'pending_notification_action'
//       → LaunchGate reads & dispatches on next app boot
// ==============================================================================

import 'dart:ui';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'sms_alert_service.dart';
import 'local_storage_service.dart';
import 'firebase_service.dart' as fs;

// ---------------------------------------------------------------------------
// Notification action ID constants
// ---------------------------------------------------------------------------
const String kNotifActionSafe = 'safe_id';
const String kNotifActionExtend = 'delay_id';
const String kNotifActionSos = 'sos_id';

// ---------------------------------------------------------------------------
// Background notification response handler (app fully terminated or in background).
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(
  NotificationResponse response,
) async {
  final actionId = response.actionId ?? response.payload ?? '';
  if (actionId.isEmpty) return;
  debugPrint('[NotificationService-BG] Action tapped: "$actionId"');

  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (_) {}

  if (actionId == kNotifActionSafe || actionId == kNotifActionExtend) {
    try {
      final storage = const LocalStorageService();
      final data = await storage.readActiveTrip();
      if (data != null && data['isActive'] == true) {
        final tripId = data['tripId'] as String? ?? '';
        final dest = data['destination'] as String? ?? '';
        final startedMs = data['startedAtMs'] as int?;
        final expectedMs = data['expectedArrivalAtMs'] as int?;
        final totalSecs = data['totalDurationSeconds'] as int? ?? 0;

        if (actionId == kNotifActionSafe) {
          await storage.saveActiveTrip(isActive: false);
          if (tripId.isNotEmpty && startedMs != null) {
            await fs.FirebaseService().saveOrUpdateTrip(
              tripId: tripId,
              destination: dest,
              estimatedTravelMinutes: totalSecs ~/ 60,
              startedAt: DateTime.fromMillisecondsSinceEpoch(startedMs),
              expectedArrivalAt: expectedMs != null ? DateTime.fromMillisecondsSinceEpoch(expectedMs) : null,
              completedAt: DateTime.now(),
              status: 'arrived',
            );
            final history = await storage.readTripHistory();
            history.add(TripRecord(
              id: tripId, destination: dest, durationMinutes: totalSecs ~/ 60,
              status: 'Completed', timestamp: DateTime.fromMillisecondsSinceEpoch(startedMs),
            ));
            await storage.saveTripHistory(history);
          }
        } else if (actionId == kNotifActionExtend) {
          final now = DateTime.now();
          final currentExpected = expectedMs != null ? DateTime.fromMillisecondsSinceEpoch(expectedMs) : now;
          final newExpected = currentExpected.isBefore(now) ? now.add(const Duration(minutes: 15)) : currentExpected.add(const Duration(minutes: 15));
          await storage.saveActiveTrip(
            isActive: true,
            destination: dest,
            totalDurationSeconds: totalSecs,
            expectedArrivalAtMs: newExpected.millisecondsSinceEpoch,
            tripId: tripId,
            startedAtMs: startedMs,
            isArrived: false,
            isTimeoutWarning: false,
          );
          if (tripId.isNotEmpty && startedMs != null) {
            await fs.FirebaseService().saveOrUpdateTrip(
              tripId: tripId,
              destination: dest,
              estimatedTravelMinutes: totalSecs ~/ 60,
              startedAt: DateTime.fromMillisecondsSinceEpoch(startedMs),
              expectedArrivalAt: newExpected,
              status: 'extended',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService-BG] Database sync error: $e');
    }
  }

  final sendPort = IsolateNameServer.lookupPortByName('lisko_notif_port');
  if (sendPort != null) {
    sendPort.send(actionId);
  } else {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification_action', actionId);
    if (actionId == kNotifActionSos) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        double? lat;
        double? lng;
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            lat = lastPosition.latitude;
            lng = lastPosition.longitude;
          } else {
            final storage = const LocalStorageService();
            final data = await storage.readActiveTrip();
            if (data != null) {
              lat = (data['cachedLat'] as num?)?.toDouble();
              lng = (data['cachedLng'] as num?)?.toDouble();
            }
          }
        }
        await SmsAlertService().sendManualSos(latitude: lat, longitude: lng);

        final storage = const LocalStorageService();
        final data = await storage.readActiveTrip();
        if (data != null && data['isActive'] == true) {
          final tripId = data['tripId'] as String? ?? '';
          final dest = data['destination'] as String? ?? 'Manual SOS';
          final startedMs = data['startedAtMs'] as int?;
          final expectedMs = data['expectedArrivalAtMs'] as int?;
          final totalSecs = data['totalDurationSeconds'] as int? ?? 0;

          await storage.saveActiveTrip(isActive: false);

          final history = await storage.readTripHistory();
          final eventId = tripId.isNotEmpty ? tripId : DateTime.now().millisecondsSinceEpoch.toString();
          history.add(TripRecord(
            id: eventId,
            destination: dest,
            durationMinutes: totalSecs ~/ 60,
            status: 'Need Help',
            timestamp: startedMs != null ? DateTime.fromMillisecondsSinceEpoch(startedMs) : DateTime.now(),
          ));
          await storage.saveTripHistory(history);

          if (tripId.isNotEmpty && startedMs != null) {
            await fs.FirebaseService().saveOrUpdateTrip(
              tripId: tripId,
              destination: dest,
              estimatedTravelMinutes: totalSecs ~/ 60,
              startedAt: DateTime.fromMillisecondsSinceEpoch(startedMs),
              expectedArrivalAt: expectedMs != null ? DateTime.fromMillisecondsSinceEpoch(expectedMs) : null,
              completedAt: DateTime.now(),
              status: 'help_requested',
            );
          }
          fs.FirebaseService().logEmergencyEvent(
            eventId: eventId,
            deviceId: 'local_device',
            tripId: tripId,
            latitude: lat ?? 0.0,
            longitude: lng ?? 0.0,
            emergencyType: 'SOS',
          );
        }
      } catch (e) {
        debugPrint('[NotificationService-BG] Failed background SOS dispatch: $e');
      }
      await prefs.remove('pending_notification_action');
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // Static callback — registered by HomeScreenState.initState(),
  // cleared in HomeScreenState.dispose().
  //
  // This lets the notification response reach the live widget without a
  // GlobalKey or a third-party state manager.
  // ---------------------------------------------------------------------------
  static void Function(String actionId)? onActionReceived;
  static ReceivePort? _receivePort;

  /// Internal response router: called for foreground and background-resumed taps.
  static void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId ?? response.payload ?? '';
    debugPrint(
      '[NotificationService] Response received - actionId: "$actionId"',
    );
    if (actionId.isNotEmpty) {
      onActionReceived?.call(actionId);
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    // Setup IsolateNameServer port to listen to the background isolate
    _receivePort ??= ReceivePort();
    IsolateNameServer.removePortNameMapping('lisko_notif_port');
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      'lisko_notif_port',
    );
    _receivePort!.listen((message) {
      if (message is String) {
        onActionReceived?.call(message);
      }
    });

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      // Foreground and background-resumed taps → static callback.
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      // App-killed taps → top-level @pragma function defined in main.dart.
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundResponseHandler,
    );

    // Low-priority persistent channel for active trip countdown bar.
    const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
      'lisko_trip_channel',
      'Lisko Trip Monitoring',
      description: 'Ongoing background monitoring for your active travel.',
      importance: Importance.low,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(tripChannel);

    final Int64List alarmVibrationPattern = Int64List.fromList([
      0,
      1000,
      500,
      1000,
      500,
      1000,
      500,
      1000,
    ]);

    // Max-priority alarm channel - high importance for heads-up presentation.
    final AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      description: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      // Re-enabled system vibration because Dart background timers fail to vibrate when the screen is off.
      enableVibration: true,
      vibrationPattern: alarmVibrationPattern,
      playSound: true,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannel);
  }

  // ---------------------------------------------------------------------------
  // Notification display methods
  // ---------------------------------------------------------------------------

  Future<void> showPersistentTripNotification(
    String destination,
    String remainingTime,
  ) async {
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_trip_channel',
      'Lisko Trip Monitoring',
      channelDescription:
          'Ongoing background monitoring for your active travel.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 888,
      title: 'Lisko: Active Travel Timer',
      body: '$destination - $remainingTime remaining',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> showTimeoutAlarm(String destination) async {
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: false,
      autoCancel: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        1000,
        500,
        1000,
        500,
        1000,
        500,
        1000,
      ]),
      playSound: true,
      styleInformation: BigTextStyleInformation(
        'Did you arrive safely at $destination?',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          kNotifActionSafe,
          "I'm Safe",
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kNotifActionExtend,
          '+15 mins',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kNotifActionSos,
          'Need Help',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: "LisKo Travel Reminder",
      body: 'Did you arrive safely at $destination?',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> showArrivalAlarm(String destination) async {
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: false,
      autoCancel: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        1000,
        500,
        1000,
        500,
        1000,
        500,
        1000,
      ]),
      playSound: true,
      styleInformation: BigTextStyleInformation(
        'Did you arrive safely at $destination?',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          kNotifActionSafe,
          "I'm Safe",
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kNotifActionExtend,
          '+15 mins',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          kNotifActionSos,
          'Need Help',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: 'LisKo Travel Reminder',
      body: 'Did you arrive safely at $destination?',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> showEmergencySentNotification(
    List<String> dispatchedTo, {
    bool permissionDenied = false,
    bool isManualSos = false,
  }) async {
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.high,
    );

    if (permissionDenied) {
      await _flutterLocalNotificationsPlugin.show(
        id: 1000,
        title: 'EMERGENCY SMS FAILED',
        body:
            'SMS permission was denied. Could not dispatch offline emergency alerts to your contacts.',
        notificationDetails: NotificationDetails(android: details),
      );
      return;
    }

    if (dispatchedTo.isEmpty) {
      await _flutterLocalNotificationsPlugin.show(
        id: 1000,
        title: 'EMERGENCY SMS FAILED',
        body:
            'Could not send SMS to any trusted contacts. Please check your signal or add valid contacts.',
        notificationDetails: NotificationDetails(android: details),
      );
      return;
    }

    final body = isManualSos
        ? 'EMERGENCY SMS SENT - student clicked the sos button for help.'
        : 'EMERGENCY SMS SENT - No response detected. Emergency SMS with live location broadcasted to trusted contacts.';

    await _flutterLocalNotificationsPlugin.show(
      id: 1000,
      title: 'EMERGENCY SMS SENT',
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  // ---------------------------------------------------------------------------
  // Cancellation
  // ---------------------------------------------------------------------------

  Future<void> cancelPersistentTripNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 888);
  }

  Future<void> cancelArrivalAlarm() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 999);
  }

  Future<void> showSimpleTestNotification() async {
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        1000,
        500,
        1000,
        500,
        1000,
        500,
        1000,
      ]),
      playSound: true,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 9999,
      title: 'LisKo Heads-Up Test',
      body: 'This is a simple high-priority notification test.',
      notificationDetails: NotificationDetails(android: details),
    );
  }
}
