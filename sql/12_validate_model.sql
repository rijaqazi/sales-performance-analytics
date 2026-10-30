/* Read-only Phase 2 exit checks. No customer identifiers are exported. */
USE SalesAnalyticsDB;
GO
SET NOCOUNT ON;
SELECT 'Staging rows' AS CheckName,COUNT_BIG(*) AS ActualValue,CONVERT(bigint,1067371) AS ExpectedValue FROM stg.RetailRaw
UNION ALL SELECT 'Canonical rows',COUNT_BIG(*),1044848 FROM clean.vw_RetailCanonical
UNION ALL SELECT 'Fact rows',COUNT_BIG(*),1044848 FROM dbo.FactSalesLine;

SELECT
    (SELECT SUM(SignedLineValueGBP) FROM clean.vw_RetailCanonical)
    -(SELECT SUM(SignedLineValueGBP) FROM dbo.FactSalesLine) AS FactValueDifferenceGBP,
    (SELECT COUNT_BIG(*) FROM clean.vw_RetailCanonical AS r
      LEFT JOIN dbo.FactSalesLine AS f ON f.SourceSheet=r.SourceSheet AND f.SourceRowNumber=r.SourceRowNumber
      WHERE f.SalesLineKey IS NULL) AS MissingSourceLines,
    (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.FactSalesLine')
      AND (is_disabled=1 OR is_not_trusted=1)) AS DisabledOrUntrustedForeignKeys;

SELECT 'DimDate' AS TableName,COUNT_BIG(*) AS RowsInTable FROM dbo.DimDate
UNION ALL SELECT 'DimProduct',COUNT_BIG(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimCustomer',COUNT_BIG(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimCountry',COUNT_BIG(*) FROM dbo.DimCountry;

SELECT LineStatus,COUNT_BIG(*) AS LinesInGroup,SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM dbo.FactSalesLine GROUP BY LineStatus ORDER BY LinesInGroup DESC;

-- Retained duplicate candidates; this is sensitivity analysis, NOT deduplication.
SELECT IsRepeatedLine,COUNT_BIG(*) AS LinesInGroup,SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM dbo.FactSalesLine GROUP BY IsRepeatedLine ORDER BY IsRepeatedLine;

-- Check calendar continuity across the full calendar-year dimension.
SELECT COUNT(*) AS CalendarRows,DATEDIFF(day,MIN(CalendarDate),MAX(CalendarDate))+1 AS ExpectedCalendarRows
FROM dbo.DimDate;
GO
