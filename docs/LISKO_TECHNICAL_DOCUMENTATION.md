# LisKo Mobile Safety Application - Technical Documentation & Defense Guide

> **System Overview**: LisKo is a privacy-preserving, local-first mobile safety application built for students commuting to and from **Polytechnic University of the Philippines (PUP) Santa Maria Campus**. It provides real-time commute monitoring, automated arrival detection via geofencing, timed safety check-ins, and offline emergency SMS alerts with clickable Google Maps location links dispatched directly through Android SIM hardware.

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Is LisKo Frontend or Backend?](#2-is-lisko-frontend-or-backend)
3. [Complete Application Flow](#3-complete-application-flow)
4. [Start Trip Flow](#4-start-trip-flow)
5. [Destination & Geofence Flow](#5-destination--geofence-flow)
6. [Emergency & Safety Flow](#6-emergency--safety-flow)
7. [GPS Acquisition Flow](#7-gps-flow)
8. [SMS Emergency Alert Flow](#8-sms-flow)
9. [Trusted Contact Import & Management Flow](#9-trusted-contact-flow)
10. [Notification Architecture](#10-notification-flow)
11. [Background Execution & Services](#11-background-execution)
12. [Why LisKo Uses a Local-First Approach](#12-why-lisko-uses-a-local-first-approach)
13. [Data Flow Diagrams](#13-data-flow)
14. [Firebase Data Documentation](#14-firebase-data-documentation)
15. [File-by-File Technical Reference](#15-file-by-file-reference)
16. [Panel Defense Quick Guide ("If the Panelist Asks...")](#16-panel-defense-quick-guide)
17. [Important Algorithms & Logic](#17-important-algorithms)
18. [Android Permissions Reference](#18-android-permissions)
19. [Outdated Claims & Documentation Corrections](#19-outdated-claims--documentation-corrections)

---

## 1. Architecture Overview

LisKo uses a **Local-First, Zero-Surveillance Architecture**. All core safety functions—geofence monitoring, countdown timers, safety response checks, and emergency SMS alert dispatches—run **100% on the user's mobile device** without requiring cloud servers or active internet connections.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        USER MOBILE DEVICE (ANDROID)                    │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    PRESENTATION / UI LAYER                       │  │
│  │  (HomeScreen, ActiveTripTab, EmergencyAlertScreen, TimesUpScreen)│  │
│  └─────────────────────────────────┬────────────────────────────────┘  │
│                                    │                                   │
│  ┌─────────────────────────────────▼────────────────────────────────┐  │
│  │               APPLICATION LOGIC / COORDINATION                   │  │
│  │   (HomeScreenState, _LaunchGate, PermissionService, Controller)  │  │
│  └────────┬────────────────────────┬────────────────────────┬───────┘  │
│           │                        │                        │          │
│  ┌────────▼──────────┐   ┌─────────▼──────────┐   ┌─────────▼───────┐  │
│  │   LOCAL STORAGE   │   │  LOCATION SERVICE  │   │   SMS SERVICE   │  │
│  │(SharedPreferences)│   │ (Stream + Hybrid)  │   │ (BackgroundSms) │  │
│  └────────┬──────────┘   └─────────┬──────────┘   └─────────┬───────┘  │
│           │                        │                        │          │
└───────────┼────────────────────────┼────────────────────────┼──────────┘
            │                        │                        │
            ▼                        ▼                        ▼
    ┌───────────────┐        ┌───────────────┐        ┌───────────────┐
    │ FIRESTORE DB  │        │   GPS ENGINE  │        │  SIM HARDWARE │
    │ (Cloud Log)   │        │ (Device Chip) │        │ (Offline SMS) │
    └───────────────┘        └───────────────┘        └───────────────┘
```

### Architectural Layers
1. **Presentation / UI Layer (`lib/screens/`, `lib/widgets/`, `lib/constants/`)**: Built with Jetpack-inspired Material 3 widgets, rendering dashboard tabs, active timer cards, bottom sheets, and full-screen emergency screens.
2. **Application Logic Layer (`main_dashboard_screen.dart` / `HomeScreenState`)**: Acts as the central orchestrator. Manages state transitions, coordinates geofence listeners, evaluates travel timer countdowns, and triggers emergency escalation.
3. **Local Storage Layer (`LocalStorageService` using `SharedPreferences`)**: Persists user setup status, saved trusted contacts, current active trip data, custom home geofence coordinates, and local trip history.
4. **Cloud Layer (`FirebaseService` using `FirebaseFirestore`)**: Acts as an **optional, non-blocking telemetry log**. Used to record trip summaries and emergency events when internet is available. Never blocks core safety alerts.
5. **Android Native Platform Layer (`geolocator`, `background_sms`, `flutter_local_notifications`, `flutter_background_service`, `vibration`, `flutter_contacts`)**: Interfaces with physical Android OS APIs to access GPS hardware, send offline SIM SMS messages, trigger haptic vibration motors, and manage foreground notification channels.

---

## 2. Is LisKo Frontend or Backend?

During a capstone defense, panelists frequently ask: *"Is your project frontend or backend?"*

### Simple Answer for Panelists:
> **"LisKo is primarily a client-side Flutter mobile application that runs on the user's Android phone. Most of the application logic, geofencing algorithms, and emergency SMS triggers run locally on the device (Frontend & On-Device Logic). Firebase serves as an auxiliary Cloud Backend for history logging, while Android's OS services (SIM SMS Gateway and GPS Engine) serve as Native System Backends."**

### Detailed Breakdown:
* **Frontend / UI**: Flutter widgets (`HomeScreen`, `ActiveTripTab`, `EmergencyAlertScreen`, `TimesUpScreen`, buttons, bottom sheets) that render the interface and capture user actions.
* **Application Logic / Controller**: On-device Dart controllers (`HomeScreenState`, `GeofenceService`, `LocationService`, `PermissionService`) that calculate arrival distance, count down timers, and decide when to alert contacts.
* **Local Persistence**: `SharedPreferences` on the Android phone, storing trusted contacts, active trip state, and offline trip history.
* **Backend Services**:
  * **Native Android OS Backend**: Android's `Telephony` SIM service for offline SMS dispatch and `LocationManager` / `FusedLocationProviderClient` for satellite positioning.
  * **Cloud Backend (Firebase Firestore)**: Cloud database used for storing trip records (`trips`) and emergency event logs (`emergency_events`).

---

## 3. Complete LisKo Application Flow

Below is the execution flow from the moment the user opens the LisKo application:

```text
App Launch (main.dart)
       │
       ▼
Initialize Bindings & Native Services
(FlutterBinding → NotificationService → BackgroundService → Firebase)
       │
       ▼
_LaunchGate
(Shows SplashScreen for 2.6s)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
Setup Completed = false           Setup Completed = true
       │                                 │
       ▼                                 ▼
WelcomeScreen / OnboardingFlow    HomeScreen (Main Dashboard)
(Steps 1–5: Setup & Contacts)            │
       │                                 ├──────────────────────────┐
       ▼                                 ▼                          ▼
Navigate to HomeScreen            Tab 0: Home / Active      Tab 1: Trips
                                  Tab 2: Contacts           Tab 3: Settings
                                         │
                                         ▼
                             User Starts Commute
                                         │
                                         ▼
                            Check Trip Requirements
                            (Permissions & Location Service)
                                         │
                                         ▼
                               Active Trip Commute
                         (Geofence & Travel Countdown)
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                 Arrived Target                 Travel Timer Expired
                         │                               │
                         ▼                               ▼
               Arrival Safety Check             90-Second Escalation
               (90-second countdown)           (Heads-Up Alarm & Vibrate)
                         │                               │
         ┌───────────────┴──────────────┐        ┌───────┴──────────────┐
         ▼                              ▼        ▼                      ▼
  User Taps "I'm Safe"           Timer Expired / User Taps "Need Help"
         │                              │
         ▼                              ▼
     End Trip                 Emergency Location Acquisition
  (Safe Status)              (Stream + Hybrid GPS, 12s timeout)
                                        │
                                        ▼
                            SmsAlertService Dispatch
                           (SMS sent to Trusted Contacts)
                                        │
                                        ▼
                           Emergency Sent Notification
```

---

## 4. Start Trip Flow

When the student configures and starts a commute trip:

```text
User Taps "Start Trip"
       │
       ▼
TripSchedulerSheet (Modal Bottom Sheet)
(User selects Destination & Duration)
       │
       ▼
PermissionService.checkTripRequirements()
(Checks Location Permission, Location Service, SMS, Notifications)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
Requirements Missing               Requirements Met
(Show Rationale Modal & Settings)         │
                                         ▼
                             Save Active Trip Locally
                          (LocalStorageService.saveActiveTrip)
                                         │
                                         ▼
                            Save Trip Record to Cloud
                         (FirebaseService.saveOrUpdateTrip)
                                         │
                                         ▼
                            Start Geofence GPS Stream
                         (GeofenceService.startMonitoring)
                                         │
                                         ▼
                          Start Travel Countdown Timer
                             (1-second periodic tick)
                                         │
                                         ▼
                             Render ActiveTripTab View
```

### Key Functions & Files Involved:
* **`TripSchedulerSheet`** (`lib/widgets/set_trip_timer_bottom_sheet.dart`): UI for choosing destination (Home, Campus, or Custom Drop-off) and duration (15 to 120 mins).
* **`PermissionService.checkTripRequirements()`** (`lib/services/permission_service.dart`): Verifies runtime permissions and GPS toggle state before allowing trip creation.
* **`HomeScreenState._startTrip()`** (`lib/screens/main_dashboard_screen.dart`): Initializes timer state, calculates expected arrival timestamp (`DateTime.now() + duration`), persists active state to `SharedPreferences`, logs to Firestore, and starts `GeofenceService`.

---

## 5. Destination & Geofence Flow

LisKo supports three main destination types:
1. **Campus**: PUP Santa Maria, Bulacan Campus (`14.8697° N, 120.9991° E`, 150m radius).
2. **Home**: User's custom residential coordinates saved in local storage (defaults to Santa Maria baseline `14.8192° N, 120.9610° E`, 150m radius).
3. **Other / Commuter Nodes**: Verified transit drop-off points in Santa Maria, Bulacan:
   * *Caypombo Terminal / Crossing* (`14.8487° N, 120.9813° E`)
   * *Waltermart Santa Maria Drop-off* (`14.8227° N, 120.9542° E`)
   * *Santa Maria Bayan / Savemore Area* (`14.8217° N, 120.9616° E`)

```text
Destination Selected
       │
       ▼
GeofenceService.resolveTarget()
(Resolves Target Coordinates & Radius)
       │
       ▼
GeofenceService.startMonitoring()
(Subscribes to Geolocator.getPositionStream)
       │
       ▼
Position Update Received
       │
       ▼
Geolocator.distanceBetween(lat1, lng1, lat2, lng2)
(Calculates Haversine spherical distance in meters)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
Distance > 150m                   Distance ≤ 150m
(Continue monitoring)                    │
                                         ▼
                              Arrival Detected Callback
                             (Triggers 90s Arrival Check)
```

### Haversine Distance Formula (Simplified for Defense):
`Geolocator.distanceBetween()` calculates the **great-circle distance** (shortest distance over the Earth's curved surface) between the student's current GPS coordinate and the destination target coordinate:

$$d = 2r \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta \lambda}{2}\right)}\right)$$

If $d \le 150\text{ meters}$, the student is inside the geofence perimeter, and arrival is triggered.

---

## 6. Emergency & Safety Flow

LisKo provides three distinct emergency triggers:

```text
                 EMERGENCY TRIGGERS
                         │
      ┌──────────────────┼──────────────────┐
      ▼                  ▼                  ▼
  Manual SOS        NEED HELP Button    Timer Expired (No Response)
  (Dashboard)      (Active Trip / Banner)     (90s Countdown Reaches 0)
      │                  │                  │
      └──────────────────┼──────────────────┘
                         │
                         ▼
          LocationService.acquireEmergencyLocation()
          (Hybrid Stream + One-Shot GPS, 12s timeout)
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
      Valid Location             GPS Timeout / Unavailable
    (Lat, Lng, Accuracy)        (locError = 'Location Unavailable')
             │                       │
             └───────────┬───────────┘
                         │
                         ▼
             SmsAlertService.sendManualSos() / dispatchEmergencyAlert()
             (Formatted SMS with Google Maps link or fallback text)
                         │
                         ▼
             Android Native BackgroundSms Dispatch
                         │
                         ▼
             NotificationService.showEmergencySentNotification()
```

### A. Manual SOS
* Tapped on the main dashboard home tab.
* Checks permissions → shows `EmergencyAlertScreen` with a **5-second countdown**.
* If user does not tap "Cancel", countdown finishes → enters loading state.
* Executes `LocationService().acquireEmergencyLocation()`.
* Formats SMS and dispatches to trusted contacts.

### B. NEED HELP Button
* Tapped on `ActiveTripTab`, `TimesUpScreen`, or from a Heads-Up Notification action button.
* Instantly transitions the commute to an emergency escalation state, bypassing travel countdowns.
* Executes `LocationService().acquireEmergencyLocation()` and dispatches emergency SMS.

### C. 90-Second Automatic Safety Escalation
* Triggered when the Travel Timer reaches `0:00` or when destination geofence entry is detected.
* Shows `TimesUpScreen` and triggers high-priority Heads-Up Notification (`showTimeoutAlarm` or `showArrivalAlarm`).
* Executes a **3-cycle custom haptic vibration loop** (`Vibration.vibrate(pattern: [0, 500, 200, 500])`).
* User options:
  * **"I'm Safe"**: Cancels vibration, cancels notifications, marks trip completed safely.
  * **"+15 mins"**: Extends trip travel timer by 15 minutes and resumes monitoring.
  * **No Response**: If 90 seconds expire without user action, `_arrivalTimer` automatically executes emergency escalation and dispatches SMS alerts.

---

## 7. GPS Flow

LisKo uses an on-demand, privacy-preserving location acquisition model managed by `LocationService` (`lib/services/location_service.dart`).

```text
Location Request Initiated
       │
       ▼
Check Location Permission & Location Service Toggle
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
Permission / Service OFF          Permission & Service ON
(Return Error State)                     │
                                         ▼
                            Hybrid GPS Acquisition Race
               ┌─────────────────────────┴─────────────────────────┐
               ▼                                                   ▼
  Geolocator.getPositionStream()                    Geolocator.getCurrentPosition()
  (AndroidSettings: 1s interval)                    (LocationAccuracy.high, 10s timeout)
               │                                                   │
               └─────────────────────────┬─────────────────────────┘
                                         │
                                         ▼
                            First Valid Position Captured
                          (positionCompleter.isCompleted)
                                         │
                                         ▼
                      Cancel Stream Subscription Immediately
                                         │
             ┌───────────────────────────┴───────────────────────────┐
             ▼                                                       ▼
      Fix Acquired                                            12-Second Timeout
  (Return Lat, Lng, Acc)                                             │
                                                                     ▼
                                                          Attempt Fallback Chain:
                                                      1. Geolocator.getLastKnownPosition()
                                                      2. cachedTripPosition
                                                      3. LocalStorage active trip coordinates
                                                      4. locError = 'Location Unavailable'
```

### Key Technical Characteristics:
* **Hybrid Acquisition**: Races an active location stream (`getPositionStream`) against a single `getCurrentPosition` call, guaranteeing high reliability across different Android vendor ROMs (such as Vivo Funtouch OS).
* **Instant Cancellation**: The stream is cancelled immediately in a `finally` block as soon as the first valid position arrives, preventing battery drain and preserving privacy.
* **Bounded Timeout**: Strict 12-second maximum duration ensures emergency SMS is never blocked indefinitely.

---

## 8. SMS Flow

Emergency SMS messages are constructed by `SmsAlertService` (`lib/services/sms_alert_service.dart`) and sent via offline Android SIM hardware using the `background_sms` plugin.

```text
Emergency Alert Triggered
       │
       ▼
Read Trusted Contacts from Local Storage
(LocalStorageService.readContacts)
       │
       ▼
Normalize Phone Numbers
(Converts 09xx / 639xx to +63 9xx xxx xxxx format)
       │
       ▼
Build Emergency Message Text
       │
       ├───────────────────────────────────────────┐
       ▼                                           ▼
Location Available                          Location Unavailable
"LISKO SOS! Need help!                      "LISKO SOS! Need help!
Loc: 14.869700,120.999100 (+/-15m)          Loc: Location Unavailable
Map: https://www.google.com/maps?q=14.8697,120.9991
Time: 09-22-2026 02:30:15 PM"               Time: 09-22-2026 02:30:15 PM"
       │                                           │
       └─────────────────────┬─────────────────────┘
                             │
                             ▼
                 Check Android SMS Permission
                             │
                             ▼
             BackgroundSms.sendMessage()
             (Hands SMS directly to Android SIM Hardware)
                             │
                             ▼
               Return Dispatched Contact List
```

> **Important Note**: LisKo SMS alerts work **100% offline without cellular data or Wi-Fi**. Only a standard cellular network SIM signal is required.

---

## 9. Trusted Contact Flow

Students manage their emergency contacts through `ContactsTab` (`lib/screens/contacts_tab.dart`) using `PhoneContactService` (`lib/services/phone_contact_service.dart`).

```text
User Taps "Import from Phone Contacts"
       │
       ▼
Show Custom Rationale Modal
("Import Emergency Contacts")
       │
       ▼
Request Native READ_CONTACTS Permission
       │
       ▼
PhoneContactService.fetchContacts()
(Reads device contacts with phone numbers via flutter_contacts)
       │
       ▼
ContactSelectionBottomSheet
(Alphabetical list with real-time search filter)
       │
       ▼
NumberSelectionBottomSheet
(If contact has multiple phone numbers)
       │
       ▼
SelectRelationshipBottomSheet
(Assigns relationship: Mother, Father, Guardian, Sibling, Friend, Other)
       │
       ▼
Save Selected Contact to SharedPreferences
(LocalStorageService.saveContacts)
```

> **Zero-Surveillance Privacy Rule**: LisKo **never** uploads or stores the student's full address book. Only the specific contacts explicitly chosen by the student are saved to local device storage.

---

## 10. Notification Architecture

Managed by `NotificationService` (`lib/services/notification_service.dart`).

### Notification Channels
1. **`lisko_alarm_channel_v2` (Sounds & Vibrate)**:
   * Importance: `Importance.max`, Priority: `Priority.high`
   * Plays alert sound + vibration pattern. Displays as a top-screen **Heads-Up Banner**.
2. **`lisko_alarm_vibrate_v1` (Vibration Only - Default)**:
   * Importance: `Importance.max`, Priority: `Priority.high`, `playSound: false`
   * Silent presentation with custom vibration pattern for discrete classroom settings.
3. **`lisko_trip_channel` (Background Service)**:
   * Importance: `Importance.low`
   * Low-priority ongoing notification (`Lisko Trip Active`) showing background trip status.

### Notification Action Buttons
Heads-Up Alarm banners feature interactive action buttons:
* **"I'M SAFE"** (`kNotifActionSafe`): Cancels alarm and marks trip completed safely.
* **"+15 MINS"** (`kNotifActionExtend`): Extends active travel timer by 15 minutes.
* **"NEED HELP"** (`kNotifActionSos`): Triggers immediate emergency location acquisition and SMS alert dispatch.

---

## 11. Background Execution

Managed by `initializeBackgroundService()` in `lib/services/background_service_setup.dart` using `flutter_background_service`.

* **Foreground Service**: Runs an Android Foreground Service with notification ID `888` and channel `lisko_trip_channel`.
* **Android 14+ Compliance**: Configured with `foregroundServiceType="location"` in `AndroidManifest.xml` to comply with Google Play API 34 security policies.
* **Purpose**: Keeps the travel timer countdown active when the phone screen is locked or when the student switches to other applications during a commute.

---

## 12. Why LisKo Uses a Local-First Approach

```text
┌────────────────────────────────────────────────────────┐
│               LOCAL-FIRST SAFETY ARCHITECTURE          │
│                                                        │
│   ┌───────────────┐     ┌───────────────┐              │
│   │  Flutter UI   │     │ Local Storage │              │
│   └───────┬───────┘     └───────┬───────┘              │
│           │                     │                      │
│   ┌───────▼─────────────────────▼───────┐              │
│   │     On-Device Safety Logic          │              │
│   └───────┬─────────────┬───────┬───────┘              │
│           │             │       │                      │
│   ┌───────▼───────┐  ┌──▼───┐  ┌▼──────────────┐       │
│   │ GPS Hardware  │  │ SIM  │  │ Notifications │       │
│   └───────────────┘  └──────┘  └───────────────┘       │
└─────────────────────────┬──────────────────────────────┘
                          │ (Optional Log Sync)
                          ▼
               ┌─────────────────────┐
               │ Firebase Firestore  │
               │ (Cloud Telemetry)   │
               └─────────────────────┘
```

### Benefits of Local-First Architecture:
1. **Offline Operational Reliability**: Commuting students frequently pass through poor signal areas or run out of mobile data. LisKo's geofencing, countdowns, and SIM SMS dispatch run 100% locally without requiring internet access.
2. **Zero-Surveillance Privacy**: Student location tracks are evaluated purely in device memory and are **never uploaded** to remote databases or tracking servers.
3. **Instant Responsiveness**: On-device evaluation eliminates network latency during critical emergency situations.

---

## 13. Data Flow Diagrams

### Normal Commute Flow
```text
Student → Selects Destination & Duration → LocalStorage (Active Trip Saved)
        → Firestore (Trip Document Logged) → GeofenceService (GPS Monitoring Active)
        → Geofence Perimeter Entered → 90s Arrival Check → Student Taps "I'm Safe"
        → LocalStorage (Trip History Saved) → Firestore (Status Updated to 'Completed')
```

### Emergency Escalation Flow
```text
Student / Timer Expiry → Emergency Escalation Triggered → LocationService (12s Hybrid GPS)
                       → SmsAlertService (Reads Contacts & Builds Message)
                       → Android SIM Hardware (Sends Offline SMS)
                       → LocalStorage (Trip History 'Alert' Logged)
                       → Firestore (Emergency Event Logged if Online)
```

---

## 14. Firebase Data Documentation

### Firestore Collections

| Collection | Purpose | Written By | Read By | Important Fields |
| :--- | :--- | :--- | :--- | :--- |
| **`trips`** | Logs historical trip summaries for record-keeping | `FirebaseService.saveOrUpdateTrip()` | `FirebaseService.getTrips()`, `getTripsStream()` | `destination`, `estimatedTravelMinutes`, `startedAt`, `expectedArrivalAt`, `completedAt`, `status`, `startLocationLat`, `startLocationLng`, `wasExtended` |
| **`emergency_events`** | Logs emergency event telemetry for capstone reporting | `FirebaseService.logEmergencyEvent()` | `FirebaseService.getTripsStream()` | `deviceId`, `tripId`, `latitude`, `longitude`, `emergencyType`, `triggeredAt`, `status` |

> **Crucial Difference**: Trusted contacts are **NEVER stored in Firebase**. Trusted contacts reside **exclusively in local device storage** (`SharedPreferences`).

### Data Storage Matrix

| Data Type | Stored Locally (`SharedPreferences`) | Stored in Cloud (`Firebase Firestore`) | Privacy & Operational Notes |
| :--- | :---: | :---: | :--- |
| **Onboarding Status** | Yes (`setup_completed`) | No | Local startup gate flag |
| **Trusted Emergency Contacts** | Yes (`trusted_contacts_json`) | **NO** | 100% local for privacy compliance |
| **Active Commute State** | Yes (`active_trip_state_json`) | No | Persistent across app restarts |
| **Home Geofence Coordinates** | Yes (`home_latitude/longitude`) | No | Student residential privacy |
| **Alert Preferences** | Yes (`timer_alert_mode`) | No | Vibration vs Sound setting |
| **Trip Summaries** | Yes (`trip_history_json`) | Yes (`trips`) | Local history works offline; synced if online |
| **Emergency Events** | Yes (`trip_history_json`) | Yes (`emergency_events`) | Local alert record + Firestore log |

---

## 15. File-by-File Reference

| File Path | Functional Role | Primary Responsibility | Open During Defense When Asked About... |
| :--- | :--- | :--- | :--- |
| `lib/main.dart` | Application Bootstrapper | Initializes services, handles splash screen timing, and routes to Welcome or Home | *"Where does the app start?" / "How is the app initialized?"* |
| `lib/screens/main_dashboard_screen.dart` | Root Dashboard Coordinator | Manages active trip state, countdown timers, bottom navigation tabs, and emergency escalation | *"Where is Manual SOS handled?" / "How are active trips managed?"* |
| `lib/screens/home_tab.dart` | Home Tab View | Displays quick trip start buttons, active status cards, and Manual SOS trigger button | *"Where is the main user dashboard layout?"* |
| `lib/screens/active_trip_screen.dart` | Active Commute View | Renders live commute countdown, distance to destination, and "+15 min" extension options | *"What does the user see during an active commute?"* |
| `lib/screens/emergency_alert_screen.dart` | Full-Screen Emergency Modal | Displays 5-second Manual SOS countdown or 90-second safety check escalation screen | *"Where is the 5-second SOS countdown screen?"* |
| `lib/screens/times_up_screen.dart` | Timer Expiry Modal | Renders full-screen prompt when travel timer expires ("I'm Safe", "+15 mins", "Need Help") | *"What happens when the travel timer expires?"* |
| `lib/screens/trips_tab.dart` | Commute History View | Displays list of past commutes, safety alerts, and travel duration metrics | *"Where is trip history displayed?"* |
| `lib/screens/contacts_tab.dart` | Contacts Management View | UI for adding, editing, deleting, and importing trusted emergency contacts | *"How do students manage trusted contacts?"* |
| `lib/screens/settings_tab.dart` | Preferences & Settings View | Configuration for Expiry Alert Mode (Vibration vs Sound), User Guide, and test utilities | *"Where are app settings and alert modes configured?"* |
| `lib/screens/onboarding_flow.dart` | Onboarding Carousel | 5-step initial setup flow for permissions, contact setup, and home geofence configuration | *"How does the initial onboarding work?"* |
| `lib/services/location_service.dart` | On-Demand Location Engine | Stream-based & hybrid GPS acquisition with 12s timeout and fallback handling | *"How does LisKo acquire GPS coordinates for emergency alerts?"* |
| `lib/services/geofence_service.dart` | Geofence Boundary Monitor | Resolves destination targets, calculates Haversine distance, and fires arrival triggers | *"How does LisKo know when the student has arrived?"* |
| `lib/services/sms_alert_service.dart` | Emergency SMS Dispatcher | Formats location text, normalizes phone numbers, and dispatches offline SMS via Android SIM | *"How are emergency SMS alerts sent?"* |
| `lib/services/notification_service.dart` | Local Notification Manager | Registers channels (`lisko_alarm_channel_v2`), displays Heads-Up banners, and handles actions | *"How do local notifications and Heads-Up alarms work?"* |
| `lib/services/local_storage_service.dart` | Local Persistence Layer | Interfaces with `SharedPreferences` to store contacts, active trips, history, and preferences | *"Where is local data stored on the phone?"* |
| `lib/services/firebase_service.dart` | Cloud Telemetry Connector | Syncs trip summaries and emergency event logs to Cloud Firestore when online | *"How does LisKo connect to Firebase?"* |
| `lib/services/permission_service.dart` | System Permission Manager | Validates runtime permissions (Location, SMS, Contacts, Notifications) and GPS toggle | *"How are permissions requested and checked?"* |
| `lib/services/phone_contact_service.dart` | Phonebook Import Engine | Fetches and filters device contacts via `flutter_contacts` for contact import | *"How does the contact import feature work?"* |
| `lib/services/background_service_setup.dart` | Background Service Config | Configures `FlutterBackgroundService` for persistent travel timer tracking | *"How does the app run in the background when locked?"* |

---

## 16. Panel Defense Quick Guide ("If the Panelist Asks...")

### Q1: "Where does the application start?"
* **Answer**: `lib/main.dart` in the `main()` function. It initializes Flutter bindings, sets up local notifications, configures the background service, connects to Firebase, and loads `_LaunchGate`. `_LaunchGate` checks `LocalStorageService.readSetupCompleted()`: if `true`, it routes to `HomeScreen`; if `false`, it routes to `WelcomeScreen`.

### Q2: "How does LisKo know the student has arrived at their destination?"
* **Answer**: In `lib/services/geofence_service.dart`. When a trip starts, `GeofenceService.startMonitoring()` listens to GPS position updates and calculates the distance to the active destination using `Geolocator.distanceBetween()` (Haversine formula). When the calculated distance is $\le 150\text{ meters}$, `onArrival` fires and triggers the 90-second arrival safety check.

### Q3: "Does LisKo continuously track student location in the cloud?"
* **Answer**: **No.** LisKo adheres to a Zero-Surveillance Architecture. GPS monitoring runs **only during an active trip** and processes location coordinates **100% locally on the device**. Coordinates are never transmitted to cloud servers or remote databases.

### Q4: "How does LisKo send emergency SMS alerts if there is no internet connection?"
* **Answer**: In `lib/services/sms_alert_service.dart`. LisKo uses the `background_sms` Flutter plugin to hand formatted emergency SMS messages directly to Android's native `SmsManager` SIM hardware. It operates entirely offline over standard cellular network signals (GSM/LTE/5G) without requiring mobile data or Wi-Fi.

### Q5: "Where are the student's trusted emergency contacts stored?"
* **Answer**: In `lib/services/local_storage_service.dart` inside `SharedPreferences` under the key `trusted_contacts_json`. Trusted contacts remain **100% local to the student's phone** and are never saved to Firebase or external servers.

### Q6: "What happens if GPS cannot be acquired during an emergency?"
* **Answer**: `LocationService.acquireEmergencyLocation()` runs a hybrid acquisition strategy for a maximum of **12 seconds**. If live GPS cannot be obtained within 12 seconds, it executes a fallback chain:
  1. `Geolocator.getLastKnownPosition()`
  2. Active trip cached coordinates (`_cachedActiveTripPosition`)
  3. `LocalStorageService.readActiveTrip()` cached coordinates
  4. If all fallbacks fail, it sets `locationError = 'Location Unavailable'` and sends the fallback SMS (`Loc: Location Unavailable`) without fake coordinates or fake Maps links.

### Q7: "Why did you choose Flutter for LisKo?"
* **Answer**: Flutter provides cross-platform UI consistency, high performance (60fps native compilation), excellent plugin support for native Android hardware APIs (GPS, SIM SMS, Notifications, Vibration), and seamless reactive state management.

---

## 17. Important Algorithms & Logic

### 1. Haversine Distance Formula (`Geolocator.distanceBetween`)
* **File**: `lib/services/geofence_service.dart` (`_evaluatePosition`)
* **Purpose**: Calculates shortest spherical surface distance between current GPS position and destination target.
* **Logic**: Computes distance in meters; if distance $\le 150\text{m}$, triggers `onArrival`.

### 2. 90-Second Safety Check Escalation Logic
* **File**: `lib/screens/main_dashboard_screen.dart` (`_startArrivalCountdownTimer`, `_startTimeoutCountdownTimer`)
* **Purpose**: Automatically alerts trusted contacts if student fails to confirm safety upon arrival or timer expiry.
* **Logic**: Sets deadline to `DateTime.now() + 90s`, starts 1-second countdown timer, triggers 3-cycle haptic vibration, and dispatches emergency SMS if deadline passes without response.

### 3. Hybrid Stream GPS Location Acquisition
* **File**: `lib/services/location_service.dart` (`acquireEmergencyLocation`)
* **Purpose**: Reliable, fast emergency GPS retrieval across diverse Android device vendor ROMs.
* **Logic**: Races `getPositionStream` (with `AndroidSettings(intervalDuration: 1s)`) against `getCurrentPosition(timeLimit: 10s)` using a `Completer<Position?>`. The first valid non-zero fix wins, and the stream subscription is immediately cancelled in a `finally` block. Capped at 12 seconds max.

### 4. Philippine Phone Number Normalization
* **File**: `lib/services/phone_contact_service.dart` (`normalizePhoneNumber`) & `sms_alert_service.dart` (`_internalDispatch`)
* **Purpose**: Formats user-entered or imported phone numbers into standard E.164 international format (`+63 9xx xxx xxxx`).
* **Logic**: Strips non-digit characters, converts leading `09` or `639` or `9` to `+63 9xx...`, ensuring compatibility with Android SIM hardware dispatchers.

---

## 18. Android Permissions Reference

Declared in `android/app/src/main/AndroidManifest.xml` and managed by `PermissionService`:

| Permission | Why LisKo Needs It | When Requested |
| :--- | :--- | :--- |
| `ACCESS_FINE_LOCATION` | High-accuracy GPS positioning for geofence arrival and emergency location links | Onboarding Step 2 & Start Trip check |
| `ACCESS_COARSE_LOCATION` | Required alongside fine location for Android 12+ (API 31+) location framework compliance | Onboarding Step 2 & Start Trip check |
| `SEND_SMS` | Offline SIM SMS emergency alert dispatch to trusted contacts | Onboarding Step 3 & Start Trip check |
| `READ_CONTACTS` | Reading device phonebook when importing trusted emergency contacts | When tapping "Import from Phone Contacts" |
| `POST_NOTIFICATIONS` | Showing travel countdowns, Heads-Up arrival/expiry alarms, and emergency sent alerts | Onboarding Step 4 & Start Trip check |
| `VIBRATE` | Haptic vibration feedback for 3-cycle emergency escalation alarms | Used automatically during safety check alarm |
| `WAKE_LOCK` | Keeping CPU awake during travel timer tick and 90-second safety check | Used automatically by timer services |
| `USE_FULL_SCREEN_INTENT` | Displaying full-screen safety check alerts over the lock screen | Used during 90s safety check escalation |
| `FOREGROUND_SERVICE` | Running persistent background travel timer service | Used during active trip commute |
| `FOREGROUND_SERVICE_LOCATION` | Compliance for Android 14+ (API 34+) location foreground services | Used during active trip commute |

---

## 19. Outdated Claims & Documentation Corrections

When updating technical documentation, it is essential to correct legacy claims from earlier project stages that no longer reflect the actual codebase:

1. **Correction on Trusted Contacts Storage**: Legacy documentation claimed trusted contacts were saved in Firebase Firestore. **Corrected**: Trusted contacts are stored **100% locally** in `SharedPreferences` (`trusted_contacts_json`) to adhere to Zero-Surveillance privacy standards.
2. **Correction on Geofence Perimeter**: Legacy documentation mentioned a 50m radius. **Corrected**: Active code uses a **150m radius** (`radiusMeters = 150.0`) to account for consumer mobile GPS accuracy tolerances in Bulacan.
3. **Correction on Commuter Drop-Off Nodes**: Legacy documentation listed an outdated "Divine Mercy" node. **Corrected**: Active code features verified drop-off nodes: *Caypombo Terminal / Crossing*, *Waltermart Santa Maria Drop-off*, and *Santa Maria Bayan / Savemore Area*.
4. **Correction on Expiry Alert Modes**: Legacy documentation listed custom audio recording options and silent mode. **Corrected**: Active code features two streamlined modes in Settings: **`Vibration Only`** (default) and **`Sounds & Vibrate`**.
5. **Correction on Emergency Location Acquisition**: Legacy documentation described a 30-second prefetch + retry sequence. **Corrected**: Active code uses a dedicated **12-second max hybrid stream acquisition** in `LocationService.acquireEmergencyLocation()`.
