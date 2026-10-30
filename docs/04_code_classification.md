# Analyst-created stock code classification

The user's SSMS screenshot of canonical special-code totals shows shipping, discounts, fees, adjustments, vouchers, ambiguous manual entries, and product-like descriptions under nonstandard codes. A nonnumeric code is not automatically invalid merchandise.

`sql/07_create_code_classification.sql` creates a maintained lookup of 21 observed codes and the reason for each assignment. These are analytical interpretations based on example descriptions, not original source categories or verified accounting classifications. Existing rows are preserved on rerun. Stock codes use binary collation to retain case distinctions.

Initial decisions:

- POST, DOT, C2: Shipping.
- D: Discount.
- BANK CHARGES, AMAZONFEE, CRUK: Fee.
- ADJUST: Adjustment.
- S: Sample, tracked separately.
- TEST001: Test.
- M and PADS: Review. Their exact treatment is unresolved.
- DCGS0058, DCGSSGIRL, DCGSSBOY, DCGS0003, DCGS0076: provisional Merchandise based on the displayed product descriptions.
- gift_0001_10, gift_0001_20, gift_0001_30, gift_0001_50: Voucher, tracked separately. Actual redemption behavior is unknown; do not claim double counting occurred.

This table is a **line-purpose classification**, not the missing merchandise category hierarchy. It does not enable claims such as sales by Furniture versus Electronics. No raw or canonical lines are removed, and no source prices or quantities change.

Expected first-run code counts: Merchandise 5, Shipping 3, Fee 3, Voucher 4, Review 2, and one each for Discount, Adjustment, Sample, and Test. Total 21 codes. These are lookup rows, not counts of transaction lines.

After verifying the table, the next step will join classifications to canonical lines, quantify unmatched codes, and define purchase, cancellation, adjustment, and review populations. Do not compute cleaned revenue from the mapping alone. Negative quantities on non-C invoices need separate treatment, and the C-prefixed nonnegative exception must remain visible.

## Coverage checkpoint

The user reported executing the mapping step; its result grid has not been independently inspected. Run `sql/08_review_classification_coverage.sql`. It creates `clean.vw_RetailClassified` with a LEFT JOIN and checks that line count stays 1,044,848. An explicit mapping takes priority. Otherwise a five-digit prefix labels the line MerchandiseCandidate, not verified Merchandise; all other codes remain Review. ClassificationBasis makes the rule visible.

The grouped output includes signed source values for every purpose so excluded or unresolved populations do not disappear. These values are not yet cleaned revenue. The final query lists every Review code with an example description; no TOP limit hides unresolved code groups. Inspect candidate exceptions and review coverage before defining eligibility or building the final fact table.

## Second review: additional explicit codes

The user's Review-code screenshot supports 17 additional mappings prepared in `sql/09_extend_code_classification.sql`: B and ADJUST2 to Adjustment; TEST002 to Test; three gift voucher codes with visible voucher descriptions to Voucher; and eleven codes with product descriptions to provisional Merchandise. The script has been prepared, not independently verified as executed.

M and m remain separate ambiguous manual codes. PADS stays Review. Missing descriptions and descriptions such as ebay remain unresolved. DCGS0041 has a truncated displayed description and is not assigned from that screenshot. Unresolved codes should remain in reconciliation and be excluded from merchandise KPIs under an explicitly documented first-version eligibility policy rather than deleted from the source. Voucher purpose labels do not establish redemption behavior or accounting revenue recognition.
