import 'ocr_models.dart';

enum _LineCue { neutral, expiry, manufacturing }

class _ExtractedDate {
  const _ExtractedDate({
    required this.lineCue,
    required this.isMonthOnly,
    required this.rawMatch,
    this.unambiguousIso,
    this.candidates = const [],
  });

  final _LineCue lineCue;
  final bool isMonthOnly;
  final String rawMatch;
  final String? unambiguousIso;
  final List<OcrDateCandidate> candidates;
}

const Map<String, int> _monthMap = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

const List<String> _monthShortNames = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final RegExp _expiryCueRegex = RegExp(
  r'\b(EXP(?:IRY|IRES|IRATION)?|BEST\s*BEFORE|BEST\s*BY|BBE|BB|USE\s*BEFORE|USE\s*BY|CONSUME\s*BY|SELL\s*BY)\b',
  caseSensitive: false,
);

final RegExp _mfgCueRegex = RegExp(
  r'\b(MFG|MFD|PROD(?:UCTION)?|PACKED|PKD|MANUF(?:ACTURED)?|BOTTLED)\b',
  caseSensitive: false,
);

final RegExp _isoRegex = RegExp(
  r'\b(20\d{2})[/\.\-](\d{1,2})[/\.\-](\d{1,2})\b',
);

final RegExp _dayMonthNameRegex = RegExp(
  r'\b(\d{1,2})[\s/\-\.]*(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)[\s,\-/\.]*(\d{2,4})\b',
  caseSensitive: false,
);

final RegExp _monthNameDayRegex = RegExp(
  r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)[\s,\-/\.]*(\d{1,2})(?:st|nd|rd|th)?[\s,\-/\.]+(\d{2,4})\b',
  caseSensitive: false,
);

final RegExp _numericDmyMdyRegex = RegExp(
  r'\b(\d{1,2})[/\.\-](\d{1,2})[/\.\-](\d{2,4})\b',
);

final RegExp _monthYearNumericRegex = RegExp(
  r'\b(?:(\d{1,2})[/\.\-](20\d{2})|(20\d{2})[/\.\-](\d{1,2}))\b',
);

final RegExp _monthYearShortNumericRegex = RegExp(
  r'\b(\d{1,2})[/\.\-](\d{2})\b',
);

final RegExp _monthNameYearRegex = RegExp(
  r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)[\s,\-/\.]*(\d{2,4})\b',
  caseSensitive: false,
);

/// Extracts a strictly validated printed expiration date from OCR [rawText].
///
/// Never invents a date from missing or unreadable text, ignores manufacturing
/// dates (`MFG`/`MFD`/`PROD`/`PKD`), and keeps ambiguous numeric dates or
/// month-only dates `null` until the user picks a candidate explicitly.
OcrDateParseResult parsePrintedDate(String rawText) {
  if (rawText.trim().isEmpty) {
    return const OcrDateParseResult(
      warning: 'No readable printed date found. Date left unknown.',
    );
  }

  final lines = rawText.split(RegExp(r'\r?\n'));
  final extracted = <_ExtractedDate>[];
  var inheritedCue = _LineCue.neutral;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final lineResults = _extractLineDates(line, inheritedCue);
    extracted.addAll(lineResults);

    // If a line contains only a cue label (e.g. "BEST BEFORE") with no date on
    // the same line, inherit that cue onto the very next non-empty line.
    if (lineResults.isEmpty) {
      if (_expiryCueRegex.hasMatch(line)) {
        inheritedCue = _LineCue.expiry;
      } else if (_mfgCueRegex.hasMatch(line)) {
        inheritedCue = _LineCue.manufacturing;
      } else {
        inheritedCue = _LineCue.neutral;
      }
    } else {
      inheritedCue = _LineCue.neutral;
    }
  }

  final usable = extracted
      .where((item) => item.lineCue != _LineCue.manufacturing)
      .toList();
  if (usable.isEmpty) {
    return const OcrDateParseResult(
      warning: 'No readable printed date found. Date left unknown.',
    );
  }

  final expiryCued = usable
      .where((item) => item.lineCue == _LineCue.expiry)
      .toList();
  final prioritized = expiryCued.isNotEmpty ? expiryCued : usable;

  final fullDates = prioritized.where((item) => !item.isMonthOnly).toList();
  if (fullDates.isNotEmpty) {
    final distinctUnambiguous = <String, String>{};
    final allCandidates = <String, OcrDateCandidate>{};

    for (final item in fullDates) {
      if (item.unambiguousIso != null) {
        distinctUnambiguous.putIfAbsent(
          item.unambiguousIso!,
          () => item.rawMatch,
        );
        allCandidates.putIfAbsent(
          '${item.unambiguousIso!}|${item.unambiguousIso!}',
          () => OcrDateCandidate(
            isoDate: item.unambiguousIso!,
            label: item.unambiguousIso!,
            rawMatch: item.rawMatch,
          ),
        );
      }
      for (final candidate in item.candidates) {
        allCandidates.putIfAbsent(
          '${candidate.isoDate}|${candidate.label}',
          () => candidate,
        );
      }
    }

    if (distinctUnambiguous.length == 1 &&
        allCandidates.length == 1 &&
        fullDates.every((item) => item.candidates.isEmpty)) {
      final onlyIso = distinctUnambiguous.keys.single;
      return OcrDateParseResult(
        printedDate: onlyIso,
        rawMatch: distinctUnambiguous.values.single,
      );
    }

    final firstRaw = fullDates.first.rawMatch;
    final warning = distinctUnambiguous.length > 1
        ? 'Multiple printed dates found ($firstRaw and others). Confirm the right date or leave it unknown.'
        : 'Date format "$firstRaw" is ambiguous (DD/MM vs MM/DD). Confirm which date is printed or leave it unknown.';
    return OcrDateParseResult(
      rawMatch: firstRaw,
      ambiguousCandidates: allCandidates.values.toList(),
      warning: warning,
    );
  }

  final monthCandidates = <String, OcrDateCandidate>{};
  for (final item in prioritized.where((e) => e.isMonthOnly)) {
    for (final candidate in item.candidates) {
      monthCandidates.putIfAbsent(
        '${candidate.isoDate}|${candidate.label}',
        () => candidate,
      );
    }
  }
  return OcrDateParseResult(
    rawMatch: prioritized.first.rawMatch,
    ambiguousCandidates: monthCandidates.values.toList(),
    isMonthOnly: true,
    warning:
        'Only month and year were found. Date left unknown unless you confirm the end-of-month date.',
  );
}

