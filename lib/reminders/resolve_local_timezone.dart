import 'package:timezone/timezone.dart' as tz;

/// Resolves an IANA [identifier] to a [tz.Location], falling back cleanly to a
/// matching local UTC offset (or [tz.UTC]) when a device reports a non-standard
/// or legacy zone name.
tz.Location resolveLocalTimezone(String identifier, {int? fallbackOffsetMs}) {
  try {
    return tz.getLocation(identifier);
  } catch (_) {
    final targetOffsetMs =
        fallbackOffsetMs ?? DateTime.now().timeZoneOffset.inMilliseconds;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset.inMilliseconds == targetOffsetMs) {
        return location;
      }
    }
    return tz.UTC;
  }
}
