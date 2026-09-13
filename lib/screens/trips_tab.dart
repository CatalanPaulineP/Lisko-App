// ==============================================================================
// LisKo Mobile Safety Application - Trip History & Metrics
// File: lib/screens/trips_tab.dart
//
// Role & Architectural Context:
// Commute history dashboard view (`TripsTab`). Displays the student's historical
// travel logs, aggregate monthly safety metrics, trip filter chips, and interactive
// sorting modals.
//
// 4-Column Segmented Metrics Card Design:
// Consolidates monthly travel analytics into a single rounded card with colored status segments:
// 1. Total Trips: Pure white `#FFFFFF` segment with bold `#1E293B` count.
// 2. Safe / Completed: Light mint `#D1FAE5` segment with emerald `#10B981` count.
// 3. Extended: Soft amber `#FEF3C7` segment with golden `#D97706` count.
// 4. Alerts Triggered: Soft crimson `#FFDAD8` segment with brand red `#DB2B38` count.
//
// Filter System & Modal Architecture:
// - Time Horizon Chips: Rapidly toggle between `[ All ]`, `[ This Week ]`, and `[ This Month ]`.
// - Section Filter Icon: Opens `_showSortBottomSheet` allowing students to filter
//   by specific commute outcome (All, Safe, Extended, Alerts).
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Visual Density & Zero-Overflow): Compact header padding (16dp vertical)
//   and fluid horizontal cards prevent vertical scrolling overflows on devices with
//   lower screen resolutions (Vivo Y11).
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../widgets/app_icon.dart';
import 'home_tab.dart';

/// Tab displaying the user's trip history, metrics summary, and past trip log.
class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  String _selectedFilter = 'All';

  void _showSortBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
              const SizedBox(height: 16),
              Text(
                'Filter Trips',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const AppIcon.small(AppIcons.map, color: AppColors.header),
                title: const Text('All Trips'),
                trailing: _selectedFilter == 'All'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = 'All');
                },
              ),
              ListTile(
                leading: const AppIcon.small(AppIcons.checkCircle, color: Color(0xFF10B981)),
                title: const Text('Safe / Completed Only'),
                trailing: _selectedFilter == 'Completed'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = 'Completed');
                },
              ),
              ListTile(
                leading: const AppIcon.small(AppIcons.schedule, color: Color(0xFFD97706)),
                title: const Text('Extended Only'),
                trailing: _selectedFilter == 'Extended'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = 'Extended');
                },
              ),
              ListTile(
                leading: const AppIcon.small(AppIcons.warning, color: Color(0xFFDB2B38)),
                title: const Text('Alerts Only'),
                trailing: _selectedFilter == 'Alert'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = 'Alert');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TripsHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                TripFilterChips(
                  selectedFilter: _selectedFilter,
                  onFilterSelected: (filter) => setState(() => _selectedFilter = filter),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RecentTripsSectionHeader(onFilterTap: _showSortBottomSheet),
                      const SizedBox(height: 12),
                      RecentTripsList(filter: _selectedFilter),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal scrollable row of trip filter option chips.
class TripFilterChips extends StatelessWidget {
  const TripFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  static const List<String> filters = ['All', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onFilterSelected(filter),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    filter,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.body,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Header row for the Recent Trips section with section title and filter icon.
class RecentTripsSectionHeader extends StatelessWidget {
  const RecentTripsSectionHeader({super.key, this.onFilterTap});

  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'RECENT TRIPS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.body,
            letterSpacing: 1.1,
          ),
        ),
        IconButton(
          onPressed: onFilterTap,
          tooltip: 'Filter trips',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: const AppIcon.standard(
            AppIcons.filter,
            size: 18,
            color: AppColors.header,
            semanticIcon: Icons.filter_list_rounded,
          ),
        ),
      ],
    );
  }
}

