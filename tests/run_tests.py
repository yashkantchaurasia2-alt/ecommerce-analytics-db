"""
Test runner for the e-commerce analytics database.

What it does:
  1. Reads DB credentials from .env (project root).
  2. DROPS and recreates the TEST database only (DB_TEST_NAME).
     Safety: refuses to run unless the name ends with "_test" and is
     different from DB_NAME, so the main database can never be dropped.
  3. Runs every sql/NN_*.sql file in numeric order.
  4. Runs assertion checks and prints a PASS/FAIL summary.

Usage:  python tests/run_tests.py
Exit code 0 = all checks passed, 1 = something failed.
"""
import os
import re
import sys
from pathlib import Path

import pymysql
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"

RESULTS = []  # (status, name, detail)


def record(ok, name, detail=""):
    RESULTS.append(("PASS" if ok else "FAIL", name, detail))
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"  ({detail})" if detail else ""))


# ---------------------------------------------------------------------------
# SQL file splitting
# pymysql runs one statement per execute(), so each file is split on ';'
# while ignoring semicolons inside quotes and comments. Comments are dropped.
# ---------------------------------------------------------------------------
def split_sql(text):
    statements, buf = [], []
    i, n = 0, len(text)
    quote = None
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if quote:
            buf.append(ch)
            if ch == "\\" and quote in ("'", '"'):
                buf.append(nxt)
                i += 2
                continue
            if ch == quote:
                if nxt == quote:          # doubled quote = escaped quote
                    buf.append(nxt)
                    i += 2
                    continue
                quote = None
            i += 1
            continue
        if ch in ("'", '"', "`"):
            quote = ch
            buf.append(ch)
        elif ch == "-" and nxt == "-" and (i + 2 >= n or text[i + 2] in " \t\r\n"):
            while i < n and text[i] != "\n":
                i += 1
            buf.append("\n")
            continue
        elif ch == "#":
            while i < n and text[i] != "\n":
                i += 1
            buf.append("\n")
            continue
        elif ch == "/" and nxt == "*":
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
            buf.append(" ")
            continue
        elif ch == ";":
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
        else:
            buf.append(ch)
        i += 1
    stmt = "".join(buf).strip()
    if stmt:
        statements.append(stmt)
    return statements


# ---------------------------------------------------------------------------
# Connection + safety
# ---------------------------------------------------------------------------
def load_config():
    load_dotenv(ROOT / ".env")
    cfg = {k: os.getenv(k, "") for k in
           ("DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME", "DB_TEST_NAME")}
    test_db = cfg["DB_TEST_NAME"]
    if not re.fullmatch(r"[A-Za-z0-9_]+_test", test_db or ""):
        sys.exit(f"Refusing to run: DB_TEST_NAME must end with '_test' (got '{test_db}').")
    if test_db == cfg["DB_NAME"]:
        sys.exit("Refusing to run: DB_TEST_NAME must differ from DB_NAME.")
    return cfg


def connect(cfg, database=None):
    return pymysql.connect(
        host=cfg["DB_HOST"] or "127.0.0.1",
        port=int(cfg["DB_PORT"] or 3306),
        user=cfg["DB_USER"],
        password=cfg["DB_PASSWORD"],
        database=database,
        charset="utf8mb4",
        autocommit=True,
        connect_timeout=10,
    )


