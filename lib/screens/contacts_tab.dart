// ==============================================================================
// LisKo Mobile Safety Application - Trusted Contacts Directory
// File: lib/screens/contacts_tab.dart
//
// Role & Architectural Context:
// Emergency contacts management view (`ContactsTab`). Coordinates trusted SMS
// recipients, displays the high-priority Primary Emergency Contact card, renders
// secondary contacts with deletion options, and hosts bottom sheet modals for
// editing, importing, and adding contacts.
//
// State Synchronization & Modal Architecture:
// - SharedPreferences Persistence: Automatically queries `LocalStorageService.readContacts()`
//   on initialization and immediately persists additions, edits, or removals.
// - Primary Emergency Contact Card: Features a soft crimson background (`#FFF2F3`),
//   pill badge indicator, circular avatar with initials, and a three-dots (`⋮`)
//   options menu triggering `EditContactBottomSheet`.
// - Phone Contacts Import: `ImportContactsBottomSheet` presents mock device contacts
//   (Dianne, Elly, ash, Rothen, Rainn) for rapid single-tap contact imports.
// - Add Contact Modal: `AddNewContactBottomSheet` includes Full Name, Relationship chips,
//   and the smart Philippine phone input container (`PhilippinePhoneInputField`) with
//   dynamic button activation upon valid input.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Functional Suitability & Privacy: Zero-surveillance local persistence protects
//   student contact lists from external exposure.
// - Usability: Standardized 48dp minimum interactive touch targets, clear confirmation
//   feedback, and seamless modal transitions without UI overflow.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/local_storage_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/app_icon.dart';
import 'home_tab.dart';
import 'onboarding_flow.dart';

