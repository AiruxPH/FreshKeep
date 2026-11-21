# Core feature checklist

## Milestone 1 — manual entry and persistent inventory

- R1: Save a food name, integer quantity, supported unit, storage and optional printed date as a separate batch.
- R2: Reject empty names, invalid quantities, unsupported units/locations and invalid calendar dates.
- R3: Display saved batches with quantities, storage and printed-date/unknown labels.
- R4: Retain saved batches across reopening the database and refreshing the browser.
- R5: Cancel an entry without saving; disable save while a submission is in progress.
- R6: Show recoverable load/save errors without clearing data.

Executed 2026-11-01: all five automated tests passed; Flutter analysis passed. Tests exercise R1–R5, including SQL reopen persistence and entry/cancel interaction. Error recovery (R6) and duplicate-click behavior still need explicit fault/in-flight testing. Browser startup and refresh persistence were checked in isolated headless Chrome; see the change log for results. Android device validation remains pending.

## Milestone 2 — stock actions and batch history

- R7: Consume and dispose only positive integer quantities no greater than available stock; validate and insert atomically.
- R8: Correct to an actual remaining quantity (zero allowed); record its signed delta and exclude corrections from waste.
- R9: Preserve event history including time, quantity change and optional reason. Disposal defaults to Unspecified.
- R10: Derive depletion from stock; preserve depleted batches and allow correction to reactivate them.
- R11: Undo a mistaken action using a linked reversal; do not mutate or delete events. Exclude reversed disposal from waste; reject repeated undo or undo resulting in invalid stock.
- R12: Upgrade v1 inventory without data loss and persist new events through reopen.
- R13: Refresh inventory after managing a batch; reject stale submissions and disable saving while in progress.

Executed 2026-11-01: 13 automated tests passed, including original entry tests plus action validation, correction/waste separation, depletion/reactivation, append-only enforcement, undo, competing withdrawals, stale stock, v1 upgrade and manage-batch interaction. Flutter analysis passed. Tests deliberately open independent database files for migration; Drift emits its generic multiple-instance warning for those distinct test databases. Android device validation remains pending.

## Milestone 3 — date status labels

- R14: Display printed-date provenance and one of five calendar-based status labels: more than 3 days away, 1–3 days, today, past, unknown. Use text/icons as well as color; do not claim freshness.
- R15: Share a local calendar clock across inventory and details. Refresh at midnight and on resume; detect foreground date/clock changes within a minute and cancel timers on disposal.
- R16: Date status calculations never change stock, create events or record waste.

Executed 2026-11-01: all 19 tests passed and Flutter analysis passed. Added six tests covering threshold boundaries, leap/year transitions, time-of-day independence, midnight refresh/cleanup, resume/foreground clock changes, and past dates in both screens with unchanged stock/waste/history. No schema migration or dependency changes were needed.

## Milestone 4 — dashboard and waste log

- R17: Show total, active and depleted batch counts and unreversed disposal event count.
- R18: Keep remaining and disposed quantities separate by unit (pieces/g/mL); never combine incompatible units.
- R19: List unreversed disposals newest first, with quantity, reason, local timestamp, batch/event IDs and a link to history. Exclude consumption, corrections and undone disposals from waste.
- R20: Read a consistent inventory/disposal snapshot; refresh reports after returning from history and support manual refresh, empty states and retry after failure without clearing records.

Added a known-value reporting dataset, compatible-unit aggregation tests, a narrow-screen dashboard/log/undo flow and read-failure recovery coverage. See the change log for executed results.

Executed 2026-11-01: all 24 tests passed in the full suite, Flutter analysis passed, and isolated Chrome dashboard/waste-log/undo/refresh checks passed.

## Milestone 5 — multi-row grocery entry and name reuse

- R21: Add/remove editable grocery rows with independent names, quantities, units, storage and optional printed dates. Save each as a distinct batch, including identical food names.
- R22: Validate all rows before saving and commit them in one transaction. Database failure rolls back every new batch and retains drafts for retry; cancellation saves nothing.
- R23: Search/reuse past saved names, deduplicated without case sensitivity, latest spelling first. Include depleted batches and reuse only the name. Support manual input if suggestions fail.
- R24: Disable editing and duplicate submissions while saving. Keep unaffected row values when a row is removed.

Executed 2026-11-01: all 32 tests passed in the full suite and final Flutter analysis passed. Eight new tests cover grouped inserts, rollback on a later failing insert, name deduplication/depletion, invalid-row removal, multi-row save/cancel, searched-name selection without stale dates/quantities, failure/retry and in-flight duplicate protection. Isolated Chrome saved two rows independently and retained both after refresh.

## Milestone 6 — cited storage references

- R25: Bundle guidance for 15–20 foods with explicit condition, storage, duration, source page/section, review date and catalog version. Current coverage: 16 foods, 17 references.
- R26: Search/filter reference candidates, including batch-context food/storage searches. Unsupported combinations show no estimate. Conditions are not silently assumed.
- R27: Keep guidance separate from printed dates and stock events. No calendar date is calculated while the rule-specific starting event/date is unknown. Provide copyable/selectable source citations offline.

Executed 2026-11-01: all 37 tests passed and final Flutter analysis passed. Five new tests cover condition-aware searches, unsupported combinations, source display, storage filters and unchanged batch data. The narrow-screen regression caught an app-bar overflow after adding a third action icon; fixed by making the app title flexible.

