# Results of `sql/12_window_functions_ctes.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## W1 ROW_NUMBER vs RANK vs DENSE_RANK - products by units sold

```sql
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
ORDER  BY units_sold DESC, product_id
```

**Rows returned:** 38

| product_id | product_name | units_sold | row_num | rnk | dense_rnk |
|---|---|---|---|---|---|
| 9 | boAt Airdopes 141 | 73 | 1 | 1 | 1 |
| 6 | Spigen Rugged Armor Phone Case | 37 | 2 | 2 | 2 |
| 8 | Portronics Konnect USB-C Cable | 37 | 3 | 2 | 2 |
| 38 | Atomic Habits | 35 | 4 | 4 | 3 |
| 33 | Pigeon 1.5L Electric Kettle | 25 | 5 | 5 | 4 |
| 25 | Biba Cotton Straight Kurta | 24 | 6 | 6 | 5 |
| 40 | Ikigai | 24 | 7 | 6 | 5 |
| 20 | SanDisk Ultra 128GB Pendrive | 23 | 8 | 8 | 6 |
| 39 | Wings of Fire | 22 | 9 | 9 | 7 |
| 24 | Roadster Graphic Print T-Shirt | 21 | 10 | 10 | 8 |
| 14 | boAt Rockerz 450 Headphones | 20 | 11 | 11 | 9 |
| 22 | Allen Solly Men's Polo T-Shirt | 20 | 12 | 11 | 9 |
| 26 | W Printed A-Line Kurta | 19 | 13 | 13 | 10 |
| 7 | Samsung 25W Type-C Charger | 16 | 14 | 14 | 11 |
| 30 | Campus North Plus Running Shoes | 14 | 15 | 15 | 12 |
| 36 | Home Sizzler Cushion Covers (Set of 5) | 14 | 16 | 15 | 12 |
| 37 | The Palace of Illusions | 14 | 17 | 15 | 12 |
| 3 | OnePlus 12R (8GB/128GB) | 13 | 18 | 18 | 13 |
| 4 | Redmi Note 13 Pro 5G | 13 | 19 | 18 | 13 |
| 10 | OnePlus Nord Buds 2 | 13 | 20 | 18 | 13 |
| 13 | JBL Tune 760NC Headphones | 12 | 21 | 21 | 14 |
| 31 | Prestige PIC 20 Induction Cooktop | 12 | 22 | 21 | 14 |
| 5 | boAt 20000mAh Power Bank | 11 | 23 | 23 | 15 |
| 23 | U.S. Polo Assn. Crew Neck Tee | 11 | 24 | 23 | 15 |
| 27 | Libas Anarkali Kurta Set | 10 | 25 | 25 | 16 |
| 29 | Puma Softride Running Shoes | 8 | 26 | 26 | 17 |
| 28 | Nike Revolution 6 Running Shoes | 7 | 27 | 27 | 18 |
| 2 | Apple iPhone 15 (128GB) | 6 | 28 | 28 | 19 |
| 19 | Logitech MX Master 3S Mouse | 6 | 29 | 28 | 19 |
| 16 | Lenovo IdeaPad Slim 3 (Ryzen 5) | 5 | 30 | 30 | 20 |
| 32 | Philips HL7756 Mixer Grinder | 5 | 31 | 30 | 20 |
| 15 | HP Pavilion 15 Laptop (i5) | 4 | 32 | 32 | 21 |
| 21 | HP M24f 24-inch FHD Monitor | 4 | 33 | 32 | 21 |
| 34 | Bajaj 1603T 16L OTG | 4 | 34 | 32 | 21 |
| 1 | Samsung Galaxy S24 (8GB/256GB) | 3 | 35 | 35 | 22 |
| 12 | Sony WH-1000XM5 Headphones | 3 | 36 | 35 | 22 |
| 11 | Apple AirPods Pro (2nd Gen) | 1 | 37 | 37 | 23 |
| 18 | ASUS Vivobook 15 (i3) | 1 | 38 | 37 | 23 |

