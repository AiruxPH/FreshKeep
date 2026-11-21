# FreshKeep — Requirement Traceability, Defect Log, Timing & Release Prep

Updated: 2026-11-21 · App version: `1.0.0+1` · Application ID: `com.freshkeep.freshkeep` · Schema: v6  
Automated verification: `flutter analyze` (0 issues), `flutter test -j 1` (**76/76 passing**).  
Note: Automated/browser checks and physical-device checks are recorded in separate columns; participant/user-study results must be reported separately from developer tests.

---

## 1. Requirement Traceability Matrix (R1–R46)

| Req ID | Milestone | Requirement Summary | Automated Coverage | Automated Status (v1.0.0+1) | Physical Device Status | Build # |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | M1 | Save food name, integer quantity, unit, storage, optional printed date as separate batch | `test/batch_test.dart`, `test/inventory_test.dart` | Pass | Verified | 1.0.0+1 |
| R2 | M1 | Reject empty names, invalid quantities, unsupported units/locations, invalid calendar dates | `test/batch_test.dart`, `test/inventory_test.dart` | Pass | Verified | 1.0.0+1 |
| R3 | M1 | Display saved batches with quantities, storage, printed-date/unknown labels | `test/inventory_test.dart`, `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R4 | M1 | Retain saved batches across DB reopen and app/browser restart | `test/inventory_test.dart` | Pass | Verified | 1.0.0+1 |
| R5 | M1 | Cancel entry without saving; disable save while submission in progress | `test/inventory_test.dart`, `test/multi_entry_test.dart` | Pass | Verified | 1.0.0+1 |
| R6 | M1 | Show recoverable load/save errors without clearing data | `test/multi_entry_test.dart`, `test/report_test.dart` | Pass | Verified | 1.0.0+1 |
| R7 | M2 | Consume/dispose positive integer quantities ≤ available stock atomically | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R8 | M2 | Correct to actual remaining quantity (0 allowed); signed delta; exclude from waste | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R9 | M2 | Preserve event history (time, delta, optional reason); disposal defaults to Unspecified | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R10 | M2 | Derive depletion from stock; preserve depleted batches; allow reactivation via correction | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R11 | M2 | Undo mistaken action via linked append-only reversal; exclude reversed disposal from waste | `test/stock_actions_test.dart`, `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R12 | M2 | Upgrade v1 inventory without data loss; persist new events through reopen | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R13 | M2 | Refresh inventory after managing batch; reject stale submissions; disable save while busy | `test/stock_actions_test.dart` | Pass | Verified | 1.0.0+1 |
| R14 | M3 | Printed-date provenance + 5 calendar status labels with text/icons; no freshness claims | `test/date_status_test.dart` | Pass | Verified | 1.0.0+1 |
| R15 | M3 | Shared local calendar clock; refresh at midnight, resume, and foreground clock changes | `test/date_status_test.dart` | Pass | Verified | 1.0.0+1 |
| R16 | M3 | Date status calculations never change stock, create events, or record waste | `test/date_status_test.dart` | Pass | Verified | 1.0.0+1 |
| R17 | M4 | Dashboard counts: total, active, depleted batches and unreversed disposal events | `test/report_test.dart` | Pass | Verified | 1.0.0+1 |
| R18 | M4 | Keep remaining/disposed quantities separate by unit (pieces/g/mL) | `test/report_test.dart` | Pass | Verified | 1.0.0+1 |
| R19 | M4 | List unreversed disposals newest first with details & history link; exclude non-waste | `test/report_test.dart` | Pass | Verified | 1.0.0+1 |
| R20 | M4 | Consistent report snapshot; refresh after history; empty/retry states without data loss | `test/report_test.dart` | Pass | Verified | 1.0.0+1 |
| R21 | M5 | Multi-row grocery entry with independent fields saved as distinct batches | `test/multi_entry_test.dart` | Pass | Verified | 1.0.0+1 |
| R22 | M5 | Validate all rows; single-transaction commit; rollback on failure retaining drafts | `test/multi_entry_test.dart` | Pass | Verified | 1.0.0+1 |
| R23 | M5 | Case-insensitive deduplicated past-name reuse (name only, includes depleted) | `test/multi_entry_test.dart` | Pass | Verified | 1.0.0+1 |
| R24 | M5 | Disable editing/duplicate submit while saving; retain unaffected rows on removal | `test/multi_entry_test.dart` | Pass | Verified | 1.0.0+1 |
| R25 | M6 | Bundled guidance catalog (16 foods, 17 references) with condition, storage, citation | `test/guidance_test.dart` | Pass | Verified | 1.0.0+1 |
| R26 | M6 | Search/filter reference candidates; unsupported combinations show no estimate | `test/guidance_test.dart` | Pass | Verified | 1.0.0+1 |
| R27 | M6 | Keep guidance separate from printed dates/stock; selectable offline citations | `test/guidance_test.dart` | Pass | Verified | 1.0.0+1 |
| R28 | M7 | Persist opt-in reminder settings, daily time, and 1-/3-day lead window across restart | `test/reminder_test.dart` | Pass | Verified | 1.0.0+1 |
| R29 | M7 | Preview future daily alerts through printed-date day; exclude unknown/past/depleted | `test/reminder_test.dart` | Pass | Verified | 1.0.0+1 |
| R30 | M7 | Resync reminders on stock changes, startup/resume, save; cancel on depletion/disable | `test/reminder_test.dart` | Pass | Verified | 1.0.0+1 |
| R31 | M7 | Android permission handling, inexact scheduling, boot receiver, test alert, web notice | `test/reminder_test.dart` | Pass | Verified | 1.0.0+1 |
| R32 | M8 | Edit saved name, storage, printed date while preserving starting qty, unit, stock, history | `test/batch_edit_test.dart` | Pass | Verified | 1.0.0+1 |
| R33 | M8 | Atomic update with append-only before/after audit; reject stale forms; skip no-ops | `test/batch_edit_test.dart` | Pass | Verified | 1.0.0+1 |
| R34 | M8 | Refresh labels/inventory and resync reminders after edit; updated names in reports/reuse | `test/batch_edit_test.dart` | Pass | Verified | 1.0.0+1 |
| R35 | M9 | Combined name search, storage, date-status, active/depleted filters + counts/no-match | `test/inventory_query_test.dart` | Pass | Verified | 1.0.0+1 |
| R36 | M9 | Sort newest-first, name, or soonest date (past first, unknown last) without mutating data | `test/inventory_query_test.dart` | Pass | Verified | 1.0.0+1 |
| R37 | M9 | Retain view criteria returning from details; refresh at calendar boundaries; reset action | `test/inventory_query_test.dart` | Pass | Verified | 1.0.0+1 |
| R38 | M10 | Labeled mobile/desktop navigation, More tools, refresh inventory on tab return | `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R39 | M10 | Compact in-stock view, soonest-date order, direct Use/Discard, exact-event quick Undo | `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R40 | M10 | Full-screen multi-entry with keyboard-aware persistent Save and all-or-nothing commit | `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R41 | M10 | Progressive disclosure of audits/sources/help, responsive styling, singular quantities | `test/ui_redesign_test.dart` | Pass | Verified | 1.0.0+1 |
| R42 | M11 | Optional display photo per batch; thumbnail in inventory, larger image in details | `test/food_photo_test.dart` | Pass | Verified | 1.0.0+1 |
| R43 | M11 | Add/change/remove photo via explicit save; 5 MB limit; stored locally in SQLite | `test/food_photo_test.dart` | Pass | Verified | 1.0.0+1 |
| R44 | M11 | Non-destructive v4→v5 migration, atomic photo/metadata save, stale rejection, audit entry | `test/food_photo_test.dart` | Pass | Verified | 1.0.0+1 |
| R45 | M12 | Optional printed expiry time (`HH:mm`, date-gated), live `Xh Ym left` countdown & `hoursLeft` status | `test/batch_test.dart`, `test/date_status_test.dart` | Pass | Pending re-check on device | 1.0.0+1 |
| R46 | M12 | Non-destructive v5→v6 migration (`printed_time`); expiry-day reminders fire at `printedTime` | `test/reminder_test.dart` | Pass | Pending re-check on device | 1.0.0+1 |

**Automated Pass Rate:** 46 / 46 requirements covered · 76 / 76 automated tests passing (100%).

---

## 2. Build-Specific Defect Log

Record every defect observed during device testing or user evaluation with its build number.

| Defect ID | Build # | Date | Severity | Area | Summary & Reproduction Steps | Status | Retest Build & Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D-001 | 1.0.0+1 | 2026-11-21 | Low | Migration Tests | Legacy v1–v4 test fixtures failed with `duplicate column name: printed_time` after schema v6 added `printed_time` to `onCreate`. Fixed by dropping `printed_time` in legacy fixtures to match old schemas. | Closed | 1.0.0+1 · 76/76 Pass |
| _D-002_ | _1.0.0+1_ | _YYYY-MM-DD_ | _High / Med / Low_ | _e.g. Notifications_ | _Describe steps to reproduce_ | _Open / Closed_ | _Build # · Pass/Fail_ |

---

## 3. Physical-Device Task Timing Sheet

Measure on the target physical Android phone (record seconds to 1 decimal place). Report **median** and **range (min–max)** in the Results chapter.

| Representative Task | Trial 1 (s) | Trial 2 (s) | Trial 3 (s) | Trial 4 (s) | Trial 5 (s) | Median (s) | Range (s) | Notes / Device Model |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Add food (1 batch, name + qty + storage + printed date) | | | | | | | | |
| Record disposal (open/quick Discard, enter qty + reason) | | | | | | | | |
| Correct stock (open batch → Correct stock → save) | | | | | | | | |

---

## 4. User Evaluation & Questionnaire Summary (Participant Results)

Keep participant findings separate from developer tests.

- **Target participant count (confirm with instructor):** _TBD_
- **Device(s) & Android version(s) tested:** _TBD (state single-device limits plainly if only one phone is used)_
- **Consent / ethics step confirmed:** [ ] Yes
- **ISO attribute mapping & score bands confirmed with instructor:** [ ] Yes

| Participant ID | Completed Core Tasks? | Issues / Usability Observations | Questionnaire Score |
| --- | --- | --- | --- |
| P1 | | | |
| P2 | | | |
| P3 | | | |

---

## 5. Android Release Signing & Distribution Steps

`android/app/build.gradle.kts` is configured to read `android/key.properties` when present (and safely falls back to debug signing otherwise). `android/key.properties`, `*.jks`, and `*.keystore` are excluded in `.gitignore`.

### Step A — Generate an upload/release keystore (store outside the repo, e.g. `%USERPROFILE%\freshkeep-keystore\`)
```powershell
mkdir "$env:USERPROFILE\freshkeep-keystore" -Force
keytool -genkey -v -keystore "$env:USERPROFILE\freshkeep-keystore\freshkeep-release.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 -alias freshkeep
```

### Step B — Create `android/key.properties` (never commit this file)
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=freshkeep
storeFile=C:/Users/CLienT/freshkeep-keystore/freshkeep-release.jks
```

### Step C — Build and verify the signed release artifact
```powershell
flutter build apk --release
# or for Play Store distribution:
flutter build appbundle --release
```
Expected outputs:
- Release APK: `build/app/outputs/flutter-apk/app-release.apk`
- Release AAB: `build/app/outputs/bundle/release/app-release.aab`
