-- ============================================================
-- XÓM COFFEE — SQL CASE STUDY
-- Platform  : Xóm Dataset (dataset.xomdata.com)
-- Database  : SQL Server (SSMS)
-- Schema    : coffee_shop.transactions
-- Data range: 2025-01-01 → 2025-06-30
-- ============================================================
--
-- TABLE SCHEMA
-- ┌─────────────────────────────────────────────────────────┐
-- │ coffee_shop.transactions (11 cols)                      │
-- │   transaction_id      int           PK                  │
-- │   transaction_date    datetime                          │
-- │   transaction_time    time                              │
-- │   transaction_qty     int                               │
-- │   store_id            int                               │
-- │   store_location      nvarchar                          │
-- │   product_id          int                               │
-- │   unit_price          decimal                           │
-- │   product_category    nvarchar                          │
-- │   product_type        nvarchar                          │
-- │   product_detail      nvarchar                          │
-- └─────────────────────────────────────────────────────────┘
--
-- KEY NOTES
-- • Flat table — no joins needed for revenue
-- • Revenue = unit_price * transaction_qty
-- • No receipt_id → cannot compute true basket size
--   (use store + date + time as proxy receipt)
-- • No customer_id → no cohort/retention analysis
-- ============================================================


-- ============================================================
-- DATA OVERVIEW — Run first to validate dataset
-- ============================================================
SELECT
    COUNT(*)                                    AS total_rows,
    COUNT(DISTINCT transaction_id)              AS total_transactions,
    COUNT(DISTINCT store_id)                    AS total_stores,
    COUNT(DISTINCT product_id)                  AS total_products,
    MIN(CAST(transaction_date AS DATE))         AS date_from,
    MAX(CAST(transaction_date AS DATE))         AS date_to
FROM coffee_shop.transactions;
-- total_rows = 149,116 | stores = 3 | products = 80
-- date range: 2025-01-01 → 2025-06-30


-- ============================================================
-- Q1: Total revenue — 6 months
-- Stakeholder: Store Operations Manager
-- Tags: aggregation
-- ============================================================
SELECT
    FORMAT(SUM(unit_price * transaction_qty), 'C', 'en-US') AS total_revenue
FROM coffee_shop.transactions;
-- Result: $698,812.33


-- ============================================================
-- Q2: Total transactions per store — 6 months
-- Stakeholder: Store Operations Manager
-- Tags: group-by, count
-- ============================================================
SELECT
    store_id,
    store_location,
    COUNT(transaction_id)               AS total_transactions
FROM coffee_shop.transactions
GROUP BY store_id, store_location
ORDER BY total_transactions DESC;
-- Finding: Hell's Kitchen has highest transaction volume


-- ============================================================
-- Q3: Top 10 best-selling products by quantity sold
-- Stakeholder: Head of Merchandising (reorder priority)
-- Tags: top, group-by, sum
-- ============================================================
SELECT TOP 10
    product_id,
    product_category,
    product_type,
    product_detail,
    SUM(transaction_qty)                AS qty_sold
FROM coffee_shop.transactions
GROUP BY product_id, product_category, product_type, product_detail
ORDER BY qty_sold DESC;
-- Use this list top-down for reorder prioritization


-- ============================================================
-- Q4: Total revenue by category
-- Stakeholder: Head of Merchandising
-- Tags: group-by, format
-- Note: ORDER BY numeric value, NOT the FORMAT() alias
--       (FORMAT returns VARCHAR → alphabetical sort = wrong)
-- ============================================================
SELECT
    product_category,
    FORMAT(SUM(unit_price * transaction_qty), 'C', 'en-US') AS category_total_rev
FROM coffee_shop.transactions
GROUP BY product_category
ORDER BY SUM(unit_price * transaction_qty) DESC;


-- ============================================================
-- Q5: Average unit price by category — identify high-ticket items
-- Stakeholder: Head of Pricing
-- Tags: avg, group-by
-- ============================================================
SELECT
    product_category,
    FORMAT(AVG(unit_price), 'C', 'en-US')   AS avg_unit_price
FROM coffee_shop.transactions
GROUP BY product_category
ORDER BY AVG(unit_price) DESC;
-- Finding: Coffee Beans is highest avg unit price (high-ticket)


