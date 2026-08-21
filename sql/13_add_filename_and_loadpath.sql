IF COL_LENGTH('meta.EntityConfig', 'SourceFileName') IS NULL
    ALTER TABLE meta.EntityConfig ADD SourceFileName NVARCHAR(200) NULL;
GO
UPDATE meta.EntityConfig SET SourceFileName = 'product.csv' WHERE EntityName = 'Product';
UPDATE meta.EntityConfig SET SourceFileName = 'customer.csv' WHERE EntityName = 'Customer';
UPDATE meta.EntityConfig SET SourceFileName = 'store.csv' WHERE EntityName = 'Store';
UPDATE meta.EntityConfig SET SourceFileName = 'sales_order.csv', SourcePathPattern = 'sales/orders/2026/08/21/'
    WHERE EntityName = 'SalesOrder';
GO
SELECT EntityName, SourceContainer, SourcePathPattern, SourceFileName, StagingTable, TargetTable FROM meta.EntityConfig;
