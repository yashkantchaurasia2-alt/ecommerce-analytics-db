-- =====================================================================
-- demo_script.sql : 6-minute live demo for the viva
-- Run against the main database after:  python tools/build_main_db.py
-- Run one block at a time (select it and execute). The whole file is also
-- safe to run end to end: it changes no data (the transaction demo ends in
-- ROLLBACK).
-- =====================================================================

-- ---------------------------------------------------------------------
-- [0:00] 1. THE DATABASE  (Relational model)
-- Say: "12 tables in BCNF, 15 foreign keys, 23 CHECK constraints,
--       realistic Indian sample data across 7 months."
-- ---------------------------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'deliveries',  COUNT(*) FROM deliveries;

-- ---------------------------------------------------------------------
-- [0:45] 2. SELF-REFERENCE + RECURSIVE CTE  (ER model, advanced SQL)
-- Say: "categories.parent_category_id points to categories itself.
--       A recursive CTE walks the tree to any depth."
-- ---------------------------------------------------------------------
WITH RECURSIVE category_tree AS (
    SELECT category_id, category_name, 1 AS level,
           CAST(category_name AS CHAR(255)) AS path
    FROM   categories WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.category_name, t.level + 1,
           CONCAT(t.path, ' > ', c.category_name)
    FROM   categories c JOIN category_tree t ON c.parent_category_id = t.category_id
)
SELECT level, path FROM category_tree ORDER BY path;

-- ---------------------------------------------------------------------
-- [1:30] 3. INTEGRITY CONSTRAINTS  (Normalization & integrity)
-- Say: "The database itself refuses bad data." Run these two lines on
-- their own to show the errors (they are commented out so the file can
-- run end to end):
--   INSERT INTO products (sku, product_name, category_id, price) VALUES ('BAD1', 'Bad', 3, -10);
--     -> ERROR 3819: Check constraint 'chk_products_price' is violated.
--   INSERT INTO orders (customer_id) VALUES (99999);
--     -> ERROR 1452: Cannot add or update a child row: a foreign key constraint fails
-- ---------------------------------------------------------------------
SELECT constraint_name, check_clause
FROM   information_schema.check_constraints
WHERE  constraint_schema = DATABASE()
  AND  constraint_name IN ('chk_products_price', 'chk_inventory_quantity', 'chk_orders_status');

-- ---------------------------------------------------------------------
-- [2:15] 4. TRANSACTION + ROLLBACK  (TCL, ACID)
-- Say: "Payment failed, so ROLLBACK undoes the order AND the stock change."
-- ---------------------------------------------------------------------
SELECT quantity AS stock_before
FROM   inventory WHERE product_id = 38 AND warehouse_id = 3;      -- Atomic Habits, Bengaluru

START TRANSACTION;
INSERT INTO orders (customer_id, order_date, status) VALUES (7, '2026-11-20 15:00:00', 'PLACED');
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (LAST_INSERT_ID(), 38, 5, 399.00);
UPDATE inventory SET quantity = quantity - 5 WHERE product_id = 38 AND warehouse_id = 3;

SELECT quantity AS stock_inside_transaction
FROM   inventory WHERE product_id = 38 AND warehouse_id = 3;      -- 5 less

ROLLBACK;                                                         -- payment failed

SELECT quantity AS stock_after_rollback
FROM   inventory WHERE product_id = 38 AND warehouse_id = 3;      -- back to the start

-- ---------------------------------------------------------------------
-- [3:15] 5. REPEAT CUSTOMERS  (project requirement)
-- Say: "GROUP BY + HAVING COUNT > 1. 34 of 44 ordering customers came back."
-- ---------------------------------------------------------------------
SELECT c.full_name,
       COUNT(*)              AS orders_placed,
       DATE(MIN(o.order_date)) AS first_order,
       DATE(MAX(o.order_date)) AS last_order
FROM   customers c JOIN orders o ON o.customer_id = c.customer_id
GROUP  BY c.customer_id, c.full_name
HAVING COUNT(*) > 1
ORDER  BY orders_placed DESC
LIMIT  10;

-- ---------------------------------------------------------------------
-- [3:45] 6. BEST SELLERS: units vs revenue  (project requirement)
-- Say: "By units the cheap boAt earbuds win; by money the OnePlus phone
--       wins. Both answers matter."
-- ---------------------------------------------------------------------
SELECT product_name, units_sold, gross_revenue
FROM   vw_product_sales
ORDER  BY units_sold DESC
LIMIT  5;

SELECT product_name, units_sold, gross_revenue
FROM   vw_product_sales
ORDER  BY gross_revenue DESC
LIMIT  5;

-- ---------------------------------------------------------------------
-- [4:15] 7. RANK vs DENSE_RANK vs ROW_NUMBER  (window functions)
-- Say: "Spigen and Portronics tie on 37 units: RANK gives 2, 2 then 4;
--       DENSE_RANK gives 2, 2 then 3; ROW_NUMBER is always unique."
-- ---------------------------------------------------------------------
SELECT product_name,
       units_sold,
       ROW_NUMBER() OVER (ORDER BY units_sold DESC, product_id) AS row_num,
       RANK()       OVER (ORDER BY units_sold DESC)             AS rnk,
       DENSE_RANK() OVER (ORDER BY units_sold DESC)             AS dense_rnk
FROM   vw_product_sales
WHERE  units_sold > 0
ORDER  BY units_sold DESC, product_id
LIMIT  8;

-- Month-over-month change with LAG
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month, SUM(p.amount) AS revenue
    FROM   orders o JOIN payments p ON p.order_id = o.order_id AND p.status = 'SUCCESS'
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month, revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
                 / LAG(revenue) OVER (ORDER BY month), 1) AS change_pct
FROM   monthly ORDER BY month;

-- ---------------------------------------------------------------------
-- [5:00] 8. SET OPERATIONS
-- Say: "INTERSECT = paid by BOTH UPI and card. EXCEPT (MySQL's MINUS) =
--       ordered but never used a coupon."
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS paid_by_upi_and_card
FROM  (SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE p.method = 'UPI' AND p.status = 'SUCCESS'
       INTERSECT
       SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE p.method = 'CARD' AND p.status = 'SUCCESS') AS both_methods;

SELECT COUNT(*) AS ordered_but_never_used_coupon
FROM  (SELECT customer_id FROM orders
       EXCEPT
       SELECT o.customer_id FROM orders o JOIN order_discounts od ON od.order_id = o.order_id) AS no_coupon;

-- ---------------------------------------------------------------------
-- [5:30] 9. VIEWS + DCL
-- Say: "The analyst can read these views but not one base table (error
--       1142 on SELECT * FROM orders)."
-- ---------------------------------------------------------------------
SELECT full_name, orders_placed, lifetime_value, segment
FROM   vw_customer_lifetime_value
ORDER  BY lifetime_value DESC
LIMIT  5;

SHOW GRANTS FOR 'r_analyst';

-- ---------------------------------------------------------------------
-- [6:00] 10. INDEXES + EXPLAIN
-- Say: "type = ref and key = idx_payments_status_method: MySQL reads 3
--       rows instead of scanning all 300+ payments."
-- ---------------------------------------------------------------------
EXPLAIN SELECT payment_id, order_id, amount
FROM   payments
WHERE  status = 'PENDING';
