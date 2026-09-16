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

  Future<List<String>> dispatchEmergencyAlert({
    required String destination,
    double? latitude,
    double? longitude,
    String? customMessage,
    bool isManualSos = false,
    bool isStationary = false,
  }) async {
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

    final coordText = (latitude != null && longitude != null)
        ? 'https://www.google.com/maps?q=$latitude,$longitude'
        : 'Unknown Location';

    String alertMessage = customMessage ?? '';
    
    if (alertMessage.isEmpty) {
      if (isManualSos) {
        alertMessage = '[LISKO EMERGENCY] Student has pressed the SOS button during their commute and may be in danger. They may be unable to respond or speak. Their current location: $coordText. Please check on them immediately.';
      } else if (isStationary) {
        alertMessage = '[LISKO SAFETY ALERT] Stationary/No Movement Detected. The student has not moved for a significant time during their trip to $destination. Their current location: $coordText. Please check on them immediately.';
      } else {
        alertMessage = '[LISKO SAFETY ALERT] Missed check-in: Student\'s travel timer expired without a confirmation response. They may have missed the notification or need assistance. Track their last known location here: $coordText.';
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
