# FreshKeep remaining work and recommendations

Reviewed: 2026-11-01. This is the current remaining-work list; older plan milestones describe historical status. Update this file and CHANGELOG.md as items are completed.

## Is it ready for an Android build?

**Ready to attempt a debug APK build for testing. Android build success and device readiness are not yet verified.** No additional recognition feature or calculated guidance date is needed before attempting this build.

The project has an Android target with application ID `com.freshkeep.freshkeep`, minimum API 24, compile SDK at least 36, Java/Kotlin JVM target 17, core-library desugaring, and notification permissions/receivers. Native SQLite, photo-picker and notification dependencies are included. This configuration review does not establish that the full native toolchain compiles successfully.

The earlier Android build ran out of disk space during native compilation. No verified APK was produced. Available disk space must be checked again before retrying. Browser and automated tests support the core behavior, but do not establish Android plugin behavior or notification delivery.

Release builds currently use the debug signing key. That is acceptable for early testing, but a proper release-signing setup is still needed before final distribution. Android needs API 24 or newer (Android 7.0+).

## Priority 1: produce and test the first Android build

- [ ] Check free space on the project, Android SDK and Gradle/cache drives. As a practical buffer, aim for at least 10 GB free before retrying; this is a recommendation, not a guaranteed build-space requirement. Do not clear personal data or global caches indiscriminately.
- [ ] Check the installed Flutter/Android toolchain with `flutter doctor -v`. Resolve reported Android SDK, Java or license issues if any; do not assume these are currently missing.
- [ ] Build a debug APK and record the command, outcome, version and any errors.
- [ ] Install it on an available physical Android phone and confirm startup.
- [ ] Run the core acceptance checks below and fix observed failures before describing Android as complete.

Typical commands from the project root:

```powershell
flutter doctor -v
flutter pub get
flutter build apk --debug
flutter devices
flutter run -d <device-id>
```

The expected APK location after a successful build is `build/app/outputs/flutter-apk/app-debug.apk`. In this workspace the Flutter batch launcher previously stalled; use the installed tool snapshot if that recurs, as documented in the existing development notes. These commands are instructions; no new build was executed during this documentation review.

### Physical-phone core acceptance

- [ ] Add one grocery and several groceries, including identical foods with different printed dates.
- [ ] Check name reuse, quantities/units, validation, cancellation and retry behavior.
- [ ] Close/reopen the app and confirm saved inventory, photos, histories and preferences remain.
- [ ] Exercise Use, Discard, Correct stock and Undo; confirm stock and waste totals against a known dataset.
- [ ] Confirm used-up batches retain history and can be reactivated by correction.
- [ ] Check search, filters, sorting, dashboard and waste log.
- [ ] Edit name/storage/date and confirm labels and reminders update correctly.
- [ ] Test in airplane mode after installation: entry, saved photos, stock actions, reports and bundled guidance. External source links still need internet.
- [ ] Check keyboard clearance, small screens, system navigation, large text, app resume and date changes.
- [ ] Check gallery selection, picker cancellation, photo replacement/removal, unreadable images and the 5 MB limit.
- [ ] Test leaving the app while the Android picker is open, including Android activity/process recreation. Implement lost-picker-result recovery or explicit recoverable behavior where needed; current code does not call `retrieveLostData`.

### Physical-phone notification acceptance

Scheduling and permission-handling code already exists. The following are verification tasks and may reveal fixes:

- [ ] Grant and deny notification permission on an applicable Android version; confirm accurate feedback and retained settings.
- [ ] Send the immediate test notification.
- [ ] Receive a scheduled reminder while the app is closed normally. Record force-stop behavior separately; it is not equivalent to closing the app.
- [ ] Reboot the phone and check reminder restoration/delivery.
- [ ] Deplete a batch and check cancellation; undo/correct it and check eligible reminders return.
- [ ] Disable reminders and confirm cancellation; verify preference persistence.
- [ ] Change timezone/time and check resynchronization on resume/reopen.
- [ ] Check behavior under the intended phone's battery restrictions and a representative reminder count. Record delays and limitations.

Web intentionally provides reminder settings and previews only. Browser background notifications are not an unfinished requirement in the current scope.

## Priority 2: final acceptance, evaluation and submission

