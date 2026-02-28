# Spotify - Music Streaming Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Music Streaming Platform  
**Granularity:** Daily & Stream-level  
**Purpose:** Track listening, artist reach, and engagement

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are key metrics? (DAU, streams, artist reach, skip rate)
• What questions matter most?
• What events are tracked? (stream, skip, like, follow, playlist)
```

#### Data Specifics
```
• Do we track skip events separately from completes?
• What is the time granularity? (real-time, daily, weekly?)
• Do we need artist/genre hierarchies?
• How granular on user context? (radio, playlist, search)
```

### Assumed Answers for This Case
- OLAP system
- Raw event ingestion
- Daily analytics with flexibility
- Artist and genre hierarchies needed

---

## Star Diagram

```
                    ┌──────────────┐
                    │   dim_user   │
                    │  (Listeners) │
                    └────────┬─────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │fact_streams  │   │fact_user_   │
            │(plays/skips) │   │events       │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │  dim_track   │   │  dim_date   │
            │              │   │             │
            └───────┬──────┘   └─────────────┘
                    │
            ┌───────┴──────────┬─────────────┐
            │                  │             │
        ┌───▼────┐      ┌──────▼────┐  ┌───▼────┐
        │dim_    │      │dim_artist │  │dim_    │
        │album   │      │           │  │genre   │
        └────────┘      └───────────┘  └────────┘
```

---

## Dimension Tables

### dim_user
| Column | Type | Description |
|--------|------|-------------|
| **user_id** (PK) | Integer | Unique user identifier |
| signup_date | Date | When user joined |
| country | String | User's country |
| subscription_tier | String | Free/Premium |
| language | String | Preferred language |
| total_streams | Integer | Lifetime streams |

### dim_track
| Column | Type | Description |
|--------|------|-------------|
| **track_id** (PK) | Integer | Unique track identifier |
| **artist_id** (FK) | Integer | Links to dim_artist |
| **album_id** (FK) | Integer | Links to dim_album |
| **genre_id** (FK) | Integer | Links to dim_genre |
| track_name | String | Song name |
| duration_seconds | Integer | Track length |
| release_date | Date | Release date |
| popularity_score | Integer | 0-100 |

### dim_artist
| Column | Type | Description |
|--------|------|-------------|
| **artist_id** (PK) | Integer | Unique artist identifier |
| artist_name | String | Artist name |
| country | String | Artist's country |
| verified | Boolean | Verified badge |
| monthly_listeners | Integer | Current listeners |
| follower_count | Integer | Total followers |

### dim_album
| Column | Type | Description |
|--------|------|-------------|
| **album_id** (PK) | Integer | Unique album identifier |
| **artist_id** (FK) | Integer | Links to dim_artist |
| album_name | String | Album name |
| release_date | Date | Release date |
| album_type | String | Album/Compilation |

### dim_genre
| Column | Type | Description |
|--------|------|-------------|
| **genre_id** (PK) | Integer | Unique genre identifier |
| **parent_genre_id** (FK) | Integer | Parent genre (hierarchy) |
| genre_name | String | Genre name |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| **date_id** (PK) | Integer | Date key (YYYYMMDD) |
| calendar_date | Date | Full date |
| day_of_week | String | Mon-Sun |
| week | Integer | Week number |
| month | Integer | 1-12 |
| year | Integer | Year |

---

## Fact Tables

### fact_streams ⭐
**Grain:** One row per track play

| Column | Type | Description |
|--------|------|-------------|
| **stream_id** (PK) | Integer | Unique stream identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **track_id** (FK) | Integer | Links to dim_track |
| **date_id** (FK) | Integer | Links to dim_date |
| stream_timestamp | Timestamp | When played |
| duration_played_sec | Integer | Seconds played |
| was_skipped | Boolean | Skip flag |
| context | String | Playlist/Radio/Search |
| device_type | String | Mobile/Desktop/Speaker |

### fact_user_events ⭐
**Grain:** One row per user action (like, follow, add-to-playlist)

| Column | Type | Description |
|--------|------|-------------|
| **event_id** (PK) | Integer | Unique event identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **track_id** (FK) | Integer | Links to dim_track |
| **date_id** (FK) | Integer | Links to dim_date |
| event_type | String | Like/Unlike/Save/Unsave |
| event_timestamp | Timestamp | When action occurred |

---

## Key Relationships

```
dim_user (1) ──< (N) fact_streams
dim_user (1) ──< (N) fact_user_events

dim_track (1) ──< (N) fact_streams
dim_track (1) ──< (N) fact_user_events

dim_artist (1) ──< (N) dim_track
dim_album (1) ──< (N) dim_track
dim_genre (1) ──< (N) dim_track

