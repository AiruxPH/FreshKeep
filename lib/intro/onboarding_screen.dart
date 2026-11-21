import 'dart:async';

import 'package:flutter/material.dart';

import 'intro_feature_tile.dart';

/// First-open onboarding screen introducing FreshKeep before entering the app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onContinue});

  final FutureOr<void> Function() onContinue;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _continuing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    try {
      await widget.onContinue();
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDECE1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Welcome',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: const Color(0xFF28664B),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/icon/freshkeep_icon_master.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: const Color(0xFF28664B),
                              child: const Icon(
                                Icons.eco_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'FreshKeep',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3329),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep track of what’s in your kitchen, offline.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      const IntroFeatureTile(
                        icon: Icons.inventory_2_outlined,
                        title: 'Track batches & dates',
                        subtitle:
                            'Printed dates, expiry times, and cited storage guidance.',
                      ),
                      const SizedBox(height: 12),
                      const IntroFeatureTile(
                        icon: Icons.schedule_outlined,
                        title: 'Clear time-left reminders',
                        subtitle:
                            'See weeks, days, hours, or minutes remaining at a glance.',
                      ),
                      const SizedBox(height: 12),
                      const IntroFeatureTile(
                        icon: Icons.offline_pin_outlined,
                        title: 'Private & offline',
                        subtitle:
                            'Your inventory, photos, and history stay on this device.',
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        key: const ValueKey('intro-continue'),
                        onPressed: _continuing ? null : _handleContinue,
                        child: Text(_continuing ? 'Starting…' : 'Get started'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
