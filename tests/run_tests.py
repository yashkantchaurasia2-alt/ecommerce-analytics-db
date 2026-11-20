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
    """Returns a list of (title, statement). title comes from a preceding
    '-- @query: <title>' comment line, or is None."""
    statements, buf = [], []
    i, n = 0, len(text)
    quote = None
    title = None
    delim = ";"
    delimiter_re = re.compile(r"[ \t]*DELIMITER[ \t]+(\S+)[ \t]*(?:\r?\n|$)", re.IGNORECASE)
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        # "DELIMITER $$" at the start of a line (client command, used for procedures)
        if not quote and (i == 0 or text[i - 1] == "\n"):
            m = delimiter_re.match(text, i)
            if m:
                delim = m.group(1)
                i = m.end()
                continue
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
            end = text.find("\n", i)
            end = n if end == -1 else end
            comment = text[i + 2:end].strip()
            if comment.startswith("@query:"):
                title = comment[len("@query:"):].strip()
            i = end
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
        elif text.startswith(delim, i):
            stmt = "".join(buf).strip()
            if stmt:
                statements.append((title, stmt))
                title = None
            buf = []
            i += len(delim)
            continue
        else:
            buf.append(ch)
        i += 1
    stmt = "".join(buf).strip()
    if stmt:
        statements.append((title, stmt))
    return statements


# ---------------------------------------------------------------------------
# Saving query results to outputs/
# ---------------------------------------------------------------------------
OUTPUT_DIR = ROOT / "outputs"
GENERATED_PASSWORDS = {}  # user -> password from CREATE USER ... RANDOM PASSWORD (memory only)
MAX_OUTPUT_ROWS = 60


def fmt_cell(v):
    if v is None:
        return "NULL"
    return str(v).replace("|", "\\|").replace("\n", " ")


def to_markdown(title, sql, columns, rows):
    lines = [f"## {title}", "", "```sql", sql, "```", ""]
    lines.append(f"**Rows returned:** {len(rows)}" +
                 (f" (showing first {MAX_OUTPUT_ROWS})" if len(rows) > MAX_OUTPUT_ROWS else ""))
    lines.append("")
    if columns:
        lines.append("| " + " | ".join(columns) + " |")
        lines.append("|" + "---|" * len(columns))
        for r in rows[:MAX_OUTPUT_ROWS]:
            lines.append("| " + " | ".join(fmt_cell(v) for v in r) + " |")
    lines.append("")
    return "\n".join(lines)


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


INVENTORY_CHANGES = {}  # sql file name -> {(sku, warehouse_id): change in quantity}
QUERY_RESULTS = {}      # "-- @query:" title -> (column names, rows)


def result(prefix):
    """Rows of the saved query whose title starts with prefix (e.g. 'J3 ')."""
    for title, (cols, rows) in QUERY_RESULTS.items():
        if title.startswith(prefix):
            return cols, rows
    return None, None


def inventory_snapshot(conn):
    with conn.cursor() as cur:
        try:
            cur.execute("SELECT p.sku, i.warehouse_id, i.quantity FROM inventory i "
                        "JOIN products p ON p.product_id = i.product_id")
            return {(s, w): q for s, w, q in cur.fetchall()}
        except pymysql.MySQLError:
            return {}   # tables do not exist yet (before 01_ddl_schema.sql)


def diff_snapshots(before, after):
    keys = set(before) | set(after)
    return {k: after.get(k, 0) - before.get(k, 0) for k in keys
            if after.get(k, 0) != before.get(k, 0)}


def run_sql_files(conn):
    files = sorted(SQL_DIR.glob("[0-9][0-9]_*.sql"))
    all_ok = True
    OUTPUT_DIR.mkdir(exist_ok=True)
    for path in files:
        statements = split_sql(path.read_text(encoding="utf-8"))
        saved = []
        before = inventory_snapshot(conn)
        with conn.cursor() as cur:
            for idx, (title, stmt) in enumerate(statements, 1):
                try:
                    cur.execute(stmt)
                    if cur.description:
                        rows = cur.fetchall()
                        cols_lower = [d[0].lower() for d in cur.description]
                        if "generated password" in cols_lower:
                            # CREATE USER ... RANDOM PASSWORD: keep in memory only,
                            # never print it or write it to outputs/.
                            ui, pi = cols_lower.index("user"), cols_lower.index("generated password")
                            for r in rows:
                                GENERATED_PASSWORDS[r[ui]] = r[pi]
                        elif title:
                            cols = [d[0] for d in cur.description]
                            QUERY_RESULTS[title] = (cols, rows)
                            saved.append(to_markdown(title, stmt, cols, rows))
                except pymysql.MySQLError as e:
                    snippet = " ".join(stmt.split())[:120]
                    record(False, f"run {path.name}", f"statement {idx}: {e.args} :: {snippet}")
                    all_ok = False
                    break
            else:
                record(True, f"run {path.name}", f"{len(statements)} statements, {len(saved)} results saved")
                INVENTORY_CHANGES[path.name] = diff_snapshots(before, inventory_snapshot(conn))
        if saved and all_ok:
            header = (f"# Results of `sql/{path.name}`\n\n"
                      "Saved automatically by `tests/run_tests.py` from a fresh test database.\n\n")
            (OUTPUT_DIR / f"{path.stem}.md").write_text(header + "\n".join(saved), encoding="utf-8")
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


