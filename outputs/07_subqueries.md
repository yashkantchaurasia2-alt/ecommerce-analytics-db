# Results of `sql/07_subqueries.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## S1 IN - customers who bought an Apple product

```sql
SELECT customer_id, full_name
FROM   customers
WHERE  customer_id IN (
         SELECT o.customer_id
         FROM   orders o
         WHERE  o.order_id IN (
                  SELECT oi.order_id
                  FROM   order_items oi
                  WHERE  oi.product_id IN (SELECT product_id FROM products WHERE brand = 'Apple')))
ORDER  BY full_name
```

**Rows returned:** 9

| customer_id | full_name |
|---|---|
| 1 | Aarav Sharma |
| 32 | Aditya Verma |
| 26 | Ananya Iyer |
| 3 | Isha Gupta |
| 31 | Kritika Sood |
| 15 | Pooja Desai |
| 44 | Pranav Hegde |
| 35 | Tushar Naidu |
| 39 | Yash Saxena |

## S2 NOT IN - active products with no sale in November

```sql
SELECT product_id, sku, product_name
FROM   products
WHERE  is_active = TRUE
  AND  product_id NOT IN (
         SELECT oi.product_id
         FROM   order_items oi
         WHERE  oi.order_id IN (SELECT order_id FROM orders
                                WHERE  order_date >= '2026-11-01'))
ORDER  BY product_id
```

**Rows returned:** 18

| product_id | sku | product_name |
|---|---|---|
| 1 | SAM-S24 | Samsung Galaxy S24 (8GB/256GB) |
| 4 | RDM-N13P | Redmi Note 13 Pro 5G |
| 5 | BOAT-PB20K | boAt 20000mAh Power Bank |
| 7 | SAM-CHG25 | Samsung 25W Type-C Charger |
| 11 | APL-APP2 | Apple AirPods Pro (2nd Gen) |
| 12 | SNY-XM5 | Sony WH-1000XM5 Headphones |
| 14 | BOAT-RK450 | boAt Rockerz 450 Headphones |
| 17 | APL-MBA-M3 | Apple MacBook Air M3 13-inch |
| 18 | ASU-VB15 | ASUS Vivobook 15 (i3) |
| 21 | HP-M24 | HP M24f 24-inch FHD Monitor |
| 24 | RDS-GTEE | Roadster Graphic Print T-Shirt |
| 26 | W-PKRT | W Printed A-Line Kurta |
| 27 | LBS-ANK | Libas Anarkali Kurta Set |
| 28 | NKE-REV6 | Nike Revolution 6 Running Shoes |
| 30 | CMP-RUN | Campus North Plus Running Shoes |
| 32 | PHL-MXR | Philips HL7756 Mixer Grinder |
| 34 | BJJ-OTG | Bajaj 1603T 16L OTG |
| 35 | AJT-CLK | Ajanta Quartz Wall Clock |

## S3 scalar subquery - products above the overall average price

```sql
SELECT product_id, product_name, price
FROM   products
WHERE  price > (SELECT AVG(price) FROM products)
ORDER  BY price DESC
```

**Rows returned:** 10

| product_id | product_name | price |
|---|---|---|
| 17 | Apple MacBook Air M3 13-inch | 114900.00 |
| 1 | Samsung Galaxy S24 (8GB/256GB) | 74999.00 |
| 2 | Apple iPhone 15 (128GB) | 69999.00 |
| 15 | HP Pavilion 15 Laptop (i5) | 62990.00 |
| 16 | Lenovo IdeaPad Slim 3 (Ryzen 5) | 45990.00 |
| 3 | OnePlus 12R (8GB/128GB) | 39999.00 |
| 18 | ASUS Vivobook 15 (i3) | 38990.00 |
| 12 | Sony WH-1000XM5 Headphones | 29990.00 |
| 11 | Apple AirPods Pro (2nd Gen) | 24900.00 |
| 4 | Redmi Note 13 Pro 5G | 23999.00 |

## S4 scalar subquery in SELECT - price vs catalogue average

```sql
SELECT product_name,
       price,
       ROUND((SELECT AVG(price) FROM products), 2)         AS catalogue_avg,
       ROUND(price - (SELECT AVG(price) FROM products), 2) AS diff_from_avg
FROM   products
ORDER  BY diff_from_avg DESC
```

**Rows returned:** 40

