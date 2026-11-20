# Results of `sql/06_joins.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## J1 INNER JOIN - products with their category

```sql
SELECT p.product_id,
       p.product_name,
       c.category_name,
       p.price
FROM   products   p
INNER JOIN categories c ON c.category_id = p.category_id
ORDER  BY c.category_name, p.price DESC
```

**Rows returned:** 40

| product_id | product_name | category_name | price |
|---|---|---|---|
| 21 | HP M24f 24-inch FHD Monitor | Computer Accessories | 10499.00 |
| 19 | Logitech MX Master 3S Mouse | Computer Accessories | 8995.00 |
| 20 | SanDisk Ultra 128GB Pendrive | Computer Accessories | 899.00 |
| 11 | Apple AirPods Pro (2nd Gen) | Earbuds | 24900.00 |
| 10 | OnePlus Nord Buds 2 | Earbuds | 2299.00 |
| 9 | boAt Airdopes 141 | Earbuds | 1364.00 |
| 37 | The Palace of Illusions | Fiction | 349.00 |
| 12 | Sony WH-1000XM5 Headphones | Headphones | 29990.00 |
| 13 | JBL Tune 760NC Headphones | Headphones | 5999.00 |
| 14 | boAt Rockerz 450 Headphones | Headphones | 1574.00 |
| 35 | Ajanta Quartz Wall Clock | Home Decor | 799.00 |
| 36 | Home Sizzler Cushion Covers (Set of 5) | Home Decor | 499.00 |
| 34 | Bajaj 1603T 16L OTG | Kitchen Appliances | 5499.00 |
| 32 | Philips HL7756 Mixer Grinder | Kitchen Appliances | 3499.00 |
| 31 | Prestige PIC 20 Induction Cooktop | Kitchen Appliances | 2299.00 |
| 33 | Pigeon 1.5L Electric Kettle | Kitchen Appliances | 699.00 |
| 17 | Apple MacBook Air M3 13-inch | Laptops | 114900.00 |
| 15 | HP Pavilion 15 Laptop (i5) | Laptops | 62990.00 |
| 16 | Lenovo IdeaPad Slim 3 (Ryzen 5) | Laptops | 45990.00 |
| 18 | ASUS Vivobook 15 (i3) | Laptops | 38990.00 |
| 22 | Allen Solly Men's Polo T-Shirt | Men's T-Shirts | 899.00 |
| 23 | U.S. Polo Assn. Crew Neck Tee | Men's T-Shirts | 799.00 |
| 24 | Roadster Graphic Print T-Shirt | Men's T-Shirts | 449.00 |
| 5 | boAt 20000mAh Power Bank | Mobile Accessories | 1574.00 |
| 7 | Samsung 25W Type-C Charger | Mobile Accessories | 1299.00 |
| 6 | Spigen Rugged Armor Phone Case | Mobile Accessories | 899.00 |
| 8 | Portronics Konnect USB-C Cable | Mobile Accessories | 299.00 |
| 38 | Atomic Habits | Non-Fiction | 399.00 |
| 40 | Ikigai | Non-Fiction | 299.00 |
| 39 | Wings of Fire | Non-Fiction | 249.00 |
| 1 | Samsung Galaxy S24 (8GB/256GB) | Smartphones | 74999.00 |
| 2 | Apple iPhone 15 (128GB) | Smartphones | 69999.00 |
| 3 | OnePlus 12R (8GB/128GB) | Smartphones | 39999.00 |
| 4 | Redmi Note 13 Pro 5G | Smartphones | 23999.00 |
| 28 | Nike Revolution 6 Running Shoes | Sports Shoes | 3695.00 |
| 29 | Puma Softride Running Shoes | Sports Shoes | 2999.00 |
| 30 | Campus North Plus Running Shoes | Sports Shoes | 1299.00 |
| 27 | Libas Anarkali Kurta Set | Women's Kurtas | 1599.00 |
| 25 | Biba Cotton Straight Kurta | Women's Kurtas | 1299.00 |
| 26 | W Printed A-Line Kurta | Women's Kurtas | 1099.00 |

## J2 INNER JOIN - top 10 orders by value

```sql
SELECT o.order_id,
       DATE(o.order_date)                 AS order_day,
       c.full_name                        AS customer,
       COUNT(*)                           AS line_items,
       SUM(oi.quantity * oi.unit_price)   AS order_value
FROM   orders      o
INNER JOIN customers   c  ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON oi.order_id   = o.order_id
GROUP  BY o.order_id, o.order_date, c.full_name
ORDER  BY order_value DESC
LIMIT  10
```

