// ==============================================================================
// Lisko Mobile Safety Application - Safety Onboarding Wizard
// File: lib/screens/onboarding_flow.dart
//
// Role & Architectural Context:
// Multi-step progressive setup wizard configuring student safety permissions and
// emergency contacts prior to dashboard access:
// - Step 1: Notification Permission (`NotificationPermissionScreen`)
// - Step 2: Initial Safety Setup checklist (`InitialSafetySetupScreen`)
// - Step 3: Add Trusted Contacts (`AddTrustedContactsScreen` with manual entry form,
//           Philippine phone input container, zero-stripping formatter, and import sheet)
// - Step 4: SMS Permission (`SmsPermissionScreen` with privacy disclaimers)
// - Step 5: Location Geofencing (`LocationPermissionScreen` with zero-surveillance notice)
// - Final: "You're Ready!" completion summary (`SetupReadyScreen`)
// 
// Smart Philippine Phone Validation & Zero-Blocker Logic:
// `PhilippinePhoneInputFormatter` enforces Philippine mobile standards:
// - Automatically intercepts and strips leading zeroes when students type out of habit (e.g. `0917...` -> `917...`).
// - Limits input strictly to numeric digits (max 10 characters starting with `9`).
// - Unifies input with the fixed `+63` prefix into standard E.164-compatible strings (`+63 9XXXXXXXXX`).
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Progressive Disclosure & Guidance): Clear step indicators (`Step N of 5`)
//   and non-blocking navigation allow users to complete setup without overwhelming cognitive load.
// - Functional Suitability & Privacy: Strict zero-surveillance transparency: locations
//   are only monitored during active trips and SMS messages are only dispatched during emergencies.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/phone_contact_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/local_storage_service.dart';
import '../services/permission_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/app_icon.dart';
import '../widgets/onboarding_header_shell.dart';
import 'main_dashboard_screen.dart';
import 'welcome_screen.dart';

// =============================================================================
// STEP 1: INITIAL SAFETY SETUP SCREEN
// =============================================================================

/// Step 1: Initial Safety Setup Checklist Overview.
class InitialSafetySetupScreen extends StatelessWidget {
  const InitialSafetySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: 1,
      title: 'Initial Safety Setup',
      subtitle: 'Complete these steps before your first trip.',
      bottom: PrimaryButton(
        label: 'Continue',
        onPressed: () {
          Navigator.push(
            context,
            createRoute(const NotificationPermissionScreen()),
          );
        },
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetupCard(
            icon: AppIcons.warning,
            semanticIcon: Icons.notifications_active_rounded,
            title: 'Allow Notifications',
            subtitle: 'Receive travel reminders and emergency updates.',
            iconBackground: AppColors.primaryContainer,
            iconColor: AppColors.primary,
          ),
          SizedBox(height: 12),
          SetupCard(
            icon: AppIcons.people,
            semanticIcon: Icons.people_alt_rounded,
            title: 'Add Trusted Contacts',
            subtitle: 'Choose people who can help keep you safe.',
            iconBackground: AppColors.primaryContainer,
            iconColor: AppColors.primary,
          ),
          SizedBox(height: 12),
          SetupCard(
            icon: AppIcons.sms,
            semanticIcon: Icons.sms_rounded,
            title: 'Allow SMS Permission',
            subtitle: 'Let Lisko send an emergency SMS when needed.',
            iconBackground: AppColors.primaryContainer,
            iconColor: AppColors.primary,
          ),
          SizedBox(height: 12),
          SetupCard(
            icon: AppIcons.location,
            semanticIcon: Icons.location_on_rounded,
            title: 'Allow Location Permission',
            subtitle: 'Share your trip location with trusted contacts.',
            iconBackground: AppColors.primaryContainer,
            iconColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 2: NOTIFICATION PERMISSION SCREEN
// =============================================================================

/// Step 2: Notification Permission Request Screen.
class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key});

