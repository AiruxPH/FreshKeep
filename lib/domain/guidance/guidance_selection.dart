import '../storage_guidance.dart';
import 'calculate_suggested_dates.dart';
import 'find_guidance_rule.dart';

/// Persisted storage-guidance selection attached to a grocery batch, keeping
/// rule provenance, confirmed starting event/date, and calculated window
/// separate from any printed packaging date.
class BatchGuidance {
  factory BatchGuidance.fromRule({
    required StorageGuidance rule,
    required String anchorEvent,
    required String anchorDate,
  }) {
    final trimmedEvent = anchorEvent.trim();
    if (trimmedEvent.isEmpty || trimmedEvent.length > 40) {
      throw ArgumentError('Choose a valid starting event.');
    }
    final dates = calculateSuggestedDates(rule, anchorDate);
    return BatchGuidance._(
      ruleId: rule.id,
      catalogVersion: StorageGuidance.catalogVersion,
      anchorEvent: trimmedEvent,
      anchorDate: anchorDate,
      suggestedDate: dates.earliest,
      suggestedEndDate: dates.latest,
    );
  }

  /// Reconstructs persisted guidance loaded from local SQLite storage.
  factory BatchGuidance.stored({
    required String ruleId,
    required String catalogVersion,
    required String anchorEvent,
    required String anchorDate,
    required String suggestedDate,
  }) {
    _requireValidDate(anchorDate);
    _requireValidDate(suggestedDate);
    final trimmedEvent = anchorEvent.trim();
    if (trimmedEvent.isEmpty || trimmedEvent.length > 40) {
      throw ArgumentError('Choose a valid starting event.');
    }
    final rule = findGuidanceRule(ruleId);
    final endDate = rule == null
        ? suggestedDate
        : calculateSuggestedDates(rule, anchorDate).latest;
    return BatchGuidance._(
      ruleId: ruleId,
      catalogVersion: catalogVersion,
      anchorEvent: trimmedEvent,
      anchorDate: anchorDate,
      suggestedDate: suggestedDate,
      suggestedEndDate: endDate,
    );
  }

  const BatchGuidance._({
    required this.ruleId,
    required this.catalogVersion,
    required this.anchorEvent,
    required this.anchorDate,
    required this.suggestedDate,
    required this.suggestedEndDate,
  });

  final String ruleId;
  final String catalogVersion;
  final String anchorEvent;
  final String anchorDate;
  final String suggestedDate;
  final String suggestedEndDate;

  bool get hasRange => suggestedEndDate != suggestedDate;

  bool sameAs(BatchGuidance? other) =>
      other != null &&
      ruleId == other.ruleId &&
      catalogVersion == other.catalogVersion &&
      anchorEvent == other.anchorEvent &&
      anchorDate == other.anchorDate &&
      suggestedDate == other.suggestedDate;

  static void _requireValidDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) {
      throw ArgumentError('Enter a valid date in YYYY-MM-DD format.');
    }
    final formatted =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    if (formatted != isoDate) {
      throw ArgumentError('Enter a valid date in YYYY-MM-DD format.');
    }
  }
}
