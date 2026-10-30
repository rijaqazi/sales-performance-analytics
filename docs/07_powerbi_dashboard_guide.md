# Phase 4: Power BI report guide

## Current status

**Phase 4 is complete.** The project was opened, refreshed, and saved in Power BI Desktop. It contains five SQL import tables, four one-to-many relationships, 18 DAX measures, and three populated report pages. All 16 DAX checks passed. Year/country slicers were tested, display issues were corrected, and actual screenshots were saved. Details are in `reports/phase_4_verification.md`. The instructions below explain reproduction; the current report does not need rebuilding.

## Open and refresh

Open `powerbi/SalesAnalytics.pbip` with Power BI Desktop. Keep the accompanying SalesAnalytics.Report and SalesAnalytics.SemanticModel folders beside it. The project uses SQL Server `TELESTE\RIJA_101` and database `SalesAnalyticsDB` in Import mode. The SQL service must be running.

At the Windows credentials dialog, select **Use my current credentials**, then click **Connect** yourself. No password is required when your Windows login already has access. If a connection, certificate, or permission error appears, inspect the exact message before changing settings. Do not publish cached credentials or `.pbi` folders.

Use **Home → Refresh** for later refreshes. Source data is imported into the local model; the project definitions do not embed the raw workbook or hardcode KPI results.

To build the connection manually from a blank report:

1. Choose **Home → Get data → SQL Server**.
2. Enter the local instance and SalesAnalyticsDB; choose **Import**.
3. Authenticate with your Windows account.
4. Select only dbo.DimDate, dbo.DimProduct, dbo.DimCustomer, dbo.DimCountry, and dbo.FactSalesLine.
5. Load, then verify the relationships described below. Do not import staging as another reporting fact table.

## Model

| One side | Many side | Direction |
| --- | --- | --- |
| DimDate.DateKey | FactSalesLine.DateKey | Dimension to fact |
| DimProduct.ProductKey | FactSalesLine.ProductKey | Dimension to fact |
| DimCustomer.CustomerKey | FactSalesLine.CustomerKey | Dimension to fact |
| DimCountry.CountryKey | FactSalesLine.CountryKey | Dimension to fact |

Use active, single-direction relationships. Do not join dimensions directly to one another. DimDate is designated as a time table with CalendarDate as its unique date column. In a manual build, use **Table tools → Mark as date table → CalendarDate**. Turn off automatic date/time for this file when manually reproducing so hidden date tables do not compete with DimDate. The generated model does not add automatic date hierarchies.

Technical keys and provenance are hidden in the field list, but preserved in the model. The unknown customer member supports anonymous sales; customer measures exclude it.

## Measures

All measure definitions are in `powerbi/measures.dax` and the semantic model. In a manual build, create each with **Modeling → New measure**, selecting FactSalesLine as the home table. Apply GBP currency, whole-number, or percentage formatting as appropriate. File `measures.dax` is documentation of individual measure definitions, not a single executable DAX query.

Core examples:

```dax
Gross Sales =
CALCULATE(
    SUM(FactSalesLine[SignedLineValueGBP]),
    KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseSale")
)

Purchase Orders =
CALCULATE(
    DISTINCTCOUNT(FactSalesLine[InvoiceNumber]),
    KEEPFILTERS(FactSalesLine[LineStatus] = "MerchandiseSale")
)

Average Order Value = DIVIDE([Gross Sales], [Purchase Orders])
```

Gross Sales and Purchase Orders share the same purchase population. Cancellation Value is the positive magnitude of eligible cancellations. Net Merchandise Value subtracts it once. Repeat Purchasers counts known customers with at least two eligible purchase invoices in the current filter context. Anonymous Sales stays in total sales but does not create a known customer.

Comparable YoY Growth pairs selected complete-source dates with complete-source dates one year earlier and removes unmatched dates from both sides. With CalendarYear = 2011, it compares January–November 2011 to January–November 2010. When multiple years are selected, it compares the matched selected dates to their year-earlier dates; do not label that result a single calendar year's growth. It returns a ratio, formatted as a percentage.

Top 10 measures use TOPN with code/name tie-breakers and ALLSELECTED so ranking respects report selections. They return blank outside the selected top ten. These rankings are based on gross sales, not net sales or profit.

**Case-sensitive SKU display:** SQL keeps case-sensitive source codes distinct, while Power BI text grouping is case-insensitive. Power Query therefore creates ProductLabel: ordinary codes stay unchanged; codes colliding after uppercase conversion receive a source-variant suffix containing ProductKey. Use ProductLabel in product axes/tables so each SQL product identity remains distinct. StockCode and original source values remain available. This is a display disambiguation, not a claim that the variants represent the same product or new source-provided identifiers.

## Design

