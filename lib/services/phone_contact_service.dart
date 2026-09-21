// ==============================================================================
// Lisko Mobile Safety Application - Phone Contacts Service
// File: lib/services/phone_contact_service.dart
//
// Role & Architectural Context:
// Service for interacting with device contacts using the `flutter_contacts` package.
// Responsible for fetching, filtering, and normalizing phone contacts for the
// Lisko-styled import flow.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Functional Suitability & Privacy: Accesses contacts only when explicitly
//   granted by the user. Does not store or transmit the contact list.
// - Usability: Provides real-time filtering and sorting to help users find
//   emergency contacts quickly.
// ==============================================================================

import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:developer' as developer;

class PhoneContactService {
  /// Fetches all contacts from the device that have at least one phone number.
  /// Contacts are sorted by name for better usability.
  Future<List<Contact>> fetchContacts() async {
    try {
      // Request permission if not already granted.
      // Note: permission_handler is used in the UI for consistent UX, 
      // but flutter_contacts handles its own request logic as a fallback.
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        return [];
      }

      // Fetch contacts with properties (phones, etc.)
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // We use initials for performance and Lisko style
      );

      // Filter for contacts that have phone numbers
      final validContacts = contacts.where((c) => c.phones.isNotEmpty).toList();

      // Sort alphabetically by display name
      validContacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      return validContacts;
    } catch (e, st) {
      developer.log('Failed to fetch phone contacts', error: e, stackTrace: st);
      return [];
    }
  }

  /// Filters a list of contacts by a search query (name).
  List<Contact> filterContacts(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;
    final normalizedQuery = query.toLowerCase();
    return contacts.where((c) => c.displayName.toLowerCase().contains(normalizedQuery)).toList();
  }

  /// Normalizes a phone number to meet Lisko's typical 10-digit requirements if possible.
  /// This helps keep the stored numbers consistent.
  static String normalizePhoneNumber(String phone) {
    // Remove non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // Handle Philippine specific formats if detected
    if (digits.startsWith('09') && digits.length == 11) {
      return '+63 ${digits.substring(1)}';
    } else if (digits.startsWith('639') && digits.length == 12) {
      return '+63 ${digits.substring(2)}';
    } else if (digits.startsWith('9') && digits.length == 10) {
      return '+63 $digits';
    }

    // Fallback: return digits if it looks like a standard length, 
    // otherwise preserve original if too short or complex
    if (digits.length >= 7) {
      return phone; 
    }
    
    return phone;
  }
}
