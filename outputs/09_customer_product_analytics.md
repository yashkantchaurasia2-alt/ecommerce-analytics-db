# Results of `sql/09_customer_product_analytics.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## A1 Repeat customers (more than 1 order)

```sql
SELECT c.customer_id,
       c.full_name,
       COUNT(DISTINCT o.order_id)          AS orders_placed,
       DATE(MIN(o.order_date))             AS first_order,
       DATE(MAX(o.order_date))             AS last_order,
       COALESCE(SUM(pay.amount), 0)        AS net_spend
FROM   customers c
JOIN   orders o ON o.customer_id = c.customer_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
                      AND pay.status   = 'SUCCESS'
                      AND o.status    <> 'CANCELLED'
GROUP  BY c.customer_id, c.full_name
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER  BY orders_placed DESC, net_spend DESC
```

**Rows returned:** 34

| customer_id | full_name | orders_placed | first_order | last_order | net_spend |
|---|---|---|---|---|---|
| 3 | Isha Gupta | 17 | 2026-05-02 | 2026-11-20 | 145357.00 |
| 32 | Aditya Verma | 16 | 2026-05-15 | 2026-11-16 | 266380.90 |
| 44 | Pranav Hegde | 16 | 2026-08-02 | 2026-10-11 | 169193.20 |
| 39 | Yash Saxena | 15 | 2026-06-03 | 2026-11-04 | 175082.05 |
| 12 | Varun Kapoor | 13 | 2026-05-16 | 2026-11-20 | 121792.95 |
| 9 | Bhavna Rathore | 13 | 2026-05-04 | 2026-11-09 | 114214.30 |
| 15 | Pooja Desai | 12 | 2026-05-29 | 2026-11-14 | 126581.40 |
| 43 | Fatima Sheikh | 12 | 2026-07-22 | 2026-10-20 | 13685.00 |
| 41 | Anjali Tiwari | 9 | 2026-07-08 | 2026-11-10 | 72657.50 |
| 26 | Ananya Iyer | 8 | 2026-05-09 | 2026-10-30 | 292528.30 |
| 1 | Aarav Sharma | 8 | 2026-05-05 | 2026-10-15 | 167434.60 |
| 11 | Arjun Reddy | 8 | 2026-06-25 | 2026-11-07 | 141201.00 |
| 31 | Kritika Sood | 8 | 2026-06-25 | 2026-11-09 | 82436.00 |
| 19 | Imran Qureshi | 8 | 2026-05-28 | 2026-11-19 | 62631.50 |
| 25 | Kunal Bose | 8 | 2026-05-17 | 2026-11-11 | 52279.25 |
| 2 | Rohan Mehta | 8 | 2026-05-30 | 2026-11-09 | 18250.20 |
| 27 | Tanvi Shah | 7 | 2026-05-03 | 2026-10-21 | 161605.10 |
| 33 | Siddharth Rao | 7 | 2026-05-24 | 2026-09-21 | 69655.30 |
| 18 | Payal Ghosh | 7 | 2026-05-06 | 2026-10-29 | 53871.00 |
| 34 | Priya Nair | 7 | 2026-05-01 | 2026-10-10 | 22830.00 |
| 29 | Manish Yadav | 7 | 2026-05-11 | 2026-11-11 | 12635.10 |
| 21 | Vikram Singh | 6 | 2026-07-13 | 2026-10-31 | 13557.50 |
| 46 | Aditi Bhatt | 5 | 2026-08-18 | 2026-11-17 | 113910.20 |
| 7 | Karan Malhotra | 5 | 2026-07-20 | 2026-10-26 | 48563.10 |
| 22 | Meera Pillai | 5 | 2026-05-03 | 2026-06-10 | 24483.00 |
| 13 | Harsh Agarwal | 5 | 2026-06-06 | 2026-11-08 | 11599.00 |
| 16 | Shreya Das | 5 | 2026-07-31 | 2026-11-17 | 10090.00 |
| 35 | Tushar Naidu | 4 | 2026-05-09 | 2026-09-13 | 32846.00 |
| 28 | Sakshi Mittal | 4 | 2026-06-21 | 2026-10-14 | 15486.00 |
| 14 | Saurabh Dubey | 4 | 2026-08-02 | 2026-10-10 | 10132.30 |
| 8 | Nikhil Jain | 3 | 2026-05-26 | 2026-10-01 | 54594.00 |
| 5 | Sneha Patil | 3 | 2026-07-10 | 2026-11-06 | 49887.00 |
| 20 | Sam Fernandes | 3 | 2026-05-14 | 2026-09-20 | 13029.30 |
| 23 | Neha Kulkarni | 3 | 2026-05-19 | 2026-07-17 | 8458.10 |

