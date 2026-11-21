final RegExp _dateLikeLineRegex = RegExp(
  r'^(?:EXP(?:IRY|IRES|IRATION)?|BEST\s*BEFORE|BEST\s*BY|BBE|BB|USE\s*BEFORE|USE\s*BY|CONSUME\s*BY|SELL\s*BY|MFG|MFD|PROD(?:UCTION)?|PKD|PACKED|LOT|BATCH|SKU|BARCODE)\b',
  caseSensitive: false,
);

final RegExp _standaloneDateRegex = RegExp(
  r'^(?:20\d{2}[/\.\-]\d{1,2}[/\.\-]\d{1,2}|\d{1,2}[/\.\-]\d{1,2}[/\.\-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4})$',
  caseSensitive: false,
);

final RegExp _weightOrPriceRegex = RegExp(
  r'^(?:NET\s*WT\.?\s*|WT\.?\s*|VOL\.?\s*|PRICE\s*)?(?:[\$₱€£]|PHP|USD)?\s*\d+(?:[.,]\d+)?\s*(?:G|KG|MG|ML|L|OZ|LB|PCS?|PC)?$',
  caseSensitive: false,
);

final RegExp _urlOrEmailRegex = RegExp(
  r'(?:https?:\/\/|www\.|\.com\b|\.ph\b|\.net\b|\.org\b|@)',
  caseSensitive: false,
);

final RegExp _longDigitsRegex = RegExp(r'\d{5,}');

final RegExp _twoLettersRegex = RegExp(r'[A-Za-z].*[A-Za-z]');

const List<String> _boilerplatePrefixes = [
  'nutrition facts',
  'nutrition information',
  'ingredients',
  'serving size',
  'servings per',
  'calories',
  'total fat',
  'saturated fat',
  'cholesterol',
  'sodium',
  'total carbohydrate',
  'dietary fiber',
  'protein',
  'keep refrigerated',
  'keep frozen',
  'store in',
  'storage',
  'product of',
  'manufactured by',
  'distributed by',
  'packed by',
  'imported by',
  'allergen',
  'contains:',
  'shake well',
  'open here',
  'tear here',
  'best before',
  'use by',
  'expiry',
  'manufactured',
];

/// Extracts a clean candidate food/product name from packaging OCR [rawText],
/// skipping barcodes, weights, prices, date lines, URLs, and label headers.
String? parseFoodName(String rawText) {
  if (rawText.trim().isEmpty) return null;

  for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
    var line = rawLine.trim().replaceAll(RegExp(r'\s+'), ' ');
    line = line.replaceAll(RegExp(r'^[,.;:\-_|/*•·]+|[,.;:\-_|/*•·]+$'), '').trim();
    if (line.length < 2 || line.length > 100) continue;
    if (!_twoLettersRegex.hasMatch(line)) continue;
    if (_urlOrEmailRegex.hasMatch(line)) continue;
    if (_longDigitsRegex.hasMatch(line)) continue;
    if (_dateLikeLineRegex.hasMatch(line)) continue;
    if (_standaloneDateRegex.hasMatch(line)) continue;
    if (_weightOrPriceRegex.hasMatch(line)) continue;

    final lower = line.toLowerCase();
    if (_boilerplatePrefixes.any((prefix) => lower.startsWith(prefix))) {
      continue;
    }

    final normalized = _normalizeCasing(line);
    return normalized.length > 100 ? normalized.substring(0, 100) : normalized;
  }
  return null;
}

String _normalizeCasing(String text) {
  final letters = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) {
    return text;
  }
  final words = text.split(' ');
  return [
    for (final word in words)
      word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase(),
  ].join(' ');
}
