# Food Delivery App - DoorDash Data Model

## Overview
**Type:** OLAP (Analytics)  
**Focus:** Food Delivery Platform  
**Granularity:** Daily & Order-level  
**Purpose:** Track orders, items, funnel conversion, and customer behavior

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
            │fact_orders   │   │fact_order_  │
            │              │   │items        │
            └───────┬──────┘   └──────┬──────┘
                    │                 │
            ┌───────▼──────┐   ┌──────▼──────┐
            │ dim_merchant │   │dim_item     │
            │              │   │             │
            └──────────────┘   └─────────────┘
                    │                 │
            ┌───────▼──────────────────▼──────┐
            │     dim_city                    │
            │   (Order location)              │
            ├─────────────────────────────────┤
            │     dim_date  dim_cuisine       │
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
| segment | String | Premium/Standard/Budget |
| total_orders | Integer | Lifetime orders |

### dim_merchant
| Column | Type | Description |
|--------|------|-------------|
| **merchant_id** (PK) | Integer | Unique merchant/restaurant identifier |
| merchant_name | String | Restaurant name |
| city_id | Integer | Primary city |
| rating | Decimal | Merchant rating (1-5) |
| verified | Boolean | Verified status |

### dim_item
| Column | Type | Description |
|--------|------|-------------|
| **item_id** (PK) | Integer | Unique item identifier |
| **merchant_id** (FK) | Integer | Links to dim_merchant |
| **cuisine_id** (FK) | Integer | Links to dim_cuisine |
| item_name | String | Item name |
| item_price | Decimal | Item price |

### dim_cuisine
| Column | Type | Description |
|--------|------|-------------|
| **cuisine_id** (PK) | Integer | Unique cuisine identifier |
| cuisine_name | String | Cuisine type (Indian, Chinese, etc.) |

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
| order_amount | Decimal | Total order value |
| order_status | String | Completed/Cancelled |
| created_at | Timestamp | When order placed |

### fact_order_items ⭐
**Grain:** One row per item per order

| Column | Type | Description |
|--------|------|-------------|
| **order_id** (FK) | Integer | Links to fact_orders |
| **item_id** (FK) | Integer | Links to dim_item |
| **cuisine_id** (FK) | Integer | Links to dim_cuisine |
| quantity | Integer | Quantity ordered |
| item_price | Decimal | Price per item |

---

## Key Relationships

```
dim_customer (1) ──< (N) fact_orders

dim_merchant (1) ──< (N) fact_orders
dim_merchant (1) ──< (N) dim_item

dim_item (1) ──< (N) fact_order_items
dim_cuisine (1) ──< (N) dim_item
dim_cuisine (1) ──< (N) fact_order_items

dim_city (1) ──< (N) fact_orders
dim_date (1) ──< (N) fact_orders

fact_orders (1) ──< (N) fact_order_items
```

---

## Core Analytics Queries

### 1. Top Customers by Repeat Orders
```sql
SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(order_amount) AS total_spent,
    ROUND(AVG(order_amount), 2) AS avg_order_value
FROM fact_orders
WHERE order_status = 'Completed'
GROUP BY customer_id
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY order_count DESC;
```

### 2. Top Customers by Repeat Orders (Last 30 Days, by City)
```sql
SELECT
    dc.city_name,
    fo.customer_id,
    COUNT(DISTINCT fo.order_id) AS order_count,
    SUM(fo.order_amount) AS total_spent
FROM fact_orders fo
JOIN dim_city dc ON fo.city_id = dc.city_id
JOIN dim_date dd ON fo.date_id = dd.date_id
WHERE dd.calendar_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND fo.order_status = 'Completed'
GROUP BY dc.city_name, fo.customer_id
HAVING COUNT(DISTINCT fo.order_id) > 1
ORDER BY dc.city_name, order_count DESC;
```

