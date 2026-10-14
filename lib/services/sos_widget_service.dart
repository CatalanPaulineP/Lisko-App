// ==============================================================================
// Lisko Mobile Safety Application - SOS Widget Integration Service
// File: lib/services/sos_widget_service.dart
//
// Role & Architectural Context:
// Communicates with native Android `MainActivity` via MethodChannel
// (`com.lisko.safety/sos_widget`). Requests home screen widget pinning
// (`requestPinWidget`).
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper service facilitating Android Home Screen SOS widget communication.
class SosWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.lisko.safety/sos_widget');

  /// Requests the native Android launcher to pin the LisKo SOS Widget to the home screen.
  /// Returns `true` if the pin request was successfully dispatched to the OS.
  static Future<bool> requestPinWidget() async {
    try {
      final bool success =
          await _channel.invokeMethod('pinSosWidget') ?? false;
      debugPrint('[SosWidgetService] requestPinWidget result: $success');
      return success;
    } catch (e) {
      debugPrint('[SosWidgetService] Error requesting widget pin: $e');
      return false;
    }
  }
}
