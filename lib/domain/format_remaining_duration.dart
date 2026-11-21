/// Formats the actual remaining duration between [now] and [date] (and
/// optional [time] in `HH:mm`), scaling cleanly across weeks, days, hours,
/// minutes, and seconds.
String formatRemainingDuration(String? date, DateTime now, {String? time}) {
  if (date == null) return 'Date unknown';
  final parsed = DateTime.parse(date);
  final local = now.toLocal();

  if (time != null) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        final expiresAt = DateTime(parsed.year, parsed.month, parsed.day, h, m);
        final remaining = expiresAt.difference(local);
        if (remaining <= Duration.zero) return 'Past date';
        if (remaining.inDays >= 7) {
          return _formatWeeksAndDays(remaining.inDays);
        }
        if (remaining.inDays >= 1) {
          final days = remaining.inDays;
          return '$days ${_plural(days, 'day')} left';
        }
        if (remaining.inHours >= 1) {
          final hours = remaining.inHours;
          final mins = remaining.inMinutes % 60;
          if (mins == 0) return '$hours ${_plural(hours, 'hour')} left';
          return '$hours ${_plural(hours, 'hour')} $mins ${_plural(mins, 'min')} left';
        }
        if (remaining.inMinutes >= 1) {
          final mins = remaining.inMinutes;
          return '$mins ${_plural(mins, 'minute')} left';
        }
        final secs = remaining.inSeconds > 0 ? remaining.inSeconds : 1;
        return '$secs ${_plural(secs, 'second')} left';
      }
    }
  }

  final dayDiff = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (dayDiff < 0) return 'Past date';
  if (dayDiff == 0) return 'Today';
  if (dayDiff < 7) return '$dayDiff ${_plural(dayDiff, 'day')} left';
  return _formatWeeksAndDays(dayDiff);
}

String _formatWeeksAndDays(int totalDays) {
  final weeks = totalDays ~/ 7;
  final remDays = totalDays % 7;
  if (remDays == 0) return '$weeks ${_plural(weeks, 'week')} left';
  return '$weeks ${_plural(weeks, 'week')} $remDays ${_plural(remDays, 'day')} left';
}

String _plural(int value, String singular) =>
    value == 1 ? singular : '${singular}s';
