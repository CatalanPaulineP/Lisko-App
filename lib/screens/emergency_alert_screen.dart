import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../main.dart';

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.onExecute,
    required this.onCancel,
    this.isManualSos = true,
    this.onExtend,
    this.immediateExecute = false,
    this.isStandalone = false,
  });

  final Future<void> Function() onExecute;
  final VoidCallback onCancel;
  final bool isManualSos;
  final VoidCallback? onExtend;
  final bool immediateExecute;
  final bool isStandalone;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  late int countdown;
  Timer? _timer;
  bool _executing = false;
  bool _done = false;
  bool _isCancelled = false;

  @override
  void initState() {
    countdown = widget.immediateExecute ? 0 : (widget.isManualSos ? 5 : 90);
    super.initState();
    if (widget.isStandalone) {
      initBackgroundServicesForSos();
    }
    if (widget.immediateExecute) {
      Future.microtask(() {
        if (mounted && !_isCancelled) _executeAlert();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isCancelled) {
          _startCountdown();
        }
      });
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isCancelled) {
        timer.cancel();
        return;
      }
      if (countdown > 0) {
        setState(() => countdown--);
        if (countdown == 0) {
          _timer?.cancel();
          Vibration.cancel();
          if (!_isCancelled) {
            _executeAlert();
          }
        }
      }
    });
  }

  Future<void> _executeAlert() async {
    if (_isCancelled) return;

    setState(() {
      countdown = 0;
      _executing = true;
    });

    await widget.onExecute();

    if (!mounted || _isCancelled) return;

    setState(() {
      _executing = false;
      _done = true;
    });

    // Close/exit activity when complete
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isCancelled) {
        _exitOrPop();
      }
    });
  }

  void _exitOrPop() {
    if (widget.isStandalone) {
      SystemNavigator.pop();
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _cancel() {
    _isCancelled = true;
    _timer?.cancel();
    Vibration.cancel();
    widget.onCancel();
    _exitOrPop();
  }

  @override
  void dispose() {
    _isCancelled = true;
    _timer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isStandalone,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
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
                  style: const TextStyle(
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
                                  _exitOrPop();
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
      ),
    );
  }
}
