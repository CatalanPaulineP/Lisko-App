// ==============================================================================
// Lisko Mobile Safety Application - Walkthrough Tutorial Overlay
// File: lib/widgets/walkthrough_overlay.dart
//
// Role & Architectural Context:
// Interactive walkthrough tutorial overlay with dynamic GlobalKey runtime anchoring,
// speech bubble arrow pointer tail, and animated bouncing hand pointer.
//
// Sequence: 13 numbered steps + 1 final completion step
// 1 of 13: Home Tab Overview (Center modal)
// 2 of 13: Setting up a Trip (Highlights SET UP TRIP button)
// 3 of 13: Send Distress Signal (Highlights SOS button)
// 4 of 13: Trips Tab (Highlights Trips Tab in bottom nav)
// 5 of 13: Trips Summary (Highlights Summary Card)
// 6 of 13: Filter by Time Range (Highlights Time Filter Chips)
// 7 of 13: Find a Specific Date (Highlights Calendar Filter Icon)
// 8 of 13: Contacts Tab (Highlights Contacts Tab in bottom nav)
// 9 of 13: Add Trusted Contact (Highlights Add Button)
// 10 of 13: Import from Contacts (Highlights Import Button)
// 11 of 13: Settings Tab (Highlights Settings Tab in bottom nav)
// 12 of 13: Home Location Pin (Highlights Home Pin)
// 13 of 13: Expiry Alert Mode (Highlights Timer Expiry)
// Final: All Done! (Center completion modal, GET STARTED button)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/local_storage_service.dart';

class WalkthroughStep {
  const WalkthroughStep({
    required this.title,
    required this.stepNumberText,
    required this.description,
    required this.targetPosition,
    required this.targetTab,
    this.arrowDirection = ArrowDirection.down,
    this.showNextButton = true,
    this.isLast = false,
  });

  final String title;
  final String stepNumberText;
  final String description;
  final TargetPosition targetPosition;
  final int targetTab; // 0 = Home, 1 = Trips, 2 = Contacts, 3 = Settings
  final ArrowDirection arrowDirection;
  final bool showNextButton;
  final bool isLast;
}

enum TargetPosition {
  center,
  setUpTripButton,
  sosButton,
  tripsTabIcon,
  tripsSummaryCard,
  tripsFilterChips,
  tripsFilterIcon,
  contactsTabIcon,
  addContactButton,
  importContactsButton,
  settingsTabIcon,
  settingsHomePin,
  settingsTimerExpiry,
}

enum ArrowDirection { down, up, right }

class WalkthroughOverlay extends StatefulWidget {
  const WalkthroughOverlay({
    super.key,
    required this.onTabChangeRequested,
    required this.onDismiss,
    this.setUpTripKey,
    this.sosKey,
    this.tripsTabKey,
    this.tripsSummaryKey,
    this.tripsFilterChipsKey,
    this.tripsCalendarIconKey,
    this.contactsTabKey,
    this.addContactKey,
    this.importContactsKey,
    this.settingsTabKey,
    this.homeLocationKey,
    this.expiryAlertKey,
  });

  final ValueChanged<int> onTabChangeRequested;
  final VoidCallback onDismiss;
  final GlobalKey? setUpTripKey;
  final GlobalKey? sosKey;
  final GlobalKey? tripsTabKey;
  final GlobalKey? tripsSummaryKey;
  final GlobalKey? tripsFilterChipsKey;
  final GlobalKey? tripsCalendarIconKey;
  final GlobalKey? contactsTabKey;
  final GlobalKey? addContactKey;
  final GlobalKey? importContactsKey;
  final GlobalKey? settingsTabKey;
  final GlobalKey? homeLocationKey;
  final GlobalKey? expiryAlertKey;

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isReady = false;

  late final AnimationController _completionController;
  late final Animation<double> _badgeScaleAnimation;
  late final Animation<double> _badgeFadeAnimation;

