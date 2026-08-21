PRINT '--- Revenue by product category ---';
SELECT Category, SUM(NetAmount) AS Revenue
FROM dw.vw_SalesDetail
GROUP BY Category
ORDER BY Revenue DESC;

PRINT '--- Daily revenue trend ---';
SELECT FullDate, TotalRevenue
FROM dw.vw_DailySalesSummary
ORDER BY FullDate;

PRINT '--- Revenue by region ---';
SELECT Region, SUM(NetAmount) AS Revenue
FROM dw.vw_SalesDetail
GROUP BY Region
ORDER BY Revenue DESC;

PRINT '--- Revenue by customer segment ---';
SELECT Segment, SUM(NetAmount) AS Revenue
FROM dw.vw_SalesDetail
GROUP BY Segment
ORDER BY Revenue DESC;
