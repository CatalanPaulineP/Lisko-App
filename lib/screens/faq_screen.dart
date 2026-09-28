// ==============================================================================
// Lisko Mobile Safety Application - Frequently Asked Questions Screen
// File: lib/screens/faq_screen.dart
//
// Role & Architectural Context:
// Interactive, 100% offline-first help screen providing quick, categorized,
// expandable answers to common commuter questions regarding trips, emergency
// alerts, trusted contacts, GPS acquisition, permissions, and privacy.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';

/// Read-only offline FAQ screen organized into 6 expandable categories.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

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
                children: const [
                  _FaqHeaderBanner(),
                  SizedBox(height: 16),

                  // Category 1: Trips
                  _CategoryHeader(title: 'TRIPS & NAVIGATION', iconStr: AppIcons.navigation),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'How do I start a trip in LisKo?',
                    answer: 'Tap Set Trip on the Home screen, choose your destination (PUP Santa Maria Campus or Home) and estimated travel duration, then tap Start Trip. The commute countdown timer begins immediately.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What happens when LisKo detects I have reached my destination?',
                    answer: "When your phone enters your destination's 150-meter geofence perimeter, LisKo displays the Destination Reached screen and asks you to confirm your safety within 90 seconds.",
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What does +15 min do on the Destination Reached screen?',
                    answer: 'Tapping +15 min extends your active trip duration by 15 minutes if you are delayed. It does not send an emergency alert or notify your contacts.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What happens if I close or minimize LisKo during a trip?',
                    answer: 'LisKo continues running its travel countdown timer and destination arrival monitoring in the background via an active Android foreground service. You will receive a Heads-Up Notification when you reach your destination or if your trip timer expires.',
                  ),
                  SizedBox(height: 20),

                  // Category 2: Emergency & Safety
                  _CategoryHeader(title: 'EMERGENCY & SAFETY ALERTS', iconStr: AppIcons.warning, accentColor: AppColors.primary),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: "What happens if I don't respond to the 90-second safety check?",
                    answer: "If 90 seconds pass without selecting I'm Safe or +15 min, LisKo automatically triggers an emergency escalation and sends an emergency SMS alert with your location to all your trusted contacts.",
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: "Who receives my \"I'm Safe\" confirmation?",
                    answer: "When you tap I'm Safe, a Safe Arrival confirmation SMS is sent exclusively to your Primary Trusted Contact (the first contact in your directory). Secondary contacts do not receive normal safe arrival messages.",
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'Who receives my emergency alerts?',
                    answer: 'Emergency alerts (triggered by Emergency SOS, Need Help, or the 90-second no-response timeout) are sent via cellular SMS to ALL your configured trusted contacts (Primary + all Secondary contacts).',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What is the difference between Emergency SOS and Need Help?',
                    answer: 'Emergency SOS is used for immediate emergencies during travel. Need Help is used when you reach your destination but do not feel safe or require assistance. Both dispatch emergency SMS alerts with your location to all trusted contacts.',
                  ),
                  SizedBox(height: 20),

                  // Category 3: Trusted Contacts
                  _CategoryHeader(title: 'TRUSTED CONTACTS', iconStr: AppIcons.people),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'How many trusted contacts can I add?',
                    answer: 'You can add between 1 and 5 trusted contacts. At least one contact is required to enable LisKo\'s safety features.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What is the Primary Contact?',
                    answer: 'The first contact in your trusted directory (Index 1) is automatically designated as your Primary Emergency Contact. They receive your routine Safe Arrival SMS confirmations in addition to emergency alerts.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'What relationship categories can I select for my contacts?',
                    answer: 'You can categorize each contact as Parent, Guardian, or Others.',
                  ),
                  SizedBox(height: 20),

                  // Category 4: Location & GPS
                  _CategoryHeader(title: 'LOCATION & GPS', iconStr: AppIcons.location),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'How do I set my Home Location?',
                    answer: 'Go to Settings → Commute Presets → Home Location Pin. Tap Use Current GPS Location while physically at home (or enter coordinates manually) and tap Save Coordinates.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'Does GPS location acquisition work offline without internet?',
                    answer: 'Yes. GPS (GNSS) satellites operate independently of Wi-Fi or mobile data. If a fresh satellite lock takes longer offline, LisKo uses multi-tier location fallbacks (such as your last known position) so an emergency alert is never delayed.',
                  ),
                  SizedBox(height: 20),

                  // Category 5: Notifications & Permissions
                  _CategoryHeader(title: 'NOTIFICATIONS & PERMISSIONS', iconStr: AppIcons.notifications),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'Why does LisKo require SMS and Location permissions?',
                    answer: 'SMS permission allows LisKo to send emergency text messages directly through your phone\'s SIM card during offline emergencies. Location permission is required to detect destination arrival and attach your position to emergency alerts.',
                  ),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'Why should notifications remain enabled?',
                    answer: 'Notifications allow LisKo to display high-priority Heads-Up safety prompts and action buttons ("I\'m Safe", "+15 min", "Need Help") even when the app is backgrounded or your phone screen is off.',
                  ),
                  SizedBox(height: 20),

                  // Category 6: Privacy
                  _CategoryHeader(title: 'PRIVACY & NON-SURVEILLANCE', iconStr: AppIcons.shield),
                  SizedBox(height: 8),
                  _FaqAccordionCard(
                    question: 'Does LisKo continuously track my location?',
                    answer: 'No. LisKo uses a Zero-Surveillance Architecture. Location tracking is active ONLY during an active commute trip or an emergency alert. GPS shuts down immediately when your trip ends or when you confirm "I\'m Safe."',
                  ),
                  SizedBox(height: 16),
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
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
class _FaqAccordionCard extends StatefulWidget {
  const _FaqAccordionCard({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  State<_FaqAccordionCard> createState() => _FaqAccordionCardState();
}

class _FaqAccordionCardState extends State<_FaqAccordionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded ? AppColors.header.withValues(alpha: 0.3) : AppColors.border,
          width: _isExpanded ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
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
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.body,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.answer,
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
    );
  }
}
