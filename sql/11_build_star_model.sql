/* Phase 2: non-destructive, transactional first load of a star schema.
   All canonical lines are retained, including review and excluded populations.
   Existing loaded facts cause a stop: avoids silently mixing changed mapping rules.
   Source staging and views remain untouched. Use 12 for repeatable validation.
*/
USE SalesAnalyticsDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT * INTO #Canonical FROM clean.vw_RetailEligible;
    IF (SELECT COUNT_BIG(*) FROM #Canonical) <> 1044848
        THROW 50101, 'Unexpected canonical count. Build stopped.', 1;
    IF EXISTS (SELECT 1 FROM #Canonical WHERE Quantity IS NULL OR UnitPrice IS NULL
        OR InvoiceDate IS NULL OR InvoiceNumber IS NULL OR StockCode IS NULL OR Country IS NULL)
        THROW 50102, 'Required typed values are missing. Build stopped.', 1;
    IF OBJECT_ID(N'dbo.FactSalesLine',N'U') IS NOT NULL
        IF EXISTS (SELECT 1 FROM dbo.FactSalesLine)
            THROW 50103, 'Facts already loaded. Run 12_validate_model.sql instead; no data changed.', 1;

    IF OBJECT_ID(N'dbo.DimDate',N'U') IS NULL
    CREATE TABLE dbo.DimDate (
        DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
        CalendarDate date NOT NULL CONSTRAINT UQ_DimDate_Date UNIQUE,
        CalendarYear smallint NOT NULL,
        MonthNumber tinyint NOT NULL CONSTRAINT CK_DimDate_Month CHECK (MonthNumber BETWEEN 1 AND 12),
        YearMonth char(7) NOT NULL,
        MonthStart date NOT NULL,
        IsCompleteSourceMonth bit NOT NULL
    );
    IF OBJECT_ID(N'dbo.DimProduct',N'U') IS NULL
    CREATE TABLE dbo.DimProduct (
        ProductKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
        StockCode nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL CONSTRAINT UQ_DimProduct_Code UNIQUE,
        ProductDescription nvarchar(500) NULL
    );
    IF OBJECT_ID(N'dbo.DimCustomer',N'U') IS NULL
    CREATE TABLE dbo.DimCustomer (
        CustomerKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
        CustomerID nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL CONSTRAINT UQ_DimCustomer_ID UNIQUE,
        IsUnknown bit NOT NULL,
        CONSTRAINT CK_DimCustomer_Unknown CHECK
            ((CustomerID IS NULL AND IsUnknown=1) OR (CustomerID IS NOT NULL AND IsUnknown=0))
    );
    IF OBJECT_ID(N'dbo.DimCountry',N'U') IS NULL
    CREATE TABLE dbo.DimCountry (
        CountryKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCountry PRIMARY KEY,
        Country nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL CONSTRAINT UQ_DimCountry_Name UNIQUE
    );
    IF OBJECT_ID(N'dbo.FactSalesLine',N'U') IS NULL
    CREATE TABLE dbo.FactSalesLine (
        SalesLineKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSalesLine PRIMARY KEY,
        SourceSheet nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
        SourceRowNumber int NOT NULL,
        DateKey int NOT NULL,
        ProductKey int NOT NULL,
        CustomerKey int NOT NULL,
        CountryKey int NOT NULL,
        InvoiceNumber nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
        InvoiceDate datetime2(0) NOT NULL,
        Quantity int NOT NULL,
        UnitPrice decimal(19,4) NOT NULL,
        SignedLineValueGBP decimal(29,4) NOT NULL,
        IsCancellation bit NOT NULL,
        CodeType varchar(30) NOT NULL,
        ClassificationBasis varchar(30) NOT NULL,
        LineStatus varchar(30) NOT NULL,
        IsRepeatedLine bit NOT NULL,
        CONSTRAINT UQ_FactSalesLine_Source UNIQUE (SourceSheet,SourceRowNumber),
        CONSTRAINT FK_Fact_Source FOREIGN KEY (SourceSheet,SourceRowNumber)
            REFERENCES stg.RetailRaw(SourceSheet,SourceRowNumber),
        CONSTRAINT FK_Fact_Date FOREIGN KEY (DateKey) REFERENCES dbo.DimDate(DateKey),
        CONSTRAINT FK_Fact_Product FOREIGN KEY (ProductKey) REFERENCES dbo.DimProduct(ProductKey),
        CONSTRAINT FK_Fact_Customer FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer(CustomerKey),
        CONSTRAINT FK_Fact_Country FOREIGN KEY (CountryKey) REFERENCES dbo.DimCountry(CountryKey),
        CONSTRAINT CK_Fact_Value CHECK (SignedLineValueGBP = CONVERT(decimal(29,4),CONVERT(decimal(10,0),Quantity)*UnitPrice)),
        CONSTRAINT CK_Fact_Status CHECK (LineStatus IN ('InvalidTypedValue','ReviewCode','NonMerchandise',
            'NonPositivePrice','MerchandiseCancellation','CancellationException',
            'OtherQuantityAdjustment','MerchandiseSale','QuantityException'))
    );

    DECLARE @MinDate date=(SELECT MIN(CONVERT(date,InvoiceDate)) FROM #Canonical),
            @MaxDate date=(SELECT MAX(CONVERT(date,InvoiceDate)) FROM #Canonical);
    -- Full calendar years support a Power BI date table; out-of-coverage months
    -- remain explicitly incomplete rather than masquerading as complete zero sales.
    ;WITH Dates AS (
        SELECT DATEFROMPARTS(YEAR(@MinDate),1,1) AS CalendarDate
        UNION ALL
        SELECT DATEADD(day,1,CalendarDate) FROM Dates
        WHERE CalendarDate < DATEFROMPARTS(YEAR(@MaxDate),12,31)
    )
    INSERT dbo.DimDate(DateKey,CalendarDate,CalendarYear,MonthNumber,YearMonth,MonthStart,IsCompleteSourceMonth)
    SELECT YEAR(CalendarDate)*10000+MONTH(CalendarDate)*100+DAY(CalendarDate),
        CalendarDate,YEAR(CalendarDate),MONTH(CalendarDate),CONVERT(char(7),CalendarDate,126),
        DATEFROMPARTS(YEAR(CalendarDate),MONTH(CalendarDate),1),
        CASE WHEN DATEFROMPARTS(YEAR(CalendarDate),MONTH(CalendarDate),1)>=@MinDate
            AND EOMONTH(CalendarDate)<=@MaxDate THEN 1 ELSE 0 END
    FROM Dates AS d WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate AS existing WHERE existing.CalendarDate=d.CalendarDate)
    OPTION (MAXRECURSION 0);

    -- Latest nonblank description, with source row as deterministic tie-breaker.
    -- RTRIM standardizes trailing spaces for the product dimension only.
    ;WITH Products AS (
        SELECT RTRIM(StockCode) AS StockCode, ProductDescription,
            ROW_NUMBER() OVER (PARTITION BY RTRIM(StockCode)
                ORDER BY CASE WHEN NULLIF(LTRIM(RTRIM(ProductDescription)),N'') IS NULL THEN 1 ELSE 0 END,
                    InvoiceDate DESC,SourceSheet DESC,SourceRowNumber DESC) AS rn
        FROM #Canonical
    )
    INSERT dbo.DimProduct(StockCode,ProductDescription)
    SELECT p.StockCode,p.ProductDescription FROM Products AS p WHERE rn=1
        AND NOT EXISTS (SELECT 1 FROM dbo.DimProduct AS existing WHERE existing.StockCode=p.StockCode);

    IF NOT EXISTS (SELECT 1 FROM dbo.DimCustomer WHERE CustomerID IS NULL)
        INSERT dbo.DimCustomer(CustomerID,IsUnknown) VALUES(NULL,1);
    INSERT dbo.DimCustomer(CustomerID,IsUnknown)
    SELECT DISTINCT c.CustomerID,0 FROM #Canonical AS c WHERE c.CustomerID IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM dbo.DimCustomer AS existing WHERE existing.CustomerID=c.CustomerID);
    INSERT dbo.DimCountry(Country)
    SELECT DISTINCT c.Country FROM #Canonical AS c
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCountry AS existing WHERE existing.Country=c.Country);

    ;WITH Lines AS (
        SELECT *,ROW_NUMBER() OVER (
            PARTITION BY InvoiceNumber,StockCode,ProductDescription,Quantity,InvoiceDate,UnitPrice,CustomerID,Country
            ORDER BY SourceSheet,SourceRowNumber) AS RepeatSequence
        FROM #Canonical
    )
    INSERT dbo.FactSalesLine(SourceSheet,SourceRowNumber,DateKey,ProductKey,CustomerKey,CountryKey,
        InvoiceNumber,InvoiceDate,Quantity,UnitPrice,SignedLineValueGBP,IsCancellation,
        CodeType,ClassificationBasis,LineStatus,IsRepeatedLine)
    SELECT l.SourceSheet,l.SourceRowNumber,YEAR(l.InvoiceDate)*10000+MONTH(l.InvoiceDate)*100+DAY(l.InvoiceDate),
        p.ProductKey,c.CustomerKey,g.CountryKey,l.InvoiceNumber,l.InvoiceDate,l.Quantity,l.UnitPrice,
        l.SignedLineValueGBP,l.IsCancellation,l.CodeType,l.ClassificationBasis,l.LineStatus,
        CONVERT(bit,CASE WHEN l.RepeatSequence>1 THEN 1 ELSE 0 END)
    FROM Lines AS l
    JOIN dbo.DimProduct AS p ON p.StockCode=RTRIM(l.StockCode)
    JOIN dbo.DimCustomer AS c ON c.CustomerID=l.CustomerID OR (c.CustomerID IS NULL AND l.CustomerID IS NULL)
    JOIN dbo.DimCountry AS g ON g.Country=l.Country;

    IF (SELECT COUNT_BIG(*) FROM dbo.FactSalesLine)<>1044848
        THROW 50104, 'Fact count does not reconcile; entire build rolled back.', 1;
    IF (SELECT SUM(SignedLineValueGBP) FROM dbo.FactSalesLine)
        <> (SELECT SUM(SignedLineValueGBP) FROM #Canonical)
        THROW 50105, 'Fact value does not reconcile; entire build rolled back.', 1;

    CREATE INDEX IX_FactSalesLine_DateStatus ON dbo.FactSalesLine(DateKey,LineStatus)
        INCLUDE(SignedLineValueGBP,InvoiceNumber,CustomerKey,ProductKey,CountryKey);
    CREATE INDEX IX_FactSalesLine_Customer ON dbo.FactSalesLine(CustomerKey,DateKey);
    COMMIT TRANSACTION;
    SELECT N'PASS: star schema loaded and reconciled' AS BuildResult,
        COUNT_BIG(*) AS FactRows FROM dbo.FactSalesLine;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
