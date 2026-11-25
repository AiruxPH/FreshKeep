/// Curated offline food categories for organizing and searching inventory.
class FoodCategory {
  const FoodCategory._();

  static const defaultCategory = 'Other';

  static const all = [
    'Produce',
    'Meat & Seafood',
    'Dairy & Eggs',
    'Grains & Bakery',
    'Canned & Dry',
    'Beverages',
    'Leftovers & Prepared',
    'Condiments & Sauces',
    'Other',
  ];

  /// Returns a valid category from [all], defaulting to [defaultCategory] when
  /// [raw] is null or blank. Throws [ArgumentError] for unrecognized non-empty
  /// categories.
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaultCategory;
    final trimmed = raw.trim();
    if (!all.contains(trimmed)) {
      throw ArgumentError('Choose a supported food category.');
    }
    return trimmed;
  }
}
