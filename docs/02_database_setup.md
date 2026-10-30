# Phase 2: database setup and verified staging import

Your SSMS screenshot confirms a connection to a local named instance using Windows Authentication. Its 17.x engine version corresponds to SQL Server 2025. The project SQL uses SQL Server 2022-compatible features.

**Status update:** Phase 2 has been executed and verified in SSMS, including the relational model. See `reports/phase_2_verification.md` for actual results and `docs/database_model.md` for implemented relationships. The instructions below are retained for reproduction; no rerun is needed on the current populated database.

## What the layers mean

- **Raw workbook:** original evidence, never edited.
- **Staging table:** both worksheets preserved as text with their worksheet and Excel row number. Text avoids silently losing alphanumeric identifiers or rejecting cancellations.
- **Clean model:** typed, classified records and related tables, built after staging is verified.
- **Power BI model:** report-friendly tables and measures, built in Phase 4.

## Step 1: confirm the connection

In SSMS select the connected server. Use **File → Open → File** (Ctrl+O), open `sql/00_check_connection.sql`, then click **Execute** or press F5. The query should identify your intended local instance. It only reads connection metadata. You do not need SQL Server Agent for these scripts.

## Step 2: create the database

Open `sql/01_create_database.sql` and press F5. It creates `SalesAnalyticsDB` if missing. The result should show `SalesAnalyticsDB` in the DatabaseName column. Right-click **Databases → Refresh** to see it in Object Explorer. Creating a database does not automatically make the toolbar switch databases; each project file explicitly uses `USE SalesAnalyticsDB`.

## Step 3: create the staging table

Open `sql/02_create_staging.sql` and execute it. First-run expected result: **ExistingStagingRows = 0**.

The primary key is `(SourceSheet, SourceRowNumber)`. It identifies a source record, even when invoice/product/value fields are repeated. CHECK constraints allow only the two known sheets and Excel row numbers from 2 onward. Quantity, price, and dates stay text until conversion is validated. No condition rejects negative source quantities.

## Step 4: import the prepared CSV

The project includes `data/processed/retail_staging.csv`, exported from both worksheets with:

- 1 header row and 1,067,371 data records.
- 10 columns: source sheet, source row number, then the 8 source values.
- UTF-8 encoding, comma delimiter, double-quote CSV escaping, LF record endings.
- ISO timestamps, preserved source descriptions, and customer IDs without an artificial `.0` suffix.
- No overlap removal, deduplication, or business cleaning.

The export is checked by parsing the complete CSV back into records. See `reports/import_manifest.json` for the hash and controls. The raw workbook remains unchanged. To regenerate the export, run `python scripts/export_staging_csv.py` with Python 3.11+ and openpyxl installed; regeneration is not necessary for your first import.

Open `sql/03_import_staging.sql`. Its file path points to the CSV in this workspace. Execute it. Allow the import to finish. Expected result: **ImportedRows = 1067371**. This can take several minutes.

The import uses a transaction and checks both worksheet counts. If import or counts fail, it rolls back. It refuses to run against a nonempty table to prevent accidental double loading. Do not delete rows or weaken constraints to bypass an error.

### If the file cannot be opened

SQL Server reads the path, not SSMS. For this local server, both apps are on your computer, but Windows file permissions can still block the SQL service or Windows login from reading the file. If error 4861 or an access-denied message appears, share the exact message. We can choose a readable local import directory and change the path. Do not grant broad access to your entire user folder.

If you receive a BULK INSERT permission error, share the error. Do not switch accounts or grant administrator rights without diagnosing it.

The Excel Import Wizard is not required. Using a prepared CSV avoids extra Excel driver requirements and mixed-type inference problems.

## Step 5: verify staging

Execute `sql/04_validate_staging.sql`. Every row in its first result table should say **PASS**. Check worksheet totals of **525,461** and **541,910**, and confirm the malformed-record result is empty. The last table should show **1,044,848 rows with IsCanonical = 1** and **22,523 rows with IsCanonical = 0**, matching the independently calculated export manifest. It previews the date-partition rule and signed source value; this is not cleaned revenue. The 22,523 date-partition exclusions differ from the 22,202 cross-sheet duplicate excess: one counts every excluded date-overlap line, the other counts exact repeated values.

All seven raw checks were subsequently executed in SSMS and showed PASS. The timeline counts and signed values were also verified. If reproducing the project and any check fails, stop and investigate before the model build.

## Planned relational model after this checkpoint

| Table | Key and relationships | Purpose |
| --- | --- | --- |
| stg.RetailRaw | Composite primary key: source sheet + row number | Original import evidence |
| dbo.DimProduct | ProductKey primary key; unique StockCode | Stable product identity and documented display description |
| dbo.DimCustomer | CustomerKey primary key; unique known CustomerID | Known-customer analysis; one unknown member for anonymous sales, excluded from RFM |
| dbo.DimCountry | CountryKey primary key; unique source country label | Country-level comparisons without inventing territories |
| dbo.DimDate | DateKey primary key; unique calendar date | Continuous calendar and time comparisons |
| dbo.FactSalesLine | SalesLineKey primary key; foreign keys to dimensions; unique source sheet + row number | Typed canonical lines, classification, signed line value, original invoice and timestamp |

Product/country keys will be enforced with foreign keys. The fact grain is one canonical source line, not one invoice. Dates relate from DimDate to a line's transaction date. Country belongs to the transaction so a customer dimension does not incorrectly force a fixed country. No direct product-to-customer relationship is needed.

Cleaning will implement the documented date partition, preserve and flag within-sheet duplicate lines, classify special codes and adjustments, and reconcile canonical and excluded values. The 83 invoices with multiple timestamps will be reviewed before deciding whether an order-header table is warranted. No category or cost field will be invented.

## References

- SQL Server version: https://learn.microsoft.com/en-us/sql/sql-server/sql-server-2025-release-notes?view=sql-server-ver17
- CSV import syntax and permissions: https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql
