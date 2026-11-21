enum DateStatus { later, soon, hoursLeft, today, past, unknown }

/// Compare calendar days, not elapsed 24-hour periods (which vary across DST).
/// When [time] is provided ("HH:mm"), the status is refined within the same
/// calendar day: if the datetime is in the future but fewer than 24 h away,
/// [DateStatus.hoursLeft] is returned instead of [DateStatus.today].
DateStatus dateStatus(String? date, DateTime now, {String? time}) {
  if (date == null) return DateStatus.unknown;
  final parsed = DateTime.parse(date);
  final local = now.toLocal();
  final dayDiff = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (dayDiff < 0) return DateStatus.past;
  if (dayDiff > 3) return DateStatus.later;
  if (dayDiff > 0) return DateStatus.soon; // 1–3 days away (calendar)

  // dayDiff == 0 → same calendar day
  if (time != null) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        final expiresAt = DateTime(parsed.year, parsed.month, parsed.day, h, m);
        if (expiresAt.isAfter(local)) return DateStatus.hoursLeft;
        return DateStatus.past; // time has already passed today
      }
    }
  }
  return DateStatus.today;
}

/// Returns a human-readable "X h Y m left" string given a date, time and now.
/// Returns null if the datetime is not in the future or time is malformed.
String? hoursLeftLabel(String date, String time, DateTime now) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final parsed = DateTime.parse(date);
  final expiresAt = DateTime(parsed.year, parsed.month, parsed.day, h, m);
  final remaining = expiresAt.difference(now.toLocal());
  if (remaining.isNegative || remaining == Duration.zero) return null;
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours == 0) return '${minutes}m left';
  if (minutes == 0) return '${hours}h left';
  return '${hours}h ${minutes}m left';
}

extension DateStatusLabel on DateStatus {
  String get label => switch (this) {
    DateStatus.later => 'More than 3 days away',
    DateStatus.soon => 'In 1–3 days',
    DateStatus.hoursLeft => 'Expires today',
    DateStatus.today => 'Today',
    DateStatus.past => 'Past date',
    DateStatus.unknown => 'Date unknown',
  };
}
