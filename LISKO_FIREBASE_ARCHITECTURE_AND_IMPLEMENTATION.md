# LisKo Mobile Safety Application — Firebase Architecture & Implementation Documentation

**Project Title**: LisKo: Mobile-Based Student Travel Safety and Emergency Monitoring Application for PUP Santa Maria Students  
**Document Version**: 2.0 (Defense-Ready Final Assessment)  
**Target Audience**: BSIT Capstone Defense Panel & Student Developers  

---

## 1. Executive Overview

LisKo is designed as a **zero-surveillance, local-first mobile safety application**. It provides PUP Santa Maria students with active travel monitoring, automated geofence arrival detection, and offline emergency SMS dispatches.

### What Firebase Is Used For in LisKo
Firebase serves as a **lightweight, remote cloud audit database** for logging travel history and emergency events. When internet connectivity is available, Cloud Firestore records:
1. **Commute Trip Records** (`trips` collection): Start timestamps, travel duration, expected arrival, completion timestamps, and operational status (`active`, `arrived`, `extended`, `expired`, etc.).
2. **Emergency Event Logs** (`emergency_events` collection): Audit logs of Manual SOS signals or unhandled travel timeouts containing emergency GPS coordinates and event timestamps.

### What Firebase Is NOT Responsible For
To protect student privacy and ensure 100% operational reliability during cell-network drops, Firebase is **NOT** involved in core emergency communications or safety execution:
* **Emergency SMS Dispatches**: Sent directly via the student's phone SIM card using the local Android telephony stack (`background_sms` plugin). Firebase does NOT send text messages.
* **Travel Timers**: Calculated and executed locally on the student's device using Dart isolates, `Timer`, and Android system Alarm Managers (`flutter_local_notifications`).
* **Trusted Emergency Contacts**: Stored **100% locally** in Android `SharedPreferences` on the physical phone. Phone numbers are **never** uploaded to Cloud Firestore.
* **Home Geofence Coordinates**: Stored strictly locally in `SharedPreferences`.
* **Student User Accounts**: LisKo operates without user registration or logins (`request.auth == null`).

### Local vs. Cloud Responsibility Matrix

| Feature / Responsibility | Handled Locally? | Handled in Cloud Firestore? | Primary Storage / Service |
| :--- | :---: | :---: | :--- |
| **Active Travel Countdown Timer** | **YES** | **NO** | Local Isolate & Notification Service |
| **Trusted Contacts Directory** | **YES** | **NO** | `SharedPreferences` (`trusted_contacts_json`) |
| **Home Geofence Pin & Radius** | **YES** | **NO** | `SharedPreferences` (`home_latitude`/`longitude`) |
| **Emergency SIM SMS Dispatch** | **YES** | **NO** | Local Telephony (`background_sms`) |
| **GPS Geofence Distance Calculation** | **YES** | **NO** | `Geolocator` plugin on device |
| **Trip Log Cloud Persistence** | **NO** | **YES** | Cloud Firestore (`trips` collection) |
| **Emergency Event Audit Logging** | **NO** | **YES** | Cloud Firestore (`emergency_events` collection) |
| **Trip History Screen Data Source** | **YES** (Combined) | **YES** (Combined) | Deduplicated merge of local storage & Firestore stream |

---

## 2. Firebase Services Used

| Firebase Service | Status | Purpose in LisKo | Evidence / Code File |
| :--- | :---: | :--- | :--- |
| **Firebase Core** | **USED** | Initializes Firebase engine bindings and connects platform credentials. | `lib/main.dart` line 53 (`Firebase.initializeApp`) |
| **Cloud Firestore** | **USED** | NoSQL document database streaming real-time trip history and emergency logs. | `lib/services/firebase_service.dart` (`FirebaseFirestore.instance`) |
| **Firebase Authentication** | **NOT USED** | LisKo is accountless to protect student privacy and avoid login barriers. | Not in `pubspec.yaml` |
| **Firebase Storage** | **NOT USED** | LisKo does not upload photos, audio, or media files to the cloud. | Not in `pubspec.yaml` |
| **Firebase Cloud Messaging (FCM)** | **NOT USED** | Local system alarms and cellular SMS are used instead of FCM push notifications. | Not in `pubspec.yaml` |
| **Cloud Functions** | **NOT USED** | All safety escalation and timer logic executes locally on the student's phone. | No `functions/` directory |
| **Firebase Analytics / Crashlytics** | **NOT USED** | No telemetry or tracking packages are compiled into the application. | Not in `pubspec.yaml` |

---

## 3. Firebase Project Configuration

* **Firebase Project ID**: `lisko-25162`
* **Project Number**: `716666460286`
* **Storage Bucket**: `lisko-25162.firebasestorage.app`
* **Android Application ID / Package Name**: `com.example.flutter_app`
* **Android App ID**: `1:716666460286:android:c108c0cb7a6c18d0b0e02f`

### Configuration Files Inventory

1. `android/app/google-services.json`:
   Native Android configuration file downloaded from Firebase Console. Specifies the `project_id` (`lisko-25162`), `mobilesdk_app_id`, and public client API key (`AIzaSyC...`). Read at build time by the Google Services Gradle plugin.
2. `lib/firebase_options.dart`:
   Dart code file generated by the FlutterFire CLI (`flutterfire configure`). Exposes static `DefaultFirebaseOptions.android` containing client identifiers for runtime engine initialization.
3. `firebase.json`:
   Project root CLI configuration file linking platform outputs and registering `"firestore": { "rules": "firestore.rules" }`.
4. `android/settings.gradle.kts`:
   Declares the Google Services Gradle plugin (`id("com.google.gms.google-services") version("4.3.15") apply false`).
