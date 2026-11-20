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

    attempt(a, "analyst: can SELECT orders", "SELECT COUNT(*) FROM orders", True)
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
        print("DCL checks:")
        check_dcl(cfg, db)
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