def check_seed(conn):
    """Row counts and data variety after 02_dml_seed_data.sql (and 03)."""
    with conn.cursor() as cur:
        exact = {"customers": 50, "products": 40, "categories": 23,
                 "warehouses": 3, "discounts": 6}
        for table, want in exact.items():
            got = scalar(cur, f"SELECT COUNT(*) FROM {table}")
            record(got == want, f"{table} has {want} rows", f"found {got}")

        minimum = {"customer_addresses": 55, "orders": 250, "order_items": 400,
                   "payments": 250, "order_discounts": 20, "deliveries": 200, "inventory": 80}
        for table, want in minimum.items():
            got = scalar(cur, f"SELECT COUNT(*) FROM {table}")
            record(got >= want, f"{table} has >= {want} rows", f"found {got}")

        months = scalar(cur, "SELECT COUNT(DISTINCT DATE_FORMAT(order_date, '%Y-%m')) FROM orders")
        record(months >= 6, "orders span >= 6 months", f"{months} months")

        methods = scalar(cur, "SELECT COUNT(DISTINCT method) FROM payments")
        record(methods == 4, "all 4 payment methods used", f"{methods}")
        for st in ("FAILED", "PENDING", "SUCCESS"):
            got = scalar(cur, "SELECT COUNT(*) FROM payments WHERE status = %s", (st,))
            record(got > 0, f"{st} payments exist", f"{got}")

        dstat = scalar(cur, "SELECT COUNT(DISTINCT status) FROM deliveries")
        record(dstat == 5, "all 5 delivery statuses present", f"{dstat}")
        ostat = scalar(cur, "SELECT COUNT(DISTINCT status) FROM orders")
        record(ostat == 5, "all 5 order statuses present", f"{ostat}")

        zero = scalar(cur, "SELECT COUNT(*) FROM customers c WHERE NOT EXISTS "
                           "(SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)")
        record(zero >= 5, "customers with zero orders exist", f"{zero}")
        repeat = scalar(cur, "SELECT COUNT(*) FROM (SELECT customer_id FROM orders "
                             "GROUP BY customer_id HAVING COUNT(*) > 1) t")
        record(repeat >= 20, "repeat customers (>1 order) exist", f"{repeat}")
        referred = scalar(cur, "SELECT COUNT(*) FROM customers WHERE referred_by IS NOT NULL")
        record(referred >= 10, "referred customers exist", f"{referred}")
        self_ref = scalar(cur, "SELECT COUNT(*) FROM customers WHERE referred_by = customer_id")
        record(self_ref == 0, "no customer refers themselves")

        depth3 = scalar(cur, "SELECT COUNT(*) FROM categories c JOIN categories p "
                             "ON c.parent_category_id = p.category_id "
                             "WHERE p.parent_category_id IS NOT NULL")
        record(depth3 > 0, "category tree has 3 levels", f"{depth3} level-3 categories")

        unsold = scalar(cur, "SELECT COUNT(*) FROM products p WHERE NOT EXISTS "
                             "(SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id)")
        record(unsold >= 2, "some products never sold", f"{unsold}")

        no_items = scalar(cur, "SELECT COUNT(*) FROM orders o WHERE NOT EXISTS "
                               "(SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)")
        record(no_items == 0, "every order has at least one item", f"{no_items} empty")

        old_price = scalar(cur, "SELECT COUNT(*) FROM order_items oi JOIN products p "
                                "USING (product_id) WHERE oi.unit_price <> p.price")
        record(old_price > 0, "some items sold at an older price", f"{old_price} rows")

        mismatched = scalar(cur, """
            SELECT COUNT(*) FROM (
                SELECT o.order_id,
                       (SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi
                         WHERE oi.order_id = o.order_id)
                     - COALESCE((SELECT SUM(od.amount_saved) FROM order_discounts od
                                  WHERE od.order_id = o.order_id), 0) AS expected,
                       (SELECT SUM(p.amount) FROM payments p
                         WHERE p.order_id = o.order_id AND p.status = 'SUCCESS') AS paid
                FROM orders o) t
            WHERE paid IS NOT NULL AND paid <> expected""")
        record(mismatched == 0, "paid amount = items total - discount", f"{mismatched} mismatched")

        cod_ref = scalar(cur, "SELECT COUNT(*) FROM payments WHERE method = 'COD' "
                              "AND transaction_ref IS NOT NULL")
        record(cod_ref == 0, "COD payments have no transaction ref")


def check_dml(conn):
    """Effects of 03_dml_operations.sql."""
    with conn.cursor() as cur:
        cur.execute("SELECT sku, price FROM products WHERE brand = 'boAt' ORDER BY sku")
        prices = {sku: float(p) for sku, p in cur.fetchall()}
        want = {"BOAT-AD141": 1364.0, "BOAT-PB20K": 1574.0, "BOAT-RK450": 1574.0}
        record(prices == want, "UPDATE raised boAt prices by 5%", str(prices))

        confirmed = scalar(cur, "SELECT COUNT(*) FROM orders o JOIN payments p "
                                "ON p.order_id = o.order_id "
                                "WHERE o.status = 'CONFIRMED' AND p.method = 'UPI' "
                                "AND p.status = 'SUCCESS' AND NOT EXISTS "
                                "(SELECT 1 FROM deliveries d WHERE d.order_id = o.order_id)")
        record(confirmed == 1, "UPDATE confirmed the pending UPI order", f"{confirmed}")
        placed_paid = scalar(cur, "SELECT COUNT(*) FROM orders o JOIN payments p "
                                  "ON p.order_id = o.order_id "
                                  "WHERE o.status = 'PLACED' AND p.status = 'SUCCESS'")
        record(placed_paid == 0, "no PLACED order has a successful payment")

        low = scalar(cur, "SELECT COUNT(*) FROM inventory WHERE warehouse_id = 1 "
                          "AND quantity < reorder_level")
        record(low == 0, "UPDATE restocked Bhiwandi below-reorder rows", f"{low} left")
        low_elsewhere = scalar(cur, "SELECT COUNT(*) FROM inventory WHERE quantity < reorder_level")
        record(low_elsewhere > 0, "other warehouses still have low stock", f"{low_elsewhere}")

        spam = scalar(cur, "SELECT COUNT(*) FROM customers WHERE email = 'spam.bot@example.in'")
        record(spam == 0, "DELETE removed the spam customer")
        coupon = scalar(cur, "SELECT COUNT(*) FROM discounts WHERE code = 'TEST50'")
        record(coupon == 0, "DELETE removed the test coupon")

        out = OUTPUT_DIR / "03_dml_operations.md"
        record(out.exists() and out.read_text(encoding="utf-8").count("## ") == 7,
               "7 SELECT results saved to outputs/03_dml_operations.md")


