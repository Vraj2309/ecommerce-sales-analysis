-- Step 1. How many orders arrive late? Actual vs promised delivery time
SELECT COUNT(*) AS delivered_orders,
       SUM(CASE WHEN date(order_delivered_customer_date)
                     > date(order_estimated_delivery_date)
                THEN 1 ELSE 0 END) AS late_orders,
       ROUND(100.0 * SUM(CASE WHEN date(order_delivered_customer_date)
                                   > date(order_estimated_delivery_date)
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(julianday(order_delivered_customer_date)
                 - julianday(order_purchase_timestamp)), 1) AS avg_delivery_days,
       ROUND(AVG(julianday(order_estimated_delivery_date)
                 - julianday(order_purchase_timestamp)), 1) AS avg_promised_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';


-- Step 2. Late vs on-time orders: review scores
-- Reviews are averaged per order first, so orders with 2+ reviews
-- are not double-counted after the join.
WITH delivery AS (
    SELECT order_id,
           CASE WHEN date(order_delivered_customer_date)
                     > date(order_estimated_delivery_date)
                THEN 'Late' ELSE 'On time' END AS delivery_status
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
),
order_reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT d.delivery_status,
       COUNT(*) AS orders,
       ROUND(AVG(r.review_score), 2) AS avg_review,
       ROUND(100.0 * SUM(CASE WHEN r.review_score = 1  THEN 1 ELSE 0 END) / COUNT(*), 1) AS one_star_pct,
       ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS negative_pct,
       ROUND(100.0 * SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS positive_pct
FROM delivery d
JOIN order_reviews r ON d.order_id = r.order_id
GROUP BY d.delivery_status;


-- Step 3. Review score by how many days late (binning with CASE)
-- Number prefixes ("0.", "1.", ...) keep the groups in the right order.
WITH delivery AS (
    SELECT order_id,
           julianday(date(order_delivered_customer_date))
             - julianday(date(order_estimated_delivery_date)) AS days_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
),
order_reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews
    GROUP BY order_id
)
SELECT CASE
           WHEN d.days_late <= 0  THEN '0. On time'
           WHEN d.days_late <= 3  THEN '1. 1-3 days late'
           WHEN d.days_late <= 7  THEN '2. 4-7 days late'
           WHEN d.days_late <= 14 THEN '3. 8-14 days late'
           ELSE                        '4. 15+ days late'
       END AS delay_group,
       COUNT(*) AS orders,
       ROUND(AVG(r.review_score), 2) AS avg_review,
       ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS one_star_pct
FROM delivery d
JOIN order_reviews r ON d.order_id = r.order_id
GROUP BY delay_group
ORDER BY delay_group;


-- Step 4. Late-delivery rate and delivery time by customer state
SELECT c.customer_state AS state,
       COUNT(*) AS orders,
       ROUND(100.0 * SUM(CASE WHEN date(o.order_delivered_customer_date)
                                   > date(o.order_estimated_delivery_date)
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(julianday(o.order_delivered_customer_date)
                 - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,
       ROUND(AVG(julianday(o.order_estimated_delivery_date)
                 - julianday(o.order_purchase_timestamp)), 1) AS avg_promised_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY c.customer_state
ORDER BY late_pct DESC;
