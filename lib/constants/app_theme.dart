// ==============================================================================
// LisKo Mobile Safety Application - Core Constants
// File: lib/constants/app_theme.dart
//
// Role & Architectural Context:
// Global Material 3 application theme configuration. Establishes the centralized
// typographic hierarchy, color scheme mappings, and surface backgrounds for all
// Flutter widgets in the app.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Readability & Typographic Hierarchy): Utilizes Plus Jakarta Sans
//   for bold, easily scannable headers and Inter for dense, highly legible body
//   and status text, ensuring clarity during high-stress emergency interactions.
// - Usability (Consistent Styling): Unifies Material 3 surfaces to AppColors.canvas
//   (#F8FAFC) preventing jarring white/grey background mismatches across route transitions.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// App theme configuration adhering to ISO/IEC 25010 design token hierarchy.
abstract final class AppTheme {
  /// Builds and returns the default Material 3 light theme for the LisKo application.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.canvas,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
      ),
      // Typographic hierarchy: Plus Jakarta Sans for titles/headers; Inter for body copy
      textTheme: TextTheme(
        // High-impact main screen titles (e.g., Welcome headline)
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.header,
        ),
        // Screen titles and modal primary headers (e.g., "Trip in Progress")
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.header,
        ),
        // Section card headers (e.g., "Set Trip Timer", "Phone Contacts")
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.header,
        ),
        // Card sub-headers and button labels
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.header,
        ),
        // Primary narrative body text
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.body,
        ),
        // Secondary description and caption text
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.body,
        ),
        // Minor footnotes and disclaimer labels
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.body,
        ),
        // Action button text and chip selectors
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.header,
        ),
      ),
    );
  }
}
