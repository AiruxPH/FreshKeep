import 'food_photo.dart';
import 'guidance/find_guidance_rule.dart';
import 'guidance/guidance_selection.dart';

class BatchDraft {
  BatchDraft({
    required String name,
    required this.quantity,
    required this.unit,
    required this.storage,
    this.printedDate,
    this.printedTime,
    this.photo,
    this.guidance,
  }) : name = name.trim() {
    if (this.name.isEmpty || this.name.length > 100) {
      throw ArgumentError('Enter a food name of 1 to 100 characters.');
    }
    if (quantity < 1 || quantity > 1000000000) {
      throw ArgumentError('Quantity must be between 1 and 1,000,000,000.');
    }
    if (!units.contains(unit) || !locations.contains(storage)) {
      throw ArgumentError('Choose a supported unit and storage location.');
    }
    if (printedDate != null) {
      final parsed = DateTime.tryParse(printedDate!);
      if (parsed == null || dateOnly(parsed) != printedDate) {
        throw ArgumentError('Enter a valid date in YYYY-MM-DD format.');
      }
    }
    if (printedTime != null) {
      if (printedDate == null) {
        throw ArgumentError('A printed time requires a printed date.');
      }
      final parts = printedTime!.split(':');
      final h = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        throw ArgumentError('Enter a valid time in HH:mm format.');
      }
    }
    if (guidance != null) {
      final rule = findGuidanceRule(guidance!.ruleId);
      if (rule != null && rule.storage != storage) {
        throw ArgumentError(
          'Storage guidance does not match the selected storage location.',
        );
      }
    }
  }
  static const units = ['pieces', 'g', 'mL'];
  static const locations = ['Pantry', 'Fridge', 'Freezer'];
  final String name;
  final int quantity;
  final String unit;
  final String storage;
  final String? printedDate;

  /// Optional expiry time stored as "HH:mm". Only valid when [printedDate]
  /// is also set. Null means no time was entered; date-only rules apply.
  final String? printedTime;
  final FoodPhoto? photo;
  final BatchGuidance? guidance;
  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Formats a [TimeOfDay]-style hour/minute pair as "HH:mm".
  static String timeOnly(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Full date+time display label, e.g. "2026-11-20 10:30" or "2026-11-20".
  String get dateTimeLabel {
    if (printedDate == null) return 'Date unknown';
    if (printedTime == null) return printedDate!;
    return '$printedDate $printedTime';
  }
}

String quantityLabel(int quantity, String unit) =>
    '$quantity ${unit == 'pieces' && quantity.abs() == 1 ? 'piece' : unit}';

class InventoryBatch {
  const InventoryBatch({
    required this.id,
    required this.draft,
    required this.remaining,
  });
  final int id;
  final BatchDraft draft;
  final int remaining;
  bool get depleted => remaining == 0;
}

class BatchDetailsDraft {
  factory BatchDetailsDraft({
    required String name,
    required String storage,
    String? printedDate,
    String? printedTime,
  }) {
    final checked = BatchDraft(
      name: name,
      quantity: 1,
      unit: 'pieces',
      storage: storage,
      printedDate: printedDate,
      printedTime: printedTime,
    );
    return BatchDetailsDraft._(
      checked.name,
      checked.storage,
      checked.printedDate,
      checked.printedTime,
    );
  }
  const BatchDetailsDraft._(
    this.name,
    this.storage,
    this.printedDate,
    this.printedTime,
  );
  final String name;
  final String storage;
  final String? printedDate;
  final String? printedTime;
  bool matches(BatchDraft other) =>
      name == other.name &&
      storage == other.storage &&
      printedDate == other.printedDate &&
      printedTime == other.printedTime;
}

class BatchEdit {
  const BatchEdit({
    required this.id,
    required this.before,
    required this.after,
    required this.createdAt,
    this.photoChange,
    this.guidanceChange,
  });
  final int id;
  final BatchDetailsDraft before;
  final BatchDetailsDraft after;
  final DateTime createdAt;
  final String? photoChange;
  final String? guidanceChange;
}
