-- =====================================================================
-- 11_indexes.sql
-- Syllabus: Views and Indexing (indexes, EXPLAIN before and after)
--
-- An INDEX is a sorted lookup structure (a B+ tree in InnoDB) on one or
-- more columns, like the index at the back of a book: instead of reading
-- every page (a FULL TABLE SCAN), MySQL jumps straight to the matching
-- rows.
--
-- How to read EXPLAIN (the columns that matter):
--   type  : ALL   = full table scan (slowest)
--           range = index range scan (e.g. BETWEEN dates)
--           ref   = index lookup on a value
--           const = at most one row, via primary/unique key (fastest)
--   key   : the index actually used (NULL = none)
--   rows  : how many rows MySQL expects to read
--   Extra : "Using filesort" = an extra sort step was needed
--
-- TRADE-OFF: indexes make reads (SELECT, JOIN, ORDER BY) faster, but every
-- INSERT / UPDATE / DELETE must also update every index on the table, and
-- each index uses disk space. So we index only columns that are used
-- often in WHERE, JOIN or ORDER BY, not every column.
--
-- Foreign-key columns already have an index: InnoDB creates one
-- automatically for every FOREIGN KEY (e.g. order_items.product_id), so
-- we do not create duplicates of those (see I0 below).
--
-- Lines starting with "-- @query:" name the result saved to
-- outputs/11_indexes.md.
-- =====================================================================

-- ---------------------------------------------------------------------
-- I0. Indexes that already exist on orders (PRIMARY + FK indexes)
-- ---------------------------------------------------------------------
-- Indexing (existing indexes) | Business question: which indexes did MySQL already create for the PK and FKs?
-- @query: I0 indexes on orders BEFORE this file (PK and FK indexes only)
SELECT index_name, seq_in_index, column_name, non_unique
FROM   information_schema.statistics
WHERE  table_schema = DATABASE() AND table_name = 'orders'
ORDER  BY index_name, seq_in_index;

-- =====================================================================
-- DEMO 1: payments(status, method)
-- Business question: find all PENDING payments (support checks these
-- every hour). status has no index yet.
-- =====================================================================
-- @query: X1 EXPLAIN BEFORE - pending payments (full table scan)
EXPLAIN SELECT payment_id, order_id, method, amount
FROM   payments
WHERE  status = 'PENDING';

CREATE INDEX idx_payments_status_method ON payments (status, method);
ANALYZE TABLE payments;

-- Indexing (EXPLAIN after) | Business question: does the pending-payments query use the new index?
-- @query: X1 EXPLAIN AFTER - pending payments (index lookup)
EXPLAIN SELECT payment_id, order_id, method, amount
FROM   payments
WHERE  status = 'PENDING';
-- What changed: type went from ALL to ref, key is now
-- idx_payments_status_method, and rows dropped from every payment to just
-- the few pending ones. Because the index starts with status, it also
-- helps "WHERE status = ... AND method = ..." (leftmost-prefix rule), but
-- NOT a query on method alone.

-- =====================================================================
-- DEMO 2: orders(order_date)
-- Business question: which orders were placed in the first week of
-- November? (Date-range reports run every day.)
-- =====================================================================
-- @query: X2 EXPLAIN BEFORE - orders in one week (full table scan)
EXPLAIN SELECT order_id, customer_id, order_date
FROM   orders
WHERE  order_date BETWEEN '2026-11-01' AND '2026-11-07 23:59:59';

CREATE INDEX idx_orders_date ON orders (order_date);
ANALYZE TABLE orders;

-- Indexing (EXPLAIN after) | Business question: does the date-range query use the new index?
-- @query: X2 EXPLAIN AFTER - orders in one week (index range scan)
EXPLAIN SELECT order_id, customer_id, order_date
FROM   orders
WHERE  order_date BETWEEN '2026-11-01' AND '2026-11-07 23:59:59';
-- What changed: type went from ALL to range. MySQL walks the sorted index
-- from 1 Nov to 7 Nov and reads only those orders.

-- =====================================================================
-- DEMO 3: composite index orders(customer_id, order_date)
-- Business question: what is customer 7's latest order? (The "my orders"
-- page.) The FK index on customer_id finds the customer's orders, but they
-- then have to be SORTED by date: "Using filesort".
-- =====================================================================
-- @query: X3 EXPLAIN BEFORE - latest order of one customer (needs filesort)
EXPLAIN SELECT order_id, order_date, status
FROM   orders
WHERE  customer_id = 7
ORDER  BY order_date DESC
LIMIT  1;

CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
ANALYZE TABLE orders;

-- Indexing (EXPLAIN after) | Business question: does the composite index remove the sort step?
-- @query: X3 EXPLAIN AFTER - latest order of one customer (no filesort)
EXPLAIN SELECT order_id, order_date, status
FROM   orders
WHERE  customer_id = 7
ORDER  BY order_date DESC
LIMIT  1;
-- What changed: inside the composite index, each customer's orders are
-- already stored in date order, so MySQL reads the last entry backwards
-- and stops. The filesort step is gone ("Backward index scan").

-- =====================================================================
-- DEMO 4: when an index CANNOT be used
-- Business question: same "November" question, written with functions.
-- Wrapping the column in a function (YEAR(), MONTH()) hides it from the
-- index, so MySQL falls back to a full scan even though idx_orders_date
-- exists. Write ranges on the bare column instead (as in DEMO 2).
-- =====================================================================
-- (status is selected on purpose: if only indexed columns were selected,
--  MySQL might scan the whole index instead, shown as type = index, which
--  still reads every entry.)
-- @query: X4 EXPLAIN - function on the column, index NOT used
EXPLAIN SELECT order_id, status
FROM   orders
WHERE  YEAR(order_date) = 2026 AND MONTH(order_date) = 11;

-- =====================================================================
-- More indexes for columns used in WHERE / JOIN / ORDER BY elsewhere
-- =====================================================================
-- vw_pending_deliveries and C6/C7 filter deliveries by status
CREATE INDEX idx_deliveries_status ON deliveries (status);

-- 03_dml_operations.sql and brand reports filter products by brand
CREATE INDEX idx_products_brand ON products (brand);

-- Indexing (catalog) | Business question: which indexes did this file add, on which columns?
-- @query: I1 all indexes created in this file
SELECT table_name,
       index_name,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns_in_order
FROM   information_schema.statistics
WHERE  table_schema = DATABASE()
  AND  index_name LIKE 'idx\_%'
GROUP  BY table_name, index_name
ORDER  BY table_name, index_name;

-- Indexing (trade-off) | Business question: which tables pay the highest write cost for their indexes?
-- @query: I2 number of indexes per table (more indexes = slower writes)
SELECT table_name,
       COUNT(DISTINCT index_name) AS indexes
FROM   information_schema.statistics
WHERE  table_schema = DATABASE()
  AND  table_name IN (SELECT table_name FROM information_schema.tables
                      WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE')
GROUP  BY table_name
ORDER  BY indexes DESC, table_name;
