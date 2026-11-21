# Reminder behavior and validation

Implemented 2026-11-01. Image processing remains outside this workstream.

## Saved behavior

- Reminders default off, with a local 09:00 time and a three-day lead window. The user can choose one or three lead days, change the time, enable/disable, and explicitly save.
- For each active batch with a printed date, generate one future alert per day from the lead-window start through the printed-date day. Already elapsed times are skipped. Unknown/past dates and depleted batches receive no scheduled alerts. The preview is shown even when delivery is off and is labeled accordingly.
- Each planned alert has a stable batch/day ID. Date arithmetic uses local calendar construction across month/year/leap boundaries, rather than subtracting 24-hour durations.
- Android replaces FreshKeep's pending notifications after committed inventory changes, startup, resume, saving settings or manual resync. Depletion removes alerts and undo/correction can restore them. Notifications refer to the recorded printed date and do not claim freshness or create stock/waste events.
- Settings persist in schema v3's `reminder_settings` singleton table. Migrations retain inventory and event history. Browser/Android settings remain separate local data stores.

## Platform behavior

- Web: settings and upcoming-time previews only. No browser notification permission is requested, no background browser delivery is promised, and no native test button is shown.
- Android: `flutter_local_notifications` 22.3.3, `timezone` 0.11.2 and `flutter_timezone` 5.1.1. Inexact allow-while-idle one-off alarms; no exact-alarm permission. Notification permission is requested only after explicit enable/save or a test-button tap. Permission denial is reported rather than presented as delivery success.
- Native setup includes a monochrome notification drawable, desugaring, notification/boot permissions and scheduled/boot receivers. The plugin requires Android API 24+; compile SDK is at least 36. Timezone is read from the device and IANA data is bundled. Refresh after a timezone change on reopen/resume/resync; changing zones while the app remains closed has not been validated.
- A denied permission or platform error does not undo inventory or preference saves. The UI reports blocked/failed synchronization and provides resync. A partial native scheduling failure clears the partial plan.
- Existing scheduled alarms are restored by the plugin's boot receiver; actual reboot delivery still needs device testing. Battery settings may delay delivery. Large alarm counts and manufacturer restrictions need testing with the intended dataset/device.

## Validation and limits

Seven new tests cover timing/IDs, exclusions, calendar boundaries, v2-to-v3 migration and preference reopen, automatic depletion/undo/disable synchronization, platform-error retry, and clearly labeled web settings/preview. Existing v1 migration fixture was updated to represent the old schema accurately after v3 was introduced.

The Android debug build attempt reached native dependency/Java compilation but failed because the disk ran out of space. It did not produce a verified APK. The disk failure also interrupted an initial full regression run. Only this attempt's generated `build/app` and exact failed-test temporary directory were removed after checking resolved paths and stopping the identified processes; about 2 GB was recovered. No user data, browser storage, source or global caches were deleted. Final verification results are recorded in CHANGELOG.md.

Before claiming Android completion, execute on a real phone: permission grant/denial, immediate test notification, scheduled delivery with app closed, phone reboot, depletion cancellation, undo restoration, settings persistence and timezone changes. These checks are not established by fake-scheduler tests or a browser preview.

## Technical sources

- [Plugin setup and scheduling](https://pub.dev/packages/flutter_local_notifications), checked against the installed 22.3.3 API and Android build configuration.
- [Android alarm guidance](https://developer.android.com/develop/background-work/services/alarms).
- [Device timezone plugin](https://pub.dev/packages/flutter_timezone).
