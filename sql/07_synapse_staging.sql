-- ============================================================
-- 07_synapse_staging.sql
-- Runs against: salesdw (Synapse)
-- A small landing area inside the warehouse itself. The staging database
-- (sampledatabase) does the validation + dedupe; only the CLEAN, deduplicated
-- rows get copied here (by ADF's Copy Activity in the real pipeline) before
-- the dimension/fact load procedures merge them into dw.* tables.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
GO

IF OBJECT_ID('stg.Product') IS NOT NULL DROP TABLE stg.Product;
CREATE TABLE stg.Product (
    ProductId    NVARCHAR(50)  NULL,
    ProductName  NVARCHAR(200) NULL,
    Category     NVARCHAR(100) NULL,
    SubCategory  NVARCHAR(100) NULL,
    UnitPrice    DECIMAL(18,4) NULL,
    IsActive     BIT           NULL
) WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
GO

IF OBJECT_ID('stg.Customer') IS NOT NULL DROP TABLE stg.Customer;
CREATE TABLE stg.Customer (
    CustomerId   NVARCHAR(50)  NULL,
    CustomerName NVARCHAR(200) NULL,
    Email        NVARCHAR(256) NULL,
    City         NVARCHAR(100) NULL,
    Country      NVARCHAR(100) NULL,
    Segment      NVARCHAR(50)  NULL
) WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
GO

IF OBJECT_ID('stg.Store') IS NOT NULL DROP TABLE stg.Store;
CREATE TABLE stg.Store (
    StoreId    NVARCHAR(50)  NULL,
    StoreName  NVARCHAR(200) NULL,
    Region     NVARCHAR(100) NULL,
    City       NVARCHAR(100) NULL
) WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
GO

IF OBJECT_ID('stg.SalesOrder') IS NOT NULL DROP TABLE stg.SalesOrder;
CREATE TABLE stg.SalesOrder (
    OrderId        NVARCHAR(50)  NULL,
    LineNumber     INT           NULL,
    OrderDate      DATE          NULL,
    CustomerId     NVARCHAR(50)  NULL,
    ProductId      NVARCHAR(50)  NULL,
    StoreId        NVARCHAR(50)  NULL,
    ChannelId      NVARCHAR(50)  NULL,
    Quantity       INT           NULL,
    UnitPrice      DECIMAL(18,4) NULL,
    DiscountAmount DECIMAL(18,4) NULL
) WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
GO

PRINT 'Synapse landing tables created';
