/* Phase 2, step 1. Run the entire file in SSMS (F5).
   Creates only a missing database. Never drops an existing database.
   Requires CREATE DATABASE permission. No file paths or sizes are hardcoded. */
USE master;
GO
IF DB_ID(N'SalesAnalyticsDB') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE SalesAnalyticsDB;');
    PRINT N'Created SalesAnalyticsDB.';
END
ELSE
    PRINT N'SalesAnalyticsDB already exists. No database was recreated.';
GO
USE SalesAnalyticsDB;
GO
SELECT DB_NAME() AS DatabaseName, compatibility_level AS CompatibilityLevel
FROM sys.databases WHERE name = DB_NAME();
GO
