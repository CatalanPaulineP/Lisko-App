# LisKo: A Mobile-Based Student Travel Safety and Emergency Monitoring Application for PUP Santa Maria Students
## SUPER DETAILED CURRENT PROJECT STRUCTURE, EXECUTION FLOW, AND DEFENSE GUIDE

---

### METADATA & SYSTEM INFORMATION
- **AUDIT DATE:** September 21, 2026
- **BRANCH:** `main` (Audited on `main` / `integrate-rain-ui-v2` / `update-user-guide-widget-security`)
- **LATEST COMMIT:** `1a07854dd1b20ec4f7cc409096694a471e8c4677` ("Update user guide for SOS widget and contacts security")
- **FLUTTER VERSION:** `3.41.9` (Channel stable, revision `00b0c91f06`)
- **DART VERSION:** `3.11.5`
- **ANDROID PACKAGE / APPLICATION ID:** `com.lisko.safety`
- **COMPILE SDK / TARGET SDK / MIN SDK:** Compile SDK 36, Target SDK 36, Min SDK 24
- **FIREBASE PROJECT:** `lisko-25162`
- **DOCUMENTATION STATUS:** CURRENT CODE AUDIT (Source of Truth verified directly against production codebase)

---

## VERIFICATION LIMITATIONS
*The following items have been fully audited in source code structure, but physical device hardware / Cloud Console live behavior requires target hardware / console access to observe live:*

1. **NEEDS PHYSICAL DEVICE VERIFICATION:**
   - Real cellular SIM SMS transmission on dual-SIM hardware (`plugins/background_sms` using `SmsManager.getSmsManagerForSubscriptionId(simSlot)`).
   - Real hardware device authentication prompt (`local_auth` / `USE_BIOMETRIC` invoking device PIN, pattern, or fingerprint).
   - Native Android AppWidget pinning interaction (`AppWidgetManager.requestPinAppWidget`) on launcher implementations (e.g. MIUI, One UI, Nova Launcher).
   - Hardware GPS satellite lock time and cold-start TTFF (Time To First Fix) under obstructed urban or indoor conditions.
   - Device OEM aggressive background app killing (e.g. Doze mode / battery optimization on Vivo, Xiaomi, Oppo devices).

2. **NEEDS FIREBASE CONSOLE VERIFICATION:**
   - Live document creation in `trips` and `emergency_events` collections on `lisko-25162`.
   - Security rule execution evaluation on live Firestore dashboard against `firestore.rules`.

---

# PHASE 1 — CURRENT PROJECT AUDIT SUMMARY

LisKo is a offline-first, privacy-conscious travel safety mobile companion designed specifically for Polytechnic University of the Philippines (PUP) Santa Maria students. The application operates **accountlessly** (no user login or Firebase Auth required), using `SharedPreferences` for local data persistence and Cloud Firestore solely as an immutable cloud audit trail for trip activity and emergency alerts.

### Architectural Core Highlights
- **Transient Native SOS Widget:** `SosWidgetProvider.kt` launches `SosEmergencyActivity.kt` (`taskAffinity="com.lisko.safety.sos_widget"`, `excludeFromRecents="true"`), which directly mounts Flutter initial route `/sos_emergency` (`WidgetSosEmergencyScreen`) without launching or disturbing the main app navigation stack.
- **4-State Widget Setup Verification:** `WidgetSosEmergencyScreen` strictly executes `readSetupCompletedStrict()` checking 4 setup states (`checking`, `verifiedIncomplete`, `verificationError`, `readyForSos`). If incomplete, prompts user and finishes via explicit native `Intent.ACTION_MAIN` / `CATEGORY_HOME`.
- **Centralized Emergency Dispatch Service:** `EmergencyDispatchService` consolidates manual SOS, active trip Need Help, timer expiry, and 90-second automatic escalation into a single pipeline (On-demand GPS acquisition $\rightarrow$ offline SIM SMS transmission $\rightarrow$ local history writing $\rightarrow$ Cloud Firestore logging $\rightarrow$ local notifications).
- **Offline SIM SMS Alert System:** Web map URLs (e.g. `https://www.google.com/maps?q=...`) have been completely removed from all SMS templates to prevent Smart/Globe/DITO carrier SMS blocking. Messages use raw plain-text coordinates: `Loc: <address>\nCoordinates: <lat>, <lng>\nSearch these coordinates in Google Maps.`
- **30-Day Trip History Retention Policy:** Local `SharedPreferences` JSON logs are pruned automatically during `readTripHistory()` for records older than 30 days (`now.subtract(Duration(days: 30))`). Cloud Firestore queries in `FirebaseService` filter by `startedAt >= cutoffTimestamp`, with defensive client-side merge filtering guaranteeing old records never render in UI.
- **Phase 1 Interactive Walkthrough Flow:** `WalkthroughOverlay` renders via root `OverlayEntry` in `HomeScreenState`, using `HoleCutoutBlocker` (`RenderProxyBox`) to allow pointer events on highlighted production controls (e.g. `SET UP TRIP`, `SAVE TRIP`) while blocking 100% of background UI.
- **Protect Trusted Contacts Security:** Integrated with `AuthService` (`local_auth`) to lock the Contacts tab using device authentication (PIN, pattern, fingerprint). Protecting contacts does NOT disable emergency SMS functions during an SOS dispatch.

---

# PHASE 2 — OUTDATED OR LEGACY INFORMATION FOUND

| Item | OLD CLAIM | CURRENT IMPLEMENTATION | SOURCE FILE / FUNCTION | WHY IT CHANGED / WHY OLD CLAIM IS WRONG |
| :--- | :--- | :--- | :--- | :--- |
| **Emergency SMS Format** | SMS includes clickable Google Maps URL link (`https://www.google.com/maps?q=...`). | Plain-text address & coordinates: `Loc: <address>\nCoordinates: <lat>, <lng>\nSearch these coordinates in Google Maps.` | `lib/services/sms_alert_service.dart` (`_buildLocationLines`) | Philippine cellular carriers (Smart, Globe, DITO) frequently block or drop SMS containing HTTP/HTTPS links as potential spam or phishing. Plain-text coordinates ensure 100% carrier delivery. |
| **Full-Screen Intent Alarm** | App uses fullScreenIntent to wake phone lock screen during 90-second safety check. | `fullScreenIntent` is NOT used in `NotificationService`. `USE_FULL_SCREEN_INTENT` manifest permission is present, but alarms use high-priority heads-up notifications with vibration and sound. | `lib/services/notification_service.dart` | `fullScreenIntent` requires special Android 14+ permissions (`USE_FULL_SCREEN_INTENT` restriction). Standard high-priority notification channels provide reliable alerts across all Android versions. |
| **History Filter Chips** | TripsTab includes "All", "This Week", and "This Month" filter chips. | "This Month" filter chip was removed. Only "All" and "This Week" remain. | `lib/screens/trips_tab.dart` | "This Month" became redundant after implementing the strict 30-day trip history retention policy. |
| **GPS Diagnostic Tool** | Settings tab includes "TEST GPS CURRENT POSITION (DIAGNOSTIC)" row and `_runGpsDiagnostic()` method. | Action row and diagnostic method were completely removed. Footer updated to "Privacy-Conscious Architecture • Offline-First". | `lib/screens/settings_tab.dart` | Diagnostic tool was a developer utility not suitable for student end-users. |
| **Instant SOS Widget Dispatch** | Home Screen SOS Widget instantly sends SMS with 1 tap without countdown. | Tapping widget launches `WidgetSosEmergencyScreen` which starts the standard 5-second countdown with cancel button. | `lib/screens/widget_sos_emergency_screen.dart` | Prevents accidental pocket emergency triggers and allows students to abort unintended widget taps. |
| **Biometric Contact Locking** | Contacts tab is locked strictly using Biometric Fingerprint scan. | Uses `local_auth` device authentication (`PIN`, `pattern`, `passcode`, `fingerprint`, `face`). | `lib/services/auth_service.dart` (`authenticate()`) | Not all student devices possess fingerprint sensors; fallback to device PIN/pattern ensures 100% device compatibility. |
| **User Guide Sections** | User Guide contains 13 sections. | User Guide now contains 14 sections (Section 7: "SOS Distress Widget" inserted). | `lib/screens/user_guide_screen.dart` | Expanded to document the Home Screen SOS Widget and Protect Trusted Contacts features. |
| **Walkthrough Overlay** | Walkthrough uses static speech bubbles and simulated method calls. | Uses interactive root `OverlayEntry` with `HoleCutoutBlocker` requiring real button taps on `SET UP TRIP` and modal `SAVE TRIP`. | `lib/widgets/walkthrough_overlay.dart`, `lib/screens/main_dashboard_screen.dart` | Provides hands-on interactive tutorial where students learn by performing actual trip staging. |
| **Continuous Live Cloud Tracking** | App streams student GPS location continuously to Cloud Firestore every second. | Zero continuous cloud location streaming. GPS location is acquired on-demand ONLY when an emergency SOS or Need Help alert is dispatched. | `lib/services/geofence_service.dart`, `lib/services/location_service.dart` | Aligns with ISO/IEC 25010 Usability/Privacy and student non-surveillance architecture. |