| product_name | price | catalogue_avg | diff_from_avg |
|---|---|---|---|
| Apple MacBook Air M3 13-inch | 114900.00 | 14779.58 | 100120.43 |
| Samsung Galaxy S24 (8GB/256GB) | 74999.00 | 14779.58 | 60219.43 |
| Apple iPhone 15 (128GB) | 69999.00 | 14779.58 | 55219.43 |
| HP Pavilion 15 Laptop (i5) | 62990.00 | 14779.58 | 48210.43 |
| Lenovo IdeaPad Slim 3 (Ryzen 5) | 45990.00 | 14779.58 | 31210.43 |
| OnePlus 12R (8GB/128GB) | 39999.00 | 14779.58 | 25219.43 |
| ASUS Vivobook 15 (i3) | 38990.00 | 14779.58 | 24210.43 |
| Sony WH-1000XM5 Headphones | 29990.00 | 14779.58 | 15210.43 |
| Apple AirPods Pro (2nd Gen) | 24900.00 | 14779.58 | 10120.43 |
| Redmi Note 13 Pro 5G | 23999.00 | 14779.58 | 9219.43 |
| HP M24f 24-inch FHD Monitor | 10499.00 | 14779.58 | -4280.58 |
| Logitech MX Master 3S Mouse | 8995.00 | 14779.58 | -5784.58 |
| JBL Tune 760NC Headphones | 5999.00 | 14779.58 | -8780.58 |
| Bajaj 1603T 16L OTG | 5499.00 | 14779.58 | -9280.58 |
| Nike Revolution 6 Running Shoes | 3695.00 | 14779.58 | -11084.58 |
| Philips HL7756 Mixer Grinder | 3499.00 | 14779.58 | -11280.58 |
| Puma Softride Running Shoes | 2999.00 | 14779.58 | -11780.58 |
| Prestige PIC 20 Induction Cooktop | 2299.00 | 14779.58 | -12480.58 |
| OnePlus Nord Buds 2 | 2299.00 | 14779.58 | -12480.58 |
| Libas Anarkali Kurta Set | 1599.00 | 14779.58 | -13180.58 |
| boAt Rockerz 450 Headphones | 1574.00 | 14779.58 | -13205.58 |
| boAt 20000mAh Power Bank | 1574.00 | 14779.58 | -13205.58 |
| boAt Airdopes 141 | 1364.00 | 14779.58 | -13415.58 |
| Samsung 25W Type-C Charger | 1299.00 | 14779.58 | -13480.58 |
| Campus North Plus Running Shoes | 1299.00 | 14779.58 | -13480.58 |
| Biba Cotton Straight Kurta | 1299.00 | 14779.58 | -13480.58 |
| W Printed A-Line Kurta | 1099.00 | 14779.58 | -13680.58 |
| Allen Solly Men's Polo T-Shirt | 899.00 | 14779.58 | -13880.58 |
| SanDisk Ultra 128GB Pendrive | 899.00 | 14779.58 | -13880.58 |
| Spigen Rugged Armor Phone Case | 899.00 | 14779.58 | -13880.58 |
| U.S. Polo Assn. Crew Neck Tee | 799.00 | 14779.58 | -13980.58 |
| Ajanta Quartz Wall Clock | 799.00 | 14779.58 | -13980.58 |
| Pigeon 1.5L Electric Kettle | 699.00 | 14779.58 | -14080.58 |
| Home Sizzler Cushion Covers (Set of 5) | 499.00 | 14779.58 | -14280.58 |
| Roadster Graphic Print T-Shirt | 449.00 | 14779.58 | -14330.58 |
| Atomic Habits | 399.00 | 14779.58 | -14380.58 |
| The Palace of Illusions | 349.00 | 14779.58 | -14430.58 |
| Portronics Konnect USB-C Cable | 299.00 | 14779.58 | -14480.58 |
| Ikigai | 299.00 | 14779.58 | -14480.58 |
| Wings of Fire | 249.00 | 14779.58 | -14530.58 |

## S5 multi-level nesting - customers of the best-selling category