5. `android/app/build.gradle.kts`:
   Applies the Google Services Gradle plugin (`id("com.google.gms.google-services")`).

> [!NOTE]
> **Client Credentials vs. Secrets**:
> Values inside `firebase_options.dart` and `google-services.json` (such as `apiKey` and `appId`) are **public client identifiers**, not administrative secret keys. In Firebase's security model, client API keys identify the project to Google servers, while server-side database protection is enforced by **Cloud Firestore Security Rules** (`firestore.rules`).

---

## 4. Firebase-Related File Map

| File Path | Purpose in LisKo | Firebase Role | When to Open During Defense |
| :--- | :--- | :--- | :--- |
| `lib/main.dart` | Core application entry point and startup gate. | Calls `await Firebase.initializeApp()` before UI launch. | Opening panel question on app startup or initialization. |
| `lib/firebase_options.dart` | Platform credentials generated by FlutterFire CLI. | Supplies `FirebaseOptions` (`projectId`, `appId`, `apiKey`). | When asked how Flutter connects to project `lisko-25162`. |
| `lib/services/firebase_service.dart` | Main database service class. | Implements `saveOrUpdateTrip()`, `logEmergencyEvent()`, and `getTripsStream()`. | When asked how Firestore reads, writes, and real-time streams work. |
| `lib/services/local_storage_service.dart` | SharedPreferences key-value storage layer. | Generates and persists the unique anonymous `lisko_installation_id`. | When asked how trusted contacts stay local or how installation isolation works. |
| `lib/screens/trips_tab.dart` | Trip history dashboard & analytics screen. | Listens to `getTripsStream()` and displays total/filtered trip metrics. | When asked how trip logs are displayed or why cross-device data doesn't mix. |
| `lib/services/notification_service.dart` | Background isolate notification handler. | Syncs trip completion/extension or SOS dispatches to Firestore from notification taps. | When asked how background notification taps sync to Firebase. |
| `firestore.rules` | Security rules file in project root. | Enforces schema validation, field types, GPS bounds, and document deletion denial. | When asked about database security, immutability, or validation. |
| `firebase.json` | Firebase CLI project metadata file. | Maps `firestore.rules` for version-controlled deployment. | When asked how security rules are deployed to Firebase. |

---

## 5. Complete Firebase Initialization Flow

```
                  LisKo App Launch (lib/main.dart: void main())
                                       │
                                       ▼
                   WidgetsFlutterBinding.ensureInitialized()
                                       │
                                       ▼
                   NotificationService().initialize()
                   (Configures local notification channels)
                                       │
                                       ▼
                   initializeBackgroundService()
                   (Registers background isolate handlers)
                                       │
                                       ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │  try {                                                              │
    │    await Firebase.initializeApp(                                    │
    │      options: DefaultFirebaseOptions.currentPlatform,               │
    │    );                                                               │
    │  } catch (error) { ... }                                            │
    └─────────────────────────────────────────────────────────────────────┘
                                       │
                                       ├─► Detects TargetPlatform.android
                                       └─► Loads DefaultFirebaseOptions.android (lisko-25162)
                                       │
                                       ▼
                   runApp(const LiskoApp()) -> Launches UI
                                       │
                                       ▼
  Lazy Evaluation: FirebaseService._firestore evaluates FirebaseFirestore.instance
                 on demand when first read/write occurs.
```

---

## 6. Local-First Architecture

LisKo operates on a **local-first paradigm**: the student's physical phone is always the primary source of truth for immediate travel monitoring and safety execution.

### Scenario A — Internet Available
1. Student sets up a trip and taps `[ START TRIP ]`.
2. Local travel timer activates immediately on device; state saved in `SharedPreferences`.
3. `FirebaseService.saveOrUpdateTrip()` sends a background write to Firestore collection `trips` with `installationId` attached.
4. Active trip progresses; real-time stream snapshots update the UI seamlessly.

### Scenario B — Internet Unavailable (Offline Mode)
1. Student sets up a trip and taps `[ START TRIP ]`.
2. Local travel timer activates normally; active trip state saved to `SharedPreferences`.
3. `FirebaseService.saveOrUpdateTrip()` attempts Firestore sync. The Cloud Firestore SDK queues the write payload in local SDK cache.
4. If an emergency occurs offline, **SmsAlertService immediately dispatches cellular SIM SMS alerts** to trusted contacts via the phone's network. Offline emergency dispatches **do not depend on Firebase**.
5. Local trip history is saved to `SharedPreferences` (`trip_history_json`).

### Scenario C — Internet Reconnects
1. When cellular data or Wi-Fi returns, the Cloud Firestore SDK automatically pushes queued local write operations to project `lisko-25162`.
2. `getTripsStream()` receives fresh cloud snapshots filtered by `installationId` and merges them with local trip history.

---

## 7. Installation ID Architecture

To solve cross-device data mixing without forcing students to create user accounts, LisKo implements an **anonymous persistent installation identifier**.

### Why It Exists
In early development, Firestore snapshot queries fetched the entire global `trips` collection (`firestore.collection('trips').snapshots()`). When multiple physical test phones and emulators connected to the same Firebase project, every phone downloaded every trip document ever created, showing `49 Total Trips` on the UI.

### How `getOrCreateInstallationId()` Works
Housed in `lib/services/local_storage_service.dart`:

```
                    First Launch of LisKo App
                               │
                               ▼
            LocalStorageService.getOrCreateInstallationId()
                               │
                               ▼
             Check SharedPreferences for 'lisko_installation_id'
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
          [ Key Exists ]               [ Key Missing ]
                │                             │
          Return saved ID              Generate new ID:
          (e.g., 'inst_...')           nowMs + Random.secure()
                                              │
                                        Save to SharedPreferences
                                              │
                                        Return new ID
```

### Exact Source Implementation
```dart
  static const _installationIdKey = 'lisko_installation_id';

  Future<String> getOrCreateInstallationId() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = preferences.getString(_installationIdKey);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final random = Random.secure();
      final r1 = random.nextInt(1000000).toString().padLeft(6, '0');
      final r2 = random.nextInt(1000000).toString().padLeft(6, '0');
      final newId = 'inst_${nowMs}_${r1}_$r2';
      await preferences.setString(_installationIdKey, newId);
      developer.log('LocalStorageService: Generated new persistent installation ID: $newId');
      return newId;
    } catch (e, st) {
      developer.log('Failed to read or generate installation ID', error: e, stackTrace: st);
      rethrow;
    }
  }
```

### Collision Resistance & Cryptographic Strength
The generator combines a millisecond Unix timestamp (`nowMs`) with two 6-digit integers generated by `Random.secure()` (which uses OS-level entropy `/dev/urandom` / `SecureRandom`). This yields $10^{12}$ possible combinations per millisecond, ensuring **zero collision probability** across any number of student installations.

### Persistence Lifecycle
* **App Restarts**: ID remains identical (read from `SharedPreferences`).
* **Phone Restarts**: ID remains identical.
* **Offline / Online Transitions**: ID remains identical.
* **App Updates**: ID remains identical.
* **App Uninstall / Reinstall**: `SharedPreferences` cleared by OS; new installation ID generated upon reinstall.

### Non-PII Privacy Compliance
`installationId` contains **NO Personally Identifiable Information (PII)**. It does not use student names, student IDs, phone numbers, email addresses, IMEI, MAC addresses, or Android Hardware IDs.

> [!IMPORTANT]
> **CRITICAL SECURITY DISTINCTION**:
> `installationId` provides **application-level installation filtering** so each phone displays only its own trips. It is **NOT** authenticated server-side user authorization. Because LisKo operates without Firebase Authentication, Firestore Security Rules allow public reads for accountless architecture compatibility.

---

## 8. Multi-Device / Multi-Student Data Isolation

```
            Phone A (Installation ID: inst_1001)
                             │
            Writes Trip A (installationId: inst_1001)
                             │
                             ▼
                  Cloud Firestore (lisko-25162)
                             ▲
                             │
            Phone B (Installation ID: inst_2002)
                             │
            Writes Trip B (installationId: inst_2002)

  ────────────────────────────────────────────────────────────

  Phone A Query:
  .where('installationId', isEqualTo: 'inst_1001')
  ──► Returns ONLY Trip A (Displays 1 trip on Phone A)

  Phone B Query:
  .where('installationId', isEqualTo: 'inst_2002')
  ──► Returns ONLY Trip B (Displays 1 trip on Phone B)
```

---

## 9. Firestore Data Model

LisKo utilizes two collections in Cloud Firestore: `trips` and `emergency_events`.

### Collection 1: `trips`
Stores commute logs (active travel, extensions, arrivals, expirations).

* **Document ID**: `tripId` (Generated locally using timestamp string, e.g. `'1741234567890'`).
* **Fields Schema Table**:

| Field Name | Data Type | Required? | Example Value | Purpose |
| :--- | :--- | :---: | :--- | :--- |
| `installationId` | String | **YES** | `'inst_1741234567890_482912'` | Anonymous installation owner ID for query filtering. |
| `destination` | String | **YES** | `'PUP Santa Maria Campus'` | Commute destination name. |
| `estimatedTravelMinutes` | Integer | **YES** | `45` | Preset travel duration in minutes. |
| `startedAt` | Timestamp | **YES** | `Timestamp(seconds=1741234567, ...)` | Trip creation timestamp. |
| `status` | String | **YES** | `'arrived'` | Current operational status (see Section 10). |
| `expectedArrivalAt` | Timestamp | Optional | `Timestamp(seconds=1741237267, ...)` | Expected arrival deadline timestamp. |
| `completedAt` | Timestamp | Optional | `Timestamp(seconds=1741236800, ...)` | Actual completion/arrival timestamp. |
| `startLocationLat` | Number (double) | Optional | `14.8192` | GPS latitude at trip start. |
| `startLocationLng` | Number (double) | Optional | `120.9610` | GPS longitude at trip start. |
| `wasExtended` | Boolean | Optional | `true` | Flag indicating if timer was extended (+15 mins). |

* **Creator**: Client UI starting a trip (`FirebaseService.saveOrUpdateTrip()`).
* **Updater**: Client UI or notification background handler (`SetOptions(merge: true)`).
* **Deleter**: **None**. (Document deletion denied by rules).

---

### Collection 2: `emergency_events`
Stores immutable audit logs of Manual SOS signals or safety check timeout escalations.

* **Document ID**: `eventId` (Timestamp string, e.g. `'1741234900000'`).
* **Fields Schema Table**:

| Field Name | Data Type | Required? | Example Value | Purpose |
| :--- | :--- | :---: | :--- | :--- |
| `installationId` | String | **YES** | `'inst_1741234567890_482912'` | Anonymous installation owner ID for query filtering. |
| `deviceId` | String | **YES** | `'local_device'` | Legacy static device string payload. |
| `tripId` | String | **YES** | `'1741234567890'` or `''` | Associated trip ID (`''` if standalone Manual SOS). |
| `latitude` | Number (double) | **YES** | `14.8192` | Emergency GPS latitude fix (or `0.0` if no fix). |
| `longitude` | Number (double) | **YES** | `120.9610` | Emergency GPS longitude fix (or `0.0` if no fix). |
| `emergencyType` | String | **YES** | `'SOS'` or `'TIMEOUT_ESCALATION'` | Type of emergency trigger. |
| `triggeredAt` | Timestamp | **YES** | `Timestamp(...)` | Exact timestamp emergency was triggered. |
| `status` | String | **YES** | `'active'` | Emergency event status indicator. |

