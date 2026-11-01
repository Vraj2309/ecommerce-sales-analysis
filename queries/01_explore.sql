
-- Q1. How many rows does each table have?
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'reviews',     COUNT(*) FROM reviews
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'sellers',     COUNT(*) FROM sellers;


-- Q2. What time period does the data cover?
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;


-- Q3. How many orders were placed each month?
-- (Look for months with very few orders at the start and end -
--  those are incomplete and should be left out of trend analysis.)
SELECT strftime('%Y-%m', order_purchase_timestamp) AS month,
       COUNT(*) AS orders
FROM orders
GROUP BY month
ORDER BY month;


-- Q4. Data quality: delivered orders with no delivery date?
SELECT COUNT(*) AS delivered_without_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;


-- Q5. IMPORTANT: customer_id vs customer_unique_id
-- In this dataset a new customer_id is created for every order.
-- customer_unique_id identifies the real person.
-- You MUST use customer_unique_id for repeat-customer analysis.
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS real_customers
FROM customers;


-- Q6. How do customers pay?
SELECT payment_type,
       COUNT(*) AS payments,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM payments), 1) AS pct
FROM payments
GROUP BY payment_type
ORDER BY payments DESC;


-- Q7. How are review scores distributed?
SELECT review_score,
       COUNT(*) AS reviews,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM reviews), 1) AS pct
FROM reviews
GROUP BY review_score
ORDER BY review_score DESC;


-- Q8. How many products have no category?
SELECT COUNT(*) AS products_without_category
FROM products
WHERE product_category_name IS NULL;


-- Q9. How many items does a typical order contain?
SELECT items_in_order,
       COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS items_in_order
    FROM order_items
    GROUP BY order_id
)
GROUP BY items_in_order
ORDER BY items_in_order;