  void _goToContacts(BuildContext context) {
    Navigator.push(context, createRoute(const TrustedContactsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: 2,
      title: 'Enable Notifications',
      subtitle: 'Never miss an important safety reminder or travel alert.',
      bottom: Column(
        children: [
          PrimaryButton(
            label: 'Allow',
            onPressed: () async {
              await PermissionService().requestNotificationPermission();
              if (!context.mounted) return;
              _goToContacts(context);
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Not Now',
            onPressed: () => _goToContacts(context),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(height: 12),
          NotificationBell(),
          SizedBox(height: 24),
          MockNotificationCard(),
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 3: TRUSTED CONTACTS SCREEN
// =============================================================================
class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  bool manualFormExpanded = false;
  final List<ContactPerson> savedContacts = [];

  Future<void> _openContactsImport() async {
    // 1. Show custom rationale modal first
    final allowed = await showDialog<bool>(
      context: context,
      builder: (_) => const ContactsPermissionModal(),
    );
    if (!mounted || allowed != true) return;

    // 2. Check current system permission status
    final status = await Permission.contacts.status;
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contacts permission is permanently denied. Please enable it in settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // 3. Request native Android permission
    final requested = await Permission.contacts.request();
    if (!requested.isGranted) return;

    if (!mounted) return;

    // 4. Proceed to selection
    final ContactPerson? selected = await showModalBottomSheet<ContactPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactSelectionBottomSheet(
        onContactSelected: (contact) => Navigator.pop(ctx, contact),
      ),
    );

    if (selected != null && mounted) {
      final result = await showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SelectRelationshipBottomSheet(contact: selected),
      );
      if (mounted && result != null) {
        final finalContact = result is ContactPerson
            ? result
            : selected.copyWith(relationship: 'Mother');
        setState(() => savedContacts.add(finalContact));
        
        // Save to local storage immediately
        final storage = const LocalStorageService();
        final currentSaved = await storage.readContacts();
        currentSaved.add(finalContact);
        await storage.saveContacts(currentSaved);
      }
    }
  }

  Future<void> _confirmDeleteContact(ContactPerson contact) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: AppIcon.card(
                    AppIcons.deleteOutline,
                    color: AppColors.primary,
                    semanticIcon: Icons.delete_outline_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove ${contact.name} from your trusted contacts?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.body,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.header,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => savedContacts.remove(contact));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: 3,
      title: 'Add Trusted Contacts',
      subtitle: 'Add people we can contact if you need help during a trip.',
      bottom: PrimaryButton(
        label: 'Continue',
        onPressed: savedContacts.isEmpty
            ? null
            : () async {
                await const LocalStorageService().saveContacts(savedContacts);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  createRoute(const SmsPermissionScreen()),
                );
              },
      ),
      child: Column(
        children: [
          PrimaryButton(
            label: 'Import from Contacts',
            iconifyIcon: AppIcons.contacts,
            icon: Icons.contacts_rounded,
            onPressed: _openContactsImport,
          ),
          if (savedContacts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SAVED CONTACTS',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.body,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...savedContacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SavedContactCard(
                  contact: contact,
                  onRemove: () => _confirmDeleteContact(contact),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const OrDivider(),
          const SizedBox(height: 28),
          if (manualFormExpanded)
            ManualContactExpandedForm(
              onCancel: () => setState(() => manualFormExpanded = false),
              onSaved: (contact) {
                setState(() {
                  savedContacts.add(contact);
                  manualFormExpanded = false;
                });
              },
            )
          else
            GestureDetector(
              onTap: () => setState(() => manualFormExpanded = true),
              child: const ManualContactCard(),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 4: SMS PERMISSION SCREEN
// =============================================================================

/// Step 4: SMS Permission Screen.
class SmsPermissionScreen extends StatelessWidget {
  const SmsPermissionScreen({super.key});

  void _goToLocation(BuildContext context) {
    Navigator.push(context, createRoute(const LocationAccessScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: 4,
      title: 'Allow SMS Permission',
      subtitle:
          "Lisko uses your device's SMS service to notify your trusted contacts during emergencies or missed travel check-ins.",
      bottom: Column(
        children: [
          PrimaryButton(
            label: 'Allow',
            onPressed: () async {
              await PermissionService().requestSmsPermission();
              if (!context.mounted) return;
              _goToLocation(context);
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Later',
            onPressed: () => _goToLocation(context),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(height: 12),
          SmsIllustration(),
          SizedBox(height: 28),
          InfoBox(),
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 5: LOCATION ACCESS SCREEN
// =============================================================================

/// Step 5: Location Access Screen.
class LocationAccessScreen extends StatelessWidget {
  const LocationAccessScreen({super.key});

  void _finishSetup(BuildContext context) {
    Navigator.push(context, createRoute(const SetupCompleteScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      step: 5,
      title: 'Allow Location Access',
      subtitle:
          'Your location is only accessed while a trip is active or when sending an emergency alert.',
      bottom: Column(
        children: [
          PrimaryButton(
            label: 'Allow Location',
            iconifyIcon: AppIcons.location,
            icon: Icons.location_on_rounded,
            onPressed: () async {
              await PermissionService().requestLocationPermission();
              if (!context.mounted) return;
              _finishSetup(context);
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Later',
            onPressed: () => _finishSetup(context),
          ),
        ],
      ),
      child: const Column(
        children: [
          SizedBox(height: 12),
          LocationIllustration(),
          SizedBox(height: 28),
          LocationInfoBox(),
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 6: SETUP COMPLETE SCREEN
// =============================================================================

/// Setup Complete Screen confirming user readiness with spring and sequential animations.
class SetupCompleteScreen extends StatefulWidget {
  const SetupCompleteScreen({super.key});

  @override
  State<SetupCompleteScreen> createState() => _SetupCompleteScreenState();
}

class _SetupCompleteScreenState extends State<SetupCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _checkScale = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
    ),
  );

  late final Animation<double> _checkOpacity = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
          child: Column(
            children: [
              const SizedBox(height: 34),
              SuccessIllustration(
                scaleAnimation: _checkScale,
                opacityAnimation: _checkOpacity,
              ),
              const SizedBox(height: 28),
              Text(
                "You're Ready!",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your safety setup has been completed successfully. You can now begin using Lisko.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 28),
              SetupChecklist(controller: _controller),
              const Spacer(),
              PrimaryButton(
                label: 'Go to Home',
                iconifyIcon: AppIcons.home,
                icon: Icons.home_rounded,
                onPressed: () async {
                  await const LocalStorageService().setSetupCompleted(true);
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    createRoute(
                      const HomeScreen(),
                      transition: RouteTransition.fadeThrough,
                    ),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-COMPONENTS, ILLUSTRATIONS & MODALS
// =============================================================================

bool get _isTestMode {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return binding.contains('TestWidgetsFlutterBinding') ||
      binding.contains('AutomatedTestWidgetsFlutterBinding');
}

/// Notification Bell displaying an ambient pulsing ring (#FFDAD8) with 60fps performance.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _pulseAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
  );

  @override
  void initState() {
    super.initState();
    if (_isTestMode) {
      _controller.forward();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulse = _pulseAnimation.value;
          final ringScale = 1.0 + (0.32 * pulse);
          final ringAlpha = (1.0 - pulse) * 0.55;

          return SizedBox(
            width: 154,
            height: 154,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Pulsing outer pink fading ring (#FFDAD8)
                Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer.withValues(alpha: ringAlpha),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: ringAlpha * 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                // Inner primary base circle
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC8CD),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: AppIcon.featureLarge(
                          AppIcons.notifications,
                          color: AppColors.primary,
                          semanticIcon: Icons.notifications_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                // Notification badge "1"
                Positioned(
                  right: 20,
                  top: 18,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.canvas, width: 3),
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MockNotificationCard extends StatelessWidget {
  const MockNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/lisko_logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LISKO  •  now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.body,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Are you home, Iskolar? Your trip timer ended.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.header,
                    fontWeight: FontWeight.w600,
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



class SetupCard extends StatelessWidget {
  const SetupCard({
    super.key,
    required this.icon,
    this.semanticIcon,
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.iconColor,
  });

  final String icon;
  final IconData? semanticIcon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: AppIcon.card(
                icon,
                color: iconColor,
                semanticIcon: semanticIcon,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.body,
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

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR ENTER MANUALLY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.body,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class ManualContactCard extends StatelessWidget {
  const ManualContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          AppIcon.card(
            AppIcons.personAdd,
            color: AppColors.primary,
            semanticIcon: Icons.person_add_alt_1_rounded,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add Manual Contact',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.header,
              ),
            ),
          ),
          AppIcon.standard(
            AppIcons.arrowDown,
            color: AppColors.body,
            semanticIcon: Icons.keyboard_arrow_down_rounded,
          ),
        ],
      ),
    );
  }
}

/// Renders the stylized Philippine flag indicator matching the design specifications.
class PhilippineFlagIndicator extends StatelessWidget {
  const PhilippineFlagIndicator({
    super.key,
    this.width = 24,
    this.height = 15,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.header,
        borderRadius: BorderRadius.circular(2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(width, height),
        painter: _PhilippineFlagPainter(),
      ),
    );
  }
}

class _PhilippineFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // White chevron / triangle on the hoist (left side)
    final trianglePath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.44, size.height * 0.5)
      ..lineTo(0, size.height);

    canvas.drawPath(trianglePath, strokePaint);

    // Horizontal divider line extending to right
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Restricts phone input strictly to numbers (max 10 digits) and automatically
/// ignores or strips out any leading zero so it only captures digits starting with 9.
class PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // If pasted or entered with leading 63 (e.g. 639123456789)
    if (digits.startsWith('63') && digits.length > 10) {
      digits = digits.substring(2);
    }

    // Smart Zero-Blocker Logic:
    // If the user types '0' as the very first digit (e.g. trying to type 0912...),
    // automatically ignore or strip out the leading zero so it only captures and
    // displays the subsequent digits starting with 9 (e.g. 9123456789).
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Restrict strictly to numbers (max 10 digits)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class ManualContactExpandedForm extends StatefulWidget {
  const ManualContactExpandedForm({
    super.key,
    this.onSaved,
    this.onCancel,
  });

  final ValueChanged<ContactPerson>? onSaved;
  final VoidCallback? onCancel;

  @override
  State<ManualContactExpandedForm> createState() =>
      _ManualContactExpandedFormState();
}

class _ManualContactExpandedFormState extends State<ManualContactExpandedForm> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController otherRelationshipController;
  String relationship = 'Mother';
  String? nameError;
  String? phoneError;
  String? otherRelationshipError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    phoneController = TextEditingController();
    otherRelationshipController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    otherRelationshipController.dispose();
    super.dispose();
  }

  String? _validatePhone(String input) {
    final clean = input.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) {
      return 'Phone number is required';
    }
    // Must be 10 digits starting with 9
    if (clean.length != 10 || !clean.startsWith('9')) {
      return 'Must be a 10-digit number starting with 9 (e.g., 9123456789)';
    }
    return null;
  }

  String _formatPhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length > 10) {
      digits = digits.substring(2);
    }
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+63 $digits';
  }

  String _extractInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CP';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _saveContact() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final otherRel = otherRelationshipController.text.trim();

    String? nError;
    String? pError;
    String? oError;

    if (name.isEmpty) {
      nError = 'Contact name is required';
    }

    pError = _validatePhone(phone);

    if (relationship == 'Other' && otherRel.isEmpty) {
      oError = 'Please specify relationship';
    }

    if (nError != null || pError != null || oError != null) {
      setState(() {
        nameError = nError;
        phoneError = pError;
        otherRelationshipError = oError;
      });
      return;
    }

    final selectedRel = relationship == 'Other' ? otherRel : relationship;
    final formattedPhone = _formatPhone(phone);
    final initials = _extractInitials(name);

    widget.onSaved?.call(
      ContactPerson(
        name: name,
        phone: formattedPhone,
        initials: initials,
        relationship: selectedRel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onCancel,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Manual Contact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.header,
                      ),
                    ),
                  ),
                  AppIcon.standard(
                    AppIcons.arrowUp,
                    color: AppColors.body,
                    semanticIcon: Icons.keyboard_arrow_up_rounded,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            onChanged: (_) {
              if (nameError != null) {
                setState(() => nameError = null);
              }
            },
            decoration: InputDecoration(
              prefixIcon: const AppIcon.badge(
                AppIcons.personOutline,
                color: AppColors.body,
                semanticIcon: Icons.person_outline_rounded,
              ),
              hintText: 'e.g., Mom',
              hintStyle: const TextStyle(color: AppColors.body, fontSize: 14),
              errorText: nameError,
              filled: true,
              fillColor: AppColors.canvas,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Relationship',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 9),
          RelationshipChips(
            selected: relationship,
            onChanged: (value) => setState(() {
              relationship = value;
              otherRelationshipError = null;
            }),
          ),
          if (relationship == 'Other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: otherRelationshipController,
              onChanged: (_) {
                if (otherRelationshipError != null) {
                  setState(() => otherRelationshipError = null);
                }
              },
              decoration: InputDecoration(
                prefixIcon: const AppIcon.badge(
                  AppIcons.peopleOutline,
                  color: AppColors.body,
                  semanticIcon: Icons.people_outline_rounded,
                ),
                hintText: 'e.g., Friend',
                hintStyle: const TextStyle(color: AppColors.body, fontSize: 14),
                errorText: otherRelationshipError,
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: phoneError != null
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
                width: phoneError != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Left Prefix Box: Flag indicator alongside +63 in bold navy
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhilippineFlagIndicator(),
                      const SizedBox(width: 8),
                      const Text(
                        '+63',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.header,
                        ),
                      ),
                    ],
                  ),
                ),
                // Subtle vertical divider line
                Container(
                  width: 1,
                  height: 26,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 12),
                // Right Text Field: starts directly after +63 with placeholder hint "9XX XXX XXXX"
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      PhilippinePhoneInputFormatter(),
                    ],
                    onChanged: (_) {
                      if (phoneError != null) {
                        setState(() => phoneError = null);
                      }
                    },
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.header,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: '9XX XXX XXXX',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          if (phoneError != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                phoneError!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saveContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Save Contact'),
            ),
          ),
        ],
      ),
    );
  }
}

class SavedContactCard extends StatelessWidget {
  const SavedContactCard({
    super.key,
    required this.contact,
    required this.onRemove,
  });

  final ContactPerson contact;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (contact.relationship.isNotEmpty) ...[
                      Text(
                        contact.relationship,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '|',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove contact',
            icon: const AppIcon.standard(
              AppIcons.deleteOutline,
              color: AppColors.primary,
              semanticIcon: Icons.delete_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class RelationshipChips extends StatelessWidget {
  const RelationshipChips({
    super.key,
    this.selected = 'Mother',
    this.onChanged,
  });

  final String selected;
  final ValueChanged<String>? onChanged;

  static const List<String> relationships = [
    'Mother',
    'Father',
    'Guardian',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(relationships.length, (index) {
        final label = relationships[index];
        final isSelected = selected == label;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == relationships.length - 1 ? 0 : 6,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: onChanged == null ? null : () => onChanged!(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSelected ? AppColors.primary : Colors.white,
                  foregroundColor:
                      isSelected ? Colors.white : const Color(0xFF64748B),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                child: Text(label),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ContactsPermissionModal extends StatelessWidget {
  const ContactsPermissionModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F172A),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: AppIcon.feature(
                  AppIcons.shield,
                  size: 36,
                  color: Colors.white,
                  semanticIcon: Icons.shield_rounded,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "'Lisko' Would Like to Access Your Contacts",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.header,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This allows you to select trusted contacts directly from your phone to receive emergency SMS notifications during your commute.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.body,
              ),
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: AppColors.border),
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.body,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: const Text(
                        "Don't Allow",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: const Text(
                        'Allow',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactSelectionBottomSheet extends StatefulWidget {
  const ContactSelectionBottomSheet({super.key, this.onContactSelected});

  final ValueChanged<ContactPerson>? onContactSelected;

  @override
  State<ContactSelectionBottomSheet> createState() => _ContactSelectionBottomSheetState();
}

class _ContactSelectionBottomSheetState extends State<ContactSelectionBottomSheet> {
  final PhoneContactService _contactService = PhoneContactService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Contact>? _allContacts;
  List<Contact>? _filteredContacts;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactService.fetchContacts();
      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load contacts. Please ensure permission is granted.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_allContacts == null) return;
    setState(() {
      _filteredContacts = _contactService.filterContacts(_allContacts!, _searchController.text);
    });
  }

  Future<void> _handleContactTap(Contact contact) async {
    String? selectedPhone;

    if (contact.phones.length == 1) {
      selectedPhone = contact.phones.first.number;
    } else {
      // Multiple numbers: show selection modal
      selectedPhone = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NumberSelectionBottomSheet(contact: contact),
      );
    }

    if (selectedPhone != null && mounted) {
      final normalizedPhone = PhoneContactService.normalizePhoneNumber(selectedPhone);
      final initials = ContactPerson.computeInitials(contact.displayName);
      
      widget.onContactSelected?.call(ContactPerson(
        name: contact.displayName,
        phone: normalizedPhone,
        initials: initials,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const AppIcon.standard(
                  AppIcons.close,
                  color: AppColors.body,
                  semanticIcon: Icons.close_rounded,
                ),
                tooltip: 'Close',
              ),
            ),
            const Text(
              'Phone Contacts',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.header,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Select a contact to import',
              style: TextStyle(fontSize: 14, color: AppColors.body),
            ),
            const SizedBox(height: 16),
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.body),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildContent(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.border,
                  foregroundColor: AppColors.body,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.body),
        ),
      );
    }

    if (_filteredContacts == null || _filteredContacts!.isEmpty) {
      return const Center(
        child: Text(
          'No contacts found',
          style: TextStyle(color: AppColors.body),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredContacts!.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts![index];
        final initials = ContactPerson.computeInitials(contact.displayName);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _handleContactTap(contact),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.header,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            contact.phones.length == 1 
                              ? contact.phones.first.number 
                              : '${contact.phones.length} phone numbers',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppIcon.badge(
                      AppIcons.chevronRight,
                      color: AppColors.body,
                      semanticIcon: Icons.chevron_right_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NumberSelectionBottomSheet extends StatelessWidget {
  const NumberSelectionBottomSheet({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Phone Number',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.header,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose a number for ${contact.displayName}',
              style: const TextStyle(fontSize: 14, color: AppColors.body),
            ),
            const SizedBox(height: 20),
            ...contact.phones.map((phone) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.pop(context, phone.number),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            phone.number,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.header,
                            ),
                          ),
                        ),
                        if (phone.label != PhoneLabel.mobile)
                          Text(
                            phone.label.toString().split('.').last.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.body,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.border,
                  foregroundColor: AppColors.body,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectRelationshipBottomSheet extends StatefulWidget {
  const SelectRelationshipBottomSheet({super.key, required this.contact});

  final ContactPerson contact;

  @override
  State<SelectRelationshipBottomSheet> createState() =>
      _SelectRelationshipBottomSheetState();
}

class _SelectRelationshipBottomSheetState
    extends State<SelectRelationshipBottomSheet> {
  String relationship = 'Mother';
  final TextEditingController _customRelationshipController = TextEditingController();

  @override
  void dispose() {
    _customRelationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const AppIcon.standard(
                  AppIcons.close,
                  color: AppColors.body,
                  semanticIcon: Icons.close_rounded,
                ),
                tooltip: 'Close',
              ),
            ),
            const Text(
              'Select Relationship',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.header,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'How is this contact related to you?',
              style: TextStyle(fontSize: 14, color: AppColors.body),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.contact.initials,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contact.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.header,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.contact.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '✓ Imported',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.successText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            RelationshipChips(
              selected: relationship,
              onChanged: (value) => setState(() => relationship = value),
            ),
            if (relationship == 'Other') ...[
              const SizedBox(height: 16),
              const Text(
                'Specify Relationship',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customRelationshipController,
                decoration: InputDecoration(
                  hintText: 'e.g. Aunt, Uncle, Sibling',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm & Save Contact',
              iconifyIcon: AppIcons.check,
              icon: Icons.check_rounded,
              onPressed: () {
                final finalRel = relationship == 'Other'
                    ? _customRelationshipController.text.trim()
                    : relationship;
                Navigator.pop(
                  context,
                  widget.contact.copyWith(
                    relationship: finalRel.isEmpty ? 'Other' : finalRel,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class SmsIllustration extends StatefulWidget {
  const SmsIllustration({super.key});

  @override
  State<SmsIllustration> createState() => _SmsIllustrationState();
}

class _SmsIllustrationState extends State<SmsIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final Animation<double> _bubble1Opacity = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.65, curve: Curves.easeOut),
    ),
  );

  late final Animation<Offset> _bubble1Slide = Tween<Offset>(
    begin: const Offset(-0.15, 0.25),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.65, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _bubble2Opacity = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.90, curve: Curves.easeOut),
    ),
  );

  late final Animation<Offset> _bubble2Slide = Tween<Offset>(
    begin: const Offset(0.15, 0.25),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.90, curve: Curves.easeOutCubic),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: SizedBox(
          width: 290,
          height: 196,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Central Phone/Chat Plate
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0F5),
                  borderRadius: BorderRadius.circular(42),
                ),
                child: Center(
                  child: Container(
                    width: 88,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100F172A),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: AppIcon.feature(
                        AppIcons.chatBubble,
                        size: 44,
                        color: AppColors.header,
                        semanticIcon: Icons.chat_bubble_rounded,
                      ),
                    ),
                  ),
                ),
              ),
              // Anchored floating bubble 1 (Top Left)
              Positioned(
                top: 10,
                left: 6,
                child: FadeTransition(
                  opacity: _bubble1Opacity,
                  child: SlideTransition(
                    position: _bubble1Slide,
                    child: const MessageBubble(
                      text: 'Are you home?',
                      isSender: false,
                    ),
                  ),
                ),
              ),
              // Anchored floating bubble 2 (Bottom Right)
              Positioned(
                bottom: 10,
                right: 6,
                child: FadeTransition(
                  opacity: _bubble2Opacity,
                  child: SlideTransition(
                    position: _bubble2Slide,
                    child: const MessageBubble(
                      text: 'SMS sent ✓',
                      success: true,
                      isSender: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    this.success = false,
    this.isSender = false,
  });

  final String text;
  final bool success;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: isSender ? const Radius.circular(14) : const Radius.circular(4),
      bottomRight: isSender ? const Radius.circular(4) : const Radius.circular(14),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: success ? AppColors.successContainer : AppColors.card,
        borderRadius: borderRadius,
        border: Border.all(
          color: success
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (success) ...[
            const AppIcon(
              AppIcons.checkCircle,
              size: 14,
              color: AppColors.successText,
              semanticIcon: Icons.check_circle_rounded,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: success ? AppColors.successText : AppColors.header,
            ),
          ),
        ],
      ),
    );
  }
}

class LocationIllustration extends StatefulWidget {
  const LocationIllustration({super.key});

  @override
  State<LocationIllustration> createState() => _LocationIllustrationState();
}

class _LocationIllustrationState extends State<LocationIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _floatOffset = Tween<double>(
    begin: 0.0,
    end: -6.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
  );

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.98,
    end: 1.03,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
  );

  @override
  void initState() {
    super.initState();
    if (_isTestMode) {
      _controller.forward();
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, _floatOffset.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F4EE),
                  borderRadius: BorderRadius.circular(42),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.18),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100F172A),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: AppIcon.featureLarge(
                        AppIcons.location,
                        color: AppColors.success,
                        semanticIcon: Icons.location_on_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LocationInfoBox extends StatelessWidget {
  const LocationInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.successContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIcon.standard(
            AppIcons.lockOutline,
            color: AppColors.successText,
            semanticIcon: Icons.lock_outline_rounded,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Location is never tracked when no trip is active.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.successText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessIllustration extends StatelessWidget {
  const SuccessIllustration({
    super.key,
    this.scaleAnimation,
    this.opacityAnimation,
  });

  final Animation<double>? scaleAnimation;
  final Animation<double>? opacityAnimation;

  @override
  Widget build(BuildContext context) {
    if (scaleAnimation == null || opacityAnimation == null) {
      return _buildStaticSuccess();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([scaleAnimation!, opacityAnimation!]),
        builder: (context, child) {
          final scale = scaleAnimation!.value;
          final opacity = opacityAnimation!.value;

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.25 * opacity),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 106,
                    height: 106,
                    decoration: const BoxDecoration(
                      color: Color(0xFFBCEFD9),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AppIcon.featureLarge(
                        AppIcons.check,
                        color: AppColors.successText,
                        semanticIcon: Icons.check_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticSuccess() {
    return Container(
      width: 156,
      height: 156,
      decoration: const BoxDecoration(
        color: AppColors.successContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 106,
          height: 106,
          decoration: const BoxDecoration(
            color: Color(0xFFBCEFD9),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: AppIcon.featureLarge(
              AppIcons.check,
              color: AppColors.successText,
              semanticIcon: Icons.check_rounded,
            ),
          ),
        ),
      ),
    );
  }
}

class SetupChecklist extends StatelessWidget {
  const SetupChecklist({super.key, this.controller});

  final AnimationController? controller;

  @override
  Widget build(BuildContext context) {
    const items = [
      'Notifications enabled',
      'Trusted contacts added',
      'SMS & Location ready',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];

          if (controller == null) {
            return _buildCheckItem(item);
          }

          final startInterval = 0.35 + (index * 0.18);
          final endInterval = (startInterval + 0.32).clamp(0.0, 1.0);

          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.30),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: controller!,
              curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
            ),
          );

          final opacityAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: controller!,
              curve: Interval(startInterval, endInterval, curve: Curves.easeOut),
            ),
          );

          return RepaintBoundary(
            child: AnimatedBuilder(
              animation: controller!,
              builder: (context, child) {
                return FadeTransition(
                  opacity: opacityAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: _buildCheckItem(item),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCheckItem(String item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const AppIcon.standard(
            AppIcons.checkCircle,
            color: AppColors.success,
            semanticIcon: Icons.check_circle_rounded,
          ),
          const SizedBox(width: 12),
          Text(
            item,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.header,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon.standard(
            AppIcons.infoOutline,
            color: AppColors.successText,
            semanticIcon: Icons.info_outline_rounded,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No SMS messages are sent unless an emergency occurs or a travel check-in is missed.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.successText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



