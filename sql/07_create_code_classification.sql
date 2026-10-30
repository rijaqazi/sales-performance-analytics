/* Analyst-created classification based on the user's special-code result grid.
   This is NOT a source-provided product category hierarchy.
   Codes not explicitly mapped remain unresolved until a later classification view
   applies documented standard-code rules and measures unmapped coverage.
   Existing classifications are preserved on rerun, not silently overwritten.
   Merchandise labels here are provisional interpretations of observed descriptions.
*/
USE SalesAnalyticsDB;
GO
IF OBJECT_ID(N'dbo.StockCodeClassification', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StockCodeClassification
    (
        StockCode nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
        CodeType varchar(20) NOT NULL,
        ClassificationReason nvarchar(250) NOT NULL,
        CONSTRAINT PK_StockCodeClassification PRIMARY KEY (StockCode),
        CONSTRAINT CK_StockCodeClassification_Type CHECK
        (CodeType IN ('Merchandise','Shipping','Discount','Fee','Adjustment',
                      'Voucher','Sample','Test','Review'))
    );
END;
GO
INSERT INTO dbo.StockCodeClassification (StockCode, CodeType, ClassificationReason)
SELECT v.StockCode, v.CodeType, v.ClassificationReason
FROM (VALUES
    (N'POST', 'Shipping', N'Observed description: POSTAGE'),
    (N'DOT', 'Shipping', N'Observed description: DOTCOM POSTAGE'),
    (N'C2', 'Shipping', N'Observed description: CARRIAGE'),
    (N'M', 'Review', N'Manual: insufficient detail to identify purpose'),
    (N'D', 'Discount', N'Observed description: Discount; keep separate from merchandise'),
    (N'S', 'Sample', N'Observed description: SAMPLES; separate analytical population'),
    (N'BANK CHARGES', 'Fee', N'Observed description: Bank Charges'),
    (N'AMAZONFEE', 'Fee', N'Observed description: AMAZON FEE'),
    (N'CRUK', 'Fee', N'Observed description: CRUK Commission'),
    (N'ADJUST', 'Adjustment', N'Observed description identifies an adjustment'),
    (N'PADS', 'Review', N'Product-like description but unusual small signed value; review source lines'),
    (N'TEST001', 'Test', N'Observed description: This is a test product.'),
    (N'DCGS0058', 'Merchandise', N'Observed description: MISO PRETTY GUM; provisional merchandise'),
    (N'DCGSSGIRL', 'Merchandise', N'Observed description: GIRLS PARTY BAG; provisional merchandise'),
    (N'DCGSSBOY', 'Merchandise', N'Observed description: BOYS PARTY BAG; provisional merchandise'),
    (N'DCGS0003', 'Merchandise', N'Observed description: BOXED GLASS ASHTRAY; provisional merchandise'),
    (N'DCGS0076', 'Merchandise', N'Observed description: SUNJAR LED NIGHT LIGHT; provisional merchandise'),
    (N'gift_0001_10', 'Voucher', N'Observed gift voucher description; separate to avoid redemption double counting'),
    (N'gift_0001_20', 'Voucher', N'Observed gift voucher description; separate to avoid redemption double counting'),
    (N'gift_0001_30', 'Voucher', N'Observed gift voucher description; separate to avoid redemption double counting'),
    (N'gift_0001_50', 'Voucher', N'Observed gift voucher description; separate to avoid redemption double counting')
) v(StockCode, CodeType, ClassificationReason)
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.StockCodeClassification AS existing
    WHERE existing.StockCode = v.StockCode COLLATE Latin1_General_100_BIN2
);
GO
SELECT CodeType, COUNT(*) AS MappedCodes
FROM dbo.StockCodeClassification
GROUP BY CodeType ORDER BY CodeType;
-- First run: 21 mapped codes. This counts codes, not transaction lines.
GO
