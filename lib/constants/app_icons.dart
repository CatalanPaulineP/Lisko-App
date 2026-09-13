// ==============================================================================
// LisKo Mobile Safety Application - Core Constants
// File: lib/constants/app_icons.dart
//
// Role & Architectural Context:
// Centralized vector icon registry utilizing `iconify_flutter` (Carbon &
// MaterialSymbols). Decouples visual icon string identifiers from UI widgets,
// ensuring strict visual consistency, zero duplicate icon assets, and effortless
// global updates.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Recognizability & Consistency): Consistent semantic icons across
//   onboarding, dashboard, and modals eliminate user confusion (e.g., identical
//   chat bubble for SMS across Step 4 and notification permissions).
// - Performance Efficiency (Resource Utilization): SVG vector strings via Iconify
//   avoid shipping heavy raster assets or multiple font files, minimizing APK size
//   and GPU memory footprints on memory-constrained devices (Vivo Y11).
// ==============================================================================

import 'package:iconify_flutter/icons/carbon.dart';
import 'package:iconify_flutter/icons/material_symbols.dart';

/// Centralized design system icon registry using Iconify (Carbon & MaterialSymbols)
/// strictly mapped to LisKo size standards and color tokens.
abstract final class AppIcons {
  // --- Navigation & App Bar ---
  /// Back arrow button for setup scaffolds and secondary navigation screens.
  static const String arrowBack = MaterialSymbols.arrow_back_rounded;

  /// Modal and dialog dismissal 'X' icon.
  static const String close = MaterialSymbols.close_rounded;

  /// Right navigational disclosure indicator for lists and action cards.
  static const String chevronRight = MaterialSymbols.chevron_right_rounded;

  /// Stepper increment button indicator.
  static const String arrowUp = MaterialSymbols.keyboard_arrow_up_rounded;

  /// Stepper decrement button indicator.
  static const String arrowDown = MaterialSymbols.keyboard_arrow_down_rounded;

  // --- Navigation Tabs (Bottom Bar) ---
  /// Home tab active state icon.
  static const String home = MaterialSymbols.home_rounded;

  /// Home tab inactive state icon.
  static const String homeOutline = MaterialSymbols.home_outline_rounded;

  /// Trips tab active state icon.
  static const String map = MaterialSymbols.map_rounded;

  /// Trips tab inactive state icon.
  static const String mapOutline = MaterialSymbols.map_outline_rounded;

  /// Contacts tab active state icon.
  static const String people = MaterialSymbols.group_rounded;

  /// Contacts tab inactive state icon.
  static const String peopleOutline = MaterialSymbols.group_outline_rounded;

  /// Settings tab active state icon.
  static const String settings = MaterialSymbols.settings_rounded;

  /// Settings tab inactive state icon.
  static const String settingsOutline = MaterialSymbols.settings_outline_rounded;

  // --- Prominent Header & Illustration Features (Carbon Unified) ---
  /// Unified notification bell icon across Step 1 and alarm/notification settings (`carbon:notification`).
  static const String notifications = Carbon.notification_filled;

  /// Outline notification bell for subtle indicator states.
  static const String notificationsOutline = Carbon.notification;

  /// Unified location pin icon across Step 5, map references, and GPS settings (`carbon:location`).
  static const String location = Carbon.location_filled;

  /// Outline location pin for destination selector chips.
  static const String locationOutline = Carbon.location;

  /// Unified SMS / messaging chat bubble icon across Step 4, SMS settings, and alerts (`carbon:chat`).
  static const String chat = Carbon.chat;

  /// Alias for SMS chat bubble.
  static const String chatBubble = Carbon.chat;

  /// Alias for SMS chat bubble.
  static const String sms = Carbon.chat;

  /// Official security shield icon representing zero-surveillance safety.
  static const String shield = MaterialSymbols.shield_rounded;

  // --- Actions, Confirmations & Status ---
  /// Dynamic navigation indicator for active trip heading.
  static const String navigation = MaterialSymbols.navigation_rounded;

  /// Simple checkmark confirmation glyph.
  static const String check = MaterialSymbols.check;

  /// Circular success verification badge glyph.
  static const String checkCircle = MaterialSymbols.check_circle_rounded;

  /// Warning triangle for SOS alert triggers and countdown warnings.
  static const String warning = MaterialSymbols.warning_rounded;

  /// Clock / duration schedule indicator for trip timer settings.
  static const String schedule = MaterialSymbols.schedule_rounded;

  // --- Contact & Profile Management ---
  /// Solid user profile glyph.
  static const String person = MaterialSymbols.person_rounded;

  /// Outline user profile glyph for form input fields.
  static const String personOutline = MaterialSymbols.person_outline_rounded;

  /// Add person icon for contact creation workflows.
  static const String personAdd = MaterialSymbols.person_add_rounded;

  /// Address book / contacts directory icon for import buttons.
  static const String contacts = MaterialSymbols.contacts_rounded;

  /// Solid phone call icon for emergency recipient contact actions.
  static const String phone = MaterialSymbols.call;

  /// Outline phone call icon.
  static const String phoneOutline = MaterialSymbols.call_outline_rounded;

  // --- General Form & Utilities ---
  /// Security padlock glyph for privacy guarantees and encrypted local storage.
  static const String lockOutline = MaterialSymbols.lock_outline;

  /// Informational tooltip and compliance banner icon.
  static const String infoOutline = MaterialSymbols.info_outline_rounded;

  /// Trash bin glyph for removing secondary trusted contacts.
  static const String deleteOutline = MaterialSymbols.delete_outline_rounded;

  /// Generic plus addition glyph.
  static const String add = MaterialSymbols.add_rounded;

  /// Academic graduation cap glyph for Campus destination preset.
  static const String school = MaterialSymbols.school_rounded;

  /// Pencil edit glyph for editing contact details.
  static const String edit = Carbon.edit;

  /// Filter funnel glyph for trip filtering by status.
  static const String filter = Carbon.filter;

  /// Vertical overflow three-dots (`⋮`) glyph for contact options popup menus.
  static const String moreVert = Carbon.overflow_menu_vertical;

  /// User group glyph for trusted contacts directory header.
  static const String group = MaterialSymbols.group_rounded;

  /// Location edit glyph for custom destination input.
  static const String editLocation = MaterialSymbols.edit_location_alt_outline_rounded;

  /// Book / documentation glyph for user guide and safety protocols.
  static const String book = Carbon.book;

  /// Idea / lightbulb glyph for smart adaptive presets.
  static const String idea = Carbon.idea;

  /// Vibration / haptic feedback glyph for timer alert mode settings.
  static const String vibration = MaterialSymbols.vibration_rounded;

  /// Building / campus architecture glyph for campus geofence.
  static const String building = MaterialSymbols.apartment_rounded;
}
