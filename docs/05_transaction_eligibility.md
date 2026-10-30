# First-version merchandise eligibility

## Verified classification checkpoint

The user's SSMS screenshot confirms 1,044,848 classified lines after the lookup join. Review contains 1,417 explicitly mapped ambiguous lines plus 30 unmapped lines = 1,447 lines. The screenshot shows 1,038,856 five-digit-prefix candidate lines and 141 explicitly mapped merchandise lines. These are line counts, not eligible purchase counts. Source signed values include adjustments and cancellations and must not yet be reported as cleaned revenue.

## Eligibility policy

`sql/10_define_transaction_eligibility.sql` creates a view with one status per canonical source line. It does not delete, deduplicate, or change monetary values.

For the first analytical version, merchandise scope combines explicitly mapped products with MerchandiseCandidate lines selected by the documented five-digit-prefix rule. This is an analyst assumption, not validation of every SKU's business purpose. Preserve ClassificationBasis for reporting and sensitivity checks. The line-purpose labels do not supply original merchandise categories.

Rules apply in this priority order:

1. Invalid parsed quantity, price, or timestamp: InvalidTypedValue.
2. Ambiguous or unmapped review code: ReviewCode.
3. Shipping, fee, discount, voucher, sample, adjustment, or test code: NonMerchandise. Original CodeType still explains the purpose.
4. Merchandise with price zero or below: NonPositivePrice, excluded from value KPIs but retained for reconciliation.
5. Merchandise with positive price, C-prefixed invoice, and negative quantity: MerchandiseCancellation. This does not prove a physical return.
6. Other C-prefixed merchandise lines with positive price: CancellationException.
7. Negative quantity without a C prefix on positive-price merchandise: OtherQuantityAdjustment. Do not silently call these customer returns.
8. Positive-quantity, positive-price, non-C merchandise: MerchandiseSale.
9. Remaining zero-quantity cases: QuantityException.

Missing descriptions do not by themselves invalidate a SKU. Missing customers do not exclude eligible sales; they will be excluded from known-customer and RFM measures. Duplicate-looking lines within the selected sheet remain. These choices must be disclosed alongside portfolio metrics.

## KPI contract for subsequent phases

- Gross merchandise sales: signed line value summed only for MerchandiseSale.
- Merchandise cancellation value: the positive magnitude of signed line values for MerchandiseCancellation.
- Net merchandise transaction value: gross merchandise sales plus signed MerchandiseCancellation values. Explicitly excludes other adjustments, separate discount lines, shipping, fees, vouchers, and unresolved lines. It is not audited net revenue.
- Purchase orders and AOV use MerchandiseSale lines and their distinct invoice identifiers; an invoice with only non-merchandise lines is not an eligible merchandise order.
- Product descriptions, costs, and accounting tax treatment are insufficient to calculate profit. Discount-adjusted revenue must not be claimed from this first-version scope.

The eligibility and model scripts were executed in SSMS. Verified: 1,044,848 rows on both sides and a zero value difference. Actual status totals appear in `reports/phase_2_verification.md`.