**Rows returned:** 10

| order_id | order_day | customer | line_items | order_value |
|---|---|---|---|---|
| 1136 | 2026-08-20 | Ananya Iyer | 4 | 121587.00 |
| 1107 | 2026-08-07 | Aarav Sharma | 3 | 103238.00 |
| 1021 | 2026-05-18 | Aditya Verma | 3 | 100345.00 |
| 1178 | 2026-09-16 | Pranav Hegde | 3 | 95297.00 |
| 1010 | 2026-05-08 | Tanvi Shah | 3 | 80193.00 |
| 1153 | 2026-08-28 | Yash Saxena | 2 | 77997.00 |
| 1228 | 2026-10-15 | Tanvi Shah | 1 | 74999.00 |
| 1002 | 2026-05-02 | Isha Gupta | 3 | 74897.00 |
| 1012 | 2026-05-09 | Ananya Iyer | 2 | 73898.00 |
| 1044 | 2026-06-13 | Yash Saxena | 1 | 72999.00 |

## J3 LEFT JOIN - every customer with order count (zero included)

```sql
SELECT c.customer_id,
       c.full_name,
       c.signup_date,
       COUNT(o.order_id) AS orders_placed
FROM   customers c
LEFT OUTER JOIN orders o ON o.customer_id = c.customer_id
GROUP  BY c.customer_id, c.full_name, c.signup_date
ORDER  BY orders_placed, c.full_name
```

**Rows returned:** 50

| customer_id | full_name | signup_date | orders_placed |
|---|---|---|---|
| 24 | Divya Krishnan | 2025-12-27 | 0 |
| 17 | Jaspreet Gill | 2025-10-26 | 0 |
| 48 | Lakshmi Subramanian | 2026-08-28 | 0 |
| 49 | Ritika Arora | 2026-09-12 | 0 |
| 6 | Riya Banerjee | 2025-04-06 | 0 |
| 50 | Swati Chavan | 2026-09-25 | 0 |
| 37 | Abhishek Mishra | 2026-05-22 | 1 |
| 36 | Alok Tripathi | 2026-04-22 | 1 |
| 40 | Aman Choudhary | 2026-06-13 | 1 |
| 45 | Deepak Pandey | 2026-07-29 | 1 |
| 30 | Gaurav Sinha | 2026-02-17 | 1 |
| 47 | Kavya Menon | 2026-08-19 | 1 |
| 38 | Mohit Bansal | 2026-05-22 | 1 |
| 42 | Nisha Thakur | 2026-07-09 | 1 |
| 10 | Rahul Joshi | 2025-04-28 | 1 |
| 4 | Simran Kaur | 2025-03-24 | 1 |
| 23 | Neha Kulkarni | 2025-12-19 | 3 |
| 8 | Nikhil Jain | 2025-04-15 | 3 |
| 20 | Sam Fernandes | 2025-11-17 | 3 |
| 5 | Sneha Patil | 2025-03-28 | 3 |
| 28 | Sakshi Mittal | 2026-01-25 | 4 |
| 14 | Saurabh Dubey | 2025-08-21 | 4 |
| 35 | Tushar Naidu | 2026-04-18 | 4 |
| 46 | Aditi Bhatt | 2026-08-14 | 5 |
| 13 | Harsh Agarwal | 2025-08-08 | 5 |
| 7 | Karan Malhotra | 2025-04-07 | 5 |
| 22 | Meera Pillai | 2025-11-28 | 5 |
| 16 | Shreya Das | 2025-09-19 | 5 |
| 21 | Vikram Singh | 2025-11-22 | 6 |
| 29 | Manish Yadav | 2026-02-15 | 7 |
| 18 | Payal Ghosh | 2025-10-26 | 7 |
| 34 | Priya Nair | 2026-04-10 | 7 |
| 33 | Siddharth Rao | 2026-04-01 | 7 |
| 27 | Tanvi Shah | 2026-01-17 | 7 |
| 1 | Aarav Sharma | 2025-01-07 | 8 |
| 26 | Ananya Iyer | 2026-01-12 | 8 |
| 11 | Arjun Reddy | 2025-05-06 | 8 |
| 19 | Imran Qureshi | 2025-10-31 | 8 |
| 31 | Kritika Sood | 2026-03-11 | 8 |
| 25 | Kunal Bose | 2026-01-05 | 8 |
| 2 | Rohan Mehta | 2025-01-16 | 8 |
| 41 | Anjali Tiwari | 2026-06-14 | 9 |
| 43 | Fatima Sheikh | 2026-07-19 | 12 |
| 15 | Pooja Desai | 2025-09-07 | 12 |
| 9 | Bhavna Rathore | 2025-04-20 | 13 |
| 12 | Varun Kapoor | 2025-05-29 | 13 |
| 39 | Yash Saxena | 2026-06-03 | 15 |
| 32 | Aditya Verma | 2026-03-13 | 16 |
| 44 | Pranav Hegde | 2026-07-28 | 16 |
| 3 | Isha Gupta | 2025-01-30 | 17 |

