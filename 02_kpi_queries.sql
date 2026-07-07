/* =====================================================================
   Logistics Performance Dashboard — KPI & Analytical Queries (v2)
   Mirrors the SQL skill set on the resume: joins, CTEs, views,
   stored procedures, window functions — now via DateDim instead of
   FORMAT()/string-based date grouping, plus profitability KPIs.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. VIEW: Shipment detail joined with all three dimensions,
--    including DateDim for the shipment date (this is what Tableau
--    connects to for the dashboard).
-- ---------------------------------------------------------------------
CREATE VIEW vw_ShipmentDetail AS
SELECT
    s.shipment_id,
    s.shipment_date,
    d.[year]           AS ship_year,
    d.[month]          AS ship_month_num,
    d.month_name       AS ship_month_name,
    d.quarter          AS ship_quarter,
    s.delivery_date,
    w.warehouse_name,
    w.region       AS warehouse_region,
    c.customer_name,
    c.customer_segment,
    c.region       AS customer_region,
    s.planned_transit_days,
    s.actual_transit_days,
    s.delivery_status,
    s.shipment_value_inr,
    s.freight_revenue_inr,
    s.operational_cost_inr,
    s.profit_inr,
    s.profit_margin_pct,
    s.on_time_flag
FROM Shipments s
INNER JOIN Warehouses w ON s.warehouse_id  = w.warehouse_id
INNER JOIN Customers  c ON s.customer_id   = c.customer_id
INNER JOIN DateDim    d ON s.shipment_date = d.[date];
GO

-- ---------------------------------------------------------------------
-- 2. On-Time Delivery Rate by Warehouse
--    (excludes In Transit / Cancelled — status not yet terminal or never fulfilled)
-- ---------------------------------------------------------------------
SELECT
    warehouse_name,
    COUNT(*)                                                       AS terminal_shipments,
    SUM(CAST(on_time_flag AS INT))                                 AS on_time_shipments,
    ROUND(SUM(CAST(on_time_flag AS INT)) * 100.0 / COUNT(*), 1)    AS on_time_pct
FROM vw_ShipmentDetail
WHERE on_time_flag IS NOT NULL
GROUP BY warehouse_name
ORDER BY on_time_pct DESC;

-- ---------------------------------------------------------------------
-- 3. Monthly Revenue & Profit Trend — grouped via DateDim, not FORMAT()
--    CTE + window function (LAG) for month-over-month growth.
-- ---------------------------------------------------------------------
WITH MonthlyFinancials AS (
    SELECT
        ship_year,
        ship_month_num,
        MIN(ship_month_name) AS ship_month_name,   -- one label per year/month group
        SUM(freight_revenue_inr) AS total_revenue,
        SUM(profit_inr)          AS total_profit
    FROM vw_ShipmentDetail
    WHERE delivery_status <> 'Cancelled'
    GROUP BY ship_year, ship_month_num
)
SELECT
    ship_month_name,
    total_revenue,
    total_profit,
    ROUND(total_profit * 100.0 / NULLIF(total_revenue, 0), 1) AS profit_margin_pct,
    total_revenue - LAG(total_revenue) OVER (ORDER BY ship_year, ship_month_num) AS mom_revenue_change,
    ROUND(
      (total_revenue - LAG(total_revenue) OVER (ORDER BY ship_year, ship_month_num))
      * 100.0 / NULLIF(LAG(total_revenue) OVER (ORDER BY ship_year, ship_month_num), 0), 1
    ) AS mom_growth_pct
FROM MonthlyFinancials
ORDER BY ship_year, ship_month_num;

-- ---------------------------------------------------------------------
-- 4. Delivery Status Breakdown by Region (conditional aggregation)
-- ---------------------------------------------------------------------
SELECT
    warehouse_region,
    SUM(CASE WHEN delivery_status = 'Delivered'  THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN delivery_status = 'Delayed'    THEN 1 ELSE 0 END) AS delayed,
    SUM(CASE WHEN delivery_status = 'In Transit' THEN 1 ELSE 0 END) AS in_transit,
    SUM(CASE WHEN delivery_status = 'Cancelled'  THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN delivery_status = 'Returned'   THEN 1 ELSE 0 END) AS returned,
    COUNT(*) AS total
FROM vw_ShipmentDetail
GROUP BY warehouse_region
ORDER BY warehouse_region;

-- ---------------------------------------------------------------------
-- 5. Profitability by Customer Segment (profit + margin KPI)
-- ---------------------------------------------------------------------
SELECT
    customer_segment,
    SUM(freight_revenue_inr)                                    AS total_revenue,
    SUM(profit_inr)                                             AS total_profit,
    ROUND(SUM(profit_inr) * 100.0 / NULLIF(SUM(freight_revenue_inr), 0), 1) AS profit_margin_pct
FROM vw_ShipmentDetail
WHERE delivery_status <> 'Cancelled'
GROUP BY customer_segment
ORDER BY total_profit DESC;

-- ---------------------------------------------------------------------
-- 6. Top 10 Customers by Profit (window function ranking)
-- ---------------------------------------------------------------------
SELECT customer_name, customer_segment, total_profit, rnk
FROM (
    SELECT
        customer_name,
        customer_segment,
        SUM(profit_inr) AS total_profit,
        RANK() OVER (ORDER BY SUM(profit_inr) DESC) AS rnk
    FROM vw_ShipmentDetail
    WHERE delivery_status <> 'Cancelled'
    GROUP BY customer_name, customer_segment
) ranked
WHERE rnk <= 10;

-- ---------------------------------------------------------------------
-- 7. Average Transit Time vs. Planned, by Warehouse (delay analysis)
-- ---------------------------------------------------------------------
SELECT
    warehouse_name,
    ROUND(AVG(planned_transit_days), 2) AS avg_planned_days,
    ROUND(AVG(actual_transit_days), 2)  AS avg_actual_days,
    ROUND(AVG(actual_transit_days) - AVG(planned_transit_days), 2) AS avg_delay_days
FROM vw_ShipmentDetail
WHERE delivery_status IN ('Delivered','Delayed')
GROUP BY warehouse_name
ORDER BY avg_delay_days DESC;

-- ---------------------------------------------------------------------
-- 8. STORED PROCEDURE #1: Parameterized monthly summary by date range,
--    joined through DateDim rather than filtering on raw dates directly.
-- ---------------------------------------------------------------------
CREATE PROCEDURE usp_GetMonthlySummary
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        warehouse_name,
        COUNT(*)                                                          AS total_shipments,
        SUM(freight_revenue_inr)                                          AS total_revenue,
        SUM(profit_inr)                                                   AS total_profit,
        ROUND(SUM(profit_inr) * 100.0 / NULLIF(SUM(freight_revenue_inr), 0), 1) AS profit_margin_pct,
        ROUND(SUM(CAST(on_time_flag AS INT)) * 100.0 / NULLIF(SUM(CASE WHEN on_time_flag IS NOT NULL THEN 1 ELSE 0 END), 0), 1) AS on_time_pct
    FROM vw_ShipmentDetail
    WHERE shipment_date BETWEEN @StartDate AND @EndDate
    GROUP BY warehouse_name
    ORDER BY total_revenue DESC;
END;
GO

-- Example execution:
-- EXEC usp_GetMonthlySummary @StartDate = '2026-01-01', @EndDate = '2026-03-31';


-- ---------------------------------------------------------------------
-- 9. STORED PROCEDURE #2: Delivery status summary for a given warehouse,
--    with an optional region filter — demonstrates conditional logic
--    and parameter defaults inside a stored procedure.
-- ---------------------------------------------------------------------
CREATE PROCEDURE usp_GetDeliveryStatusSummary
    @WarehouseName VARCHAR(100) = NULL,   -- optional: NULL returns all warehouses
    @Region        VARCHAR(50)  = NULL    -- optional: NULL returns all regions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        warehouse_name,
        warehouse_region,
        delivery_status,
        COUNT(*) AS shipment_count,
        SUM(freight_revenue_inr) AS total_revenue
    FROM vw_ShipmentDetail
    WHERE (@WarehouseName IS NULL OR warehouse_name = @WarehouseName)
      AND (@Region        IS NULL OR warehouse_region = @Region)
    GROUP BY warehouse_name, warehouse_region, delivery_status
    ORDER BY warehouse_name, delivery_status;
END;
GO

-- Example execution:
-- EXEC usp_GetDeliveryStatusSummary @WarehouseName = 'Hyderabad Hub';
-- EXEC usp_GetDeliveryStatusSummary @Region = 'South';
-- EXEC usp_GetDeliveryStatusSummary;  -- all warehouses, all regions

-- ---------------------------------------------------------------------
-- 10. Customers with no shipments in the last 30 days (anti-join)
-- ---------------------------------------------------------------------
SELECT c.customer_name, c.customer_segment
FROM Customers c
LEFT JOIN Shipments s
    ON c.customer_id = s.customer_id
    AND s.shipment_date >= DATEADD(DAY, -30, (SELECT MAX(shipment_date) FROM Shipments))
WHERE s.shipment_id IS NULL;
