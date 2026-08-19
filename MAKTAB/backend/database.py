import os
import sqlite3
from typing import Any, List, Dict, Tuple, Optional
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "maktab_backend.db")

class DBConnection:
    def __init__(self, is_postgres: bool, conn: Any):
        self.is_postgres = is_postgres
        self.conn = conn

    def cursor(self):
        return DBCursor(self.is_postgres, self.conn.cursor())

    def commit(self):
        self.conn.commit()

    def close(self):
        self.conn.close()

class DBCursor:
    def __init__(self, is_postgres: bool, cursor: Any):
        self.is_postgres = is_postgres
        self.cursor = cursor

    def execute(self, query: str, params: Tuple[Any, ...] = ()):
        if self.is_postgres:
            # Convert SQLite '?' placeholders to PostgreSQL '%s'
            pg_query = query.replace("?", "%s").replace("ON CONFLICT(id) DO UPDATE SET", "ON CONFLICT(id) DO UPDATE SET")
            self.cursor.execute(pg_query, params)
        else:
            self.cursor.execute(query, params)

    def fetchone(self) -> Optional[Dict[str, Any]]:
        row = self.cursor.fetchone()
        if not row:
            return None
        if self.is_postgres:
            colnames = [desc[0] for desc in self.cursor.description]
            return dict(zip(colnames, row))
        return dict(row)

    def fetchall(self) -> List[Dict[str, Any]]:
        rows = self.cursor.fetchall()
        if not rows:
            return []
        if self.is_postgres:
            colnames = [desc[0] for desc in self.cursor.description]
            return [dict(zip(colnames, r)) for r in rows]
        return [dict(r) for r in rows]

def get_db() -> DBConnection:
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        import psycopg2
        # Fix postgres:// to postgresql:// if needed by psycopg2
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)
        conn = psycopg2.connect(db_url)
        return DBConnection(True, conn)
    else:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return DBConnection(False, conn)

def init_db():
    conn = get_db()
    cursor = conn.cursor()

    # Define portable DDL statements
    id_type = "SERIAL PRIMARY KEY" if conn.is_postgres else "INTEGER PRIMARY KEY"
    real_type = "DOUBLE PRECISION" if conn.is_postgres else "REAL"

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS users (
        id {id_type},
        maktab_id TEXT NOT NULL,
        name TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        mobile TEXT,
        created_at TEXT,
        is_active INTEGER DEFAULT 1,
        photo_path TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS batches (
        id {id_type},
        maktab_id TEXT NOT NULL,
        name TEXT NOT NULL,
        section TEXT,
        room TEXT,
        teacher_id INTEGER,
        created_at TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS students (
        id {id_type},
        maktab_id TEXT NOT NULL,
        name TEXT NOT NULL,
        guardian_name TEXT,
        guardian_phone TEXT,
        batch_id INTEGER,
        dob TEXT,
        gender TEXT,
        address TEXT,
        admission_date TEXT,
        roll_number TEXT,
        photo_path TEXT,
        teacher_note TEXT,
        is_deleted INTEGER DEFAULT 0,
        deleted_at TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS attendance (
        id {id_type},
        maktab_id TEXT NOT NULL,
        student_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        remarks TEXT,
        time TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS teacher_attendance (
        id {id_type},
        maktab_id TEXT NOT NULL,
        teacher_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        remarks TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS quran_progress (
        id {id_type},
        maktab_id TEXT NOT NULL,
        student_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        surah TEXT NOT NULL,
        ayah_from INTEGER NOT NULL,
        ayah_to INTEGER NOT NULL,
        grade TEXT NOT NULL,
        remarks TEXT
    );
    """)

    cursor.execute(f"""
    CREATE TABLE IF NOT EXISTS fee_payments (
        id {id_type},
        maktab_id TEXT NOT NULL,
        student_id INTEGER NOT NULL,
        amount {real_type} NOT NULL,
        payment_date TEXT NOT NULL,
        month TEXT NOT NULL,
        year INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        receipt_number TEXT,
        remarks TEXT,
        timestamp TEXT
    );
    """)

    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")
