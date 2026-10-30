# Phase 1: verified dataset profile

Profiled on 31 October 2026. The workbook is preserved unchanged in `data/raw/`. No records have been cleaned, discarded, or imported into SQL Server.

## File verification

- File: `online_retail_II.xlsx`, 45,622,278 bytes.
- SHA-256: `bcbe73b35f5b7babf197fb0cb983a11f5d9ff929078d4aa53d171b1f2df2e980`.
- Downloaded original and project copy have matching hashes. This identifies this snapshot, not independent authentication against UCI.
- Total: **1,067,371 raw rows, 8 columns**, matching UCI's published row count.
- Both sheets were read. Neither contains formula cells.

| Worksheet | Rows | First timestamp | Last timestamp | Within-sheet duplicate excess |
| --- | ---: | --- | --- | ---: |
| Year 2009-2010 | 525,461 | 2009-12-01 07:45:00 | 2010-12-09 20:01:00 | 6,865 |
| Year 2010-2011 | 541,910 | 2010-12-01 08:26:00 | 2011-12-09 12:50:00 | 5,268 |

The worksheets overlap on **1–9 December 2010**. Simply appending both would double-count some records. December 2011 is incomplete.

## Columns, types, and dates

Actual headers: Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country. See `docs/data_dictionary.md` for their mapping to UCI's names.

Invoice and StockCode mix numeric and text cells. Quantity is integer-valued. Price is numeric. Customer ID contains integers and blanks. Description includes four numeric cells alongside text and blanks. Preserve identifiers as text in SQL and review unusual descriptions.

All date cells decode as datetimes. Both worksheets use Excel display format `m/d/yy h:mm`. No month/day string parsing was needed. Overall coverage is **2009-12-01 07:45:00 through 2011-12-09 12:50:00**.

## Raw quality counts

| Diagnostic | Rows |
| --- | ---: |
| Missing Customer ID | 243,007 |
| Missing Description | 4,382 |
| Missing values in other columns | 0 |
| Whitespace-only cells | 0 |
| Negative quantities | 22,950 |
| Zero quantities | 0 |
| Zero prices | 6,202 |
| Negative prices | 5 |
| C-prefixed invoice lines | 19,494 |
| C-prefixed lines with nonnegative quantity | 1 |
| Negative quantity without C prefix | 3,457 |
| Invalid dates | 0 |

Diagnostics overlap; adding these counts does not give a valid exclusion total. Quantity ranges from -80,995 to 80,995. Price ranges from -53,594.36 to 38,970 GBP per unit. Review extremes before treating them as errors.

Raw distinct counts: 53,628 invoice identifiers, 5,942 nonmissing customer IDs, 5,305 stock codes, and 43 country labels. These are not counts of eligible purchases, active customers, or verified sovereign countries.

## Duplicate and relationship checks

- **34,335 excess exact duplicate rows** across all eight columns: the number that would be removed if each distinct source row were kept once. This does not prove every repeat is erroneous.
- **67,242 rows** belong to **32,907 duplicate groups**. Group membership differs from excess-row count.
- Within-sheet duplicate excess totals **12,133**. Combined excess is **22,202** higher due to records shared between worksheets. This is not the total number of lines in the overlapping dates.
- No invoice identifier maps to multiple customer values (including missing) or multiple country labels.
- **83 invoice identifiers have multiple timestamps.** Review these before defining an order date. Do not arbitrarily select a timestamp during a join.
- **1,232 stock codes have multiple nonmissing descriptions.** Description is not a stable product key.
- Unusual stock codes include POST, DOT, M, BANK CHARGES, and gift-prefixed codes. Code shape alone does not prove invalid merchandise. One stock code includes a trailing space.

## Recommended Phase 2 rules

1. Preserve both sheets in staging with source worksheet and Excel row number.
2. For the analysis timeline, use `Year 2009-2010` before 1 December 2010 and `Year 2010-2011` from 1 December 2010 onward. This assigns each date one authoritative worksheet. It is an analyst rule, not proof that one sheet is universally more accurate. Quantify excluded overlap rows and value in SQL.
3. Retain and flag repeated lines within that timeline initially. No unique source invoice-line key proves that identical lines are erroneous. Compare totals under deduplication as a sensitivity check before deciding whether to remove them.
4. Include anonymous eligible purchases in sales totals. Exclude missing customer IDs from RFM and known-customer analysis. Never combine anonymous purchases into one customer.
5. Classify cancellations, other negative-quantity adjustments, zero prices, negative prices, and administrative codes separately. Cancellation flags do not prove physical returns. Do not subtract signed cancellations twice.
6. Review special codes in a classification table. Do not reject every nonnumeric code. Document eligible merchandise and cancellations and reconcile their signed values to the canonical source population.
7. Choose product display descriptions with a documented deterministic rule while retaining source descriptions.
8. Compare matching complete months for YoY. Label annual coverage explicitly and align partial periods.
9. Profit and margin remain unavailable because costs are absent. Use country comparisons. Defer category visuals until a reviewed, explicitly analyst-created mapping exists.

## Reproduction and verification

Run `python scripts/profile_dataset.py` from the project root with Python 3.11+, pandas, and openpyxl installed. The script reads the source without editing it and writes `reports/dataset_profile.json`. The JSON includes observed cell types, date formats, monthly row counts, and special-code frequencies. Numeric dataframe identifiers can acquire a display-only `.0`; reported text lengths are diagnostics, not final SQL sizing.

Checks passed: sheet totals equal combined rows, monthly counts equal dated rows, all source dates decode, and original/copy hashes match.

**Phase 1 profiling is complete.** Recommended cleaning rules are ready for review. Phase 2 has not begun. Next, provide the **Server name** shown in your SSMS connection window and whether you use **Windows Authentication** or **SQL Server Authentication**. Do not share a password.
