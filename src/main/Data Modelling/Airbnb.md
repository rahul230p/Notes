# Airbnb - Hospitality Marketplace Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Hospitality Booking Platform  
**Granularity:** Daily & Booking-level  
**Purpose:** Track bookings, revenue, occupancy, and hosts

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are key metrics? (occupancy rate, revenue, bookings, ARR)
• What questions matter most? (demand, host earnings, guest patterns?)
• What events are tracked? (search, view, booking, cancellation, review)
```

#### Data Specifics
```
• What is the time granularity? (daily, weekly, monthly?)
• Do we track booking life-cycle? (pending, confirmed, completed?)
• How detailed on geographic analysis?
• Do we need host/guest segmentation?
```

### Assumed Answers for This Case
- OLAP system
- Batch pipelines
- Daily analytics
- Marketplace perspective (both host and guest sides)

---

## Star Diagram

```
                    ┌──────────────┐
                    │  dim_guest   │
                    │(Travelers)   │
                    └────────┬─────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │fact_bookings │   │fact_host_   │
            │              │   │payouts      │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │ dim_listing  │   │  dim_host   │
            │(properties)  │   │             │
            └──────────────┘   └─────────────┘
                    │                 │
            ┌───────▼──────────────────▼──────┐
            │    dim_location                 │
            │   (cities/zones)                │
            └──────────────┬───────────────────┘
                           │
                    ┌──────▼──────┐
                    │  dim_date   │
                    │             │
                    └─────────────┘
```

---

## Dimension Tables

### dim_guest
| Column | Type | Description |
|--------|------|-------------|
| **guest_id** (PK) | Integer | Unique guest identifier |
| signup_date | Date | When joined Airbnb |
| country | String | Guest's country |
| city | String | Primary city |
| verification_status | String | Verified/Pending |
| avg_rating | Decimal | Rating from hosts (1-5) |

### dim_host
| Column | Type | Description |
|--------|------|-------------|
| **host_id** (PK) | Integer | Unique host identifier |
| signup_date | Date | When became host |
| country | String | Host's country |
| city | String | Primary city |
| superhost_status | Boolean | Superhost flag |
| avg_rating | Decimal | Rating from guests (1-5) |
| total_listings | Integer | Properties hosted |

### dim_listing
| Column | Type | Description |
|--------|------|-------------|
| **listing_id** (PK) | Integer | Unique listing identifier |
| **host_id** (FK) | Integer | Links to dim_host |
| **location_id** (FK) | Integer | Links to dim_location |
| property_type | String | Apartment/House/Villa |
| bedrooms | Integer | Bedroom count |
| beds | Integer | Bed count |
| max_guests | Integer | Max occupancy |
| amenities | String | Comma-separated list |
| avg_rating | Decimal | Listing rating (1-5) |

### dim_location
| Column | Type | Description |
|--------|------|-------------|
| **location_id** (PK) | Integer | Unique location identifier |
| country | String | Country name |
| state | String | State/Province |
| city | String | City name |
| neighborhood | String | Neighborhood name |
| latitude | Decimal | GPS latitude |
| longitude | Decimal | GPS longitude |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| **date_id** (PK) | Integer | Date key (YYYYMMDD) |
| calendar_date | Date | Full date |
| day_of_week | String | Mon-Sun |
| month | Integer | 1-12 |
| year | Integer | Year |
| is_weekend | Boolean | Weekend flag |
| is_holiday | Boolean | Holiday flag |

---

## Fact Tables

### fact_bookings ⭐
**Grain:** One row per booking (confirmed, completed, or cancelled)

| Column | Type | Description |
|--------|------|-------------|
| **booking_id** (PK) | Integer | Unique booking identifier |
| **guest_id** (FK) | Integer | Links to dim_guest |
| **listing_id** (FK) | Integer | Links to dim_listing |
| **host_id** (FK) | Integer | Links to dim_host |
| **checkin_date_id** (FK) | Integer | Links to dim_date |
| **checkout_date_id** (FK) | Integer | Links to dim_date |
| booking_date | Date | When booking was made |
| guest_count | Integer | Number of guests |
| total_nights | Integer | Length of stay |
| base_price | Decimal | Nightly rate |
| cleaning_fee | Decimal | Cleaning charge |
| service_fee | Decimal | Airbnb service fee |
| total_price | Decimal | Total charged |
| booking_status | String | Confirmed/Completed/Cancelled |

### fact_host_payouts ⭐
**Grain:** One row per host per payout period

| Column | Type | Description |
|--------|------|-------------|
| **payout_id** (PK) | Integer | Unique payout identifier |
| **host_id** (FK) | Integer | Links to dim_host |
| **date_id** (FK) | Integer | Links to dim_date |
| payout_period | String | Monthly/Weekly |
| total_earnings | Decimal | Total paid to host |
| total_bookings | Integer | Bookings in period |
| total_nights | Integer | Total nights hosted |
| cleaning_fees_earned | Decimal | Cleaning fees received |
| service_fees_charged | Decimal | Airbnb fees deducted |

---

## Key Relationships

```
dim_guest (1) ──< (N) fact_bookings

