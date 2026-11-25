import 'quantity_math.dart';

/// Whether [unit] allows decimal quantities (up to 2 decimal places).
bool unitAllowsDecimals(String unit) => unit == 'g' || unit == 'mL';

/// Returns true when [value] represents an exact whole integer.
bool isWholeQuantity(num value) =>
    value.isFinite && toScaledUnits(value) % kQuantityScale == 0;

/// Returns true when [value] has at most 2 decimal places.
bool hasAtMostTwoDecimals(num value) =>
    value.isFinite && (value * kQuantityScale - (value * kQuantityScale).round()).abs() < 1e-6;

/// Parses a user-entered quantity string according to [unit].
/// Returns null if empty, non-numeric, or incompatible with [unit]'s precision.
double? parseQuantityInput(String raw, String unit) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!unitAllowsDecimals(unit)) {
    final whole = int.tryParse(text);
    return whole?.toDouble();
  }
  if (!RegExp(r'^(?:\d+(?:\.\d{1,2})?|\.\d{1,2})$').hasMatch(text)) {
    return null;
  }
  final parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite) return null;
  return normalizeQuantity(parsed);
}

/// Validates [value] for [unit] and returns an error message or null if valid.
String? validateQuantityForUnit(
  num value,
  String unit, {
  bool allowZero = false,
}) {
  if (!value.isFinite) {
    return 'Enter a valid quantity.';
  }
  if (!unitAllowsDecimals(unit)) {
    if (!isWholeQuantity(value)) {
      return 'Use whole numbers for pieces.';
    }
    final min = allowZero ? 0 : 1;
    if (value < min || value > kMaxQuantity) {
      return allowZero
          ? 'Enter a whole number from 0 to 1,000,000,000.'
          : 'Enter a whole number from 1 to 1,000,000,000.';
    }
    return null;
  }
  if (!hasAtMostTwoDecimals(value)) {
    return 'Use up to 2 decimal places for $unit.';
  }
  if (allowZero ? value < 0 : value <= 0 || value > kMaxQuantity) {
    return allowZero
        ? 'Enter a quantity from 0 to 1,000,000,000.'
        : 'Enter a quantity greater than 0 up to 1,000,000,000.';
  }
  if (value > kMaxQuantity) {
    return 'Enter a quantity up to 1,000,000,000.';
  }
  return null;
}
