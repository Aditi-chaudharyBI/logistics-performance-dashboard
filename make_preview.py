import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec

df = pd.read_csv("../data/tableau_source.csv", parse_dates=["shipment_date", "delivery_date"])

NAVY = "#1F3864"
ACCENT = "#2E75B6"
GREY = "#666666"
BG = "#F4F6F9"
STATUS_COLORS = {
    "Delivered": "#2E75B6", "Delayed": "#C00000", "In Transit": "#7CA6D8",
    "Cancelled": "#999999", "Returned": "#E8A33D"
}

fig = plt.figure(figsize=(14, 9), facecolor="white")
gs = gridspec.GridSpec(3, 3, height_ratios=[0.5, 1.2, 1.2], hspace=0.6, wspace=0.35)

fig.suptitle("Logistics Performance Dashboard", fontsize=20, fontweight="bold", color=NAVY, x=0.02, ha="left", y=0.98)
fig.text(0.02, 0.945, "Shipment Volume | Delivery Performance | Revenue & Profit Trends | Operational KPIs",
          fontsize=11, color=GREY)

terminal = df[df["on_time_flag"].notna()]
revenue_df = df[df["delivery_status"] != "Cancelled"]

kpis = [
    ("Total Shipments", f"{len(df):,}"),
    ("On-Time Delivery Rate", f"{terminal['on_time_flag'].mean()*100:.1f}%"),
    ("Total Freight Revenue (INR)", f"{revenue_df['freight_revenue_inr'].sum()/1e6:.2f}M"),
    ("Avg Profit Margin", f"{revenue_df['profit_margin_pct'].mean():.1f}%"),
]
gs_top = gridspec.GridSpecFromSubplotSpec(1, 4, subplot_spec=gs[0, :], wspace=0.25)
for i, (label, val) in enumerate(kpis):
    ax = fig.add_subplot(gs_top[i])
    ax.set_facecolor(BG)
    ax.axis("off")
    ax.text(0.5, 0.65, val, ha="center", va="center", fontsize=19, fontweight="bold", color=NAVY, transform=ax.transAxes)
    ax.text(0.5, 0.15, label, ha="center", va="center", fontsize=9.5, color=GREY, transform=ax.transAxes)
    ax.add_patch(plt.Rectangle((0,0),1,1, transform=ax.transAxes, fill=False, edgecolor="#DDDDDD", linewidth=1.5))

# Monthly revenue & profit trend
revenue_df = revenue_df.copy()
revenue_df["month"] = revenue_df["shipment_date"].dt.to_period("M").astype(str)
monthly = revenue_df.groupby("month").agg(revenue=("freight_revenue_inr","sum"), profit=("profit_inr","sum")).reset_index()
ax1 = fig.add_subplot(gs[1, :2])
ax1.plot(monthly["month"], monthly["revenue"]/1e3, marker="o", color=ACCENT, linewidth=2, label="Revenue (INR '000)")
ax1.plot(monthly["month"], monthly["profit"]/1e3, marker="o", color=NAVY, linewidth=2, label="Profit (INR '000)")
ax1.set_title("Monthly Revenue & Profit Trend", fontsize=12, fontweight="bold", color=NAVY, loc="left")
ax1.tick_params(axis="x", rotation=45, labelsize=8)
ax1.spines[["top","right"]].set_visible(False)
ax1.grid(axis="y", linestyle="--", alpha=0.4)
ax1.legend(fontsize=8, frameon=False)

# On-time % by warehouse
wh = terminal.groupby("warehouse_name")["on_time_flag"].mean().sort_values() * 100
ax2 = fig.add_subplot(gs[1, 2])
ax2.barh(wh.index, wh.values, color=ACCENT)
ax2.set_title("On-Time % by Warehouse", fontsize=12, fontweight="bold", color=NAVY, loc="left")
ax2.spines[["top","right"]].set_visible(False)
ax2.tick_params(labelsize=8)

# Delivery status breakdown (all 5 realistic states)
status_counts = df["delivery_status"].value_counts().reindex(
    ["Delivered","Delayed","In Transit","Returned","Cancelled"]
)
ax3 = fig.add_subplot(gs[2, 0])
ax3.bar(status_counts.index, status_counts.values, color=[STATUS_COLORS[s] for s in status_counts.index])
ax3.set_title("Delivery Status Breakdown", fontsize=12, fontweight="bold", color=NAVY, loc="left")
ax3.spines[["top","right"]].set_visible(False)
ax3.tick_params(axis="x", rotation=20, labelsize=8)

# Profit margin by customer segment
seg = revenue_df.groupby("customer_segment").agg(
    revenue=("freight_revenue_inr","sum"), profit=("profit_inr","sum")
)
seg["margin_pct"] = seg["profit"] / seg["revenue"] * 100
seg = seg.sort_values("margin_pct", ascending=False)
ax4 = fig.add_subplot(gs[2, 1])
ax4.bar(seg.index, seg["margin_pct"], color=NAVY)
ax4.set_title("Profit Margin % by Segment", fontsize=12, fontweight="bold", color=NAVY, loc="left")
ax4.spines[["top","right"]].set_visible(False)
ax4.tick_params(axis="x", rotation=20, labelsize=8)

# Shipment volume by region
region_vol = df.groupby("warehouse_region")["shipment_id"].count()
ax5 = fig.add_subplot(gs[2, 2])
ax5.pie(region_vol.values, labels=region_vol.index, autopct="%1.0f%%",
        colors=["#1F3864","#2E75B6","#7CA6D8","#B7CFE8"], textprops={"fontsize":9})
ax5.set_title("Shipment Volume by Region", fontsize=12, fontweight="bold", color=NAVY, loc="left")

plt.savefig("dashboard_preview.png", dpi=150, bbox_inches="tight", facecolor="white")
print("Saved dashboard_preview.png")
