import sqlite3
import os
import psycopg2
from typing import Dict, List, Any
from dotenv import load_dotenv

load_dotenv()
SQLITE_DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "maktab_backend.db")
DATABASE_URL = os.getenv("DATABASE_URL")

def migrate():
    if not DATABASE_URL:
        print("Error: DATABASE_URL environment variable is not set.")
        print("Example: export DATABASE_URL='postgresql://user:pass@ep-xyz.postgres.render.com/maktab'")
        return

    if not os.path.exists(SQLITE_DB):
        print(f"No local SQLite database found at {SQLITE_DB} to migrate.")
        return

    print(f"Reading local SQLite database: {SQLITE_DB}")
    sq_conn = sqlite3.connect(SQLITE_DB)
    sq_conn.row_factory = sqlite3.Row
    sq_cursor = sq_conn.cursor()

    db_url = DATABASE_URL
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)

    print("Connecting to production PostgreSQL cloud database...")
    pg_conn = psycopg2.connect(db_url)
    pg_cursor = pg_conn.cursor()

    tables = ["users", "batches", "students", "attendance", "teacher_attendance", "quran_progress", "fee_payments"]

    for table in tables:
        sq_cursor.execute(f"SELECT * FROM {table}")
        rows = [dict(r) for r in sq_cursor.fetchall()]
        print(f"Migrating {len(rows)} records for table: {table}...")

        for r in rows:
            cols = list(r.keys())
            placeholders = ", ".join(["%s"] * len(cols))
            col_names = ", ".join(cols)
            updates = ", ".join([f"{c}=EXCLUDED.{c}" for c in cols if c != "id"])

            sql = f"""
            INSERT INTO {table} ({col_names})
            VALUES ({placeholders})
            ON CONFLICT(id) DO UPDATE SET {updates}
            """
            pg_cursor.execute(sql, list(r.values()))

    pg_conn.commit()
    sq_conn.close()
    pg_conn.close()

    print("Migration completed successfully! All records migrated to PostgreSQL cloud database.")

if __name__ == "__main__":
    migrate()
