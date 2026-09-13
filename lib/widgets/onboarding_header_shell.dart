// ==============================================================================
// LisKo Mobile Safety Application - Core Scaffolding
// File: lib/widgets/onboarding_header_shell.dart
//
// Role & Architectural Context:
// Structural framework for the 5-step onboarding wizard. Unifies top navigation,
// segmented progress visualization, page layout scroll containers, and bottom
// action CTA anchors into a cohesive `SetupScaffold`.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Operability & Navigation Safety): Features a persistent `TopHeader`
//   with an internal `_popping` guard. This prevents rapid multi-taps on the back
//   button from popping multiple routes simultaneously and dumping the user back
//   at the Welcome carousel unexpectedly.
// - Usability (Visual Continuity): Employs a Flutter `Hero` widget combined with a
//   custom `fixedOnboardingHeader` flight shuttle builder to seamlessly animate the
//   progress bar across route steps without glitchy intermediate redraws.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import 'app_icon.dart';

/// Top header for the onboarding wizard with progress indicator and debounced back button.
class TopHeader extends StatefulWidget {
  const TopHeader({super.key, required this.step, this.onBack});

  /// Current active step (1 through 5).
  final int step;

  /// Optional custom back navigation callback. Falls back to `Navigator.pop(context)`.
  final VoidCallback? onBack;

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  bool _popping = false;

  void _handleBack() {
    if (_popping) return;
    _popping = true;
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const AppIcon.standard(
              AppIcons.arrowBack,
              color: Colors.white,
              semanticIcon: Icons.arrow_back_rounded,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(
            'Step ${widget.step} of 5',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: SegmentedProgress(filled: widget.step)),
        ],
      ),
    );
  }
}

/// 5-segment progress bar reflecting the onboarding step.
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({super.key, required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
            decoration: BoxDecoration(
              color: index < filled ? AppColors.primary : const Color(0xFF475569),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed Hero flight shuttle that maintains seamless header rendering across page transitions.
Widget fixedOnboardingHeader(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  // During forward or backward transitions, render the target destination header
  // to avoid displaying obsolete step states in transit.
  return toHeroContext.widget;
}

/// Standardized scaffold for onboarding setup screens with persistent header shell.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.bottom,
    this.onBack,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Hero(
              tag: 'onboarding-header',
              flightShuttleBuilder: fixedOnboardingHeader,
              child: Material(
                type: MaterialType.transparency,
                child: TopHeader(step: step, onBack: onBack),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.header,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.body,
                      ),
                    ),
                    const SizedBox(height: 28),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: bottom,
            ),
          ],
        ),
      ),
    );
  }
}
