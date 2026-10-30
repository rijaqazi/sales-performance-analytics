# Project checklist

## Phase 1: dataset

- [x] Check workspace for existing project files.
- [x] Verify an official dataset source and license.
- [x] Prepare folders, source notes, preliminary dictionary, and acquisition guide.
- [x] Obtain original workbook.
- [x] Record checksum and profile all sheets.
- [x] Review measured quality results and define the documented first-version analytical scope; remaining ambiguities are retained under Review.

## Phase 2: database

- [x] Identify local SQL Server instance and authentication method without storing credentials (verified by user screenshot; no credentials saved).
- [x] Prepare database creation, staging schema, CSV import, and raw validation scripts (00–04).
- [x] Document the planned relational model and its keys; implementation follows verified staging import.
- [x] Create SalesAnalyticsDB scripts, staging import instructions, keys, and relationships.
- [x] Create reproducible cleaning, non-destructive exception/review, and validation scripts.
- [x] Execute in SSMS and reconcile source, staging, exclusions, and canonical fact totals.

## Phase 3: SQL

- [x] Add commented T-SQL for supported requirements, including CTEs, joins, grouping, CASE, subqueries, and window functions.
- [x] Explain unavailable profit and category analysis; no fictional enrichment added.
- [x] Verify executed query outputs and metric definitions; all SQL reconciliations and 15 saved-result checks pass.

## Phase 4: Power BI

- [x] Prepare SQL import connections, star relationships, date-table metadata, and 18 DAX measures; native opening, refresh, and DAX results are verified.
- [x] Provide a professional palette and step-by-step instructions for three pages, visuals, and slicers.
- [x] Build, refresh, and save the report in Power BI Desktop using Windows authentication.
- [x] Reconcile 16 DAX controls and year/country filter behavior against SQL; review all three pages and save actual screenshots.

## Phase 5: business insights

- [x] Document at least five measured findings with period, denominator, query reference, and practical action.
- [x] Review evidence and limitations.

## Phase 6: portfolio

- [x] Finalize README, dictionary, report screenshots, and business insights report.
- [x] Prepare publication instructions and review local deliverables.
- [ ] User publishes to GitHub and verifies the public repository; external publication remains pending.