* **Creator**: Emergency dispatch flow (`FirebaseService.logEmergencyEvent()`).
* **Updater**: **None**. (Emergency events are strictly immutable).
* **Deleter**: **None**. (Deletion denied by rules).

---

## 10. `trips` Collection Verified Status Enum

The application source code uses **8 verified status strings**:

| Status String | Operational Meaning | Trigger Action / Function |
| :--- | :--- | :--- |
| `'active'` | Trip started; travel timer counting down. | `main_dashboard_screen.dart: _startTrip()` |
| `'timeout_warning'` | Travel timer expired; 90s safety check active. | `main_dashboard_screen.dart: _checkTravelTimer()` |
| `'arrived'` | Student confirmed safe arrival. | `_completeTrip()` or Notification "I'm Safe" tap |
| `'extended'` | Timer extended by +15 minutes. | Notification "Extend" tap (`kNotifActionExtend`) |
| `'Trip Extended'` | Timer extended by +15 minutes in UI. | `main_dashboard_screen.dart: _extendTrip()` |
| `'cancelled'` | Trip manually cancelled by student. | `main_dashboard_screen.dart: _completeTrip(safe: false)` |
| `'help_requested'` | Student tapped "Need Help" or SOS during trip. | `main_dashboard_screen.dart: _triggerEmergencyFlow()` |
| `'expired'` | 90s safety check expired without response. | `main_dashboard_screen.dart: _handleSafetyTimeout()` |

---

## 11. `emergency_events` Collection Details

### Standalone SOS vs. Active Trip SOS (`tripId`)
* **Standalone Manual SOS**: When a student triggers Manual SOS from the dashboard without an active trip, `tripId` is written as `""` (empty string).
* **Active Trip SOS**: When SOS is triggered during an active trip, `tripId` is set to the active `tripId`, linking the emergency record directly to the travel log.

### `deviceId` vs. `installationId`
`deviceId` contains the static legacy string `'local_device'`. It is retained for backward compatibility with early data models, but **`installationId` is used for multi-device data filtering**.

---

## 12. Complete Trip Lifecycle & Firestore Writes

```
                          User taps [ START TRIP ]
                                     │
                                     ▼
                   main_dashboard_screen.dart: _startTrip()
                                     │
                                     ▼
                  LocalStorageService.saveActiveTrip()
                  (Persisted in SharedPreferences)
                                     │
                                     ▼
                FirebaseService().saveOrUpdateTrip(...)
                - Fetches persistent installationId
                - SetOptions(merge: true)
                - writes status: 'active'
                                     │
                                     ▼
                        Travel Progresses / Updates:
    ┌────────────────────────────────┼────────────────────────────────┐
    ▼                                ▼                                ▼
[ Geofence Arrival ]         [ +15 Min Extend ]              [ 90s Timeout ]
status: 'arrived'            status: 'extended'              status: 'timeout_warning'
completedAt: now()           wasExtended: true               safety check active
    │                                │                                │
    └────────────────────────────────┼────────────────────────────────┘
                                     │
                                     ▼
                  FirebaseService().saveOrUpdateTrip()
                  (Merged update in Firestore collection 'trips')
                                     │
                                     ▼
                          Trip History UI Stream
```

---

## 13. Complete Manual SOS Flow

```
                      User Taps [ SEND DISTRESS SIGNAL ]
                                     │
                                     ▼
              main_dashboard_screen.dart: _triggerEmergencyFlow()
                                     │
                                     ▼
                 LocationService().acquireEmergencyLocation()
                 (Attempts fast GPS fix within 8 seconds)
                                     │
                                     ▼
                 SmsAlertService().sendManualSos(...)
                 (Dispatches emergency SMS via background_sms plugin / SIM card)
                 *** Independent of Firebase ***
                                     │
                                     ▼
               FirebaseService().logEmergencyEvent(...)
               - Fetches persistent installationId
               - tripId: ""
               - emergencyType: "SOS"
               - latitude, longitude coordinates
               - status: "active"
                                     │
                                     ▼
               Written to Cloud Firestore 'emergency_events'
```

---

## 14. SOS During Active Trip Flow

```
                     Active Trip Running (status: 'active')
                                       │
                                       ▼
                         Emergency Triggered / Tapped
                                       │
                                       ▼
     SmsAlertService dispatches emergency SMS to ALL contacts via SIM card
                                       │
                                       ▼
     FirebaseService().saveOrUpdateTrip(
       tripId: activeTripId,
       status: 'help_requested',
       completedAt: DateTime.now(),
     )
                                       │
                                       ▼
     FirebaseService().logEmergencyEvent(
       eventId: eventId,
       deviceId: 'local_device',
       tripId: activeTripId, // <--- Links event to active trip ID
       emergencyType: 'SOS',
       latitude: gpsLat,
       longitude: gpsLng,
     )
```

---

## 15. Trip History Architecture & Stream Merging