def check_tcl(conn):
    """Effects of 05_tcl_transactions.sql."""
    with conn.cursor() as cur:
        change = INVENTORY_CHANGES.get("05_tcl_transactions.sql")
        want = {("ONP-NB2", 3): -1, ("SPG-CASE", 3): -2,   # case 1 committed
                ("JBL-760NC", 3): -1,                      # case 4 kept item 1
                ("PGN-KTL", 1): -2}                        # procedure call 1
        record(change == want, "stock changed ONLY for committed orders",
               f"changes={change}")
        for sku in ("BK-ATOMIC", "RDM-N13P", "SNY-XM5"):
            record(change is not None and not any(k[0] == sku for k in change),
                   f"rolled-back {sku} stock is unchanged")

        def orders_at(ts):
            return scalar(cur, "SELECT COUNT(*) FROM orders WHERE order_date = %s", (ts,))

        record(orders_at("2026-11-20 10:00:00") == 1, "case 1: order committed")
        items = scalar(cur, "SELECT COUNT(*) FROM order_items oi JOIN orders o USING (order_id) "
                            "WHERE o.order_date = '2026-11-20 10:00:00'")
        record(items == 2, "case 1: order has 2 items", f"{items}")
        paid = scalar(cur, "SELECT p.amount FROM payments p JOIN orders o USING (order_id) "
                           "WHERE o.order_date = '2026-11-20 10:00:00' AND p.status = 'SUCCESS'")
        record(paid is not None and float(paid) == 4097.0, "case 1: payment = 2299 + 2 x 899", f"{paid}")
        record(orders_at("2026-11-20 10:15:00") == 0, "case 2: payment-failed order rolled back")
        record(orders_at("2026-11-20 10:30:00") == 0, "case 3: no-stock order rolled back")

        cur.execute("SELECT p.sku FROM order_items oi JOIN orders o USING (order_id) "
                    "JOIN products p ON p.product_id = oi.product_id "
                    "WHERE o.order_date = '2026-11-20 10:45:00'")
        skus = [r[0] for r in cur.fetchall()]
        record(skus == ["JBL-760NC"], "case 4: ROLLBACK TO SAVEPOINT kept only item 1", f"{skus}")

        price = scalar(cur, "SELECT price FROM products WHERE sku = 'PGN-KTL'")
        record(float(price) == 699.0, "case 5: autocommit=0 change was rolled back", f"{price}")
        city = scalar(cur, "SELECT city FROM warehouses WHERE warehouse_id = 3")
        record(city == "Bengaluru", "case 5: warehouse city restored", city)
        record(scalar(cur, "SELECT @@autocommit") == 1, "session ends with autocommit = 1")

        proc = scalar(cur, "SELECT COUNT(*) FROM information_schema.routines "
                           "WHERE routine_schema = DATABASE() AND routine_name = 'sp_place_order'")
        record(proc == 1, "procedure sp_place_order exists")
        record(orders_at("2026-11-20 12:00:00") == 1, "procedure: only the good call committed")
        cur.execute("SELECT @call1, @call2, @call3")
        r1, r2, r3 = cur.fetchone()
        record((r1 or "").startswith("COMMITTED order"), "procedure call 1 committed", r1)
        record(r2 == "ROLLED BACK: insufficient stock", "procedure call 2 rolled back (stock)", r2)
        record(r3 == "ROLLED BACK: payment FAILED", "procedure call 3 rolled back (payment)", r3)


def check_joins():
    """Results of 06_joins.sql (read from the saved query results)."""
    def col(cols, rows, name):
        i = cols.index(name)
        return [r[i] for r in rows]

    cols, rows = result("J1 ")
    record(rows is not None and len(rows) == 40, "J1 INNER JOIN: 40 products with category",
           f"{None if rows is None else len(rows)}")
    cols, rows = result("J2 ")
    record(rows is not None and len(rows) == 10, "J2 INNER JOIN: top 10 orders")

    cols, rows = result("J3 ")
    zeros = None if rows is None else col(cols, rows, "orders_placed").count(0)
    record(rows is not None and len(rows) == 50 and zeros == 6,
           "J3 LEFT JOIN: 50 customers, 6 with zero orders", f"zero={zeros}")

    cols, rows = result("J4 ")
    skus = None if rows is None else sorted(col(cols, rows, "sku"))
    record(skus == ["AJT-CLK", "APL-MBA-M3"], "J4 anti-join: never-sold products", f"{skus}")

    cols, rows = result("J5 ")
    used = None if rows is None else dict(zip(col(cols, rows, "code"), col(cols, rows, "times_used")))
    record(used is not None and len(used) == 6 and used.get("SUMMER25") == 0,
           "J5 RIGHT JOIN: all 6 coupons, SUMMER25 unused", f"{used}")

    cols, rows = result("J6 ")
    left_only = rows is not None and any(r[2] is None for r in rows)
    right_only = rows is not None and any(r[0] is None for r in rows)
    record(left_only and right_only, "J6 FULL OUTER: unmatched rows on BOTH sides",
           f"left-only={left_only} right-only={right_only}")

    cols, rows = result("J7 ")
    tops = None if rows is None else col(cols, rows, "parent_category").count(None)
    record(rows is not None and len(rows) == 23 and tops == 4,
           "J7 SELF JOIN: 23 categories, 4 top-level", f"top={tops}")
    cols, rows = result("J8 ")
    record(rows is not None and len(rows) == 9, "J8 SELF JOIN: 9 three-level paths",
           f"{None if rows is None else len(rows)}")
    cols, rows = result("J9 ")
    record(rows is not None and len(rows) == 15, "J9 SELF JOIN: 15 referral pairs",
           f"{None if rows is None else len(rows)}")

    cols, rows = result("J10 ")
    record(bool(rows) and len(cols) == 11, "J10 8-table JOIN returns recent orders",
           f"{None if rows is None else len(rows)} rows")
    cols, rows = result("J11 ")
    cats = set() if rows is None else set(col(cols, rows, "category"))
    record(None not in cats and len(cats) == 4, "J11 revenue by category and method",
           f"categories={sorted(c for c in cats if c)}")
    cols, rows = result("J12 ")
    record(rows is not None and len(rows) == 20, "J12 CROSS JOIN: 120 - 100 = 20 unstocked pairs",
           f"{None if rows is None else len(rows)}")


