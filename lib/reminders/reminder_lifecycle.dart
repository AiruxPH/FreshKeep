import 'package:flutter/widgets.dart';

import 'reminder_controller.dart';

class ReminderLifecycle extends StatefulWidget {
  const ReminderLifecycle({
    super.key,
    required this.controller,
    required this.child,
  });
  final ReminderController? controller;
  final Widget child;
  @override
  State<ReminderLifecycle> createState() => _ReminderLifecycleState();
}

class _ReminderLifecycleState extends State<ReminderLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller?.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