## J4 LEFT JOIN IS NULL - products never sold

```sql
SELECT p.product_id,
       p.sku,
       p.product_name,
       p.price
FROM   products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE  oi.product_id IS NULL
ORDER  BY p.product_id
```

**Rows returned:** 2

| product_id | sku | product_name | price |
|---|---|---|---|
| 17 | APL-MBA-M3 | Apple MacBook Air M3 13-inch | 114900.00 |
| 35 | AJT-CLK | Ajanta Quartz Wall Clock | 799.00 |

## J5 RIGHT JOIN - every coupon with times used

```sql
SELECT d.code,
       d.discount_type,
       d.discount_value,
       COUNT(od.order_id)                AS times_used,
       COALESCE(SUM(od.amount_saved), 0) AS total_saved
FROM   order_discounts od
RIGHT OUTER JOIN discounts d ON d.discount_id = od.discount_id
GROUP  BY d.discount_id, d.code, d.discount_type, d.discount_value
ORDER  BY times_used DESC
```

**Rows returned:** 6

| code | discount_type | discount_value | times_used | total_saved |
|---|---|---|---|---|
| SAVE10 | PERCENT | 10.00 | 46 | 37373.30 |
| MONSOON15 | PERCENT | 15.00 | 12 | 12325.20 |
| FLAT500 | FLAT | 500.00 | 12 | 6000.00 |
| WELCOME100 | FLAT | 100.00 | 7 | 700.00 |
| FESTIVE20 | PERCENT | 20.00 | 1 | 4799.80 |
| SUMMER25 | PERCENT | 25.00 | 0 | 0.00 |

## J6 FULL OUTER JOIN (emulated) - customer cities vs warehouse cities

```sql
SELECT cc.city          AS customer_city,
       cc.customers,
       w.city           AS warehouse_city,
       w.warehouse_name
FROM   (SELECT city, COUNT(*) AS customers
        FROM   customer_addresses
        WHERE  is_default = TRUE
        GROUP  BY city) AS cc
LEFT JOIN warehouses w ON w.city = cc.city
UNION
SELECT cc.city,
       cc.customers,
       w.city,
       w.warehouse_name
FROM   (SELECT city, COUNT(*) AS customers
        FROM   customer_addresses
        WHERE  is_default = TRUE
        GROUP  BY city) AS cc
RIGHT JOIN warehouses w ON w.city = cc.city
ORDER  BY warehouse_city IS NULL, customer_city
```

**Rows returned:** 15

| customer_city | customers | warehouse_city | warehouse_name |
|---|---|---|---|
| NULL | NULL | Gurugram | Gurugram FC |
| Bengaluru | 9 | Bengaluru | Bengaluru FC |
| Mumbai | 3 | Mumbai | Bhiwandi FC |
| Ahmedabad | 4 | NULL | NULL |
| Chandigarh | 4 | NULL | NULL |
| Chennai | 3 | NULL | NULL |
| Delhi | 1 | NULL | NULL |
| Hyderabad | 1 | NULL | NULL |
| Indore | 3 | NULL | NULL |
| Jaipur | 4 | NULL | NULL |
| Kochi | 8 | NULL | NULL |
| Kolkata | 2 | NULL | NULL |
| Lucknow | 2 | NULL | NULL |
| Patna | 4 | NULL | NULL |
| Pune | 2 | NULL | NULL |

## J7 SELF JOIN - category and its parent

```sql
SELECT child.category_id,
       child.category_name,
       parent.category_name AS parent_category
FROM   categories child
LEFT JOIN categories parent ON parent.category_id = child.parent_category_id
ORDER  BY child.category_id
```