---

# PHASE 3 — COMPLETE PROJECT DIRECTORY & FILE STRUCTURE MAP

```
C:/Users/Pauline/Lisko/flutter_app/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml                        # Manifest permissions, activities, receivers, services
│       ├── kotlin/com/lisko/safety/
│       │   ├── MainActivity.kt                       # Main entry activity, splash screen, pinSosWidget MethodChannel
│       │   ├── SosEmergencyActivity.kt               # Transient activity for SOS widget, mounts /sos_emergency route
│       │   └── SosWidgetProvider.kt                  # AppWidgetProvider handling Home Screen widget updates & taps
│       └── res/xml/sos_widget_info.xml               # AppWidget metadata configuration
├── assets/
│   └── images/                                       # App logo and map graphic resources
├── docs/                                             # Technical documentation and defense guides
├── firestore.rules                                   # Cloud Firestore schema validation & security rules
├── lib/
│   ├── constants/
│   │   ├── app_colors.dart                           # Semantic palette tokens (canvas, header, primary, success)
│   │   ├── app_icons.dart                            # Icon string identifiers (MaterialSymbols / Carbon)
│   │   └── app_theme.dart                            # Material 3 light theme configuration
│   ├── firebase_options.dart                         # Auto-generated Firebase options for lisko-25162
│   ├── main.dart                                     # Application entry point, LiskoApp, _LaunchGate bootstrapper
│   ├── models/
│   │   └── (Inlined models in firebase_service & local_storage_service)
│   ├── screens/
│   │   ├── active_trip_screen.dart                   # Active commute timer, geofence, arrival confirmation dialogs
│   │   ├── all_notifications_screen.dart             # Full-screen notification history view
│   │   ├── contacts_tab.dart                         # Trusted contacts management, import, Protect Contacts lock
│   │   ├── emergency_alert_screen.dart               # In-app 5-second SOS countdown screen with siren UI
│   │   ├── faq_screen.dart                           # Frequently asked questions screen
│   │   ├── home_tab.dart                             # Primary dashboard tab (header, system ready, trip card, today activity)
│   │   ├── main_dashboard_screen.dart                # HomeScreen coordinator, IndexedStack tab manager, walkthrough entry
│   │   ├── onboarding_flow.dart                      # 3-step setup (contacts, home location, permissions)
│   │   ├── screens.dart                              # Barrel export file for screens
│   │   ├── settings_tab.dart                         # Settings tab (Home location, alert mode, widget detail, contacts protection)
│   │   ├── sos_widget_detail_screen.dart             # SOS widget guide & requestPinAppWidget trigger screen
│   │   ├── splash_screen.dart                        # Initial branded splash screen
│   │   ├── times_up_screen.dart                      # 90-second safety check confirmation screen (arrival / timeout)
│   │   ├── trips_tab.dart                            # Trip history, metrics summary, filters, PDF export trigger
│   │   ├── user_guide_screen.dart                    # 14-section expandable user guide & safety protocol
│   │   ├── welcome_screen.dart                       # Onboarding welcome screen
│   │   └── widget_sos_emergency_screen.dart          # Standalone SOS screen for native widget execution
│   ├── services/
│   │   ├── auth_service.dart                         # Local authentication service (PIN / pattern / biometrics)
│   │   ├── background_service_setup.dart             # flutter_background_service configuration & background isolate
│   │   ├── emergency_dispatch_service.dart           # Centralized SOS & emergency dispatch pipeline
│   │   ├── firebase_service.dart                     # Cloud Firestore sync, trips & emergency_events queries
│   │   ├── geofence_service.dart                     # Geolocator position stream, 150m distance calculation
│   │   ├── local_storage_service.dart                # SharedPreferences read/write, 30-day trip history pruning
│   │   ├── location_service.dart                     # On-demand GPS location acquisition with 5-tier fallback
│   │   ├── notification_service.dart                 # flutter_local_notifications channels & heads-up alarms
│   │   ├── permission_service.dart                   # Runtime permissions requester (SMS, Location, Contacts, Notifications)
│   │   ├── phone_contact_service.dart                # Device contact picker & import integration
│   │   ├── sms_alert_service.dart                    # Background SMS template builder & background_sms invocation
│   │   ├── sos_widget_service.dart                   # MethodChannel bridge to MainActivity pinSosWidget
│   │   └── trip_history_export_service.dart          # PDF generation & share_plus export service
│   └── widgets/
│       ├── action_buttons.dart                       # Custom styled buttons & action controls
│       ├── app_icon.dart                             # Iconify icon renderer widget
│       ├── legal_modals.dart                         # Privacy Policy & Terms of Service modal sheets
│       ├── notifications_popover.dart                # Top-right notification dropdown popover
│       ├── onboarding_header_shell.dart              # Onboarding step header & progress bar shell
│       ├── set_trip_timer_bottom_sheet.dart          # TripSchedulerSheet modal (destination & duration selector)
│       ├── system_status_card.dart                   # SystemReadyCard displaying readiness badges
│       ├── trip_timer_card.dart                      # Home dashboard trip timer & staged trip card
│       ├── walkthrough_overlay.dart                  # 15-step interactive walkthrough overlay with HoleCutoutBlocker
│       └── widgets.dart                              # Barrel export file for widgets
├── plugins/
│   └── background_sms/                               # Local plugin for offline SIM SMS dispatch via SmsManager
├── pubspec.yaml                                      # Package dependencies and asset configurations
└── test/
    └── widget_test.dart                              # Comprehensive automated test suite (27 tests)
```

---

# PHASE 4 — COMPLETE APP STARTUP FLOW

### Execution Sequence (User taps LisKo app icon)
1. **Android Launcher (`Intent.ACTION_MAIN`, `CATEGORY_LAUNCHER`)**
   - Invokes `com.lisko.safety.MainActivity`.
   - Android system executes `installSplashScreen()` from `androidx.core:core-splashscreen`.
2. **`MainActivity.kt` (Subclass of `FlutterFragmentActivity`)**
   - Initializes Android Flutter Engine.
   - Registers `MethodChannel("com.lisko.safety/sos_widget")` for widget pinning.
