-- =====================================================================
-- 12_window_functions_ctes.sql
-- Syllabus: Advanced SQL (window functions and CTEs, including recursive
--           CTEs). Project requirement: "use window functions to rank
--           products based on sales performance".
--
-- WINDOW FUNCTION: calculates over a "window" of related rows but, unlike
-- GROUP BY, does NOT collapse them: every row stays, and gets an extra
-- value (its rank, a running total, the previous row's value...).
--   function() OVER (PARTITION BY <groups> ORDER BY <order> <frame>)
--     PARTITION BY : restart the calculation for each group (optional)
--     ORDER BY     : the order inside each group
--     frame        : which rows count, e.g. ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- Window functions are evaluated AFTER WHERE / GROUP BY / HAVING, so they
-- cannot be used in WHERE. To filter on a rank, compute it in a CTE (or a
-- derived table) first and filter outside.
--
-- CTE (Common Table Expression): WITH name AS (SELECT ...) gives a
-- temporary, named result that exists only for that one statement. It
-- splits a long query into readable steps and can be referenced more than
-- once. A RECURSIVE CTE refers to itself, which lets SQL walk a tree of any
-- depth (category tree, referral chain).
--
-- Same definitions as file 09: UNITS / GROSS VALUE count orders that are
-- not CANCELLED; NET REVENUE = SUCCESS payments on non-cancelled orders.
-- Lines starting with "-- @query:" name the result saved to
-- outputs/12_window_functions_ctes.md.
-- =====================================================================

-- =====================================================================
-- A. RANKING PRODUCTS BY SALES PERFORMANCE
-- =====================================================================

-- ---------------------------------------------------------------------
-- W1. ROW_NUMBER vs RANK vs DENSE_RANK (with real ties)
-- Business question: rank every product by units sold.
-- On a tie (e.g. two products with 37 units):
--   ROW_NUMBER : always 1, 2, 3, ... (ties broken by product_id), unique
--   RANK       : ties share a rank, then a GAP  (1, 1, 3)
--   DENSE_RANK : ties share a rank, NO gap      (1, 1, 2)
-- The named WINDOW clause (w) avoids repeating the same OVER (...).
-- ---------------------------------------------------------------------
-- @query: W1 ROW_NUMBER vs RANK vs DENSE_RANK - products by units sold
WITH product_units AS (
    SELECT p.product_id,
           p.product_name,
           SUM(oi.quantity) AS units_sold
    FROM   order_items oi
    JOIN   orders   o ON o.order_id   = oi.order_id
    JOIN   products p ON p.product_id = oi.product_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY p.product_id, p.product_name
)
SELECT product_id,
       product_name,
       units_sold,
       ROW_NUMBER() OVER (ORDER BY units_sold DESC, product_id) AS row_num,
       RANK()       OVER w                                      AS rnk,
       DENSE_RANK() OVER w                                      AS dense_rnk
FROM   product_units
WINDOW w AS (ORDER BY units_sold DESC)
ORDER  BY units_sold DESC, product_id;

-- ---------------------------------------------------------------------
-- W2. RANK() with PARTITION BY category
-- Business question: how does each product rank INSIDE its own category,
-- by revenue and by units?
-- PARTITION BY restarts the ranking at 1 for every category.
-- ---------------------------------------------------------------------
-- @query: W2 RANK PARTITION BY category - product rank inside its category
SELECT cat.category_name,
       p.product_name,
       SUM(oi.quantity)                 AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS gross_value,
       RANK() OVER (PARTITION BY cat.category_id
                    ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS revenue_rank,
       RANK() OVER (PARTITION BY cat.category_id
                    ORDER BY SUM(oi.quantity) DESC)                 AS units_rank
FROM   order_items oi
JOIN   orders     o   ON o.order_id     = oi.order_id
JOIN   products   p   ON p.product_id   = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY cat.category_id, cat.category_name, p.product_id, p.product_name
ORDER  BY cat.category_name, revenue_rank;

-- ---------------------------------------------------------------------
-- W2b. Best-selling product per category with RANK() (compare with B3 in
-- file 09, which needed two derived tables)
-- Business question: the number-one product (by units) in each category,
-- keeping ties.
-- ---------------------------------------------------------------------
-- @query: W2b RANK = 1 - best seller per category (ties kept)
WITH ranked AS (
    SELECT cat.category_name,
           p.product_name,
           SUM(oi.quantity) AS units_sold,
           RANK() OVER (PARTITION BY cat.category_id
                        ORDER BY SUM(oi.quantity) DESC) AS rnk
    FROM   order_items oi
    JOIN   orders     o   ON o.order_id     = oi.order_id
    JOIN   products   p   ON p.product_id   = oi.product_id
    JOIN   categories cat ON cat.category_id = p.category_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT category_name, product_name, units_sold
FROM   ranked
WHERE  rnk = 1
ORDER  BY units_sold DESC, category_name;

-- ---------------------------------------------------------------------
-- W3. ROW_NUMBER() = 1 - exactly ONE winner per category
-- Business question: we can feature only one product per category on the
-- home page. On a tie in units, pick the one with more revenue.
-- ---------------------------------------------------------------------
-- @query: W3 ROW_NUMBER = 1 - one featured product per category
WITH ranked AS (
    SELECT cat.category_name,
           p.product_name,
           SUM(oi.quantity)                 AS units_sold,
           SUM(oi.quantity * oi.unit_price) AS gross_value,
           ROW_NUMBER() OVER (PARTITION BY cat.category_id
                              ORDER BY SUM(oi.quantity) DESC,
                                       SUM(oi.quantity * oi.unit_price) DESC,
                                       p.product_id) AS rn
    FROM   order_items oi
    JOIN   orders     o   ON o.order_id     = oi.order_id
    JOIN   products   p   ON p.product_id   = oi.product_id
    JOIN   categories cat ON cat.category_id = p.category_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT category_name, product_name, units_sold, gross_value
FROM   ranked
WHERE  rn = 1
ORDER  BY category_name;

-- =====================================================================
-- B. REVENUE TRENDS
-- =====================================================================

-- ---------------------------------------------------------------------
-- W4. Running total with SUM() OVER (ORDER BY ...)
-- Business question: how did total revenue build up month by month, and
-- what share of the year-to-date total had we reached each month?
-- ---------------------------------------------------------------------
-- @query: W4 SUM OVER ORDER BY - running total of revenue
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           SUM(pay.amount)                    AS revenue
    FROM   orders o
    JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month,
       revenue,
       SUM(revenue) OVER (ORDER BY month
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
       ROUND(100 * SUM(revenue) OVER (ORDER BY month
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                 / SUM(revenue) OVER (), 1)                                 AS pct_of_total
FROM   monthly
ORDER  BY month;

-- ---------------------------------------------------------------------
-- W5. Month-over-month change with LAG()
-- Business question: did revenue go up or down compared with the
-- previous month, and by how much?
-- LAG(x) returns x from the PREVIOUS row (NULL for the first month).
-- ---------------------------------------------------------------------
-- @query: W5 LAG - month-over-month revenue change
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           COUNT(*)                           AS paid_orders,
           SUM(pay.amount)                    AS revenue
    FROM   orders o
    JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month,
       paid_orders,
       revenue,
       LAG(revenue) OVER (ORDER BY month)             AS prev_month_revenue,
       revenue - LAG(revenue) OVER (ORDER BY month)   AS change_amount,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
                 / LAG(revenue) OVER (ORDER BY month), 1) AS change_pct
FROM   monthly
ORDER  BY month;

-- ---------------------------------------------------------------------
-- W6. Moving average with a window FRAME
-- Business question: what is the 3-month moving average of revenue (it
-- smooths out one-off spikes such as the Diwali sale)?
-- ---------------------------------------------------------------------
-- @query: W6 AVG OVER ROWS 2 PRECEDING - 3-month moving average
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           SUM(pay.amount)                    AS revenue
    FROM   orders o
    JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month,
       revenue,
       ROUND(AVG(revenue) OVER (ORDER BY month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM   monthly
ORDER  BY month;

-- =====================================================================
-- C. CUSTOMERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- W7. Customer segments with NTILE(4)
-- Business question: split paying customers into 4 equal groups by
-- lifetime value (Q1 = top 25%). Uses the view from file 10.
-- ---------------------------------------------------------------------
-- @query: W7 NTILE(4) - customer quartiles by lifetime value
SELECT customer_id,
       full_name,
       lifetime_value,
       NTILE(4) OVER (ORDER BY lifetime_value DESC, customer_id) AS quartile
FROM   vw_customer_lifetime_value
WHERE  lifetime_value > 0
ORDER  BY lifetime_value DESC, customer_id;

-- @query: W7b NTILE(4) - size and value of each quartile
WITH q AS (
    SELECT customer_id,
           lifetime_value,
           NTILE(4) OVER (ORDER BY lifetime_value DESC, customer_id) AS quartile
    FROM   vw_customer_lifetime_value
    WHERE  lifetime_value > 0
)
SELECT CONCAT('Q', quartile)              AS quartile,
       COUNT(*)                           AS customers,
       MIN(lifetime_value)                AS min_value,
       MAX(lifetime_value)                AS max_value,
       SUM(lifetime_value)                AS total_value,
       ROUND(100 * SUM(lifetime_value) / (SELECT SUM(lifetime_value) FROM q), 1) AS share_pct
FROM   q
GROUP  BY quartile
ORDER  BY quartile;

-- ---------------------------------------------------------------------
-- W8. LEAD() - days until the next order (repeat behaviour)
-- Business question: how many days do repeat customers usually wait
-- before ordering again? (When should the "come back" reminder go out?)
-- LEAD(x) returns x from the NEXT row in the partition.
-- ---------------------------------------------------------------------
-- @query: W8 LEAD - average gap between orders per repeat customer
WITH gaps AS (
    SELECT customer_id,
           order_date,
           DATEDIFF(LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date),
                    order_date) AS days_to_next_order
    FROM   orders
)
SELECT g.customer_id,
       c.full_name,
       COUNT(*) + 1                       AS orders_placed,
       ROUND(AVG(g.days_to_next_order), 1) AS avg_days_between_orders,
       MIN(g.days_to_next_order)          AS shortest_gap,
       MAX(g.days_to_next_order)          AS longest_gap
FROM   gaps g
JOIN   customers c ON c.customer_id = g.customer_id
WHERE  g.days_to_next_order IS NOT NULL
GROUP  BY g.customer_id, c.full_name
ORDER  BY avg_days_between_orders, g.customer_id;

-- ---------------------------------------------------------------------
-- W9. Share of total, PERCENT_RANK and CUME_DIST
-- Business question: what share of all sales does each product make, and
-- in which percentile does it sit? (Top 15 shown.)
-- SUM(...) OVER () with an empty window = the grand total on every row.
-- ---------------------------------------------------------------------
-- @query: W9 SUM OVER () and PERCENT_RANK - product share of sales (top 15)
WITH product_value AS (
    SELECT p.product_name,
           SUM(oi.quantity * oi.unit_price) AS gross_value
    FROM   order_items oi
    JOIN   orders   o ON o.order_id   = oi.order_id
    JOIN   products p ON p.product_id = oi.product_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY p.product_id, p.product_name
)
SELECT product_name,
       gross_value,
       ROUND(100 * gross_value / SUM(gross_value) OVER (), 2)           AS share_pct,
       ROUND(100 * SUM(gross_value) OVER (ORDER BY gross_value DESC
                                          ROWS UNBOUNDED PRECEDING)
                 / SUM(gross_value) OVER (), 1)                         AS cumulative_pct,
       -- (alias names avoid PERCENT_RANK / CUME_DIST, which are reserved words)
       ROUND(PERCENT_RANK() OVER (ORDER BY gross_value), 3)             AS pct_rank,
       ROUND(CUME_DIST()    OVER (ORDER BY gross_value), 3)             AS cumulative_dist
FROM   product_value
ORDER  BY gross_value DESC
LIMIT  15;

-- =====================================================================
-- D. CTEs FOR MULTI-STEP ANALYSIS
-- =====================================================================

-- ---------------------------------------------------------------------
-- T1. Multi-step CTE: top product of every month
-- Business question: which product sold the most units in each month?
--   step 1 (monthly_sales): units per product per month
--   step 2 (ranked)       : RANK() inside each month
--   step 3 (final SELECT) : keep rank 1
-- ---------------------------------------------------------------------
-- @query: T1 CTE + RANK - top product of each month
WITH monthly_sales AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           p.product_name,
           SUM(oi.quantity)                   AS units_sold,
           SUM(oi.quantity * oi.unit_price)   AS gross_value
    FROM   order_items oi
    JOIN   orders   o ON o.order_id   = oi.order_id
    JOIN   products p ON p.product_id = oi.product_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m'), p.product_id, p.product_name
),
ranked AS (
    SELECT month, product_name, units_sold, gross_value,
           RANK() OVER (PARTITION BY month ORDER BY units_sold DESC) AS rnk
    FROM   monthly_sales
)
SELECT month, product_name, units_sold, gross_value
FROM   ranked
WHERE  rnk = 1
ORDER  BY month, product_name;

-- ---------------------------------------------------------------------
-- T2. Multi-step CTE: customer cohorts
-- Business question: group customers by the month of their FIRST order;
-- how many of each group came back for another order?
-- ---------------------------------------------------------------------
-- @query: T2 CTE - cohorts by first-order month and how many came back
WITH first_orders AS (
    SELECT customer_id,
           MIN(order_date) AS first_order,
           COUNT(*)        AS total_orders
    FROM   orders
    GROUP  BY customer_id
),
cohorts AS (
    SELECT DATE_FORMAT(first_order, '%Y-%m') AS cohort_month,
           customer_id,
           total_orders
    FROM   first_orders
)
SELECT cohort_month,
       COUNT(*)                                     AS new_customers,
       SUM(total_orders > 1)                        AS came_back,
       ROUND(100 * SUM(total_orders > 1) / COUNT(*), 1) AS came_back_pct
FROM   cohorts
GROUP  BY cohort_month
ORDER  BY cohort_month;

-- ---------------------------------------------------------------------
-- T3. CTE used twice: months above the average month
-- Business question: the same as S14 in file 07, but the monthly totals
-- are written ONCE (in the CTE) and used twice, instead of repeating the
-- derived table.
-- ---------------------------------------------------------------------
-- @query: T3 CTE referenced twice - months above the average monthly revenue
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
           SUM(pay.amount)                    AS revenue
    FROM   orders o
    JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT month, revenue
FROM   monthly
WHERE  revenue > (SELECT AVG(revenue) FROM monthly)
ORDER  BY month;

-- =====================================================================
-- E. RECURSIVE CTEs
-- Structure:  WITH RECURSIVE name AS (
--                 anchor member      -- the starting rows
--                 UNION ALL
--                 recursive member   -- joins back to "name", one level deeper
--             )
-- MySQL stops when the recursive member returns no new rows. The
-- "level < 10" guard protects against a loop in bad data
-- (cte_max_recursion_depth = 1000 is the server's own safety net).
-- =====================================================================

-- ---------------------------------------------------------------------
-- R1. Recursive CTE: the full category tree
-- Business question: show every category with its level and full path,
-- for ANY depth (the self join in J8 needed one join per level).
-- ---------------------------------------------------------------------
-- @query: R1 WITH RECURSIVE - full category tree
WITH RECURSIVE category_tree AS (
    -- anchor: top-level categories
    SELECT category_id,
           category_name,
           parent_category_id,
           1                               AS level,
           CAST(category_name AS CHAR(255)) AS path
    FROM   categories
    WHERE  parent_category_id IS NULL
    UNION ALL
    -- recursive member: children of the rows found so far
    SELECT c.category_id,
           c.category_name,
           c.parent_category_id,
           t.level + 1,
           CONCAT(t.path, ' > ', c.category_name)
    FROM   categories c
    JOIN   category_tree t ON c.parent_category_id = t.category_id
    WHERE  t.level < 10
)
SELECT category_id,
       CONCAT(REPEAT('    ', level - 1), category_name) AS indented_name,
       level,
       path
FROM   category_tree
ORDER  BY path;

-- ---------------------------------------------------------------------
-- R2. Recursive CTE + roll-up
-- Business question: how much has each TOP-LEVEL category sold in total,
-- counting all of its sub-categories at every depth?
-- Each row carries its root (top-level) category down the tree.
-- ---------------------------------------------------------------------
-- @query: R2 WITH RECURSIVE - sales rolled up to each top-level category
WITH RECURSIVE branch AS (
    SELECT category_id   AS root_id,
           category_name AS root_name,
           category_id,
           1             AS level
    FROM   categories
    WHERE  parent_category_id IS NULL
    UNION ALL
    SELECT b.root_id, b.root_name, c.category_id, b.level + 1
    FROM   categories c
    JOIN   branch b ON c.parent_category_id = b.category_id
    WHERE  b.level < 10
),
category_sales AS (
    SELECT p.category_id,
           COUNT(DISTINCT p.product_id)     AS products_sold,
           SUM(oi.quantity)                 AS units_sold,
           SUM(oi.quantity * oi.unit_price) AS gross_value
    FROM   order_items oi
    JOIN   orders   o ON o.order_id   = oi.order_id
    JOIN   products p ON p.product_id = oi.product_id
    WHERE  o.status <> 'CANCELLED'
    GROUP  BY p.category_id
)
SELECT b.root_name                        AS top_level_category,
       COUNT(*) - 1                       AS sub_categories,
       COALESCE(SUM(s.products_sold), 0)  AS products_sold,
       COALESCE(SUM(s.units_sold), 0)     AS units_sold,
       COALESCE(SUM(s.gross_value), 0)    AS gross_value,
       RANK() OVER (ORDER BY COALESCE(SUM(s.gross_value), 0) DESC) AS revenue_rank
FROM   branch b
LEFT JOIN category_sales s ON s.category_id = b.category_id
GROUP  BY b.root_id, b.root_name
ORDER  BY revenue_rank;

-- ---------------------------------------------------------------------
-- R3. Recursive CTE: referral chains
-- Business question: who started each referral chain, and how far did it
-- spread (A referred B, B referred C, ...)?
-- ---------------------------------------------------------------------
-- @query: R3 WITH RECURSIVE - referral chains from their original referrer
WITH RECURSIVE referral_chain AS (
    -- anchor: customers who were not referred by anyone but referred someone
    SELECT c.customer_id,
           c.full_name                       AS chain_start,
           0                                 AS depth,
           CAST(c.full_name AS CHAR(500))    AS chain
    FROM   customers c
    WHERE  c.referred_by IS NULL
      AND  EXISTS (SELECT 1 FROM customers x WHERE x.referred_by = c.customer_id)
    UNION ALL
    SELECT c.customer_id,
           rc.chain_start,
           rc.depth + 1,
           CONCAT(rc.chain, ' -> ', c.full_name)
    FROM   customers c
    JOIN   referral_chain rc ON c.referred_by = rc.customer_id
    WHERE  rc.depth < 10
)
SELECT chain_start,
       depth AS referral_level,
       chain
FROM   referral_chain
WHERE  depth > 0
ORDER  BY depth DESC, chain;