### 3. Most Popular Item in Each City (Top-N per Group)
```sql
WITH item_counts AS (
    SELECT
        dc.city_name,
        di.item_name,
        COUNT(DISTINCT foi.order_id) AS order_count,
        ROW_NUMBER() OVER (
            PARTITION BY dc.city_name
            ORDER BY COUNT(DISTINCT foi.order_id) DESC
        ) AS rn
    FROM fact_order_items foi
    JOIN fact_orders fo ON foi.order_id = fo.order_id
    JOIN dim_city dc ON fo.city_id = dc.city_id
    JOIN dim_item di ON foi.item_id = di.item_id
    WHERE fo.order_status = 'Completed'
    GROUP BY dc.city_name, di.item_name
)
SELECT
    city_name,
    item_name,
    order_count
FROM item_counts
WHERE rn = 1;
```

### 4. Average Order Value (AOV) Across Cuisines
```sql
SELECT
    dc.cuisine_name,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.order_amount) AS total_revenue,
    ROUND(AVG(fo.order_amount), 2) AS avg_order_value
FROM fact_orders fo
JOIN fact_order_items foi ON fo.order_id = foi.order_id
JOIN dim_cuisine dc ON foi.cuisine_id = dc.cuisine_id
WHERE fo.order_status = 'Completed'
GROUP BY dc.cuisine_name
ORDER BY avg_order_value DESC;
```

### 5. Track Conversion by Funnel Stage
```sql
SELECT
    'Browse' AS stage,
    COUNT(DISTINCT customer_id) AS unique_users
FROM fact_orders
UNION ALL
SELECT
    'Add to Cart' AS stage,
    COUNT(DISTINCT order_id) AS unique_orders
FROM fact_order_items
UNION ALL
SELECT
    'Checkout' AS stage,
    COUNT(DISTINCT order_id) AS orders
FROM fact_orders
UNION ALL
SELECT
    'Order Complete' AS stage,
    COUNT(DISTINCT order_id) AS completed_orders
FROM fact_orders
WHERE order_status = 'Completed';
```

### 6. Daily Revenue by City
```sql
SELECT
    dd.calendar_date,
    dc.city_name,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.order_amount) AS daily_revenue,
    ROUND(AVG(fo.order_amount), 2) AS avg_order_value
FROM fact_orders fo
JOIN dim_date dd ON fo.date_id = dd.date_id
JOIN dim_city dc ON fo.city_id = dc.city_id
WHERE fo.order_status = 'Completed'
GROUP BY dd.calendar_date, dc.city_name
ORDER BY dd.calendar_date DESC, daily_revenue DESC;
```

### 7. Orders & Revenue Growth Over Time
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
WHERE fo.order_status = 'Completed'
GROUP BY dd.year, dd.month
ORDER BY dd.year DESC, dd.month DESC;
```

### 8. Top Merchants by Orders and Revenue
```sql
SELECT TOP 20
    dm.merchant_id,
    dm.merchant_name,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    SUM(fo.order_amount) AS total_revenue,
    ROUND(AVG(fo.order_amount), 2) AS avg_order_value,
    ROUND(dm.rating, 2) AS rating
FROM fact_orders fo
JOIN dim_merchant dm ON fo.merchant_id = dm.merchant_id
WHERE fo.order_status = 'Completed'
GROUP BY dm.merchant_id, dm.merchant_name, dm.rating
ORDER BY total_revenue DESC;
```

### 9. Most Popular Items Overall
```sql
SELECT TOP 20
    di.item_name,
    dm.merchant_name,
    dc.cuisine_name,
    COUNT(DISTINCT foi.order_id) AS orders,
    ROUND(AVG(foi.item_price), 2) AS avg_price
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_item di ON foi.item_id = di.item_id
JOIN dim_merchant dm ON di.merchant_id = dm.merchant_id
JOIN dim_cuisine dc ON foi.cuisine_id = dc.cuisine_id
WHERE fo.order_status = 'Completed'
GROUP BY di.item_name, dm.merchant_name, dc.cuisine_name
ORDER BY orders DESC;
```

### 10. Daily Active Users (DAU) by City
```sql
SELECT
    dd.calendar_date,
    dc.city_name,
    COUNT(DISTINCT fo.customer_id) AS dau,
    COUNT(DISTINCT fo.order_id) AS orders
