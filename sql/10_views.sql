-- =====================================================================
-- 10_views.sql
-- Syllabus: Views and Indexing (views) + DCL (GRANT / REVOKE on views)
--
-- A VIEW is a saved SELECT that behaves like a virtual table. It stores
-- no data of its own; every time it is queried, MySQL runs its SELECT on
-- the base tables, so it is always up to date.
-- Why use views:
--   * simplicity : a long 6-table join becomes "SELECT * FROM vw_..."
--   * security   : a user can be given the view without the base tables,
--                  so they see only the rows and columns the view exposes
--   * consistency: everyone uses the same definition of "net revenue"
--
-- "Today" is 2026-11-20 (the sample data date). In production the views
-- would use CURDATE() instead of the fixed date.
-- Lines starting with "-- @query:" name the result saved to
-- outputs/10_views.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- VIEW 1: vw_order_summary
-- Business question: give me ONE row per order with everything support
-- needs: customer, items, money, payment state and delivery state.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT o.order_id,
       o.order_date,
       o.customer_id,
       c.full_name                         AS customer,
       o.status                            AS order_status,
       g.items,
       g.gross_value,
       COALESCE(od.discount, 0)            AS discount,
       g.gross_value - COALESCE(od.discount, 0) AS payable,
       COALESCE(pay.paid_amount, 0)        AS net_paid,
       CASE
           WHEN pay.successes > 0 THEN 'PAID'
           WHEN pay.pendings  > 0 THEN 'PENDING'
           ELSE 'FAILED'
       END                                 AS payment_status,
       pay.attempts                        AS payment_attempts,
       COALESCE(dl.status, 'NOT CREATED')  AS delivery_status
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
JOIN  (SELECT order_id,
              COUNT(*)                     AS items,
              SUM(quantity * unit_price)   AS gross_value
       FROM   order_items
       GROUP  BY order_id) AS g ON g.order_id = o.order_id
LEFT JOIN (SELECT order_id, SUM(amount_saved) AS discount
           FROM   order_discounts
           GROUP  BY order_id) AS od ON od.order_id = o.order_id
LEFT JOIN (SELECT order_id,
                  COUNT(*)                                         AS attempts,
                  SUM(status = 'SUCCESS')                          AS successes,
                  SUM(status = 'PENDING')                          AS pendings,
                  SUM(CASE WHEN status = 'SUCCESS' THEN amount END) AS paid_amount
           FROM   payments
           GROUP  BY order_id) AS pay ON pay.order_id = o.order_id
LEFT JOIN deliveries dl ON dl.order_id = o.order_id;