## A2 Repeat purchase rate

```sql
SELECT COUNT(*)                                  AS ordering_customers,
       SUM(order_count > 1)                      AS repeat_customers,
       SUM(order_count = 1)                      AS one_time_customers,
       ROUND(100 * SUM(order_count > 1) / COUNT(*), 1) AS repeat_rate_pct
FROM  (SELECT customer_id, COUNT(*) AS order_count
       FROM   orders
       GROUP  BY customer_id) AS per_customer
```

**Rows returned:** 1

| ordering_customers | repeat_customers | one_time_customers | repeat_rate_pct |
|---|---|---|---|
| 44 | 34 | 10 | 77.3 |

## A3 Top 10 customers by net spend

```sql
SELECT c.customer_id,
       c.full_name,
       a.city,
       COUNT(*)                  AS paid_orders,
       SUM(pay.amount)           AS net_spend,
       ROUND(AVG(pay.amount), 2) AS avg_order_value
FROM   customers c
JOIN   orders   o   ON o.customer_id  = c.customer_id
JOIN   payments pay ON pay.order_id   = o.order_id AND pay.status = 'SUCCESS'
LEFT JOIN customer_addresses a ON a.customer_id = c.customer_id AND a.is_default = TRUE
WHERE  o.status <> 'CANCELLED'
GROUP  BY c.customer_id, c.full_name, a.city
ORDER  BY net_spend DESC
LIMIT  10
```

**Rows returned:** 10

| customer_id | full_name | city | paid_orders | net_spend | avg_order_value |
|---|---|---|---|---|---|
| 26 | Ananya Iyer | Chennai | 8 | 292528.30 | 36566.04 |
| 32 | Aditya Verma | Pune | 15 | 266380.90 | 17758.73 |
| 39 | Yash Saxena | Mumbai | 15 | 175082.05 | 11672.14 |
| 44 | Pranav Hegde | Jaipur | 14 | 169193.20 | 12085.23 |
| 1 | Aarav Sharma | Chandigarh | 6 | 167434.60 | 27905.77 |
| 27 | Tanvi Shah | Chandigarh | 7 | 161605.10 | 23086.44 |
| 3 | Isha Gupta | Patna | 14 | 145357.00 | 10382.64 |
| 11 | Arjun Reddy | Kolkata | 8 | 141201.00 | 17650.13 |
| 15 | Pooja Desai | Lucknow | 11 | 126581.40 | 11507.40 |
| 12 | Varun Kapoor | Mumbai | 13 | 121792.95 | 9368.69 |

## A4 Referred vs direct customers

```sql
SELECT source,
       COUNT(*)                 AS customers,
       ROUND(AVG(orders), 2)    AS avg_orders,
       ROUND(AVG(spend), 2)     AS avg_net_spend,
       SUM(orders = 0)          AS never_ordered
FROM  (SELECT c.customer_id,
              IF(c.referred_by IS NULL, 'Direct', 'Referred') AS source,
              (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS orders,
              (SELECT COALESCE(SUM(p.amount), 0)
               FROM   payments p JOIN orders o ON o.order_id = p.order_id
               WHERE  o.customer_id = c.customer_id
                 AND  p.status = 'SUCCESS' AND o.status <> 'CANCELLED') AS spend
       FROM   customers c) AS per_customer
GROUP  BY source
ORDER  BY source
```

**Rows returned:** 2

