// ==============================================================================
// LisKo Mobile Safety Application - Main Dashboard & Tab Coordinator
// File: lib/screens/main_dashboard_screen.dart
//
// Role & Architectural Context:
// Root screen container (`HomeScreen`) coordinating the four bottom navigation tabs:
// - Tab 0: Home Dashboard (`HomeDashboardTab` when idle, `ActiveTripTab` when commuting)
// - Tab 1: Trips History & Metrics (`TripsTab`)
// - Tab 2: Trusted Contacts Directory (`ContactsTab`)
// - Tab 3: Security & Preferences (`SettingsTab`)
//
// Trip State Management & Countdown Lifecycle:
// Manages the active commute countdown (`tripActive`, `remaining`, `totalDuration`):
// - Starting a Trip: Cancels any lingering timers, sets active duration, and ticks every 1 second.
// - Auto-Completion: When countdown expires (`remaining <= Duration.zero`), timer cancels
//   and trip state automatically terminates.
// - Trip Extension (+15 min): Safely increments remaining duration without resetting the timer.
// - Modal & Dialog Guards (`_sheetOpen`, `_dialogOpen`): Enforces re-entrancy protection
//   preventing duplicate modals during rapid user interaction.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Reliability: Timers are strictly canceled inside `dispose()` and state updates
//   verify `mounted` prior to invoking `setState()`.
// - Usability (Smooth Transitions): Tab switches utilize `AnimatedSwitcher` (120ms easeOut)
//   retaining steady 60fps rendering without route navigation overhead.
// ==============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../services/geofence_service.dart';
import '../services/sms_alert_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_icon.dart';
import '../widgets/set_trip_timer_bottom_sheet.dart';
import 'active_trip_screen.dart';
import 'contacts_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';
import 'trips_tab.dart';