List<_ExtractedDate> _extractLineDates(String line, _LineCue inheritedCue) {
  final consumed = <List<int>>[];
  final results = <_ExtractedDate>[];

  bool overlaps(int start, int end) =>
      consumed.any((span) => start < span[1] && end > span[0]);

  void claim(int start, int end) => consumed.add([start, end]);

  for (final match in _isoRegex.allMatches(line)) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    claim(match.start, match.end);
    final iso = _validIsoDate(year, month, day);
    if (iso == null) continue;
    results.add(
      _ExtractedDate(
        lineCue: _cueForOffset(line, match.start, inheritedCue),
        isMonthOnly: false,
        rawMatch: match.group(0)!,
        unambiguousIso: iso,
      ),
    );
  }

  for (final match in _dayMonthNameRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final day = int.parse(match.group(1)!);
    final month = _monthMap[match.group(2)!.toLowerCase()];
    final year = _expandYear(int.parse(match.group(3)!));
    if (year != null) claim(match.start, match.end);
    final iso = month == null || year == null
        ? null
        : _validIsoDate(year, month, day);
    if (iso == null) continue;
    results.add(
      _ExtractedDate(
        lineCue: _cueForOffset(line, match.start, inheritedCue),
        isMonthOnly: false,
        rawMatch: match.group(0)!,
        unambiguousIso: iso,
      ),
    );
  }

  for (final match in _monthNameDayRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final month = _monthMap[match.group(1)!.toLowerCase()];
    final day = int.parse(match.group(2)!);
    final year = _expandYear(int.parse(match.group(3)!));
    if (year != null) claim(match.start, match.end);
    final iso = month == null || year == null
        ? null
        : _validIsoDate(year, month, day);
    if (iso == null) continue;
    results.add(
      _ExtractedDate(
        lineCue: _cueForOffset(line, match.start, inheritedCue),
        isMonthOnly: false,
        rawMatch: match.group(0)!,
        unambiguousIso: iso,
      ),
    );
  }

  for (final match in _numericDmyMdyRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    final year = _expandYear(int.parse(match.group(3)!));
    if (year == null) continue;
    claim(match.start, match.end);
    if (a < 1 || b < 1) continue;
    final cue = _cueForOffset(line, match.start, inheritedCue);
    final raw = match.group(0)!;

    if (a > 12 && b <= 12) {
      final iso = _validIsoDate(year, b, a);
      if (iso == null) continue;
      results.add(
        _ExtractedDate(
          lineCue: cue,
          isMonthOnly: false,
          rawMatch: raw,
          unambiguousIso: iso,
        ),
      );
    } else if (b > 12 && a <= 12) {
      final iso = _validIsoDate(year, a, b);
      if (iso == null) continue;
      results.add(
        _ExtractedDate(
          lineCue: cue,
          isMonthOnly: false,
          rawMatch: raw,
          unambiguousIso: iso,
        ),
      );
    } else if (a == b && a <= 12) {
      final iso = _validIsoDate(year, a, b);
      if (iso == null) continue;
      results.add(
        _ExtractedDate(
          lineCue: cue,
          isMonthOnly: false,
          rawMatch: raw,
          unambiguousIso: iso,
        ),
      );
    } else if (a <= 12 && b <= 12) {
      final dmy = _validIsoDate(year, b, a);
      final mdy = _validIsoDate(year, a, b);
      if (dmy == null || mdy == null) continue;
      results.add(
        _ExtractedDate(
          lineCue: cue,
          isMonthOnly: false,
          rawMatch: raw,
          candidates: [
            OcrDateCandidate(
              isoDate: dmy,
              label: '$dmy (DD/MM)',
              rawMatch: raw,
            ),
            OcrDateCandidate(
              isoDate: mdy,
              label: '$mdy (MM/DD)',
              rawMatch: raw,
            ),
          ],
        ),
      );
    }
  }

  for (final match in _monthYearNumericRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final int month;
    final int year;
    if (match.group(1) != null && match.group(2) != null) {
      month = int.parse(match.group(1)!);
      year = int.parse(match.group(2)!);
    } else {
      year = int.parse(match.group(3)!);
      month = int.parse(match.group(4)!);
    }
    if (month < 1 || month > 12 || year < 2000 || year > 2100) continue;
    final endIso = _endOfMonthIso(year, month);
    claim(match.start, match.end);
    results.add(
      _ExtractedDate(
        lineCue: _cueForOffset(line, match.start, inheritedCue),
        isMonthOnly: true,
        rawMatch: match.group(0)!,
        candidates: [
          OcrDateCandidate(
            isoDate: endIso,
            label:
                '$endIso (end of ${_monthShortNames[month]} $year — verify packaging)',
            rawMatch: match.group(0)!,
            note: 'Month-only label',
          ),
        ],
      ),
    );
  }

  for (final match in _monthYearShortNumericRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final cue = _cueForOffset(line, match.start, inheritedCue);
    if (cue != _LineCue.expiry) continue;
    final month = int.parse(match.group(1)!);
    final rawYear = int.parse(match.group(2)!);
    if (month < 1 || month > 12 || rawYear < 20 || rawYear > 50) continue;
    final year = 2000 + rawYear;
    final endIso = _endOfMonthIso(year, month);
    claim(match.start, match.end);
    results.add(
      _ExtractedDate(
        lineCue: cue,
        isMonthOnly: true,
        rawMatch: match.group(0)!,
        candidates: [
          OcrDateCandidate(
            isoDate: endIso,
            label:
                '$endIso (end of ${_monthShortNames[month]} $year — verify packaging)',
            rawMatch: match.group(0)!,
            note: 'Month-only label',
          ),
        ],
      ),
    );
  }

  for (final match in _monthNameYearRegex.allMatches(line)) {
    if (overlaps(match.start, match.end)) continue;
    final month = _monthMap[match.group(1)!.toLowerCase()];
    final rawYear = int.parse(match.group(2)!);
    final cue = _cueForOffset(line, match.start, inheritedCue);
    // Avoid turning arbitrary "MAR 15" strings into years unless 4-digit 20xx
    // or explicitly marked by an expiry cue on a 20..50 year suffix.
    if (rawYear < 100 &&
        (cue != _LineCue.expiry || rawYear < 20 || rawYear > 50)) {
      continue;
    }
    final year = _expandYear(rawYear);
    if (month == null || year == null) continue;
    final endIso = _endOfMonthIso(year, month);
    claim(match.start, match.end);
    results.add(
      _ExtractedDate(
        lineCue: cue,
        isMonthOnly: true,
        rawMatch: match.group(0)!,
        candidates: [
          OcrDateCandidate(
            isoDate: endIso,
            label:
                '$endIso (end of ${_monthShortNames[month]} $year — verify packaging)',
            rawMatch: match.group(0)!,
            note: 'Month-only label',
          ),
        ],
      ),
    );
  }

  return results;
}

_LineCue _cueForOffset(String line, int offset, _LineCue inheritedCue) {
  final prefix = line.substring(0, offset);
  final expiryMatches = _expiryCueRegex.allMatches(prefix).toList();
  final mfgMatches = _mfgCueRegex.allMatches(prefix).toList();
  if (expiryMatches.isEmpty && mfgMatches.isEmpty) {
    return inheritedCue;
  }
  final lastExpiry = expiryMatches.isEmpty ? -1 : expiryMatches.last.start;
  final lastMfg = mfgMatches.isEmpty ? -1 : mfgMatches.last.start;
  return lastExpiry >= lastMfg ? _LineCue.expiry : _LineCue.manufacturing;
}

int? _expandYear(int rawYear) {
  final full = rawYear < 100 ? 2000 + rawYear : rawYear;
  return full >= 2000 && full <= 2100 ? full : null;
}

String? _validIsoDate(int year, int month, int day) {
  if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final dt = DateTime(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) return null;
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

String _endOfMonthIso(int year, int month) {
  final lastDay = DateTime(year, month + 1, 0);
  return _validIsoDate(lastDay.year, lastDay.month, lastDay.day)!;
}
