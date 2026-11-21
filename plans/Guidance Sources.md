# Storage guidance source register

Reviewed: 2026-11-01 (Asia/Taipei). Catalog version: 2026-11-01.1.

The canonical rule values and page/row citations are in `lib/data/guidance_catalog.dart`. The bundled catalog covers 16 distinct foods with 17 condition-specific references (two egg conditions). Duration ranges and units are preserved, rather than converted to a single expiry prediction.

## Sources

1. [Wyoming Department of Health: Food Storage Times](https://health.wyo.gov/wp-content/uploads/2018/06/FOOD-STORAGE-TIMES-.pdf), hosted under June 2018. Its introduction explicitly attributes all storage times to FoodKeeper. Verified the food/condition/duration columns using the PDF text and requested table-page screenshots. Page references in code are one-based. This is a published historical reproduction, not a claim to have downloaded the current FoodKeeper database.
2. [National Mango Board: Ripening and Storing Mangos](https://www.mango.org/ripening-and-storing-mangos/), section on whole ripe fruit. Used this instead of the chart's older combined papaya/mango row. Preserve the distinction between whole ripe mangoes and unripe/cut fruit.
3. [FoodSafety.gov: FoodKeeper App](https://www.foodsafety.gov/keep-food-safe/foodkeeper-app), provenance of FoodKeeper (USDA FSIS, Cornell University and the Food Marketing Institute). This page is context, not an extra duration source.

The official FSIS JSON URL listed in the government data catalog returned HTTP 403 during review: `https://www.fsis.usda.gov/shared/data/EN/foodkeeper.json`. No unverified third-party replacement was used. Future catalog revisions must recheck the cited rows, assign a new catalog version, and record changes here and in CHANGELOG.md.

## Implementation boundaries

- Rules are offline reference data with explicit conditions and storage. Search results are candidates, not a claim that a rule applies to the batch.
- No automatic matching or date calculation occurs. No rule is silently attached to saved batches. Current batches do not record the rule-specific starting event, so the app explicitly says no suggested date is set.
- Missing foods/storage combinations receive no estimate. A fridge reference is not applied to pantry/freezer batches. Choosing All storage only browses references and does not change a batch's storage.
- Printed dates, inventory quantities, stock events and waste remain unchanged when guidance is viewed. No schema or dependency changes were needed.
- If calculated suggestions are added later, first persist the selected rule/version, confirmed condition and known anchor event/date separately from the printed date. Unknown anchors must produce no calculated date.
