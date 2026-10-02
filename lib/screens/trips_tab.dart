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
  const TripsTab({
    super.key,
    this.onStartNewTrip,
    this.summaryKey,
    this.filterChipsKey,
    this.calendarIconKey,
  });

  final VoidCallback? onStartNewTrip;
  final GlobalKey? summaryKey;
  final GlobalKey? filterChipsKey;
  final GlobalKey? calendarIconKey;

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> with AutomaticKeepAliveClientMixin {
  String _selectedFilter = 'All';
  String _selectedTimeFilter = 'All';
  DateTime? _selectedCustomDate;
  late final Stream<List<TripRecord>> _tripsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tripsStream = FirebaseService().getTripsStream();
  }

  Future<void> _openCalendarDatePicker() async {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? now,
      firstDate: oneMonthAgo,
      lastDate: now,
      helpText: 'SELECT TRIP DATE (LAST 30 DAYS)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.header,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedCustomDate = picked;
      });
    }
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
          if (_selectedCustomDate != null) {
            return t.timestamp.year == _selectedCustomDate!.year &&
                t.timestamp.month == _selectedCustomDate!.month &&
                t.timestamp.day == _selectedCustomDate!.day;
          }
          if (_selectedTimeFilter == 'This Week') {
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
            return t.timestamp.isAfter(startOfWeekMidnight.subtract(const Duration(milliseconds: 1)));
          } else if (_selectedTimeFilter == 'This Month') {
            return t.timestamp.year == now.year && t.timestamp.month == now.month;
          }
          return true;
        }).toList();

        final safeCount = timeFilteredTrips.where((t) => ['completed', 'arrived', 'arrived safely'].contains(t.status.toLowerCase())).length;
        final extendedCount = timeFilteredTrips.where((t) => t.wasExtended || ['extended', 'trip extended'].contains(t.status.toLowerCase())).length;
        final alertsCount = timeFilteredTrips.where((t) => ['alert', 'expired', 'help_requested', 'manual sos', 'need help', 'timer expired'].contains(t.status.toLowerCase())).length;

        final filteredTrips = timeFilteredTrips.where((t) {
          if (_selectedFilter == 'Completed') return ['completed', 'arrived', 'arrived safely'].contains(t.status.toLowerCase());
          if (_selectedFilter == 'Extended') return t.wasExtended || ['extended', 'trip extended'].contains(t.status.toLowerCase());
          if (_selectedFilter == 'Alert') return ['alert', 'expired', 'help_requested', 'manual sos', 'need help', 'timer expired'].contains(t.status.toLowerCase());
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripsHeader(
              summaryKey: widget.summaryKey,
              tripCount: timeFilteredTrips.length,
              safeCount: safeCount,
              extendedCount: extendedCount,
              alertsCount: alertsCount,
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    TripFilterChips(
                      key: widget.filterChipsKey,
                      selectedFilter: _selectedCustomDate != null ? '' : _selectedTimeFilter,
                      onFilterSelected: (filter) =>
                          setState(() {
                            _selectedTimeFilter = filter;
                            _selectedCustomDate = null;
                          }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      RecentTripsSectionHeader(
                        filterIconKey: widget.calendarIconKey,
                        selectedFilter: _selectedFilter,
                        selectedCustomDate: _selectedCustomDate,
                        onFilterTap: _openCalendarDatePicker,
                        onClearCustomDate: () => setState(() => _selectedCustomDate = null),
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
  const RecentTripsSectionHeader({
    super.key,
    this.onFilterTap,
    this.selectedFilter = 'All',
    this.selectedCustomDate,
    this.onClearCustomDate,
    this.filterIconKey,
  });

  final VoidCallback? onFilterTap;
  final String selectedFilter;
  final DateTime? selectedCustomDate;
  final VoidCallback? onClearCustomDate;
  final GlobalKey? filterIconKey;

  String get _titleText {
    if (selectedCustomDate != null) {
      final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      final m = months[selectedCustomDate!.month - 1];
      return 'TRIPS ON $m ${selectedCustomDate!.day}, ${selectedCustomDate!.year}';
    }
    if (selectedFilter == 'Completed') return 'RECENT TRIPS (ARRIVED)';
    if (selectedFilter == 'Extended') return 'RECENT TRIPS (EXTENDED)';
    if (selectedFilter == 'Alert') return 'RECENT TRIPS (ALERTS)';
    return 'RECENT TRIPS';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              _titleText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.body,
                letterSpacing: 1.1,
              ),
            ),
            if (selectedCustomDate != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClearCustomDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ALL DATES',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.close_rounded, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        IconButton(
          key: filterIconKey,
          onPressed: onFilterTap,
          tooltip: 'Select date from calendar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: Icon(
            Icons.filter_alt_rounded,
            size: 20,
            color: selectedCustomDate != null ? AppColors.primary : AppColors.header,
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
    required this.selectedFilter,
    required this.onFilterChanged,
    this.summaryKey,
  });

  final GlobalKey? summaryKey;
  final int tripCount;
  final int safeCount;
  final int extendedCount;
  final int alertsCount;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

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
                key: summaryKey,
                total: tripCount,
                safe: safeCount,
                extended: extendedCount,
                alerts: alertsCount,
                selectedFilter: selectedFilter,
                onFilterChanged: onFilterChanged,
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
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final int total;
  final int safe;
  final int extended;
  final int alerts;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final isTotalSelected = selectedFilter == 'All';
    final isSafeSelected = selectedFilter == 'Completed';
    final isExtendedSelected = selectedFilter == 'Extended';
    final isAlertsSelected = selectedFilter == 'Alert';

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
      child: Row(
        children: [
          Expanded(
            child: MetricSegment(
              value: total.toString(),
              label: 'Total',
              backgroundColor: Colors.white,
              valueColor: AppColors.header,
              labelColor: AppColors.body,
              isSelected: isTotalSelected,
              onTap: () => onFilterChanged('All'),
              defaultBorderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: safe.toString(),
              label: 'Arrived',
              backgroundColor: const Color(0xFFD1FAE5),
              valueColor: const Color(0xFF10B981),
              labelColor: AppColors.body,
              isSelected: isSafeSelected,
              onTap: () => onFilterChanged(isSafeSelected ? 'All' : 'Completed'),
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: extended.toString(),
              label: 'Extended',
              backgroundColor: const Color(0xFFFEF3C7),
              valueColor: const Color(0xFFD97706),
              labelColor: AppColors.body,
              isSelected: isExtendedSelected,
              onTap: () => onFilterChanged(isExtendedSelected ? 'All' : 'Extended'),
            ),
          ),
          Expanded(
            child: MetricSegment(
              value: alerts.toString(),
              label: 'Alerts',
              backgroundColor: const Color(0xFFFFDAD8),
              valueColor: const Color(0xFFDB2B38),
              labelColor: AppColors.body,
              isSelected: isAlertsSelected,
              onTap: () => onFilterChanged(isAlertsSelected ? 'All' : 'Alert'),
              defaultBorderRadius: const BorderRadius.only(
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
    required this.isSelected,
    required this.onTap,
    this.defaultBorderRadius,
  });

  final String value;
  final String label;
  final Color backgroundColor;
  final Color valueColor;
  final Color labelColor;
  final bool isSelected;
  final VoidCallback onTap;
  final BorderRadius? defaultBorderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = isSelected
        ? BorderRadius.circular(16)
        : (defaultBorderRadius ?? BorderRadius.zero);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: effectiveRadius,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: valueColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
            border: isSelected
                ? Border.all(color: valueColor.withValues(alpha: 0.5), width: 1.5)
                : null,
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: labelColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
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
                      final statusLower = trip.status.toLowerCase();
                      
                      String displayStatus;
                      String displayTitle;
                      String? displayDuration;

                      bool isStandaloneSos = (statusLower == 'alert' && trip.destination == 'Manual SOS') || statusLower == 'manual sos';
                      bool isExpired = statusLower == 'expired' || statusLower == 'timer expired';
                      bool isArrived = ['completed', 'arrived', 'arrived safely'].contains(statusLower);
                      bool isAlert = ['alert', 'help_requested', 'need help'].contains(statusLower);
                      bool isExtended = trip.wasExtended || ['extended', 'trip extended'].contains(statusLower);
                      bool isCancelled = statusLower == 'cancelled';

                      if (isArrived) {
                        displayStatus = 'ARRIVED';
                      } else if (isExpired) {
                        displayStatus = 'EXPIRED';
                      } else if (isStandaloneSos || isAlert) {
                        displayStatus = 'ALERT';
                      } else if (isExtended) {
                        displayStatus = 'EXTENDED';
                      } else if (isCancelled) {
                        displayStatus = 'CANCELLED';
                      } else {
                        displayStatus = trip.status.toUpperCase();
                      }

                      if (isStandaloneSos) {
                        displayTitle = 'Emergency Alert';
                        displayDuration = 'Manual SOS';
                      } else {
                        displayTitle = trip.destination;
                        final mins = trip.durationMinutes;
                        if (mins == 0) {
                           displayDuration = 'Duration: <1 min';
                        } else if (mins < 60) {
                           displayDuration = 'Duration: $mins min${mins > 1 ? 's' : ''}';
                        } else {
                           final hr = mins ~/ 60;
                           final m = mins % 60;
                           displayDuration = 'Duration: $hr hr${hr > 1 ? 's' : ''}${m > 0 ? ' $m min${m > 1 ? 's' : ''}' : ''}';
                        }
                      }

                      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      final h = trip.timestamp.hour;
                      final min = trip.timestamp.minute.toString().padLeft(2, '0');
                      final amPm = h >= 12 ? 'PM' : 'AM';
                      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
                      final displayDate = '${months[trip.timestamp.month - 1]} ${trip.timestamp.day}, ${trip.timestamp.year} • $hour12:$min $amPm';

                      Color bBgColor;
                      Color bTextColor;
                      if (displayStatus == 'ARRIVED') {
                        bBgColor = const Color(0xFFD1FAE5);
                        bTextColor = const Color(0xFF10B981);
                      } else if (displayStatus == 'EXPIRED' || displayStatus == 'ALERT') {
                        bBgColor = const Color(0xFFFFDAD8);
                        bTextColor = const Color(0xFFDB2B38);
                      } else {
                        bBgColor = const Color(0xFFFEF3C7);
                        bTextColor = const Color(0xFFD97706);
                      }

                      return TripListItem(
                        title: displayTitle,
                        subtitle: displayDate,
                        durationOrSos: displayDuration,
                        status: displayStatus,
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
    required this.title,
    required this.subtitle,
    required this.status,
    required this.badgeBgColor,
    required this.badgeTextColor,
    this.durationOrSos,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final String? durationOrSos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.body,
                    ),
                  ),
                ),
                if (durationOrSos != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    durationOrSos!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.body,
                    ),
                  ),
                ]
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
                fontWeight: FontWeight.w800,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

