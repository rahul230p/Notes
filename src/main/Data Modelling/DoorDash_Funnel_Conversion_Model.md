# Food Delivery App - DoorDash Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Food Delivery Platform  
**Granularity:** Daily & Order-level  
**Purpose:** Track orders, funnel conversion, and customer behavior

---

## ⚠️ Clarifying Questions (ASK FIRST - VERY IMPORTANT)

Always start with these. This signals seniority.

### Required Questions to Ask

#### System & Infrastructure
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• Are pipelines batch or streaming?
• What is the time granularity? (daily, hourly, real-time?)
```

#### Business Context
```
• What are the core business questions?
• What is the data volume? (users, orders, events)
• What are key metrics? (DAU, AOV, conversion, retention)
```

#### Data Specifics
```
• Can an order have multiple items or cuisines?
• How is city defined? (order city vs user home city?)
• Are promotions/referrals in scope?
• Do we track delivery metrics?
```

### Assumed Answers for This Case
- OLAP system (analytics focus)
- Batch pipelines
- High volume (millions of users, billions of orders)
- Read efficiency is critical
- Orders have multiple items
- City = order delivery location (not customer home)

---

## Star Diagram

```
                    ┌─────────────────┐
                    │   dim_customer  │
                    │   (Users)       │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │fact_orders   │   │fact_funnel_ │
            │              │   │events       │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │ dim_merchant │   │ dim_date    │
            │              │   │             │
            └──────────────┘   └─────────────┘
                    │                 │
            ┌───────▼──────────────────▼──────┐
            │     dim_city                    │
            │   (Order location)              │
            └─────────────────────────────────┘
```

---

## Dimension Tables

### dim_customer
| Column | Type | Description |
|--------|------|-------------|
| **customer_id** (PK) | Integer | Unique customer identifier |
| signup_date | Date | When customer registered |
| country | String | Customer's country |
| city | String | Primary city |
| segment | String | Premium/Standard/Budget |
| total_orders | Integer | Lifetime orders |

### dim_merchant
| Column | Type | Description |
|--------|------|-------------|
| **merchant_id** (PK) | Integer | Unique merchant identifier |
| merchant_name | String | Restaurant/Store name |
| cuisine_type | String | Cuisine category |
| city_id | Integer | Merchant's city |
| rating | Decimal | Merchant rating (1-5) |
| verified | Boolean | Verified status |

### dim_city
| Column | Type | Description |
|--------|------|-------------|
| **city_id** (PK) | Integer | Unique city identifier |
| city_name | String | City name |
| region | String | Region/State |
| country | String | Country |
| zone | String | Delivery zone |

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

### dim_funnel_stage
| Column | Type | Description |
|--------|------|-------------|
| **stage_id** (PK) | Integer | Stage identifier |
| stage_name | String | Browse/Add/Checkout/Order |
| stage_order | Integer | Step sequence (1,2,3,4) |

---

## Fact Tables

### fact_orders ⭐
**Grain:** One row per completed order

| Column | Type | Description |
|--------|------|-------------|
| **order_id** (PK) | Integer | Unique order identifier |
| **customer_id** (FK) | Integer | Links to dim_customer |
| **merchant_id** (FK) | Integer | Links to dim_merchant |
| **city_id** (FK) | Integer | Links to dim_city |
| **date_id** (FK) | Integer | Links to dim_date |
| order_timestamp | Timestamp | When order placed |
| order_amount | Decimal | Total order value |
| delivery_time_minutes | Integer | Delivery duration |
| rating | Integer | Customer rating (1-5) |
| status | String | Completed/Cancelled |

### fact_funnel_events ⭐
**Grain:** One row per user per funnel stage per session

| Column | Type | Description |
|--------|------|-------------|
| **event_id** (PK) | Integer | Unique event identifier |
| **customer_id** (FK) | Integer | Links to dim_customer |
| **stage_id** (FK) | Integer | Links to dim_funnel_stage |
| **city_id** (FK) | Integer | Links to dim_city |
| **date_id** (FK) | Integer | Links to dim_date |
| session_id | String | User session identifier |
| event_timestamp | Timestamp | When event occurred |
| converted_to_order | Boolean | Did session lead to order? |

---

## Key Relationships

```
dim_customer (1) ──< (N) fact_orders
dim_customer (1) ──< (N) fact_funnel_events