## W2 RANK PARTITION BY category - product rank inside its category

```sql
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
ORDER  BY cat.category_name, revenue_rank
```

**Rows returned:** 38

| category_name | product_name | units_sold | gross_value | revenue_rank | units_rank |
|---|---|---|---|---|---|
| Computer Accessories | Logitech MX Master 3S Mouse | 6 | 53970.00 | 1 | 2 |
| Computer Accessories | HP M24f 24-inch FHD Monitor | 4 | 41996.00 | 2 | 3 |
| Computer Accessories | SanDisk Ultra 128GB Pendrive | 23 | 20677.00 | 3 | 1 |
| Earbuds | boAt Airdopes 141 | 73 | 94827.00 | 1 | 1 |
| Earbuds | OnePlus Nord Buds 2 | 13 | 30287.00 | 2 | 2 |
| Earbuds | Apple AirPods Pro (2nd Gen) | 1 | 24900.00 | 3 | 3 |
| Fiction | The Palace of Illusions | 14 | 4886.00 | 1 | 1 |
| Headphones | Sony WH-1000XM5 Headphones | 3 | 89970.00 | 1 | 3 |
| Headphones | JBL Tune 760NC Headphones | 12 | 71988.00 | 2 | 2 |
| Headphones | boAt Rockerz 450 Headphones | 20 | 29980.00 | 3 | 1 |
| Home Decor | Home Sizzler Cushion Covers (Set of 5) | 14 | 6986.00 | 1 | 1 |
| Kitchen Appliances | Prestige PIC 20 Induction Cooktop | 12 | 27588.00 | 1 | 2 |
| Kitchen Appliances | Bajaj 1603T 16L OTG | 4 | 21996.00 | 2 | 4 |
| Kitchen Appliances | Philips HL7756 Mixer Grinder | 5 | 17495.00 | 3 | 3 |
| Kitchen Appliances | Pigeon 1.5L Electric Kettle | 25 | 17475.00 | 4 | 1 |
| Laptops | HP Pavilion 15 Laptop (i5) | 4 | 251960.00 | 1 | 2 |
| Laptops | Lenovo IdeaPad Slim 3 (Ryzen 5) | 5 | 229950.00 | 2 | 1 |
| Laptops | ASUS Vivobook 15 (i3) | 1 | 38990.00 | 3 | 3 |
| Men's T-Shirts | Allen Solly Men's Polo T-Shirt | 20 | 17980.00 | 1 | 2 |
| Men's T-Shirts | Roadster Graphic Print T-Shirt | 21 | 9429.00 | 2 | 1 |
| Men's T-Shirts | U.S. Polo Assn. Crew Neck Tee | 11 | 8789.00 | 3 | 3 |
| Mobile Accessories | Spigen Rugged Armor Phone Case | 37 | 33263.00 | 1 | 1 |
| Mobile Accessories | Samsung 25W Type-C Charger | 16 | 20784.00 | 2 | 3 |
| Mobile Accessories | boAt 20000mAh Power Bank | 11 | 16489.00 | 3 | 4 |
| Mobile Accessories | Portronics Konnect USB-C Cable | 37 | 11063.00 | 4 | 1 |
| Non-Fiction | Atomic Habits | 35 | 14465.00 | 1 | 1 |
| Non-Fiction | Ikigai | 24 | 7176.00 | 2 | 2 |
| Non-Fiction | Wings of Fire | 22 | 5478.00 | 3 | 3 |
| Smartphones | OnePlus 12R (8GB/128GB) | 13 | 519987.00 | 1 | 1 |
| Smartphones | Apple iPhone 15 (128GB) | 6 | 431994.00 | 2 | 3 |
| Smartphones | Redmi Note 13 Pro 5G | 13 | 325987.00 | 3 | 1 |
| Smartphones | Samsung Galaxy S24 (8GB/256GB) | 3 | 224997.00 | 4 | 4 |
| Sports Shoes | Nike Revolution 6 Running Shoes | 7 | 25865.00 | 1 | 3 |
| Sports Shoes | Puma Softride Running Shoes | 8 | 23192.00 | 2 | 2 |
| Sports Shoes | Campus North Plus Running Shoes | 14 | 18186.00 | 3 | 1 |
| Women's Kurtas | Biba Cotton Straight Kurta | 24 | 31176.00 | 1 | 1 |
| Women's Kurtas | W Printed A-Line Kurta | 19 | 20881.00 | 2 | 2 |
| Women's Kurtas | Libas Anarkali Kurta Set | 10 | 15990.00 | 3 | 3 |

