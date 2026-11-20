# Rubric Mapping

This page maps every syllabus component and every marking area to the exact file and query that proves it. Query IDs (J1, S7, W1, ...) are the `-- @query:` labels in the SQL files. Their saved results are in `outputs/<same file name>.md`.

All evidence is checked automatically by `python tests/run_tests.py`: 213 checks, all passing.

---

## 1. Mandatory syllabus coverage

| Syllabus component | Expected | Where it is implemented | Key evidence |
|---|---|---|---|
| **ER Model** | ER diagram with entities and relationships | `docs/er-diagram.md` | Mermaid diagram of 12 entities and 15 relationships; cardinality table (1:1, 1:N, M:N resolved by `order_items`, `inventory`, `order_discounts`); two recursive relationships |
| **Relational Model** | Schema with primary and foreign keys | `sql/01_ddl_schema.sql` | 12 tables, every table has a PK (3 composite), 15 FKs with ON DELETE / ON UPDATE rules, composite FK `orders(shipping_address_id, customer_id)` |
| **Normalization** | 1NF, 2NF, 3NF **and BCNF** | `docs/normalization.md` | Un-normalized order sheet → 1NF → 2NF → 3NF with FDs and the anomaly removed at each step; `courier_coverage` example that is in 3NF but not BCNF, decomposed; BCNF check of all 12 real tables |
| **SQL Fundamentals: DDL** | CREATE, ALTER, DROP, TRUNCATE, RENAME | `sql/01_ddl_schema.sql` | CREATE ×12; ALTER ADD COLUMN / MODIFY / ADD CONSTRAINT / RENAME COLUMN; RENAME TABLE; TRUNCATE; DROP |
| **SQL Fundamentals: DML** | INSERT, UPDATE, DELETE, SELECT with WHERE, GROUP BY, HAVING, ORDER BY | `sql/02_dml_seed_data.sql`, `sql/03_dml_operations.sql` | 1,724 seed rows; UPDATE ×4 (incl. UPDATE … JOIN and a subquery); DELETE ×2; 7 SELECTs covering WHERE, BETWEEN, LIKE, GROUP BY, HAVING, ORDER BY |
| **SQL Fundamentals: DCL** | GRANT, REVOKE | `sql/04_dcl_users_roles.sql`, `sql/10_views.sql` | CREATE ROLE ×3, CREATE USER ×3 (random passwords), table and **column-level** GRANTs, REVOKE demo, SET DEFAULT ROLE; analyst moved to views-only |
| **SQL Fundamentals: TCL** | COMMIT, ROLLBACK, SAVEPOINT | `sql/05_tcl_transactions.sql` | Case 1 COMMIT; Case 2 ROLLBACK (payment failed); Case 3 ROLLBACK (no stock); Case 4 SAVEPOINT + ROLLBACK TO SAVEPOINT; Case 5 SET autocommit 0/1; `sp_place_order` procedure with automatic COMMIT/ROLLBACK |
| **Complex Queries: joins** | Inner, Outer and Self joins | `sql/06_joins.sql` | INNER J1, J2; LEFT J3, J4; RIGHT J5; FULL OUTER (emulated with LEFT JOIN UNION RIGHT JOIN) J6; SELF J7, J8, J9, J9b; CROSS J12; 8-table J10; 5-table J11 |
| **Subqueries** | Nested and correlated | `sql/07_subqueries.sql` | Nested: S1 (IN), S2 (NOT IN), S3/S4 (scalar), S5 (4 levels), S6a (ALL), S6b (ANY). Correlated: S7, S8, S9, S10. EXISTS S11, NOT EXISTS S12. Derived tables S13, S14 |
| **Set Operations** | UNION, INTERSECT, MINUS/EXCEPT | `sql/08_set_operations.sql` | UNION U1, U4; UNION ALL U2; UNION vs UNION ALL U3; INTERSECT I1, I2 (+ IN equivalent I1b); EXCEPT E1, E2; MINUS equivalents E1b (NOT EXISTS) and E1c (LEFT JOIN … IS NULL) |
| **Views** | Minimum two views | `sql/10_views.sql` | **5 views**: `vw_order_summary`, `vw_product_sales`, `vw_customer_lifetime_value`, `vw_pending_deliveries`, `vw_active_products` (updatable, WITH CHECK OPTION); queried in V1–V5; granted to the analyst (V6) |
| **Indexing** | Appropriate indexes | `sql/11_indexes.sql` | 5 indexes on WHERE / JOIN / ORDER BY columns; EXPLAIN before and after: X1 (ALL → ref, 312 → 3 rows), X2 (ALL → range, 283 → 13 rows), X3 (filesort removed); X4 shows when an index cannot be used; K0–K2 list the indexes and the write-cost trade-off |
| **Advanced SQL: window functions** | Window functions | `sql/12_window_functions_ctes.sql` | ROW_NUMBER / RANK / DENSE_RANK on real ties W1; PARTITION BY W2, W2b, W3; running total W4; LAG W5; moving average W6; NTILE(4) W7, W7b; LEAD W8; SUM() OVER (), PERCENT_RANK, CUME_DIST W9 |
| **Advanced SQL: CTEs** | CTEs | `sql/12_window_functions_ctes.sql` | Multi-step CTEs T1, T2; CTE referenced twice T3; **recursive CTEs** R1 (category tree), R2 (sales roll-up), R3 (referral chains) |

