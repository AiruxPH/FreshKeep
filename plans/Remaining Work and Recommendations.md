# FreshKeep remaining work and recommendations

Reviewed: 2026-11-21. This is the current remaining-work list; older plan milestones describe historical status. Update this file and CHANGELOG.md as items are completed.

## Android build & device status

**Priority 1 (debug APK build, physical-phone startup, and physical-phone core/photo/notification acceptance) is complete.** Schema is now v6 (with optional `printed_time` and live `hoursLeft` countdown), and all 76 automated tests plus `flutter analyze` pass.

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

- [x] Map each numbered requirement R1-R46 to an executed acceptance case in `plans/Requirement Traceability and Evaluation.md`. (Re-check R45-R46 printed-time behavior on physical phone when ready.)
- [x] Run the final regression suite and analysis (`flutter analyze` clean, 76/76 tests passing).
- [x] Set up a build-specific defect log and device timing sheet template in `plans/Requirement Traceability and Evaluation.md`.
- [ ] Time representative tasks on the phone: add food, record disposal and correct stock. Report medians and ranges.
- [ ] Confirm participant count, consent/evaluation procedures and questionnaire interpretation with the instructor; conduct user sessions and report findings separately from developer tests.
- [ ] Address usability findings and document any remaining limitations.
- [ ] Prepare final screenshots, results/write-up, code appendix and reproducible setup instructions.
- [ ] Confirm final application identity, launcher icon, version/build number and distribution method.
- [ ] Generate the release keystore + `android/key.properties` (outside source control) and build/test the signed release artifact (`flutter build apk --release` or `flutter build appbundle --release`).
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