-- ============================================================
-- Q6: Transaction count by hour of day per store — peak hour analysis
-- Stakeholder: Marketing Manager (happy hour promo planning)
-- Tags: datepart, group-by
-- ============================================================
SELECT
    store_location,
    DATEPART(HOUR, transaction_time)                        AS hour_of_day,
    FORMAT(DATEPART(HOUR, transaction_time), '00') + ':00'  AS hour_label,
    COUNT(transaction_id)                                   AS total_transactions,
    FORMAT(SUM(unit_price * transaction_qty), 'C', 'en-US') AS total_revenue
FROM coffee_shop.transactions
GROUP BY store_location, DATEPART(HOUR, transaction_time)
ORDER BY store_location ASC, hour_of_day ASC;
-- Finding: All 3 stores peak at 10:00 AM, sharp drop after 11:00 AM
-- Promo windows: Astoria 14-16:00 | HK 12-14:00 | LM 11-13:00


-- ============================================================
-- Q7: Weekday vs Weekend revenue per store — staffing schedule
-- Stakeholder: Store Operations Manager
-- Tags: case-when, datepart(weekday), group-by
-- Note: DATEPART(WEEKDAY) → 1=Sunday, 7=Saturday
--       Must repeat CASE WHEN in GROUP BY (alias not allowed)
-- ============================================================
SELECT
    store_location,
    CASE
        WHEN DATEPART(WEEKDAY, transaction_date) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END                                                         AS day_type,
    COUNT(transaction_id)                                       AS total_transactions,
    FORMAT(SUM(unit_price * transaction_qty), 'C', 'en-US')     AS total_revenue
FROM coffee_shop.transactions
GROUP BY store_location,
    CASE
        WHEN DATEPART(WEEKDAY, transaction_date) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END
ORDER BY store_location ASC, day_type ASC;
-- Finding: Weekday/Weekend split ~71%/29% consistent across all stores
-- Weekend revenue per day slightly higher → keep upselling staff on weekends


-- ============================================================
-- Q8: Revenue by weekday per store — find slow days for promo
-- Stakeholder: Marketing Manager
-- Tags: datename, datepart, where, group-by
-- Note: DATENAME returns day name (Monday/Tuesday...)
--       DATEPART returns number (2-6 for Mon-Fri)
-- ============================================================
SELECT
    store_location,
    DATENAME(WEEKDAY, transaction_date)                     AS day_name,
    DATEPART(WEEKDAY, transaction_date)                     AS day_num,
    COUNT(transaction_id)                                   AS total_transactions,
    FORMAT(SUM(unit_price * transaction_qty), 'C', 'en-US') AS total_revenue
FROM coffee_shop.transactions
WHERE DATEPART(WEEKDAY, transaction_date) IN (2, 3, 4, 5, 6)
GROUP BY
    store_location,
    DATENAME(WEEKDAY, transaction_date),
    DATEPART(WEEKDAY, transaction_date)
ORDER BY store_location ASC, SUM(unit_price * transaction_qty) ASC;
-- Slow days: Astoria=Friday | Hell's Kitchen=Tuesday | Lower Manhattan=Wednesday
-- Chain-wide promo: Tuesday (weakest in 2/3 stores)
-- Best window: Tuesday 11:00–14:00 combined with Q6 off-peak hours


-- ============================================================
-- Q9: Avg daily basket size (unique products sold per store per day)
-- Stakeholder: Head of Merchandising
-- Tags: cte, count-distinct, avg
-- ⚠️  No receipt_id in dataset → cannot compute true basket size
--     Proxy: COUNT(DISTINCT product_id) per store per day
-- ============================================================
WITH daily_basket AS (
    SELECT
        store_location,
        CAST(transaction_date AS DATE)          AS txn_date,
        COUNT(DISTINCT product_id)              AS unique_products
    FROM coffee_shop.transactions
    GROUP BY store_location, CAST(transaction_date AS DATE)
)
SELECT
    store_location,
    ROUND(AVG(CAST(unique_products AS FLOAT)), 1)   AS avg_daily_basket_size
FROM daily_basket
GROUP BY store_location
ORDER BY avg_daily_basket_size DESC;
-- Results: HK=59.8 | LM=59.3 | Astoria=56.4 (out of 80 SKUs)
-- All stores sell 70-75% of catalog daily
-- To get true basket size: receipt_id must be added to POS system


