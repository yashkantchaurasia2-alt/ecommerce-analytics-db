# Normalization: from one messy sheet to BCNF

This document takes one un-normalized "order sheet" and walks it through **1NF → 2NF → 3NF → BCNF**. At each step it lists the functional dependencies (FDs) and the anomaly that the step removes. It ends with a BCNF check of every table in the real schema (`sql/01_ddl_schema.sql`).

Notation: `A → B` means "A determines B": if two rows have the same A, they must have the same B.

---

## 0. The un-normalized table (UNF)

A shop owner keeps everything in one spreadsheet:

| order_id | order_date | customer_name | customer_email | customer_phone | customer_city | products | categories | unit_prices | payment_method | coupon_code | coupon_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | 2026-06-02 | Aarav Sharma | aarav@mail.in | 9876500001 | Pune | iPhone 15, Phone Cover | Smartphones, Accessories | 69999, 499 | UPI | SAVE10 | 10 |
| 102 | 2026-06-05 | Priya Nair | priya@mail.in | 9876500002 | Kochi | Phone Cover | Accessories | 499 | COD | — | — |
| 103 | 2026-06-09 | Aarav Sharma | aarav@mail.in | 9876500001 | Pune | Boat Earbuds, Phone Cover | Audio, Accessories | 1299, 449 | CARD | SAVE10 | 10 |

**Problems:**
- **Not atomic.** `products`, `categories` and `unit_prices` hold lists in one cell.
- **Redundancy.** Aarav's email, phone and city are repeated on every order. "Phone Cover → Accessories" is repeated on every row it appears in.
- **Update anomaly.** If Aarav changes his phone number, every one of his rows must be edited. Missing one leaves two different phone numbers for him.
- **Insert anomaly.** A new product cannot be added until somebody orders it. A new coupon cannot be added until somebody uses it.
- **Delete anomaly.** Deleting order 102 also deletes the only record of customer Priya Nair.

---

## 1. First Normal Form (1NF)

**Rule:** every cell holds a single atomic value, there are no repeating groups, and each row is identified by a key.

**Fix:** split the lists so that there is one row per (order, product).

| order_id | product_name | order_date | customer_email | customer_name | customer_phone | customer_city | category | unit_price | payment_method | coupon_code | coupon_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | iPhone 15 | 2026-06-02 | aarav@mail.in | Aarav Sharma | 9876500001 | Pune | Smartphones | 69999 | UPI | SAVE10 | 10 |
| 101 | Phone Cover | 2026-06-02 | aarav@mail.in | Aarav Sharma | 9876500001 | Pune | Accessories | 499 | UPI | SAVE10 | 10 |
| 102 | Phone Cover | 2026-06-05 | priya@mail.in | Priya Nair | 9876500002 | Kochi | Accessories | 499 | COD | NULL | NULL |
| 103 | Boat Earbuds | 2026-06-09 | aarav@mail.in | Aarav Sharma | 9876500001 | Pune | Audio | 1299 | CARD | SAVE10 | 10 |
| 103 | Phone Cover | 2026-06-09 | aarav@mail.in | Aarav Sharma | 9876500001 | Pune | Accessories | 449 | CARD | SAVE10 | 10 |

**Primary key:** `(order_id, product_name)`.

**Functional dependencies:**
1. `order_id → order_date, customer_email, payment_method, coupon_code`
2. `customer_email → customer_name, customer_phone, customer_city`
3. `product_name → category`
4. `coupon_code → coupon_pct`
5. `(order_id, product_name) → unit_price` (and quantity, once we record it)

Phone Cover was ₹499 on order 101 and ₹449 on order 103. So `unit_price` depends on the order **and** the product, not on the product alone. This is why the real schema keeps `unit_price` in `order_items`.

**Removed:** non-atomic cells, so we can now query "all orders containing Phone Cover". **Still present:** heavy redundancy, plus all the update, insert and delete anomalies.

---

## 2. Second Normal Form (2NF)