def check_subqueries(conn):
    """Each subquery result is compared with an independent JOIN / GROUP BY version."""
    def rows_of(prefix):
        cols, rows = result(prefix)
        return cols, (rows or [])

    def same(label, prefix, key_col, alt_sql):
        cols, rows = rows_of(prefix)
        got = sorted(r[cols.index(key_col)] for r in rows) if cols else None
        with conn.cursor() as cur:
            cur.execute(alt_sql)
            want = sorted(r[0] for r in cur.fetchall())
        record(got == want and len(want) > 0, label, f"{len(want)} rows")

    same("S1 IN = JOIN version (Apple buyers)", "S1 ", "customer_id",
         "SELECT DISTINCT o.customer_id FROM orders o JOIN order_items oi USING (order_id) "
         "JOIN products p USING (product_id) WHERE p.brand = 'Apple'")
    same("S2 NOT IN = LEFT JOIN version", "S2 ", "product_id",
         "SELECT p.product_id FROM products p LEFT JOIN (SELECT DISTINCT oi.product_id "
         "FROM order_items oi JOIN orders o USING (order_id) WHERE o.order_date >= '2026-11-01') s "
         "USING (product_id) WHERE s.product_id IS NULL AND p.is_active = TRUE")
    same("S3 scalar = JOIN with average", "S3 ", "product_id",
         "SELECT p.product_id FROM products p CROSS JOIN (SELECT AVG(price) a FROM products) t "
         "WHERE p.price > t.a")
    cols, rows = rows_of("S4 ")
    record(len(rows) == 40, "S4 scalar in SELECT: 40 products")
    same("S5 nested = JOIN version (best category buyers)", "S5 ", "customer_id",
         "SELECT DISTINCT o.customer_id FROM orders o JOIN order_items oi USING (order_id) "
         "JOIN products p USING (product_id) WHERE p.category_id = (SELECT category_id FROM "
         "(SELECT p2.category_id, SUM(oi2.quantity) u FROM order_items oi2 JOIN products p2 "
         "USING (product_id) GROUP BY p2.category_id ORDER BY u DESC LIMIT 1) b)")

    with conn.cursor() as cur:
        max_book = float(scalar(cur, "SELECT MAX(price) FROM products WHERE category_id IN (22, 23)"))
    cols, rows = rows_of("S6a ")
    record(bool(rows) and all(float(r[1]) > max_book for r in rows),
           "S6a > ALL: every price above the costliest book", f"max book {max_book}")
    cols, rows = rows_of("S6b ")
    record(bool(rows) and all(float(r[1]) < max_book for r in rows),
           "S6b < ANY: every price below the costliest book", f"{len(rows)} rows")

    cols, rows = rows_of("S7 ")
    record(bool(rows) and all(float(r[2]) > float(r[3]) for r in rows),
           "S7 correlated: each price > its category average")
    same("S7 correlated = derived-table JOIN version", "S7 ", "product_name",
         "SELECT p.product_name FROM products p JOIN (SELECT category_id, AVG(price) a FROM "
         "products GROUP BY category_id) c USING (category_id) WHERE p.price > c.a")
    same("S8 latest order = GROUP BY MAX version (44 customers)", "S8 ", "order_id",
         "SELECT o.order_id FROM orders o JOIN (SELECT customer_id, MAX(order_date) m FROM orders "
         "GROUP BY customer_id) t ON t.customer_id = o.customer_id AND t.m = o.order_date")
    cols, rows = rows_of("S8 ")
    record(len(rows) == 44 and len({r[0] for r in rows}) == 44,
           "S8 one latest order per ordering customer", f"{len(rows)} rows")

    cols, rows = rows_of("S9 ")
    spends = [float(r[3]) for r in rows]
    record(len(rows) == 15 and spends == sorted(spends, reverse=True) and spends[0] > 0,
           "S9 top 15 customers by spend, sorted")
    same("S10 correlated = derived-table JOIN version", "S10 ", "order_id",
         "SELECT v.order_id FROM (SELECT o.order_id, o.customer_id, SUM(oi.quantity * oi.unit_price) val "
         "FROM orders o JOIN order_items oi USING (order_id) GROUP BY o.order_id, o.customer_id) v "
         "JOIN (SELECT o.customer_id, SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id) a "
         "FROM orders o JOIN order_items oi USING (order_id) GROUP BY o.customer_id) c "
         "USING (customer_id) WHERE v.val > c.a")
    same("S11 EXISTS = JOIN + DISTINCT version", "S11 ", "customer_id",
         "SELECT DISTINCT o.customer_id FROM orders o JOIN payments p USING (order_id) "
         "WHERE p.status = 'FAILED'")
    cols, rows = rows_of("S12 ")
    _, j3 = result("J3 ")
    zero_j3 = sorted(r[0] for r in (j3 or []) if r[3] == 0)
    record(sorted(r[0] for r in rows) == zero_j3 and len(rows) == 6,
           "S12 NOT EXISTS = the 6 zero-order customers of J3")

    cols, rows = rows_of("S13 ")
    segs = sorted(r[0] for r in rows)
    record(segs == ["High", "Low", "Medium"] and sum(r[1] for r in rows) == 44,
           "S13 derived tables: 3 segments covering 44 customers", f"{segs}")
    cols, rows = rows_of("S14 ")
    record(0 < len(rows) < 7, "S14 some (not all) months above average", f"{[r[0] for r in rows]}")


def check_set_operations(conn):
    """Results of 08_set_operations.sql, cross-checked against each other."""
    def ids(prefix, col=0):
        _, rows = result(prefix)
        return None if rows is None else sorted(r[col] for r in rows)

    e1, e1b, e1c = ids("E1 "), ids("E1b "), ids("E1c ")
    record(bool(e1) and e1 == e1b == e1c, "E1 EXCEPT = NOT EXISTS = LEFT JOIN IS NULL",
           f"{None if e1 is None else len(e1)} customers")
    i1, i1b = ids("I1 "), ids("I1b ")
    record(bool(i1) and i1 == i1b, "I1 INTERSECT = IN version", f"{None if i1 is None else len(i1)} customers")

    u1 = ids("U1 ")
    _, u2 = result("U2 ")
    record(u1 is not None and u2 is not None and len(u2) - len(u1) == len(i1 or []) > 0,
           "UNION ALL - UNION = customers counted twice (= INTERSECT)",
           f"union={len(u1 or [])} union_all={len(u2 or [])} both={len(i1 or [])}")
    _, u3 = result("U3 ")
    counts = {r[0]: r[1] for r in (u3 or [])}
    record(counts.get("UNION (duplicates removed)") == len(u1 or []) and
           counts.get("UNION ALL (duplicates kept)") == len(u2 or []),
           "U3 counts match U1 and U2", f"{counts}")

    cities = ids("U4 ")
    with conn.cursor() as cur:
        cur.execute("SELECT DISTINCT city FROM customer_addresses WHERE is_default = TRUE "
                    "UNION SELECT city FROM warehouses")
        want = sorted(r[0] for r in cur.fetchall())
    record(cities == want and "Gurugram" in (cities or []), "U4 UNION of customer and warehouse cities",
           f"{len(cities or [])} cities")

    i2 = ids("I2 ")
    with conn.cursor() as cur:
        cur.execute("SELECT oi.product_id FROM order_items oi JOIN orders o USING (order_id) "
                    "GROUP BY oi.product_id "
                    "HAVING SUM(o.order_date >= '2026-10-01' AND o.order_date < '2026-11-01') > 0 "
                    "   AND SUM(o.order_date >= '2026-11-01') > 0")
        want = sorted(r[0] for r in cur.fetchall())
    record(bool(i2) and i2 == want, "I2 INTERSECT = GROUP BY HAVING version", f"{len(i2 or [])} products")

    e2 = ids("E2 ", 1)
    record(e2 == ["AJT-CLK", "APL-MBA-M3"], "E2 EXCEPT: never-sold products", f"{e2}")