3. **Dart `main()` (`lib/main.dart`)**
   - Executes `WidgetsFlutterBinding.ensureInitialized()`.
   - Invokes `runApp(const LiskoApp())`.
4. **`LiskoApp.build()` (`lib/main.dart`)**
   - Returns `MaterialApp` with `AppTheme.light`.
   - Evaluates `onGenerateInitialRoutes`:
     - If `initialRoute == '/sos_emergency'`, mounts `WidgetSosEmergencyScreen` (Widget flow).
     - Otherwise, mounts `_LaunchGate` (Main app flow).
5. **`_LaunchGateState.initState()` & `_bootstrapAndNavigate()` (`lib/main.dart`)**
   - Immediately renders `SplashScreen(statusText: 'Preparing LisKo...')` so zero black frames appear.
   - Executes `Future.wait(...)` concurrently:
     - `NotificationService().initialize()`: Creates notification channels (`lisko_active_trip_channel_v2`, `lisko_safety_alerts_v2`, `lisko_emergency_v2`).
     - `initializeBackgroundService()`: Configures `flutter_background_service` Android Foreground Service.
     - `Firebase.initializeApp(...)`: Initializes Firebase instance for `lisko-25162`.
   - Reads `LocalStorageService().readSetupCompleted()`.
   - Reads `LocalStorageService().readActiveTrip()` to check if an active commute was interrupted.
   - Ensures minimum splash delay of 2,000ms for visual smooth transition.
   - Invokes `Navigator.pushReplacement(...)`:
     - If `setupCompleted == true` $\rightarrow$ `HomeScreen()` (`lib/screens/main_dashboard_screen.dart`).
     - If `setupCompleted == false` $\rightarrow$ `WelcomeScreen()` (`lib/screens/welcome_screen.dart`).
   - If `setupCompleted == true`, executes `_dispatchPendingNotificationAction()` to handle any notification action tapped while the app process was terminated.

---

# PHASE 5 — ONBOARDING FLOW

When `readSetupCompleted()` returns `false`, `_LaunchGate` navigates to `WelcomeScreen`.

```
[WelcomeScreen] 
   │
   ├─► Tap "Get Started" ──► [OnboardingFlow (Step 1: Trusted Contacts)]
   │                            │
   │                            ├─► Add 1 to 5 contacts (Manual entry or PhoneContactService)
   │                            ├─► Select relationship (Parent / Guardian / Others)
   │                            └─► First contact marked as Primary (receives Safe Arrival)
   │                            │
   │                            ▼ Tap "Next"
   │                         [OnboardingFlow (Step 2: Home Location)]
   │                            │
   │                            ├─► Set home location while physically at home
   │                            └─► LocationService acquires lat/lng & Geocoding street address
   │                            │
   │                            ▼ Tap "Next"
   │                         [OnboardingFlow (Step 3: Permissions)]
   │                            │
   │                            ├─► Request SMS permission (SEND_SMS)
   │                            ├─► Request Location permission (ACCESS_FINE_LOCATION)
   │                            └─► Request Notification permission (POST_NOTIFICATIONS)
   │                            │
   │                            ▼ Tap "Complete Setup"
   │                         [LocalStorageService]
   │                            ├─► saveSetupCompleted(true)
   │                            ├─► saveWalkthroughCompleted(false)
   │                            └─► Navigator.pushReplacement(HomeScreen())
```

---

# PHASE 6 — MAIN DASHBOARD / TAB ARCHITECTURE

### `HomeScreen` & `HomeScreenState` (`lib/screens/main_dashboard_screen.dart`)
`HomeScreen` is the primary orchestrator and state coordinator of LisKo.

#### Key Responsibilities & Shared State
- **Tab State (`selectedTab`):** Controls active tab in `IndexedStack` (0: Home, 1: Trips, 2: Contacts, 3: Settings).
- **Active Trip State (`tripActive`):** Holds active commute state (`destination`, `remaining`, `totalDuration`, `tripId`, `expectedArrival`).
- **Staged Trip State (`tripStaged`):** Holds staged setup (`stagedDestination`, `stagedDuration`) configured via `TripSchedulerSheet`.
- **Walkthrough State (`showWalkthrough`, `walkthroughStep`):** Coordinates 15-step interactive walkthrough via `_walkthroughOverlayEntry` root `OverlayEntry`.
- **Lifecycle & Restoration (`initState`):** Invokes `_restoreActiveTrip()` to recover active trip if app process was killed by Android.
- **Notification Callback Registration:** Hooks into `NotificationService.onActionReceived` to respond to notification button taps (`I'M SAFE`, `+15 MIN`, `NEED HELP`).

#### Child Tabs Summary
1. **`HomeDashboardTab` (`lib/screens/home_tab.dart`):** Hero header with greeting, `SystemReadyCard`, `TripTimerCard`, `SET UP TRIP` / `START TRIP` button, `SosWarningBox`, and `TodayActivity` activity log.
2. **`TripsTab` (`lib/screens/trips_tab.dart`):** Summary metrics cards, "All" vs "This Week" filter chips, scrollable trip log list, and PDF export action.
3. **`ContactsTab` (`lib/screens/contacts_tab.dart`):** List of trusted contacts (1-5), primary badge indicator, add/edit/delete modal forms, device contact import button, and Protect Trusted Contacts biometric/PIN lock screen.
4. **`SettingsTab` (`lib/screens/settings_tab.dart`):** Home Location Pin setup card, Campus geofence info card, Default travel duration selector, Alert Mode selector, Protect Trusted Contacts toggle, Home Screen SOS Widget guide launcher, User Guide & FAQ links, Legal modal launchers.

---

# PHASE 7 — TRIP SETUP FLOW

```
[HomeDashboardTab] ──► Tap "SET UP TRIP" ──► _openTripScheduler() ──► [TripSchedulerSheet]
                                                                             │
                                                                             ├─► Choose Destination (Campus / Home / Custom)
                                                                             ├─► Choose Travel Duration (Slider / Quick Presets)
                                                                             │
                                                                             ▼ Tap "SAVE TRIP"
                                                                       [HomeScreenState]
                                                                         ├─► tripStaged = true
                                                                         ├─► stagedDestination = selected
                                                                         ├─► stagedDuration = selected
                                                                         └─► Close sheet modal
```

### Critical Distinction: SAVE TRIP vs START TRIP
- **SAVE TRIP (Staging):** Configures `stagedDestination` and `stagedDuration` in memory. Sets `tripStaged = true`. **NO background service starts, NO geofence monitoring executes, NO timer counts down, NO location permissions are consumed.**
- **START TRIP (Execution):** Validates permissions and contacts, creates `tripId`, persists active trip to `SharedPreferences`, starts `flutter_background_service`, initiates `GeofenceService` location stream, logs trip to Cloud Firestore, and mounts `ActiveTripTab`.

---

# PHASE 8 — START TRIP FLOW

When student taps `START TRIP` on `HomeDashboardTab`:

1. **`_startTrip(destination, duration)` invoked in `main_dashboard_screen.dart`.**
2. **Validation Checks:**
   - Evaluates `PermissionService().hasSmsPermission()`. If missing, prompts user.
   - Evaluates `PermissionService().hasLocationPermission()`. If missing, prompts user.
   - Evaluates `LocalStorageService().readTrustedContacts()`. Must have $\ge 1$ contact.
3. **Trip Initialization:**
   - Generates unique `tripId = DateTime.now().millisecondsSinceEpoch.toString()`.
   - Computes `startedAt = DateTime.now()` and `expectedArrivalAt = startedAt.add(duration)`.
   - Writes active trip JSON to `SharedPreferences` via `LocalStorageService().saveActiveTrip(...)`.
