# FreshKeep remaining work and recommendations

Reviewed: 2026-11-25. This is the current remaining-work list; older plan milestones describe historical status. Update this file and CHANGELOG.md as items are completed.

## Android build & device status

**Priority 1 (debug APK build, physical-phone startup, and physical-phone core/photo/notification acceptance) is complete.** Schema is now **v9** (`printed_time`, direct camera capture + lost-picker recovery, custom Android/web launcher icons, calculated storage-guidance dates, splash/first-open onboarding, redesigned dashboard & waste search/filter, optional offline Local JSON Backup, separate ML Kit OCR experiment, **food categories + category search/filter**, and **decimal quantities for `g` and `mL`**), and the full automated test suite + `flutter analyze` pass.

Release signing is now wired in `android/app/build.gradle.kts` via `android/key.properties` (ignored in `.gitignore`, falling back to debug signing when `key.properties` is absent). Creating the keystore and building the final signed release artifact remains under Priority 2.

## Priority 1: produce and test the first Android build (Completed)

- [x] Check free space on the project, Android SDK and Gradle/cache drives.
- [x] Check the installed Flutter/Android toolchain with `flutter doctor -v`.
- [x] Build a debug APK and verify startup on a physical Android phone.
- [x] Run physical-phone core, offline, photo, and notification acceptance checks.

### Physical-phone core acceptance (Completed)

- [x] Add one grocery and several groceries, including identical foods with different printed dates.
- [x] Check name reuse, quantities/units, validation, cancellation and retry behavior.
- [x] Close/reopen the app and confirm saved inventory, photos, histories and preferences remain.
- [x] Exercise Use, Discard, Correct stock and Undo; confirm stock and waste totals against a known dataset.
- [x] Confirm used-up batches retain history and can be reactivated by correction.
- [x] Check search, filters, sorting, dashboard and waste log.
- [x] Edit name/storage/date and confirm labels and reminders update correctly.
- [x] Test in airplane mode after installation: entry, saved photos, stock actions, reports and bundled guidance. External source links still need internet.
- [x] Check keyboard clearance, small screens, system navigation, large text, app resume and date changes.
- [x] Check gallery selection, picker cancellation, photo replacement/removal, unreadable images and the 5 MB limit.
- [x] Test leaving the app while the Android picker is open, including Android activity/process recreation.

### Physical-phone notification acceptance (Completed)

- [x] Grant and deny notification permission on an applicable Android version; confirm accurate feedback and retained settings.
- [x] Send the immediate test notification.
- [x] Receive a scheduled reminder while the app is closed normally.
- [x] Reboot the phone and check reminder restoration/delivery.
- [x] Deplete a batch and check cancellation; undo/correct it and check eligible reminders return.
- [x] Disable reminders and confirm cancellation; verify preference persistence.
- [x] Change timezone/time and check resynchronization on resume/reopen.
- [x] Check behavior under the intended phone's battery restrictions and a representative reminder count.

Web intentionally provides reminder settings and previews only. Browser background notifications are not an unfinished requirement in the current scope.

## Priority 2: final acceptance, evaluation and submission

- [x] Map each numbered requirement R1-R49 to an executed acceptance case in `plans/Requirement Traceability and Evaluation.md`. (Re-check R45-R49 printed-time, camera capture, launcher icon, and calculated guidance behavior on physical phone when ready.)
- [x] Run the final regression suite and analysis (`flutter analyze` clean, full test suite passing).
- [x] Set up a build-specific defect log and device timing sheet template in `plans/Requirement Traceability and Evaluation.md`.
- [ ] Time representative tasks on the phone: add food, record disposal and correct stock. Report medians and ranges.
- [ ] Confirm participant count, consent/evaluation procedures and questionnaire interpretation with the instructor; conduct user sessions and report findings separately from developer tests.
- [ ] Address usability findings and document any remaining limitations.
- [ ] Prepare final screenshots, results/write-up, code appendix and reproducible setup instructions.
- [x] Generate custom Android adaptive/legacy launcher icon and web manifest/favicon icons (`assets/icon/freshkeep_icon_master.png`). Confirm final application identity and version/build number before distribution.
- [ ] Generate the release keystore + `android/key.properties` (outside source control) and build/test the signed release artifact (`flutter build apk --release` or `flutter build appbundle --release`).
- [ ] Reconcile historical planning text and the DOCX proposal copy where required. The development plan still contains obsolete initial setup steps and an older ten-week schedule below its superseding one-month agreement.