FROM fact_orders fo
JOIN dim_date dd ON fo.date_id = dd.date_id
JOIN dim_city dc ON fo.city_id = dc.city_id
WHERE fo.order_status = 'Completed'
GROUP BY dd.calendar_date, dc.city_name
ORDER BY dd.calendar_date DESC;
```

---

## Design Principles

✅ **Simplified:** 2 fact tables (orders, order_items)  
✅ **Event-Based:** Each fact represents a business event  
✅ **Clear Grain:** Orders = one per order; Items = one per item per order  
✅ **Star Schema:** All facts connect to dimensions, no dimension-dimension joins  
✅ **Query-First:** Designed to answer real business questions  

---

## Interview Tips

1. **Grain Definition:** "fact_orders = one row per order; fact_order_items = one row per item per order"
2. **Why 2 Facts?** "Orders capture transaction level; items capture product composition - different grains"
3. **Star Schema:** "All queries start from facts and join outward to dimensions - radial pattern"
4. **City Choice:** "City represents order delivery location, not customer home - important distinction"
5. **Extension:** "To add funnel events, create fact_funnel_events reusing dim_customer, dim_city, dim_date"

---

## Follow-Up Questions & Answers

### Q1: "What if an item has multiple variants (e.g., spice level)?"
**A:** Store variants in dim_item or create separate table:
```sql
CREATE TABLE dim_item_variant (
    variant_id INT PRIMARY KEY,
    item_id INT FK,
    variant_type VARCHAR, -- 'spice_level', 'portion_size'
    variant_value VARCHAR, -- 'mild', 'medium', 'hot'
    price_adjustment DECIMAL
);

ALTER TABLE fact_order_items ADD variant_id INT FK;
```

### Q2: "How do we track items that go out of stock?"
**A:** Add status to dim_item:
```sql
ALTER TABLE dim_item 
ADD availability_status VARCHAR, -- 'available', 'temporarily_unavailable', 'discontinued'
ADD last_available_date DATE;

SELECT 
    di.item_name,
    COUNT(foi.order_id) AS orders_since_discontinued
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
WHERE di.availability_status = 'discontinued'
  AND foi.order_id > (SELECT MAX(order_date) FROM fact_orders 
                       WHERE EXTRACT(MONTH FROM order_date) = MONTH(di.last_available_date));
```

### Q3: "Should we track combo items separately?"
**A:** YES - items can be combos or single items:
```sql
ALTER TABLE dim_item 
ADD item_type VARCHAR, -- 'single_item', 'combo', 'bundle'
ADD combo_items_list VARCHAR; -- comma-separated item_ids

SELECT 
    COUNT(DISTINCT foi.order_id) AS orders_with_combos
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
WHERE di.item_type = 'combo';
```

### Q4: "How do we measure customer preference for items?"
**A:** Track item affinity:
```sql
WITH customer_preferences AS (
    SELECT 
        foi.user_id,
        di.item_name,
        COUNT(foi.order_id) AS times_ordered,
        ROW_NUMBER() OVER (PARTITION BY foi.user_id ORDER BY COUNT(foi.order_id) DESC) AS preference_rank
    FROM fact_order_items foi
    JOIN dim_item di ON foi.item_id = di.item_id
    GROUP BY foi.user_id, di.item_name
)
SELECT * FROM customer_preferences WHERE preference_rank <= 5;
```

### Q5: "What about cross-sell and upsell opportunities?"
**A:** Analyze item combinations:
```sql
WITH item_pairs AS (
    SELECT 
        foi1.item_id AS item_1,
        foi2.item_id AS item_2,
        COUNT(DISTINCT foi1.order_id) AS orders_with_both
    FROM fact_order_items foi1
    JOIN fact_order_items foi2 ON foi1.order_id = foi2.order_id 
                                AND foi1.item_id < foi2.item_id
    GROUP BY foi1.item_id, foi2.item_id
    HAVING COUNT(DISTINCT foi1.order_id) > 100
)
SELECT 
    di1.item_name,
    di2.item_name,
    orders_with_both
