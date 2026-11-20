-- =====================================================================
-- 09_customer_product_analytics.sql
-- Syllabus: Complex Queries (joins, GROUP BY / HAVING, subqueries) used
--           for the project requirements:
--             * identify REPEAT CUSTOMERS
--             * identify BEST-SELLING PRODUCTS
--             * ORDER and PAYMENT analysis
-- (Window-function versions of the rankings are in
--  12_window_functions_ctes.sql.)
--
-- Definitions used by every query in this file:
--   NET REVENUE   = amount of SUCCESS payments on orders that are not
--                   CANCELLED (coupon savings are already deducted).
--   GROSS VALUE   = SUM(quantity * unit_price) of the items, before coupon.
--                   Used for product-level figures, because a coupon applies
--                   to the whole order, not to one product.
--   UNITS SOLD    = item quantities on orders that are not CANCELLED.
--   "TODAY"       = 2026-11-20, the date of the sample data set.
--
-- Lines starting with "-- @query:" name the result saved to
-- outputs/09_customer_product_analytics.md.
-- =====================================================================

-- =====================================================================
-- A. CUSTOMERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- A1. Repeat customers (JOIN + GROUP BY + HAVING)
-- Business question: which customers have ordered more than once, and how
-- loyal and valuable are they?
-- ---------------------------------------------------------------------
-- @query: A1 Repeat customers (more than 1 order)
SELECT c.customer_id,
       c.full_name,
       COUNT(DISTINCT o.order_id)          AS orders_placed,
       DATE(MIN(o.order_date))             AS first_order,
       DATE(MAX(o.order_date))             AS last_order,
       COALESCE(SUM(pay.amount), 0)        AS net_spend
FROM   customers c
JOIN   orders o ON o.customer_id = c.customer_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
                      AND pay.status   = 'SUCCESS'
                      AND o.status    <> 'CANCELLED'
GROUP  BY c.customer_id, c.full_name
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER  BY orders_placed DESC, net_spend DESC;

-- ---------------------------------------------------------------------
-- A2. Repeat purchase rate (derived table)
-- Business question: out of all customers who ordered, what percentage
-- came back for another order?
-- ---------------------------------------------------------------------
-- @query: A2 Repeat purchase rate
SELECT COUNT(*)                                  AS ordering_customers,
       SUM(order_count > 1)                      AS repeat_customers,
       SUM(order_count = 1)                      AS one_time_customers,
       ROUND(100 * SUM(order_count > 1) / COUNT(*), 1) AS repeat_rate_pct
FROM  (SELECT customer_id, COUNT(*) AS order_count
       FROM   orders
       GROUP  BY customer_id) AS per_customer;

-- ---------------------------------------------------------------------
-- A3. Top customers by net spend (4-table join)
-- Business question: who are our 10 most valuable customers?
-- ---------------------------------------------------------------------
-- @query: A3 Top 10 customers by net spend
SELECT c.customer_id,
       c.full_name,
       a.city,
       COUNT(*)                  AS paid_orders,
       SUM(pay.amount)           AS net_spend,
       ROUND(AVG(pay.amount), 2) AS avg_order_value
FROM   customers c
JOIN   orders   o   ON o.customer_id  = c.customer_id
JOIN   payments pay ON pay.order_id   = o.order_id AND pay.status = 'SUCCESS'
LEFT JOIN customer_addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
WHERE  o.status <> 'CANCELLED'
GROUP  BY c.customer_id, c.full_name, a.city
ORDER  BY net_spend DESC
LIMIT  10;

-- ---------------------------------------------------------------------
-- A4. Referral impact (correlated subqueries inside a derived table)
-- Business question: do referred customers order more and spend more than
-- customers who came directly?
-- ---------------------------------------------------------------------
-- @query: A4 Referred vs direct customers
SELECT source,
       COUNT(*)                 AS customers,
       ROUND(AVG(orders), 2)    AS avg_orders,
       ROUND(AVG(spend), 2)     AS avg_net_spend,
       SUM(orders = 0)          AS never_ordered
