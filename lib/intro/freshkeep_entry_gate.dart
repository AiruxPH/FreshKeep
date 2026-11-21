import 'package:flutter/material.dart';

import 'intro_screen.dart';

/// Gates entry to [child] behind [IntroScreen] when [showIntro] is true.
class FreshKeepEntryGate extends StatefulWidget {
  const FreshKeepEntryGate({
    super.key,
    required this.showIntro,
    required this.child,
  });

  final bool showIntro;
  final Widget child;

  @override
  State<FreshKeepEntryGate> createState() => _FreshKeepEntryGateState();
}

class _FreshKeepEntryGateState extends State<FreshKeepEntryGate> {
  late bool _showingIntro = widget.showIntro;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _showingIntro
          ? IntroScreen(
              key: const ValueKey('intro-screen'),
              onContinue: () => setState(() => _showingIntro = false),
            )
          : widget.child,
    );
  }
}
