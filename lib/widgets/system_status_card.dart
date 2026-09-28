import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/local_storage_service.dart';
import '../services/permission_service.dart';
import 'app_icon.dart';

/// Card showing current readiness status, primary contact, and default destination.
class SystemReadyCard extends StatefulWidget {
  const SystemReadyCard({
    super.key,
    this.destination = 'Campus',
    this.selectedTab = 0,
  });

  /// Default trip destination label and estimated duration.
  final String destination;

  /// Active tab index in bottom navigation bar to trigger targeted refreshes on return.
  final int selectedTab;

  @override
  State<SystemReadyCard> createState() => _SystemReadyCardState();
}

class _SystemReadyCardState extends State<SystemReadyCard>
    with WidgetsBindingObserver {
  String _contactName = 'Loading...';
  String _contactRel = '';
  String _displayDestination = 'Campus';
  String _displayDuration = '45 min';
  bool _isSystemReady = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant SystemReadyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTab == 0) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    const storage = LocalStorageService();
    final permService = PermissionService();

    final contacts = await storage.readContacts();
    final defaultMins = await storage.readDefaultTravelDuration();

    final notificationsEnabled = await permService.checkNotificationPermission();
    final contactsAdded = contacts.isNotEmpty;
    final smsPermissionGranted = await permService.checkSmsPermission();
    final locationPermissionGranted = await permService.checkLocationPermission();
    final locationServiceEnabled = await permService.isLocationServiceEnabled();

    final allReady = notificationsEnabled &&
        contactsAdded &&
        smsPermissionGranted &&
        locationPermissionGranted &&
        locationServiceEnabled;

    if (!mounted) return;

    final newRel = contacts.isNotEmpty
        ? (contacts.first.relationship.isNotEmpty ? contacts.first.relationship : 'Primary Contact')
        : '';
    final newName = contacts.isNotEmpty ? contacts.first.name : 'No contact set';
    final newDur = '$defaultMins min';

    if (_isSystemReady != allReady ||
        _contactName != newName ||
        _contactRel != newRel ||
        _displayDuration != newDur) {
      setState(() {
        _isSystemReady = allReady;
        _displayDestination = 'Campus';
        _displayDuration = newDur;
        _contactName = newName;
        _contactRel = newRel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _isSystemReady
                  ? AppColors.success.withValues(alpha: 0.13)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _isSystemReady
                          ? AppColors.success
                          : const Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isSystemReady ? 'System Ready' : 'Action Needed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _isSystemReady
                        ? AppColors.successText
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CompactDetail(
                  icon: Icons.person_outline_rounded,
                  label: 'Emergency Contact',
                  value: _contactName,
                  secondaryValue: _contactRel,
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: CompactDetail(
                  icon: Icons.location_on_outlined,
                  label: 'Default Destination',
                  value: _displayDestination,
                  secondaryValue: _displayDuration,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact key-value display item with icon.
class CompactDetail extends StatelessWidget {
  const CompactDetail({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.secondaryValue,
    this.iconifyIcon,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? secondaryValue;
  final String? iconifyIcon;

  @override
  Widget build(BuildContext context) {
    final effectiveIconify = iconifyIcon ??
        (icon == Icons.person_outline_rounded
            ? AppIcons.personOutline
            : AppIcons.locationOutline);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: AppIcon.standard(
            effectiveIconify,
            color: AppColors.body,
            semanticIcon: icon,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
                maxLines: 1,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryValue != null && secondaryValue!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  secondaryValue!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.body,
                  ),
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
