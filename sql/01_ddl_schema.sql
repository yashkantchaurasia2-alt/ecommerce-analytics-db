-- =====================================================================
-- 01_ddl_schema.sql
-- Syllabus: Relational Model + SQL Fundamentals (DDL) + Integrity constraints
-- Builds the 12-table e-commerce schema (BCNF, see docs/normalization.md)
-- and demonstrates CREATE, ALTER, RENAME, TRUNCATE and DROP.
-- Run inside an empty database (the test runner creates one for you).
-- =====================================================================

-- ---------------------------------------------------------------------
-- DDL: DROP
-- Clean slate, so this file can be re-run safely. Child tables first;
-- FOREIGN_KEY_CHECKS is switched off only for the duration of the drops.
-- ---------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS deliveries, order_discounts, discounts, payments,
                     order_items, orders, inventory, warehouses, products,
                     categories, customer_addresses, customers,
                     temp_price_log, price_change_log;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE customers
-- Business question: who are our customers and who referred them?
-- referred_by -> customers (self-referencing FK, used for SELF JOIN).
-- MySQL note: a column that has an ON DELETE SET NULL / CASCADE action
-- cannot also appear in a CHECK constraint (error 3823), so the rule
-- "a customer cannot refer themselves" is enforced in the data, not CHECK.
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id   INT          NOT NULL AUTO_INCREMENT,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(120) NOT NULL,
    phone         CHAR(10)     NOT NULL,
    gender        CHAR(1)      NULL,
    date_of_birth DATE         NULL,
    signup_date   DATE         NOT NULL DEFAULT (CURRENT_DATE),
    referred_by   INT          NULL,
    CONSTRAINT pk_customers        PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email  UNIQUE (email),
    CONSTRAINT uq_customers_phone  UNIQUE (phone),
    CONSTRAINT chk_customers_phone  CHECK (phone REGEXP '^[6-9][0-9]{9}$'),
    CONSTRAINT chk_customers_email  CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT chk_customers_gender CHECK (gender IN ('M', 'F', 'O')),
    CONSTRAINT fk_customers_referred_by FOREIGN KEY (referred_by)
        REFERENCES customers (customer_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE customer_addresses (1 customer : N addresses)
-- UNIQUE (address_id, customer_id) lets orders use a composite FK, so an
-- order can only ship to an address that belongs to the same customer.
-- ---------------------------------------------------------------------
CREATE TABLE customer_addresses (
    address_id   INT          NOT NULL AUTO_INCREMENT,
    customer_id  INT          NOT NULL,
    address_type VARCHAR(10)  NOT NULL DEFAULT 'HOME',
    line1        VARCHAR(150) NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    state        VARCHAR(60)  NOT NULL,
    pincode      CHAR(6)      NOT NULL,
    is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_customer_addresses PRIMARY KEY (address_id),
    CONSTRAINT uq_address_customer   UNIQUE (address_id, customer_id),
    CONSTRAINT chk_address_type    CHECK (address_type IN ('HOME', 'WORK', 'OTHER')),
    CONSTRAINT chk_address_pincode CHECK (pincode REGEXP '^[1-9][0-9]{5}$'),
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE categories (self-referencing tree)
-- Electronics -> Mobiles -> Smartphones. parent_category_id is NULL for
-- top-level categories. Used for SELF JOIN and the recursive CTE.
-- RESTRICT: a parent category cannot be deleted while it has children.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id        INT         NOT NULL AUTO_INCREMENT,
    category_name      VARCHAR(60) NOT NULL,
    parent_category_id INT         NULL,
    CONSTRAINT pk_categories      PRIMARY KEY (category_id),
    CONSTRAINT uq_categories_name UNIQUE (category_name),
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_category_id)
        REFERENCES categories (category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE products (N products : 1 category)
-- price is the CURRENT selling price; the price actually paid is kept
-- in order_items.unit_price.
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id   INT           NOT NULL AUTO_INCREMENT,
    sku          VARCHAR(20)   NOT NULL,
    product_name VARCHAR(120)  NOT NULL,
    category_id  INT           NOT NULL,
    brand        VARCHAR(60)   NULL,
    price        DECIMAL(10,2) NOT NULL,
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_products     PRIMARY KEY (product_id),
    CONSTRAINT uq_products_sku UNIQUE (sku),
    CONSTRAINT chk_products_price CHECK (price > 0),
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE warehouses
-- ---------------------------------------------------------------------
CREATE TABLE warehouses (
    warehouse_id   INT         NOT NULL AUTO_INCREMENT,
    warehouse_name VARCHAR(60) NOT NULL,
    city           VARCHAR(60) NOT NULL,
    state          VARCHAR(60) NOT NULL,
    CONSTRAINT pk_warehouses      PRIMARY KEY (warehouse_id),
    CONSTRAINT uq_warehouses_name UNIQUE (warehouse_name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE inventory
-- Resolves the M:N between products and warehouses.
-- Composite PK (product_id, warehouse_id): one stock row per pair.
-- CHECK quantity >= 0: stock can never go negative.
-- ---------------------------------------------------------------------
CREATE TABLE inventory (
    product_id    INT      NOT NULL,
    warehouse_id  INT      NOT NULL,
    quantity      INT      NOT NULL DEFAULT 0,
    reorder_level INT      NOT NULL DEFAULT 10,
    last_updated  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                           ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory PRIMARY KEY (product_id, warehouse_id),
    CONSTRAINT chk_inventory_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_inventory_reorder  CHECK (reorder_level >= 0),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inventory_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouses (warehouse_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE orders (1 customer : N orders)
-- Order total is NOT stored: it is derived as SUM(quantity * unit_price)
-- from order_items, so it can never disagree with the items (3NF).
-- RESTRICT: a customer who has orders cannot be deleted (keeps history).
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id            INT         NOT NULL AUTO_INCREMENT,
    customer_id         INT         NOT NULL,
    shipping_address_id INT         NULL,
    order_date          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status              VARCHAR(12) NOT NULL DEFAULT 'PLACED',
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT chk_orders_status CHECK (status IN
        ('PLACED', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_address FOREIGN KEY (shipping_address_id, customer_id)
        REFERENCES customer_addresses (address_id, customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE order_items
-- Resolves the M:N between orders and products.
-- unit_price = price at the time of purchase (later price changes in
-- products do not change old orders). It depends on the WHOLE key
-- (order_id, product_id), so there is no partial dependency (2NF).
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id   INT           NOT NULL,
    product_id INT           NOT NULL,
    quantity   INT           NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id),
    CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_order_items_price    CHECK (unit_price > 0),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE payments (1 order : N payment attempts)
-- An order counts as paid when at least one attempt has status SUCCESS.
-- transaction_ref is NULL for COD, unique otherwise.
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id      INT           NOT NULL AUTO_INCREMENT,
    order_id        INT           NOT NULL,
    method          VARCHAR(12)   NOT NULL,
    status          VARCHAR(8)    NOT NULL DEFAULT 'PENDING',
    amount          DECIMAL(10,2) NOT NULL,
    paid_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transaction_ref VARCHAR(30)   NULL,
    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    CONSTRAINT uq_payments_txn_ref UNIQUE (transaction_ref),
    CONSTRAINT chk_payments_method CHECK (method IN ('UPI', 'CARD', 'COD', 'NET_BANKING')),
    CONSTRAINT chk_payments_status CHECK (status IN ('SUCCESS', 'FAILED', 'PENDING')),
    CONSTRAINT chk_payments_amount CHECK (amount > 0),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE discounts (coupons)
-- PERCENT coupons must be <= 100; validity window must make sense.
-- ---------------------------------------------------------------------
CREATE TABLE discounts (
    discount_id     INT           NOT NULL AUTO_INCREMENT,
    code            VARCHAR(20)   NOT NULL,
    description     VARCHAR(150)  NULL,
    discount_type   VARCHAR(7)    NOT NULL,
    discount_value  DECIMAL(10,2) NOT NULL,
    min_order_value DECIMAL(10,2) NOT NULL DEFAULT 0,
    valid_from      DATE          NOT NULL,
    valid_to        DATE          NOT NULL,
    CONSTRAINT pk_discounts      PRIMARY KEY (discount_id),
    CONSTRAINT uq_discounts_code UNIQUE (code),
    CONSTRAINT chk_discounts_type  CHECK (discount_type IN ('PERCENT', 'FLAT')),
    CONSTRAINT chk_discounts_value CHECK (discount_value > 0),
    CONSTRAINT chk_discounts_pct   CHECK (discount_type <> 'PERCENT' OR discount_value <= 100),
    CONSTRAINT chk_discounts_min   CHECK (min_order_value >= 0),
    CONSTRAINT chk_discounts_dates CHECK (valid_to >= valid_from)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE order_discounts
-- Resolves the M:N between orders and discounts.
-- amount_saved is the rupee value actually deducted on this order.
-- ---------------------------------------------------------------------
CREATE TABLE order_discounts (
    order_id     INT           NOT NULL,
    discount_id  INT           NOT NULL,
    amount_saved DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_order_discounts PRIMARY KEY (order_id, discount_id),
    CONSTRAINT chk_order_discounts_saved CHECK (amount_saved >= 0),
    CONSTRAINT fk_order_discounts_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_discounts_discount FOREIGN KEY (discount_id)
        REFERENCES discounts (discount_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- DDL: CREATE TABLE deliveries (1 order : 1 delivery)
-- UNIQUE (order_id) is what makes the relationship 1:1.
-- ---------------------------------------------------------------------
CREATE TABLE deliveries (
    delivery_id    INT         NOT NULL AUTO_INCREMENT,
    order_id       INT         NOT NULL,
    warehouse_id   INT         NOT NULL,
    courier        VARCHAR(40) NOT NULL,
    tracking_no    VARCHAR(30) NULL,
    status         VARCHAR(12) NOT NULL DEFAULT 'PENDING',
    shipped_date   DATE        NULL,
    delivered_date DATE        NULL,
    CONSTRAINT pk_deliveries          PRIMARY KEY (delivery_id),
    CONSTRAINT uq_deliveries_order    UNIQUE (order_id),
    CONSTRAINT uq_deliveries_tracking UNIQUE (tracking_no),
    CONSTRAINT chk_deliveries_status CHECK (status IN
        ('PENDING', 'SHIPPED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED')),
    CONSTRAINT chk_deliveries_dates CHECK (delivered_date IS NULL OR
        (shipped_date IS NOT NULL AND delivered_date >= shipped_date)),
    CONSTRAINT fk_deliveries_order FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_deliveries_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouses (warehouse_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- =====================================================================
-- DDL: ALTER TABLE
-- Business need: show the MRP next to the selling price (for "% off").
-- 1) ADD a column  2) MODIFY a column  3) ADD a CHECK constraint.
-- =====================================================================
ALTER TABLE products
    ADD COLUMN mrp DECIMAL(10,2) NULL AFTER price;

ALTER TABLE products
    MODIFY COLUMN brand VARCHAR(80) NOT NULL DEFAULT 'Generic';

ALTER TABLE products
    ADD CONSTRAINT chk_products_mrp CHECK (mrp IS NULL OR mrp >= price);

-- =====================================================================
-- DDL: RENAME, TRUNCATE, DROP (on a throw-away table, so the real
-- schema is not affected)
-- =====================================================================
CREATE TABLE temp_price_log (
    log_id     INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
    product_id INT           NOT NULL,
    old_price  DECIMAL(10,2) NOT NULL,
    new_price  DECIMAL(10,2) NOT NULL,
    changed_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- RENAME: give the table a clearer name
RENAME TABLE temp_price_log TO price_change_log;

-- ALTER ... RENAME COLUMN: rename a column
ALTER TABLE price_change_log RENAME COLUMN changed_at TO logged_at;

-- TRUNCATE: removes all rows at once and resets AUTO_INCREMENT
-- (DDL, auto-commits; unlike DELETE it cannot be rolled back)
INSERT INTO price_change_log (product_id, old_price, new_price) VALUES (1, 100.00, 90.00);
TRUNCATE TABLE price_change_log;

-- DROP: removes the table structure itself
DROP TABLE price_change_log;
