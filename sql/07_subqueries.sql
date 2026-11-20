-- =====================================================================
-- 07_subqueries.sql
-- Syllabus: Subqueries (nested and correlated), IN / NOT IN, scalar,
--           ANY / ALL, EXISTS / NOT EXISTS, subquery in FROM (derived table)
--
-- NESTED (non-correlated) subquery: the inner query does not use any
--   column of the outer query, so MySQL can run it ONCE and reuse the result.
-- CORRELATED subquery: the inner query uses a column of the outer row
--   (e.g. p.category_id), so it is evaluated again FOR EVERY outer row.
--
-- Lines starting with "-- @query:" name the result saved to
-- outputs/07_subqueries.md.
-- =====================================================================

-- =====================================================================
-- A. NESTED SUBQUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- S1. Nested subquery with IN
-- Business question: which customers have bought at least one Apple product?
-- ---------------------------------------------------------------------
-- @query: S1 IN - customers who bought an Apple product
SELECT customer_id, full_name
FROM   customers
WHERE  customer_id IN (
         SELECT o.customer_id
         FROM   orders o
         WHERE  o.order_id IN (
                  SELECT oi.order_id
                  FROM   order_items oi
                  WHERE  oi.product_id IN (SELECT product_id FROM products WHERE brand = 'Apple')))
ORDER  BY full_name;

-- ---------------------------------------------------------------------
-- S2. Nested subquery with NOT IN
-- Business question: which active products were not sold even once in
-- November 2026?
-- Caution: NOT IN returns NO rows if the subquery contains a NULL.
-- order_items.product_id is NOT NULL, so it is safe here; in general
-- NOT EXISTS (S12) is the safer choice.
-- ---------------------------------------------------------------------
-- @query: S2 NOT IN - active products with no sale in November
SELECT product_id, sku, product_name
FROM   products
WHERE  is_active = TRUE
  AND  product_id NOT IN (
         SELECT oi.product_id
         FROM   order_items oi
         WHERE  oi.order_id IN (SELECT order_id FROM orders
                                WHERE  order_date >= '2026-11-01'))
ORDER  BY product_id;

-- ---------------------------------------------------------------------
-- S3. Scalar subquery in WHERE
-- Business question: which products cost more than the average product?
-- A scalar subquery returns exactly one value (one row, one column).
-- ---------------------------------------------------------------------
-- @query: S3 scalar subquery - products above the overall average price
SELECT product_id, product_name, price
FROM   products
WHERE  price > (SELECT AVG(price) FROM products)
ORDER  BY price DESC;

-- ---------------------------------------------------------------------
-- S4. Scalar subquery in SELECT
-- Business question: how far is each product's price from the catalogue
-- average?
-- ---------------------------------------------------------------------
-- @query: S4 scalar subquery in SELECT - price vs catalogue average
SELECT product_name,
       price,
       ROUND((SELECT AVG(price) FROM products), 2)         AS catalogue_avg,
       ROUND(price - (SELECT AVG(price) FROM products), 2) AS diff_from_avg
FROM   products
ORDER  BY diff_from_avg DESC;

-- ---------------------------------------------------------------------
-- S5. Multi-level nesting (4 levels deep)
-- Business question: which customers bought something from our
-- best-selling category (by units sold)?
-- Read from the inside out:
--   level 4: best category  -> level 3: its products
--   level 2: orders containing them -> level 1: their customers
-- (MySQL does not allow LIMIT directly inside IN (...), so the "top 1"
--  is wrapped in a derived table.)
-- ---------------------------------------------------------------------
-- @query: S5 multi-level nesting - customers of the best-selling category
SELECT customer_id, full_name
FROM   customers
WHERE  customer_id IN (
         SELECT customer_id FROM orders
         WHERE  order_id IN (
                  SELECT order_id FROM order_items
                  WHERE  product_id IN (
                           SELECT product_id FROM products
                           WHERE  category_id = (
                                    SELECT category_id
                                    FROM  (SELECT p.category_id, SUM(oi.quantity) AS units
                                           FROM   order_items oi
                                           JOIN   products p ON p.product_id = oi.product_id
                                           GROUP  BY p.category_id
                                           ORDER  BY units DESC
                                           LIMIT  1) AS best))))
ORDER  BY full_name;

