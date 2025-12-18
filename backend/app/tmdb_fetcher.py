import time
import requests
import sqlite3
import os 
from dotenv import load_dotenv

from app.database import DB_PATH, init_db

load_dotenv()
init_db()  # ✅ create table in the ONLY db

print("📁 DB PATH USED:", DB_PATH)

API_KEY = os.getenv("TMDB_API_KEY")
BASE_URL = "https://api.themoviedb.org/3"


def get_conn():
    return sqlite3.connect(DB_PATH)


def fetch_popular_movies(page):
    url = f"{BASE_URL}/movie/popular"
    params = {
        "api_key": API_KEY,
        "language": "en-US",
        "page": page
    }
    response = requests.get(url, params=params, timeout=15)
    response.raise_for_status()
    return response.json()["results"]


def insert_movie(movie):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT OR IGNORE INTO movies
            (id, title, overview, genres, cast, collection, poster_path)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            movie["id"],
            movie.get("title", ""),
            movie.get("overview", ""),
            "",
            "",
            "",
            movie.get("poster_path", "")
        ))
        conn.commit()


def bulk_load_movies(start_page=1, end_page=5):
    for page in range(start_page, end_page + 1):
        for attempt in range(1, 4):
            try:
                print(f"📥 Fetching page {page} (attempt {attempt})")
                movies = fetch_popular_movies(page)

                for movie in movies:
                    insert_movie(movie)

                time.sleep(1.2)  # TMDB-safe
                break

            except Exception as e:
                print(f"⚠️ Page {page} failed ({attempt}/3): {e}")
                time.sleep(3)
        else:
            print(f"❌ Skipped page {page}")


if __name__ == "__main__":
    print("🚀 TMDB bulk fetch started")
    bulk_load_movies(1, 5)
    print("✅ TMDB bulk fetch finished")
