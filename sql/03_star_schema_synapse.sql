-- ============================================================
-- 03_star_schema_synapse.sql
-- Runs against: salesdw (Synapse Dedicated SQL Pool)
-- Creates the presentation layer: DimDate, DimProduct, DimCustomer, DimStore, FactSales
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw') EXEC('CREATE SCHEMA dw');
GO

IF OBJECT_ID('dw.DimDate') IS NOT NULL DROP TABLE dw.DimDate;
CREATE TABLE dw.DimDate (
    DateKey     INT           NOT NULL,      -- YYYYMMDD
    FullDate    DATE          NOT NULL,
    DayOfWeek   TINYINT       NOT NULL,
    DayName     NVARCHAR(10)  NOT NULL,
    MonthNumber TINYINT       NOT NULL,
    MonthName   NVARCHAR(10)  NOT NULL,
    Quarter     TINYINT       NOT NULL,
    Year        SMALLINT      NOT NULL,
    IsWeekend   BIT           NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX (DateKey));
GO

IF OBJECT_ID('dw.DimProduct') IS NOT NULL DROP TABLE dw.DimProduct;
CREATE TABLE dw.DimProduct (
    ProductKey    INT           IDENTITY(1,1) NOT NULL,
    ProductId     NVARCHAR(50)  NOT NULL,
    ProductName   NVARCHAR(200) NOT NULL,
    Category      NVARCHAR(100) NULL,
    SubCategory   NVARCHAR(100) NULL,
    UnitPrice     DECIMAL(18,4) NULL,
    IsActive      BIT           NOT NULL DEFAULT 1,
    LastUpdated   DATETIME2(3)  NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX (ProductKey));
GO

-- SCD Type 2: keeps history of changes (e.g. a customer's city changing over time)
IF OBJECT_ID('dw.DimCustomer') IS NOT NULL DROP TABLE dw.DimCustomer;
CREATE TABLE dw.DimCustomer (
    CustomerKey   INT           IDENTITY(1,1) NOT NULL,
    CustomerId    NVARCHAR(50)  NOT NULL,
    CustomerName  NVARCHAR(200) NOT NULL,
    Email         NVARCHAR(256) NULL,
    City          NVARCHAR(100) NULL,
    Country       NVARCHAR(100) NULL,
    Segment       NVARCHAR(50)  NULL,
    EffectiveFrom DATETIME2(3)  NOT NULL,
    EffectiveTo   DATETIME2(3)  NULL,
    IsCurrent     BIT           NOT NULL DEFAULT 1,
    LastUpdated   DATETIME2(3)  NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX (CustomerKey));
GO

IF OBJECT_ID('dw.DimStore') IS NOT NULL DROP TABLE dw.DimStore;
CREATE TABLE dw.DimStore (
    StoreKey    INT           IDENTITY(1,1) NOT NULL,
    StoreId     NVARCHAR(50)  NOT NULL,
    StoreName   NVARCHAR(200) NOT NULL,
    Region      NVARCHAR(100) NULL,
    City        NVARCHAR(100) NULL,
    LastUpdated DATETIME2(3)  NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX (StoreKey));
GO

IF OBJECT_ID('dw.FactSales') IS NOT NULL DROP TABLE dw.FactSales;
CREATE TABLE dw.FactSales (
    SalesKey       BIGINT        IDENTITY(1,1) NOT NULL,
    DateKey        INT           NOT NULL,
    ProductKey     INT           NOT NULL,
    CustomerKey    INT           NOT NULL,
    StoreKey       INT           NOT NULL,
    OrderId        NVARCHAR(50)  NOT NULL,
    LineNumber     INT           NOT NULL,
    Quantity       INT           NOT NULL,
    UnitPrice      DECIMAL(18,4) NOT NULL,
    DiscountAmount DECIMAL(18,4) NOT NULL DEFAULT 0,
    NetAmount      DECIMAL(18,4) NOT NULL,
    LoadTimestamp  DATETIME2(3)  NOT NULL
)
WITH (
    DISTRIBUTION = HASH (CustomerKey),
    CLUSTERED COLUMNSTORE INDEX
);
GO

-- Seed a full year of dates (2026) so DimDate is ready for our sample order dates
;WITH d AS (
    SELECT CAST('2026-01-01' AS DATE) AS FullDate
    UNION ALL
    SELECT DATEADD(day, 1, FullDate) FROM d WHERE FullDate < '2026-12-31'
)
INSERT INTO dw.DimDate (DateKey, FullDate, DayOfWeek, DayName, MonthNumber, MonthName, Quarter, Year, IsWeekend)
SELECT
    CONVERT(INT, CONVERT(VARCHAR(8), FullDate, 112)),
    FullDate,
    DATEPART(WEEKDAY, FullDate),
    DATENAME(WEEKDAY, FullDate),
    DATEPART(MONTH, FullDate),
    DATENAME(MONTH, FullDate),
    DATEPART(QUARTER, FullDate),
    DATEPART(YEAR, FullDate),
    CASE WHEN DATEPART(WEEKDAY, FullDate) IN (1,7) THEN 1 ELSE 0 END
FROM d
OPTION (MAXRECURSION 400);
GO

PRINT 'star schema created';
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dw' ORDER BY TABLE_NAME;
SELECT COUNT(*) AS DimDateRows FROM dw.DimDate;
