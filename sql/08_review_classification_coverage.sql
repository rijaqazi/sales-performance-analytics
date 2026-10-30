/* Phase 2: enrich canonical lines without excluding or aggregating them.
   An explicit mapping takes priority. A five-digit prefix only identifies a
   merchandise CANDIDATE; it does not verify the product's business purpose.
   The mapping primary key prevents a one-to-many join from multiplying lines.
   CodeType is a line-purpose label, not a merchandise category hierarchy.
*/
USE SalesAnalyticsDB;
GO
CREATE OR ALTER VIEW clean.vw_RetailClassified
AS
SELECT
    r.SourceSheet,
    r.SourceRowNumber,
    r.InvoiceNumber,
    r.StockCode,
    r.ProductDescription,
    r.Quantity,
    r.InvoiceDate,
    r.UnitPrice,
    r.CustomerID,
    r.Country,
    r.IsCancellation,
    r.SignedLineValueGBP,
    CASE
        WHEN m.StockCode IS NOT NULL THEN m.CodeType
        WHEN r.StockCode COLLATE Latin1_General_100_BIN2
            LIKE N'[0-9][0-9][0-9][0-9][0-9]%'
            THEN 'MerchandiseCandidate'
        ELSE 'Review'
    END AS CodeType,
    CASE
        WHEN m.StockCode IS NOT NULL THEN 'ExplicitMapping'
        WHEN r.StockCode COLLATE Latin1_General_100_BIN2
            LIKE N'[0-9][0-9][0-9][0-9][0-9]%'
            THEN 'FiveDigitPrefixRule'
        ELSE 'UnmappedCode'
    END AS ClassificationBasis
FROM clean.vw_RetailCanonical AS r
LEFT JOIN dbo.StockCodeClassification AS m
    ON r.StockCode = m.StockCode;
GO

-- Must remain 1,044,848: adding lookup labels must not multiply or lose lines.
SELECT COUNT_BIG(*) AS ClassifiedRows
FROM clean.vw_RetailClassified;

-- Coverage and source-value reconciliation, not cleaned revenue.
SELECT CodeType, ClassificationBasis,
    COUNT_BIG(*) AS LinesInGroup,
    COUNT(DISTINCT StockCode) AS DistinctCodes,
    SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM clean.vw_RetailClassified
GROUP BY CodeType, ClassificationBasis
ORDER BY LinesInGroup DESC;

-- Separate query for the next review. Do not classify from code shape alone.
SELECT StockCode,
    MIN(ProductDescription) AS ExampleDescription,
    COUNT_BIG(*) AS LinesInGroup,
    SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM clean.vw_RetailClassified
WHERE CodeType = 'Review'
GROUP BY StockCode
ORDER BY LinesInGroup DESC, StockCode;
GO
