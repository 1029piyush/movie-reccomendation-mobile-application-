from fastapi import FastAPI
from app.database import init_db, get_connection

app = FastAPI()


@app.on_event("startup")
def startup():
    init_db()


@app.get("/")
def root():
    return {"status": "Backend running"}


@app.get("/movies")
def get_movies():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM movies")
    rows = cursor.fetchall()

    conn.close()
    return [dict(row) for row in rows]

POSTER_BASE_URL = "https://image.tmdb.org/t/p/w500"

@app.get("/movies")
def get_movies():
    conn = get_connection()
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
exit()

