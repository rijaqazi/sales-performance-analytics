# Data dictionary

Workbook headers and source value types are verified. Staging preserves text source values and row provenance. The implemented model is documented below; executable definitions in SQL script 11 are authoritative.

| Actual header | UCI name | Observed populated cell values | Missing raw rows |
| --- | --- | --- | ---: |
| Invoice | InvoiceNo | Integer or text | 0 |
| StockCode | StockCode | Integer or text | 0 |
| Description | Description | Text and 4 integer-valued cells | 4,382 |
| Quantity | Quantity | Integer | 0 |
| InvoiceDate | InvoiceDate | Excel date/time, decoded as datetime | 0 |
| Price | UnitPrice | Numeric | 0 |
| Customer ID | CustomerID | Integer | 243,007 |
| Country | Country | Text | 0 |

Both worksheets have the same headers. All dates decode successfully. Their Excel display format is `m/d/yy h:mm`; they are not day/month text strings. When exporting customer identifiers, avoid artificial `.0` suffixes caused by dataframe numeric representations. Observed types and missing counts above precede overlap treatment or cleaning.

| UCI field name | Meaning | Implemented clean SQL Server type | Handling |
| --- | --- | --- | --- |
| InvoiceNo | Invoice identifier; C prefix indicates cancellation | nvarchar(30) | Text preserves cancellation prefixes; repeats across invoice lines are expected |
| StockCode | Product/item identifier | nvarchar(30) | Preserve letters and leading zeros; inspect special codes |
| Description | Product description | nvarchar(500) | Missing descriptions possible; do not use as a product key |
| Quantity | Units on the invoice line | int | Validate numeric range; negative values need classification |
| InvoiceDate | Transaction date and time | datetime2(0) | Preserve time; verify source precision and parsing |
| UnitPrice | Price per unit in GBP | decimal(19,4) | Check source scale, zero, and negative values |
| CustomerID | Customer identifier | nvarchar(30) | Preserve as an identifier; null is not a known customer |
| Country | Customer's country | nvarchar(100) | Country comparison, not a verified shipping location |

Source: https://archive.ics.uci.edu/dataset/502/online+retail+ii

There is no source-provided unique invoice-line key, cost, profit, category, or subnational region. SQL uses InvoiceNumber for InvoiceNo, ProductDescription for Description, and UnitPrice for Price. These are renames, not additional source attributes.

## Implemented SQL model

| Table | Columns and SQL types | Meaning |
| --- | --- | --- |
| DimDate | DateKey int PK; CalendarDate date unique; CalendarYear smallint; MonthNumber tinyint; YearMonth char(7); MonthStart date; IsCompleteSourceMonth bit | Full 2009–2011 calendar; DateKey is YYYYMMDD. Completeness concerns observed source boundaries. |
| DimProduct | ProductKey int identity PK; StockCode nvarchar(30) unique, binary collation; ProductDescription nvarchar(500) nullable | Case-sensitive SKU; trailing spaces trimmed in the dimension. Latest nonblank description is the display label. |
| DimCustomer | CustomerKey int identity PK; CustomerID nvarchar(30) unique nullable; IsUnknown bit | Known source IDs and one NULL placeholder. The placeholder is not one real customer. |
| DimCountry | CountryKey int identity PK; Country nvarchar(100) unique | Source customer-country label. |
| FactSalesLine | SalesLineKey int identity PK; SourceSheet nvarchar(30); SourceRowNumber int | One canonical source line; sheet/row pair is unique and references staging. |
| FactSalesLine | DateKey, ProductKey, CustomerKey, CountryKey: int FK | Four dimension relationships. |
| FactSalesLine | InvoiceNumber nvarchar(30); InvoiceDate datetime2(0); Quantity int; UnitPrice decimal(19,4) | Source transaction identifiers, timestamp, units, and GBP unit price. |
| FactSalesLine | SignedLineValueGBP decimal(29,4) | Quantity × unit price; enforced by a CHECK constraint. Negative values are retained. |
| FactSalesLine | IsCancellation bit; CodeType varchar(30); ClassificationBasis varchar(30); LineStatus varchar(30); IsRepeatedLine bit | Derived audit fields, defined below. |

Fact fields are NOT NULL; the two explicitly nullable dimension attributes are identified above. See [model and constraints](database_model.md) and [SQL DDL](../sql/11_build_star_model.sql).

## Derived fields

- **IsCancellation:** cancellation-prefix diagnostic; not proof of a physical return.
- **CodeType:** analyst purpose classification, such as Merchandise, MerchandiseCandidate, Shipping, Fee, or Review. This is not a merchandise category hierarchy.
- **ClassificationBasis:** explicit lookup mapping, provisional five-digit-prefix rule, or unmapped code. See classification guides and SQL scripts 07–10.
- **LineStatus:** eligibility/review outcome. Actual loaded populations are MerchandiseSale, MerchandiseCancellation, NonPositivePrice, NonMerchandise, and ReviewCode. The schema also permits documented exception statuses.
- **IsRepeatedLine:** marks repetitions after the first matching canonical line. These records are retained; the flag does not prove erroneous duplication.
- **Power BI ProductLabel:** display-only field derived in Power Query. Case-colliding SKU labels receive a ProductKey suffix to preserve separate identities in Power BI's text comparisons. It is not a new source SKU or category.
- **RFM fields:** recency in days at 10 December 2011, frequency as distinct eligible orders, and monetary value as gross purchases in the fixed preceding one-year window; scores and segments are analyst-derived SQL outputs, not source columns.

Measure formulas, populations, and cancellation treatment are in [metric definitions](metric_definitions.md). Descriptive dimension counts include exception records and must not be substituted for purchasing-customer counts.