4. **Cloud & Service Launch:**
   - Calls `FirebaseService().saveOrUpdateTrip(...)` to write document to Firestore `trips` collection.
   - Calls `NotificationService().showActiveTripNotification(...)` to launch persistent Android notification.
   - Invokes `FlutterBackgroundService().startService()`.
   - Calls `GeofenceService().startMonitoring(...)` passing target coordinates.
5. **UI Transition:**
   - Sets `tripActive = true`, `tripStaged = false`.
   - Switches `HomeDashboardTab` body to `ActiveTripTab` (`lib/screens/active_trip_screen.dart`).

---

# PHASE 9 — ACTIVE TRIP FLOW

While `ActiveTripTab` (`lib/screens/active_trip_screen.dart`) is visible:
- **UI Timer:** Driven by a periodic 1-second `Timer` in `_ActiveTripTabState` updating `remaining` countdown.
- **Source of Truth:** The timer is calculated as `expectedArrivalAt.difference(DateTime.now())`, ensuring that clock drift or UI pauses never cause timing inaccuracies.
- **`+15 Min` Extension:** Invokes `_extendTrip()`, adding 900 seconds to `expectedArrivalAt`, updating local `SharedPreferences`, updating Firestore document (`wasExtended = true`, `status = 'extended'`), and updating `GeofenceService` and background service parameters.
- **`I'M SAFE` Button:** Invokes `_handleSafePressed()`, stopping background service, canceling geofence stream, removing persistent notification, saving safe arrival to local history, updating Firestore document (`status = 'arrived'`), dispatching Safe Arrival SMS to primary contact, and resetting dashboard to resting state.

---

# PHASE 10 — BACKGROUND EXECUTION ARCHITECTURE

When a trip is active and the student presses the Android Home button (or switches apps):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ANDROID SYSTEM PROCESS                          │
├────────────────────────────────────────────────────────────────────────┤
│  1. Main Flutter Isolate (UI Process)                                  │
│     • Enters AppLifecycleState.paused / AppLifecycleState.hidden.       │
│     • Flutter UI frames pause rendering.                               │
│                                                                        │
│  2. Android Foreground Service (id.flutter.flutter_background_service)  │
│     • Promoted to Foreground Service with notification.                │
│     • foregroundServiceType="location" prevents Android 14+ termination│
│                                                                        │
│  3. Background Dart Isolate (onStart function)                          │
│     • Executes independently in background Dart VM isolate.            │
│     • Runs 1-second periodic timer checking expectedArrivalAt.         │
│     • Reads/writes SharedPreferences directly.                        │
│     • Communicates with Foreground UI isolate via ServiceInstance.     │
└────────────────────────────────────────────────────────────────────────┘
```

### Background Service Entry Point (`lib/services/background_service_setup.dart`)
- **Isolate Function:** `@pragma('vm:entry-point') void onStart(ServiceInstance service)`.
- **Background Checks:** Periodically calculates `expectedArrivalAt.difference(DateTime.now())`.
- **Timeout Trigger:** When `remaining <= 0` in background:
  - Invokes `NotificationService().showTimeoutAlarmNotification(...)`.
  - Sends `service.invoke('timeoutDetected')` message to main isolate if alive.
  - Sets `safetyCheckDeadline = DateTime.now().add(Duration(seconds: 90))`.
  - Schedules 90-second automatic escalation timer in background isolate.

---

# PHASE 11 — GEOFENCE / ARRIVAL FLOW

### Geofence Engine (`lib/services/geofence_service.dart`)
- **Target Target Resolution:** Resolves target destination coordinates:
  - `"Campus"` $\rightarrow$ PUP Santa Maria Campus (`14.869725503304737, 120.9990821362761`).
  - `"Home"` $\rightarrow$ Saved home coordinates from `LocalStorageService().readHomeLocation()`.
  - Custom location $\rightarrow$ Lat/lng passed from scheduler.
- **Geolocator Position Stream:** Subscribes to `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))`.
- **Distance Calculation:** Invokes `Geolocator.distanceBetween(currentLat, currentLng, targetLat, targetLng)`.
- **Boundary Threshold:** Compares calculated distance against `150.0` meters (`radiusMeters`).
- **Arrival Trigger:** When `distance <= 150.0` meters:
  - Cancels `Geolocator` position stream to conserve battery.
  - Triggers `onArrival` callback in `HomeScreenState`.
  - Triggers `NotificationService().showArrivalAlarmNotification(...)`.
  - Sets `isArrived = true` and starts 90-second safety check countdown.

---

# PHASE 12 — TIMER EXPIRY FLOW

When `expectedArrivalAt` is reached before student arrives at destination:
1. `remaining <= 0` detected by UI timer or background isolate timer.
2. `NotificationService().showTimeoutAlarmNotification()` fires high-priority alert with sound and vibration.
3. Sets `safetyCheckDeadline = DateTime.now().add(const Duration(seconds: 90))`.
4. Saves `timeout_warning` state to `SharedPreferences`.
5. Updates Firestore trip document status to `'timeout_warning'`.
6. Mounts `TimesUpScreen` or displays arrival/timeout confirmation dialog on active trip view.

---

# PHASE 13 — ARRIVAL / TIMEOUT SAFETY CHECK

When student reaches destination OR timer expires, a **90-second safety check** begins.

```
                  ┌────────────────────────────────────────┐
                  │      90-SECOND SAFETY CHECK PROMPT      │
                  └───────────────────┬────────────────────┘
                                      │
         ┌────────────────────────────┼────────────────────────────┐
         ▼                            ▼                            ▼
   [I'M SAFE]                     [+15 MIN]                   [NEED HELP]
   • Stops service                • Adds 900s to timer        • Triggers immediate
   • Sends Safe Arrival           • Resumes commute             emergency dispatch
     SMS to Primary               • Updates Firestore          • Sends Emergency SMS
   • Logs successful trip           ('extended')                to all contacts
   • Resets dashboard             • Resets 90s prompt          • Logs emergency event
```

---

# PHASE 14 — AUTOMATIC 90-SECOND ESCALATION

If the student does NOT respond to the safety check prompt within 90 seconds:

```
[90-Second Deadline Expires]
   │
   ├─► Claim Escalation Guard (Atomic boolean flag prevents duplicate UI/Background execution)
   │
   ├─► LocationService.acquireEmergencyLocation()
   │      ├─► Tier 1: On-demand high-accuracy GPS fix (10s timeout)
   │      ├─► Tier 2: Geolocator.getLastKnownPosition()
   │      ├─► Tier 3: Active trip start location
   │      └─► Tier 4: Fallback "GPS Location Unavailable"
   │
   ├─► SmsAlertService.sendEmergencySms()
   │      ├─► Builds SMS: "EMERGENCY ALERT: Safety check timed out for [Destination]..."
   │      ├─► Appends raw coordinates & address
   │      └─► Dispatches via BackgroundSms plugin to ALL trusted contacts
   │
   ├─► LocalStorageService.saveTripRecord(status: 'expired')
   │
   ├─► FirebaseService.logEmergencyEvent(type: 'TIMEOUT_ESCALATION')
   │
   └─► Reset active trip state & stop background service
```

---

# PHASE 15 — MANUAL SOS FLOW

When student taps the red SOS warning box on `HomeDashboardTab` or triggers SOS during trip:

```
[Tap SOS Box] ──► [EmergencyAlertScreen]
                        │
                        ├─► Plays 5-second animated visual/haptic countdown
                        ├─► Student can tap "CANCEL" anytime during 5 seconds
                        │
                        ▼ Countdown Completes (0s)
               [EmergencyDispatchService.executeManualSosDispatch()]
                        │
                        ├─► Acquire Emergency Location
                        ├─► Dispatch Emergency SMS to ALL trusted contacts
                        ├─► Play confirmation vibration pattern
                        ├─► Log trip record ('alert' / 'Manual SOS')
                        ├─► Log Cloud Firestore emergency_event ('SOS')
                        └─► Display Emergency Confirmation Dialog
```

---

# PHASE 16 — EMERGENCY DISPATCH SERVICE

`EmergencyDispatchService` (`lib/services/emergency_dispatch_service.dart`) is a thread-safe, centralized singleton orchestrating all emergency flows across LisKo.

### Public API Methods
1. **`executeManualSosDispatch(...)`**: Invoked by in-app Manual SOS button and native SOS widget.
2. **`executeActiveTripNeedHelpDispatch(...)`**: Invoked when student taps `Need Help` during active trip.
3. **`executeAutomaticEscalationDispatch(...)`**: Invoked when 90-second safety check times out without response.

### Unified Pipeline Execution
```
acquireEmergencyLocation() ──► readTrustedContacts() ──► sendEmergencySms() ──► saveTripRecord() ──► logEmergencyEvent()
```

---

# PHASE 17 — LOCATION SERVICE

`LocationService` (`lib/services/location_service.dart`) provides on-demand GPS coordinates during emergencies, separate from `GeofenceService`'s continuous position stream.

### Why LisKo Needs Both Services
- **`GeofenceService`:** Manages low-power position streaming during active commutes to detect when student enters the 150m destination radius.
- **`LocationService`:** Executes an immediate high-priority 5-tier fallback location acquisition when an emergency alert is triggered.

### 5-Tier Emergency Location Fallback Strategy
1. **Tier 1 (High Accuracy GPS):** `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10))`.
2. **Tier 2 (Medium Accuracy GPS):** `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5))`.
3. **Tier 3 (Last Known Position):** `Geolocator.getLastKnownPosition()`.
4. **Tier 4 (Active Trip Start Location):** Uses `startLocationLat` / `startLocationLng` saved in `SharedPreferences`.
5. **Tier 5 (GPS Disabled Fallback):** Returns `null`, causing `SmsAlertService` to append `Loc: GPS Location Unavailable`.

---

# PHASE 18 — SMS FLOW

### SMS Transmission Pipeline
```
[SmsAlertService] ──► [BackgroundSms Plugin] ──► [BackgroundSmsPlugin.java] ──► [Android SmsManager] ──► [SIM Hardware] ──► [Cellular Carrier] ──► [Trusted Contact]
```

### Current Production SMS Templates
1. **Manual SOS / Need Help:**
   ```
   EMERGENCY ALERT: Manual SOS triggered by LisKo Safety App.
   Loc: Brgy. Poblacion, Santa Maria, Bulacan
   Coordinates: 14.819200, 120.961000
   Search these coordinates in Google Maps.
   ```
2. **Timeout Escalation:**
   ```
   EMERGENCY ALERT: Safety check timed out for Campus. Student did not confirm safe arrival.
   Loc: Brgy. Caypombo, Santa Maria, Bulacan
   Coordinates: 14.869726, 120.999082
   Search these coordinates in Google Maps.
   ```
3. **Safe Arrival:**
   ```
   LisKo Safety Alert: I have safely arrived at Campus.
   ```

---

# PHASE 19 — HOME SCREEN SOS WIDGET ARCHITECTURE

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ANDROID HOME SCREEN WIDGET                      │
├────────────────────────────────────────────────────────────────────────┤
│  1. LisKo SOS AppWidget (SosWidgetProvider.kt)                         │
│     • User taps widget container on Android Home Screen.               │
│     • Fires PendingIntent targeting SosEmergencyActivity.kt.           │
│                                                                        │
│  2. Transient Native Activity (SosEmergencyActivity.kt)                │
│     • Launched with taskAffinity="com.lisko.safety.sos_widget".        │
│     • excludeFromRecents="true", showWhenLocked="true".                │
│     • Directly mounts getInitialRoute() = "/sos_emergency".            │
│                                                                        │
│  3. Standalone Flutter Screen (WidgetSosEmergencyScreen)               │
│     • Bypasses main app _LaunchGate and navigation stack.              │
│     • Executes readSetupCompletedStrict() 4-state verification.         │
│     • Renders 5-second countdown with CANCEL button.                   │
│     • On completion: Calls EmergencyDispatchService.                   │
│     • Finishes activity via native Intent.ACTION_MAIN / CATEGORY_HOME. │
└────────────────────────────────────────────────────────────────────────┘
```