| source | customers | avg_orders | avg_net_spend | never_ordered |
|---|---|---|---|---|
| Direct | 35 | 5.49 | 53600.45 | 4 |
| Referred | 15 | 5.80 | 58887.15 | 2 |

## B1 Best-selling products by quantity (top 10)

```sql
SELECT p.product_id,
       p.product_name,
       cat.category_name,
       SUM(oi.quantity)                  AS units_sold,
       COUNT(DISTINCT oi.order_id)       AS orders,
       SUM(oi.quantity * oi.unit_price)  AS gross_value
FROM   order_items oi
JOIN   orders     o   ON o.order_id     = oi.order_id
JOIN   products   p   ON p.product_id   = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY p.product_id, p.product_name, cat.category_name
ORDER  BY units_sold DESC, gross_value DESC
LIMIT  10
```

**Rows returned:** 10

| product_id | product_name | category_name | units_sold | orders | gross_value |
|---|---|---|---|---|---|
| 9 | boAt Airdopes 141 | Earbuds | 73 | 56 | 94827.00 |
| 6 | Spigen Rugged Armor Phone Case | Mobile Accessories | 37 | 28 | 33263.00 |
| 8 | Portronics Konnect USB-C Cable | Mobile Accessories | 37 | 33 | 11063.00 |
| 38 | Atomic Habits | Non-Fiction | 35 | 25 | 14465.00 |
| 33 | Pigeon 1.5L Electric Kettle | Kitchen Appliances | 25 | 20 | 17475.00 |
| 25 | Biba Cotton Straight Kurta | Women's Kurtas | 24 | 17 | 31176.00 |
| 40 | Ikigai | Non-Fiction | 24 | 19 | 7176.00 |
| 20 | SanDisk Ultra 128GB Pendrive | Computer Accessories | 23 | 16 | 20677.00 |
| 39 | Wings of Fire | Non-Fiction | 22 | 17 | 5478.00 |
| 24 | Roadster Graphic Print T-Shirt | Men's T-Shirts | 21 | 14 | 9429.00 |

## B2 Best-selling products by revenue (top 10)

```sql
SELECT p.product_id,
       p.product_name,
       cat.category_name,
       SUM(oi.quantity)                  AS units_sold,
       SUM(oi.quantity * oi.unit_price)  AS gross_value,
       ROUND(100 * SUM(oi.quantity * oi.unit_price)
             / (SELECT SUM(oi2.quantity * oi2.unit_price)
                FROM   order_items oi2 JOIN orders o2 ON o2.order_id = oi2.order_id
                WHERE  o2.status <> 'CANCELLED'), 2) AS share_pct
FROM   order_items oi
JOIN   orders     o   ON o.order_id     = oi.order_id
JOIN   products   p   ON p.product_id   = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY p.product_id, p.product_name, cat.category_name
ORDER  BY gross_value DESC
LIMIT  10
```

**Rows returned:** 10

| product_id | product_name | category_name | units_sold | gross_value | share_pct |
|---|---|---|---|---|---|
| 3 | OnePlus 12R (8GB/128GB) | Smartphones | 13 | 519987.00 | 18.19 |
| 2 | Apple iPhone 15 (128GB) | Smartphones | 6 | 431994.00 | 15.11 |
| 4 | Redmi Note 13 Pro 5G | Smartphones | 13 | 325987.00 | 11.40 |
| 15 | HP Pavilion 15 Laptop (i5) | Laptops | 4 | 251960.00 | 8.81 |
| 16 | Lenovo IdeaPad Slim 3 (Ryzen 5) | Laptops | 5 | 229950.00 | 8.04 |
| 1 | Samsung Galaxy S24 (8GB/256GB) | Smartphones | 3 | 224997.00 | 7.87 |
| 9 | boAt Airdopes 141 | Earbuds | 73 | 94827.00 | 3.32 |
| 12 | Sony WH-1000XM5 Headphones | Headphones | 3 | 89970.00 | 3.15 |
| 13 | JBL Tune 760NC Headphones | Headphones | 12 | 71988.00 | 2.52 |
| 19 | Logitech MX Master 3S Mouse | Computer Accessories | 6 | 53970.00 | 1.89 |

