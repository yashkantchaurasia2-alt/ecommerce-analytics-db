-- =====================================================================
-- 05_tcl_transactions.sql
-- Syllabus: SQL Fundamentals (TCL: START TRANSACTION, COMMIT, ROLLBACK,
--           SAVEPOINT, ROLLBACK TO SAVEPOINT, SET autocommit)
-- Business need: placing an order touches 5 tables (orders, order_items,
-- inventory, payments, deliveries). Either ALL of these changes happen or
-- NONE of them do (Atomicity, the "A" in ACID).
-- All scenarios ship from warehouse 3 (Bengaluru FC) unless noted.
-- =====================================================================

-- =====================================================================
-- CASE 1: successful order -> COMMIT
-- Customer 3 buys 1 x OnePlus Nord Buds 2 + 2 x Spigen phone case.
-- =====================================================================
-- @query: Case 1 - stock BEFORE the order
SELECT p.sku, i.warehouse_id, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku IN ('ONP-NB2', 'SPG-CASE') AND i.warehouse_id = 3
ORDER  BY p.sku;

START TRANSACTION;

-- step 1: create the order
INSERT INTO orders (customer_id, shipping_address_id, order_date, status)
SELECT 3, address_id, '2026-11-20 10:00:00', 'PLACED'
FROM   customer_addresses
WHERE  customer_id = 3 AND is_default = TRUE;

SET @case1_order = LAST_INSERT_ID();

-- step 2: add the items at today's price (price at purchase)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT @case1_order, product_id,
       CASE sku WHEN 'ONP-NB2' THEN 1 ELSE 2 END,
       price
FROM   products
WHERE  sku IN ('ONP-NB2', 'SPG-CASE');

-- step 3: reduce stock for every item of this order (set-based UPDATE)
UPDATE inventory i
JOIN   order_items oi ON oi.product_id = i.product_id
SET    i.quantity = i.quantity - oi.quantity
WHERE  oi.order_id = @case1_order
  AND  i.warehouse_id = 3;

-- step 4: record the successful payment (amount = items total)
INSERT INTO payments (order_id, method, status, amount, paid_at, transaction_ref)
SELECT @case1_order, 'CARD', 'SUCCESS', SUM(quantity * unit_price),
       '2026-11-20 10:01:00', 'CRDTCL0001'
FROM   order_items
WHERE  order_id = @case1_order;

-- step 5: create the delivery and confirm the order
INSERT INTO deliveries (order_id, warehouse_id, courier, status)
VALUES (@case1_order, 3, 'Blue Dart', 'PENDING');

UPDATE orders SET status = 'CONFIRMED' WHERE order_id = @case1_order;

COMMIT;

-- @query: Case 1 - stock AFTER COMMIT (Nord Buds -1, case -2)
SELECT p.sku, i.warehouse_id, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku IN ('ONP-NB2', 'SPG-CASE') AND i.warehouse_id = 3
ORDER  BY p.sku;

-- @query: Case 1 - the committed order
SELECT o.order_id, o.status, oi.product_id, oi.quantity, oi.unit_price,
       p.method, p.status AS payment_status, p.amount
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
JOIN   payments p     ON p.order_id  = o.order_id
WHERE  o.order_id = @case1_order;

-- =====================================================================
-- CASE 2: payment FAILED -> ROLLBACK
-- Customer 7 buys 3 x Atomic Habits. Order, item and stock change are
-- done, then the bank declines the card, so everything is undone.
-- Note: the AUTO_INCREMENT number used here is NOT given back, so the
-- order IDs will have a gap. That is normal and harmless.
-- =====================================================================
START TRANSACTION;

INSERT INTO orders (customer_id, order_date, status)
VALUES (7, '2026-11-20 10:15:00', 'PLACED');

SET @case2_order = LAST_INSERT_ID();

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT @case2_order, product_id, 3, price FROM products WHERE sku = 'BK-ATOMIC';

UPDATE inventory
SET    quantity = quantity - 3
WHERE  warehouse_id = 3
  AND  product_id = (SELECT product_id FROM products WHERE sku = 'BK-ATOMIC');

-- @query: Case 2 - stock INSIDE the transaction (already reduced by 3)
SELECT p.sku, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'BK-ATOMIC' AND i.warehouse_id = 3;

-- The payment gateway answers "FAILED", so the whole order is undone.
ROLLBACK;

-- @query: Case 2 - stock AFTER ROLLBACK (back to the original value)
SELECT p.sku, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'BK-ATOMIC' AND i.warehouse_id = 3;

