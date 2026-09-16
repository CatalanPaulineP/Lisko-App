// ==============================================================================
// Lisko Mobile Safety Application – Stationary Detection & Inactivity Service
// File: lib/services/stationary_detection_service.dart
//
// Algorithm: Haversine Distance + Dwell-Time Inactivity Detection
// Role & Architectural Context:
//   Monitors whether a student has moved significantly from their trip-start
//   position after a configurable dwell-time threshold (default: 10 minutes).
//   If the student has NOT moved more than 20 meters, it triggers the safety
//   heads-up inactivity warning, even if the geofence has not yet fired.
//
// Algorithm Steps:
//   1. On "Start Trip", capture anchor coordinates (Lat1, Lon1) and Time1.
//   2. After dwellMinutes elapsed, sample current GPS position (Lat2, Lon2).
//   3. Compute Haversine distance between (Lat1, Lon1) and (Lat2, Lon2).
//   4. If distance < kStationaryThresholdMeters (20m) → fire onInactivityDetected.
//   5. If distance >= 20m → user is moving normally; reschedule for next check.
//
// Architecture Constraints:
//   - All computation is strictly on-device (local-first, zero-surveillance).
//   - The timer only runs while a trip is active (battery-efficient).
//   - No network calls or cloud streaming are performed.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
//   - Reliability: Graceful fallback if GPS is unavailable during check.
//   - Privacy by Design: No location data is stored or transmitted.
// ==============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Radius of the Earth in meters, used by the Haversine formula.
const double _kEarthRadiusMeters = 6371000.0;

/// Minimum movement threshold in meters. If the student has moved less than
/// this distance from their trip-start position during the dwell window,
/// the inactivity warning is triggered.
const double kStationaryThresholdMeters = 20.0;

/// How many minutes into the trip before the first stationary check fires.
/// Default: 10 minutes.
const int kDefaultDwellMinutes = 10;

/// Service that detects whether a student is stationary during an active trip
/// using the Haversine distance formula over a configurable dwell-time window.
///
/// Usage:
/// ```dart
/// _stationaryService.startMonitoring(
///   anchorLat: 14.5995,
///   anchorLon: 120.9842,
///   onInactivityDetected: () => _triggerSafetyBanner(),
///   dwellMinutes: 10,
/// );
/// ```
class StationaryDetectionService {
  /// Singleton pattern — ensures only one inactivity monitor runs at a time.
  static final StationaryDetectionService _instance =
      StationaryDetectionService._internal();
  factory StationaryDetectionService() => _instance;
  StationaryDetectionService._internal();

  Timer? _dwellTimer;
  double? _anchorLat;
  double? _anchorLon;
  bool _monitoring = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts the inactivity monitoring loop for an active trip.
  ///
  /// Parameters:
  /// - [anchorLat], [anchorLon]: GPS coordinates captured at trip start.
  /// - [onInactivityDetected]: Callback invoked when the student hasn't moved.
  /// - [dwellMinutes]: Interval in minutes before each stationary check.
  ///   Defaults to [kDefaultDwellMinutes] (10 minutes).
  void startMonitoring({
    required double anchorLat,
    required double anchorLon,
    required VoidCallback onInactivityDetected,
    int dwellMinutes = kDefaultDwellMinutes,
  }) {
    // Guard: prevent double-starting
    if (_monitoring) stopMonitoring();

    _anchorLat = anchorLat;
    _anchorLon = anchorLon;
    _monitoring = true;

    debugPrint(
      '[StationaryDetection] Monitoring started. '
      'Anchor: ($anchorLat, $anchorLon). '
      'First check in $dwellMinutes minute(s).',
    );

    // Schedule the first check after the dwell threshold has elapsed.
    _scheduleDwellCheck(
      onInactivityDetected: onInactivityDetected,
      dwellMinutes: dwellMinutes,
    );
  }