dim_date (1) ──< (N) fact_streams
dim_date (1) ──< (N) fact_user_events
```

---

## Core Analytics Queries

### 1. Daily Streams & Unique Listeners
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fs.user_id) AS dau,
    COUNT(fs.stream_id) AS total_streams,
    SUM(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) AS completed_streams,
    ROUND(100.0 * SUM(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) / COUNT(fs.stream_id), 2) AS completion_rate_pct
FROM fact_streams fs
JOIN dim_date dd ON fs.date_id = dd.date_id
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### 2. Top 20 Tracks by Streams
```sql
SELECT TOP 20
    dt.track_name,
    da.artist_name,
    dg.genre_name,
    COUNT(fs.stream_id) AS total_streams,
    SUM(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) AS completed_plays,
    ROUND(100.0 * SUM(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) / COUNT(fs.stream_id), 2) AS skip_rate_pct
FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
JOIN dim_artist da ON dt.artist_id = da.artist_id
JOIN dim_genre dg ON dt.genre_id = dg.genre_id
GROUP BY dt.track_id, dt.track_name, da.artist_name, dg.genre_name
ORDER BY total_streams DESC;
```

### 3. Artist Reach & Monthly Listeners
```sql
SELECT 
    da.artist_name,
    COUNT(DISTINCT fs.user_id) AS unique_listeners,
    COUNT(fs.stream_id) AS total_streams,
    SUM(fs.duration_played_sec) / 3600.0 AS total_hours_listened,
    AVG(fs.duration_played_sec) AS avg_duration_per_stream
FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
JOIN dim_artist da ON dt.artist_id = da.artist_id
GROUP BY da.artist_id, da.artist_name
ORDER BY unique_listeners DESC;
```

### 4. Genre Popularity Trend
```sql
SELECT 
    dg.genre_name,
    dd.year,
    dd.month,
    COUNT(DISTINCT fs.stream_id) AS streams,
    COUNT(DISTINCT fs.user_id) AS unique_listeners,
    ROUND(100.0 * SUM(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) / COUNT(fs.stream_id), 2) AS completion_rate_pct
FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
JOIN dim_genre dg ON dt.genre_id = dg.genre_id
JOIN dim_date dd ON fs.date_id = dd.date_id
GROUP BY dg.genre_name, dd.year, dd.month
ORDER BY dd.year DESC, dd.month DESC;
```

### 5. User Engagement (Likes & Saves)
```sql
SELECT TOP 20
    dd.calendar_date,
    COUNT(DISTINCT CASE WHEN fue.event_type = 'Like' THEN fue.user_id END) AS users_liking,
    COUNT(DISTINCT CASE WHEN fue.event_type = 'Save' THEN fue.user_id END) AS users_saving,
    COUNT(CASE WHEN fue.event_type = 'Like' THEN 1 END) AS total_likes,
    COUNT(CASE WHEN fue.event_type = 'Save' THEN 1 END) AS total_saves
FROM fact_user_events fue
JOIN dim_date dd ON fue.date_id = dd.date_id
WHERE fue.event_type IN ('Like', 'Save')
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (streams, user_events)  
✅ **Stream Tracking:** Captures plays and skips separately  
✅ **User Engagement:** Separate fact for likes/saves  
✅ **Artist Analytics:** Track artist reach through unique listeners  
✅ **Genre Hierarchy:** Support drill-down by genre  

---

## Interview Tips

1. **Grain:** "fact_streams = one track play; fact_user_events = one user action"
2. **Skip Analysis:** "was_skipped flag shows engagement quality separately"
3. **Artist Reach:** "Unique listeners per artist per month = monthly listener metric"
4. **Star Schema:** "All dimensions connect centrally to fact tables for query efficiency"

---

## Follow-Up Questions & Answers

### Q1: "How do we track playlist vs radio vs search context separately?"
**A:** Include context as column in fact_streams:
```sql
SELECT 
    context,
    COUNT(*) AS streams,
    SUM(CASE WHEN was_skipped = 0 THEN 1 ELSE 0 END) AS completed,
    ROUND(100.0 * SUM(CASE WHEN was_skipped = 0 THEN 1 ELSE 0 END) / 
          COUNT(*), 2) AS skip_rate_pct
FROM fact_streams
GROUP BY context
ORDER BY completed DESC;

-- Results: Playlist, Radio, Search, Recommendation, Library
```

### Q2: "What about songs that were skipped within 3 seconds (quality control)?"
**A:** Create separate fact for quick skips:
```sql
CREATE TABLE fact_quality_issues (
    issue_id INT PRIMARY KEY,
    stream_id INT FK,
    user_id INT FK,
    track_id INT FK,
    date_id INT FK,
    skip_after_sec INT,
    issue_type VARCHAR -- 'audio_quality', 'stream_issue', 'wrong_content'
);
```

### Q3: "How do we handle explicit content restrictions by region?"
**A:** Add region access flags to dim_track:
```sql
ALTER TABLE dim_track 
ADD explicit_flag BOOLEAN,
ADD blocked_regions VARCHAR; -- 'US,UK,CA'

SELECT * FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
WHERE dt.blocked_regions NOT LIKE CONCAT('%', @user_region, '%');
```

