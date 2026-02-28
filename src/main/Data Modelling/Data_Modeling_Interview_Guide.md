# 📚 Data Modeling Interview Guide - Complete Preparation

## Table of Contents
1. [Clarifying Questions](#clarifying-questions)
2. [Grain Definition](#grain-definition)
3. [Facts vs Dimensions](#facts-vs-dimensions)
4. [Avoiding Common Mistakes](#avoiding-common-mistakes)
5. [Date Handling](#date-handling)
6. [Query-First Thinking](#query-first-thinking)
7. [Standard Query Patterns](#standard-query-patterns)
8. [Model Extension](#model-extension)
9. [Interview Traps](#interview-traps)
10. [Interview Scripts](#interview-scripts)
11. [Follow-Up Questions](#follow-up-questions)
12. [Red Flags to Avoid](#red-flags-to-avoid)

---

## 🎯 Clarifying Questions

### Step 1: ALWAYS START BY ASKING CLARIFYING QUESTIONS

This is **non-negotiable**. Jumping straight to tables is a red flag that signals junior thinking.

### Required Questions to Ask

#### Business Context
```
• Is this an OLAP (analytics) or OLTP (transactional) system?
• What are the core business metrics?
  (DAU, MAU, retention, engagement, revenue)
• What product questions should this model answer first?
• Who is the primary user of this data?
  (Data scientists, analysts, business stakeholders?)
```

#### Event Tracking
```
• What events are we tracking?
  (login, activity, order, delivery, etc.)
• How frequently are events generated?
• Do we need all events or sampled events?
```

#### Data Storage
```
• Are we storing raw events or aggregated data?
• What is the time granularity?
  (daily, weekly, monthly, hourly, real-time?)
• Is near real-time required or is batch sufficient?
```

#### Dimension Attributes
```
• Do dimension attributes change over time?
  (user address, product category, merchant name?)
• Do we need to track historical changes?
  (SCD Type 2 = version each change)
```

### Interview Signal
```
SAY EXPLICITLY:

"I want to clarify use cases before designing tables."

This alone signals seniority.
```

### Why This Matters
- Shows you understand the problem before jumping to solution
- Prevents rework when requirements weren't clear
- Demonstrates communication skills
- Asks the right questions instead of making assumptions

---

## ⭐ Grain Definition

### Step 2: PICK THE GRAIN FIRST (MOST IMPORTANT STEP)

This is the **most critical decision** in your model. Get this right, and everything else follows.

### Definition
```
GRAIN = What does ONE row represent?
```

### Why Grain Matters
```
Grain decides:
• GROUP BY behavior in queries
• Aggregation correctness
• Query simplicity
• Whether JOIN results are correct
```

### How to State Grain
**Rule:** If you can't state the grain in one sentence, the model is wrong.

### Examples by Platform

#### E-Commerce (Amazon)
```
WRONG: "One row per customer"
CORRECT: "One row per order item (customer, product, order)"
```

#### Ride-Sharing (Uber)
```
WRONG: "One row per driver"
CORRECT: "One row per completed trip (user, driver, pickup, dropoff, timestamp)"
```

#### Streaming (Netflix)
```
WRONG: "One row per user"
CORRECT: "One row per viewing session (user, content, start_time, end_time)"
```

#### Music (Spotify)
```
WRONG: "One row per listener"
CORRECT: "One row per track play (user, track, timestamp, was_skipped)"
```

#### Hospitality (Airbnb)
```
WRONG: "One row per guest"
CORRECT: "One row per booking (guest, listing, checkin_date, checkout_date)"
```

#### Fitness (Wearable)
```
WRONG: "One row per user activity"
CORRECT: "One row per activity event (user, activity_type, timestamp, steps, calories)"
```

### Grain Interview Follow-Ups

**Q: "What if I want to track multiple metrics per event?"**
```
A: "Keep one metric per fact table, or store all as columns if they come from same event.
   DON'T create separate rows for same event."
   
Example:
fact_streams table:
- stream_id (PK)
- user_id (FK)
- track_id (FK)
- duration_played_sec
- was_skipped
✅ All same event, all stay in one row
```

**Q: "What if metrics have different granularities?"**
```
A: "Create separate fact tables with different grains.
   
Example:
- fact_activity_events (grain: per event timestamp)
- fact_daily_activity_summary (grain: per user per day)"
```

---

## 📊 Facts vs Dimensions

### Step 3: FACTS VS DIMENSIONS (NON-NEGOTIABLE RULES)

### FACT TABLES
```
Purpose:    Capture business events
Contents:   Measures (metrics, numbers)
           Foreign keys to dimensions
Keys:      Primary key (usually auto-increment)
           Foreign keys (links to dimensions)
Cardinality: HIGH - millions/billions of rows
Frequency: Updated frequently
Examples:  fact_orders, fact_clicks, fact_streams

What to include:
✅ Foreign keys to dimensions
✅ Measures (sum-able numbers)
✅ Event timestamps
✅ Flags (was_skipped, is_completed)

What NOT to include:
❌ Descriptive text (belongs in dimension)
❌ Non-repeating attributes (belongs in dimension)
❌ Hierarchies (belongs in dimension)
```

### DIMENSION TABLES
```
Purpose:    Provide context for facts
Contents:   Attributes (descriptive, categorical)
Keys:      Primary key (usually integer ID)
Cardinality: LOW - hundreds/thousands of rows
Frequency: Updated less frequently
Examples:  dim_user, dim_product, dim_date

What to include:
✅ Primary key
✅ Descriptive attributes
✅ Categorical values
✅ Hierarchies (category → subcategory)

What NOT to include:
❌ Measures or metrics
❌ Foreign keys to other dimensions
❌ High-cardinality data
```

### Golden Rule
```
Facts record events. Dimensions provide context.
```

### Visual Example

```
┌─────────────────────────────┐
│    dim_customer             │
├─────────────────────────────┤
│ PK: customer_id             │
│    name (attribute)         │
│    country (attribute)      │
│    account_tier (context)   │
└─────────────────────────────┘
           ▲
           │ (1:N)
           │
┌─────────────────────────────┐
│    fact_purchases           │
├─────────────────────────────┤
│ PK: purchase_id             │
│ FK: customer_id ──→ join    │
│ FK: product_id              │
│    quantity (measure)       │
│    price (measure)          │
└─────────────────────────────┘
```

### Interview Question: "Is this a fact or dimension?"

**Scenario 1: dim_date**
```
Q: "Is dim_date a fact or dimension?"
A: "Dimension. It provides context (when did event happen?)
   even though it has many rows. It's not an event."
```

**Scenario 2: fact_login_events**
```
Q: "Is fact_login_events a fact or dimension?"
A: "Fact. It captures an event (user logged in) with
   foreign keys to dimensions (user, device, date)."
```

**Scenario 3: dim_category**
```
Q: "Is dim_category a fact or dimension?"
A: "Dimension. It provides context for products.
   Millions of categories would be wrong - should be
   thousands at most."
```

---

## ❌ Avoiding Common Mistakes

### Step 4: AVOID DIMENSION → DIMENSION JOINS (AT ALL COSTS)

This is a **hard rule** in star schemas.

### The Problem

```
❌ WRONG PATTERN:

fact_purchase
    ↓
dim_customer
    ↓
dim_country
    ↓
dim_region

This breaks the star schema!
```

### Why It's Wrong
```
1. Violates star schema principle
2. Makes queries complex
3. Reduces query performance
4. Indicates missing foreign key in fact
```

### The Solution

```
✅ CORRECT PATTERN:

                dim_customer
                dim_date
                dim_product
                     │
fact_purchase ─┬─────┼─────┬─
               ↓     ↓     ↓
               fact table at center
               dimensions around it

fact → dim_customer
fact → dim_date  
fact → dim_product
```

### Rules to Remember
```
• Facts join to dimensions
• Dimensions NEVER join to other dimensions
• All foreign keys live in the fact table
• Each join is one hop from the fact

If you ever feel tempted to join dim → dim:
You're missing a foreign key in the fact.
```

### Example Fix

```
❌ WRONG:
SELECT p.product_name, c.category_name, r.region_name
FROM fact_purchases f
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_category c ON p.category_id = c.category_id  ← dim joins dim!
JOIN dim_region r ON c.region_id = r.region_id        ← dim joins dim!

✅ CORRECT:
Modify dim_product to include category_name:
dim_product (product_id, product_name, category_id, category_name, ...)

Or create flat dimension:
dim_product_category (product_id, product_name, category_name, region_name, ...)

SELECT p.product_name, p.category_name, p.region_name
FROM fact_purchases f
JOIN dim_product p ON f.product_id = p.product_id  ← all from one hop
```

---

## 📅 Date Handling

### Step 5: DATE HANDLING (COMMON INTERVIEW FOLLOW-UP)

Having many date_ids is **normal and expected**. Don't apologize for it.

### Why Multiple Date IDs?

```
Different events have different dates:
• When was the order placed? → order_date_id
• When was it delivered? → delivery_date_id
• When was it returned? → return_date_id

Each business date is meaningful.
```

### Examples

```
E-Commerce:
• browse_date_id
• cart_add_date_id
• purchase_date_id
• delivery_date_id
• return_date_id

Ride-Sharing:
• request_date_id
• pickup_date_id
• dropoff_date_id

Streaming:
• login_date_id
• view_start_date_id
• view_end_date_id
• cancellation_date_id
```

### Rules

```
• One date_id per meaningful business event
• Name them clearly
• Join facts to dim_date, not timestamps
• Use date_id, not datetime string
```

### Why This Approach Wins

```
1. Better performance
   - Integer key vs string comparison
   - Indexes work better on integers

2. Consistent calendar logic
   - All reports use same calendar
   - holidays, weekends, fiscal_year consistent

3. Cleaner SQL
   - No date parsing needed
   - Simple integer join
   - Easy date arithmetic
```

### SQL Example

```sql
❌ WRONG (using timestamps):
SELECT DATE(view_start_timestamp) AS view_date, COUNT(*)
FROM fact_views
WHERE YEAR(view_start_timestamp) = 2024

✅ CORRECT (using date_id):
SELECT dd.calendar_date, COUNT(*)
FROM fact_views fv
JOIN dim_date dd ON fv.view_start_date_id = dd.date_id
WHERE dd.year = 2024
GROUP BY dd.calendar_date
```

---

## 🧠 Query-First Thinking

### Step 6: QUERY-FIRST THINKING (THIS IS WHAT THEY TEST)

Design your model while thinking: **"How will an analyst write queries on this?"**

### The Test

If your model is good:
```
✅ SQL is SHORT
✅ GROUP BY is OBVIOUS
✅ No HACKS needed
✅ No complex CTEs
✅ No subqueries
```

### Golden Rule
```
If SQL feels messy → model is wrong.
If SQL is clean → model is right.
```

### Example: Bad Model

```
❌ BAD MODEL (messy SQL):
SELECT c.customer_name,
       SUM(f.amount)
FROM fact_purchases f
JOIN dim_customer c ON f.customer_id = c.customer_id
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_category c2 ON p.category_id = c2.category_id
JOIN dim_subcategory s ON c2.subcategory_id = s.subcategory_id
WHERE c2.name = 'Electronics'
  AND s.name = 'Phones'
  AND YEAR(f.purchase_date) = 2024
GROUP BY c.customer_id, c.customer_name
ORDER BY SUM(f.amount) DESC;

Problems:
• Too many joins
• dim-dim join (BAD)
• Complex WHERE with dims
• Hard to understand
```

```
✅ GOOD MODEL (clean SQL):
SELECT dc.customer_name,
       SUM(fp.total_price) AS total_spent
FROM fact_purchases fp
JOIN dim_customer dc ON fp.customer_id = dc.customer_id
WHERE fp.category_name = 'Electronics'
  AND fp.subcategory_name = 'Phones'
  AND fp.purchase_year = 2024
GROUP BY dc.customer_id, dc.customer_name
ORDER BY total_spent DESC;

Why better:
• Fewer joins (flat dimension)
• All attributes in one table
• WHERE is on facts/simple dimensions
• Easy to read and understand
```

### Key Principle: Denormalization

```
In OLAP (data warehouse), you WANT some denormalization:
• Flatten dimensions
• Include descriptive text in fact tables
• Pre-compute hierarchies

This is OPPOSITE of OLTP (operational databases)
where normalization is preferred.

Why?
• Query performance
• Analyst ease
• Fewer joins needed
```

---

## 🔧 Standard Query Patterns

### Step 7: STANDARD QUERY PATTERNS (MENTAL TEMPLATES)

Learn these patterns. They come up in almost every interview.

### Pattern 1: Average per User per Day

```sql
-- "Show me average steps per user per day"
SELECT 
    fa.user_id,
    dd.calendar_date,
    AVG(fa.steps) AS avg_steps
FROM fact_activity fa
JOIN dim_date dd ON fa.activity_date_id = dd.date_id
GROUP BY fa.user_id, dd.calendar_date
ORDER BY dd.calendar_date DESC;
```

### Pattern 2: DAU / MAU

```sql
-- "Show daily/monthly active users"
-- DAU
SELECT 
    dd.calendar_date,
    COUNT(DISTINCT fl.user_id) AS dau
FROM fact_login fl
JOIN dim_date dd ON fl.login_date_id = dd.date_id
GROUP BY dd.calendar_date;

-- MAU
SELECT 
    dd.year,
    dd.month,
    COUNT(DISTINCT fl.user_id) AS mau
FROM fact_login fl
JOIN dim_date dd ON fl.login_date_id = dd.date_id
GROUP BY dd.year, dd.month;
```

### Pattern 3: Retention Cohort

```sql
-- "What % of users who signed up in Jan 2024 are still active in Feb?"
WITH signup_cohort AS (
    SELECT 
        user_id,
        DATE_TRUNC('month', signup_date) AS signup_month
    FROM dim_user
    WHERE signup_date >= '2024-01-01'
),
activity AS (
    SELECT 
        sc.user_id,
        sc.signup_month,
        DATE_TRUNC('month', fl.login_date) AS active_month
    FROM signup_cohort sc
    LEFT JOIN fact_login fl ON sc.user_id = fl.user_id
)
SELECT 
    signup_month,
    COUNT(DISTINCT user_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN active_month = DATE_TRUNC('month', signup_month) + '1 month'::interval
                       THEN user_id END) AS month_1_retained
FROM activity
GROUP BY signup_month;
```

### Pattern 4: Top N Users

```sql
-- "Show top 10 users by purchase amount"
SELECT TOP 10
    du.user_id,
    du.user_name,
    SUM(fp.total_price) AS total_spent
FROM fact_purchases fp
JOIN dim_user du ON fp.user_id = du.user_id
GROUP BY fp.user_id, du.user_id, du.user_name
ORDER BY total_spent DESC;
```

### Pattern 5: Rolling Metrics

```sql
-- "Show 7-day rolling average of daily active users"
WITH daily_users AS (
    SELECT 
        dd.calendar_date,
        COUNT(DISTINCT fl.user_id) AS dau
    FROM fact_login fl
    JOIN dim_date dd ON fl.login_date_id = dd.date_id
    GROUP BY dd.calendar_date
)
SELECT 
    calendar_date,
    AVG(dau) OVER (ORDER BY calendar_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg
FROM daily_users
ORDER BY calendar_date DESC;
```

---

## 🔄 Model Extension

### Step 8: EXTENDING THE MODEL (FUTURE-PROOFING)

When new features arrive, follow the rule:

```
RULE:

Add new FACT tables, don't change existing ones.
```

### Why This Matters

```
Existing queries must keep working.
New features should be isolated.
Clean separation of concerns.
```

### Example: Extending Fitness App

```
Original facts:
• fact_activity_events
• fact_login_events

New feature requested: Sleep tracking

❌ WRONG:
ALTER TABLE fact_activity_events ADD sleep_duration_hours INT;
This breaks the grain!

✅ CORRECT:
CREATE TABLE fact_sleep_events (
    event_id INT,
    user_id INT,
    device_id INT,
    date_id INT,
    sleep_start_time TIMESTAMP,
    sleep_end_time TIMESTAMP,
    duration_hours INT,
    quality_score INT
);

Reuse dimensions:
• dim_user (same user_id)
• dim_date (same date_id)
• dim_device (same device_id)
```

### Principles for Extension

```
1. Add new fact tables for new events
2. Reuse existing dimensions
3. Don't modify existing fact tables
4. Don't break existing grain
5. Name new facts clearly

Example additions:
• Workouts → fact_workout_events
• Sleep → fact_sleep_events
• Challenges → fact_challenge_events
• Social → fact_follow_events
```

---

## 🚨 Interview Traps

### Step 9: COMMON INTERVIEW TRAPS (AVOID THESE)

These are the mistakes that scream "junior":

### Trap 1: Jumping to Tables Without Clarifying

```
❌ WRONG:
Interviewer: "Design a data model for a fitness app"
You: "I'd have dim_user, dim_activity, fact_activities..."

✅ CORRECT:
Interviewer: "Design a data model for a fitness app"
You: "I'd like to clarify first:
     - What metrics matter most? (DAU, engagement, health metrics?)
     - What events are we tracking? (workouts, steps, heart rate?)
     - Is real-time required?
     - How long do we keep data?"
```

### Trap 2: Not Defining Grain Explicitly

```
❌ WRONG:
"One row per activity"
(Vague! Are multiple metrics in one row? Multiple timestamps?)

✅ CORRECT:
"One row per activity event, with columns for steps, 
 calories, heart rate, and duration - all captured at same timestamp"
```

### Trap 3: Mixing Row-Level Columns with GROUP BY

```
❌ WRONG:
SELECT user_id, activity_date, steps, calories
FROM fact_activity
WHERE activity_date = '2024-01-01'

You're mixing transaction-level data with aggregation!

✅ CORRECT:
SELECT user_id, activity_date, SUM(steps) AS total_steps, SUM(calories) AS total_calories
FROM fact_activity
WHERE activity_date = '2024-01-01'
GROUP BY user_id, activity_date
```

### Trap 4: Using HAVING Instead of WHERE

```
❌ WRONG:
SELECT user_id, SUM(steps) AS total_steps
FROM fact_activity
GROUP BY user_id
HAVING activity_date = '2024-01-01'  ← This is WRONG

✅ CORRECT:
SELECT user_id, SUM(steps) AS total_steps
FROM fact_activity
WHERE activity_date = '2024-01-01'   ← Filter before GROUP BY
GROUP BY user_id
```

### Trap 5: Pre-Aggregating Too Early

```
❌ WRONG:
fact_daily_summary (aggregated at warehouse load time)
  - Hard to drill down to details
  - Can't re-aggregate differently
  - Inflexible for new queries

✅ CORRECT:
fact_activity_events (raw events)
  - Analysts can aggregate any way they want
  - Can slice/dice flexibly
  - Supports ad-hoc queries
```

### Trap 6: Dimension → Dimension Joins

```
❌ WRONG:
fact_purchase
    ↓
dim_customer
    ↓
dim_country
    ↓
dim_region

✅ CORRECT:
fact_purchase → dim_customer (which has country, region attributes)
```

---

## 🎤 Interview Scripts

### Step 10: SAMPLE INTERVIEW SCRIPTS

Use these as templates for your responses.

### Script 1: "Design a Data Model for Netflix"

```
INTERVIEWER: "Design a data model for Netflix"

YOU: "I'd like to clarify a few things first:

1. Business Goals
   - Are we measuring retention, engagement, or content popularity?
   - What are our core metrics? (MAU, watch time, churn rate?)

2. Events to Track
   - Do we track every play/pause or just completed views?
   - Do we care about completion rate?

3. Data Freshness
   - Do we need real-time dashboards or is daily batch okay?

4. Dimensions
   - Do subscriber attributes change (address, country)?
   - Do we need historical tracking?

Given typical requirements, I'd propose:

FACT TABLES:
1. fact_streams (one row per viewing session)
   - user_id, content_id, start_time, end_time, duration_watched_sec, 
     completion_percentage

2. fact_subscription_events (one row per lifecycle change)
   - user_id, event_type (signup/upgrade/churn), date, tier

DIMENSIONS:
- dim_user (who watched?)
- dim_content (what did they watch?)
- dim_date (when?)
- dim_genre (how to categorize content?)

This star schema supports:
- Daily active users (SELECT DISTINCT user_id FROM fact_streams)
- Retention cohorts (join signup_date with viewing_date)
- Churn analysis (FROM fact_subscription_events WHERE event_type='churn')
- Content popularity (SELECT content_id, COUNT(*) FROM fact_streams GROUP BY content_id)

Any follow-ups?"
```

### Script 2: "What if We Need to Track Pause Events?"

```
INTERVIEWER: "What if we also want to track every pause event?"

YOU: "Good question. I have two options:

Option 1 (Simple - Keep Current):
- Keep fact_streams at session level
- Don't track every pause, just overall completion

Option 2 (Detailed - New Fact):
- Create fact_pause_events (one row per pause)
- Keep fact_streams at session level
- Join them for detailed analysis

I'd recommend Option 1 initially because:
1. Simpler to explain
2. Covers 90% of use cases
3. If we later need pause detail, we add fact_pause_events
   without breaking existing queries

But if we MUST have pause level detail from day 1, go with Option 2
and reuse dim_user, dim_date, dim_content.

How would it impact the analysis you want to do?"
```

### Script 3: "What About Product Attributes That Change?"

```
INTERVIEWER: "What if content has a featured_category that changes?"

YOU: "Great edge case. We have options:

Option 1 (SCD Type 1 - Overwrite):
dim_content:
  - content_id
  - title
  - featured_category (current value)
  
Problem: History lost

Option 2 (SCD Type 2 - Version):
dim_content:
  - content_id
  - title
  - featured_category
  - version_number
  - start_date
  - end_date
  - is_current

Better: Keeps full history

I'd recommend SCD Type 2 because:
- Historical analysis is possible
- When content was in what category?
- Analysts can use is_current filter for current state

Unless featured_category changes hourly (unlikely for content),
versioning is straightforward.

Does featured_category change frequently?"
```

### Script 4: "How Would You Scale This?"

```
INTERVIEWER: "How would you scale this model to handle 10B events/day?"

YOU: "Good question. At 10B events/day, I'd consider:

1. Partitioning
   - Partition fact tables by date
   - DROP old partitions after retention period
   - Speeds up date range queries

2. Pre-aggregation
   - Create fact_daily_summary at data load time
   - Most queries use daily granularity anyway
   - Can still drill to raw events if needed

3. Materialized Views
   - Pre-compute popular queries (top 100 contents)
   - Update nightly
   - Fast for dashboards

4. Star Schema Optimization
   - Keep dimensions small (< 100MB)
   - Use integer keys (faster than strings)
   - Cluster fact tables by time

Current model handles this well because:
- Only 2 facts per user action (no bloat)
- Integer keys are efficient
- Clean star schema indexes work well

At 10B scale, we'd likely add data warehouse (Snowflake/BigQuery)
and use columnar formats. Model remains the same."
```

---

## 🤔 Follow-Up Questions

### Step 11: PREPARE FOR FOLLOW-UP QUESTIONS

Interviewers often ask these to dig deeper:

### Follow-Up 1: "What Queries Would Break?"

```
INTERVIEWER: "If I added a new dimension to fact_purchase, 
             would existing queries break?"

YOU: "No, because:
1. I'm only adding columns, not changing existing structure
2. Existing columns remain unchanged
3. Old queries use old columns
4. New queries can use new dimension

Example:
Old query: SELECT user_id, SUM(amount) FROM fact_purchase GROUP BY user_id
If I add merchant_id column: Query still works exactly same

That's why adding dimensions is safe."
```

### Follow-Up 2: "What's the Cardinality of This Dimension?"

```
INTERVIEWER: "What's the cardinality of dim_user?"

YOU: "Good question. For a streaming app:
- Low cardinality initially (say, 10M users)
- Grows monthly but stays manageable (< 1B)
- Each row is ~500 bytes

Compare to dim_product:
- Could be 100M+ for e-commerce
- Still manageable since dimension, not fact

If it were a fact (like activities), 10B rows/day = huge problem.
That's why granularity matters."
```

### Follow-Up 3: "How Would You Handle NULL Values?"

```
INTERVIEWER: "What if a user doesn't have a subscription_tier?"

YOU: "Good catch. I'd handle this:

Option 1 (NULL in fact):
fact_purchase.subscription_tier_id = NULL
Problem: GROUP BY might miss these

Option 2 (Unknown dimension):
dim_subscription_tier:
  - tier_id = 0 (or -1)
  - tier_name = 'Unknown'
  - price = 0

Better: No NULLs to worry about, counts don't disappear

I'd use Option 2 because:
- NULL values complicate GROUP BY
- Aggregations handle 0 better than NULL
- Cleaner reporting

Unless there's specific business reason to keep NULL,
always use Unknown values in dimensions."
```

### Follow-Up 4: "What About Late-Arriving Data?"

```
INTERVIEWER: "What if activity is logged 3 days late?"

YOU: "Real problem in streaming data. I'd:

1. Partition by creation_date (when event happened)
2. Have an ingestion_date (when we received it)
3. Accept late arrivals up to X days

fact_activity:
  - event_timestamp (when it happened)
  - ingestion_date (when we got it)
  - PARTITION BY event_date

This way:
- Analytics use event_date (correct timing)
- Late data still flows to correct partition
- Can handle up to X days late
- Beyond X days, we reject or log separately

Trade-off: More complex, but accurate reporting."
```

---

## 🚫 Red Flags to Avoid

### Step 12: RED FLAGS TO AVOID IN INTERVIEWS

### Red Flag 1: "I'm Not Sure"

```
❌ DON'T SAY:
"I'm not sure what granularity we need"

✅ SAY:
"I'd typically start with event-level granularity (every activity),
 then pre-aggregate to daily if performance needs it. Let me ask:
 What's your typical query - single user or aggregated across millions?"
```

### Red Flag 2: Overcomplicating

```
❌ DON'T SAY:
"I'd create 15 fact tables with 30 dimensions,
 with complex hierarchies and slowly changing dimensions..."

✅ SAY:
"I'd start with 2 fact tables and 4 dimensions, then extend
 when we have specific requirements. Simple first, complex later."
```

### Red Flag 3: Ignoring Performance

```
❌ DON'T SAY:
"We'll just store raw events and aggregate on query"

✅ SAY:
"For 10B events/day, I'd partition by date and pre-compute
 daily summaries to keep queries fast. Raw events available
 for drill-down if needed."
```

### Red Flag 4: Not Asking About Users

```
❌ DON'T SAY:
"Here's the model" (without asking who will use it)

✅ SAY:
"Before I finalize, who's using this? Data scientists, analysts,
 business users? That affects denormalization strategy."
```

### Red Flag 5: No Extension Story

```
❌ DON'T SAY:
"This model handles everything we need"

✅ SAY:
"This handles our current requirements. When new events arrive,
 we add new fact tables reusing these dimensions. Here's how..."
```

### Red Flag 6: Confusing OLAP with OLTP

```
❌ DON'T SAY:
"This is fully normalized to 3NF"
(Wrong for analytics!)

✅ SAY:
"For analytics, I'm intentionally denormalizing to flatten joins.
 For operational systems, I'd normalize. Different goals."
```

### Red Flag 7: Dimension-Dimension Joins

```
❌ DON'T SAY:
"I'll join dim_product to dim_category to dim_supplier..."

✅ SAY:
"All these are in one hop from the fact table.
 I'm denormalizing to avoid chaining joins."
```

### Red Flag 8: No Grain Definition

```
❌ DON'T SAY:
"One row per user"

✅ SAY:
"One row per viewing session - all columns captured
 at the same moment in time."
```

---

## 🏆 Final One-Liners (MEMORIZE)

### Step 13: WINNING PHRASES

Memorize these. Use them in interviews.

```
📌 "I start by clarifying use cases and defining grain."

📌 "Facts capture events; dimensions provide context."

📌 "All joins originate from the fact table."

📌 "I design schemas around analytics queries."

📌 "To extend the model, I add new fact tables, not modify existing ones."

📌 "If SQL feels messy, the model is wrong."

📌 "I denormalize intentionally to keep queries simple."

📌 "This handles our current requirements. Here's how we extend it..."

📌 "Let me ask some clarifying questions first."

📌 "Grain is the first and most important decision."
```

---

## ✅ Pre-Interview Checklist

### Step 14: FINAL PREPARATION CHECKLIST

Before your interview, verify you can do these:

```
✅ Ask clarifying questions confidently
   - Business goals
   - Events to track
   - Data freshness
   - Dimension attributes

✅ State grain clearly
   - One sentence: "One row represents..."
   - Explain why that grain
   - Show how it supports queries

✅ Explain why a table is a fact or dimension
   - Facts have measures and FKs
   - Dimensions have attributes
   - Cardinality difference

✅ Avoid dim-dim joins instinctively
   - Every join from fact
   - Flatten dimensions if needed
   - Recognize the pattern immediately

✅ Explain SQL using the model
   - SELECT from facts
   - Filter facts, not dimensions
   - Join one hop to dims

✅ Show extension story
   - New events = new facts
   - Reuse dimensions
   - No breaking changes

✅ Compare OLAP vs OLTP
   - Denormalization for OLAP
   - Normalization for OLTP
   - Why both exist

✅ Handle edge cases
   - Changing attributes (SCD)
   - Multiple dates
   - NULL handling
   - Late-arriving data
```

---

## 🎯 30-Minute Practice Session

### Simulate an Interview

```
TIMER: 30 minutes

PART 1 (5 min): Clarifying Questions
- Ask your 8 clarifying questions
- Listen carefully to answers

PART 2 (10 min): Schema Design
- Draw the star diagram
- Define grain
- Explain facts and dimensions

PART 3 (10 min): Queries
- Write 3-5 key queries
- Explain what they answer
- Show SQL is clean

PART 4 (5 min): Extension
- Describe new feature
- Show how model extends
- No breaking changes

Review:
- Did you ask questions first?
- Was grain clear?
- Was SQL clean?
- Did you handle follow-ups?
```

---

## 📚 Quick Reference

### When Interviewer Says...

| Statement | Your Response |
|-----------|---------------|
| "Design Netflix data model" | "Let me ask a few clarifying questions first..." |
| "What's the grain?" | "One row per viewing session with all metrics from same moment" |
| "Is this a fact?" | "Yes, because it has measures and captures an event" |
| "How do you extend it?" | "New fact tables reusing these dimensions, no changes to existing" |
| "Queries are slow" | "Let me check the joins... if we're joining dims to dims, that's the issue" |
| "What about this edge case?" | "Good question. Here are my options..." |

---

**🎊 You're ready! Go ace that interview! 🚀**