dim_host (1) ──< (N) dim_listing
dim_host (1) ──< (N) fact_bookings
dim_host (1) ──< (N) fact_host_payouts

dim_listing (1) ──< (N) fact_bookings

dim_location (1) ──< (N) dim_listing
dim_location (1) ──< (N) dim_host

dim_date (1) ──< (N) fact_bookings (checkin)
dim_date (1) ──< (N) fact_bookings (checkout)
dim_date (1) ──< (N) fact_host_payouts
```

---

## Core Analytics Queries

### 1. Daily Bookings & Revenue
```sql
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fb.booking_id) AS bookings,
    COUNT(DISTINCT fb.guest_id) AS unique_guests,
    SUM(fb.total_price) AS daily_revenue,
    AVG(fb.total_price) AS avg_booking_value
FROM fact_bookings fb
JOIN dim_date dd ON fb.booking_date = dd.calendar_date
WHERE fb.booking_status IN ('Confirmed', 'Completed')
GROUP BY dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### 2. Occupancy Rate by City
```sql
SELECT 
    dl.city,
    dd.year,
    dd.month,
    COUNT(DISTINCT dl.location_id) AS total_listings,
    SUM(CASE WHEN fb.booking_status = 'Completed' THEN fb.total_nights ELSE 0 END) AS booked_nights,
    SUM(fb.total_nights) AS available_nights,
    ROUND(100.0 * SUM(CASE WHEN fb.booking_status = 'Completed' THEN fb.total_nights ELSE 0 END) / 
          SUM(fb.total_nights), 2) AS occupancy_rate_pct
FROM fact_bookings fb
JOIN dim_listing dl ON fb.listing_id = dl.listing_id
JOIN dim_location dl ON dl.location_id = dl.location_id
JOIN dim_date dd ON fb.checkin_date_id = dd.date_id
GROUP BY dl.city, dd.year, dd.month
ORDER BY occupancy_rate_pct DESC;
```

### 3. Top 20 Properties by Revenue
```sql
SELECT TOP 20
    dl.listing_id,
    dh.host_name,
    dl.property_type,
    dl.bedrooms,
    COUNT(fb.booking_id) AS total_bookings,
    SUM(fb.total_nights) AS nights_hosted,
    SUM(fb.total_price) AS total_revenue,
    AVG(fb.total_price) AS avg_booking_value
FROM fact_bookings fb
JOIN dim_listing dl ON fb.listing_id = dl.listing_id
JOIN dim_host dh ON fb.host_id = dh.host_id
WHERE fb.booking_status IN ('Confirmed', 'Completed')
GROUP BY dl.listing_id, dh.host_name, dl.property_type, dl.bedrooms
ORDER BY total_revenue DESC;
```

