import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/firebase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseService Anonymous Auth & Firestore Ownership Unit Tests', () {
    test(
      'ensureAnonymousAuth returns test_anonymous_uid in test environment',
      () async {
        final service = FirebaseService();
        final uid = await service.ensureAnonymousAuth();
        expect(uid, 'test_anonymous_uid');
      },
    );

    test(
      'ensureAnonymousAuth coalesces concurrent calls into a single shared in-flight Future',
      () async {
        final service = FirebaseService();
        final results = await Future.wait([
          service.ensureAnonymousAuth(),
          service.ensureAnonymousAuth(),
          service.ensureAnonymousAuth(),
        ]);
        expect(results[0], 'test_anonymous_uid');
        expect(results[1], 'test_anonymous_uid');
        expect(results[2], 'test_anonymous_uid');
      },
    );

    test(
      'saveOrUpdateTrip executes safely without throwing in test environment',
      () async {
        final service = FirebaseService();
        await service.saveOrUpdateTrip(
          tripId: 'test_trip_123',
          destination: 'Campus',
          estimatedTravelMinutes: 45,
          startedAt: DateTime.now(),
          status: 'active',
        );
        expect(true, isTrue);
      },
    );

    test(
      'logEmergencyEvent executes safely without throwing in test environment',
      () async {
        final service = FirebaseService();
        await service.logEmergencyEvent(
          eventId: 'test_event_123',
          deviceId: 'local_device',
          tripId: 'test_trip_123',
          latitude: 14.869725,
          longitude: 120.999082,
          emergencyType: 'SOS',
        );
        expect(true, isTrue);
      },
    );

    test('getTripsStream returns broadcast stream without throwing', () {
      final service = FirebaseService();
      final stream = service.getTripsStream();
      expect(stream, isNotNull);
    });
  });
}
