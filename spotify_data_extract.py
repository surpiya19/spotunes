import os
import time
import sqlite3
from dotenv import load_dotenv
import spotipy
from spotipy.oauth2 import SpotifyOAuth
from tqdm import tqdm
from spotipy.exceptions import SpotifyException

# -------------------------
# 1. Load .env credentials
# -------------------------
load_dotenv()

SPOTIFY_CLIENT_ID = os.getenv("SPOTIPY_CLIENT_ID")
SPOTIFY_CLIENT_SECRET = os.getenv("SPOTIPY_CLIENT_SECRET")
SPOTIFY_REDIRECT_URI = os.getenv("SPOTIPY_REDIRECT_URI")
SCOPE = "user-library-read playlist-read-private"

sp = spotipy.Spotify(
    auth_manager=SpotifyOAuth(
        client_id=SPOTIFY_CLIENT_ID,
        client_secret=SPOTIFY_CLIENT_SECRET,
        redirect_uri=SPOTIFY_REDIRECT_URI,
        scope=SCOPE,
    )
)

# -------------------------
# 2. Connect to SQLite DB
# -------------------------
conn = sqlite3.connect("spotify.db")
cursor = conn.cursor()

# -------------------------
# 3. Create Tables
# -------------------------
cursor.execute(
    """
CREATE TABLE IF NOT EXISTS artists (
    artist_id TEXT PRIMARY KEY,
    name TEXT,
    genres TEXT
)
"""
)

cursor.execute(
    """
CREATE TABLE IF NOT EXISTS albums (
    album_id TEXT PRIMARY KEY,
    name TEXT,
    release_date TEXT,
    artist_id TEXT,
    FOREIGN KEY (artist_id) REFERENCES artists(artist_id)
)
"""
)

cursor.execute(
    """
CREATE TABLE IF NOT EXISTS tracks (
    track_id TEXT PRIMARY KEY,
    name TEXT,
    album_id TEXT,
    popularity INTEGER,
    duration_ms INTEGER,
    explicit BOOLEAN,
    FOREIGN KEY (album_id) REFERENCES albums(album_id)
)
"""
)

cursor.execute(
    """
CREATE TABLE IF NOT EXISTS playlists (
    playlist_id TEXT PRIMARY KEY,
    name TEXT,
    owner TEXT,
    num_tracks INTEGER
)
"""
)

cursor.execute(
    """
CREATE TABLE IF NOT EXISTS playlist_tracks (
    playlist_id TEXT,
    track_id TEXT,
    PRIMARY KEY (playlist_id, track_id),
    FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id),
    FOREIGN KEY (track_id) REFERENCES tracks(track_id)
)
"""
)

conn.commit()


# -------------------------
# 4. Helper: Retry on rate limit
# -------------------------
def fetch_with_retry(func, *args, max_retries=5, delay=1, **kwargs):
    retries = 0
    while retries < max_retries:
        try:
            return func(*args, **kwargs)
        except SpotifyException as e:
            if e.http_status in [429, 403]:  # rate-limit or forbidden
                wait = int(e.headers.get("Retry-After", delay))
                print(f"Rate limited, waiting {wait}s...")
                time.sleep(wait)
                retries += 1
            else:
                raise e
    print("Max retries reached, skipping...")
    return None


# -------------------------
# 5. Fetch playlists
# -------------------------
print("Fetching playlists...")
playlists_data = fetch_with_retry(sp.current_user_playlists, limit=30)
playlists = playlists_data["items"] if playlists_data else []
print(f"🎵 Found {len(playlists)} playlists.")

# -------------------------
# 6. Fetch tracks and insert into DB
# -------------------------
for p_idx, playlist in enumerate(tqdm(playlists, desc="Playlists")):
    pid = playlist["id"]
    pname = playlist["name"]
    owner = playlist["owner"]["display_name"]
    num_tracks = playlist["tracks"]["total"]

    cursor.execute(
        "INSERT OR IGNORE INTO playlists (playlist_id, name, owner, num_tracks) VALUES (?, ?, ?, ?)",
        (pid, pname, owner, num_tracks),
    )

    results = fetch_with_retry(sp.playlist_tracks, pid, limit=100)
    tracks_items = results.get("items", []) if results else []

    while results and results.get("next"):
        results = fetch_with_retry(sp.next, results)
        if results:
            tracks_items.extend(results.get("items", []))
        time.sleep(0.5)  # small delay to avoid rate limits

    for item in tracks_items:
        track = item.get("track")
        if not track:
            continue

        track_id = track["id"]
        track_name = track["name"]
        album = track["album"]
        album_id = album["id"]
        popularity = track["popularity"]
        duration_ms = track["duration_ms"]
        explicit = track["explicit"]

        # Album info
        artist = track["artists"][0]
        artist_id = artist["id"]
        artist_name = artist["name"]

        # Fetch artist genres safely
        artist_info = fetch_with_retry(sp.artist, artist_id)
        artist_genres = ",".join(artist_info.get("genres", [])) if artist_info else ""

        release_date = album["release_date"]

        # Insert artist
        cursor.execute(
            "INSERT OR IGNORE INTO artists (artist_id, name, genres) VALUES (?, ?, ?)",
            (artist_id, artist_name, artist_genres),
        )

        # Insert album
        cursor.execute(
            "INSERT OR IGNORE INTO albums (album_id, name, release_date, artist_id) VALUES (?, ?, ?, ?)",
            (album_id, album["name"], release_date, artist_id),
        )

        # Insert track
        cursor.execute(
            "INSERT OR IGNORE INTO tracks (track_id, name, album_id, popularity, duration_ms, explicit) VALUES (?, ?, ?, ?, ?, ?)",
            (track_id, track_name, album_id, popularity, duration_ms, explicit),
        )

        # Insert playlist-track relation
        cursor.execute(
            "INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id) VALUES (?, ?)",
            (pid, track_id),
        )

    conn.commit()

conn.close()
print("✅ Spotify data successfully saved to spotify.db")
