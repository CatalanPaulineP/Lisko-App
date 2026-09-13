import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key, required this.onExecute, required this.onCancel});

  final Future<void> Function() onExecute;
  final VoidCallback onCancel;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  int countdown = 5;
  Timer? _timer;
  bool _executing = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (countdown > 1) {
        setState(() => countdown--);
      } else {
        _timer?.cancel();
        _executeAlert();
      }
    });
  }

  Future<void> _executeAlert() async {
    setState(() {
      countdown = 0;
      _executing = true;
    });
    
    await widget.onExecute();
    
    if (mounted) {
      setState(() {
        _executing = false;
        _done = true;
      });
      // Optionally close after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _cancel() {
    _timer?.cancel();
    widget.onCancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  _done ? Icons.check_rounded : Icons.warning_rounded,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Emergency!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _done 
                  ? 'SMS Sent & Location Shared'
                  : 'Sending Alert\nLocation Shared\nSMS Sent',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (!_done && !_executing) ...[
                const Text(
                  'ALERTING CONTACTS IN',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$countdown',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
              ],
              if (_executing)
                const CircularProgressIndicator(color: Colors.white),
              const Spacer(),
              if (!_done && !_executing)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

