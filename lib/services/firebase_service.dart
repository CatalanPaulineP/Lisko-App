import 'dart:async';
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

  StreamController<List<TripRecord>>? _tripsController;
  StreamSubscription? _subTrips;
  StreamSubscription? _subEvents;
  
  List<TripRecord> _localTrips = [];
  List<TripRecord> _currentTrips = [];
  List<TripRecord> _currentEvents = [];

  void _emitCombinedTrips() {
    if (_tripsController == null || _tripsController!.isClosed) return;
    final map = <String, TripRecord>{};
    for (final t in _localTrips) { map[t.id] = t; }
    for (final t in _currentTrips) { map[t.id] = t; }
    for (final t in _currentEvents) { map[t.id] = t; }
    
    final combined = map.values.toList();
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _tripsController!.add(combined);
  }

  Future<void> refreshLocalTrips() async {
    try {
      _localTrips = await const LocalStorageService().readTripHistory();
      final activeData = await const LocalStorageService().readActiveTrip();
      if (activeData != null && activeData['isActive'] == true) {
         final activeId = activeData['tripId'] as String? ?? '';
         if (activeId.isNotEmpty && activeData['startedAtMs'] != null) {
           _localTrips.add(TripRecord(
             id: activeId,
             destination: activeData['destination'] as String? ?? 'Unknown',
             durationMinutes: (activeData['totalDurationSeconds'] as int? ?? 0) ~/ 60,
             status: 'active',
             timestamp: DateTime.fromMillisecondsSinceEpoch(activeData['startedAtMs'] as int),
           ));
         }
      }
      _emitCombinedTrips();
    } catch (_) {}
  }

  Stream<List<TripRecord>> getTripsStream() {
    _tripsController ??= StreamController<List<TripRecord>>.broadcast(
      onListen: () async {
        await refreshLocalTrips();

        _subTrips = _firestore
            .collection('trips')
            .orderBy('startedAt', descending: true)
            .snapshots()
            .listen((snapshot) {
          _currentTrips = snapshot.docs.map((doc) {
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
          _emitCombinedTrips();
        }, onError: (e) {
          developer.log('FirebaseService trips error: $e');
        });

        _subEvents = _firestore
            .collection('emergency_events')
            .where('tripId', isEqualTo: '')
            .snapshots()
            .listen((snapshot) {
          _currentEvents = snapshot.docs.map((doc) {
            final data = doc.data();
            return TripRecord(
              id: doc.id,
              destination: 'Manual SOS',
              durationMinutes: 0,
              status: 'Alert',
              timestamp: _parseDateSafely(data['triggeredAt']),
              wasExtended: false,
            );
          }).toList();
          _emitCombinedTrips();
        }, onError: (e) {
          developer.log('FirebaseService emergency_events error: $e');
        });
      },
      onCancel: () {
        _subTrips?.cancel();
        _subEvents?.cancel();
        _tripsController = null;
      },
    );

    return _tripsController!.stream;
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
    required String eventId,
    required String deviceId,
    required String tripId,
    required double latitude,
    required double longitude,
    required String emergencyType,
  }) async {
    try {
      await _firestore.collection('emergency_events').doc(eventId).set({
        'deviceId': deviceId,
        'tripId': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'emergencyType': emergencyType, // e.g., 'SOS', 'TIMEOUT_ESCALATION'
        'triggeredAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      developer.log('FirebaseService: Successfully logged emergency event ($emergencyType) with ID: $eventId.');
    } catch (e) {
      developer.log('FirebaseService: Failed to log emergency event to Firestore. Error: $e');
    }
  }
}

