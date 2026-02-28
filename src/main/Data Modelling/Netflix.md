# Netflix - Streaming Platform Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Streaming Platform  
**Granularity:** Daily & Session-level  
**Purpose:** Track engagement, retention, and churn

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are the key metrics? (DAU, MAU, retention, churn)
• What questions do stakeholders want answered?
• What events are tracked? (login, browse, view, pause, rating, subscription)
```

#### Data Specifics
```
• Is data stored as raw events or aggregated?
• What is the time granularity? (hourly, daily, weekly?)
• Do we need content recommendation feedback?
• What retention and churn metrics matter most?
```

### Assumed Answers for This Case
- OLAP system
- Raw event ingestion with streaming component
- Daily/weekly analytics with near real-time dashboards
- Batch processing with real-time streaming

---

## Star Diagram

```
                    ┌──────────────┐
                    │   dim_user   │
                    │(Subscribers) │
                    └────────┬─────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │fact_streams  │   │fact_sub_    │
            │(watch time)  │   │events       │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │ dim_content  │   │ dim_date    │
            │(shows/movies)│   │             │
            └──────────────┘   └─────────────┘
                    │
            ┌───────▼──────────┐
            │   dim_genre      │
            │  (hierarchical)  │
            └──────────────────┘
```

---

## Dimension Tables

### dim_user
| Column | Type | Description |
|--------|------|-------------|
| **user_id** (PK) | Integer | Unique subscriber identifier |
| signup_date | Date | When subscriber joined |
| country | String | User's country |
| subscription_tier | String | Basic/Standard/Premium |
| account_status | String | Active/Cancelled |
| last_active_date | Date | Last viewing date |

### dim_content
| Column | Type | Description |
|--------|------|-------------|
| **content_id** (PK) | Integer | Unique content identifier |
| **genre_id** (FK) | Integer | Links to dim_genre |
| content_type | String | Movie/TV Series |
| title | String | Content name |
| release_date | Date | Release date |
| runtime_minutes | Integer | Duration (movies) |
| director | String | Director name |
| imdb_rating | Decimal | IMDb rating |

### dim_genre
| Column | Type | Description |
|--------|------|-------------|
| **genre_id** (PK) | Integer | Unique genre identifier |
| **parent_genre_id** (FK) | Integer | Parent genre (hierarchy) |
| genre_name | String | Genre name |
| level | Integer | Hierarchy level (1, 2) |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| **date_id** (PK) | Integer | Date key (YYYYMMDD) |
| calendar_date | Date | Full date |
| day_of_week | String | Mon-Sun |
| week | Integer | Week number |
| month | Integer | 1-12 |
| year | Integer | Year |
| quarter | Integer | Q1-Q4 |

---

## Fact Tables

### fact_streams ⭐
**Grain:** One row per view session

| Column | Type | Description |
|--------|------|-------------|
| **stream_id** (PK) | Integer | Unique stream identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **content_id** (FK) | Integer | Links to dim_content |
| **date_id** (FK) | Integer | Links to dim_date |
| start_time | Timestamp | When viewing started |
| end_time | Timestamp | When viewing ended |
| duration_watched_sec | Integer | Seconds watched |
| completion_percentage | Decimal | % of content watched |
| device_type | String | Mobile/Desktop/Smart TV |

### fact_subscription_events ⭐
**Grain:** One row per subscription change

| Column | Type | Description |
|--------|------|-------------|
| **event_id** (PK) | Integer | Unique event identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **date_id** (FK) | Integer | Links to dim_date |
| event_type | String | Signup/Upgrade/Downgrade/Churn |
| subscription_tier | String | Tier after event |
| monthly_price | Decimal | Price of subscription |
| cancellation_reason | String | Why cancelled (if churn) |

---

## Key Relationships

```
dim_user (1) ──< (N) fact_streams
dim_user (1) ──< (N) fact_subscription_events

dim_content (1) ──< (N) fact_streams
dim_genre (1) ──< (N) dim_content (hierarchy)

dim_date (1) ──< (N) fact_streams
dim_date (1) ──< (N) fact_subscription_events
```

---

## Core Analytics Queries

### 1. Daily Active Users (DAU)
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fs.user_id) AS dau,
    COUNT(DISTINCT fs.stream_id) AS total_streams,
    SUM(fs.duration_watched_sec) / 3600.0 AS hours_watched
FROM fact_streams fs
JOIN dim_date dd ON fs.date_id = dd.date_id
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### 2. Content Completion Rate
```sql
SELECT TOP 20
    dc.title,
    dc.content_type,
    COUNT(fs.stream_id) AS views,
    ROUND(AVG(fs.completion_percentage), 2) AS avg_completion_pct,
    COUNT(DISTINCT CASE WHEN fs.completion_percentage >= 90 THEN fs.stream_id END) AS completed_views
