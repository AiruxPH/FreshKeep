import 'quantity/quantity_math.dart';
import 'quantity/validate_quantity.dart';

enum StockAction { consume, dispose, correct }

class StockValidationException implements Exception {
  const StockValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

double stockDelta(
  StockAction action,
  num quantity,
  num remaining, {
  String unit = 'g',
}) {
  final quantityError = validateQuantityForUnit(
    quantity,
    unit,
    allowZero: true,
  );
  if (quantityError != null) {
    throw StockValidationException(quantityError);
  }
  final scaledQty = toScaledUnits(quantity);
  final scaledRem = toScaledUnits(remaining);
  if (action == StockAction.correct) {
    if (scaledQty == scaledRem) {
      throw const StockValidationException(
        'The actual quantity already matches your stock.',
      );
    }
    return fromScaledUnits(scaledQty - scaledRem);
  }
  if (scaledQty <= 0) {
    throw const StockValidationException('Enter a quantity greater than zero.');
  }
  if (scaledQty > scaledRem) {
    throw const StockValidationException(
      'This quantity exceeds the remaining stock.',
    );
  }
  return fromScaledUnits(-scaledQty);
}

class StockEvent {
  StockEvent({
    required this.id,
    required this.type,
    required num delta,
    required this.reason,
    required this.createdAt,
    required this.reversed,
  }) : delta = normalizeQuantity(delta);
  final int id;
  final String type;
  final double delta;
  final String? reason;
  final DateTime createdAt;
  final bool reversed;
}
