import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for interacting with Firebase Cloud Firestore.
/// 
/// CONSTRAINTS ALIGNMENT:
/// To respect the Local-First and Zero-Surveillance architecture, this service 
/// DOES NOT sync general user travel data, live location, or active trips.
/// It strictly logs unacknowledged emergency events (SOS or TIMEOUT_ESCALATION) 
/// to the 'emergency_events' collection for critical auditing purposes.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Logs an emergency event to the 'emergency_events' collection.
  /// 
  /// Triggers only when the safety timer expires without user confirmation, or 
  /// when the user explicitly triggers an SOS.
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
      // Intentionally swallowing the error to prevent blocking the rest of the 
      // emergency escalation flow (e.g., SMS dispatch) if network connectivity fails.
    }
  }
}

