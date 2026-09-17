import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../constants/app_colors.dart';

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key, required this.onExecute, required this.onCancel, this.isManualSos = true, this.onExtend, this.immediateExecute = false});

  final Future<void> Function() onExecute;
  final VoidCallback onCancel;
  final bool isManualSos;
  final VoidCallback? onExtend;
  final bool immediateExecute;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  late int countdown;
  Timer? _timer;
  bool _executing = false;
  bool _done = false;

  @override
  void initState() {
    countdown = widget.immediateExecute ? 0 : (widget.isManualSos ? 5 : 90);
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (countdown > 0) {
        setState(() => countdown--);
        if (countdown == 0) {
          _timer?.cancel();
          Vibration.cancel();
          _executeAlert();
        }
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
    Vibration.cancel();
    widget.onCancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    Vibration.cancel();
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
              Text(
                widget.isManualSos ? 'Manual SOS Triggered' : 'Inactivity Safety Alert',
                textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
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
                if (widget.isManualSos)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _cancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _cancel, // I'm Safe
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const FittedBox(child: Text("I'm Safe", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onExtend?.call();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const FittedBox(child: Text("+15 mins", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _timer?.cancel();
                            Vibration.cancel();
                            _executeAlert();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Need Help / SOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

