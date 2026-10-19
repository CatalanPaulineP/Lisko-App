// ==============================================================================
// Lisko Mobile Safety Application - SOS Widget Detail Modal
// File: lib/screens/sos_widget_detail_screen.dart
//
// Role & Architectural Context:
// Modal bottom sheet displaying the 2x1 SOS Widget preview, feature breakdown,
// and launcher pinning CTA (`requestPinWidget`).
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/sos_widget_service.dart';

/// Modal bottom sheet displaying the 2x1 SOS Widget preview, feature breakdown, and launcher pin CTA.
class SosWidgetDetailModalBottomSheet extends StatelessWidget {
  const SosWidgetDetailModalBottomSheet({super.key});

  Future<void> _pinWidget(BuildContext context) async {
    final success = await SosWidgetService.requestPinWidget();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Widget request sent. Confirm placement on your Home Screen or use manual setup below.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your launcher requires manual widget setup. Long-press Home Screen -> Widgets -> LisKo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.header,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.88,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home Screen SOS Widget',
                                textScaler: TextScaler.noScaling,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.header,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Add quick access to Emergency SOS from your phone\'s Home Screen.',
                                textAlign: TextAlign.justify,
                                textScaler: TextScaler.noScaling,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.body,
                                  height: 1.35,
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
                    const SizedBox(height: 16),

                    // Preview Section Label
                    Text(
                      'PREVIEW',
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Static Widget Visual Card Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFDAD8), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x29EF4444),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0x33FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EMERGENCY SOS',
                                  textScaler: TextScaler.noScaling,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to alert trusted contacts',
                                  textScaler: TextScaler.noScaling,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFFFDAD8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Explanation Note
                    Text(
                      'Tap the widget from your Home Screen to start the 5-second SOS countdown.',
                      textAlign: TextAlign.justify,
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.body,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Benefits & Protocol Section
                    Text(
                      'KEY BENEFITS & PROTOCOL',
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildBenefitCard(
                      icon: Icons.flash_on_rounded,
                      title: 'Rapid Emergency Access',
                      description: 'Start the SOS countdown directly from your Home Screen without navigating through the main LisKo application.',
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitCard(
                      icon: Icons.timer_rounded,
                      title: '5-Second Safety Buffer',
                      description: 'Provides a 5-second countdown with haptic vibration feedback and an instant 1-tap cancel button to prevent false alarms.',
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitCard(
                      icon: Icons.sms_outlined,
                      title: 'Automatic Location & SMS',
                      description: 'Obtains the device\'s current location and sends a cellular emergency SMS to trusted contacts when the countdown completes.',
                    ),
                    const SizedBox(height: 16),

                    // Pin Button CTA
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _pinWidget(context),
                              icon: const Icon(Icons.add_to_home_screen_rounded, size: 20),
                              label: Text(
                                'Add to Home Screen',
                                textScaler: TextScaler.noScaling,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'If automatic setup isn\'t supported by your launcher, add LisKo manually from your phone\'s Widgets menu.',
                            textAlign: TextAlign.justify,
                            textScaler: TextScaler.noScaling,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.body,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDAD8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  textAlign: TextAlign.justify,
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                    height: 1.35,
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
