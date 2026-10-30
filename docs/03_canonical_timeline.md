# Phase 2: typed canonical timeline

Staging import and validation are complete; executed results are recorded in the Phase 2 verification report. Before running this step, all seven raw checks must say PASS, and the overlap preview must show 1,044,848 kept rows and 22,523 excluded rows.

Run `sql/05_create_canonical_view.sql` in SSMS. It creates `clean.vw_RetailCanonical`, a saved query selecting the first worksheet before 1 December 2010 and the second worksheet from that date onward. It does not delete any staging data or remove repeated lines within a worksheet.

The view converts quantity to int, timestamp to datetime2(0), and price to decimal(19,4). Source profiling found at most three decimal places in price, so four places preserve the observed precision. Identifiers remain text. Anonymous customer IDs remain NULL. SignedLineValueGBP multiplies quantity by price with a decimal result rather than binary floating point.

The cancellation flag identifies invoice prefixes only. The signed line value includes source adjustments and special codes, so it must not yet be labeled cleaned sales revenue. Product and country text are preserved at this stage.

Expected verification row:

| CanonicalRows | FirstTimestamp | LastTimestamp | InvalidTypedRows |
| ---: | --- | --- | ---: |
| 1,044,848 | 2009-12-01 07:45:00 | 2011-12-09 12:50:00 | 0 |

Save or share this result before continuing. Classification, duplicate review, product display rules, dimension/fact tables, foreign keys, and reconciliations remain pending. This view is an intermediate typed timeline, not a completed clean model.

## Verified execution checkpoint

The user's SSMS result screenshot confirms all four expected values above. Canonical view creation and the row/date/type check are verified. Earlier staging checks were reported complete by the user; their result grids were not independently inspected.

Next run `sql/06_review_special_codes.sql`, which only reads data. It reports canonical quality counts, the number of distinct codes outside the typical five-digit prefix pattern, and up to 100 such code groups with an example description and signed source value. The example description is the lexicographically smallest nonmissing description, not a definitive product name. The code pattern is a review aid, not an eligibility rule. Inspect these results before designing merchandise, charge, adjustment, and review classifications.
