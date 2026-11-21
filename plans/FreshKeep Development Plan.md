# FreshKeep Development Plan

## Updated delivery agreement — 2026-11-01

**Latest scope decision:** Build the core app first. Image processing is a separate workstream and is excluded from the current app implementation schedule and completion criteria. Do not start the camera experiment during this core-app phase. Preserve an editable entry-draft boundary for later integration without implementing recognition now. This decision supersedes camera-experiment slots in the schedule below.

This section supersedes the original ten-week schedule and the unresolved teacher-intent question below. The original sections remain as scope/reference material. The DOCX copy has not been synchronized with this update.

- Deadline: one month. Build and review features one at a time.
- Develop the Flutter app with web and Android targets. Use the browser for rapid core-feature testing; Android remains the final mobile target.
- Prefer Drift with browser SQLite/WASM persistence and native SQLite on Android. Verify saved data survives a browser refresh early. Browser and Android data are separate local stores; clearing browser storage can remove browser test data.
- Android camera recognition and scheduled notifications require their own device checks. Browser tests alone do not establish Android readiness.
- Teacher clarification: image input means photographing groceries to draft food names and read printed expiration dates. It does not mean spoilage detection. Single-item versus batch capture remains undecided.
- Separate food-name recognition from printed-text recognition. A photo can supply a printed date only when it is visible and readable. Do not infer an expiration date from the food's appearance. Ambiguous or missing dates require review or remain unknown; any guidance suggestion is shown separately.
- First camera experiment, after the core flow: a single packaged item, using one or more photos if its name and date are on different sides. This is a proposed experiment, not a final decision against batch capture. Keep every result editable before saving. Broader food recognition and multi-item/date association need separate feasibility testing and are not guaranteed within this month.
- Google ML Kit's Flutter text-recognition package supports Android/iOS, not web. Keep the recognition service separate so browser tests can exercise draft review with clearly identified sample results without claiming real recognition.

### Four-week delivery targets

| Week | Sequential features | Acceptance gate |
| --- | --- | --- |
| 1 | Project setup, manual single-batch entry, saved inventory | Add a batch and verify it after browser refresh |
| 2 | Consume, dispose, correct, history, date labels | Stock and waste totals pass expected-value tests |
| 3 | Multi-row entry, waste log/dashboard, sourced guidance, Android reminders | Each feature reviewed separately; reminders checked on Android |
| 4 | Core regression, fixes, evaluation and documentation | Core features verified and results documented |

Reserve evaluation/documentation time throughout the month. If camera automation becomes mandatory for submission, agree a narrower core or camera scope before committing to the deadline. Full grocery recognition plus reliable batch expiration matching is a separate stretch scope.

### Immediate next feature

Create the Flutter web/Android project and implement manual single-batch entry with persistent inventory. Complete and review this feature before starting stock actions. No app implementation has started as part of this planning update.

References: https://drift.simonbinder.eu/platforms/web/ and https://pub.dev/documentation/google_mlkit_text_recognition/latest/

Prepared for Anecito Randy E. Calunod Jr. · ITP801 Mobile Application Development · Misamis University · November 2026

## 1. Overview and Status

FreshKeep is an offline Android app for students living independently. It tracks food in batches, records consumption, disposal and correction as separate events, and handles printed, suggested and unknown dates carefully. The proposal has been presented and accepted. The teacher suggested adding image processing for the input of goods. That feature is **on hold** until the core app is stable (see Section 8).

**Stack:** Flutter and Dart for the interface and logic, SQLite for local storage.

## 2. Scope

**Must have (MVP)**

- Quick multi-row entry with search and reuse of past food names
- Batches with explicit units and optional dates
- Consume, dispose and correct actions, with validation
- Date status labels and local reminders
- Curated storage guidance for 15 to 20 foods
- Dashboard of tracked inventory and recorded waste

**On hold (planned for later):** image-based entry of goods.

