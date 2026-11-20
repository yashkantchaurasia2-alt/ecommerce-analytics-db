# PRD — E-Commerce Order and Customer Analytics System

## 1. Summary
A relational database for an Indian e-commerce platform. It stores customers, products, inventory, orders, payments, discounts and deliveries. It also answers business questions such as who the repeat customers are, which products sell best and how payments are going. A simple website presents the schema, the queries and their results.

## 2. Problem
Small e-commerce businesses often keep orders, stock and payments in separate spreadsheets. That leads to:
- duplicate and inconsistent customer and product data (update anomalies)
- stock that goes negative or does not match orders
- no reliable way to see repeat customers, best sellers or revenue trends

## 3. Goals
| # | Goal | Measured by |
|---|---|---|
| G1 | Normalized schema (1NF → BCNF) with full integrity constraints | `docs/normalization.md`, DDL, constraint tests pass |
| G2 | Cover DDL, DML, DCL, TCL | `sql/01`–`sql/05` run without errors |
| G3 | Order & payment analysis with joins and subqueries | `sql/06`, `sql/07`, `sql/09` |
| G4 | Identify repeat customers and best-selling products | `sql/09` returns non-empty results |
| G5 | Rank products with window functions; use CTEs | `sql/12` |
| G6 | Set operations, ≥2 views, indexes with EXPLAIN | `sql/08`, `sql/10`, `sql/11` |
| G7 | A clean, comfortable website to showcase the project | site runs locally and works at phone width |

## 4. Users / roles
| Role | Needs | DB access |
|---|---|---|
| Admin (`db_admin`) | Manage schema, users, all data | Full |
| Order clerk (`order_clerk`) | Place and update orders, record payments | INSERT/UPDATE on order tables only |
| Analyst (`analyst`) | Sales and customer reports | Read-only, ideally on views only |
| Customer | Browses and buys (represented as data, not a DB login) | None |
| Teacher / examiner | Checks syllabus coverage and runs the demo | Repo, website, demo script |

## 5. Scope (v1)
**Database (MySQL 8.0.31+), 12 tables:** `customers`, `customer_addresses`, `categories` (self-referencing tree), `products`, `warehouses`, `inventory`, `orders`, `order_items`, `payments`, `discounts`, `order_discounts`, `deliveries`.

**SQL deliverables:** files `sql/01`–`sql/12` as listed in `CLAUDE.md`. Every query carries a comment naming the syllabus component it covers and the business question it answers.

**Seed data:** about 50 customers (some referred by others, some with zero orders), a 3-level category tree, 40 products, 2–3 warehouses, 250+ orders over 6+ months, UPI/card/COD/net-banking payments (including failed and pending ones), coupons, and deliveries in different statuses.

**Testing:** `tests/run_tests` rebuilds a test database, runs every SQL file, and asserts row counts, constraint rejections, TCL rollback, views/indexes and analytics results. It prints PASS/FAIL. Query outputs are saved to `outputs/`.

**Website:** a calm, aesthetic, responsive site with these pages:
- Overview (problem, stack, how to run)
- Schema & ER diagram
- Normalization walkthrough
- Query explorer: each query with its syllabus tag, plain-English question, SQL and saved result table
- Analytics dashboard: repeat customers, best sellers, monthly revenue, payment-method split

The site reads the saved results in `outputs/` (exported as JSON). It does not hold DB credentials, so it is safe to host publicly.

**Docs:** `README.md`, `docs/requirements-analysis.md`, `docs/er-diagram.md`, `docs/normalization.md`, `docs/rubric-mapping.md`, `docs/viva-notes.md`, `demo/demo_script.sql`.

## 6. Out of scope (v1)
- Real payment gateway, authentication or customer login
- A live write-enabled app (the website is read-only and shows saved results)
- Reviews, cart, wishlist, sellers or returns tables
- Production hosting of the database

## 7. Constraints & assumptions
- **Deadline: today.** Rubric evidence comes first and polish second.
- MySQL 8.0.31+ is required. `MINUS` is shown through `EXCEPT` and `NOT EXISTS` / `LEFT JOIN … IS NULL`. `FULL OUTER JOIN` is emulated with `LEFT JOIN UNION RIGHT JOIN`.
- The GitHub repo is **public**. Secrets live only in `.env` (git-ignored); `.env.example` is committed.
- The repo, docs and outputs together serve as the report. No separate PDF or PPT is needed.
- All amounts are in INR. Dates fall in a recent 6+ month window.

## 8. Acceptance criteria
- A fresh clone plus a filled-in `.env` gives an all-PASS result from `tests/run_tests`.
- Every row of the syllabus table and the marking scheme maps to a file and query in `docs/rubric-mapping.md`.
- There are no secrets anywhere in the git history.
- The website loads, shows every query result, and stays readable at phone width.