-- ---------------------------------------------------------------------
-- S6. ALL and ANY
-- Business question (a): which products cost more than EVERY book?
--   > ALL (list)  means  greater than the maximum of the list.
-- Business question (b): which products are cheaper than AT LEAST ONE book?
--   < ANY (list)  means  less than the maximum of the list.
-- ---------------------------------------------------------------------
-- @query: S6a ALL - products costlier than every book
SELECT product_name, price
FROM   products
WHERE  price > ALL (SELECT p.price
                    FROM   products p
                    WHERE  p.category_id IN (SELECT category_id FROM categories
                                             WHERE  parent_category_id =
                                                    (SELECT category_id FROM categories
                                                     WHERE  category_name = 'Books')))
ORDER  BY price
LIMIT  10;

-- (22, 23 = Fiction and Non-Fiction, the two Books sub-categories)
-- @query: S6b ANY - non-book products cheaper than at least one book
SELECT product_name, price
FROM   products
WHERE  category_id NOT IN (22, 23)
  AND  price < ANY (SELECT price FROM products WHERE category_id IN (22, 23))
ORDER  BY price;

-- =====================================================================
-- B. CORRELATED SUBQUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- S7. Correlated subquery in WHERE
-- Business question: which products are priced above THEIR OWN
-- category's average?
-- p2.category_id = p.category_id links the inner query to the outer row,
-- so the category average is recalculated for every product.
-- ---------------------------------------------------------------------
-- @query: S7 correlated - products above their category average
SELECT p.product_name,
       p.category_id,
       p.price,
       (SELECT ROUND(AVG(p2.price), 2)
        FROM   products p2
        WHERE  p2.category_id = p.category_id) AS category_avg
FROM   products p
WHERE  p.price > (SELECT AVG(p2.price)
                  FROM   products p2
                  WHERE  p2.category_id = p.category_id)
ORDER  BY p.category_id, p.price DESC;

-- ---------------------------------------------------------------------
-- S8. Correlated subquery: latest row per group
-- Business question: what is each customer's most recent order?
-- ---------------------------------------------------------------------
-- @query: S8 correlated - each customer's latest order
SELECT c.customer_id,
       c.full_name,
       o.order_id,
       o.order_date,
       o.status
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
WHERE  o.order_date = (SELECT MAX(o2.order_date)
                       FROM   orders o2
                       WHERE  o2.customer_id = o.customer_id)
ORDER  BY o.order_date DESC;

-- ---------------------------------------------------------------------
-- S9. Correlated subqueries in SELECT
-- Business question: for each customer, how many orders have they placed
-- and how much have they actually paid (successful payments on orders
-- that were not cancelled)? Top 15 by spend.
-- ---------------------------------------------------------------------
-- @query: S9 correlated in SELECT - orders and spend per customer (top 15)
SELECT c.customer_id,
       c.full_name,
       (SELECT COUNT(*)
        FROM   orders o
        WHERE  o.customer_id = c.customer_id) AS orders_placed,
       (SELECT COALESCE(SUM(p.amount), 0)
        FROM   payments p
        JOIN   orders o ON o.order_id = p.order_id
        WHERE  o.customer_id = c.customer_id
          AND  p.status = 'SUCCESS'
          AND  o.status <> 'CANCELLED') AS total_spend
FROM   customers c
ORDER  BY total_spend DESC, c.customer_id
LIMIT  15;

-- ---------------------------------------------------------------------
-- S10. Correlated subquery comparing a row with its own group
-- Business question: which orders were bigger than that customer's OWN
-- average order value? (A sign of an unusually large purchase.)
-- customer's average = all their item value / number of their orders
-- ---------------------------------------------------------------------
-- @query: S10 correlated - orders above the customer's own average
SELECT o.order_id,
       o.customer_id,
       (SELECT SUM(oi.quantity * oi.unit_price)
        FROM   order_items oi
        WHERE  oi.order_id = o.order_id) AS order_value,
       ROUND((SELECT SUM(oi2.quantity * oi2.unit_price)
              FROM   order_items oi2
              JOIN   orders o2 ON o2.order_id = oi2.order_id
              WHERE  o2.customer_id = o.customer_id)
           / (SELECT COUNT(*) FROM orders o3 WHERE o3.customer_id = o.customer_id), 2)
                                         AS customer_avg