### Q4: "Should featuring artists be tracked separately?"
**A:** YES - create junction fact table:
```sql
CREATE TABLE fact_artist_collaborations (
    collab_id INT PRIMARY KEY,
    track_id INT FK,
    primary_artist_id INT FK,
    featured_artist_id INT FK,
    collab_type VARCHAR -- 'featured', 'remix', 'cover'
);

-- Then join both artists to streams
SELECT da1.artist_name, da2.artist_name, COUNT(*) AS collabs
FROM fact_streams fs
JOIN fact_artist_collaborations fac ON fs.track_id = fac.track_id
JOIN dim_artist da1 ON fac.primary_artist_id = da1.artist_id
JOIN dim_artist da2 ON fac.featured_artist_id = da2.artist_id
GROUP BY da1.artist_name, da2.artist_name;
```

### Q5: "How do we track algorithmic recommendations impact?"
**A:** Add algorithm tracking:
```sql
ALTER TABLE fact_streams 
ADD algorithm_id INT,
ADD recommendation_confidence DECIMAL; -- 0-100

SELECT 
    algorithm_id,
    COUNT(*) AS recommendations_made,
    SUM(CASE WHEN was_skipped = 0 THEN 1 ELSE 0 END) AS accepted,
    ROUND(100.0 * SUM(CASE WHEN was_skipped = 0 THEN 1 ELSE 0 END) / 
          COUNT(*), 2) AS acceptance_rate_pct
FROM fact_streams
WHERE context = 'Recommendation'
GROUP BY algorithm_id;
```

### Q6: "What about offline downloads? How do we count them?"
**A:** Create separate fact table:
```sql
CREATE TABLE fact_offline_downloads (
    download_id INT PRIMARY KEY,
    user_id INT FK,
    track_id INT FK,
    date_id INT FK,
    downloaded_at TIMESTAMP,
    played_offline BOOLEAN
);
```
Separate from streams, different business meaning.

### Q7: "How do we measure artist success over time?"
**A:** Track by monthly cohorts:
```sql
SELECT 
    dd.year,
    dd.month,
    da.artist_name,
    COUNT(DISTINCT fs.user_id) AS monthly_listeners,
    COUNT(DISTINCT fs.stream_id) AS total_streams,
    ROUND(SUM(fs.duration_played_sec) / 3600.0, 2) AS hours_listened
FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
JOIN dim_artist da ON dt.artist_id = da.artist_id
JOIN dim_date dd ON fs.date_id = dd.date_id
GROUP BY dd.year, dd.month, da.artist_name
ORDER BY dd.year DESC, dd.month DESC;
```

### Q8: "Should we track free vs premium user differences?"
**A:** Add subscription tier to dim_user:
```sql
ALTER TABLE dim_user ADD subscription_tier VARCHAR; -- Free, Premium

SELECT 
    du.subscription_tier,
    COUNT(DISTINCT fs.user_id) AS users,
    AVG(CASE WHEN fs.was_skipped = 0 THEN 1 ELSE 0 END) AS completion_rate
FROM fact_streams fs
JOIN dim_user du ON fs.user_id = du.user_id
GROUP BY du.subscription_tier;

-- Compare engagement between tiers
```

### Q9: "What's the cardinality of dim_genre?"
**A:** Medium cardinality with hierarchy:
```
Top level genres: ~30 (Rock, Pop, Hip-Hop, etc.)
Sub-genres: ~500-1000 (Indie Rock, K-Pop, Trap, etc.)
Can be multi-level hierarchy or flattened.

Best approach: Flatten with parent_genre_id for drill-down
```

### Q10: "How do we handle trending songs vs evergreen catalog?"
**A:** Track trend metrics:
```sql
SELECT 
    dt.track_name,
    da.artist_name,
    COUNT(*) AS streams_this_week,
    LAG(COUNT(*)) OVER (
        PARTITION BY dt.track_id 
        ORDER BY dd.week
    ) AS streams_prev_week,
    ROUND(100.0 * (COUNT(*) - LAG(COUNT(*)) OVER (...)) / 
          LAG(COUNT(*)) OVER (...), 2) AS week_over_week_growth
FROM fact_streams fs
JOIN dim_track dt ON fs.track_id = dt.track_id
JOIN dim_artist da ON dt.artist_id = da.artist_id
JOIN dim_date dd ON fs.date_id = dd.date_id
WHERE dd.year = 2026 AND dd.month = 1
GROUP BY dt.track_id, dt.track_name, da.artist_name, dd.week;
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Storing artist in dim_track only (missing collaborations)  
✅ **RIGHT:** Use junction table for multi-artist tracks

❌ **WRONG:** Not separating skip flag from actual completion  
✅ **RIGHT:** Include was_skipped and duration_played_sec separately

❌ **WRONG:** Mixing download and stream metrics  
✅ **RIGHT:** Separate fact tables for different behaviors

❌ **WRONG:** Aggregating weekly data in fact table  
✅ **RIGHT:** Keep stream level, aggregate on query

---

## One-Liner Reminders

📌 "Grain: one track play = one row, even if same user plays same track twice."

📌 "was_skipped is crucial for quality metrics."

📌 "Artist reach = COUNT(DISTINCT user_id) per period."

📌 "Use junction table for featuring/collaboration artists."

