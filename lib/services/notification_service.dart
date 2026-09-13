import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    // According to error `The named parameter 'initializationSettings' isn't defined`
    // and `The named parameter 'settings' is required, but there's no corresponding argument`
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lisko_trip_channel',
      'LisKo Trip Monitoring',
      description: 'Ongoing background monitoring for your active travel.',
      importance: Importance.low,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
        
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'lisko_alarm_channel',
      'LisKo Arrival Alerts',
      description: 'High priority alerts for safety checks.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);
  }

  Future<void> showPersistentTripNotification(String destination, String remainingTime) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'lisko_trip_channel',
      'LisKo Trip Monitoring',
      channelDescription: 'Ongoing background monitoring for your active travel.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    
    await _flutterLocalNotificationsPlugin.show(
      id: 888,
      title: 'LisKo: 🚶 Travel Timer',
      body: '$destination - $remainingTime remaining',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> showArrivalAlarm(String destination) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Arrival Alerts',
      channelDescription: 'High priority alerts for safety checks.',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('safe_id', "I'm safe", titleColor: Color(0xFF4CAF50)),
        AndroidNotificationAction('delay_id', '+15 min', titleColor: Color(0xFF9E9E9E)),
        AndroidNotificationAction('sos_id', 'Need help', titleColor: Color(0xFFF44336)),
      ],
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    
    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: 'Did you arrive safely at $destination?',
      body: 'Confirm your safety within 90 seconds or your trusted contacts will automatically receive emergency SMS alerts with your live location.',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> showEmergencySentNotification(List<String> dispatchedTo) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'lisko_alarm_channel',
      'LisKo Arrival Alerts',
      channelDescription: 'High priority alerts for safety checks.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    
    final names = dispatchedTo.isNotEmpty ? dispatchedTo.join(', ') : 'trusted contacts';
    await _flutterLocalNotificationsPlugin.show(
      id: 1000,
      title: 'EMERGENCY SMS SENT',
      body: 'No response detected. Emergency SMS with live location broadcasted to $names.',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> cancelPersistentTripNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 888);
  }

  Future<void> cancelArrivalAlarm() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 999);
  }
}
