// ==============================================================================
// Lisko Mobile Safety Application - Legal & Privacy Modals
// File: lib/widgets/legal_modals.dart
//
// Role & Architectural Context:
// Shared modal bottom sheet dialogs for Privacy Policy, GPS Usage Rules, and Terms of Use.
// Reused across WelcomeScreen, SettingsTab, and onboarding flows to maintain a single
// authoritative source of truth for legal and data protection disclosures.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class ExpandablePrivacyCard extends StatelessWidget {
  const ExpandablePrivacyCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isExpanded,
    required this.onExpansionChanged,
    this.accentColor,
    this.backgroundColor = AppColors.canvas,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Color? accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final themeColor = accentColor ?? AppColors.header;
    final bgContainerColor = (accentColor ?? AppColors.primary).withValues(
      alpha: 0.1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            InkWell(
              onTap: () => onExpansionChanged(!isExpanded),
              child: Container(
                color: backgroundColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: bgContainerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: themeColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.header,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: isExpanded ? themeColor : AppColors.body,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: themeColor.withValues(alpha: 0.1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Text(
                  description,
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                    height: 1.5,
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

/// Modal bottom sheet presenting LisKo's Privacy Policy and GPS Usage Rules.
class PrivacyPolicyModalBottomSheet extends StatefulWidget {
  const PrivacyPolicyModalBottomSheet({super.key});

  @override
  State<PrivacyPolicyModalBottomSheet> createState() =>
      _PrivacyPolicyModalBottomSheetState();
}

class _PrivacyPolicyModalBottomSheetState
    extends State<PrivacyPolicyModalBottomSheet> {
  int? _expandedIndex;

  void _handleExpansion(int index, bool expanded) {
    setState(() {
      _expandedIndex = expanded ? index : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy & GPS Usage',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.header,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'How LisKo protects student privacy and handles location data',
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.body,
                    ),
                  ),
                ],
              ),
            ),
            const _ColorLegend(),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  // SECTION 1: PRIVACY POLICY
                  Text(
                    'PRIVACY POLICY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.body,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 0,
                    onExpansionChanged: (exp) => _handleExpansion(0, exp),
                    title: 'Information LisKo Uses',
                    icon: Icons.folder_shared_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'LisKo uses information necessary for travel safety monitoring:\n'
                        '• Firebase Anonymous Account: Automatically assigned upon first launch without requiring student name, email, or password registration.\n'
                        '• Trusted Contacts & Settings: Contact names, phone numbers, home location coordinates, and commute duration presets are stored locally on your device using SharedPreferences.\n'
                        '• Local Trip History: Saved on your phone and automatically pruned after 30 days when reading trip history.\n'
                        '• Cloud Safety Records: Trip monitoring status, emergency event logs, and time-limited verification reference IDs are stored securely in Cloud Firestore.\n'
                        '• Location Coordinates: Obtained during geofence arrival checks, Manual SOS, or unanswered safety check timeouts, and processed locally or via Android system geocoding.\n'
                        '• Device Identifiers: Local Installation ID (installationId) and Anonymous Auth UID isolate your cloud records without personal accounts.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 1,
                    onExpansionChanged: (exp) => _handleExpansion(1, exp),
                    title: 'Why Information Is Used',
                    icon: Icons.center_focus_strong_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'LisKo uses this information solely to:\n'
                        '• Manage active commute timers and detect destination geofence arrival.\n'
                        '• Automatically send Safe-Arrival SMS notifications to your Primary Emergency Contact when you tap "I\'m Safe".\n'
                        '• Automatically dispatch emergency SMS alerts with GPS location coordinates to trusted contacts during Manual SOS or unanswered safety check timeouts.\n'
                        '• Verify authenticated user data deletion requests.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 2,
                    onExpansionChanged: (exp) => _handleExpansion(2, exp),
                    title: 'SMS & Communication Privacy',
                    icon: Icons.sms_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        '• Emergency and safe-arrival SMS messages are transmitted directly via your phone\'s cellular SIM network.\n'
                        '• SIM SMS relies on mobile carrier coverage. GPS location accuracy depends on satellite visibility and hardware state.\n'
                        '• LisKo does not read, access, or receive SMS messages from your inbox (READ_SMS and RECEIVE_SMS permissions are not used).\n'
                        '• Messages already sent to contacts are stored on recipient phones outside LisKo\'s control.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 3,
                    onExpansionChanged: (exp) => _handleExpansion(3, exp),
                    title: 'Who Receives Your Information',
                    icon: Icons.people_outline_rounded,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        '• Normal Safe Arrival: Confirming "I\'m Safe" sends an SMS only to your Primary Emergency Contact without GPS coordinates.\n'
                        '• Emergency Alerts: Triggering Manual SOS, tapping "Need Help", or failing to respond to a safety timeout sends emergency alerts to all your trusted contacts.\n'
                        '• Cloud Encryption: Cloud Firestore communication uses encrypted HTTPS/TLS 1.3 channels. Cellular SMS uses standard mobile network signaling.\n'
                        '• No Live-Tracking Dashboard: LisKo does not broadcast your location to a public or admin web dashboard.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 4,
                    onExpansionChanged: (exp) => _handleExpansion(4, exp),
                    title: 'Storage & Data Deletion Requests',
                    icon: Icons.phonelink_setup_rounded,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        '• Local trip history is automatically pruned on your phone after 30 days during trip history cleanup.\n'
                        '• Production Cloud Firestore records are stored securely and are NOT automatically deleted after 30 days.\n'
                        '• To request cloud record deletion, go to Settings → Request Data Deletion → Verify My Deletion Request to generate a time-limited verification reference valid for up to 24 hours.\n'
                        '• Submitting a deletion request does not immediately delete cloud records. An authorized LisKo maintainer must first verify the request and manually process the applicable records through the Firebase Console.\n'
                        '• Email your Reference ID to liskoapp.team@gmail.com. Verification references expire after 24 hours but are not automatically removed upon expiration.\n'
                        '• Uninstalled App Notice: Reinstalling assigns a new Anonymous UID. If you uninstalled before generating a Reference ID, email liskoapp.team@gmail.com with general travel details (such as approximate travel dates or destination municipality) to help locate unlinked records. Additional verification may be required.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 5,
                    onExpansionChanged: (exp) => _handleExpansion(5, exp),
                    title: 'Privacy Commitment',
                    icon: Icons.verified_user_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'LisKo is designed for trip-based safety monitoring rather than continuous, round-the-clock surveillance. Location monitoring is activated during student-initiated trips and may continue in the background while a trip is active. Location may also be obtained when emergency features are triggered. LisKo does not provide a public or administrator live-tracking dashboard.',
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: GPS USAGE RULES
                  Text(
                    'GPS USAGE RULES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.body,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 6,
                    onExpansionChanged: (exp) => _handleExpansion(6, exp),
                    title: '1. When GPS / Location Is Used',
                    icon: Icons.location_on_outlined,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        'LisKo accesses location services during specific event-driven safety functions:\n'
                        '• Active Travel Monitoring: Monitoring trip progress and checking geofence boundary arrival during student-initiated commutes (including background operation).\n'
                        '• Emergency Alerts: Requesting your current location during Manual SOS, "Need Help", or an unanswered safety check timeout.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 7,
                    onExpansionChanged: (exp) => _handleExpansion(7, exp),
                    title: '2. When GPS Is NOT Used',
                    icon: Icons.location_off_outlined,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        '• LisKo is designed for trip-based safety monitoring rather than continuous, round-the-clock surveillance.\n'
                        '• LisKo does not provide 24/7 live-location tracking outside active trips.\n'
                        '• Confirming "I\'m Safe" on arrival does not attach GPS coordinates to the normal Safe Arrival SMS.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 8,
                    onExpansionChanged: (exp) => _handleExpansion(8, exp),
                    title: '3. Emergency Location Sharing',
                    icon: Icons.sos_rounded,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        '• During an emergency alert, LisKo attempts to obtain your current GPS coordinates.\n'
                        '• If a valid location fix is obtained, available location information such as readable location descriptions and GPS coordinates are included in the emergency SMS.\n'
                        '• If location services cannot obtain a current fix, the emergency alert is still sent without location coordinates.\n'
                        '• Emergency location is sent only to the trusted contacts involved in the alert.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 9,
                    onExpansionChanged: (exp) => _handleExpansion(9, exp),
                    title: '4. Permissions & User Control',
                    icon: Icons.admin_panel_settings_outlined,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        '• Android Location Permission is required for geofencing and emergency location features.\n'
                        '• You can enable or disable location permissions at any time through Android System Settings.\n'
                        '• Disabling location services or permissions may prevent geofencing auto-arrival and emergency location acquisition.',
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet presenting LisKo's Terms of Use and Safety Disclaimer.
class TermsOfUseModalBottomSheet extends StatefulWidget {
  const TermsOfUseModalBottomSheet({super.key});

  @override
  State<TermsOfUseModalBottomSheet> createState() =>
      _TermsOfUseModalBottomSheetState();
}

class _TermsOfUseModalBottomSheetState
    extends State<TermsOfUseModalBottomSheet> {
  int? _expandedIndex;

  void _handleExpansion(int index, bool expanded) {
    setState(() {
      _expandedIndex = expanded ? index : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Use & Safety Disclaimer',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.header,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Terms governing the use of LisKo safety and emergency features',
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.body,
                    ),
                  ),
                ],
              ),
            ),
            const _ColorLegend(),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  Text(
                    'TERMS OF USE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.body,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 0,
                    onExpansionChanged: (exp) => _handleExpansion(0, exp),
                    title: '1. Purpose of LisKo',
                    icon: Icons.info_outline_rounded,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'LisKo is a mobile student travel safety and emergency monitoring application designed to support Polytechnic University of the Philippines – Santa Maria Campus students during travel between home and campus.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 1,
                    onExpansionChanged: (exp) => _handleExpansion(1, exp),
                    title: '2. Supplementary Safety Tool',
                    icon: Icons.gavel_rounded,
                    accentColor: AppColors.primary,
                    backgroundColor: const Color(0xFFFFEBEE),
                    description:
                        '• LisKo is a supplementary safety tool intended to assist travel communication.\n'
                        '• LisKo is NOT a replacement for official emergency response services (such as police, ambulance, fire services, or 911).\n'
                        '• In an immediate or life-threatening emergency, users should contact official local emergency services directly whenever possible.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 2,
                    onExpansionChanged: (exp) => _handleExpansion(2, exp),
                    title: '3. Emergency SMS Limitations',
                    icon: Icons.signal_cellular_alt_rounded,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        '• Emergency SMS alert transmission relies on your cellular network SIM signal, active carrier subscription, device battery state, and system permissions.\n'
                        '• LisKo cannot guarantee successful SMS delivery under zero-signal conditions, carrier network outages, or hardware power loss.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 3,
                    onExpansionChanged: (exp) => _handleExpansion(3, exp),
                    title: '4. Location / GPS Limitations',
                    icon: Icons.my_location_rounded,
                    accentColor: const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFFFFDE7),
                    description:
                        '• Geofence boundary arrival detection and GPS location accuracy depend on device location hardware, satellite visibility, clear sky conditions, and Android location settings.\n'
                        '• LisKo cannot guarantee exact boundary detection under severe GPS drift, indoor signal attenuation, or device hardware limitations.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 4,
                    onExpansionChanged: (exp) => _handleExpansion(4, exp),
                    title: '5. Device & Power Management',
                    icon: Icons.battery_saver_rounded,
                    accentColor: const Color(0xFFFF9800),
                    backgroundColor: const Color(0xFFFFF3E0),
                    description:
                        '• Android OS or device manufacturer background power management settings may affect background execution if restricted by the user.\n'
                        '• Users should ensure background power settings allow LisKo to operate during active trips.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 5,
                    onExpansionChanged: (exp) => _handleExpansion(5, exp),
                    title: '6. User Responsibilities',
                    icon: Icons.assignment_ind_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'Users must:\n'
                        '• Maintain accurate, up-to-date phone numbers for trusted contacts.\n'
                        '• Select trusted contacts responsibly with their knowledge.\n'
                        '• Maintain required system permissions (Location, Notifications, SMS) during active trips.\n'
                        '• Maintain adequate phone battery charge during travel.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 6,
                    onExpansionChanged: (exp) => _handleExpansion(6, exp),
                    title: '7. Responsible Use & Misuse',
                    icon: Icons.block_rounded,
                    accentColor: AppColors.primary,
                    backgroundColor: const Color(0xFFFFEBEE),
                    description:
                        '• LisKo must be used strictly for genuine travel safety and emergency communication.\n'
                        '• Users shall not intentionally trigger false emergency alerts, misuse SOS features, or use the application to harass contacts.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 7,
                    onExpansionChanged: (exp) => _handleExpansion(7, exp),
                    title: '8. Privacy',
                    icon: Icons.security_rounded,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'The collection, storage, and processing of location, contact, and trip information are governed by LisKo\'s separate Privacy Policy.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 8,
                    onExpansionChanged: (exp) => _handleExpansion(8, exp),
                    title: '9. Updates to Terms',
                    icon: Icons.update_rounded,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'These Terms of Use may be updated periodically as LisKo features or application capabilities evolve.',
                  ),
                  ExpandablePrivacyCard(
                    isExpanded: _expandedIndex == 9,
                    onExpansionChanged: (exp) => _handleExpansion(9, exp),
                    title: '10. Project Contact',
                    icon: Icons.contact_support_outlined,
                    accentColor: AppColors.successText,
                    backgroundColor: const Color(0xFFE8F5E9),
                    description:
                        'For inquiries regarding the LisKo research capstone project, contact:\n'
                        'liskoapp.team@gmail.com',
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
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
