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
    this.municipality = '',
    this.transitType = 'terminal',
    this.address = '',
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

  /// The municipality/city where this terminal is located.
  final String municipality;

  /// The primary mode of transport (e.g., 'bus', 'jeep', 'van', 'campus', 'home').
  final String transitType;

  /// The specific street address or landmark description.
  final String address;

  /// Trigger radius perimeter in meters (defaults to 150m).
  final double radiusMeters;

  @override
  String toString() =>
      'GeofenceTarget($name, $municipality, address: $address, lat: $latitude, lng: $longitude, type: $transitType, r: ${radiusMeters}m)';
}

/// Service managing conditional GPS geofence monitoring and arrival detection.
class GeofenceService {
  GeofenceService({LocalStorageService? storageService})
      : _storage = storageService ?? const LocalStorageService();

  final LocalStorageService _storage;

  /// PUP Santa Maria, Bulacan Campus Geofence Target.
  /// Verified Coordinates: 14.869725503304737° N, 120.9990821362761° E (Pulong Buhangin, Santa Maria, Bulacan).
  static const GeofenceTarget pupSantaMariaCampus = GeofenceTarget(
    id: 'campus',
    name: 'Campus',
    latitude: 14.869725503304737,
    longitude: 120.9990821362761,
    municipality: 'SANTA MARIA',
    transitType: 'campus',
    radiusMeters: 150.0,
  );

  /// Default Home baseline target if unconfigured in local settings.
  static const GeofenceTarget defaultHome = GeofenceTarget(
    id: 'home',
    name: 'Home',
    latitude: LocalStorageService.defaultHomeLat,
    longitude: LocalStorageService.defaultHomeLng,
    municipality: 'HOME',
    transitType: 'home',
    radiusMeters: LocalStorageService.defaultHomeRadius,
  );