**Rows returned:** 23

| category_id | category_name | parent_category |
|---|---|---|
| 1 | Electronics | NULL |
| 2 | Mobiles | Electronics |
| 3 | Smartphones | Mobiles |
| 4 | Mobile Accessories | Mobiles |
| 5 | Audio | Electronics |
| 6 | Earbuds | Audio |
| 7 | Headphones | Audio |
| 8 | Computers | Electronics |
| 9 | Laptops | Computers |
| 10 | Computer Accessories | Computers |
| 11 | Fashion | NULL |
| 12 | Men | Fashion |
| 13 | Men's T-Shirts | Men |
| 14 | Women | Fashion |
| 15 | Women's Kurtas | Women |
| 16 | Footwear | Fashion |
| 17 | Sports Shoes | Footwear |
| 18 | Home & Kitchen | NULL |
| 19 | Kitchen Appliances | Home & Kitchen |
| 20 | Home Decor | Home & Kitchen |
| 21 | Books | NULL |
| 22 | Fiction | Books |
| 23 | Non-Fiction | Books |

## J8 SELF JOIN - full 3-level category path

```sql
SELECT top_level.category_name AS level_1,
       mid_level.category_name AS level_2,
       leaf.category_name      AS level_3,
       CONCAT(top_level.category_name, ' > ', mid_level.category_name,
              ' > ', leaf.category_name) AS full_path
FROM   categories leaf
JOIN   categories mid_level ON mid_level.category_id = leaf.parent_category_id
JOIN   categories top_level ON top_level.category_id = mid_level.parent_category_id
ORDER  BY full_path
```

**Rows returned:** 9

| level_1 | level_2 | level_3 | full_path |
|---|---|---|---|
| Electronics | Audio | Earbuds | Electronics > Audio > Earbuds |
| Electronics | Audio | Headphones | Electronics > Audio > Headphones |
| Electronics | Computers | Computer Accessories | Electronics > Computers > Computer Accessories |
| Electronics | Computers | Laptops | Electronics > Computers > Laptops |
| Electronics | Mobiles | Mobile Accessories | Electronics > Mobiles > Mobile Accessories |
| Electronics | Mobiles | Smartphones | Electronics > Mobiles > Smartphones |
| Fashion | Footwear | Sports Shoes | Fashion > Footwear > Sports Shoes |
| Fashion | Men | Men's T-Shirts | Fashion > Men > Men's T-Shirts |
| Fashion | Women | Women's Kurtas | Fashion > Women > Women's Kurtas |

## J9 SELF JOIN - who referred whom

```sql
SELECT referrer.customer_id AS referrer_id,
       referrer.full_name   AS referred_by,
       newbie.customer_id   AS customer_id,
       newbie.full_name     AS customer,
       newbie.signup_date
FROM   customers newbie
JOIN   customers referrer ON referrer.customer_id = newbie.referred_by
ORDER  BY referrer.full_name, newbie.signup_date
```

**Rows returned:** 15

| referrer_id | referred_by | customer_id | customer | signup_date |
|---|---|---|---|---|
| 26 | Ananya Iyer | 27 | Tanvi Shah | 2026-01-17 |
| 11 | Arjun Reddy | 12 | Varun Kapoor | 2025-05-29 |
| 11 | Arjun Reddy | 18 | Payal Ghosh | 2025-10-26 |
| 19 | Imran Qureshi | 30 | Gaurav Sinha | 2026-02-17 |
| 17 | Jaspreet Gill | 50 | Swati Chavan | 2026-09-25 |
| 7 | Karan Malhotra | 13 | Harsh Agarwal | 2025-08-08 |
| 38 | Mohit Bansal | 40 | Aman Choudhary | 2026-06-13 |
| 10 | Rahul Joshi | 25 | Kunal Bose | 2026-01-05 |
| 10 | Rahul Joshi | 32 | Aditya Verma | 2026-03-13 |
| 6 | Riya Banerjee | 8 | Nikhil Jain | 2025-04-15 |
| 2 | Rohan Mehta | 16 | Shreya Das | 2025-09-19 |
| 20 | Sam Fernandes | 23 | Neha Kulkarni | 2025-12-19 |
| 4 | Simran Kaur | 21 | Vikram Singh | 2025-11-22 |
| 12 | Varun Kapoor | 15 | Pooja Desai | 2025-09-07 |
| 39 | Yash Saxena | 49 | Ritika Arora | 2026-09-12 |

