# Fitness App - Wearable Device Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Fitness & Wellness Tracking  
**Granularity:** Daily & Event-level  
**Purpose:** Track user activities, engagement, and health metrics

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are key metrics? (DAU, active minutes, workout completion)
• What health metrics matter? (steps, calories, heart rate, sleep?)
• What events are tracked? (activity, login, challenges, achievements)
```

#### Data Specifics
```
• What is the time granularity? (hourly, daily, real-time?)
• How detailed should activity tracking be?
• Do we need device-level tracking?
• Do we have social/challenge features to track?
```

### Assumed Answers for This Case
- OLAP system
- Daily analytics with event granularity
- Track activities, logins, and engagement
- Device accuracy matters

---

## Star Diagram

```
                    ┌─────────────────┐
                    │   dim_user      │
                    │ (Wearable users)│
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │fact_activity │   │fact_login   │
            │  _events     │   │ _events     │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │dim_activity_ │   │  dim_date   │
            │  type        │   │             │
            └──────────────┘   └─────────────┘
                    │
            ┌───────▼──────┐
            │  dim_device  │
            │ (Wearables)  │
            └──────────────┘
```

---

## Dimension Tables

### dim_user
| Column | Type | Description |
|--------|------|-------------|
| **user_id** (PK) | Integer | Unique user identifier |
| signup_date | Date | When user joined |
| age_group | String | Age bracket |
| gender | String | Male/Female/Other |
| country | String | User's country |
| timezone | String | Time zone |

### dim_activity_type
| Column | Type | Description |
|--------|------|-------------|
| **activity_type_id** (PK) | Integer | Unique activity identifier |
| activity_name | String | Walking, Running, Heart Rate, etc. |
| unit | String | Steps, BPM, kcal, etc. |

### dim_device
| Column | Type | Description |
|--------|------|-------------|
| **device_id** (PK) | Integer | Unique device identifier |
| device_model | String | Apple Watch, Fitbit, etc. |
| os_version | String | Operating system version |
| firmware_version | String | Firmware version |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| **date_id** (PK) | Integer | Date key (YYYYMMDD) |
| calendar_date | Date | Full date |
| day_of_week | String | Mon-Sun |
| week | Integer | Week number |
| month | Integer | 1-12 |
| year | Integer | Year |
| is_weekend | Boolean | Weekend flag |

---

## Fact Tables

### fact_activity_events ⭐
**Grain:** One row per user per activity per timestamp

| Column | Type | Description |
|--------|------|-------------|
| **event_id** (PK) | Integer | Unique event identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **activity_type_id** (FK) | Integer | Links to dim_activity_type |
| **device_id** (FK) | Integer | Links to dim_device |
| **date_id** (FK) | Integer | Links to dim_date |
| activity_timestamp | Timestamp | When activity recorded |
| steps | Integer | Step count |
| calories | Decimal | Calories burned |
| heart_rate | Integer | Heart rate (BPM) |
| duration_minutes | Integer | Activity duration |

### fact_login_events ⭐
**Grain:** One row per user per login session

| Column | Type | Description |
|--------|------|-------------|
| **login_id** (PK) | Integer | Unique login identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **device_id** (FK) | Integer | Links to dim_device |
| **date_id** (FK) | Integer | Links to dim_date |
| login_timestamp | Timestamp | When user logged in |

---

## Key Relationships

```
dim_user (1) ──< (N) fact_activity_events
dim_user (1) ──< (N) fact_login_events

dim_activity_type (1) ──< (N) fact_activity_events
dim_device (1) ──< (N) fact_activity_events
dim_device (1) ──< (N) fact_login_events

dim_date (1) ──< (N) fact_activity_events
dim_date (1) ──< (N) fact_login_events
```

---

## Core Analytics Queries

### 1. Average Steps Per User Per Day
```sql
SELECT 
    f.user_id,
    dt.calendar_date,
    AVG(f.steps) AS avg_steps
