from pathlib import Path
import sqlite3

DB_PATH = Path(__file__).resolve().parent / "movies.db"
# This points to backend/app/movies.db ✅


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS movies (
        id INTEGER PRIMARY KEY,
        title TEXT,
        overview TEXT,
        genres TEXT,
        cast TEXT,
        collection TEXT,
        poster_path TEXT
    )
    """)

    conn.commit()
    conn.close()
