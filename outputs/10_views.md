# Results of `sql/10_views.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## V1 vw_order_summary - the 10 most recent orders

```sql
SELECT order_id, order_date, customer, items, gross_value, discount,
       net_paid, payment_status, delivery_status
FROM   vw_order_summary
ORDER  BY order_date DESC
LIMIT  10
```

**Rows returned:** 10

| order_id | order_date | customer | items | gross_value | discount | net_paid | payment_status | delivery_status |
|---|---|---|---|---|---|---|---|---|
| 1281 | 2026-11-20 12:00:00 | Isha Gupta | 1 | 1398.00 | 0.00 | 1398.00 | PAID | PENDING |
| 1280 | 2026-11-20 10:45:00 | Varun Kapoor | 1 | 5999.00 | 0.00 | 5999.00 | PAID | PENDING |
| 1277 | 2026-11-20 10:00:00 | Isha Gupta | 2 | 4097.00 | 0.00 | 4097.00 | PAID | PENDING |
| 1276 | 2026-11-19 23:04:46 | Kavya Menon | 2 | 10294.00 | 1029.40 | 0.00 | FAILED | NOT CREATED |
| 1275 | 2026-11-19 10:37:55 | Imran Qureshi | 3 | 1945.00 | 194.50 | 1750.50 | PAID | SHIPPED |
| 1274 | 2026-11-17 23:00:23 | Shreya Das | 1 | 299.00 | 0.00 | 299.00 | PAID | PENDING |
| 1273 | 2026-11-17 19:07:03 | Aditi Bhatt | 1 | 1299.00 | 129.90 | 1169.10 | PAID | PENDING |
| 1272 | 2026-11-16 22:21:44 | Aditya Verma | 2 | 1598.00 | 159.80 | 1438.20 | PAID | SHIPPED |
| 1271 | 2026-11-15 15:59:19 | Aditya Verma | 1 | 1299.00 | 0.00 | 0.00 | PENDING | NOT CREATED |
| 1270 | 2026-11-15 09:27:12 | Aditi Bhatt | 3 | 42896.00 | 0.00 | 0.00 | PENDING | NOT CREATED |

## V2 vw_product_sales - top 10 products by revenue, with stock left

```sql
SELECT product_name, category_name, units_sold, gross_revenue, stock_left
FROM   vw_product_sales
ORDER  BY gross_revenue DESC
LIMIT  10
```

**Rows returned:** 10

| product_name | category_name | units_sold | gross_revenue | stock_left |
|---|---|---|---|---|
| OnePlus 12R (8GB/128GB) | Smartphones | 13 | 519987.00 | 217 |
| Apple iPhone 15 (128GB) | Smartphones | 6 | 431994.00 | 263 |
| Redmi Note 13 Pro 5G | Smartphones | 13 | 325987.00 | 286 |
| HP Pavilion 15 Laptop (i5) | Laptops | 4 | 251960.00 | 207 |
| Lenovo IdeaPad Slim 3 (Ryzen 5) | Laptops | 5 | 229950.00 | 118 |
| Samsung Galaxy S24 (8GB/256GB) | Smartphones | 3 | 224997.00 | 199 |
| boAt Airdopes 141 | Earbuds | 73 | 94827.00 | 202 |
| Sony WH-1000XM5 Headphones | Headphones | 3 | 89970.00 | 50 |
| JBL Tune 760NC Headphones | Headphones | 12 | 71988.00 | 324 |
| Logitech MX Master 3S Mouse | Computer Accessories | 6 | 53970.00 | 325 |

## V3 vw_customer_lifetime_value - customers per segment

```sql
SELECT segment,
       COUNT(*)                    AS customers,
       SUM(lifetime_value)         AS total_value,
       ROUND(AVG(lifetime_value), 2) AS avg_value
FROM   vw_customer_lifetime_value
GROUP  BY segment
ORDER  BY total_value DESC
```

**Rows returned:** 4

