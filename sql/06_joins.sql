-- =====================================================================
-- 06_joins.sql
-- Syllabus: Complex Queries (INNER, LEFT/RIGHT OUTER, FULL OUTER
--           emulation, SELF, CROSS joins; multi-table joins for order and
--           payment analysis)
-- Lines starting with "-- @query:" name the result saved to
-- outputs/06_joins.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- J1. INNER JOIN (2 tables)
-- Business question: what is each product's category?
-- INNER JOIN keeps only rows that have a match on both sides.
-- ---------------------------------------------------------------------
-- @query: J1 INNER JOIN - products with their category
SELECT p.product_id,
       p.product_name,
       c.category_name,
       p.price
FROM   products   p
INNER JOIN categories c ON c.category_id = p.category_id
ORDER  BY c.category_name, p.price DESC;

-- ---------------------------------------------------------------------
-- J2. INNER JOIN (3 tables) + GROUP BY
-- Business question: which are the 10 biggest orders by value, and who
-- placed them?
-- ---------------------------------------------------------------------
-- @query: J2 INNER JOIN - top 10 orders by value
SELECT o.order_id,
       DATE(o.order_date)                 AS order_day,
       c.full_name                        AS customer,
       COUNT(*)                           AS line_items,
       SUM(oi.quantity * oi.unit_price)   AS order_value
FROM   orders      o
INNER JOIN customers   c  ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON oi.order_id   = o.order_id
GROUP  BY o.order_id, o.order_date, c.full_name
ORDER  BY order_value DESC
LIMIT  10;

-- ---------------------------------------------------------------------
-- J3. LEFT OUTER JOIN
-- Business question: how many orders has EVERY customer placed,
-- including customers who never ordered?
-- LEFT JOIN keeps all customers; for those with no orders the order
-- columns are NULL, and COUNT(o.order_id) counts them as 0.
-- ---------------------------------------------------------------------
-- @query: J3 LEFT JOIN - every customer with order count (zero included)
SELECT c.customer_id,
       c.full_name,
       c.signup_date,
       COUNT(o.order_id) AS orders_placed
FROM   customers c
LEFT OUTER JOIN orders o ON o.customer_id = c.customer_id
GROUP  BY c.customer_id, c.full_name, c.signup_date
ORDER  BY orders_placed, c.full_name;

-- ---------------------------------------------------------------------
-- J4. LEFT JOIN ... IS NULL (anti-join)
-- Business question: which products have never been sold?
-- ---------------------------------------------------------------------
-- @query: J4 LEFT JOIN IS NULL - products never sold
SELECT p.product_id,
       p.sku,
       p.product_name,
       p.price
FROM   products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE  oi.product_id IS NULL
ORDER  BY p.product_id;

-- ---------------------------------------------------------------------
-- J5. RIGHT OUTER JOIN
-- Business question: how many times was EVERY coupon used, including
-- coupons nobody used?
-- RIGHT JOIN keeps all rows of the table on the right (discounts).
-- ---------------------------------------------------------------------
-- @query: J5 RIGHT JOIN - every coupon with times used
SELECT d.code,
       d.discount_type,
       d.discount_value,
       COUNT(od.order_id)                AS times_used,
       COALESCE(SUM(od.amount_saved), 0) AS total_saved
FROM   order_discounts od
RIGHT OUTER JOIN discounts d ON d.discount_id = od.discount_id
GROUP  BY d.discount_id, d.code, d.discount_type, d.discount_value
ORDER  BY times_used DESC;

-- ---------------------------------------------------------------------
-- J6. FULL OUTER JOIN (emulated)
-- Business question: which customer cities have no warehouse, and which
-- warehouse cities have no customers? (Where should the next warehouse
-- go?)
-- MySQL has no FULL OUTER JOIN keyword. Standard emulation:
--     LEFT JOIN  (all left rows + matches)
--     UNION      (combine and REMOVE the duplicate matched rows)
--     RIGHT JOIN (all right rows + matches)
-- UNION ALL would show every matched city twice, so UNION is used.
-- ---------------------------------------------------------------------
-- @query: J6 FULL OUTER JOIN (emulated) - customer cities vs warehouse cities
SELECT cc.city          AS customer_city,
       cc.customers,
       w.city           AS warehouse_city,
       w.warehouse_name
FROM   (SELECT city, COUNT(*) AS customers
        FROM   customer_addresses
        WHERE  is_default = TRUE
        GROUP  BY city) AS cc
LEFT JOIN warehouses w ON w.city = cc.city
UNION
SELECT cc.city,
       cc.customers,
       w.city,
       w.warehouse_name
FROM   (SELECT city, COUNT(*) AS customers
        FROM   customer_addresses
        WHERE  is_default = TRUE
        GROUP  BY city) AS cc
RIGHT JOIN warehouses w ON w.city = cc.city
ORDER  BY warehouse_city IS NULL, customer_city;

-- ---------------------------------------------------------------------
-- J7. SELF JOIN (categories)
-- Business question: what is the parent of each category?
-- The same table is used twice with two aliases: child and parent.
-- LEFT JOIN so that top-level categories (no parent) are kept.
-- ---------------------------------------------------------------------
-- @query: J7 SELF JOIN - category and its parent
SELECT child.category_id,
       child.category_name,
       parent.category_name AS parent_category
FROM   categories child
LEFT JOIN categories parent ON parent.category_id = child.parent_category_id
ORDER  BY child.category_id;

