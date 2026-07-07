/* =====================================================================
   Logistics Performance Dashboard — Schema (v2)
   Database: SQL Server
   =====================================================================
   Star-schema design: one fact table (Shipments) surrounded by
   Warehouse, Customer, and Date dimension tables.

   v2 changes:
   - Shipments now links to DateDim on BOTH shipment_date and delivery_date
     (delivery_date FK is nullable — In Transit shipments have no delivery
     date yet).
   - CHECK constraints added for data validation at the database layer,
     not just in the ETL/generation script.
   - profit_inr / profit_margin_pct / freight_revenue_inr / operational_cost_inr
     added to support profitability KPIs.
   - delivery_status now reflects realistic shipment states.
   ===================================================================== */

CREATE TABLE Warehouses (
    warehouse_id     INT PRIMARY KEY,
    warehouse_name   VARCHAR(100) NOT NULL,
    region           VARCHAR(50)  NOT NULL,
    state            VARCHAR(50)  NOT NULL
);

CREATE TABLE Customers (
    customer_id       INT PRIMARY KEY,
    customer_name     VARCHAR(100) NOT NULL,
    customer_segment  VARCHAR(50)  NOT NULL,
    region            VARCHAR(50)  NOT NULL,

    CONSTRAINT CK_Customers_Segment CHECK (customer_segment IN ('Retail','E-commerce','Wholesale','Enterprise'))
);

CREATE TABLE DateDim (
    [date]        DATE PRIMARY KEY,
    [year]        INT NOT NULL,
    [month]       INT NOT NULL,
    month_name    VARCHAR(20) NOT NULL,
    quarter       INT NOT NULL,
    day_of_week   VARCHAR(20) NOT NULL,

    CONSTRAINT CK_DateDim_Month   CHECK ([month] BETWEEN 1 AND 12),
    CONSTRAINT CK_DateDim_Quarter CHECK (quarter BETWEEN 1 AND 4)
);

CREATE TABLE Shipments (
    shipment_id           INT PRIMARY KEY,
    shipment_date         DATE NOT NULL,
    delivery_date         DATE NULL,          -- NULL until the shipment reaches a terminal state
    warehouse_id          INT NOT NULL,
    customer_id           INT NOT NULL,
    planned_transit_days  DECIMAL(5,1) NOT NULL,
    actual_transit_days   DECIMAL(5,1) NOT NULL,
    delivery_status       VARCHAR(20)  NOT NULL,   -- Delivered / In Transit / Delayed / Cancelled / Returned
    shipment_value_inr    DECIMAL(12,2) NOT NULL,  -- declared value of goods
    freight_revenue_inr   DECIMAL(12,2) NOT NULL,  -- amount billed to customer for shipping
    operational_cost_inr  DECIMAL(12,2) NOT NULL,  -- fuel, handling, labor cost to fulfill
    profit_inr            DECIMAL(12,2) NOT NULL,  -- freight_revenue_inr - operational_cost_inr
    profit_margin_pct     DECIMAL(5,2)  NOT NULL,  -- profit_inr / freight_revenue_inr * 100
    on_time_flag          BIT NULL,                -- NULL until status is terminal

    CONSTRAINT FK_Shipments_Warehouse  FOREIGN KEY (warehouse_id)   REFERENCES Warehouses(warehouse_id),
    CONSTRAINT FK_Shipments_Customer   FOREIGN KEY (customer_id)    REFERENCES Customers(customer_id),
    CONSTRAINT FK_Shipments_ShipDate   FOREIGN KEY (shipment_date)  REFERENCES DateDim([date]),
    CONSTRAINT FK_Shipments_DeliverDate FOREIGN KEY (delivery_date) REFERENCES DateDim([date]),

    -- Data validation constraints
    CONSTRAINT CK_Shipments_Status CHECK (delivery_status IN ('Delivered','In Transit','Delayed','Cancelled','Returned')),
    CONSTRAINT CK_Shipments_ValueNonNeg   CHECK (shipment_value_inr >= 0),
    CONSTRAINT CK_Shipments_RevenueNonNeg CHECK (freight_revenue_inr >= 0),
    CONSTRAINT CK_Shipments_CostNonNeg    CHECK (operational_cost_inr >= 0),
    CONSTRAINT CK_Shipments_PlannedTransitPositive CHECK (planned_transit_days > 0),
    CONSTRAINT CK_Shipments_ActualTransitNonNeg    CHECK (actual_transit_days >= 0),
    CONSTRAINT CK_Shipments_OnTimeFlagBinary CHECK (on_time_flag IN (0, 1) OR on_time_flag IS NULL),
    -- A shipment can only have a delivery_date once it's reached a terminal status
    CONSTRAINT CK_Shipments_DeliveryDateLogic CHECK (
        (delivery_status IN ('Delivered','Delayed','Returned') AND delivery_date IS NOT NULL)
        OR (delivery_status IN ('In Transit','Cancelled') AND delivery_date IS NULL)
    )
);

-- Indexes on commonly filtered/joined columns (query optimization)
CREATE INDEX IX_Shipments_ShipDate    ON Shipments(shipment_date);
CREATE INDEX IX_Shipments_DeliverDate ON Shipments(delivery_date);
CREATE INDEX IX_Shipments_Warehouse   ON Shipments(warehouse_id);
CREATE INDEX IX_Shipments_Customer    ON Shipments(customer_id);
CREATE INDEX IX_Shipments_Status      ON Shipments(delivery_status);

/* Bulk load reference (adjust path to your local copy of the CSVs).
   Load dimensions and DateDim BEFORE Shipments, since Shipments has FKs to all three.

BULK INSERT Warehouses FROM 'C:\data\warehouses.csv' WITH (FORMAT='CSV', FIRSTROW=2);
BULK INSERT Customers  FROM 'C:\data\customers.csv'  WITH (FORMAT='CSV', FIRSTROW=2);
BULK INSERT DateDim    FROM 'C:\data\date_dim.csv'   WITH (FORMAT='CSV', FIRSTROW=2);
BULK INSERT Shipments  FROM 'C:\data\shipments.csv'  WITH (FORMAT='CSV', FIRSTROW=2);
*/
