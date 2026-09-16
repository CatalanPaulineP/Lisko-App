import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/local_storage_service.dart';
import 'app_icon.dart';

/// Card showing current readiness status, primary contact, and default destination.
class SystemReadyCard extends StatefulWidget {
  const SystemReadyCard({
    super.key,
    this.destination = 'Campus (45 min)',
  });

  /// Default trip destination label and estimated duration.
  final String destination;

  @override
  State<SystemReadyCard> createState() => _SystemReadyCardState();
}

class _SystemReadyCardState extends State<SystemReadyCard> {
  String _contactName = 'Loading...';
  String _displayDestination = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    const storage = LocalStorageService();
    final contacts = await storage.readContacts();
    final defaultMins = await storage.readDefaultTravelDuration();
    if (!mounted) return;

    setState(() {
      _displayDestination = 'Campus ($defaultMins min)';
      if (contacts.isEmpty) {
        _contactName = 'No emergency contact set';
      } else {
        final primary = contacts.first;
        _contactName = '${primary.relationship} (${primary.name})';
      }
    });
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
              color: AppColors.success.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'System Ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: CompactDetail(
                  icon: Icons.person_outline_rounded,
                  label: 'Emergency Contact',
                  value: _contactName,
                ),
              ),
              Container(width: 1, height: 46, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: CompactDetail(
                  icon: Icons.location_on_outlined,
                  label: 'Default Destination',
                  value: _displayDestination,
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
    this.iconifyIcon,
  });

  final IconData icon;
  final String label;
  final String value;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
