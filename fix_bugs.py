import re
import sys

with open('lib/screens/onboarding_flow.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _confirmDeleteContact to use showDialog instead of showModalBottomSheet
delete_old = """  Future<void> _confirmDeleteContact(ContactPerson contact) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x180F172A),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),"""

delete_new = """  Future<void> _confirmDeleteContact(ContactPerson contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["""

content = content.replace(delete_old, delete_new)

# Also fix the closing of the AlertDialog children:
delete_buttons_old = """                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.body,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {"""

delete_buttons_new = """                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.body,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ),
      ),
    );

    if (confirmed == true && mounted) {"""
content = content.replace(delete_buttons_old, delete_buttons_new)

# Now fix the SelectRelationshipBottomSheet!
# First replace the state class signature and variables.
rel_old = """class _SelectRelationshipBottomSheetState
    extends State<SelectRelationshipBottomSheet> {
  String relationship = 'Mother';

  @override
  Widget build(BuildContext context) {"""

rel_new = """class _SelectRelationshipBottomSheetState
    extends State<SelectRelationshipBottomSheet> {
  String relationship = 'Mother';
  final TextEditingController _customRelationshipController = TextEditingController();

  @override
  void dispose() {
    _customRelationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {"""

content = content.replace(rel_old, rel_new)

# Next, add the custom text field inside the Column, right below RelationshipChips:
chips_old = """            RelationshipChips(
              selected: relationship,
              onChanged: (value) => setState(() => relationship = value),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm & Save Contact',
              iconifyIcon: AppIcons.check,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),"""

chips_new = """            RelationshipChips(
              selected: relationship,
              onChanged: (value) => setState(() => relationship = value),
            ),
            if (relationship == 'Other') ...[
              const SizedBox(height: 16),
              const Text(
                'Specify Relationship',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customRelationshipController,
                decoration: InputDecoration(
                  hintText: 'e.g. Aunt, Uncle, Sibling',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm & Save Contact',
              iconifyIcon: AppIcons.check,
              icon: Icons.check_rounded,
              onPressed: () {
                final finalRel = relationship == 'Other'
                    ? _customRelationshipController.text.trim()
                    : relationship;
                Navigator.pop(
                  context,
                  widget.contact.copyWith(
                    relationship: finalRel.isEmpty ? 'Other' : finalRel,
                  ),
                );
              },
            ),"""

content = content.replace(chips_old, chips_new)

with open('lib/screens/onboarding_flow.dart', 'w', encoding='utf-8') as f:
    f.write(content)