FROM item_pairs ip
JOIN dim_item di1 ON ip.item_1 = di1.item_id
JOIN dim_item di2 ON ip.item_2 = di2.item_id
ORDER BY orders_with_both DESC;
```

### Q6: "How do we handle price changes during the day?"
**A:** Snapshot price at order time (already in fact_order_items.item_price):
```sql
-- Historical comparison
SELECT 
    di.item_name,
    EXTRACT(HOUR FROM dd.calendar_date) AS hour_of_day,
    AVG(foi.item_price) AS avg_price_this_hour
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
JOIN dim_date dd ON foi.order_id IN (
    SELECT order_id FROM fact_orders 
    WHERE date_id = dd.date_id
)
GROUP BY di.item_name, EXTRACT(HOUR FROM dd.calendar_date)
ORDER BY di.item_name, hour_of_day;
```

### Q7: "Should cuisine hierarchy affect analysis?"
**A:** YES - use dim_cuisine for segmentation:
```sql
SELECT 
    dc.cuisine_name,
    COUNT(DISTINCT foi.order_id) AS orders,
    SUM(foi.item_price * foi.quantity) AS revenue,
    ROUND(AVG(foi.item_price), 2) AS avg_item_price
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
JOIN dim_cuisine dc ON foi.cuisine_id = dc.cuisine_id
GROUP BY dc.cuisine_name
ORDER BY revenue DESC;
```

### Q8: "How do we track item performance by merchant?"
**A:** Multi-dimensional analysis:
```sql
SELECT TOP 20
    dm.merchant_name,
    di.item_name,
    COUNT(foi.order_id) AS orders,
    SUM(foi.item_price * foi.quantity) AS revenue,
    AVG(foi.quantity) AS avg_quantity
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
JOIN dim_merchant dm ON di.merchant_id = dm.merchant_id
GROUP BY dm.merchant_id, dm.merchant_name, di.item_id, di.item_name
ORDER BY revenue DESC;
```

### Q9: "What about recommending items to customers?"
**A:** Use collaborative filtering on order patterns:
```sql
-- Find users with similar item preferences
SELECT 
    u1.user_id,
    u2.user_id AS similar_user,
    COUNT(DISTINCT CASE WHEN foi1.item_id = foi2.item_id THEN foi1.item_id END) AS shared_items
FROM fact_order_items foi1
JOIN dim_user u1 ON foi1.user_id = u1.user_id
JOIN dim_user u2 ON u1.city = u2.city
JOIN fact_order_items foi2 ON u2.user_id = foi2.user_id 
                            AND foi1.item_id = foi2.item_id
WHERE u1.user_id != u2.user_id
GROUP BY u1.user_id, u2.user_id
HAVING COUNT(DISTINCT foi1.item_id) > 3;
```

### Q10: "Should we pre-aggregate cuisine-level metrics?"
**A:** Keep raw items, pre-aggregate if performance needs it:
```sql
-- Create materialized view for daily cuisine summary
CREATE MATERIALIZED VIEW fact_daily_cuisine_summary AS
SELECT 
    dc.cuisine_id,
    dd.date_id,
    COUNT(DISTINCT foi.order_id) AS orders,
    SUM(foi.item_price * foi.quantity) AS revenue,
    COUNT(DISTINCT foi.user_id) AS unique_users
FROM fact_order_items foi
JOIN dim_item di ON foi.item_id = di.item_id
JOIN dim_cuisine dc ON foi.cuisine_id = dc.cuisine_id
JOIN dim_date dd ON foi.order_id IN (
    SELECT order_id FROM fact_orders WHERE date_id = dd.date_id
)
GROUP BY dc.cuisine_id, dd.date_id;
```

---

## Common Interview Mistakes to Avoid

❌ **WRONG:** Storing item name in fact_order_items  
✅ **RIGHT:** Use item_id FK, join to dim_item when needed

❌ **WRONG:** Mixing order-level and item-level metrics  
✅ **RIGHT:** Keep separate grains, join when needed

❌ **WRONG:** Not capturing quantity per item  
✅ **RIGHT:** Include quantity in fact_order_items

❌ **WRONG:** Ignoring price changes over time  
✅ **RIGHT:** Snapshot price at order time

---

## One-Liner Reminders

📌 "Grain: one row per item per order (order can have many items)."

📌 "Item price captured at order time for historical analysis."

📌 "Cuisine is context for grouping, not a fact measure."

📌 "Quantity enables AOV and item-level profitability analysis."

