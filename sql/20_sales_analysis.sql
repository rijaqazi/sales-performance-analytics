/* PHASE 3 — read-only, reproducible sales and customer analysis.
   Prerequisites: Phase 2 validated. No source or model tables are changed.
   All money is GBP. Eligible scope includes the documented code-pattern assumption.
   Repeated-line candidates remain included; sensitivity is reported separately.
   Separate discount lines, shipping, fees, vouchers and review lines are excluded
   from merchandise metrics. Profit/categories are unavailable, not zero.
   Percentage columns use 0–100 units, not 0–1 ratios.
   Run the entire file in one SSMS query tab; temporary tables are session-local.
*/
USE SalesAnalyticsDB;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #Sales,#Orders,#Customers,#Monthly,#RFMBase,#RFMScores,#RFM;

DECLARE @DataStart date=(SELECT MIN(CONVERT(date,InvoiceDate)) FROM dbo.FactSalesLine),
        @DataEnd date=(SELECT MAX(CONVERT(date,InvoiceDate)) FROM dbo.FactSalesLine);
DECLARE @Snapshot date=DATEADD(day,1,@DataEnd);
DECLARE @RFMStart date=DATEADD(year,-1,@Snapshot);

-- A CTE names the eligible purchase population before materializing it once.
;WITH EligiblePurchases AS
(
    SELECT InvoiceNumber,InvoiceDate,DateKey,ProductKey,CustomerKey,CountryKey,
        Quantity,SignedLineValueGBP,IsRepeatedLine,ClassificationBasis
    FROM dbo.FactSalesLine WHERE LineStatus='MerchandiseSale'
)
SELECT * INTO #Sales FROM EligiblePurchases;

-- An order can have multiple line timestamps. Anchor order-level behavior to
-- the first eligible purchase timestamp; retain line timestamps for sales trends.
SELECT InvoiceNumber,MIN(InvoiceDate) AS FirstPurchaseTimestamp,
    MAX(InvoiceDate) AS LastPurchaseTimestamp,
    MAX(CustomerKey) AS CustomerKey,MAX(CountryKey) AS CountryKey,
    SUM(SignedLineValueGBP) AS OrderValueGBP,COUNT_BIG(*) AS PurchaseLines,
    COUNT(DISTINCT CustomerKey) AS CustomerKeys,COUNT(DISTINCT CountryKey) AS CountryKeys