dim_merchant (1) ──< (N) fact_orders
dim_city (1) ──< (N) fact_orders
dim_city (1) ──< (N) fact_funnel_events
dim_date (1) ──< (N) fact_orders
dim_date (1) ──< (N) fact_funnel_events

dim_funnel_stage (1) ──< (N) fact_funnel_events
```

---

## Core Analytics Queries

### 1. Top 10 Customers by Repeat Orders
```sql
SELECT TOP 10
    dc.customer_id,
    COUNT(fo.order_id) AS total_orders,
    SUM(fo.order_amount) AS total_spent,
    ROUND(AVG(fo.rating), 2) AS avg_rating
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
GROUP BY dc.customer_id
HAVING COUNT(fo.order_id) > 1
ORDER BY total_orders DESC;
```

### 2. Track Conversion by Funnel Stage
```sql
SELECT 
    dfs.stage_name,
    COUNT(DISTINCT ffe.event_id) AS stage_events,
    COUNT(DISTINCT ffe.session_id) AS unique_sessions,
    COUNT(DISTINCT CASE WHEN ffe.converted_to_order = 1 THEN ffe.session_id END) AS converted_sessions,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ffe.converted_to_order = 1 THEN ffe.session_id END) /
          COUNT(DISTINCT ffe.session_id), 2) AS conversion_rate_pct
FROM fact_funnel_events ffe
JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
GROUP BY dfs.stage_name, dfs.stage_order
ORDER BY dfs.stage_order;
```

### 3. Daily Revenue by City
```sql
SELECT 
    dd.calendar_date,
    dc.city_name,
    COUNT(fo.order_id) AS orders,
    SUM(fo.order_amount) AS daily_revenue,
    AVG(fo.order_amount) AS avg_order_value
FROM fact_orders fo
JOIN dim_date dd ON fo.date_id = dd.date_id
JOIN dim_city dc ON fo.city_id = dc.city_id
GROUP BY dd.calendar_date, dc.city_name
ORDER BY dd.calendar_date DESC, daily_revenue DESC;
```

### 4. Top Merchants by Orders and Revenue
```sql
SELECT TOP 20
    dm.merchant_id,
    dm.merchant_name,
    dm.cuisine_type,
    COUNT(fo.order_id) AS total_orders,
    SUM(fo.order_amount) AS total_revenue,
    AVG(fo.order_amount) AS avg_order_value,
    ROUND(AVG(fo.rating), 2) AS avg_rating
FROM fact_orders fo
JOIN dim_merchant dm ON fo.merchant_id = dm.merchant_id
WHERE fo.status = 'Completed'
GROUP BY dm.merchant_id, dm.merchant_name, dm.cuisine_type
ORDER BY total_revenue DESC;
```

### 5. Funnel Drop-Off Analysis
```sql
WITH stage_conversions AS (
    SELECT 
        dfs.stage_name,
        dfs.stage_order,
        COUNT(DISTINCT ffe.session_id) AS sessions_at_stage
    FROM fact_funnel_events ffe
    JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
    GROUP BY dfs.stage_name, dfs.stage_order
)
SELECT 
    stage_name,
    sessions_at_stage,
    LAG(sessions_at_stage) OVER (ORDER BY stage_order) AS previous_stage_sessions,
    ROUND(100.0 * sessions_at_stage / LAG(sessions_at_stage) OVER (ORDER BY stage_order), 2) AS drop_off_rate_pct