FROM fact_streams fs
JOIN dim_content dc ON fs.content_id = dc.content_id
GROUP BY dc.content_id, dc.title, dc.content_type
ORDER BY views DESC;
```

### 3. Churn Rate by Month
```sql
SELECT 
    dd.year,
    dd.month,
    COUNT(DISTINCT CASE WHEN fse.event_type = 'Churn' THEN fse.user_id END) AS churned_users,
    COUNT(DISTINCT CASE WHEN fse.event_type = 'Signup' THEN fse.user_id END) AS new_signups,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN fse.event_type = 'Churn' THEN fse.user_id END) / 
          COUNT(DISTINCT fse.user_id), 2) AS churn_rate_pct
FROM fact_subscription_events fse
JOIN dim_date dd ON fse.date_id = dd.date_id
GROUP BY dd.year, dd.month
ORDER BY dd.year DESC, dd.month DESC;
```

### 4. Top Genres by Watch Time
```sql
SELECT 
    dg.genre_name,
    SUM(fs.duration_watched_sec) / 3600.0 AS total_hours,
    COUNT(DISTINCT fs.stream_id) AS views,
    COUNT(DISTINCT fs.user_id) AS unique_viewers
FROM fact_streams fs
JOIN dim_content dc ON fs.content_id = dc.content_id
JOIN dim_genre dg ON dc.genre_id = dg.genre_id
GROUP BY dg.genre_id, dg.genre_name
ORDER BY total_hours DESC;
```

### 5. Retention Cohort (Day 1, Day 7, Day 30)
```sql
WITH signup_cohort AS (
    SELECT 
        du.user_id,
        MIN(fse.date_id) AS signup_date
    FROM fact_subscription_events fse
    JOIN dim_user du ON fse.user_id = du.user_id
    WHERE fse.event_type = 'Signup'
    GROUP BY du.user_id
),
viewing_activity AS (
    SELECT 
        sc.user_id,
        sc.signup_date,
        fs.date_id,
        DATEDIFF(day, sc.signup_date, fs.date_id) AS days_since_signup
    FROM signup_cohort sc
    JOIN fact_streams fs ON sc.user_id = fs.user_id
)
SELECT 
    COUNT(DISTINCT user_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN days_since_signup = 1 THEN user_id END) AS day1_retained,
    COUNT(DISTINCT CASE WHEN days_since_signup = 7 THEN user_id END) AS day7_retained,
    COUNT(DISTINCT CASE WHEN days_since_signup = 30 THEN user_id END) AS day30_retained
FROM viewing_activity
GROUP BY signup_date;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (streams, subscriptions)  
✅ **Session Granularity:** Tracks complete viewing sessions  
✅ **Churn Tracking:** Separate subscription events fact  
✅ **Content Hierarchy:** Genre hierarchies for drill-down  
✅ **Device Tracking:** Supports device analytics  

---

## Interview Tips

1. **Grain:** "fact_streams = one view session; fact_subscription_events = one lifecycle change"
2. **Engagement Metric:** "completion_percentage shows how much users actually watch"
3. **Retention:** "Compare signup cohorts with viewing activity over 30 days"
4. **Star Schema:** "Dimensions radiating from facts enable fast query performance"

---

## Follow-Up Questions & Answers

### Q1: "How do we track pause/resume separately from stream completion?"
**A:** Create separate fact table `fact_pause_resume_events`:
```sql
CREATE TABLE fact_pause_resume_events (
    event_id INT PRIMARY KEY,
    stream_id INT FK,
    user_id INT FK,
    content_id INT FK,
    date_id INT FK,
    event_type VARCHAR, -- 'pause' or 'resume'
    timestamp TIMESTAMP,
    playback_position_sec INT
);
```
Keeps stream grain intact, pause/resume as separate events.