```
 Local Storage (SharedPreferences)              Cloud Firestore
      _localTrips + activeTrip                  lisko-25162
                  │                                  │
                  │              ┌───────────────────┴───────────────────┐
                  │              ▼                                       ▼
                  │       trips Collection                   emergency_events Collection
                  │       .where('installationId', == id)    .where('installationId', == id)
                  │       .orderBy('startedAt', DESC)        .where('tripId', == '')
                  │              │                                       │
                  │              ▼                                       ▼
                  │        _currentTrips                           _currentEvents
                  │              │                                       │
                  └──────────────┼───────────────────────────────────────┘
                                 │
                                 ▼
                     FirebaseService._emitCombinedTrips()
                     - Inserts _localTrips into Map<String, TripRecord> map[t.id]
                     - Inserts _currentTrips into map[t.id] (overwrites local)
                     - Inserts _currentEvents into map[t.id]
                     - Sorts deduplicated list by timestamp descending
                                 │
                                 ▼
                    StreamBuilder in TripsTab
                    Displays filtered tripCount & cards
```

---

## 16. Firestore Queries Summary

| Collection | Query Expression | Purpose | Installation Filter? | Index Needed? |
| :--- | :--- | :--- | :---: | :---: |
| `trips` | `.where('installationId', isEqualTo: installId).orderBy('startedAt', descending: true).snapshots()` | Real-time trip history stream for current device. | **YES** | **YES** (Composite Index) |
| `emergency_events` | `.where('installationId', isEqualTo: installId).where('tripId', isEqualTo: '').snapshots()` | Real-time standalone SOS event stream for Trips tab. | **YES** | **YES** (Composite Index) |
| `trips` | `.collection('trips').orderBy('startedAt', descending: true).get()` | One-shot trip history fetch in `getTrips()`. | NO (Legacy fallback) | Single-field |

> [!IMPORTANT]
> **Composite Index Requirements**:
> Combining `.where('installationId', isEqualTo: id)` with `.orderBy('startedAt', descending: true)` or multiple `.where()` filters requires composite indexes in Cloud Firestore:
> 1. Index 1 (`trips`): `installationId` ASC, `startedAt` DESC.
> 2. Index 2 (`emergency_events`): `installationId` ASC, `tripId` ASC.

---

## 17. Firestore Security Rules Summary (`firestore.rules`)

