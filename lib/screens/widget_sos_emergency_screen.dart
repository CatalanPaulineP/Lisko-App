// ==============================================================================
// Lisko Mobile Safety Application - Widget SOS Emergency Screen
// File: lib/screens/widget_sos_emergency_screen.dart
//
// Role & Architectural Context:
// Root Flutter screen mounted when [SosEmergencyActivity] launches via Home Screen widget tap.
// Manages strict setup verification (checking, verifiedIncomplete, verificationError, readyForSos),
// initializes widget-engine dependencies, and displays the 5-second countdown overlay.
// ==============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../firebase_options.dart';
import '../services/emergency_dispatch_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import 'emergency_alert_screen.dart';

enum WidgetSetupState {
  checking,
  verifiedIncomplete,
  verificationError,
  readyForSos,
}

/// Screen mounted by dedicated [SosEmergencyActivity] when SOS widget is tapped.
class WidgetSosEmergencyScreen extends StatefulWidget {
  const WidgetSosEmergencyScreen({super.key});

  @override
  State<WidgetSosEmergencyScreen> createState() => _WidgetSosEmergencyScreenState();
}

class _WidgetSosEmergencyScreenState extends State<WidgetSosEmergencyScreen> {
  static const MethodChannel _activityChannel =
      MethodChannel('com.lisko.safety/sos_emergency_activity');

  WidgetSetupState _state = WidgetSetupState.checking;

  @override
  void initState() {
    super.initState();
    _checkSetupAndRun();
  }

  Future<void> _checkSetupAndRun() async {
    if (mounted && _state != WidgetSetupState.checking) {
      setState(() {
        _state = WidgetSetupState.checking;
      });
    }

    try {
      const storage = LocalStorageService();
      final bool setupCompleted = await storage.readSetupCompletedStrict();

      if (!setupCompleted) {
        debugPrint('[WidgetSosEmergencyScreen] Verified setup_completed is FALSE.');
        if (mounted) {
          setState(() {
            _state = WidgetSetupState.verifiedIncomplete;
          });
        }
        return;
      }

      // Best-effort initialization of widget-engine dependencies
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[WidgetSosEmergencyScreen] Best-effort Firebase init succeeded.');
      } catch (e) {
        debugPrint('[WidgetSosEmergencyScreen] Best-effort Firebase init note: $e');
      }

      try {
        await NotificationService().initialize();
        debugPrint('[WidgetSosEmergencyScreen] Best-effort NotificationService init succeeded.');
      } catch (e) {
        debugPrint('[WidgetSosEmergencyScreen] Best-effort NotificationService init note: $e');
      }

      if (mounted) {
        setState(() {
          _state = WidgetSetupState.readyForSos;
        });
        await const LocalStorageService().saveEmergencyActive(true);
      }
    } catch (e, st) {
      debugPrint('[WidgetSosEmergencyScreen] Setup verification error: $e\n$st');
      if (mounted) {
        setState(() {
          _state = WidgetSetupState.verificationError;
        });
      }
    }
  }

  Future<void> _finishActivity() async {
    await const LocalStorageService().saveEmergencyActive(false);
    try {
      await _activityChannel.invokeMethod('finishSosActivity');
    } catch (_) {}
  }

  Future<void> _openOnboardingAndFinish() async {
    await const LocalStorageService().saveEmergencyActive(false);
    try {
      await _activityChannel.invokeMethod('openOnboardingAndFinish');
    } catch (_) {
      await _finishActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case WidgetSetupState.checking:
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );

      case WidgetSetupState.verifiedIncomplete:
        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFDAD8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Complete LisKo Setup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please complete LisKo safety setup before using the Home Screen SOS widget.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.body,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _openOnboardingAndFinish,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Open LisKo Setup',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _finishActivity,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.header,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case WidgetSetupState.verificationError:
        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.header.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.header,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unable to Verify Setup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'LisKo couldn\'t verify your setup. Please try again.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.body,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _checkSetupAndRun,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.header,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _finishActivity,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.header,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case WidgetSetupState.readyForSos:
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: EmergencyAlertScreen(
            isManualSos: true,
            immediateExecute: false,
            skipCompletionDelay: true,
            onExecute: () async {
              await EmergencyDispatchService().executeManualSosDispatch();
              await _finishActivity();
            },
            onCancel: () async {
              await _finishActivity();
            },
          ),
        );
    }
  }
}
