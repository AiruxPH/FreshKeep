import '../batch.dart';

enum EffectiveDateSource { printed, suggested, unknown }

class EffectiveBatchDate {
  const EffectiveBatchDate({this.date, this.time, required this.source});
  final String? date;
  final String? time;
  final EffectiveDateSource source;
}

/// Resolves the active review date for status labels, sorting, and reminders.
/// Printed packaging dates always take priority over calculated guidance dates.
EffectiveBatchDate resolveEffectiveDate(BatchDraft draft) {
  if (draft.printedDate != null) {
    return EffectiveBatchDate(
      date: draft.printedDate,
      time: draft.printedTime,
      source: EffectiveDateSource.printed,
    );
  }
  if (draft.guidance != null) {
    return EffectiveBatchDate(
      date: draft.guidance!.suggestedDate,
      source: EffectiveDateSource.suggested,
    );
  }
  return const EffectiveBatchDate(source: EffectiveDateSource.unknown);
}
