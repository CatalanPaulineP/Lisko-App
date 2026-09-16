// ==============================================================================
// LisKo Mobile Safety Application - Active Trip Tracking View
// File: lib/screens/active_trip_screen.dart
//
// Role & Architectural Context:
// Live commute monitoring view displayed inside `HomeScreen` while a travel trip
// is active. Replaces the idle home dashboard with real-time countdown tracking,
// safe arrival confirmation, trip duration extension, and SOS escalation.
//
// Layout Structure (3 sections):
// 1. Navy Header   — edge-to-edge Container with trip status, destination, duration.
// 2. Centered Ring — Expanded + Center so CountdownRing floats in the middle.
// 3. Bottom Buttons — SafeArea + Padding with SafeButton, +15min, and SOS.
//
// Geofencing & Safety Escalation Logic:
// - Countdown Visualization: `CountdownRing` calculates elapsed vs total duration,
//   rendering an emerald green circular arc that smoothly depletes as the student travels.
// - False Alarm Prevention: Commutes commonly face traffic delays; the `+ 15 min`
//   extension button provides a single-tap extension without triggering false emergency alerts.
// - Arrival Confirmation: `SafeButton` ("I'm Safe / Arrive") records completed arrival,
//   terminates tracking, and logs the trip into local history.
// - Emergency Escalation: "Need Help / SOS" opens immediate alert confirmation to
//   prepare emergency dispatch to trusted contacts.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Rapid Emergency Response): High-visibility countdown and debounced
//   touch targets ensure error-free operation even in urgent or stressful scenarios.
// ==============================================================================

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../widgets/action_buttons.dart';
import '../widgets/app_icon.dart';

/// Screen view displayed while a travel trip is in progress.
class ActiveTripTab extends StatelessWidget {
  const ActiveTripTab({
    super.key,
    required this.destination,
    required this.remaining,
    required this.totalDuration,
    required this.onSafe,
    required this.onExtend,
    required this.onSos,
    this.isArrived = false,
    this.arrivalRemainingSeconds = 90,
  });

  /// Target destination name (e.g., "Home" or "Campus").
  final String destination;

  /// Remaining countdown duration.
  final Duration remaining;

  /// Initial total duration configured for this trip.
  final Duration totalDuration;

  /// Callback confirming safe arrival at destination.
  final VoidCallback onSafe;

  /// Callback extending trip duration by 15 minutes.
  final VoidCallback onExtend;

  /// Callback triggering emergency SOS alert confirmation.
  final VoidCallback onSos;

  /// Whether the student's device has entered the destination geofence perimeter.
  final bool isArrived;

  /// Remaining seconds in the 90-second arrival safety verification countdown.
  final int arrivalRemainingSeconds;