FROM fact_activity_events f
JOIN dim_activity_type dat ON f.activity_type_id = dat.activity_type_id
JOIN dim_date dt ON f.date_id = dt.date_id
WHERE dat.activity_name = 'Walking'
GROUP BY f.user_id, dt.calendar_date
ORDER BY dt.calendar_date DESC;
```

### 2. Daily Active Users (DAU)
```sql
SELECT 
    dt.calendar_date,
    COUNT(DISTINCT f.user_id) AS dau
FROM fact_login_events f
JOIN dim_date dt ON f.date_id = dt.date_id
GROUP BY dt.calendar_date
ORDER BY dt.calendar_date DESC;
```

### 3. Monthly Active Users (MAU)
```sql
SELECT 
    dt.year,
    dt.month,
    COUNT(DISTINCT f.user_id) AS mau
FROM fact_login_events f
JOIN dim_date dt ON f.date_id = dt.date_id
GROUP BY dt.year, dt.month
ORDER BY dt.year DESC, dt.month DESC;
```

### 4. Top 10 Most Active Users by Steps
```sql
SELECT TOP 10
    f.user_id,
    SUM(f.steps) AS total_steps,
    COUNT(DISTINCT f.date_id) AS active_days,
    AVG(f.steps) AS avg_steps_per_day
FROM fact_activity_events f
JOIN dim_activity_type dat ON f.activity_type_id = dat.activity_type_id
WHERE dat.activity_name = 'Walking'
GROUP BY f.user_id
ORDER BY total_steps DESC;
```

### 5. User Retention (Day 1, Day 7, Day 30)
```sql
WITH user_signup AS (
    SELECT 
        u.user_id,
        MIN(du.signup_date) AS signup_date
    FROM dim_user du
    GROUP BY u.user_id, du.signup_date
),
login_activity AS (
    SELECT 
        us.user_id,
        us.signup_date,
        dt.calendar_date,
        DATEDIFF(day, us.signup_date, dt.calendar_date) AS days_since_signup
    FROM user_signup us
    JOIN fact_login_events f ON us.user_id = f.user_id
    JOIN dim_date dt ON f.date_id = dt.date_id
)
SELECT 
    COUNT(DISTINCT user_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN days_since_signup = 1 THEN user_id END) AS day1_retained,
    COUNT(DISTINCT CASE WHEN days_since_signup = 7 THEN user_id END) AS day7_retained,
    COUNT(DISTINCT CASE WHEN days_since_signup = 30 THEN user_id END) AS day30_retained
FROM login_activity;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (activities, logins)  
✅ **Event-Based:** Each fact = one business event  
✅ **Clean Grain:** Activity events vs. login events  
✅ **Extensible:** Easy to add sleep, workouts as new facts  
✅ **Device Tracking:** Supports device accuracy analysis  

---

## Interview Tips

1. **Grain Definition:** "fact_activity_events = one recorded activity; fact_login_events = one login session"
2. **Why 2 Facts?** "Activities are sensor data; logins track engagement - different granularity"
3. **Star Schema:** "User dimension at center connects to facts; activities/dates provide context"
4. **Extensibility:** "To add sleep tracking, create fact_sleep_events reusing existing dimensions"

---

## Follow-Up Questions & Answers

### Q1: "What if we want to track sleep data?"
**A:** Create a new fact table `fact_sleep_events`:
```sql
CREATE TABLE fact_sleep_events (
    sleep_id INT PRIMARY KEY,
    user_id INT FK,
    device_id INT FK,
    date_id INT FK,
    sleep_start_time TIMESTAMP,
    sleep_end_time TIMESTAMP,
    duration_minutes INT,
    sleep_quality INT,
    heart_rate_variability INT
);
```
Reuse dim_user, dim_device, dim_date. No breaking changes to existing queries.

### Q2: "How do we handle multiple activities in one day?"
**A:** That's exactly why we have one row per activity per timestamp in fact_activity_events.
```sql
-- Multiple activities same day are separate rows
SELECT * FROM fact_activity_events 
WHERE user_id = 123 AND date_id = 20260127;
-- Returns: Walking at 7am, Running at 6pm, etc.
```

