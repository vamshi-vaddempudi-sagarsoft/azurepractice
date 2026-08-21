-- ============================================================
-- 02_seed_metadata.sql
-- Fills in the "settings tables" (meta schema) describing our 4 starting entities:
-- Product, Customer, Store (dimensions) and SalesOrder (fact).
-- Channel (the 5th, "prove it's generic" entity) is added later, on purpose.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP')
    INSERT INTO meta.SourceSystem (SourceSystemName, Description) VALUES ('SalesERP', 'Practice sales source system');
GO

DELETE FROM meta.ColumnMapping;
DELETE FROM meta.ValidationRule;
DELETE FROM meta.EntityConfig;
GO

INSERT INTO meta.EntityConfig
    (SourceSystemId, EntityName, EntityType, SourceContainer, SourcePathPattern, SourceFileFormat,
     SourceDelimiter, HasHeader, StagingTable, TargetSchema, TargetTable, LoadType,
     BusinessKeyColumns, WatermarkColumn, SCDType, Priority)
SELECT SourceSystemId, 'Product', 'Dimension', 'samplecontainer', 'sales/product/', 'csv',
       ',', 1, 'stg.Product', 'dw', 'dw.DimProduct', 'Full', 'ProductId', NULL, 1, 10
FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP';

INSERT INTO meta.EntityConfig
    (SourceSystemId, EntityName, EntityType, SourceContainer, SourcePathPattern, SourceFileFormat,
     SourceDelimiter, HasHeader, StagingTable, TargetSchema, TargetTable, LoadType,
     BusinessKeyColumns, WatermarkColumn, SCDType, Priority)
SELECT SourceSystemId, 'Customer', 'Dimension', 'samplecontainer', 'sales/customer/', 'csv',
       ',', 1, 'stg.Customer', 'dw', 'dw.DimCustomer', 'Full', 'CustomerId', NULL, 2, 20
FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP';

INSERT INTO meta.EntityConfig
    (SourceSystemId, EntityName, EntityType, SourceContainer, SourcePathPattern, SourceFileFormat,
     SourceDelimiter, HasHeader, StagingTable, TargetSchema, TargetTable, LoadType,
     BusinessKeyColumns, WatermarkColumn, SCDType, Priority)
SELECT SourceSystemId, 'Store', 'Dimension', 'samplecontainer', 'sales/store/', 'csv',
       ',', 1, 'stg.Store', 'dw', 'dw.DimStore', 'Full', 'StoreId', NULL, 1, 30
FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP';

INSERT INTO meta.EntityConfig
    (SourceSystemId, EntityName, EntityType, SourceContainer, SourcePathPattern, SourceFileFormat,
     SourceDelimiter, HasHeader, StagingTable, TargetSchema, TargetTable, LoadType,
     BusinessKeyColumns, WatermarkColumn, SCDType, Priority)
SELECT SourceSystemId, 'SalesOrder', 'Fact', 'samplecontainer', 'sales/orders/', 'csv',
       ',', 1, 'stg.SalesOrder', 'dw', 'dw.FactSales', 'Incremental',
       'OrderId,LineNumber', 'OrderDate', NULL, 50
FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP';
GO