/// Tab displaying the user's trusted contacts directory with real-time state synchronization,
/// primary emergency card, edit popup menu, and modal bottom sheets.
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final LocalStorageService _storage = const LocalStorageService();
  List<ContactPerson> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final loaded = await _storage.readContacts();
    if (mounted) {
      setState(() {
        _contacts = loaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateContacts(List<ContactPerson> updated) async {
    await _storage.saveContacts(updated);
    if (mounted) {
      setState(() => _contacts = updated);
    }
  }

  void _openEditContactModal(ContactPerson contact, int index) {
    showModalBottomSheet<ContactPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditContactBottomSheet(
        contact: contact,
        onSaved: (edited) {
          final updated = List<ContactPerson>.from(_contacts);
          updated[index] = edited;
          _updateContacts(updated);
        },
      ),
    );
  }

  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  Future<void> _openImportModal() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();
      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        final String name = contact.fullName ?? 'Unknown';
        final String phone = contact.phoneNumbers!.first;
        final String initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        final imported = ContactPerson(
          name: name,
          phone: phone,
          initials: initials,
          relationship: 'Other',
        );

        final updated = List<ContactPerson>.from(_contacts);
        if (!updated.any((c) => c.phone == imported.phone)) {
          updated.add(imported);
          _updateContacts(updated);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $name successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact already exists in your trusted list')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to pick contact: $e');
    }
  }

  void _openAddContactModal() {
    showModalBottomSheet<ContactPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddNewContactBottomSheet(
        onAdded: (newContact) {
          final updated = List<ContactPerson>.from(_contacts)..add(newContact);
          _updateContacts(updated);
        },
      ),
    );
  }

  void _removeContact(int index) {
    if (index >= 0 && index < _contacts.length) {
      final updated = List<ContactPerson>.from(_contacts)..removeAt(index);
      _updateContacts(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final primaryContact = _contacts.isNotEmpty
        ? _contacts.first
        : const ContactPerson(
            name: 'Maria Santos',
            phone: '+63 917 123 4567',
            initials: 'MS',
            relationship: 'Mother',
          );

    final secondaryContacts =
        _contacts.length > 1 ? _contacts.sublist(1) : <ContactPerson>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Bar matching image_6c39af.png
        ContactsHeader(
          contactCount: _contacts.length,
          onAddTap: _openAddContactModal,
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary Emergency Recipients Card matching image_6c39af.png
                  PrimaryEmergencyContactCard(
                    contact: primaryContact,
                    onEditTap: () => _openEditContactModal(primaryContact, 0),
                  ),
                  const SizedBox(height: 16),
                  // Outline Import from Contacts Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _openImportModal,
                      icon: const AppIcon.standard(
                        AppIcons.contacts,
                        color: AppColors.header,
                        size: 20,
                        semanticIcon: Icons.contacts_rounded,
                      ),
                      label: Text(
                        'Import from Contacts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.header,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (secondaryContacts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'OTHER TRUSTED CONTACTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.body,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                      child: Column(
                        children: [
                          for (int i = 0; i < secondaryContacts.length; i++) ...[
                            SecondaryContactListItem(
                              contact: secondaryContacts[i],
                              onRemove: () => _removeContact(i + 1),
                            ),
                            if (i < secondaryContacts.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.border,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top Dark Navy App Bar with Group icon, Trusted Contacts title, subtitle, and solid Crimson [+ Add] button.
class ContactsHeader extends StatelessWidget {
  const ContactsHeader({
    super.key,
    required this.contactCount,
    required this.onAddTap,
  });

  final int contactCount;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      child: CustomPaint(
        painter: const HomeHeaderPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                    AppIcons.people,
                    color: Colors.white,
                    semanticIcon: Icons.group_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Trusted Contacts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$contactCount Contacts Active | SMS recipient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: const Key('add_contact_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: onAddTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Add',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary Emergency Contact card with soft crimson tint, pill badge, crimson avatar, and three-dots menu.
class PrimaryEmergencyContactCard extends StatelessWidget {
  const PrimaryEmergencyContactCard({
    super.key,
    required this.contact,
    required this.onEditTap,
  });

  final ContactPerson contact;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0CDB2B38),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Primary Emergency Contact',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.body,
                  size: 20,
                ),
                tooltip: 'Contact options',
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditTap();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.header,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit Contact',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.header,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  contact.initials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.header,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${contact.relationship} | ${contact.phone}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.body,
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
}

/// Secondary contact row item in the list.
class SecondaryContactListItem extends StatelessWidget {
  const SecondaryContactListItem({
    super.key,
    required this.contact,
    required this.onRemove,
  });

  final ContactPerson contact;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDAD8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              contact.initials,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.header,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.relationship} | ${contact.phone}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.body,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove contact',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.body,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit Contact Modal Bottom Sheet matching image_6c410d.png
class EditContactBottomSheet extends StatefulWidget {
  const EditContactBottomSheet({
    super.key,
    required this.contact,
    required this.onSaved,
  });

  final ContactPerson contact;
  final ValueChanged<ContactPerson> onSaved;

  @override
  State<EditContactBottomSheet> createState() => _EditContactBottomSheetState();
}

class _EditContactBottomSheetState extends State<EditContactBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _otherRelController;
  late String _relationship;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);

    // Extract raw 10 digits from existing formatted phone
    final rawDigits = widget.contact.phone.replaceAll(RegExp(r'\D'), '');
    final tenDigits = rawDigits.startsWith('63')
        ? rawDigits.substring(2)
        : rawDigits;
    _phoneController = TextEditingController(text: tenDigits);

    final knownRels = ['Mother', 'Father', 'Guardian'];
    if (knownRels.contains(widget.contact.relationship)) {
      _relationship = widget.contact.relationship;
      _otherRelController = TextEditingController();
    } else {
      _relationship = 'Other';
      _otherRelController =
          TextEditingController(text: widget.contact.relationship);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otherRelController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    setState(() {
      _nameError = name.isEmpty ? 'Contact name is required' : null;
      if (digits.isEmpty) {
        _phoneError = 'Phone number is required';
      } else if (digits.length != 10 || !digits.startsWith('9')) {
        _phoneError = 'Must be a 10-digit number starting with 9';
      } else {
        _phoneError = null;
      }
    });

    if (_nameError != null || _phoneError != null) return;

    final finalRel = _relationship == 'Other'
        ? (_otherRelController.text.trim().isEmpty
            ? 'Other'
            : _otherRelController.text.trim())
        : _relationship;

    final formattedPhone = '+63 $digits';
    final initials = ContactPerson.computeInitials(name);

    widget.onSaved(
      ContactPerson(
        name: name,
        phone: formattedPhone,
        initials: initials,
        relationship: finalRel,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Contact',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.header,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Emergency SMS recipient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.body,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Full Name field
              Text(
                'Full Name',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.body,
                    size: 20,
                  ),
                  errorText: _nameError,
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Relationship selection chips
              Text(
                'Relationship',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              RelationshipChips(
                selected: _relationship,
                onChanged: (val) => setState(() => _relationship = val),
              ),
              if (_relationship == 'Other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _otherRelController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Friend',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.body,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.canvas,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Phone number input
              Text(
                'Phone Number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              PhilippinePhoneInputField(
                controller: _phoneController,
                hasError: _phoneError != null,
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                  }
                },
              ),
              if (_phoneError != null) ...[
                const SizedBox(height: 5),
                Text(
                  _phoneError!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              // Save Changes Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add New Contact Bottom Sheet matching image_6c44f3.png
class AddNewContactBottomSheet extends StatefulWidget {
  const AddNewContactBottomSheet({super.key, required this.onAdded});

  final ValueChanged<ContactPerson> onAdded;

  @override
  State<AddNewContactBottomSheet> createState() =>
      _AddNewContactBottomSheetState();
}

class _AddNewContactBottomSheetState extends State<AddNewContactBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otherRelController = TextEditingController();
  String _relationship = 'Mother';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateInputs);
    _phoneController.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otherRelController.dispose();
    super.dispose();
  }

  void _validateInputs() {
    final name = _nameController.text.trim();
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final valid = name.isNotEmpty && digits.length == 10 && digits.startsWith('9');
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _handleAdd() {
    if (!_isValid) return;

    final name = _nameController.text.trim();
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final finalRel = _relationship == 'Other'
        ? (_otherRelController.text.trim().isEmpty
            ? 'Other'
            : _otherRelController.text.trim())
        : _relationship;

    final formattedPhone = '+63 $digits';
    final initials = ContactPerson.computeInitials(name);

    widget.onAdded(
      ContactPerson(
        name: name,
        phone: formattedPhone,
        initials: initials,
        relationship: finalRel,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Contact',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.header,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Emergency SMS recipient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.body,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Full Name field
              Text(
                'Full Name',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Mom',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.body,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.canvas,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Relationship selection chips
              Text(
                'Relationship',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              RelationshipChips(
                selected: _relationship,
                onChanged: (val) => setState(() => _relationship = val),
              ),
              if (_relationship == 'Other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _otherRelController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Friend',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.body,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.canvas,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Phone number input
              Text(
                'Phone Number',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body,
                ),
              ),
              const SizedBox(height: 8),
              PhilippinePhoneInputField(
                controller: _phoneController,
                hasError: false,
              ),
              const SizedBox(height: 24),
              // Add Contact Action Button (active crimson when valid, grey when disabled)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isValid ? _handleAdd : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? AppColors.primary
                        : const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Add Contact'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Philippine phone number input container with flag prefix, static +63, vertical divider, and zero-blocker.
class PhilippinePhoneInputField extends StatelessWidget {
  const PhilippinePhoneInputField({
    super.key,
    required this.controller,
    this.hasError = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? AppColors.primary : const Color(0xFFE2E8F0),
          width: hasError ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Left Prefix Box: Flag indicator alongside +63 in bold navy
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhilippineFlagIndicator(),
                const SizedBox(width: 8),
                Text(
                  '+63',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.header,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PhilippinePhoneInputFormatter(),
              ],
              onChanged: onChanged,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.header,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: '9XX XXX XXXX',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}


