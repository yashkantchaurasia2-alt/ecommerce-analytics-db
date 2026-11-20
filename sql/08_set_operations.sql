-- =====================================================================
-- 08_set_operations.sql
-- Syllabus: Set Operations (UNION, UNION ALL, INTERSECT, EXCEPT, and the
--           MINUS equivalent)
--
-- Rules for every set operation:
--   * both queries return the SAME NUMBER of columns, with compatible types
--   * result column names come from the FIRST query
--   * ORDER BY is written once, at the very end
--   * UNION / INTERSECT / EXCEPT remove duplicates (DISTINCT) by default;
--     UNION ALL keeps them
--
-- MINUS: Oracle's keyword for "rows in A that are not in B". MySQL has no
-- MINUS. Since 8.0.31 MySQL supports the standard EXCEPT, which does the
-- same thing. The older equivalents (NOT EXISTS, LEFT JOIN ... IS NULL)
-- are shown too, because they work on every MySQL version.
--
-- Lines starting with "-- @query:" name the result saved to
-- outputs/08_set_operations.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- U1. UNION
-- Business question: which customers have paid successfully by UPI OR by
-- card? Each customer appears once.
-- ---------------------------------------------------------------------
-- @query: U1 UNION - customers who paid by UPI or card
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
UNION
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- U2. UNION ALL
-- Business question: the same list, but WITHOUT removing duplicates.
-- DISTINCT inside each half gives one row per customer per method, so a
-- customer who used both methods appears exactly twice.
-- ---------------------------------------------------------------------
-- @query: U2 UNION ALL - same list, duplicates kept
SELECT DISTINCT o.customer_id, 'UPI' AS method
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
UNION ALL
SELECT DISTINCT o.customer_id, 'CARD'
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id, method;

-- ---------------------------------------------------------------------
-- U3. UNION vs UNION ALL, side by side
-- Business question: how many rows does each version return, and why?
-- ---------------------------------------------------------------------
-- @query: U3 UNION vs UNION ALL - row counts
SELECT 'UNION (duplicates removed)' AS version, COUNT(*) AS row_count
FROM  (SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
       UNION
       SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE  p.method = 'CARD' AND p.status = 'SUCCESS') AS u
UNION ALL
SELECT 'UNION ALL (duplicates kept)', COUNT(*)
FROM  (SELECT DISTINCT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
       UNION ALL
       SELECT DISTINCT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id
       WHERE  p.method = 'CARD' AND p.status = 'SUCCESS') AS ua;

-- ---------------------------------------------------------------------
-- U4. UNION across two different tables
-- Business question: in which cities do we have customers OR a warehouse?
-- (Our full "presence" map.) A city that has both appears only once.
-- ---------------------------------------------------------------------
-- @query: U4 UNION - every city with a customer or a warehouse
SELECT city FROM customer_addresses WHERE is_default = TRUE
UNION
SELECT city FROM warehouses
ORDER  BY city;

-- ---------------------------------------------------------------------
-- I1. INTERSECT
-- Business question: which customers have paid successfully by BOTH UPI
-- AND card? (They are comfortable with digital payments: good targets
-- for a card-linked UPI cashback offer.)
-- ---------------------------------------------------------------------
-- @query: I1 INTERSECT - customers who paid by both UPI and card
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
INTERSECT
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- I1b. INTERSECT equivalent for MySQL older than 8.0.31: IN
-- Business question: the same as I1.
-- ---------------------------------------------------------------------
-- @query: I1b INTERSECT equivalent with IN - same customers as I1
SELECT DISTINCT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI' AND p.status = 'SUCCESS'
  AND  o.customer_id IN (SELECT o2.customer_id
                         FROM   orders o2 JOIN payments p2 ON p2.order_id = o2.order_id
                         WHERE  p2.method = 'CARD' AND p2.status = 'SUCCESS')
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- I2. INTERSECT
-- Business question: which products sold in BOTH October (Diwali month)
-- AND November? (Steady sellers, not just festive spikes.)
-- ---------------------------------------------------------------------
-- @query: I2 INTERSECT - products sold in both October and November
SELECT oi.product_id
FROM   order_items oi JOIN orders o ON o.order_id = oi.order_id
WHERE  o.order_date >= '2026-10-01' AND o.order_date < '2026-11-01'
INTERSECT
SELECT oi.product_id
FROM   order_items oi JOIN orders o ON o.order_id = oi.order_id
WHERE  o.order_date >= '2026-11-01' AND o.order_date < '2026-12-01'
ORDER  BY product_id;

-- ---------------------------------------------------------------------
-- E1. EXCEPT (this is what Oracle writes as MINUS)
-- Business question: which customers placed orders but NEVER used a
-- coupon? (Send them a first-coupon offer.)
--   Oracle:  SELECT customer_id FROM orders
--            MINUS
--            SELECT o.customer_id FROM orders o JOIN order_discounts od ...
-- ---------------------------------------------------------------------
-- @query: E1 EXCEPT - customers who ordered but never used a coupon
SELECT customer_id
FROM   orders
EXCEPT
SELECT o.customer_id
FROM   orders o JOIN order_discounts od ON od.order_id = o.order_id
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- E1b. MINUS equivalent no. 1: NOT EXISTS
-- Business question: the same as E1 (works on every MySQL version).
-- ---------------------------------------------------------------------
-- @query: E1b MINUS equivalent with NOT EXISTS - same customers as E1
SELECT DISTINCT o.customer_id
FROM   orders o
WHERE  NOT EXISTS (SELECT 1
                   FROM   orders o2 JOIN order_discounts od ON od.order_id = o2.order_id
                   WHERE  o2.customer_id = o.customer_id)
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- E1c. MINUS equivalent no. 2: LEFT JOIN ... IS NULL
-- Business question: the same as E1.
-- ---------------------------------------------------------------------
-- @query: E1c MINUS equivalent with LEFT JOIN IS NULL - same customers as E1
SELECT DISTINCT o.customer_id
FROM   orders o
LEFT JOIN (SELECT DISTINCT o2.customer_id
           FROM   orders o2 JOIN order_discounts od ON od.order_id = o2.order_id) AS used
       ON used.customer_id = o.customer_id
WHERE  used.customer_id IS NULL
ORDER  BY customer_id;

-- ---------------------------------------------------------------------
-- E2. EXCEPT
-- Business question: which catalogue products have never been sold?
-- (All products MINUS the products that appear in order_items.)
-- ---------------------------------------------------------------------
-- @query: E2 EXCEPT - catalogue minus sold products
SELECT product_id, sku FROM products
EXCEPT
SELECT p.product_id, p.sku
FROM   products p JOIN order_items oi ON oi.product_id = p.product_id
ORDER  BY product_id;
