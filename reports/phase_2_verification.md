# Phase 2 verification — complete

Verified by executing scripts in a Windows-authenticated SSMS session on 31 October 2026. Source staging rows were preserved.

## Database and relationships

Database: SalesAnalyticsDB on the user's local SQL Server 2025 (17.x) instance. Scripts use features compatible with SQL Server 2022. SSMS version observed locally is 22.

| Table | Verified rows |
| --- | ---: |
| stg.RetailRaw | 1,067,371 |
| dbo.FactSalesLine | 1,044,848 |
| dbo.DimDate | 1,095 |
| dbo.DimProduct | 5,304 |
| dbo.DimCustomer | 5,943 |
| dbo.DimCountry | 43 |

DimCustomer includes 5,942 known identifiers and one anonymous placeholder, not 5,943 known customers. Country counts represent source labels. Product keys standardize trailing spaces while preserving case. Date covers the full calendar years 2009–2011; source coverage is narrower.

All five fact foreign keys are enabled and trusted. Source keys uniquely trace each fact line to staging. A decimal CHECK constraint enforces quantity × price. The build and indexes committed successfully.

## Verified controls

- All seven original raw checks PASS: row count, missing customers, missing descriptions, negative quantities, zero prices, negative prices, invalid typed rows.
- Original sheet counts remain 525,461 and 541,910.
- Canonical count and fact count both equal 1,044,848.
- No canonical source lines are missing from facts.
- Canonical-to-fact signed-value difference: **0.0000 GBP**.
- Disabled or untrusted fact foreign keys: **0**.
- Date dimension continuity: 1,095 actual dates and 1,095 expected dates.

## Complete transaction-value reconciliation

These values are technical controls, not audited financial revenue.

| Canonical status | Lines | Signed source value (GBP) |
| --- | ---: | ---: |
| MerchandiseSale | 1,015,070 | 19,700,949.3800 |
| MerchandiseCancellation | 17,973 | -719,656.3400 |
| NonPositivePrice | 5,954 | 0.0000 |
| NonMerchandise | 4,404 | 11,436.1710 |
| ReviewCode | 1,447 | -82,967.0930 |
| **Total canonical** | **1,044,848** | **18,909,762.1180** |

The date partition excludes 22,523 overlapping-extract lines with signed value 377,488.4500 GBP from the canonical timeline; all remain in staging. Adding excluded value and canonical value yields the raw signed transaction value of 19,287,250.5680 GBP. These exclusions differ from exact duplicate matching.

No populated InvalidTypedValue, CancellationException, OtherQuantityAdjustment, or QuantityException status groups appeared under the adopted priority rules. This does not mean such issues never occurred in raw data: some raw exceptions fall under earlier purpose/price classifications.

## Repeated lines and unresolved data

11,812 repeated-line candidates remain in facts, with signed source value 54,228.4200 GBP. They are not automatically erroneous and were not removed. The remaining 1,033,036 first/nonrepeated lines have signed value 18,855,533.6980 GBP. SQL comparison semantics and the canonical date partition differ from the all-raw Python profile, so duplicate counts need not match.

`clean.vw_DataQualityReview` provides a non-destructive review surface for unresolved purposes, nonpositive prices, typed exceptions, and repeated-line flags. Legitimate anonymous purchases remain in the model. Shipping/fees/discounts/vouchers/samples/tests remain traceable and separate from merchandise KPIs.

## Definitions and limits carried forward

- Merchandise scope includes explicitly mapped products and provisional five-digit-prefix candidates. Preserve ClassificationBasis for sensitivity analysis.
- C-prefix flags cancellation, not proof of a physical return.
- Net merchandise transaction value includes eligible sales and signed eligible cancellations. It excludes separate discounts and other adjustments; do not label it audited net revenue.
- Repeated within-sheet lines are retained. RFM must exclude the anonymous customer placeholder.
- December 2011 is partial; YoY must align coverage.
- No costs or original product categories are available. Profit is unavailable. Line-purpose classification is not a substitute product-category hierarchy.

## Reproduction

Fresh database: run SQL files 01–13 in numeric order after generating the staging CSV. Script 00 is an optional connection check. Do not rerun the import into nonempty staging. Script 11 stops when facts already exist; use script 12 for read-only revalidation. Classification changes require a deliberate refresh design rather than mixing rule versions in an existing fact snapshot.

Evidence: `phase_2_ssms_validation_evidence.txt` and `phase_2_raw_validation_evidence.txt` contain the actual aggregate result values read from SSMS. Model documentation: `docs/database_model.md`. SQL analysis and Power BI are the next phases; they are not included in this completion claim.
