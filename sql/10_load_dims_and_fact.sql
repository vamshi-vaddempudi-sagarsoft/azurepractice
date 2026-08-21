-- ============================================================
-- 10_load_dims_and_fact.sql
-- Runs against: salesdw (Synapse)
-- The "merge into the warehouse" procedures. Product/Store are SCD1
-- (overwrite). Customer is SCD2 (keep history). Fact joins everything
-- by business key to find the right surrogate keys.
-- ============================================================

IF OBJECT_ID('dw.usp_LoadDimProduct') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimProduct;
GO
CREATE PROCEDURE dw.usp_LoadDimProduct AS
BEGIN
    SET NOCOUNT ON;
    UPDATE d SET ProductName = s.ProductName, Category = s.Category, SubCategory = s.SubCategory,
                 UnitPrice = s.UnitPrice, IsActive = ISNULL(s.IsActive, 1), LastUpdated = SYSUTCDATETIME()
    FROM dw.DimProduct d INNER JOIN stg.Product s ON d.ProductId = s.ProductId
    WHERE ISNULL(d.ProductName,'') <> ISNULL(s.ProductName,'')
       OR ISNULL(d.Category,'')    <> ISNULL(s.Category,'')
       OR ISNULL(d.SubCategory,'') <> ISNULL(s.SubCategory,'')
       OR ISNULL(d.UnitPrice,0)    <> ISNULL(s.UnitPrice,0);

    INSERT INTO dw.DimProduct (ProductId, ProductName, Category, SubCategory, UnitPrice, IsActive, LastUpdated)
    SELECT s.ProductId, s.ProductName, s.Category, s.SubCategory, s.UnitPrice, ISNULL(s.IsActive,1), SYSUTCDATETIME()
    FROM stg.Product s WHERE NOT EXISTS (SELECT 1 FROM dw.DimProduct d WHERE d.ProductId = s.ProductId);
END
GO

IF OBJECT_ID('dw.usp_LoadDimStore') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimStore;
GO
CREATE PROCEDURE dw.usp_LoadDimStore AS
BEGIN
    SET NOCOUNT ON;
    UPDATE d SET StoreName = s.StoreName, Region = s.Region, City = s.City, LastUpdated = SYSUTCDATETIME()
    FROM dw.DimStore d INNER JOIN stg.Store s ON d.StoreId = s.StoreId
    WHERE ISNULL(d.StoreName,'') <> ISNULL(s.StoreName,'')
       OR ISNULL(d.Region,'')    <> ISNULL(s.Region,'')
       OR ISNULL(d.City,'')      <> ISNULL(s.City,'');

    INSERT INTO dw.DimStore (StoreId, StoreName, Region, City, LastUpdated)
    SELECT s.StoreId, s.StoreName, s.Region, s.City, SYSUTCDATETIME()
    FROM stg.Store s WHERE NOT EXISTS (SELECT 1 FROM dw.DimStore d WHERE d.StoreId = s.StoreId);
END
GO

IF OBJECT_ID('dw.usp_LoadDimCustomer') IS NOT NULL DROP PROCEDURE dw.usp_LoadDimCustomer;
GO
CREATE PROCEDURE dw.usp_LoadDimCustomer AS
BEGIN
    SET NOCOUNT ON;
    -- Close the current version if any tracked attribute changed
    UPDATE d SET EffectiveTo = SYSUTCDATETIME(), IsCurrent = 0, LastUpdated = SYSUTCDATETIME()
    FROM dw.DimCustomer d INNER JOIN stg.Customer s ON d.CustomerId = s.CustomerId
    WHERE d.IsCurrent = 1
      AND (ISNULL(d.CustomerName,'') <> ISNULL(s.CustomerName,'')
        OR ISNULL(d.City,'')         <> ISNULL(s.City,'')
        OR ISNULL(d.Country,'')      <> ISNULL(s.Country,'')
        OR ISNULL(d.Segment,'')      <> ISNULL(s.Segment,''));

    -- Insert a new current version for new customers, or ones just closed above
    INSERT INTO dw.DimCustomer (CustomerId, CustomerName, Email, City, Country, Segment, EffectiveFrom, EffectiveTo, IsCurrent, LastUpdated)
    SELECT s.CustomerId, s.CustomerName, s.Email, s.City, s.Country, s.Segment, SYSUTCDATETIME(), NULL, 1, SYSUTCDATETIME()
    FROM stg.Customer s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.DimCustomer d
        WHERE d.CustomerId = s.CustomerId AND d.IsCurrent = 1
          AND ISNULL(d.CustomerName,'') = ISNULL(s.CustomerName,'')
          AND ISNULL(d.City,'')         = ISNULL(s.City,'')
          AND ISNULL(d.Country,'')      = ISNULL(s.Country,'')
          AND ISNULL(d.Segment,'')      = ISNULL(s.Segment,'')
    );
END
GO

IF OBJECT_ID('dw.usp_LoadFactSales') IS NOT NULL DROP PROCEDURE dw.usp_LoadFactSales;
GO
CREATE PROCEDURE dw.usp_LoadFactSales AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dw.FactSales;   -- simple full-reload pattern for this demo, re-runnable
    INSERT INTO dw.FactSales (DateKey, ProductKey, CustomerKey, StoreKey, OrderId, LineNumber,
                               Quantity, UnitPrice, DiscountAmount, NetAmount, LoadTimestamp)
    SELECT
        CONVERT(INT, CONVERT(VARCHAR(8), s.OrderDate, 112)) AS DateKey,
        p.ProductKey, c.CustomerKey, st.StoreKey,
        s.OrderId, s.LineNumber, s.Quantity, s.UnitPrice, ISNULL(s.DiscountAmount, 0),
        s.Quantity * s.UnitPrice - ISNULL(s.DiscountAmount, 0),
        SYSUTCDATETIME()
    FROM stg.SalesOrder s
    INNER JOIN dw.DimProduct  p  ON p.ProductId  = s.ProductId  AND p.IsActive = 1
    INNER JOIN dw.DimCustomer c  ON c.CustomerId = s.CustomerId AND c.IsCurrent = 1
    INNER JOIN dw.DimStore    st ON st.StoreId   = s.StoreId;
END
GO

EXEC dw.usp_LoadDimProduct;
EXEC dw.usp_LoadDimStore;
EXEC dw.usp_LoadDimCustomer;
EXEC dw.usp_LoadFactSales;

PRINT '--- Row counts after loading the warehouse ---';
SELECT 'DimProduct' T, COUNT(*) C FROM dw.DimProduct
UNION ALL SELECT 'DimStore', COUNT(*) FROM dw.DimStore
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dw.DimCustomer
UNION ALL SELECT 'FactSales', COUNT(*) FROM dw.FactSales;