## J9b SELF JOIN + GROUP BY - top referrers

```sql
SELECT referrer.full_name AS referrer,
       COUNT(*)           AS customers_referred
FROM   customers newbie
JOIN   customers referrer ON referrer.customer_id = newbie.referred_by
GROUP  BY referrer.customer_id, referrer.full_name
ORDER  BY customers_referred DESC, referrer
```

**Rows returned:** 13

| referrer | customers_referred |
|---|---|
| Arjun Reddy | 2 |
| Rahul Joshi | 2 |
| Ananya Iyer | 1 |
| Imran Qureshi | 1 |
| Jaspreet Gill | 1 |
| Karan Malhotra | 1 |
| Mohit Bansal | 1 |
| Riya Banerjee | 1 |
| Rohan Mehta | 1 |
| Sam Fernandes | 1 |
| Simran Kaur | 1 |
| Varun Kapoor | 1 |
| Yash Saxena | 1 |

## J10 8-table JOIN - last 7 days, full order and payment picture

```sql
SELECT o.order_id,
       DATE(o.order_date)                AS order_day,
       c.full_name                       AS customer,
       a.city,
       COUNT(oi.product_id)              AS items,
       SUM(oi.quantity * oi.unit_price)  AS items_value,
       d.code                            AS coupon,
       pay.method                        AS pay_method,
       pay.status                        AS pay_status,
       dl.status                         AS delivery_status,
       o.status                          AS order_status
FROM   orders o
JOIN   customers          c   ON c.customer_id   = o.customer_id
JOIN   order_items        oi  ON oi.order_id     = o.order_id
LEFT JOIN customer_addresses a   ON a.address_id    = o.shipping_address_id
LEFT JOIN order_discounts    od  ON od.order_id     = o.order_id
LEFT JOIN discounts          d   ON d.discount_id   = od.discount_id
LEFT JOIN payments           pay ON pay.order_id    = o.order_id
                                AND pay.status     <> 'FAILED'
LEFT JOIN deliveries         dl  ON dl.order_id     = o.order_id
WHERE  o.order_date >= '2026-11-13'
GROUP  BY o.order_id, o.order_date, c.full_name, a.city, d.code,
          pay.method, pay.status, dl.status, o.status
ORDER  BY o.order_date
```

**Rows returned:** 11

| order_id | order_day | customer | city | items | items_value | coupon | pay_method | pay_status | delivery_status | order_status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1269 | 2026-11-14 | Pooja Desai | Lucknow | 3 | 1347.00 | NULL | UPI | SUCCESS | IN_TRANSIT | SHIPPED |
| 1270 | 2026-11-15 | Aditi Bhatt | Ahmedabad | 3 | 42896.00 | NULL | NET_BANKING | PENDING | NULL | PLACED |
| 1271 | 2026-11-15 | Aditya Verma | Pune | 1 | 1299.00 | NULL | NET_BANKING | PENDING | NULL | PLACED |
| 1272 | 2026-11-16 | Aditya Verma | Pune | 2 | 1598.00 | SAVE10 | UPI | SUCCESS | SHIPPED | SHIPPED |
| 1273 | 2026-11-17 | Aditi Bhatt | Ahmedabad | 1 | 1299.00 | SAVE10 | UPI | SUCCESS | PENDING | CONFIRMED |
| 1274 | 2026-11-17 | Shreya Das | Ahmedabad | 1 | 299.00 | NULL | UPI | SUCCESS | PENDING | CONFIRMED |
| 1275 | 2026-11-19 | Imran Qureshi | Ahmedabad | 3 | 1945.00 | SAVE10 | NET_BANKING | SUCCESS | SHIPPED | SHIPPED |
| 1276 | 2026-11-19 | Kavya Menon | Chandigarh | 2 | 10294.00 | SAVE10 | NULL | NULL | NULL | CANCELLED |
| 1277 | 2026-11-20 | Isha Gupta | Patna | 2 | 4097.00 | NULL | CARD | SUCCESS | PENDING | CONFIRMED |
| 1280 | 2026-11-20 | Varun Kapoor | NULL | 1 | 5999.00 | NULL | NET_BANKING | SUCCESS | PENDING | CONFIRMED |
| 1281 | 2026-11-20 | Isha Gupta | NULL | 1 | 1398.00 | NULL | UPI | SUCCESS | PENDING | CONFIRMED |

