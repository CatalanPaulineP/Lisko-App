import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'local_storage_service.dart';

/// Service for interacting with Firebase Cloud Firestore.
/// 
/// Maintains the trips, emergency_events, and trusted_contacts collections.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _parseDateSafely(dynamic rawDate) {
    if (rawDate == null) return DateTime.now();
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is String) return DateTime.tryParse(rawDate) ?? DateTime.now();
    if (rawDate is int) return DateTime.fromMillisecondsSinceEpoch(rawDate);
    return DateTime.now();
  }

  /// Retrieves the actual saved trip records from Firebase for the Trips tab.
  Future<List<TripRecord>> getTrips() async {
    try {
      final snapshot = await _firestore.collection('trips')
          .orderBy('startedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TripRecord(
          id: doc.id,
          destination: data['destination'] ?? 'Unknown',
          durationMinutes: data['estimatedTravelMinutes'] ?? 0,
          status: data['status'] ?? 'Unknown',
          timestamp: _parseDateSafely(data['startedAt']),
          wasExtended: data['wasExtended'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      developer.log('FirebaseService: Failed to fetch trips. Error: $e');
      return [];
    }
  }

  Stream<List<TripRecord>> getTripsStream() {
    return _firestore
        .collection('trips')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TripRecord(
          id: doc.id,
          destination: data['destination'] ?? 'Unknown',
          durationMinutes: data['estimatedTravelMinutes'] ?? 0,
          status: data['status'] ?? 'Unknown',
          timestamp: _parseDateSafely(data['startedAt']),
          wasExtended: data['wasExtended'] as bool? ?? false,
        );
      }).toList();
    });
  }

  /// Creates or updates a trip in Firebase.
  Future<void> saveOrUpdateTrip({
    required String tripId,
    required String destination,
    required int estimatedTravelMinutes,
    required DateTime startedAt,
    DateTime? expectedArrivalAt,
    DateTime? completedAt,
    required String status,
    double? startLat,
    double? startLng,
    bool? wasExtended,
  }) async {
    try {
      final data = {
        'destination': destination,
        'estimatedTravelMinutes': estimatedTravelMinutes,
        'startedAt': Timestamp.fromDate(startedAt),
        if (expectedArrivalAt != null) 'expectedArrivalAt': Timestamp.fromDate(expectedArrivalAt),
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt),
        'status': status,
        if (startLat != null) 'startLocationLat': startLat,
        if (startLng != null) 'startLocationLng': startLng,
        if (wasExtended != null) 'wasExtended': wasExtended,
      };

      await _firestore.collection('trips').doc(tripId).set(data, SetOptions(merge: true));
      developer.log('FirebaseService: Saved/Updated trip $tripId ($status).');
    } catch (e) {
      developer.log('FirebaseService: Failed to save trip. Error: $e');
    }
  }

  /// Logs an emergency event to the 'emergency_events' collection.
  Future<void> logEmergencyEvent({
    required String deviceId,
    required String tripId,
    required double latitude,
    required double longitude,
    required String emergencyType,
  }) async {
    try {
      await _firestore.collection('emergency_events').add({
        'deviceId': deviceId,
        'tripId': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'emergencyType': emergencyType, // e.g., 'SOS', 'TIMEOUT_ESCALATION'
        'triggeredAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      developer.log('FirebaseService: Successfully logged emergency event ($emergencyType).');
    } catch (e) {
      developer.log('FirebaseService: Failed to log emergency event to Firestore. Error: $e');
    }
  }
}

