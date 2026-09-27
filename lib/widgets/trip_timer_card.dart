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

import 'dart:async';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import 'app_icon.dart';

/// Card displaying inactive, staged, or active circular trip countdown.
class TripTimerCard extends StatelessWidget {
  const TripTimerCard({
    super.key,
    this.timeText = '__:__:__',
    this.statusText = 'NO ACTIVE TRIP',
    this.isActive = false,
    this.isStaged = false,
    this.onAdjustMinutes,
    this.onEditSetup,
  });

  /// Countdown string to display (e.g., `__:__:__` or `00:45:00`).
  final String timeText;

  /// Status badge subtext (e.g., `NO ACTIVE TRIP` or `COMMUTING`).
  final String statusText;

  /// Whether a trip is currently in progress.
  final bool isActive;

  /// Whether a trip timer is staged/saved before clicking Start.
  final bool isStaged;

  /// Callback to adjust minutes directly when staged.
  final ValueChanged<int>? onAdjustMinutes;

  /// Callback to re-open setup sheet when staged or set up timer when tapped.
  final VoidCallback? onEditSetup;

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
          // Circular Trip Timer Display Widget (Tappable to edit/configure)
          GestureDetector(
            onTap: onEditSetup,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 136,
              height: 136,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Neutral Inactive or Active/Staged Ring
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? AppColors.success
                            : isStaged
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                        width: 6,
                      ),
                    ),
                  ),
                  // Centered Placeholder Countdown & Status Subtext
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: (isActive || isStaged)
                                ? AppColors.header
                                : mutedSlate,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ScrollingMarqueeText(
                          text: statusText,
                          style: TextStyle(
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? AppColors.successText
                                : isStaged
                                    ? AppColors.primary
                                    : mutedSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isStaged) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => onAdjustMinutes?.call(-5),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.header,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('- 5m', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onEditSetup,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => onAdjustMinutes?.call(5),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.header,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('+ 5m', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated scrolling text for status labels that exceed the inner ring width.
class ScrollingMarqueeText extends StatefulWidget {
  const ScrollingMarqueeText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<ScrollingMarqueeText> createState() => _ScrollingMarqueeTextState();
}

class _ScrollingMarqueeTextState extends State<ScrollingMarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  @override
  void didUpdateWidget(covariant ScrollingMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
    }
  }

  void _startMarquee() {
    _timer?.cancel();
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      final current = _scrollController.offset;
      if (current >= max) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(current + 1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          widget.text,
          style: widget.style,
        ),
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

