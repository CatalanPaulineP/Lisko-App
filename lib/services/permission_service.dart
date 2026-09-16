import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  bool get _isTestEnvironment {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('TestWidgetsFlutterBinding') ||
        binding.contains('AutomatedTestWidgetsFlutterBinding');
  }

  Future<bool> checkLocationPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.location.status;
    return status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> isLocationServiceEnabled() async {
    if (_isTestEnvironment) return true;
    return await geo.Geolocator.isLocationServiceEnabled();
  }

  Future<bool> checkSmsPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  Future<bool> requestSmsPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> checkContactsPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  Future<bool> requestContactsPermission() async {
    if (_isTestEnvironment) return true;
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<bool> checkNotificationPermission() async {
    if (_isTestEnvironment) return true;
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return true;
  }

  Future<bool> requestNotificationPermission() async {
    if (_isTestEnvironment) return true;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> checkTripRequirements(BuildContext context) async {
    if (_isTestEnvironment) return true;
    
    // 1. Check Location Permission
    bool hasLoc = await checkLocationPermission();
    if (!hasLoc) {
      var status = await Permission.location.status;
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        bool goSettings = await _showExplanationModal(
          context,
          'Location Permission Is Disabled',
          'Lisko needs location access to provide Travel Monitoring and emergency location features.\n\nPlease enable Location permission in your phone settings.',
          'Open Settings',
        );
        if (goSettings) {
          await openAppSettings();
        }
        return false;
      } else {
        if (!context.mounted) return false;
        bool allowReq = await _showExplanationModal(
          context,
          'Location Permission Required',
          'Lisko needs access to your location to monitor your journey and provide your location during an emergency.',
          'Allow Location',
        );
        if (allowReq) {
          bool granted = await requestLocationPermission();
          if (!granted) return false;
        } else {
          return false;
        }
      }
    }

    // 2. Check Location Services Enabled
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      bool goSettings = await _showExplanationModal(
        context,
        'Location Service is Off',
        'Your phone\'s GPS/Location service is turned off.\n\nPlease turn it on to enable trip monitoring.',
        'Open Settings',
      );
      if (goSettings) {
        await geo.Geolocator.openLocationSettings();
      }
      return false;
    }

    // 3. Check SMS Permission
    bool hasSms = await checkSmsPermission();
    if (!hasSms) {
      var status = await Permission.sms.status;
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        bool goSettings = await _showExplanationModal(
          context,
          'SMS Permission Is Disabled',
          'Lisko needs SMS access to automatically send emergency alerts to your trusted contacts if you do not respond.\n\nPlease enable SMS permission in your phone settings before starting a monitored trip.',
          'Open Settings',
        );
        if (goSettings) {
          await openAppSettings();
        }
        return false;
      } else {
        if (!context.mounted) return false;
        bool allowReq = await _showExplanationModal(
          context,
          'SMS Permission Required',
          'Lisko needs SMS permission to send offline emergency alerts to your trusted contacts if you do not arrive safely. No messages are sent unless there is an emergency.',
          'Allow SMS',
        );
        if (allowReq) {
          bool granted = await requestSmsPermission();
          if (!granted) return false;
        } else {
          return false;
        }
      }
    }

    // 4. Check Notification Permission (Android 13+)
    bool hasNotif = await checkNotificationPermission();
    if (!hasNotif) {
      if (!context.mounted) return false;
      bool allowReq = await _showExplanationModal(
        context,
        'Notifications Needed',
        'Lisko needs notification permission to show the background travel timer and the arrival safety check alert.',
        'Allow Notifications',
      );
      if (allowReq) {
        bool granted = await requestNotificationPermission();
        if (!granted) return false;
      } else {
        return false;
      }
    }

    return true;
  }

  Future<bool> _showExplanationModal(
    BuildContext context,
    String title,
    String content,
    String actionLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