-- @query: Case 2 - the rolled-back order does not exist
SELECT COUNT(*) AS orders_found
FROM   orders
WHERE  order_date = '2026-11-20 10:15:00';

-- =====================================================================
-- CASE 3: not enough stock -> ROLLBACK
-- Customer 12 wants 500 Redmi Note 13 Pro phones; Bengaluru has far fewer.
-- The stock check lives in the WHERE clause: "quantity >= 500" matches
-- no row, so ROW_COUNT() = 0 and the clerk rolls back.
-- =====================================================================
START TRANSACTION;

INSERT INTO orders (customer_id, order_date, status)
VALUES (12, '2026-11-20 10:30:00', 'PLACED');

SET @case3_order = LAST_INSERT_ID();

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT @case3_order, product_id, 500, price FROM products WHERE sku = 'RDM-N13P';

UPDATE inventory
SET    quantity = quantity - 500
WHERE  warehouse_id = 3
  AND  product_id = (SELECT product_id FROM products WHERE sku = 'RDM-N13P')
  AND  quantity >= 500;

-- @query: Case 3 - rows updated by the stock check (0 = not enough stock)
SELECT ROW_COUNT() AS rows_updated;

ROLLBACK;

-- @query: Case 3 - stock and orders after ROLLBACK (unchanged, no order)
SELECT p.sku, i.quantity,
       (SELECT COUNT(*) FROM orders WHERE order_date = '2026-11-20 10:30:00') AS orders_found
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'RDM-N13P' AND i.warehouse_id = 3;

-- =====================================================================
-- CASE 4: SAVEPOINT + ROLLBACK TO SAVEPOINT
-- Customer 12 orders JBL headphones and Sony XM5 headphones. The Sony is
-- out of stock, so only that part is undone; the JBL order is kept.
-- =====================================================================
START TRANSACTION;

INSERT INTO orders (customer_id, order_date, status)
VALUES (12, '2026-11-20 10:45:00', 'PLACED');

SET @case4_order = LAST_INSERT_ID();

-- item 1: JBL Tune 760NC (in stock)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT @case4_order, product_id, 1, price FROM products WHERE sku = 'JBL-760NC';

UPDATE inventory
SET    quantity = quantity - 1
WHERE  warehouse_id = 3
  AND  product_id = (SELECT product_id FROM products WHERE sku = 'JBL-760NC')
  AND  quantity >= 1;

SAVEPOINT after_item1;

-- item 2: Sony WH-1000XM5 (stock = 0 in Bengaluru)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT @case4_order, product_id, 1, price FROM products WHERE sku = 'SNY-XM5';

UPDATE inventory
SET    quantity = quantity - 1
WHERE  warehouse_id = 3
  AND  product_id = (SELECT product_id FROM products WHERE sku = 'SNY-XM5')
  AND  quantity >= 1;

-- @query: Case 4 - rows updated for Sony (0 = out of stock)
SELECT ROW_COUNT() AS rows_updated;

-- Undo only the Sony item; the order and the JBL item stay.
ROLLBACK TO SAVEPOINT after_item1;

INSERT INTO payments (order_id, method, status, amount, paid_at, transaction_ref)
SELECT @case4_order, 'NET_BANKING', 'SUCCESS', SUM(quantity * unit_price),
       '2026-11-20 10:46:00', 'NBTCL0004'
FROM   order_items
WHERE  order_id = @case4_order;

INSERT INTO deliveries (order_id, warehouse_id, courier, status)
VALUES (@case4_order, 3, 'Delhivery', 'PENDING');

UPDATE orders SET status = 'CONFIRMED' WHERE order_id = @case4_order;

COMMIT;

-- @query: Case 4 - committed order keeps only the JBL item
SELECT oi.order_id, p.sku, oi.quantity, oi.unit_price
FROM   order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE  oi.order_id = @case4_order;

-- =====================================================================
-- CASE 5: SET autocommit
-- autocommit = 1 (MySQL default): every statement is committed at once.
-- autocommit = 0: changes wait for COMMIT, and ROLLBACK can undo them.
-- =====================================================================
SET autocommit = 0;

UPDATE products SET price = price - 100 WHERE sku = 'PGN-KTL';

-- @query: Case 5 - kettle price after UPDATE with autocommit = 0 (not saved yet)
SELECT sku, price FROM products WHERE sku = 'PGN-KTL';

ROLLBACK;

-- @query: Case 5 - kettle price after ROLLBACK (original 699 is back)
SELECT sku, price FROM products WHERE sku = 'PGN-KTL';

SET autocommit = 1;

UPDATE warehouses SET city = 'Bengaluru Urban' WHERE warehouse_id = 3;