---

# PHASE 20 — TRUSTED CONTACTS & SECURITY

- **Contact Limits:** Supports 1 to 5 trusted contacts.
- **Primary Contact:** First contact in list receives Safe Arrival SMS messages; all contacts receive emergency SOS alerts.
- **Phone Normalization:** Automatically strips spaces and formatting, normalizing numbers to Philippine format (`+639xx` or `09xx`).
- **Device Import:** Integrates `flutter_contacts` (`PhoneContactService`) to import contacts directly from phonebook.

### Protect Trusted Contacts (`lib/services/auth_service.dart`)
- **Settings Toggle:** Enabling "Protect Trusted Contacts" locks the Contacts tab.
- **`AuthService.authenticate()`:** Invokes `local_auth` plugin requesting device authentication (`PIN`, `pattern`, `passcode`, `fingerprint`, `face`).
- **Uncompromised Emergency Dispatch:** Locking the Contacts tab protects contact details from unauthorized editing, BUT does **NOT** block `EmergencyDispatchService` from reading stored contacts during an automated emergency dispatch.

---

# PHASE 21 — TRIPS / HISTORY & 30-DAY RETENTION

### Local & Cloud Trip Synchronization
- **Local Logs:** Saved as JSON array in `SharedPreferences` (`lisko_trip_history`).
- **Cloud Logs:** Saved to Cloud Firestore `trips` collection (`installationId`).
- **30-Day Retention Implementation:**
  - **Local Pruning:** `LocalStorageService().readTripHistory()` automatically calculates `cutoff = DateTime.now().subtract(const Duration(days: 30))`, filters out older entries, and saves pruned list back to disk.
  - **Cloud Cutoff Query:** `FirebaseService().getTrips()` queries Firestore with `where('startedAt', isGreaterThanOrEqualTo: cutoffTimestamp)`.
  - **Defensive Merge Filter:** `_emitCombinedTrips()` applies client-side timestamp cutoff filtering, ensuring legacy records never reach the UI stream.
- **PDF History Export:** `TripHistoryExportService` uses `pdf` and `share_plus` packages to compile a formatted PDF safety report excluding private contact data, allowing students to save or share travel logs.

---

# PHASE 22 — SETTINGS

- **Home Location Pin:** Captures current physical location as Home coordinates for geofencing.
- **Campus Geofence Info:** Displays PUP Santa Maria campus coordinates and 150m boundary info.
- **Default Travel Duration:** Configures default commute time (15, 30, 45, 60 mins).
- **Alert Mode:** Selects notification behavior (`Sound & Vibration`, `Vibration Only`, `Silent`).
- **Protect Trusted Contacts:** Toggles device authentication lock for Contacts tab.
- **Home Screen SOS Widget:** Opens `SosWidgetDetailScreen` and triggers `requestPinAppWidget`.
- **User Guide & FAQ:** Navigates to `UserGuideScreen` (14 sections) and `FaqScreen`.
- **Legal Modals:** Displays Privacy Policy and Terms of Service modal sheets.

---

# PHASE 23 — NOTIFICATION ARCHITECTURE

### Production Notification Channels (`lib/services/notification_service.dart`)
1. **`lisko_active_trip_channel_v2`:**
   - Name: `Active Trip Monitor`
   - Importance: `Importance.low` (Ongoing persistent notification during commutes).
