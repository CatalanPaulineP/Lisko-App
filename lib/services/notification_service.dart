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
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'sms_alert_service.dart';

// ---------------------------------------------------------------------------
// Notification action ID constants
// ---------------------------------------------------------------------------
const String kNotifActionSafe   = 'safe_id';
const String kNotifActionExtend = 'delay_id';
const String kNotifActionSos    = 'sos_id';

// ---------------------------------------------------------------------------
// Background notification response handler (app fully terminated or in background).
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
void notificationBackgroundResponseHandler(NotificationResponse response) async {
  final actionId = response.actionId ?? response.payload ?? '';
  if (actionId.isEmpty) return;
  debugPrint('[NotificationService-BG] Action tapped: "$actionId"');

  final sendPort = IsolateNameServer.lookupPortByName('lisko_notif_port');
  if (sendPort != null) {
    // Main isolate is still alive! Send it directly so it acts immediately without launching the app.
    sendPort.send(actionId);
  } else {
    // App is fully terminated, save to SharedPreferences for next boot.
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
          }
        }
        final smsService = SmsAlertService();
        await smsService.sendManualSos(latitude: lat, longitude: lng);
      } catch (e) {
        debugPrint('[NotificationService-BG] Failed background SOS dispatch: $e');
      }
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
    debugPrint('[NotificationService] Response received - actionId: "$actionId"');
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
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, 'lisko_notif_port');
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
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundResponseHandler,
    );

    // Low-priority persistent channel for active trip countdown bar.
    const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
      'lisko_trip_channel',
      'Lisko Trip Monitoring',
      description: 'Ongoing background monitoring for your active travel.',
      importance: Importance.low,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(tripChannel);

    // Max-priority alarm channel – high importance for heads-up presentation.
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'lisko_alarm_channel',
      'LisKo Travel Reminder',
      description: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      // System vibration disabled – custom Vibration.vibrate() loop handles haptics.
      enableVibration: false,
      playSound: true,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);
  }

  // ---------------------------------------------------------------------------
  // Notification display methods
  // ---------------------------------------------------------------------------

  Future<void> showPersistentTripNotification(
      String destination, String remainingTime) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_trip_channel',
      'Lisko Trip Monitoring',
      channelDescription: 'Ongoing background monitoring for your active travel.',
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
      notificationDetails: const NotificationDetails(android: details),
    );
  }

  Future<void> showTimeoutAlarm(String destination) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'Lisko Arrival Alerts',
      channelDescription:
          'High priority safety check alarm - wakes device like a native alarm clock.',
      importance: Importance.max,
      priority: Priority.max,
      
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      enableVibration: false,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(kNotifActionSafe,   "I'm Safe",   showsUserInterface: false),
        AndroidNotificationAction(kNotifActionExtend, '+15 mins',   showsUserInterface: false),
        AndroidNotificationAction(kNotifActionSos,    'Need Help',  showsUserInterface: false),
      ],
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: "LisKo Travel Reminder",
      body: 'Did you arrive safely at $destination?',
      notificationDetails: const NotificationDetails(android: details),
    );
  }
  Future<void> showArrivalAlarm(String destination) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'Lisko Arrival Alerts',
      channelDescription:
          'High priority safety check alarm — wakes device like a native alarm clock.',
      importance: Importance.max,
      priority: Priority.max,
      // fullScreenIntent: true → Android wakes the screen and overlays the lock
      
      
      ongoing: true,
      autoCancel: false,
      // AndroidNotificationCategory.alarm tells the OS this is time-critical.
      category: AndroidNotificationCategory.alarm,
      enableVibration: false,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(kNotifActionSafe,   "I'm Safe",   showsUserInterface: false),
        AndroidNotificationAction(kNotifActionExtend, '+15 mins',   showsUserInterface: false),
        AndroidNotificationAction(kNotifActionSos,    'Need Help',  showsUserInterface: false),
      ],
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: 'LisKo Travel Reminder',
      body: 'Did you arrive safely at $destination?',
      notificationDetails: const NotificationDetails(android: details),
    );
  }

  Future<void> showStationaryAlarm(String destination) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'Lisko Arrival Alerts',
      channelDescription:
          'High priority safety check alarm - wakes device like a native alarm clock.',
      importance: Importance.max,
      priority: Priority.max,
      
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      enableVibration: false,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(kNotifActionExtend, '+15 min / Traffic', showsUserInterface: false),
        AndroidNotificationAction(kNotifActionSos,    'NEED HELP',  showsUserInterface: false),
      ],
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 999, // use same ID so it replaces/cancels arrival if somehow concurrent
      title: 'Are you stuck?',
      body: "We detected little or no movement during your trip to $destination. If you do not respond in 90s, we will automatically alert your emergency contacts.",
      notificationDetails: const NotificationDetails(android: details),
    );
  }

  Future<void> showEmergencySentNotification(List<String> dispatchedTo, {bool permissionDenied = false, bool isManualSos = false}) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'Lisko Arrival Alerts',
      channelDescription: 'High priority alerts for safety checks.',
      importance: Importance.max,
      priority: Priority.high,
    );

    if (permissionDenied) {
      await _flutterLocalNotificationsPlugin.show(
        id: 1000,
        title: 'EMERGENCY SMS FAILED',
        body: 'SMS permission was denied. Could not dispatch offline emergency alerts to your contacts.',
        notificationDetails: const NotificationDetails(android: details),
      );
      return;
    }

    if (dispatchedTo.isEmpty) {
      await _flutterLocalNotificationsPlugin.show(
        id: 1000,
        title: 'EMERGENCY SMS FAILED',
        body: 'Could not send SMS to any trusted contacts. Please check your signal or add valid contacts.',
        notificationDetails: const NotificationDetails(android: details),
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
      notificationDetails: const NotificationDetails(android: details),
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
}

