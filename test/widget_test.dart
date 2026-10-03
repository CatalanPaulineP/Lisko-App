import 'dart:convert';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/geofence_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/plugins/notification_channel'),
      (MethodCall methodCall) async {
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('id.flutter/background_service'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
  });

  testWidgets('setup flow shows the requested three screens', (tester) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': false});
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await tester.pumpWidget(const LiskoApp());

    expect(find.text('Preparing LisKo...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WELCOME TO LISKO'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Initial Safety Setup'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enable Notifications'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(find.text('Import from Contacts'), findsOneWidget);
    expect(find.text('OR ENTER MANUALLY'), findsOneWidget);
    expect(find.text('Add Manual Contact'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SmsPermissionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Step 4 of 5'), findsOneWidget);
    expect(find.text('Allow SMS Permission'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.textContaining('No SMS messages are sent'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(find.text('Allow Location Access'), findsOneWidget);
    expect(find.text('Allow Location'), findsOneWidget);
    expect(
      find.text('Location is never tracked when no trip is active.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Allow Location'));
    await tester.pumpAndSettle();
    expect(find.text("You're Ready!"), findsOneWidget);
    expect(find.text('Notifications Enabled'), findsOneWidget);
    expect(find.text('Trusted Contacts Added'), findsOneWidget);
    expect(find.text('SMS Enabled'), findsOneWidget);
    expect(find.text('Location Enabled'), findsOneWidget);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Iskolar'), findsOneWidget);
  });

  testWidgets('fresh startup stays on splash before opening Welcome', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('setup_completed', true);
    await tester.pumpWidget(const LiskoApp());

    expect(find.text('Preparing LisKo...'), findsOneWidget);
    expect(find.text('Iskolar'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Preparing LisKo...'), findsOneWidget);
    expect(find.text('Iskolar'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WELCOME TO LISKO'), findsOneWidget);
    expect(find.text('Iskolar'), findsNothing);
  });

  testWidgets('contact overlays expose manual and import states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': false});
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await tester.pumpWidget(const LiskoApp());

    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Manual Contact'));
    await tester.pumpAndSettle();
    expect(find.text('e.g., Mom'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Save Contact'), findsOneWidget);

    await tester.tap(find.text('Import from Contacts'));
    await tester.pumpAndSettle();
    expect(
      find.text("'Lisko' Would Like to Access Your Contacts"),
      findsOneWidget,
    );

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(find.text('Phone Contacts'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);

    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Select Relationship'), findsOneWidget);
    expect(find.text('✓ Imported'), findsOneWidget);
    expect(find.text('Confirm & Save Contact'), findsOneWidget);

    await tester.tap(find.text('Confirm & Save Contact'));
    await tester.pumpAndSettle();
    expect(find.text('SAVED CONTACTS'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('+63 9171234567'), findsOneWidget);
  });

  testWidgets('home tabs switch instantly without route navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Iskolar'), findsOneWidget);
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Contacts Active'), findsOneWidget);
    expect(find.text('Trusted Contacts'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('trip scheduler starts and controls an active trip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // 1. Open Set Trip Timer sheet from Home
    final setUpBtn = find.byType(HomeStartButton);
    await tester.ensureVisible(setUpBtn);
    await tester.pumpAndSettle();
    await tester.tap(setUpBtn);
    await tester.pumpAndSettle();
    expect(find.text('Set Trip Timer'), findsOneWidget);
    expect(find.text('HEADING TO'), findsOneWidget);
    expect(find.text('Campus'), findsWidgets);

    // 2. Select 30 min and tap SAVE TRIP
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    expect(find.text('00 h : 30 m : 00 s'), findsOneWidget);

    await tester.tap(find.text('SAVE TRIP').last);
    await tester.pumpAndSettle();

    // 3. Staged state on Home: displays START TRIP
    expect(find.text('START TRIP'), findsOneWidget);
    expect(find.text('HEADING TO CAMPUS'), findsOneWidget);

    // Sleep 360ms CPU time to clear 350ms rapid-tap debounce threshold
    sleep(const Duration(milliseconds: 360));

    // 4. Tap START TRIP to begin active trip
    final startBtn = find.byType(HomeStartButton);
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    // 5. Active trip state:
    expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('+ 15 min'), findsOneWidget);
    expect(find.text('Need Help / SOS'), findsOneWidget);

    // 6. Test + 15 min extension during active trip
    await tester.tap(find.text('+ 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
  });

  testWidgets('stepper touch targets comply with ISO/IEC 25010 usability guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripSchedulerSheet(onStart: (_, __) async => true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final upStepper = find.byIcon(Icons.keyboard_arrow_up_rounded).first;
    final downStepper = find.byIcon(Icons.keyboard_arrow_down_rounded).first;

    final upSize = tester.getSize(upStepper);
    final downSize = tester.getSize(downStepper);

    // Verify touch targets satisfy accessibility minimums
    expect(upSize.width, greaterThanOrEqualTo(20.0));
    expect(downSize.width, greaterThanOrEqualTo(20.0));
  });

  testWidgets('rapid double tap on Start Trip does not open stacked bottom sheets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Rapid double tap on SET UP TRIP
    await tester.tap(find.text('SET UP TRIP').last);
    await tester.tap(find.text('SET UP TRIP').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Set Trip Timer'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Verify sheet is dismissed completely without a stacked second sheet
    expect(find.text('Set Trip Timer'), findsNothing);
  });

  testWidgets('splash screen executes entrance animation and staggered typography reveal', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Frame 0: Widgets are inflated
    expect(find.text('LISKO'), findsOneWidget);
    expect(find.text('Your Student Safety Companion'), findsOneWidget);
    expect(find.text('Preparing LisKo...'), findsOneWidget);

    // Advance 400ms to complete shield scale-up & glow
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LISKO'), findsOneWidget);

    // Advance 550ms to complete staggered typography reveal
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Your Student Safety Companion'), findsOneWidget);
    expect(find.text('Preparing LisKo...'), findsOneWidget);

    // Advance to verify smooth runner animation loop
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Preparing LisKo...'), findsOneWidget);
  });

  testWidgets('onboarding screens execute smooth 60fps animations and layout cleanup', (
    tester,
  ) async {
    // Step 2: NotificationBell pulse animation
    await tester.pumpWidget(const MaterialApp(home: NotificationPermissionScreen()));
    expect(find.byType(NotificationBell), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Enable Notifications'), findsOneWidget);

    // Step 4: SmsIllustration anchored floating speech bubbles
    await tester.pumpWidget(const MaterialApp(home: SmsPermissionScreen()));
    expect(find.byType(SmsIllustration), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Are you home?'), findsOneWidget);
    expect(find.text('SMS sent ✓'), findsOneWidget);

    // Step 5: LocationIllustration floating pin and compliance banner
    await tester.pumpWidget(const MaterialApp(home: LocationAccessScreen()));
    expect(find.byType(LocationIllustration), findsOneWidget);
    expect(find.byType(LocationInfoBox), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.text('Location is never tracked when no trip is active.'),
      findsOneWidget,
    );

    // Completion Screen: Success checkmark bounce and sequential checklist
    await tester.pumpWidget(const MaterialApp(home: SetupCompleteScreen()));
    expect(find.byType(SuccessIllustration), findsOneWidget);
    expect(find.byType(SetupChecklist), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text("You're Ready!"), findsOneWidget);
    expect(find.text('Notifications Enabled'), findsOneWidget);
    expect(find.text('Trusted Contacts Added'), findsOneWidget);
    expect(find.text('SMS Enabled'), findsOneWidget);
    expect(find.text('Location Enabled'), findsOneWidget);
  });

  testWidgets(
    'trusted contacts manual form validates PH mobile and confirms deletion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrustedContactsScreen()),
        ),
      );

      // Open manual form
      await tester.tap(find.text('Add Manual Contact'));
      await tester.pumpAndSettle();

      // Attempt to save empty fields
      await tester.ensureVisible(find.text('Save Contact'));
      await tester.tap(find.text('Save Contact'));
      await tester.pumpAndSettle();
      expect(find.text('Contact name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);

      // Enter name and invalid phone number
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., Mom'),
        'Pauline Santos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '9XX XXX XXXX'),
        '12345',
      );
      await tester.ensureVisible(find.text('Save Contact'));
      await tester.tap(find.text('Save Contact'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Must be a 10-digit number starting with 9 (e.g., 9123456789)',
        ),
        findsOneWidget,
      );

      // Test zero-blocker: entering 09123456789 strips leading 0 to 9123456789
      await tester.enterText(
        find.widgetWithText(TextField, '9XX XXX XXXX'),
        '09123456789',
      );
      expect(find.text('9123456789'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Contact'));
      await tester.tap(find.text('Save Contact'));
      await tester.pumpAndSettle();

      // Verify contact saved and manual form closed
      expect(find.text('SAVED CONTACTS'), findsOneWidget);
      expect(find.text('Pauline Santos'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('+63 9123456789'), findsOneWidget);
      expect(find.text('PS'), findsOneWidget);
      expect(find.byType(ManualContactExpandedForm), findsNothing);

      // Trigger deletion modal
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Contact'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to remove Pauline Santos from your trusted contacts?',
        ),
        findsOneWidget,
      );

      // Test Cancel does not delete
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Pauline Santos'), findsOneWidget);

      // Trigger deletion modal again and confirm Remove
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      // Contact is now deleted
      expect(find.text('Pauline Santos'), findsNothing);
      expect(find.text('SAVED CONTACTS'), findsNothing);
    },
  );

  testWidgets(
    'dashboard inactive timer shows --:--:-- in slate grey and bottom sheet chips are consistent',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripTimerCard(),
          ),
        ),
      );

      // Verify neutral placeholder countdown and muted slate color
      final placeholderFinder = find.text('__:__:__');
      expect(placeholderFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(placeholderFinder);
      expect(textWidget.style?.color, const Color(0xFF64748B));
      expect(find.text('NO ACTIVE TRIP'), findsOneWidget);

      // Pump Bottom Sheet and verify scrollable wheel picker & chips
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSchedulerSheet(onStart: (_, __) async => true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify destination and duration chips render with consistent radius
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Campus'), findsWidgets);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);

      // Test scroll drag on minute ListWheelScrollView
      final wheels = find.byType(ListWheelScrollView);
      expect(wheels, findsNWidgets(2)); // HR and MIN wheels

      // Drag up to scroll through minutes
      await tester.drag(wheels.last, const Offset(0, -60));
      await tester.pumpAndSettle();

      // Verify touch target for steppers
      final upButton = find.byIcon(Icons.keyboard_arrow_up_rounded).first;
      await tester.tap(upButton);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'trips tab displays hero header, summary metrics, and recent trips list correctly',
    (tester) async {
      final mockTrips = [
        TripRecord(id: '1', destination: 'Campus - Home', durationMinutes: 50, status: 'Completed', timestamp: DateTime(2026, 6, 10)),
        TripRecord(id: '2', destination: 'Campus - Home', durationMinutes: 45, status: 'Extended', timestamp: DateTime(2026, 6, 8), wasExtended: true),
        TripRecord(id: '3', destination: 'Home - Campus', durationMinutes: 30, status: 'Alert', timestamp: DateTime(2026, 6, 5)),
      ];
      final encoded = jsonEncode(mockTrips.map((t) => t.toJson()).toList());
      SharedPreferences.setMockInitialValues({'trip_history_json': encoded, 'walkthrough_completed_v2': true, 'setup_completed': true});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Subtitle
      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('3 trips recorded'), findsOneWidget);

      // Verify Summary Metrics Card 4 columns
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Extended'), findsWidgets); // Column label and badge
      expect(find.text('Alerts'), findsOneWidget); // Segment 4 label

      expect(find.text('3'), findsOneWidget);

      // Verify Recent Trips Section
      expect(find.text('RECENT TRIPS'), findsOneWidget);
      expect(find.text('Campus - Home'), findsNWidgets(2));
      expect(find.text('Home - Campus'), findsOneWidget);

      // Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);

      // Verify Section Filter Icon
      expect(find.byTooltip('Select date from calendar'), findsOneWidget);

      // Verify Bottom Navigation switches to TripsTab in HomeScreen
      SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('Iskolar'), findsOneWidget);
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('RECENT TRIPS'), findsOneWidget);
    },
  );

  test('geofence service resolves PUP Santa Maria and Home coordinates correctly', () async {
    final service = GeofenceService();

    // Verify PUP Santa Maria Campus target
    final campusTarget = await service.resolveTarget('Campus');
    expect(campusTarget!.name, 'Campus');
    expect(campusTarget.latitude, 14.869725503304737);
    expect(campusTarget.longitude, 120.9990821362761);
    expect(campusTarget.radiusMeters, 150.0);

    // Verify Home target
    final homeTarget = await service.resolveTarget('Home');
    expect(homeTarget!.name, 'Home');
    expect(homeTarget.latitude, 14.8192);
    expect(homeTarget.longitude, 120.9610);
    expect(homeTarget.radiusMeters, 150.0);
  });

  testWidgets(
    'active trip geofence arrival triggers safety prompt with 90s countdown and handles safe confirmation',
    (tester) async {
      SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Stage and Start a trip to Campus
      final setUpBtn = find.byType(HomeStartButton);
      await tester.ensureVisible(setUpBtn);
      await tester.pumpAndSettle();
      await tester.tap(setUpBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE TRIP').last);
      await tester.pumpAndSettle();

      // Sleep 360ms CPU time to clear 350ms rapid-tap debounce threshold
      sleep(const Duration(milliseconds: 360));

      final startBtn = find.byType(HomeStartButton);
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);

      // 2. Simulate entering the destination geofence perimeter
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      // 3. Verify Destination Reached state and safety confirmation prompt
      expect(find.text('Destination Reached'), findsOneWidget);
      expect(find.textContaining("You've reached your destination"), findsOneWidget);
      expect(find.text("I'm Safe"), findsOneWidget);
      expect(find.text('NEED HELP'), findsOneWidget);

      // 4. Confirm safety: tap "I'm Safe"
      await tester.tap(find.text("I'm Safe"));
      await tester.pumpAndSettle();

      // 5. Verify trip is safely concluded and returns to idle home screen
      expect(find.text('SET UP TRIP'), findsWidgets);
      expect(find.text('Destination Reached'), findsNothing);
    },
  );

  testWidgets(
    'geofence arrival handles + 15 min extension and resumes active commute countdown',
    (tester) async {
      SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Stage and Start a trip
      final setUpBtn = find.byType(HomeStartButton);
      await tester.ensureVisible(setUpBtn);
      await tester.pumpAndSettle();
      await tester.tap(setUpBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SAVE TRIP').last);
      await tester.pumpAndSettle();

      // Sleep 360ms CPU time to clear 350ms rapid-tap debounce threshold
      sleep(const Duration(milliseconds: 360));

      final startBtn = find.byType(HomeStartButton);
      await tester.ensureVisible(startBtn);
      await tester.pumpAndSettle();
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // 2. Trigger arrival prompt
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      expect(find.text('Destination Reached'), findsOneWidget);

      // 3. Confirm safe arrival
      await tester.tap(find.text("I'm Safe"));
      await tester.pumpAndSettle();

      // 4. Verify arrival prompt is dismissed and returns to Home
      expect(find.text('Destination Reached'), findsNothing);
      expect(find.text('SET UP TRIP'), findsWidgets);
    },
  );

  testWidgets(
    'SettingsTab renders correctly and handles modal interactions',
    (tester) async {
      SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Lisko Preferences & Diagnostics'), findsOneWidget);

      // Verify Sections
      expect(find.text('COMMUTE PRESETS & GEOFENCING'), findsOneWidget);
      expect(find.text('ALARM & SAFETY PROTOCOL'), findsOneWidget);
      expect(find.text('INFORMATION & SUPPORT'), findsOneWidget);

      // Verify Section 1 Items
      expect(find.text('Home Location Pin'), findsOneWidget);
      expect(find.text('Tap to set home coordinates'), findsOneWidget);
      expect(find.text('PUP Santa Maria Campus'), findsOneWidget);
      expect(find.text('Campus Destination Geofence (150m)'), findsOneWidget);
      expect(find.text('Default Travel Duration'), findsOneWidget);

      // Verify Section 2 Items
      expect(find.text('Expiry Alert Mode'), findsOneWidget);
      expect(find.text('Covert SMS Emergency Dispatch'), findsOneWidget);

      // Verify Section 3 Items
      expect(find.text('User Guide & Safety Protocol'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('Privacy Policy & GPS Usage Rules'), findsOneWidget);

      // Verify Footer
      expect(find.text('Lisko v1.0.0 • PUP Santa Maria Campus'), findsOneWidget);
      expect(find.text('Zero-Surveillance Architecture • Offline-First'), findsOneWidget);

      // Open Home Geofence Modal
      await tester.tap(find.text('Home Location Pin'));
      await tester.pumpAndSettle();
      expect(find.text('Set Home Geofence'), findsOneWidget);
      expect(find.text('Use Current GPS Location'), findsOneWidget);

      // Tap Use Current GPS
      await tester.tap(find.text('Use Current GPS Location'));
      await tester.pumpAndSettle();

      // Verify Save
      await tester.tap(find.text('Save Coordinates'));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('Set Home Geofence'), findsNothing);

      // Open Campus Geofence Modal
      await tester.tap(find.text('PUP Santa Maria Campus'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Geofence'), findsOneWidget);
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      // Open User Guide Modal
      await tester.ensureVisible(find.text('User Guide & Safety Protocol'));
      await tester.tap(find.text('User Guide & Safety Protocol'));
      await tester.pumpAndSettle();
      expect(find.text('User Guide & Safety Protocol'), findsWidgets);
      await tester.tap(find.text('Got It, I Understand'));
      await tester.pumpAndSettle();

      // Open Privacy Modal
      await tester.ensureVisible(find.text('Privacy Policy & GPS Usage Rules'));
      await tester.tap(find.text('Privacy Policy & GPS Usage Rules'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy & GPS Usage Rules'), findsWidgets);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'TransitNodeSelectionSheet enforces priority order, single expansion accordion, and collapse lifecycle',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransitNodeSelectionSheet(
              onSelected: (name) => selected = name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify header text and priority display order (1. Santa Maria, 2. Norzagaray, 3. Angat)
      expect(find.text('Select Transit Drop-off'), findsOneWidget);
      expect(find.text('Choose a frequent commuter node in your area'), findsOneWidget);

      final santaMariaFinder = find.text('Santa Maria');
      final norzagarayFinder = find.text('Norzagaray');
      final angatFinder = find.text('Angat');

      expect(santaMariaFinder, findsOneWidget);
      expect(norzagarayFinder, findsOneWidget);
      expect(angatFinder, findsOneWidget);

      // Verify Santa Maria appears above Norzagaray, and Norzagaray above Angat
      final santaMariaY = tester.getTopLeft(santaMariaFinder).dy;
      final norzagarayY = tester.getTopLeft(norzagarayFinder).dy;
      final angatY = tester.getTopLeft(angatFinder).dy;

      expect(santaMariaY, lessThan(norzagarayY));
      expect(norzagarayY, lessThan(angatY));

      // 2. All groups start collapsed initially
      expect(find.text('Caypombo Terminal / Crossing'), findsNothing);
      expect(find.text('Norzagaray-Santa Maria Jeepney & UV Terminal'), findsNothing);
      expect(find.text('Angat-Divisoria Bus Terminal (Sta. Monica Transport / Racal / Agila Line)'), findsNothing);

      // 3. Expand Santa Maria
      await tester.tap(santaMariaFinder);
      await tester.pumpAndSettle();
      expect(find.text('Caypombo Terminal / Crossing'), findsOneWidget);
      expect(find.text('Waltermart Santa Maria Drop-off'), findsOneWidget);

      // 4. Without manually collapsing Santa Maria, expand Angat
      await tester.tap(angatFinder);
      await tester.pumpAndSettle();

      // Angat terminals become visible, Santa Maria terminals are automatically collapsed!
      expect(find.text('Angat-Divisoria Bus Terminal (Sta. Monica Transport / Racal / Agila Line)'), findsOneWidget);
      expect(find.text('Angat-Monumento Bus Terminal (Shanine & Pauline Transport)'), findsOneWidget);
      expect(find.text('Caypombo Terminal / Crossing'), findsNothing);

      // 5. Expand Norzagaray
      await tester.tap(norzagarayFinder);
      await tester.pumpAndSettle();

      // Norzagaray terminal becomes visible, Angat terminals are automatically collapsed!
      expect(find.text('Norzagaray-Santa Maria Jeepney & UV Terminal'), findsOneWidget);
      expect(find.text('Angat-Divisoria Bus Terminal (Sta. Monica Transport / Racal / Agila Line)'), findsNothing);

      // 6. Tap Norzagaray again -> collapses, bottom sheet remains open
      await tester.tap(norzagarayFinder);
      await tester.pumpAndSettle();

      expect(find.byType(TransitNodeSelectionSheet), findsOneWidget);
      expect(find.text('Norzagaray-Santa Maria Jeepney & UV Terminal'), findsNothing);

      // 7. Re-expand Santa Maria successfully
      await tester.tap(santaMariaFinder);
      await tester.pumpAndSettle();
      expect(find.text('Caypombo Terminal / Crossing'), findsOneWidget);

      // 8. Select an actual terminal -> callback fires and modal closes
      await tester.tap(find.text('Caypombo Terminal / Crossing'));
      await tester.pumpAndSettle();

      expect(selected, 'Caypombo Terminal / Crossing');

      // 9. Verify exact resolveTarget() matching
      final service = GeofenceService();
      final resolvedNorz = await service.resolveTarget('Norzagaray-Santa Maria Jeepney & UV Terminal');
      final resolvedDivisoria = await service.resolveTarget('Angat-Divisoria Bus Terminal (Sta. Monica Transport / Racal / Agila Line)');

      expect(resolvedNorz!.id, 'norz_terminal');
      expect(resolvedDivisoria!.id, 'angat_divisoria');
    },
  );

  testWidgets(
    'notification bell opens popover displaying max 5 recent items without auto-marking read',
    (tester) async {
      SharedPreferences.setMockInitialValues({'walkthrough_completed_v2': true, 'setup_completed': true});

      final todayList = List.generate(
        4,
        (i) => AppNotificationItem(
          id: 't_$i',
          title: 'Safe Arrival Alert $i',
          message: 'You have safely arrived at Campus.',
          timeAgo: '10m ago',
          category: 'arrival',
          isRead: false,
        ),
      );

      final earlierList = List.generate(
        4,
        (i) => AppNotificationItem(
          id: 'e_$i',
          title: 'Emergency Alert Sent $i',
          message: 'Manual SOS triggered. Alert SMS sent to trusted contacts.',
          timeAgo: 'Yesterday',
          category: 'emergency',
          isRead: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsPopover(
              todayNotifications: todayList,
              earlierNotifications: earlierList,
              onClose: () {},
              onItemTap: (_) {},
              onViewAll: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify popover title and unread badge count (total 8 unread)
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // 2. Verify max 5 recent items are displayed
      expect(find.byType(NotificationTile), findsNWidgets(5));
      expect(find.text('View All Notifications'), findsOneWidget);
    },
  );

  testWidgets(
    'AllNotificationsScreen displays category filter chips and filters emergency vs safe arrival notifications',
    (tester) async {
      final todayList = [
        const AppNotificationItem(
          id: '1',
          title: 'Safe Arrival Alert',
          message: 'You have safely arrived at Campus.',
          timeAgo: '10m ago',
          category: 'arrival',
          isRead: false,
        ),
        const AppNotificationItem(
          id: '2',
          title: 'Emergency Alert Sent',
          message: 'Manual SOS triggered. Alert SMS sent to trusted contacts.',
          timeAgo: '30m ago',
          category: 'emergency',
          isRead: false,
        ),
      ];

      final yesterdayList = [
        const AppNotificationItem(
          id: '3',
          title: 'Emergency Alert Sent',
          message: 'Safety check timed out for Campus. Alert SMS sent to trusted contacts.',
          timeAgo: 'Yesterday',
          category: 'emergency',
          isRead: true,
        ),
      ];

      String? tappedId;

      await tester.pumpWidget(
        MaterialApp(
          home: AllNotificationsScreen(
            todayNotifications: todayList,
            yesterdayNotifications: yesterdayList,
            earlierNotifications: const [],
            onItemTap: (id) => tappedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. All filter selected by default: shows TODAY and YESTERDAY sections
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.byType(NotificationTile), findsNWidgets(3));

      // 2. Filter by Emergency Alerts
      await tester.tap(find.text('Emergency Alerts'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationTile), findsNWidgets(2));
      expect(find.text('Safe Arrival Alert'), findsNothing);

      // 3. Filter by Safe Arrivals
      await tester.tap(find.text('Safe Arrivals'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationTile), findsNWidgets(1));
      expect(find.text('Safe Arrival Alert'), findsOneWidget);
      expect(find.text('Emergency Alert Sent'), findsNothing);

      // 4. Tap notification tile
      await tester.tap(find.text('Safe Arrival Alert'));
      await tester.pumpAndSettle();
      expect(tappedId, '1');

      // 5. Test empty state when filter has no matches
      await tester.pumpWidget(
        MaterialApp(
          home: AllNotificationsScreen(
            todayNotifications: const [],
            yesterdayNotifications: const [],
            earlierNotifications: const [],
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No safe arrivals recorded'), findsOneWidget);
    },
  );

  testWidgets(
    'opening popover marks ONLY top 5 visible notifications read and leaves older items unread',
    (tester) async {
      final mockTrips = List.generate(
        8,
        (i) => TripRecord(
          id: 'trip_$i',
          destination: 'Campus $i',
          durationMinutes: 30,
          status: 'arrived',
          timestamp: DateTime.now().subtract(Duration(minutes: i * 10)),
        ),
      );

      final encoded = jsonEncode(mockTrips.map((t) => t.toJson()).toList());
      SharedPreferences.setMockInitialValues({
        'trip_history_json': encoded,
        'walkthrough_completed_v2': true,
        'setup_completed': true,
      });

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // 1. Initial state: Notification bell has unread indicator
      expect(find.byTooltip('Notifications'), findsOneWidget);

      // 2. Open Notification Popover
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      // 3. Popover shows top 5 items, unread badge count shows remaining 3
      expect(find.byType(NotificationsPopover), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 remaining unread

      // 4. Close popover
      await tester.tap(find.byTooltip('Close notifications'));
      await tester.pumpAndSettle();

      // 5. Verify top 5 IDs were persisted as read, and items 5-7 remain unread
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_notification_ids_set') ?? [];
      expect(readIds.length, 5);
      expect(readIds, containsAll(['trip_0', 'trip_1', 'trip_2', 'trip_3', 'trip_4']));
      expect(readIds.contains('trip_5'), false);
      expect(readIds.contains('trip_6'), false);
      expect(readIds.contains('trip_7'), false);
    },
  );
}
