-- ============================================================
-- 01_meta_and_staging.sql
-- Runs against: sampledatabase (Azure SQL DB)
-- Creates: meta schema (the "settings tables") + stg schema (the "landing tables")
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'meta') EXEC('CREATE SCHEMA meta');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
GO

-- ---------------------------------------------------------- meta: settings tables
IF OBJECT_ID('meta.SourceSystem') IS NOT NULL DROP TABLE meta.SourceSystem;
CREATE TABLE meta.SourceSystem (
    SourceSystemId   INT IDENTITY(1,1) PRIMARY KEY,
    SourceSystemName NVARCHAR(100) NOT NULL UNIQUE,
    Description      NVARCHAR(500) NULL,
    IsActive         BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('meta.EntityConfig') IS NOT NULL DROP TABLE meta.EntityConfig;
CREATE TABLE meta.EntityConfig (
    EntityId            INT IDENTITY(1,1) PRIMARY KEY,
    SourceSystemId      INT NOT NULL,
    EntityName          NVARCHAR(100) NOT NULL,
    EntityType          NVARCHAR(20)  NOT NULL,   -- Dimension / Fact
    SourceContainer     NVARCHAR(100) NOT NULL,
    SourcePathPattern   NVARCHAR(500) NOT NULL,
    SourceFileFormat    NVARCHAR(20)  NOT NULL,   -- csv / json
    SourceDelimiter     NVARCHAR(5)   NULL,
    HasHeader           BIT           NOT NULL DEFAULT 1,
    StagingTable        NVARCHAR(200) NOT NULL,   -- e.g. stg.SalesOrder
    TargetSchema        NVARCHAR(50)  NOT NULL,   -- dw
    TargetTable         NVARCHAR(200) NOT NULL,   -- e.g. dw.FactSales
    LoadType            NVARCHAR(20)  NOT NULL,   -- Full / Incremental
    BusinessKeyColumns  NVARCHAR(500) NOT NULL,
    WatermarkColumn     NVARCHAR(100) NULL,
    SCDType             TINYINT       NULL,       -- 1 or 2, dimensions only
    IsActive            BIT           NOT NULL DEFAULT 1,
    Priority            INT           NOT NULL DEFAULT 100,
    CreatedOn           DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('meta.ColumnMapping') IS NOT NULL DROP TABLE meta.ColumnMapping;
CREATE TABLE meta.ColumnMapping (
    MappingId       INT IDENTITY(1,1) PRIMARY KEY,
    EntityId        INT NOT NULL,
    SourceColumn    NVARCHAR(200) NOT NULL,
    TargetColumn    NVARCHAR(200) NOT NULL,
    DataType        NVARCHAR(50)  NOT NULL,
    IsNullable      BIT           NOT NULL DEFAULT 1,
    IsBusinessKey   BIT           NOT NULL DEFAULT 0,
    IsWatermark     BIT           NOT NULL DEFAULT 0,
    TransformExpr   NVARCHAR(500) NULL,
    Ordinal         INT           NOT NULL
);
GO

IF OBJECT_ID('meta.ValidationRule') IS NOT NULL DROP TABLE meta.ValidationRule;
CREATE TABLE meta.ValidationRule (
    RuleId          INT IDENTITY(1,1) PRIMARY KEY,
    EntityId        INT NOT NULL,
    RuleName        NVARCHAR(100) NOT NULL,
    RuleType        NVARCHAR(50)  NOT NULL,   -- NotNull / Range / Referential
    ColumnName      NVARCHAR(200) NULL,
    RuleExpression  NVARCHAR(1000) NOT NULL,
    ErrorSeverity   NVARCHAR(20)  NOT NULL DEFAULT 'Error',
    IsActive        BIT           NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('meta.PipelineRunLog') IS NOT NULL DROP TABLE meta.PipelineRunLog;
CREATE TABLE meta.PipelineRunLog (
    RunLogId        BIGINT IDENTITY(1,1) PRIMARY KEY,
    PipelineName    NVARCHAR(200),
    ADFRunId        NVARCHAR(100) NULL,
    EntityId        INT NULL,
    StartTimeUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    EndTimeUtc      DATETIME2(3) NULL,
    Status          NVARCHAR(20) NOT NULL DEFAULT 'Running',
    RowsRead        BIGINT NULL,
    RowsInserted    BIGINT NULL,
    RowsUpdated     BIGINT NULL,
    RowsRejected    BIGINT NULL,
    ErrorMessage    NVARCHAR(MAX) NULL
);
GO

IF OBJECT_ID('meta.FileLog') IS NOT NULL DROP TABLE meta.FileLog;
CREATE TABLE meta.FileLog (
    FileLogId       BIGINT IDENTITY(1,1) PRIMARY KEY,
    EntityId        INT NULL,
    FilePath        NVARCHAR(1000),
    FileName        NVARCHAR(500),
    FileRowCount    BIGINT NULL,
    ValidationStatus NVARCHAR(20) NULL,   -- Passed / Failed / Partial
    ProcessedOn     DATETIME2(3) DEFAULT SYSUTCDATETIME()
);
GO

-- ---------------------------------------------------------- stg: landing tables
IF OBJECT_ID('stg.SalesOrder') IS NOT NULL DROP TABLE stg.SalesOrder;
CREATE TABLE stg.SalesOrder (
    StagingRowId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderId         NVARCHAR(50)  NULL,
    LineNumber      INT           NULL,
    OrderDate       DATE          NULL,
    CustomerId      NVARCHAR(50)  NULL,
    ProductId       NVARCHAR(50)  NULL,
    StoreId         NVARCHAR(50)  NULL,
    ChannelId       NVARCHAR(50)  NULL,
    Quantity        INT           NULL,
    UnitPrice       DECIMAL(18,4) NULL,
    DiscountAmount  DECIMAL(18,4) NULL,
    LoadTimestamp   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFile      NVARCHAR(500) NULL
);
GO

IF OBJECT_ID('stg.Product') IS NOT NULL DROP TABLE stg.Product;
CREATE TABLE stg.Product (
    StagingRowId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductId       NVARCHAR(50)  NULL,
    ProductName     NVARCHAR(200) NULL,
    Category        NVARCHAR(100) NULL,
    SubCategory     NVARCHAR(100) NULL,
    UnitPrice       DECIMAL(18,4) NULL,
    IsActive        BIT           NULL,
    LoadTimestamp   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFile      NVARCHAR(500) NULL
);
GO

IF OBJECT_ID('stg.Customer') IS NOT NULL DROP TABLE stg.Customer;
CREATE TABLE stg.Customer (
    StagingRowId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerId      NVARCHAR(50)  NULL,
    CustomerName    NVARCHAR(200) NULL,
    Email           NVARCHAR(256) NULL,
    City            NVARCHAR(100) NULL,
    Country         NVARCHAR(100) NULL,
    Segment         NVARCHAR(50)  NULL,
    LoadTimestamp   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFile      NVARCHAR(500) NULL
);
GO

IF OBJECT_ID('stg.Store') IS NOT NULL DROP TABLE stg.Store;
CREATE TABLE stg.Store (
    StagingRowId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    StoreId         NVARCHAR(50)  NULL,
    StoreName       NVARCHAR(200) NULL,
    Region          NVARCHAR(100) NULL,
    City            NVARCHAR(100) NULL,
    LoadTimestamp   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFile      NVARCHAR(500) NULL
);
GO

-- The 5th, deliberately trivial entity: added later purely via metadata to prove
-- the pipeline is genuinely generic, not hardcoded per entity.
IF OBJECT_ID('stg.Channel') IS NOT NULL DROP TABLE stg.Channel;
CREATE TABLE stg.Channel (
    StagingRowId    BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChannelId       NVARCHAR(50)  NULL,
    ChannelName     NVARCHAR(100) NULL,
    LoadTimestamp   DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceFile      NVARCHAR(500) NULL
);
GO

IF OBJECT_ID('stg.ErrorRows') IS NOT NULL DROP TABLE stg.ErrorRows;
CREATE TABLE stg.ErrorRows (
    ErrorRowId      BIGINT IDENTITY(1,1) PRIMARY KEY,
    EntityName      NVARCHAR(100),
    BatchId         UNIQUEIDENTIFIER,
    RowData         NVARCHAR(MAX),
    ErrorReason     NVARCHAR(500),
    ErrorTimeUtc    DATETIME2(3) DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('stg.DuplicateLog') IS NOT NULL DROP TABLE stg.DuplicateLog;
CREATE TABLE stg.DuplicateLog (
    DuplicateLogId  BIGINT IDENTITY(1,1) PRIMARY KEY,
    EntityName      NVARCHAR(100),
    BusinessKey     NVARCHAR(200),
    RowData         NVARCHAR(MAX),
    DetectedOn      DATETIME2(3) DEFAULT SYSUTCDATETIME()
);
GO

PRINT 'meta + stg schema created successfully';
