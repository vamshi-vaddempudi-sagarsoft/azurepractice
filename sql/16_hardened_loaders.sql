-- ============================================================
-- 16_hardened_loaders.sql
-- Runs against: salesdw (Synapse)
-- Makes the dimension/fact loaders defensive: they now always collapse the
-- landing table down to one row per business key BEFORE merging, so they
-- give the correct result even if the landing table has duplicate copies.
-- ============================================================

IF OBJECT_ID('dw.usp_LoadDimGeneric') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimGeneric;
GO
CREATE PROCEDURE dw.usp_LoadDimGeneric
    @StagingTable   NVARCHAR(200),
    @TargetTable    NVARCHAR(200),
    @BusinessKeyCol NVARCHAR(100),
    @AttributeCols  NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @setClause NVARCHAR(MAX) = (
        SELECT STRING_AGG(CAST('d.' + LTRIM(RTRIM(value)) + ' = s.' + LTRIM(RTRIM(value)) AS NVARCHAR(MAX)), N', ')
        FROM STRING_SPLIT(@AttributeCols, ',')
    );
    DECLARE @insertCols NVARCHAR(MAX) = @BusinessKeyCol + N', ' + @AttributeCols + N', LastUpdated';
    DECLARE @selectCols NVARCHAR(MAX) = (
        SELECT STRING_AGG(CAST('s.' + LTRIM(RTRIM(value)) AS NVARCHAR(MAX)), N', ')
        FROM STRING_SPLIT(@BusinessKeyCol + ',' + @AttributeCols, ',')
    );

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT *, ROW_NUMBER() OVER (PARTITION BY ' + @BusinessKeyCol + N' ORDER BY ' + @BusinessKeyCol + N') AS rn
        INTO #dedup
        FROM ' + @StagingTable + N';

        UPDATE d SET ' + @setClause + N', LastUpdated = SYSUTCDATETIME()
        FROM ' + @TargetTable + N' d INNER JOIN #dedup s
            ON d.' + @BusinessKeyCol + N' = s.' + @BusinessKeyCol + N'
        WHERE s.rn = 1;

        INSERT INTO ' + @TargetTable + N' (' + @insertCols + N')
        SELECT ' + @selectCols + N', SYSUTCDATETIME()
        FROM #dedup s
        WHERE s.rn = 1
          AND NOT EXISTS (SELECT 1 FROM ' + @TargetTable + N' d WHERE d.' + @BusinessKeyCol + N' = s.' + @BusinessKeyCol + N');

        DROP TABLE #dedup;';

    EXEC sp_executesql @sql;
END
GO

IF OBJECT_ID('dw.usp_LoadDimCustomer') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimCustomer;
GO
CREATE PROCEDURE dw.usp_LoadDimCustomer AS
BEGIN
    SET NOCOUNT ON;
    SELECT *, ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY CustomerId) AS rn
    INTO #custDedup FROM stg.Customer;

    UPDATE d SET EffectiveTo = SYSUTCDATETIME(), IsCurrent = 0, LastUpdated = SYSUTCDATETIME()
    FROM dw.DimCustomer d INNER JOIN #custDedup s ON d.CustomerId = s.CustomerId
    WHERE s.rn = 1 AND d.IsCurrent = 1
      AND (ISNULL(d.CustomerName,'') <> ISNULL(s.CustomerName,'')
        OR ISNULL(d.City,'')         <> ISNULL(s.City,'')
        OR ISNULL(d.Country,'')      <> ISNULL(s.Country,'')
        OR ISNULL(d.Segment,'')      <> ISNULL(s.Segment,''));

    INSERT INTO dw.DimCustomer (CustomerId, CustomerName, Email, City, Country, Segment, EffectiveFrom, EffectiveTo, IsCurrent, LastUpdated)
    SELECT s.CustomerId, s.CustomerName, s.Email, s.City, s.Country, s.Segment, SYSUTCDATETIME(), NULL, 1, SYSUTCDATETIME()
    FROM #custDedup s
    WHERE s.rn = 1
      AND NOT EXISTS (
        SELECT 1 FROM dw.DimCustomer d
        WHERE d.CustomerId = s.CustomerId AND d.IsCurrent = 1
          AND ISNULL(d.CustomerName,'') = ISNULL(s.CustomerName,'')
          AND ISNULL(d.City,'')         = ISNULL(s.City,'')
          AND ISNULL(d.Country,'')      = ISNULL(s.Country,'')
          AND ISNULL(d.Segment,'')      = ISNULL(s.Segment,'')
      );

    DROP TABLE #custDedup;
END
GO

IF OBJECT_ID('dw.usp_LoadFactSales') IS NOT NULL DROP PROCEDURE dw.usp_LoadFactSales;
GO
CREATE PROCEDURE dw.usp_LoadFactSales AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dw.FactSales;

    SELECT *, ROW_NUMBER() OVER (PARTITION BY OrderId, LineNumber ORDER BY OrderId) AS rn
    INTO #salesDedup FROM stg.SalesOrder;

    INSERT INTO dw.FactSales (DateKey, ProductKey, CustomerKey, StoreKey, OrderId, LineNumber,
                               Quantity, UnitPrice, DiscountAmount, NetAmount, LoadTimestamp)
    SELECT
        CONVERT(INT, CONVERT(VARCHAR(8), s.OrderDate, 112)) AS DateKey,
        p.ProductKey, c.CustomerKey, st.StoreKey,
        s.OrderId, s.LineNumber, s.Quantity, s.UnitPrice, ISNULL(s.DiscountAmount, 0),
        s.Quantity * s.UnitPrice - ISNULL(s.DiscountAmount, 0),
        SYSUTCDATETIME()
    FROM #salesDedup s
    INNER JOIN dw.DimProduct  p  ON p.ProductId  = s.ProductId  AND p.IsActive = 1
    INNER JOIN dw.DimCustomer c  ON c.CustomerId = s.CustomerId AND c.IsCurrent = 1
    INNER JOIN dw.DimStore    st ON st.StoreId   = s.StoreId
    WHERE s.rn = 1;

    DROP TABLE #salesDedup;
END
GO

PRINT 'loaders hardened against duplicate landing rows';