Scope boundary: the reference catalog is complete for this milestone. Persisted rule selection/anchor events and calculated suggested dates are not implemented; they must be a separate change with their own migration and tests if introduced.

## Milestone 7 — reminder settings and platform scheduling

- R28: Persist opt-in reminder settings, local daily time and one-/three-day lead window across restart/refresh.
- R29: Preview future daily alerts through each active batch's printed-date day. Exclude unknown/past dates, depleted batches and elapsed times. Keep stock/waste unchanged.
- R30: Resynchronize after committed stock changes, startup/resume and explicit save/resync. Depletion/disable cancel alerts; correction/undo can restore eligible alerts.
- R31: Android notification permission handling, inexact scheduling, boot receiver setup, test notification, and clear blocked/failure states. No native delivery claim on web.

Seven reminder tests cover timing, exclusions, calendar boundaries, v2 migration/reopen, cancellation/restoration, platform failure/retry and web preference/preview behavior. Final executed results are in CHANGELOG.md. Android APK generation was interrupted by disk exhaustion; real-device delivery, reboot and timezone checks remain pending.

Executed 2026-11-01: all 44 tests passed in a serialized full-suite run after recovering disk space; Flutter analysis passed. Native APK/device validation remains outstanding.

Isolated Chrome verified reminder preference persistence after refresh and the preview-only web notice. The local server remains available at the same address.

## Milestone 8 — saved batch detail editing

- R32: Edit the saved name, storage and printed date (including clearing to unknown) while preserving starting quantity, unit, remaining stock and waste/event history.
- R33: Atomically update details with an append-only timestamped before/after audit. Reject stale forms; no-op edits create no audit record. Cancelling or a failed save leaves data unchanged.
- R34: Refresh inventory/date labels after editing and resynchronize reminders after name/date changes. Corrected names appear in reports and future name reuse.

Executed 2026-11-01: all 50 tests passed in the serialized full suite and Flutter analysis passed. Six new tests cover preserved stock/waste/audit, stale/no-op behavior, rollback on failed audit insertion, v3 upgrade/reopen with preferences, reminder rescheduling/cancellation, and editor validation/cancel/save/inventory refresh. Legacy v1/v2 fixtures were updated to reconstruct those earlier schemas accurately.

Isolated Chrome verified name editing, printed-date clearing, audit display and persistence after refresh.

## Milestone 9 — inventory browsing

- R35: Combine case-insensitive name search, storage, date-status and active/depleted filters with matching/total result counts and a recoverable no-match state.
- R36: Sort newest-first, by food name or by printed date (past first, unknown last), with stable newest-first tie-breaking. Never mutate inventory while browsing.
- R37: Retain view criteria when returning from batch management; reflect stock changes and refresh date-filter membership at local calendar boundaries. Provide clear/reset actions. View criteria reset on restart.

Added six tests for combined criteria, stable nonmutating sort order, date membership, narrow-screen reset/no-match flow, retained active-only criteria after consumption, and automatic midnight refresh. Final executed results are in CHANGELOG.md.

Executed 2026-11-01: all 56 tests passed in the serialized full suite, Flutter analysis passed, and isolated Chrome search/reset/sort checks passed.

## Milestone 10 — approved UI/UX refresh

- R38: Labeled mobile/desktop navigation, discoverable More tools and fresh inventory when returning from another tab.
- R39: Compact in-stock inventory, date-attention ordering, direct Use/Discard actions and exact-event quick Undo while preserving stored records and histories.
- R40: Full-screen multi-entry with compact explicit quantity/unit controls, storage/date summaries, accessible added rows and a keyboard-aware persistent Save action. Preserve all-or-nothing saves.
- R41: Progressive disclosure of audit/source/help details, consistent responsive styling and readable singular quantities; maintain complete history/source access and truthful reminder platform notices.

Executed 2026-11-01: 61 tests passed in the full suite and Flutter analysis passed. Five new UI tests cover labeled navigation/early food visibility, exact-event Undo preserving earlier waste, keyboard-aware multi-entry, tab refresh and large-text/wide layouts. Isolated Chrome verified the redesigned main flows on phone and desktop dimensions. Adapted interaction tests follow the new screens rather than treating old labels/widget structure as requirements.

## Milestone 11 ? optional display photos

- R42: Select an optional device photo for each independent grocery entry; display a thumbnail in inventory and a larger image in details without recognizing food or dates.
- R43: Add/change/remove photos through explicit-save editing; Cancel preserves the stored image. Validate readable images and cap each at 5 MB; keep photo bytes in local SQLite so they survive refresh/reopen.
- R44: Migrate existing inventory without losing stock/date/history/settings; make photo saves atomic with metadata, reject stale photo overwrites and record lightweight added/changed/removed detail-history entries. Photo edits never create stock movements or inferred dates. Old photos are not retained as an undo archive.

Six added automated checks cover photo validation/immutability, persistence/migration, stock/date preservation, transactional rollback, picker cancellation/failure and editor save/cancel. Flutter analysis passed; isolated Chrome verified actual image selection, inventory/details display, full-refresh persistence, cancelled removal and committed removal. Execution details are in CHANGELOG.md. Native picker and Android activity/process recovery remain device-verification work.

## Remaining core completion work

Complete Android build/device checks when disk/device access is ready; execute requirement-level acceptance tests and polish before evaluation. Calculated guidance dates still require separately persisted rule/condition/anchor inputs; the current guidance catalog remains reference-only. No recognition work is included in this phase.
