// ==============================================================================
// Lisko Mobile Safety Application - Trip History & Metrics
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
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../widgets/app_icon.dart';
import 'home_tab.dart';

/// Tab displaying the user's trip history, metrics summary, and past trip log.
class TripsTab extends StatefulWidget {
  const TripsTab({super.key, this.onStartNewTrip});

  final VoidCallback? onStartNewTrip;

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> with AutomaticKeepAliveClientMixin {
  String _selectedFilter = 'All';
  String _selectedTimeFilter = 'All';
  late final Stream<List<TripRecord>> _tripsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tripsStream = FirebaseService().getTripsStream();
  }

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
                leading: const AppIcon.small(AppIcons.checkCircle, color: Color(0xFF10B981)),
                title: const Text('Safe / Completed Only'),
                trailing: _selectedFilter == 'Completed' ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = _selectedFilter == 'Completed' ? 'All' : 'Completed');
                },
              ),
              ListTile(
                leading: const Icon(Icons.update_rounded, color: Color(0xFFD97706)),
                title: const Text('Extended Only'),
                trailing: _selectedFilter == 'Extended' ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = _selectedFilter == 'Extended' ? 'All' : 'Extended');
                },
              ),
              ListTile(
                leading: const AppIcon.small(AppIcons.warning, color: AppColors.primary),
                title: const Text('Alerts Triggered'),
                trailing: _selectedFilter == 'Alert' ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedFilter = _selectedFilter == 'Alert' ? 'All' : 'Alert');
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
    super.build(context);
    return StreamBuilder<List<TripRecord>>(
      stream: _tripsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final trips = snapshot.data ?? [];
        final now = DateTime.now();

        final timeFilteredTrips = trips.where((t) {
          if (_selectedTimeFilter == 'This Week') {
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
            return t.timestamp.isAfter(startOfWeekMidnight.subtract(const Duration(milliseconds: 1)));
          } else if (_selectedTimeFilter == 'This Month') {
            return t.timestamp.year == now.year && t.timestamp.month == now.month;
          }
          return true;
        }).toList();

        final safeCount = timeFilteredTrips.where((t) => t.status.toLowerCase() == 'completed' || t.status.toLowerCase() == 'arrived').length;
        final extendedCount = timeFilteredTrips.where((t) => t.status.toLowerCase() == 'extended').length;
        final alertsCount = timeFilteredTrips.where((t) => t.status.toLowerCase() == 'alert' || t.status.toLowerCase() == 'expired' || t.status.toLowerCase() == 'help_requested').length;

        final filteredTrips = timeFilteredTrips.where((t) {
          if (_selectedFilter == 'Completed') return t.status.toLowerCase() == 'completed' || t.status.toLowerCase() == 'arrived';
          if (_selectedFilter == 'Extended') return t.status.toLowerCase() == 'extended';
          if (_selectedFilter == 'Alert') return t.status.toLowerCase() == 'alert' || t.status.toLowerCase() == 'expired' || t.status.toLowerCase() == 'help_requested';
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripsHeader(
              tripCount: timeFilteredTrips.length,
              safeCount: safeCount,
              extendedCount: extendedCount,
              alertsCount: alertsCount,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    TripFilterChips(
                      selectedFilter: _selectedTimeFilter,
                      onFilterSelected: (filter) =>
                          setState(() => _selectedTimeFilter = filter),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      RecentTripsSectionHeader(
                        onFilterTap: _showSortBottomSheet,
                      ),
                      const SizedBox(height: 12),
                      RecentTripsList(
                        filter: _selectedFilter,
                        trips: filteredTrips,
                        isLoading: snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData,
                        onStartNewTrip: widget.onStartNewTrip,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
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
  const TripsHeader({
    super.key,
    required this.tripCount,
    required this.safeCount,
    required this.extendedCount,
    required this.alertsCount,
  });

  final int tripCount;
  final int safeCount;
  final int extendedCount;
  final int alertsCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom:
              36, // Stops 36px above the bottom of the stack to let the card stick out
          child: CustomPaint(painter: const HomeHeaderPatternPainter()),
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
                          '$tripCount trip${tripCount == 1 ? '' : 's'} recorded',
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
            const SizedBox(
              height: 28,
            ), // Explicit spacing to perfectly prevent text overlap
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SummaryMetricsCard(
                total: tripCount,
                safe: safeCount,
                extended: extendedCount,
                alerts: alertsCount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Segmented 4-column metric bar with solid tinted backgrounds and rounded outer corners.
class SummaryMetricsCard extends StatelessWidget {
  const SummaryMetricsCard({
    super.key,
    required this.total,
    required this.safe,
    required this.extended,
    required this.alerts,
  });

  final int total;
  final int safe;
  final int extended;
  final int alerts;

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
      child: Row(
        children: [
          Expanded(
            child: MetricSegment(
              value: total.toString(),
              label: 'Total',
              backgroundColor: Colors.white,
              valueColor: AppColors.header,
              labelColor: AppColors.body,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: safe.toString(),
              label: 'Safe',
              backgroundColor: const Color(0xFFD1FAE5),
              valueColor: const Color(0xFF10B981),
              labelColor: AppColors.body,
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: extended.toString(),
              label: 'Extended',
              backgroundColor: const Color(0xFFFEF3C7),
              valueColor: const Color(0xFFD97706),
              labelColor: AppColors.body,
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: alerts.toString(),
              label: 'Alerts',
              backgroundColor: const Color(0xFFFFDAD8),
              valueColor: const Color(0xFFDB2B38),
              labelColor: AppColors.body,
              borderRadius: const BorderRadius.only(
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
class RecentTripsList extends StatelessWidget {
  const RecentTripsList({
    super.key,
    this.filter = 'All',
    required this.trips,
    required this.isLoading,
    this.onStartNewTrip,
  });

  final String filter;
  final List<TripRecord> trips;
  final bool isLoading;
  final VoidCallback? onStartNewTrip;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
                    const SizedBox(height: 12),
                    Text(
                      'No trips found',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
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
                  Builder(
                    builder: (context) {
                      final trip = trips[i];
                      // Dynamic styling based on status
                      String iconStr;
                      IconData semIcon;
                      Color iColor;
                      Color iBgColor;
                      Color bBgColor;
                      Color bTextColor;

                      if (trip.status == 'Completed' || trip.status.toLowerCase() == 'arrived') {
                        iconStr = AppIcons.check;
                        semIcon = Icons.check_rounded;
                        iColor = const Color(0xFF10B981);
                        iBgColor = const Color(0xFFD1FAE5);
                        bBgColor = const Color(0xFFD1FAE5);
                        bTextColor = const Color(0xFF10B981);
                      } else if (trip.status == 'Alert' || trip.status.toLowerCase() == 'expired' || trip.status.toLowerCase() == 'help_requested') {
                        iconStr = AppIcons.warning;
                        semIcon = Icons.warning_amber_rounded;
                        iColor = const Color(0xFFDB2B38);
                        iBgColor = const Color(0xFFFFDAD8);
                        bBgColor = const Color(0xFFFFDAD8);
                        bTextColor = const Color(0xFFDB2B38);
                      } else {
                        iconStr = AppIcons.schedule;
                        semIcon = Icons.schedule_rounded;
                        iColor = const Color(0xFFD97706);
                        iBgColor = const Color(0xFFFEF3C7);
                        bBgColor = const Color(0xFFFEF3C7);
                        bTextColor = const Color(0xFFD97706);
                      }

                      final months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];
                      final dateStr =
                          '${months[trip.timestamp.month - 1]} ${trip.timestamp.day} | ${trip.durationMinutes} mins';

                      return TripListItem(
                        icon: iconStr,
                        semanticIcon: semIcon,
                        iconColor: iColor,
                        iconBgColor: iBgColor,
                        title: trip.destination,
                        subtitle: dateStr,
                        status: trip.status,
                        badgeBgColor: bBgColor,
                        badgeTextColor: bTextColor,
                      );
                    },
                  ),
                  if (i < trips.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
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

