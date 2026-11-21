class StorageGuidance {
  const StorageGuidance({
    required this.id,
    required this.food,
    required this.searchTerms,
    required this.condition,
    required this.storage,
    required this.duration,
    required this.minDays,
    required this.maxDays,
    required this.defaultAnchorEvent,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.sourceLocation,
  });
  final String id;
  final String food;
  final List<String> searchTerms;
  final String condition;
  final String storage;
  final String duration;
  final int minDays;
  final int maxDays;
  final String defaultAnchorEvent;
  final String sourceTitle;
  final String sourceUrl;
  final String sourceLocation;
  static const reviewedOn = '2026-11-01';
  static const catalogVersion = '2026-11-01.1';
  static const anchorEvents = [
    'Purchased',
    'Opened',
    'Cooked',
    'Refrigerated',
    'Stored',
  ];

  bool matches(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final text = '$food ${searchTerms.join(' ')} $condition'.toLowerCase();
    return terms.every(text.contains);
  }
}
