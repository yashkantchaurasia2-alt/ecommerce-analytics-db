# Requirements Analysis

## 1. Problem identification
An online store has to track who buys, what they buy, where the stock is, how they paid, which coupon they used and whether the parcel arrived. When this lives in one flat sheet or in several disconnected sheets:
- **Redundancy.** A customer's name and phone number repeat on every order row.
- **Update anomaly.** Changing a product price or a customer address means editing many rows, and missing one leaves the data inconsistent.
- **Insert anomaly.** A new product cannot be recorded until someone orders it.
- **Delete anomaly.** Deleting a customer's only order also deletes the customer.
- **No analysis.** Questions like repeat customers, best sellers, revenue by month or failed payments cannot be answered reliably.

**Objective:** design a normalized (BCNF) relational database with integrity constraints, access control and transactions. Use it to support complex order and payment retrieval and customer purchasing behaviour analysis.

## 2. Stakeholders
| Stakeholder | Interest | How the system serves them |
|---|---|---|
| Admin | Keeps the database correct and secure | `db_admin` role with full privileges; DDL scripts |
| Order clerk | Places orders and records payments quickly and safely | `order_clerk` role; the place-order transaction with ROLLBACK on failure |
| Analyst / management | Sales trends, top products, loyal customers | `analyst` role, read-only on views; analytics, window-function and CTE queries |
| Customer | Correct orders, applied discounts, timely delivery | Data integrity (FKs, CHECKs), tracked delivery status |
| Warehouse staff | Accurate stock per warehouse | `inventory` table; stock cannot go negative |
| Teacher / examiner | Syllabus coverage and correctness | Rubric mapping, tests, demo script, website |

## 3. Functional requirements
| ID | Requirement |
|---|---|
| FR1 | Store customers with multiple addresses and an optional referrer (another customer). |
| FR2 | Store a 3-level product category hierarchy (parent → child → grandchild). |
| FR3 | Store products with price, category and active flag; prices must be > 0. |
| FR4 | Track stock per product per warehouse; quantity must be ≥ 0. |
| FR5 | Record orders with one or more items, keeping the unit price at the time of purchase. |
| FR6 | Record one or more payments per order with method (UPI, card, COD, net banking) and status (success, failed, pending). |
| FR7 | Store coupons (percentage or flat, validity dates) and link them to orders. |
| FR8 | Track a delivery per order with status (pending, shipped, in transit, delivered, returned) and dates. |
| FR9 | Place an order atomically: create order → add items → reduce stock → record payment → commit. Roll back on insufficient stock or failed payment. |
| FR10 | Provide three access levels (admin, clerk, analyst) using GRANT and REVOKE. |
| FR11 | Report repeat customers, top customers by spend, best-selling products by quantity and revenue, best seller per category, average order value, revenue by payment method and month, failed/pending payments, undelivered orders, and discount usage and impact. |
| FR12 | Rank products by sales overall and per category (RANK, DENSE_RANK, ROW_NUMBER); running revenue totals; month-over-month change (LAG); customer quartiles (NTILE). |
| FR13 | Provide at least 2 reusable views (target 4) for reporting. |
| FR14 | Display schema, queries and results on a responsive website. |

## 4. Non-functional requirements
| ID | Category | Requirement |
|---|---|---|
| NFR1 | Integrity | PK, FK, UNIQUE, NOT NULL, CHECK and DEFAULT constraints on all tables; sensible ON DELETE / ON UPDATE rules. |
| NFR2 | Normalization | Every table is in BCNF, or has a documented justification. |
| NFR3 | Consistency | Multi-step operations use transactions (ACID). Failures leave no partial data. |
| NFR4 | Security | Least privilege per role. Credentials only in `.env`, never in git. The public website holds no credentials. |
| NFR5 | Performance | Indexes on FK and filter/join columns, with EXPLAIN before and after as evidence. |
| NFR6 | Portability | Runs on stock MySQL 8.0.31+ with no extensions. |
| NFR7 | Testability | One command rebuilds a test DB and checks everything with a PASS/FAIL summary. |
| NFR8 | Maintainability | Numbered SQL files. Every query is commented with its syllabus component and business question. |
| NFR9 | Usability | The website is clean, calm and readable on phone and desktop. |

## 5. Assumptions
- A single currency (INR) and a single country (India).
- One delivery per order. Orders are not split across shipments.
- An order may have several payment attempts. It counts as paid when at least one payment succeeded.
- At most one coupon per order in the seed data. The `order_discounts` link table still allows more.
- A customer is a "repeat customer" if they have more than one order.
- Revenue counts only orders with a successful payment, unless a query says otherwise.
- Seed data is synthetic. Names, phone numbers and emails are fake.

## 6. Out of scope
- Real payment gateway, user login or password storage
- Cart, wishlist, reviews, sellers/marketplace, returns/refunds workflow
- A live website that writes to the database
- Production deployment of the database
