# Uber - Ride-Sharing Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Ride-Sharing Platform  
**Granularity:** Hourly and Daily  
**Purpose:** Track trips, drivers, demand, and revenue

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are the key metrics? (DAU, revenue, driver utilization)
• Do we care about peak demand analysis by hour?
• What geography scope? (single city, multi-city, global?)
```

#### Data Specifics
```
• What is the time granularity? (hourly, daily, real-time?)
• Do we track surge pricing impact?
• How are rides measured? (completed rides, requests, cancellations?)
• Do we need driver-level detail or aggregated metrics?
```

### Assumed Answers for This Case
- OLAP system
- Batch pipelines
- Hourly granularity for peak analysis
- Global multi-city operation

---

## Star Diagram

```
                    ┌──────────────┐
                    │  dim_user    │
                    │  (Riders)    │
                    └────────┬─────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │ fact_trips   │   │ fact_driver │
            │              │   │  _events    │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │  dim_driver  │   │dim_location │
            │              │   │   (zones)   │
            └──────────────┘   └─────────────┘
                    │                 │
            ┌───────▼──────────────────▼──────┐
            │    dim_date_hour                │
            │   (hourly granularity)          │
            └─────────────────────────────────┘
```

---

## Dimension Tables

### dim_user (Riders)
| Column | Type | Description |
|--------|------|-------------|
| **user_id** (PK) | Integer | Unique rider identifier |
| signup_date | Date | When rider joined |
| country | String | Rider's country |
| city | String | Primary city |
| account_type | String | Personal/Business |
| avg_rating | Decimal | Rider rating (1-5) |
| total_trips | Integer | Lifetime trips |

### dim_driver
| Column | Type | Description |
|--------|------|-------------|
| **driver_id** (PK) | Integer | Unique driver identifier |
| signup_date | Date | When driver joined |
| city | String | Primary city |
| avg_rating | Decimal | Driver rating (1-5) |
| total_trips | Integer | Lifetime trips |
| verification_status | String | Verified/Pending |

### dim_location
| Column | Type | Description |
|--------|------|-------------|
| **location_id** (PK) | Integer | Unique location identifier |
| latitude | Decimal | GPS latitude |
| longitude | Decimal | GPS longitude |
| city | String | City name |
| neighborhood | String | Neighborhood name |
| zone_id | String | Zone code |

### dim_date_hour
| Column | Type | Description |
|--------|------|-------------|
| **date_hour_id** (PK) | Integer | Key (YYYYMMDDHH) |
| calendar_date | Date | Date portion |
| hour_of_day | Integer | 0-23 |
| day_of_week | String | Mon-Sun |
| month | Integer | 1-12 |
| year | Integer | Year |
| is_peak_hour | Boolean | Rush hour flag |

---

## Fact Tables

### fact_trips ⭐
**Grain:** One row per completed or cancelled trip

| Column | Type | Description |
|--------|------|-------------|
| **trip_id** (PK) | Integer | Unique trip identifier |
| **user_id** (FK) | Integer | Links to dim_user |
| **driver_id** (FK) | Integer | Links to dim_driver |
| **pickup_location_id** (FK) | Integer | Links to dim_location |
| **dropoff_location_id** (FK) | Integer | Links to dim_location |
| **date_hour_id** (FK) | Integer | Links to dim_date_hour |
| distance_km | Decimal | Trip distance |
| duration_minutes | Integer | Trip duration |
| base_fare | Decimal | Base cost |
| surge_multiplier | Decimal | 1.0x, 1.5x, 2.0x, etc. |
| total_fare | Decimal | Final charged amount |
| status | String | Completed/Cancelled |

### fact_driver_events ⭐
**Grain:** One row per driver hourly status snapshot

| Column | Type | Description |
|--------|------|-------------|
| **event_id** (PK) | Integer | Unique event identifier |
| **driver_id** (FK) | Integer | Links to dim_driver |
| **location_id** (FK) | Integer | Links to dim_location |
| **date_hour_id** (FK) | Integer | Links to dim_date_hour |
| status | String | Online/Offline |
| hours_worked | Decimal | Hours online in this hour |
| trips_completed | Integer | Trips in this hour |
| revenue_earned | Decimal | Total earned this hour |

---

## Key Relationships

```
dim_user (1) ──< (N) fact_trips

dim_driver (1) ──< (N) fact_trips
dim_driver (1) ──< (N) fact_driver_events

dim_location (1) ──< (N) fact_trips (pickup)
dim_location (1) ──< (N) fact_trips (dropoff)
dim_location (1) ──< (N) fact_driver_events