```sql
SELECT customer_id, full_name
FROM   customers
WHERE  customer_id IN (
         SELECT customer_id FROM orders
         WHERE  order_id IN (
                  SELECT order_id FROM order_items
                  WHERE  product_id IN (
                           SELECT product_id FROM products
                           WHERE  category_id = (
                                    SELECT category_id
                                    FROM  (SELECT p.category_id, SUM(oi.quantity) AS units
                                           FROM   order_items oi
                                           JOIN   products p ON p.product_id = oi.product_id
                                           GROUP  BY p.category_id
                                           ORDER  BY units DESC
                                           LIMIT  1) AS best))))
ORDER  BY full_name
```

**Rows returned:** 32

| customer_id | full_name |
|---|---|
| 1 | Aarav Sharma |
| 46 | Aditi Bhatt |
| 32 | Aditya Verma |
| 36 | Alok Tripathi |
| 40 | Aman Choudhary |
| 26 | Ananya Iyer |
| 41 | Anjali Tiwari |
| 11 | Arjun Reddy |
| 9 | Bhavna Rathore |
| 43 | Fatima Sheikh |
| 13 | Harsh Agarwal |
| 19 | Imran Qureshi |
| 3 | Isha Gupta |
| 31 | Kritika Sood |
| 25 | Kunal Bose |
| 29 | Manish Yadav |
| 22 | Meera Pillai |
| 23 | Neha Kulkarni |
| 18 | Payal Ghosh |
| 15 | Pooja Desai |
| 44 | Pranav Hegde |
| 34 | Priya Nair |
| 2 | Rohan Mehta |
| 28 | Sakshi Mittal |
| 20 | Sam Fernandes |
| 14 | Saurabh Dubey |
| 16 | Shreya Das |
| 33 | Siddharth Rao |
| 4 | Simran Kaur |
| 27 | Tanvi Shah |
| 12 | Varun Kapoor |
| 39 | Yash Saxena |

## S6a ALL - products costlier than every book

```sql
SELECT product_name, price
FROM   products
WHERE  price > ALL (SELECT p.price
                    FROM   products p
                    WHERE  p.category_id IN (SELECT category_id FROM categories
                                             WHERE  parent_category_id =
                                                    (SELECT category_id FROM categories
                                                     WHERE  category_name = 'Books')))
ORDER  BY price
LIMIT  10
```

**Rows returned:** 10

| product_name | price |
|---|---|
| Roadster Graphic Print T-Shirt | 449.00 |
| Home Sizzler Cushion Covers (Set of 5) | 499.00 |
| Pigeon 1.5L Electric Kettle | 699.00 |
| Ajanta Quartz Wall Clock | 799.00 |
| U.S. Polo Assn. Crew Neck Tee | 799.00 |
| Allen Solly Men's Polo T-Shirt | 899.00 |
| Spigen Rugged Armor Phone Case | 899.00 |
| SanDisk Ultra 128GB Pendrive | 899.00 |
| W Printed A-Line Kurta | 1099.00 |
| Campus North Plus Running Shoes | 1299.00 |

## S6b ANY - non-book products cheaper than at least one book

```sql
SELECT product_name, price
FROM   products
WHERE  category_id NOT IN (22, 23)
  AND  price < ANY (SELECT price FROM products WHERE category_id IN (22, 23))
ORDER  BY price
```

**Rows returned:** 1

| product_name | price |
|---|---|
| Portronics Konnect USB-C Cable | 299.00 |

## S7 correlated - products above their category average

```sql
SELECT p.product_name,
       p.category_id,
       p.price,
       (SELECT ROUND(AVG(p2.price), 2)
        FROM   products p2
        WHERE  p2.category_id = p.category_id) AS category_avg
FROM   products p
WHERE  p.price > (SELECT AVG(p2.price)
                  FROM   products p2
                  WHERE  p2.category_id = p.category_id)
ORDER  BY p.category_id, p.price DESC
```

**Rows returned:** 18

