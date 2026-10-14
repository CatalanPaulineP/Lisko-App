// ==============================================================================
// Lisko Mobile Safety Application - Shared Emergency Dispatch Service
// File: lib/services/emergency_dispatch_service.dart
//
// Role & Architectural Context:
// Centralized, shared execution service for Manual SOS emergency escalation.
// Encapsulates location acquisition, offline SMS alert dispatch, local history
// persistence, and Cloud Firestore emergency logging. Reused by both in-app Manual SOS
// (`HomeScreenState`) and the dedicated Home Screen SOS Widget (`SosEmergencyActivity`).
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'sms_alert_service.dart';

/// Shared service executing the authoritative Manual SOS emergency escalation protocol.
class EmergencyDispatchService {
  final SmsAlertService _smsAlertService = SmsAlertService();
  final LocalStorageService _storage = const LocalStorageService();

  /// Executes the exact Manual SOS emergency escalation flow:
  /// 1. Acquires emergency GPS location via [LocationService].
  /// 2. Dispatches offline SMS to trusted contacts via [SmsAlertService].
  /// 3. Displays emergency notification via [NotificationService].
  /// 4. Saves trip history record locally via [LocalStorageService].
  /// 5. Logs emergency event in Cloud Firestore via [FirebaseService] (using installationId).
  Future<List<String>> executeManualSosDispatch({
    Position? cachedPosition,
    String? tripId,
    String? destination,
    Duration? totalDuration,
    DateTime? startedAt,
    DateTime? expectedArrivalAt,
  }) async {
    double? lat;
    double? lng;
    double? acc;
    String? locError;

    // Acquire emergency location using shared LocationService
    final locResult = await LocationService().acquireEmergencyLocation(
      cachedTripPosition: cachedPosition,
    );

    lat = locResult.latitude;
    lng = locResult.longitude;
    acc = locResult.accuracy;
    locError = locResult.locationError;

    List<String> sentList = [];
    bool permissionDenied = (locError == 'Permission Denied');

    try {
      debugPrint('[EmergencyDispatchService] Dispatching Manual SOS alert...');
      sentList = await _smsAlertService.sendManualSos(
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        locationError: locError,
      );
      debugPrint('[EmergencyDispatchService] SMS successfully dispatched to ${sentList.length} contacts.');
      await NotificationService().showEmergencySentNotification(
        sentList,
        permissionDenied: permissionDenied,
        isManualSos: true,
      );
    } catch (e) {
      if (e.toString().contains('SMS_PERMISSION_DENIED')) {
        permissionDenied = true;
        await NotificationService().showEmergencySentNotification([], permissionDenied: true, isManualSos: true);
      } else {
        await NotificationService().showEmergencySentNotification([], permissionDenied: false, isManualSos: true);
      }
    }

    await _storage.saveActiveTrip(isActive: false);

    // Log the trip locally as Alert
    final history = await _storage.readTripHistory();
    final activeTripId = (tripId != null && tripId.isNotEmpty) ? tripId : '';
    final eventDestination = (activeTripId.isEmpty) ? 'Manual SOS' : (destination ?? 'Campus');
    final eventType = (activeTripId.isEmpty) ? 'Manual SOS' : 'Need Help';

    final eventId = activeTripId.isNotEmpty ? activeTripId : DateTime.now().millisecondsSinceEpoch.toString();
    final newTrip = TripRecord(
      id: eventId,
      destination: eventDestination,
      durationMinutes: totalDuration?.inMinutes ?? 0,
      status: eventType,
      timestamp: DateTime.now(),
    );
    await _storage.saveTripHistory([...history, newTrip]);
    FirebaseService().refreshLocalTrips();

    if (activeTripId.isNotEmpty && startedAt != null) {
      FirebaseService().saveOrUpdateTrip(
        tripId: activeTripId,
        destination: eventDestination,
        estimatedTravelMinutes: totalDuration?.inMinutes ?? 0,
        startedAt: startedAt,
        expectedArrivalAt: expectedArrivalAt,
        completedAt: DateTime.now(),
        status: 'help_requested',
      );
    }

    FirebaseService().logEmergencyEvent(
      eventId: eventId,
      deviceId: 'local_device',
      tripId: activeTripId,
      latitude: lat ?? 0.0,
      longitude: lng ?? 0.0,
      emergencyType: 'SOS',
    );

    return sentList;
  }
}
