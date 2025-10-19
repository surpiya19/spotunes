-- 1. Total Tracks by Playlist
-- SELECT, FROM, ORDER BY --
SELECT 
    name AS playlist_name, 
    num_tracks
FROM playlists
ORDER BY num_tracks DESC;

-- 2. Finding the most popular songs I’ve saved based on spotify's popularity metric
-- JOIN, ORDER BY, LIMIT --
SELECT 
    t.name AS track_name,
    a.name AS artist_name,
    t.popularity
FROM tracks t
JOIN albums al ON t.album_id = al.album_id
JOIN artists a ON al.artist_id = a.artist_id
ORDER BY t.popularity DESC
LIMIT 10;

-- 3. Measuring how consistently popular an artist’s songs are
-- CTE (WITH), AVG(), JOIN, GROUP BY, CASE WHEN -- 
WITH artist_popularity AS (
    SELECT 
        ar.artist_id,
        ar.name AS artist_name,
        AVG(t.popularity) AS avg_popularity
    FROM artists ar
    JOIN albums al ON ar.artist_id = al.artist_id
    JOIN tracks t ON al.album_id = t.album_id
    GROUP BY ar.artist_id, ar.name
)
SELECT 
    artist_name,
    ROUND(avg_popularity, 1) AS avg_popularity,
    CASE 
        WHEN avg_popularity >= 80 THEN '🔥 Superstar'
        WHEN avg_popularity >= 60 THEN '⭐ Rising Artist'
        ELSE '🌱 Underrated Gem'
    END AS popularity_level
FROM artist_popularity
ORDER BY avg_popularity ASC
LIMIT 15;

-- 4. Seeing which playlists have the most diverse range of artists
-- COUNT()(Aggregate), DISTINCT (Aggregate), JOIN (4 WAY JOIN), GROUP BY, ORDER BY,  --
SELECT 
    p.name AS playlist_name,
    COUNT(DISTINCT ar.artist_id) AS unique_artists,
    COUNT(pt.track_id) AS total_tracks,
    ROUND(
        CAST(COUNT(DISTINCT ar.artist_id) AS FLOAT) / COUNT(pt.track_id) * 100, 
        1
    ) AS diversity_percent
FROM playlists p
JOIN playlist_tracks pt ON p.playlist_id = pt.playlist_id
JOIN tracks t ON pt.track_id = t.track_id
JOIN albums al ON t.album_id = al.album_id
JOIN artists ar ON al.artist_id = ar.artist_id
GROUP BY p.name
ORDER BY diversity_percent DESC
LIMIT 10;

-- 5. Average song duration by playlist
-- AVG(), JOIN, GROUP BY, ORDER BY, Data transformation (duration_ms -> minutes)--
SELECT 
    p.name AS playlist_name,
    ROUND(AVG(t.duration_ms) / 60000, 2) AS avg_duration_min
FROM playlists p
JOIN playlist_tracks pt ON p.playlist_id = pt.playlist_id
JOIN tracks t ON pt.track_id = t.track_id
GROUP BY p.name
ORDER BY avg_duration_min DESC;

-- 6. Identifying playlists with the most explicit content
-- CASE WHEN (data cleaning), SUM(), COUNT(), GROUP BY, JOIN, ORDER BY --
SELECT 
    p.name AS playlist_name,
    SUM(CASE WHEN t.explicit = 1 THEN 1 ELSE 0 END) AS explicit_count,
    COUNT(*) AS total_tracks,
    ROUND(SUM(CASE WHEN t.explicit = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS explicit_percent
FROM playlists p
JOIN playlist_tracks pt ON p.playlist_id = pt.playlist_id
JOIN tracks t ON pt.track_id = t.track_id
GROUP BY p.name
ORDER BY explicit_percent DESC;


-- 7. Finding artists that appear most frequently across my playlists
-- JOIN, Aggregates, GROUP BY, Basics --M
SELECT 
    ar.name AS artist_name,
    COUNT(DISTINCT p.playlist_id) AS playlist_count
FROM artists ar
JOIN albums al ON ar.artist_id = al.artist_id
JOIN tracks t ON al.album_id = t.album_id
JOIN playlist_tracks pt ON t.track_id = pt.track_id
JOIN playlists p ON pt.playlist_id = p.playlist_id
GROUP BY ar.artist_id
ORDER BY playlist_count DESC
LIMIT 10;


-- 8. Ranking Artists by Track Popularity
-- Window Function, CTE, JOIN, Aggregates --
WITH artist_popularity AS (
    SELECT 
        ar.name AS artist_name,
        AVG(t.popularity) AS avg_popularity
    FROM artists ar
    JOIN albums al ON ar.artist_id = al.artist_id
    JOIN tracks t ON al.album_id = t.album_id
    GROUP BY ar.name
)
SELECT 
    artist_name,
    ROUND(avg_popularity, 1) AS avg_popularity,
    RANK() OVER (ORDER BY avg_popularity DESC) AS rank_position
FROM artist_popularity
LIMIT 10;


-- 9. Comparing Latest vs Oldest Albums per Artist
-- CTE, Window Function (LAG), Independent Advanced Feature -- 
WITH ordered_albums AS (
    SELECT 
        ar.name AS artist_name,
        al.name AS album_name,
        al.release_date,
        LAG(al.release_date) OVER (PARTITION BY ar.artist_id ORDER BY al.release_date) AS previous_release
    FROM albums al
    JOIN artists ar ON al.artist_id = ar.artist_id
)
SELECT *
FROM ordered_albums
WHERE previous_release IS NOT NULL
LIMIT 10;


-- 10. Merge results from two playlist categories
-- UNION -- 
SELECT name AS playlist_name, num_tracks, 'Short Playlist' AS category
FROM playlists
WHERE num_tracks < 20
UNION
SELECT name AS playlist_name, num_tracks, 'Large Playlist' AS category
FROM playlists
WHERE num_tracks >= 20;

-- 11. Extracting the Release Year from the Album Release Date
-- String/Date Function (SUBSTR()), SELECT, ORDER BY, LIMIT --
SELECT 
    name as song, 
    SUBSTR(release_date, 1, 4) AS release_year
FROM albums
ORDER BY release_year DESC
LIMIT 10;

-- 12. Replacing names of unnamed tracks and fact checking
-- COALESCE, LEFT JOIN, JOIN, GROUP BY, ORDER BY, COUNT() --
SELECT 
    COALESCE(t.name, 'Unknown Track') AS track_name,
    a.name AS artist_name,
    COUNT(pt.playlist_id) AS playlist_count
FROM tracks t
LEFT JOIN playlist_tracks pt ON t.track_id = pt.track_id
JOIN albums al ON t.album_id = al.album_id
JOIN artists a ON al.artist_id = a.artist_id
GROUP BY track_name, artist_name
ORDER BY playlist_count DESC
LIMIT 15;
-- Fact-check: Confirming that unnamed tracks don't exist
SELECT *
FROM tracks
WHERE name IS NULL;

-- 13. Updating unknown artist genre
-- UPDATE --
UPDATE artists
SET genres = 'Unknown Genre'
WHERE genres IS NULL OR genres = '';
-- Fact-check: Confirm missing artist genres were updated
SELECT COUNT(*) AS missing_genres
FROM artists
WHERE genres IS NULL OR genres = '';


