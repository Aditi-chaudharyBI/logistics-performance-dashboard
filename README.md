# 📦 Logistics Performance Dashboard

## Overview

The **Logistics Performance Dashboard** is an end-to-end business intelligence project designed to monitor logistics operations using **Tableau** and **SQL Server**. The solution provides a centralized view of shipment performance, delivery efficiency, revenue, profit, and operational KPIs, enabling data-driven business decisions.

---

## Business Objective

The project addresses the challenge of fragmented logistics reporting by integrating operational data into a single interactive Tableau dashboard. It enables stakeholders to monitor warehouse performance, delivery timelines, customer profitability, and revenue trends in real time.

---

## Technology Stack

| Category         | Technologies                                            |
| ---------------- | ------------------------------------------------------- |
| Visualization    | Tableau Desktop, Tableau Public                         |
| Database         | SQL Server                                              |
| Programming      | Python (Pandas, NumPy)                                  |
| SQL              | Joins, CTEs, Views, Stored Procedures, Window Functions |
| Data Engineering | ETL, Data Modeling, Data Validation                     |

---

## Key Features

* Interactive Tableau dashboards
* Logistics KPI monitoring
* Shipment performance analysis
* Revenue and profit analysis
* Customer segmentation insights
* Warehouse performance tracking
* On-time delivery analysis
* Delivery status monitoring
* Dynamic filters and dashboard actions
* Automated SQL-based reporting

---

## Dashboard KPIs

* On-Time Delivery Rate
* Monthly Revenue Trend
* Monthly Profit Trend
* Profit Margin
* Shipment Volume
* Delivery Status Distribution
* Warehouse Performance
* Customer Profitability
* Planned vs Actual Transit Time

---

## Data Model

The solution uses a **star schema** consisting of:

* Fact Shipments
* Dim Date
* Dim Customers
* Dim Warehouses

The Tableau dashboard consumes a SQL Server view created from the dimensional model to provide optimized analytical reporting.

---

## SQL Concepts Demonstrated

* Inner & Outer Joins
* Common Table Expressions (CTEs)
* Views
* Stored Procedures
* Window Functions
* Ranking Functions
* Aggregate Functions
* Query Optimization

---

## Business Impact

* Centralized logistics reporting
* Reduced manual reporting effort
* Faster operational decision-making
* Improved KPI visibility
* Better warehouse performance monitoring
* Enhanced customer profitability analysis

---

## Repository Structure

```
logistics-dashboard/
│
├── data/
├── sql/
├── images/
├── Logistics_Performance_Dashboard.twbx
├── Logistics_Performance_Dashboard.twb
└── README.md
```

---

## Future Enhancements

* Snowflake Integration
* Live SQL Server Connection
* Tableau Server Publishing
* Incremental Data Refresh
* Performance Optimization
* Predictive Analytics

---

## Author

**Aditi Chaudhary**

**Tableau Developer | Business Analyst | Business Intelligence Analyst**

* SQL Server
* Tableau
* Data Visualization
* Data Modeling
* ETL
* Business Intelligence