## J11 5-table JOIN - revenue by category and payment method

```sql
SELECT COALESCE(top_cat.category_name, mid_cat.category_name) AS category,
       pay.method,
       COUNT(DISTINCT o.order_id)       AS orders,
       SUM(oi.quantity * oi.unit_price) AS gross_revenue
FROM   order_items oi
JOIN   orders      o       ON o.order_id     = oi.order_id
JOIN   payments    pay     ON pay.order_id   = o.order_id AND pay.status = 'SUCCESS'
JOIN   products    p       ON p.product_id   = oi.product_id
JOIN   categories  leaf    ON leaf.category_id = p.category_id
JOIN   categories  mid_cat ON mid_cat.category_id = leaf.parent_category_id




LEFT JOIN categories top_cat ON top_cat.category_id = mid_cat.parent_category_id
WHERE  o.status <> 'CANCELLED'
GROUP  BY COALESCE(top_cat.category_name, mid_cat.category_name), pay.method
ORDER  BY category, gross_revenue DESC
```

**Rows returned:** 16

| category | method | orders | gross_revenue |
|---|---|---|---|
| Books | UPI | 28 | 13609.00 |
| Books | CARD | 16 | 7327.00 |
| Books | NET_BANKING | 10 | 5235.00 |
| Books | COD | 10 | 5136.00 |
| Electronics | UPI | 80 | 756644.00 |
| Electronics | NET_BANKING | 34 | 653623.00 |
| Electronics | CARD | 45 | 643776.00 |
| Electronics | COD | 30 | 467419.00 |
| Fashion | UPI | 36 | 72182.00 |
| Fashion | CARD | 25 | 53455.00 |
| Fashion | COD | 13 | 26276.00 |
| Fashion | NET_BANKING | 15 | 18276.00 |
| Home & Kitchen | UPI | 20 | 38176.00 |
| Home & Kitchen | COD | 9 | 23091.00 |
| Home & Kitchen | CARD | 12 | 20780.00 |
| Home & Kitchen | NET_BANKING | 6 | 9493.00 |

## J12 CROSS JOIN - product/warehouse pairs with no stock row

```sql
SELECT p.sku,
       p.product_name,
       w.warehouse_name
FROM   products p
CROSS JOIN warehouses w
LEFT JOIN inventory i ON i.product_id   = p.product_id
                     AND i.warehouse_id = w.warehouse_id
WHERE  i.product_id IS NULL
ORDER  BY w.warehouse_id, p.sku
```

**Rows returned:** 20

| sku | product_name | warehouse_name |
|---|---|---|
| BIBA-KRT | Biba Cotton Straight Kurta | Bhiwandi FC |
| HP-M24 | HP M24f 24-inch FHD Monitor | Bhiwandi FC |
| LEN-IPS3 | Lenovo IdeaPad Slim 3 (Ryzen 5) | Bhiwandi FC |
| ONP-NB2 | OnePlus Nord Buds 2 | Bhiwandi FC |
| PRS-IND | Prestige PIC 20 Induction Cooktop | Bhiwandi FC |
| RDM-N13P | Redmi Note 13 Pro 5G | Bhiwandi FC |
| SPG-CASE | Spigen Rugged Armor Phone Case | Bhiwandi FC |
| APL-IP15 | Apple iPhone 15 (128GB) | Gurugram FC |
| BK-WINGS | Wings of Fire | Gurugram FC |
| BOAT-RK450 | boAt Rockerz 450 Headphones | Gurugram FC |
| CMP-RUN | Campus North Plus Running Shoes | Gurugram FC |
| LBS-ANK | Libas Anarkali Kurta Set | Gurugram FC |
| USP-CREW | U.S. Polo Assn. Crew Neck Tee | Gurugram FC |
| W-PKRT | W Printed A-Line Kurta | Gurugram FC |
| BJJ-OTG | Bajaj 1603T 16L OTG | Bengaluru FC |
| BOAT-PB20K | boAt 20000mAh Power Bank | Bengaluru FC |
| HP-PAV15 | HP Pavilion 15 Laptop (i5) | Bengaluru FC |
| PGN-KTL | Pigeon 1.5L Electric Kettle | Bengaluru FC |
| RDS-GTEE | Roadster Graphic Print T-Shirt | Bengaluru FC |
| SAM-S24 | Samsung Galaxy S24 (8GB/256GB) | Bengaluru FC |