| product_name | category_id | price | category_avg |
|---|---|---|---|
| Samsung Galaxy S24 (8GB/256GB) | 3 | 74999.00 | 52249.00 |
| Apple iPhone 15 (128GB) | 3 | 69999.00 | 52249.00 |
| boAt 20000mAh Power Bank | 4 | 1574.00 | 1017.75 |
| Samsung 25W Type-C Charger | 4 | 1299.00 | 1017.75 |
| Apple AirPods Pro (2nd Gen) | 6 | 24900.00 | 9521.00 |
| Sony WH-1000XM5 Headphones | 7 | 29990.00 | 12521.00 |
| Apple MacBook Air M3 13-inch | 9 | 114900.00 | 65717.50 |
| HP M24f 24-inch FHD Monitor | 10 | 10499.00 | 6797.67 |
| Logitech MX Master 3S Mouse | 10 | 8995.00 | 6797.67 |
| Allen Solly Men's Polo T-Shirt | 13 | 899.00 | 715.67 |
| U.S. Polo Assn. Crew Neck Tee | 13 | 799.00 | 715.67 |
| Libas Anarkali Kurta Set | 15 | 1599.00 | 1332.33 |
| Nike Revolution 6 Running Shoes | 17 | 3695.00 | 2664.33 |
| Puma Softride Running Shoes | 17 | 2999.00 | 2664.33 |
| Bajaj 1603T 16L OTG | 19 | 5499.00 | 2999.00 |
| Philips HL7756 Mixer Grinder | 19 | 3499.00 | 2999.00 |
| Ajanta Quartz Wall Clock | 20 | 799.00 | 649.00 |
| Atomic Habits | 23 | 399.00 | 315.67 |

## S8 correlated - each customer's latest order

```sql
SELECT c.customer_id,
       c.full_name,
       o.order_id,
       o.order_date,
       o.status
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
WHERE  o.order_date = (SELECT MAX(o2.order_date)
                       FROM   orders o2
                       WHERE  o2.customer_id = o.customer_id)
ORDER  BY o.order_date DESC
```

**Rows returned:** 44

| customer_id | full_name | order_id | order_date | status |
|---|---|---|---|---|
| 3 | Isha Gupta | 1281 | 2026-11-20 12:00:00 | CONFIRMED |
| 12 | Varun Kapoor | 1280 | 2026-11-20 10:45:00 | CONFIRMED |
| 47 | Kavya Menon | 1276 | 2026-11-19 23:04:46 | CANCELLED |
| 19 | Imran Qureshi | 1275 | 2026-11-19 10:37:55 | SHIPPED |
| 16 | Shreya Das | 1274 | 2026-11-17 23:00:23 | CONFIRMED |
| 46 | Aditi Bhatt | 1273 | 2026-11-17 19:07:03 | CONFIRMED |
| 32 | Aditya Verma | 1272 | 2026-11-16 22:21:44 | SHIPPED |
| 15 | Pooja Desai | 1269 | 2026-11-14 22:10:22 | SHIPPED |
| 25 | Kunal Bose | 1268 | 2026-11-11 13:23:30 | DELIVERED |
| 29 | Manish Yadav | 1267 | 2026-11-11 08:27:29 | SHIPPED |
| 41 | Anjali Tiwari | 1266 | 2026-11-10 11:58:18 | SHIPPED |
| 31 | Kritika Sood | 1265 | 2026-11-09 21:18:27 | PLACED |
| 9 | Bhavna Rathore | 1264 | 2026-11-09 20:33:14 | DELIVERED |
| 2 | Rohan Mehta | 1263 | 2026-11-09 12:36:55 | DELIVERED |
| 13 | Harsh Agarwal | 1262 | 2026-11-08 11:03:26 | CONFIRMED |
| 11 | Arjun Reddy | 1261 | 2026-11-07 08:06:15 | DELIVERED |
| 5 | Sneha Patil | 1259 | 2026-11-06 21:30:18 | DELIVERED |
| 39 | Yash Saxena | 1254 | 2026-11-04 22:30:01 | DELIVERED |
| 21 | Vikram Singh | 1247 | 2026-10-31 09:04:29 | DELIVERED |
| 26 | Ananya Iyer | 1245 | 2026-10-30 11:13:19 | DELIVERED |
| 36 | Alok Tripathi | 1244 | 2026-10-29 20:54:04 | DELIVERED |
| 18 | Payal Ghosh | 1243 | 2026-10-29 16:00:13 | DELIVERED |
| 7 | Karan Malhotra | 1241 | 2026-10-26 17:45:48 | DELIVERED |
| 27 | Tanvi Shah | 1235 | 2026-10-21 23:59:43 | DELIVERED |
| 43 | Fatima Sheikh | 1234 | 2026-10-20 12:45:46 | CANCELLED |
| 1 | Aarav Sharma | 1227 | 2026-10-15 13:29:05 | DELIVERED |
| 28 | Sakshi Mittal | 1226 | 2026-10-14 18:55:23 | DELIVERED |
| 44 | Pranav Hegde | 1222 | 2026-10-11 22:00:19 | DELIVERED |
| 34 | Priya Nair | 1216 | 2026-10-10 12:01:01 | DELIVERED |
| 14 | Saurabh Dubey | 1215 | 2026-10-10 10:36:49 | DELIVERED |
| 8 | Nikhil Jain | 1195 | 2026-10-01 18:41:34 | DELIVERED |
| 42 | Nisha Thakur | 1190 | 2026-09-28 22:12:16 | CANCELLED |
| 33 | Siddharth Rao | 1183 | 2026-09-21 08:47:35 | DELIVERED |
| 20 | Sam Fernandes | 1182 | 2026-09-20 22:12:59 | DELIVERED |
| 35 | Tushar Naidu | 1172 | 2026-09-13 11:57:26 | DELIVERED |
| 45 | Deepak Pandey | 1164 | 2026-09-09 14:16:14 | CANCELLED |
| 30 | Gaurav Sinha | 1148 | 2026-08-26 08:07:02 | CANCELLED |
| 4 | Simran Kaur | 1143 | 2026-08-22 10:54:24 | DELIVERED |
| 38 | Mohit Bansal | 1141 | 2026-08-21 10:05:00 | DELIVERED |
| 10 | Rahul Joshi | 1112 | 2026-08-08 19:54:51 | CANCELLED |
| 23 | Neha Kulkarni | 1082 | 2026-07-17 11:52:34 | DELIVERED |
| 40 | Aman Choudhary | 1081 | 2026-07-15 23:43:55 | DELIVERED |
| 37 | Abhishek Mishra | 1048 | 2026-06-17 17:25:15 | DELIVERED |
| 22 | Meera Pillai | 1042 | 2026-06-10 17:01:56 | DELIVERED |