2. **`lisko_safety_alerts_v2`:**
   - Name: `Safety Confirmation Alerts`
   - Importance: `Importance.max` / `Priority.high` (Arrival and timeout 90-second safety check alarms with custom sound and vibration).
3. **`lisko_emergency_v2`:**
   - Name: `Emergency SOS Alerts`
   - Importance: `Importance.max` / `Priority.high` (Emergency SMS dispatch confirmation alerts).

---

# PHASE 24 — FIREBASE / FIRESTORE ARCHITECTURE

### Collections Schema (`firestore.rules`)
1. **`trips` Collection:**
   - `installationId` (string, required)
   - `destination` (string, required)
   - `estimatedTravelMinutes` (int, required)
   - `startedAt` (timestamp, required)
   - `status` (string, required: `active`, `timeout_warning`, `arrived`, `extended`, `cancelled`, `help_requested`, `expired`)
   - `expectedArrivalAt` (timestamp, optional)
   - `completedAt` (timestamp, optional)
   - `startLocationLat` / `startLocationLng` (number, optional)
   - `wasExtended` (bool, optional)
2. **`emergency_events` Collection (Immutable Audit Log):**
   - `installationId` (string, required)
   - `deviceId` (string, required)
   - `tripId` (string, required)
   - `latitude` / `longitude` (number, required)
   - `emergencyType` (string: `SOS`, `TIMEOUT_ESCALATION`)
   - `triggeredAt` (timestamp, required)
   - `status` (string: `active`)

*Security Enforcement:* Deletions are forbidden (`allow delete: if false;`). `emergency_events` are strictly immutable (`allow update: if false;`).

---

# PHASE 25 — LOCAL STORAGE (SHAREDPREFERENCES KEYS MAP)

| Key Name | Data Type | Written By | Read By | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `setup_completed` | `bool` | `OnboardingFlow` | `_LaunchGate` | Tracks whether student completed initial setup. |
| `installation_id` | `String` | `LocalStorageService` | `FirebaseService` | Unique UUID identifying device installation without account login. |
| `trusted_contacts` | `String` (JSON) | `ContactsTab` / `Onboarding` | `EmergencyDispatchService` | Stores 1-5 trusted contact objects (name, phone, relationship, isPrimary). |
| `home_location` | `String` (JSON) | `SettingsTab` / `Onboarding` | `GeofenceService` | Stores saved Home coordinates (`latitude`, `longitude`, `address`). |
| `active_trip` | `String` (JSON) | `HomeScreenState` | `_LaunchGate` / Background | Stores active trip state for process restoration after kill. |
| `lisko_trip_history` | `String` (JSON) | `LocalStorageService` | `TripsTab` | Stores local trip history array (pruned to 30 days). |
| `walkthrough_completed_v2` | `bool` | `WalkthroughOverlay` | `HomeScreenState` | Tracks whether student completed or dismissed interactive walkthrough. |
| `protect_contacts_enabled` | `bool` | `SettingsTab` | `ContactsTab` | Tracks whether Protect Trusted Contacts biometric/PIN lock is active. |
| `read_notification_ids` | `String` (JSON) | `HomeHeader` | `HomeHeader` | Tracks IDs of notifications read in popover overlay. |

---

# PHASE 26 — PERMISSIONS

| Permission Name | Android Manifest Constant | Type | Purpose | If Denied |
| :--- | :--- | :--- | :--- | :--- |
| **SMS Transmission** | `android.permission.SEND_SMS` | Runtime | Dispatches emergency SMS to trusted contacts without opening default messaging app. | SOS alerts cannot be transmitted via cellular network. Prompts user before trip start. |
| **Fine Location** | `android.permission.ACCESS_FINE_LOCATION` | Runtime | High-accuracy GPS for geofencing and emergency location fix. | Geofencing and location inclusion in emergency SMS disabled. |
| **Coarse Location** | `android.permission.ACCESS_COARSE_LOCATION` | Runtime | Cellular/Wi-Fi network location fallback. | Reduced location accuracy during emergencies. |
| **Notifications** | `android.permission.POST_NOTIFICATIONS` | Runtime | Displays persistent trip status and safety check heads-up alerts. | Travel alerts and safety confirmation prompts hidden from lock screen. |
| **Read Contacts** | `android.permission.READ_CONTACTS` | Runtime | Allows importing trusted contacts directly from phonebook. | Student must type contact names and numbers manually. |
| **Biometric / Device Auth** | `android.permission.USE_BIOMETRIC` | Manifest | Supports device authentication for Protect Trusted Contacts. | Falls back to device PIN/pattern. |
| **Foreground Service** | `android.permission.FOREGROUND_SERVICE_LOCATION` | Manifest | Required on Android 14+ (API 34+) for background location monitoring during trips. | Background service terminated by Android 14+. |

---

# PHASE 27 — UI VS CONTROLLER VS SERVICE VS NATIVE LAYER MAP

| File Name | Architectural Layer | Key Responsibility |
| :--- | :--- | :--- |
| `lib/main.dart` | Application Bootstrapper | Binary messenger init, splash screen, launch gate routing. |
| `main_dashboard_screen.dart` | Controller / Orchestrator | State management, tab coordination, trip lifecycle execution. |
| `home_tab.dart` | UI View | Hero dashboard, trip card, start button, SOS trigger, today activity. |
| `active_trip_screen.dart` | UI / Controller View | Active commute countdown timer, geofence arrival prompt, extension. |
| `emergency_dispatch_service.dart`| Domain / Emergency Service | Centralized emergency dispatch pipeline (Location $\rightarrow$ SMS $\rightarrow$ History $\rightarrow$ Firestore). |
| `geofence_service.dart` | Domain / Location Engine | Low-power GPS position stream, 150m destination radius calculation. |
| `location_service.dart` | Domain / Emergency GPS | On-demand 5-tier fallback location acquisition. |
| `sms_alert_service.dart` | Domain / Communication | Plain-text SMS template generation, `background_sms` invocation. |
| `local_storage_service.dart` | Data / Storage Layer | `SharedPreferences` read/write, 30-day trip history pruning. |
| `firebase_service.dart` | Data / Cloud Sync | Cloud Firestore synchronization (`trips` & `emergency_events`). |
| `MainActivity.kt` | Native Android Bridge | Splash screen, Flutter engine config, `pinSosWidget` MethodChannel. |
| `SosEmergencyActivity.kt` | Native Android Transient | Isolated activity for SOS widget, mounts `/sos_emergency` Flutter route. |
| `SosWidgetProvider.kt` | Native Android AppWidget | Home screen widget provider broadcasting tap events. |
| `BackgroundSmsPlugin.java` | Native Java Plugin Bridge | Invokes Android `SmsManager` for direct SMS sending. |

---

# PHASE 28 — FUNCTION CALL MAP ("WHO CALLS WHO")

```
main() [main.dart]
 └──> LiskoApp [main.dart]
       └──> _LaunchGate [main.dart]
             ├──> NotificationService().initialize()
             ├──> initializeBackgroundService()
             ├──> Firebase.initializeApp()
             └──> Navigator.pushReplacement(HomeScreen())
                   └──> HomeScreenState.initState() [main_dashboard_screen.dart]
                         └──> _restoreActiveTrip()
```

```
_startTrip() [main_dashboard_screen.dart]
 ├──> PermissionService().hasSmsPermission()
 ├──> LocalStorageService().saveActiveTrip()
 ├──> FirebaseService().saveOrUpdateTrip()
 ├──> NotificationService().showActiveTripNotification()
 ├──> FlutterBackgroundService().startService()
 └──> GeofenceService().startMonitoring()
       └──> Geolocator.getPositionStream()
             └──> _handleArrivalDetected() [main_dashboard_screen.dart]
                   └──> NotificationService().showArrivalAlarmNotification()
```

