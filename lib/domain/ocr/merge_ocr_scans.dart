import 'ocr_models.dart';
import 'parse_food_name.dart';
import 'parse_printed_date.dart';

/// Merges one or more label scans for a single packaged item into one
/// editable draft (e.g. front-of-pack name + back/lid printed expiration date).
OcrDraftResult mergeOcrScans(List<OcrPhotoScan> scans) {
  if (scans.isEmpty) {
    return const OcrDraftResult(
      dateResult: OcrDateParseResult(
        warning: 'Scan a label photo or try a sample label first.',
      ),
      scans: [],
    );
  }

  String? suggestedName;
  final dateResults = <OcrDateParseResult>[];
  for (final scan in scans) {
    suggestedName ??= parseFoodName(scan.rawText);
    final parsedDate = parsePrintedDate(scan.rawText);
    if (parsedDate.hasDate || parsedDate.isAmbiguous) {
      dateResults.add(parsedDate);
    }
  }

  final OcrDateParseResult combinedDate;
  if (dateResults.isEmpty) {
    combinedDate = const OcrDateParseResult(
      warning: 'No readable printed date found. Date left unknown.',
    );
  } else {
    final unambiguous = <String, String>{};
    final candidates = <String, OcrDateCandidate>{};
    var hasFullDate = false;

    for (final result in dateResults) {
      if (!result.isMonthOnly && (result.hasDate || result.isAmbiguous)) {
        hasFullDate = true;
      }
      if (result.printedDate != null) {
        unambiguous.putIfAbsent(
          result.printedDate!,
          () => result.rawMatch ?? result.printedDate!,
        );
        candidates.putIfAbsent(
          '${result.printedDate!}|${result.printedDate!}',
          () => OcrDateCandidate(
            isoDate: result.printedDate!,
            label: result.printedDate!,
            rawMatch: result.rawMatch ?? result.printedDate!,
          ),
        );
      }
      for (final candidate in result.ambiguousCandidates) {
        candidates.putIfAbsent(
          '${candidate.isoDate}|${candidate.label}',
          () => candidate,
        );
      }
    }

    if (unambiguous.length == 1 &&
        candidates.length == 1 &&
        dateResults.every((r) => !r.isAmbiguous && r.hasDate)) {
      combinedDate = OcrDateParseResult(
        printedDate: unambiguous.keys.single,
        rawMatch: unambiguous.values.single,
      );
    } else if (dateResults.length == 1 &&
        dateResults.single.isAmbiguous &&
        !dateResults.single.hasDate) {
      combinedDate = dateResults.single;
    } else {
      combinedDate = OcrDateParseResult(
        rawMatch: dateResults.first.rawMatch,
        ambiguousCandidates: candidates.values.toList(),
        isMonthOnly: !hasFullDate && dateResults.every((r) => r.isMonthOnly),
        warning: unambiguous.length > 1
            ? 'Scanned photos showed different dates. Confirm the printed date or leave it unknown.'
            : dateResults.first.warning ??
                  'Printed date requires confirmation before saving.',
      );
    }
  }

  final warnings = <String>[
    if (scans.any((scan) => scan.isSample))
      'Sample text only: no real camera or image text recognition ran.',
    if (combinedDate.warning != null) combinedDate.warning!,
  ];

  return OcrDraftResult(
    suggestedName: suggestedName,
    dateResult: combinedDate,
    scans: List.unmodifiable(scans),
    warnings: warnings,
  );
}
