# Metric definitions

Phase 3 definitions have been executed and validated. Actual results are in `reports/sql_analysis_results.json` and the readable Phase 3 report. Merchandise eligibility follows `docs/05_transaction_eligibility.md`; candidate code rules and retained repeated lines remain explicit assumptions.

| Metric | Implemented definition | Important qualification |
| --- | --- | --- |
| Line value (GBP) | Quantity × unit price | Preserve signed source value for reconciliation |
| Gross merchandise sales (GBP) | Sum SignedLineValueGBP for MerchandiseSale | Excludes cancellations, separate discounts, and non-merchandise lines |
| Merchandise cancellation value (GBP) | Negative of the signed sum for MerchandiseCancellation | C-prefix is not proof of physical return; do not subtract twice |
| Net merchandise transaction value (GBP) | Gross merchandise sales plus signed MerchandiseCancellation values | Excludes other adjustments and separate discounts; not audited accounting net revenue |
| Purchase orders | Distinct eligible purchase invoice identifiers | Canonical worksheet overlap already removed; line count is not order count |
| Average order value (GBP) | Gross sales / sales orders | Numerator and denominator use the same eligible purchase population |
| Purchasing customers | Distinct nonblank customer IDs on eligible purchases | Anonymous orders remain in sales totals but not known-customer counts |
| Repeat purchaser share | Known customers with at least two distinct purchase orders / known purchasing customers | Depends on selected observation window |
| YoY sales growth | (Current comparable-period sales − prior comparable-period sales) / prior comparable-period sales | Undefined when prior value is zero or missing; match coverage |
| RFM recency | Days from most recent eligible purchase line date in window to 2011-12-10 | Window is 2010-12-10 inclusive to 2011-12-10 exclusive; never uses today's date |
| RFM frequency | Distinct eligible purchase invoices in that window per known customer | Count orders, not invoice lines |
| RFM monetary value | Gross eligible merchandise purchase value in that window per known customer | Does not subtract cancellations; anonymous customers excluded |

Profit and margin are unavailable because costs are absent. Category totals require a separately documented merchandise-category mapping. RFM uses tie-aware percentiles and documented segment rules in `docs/06_sql_analysis_guide.md`; these are analyst labels, not source facts. All-history customer behavior and trailing-year RFM use different observation windows and therefore have different customer counts.

Order-level dates use the first eligible purchase timestamp per invoice. Sales trends retain line timestamps. Actual SQL checks found no eligible purchase invoice spanning dates or months in this snapshot. Percentages in saved SQL JSON use 0–100 units; Power BI percentage measures should use ratios (0–1) and percentage formatting.
