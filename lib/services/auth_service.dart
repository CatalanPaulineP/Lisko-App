// ==============================================================================
// Lisko Mobile Safety Application - Native Device Security Authentication Service
// File: lib/services/auth_service.dart
//
// Role & Architectural Context:
// Integrates `local_auth` platform channels to prompt native Android lock screen
// credentials (PIN, pattern, password, or biometrics) for protecting sensitive
// student safety data (trusted emergency contacts).
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Helper service invoking native device authentication prompts.
class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks whether device security (PIN, pattern, password, or biometrics) is available.
  static Future<bool> isDeviceAuthSupported() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('[AuthService] Error checking device auth support: $e');
      return false;
    }
  }

  /// Prompts native device lock screen security (PIN, pattern, password, or biometrics).
  static Future<bool> authenticate({
    String reason = 'Authenticate to access your trusted emergency contacts',
  }) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('[AuthService] PlatformException during authenticate: $e');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Error during authenticate: $e');
      return false;
    }
  }
}
