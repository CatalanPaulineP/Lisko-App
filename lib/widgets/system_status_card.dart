// ==============================================================================
// LisKo Mobile Safety Application - Dashboard Components
// File: lib/widgets/system_status_card.dart
//
// Role & Architectural Context:
// High-level status summary card displayed on the Home Tab dashboard. Reassures
// the user at a single glance that emergency SMS dispatch, trusted contacts,
// and default trip destinations are configured and ready.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (User Reassurance & Status Visibility): Provides clear visual feedback
//   using an emerald "System Ready" pill badge, reinforcing peace of mind.
// - Usability (Information Scannability): Employs a dual-column layout dividing
//   Primary Emergency Contact and Default Destination with a crisp divider line.
// ==============================================================================

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import 'app_icon.dart';

/// Card showing current readiness status, primary contact, and default destination.
class SystemReadyCard extends StatelessWidget {
  const SystemReadyCard({
    super.key,
    this.contactName = 'Mom (Maria Santos)',
    this.destination = 'Campus (45 min)',
  });

  /// Contact name and relationship summary to display.
  final String contactName;

  /// Default trip destination label and estimated duration.
  final String destination;

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
                  value: contactName,
                ),
              ),
              Container(width: 1, height: 46, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: CompactDetail(
                  icon: Icons.location_on_outlined,
                  label: 'Default Destination',
                  value: destination,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon.small(
              effectiveIconify,
              size: 16,
              color: AppColors.primary,
              semanticIcon: icon,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.body),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.header,
          ),
        ),
      ],
    );
  }
}
