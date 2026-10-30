/* Read-only Phase 2 review. A code pattern is a review aid, not a classification.
   Do not delete these rows or label their values merchandise revenue automatically.
   TOP (100) limits the displayed code groups; the query reports total distinct
   review codes separately so truncation is visible.
   Counts refer to the canonical timeline, not both raw worksheets combined. */
USE SalesAnalyticsDB;
GO
SELECT
    COUNT_BIG(*) AS CanonicalRows,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS NegativeQuantityRows,
    SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS ZeroPriceRows,
    SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END) AS NegativePriceRows,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS MissingCustomerRows
FROM clean.vw_RetailCanonical;

-- Typical stock codes start with five digits; inspect exceptions, not reject them.
SELECT COUNT(DISTINCT StockCode) AS DistinctCodesToReview
FROM clean.vw_RetailCanonical
WHERE StockCode COLLATE Latin1_General_100_BIN2
    NOT LIKE N'[0-9][0-9][0-9][0-9][0-9]%';

SELECT TOP (100)
    StockCode,
    MIN(CONVERT(nvarchar(500), ProductDescription)) AS ExampleDescription,
    COUNT_BIG(*) AS LinesInGroup,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS NegativeQuantityRows,
    SUM(CASE WHEN IsCancellation = 1 THEN 1 ELSE 0 END) AS CancellationRows,
    SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM clean.vw_RetailCanonical
WHERE StockCode COLLATE Latin1_General_100_BIN2
    NOT LIKE N'[0-9][0-9][0-9][0-9][0-9]%'
GROUP BY StockCode
ORDER BY LinesInGroup DESC, StockCode;
GO
