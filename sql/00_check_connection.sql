/* Read-only: run in SSMS while connected to your chosen local instance.
   Do not put passwords or connection strings in this repository. */
SELECT
    CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)) AS ServerName,
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS ProductVersion,
    CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS Edition,
    ORIGINAL_LOGIN() AS LoginName,
    DB_NAME() AS CurrentDatabase;
GO