## B3 Best-selling product per category

```sql
SELECT cat.category_name,
       s.product_name,
       s.units_sold
FROM  (SELECT p.category_id, p.product_id, p.product_name,
              SUM(oi.quantity) AS units_sold
       FROM   order_items oi
       JOIN   orders   o ON o.order_id   = oi.order_id
       JOIN   products p ON p.product_id = oi.product_id
       WHERE  o.status <> 'CANCELLED'
       GROUP  BY p.category_id, p.product_id, p.product_name) AS s
JOIN  (SELECT category_id, MAX(units_sold) AS max_units
       FROM  (SELECT p.category_id, p.product_id, SUM(oi.quantity) AS units_sold
              FROM   order_items oi
              JOIN   orders   o ON o.order_id   = oi.order_id
              JOIN   products p ON p.product_id = oi.product_id
              WHERE  o.status <> 'CANCELLED'
              GROUP  BY p.category_id, p.product_id) AS t
       GROUP  BY category_id) AS m
       ON m.category_id = s.category_id AND m.max_units = s.units_sold
JOIN   categories cat ON cat.category_id = s.category_id
ORDER  BY s.units_sold DESC, cat.category_name
```

**Rows returned:** 15

| category_name | product_name | units_sold |
|---|---|---|
| Earbuds | boAt Airdopes 141 | 73 |
| Mobile Accessories | Portronics Konnect USB-C Cable | 37 |
| Mobile Accessories | Spigen Rugged Armor Phone Case | 37 |
| Non-Fiction | Atomic Habits | 35 |
| Kitchen Appliances | Pigeon 1.5L Electric Kettle | 25 |
| Women's Kurtas | Biba Cotton Straight Kurta | 24 |
| Computer Accessories | SanDisk Ultra 128GB Pendrive | 23 |
| Men's T-Shirts | Roadster Graphic Print T-Shirt | 21 |
| Headphones | boAt Rockerz 450 Headphones | 20 |
| Fiction | The Palace of Illusions | 14 |
| Home Decor | Home Sizzler Cushion Covers (Set of 5) | 14 |
| Sports Shoes | Campus North Plus Running Shoes | 14 |
| Smartphones | OnePlus 12R (8GB/128GB) | 13 |
| Smartphones | Redmi Note 13 Pro 5G | 13 |
| Laptops | Lenovo IdeaPad Slim 3 (Ryzen 5) | 5 |

## B4 Stock of the top 10 best sellers

```sql
SELECT top10.product_name,
       top10.units_sold,
       SUM(i.quantity)                        AS stock_all_warehouses,
       SUM(i.quantity = 0)                    AS warehouses_out_of_stock,
       SUM(i.quantity < i.reorder_level)      AS warehouses_below_reorder
FROM  (SELECT p.product_id, p.product_name, SUM(oi.quantity) AS units_sold
       FROM   order_items oi
       JOIN   orders   o ON o.order_id   = oi.order_id
       JOIN   products p ON p.product_id = oi.product_id
       WHERE  o.status <> 'CANCELLED'
       GROUP  BY p.product_id, p.product_name
       ORDER  BY units_sold DESC
       LIMIT  10) AS top10
JOIN   inventory i ON i.product_id = top10.product_id
GROUP  BY top10.product_id, top10.product_name, top10.units_sold
ORDER  BY top10.units_sold DESC
```

**Rows returned:** 10

| product_name | units_sold | stock_all_warehouses | warehouses_out_of_stock | warehouses_below_reorder |
|---|---|---|---|---|
| boAt Airdopes 141 | 73 | 202 | 0 | 0 |
| Spigen Rugged Armor Phone Case | 37 | 266 | 0 | 0 |
| Portronics Konnect USB-C Cable | 37 | 325 | 0 | 0 |
| Atomic Habits | 35 | 229 | 0 | 0 |
| Pigeon 1.5L Electric Kettle | 25 | 299 | 0 | 0 |
| Ikigai | 24 | 297 | 0 | 0 |
| Biba Cotton Straight Kurta | 24 | 224 | 0 | 0 |
| SanDisk Ultra 128GB Pendrive | 23 | 270 | 0 | 0 |
| Wings of Fire | 22 | 158 | 0 | 0 |
| Roadster Graphic Print T-Shirt | 21 | 233 | 0 | 0 |

