// ==============================================================================
// Lisko Mobile Safety Application - Notifications Popover Dropdown
// File: lib/widgets/notifications_popover.dart
//
// Role & Architectural Context:
// Interactive notifications popover card anchored to the top-bar notification bell.
// Features upward pointer tail, top-5 recent notifications display,
// unread indicator dots, tap-to-read, and 'View All Notifications' navigation.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Data model representing a single notification item in the popover and history screen.
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.isRead = false,
    this.category = 'system', // 'emergency', 'arrival', 'trip', 'system'
    this.icon = Icons.notifications_rounded,
    this.iconColor = AppColors.primary,
  });

  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final String category;
  final IconData icon;
  final Color iconColor;

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? timeAgo,
    bool? isRead,
    String? category,
    IconData? icon,
    Color? iconColor,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timeAgo: timeAgo ?? this.timeAgo,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}

/// Popover dropdown card anchored directly below the notification bell icon.
class NotificationsPopover extends StatelessWidget {
  const NotificationsPopover({
    super.key,
    required this.todayNotifications,
    required this.earlierNotifications,
    required this.onClose,
    required this.onItemTap,
    required this.onViewAll,
  });

  final List<AppNotificationItem> todayNotifications;
  final List<AppNotificationItem> earlierNotifications;
  final VoidCallback onClose;
  final ValueChanged<String> onItemTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final popoverWidth = (size.width - 32.0).clamp(280.0, 360.0);

    // Combine and limit to top 5 recent notifications
    final allItems = [...todayNotifications, ...earlierNotifications];
    final recentItems = allItems.take(5).toList();

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Upward-pointing arrow pointer aligned with notification bell icon center
              Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: CustomPaint(
                  size: const Size(16, 10),
                  painter: _PopoverArrowPainter(color: Colors.white),
                ),
              ),
              // Main Popover Card Body
              Container(
                width: popoverWidth,
                constraints: BoxConstraints(
                  maxHeight: size.height * 0.70,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2B0F172A),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Notifications',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildUnreadBadge(allItems),
                            ],
                          ),
                          IconButton(
                            onPressed: onClose,
                            tooltip: 'Close notifications',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                    // Notification Lists Container
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('RECENT'),
                            const SizedBox(height: 6),
                            _buildNotificationSection(recentItems),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                    // Footer: View All Notifications
                    InkWell(
                      onTap: onViewAll,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'View All Notifications',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadBadge(List<AppNotificationItem> allItems) {
    final unreadCount = allItems.where((n) => !n.isRead).length;

    if (unreadCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$unreadCount',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
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

  Widget _buildNotificationSection(List<AppNotificationItem> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Center(
          child: Text(
            'No notifications',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            NotificationTile(
              item: items[i],
              onTap: () => onItemTap(items[i].id),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }
}

/// Single notification item tile supporting tap-to-read.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final AppNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  item.icon,
                  size: 18,
                  color: item.iconColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Title, Message & TimeAgo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.timeAgo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            // Unread Indicator Dot
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CustomPainter drawing upward speech-bubble pointer tail.
class _PopoverArrowPainter extends CustomPainter {
  _PopoverArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PopoverArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
