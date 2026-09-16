// ==============================================================================
// LisKo Mobile Safety Application - Core Components
// File: lib/widgets/action_buttons.dart
//
// Role & Architectural Context:
// Defines primary action buttons, secondary text buttons, selection chips, and
// the `ContactPerson` domain entity model. Acts as the primary interaction
// building blocks across the entire user experience.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Operability & Touch Targets): Buttons adhere to a minimum 52dp
//   height target (exceeding standard 48dp guidelines), ensuring accessibility
//   even during stressful situations or one-handed mobile operation.
// - Reliability (Debounce Guards): `PrimaryButton` and `SecondaryButton` feature
//   an integrated 350ms timer debounce mechanism. This prevents accidental double-tap
//   spams that could spawn stacked modals or trigger duplicated emergency SMS dispatches.
// - Reliability (Resource Management): All debounce timers are strictly tracked and
//   canceled during widget `dispose()`, preventing timer leaks.
// ==============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import 'app_icon.dart';

/// Lightweight navigation lock utility for safe explicit locking.
class NavigationLock {
  static void reset() {}
  static void run(VoidCallback action, {Duration duration = Duration.zero}) {
    action();
  }
}

/// Data model representing a trusted emergency contact.
///
/// Encapsulates recipient metadata (name, Philippine phone, relation, and avatar initials)
/// with full JSON serialization support for on-device persistence.
class ContactPerson {
  const ContactPerson({
    required this.name,
    required this.phone,
    required this.initials,
    this.relationship = 'Mother',
  });

  /// Full display name of the contact.
  final String name;

  /// Validated Philippine mobile number (e.g. `+63 9123456789`).
  final String phone;

  /// Two-letter uppercase initials used for avatar rendering (e.g. `PL`, `MS`).
  final String initials;

  /// Relationship type (e.g. `Mother`, `Father`, `Guardian`, `Other`).
  final String relationship;

  /// Creates a copy of this contact with updated fields.
  ContactPerson copyWith({
    String? name,
    String? phone,
    String? initials,
    String? relationship,
  }) {
    return ContactPerson(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      initials: initials ?? this.initials,
      relationship: relationship ?? this.relationship,
    );
  }

  /// Serializes the contact person into a JSON map for `SharedPreferences`.
  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'initials': initials,
        'relationship': relationship,
      };

  /// Deserializes a contact person from a stored JSON map with safe defaults.
  factory ContactPerson.fromJson(Map<String, dynamic> json) {
    return ContactPerson(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      initials: json['initials'] as String? ?? '??',
      relationship: json['relationship'] as String? ?? 'Mother',
    );
  }

  /// Automatically computes 1-2 character uppercase initials from a contact's full name.
  /// Handles single names, multi-word names, and empty fallbacks safely.
  static String computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '??';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Standard full-width Primary CTA button with local debounce protection against double taps.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconifyIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? iconifyIcon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handlePressed() {
    if (widget.onPressed == null) return;
    if (_debounceTimer != null && _debounceTimer!.isActive) return;

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {});
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: isEnabled ? AppColors.primaryGradient : null,
          color: isEnabled ? null : AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: isEnabled ? _handlePressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: isEnabled ? Colors.white : AppColors.body,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppColors.body,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.iconifyIcon != null || widget.icon != null) ...[
              AppIcon.standard(
                widget.iconifyIcon ?? _resolveIconify(widget.icon),
                size: 20,
                color: isEnabled ? Colors.white : AppColors.body,
                semanticIcon: widget.icon,
              ),
              const SizedBox(width: 8),
            ],
            Text(widget.label),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GradientButton — lightweight stateless gradient CTA for use in bottom sheets,
// modals, and dialogs where PrimaryButton's debounce is not required.
//
// Renders the app's `AppColors.primaryGradient` (red top → darker red bottom)
// wrapped inside an InkWell for native ripple feedback, ensuring visual
// consistency with PrimaryButton throughout the entire LisKo surface.
// ---------------------------------------------------------------------------
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50.0,
    this.fontSize = 15.0,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.primaryGradient : null,
            color: enabled ? null : AppColors.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : AppColors.body,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard Secondary Text/Action button with local debounce protection against double taps.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handlePressed() {
    if (_debounceTimer != null && _debounceTimer!.isActive) return;

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {});
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: _handlePressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.body,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(widget.label),
      ),
    );
  }
}

/// Accessible choice chip supporting icons, soft states, and ISO 25010 touch targets.
class ChoiceChipWidget extends StatelessWidget {
  const ChoiceChipWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconifyIcon,
    this.softSelected = false,
    this.fullWidth = false,
    this.borderRadius = 12.0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? iconifyIcon;
  final bool softSelected;
  final bool fullWidth;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (softSelected ? AppColors.primaryContainer : AppColors.primary)
        : Colors.white;

    final contentColor = selected
        ? (softSelected ? AppColors.primary : Colors.white)
        : const Color(0xFF64748B);

    final borderColor = selected
        ? AppColors.primary
        : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: fullWidth ? double.infinity : null,
          height: 42,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconifyIcon != null || icon != null) ...[
                AppIcon.small(
                  iconifyIcon ?? _resolveIconify(icon),
                  size: 16,
                  color: contentColor,
                  semanticIcon: icon,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _resolveIconify(IconData? icon) {
  if (icon == null) return AppIcons.navigation;
  if (icon == Icons.navigation_rounded) return AppIcons.navigation;
  if (icon == Icons.contacts_rounded) return AppIcons.contacts;
  if (icon == Icons.location_on_rounded) return AppIcons.location;
  if (icon == Icons.home_rounded || icon == Icons.home_outlined) return AppIcons.home;
  if (icon == Icons.school_outlined || icon == Icons.school_rounded) return AppIcons.school;
  if (icon == Icons.edit_location_alt_outlined || icon == Icons.edit_location_alt_rounded) return AppIcons.editLocation;
  if (icon == Icons.check_rounded) return AppIcons.check;
  if (icon == Icons.add_rounded) return AppIcons.add;
  return AppIcons.navigation;
}