### Q2: "What about series vs movie differences in completion rates?"
**A:** Filter by content_type and compare:
```sql
SELECT 
    CASE WHEN dc.content_type = 'Movie' THEN 'Movie'
         WHEN dc.content_type = 'TV Series' THEN 'Series'
    END AS content_type,
    AVG(fs.completion_percentage) AS avg_completion,
    COUNT(*) AS view_count
FROM fact_streams fs
JOIN dim_content dc ON fs.content_id = dc.content_id
GROUP BY dc.content_type;
```

### Q3: "How do we handle subscription tier differences in catalog access?"
**A:** Add tier availability to dim_content:
```sql
ALTER TABLE dim_content 
ADD min_tier_required VARCHAR; -- Basic, Standard, Premium

SELECT * FROM fact_streams fs
JOIN dim_content dc ON fs.content_id = dc.content_id
WHERE dc.min_tier_required <= (
    SELECT tier FROM dim_subscription_tier WHERE tier_id = @user_tier_id
);
```

### Q4: "Should we track trailer views separately?"
**A:** YES - create `fact_trailer_views`:
```sql
CREATE TABLE fact_trailer_views (
    view_id INT PRIMARY KEY,
    user_id INT FK,
    content_id INT FK,
    date_id INT FK,
    duration_watched_sec INT,
    completion_percentage INT
);
```
Different from main content viewing, different business meaning.

### Q5: "What about rating predictions vs actual ratings?"
**A:** Store both in fact_streams or separate fact:
```sql
ALTER TABLE fact_streams 
ADD predicted_rating DECIMAL,
ADD actual_rating INT;

-- Then analyze prediction accuracy
SELECT 
    ROUND(SQRT(AVG(POWER(predicted_rating - actual_rating, 2))), 2) AS rmse
FROM fact_streams
WHERE actual_rating IS NOT NULL;
```

### Q6: "How do we handle content removal from catalog?"
**A:** Use SCD Type 2 for dim_content:
```sql
CREATE TABLE dim_content (
    content_id INT,
    title VARCHAR,
    release_date DATE,
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN,
    version_number INT
);

-- Users can still query what they watched even if content removed
```

### Q7: "What's the cardinality of dim_genre?"
**A:** Low-to-medium (100-1000 genres):
```
Single genres: ~50-100
Sub-genres: ~500-1000
If hierarchical (parent_genre_id): Level 2-3 deep

Easily indexed, no cardinality issues.
```

### Q8: "How do we measure engagement beyond completion?"
**A:** Create engagement score combining multiple metrics:
```sql
SELECT 
    user_id,
    CASE 
        WHEN completion_percentage >= 90 THEN 3
        WHEN completion_percentage >= 50 THEN 2
        WHEN completion_percentage >= 10 THEN 1
        ELSE 0
    END AS engagement_score
FROM fact_streams
WHERE date_id >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);
```

### Q9: "Should device type affect our analysis?"
**A:** YES - viewing patterns differ significantly:
```sql
SELECT 
    device_type,
    AVG(completion_percentage) AS avg_completion,
    COUNT(*) AS views
FROM fact_streams
GROUP BY device_type
ORDER BY avg_completion DESC;

-- Typically: Smart TV > Desktop > Mobile
```

### Q10: "How do we track A/B testing for UI changes?"
**A:** Add experiment tracking dimension:
```sql
CREATE TABLE dim_experiment (
    experiment_id INT PRIMARY KEY,
    experiment_name VARCHAR,
    variant_name VARCHAR,
    start_date DATE,
    end_date DATE
);

-- Link to fact
ALTER TABLE fact_streams ADD experiment_id INT FK;

-- Compare metrics by variant
SELECT 
    de.variant_name,
    AVG(fs.completion_percentage) AS completion,
    COUNT(DISTINCT fs.user_id) AS users
FROM fact_streams fs
LEFT JOIN dim_experiment de ON fs.experiment_id = de.experiment_id
GROUP BY de.variant_name;
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Including all user attributes in fact_streams  
✅ **RIGHT:** Only PKs and FKs in facts, attributes in dim_user

❌ **WRONG:** Mixing movie and series metrics  
✅ **RIGHT:** Filter by content_type or create separate facts

❌ **WRONG:** Aggregating data at load time  
✅ **RIGHT:** Keep stream level, aggregate on query

❌ **WRONG:** Not tracking subscription downgrades  
✅ **RIGHT:** Capture in fact_subscription_events with event_type

---

## One-Liner Reminders

📌 "Grain is one view session, not one user per day."

📌 "completion_percentage is key engagement metric."

📌 "Separate pause/resume from stream completion."

📌 "Content type (movie vs series) drives different analysis."

