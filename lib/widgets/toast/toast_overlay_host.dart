import 'dart:async';

import 'package:flutter/material.dart';

import 'toast_state.dart';

/// Animates and auto-dismisses a floating toast overlay after [duration].
class ToastOverlayHost extends StatefulWidget {
  const ToastOverlayHost({
    super.key,
    required this.entry,
    required this.duration,
    required this.onDismiss,
    required this.child,
  });

  final OverlayEntry entry;
  final Duration duration;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<ToastOverlayHost> createState() => _ToastOverlayHostState();
}

class _ToastOverlayHostState extends State<ToastOverlayHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    clearActiveToastIfMatches(widget.entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomOffset = bottomInset + (size.width < 1000 ? 88 : 24);

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
