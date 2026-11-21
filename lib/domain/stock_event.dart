enum StockAction { consume, dispose, correct }

class StockValidationException implements Exception {
  const StockValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

int stockDelta(StockAction action, int quantity, int remaining) {
  if (quantity < 0 || quantity > 1000000000) {
    throw const StockValidationException(
      'Enter a quantity from 0 to 1,000,000,000.',
    );
  }
  if (action == StockAction.correct) {
    if (quantity == remaining) {
      throw const StockValidationException(
        'The actual quantity already matches your stock.',
      );
    }
    return quantity - remaining;
  }
  if (quantity == 0) {
    throw const StockValidationException('Enter a quantity greater than zero.');
  }
  if (quantity > remaining) {
    throw const StockValidationException(
      'This quantity exceeds the remaining stock.',
    );
  }
  return -quantity;
}

class StockEvent {
  const StockEvent({
    required this.id,
    required this.type,
    required this.delta,
    required this.reason,
    required this.createdAt,
    required this.reversed,
  });
  final int id;
  final String type;
  final int delta;
  final String? reason;
  final DateTime createdAt;
  final bool reversed;
}