## W2b RANK = 1 - best seller per category (ties kept)

```sql
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
ORDER  BY units_sold DESC, category_name
```

**Rows returned:** 15

| category_name | product_name | units_sold |
|---|---|---|
| Earbuds | boAt Airdopes 141 | 73 |
| Mobile Accessories | Spigen Rugged Armor Phone Case | 37 |
| Mobile Accessories | Portronics Konnect USB-C Cable | 37 |
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

## W3 ROW_NUMBER = 1 - one featured product per category

```sql
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
ORDER  BY category_name
```

**Rows returned:** 13

| category_name | product_name | units_sold | gross_value |
|---|---|---|---|
| Computer Accessories | SanDisk Ultra 128GB Pendrive | 23 | 20677.00 |
| Earbuds | boAt Airdopes 141 | 73 | 94827.00 |
| Fiction | The Palace of Illusions | 14 | 4886.00 |
| Headphones | boAt Rockerz 450 Headphones | 20 | 29980.00 |
| Home Decor | Home Sizzler Cushion Covers (Set of 5) | 14 | 6986.00 |
| Kitchen Appliances | Pigeon 1.5L Electric Kettle | 25 | 17475.00 |
| Laptops | Lenovo IdeaPad Slim 3 (Ryzen 5) | 5 | 229950.00 |
| Men's T-Shirts | Roadster Graphic Print T-Shirt | 21 | 9429.00 |
| Mobile Accessories | Spigen Rugged Armor Phone Case | 37 | 33263.00 |
| Non-Fiction | Atomic Habits | 35 | 14465.00 |
| Smartphones | OnePlus 12R (8GB/128GB) | 13 | 519987.00 |
| Sports Shoes | Campus North Plus Running Shoes | 14 | 18186.00 |
| Women's Kurtas | Biba Cotton Straight Kurta | 24 | 31176.00 |

## W4 SUM OVER ORDER BY - running total of revenue

```sql
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
ORDER  BY month
```

**Rows returned:** 7

| month | revenue | running_total | pct_of_total |
|---|---|---|---|
| 2026-05 | 480445.40 | 480445.40 | 17.4 |
| 2026-06 | 308110.80 | 788556.20 | 28.6 |
| 2026-07 | 260324.55 | 1048880.75 | 38.0 |
| 2026-08 | 725777.05 | 1774657.80 | 64.3 |
| 2026-09 | 130122.70 | 1904780.50 | 69.0 |
| 2026-10 | 620137.30 | 2524917.80 | 91.5 |
| 2026-11 | 234405.30 | 2759323.10 | 100.0 |

## W5 LAG - month-over-month revenue change

```sql
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
ORDER  BY month
```

**Rows returned:** 7

| month | paid_orders | revenue | prev_month_revenue | change_amount | change_pct |
|---|---|---|---|---|---|
| 2026-05 | 33 | 480445.40 | NULL | NULL | NULL |
| 2026-06 | 30 | 308110.80 | 480445.40 | -172334.60 | -35.9 |
| 2026-07 | 32 | 260324.55 | 308110.80 | -47786.25 | -15.5 |
| 2026-08 | 54 | 725777.05 | 260324.55 | 465452.50 | 178.8 |
| 2026-09 | 30 | 130122.70 | 725777.05 | -595654.35 | -82.1 |
| 2026-10 | 49 | 620137.30 | 130122.70 | 490014.60 | 376.6 |
| 2026-11 | 26 | 234405.30 | 620137.30 | -385732.00 | -62.2 |