  static const List<ConfettiParticle> _particles = [
    ConfettiParticle(xRatio: 0.20, yStart: 180, speedY: 0.9, speedX: -25, color: AppColors.primary, size: 8, rotationSpeed: 1.2),
    ConfettiParticle(xRatio: 0.35, yStart: 140, speedY: 1.1, speedX: -10, color: AppColors.success, size: 7, rotationSpeed: -1.5),
    ConfettiParticle(xRatio: 0.50, yStart: 120, speedY: 1.0, speedX: 5, color: Color(0xFFD97706), size: 9, rotationSpeed: 2.0),
    ConfettiParticle(xRatio: 0.65, yStart: 150, speedY: 1.2, speedX: 18, color: AppColors.primary, size: 8, rotationSpeed: -1.1),
    ConfettiParticle(xRatio: 0.80, yStart: 170, speedY: 0.95, speedX: 30, color: AppColors.success, size: 7, rotationSpeed: 1.8),
    ConfettiParticle(xRatio: 0.28, yStart: 210, speedY: 1.05, speedX: -15, color: Color(0xFFD97706), size: 6, rotationSpeed: -2.2),
    ConfettiParticle(xRatio: 0.42, yStart: 190, speedY: 1.15, speedX: 8, color: AppColors.header, size: 8, rotationSpeed: 1.4),
    ConfettiParticle(xRatio: 0.58, yStart: 200, speedY: 0.85, speedX: -8, color: AppColors.success, size: 9, rotationSpeed: -1.0),
    ConfettiParticle(xRatio: 0.72, yStart: 220, speedY: 1.1, speedX: 20, color: AppColors.primary, size: 7, rotationSpeed: 1.7),
    ConfettiParticle(xRatio: 0.15, yStart: 230, speedY: 0.8, speedX: -30, color: AppColors.header, size: 8, rotationSpeed: -1.3),
    ConfettiParticle(xRatio: 0.85, yStart: 210, speedY: 1.25, speedX: 25, color: Color(0xFFD97706), size: 6, rotationSpeed: 2.5),
    ConfettiParticle(xRatio: 0.48, yStart: 160, speedY: 0.95, speedX: -4, color: AppColors.primary, size: 8, rotationSpeed: -1.6),
  ];

