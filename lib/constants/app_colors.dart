// ==============================================================================
// Lisko Mobile Safety Application - Core Constants
// File: lib/constants/app_colors.dart
//
// Role & Architectural Context:
// Global design tokens defining the centralized color palette for the Lisko
// application. Ensures consistent visual identity across onboarding, dashboard,
// trip tracking, contacts, and modal components.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Recognizability & Accessibility): High-contrast pairings between
//   Deep Navy (#1E293B) and Canvas (#F8FAFC) satisfy WCAG 2.1 AA contrast
//   ratios for readability under outdoor daylight conditions.
// - Usability (Visual Clarity & Status Indication): Clear chromatic differentiation
//   between Brand Crimson (urgent/primary), Success Green (safe/ready), and Slate
//   Grey (neutral/inactive) reduces user cognitive load during emergencies.
// ==============================================================================

import 'package:flutter/material.dart';

/// Centralized design tokens establishing the official Lisko color system.
///
/// Designed as an `abstract final class` to prevent instantiation and subclassing,
/// acting purely as a static namespace for compile-time constant colors.
abstract final class AppColors {
  /// Base canvas background: `#F8FAFC` (Slate 50).
  /// Provides an ultra-light, neutral backdrop reducing eye fatigue.
  static const canvas = Color(0xFFF8FAFC);

  /// Official Brand Crimson primary: `#DB2B38`.
  /// Represents urgency, action, and core branding (SOS buttons, active tabs,
  /// primary CTA actions, and alert states).
  static const primary = Color(0xFFDB2B38);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  static const timerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA7F3D0), Color(0xFF10B981)],
  );

  /// Deep Navy header & high-contrast typography: `#1E293B` (Slate 800).
  /// Used for top app bars, primary titles, and high-emphasis textual content.
  static const header = Color(0xFF1E293B);

  /// Medium-emphasis slate body text: `#64748B` (Slate 500).
  /// Used for secondary subtitles, descriptive metadata, and inactive chip labels.
  static const body = Color(0xFF64748B);

  /// Soft crimson container tint: `#FFDAD8`.
  /// Used for subtle emergency badge backgrounds, primary contact pill containers,
  /// and avatar ring accents.
  static const primaryContainer = Color(0xFFFFDAD8);

  /// Semantic Success Green: `#10B981` (Emerald 500).
  /// Used for safe trip statuses, completed checklist badges, and active readiness indicators.
  static const success = Color(0xFF10B981);

  /// Pure surface / card background: `#FFFFFF`.
  /// Provides elevated contrast for interactive cards, sheets, and dialog surfaces.
  static const card = Color(0xFFFFFFFF);

  /// Subtle container and card outline border: `#E2E8F0` (Slate 200).
  /// Delivers crisp card separation without visual clutter.
  static const border = Color(0xFFE2E8F0);

  /// Subtle accent / stepper divider border: `#CBD5E1` (Slate 300).
  /// Used for input field containers, stepper buttons, and inactive chip outlines.
  static const borderSubtle = Color(0xFFCBD5E1);

  /// Success container tint: `#DDF7ED`.
  /// Used for "Safe" metric pill backgrounds and system ready banners.
  static const successContainer = Color(0xFFDDF7ED);

  /// High-contrast success green typography: `#047857` (Emerald 700).
  /// Delivers accessible text contrast on top of light emerald backgrounds.
  static const successText = Color(0xFF047857);
}

