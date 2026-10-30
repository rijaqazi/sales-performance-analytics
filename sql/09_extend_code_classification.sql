/* Additional analyst mappings supported by the user's Review-code result grid.
   Preserve existing decisions on rerun. Do not infer costs, profit, categories,
   physical returns, or voucher redemption from these purpose labels.
   M, m, PADS, NULL-description codes, and vague descriptions remain Review.
*/
USE SalesAnalyticsDB;
GO
INSERT INTO dbo.StockCodeClassification
    (StockCode, CodeType, ClassificationReason)
SELECT v.StockCode, v.CodeType, v.Reason
FROM (VALUES
    (N'B', 'Adjustment', N'Observed description: Adjust bad debt'),
    (N'ADJUST2', 'Adjustment', N'Observed dated adjustment description'),
    (N'TEST002', 'Test', N'Observed description: This is a test product.'),
    (N'gift_0001_40', 'Voucher', N'Observed gift voucher description'),
    (N'gift_0001_70', 'Voucher', N'Observed gift voucher description'),
    (N'gift_0001_80', 'Voucher', N'Observed gift voucher description'),
    (N'DCGS0069', 'Merchandise', N'Provisional: OOH LA LA DOGS COLLAR'),
    (N'DCGS0004', 'Merchandise', N'Provisional: HAYNES CAMPER SHOULDER BAG'),
    (N'DCGS0066N', 'Merchandise', N'Provisional: NAVY CUDDLES DOG HOODIE'),
    (N'DCGS0072', 'Merchandise', N'Provisional: CAT CAMOUFLAGE COLLAR'),
    (N'DCGS0068', 'Merchandise', N'Provisional: DOGS NIGHT COLLAR'),
    (N'DCGS0070', 'Merchandise', N'Provisional: CAMOUFLAGE DOG COLLAR'),
    (N'SP1002', 'Merchandise', N'Provisional: KIDS CHALKBOARD/EASEL'),
    (N'DCGS0037', 'Merchandise', N'Provisional: KEY-RING CORKSCREW'),
    (N'DCGS0062', 'Merchandise', N'Provisional: ROAD-RAGE CAR FRESHENER'),
    (N'DCGS0044', 'Merchandise', N'Provisional: HANDZ-OFF CAR FRESHENER'),
    (N'DCGS0075', 'Merchandise', N'Provisional: CAMOUFLAGE DOG LEAD')
) v(StockCode, CodeType, Reason)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.StockCodeClassification AS existing
    WHERE existing.StockCode = v.StockCode COLLATE Latin1_General_100_BIN2
);
GO
-- Views immediately reflect the new lookup rows; no data reload is needed.
SELECT COUNT_BIG(*) AS ClassifiedRows
FROM clean.vw_RetailClassified;

SELECT CodeType, ClassificationBasis,
    COUNT_BIG(*) AS LinesInGroup,
    COUNT(DISTINCT StockCode) AS DistinctCodes,
    SUM(SignedLineValueGBP) AS SignedSourceValueGBP
FROM clean.vw_RetailClassified
GROUP BY CodeType, ClassificationBasis
ORDER BY LinesInGroup DESC;
GO
