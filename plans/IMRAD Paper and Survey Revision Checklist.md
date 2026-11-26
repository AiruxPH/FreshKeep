# FreshKeep — IMRAD Paper & Survey Revision Checklist

Created: 2026-11-26  
Targets:
- Manuscript: `paper_and_presentation(proposal)/FreshKeep_Research_Proposal(IMRAD).docx` → Final IMRAD Paper
- Survey: `paper_and_presentation(proposal)/Freshkeep_-_questionnaire_polished (1).docx` / Google Forms (`https://docs.google.com/forms/d/e/1FAIpQLSeqazJZfaJS-eTChevbZuaS1k_T2pdtu_-zVA3gwY_LlOVrpw/viewform?usp=header`) & printed sheets

---

## Part 1 — Questionnaire Changes (`Freshkeep_-_questionnaire_polished (1).docx` / Google Forms)

### Confirmed User Decisions
- [x] **No `N/O` column:** Use a straight **5-point Likert scale** (`5 = Strongly agree` to `1 = Strongly disagree`).
- [x] **Keep `Participant name` on the form:** Collect names to verify legitimate respondents, then anonymize into participant codes (`P1`, `P2`, ...) when reporting results in the manuscript.

### Wording Fixes Before Publishing Google Form
- [ ] **Section A heading:** Change `Functional Stability` → **`Functional Suitability`** (matches ISO/IEC 25010).
- [ ] **E.3 (Operability #3):** Change *"Settings I changed, such as storage locations, applied as I expected."* → **`Settings I changed, such as reminder time and lead window, applied as I expected.`**
- [ ] **I.2 (Flexibility #2):** Change *"I could create or rename storage locations to fit my own kitchen."* → **`I could organize foods using storage locations (Pantry, Fridge, Freezer) and food categories that fit my kitchen.`**
- [ ] **I.3 (Flexibility #3):** Change *"pieces, grams, or packs"* → **`pieces, grams (g), or millilitres (mL)`**.
- [ ] **H.6 (Maintainability #6, recommended since `N/O` was removed):** Consider rewording *"Updating the app preserved my existing records."* → **`Closing and reopening the app preserved my existing records.`** (or **`Exporting and importing a backup preserved my existing records.`**) so single-session testers do not have to guess.

### Google Forms Setup Tip
- [ ] Create one **Multiple-Choice Grid** question per section (`A` through `I`) with rows = statements and columns = `5, 4, 3, 2, 1` so all 67 items stay compact and quick to answer (~3 minutes).

---

## Part 2 — IMRAD Manuscript Changes (`FreshKeep_Research_Proposal(IMRAD).docx` → Final Paper)

### 1. Global & Preliminary Edits
- [ ] Convert proposal future tense (*"will provide / will validate / will use"*) to present tense for implemented behavior and past tense (*"was implemented / was verified"*) for development and testing steps.
- [ ] Write a **150–250 word Abstract** under the title/author block summarizing the problem, offline Flutter/SQLite build, technical verification (`55/55` requirements, `121/121` automated tests, device validation, and survey results if collected), and scope-bounded conclusions.

### 2. Introduction, Objectives & Scope
- [ ] Update mentions of *"Receipt scanning will be explored as an optional enhancement"* to state that **on-device ML Kit OCR was scoped to single-item packaging labels (food name + printed expiration date)** rather than multi-item receipts because grocery receipts do not print expiration dates.
- [ ] Keep all Scope & Limitations exclusions intact (single device, no spoilage prediction, no biological remaining-life prediction, no shared household sync, no automatic weighing of discarded food).

### 3. Methodology Updates (Exact Implemented Specs)
- [ ] **System Architecture & Development Tools:** Replace placeholder sentence with actual stack and build details:
  - Flutter `3.47.2`, Dart `3.13.2`, SQLite via `drift: 2.35.3` & `drift_flutter: 0.3.1` (**schema v9**, 6 tables: `batches`, `events`, `batch_edits`, `batch_photos`, `reminder_settings`, `app_preferences`).
  - Packages: `flutter_local_notifications: 22.3.3`, `timezone: 0.11.2`, `flutter_timezone: 5.1.1`, `image_picker: 1.2.4`, `file_picker: 13.4.0`, `google_mlkit_text_recognition: 1.0.3`.
  - Android config: `minSdk 24` (Android 7.0+), `compileSdk 36`, application ID `com.freshkeep.freshkeep`, version `1.0.0+1`, split-ABI release APKs (`arm64-v8a`: `34.13 MB`, `armeabi-v7a`: `27.54 MB`, `x86_64`: `35.99 MB`; note: update sizes if rebuilt after latest `2026-11-26` edits).
  - Add exact test hardware: **[Phone model, Android version, RAM/storage]**.
- [ ] **Data Model & Quantity Management:**
  - Document the **9 curated offline food categories** (`Produce`, `Meat & Seafood`, `Dairy & Eggs`, `Grains & Bakery`, `Canned & Dry`, `Beverages`, `Leftovers & Prepared`, `Condiments & Sauces`, `Other`) plus context-aware keyword recommendations and 1-tap mismatch prompts.
  - Note that `pieces` enforces positive whole integers while `g` and `mL` accept up to 2 decimal places computed via scaled integer hundredths to prevent floating-point drift, and that `events` + `batch_edits` are protected by SQLite append-only triggers with linked reversals (`undo`).
- [ ] **Food Entry, Maintenance & Local Backup:**
  - Right after *"Local storage will not protect against device loss or application removal"*, add **offline Local JSON Backup** (export/import with Merge & Replace modes and pre-commit validation) as a device-local mitigation without cloud sync.
  - Mention optional per-batch **display photos** (gallery or camera capture, 5 MB cap, stored in SQLite for visual reference only).
- [ ] **Date Reminders & Storage Guidance:**
  - Update provenance wording to exact implemented labels: **`Printed date`** (with optional `HH:mm` expiry time and live remaining-duration countdown), **`Suggested date (guidance)`**, and **`Date unknown`**, alongside user-configured daily notification time and 1-/3-day lead window.
  - State the catalog covers **16 common foods (17 condition-specific rules)** from the 2018 Wyoming Department of Health FoodKeeper chart and National Mango Board, requires confirmation of condition/storage/starting event/date (capped at today), and clears incompatible guidance if storage changes.
- [ ] **Optional Receipt Assistance → Optional On-Device Label OCR Assistance:**
  - Explain the pivot from multi-item receipts to single-item packaging labels (citing ML Kit `[6]`, `[7]` and CORD `[8]`): front/back multi-side scanning, `MFG`/`MFD`/`PROD`/`PKD` exclusion, ambiguity confirmation chips (`DD/MM` vs `MM/DD` and month-only `NOV 2026` / `EXP 11/26`), and draft-only handoff to manual review.
- [ ] **Evaluation & Data Handling (Survey Alignment):**
  - Specify the **5-point Likert scale (1–5, no `N/O`)**, add a one-line disclaimer that the survey was adapted from ISO/IEC 25010:2023 (not an official ISO instrument), and note that **`Participant name` was collected only to verify respondents and anonymized as `P1`, `P2`, ... when reporting results**.
  - State clearly that any participant testing photos included in the documentation/appendices were taken strictly voluntarily and with explicit participant consent.

### 4. New Sections to Write (Results, Discussion, Limitations, Conclusion)
- [ ] **Results — System Overview:** Insert 4–6 labeled release screenshots (Inventory, Add Groceries with category suggestion, Batch Details, Dashboard & Waste Log, Reminders/Backup/OCR).
- [ ] **Results — Technical Verification:**
  - Report `flutter analyze` (**0 issues**), `flutter test -j 1` (**121/121 passed, 100% pass rate** across `R1–R55`), and physical Android device checks from `plans/Requirement Traceability and Evaluation.md`.
  - Include Defect Log summary (`D-001` legacy migration fixture, `D-002` Android release R8 stripping `@drawable/ic_stat_freshkeep` resolved via `keep.xml`, `D-003` OCR month-year regex overlap).
  - Insert 5-trial **Task Timing Table** (medians & min–max ranges for Add food, Record disposal, Correct stock).
- [ ] **Results — Optional OCR Pilot:** Insert the 5 held-out packaged grocery scans from Section 6 of `plans/Requirement Traceability and Evaluation.md` (raw extraction vs. edits needed vs. scan-to-draft time).
- [ ] **Results — User Survey (`Google Forms`):** Report participant count ($n$), response distributions, item means, and section averages separately from developer testing *(or note deferral if no external respondents were collected)*.
- [ ] **Discussion & Honest Limitations:**
  - Discuss objective attainment + deployment lessons (`D-002` R8 shrinking fix; `--split-per-abi` reducing APK size from `90.44 MB` to `34.13 MB`).
  - State limitations: single-device local storage, Android OEM Doze battery delays on inexact alarms, 2018 FoodKeeper 16-food catalog scope, 1-minute foreground countdown refresh (`LocalDayScope`), and no claim of measured waste reduction or spoilage prediction.
- [ ] **Conclusion & References:** Summarize findings within scope, list future work (multi-item receipt parsing, longitudinal waste-reduction study, in-app update distribution), keep `[1]`–`[8]`, and add **ISO/IEC 25010:2023 as `[9]`** if reporting the survey.