```
EmergencyDispatchService.executeManualSosDispatch() [emergency_dispatch_service.dart]
 ├──> LocationService().acquireEmergencyLocation()
 ├──> LocalStorageService().readTrustedContacts()
 ├──> SmsAlertService().sendEmergencySms()
 ├──> LocalStorageService().saveTripRecord()
 └──> FirebaseService().logEmergencyEvent()
```

---

# PHASE 29 — STATE VARIABLE MAP

| Variable Name | Type | Class / Scope | Purpose & Lifecycle |
| :--- | :--- | :--- | :--- |
| `selectedTab` | `int` | `HomeScreenState` | Active navigation tab index (0: Home, 1: Trips, 2: Contacts, 3: Settings). |
| `tripActive` | `bool` | `HomeScreenState` | Controls whether an active commute is currently executing. |
| `tripStaged` | `bool` | `HomeScreenState` | Controls whether a staged trip setup is saved and waiting to start. |
| `stagedDestination` | `String` | `HomeScreenState` | Selected destination name for staged trip ("Campus", "Home", etc.). |
| `stagedDuration` | `Duration` | `HomeScreenState` | Selected duration for staged trip. |
| `expectedArrival` | `DateTime?` | `HomeScreenState` | Absolute timestamp when active trip is scheduled to complete. |
| `remaining` | `Duration` | `HomeScreenState` | Live remaining countdown duration derived from `expectedArrival`. |
| `showWalkthrough` | `bool` | `HomeScreenState` | Controls rendering of `WalkthroughOverlay` root `OverlayEntry`. |
| `walkthroughStep` | `int` | `HomeScreenState` | Active step index (0-15) in interactive walkthrough sequence. |
| `_expandedIndex` | `int?` | `_UserGuideScreenState` | Tracks expanded accordion card index in User Guide (null = all collapsed). |

---

# PHASE 30 — FAILURE / EDGE CASE FLOWS

1. **No Trusted Contacts Added:**
   - `_startTrip()` and SOS trigger detect zero contacts.
   - App displays `AlertDialog` prompting student to add at least 1 trusted contact in Contacts tab before proceeding.
2. **SMS Permission Denied:**
   - `PermissionService` detects missing `SEND_SMS` permission.
   - Displays rationale dialog explaining cellular SMS is required for emergency dispatch.
3. **GPS Turned Off on Phone:**
   - `LocationService` Tier 1 & 2 fail.
   - Falls back to Tier 3 (Last known position) $\rightarrow$ Tier 4 (Trip start location) $\rightarrow$ Tier 5 (`Loc: GPS Location Unavailable`).
   - SMS is **STILL SENT** to contacts with timestamp and status; dispatch is never blocked by GPS failure.
4. **No Internet / Cellular Data:**
   - Cloud Firestore sync queues locally.
   - **Emergency SMS is unaffected** because SMS operates over GSM/cellular voice network, requiring zero internet data.
5. **App Process Killed by Android OS:**
   - `_restoreActiveTrip()` reads `lisko_active_trip` JSON from `SharedPreferences` on boot.
   - Recovers destination, `expectedArrival`, calculates updated `remaining` time, and resumes UI timer seamlessly.

---

# PHASE 31 — COMPLETE END-TO-END FLOWCHARTS

### 1. START TRIP FLOW
```
[User Taps START TRIP]
  ↓
[main_dashboard_screen.dart: _startTrip()]
  ↓
[Check Permissions & Contacts] ──► Denied ──► [Show Permission / Contact Dialog]
  ↓ Approved
[LocalStorageService: saveActiveTrip()]
  ↓
[FirebaseService: saveOrUpdateTrip('active')]
  ↓
[NotificationService: showActiveTripNotification()]
  ↓
[FlutterBackgroundService: startService()]
  ↓
[GeofenceService: startMonitoring()]
  ↓
[UI: Mount ActiveTripTab]
```

### 2. AUTOMATIC 90-SECOND ESCALATION FLOW
```
[90s Safety Check Countdown Reaches 0s]
  ↓
[Claim Escalation Guard (Atomic Flag)]
  ↓
[LocationService: acquireEmergencyLocation()]
  ↓
[SmsAlertService: sendEmergencySms('TIMEOUT_ESCALATION')]
  ↓
[LocalStorageService: saveTripRecord('expired')]
  ↓
[FirebaseService: logEmergencyEvent('TIMEOUT_ESCALATION')]
  ↓
[Reset Trip & Stop Background Service]
```

### 3. NATIVE SOS WIDGET FLOW
```
[User Taps Home Screen SOS Widget]
  ↓
[SosWidgetProvider.kt: PendingIntent]
  ↓
[SosEmergencyActivity.kt (taskAffinity="sos_widget")]
  ↓
[WidgetSosEmergencyScreen (/sos_emergency)]
  ↓
[Check Setup Completed] ──► Incomplete ──► [Prompt & Return to Home via ACTION_MAIN]
  ↓ Complete
[5-Second Countdown UI] ──► User Taps Cancel ──► [Finish Activity]
  ↓ Completes (0s)
[EmergencyDispatchService: executeManualSosDispatch()]
  ↓
[Finish Activity & Return to Android Home]
```

---

# PHASE 32 — DEFENSE PREPARATION

### Top 10 High-Frequency Technical Defense Questions

#### Q1: Why did your team use offline SMS instead of an internet-based server alert system?
- **Short Answer:** Cellular SMS operates over the GSM voice network without requiring internet data, making it reliable in poor coverage areas in Bulacan.
- **Detailed Answer:** Many commuting students do not have continuous mobile data subscriptions or lose internet connectivity along travel routes between PUP Santa Maria and rural barangays. SMS uses the phone's native SIM card capability to transmit emergency alerts reliably without depending on Wi-Fi or 4G/5G data networks.
- **File to Open:** `lib/services/sms_alert_service.dart`

#### Q2: How does LisKo monitor student arrival without draining the phone battery?
- **Short Answer:** We use `GeofenceService` with a 150-meter destination boundary radius and a 10-meter distance filter, stopping the stream immediately upon arrival.
- **Detailed Answer:** Rather than continuous cloud location tracking, `GeofenceService` listens to local `Geolocator` position updates filtered by a 10-meter distance threshold. When distance to the target (`Campus` or `Home`) drops below 150 meters, arrival is confirmed and the location listener is immediately canceled.
- **File to Open:** `lib/services/geofence_service.dart`

#### Q3: Why is the app accountless? How do you identify users without Firebase Authentication?
- **Short Answer:** Accountless architecture protects student privacy and eliminates login barriers, using a unique local `installationId` UUID for cloud audit logging.
- **Detailed Answer:** Requiring accounts introduces friction during emergency setup and stores sensitive PII on cloud servers. LisKo generates a cryptographic `installationId` UUID stored in `SharedPreferences` upon installation. Trusted contacts and home location coordinates remain strictly on the local device.
- **File to Open:** `lib/services/local_storage_service.dart` (`readInstallationId`)

#### Q4: What happens if the student's phone loses GPS lock during an emergency?
- **Short Answer:** `LocationService` executes a 5-tier emergency location fallback strategy, guaranteeing that an SMS is sent even if GPS fails completely.
- **Detailed Answer:** `LocationService` attempts high-accuracy GPS (10s), medium-accuracy GPS (5s), last known position, and active trip start location. If all fail, it returns `null`, and `SmsAlertService` appends `Loc: GPS Location Unavailable`. The emergency SMS is never blocked by GPS failure.
- **File to Open:** `lib/services/location_service.dart`