## W6 AVG OVER ROWS 2 PRECEDING - 3-month moving average

```sql
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
ORDER  BY month
```

**Rows returned:** 7

| month | revenue | moving_avg_3m |
|---|---|---|
| 2026-05 | 480445.40 | 480445.40 |
| 2026-06 | 308110.80 | 394278.10 |
| 2026-07 | 260324.55 | 349626.92 |
| 2026-08 | 725777.05 | 431404.13 |
| 2026-09 | 130122.70 | 372074.77 |
| 2026-10 | 620137.30 | 492012.35 |
| 2026-11 | 234405.30 | 328221.77 |

## W7 NTILE(4) - customer quartiles by lifetime value

```sql
SELECT customer_id,
       full_name,
       lifetime_value,
       NTILE(4) OVER (ORDER BY lifetime_value DESC, customer_id) AS quartile
FROM   vw_customer_lifetime_value
WHERE  lifetime_value > 0
ORDER  BY lifetime_value DESC, customer_id
```

**Rows returned:** 39

| customer_id | full_name | lifetime_value | quartile |
|---|---|---|---|
| 26 | Ananya Iyer | 292528.30 | 1 |
| 32 | Aditya Verma | 266380.90 | 1 |
| 39 | Yash Saxena | 175082.05 | 1 |
| 44 | Pranav Hegde | 169193.20 | 1 |
| 1 | Aarav Sharma | 167434.60 | 1 |
| 27 | Tanvi Shah | 161605.10 | 1 |
| 3 | Isha Gupta | 145357.00 | 1 |
| 11 | Arjun Reddy | 141201.00 | 1 |
| 15 | Pooja Desai | 126581.40 | 1 |
| 12 | Varun Kapoor | 121792.95 | 1 |
| 9 | Bhavna Rathore | 114214.30 | 2 |
| 46 | Aditi Bhatt | 113910.20 | 2 |
| 31 | Kritika Sood | 82436.00 | 2 |
| 41 | Anjali Tiwari | 72657.50 | 2 |
| 33 | Siddharth Rao | 69655.30 | 2 |
| 19 | Imran Qureshi | 62631.50 | 2 |
| 8 | Nikhil Jain | 54594.00 | 2 |
| 18 | Payal Ghosh | 53871.00 | 2 |
| 25 | Kunal Bose | 52279.25 | 2 |
| 5 | Sneha Patil | 49887.00 | 2 |
| 7 | Karan Malhotra | 48563.10 | 3 |
| 35 | Tushar Naidu | 32846.00 | 3 |
| 22 | Meera Pillai | 24483.00 | 3 |
| 34 | Priya Nair | 22830.00 | 3 |
| 2 | Rohan Mehta | 18250.20 | 3 |
| 28 | Sakshi Mittal | 15486.00 | 3 |
| 43 | Fatima Sheikh | 13685.00 | 3 |
| 21 | Vikram Singh | 13557.50 | 3 |
| 20 | Sam Fernandes | 13029.30 | 3 |
| 29 | Manish Yadav | 12635.10 | 3 |
| 13 | Harsh Agarwal | 11599.00 | 4 |
| 14 | Saurabh Dubey | 10132.30 | 4 |
| 16 | Shreya Das | 10090.00 | 4 |
| 23 | Neha Kulkarni | 8458.10 | 4 |
| 38 | Mohit Bansal | 3097.00 | 4 |
| 40 | Aman Choudhary | 2498.00 | 4 |
| 37 | Abhishek Mishra | 1994.95 | 4 |
| 4 | Simran Kaur | 1497.00 | 4 |
| 36 | Alok Tripathi | 1299.00 | 4 |

## W7b NTILE(4) - size and value of each quartile

```sql
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
ORDER  BY quartile
```

**Rows returned:** 4

