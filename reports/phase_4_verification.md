# Phase 4 verification — complete

Verified in Power BI Desktop on 31 October 2026. This report records actual execution, not just file generation.

## Delivered report

- `powerbi/SalesAnalytics.pbip`: native project entry point.
- Five SQL import tables, four active one-to-many single-direction relationships, 18 measures, and three report pages.
- Source: local SalesAnalyticsDB. The connection uses Windows authentication.
- SQL refresh completed successfully, including 1,044,848 fact lines.
- The populated model and report were saved in Desktop. Local cached data under `.pbi` is excluded from Git; another computer must recreate the SQL database and refresh.

## DAX checks

All **16** checks in `powerbi/validate_measures.dax` passed in the actual loaded model:

| Check | Verified result |
| --- | ---: |
| Gross merchandise sales | £19,700,949.38 |
| Cancellation value | £719,656.34 |
| Net merchandise value | £18,981,293.04 |
| Eligible purchase orders | 39,516 |
| Average order value | £498.5563 at validation precision |
| Known purchasing customers | 5,852 |
| Repeat purchasers | 4,234 |
| Anonymous sales | £2,576,008.40 |
| Fact lines | 1,044,848 |
| Review lines | 1,447 |
| Retained repeated eligible sale value | £57,092.82 |
| Product 22423 gross sales | £331,084.27 |
| 2011 comparable complete-month growth | Approximately 0.028927 ratio, displayed as 2.89% |
| Distinct product display labels | 5,304 |
| Visible top-ten product rows | 10 |
| Combined top-ten product gross sales | £1,576,595.71 |

Money tolerances, integer tolerances, and ratio precision are explicit in the query. Screenshots `dax_validation_final_rows_1_8.png` and `dax_validation_final_rows_9_16.png` preserve actual PASS result grids. The later currency-format correction changed formatting, not measure expressions or data values.

## Interaction checks

- Selecting **2011** on the overview filtered the cards, trend, and top-product/country rankings. Gross sales £9,493,501.29 and net merchandise value £9,032,384.97 match the SQL yearly output. These are partial-year totals, not the January–November YoY comparison.
- Selecting **Australia** showed gross sales £167,867.51, net merchandise value £166,349.65, and 89 orders, matching SQL CountryPerformance.
- Clearing selections restored the all-period totals. Slicers are page-local, not synchronized.
- The monthly table showed blank YoY for partial December 2011. Complete-month growth displayed for eligible earlier comparisons.

## Display and identity corrections

- Removed text-box padding that clipped the report heading.
- Set card display units to None so order counts and currency are displayed exactly, rather than rounding 39,516 to 40K.
- Set percentage precision and removed redundant automatic visual subtitles.
- SQL's binary SKU identity differs from Power BI's case-insensitive text grouping. Added ProductLabel in Power Query, with a ProductKey-based variant suffix only for colliding case-insensitive codes. This preserves separate SQL identities rather than silently merging them. The top-ten count and total were validated after this correction; SKU 85099B's £180,888.03 now appears.
- Removed the Excel-style `[Red]` format token, which Power BI displayed literally. Negative amounts now use parentheses. The correction was applied in Desktop's TMDL view and saved.

All three pages were visually inspected with populated data. Scrollbars intentionally support the complete top-ten lists and monthly history. No blank/error visuals remain in the inspected delivered pages.

## Actual screenshots

- `dashboard/screenshots/01_sales_overview.png`
- `dashboard/screenshots/02_products_and_markets.png`
- `dashboard/screenshots/03_customers_and_data_quality.png`

These are native Desktop screenshots, not mockups. The overview opens unfiltered. The Products and Markets screenshot has the monthly table scrolled to recent months; no year/country filter is selected.

## Scope carried forward

Profit and original merchandise categories remain unavailable. Line-purpose classifications and transaction statuses are not product categories. RFM remains a verified fixed-window SQL analysis; the customer page does not claim dynamic RFM segmentation. Repeated-line candidates and provisional merchandise-code assumptions remain disclosed. No Power BI Service deployment, refresh gateway, or public publishing is claimed.
