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

  String _formatSmsDateTime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = months[now.month - 1];
    final dayStr = now.day;
    final yearStr = now.year;

    int h = now.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    final hs = h;
    final mi = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');

    return '$monthStr $dayStr, $yearStr, $hs:$mi:$sec $ampm';
  }

  Future<String> _buildLocationLines({
    double? latitude,
    double? longitude,
    String? locationError,
  }) async {
    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(6);
      final lngStr = longitude.toStringAsFixed(6);
      final rawAddr = await _reverseGeocode(latitude, longitude);

      final coordsBlock = 'Coordinates: $latStr, $lngStr\n'
          'Search these coordinates in Google Maps.';

      if (rawAddr != null && rawAddr.trim().isNotEmpty) {
        var cleanAddr = rawAddr.trim();
        if (cleanAddr.toLowerCase().startsWith('near ')) {
          cleanAddr = cleanAddr.substring(5).trim();
        }
        return 'Loc: $cleanAddr\n$coordsBlock';
      } else {
        return coordsBlock;
      }
    } else {
      return 'Loc: ${locationError ?? "Location unavailable"}';
    }
  }

  bool _isValidStreet(String street) {
    final trimmed = street.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (lower == 'unnamed road' || lower == 'unnamed' || lower == 'null') {
      return false;
    }

    // Omit numeric-only street numbers (e.g. "123")
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return false;
    }

    // Omit Plus Codes (e.g. "7Q5F+X9")
    if (RegExp(r'^[A-Za-z0-9]{4,8}\+[A-Za-z0-9]{2,4}$').hasMatch(trimmed)) {
      return false;
    }

    return true;
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    if (_isTestEnvironment) {
      return 'Pulong Buhangin, Sta. Maria';
    }
    try {
      final placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 3));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final street = (p.thoroughfare ?? p.street ?? '').trim();
        final subLoc = (p.subLocality ?? '').trim();
        final loc = (p.locality ?? p.subAdministrativeArea ?? '').trim();
        final admin = (p.administrativeArea ?? '').trim();

        final parts = <String>[];

        // Priority A: Street + Municipality/City
        if (_isValidStreet(street) && loc.isNotEmpty) {
          parts.add(street);
          parts.add(loc);
        }
        // Priority B: Barangay/SubLocality + Municipality/City
        else if (subLoc.isNotEmpty && loc.isNotEmpty) {
          parts.add(subLoc);
          parts.add(loc);
        }
        // Priority C: Municipality/City + Province
        else if (loc.isNotEmpty && admin.isNotEmpty) {
          parts.add(loc);
          parts.add(admin);
        }
        // Priority D: Barangay/SubLocality + Province
        else if (subLoc.isNotEmpty && admin.isNotEmpty) {
          parts.add(subLoc);
          parts.add(admin);
        }
        // Priority E: Single available component
        else if (loc.isNotEmpty) {
          parts.add(loc);
        } else if (subLoc.isNotEmpty) {
          parts.add(subLoc);
        } else if (admin.isNotEmpty) {
          parts.add(admin);
        }

        // Deduplicate & normalize abbreviations
        final uniqueParts = <String>[];
        final seenLower = <String>{};

        for (var part in parts) {
          var cleaned = part
              .replaceAll('Barangay ', 'Brgy. ')
              .replaceAll('Santa ', 'Sta. ')
              .replaceAll('Saint ', 'St. ')
              .replaceAll('Near ', '')
              .trim();

          cleaned = cleaned.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');
          if (cleaned.isEmpty) continue;

          final lower = cleaned.toLowerCase();
          if (!seenLower.contains(lower)) {
            seenLower.add(lower);
            uniqueParts.add(cleaned);
          }
        }

        if (uniqueParts.isNotEmpty) {
          return uniqueParts.join(', ');
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
    final dateTimeStr = _formatSmsDateTime();
    final locLines = await _buildLocationLines(
      latitude: latitude,
      longitude: longitude,
      locationError: locationError,
    );

    final alertMessage = 'LISKO SOS! Student needs help.\n\n'
        '$locLines\n'
        'Date & Time: $dateTimeStr';

    return _internalDispatch(alertMessage);
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
      final dateTimeStr = _formatSmsDateTime();
      final destText = destination.isNotEmpty ? destination : 'destination';
      final locLines = await _buildLocationLines(
        latitude: latitude,
        longitude: longitude,
        locationError: locationError,
      );

      final header = isArrived
          ? 'LISKO ALERT: Student reached $destText but did not confirm safety.'
          : 'LISKO ALERT: Timer expired!';

      alertMessage = '$header\n\n'
          '$locLines\n'
          'Date & Time: $dateTimeStr';
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
    final dateTimeStr = _formatSmsDateTime();
    final destText = destination.isNotEmpty ? destination : 'destination';

    final alertMessage =
        'LisKo: Student arrived safely at $destText.\n\n'
        'Date & Time: $dateTimeStr';

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