FROM stage_conversions
ORDER BY stage_order;
```

### 6. Customer Repeat Rate by Signup Cohort
```sql
WITH signup_cohorts AS (
    SELECT 
        customer_id,
        YEAR(signup_date) AS signup_year,
        MONTH(signup_date) AS signup_month
    FROM dim_customer
),
order_activity AS (
    SELECT 
        sc.customer_id,
        sc.signup_year,
        sc.signup_month,
        COUNT(fo.order_id) AS total_orders
    FROM signup_cohorts sc
    LEFT JOIN fact_orders fo ON sc.customer_id = fo.customer_id
    GROUP BY sc.customer_id, sc.signup_year, sc.signup_month
)
SELECT 
    signup_year,
    signup_month,
    COUNT(DISTINCT customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN total_orders >= 2 THEN customer_id END) AS repeat_customers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN total_orders >= 2 THEN customer_id END) /
          COUNT(DISTINCT customer_id), 2) AS repeat_rate_pct
FROM order_activity
GROUP BY signup_year, signup_month
ORDER BY signup_year DESC, signup_month DESC;
```

WITH item_counts AS (
SELECT
dc.city_name,
di.item_name,
COUNT(*) AS order_count
FROM fact_order_items oi
JOIN fact_orders o
ON oi.order_id = o.order_id
JOIN dim_city dc
ON o.city_id = dc.city_id
JOIN dim_item di
ON oi.item_id = di.item_id
GROUP BY dc.city_name, di.item_name
)
SELECT
city_name,
item_name,
order_count
FROM (
SELECT
city_name,
item_name,
order_count,
ROW_NUMBER() OVER (
PARTITION BY city_name
ORDER BY order_count DESC
) AS rn
FROM item_counts
) t
WHERE rn = 1;


### 7. Average Delivery Time by Merchant
```sql
SELECT TOP 15
    dm.merchant_id,
    dm.merchant_name,
    COUNT(fo.order_id) AS orders,
    ROUND(AVG(fo.delivery_time_minutes), 2) AS avg_delivery_time,
    MIN(fo.delivery_time_minutes) AS min_delivery_time,
    MAX(fo.delivery_time_minutes) AS max_delivery_time
FROM fact_orders fo
JOIN dim_merchant dm ON fo.merchant_id = dm.merchant_id
WHERE fo.status = 'Completed'
GROUP BY dm.merchant_id, dm.merchant_name
ORDER BY avg_delivery_time ASC;
```

### 8. Orders and Revenue Growth Over Time
```sql
SELECT 
    dd.year,
    dd.month,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.order_amount) AS revenue,
    COUNT(DISTINCT fo.customer_id) AS unique_customers,
    ROUND(SUM(fo.order_amount) / COUNT(DISTINCT fo.customer_id), 2) AS revenue_per_customer
FROM fact_orders fo
JOIN dim_date dd ON fo.date_id = dd.date_id
WHERE fo.status = 'Completed'
GROUP BY dd.year, dd.month
ORDER BY dd.year DESC, dd.month DESC;
```

### 9. Funnel Conversion by City
```sql
SELECT 
    dc.city_name,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN dfs.stage_name = 'Order' AND ffe.converted_to_order = 1 
                                       THEN ffe.session_id END) /
          COUNT(DISTINCT CASE WHEN dfs.stage_name = 'Browse' THEN ffe.session_id END), 2) AS overall_conversion_pct,
    COUNT(DISTINCT ffe.session_id) AS total_sessions
FROM fact_funnel_events ffe
JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
JOIN dim_city dc ON ffe.city_id = dc.city_id
GROUP BY dc.city_name
ORDER BY overall_conversion_pct DESC;
```

### 10. Customer Satisfaction (Rating) by Merchant
```sql
SELECT TOP 20
    dm.merchant_name,
    dm.cuisine_type,
    COUNT(fo.order_id) AS orders,
    ROUND(AVG(fo.rating), 2) AS avg_rating,
    COUNT(DISTINCT CASE WHEN fo.rating >= 4 THEN fo.order_id END) AS highly_rated,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN fo.rating >= 4 THEN fo.order_id END) /
          COUNT(fo.order_id), 2) AS satisfaction_rate_pct
