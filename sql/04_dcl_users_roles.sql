-- =====================================================================
-- 04_dcl_users_roles.sql
-- Syllabus: SQL Fundamentals (DCL: CREATE ROLE / CREATE USER, GRANT,
--           REVOKE, SET DEFAULT ROLE, SHOW GRANTS)
-- Business need: least privilege. Each person gets only the access their
-- job needs.
--   db_admin    -> r_admin       : full control of this database
--   order_clerk -> r_order_clerk : place and update orders, never delete
--   analyst     -> r_analyst     : read-only (moved to views-only in 10_views.sql)
--
-- No password is written in this file. IDENTIFIED BY RANDOM PASSWORD makes
-- MySQL generate one and return it once in the result set. The admin then
-- shares it securely, or sets a new one with ALTER USER.
--
-- GRANT needs a literal database name, but this file must work in any
-- database (main or test). So each GRANT is built with DATABASE() and run
-- as a prepared statement. The plain form is shown in the comment above it.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Clean slate. Users and roles belong to the whole MySQL server, not to
-- one database, so the old copies of THESE three users and roles are
-- removed first. No other account is touched.
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'db_admin'@'localhost', 'order_clerk'@'localhost', 'analyst'@'localhost';
DROP ROLE IF EXISTS 'r_admin', 'r_order_clerk', 'r_analyst';

-- ---------------------------------------------------------------------
-- DCL: CREATE ROLE
-- A role is a named bundle of privileges. Grant to the role once, then
-- give the role to as many users as needed.
-- ---------------------------------------------------------------------
CREATE ROLE 'r_admin', 'r_order_clerk', 'r_analyst';

SET @db = DATABASE();

-- ---------------------------------------------------------------------
-- DCL: GRANT to r_admin
-- Plain form: GRANT ALL PRIVILEGES ON ecommerce_db.* TO r_admin WITH GRANT OPTION;
-- ---------------------------------------------------------------------
SET @sql = CONCAT('GRANT ALL PRIVILEGES ON `', @db, '`.* TO r_admin WITH GRANT OPTION');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- DCL: GRANT to r_order_clerk
-- Read-only on reference data the clerk needs to look up.
-- Plain form: GRANT SELECT ON ecommerce_db.customers TO r_order_clerk;  (and so on)
-- ---------------------------------------------------------------------
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.customers TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.customer_addresses TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.categories TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.products TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.warehouses TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.discounts TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Order-processing tables: read, insert and update, but NOT delete.
-- Plain form: GRANT SELECT, INSERT, UPDATE ON ecommerce_db.orders TO r_order_clerk;
SET @sql = CONCAT('GRANT SELECT, INSERT, UPDATE ON `', @db, '`.orders TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT, INSERT, UPDATE ON `', @db, '`.order_items TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT, INSERT, UPDATE ON `', @db, '`.payments TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT, INSERT, UPDATE ON `', @db, '`.order_discounts TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql = CONCAT('GRANT SELECT, INSERT, UPDATE ON `', @db, '`.deliveries TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- COLUMN-LEVEL privilege: the clerk may reduce stock when an order is
-- placed (UPDATE quantity) but may not change the reorder level.
-- Plain form: GRANT SELECT, UPDATE (quantity) ON ecommerce_db.inventory TO r_order_clerk;
SET @sql = CONCAT('GRANT SELECT, UPDATE (quantity) ON `', @db, '`.inventory TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- DCL: GRANT to r_analyst (read-only on every table for now).
-- In 10_views.sql this is REVOKEd and replaced by SELECT on views only.
-- Plain form: GRANT SELECT ON ecommerce_db.* TO r_analyst;
-- ---------------------------------------------------------------------
SET @sql = CONCAT('GRANT SELECT ON `', @db, '`.* TO r_analyst');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- DCL: CREATE USER
-- RANDOM PASSWORD: MySQL generates the password and returns it once.
-- FAILED_LOGIN_ATTEMPTS / PASSWORD_LOCK_TIME: lock the account for a day
-- after 5 wrong passwords (protects against guessing).
-- ---------------------------------------------------------------------
CREATE USER 'db_admin'@'localhost' IDENTIFIED BY RANDOM PASSWORD
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'order_clerk'@'localhost' IDENTIFIED BY RANDOM PASSWORD
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'analyst'@'localhost' IDENTIFIED BY RANDOM PASSWORD
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;

-- ---------------------------------------------------------------------
-- DCL: GRANT role TO user, then SET DEFAULT ROLE so the role is active
-- as soon as the user logs in (otherwise they would have to run SET ROLE).
-- ---------------------------------------------------------------------
GRANT 'r_admin'       TO 'db_admin'@'localhost';
GRANT 'r_order_clerk' TO 'order_clerk'@'localhost';
GRANT 'r_analyst'     TO 'analyst'@'localhost';

SET DEFAULT ROLE 'r_admin'       TO 'db_admin'@'localhost';
SET DEFAULT ROLE 'r_order_clerk' TO 'order_clerk'@'localhost';
SET DEFAULT ROLE 'r_analyst'     TO 'analyst'@'localhost';

-- ---------------------------------------------------------------------
-- DCL: REVOKE
-- Business question: a clerk was given DELETE on orders by mistake.
-- Deleting orders would destroy sales history, so it is taken back.
-- ---------------------------------------------------------------------
-- Plain form: GRANT DELETE ON ecommerce_db.orders TO r_order_clerk;
SET @sql = CONCAT('GRANT DELETE ON `', @db, '`.orders TO r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- @query: r_order_clerk grants BEFORE revoke (note DELETE on orders)
SHOW GRANTS FOR 'r_order_clerk';

-- Plain form: REVOKE DELETE ON ecommerce_db.orders FROM r_order_clerk;
SET @sql = CONCAT('REVOKE DELETE ON `', @db, '`.orders FROM r_order_clerk');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- @query: r_order_clerk grants AFTER revoke (DELETE is gone)
SHOW GRANTS FOR 'r_order_clerk';

-- ---------------------------------------------------------------------
-- DCL: SHOW GRANTS ... USING
-- Business question: what can each user actually do once their role is
-- active?
-- ---------------------------------------------------------------------
-- @query: Effective privileges of db_admin
SHOW GRANTS FOR 'db_admin'@'localhost' USING 'r_admin';

-- @query: Effective privileges of analyst
SHOW GRANTS FOR 'analyst'@'localhost' USING 'r_analyst';

-- @query: Which role is assigned to which user
SELECT from_user AS role_name,
       to_user   AS user_name,
       to_host   AS user_host
FROM   mysql.role_edges
WHERE  from_user IN ('r_admin', 'r_order_clerk', 'r_analyst')
ORDER  BY role_name;
