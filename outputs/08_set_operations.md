# Results of `sql/08_set_operations.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## U1 UNION - customers who paid by UPI or card

```sql
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
UNION
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id
```

**Rows returned:** 38

| customer_id |
|---|
| 1 |
| 2 |
| 3 |
| 4 |
| 5 |
| 7 |
| 8 |
| 9 |
| 10 |
| 11 |
| 12 |
| 13 |
| 15 |
| 16 |
| 18 |
| 19 |
| 20 |
| 21 |
| 22 |
| 23 |
| 25 |
| 26 |
| 27 |
| 28 |
| 29 |
| 31 |
| 32 |
| 33 |
| 34 |
| 35 |
| 36 |
| 38 |
| 39 |
| 40 |
| 41 |
| 43 |
| 44 |
| 46 |

## U2 UNION ALL - same list, duplicates kept

```sql
SELECT DISTINCT o.customer_id, 'UPI' AS method
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
UNION ALL
SELECT DISTINCT o.customer_id, 'CARD'
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id, method
```

**Rows returned:** 66 (showing first 60)

| customer_id | method |
|---|---|
| 1 | CARD |
| 1 | UPI |
| 2 | CARD |
| 2 | UPI |
| 3 | CARD |
| 3 | UPI |
| 4 | UPI |
| 5 | CARD |
| 5 | UPI |
| 7 | CARD |
| 7 | UPI |
| 8 | UPI |
| 9 | CARD |
| 9 | UPI |
| 10 | CARD |
| 11 | CARD |
| 11 | UPI |
| 12 | CARD |
| 12 | UPI |
| 13 | CARD |
| 13 | UPI |
| 15 | CARD |
| 15 | UPI |
| 16 | UPI |
| 18 | CARD |
| 18 | UPI |
| 19 | CARD |
| 19 | UPI |
| 20 | UPI |
| 21 | CARD |
| 21 | UPI |
| 22 | CARD |
| 22 | UPI |
| 23 | CARD |
| 23 | UPI |
| 25 | CARD |
| 25 | UPI |
| 26 | CARD |
| 26 | UPI |
| 27 | CARD |
| 27 | UPI |
| 28 | CARD |
| 28 | UPI |
| 29 | CARD |
| 29 | UPI |
| 31 | UPI |
| 32 | CARD |
| 32 | UPI |
| 33 | CARD |
| 33 | UPI |
| 34 | CARD |
| 34 | UPI |
| 35 | CARD |
| 35 | UPI |
| 36 | UPI |
| 38 | CARD |
| 39 | CARD |
| 39 | UPI |
| 40 | UPI |
| 41 | CARD |

## U3 UNION vs UNION ALL - row counts

```sql
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
       WHERE  p.method = 'CARD' AND p.status = 'SUCCESS') AS ua
```

**Rows returned:** 2

| version | row_count |
|---|---|
| UNION (duplicates removed) | 38 |
| UNION ALL (duplicates kept) | 66 |

## U4 UNION - every city with a customer or a warehouse

```sql
SELECT city FROM customer_addresses WHERE is_default = TRUE
UNION
SELECT city FROM warehouses
ORDER  BY city
```

**Rows returned:** 15

| city |
|---|
| Ahmedabad |
| Bengaluru |
| Chandigarh |
| Chennai |
| Delhi |
| Gurugram |
| Hyderabad |
| Indore |
| Jaipur |
| Kochi |
| Kolkata |
| Lucknow |
| Mumbai |
| Patna |
| Pune |

## I1 INTERSECT - customers who paid by both UPI and card

```sql
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI'  AND p.status = 'SUCCESS'
INTERSECT
SELECT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'CARD' AND p.status = 'SUCCESS'
ORDER  BY customer_id
```

**Rows returned:** 28

| customer_id |
|---|
| 1 |
| 2 |
| 3 |
| 5 |
| 7 |
| 9 |
| 11 |
| 12 |
| 13 |
| 15 |
| 18 |
| 19 |
| 21 |
| 22 |
| 23 |
| 25 |
| 26 |
| 27 |
| 28 |
| 29 |
| 32 |
| 33 |
| 34 |
| 35 |
| 39 |
| 41 |
| 43 |
| 44 |