### 4. Booking Status Distribution
```sql
SELECT 
    fb.booking_status,
    COUNT(fb.booking_id) AS booking_count,
    ROUND(100.0 * COUNT(fb.booking_id) / SUM(COUNT(fb.booking_id)) OVER (), 2) AS percentage,
    SUM(fb.total_price) AS revenue_impact
FROM fact_bookings fb
GROUP BY fb.booking_status;
```

### 5. Host Earnings Analysis
```sql
SELECT TOP 20
    dh.host_id,
    dh.host_name,
    dh.superhost_status,
    SUM(fhp.total_earnings) AS lifetime_earnings,
    SUM(fhp.total_bookings) AS total_bookings,
    AVG(fhp.total_earnings) AS avg_monthly_earnings,
    COUNT(DISTINCT fhp.payout_id) AS payout_periods
FROM fact_host_payouts fhp
JOIN dim_host dh ON fhp.host_id = dh.host_id
GROUP BY dh.host_id, dh.host_name, dh.superhost_status
ORDER BY lifetime_earnings DESC;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (bookings, payouts)  
✅ **Marketplace Model:** Tracks both guest and host perspectives  
✅ **Stay Duration:** total_nights enables occupancy calculations  
✅ **Revenue Tracking:** Separate payout fact for host earnings  
✅ **Geographic Analysis:** Location dimension for city-level metrics  

---

## Interview Tips

1. **Grain:** "fact_bookings = one reservation; fact_host_payouts = one payout period"
2. **Occupancy Formula:** "booked_nights / total_available_nights shows listing utilization"
3. **Two Perspectives:** "Bookings track guest behavior; payouts track host earnings"
4. **Star Schema:** "All dimensions radiate from central facts for efficient OLAP queries"

---

## Follow-Up Questions & Answers

### Q1: "How do we handle cancellations by guests vs hosts?"
**A:** Include cancellation tracking in fact_bookings:
```sql
ALTER TABLE fact_bookings 
ADD cancelled_by VARCHAR, -- 'guest', 'host', 'system'
ADD cancellation_reason VARCHAR,
ADD refund_percentage INT;

SELECT 
    cancelled_by,
    COUNT(*) AS cancellations,
    AVG(refund_percentage) AS avg_refund_pct
FROM fact_bookings
WHERE booking_status = 'Cancelled'
GROUP BY cancelled_by;
```

### Q2: "What about split bookings (multiple properties per trip)?"
**A:** Each property is separate booking row:
```sql
-- User books multiple properties for same trip
SELECT 
    guest_id,
    checkin_date,
    COUNT(DISTINCT listing_id) AS properties_booked,
    SUM(total_price) AS total_spend
FROM fact_bookings
WHERE booking_status = 'Completed'
GROUP BY guest_id, checkin_date
HAVING COUNT(DISTINCT listing_id) > 1;
```

### Q3: "How do we track dynamic pricing changes?"
**A:** Implement SCD Type 2 for dim_listing or track in fact:
```sql
ALTER TABLE fact_bookings 
ADD base_nightly_rate DECIMAL,
ADD surge_multiplier DECIMAL,
ADD seasonal_multiplier DECIMAL;

-- Can then analyze pricing impact
SELECT 
    seasonal_multiplier,
    COUNT(*) AS bookings,
    AVG(rating) AS avg_rating
