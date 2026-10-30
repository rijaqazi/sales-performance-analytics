/* Phase 2: typed canonical timeline, before merchandise eligibility rules.
   A view stores a query; it does not delete staging rows or copy a new table.
   Prerequisite: all seven checks in 04_validate_staging.sql must PASS and the
   overlap preview must show 1,044,848 kept / 22,523 excluded source rows.
   TRY_CONVERT returns NULL for an invalid value so later validation can expose it.
   Cancellation flags are source indicators, not proof of physical returns.
   Known-customer IDs remain text; anonymous IDs remain NULL.
   No within-sheet deduplication, special-code exclusion, or price filtering occurs.
*/
USE SalesAnalyticsDB;
GO
IF SCHEMA_ID(N'clean') IS NULL
    EXEC(N'CREATE SCHEMA clean AUTHORIZATION dbo;');
GO
CREATE OR ALTER VIEW clean.vw_RetailCanonical
AS
SELECT
    SourceSheet,
    SourceRowNumber,
    InvoiceRaw AS InvoiceNumber,
    StockCodeRaw AS StockCode,
    DescriptionRaw AS ProductDescription,
    TRY_CONVERT(int, NULLIF(QuantityRaw, N'')) AS Quantity,
    TRY_CONVERT(datetime2(0), NULLIF(InvoiceDateRaw, N''), 126) AS InvoiceDate,
    TRY_CONVERT(decimal(19,4), NULLIF(UnitPriceRaw, N'')) AS UnitPrice,
    NULLIF(CustomerIDRaw, N'') AS CustomerID,
    CountryRaw AS Country,
    CONVERT(bit, CASE WHEN UPPER(LEFT(InvoiceRaw, 1)) = N'C'
        THEN 1 ELSE 0 END) AS IsCancellation,
    CONVERT(decimal(29,4),
        CONVERT(decimal(10,0), TRY_CONVERT(int, NULLIF(QuantityRaw, N'')))
        * TRY_CONVERT(decimal(19,4), NULLIF(UnitPriceRaw, N''))
    ) AS SignedLineValueGBP
FROM stg.RetailRaw
WHERE
    (SourceSheet = N'Year 2009-2010'
        AND TRY_CONVERT(datetime2(0), InvoiceDateRaw, 126) < '20101201')
    OR
    (SourceSheet = N'Year 2010-2011'
        AND TRY_CONVERT(datetime2(0), InvoiceDateRaw, 126) >= '20101201');
GO
SELECT
    COUNT_BIG(*) AS CanonicalRows,
    MIN(InvoiceDate) AS FirstTimestamp,
    MAX(InvoiceDate) AS LastTimestamp,
    SUM(CASE WHEN Quantity IS NULL OR UnitPrice IS NULL
        OR InvoiceDate IS NULL THEN 1 ELSE 0 END) AS InvalidTypedRows
FROM clean.vw_RetailCanonical;
-- Expected: 1044848, 2009-12-01 07:45:00, 2011-12-09 12:50:00, 0.
-- SignedLineValueGBP is source transaction value, NOT yet eligible revenue.
GO
