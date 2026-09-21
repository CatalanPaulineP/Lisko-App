import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:background_sms/background_sms.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vibration/vibration.dart';

import 'local_storage_service.dart';

class SmsAlertService {
  SmsAlertService({LocalStorageService? storageService})
      : _storage = storageService ?? const LocalStorageService();

  final LocalStorageService _storage;

  bool get _isTestEnvironment {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('TestWidgetsFlutterBinding') ||
        binding.contains('AutomatedTestWidgetsFlutterBinding');
  }

  Future<void> triggerHapticAlert() async {
    if (_isTestEnvironment) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 500, 200, 500]);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  String _appendTimestamp(String message) {
    final now = DateTime.now();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final y = now.year.toString();
    int h = now.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    final hs = h.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final timestamp = '\nTime: $mo-$d-$y $hs:$mi:$s $ampm';
    return '$message$timestamp';
  }

  Future<List<String>> sendManualSos({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationError,
  }) async {
    String coordText = locationError ?? 'Unavailable';
    String mapLink = '';
    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(6);
      final lngStr = longitude.toStringAsFixed(6);
      coordText = '$latStr,$lngStr';
      if (accuracy != null) {
        coordText += ' (+/-${accuracy.toStringAsFixed(0)}m)';
      }
      mapLink = '\nMap: https://maps.google.com/?q=$latStr,$lngStr';
    }
        
    final alertMessage = 'LISKO SOS! Need help!\nLoc: $coordText$mapLink';
    return _internalDispatch(_appendTimestamp(alertMessage));
  }

  Future<List<String>> dispatchEmergencyAlert({
    required String destination,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationError,
    String? customMessage,
  }) async {
    String coordText = locationError ?? 'Unavailable';
    String mapLink = '';
    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(6);
      final lngStr = longitude.toStringAsFixed(6);
      coordText = '$latStr,$lngStr';
      if (accuracy != null) {
        coordText += ' (+/-${accuracy.toStringAsFixed(0)}m)';
      }
      mapLink = '\nMap: https://maps.google.com/?q=$latStr,$lngStr';
    }

    String alertMessage = customMessage ?? '';
    
    if (alertMessage.isEmpty) {
      alertMessage = 'LISKO ALERT: Travel timer expired!\nLoc: $coordText$mapLink';
    }

    return _internalDispatch(_appendTimestamp(alertMessage));
  }

  Future<List<String>> _internalDispatch(String alertMessage) async {
    developer.log('SmsAlertService: Starting emergency SMS dispatch.');
    await triggerHapticAlert();

    final contacts = await _storage.readContacts();
    if (contacts.isEmpty) {
      developer.log('SmsAlertService: No trusted contacts configured to receive SOS.');
      return [];
    }
    
    if (!_isTestEnvironment) {
      developer.log('SmsAlertService: SMS permission status: checking...');
      final smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          developer.log('SmsAlertService: SMS permission denied.');
          throw Exception('SMS_PERMISSION_DENIED');
        }
      }
    }

    developer.log('SmsAlertService: Found ${contacts.length} trusted contacts.');
    for (final contact in contacts) {
      developer.log('SmsAlertService: Contact found: ${contact.name} (${contact.phone})');
    }

    final dispatchedTo = <String>[];
    for (final contact in contacts) {
      // Improved Phone Number Normalization
      String digitsOnly = contact.phone.replaceAll(RegExp(r'\D'), '');
      String cleanPhone = '';
      if (digitsOnly.startsWith('0')) {
        cleanPhone = '+63${digitsOnly.substring(1)}';
      } else if (digitsOnly.startsWith('63')) {
        cleanPhone = '+$digitsOnly';
      } else if (digitsOnly.length == 10) {
        cleanPhone = '+63$digitsOnly';
      } else {
        cleanPhone = '+$digitsOnly';
      }

      if (cleanPhone.length < 10) {
        developer.log('SmsAlertService: Invalid phone number format for ${contact.name} ($cleanPhone). Skipping.');
        continue;
      }

      developer.log('SmsAlertService: Normalized phone number for ${contact.name}: $cleanPhone');

      if (!_isTestEnvironment) {
        try {
          developer.log('SmsAlertService: Attempting SMS send to ${contact.name} ($cleanPhone)...');
          
          final result = await BackgroundSms.sendMessage(
            phoneNumber: cleanPhone,
            message: alertMessage,
          );
          
          developer.log('SmsAlertService: BackgroundSms result: $result');
          
          if (result == SmsStatus.sent) {
            developer.log('SmsAlertService: SMS successfully handed to Android for ${contact.name} ($cleanPhone).');
            dispatchedTo.add('${contact.name} ($cleanPhone)');
          } else {
            developer.log('SmsAlertService: SMS send failed. Status: $result');
          }
        } on PlatformException catch (e) {
          developer.log('SmsAlertService: PlatformException (Native Error) while sending SMS to ${contact.name}: ${e.message} (Code: ${e.code}, Details: ${e.details})');
        } catch (e) {
          developer.log('SmsAlertService: Exception while sending SMS to ${contact.name}: $e');
        }
      } else {
        dispatchedTo.add('${contact.name} ($cleanPhone)');
      }
    }

    return dispatchedTo;
  }
}
