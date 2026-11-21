# FreshKeep feasibility review

Reviewed: 2026-11-01 (Asia/Taipei)

## Decision

Proceed with the offline Android MVP in FreshKeep Development Plan.md. Flutter, pure Dart business logic and SQLite fit this scope. Image-based entry remains optional and outside the MVP completion criteria. This is a document-level feasibility assessment, not a tested application or a verification of the accepted proposal.

The workspace currently contains planning/proposal documents; no Flutter project or pubspec.yaml was found. Ten weeks is a reasonable planning estimate for a focused student MVP, conditional on available development hours, device access and evaluation scheduling. It is not a guaranteed delivery estimate. Write the manuscript and gather evaluation approvals alongside development, rather than starting the write-up after week ten.

## Resolve before schema implementation

1. Corrections: expose one correction action that accepts the actual remaining quantity. Persist its signed delta (actual minus current) as a correction event. Remaining stock = starting quantity + signed correction deltas - consumption - disposal. Remove the ambiguous separate `adjust` event unless a distinct use case is established. Never count corrections as waste. Correcting a mistaken disposal record needs a linked reversal/correction policy so waste totals can also be fixed without deleting history.
2. Transactions: validate available stock and append each event in one database transaction. Prevent duplicate submissions. Define all-or-nothing saving for a multi-row entry. Reject zero/negative consumption and disposal, incompatible units and results below zero.
3. Units: establish a small fixed unit list and canonical integer storage (pieces, grams, millilitres). Do not convert volume to mass or packages to pieces without explicit conversion data. Decide whether fractional pieces are excluded.
4. Dates: store date-only values separately from event timestamps. Calculate status using local calendar dates, including refresh after midnight/resume. Add printed date kind (for example best-before, use-by, unspecified) separately from source; do not present every past date as proof of spoilage.
5. Guidance: persist the applicable condition, anchor event/date and selected rule/version for a batch. Distinguish opened/unopened and storage conditions. A food-level rule ID alone cannot express these choices. Unknown anchors produce no suggested date. Retain explicit user overrides and their provenance. Unsupported foods remain unknown.
6. Batch lifecycle: derive depletion from remaining quantity, or update a cached flag in the same transaction. A positive correction must reactivate a depleted batch. Preserve historical records and foreign-key integrity.
7. Reminders: specify the daily reminder time, selected date thresholds, cancellation for depleted batches and rescheduling after date edits. Test app restart and device reboot separately, plus permission denial and timezone changes. Use inexact scheduling for ordinary food reminders unless exact timing has a demonstrated requirement.

## Execution order

1. Number MVP requirements and define expected results for stock/date edge cases.
2. Scaffold Flutter, select and record compatible dependency versions, and run on a physical Android device.
3. Build one complete flow: add a batch, persist it, consume/dispose/correct, restart and verify inventory and waste totals.
4. Extend to multi-row entry, remaining screens and unit-grouped dashboard.
5. Add sourced guidance and reminders. Run a small reminder feasibility check on the target phone early in development.
6. Execute requirement tests and user evaluation; finish screenshots, defect log and manuscript.

Keep image work out of the critical path. The teacher's intended input type and evaluation expectations still require confirmation before that feature is implemented.

## Technical references checked

- Drift supports SQLite transactions and migration tooling: https://drift.simonbinder.eu/dart_api/transactions/ and https://drift.simonbinder.eu/migrations/
- flutter_local_notifications documents Android permissions, scheduling and reboot receiver setup: https://pub.dev/packages/flutter_local_notifications

No guidance durations or food-safety claims were verified in this review. Each eventual guidance rule still needs its own cited source.
