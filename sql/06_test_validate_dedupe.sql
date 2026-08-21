DECLARE @BatchId UNIQUEIDENTIFIER = NEWID();
PRINT CONCAT('BatchId used: ', CAST(@BatchId AS NVARCHAR(50)));

EXEC meta.usp_ValidateEntity @EntityId = 1, @BatchId = @BatchId;  -- Product
EXEC meta.usp_ValidateEntity @EntityId = 2, @BatchId = @BatchId;  -- Customer
EXEC meta.usp_ValidateEntity @EntityId = 3, @BatchId = @BatchId;  -- Store
EXEC meta.usp_ValidateEntity @EntityId = 4, @BatchId = @BatchId;  -- SalesOrder

EXEC meta.usp_DeduplicateEntity @EntityId = 4, @BatchId = @BatchId;  -- SalesOrder

PRINT '--- Rejected rows (reasons) ---';
SELECT EntityName, ErrorReason, SourceRowId FROM stg.ErrorRows ORDER BY ErrorRowId;

PRINT '--- Duplicate rows removed ---';
SELECT EntityName, BusinessKey, SourceRowId FROM stg.DuplicateLog;

PRINT '--- Remaining row counts after validate + dedupe ---';
SELECT 'SalesOrder' AS TableName, COUNT(*) AS Rows FROM stg.SalesOrder;
SELECT TOP 3 * FROM stg.SalesOrder WHERE OrderId = 'ORD-9005';