  /// Stops the inactivity monitoring loop.
  /// Must be called when the trip ends, is extended, or the safety banner
  /// has already been dismissed.
  void stopMonitoring() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _monitoring = false;
    _anchorLat = null;
    _anchorLon = null;
    debugPrint('[StationaryDetection] Monitoring stopped.');
  }

  /// Returns true if the service is currently running an active check loop.
  bool get isMonitoring => _monitoring;

  // ---------------------------------------------------------------------------
  // Internal Logic
  // ---------------------------------------------------------------------------

  /// Schedules a single delayed check after [dwellMinutes] have elapsed.
  void _scheduleDwellCheck({
    required VoidCallback onInactivityDetected,
    required int dwellMinutes,
  }) {
    _dwellTimer?.cancel();
    _dwellTimer = Timer(
      Duration(minutes: dwellMinutes),
      () => _runStationaryCheck(
        onInactivityDetected: onInactivityDetected,
        dwellMinutes: dwellMinutes,
      ),
    );
  }

  /// Fetches the current GPS position, computes Haversine distance from anchor,
  /// and fires [onInactivityDetected] if the student has not moved far enough.
  Future<void> _runStationaryCheck({
    required VoidCallback onInactivityDetected,
    required int dwellMinutes,
  }) async {
    // Safety: abort if monitoring was stopped before check fired.
    if (!_monitoring || _anchorLat == null || _anchorLon == null) return;

    debugPrint('[StationaryDetection] Running dwell-time inactivity check...');

    try {
      final Position current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final double distanceMeters = haversineDistance(
        lat1: _anchorLat!,
        lon1: _anchorLon!,
        lat2: current.latitude,
        lon2: current.longitude,
      );

      debugPrint(
        '[StationaryDetection] Haversine distance from anchor: '
        '${distanceMeters.toStringAsFixed(1)}m '
        '(threshold: ${kStationaryThresholdMeters}m).',
      );

      if (distanceMeters < kStationaryThresholdMeters) {
        // Student has not moved. Trigger the inactivity prompt.
        debugPrint(
          '[StationaryDetection] Stationary threshold met. '
          'distance ${distanceMeters.toStringAsFixed(1)}m < ${kStationaryThresholdMeters}m. '
          'Triggering emergency alarm/SMS sequence immediately.',
        );
        stopMonitoring();
        onInactivityDetected();
      } else {
        // Student is moving normally. Update anchor to current position and
        // reschedule the next check to avoid re-triggering for old distances.
        debugPrint(
          '[StationaryDetection] ✅ Student is moving '
          '(${distanceMeters.toStringAsFixed(1)}m ≥ ${kStationaryThresholdMeters}m). '
          'Rescheduling check in $dwellMinutes minute(s).',
        );
        _anchorLat = current.latitude;
        _anchorLon = current.longitude;
        _scheduleDwellCheck(
          onInactivityDetected: onInactivityDetected,
          dwellMinutes: dwellMinutes,
        );
      }
    } catch (e) {
      // GPS unavailable (e.g., indoor, tunnel). Log and reschedule gracefully
      // rather than triggering a false positive.
      debugPrint(
        '[StationaryDetection] GPS unavailable during check: $e. '
        'Rescheduling without triggering warning.',
      );
      _scheduleDwellCheck(
        onInactivityDetected: onInactivityDetected,
        dwellMinutes: dwellMinutes,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Haversine Distance Formula
  // ---------------------------------------------------------------------------

  /// Computes the great-circle distance in meters between two GPS coordinates
  /// using the Haversine formula.
  ///
  /// The Haversine formula accounts for the Earth's curvature and provides
  /// accurate short-range distance estimates suitable for geofencing.
  ///
  /// Formula:
  ///   a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
  ///   c = 2 × atan2(√a, √(1−a))
  ///   d = R × c
  ///
  /// where R = 6,371,000 m (Earth's radius).
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _kEarthRadiusMeters * c;
  }

  /// Converts degrees to radians.
  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}


