// ==============================================================================
// Lisko Mobile Safety Application - User Guide & Safety Protocol Screen
// File: lib/screens/user_guide_screen.dart
//
// Role & Architectural Context:
// Interactive, vertically scrollable user guide providing 14 expandable/collapsible
// accordion sections detailing setup, trip safety, emergency actions, contacts,
// location privacy, and safety reminders.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';

/// Screen presenting 14 expandable guide sections and a sticky confirmation CTA button.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  // Accordion state: track which index is currently expanded. null = all collapsed.
  int? _expandedIndex;

  void _handleToggle(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  // Semantic Design System Palette Tokens
  static const _greenAccent = AppColors.successText; // #047857
  static const _greenBg = AppColors.successContainer; // #DDF7ED

  static const _amberBg = Color(0xFFFEF3C7); // Amber 100

  static const _redAccent = AppColors.primary; // #DB2B38
  static const _redBg = AppColors.primaryContainer; // #FFDAD8

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Iconify(
            AppIcons.arrowBack,
            color: AppColors.header,
            size: 24,
          ),
        ),
        title: Text(
          'User Guide & Safety Protocol',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.header,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const _HeaderIntroBanner(),
                  const _ColorLegend(),
                  const SizedBox(height: 8),

                  // 1. Getting Started (GREEN - CAT 1)
                  _GuideSectionCard(
                    index: 0,
                    isExpanded: _expandedIndex == 0,
                    onToggle: () => _handleToggle(0),
                    iconStr: AppIcons.checkCircle,
                    title: '1. Getting Started',
                    accentColor: _greenAccent,
                    backgroundColor: const Color(0xFFE8F5E9),
                    iconBgColor: _greenBg,
                    child: const _GettingStartedContent(),
                  ),
                  const SizedBox(height: 12),

                  // 2. Start a Trip (RED - CAT 4)
                  _GuideSectionCard(
                    index: 1,
                    isExpanded: _expandedIndex == 1,
                    onToggle: () => _handleToggle(1),
                    iconStr: AppIcons.navigation,
                    title: '2. Start a Trip',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _StartTripContent(),
                  ),
                  const SizedBox(height: 12),

                  // 3. During Your Trip (RED - CAT 4)
                  _GuideSectionCard(
                    index: 2,
                    isExpanded: _expandedIndex == 2,
                    onToggle: () => _handleToggle(2),
                    iconStr: AppIcons.schedule,
                    title: '3. During Your Trip',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _DuringTripContent(),
                  ),
                  const SizedBox(height: 12),

                  // 4. Destination Reached (RED - CAT 4)
                  _GuideSectionCard(
                    index: 3,
                    isExpanded: _expandedIndex == 3,
                    onToggle: () => _handleToggle(3),
                    iconStr: AppIcons.checkCircle,
                    title: '4. Destination Reached',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _DestinationReachedContent(),
                  ),
                  const SizedBox(height: 12),

                  // 5. If You Don't Respond (RED - CAT 4)
                  _GuideSectionCard(
                    index: 4,
                    isExpanded: _expandedIndex == 4,
                    onToggle: () => _handleToggle(4),
                    iconStr: AppIcons.warning,
                    title: "5. If You Don't Respond",
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _NoResponseContent(),
                  ),
                  const SizedBox(height: 12),

                  // 6. Emergency SOS (RED - CAT 4)
                  _GuideSectionCard(
                    index: 5,
                    isExpanded: _expandedIndex == 5,
                    onToggle: () => _handleToggle(5),
                    iconStr: AppIcons.warning,
                    title: '6. Emergency SOS',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _EmergencySosContent(),
                  ),
                  const SizedBox(height: 12),

                  // 7. SOS Distress Widget (RED - CAT 4)
                  _GuideSectionCard(
                    index: 6,
                    isExpanded: _expandedIndex == 6,
                    onToggle: () => _handleToggle(6),
                    iconStr: AppIcons.warning,
                    title: '7. SOS Distress Widget',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _SosWidgetContent(),
                  ),
                  const SizedBox(height: 12),

                  // 8. Need Help (RED - CAT 4)
                  _GuideSectionCard(
                    index: 7,
                    isExpanded: _expandedIndex == 7,
                    onToggle: () => _handleToggle(7),
                    iconStr: AppIcons.infoOutline,
                    title: '8. Need Help',
                    accentColor: _redAccent,
                    backgroundColor: const Color(0xFFFFEBEE),
                    iconBgColor: _redBg,
                    child: const _NeedHelpContent(),
                  ),
                  const SizedBox(height: 12),

                  // 9. Trusted Contacts (GREEN - CAT 1)
                  _GuideSectionCard(
                    index: 8,
                    isExpanded: _expandedIndex == 8,
                    onToggle: () => _handleToggle(8),
                    iconStr: AppIcons.people,
                    title: '9. Trusted Contacts',
                    accentColor: _greenAccent,
                    backgroundColor: const Color(0xFFE8F5E9),
                    iconBgColor: _greenBg,
                    child: const _TrustedContactsContent(),
                  ),
                  const SizedBox(height: 12),

                  // 10. Set Your Home Location (YELLOW - CAT 2)
                  _GuideSectionCard(
                    index: 9,
                    isExpanded: _expandedIndex == 9,
                    onToggle: () => _handleToggle(9),
                    iconStr: AppIcons.home,
                    title: '10. Set Your Home Location',
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    iconBgColor: _amberBg,
                    child: const _HomeLocationContent(),
                  ),
                  const SizedBox(height: 12),

                  // 11. Emergency SMS & Location (YELLOW - CAT 2)
                  _GuideSectionCard(
                    index: 10,
                    isExpanded: _expandedIndex == 10,
                    onToggle: () => _handleToggle(10),
                    iconStr: AppIcons.chat,
                    title: '11. Emergency SMS & Location',
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    iconBgColor: _amberBg,
                    child: const _SmsLocationContent(),
                  ),
                  const SizedBox(height: 12),

                  // 12. Notifications (ORANGE - CAT 3)
                  _GuideSectionCard(
                    index: 11,
                    isExpanded: _expandedIndex == 11,
                    onToggle: () => _handleToggle(11),
                    iconStr: AppIcons.notifications,
                    title: '12. Notifications',
                    accentColor: const Color(0xFFFF9800),
                    backgroundColor: const Color(0xFFFFF3E0),
                    iconBgColor: _amberBg,
                    child: const _NotificationsContent(),
                  ),
                  const SizedBox(height: 12),

                  // 13. Privacy & Non-Surveillance (GREEN - CAT 1)
                  _GuideSectionCard(
                    index: 12,
                    isExpanded: _expandedIndex == 12,
                    onToggle: () => _handleToggle(12),
                    iconStr: AppIcons.shield,
                    title: '13. Privacy & Non-Surveillance',
                    accentColor: _greenAccent,
                    backgroundColor: const Color(0xFFE8F5E9),
                    iconBgColor: _greenBg,
                    child: const _PrivacyContent(),
                  ),
                  const SizedBox(height: 12),

                  // 14. Safety Reminders (GREEN - CAT 1)
                  _GuideSectionCard(
                    index: 13,
                    isExpanded: _expandedIndex == 13,
                    onToggle: () => _handleToggle(13),
                    iconStr: AppIcons.check,
                    title: '14. Safety Reminders',
                    accentColor: _greenAccent,
                    backgroundColor: const Color(0xFFE8F5E9),
                    iconBgColor: _greenBg,
                    child: const _SafetyRemindersContent(),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Persistent Bottom Sticky CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.header,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It, I Understand',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
}

/// Header introduction card summarizing the purpose of the guide.
class _HeaderIntroBanner extends StatelessWidget {
  const _HeaderIntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Iconify(AppIcons.book, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LisKo Safety Companion',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your essential guide to setting up, traveling, and using safety alerts effectively.',
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.header.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small color-code legend for visual categorization.
class _ColorLegend extends StatelessWidget {
  const _ColorLegend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Color(0xFF2E7D32), label: 'Safety & Setup'),
              SizedBox(width: 12),
              _Separator(),
              SizedBox(width: 12),
              _LegendItem(color: Color(0xFFD97706), label: 'Active Tracking'),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Color(0xFFFF9800), label: 'Proactive Alert'),
              SizedBox(width: 12),
              _Separator(),
              SizedBox(width: 12),
              _LegendItem(color: Color(0xFFD32F2F), label: 'Emergency'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.body,
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '|',
      style: TextStyle(
        color: AppColors.border,
        fontSize: 11,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

/// Expandable accordion card holding a section's title, icon, and custom child.
class _GuideSectionCard extends StatelessWidget {
  const _GuideSectionCard({
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.iconStr,
    required this.title,
    required this.child,
    this.accentColor,
    this.backgroundColor = Colors.white,
    this.iconBgColor,
  });

  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String iconStr;
  final String title;
  final Widget child;
  final Color? accentColor;
  final Color backgroundColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    final themeColor = accentColor ?? AppColors.header;
    final bgContainerColor =
        iconBgColor ?? (accentColor ?? AppColors.body).withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? themeColor.withValues(alpha: 0.4)
              : AppColors.border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              color: backgroundColor,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bgContainerColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Iconify(iconStr, color: themeColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.header,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? themeColor : AppColors.body,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: themeColor.withValues(alpha: 0.1),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// Section 1: Getting Started
// ==============================================================================
class _GettingStartedContent extends StatelessWidget {
  const _GettingStartedContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before using LisKo, make sure your basic safety setup is ready.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem('Add at least one trusted contact.'),
        const _BulletItem(
          'Allow SMS permission so LisKo can send emergency messages.',
        ),
        const _BulletItem(
          'Allow location permission when required for trip and emergency location features.',
        ),
        const _BulletItem(
          'Enable notifications so you can receive travel and safety alerts.',
        ),
        const _BulletItem(
          'Set your Home Location while you are physically at home.',
        ),
        const SizedBox(height: 12),
        _InfoNoteBox(
          text:
              'Your trusted contacts are the people LisKo can notify when you need help or when an emergency alert is triggered.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 2: Start a Trip
// ==============================================================================
class _StartTripContent extends StatelessWidget {
  const _StartTripContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set up your trip before you begin traveling.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 10),
        const _StepItem(number: 1, text: 'Tap Set Trip on the Home screen.'),
        const _StepItem(number: 2, text: 'Choose your destination.'),
        const _StepItem(number: 3, text: 'Set your estimated travel time.'),
        const _StepItem(number: 4, text: 'Review your trip details.'),
        const _StepItem(number: 5, text: 'Tap Start Trip to begin.'),
        const SizedBox(height: 12),
        const _InfoNoteBox(
          text: 'The timer starts only after you tap Start Trip.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 3: During Your Trip
// ==============================================================================
class _DuringTripContent extends StatelessWidget {
  const _DuringTripContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LisKo helps you keep track of your expected arrival time while you travel.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem('Your trip timer counts down after the trip starts.'),
        const _BulletItem(
          'LisKo can detect when you reach your selected destination.',
        ),
        const _BulletItem(
          'LisKo is designed as a travel safety companion, not a continuous tracking system.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 4: Destination Reached
// ==============================================================================
class _DestinationReachedContent extends StatelessWidget {
  const _DestinationReachedContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When LisKo detects that you have reached your destination, it asks you to confirm your safety.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 12),

        // Action 1: I'm Safe
        _ActionRowBadge(
          title: "I'm Safe",
          badgeColor: AppColors.success,
          textColor: Colors.white,
          description:
              'Confirms that you arrived safely. A Safe Arrival SMS is sent to your primary trusted contact.',
        ),
        const SizedBox(height: 10),

        // Action 2: +15 min
        _ActionRowBadge(
          title: '+15 min',
          badgeColor: const Color(0xFFD97706),
          textColor: Colors.white,
          description:
              'Adds 15 minutes to your trip. This does not send an emergency alert.',
        ),
        const SizedBox(height: 10),

        // Action 3: Need Help
        _ActionRowBadge(
          title: 'Need Help',
          badgeColor: AppColors.primary,
          textColor: Colors.white,
          description:
              'Requests assistance and sends an emergency alert to your trusted contacts.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 5: If You Don't Respond
// ==============================================================================
class _NoResponseContent extends StatelessWidget {
  const _NoResponseContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'If you do not respond to the safety confirmation within 90 seconds, LisKo automatically sends an emergency alert to your trusted contacts.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem(
          'The emergency alert attempts to include your available emergency location information and GPS coordinates.',
        ),
        const _BulletItem(
          'LisKo may use vibration and notification alerts to get your attention during the safety confirmation.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 6: Emergency SOS
// ==============================================================================
class _EmergencySosContent extends StatelessWidget {
  const _EmergencySosContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use Emergency SOS when you need immediate assistance.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'When an emergency alert is triggered, LisKo attempts to obtain your current location and sends an emergency SMS to your trusted contacts.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'The alert may contain:',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 6),
        const _BulletItem('Emergency status'),
        const _BulletItem('GPS coordinates'),
        const _BulletItem('Google Maps location link'),
        const _BulletItem('Time of the alert'),
      ],
    );
  }
}

// ==============================================================================
// Section 7: SOS Distress Widget
// ==============================================================================
class _SosWidgetContent extends StatelessWidget {
  const _SosWidgetContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "The Home Screen SOS Widget gives you a quick way to start LisKo's emergency SOS flow directly from your phone's Home Screen.",
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem(
          'To add it from LisKo, go to Settings and open Home Screen SOS Widget, then select Add to Home Screen.',
        ),
        const _BulletItem(
          'You may also add it manually from your Android Home Screen\'s Widgets menu, depending on your device launcher.',
        ),
        const _BulletItem(
          'Tapping the widget starts the 5-second SOS countdown.',
        ),
        const _BulletItem(
          'You can cancel during the countdown if the widget was tapped accidentally.',
        ),
        const _BulletItem(
          'If the countdown completes, LisKo sends an emergency SMS to your trusted contacts and attempts to include your available emergency location.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 8: Need Help
// ==============================================================================
class _NeedHelpContent extends StatelessWidget {
  const _NeedHelpContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use Need Help when you have reached your destination but do not feel safe or need assistance.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'LisKo sends an emergency alert to your trusted contacts and attempts to include your current emergency location.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 9: Trusted Contacts
// ==============================================================================
class _TrustedContactsContent extends StatelessWidget {
  const _TrustedContactsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trusted contacts are the people who can receive safety and emergency SMS messages from LisKo.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem('You can have 1 to 5 trusted contacts.'),
        const _BulletItem(
          'The first contact is the primary emergency contact.',
        ),
        const _BulletItem(
          'The primary contact receives Safe Arrival SMS messages.',
        ),
        const _BulletItem('Emergency alerts are sent to all trusted contacts.'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relationship categories:',
                textAlign: TextAlign.justify,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _RelationshipChip('Parent'),
                  const SizedBox(width: 8),
                  _RelationshipChip('Guardian'),
                  const SizedBox(width: 8),
                  _RelationshipChip('Others'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Contact Privacy & Security',
          textAlign: TextAlign.start,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'You can protect your trusted contacts from unauthorized viewing or changes by enabling Protect Trusted Contacts in Settings. When enabled, LisKo uses your device authentication, such as your PIN, pattern, fingerprint, or other supported device security.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        _InfoNoteBox(
          text:
              'Protecting the Contacts tab does not disable LisKo\'s emergency SMS functions. Emergency alerts can still use your saved trusted contacts when an SOS or automatic escalation occurs.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 10: Set Your Home Location
// ==============================================================================
class _HomeLocationContent extends StatelessWidget {
  const _HomeLocationContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your Home Location while you are physically at home.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'LisKo uses your saved Home Location to recognize when you reach home during a trip.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const _InfoNoteBox(
          text:
              'For more accurate home arrival detection, set your Home Location while you are at home.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 11: Emergency SMS & Location
// ==============================================================================
class _SmsLocationContent extends StatelessWidget {
  const _SmsLocationContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LisKo uses your phone's cellular SMS capability to send emergency messages to your trusted contacts.",
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const _BulletItem(
          'Emergency location is requested when an emergency alert is triggered.',
        ),
        const _BulletItem(
          'If a current GPS location cannot be obtained, LisKo may use available recent location information or indicate that the location is unavailable.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFD97706),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMS delivery depends on your SIM card, cellular service, phone settings, and network conditions.',
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 12: Notifications
// ==============================================================================
class _NotificationsContent extends StatelessWidget {
  const _NotificationsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep LisKo notifications enabled so you can receive travel and safety alerts even while using another app.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Notification behavior may also depend on your phone's notification settings and battery/background restrictions.",
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 13: Privacy & Non-Surveillance
// ==============================================================================
class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LisKo is designed as a travel safety companion, not a continuous tracking system.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.header,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Location information is used when needed for trip safety features, such as destination detection and emergency assistance.',
          textAlign: TextAlign.justify,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ==============================================================================
// Section 14: Safety Reminders
// ==============================================================================
class _SafetyRemindersContent extends StatelessWidget {
  const _SafetyRemindersContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ChecklistBullet('Keep your phone charged when traveling.'),
        const _ChecklistBullet('Make sure your SIM card can send SMS.'),
        const _ChecklistBullet('Keep LisKo notifications enabled.'),
        const _ChecklistBullet('Keep your trusted contacts updated.'),
        const _ChecklistBullet(
          'Allow required permissions when using trip and emergency features.',
        ),
        const _ChecklistBullet(
          "Make sure your phone's Location Services are available when needed.",
        ),
        const _ChecklistBullet(
          'In a real emergency, contact the appropriate emergency service when possible.',
        ),
        const SizedBox(height: 12),
        _InfoNoteBox(
          text:
              'LisKo is a safety support tool and should not replace emergency services.',
        ),
      ],
    );
  }
}

// ==============================================================================
// Small Reusable Helper Widgets
// ==============================================================================

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.header,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistBullet extends StatelessWidget {
  const _ChecklistBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.header,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.header,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.header,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRowBadge extends StatelessWidget {
  const _ActionRowBadge({
    required this.title,
    required this.badgeColor,
    required this.textColor,
    required this.description,
  });

  final String title;
  final Color badgeColor;
  final Color textColor;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.justify,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  const _RelationshipChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.header,
        ),
      ),
    );
  }
}

class _InfoNoteBox extends StatelessWidget {
  const _InfoNoteBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.body,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
