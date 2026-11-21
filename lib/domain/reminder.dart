import 'batch.dart';
import 'guidance/resolve_effective_date.dart';

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
    this.dateSource = 'printed',
  });
  final int id;
  final int batchId;
  final String food;
  final String printedDate;
  final DateTime at;
  final String dateSource;
}

/// Produce future one-off alerts, not repeating alarms that outlive a batch.
///
/// Uses each active batch's effective date (printed packaging date first,
/// falling back to a confirmed calculated guidance suggested date).
/// When an effective printed date has a [BatchDraft.printedTime], the expiry-day
/// alert (`lead == 0`) fires at that exact time; lead-day alerts always use
/// [ReminderSettings.hour] and [ReminderSettings.minute].
List<PlannedReminder> planReminders(
  List<InventoryBatch> batches,
  ReminderSettings settings,
  DateTime now,
) {
  final plan = <PlannedReminder>[];
  for (final batch in batches) {
    if (batch.depleted) continue;
    final effective = resolveEffectiveDate(batch.draft);
    if (effective.date == null) continue;
    final date = DateTime.parse(effective.date!);
    final printedTime = effective.time;

    for (var lead = 0; lead <= settings.leadDays; lead++) {
      // For the expiry day (lead==0) use the printed time when available;
      // for lead days always use the user's chosen reminder time.
      var alertHour = settings.hour;
      var alertMinute = settings.minute;
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
            printedDate: effective.date!,
            at: at,
            dateSource: effective.source.name,
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