/// Compact header with dark navy background (#1E293B), pattern, and tight balanced metrics card overlap.
class TripsHeader extends StatelessWidget {
  const TripsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 36, // Stops 36px above the bottom of the stack to let the card stick out
          child: CustomPaint(
            painter: const HomeHeaderPatternPainter(),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
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
                        AppIcons.map,
                        color: Colors.white,
                        semanticIcon: Icons.map_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Trip History',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '3 trips recorded this month',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28), // Explicit spacing to perfectly prevent text overlap
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SummaryMetricsCard(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Segmented 4-column metric bar with solid tinted backgrounds and rounded outer corners.
class SummaryMetricsCard extends StatelessWidget {
  const SummaryMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const Row(
        children: [
          Expanded(
            child: MetricSegment(
              value: '3',
              label: 'Total',
              backgroundColor: Colors.white,
              valueColor: AppColors.header,
              labelColor: AppColors.body,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: '1',
              label: 'Safe',
              backgroundColor: Color(0xFFD1FAE5),
              valueColor: Color(0xFF10B981),
              labelColor: AppColors.body,
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: '1',
              label: 'Extended',
              backgroundColor: Color(0xFFFEF3C7),
              valueColor: Color(0xFFD97706),
              labelColor: AppColors.body,
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: '1',
              label: 'Alerts',
              backgroundColor: Color(0xFFFFDAD8),
              valueColor: Color(0xFFDB2B38),
              labelColor: AppColors.body,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single segment in the segmented metrics summary card.
class MetricSegment extends StatelessWidget {
  const MetricSegment({
    super.key,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.valueColor,
    required this.labelColor,
    this.borderRadius,
  });

  final String value;
  final String label;
  final Color backgroundColor;
  final Color valueColor;
  final Color labelColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: labelColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Model representing a recorded trip for display in the recent trips list.
class RecordedTripData {
  const RecordedTripData({
    required this.icon,
    required this.semanticIcon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.isThisWeek,
  });

  final String icon;
  final IconData semanticIcon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String status;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final bool isThisWeek;
}

/// Clean rounded container card listing past trips with status badges.
class RecentTripsList extends StatelessWidget {
  const RecentTripsList({super.key, this.filter = 'All'});

  final String filter;

  static const List<RecordedTripData> allTrips = [
    RecordedTripData(
      icon: AppIcons.check,
      semanticIcon: Icons.check_rounded,
      iconColor: Color(0xFF10B981),
      iconBgColor: Color(0xFFD1FAE5),
      title: 'Campus - Home',
      subtitle: 'June 10 | 50 mins',
      status: 'Completed',
      badgeBgColor: Color(0xFFD1FAE5),
      badgeTextColor: Color(0xFF10B981),
      isThisWeek: true,
    ),
    RecordedTripData(
      icon: AppIcons.schedule,
      semanticIcon: Icons.schedule_rounded,
      iconColor: Color(0xFFD97706),
      iconBgColor: Color(0xFFFEF3C7),
      title: 'Home - Campus',
      subtitle: 'June 08 | 45 mins (+15m)',
      status: 'Extended',
      badgeBgColor: Color(0xFFFEF3C7),
      badgeTextColor: Color(0xFFD97706),
      isThisWeek: true,
    ),
    RecordedTripData(
      icon: AppIcons.warning,
      semanticIcon: Icons.warning_amber_rounded,
      iconColor: Color(0xFFDB2B38),
      iconBgColor: Color(0xFFFFDAD8),
      title: 'Campus - Home',
      subtitle: 'June 05 | 30 mins',
      status: 'Alert',
      badgeBgColor: Color(0xFFFFDAD8),
      badgeTextColor: Color(0xFFDB2B38),
      isThisWeek: false,
    ),
  ];

  List<RecordedTripData> _getFilteredTrips() {
    switch (filter) {
      case 'This Week':
        return allTrips.where((t) => t.isThisWeek).toList();
      case 'This Month':
      case 'All':
        return allTrips;
      case 'Completed':
        return allTrips.where((t) => t.status == 'Completed').toList();
      case 'Extended':
        return allTrips.where((t) => t.status == 'Extended').toList();
      case 'Alert':
        return allTrips.where((t) => t.status == 'Alert').toList();
      default:
        return allTrips;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = _getFilteredTrips();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: trips.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon.standard(
                      AppIcons.map,
                      size: 28,
                      color: AppColors.body,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trips found for this filter',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < trips.length; i++) ...[
                  TripListItem(
                    icon: trips[i].icon,
                    semanticIcon: trips[i].semanticIcon,
                    iconColor: trips[i].iconColor,
                    iconBgColor: trips[i].iconBgColor,
                    title: trips[i].title,
                    subtitle: trips[i].subtitle,
                    status: trips[i].status,
                    badgeBgColor: trips[i].badgeBgColor,
                    badgeTextColor: trips[i].badgeTextColor,
                  ),
                  if (i < trips.length - 1)
                    const Divider(height: 1, thickness: 1, color: AppColors.border),
                ],
              ],
            ),
    );
  }
}

/// Single row item for a recorded trip in the list.
class TripListItem extends StatelessWidget {
  const TripListItem({
    super.key,
    required this.icon,
    required this.semanticIcon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.badgeBgColor,
    required this.badgeTextColor,
  });

  final String icon;
  final IconData semanticIcon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String status;
  final Color badgeBgColor;
  final Color badgeTextColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon.standard(
              icon,
              size: 20,
              color: iconColor,
              semanticIcon: semanticIcon,
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

