import 'batch.dart';
import 'quantity/quantity_math.dart';

/// Represents an unreversed stock movement that can still be undone.
class RecentStockAction {
  RecentStockAction({
    required this.eventId,
    required this.batchId,
    required this.food,
    required this.unit,
    required this.type,
    required num delta,
    this.reason,
    required this.createdAt,
  }) : delta = normalizeQuantity(delta);

  final int eventId;
  final int batchId;
  final String food;
  final String unit;
  final String type;
  final double delta;
  final String? reason;
  final DateTime createdAt;

  String get actionSummary {
    if (type == 'consume') return 'Used ${quantityLabel(delta.abs(), unit)}';
    if (type == 'dispose') {
      return 'Discarded ${quantityLabel(delta.abs(), unit)}';
    }
    final sign = delta > 0 ? '+' : '';
    return 'Corrected $sign${quantityLabel(delta, unit)}';
  }
}
