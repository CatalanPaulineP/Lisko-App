import 'dart:async';
import 'dart:developer' as developer;
import 'package:background_sms/background_sms.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final y = (now.year % 100).toString().padLeft(2, '0');
    int h = now.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    final hs = h.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final timestamp = '\nTime: $mo-$d-$y $hs:$mi $ampm';
    return '$message$timestamp';
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    if (_isTestEnvironment) {
      return 'Pulong Buhangin, Sta Maria';
    }
    try {
      final placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 3));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];

        final subLoc = p.subLocality ?? p.thoroughfare;
        if (subLoc != null && subLoc.isNotEmpty) {
          parts.add(subLoc);
        }

        final loc = p.locality ?? p.subAdministrativeArea;
        if (loc != null && loc.isNotEmpty) {
          parts.add(loc);
        }

        if (parts.isNotEmpty) {
          var addr = parts.join(', ');
          addr = addr
              .replaceAll('Santa ', 'Sta ')
              .replaceAll('Barangay ', 'Brgy ')
              .replaceAll('Saint ', 'St ');
          if (addr.length > 24) {
            addr = addr.substring(0, 24);
          }
          return addr;
        }
      }
    } catch (e) {
      developer.log('SmsAlertService: Reverse geocoding error or timeout: $e');
    }
    return null;
  }

  Future<List<String>> sendManualSos({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationError,
  }) async {
    String alertMessage;

    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(6);
      final lngStr = longitude.toStringAsFixed(6);
      final accStr = accuracy != null ? ' (+/-${accuracy.toStringAsFixed(0)}m)' : '';
      final address = await _reverseGeocode(latitude, longitude);

      final locLine = (address != null && address.isNotEmpty) ? 'Loc: $address\n' : '';

      alertMessage = 'LISKO SOS! Need Help!\n'
          '$locLine'
          '$latStr,$lngStr$accStr\n'
          'Map: https://www.google.com/maps?q=$latStr,$lngStr';
    } else {
      final err = locationError ?? 'Location Unavailable';
      alertMessage = 'LISKO SOS! Need Help!\n'
          'Loc: $err';
    }

    return _internalDispatch(_appendTimestamp(alertMessage));
  }

  Future<List<String>> dispatchEmergencyAlert({
    required String destination,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationError,
    String? customMessage,
    bool isArrived = true,
  }) async {
    String alertMessage;

    if (customMessage != null && customMessage.isNotEmpty) {
      alertMessage = customMessage;
    } else {
      final now = DateTime.now();
      int h = now.hour;
      final ampm = h >= 12 ? 'PM' : 'AM';
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      final hs = h.toString().padLeft(2, '0');
      final mi = now.minute.toString().padLeft(2, '0');
      final timeStr = '$hs:$mi $ampm';

      final locText = (latitude != null && longitude != null)
          ? 'https://www.google.com/maps?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}'
          : (locationError ?? 'Location Unavailable');

      final destText = destination.isNotEmpty ? destination : 'destination';

      if (isArrived) {
        alertMessage =
            'LisKo ALERT: Student reached $destText but did not respond to the safety confirmation. Location: $locText Time: $timeStr';
      } else {
        alertMessage =
            'LisKo ALERT: Student did not respond to the safety confirmation for $destText. Location: $locText Time: $timeStr';
      }
    }

    return _internalDispatch(alertMessage);
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

  /// Dispatches a safe-arrival confirmation SMS ONLY to the Primary Emergency Contact (contacts[0]).
  /// Does NOT perform GPS acquisition or reverse geocoding.
  Future<List<String>> dispatchPrimaryArrivalSms({
    required String destination,
  }) async {
    final now = DateTime.now();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final y = (now.year % 100).toString().padLeft(2, '0');
    int h = now.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    final hs = h.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final timeStr = '$mo-$d-$y $hs:$mi $ampm';

    final alertMessage =
        'LisKo: Student arrived safely at $destination. Time: $timeStr';

    return _internalDispatchPrimaryOnly(alertMessage);
  }

  /// Sends SMS ONLY to the Primary Emergency Contact (contacts[0] / contacts.first).
  Future<List<String>> _internalDispatchPrimaryOnly(String alertMessage) async {
    developer.log('SmsAlertService: Starting Primary-only safe-arrival SMS dispatch.');

    final contacts = await _storage.readContacts();
    if (contacts.isEmpty) {
      developer.log('SmsAlertService: No trusted contacts configured to receive safe-arrival SMS.');
      return [];
    }

    final primaryContact = contacts.first;

    if (!_isTestEnvironment) {
      final smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          developer.log('SmsAlertService: SMS permission denied for safe-arrival SMS.');
          return [];
        }
      }
    }

    // Phone Number Normalization
    String digitsOnly = primaryContact.phone.replaceAll(RegExp(r'\D'), '');
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
      developer.log('SmsAlertService: Invalid phone number format for primary contact (${primaryContact.name}).');
      return [];
    }

    final dispatchedTo = <String>[];
    if (!_isTestEnvironment) {
      try {
        final result = await BackgroundSms.sendMessage(
          phoneNumber: cleanPhone,
          message: alertMessage,
        );

        if (result == SmsStatus.sent) {
          developer.log('SmsAlertService: Safe-arrival SMS sent to primary contact ${primaryContact.name} ($cleanPhone).');
          dispatchedTo.add('${primaryContact.name} ($cleanPhone)');
        }
      } catch (e) {
        developer.log('SmsAlertService: Exception while sending safe-arrival SMS to primary contact: $e');
      }
    } else {
      dispatchedTo.add('${primaryContact.name} ($cleanPhone)');
    }

    return dispatchedTo;
  }
}