- Canvas: 1600 × 900, light background #F3F6FA.
- Primary teal #087F8C; heading navy #17324D.
- Secondary teal #38A99B; amber #E8AA42; muted text #7086A0.
- White chart/card panels with subtle borders and consistent spacing.
- Segoe UI typography and GBP units.

The reusable theme is `powerbi/sales-analytics-theme.json`. To apply manually, choose **View → Themes → Browse for themes** and select it.

## Page 1: Sales Performance Overview

1. Add a text box with the report title and a subtitle stating GBP, source period, and partial December 2011.
2. Add a **Slicer** with DimDate.CalendarYear and another with DimCountry.Country. Set dropdown style. These slicers filter the page's related visuals.
3. Add five **Card** visuals: Gross Sales, Net Merchandise Value, Purchase Orders, Average Order Value, Known Customers. Use clear titles and appropriate formats.
4. Add a **Line chart**: X-axis DimDate.YearMonth, Y-axis Gross Sales. Sort YearMonth ascending. Its YYYY-MM values sort chronologically without a separate month-name sort column.
5. Add a **Clustered bar chart**: category DimCountry.Country, value Top 10 Country Sales. Sort by that measure descending.
6. Add a **Table**: DimProduct.ProductLabel, DimProduct.ProductDescription, Top 10 Product Sales. Display ProductLabel as SKU and ProductDescription as Product. Sort descending by sales. Blank non-top-ten measures suppress other products.
7. Add cards for Repeat Purchaser Rate and Cancellation Value Rate. The latter is a value ratio, not an order-return rate.
8. Add a scope note explaining excluded non-merchandise lines and absent costs/categories.

## Page 2: Products and Markets

1. Repeat the year and country slicers. They are page-local; no synced selection is claimed unless configured and tested.
2. Add cards for Gross Sales, Purchase Orders, Average Order Value, and Cancellation Value.
3. Add a clustered bar chart with ProductLabel and Top 10 Product Sales.
4. Add a clustered bar chart with Country and Top 10 Country Sales.
5. Add a monthly table: YearMonth, Gross Sales, Cancellation Value, Net Merchandise Value, Comparable YoY Growth. Sort YearMonth ascending. Incomplete/unmatched comparisons remain blank.

## Page 3: Customers and Data Quality

1. Add the year/country slicers and cards for Known Customers, Repeat Purchasers, Repeat Purchaser Rate, Anonymous Sales, and Anonymous Sales Share.
2. Add a line chart with YearMonth and Known Customers. Counts are distinct within each month and must not be summed to obtain the all-period customer count.
3. Add a reconciliation table using FactSalesLine.LineStatus, Source Lines, and Signed Source Value. Keep the title explicit: these are transaction statuses, not product categories.
4. Add cards for Review Lines and Repeated Sale Value. Repeated lines are retained; this measure supports sensitivity review rather than asserting data errors.
5. Add source credit and notes explaining anonymous customers, retained repeats, and the separate fixed-window RFM analysis.

RFM remains a verified SQL analysis with a fixed historical window; the interactive customer page does not pretend to dynamically recalculate RFM segments. Profit and merchandise-category charts are not possible from this source without additional documented data.

## Verification before Phase 4 is complete

1. Refresh all five tables successfully.
2. Open **DAX Query view**, paste `powerbi/validate_measures.dax`, and run it. All 16 checks should show PASS against actual SQL controls. The suite includes distinct product labels, exactly ten visible ranked products, and their combined SQL sales value.
3. Confirm the overview totals match the SQL report with no slicer selections.
4. Select 2011 and verify the matched YoY ratio rounds to 2.89%; compare product/country filters to equivalent SQL.
5. Check top-ten ranking, clearing slicers, and customer behavior under filters. Verify no blank/error visuals or clipped labels.
6. Save the project, then capture actual screenshots of all three pages in `dashboard/screenshots/`.

The generated PBIP/PBIR files and measures are concrete project artifacts. Their presence alone is not proof that data refresh or visual checks passed.

For this delivered snapshot, native refresh and checks were actually performed. Screenshots are `dashboard/screenshots/01_sales_overview.png`, `02_products_and_markets.png`, and `03_customers_and_data_quality.png`. Tables and charts may use scrollbars to show all ranked rows or monthly history. Slicers are page-local rather than synchronized across pages. The delivered opening page is the unfiltered overview.

Use the already saved project for normal work. `scripts/build_powerbi_project.py` is an optional definition-regeneration tool for a fresh clone without a native cache. It uses the project's existing report resources if the original temporary native scaffold is unavailable. Regeneration resets authored layout/measure definitions and requires refresh and QA again; it is not a data-refresh command.

## Microsoft references

- SQL Server connector: https://learn.microsoft.com/en-us/power-query/connectors/sql-server
- Power BI project files: https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview
- Supported PBIR report editing: https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report
- Semantic model formats: https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset
