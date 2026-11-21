import 'batch.dart';

class ReminderSettings {
  ReminderSettings({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.leadDays = 3,
  }) {
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        ![1, 3].contains(leadDays)) {
      throw ArgumentError('Choose a valid time and a 1- or 3-day lead window.');
    }
  }
  final bool enabled;
  final int hour;
  final int minute;
  final int leadDays;
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.batchId,
    required this.food,
    required this.printedDate,
    required this.at,
  });
  final int id;
  final int batchId;
  final String food;
  final String printedDate;
  final DateTime at;
}

/// Produce future one-off alerts, not repeating alarms that outlive a batch.
///
/// When a batch has a [BatchDraft.printedTime], the alert for the **expiry day
/// itself** (lead == 0) fires at the exact printed time instead of the user's
/// daily reminder time. Lead-day alerts (lead > 0) always use the user's chosen
/// [ReminderSettings.hour] / [ReminderSettings.minute].
List<PlannedReminder> planReminders(
  List<InventoryBatch> batches,
  ReminderSettings settings,
  DateTime now,
) {
  final plan = <PlannedReminder>[];
  for (final batch in batches) {
    if (batch.depleted || batch.draft.printedDate == null) continue;
    final date = DateTime.parse(batch.draft.printedDate!);
    final printedTime = batch.draft.printedTime;

    for (var lead = 0; lead <= settings.leadDays; lead++) {
      // For the expiry day (lead==0) use the printed time when available;
      // for lead days always use the user's chosen reminder time.
      int alertHour = settings.hour;
      int alertMinute = settings.minute;
      if (lead == 0 && printedTime != null) {
        final parts = printedTime.split(':');
        final h = parts.length == 2 ? int.tryParse(parts[0]) : null;
        final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (h != null && m != null) {
          alertHour = h;
          alertMinute = m;
        }
      }

      // Construct local calendar dates rather than subtracting 24-hour periods.
      final at = DateTime(
        date.year,
        date.month,
        date.day - lead,
        alertHour,
        alertMinute,
      );
      final id = batch.id * 4 + lead;
      if (at.isAfter(now) && id < 2147483000) {
        plan.add(
          PlannedReminder(
            id: id,
            batchId: batch.id,
            food: batch.draft.name,
            printedDate: batch.draft.printedDate!,
            at: at,
          ),
        );
      }
    }
  }
  plan.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time != 0 ? time : a.id.compareTo(b.id);
  });
  return plan;
}
