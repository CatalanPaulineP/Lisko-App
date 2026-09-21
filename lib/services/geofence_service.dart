// ==============================================================================
// Lisko Mobile Safety Application - Geofencing & Arrival Detection Service
// File: lib/services/geofence_service.dart
//
// Role & Architectural Context:
// Real-time geofence tracking and destination boundary monitor. Responsible for
// resolving target coordinates (PUP Santa Maria Campus, Home, or Custom),
// calculating distance to perimeter using `Geolocator.distanceBetween()`, and
// firing auto-arrival callbacks when the student enters the 150m perimeter.
//
// Zero-Surveillance Architecture & Privacy Compliance:
// - On-Demand Activation: GPS monitoring is strictly INACTIVE by default.
//   It is initialized ONLY when the student explicitly starts an active commute
//   via `startMonitoring()`.
// - 100% On-Device Processing: Coordinates are evaluated purely locally against
//   the active destination boundary. No GPS tracks, history, or telemetry are
//   ever transmitted over the network or saved to remote cloud databases.
// - Immediate Termination: As soon as the trip completes, ends, or confirms safe
//   arrival, `stopMonitoring()` is invoked to kill the location stream and release
//   GPS hardware resources.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability & Timeliness: 150-meter perimeter ensures early, reliable arrival
//   prompting even with standard consumer GPS tolerances.
// - Reliability (Fault-Tolerant Operation): Gracefully handles disabled GPS, denied
//   permissions, or test harnesses without crashing.
// ==============================================================================

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'local_storage_service.dart';

/// Represents a geofenced geographic boundary destination.
class GeofenceTarget {
  const GeofenceTarget({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
  });

  /// Unique target identifier.
  final String id;

  /// Human-readable destination label (e.g., "Campus", "Home").
  final String name;

  /// Target geographic latitude.
  final double latitude;

  /// Target geographic longitude.
  final double longitude;

  /// Trigger radius perimeter in meters (defaults to 150m).
  final double radiusMeters;

  @override
  String toString() =>
      'GeofenceTarget($name, lat: $latitude, lng: $longitude, r: ${radiusMeters}m)';
}

/// Service managing conditional GPS geofence monitoring and arrival detection.
class GeofenceService {
  GeofenceService({LocalStorageService? storageService})
      : _storage = storageService ?? const LocalStorageService();

  final LocalStorageService _storage;

  /// PUP Santa Maria, Bulacan Campus Geofence Target.
  /// Coordinates: 14.8697° N, 120.9991° E (Sitio Gulod, Pulong Buhangin, Santa Maria, Bulacan).
  static const GeofenceTarget pupSantaMariaCampus = GeofenceTarget(
    id: 'campus',
    name: 'Campus',
    latitude: 14.8697,
    longitude: 120.9991,
    radiusMeters: 150.0,
  );

  /// Default Home baseline target if unconfigured in local settings.
  static const GeofenceTarget defaultHome = GeofenceTarget(
    id: 'home',
    name: 'Home',
    latitude: LocalStorageService.defaultHomeLat,
    longitude: LocalStorageService.defaultHomeLng,
    radiusMeters: LocalStorageService.defaultHomeRadius,
  );

  /// Verified Commuter Transit Nodes for Santa Maria, Bulacan
  static const List<GeofenceTarget> commuterNodes = [
    GeofenceTarget(
      id: 'caypombo',
      name: 'Caypombo Terminal / Crossing',
      latitude: 14.848737039366092,
      longitude: 120.9812542306243,
      radiusMeters: 150.0,
    ),
    GeofenceTarget(
      id: 'waltermart',
      name: 'Waltermart Santa Maria Drop-off',
      latitude: 14.822738093788265,
      longitude: 120.95424771314413,
      radiusMeters: 150.0,
    ),
    GeofenceTarget(
      id: 'bayan',
      name: 'Santa Maria Bayan / Savemore Area',
      latitude: 14.821742177842623,
      longitude: 120.96163959792787,
      radiusMeters: 150.0,
    ),
  ];

  StreamSubscription<Position>? _positionSubscription;
  bool _isMonitoring = false;
  GeofenceTarget? _activeTarget;
  bool _arrivalDetected = false;
  double? _lastDistanceMeters;

  /// Whether active GPS tracking is currently running.
  bool get isMonitoring => _isMonitoring;

  /// The active destination target being monitored.
  GeofenceTarget? get activeTarget => _activeTarget;

  /// Whether arrival has already been detected for the active trip.
  bool get arrivalDetected => _arrivalDetected;

  /// Most recent distance in meters to the active destination.
  double? get lastDistanceMeters => _lastDistanceMeters;

  /// Helper detecting if app is executing within a Flutter test harness.
  bool get _isTestEnvironment {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('TestWidgetsFlutterBinding') ||
        binding.contains('AutomatedTestWidgetsFlutterBinding');
  }

