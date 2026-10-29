import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/local_storage_service.dart';
import 'package:flutter_app/screens/trips_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip History Extension Tracking Bug Fix Tests', () {
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

        // Verify that calling saveActiveTrip without passing wasExtended retains wasExtended == true
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

    testWidgets(
      'TripListItem renders +15 MIN tag when trip was extended alongside ALERT or ARRIVED',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Mar 30, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'ALERT',
                badgeBgColor: Color(0xFFFFDAD8),
                badgeTextColor: Color(0xFFDB2B38),
                wasExtended: true,
              ),
            ),
          ),
        );

        expect(find.text('+15 MIN'), findsOneWidget);
        expect(find.text('ALERT'), findsOneWidget);
      },
    );

    testWidgets(
      'TripListItem does NOT render redundant +15 MIN tag when status is already EXTENDED',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripListItem(
                title: 'Campus',
                subtitle: 'Mar 30, 2026 • 10:00 AM',
                durationOrSos: 'Duration: 45 mins',
                status: 'EXTENDED',
                badgeBgColor: Color(0xFFFEF3C7),
                badgeTextColor: Color(0xFFD97706),
                wasExtended: true,
              ),
            ),
          ),
        );

        expect(find.text('+15 MIN'), findsNothing);
        expect(find.text('EXTENDED'), findsOneWidget);
      },
    );
  });
}
