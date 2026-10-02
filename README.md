# LisKo

**LisKo** is an offline-first mobile safety and travel-monitoring application designed to safeguard commuting students of Polytechnic University of the Philippines – Santa Maria Campus. Built with a zero-surveillance architecture, LisKo provides privacy-respecting travel safety monitoring without continuous cloud tracking or mandatory user account creation.

The application allows students to schedule travel timers, monitor active trip progress via GPS geofencing, and respond to automated safety confirmation prompts upon arrival or countdown expiration. In emergencies, LisKo dispatches direct SIM-based SMS alerts containing real-time GPS location coordinates, reverse-geocoded landmarks, and Google Maps web links directly to trusted emergency contacts over the cellular SIM network, ensuring reliable emergency escalation even without active internet connectivity.

---

## Key Features

- **Set a Trip Scheduler**: Choose destination presets (PUP Santa Maria Campus, Home, or commuter transit nodes) and set estimated travel durations.
- **Active Trip Monitoring**: Real-time countdown timer displaying remaining travel time with options to extend (+15 Minutes) or confirm safe arrival.
- **On-Demand Destination Geofence**: Active-trip GPS position monitoring (`Geolocator.getPositionStream`) tracks distance to destination boundaries (150m perimeter) and triggers arrival prompts upon entry. Location tracking automatically stops when the trip concludes.
- **Safety Confirmation & 90-Second Escalation**: Fullscreen arrival and timeout prompt (`TimesUpScreen`) with a 90-second countdown; confirming safety concludes the trip, while timeout automatically triggers emergency protocol.
- **Direct SIM-Based Emergency SMS Dispatch**: Sends direct cellular SMS messages containing real-time GPS coordinates, reverse-geocoded landmarks, and Google Maps web links to trusted contacts during emergencies via `background_sms`.
- **Manual SOS Trigger**: One-tap emergency dispatch on the dashboard for immediate location-assisted SMS broadcast.
- **Trusted Contacts Directory**: Manage primary and secondary emergency contacts with Philippine mobile number validation and native phone contacts import (`flutter_contacts`).
- **Commuter Transit Directory**: Expandable municipality dropdowns (Santa Maria, Norzagaray, Angat) with transit mode icons (bus, jeep, van) and address details.
- **Local & Device-Isolated Cloud History**: Stores trip history locally on the device with accountless Cloud Firestore event logging isolated per device via a unique Installation ID.
- **State Restoration**: Restores active commute state upon app restart if a trip was in progress.

---

## Technology Stack

| Category | Technology |
| --- | --- |
| **Framework** | Flutter (Development Environment: v3.47+) |
| **Language** | Dart (SDK Constraint: `>=3.11.0 <4.0.0`) |
| **Target Platform** | Android (AGP 8.11+, Compile SDK 36, Min SDK 21, Java 17) |
| **Cloud Database** | Firebase Cloud Firestore (`cloud_firestore`, `firebase_core`) |
| **Location & Geofencing** | `geolocator`, `geocoding` (No Google Maps SDK required) |
| **SMS Dispatch** | `background_sms` (Native Android MethodChannel) |
| **Notifications & Alarms** | `flutter_local_notifications` |
| **Background Processing** | `flutter_background_service` |
| **Local Persistence** | `shared_preferences` |
| **Contact Import** | `flutter_contacts` |
| **UI & Styling** | `google_fonts` (Plus Jakarta Sans), `iconify_flutter` |

---

## Data Architecture & Privacy Model

LisKo operates on an **accountless data architecture**, separating local device storage from cloud event records based on the current implementation:

### Local Device Persistence (`SharedPreferences`)
**Privacy Design**: Based on the current implementation, trusted contact information, including names, phone numbers, and relationships, as well as custom Home location coordinates, are stored locally using `SharedPreferences` and are not included in the application's Firestore synchronization.
- Trusted emergency contacts directory (names, phone numbers, relationships)
- Custom Home geofence coordinates (`latitude`, `longitude`, `radius`)
- Onboarding and walkthrough completion states
- User preferences (Timer alert mode, default travel duration)
- Local trip history cache

### Cloud Firestore Event Records (`cloud_firestore`)
LisKo logs anonymous, schema-validated event records to Cloud Firestore for audit trails:
- **`trips` Collection**: Destination name, estimated travel duration, start/completion timestamps, status, and optional start location coordinates.
- **`emergency_events` Collection**: Device ID, trip ID, trigger timestamp, emergency type (`SOS` or `TIMEOUT_ESCALATION`), and emergency GPS coordinates.

### Device Record Isolation (`installationId`)
Because LisKo does not use user accounts or logins:
- `LocalStorageService` generates a unique, persistent random ID (`installationId`) upon first launch.
- All Firestore writes attach this `installationId`.
- The Trips history screen queries Firestore using `.where('installationId', isEqualTo: installId)`, ensuring each device retrieves only its own records.

