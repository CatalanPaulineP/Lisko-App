// ==============================================================================
// Lisko Mobile Safety Application - Walkthrough Tutorial Overlay
// File: lib/widgets/walkthrough_overlay.dart
//
// Role & Architectural Context:
// Interactive walkthrough tutorial overlay with dynamic GlobalKey runtime anchoring,
// speech bubble arrow pointer tail, and animated bouncing hand pointer.
//
// Sequence: 15 numbered steps + 1 final completion step
// 1 of 15: Home Tab Overview (Center modal)
// 2 of 15: Setting up a Trip (Highlights SET UP TRIP button)
// 3 of 15: Send Distress Signal (Highlights SOS button)
// 4 of 15: Trips Tab (Highlights Trips Tab in bottom nav)
// 5 of 15: Trips Summary (Highlights Summary Card)
// 6 of 15: Filter by Time Range (Highlights Time Filter Chips)
// 7 of 15: Find a Specific Date (Highlights Calendar Filter Icon)
// 8 of 15: Contacts Tab (Highlights Contacts Tab in bottom nav)
// 9 of 15: Add Trusted Contact (Highlights Add Button)
// 10 of 15: Import from Contacts (Highlights Import Button)
// 11 of 15: Settings Tab (Highlights Settings Tab in bottom nav)
// 12 of 15: Home Location Pin (Highlights Home Pin)
// 13 of 15: Expiry Alert Mode (Highlights Timer Expiry)
// 14 of 15: Protect Trusted Contacts (Highlights Protect Trusted Contacts row)
// 15 of 15: Home Screen SOS Widget (Highlights Home Screen SOS Widget row)
// Final: All Done! (Center completion modal, FINISH button)
// ==============================================================================

import 'dart:math' as math;

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
  settingsProtectContacts,
  settingsSosWidget,
  tripModalDestination,
  tripModalTimer,
  tripModalSaveButton,
  activeTripStartButton,
  tripsExportButton,
}

enum ArrowDirection { down, up, right }

class WalkthroughOverlay extends StatefulWidget {
  const WalkthroughOverlay({
    super.key,
    required this.onTabChangeRequested,
    required this.onDismiss,
    this.onStepChanged,
    this.onModalTriggerRequested,
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
    this.protectContactsKey,
    this.sosWidgetKey,
    this.tripModalDestinationKey,
    this.tripModalTimerKey,
    this.tripModalSaveButtonKey,
    this.activeTripStartButtonKey,
    this.tripsExportKey,
    this.initialStep = 0,
    this.endStep = 18,
  });

  final ValueChanged<int> onTabChangeRequested;
  final VoidCallback onDismiss;
  final ValueChanged<int>? onStepChanged;
  final VoidCallback? onModalTriggerRequested;
  final int initialStep;
  final int endStep;
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
  final GlobalKey? protectContactsKey;
  final GlobalKey? sosWidgetKey;
  final GlobalKey? tripModalDestinationKey;
  final GlobalKey? tripModalTimerKey;
  final GlobalKey? tripModalSaveButtonKey;
  final GlobalKey? activeTripStartButtonKey;
  final GlobalKey? tripsExportKey;

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isReady = false;
  bool _showSectionComplete = false;

  late final AnimationController _completionController;
  late final Animation<double> _badgeScaleAnimation;
  late final Animation<double> _badgeFadeAnimation;