## C1 Average order value

```sql
SELECT COUNT(*)                 AS paid_orders,
       SUM(pay.amount)          AS net_revenue,
       ROUND(AVG(pay.amount), 2) AS avg_order_value,
       MIN(pay.amount)          AS smallest_order,
       MAX(pay.amount)          AS biggest_order
FROM   payments pay
JOIN   orders   o ON o.order_id = pay.order_id
WHERE  pay.status = 'SUCCESS'
  AND  o.status  <> 'CANCELLED'
```

**Rows returned:** 1

| paid_orders | net_revenue | avg_order_value | smallest_order | biggest_order |
|---|---|---|---|---|
| 254 | 2759323.10 | 10863.48 | 249.00 | 121587.00 |

## C2 Revenue by payment method

```sql
SELECT pay.method,
       COUNT(*)                  AS paid_orders,
       SUM(pay.amount)           AS net_revenue,
       ROUND(AVG(pay.amount), 2) AS avg_order_value,
       ROUND(100 * SUM(pay.amount)
             / (SELECT SUM(p2.amount)
                FROM   payments p2 JOIN orders o2 ON o2.order_id = p2.order_id
                WHERE  p2.status = 'SUCCESS' AND o2.status <> 'CANCELLED'), 2) AS share_pct
FROM   payments pay
JOIN   orders   o ON o.order_id = pay.order_id
WHERE  pay.status = 'SUCCESS'
  AND  o.status  <> 'CANCELLED'
GROUP  BY pay.method
ORDER  BY net_revenue DESC
```

**Rows returned:** 4

| method | paid_orders | net_revenue | avg_order_value | share_pct |
|---|---|---|---|---|
| UPI | 106 | 867061.20 | 8179.82 | 31.42 |
| CARD | 62 | 717270.80 | 11568.88 | 25.99 |
| NET_BANKING | 41 | 671832.25 | 16386.15 | 24.35 |
| COD | 45 | 503158.85 | 11181.31 | 18.23 |

## C3 Payment failure rate by method

```sql
SELECT method,
       COUNT(*)                                   AS attempts,
       SUM(status = 'SUCCESS')                    AS succeeded,
       SUM(status = 'FAILED')                     AS failed,
       SUM(status = 'PENDING')                    AS pending,
       ROUND(100 * SUM(status = 'FAILED') / COUNT(*), 1) AS failure_rate_pct
FROM   payments
GROUP  BY method
ORDER  BY failure_rate_pct DESC
```

**Rows returned:** 4

| method | attempts | succeeded | failed | pending | failure_rate_pct |
|---|---|---|---|---|---|
| CARD | 80 | 64 | 16 | 0 | 20.0 |
| NET_BANKING | 56 | 43 | 10 | 3 | 17.9 |
| UPI | 130 | 108 | 22 | 0 | 16.9 |
| COD | 45 | 45 | 0 | 0 | 0.0 |

## C4 Monthly revenue

```sql
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
       COUNT(*)                           AS paid_orders,
       SUM(pay.amount)                    AS net_revenue,
       ROUND(AVG(pay.amount), 2)          AS avg_order_value
FROM   orders   o
JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
WHERE  o.status <> 'CANCELLED'
GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER  BY month
```

**Rows returned:** 7

| month | paid_orders | net_revenue | avg_order_value |
|---|---|---|---|
| 2026-05 | 33 | 480445.40 | 14558.95 |
| 2026-06 | 30 | 308110.80 | 10270.36 |
| 2026-07 | 32 | 260324.55 | 8135.14 |
| 2026-08 | 54 | 725777.05 | 13440.32 |
| 2026-09 | 30 | 130122.70 | 4337.42 |
| 2026-10 | 49 | 620137.30 | 12655.86 |
| 2026-11 | 26 | 234405.30 | 9015.59 |