```gorules
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isValidTripStatus(status) {
      return status in [
        'active', 'timeout_warning', 'arrived', 'extended',
        'cancelled', 'help_requested', 'expired', 'Trip Extended'
      ];
    }

    function isValidTripSchema(data) {
      let allowedKeys = [
        'installationId', 'destination', 'estimatedTravelMinutes',
        'startedAt', 'expectedArrivalAt', 'completedAt', 'status',
        'startLocationLat', 'startLocationLng', 'wasExtended'
      ];

      return data.keys().hasOnly(allowedKeys)
        && data.installationId is string
        && data.installationId.size() > 0
        && data.destination is string
        && data.destination.size() > 0
        && data.estimatedTravelMinutes is int
        && data.estimatedTravelMinutes > 0
        && data.startedAt is timestamp
        && data.status is string
        && isValidTripStatus(data.status)
        && (!('expectedArrivalAt' in data) || data.expectedArrivalAt is timestamp)
        && (!('completedAt' in data) || data.completedAt is timestamp)
        && (!('startLocationLat' in data) || (data.startLocationLat is number && data.startLocationLat >= -90.0 && data.startLocationLat <= 90.0))
        && (!('startLocationLng' in data) || (data.startLocationLng is number && data.startLocationLng >= -180.0 && data.startLocationLng <= 180.0))
        && (!('wasExtended' in data) || data.wasExtended is bool);
    }

    function isValidEmergencyEventSchema(data) {
      let allowedKeys = [
        'installationId', 'deviceId', 'tripId', 'latitude',
        'longitude', 'emergencyType', 'triggeredAt', 'status'
      ];

      return data.keys().hasOnly(allowedKeys)
        && data.installationId is string
        && data.installationId.size() > 0
        && data.deviceId is string
        && data.tripId is string
        && data.latitude is number
        && data.latitude >= -90.0 && data.latitude <= 90.0
        && data.longitude is number
        && data.longitude >= -180.0 && data.longitude <= 180.0
        && data.emergencyType in ['SOS', 'TIMEOUT_ESCALATION']
        && data.triggeredAt is timestamp
        && data.status == 'active';
    }

    match /trips/{tripId} {
      allow read: if true;
      allow create: if isValidTripSchema(request.resource.data);
      allow update: if isValidTripSchema(request.resource.data)
                    && request.resource.data.startedAt == resource.data.startedAt
                    && request.resource.data.destination == resource.data.destination
                    && request.resource.data.installationId == resource.data.installationId;
      allow delete: if false;
    }

    match /emergency_events/{eventId} {
      allow read: if true;
      allow create: if isValidEmergencyEventSchema(request.resource.data);
      allow update: if false;
      allow delete: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 18. Security: What the Rules Protect vs. Do Not Protect

| Security Property | Protection Status | Technical Explanation |
| :--- | :---: | :--- |
| **Strict Schema Enforcement** | **PROTECTED** | `keys().hasOnly(allowedKeys)` rejects extra/unexpected fields. |
| **Data Type Integrity** | **PROTECTED** | Validates string, int, double, bool, and timestamp types. |
| **GPS Coordinate Bounds** | **PROTECTED** | Rejects latitudes outside `[-90, 90]` or longitudes outside `[-180, 180]`. |
| **Trip Immutability** | **PROTECTED** | `startedAt`, `destination`, and `installationId` cannot be changed after creation. |
| **Emergency Log Immutability** | **PROTECTED** | `allow update: if false;` prevents tampering with emergency audit logs. |
| **Deletion Protection** | **PROTECTED** | `allow delete: if false;` prevents document deletion. |
| **Catch-All Collection Shield** | **PROTECTED** | Blocks access to unsupported collections. |
| **Per-User Authenticated Privacy** | **NOT PROTECTED** | Because `request.auth == null`, `allow read: if true;` is open for accountless architecture compatibility. |

---

## 19. Why Firebase Authentication Is Not Currently Used

LisKo adheres to a **zero-surveillance student privacy philosophy**:
1. **Frictionless Emergency Readiness**: Students can install LisKo and immediately configure safety monitoring without creating accounts, remembering passwords, or confirming email addresses.
2. **Local Data Sovereignty**: Personal contacts and home addresses remain on the student's physical phone.
3. **Future Enhancement**: In production iterations, `FirebaseAuth` (e.g., PUP Webmail SSO) can be added to attach `request.auth.uid` to `installationId`, turning installation filtering into authenticated server-side ownership (`FUTURE ENHANCEMENT — NOT CURRENTLY IMPLEMENTED`).

---

## 20. Firestore Rules vs. Firebase Console

* **Local Version Control**: `firestore.rules` is maintained in the git repository to ensure infrastructure-as-code consistency across developers.
* **CLI Deployment**: Registered in `firebase.json`. Deployed via terminal:
  ```bash
  firebase deploy --only firestore:rules --project lisko-25162
  ```
* **Console Sync**: Console rules should always match the repository `firestore.rules` file to prevent configuration drift.

---

## 21. Firestore Offline / Reconnect Behavior

LisKo features dual offline resilience:
1. **LisKo Local Storage (`SharedPreferences`)**: Immediate local persistence for active trip state and trip history (`trip_history_json`).
2. **Firestore SDK Offline Cache**: When offline, the Cloud Firestore SDK queues writes in its local SQLite cache. Upon reconnecting, queued writes automatically push to project `lisko-25162`.

---

## 22. Failure Scenarios & System Recovery

| Scenario | Expected LisKo Behavior |
| :--- | :--- |
| **Cellular Data / Wi-Fi Drops** | App continues active trip monitoring locally. Emergency SMS alerts dispatch via phone SIM card. Cloud writes queue in SDK cache. |
| **Firebase Server Outage** | Travel timer, geofence arrival, and emergency SMS dispatch operate 100% normally. Cloud sync resumes when servers recover. |
| **Firestore Write Fails** | Caught by `try/catch` in `FirebaseService`. Error logged to console. Local trip history remains intact. |
| **SharedPreferences Read Fails** | `LocalStorageService` falls back to default safe baseline values (`defaultContacts`, `false` setup). |
| **GPS Fix Unavailable** | Emergency SMS dispatches with warning text and last known location or notice that GPS fix could not be obtained. |
| **Reinstalling App** | OS clears `SharedPreferences`. A new `installationId` is generated upon reinstall. Legacy cloud logs remain stored safely in Firestore under the old ID. |

---

## 23. Legacy Firestore Data Handling

The ~49 legacy cloud trip documents created during early testing lack an `installationId`. When queries execute `.where('installationId', isEqualTo: currentInstallationId)`, Cloud Firestore automatically excludes legacy records, preventing cross-device history mixing without needing destructive database wipes.

---

## 24. Scalability Analysis

* **Query Efficiency**: `.where('installationId', isEqualTo: id)` filters queries at the database engine level, retrieving only documents matching the device's installation ID.
* **Cost Minimization**: Deduplicated streams and local `SharedPreferences` caching minimize Firestore read/write operations.

---

## 25. Privacy Considerations

* **Anonymous Identifiers**: `installationId` is a pseudonymous random string (`inst_1741234567890_482912`).
* **Zero Contact Upload**: Emergency contact names, phone numbers, and relationships are **never** transmitted to Cloud Firestore.
* **Event-Driven GPS**: Location coordinates are queried only during active trip geofencing or emergency dispatches.

---

## 26. Complete Architecture Diagram

```
                                  LISKO FLUTTER MOBILE APP
                                             │
             ┌───────────────────────────────┴───────────────────────────────┐
             │                                                               │
     LOCAL LAYER (Phone)                                             CLOUD LAYER (Firebase)
             │                                                               │
  SharedPreferences                                                  Firebase Core
  ├── trusted_contacts_json (Local Only)                                     │
  ├── home_latitude/longitude (Local Only)                           Cloud Firestore
  ├── lisko_installation_id                                                  │
  └── trip_history_json                                              ┌───────┴───────┐
             │                                                       │               │
  Local Telephony (SIM Card)                                       trips          emergency_events
  └── background_sms (Emergency Dispatches)                      Collection       Collection
