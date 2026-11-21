import 'dart:async';

import 'package:flutter/widgets.dart';

/// A single calendar clock shared by all routes, without touching saved data.
class LocalDayScope extends StatefulWidget {
  const LocalDayScope({
    super.key,
    required this.child,
    this.now = DateTime.now,
  });
  final Widget child;
  final DateTime Function() now;

  static DateTime of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LocalDay>()!.day;

  @override
  State<LocalDayScope> createState() => _LocalDayScopeState();
}

class _LocalDayScopeState extends State<LocalDayScope>
    with WidgetsBindingObserver {
  late DateTime _day;
  Timer? _midnight;
  Timer? _clockCheck;

  @override
  void initState() {
    super.initState();
    _day = widget.now().toLocal();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    // Also catches clock/timezone changes while the app stays in the foreground.
    _clockCheck = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = widget.now().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      next.difference(now) + const Duration(milliseconds: 50),
      _refresh,
    );
  }

  void _refresh() {
    final now = widget.now().toLocal();
    if (_day.year != now.year ||
        _day.month != now.month ||
        _day.day != now.day ||
        _day.hour != now.hour ||
        _day.minute != now.minute) {
      setState(() => _day = now);
    }
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _clockCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LocalDay(day: _day, child: widget.child);
}

class _LocalDay extends InheritedWidget {
  const _LocalDay({required this.day, required super.child});
  final DateTime day;
  @override
  bool updateShouldNotify(_LocalDay oldWidget) => oldWidget.day != day;
}