def check_analytics(conn):
    """Results of 09_customer_product_analytics.sql, reconciled with each other."""
    NET = ("SELECT {cols} FROM payments p JOIN orders o USING (order_id) "
           "WHERE p.status = 'SUCCESS' AND o.status <> 'CANCELLED'")
    with conn.cursor() as cur:
        total = float(scalar(cur, NET.format(cols="SUM(p.amount)")))
        paid_orders = scalar(cur, NET.format(cols="COUNT(*)"))
        repeat_n = scalar(cur, "SELECT COUNT(*) FROM (SELECT customer_id FROM orders "
                               "GROUP BY customer_id HAVING COUNT(*) > 1) t")
        cur.execute("SELECT oi.product_id FROM order_items oi JOIN orders o USING (order_id) "
                    "WHERE o.status <> 'CANCELLED' GROUP BY oi.product_id "
                    "ORDER BY SUM(oi.quantity) DESC, SUM(oi.quantity * oi.unit_price) DESC LIMIT 1")
        top_qty = cur.fetchone()[0]
        cur.execute("SELECT oi.product_id FROM order_items oi JOIN orders o USING (order_id) "
                    "WHERE o.status <> 'CANCELLED' GROUP BY oi.product_id "
                    "ORDER BY SUM(oi.quantity * oi.unit_price) DESC LIMIT 1")
        top_rev = cur.fetchone()[0]
        cur.execute("SELECT p.category_id, MAX(u) FROM (SELECT oi.product_id, SUM(oi.quantity) u "
                    "FROM order_items oi JOIN orders o USING (order_id) WHERE o.status <> 'CANCELLED' "
                    "GROUP BY oi.product_id) s JOIN products p USING (product_id) GROUP BY p.category_id")
        cat_max = {cid: m for cid, m in cur.fetchall()}
        cur.execute("SELECT category_id, category_name FROM categories")
        cat_name = {cid: n for cid, n in cur.fetchall()}
        saved_total = float(scalar(cur, "SELECT SUM(amount_saved) FROM order_discounts"))

    cols, rows = result("A1 ")
    rows = rows or []
    record(len(rows) == repeat_n and all(r[2] > 1 for r in rows) and repeat_n >= 20,
           "A1 repeat customers = HAVING COUNT > 1 version", f"{len(rows)} customers")
    _, a2 = result("A2 ")
    record(bool(a2) and a2[0][1] == repeat_n, "A2 repeat rate uses the same repeat count",
           f"{a2[0][3] if a2 else None}%")
    _, a3 = result("A3 ")
    spends = [float(r[4]) for r in (a3 or [])]
    record(len(spends) == 10 and spends == sorted(spends, reverse=True), "A3 top 10 spenders, sorted")
    _, a4 = result("A4 ")
    record(sorted(r[0] for r in (a4 or [])) == ["Direct", "Referred"] and
           sum(r[1] for r in a4) == 50, "A4 referred + direct = 50 customers")

    _, b1 = result("B1 ")
    record(bool(b1) and b1[0][0] == top_qty, "B1 rank-1 by quantity matches independent query",
           f"{b1[0][1] if b1 else None}")
    _, b2 = result("B2 ")
    record(bool(b2) and b2[0][0] == top_rev, "B2 rank-1 by revenue matches independent query",
           f"{b2[0][1] if b2 else None}")
    record(bool(b1) and bool(b2) and b1[0][0] != b2[0][0],
           "B1 and B2 have different winners (units vs money)")
    _, b3 = result("B3 ")
    by_name = {}
    for cat, _, units in (b3 or []):
        by_name.setdefault(cat, set()).add(units)
    want = {cat_name[c]: {m} for c, m in cat_max.items()}
    record(by_name == want, "B3 best seller per category = category maximum",
           f"{len(by_name)} categories")
    _, b4 = result("B4 ")
    record(bool(b4) and len(b4) == 10, "B4 stock shown for the top 10 sellers")

    _, c1 = result("C1 ")
    ok = bool(c1) and c1[0][0] == paid_orders and abs(float(c1[0][1]) - total) < 0.01 \
        and abs(float(c1[0][2]) - total / paid_orders) < 0.01
    record(ok, "C1 AOV = net revenue / paid orders", f"AOV {c1[0][2] if c1 else None}")
    _, c2 = result("C2 ")
    c2_total = sum(float(r[2]) for r in (c2 or []))
    c2_share = sum(float(r[4]) for r in (c2 or []))
    record(len(c2 or []) == 4 and abs(c2_total - total) < 0.01 and abs(c2_share - 100) < 0.05,
           "C2 revenue by method adds up to net revenue (and 100%)", f"{c2_total:.2f}")
    _, c3 = result("C3 ")
    record(bool(c3) and sum(r[1] for r in c3) == sum(r[2] + r[3] + r[4] for r in c3),
           "C3 attempts = succeeded + failed + pending")
    _, c4 = result("C4 ")
    c4_total = sum(float(r[2]) for r in (c4 or []))
    record(len(c4 or []) >= 6 and abs(c4_total - total) < 0.01,
           "C4 monthly revenue adds up to net revenue", f"{len(c4 or [])} months")
    cols, c5 = result("C5 ")
    outcomes = {r[4] for r in (c5 or [])}
    record(outcomes == {"Recovered on retry", "Money pending", "Failed - order cancelled"},
           "C5 shows all 3 payment-trouble outcomes", f"{len(c5 or [])} orders")
    _, c6 = result("C6 ")
    record(bool(c6) and all(r[4] not in ("DELIVERED", "CANCELLED") for r in c6),
           "C6 only undelivered live orders", f"{len(c6 or [])} orders")
    _, c7 = result("C7 ")
    record(bool(c7) and len(c7) == 5, "C7 all 5 couriers")

    _, d1 = result("D1 ")
    d1_total = sum(float(r[5]) for r in (d1 or []))
    record(len(d1 or []) == 6 and abs(d1_total - saved_total) < 0.01,
           "D1 coupon savings add up to order_discounts total", f"{d1_total:.2f}")
    _, d2 = result("D2 ")
    record(bool(d2) and sum(r[1] for r in d2) == paid_orders,
           "D2 coupon + no-coupon orders = all paid orders")


