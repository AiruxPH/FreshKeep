import 'batch.dart';

class WasteEntry {
  const WasteEntry({
    required this.id,
    required this.batchId,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.reason,
    required this.createdAt,
  });
  final int id;
  final int batchId;
  final String food;
  final int quantity;
  final String unit;
  final String reason;
  final DateTime createdAt;
}

class InventoryReport {
  InventoryReport({
    required List<InventoryBatch> batches,
    required List<WasteEntry> disposals,
  }) : batches = List.unmodifiable(batches),
       disposals = List.unmodifiable(disposals);
  final List<InventoryBatch> batches;
  final List<WasteEntry> disposals;

  int get activeBatches => batches.where((batch) => !batch.depleted).length;
  int get depletedBatches => batches.where((batch) => batch.depleted).length;

  Map<String, int> get remainingByUnit {
    final totals = {for (final unit in BatchDraft.units) unit: 0};
    for (final batch in batches) {
      totals[batch.draft.unit] = totals[batch.draft.unit]! + batch.remaining;
    }
    return totals;
  }

  Map<String, int> get disposedByUnit {
    final totals = {for (final unit in BatchDraft.units) unit: 0};
    for (final entry in disposals) {
      totals[entry.unit] = totals[entry.unit]! + entry.quantity;
    }
    return totals;
  }
}
