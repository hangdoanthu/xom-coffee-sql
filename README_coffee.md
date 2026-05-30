# Xóm Coffee — SQL Case Study

> **Platform:** [Xóm Dataset](https://dataset.xomdata.com/) · **Tool:** SQL Server (SSMS) · **Schema:** `coffee_shop`

## Business Context

Xóm Coffee is a specialty coffee chain with 3 locations in Manhattan. The POS system records ~150,000 transactions over 6 months across 80 SKUs spanning coffee, tea, drinking chocolate, bakery, and merchandise.

| Metric | Value |
|---|---|
| Locations | Astoria, Hell's Kitchen, Lower Manhattan |
| Total Transactions | 149,116 |
| Product Catalog | 80 SKUs |
| Data Range | 2025-01-01 → 2025-06-30 |
| Total Revenue | $698,812.33 |

---

## Schema

```
coffee_shop.transactions (11 cols) — flat table, no joins needed
├── transaction_id      int         PK
├── transaction_date    datetime
├── transaction_time    time
├── transaction_qty     int
├── store_id            int
├── store_location      nvarchar    Astoria | Hell's Kitchen | Lower Manhattan
├── product_id          int
├── unit_price          decimal
├── product_category    nvarchar
├── product_type        nvarchar
└── product_detail      nvarchar    most granular SKU name
```

> **Revenue formula:** `unit_price * transaction_qty` — always multiply, never use `unit_price` alone.

> **Limitations:** No `receipt_id` → cannot compute true basket size or cross-category per receipt. No `customer_id` → no cohort or retention analysis.

---

## Queries

| # | Question | Stakeholder | Concepts |
|---|---|---|---|
| Q1 | Total revenue 6 months | Store Ops Manager | `SUM`, `FORMAT` |
| Q2 | Total transactions per store | Store Ops Manager | `COUNT`, `GROUP BY` |
| Q3 | Top 10 best-selling SKUs by quantity | Head of Merchandising | `TOP`, `SUM`, `GROUP BY` |
| Q4 | Total revenue by category | Head of Merchandising | `GROUP BY`, `ORDER BY` numeric |
| Q5 | Avg unit price by category (high-ticket) | Head of Pricing | `AVG`, `GROUP BY` |
| Q6 | Transactions by hour of day per store | Marketing Manager | `DATEPART(HOUR)`, `GROUP BY` |
| Q7 | Weekday vs Weekend revenue per store | Store Ops Manager | `DATEPART(WEEKDAY)`, `CASE WHEN` |
| Q8 | Slow days per store (weekdays only) | Marketing Manager | `DATENAME`, `WHERE`, `ORDER BY` |
| Q9 | Avg daily basket size per store | Head of Merchandising | CTE, `COUNT DISTINCT`, proxy receipt |
| Q10 | Cross-category purchase rate | CMO | CTE, proxy receipt, `CASE WHEN` |
| Q11 | Monthly revenue + MoM growth % | Store Ops Manager | CTE, `LAG()`, `PARTITION BY` |
| Q12 | Top 3 SKUs per store | Head of Merchandising | CTE, `RANK()`, `PARTITION BY` |

---

## Key Findings

### Peak Hours (Q6)
All 3 stores peak at **10:00 AM** with a sharp drop after 11:00 AM. Recommended happy hour windows:
- Astoria → **14:00–16:00**
- Hell's Kitchen → **12:00–14:00**
- Lower Manhattan → **11:00–13:00**

### Weekday vs Weekend (Q7)
Consistent **71% / 29%** split across all stores. Weekend revenue per day is slightly higher → customers spend more per visit on weekends.

### Slow Days (Q8)
| Store | Slowest Day |
|---|---|
| Astoria | Friday |
| Hell's Kitchen | Tuesday |
| Lower Manhattan | Wednesday |

Chain-wide promo recommendation: **Tuesday** (weakest in 2/3 stores).

### MoM Growth (Q11)
February dip across all stores due to shorter month (28 days), not an operational issue. Strong growth March→May (+20% to +33% MoM). Hell's Kitchen leads absolute revenue in June ($56,957).

### Cross-sell (Q10)
| Store | Cross-cat Rate |
|---|---|
| Lower Manhattan | 30.2% |
| Hell's Kitchen | 22.8% |
| Astoria | 22.0% |

~75–78% of purchases are single-category → significant upsell opportunity via combo deals.

### Store Personality (Q12)
- **Astoria** → Drinking Chocolate + Tea dominant
- **Hell's Kitchen** → Coffee-first (Ouro Brasileiro shot #1)
- **Lower Manhattan** → Tea dominant

---

## Key Learnings

**Flat POS table — always multiply quantity**
`SUM(unit_price)` gives wrong revenue. Always `SUM(unit_price * transaction_qty)`.

**ORDER BY FORMAT() alias = wrong sort**
`FORMAT()` returns VARCHAR. `ORDER BY category_total_rev` sorts alphabetically: `"$9,000" > "$10,000"`. Always `ORDER BY SUM(...)` for numeric sorting.

**DATEPART(DAY) vs DATEPART(WEEKDAY)**
`DAY` = day of month (1–31). `WEEKDAY` = day of week (1=Sunday, 7=Saturday). Confusing these two returns completely wrong results.

**CASE WHEN in GROUP BY must be repeated verbatim**
SQL Server does not allow aliases in `GROUP BY`. The full `CASE WHEN` expression must be copy-pasted exactly.

**LAG() for MoM growth**
`LAG(revenue, 1) OVER (PARTITION BY store ORDER BY mth)` retrieves previous month's value. `PARTITION BY store` ensures the lag resets per store — without it, January of Store B would incorrectly inherit December of Store A.

**Proxy receipt when receipt_id is missing**
`store_id + transaction_date + transaction_time` as a proxy groups likely same-purchase rows. Flagged as a data quality gap to POS team.

---

## Notes

- All queries use **SQL Server syntax**: `TOP N`, `DATEPART`, `DATENAME`, `FORMAT`, `LAG`.
- `LIMIT` is not valid in SQL Server — use `SELECT TOP N`.
- Dataset is a flat single table — no joins required.

---

## Repository Structure

```
xom-coffee-sql/
├── xom_coffee_analysis.sql   ← Q1–Q12 with inline comments and findings
└── README.md
```

---

*Case study completed as part of the [Xóm Dataset](https://dataset.xomdata.com/) learning path.*
