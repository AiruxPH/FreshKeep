import 'batch.dart';
import 'date_status.dart';
import 'guidance/resolve_effective_date.dart';
import 'inventory_report.dart';

class ReasonTotal {
  const ReasonTotal(this.reason, this.count);
  final String reason;
  final int count;
}

/// Pure summary metrics powering the FreshKeep Dashboard breakdown cards.
class DashboardSummary {
  const DashboardSummary({
    required this.pastCount,
    required this.urgentCount,
    required this.soonCount,
    required this.laterCount,
    required this.unknownCount,
    required this.byStorage,
    required this.topReasons,
  });

  final int pastCount;
  final int urgentCount;
  final int soonCount;
  final int laterCount;
  final int unknownCount;
  final Map<String, int> byStorage;
  final List<ReasonTotal> topReasons;

  int get attentionCount => pastCount + urgentCount + soonCount;

  factory DashboardSummary.fromReport(InventoryReport report, DateTime now) {
    var past = 0;
    var urgent = 0;
    var soon = 0;
    var later = 0;
    var unknown = 0;
    final storageCounts = {
      for (final loc in BatchDraft.locations) loc: 0,
    };

    for (final batch in report.batches) {
      if (batch.depleted) continue;
      storageCounts[batch.draft.storage] =
          (storageCounts[batch.draft.storage] ?? 0) + 1;
      final effective = resolveEffectiveDate(batch.draft);
      switch (dateStatus(effective.date, now, time: effective.time)) {
        case DateStatus.past:
          past++;
        case DateStatus.hoursLeft:
        case DateStatus.today:
          urgent++;
        case DateStatus.soon:
          soon++;
        case DateStatus.later:
          later++;
        case DateStatus.unknown:
          unknown++;
      }
    }

    final reasonCounts = <String, int>{};
    for (final entry in report.disposals) {
      reasonCounts[entry.reason] = (reasonCounts[entry.reason] ?? 0) + 1;
    }
    final topReasons = [
      for (final item in reasonCounts.entries)
        ReasonTotal(item.key, item.value),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0
            ? byCount
            : a.reason.toLowerCase().compareTo(b.reason.toLowerCase());
      });

    return DashboardSummary(
      pastCount: past,
      urgentCount: urgent,
      soonCount: soon,
      laterCount: later,
      unknownCount: unknown,
      byStorage: storageCounts,
      topReasons: topReasons,
    );
  }
}