## 2. Project-specific requirements

| # | Requirement | Where |
|---|---|---|
| 1 | Normalized schemas for e-commerce operations | `docs/normalization.md`, `sql/01_ddl_schema.sql` |
| 2 | DDL, DML, DCL and TCL | `sql/01` – `sql/05` |
| 3 | Joins and subqueries for order and payment analysis | `sql/06` J10 (8-table order/payment picture), J11 (revenue by category and method); `sql/07` S9, S10, S11, S14; `sql/09` C1–C7 |
| 4 | Repeat customers and best-selling products | `sql/09` A1 (repeat customers), A2 (repeat rate 77.3%), B1 (best sellers by quantity), B2 (by revenue), B3 (per category) |
| 5 | Window functions to rank products by sales | `sql/12` W1, W2, W2b, W3, W9, T1 |

## 3. Marking scheme (100 marks)

| Area | Marks | Evidence |
|---|---|---|
| Problem identification & requirements analysis | 10 | `docs/requirements-analysis.md` (problem and anomalies, 6 stakeholders, 14 functional and 9 non-functional requirements, assumptions, out of scope); `PRD.md` (goals G1–G7, roles, scope, acceptance criteria) |
| ER modelling & schema design | 15 | `docs/er-diagram.md`; `sql/01_ddl_schema.sql` |
| Normalization & integrity constraints | 15 | `docs/normalization.md`; 23 CHECK, 15 FK, UNIQUE, NOT NULL, DEFAULT constraints in `sql/01`; **12 constraint-rejection tests** in `tests/run_tests.py` (plus the view's CHECK OPTION test) (negative price, negative stock, invalid status, non-existent customer, another customer's address, ...) |
| SQL implementation & query development | 25 | `sql/02` – `sql/09` (DML, DCL, TCL, 13 joins, 15 subqueries, 11 set operations, 17 analytics queries) |
| Advanced SQL, views & indexing | 15 | `sql/10` (5 views), `sql/11` (5 indexes, EXPLAIN before/after), `sql/12` (17 window-function and CTE queries) |
| Testing, documentation & validation | 10 | `tests/run_tests.py` (213 checks, each result cross-checked against an independent query); `outputs/` (118 saved results); `README.md` |
| Demonstration & viva | 10 | `demo/demo_script.sql` (6-minute demo, tested to run cleanly and change no data); `docs/viva-notes.md` (every query explained + viva Q&A) |

## 4. How the evidence is verified

`tests/run_tests.py` rebuilds a fresh test database, runs every SQL file, and then checks:

- **Schema:** 12 tables, 15 FKs, 23 CHECKs, a PK on every table, and the DDL demo effects.
- **Data:** row counts, 7 months of orders, all payment methods and statuses, and money that reconciles (paid = items − discount).
- **Constraints:** 12 invalid inserts are rejected with the expected MySQL error codes.
- **DCL:** real logins as `db_admin`, `order_clerk` and `analyst`, with allowed and denied actions (errors 1142, 1143, 1369).
- **TCL:** stock changes only for committed orders; rolled-back orders leave no trace.
- **Query results:** each one is compared with an independently written query. For example:
  - EXCEPT = NOT EXISTS = LEFT JOIN … IS NULL
  - the RANK = 1 result matches the GROUP BY version
  - revenue totals agree three ways
- **Indexes:** EXPLAIN plans change from ALL to ref/range.
- **Demo:** the demo script runs end to end and leaves the data unchanged.
