IF OBJECT_ID('dw.usp_TruncateTable') IS NOT NULL DROP PROCEDURE dw.usp_TruncateTable;
GO
CREATE PROCEDURE dw.usp_TruncateTable @TableName NVARCHAR(200) AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX) = N'TRUNCATE TABLE ' + @TableName;
    EXEC sp_executesql @sql;
END
GO
-- Clean up the accumulated duplicate rows from earlier test runs
TRUNCATE TABLE stg.Product;
TRUNCATE TABLE stg.Customer;
TRUNCATE TABLE stg.Store;
TRUNCATE TABLE stg.SalesOrder;
TRUNCATE TABLE dw.FactSales;
PRINT 'helper procedure created, landing tables cleaned';