  /// Verified Commuter Transit Nodes for Santa Maria, Norzagaray, Angat, Pandi, Bocaue, and Marilao
  static const List<GeofenceTarget> commuterNodes = [
    // --- SANTA MARIA ---
    GeofenceTarget(
      id: 'caypombo',
      name: 'Caypombo Jeep/Bus Stop',
      latitude: 14.847154,
      longitude: 120.980688,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      radiusMeters: 150.0,
    ),
    GeofenceTarget(
      id: 'waltermart',
      name: 'Waltermart Santa Maria Drop-off',
      latitude: 14.824197,
      longitude: 120.954508,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      radiusMeters: 150.0,
    ),
    GeofenceTarget(
      id: 'bayan',
      name: 'Santa Maria Bayan / Savemore Area',
      latitude: 14.821742177842623,
      longitude: 120.96163959792787,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      radiusMeters: 150.0,
    ),
    GeofenceTarget(
      id: 'sm_jeep_terminal',
      name: 'New Santa Maria Jeepney Terminal (Ilalim ng Tulay)',
      latitude: 14.81761144692498,
      longitude: 120.95939230431375,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      address: '15 C De Jesus St, Brgy. Poblacion, Santa Maria, 3022 Bulacan',
    ),
    GeofenceTarget(
      id: 'sm_sti_station',
      name: 'STI College - Sta. Maria Loading/Unloading Station',
      latitude: 14.8211107,
      longitude: 120.959243,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      address: 'AAA Building, Halili Arcade, Brgy. Poblacion, Santa Maria, 3022 Bulacan',
    ),
    GeofenceTarget(
      id: 'sm_caypombo_p2p',
      name: 'P2P Caypombo Terminal',
      latitude: 14.848596041960562,
      longitude: 120.98127901552402,
      municipality: 'SANTA MARIA',
      transitType: 'bus',
      address: 'RXXJ+CG6, Brgy. Caypombo, 3022 Santa Maria, Bulacan',
    ),
    GeofenceTarget(
      id: 'sm_tierra_subd',
      name: 'Tierra de Santa Maria Subdivision Jeep/Bus Stop',
      latitude: 14.873438,
      longitude: 121.006779,
      municipality: 'SANTA MARIA',
      transitType: 'jeep',
      address: 'Norzagaray - Santa Maria Road, Brgy. Pulong Buhangin, Santa Maria, 3022 Bulacan',
    ),

    // --- NORZAGARAY ---
    GeofenceTarget(
      id: 'norz_terminal',
      name: 'Norzagaray Crossing',
      latitude: 14.905759,
      longitude: 121.038575,
      municipality: 'NORZAGARAY',
      transitType: 'jeep',
      address: 'Gen. E. De Leon St., Brgy. Poblacion, Norzagaray, Bulacan',
    ),

    // --- ANGAT ---
    GeofenceTarget(
      id: 'angat_divisoria',
      name: 'Angat-Divisoria Bus Terminal (Sta. Monica Transport / Racal / Agila Line)',
      latitude: 14.922119,
      longitude: 121.031189,
      municipality: 'ANGAT',
      transitType: 'bus',
      address: 'Matías A. Fernando Ave, Brgy. Poblacion, Angat, Bulacan',
    ),
    GeofenceTarget(
      id: 'angat_monumento',
      name: 'Angat-Monumento Bus Terminal (Shanine & Pauline Transport)',
      latitude: 14.916910,
      longitude: 121.028850,
      municipality: 'ANGAT',
      transitType: 'bus',
      address: 'W28H+MG8, Brgy. Santa Cruz, Angat, Bulacan',
    ),
    GeofenceTarget(
      id: 'angat_precious',
      name: 'Precious Grace Transport - Angat Bus Terminal',
      latitude: 14.917082,
      longitude: 121.028816,
      municipality: 'ANGAT',
      transitType: 'bus',
      address: 'General Alejo Santos Highway, Brgy. Poblacion, Angat, Bulacan',
    ),

    // --- PANDI ---
    GeofenceTarget(
      id: 'pandi_p2p',
      name: 'P2P Pandi Terminal',
      latitude: 14.885914,
      longitude: 120.967473,
      municipality: 'PANDI',
      transitType: 'bus',
      address: 'VXP8+8XP, Brgy. Mapulang Lupa, Pandi, Bulacan',
    ),

    // --- BOCAUE ---
    GeofenceTarget(
      id: 'bocaue_loading_station',
      name: 'Bocaue Loading/Unloading Station',
      latitude: 14.807693,
      longitude: 120.941586,
      municipality: 'BOCAUE',
      transitType: 'jeep',
      address: '',
    ),

    // --- MARILAO ---
    GeofenceTarget(
      id: 'marilao_fortune',
      name: 'Fortune Market & Transport Terminal',
      latitude: 14.762252,
      longitude: 120.948450,
      municipality: 'MARILAO',
      transitType: 'jeep',
      address: 'Fortune Market, Brgy. Tabing Ilog, Marilao, Bulacan',
    ),
  ];