| quartile | customers | min_value | max_value | total_value | share_pct |
|---|---|---|---|---|---|
| Q1 | 10 | 121792.95 | 292528.30 | 1767156.50 | 64.0 |
| Q2 | 10 | 49887.00 | 114214.30 | 726136.05 | 26.3 |
| Q3 | 10 | 12635.10 | 48563.10 | 215365.20 | 7.8 |
| Q4 | 9 | 1299.00 | 11599.00 | 50665.35 | 1.8 |

## W8 LEAD - average gap between orders per repeat customer

```sql
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
ORDER  BY avg_days_between_orders, g.customer_id
```

**Rows returned:** 34

| customer_id | full_name | orders_placed | avg_days_between_orders | shortest_gap | longest_gap |
|---|---|---|---|---|---|
| 44 | Pranav Hegde | 16 | 4.7 | 0 | 15 |
| 43 | Fatima Sheikh | 12 | 8.2 | 0 | 31 |
| 22 | Meera Pillai | 5 | 9.5 | 3 | 17 |
| 39 | Yash Saxena | 15 | 11.0 | 0 | 31 |
| 32 | Aditya Verma | 16 | 12.3 | 1 | 58 |
| 3 | Isha Gupta | 17 | 12.6 | 0 | 41 |
| 15 | Pooja Desai | 12 | 15.4 | 0 | 39 |
| 41 | Anjali Tiwari | 9 | 15.6 | 1 | 76 |
| 12 | Varun Kapoor | 13 | 15.7 | 1 | 52 |
| 9 | Bhavna Rathore | 13 | 15.8 | 1 | 74 |
| 11 | Arjun Reddy | 8 | 19.3 | 0 | 38 |
| 31 | Kritika Sood | 8 | 19.6 | 1 | 68 |
| 33 | Siddharth Rao | 7 | 20.0 | 2 | 38 |
| 21 | Vikram Singh | 6 | 22.0 | 2 | 37 |
| 46 | Aditi Bhatt | 5 | 22.8 | 2 | 43 |
| 14 | Saurabh Dubey | 4 | 23.0 | 4 | 47 |
| 1 | Aarav Sharma | 8 | 23.3 | 4 | 61 |
| 2 | Rohan Mehta | 8 | 23.3 | 4 | 53 |
| 7 | Karan Malhotra | 5 | 24.5 | 8 | 37 |
| 26 | Ananya Iyer | 8 | 24.9 | 4 | 66 |
| 19 | Imran Qureshi | 8 | 25.0 | 2 | 46 |
| 25 | Kunal Bose | 8 | 25.4 | 8 | 58 |
| 34 | Priya Nair | 7 | 27.0 | 1 | 112 |
| 16 | Shreya Das | 5 | 27.3 | 3 | 85 |
| 27 | Tanvi Shah | 7 | 28.5 | 2 | 118 |
| 18 | Payal Ghosh | 7 | 29.3 | 5 | 71 |
| 23 | Neha Kulkarni | 3 | 29.5 | 28 | 31 |
| 29 | Manish Yadav | 7 | 30.7 | 3 | 135 |
| 28 | Sakshi Mittal | 4 | 38.3 | 3 | 83 |
| 13 | Harsh Agarwal | 5 | 38.8 | 10 | 102 |
| 35 | Tushar Naidu | 4 | 42.3 | 1 | 78 |
| 5 | Sneha Patil | 3 | 59.5 | 3 | 116 |
| 8 | Nikhil Jain | 3 | 64.0 | 52 | 76 |
| 20 | Sam Fernandes | 3 | 64.5 | 55 | 74 |

## W9 SUM OVER () and PERCENT_RANK - product share of sales (top 15)

```sql
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
       

       ROUND(PERCENT_RANK() OVER (ORDER BY gross_value), 3)             AS pct_rank,
       ROUND(CUME_DIST()    OVER (ORDER BY gross_value), 3)             AS cumulative_dist
FROM   product_value
ORDER  BY gross_value DESC
LIMIT  15
```

**Rows returned:** 15

