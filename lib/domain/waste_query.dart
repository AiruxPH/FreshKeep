import 'batch.dart';
import 'inventory_report.dart';
import 'quantity/quantity_math.dart';

enum WasteSort { newest, oldest, largestQty, foodName }

enum WasteDateRange { allTime, last7Days, last30Days }

/// Returns deduplicated waste reasons sorted alphabetically, placing
/// `'Unspecified'` last when present.
List<String> distinctWasteReasons(List<WasteEntry> disposals) {
  final seen = <String, String>{};
  for (final entry in disposals) {
    final trimmed = entry.reason.trim();
    if (trimmed.isEmpty) continue;
    seen.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
  }
  final reasons = seen.values.toList()
    ..sort((a, b) {
      final aUnspec = a.toLowerCase() == 'unspecified';
      final bUnspec = b.toLowerCase() == 'unspecified';
      if (aUnspec != bUnspec) return aUnspec ? 1 : -1;
      return a.toLowerCase().compareTo(b.reasonLower);
    });
  return reasons;
}

extension on String {
  String get reasonLower => toLowerCase();
}

/// Filters and sorts [disposals] without mutating the source list.
List<WasteEntry> queryWasteLog(
  List<WasteEntry> disposals,
  DateTime now, {
  String search = '',
  String? unit,
  String? reason,
  WasteDateRange dateRange = WasteDateRange.allTime,
  WasteSort sort = WasteSort.newest,
}) {
  final words = search
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final localNow = now.toLocal();
  final todayUtc = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final maxAgeDays = switch (dateRange) {
    WasteDateRange.allTime => null,
    WasteDateRange.last7Days => 6,
    WasteDateRange.last30Days => 29,
  };

  final result = disposals.where((entry) {
    if (words.isNotEmpty) {
      final haystack = '${entry.food} ${entry.reason}'.toLowerCase();
      if (!words.every(haystack.contains)) return false;
    }
    if (unit != null && entry.unit != unit) return false;
    if (reason != null && entry.reason.toLowerCase() != reason.toLowerCase()) {
      return false;
    }
    if (maxAgeDays != null) {
      final localCreated = entry.createdAt.toLocal();
      final entryDayUtc = DateTime.utc(
        localCreated.year,
        localCreated.month,
        localCreated.day,
      );
      final ageDays = todayUtc.difference(entryDayUtc).inDays;
      if (ageDays > maxAgeDays || ageDays < 0) return false;
    }
    return true;
  }).toList();

  result.sort((a, b) {
    var cmp = switch (sort) {
      WasteSort.newest => b.createdAt.compareTo(a.createdAt),
      WasteSort.oldest => a.createdAt.compareTo(b.createdAt),
      WasteSort.largestQty => b.quantity.compareTo(a.quantity),
      WasteSort.foodName => a.food.toLowerCase().compareTo(
        b.food.toLowerCase(),
      ),
    };
    if (cmp == 0) cmp = b.id.compareTo(a.id);
    return cmp;
  });

  return result;
}

/// Sums disposed quantities separately per compatible unit (`pieces`, `g`, `mL`).
Map<String, double> wasteTotalsByUnit(List<WasteEntry> entries) {
  final scaled = {for (final unit in BatchDraft.units) unit: 0};
  for (final entry in entries) {
    scaled[entry.unit] = (scaled[entry.unit] ?? 0) + toScaledUnits(entry.quantity);
  }
  return {
    for (final unit in BatchDraft.units) unit: fromScaledUnits(scaled[unit]!),
  };
}