## C5 Orders with failed or pending payments

```sql
SELECT o.order_id,
       DATE(o.order_date)                         AS order_day,
       c.full_name                                AS customer,
       GROUP_CONCAT(CONCAT(pay.method, ':', pay.status)
                    ORDER BY pay.payment_id SEPARATOR ' -> ') AS payment_attempts,
       CASE
           WHEN SUM(pay.status = 'SUCCESS') > 0 THEN 'Recovered on retry'
           WHEN SUM(pay.status = 'PENDING') > 0 THEN 'Money pending'
           ELSE 'Failed - order cancelled'
       END                                        AS outcome,
       o.status                                   AS order_status
FROM   orders o
JOIN   customers c  ON c.customer_id = o.customer_id
JOIN   payments pay ON pay.order_id  = o.order_id
GROUP  BY o.order_id, o.order_date, c.full_name, o.status
HAVING SUM(pay.status IN ('FAILED', 'PENDING')) > 0
ORDER  BY outcome, o.order_date
```

**Rows returned:** 41

| order_id | order_day | customer | payment_attempts | outcome | order_status |
|---|---|---|---|---|---|
| 1002 | 2026-05-02 | Isha Gupta | NET_BANKING:FAILED -> NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1007 | 2026-05-05 | Aarav Sharma | UPI:FAILED -> UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1074 | 2026-07-09 | Anjali Tiwari | NET_BANKING:FAILED -> NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1113 | 2026-08-09 | Kritika Sood | NET_BANKING:FAILED -> NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1148 | 2026-08-26 | Gaurav Sinha | NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1164 | 2026-09-09 | Deepak Pandey | UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1178 | 2026-09-16 | Pranav Hegde | NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1181 | 2026-09-18 | Karan Malhotra | CARD:FAILED -> CARD:FAILED | Failed - order cancelled | CANCELLED |
| 1185 | 2026-09-23 | Anjali Tiwari | CARD:FAILED -> CARD:FAILED | Failed - order cancelled | CANCELLED |
| 1190 | 2026-09-28 | Nisha Thakur | UPI:FAILED -> UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1193 | 2026-09-30 | Priya Nair | UPI:FAILED -> UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1205 | 2026-10-05 | Pooja Desai | UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1220 | 2026-10-11 | Fatima Sheikh | UPI:FAILED -> UPI:FAILED | Failed - order cancelled | CANCELLED |
| 1234 | 2026-10-20 | Fatima Sheikh | CARD:FAILED | Failed - order cancelled | CANCELLED |
| 1237 | 2026-10-22 | Manish Yadav | CARD:FAILED | Failed - order cancelled | CANCELLED |
| 1276 | 2026-11-19 | Kavya Menon | NET_BANKING:FAILED -> NET_BANKING:FAILED | Failed - order cancelled | CANCELLED |
| 1265 | 2026-11-09 | Kritika Sood | NET_BANKING:PENDING | Money pending | PLACED |
| 1270 | 2026-11-15 | Aditi Bhatt | NET_BANKING:PENDING | Money pending | PLACED |
| 1271 | 2026-11-15 | Aditya Verma | NET_BANKING:PENDING | Money pending | PLACED |
| 1015 | 2026-05-14 | Payal Ghosh | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1016 | 2026-05-14 | Priya Nair | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1049 | 2026-06-18 | Varun Kapoor | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1082 | 2026-07-17 | Neha Kulkarni | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1093 | 2026-07-22 | Fatima Sheikh | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1097 | 2026-07-28 | Bhavna Rathore | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1099 | 2026-07-29 | Harsh Agarwal | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1118 | 2026-08-12 | Karan Malhotra | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1120 | 2026-08-12 | Pooja Desai | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1137 | 2026-08-20 | Saurabh Dubey | UPI:FAILED -> NET_BANKING:SUCCESS | Recovered on retry | DELIVERED |
| 1138 | 2026-08-20 | Arjun Reddy | CARD:FAILED -> NET_BANKING:SUCCESS | Recovered on retry | DELIVERED |
| 1154 | 2026-08-28 | Yash Saxena | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1180 | 2026-09-17 | Arjun Reddy | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1186 | 2026-09-24 | Vikram Singh | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1208 | 2026-10-06 | Imran Qureshi | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1211 | 2026-10-07 | Aditya Verma | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1212 | 2026-10-08 | Varun Kapoor | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |
| 1224 | 2026-10-13 | Manish Yadav | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1232 | 2026-10-17 | Isha Gupta | UPI:FAILED -> NET_BANKING:SUCCESS | Recovered on retry | DELIVERED |
| 1238 | 2026-10-23 | Aditya Verma | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1242 | 2026-10-27 | Kritika Sood | CARD:FAILED -> UPI:SUCCESS | Recovered on retry | DELIVERED |
| 1263 | 2026-11-09 | Rohan Mehta | UPI:FAILED -> CARD:SUCCESS | Recovered on retry | DELIVERED |

