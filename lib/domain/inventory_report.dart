import 'batch.dart';
import 'quantity/quantity_math.dart';

class WasteEntry {
  WasteEntry({
    required this.id,
    required this.batchId,
    required this.food,
    required num quantity,
    required this.unit,
    required this.reason,
    required this.createdAt,
  }) : quantity = normalizeQuantity(quantity);
  final int id;
  final int batchId;
  final String food;
  final double quantity;
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

  Map<String, double> get remainingByUnit {
    final scaled = {for (final unit in BatchDraft.units) unit: 0};
    for (final batch in batches) {
      scaled[batch.draft.unit] =
          scaled[batch.draft.unit]! + toScaledUnits(batch.remaining);
    }
    return {
      for (final unit in BatchDraft.units) unit: fromScaledUnits(scaled[unit]!),
    };
  }

  Map<String, double> get disposedByUnit {
    final scaled = {for (final unit in BatchDraft.units) unit: 0};
    for (final entry in disposals) {
      scaled[entry.unit] = scaled[entry.unit]! + toScaledUnits(entry.quantity);
    }
    return {
      for (final unit in BatchDraft.units) unit: fromScaledUnits(scaled[unit]!),
    };
  }
}
