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
import 'package:flutter_background_service/flutter_background_service.dart';
import 'local_storage_service.dart';

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

  try {
    final bgService = FlutterBackgroundService();
    final isRunning = await bgService.isRunning();

    if (isRunning) {
      debugPrint('[NotificationService-BG] BackgroundService is running. Invoking notificationAction directly without saving pending action.');
      bgService.invoke('notificationAction', {'actionId': actionId});
    } else {
      debugPrint('[NotificationService-BG] BackgroundService is NOT running. Saving pending action "$actionId" and starting service.');
      final storage = const LocalStorageService();
      await storage.savePendingAction(actionId);
      await bgService.startService();
    }
  } catch (e) {
    debugPrint('[NotificationService-BG] FlutterBackgroundService wake error: $e');
  }

  final sendPort = IsolateNameServer.lookupPortByName('lisko_notif_port');
  if (sendPort != null) {
    sendPort.send(actionId);
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
  static void _handleNotificationResponse(NotificationResponse response) async {
    final actionId = response.actionId ?? response.payload ?? '';
    debugPrint(
      '[NotificationService] Response received - actionId: "$actionId"',
    );
    if (actionId.isEmpty) return;

    if (actionId == kNotifActionSafe) {
      final data = await const LocalStorageService().readActiveTrip();
      final isActive = (data != null && data['isActive'] == true);
      if (!isActive) {
        debugPrint('[LisKo-Action] ignoring stale safe_id because trip is inactive');
        return;
      }
    }

    onActionReceived?.call(actionId);
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


    // Max-priority alarm channel (Sound & Vibrate) - high importance for heads-up presentation.
    const AndroidNotificationChannel alarmChannelSound = AndroidNotificationChannel(
      'lisko_alarm_channel_v2',
      'LisKo Travel Reminder',
      description: 'Arrival reminders and travel safety confirmation with sound',
      importance: Importance.max,
      enableVibration: false,
      playSound: true,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannelSound);

    // Max-priority alarm channel (Vibration Only) - high importance for heads-up presentation without sound.
    const AndroidNotificationChannel alarmChannelVibrate = AndroidNotificationChannel(
      'lisko_alarm_vibrate_v1',
      'LisKo Travel Reminder (Vibration Only)',
      description: 'Arrival reminders and travel safety confirmation without sound',
      importance: Importance.max,
      enableVibration: false,
      playSound: false,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannelVibrate);
  }

  /// Dedicated background-safe initialization method for the BackgroundService isolate.
  /// Initializes local notifications plugin and creates channels WITHOUT registering
  /// UI action callbacks, IsolateNameServer mappings, or background response handlers.
  Future<void> initializeForBackgroundService() async {
    if (_isTestEnvironment) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
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

    // Max-priority alarm channel (Sound & Vibrate)
    const AndroidNotificationChannel alarmChannelSound = AndroidNotificationChannel(
      'lisko_alarm_channel_v2',
      'LisKo Travel Reminder',
      description: 'Arrival reminders and travel safety confirmation with sound',
      importance: Importance.max,
      enableVibration: false,
      playSound: true,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannelSound);

    // Max-priority alarm channel (Vibration Only)
    const AndroidNotificationChannel alarmChannelVibrate = AndroidNotificationChannel(
      'lisko_alarm_vibrate_v1',
      'LisKo Travel Reminder (Vibration Only)',
      description: 'Arrival reminders and travel safety confirmation without sound',
      importance: Importance.max,
      enableVibration: false,
      playSound: false,
      showBadge: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannelVibrate);

    debugPrint('[LisKo-Notif889] background notification init complete');
  }

  bool get _isTestEnvironment {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('TestWidgetsFlutterBinding') ||
        binding.contains('AutomatedTestWidgetsFlutterBinding');
  }

  // ---------------------------------------------------------------------------
  // Notification display methods
  // ---------------------------------------------------------------------------

  Future<void> showPersistentTripNotification(
    String destination,
    String remainingTime, {
    int? expectedArrivalAtMs,
  }) async {
    if (_isTestEnvironment) return;
    final title = 'Lisko: Active Travel Timer';
    final content = 'Heading to $destination';

    try {
      final bgService = FlutterBackgroundService();
      if (await bgService.isRunning()) {
        bgService.invoke('updateNotification', {
          'title': title,
          'content': content,
          'expectedArrivalAtMs': expectedArrivalAtMs,
        });
      }
    } catch (_) {}
  }

  Future<void> showTimeoutAlarm(String destination) async {
    if (_isTestEnvironment) return;
    final alertMode = await const LocalStorageService().readAlertMode();
    final bool playSound = (alertMode == 'Sounds & Vibrate');
    final String channelId = playSound ? 'lisko_alarm_channel_v2' : 'lisko_alarm_vibrate_v1';

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      channelId,
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      ongoing: false,
      autoCancel: false,
      enableVibration: false,
      playSound: playSound,
      styleInformation: BigTextStyleInformation(
        'Estimated travel time to $destination has ended.',
      ),
      actions: const <AndroidNotificationAction>[
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
      body: 'Estimated travel time to $destination has ended.',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> showArrivalAlarm(String destination) async {
    if (_isTestEnvironment) return;
    final alertMode = await const LocalStorageService().readAlertMode();
    final bool playSound = (alertMode == 'Sounds & Vibrate');
    final String channelId = playSound ? 'lisko_alarm_channel_v2' : 'lisko_alarm_vibrate_v1';

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      channelId,
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      ongoing: false,
      autoCancel: false,
      enableVibration: false,
      playSound: playSound,
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
    if (_isTestEnvironment) return;
    final alertMode = await const LocalStorageService().readAlertMode();
    final bool playSound = (alertMode == 'Sounds & Vibrate');
    final String channelId = playSound ? 'lisko_alarm_channel_v2' : 'lisko_alarm_vibrate_v1';

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      channelId,
      'LisKo Travel Reminder',
      channelDescription: 'Arrival reminders and travel safety confirmation',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
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
    if (_isTestEnvironment) return;
    debugPrint('[LisKo-BG-Diag] cancelPersistentTripNotification(888) called');
    await _flutterLocalNotificationsPlugin.cancel(id: 888);
  }

  Future<void> cancelArrivalAlarm() async {
    if (_isTestEnvironment) return;
    await _flutterLocalNotificationsPlugin.cancel(id: 999);
  }

  Future<void> showSimpleTestNotification() async {
    final alertMode = await const LocalStorageService().readAlertMode();
    final bool playSound = (alertMode == 'Sounds & Vibrate');
    final String channelId = playSound ? 'lisko_alarm_channel_v2' : 'lisko_alarm_vibrate_v1';

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      channelId,
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
      playSound: playSound,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: 9999,
      title: 'LisKo Heads-Up Test',
      body: 'This is a simple high-priority notification test.',
      notificationDetails: NotificationDetails(android: details),
    );
  }
}
