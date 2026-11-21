import 'batch.dart';
import 'date_status.dart';

enum StockFilter { all, active, depleted }

enum InventorySort { newest, soonestDate, name }

List<InventoryBatch> queryInventory(
  List<InventoryBatch> batches,
  DateTime now, {
  String search = '',
  String? storage,
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
    if (!words.every(batch.draft.name.toLowerCase().contains)) return false;
    if (storage != null && batch.draft.storage != storage) return false;
    if (status != null &&
        dateStatus(
              batch.draft.printedDate,
              now,
              time: batch.draft.printedTime,
            ) !=
            status) {
      return false;
    }
    if (stock == StockFilter.active && batch.depleted) return false;
    if (stock == StockFilter.depleted && !batch.depleted) return false;
    return true;
  }).toList();
  result.sort((a, b) {
    var comparison = 0;
    if (sort == InventorySort.soonestDate) {
      final first = a.draft.printedDate, second = b.draft.printedDate;
      comparison = first == null
          ? (second == null ? 0 : 1)
          : second == null
          ? -1
          : first.compareTo(second);
      if (comparison == 0 && first != null) {
        final t1 = a.draft.printedTime, t2 = b.draft.printedTime;
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