| product_name | gross_value | share_pct | cumulative_pct | pct_rank | cumulative_dist |
|---|---|---|---|---|---|
| OnePlus 12R (8GB/128GB) | 519987.00 | 18.19 | 18.2 | 1.0 | 1.0 |
| Apple iPhone 15 (128GB) | 431994.00 | 15.11 | 33.3 | 0.973 | 0.974 |
| Redmi Note 13 Pro 5G | 325987.00 | 11.40 | 44.7 | 0.946 | 0.947 |
| HP Pavilion 15 Laptop (i5) | 251960.00 | 8.81 | 53.5 | 0.919 | 0.921 |
| Lenovo IdeaPad Slim 3 (Ryzen 5) | 229950.00 | 8.04 | 61.6 | 0.892 | 0.895 |
| Samsung Galaxy S24 (8GB/256GB) | 224997.00 | 7.87 | 69.4 | 0.865 | 0.868 |
| boAt Airdopes 141 | 94827.00 | 3.32 | 72.7 | 0.838 | 0.842 |
| Sony WH-1000XM5 Headphones | 89970.00 | 3.15 | 75.9 | 0.811 | 0.816 |
| JBL Tune 760NC Headphones | 71988.00 | 2.52 | 78.4 | 0.784 | 0.789 |
| Logitech MX Master 3S Mouse | 53970.00 | 1.89 | 80.3 | 0.757 | 0.763 |
| HP M24f 24-inch FHD Monitor | 41996.00 | 1.47 | 81.8 | 0.73 | 0.737 |
| ASUS Vivobook 15 (i3) | 38990.00 | 1.36 | 83.1 | 0.703 | 0.711 |
| Spigen Rugged Armor Phone Case | 33263.00 | 1.16 | 84.3 | 0.676 | 0.684 |
| Biba Cotton Straight Kurta | 31176.00 | 1.09 | 85.4 | 0.649 | 0.658 |
| OnePlus Nord Buds 2 | 30287.00 | 1.06 | 86.4 | 0.622 | 0.632 |

## T1 CTE + RANK - top product of each month

```sql
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
ORDER  BY month, product_name
```

**Rows returned:** 7

| month | product_name | units_sold | gross_value |
|---|---|---|---|
| 2026-05 | boAt Airdopes 141 | 8 | 10392.00 |
| 2026-06 | Roadster Graphic Print T-Shirt | 7 | 3143.00 |
| 2026-07 | boAt Airdopes 141 | 8 | 10392.00 |
| 2026-08 | boAt Airdopes 141 | 21 | 27279.00 |
| 2026-09 | boAt Airdopes 141 | 11 | 14289.00 |
| 2026-10 | boAt Airdopes 141 | 11 | 14289.00 |
| 2026-11 | boAt Airdopes 141 | 9 | 11691.00 |

## T2 CTE - cohorts by first-order month and how many came back

```sql
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
ORDER  BY cohort_month
```

**Rows returned:** 7

| cohort_month | new_customers | came_back | came_back_pct |
|---|---|---|---|
| 2026-05 | 20 | 20 | 100.0 |
| 2026-06 | 6 | 5 | 83.3 |
| 2026-07 | 7 | 6 | 85.7 |
| 2026-08 | 7 | 3 | 42.9 |
| 2026-09 | 2 | 0 | 0.0 |
| 2026-10 | 1 | 0 | 0.0 |
| 2026-11 | 1 | 0 | 0.0 |

## T3 CTE referenced twice - months above the average monthly revenue

```sql
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
ORDER  BY month
```

**Rows returned:** 3

| month | revenue |
|---|---|
| 2026-05 | 480445.40 |
| 2026-08 | 725777.05 |
| 2026-10 | 620137.30 |

## R1 WITH RECURSIVE - full category tree

```sql
WITH RECURSIVE category_tree AS (
    

    SELECT category_id,
           category_name,
           parent_category_id,
           1                               AS level,
           CAST(category_name AS CHAR(255)) AS path
    FROM   categories
    WHERE  parent_category_id IS NULL
    UNION ALL
    

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
ORDER  BY path
```

