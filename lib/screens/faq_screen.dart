// ==============================================================================
// Lisko Mobile Safety Application - Frequently Asked Questions Screen
// File: lib/screens/faq_screen.dart
//
// Role & Architectural Context:
// Interactive, 100% offline-first help screen providing quick, categorized,
// expandable answers to common commuter questions regarding trips, emergency
// alerts, trusted contacts, GPS acquisition, permissions, battery settings, and privacy.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';

/// Read-only offline FAQ screen organized into expandable categories.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  // Accordion state: track which question index is currently expanded.
  int? _expandedIndex;

  void _handleToggle(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

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
          'Frequently Asked Questions',
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
                  const _FaqHeaderBanner(),
                  const _ColorLegend(),
                  const SizedBox(height: 8),

                  // Category 1: Trips & Commute Monitoring
                  const _CategoryHeader(
                    title: 'TRIPS & COMMUTE MONITORING',
                    iconStr: AppIcons.navigation,
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 0,
                    onToggle: () => _handleToggle(0),
                    question: 'How do I start a trip in LisKo?',
                    answer:
                        'Tap Set Up Trip on the Home tab. Select your destination (PUP Santa Maria Campus or Home) and estimated travel duration, then tap SAVE TRIP. Back on the Home tab, tap Start Trip to launch active travel countdown monitoring.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 1,
                    onToggle: () => _handleToggle(1),
                    question:
                        'What happens when LisKo detects I have reached my destination?',
                    answer:
                        'When your phone enters your destination\'s geofence boundary, LisKo displays the Destination Reached screen. You can select I\'m Safe to complete the trip or Need Help if you require emergency assistance. You have 90 seconds to respond before automatic escalation triggers.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 2,
                    onToggle: () => _handleToggle(2),
                    question:
                        'What does +15 min do on the Travel Time Ended screen?',
                    answer:
                        'When your travel countdown timer reaches zero before reaching your destination geofence, LisKo displays the Travel Time Ended screen. Tapping +15 min extends your active trip duration by 15 minutes and resumes monitoring. It does not send an emergency alert.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 3,
                    onToggle: () => _handleToggle(3),
                    question:
                        'What happens if I close or minimize LisKo during a trip?',
                    answer:
                        'LisKo continues travel countdown monitoring in the background via a persistent Android status-bar notification ("LisKo Commute Active"). You will receive a high-priority Heads-Up safety check prompt when you reach your destination or if your trip timer expires.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 20),

                  // Category 2: Emergency & Safety Alerts
                  const _CategoryHeader(
                    title: 'EMERGENCY & SAFETY ALERTS',
                    iconStr: AppIcons.warning,
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 4,
                    onToggle: () => _handleToggle(4),
                    question:
                        'What happens if I don\'t respond to the 90-second safety check?',
                    answer:
                        'If 90 seconds pass without selecting I\'m Safe (on Destination Reached) or +15 min (on Travel Time Ended), LisKo automatically triggers an emergency escalation and sends an emergency SMS alert with your location to all your trusted contacts.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 5,
                    onToggle: () => _handleToggle(5),
                    question: 'How does Manual Emergency SOS work?',
                    answer:
                        'Tapping SEND DISTRESS SIGNAL on the Home tab (or tapping the Home Screen SOS Widget) opens the Manual SOS screen with a 5-second cancellation countdown. You can tap Cancel before 5 seconds elapse. If uncancelled, emergency SMS alerts with your location are sent to all trusted contacts. Manual SOS works anytime, even without an active trip.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 6,
                    onToggle: () => _handleToggle(6),
                    question: 'How do I add the Home Screen SOS Widget?',
                    answer:
                        'Go to Settings → Alarm & Safety Protocol → Home Screen SOS Widget, tap Add to Home Screen, and confirm. Alternatively, touch and hold an empty space on your phone\'s Home screen → tap Widgets → drag LisKo SOS Widget to your Home screen.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 7,
                    onToggle: () => _handleToggle(7),
                    question: 'Who receives my "I\'m Safe" confirmation?',
                    answer:
                        'When you tap I\'m Safe, a Safe Arrival confirmation SMS is sent exclusively to your Primary Emergency Contact (the first contact in your directory). Secondary contacts do not receive routine safe-arrival texts.',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 8,
                    onToggle: () => _handleToggle(8),
                    question: 'Who receives my emergency alerts?',
                    answer:
                        'Emergency alerts (triggered by Emergency SOS, Need Help, or the 90-second no-response timeout) are sent via cellular SMS to ALL your configured trusted contacts (Primary + all Secondary contacts).',
                    backgroundColor: const Color(0xFFFFEBEE),
                    accentColor: AppColors.primary,
                  ),
                  const SizedBox(height: 20),

                  // Category 3: Trusted Contacts
                  const _CategoryHeader(
                    title: 'TRUSTED CONTACTS',
                    iconStr: AppIcons.people,
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 9,
                    onToggle: () => _handleToggle(9),
                    question: 'How many trusted contacts can I add?',
                    answer:
                        'You can add between 1 and 5 trusted contacts manually or import them from your phonebook. At least one contact is required to enable LisKo\'s safety features.',
                    backgroundColor: const Color(0xFFE8F5E9),
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 10,
                    onToggle: () => _handleToggle(10),
                    question: 'What is the Primary Contact?',
                    answer:
                        'The first contact in your directory (Index 1) is designated as your Primary Emergency Contact. They receive your routine Safe Arrival SMS confirmations in addition to emergency alerts.',
                    backgroundColor: const Color(0xFFE8F5E9),
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 11,
                    onToggle: () => _handleToggle(11),
                    question:
                        'What relationship categories can I select for my contacts?',
                    answer:
                        'You can categorize each contact as Parent, Guardian, or Others.',
                    backgroundColor: const Color(0xFFE8F5E9),
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 20),

                  // Category 4: Location, Battery & System Settings
                  const _CategoryHeader(
                    title: 'LOCATION & BATTERY SETTINGS',
                    iconStr: AppIcons.location,
                    accentColor: Color(0xFFD97706),
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 12,
                    onToggle: () => _handleToggle(12),
                    question: 'How do I set my Home Location?',
                    answer:
                        'Go to Settings → Commute Presets → Home Location Pin. Tap Use Current GPS Location while physically at home (or enter coordinates manually) and tap Save Coordinates.',
                    backgroundColor: const Color(0xFFFFFDE7),
                    accentColor: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 13,
                    onToggle: () => _handleToggle(13),
                    question:
                        'How do I ensure LisKo runs reliably in the background?',
                    answer:
                        'Some Android phones aggressively optimize battery usage. To ensure uninterrupted trip monitoring, go to Phone Settings → Battery → High Background Power Consumption (or Battery Optimization / Background App Refresh) → select LisKo → set to Allow / No Restrictions.',
                    backgroundColor: const Color(0xFFFFFDE7),
                    accentColor: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 14,
                    onToggle: () => _handleToggle(14),
                    question:
                        'Does GPS location acquisition work offline without internet?',
                    answer:
                        'Yes. GPS (GNSS) satellites operate independently of Wi-Fi or mobile data. If a satellite lock takes longer offline, LisKo uses location fallbacks (such as your last known position) so emergency alerts are never delayed.',
                    backgroundColor: const Color(0xFFFFFDE7),
                    accentColor: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 20),

                  // Category 5: Permissions & SMS Requirements
                  const _CategoryHeader(
                    title: 'PERMISSIONS & SMS REQUIREMENTS',
                    iconStr: AppIcons.notifications,
                    accentColor: Color(0xFFFF9800),
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 15,
                    onToggle: () => _handleToggle(15),
                    question:
                        'Why does LisKo require SMS and Location permissions?',
                    answer:
                        'SMS permission allows LisKo to send emergency text messages directly through your phone\'s cellular SIM card when mobile internet is unavailable. Location permission is required to detect destination arrival and attach your position to emergency alerts.',
                    backgroundColor: const Color(0xFFFFF3E0),
                    accentColor: const Color(0xFFFF9800),
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 16,
                    onToggle: () => _handleToggle(16),
                    question:
                        'Is mobile internet data required to send SMS alerts?',
                    answer:
                        'No. Emergency SMS alerts are transmitted through your device\'s SIM card and cellular network without requiring mobile data. However, active cellular SIM coverage, SMS load/allowance, and required system permissions are necessary.',
                    backgroundColor: const Color(0xFFFFF3E0),
                    accentColor: const Color(0xFFFF9800),
                  ),
                  const SizedBox(height: 20),

                  // Category 6: Privacy & Data Deletion
                  const _CategoryHeader(
                    title: 'PRIVACY & DATA DELETION',
                    iconStr: AppIcons.shield,
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 17,
                    onToggle: () => _handleToggle(17),
                    question: 'Does LisKo continuously track my location?',
                    answer:
                        'No. LisKo is designed for trip-based safety monitoring. Location monitoring is active ONLY during student-initiated trips or when emergency features (such as Manual SOS) are triggered. LisKo has no 24/7 continuous tracking or public live dashboard.',
                    backgroundColor: const Color(0xFFE8F5E9),
                    accentColor: AppColors.successText,
                  ),
                  const SizedBox(height: 8),
                  _FaqAccordionCard(
                    isExpanded: _expandedIndex == 18,
                    onToggle: () => _handleToggle(18),
                    question: 'How do I request deletion of my cloud data?',
                    answer:
                        'Go to Settings → Request Data Deletion → tap Verify My Deletion Request to generate a 24-hour Reference ID, then tap Send Email Request to email liskoapp.team@gmail.com. Maintainers verify and process deletion requests manually through the Firebase Console.',
                    backgroundColor: const Color(0xFFE8F5E9),
                    accentColor: AppColors.successText,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Persistent Bottom Action Button
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
                    'Got It, Thanks!',
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

/// Header banner for FAQ screen.
class _FaqHeaderBanner extends StatelessWidget {
  const _FaqHeaderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.body, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.header,
              shape: BoxShape.circle,
            ),
            child: const Iconify(
              AppIcons.infoOutline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Help & Answers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find quick answers to common questions about LisKo commute safety features.',
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
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

/// Category header row in FAQ list.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.iconStr,
    this.accentColor,
  });

  final String title;
  final String iconStr;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.header;
    return Row(
      children: [
        Iconify(iconStr, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Expandable accordion card holding an FAQ question and answer.
class _FaqAccordionCard extends StatelessWidget {
  const _FaqAccordionCard({
    required this.isExpanded,
    required this.onToggle,
    required this.question,
    required this.answer,
    this.backgroundColor = Colors.white,
    this.accentColor = AppColors.header,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final String question;
  final String answer;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? accentColor.withValues(alpha: 0.4)
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
        borderRadius: BorderRadius.circular(14),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.header,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? accentColor : AppColors.body,
                        size: 22,
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
                color: accentColor.withValues(alpha: 0.1),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Text(
                  answer,
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