## S9 correlated in SELECT - orders and spend per customer (top 15)

```sql
SELECT c.customer_id,
       c.full_name,
       (SELECT COUNT(*)
        FROM   orders o
        WHERE  o.customer_id = c.customer_id) AS orders_placed,
       (SELECT COALESCE(SUM(p.amount), 0)
        FROM   payments p
        JOIN   orders o ON o.order_id = p.order_id
        WHERE  o.customer_id = c.customer_id
          AND  p.status = 'SUCCESS'
          AND  o.status <> 'CANCELLED') AS total_spend
FROM   customers c
ORDER  BY total_spend DESC, c.customer_id
LIMIT  15
```

**Rows returned:** 15

| customer_id | full_name | orders_placed | total_spend |
|---|---|---|---|
| 26 | Ananya Iyer | 8 | 292528.30 |
| 32 | Aditya Verma | 16 | 266380.90 |
| 39 | Yash Saxena | 15 | 175082.05 |
| 44 | Pranav Hegde | 16 | 169193.20 |
| 1 | Aarav Sharma | 8 | 167434.60 |
| 27 | Tanvi Shah | 7 | 161605.10 |
| 3 | Isha Gupta | 17 | 145357.00 |
| 11 | Arjun Reddy | 8 | 141201.00 |
| 15 | Pooja Desai | 12 | 126581.40 |
| 12 | Varun Kapoor | 13 | 121792.95 |
| 9 | Bhavna Rathore | 13 | 114214.30 |
| 46 | Aditi Bhatt | 5 | 113910.20 |
| 31 | Kritika Sood | 8 | 82436.00 |
| 41 | Anjali Tiwari | 9 | 72657.50 |
| 33 | Siddharth Rao | 7 | 69655.30 |

## S10 correlated - orders above the customer's own average

```sql
SELECT o.order_id,
       o.customer_id,
       (SELECT SUM(oi.quantity * oi.unit_price)
        FROM   order_items oi
        WHERE  oi.order_id = o.order_id) AS order_value,
       ROUND((SELECT SUM(oi2.quantity * oi2.unit_price)
              FROM   order_items oi2
              JOIN   orders o2 ON o2.order_id = oi2.order_id
              WHERE  o2.customer_id = o.customer_id)
           / (SELECT COUNT(*) FROM orders o3 WHERE o3.customer_id = o.customer_id), 2)
                                         AS customer_avg
FROM   orders o
WHERE  (SELECT SUM(oi.quantity * oi.unit_price)
        FROM   order_items oi
        WHERE  oi.order_id = o.order_id)
     > (SELECT SUM(oi2.quantity * oi2.unit_price)
        FROM   order_items oi2
        JOIN   orders o2 ON o2.order_id = oi2.order_id
        WHERE  o2.customer_id = o.customer_id)
     / (SELECT COUNT(*) FROM orders o3 WHERE o3.customer_id = o.customer_id)
ORDER  BY o.customer_id, o.order_id
```

