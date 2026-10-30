/* Non-destructive exception/review surface. No records are deleted or corrected
   without evidence. A repeat flag alone is not proof of a bad source record.
   Non-merchandise lines remain in facts for reconciliation, but are not all
   automatically data-quality failures. Anonymous sales are also legitimate.
*/
USE SalesAnalyticsDB;
GO
CREATE OR ALTER VIEW clean.vw_DataQualityReview
AS
SELECT SalesLineKey,SourceSheet,SourceRowNumber,InvoiceNumber,InvoiceDate,
    ProductKey,CustomerKey,CountryKey,Quantity,UnitPrice,SignedLineValueGBP,
    CodeType,ClassificationBasis,LineStatus,IsRepeatedLine
FROM dbo.FactSalesLine
WHERE LineStatus IN ('ReviewCode','InvalidTypedValue','NonPositivePrice',
    'CancellationException','OtherQuantityAdjustment','QuantityException')
    OR IsRepeatedLine=1;
GO
SELECT LineStatus,IsRepeatedLine,COUNT_BIG(*) AS ReviewRows
FROM clean.vw_DataQualityReview
GROUP BY LineStatus,IsRepeatedLine ORDER BY LineStatus,IsRepeatedLine;
GO