-- ============================================================
-- Q10: Cross-category purchase rate — cross-sell index
-- Stakeholder: CMO
-- Tags: cte, count-distinct, case-when, proxy-receipt
-- ⚠️  No receipt_id → proxy = store_id + date + time
-- Definition: receipt with >= 2 different categories = cross-category
-- ============================================================
WITH receipt_level AS (
    -- Step 1+2: Group by proxy receipt, count unique categories
    SELECT
        store_location,
        store_id,
        CAST(transaction_date AS DATE)          AS txn_date,
        transaction_time,
        COUNT(DISTINCT product_category)        AS unique_categories
    FROM coffee_shop.transactions
    GROUP BY store_location, store_id,
             CAST(transaction_date AS DATE),
             transaction_time
),
cross_cat AS (
    -- Step 3: Flag receipts with >= 2 categories
    SELECT
        store_location,
        COUNT(*)                                AS total_receipts,
        SUM(CASE
                WHEN unique_categories >= 2 THEN 1
                ELSE 0
            END)                                AS cross_category_receipts
    FROM receipt_level
    GROUP BY store_location
)
-- Step 4: Calculate cross-sell %
SELECT
    store_location,
    total_receipts,
    cross_category_receipts,
    ROUND(100.0 * cross_category_receipts / total_receipts, 1) AS cross_cat_pct
FROM cross_cat
ORDER BY cross_cat_pct DESC;
-- Results: LM=30.2% | HK=22.8% | Astoria=22.0%
-- ~75-78% of purchases are single-category → strong upsell opportunity
-- Recommend: combo deals at Astoria & HK, benchmark LM practices


-- ============================================================
-- Q11: Monthly revenue + MoM growth % per store
-- Stakeholder: Store Operations Manager
-- Tags: cte, window-function, lag, mom
-- ============================================================
WITH monthly_rev AS (
    SELECT
        store_location,
        MONTH(transaction_date)                 AS mth,
        SUM(transaction_qty * unit_price)       AS revenue
    FROM coffee_shop.transactions
    GROUP BY store_location, MONTH(transaction_date)
),
mom AS (
    SELECT
        store_location,
        mth,
        revenue,
        LAG(revenue, 1) OVER (
            PARTITION BY store_location
            ORDER BY mth
        )                                       AS prev_revenue
    FROM monthly_rev
)
SELECT
    store_location,
    mth,
    CAST(revenue AS DECIMAL(18,2))              AS revenue,
    CAST(prev_revenue AS DECIMAL(18,2))         AS prev_revenue,
    CASE
        WHEN prev_revenue IS NULL THEN 'N/A'
        ELSE CONCAT(
            ROUND(100.0 * (revenue - prev_revenue) / prev_revenue, 1),
            '%'
        )
    END                                         AS mom_growth
FROM mom
ORDER BY store_location ASC, mth ASC;
-- Feb dip across all stores → seasonal (28 days), not operational issue
-- Strong growth Mar→May (+20% to +33% MoM)
-- Jun stabilizing (+5-8%) — healthy normalization after growth spike
-- Hell's Kitchen leads absolute revenue at Jun ($56,957)


-- ============================================================
-- Q12: Top 3 best-selling SKUs per store
-- Stakeholder: Head of Merchandising
-- Tags: cte, rank, partition-by, window-function
-- Note: RANK() used to capture ties (vs ROW_NUMBER)
-- ============================================================
WITH sold_qty AS (
    SELECT
        store_id,
        store_location,
        product_id,
        product_category,
        product_detail,
        SUM(transaction_qty)                    AS sold
    FROM coffee_shop.transactions
    GROUP BY store_id, store_location, product_id,
             product_category, product_detail
),
ranked AS (
    SELECT
        store_id,
        store_location,
        product_id,
        product_category,
        product_detail,
        sold,
        RANK() OVER (
            PARTITION BY store_location
            ORDER BY sold DESC
        )                                       AS rank_in_store
    FROM sold_qty
)
SELECT
    store_id,
    store_location,
    product_id,
    product_category,
    product_detail,
    sold,
    rank_in_store
FROM ranked
WHERE rank_in_store <= 3
ORDER BY store_location ASC, rank_in_store ASC;
-- Each store has a distinct personality:
-- Astoria      → Drinking Chocolate + Tea dominant (no Coffee in top 3)
-- Hell's Kitchen → Coffee #1 (Ouro Brasileiro), then Tea
-- Lower Manhattan → Tea dominant, Coffee only rank 3
-- Recommendation: tailor reorder list per store profile