| segment | customers | total_value | avg_value |
|---|---|---|---|
| High | 12 | 1995281.00 | 166273.42 |
| Medium | 10 | 579420.65 | 57942.07 |
| Low | 17 | 184621.45 | 10860.09 |
| No purchase | 11 | 0.00 | 0.00 |

## V3b vw_customer_lifetime_value - top 5 customers

```sql
SELECT customer_id, full_name, city, orders_placed, lifetime_value, segment
FROM   vw_customer_lifetime_value
ORDER  BY lifetime_value DESC
LIMIT  5
```

**Rows returned:** 5

| customer_id | full_name | city | orders_placed | lifetime_value | segment |
|---|---|---|---|---|---|
| 26 | Ananya Iyer | Chennai | 8 | 292528.30 | High |
| 32 | Aditya Verma | Pune | 16 | 266380.90 | High |
| 39 | Yash Saxena | Mumbai | 15 | 175082.05 | High |
| 44 | Pranav Hegde | Jaipur | 16 | 169193.20 | High |
| 1 | Aarav Sharma | Chandigarh | 8 | 167434.60 | High |

## V4 vw_pending_deliveries - waiting more than 3 days

```sql
SELECT order_id, order_day, days_waiting, customer, delivery_status, courier
FROM   vw_pending_deliveries
WHERE  days_waiting > 3
ORDER  BY days_waiting DESC
```

**Rows returned:** 8

| order_id | order_day | days_waiting | customer | delivery_status | courier |
|---|---|---|---|---|---|
| 1262 | 2026-11-08 | 12 | Harsh Agarwal | NOT CREATED | NULL |
| 1265 | 2026-11-09 | 11 | Kritika Sood | NOT CREATED | NULL |
| 1266 | 2026-11-10 | 10 | Anjali Tiwari | IN_TRANSIT | Shadowfax |
| 1267 | 2026-11-11 | 9 | Manish Yadav | IN_TRANSIT | XpressBees |
| 1269 | 2026-11-14 | 6 | Pooja Desai | IN_TRANSIT | Ekart |
| 1270 | 2026-11-15 | 5 | Aditi Bhatt | NOT CREATED | NULL |
| 1271 | 2026-11-15 | 5 | Aditya Verma | NOT CREATED | NULL |
| 1272 | 2026-11-16 | 4 | Aditya Verma | SHIPPED | Blue Dart |

## V5 price changed through the view is visible in the base table

```sql
SELECT sku, price FROM products WHERE sku = 'PGN-KTL'
```

**Rows returned:** 1

| sku | price |
|---|---|
| PGN-KTL | 649.00 |

## V6 r_analyst grants after the change (views only)

```sql
SHOW GRANTS FOR 'r_analyst'
```

**Rows returned:** 5

| Grants for r_analyst@% |
|---|
| GRANT USAGE ON *.* TO `r_analyst`@`%` |
| GRANT SELECT ON `ecommerce_test`.`vw_customer_lifetime_value` TO `r_analyst`@`%` |
| GRANT SELECT ON `ecommerce_test`.`vw_order_summary` TO `r_analyst`@`%` |
| GRANT SELECT ON `ecommerce_test`.`vw_pending_deliveries` TO `r_analyst`@`%` |
| GRANT SELECT ON `ecommerce_test`.`vw_product_sales` TO `r_analyst`@`%` |

## V7 all views in this database

```sql
SELECT table_name AS view_name, is_updatable, check_option, security_type
FROM   information_schema.views
WHERE  table_schema = DATABASE()
ORDER  BY table_name
```

**Rows returned:** 5

| view_name | IS_UPDATABLE | CHECK_OPTION | SECURITY_TYPE |
|---|---|---|---|
| vw_active_products | YES | CASCADED | DEFINER |
| vw_customer_lifetime_value | NO | NONE | DEFINER |
| vw_order_summary | NO | NONE | DEFINER |
| vw_pending_deliveries | NO | NONE | DEFINER |
| vw_product_sales | NO | NONE | DEFINER |
