import '../storage_guidance.dart';
import 'add_calendar_days.dart';

/// Computes the earliest and latest suggested calendar dates (`YYYY-MM-DD`)
/// from a verified [StorageGuidance] rule and confirmed [anchorDate].
({String earliest, String latest}) calculateSuggestedDates(
  StorageGuidance rule,
  String anchorDate,
) => (
  earliest: addCalendarDays(anchorDate, rule.minDays),
  latest: addCalendarDays(anchorDate, rule.maxDays),
);
