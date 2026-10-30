/* Phase 2, step 3. Run AFTER 01 and 02.
   IMPORTANT: SQL Server reads this path on the server computer. For your local
   instance this is the same Windows computer. Edit the path if the file moves.
   File is UTF-8, comma-separated, quoted using standard CSV escaping, LF endings.
   Import preserves both worksheets. No cleaning or deduplication is done here.
   Refuses a nonempty table so rerunning cannot append the source twice. */
USE SalesAnalyticsDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM stg.RetailRaw)
    THROW 50001, 'Staging already has rows. Run 04_validate_staging.sql; do not import twice.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    BULK INSERT stg.RetailRaw
    FROM 'C:\SalesAnalytics\data\processed\retail_staging.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIELDQUOTE = '"',
        FIRSTROW = 2,
        CODEPAGE = '65001',
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0a',
        KEEPNULLS,
        CHECK_CONSTRAINTS,
        TABLOCK,
        MAXERRORS = 0
    );
    IF (SELECT COUNT_BIG(*) FROM stg.RetailRaw) <> 1067371
        THROW 50002, 'Imported row count differs from the verified source. Import rolled back.', 1;
    IF (SELECT COUNT_BIG(*) FROM stg.RetailRaw WHERE SourceSheet = N'Year 2009-2010') <> 525461
        THROW 50003, 'First worksheet count differs. Import rolled back.', 1;
    IF (SELECT COUNT_BIG(*) FROM stg.RetailRaw WHERE SourceSheet = N'Year 2010-2011') <> 541910
        THROW 50004, 'Second worksheet count differs. Import rolled back.', 1;
    COMMIT TRANSACTION;
    SELECT COUNT_BIG(*) AS ImportedRows FROM stg.RetailRaw;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
