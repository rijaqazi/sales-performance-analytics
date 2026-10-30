# Phase 3: understand the SQL analysis

## Run and inspect

`sql/20_sales_analysis.sql` is the complete read-only analysis. Run the entire file in one SSMS query tab against SalesAnalyticsDB. It creates only session-local temporary tables and ends with one JSON result containing all sections. `reports/sql_analysis_results.json` is a readable capture of the actual executed result, not generated example data.

The current result was executed and reconciled through the connected SSMS session. Source and star-schema tables were not changed. The JSON groups many outputs into one reproducible snapshot; each section's inner SELECT is also an ordinary SQL analysis query.

## Requirement coverage

| Requirement | Result section | Meaning |
| --- | --- | --- |
| Total revenue/sales | KPIs | Eligible gross merchandise sales and separately labeled net merchandise transaction value |
| Profit and margin | KPIs.ProfitStatus | NULL, unavailable without costs; never reported as zero |
| Monthly/yearly trends | MonthlyTrends, YearlyTrends | Calendar order, explicit complete-month/full-year coverage |
| Top 10 products | TopProducts | Gross merchandise sales by StockCode, joined to display description; deterministic ranking |
| Sales by category | CategoryAnalysisStatus | Unavailable without a reviewed merchandise-category enrichment |
| Regional performance | CountryPerformance | Source country labels; no subnational regions are available |
| Customer behavior | CustomerBehavior, PurchaseFrequency | Known purchasing customers, repeat purchasers, order frequency, anonymous-sales coverage |
| Average order value | KPIs.AverageOrderValueGBP | Gross eligible purchase value divided by distinct eligible purchase invoices |
| YoY growth | MonthlyTrends, ComparablePeriodYoY | Complete comparable months; Jan–Nov 2011 versus Jan–Nov 2010 |
| RFM segmentation | RFMDefinition, RFMSegments | Fixed trailing-year window, identified customers, tie-aware relative scores |

The dataset cannot answer profit or original-category questions. Those limitations are part of a professional analysis, not missing values to invent. CodeType describes a line's purpose and is not a substitute merchandise category.

## How the query works

1. **CTE:** EligiblePurchases names the purchase population: LineStatus = MerchandiseSale. Naming a set helps explain what every following calculation includes.
2. **Temporary tables:** #Sales and #Orders avoid repeatedly rebuilding the same population. The # prefix means the table exists only in this connection. It is not a permanent model change.
3. **GROUP BY:** lines are grouped into invoices to count orders correctly. Counting invoice lines would overstate orders and understate AOV.
4. **JOIN:** dimension keys connect facts to product names, country labels, and known/anonymous customer status. We verify an invoice has one customer and country before customer analysis.
5. **CASE WHEN:** the query labels partial years, frequency bands, and RFM segments explicitly.
6. **Subqueries:** independent order and monthly sums are compared with the line total. NULLIF protects denominators without converting unavailable growth to zero.
7. **Window functions:** ROW_NUMBER ranks products with a stable code tie-breaker. PERCENT_RANK scores relative customer behavior without splitting equal metric values by an arbitrary customer-ID order.

## Time and order definitions

Transaction trends use each line's original timestamp. Order-level behavior uses the first eligible purchase timestamp per invoice. The actual check found zero eligible purchase invoices spanning different calendar dates or months, so the chosen order convention does not shift this snapshot's monthly order counts across dates/months.

Monthly YoY is NULL if either month lacks complete source-boundary coverage or the previous value is unavailable/zero. December 2011 remains partial. Annual comparison uses January–November in both 2010 and 2011, not a full year against a partial year. Percentage fields in JSON are 0–100 values; DAX percentage measures normally use 0–1 ratios.

## RFM definitions and scoring

- Snapshot: 10 December 2011, fixed to one day after the last observed date.
- Window: timestamps from 10 December 2010 inclusive to 10 December 2011 exclusive.
- Recency: days between the last eligible purchase line date and snapshot; smaller is more recent.
- Frequency: distinct eligible purchase invoice IDs during that same window.
- Monetary: gross eligible merchandise purchases in that same window, without subtracting cancellations.
- Population: known customer IDs with at least one eligible purchase in the window. Anonymous sales remain in overall KPIs but not RFM.

Relative percentiles are mapped to scores 1–5 at 0.2, 0.4, 0.6, and 0.8. Recency ranks in reverse direction so recent customers score higher. Frequency and monetary value rank upward. Ties retain the same score, so segment sizes need not be equal and a tied distribution can leave some scores unused.

Apply segment rules in this order:

| Segment | Rule |
| --- | --- |
| Champions | R >= 4 and F >= 4 and M >= 4 |
| At-risk high value | R <= 2 and either F >= 4 or M >= 4 |
| Recent occasional | R >= 4 and F <= 2 |
| Loyal | R >= 3 and F >= 3 |
| Dormant | R <= 2 |
| Potential | All remaining customers |

These are analyst-created exploratory labels. They do not prove churn, profitability, new-customer acquisition, or campaign response. Customers with no eligible purchase in the trailing window are outside this RFM population, even if they bought earlier. Historical source data cannot support a real current marketing campaign.

## Explaining the analysis

“I preserved both original worksheets, identified overlapping dates, and built a source-traceable star schema. I separated merchandise sales from cancellations and non-merchandise lines, documented a provisional stock-code rule, and retained repeated-line candidates for sensitivity analysis. I reconciled line totals to orders and monthly totals, aligned YoY coverage, and built RFM segments using a fixed historical window. I did not calculate profit because costs were absent.”