FROM fact_orders fo
JOIN dim_merchant dm ON fo.merchant_id = dm.merchant_id
GROUP BY dm.merchant_id, dm.merchant_name, dm.cuisine_type
HAVING COUNT(fo.order_id) >= 10
ORDER BY avg_rating DESC;
```

---

## Design Principles

✅ **Simplified:** Only 2 fact tables (orders, funnel)  
✅ **Event-Based:** Each fact represents a business event  
✅ **Clear Grain:** Orders = one row per order; Funnel = one row per event  
✅ **Star Schema:** All facts connect to dimensions  
✅ **Query-First:** Designed to answer real business questions  

---

## Interview Tips

1. **Grain Definition:** "fact_orders = one row per completed order; fact_funnel_events = one row per user per stage per session"
2. **Why 2 Facts?** "Orders are transactions; funnel events are separate behavioral events - different grains"
3. **Star Schema:** "All queries start from facts and join to dimensions - no dimension-dimension joins"
4. **City Choice:** "City represents order delivery location, not customer home - important distinction"

---

## Follow-Up Questions & Answers

### Q1: "How do we track cart abandonment?"
**A:** Create separate fact table for abandoned carts:
```sql
CREATE TABLE fact_cart_abandonments (
    abandonment_id INT PRIMARY KEY,
    customer_id INT FK,
    session_id VARCHAR,
    date_id INT FK,
    cart_value DECIMAL,
    item_count INT,
    abandoned_at TIMESTAMP
);

-- Joins same dimensions: dim_customer, dim_date, dim_city
```

### Q2: "What if a user adds same item multiple times in cart?"
**A:** That's captured at funnel_stage level - each add-to-cart is separate event:
```sql
SELECT 
    customer_id,
    session_id,
    COUNT(*) AS add_to_cart_events,
    COUNT(CASE WHEN converted_to_order = 1 THEN 1 END) AS converted_sessions
FROM fact_funnel_events
WHERE stage_id = (SELECT stage_id FROM dim_funnel_stage WHERE stage_name = 'Add to Cart')
GROUP BY customer_id, session_id;
```

### Q3: "How do we handle promo code impact on conversion?"
**A:** Add to funnel events:
```sql
ALTER TABLE fact_funnel_events 
ADD promo_code_id INT,
ADD discount_applied DECIMAL;

SELECT 
    CASE WHEN promo_code_id IS NOT NULL THEN 'With Promo' ELSE 'No Promo' END,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN converted_to_order = 1 THEN session_id END) AS converted,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN converted_to_order = 1 THEN session_id END) /
          COUNT(DISTINCT session_id), 2) AS conversion_rate_pct
FROM fact_funnel_events
WHERE stage_id IN (SELECT stage_id FROM dim_funnel_stage 
                   WHERE stage_name IN ('Checkout', 'Order'))
GROUP BY CASE WHEN promo_code_id IS NOT NULL THEN 'With Promo' ELSE 'No Promo' END;
```

### Q4: "What about failed payment attempts?"
**A:** Create separate fact table:
```sql
CREATE TABLE fact_payment_failures (
    failure_id INT PRIMARY KEY,
    customer_id INT FK,
    session_id VARCHAR,
    date_id INT FK,
    failure_reason VARCHAR, -- 'insufficient_funds', 'card_declined', 'timeout'
    retry_count INT
);
```

### Q5: "How do we measure funnel drop-off correctly?"
**A:** Use window functions to compare stage transitions:
```sql
WITH stage_users AS (
    SELECT 
        dfs.stage_order,
        dfs.stage_name,
        COUNT(DISTINCT ffe.session_id) AS users_at_stage
    FROM fact_funnel_events ffe
    JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
    GROUP BY dfs.stage_order, dfs.stage_name
)
SELECT 
    stage_name,
    users_at_stage,
    LAG(users_at_stage) OVER (ORDER BY stage_order) AS prev_stage_users,
    ROUND(100.0 * users_at_stage / 
          LAG(users_at_stage) OVER (ORDER BY stage_order), 2) AS retention_pct
