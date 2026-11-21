import 'batch.dart';

/// Represents an unreversed stock movement that can still be undone.
class RecentStockAction {
  const RecentStockAction({
    required this.eventId,
    required this.batchId,
    required this.food,
    required this.unit,
    required this.type,
    required this.delta,
    this.reason,
    required this.createdAt,
  });

  final int eventId;
  final int batchId;
  final String food;
  final String unit;
  final String type;
  final int delta;
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
