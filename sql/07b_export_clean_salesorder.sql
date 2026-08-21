SET NOCOUNT ON;
PRINT 'DELETE FROM stg.SalesOrder;';
SELECT
    'INSERT INTO stg.SalesOrder (OrderId, LineNumber, OrderDate, CustomerId, ProductId, StoreId, ChannelId, Quantity, UnitPrice, DiscountAmount) VALUES ('
    + '''' + OrderId + ''', '
    + CAST(LineNumber AS VARCHAR(20)) + ', '
    + '''' + CONVERT(VARCHAR(10), OrderDate, 23) + ''', '
    + '''' + CustomerId + ''', '
    + '''' + ProductId + ''', '
    + '''' + StoreId + ''', '
    + ISNULL('''' + ChannelId + '''', 'NULL') + ', '
    + CAST(Quantity AS VARCHAR(20)) + ', '
    + CAST(UnitPrice AS VARCHAR(30)) + ', '
    + CAST(ISNULL(DiscountAmount, 0) AS VARCHAR(30)) + ');'
FROM stg.SalesOrder
WHERE StagingRowId NOT IN (
    SELECT SourceRowId FROM stg.ErrorRows WHERE EntityName = 'SalesOrder' AND SourceRowId IS NOT NULL
);