**Rule:** 1NF, plus **no partial dependency**: no non-key attribute may depend on only *part* of a composite key.

**Partial dependencies that break 2NF:**
- FD 1: `order_id → order_date, customer_email, payment_method, coupon_code` depends on only half of the key.
- FD 3: `product_name → category` depends on only the other half.

**Fix:** move each partial dependency into its own table.

| Table | Columns | Key |
|---|---|---|
| ORDERS_2NF | order_id, order_date, customer_email, customer_name, customer_phone, customer_city, payment_method, coupon_code, coupon_pct | order_id |
| PRODUCTS_2NF | product_name, category | product_name |
| ORDER_ITEMS_2NF | order_id, product_name, quantity, unit_price | (order_id, product_name) |

**Removed:**
- **Insert anomaly for products:** a product can now exist with no orders.
- **Update anomaly for categories:** "Phone Cover → Accessories" is now stored once.

**Still present:** ORDERS_2NF repeats customer details on every order and coupon details on every order that uses the coupon.

---

## 3. Third Normal Form (3NF)

**Rule:** 2NF, plus **no transitive dependency**: no non-key attribute may depend on another non-key attribute.

**Transitive dependencies in ORDERS_2NF:**
- `order_id → customer_email → customer_name, customer_phone, customer_city`
- `order_id → coupon_code → coupon_pct`

**And in PRODUCTS_2NF:** with a surrogate key, the chain is `product_id → category_id → category_name`.

**Fix:** pull out customers, coupons and categories, and use surrogate keys.

| Table | Columns | Key |
|---|---|---|
| customers | customer_id, full_name, email (UNIQUE), phone (UNIQUE) | customer_id |
| orders | order_id, customer_id, order_date | order_id |
| payments | payment_id, order_id, method, amount, status | payment_id |
| discounts | discount_id, code (UNIQUE), discount_type, discount_value | discount_id |
| order_discounts | order_id, discount_id, amount_saved | (order_id, discount_id) |
| categories | category_id, category_name | category_id |
| products | product_id, product_name, category_id, price | product_id |
| order_items | order_id, product_id, quantity, unit_price | (order_id, product_id) |

**Removed:**
- **Update anomaly:** Aarav's phone number now lives in exactly one row.
- **Delete anomaly:** deleting order 102 no longer deletes customer Priya.
- **Insert anomaly:** a coupon can now exist before anyone uses it.

`payment_method` moved out of `orders` into `payments`, because one order can have several payment attempts (for example a failed UPI attempt followed by a successful card payment). Keeping it in `orders` would force a repeating group back in.

---

## 4. Boyce–Codd Normal Form (BCNF)

**Rule:** for **every** non-trivial FD `X → Y`, X must be a **superkey**.

3NF allows one exception: `X → Y` is still acceptable when Y is a *prime* attribute (part of some candidate key). BCNF removes that exception.

### 4.1 Example that is in 3NF but NOT in BCNF

Courier coverage. Each pincode is served by several courier partners. Each courier delivers to that pincode through exactly one of its hubs, and each hub belongs to exactly one courier.

**COURIER_COVERAGE(pincode, courier, hub)**

| pincode | courier | hub |
|---|---|---|
| 411001 | BlueDart | BD-Pune-1 |
| 411001 | Delhivery | DL-Pune-East |
| 411002 | BlueDart | BD-Pune-1 |
| 411002 | Delhivery | DL-Pune-West |

**FDs:**
- `{pincode, courier} → hub`: one hub per courier per pincode
- `hub → courier`: a hub belongs to one courier

**Candidate keys:**
- `{pincode, courier}`
- `{pincode, hub}`, because hub gives courier, so `{pincode, hub}` gives every attribute

**3NF check:** for `hub → courier`, `hub` is not a superkey, **but** `courier` is prime (part of the key `{pincode, courier}`). So the table **is in 3NF**.

**BCNF check:** `hub` is not a superkey, so the table is **not in BCNF**.