-- ---------------------------------------------------------------------
-- J8. SELF JOIN, three levels
-- Business question: show the full path of every 3rd-level category,
-- e.g. Electronics > Mobiles > Smartphones.
-- (A recursive CTE in 12_window_functions_ctes.sql does this for any
--  depth; a self join needs one join per level.)
-- ---------------------------------------------------------------------
-- @query: J8 SELF JOIN - full 3-level category path
SELECT top_level.category_name AS level_1,
       mid_level.category_name AS level_2,
       leaf.category_name      AS level_3,
       CONCAT(top_level.category_name, ' > ', mid_level.category_name,
              ' > ', leaf.category_name) AS full_path
FROM   categories leaf
JOIN   categories mid_level ON mid_level.category_id = leaf.parent_category_id
JOIN   categories top_level ON top_level.category_id = mid_level.parent_category_id
ORDER  BY full_path;

-- ---------------------------------------------------------------------
-- J9. SELF JOIN (customer referrals)
-- Business question: which customer referred whom?
-- ---------------------------------------------------------------------
-- @query: J9 SELF JOIN - who referred whom
SELECT referrer.customer_id AS referrer_id,
       referrer.full_name   AS referred_by,
       newbie.customer_id   AS customer_id,
       newbie.full_name     AS customer,
       newbie.signup_date
FROM   customers newbie
JOIN   customers referrer ON referrer.customer_id = newbie.referred_by
ORDER  BY referrer.full_name, newbie.signup_date;

-- Business question: which customers brought in the most new customers?
-- @query: J9b SELF JOIN + GROUP BY - top referrers
SELECT referrer.full_name AS referrer,
       COUNT(*)           AS customers_referred
FROM   customers newbie
JOIN   customers referrer ON referrer.customer_id = newbie.referred_by
GROUP  BY referrer.customer_id, referrer.full_name
ORDER  BY customers_referred DESC, referrer;

-- ---------------------------------------------------------------------
-- J10. 8-table join: order and payment analysis
-- Business question: for every order of the last 7 days, show the full
-- picture: customer, city, items, value, coupon, payment and delivery.
-- INNER JOIN where a row must exist (customer, items); LEFT JOIN where it
-- may not (address, coupon, payment, delivery). Only the non-failed
-- payment is joined, so failed retries do not double the item rows.
-- ---------------------------------------------------------------------
-- @query: J10 8-table JOIN - last 7 days, full order and payment picture
SELECT o.order_id,
       DATE(o.order_date)                AS order_day,
       c.full_name                       AS customer,
       a.city,
       COUNT(oi.product_id)              AS items,
       SUM(oi.quantity * oi.unit_price)  AS items_value,
       d.code                            AS coupon,
       pay.method                        AS pay_method,
       pay.status                        AS pay_status,
       dl.status                         AS delivery_status,
       o.status                          AS order_status
FROM   orders o
JOIN   customers          c   ON c.customer_id   = o.customer_id
JOIN   order_items        oi  ON oi.order_id     = o.order_id
LEFT JOIN customer_addresses a   ON a.address_id    = o.shipping_address_id
LEFT JOIN order_discounts    od  ON od.order_id     = o.order_id
LEFT JOIN discounts          d   ON d.discount_id   = od.discount_id
LEFT JOIN payments           pay ON pay.order_id    = o.order_id
                                AND pay.status     <> 'FAILED'
LEFT JOIN deliveries         dl  ON dl.order_id     = o.order_id
WHERE  o.order_date >= '2026-11-13'
GROUP  BY o.order_id, o.order_date, c.full_name, a.city, d.code,
          pay.method, pay.status, dl.status, o.status
ORDER  BY o.order_date;

-- ---------------------------------------------------------------------
-- J11. 5-table join + GROUP BY: payment analysis
-- Business question: how much revenue did each top-level category earn
-- through each payment method? (Successful payments on orders that were
-- not cancelled; gross item value before coupons.)
-- ---------------------------------------------------------------------
-- @query: J11 5-table JOIN - revenue by category and payment method
SELECT COALESCE(top_cat.category_name, mid_cat.category_name) AS category,
       pay.method,
       COUNT(DISTINCT o.order_id)       AS orders,
       SUM(oi.quantity * oi.unit_price) AS gross_revenue
FROM   order_items oi
JOIN   orders      o       ON o.order_id     = oi.order_id
JOIN   payments    pay     ON pay.order_id   = o.order_id AND pay.status = 'SUCCESS'
JOIN   products    p       ON p.product_id   = oi.product_id
JOIN   categories  leaf    ON leaf.category_id = p.category_id
JOIN   categories  mid_cat ON mid_cat.category_id = leaf.parent_category_id
-- LEFT JOIN: for 2-level branches (e.g. Books > Fiction) mid_cat is already
-- the top level, so top_cat is NULL and COALESCE falls back to mid_cat.
LEFT JOIN categories top_cat ON top_cat.category_id = mid_cat.parent_category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY COALESCE(top_cat.category_name, mid_cat.category_name), pay.method
ORDER  BY category, gross_revenue DESC;

-- ---------------------------------------------------------------------
-- J12. CROSS JOIN + LEFT JOIN
-- Business question: which products are NOT stocked at all in some
-- warehouse? CROSS JOIN builds every product x warehouse pair (40 x 3 =
-- 120); the LEFT JOIN then finds the pairs with no inventory row.
-- ---------------------------------------------------------------------
-- @query: J12 CROSS JOIN - product/warehouse pairs with no stock row
SELECT p.sku,
       p.product_name,
       w.warehouse_name
FROM   products p
CROSS JOIN warehouses w
LEFT JOIN inventory i ON i.product_id   = p.product_id
                     AND i.warehouse_id = w.warehouse_id
WHERE  i.product_id IS NULL
ORDER  BY w.warehouse_id, p.sku;
