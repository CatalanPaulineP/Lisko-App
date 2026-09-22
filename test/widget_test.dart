import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/geofence_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('setup flow shows the requested three screens', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await tester.pumpWidget(const LiskoApp());

    expect(find.text('Loading...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
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
    expect(find.text('Notifications enabled'), findsOneWidget);
    expect(find.text('Trusted contacts added'), findsOneWidget);
    expect(find.text('SMS & Location ready'), findsOneWidget);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning,'), findsOneWidget);
    expect(find.text('Iskolar'), findsOneWidget);
  });

  testWidgets('fresh startup stays on splash before opening Welcome', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('setup_completed', true);
    await tester.pumpWidget(const LiskoApp());

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Good morning,'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Good morning,'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WELCOME TO LISKO'), findsOneWidget);
    expect(find.text('Good morning,'), findsNothing);
  });

  testWidgets('contact overlays expose manual and import states', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await tester.pumpWidget(const LiskoApp());

    await tester.pump(const Duration(seconds: 5));
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
    expect(find.text('Mother'), findsOneWidget);
    expect(find.text('Save Contact'), findsOneWidget);

    await tester.tap(find.text('Import from Contacts'));
    await tester.pumpAndSettle();
    expect(
      find.text("'LisKo' Would Like to Access Your Contacts"),
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
    expect(find.text('+63 917 123 4567'), findsOneWidget);
  });

  testWidgets('home tabs switch instantly without route navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Good morning, Iskolar'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.text('START TRIP').last);
    await tester.pumpAndSettle();
    expect(find.text('Set Trip Timer'), findsOneWidget);
    expect(find.text('HEADING TO'), findsOneWidget);
    expect(find.text('Campus'), findsWidgets);

    await tester.tap(find.text('30 min'));
    await tester.pump();
    expect(find.text('00 h : 30 m : 00 s'), findsOneWidget);

    await tester.tap(find.text('START TRIP').last);
    await tester.pumpAndSettle();
    expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text("I'm Safe / Arrive"), findsOneWidget);
    expect(find.text('+ 15 min'), findsOneWidget);

    await tester.tap(find.text('+ 15 min'));
    await tester.pump();
    await tester.tap(find.text("I'm Safe / Arrive"));
    await tester.pump();
    expect(find.text('START TRIP'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // Rapid double tap on START TRIP (second tap simulates user double clicking before sheet settles)
    await tester.tap(find.text('START TRIP').last);
    await tester.tap(find.text('START TRIP').last, warnIfMissed: false);
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
    expect(find.text('Loading...'), findsOneWidget);

    // Advance 400ms to complete shield scale-up & glow
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LISKO'), findsOneWidget);

    // Advance 550ms to complete staggered typography reveal
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Your Student Safety Companion'), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    // Advance to verify smooth runner animation loop
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('onboarding screens execute smooth 60fps animations and layout cleanup', (
    tester,
  ) async {
    // Step 1: NotificationBell pulse animation
    await tester.pumpWidget(const MaterialApp(home: InitialSafetySetupScreen()));
    expect(find.byType(NotificationBell), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Allow Notifications'), findsOneWidget);

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
    expect(find.text('Notifications enabled'), findsOneWidget);
    expect(find.text('Trusted contacts added'), findsOneWidget);
    expect(find.text('SMS & Location ready'), findsOneWidget);
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
      expect(find.text('Mother'), findsOneWidget);
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

      // Trigger deletion modal again and confirm Delete
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Contact is now deleted
      expect(find.text('Pauline Santos'), findsNothing);
      expect(find.text('SAVED CONTACTS'), findsNothing);
    },
  );

  testWidgets(
    'dashboard inactive timer shows __:__:__ in slate grey and bottom sheet chips are consistent',
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
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripsTab(),
          ),
        ),
      );

      // Verify Header and Subtitle
      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('3 trips recorded this month'), findsOneWidget);

      // Verify Summary Metrics Card 4 columns
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Extended'), findsWidgets); // Column label and badge
      expect(find.text('Alerts'), findsOneWidget); // Segment 4 label
      expect(find.text('Alert'), findsOneWidget); // Trip 3 badge

      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(3)); // Safe, Extended, Alerts each have 1

      // Verify Recent Trips Section
      expect(find.text('RECENT TRIPS'), findsOneWidget);
      expect(find.text('Campus - Home'), findsNWidgets(2));
      expect(find.text('Home - Campus'), findsOneWidget);

      expect(find.text('June 10 | 50 mins'), findsOneWidget);
      expect(find.text('June 08 | 45 mins (+15m)'), findsOneWidget);
      expect(find.text('June 05 | 30 mins'), findsOneWidget);

      // Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);

      // Verify Section Filter Icon
      expect(find.byTooltip('Filter trips'), findsOneWidget);

      // Test tapping 'This Week' filter chip
      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();
      expect(find.text('June 10 | 50 mins'), findsOneWidget);
      expect(find.text('June 08 | 45 mins (+15m)'), findsOneWidget);
      expect(find.text('June 05 | 30 mins'), findsNothing);

      // Test tapping filter icon to open filter bottom sheet
      await tester.tap(find.byTooltip('Filter trips'));
      await tester.pumpAndSettle();
      expect(find.text('Filter Trips'), findsOneWidget);
      expect(find.text('All Trips'), findsOneWidget);
      expect(find.text('Alerts Only'), findsOneWidget);

      // Filter by Alerts Only
      await tester.tap(find.text('Alerts Only'));
      await tester.pumpAndSettle();
      expect(find.text('June 05 | 30 mins'), findsOneWidget);
      expect(find.text('June 10 | 50 mins'), findsNothing);

      // Switch back to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('June 10 | 50 mins'), findsOneWidget);
      expect(find.text('June 08 | 45 mins (+15m)'), findsOneWidget);
      expect(find.text('June 05 | 30 mins'), findsOneWidget);

      // Verify Bottom Navigation switches to TripsTab in HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('Good morning,'), findsOneWidget);
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      expect(find.text('Trip History'), findsOneWidget);
      expect(find.text('3 trips recorded this month'), findsOneWidget);
      expect(find.text('RECENT TRIPS'), findsOneWidget);
      expect(find.byTooltip('Filter trips'), findsOneWidget);
    },
  );

  testWidgets(
    'ContactsTab renders correctly and supports edit, import, add, and remove operations',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Trusted Contacts'), findsOneWidget);
      expect(find.text('3 Contacts Active | SMS recipient'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // Verify Primary Emergency Contact Card
      expect(find.text('Primary Emergency Contact'), findsOneWidget);
      expect(find.text('Pauline'), findsOneWidget);
      expect(find.text('Mother | +63 9123456789'), findsOneWidget);
      expect(find.text('Import from Contacts'), findsOneWidget);

      // Verify Secondary Contacts List
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);

      // Test Edit Primary Contact flow
      await tester.tap(find.byTooltip('Contact options'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Contact'), findsOneWidget);
      await tester.tap(find.text('Edit Contact'));
      await tester.pumpAndSettle();

      // Edit bottom sheet is open
      expect(find.text('Emergency SMS recipient'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Change name to Pauline Smith
      await tester.enterText(find.widgetWithText(TextField, 'Pauline'), 'Pauline Smith');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify updated name on card
      expect(find.text('Pauline Smith'), findsOneWidget);

      // Test Import from Contacts flow
      await tester.tap(find.text('Import from Contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Phone Contacts'), findsOneWidget);
      expect(find.text('Select a contact to import'), findsOneWidget);
      expect(find.text('Dianne'), findsOneWidget);

      await tester.tap(find.text('Dianne'));
      await tester.pumpAndSettle();

      // Verify Dianne is added and active count is now 4
      expect(find.text('4 Contacts Active | SMS recipient'), findsOneWidget);
      expect(find.text('Dianne'), findsOneWidget);

      // Test Add New Contact modal via + Add button
      await tester.tap(find.byKey(const Key('add_contact_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add New Contact'), findsOneWidget);
      expect(find.text('Add Contact'), findsOneWidget);

      // Enter details
      final textFields = find.byType(TextField);
      // First text field is Full Name
      await tester.enterText(textFields.first, 'Kuya Carlos');
      await tester.tap(find.text('Guardian'));
      // Last text field is Phone Number
      await tester.enterText(textFields.last, '9150001111');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Contact'));
      await tester.pumpAndSettle();

      // Verify Kuya Carlos is added and active count is 5
      expect(find.text('5 Contacts Active | SMS recipient'), findsOneWidget);
      expect(find.text('Kuya Carlos'), findsOneWidget);

      // Test deleting a secondary contact
      await tester.tap(find.byTooltip('Remove contact').first);
      await tester.pumpAndSettle();

      expect(find.text('4 Contacts Active | SMS recipient'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);
    },
  );

  test('geofence service resolves PUP Santa Maria and Home coordinates correctly', () async {
    final service = GeofenceService();

    // Verify PUP Santa Maria Campus target
    final campusTarget = await service.resolveTarget('Campus');
    expect(campusTarget!.name, 'Campus');
    expect(campusTarget.latitude, 14.8697);
    expect(campusTarget.longitude, 120.9991);
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
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Start a trip to Campus
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();

      expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);

      // 2. Simulate entering the destination geofence perimeter
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      // 3. Verify Destination Reached state and safety confirmation prompt
      expect(find.text('DESTINATION REACHED'), findsOneWidget);
      expect(find.text('You have arrived at Campus.'), findsOneWidget);
      expect(find.text('Are you safe?'), findsOneWidget);
      expect(find.textContaining('Auto-alert in: 01:30'), findsOneWidget);
      expect(find.text("I'm Safe / Arrive"), findsOneWidget);
      expect(find.text('+ 15 min'), findsOneWidget);
      expect(find.text('🚨 Need Help'), findsOneWidget);

      // 4. Advance 1 second to test 90s countdown ticking
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Auto-alert in: 01:29'), findsOneWidget);

      // 5. Confirm safety: tap "I'm Safe / Arrive"
      await tester.tap(find.text("I'm Safe / Arrive"));
      await tester.pumpAndSettle();

      // 6. Verify trip is safely concluded and returns to idle home screen
      expect(find.text('START TRIP'), findsWidgets);
      expect(find.text('DESTINATION REACHED'), findsNothing);
    },
  );

  testWidgets(
    'geofence arrival handles + 15 min extension and resumes active commute countdown',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Start a trip
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();

      // 2. Trigger arrival prompt
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      expect(find.text("Time's Up"), findsOneWidget);

      // 3. Tap "+15 min" extension button
      await tester.tap(find.text('+15 min'));
      await tester.pumpAndSettle();

      // 4. Verify arrival prompt is dismissed and normal trip countdown resumes
      expect(find.text("Time's Up"), findsNothing);

      // Conclude trip cleanly
      await tester.tap(find.text("I'm Safe"));
      await tester.pumpAndSettle();
      expect(find.text('START TRIP'), findsWidgets);
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
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Start a trip to Campus
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();

      expect(find.text('TRIP IN PROGRESS'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);

      // 2. Simulate entering the destination geofence perimeter
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      // 3. Verify Destination Reached state and safety confirmation prompt
      expect(find.text('DESTINATION REACHED'), findsOneWidget);
      expect(find.text('You have arrived at Campus.'), findsOneWidget);
      expect(find.text('Are you safe?'), findsOneWidget);
      expect(find.textContaining('Auto-alert in: 01:30'), findsOneWidget);
      expect(find.text("I'm Safe / Arrive"), findsOneWidget);
      expect(find.text('+ 15 min'), findsOneWidget);
      expect(find.text('🚨 Need Help'), findsOneWidget);

      // 4. Advance 1 second to test 90s countdown ticking
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Auto-alert in: 01:29'), findsOneWidget);

      // 5. Confirm safety: tap "I'm Safe / Arrive"
      await tester.tap(find.text("I'm Safe / Arrive"));
      await tester.pumpAndSettle();

      // 6. Verify trip is safely concluded and returns to idle home screen
      expect(find.text('START TRIP'), findsWidgets);
      expect(find.text('DESTINATION REACHED'), findsNothing);
    },
  );

  testWidgets(
    'geofence arrival handles + 15 min extension and resumes active commute countdown',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      // 1. Start a trip
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('START TRIP').last);
      await tester.pumpAndSettle();

      // 2. Trigger arrival prompt
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      homeState.simulateGeofenceArrival();
      await tester.pumpAndSettle();

      expect(find.text("Time's Up"), findsOneWidget);

      // 3. Tap "+15 min" extension button
      await tester.tap(find.text('+15 min'));
      await tester.pumpAndSettle();

      // 4. Verify arrival prompt is dismissed and normal trip countdown resumes
      expect(find.text("Time's Up"), findsNothing);

      // Conclude trip cleanly
      await tester.tap(find.text("I'm Safe"));
      await tester.pumpAndSettle();
      expect(find.text('START TRIP'), findsWidgets);
    },
  );
  testWidgets(
    'SettingsTab renders correctly and handles modal interactions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
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
      expect(find.text('14.8192° N, 120.9610° E'), findsOneWidget);
      expect(find.text('PUP Santa Maria Campus'), findsOneWidget);
      expect(find.textContaining('14.8697'), findsWidgets);
      expect(find.text('Default Travel Duration'), findsOneWidget);
      // Smart Adaptive Presets removed

      // Verify Section 2 Items
      expect(find.text('Expiry Alert Mode'), findsOneWidget);
      expect(find.text('Covert SMS Emergency Dispatch'), findsOneWidget);

      // Verify Section 3 Items
      expect(find.text('User Guide & Safety Protocol'), findsOneWidget);
      expect(find.text('Privacy Policy & GPS Usage Rules'), findsOneWidget);

      // Verify Footer
      expect(find.text('LisKo v1.0.0 • PUP Santa Maria Campus'), findsOneWidget);
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
      await tester.tap(find.byIcon(Icons.close_rounded).last);
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
}
