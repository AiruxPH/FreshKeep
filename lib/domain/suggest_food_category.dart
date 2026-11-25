class _CategoryRule {
  const _CategoryRule(this.category, this.keywords);
  final String category;
  final List<String> keywords;
}

const List<_CategoryRule> _categoryRules = [
  _CategoryRule('Leftovers & Prepared', [
    'leftover',
    'leftovers',
    'cooked',
    'fried rice',
    'adobo',
    'sinigang',
    'ulam',
    'viand',
    'bento',
    'meal',
    'pizza',
    'burger',
    'sandwich',
    'curry',
    'stew',
  ]),
  _CategoryRule('Condiments & Sauces', [
    'soy sauce',
    'vinegar',
    'ketchup',
    'mayo',
    'mayonnaise',
    'mustard',
    'fish sauce',
    'patis',
    'bagoong',
    'oyster sauce',
    'hot sauce',
    'cooking oil',
    'olive oil',
    'sesame oil',
    'oil',
    'dressing',
    'jam',
    'jelly',
    'honey',
    'peanut butter',
    'syrup',
    'gravy',
    'sauce',
    'seasoning',
    'spice',
  ]),
  _CategoryRule('Canned & Dry', [
    'canned',
    'instant',
    'ramen',
    'beans',
    'lentil',
    'lentils',
    'peanut',
    'peanuts',
    'almond',
    'almonds',
    'cashew',
    'cashews',
    'nut',
    'nuts',
    'sugar',
    'salt',
    'chips',
    'chip',
    'snack',
  ]),
  _CategoryRule('Beverages', [
    'water',
    'juice',
    'coffee',
    'tea',
    'soda',
    'cola',
    'softdrink',
    'beer',
    'wine',
    'smoothie',
    'shake',
    'soy milk',
    'oat milk',
    'almond milk',
    'milo',
    'yakult',
    'drink',
  ]),
  _CategoryRule('Dairy & Eggs', [
    'egg',
    'eggs',
    'milk',
    'cheese',
    'cheddar',
    'mozzarella',
    'butter',
    'yogurt',
    'yoghurt',
    'cream',
    'margarine',
  ]),
  _CategoryRule('Meat & Seafood', [
    'chicken',
    'pork',
    'beef',
    'fish',
    'tuna',
    'salmon',
    'shrimp',
    'prawn',
    'squid',
    'crab',
    'bacon',
    'ham',
    'sausage',
    'hotdog',
    'tocino',
    'longganisa',
    'sardines',
    'bangus',
    'tilapia',
    'meat',
    'steak',
    'turkey',
    'duck',
  ]),
  _CategoryRule('Produce', [
    'mango',
    'banana',
    'apple',
    'orange',
    'calamansi',
    'lemon',
    'lime',
    'grape',
    'tomato',
    'potato',
    'onion',
    'garlic',
    'ginger',
    'carrot',
    'cabbage',
    'lettuce',
    'spinach',
    'kangkong',
    'malunggay',
    'pechay',
    'broccoli',
    'cucumber',
    'eggplant',
    'okra',
    'squash',
    'avocado',
    'papaya',
    'pineapple',
    'watermelon',
    'strawberry',
    'vegetable',
    'fruit',
    'chili',
    'pepper',
    'herb',
  ]),
  _CategoryRule('Grains & Bakery', [
    'rice',
    'bread',
    'loaf',
    'pandesal',
    'pasta',
    'spaghetti',
    'macaroni',
    'noodle',
    'noodles',
    'pancit',
    'oats',
    'oatmeal',
    'flour',
    'cereal',
    'tortilla',
    'bun',
    'bagel',
    'cracker',
    'biscuit',
    'cookie',
    'cake',
    'pastry',
  ]),
];

/// Suggests an offline food category for [foodName] using prioritized
/// word-boundary/phrase matching, or returns `null` when unrecognized.
String? suggestFoodCategory(String foodName) {
  final normalized = foodName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return null;

  for (final rule in _categoryRules) {
    for (final keyword in rule.keywords) {
      final pattern = RegExp('(^|\\s)${RegExp.escape(keyword)}(\\s|\$)');
      if (pattern.hasMatch(normalized)) {
        return rule.category;
      }
    }
  }
  return null;
}

/// Returns a helpful mismatch warning when [foodName] maps strongly to a
/// different category than [selectedCategory], or `null` when aligned/unknown.
String? categoryMismatchWarning(String foodName, String selectedCategory) {
  final suggested = suggestFoodCategory(foodName);
  if (suggested == null || suggested == selectedCategory) return null;
  return 'Suggested category for "${foodName.trim()}" is $suggested (currently $selectedCategory).';
}
