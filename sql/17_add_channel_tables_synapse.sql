-- The Channel entity's metadata was added, but its two physical tables
-- (Synapse landing + target dimension) still need to exist, exactly like
-- any other dimension. This is a one-time table creation, NOT a pipeline
-- or stored procedure change.

IF OBJECT_ID('stg.Channel') IS NOT NULL DROP TABLE stg.Channel;
CREATE TABLE stg.Channel (
    ChannelId   NVARCHAR(50)  NULL,
    ChannelName NVARCHAR(100) NULL
) WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
GO

IF OBJECT_ID('dw.DimChannel') IS NOT NULL DROP TABLE dw.DimChannel;
CREATE TABLE dw.DimChannel (
    ChannelKey  INT IDENTITY(1,1) NOT NULL,
    ChannelId   NVARCHAR(50)  NOT NULL,
    ChannelName NVARCHAR(100) NULL,
    LastUpdated DATETIME2(3) NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX (ChannelKey));
GO

PRINT 'Channel tables created in Synapse';