  StreamSubscription<Position>? _positionSubscription;
  bool _isMonitoring = false;
  GeofenceTarget? _activeTarget;
  bool _arrivalDetected = false;
  bool _suppressArrivalUntilExit = false;
  double? _lastDistanceMeters;
  DateTime? _lastGpsLogTime;

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
        municipality: 'HOME',
        transitType: 'home',
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
    bool suppressArrivalUntilExit = false,
  }) async {
    debugPrint('[LisKo-BG-Diag] startMonitoring called for destination "$destination", suppressArrivalUntilExit=$suppressArrivalUntilExit');
    stopMonitoring();

    _activeTarget = await resolveTarget(destination);
    if (_activeTarget == null) {
      debugPrint('[LisKo-BG-Diag] startMonitoring failed: target null for "$destination"');
      onError?.call('Location monitoring unavailable for this destination');
      return false;
    }
    _arrivalDetected = false;
    _suppressArrivalUntilExit = suppressArrivalUntilExit;
    _isMonitoring = true;

    // In unit / widget tests, avoid touching unmocked native geolocator platform channels.
    if (_isTestEnvironment) {
      developer.log('GeofenceService: Running in test mode, monitoring target $_activeTarget');
      return true;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LisKo-BG-Diag] startMonitoring failed: Location services disabled');
        onError?.call('Location services are disabled on device.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LisKo-BG-Diag] startMonitoring failed: Permission denied');
          onError?.call('Location permission denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LisKo-BG-Diag] startMonitoring failed: Permission permanently denied');
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

      debugPrint('[LisKo-BG-Diag] Position subscription created for target "${_activeTarget?.name}"');
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) {
          _evaluatePosition(position, onArrival, onLocationUpdate);
        },
        onError: (error) {
          debugPrint('[LisKo-BG-Diag] GPS position stream error: $error');
          developer.log('GPS position stream error: $error');
          onError?.call(error.toString());
        },
      );

      return true;
    } catch (e, st) {
      debugPrint('[LisKo-BG-Diag] startMonitoring exception: $e');
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

    final now = DateTime.now();
    if (_lastGpsLogTime == null || now.difference(_lastGpsLogTime!) >= const Duration(seconds: 30)) {
      _lastGpsLogTime = now;
      debugPrint(
        '[LisKo-BG-Diag] GPS heartbeat: time=${now.toIso8601String()}, '
        'lat=${position.latitude.toStringAsFixed(6)}, lng=${position.longitude.toStringAsFixed(6)}, '
        'accuracy=${position.accuracy.toStringAsFixed(1)}m, '
        'target="${target.name}" (${target.id}), distance=${distance.toStringAsFixed(1)}m, '
        'suppressed=$_suppressArrivalUntilExit',
      );
    }

    // Exit / Hysteresis check: If device moves >180m from target, clear suppression and re-arm geofence
    if (_suppressArrivalUntilExit && distance > 180.0) {
      _suppressArrivalUntilExit = false;
      _arrivalDetected = false;
      const LocalStorageService().saveActiveTrip(
        isActive: true,
        destination: target.name,
        suppressArrivalUntilExit: false,
      );
      debugPrint('[LisKo-BG-Diag] Destination exit confirmed (${distance.toStringAsFixed(1)}m > 180m); arrival re-armed for ${target.name}');
    }

    if (distance <= target.radiusMeters && !_arrivalDetected && !_suppressArrivalUntilExit) {
      _arrivalDetected = true;
      debugPrint('[LisKo-BG-Diag] Destination arrival triggered: within ${distance.toStringAsFixed(1)}m of ${target.name}');
      debugPrint('[LisKo-Arrival-Trace] T+${DateTime.now().millisecondsSinceEpoch} ms: Geofence Arrival Detected: distance ${distance.toStringAsFixed(1)}m <= radius ${target.radiusMeters}m for target ${target.name}');
      developer.log('Geofence Arrival Detected: within ${distance.toStringAsFixed(1)}m of ${target.name}');
      onArrival(target, distance);
    } else if (distance <= target.radiusMeters && _suppressArrivalUntilExit) {
      debugPrint('[LisKo-BG-Diag] Arrival suppressed: device still inside previous destination (${distance.toStringAsFixed(1)}m <= 180m)');
    }
  }

  /// Terminates active GPS tracking and releases hardware resources.
  ///
  /// Adheres strictly to Zero-Surveillance principles by shutting down
  /// location listeners as soon as the trip ends or safe arrival is confirmed.
  void stopMonitoring() {
    debugPrint('[LisKo-BG-Diag] stopMonitoring called, cancelling subscription for target "${_activeTarget?.name}"');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    _activeTarget = null;
    _arrivalDetected = false;
    _suppressArrivalUntilExit = false;
    _lastDistanceMeters = null;
    _lastGpsLogTime = null;
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
