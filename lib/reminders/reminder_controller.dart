import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/inventory_database.dart';
import '../domain/reminder.dart';
import 'notification_service.dart';

class ReminderController extends ChangeNotifier {
  ReminderController(this.database, this.service, {this.now = DateTime.now});
  final InventoryDatabase database;
  final NotificationService service;
  final DateTime Function() now;
  ReminderSettings settings = ReminderSettings();
  List<PlannedReminder> plan = [];
  String status = 'Loading reminder settings…';
  bool failed = false;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  StreamSubscription<void>? _subscription;
  Timer? _debounce;

  Future<void> start() {
    _subscription ??= database.inventoryChanges.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () => refresh());
    });
    return refresh();
  }

  Future<void> refresh({bool requestPermission = false}) {
    final work = _queue.then((_) async {
      if (_disposed) return;
      try {
        settings = await database.loadReminderSettings();
        final batches = await database.loadBatches();
        plan = planReminders(batches, settings, now());
        if (_disposed) return;
        status = await service.replace(
          settings.enabled ? plan : [],
          enabled: settings.enabled,
          requestPermission: requestPermission,
        );
        failed = false;
      } catch (_) {
        failed = true;
        status = 'Reminder sync failed. Saved inventory is unchanged. Retry resync to check pending alerts.';
      }
      if (!_disposed) notifyListeners();
    });
    _queue = work;
    return work;
  }

  Future<void> save(ReminderSettings value) async {
    await database.saveReminderSettings(value);
    await refresh(requestPermission: value.enabled);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
