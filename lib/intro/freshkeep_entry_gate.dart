import 'dart:async';

import 'package:flutter/material.dart';

import '../data/inventory_database.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

enum _LaunchStage { splash, onboarding, app }

/// Displays a brief branded [SplashScreen] on every launch and routes through
/// [OnboardingScreen] only on the user's very first open.
class FreshKeepEntryGate extends StatefulWidget {
  const FreshKeepEntryGate({
    super.key,
    required this.database,
    required this.showSplash,
    required this.showOnboardingIfNeeded,
    this.splashDuration = const Duration(milliseconds: 1100),
    required this.child,
  });

  final InventoryDatabase database;
  final bool showSplash;
  final bool showOnboardingIfNeeded;
  final Duration splashDuration;
  final Widget child;

  @override
  State<FreshKeepEntryGate> createState() => _FreshKeepEntryGateState();
}

class _FreshKeepEntryGateState extends State<FreshKeepEntryGate> {
  late _LaunchStage _stage;
  Timer? _splashTimer;
  bool _timerDone = false;
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    if (!widget.showSplash && !widget.showOnboardingIfNeeded) {
      _stage = _LaunchStage.app;
      return;
    }
    _stage = _LaunchStage.splash;
    if (widget.showSplash) {
      _splashTimer = Timer(widget.splashDuration, () {
        _timerDone = true;
        _tryAdvanceFromSplash();
      });
    } else {
      _timerDone = true;
    }
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    var completed = true;
    if (widget.showOnboardingIfNeeded) {
      try {
        completed = await widget.database.hasCompletedOnboarding();
      } catch (_) {
        completed = false;
      }
    }
    if (!mounted) return;
    _onboardingDone = completed;
    _tryAdvanceFromSplash();
  }

  void _tryAdvanceFromSplash() {
    if (!mounted || !_timerDone || _onboardingDone == null) return;
    if (_stage != _LaunchStage.splash) return;
    setState(() {
      _stage = (widget.showOnboardingIfNeeded && !_onboardingDone!)
          ? _LaunchStage.onboarding
          : _LaunchStage.app;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      await widget.database.markOnboardingCompleted();
    } catch (_) {
      // Never block entering the app if persisting the flag fails.
    }
    if (mounted) {
      setState(() => _stage = _LaunchStage.app);
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: switch (_stage) {
        _LaunchStage.splash => const SplashScreen(
          key: ValueKey('splash-screen'),
        ),
        _LaunchStage.onboarding => OnboardingScreen(
          key: const ValueKey('onboarding-screen'),
          onContinue: _completeOnboarding,
        ),
        _LaunchStage.app => widget.child,
      },
    );
  }
}
