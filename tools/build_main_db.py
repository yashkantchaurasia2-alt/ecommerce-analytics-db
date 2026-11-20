"""
Builds the MAIN database (DB_NAME from .env) by running sql/01 ... sql/12 in order.

Safety:
  * If the database already exists, the script stops and changes nothing.
  * Rebuilding needs the --reset flag AND typing YES at the prompt, because
    it drops the existing database and all of its data.

Usage:
  python tools/build_main_db.py            # create it if it does not exist
  python tools/build_main_db.py --reset    # drop and rebuild (asks first)

Note: users and roles (db_admin, order_clerk, analyst) belong to the whole
MySQL server. Running the tests re-creates them for the TEST database, so
run this script again (with --reset) if you need their grants on the main
database afterwards.
"""
import re
import sys
from pathlib import Path

import pymysql

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from run_tests import connect, split_sql  # noqa: E402  (reuse the tested splitter)
from dotenv import load_dotenv  # noqa: E402
import os  # noqa: E402


def main():
    load_dotenv(ROOT / ".env")
    cfg = {k: os.getenv(k, "") for k in
           ("DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD", "DB_NAME", "DB_TEST_NAME")}
    name = cfg["DB_NAME"]
    if not re.fullmatch(r"[A-Za-z0-9_]+", name or ""):
        sys.exit(f"DB_NAME in .env is missing or invalid: '{name}'")
    if name == cfg["DB_TEST_NAME"]:
        sys.exit("DB_NAME must be different from DB_TEST_NAME.")

    reset = "--reset" in sys.argv
    server = connect(cfg)
    with server.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = %s", (name,))
        exists = cur.fetchone()[0] == 1
        if exists and not reset:
            print(f"Database '{name}' already exists. Nothing was changed.")
            print("To drop and rebuild it, run:  python tools/build_main_db.py --reset")
            return 0
        if exists:
            answer = input(f"This will DROP '{name}' and ALL its data. Type YES to continue: ")
            if answer.strip() != "YES":
                print("Cancelled. Nothing was changed.")
                return 0
            cur.execute(f"DROP DATABASE `{name}`")
        cur.execute(f"CREATE DATABASE `{name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci")
    server.close()

    conn = connect(cfg, name)
    for path in sorted((ROOT / "sql").glob("[0-9][0-9]_*.sql")):
        statements = split_sql(path.read_text(encoding="utf-8"))
        with conn.cursor() as cur:
            for idx, (_, stmt) in enumerate(statements, 1):
                try:
                    cur.execute(stmt)
                    if cur.description:
                        cur.fetchall()   # results (including generated passwords) are discarded
                except pymysql.MySQLError as e:
                    print(f"FAILED in {path.name}, statement {idx}: {e.args}")
                    return 1
        print(f"  ran {path.name} ({len(statements)} statements)")
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM orders")
        orders = cur.fetchone()[0]
    conn.close()
    print(f"Database '{name}' is ready ({orders} orders).")
    print("Users db_admin / order_clerk / analyst were created with random passwords.")
    print("Set your own with:  ALTER USER 'analyst'@'localhost' IDENTIFIED BY '...';")
    return 0


if __name__ == "__main__":
    sys.exit(main())
