# FreshKeep UI/UX review

Reviewed 2026-11-01 at 390 × 844 browser dimensions. Inspected inventory, grocery entry and batch details visually, plus the report/reminder screen implementation. This is an interface review, not a user study. The user approved this direction; implementation notes below record the subsequent refresh.

## Findings

1. Inventory spends roughly half the initial phone viewport on branding/introduction, count, entry button, search and filter controls before showing the first food card. The daily task is checking food, so inventory should appear sooner.
2. Four app-bar icons are the only primary navigation. Tooltips help explain controls but do not provide persistent destination labels on a phone.
3. Grocery entry uses a narrow dialog with a large card per row. The name hint and quantity helper text are visibly clipped at phone width. Even one batch consumes most of the screen; multi-row entry involves substantial scrolling. Soft-keyboard behavior was not inspected in this headless browser review.
4. Inventory cards spend a separate line/action on Manage batch. Common consume/dispose actions require opening details first. Quantity and date could have a clearer hierarchy, and depleted history need not compete with active food by default.
5. Batch details expose stock history, details history and explanatory record text at the same visual level as daily actions. Audit information is valuable but can be progressively disclosed.
6. Some copy reads like a data-management tool: batch, depleted, disposal events, resync. Use plain action labels where possible while retaining precise explanations. Fix singular/plural issues such as 1 pieces and 1 batches.

## Recommended direction

- Keep the current green and warm off-white palette. Improve spacing, text hierarchy and contrast before introducing decorative assets or complex animations.
- Mobile navigation: visible labels for Inventory, Dashboard, Waste and More; place guidance/reminder settings under More. Use a persistent, easy-to-reach Add groceries action. Use an equivalent labeled layout on wider web screens.
- Inventory: compact header, immediate search/filter access, active batches as the normal view, and clear date-attention ordering. Retain accessible depleted history and exact date provenance. Date labels must never imply freshness guarantees.
- Cards: emphasize food name, remaining quantity/unit and date status. Tap the card for details; provide labeled shortcuts for common quantity actions. Preserve review/validation and undo behavior.
- Entry: a full-screen mobile entry flow with compact editable rows and a persistent Save action. Keep names/quantities/units and a storage/date summary understandable. Optional details may expand, but unknown dates and units must stay explicit. Keep the existing all-or-nothing save and per-batch independence.
- Details: prominent quantity actions; secondary edit/guidance; collapsible audit sections. Keep tooltips for secondary help and visible labels for essential actions.
- Move detailed platform/developer information out of the main daily flow where possible. Keep a short, truthful web-preview notice for reminders and place troubleshooting details in an expandable section.

## Suggested implementation order

1. Navigation and inventory layout.
2. Grocery-entry experience.
3. Batch details/action sheets and consistent wording.
4. Dashboard, guidance and reminder visual consistency.
5. Phone-width, large-text, keyboard, focus and screen-reader checks.

Preserve business rules, saved records, source citations and the offline scope. Existing automated tests remain useful for regression, but layout changes will need interaction/accessibility checks rather than treating the present widget structure as a requirement.

Review screenshots and the temporary capture script are stored under ignored `.dart_tool/` (`review-inventory-mobile.png`, `review-entry-mobile.png`, `review-details-mobile.png`, `ui_review.mjs`). No application source changed during this review.

## Implemented refresh — 2026-11-01

- Added labeled Inventory/Dashboard/Waste/More bottom navigation and a labeled sidebar on wide screens. More contains reminders and guidance. Returning to Inventory refreshes data after changes made elsewhere.
- Replaced the introductory inventory banner with a compact header and persistent Add action. Default to in-stock food ordered by printed date, with quick All/Used up access. Food cards emphasize name/quantity/storage/date and expose Use/Discard actions directly. Tapping a card opens details.
- Extracted the shared, validated stock-action form into phone sheets/wide dialogs. Quick-action Undo receives the exact committed event ID rather than guessing the latest event. Record history and waste separation remain unchanged.
- Replaced the narrow grocery dialog with full-screen entry, compact quantity/unit fields, expandable storage/date summaries, automatic focus/scroll for added entries and a keyboard-aware fixed Save area. Atomic save and independent dates/units remain unchanged.
- Collapsed stock/detail audit histories and source citation details. Reworked dashboard counts into a phone-friendly 2×2 layout; retained the green/off-white palette with white cards, clearer borders and consistent control sizing. Simplified reminder lead labels/help and fixed common singular quantity labels.
- Validation: 61 tests passed in the full suite, including five new navigation/layout/action tests; Flutter analysis passed. Targeted checks covered adapted scrolling/history/source interactions. Isolated Chrome exercised mobile and desktop navigation, quick Use/Undo, two-entry save/search, Dashboard/Waste and More tools.
- Automated layout checks include the first phone food card appearing before half the viewport, persistent Save above a simulated keyboard, large phone text and wide-screen navigation. These are not a physical-phone or assistive-technology user study.
- New captures live under `.dart_tool/`: `new-inventory-mobile.png`, `new-entry-mobile.png`, `new-action-mobile.png`, `new-details-mobile.png`, `new-dashboard-mobile.png`, `new-more-mobile.png`, and `new-inventory-desktop.png`. Browser fixtures are isolated from the user's normal browser data.

No database schema, dependency, source-guidance duration or Android build configuration changed. Existing saved records remain intact. Physical Android build/notification verification remains outstanding from the earlier phase.
