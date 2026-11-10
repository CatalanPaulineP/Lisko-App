import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/local_storage_service.dart';
import 'package:flutter_app/screens/trips_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip History Extension & Badge Display Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'LocalStorageService saveActiveTrip and readActiveTrip persist wasExtended flag',
      () async {
        const storage = LocalStorageService();

        await storage.saveActiveTrip(
          isActive: true,
          destination: 'Campus',
          tripId: 'trip_101',
          wasExtended: true,
        );

        final activeData = await storage.readActiveTrip();
        expect(activeData, isNotNull);
        expect(activeData!['wasExtended'], isTrue);

        await storage.saveActiveTrip(
          isActive: true,
          destination: 'Campus',
          tripId: 'trip_101',
          isArrived: true,
        );

        final updatedData = await storage.readActiveTrip();
        expect(updatedData!['wasExtended'], isTrue);
      },
    );

    test(
      'TripRecord JSON serialization and deserialization preserves wasExtended flag',
      () {
        final trip = TripRecord(
          id: 'trip_202',
          destination: 'Home',
          durationMinutes: 45,
          status: 'Need Help',
          timestamp: DateTime(2026, 3, 30, 10, 0),
          wasExtended: true,
        );

        final json = trip.toJson();
        expect(json['wasExtended'], isTrue);

        final restored = TripRecord.fromJson(json);
        expect(restored.wasExtended, isTrue);
        expect(restored.status, 'Need Help');
      },
    );

    test('Legacy TripRecord missing wasExtended defaults to false cleanly', () {
      final legacyJson = {
        'id': 'legacy_1',
        'destination': 'School',
        'durationMinutes': 30,
        'status': 'Arrived Safely',
        'timestamp': '2026-03-30T10:00:00.000',
      };

      final legacyTrip = TripRecord.fromJson(legacyJson);
      expect(legacyTrip.wasExtended, isFalse);
    });

    testWidgets('Scenario 1: Pending timeout renders WARNING badge only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripListItem(
              title: 'Campus',
              subtitle: 'Nov 10, 2026 • 10:00 AM',
              durationOrSos: 'Duration: 45 mins',
              status: 'WARNING',
              badgeBgColor: Color(0xFFFEF3C7),
              badgeTextColor: Color(0xFFD97706),
              wasExtended: false,
              hasAlertChip: false,
            ),
          ),
        ),
      );

      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('ALERT'), findsNothing);
      expect(find.text('+15 MIN'), findsNothing);
    });

    testWidgets(
      'Scenario 2: Final expired trip with escalation renders ALERT chip + EXPIRED badge',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'EXPIRED',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: false,
                hasAlertChip: true,
              ),
            ),
          ),
        );

        expect(find.text('ALERT'), findsOneWidget);
        expect(find.text('EXPIRED'), findsOneWidget);
        expect(find.text('+15 MIN'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 3: Expired trip without escalation indicator renders EXPIRED badge only',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'EXPIRED',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: false,
                hasAlertChip: false,
              ),
            ),
          ),
        );

        expect(find.text('EXPIRED'), findsOneWidget);
        expect(find.text('ALERT'), findsNothing);
        expect(find.text('+15 MIN'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 4 & 5: Need Help and Manual SOS render ALERT badge without duplicate ALERT chip',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Emergency Alert',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Manual SOS',
                status: 'ALERT',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: false,
                hasAlertChip: true,
              ),
            ),
          ),
        );

        expect(find.text('ALERT'), findsOneWidget); // Suppresses duplicate!
      },
    );

    testWidgets(
      'Scenario 6: Extended then arrived renders +15 MIN chip + ARRIVED badge',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'ARRIVED',
                badgeBgColor: Color(0xFFD1FAE5),
                badgeTextColor: Color(0xFF10B981),
                wasExtended: true,
                hasAlertChip: false,
              ),
            ),
          ),
        );

        expect(find.text('+15 MIN'), findsOneWidget);
        expect(find.text('ARRIVED'), findsOneWidget);
        expect(find.text('ALERT'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 7: Extended then expired with escalation renders +15 MIN + ALERT + EXPIRED',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'EXPIRED',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: true,
                hasAlertChip: true,
              ),
            ),
          ),
        );

        expect(find.text('+15 MIN'), findsOneWidget);
        expect(find.text('ALERT'), findsOneWidget);
        expect(find.text('EXPIRED'), findsOneWidget);
      },
    );

    testWidgets(
      'Scenario 8: Arrival Unconfirmed renders ALERT chip + UNCONFIRMED badge without EXPIRED',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Nov 10, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'UNCONFIRMED',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: false,
                hasAlertChip: true,
              ),
            ),
          ),
        );

        expect(find.text('ALERT'), findsOneWidget);
        expect(find.text('UNCONFIRMED'), findsOneWidget);
        expect(find.text('EXPIRED'), findsNothing);
      },
    );
  });
}
