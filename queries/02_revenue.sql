
-- Step 1. Monthly revenue, orders and average order value
SELECT strftime('%Y-%m', o.order_purchase_timestamp)        AS month,
       COUNT(DISTINCT o.order_id)                            AS orders,
       ROUND(SUM(oi.price), 2)                               AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY month
ORDER BY month;


-- Step 2. Month-over-month growth and running total
-- LAG() gets the previous month's revenue; SUM() OVER builds a running total.
WITH monthly AS (
    SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 0)                                AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY month), 0)     AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1)   AS mom_growth_pct,
       ROUND(SUM(revenue) OVER (ORDER BY month), 0)     AS running_total
FROM monthly
ORDER BY month;


-- Step 3. Top 10 categories by revenue, with share of total and rank
-- COALESCE keeps uncategorised products as 'unknown' instead of dropping them.
WITH category_sales AS (
    SELECT COALESCE(t.product_category_name_english,
                    p.product_category_name,
                    'unknown')            AS category,
           COUNT(DISTINCT o.order_id)     AS orders,
           SUM(oi.price)                  AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    LEFT JOIN category_translation t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY category
)
SELECT category,
       orders,
       ROUND(revenue, 0)                                  AS revenue,
       ROUND(revenue / orders, 2)                         AS avg_order_value,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)   AS revenue_share_pct,
       RANK() OVER (ORDER BY revenue DESC)                AS revenue_rank
FROM category_sales
ORDER BY revenue DESC
LIMIT 10;
