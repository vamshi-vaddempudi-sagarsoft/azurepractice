-- ============================================================
-- 15_add_channel_entity.sql
-- Runs against: sampledatabase
-- Adds the 5th entity (Channel) PURELY through metadata rows.
-- No pipeline JSON, no new stored procedure, no code change of any kind.
-- The Channel table (stg.Channel in both databases, dw.DimChannel in Synapse)
-- already exists from the very first schema script - only the metadata is new.
-- ============================================================

INSERT INTO meta.EntityConfig
    (SourceSystemId, EntityName, EntityType, SourceContainer, SourcePathPattern, SourceFileFormat,
     SourceDelimiter, HasHeader, StagingTable, TargetSchema, TargetTable, LoadType,
     BusinessKeyColumns, WatermarkColumn, SCDType, Priority, SourceFileName)
SELECT SourceSystemId, 'Channel', 'Dimension', 'samplecontainer', 'sales/channel/', 'csv',
       ',', 1, 'stg.Channel', 'dw', 'dw.DimChannel', 'Full', 'ChannelId', NULL, 1, 5, 'channel.csv'
FROM meta.SourceSystem WHERE SourceSystemName = 'SalesERP'
  AND NOT EXISTS (SELECT 1 FROM meta.EntityConfig WHERE EntityName = 'Channel');

INSERT INTO meta.ColumnMapping (EntityId, SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
SELECT EntityId, v.SourceColumn, v.TargetColumn, v.DataType, v.IsNullable, v.IsBusinessKey, v.IsWatermark, v.Ordinal
FROM meta.EntityConfig e
CROSS APPLY (VALUES
    ('ChannelId','ChannelId','NVARCHAR(50)',0,1,0,1),
    ('ChannelName','ChannelName','NVARCHAR(100)',1,0,0,2)
) AS v(SourceColumn, TargetColumn, DataType, IsNullable, IsBusinessKey, IsWatermark, Ordinal)
WHERE e.EntityName = 'Channel'
  AND NOT EXISTS (SELECT 1 FROM meta.ColumnMapping cm WHERE cm.EntityId = e.EntityId);

INSERT INTO meta.ValidationRule (EntityId, RuleName, RuleType, ColumnName, RuleExpression)
SELECT EntityId, 'Channel_ChannelId_Required', 'NotNull', 'ChannelId', 'ChannelId IS NOT NULL'
FROM meta.EntityConfig e WHERE e.EntityName = 'Channel'
  AND NOT EXISTS (SELECT 1 FROM meta.ValidationRule vr WHERE vr.EntityId = e.EntityId);

PRINT 'Channel entity registered - zero pipeline or procedure changes made';
SELECT EntityId, EntityName, EntityType, StagingTable, TargetTable, BusinessKeyColumns, Priority FROM meta.EntityConfig ORDER BY Priority;