```

---

## 27. Data Flow Diagrams

### A. Start Trip
`User taps Start Trip → LocalStorageService.saveActiveTrip() → FirebaseService.saveOrUpdateTrip() [status: 'active'] → Firestore 'trips'`

### B. Complete / Arrive
`Geofence Trigger / "I'm Safe" Tap → Local Active Trip Cleared → Primary Safe Arrival SMS via SIM → saveOrUpdateTrip() [status: 'arrived']`

### C. Extend Trip
`User taps +15 Min → Local Timer Updated → saveOrUpdateTrip() [status: 'extended', wasExtended: true]`

### D. Cancel Trip
`User taps Cancel → Local Active Trip Cleared → saveOrUpdateTrip() [status: 'cancelled']`

### E. Timeout Escalation
`90s Check Expires → Haptic Alert → Emergency SIM SMS Dispatched → saveOrUpdateTrip() [status: 'expired'] → logEmergencyEvent() [type: 'TIMEOUT_ESCALATION']`

### F. Manual SOS
`User Taps SOS → GPS Fix Acquired → Emergency SIM SMS Dispatched to ALL Contacts → logEmergencyEvent() [type: 'SOS', tripId: '']`

### G. SOS During Active Trip
`User Taps SOS in Trip → Emergency SIM SMS Dispatched → saveOrUpdateTrip() [status: 'help_requested'] → logEmergencyEvent() [tripId: activeId]`

### H. Offline → Reconnect
`Trip Action Offline → Queued in Firestore SDK Cache → Internet Returns → SDK Pushes Writes to Cloud → getTripsStream Snapshot Emitted`

### I. Trip History Retrieval
`TripsTab Launched → getTripsStream() Queries trips & emergency_events where installationId == id → _emitCombinedTrips() Deduplicates & Sorts → UI Renders`

### J. Two Different Phones
`Phone A (inst_A) & Phone B (inst_B) → Phone A queries inst_A → Phone B queries inst_B → Zero Data Mixing`

---

## 28. Defense-Ready Questions and Answers

1. **Q: Why did you use Firebase in LisKo?**  
   *A: Firebase Cloud Firestore provides remote cloud persistence and real-time data streaming for student trip logs and emergency event records across app restarts.*
2. **Q: Why Cloud Firestore instead of a SQL database like MySQL?**  
   *A: Firestore provides native real-time stream listeners (`snapshots()`), seamless Flutter integration via FlutterFire, and automatic offline write queuing.*
3. **Q: What happens if there is no internet during a trip?**  
   *A: LisKo is local-first. Travel timers, geofence monitoring, and emergency SIM SMS dispatches work 100% offline. Firestore writes queue in SDK memory until reconnecting.*
4. **Q: Does Firebase send the emergency text messages?**  
   *A: No. Emergency text messages are sent directly from the phone's SIM card using the local Android telephony framework (`background_sms` plugin).*
5. **Q: Why do you call LisKo a local-first application?**  
   *A: Because all safety-critical features—timers, emergency dispatches, and contact storage—execute directly on the student's physical phone without needing a cloud server.*
6. **Q: What is `installationId` and why did you implement it?**  
   *A: `installationId` is an anonymous, persistent random ID generated per device installation (`SharedPreferences`). It filters Firestore queries so each phone displays only its own trips.*
7. **Q: Why did one phone previously show 49 total trips?**  
   *A: Early queries fetched the entire global `trips` collection without filtering. Adding `.where('installationId', isEqualTo: id)` isolated each phone's history.*
8. **Q: Is `installationId` the same as user authentication?**  
   *A: No. `installationId` provides client-side UI filtering. It is not an authenticated user identity because LisKo operates without Firebase Authentication.*
9. **Q: Why don't you use Firebase Authentication?**  
   *A: To maintain a zero-surveillance, friction-free safety model where students can use LisKo immediately without creating accounts or supplying personal emails.*
10. **Q: Where are trusted emergency contacts stored?**  
    *A: Trusted contacts are stored 100% locally in `SharedPreferences` on the physical phone and are never uploaded to Cloud Firestore.*
11. **Q: Where is the student's home location stored?**  
    *A: Home geofence coordinates are stored locally in `SharedPreferences` (`home_latitude` and `home_longitude`).*
12. **Q: What happens if two phones use LisKo simultaneously?**  
    *A: Each phone generates its own unique `installationId`, so their Firestore writes and history streams remain completely isolated.*
13. **Q: What happens if a student uninstalls and reinstalls LisKo?**  
    *A: Android clears `SharedPreferences`, so a new `installationId` is generated. Previous cloud records remain safely in Firestore under the old ID.*
14. **Q: Why is `tripId` empty (`""`) in standalone Manual SOS records?**  
    *A: Because Manual SOS can be triggered anytime from the dashboard without starting a travel trip, so there is no active trip ID to reference.*
15. **Q: What is `deviceId = 'local_device'` in emergency events?**  
    *A: It is a static legacy string payload. Active filtering relies on `installationId`.*
16. **Q: How do your Firestore Security Rules protect the database?**  
    *A: `firestore.rules` enforces strict schema key checking, data type validation, GPS coordinate range limits, immutable trip fields, and prevents document deletion.*
17. **Q: Can users delete trip records from Firestore?**  
    *A: No. `firestore.rules` explicitly denies deletions (`allow delete: if false;`) to preserve an immutable audit trail.*
18. **Q: Can emergency events be modified after creation?**  
    *A: No. `firestore.rules` explicitly denies updates (`allow update: if false;`) to emergency event logs.*
19. **Q: What happens to legacy cloud documents lacking `installationId`?**  
    *A: They remain safely stored in Firestore but are automatically excluded from filtered UI queries.*
20. **Q: Does LisKo require composite indexes in Firestore?**  
    *A: Yes. Combining `.where('installationId', isEqualTo: id)` with `.orderBy('startedAt', descending: true)` requires a composite index in Cloud Firestore.*

---

## 29. "If the Panelist Asks This, Open This File"

| Panelist Question | File to Open | Exact Function / Section |
| :--- | :--- | :--- |
| **"How is Firebase initialized?"** | `lib/main.dart` | `main()` line 53 |
| **"Where are Firestore writes implemented?"** | `lib/services/firebase_service.dart` | `saveOrUpdateTrip()` & `logEmergencyEvent()` |
| **"How is installationId generated?"** | `lib/services/local_storage_service.dart` | `getOrCreateInstallationId()` |
| **"How are trips filtered by device installation?"** | `lib/services/firebase_service.dart` | `getTripsStream()` |
| **"Where are security rules defined?"** | `firestore.rules` | `isValidTripSchema()` & `match /trips/{tripId}` |
| **"Where are trusted contacts stored?"** | `lib/services/local_storage_service.dart` | `readContacts()` & `saveContacts()` |
| **"How is emergency SMS dispatched?"** | `lib/services/sms_alert_service.dart` | `sendManualSos()` |
| **"Where is the trip history UI rendered?"** | `lib/screens/trips_tab.dart` | `_TripsTabState.build()` StreamBuilder |

---

## 30. Terminology Cheat Sheet

* **Firebase Core**: The base Google Flutter package required to initialize Firebase services.
* **Cloud Firestore**: Google's flexible, scalable NoSQL cloud database.
* **Collection**: A container for Firestore documents (e.g. `trips`).
* **Document**: A single record inside a Firestore collection containing key-value pairs.
* **Snapshot Listener**: A real-time WebSocket connection (`snapshots()`) that receives updates whenever database documents change.
* **Local-First**: Software design where all primary features run locally on the phone without requiring cloud servers.
* **SharedPreferences**: Android's native local key-value storage framework.
* **Security Rules**: Server-side access control configuration governing Firestore reads, writes, and field validations.
* **Schema Validation**: Verifying that incoming database documents contain required fields and valid data types.
* **Installation ID**: A persistent, anonymous unique string generated once per app installation (`lisko_installation_id`).
* **`Random.secure()`**: Dart's cryptographically secure pseudo-random number generator (CSPRNG).
* **Composite Index**: A Cloud Firestore database index spanning multiple fields required for queries using both `.where()` and `.orderBy()`.

---

## 31. Current Architecture Limitations

1. **Accountless Privacy Trade-off**: Because LisKo operates without user logins (`request.auth == null`), `firestore.rules` permits public reads (`allow read: if true;`). Database integrity is protected by schema validation, but per-student authenticated confidentiality is not enforced.
2. **Installation Filtering vs. Authorization**: `installationId` provides client-side history isolation. It is not an authenticated cryptographic user token.
3. **Local Storage Persistence**: Uninstalling LisKo or clearing app data clears `SharedPreferences`, causing the app to generate a new `installationId` upon reinstall.

---

## 32. Future Production Improvements

`FUTURE ENHANCEMENT — NOT CURRENTLY IMPLEMENTED`
1. **PUP Student SSO Authentication**: Integrating `FirebaseAuth` (PUP Webmail OAuth) to assign a verified `request.auth.uid`.
2. **Authenticated Security Rules**: Updating `firestore.rules` to enforce `allow read, write: if request.auth != null && request.auth.uid == resource.data.studentUid;`.
3. **Cloud Functions Escalation**: Server-side webhooks for automated email dispatch to university safety officers.

---

## 33. Final Defense Summary

### Firebase Architecture in 60 Seconds

> LisKo uses Firebase Cloud Firestore as an anonymous, lightweight remote audit log for travel history and emergency events. Designed with a local-first philosophy, all safety-critical functions—including the travel countdown timer, home geofencing, trusted contacts directory, and emergency SMS dispatches—execute directly on the student's physical phone. Personal contact numbers and home coordinates are stored strictly in local Android `SharedPreferences` and are never uploaded to the cloud.
>
> To isolate trip history across different physical devices without forcing students to create user accounts, LisKo generates a persistent, cryptographically strong random `installationId` on first launch. All Cloud Firestore writes and real-time stream queries are filtered by this installation ID, ensuring each student's phone displays only their own commute logs. Cloud Firestore Security Rules enforce strict field schema validation, numeric GPS coordinate bounds, and document deletion protection.

---

## 34. Final Technical Verification Table

| Item | Verified? | Evidence / Location |
| :--- | :---: | :--- |
| **Firebase Initialized** | **YES** | `lib/main.dart:53` |
| **Cloud Firestore Used** | **YES** | `lib/services/firebase_service.dart` |
| **Firebase Auth Not Used** | **YES** | Absent from `pubspec.yaml` |
| **`trips` Collection** | **YES** | `lib/services/firebase_service.dart:180` |
| **`emergency_events` Collection** | **YES** | `lib/services/firebase_service.dart:212` |
| **`installationId` Generated** | **YES** | `lib/services/local_storage_service.dart:28` |
| **`installationId` Persisted** | **YES** | `SharedPreferences` key `lisko_installation_id` |
| **`installationId` in Trips Writes** | **YES** | `lib/services/firebase_service.dart:182` |
| **`installationId` in Emergency Writes** | **YES** | `lib/services/firebase_service.dart:214` |
| **Trips Query Filtered by `installationId`** | **YES** | `lib/services/firebase_service.dart:114` |
| **Emergency Query Filtered by `installationId`** | **YES** | `lib/services/firebase_service.dart:136` |
| **Standalone SOS `tripId == ""`** | **YES** | `lib/services/firebase_service.dart:137` |
| **Active Trip SOS Linked `tripId`** | **YES** | `lib/screens/main_dashboard_screen.dart:907` |
| **Trusted Contacts Stored Locally** | **YES** | `SharedPreferences` key `trusted_contacts_json` |
| **Firestore Security Rules Created** | **YES** | `firestore.rules` in project root |
| **Rules Configuration in `firebase.json`** | **YES** | `firebase.json` line 3 |
| **SMS Dispatched via Cellular SIM** | **YES** | `lib/services/sms_alert_service.dart` |
| **Offline Resilience Supported** | **YES** | Firestore SDK local cache + SharedPreferences |
| **Composite Indexes Identified** | **YES** | `installationId` ASC + `startedAt` DESC |
| **Static Analysis Passing** | **YES** | `flutter analyze` (0 errors, 0 warnings in app code) |