-- With autocommit = 1 the UPDATE above is already permanent,
-- so this ROLLBACK has nothing to undo.
ROLLBACK;

-- @query: Case 5 - with autocommit = 1, ROLLBACK did not undo the change
SELECT warehouse_id, city FROM warehouses WHERE warehouse_id = 3;

-- put the original value back
UPDATE warehouses SET city = 'Bengaluru' WHERE warehouse_id = 3;

-- =====================================================================
-- STORED PROCEDURE: sp_place_order
-- The cases above roll back "by hand". A real system decides by itself:
--   not enough stock      -> ROLLBACK
--   payment not SUCCESS   -> ROLLBACK
--   any SQL error         -> ROLLBACK (EXIT HANDLER)
--   otherwise             -> COMMIT
-- SELECT ... FOR UPDATE locks the stock row, so two clerks cannot sell
-- the same last unit at the same time (Isolation, the "I" in ACID).
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_place_order;

DELIMITER $$
CREATE PROCEDURE sp_place_order(
    IN  p_customer_id    INT,
    IN  p_sku            VARCHAR(20),
    IN  p_qty            INT,
    IN  p_warehouse_id   INT,
    IN  p_method         VARCHAR(12),
    IN  p_payment_status VARCHAR(8),
    OUT p_result         VARCHAR(100)
)
BEGIN
    DECLARE v_product_id INT;
    DECLARE v_price      DECIMAL(10,2);
    DECLARE v_stock      INT DEFAULT NULL;
    DECLARE v_order_id   INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ROLLED BACK: database error';
    END;

    SELECT product_id, price INTO v_product_id, v_price
    FROM   products WHERE sku = p_sku;

    START TRANSACTION;

    INSERT INTO orders (customer_id, order_date, status)
    VALUES (p_customer_id, '2026-11-20 12:00:00', 'PLACED');
    SET v_order_id = LAST_INSERT_ID();

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, v_product_id, p_qty, v_price);

    SELECT quantity INTO v_stock
    FROM   inventory
    WHERE  product_id = v_product_id AND warehouse_id = p_warehouse_id
    FOR UPDATE;

    IF v_stock IS NULL OR v_stock < p_qty THEN
        ROLLBACK;
        SET p_result = 'ROLLED BACK: insufficient stock';
    ELSE
        UPDATE inventory
        SET    quantity = quantity - p_qty
        WHERE  product_id = v_product_id AND warehouse_id = p_warehouse_id;

        INSERT INTO payments (order_id, method, status, amount, paid_at, transaction_ref)
        VALUES (v_order_id, p_method, p_payment_status, p_qty * v_price,
                '2026-11-20 12:01:00',
                IF(p_method = 'COD', NULL, CONCAT('SP', v_order_id)));

        IF p_payment_status <> 'SUCCESS' THEN
            ROLLBACK;
            SET p_result = CONCAT('ROLLED BACK: payment ', p_payment_status);
        ELSE
            INSERT INTO deliveries (order_id, warehouse_id, courier, status)
            VALUES (v_order_id, p_warehouse_id, 'Delhivery', 'PENDING');

            UPDATE orders SET status = 'CONFIRMED' WHERE order_id = v_order_id;

            COMMIT;
            SET p_result = CONCAT('COMMITTED order ', v_order_id);
        END IF;
    END IF;
END$$
DELIMITER ;

-- Call 1: enough stock, payment succeeds -> COMMIT
-- (2 x Pigeon kettle from Bhiwandi, warehouse 1)
CALL sp_place_order(3, 'PGN-KTL', 2, 1, 'UPI', 'SUCCESS', @call1);

-- Call 2: 1000 phones, not enough stock -> ROLLBACK
CALL sp_place_order(3, 'RDM-N13P', 1000, 3, 'CARD', 'SUCCESS', @call2);

-- Call 3: stock is fine, but the payment fails -> ROLLBACK
CALL sp_place_order(3, 'BK-ATOMIC', 1, 3, 'CARD', 'FAILED', @call3);

-- @query: sp_place_order results (only call 1 committed)
SELECT 'Call 1: 2 x kettle, UPI SUCCESS'   AS scenario, @call1 AS result
UNION ALL
SELECT 'Call 2: 1000 x Redmi, no stock',               @call2
UNION ALL
SELECT 'Call 3: 1 x Atomic Habits, payment FAILED',    @call3;

-- @query: Orders created at 12:00 by the procedure (only 1 survives)
SELECT o.order_id, o.status, oi.product_id, oi.quantity
FROM   orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date = '2026-11-20 12:00:00';
