# FreshKeep

Offline grocery inventory, built with Flutter. Repository: <https://github.com/AiruxPH/FreshKeep>. Implemented: multi-row manual entry with previous-name suggestions, persistent inventory with optional display photos (gallery & camera capture), stock actions, batch history, calendar-based date labels & printed-time countdowns, cited & optional calculated storage guidance, dashboard, waste log search/filter, reminder settings/device notifications, offline **Local JSON Backup (export/import)**, and an optional on-device **ML Kit OCR Experiment** for drafting single packaged items into manual review.

## Run on web

```powershell
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173
```

Use the same browser profile and address each time to retain test inventory. Browser and Android data are separate. Clearing site data or using private browsing can remove saved browser inventory.

In this development environment the Flutter batch launcher stalled, while directly invoking its tool snapshot worked. If needed, run `./scripts/run-web.ps1` in PowerShell and open http://127.0.0.1:5173. The script serves the app without opening a window. Press `r` for hot reload, `R` for hot restart, and `q` to stop.

## Using FreshKeep

Use the labeled **Inventory**, **Dashboard**, **Waste** and **More** navigation. Phones show bottom navigation; wide screens use a sidebar. Reminders and storage guidance live under More. Inventory refreshes when you return from another tab.

Inventory opens with food **In stock**, ordered by soonest printed date. Past dates come first and unknown dates last. **All** and **Used up** keep older history accessible. Search by name, or expand **Filters and sort** for storage/date/stock criteria and alternate sorting. **Reset filters** returns to the normal in-stock/soonest-date view; **Show all batches** clears criteria and includes used-up records. Matching/total counts explain what is visible. Criteria stay applied when returning from batch details, date filters update with the local day, and view settings reset on restart. Browsing does not change records.

Use the persistent **Add groceries** button for full-screen entry. Enter each food name and positive whole-number quantity/unit, then expand **Storage & date** to change its location or add a printed date. The collapsed summary keeps storage and unknown/entered dates visible. **Add another food** adds an independent entry and focuses its name. The fixed **Save groceries** area stays above the keyboard. Each entry remains a separate batch, including identical foods with different dates. All entries validate and commit together; failure saves none and retains drafts. Cancel discards unsaved entries.

Type in **Food name** to search previous names (up to eight matches, ignoring case). Selecting a suggestion reuses only the name. Quantity, unit, storage and printed date remain independent for every new row. Previous names include depleted batches; unsaved/cancelled names are never added to suggestions. If suggestions cannot load, manual entry remains available.

Tap a food card for details, or choose **Use** / **Discard** directly on the card. Quantity entry uses a short sheet on phones and a dialog on wider screens. Quick actions offer **Undo** in the confirmation bar; it reverses that exact action. In details, **Correct stock** sets the actual amount left rather than a delta, and never counts as waste. Optional disposal reasons default to Unspecified. Expand **Batch history** for past actions and **Undo entry**. Used-up batches keep their history and can be reactivated by correction. Undo cannot produce invalid stock. Quantities retain their original unit.

In batch details, use the **Edit batch details** pencil icon to correct the name, storage location or printed date. Clear the date to mark it unknown. Starting quantity and unit stay fixed; use Correct stock for remaining amounts. Detail changes are recorded separately under Details history and do not change stock/waste events. Saving refreshes date labels and reminder plans; cancelling saves nothing. If another edit changed the details while your form was open, close and reopen it before retrying. Reports and name suggestions use the corrected food name.

Use **Add photo (optional)** on a grocery entry to choose an image from your device. Each batch keeps its own photo, shown in inventory and batch details. Open **Edit batch details** to add, change or remove it, then **Save changes**; Cancel keeps the stored photo. Photos are optional, up to 5 MB each, and stored in the local database rather than temporary file paths. Unreadable images are rejected; JPG, PNG and WebP are good choices. Photos only provide a visual reference: names, quantities and printed dates are still entered manually. Clearing site/app data removes photos along with inventory. Photo changes appear in Details history as added/changed/removed; old image files are not retained for undo.

Open **More → Reminders** to choose a daily time, a one- or three-day lead window, and enable/disable reminders. Save to persist changes; resync rechecks saved settings. Upcoming alerts preview future times for active dated batches, including the printed-date day. Unknown dates, past dates and used-up batches are excluded. Web saves settings and shows a preview only; it does not deliver background notifications. Expand How reminders work for additional details. Android has permission handling, inexact scheduling and a test-notification button. Phone delivery/reboot validation remains pending. See `plans/Reminder Behavior.md` for behavior and checks.

