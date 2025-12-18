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
# EXISTING WORKING ENDPOINT
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

    movies = []
    for r in rows:
        movies.append({
            "id": r["id"],
            "title": r["title"],
            "overview": r["overview"],
            "poster_url": (
                POSTER_BASE_URL + r["poster_path"]
                if r["poster_path"] else None
            )
        })

    return movies


# ---------------------------
# NEW: SEARCH WITH TMDB FALLBACK
# ---------------------------
@app.get("/search")
def search_movies(query: str = Query(..., min_length=2)):
    # 1️⃣ Search local database first
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

    # 2️⃣ Fallback to TMDB (real-time)
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

    results = []
    for movie in data.get("results", [])[:10]:
        results.append({
            "tmdb_id": movie["id"],
            "title": movie["title"],
            "overview": movie.get("overview"),
            "poster_url": (
                POSTER_BASE_URL + movie["poster_path"]
                if movie.get("poster_path") else None
            )
        })

    return {
        "source": "tmdb",
        "results": results
    }


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

    # 1️⃣ Trending Now (random sample)
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        ORDER BY RANDOM()
        LIMIT 10
    """)
    trending = [format_movie(r) for r in cur.fetchall()]

    # 2️⃣ Popular Movies (top N; deterministic placeholder)
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        LIMIT 10
    """)
    popular = [format_movie(r) for r in cur.fetchall()]

    # 3️⃣ Recently Added (latest IDs)
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        ORDER BY id DESC
        LIMIT 10
    """)
    recent = [format_movie(r) for r in cur.fetchall()]

    # 4️⃣ Action Picks (simple text match)
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE overview LIKE '%action%'
        LIMIT 10
    """)
    action = [format_movie(r) for r in cur.fetchall()]

    # 5️⃣ Sci-Fi Picks (simple text match)
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE overview LIKE '%space%' OR overview LIKE '%future%'
        LIMIT 10
    """)
    scifi = [format_movie(r) for r in cur.fetchall()]

    conn.close()

    return {
        "sections": [
            {"id": "trending", "title": "Trending Now", "type": "horizontal", "movies": trending},
            {"id": "popular", "title": "Popular Movies", "type": "horizontal", "movies": popular},
            {"id": "recent", "title": "Recently Added", "type": "horizontal", "movies": recent},
            {"id": "action", "title": "Action Picks", "type": "horizontal", "movies": action},
            {"id": "scifi", "title": "Sci-Fi Picks", "type": "horizontal", "movies": scifi},
        ]
    }
@app.get("/movies/{movie_id}/related")
def get_related_movies(movie_id: int):
    conn = get_connection()
    conn.row_factory = lambda cursor, row: {
        col[0]: row[idx]
        for idx, col in enumerate(cursor.description)
    }
    cur = conn.cursor()

    # Get current movie
    cur.execute("""
        SELECT overview
        FROM movies
        WHERE id = ?
    """, (movie_id,))
    movie = cur.fetchone()

    if not movie:
        conn.close()
        return []

    keyword = movie["overview"].split(" ")[0]  # simple seed

    # Find related movies
    cur.execute("""
        SELECT id, title, overview, poster_path
        FROM movies
        WHERE overview LIKE ?
        AND id != ?
        LIMIT 10
    """, (f"%{keyword}%", movie_id))

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
@app.get("/movies/{movie_id}")
def get_movie_detail(movie_id: str):
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

    return {
        "id": movie["id"],
        "title": movie["title"],
        "overview": movie["overview"],
        "poster_url": (
            POSTER_BASE_URL + movie["poster_path"]
            if movie["poster_path"] else None
        )
    }
