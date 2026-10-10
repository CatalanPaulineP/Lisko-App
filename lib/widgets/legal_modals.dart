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

class ExpandablePrivacyCard extends StatefulWidget {
  const ExpandablePrivacyCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  State<ExpandablePrivacyCard> createState() => _ExpandablePrivacyCardState();
}

class _ExpandablePrivacyCardState extends State<ExpandablePrivacyCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded, color: AppColors.body, size: 20),
          ),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: AppColors.primary, size: 18),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.header,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Text(
              widget.description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet presenting LisKo's Privacy Policy and GPS Usage Rules.
class PrivacyPolicyModalBottomSheet extends StatelessWidget {
  const PrivacyPolicyModalBottomSheet({super.key});

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
                    icon: const Icon(Icons.close_rounded, color: AppColors.body),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const ExpandablePrivacyCard(
                    title: 'Information LisKo Uses',
                    icon: Icons.folder_shared_outlined,
                    description:
                        'LisKo uses information necessary for travel safety monitoring:\n'
                        '• Trusted Contacts: Names, phone numbers, and relationships you provide.\n'
                        '• Commute Settings: Travel destinations and timer presets you select.\n'
                        '• Trip Logs: Travel timer status and timestamps.\n'
                        '• Location Coordinates: Used only when required by geofence arrival or emergency alert features.\n'
                        '• Anonymous Installation ID: Generated locally (installationId) to isolate trip and emergency event logs per device in Cloud Firestore without requiring personal user accounts.\n\n'
                        'LisKo does not require user registration or an online account. Trusted contacts and app preferences are stored locally on your device.',
                  ),
                  const ExpandablePrivacyCard(
                    title: 'Why Information Is Used',
                    icon: Icons.center_focus_strong_outlined,
                    description:
                        'LisKo uses this information solely to:\n'
                        '• Manage active commute timers and send arrival reminders.\n'
                        '• Automatically detect arrival at your selected destination geofence.\n'
                        '• Send safe-arrival SMS notifications to your Primary Emergency Contact.\n'
                        '• Dispatch emergency alerts with your location to trusted contacts when needed.',
                  ),
                  const ExpandablePrivacyCard(
                    title: 'SMS & Communication Privacy',
                    icon: Icons.sms_outlined,
                    description:
                        '• LisKo dispatches emergency and safe-arrival SMS messages via your device\'s SIM network.\n'
                        '• LisKo does not read, access, or receive SMS messages from your inbox (READ_SMS and RECEIVE_SMS permissions are not used).\n'
                        '• SMS messages are sent only during active safety events or user-initiated emergency actions.',
                  ),
                  const ExpandablePrivacyCard(
                    title: 'Who Receives Your Information',
                    icon: Icons.people_outline_rounded,
                    description:
                        '• Normal Safe Arrival: Confirming "I\'m Safe" sends an SMS only to your Primary Emergency Contact without GPS coordinates.\n'
                        '• Emergency Alerts: Triggering Manual SOS, tapping "Need Help", or failing to respond to a safety timeout sends emergency alerts to all your trusted contacts.\n'
                        '• No Live-Tracking Dashboard: LisKo does not broadcast your location to a public or admin web dashboard.',
                  ),
                  const ExpandablePrivacyCard(
                    title: 'Storage & User Control',
                    icon: Icons.phonelink_setup_rounded,
                    description:
                        '• No account registration or login is required.\n'
                        '• Some app information, such as trusted contacts and preferences, is stored locally on your phone.\n'
                        '• You can add, edit, or remove trusted contacts at any time.\n'
                        '• You can manage Android location permissions through system settings.',
                  ),
                  const ExpandablePrivacyCard(
                    title: 'Privacy Commitment',
                    icon: Icons.verified_user_outlined,
                    description:
                        'LisKo is designed to minimize location sharing by utilizing location information only when required by its safety and emergency features.',
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
                  const ExpandablePrivacyCard(
                    title: '1. When GPS / Location Is Used',
                    icon: Icons.location_on_outlined,
                    description:
                        'LisKo accesses location services only during specific event-driven safety functions:\n'
                        '• Destination Arrival: Checking geofence boundary arrival during an active trip.\n'
                        '• Emergency Alerts: Requesting your current location during Manual SOS, "Need Help", or an unhandled safety timeout.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '2. When GPS Is NOT Used',
                    icon: Icons.location_off_outlined,
                    description:
                        '• LisKo does not continuously broadcast or track your location throughout your journey.\n'
                        '• LisKo does not provide 24/7 live-location tracking.\n'
                        '• Confirming "I\'m Safe" on arrival does not attach GPS coordinates to the normal Safe Arrival SMS.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '3. Emergency Location Sharing',
                    icon: Icons.sos_rounded,
                    description:
                        '• During an emergency alert, LisKo attempts to obtain your current GPS coordinates.\n'
                        '• If a valid location fix is obtained, coordinates and a Google Maps link may be included in the emergency SMS.\n'
                        '• If location services cannot obtain a current fix, the emergency alert is still sent without location coordinates.\n'
                        '• Emergency location is sent only to the trusted contacts involved in the alert.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '4. Permissions & User Control',
                    icon: Icons.admin_panel_settings_outlined,
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
class TermsOfUseModalBottomSheet extends StatelessWidget {
  const TermsOfUseModalBottomSheet({super.key});

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
                    icon: const Icon(Icons.close_rounded, color: AppColors.body),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const ExpandablePrivacyCard(
                    title: '1. Purpose of LisKo',
                    icon: Icons.info_outline_rounded,
                    description:
                        'LisKo is a mobile student travel safety and emergency monitoring application designed to support Polytechnic University of the Philippines – Santa Maria Campus students during travel between home and campus.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '2. Supplementary Safety Tool',
                    icon: Icons.gavel_rounded,
                    description:
                        '• LisKo is a supplementary safety tool intended to assist travel communication.\n'
                        '• LisKo is NOT a replacement for official emergency response services (such as police, ambulance, fire services, or 911).\n'
                        '• In an immediate or life-threatening emergency, users should contact official local emergency services directly whenever possible.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '3. Emergency SMS Limitations',
                    icon: Icons.signal_cellular_alt_rounded,
                    description:
                        '• Emergency SMS alert transmission relies on your cellular network SIM signal, active carrier subscription, device battery state, and system permissions.\n'
                        '• LisKo cannot guarantee successful SMS delivery under zero-signal conditions, carrier network outages, or hardware power loss.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '4. Location / GPS Limitations',
                    icon: Icons.my_location_rounded,
                    description:
                        '• Geofence boundary arrival detection and GPS location accuracy depend on device location hardware, satellite visibility, clear sky conditions, and Android location settings.\n'
                        '• LisKo cannot guarantee exact boundary detection under severe GPS drift, indoor signal attenuation, or device hardware limitations.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '5. Device & Power Management',
                    icon: Icons.battery_saver_rounded,
                    description:
                        '• Android OS or device manufacturer background power management settings may affect background execution if restricted by the user.\n'
                        '• Users should ensure background power settings allow LisKo to operate during active trips.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '6. User Responsibilities',
                    icon: Icons.assignment_ind_outlined,
                    description:
                        'Users must:\n'
                        '• Maintain accurate, up-to-date phone numbers for trusted contacts.\n'
                        '• Select trusted contacts responsibly with their knowledge.\n'
                        '• Maintain required system permissions (Location, Notifications, SMS) during active trips.\n'
                        '• Maintain adequate phone battery charge during travel.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '7. Responsible Use & Misuse',
                    icon: Icons.block_rounded,
                    description:
                        '• LisKo must be used strictly for genuine travel safety and emergency communication.\n'
                        '• Users shall not intentionally trigger false emergency alerts, misuse SOS features, or use the application to harass contacts.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '8. Privacy',
                    icon: Icons.security_rounded,
                    description:
                        'The collection, storage, and processing of location, contact, and trip information are governed by LisKo\'s separate Privacy Policy.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '9. Updates to Terms',
                    icon: Icons.update_rounded,
                    description:
                        'These Terms of Use may be updated periodically as LisKo features or application capabilities evolve.',
                  ),
                  const ExpandablePrivacyCard(
                    title: '10. Project Contact',
                    icon: Icons.contact_support_outlined,
                    description:
                        'For inquiries regarding the LisKo research capstone project, contact:\n'
                        '[INSERT OFFICIAL LISKO/PUP PROJECT EMAIL BEFORE RELEASE]',
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
