-- =====================================================================
-- 03_dml_operations.sql
-- Syllabus: SQL Fundamentals (DML: INSERT, UPDATE, DELETE, SELECT with
--           WHERE, GROUP BY, HAVING, ORDER BY)
-- Runs after 02_dml_seed_data.sql. Lines starting with "-- @query:" name
-- the result that the test runner saves to outputs/03_dml_operations.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- UPDATE 1 (DML: UPDATE ... WHERE)
-- Business question: boAt raises prices by 5%. Update the current price,
-- rounded to the nearest rupee. Old orders keep their price, because
-- order_items.unit_price stores the price at the time of purchase.
-- ---------------------------------------------------------------------
UPDATE products
SET    price = ROUND(price * 1.05, 0)
WHERE  brand = 'boAt';

-- ---------------------------------------------------------------------
-- UPDATE 2 (DML: UPDATE with a subquery, then UPDATE with a JOIN)
-- Business question: the bank confirms the oldest pending UPI payment.
-- Mark that payment SUCCESS, then move its order from PLACED to CONFIRMED.
-- (The inner derived table is needed because MySQL does not allow a
--  subquery to read the same table that is being updated.)
-- ---------------------------------------------------------------------
UPDATE payments
SET    status = 'SUCCESS'
WHERE  payment_id = (SELECT first_id
                     FROM (SELECT MIN(payment_id) AS first_id
                           FROM   payments
                           WHERE  status = 'PENDING' AND method = 'UPI') AS t);

UPDATE orders o
JOIN   payments p ON p.order_id = o.order_id
SET    o.status = 'CONFIRMED'
WHERE  o.status = 'PLACED'
  AND  p.status = 'SUCCESS';

-- ---------------------------------------------------------------------
-- UPDATE 3 (DML: UPDATE with arithmetic)
-- Business question: restock the Bhiwandi warehouse. Every product there
-- that is below its reorder level gets 50 more units.
-- ---------------------------------------------------------------------
UPDATE inventory
SET    quantity = quantity + 50
WHERE  warehouse_id = 1
  AND  quantity < reorder_level;

-- ---------------------------------------------------------------------
-- INSERT + DELETE (DML: DELETE ... WHERE)
-- Business question: a spam sign-up and a test coupon were created by
-- mistake. Insert them, then delete them. The real data is not touched.
-- ---------------------------------------------------------------------
INSERT INTO customers (full_name, email, phone)
VALUES ('Spam Bot', 'spam.bot@example.in', '9000000001');

INSERT INTO discounts (code, description, discount_type, discount_value, valid_from, valid_to)
VALUES ('TEST50', 'Test coupon created by mistake', 'FLAT', 50, '2026-11-01', '2026-11-30');

DELETE FROM customers WHERE email = 'spam.bot@example.in';

DELETE FROM discounts
WHERE  code = 'TEST50'
  AND  discount_id NOT IN (SELECT discount_id FROM order_discounts);

-- ---------------------------------------------------------------------
-- SELECT 1 (DML: SELECT + WHERE + ORDER BY)
-- Business question: which products cost more than Rs 10,000, most
-- expensive first, and how much discount do they show against MRP?
-- ---------------------------------------------------------------------
-- @query: Premium products above Rs 10,000
SELECT product_id,
       product_name,
       brand,
       price,
       mrp,
       ROUND((mrp - price) / mrp * 100, 1) AS pct_off
FROM   products
WHERE  price > 10000
ORDER  BY price DESC;

-- ---------------------------------------------------------------------
-- SELECT 2 (DML: SELECT + GROUP BY + ORDER BY)
-- Business question: in which cities do our customers live?
-- (Each customer has exactly one default address.)
-- ---------------------------------------------------------------------
-- @query: Customers per city
SELECT city,
       state,
       COUNT(*) AS customers
FROM   customer_addresses
WHERE  is_default = TRUE
GROUP  BY city, state
ORDER  BY customers DESC, city;

-- ---------------------------------------------------------------------
-- SELECT 3 (DML: SELECT + GROUP BY + HAVING)
-- Business question: which categories have 3 or more products, and what
-- is their average price?
-- ---------------------------------------------------------------------
-- @query: Categories with 3 or more products
SELECT category_id,
       COUNT(*)             AS products,
       ROUND(AVG(price), 2) AS avg_price,
       MIN(price)           AS cheapest,
       MAX(price)           AS costliest
FROM   products
GROUP  BY category_id
HAVING COUNT(*) >= 3
ORDER  BY products DESC, category_id;

-- ---------------------------------------------------------------------
-- SELECT 4 (DML: SELECT + GROUP BY)
-- Business question: how many orders are in each status?
-- ---------------------------------------------------------------------
-- @query: Orders by status
SELECT status,
       COUNT(*) AS orders
FROM   orders
GROUP  BY status
ORDER  BY orders DESC;

-- ---------------------------------------------------------------------
-- SELECT 5 (DML: SELECT + GROUP BY on two columns + HAVING + ORDER BY)
-- Business question: how do payment attempts split by method and status?
-- Show only combinations that happened more than 5 times.
-- ---------------------------------------------------------------------
-- @query: Payment attempts by method and status (more than 5)
SELECT method,
       status,
       COUNT(*)    AS attempts,
       SUM(amount) AS total_amount
FROM   payments
GROUP  BY method, status
HAVING COUNT(*) > 5
ORDER  BY method, attempts DESC;

-- ---------------------------------------------------------------------
-- SELECT 6 (DML: SELECT + WHERE comparing two columns + ORDER BY)
-- Business question: which stock rows are still below their reorder level
-- after the Bhiwandi restock?
-- ---------------------------------------------------------------------
-- @query: Stock below reorder level
SELECT product_id,
       warehouse_id,
       quantity,
       reorder_level
FROM   inventory
WHERE  quantity < reorder_level
ORDER  BY quantity, product_id;

-- ---------------------------------------------------------------------
-- SELECT 7 (DML: SELECT + WHERE with BETWEEN and LIKE)
-- Business question: which orders were placed during the Diwali sale
-- week (2026-10-25 to 2026-11-01) by customers whose name starts with 'A'?
-- ---------------------------------------------------------------------
-- @query: Diwali-week orders by customers named A...
SELECT o.order_id,
       o.order_date,
       c.full_name,
       o.status
FROM   orders o, customers c
WHERE  o.customer_id = c.customer_id
  AND  o.order_date BETWEEN '2026-10-25' AND '2026-11-01 23:59:59'
  AND  c.full_name LIKE 'A%'
ORDER  BY o.order_date;
