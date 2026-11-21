import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder.dart';
import 'resolve_local_timezone.dart';

abstract class NotificationService {
  bool get supported;
  Future<String> replace(
    List<PlannedReminder> plan, {
    required bool enabled,
    bool requestPermission = false,
  });
  Future<void> sendTest();
  Future<void> openSettings();
}

class PreviewNotifications implements NotificationService {
  @override
  bool get supported => false;
  @override
  Future<String> replace(
    List<PlannedReminder> plan, {
    required bool enabled,
    bool requestPermission = false,
  }) async =>
      'Preview only on web. No device notifications are scheduled in this browser.';
  @override
  Future<void> sendTest() async =>
      throw UnsupportedError('Android notification test only.');
  @override
  Future<void> openSettings() async {}
}

NotificationService createNotificationService() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? AndroidNotifications()
    : PreviewNotifications();

class AndroidNotifications implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  @override
  bool get supported => true;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'freshkeep_dates',
      'Food date reminders',
      channelDescription: 'Reminders to review recorded printed food dates.',
      icon: 'ic_stat_freshkeep',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> _initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_freshkeep'),
      ),
    );
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  @override
  Future<String> replace(
    List<PlannedReminder> plan, {
    required bool enabled,
    bool requestPermission = false,
  }) async {
    await _initialize();
    // FreshKeep currently owns all notifications created by this plugin instance.
    await _plugin.cancelAll();
    if (!enabled) return 'Reminders are off. Pending alerts have been cleared.';
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    var notificationsEnabled = await android.areNotificationsEnabled() == true;
    if (!notificationsEnabled && requestPermission) {
      await android.requestNotificationsPermission();
      notificationsEnabled = await android.areNotificationsEnabled() == true;
    }
    if (!notificationsEnabled) {
      return 'Settings saved, but Android notifications are blocked. Allow notifications in Android settings, then resync.';
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(resolveLocalTimezone(zone.identifier));
    try {
      for (final reminder in plan) {
        final at = tz.TZDateTime.from(reminder.at, tz.local);
        if (!at.isAfter(tz.TZDateTime.now(tz.local))) continue;
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: 'Review ${reminder.food}',
          body: reminder.dateSource == 'suggested'
              ? 'Suggested date (guidance): ${reminder.printedDate}. Review this batch in FreshKeep.'
              : 'Printed date: ${reminder.printedDate}. Review this batch in FreshKeep.',
          scheduledDate: at,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '${reminder.batchId}',
        );
      }
    } catch (_) {
      await _plugin.cancelAll();
      rethrow;
    }
    return 'Android reminders synchronized. Delivery may be delayed by battery settings.';
  }

  @override
  Future<void> sendTest() async {
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    var enabled = await android.areNotificationsEnabled() == true;
    if (!enabled) {
      await android.requestNotificationsPermission();
      enabled = await android.areNotificationsEnabled() == true;
    }
    if (!enabled) {
      throw StateError('Notifications are disabled in Android settings.');
    }
    await _plugin.show(
      id: 2147483640,
      title: 'FreshKeep test reminder',
      body:
          'Notifications are available. Scheduled delivery still needs a device check.',
      notificationDetails: _details,
    );
  }

  @override
  Future<void> openSettings() async {
    await _initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.openAppNotificationSettings();
  }
}
