/// Adds [days] to an ISO calendar date (`YYYY-MM-DD`) using local calendar
/// arithmetic rather than fixed 24-hour durations.
String addCalendarDays(String isoDate, int days) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null || _formatIsoDate(parsed) != isoDate) {
    throw ArgumentError('Enter a valid date in YYYY-MM-DD format.');
  }
  return _formatIsoDate(DateTime(parsed.year, parsed.month, parsed.day + days));
}

String _formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