FROM fact_bookings
GROUP BY seasonal_multiplier;
```

### Q4: "Should reviews be a separate fact table?"
**A:** YES - reviews are separate events:
```sql
CREATE TABLE fact_reviews (
    review_id INT PRIMARY KEY,
    booking_id INT FK,
    guest_id INT FK,
    host_id INT FK,
    listing_id INT FK,
    date_id INT FK,
    rating INT, -- 1-5
    review_text VARCHAR,
    review_date DATE
);
```
Different from booking grain, can have multiple reviews per booking.

### Q5: "What about disputed charges or chargebacks?"
**A:** Create separate fact table:
```sql
CREATE TABLE fact_payment_disputes (
    dispute_id INT PRIMARY KEY,
    booking_id INT FK,
    guest_id INT FK,
    host_id INT FK,
    date_id INT FK,
    dispute_amount DECIMAL,
    dispute_reason VARCHAR,
    resolution VARCHAR -- 'guest_refunded', 'host_paid', 'split'
);
```

### Q6: "How do we calculate host earnings accurately?"
**A:** Fact_host_payouts consolidates after fees:
```sql
SELECT 
    dh.host_id,
    dh.host_name,
    SUM(fhp.total_earnings) AS gross_earnings,
    SUM(fhp.service_fees_charged) AS fees_paid,
    SUM(fhp.total_earnings) - SUM(fhp.service_fees_charged) AS net_earnings
FROM fact_host_payouts fhp
JOIN dim_host dh ON fhp.host_id = dh.host_id
GROUP BY dh.host_id, dh.host_name
ORDER BY net_earnings DESC;
```

### Q7: "Should property type affect occupancy analysis?"
**A:** YES - filter by property type:
```sql
SELECT 
    dp.property_type,
    COUNT(DISTINCT dp.listing_id) AS listings,
    SUM(CASE WHEN fb.booking_status = 'Completed' THEN fb.total_nights ELSE 0 END) AS booked_nights,
    ROUND(100.0 * SUM(CASE WHEN fb.booking_status = 'Completed' THEN fb.total_nights ELSE 0 END) /
          (COUNT(DISTINCT dp.listing_id) * 365), 2) AS annual_occupancy_rate
FROM fact_bookings fb
JOIN dim_listing dp ON fb.listing_id = dp.listing_id
GROUP BY dp.property_type;
```

### Q8: "What's the cardinality of dim_listing?"
**A:** HIGH cardinality (1M-50M+ listings globally):
```
• Single city: 10K-100K listings
• Country: 100K-1M listings
• Global: 10M+ listings

Index on city_id and property_type for query performance.
Need proper partitioning strategies.
```

### Q9: "How do we track host response time to bookings?"
**A:** Add timestamp tracking:
```sql
ALTER TABLE fact_bookings 
ADD requested_at TIMESTAMP,
ADD confirmed_at TIMESTAMP;

SELECT 
    DATEDIFF(hour, requested_at, confirmed_at) AS response_time_hours,
    COUNT(*) AS bookings,
    AVG(rating) AS avg_rating
FROM fact_bookings
GROUP BY DATEDIFF(hour, requested_at, confirmed_at)
ORDER BY avg_rating DESC;
```

### Q10: "Should we track guest vs host communication?"
**A:** Create separate fact:
```sql
CREATE TABLE fact_messages (
    message_id INT PRIMARY KEY,
    booking_id INT FK,
    from_user_id INT FK, -- guest_id or host_id
    to_user_id INT FK,
    date_id INT FK,
    message_timestamp TIMESTAMP,
    message_length INT,
    has_image BOOLEAN
);

-- Enables "response time" analysis
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Including guest feedback in host dimension  
✅ **RIGHT:** Track separately in fact_reviews

❌ **WRONG:** Storing pricing history in fact_bookings  
✅ **RIGHT:** Snapshot pricing at booking time, track changes in SCD

❌ **WRONG:** Aggregating bookings to property-month level  
✅ **RIGHT:** Keep booking grain, aggregate on query

❌ **WRONG:** Missing cancellation scenarios in analysis  
✅ **RIGHT:** Include cancelled bookings with status tracking

---

## One-Liner Reminders

📌 "Grain: one row per booking (confirmed, completed, or cancelled)."

📌 "Occupancy = booked_nights / total_available_nights."

📌 "Track both guest and host sides as separate perspectives."

📌 "Reviews, disputes, messages are separate facts."

