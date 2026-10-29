import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firestore Security Rules Architectural Specifications', () {
    late String rulesContent;

    setUpAll(() {
      final file = File('firestore.rules');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'firestore.rules file must exist',
      );
      rulesContent = file.readAsStringSync();
    });

    test(
      'firestore.rules requires authenticated user and userId matching in schemas',
      () {
        expect(rulesContent, contains('data.userId == request.auth.uid'));
        expect(rulesContent, contains('function isAuthenticated()'));
        expect(rulesContent, contains('function isOwner(userId)'));
      },
    );

    test('firestore.rules enforces isOwner for trips collection reads', () {
      expect(rulesContent, contains('match /trips/{tripId}'));
      expect(
        rulesContent,
        contains('allow read: if isOwner(resource.data.userId);'),
      );
    });

    test(
      'firestore.rules enforces isOwner for emergency_events collection reads',
      () {
        expect(rulesContent, contains('match /emergency_events/{eventId}'));
        expect(
          rulesContent,
          contains('allow read: if isOwner(resource.data.userId);'),
        );
      },
    );

    test('firestore.rules contains zero unauthenticated public read rules', () {
      expect(rulesContent.contains('allow read: if true;'), isFalse);
    });
  });
}
