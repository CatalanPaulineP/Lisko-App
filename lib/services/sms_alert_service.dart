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
  }) async {
    await triggerHapticAlert();

    final contacts = await _storage.readContacts();
    if (contacts.isEmpty) {
      developer.log('SmsAlertService: No trusted contacts configured to receive SOS.');
      return [];
    }

    final coordText = (latitude != null && longitude != null)
        ? ' Live location: https://maps.google.com/?q=$latitude,$longitude'
        : '';

    final alertMessage = customMessage ??
        'LisKo Emergency Alert: Student did not confirm safety within 90 seconds of arriving at $destination.$coordText Please verify their safety immediately.';

    developer.log('SmsAlertService: Dispatching offline emergency SMS to ${contacts.length} recipients: "$alertMessage"');

    final dispatchedTo = <String>[];
    for (final contact in contacts) {
      if (!_isTestEnvironment) {
        final result = await BackgroundSms.sendMessage(
          phoneNumber: contact.phone,
          message: alertMessage,
        );
        if (result == SmsStatus.sent) {
          dispatchedTo.add('${contact.name} (${contact.phone})');
        } else {
          developer.log('SmsAlertService: Failed to send SMS to ${contact.phone}');
        }
      } else {
        dispatchedTo.add('${contact.name} (${contact.phone})');
      }
    }

    return dispatchedTo;
  }
}