**Rows returned:** 76 (showing first 60)

| order_id | customer_id | order_value | customer_avg |
|---|---|---|---|
| 1063 | 1 | 47489.00 | 24657.75 |
| 1066 | 1 | 24900.00 | 24657.75 |
| 1107 | 1 | 103238.00 | 24657.75 |
| 1095 | 2 | 3499.00 | 2341.25 |
| 1106 | 2 | 4396.00 | 2341.25 |
| 1263 | 2 | 3897.00 | 2341.25 |
| 1002 | 3 | 74897.00 | 13194.18 |
| 1064 | 3 | 40597.00 | 13194.18 |
| 1067 | 3 | 62990.00 | 13194.18 |
| 1253 | 5 | 45990.00 | 16629.00 |
| 1241 | 7 | 39999.00 | 10958.40 |
| 1029 | 8 | 29197.00 | 18198.00 |
| 1195 | 8 | 23999.00 | 18198.00 |
| 1123 | 9 | 39999.00 | 8962.31 |
| 1203 | 9 | 39439.00 | 8962.31 |
| 1068 | 11 | 25999.00 | 19135.00 |
| 1138 | 11 | 70196.00 | 19135.00 |
| 1196 | 11 | 43296.00 | 19135.00 |
| 1019 | 12 | 40448.00 | 9501.31 |
| 1030 | 12 | 36592.00 | 9501.31 |
| 1229 | 12 | 10796.00 | 9501.31 |
| 1071 | 13 | 8394.00 | 2617.60 |
| 1102 | 14 | 3597.00 | 2623.00 |
| 1215 | 14 | 3798.00 | 2623.00 |
| 1033 | 15 | 33489.00 | 10675.83 |
| 1197 | 15 | 71298.00 | 10675.83 |
| 1105 | 16 | 4196.00 | 2018.00 |
| 1109 | 16 | 3897.00 | 2018.00 |
| 1045 | 18 | 29990.00 | 7695.86 |
| 1056 | 18 | 10593.00 | 7695.86 |
| 1201 | 19 | 39999.00 | 7915.75 |
| 1017 | 20 | 5999.00 | 4581.33 |
| 1072 | 20 | 7147.00 | 4581.33 |
| 1151 | 21 | 5596.00 | 2356.17 |
| 1186 | 21 | 2598.00 | 2356.17 |
| 1042 | 22 | 9396.00 | 4916.60 |
| 1022 | 23 | 3695.00 | 2862.67 |
| 1082 | 23 | 3594.00 | 2862.67 |
| 1111 | 25 | 41498.00 | 6723.63 |
| 1012 | 26 | 73898.00 | 37096.63 |
| 1125 | 26 | 40398.00 | 37096.63 |
| 1136 | 26 | 121587.00 | 37096.63 |
| 1010 | 27 | 80193.00 | 23105.00 |
| 1228 | 27 | 74999.00 | 23105.00 |
| 1054 | 28 | 4396.00 | 3871.50 |
| 1176 | 28 | 4796.00 | 3871.50 |
| 1226 | 28 | 5096.00 | 3871.50 |
| 1013 | 29 | 4196.00 | 2690.14 |
| 1224 | 29 | 2946.00 | 2690.14 |
| 1237 | 29 | 5896.00 | 2690.14 |
| 1267 | 29 | 2999.00 | 2690.14 |
| 1260 | 31 | 70898.00 | 11816.25 |
| 1021 | 32 | 100345.00 | 16802.44 |
| 1211 | 32 | 44593.00 | 16802.44 |
| 1213 | 32 | 27296.00 | 16802.44 |
| 1250 | 32 | 66288.00 | 16802.44 |
| 1077 | 33 | 27996.00 | 10810.57 |
| 1165 | 33 | 28595.00 | 10810.57 |
| 1006 | 34 | 5596.00 | 3661.14 |
| 1016 | 34 | 6593.00 | 3661.14 |