def check_views(conn):
    """Results of 10_views.sql."""
    views = ["vw_active_products", "vw_customer_lifetime_value", "vw_order_summary",
             "vw_pending_deliveries", "vw_product_sales"]
    with conn.cursor() as cur:
        cur.execute("SELECT table_name, is_updatable, check_option FROM information_schema.views "
                    "WHERE table_schema = DATABASE() ORDER BY table_name")
        found = cur.fetchall()
        record([r[0] for r in found] == views, "5 views exist", f"{[r[0] for r in found]}")
        info = {r[0]: (r[1], r[2]) for r in found}
        record(info.get("vw_active_products") == ("YES", "CASCADED"),
               "vw_active_products is updatable WITH CASCADED CHECK OPTION", f"{info.get('vw_active_products')}")
        for v in views:
            n = scalar(cur, f"SELECT COUNT(*) FROM {v}")
            record(n > 0, f"{v} returns rows", f"{n}")

        orders = scalar(cur, "SELECT COUNT(*) FROM orders")
        summary = scalar(cur, "SELECT COUNT(*) FROM vw_order_summary")
        record(orders == summary, "vw_order_summary: one row per order", f"{summary}/{orders}")
        mismatch = scalar(cur, "SELECT COUNT(*) FROM vw_order_summary "
                               "WHERE payment_status = 'PAID' AND net_paid <> payable")
        record(mismatch == 0, "vw_order_summary: paid orders paid exactly the payable amount")

        net = float(scalar(cur, "SELECT SUM(p.amount) FROM payments p JOIN orders o USING (order_id) "
                                "WHERE p.status = 'SUCCESS' AND o.status <> 'CANCELLED'"))
        ltv = float(scalar(cur, "SELECT SUM(lifetime_value) FROM vw_customer_lifetime_value"))
        record(abs(net - ltv) < 0.01, "lifetime values add up to net revenue", f"{ltv:.2f}")
        record(scalar(cur, "SELECT COUNT(*) FROM vw_customer_lifetime_value") == 50,
               "vw_customer_lifetime_value covers all 50 customers")
        segs = scalar(cur, "SELECT COUNT(DISTINCT segment) FROM vw_customer_lifetime_value")
        record(segs == 4, "4 customer segments (High/Medium/Low/No purchase)", f"{segs}")

        sold = scalar(cur, "SELECT SUM(units_sold) FROM vw_product_sales")
        want = scalar(cur, "SELECT SUM(oi.quantity) FROM order_items oi JOIN orders o USING (order_id) "
                           "WHERE o.status <> 'CANCELLED'")
        record(sold == want, "vw_product_sales units = order_items units", f"{sold}")
        pend = scalar(cur, "SELECT COUNT(*) FROM vw_pending_deliveries")
        _, c6 = result("C6 ")
        record(pend == len(c6 or []), "vw_pending_deliveries = C6 undelivered orders", f"{pend}")

        price = scalar(cur, "SELECT price FROM products WHERE sku = 'PGN-KTL'")
        record(float(price) == 699.0, "price updated through view was restored", f"{price}")
        _, v5 = result("V5 ")
        record(bool(v5) and float(v5[0][1]) == 649.0, "UPDATE through the view reached products")


def check_indexes(conn):
    """Results of 11_indexes.sql: indexes exist and EXPLAIN changed as expected."""
    want = {("payments", "idx_payments_status_method"), ("orders", "idx_orders_date"),
            ("orders", "idx_orders_customer_date"), ("deliveries", "idx_deliveries_status"),
            ("products", "idx_products_brand")}
    with conn.cursor() as cur:
        cur.execute("SELECT DISTINCT table_name, index_name FROM information_schema.statistics "
                    "WHERE table_schema = DATABASE() AND index_name LIKE 'idx\\_%'")
        found = {(t, i) for t, i in cur.fetchall()}
    record(found == want, "5 new indexes exist", f"{sorted(i for _, i in found)}")

    def plan(prefix):
        cols, rows = result(prefix)
        if not rows:
            return {}
        return dict(zip(cols, rows[0]))

    b, a = plan("X1 EXPLAIN BEFORE"), plan("X1 EXPLAIN AFTER")
    record(b.get("type") == "ALL" and b.get("key") is None,
           "X1 before: full table scan on payments", f"type={b.get('type')} rows={b.get('rows')}")
    record(a.get("type") == "ref" and a.get("key") == "idx_payments_status_method"
           and (a.get("rows") or 0) < (b.get("rows") or 0),
           "X1 after: ref lookup via idx_payments_status_method, fewer rows",
           f"type={a.get('type')} rows={a.get('rows')}")

    b, a = plan("X2 EXPLAIN BEFORE"), plan("X2 EXPLAIN AFTER")
    record(b.get("type") == "ALL", "X2 before: full table scan on orders",
           f"type={b.get('type')} rows={b.get('rows')}")
    record(a.get("type") == "range" and a.get("key") == "idx_orders_date"
           and (a.get("rows") or 0) < (b.get("rows") or 0),
           "X2 after: range scan via idx_orders_date, fewer rows",
           f"type={a.get('type')} rows={a.get('rows')}")

    b, a = plan("X3 EXPLAIN BEFORE"), plan("X3 EXPLAIN AFTER")
    record("filesort" in (b.get("Extra") or ""), "X3 before: needs a filesort", b.get("Extra"))
    record(a.get("key") == "idx_orders_customer_date" and "filesort" not in (a.get("Extra") or ""),
           "X3 after: composite index, no filesort", f"key={a.get('key')} extra={a.get('Extra')}")

    x4 = plan("X4 ")
    record(x4.get("type") == "ALL", "X4 function on column: index not used",
           f"type={x4.get('type')}")


