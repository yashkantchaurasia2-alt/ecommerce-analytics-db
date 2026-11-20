# Results of `sql/11_indexes.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## I0 indexes on orders BEFORE this file (PK and FK indexes only)

```sql
SELECT index_name, seq_in_index, column_name, non_unique
FROM   information_schema.statistics
WHERE  table_schema = DATABASE() AND table_name = 'orders'
ORDER  BY index_name, seq_in_index
```

**Rows returned:** 4

| INDEX_NAME | SEQ_IN_INDEX | COLUMN_NAME | NON_UNIQUE |
|---|---|---|---|
| fk_orders_address | 1 | shipping_address_id | 1 |
| fk_orders_address | 2 | customer_id | 1 |
| fk_orders_customer | 1 | customer_id | 1 |
| PRIMARY | 1 | order_id | 0 |

## X1 EXPLAIN BEFORE - pending payments (full table scan)

```sql
EXPLAIN SELECT payment_id, order_id, method, amount
FROM   payments
WHERE  status = 'PENDING'
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | payments | NULL | ALL | NULL | NULL | NULL | NULL | 312 | 10.0 | Using where |

## X1 EXPLAIN AFTER - pending payments (index lookup)

```sql
EXPLAIN SELECT payment_id, order_id, method, amount
FROM   payments
WHERE  status = 'PENDING'
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | payments | NULL | ref | idx_payments_status_method | idx_payments_status_method | 34 | const | 3 | 100.0 | NULL |

## X2 EXPLAIN BEFORE - orders in one week (full table scan)

```sql
EXPLAIN SELECT order_id, customer_id, order_date
FROM   orders
WHERE  order_date BETWEEN '2026-11-01' AND '2026-11-07 23:59:59'
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | orders | NULL | ALL | NULL | NULL | NULL | NULL | 283 | 11.11 | Using where |

## X2 EXPLAIN AFTER - orders in one week (index range scan)

```sql
EXPLAIN SELECT order_id, customer_id, order_date
FROM   orders
WHERE  order_date BETWEEN '2026-11-01' AND '2026-11-07 23:59:59'
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | orders | NULL | range | idx_orders_date | idx_orders_date | 5 | NULL | 13 | 100.0 | Using index condition |

## X3 EXPLAIN BEFORE - latest order of one customer (needs filesort)

```sql
EXPLAIN SELECT order_id, order_date, status
FROM   orders
WHERE  customer_id = 7
ORDER  BY order_date DESC
LIMIT  1
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | orders | NULL | ref | fk_orders_customer | fk_orders_customer | 4 | const | 5 | 100.0 | Using filesort |

## X3 EXPLAIN AFTER - latest order of one customer (no filesort)

```sql
EXPLAIN SELECT order_id, order_date, status
FROM   orders
WHERE  customer_id = 7
ORDER  BY order_date DESC
LIMIT  1
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | orders | NULL | ref | idx_orders_customer_date | idx_orders_customer_date | 4 | const | 5 | 100.0 | Backward index scan |

## X4 EXPLAIN - function on the column, index NOT used

```sql
EXPLAIN SELECT order_id, status
FROM   orders
WHERE  YEAR(order_date) = 2026 AND MONTH(order_date) = 11
```

**Rows returned:** 1

| id | select_type | table | partitions | type | possible_keys | key | key_len | ref | rows | filtered | Extra |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | SIMPLE | orders | NULL | ALL | NULL | NULL | NULL | NULL | 279 | 100.0 | Using where |

## I1 all indexes created in this file

```sql
SELECT table_name,
       index_name,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns_in_order
FROM   information_schema.statistics
WHERE  table_schema = DATABASE()
  AND  index_name LIKE 'idx\_%'
GROUP  BY table_name, index_name
ORDER  BY table_name, index_name
```

**Rows returned:** 5

| TABLE_NAME | INDEX_NAME | columns_in_order |
|---|---|---|
| deliveries | idx_deliveries_status | status |
| orders | idx_orders_customer_date | customer_id,order_date |
| orders | idx_orders_date | order_date |
| payments | idx_payments_status_method | status,method |
| products | idx_products_brand | brand |

## I2 number of indexes per table (more indexes = slower writes)

```sql
SELECT table_name,
       COUNT(DISTINCT index_name) AS indexes
FROM   information_schema.statistics
WHERE  table_schema = DATABASE()
  AND  table_name IN (SELECT table_name FROM information_schema.tables
                      WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE')
GROUP  BY table_name
ORDER  BY indexes DESC, table_name
```

**Rows returned:** 12

| TABLE_NAME | indexes |
|---|---|
| deliveries | 5 |
| customers | 4 |
| orders | 4 |
| payments | 4 |
| products | 4 |
| categories | 3 |
| customer_addresses | 3 |
| discounts | 2 |
| inventory | 2 |
| order_discounts | 2 |
| order_items | 2 |
| warehouses | 2 |
