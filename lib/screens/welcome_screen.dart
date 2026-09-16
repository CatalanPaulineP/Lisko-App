// ==============================================================================
// LisKo Mobile Safety Application - Welcome & Route Transitions
// File: lib/screens/welcome_screen.dart
//
// Role & Architectural Context:
// First interactive onboarding screen. Welcomes new users, explains LisKo's
// commuter safety purpose (connecting students and trusted contacts), and hosts
// the global `createRoute` navigation transition factory.
//
// Route Transition System:
// Enforces consistent, frame-rate-optimized screen transitions:
// - `RouteTransition.onboarding`: Horizontal slide transition (250ms) for wizard progression.
// - `RouteTransition.fade` & `fadeWelcome`: Smooth opacity crossfades (200-250ms)
//   preventing white screen flicker when transitioning from the dark splash screen.
//
// ISO/IEC 25010 Software Quality Standards Alignment:
// - Usability (Clarity of Intent & Aesthetics): Clear headline, mission statement,
//   and high-emphasis PrimaryButton ("Get Started") direct the student into the
//   safety setup with zero confusion.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../widgets/action_buttons.dart';
import '../widgets/app_icon.dart';
import 'onboarding_flow.dart';

/// Route transition types used across the application.
enum RouteTransition { fade, fadeWelcome, fadeThrough, onboarding }

/// Creates smooth page routes with customizable animation transitions.
Route createRoute(
  Widget targetScreen, {
  RouteTransition transition = RouteTransition.onboarding,
}) {
  final duration = switch (transition) {
    RouteTransition.fadeWelcome => 200,
    RouteTransition.fade => 250,
    RouteTransition.fadeThrough => 300,
    RouteTransition.onboarding => 250,
  };

  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (transition == RouteTransition.onboarding) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      }

      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(opacity: fadeAnimation, child: child);
    },
    transitionDuration: Duration(milliseconds: duration),
    reverseTransitionDuration: Duration(milliseconds: duration),
  );
}

/// Initial welcome screen presenting LisKo's core mission and setup trigger.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 280,
                width: double.infinity,
                child: MapPreview(),
              ),
              const SizedBox(height: 30),
              Text(
                'WELCOME TO LISKO',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.header,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Stay connected with your trusted contacts while travelling between home and campus. Complete a quick safety setup before using the application.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: AppColors.body,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.push(
                    context,
                    createRoute(
                      const InitialSafetySetupScreen(),
                      transition: RouteTransition.fadeWelcome,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map preview graphic with LisKo security badge overlay.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/map_graphic.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  AppIcon.small(
                    AppIcons.shield,
                    color: Colors.white,
                    semanticIcon: Icons.shield_rounded,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LISKO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