  static const List<WalkthroughStep> _steps = [
    // Step 1 of 13: Home Tab Overview
    WalkthroughStep(
      title: 'Home Tab',
      stepNumberText: '1 of 13',
      description:
          'Welcome to your dashboard. From here, you can set up active trips and quickly send emergency alerts when needed.',
      targetPosition: TargetPosition.center,
      targetTab: 0,
    ),
    // Step 2 of 13: Setting up a Trip
    WalkthroughStep(
      title: 'Setting up a Trip',
      stepNumberText: '2 of 13',
      description:
          'Tap Set Up Trip to set your destination and estimated travel duration before heading out.',
      targetPosition: TargetPosition.setUpTripButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 3 of 13: Send Distress Signal
    WalkthroughStep(
      title: 'Send Distress Signal',
      stepNumberText: '3 of 13',
      description:
          'Tap once to alert your trusted contacts when you need emergency assistance.',
      targetPosition: TargetPosition.sosButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 4 of 13: Trips Tab Navigation
    WalkthroughStep(
      title: 'Trips Tab',
      stepNumberText: '4 of 13',
      description:
          'Tap here to view and manage your trip history, summaries, filters, and dates.',
      targetPosition: TargetPosition.tripsTabIcon,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 5 of 13: Trips Summary
    WalkthroughStep(
      title: 'Trips Summary',
      stepNumberText: '5 of 13',
      description:
          'View a quick breakdown of your recorded trips by Total, Arrived, Extended, or Alerts. Tap any segment to filter your list.',
      targetPosition: TargetPosition.tripsSummaryCard,
      targetTab: 1,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 6 of 13: Filter by Time Range
    WalkthroughStep(
      title: 'Filter by Time Range',
      stepNumberText: '6 of 13',
      description:
          'Filter your trip history by selecting All, This Week, or This Month to quickly view specific logs.',
      targetPosition: TargetPosition.tripsFilterChips,
      targetTab: 1,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 7 of 13: Find a Specific Date
    WalkthroughStep(
      title: 'Find a Specific Date',
      stepNumberText: '7 of 13',
      description:
          'Use the date filter when you want to find trips from a specific day.',
      targetPosition: TargetPosition.tripsFilterIcon,
      targetTab: 1,
      arrowDirection: ArrowDirection.right,
    ),
    // Step 8 of 13: Contacts Tab Transition
    WalkthroughStep(
      title: 'Contacts Tab',
      stepNumberText: '8 of 13',
      description:
          'Tap here to view and manage the trusted contacts who receive your emergency alerts.',
      targetPosition: TargetPosition.contactsTabIcon,
      targetTab: 1,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 9 of 13: Add Trusted Contact
    WalkthroughStep(
      title: 'Add a Trusted Contact',
      stepNumberText: '9 of 13',
      description:
          'Tap the Add button to manually enter a new emergency contact’s details.',
      targetPosition: TargetPosition.addContactButton,
      targetTab: 2,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 10 of 13: Import from Contacts
    WalkthroughStep(
      title: 'Import from Contacts',
      stepNumberText: '10 of 13',
      description:
          'Import a trusted contact directly from your phone’s contact list.',
      targetPosition: TargetPosition.importContactsButton,
      targetTab: 2,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 11 of 13: Settings Tab Transition
    WalkthroughStep(
      title: 'Settings Tab',
      stepNumberText: '11 of 13',
      description:
          'Tap here to manage your home location, alert modes, and app preferences.',
      targetPosition: TargetPosition.settingsTabIcon,
      targetTab: 2,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 12 of 13: Home Location Pin
    WalkthroughStep(
      title: 'Home Location Pin',
      stepNumberText: '12 of 13',
      description:
          'Set your home coordinates to enable automatic arrival detection when you get home.',
      targetPosition: TargetPosition.settingsHomePin,
      targetTab: 3,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 13 of 13: Expiry Alert Mode
    WalkthroughStep(
      title: 'Expiry Alert Mode',
      stepNumberText: '13 of 13',
      description:
          'Choose between vibration or sound alerts for when your trip timer is about to expire.',
      targetPosition: TargetPosition.settingsTimerExpiry,
      targetTab: 3,
      arrowDirection: ArrowDirection.up,
    ),
    // Final Step: All Done!
    WalkthroughStep(
      title: 'All Done!',
      stepNumberText: '',
      description:
          "You're all set to use Lisko. Stay safe on your journeys!",
      targetPosition: TargetPosition.center,
      targetTab: 3,
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _badgeScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _badgeFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    GoogleFonts.pendingFonts([
      GoogleFonts.plusJakartaSans(),
    ]);

    if (_steps[_currentStep].isLast) {
      _completionController.forward(from: 0.0);
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _completionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      final next = _currentStep + 1;
      setState(() {
        _currentStep = next;
        _isReady = false;
      });
      if (_steps[next].isLast) {
        _completionController.forward(from: 0.0);
      }
      widget.onTabChangeRequested(_steps[next].targetTab);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _isReady = true;
          });
        }
      });
    } else {
      _finishWalkthrough();
    }
  }

  void _finishWalkthrough() async {
    widget.onTabChangeRequested(0);
    await const LocalStorageService().saveWalkthroughCompleted(true);
    widget.onDismiss();
  }

  Rect? _getRectFromKey(GlobalKey? key) {
    if (key == null) return null;
    final context = key.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  Rect? _calculateTargetRect(TargetPosition pos, Size size) {
    switch (pos) {
      case TargetPosition.setUpTripButton:
        final rect = _getRectFromKey(widget.setUpTripKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.sosButton:
        final rect = _getRectFromKey(widget.sosKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.tripsTabIcon:
      case TargetPosition.contactsTabIcon:
        final GlobalKey? key = pos == TargetPosition.tripsTabIcon ? widget.tripsTabKey : widget.contactsTabKey;
        final rect = _getRectFromKey(key);
        if (rect != null) {
          return Rect.fromCenter(
            center: Offset(rect.center.dx, rect.center.dy + 5.0),
            width: 74.0,
            height: 48.0,
          );
        }
        return null;
      case TargetPosition.settingsTabIcon:
        final rect = _getRectFromKey(widget.settingsTabKey);
        if (rect != null) {
          return Rect.fromCenter(
            center: Offset(rect.center.dx, rect.center.dy + 4.0),
            width: 64.0,
            height: 44.0,
          );
        }
        return null;
      case TargetPosition.tripsSummaryCard:
        final rect = _getRectFromKey(widget.tripsSummaryKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.tripsFilterChips:
        final rect = _getRectFromKey(widget.tripsFilterChipsKey);
        if (rect != null) {
          final tightWidth = 270.0.clamp(180.0, size.width - 40.0);
          return Rect.fromLTWH(20.0, rect.top - 2, tightWidth, rect.height + 4);
        }
        return null;
      case TargetPosition.tripsFilterIcon:
        final rect = _getRectFromKey(widget.tripsCalendarIconKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 6, rect.top - 6, rect.width + 12, rect.height + 12);
        }
        return null;
      case TargetPosition.addContactButton:
        final rect = _getRectFromKey(widget.addContactKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.importContactsButton:
        final rect = _getRectFromKey(widget.importContactsKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.settingsHomePin:
        final rect = _getRectFromKey(widget.homeLocationKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.settingsTimerExpiry:
        final rect = _getRectFromKey(widget.expiryAlertKey);
        if (rect != null) {
          return Rect.fromLTWH(rect.left - 4, rect.top - 2, rect.width + 8, rect.height + 4);
        }
        return null;
      case TargetPosition.center:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final size = MediaQuery.sizeOf(context);
    final targetRect = _calculateTargetRect(step.targetPosition, size);
    final bool hasValidRect = step.targetPosition == TargetPosition.center || (targetRect != null && targetRect != Rect.zero);
    final bool showCard = _isReady && hasValidRect;
    final bool isBottomTab = step.targetPosition == TargetPosition.tripsTabIcon ||
        step.targetPosition == TargetPosition.contactsTabIcon ||
        step.targetPosition == TargetPosition.settingsTabIcon;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Spotlight Cutout Background Overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Prevent taps passing through during tutorial
              child: CustomPaint(
                painter: SpotlightOverlayPainter(
                  targetRect: targetRect,
                  borderRadius: isBottomTab ? 12.0 : 16.0,
                ),
              ),
            ),
          ),

          // Tappable cutout region for highlighted targets
          if (targetRect != null)
            Positioned.fromRect(
              rect: targetRect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (step.targetPosition == TargetPosition.tripsTabIcon) {
                    widget.onTabChangeRequested(1);
                  } else if (step.targetPosition == TargetPosition.contactsTabIcon) {
                    widget.onTabChangeRequested(2);
                  } else if (step.targetPosition == TargetPosition.settingsTabIcon) {
                    widget.onTabChangeRequested(3);
                  }
                  _nextStep();
                },
              ),
            ),

          // Bouncing Animated Pointing Hand
          if (isBottomTab)
            _buildAnimatedPointer(step, size, targetRect, showCard),

          // Particle effect on final completion step
          if (step.isLast && !MediaQuery.of(context).disableAnimations)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _completionController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: ConfettiParticlePainter(
                        progress: _completionController.value,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Floating Speech Bubble Tutorial Card Box
          _buildTooltipCard(step, size, targetRect, showCard),
        ],
      ),
    );
  }

  Widget _buildAnimatedPointer(WalkthroughStep step, Size size, Rect? targetRect, bool showCard) {
    if (!showCard) return const SizedBox.shrink();

    if (targetRect != null) {
      final pointerLeft = targetRect.center.dx - 25;
      final pointerBottom = (size.height - targetRect.top) + 8.0;

      int targetTab = 0;
      if (step.targetPosition == TargetPosition.tripsTabIcon) {
        targetTab = 1;
      } else if (step.targetPosition == TargetPosition.contactsTabIcon) {
        targetTab = 2;
      } else if (step.targetPosition == TargetPosition.settingsTabIcon) {
        targetTab = 3;
      }

      return Positioned(
        left: pointerLeft,
        bottom: pointerBottom,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          opacity: showCard ? 1.0 : 0.0,
          child: GestureDetector(
            onTap: () {
              widget.onTabChangeRequested(targetTab);
              _nextStep();
            },
            child: const BouncingPointerHand(),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTooltipCard(WalkthroughStep step, Size size, Rect? targetRect, bool showCard) {
    if (!showCard) return const SizedBox.shrink();

    final bool showArrow = targetRect != null && step.targetPosition != TargetPosition.center;

    if (showArrow) {
      if (step.arrowDirection == ArrowDirection.up) {
        // Speech bubble sitting BELOW targetRect with arrow pointing UP
        final double arrowLeft = (targetRect.center.dx - 10).clamp(36.0, size.width - 56.0);
        final double topDist = targetRect.bottom + 12.0;

        return Positioned(
          left: 20,
          right: 20,
          top: topDist,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: showCard ? 1.0 : 0.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft - 20),
                  child: CustomPaint(
                    size: const Size(20, 12),
                    painter: SpeechBubblePointerTail(
                      color: Colors.white,
                      direction: ArrowDirection.up,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _buildCardContent(step),
                ),
              ],
            ),
          ),
        );
      } else if (step.arrowDirection == ArrowDirection.right) {
        // Speech bubble sitting to the LEFT of targetRect with arrow pointing RIGHT
        final double topDist = (targetRect.top - 20).clamp(40.0, size.height - 230);
        final double arrowTop = (targetRect.center.dy - topDist - 10).clamp(12.0, 120.0);

        return Positioned(
          left: 16,
          right: size.width - targetRect.left + 8.0,
          top: topDist,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: showCard ? 1.0 : 0.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildCardContent(step),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: arrowTop),
                  child: CustomPaint(
                    size: const Size(12, 20),
                    painter: SpeechBubblePointerTail(
                      color: Colors.white,
                      direction: ArrowDirection.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Speech bubble sitting ABOVE targetRect with arrow pointing DOWN
        final double arrowLeft = (targetRect.center.dx - 10).clamp(36.0, size.width - 56.0);
        double bottomDist = (size.height - targetRect.top) + 12.0;

        // On tab transition steps (Trips Tab, Contacts Tab or Settings Tab), leave room for bouncing hand
        if (step.targetPosition == TargetPosition.tripsTabIcon ||
            step.targetPosition == TargetPosition.contactsTabIcon ||
            step.targetPosition == TargetPosition.settingsTabIcon) {
          bottomDist += 58.0;
        }

        return Positioned(
          left: 20,
          right: 20,
          bottom: bottomDist,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: showCard ? 1.0 : 0.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _buildCardContent(step),
                ),
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft - 20),
                  child: CustomPaint(
                    size: const Size(20, 12),
                    painter: SpeechBubblePointerTail(
                      color: Colors.white,
                      direction: ArrowDirection.down,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Step 1 & Step 5: Center intro cards (no arrow) - Centered in viewport
    return Positioned.fill(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        opacity: showCard ? 1.0 : 0.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: _buildCardContent(step),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(WalkthroughStep step) {
    final bool isLast = step.isLast;
    final bool showNext = step.showNextButton && !isLast;
    final bool isReducedMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLast ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (isLast) ...[
          Center(
            child: ScaleTransition(
              scale: isReducedMotion ? const AlwaysStoppedAnimation(1.0) : _badgeScaleAnimation,
              child: FadeTransition(
                opacity: isReducedMotion ? const AlwaysStoppedAnimation(1.0) : _badgeFadeAnimation,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.successContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        ],
        Row(
          mainAxisAlignment: isLast ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                step.title,
                textScaler: TextScaler.noScaling,
                textAlign: isLast ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
            ),
            if (step.stepNumberText.isNotEmpty)
              Text(
                step.stepNumberText,
                textScaler: TextScaler.noScaling,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          step.description,
          textScaler: TextScaler.noScaling,
          textAlign: isLast ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: isLast
              ? MainAxisAlignment.center
              : (showNext ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isLast)
              TextButton(
                onPressed: _finishWalkthrough,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'SKIP',
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            if (showNext)
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1.5,
                ),
                child: Text(
                  'NEXT >',
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            if (isLast)
              ElevatedButton(
                onPressed: _finishWalkthrough,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'GET STARTED',
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Triangular arrow pointer tail attached to speech bubble card edges.
class SpeechBubblePointerTail extends CustomPainter {
  SpeechBubblePointerTail({
    required this.color,
    this.direction = ArrowDirection.down,
  });

  final Color color;
  final ArrowDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (direction == ArrowDirection.down) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    } else if (direction == ArrowDirection.up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    } else if (direction == ArrowDirection.right) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePointerTail oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}

/// Animated bouncing hand pointer pointing DOWNWARDS at highlighted elements.
class BouncingPointerHand extends StatefulWidget {
  const BouncingPointerHand({super.key});

  @override
  State<BouncingPointerHand> createState() => _BouncingPointerHandState();
}

class _BouncingPointerHandState extends State<BouncingPointerHand>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value), // Bounces towards target below
          child: Transform.flip(
            flipY: true, // Inverts vertically so index finger points DOWNWARDS
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter drawing translucent dark overlay with a bright cutout spotlight framing target widgets.
class SpotlightOverlayPainter extends CustomPainter {
  SpotlightOverlayPainter({
    required this.targetRect,
    required this.borderRadius,
  });

  final Rect? targetRect;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xCC0F172A);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      return;
    }

    final screenPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          targetRect!,
          Radius.circular(borderRadius),
        ),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, backgroundPaint);

    // Draw bright glowing border around the highlighted target
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect!,
        Radius.circular(borderRadius),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// Data model for a single decorative particle shape.
class ConfettiParticle {
  const ConfettiParticle({
    required this.xRatio,
    required this.yStart,
    required this.speedY,
    required this.speedX,
    required this.color,
    required this.size,
    required this.rotationSpeed,
  });

  final double xRatio;
  final double yStart;
  final double speedY;
  final double speedX;
  final Color color;
  final double size;
  final double rotationSpeed;
}

/// CustomPainter drawing a subtle zero-dependency particle animation on final walkthrough completion.
class ConfettiParticlePainter extends CustomPainter {
  ConfettiParticlePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = size.width * p.xRatio + (p.speedX * progress * 50);
      final y = p.yStart + (p.speedY * progress * size.height * 0.35);
      final opacity = fadeOut.clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.65),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
