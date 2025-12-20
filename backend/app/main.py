from fastapi import FastAPI, Query
from app.database import init_db, get_connection
from dotenv import load_dotenv
import os
import requests

load_dotenv()

POSTER_BASE_URL = "https://image.tmdb.org/t/p/w500"
TMDB_API_KEY = os.getenv("TMDB_API_KEY")
TMDB_SEARCH_URL = "https://api.themoviedb.org/3/search/movie"

app = FastAPI()


@app.on_event("startup")
def startup_event():
    init_db()


@app.get("/")
def root():
    return {"status": "API running"}


# ---------------------------
# MOVIES LIST
# ---------------------------
@app.get("/movies")
def get_movies():
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        LIMIT 50
    """)

    rows = cur.fetchall()
    conn.close()

    return [
        {
            "id": r["id"],
            "title": r["title"],
            "overview": r["overview"],
            "poster_url": (
                POSTER_BASE_URL + r["poster_path"]
                if r["poster_path"] else None
            )
        }
        for r in rows
    ]


# ---------------------------
# SEARCH (DB → TMDB)
# ---------------------------
@app.get("/search")
def search_movies(query: str = Query(..., min_length=2)):
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE title LIKE ?
        LIMIT 10
    """, (f"%{query}%",))

    rows = cur.fetchall()
    conn.close()

    if rows:
        return {
            "source": "local",
            "results": [
                {
                    "id": r["id"],
                    "title": r["title"],
                    "overview": r["overview"],
                    "poster_url": (
                        POSTER_BASE_URL + r["poster_path"]
                        if r["poster_path"] else None
                    )
                }
                for r in rows
            ]
        }

    response = requests.get(
        TMDB_SEARCH_URL,
        params={
            "api_key": TMDB_API_KEY,
            "query": query,
            "language": "en-US",
            "include_adult": False,
            "page": 1
        },
        timeout=10
    )

    data = response.json()

    return {
        "source": "tmdb",
        "results": [
            {
                "tmdb_id": m["id"],
                "title": m["title"],
                "overview": m.get("overview"),
                "poster_url": (
                    POSTER_BASE_URL + m["poster_path"]
                    if m.get("poster_path") else None
                )
            }
            for m in data.get("results", [])[:10]
        ]
    }


# ---------------------------
# HOME SECTIONS
# ---------------------------
def format_movie(r):
    return {
        "id": r["id"],
        "title": r["title"],
        "overview": r["overview"],
        "poster_url": (
            POSTER_BASE_URL + r["poster_path"]
            if r["poster_path"] else None
        )
    }


@app.get("/home")
def home():
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    cur.execute("SELECT * FROM movies ORDER BY RANDOM() LIMIT 10")
    trending = [format_movie(r) for r in cur.fetchall()]

    cur.execute("SELECT * FROM movies LIMIT 10")
    popular = [format_movie(r) for r in cur.fetchall()]

    cur.execute("SELECT * FROM movies ORDER BY id DESC LIMIT 10")
    recent = [format_movie(r) for r in cur.fetchall()]

    cur.execute("SELECT * FROM movies WHERE overview LIKE '%action%' LIMIT 10")
    action = [format_movie(r) for r in cur.fetchall()]

    cur.execute("""
        SELECT * FROM movies
        WHERE overview LIKE '%space%' OR overview LIKE '%future%'
        LIMIT 10
    """)
    scifi = [format_movie(r) for r in cur.fetchall()]

    conn.close()

    return {
        "sections": [
            {"id": "trending", "title": "Trending Now", "movies": trending},
            {"id": "popular", "title": "Popular Movies", "movies": popular},
            {"id": "recent", "title": "Recently Added", "movies": recent},
            {"id": "action", "title": "Action Picks", "movies": action},
            {"id": "scifi", "title": "Sci-Fi Picks", "movies": scifi},
        ]
    }


# ---------------------------
# MOVIE DETAIL (DB)
# ---------------------------
@app.get("/movies/{movie_id}")
def get_movie_detail(movie_id: int):
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE id = ?
    """, (movie_id,))

    movie = cur.fetchone()
    conn.close()

    if not movie:
        return {"error": "Movie not found"}

    return format_movie(movie)


# ---------------------------
# TMDB DETAIL + LAZY INSERT
# ---------------------------
@app.get("/tmdb/movie/{tmdb_id}")
def get_tmdb_movie_detail(tmdb_id: int):
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE id = ?
    """, (tmdb_id,))
    existing = cur.fetchone()

    if existing:
        conn.close()
        return format_movie(existing)

    response = requests.get(
        f"https://api.themoviedb.org/3/movie/{tmdb_id}",
        params={"api_key": TMDB_API_KEY},
        timeout=10
    )

    if response.status_code != 200:
        conn.close()
        return {"error": "TMDB movie not found"}

    movie = response.json()

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
    conn.close()

    return {
        "id": movie["id"],
        "title": movie.get("title"),
        "overview": movie.get("overview"),
        "poster_url": (
            POSTER_BASE_URL + movie["poster_path"]
            if movie.get("poster_path") else None
        )
    }

@app.get("/tmdb/movie/{tmdb_id}/trailer")
def get_trailer(tmdb_id: int):
    response = requests.get(
        f"https://api.themoviedb.org/3/movie/{tmdb_id}/videos",
        params={"api_key": TMDB_API_KEY},
        timeout=10
    )

    data = response.json()

    for v in data.get("results", []):
        if v["site"] == "YouTube" and v["type"] == "Trailer":
            return {"youtube_key": v["key"]}

    return {"error": "Trailer not found"}

@app.get("/tmdb/movie/{tmdb_id}/genres")
def get_genres(tmdb_id: int):
    response = requests.get(
        f"https://api.themoviedb.org/3/movie/{tmdb_id}",
        params={"api_key": TMDB_API_KEY},
        timeout=10
    )

    if response.status_code != 200:
        return []

    data = response.json()
    return [g["name"] for g in data.get("genres", [])]

@app.get("/tmdb/movie/{tmdb_id}/cast")
def get_cast(tmdb_id: int):
    response = requests.get(
        f"https://api.themoviedb.org/3/movie/{tmdb_id}/credits",
        params={"api_key": TMDB_API_KEY},
        timeout=10
    )

    if response.status_code != 200:
        return []

    data = response.json()
    return [c["name"] for c in data.get("cast", [])[:10]]

@app.get("/movies/{movie_id}/feed")
def movie_feed(movie_id: int, offset: int = 0, limit: int = 10):
    conn = get_connection()
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE id != ?
        ORDER BY RANDOM()
        LIMIT ? OFFSET ?
    """, (movie_id, limit, offset))

    rows = cur.fetchall()
    conn.close()

    return [
        {
            "id": r["id"],
            "title": r["title"],
            "overview": r["overview"],
            "poster_url": POSTER_BASE_URL + r["poster_path"]
            if r["poster_path"] else None
        }
        for r in rows
    ]
@app.get("/movies/{movie_id}/related")
def get_related_movies(movie_id: int):
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    # Get current movie overview
    cur.execute("SELECT overview FROM movies WHERE id = ?", (movie_id,))
    movie = cur.fetchone()

    # Fallback-safe logic
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE id != ?
        ORDER BY RANDOM()
        LIMIT 10
    """, (movie_id,))

    rows = cur.fetchall()
    conn.close()

    return [
        {
            "id": r["id"],
            "title": r["title"],
            "overview": r["overview"],
            "poster_url": (
                POSTER_BASE_URL + r["poster_path"]
                if r["poster_path"] else None
            )
        }
        for r in rows
    ]