INTO #Orders FROM #Sales GROUP BY InvoiceNumber;
IF EXISTS (SELECT 1 FROM #Orders WHERE CustomerKeys<>1 OR CountryKeys<>1)
    THROW 50201, 'An order has multiple customer/country keys; review before customer analysis.',1;

SELECT o.CustomerKey,COUNT_BIG(*) AS Orders,
    SUM(o.OrderValueGBP) AS GrossPurchasesGBP,
    MIN(o.FirstPurchaseTimestamp) AS FirstPurchaseTimestamp,
    MAX(o.FirstPurchaseTimestamp) AS LastPurchaseTimestamp
INTO #Customers FROM #Orders AS o
JOIN dbo.DimCustomer AS c ON c.CustomerKey=o.CustomerKey
WHERE c.IsUnknown=0 GROUP BY o.CustomerKey;

-- Full calendar with source-coverage filtering. Do not present pre-source months
-- as known zero sales. December 2011 is explicitly incomplete.
SELECT d.MonthStart,MAX(CONVERT(int,d.IsCompleteSourceMonth)) AS IsCompleteSourceMonth,
    SUM(CASE WHEN f.LineStatus='MerchandiseSale' THEN f.SignedLineValueGBP ELSE 0 END) AS GrossSalesGBP,
    -SUM(CASE WHEN f.LineStatus='MerchandiseCancellation' THEN f.SignedLineValueGBP ELSE 0 END) AS CancellationValueGBP,
    SUM(CASE WHEN f.LineStatus IN ('MerchandiseSale','MerchandiseCancellation') THEN f.SignedLineValueGBP ELSE 0 END) AS NetMerchandiseValueGBP
INTO #Monthly FROM dbo.DimDate AS d
LEFT JOIN dbo.FactSalesLine AS f ON f.DateKey=d.DateKey
WHERE d.CalendarDate BETWEEN @DataStart AND @DataEnd
GROUP BY d.MonthStart;

-- RFM: trailing one calendar year ending on the day after the final source date.
-- Recency uses the last eligible LINE timestamp in that window; frequency counts
-- distinct invoices. All three metrics use the same known-customer population.
SELECT s.CustomerKey,DATEDIFF(day,MAX(CONVERT(date,s.InvoiceDate)),@Snapshot) AS RecencyDays,
    COUNT(DISTINCT s.InvoiceNumber) AS FrequencyOrders,
    SUM(s.SignedLineValueGBP) AS MonetaryGBP
INTO #RFMBase FROM #Sales AS s
JOIN dbo.DimCustomer AS c ON c.CustomerKey=s.CustomerKey
WHERE c.IsUnknown=0 AND s.InvoiceDate>=@RFMStart AND s.InvoiceDate<@Snapshot
GROUP BY s.CustomerKey;

-- PERCENT_RANK keeps equal metric values tied. Groups need not have equal sizes.
-- Recency descending makes more recent customers rank higher; F/M ascend.
SELECT *,PERCENT_RANK() OVER(ORDER BY RecencyDays DESC) AS RPercentile,
    PERCENT_RANK() OVER(ORDER BY FrequencyOrders) AS FPercentile,
    PERCENT_RANK() OVER(ORDER BY MonetaryGBP) AS MPercentile
INTO #RFMScores FROM #RFMBase;
SELECT *,
    CASE WHEN RPercentile<0.2 THEN 1 WHEN RPercentile<0.4 THEN 2 WHEN RPercentile<0.6 THEN 3 WHEN RPercentile<0.8 THEN 4 ELSE 5 END AS RScore,
    CASE WHEN FPercentile<0.2 THEN 1 WHEN FPercentile<0.4 THEN 2 WHEN FPercentile<0.6 THEN 3 WHEN FPercentile<0.8 THEN 4 ELSE 5 END AS FScore,
    CASE WHEN MPercentile<0.2 THEN 1 WHEN MPercentile<0.4 THEN 2 WHEN MPercentile<0.6 THEN 3 WHEN MPercentile<0.8 THEN 4 ELSE 5 END AS MScore
INTO #RFM FROM #RFMScores;

-- Reconcile independent aggregation paths before emitting any analysis.
IF (SELECT SUM(OrderValueGBP) FROM #Orders)<>(SELECT SUM(SignedLineValueGBP) FROM #Sales)
    THROW 50202,'Order and line revenue do not reconcile.',1;
IF (SELECT SUM(GrossSalesGBP) FROM #Monthly)<>(SELECT SUM(SignedLineValueGBP) FROM #Sales)
    THROW 50203,'Monthly and line revenue do not reconcile.',1;
IF (SELECT SUM(MonetaryGBP) FROM #RFM)<>(SELECT SUM(s.SignedLineValueGBP) FROM #Sales AS s
    JOIN dbo.DimCustomer AS c ON c.CustomerKey=s.CustomerKey
    WHERE c.IsUnknown=0 AND s.InvoiceDate>=@RFMStart AND s.InvoiceDate<@Snapshot)
    THROW 50204,'RFM monetary values do not reconcile.',1;

-- Annual YoY compares complete Jan–Nov periods for this source, not full 2010
-- against partial 2011. Use the last month whose boundary is covered by source.
DECLARE @ComparisonEnd date=CASE WHEN @DataEnd=EOMONTH(@DataEnd) THEN DATEADD(day,1,@DataEnd)
    ELSE DATEFROMPARTS(YEAR(@DataEnd),MONTH(@DataEnd),1) END;
DECLARE @ComparisonStart date=DATEFROMPARTS(YEAR(DATEADD(day,-1,@ComparisonEnd)),1,1);

-- One JSON result supports machine-readable local result capture from SSMS.
-- No customer IDs or names are exported. Section names match the mentoring guide.
SELECT (
SELECT
    @DataStart AS SourceFirstDate,@DataEnd AS SourceLastDate,
    JSON_QUERY((SELECT
        SUM(CASE WHEN LineStatus='MerchandiseSale' THEN SignedLineValueGBP ELSE 0 END) AS GrossMerchandiseSalesGBP,
        -SUM(CASE WHEN LineStatus='MerchandiseCancellation' THEN SignedLineValueGBP ELSE 0 END) AS CancellationValueGBP,
        SUM(CASE WHEN LineStatus IN ('MerchandiseSale','MerchandiseCancellation') THEN SignedLineValueGBP ELSE 0 END) AS NetMerchandiseTransactionValueGBP,
        (SELECT COUNT_BIG(*) FROM #Orders) AS PurchaseOrders,
        (SELECT COUNT_BIG(*) FROM #Customers) AS KnownPurchasingCustomers,
        CONVERT(decimal(19,4),(SELECT SUM(OrderValueGBP) FROM #Orders)/NULLIF(CONVERT(decimal(19,4),(SELECT COUNT_BIG(*) FROM #Orders)),0)) AS AverageOrderValueGBP,
        CAST(NULL AS decimal(19,4)) AS ProfitGBP,CAST(NULL AS decimal(12,4)) AS ProfitMarginPct,
        'Unavailable: source has no product costs' AS ProfitStatus
        FROM dbo.FactSalesLine FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) AS KPIs,

    JSON_QUERY((SELECT m.MonthStart,m.IsCompleteSourceMonth,m.GrossSalesGBP,m.CancellationValueGBP,m.NetMerchandiseValueGBP,
        (SELECT COUNT_BIG(*) FROM #Orders AS o WHERE o.FirstPurchaseTimestamp>=m.MonthStart AND o.FirstPurchaseTimestamp<DATEADD(month,1,m.MonthStart)) AS PurchaseOrders,
        CONVERT(decimal(12,4),100.0*(CONVERT(decimal(19,4),m.GrossSalesGBP)-CONVERT(decimal(19,4),p.GrossSalesGBP))/NULLIF(CONVERT(decimal(19,4),p.GrossSalesGBP),0)) AS YoYGrossSalesGrowthPct
        FROM #Monthly AS m LEFT JOIN #Monthly AS p ON p.MonthStart=DATEADD(year,-1,m.MonthStart)
            AND p.IsCompleteSourceMonth=1 AND m.IsCompleteSourceMonth=1
        ORDER BY m.MonthStart FOR JSON PATH,INCLUDE_NULL_VALUES)) AS MonthlyTrends,

    JSON_QUERY((SELECT YEAR(MonthStart) AS CalendarYear,MIN(MonthStart) AS FirstObservedMonth,MAX(MonthStart) AS LastObservedMonth,
        SUM(GrossSalesGBP) AS GrossSalesGBP,SUM(NetMerchandiseValueGBP) AS NetMerchandiseValueGBP,
        SUM(IsCompleteSourceMonth) AS CompleteSourceMonths,
        CASE WHEN COUNT(*)=12 AND MIN(IsCompleteSourceMonth)=1 THEN 'Full year' ELSE 'Partial year' END AS Coverage
        FROM #Monthly GROUP BY YEAR(MonthStart) ORDER BY CalendarYear FOR JSON PATH)) AS YearlyTrends,

    JSON_QUERY((SELECT TOP(10) p.StockCode,p.ProductDescription,SUM(s.SignedLineValueGBP) AS GrossSalesGBP,
        SUM(CONVERT(bigint,s.Quantity)) AS UnitsSold,
        ROW_NUMBER() OVER(ORDER BY SUM(s.SignedLineValueGBP) DESC,p.StockCode) AS RevenueRank
        FROM #Sales AS s JOIN dbo.DimProduct AS p ON p.ProductKey=s.ProductKey
        GROUP BY p.StockCode,p.ProductDescription ORDER BY GrossSalesGBP DESC,p.StockCode FOR JSON PATH,INCLUDE_NULL_VALUES)) AS TopProducts,

    JSON_QUERY((SELECT g.Country,SUM(CASE WHEN f.LineStatus='MerchandiseSale' THEN f.SignedLineValueGBP ELSE 0 END) AS GrossSalesGBP,
        SUM(CASE WHEN f.LineStatus IN ('MerchandiseSale','MerchandiseCancellation') THEN f.SignedLineValueGBP ELSE 0 END) AS NetMerchandiseValueGBP,
        COUNT(DISTINCT CASE WHEN f.LineStatus='MerchandiseSale' THEN f.InvoiceNumber END) AS PurchaseOrders
        FROM dbo.FactSalesLine AS f JOIN dbo.DimCountry AS g ON g.CountryKey=f.CountryKey
        GROUP BY g.Country ORDER BY GrossSalesGBP DESC,g.Country FOR JSON PATH)) AS CountryPerformance,

    JSON_QUERY((SELECT COUNT_BIG(*) AS KnownPurchasingCustomers,
        SUM(CASE WHEN Orders>=2 THEN 1 ELSE 0 END) AS RepeatPurchasers,
        CONVERT(decimal(12,4),100.0*SUM(CASE WHEN Orders>=2 THEN 1 ELSE 0 END)/NULLIF(COUNT_BIG(*),0)) AS RepeatPurchaserPct,
        SUM(GrossPurchasesGBP) AS KnownCustomerGrossSalesGBP,
        (SELECT SUM(s.SignedLineValueGBP) FROM #Sales AS s JOIN dbo.DimCustomer AS c ON c.CustomerKey=s.CustomerKey WHERE c.IsUnknown=1) AS AnonymousGrossSalesGBP
        FROM #Customers FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS CustomerBehavior,

    JSON_QUERY((SELECT CASE WHEN Orders=1 THEN '1 order' WHEN Orders BETWEEN 2 AND 4 THEN '2–4 orders'
        WHEN Orders BETWEEN 5 AND 9 THEN '5–9 orders' ELSE '10+ orders' END AS PurchaseBand,
        COUNT_BIG(*) AS Customers,SUM(GrossPurchasesGBP) AS GrossPurchasesGBP
        FROM #Customers GROUP BY CASE WHEN Orders=1 THEN '1 order' WHEN Orders BETWEEN 2 AND 4 THEN '2–4 orders'
        WHEN Orders BETWEEN 5 AND 9 THEN '5–9 orders' ELSE '10+ orders' END
        ORDER BY MIN(Orders) FOR JSON PATH)) AS PurchaseFrequency,

    JSON_QUERY((SELECT @ComparisonStart AS CurrentPeriodStart,DATEADD(day,-1,@ComparisonEnd) AS CurrentPeriodEnd,
        DATEADD(year,-1,@ComparisonStart) AS PriorPeriodStart,DATEADD(day,-1,DATEADD(year,-1,@ComparisonEnd)) AS PriorPeriodEnd,
        totals.CurrentGBP,totals.PriorGBP,
        CONVERT(decimal(12,4),100.0*(CONVERT(decimal(19,4),totals.CurrentGBP)-CONVERT(decimal(19,4),totals.PriorGBP))/NULLIF(CONVERT(decimal(19,4),totals.PriorGBP),0)) AS GrowthPct
        FROM (SELECT SUM(CASE WHEN InvoiceDate>=@ComparisonStart AND InvoiceDate<@ComparisonEnd THEN SignedLineValueGBP ELSE 0 END) AS CurrentGBP,
            SUM(CASE WHEN InvoiceDate>=DATEADD(year,-1,@ComparisonStart) AND InvoiceDate<DATEADD(year,-1,@ComparisonEnd) THEN SignedLineValueGBP ELSE 0 END) AS PriorGBP FROM #Sales) AS totals
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS ComparablePeriodYoY,

    JSON_QUERY((SELECT @RFMStart AS WindowStart,@Snapshot AS WindowEndExclusive,@Snapshot AS SnapshotDate,
        COUNT_BIG(*) AS IncludedCustomers,SUM(MonetaryGBP) AS IncludedGrossPurchasesGBP,
        MIN(RecencyDays) AS MinRecencyDays,MAX(RecencyDays) AS MaxRecencyDays
        FROM #RFM FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS RFMDefinition,

    JSON_QUERY((SELECT Segment,COUNT_BIG(*) AS Customers,SUM(MonetaryGBP) AS GrossPurchasesGBP,
        CONVERT(decimal(12,2),AVG(CONVERT(decimal(12,2),RecencyDays))) AS AverageRecencyDays,
        CONVERT(decimal(12,2),AVG(CONVERT(decimal(12,2),FrequencyOrders))) AS AverageOrders
        FROM (SELECT *,CASE WHEN RScore>=4 AND FScore>=4 AND MScore>=4 THEN 'Champions'
            WHEN RScore<=2 AND (FScore>=4 OR MScore>=4) THEN 'At-risk high value'
            WHEN RScore>=4 AND FScore<=2 THEN 'Recent occasional'
            WHEN RScore>=3 AND FScore>=3 THEN 'Loyal'
            WHEN RScore<=2 THEN 'Dormant' ELSE 'Potential' END AS Segment FROM #RFM) AS segmented
        GROUP BY Segment ORDER BY GrossPurchasesGBP DESC FOR JSON PATH)) AS RFMSegments,

    JSON_QUERY((SELECT
        (SELECT SUM(OrderValueGBP) FROM #Orders)-(SELECT SUM(SignedLineValueGBP) FROM #Sales) AS OrderValueDifferenceGBP,
        (SELECT SUM(GrossSalesGBP) FROM #Monthly)-(SELECT SUM(SignedLineValueGBP) FROM #Sales) AS MonthlyValueDifferenceGBP,
        (SELECT COUNT_BIG(*) FROM #Orders WHERE CONVERT(date,FirstPurchaseTimestamp)<>CONVERT(date,LastPurchaseTimestamp)) AS OrdersSpanningDates,
        (SELECT COUNT_BIG(*) FROM #Orders WHERE YEAR(FirstPurchaseTimestamp)*100+MONTH(FirstPurchaseTimestamp)<>YEAR(LastPurchaseTimestamp)*100+MONTH(LastPurchaseTimestamp)) AS OrdersSpanningMonths,
        (SELECT SUM(SignedLineValueGBP) FROM #Sales WHERE IsRepeatedLine=1) AS RepeatedSaleLineValueGBP,
        (SELECT COUNT_BIG(*) FROM #RFM WHERE RScore NOT BETWEEN 1 AND 5 OR FScore NOT BETWEEN 1 AND 5 OR MScore NOT BETWEEN 1 AND 5) AS InvalidRFMScores,
        'PASS: order, monthly, RFM monetary reconciliations' AS ValidationStatus
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS Validation,

    'Unavailable: source has no merchandise categories. Purpose classification is not a replacement.' AS CategoryAnalysisStatus,
    'Country-level only; source has no subnational regions.' AS RegionalAnalysisScope
FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER
) AS AnalysisJSON;
GO