  @override
  Widget build(BuildContext context) {
    if (isArrived) {
      return _buildArrivalView(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. NAVY HEADER ────────────────────────────────────────────────────
        // Edge-to-edge navy Container clearly labelling the active trip state,
        // destination name, configured duration, and live "Active" badge.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.header, // Deep Navy #1E293B
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TRIP IN PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8), // muted slate on navy
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatTripDuration(totalDuration),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const ActiveBadge(),
            ],
          ),
        ),

        // ── 2. CENTERED COUNTDOWN RING ────────────────────────────────────────
        // Expanded fills all remaining space between header and buttons.
        // Center vertically and horizontally places the ring in the middle.
        Expanded(
          child: Center(
            child: CountdownRing(
              remaining: remaining,
              totalDuration: totalDuration,
            ),
          ),
        ),

        // ── 3. BOTTOM ACTION BUTTONS ──────────────────────────────────────────
        // SafeArea (top: false) prevents overlap with the Android gesture bar.
        // Fixed padding keeps buttons away from screen edges on all form factors.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: SafeButton(onPressed: onSafe)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlineAction(
                        label: '+ 15 min',
                        icon: Icons.access_time_rounded,
                        onPressed: onExtend,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Need Help / SOS',
                  onPressed: onSos,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the high-visibility safety confirmation view upon entering geofence.
  Widget _buildArrivalView(BuildContext context) {
    final minutes = (arrivalRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (arrivalRemainingSeconds % 60).toString().padLeft(2, '0');
    final countdownFormatted = '$minutes:$seconds';
    final isUrgent = arrivalRemainingSeconds <= 30;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESTINATION REACHED',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.successText,
                    ),
                  ),
                  Text(
                    destination,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header,
                    ),
                  ),
                  const Text(
                    'Arrived within geofence perimeter',
                    style: TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Arrived',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Safety confirmation card with 90-second countdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUrgent ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isUrgent ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUrgent ? AppColors.primary : Colors.black).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon.standard(
                      AppIcons.checkCircle,
                      color: AppColors.success,
                      size: 30,
                      semanticIcon: Icons.check_circle_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'You have arrived at $destination.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Are you safe?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                // 90-second countdown indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? AppColors.primaryContainer.withValues(alpha: 0.3)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon.standard(
                        AppIcons.schedule,
                        size: 18,
                        color: isUrgent ? AppColors.primary : const Color(0xFFD97706),
                        semanticIcon: Icons.access_time_rounded,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Auto-alert in: $countdownFormatted',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isUrgent ? AppColors.primary : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please confirm your safety. If you do not respond within 90 seconds, LisKo will automatically alert your trusted emergency contacts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.body, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons: I'm Safe, Extend Time, Need Help
          SizedBox(
            width: double.infinity,
            child: SafeButton(
              onPressed: onSafe,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlineAction(
                  label: '+ 15 min',
                  icon: Icons.access_time_rounded,
                  onPressed: onExtend,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Need Help / SOS',
                  onPressed: onSos,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge indicating active trip status.
/// Colors are tuned for legibility against the navy header background.
class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.success,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.directions_run_rounded, size: 14, color: AppColors.successText),
          SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.successText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular countdown indicator with remaining time display.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.totalDuration,
  });

  final Duration remaining;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final progress = totalDuration.inSeconds == 0
        ? 0.0
        : (remaining.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 230,
            height: 230,
            child: CustomPaint(painter: _TimerGradientPainter(progress: progress)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTripDuration(remaining),
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
              const Text(
                'TIME REMAINING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.body,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Button to end trip safely and notify contacts.
class SafeButton extends StatefulWidget {
  const SafeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<SafeButton> createState() => _SafeButtonState();
}

class _SafeButtonState extends State<SafeButton> {
  DateTime _lastPressed = DateTime.fromMillisecondsSinceEpoch(0);

  void _handlePressed() {
    final now = DateTime.now();
    if (now.difference(_lastPressed) < const Duration(milliseconds: 350)) return;
    _lastPressed = now;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: _handlePressed,
          icon: const AppIcon.badge(
            AppIcons.check,
            color: Colors.white,
            semanticIcon: Icons.check_rounded,
          ),
          label: const Text("I'm Safe / Arrive"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Outlined button for extending duration with debounce protection.
class OutlineAction extends StatefulWidget {
  const OutlineAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<OutlineAction> createState() => _OutlineActionState();
}

class _OutlineActionState extends State<OutlineAction> {
  DateTime _lastPressed = DateTime.fromMillisecondsSinceEpoch(0);

  void _handlePressed() {
    final now = DateTime.now();
    if (now.difference(_lastPressed) < const Duration(milliseconds: 300)) return;
    _lastPressed = now;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _handlePressed,
        icon: AppIcon.badge(
          widget.icon == Icons.access_time_rounded
              ? AppIcons.schedule
              : AppIcons.navigation,
          color: AppColors.header,
          semanticIcon: widget.icon,
        ),
        label: Text(widget.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.header,
          side: const BorderSide(color: AppColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Formats duration as HH:MM:SS
String formatTripDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _TimerGradientPainter extends CustomPainter {
  final double progress;
  _TimerGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Gradient active arc
    final gradientPaint = Paint()
      ..shader = AppColors.timerGradient.createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Glow shadow
    final shadowPaint = Paint()
      ..color = const Color(0x6010B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, shadowPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _TimerGradientPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