FROM  (SELECT c.customer_id,
              IF(c.referred_by IS NULL, 'Direct', 'Referred') AS source,
              (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS orders,
              (SELECT COALESCE(SUM(p.amount), 0)
               FROM   payments p JOIN orders o ON o.order_id = p.order_id
               WHERE  o.customer_id = c.customer_id
                 AND  p.status = 'SUCCESS' AND o.status <> 'CANCELLED') AS spend
       FROM   customers c) AS per_customer
GROUP  BY source
ORDER  BY source;

-- =====================================================================
-- B. PRODUCTS
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1. Best-selling products by QUANTITY
-- Business question: which 10 products sell the most units?
-- ---------------------------------------------------------------------
-- @query: B1 Best-selling products by quantity (top 10)
SELECT p.product_id,
       p.product_name,
       cat.category_name,
       SUM(oi.quantity)                  AS units_sold,
       COUNT(DISTINCT oi.order_id)       AS orders,
       SUM(oi.quantity * oi.unit_price)  AS gross_value
FROM   order_items oi
JOIN   orders     o   ON o.order_id     = oi.order_id
JOIN   products   p   ON p.product_id   = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY p.product_id, p.product_name, cat.category_name
ORDER  BY units_sold DESC, gross_value DESC
LIMIT  10;

-- ---------------------------------------------------------------------
-- B2. Best-selling products by REVENUE
-- Business question: which 10 products bring in the most money?
-- (Different from B1: a cable sells many units cheaply, a phone sells
--  fewer units but earns far more.)
-- ---------------------------------------------------------------------
-- @query: B2 Best-selling products by revenue (top 10)
SELECT p.product_id,
       p.product_name,
       cat.category_name,
       SUM(oi.quantity)                  AS units_sold,
       SUM(oi.quantity * oi.unit_price)  AS gross_value,
       ROUND(100 * SUM(oi.quantity * oi.unit_price)
             / (SELECT SUM(oi2.quantity * oi2.unit_price)
                FROM   order_items oi2 JOIN orders o2 ON o2.order_id = oi2.order_id
                WHERE  o2.status <> 'CANCELLED'), 2) AS share_pct
FROM   order_items oi
JOIN   orders     o   ON o.order_id     = oi.order_id
JOIN   products   p   ON p.product_id   = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY p.product_id, p.product_name, cat.category_name
ORDER  BY gross_value DESC
LIMIT  10;

-- ---------------------------------------------------------------------
-- B3. Best-selling product in EACH category (without window functions)
-- Business question: what is the number-one product (by units) in every
-- category?
-- Method: product totals JOIN category maximum ON units = maximum.
-- If two products tie for the top spot, both are shown (that is the
-- correct answer; ROW_NUMBER() in file 12 shows how to force one).
-- ---------------------------------------------------------------------
-- @query: B3 Best-selling product per category
SELECT cat.category_name,
       s.product_name,
       s.units_sold
FROM  (SELECT p.category_id, p.product_id, p.product_name,
              SUM(oi.quantity) AS units_sold
       FROM   order_items oi
       JOIN   orders   o ON o.order_id   = oi.order_id
       JOIN   products p ON p.product_id = oi.product_id
       WHERE  o.status <> 'CANCELLED'
       GROUP  BY p.category_id, p.product_id, p.product_name) AS s
JOIN  (SELECT category_id, MAX(units_sold) AS max_units
       FROM  (SELECT p.category_id, p.product_id, SUM(oi.quantity) AS units_sold
              FROM   order_items oi
              JOIN   orders   o ON o.order_id   = oi.order_id
              JOIN   products p ON p.product_id = oi.product_id
              WHERE  o.status <> 'CANCELLED'
              GROUP  BY p.category_id, p.product_id) AS t
       GROUP  BY category_id) AS m
       ON m.category_id = s.category_id AND m.max_units = s.units_sold
JOIN   categories cat ON cat.category_id = s.category_id
ORDER  BY s.units_sold DESC, cat.category_name;

-- ---------------------------------------------------------------------
-- B4. Stock health of the best sellers
-- Business question: are our 10 best-selling products in stock, or do we
-- need to reorder?
-- ---------------------------------------------------------------------
-- @query: B4 Stock of the top 10 best sellers
SELECT top10.product_name,
       top10.units_sold,
       SUM(i.quantity)                        AS stock_all_warehouses,
       SUM(i.quantity = 0)                    AS warehouses_out_of_stock,
       SUM(i.quantity < i.reorder_level)      AS warehouses_below_reorder
FROM  (SELECT p.product_id, p.product_name, SUM(oi.quantity) AS units_sold
       FROM   order_items oi
       JOIN   orders   o ON o.order_id   = oi.order_id
       JOIN   products p ON p.product_id = oi.product_id
       WHERE  o.status <> 'CANCELLED'
       GROUP  BY p.product_id, p.product_name
       ORDER  BY units_sold DESC
       LIMIT  10) AS top10
JOIN   inventory i ON i.product_id = top10.product_id
GROUP  BY top10.product_id, top10.product_name, top10.units_sold
ORDER  BY top10.units_sold DESC;

-- =====================================================================
-- C. ORDERS AND PAYMENTS
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1. Average order value (AOV)
-- Business question: how much does a typical paid order bring in?
-- ---------------------------------------------------------------------
-- @query: C1 Average order value
SELECT COUNT(*)                 AS paid_orders,
       SUM(pay.amount)          AS net_revenue,
       ROUND(AVG(pay.amount), 2) AS avg_order_value,
       MIN(pay.amount)          AS smallest_order,
       MAX(pay.amount)          AS biggest_order
FROM   payments pay
JOIN   orders   o ON o.order_id = pay.order_id
WHERE  pay.status = 'SUCCESS'
  AND  o.status  <> 'CANCELLED';

-- ---------------------------------------------------------------------
-- C2. Revenue by payment method (scalar subquery for the share)
-- Business question: how do customers pay, and which method brings the
-- most money?
-- ---------------------------------------------------------------------
-- @query: C2 Revenue by payment method
SELECT pay.method,
       COUNT(*)                  AS paid_orders,
       SUM(pay.amount)           AS net_revenue,
       ROUND(AVG(pay.amount), 2) AS avg_order_value,
       ROUND(100 * SUM(pay.amount)
             / (SELECT SUM(p2.amount)
                FROM   payments p2 JOIN orders o2 ON o2.order_id = p2.order_id
                WHERE  p2.status = 'SUCCESS' AND o2.status <> 'CANCELLED'), 2) AS share_pct
FROM   payments pay
JOIN   orders   o ON o.order_id = pay.order_id
WHERE  pay.status = 'SUCCESS'
  AND  o.status  <> 'CANCELLED'
GROUP  BY pay.method
ORDER  BY net_revenue DESC;

-- ---------------------------------------------------------------------
-- C3. Payment failure rate by method
-- Business question: which payment method fails most often? (Talk to that
-- payment partner.)
-- ---------------------------------------------------------------------
-- @query: C3 Payment failure rate by method
SELECT method,
       COUNT(*)                                   AS attempts,
       SUM(status = 'SUCCESS')                    AS succeeded,
       SUM(status = 'FAILED')                     AS failed,
       SUM(status = 'PENDING')                    AS pending,
       ROUND(100 * SUM(status = 'FAILED') / COUNT(*), 1) AS failure_rate_pct
FROM   payments
GROUP  BY method
ORDER  BY failure_rate_pct DESC;

-- ---------------------------------------------------------------------
-- C4. Monthly revenue
-- Business question: how did sales move month by month?
-- (Month-over-month change with LAG() is in file 12.)
-- ---------------------------------------------------------------------
-- @query: C4 Monthly revenue
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
       COUNT(*)                           AS paid_orders,
       SUM(pay.amount)                    AS net_revenue,
       ROUND(AVG(pay.amount), 2)          AS avg_order_value
FROM   orders   o
JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
WHERE  o.status <> 'CANCELLED'
GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER  BY month;

-- ---------------------------------------------------------------------
-- C5. Orders with failed or pending payments
-- Business question: which orders had payment trouble, and where does each
-- one stand now (recovered on retry, money still pending, or lost)?
-- ---------------------------------------------------------------------
-- @query: C5 Orders with failed or pending payments
SELECT o.order_id,
       DATE(o.order_date)                         AS order_day,
       c.full_name                                AS customer,
       GROUP_CONCAT(CONCAT(pay.method, ':', pay.status)
                    ORDER BY pay.payment_id SEPARATOR ' -> ') AS payment_attempts,
       CASE
           WHEN SUM(pay.status = 'SUCCESS') > 0 THEN 'Recovered on retry'
           WHEN SUM(pay.status = 'PENDING') > 0 THEN 'Money pending'
           ELSE 'Failed - order cancelled'
       END                                        AS outcome,
       o.status                                   AS order_status
FROM   orders o
JOIN   customers c  ON c.customer_id = o.customer_id
JOIN   payments pay ON pay.order_id  = o.order_id
GROUP  BY o.order_id, o.order_date, c.full_name, o.status
HAVING SUM(pay.status IN ('FAILED', 'PENDING')) > 0
ORDER  BY outcome, o.order_date;

-- ---------------------------------------------------------------------
-- C6. Orders not yet delivered
-- Business question: which live orders are still waiting for delivery,
-- and for how many days? (Oldest first, so support can chase them.)
-- ---------------------------------------------------------------------
-- @query: C6 Orders not yet delivered
SELECT o.order_id,
       DATE(o.order_date)                       AS order_day,
       DATEDIFF('2026-11-20', o.order_date)     AS days_waiting,
       c.full_name                              AS customer,
       o.status                                 AS order_status,
       COALESCE(d.status, 'NOT CREATED')        AS delivery_status,
       d.courier,
       w.warehouse_name
FROM   orders o
JOIN   customers  c ON c.customer_id = o.customer_id
LEFT JOIN deliveries d ON d.order_id     = o.order_id
LEFT JOIN warehouses w ON w.warehouse_id = d.warehouse_id
WHERE  o.status NOT IN ('DELIVERED', 'CANCELLED')
ORDER  BY days_waiting DESC, o.order_id;

-- ---------------------------------------------------------------------
-- C7. Courier performance
-- Business question: which courier delivers fastest, and which has the
-- most returns?
-- ---------------------------------------------------------------------
-- @query: C7 Courier performance
SELECT courier,
       COUNT(*)                                             AS shipments,
       SUM(status = 'DELIVERED')                            AS delivered,
       SUM(status = 'RETURNED')                             AS returned,
       ROUND(AVG(CASE WHEN status = 'DELIVERED'
                      THEN DATEDIFF(delivered_date, shipped_date) END), 2) AS avg_transit_days,
       ROUND(100 * SUM(status = 'RETURNED')
             / NULLIF(SUM(status IN ('DELIVERED', 'RETURNED')), 0), 1)   AS return_rate_pct
FROM   deliveries
GROUP  BY courier
ORDER  BY avg_transit_days;

-- =====================================================================
-- D. DISCOUNTS
-- =====================================================================

-- ---------------------------------------------------------------------
-- D1. Coupon usage and impact
-- Business question: how often is each coupon used, how much discount has
-- it given away, and how big are the orders that use it?
-- ---------------------------------------------------------------------
-- @query: D1 Coupon usage and impact
SELECT d.code,
       d.discount_type,
       d.discount_value,
       d.min_order_value,
       COUNT(od.order_id)                            AS times_used,
       COALESCE(SUM(od.amount_saved), 0)             AS total_discount_given,
       ROUND(AVG(od.amount_saved), 2)                AS avg_saving,
       ROUND(AVG((SELECT SUM(oi.quantity * oi.unit_price)
                  FROM   order_items oi
                  WHERE  oi.order_id = od.order_id)), 2) AS avg_order_gross
FROM   discounts d
LEFT JOIN order_discounts od ON od.discount_id = d.discount_id
GROUP  BY d.discount_id, d.code, d.discount_type, d.discount_value, d.min_order_value
ORDER  BY times_used DESC, d.code;

-- ---------------------------------------------------------------------
-- D2. Orders with a coupon vs without
-- Business question: do orders with a coupon have a bigger basket?
-- (Paid, not-cancelled orders only.)
-- ---------------------------------------------------------------------
-- @query: D2 Coupon vs no-coupon orders
SELECT IF(od.order_id IS NULL, 'No coupon', 'With coupon') AS order_type,
       COUNT(*)                                          AS paid_orders,
       ROUND(AVG(g.gross_value), 2)                      AS avg_gross_value,
       ROUND(AVG(COALESCE(od.amount_saved, 0)), 2)       AS avg_saving,
       ROUND(AVG(pay.amount), 2)                         AS avg_net_paid
FROM   orders o
JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
JOIN  (SELECT order_id, SUM(quantity * unit_price) AS gross_value
       FROM   order_items
       GROUP  BY order_id) AS g ON g.order_id = o.order_id
LEFT JOIN order_discounts od ON od.order_id = o.order_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY IF(od.order_id IS NULL, 'No coupon', 'With coupon')
ORDER  BY order_type DESC;