## Implemented optional & scope-aligned enhancements (device re-check pending)

### Calculated storage-guidance dates (Implemented in M13 — R49)

- [x] Added explicit guidance-rule selection, food condition, and the rule's starting event/date confirmation (`showApplyGuidanceSheet`).
- [x] Persisted guidance inputs via v6→v7 migration; displays suggested date separately from printed date, with provenance and source citation.
- [x] Defined editing, clearing, and reminder behavior for suggestions; tested unknown anchors and unsupported combinations.

### Direct camera capture (Implemented in M13 — R47)

- [x] Added a dedicated `Take photo` action alongside gallery picking in entry and edit photo controls.
- [x] Shared 5 MB size checks, codec readability checks, safe cancellation/errors, and Android `retrieveLostData()` recovery.

### Food categories & decimal measured units (Implemented in M15 — R54–R55)

- [x] Added curated offline food categories (`FoodCategory.all`), category display on batch cards/details, editable category with audit history, and category search + filter in Inventory.
- [x] Enabled decimal quantities (up to 2 decimal places) for measured units (`g`, `mL`) using exact hundredths math while keeping `pieces` whole-number, migrated losslessly via v8→v9.

### Image-based grocery entry: separate single-item experiment (Implemented in M14 — R52–R53; device eval pending)

- [x] Start with single packaged-item capture supporting multi-side scans (e.g. front label name + back panel date).
- [x] Separate food-name drafting from printed-date OCR; ignore manufacturing dates (`MFG`/`MFD`/`PROD`/`PKD`), keep missing/ambiguous dates unknown until confirmed, and never infer dates from appearance.
- [x] Hand off all OCR results strictly as editable drafts into `AddGroceriesScreen`, keeping manual entry intact on failure/cancellation and isolating ML Kit behind a web/desktop Sample Mode stub.
- [ ] Evaluate on held-out packaged items on the physical Android phone, logging raw extraction errors, user corrections, and task timing in `plans/Requirement Traceability and Evaluation.md`.
- Note: Packaging-label OCR was chosen over full receipt scanning because grocery receipts omit expiration dates. Future stretch (deferred): multi-item receipt capture & in-app update checker.

## Additional recommendations, not current completion requirements

1. **Keep web for fast iteration and Android for platform checks.** Continue implementing one feature at a time, then review it. Browser and phone databases are separate; web records do not automatically transfer to the phone.
2. **Protect the one-month deadline.** Prioritize Android build, notification checks, real-phone usability and evaluation before optional additions.
3. **Git repository is active on GitHub (`https://github.com/AiruxPH/FreshKeep`).** Keep `CHANGELOG.md` updated as offline memory alongside clean Git commits. Never commit keys (`android/key.properties`, `*.jks`, `*.keystore`) or personal evaluation data.
4. **Local JSON export/import is implemented (`More → Backup & restore`).** Supports offline `.json` export/import (Merge or Replace mode with optional photos) to safeguard device-local records during phone testing and user sessions without introducing cloud sync.
5. **Review photo storage under a realistic dataset.** The current per-photo cap is 5 MB and original bytes are stored locally. Measure startup, scrolling and storage use before deciding whether thumbnails, compression or lazy image loading are needed.
6. **Recheck guidance sources before submission.** The FoodKeeper references use a documented historical 2018 chart. Record any source/catalog updates and their implications rather than silently changing durations.

Cloud sync, shared-household synchronization, appearance-based spoilage detection, exact remaining-life prediction and automatic measurement of discarded food remain excluded from the agreed scope. They are not missing core deliverables.

## Suggested order

1. ~~Successful debug APK build and physical-phone startup.~~ (Completed)
2. ~~Core offline, photo and notification acceptance checks; fix defects.~~ (Completed for R1–R44)
3. Generate release keystore (`android/key.properties` outside git) and build the smaller `--split-per-abi` release APK (`app-arm64-v8a-release.apk`).
4. Re-check `D-002` and `R45–R55` on the physical Android phone and record the 5-trial task timing sheet + held-out OCR sheet.
5. Run quick Google Forms user evaluation (`Freshkeep_quest (1).docx`), polish any findings, and finalize the manuscript/submission materials.

Sources of project status: `Core Feature Checklist.md`, `FreshKeep Development Plan.md`, `Reminder Behavior.md`, README.md, CHANGELOG.md and the current Android/photo-picker source. Checklist boxes here reflect outstanding work, not a claim that no related implementation exists.
