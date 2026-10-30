# Data provenance

- Dataset: Online Retail II (UCI dataset 502).
- Creator: Daqing Chen.
- Citation: Chen, D. (2012). Online Retail II [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5CG6D.
- Source: https://archive.ics.uci.edu/dataset/502/online+retail+ii
- License: https://creativecommons.org/licenses/by/4.0/ (CC BY 4.0).
- Source page checked: 31 October 2026.
- Local acquisition: user downloaded the workbook; copied unchanged from Downloads on 31 October 2026.
- Expected workbook name from source page: `online_retail_II.xlsx`.
- Size: 45,622,278 bytes.
- SHA-256: `bcbe73b35f5b7babf197fb0cb983a11f5d9ff929078d4aa53d171b1f2df2e980` (matches the downloaded original).
- Worksheets: `Year 2009-2010` (525,461 rows), `Year 2010-2011` (541,910 rows).
- Actual columns: Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country.
- Raw rows: 1,067,371 before overlap handling or cleaning. Detailed results: `reports/dataset_profile.json`.

Keep the original workbook in `raw/` without editing or resaving it. Do not combine overlapping source sheets until their dates and repeated records have been examined. Store later exports in `processed/`; record all transformations in SQL and documentation. Preserve sheet name and source row number when creating staging records so rejected or repeated records can be traced.

Workbook headers differ from UCI's standardized names. The verified mapping is in `docs/data_dictionary.md`. Reproduce the profile with `python scripts/profile_dataset.py` from the project root using Python 3.11+, pandas, and openpyxl. These are optional profiling dependencies, not requirements for running the eventual dashboard.

Do not treat missing customers as the same person. Do not replace missing identifiers with zero. Do not remove identical lines automatically: the source has no guaranteed unique invoice-line identifier, so identical lines need an explicit handling policy.
