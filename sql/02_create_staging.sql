/* Phase 2, step 2: staging preserves original values as text.
   No positive-quantity constraint: cancellations and adjustments are valid evidence.
   Binary collation keeps case-sensitive source codes such as M and m distinct.
   The composite primary key records source provenance, not an invented order-line ID. */
USE SalesAnalyticsDB;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
GO
IF OBJECT_ID(N'stg.RetailRaw', N'U') IS NULL
BEGIN
    CREATE TABLE stg.RetailRaw
    (
        SourceSheet nvarchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
        SourceRowNumber int NOT NULL,
        InvoiceRaw nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL,
        StockCodeRaw nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL,
        DescriptionRaw nvarchar(500) COLLATE Latin1_General_100_BIN2 NULL,
        QuantityRaw nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL,
        InvoiceDateRaw nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL,
        UnitPriceRaw nvarchar(50) COLLATE Latin1_General_100_BIN2 NULL,
        CustomerIDRaw nvarchar(30) COLLATE Latin1_General_100_BIN2 NULL,
        CountryRaw nvarchar(100) COLLATE Latin1_General_100_BIN2 NULL,
        CONSTRAINT PK_RetailRaw PRIMARY KEY (SourceSheet, SourceRowNumber),
        CONSTRAINT CK_RetailRaw_SourceRow CHECK (SourceRowNumber >= 2),
        CONSTRAINT CK_RetailRaw_SourceSheet CHECK
            (SourceSheet IN (N'Year 2009-2010', N'Year 2010-2011'))
    );
END
ELSE PRINT N'stg.RetailRaw already exists; no table was recreated.';
GO
SELECT COUNT_BIG(*) AS ExistingStagingRows FROM stg.RetailRaw;
GO