### Q3: "What about device accuracy - does it matter?"
**A:** Yes, track it in dim_device and filter if needed:
```sql
-- Query only accurate devices
SELECT f.* 
FROM fact_activity_events f
JOIN dim_device d ON f.device_id = d.device_id
WHERE d.device_model IN ('Apple Watch Series 9', 'Fitbit Sense 2')
```

### Q4: "How do we measure workout completion rates?"
**A:** Add a flag to fact_activity_events:
```sql
ALTER TABLE fact_activity_events 
ADD completion_percentage INT; -- 0-100%

-- Query completion
SELECT 
    AVG(completion_percentage) AS avg_completion,
    COUNT(*) AS total_workouts
FROM fact_activity_events
WHERE activity_type_id = 3; -- Running
```

### Q5: "What if a user doesn't log in but still has activity data?"
**A:** Both facts work independently:
```sql
-- Users with activity but no login
SELECT DISTINCT fa.user_id
FROM fact_activity_events fa
WHERE NOT EXISTS (
    SELECT 1 FROM fact_login_events fl 
    WHERE fl.user_id = fa.user_id 
    AND fl.date_id = fa.date_id
);
```

### Q6: "Can we track social features like challenges?"
**A:** Add new fact table `fact_challenge_events`:
```sql
CREATE TABLE fact_challenge_events (
    challenge_id INT PRIMARY KEY,
    user_id INT FK,
    challenge_name VARCHAR,
    date_id INT FK,
    is_completed BOOLEAN,
    progress_percentage INT
);
```

### Q7: "How do we handle timezone differences?"
**A:** Store user timezone in dim_user and convert during queries:
```sql
SELECT 
    dt.calendar_date,
    CONVERT_TZ(f.activity_timestamp, 'UTC', du.timezone) AS local_time
FROM fact_activity_events f
JOIN dim_user du ON f.user_id = du.user_id
JOIN dim_date dt ON f.date_id = dt.date_id;
```

### Q8: "What's the cardinality of dim_activity_type?"
**A:** Low cardinality - typically 10-20 types:
```
• Walking
• Running  
• Cycling
• Swimming
• Heart Rate Monitor
• Sleep Tracking
• Meditation
• Strength Training
```
Easily fits in memory, no indexing issues.

### Q9: "How do we handle missing data from devices?"
**A:** Use NULL or default values, track separately:
```sql
-- Count missing data
SELECT 
    COALESCE(activity_type_id, -1) AS activity_type,
    COUNT(*) AS event_count
FROM fact_activity_events
WHERE steps IS NULL OR heart_rate IS NULL
GROUP BY activity_type;
```

### Q10: "Should we pre-aggregate daily summaries?"
**A:** Keep raw events first, pre-aggregate if performance needs it:
```sql
-- Create materialized view for daily summaries
CREATE MATERIALIZED VIEW fact_daily_activity_summary AS
SELECT 
    user_id,
    date_id,
    SUM(steps) AS daily_steps,
    AVG(heart_rate) AS avg_heart_rate,
    SUM(calories) AS daily_calories,
    COUNT(DISTINCT activity_type_id) AS activity_types
FROM fact_activity_events
GROUP BY user_id, date_id;
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Storing daily summary instead of raw events  
✅ **RIGHT:** Store events, aggregate on query

❌ **WRONG:** Mixing activity types into one row  
✅ **RIGHT:** One row per activity per timestamp

❌ **WRONG:** Including device in dim_user  
✅ **RIGHT:** Separate dim_device for tracking changes

❌ **WRONG:** Using VARCHAR for activity types  
✅ **RIGHT:** Use dim_activity_type with integer FK

---

## One-Liner Reminders

📌 "Grain is one activity per timestamp, not one per day."

📌 "Activities and logins are separate events with different frequencies."

📌 "Device dimension enables device-level accuracy tracking."

📌 "Extensibility: add new facts without modifying existing tables."