-- ---------------------------------------------------------------------
-- VIEW 2: vw_product_sales
-- Business question: for every product, how much has it sold, how much
-- has it earned, and how much stock is left?
-- (Units and revenue count only orders that were not cancelled.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_product_sales AS
SELECT p.product_id,
       p.sku,
       p.product_name,
       cat.category_name,
       p.brand,
       p.price,
       COALESCE(s.units_sold, 0)     AS units_sold,
       COALESCE(s.orders, 0)         AS orders,
       COALESCE(s.gross_revenue, 0)  AS gross_revenue,
       COALESCE(st.stock, 0)         AS stock_left
FROM   products p
JOIN   categories cat ON cat.category_id = p.category_id
LEFT JOIN (SELECT oi.product_id,
                  SUM(oi.quantity)                 AS units_sold,
                  COUNT(DISTINCT oi.order_id)      AS orders,
                  SUM(oi.quantity * oi.unit_price) AS gross_revenue
           FROM   order_items oi
           JOIN   orders o ON o.order_id = oi.order_id
           WHERE  o.status <> 'CANCELLED'
           GROUP  BY oi.product_id) AS s ON s.product_id = p.product_id
LEFT JOIN (SELECT product_id, SUM(quantity) AS stock
           FROM   inventory
           GROUP  BY product_id) AS st ON st.product_id = p.product_id;

-- ---------------------------------------------------------------------
-- VIEW 3: vw_customer_lifetime_value
-- Business question: how valuable is each customer over their whole
-- relationship with us (lifetime value), and which segment are they in?
-- lifetime_value = net revenue (SUCCESS payments, order not cancelled).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_lifetime_value AS
SELECT c.customer_id,
       c.full_name,
       a.city,
       c.signup_date,
       COALESCE(o.orders_placed, 0)   AS orders_placed,
       COALESCE(v.paid_orders, 0)     AS paid_orders,
       COALESCE(v.lifetime_value, 0)  AS lifetime_value,
       ROUND(v.lifetime_value / v.paid_orders, 2) AS avg_order_value,
       o.first_order,
       o.last_order,
       CASE
           WHEN COALESCE(v.lifetime_value, 0) >= 100000 THEN 'High'
           WHEN COALESCE(v.lifetime_value, 0) >= 25000  THEN 'Medium'
           WHEN COALESCE(v.lifetime_value, 0) >  0      THEN 'Low'
           ELSE 'No purchase'
       END                            AS segment
FROM   customers c
LEFT JOIN customer_addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
LEFT JOIN (SELECT customer_id,
                  COUNT(*)              AS orders_placed,
                  DATE(MIN(order_date)) AS first_order,
                  DATE(MAX(order_date)) AS last_order
           FROM   orders
           GROUP  BY customer_id) AS o ON o.customer_id = c.customer_id
LEFT JOIN (SELECT ord.customer_id,
                  COUNT(*)        AS paid_orders,
                  SUM(pay.amount) AS lifetime_value
           FROM   orders ord
           JOIN   payments pay ON pay.order_id = ord.order_id AND pay.status = 'SUCCESS'
           WHERE  ord.status <> 'CANCELLED'
           GROUP  BY ord.customer_id) AS v ON v.customer_id = c.customer_id;

-- ---------------------------------------------------------------------
-- VIEW 4: vw_pending_deliveries
-- Business question: which live orders have not been delivered yet, and
-- how long has each customer been waiting?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_pending_deliveries AS
SELECT o.order_id,
       DATE(o.order_date)                    AS order_day,
       DATEDIFF('2026-11-20', o.order_date)  AS days_waiting,
       c.full_name                           AS customer,
       a.city                                AS ship_to_city,
       o.status                              AS order_status,
       COALESCE(d.status, 'NOT CREATED')     AS delivery_status,
       d.courier,
       d.tracking_no,
       w.warehouse_name
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
LEFT JOIN customer_addresses a ON a.address_id   = o.shipping_address_id
LEFT JOIN deliveries d         ON d.order_id     = o.order_id
LEFT JOIN warehouses w         ON w.warehouse_id = d.warehouse_id
WHERE  o.status NOT IN ('DELIVERED', 'CANCELLED');

-- ---------------------------------------------------------------------
-- VIEW 5: vw_active_products (UPDATABLE view WITH CHECK OPTION)
-- Business question: give the order clerk a "live catalogue" they can
-- correct prices in, without letting them touch inactive products or
-- deactivate anything.
-- It reads ONE table with no GROUP BY / DISTINCT / JOIN, so MySQL lets
-- UPDATE statements go through the view to the products table.
-- WITH CHECK OPTION: an UPDATE or INSERT through the view is rejected if
-- the resulting row would no longer satisfy the view's WHERE clause.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_active_products AS
SELECT product_id, sku, product_name, category_id, brand, price, mrp, is_active
FROM   products
WHERE  is_active = TRUE
WITH CASCADED CHECK OPTION;

-- =====================================================================
-- Using the views
-- =====================================================================

-- Views (querying a view) | Business question: what are the 10 most recent orders and their payment/delivery state?
-- @query: V1 vw_order_summary - the 10 most recent orders
SELECT order_id, order_date, customer, items, gross_value, discount,
       net_paid, payment_status, delivery_status
FROM   vw_order_summary
ORDER  BY order_date DESC
LIMIT  10;

-- Views (querying a view) | Business question: which products earn the most, and how much stock is left?
-- @query: V2 vw_product_sales - top 10 products by revenue, with stock left
SELECT product_name, category_name, units_sold, gross_revenue, stock_left
FROM   vw_product_sales
ORDER  BY gross_revenue DESC
LIMIT  10;

-- Views + GROUP BY | Business question: how many customers and how much value are in each segment?
-- @query: V3 vw_customer_lifetime_value - customers per segment
SELECT segment,
       COUNT(*)                    AS customers,
       SUM(lifetime_value)         AS total_value,
       ROUND(AVG(lifetime_value), 2) AS avg_value
FROM   vw_customer_lifetime_value
GROUP  BY segment
ORDER  BY total_value DESC;

-- Views (querying a view) | Business question: who are our 5 most valuable customers?
-- @query: V3b vw_customer_lifetime_value - top 5 customers
SELECT customer_id, full_name, city, orders_placed, lifetime_value, segment
FROM   vw_customer_lifetime_value
ORDER  BY lifetime_value DESC
LIMIT  5;

-- Views + WHERE | Business question: which customers have waited more than 3 days for delivery?
-- @query: V4 vw_pending_deliveries - waiting more than 3 days
SELECT order_id, order_day, days_waiting, customer, delivery_status, courier
FROM   vw_pending_deliveries
WHERE  days_waiting > 3
ORDER  BY days_waiting DESC;

-- ---------------------------------------------------------------------
-- Updating THROUGH a view
-- Business question: the clerk corrects the kettle price via the view.
-- The change lands in the products table. It is then put back, so later
-- files see the original price.
-- ---------------------------------------------------------------------
UPDATE vw_active_products SET price = 649 WHERE sku = 'PGN-KTL';

-- Views (updatable view) | Business question: did the UPDATE through the view reach the products table?
-- @query: V5 price changed through the view is visible in the base table
SELECT sku, price FROM products WHERE sku = 'PGN-KTL';

UPDATE vw_active_products SET price = 699 WHERE sku = 'PGN-KTL';

-- WITH CHECK OPTION in action (this statement is REJECTED, so it is not
-- run here; tests/run_tests.py runs it and expects error 1369):
--   UPDATE vw_active_products SET is_active = FALSE WHERE sku = 'PGN-KTL';
--   ERROR 1369 (HY000): CHECK OPTION failed 'vw_active_products'

-- =====================================================================
-- DCL on views: the analyst becomes VIEW-ONLY (promised in file 04)
-- Views use SQL SECURITY DEFINER by default: they run with the rights of
-- the user who created them, so the analyst can read a view without
-- having SELECT on the tables underneath.
-- =====================================================================
SET @db = DATABASE();

-- Plain form: REVOKE SELECT ON ecommerce_db.* FROM r_analyst;
SET @sql = CONCAT('REVOKE SELECT ON `', @db, '`.* FROM r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Plain form: GRANT SELECT ON ecommerce_db.vw_order_summary TO r_analyst;  (and so on)
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.vw_order_summary TO r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.vw_product_sales TO r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.vw_customer_lifetime_value TO r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.vw_pending_deliveries TO r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- The clerk may correct prices of ACTIVE products through the view, while
-- the products table itself stays read-only for them.
-- Plain form: GRANT SELECT, UPDATE ON ecommerce_db.vw_active_products TO r_order_clerk;
SET @sql = CONCAT('GRANT SELECT, UPDATE ON `', @db, '`.vw_active_products TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- DCL on views | Business question: is the analyst now limited to views only?
-- @query: V6 r_analyst grants after the change (views only)
SHOW GRANTS FOR 'r_analyst';

-- Views (catalog) | Business question: which views exist, and which one is updatable?
-- @query: V7 all views in this database
SELECT table_name AS view_name, is_updatable, check_option, security_type
FROM   information_schema.views
WHERE  table_schema = DATABASE()
ORDER  BY table_name;