**Excluded, as the proposal states:** cloud sync, shared household synchronization, image-based spoilage detection, exact remaining-life predictions, automatic measurement of discarded food.

## 3. Architecture and Stack

Three layers, matching the proposal:

- **Presentation:** Entry, Inventory, Item details, Waste log and Dashboard screens.
- **Application logic:** pure Dart classes for validation, stock calculation, date status and guidance selection. Keep these free of Flutter imports so they are easy to unit test.
- **Data:** SQLite repositories for batches, events and guidance rules.

**Packages to consider** (pin exact versions and record them, since the proposal says versions will be documented):

- `sqflite` or `drift` for SQLite. Drift gives typed queries and migrations.
- `riverpod` for state management.
- `flutter_local_notifications` and `timezone` for reminders.
- `intl` for dates.
- `flutter_test`, `integration_test` and `sqflite_common_ffi` for tests.
- Image-processing packages are chosen later (Section 8).

## 4. Data Model

| Table | Key fields |
| --- | --- |
| `foods` | id, name, category, guidance\_rule\_id (nullable) |
| `batches` | id, food\_id, starting\_qty, unit, storage\_location, purchase\_date, date\_value (nullable), date\_source (printed, suggested, user, unknown), status |
| `events` | id, batch\_id, type (consume, dispose, correct, adjust), qty, reason (nullable), created\_at |
| `guidance_rules` | id, food, condition, storage\_method, duration, starting\_event, source\_citation |

**Design decisions**

- Make `events` append-only and compute remaining stock from it: (starting + adjustments) − (consumed + discarded). One source of truth is easier to test and audit.
- Count only `dispose` events as waste, so corrections never inflate it.
- Store whole items as integers. Store measured units as integers in a smaller unit (grams rather than decimal kilograms) to avoid floating-point drift.
- The dashboard groups quantities by compatible unit and never sums pieces, grams and millilitres together.
- Use a depleted flag on batches so history stays available.

## 5. Date Handling

- **Resolution order:** retain the printed date, then suggest from a guidance rule, otherwise leave it unknown.
- **Starting event:** if the starting event is unknown, such as when the item was first stored, do not start the clock.
- **Status labels:** more than 3 days away, 1 to 3 days, today, past, unknown. These are interface thresholds, not biological freshness rules.
- **Source badges:** each date shows whether it is printed, suggested or user-entered.
- **Overdue dates:** passing a date never creates a waste record automatically.

**Guidance rules:** choose 15 to 20 foods and fill durations only from the cited source (FoodKeeper or the National Mango Board). Do not use numbers from memory. Eggs, milk, chicken, mangoes, bananas, bread, leftovers and leafy greens are sensible candidates because they are common for students.

## 6. Screens

- **Inventory:** active batches with date status and remaining quantity.
- **Add entry:** editable multi-row list with search suggestions and previous-name reuse.
- **Item details:** batch history and events.
- **Consume, dispose, correct sheets:** short quantity-update actions. Disposal records the date, amount and reason (with an unspecified option).
- **Waste log:** recorded disposals with reasons.
- **Dashboard:** batch counts, disposal events and quantities grouped by compatible unit.

## 7. Timeline

This assumes about 10 weeks. Adjust it to the submission or defense date.

| Phase | Weeks | Deliverables | Done when |
| --- | --- | --- | --- |
| 0. Setup | 1 | Flutter project, Git repo, numbered requirements (R1, R2...), blank test checklist, physical device working | App runs on your phone |
| 1. Data and logic | 2–3 | Schema, repositories, stock calculation, validation, date status, unit tests | Edge-case unit tests pass |
| 2. Core UI | 3–5 | Entry list, inventory, details, consume/dispose/correct sheets | Full add, consume and dispose flow works |
| 3. Reminders and guidance | 5–6 | Notification scheduling, guidance seed data, source badges | Reminders fire after an app restart |
| 4. Dashboard and polish | 7 | Dashboard, waste log, empty states, error messages | No open critical defects |
| 5. Image-based entry (on hold) | 8, if time allows | See Section 8 | Core app stable first |
| 6. Evaluation | 8–10 | Functional tests, timing, user sessions, questionnaire | Data collected |
| 7. Write-up | 10+ | Results chapter, screenshots, Appendix D code | Manuscript complete |

