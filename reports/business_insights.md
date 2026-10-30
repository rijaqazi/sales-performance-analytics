# Business insights and recommended actions

This is a historical retail case study, not a current trading report. All findings below come from executed SQL in [20_sales_analysis.sql](../sql/20_sales_analysis.sql), saved in [sql_analysis_results.json](sql_analysis_results.json). Monetary values are GBP. Recommendations describe what an analyst could propose; no business intervention or resulting improvement was measured.

## Scope and headline results

Unless specified otherwise, the period is **1 December 2009–9 December 2011**. Eligible merchandise purchases total **£19,700,949.38** across **39,516 orders**, with **£498.56 AOV**. After merchandise cancellations, net merchandise transaction value is **£18,981,293.04**.

The merchandise definition includes explicitly mapped merchandise and provisional five-digit-prefix codes. Separate shipping, fees, discounts, vouchers, review codes, and other adjustments are excluded from these KPIs. Net merchandise value is not audited accounting net revenue. Costs, profit, product categories, and subnational regions are unavailable. Country is the source customer-country label. Repeated-line candidates are retained.

## 1. Comparable sales grew modestly

**Evidence:** January–November 2011 gross merchandise sales were **£8,878,008.02**, compared with **£8,628,413.35** for January–November 2010: **2.89% growth**.

**Calculation:** `(2011 Jan–Nov / 2010 Jan–Nov − 1) × 100`. Evidence key: `ComparablePeriodYoY`.

**Action:** Review product and country contributions to this change before setting expansion priorities. Use the same complete-month comparison in management reporting.

**Limit:** December 2011 ends on the 9th; comparing the observed 2011 total with a full 2010 year would mix unequal coverage. This result does not identify the cause of growth or adjust for inflation.

## 2. November was the largest complete sales month in both years

**Evidence:** November 2010 recorded **£1,435,680.12** and November 2011 **£1,457,745.53**. Each was the highest observed complete month within its respective year (12 complete months in 2010; 11 in 2011).

**Calculation:** Rank `MonthlyTrends.GrossSalesGBP` within each year after filtering `IsCompleteSourceMonth = 1`.

**Action:** Plan purchasing, warehouse capacity, and service coverage ahead of November, then review SKU-level demand and cancellation history before committing stock.

**Limit:** Two annual cycles suggest a planning hypothesis, not a validated forecast or proof of a seasonal cause. The completeness flag describes source date boundaries.

## 3. Sales were concentrated in the United Kingdom

**Evidence:** UK gross merchandise sales were **£16,856,325.88**, or **85.56%** of total gross merchandise sales. EIRE and the Netherlands followed at **£623,795.85** and **£549,775.06**.

**Calculation:** `UK gross / all-country gross × 100`. Evidence key: `CountryPerformance`; denominator **£19,700,949.38**.

**Action:** Prioritize service reliability in the largest market. Evaluate non-UK markets using order size, shipping expense, and service requirements before proposing expansion.

**Limit:** Country sales are not profitability. Shipping costs and acquisition costs are absent; the source labels are not verified delivery destinations.

## 4. Frequent customers accounted for much of known-customer spending

**Evidence:** **961** known customers placed 10 or more eligible orders. They represented **16.42%** of the **5,852** known purchasing customers and generated **£11,403,696.08**, or **66.59%** of known-customer gross sales. Across all known purchasers, **4,234 (72.35%)** purchased more than once.

**Calculation:** `PurchaseFrequency` 10+ band divided by `CustomerBehavior` known-customer totals. Sales denominator is **£17,124,940.98**, excluding anonymous sales.

**Action:** Review the needs of frequent purchasers and prioritize account service, product availability, and retention measurement for this group.

**Limit:** Counts reflect observed orders in this historical window. High spending does not establish profitability, and repeat purchasing is not proof of loyalty caused by a program.

## 5. Missing customer IDs limit customer analysis

**Evidence:** **£2,576,008.40**, or **13.08%** of gross merchandise sales, had no customer ID.

**Calculation:** `CustomerBehavior.AnonymousGrossSalesGBP / KPIs.GrossMerchandiseSalesGBP × 100`.

**Action:** Improve consistent customer-ID capture and monitor the identified-sales share in future reporting. Keep anonymous sales in financial totals while excluding them from distinct known-customer and RFM counts.

**Limit:** The unknown dimension member is a relationship placeholder, not one customer. The data cannot establish whether anonymous purchases belong to existing known customers.

## 6. RFM suggests different retention priorities

**Evidence:** In the fixed **10 December 2010–9 December 2011** purchase window, **4,261** known customers generated **£8,451,542.90**. The analyst-defined Champions segment contained **857 customers (20.11%)** and **£5,290,620.82 (62.60% of window sales)**. The At-risk high value segment contained **407 customers** and **£858,916.39**; its average days since last purchase was **136.98**, compared with **12.05** for Champions.

**Calculation:** `RFMSegments` totals and segment shares; snapshot **10 December 2011**. Recency measures days since the last eligible purchase, frequency counts distinct eligible invoices, and monetary value sums gross purchases in the same window. Tie-aware percentile scores and prioritized segment rules are documented in the SQL guide.

**Action:** Propose service and retention attention for Champions and a separately measured reactivation experiment for high-value customers with older purchases. Evaluate response against a holdout before claiming an effect.

**Limit:** RFM labels are analyst heuristics, not validated churn predictions. This analysis is separate from the three dashboard pages. The historical customers are not a present-day outreach list.

## 7. Cancellations materially change the sales headline

**Evidence:** Merchandise cancellation value was **£719,656.34**, equivalent to **3.65%** of gross merchandise sales. Subtracting it gives **£18,981,293.04** net merchandise transaction value.

**Calculation:** `KPIs.CancellationValueGBP / KPIs.GrossMerchandiseSalesGBP × 100`. This is a **value ratio**, not a returned-order or returned-unit rate.

**Action:** Report gross sales, cancellation value, and net merchandise value together. Investigate cancellation reasons and SKU/order concentration before recommending a process change.

**Limit:** A cancellation prefix does not prove a physical return. The records do not establish why an order was cancelled, and cancellations are not matched to original purchases here.

## Suggested decision sequence

1. Improve identification and cancellation-reason capture so customer and operational decisions have better evidence.
2. Protect service for the largest market and frequent purchasers; distinguish revenue contribution from profitability.
3. Use the historical November peak as an input to demand planning, with SKU-level checks and updated data.
4. Test segment-specific retention ideas; measure outcomes before reporting any business impact.

## Evidence and verification

The report builder uses decimal arithmetic, checks country and customer-band reconciliations, confirms both annual peaks, and checks the RFM population and sales totals. Run `python scripts/build_business_report.py` to reproduce this report from the saved SQL results; this does not execute SQL Server or refresh Power BI. The saved SQL output itself can be reproduced by running the analysis against the verified model.

See [SQL verification](phase_3_verification.json), [Power BI verification](phase_4_verification.md), [metric definitions](../docs/metric_definitions.md), and [transformation rules](../docs/database_model.md).

Dataset: Chen, D. (2012). *Online Retail II*. UCI Machine Learning Repository, [DOI](https://doi.org/10.24432/C5CG6D), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This project applies the documented timeline partition, purpose classification, eligibility rules, dimensional modeling, and aggregation to the source.