---

## Project Structure

```
flutter_app/
├── android/                  # Android native runner and build scripts
├── assets/                   # Static branding logos and graphic maps
├── lib/                      # Primary Dart source code
│   ├── constants/            # Design tokens, color palette, and icons
│   ├── screens/              # Application screens, tabs, and modals
│   ├── services/             # Storage, location, geofencing, SMS, and Firebase
│   ├── widgets/              # Reusable UI components and overlays
│   ├── firebase_options.dart # Firebase client configuration
│   └── main.dart             # Entry point and LaunchGate coordinator
├── plugins/                  # Local plugins (background_sms)
├── test/                     # Unit and widget test suite
├── firebase.json             # Firebase project configuration
├── firestore.rules           # Cloud Firestore security rules
└── pubspec.yaml              # Package dependencies and asset declarations
```

- **`android/`**: Contains Android Manifest, Gradle build scripts, and native Kotlin activity code.
- **`assets/`**: Static assets including app branding logos and graphical maps.
- **`lib/`**: Primary Dart application codebase organized by constants, screens, services, and widgets.
- **`plugins/`**: Custom local plugin packages used for native Android background SMS dispatch.
- **`test/`**: Automated unit and widget test suite covering app startup, geofencing, and UI flows.

---

## Prerequisites

Before setting up and running LisKo, ensure your development environment includes:

- **Dart SDK** (`>=3.11.0 <4.0.0` as specified in `pubspec.yaml`)
- **Flutter SDK** (Tested on v3.47.0 or higher)
- **Android Studio** or **Visual Studio Code** (with Flutter and Dart extensions)
- **Android SDK** (API Level 34+, Compile SDK 36, Java 17)
- **Git**
- **Physical Android Device** (API 21+) with an active cellular SIM card for SMS testing, or an Android Emulator

---

## Installation and Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd flutter_app
   ```

2. **Verify Flutter environment**:
   ```bash
   flutter doctor
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Verify static analysis**:
   ```bash
   flutter analyze
   ```

---

## Firebase Configuration

LisKo integrates with Firebase Cloud Firestore for anonymous, schema-validated trip event logging and emergency audit trails (`projectId: lisko-25162`).

- Mobile client options are defined in `lib/firebase_options.dart` and `android/app/google-services.json`.
- Cloud Firestore security rules are enforced via `firestore.rules`.

> **Security Notice**: Firebase client configuration keys (`lib/firebase_options.dart` and `google-services.json`) are public mobile client identifiers protected server-side by Cloud Firestore security rules. Developers must **NEVER** commit private service-account keys, signing keystores, passwords, or server credentials to the repository.

---

## Running the Application

- **Run on connected device/emulator**:
  ```bash
  flutter run
  ```

- **Run in release mode**:
  ```bash
  flutter run --release
  ```

- **Run automated test suite**:
  ```bash
  flutter test
  ```

- **Build debug APK**:
  ```bash
  flutter build apk --debug
  ```

---

## Required Permissions

LisKo requests the following Android permissions:

| Permission | Purpose |
| --- | --- |
| `SEND_SMS` | Direct transmission of emergency SMS alerts over cellular SIM network via `background_sms`. |
| `READ_PHONE_STATE` | Reads Multi-SIM subscription details for SMS routing. |
| `READ_CONTACTS` | Imports emergency contacts from Android address book. |
| `ACCESS_FINE_LOCATION` | High-accuracy GPS for on-demand destination geofence arrival detection and emergency location inclusion. |
| `ACCESS_COARSE_LOCATION` | Approximate location fallback. |
| `POST_NOTIFICATIONS` | Displays active countdown notifications and high-priority alarms (Android 13+). |
| `VIBRATE` | Haptic vibration patterns for safety alerts and alarms. |
| `WAKE_LOCK` | Keeps CPU active during active trip background monitoring. |
| `USE_FULL_SCREEN_INTENT` | Declared in the Android manifest; the current notification implementation does not configure Android full-screen intents. The Time's Up safety screen is presented through the Flutter application when applicable. |
| `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_LOCATION` | Foreground service location monitoring support during active trips (Android 14+ / API 34+). |

---

## Development Team

### LisKo Team

| Member | Role |
| --- | --- |
| [Member Name] | [Role] |
| [Member Name] | [Role] |
| [Member Name] | [Role] |
| [Member Name] | [Role] |

---

## Project Status

LisKo is currently under active development, testing, and evaluation as an academic capstone project. Features, interfaces, and architecture continue to be refined through field testing and usability evaluation.

---

## Academic Purpose

LisKo was developed as an academic Capstone project by Bachelor of Science in Information Technology (BSIT) students of:

**Polytechnic University of the Philippines – Santa Maria Campus**  
Santa Maria, Bulacan, Philippines
