import 'batch.dart';
import 'date_status.dart';
import 'guidance/resolve_effective_date.dart';

enum StockFilter { all, active, depleted }

enum InventorySort { newest, soonestDate, name }

List<InventoryBatch> queryInventory(
  List<InventoryBatch> batches,
  DateTime now, {
  String search = '',
  String? storage,
  String? category,
  DateStatus? status,
  StockFilter stock = StockFilter.all,
  InventorySort sort = InventorySort.newest,
}) {
  final words = search
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final result = batches.where((batch) {
    final searchable =
        '${batch.draft.name} ${batch.draft.category}'.toLowerCase();
    if (!words.every(searchable.contains)) return false;
    if (storage != null && batch.draft.storage != storage) return false;
    if (category != null && batch.draft.category != category) return false;
    if (status != null) {
      final effective = resolveEffectiveDate(batch.draft);
      if (dateStatus(effective.date, now, time: effective.time) != status) {
        return false;
      }
    }
    if (stock == StockFilter.active && batch.depleted) return false;
    if (stock == StockFilter.depleted && !batch.depleted) return false;
    return true;
  }).toList();
  result.sort((a, b) {
    var comparison = 0;
    if (sort == InventorySort.soonestDate) {
      final firstEff = resolveEffectiveDate(a.draft);
      final secondEff = resolveEffectiveDate(b.draft);
      final first = firstEff.date, second = secondEff.date;
      comparison = first == null
          ? (second == null ? 0 : 1)
          : second == null
          ? -1
          : first.compareTo(second);
      if (comparison == 0 && first != null) {
        final t1 = firstEff.time, t2 = secondEff.time;
        comparison = t1 == null
            ? (t2 == null ? 0 : 1)
            : t2 == null
            ? -1
            : t1.compareTo(t2);
      }
    } else if (sort == InventorySort.name) {
      comparison = a.draft.name.toLowerCase().compareTo(
        b.draft.name.toLowerCase(),
      );
    }
    return comparison != 0 ? comparison : b.id.compareTo(a.id);
  });
  return result;
}
