// ==============================================================================
// Lisko Mobile Safety Application - Settings & Preferences Tab
// File: lib/screens/settings_tab.dart
//
// Role & Architectural Context:
// Application preferences and security configuration tab (`SettingsTab`).
// Serves as the central hub for managing notification permissions, emergency SMS
// templates, haptic escalation sensitivity, and local data resets.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Functional Suitability (Configurability & Control): Gives students granular
//   control over their personal safety thresholds and notification alerts.
// - Usability: Simple, accessible settings layout aligned with Material 3 styling.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_icon.dart';
import 'home_tab.dart'; // For HomeHeaderPatternPainter

/// Tab for managing Lisko preferences, notifications, and permissions.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final LocalStorageService _storage = const LocalStorageService();

  String _defaultDuration = '45 mins';
  String _alertMode = 'Sound & Vibrate';
  // _covertSmsDispatch removed
  double? _homeLat;
  double? _homeLng;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final homeCoords = await _storage.readHomeCoordinates();
    final alertMode = await _storage.readAlertMode();
    final defaultMins = await _storage.readDefaultTravelDuration();
    if (mounted) {
      setState(() {
        _homeLat = homeCoords['latitude'];
        _homeLng = homeCoords['longitude'];
        _alertMode = alertMode;
        _defaultDuration = '$defaultMins mins';
      });
    }
  }

  void _openHomeGeofenceModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SetHomeGeofenceModal(
        currentLat: _homeLat,
        currentLng: _homeLng,
        onSaved: (lat, lng) async {
          await _storage.saveHomeCoordinates(latitude: lat, longitude: lng);
          if (mounted) {
            setState(() {
              _homeLat = lat;
              _homeLng = lng;
            });
          }
        },
      ),
    );
  }

  void _openCampusGeofenceModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Campus Geofence'),
        content: const Text(
            'PUP Santa Maria Campus coordinates are fixed at 14.8697� N, 120.9991� E.\n\n'
            'The arrival perimeter is set to 150 meters. When your device enters this radius, '
            'the arrival timer triggers automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _openUserGuideModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const InfoModalBottomSheet(
        title: 'User Guide & Safety Protocol',
        content: 'The Lisko safety protocol operates in 3 escalation stages:\n\n'
            '1. Warning: 90 seconds before trip expiry, the app will notify you.\n'
            '2. Escalation: 3-cycle haptic vibrations occur.\n'
            '3. Emergency: Offline SMS dispatch to your trusted contacts.\n\n'
            'Please ensure you respond to the warning prompt if you are safe.',
      ),
    );
  }

  void _openPrivacyModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const InfoModalBottomSheet(
        title: 'Privacy Policy & GPS Usage',
        content: 'Lisko uses a Zero-Surveillance Architecture:\n\n'
            '- GPS is only tracked during active trips.\n'
            '- Geofence monitoring runs 100% locally on your device.\n'
            '- Your location data is NEVER uploaded to any cloud server.\n'
            '- Emergency SMS alerts send your last known location only to your trusted contacts.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Commute Presets & Geofencing Card
                  _buildSectionTitle('COMMUTE PRESETS & GEOFENCING'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _buildActionRow(
                          iconStr: AppIcons.home,
                          semanticIcon: Icons.home_rounded,
                          iconBg: const Color(0xFFFFDAD8),
                          iconColor: AppColors.primary,
                          title: 'Home Location Pin',
                          subtitle: _homeLat != null
                              ? '${_homeLat!.toStringAsFixed(4)}� N, ${_homeLng!.toStringAsFixed(4)}� E'
                              : 'Tap to set home coordinates',
                          onTap: _openHomeGeofenceModal,
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildActionRow(
                          iconStr: AppIcons.building,
                          semanticIcon: Icons.apartment_rounded,
                          iconBg: AppColors.canvas,
                          iconColor: AppColors.body,
                          title: 'PUP Santa Maria Campus',
                          subtitle: '14.8697° N, 120.9991° E • 150m',
                          onTap: _openCampusGeofenceModal,
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildDropdownRow(
                          iconStr: AppIcons.schedule,
                          semanticIcon: Icons.timer_rounded,
                          iconBg: AppColors.canvas,
                          iconColor: AppColors.body,
                          title: 'Default Travel Duration',
                          value: _defaultDuration,
                          items: const ['15 mins', '30 mins', '45 mins', '60 mins'],
                          onChanged: (val) {
                              setState(() => _defaultDuration = val!);
                              final mins = int.tryParse(val!.replaceAll(' mins', '')) ?? 45;
                              _storage.saveDefaultTravelDuration(mins);
                            },
                        ),
                        // End of Commute Presets
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Alarm & Safety Protocol Card
                  _buildSectionTitle('ALARM & SAFETY PROTOCOL'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _buildDropdownRow(
                          iconStr: AppIcons.vibration,
                          semanticIcon: Icons.vibration_rounded,
                          iconBg: AppColors.canvas,
                          iconColor: AppColors.body,
                          title: 'Timer Expiry Alert Mode',
                          value: _alertMode,
                          items: const ['Vibrate Only', 'Sound & Vibrate', 'Silent'],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _alertMode = val);
                              _storage.saveAlertMode(val);
                            }
                          },
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildInfoRow(
                          iconStr: AppIcons.warning,
                          semanticIcon: Icons.warning_rounded,
                          iconBg: const Color(0xFFFFDAD8),
                          iconColor: AppColors.primary,
                          title: 'Covert SMS Emergency Dispatch',
                          subtitle: '3-cycle haptic escalation before offline SMS trigger',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Information & Support Card
                  _buildSectionTitle('INFORMATION & SUPPORT'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _buildActionRow(
                          iconStr: AppIcons.book,
                          semanticIcon: Icons.book_rounded,
                          iconBg: AppColors.canvas,
                          iconColor: AppColors.body,
                          title: 'User Guide & Safety Protocol',
                          onTap: _openUserGuideModal,
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildActionRow(
                          iconStr: AppIcons.shield,
                          semanticIcon: Icons.privacy_tip_rounded,
                          iconBg: AppColors.canvas,
                          iconColor: AppColors.body,
                          title: 'Privacy Policy & GPS Usage Rules',
                          onTap: _openPrivacyModal,
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildActionRow(
                          iconStr: AppIcons.warning,
                          semanticIcon: Icons.bug_report_rounded,
                          iconBg: const Color(0xFFFFDAD8),
                          iconColor: AppColors.primary,
                          title: 'TEST HEADS-UP NOTIFICATION',
                          onTap: () {
                            debugPrint('[TEST] Calling NotificationService.showArrivalAlarm()');
                            NotificationService().showArrivalAlarm('PUP Santa Maria').then((_) {
                              debugPrint('[TEST] showArrivalAlarm() completed');
                            });
                          },
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _buildActionRow(
                          iconStr: AppIcons.warning,
                          semanticIcon: Icons.bug_report_rounded,
                          iconBg: const Color(0xFFFFDAD8),
                          iconColor: AppColors.primary,
                          title: 'TEST SIMPLE HEADS-UP',
                          onTap: () {
                            debugPrint('[TEST-SIMPLE] Showing simple max-priority notification');
                            NotificationService().showSimpleTestNotification().then((_) {
                              debugPrint('[TEST-SIMPLE] Notification show() completed');
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Lisko v1.0.0 • PUP Santa Maria Campus',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.body,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Zero-Surveillance Architecture � Offline-First',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.body,
        letterSpacing: 1.1,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String iconStr,
    required IconData semanticIcon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(
              child: AppIcon.badge(iconStr, color: iconColor, semanticIcon: semanticIcon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.header,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.body),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.header,
              ),
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required String iconStr,
    required IconData semanticIcon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Center(
                child: AppIcon.badge(iconStr, color: iconColor, semanticIcon: semanticIcon),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.header,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.body,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.body),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String iconStr,
    required IconData semanticIcon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(
              child: AppIcon.badge(iconStr, color: iconColor, semanticIcon: semanticIcon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.header,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.body,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      child: CustomPaint(
        painter: const HomeHeaderPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const AppIcon.standard(
                    AppIcons.settings,
                    color: Colors.white,
                    semanticIcon: Icons.settings_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Settings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Lisko Preferences & Diagnostics',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SetHomeGeofenceModal extends StatefulWidget {
  const SetHomeGeofenceModal({
    super.key,
    this.currentLat,
    this.currentLng,
    required this.onSaved,
  });

  final double? currentLat;
  final double? currentLng;
  final void Function(double, double) onSaved;

  @override
  State<SetHomeGeofenceModal> createState() => _SetHomeGeofenceModalState();
}

class _SetHomeGeofenceModalState extends State<SetHomeGeofenceModal> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.currentLat?.toString() ?? '');
    _lngController = TextEditingController(text: widget.currentLng?.toString() ?? '');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat != null && lng != null) {
      widget.onSaved(lat, lng);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid coordinates.')),
      );
    }
  }

  void _useCurrentGPS() {
    // Mocking a current GPS fetch for demonstration purposes
    setState(() {
      _latController.text = '14.8512';
      _lngController.text = '120.9856';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Home Geofence',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.header,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Auto-arrival trigger at home',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _useCurrentGPS,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: const Text('Use Current GPS Location'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Coordinates',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

class InfoModalBottomSheet extends StatelessWidget {
  const InfoModalBottomSheet({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.body),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
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