## I1b INTERSECT equivalent with IN - same customers as I1

```sql
SELECT DISTINCT o.customer_id
FROM   orders o JOIN payments p ON p.order_id = o.order_id
WHERE  p.method = 'UPI' AND p.status = 'SUCCESS'
  AND  o.customer_id IN (SELECT o2.customer_id
                         FROM   orders o2 JOIN payments p2 ON p2.order_id = o2.order_id
                         WHERE  p2.method = 'CARD' AND p2.status = 'SUCCESS')
ORDER  BY customer_id
```

**Rows returned:** 28

| customer_id |
|---|
| 1 |
| 2 |
| 3 |
| 5 |
| 7 |
| 9 |
| 11 |
| 12 |
| 13 |
| 15 |
| 18 |
| 19 |
| 21 |
| 22 |
| 23 |
| 25 |
| 26 |
| 27 |
| 28 |
| 29 |
| 32 |
| 33 |
| 34 |
| 35 |
| 39 |
| 41 |
| 43 |
| 44 |

## I2 INTERSECT - products sold in both October and November

```sql
SELECT oi.product_id
FROM   order_items oi JOIN orders o ON o.order_id = oi.order_id
WHERE  o.order_date >= '2026-10-01' AND o.order_date < '2026-11-01'
INTERSECT
SELECT oi.product_id
FROM   order_items oi JOIN orders o ON o.order_id = oi.order_id
WHERE  o.order_date >= '2026-11-01' AND o.order_date < '2026-12-01'
ORDER  BY product_id
```

**Rows returned:** 21

| product_id |
|---|
| 2 |
| 3 |
| 6 |
| 8 |
| 9 |
| 10 |
| 13 |
| 16 |
| 19 |
| 20 |
| 22 |
| 23 |
| 25 |
| 29 |
| 31 |
| 33 |
| 36 |
| 37 |
| 38 |
| 39 |
| 40 |

## E1 EXCEPT - customers who ordered but never used a coupon

```sql
SELECT customer_id
FROM   orders
EXCEPT
SELECT o.customer_id
FROM   orders o JOIN order_discounts od ON od.order_id = o.order_id
ORDER  BY customer_id
```

**Rows returned:** 12

| customer_id |
|---|
| 4 |
| 5 |
| 8 |
| 16 |
| 18 |
| 28 |
| 35 |
| 36 |
| 38 |
| 42 |
| 43 |
| 45 |

## E1b MINUS equivalent with NOT EXISTS - same customers as E1

```sql
SELECT DISTINCT o.customer_id
FROM   orders o
WHERE  NOT EXISTS (SELECT 1
                   FROM   orders o2 JOIN order_discounts od ON od.order_id = o2.order_id
                   WHERE  o2.customer_id = o.customer_id)
ORDER  BY customer_id
```

**Rows returned:** 12

| customer_id |
|---|
| 4 |
| 5 |
| 8 |
| 16 |
| 18 |
| 28 |
| 35 |
| 36 |
| 38 |
| 42 |
| 43 |
| 45 |

## E1c MINUS equivalent with LEFT JOIN IS NULL - same customers as E1

```sql
SELECT DISTINCT o.customer_id
FROM   orders o
LEFT JOIN (SELECT DISTINCT o2.customer_id
           FROM   orders o2 JOIN order_discounts od ON od.order_id = o2.order_id) AS used
       ON used.customer_id = o.customer_id
WHERE  used.customer_id IS NULL
ORDER  BY customer_id
```

**Rows returned:** 12

| customer_id |
|---|
| 4 |
| 5 |
| 8 |
| 16 |
| 18 |
| 28 |
| 35 |
| 36 |
| 38 |
| 42 |
| 43 |
| 45 |

## E2 EXCEPT - catalogue minus sold products

```sql
SELECT product_id, sku FROM products
EXCEPT
SELECT p.product_id, p.sku
FROM   products p JOIN order_items oi ON oi.product_id = p.product_id
ORDER  BY product_id
```

**Rows returned:** 2

| product_id | sku |
|---|---|
| 17 | APL-MBA-M3 |
| 35 | AJT-CLK |
