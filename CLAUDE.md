# CLAUDE.md

Project guide for anyone working in this repository.

## What this is
DBMS capstone: a normalized (up to BCNF) relational database for an e-commerce platform — customers, products, inventory, orders, payments, discounts, deliveries — plus SQL for order/payment analysis, repeat customers, best sellers and window-function product rankings.

## Tech stack
- MySQL 8.0.31+ (needed for window functions, CTEs, `INTERSECT`/`EXCEPT`). MySQL has no `MINUS`: use `EXCEPT` and also show the `NOT EXISTS` / `LEFT JOIN ... IS NULL` equivalent.
- SQL + a test script, plus a read-only showcase website (shows saved query results from `outputs/`; never holds DB credentials).
- DB credentials come from `.env` (template: `.env.example`).

## How to run locally
- Run the SQL files in `sql/` in numeric order (`01_` → `12_`); each file depends on the ones before it.
- MySQL 8.0.46 runs inside WSL (Ubuntu 24.04), reached from Windows at 127.0.0.1:3306; no mysql client on Windows, so use Python (`pip install -r requirements.txt`). Ubuntu must be running.
- Tests: `python tests/run_tests.py` drops and recreates a **test database only**, runs every `sql/` file in order, asserts row counts, constraint rejections, TCL rollback, views/indexes and analytics results, and prints PASS/FAIL.
- Query results for the report are saved in `outputs/` by the test runner: any statement preceded by a `-- @query: <title>` comment line is written to `outputs/<sql file name>.md`.
- `sql/02_dml_seed_data.sql` is generated: edit `tools/generate_seed.py` (fixed random seed, "today" = 2026-11-20) and re-run `python tools/generate_seed.py`, never hand-edit the SQL. Test expectations (row counts, boAt prices) depend on this data.

## Main folders
- `sql/` — numbered scripts: DDL, seed DML, DML ops, DCL, TCL, joins, subqueries, set ops, analytics, views, indexes, window functions/CTEs.
- `docs/` — requirements, ER diagram (Mermaid), normalization 1NF→BCNF, rubric mapping, viva notes.
- `demo/` — 5–7 minute live demo script. `tests/` — test runner. `outputs/` — saved query results.
- Every query needs a comment above it: which syllabus component it covers + the business question it answers.

## Hard rules
1. No AI attribution anywhere — not in code, comments, docs, commit messages or PR descriptions. Plain commit messages only (e.g. `add orders and order_items tables`).
2. Explain every file to the user in simple Hinglish (they must defend it in a viva).
3. Missing GitHub or database access (gh not logged in, push fails, no DB server/credentials) → stop and ask the user. No workarounds.
4. Secrets only in `.env`; `.env` is git-ignored and never committed. Commit `.env.example` with empty values.
5. Show a plan before any big change and wait for "ok". Work one step at a time and stop after each.
6. Don't touch files unrelated to the current step.
7. Test → commit → push after every working step. Never push failing tests.
8. No destructive commands (`DROP DATABASE`, `rm -rf`, …) outside the project's own test database without asking first.
