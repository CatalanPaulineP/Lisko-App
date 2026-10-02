// ==============================================================================
// Lisko Mobile Safety Application - All Notifications Screen
// File: lib/screens/all_notifications_screen.dart
//
// Role & Architectural Context:
// Full history view (`AllNotificationsScreen`) presenting complete student
// travel alerts and safety logs grouped by category chips ('All', 'Emergency Alerts',
// 'Safe Arrivals') and date section ('RECENT' vs 'EARLIER').
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../widgets/notifications_popover.dart';

/// Screen displaying the complete log of user notifications with category filter chips.
class AllNotificationsScreen extends StatefulWidget {
  const AllNotificationsScreen({
    super.key,
    required this.todayNotifications,
    required this.earlierNotifications,
    required this.onItemTap,
  });

  final List<AppNotificationItem> todayNotifications;
  final List<AppNotificationItem> earlierNotifications;
  final ValueChanged<String> onItemTap;

  @override
  State<AllNotificationsScreen> createState() => _AllNotificationsScreenState();
}

class _AllNotificationsScreenState extends State<AllNotificationsScreen> {
  String _selectedFilter = 'All';

  bool _matchesFilter(AppNotificationItem item, String filter) {
    if (filter == 'All') return true;

    final titleLower = item.title.toLowerCase();
    final messageLower = item.message.toLowerCase();

    final isArrival = titleLower.contains('safe') ||
        titleLower.contains('arrival') ||
        titleLower.contains('arrived') ||
        item.icon == Icons.check_circle_rounded;

    final isEmergency = titleLower.contains('emergency') ||
        titleLower.contains('sos') ||
        titleLower.contains('timeout') ||
        messageLower.contains('sos') ||
        messageLower.contains('timeout') ||
        item.icon == Icons.warning_rounded;

    if (filter == 'Emergency Alerts') {
      if (isArrival) return false;
      return isEmergency || (titleLower.contains('alert') && !titleLower.contains('safe'));
    }

    if (filter == 'Safe Arrivals') {
      return isArrival;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filteredToday = widget.todayNotifications
        .where((item) => _matchesFilter(item, _selectedFilter))
        .toList();

    final filteredEarlier = widget.earlierNotifications
        .where((item) => _matchesFilter(item, _selectedFilter))
        .toList();

    final bool isEmpty = filteredToday.isEmpty && filteredEarlier.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.header),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.header,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips Row
          _buildFilterChips(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Main Notifications List / Empty State
          Expanded(
            child: isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (filteredToday.isNotEmpty) ...[
                          _buildSectionHeader('RECENT'),
                          const SizedBox(height: 8),
                          _buildContainerCard(filteredToday),
                          const SizedBox(height: 24),
                        ],
                        if (filteredEarlier.isNotEmpty) ...[
                          _buildSectionHeader('EARLIER'),
                          const SizedBox(height: 8),
                          _buildContainerCard(filteredEarlier),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const options = ['All', 'Emergency Alerts', 'Safe Arrivals'];

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(
          children: options.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Material(
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      filter,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String titleText = 'No notifications yet';
    String subtitleText = 'Safety logs and travel alerts will appear here.';
    IconData icon = Icons.notifications_off_outlined;

    if (_selectedFilter == 'Emergency Alerts') {
      titleText = 'No emergency alerts recorded';
      subtitleText = 'Manual SOS and safety check timeout alerts will appear here.';
      icon = Icons.warning_amber_rounded;
    } else if (_selectedFilter == 'Safe Arrivals') {
      titleText = 'No safe arrivals recorded';
      subtitleText = 'Safe arrival confirmations will appear here.';
      icon = Icons.check_circle_outline_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              titleText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.header,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildContainerCard(List<AppNotificationItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            NotificationTile(
              item: items[i],
              onTap: () => widget.onItemTap(items[i].id),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}
