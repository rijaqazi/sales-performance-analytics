# Phase 3: verified SQL analysis

Executed in SQL Server through the connected SSMS session on 31 October 2026. The actual result is saved in `sql_analysis_results.json`. No permanent tables were changed.

Source coverage: **2009-12-01 to 2011-12-09**. Currency: GBP. Repeated-line candidates remain included, and merchandise includes the documented provisional code-pattern rule.

## KPI results

| Metric | Verified value |
| --- | ---: |
| Gross merchandise sales | £19,700,949.38 |
| Merchandise cancellation value | £719,656.34 |
| Net merchandise transaction value | £18,981,293.04 |
| Eligible purchase orders | 39,516 |
| Average order value | £498.56 |
| Known purchasing customers | 5,852 |
| Repeat known purchasers | 4,234 (72.35%) |
| Profit / profit margin | Unavailable: costs absent |

Net merchandise transaction value excludes separate discounts, shipping, fees, vouchers, and unresolved lines. It is not audited accounting revenue. Category analysis is unavailable because the source has no merchandise-category hierarchy.

## Comparable-period growth

**2011-01-01–2011-11-30** gross sales: £8,878,008.02. Matching prior period **2010-01-01–2010-11-30**: £8,628,413.35. Growth: **2.89%**.

Monthly YoY is unavailable where comparable complete-source months are absent. December 2011 is partial.

## Top ten products by gross merchandise sales

| Rank | Stock code | Product display description | Gross sales (GBP) |
| ---: | --- | --- | ---: |
| 1 | 22423 | REGENCY CAKESTAND 3 TIER | 331,084.27 |
| 2 | 85123A | CREAM HANGING HEART T-LIGHT HOLDER | 258,065.91 |
| 3 | 85099B | JUMBO BAG RED RETROSPOT | 180,888.03 |
| 4 | 23843 | PAPER CRAFT , LITTLE BIRDIE | 168,469.60 |
| 5 | 47566 | PARTY BUNTING | 148,395.98 |
| 6 | 84879 | ASSORTED COLOUR BIRD ORNAMENT | 129,681.08 |
| 7 | 22086 | PAPER CHAIN KIT 50'S CHRISTMAS  | 117,884.19 |
| 8 | 23166 | MEDIUM CERAMIC TOP STORAGE JAR | 81,700.92 |
| 9 | 79321 | CHILLI LIGHTS | 80,873.23 |
| 10 | 22197 | POPCORN HOLDER | 79,552.50 |

## Leading country labels

| Country | Gross merchandise sales (GBP) | Eligible orders |
| --- | ---: | ---: |
| United Kingdom | 16,856,325.88 | 36,184 |
| EIRE | 623,795.85 | 581 |
| Netherlands | 549,775.06 | 216 |
| Germany | 383,847.67 | 753 |
| France | 311,288.38 | 598 |

All source country labels are in the JSON. These are customer-country comparisons, not verified delivery regions.

## RFM customer segments

Window: **2010-12-10 inclusive to 2011-12-10 exclusive**. Snapshot: **2011-12-10**. Known customers included: **4,261**.

| Segment | Customers | Window gross purchases (GBP) |
| --- | ---: | ---: |
| Champions | 857 | 5,290,620.82 |
| Loyal | 706 | 1,189,969.72 |
| At-risk high value | 407 | 858,916.39 |
| Dormant | 1,302 | 443,106.79 |
| Recent occasional | 499 | 410,461.84 |
| Potential | 490 | 258,467.34 |

Segments are exploratory, analyst-defined labels, not validated churn or profitability predictions. Scores keep ties together; groups are not guaranteed equal size. Anonymous customers and customers without a purchase in this window are excluded. Scoring details are in `docs/06_sql_analysis_guide.md`.

## Validation

All SQL order/month/RFM reconciliations passed. No eligible purchase invoice spans calendar dates or months in this snapshot. This validates the first-purchase-date convention for monthly order counts.

Repeated eligible sale-line candidates contribute **£57,092.82** to gross sales. This is a sensitivity amount, not proof of overstatement.

All 15 saved-result checks passed using independent Decimal arithmetic:

- Monthly gross equals total.
- Yearly gross equals total.
- Country gross equals total.
- Country net equals total.
- Known plus anonymous equals gross.
- Customer bands reconcile counts.
- Customer bands reconcile value.
- RFM segments reconcile counts.
- RFM segments reconcile value.
- Gross minus cancellations equals net.
- AOV agrees within displayed precision.
- Monthly order counts reconcile.
- Profit and margin are unavailable.
- SQL reconciliations pass.
- Top products are ranked descending.

## Next phase

Build the Power BI semantic model, DAX measures, visuals, and reconciliation against these SQL controls. No Power BI report or screenshots are claimed complete.