## S11 EXISTS - customers with at least one failed payment

```sql
SELECT c.customer_id, c.full_name
FROM   customers c
WHERE  EXISTS (SELECT 1
               FROM   orders o
               JOIN   payments p ON p.order_id = o.order_id
               WHERE  o.customer_id = c.customer_id
                 AND  p.status = 'FAILED')
ORDER  BY c.full_name
```

**Rows returned:** 26

| customer_id | full_name |
|---|---|
| 1 | Aarav Sharma |
| 32 | Aditya Verma |
| 41 | Anjali Tiwari |
| 11 | Arjun Reddy |
| 9 | Bhavna Rathore |
| 45 | Deepak Pandey |
| 43 | Fatima Sheikh |
| 30 | Gaurav Sinha |
| 13 | Harsh Agarwal |
| 19 | Imran Qureshi |
| 3 | Isha Gupta |
| 7 | Karan Malhotra |
| 47 | Kavya Menon |
| 31 | Kritika Sood |
| 29 | Manish Yadav |
| 23 | Neha Kulkarni |
| 42 | Nisha Thakur |
| 18 | Payal Ghosh |
| 15 | Pooja Desai |
| 44 | Pranav Hegde |
| 34 | Priya Nair |
| 2 | Rohan Mehta |
| 14 | Saurabh Dubey |
| 12 | Varun Kapoor |
| 21 | Vikram Singh |
| 39 | Yash Saxena |

## S12 NOT EXISTS - customers who never ordered

```sql
SELECT c.customer_id, c.full_name, c.signup_date
FROM   customers c
WHERE  NOT EXISTS (SELECT 1
                   FROM   orders o
                   WHERE  o.customer_id = c.customer_id)
ORDER  BY c.signup_date
```

**Rows returned:** 6

| customer_id | full_name | signup_date |
|---|---|---|
| 6 | Riya Banerjee | 2025-04-06 |
| 17 | Jaspreet Gill | 2025-10-26 |
| 24 | Divya Krishnan | 2025-12-27 |
| 48 | Lakshmi Subramanian | 2026-08-28 |
| 49 | Ritika Arora | 2026-09-12 |
| 50 | Swati Chavan | 2026-09-25 |

## S13 derived tables - customer segments by average order value

```sql
SELECT segment,
       COUNT(*)                         AS customers,
       ROUND(AVG(avg_order_value), 2)   AS avg_order_value
FROM  (SELECT customer_id,
              AVG(order_value) AS avg_order_value,
              CASE
                  WHEN AVG(order_value) >= 20000 THEN 'High'
                  WHEN AVG(order_value) >= 5000  THEN 'Medium'
                  ELSE 'Low'
              END AS segment
       FROM  (SELECT o.customer_id,
                     o.order_id,
                     SUM(oi.quantity * oi.unit_price) AS order_value
              FROM   orders o
              JOIN   order_items oi ON oi.order_id = o.order_id
              GROUP  BY o.customer_id, o.order_id) AS per_order
       GROUP  BY customer_id) AS per_customer
GROUP  BY segment
ORDER  BY avg_order_value DESC
```

**Rows returned:** 3

| segment | customers | avg_order_value |
|---|---|---|
| High | 4 | 29303.09 |
| Medium | 20 | 11634.79 |
| Low | 20 | 2771.04 |

## S14 derived table - months above the average monthly revenue

```sql
SELECT m.month,
       m.revenue
FROM  (SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
              SUM(p.amount)                      AS revenue
       FROM   orders o
       JOIN   payments p ON p.order_id = o.order_id
       WHERE  p.status = 'SUCCESS' AND o.status <> 'CANCELLED'
       GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')) AS m
WHERE  m.revenue > (SELECT AVG(m2.revenue)
                    FROM  (SELECT SUM(p.amount) AS revenue
                           FROM   orders o
                           JOIN   payments p ON p.order_id = o.order_id
                           WHERE  p.status = 'SUCCESS' AND o.status <> 'CANCELLED'
                           GROUP  BY DATE_FORMAT(o.order_date, '%Y-%m')) AS m2)
ORDER  BY m.month
```

**Rows returned:** 3

| month | revenue |
|---|---|
| 2026-05 | 480445.40 |
| 2026-08 | 725777.05 |
| 2026-10 | 620137.30 |
