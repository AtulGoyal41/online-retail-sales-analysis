# Online Retail Sales Analysis

Analyzed £9.6M in UK online retail transactions to uncover revenue leakage, customer concentration risk, and seasonal demand patterns — built independently in three tools (Excel/Power Query/Power Pivot, MySQL, and Power BI) and reconciled figure-by-figure across all three.

## Business Problem

This project analyzes transaction data from an online gift/houseware retailer, where three business functions have a stake in the results: Finance cares about the Revenue Bridge (where money leaks — cancellations, write-offs, vouchers); Customer Service cares about the cancellation rate by customer type (18.54% Registered vs. 4.21% Guest — a pattern worth investigating); and Operations cares about cancelled order volume (4,592 of 28,816 orders) — wasted picking/packing time and labor on orders that never shipped. I analyzed the transaction-level data to surface these findings for each stakeholder.

## Approach: One Analysis, Three Tools

Rather than building this once, I built it three times — first in Excel/Power Query/Power Pivot, then rebuilt independently in MySQL, then rebuilt again in Power BI connected live to the MySQL database. The business logic (the six cleaning rules and five findings) was never re-derived between tools — only re-expressed in each one's syntax. Every output was then reconciled against the other two rather than trusted on its own.

That reconciliation surfaced six real defects that were invisible from inside any single tool — a case-sensitive string match that silently miscounted 4 rows, a stale duplicate table in Excel's data model, a DAX function that folded anonymous customers into one phantom account, a grouping choice that fragmented one product's revenue across three rows, a filter mismatch between a ratio's numerator and denominator, and a sign error in a revenue bridge. All six are documented, traced to their cause, and fixed across all three versions — see [`docs/SQL_PowerBI_Process.md`](docs/SQL_PowerBI_Process.md) for the full process.

## Key Findings

- **Revenue Bridge:** Net Sales Revenue — after excluding cancellations, write-offs, and vouchers — totals £9,590,901.39.
- **EIRE Concentration Risk:** 3 real, identifiable customer accounts generate £325,403.11 of Net Sales Revenue, averaging £108,467.70 per account — over 50x the UK average of £2,057 per account.
- **Cancellation Rate:** Registered customers cancel orders at 18.54%, nearly 4.4x higher than Guest customers at 4.21%.
- **Order Value:** Registered and Guest customers spend almost identically per order (£457.31 vs £425.47) — the difference between the two groups is cancellation behaviour, not order size.
- **Top Products:** The top 5 products (by StockCode) generate 5.65% of Net Sales Revenue — roughly 47x what even distribution across 4,144 products would predict.
- **Seasonal Pattern:** November (£1.40M) is the peak revenue month — not December (£402K) — meaning restocking needs to happen before November, not for a Christmas rush.

Full write-up with confirmed vs. not-confirmed reasoning and business impact/benefit/risk analysis: see [`docs/EDA_Findings.md`](docs/EDA_Findings.md).

## Dashboards

**Excel / Power Pivot**

![Excel Dashboard](image/dashboard.png)

**Power BI** — three-page live report (Overview, Customer & Product Analysis, Key Insights), connected directly to the MySQL database built for this project. PDF export and the working `.pbix` file: [`powerbi/`](powerbi/)

## Repository Structure

| Folder | Contents |
|---|---|
| `dashboard/` | Original Excel workbook |
| `image/` | Excel dashboard export |
| `sql/` | Full MySQL rebuild — schema design, load, cleaning, all six derived columns, all five EDA findings |
| `powerbi/` | Power BI rebuild — PDF export and `.pbix` source, connected live to MySQL |
| `docs/` | Executive summary, full EDA findings, data dictionary, and the full SQL/Power BI rebuild process |

## Tools Used

Excel, Power Query, Power Pivot (DAX), MySQL, Power BI

## Data Source

[Online Retail II — UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii)
Transaction data (Dec 2009 – Dec 2010 sheet used) from a UK-based online gift/houseware wholesaler. Raw dataset not included in this repo — see link above to access it directly.

Note for anyone rebuilding this: export the source sheet as **CSV UTF-8**, not plain CSV — the default Windows-1252 export fails on the £ symbol and accented product descriptions during load.

## Project Documentation

- [Executive Summary](docs/Executive_Summary.md)
- [Full EDA Findings](docs/EDA_Findings.md)
- [Data Dictionary](docs/Data_Dictionary.md)
- [SQL & Power BI Rebuild Process](docs/SQL_PowerBI_Process.md)