def rebuild_test_db(cfg):
    name = cfg["DB_TEST_NAME"]
    conn = connect(cfg)
    with conn.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS `{name}`")
        cur.execute(f"CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
    conn.close()


def run_sql_files(conn):
    files = sorted(SQL_DIR.glob("[0-9][0-9]_*.sql"))
    all_ok = True
    for path in files:
        statements = split_sql(path.read_text(encoding="utf-8"))
        with conn.cursor() as cur:
            for idx, stmt in enumerate(statements, 1):
                try:
                    cur.execute(stmt)
                    if cur.description:
                        cur.fetchall()
                except pymysql.MySQLError as e:
                    snippet = " ".join(stmt.split())[:120]
                    record(False, f"run {path.name}", f"statement {idx}: {e.args} :: {snippet}")
                    all_ok = False
                    break
            else:
                record(True, f"run {path.name}", f"{len(statements)} statements")
        if not all_ok:
            break
    return all_ok


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
EXPECTED_TABLES = {
    "customers", "customer_addresses", "categories", "products", "warehouses",
    "inventory", "orders", "order_items", "payments", "discounts",
    "order_discounts", "deliveries",
}


def scalar(cur, sql, args=None):
    cur.execute(sql, args)
    row = cur.fetchone()
    return row[0] if row else None


def check_schema(conn, db):
    with conn.cursor() as cur:
        cur.execute("SELECT table_name FROM information_schema.tables "
                    "WHERE table_schema = %s AND table_type = 'BASE TABLE'", (db,))
        tables = {r[0] for r in cur.fetchall()}
        missing = EXPECTED_TABLES - tables
        extra = tables - EXPECTED_TABLES
        record(not missing and not extra, "schema has exactly the 12 tables",
               f"missing={sorted(missing)} extra={sorted(extra)}" if (missing or extra) else "")

        fks = scalar(cur, "SELECT COUNT(*) FROM information_schema.referential_constraints "
                          "WHERE constraint_schema = %s", (db,))
        record(fks == 15, "15 foreign keys defined", f"found {fks}")

        checks = scalar(cur, "SELECT COUNT(*) FROM information_schema.check_constraints "
                             "WHERE constraint_schema = %s", (db,))
        record(checks == 23, "23 CHECK constraints defined", f"found {checks}")

        no_pk = scalar(cur, """
            SELECT COUNT(*) FROM information_schema.tables t
            WHERE t.table_schema = %s AND t.table_type = 'BASE TABLE'
              AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints c
                              WHERE c.table_schema = t.table_schema
                                AND c.table_name = t.table_name
                                AND c.constraint_type = 'PRIMARY KEY')""", (db,))
        record(no_pk == 0, "every table has a primary key", f"{no_pk} without PK")

        mrp = scalar(cur, "SELECT COUNT(*) FROM information_schema.columns "
                          "WHERE table_schema = %s AND table_name = 'products' "
                          "AND column_name = 'mrp'", (db,))
        record(mrp == 1, "ALTER added products.mrp")

        brand_null = scalar(cur, "SELECT is_nullable FROM information_schema.columns "
                                 "WHERE table_schema = %s AND table_name = 'products' "
                                 "AND column_name = 'brand'", (db,))
        record(brand_null == "NO", "ALTER ... MODIFY made products.brand NOT NULL")

        log = scalar(cur, "SELECT COUNT(*) FROM information_schema.tables "
                          "WHERE table_schema = %s AND table_name IN "
                          "('temp_price_log', 'price_change_log')", (db,))
        record(log == 0, "RENAME/TRUNCATE/DROP demo table is gone")


def expect_reject(cur, name, sql, args, codes):
    try:
        cur.execute(sql, args)
    except pymysql.MySQLError as e:
        code = e.args[0]
        record(code in codes, f"rejects {name}", f"MySQL error {code}")
        return
    record(False, f"rejects {name}", "insert was ACCEPTED")


def check_constraints(conn):
    """Insert a tiny valid fixture, try invalid rows, then roll everything back."""
    CHECK_FAIL, FK_FAIL, DUPLICATE = 3819, 1452, 1062
    conn.autocommit(False)
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO categories (category_name) VALUES ('__t_cat')")
            cat = cur.lastrowid
            cur.execute("INSERT INTO products (sku, product_name, category_id, price) "
                        "VALUES ('__T1', 'Test product', %s, 100)", (cat,))
            prod = cur.lastrowid
            cur.execute("INSERT INTO warehouses (warehouse_name, city, state) "
                        "VALUES ('__t_wh', 'Pune', 'Maharashtra')")
            wh = cur.lastrowid
            cur.execute("INSERT INTO customers (full_name, email, phone) "
                        "VALUES ('Test User', 'test.user@example.com', '9876543210')")
            cust = cur.lastrowid
            record(True, "valid fixture rows are accepted")

            bad_cust = scalar(cur, "SELECT COALESCE(MAX(customer_id), 0) + 1000 FROM customers")

            expect_reject(cur, "negative product price",
                          "INSERT INTO products (sku, product_name, category_id, price) "
                          "VALUES ('__T2', 'Bad', %s, -5)", (cat,), {CHECK_FAIL})
            expect_reject(cur, "zero product price",
                          "INSERT INTO products (sku, product_name, category_id, price) "
                          "VALUES ('__T3', 'Bad', %s, 0)", (cat,), {CHECK_FAIL})
            expect_reject(cur, "negative stock",
                          "INSERT INTO inventory (product_id, warehouse_id, quantity) "
                          "VALUES (%s, %s, -1)", (prod, wh), {CHECK_FAIL})
            expect_reject(cur, "invalid order status",
                          "INSERT INTO orders (customer_id, status) VALUES (%s, 'LOST')",
                          (cust,), {CHECK_FAIL})
            expect_reject(cur, "order for non-existent customer",
                          "INSERT INTO orders (customer_id) VALUES (%s)", (bad_cust,), {FK_FAIL})
            expect_reject(cur, "invalid payment method",
                          "INSERT INTO payments (order_id, method, amount) VALUES (1, 'BITCOIN', 10)",
                          None, {CHECK_FAIL, FK_FAIL})
            expect_reject(cur, "duplicate customer email",
                          "INSERT INTO customers (full_name, email, phone) "
                          "VALUES ('Dup', 'test.user@example.com', '9876500000')", None, {DUPLICATE})
            expect_reject(cur, "invalid phone number",
                          "INSERT INTO customers (full_name, email, phone) "
                          "VALUES ('Bad Phone', 'bad.phone@example.com', '12345')", None, {CHECK_FAIL})
            expect_reject(cur, "coupon valid_to before valid_from",
                          "INSERT INTO discounts (code, discount_type, discount_value, valid_from, valid_to) "
                          "VALUES ('__BAD', 'FLAT', 50, '2026-05-10', '2026-05-01')", None, {CHECK_FAIL})
            expect_reject(cur, "percent coupon above 100",
                          "INSERT INTO discounts (code, discount_type, discount_value, valid_from, valid_to) "
                          "VALUES ('__BAD2', 'PERCENT', 150, '2026-05-01', '2026-05-10')", None, {CHECK_FAIL})
            expect_reject(cur, "mrp lower than price",
                          "INSERT INTO products (sku, product_name, category_id, price, mrp) "
                          "VALUES ('__T4', 'Bad', %s, 100, 50)", (cat,), {CHECK_FAIL})

            # Address belonging to ANOTHER customer must be rejected (composite FK).
            cur.execute("INSERT INTO customers (full_name, email, phone) "
                        "VALUES ('Other', 'other.user@example.com', '9876511111')")
            other = cur.lastrowid
            cur.execute("INSERT INTO customer_addresses (customer_id, line1, city, state, pincode) "
                        "VALUES (%s, '1 MG Road', 'Pune', 'Maharashtra', '411001')", (other,))
            other_addr = cur.lastrowid
            expect_reject(cur, "order shipping to another customer's address",
                          "INSERT INTO orders (customer_id, shipping_address_id) VALUES (%s, %s)",
                          (cust, other_addr), {FK_FAIL})
    finally:
        conn.rollback()
        conn.autocommit(True)


def main():
    cfg = load_config()
    db = cfg["DB_TEST_NAME"]
    print(f"Rebuilding test database '{db}' ...")
    try:
        rebuild_test_db(cfg)
        conn = connect(cfg, db)
    except pymysql.MySQLError as e:
        print(f"Cannot connect / rebuild: {e.args}")
        return 1

    print("Running SQL files:")
    files_ok = run_sql_files(conn)
    if files_ok:
        print("Schema checks:")
        check_schema(conn, db)
        print("Constraint checks:")
        check_constraints(conn)
    conn.close()

    passed = sum(1 for s, _, _ in RESULTS if s == "PASS")
    failed = len(RESULTS) - passed
    print("\n" + "=" * 50)
    print(f"SUMMARY: {passed} passed, {failed} failed -> {'ALL PASS' if failed == 0 else 'FAIL'}")
    print("=" * 50)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
