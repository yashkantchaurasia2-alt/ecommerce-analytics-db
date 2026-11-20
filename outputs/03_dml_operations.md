# Results of `sql/03_dml_operations.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## Premium products above Rs 10,000

```sql
SELECT product_id,
       product_name,
       brand,
       price,
       mrp,
       ROUND((mrp - price) / mrp * 100, 1) AS pct_off
FROM   products
WHERE  price > 10000
ORDER  BY price DESC
```

**Rows returned:** 11

| product_id | product_name | brand | price | mrp | pct_off |
|---|---|---|---|---|---|
| 17 | Apple MacBook Air M3 13-inch | Apple | 114900.00 | 114900.00 | 0.0 |
| 1 | Samsung Galaxy S24 (8GB/256GB) | Samsung | 74999.00 | 79999.00 | 6.3 |
| 2 | Apple iPhone 15 (128GB) | Apple | 69999.00 | 79900.00 | 12.4 |
| 15 | HP Pavilion 15 Laptop (i5) | HP | 62990.00 | 72990.00 | 13.7 |
| 16 | Lenovo IdeaPad Slim 3 (Ryzen 5) | Lenovo | 45990.00 | 57990.00 | 20.7 |
| 3 | OnePlus 12R (8GB/128GB) | OnePlus | 39999.00 | 42999.00 | 7.0 |
| 18 | ASUS Vivobook 15 (i3) | ASUS | 38990.00 | 49990.00 | 22.0 |
| 12 | Sony WH-1000XM5 Headphones | Sony | 29990.00 | 34990.00 | 14.3 |
| 11 | Apple AirPods Pro (2nd Gen) | Apple | 24900.00 | 26900.00 | 7.4 |
| 4 | Redmi Note 13 Pro 5G | Xiaomi | 23999.00 | 26999.00 | 11.1 |
| 21 | HP M24f 24-inch FHD Monitor | HP | 10499.00 | 14999.00 | 30.0 |

## Customers per city

```sql
SELECT city,
       state,
       COUNT(*) AS customers
FROM   customer_addresses
WHERE  is_default = TRUE
GROUP  BY city, state
ORDER  BY customers DESC, city
```

**Rows returned:** 14

| city | state | customers |
|---|---|---|
| Bengaluru | Karnataka | 9 |
| Kochi | Kerala | 8 |
| Ahmedabad | Gujarat | 4 |
| Chandigarh | Chandigarh | 4 |
| Jaipur | Rajasthan | 4 |
| Patna | Bihar | 4 |
| Chennai | Tamil Nadu | 3 |
| Indore | Madhya Pradesh | 3 |
| Mumbai | Maharashtra | 3 |
| Kolkata | West Bengal | 2 |
| Lucknow | Uttar Pradesh | 2 |
| Pune | Maharashtra | 2 |
| Delhi | Delhi | 1 |
| Hyderabad | Telangana | 1 |

## Categories with 3 or more products

```sql
SELECT category_id,
       COUNT(*)             AS products,
       ROUND(AVG(price), 2) AS avg_price,
       MIN(price)           AS cheapest,
       MAX(price)           AS costliest
FROM   products
GROUP  BY category_id
HAVING COUNT(*) >= 3
ORDER  BY products DESC, category_id
```

**Rows returned:** 11

| category_id | products | avg_price | cheapest | costliest |
|---|---|---|---|---|
| 3 | 4 | 52249.00 | 23999.00 | 74999.00 |
| 4 | 4 | 1017.75 | 299.00 | 1574.00 |
| 9 | 4 | 65717.50 | 38990.00 | 114900.00 |
| 19 | 4 | 2999.00 | 699.00 | 5499.00 |
| 6 | 3 | 9521.00 | 1364.00 | 24900.00 |
| 7 | 3 | 12521.00 | 1574.00 | 29990.00 |
| 10 | 3 | 6797.67 | 899.00 | 10499.00 |
| 13 | 3 | 715.67 | 449.00 | 899.00 |
| 15 | 3 | 1332.33 | 1099.00 | 1599.00 |
| 17 | 3 | 2664.33 | 1299.00 | 3695.00 |
| 23 | 3 | 315.67 | 249.00 | 399.00 |

## Orders by status

```sql
SELECT status,
       COUNT(*) AS orders
FROM   orders
GROUP  BY status
ORDER  BY orders DESC
```

**Rows returned:** 5

| status | orders |
|---|---|
| DELIVERED | 243 |
| CANCELLED | 22 |
| SHIPPED | 5 |
| CONFIRMED | 3 |
| PLACED | 3 |

## Payment attempts by method and status (more than 5)

```sql
SELECT method,
       status,
       COUNT(*)    AS attempts,
       SUM(amount) AS total_amount
FROM   payments
GROUP  BY method, status
HAVING COUNT(*) > 5
ORDER  BY method, attempts DESC
```

**Rows returned:** 7

| method | status | attempts | total_amount |
|---|---|---|---|
| CARD | SUCCESS | 63 | 715426.95 |
| CARD | FAILED | 16 | 148177.60 |
| COD | SUCCESS | 45 | 503158.85 |
| NET_BANKING | SUCCESS | 42 | 694784.85 |
| NET_BANKING | FAILED | 10 | 281898.70 |
| UPI | SUCCESS | 107 | 868710.20 |
| UPI | FAILED | 22 | 64125.75 |

## Stock below reorder level

```sql
SELECT product_id,
       warehouse_id,
       quantity,
       reorder_level
FROM   inventory
WHERE  quantity < reorder_level
ORDER  BY quantity, product_id
```

**Rows returned:** 10

| product_id | warehouse_id | quantity | reorder_level |
|---|---|---|---|
| 12 | 2 | 0 | 10 |
| 12 | 3 | 0 | 10 |
| 13 | 2 | 0 | 10 |
| 37 | 3 | 2 | 20 |
| 11 | 3 | 3 | 10 |
| 17 | 3 | 7 | 10 |
| 22 | 2 | 7 | 20 |
| 32 | 3 | 15 | 20 |
| 31 | 3 | 18 | 20 |
| 30 | 3 | 19 | 20 |

## Diwali-week orders by customers named A...

```sql
SELECT o.order_id,
       o.order_date,
       c.full_name,
       o.status
FROM   orders o, customers c
WHERE  o.customer_id = c.customer_id
  AND  o.order_date BETWEEN '2026-10-25' AND '2026-11-01 23:59:59'
  AND  c.full_name LIKE 'A%'
ORDER  BY o.order_date
```

**Rows returned:** 4

| order_id | order_date | full_name | status |
|---|---|---|---|
| 1244 | 2026-10-29 20:54:04 | Alok Tripathi | DELIVERED |
| 1245 | 2026-10-30 11:13:19 | Ananya Iyer | DELIVERED |
| 1248 | 2026-10-31 18:03:27 | Anjali Tiwari | DELIVERED |
| 1250 | 2026-11-01 17:44:05 | Aditya Verma | DELIVERED |