**Anomalies that remain:**
- **Update:** if hub BD-Pune-1 is transferred to another courier, every pincode row for that hub must change.
- **Insert:** a new hub cannot be recorded until it serves at least one pincode.
- **Delete:** removing the last pincode served by a hub loses the fact of which courier owns that hub.

**BCNF decomposition** (split on the violating FD `hub → courier`):

| Table | Columns | Key | FDs |
|---|---|---|---|
| HUBS | hub, courier | hub | hub → courier ✔ (hub is a key) |
| PINCODE_HUBS | pincode, hub | (pincode, hub) | none besides the key ✔ |

- **Lossless join:** the common attribute `hub` is a key of HUBS, so joining the two tables gives back exactly the original rows.
- **Dependency preservation:** `{pincode, courier} → hub` is no longer enforceable inside a single table. This is the well-known trade-off: BCNF does not always preserve every FD, while 3NF always can.

> This table is only a teaching example. It is not part of the project schema.

### 4.2 Our schema after BCNF
The 3NF tables from step 3 already satisfy BCNF, because every determinant in them is a key. The final schema adds the supporting tables `customer_addresses`, `warehouses`, `inventory` and `deliveries`, checked below.

---

## 5. BCNF check of every table in the real schema

For each table, the FDs are listed, and every determinant is checked to be a superkey. Candidate keys include the UNIQUE columns.

| Table | Candidate keys | Non-trivial FDs | BCNF? |
|---|---|---|---|
| customers | customer_id, email, phone | each key → all other columns | ✔ every determinant is a key |
| customer_addresses | address_id | address_id → all | ✔ (see note A) |
| categories | category_id, category_name | each key → all | ✔ |
| products | product_id, sku | each key → all | ✔ |
| warehouses | warehouse_id, warehouse_name | each key → all | ✔ (see note A) |
| inventory | (product_id, warehouse_id) | key → quantity, reorder_level, last_updated | ✔ |
| orders | order_id | order_id → customer_id, shipping_address_id, order_date, status | ✔ |
| order_items | (order_id, product_id) | key → quantity, unit_price | ✔ (unit_price depends on the whole key) |
| payments | payment_id, transaction_ref | each key → all | ✔ |
| discounts | discount_id, code | each key → all | ✔ |
| order_discounts | (order_id, discount_id) | key → amount_saved | ✔ |
| deliveries | delivery_id, order_id, tracking_no | each key → all | ✔ |

**Result: all 12 tables are in BCNF.**

### Note A: city, state and pincode
- **`city → state` does not hold in India.** The same city name exists in different states, for example Aurangabad in Maharashtra and in Bihar. So storing `city` and `state` together in `customer_addresses` and `warehouses` is not a transitive dependency.
- **`pincode → city` is not reliable either.** One pincode can cover several towns or localities with different names.
- **`pincode → state` mostly holds in real life**, but the schema treats an address as a snapshot typed by the customer, not as a lookup. If the examiner treats `pincode → state` as a business rule, the strict BCNF fix is the same pattern as section 4.1: move it into a `pincodes(pincode, state)` lookup table and keep only `pincode` in the address. We chose not to, so that the schema stays at the 12 tables in the brief.

### Note B: why no stored totals
`order_total` and `line_total` are left out on purpose. Each would be fully determined by other columns (`SUM(quantity * unit_price)`), so storing them would add a redundant dependency and a chance of drift. They are calculated in queries and views instead.

---

## 6. Summary

| Step | Rule | What we fixed here | Anomaly removed |
|---|---|---|---|
| 1NF | Atomic values, no repeating groups | Split product lists into one row per item | Can now query individual items |
| 2NF | No partial dependency on a composite key | Separated orders and products from order_items | Insert anomaly for products; update anomaly for categories |
| 3NF | No transitive dependency | Separated customers, coupons, categories, payments | Update and delete anomalies for customers; insert anomaly for coupons |
| BCNF | Every determinant is a superkey | Courier/hub example split into HUBS + PINCODE_HUBS | Update, insert and delete anomalies caused by `hub → courier` |