dim_date_hour (1) ──< (N) fact_trips
dim_date_hour (1) ──< (N) fact_driver_events
```

---

## Core Analytics Queries

### 1. Daily Active Users & Rides
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT ft.user_id) AS dau,
    COUNT(DISTINCT ft.trip_id) AS total_trips,
    SUM(ft.total_fare) AS daily_revenue
FROM fact_trips ft
JOIN dim_date_hour dd ON ft.date_hour_id = dd.date_hour_id
WHERE ft.status = 'Completed'
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### 2. Driver Utilization Rate
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fde.driver_id) AS active_drivers,
    COUNT(DISTINCT ft.driver_id) AS drivers_with_trips,
    ROUND(100.0 * COUNT(DISTINCT ft.driver_id) / COUNT(DISTINCT fde.driver_id), 2) AS utilization_rate_pct
FROM fact_driver_events fde
LEFT JOIN fact_trips ft ON fde.driver_id = ft.driver_id 
    AND DATE(fde.date_hour_id) = DATE(ft.date_hour_id)
JOIN dim_date_hour dd ON fde.date_hour_id = dd.date_hour_id
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### 3. Revenue by City
```sql
SELECT 
    dl.city,
    SUM(ft.total_fare) AS total_revenue,
    COUNT(ft.trip_id) AS trips,
    AVG(ft.total_fare) AS avg_fare
FROM fact_trips ft
JOIN dim_location dl ON ft.pickup_location_id = dl.location_id
WHERE ft.status = 'Completed'
GROUP BY dl.city
ORDER BY total_revenue DESC;
```

### 4. Peak Hours Analysis
```sql
SELECT 
    dd.hour_of_day,
    dl.city,
    COUNT(ft.trip_id) AS trips,
    AVG(ft.surge_multiplier) AS avg_surge,
    SUM(ft.total_fare) AS revenue
FROM fact_trips ft
JOIN dim_location dl ON ft.pickup_location_id = dl.location_id
JOIN dim_date_hour dd ON ft.date_hour_id = dd.date_hour_id
WHERE ft.status = 'Completed'
GROUP BY dd.hour_of_day, dl.city
ORDER BY dd.hour_of_day, revenue DESC;
```

### 5. Top Drivers by Earnings
```sql
SELECT TOP 20
    dd.driver_id,
    COUNT(ft.trip_id) AS trips,
    SUM(ft.total_fare) AS total_earnings,
    AVG(ft.total_fare) AS avg_fare_per_trip,
    AVG(DATEDIFF(MINUTE, ft.start_time, ft.end_time)) AS avg_trip_duration
FROM fact_trips ft
JOIN dim_driver dd ON ft.driver_id = dd.driver_id
WHERE ft.status = 'Completed'
GROUP BY dd.driver_id
ORDER BY total_earnings DESC;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (trips, driver events)  
✅ **Hourly Granularity:** Supports peak demand analysis  
✅ **Geospatial:** Location dimension for city/zone analytics  
✅ **Supply & Demand:** Separate facts for drivers and trips  
✅ **Surge Tracking:** Built into trip fact for revenue analysis  

---

## Interview Tips

1. **Grain:** "fact_trips = one row per completed/cancelled trip; fact_driver_events = hourly driver status"
2. **Why 2 Facts?** "Trips are customer transactions, driver_events track supply availability"
3. **Peak Hours:** "Combine hour_of_day with surge_multiplier to see pricing impact"
4. **Star Schema:** "All dimensions radiate from central facts for efficient queries"

---

## Follow-Up Questions & Answers

### Q1: "How do we track cancelled trips?"
**A:** Include status column in fact_trips and filter by status:
```sql
SELECT 
    status,
    COUNT(*) AS trip_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM fact_trips
GROUP BY status;

-- Result: Completed, Cancelled by Driver, Cancelled by User, No Show
```

### Q2: "What about driver surge pricing - how is it calculated?"
**A:** Track surge_multiplier in fact_trips:
```sql
SELECT 
    dd.hour_of_day,
    AVG(ft.surge_multiplier) AS avg_surge,
    COUNT(DISTINCT ft.trip_id) AS trips
FROM fact_trips ft
JOIN dim_date_hour dd ON ft.date_hour_id = dd.date_hour_id
WHERE dd.is_peak_hour = 1
GROUP BY dd.hour_of_day
ORDER BY avg_surge DESC;
```