#### Q5: How does the Home Screen SOS Widget work without opening the main app?
- **Short Answer:** The widget uses a dedicated, transient native activity (`SosEmergencyActivity.kt`) with `taskAffinity="sos_widget"` that directly mounts the `/sos_emergency` Flutter route.
- **Detailed Answer:** `SosWidgetProvider.kt` attaches a `PendingIntent` launching `SosEmergencyActivity.kt`. This activity is configured with `excludeFromRecents="true"` and `taskAffinity="com.lisko.safety.sos_widget"`, directly rendering `WidgetSosEmergencyScreen` for a clean, non-intrusive 5-second countdown overlay.
- **File to Open:** `android/app/src/main/kotlin/com/lisko/safety/SosEmergencyActivity.kt`

#### Q6: How do you prevent duplicate emergency SMS messages if both the background service and UI detect a timeout simultaneously?
- **Short Answer:** We use an atomic `_isEscalating` claim flag in `main_dashboard_screen.dart` and `EmergencyDispatchService`.
- **Detailed Answer:** When the 90-second safety check expires, the executing thread must atomically claim the escalation lock (`claimAutomaticEscalation()`). If another thread or background callback attempts to escalate simultaneously, the claim returns `false` and the duplicate execution is aborted.
- **File to Open:** `lib/services/emergency_dispatch_service.dart`

#### Q7: How are trusted contacts protected from unauthorized editing?
- **Short Answer:** Enabling "Protect Trusted Contacts" uses `local_auth` device authentication (PIN, pattern, fingerprint) to lock the Contacts tab.
- **Detailed Answer:** When `protect_contacts_enabled` is true, opening `ContactsTab` invokes `AuthService.authenticate()`, requiring device PIN/pattern or biometrics. Importantly, this lock protects the UI editing forms but does NOT block `EmergencyDispatchService` from reading stored contacts during an automated emergency.
- **File to Open:** `lib/services/auth_service.dart`

#### Q8: Why were web map URLs removed from your emergency SMS messages?
- **Short Answer:** Philippine cellular carriers (Smart, Globe, DITO) frequently filter or block SMS messages containing HTTP/HTTPS web links as potential spam.
- **Detailed Answer:** Carrier SMS anti-spam filters automatically drop messages containing URLs (`https://maps.google.com/?q=...`). Replaced with plain-text address and raw coordinates (`Coordinates: 14.869726, 120.999082`), ensuring 100% carrier delivery success while allowing contacts to copy/search coordinates in Maps.
- **File to Open:** `lib/services/sms_alert_service.dart` (`_buildLocationLines`)

#### Q9: How does the 30-day trip history retention policy work?
- **Short Answer:** Local JSON logs are pruned during `readTripHistory()`, and Firestore queries enforce `startedAt >= cutoffTimestamp` with client-side defensive filtering.
- **Detailed Answer:** `LocalStorageService.readTripHistory()` calculates `cutoff = now - 30 days`, removes older JSON entries, and writes the pruned list back to disk. Cloud Firestore queries filter by timestamp, and `_emitCombinedTrips()` applies client-side filtering as a defensive layer.
- **File to Open:** `lib/services/local_storage_service.dart` (`readTripHistory`)

#### Q10: What security rules enforce data integrity in Cloud Firestore?
- **Short Answer:** `firestore.rules` enforces key presence, numeric coordinate bounds, immutable timestamps, and forbids document deletions (`allow delete: if false`).
- **Detailed Answer:** Firestore rules validate allowed status strings, enforce strict field key checking, restrict lat/lng values to valid geographic ranges (-90 to 90, -180 to 180), require immutable `startedAt` timestamps on updates, and completely disable deletion on `trips` and `emergency_events` collections.
- **File to Open:** `firestore.rules`

---

# PHASE 33 — SIMPLE EXPLANATION VERSION (TAGLISH & ANALOGIES)

| Component | Technical Summary | Simple Taglish Explanation | Real-World Analogy |
| :--- | :--- | :--- | :--- |
| **`GeofenceService`** | Monitors device position and compares it against a 150m destination radius. | Siya yung taga-check kung malapit na ba talaga yung student sa PUP o sa bahay. | Parang guard sa gate na nagche-check kung nakapasok ka na sa campus boundary. |
| **`EmergencyDispatchService`** | Centralized pipeline executing emergency location acquisition, SMS dispatch, and audit logging. | Siya yung taga-padala ng saklolo kapag nag-SOS o nag-timeout ang student. | Parang emergency 911 operator na nagpapadala agad ng tulong at mensahe. |
| **`LocationService`** | 5-tier fallback location engine acquiring GPS coordinates on demand. | Siya yung taga-hanap ng eksaktong kinaroroonan ng student gamit ang GPS. | Parang compass at mapa na hahanapin ang kinaroroonan mo kahit mahina ang signal. |
| **`SmsAlertService`** | Builds plain-text alert templates and invokes `background_sms` plugin. | Siya yung taga-gawa at taga-text ng emergency message sa trusted contacts. | Parang taga-hatid ng telegrama na siguradong makakarating kahit walang internet. |
| **`BackgroundSmsPlugin`** | Native Java plugin invoking Android `SmsManager` directly over cellular network. | Yung tulay sa Android phone para makapag-send ng SMS nang hindi binubuksan ang Messages app. | Parang direktang linya sa cell tower. |
| **`SosWidgetProvider`** | Native Android AppWidget broadcasting home screen SOS widget tap events. | Widget sa Home Screen ng phone para mabilis makapag-SOS ang student. | Parang panic button sa dingding ng bahay. |

---

# PHASE 34 — DEFENSE CHEAT SHEET

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                LISKO DEFENSE CHEAT SHEET                                │
├───────────────────────────────┬───────────────────────────────────┬─────────────────────┤
│ FEATURE / SURFACE             │ MAIN SOURCE FILE                  │ KEY FUNCTION        │
├───────────────────────────────┼───────────────────────────────────┼─────────────────────┤
│ App Startup & Gate            │ lib/main.dart                     │ _bootstrapAndNavigate│
│ Main Dashboard & State        │ lib/screens/main_dashboard_screen.dart│ _startTrip / _restoreTrip│
│ Emergency Dispatch Pipeline   │ lib/services/emergency_dispatch_service.dart│ executeManualSosDispatch│
│ Emergency GPS Location        │ lib/services/location_service.dart│ acquireEmergencyLocation│
│ Geofence Arrival Stream       │ lib/services/geofence_service.dart│ startMonitoring     │
│ Offline SIM SMS Alert         │ lib/services/sms_alert_service.dart│ sendEmergencySms    │
│ Local Data Persistence        │ lib/services/local_storage_service.dart│ readTripHistory    │
│ Cloud Firestore Sync          │ lib/services/firebase_service.dart│ saveOrUpdateTrip    │
│ Native SOS Widget Activity    │ android/.../SosEmergencyActivity.kt│ returnToHomeAndFinish│
│ Native SOS Widget Receiver    │ android/.../SosWidgetProvider.kt  │ updateAppWidget     │
│ Native Java SMS Plugin        │ plugins/background_sms/.../BackgroundSmsPlugin.java│ sendSMS │
│ Contact Security & Auth       │ lib/services/auth_service.dart    │ authenticate        │
│ PDF History Export            │ lib/services/trip_history_export_service.dart│ generatePdfReport│
│ Interactive Walkthrough       │ lib/widgets/walkthrough_overlay.dart│ HoleCutoutBlocker  │
│ Cloud Security Rules          │ firestore.rules                   │ isValidTripSchema   │
└───────────────────────────────┴───────────────────────────────────┴─────────────────────┘
```