FROM   orders o
WHERE  (SELECT SUM(oi.quantity * oi.unit_price)
        FROM   order_items oi
        WHERE  oi.order_id = o.order_id)
     > (SELECT SUM(oi2.quantity * oi2.unit_price)
        FROM   order_items oi2
        JOIN   orders o2 ON o2.order_id = oi2.order_id
        WHERE  o2.customer_id = o.customer_id)
     / (SELECT COUNT(*) FROM orders o3 WHERE o3.customer_id = o.customer_id)
ORDER  BY o.customer_id, o.order_id;

-- =====================================================================
-- C. EXISTS / NOT EXISTS
-- EXISTS only asks "is there at least one row?". It stops at the first
-- match, and NULLs in the subquery cannot break it (unlike NOT IN).
-- =====================================================================

-- ---------------------------------------------------------------------
-- S11. EXISTS (correlated)
-- Business question: which customers have had at least one failed
-- payment? (Candidates for a "payment trouble?" help message.)
-- ---------------------------------------------------------------------
-- @query: S11 EXISTS - customers with at least one failed payment
SELECT c.customer_id, c.full_name
FROM   customers c
WHERE  EXISTS (SELECT 1
               FROM   orders o
               JOIN   payments p ON p.order_id = o.order_id
               WHERE  o.customer_id = c.customer_id
                 AND  p.status = 'FAILED')
ORDER  BY c.full_name;

-- ---------------------------------------------------------------------
-- S12. NOT EXISTS (correlated)
-- Business question: which customers signed up but never placed an order?
-- (Target them with the WELCOME100 coupon.)
-- ---------------------------------------------------------------------
-- @query: S12 NOT EXISTS - customers who never ordered
SELECT c.customer_id, c.full_name, c.signup_date
FROM   customers c
WHERE  NOT EXISTS (SELECT 1
                   FROM   orders o
                   WHERE  o.customer_id = c.customer_id)
ORDER  BY c.signup_date;

-- =====================================================================
-- D. SUBQUERY IN FROM (derived tables)
-- =====================================================================

-- ---------------------------------------------------------------------
-- S13. Two levels of derived tables
-- Business question: split customers into High / Medium / Low value by
-- their average order value.
--   per_order    : value of every order
--   per_customer : average order value of every customer + segment
--   outer query  : how many customers fall in each segment
-- ---------------------------------------------------------------------
-- @query: S13 derived tables - customer segments by average order value
SELECT segment,
       COUNT(*)                         AS customers,
       ROUND(AVG(avg_order_value), 2)   AS avg_order_value
FROM  (SELECT customer_id,
              AVG(order_value) AS avg_order_value,
              CASE
                  WHEN AVG(order_value) >= 20000 THEN 'High'
                  WHEN AVG(order_value) >= 5000  THEN 'Medium'
                  ELSE 'Low'
              END AS segment
       FROM  (SELECT o.customer_id,
                     o.order_id,
                     SUM(oi.quantity * oi.unit_price) AS order_value
              FROM   orders o
              JOIN   order_items oi ON oi.order_id = o.order_id
              GROUP  BY o.customer_id, o.order_id) AS per_order
       GROUP  BY customer_id) AS per_customer
GROUP  BY segment
ORDER  BY avg_order_value DESC;

-- ---------------------------------------------------------------------
-- S14. Derived table + scalar subquery
-- Business question: which months earned more than the average month?
-- (Revenue = successful payments on orders that were not cancelled.)
-- The same derived table is written twice here; a CTE (WITH ...) in
-- 12_window_functions_ctes.sql removes that repetition.
-- ---------------------------------------------------------------------
-- @query: S14 derived table - months above the average monthly revenue
SELECT m.month,
       m.revenue
FROM  (SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
              SUM(p.amount)                      AS revenue
       FROM   orders o
       JOIN   payments p ON p.order_id = o.order_id
       WHERE  p.status = 'SUCCESS' AND o.status <> 'CANCELLED'
       GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')) AS m
WHERE  m.revenue > (SELECT AVG(m2.revenue)
                    FROM  (SELECT SUM(p.amount) AS revenue
                           FROM   orders o
                           JOIN   payments p ON p.order_id = o.order_id
                           WHERE  p.status = 'SUCCESS' AND o.status <> 'CANCELLED'
                           GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')) AS m2)
ORDER  BY m.month;
