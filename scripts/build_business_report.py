"""Build portfolio findings from the saved, executed SQL result (no generated data)."""
from pathlib import Path
from decimal import Decimal
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'reports/sql_analysis_results.json'
d = json.loads(source.read_text(encoding='utf-8-sig'), parse_float=Decimal)
k = d['KPIs']
gross = k['GrossMerchandiseSalesGBP']
behavior = d['CustomerBehavior']
uk = next(x for x in d['CountryPerformance'] if x['Country'] == 'United Kingdom')
frequent = next(x for x in d['PurchaseFrequency'] if x['PurchaseBand'] == '10+ orders')
champ = next(x for x in d['RFMSegments'] if x['Segment'] == 'Champions')
risk = next(x for x in d['RFMSegments'] if x['Segment'] == 'At-risk high value')
rfm_customers = sum(x['Customers'] for x in d['RFMSegments'])
rfm_sales = sum(x['GrossPurchasesGBP'] for x in d['RFMSegments'])
yoy = d['ComparablePeriodYoY']
def pct(n, denominator):
    return Decimal(n) * 100 / Decimal(denominator)
def money(n):
    return f'£{n:,.2f}'
peaks = {}
for year in ('2010', '2011'):
    complete = [x for x in d['MonthlyTrends'] if x['MonthStart'].startswith(year) and x['IsCompleteSourceMonth']]
    peaks[year] = max(complete, key=lambda x: x['GrossSalesGBP'])
assert k['GrossMerchandiseSalesGBP'] - k['CancellationValueGBP'] == k['NetMerchandiseTransactionValueGBP']
assert sum(x['GrossSalesGBP'] for x in d['CountryPerformance']) == gross
assert sum(x['GrossPurchasesGBP'] for x in d['PurchaseFrequency']) == behavior['KnownCustomerGrossSalesGBP']
assert rfm_customers == 4261 and rfm_sales == Decimal('8451542.90')
assert all(x['MonthStart'].endswith('11-01') for x in peaks.values())

