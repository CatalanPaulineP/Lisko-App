// ==============================================================================
// LisKo Mobile Safety Application - Core Services
// File: lib/services/local_storage_service.dart
//
// Role & Architectural Context:
// Low-level persistence service abstracting `SharedPreferences` operations.
// Responsible for persisting user setup completion flags and trusted emergency
// contacts on the physical device.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Functional Suitability & Privacy (Zero-Surveillance Architecture): All personal
//   contact data and trip configurations remain strictly localized on the user's
//   device. No remote servers, cloud databases, or third-party analytics are used,
//   ensuring complete student privacy in compliance with data privacy principles.
// - Reliability (Fault Tolerance & Graceful Recovery): Every async operation is
//   isolated with defensive `try/catch` blocks and structured logging. In the event
//   of device storage corruption or I/O failure, the service falls back gracefully
//   to predictable safe defaults (e.g., `defaultContacts` or `false` for setup)
//   preventing unhandled app crashes.
// ==============================================================================

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/action_buttons.dart';

/// Service for persistent key-value storage with graceful error recovery.
///
/// Implemented with a `const` constructor for dependency-injection readiness and
/// zero-overhead instantiation across UI state controllers.
class LocalStorageService {
  const LocalStorageService();

  /// Key identifying whether the user has successfully finished initial onboarding.
  static const _setupCompletedKey = 'setup_completed';

  /// Key storing the JSON-encoded list of trusted emergency contacts.
  static const _trustedContactsKey = 'trusted_contacts_json';

  /// Keys storing the saved Home geofence perimeter coordinates.
  static const _homeLatKey = 'home_latitude';
  static const _homeLngKey = 'home_longitude';
  static const _homeRadiusKey = 'home_radius_meters';

  /// Default baseline Home geofence target coordinates (Santa Maria, Bulacan).
  static const double defaultHomeLat = 14.8192;
  static const double defaultHomeLng = 120.9610;
  static const double defaultHomeRadius = 150.0;

  /// Default baseline contacts loaded upon fresh install if no contacts exist.
  /// Pre-configured with Pauline as the primary emergency contact to ensure
  /// immediate emergency SMS readiness.
  static const List<ContactPerson> defaultContacts = [
    ContactPerson(
      name: 'Pauline',
      phone: '+63 9123456789',
      initials: 'PL',
      relationship: 'Mother',
    ),
    ContactPerson(
      name: 'Maria Santos',
      phone: '+63 917 123 4567',
      initials: 'MS',
      relationship: 'Father',
    ),
    ContactPerson(
      name: 'Juan Dela Cruz',
      phone: '+63 905 456 7890',
      initials: 'JD',
      relationship: 'Guardian',
    ),
  ];

  /// Reads whether the user has completed the initial onboarding setup.
  ///
  /// **Boot Check & Lockout Logic:**
  /// Used by `main.dart` during app launch to determine the initial route:
  /// - `true`: Skips the welcome/onboarding carousel and navigates directly to `HomeScreen`.
  /// - `false`: Shows the initial `SplashScreen` followed by the onboarding flow.
  ///
  /// Falls back safely to `false` if an I/O or platform channel error occurs.
  Future<bool> readSetupCompleted() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_setupCompletedKey) ?? false;
    } catch (e, st) {
      developer.log(
        'Failed to read setup_completed from SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Persists the onboarding setup completion state to local storage.
  ///
  /// Called upon tapping "Go to Home" on the Step 5 ("You're Ready!") screen,
  /// permanently locking out the onboarding flow for future app launches.
  Future<bool> setSetupCompleted(bool completed) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return await preferences.setBool(_setupCompletedKey, completed);
    } catch (e, st) {
      developer.log(
        'Failed to write setup_completed to SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Reads the saved trusted contacts list from local storage.
  ///
  /// **Data Deserialization & Recovery:**
  /// Decodes the stored JSON string array into strongly typed [ContactPerson] models.
  /// If no data has been saved yet (or in case of JSON parse failure), falls back
  /// to [defaultContacts] so the UI always has guaranteed emergency recipients.
  Future<List<ContactPerson>> readContacts() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_trustedContactsKey);
      if (raw == null || raw.isEmpty) {
        return List<ContactPerson>.from(defaultContacts);
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ContactPerson.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      developer.log(
        'Failed to read contacts from SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return List<ContactPerson>.from(defaultContacts);
    }
  }

  /// Persists the updated list of trusted emergency contacts to local storage.
  ///
  /// **Data Serialization:**
  /// Converts the list of [ContactPerson] instances into a JSON array string
  /// and writes it to `SharedPreferences`. Used during onboarding contact entry,
  /// contact editing, contact deletion, and contact importing.
  Future<bool> saveContacts(List<ContactPerson> contacts) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
      return await preferences.setString(_trustedContactsKey, encoded);
    } catch (e, st) {
      developer.log(
        'Failed to write contacts to SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Reads the saved Home geofence coordinates from local storage.
  ///
  /// Returns a map containing `'latitude'`, `'longitude'`, and `'radius'`.
  /// If unconfigured, safely defaults to the Santa Maria residential baseline
  /// (`14.8192, 120.9610, 150.0m`).
  Future<Map<String, double>> readHomeCoordinates() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final lat = preferences.getDouble(_homeLatKey) ?? defaultHomeLat;
      final lng = preferences.getDouble(_homeLngKey) ?? defaultHomeLng;
      final radius = preferences.getDouble(_homeRadiusKey) ?? defaultHomeRadius;
      return {'latitude': lat, 'longitude': lng, 'radius': radius};
    } catch (e, st) {
      developer.log(
        'Failed to read Home geofence coordinates from SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return {
        'latitude': defaultHomeLat,
        'longitude': defaultHomeLng,
        'radius': defaultHomeRadius,
      };
    }
  }

  /// Persists the custom Home geofence coordinates to local storage.
  Future<bool> saveHomeCoordinates({
    required double latitude,
    required double longitude,
    double radius = defaultHomeRadius,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_homeLatKey, latitude);
      await preferences.setDouble(_homeLngKey, longitude);
      await preferences.setDouble(_homeRadiusKey, radius);
      return true;
    } catch (e, st) {
      developer.log(
        'Failed to write Home geofence coordinates to SharedPreferences',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}

