-- ============================================================
-- 05_generic_validate_and_dedupe.sql
-- Runs against: sampledatabase
-- The two "engine" procedures. Neither one hardcodes a table or column name -
-- both read meta.EntityConfig / meta.ValidationRule and build their own SQL.
-- ============================================================

ALTER TABLE stg.ErrorRows ADD SourceRowId BIGINT NULL;
GO
ALTER TABLE stg.DuplicateLog ADD SourceRowId BIGINT NULL;
GO

-- ------------------------------------------------------------
-- meta.usp_ValidateEntity
-- Loops over every active rule for the entity and logs failing rows to
-- stg.ErrorRows. Works the same regardless of which entity/table it's given.
-- ------------------------------------------------------------
IF OBJECT_ID('meta.usp_ValidateEntity') IS NOT NULL DROP PROCEDURE meta.usp_ValidateEntity;
GO
CREATE PROCEDURE meta.usp_ValidateEntity
    @EntityId INT,
    @BatchId  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StagingTable NVARCHAR(200), @EntityName NVARCHAR(100);
    SELECT @StagingTable = StagingTable, @EntityName = EntityName
    FROM meta.EntityConfig WHERE EntityId = @EntityId;

    DECLARE @RuleName NVARCHAR(100), @RuleType NVARCHAR(50), @ColumnName NVARCHAR(200), @RuleExpression NVARCHAR(1000);
    DECLARE @sql NVARCHAR(MAX);

    DECLARE rule_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT RuleName, RuleType, ColumnName, RuleExpression
        FROM meta.ValidationRule WHERE EntityId = @EntityId AND IsActive = 1;

    OPEN rule_cursor;
    FETCH NEXT FROM rule_cursor INTO @RuleName, @RuleType, @ColumnName, @RuleExpression;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @RuleType = 'NotNull'
            SET @sql = N'INSERT INTO stg.ErrorRows (EntityName, BatchId, SourceRowId, RowData, ErrorReason)
                SELECT @p_EntityName, @p_BatchId, s.StagingRowId, (SELECT s.* FOR JSON PATH), @p_Reason
                FROM ' + @StagingTable + N' s WHERE s.' + @ColumnName + N' IS NULL';
        ELSE IF @RuleType = 'Range'
            SET @sql = N'INSERT INTO stg.ErrorRows (EntityName, BatchId, SourceRowId, RowData, ErrorReason)
                SELECT @p_EntityName, @p_BatchId, s.StagingRowId, (SELECT s.* FOR JSON PATH), @p_Reason
                FROM ' + @StagingTable + N' s WHERE s.' + @ColumnName + N' IS NOT NULL AND NOT (' +
                REPLACE(@RuleExpression, 'value', @ColumnName) + N')';
        ELSE IF @RuleType = 'Referential'
            SET @sql = N'INSERT INTO stg.ErrorRows (EntityName, BatchId, SourceRowId, RowData, ErrorReason)
                SELECT @p_EntityName, @p_BatchId, s.StagingRowId, (SELECT s.* FOR JSON PATH), @p_Reason
                FROM ' + @StagingTable + N' s WHERE s.' + @ColumnName + N' IS NOT NULL AND NOT EXISTS
                (SELECT 1 FROM ' + @RuleExpression + N' r WHERE r.' + @ColumnName + N' = s.' + @ColumnName + N')';
        ELSE
            SET @sql = NULL;

        IF @sql IS NOT NULL
            EXEC sp_executesql @sql,
                N'@p_EntityName NVARCHAR(100), @p_BatchId UNIQUEIDENTIFIER, @p_Reason NVARCHAR(200)',
                @EntityName, @BatchId, @RuleName;

        FETCH NEXT FROM rule_cursor INTO @RuleName, @RuleType, @ColumnName, @RuleExpression;
    END
    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;
END
GO

-- ------------------------------------------------------------
-- meta.usp_DeduplicateEntity
-- Keeps the latest row per business key (as configured in meta.EntityConfig),
-- moves the earlier duplicate(s) to stg.DuplicateLog, and DELETEs them from
-- staging. Same procedure regardless of what the business key columns are.
-- Rows already flagged by validation (in stg.ErrorRows for this batch) are
-- excluded first, so a bad row can't "win" a duplicate contest.
-- ------------------------------------------------------------
IF OBJECT_ID('meta.usp_DeduplicateEntity') IS NOT NULL DROP PROCEDURE meta.usp_DeduplicateEntity;
GO
CREATE PROCEDURE meta.usp_DeduplicateEntity
    @EntityId INT,
    @BatchId  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StagingTable NVARCHAR(200), @EntityName NVARCHAR(100), @BusinessKeyColumns NVARCHAR(500), @WatermarkColumn NVARCHAR(100);
    SELECT @StagingTable = StagingTable, @EntityName = EntityName,
           @BusinessKeyColumns = BusinessKeyColumns, @WatermarkColumn = WatermarkColumn
    FROM meta.EntityConfig WHERE EntityId = @EntityId;

    DECLARE @OrderColumn NVARCHAR(100) = ISNULL(@WatermarkColumn, 'StagingRowId');

    -- A T-SQL "WITH ... AS" CTE is only visible to the ONE statement right after it,
    -- so the ranking has to be materialised into a real (temp) table before we can
    -- both INSERT the duplicates into the log AND DELETE them from staging.
    DECLARE @sql NVARCHAR(MAX) = N'
    SELECT s.*, ROW_NUMBER() OVER (
            PARTITION BY ' + @BusinessKeyColumns + N'
            ORDER BY ' + @OrderColumn + N' DESC, StagingRowId DESC
        ) AS rn
    INTO #ranked
    FROM ' + @StagingTable + N' s
    WHERE s.StagingRowId NOT IN (
        SELECT SourceRowId FROM stg.ErrorRows WHERE EntityName = @p_EntityName AND BatchId = @p_BatchId AND SourceRowId IS NOT NULL
    );

    INSERT INTO stg.DuplicateLog (EntityName, BusinessKey, SourceRowId, RowData)
    SELECT @p_EntityName,
           ' + (SELECT STRING_AGG(CAST('CAST(' + LTRIM(RTRIM(value)) + ' AS NVARCHAR(100))' AS NVARCHAR(MAX)), N' + ''|'' + ')
                     WITHIN GROUP (ORDER BY ordinal)
                FROM STRING_SPLIT(@BusinessKeyColumns, ',', 1)) + N',
           StagingRowId,
           (SELECT r.* FOR JSON PATH)
    FROM #ranked r WHERE rn > 1;

    DELETE s FROM ' + @StagingTable + N' s
    WHERE EXISTS (
        SELECT 1 FROM #ranked r WHERE r.rn > 1 AND r.StagingRowId = s.StagingRowId
    );

    DROP TABLE #ranked;';

    EXEC sp_executesql @sql,
        N'@p_EntityName NVARCHAR(100), @p_BatchId UNIQUEIDENTIFIER',
        @EntityName, @BatchId;
END
GO

PRINT 'generic validate + dedupe procedures created';
