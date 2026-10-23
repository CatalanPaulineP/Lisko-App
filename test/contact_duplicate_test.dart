import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/widgets/action_buttons.dart';

void main() {
  group('ContactPerson Phone Number Normalization & Duplicate Comparison', () {
    test('extractPhoneDigits correctly extracts digits for Philippine and standard numbers', () {
      expect(ContactPerson.extractPhoneDigits('+63 917 123 4567'), '9171234567');
      expect(ContactPerson.extractPhoneDigits('09171234567'), '9171234567');
      expect(ContactPerson.extractPhoneDigits('9171234567'), '9171234567');
      expect(ContactPerson.extractPhoneDigits('+639171234567'), '9171234567');
      expect(ContactPerson.extractPhoneDigits('639171234567'), '9171234567');
      expect(ContactPerson.extractPhoneDigits('0918-123-4567'), '9181234567');
    });

    test('isSamePhoneNumber returns true for duplicate numbers despite formatting/prefix differences', () {
      // +63 917 123 4567 vs 09171234567
      expect(
        ContactPerson.isSamePhoneNumber('+63 917 123 4567', '09171234567'),
        isTrue,
      );

      // +63 917 123 4567 vs +639171234567
      expect(
        ContactPerson.isSamePhoneNumber('+63 917 123 4567', '+639171234567'),
        isTrue,
      );

      // 9171234567 vs +63 917 123 4567
      expect(
        ContactPerson.isSamePhoneNumber('9171234567', '+63 917 123 4567'),
        isTrue,
      );

      // 0918-123-4567 vs +63 918 123 4567
      expect(
        ContactPerson.isSamePhoneNumber('0918-123-4567', '+63 918 123 4567'),
        isTrue,
      );
    });

    test('isSamePhoneNumber returns false for genuinely different phone numbers', () {
      expect(
        ContactPerson.isSamePhoneNumber('+63 917 123 4567', '+63 918 123 4567'),
        isFalse,
      );
      expect(
        ContactPerson.isSamePhoneNumber('09171234567', '09171234568'),
        isFalse,
      );
    });
  });
}
