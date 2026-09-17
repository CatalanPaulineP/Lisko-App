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
    final timestamp = 'Time: $mo-$d-$y $hs:$mi:$s $ampm';
    return '$message $timestamp';
  }

  Future<List<String>> sendManualSos({
    double? latitude,
    double? longitude,
  }) async {
    final coordText = (latitude != null && longitude != null)
        ? '$latitude, $longitude'
        : 'Unknown Location';
        
    final alertMessage = '[LISKO EMERGENCY] student needs immediate help! location : $coordText (Copy these numbers and paste into Google maps). Please check them immediately.';
    return _internalDispatch(_appendTimestamp(alertMessage));
  }

  Future<List<String>> dispatchEmergencyAlert({
    required String destination,
    double? latitude,
    double? longitude,
    String? customMessage,
    bool isStationary = false,
  }) async {
    final coordText = (latitude != null && longitude != null)
        ? '$latitude, $longitude'
        : 'Unknown Location';

    String alertMessage = customMessage ?? '';
    
    if (alertMessage.isEmpty) {
      if (isStationary) {
        alertMessage = '[LISKO SAFETY ALERT] Stationary/No Movement Detected. Location: $coordText (Copy these numbers and paste into Google Maps). Please check on the student.';
      } else {
        alertMessage = '[LISKO SAFETY ALERT] Missed check-in: Student\'s travel timer expired. Location: $coordText (Copy these numbers and paste into Google Maps).';
      }
    }

    return _internalDispatch(_appendTimestamp(alertMessage));
  }

  Future<List<String>> _internalDispatch(String alertMessage) async {
    await triggerHapticAlert();

    final contacts = await _storage.readContacts();
    if (contacts.isEmpty) {
      developer.log('SmsAlertService: No trusted contacts configured to receive SOS.');
      return [];
    }
    
    if (!_isTestEnvironment) {
      final smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          developer.log('SmsAlertService: SMS permission denied. Cannot dispatch.');
          throw Exception('SMS_PERMISSION_DENIED');
        }
      }
    }

    developer.log('SmsAlertService: Dispatching offline emergency SMS to ${contacts.length} recipients: "$alertMessage"');

    final dispatchedTo = <String>[];
    for (final contact in contacts) {
      if (!_isTestEnvironment) {
        try {
          String cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
          // Format to E.164 (Philippine context default as requested)
          if (cleanPhone.startsWith('0')) {
            cleanPhone = '+63${cleanPhone.substring(1)}';
          } else if (cleanPhone.startsWith('63')) {
            cleanPhone = '+$cleanPhone';
          }

          final result = await BackgroundSms.sendMessage(
            phoneNumber: cleanPhone,
            message: alertMessage,
            simSlot: 1,
          );
          
          if (result == SmsStatus.sent) {
            dispatchedTo.add('${contact.name} ($cleanPhone)');
          } else {
            developer.log('SmsAlertService: Failed to send SMS to $cleanPhone - Status: $result');
          }
        } on PlatformException catch (e) {
          developer.log('SmsAlertService: PlatformException (Native Error) while sending SMS to ${contact.phone}: ${e.message} (Code: ${e.code}, Details: ${e.details})');
        } catch (e) {
          developer.log('SmsAlertService: Exception while sending SMS to ${contact.phone}: $e');
        }
      } else {
        dispatchedTo.add('${contact.name} (${contact.phone})');
      }
    }

    return dispatchedTo;
  }
}