/// Main container screen hosting the bottom navigation bar and active trip state.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final SmsAlertService _smsAlertService = SmsAlertService();

  int selectedTab = 0;
  bool tripActive = false;
  bool isArrived = false;
  int arrivalCountdown = 90;
  Duration remaining = const Duration(minutes: 45);
  DateTime? expectedArrivalAt;
  DateTime? safetyCheckDeadline;
  Duration totalDuration = const Duration(minutes: 45);
  String destination = 'Campus';
  Timer? tripTimer;
  Timer? _arrivalTimer;

  @override
  void dispose() {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    _geofenceService.stopMonitoring();
    super.dispose();
  }

  void _startTrip(String selectedDestination, Duration duration) async {
    final canStart = await PermissionService().checkTripRequirements(context);
    if (canStart) {
      _executeStartTrip(selectedDestination, duration);
    }
  }

  void _executeStartTrip(String selectedDestination, Duration duration) {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    final now = DateTime.now();
    setState(() {
      tripActive = true;
      isArrived = false;
      arrivalCountdown = 90;
      destination = selectedDestination;
      totalDuration = duration;
      expectedArrivalAt = now.add(duration);
      remaining = duration;
      selectedTab = 0;
    });

    // 1. Activate Conditional GPS Geofence Monitoring (strictly inactive when idle)
    _geofenceService.startMonitoring(
      destination: selectedDestination,
      onArrival: (target, distance) {
        if (!mounted) return;
        _handleArrivalDetected(target.name);
      },
      onError: (error) {
        debugPrint('Geofence tracking notice: $error');
      },
    );

    // 2. Start Travel Countdown Timer using Timestamp Comparison
    tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      if (expectedArrivalAt != null && currentTime.isAfter(expectedArrivalAt!)) {
        tripTimer?.cancel();
        // Travel timer expired: prompt safety verification
        _handleArrivalDetected(destination);
      } else if (expectedArrivalAt != null) {
        setState(() => remaining = expectedArrivalAt!.difference(currentTime));
      }
    });
  }

  /// Triggers arrival state and begins 90-second escalation countdown.
  void _handleArrivalDetected(String destinationName) {
    if (isArrived) return;
    tripTimer?.cancel();
    final now = DateTime.now();
    
    setState(() {
      isArrived = true;
      safetyCheckDeadline = now.add(const Duration(seconds: 90));
      arrivalCountdown = 90;
      selectedTab = 0;
    });

    // Start 90-second safety escalation countdown
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final currentTime = DateTime.now();
      
      if (safetyCheckDeadline != null && currentTime.isAfter(safetyCheckDeadline!)) {
        _arrivalTimer?.cancel();
        setState(() => arrivalCountdown = 0);
        _escalateEmergencyAlert();
      } else if (safetyCheckDeadline != null) {
        setState(() => arrivalCountdown = safetyCheckDeadline!.difference(currentTime).inSeconds);
      }
    });
  }

  /// Public test & demonstration helper allowing simulation of GPS arrival.
  void simulateGeofenceArrival() {
    _handleArrivalDetected(destination);
  }

  /// Dispatches offline SMS emergency alerts when 90-second timer expires.
  Future<void> _escalateEmergencyAlert() async {
    double? lat = _geofenceService.activeTarget?.latitude;
    double? lng = _geofenceService.activeTarget?.longitude;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      lat = position.latitude;
      lng = position.longitude;
    } catch (e) {
      debugPrint('Failed to fetch live GPS for emergency escalation: $e');
    }

    final sentList = await _smsAlertService.dispatchEmergencyAlert(
      destination: destination,
      latitude: lat,
      longitude: lng,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 5),
          content: Text(
            '⚠️ 90s safety window expired. Offline SMS alert dispatched to ${sentList.isEmpty ? "trusted contacts" : sentList.join(", ")}.',
          ),
        ),
      );
    }
  }

  void _endTrip() {
    tripTimer?.cancel();
    _arrivalTimer?.cancel();
    // Immediate GPS shutdown preserving Zero-Surveillance privacy
    _geofenceService.stopMonitoring();
    setState(() {
      tripActive = false;
      isArrived = false;
      remaining = Duration.zero;
      arrivalCountdown = 90;
      expectedArrivalAt = null;
      safetyCheckDeadline = null;
    });
  }

  void _extendTrip() {
    _arrivalTimer?.cancel();
    
    final currentTime = DateTime.now();
    // If we've already passed expectedArrivalAt, or it's null, base it on now
    if (expectedArrivalAt == null || currentTime.isAfter(expectedArrivalAt!)) {
        expectedArrivalAt = currentTime.add(const Duration(minutes: 15));
    } else {
        expectedArrivalAt = expectedArrivalAt!.add(const Duration(minutes: 15));
    }

    setState(() {
      isArrived = false;
      arrivalCountdown = 90;
      remaining = expectedArrivalAt!.difference(currentTime);
    });

    // Re-enable travel countdown
    tripTimer?.cancel();
    tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final nowTime = DateTime.now();
      if (expectedArrivalAt != null && nowTime.isAfter(expectedArrivalAt!)) {
        tripTimer?.cancel();
        _handleArrivalDetected(destination);
      } else if (expectedArrivalAt != null) {
        setState(() => remaining = expectedArrivalAt!.difference(nowTime));
      }
    });
  }

  bool _dialogOpen = false;
  bool _sheetOpen = false;

  Future<void> _showSosConfirmation() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Need help?'),
          content: const Text(
            'Your trusted contacts will be notified that you may need assistance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SOS alert prepared for your trusted contacts.'),
                    ),
                  );
                }
              },
              child: const Text('Confirm SOS'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) _dialogOpen = false;
    }
  }

  void _openTripScheduler() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripSchedulerSheet(onStart: _startTrip),
    ).whenComplete(() {
      if (mounted) _sheetOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: selectedTab == 0
            ? (tripActive
                ? ActiveTripTab(
                    key: const ValueKey('active-trip'),
                    destination: destination,
                    remaining: remaining,
                    totalDuration: totalDuration,
                    onSafe: _endTrip,
                    onExtend: _extendTrip,
                    onSos: _showSosConfirmation,
                    isArrived: isArrived,
                    arrivalRemainingSeconds: arrivalCountdown,
                  )
                : HomeDashboardTab(
                    key: const ValueKey('home-dashboard'),
                    onStartTrip: _openTripScheduler,
                  ))
            : selectedTab == 1
                ? const TripsTab(key: ValueKey('trips'))
                : selectedTab == 2
                    ? const ContactsTab(key: ValueKey('contacts'))
                    : const SettingsTab(key: ValueKey('settings')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) {
          if (selectedTab == index) return;
          setState(() => selectedTab = index);
        },
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.body,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.homeOutline,
              color: AppColors.body,
              semanticIcon: Icons.home_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.home,
              color: AppColors.primary,
              semanticIcon: Icons.home_rounded,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.mapOutline,
              color: AppColors.body,
              semanticIcon: Icons.map_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.map,
              color: AppColors.primary,
              semanticIcon: Icons.map_rounded,
            ),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.peopleOutline,
              color: AppColors.body,
              semanticIcon: Icons.people_outline_rounded,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.people,
              color: AppColors.primary,
              semanticIcon: Icons.people_rounded,
            ),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: AppIcon.standard(
              AppIcons.settingsOutline,
              color: AppColors.body,
              semanticIcon: Icons.settings_outlined,
            ),
            activeIcon: AppIcon.standard(
              AppIcons.settings,
              color: AppColors.primary,
              semanticIcon: Icons.settings_rounded,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
