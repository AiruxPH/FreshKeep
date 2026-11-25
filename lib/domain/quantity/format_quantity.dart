import 'quantity_math.dart';

/// Formats a quantity cleanly without trailing `.0` (e.g. `5`, `1.5`, `0.25`).
String formatQuantityValue(num quantity) {
  final scaled = toScaledUnits(quantity);
  if (scaled == 0) return '0';
  final negative = scaled < 0;
  final absScaled = scaled.abs();
  final whole = absScaled ~/ kQuantityScale;
  final frac = absScaled % kQuantityScale;
  final prefix = negative ? '-' : '';
  if (frac == 0) return '$prefix$whole';
  if (frac % 10 == 0) return '$prefix$whole.${frac ~/ 10}';
  return '$prefix$whole.${frac.toString().padLeft(2, '0')}';
}

/// Formats a quantity together with its unit, singularizing `1 piece`.
String formatQuantityLabel(num quantity, String unit) {
  final text = formatQuantityValue(quantity);
  final isOne = toScaledUnits(quantity).abs() == kQuantityScale;
  return '$text ${unit == 'pieces' && isOne ? 'piece' : unit}';
}
