-- ============================================================
-- 12_generic_dim_loader.sql
-- Runs against: salesdw (Synapse)
-- One SCD1 (overwrite-style) dimension loader that works for ANY simple
-- dimension, as long as it's told: which landing table, which target table,
-- the business key column, and the list of attribute columns to copy across.
-- ADF supplies those four things by reading meta.EntityConfig / ColumnMapping -
-- this procedure itself never mentions Product, Store, or any entity name.
-- ============================================================

IF OBJECT_ID('dw.usp_LoadDimGeneric') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimGeneric;
GO
CREATE PROCEDURE dw.usp_LoadDimGeneric
    @StagingTable   NVARCHAR(200),   -- e.g. 'stg.Channel'
    @TargetTable    NVARCHAR(200),   -- e.g. 'dw.DimChannel'
    @BusinessKeyCol NVARCHAR(100),   -- e.g. 'ChannelId'
    @AttributeCols  NVARCHAR(1000)   -- comma list, e.g. 'ChannelName'
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

    DECLARE @sql NVARCHAR(MAX) =
        N'UPDATE d SET ' + @setClause + N', LastUpdated = SYSUTCDATETIME()
          FROM ' + @TargetTable + N' d INNER JOIN ' + @StagingTable + N' s
            ON d.' + @BusinessKeyCol + N' = s.' + @BusinessKeyCol + N';

          INSERT INTO ' + @TargetTable + N' (' + @insertCols + N')
          SELECT ' + @selectCols + N', SYSUTCDATETIME()
          FROM ' + @StagingTable + N' s
          WHERE NOT EXISTS (SELECT 1 FROM ' + @TargetTable + N' d WHERE d.' + @BusinessKeyCol + N' = s.' + @BusinessKeyCol + N');';

    EXEC sp_executesql @sql;
END
GO

-- Re-point Product and Store onto the generic loader, to prove it's not just
-- theoretical - the SAME procedure now runs both of them.
EXEC dw.usp_LoadDimGeneric @StagingTable='stg.Product', @TargetTable='dw.DimProduct',
     @BusinessKeyCol='ProductId', @AttributeCols='ProductName,Category,SubCategory,UnitPrice,IsActive';
EXEC dw.usp_LoadDimGeneric @StagingTable='stg.Store', @TargetTable='dw.DimStore',
     @BusinessKeyCol='StoreId', @AttributeCols='StoreName,Region,City';

PRINT '--- Generic loader verification (should match earlier counts) ---';
SELECT 'DimProduct' T, COUNT(*) C FROM dw.DimProduct
UNION ALL SELECT 'DimStore', COUNT(*) FROM dw.DimStore;
