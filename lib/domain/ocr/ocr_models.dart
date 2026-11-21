import '../food_photo.dart';

/// A candidate printed expiration date extracted from OCR text that requires
/// explicit user confirmation before pre-filling a batch date.
class OcrDateCandidate {
  const OcrDateCandidate({
    required this.isoDate,
    required this.label,
    required this.rawMatch,
    this.note,
  });

  final String isoDate;
  final String label;
  final String rawMatch;
  final String? note;
}

/// Outcome of scanning OCR text for a visible printed expiration date.
///
/// Missing, manufacturing-only, or ambiguous dates leave [printedDate] `null`
/// so FreshKeep never guesses an expiration date silently.
class OcrDateParseResult {
  const OcrDateParseResult({
    this.printedDate,
    this.rawMatch,
    this.ambiguousCandidates = const [],
    this.warning,
    this.isMonthOnly = false,
  });

  final String? printedDate;
  final String? rawMatch;
  final List<OcrDateCandidate> ambiguousCandidates;
  final String? warning;
  final bool isMonthOnly;

  bool get hasDate => printedDate != null;
  bool get isAmbiguous => ambiguousCandidates.isNotEmpty;
}

/// One scanned image or sample input belonging to a single packaged item.
class OcrPhotoScan {
  const OcrPhotoScan({
    required this.id,
    required this.sourceLabel,
    required this.rawText,
    required this.elapsedMs,
    required this.isSample,
    this.photo,
  });

  final String id;
  final String sourceLabel;
  final String rawText;
  final int elapsedMs;
  final bool isSample;
  final FoodPhoto? photo;
}

/// Combined editable suggestion produced from one or more label scans.
class OcrDraftResult {
  const OcrDraftResult({
    this.suggestedName,
    required this.dateResult,
    required this.scans,
    this.warnings = const [],
  });

  final String? suggestedName;
  final OcrDateParseResult dateResult;
  final List<OcrPhotoScan> scans;
  final List<String> warnings;
}

/// User-reviewed draft handed off from [ScanLabelScreen] to
/// [AddGroceriesScreen]. Never written to SQLite automatically.
class OcrGroceryDraft {
  const OcrGroceryDraft({
    required this.name,
    this.printedDate,
    this.photo,
    this.fromSampleMode = false,
    this.rawOcrSummary,
  });

  final String name;
  final String? printedDate;
  final FoodPhoto? photo;
  final bool fromSampleMode;
  final String? rawOcrSummary;
}