  /// Resolves target geofence coordinates based on selected destination name.
  Future<GeofenceTarget?> resolveTarget(String destinationName) async {
    final normalized = destinationName.trim().toLowerCase();

    // Prefer exact match against commuter nodes
    for (final node in commuterNodes) {
      if (normalized == node.name.toLowerCase()) {
        return node;
      }
    }

    if (normalized.contains('campus') || normalized.contains('pup') || normalized.contains('school')) {
      return pupSantaMariaCampus;
    }

    if (normalized.contains('home')) {
      final homeCoords = await _storage.readHomeCoordinates();
      return GeofenceTarget(
        id: 'home',
        name: 'Home',
        latitude: homeCoords['latitude'] ?? defaultHome.latitude,
        longitude: homeCoords['longitude'] ?? defaultHome.longitude,
        radiusMeters: homeCoords['radius'] ?? defaultHome.radiusMeters,
      );
    }

    for (final node in commuterNodes) {
      if (normalized == node.id.toLowerCase() ||
          normalized == node.name.split(' ').first.toLowerCase()) {
        return node;
      }
    }

    // unknown destination - avoid silent fallback to Campus
    return null;
  }

  /// Activates on-demand GPS monitoring when a commute starts.
  ///
  /// Listens to high-accuracy device coordinates and checks if the student
  /// has entered the destination's perimeter radius.
  Future<bool> startMonitoring({
    required String destination,
    required void Function(GeofenceTarget target, double distanceMeters) onArrival,
    void Function(double distanceMeters)? onLocationUpdate,
    void Function(String error)? onError,
  }) async {
    stopMonitoring();

    _activeTarget = await resolveTarget(destination);
    if (_activeTarget == null) {
      onError?.call('Location monitoring unavailable for this destination');
      return false;
    }
    _arrivalDetected = false;
    _isMonitoring = true;

    // In unit / widget tests, avoid touching unmocked native geolocator platform channels.
    if (_isTestEnvironment) {
      developer.log('GeofenceService: Running in test mode, monitoring target $_activeTarget');
      return true;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled on device.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('Location permission denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permission permanently denied.');
        return false;
      }

      // Check current position immediately
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _evaluatePosition(initialPosition, onArrival, onLocationUpdate);
      } catch (e) {
        developer.log('Initial GPS position fetch notice: $e');
      }

      // Stream continuous location updates during the active trip
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Updates every 10 meters
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          _evaluatePosition(position, onArrival, onLocationUpdate);
        },
        onError: (error) {
          developer.log('GPS position stream error: $error');
          onError?.call(error.toString());
        },
      );

      return true;
    } catch (e, st) {
      developer.log('GeofenceService startMonitoring error', error: e, stackTrace: st);
      onError?.call('Failed to activate geofence GPS monitoring: $e');
      return false;
    }
  }

  /// Evaluates device position against the active geofence target boundary.
  void _evaluatePosition(
    Position position,
    void Function(GeofenceTarget target, double distanceMeters) onArrival,
    void Function(double distanceMeters)? onLocationUpdate,
  ) {
    final target = _activeTarget;
    if (target == null || !_isMonitoring) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    _lastDistanceMeters = distance;
    onLocationUpdate?.call(distance);

    if (distance <= target.radiusMeters && !_arrivalDetected) {
      _arrivalDetected = true;
      developer.log('Geofence Arrival Detected: within ${distance.toStringAsFixed(1)}m of ${target.name}');
      onArrival(target, distance);
    }
  }

  /// Terminates active GPS tracking and releases hardware resources.
  ///
  /// Adheres strictly to Zero-Surveillance principles by shutting down
  /// location listeners as soon as the trip ends or safe arrival is confirmed.
  void stopMonitoring() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    _activeTarget = null;
    _arrivalDetected = false;
    _lastDistanceMeters = null;
  }

  /// Testing & Simulation helper: Simulates entering the geofence perimeter.
  void simulateArrival({
    required void Function(GeofenceTarget target, double distanceMeters) onArrival,
  }) {
    if (_activeTarget != null && !_arrivalDetected) {
      _arrivalDetected = true;
      _lastDistanceMeters = 50.0;
      onArrival(_activeTarget!, 50.0);
    }
  }

  /// Testing & Simulation helper: Simulates a specific GPS coordinate update.
  void simulatePosition({
    required double latitude,
    required double longitude,
    required void Function(GeofenceTarget target, double distanceMeters) onArrival,
    void Function(double distanceMeters)? onLocationUpdate,
  }) {
    final target = _activeTarget;
    if (target == null) return;

    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      target.latitude,
      target.longitude,
    );

    _lastDistanceMeters = distance;
    onLocationUpdate?.call(distance);

    if (distance <= target.radiusMeters && !_arrivalDetected) {
      _arrivalDetected = true;
      onArrival(target, distance);
    }
  }
}