-- ---------------------------------------------------------- Column mappings
INSERT INTO meta.ColumnMapping (EntityId, SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
SELECT EntityId, v.SourceColumn, v.TargetColumn, v.DataType, v.IsNullable, v.IsBusinessKey, v.IsWatermark, v.Ordinal
FROM meta.EntityConfig e
CROSS APPLY (VALUES
    ('ProductId','ProductId','NVARCHAR(50)',0,1,0,1),
    ('ProductName','ProductName','NVARCHAR(200)',1,0,0,2),
    ('Category','Category','NVARCHAR(100)',1,0,0,3),
    ('SubCategory','SubCategory','NVARCHAR(100)',1,0,0,4),
    ('UnitPrice','UnitPrice','DECIMAL(18,4)',1,0,0,5),
    ('IsActive','IsActive','BIT',1,0,0,6)
) AS v(SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
WHERE e.EntityName = 'Product';

INSERT INTO meta.ColumnMapping (EntityId, SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
SELECT EntityId, v.SourceColumn, v.TargetColumn, v.DataType, v.IsNullable, v.IsBusinessKey, v.IsWatermark, v.Ordinal
FROM meta.EntityConfig e
CROSS APPLY (VALUES
    ('CustomerId','CustomerId','NVARCHAR(50)',0,1,0,1),
    ('CustomerName','CustomerName','NVARCHAR(200)',0,0,0,2),
    ('Email','Email','NVARCHAR(256)',1,0,0,3),
    ('City','City','NVARCHAR(100)',1,0,0,4),
    ('Country','Country','NVARCHAR(100)',1,0,0,5),
    ('Segment','Segment','NVARCHAR(50)',1,0,0,6)
) AS v(SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
WHERE e.EntityName = 'Customer';

INSERT INTO meta.ColumnMapping (EntityId, SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
SELECT EntityId, v.SourceColumn, v.TargetColumn, v.DataType, v.IsNullable, v.IsBusinessKey, v.IsWatermark, v.Ordinal
FROM meta.EntityConfig e
CROSS APPLY (VALUES
    ('StoreId','StoreId','NVARCHAR(50)',0,1,0,1),
    ('StoreName','StoreName','NVARCHAR(200)',0,0,0,2),
    ('Region','Region','NVARCHAR(100)',1,0,0,3),
    ('City','City','NVARCHAR(100)',1,0,0,4)
) AS v(SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
WHERE e.EntityName = 'Store';

INSERT INTO meta.ColumnMapping (EntityId, SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
SELECT EntityId, v.SourceColumn, v.TargetColumn, v.DataType, v.IsNullable, v.IsBusinessKey, v.IsWatermark, v.Ordinal
FROM meta.EntityConfig e
CROSS APPLY (VALUES
    ('OrderId','OrderId','NVARCHAR(50)',0,1,0,1),
    ('LineNumber','LineNumber','INT',0,1,0,2),
    ('OrderDate','OrderDate','DATE',0,0,1,3),
    ('CustomerId','CustomerId','NVARCHAR(50)',0,0,0,4),
    ('ProductId','ProductId','NVARCHAR(50)',0,0,0,5),
    ('StoreId','StoreId','NVARCHAR(50)',0,0,0,6),
    ('ChannelId','ChannelId','NVARCHAR(50)',1,0,0,7),
    ('Quantity','Quantity','INT',0,0,0,8),
    ('UnitPrice','UnitPrice','DECIMAL(18,4)',0,0,0,9),
    ('DiscountAmount','DiscountAmount','DECIMAL(18,4)',1,0,0,10)
) AS v(SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
WHERE e.EntityName = 'SalesOrder';
GO

-- ---------------------------------------------------------- Validation rules
-- Required rule types only: NotNull, Range, Referential
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Product_ProductId_Required', 'NotNull', 'ProductId', 'ProductId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'Product';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Product_Name_Required', 'NotNull', 'ProductName', 'ProductName IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'Product';

INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Customer_CustomerId_Required', 'NotNull', 'CustomerId', 'CustomerId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'Customer';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Customer_Name_Required', 'NotNull', 'CustomerName', 'CustomerName IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'Customer';

INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Store_StoreId_Required', 'NotNull', 'StoreId', 'StoreId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'Store';

INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_OrderId_Required', 'NotNull', 'OrderId', 'OrderId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_CustomerId_Required', 'NotNull', 'CustomerId', 'CustomerId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_ProductId_Required', 'NotNull', 'ProductId', 'ProductId IS NOT NULL' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_Quantity_Positive', 'Range', 'Quantity', 'value > 0' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_ProductId_Exists', 'Referential', 'ProductId', 'stg.Product' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Sales_CustomerId_Exists', 'Referential', 'CustomerId', 'stg.Customer' FROM meta.EntityConfig WHERE EntityName = 'SalesOrder';
GO

PRINT 'metadata seeded';
SELECT EntityId, EntityName, EntityType, StagingTable, TargetTable, BusinessKeyColumns, SCDType, Priority FROM meta.EntityConfig ORDER BY Priority;
SELECT EntityId, COUNT(*) AS MappingCount FROM meta.ColumnMapping GROUP BY EntityId;
SELECT EntityId, COUNT(*) AS RuleCount FROM meta.ValidationRule GROUP BY EntityId;
