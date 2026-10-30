# Phase 1: acquire and understand the dataset

**Update: acquisition and profiling are complete.** The instructions and pending-status table below describe the original setup workflow. Use [the verified Phase 1 report](../reports/phase_1_status.md) for current results and recommended cleaning rules. No further download is needed.

## Why this dataset

Online Retail II is real transaction data with product identifiers, quantities, prices, invoice timestamps, customer identifiers, and countries. Its longer history supports more useful year-over-year comparisons than a one-year extract. It also contains practical cleaning challenges rather than only polished example records.

Source: https://archive.ics.uci.edu/dataset/502/online+retail+ii

License: https://creativecommons.org/licenses/by/4.0/

## Download manually

1. Open the source page above in your browser.
2. Click **Download**. The source page lists a workbook of approximately 43.5 MB; the download may be a ZIP archive.
3. If a ZIP is downloaded, use Windows **Extract All**.
4. Place `online_retail_II.xlsx` in this project's `data/raw/` folder.
5. Keep the original unchanged. Do not convert only the first worksheet to CSV: we need to inspect every sheet first.
6. Tell me **“The workbook is in data/raw; verify Phase 1.”** I will inspect the actual file before creating the database scripts.

You do not need to install Python, open Excel, or import anything into SQL Server yet. The project tools can inspect the workbook once it is available here.

## What we will verify

| Check | Why it matters | Status |
| --- | --- | --- |
| File name, size, SHA-256 hash | Identifies the exact input used | Pending |
| Worksheets and rows per sheet | Prevents missing or double-counted records | Pending |
| Actual headers and storage types | Prevents an incorrect SQL import schema | Pending |
| Nulls and blank text in every column | Identifies missing information | Pending |
| Exact duplicate lines within and across sheets | Quantifies repeats before choosing a policy | Pending |
| Repeated invoices | Expected for invoice lines; not automatically duplicates | Pending |
| Earliest/latest timestamp and monthly coverage | Identifies incomplete periods | Pending |
| Excel date values versus text dates | Prevents month/day interpretation errors | Pending |
| C-prefixed invoices and negative quantities | Separates cancellations and adjustments | Pending |
| Zero/negative prices and unusual product codes | Separates normal merchandise from exceptions | Pending |
| Products with multiple descriptions | Helps design a stable product dimension | Pending |
| Invoice/customer/country consistency | Checks proposed order relationships | Pending |

The source date notation is day/month/year: 01/12/2009 means 1 December 2009. Actual Excel timestamps may be stored as numeric date serials with display formatting. We will inspect storage rather than assume the displayed format is text. Later exports should use unambiguous ISO timestamps such as `2009-12-01T07:45:00`; this is a format example, not a claimed source record.

## Scope decisions

- Currency is GBP according to UCI; use GBP labels in the report.
- Revenue is quantity multiplied by unit price, subject to a documented eligibility policy. It is a transaction-value measure, not audited financial revenue.
- No costs means no profit or profit-margin measure.
- No categories means no source-backed category chart. If we add a mapping later, document who assigned it, the rule, and unmapped coverage.
- Use country for geographic comparison. Do not invent sales territories or states.
- Use identified customers for RFM; report the excluded share of sales separately.
- Compare matching date coverage across years. A partial December cannot be compared fairly with a complete December.

## Phase 1 exit gate

Proceed to Phase 2 only after the workbook is profiled, the profiling report contains measured results, and we agree on cancellation, duplicate, non-merchandise, missing-customer, and category handling. At that checkpoint we will also identify the SQL Server instance name needed for your manual SSMS connection.
