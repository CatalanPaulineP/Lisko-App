// ==============================================================================
// Lisko Mobile Safety Application - Dashboard Components
// File: lib/widgets/trip_timer_card.dart
//
// Role & Architectural Context:
// Central home dashboard visualizer. Displays the circular countdown ring in
// both inactive and active states, alongside the high-priority `SosWarningBox`
// emergency dispatch trigger.
//
// Inactive Trip Timer Design:
// When no trip is active, the circular timer presents a neutral `#E2E8F0` ring
// with muted slate grey (`#64748B`) placeholder countdown text `"__:__:__"`
// and subtitle `"NO ACTIVE TRIP"`. This transparently communicates to the student
// that background GPS tracking is strictly idle, preserving battery and honoring
// zero-surveillance privacy.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Ergonomics & Stress-Responsive Cues): `SosWarningBox` provides a
//   high-contrast 62dp touch container with prominent warning iconography and clear
//   activation instructions ("Hold 3s or Double Tap") ensuring rapid emergency action.
// ==============================================================================

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import 'app_icon.dart';

/// Card displaying inactive or active circular trip countdown.
class TripTimerCard extends StatelessWidget {
  const TripTimerCard({
    super.key,
    this.timeText = '__:__:__',
    this.statusText = 'NO ACTIVE TRIP',
    this.isActive = false,
  });

  /// Countdown string to display (e.g., `__:__:__` or `00:45:00`).
  final String timeText;

  /// Status badge subtext (e.g., `NO ACTIVE TRIP` or `COMMUTING`).
  final String statusText;

  /// Whether a trip is currently in progress.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    const mutedSlate = Color(0xFF64748B);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TRIP TIMER',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 10),
          // Circular Trip Timer Display Widget
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Neutral Inactive Ring
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppColors.success : const Color(0xFFE2E8F0),
                      width: 6,
                    ),
                  ),
                ),
                // Centered Placeholder Countdown & Status Subtext
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isActive ? AppColors.header : mutedSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                        color: isActive ? AppColors.successText : mutedSlate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard reusable card container for dashboard sections.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// SOS Emergency shortcut banner with clear instructional cues.
class SosWarningBox extends StatelessWidget {
  const SosWarningBox({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.28),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.65)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon.standard(
              AppIcons.warning,
              color: AppColors.primary,
              semanticIcon: Icons.warning_rounded,
            ),
            SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Hold 3s or Double Tap',
                  style: TextStyle(fontSize: 11, color: AppColors.body),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

