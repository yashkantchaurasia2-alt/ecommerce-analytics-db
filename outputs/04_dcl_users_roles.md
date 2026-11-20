# Results of `sql/04_dcl_users_roles.sql`

Saved automatically by `tests/run_tests.py` from a fresh test database.

## r_order_clerk grants BEFORE revoke (note DELETE on orders)

```sql
SHOW GRANTS FOR 'r_order_clerk'
```

**Rows returned:** 13

| Grants for r_order_clerk@% |
|---|
| GRANT USAGE ON *.* TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`categories` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`customer_addresses` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`customers` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`deliveries` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`discounts` TO `r_order_clerk`@`%` |
| GRANT SELECT, UPDATE (`quantity`) ON `ecommerce_test`.`inventory` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`order_discounts` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`order_items` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE, DELETE ON `ecommerce_test`.`orders` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`payments` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`products` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`warehouses` TO `r_order_clerk`@`%` |

## r_order_clerk grants AFTER revoke (DELETE is gone)

```sql
SHOW GRANTS FOR 'r_order_clerk'
```

**Rows returned:** 13

| Grants for r_order_clerk@% |
|---|
| GRANT USAGE ON *.* TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`categories` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`customer_addresses` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`customers` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`deliveries` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`discounts` TO `r_order_clerk`@`%` |
| GRANT SELECT, UPDATE (`quantity`) ON `ecommerce_test`.`inventory` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`order_discounts` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`order_items` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`orders` TO `r_order_clerk`@`%` |
| GRANT SELECT, INSERT, UPDATE ON `ecommerce_test`.`payments` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`products` TO `r_order_clerk`@`%` |
| GRANT SELECT ON `ecommerce_test`.`warehouses` TO `r_order_clerk`@`%` |

## Effective privileges of db_admin

```sql
SHOW GRANTS FOR 'db_admin'@'localhost' USING 'r_admin'
```

**Rows returned:** 3

| Grants for db_admin@localhost |
|---|
| GRANT USAGE ON *.* TO `db_admin`@`localhost` |
| GRANT ALL PRIVILEGES ON `ecommerce_test`.* TO `db_admin`@`localhost` WITH GRANT OPTION |
| GRANT `r_admin`@`%` TO `db_admin`@`localhost` |

## Effective privileges of analyst

```sql
SHOW GRANTS FOR 'analyst'@'localhost' USING 'r_analyst'
```

**Rows returned:** 3

| Grants for analyst@localhost |
|---|
| GRANT USAGE ON *.* TO `analyst`@`localhost` |
| GRANT SELECT ON `ecommerce_test`.* TO `analyst`@`localhost` |
| GRANT `r_analyst`@`%` TO `analyst`@`localhost` |

## Which role is assigned to which user

```sql
SELECT from_user AS role_name,
       to_user   AS user_name,
       to_host   AS user_host
FROM   mysql.role_edges
WHERE  from_user IN ('r_admin', 'r_order_clerk', 'r_analyst')
ORDER  BY role_name
```

**Rows returned:** 3

| role_name | user_name | user_host |
|---|---|---|
| r_admin | db_admin | localhost |
| r_analyst | analyst | localhost |
| r_order_clerk | order_clerk | localhost |