- [ ] Map each numbered requirement R1-R44 to an executed acceptance case, expected result, actual result and build number. Existing automated tests and browser checks can support this record; do not present them as physical-device or participant results.
- [ ] Run the final regression suite and analysis after Android fixes. Preserve existing database migrations and verify upgrades rather than clearing saved records to make tests pass.
- [ ] Keep a build-specific defect log with reproduction steps, severity, status and retest results.
- [ ] Time representative tasks on the phone: add food, record disposal and correct stock. Report medians and ranges.
- [ ] Confirm participant count, consent/evaluation procedures and questionnaire interpretation with the instructor; conduct user sessions and report findings separately from developer tests.
- [ ] Address usability findings and document any remaining limitations.
- [ ] Prepare final screenshots, results/write-up, code appendix and reproducible setup instructions.
- [ ] Confirm final application identity, launcher icon, version/build number and distribution method.
- [ ] Configure release signing and keep signing secrets outside source control before distributing a final release. Produce and test the final artifact appropriate to the agreed distribution method.
- [ ] Reconcile historical planning text and the DOCX proposal copy where required. The development plan still contains obsolete initial setup steps and an older ten-week schedule below its superseding one-month agreement.

## Unimplemented features requiring a scope decision

### Calculated storage-guidance dates

The offline catalog already provides 16 foods and 17 condition-specific references. It currently displays references without assigning a calculated date.

- [ ] If calculated suggestions are required, add explicit guidance-rule selection, food condition and the rule's starting event/date.
- [ ] Persist those inputs with a migration; show a suggested date separately from a printed date, with provenance and source citation.
- [ ] Define editing, clearing and reminder behavior for suggestions; test unknown anchors and unsupported combinations.

Recommendation: confirm this requirement before implementing it. The reference-only milestone is complete. Do not calculate dates from an assumed purchase/opening/storage date.

### Image-based grocery entry: separate workstream

Display photos are implemented. Food recognition and printed-date extraction are not implemented and remain separate from core Android readiness.

- [ ] Decide single-item versus batch capture, target foods and the expected input photos with the image-processing workstream.
- [ ] Prototype food/product-name recognition and printed-date OCR separately. Names and dates may require different photos.
- [ ] Define the handoff into editable grocery drafts, including cancellation, uncertainty and failure behavior. Keep manual entry available.
- [ ] For multi-item capture, test matching each recognized item to the correct visible date; do not assume proximity is reliable.
- [ ] Evaluate held-out examples, extraction errors, user corrections and task time.

Recommendation: start with a single packaged item and a review screen. Missing/unreadable dates stay unknown; appearance must not supply an expiration date. Recognition integration should follow a stable Android core build.

### Direct camera capture: optional convenience

- [ ] Add a dedicated Take photo action if needed. The current implemented picker requests gallery selection; the app does not provide its own camera capture action.
- [ ] Test camera cancellation, device-specific behavior and interrupted capture if introduced.

Recommendation: gallery selection is sufficient for the first Android test. Camera capture alone does not require food recognition.

## Additional recommendations, not current completion requirements

1. **Keep web for fast iteration and Android for platform checks.** Continue implementing one feature at a time, then review it. Browser and phone databases are separate; web records do not automatically transfer to the phone.
2. **Protect the one-month deadline.** Prioritize Android build, notification checks, real-phone usability and evaluation before optional additions.
3. **Set up Git if not already done.** The last repository check reported that this workspace was not a Git repository. Keep CHANGELOG.md as offline memory, and add version-control commits/checkpoints for source recovery. Do not commit keys or personal test data.
4. **Consider local export/import later.** No in-app backup/restore feature is implemented. Device-local records and photos can be lost on app/site-data clearing; local backup could help evaluation without introducing cloud sync.
5. **Review photo storage under a realistic dataset.** The current per-photo cap is 5 MB and original bytes are stored locally. Measure startup, scrolling and storage use before deciding whether thumbnails, compression or lazy image loading are needed.
6. **Recheck guidance sources before submission.** The FoodKeeper references use a documented historical 2018 chart. Record any source/catalog updates and their implications rather than silently changing durations.

Cloud sync, shared-household synchronization, appearance-based spoilage detection, exact remaining-life prediction and automatic measurement of discarded food remain excluded from the agreed scope. They are not missing core deliverables.

## Suggested order

1. Successful debug APK build and physical-phone startup.
2. Core offline, photo and notification acceptance checks; fix defects.
3. Final requirement traceability and regression checks.
4. User evaluation, polish and submission materials.
5. Add calculated suggestions or camera convenience only if confirmed and time permits; keep recognition in its separate workstream.

Sources of project status: `Core Feature Checklist.md`, `FreshKeep Development Plan.md`, `Reminder Behavior.md`, README.md, CHANGELOG.md and the current Android/photo-picker source. Checklist boxes here reflect outstanding work, not a claim that no related implementation exists.