FROM stage_users
ORDER BY stage_order;
```

### Q6: "Should we track device type impact on conversion?"
**A:** YES - add to funnel events:
```sql
ALTER TABLE fact_funnel_events ADD device_type VARCHAR;

SELECT 
    device_type,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN converted_to_order = 1 THEN session_id END) AS converted,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN converted_to_order = 1 THEN session_id END) /
          COUNT(DISTINCT session_id), 2) AS conversion_rate
FROM fact_funnel_events
GROUP BY device_type
ORDER BY conversion_rate DESC;
```

### Q7: "What about repeat users vs new users in funnel?"
**A:** Join to customer history:
```sql
WITH customer_type AS (
    SELECT 
        customer_id,
        CASE WHEN MIN(signup_date) <= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
             THEN 'Existing' ELSE 'New' END AS customer_category
    FROM dim_customer
    GROUP BY customer_id
)
SELECT 
    ct.customer_category,
    COUNT(DISTINCT ffe.session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN ffe.converted_to_order = 1 THEN ffe.session_id END) AS converted
FROM fact_funnel_events ffe
JOIN customer_type ct ON ffe.customer_id = ct.customer_id
GROUP BY ct.customer_category;
```

### Q8: "How do we handle geo-specific funnel analysis?"
**A:** Use dim_city in queries:
```sql
SELECT 
    dc.city_name,
    dfs.stage_name,
    COUNT(DISTINCT ffe.session_id) AS sessions,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ffe.converted_to_order = 1 THEN ffe.session_id END) /
          COUNT(DISTINCT ffe.session_id), 2) AS conversion_rate_pct
FROM fact_funnel_events ffe
JOIN dim_city dc ON ffe.city_id = dc.city_id
JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
GROUP BY dc.city_name, dfs.stage_name
ORDER BY dc.city_name, dfs.stage_order;
```

### Q9: "What about mobile app vs web funnel differences?"
**A:** Add channel tracking:
```sql
ALTER TABLE fact_funnel_events ADD channel VARCHAR; -- 'mobile_app', 'web', 'webapp'

SELECT 
    channel,
    dfs.stage_name,
    COUNT(DISTINCT ffe.session_id) AS users
FROM fact_funnel_events ffe
JOIN dim_funnel_stage dfs ON ffe.stage_id = dfs.stage_id
GROUP BY channel, dfs.stage_name
ORDER BY channel, dfs.stage_order;
```

### Q10: "Should order and funnel events have matching timestamps?"
**A:** Funnel events lead to order_created_at:
```sql
-- Validate funnel to order flow
SELECT 
    COUNT(*) AS funnel_to_order_matches
FROM fact_orders fo
WHERE EXISTS (
    SELECT 1 FROM fact_funnel_events ffe
    WHERE ffe.customer_id = fo.customer_id
      AND ffe.session_id = fo.session_id
      AND ffe.event_timestamp <= fo.created_at
      AND ffe.converted_to_order = 1
);
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Mixing funnel events into order facts  
✅ **RIGHT:** Separate facts with different grains

❌ **WRONG:** Only tracking successful conversions  
✅ **RIGHT:** Track all stages including drop-offs

❌ **WRONG:** Not capturing repeat visits same session  
✅ **RIGHT:** Each funnel event is separate row

❌ **WRONG:** Ignoring failed payments in funnel  
✅ **RIGHT:** Create separate fact for payment issues

---

## One-Liner Reminders

📌 "Funnel grain: one row per user per stage per session."

📌 "Orders grain: one row per completed order."

📌 "Drop-off = users at stage N vs stage N+1."

📌 "Always track conversion_to_order flag."