def check_window_ctes(conn):
    """Results of 12_window_functions_ctes.sql."""
    def rows_of(prefix):
        cols, rows = result(prefix)
        return cols or [], rows or []

    # W1: ROW_NUMBER unique, RANK with gaps after ties, DENSE_RANK without gaps
    cols, rows = rows_of("W1 ")
    units = [r[2] for r in rows]
    rn, rk, dr = ([r[i] for r in rows] for i in (3, 4, 5))
    record(rn == list(range(1, len(rows) + 1)) and len(rows) == 38,
           "W1 ROW_NUMBER is 1..n with no repeats", f"{len(rows)} products")
    ties = len(units) != len(set(units))
    exp_rank = [1 + sum(u > x for u in units) for x in units]
    distinct_sorted = sorted(set(units), reverse=True)
    exp_dense = [distinct_sorted.index(x) + 1 for x in units]
    record(ties and rk == exp_rank, "W1 RANK: ties share a rank, then a gap", f"max rank {max(rk or [0])}")
    record(dr == exp_dense and max(dr) < max(rk), "W1 DENSE_RANK: ties share a rank, no gap",
           f"max dense {max(dr or [0])}")

    # W2b (RANK = 1) must match B3 from file 09; W3 (ROW_NUMBER = 1) has one row per category
    _, b3 = result("B3 ")
    _, w2b = rows_of("W2b ")
    record(sorted((r[0], r[1]) for r in w2b) == sorted((r[0], r[1]) for r in (b3 or [])),
           "W2b RANK=1 per category = B3 (no window function) result", f"{len(w2b)} rows")
    _, w3 = rows_of("W3 ")
    record(len(w3) == len({r[0] for r in w2b}) == len({r[0] for r in w3}),
           "W3 ROW_NUMBER=1: exactly one product per category", f"{len(w3)} categories")
    _, w2 = rows_of("W2 ")
    record(sum(1 for r in w2 if r[4] == 1) >= len(w3), "W2 PARTITION BY restarts rank at 1 per category")

    with conn.cursor() as cur:
        net = float(scalar(cur, "SELECT SUM(p.amount) FROM payments p JOIN orders o USING (order_id) "
                                "WHERE p.status = 'SUCCESS' AND o.status <> 'CANCELLED'"))
    _, w4 = rows_of("W4 ")
    running = [float(r[2]) for r in w4]
    record(bool(running) and running == sorted(running) and abs(running[-1] - net) < 0.01
           and float(w4[-1][3]) == 100.0, "W4 running total never falls and ends at net revenue",
           f"{running[-1] if running else None}")
    _, w5 = rows_of("W5 ")
    ok = bool(w5) and w5[0][3] is None and all(
        abs(float(w5[i][3]) - float(w5[i - 1][2])) < 0.01 for i in range(1, len(w5)))
    record(ok, "W5 LAG: first month NULL, each row sees the previous month")
    _, w6 = rows_of("W6 ")
    rev = [float(r[1]) for r in w6]
    exp = [round(sum(rev[max(0, i - 2):i + 1]) / len(rev[max(0, i - 2):i + 1]), 2) for i in range(len(rev))]
    record(bool(w6) and all(abs(float(r[2]) - e) < 0.01 for r, e in zip(w6, exp)),
           "W6 3-month moving average is correct")

    _, w7 = rows_of("W7 ")
    sizes = [sum(1 for r in w7 if r[3] == q) for q in (1, 2, 3, 4)]
    with conn.cursor() as cur:
        paying = scalar(cur, "SELECT COUNT(*) FROM vw_customer_lifetime_value WHERE lifetime_value > 0")
    record(len(w7) == paying and max(sizes) - min(sizes) <= 1,
           "W7 NTILE(4): every paying customer in 4 near-equal groups", f"{sizes} of {paying}")
    _, w7b = rows_of("W7b ")
    record(len(w7b) == 4 and abs(sum(float(r[5]) for r in w7b) - 100) < 0.2,
           "W7b quartile shares add up to 100%")
    _, w8 = rows_of("W8 ")
    _, a1 = result("A1 ")
    record(len(w8) == len(a1 or []), "W8 LEAD gaps for every repeat customer", f"{len(w8)}")
    _, w9 = rows_of("W9 ")
    record(len(w9) == 15 and float(w9[0][4]) == 1.0, "W9 top product has PERCENT_RANK 1")

    _, t1 = rows_of("T1 ")
    record(len({r[0] for r in t1}) == 7, "T1 a top product for each of the 7 months", f"{len(t1)} rows")
    _, t2 = rows_of("T2 ")
    record(sum(r[1] for r in t2) == 44, "T2 cohorts cover all 44 ordering customers")
    _, t3 = rows_of("T3 ")
    _, s14 = result("S14 ")
    record([r[0] for r in t3] == [r[0] for r in (s14 or [])] and len(t3) > 0,
           "T3 CTE gives the same months as S14 (derived tables)")

    _, r1 = rows_of("R1 ")
    levels = [r[2] for r in r1]
    record(len(r1) == 23 and max(levels) == 3 and levels.count(3) == 9,
           "R1 recursive tree: 23 categories, 3 levels, 9 leaf paths", f"{len(r1)} rows")
    _, r2 = rows_of("R2 ")
    with conn.cursor() as cur:
        units_all = scalar(cur, "SELECT SUM(oi.quantity) FROM order_items oi JOIN orders o USING (order_id) "
                                "WHERE o.status <> 'CANCELLED'")
    record(len(r2) == 4 and sum(r[3] for r in r2) == units_all,
           "R2 roll-up: 4 top-level categories, units add up", f"{units_all}")
    _, r3 = rows_of("R3 ")
    record(len(r3) == 15 and max(r[1] for r in r3) >= 1, "R3 referral chains reach all 15 referred customers",
           f"max depth {max((r[1] for r in r3), default=0)}")


def check_demo(conn):
    """demo/demo_script.sql must run without errors and leave the data unchanged."""
    tables = ["customers", "products", "orders", "order_items", "payments", "inventory", "deliveries"]

    def fingerprint():
        with conn.cursor() as cur:
            counts = {t: scalar(cur, f"SELECT COUNT(*) FROM {t}") for t in tables}
            counts["stock_total"] = scalar(cur, "SELECT SUM(quantity) FROM inventory")
            return counts

    before = fingerprint()
    statements = split_sql((ROOT / "demo" / "demo_script.sql").read_text(encoding="utf-8"))
    error = None
    with conn.cursor() as cur:
        for idx, (_, stmt) in enumerate(statements, 1):
            try:
                cur.execute(stmt)
                if cur.description:
                    cur.fetchall()
            except pymysql.MySQLError as e:
                error = f"statement {idx}: {e.args}"
                break
    record(error is None, "demo script runs end to end without errors",
           error or f"{len(statements)} statements")
    record(fingerprint() == before, "demo script leaves the data unchanged (ROLLBACK worked)")