### Q3: "How do we handle multiple drivers declining a request?"
**A:** Create separate fact table `fact_driver_decline_events`:
```sql
CREATE TABLE fact_driver_decline_events (
    decline_id INT PRIMARY KEY,
    trip_id INT FK,
    driver_id INT FK,
    date_hour_id INT FK,
    declined_at TIMESTAMP,
    reason VARCHAR
);
```
No impact on existing queries, extension via new fact.

### Q4: "Should we track driver ratings separately?"
**A:** Yes, create `fact_driver_rating_events`:
```sql
CREATE TABLE fact_driver_rating_events (
    rating_id INT PRIMARY KEY,
    driver_id INT FK,
    trip_id INT FK,
    date_id INT FK,
    rating INT,
    feedback_text VARCHAR
);
```
Separate from trips to handle multiple ratings per trip.

### Q5: "What's the cardinality of location dimension?"
**A:** Medium cardinality (10K-100K locations depending on granularity):
```
• City level: 500 locations
• Neighborhood: 10K locations
• GPS grid (1km²): 1M+ locations

Use neighborhood level for balance between detail and performance.
```

### Q6: "How do we calculate driver utilization?"
**A:** Compare active drivers with drivers having trips:
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fde.driver_id) AS active_drivers,
    COUNT(DISTINCT ft.driver_id) AS drivers_with_trips,
    ROUND(100.0 * COUNT(DISTINCT ft.driver_id) / 
          COUNT(DISTINCT fde.driver_id), 2) AS utilization_pct
FROM fact_driver_events fde
LEFT JOIN fact_trips ft ON fde.driver_id = ft.driver_id 
    AND DATE(fde.date_hour_id) = DATE(ft.date_hour_id)
JOIN dim_date_hour dd ON fde.date_hour_id = dd.date_hour_id
GROUP BY dd.calendar_date;
```

### Q7: "What about ride_type dimension changes (new ride types added)?"
**A:** Implement SCD Type 1 (overwrite) unless historical comparison needed:
```sql
-- Type 1: Just update
UPDATE dim_ride_type 
SET base_fare = 2.50 
WHERE ride_type_id = 1;

-- Type 2: Keep history
INSERT INTO dim_ride_type 
VALUES (1, 'UberX', 2.50, ..., '2026-01-27', GETDATE(), 1);
```

### Q8: "How do we detect surge pricing abuse?"
**A:** Analyze surge multiplier outliers:
```sql
SELECT 
    ft.trip_id,
    ft.surge_multiplier,
    AVG(ft2.surge_multiplier) OVER (
        PARTITION BY DATE(ft.date_hour_id)
        ORDER BY ft.date_hour_id ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING
    ) AS rolling_avg_surge
FROM fact_trips ft
JOIN fact_trips ft2 ON DATE(ft.date_hour_id) = DATE(ft2.date_hour_id)
WHERE ft.surge_multiplier > 5.0; -- Extreme surge
```

### Q9: "Should pickup and dropoff be separate locations?"
**A:** YES - essential for geographic analysis:
```sql
-- CORRECT
fact_trips:
  pickup_location_id FK
  dropoff_location_id FK

-- Enables queries like:
SELECT 
    dl_pickup.city_name AS from_city,
    dl_dropoff.city_name AS to_city,
    COUNT(*) AS trips
FROM fact_trips ft
JOIN dim_location dl_pickup ON ft.pickup_location_id = dl_pickup.location_id
JOIN dim_location dl_dropoff ON ft.dropoff_location_id = dl_dropoff.location_id
GROUP BY dl_pickup.city_name, dl_dropoff.city_name;
```

### Q10: "What if a driver accepts a trip but never shows up?"
**A:** Status field captures this:
```sql
SELECT 
    status,
    COUNT(*) AS count
FROM fact_trips
GROUP BY status;

-- Status values: 
-- Completed, CancelledByDriver, CancelledByUser, 
-- NoShow, DriverNoShow, RequestExpired
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Single location dimension (confuses pickup/dropoff)  
✅ **RIGHT:** Separate FK columns for pickup and dropoff

❌ **WRONG:** Driver rating in dim_driver (doesn't change monthly)  
✅ **RIGHT:** Rating as SCD Type 2 or separate fact table

❌ **WRONG:** Aggregating trips by hour in fact table  
✅ **RIGHT:** Keep trip-level grain, aggregate on query

❌ **WRONG:** Ignoring cancelled trips  
✅ **RIGHT:** Include with status = 'Cancelled'

---

## One-Liner Reminders

📌 "Two distinct location FKs: pickup_location_id and dropoff_location_id."

📌 "Driver events track supply; trips track demand."

📌 "Surge multiplier lives in fact, not dimension."

📌 "Hourly granularity matters for peak hour analysis."

