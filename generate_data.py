"""
Generates a synthetic logistics shipments dataset for the
Logistics Performance Dashboard portfolio project.

v2 changes:
- Realistic delivery_status categories (Delivered, In Transit, Delayed, Cancelled, Returned)
- on_time_flag only meaningful for terminal statuses (NULL for In Transit)
- profit_inr and profit_margin_pct added
- DateDim extended to cover delivery_date range, so Shipments can FK to it on both dates

Run: python generate_data.py
Outputs: shipments.csv, warehouses.csv, customers.csv, date_dim.csv, tableau_source.csv
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta

np.random.seed(42)

# Reference "today" for the dataset — anything shipped too recently to have
# completed transit is still "In Transit".
REFERENCE_DATE = datetime(2026, 6, 30)

# ---------------------------------------------------------
# 1. Dimension: Warehouses
# ---------------------------------------------------------
warehouses = pd.DataFrame({
    "warehouse_id": range(1, 9),
    "warehouse_name": [
        "Hyderabad Hub", "Bengaluru Hub", "Chennai Hub", "Mumbai Hub",
        "Delhi Hub", "Pune Hub", "Kolkata Hub", "Ahmedabad Hub"
    ],
    "region": [
        "South", "South", "South", "West",
        "North", "West", "East", "West"
    ],
    "state": [
        "Telangana", "Karnataka", "Tamil Nadu", "Maharashtra",
        "Delhi", "Maharashtra", "West Bengal", "Gujarat"
    ]
})

# ---------------------------------------------------------
# 2. Dimension: Customers
# ---------------------------------------------------------
n_customers = 150
customers = pd.DataFrame({
    "customer_id": range(1, n_customers + 1),
    "customer_name": [f"Customer_{i:03d}" for i in range(1, n_customers + 1)],
    "customer_segment": np.random.choice(
        ["Retail", "E-commerce", "Wholesale", "Enterprise"],
        n_customers, p=[0.35, 0.30, 0.20, 0.15]
    ),
    "region": np.random.choice(
        ["South", "West", "North", "East"], n_customers, p=[0.35, 0.30, 0.20, 0.15]
    )
})

# ---------------------------------------------------------
# 3. Date dimension — extended 14 days past REFERENCE_DATE so that
#    delivery_date (shipment_date + transit) always has a valid FK match,
#    even for shipments made near the end of the observation window.
# ---------------------------------------------------------
start_date = datetime(2025, 7, 1)
end_date = REFERENCE_DATE + timedelta(days=14)
date_range_full = pd.date_range(start_date, end_date, freq="D")
date_dim = pd.DataFrame({"date": date_range_full})
date_dim["year"] = date_dim["date"].dt.year
date_dim["month"] = date_dim["date"].dt.month
date_dim["month_name"] = date_dim["date"].dt.strftime("%b-%Y")
date_dim["quarter"] = date_dim["date"].dt.quarter
date_dim["day_of_week"] = date_dim["date"].dt.day_name()

# Shipments are only ever *placed* within the original observation window
shipment_date_range = pd.date_range(start_date, REFERENCE_DATE, freq="D")

# ---------------------------------------------------------
# 4. Fact: Shipments
# ---------------------------------------------------------
n_shipments = 12000

shipment_dates = pd.to_datetime(np.random.choice(shipment_date_range, n_shipments))
warehouse_ids = np.random.choice(warehouses["warehouse_id"], n_shipments)
customer_ids = np.random.choice(customers["customer_id"], n_shipments)

planned_transit = np.random.normal(loc=3.2, scale=1.1, size=n_shipments).clip(1, 10)

# Assign a realistic status mix first, then derive transit/delivery consistent with it
status_roll = np.random.rand(n_shipments)
delivery_status = np.empty(n_shipments, dtype=object)
delivery_status[status_roll < 0.03] = "Cancelled"                                   # 3%
delivery_status[(status_roll >= 0.03) & (status_roll < 0.05)] = "Returned"          # 2%
delivery_status[(status_roll >= 0.05) & (status_roll < 0.20)] = "Delayed"           # 15%
remaining = status_roll >= 0.20                                                     # 80%

days_since_ship = (REFERENCE_DATE - shipment_dates).days
# Of the "remaining" bucket, anything shipped too recently to have completed
# even its planned transit is still In Transit; the rest are cleanly Delivered.
still_in_transit = remaining & (days_since_ship < np.ceil(planned_transit))
delivery_status[still_in_transit] = "In Transit"
delivery_status[remaining & ~still_in_transit] = "Delivered"

# Actual transit time, consistent with the assigned status
actual_transit = planned_transit.copy()
delayed_mask = delivery_status == "Delayed"
actual_transit[delayed_mask] = planned_transit[delayed_mask] + np.random.uniform(1.5, 5, delayed_mask.sum())
returned_mask = delivery_status == "Returned"
actual_transit[returned_mask] = planned_transit[returned_mask] + np.random.uniform(0.5, 3, returned_mask.sum())

# on_time_flag only makes sense once a shipment has actually reached a terminal state
on_time_flag = np.where(
    delivery_status == "Delivered", 1,
    np.where(np.isin(delivery_status, ["Delayed", "Returned", "Cancelled"]), 0, np.nan)
)

shipment_value = np.round(np.random.gamma(shape=2.2, scale=850, size=n_shipments), 2)  # declared value of goods (not revenue)

# Freight revenue: what the logistics company actually bills for the shipment —
# modeled as a function of declared value + distance/weight proxy, independent of profit calc.
freight_revenue = np.round(
    np.random.gamma(shape=3.0, scale=180, size=n_shipments) + shipment_value * 0.03, 2
)

# Operational cost: fuel, handling, labor — delayed shipments run less efficiently
# (extra handling, re-routing), so they carry a cost penalty.
base_cost_ratio = np.random.uniform(0.55, 0.80, n_shipments)
delay_cost_penalty = np.where(delivery_status == "Delayed", np.random.uniform(0.08, 0.18, n_shipments), 0.0)
returned_cost_penalty = np.where(delivery_status == "Returned", np.random.uniform(0.15, 0.30, n_shipments), 0.0)
operational_cost = np.round(freight_revenue * (base_cost_ratio + delay_cost_penalty + returned_cost_penalty), 2)

# Cancelled shipments never bill freight or incur fulfillment cost
freight_revenue = np.where(delivery_status == "Cancelled", 0.0, freight_revenue)
operational_cost = np.where(delivery_status == "Cancelled", 0.0, operational_cost)
shipment_value = np.where(delivery_status == "Cancelled", 0.0, shipment_value)

profit = np.round(freight_revenue - operational_cost, 2)
profit_margin_pct = np.round(
    np.divide(profit, freight_revenue, out=np.zeros_like(profit), where=freight_revenue > 0) * 100, 2
)

shipments = pd.DataFrame({
    "shipment_id": range(1, n_shipments + 1),
    "shipment_date": shipment_dates,
    "warehouse_id": warehouse_ids,
    "customer_id": customer_ids,
    "planned_transit_days": np.round(planned_transit, 1),
    "actual_transit_days": np.round(actual_transit, 1),
    "delivery_status": delivery_status,
    "shipment_value_inr": shipment_value,
    "freight_revenue_inr": freight_revenue,
    "operational_cost_inr": operational_cost,
    "profit_inr": profit,
    "profit_margin_pct": profit_margin_pct,
    "on_time_flag": on_time_flag
})

# delivery_date is only meaningful for shipments that have actually moved
shipments["delivery_date"] = np.where(
    shipments["delivery_status"].isin(["Delivered", "Delayed", "Returned"]),
    shipments["shipment_date"] + pd.to_timedelta(shipments["actual_transit_days"], unit="D"),
    pd.NaT
)
shipments["delivery_date"] = pd.to_datetime(shipments["delivery_date"]).dt.normalize()

# on_time_flag stored as nullable int (SQL Server BIT can't hold NULL cleanly via CSV import
# as float — exported as empty string for NULL, handled in the schema as NULL-able BIT)
shipments["on_time_flag"] = shipments["on_time_flag"].astype("Int64")

# ---------------------------------------------------------
# Save dimension/fact tables
# ---------------------------------------------------------
warehouses.to_csv("warehouses.csv", index=False)
customers.to_csv("customers.csv", index=False)
date_dim.to_csv("date_dim.csv", index=False)
shipments.to_csv("shipments.csv", index=False)

# ---------------------------------------------------------
# Denormalized flat file for Tableau (single-table connection —
# avoids needing Tableau relationships/joins across 4 files)
# ---------------------------------------------------------
tableau_source = (
    shipments
    .merge(warehouses, on="warehouse_id", suffixes=("", "_wh"))
    .merge(customers, on="customer_id", suffixes=("_warehouse", "_customer"))
)
tableau_source = tableau_source.rename(columns={
    "region_warehouse": "warehouse_region",
    "region_customer": "customer_region"
})
tableau_source.to_csv("tableau_source.csv", index=False)

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
print("Generated files: shipments.csv, warehouses.csv, customers.csv, date_dim.csv, tableau_source.csv")
print(f"\nStatus breakdown:\n{shipments['delivery_status'].value_counts()}")
print(f"\nOn-time delivery rate (terminal shipments only): {shipments['on_time_flag'].mean()*100:.1f}%")
print(f"Total freight revenue: INR {shipments['freight_revenue_inr'].sum():,.0f}")
print(f"Total profit:          INR {shipments['profit_inr'].sum():,.0f}")
print(f"Avg profit margin: {shipments.loc[shipments['freight_revenue_inr']>0,'profit_margin_pct'].mean():.1f}%")