def check_dcl(cfg, db):
    """Log in as each project user and check what is allowed and denied."""
    TABLE_DENIED, COLUMN_DENIED = 1142, 1143
    admin = connect(cfg, db)
    with admin.cursor() as cur:
        roles = scalar(cur, "SELECT COUNT(*) FROM mysql.user WHERE user IN "
                            "('r_admin', 'r_order_clerk', 'r_analyst') AND account_locked = 'Y'")
        record(roles == 3, "3 roles exist", f"{roles}")
        edges = scalar(cur, "SELECT COUNT(*) FROM mysql.role_edges WHERE "
                            "(from_user, to_user) IN (('r_admin', 'db_admin'), "
                            "('r_order_clerk', 'order_clerk'), ('r_analyst', 'analyst'))")
        record(edges == 3, "each user has its role", f"{edges}")
        defaults = scalar(cur, "SELECT COUNT(*) FROM mysql.default_roles WHERE user IN "
                               "('db_admin', 'order_clerk', 'analyst')")
        record(defaults == 3, "each user has a default role", f"{defaults}")
    admin.close()

    missing = {"db_admin", "order_clerk", "analyst"} - set(GENERATED_PASSWORDS)
    if missing:
        record(False, "random passwords captured for all users", f"missing {sorted(missing)}")
        return
    record(True, "random passwords captured (kept in memory only)")

    def as_user(user):
        return pymysql.connect(host=cfg["DB_HOST"] or "127.0.0.1", port=int(cfg["DB_PORT"] or 3306),
                               user=user, password=GENERATED_PASSWORDS[user], database=db,
                               charset="utf8mb4", autocommit=False, connect_timeout=10)

    def attempt(conn, label, sql, expect_ok, deny_codes=(TABLE_DENIED, COLUMN_DENIED)):
        with conn.cursor() as cur:
            try:
                cur.execute(sql)
                if cur.description:
                    cur.fetchall()
                record(expect_ok, label, "allowed" if expect_ok else "was ALLOWED")
            except pymysql.MySQLError as e:
                ok = (not expect_ok) and e.args[0] in deny_codes
                record(ok, label, f"MySQL error {e.args[0]}")
            finally:
                conn.rollback()

    try:
        conns = {u: as_user(u) for u in ("db_admin", "order_clerk", "analyst")}
    except pymysql.MySQLError as e:
        record(False, "log in as project users", f"{e.args}")
        return
    record(True, "log in as db_admin, order_clerk, analyst")

    a, c, n = conns["analyst"], conns["order_clerk"], conns["db_admin"]
    attempt(n, "db_admin: can DELETE (inside rolled-back txn)", "DELETE FROM payments WHERE 1 = 0", True)
    attempt(n, "db_admin: can ALTER schema", "ALTER TABLE warehouses COMMENT = 'admin test'", True)

    attempt(c, "clerk: can SELECT products", "SELECT COUNT(*) FROM products", True)
    attempt(c, "clerk: can INSERT an order",
            "INSERT INTO orders (customer_id) VALUES (1)", True)
    attempt(c, "clerk: can UPDATE inventory.quantity",
            "UPDATE inventory SET quantity = quantity WHERE product_id = 1", True)
    attempt(c, "clerk: denied UPDATE inventory.reorder_level",
            "UPDATE inventory SET reorder_level = 5 WHERE product_id = 1", False)
    attempt(c, "clerk: denied UPDATE products.price",
            "UPDATE products SET price = 1 WHERE product_id = 1", False)
    attempt(c, "clerk: denied DELETE orders (after REVOKE)",
            "DELETE FROM orders WHERE order_id = 1001", False)

    # After 10_views.sql the analyst is view-only.
    for view in ("vw_order_summary", "vw_product_sales", "vw_customer_lifetime_value",
                 "vw_pending_deliveries"):
        attempt(a, f"analyst: can SELECT {view}", f"SELECT COUNT(*) FROM {view}", True)
    attempt(a, "analyst: denied SELECT on base table orders", "SELECT COUNT(*) FROM orders", False)
    attempt(a, "analyst: denied SELECT on base table customers", "SELECT email FROM customers", False)
    attempt(a, "analyst: denied the clerk's updatable view",
            "SELECT COUNT(*) FROM vw_active_products", False)
    attempt(c, "clerk: can UPDATE price THROUGH vw_active_products",
            "UPDATE vw_active_products SET price = price WHERE sku = 'PGN-KTL'", True)
    attempt(c, "clerk: CHECK OPTION rejects deactivating via the view",
            "UPDATE vw_active_products SET is_active = FALSE WHERE sku = 'PGN-KTL'", False,
            deny_codes=(1369,))
    attempt(a, "analyst: denied INSERT",
            "INSERT INTO customers (full_name, email, phone) VALUES ('X', 'x@example.in', '9000000002')", False)
    attempt(a, "analyst: denied UPDATE", "UPDATE products SET price = 1 WHERE product_id = 1", False)
    attempt(a, "analyst: denied DELETE", "DELETE FROM payments WHERE 1 = 0", False)
    for conn in conns.values():
        conn.close()

    # ALTER TABLE ... COMMENT is DDL (auto-commit); put the comment back.
    admin = connect(cfg, db)
    with admin.cursor() as cur:
        cur.execute("ALTER TABLE warehouses COMMENT = ''")
    admin.close()


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
        print("Seed data checks:")
        check_seed(conn)
        print("DML checks:")
        check_dml(conn)
        print("TCL checks:")
        check_tcl(conn)
        print("Join checks:")
        check_joins()
        print("Subquery checks:")
        check_subqueries(conn)
        print("Set operation checks:")
        check_set_operations(conn)
        print("Analytics checks:")
        check_analytics(conn)
        print("View checks:")
        check_views(conn)
        print("Index checks:")
        check_indexes(conn)
        print("Window function and CTE checks:")
        check_window_ctes(conn)
        print("DCL checks:")
        check_dcl(cfg, db)
        print("Constraint checks:")
        check_constraints(conn)
        print("Demo script checks:")
        check_demo(conn)
    conn.close()

    passed = sum(1 for s, _, _ in RESULTS if s == "PASS")
    failed = len(RESULTS) - passed
    print("\n" + "=" * 50)
    print(f"SUMMARY: {passed} passed, {failed} failed -> {'ALL PASS' if failed == 0 else 'FAIL'}")
    print("=" * 50)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