report = f'''# Business insights and recommended actions

This is a historical retail case study, not a current trading report. All findings below come from executed SQL in [20_sales_analysis.sql](../sql/20_sales_analysis.sql), saved in [sql_analysis_results.json](sql_analysis_results.json). Monetary values are GBP. Recommendations describe what an analyst could propose; no business intervention or resulting improvement was measured.

## Scope and headline results

Unless specified otherwise, the period is **1 December 2009–9 December 2011**. Eligible merchandise purchases total **{money(gross)}** across **{k['PurchaseOrders']:,} orders**, with **{money(k['AverageOrderValueGBP'])} AOV**. After merchandise cancellations, net merchandise transaction value is **{money(k['NetMerchandiseTransactionValueGBP'])}**.

The merchandise definition includes explicitly mapped merchandise and provisional five-digit-prefix codes. Separate shipping, fees, discounts, vouchers, review codes, and other adjustments are excluded from these KPIs. Net merchandise value is not audited accounting net revenue. Costs, profit, product categories, and subnational regions are unavailable. Country is the source customer-country label. Repeated-line candidates are retained.

## 1. Comparable sales grew modestly

**Evidence:** January–November 2011 gross merchandise sales were **{money(yoy['CurrentGBP'])}**, compared with **{money(yoy['PriorGBP'])}** for January–November 2010: **{yoy['GrowthPct']:.2f}% growth**.

**Calculation:** `(2011 Jan–Nov / 2010 Jan–Nov − 1) × 100`. Evidence key: `ComparablePeriodYoY`.

**Action:** Review product and country contributions to this change before setting expansion priorities. Use the same complete-month comparison in management reporting.

**Limit:** December 2011 ends on the 9th; comparing the observed 2011 total with a full 2010 year would mix unequal coverage. This result does not identify the cause of growth or adjust for inflation.

## 2. November was the largest complete sales month in both years

**Evidence:** November 2010 recorded **{money(peaks['2010']['GrossSalesGBP'])}** and November 2011 **{money(peaks['2011']['GrossSalesGBP'])}**. Each was the highest observed complete month within its respective year (12 complete months in 2010; 11 in 2011).

**Calculation:** Rank `MonthlyTrends.GrossSalesGBP` within each year after filtering `IsCompleteSourceMonth = 1`.

**Action:** Plan purchasing, warehouse capacity, and service coverage ahead of November, then review SKU-level demand and cancellation history before committing stock.

**Limit:** Two annual cycles suggest a planning hypothesis, not a validated forecast or proof of a seasonal cause. The completeness flag describes source date boundaries.

## 3. Sales were concentrated in the United Kingdom

**Evidence:** UK gross merchandise sales were **{money(uk['GrossSalesGBP'])}**, or **{pct(uk['GrossSalesGBP'], gross):.2f}%** of total gross merchandise sales. EIRE and the Netherlands followed at **£623,795.85** and **£549,775.06**.

**Calculation:** `UK gross / all-country gross × 100`. Evidence key: `CountryPerformance`; denominator **{money(gross)}**.

**Action:** Prioritize service reliability in the largest market. Evaluate non-UK markets using order size, shipping expense, and service requirements before proposing expansion.

**Limit:** Country sales are not profitability. Shipping costs and acquisition costs are absent; the source labels are not verified delivery destinations.

## 4. Frequent customers accounted for much of known-customer spending

**Evidence:** **{frequent['Customers']:,}** known customers placed 10 or more eligible orders. They represented **{pct(frequent['Customers'], behavior['KnownPurchasingCustomers']):.2f}%** of the **{behavior['KnownPurchasingCustomers']:,}** known purchasing customers and generated **{money(frequent['GrossPurchasesGBP'])}**, or **{pct(frequent['GrossPurchasesGBP'], behavior['KnownCustomerGrossSalesGBP']):.2f}%** of known-customer gross sales. Across all known purchasers, **{behavior['RepeatPurchasers']:,} ({behavior['RepeatPurchaserPct']:.2f}%)** purchased more than once.

**Calculation:** `PurchaseFrequency` 10+ band divided by `CustomerBehavior` known-customer totals. Sales denominator is **{money(behavior['KnownCustomerGrossSalesGBP'])}**, excluding anonymous sales.

**Action:** Review the needs of frequent purchasers and prioritize account service, product availability, and retention measurement for this group.

**Limit:** Counts reflect observed orders in this historical window. High spending does not establish profitability, and repeat purchasing is not proof of loyalty caused by a program.

## 5. Missing customer IDs limit customer analysis

**Evidence:** **{money(behavior['AnonymousGrossSalesGBP'])}**, or **{pct(behavior['AnonymousGrossSalesGBP'], gross):.2f}%** of gross merchandise sales, had no customer ID.

**Calculation:** `CustomerBehavior.AnonymousGrossSalesGBP / KPIs.GrossMerchandiseSalesGBP × 100`.

**Action:** Improve consistent customer-ID capture and monitor the identified-sales share in future reporting. Keep anonymous sales in financial totals while excluding them from distinct known-customer and RFM counts.

**Limit:** The unknown dimension member is a relationship placeholder, not one customer. The data cannot establish whether anonymous purchases belong to existing known customers.

## 6. RFM suggests different retention priorities

**Evidence:** In the fixed **10 December 2010–9 December 2011** purchase window, **{rfm_customers:,}** known customers generated **{money(rfm_sales)}**. The analyst-defined Champions segment contained **{champ['Customers']:,} customers ({pct(champ['Customers'], rfm_customers):.2f}%)** and **{money(champ['GrossPurchasesGBP'])} ({pct(champ['GrossPurchasesGBP'], rfm_sales):.2f}% of window sales)**. The At-risk high value segment contained **{risk['Customers']:,} customers** and **{money(risk['GrossPurchasesGBP'])}**; its average days since last purchase was **{risk['AverageRecencyDays']:.2f}**, compared with **{champ['AverageRecencyDays']:.2f}** for Champions.

**Calculation:** `RFMSegments` totals and segment shares; snapshot **10 December 2011**. Recency measures days since the last eligible purchase, frequency counts distinct eligible invoices, and monetary value sums gross purchases in the same window. Tie-aware percentile scores and prioritized segment rules are documented in the SQL guide.

**Action:** Propose service and retention attention for Champions and a separately measured reactivation experiment for high-value customers with older purchases. Evaluate response against a holdout before claiming an effect.

**Limit:** RFM labels are analyst heuristics, not validated churn predictions. This analysis is separate from the three dashboard pages. The historical customers are not a present-day outreach list.

## 7. Cancellations materially change the sales headline

**Evidence:** Merchandise cancellation value was **{money(k['CancellationValueGBP'])}**, equivalent to **{pct(k['CancellationValueGBP'], gross):.2f}%** of gross merchandise sales. Subtracting it gives **{money(k['NetMerchandiseTransactionValueGBP'])}** net merchandise transaction value.

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
'''
(ROOT / 'reports/business_insights.md').write_text(report, encoding='utf-8')
proof = {
    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'checks': 'PASS: net arithmetic, country gross, known-customer bands, RFM totals, both November peaks',
    'uk_gross_share_pct': str(pct(uk['GrossSalesGBP'], gross)),
    'frequent_known_customer_share_pct': str(pct(frequent['Customers'], behavior['KnownPurchasingCustomers'])),
    'frequent_known_sales_share_pct': str(pct(frequent['GrossPurchasesGBP'], behavior['KnownCustomerGrossSalesGBP'])),
    'anonymous_gross_share_pct': str(pct(behavior['AnonymousGrossSalesGBP'], gross)),
    'cancellation_value_ratio_pct': str(pct(k['CancellationValueGBP'], gross)),
    'champion_window_sales_share_pct': str(pct(champ['GrossPurchasesGBP'], rfm_sales)),
}
(ROOT / 'reports/business_insights_verification.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print('PASS: seven findings generated from executed SQL results and reconciled.')