## C6 Orders not yet delivered

```sql
SELECT o.order_id,
       DATE(o.order_date)                       AS order_day,
       DATEDIFF('2026-11-20', o.order_date)     AS days_waiting,
       c.full_name                              AS customer,
       o.status                                 AS order_status,
       COALESCE(d.status, 'NOT CREATED')        AS delivery_status,
       d.courier,
       w.warehouse_name
FROM   orders o
JOIN   customers  c ON c.customer_id = o.customer_id
LEFT JOIN deliveries d ON d.order_id     = o.order_id
LEFT JOIN warehouses w ON w.warehouse_id = d.warehouse_id
WHERE  o.status NOT IN ('DELIVERED', 'CANCELLED')
ORDER  BY days_waiting DESC, o.order_id
```

**Rows returned:** 14

| order_id | order_day | days_waiting | customer | order_status | delivery_status | courier | warehouse_name |
|---|---|---|---|---|---|---|---|
| 1262 | 2026-11-08 | 12 | Harsh Agarwal | CONFIRMED | NOT CREATED | NULL | NULL |
| 1265 | 2026-11-09 | 11 | Kritika Sood | PLACED | NOT CREATED | NULL | NULL |
| 1266 | 2026-11-10 | 10 | Anjali Tiwari | SHIPPED | IN_TRANSIT | Shadowfax | Bhiwandi FC |
| 1267 | 2026-11-11 | 9 | Manish Yadav | SHIPPED | IN_TRANSIT | XpressBees | Gurugram FC |
| 1269 | 2026-11-14 | 6 | Pooja Desai | SHIPPED | IN_TRANSIT | Ekart | Gurugram FC |
| 1270 | 2026-11-15 | 5 | Aditi Bhatt | PLACED | NOT CREATED | NULL | NULL |
| 1271 | 2026-11-15 | 5 | Aditya Verma | PLACED | NOT CREATED | NULL | NULL |
| 1272 | 2026-11-16 | 4 | Aditya Verma | SHIPPED | SHIPPED | Blue Dart | Bhiwandi FC |
| 1273 | 2026-11-17 | 3 | Aditi Bhatt | CONFIRMED | PENDING | XpressBees | Bhiwandi FC |
| 1274 | 2026-11-17 | 3 | Shreya Das | CONFIRMED | PENDING | Shadowfax | Bhiwandi FC |
| 1275 | 2026-11-19 | 1 | Imran Qureshi | SHIPPED | SHIPPED | Delhivery | Bhiwandi FC |
| 1277 | 2026-11-20 | 0 | Isha Gupta | CONFIRMED | PENDING | Blue Dart | Bengaluru FC |
| 1280 | 2026-11-20 | 0 | Varun Kapoor | CONFIRMED | PENDING | Delhivery | Bengaluru FC |
| 1281 | 2026-11-20 | 0 | Isha Gupta | CONFIRMED | PENDING | Delhivery | Bhiwandi FC |

## C7 Courier performance

