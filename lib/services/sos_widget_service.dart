// ==============================================================================
// Lisko Mobile Safety Application - SOS Widget Integration Service
// File: lib/services/sos_widget_service.dart
//
// Role & Architectural Context:
// Communicates with native Android `MainActivity` via MethodChannel
// (`com.example.flutter_app/sos_widget`). Listens for real-time widget taps,
// requests home screen widget pinning (`requestPinWidget`), and checks for pending
// launch intents.
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper service facilitating Android Home Screen SOS widget communication.
class SosWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.example.flutter_app/sos_widget');

  /// Listens for native SOS widget trigger events while the app is active in foreground or background.
  static void initialize({required VoidCallback onSosTriggered}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSosTriggered') {
        debugPrint('[SosWidgetService] Received onSosTriggered MethodChannel call from native widget');
        onSosTriggered();
      }
    });
  }

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

  /// Queries native Android `MainActivity` to check if the app was launched directly
  /// from the home screen SOS widget.
  static Future<bool> checkPendingSos() async {
    try {
      final bool shouldTrigger =
          await _channel.invokeMethod('checkPendingSos') ?? false;
      if (shouldTrigger) {
        debugPrint('[SosWidgetService] Pending SOS widget intent detected');
      }
      return shouldTrigger;
    } catch (e) {
      debugPrint('[SosWidgetService] Error checking pending SOS: $e');
      return false;
    }
  }
}