Open **More → Storage guidance**, or the guidance link in food details. The offline catalog covers 16 foods with 17 condition-specific references. Search/filter candidates and expand **Source details** for page/section, review date, URL and citation copying. Conditions, durations and source attribution remain visible. Batch context prefills food/storage without assigning a rule. Unsupported combinations receive no estimate; calendar suggestions remain unavailable until rule-specific starting events/dates are recorded. Viewing guidance never changes a printed date, stock or waste. See `plans/Guidance Sources.md` for provenance and the historical FoodKeeper source limitation.

**Dashboard** shows total/in-stock/used-up batch counts, date-attention breakdown, top waste reasons, unreversed disposals and quantities separately by pieces, grams and millilitres. **Waste** lists unreversed disposals newest first, with search, unit/reason/date filters, sort modes, and batch-history access. Returning from history refreshes the report. Reports cover all recorded time and can be refreshed; they summarize tracked records rather than automatically measured waste.

Open **More → Backup & restore** to export your inventory, display photos, stock/detail audit histories, guidance links, reminder settings, and preferences to an offline JSON file (or clipboard when under 2 MB), or import an exported JSON file/snippet with a pre-commit count preview and choice of **Merge** or **Replace**. Backups stay device-local with zero cloud sync.

Open **More → Label scanner (OCR experiment)** or tap **Scan label (beta)** inside **Add groceries** to capture one or more sides of a single packaged grocery item using on-device ML Kit Latin text recognition (Android/iOS). Extracted food names and visible printed dates (ignoring manufacturing dates and flagging ambiguous `DD/MM` vs `MM/DD` or month-only dates) always arrive as editable drafts for review and never save automatically or guess expiration dates from appearance. On web and desktop builds, an honest **Sample mode** lets you test multi-side draft review with preset sample label text without claiming real OCR.

## Verify

Inventory and batch details show **More than 3 days away**, **In 1–3 days**, **Today**, **Past date**, or **Date unknown**. These compare printed dates with the device's local calendar date, and do not claim freshness. Labels refresh at midnight, on app resume, and within a minute of a foreground clock/date change. Background browsers may delay timers until resumed. Passing a date never creates a disposal or changes stock. Tap/hover a label for help.

```powershell
flutter analyze
flutter test
```

Tests cover domain validation, date thresholds, leap/year boundaries, midnight/resume refresh, SQL persistence across close/reopen, multi-row atomic saves, row removal/cancellation, searched-name reuse, failed-save retry, in-flight duplicate protection, stock actions, reporting, waste separation, undo, competing withdrawals, stale forms and v1-to-v2 migration. Android execution has not yet been verified.

UI regression checks additionally cover phone navigation, food visibility, exact-event quick Undo, keyboard clearance for Save, refreshing after tab changes, 2× phone text and wide-screen navigation. Keyboard checks use simulated view insets; physical Android keyboard and notification delivery checks remain pending.

## Storage and versions

Flutter 3.47.2, Dart 3.13.2, Drift 2.35.3 and drift_flutter 0.3.1 power local persistence. Reminders use `flutter_local_notifications: 22.3.3`, `timezone: 0.11.2` and `flutter_timezone: 5.1.1`. Media/file helpers and optional extras use `image_picker: 1.2.4`, `file_picker: 13.4.0` and `google_mlkit_text_recognition: 1.0.3` (kept isolated behind a web-safe sample stub). Resolved dependency versions are recorded in `pubspec.lock`. SQL schema is now **v8** (`batches` with `printed_time` & confirmed guidance columns, `batch_photos`, append-only `events` & `batch_edits`, `reminder_settings`, and `app_preferences` for first-open onboarding state). Future changes preserve existing records via migrations rather than clearing user data. Android requires API 24+ (`minSdk = 24`, `compileSdk = 36`, with R8 `keep.xml` and `proguard-rules.pro` rules for release APKs).

`web/drift_worker.js` and `web/sqlite3.wasm` are official artifacts from the matching [Drift 2.35.3 release](https://github.com/simolus3/drift/releases/tag/drift-2.35.3). Update them together when upgrading Drift. See [web database setup](https://drift.simonbinder.eu/platforms/web/).

Project decisions and changes are recorded in `plans/` and `CHANGELOG.md`. See [Remaining work and recommendations](plans/Remaining%20Work%20and%20Recommendations.md) for Android build readiness, outstanding verification, scope decisions and suggested next steps.
