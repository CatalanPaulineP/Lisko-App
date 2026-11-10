import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/local_storage_service.dart';
import 'package:flutter_app/services/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trip History Status Synchronization & Resolution Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Scenario 1: Timer expires and user selects +15 min', () async {
      const storage = LocalStorageService();

      // 1. Timeout detected -> saves active trip with isTimeoutWarning = true
      await storage.saveActiveTrip(
        isActive: true,
        destination: 'Campus',
        tripId: 'trip_sync_001',
        totalDurationSeconds: 45 * 60,
        isTimeoutWarning: true,
        wasExtended: false,
      );

      // 2. User selects +15 min -> extends trip
      await storage.saveActiveTrip(
        isActive: true,
        destination: 'Campus',
        tripId: 'trip_sync_001',
        totalDurationSeconds: 45 * 60,
        isTimeoutWarning: false,
        wasExtended: true,
      );

      final activeData = await storage.readActiveTrip();
      expect(activeData, isNotNull);
      expect(activeData!['isTimeoutWarning'], isFalse);
      expect(activeData['wasExtended'], isTrue);
    });

    test(
      'Scenario 2 & 8: Local status resolution prevents stale timeout_warning from overwriting local EXPIRED/Timer Expired',
      () {
        final fbService = FirebaseService();

        // Local status is 'Timer Expired' (Priority 4), Cloud is 'timeout_warning' (Priority 2)
        final resolvedTimerExpired = fbService.resolveTripStatus(
          'Timer Expired',
          'timeout_warning',
        );
        expect(resolvedTimerExpired, 'Timer Expired');

        // Local status is 'expired' (Priority 4), Cloud is 'timeout_warning' (Priority 2)
        final resolvedExpired = fbService.resolveTripStatus(
          'expired',
          'timeout_warning',
        );
        expect(resolvedExpired, 'expired');

        // Local status is 'Arrival Unconfirmed' (Priority 4), Cloud is 'timeout_warning' (Priority 2)
        final resolvedUnconfirmed = fbService.resolveTripStatus(
          'Arrival Unconfirmed',
          'timeout_warning',
        );
        expect(resolvedUnconfirmed, 'Arrival Unconfirmed');

        // Local status is 'Trip Extended' (Priority 3), Cloud is 'timeout_warning' (Priority 2)
        final resolvedExt = fbService.resolveTripStatus(
          'Trip Extended',
          'timeout_warning',
        );
        expect(resolvedExt, 'Trip Extended');

        // Local status is 'Arrived Safely' (Priority 4), Cloud is 'timeout_warning' (Priority 2)
        final resolvedArrived = fbService.resolveTripStatus(
          'Arrived Safely',
          'timeout_warning',
        );
        expect(resolvedArrived, 'Arrived Safely');

        // Local status is 'active' (Priority 1), Cloud is 'arrived' (Priority 4)
        final resolvedCloudTerminal = fbService.resolveTripStatus(
          'active',
          'arrived',
        );
        expect(resolvedCloudTerminal, 'arrived');
      },
    );

    test(
      'Scenario 2b: combineTripsForTesting verifies actual local-cloud map merging and timestamp preservation',
      () {
        final fbService = FirebaseService();
        final completionTime = DateTime(2026, 11, 10, 10, 46);
        final startTime = DateTime(2026, 11, 10, 10, 0);

        final localTrips = [
          TripRecord(
            id: 'trip_stream_100',
            destination: 'Campus',
            durationMinutes: 45,
            status: 'Timer Expired',
            timestamp: completionTime,
            wasExtended: false,
          ),
        ];

        final currentTrips = [
          TripRecord(
            id: 'trip_stream_100',
            destination: 'Campus',
            durationMinutes: 45,
            status: 'timeout_warning',
            timestamp: startTime,
            wasExtended: false,
          ),
        ];

        final combined = fbService.combineTripsForTesting(
          localTrips: localTrips,
          currentTrips: currentTrips,
        );

        expect(combined.length, 1);
        expect(combined.first.id, 'trip_stream_100');
        expect(combined.first.status, 'Timer Expired');
        expect(
          combined.first.timestamp,
          completionTime,
        ); // Preserves local completion time!
      },
    );

    test(
      'Scenario 3: Extended trip eventually reaches destination safely',
      () async {
        const storage = LocalStorageService();

        final newTrip = TripRecord(
          id: 'trip_sync_003',
          destination: 'Campus',
          durationMinutes: 45,
          status: 'Arrived Safely',
          timestamp: DateTime.now(),
          wasExtended: true,
        );

        await storage.saveTripHistory([newTrip]);
        final history = await storage.readTripHistory();

        expect(history.length, 1);
        expect(history.first.status, 'Arrived Safely');
        expect(history.first.wasExtended, isTrue);
      },
    );

    test(
      'Scenario 4: Extended trip later triggers an emergency alert',
      () async {
        const storage = LocalStorageService();

        final emergencyTrip = TripRecord(
          id: 'trip_sync_004',
          destination: 'Home',
          durationMinutes: 30,
          status: 'Timer Expired',
          timestamp: DateTime.now(),
          wasExtended: true,
        );

        await storage.saveTripHistory([emergencyTrip]);
        final history = await storage.readTripHistory();

        expect(history.length, 1);
        expect(history.first.status, 'Timer Expired');
        expect(history.first.wasExtended, isTrue);
      },
    );

    test(
      'Scenario 5: Safety warning (timeout_warning) is classified under warning status and not counted in completed alerts',
      () {
        final warningTrip = TripRecord(
          id: 'trip_sync_005',
          destination: 'Campus',
          durationMinutes: 45,
          status: 'timeout_warning',
          timestamp: DateTime.now(),
          wasExtended: false,
        );

        final statusLower = warningTrip.status.toLowerCase();
        final isCompletedAlert = [
          'alert',
          'expired',
          'help_requested',
          'manual sos',
          'need help',
          'timer expired',
          'arrival unconfirmed',
        ].contains(statusLower);

        expect(isCompletedAlert, isFalse);
      },
    );

    test(
      'Scenario 6: Unanswered safety check reaches final outcome (Timer Expired / expired)',
      () async {
        const storage = LocalStorageService();

        final finalOutcomeTrip = TripRecord(
          id: 'trip_sync_006',
          destination: 'Campus',
          durationMinutes: 45,
          status: 'Timer Expired',
          timestamp: DateTime.now(),
          wasExtended: false,
        );

        await storage.saveTripHistory([finalOutcomeTrip]);
        final history = await storage.readTripHistory();

        expect(history.first.status, 'Timer Expired');
      },
    );

    test(
      'Scenario 7: App backgrounding and reopening preserves active trip state',
      () async {
        const storage = LocalStorageService();

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await storage.saveActiveTrip(
          isActive: true,
          destination: 'Campus',
          tripId: 'trip_sync_007',
          totalDurationSeconds: 45 * 60,
          startedAtMs: nowMs,
          expectedArrivalAtMs: nowMs + 45 * 60 * 1000,
          isArrived: false,
          isTimeoutWarning: false,
          wasExtended: true,
        );

        // Reopen simulation
        final restored = await storage.readActiveTrip();
        expect(restored, isNotNull);
        expect(restored!['tripId'], 'trip_sync_007');
        expect(restored['wasExtended'], isTrue);
        expect(restored['isActive'], isTrue);
      },
    );

    test(
      'Scenario 9: Stable tripId matching merges transient warning record and finalized outcome into strictly ONE record',
      () {
        final fbService = FirebaseService();
        final startTime = DateTime(2026, 11, 10, 10, 0);
        final completionTime = DateTime(2026, 11, 10, 10, 46);

        // Record A (stale cloud warning record with same tripId)
        final currentTrips = [
          TripRecord(
            id: 'trip_stable_001',
            destination: 'Campus',
            durationMinutes: 45,
            status: 'timeout_warning',
            timestamp: startTime,
            wasExtended: false,
          ),
        ];

        // Record B (finalized local history record with same tripId)
        final localTrips = [
          TripRecord(
            id: 'trip_stable_001',
            destination: 'Campus',
            durationMinutes: 45,
            status: 'Timer Expired',
            timestamp: completionTime,
            wasExtended: false,
          ),
        ];

        final combined = fbService.combineTripsForTesting(
          localTrips: localTrips,
          currentTrips: currentTrips,
        );

        // Verify that the 2 records for the same tripId merge into strictly 1 finalized record
        expect(combined.length, 1);
        expect(combined.first.id, 'trip_stable_001');
        expect(combined.first.status, 'Timer Expired');
        expect(combined.first.timestamp, completionTime);
      },
    );

    test(
      'Scenario 10: Separate trips 10-30 minutes apart to the same destination with different trip IDs are 100% PRESERVED as separate trips',
      () {
        final fbService = FirebaseService();

        final trips = [
          TripRecord(
            id: 'trip_campus_0800',
            destination: 'Campus',
            durationMinutes: 30,
            status: 'Arrived Safely',
            timestamp: DateTime(2026, 11, 10, 8, 0),
            wasExtended: false,
          ),
          TripRecord(
            id: 'trip_campus_0815',
            destination: 'Campus',
            durationMinutes: 30,
            status: 'Arrived Safely',
            timestamp: DateTime(2026, 11, 10, 8, 15), // 15 mins apart!
            wasExtended: false,
          ),
        ];

        final combined = fbService.combineTripsForTesting(
          localTrips: trips,
          currentTrips: [],
        );

        // Verify that two separate trips 15 minutes apart to the same destination are 100% PRESERVED
        expect(combined.length, 2);
        expect(combined.first.id, 'trip_campus_0815');
        expect(combined.last.id, 'trip_campus_0800');
      },
    );
  });
}