```sql
SELECT courier,
       COUNT(*)                                             AS shipments,
       SUM(status = 'DELIVERED')                            AS delivered,
       SUM(status = 'RETURNED')                             AS returned,
       ROUND(AVG(CASE WHEN status = 'DELIVERED'
                      THEN DATEDIFF(delivered_date, shipped_date) END), 2) AS avg_transit_days,
       ROUND(100 * SUM(status = 'RETURNED')
             / NULLIF(SUM(status IN ('DELIVERED', 'RETURNED')), 0), 1)   AS return_rate_pct
FROM   deliveries
GROUP  BY courier
ORDER  BY avg_transit_days
```

**Rows returned:** 5

| courier | shipments | delivered | returned | avg_transit_days | return_rate_pct |
|---|---|---|---|---|---|
| Ekart | 45 | 42 | 2 | 3.67 | 4.5 |
| XpressBees | 66 | 64 | 0 | 3.73 | 0.0 |
| Blue Dart | 50 | 46 | 2 | 4.09 | 4.2 |
| Delhivery | 55 | 50 | 2 | 4.14 | 3.8 |
| Shadowfax | 43 | 41 | 0 | 4.68 | 0.0 |

## D1 Coupon usage and impact

```sql
SELECT d.code,
       d.discount_type,
       d.discount_value,
       d.min_order_value,
       COUNT(od.order_id)                            AS times_used,
       COALESCE(SUM(od.amount_saved), 0)             AS total_discount_given,
       ROUND(AVG(od.amount_saved), 2)                AS avg_saving,
       ROUND(AVG((SELECT SUM(oi.quantity * oi.unit_price)
                  FROM   order_items oi
                  WHERE  oi.order_id = od.order_id)), 2) AS avg_order_gross
FROM   discounts d
LEFT JOIN order_discounts od ON od.discount_id = d.discount_id
GROUP  BY d.discount_id, d.code, d.discount_type, d.discount_value, d.min_order_value
ORDER  BY times_used DESC, d.code
```

**Rows returned:** 6

| code | discount_type | discount_value | min_order_value | times_used | total_discount_given | avg_saving | avg_order_gross |
|---|---|---|---|---|---|---|---|
| SAVE10 | PERCENT | 10.00 | 1000.00 | 46 | 37373.30 | 812.46 | 8124.63 |
| FLAT500 | FLAT | 500.00 | 5000.00 | 12 | 6000.00 | 500.00 | 37165.92 |
| MONSOON15 | PERCENT | 15.00 | 2000.00 | 12 | 12325.20 | 1027.10 | 6847.33 |
| WELCOME100 | FLAT | 100.00 | 499.00 | 7 | 700.00 | 100.00 | 13339.71 |
| FESTIVE20 | PERCENT | 20.00 | 3000.00 | 1 | 4799.80 | 4799.80 | 23999.00 |
| SUMMER25 | PERCENT | 25.00 | 1500.00 | 0 | 0.00 | NULL | NULL |

## D2 Coupon vs no-coupon orders

```sql
SELECT IF(od.order_id IS NULL, 'No coupon', 'With coupon') AS order_type,
       COUNT(*)                                          AS paid_orders,
       ROUND(AVG(g.gross_value), 2)                      AS avg_gross_value,
       ROUND(AVG(COALESCE(od.amount_saved, 0)), 2)       AS avg_saving,
       ROUND(AVG(pay.amount), 2)                         AS avg_net_paid
FROM   orders o
JOIN   payments pay ON pay.order_id = o.order_id AND pay.status = 'SUCCESS'
JOIN  (SELECT order_id, SUM(quantity * unit_price) AS gross_value
       FROM   order_items
       GROUP  BY order_id) AS g ON g.order_id = o.order_id
LEFT JOIN order_discounts od ON od.order_id = o.order_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY IF(od.order_id IS NULL, 'No coupon', 'With coupon')
ORDER  BY order_type DESC
```

**Rows returned:** 2

| order_type | paid_orders | avg_gross_value | avg_saving | avg_net_paid |
|---|---|---|---|---|
| With coupon | 70 | 12647.04 | 788.21 | 11858.83 |
| No coupon | 184 | 10484.81 | 0.00 | 10484.81 |