  static List<ConfettiParticle> _generateParticles() {
    final List<ConfettiParticle> list = [];
    final colors = [
      AppColors.success,
      AppColors.primary,
      const Color(0xFFD97706),
      const Color(0xFF10B981),
      AppColors.header,
      const Color(0xFF38BDF8),
    ];
    const count = 20;
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi) / count) + (i % 2 == 0 ? 0.1 : -0.1);
      final speed = 75.0 + (i % 5) * 22.0;
      final size = 5.5 + (i % 3) * 2.5;
      final color = colors[i % colors.length];
      list.add(
        ConfettiParticle(angle: angle, speed: speed, color: color, size: size),
      );
    }
    return list;
  }

  static final List<ConfettiParticle> _particles = _generateParticles();

  static const List<WalkthroughStep> _steps = [
    // Step 1 of 15: Home Tab Overview
    WalkthroughStep(
      title: 'Home Tab',
      stepNumberText: '1 of 15',
      description:
          'Welcome to your dashboard. From here, you can set up active trips and quickly send emergency alerts when needed.',
      targetPosition: TargetPosition.center,
      targetTab: 0,
    ),
    // Step 2 of 15: Setting up a Trip
    WalkthroughStep(
      title: 'Setting up a Trip',
      stepNumberText: '2 of 15',
      description:
          'Tap Set Up Trip to set your destination and estimated travel duration before heading out.',
      targetPosition: TargetPosition.setUpTripButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Index 2: Step 2.1
    WalkthroughStep(
      title: 'Destination',
      stepNumberText: '2.1 of 15',
      description:
          'Where are you heading? Choose Home, Campus, or tap Custom to select terminals, loading stops, and drop-off points.',
      targetPosition: TargetPosition.tripModalDestination,
      targetTab: 0,
      arrowDirection: ArrowDirection.up,
    ),
    // Index 3: Step 2.2
    WalkthroughStep(
      title: 'Travel Timer',
      stepNumberText: '2.2 of 15',
      description:
          'Pick a quick time preset or fine-tune the hours and minutes for your trip.',
      targetPosition: TargetPosition.tripModalTimer,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Index 4: Step 2.3
    WalkthroughStep(
      title: 'Save your Trip',
      stepNumberText: '2.3 of 15',
      description:
          'Tap here to save your destination and timer settings to begin monitoring your travel.',
      targetPosition: TargetPosition.tripModalSaveButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Index 5: Step 2.4
    WalkthroughStep(
      title: 'Start your Trip',
      stepNumberText: '2.4 of 15',
      description:
          'Tap Start Trip to begin tracking. You can still adjust your timer or change your destination before you head out.',
      targetPosition: TargetPosition.activeTripStartButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 3 of 15: Send Distress Signal
    WalkthroughStep(
      title: 'Send Distress Signal',
      stepNumberText: '3 of 15',
      description:
          'Tap once to alert your trusted contacts when you need emergency assistance.',
      targetPosition: TargetPosition.sosButton,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 4 of 15: Trips Tab Navigation
    WalkthroughStep(
      title: 'Trips Tab',
      stepNumberText: '4 of 15',
      description:
          'Tap here to view and manage your trip history, summaries, filters, and dates.',
      targetPosition: TargetPosition.tripsTabIcon,
      targetTab: 0,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 5 of 15: Trips Summary
    WalkthroughStep(
      title: 'Trips Summary',
      stepNumberText: '5 of 15',
      description:
          'View a quick breakdown of your recorded trips by Total, Arrived, Extended, or Alerts. Tap any segment to filter your list.',
      targetPosition: TargetPosition.tripsSummaryCard,
      targetTab: 1,
      arrowDirection: ArrowDirection.up,
    ),
    // Index 9: Step 5.1
    WalkthroughStep(
      title: 'Export Trip History',
      stepNumberText: '5.1 of 15',
      description:
          'Tap Export to generate a PDF report of your trip history. You can save this file to your device or share it directly through your preferred messaging apps.',
      targetPosition: TargetPosition.tripsExportButton,
      targetTab: 1,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 6 of 15: Filter by Time Range
    WalkthroughStep(
      title: 'Filter by Time Range',
      stepNumberText: '6 of 15',
      description:
          'Filter your trip history by selecting All or This Week to quickly view specific logs.',
      targetPosition: TargetPosition.tripsFilterChips,
      targetTab: 1,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 7 of 15: Find a Specific Date
    WalkthroughStep(
      title: 'Find a Specific Date',
      stepNumberText: '7 of 15',
      description:
          'Use the date filter when you want to find trips from a specific day.',
      targetPosition: TargetPosition.tripsFilterIcon,
      targetTab: 1,
      arrowDirection: ArrowDirection.right,
    ),
    // Step 8 of 15: Contacts Tab Transition
    WalkthroughStep(
      title: 'Contacts Tab',
      stepNumberText: '8 of 15',
      description:
          'Tap here to view and manage the trusted contacts who receive your emergency alerts.',
      targetPosition: TargetPosition.contactsTabIcon,
      targetTab: 1,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 9 of 15: Add Trusted Contact
    WalkthroughStep(
      title: 'Add a Trusted Contact',
      stepNumberText: '9 of 15',
      description:
          'Tap the Add button to manually enter a new emergency contact’s details.',
      targetPosition: TargetPosition.addContactButton,
      targetTab: 2,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 10 of 15: Import from Contacts
    WalkthroughStep(
      title: 'Import from Contacts',
      stepNumberText: '10 of 15',
      description:
          'Import a trusted contact directly from your phone’s contact list.',
      targetPosition: TargetPosition.importContactsButton,
      targetTab: 2,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 11 of 15: Settings Tab Transition
    WalkthroughStep(
      title: 'Settings Tab',
      stepNumberText: '11 of 15',
      description:
          'Tap here to manage your home location, alert modes, and app preferences.',
      targetPosition: TargetPosition.settingsTabIcon,
      targetTab: 2,
      arrowDirection: ArrowDirection.down,
      showNextButton: false,
    ),
    // Step 12 of 15: Home Location Pin
    WalkthroughStep(
      title: 'Home Location Pin',
      stepNumberText: '12 of 15',
      description:
          'Set your home coordinates to enable automatic arrival detection when you get home.',
      targetPosition: TargetPosition.settingsHomePin,
      targetTab: 3,
      arrowDirection: ArrowDirection.up,
    ),
    // Step 13 of 15: Expiry Alert Mode
    WalkthroughStep(
      title: 'Expiry Alert Mode',
      stepNumberText: '13 of 15',
      description:
          'Choose between vibration or sound alerts for when your trip timer is about to expire.',
      targetPosition: TargetPosition.settingsTimerExpiry,
      targetTab: 3,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 14 of 15: Protect Trusted Contacts
    WalkthroughStep(
      title: 'Protect Trusted Contacts',
      stepNumberText: '14 of 15',
      description:
          'Use your device authentication to protect your trusted contacts from unauthorized changes.',
      targetPosition: TargetPosition.settingsProtectContacts,
      targetTab: 3,
      arrowDirection: ArrowDirection.down,
    ),
    // Step 15 of 15: Home Screen SOS Widget
    WalkthroughStep(
      title: 'Home Screen SOS Widget',
      stepNumberText: '15 of 15',
      description:
          'Learn how to add a Home Screen shortcut that starts the 5-second SOS countdown and sends an emergency SMS when the countdown completes.',
      targetPosition: TargetPosition.settingsSosWidget,
      targetTab: 3,
      arrowDirection: ArrowDirection.down,
    ),
    // Final Step: All Done!
    WalkthroughStep(
      title: 'All Done!',
      stepNumberText: '',
      description:
          "You're all set to use Lisko. Stay safe on your journeys, Iskolar!",
      targetPosition: TargetPosition.center,
      targetTab: 3,
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    // Trigger modal if starting at steps 2.1-2.3 (indices 2, 3, 4)
    if (_currentStep >= 2 && _currentStep <= 4) {
      widget.onModalTriggerRequested?.call();
    }

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

    GoogleFonts.pendingFonts([GoogleFonts.plusJakartaSans()]);

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
    if (_currentStep < widget.endStep && _currentStep < _steps.length - 1) {
      final next = _currentStep + 1;

      // Trigger modal if moving to step 2.1 (index 2)
      if (next == 2) {
        widget.onModalTriggerRequested?.call();
      }

      // Close modal if moving from step 2.3 (index 4) to 2.4 (index 5)
      if (_currentStep == 4) {
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _currentStep = next;
              _isReady = false;
            });
            if (_steps[next].isLast) {
              _completionController.forward(from: 0.0);
            }
            widget.onTabChangeRequested(_steps[next].targetTab);
            widget.onStepChanged?.call(next);
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted) {
                setState(() {
                  _isReady = true;
                });
              }
            });
          }
        });
        return;
      }

      setState(() {
        _currentStep = next;
        _isReady = false;
      });
      if (_steps[next].isLast) {
        _completionController.forward(from: 0.0);
      }
      widget.onTabChangeRequested(_steps[next].targetTab);
      widget.onStepChanged?.call(next);

      // Dynamic delay based on transition type (modal/tab/complex layout)
      int delayMs = 150;
      if (next == 2) {
        delayMs = 500; // Wait for bottom sheet slide-in
      }
      if (next == 6) {
        delayMs = 350; // Ensure Home Tab is fully settled after modal closure
      }

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          setState(() {
            _isReady = true;
          });
          if (_steps[_currentStep].isLast) {
            _completionController.forward(from: 0.0);
          }
        }
      });
    } else {
      if (_currentStep == widget.endStep && !_steps[_currentStep].isLast) {
        setState(() {
          _showSectionComplete = true;
        });
        _completionController.forward(from: 0.0);
        return;
      }
      _finishWalkthrough();
    }
  }

  void _finishWalkthrough() async {
    widget.onTabChangeRequested(0);
    await const LocalStorageService().saveWalkthroughCompleted(true);
    widget.onDismiss();
  }

  Rect _getRectFromKey(GlobalKey? key, Size screenSize) {
    if (key == null) {
      return Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 2,
        height: 2,
      );
    }
    final context = key.currentContext;
    if (context == null) {
      return Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 2,
        height: 2,
      );
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 2,
        height: 2,
      );
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  Rect _calculateTargetRect(TargetPosition pos, Size size) {
    Rect rect = Rect.zero;
    switch (pos) {
      case TargetPosition.setUpTripButton:
        rect = _getRectFromKey(widget.setUpTripKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.sosButton:
        rect = _getRectFromKey(widget.sosKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.tripsTabIcon:
      case TargetPosition.contactsTabIcon:
        final GlobalKey? key = pos == TargetPosition.tripsTabIcon
            ? widget.tripsTabKey
            : widget.contactsTabKey;
        rect = _getRectFromKey(key, size);
        rect = Rect.fromCenter(
          center: Offset(rect.center.dx, rect.center.dy + 5.0),
          width: 74.0,
          height: 48.0,
        );
        break;
      case TargetPosition.settingsTabIcon:
        rect = _getRectFromKey(widget.settingsTabKey, size);
        rect = Rect.fromCenter(
          center: Offset(rect.center.dx, rect.center.dy + 4.0),
          width: 64.0,
          height: 44.0,
        );
        break;
      case TargetPosition.tripsSummaryCard:
        rect = _getRectFromKey(widget.tripsSummaryKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.tripsFilterChips:
        rect = _getRectFromKey(widget.tripsFilterChipsKey, size);
        final tightWidth = 270.0.clamp(180.0, size.width - 40.0);
        rect = Rect.fromLTWH(20.0, rect.top - 2, tightWidth, rect.height + 4);
        break;
      case TargetPosition.tripsFilterIcon:
        rect = _getRectFromKey(widget.tripsCalendarIconKey, size);
        rect = Rect.fromLTWH(
          rect.left - 6,
          rect.top - 6,
          rect.width + 12,
          rect.height + 12,
        );
        break;
      case TargetPosition.addContactButton:
        rect = _getRectFromKey(widget.addContactKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.importContactsButton:
        rect = _getRectFromKey(widget.importContactsKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.settingsHomePin:
        rect = _getRectFromKey(widget.homeLocationKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.settingsTimerExpiry:
        rect = _getRectFromKey(widget.expiryAlertKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.settingsProtectContacts:
        rect = _getRectFromKey(widget.protectContactsKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.settingsSosWidget:
        rect = _getRectFromKey(widget.sosWidgetKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.tripModalDestination:
        rect = _getRectFromKey(widget.tripModalDestinationKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 4,
          rect.width + 8,
          rect.height + 8,
        );
        break;
      case TargetPosition.tripModalTimer:
        rect = _getRectFromKey(widget.tripModalTimerKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 4,
          rect.width + 8,
          rect.height + 8,
        );
        break;
      case TargetPosition.tripModalSaveButton:
        rect = _getRectFromKey(widget.tripModalSaveButtonKey, size);
        rect = Rect.fromLTWH(
          rect.left - 2,
          rect.top - 2,
          rect.width + 4,
          rect.height + 4,
        );
        break;
      case TargetPosition.activeTripStartButton:
        rect = _getRectFromKey(widget.activeTripStartButtonKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 4,
          rect.width + 8,
          rect.height + 8,
        );
        break;
      case TargetPosition.tripsExportButton:
        rect = _getRectFromKey(widget.tripsExportKey, size);
        rect = Rect.fromLTWH(
          rect.left - 4,
          rect.top - 2,
          rect.width + 8,
          rect.height + 4,
        );
        break;
      case TargetPosition.center:
        return Rect.zero;
    }

    return rect;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final size = MediaQuery.sizeOf(context);

    final targetRect = _showSectionComplete
        ? Rect.zero
        : _calculateTargetRect(step.targetPosition, size);

    final bool showCard = _isReady;
    final bool isBottomTab =
        !_showSectionComplete &&
        (step.targetPosition == TargetPosition.tripsTabIcon ||
            step.targetPosition == TargetPosition.contactsTabIcon ||
            step.targetPosition == TargetPosition.settingsTabIcon);

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
                  targetRect: targetRect == Rect.zero ? null : targetRect,
                  borderRadius: isBottomTab ? 12.0 : 16.0,
                ),
              ),
            ),
          ),

          // Tappable cutout region for highlighted targets
          if (targetRect != Rect.zero)
            Positioned.fromRect(
              rect: targetRect,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (step.targetPosition == TargetPosition.tripsTabIcon) {
                    widget.onTabChangeRequested(1);
                  } else if (step.targetPosition ==
                      TargetPosition.contactsTabIcon) {
                    widget.onTabChangeRequested(2);
                  } else if (step.targetPosition ==
                      TargetPosition.settingsTabIcon) {
                    widget.onTabChangeRequested(3);
                  }
                  _nextStep();
                },
              ),
            ),

          // Bouncing Animated Pointing Hand
          if (isBottomTab)
            _buildAnimatedPointer(step, size, targetRect, showCard),

          // Floating Speech Bubble Tutorial Card Box
          _buildTooltipCard(step, size, targetRect, showCard),
        ],
      ),
    );
  }

  Widget _buildAnimatedPointer(
    WalkthroughStep step,
    Size size,
    Rect targetRect,
    bool showCard,
  ) {
    if (!showCard) return const SizedBox.shrink();

    if (targetRect != Rect.zero) {
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

  Widget _buildTooltipCard(
    WalkthroughStep step,
    Size size,
    Rect targetRect,
    bool showCard,
  ) {
    if (!showCard) return const SizedBox.shrink();

    final bool showArrow =
        !_showSectionComplete &&
        targetRect != Rect.zero &&
        step.targetPosition != TargetPosition.center;

    if (showArrow) {
      if (step.arrowDirection == ArrowDirection.up) {
        // Speech bubble sitting BELOW targetRect with arrow pointing UP
        final double arrowLeft = (targetRect.center.dx - 10).clamp(
          36.0,
          size.width - 56.0,
        );
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
        final double topDist = (targetRect.top - 20).clamp(
          40.0,
          size.height - 230,
        );
        final double arrowTop = (targetRect.center.dy - topDist - 10).clamp(
          12.0,
          120.0,
        );

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
        final double arrowLeft = (targetRect.center.dx - 10).clamp(
          36.0,
          size.width - 56.0,
        );
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

    // Final Step: Center completion modal with radial particle burst and card scale/fade entry
    if (step.isLast) {
      final isReducedMotion = MediaQuery.of(context).disableAnimations;

      final cardScaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(
          parent: _completionController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
        ),
      );

      final cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _completionController,
          curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
        ),
      );

      return Positioned.fill(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          opacity: showCard ? 1.0 : 0.0,
          child: Stack(
            children: [
              // Radial celebratory particle burst framing the completion card
              if (!isReducedMotion)
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

              // Centered completion card with smooth scale & fade entry
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Center(
                  child: ScaleTransition(
                    scale: isReducedMotion
                        ? const AlwaysStoppedAnimation(1.0)
                        : cardScaleAnimation,
                    child: FadeTransition(
                      opacity: isReducedMotion
                          ? const AlwaysStoppedAnimation(1.0)
                          : cardFadeAnimation,
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
              ),
            ],
          ),
        ),
      );
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
    final bool isWholeLast = step.isLast;
    final bool isDoneStep = isWholeLast || _showSectionComplete;

    final bool showNext = step.showNextButton && !isDoneStep;
    final bool isReducedMotion = MediaQuery.of(context).disableAnimations;

    final String title = _showSectionComplete
        ? 'Section Complete!'
        : step.title;
    final String description = _showSectionComplete
        ? "You've finished this section of the walkthrough."
        : step.description;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isDoneStep
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (isDoneStep) ...[
          Center(
            child: ScaleTransition(
              scale: isReducedMotion
                  ? const AlwaysStoppedAnimation(1.0)
                  : _badgeScaleAnimation,
              child: FadeTransition(
                opacity: isReducedMotion
                    ? const AlwaysStoppedAnimation(1.0)
                    : _badgeFadeAnimation,
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
          mainAxisAlignment: isDoneStep
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                textScaler: TextScaler.noScaling,
                textAlign: isDoneStep ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
            ),
            if (step.stepNumberText.isNotEmpty &&
                !isDoneStep &&
                !_showSectionComplete)
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
          description,
          textScaler: TextScaler.noScaling,
          textAlign: isDoneStep ? TextAlign.center : TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: isDoneStep
              ? MainAxisAlignment.center
              : (showNext
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.end),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isDoneStep)
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
            if (isDoneStep)
              ElevatedButton(
                onPressed: isWholeLast ? _finishWalkthrough : widget.onDismiss,
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
                  'DONE',
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

    _animation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        RRect.fromRectAndRadius(targetRect!, Radius.circular(borderRadius)),
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
      RRect.fromRectAndRadius(targetRect!, Radius.circular(borderRadius)),
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
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
}

/// CustomPainter drawing a subtle zero-dependency particle animation on final walkthrough completion.
class ConfettiParticlePainter extends CustomPainter {
  ConfettiParticlePainter({required this.progress, required this.particles});

  final double progress;
  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final curvedProgress = Curves.easeOutCubic.transform(progress);
    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final distance = p.speed * curvedProgress;
      final dyGravity = curvedProgress * curvedProgress * 30.0;
      final x = center.dx + distance * math.cos(p.angle);
      final y = center.dy + distance * math.sin(p.angle) + dyGravity;
      final opacity = (fadeOut * 1.2).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + curvedProgress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.65,
          ),
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