## 8. Image-Based Entry of Goods (On Hold)

The teacher suggested image processing for entering goods. It is deliberately postponed. Until the core app is done, only these small preparations belong in the build:

- **Entry draft interface:** design the Add entry screen so rows can come from more than one source (manual typing now, image-derived drafts later). Image results should always arrive as editable drafts that the user reviews before saving, never saved automatically. This matches the proposal's treatment of receipt assistance.
- **Keep it out of the core path:** failure or absence of this feature must not block evaluation of the core system.
- **Dates stay honest:** a photo should never invent a date. If no printed date is read, the date stays unknown.

**Options to decide later**

| Approach | What it gives | Trade-off |
| --- | --- | --- |
| Text recognition on receipts or labels (Google ML Kit, on-device) | Draft rows from receipt text, printed dates from packaging | Receipt text is messy and needs review and correction |
| Photo recognition of the item itself (image labeling or a small custom model) | Suggested food name and category from a photo | Needs a food class list and testing, and accuracy varies |

**Open questions to settle with the teacher**

1. Which input is meant: receipts, product labels, or photos of the food itself?
2. Does the accepted scope statement need an amendment, given that the proposal lists receipt recognition only as optional and excludes image-based spoilage detection (entry recognition is a different thing from spoilage detection)?
3. How should this feature be evaluated: extraction error counts, correction effort, and time compared with manual entry, as the proposal already outlines for receipts?

## 9. Testing Plan

Build the test checklist alongside the code, so every requirement ID maps to at least one test case.

- **Unit tests:** negative stock rejected, over-quantity disposal rejected, correction not counted as waste, date boundaries, unknown dates, separate batches for different dates, unit grouping.
- **Integration tests:** restart persistence, offline operation, cancelled actions leave records unchanged.
- **Expected-value dataset:** a fixed inventory with known outcomes, used to compute the functional pass rate.
- **Timing sheet:** time the representative tasks (add food, record disposal, correct stock) on the device and report medians and ranges.
- **Portability:** install on whatever Android versions or devices are available, and state the single-device limits plainly.
- **Defect log:** record every bug with a build number.
- **Image-based entry, if built:** use distinct examples plus held-out ones, and record raw extraction errors and correction effort.

## 10. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Reminders unreliable under Android battery optimization | Test on a real device early. Request the notification permission on Android 13 and later. Use exact alarms only if needed. Add a note that reminders may be delayed. |
| Wrong guidance data | Cite a source for every rule. Leave unsupported foods without an estimate. |
| Scope creep, especially from image processing | Hold the MVP line. Do not start Section 8 until Phase 4 is stable. |
| Too few participants | Confirm sample size and ethics steps with the instructor before Phase 6. |
| Questionnaire alignment | Confirm the ISO attribute mapping and the uneven score bands with the instructor, as the proposal notes. |

## 11. Definition of Done

- All MVP features work offline on a physical Android device.
- Every numbered requirement has at least one executed test case, with the pass rate reported.
- Saved records survive an app restart.
- User sessions and the questionnaire are completed, with results reported separately from developer tests.
- Screenshots, code appendix and defect log are ready for the Results chapter.

## 12. Next Steps This Week

1. Create the project and repo, and get a blank app running on your phone.
2. Turn the proposal into numbered requirements.
3. Write the schema and the stock-calculation unit tests first.
4. Pick the 15 to 20 foods and start collecting source citations.
5. Ask the teacher the open questions in Section 8 when convenient, so the image feature is defined before you reach it.