**Rows returned:** 23

| category_id | indented_name | level | path |
|---|---|---|---|
| 21 | Books | 1 | Books |
| 22 |     Fiction | 2 | Books > Fiction |
| 23 |     Non-Fiction | 2 | Books > Non-Fiction |
| 1 | Electronics | 1 | Electronics |
| 5 |     Audio | 2 | Electronics > Audio |
| 6 |         Earbuds | 3 | Electronics > Audio > Earbuds |
| 7 |         Headphones | 3 | Electronics > Audio > Headphones |
| 8 |     Computers | 2 | Electronics > Computers |
| 10 |         Computer Accessories | 3 | Electronics > Computers > Computer Accessories |
| 9 |         Laptops | 3 | Electronics > Computers > Laptops |
| 2 |     Mobiles | 2 | Electronics > Mobiles |
| 4 |         Mobile Accessories | 3 | Electronics > Mobiles > Mobile Accessories |
| 3 |         Smartphones | 3 | Electronics > Mobiles > Smartphones |
| 11 | Fashion | 1 | Fashion |
| 16 |     Footwear | 2 | Fashion > Footwear |
| 17 |         Sports Shoes | 3 | Fashion > Footwear > Sports Shoes |
| 12 |     Men | 2 | Fashion > Men |
| 13 |         Men's T-Shirts | 3 | Fashion > Men > Men's T-Shirts |
| 14 |     Women | 2 | Fashion > Women |
| 15 |         Women's Kurtas | 3 | Fashion > Women > Women's Kurtas |
| 18 | Home & Kitchen | 1 | Home & Kitchen |
| 20 |     Home Decor | 2 | Home & Kitchen > Home Decor |
| 19 |     Kitchen Appliances | 2 | Home & Kitchen > Kitchen Appliances |

## R2 WITH RECURSIVE - sales rolled up to each top-level category

```sql
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
ORDER  BY revenue_rank
```

**Rows returned:** 4

| top_level_category | sub_categories | products_sold | units_sold | gross_value | revenue_rank |
|---|---|---|---|---|---|
| Electronics | 9 | 20 | 301 | 2564059.00 | 1 |
| Fashion | 6 | 9 | 134 | 171488.00 | 2 |
| Home & Kitchen | 2 | 5 | 60 | 91540.00 | 3 |
| Books | 2 | 4 | 95 | 32005.00 | 4 |

## R3 WITH RECURSIVE - referral chains from their original referrer

```sql
WITH RECURSIVE referral_chain AS (
    

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
ORDER  BY depth DESC, chain
```

**Rows returned:** 15

| chain_start | referral_level | chain |
|---|---|---|
| Arjun Reddy | 2 | Arjun Reddy -> Varun Kapoor -> Pooja Desai |
| Ananya Iyer | 1 | Ananya Iyer -> Tanvi Shah |
| Arjun Reddy | 1 | Arjun Reddy -> Payal Ghosh |
| Arjun Reddy | 1 | Arjun Reddy -> Varun Kapoor |
| Imran Qureshi | 1 | Imran Qureshi -> Gaurav Sinha |
| Jaspreet Gill | 1 | Jaspreet Gill -> Swati Chavan |
| Karan Malhotra | 1 | Karan Malhotra -> Harsh Agarwal |
| Mohit Bansal | 1 | Mohit Bansal -> Aman Choudhary |
| Rahul Joshi | 1 | Rahul Joshi -> Aditya Verma |
| Rahul Joshi | 1 | Rahul Joshi -> Kunal Bose |
| Riya Banerjee | 1 | Riya Banerjee -> Nikhil Jain |
| Rohan Mehta | 1 | Rohan Mehta -> Shreya Das |
| Sam Fernandes | 1 | Sam Fernandes -> Neha Kulkarni |
| Simran Kaur | 1 | Simran Kaur -> Vikram Singh |
| Yash Saxena | 1 | Yash Saxena -> Ritika Arora |
