# Results of `sql/05_tcl_transactions.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## Case 1 - stock BEFORE the order

```sql
SELECT p.sku, i.warehouse_id, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku IN ('ONP-NB2', 'SPG-CASE') AND i.warehouse_id = 3
ORDER  BY p.sku
```

**Rows returned:** 2

| sku | warehouse_id | quantity |
|---|---|---|
| ONP-NB2 | 3 | 83 |
| SPG-CASE | 3 | 100 |

## Case 1 - stock AFTER COMMIT (Nord Buds -1, case -2)

```sql
SELECT p.sku, i.warehouse_id, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku IN ('ONP-NB2', 'SPG-CASE') AND i.warehouse_id = 3
ORDER  BY p.sku
```

**Rows returned:** 2

| sku | warehouse_id | quantity |
|---|---|---|
| ONP-NB2 | 3 | 82 |
| SPG-CASE | 3 | 98 |

## Case 1 - the committed order

```sql
SELECT o.order_id, o.status, oi.product_id, oi.quantity, oi.unit_price,
       p.method, p.status AS payment_status, p.amount
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
JOIN   payments p     ON p.order_id  = o.order_id
WHERE  o.order_id = @case1_order
```

**Rows returned:** 2

| order_id | status | product_id | quantity | unit_price | method | payment_status | amount |
|---|---|---|---|---|---|---|---|
| 1277 | CONFIRMED | 6 | 2 | 899.00 | CARD | SUCCESS | 4097.00 |
| 1277 | CONFIRMED | 10 | 1 | 2299.00 | CARD | SUCCESS | 4097.00 |

## Case 2 - stock INSIDE the transaction (already reduced by 3)

```sql
SELECT p.sku, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'BK-ATOMIC' AND i.warehouse_id = 3
```

**Rows returned:** 1

| sku | quantity |
|---|---|
| BK-ATOMIC | 118 |

## Case 2 - stock AFTER ROLLBACK (back to the original value)

```sql
SELECT p.sku, i.quantity
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'BK-ATOMIC' AND i.warehouse_id = 3
```

**Rows returned:** 1

| sku | quantity |
|---|---|
| BK-ATOMIC | 121 |

## Case 2 - the rolled-back order does not exist

```sql
SELECT COUNT(*) AS orders_found
FROM   orders
WHERE  order_date = '2026-11-20 10:15:00'
```

**Rows returned:** 1

| orders_found |
|---|
| 0 |

## Case 3 - rows updated by the stock check (0 = not enough stock)

```sql
SELECT ROW_COUNT() AS rows_updated
```

**Rows returned:** 1

| rows_updated |
|---|
| 0 |

## Case 3 - stock and orders after ROLLBACK (unchanged, no order)

```sql
SELECT p.sku, i.quantity,
       (SELECT COUNT(*) FROM orders WHERE order_date = '2026-11-20 10:30:00') AS orders_found
FROM   inventory i JOIN products p ON p.product_id = i.product_id
WHERE  p.sku = 'RDM-N13P' AND i.warehouse_id = 3
```

**Rows returned:** 1

| sku | quantity | orders_found |
|---|---|---|
| RDM-N13P | 177 | 0 |

## Case 4 - rows updated for Sony (0 = out of stock)

```sql
SELECT ROW_COUNT() AS rows_updated
```

**Rows returned:** 1

| rows_updated |
|---|
| 0 |

## Case 4 - committed order keeps only the JBL item

```sql
SELECT oi.order_id, p.sku, oi.quantity, oi.unit_price
FROM   order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE  oi.order_id = @case4_order
```

**Rows returned:** 1

| order_id | sku | quantity | unit_price |
|---|---|---|---|
| 1280 | JBL-760NC | 1 | 5999.00 |

## Case 5 - kettle price after UPDATE with autocommit = 0 (not saved yet)

```sql
SELECT sku, price FROM products WHERE sku = 'PGN-KTL'
```

**Rows returned:** 1

| sku | price |
|---|---|
| PGN-KTL | 599.00 |

## Case 5 - kettle price after ROLLBACK (original 699 is back)

```sql
SELECT sku, price FROM products WHERE sku = 'PGN-KTL'
```

**Rows returned:** 1

| sku | price |
|---|---|
| PGN-KTL | 699.00 |

## Case 5 - with autocommit = 1, ROLLBACK did not undo the change

```sql
SELECT warehouse_id, city FROM warehouses WHERE warehouse_id = 3
```

**Rows returned:** 1

| warehouse_id | city |
|---|---|
| 3 | Bengaluru Urban |

## sp_place_order results (only call 1 committed)

```sql
SELECT 'Call 1: 2 x kettle, UPI SUCCESS'   AS scenario, @call1 AS result
UNION ALL
SELECT 'Call 2: 1000 x Redmi, no stock',               @call2
UNION ALL
SELECT 'Call 3: 1 x Atomic Habits, payment FAILED',    @call3
```

**Rows returned:** 3

| scenario | result |
|---|---|
| Call 1: 2 x kettle, UPI SUCCESS | COMMITTED order 1281 |
| Call 2: 1000 x Redmi, no stock | ROLLED BACK: insufficient stock |
| Call 3: 1 x Atomic Habits, payment FAILED | ROLLED BACK: payment FAILED |

## Orders created at 12:00 by the procedure (only 1 survives)

```sql
SELECT o.order_id, o.status, oi.product_id, oi.quantity
FROM   orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date = '2026-11-20 12:00:00'
```

**Rows returned:** 1

| order_id | status | product_id | quantity |
|---|---|---|---|
| 1281 | CONFIRMED | 33 | 2 |
