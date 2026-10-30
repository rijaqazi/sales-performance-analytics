/* First-version analytical eligibility, NOT audited accounting revenue.
   Merchandise scope = explicit Merchandise + five-digit-prefix candidates.
   Pattern candidates are an analyst assumption; ClassificationBasis is retained.
   Missing product descriptions do not invalidate an otherwise identifiable SKU.
   Anonymous customers stay in sales, but will be excluded from known-customer RFM.
   Repeated within-sheet lines remain; source-line uniqueness is preserved.
   Every canonical line receives exactly one status; no records are deleted.
*/
USE SalesAnalyticsDB;
GO
CREATE OR ALTER VIEW clean.vw_RetailEligible
AS
SELECT r.*,
    CASE
        WHEN Quantity IS NULL OR UnitPrice IS NULL OR InvoiceDate IS NULL
            THEN 'InvalidTypedValue'
        WHEN CodeType = 'Review' THEN 'ReviewCode'
        WHEN CodeType NOT IN ('Merchandise', 'MerchandiseCandidate')
            THEN 'NonMerchandise'
        WHEN UnitPrice <= 0 THEN 'NonPositivePrice'
        WHEN IsCancellation = 1 AND Quantity < 0
            THEN 'MerchandiseCancellation'
        WHEN IsCancellation = 1 THEN 'CancellationException'
        WHEN Quantity < 0 THEN 'OtherQuantityAdjustment'
        WHEN Quantity > 0 THEN 'MerchandiseSale'
        ELSE 'QuantityException'
    END AS LineStatus
FROM clean.vw_RetailClassified AS r;
GO
SELECT LineStatus,
    COUNT_BIG(*) AS LinesInGroup,
    SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM clean.vw_RetailEligible
GROUP BY LineStatus ORDER BY LinesInGroup DESC;

-- Coverage must match. ValueDifferenceGBP must be 0.0000.
-- The independent canonical query is compared to the classified/eligible view.
SELECT
    (SELECT COUNT_BIG(*) FROM clean.vw_RetailCanonical) AS CanonicalRows,
    (SELECT COUNT_BIG(*) FROM clean.vw_RetailEligible) AS ClassifiedRows,
    (SELECT SUM(SignedLineValueGBP) FROM clean.vw_RetailCanonical)
      - (SELECT SUM(SignedLineValueGBP) FROM clean.vw_RetailEligible)
        AS ValueDifferenceGBP;
GO
