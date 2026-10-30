/* Phase 2 checkpoint: read-only. Run the WHOLE file after import.
   Expected values refer to the original raw population, before cleaning.
   TRY_CONVERT exposes invalid values without crashing the diagnostic query.
   No CSV parsing failures should be accepted just because import completed. */
USE SalesAnalyticsDB;
GO
SET NOCOUNT ON;

;WITH Parsed AS
(
    SELECT *,
        TRY_CONVERT(int, NULLIF(QuantityRaw, N'')) AS Quantity,
        TRY_CONVERT(decimal(19,4), NULLIF(UnitPriceRaw, N'')) AS UnitPrice,
        TRY_CONVERT(datetime2(0), NULLIF(InvoiceDateRaw, N''), 126) AS InvoiceDate
    FROM stg.RetailRaw
), Observed AS
(
    SELECT COUNT_BIG(*) AS RawRows,
        SUM(CONVERT(bigint, CASE WHEN NULLIF(CustomerIDRaw,N'') IS NULL THEN 1 ELSE 0 END)) AS MissingCustomers,
        SUM(CONVERT(bigint, CASE WHEN NULLIF(DescriptionRaw,N'') IS NULL THEN 1 ELSE 0 END)) AS MissingDescriptions,
        SUM(CONVERT(bigint, CASE WHEN Quantity < 0 THEN 1 ELSE 0 END)) AS NegativeQuantities,
        SUM(CONVERT(bigint, CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END)) AS ZeroPrices,
        SUM(CONVERT(bigint, CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END)) AS NegativePrices,
        SUM(CONVERT(bigint, CASE WHEN Quantity IS NULL OR UnitPrice IS NULL OR InvoiceDate IS NULL THEN 1 ELSE 0 END)) AS InvalidTypedRows
    FROM Parsed
)
SELECT checks.CheckName, checks.ExpectedValue, checks.ActualValue,
    CASE WHEN checks.ActualValue = checks.ExpectedValue THEN 'PASS' ELSE 'FAIL' END AS Result
FROM Observed
CROSS APPLY (VALUES
    ('Raw rows', CONVERT(bigint,1067371), RawRows),
    ('Missing customers', CONVERT(bigint,243007), MissingCustomers),
    ('Missing descriptions', CONVERT(bigint,4382), MissingDescriptions),
    ('Negative quantities', CONVERT(bigint,22950), NegativeQuantities),
    ('Zero prices', CONVERT(bigint,6202), ZeroPrices),
    ('Negative prices', CONVERT(bigint,5), NegativePrices),
    ('Invalid typed rows', CONVERT(bigint,0), InvalidTypedRows)
) checks(CheckName, ExpectedValue, ActualValue);

-- Per-sheet control totals and timestamp boundaries.
SELECT SourceSheet, COUNT_BIG(*) AS RawRows,
    MIN(TRY_CONVERT(datetime2(0), InvoiceDateRaw,126)) AS FirstTimestamp,
    MAX(TRY_CONVERT(datetime2(0), InvoiceDateRaw,126)) AS LastTimestamp,
    MIN(SourceRowNumber) AS FirstExcelRow, MAX(SourceRowNumber) AS LastExcelRow
FROM stg.RetailRaw
GROUP BY SourceSheet ORDER BY SourceSheet;

-- Review malformed records, if any. Expected: no rows.
SELECT TOP (20) * FROM stg.RetailRaw
WHERE TRY_CONVERT(int, NULLIF(QuantityRaw,N'')) IS NULL
   OR TRY_CONVERT(decimal(19,4), NULLIF(UnitPriceRaw,N'')) IS NULL
   OR TRY_CONVERT(datetime2(0), NULLIF(InvoiceDateRaw,N''),126) IS NULL;

-- Date-partition rule preview only. Raw staging is not changed.
;WITH Timeline AS
(
    SELECT *, CASE
        WHEN SourceSheet = N'Year 2009-2010'
             AND TRY_CONVERT(datetime2(0), InvoiceDateRaw,126) < CONVERT(datetime2(0),'2010-12-01T00:00:00',126) THEN 1
        WHEN SourceSheet = N'Year 2010-2011'
             AND TRY_CONVERT(datetime2(0), InvoiceDateRaw,126) >= CONVERT(datetime2(0),'2010-12-01T00:00:00',126) THEN 1
        ELSE 0 END AS IsCanonical
    FROM stg.RetailRaw
)
SELECT IsCanonical, COUNT_BIG(*) AS RowsInGroup,
    SUM(CONVERT(decimal(19,4), TRY_CONVERT(int, QuantityRaw))
        * TRY_CONVERT(decimal(19,4), UnitPriceRaw)) AS SignedSourceValueGBP
FROM Timeline GROUP BY IsCanonical ORDER BY IsCanonical DESC;
GO
