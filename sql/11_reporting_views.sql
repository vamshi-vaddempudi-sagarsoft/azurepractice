-- ============================================================
-- 11_reporting_views.sql
-- Runs against: salesdw (Synapse)
-- Plain SQL views on top of the star schema - this is the "payoff" layer
-- a Power BI dashboard would normally sit on, if we were building one.
-- ============================================================

IF OBJECT_ID('dw.vw_SalesDetail') IS NOT NULL DROP VIEW dw.vw_SalesDetail;
GO
CREATE VIEW dw.vw_SalesDetail AS
SELECT
    f.OrderId, f.LineNumber,
    d.FullDate AS OrderDate, d.Year, d.Quarter, d.MonthName,
    p.ProductId, p.ProductName, p.Category, p.SubCategory,
    c.CustomerId, c.CustomerName, c.City AS CustomerCity, c.Segment,
    st.StoreId, st.StoreName, st.Region,
    f.Quantity, f.UnitPrice, f.DiscountAmount, f.NetAmount
FROM dw.FactSales f
INNER JOIN dw.DimDate d ON f.DateKey = d.DateKey
INNER JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
INNER JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
INNER JOIN dw.DimStore st ON f.StoreKey = st.StoreKey;
GO

IF OBJECT_ID('dw.vw_DailySalesSummary') IS NOT NULL DROP VIEW dw.vw_DailySalesSummary;
GO
CREATE VIEW dw.vw_DailySalesSummary AS
SELECT d.FullDate, d.Year, d.MonthName,
       COUNT(DISTINCT f.OrderId) AS OrderCount,
       SUM(f.Quantity) AS TotalUnits,
       SUM(f.NetAmount) AS TotalRevenue
FROM dw.FactSales f
INNER JOIN dw.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.FullDate, d.Year, d.MonthName;
GO

IF OBJECT_ID('dw.vw_SalesByCategory') IS NOT NULL DROP VIEW dw.vw_SalesByCategory;
GO
CREATE VIEW dw.vw_SalesByCategory AS
SELECT p.Category, p.SubCategory,
       SUM(f.Quantity) AS Units,
       SUM(f.NetAmount) AS Revenue
FROM dw.FactSales f
INNER JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category, p.SubCategory;
GO

PRINT '--- Top 5 products by revenue ---';
SELECT TOP 5 ProductName, Category, SUM(NetAmount) AS Revenue
FROM dw.vw_SalesDetail GROUP BY ProductName, Category ORDER BY Revenue DESC;

PRINT '--- Revenue by customer segment ---';
SELECT Segment, COUNT(DISTINCT CustomerId) AS Customers, SUM(NetAmount) AS Revenue
FROM dw.vw_SalesDetail GROUP BY Segment ORDER BY Revenue DESC;

PRINT '--- Revenue by region ---';
SELECT Region, SUM(NetAmount) AS Revenue FROM dw.vw_SalesDetail GROUP BY Region ORDER BY Revenue DESC;
