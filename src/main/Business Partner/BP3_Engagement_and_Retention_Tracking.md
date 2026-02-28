# 📊 DoorDash – Business Partner: Engagement & Retention Tracking

## Problem Statement
"We want to track engagement" (or retention, order quality, user satisfaction, etc.). How would you approach this? What metrics/KPIs would you define? What data sources? How would you build a dashboard?

---

## Q1: What does "engagement" mean for DoorDash?

### Answer:
Engagement varies by stakeholder:
- **Customer Engagement**: Frequency of orders, app usage, time spent browsing
- **Dasher Engagement**: Active delivery hours, acceptance rates, completion rates
- **Merchant Engagement**: Orders received, active hours, listing optimization

For this discussion, let's focus on **Customer Engagement** → which indicates likelihood of retention and lifetime value.

---

## Q2: How would you define engagement operationally?

### Answer:

**Primary Engagement Metrics:**

| Metric | Definition | Why It Matters |
|--------|-----------|-----------------|
| **Order Frequency** | Orders per user per week/month | Direct indicator of platform stickiness |
| **Days Active** | # of days user placed an order in 30-day window | Habit formation |
| **Session Count** | App opens per user per week | Engagement intensity |
| **Average Order Value (AOV)** | $ spent per order | Monetization health |
| **Time to Next Order** | Days between consecutive orders | Predictive of churn risk |

**Derived Engagement Metrics:**

| Metric | Definition | Formula |
|--------|-----------|---------|
| **Monthly Active Users (MAU)** | Users with ≥1 order in 30 days | Count(distinct users) |
| **Weekly Active Users (WAU)** | Users with ≥1 order in 7 days | Count(distinct users) |
| **Repeat Order Rate** | % of users ordering 2+ times | (Users with ≥2 orders / Total users) × 100 |
| **D1/D7/D30 Retention** | % of users returning after 1/7/30 days | (Returning users / New users) × 100 |
| **Engagement Score** | Composite metric combining frequency, value, recency | (Orders_30d × Weight1) + (AOV × Weight2) + (Days_Active × Weight3) |

---

## Q3: How would you segment users to understand engagement better?

### Answer:

**Segmentation Strategy:**

```
┌─────────────────────────────────────┐
│     USER ENGAGEMENT SEGMENTS        │
├─────────────────────────────────────┤
│ 1. POWER USERS                      │
│    - 4+ orders/month, high AOV      │
│    - Goal: Maximize LTV             │
│                                     │
│ 2. REGULAR USERS                    │
│    - 2-4 orders/month, mid AOV      │
│    - Goal: Increase frequency       │
│                                     │
│ 3. OCCASIONAL USERS                 │
│    - 1 order/month or less          │
│    - Goal: Reactivate               │
│                                     │
│ 4. AT-RISK (Churning)               │
│    - No orders in 60+ days          │
│    - Goal: Win-back campaigns       │
│                                     │
│ 5. NEW USERS                        │
│    - <30 days on platform           │
│    - Goal: Drive repeat behavior    │
└─────────────────────────────────────┘
```

**Additional Segmentations:**
- By geography (city, neighborhood)
- By food preference (cuisine, restaurant type)
- By time preference (lunch vs dinner)
- By device (iOS vs Android vs web)

---

## Q4: What data sources would you need?

### Answer:

**Core Data Sources:**

| Source | Data | Use Case |
|--------|------|----------|
| **Orders DB** | order_id, user_id, timestamp, amount, merchant_id, status | Order frequency, AOV, completion rates |
| **Users DB** | user_id, signup_date, city, device, last_login | Cohort analysis, platform stickiness |
| **App Events** | user_id, event_type (view, search, add_to_cart), timestamp | Session depth, browsing behavior |
| **Merchant DB** | merchant_id, cuisine, rating, avg_delivery_time | Merchant quality impact on engagement |
| **Ratings/Reviews** | order_id, user_id, rating, review_text | Satisfaction → engagement feedback loop |
| **Promo/Marketing** | user_id, campaign_id, promo_applied, timestamp | Attribution of engagement lift |
| **Customer Support** | user_id, complaint_category, resolution_time | Dissatisfaction indicators |

**Data Architecture:**

```
┌──────────────────────────────────────────────┐
│             RAW DATA SOURCES                 │
├──────────────────────────────────────────────┤
│ Orders DB  │ Users DB  │ Events  │ Merchants │
└──────┬──────────┬──────────┬────────┬────────┘
       │          │          │        │
       └──────────┼──────────┼────────┘
                  ▼
        ┌─────────────────────┐
        │  DATA WAREHOUSE     │
        │   (Fact Tables)     │
        ├─────────────────────┤
        │ Orders Fact         │
        │ Users Dimension     │
        │ Merchants Dimension │
        │ Time Dimension      │
        └────────┬────────────┘
                 ▼
        ┌─────────────────────┐
        │ ENGAGEMENT METRICS  │
        │ TABLE (AGGREGATED)  │
        └────────┬────────────┘
                 ▼
        ┌─────────────────────┐
        │   DASHBOARD         │
        │   (Visualization)   │
        └─────────────────────┘
```

---

## Q5: How would you calculate retention cohorts?

### Answer:

**Cohort Retention Approach:**

```
Cohort: Users who signed up in January 2026

        Jan    Feb    Mar    Apr    May
Jan     100%   45%    32%    28%    22%
Feb            100%   52%    38%    25%
Mar                   100%   48%    35%
Apr                          100%   42%
May                                 100%

Reading: 45% of January cohort was still active (≥1 order) in February
         32% of January cohort was still active in March
```

**Formula:**
```
Retention_Rate(Cohort, Week_N) = 
    (Users_from_Cohort_Active_in_Week_N / Total_Users_in_Cohort) × 100
```

**Cohort Analysis:**
- New users tend to have high Day-1 retention (~50-60%)
- Day-7 retention typically drops to 20-30%
- Stable retention plateau around Day-30

---

## Q6: What would your dashboard look like?

### Answer:

**Dashboard Structure:**

```
┌─────────────────────────────────────────────────────┐
│ DOORDASH ENGAGEMENT & RETENTION DASHBOARD           │
├─────────────────────────────────────────────────────┤
│                                                     │
│ ┌─── KEY METRICS (Top Row) ───┐                   │
│ │ MAU: 2.3M    WAU: 1.8M       │                   │
│ │ Repeat Rate: 58%  D30 Ret: 42%                   │
│ │                              │                   │
│ └──────────────────────────────┘                   │
│                                                     │
│ ┌─── Retention Curve (Left) ─┐ ┌─ Cohort Heatmap ┐│
│ │ 100%                        │ │ Jan  45% 32%... ││
│ │  80%   ╱                    │ │ Feb  52% 38%... ││
│ │  60%  ╱                     │ │ Mar  48% 35%... ││
│ │  40% ╱                      │ │ Apr  42% ...    ││
│ │  20%╱                       │ │ May  ...        ││
│ │   └─────────────────        │ │                 ││
│ │   Day0 7  14  21  28        │ └─────────────────┘│
│ │                                                  │
│ ├──────────────────────────────────────────────────┤
│ │ Order Frequency Distribution (Bottom Left)      │
│ │ ┌─────────────────────────────────────┐         │
│ │ │ 5+ orders: 15%                      │         │
│ │ │ 3-4 orders: 25%                     │         │
│ │ │ 2 orders: 30%                       │         │
│ │ │ 1 order: 30%                        │         │
│ │ └─────────────────────────────────────┘         │
│ │                                                  │
│ ├──────────────────────────────────────────────────┤
│ │ Engagement Trends by Segment (Bottom Right)    │
│ │ ┌─────────────────────────────────────┐         │
│ │ │ Power Users:  ↑ +8% MoM             │         │
│ │ │ Regular Users: → Flat               │         │
│ │ │ Occasional:   ↓ -5% MoM             │         │
│ │ │ At-Risk:      ↓ -12% MoM            │         │
│ │ └─────────────────────────────────────┘         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Drill-Down Capabilities:**
- Filter by city, cuisine type, time period
- Compare segments
- Anomaly detection (sudden drops in engagement)
- Correlation with marketing campaigns

---

## Q7: What would cause engagement to drop?

### Answer:

**Root Cause Analysis Framework:**

| Category | Potential Causes | Investigation |
|----------|------------------|-----------------|
| **Product** | Bugs in app, slow loading, UX changes | App crash logs, session duration, bounce rate |
| **Supply** | Fewer restaurants, longer wait times | Avg delivery time trending, merchant count |
| **Quality** | Cold food, late deliveries, rude drivers | Ratings distribution, complaint tickets |
| **Demand** | Marketing spend decreased, seasonality | Marketing spend timeline, holiday periods |
| **Competition** | Uber Eats promo, new competitor | Competitive pricing intelligence |
| **External** | Economic downturn, weather, lockdowns | Macro indicators, weather data |

**Diagnostic Dashboard:**
```
Engagement Drop Detected: -15% MoM

┌─────────────────────────────────────┐
│ Pinpoint the Root Cause             │
├─────────────────────────────────────┤
│                                     │
│ App Performance?                    │
│ ▓▓▓▓░ 40% degradation              │
│                                     │
│ Delivery Times?                     │
│ ▓▓▓▓▓▓▓▓░ 82% increase (WARNING)   │
│                                     │
│ Avg Rating?                         │
│ ▓▓░ 3.8/5.0 (down from 4.1)        │
│                                     │
│ Marketing Spend?                    │
│ ░░░░░░░░░░ 50% cut                  │
│                                     │
└─────────────────────────────────────┘

PRIMARY CULPRIT: Delivery Times + Marketing Spend Cut
```

---

## Q8: How would you set up alerts?

### Answer:

**Alert System:**

| Alert | Threshold | Action |
|-------|-----------|--------|
| **Retention Drop** | D30 retention < 40% (vs historical 42%) | Investigate via cohort analysis |
| **Engagement Score Drop** | >10% week-over-week decline | Alert ops & product teams |
| **Repeat Rate Drop** | <55% (vs 58% baseline) | Review quality metrics |
| **New User Conversion** | D7 retention < 25% on new users | Escalate to growth team |
| **Segment at Risk** | Occasional users shrinking >5% weekly | Prepare reactivation campaign |

---

## Summary: Engagement & Retention Strategy

1. **Define metrics**: Order frequency, retention cohorts, repeat rate, engagement score
2. **Segment users**: Power, Regular, Occasional, At-Risk, New
3. **Data sources**: Orders, users, events, merchants, ratings
4. **Build dashboard**: Track trends, segment performance, enable drill-down
5. **Diagnose issues**: Investigate drops via product, supply, quality, demand factors
6. **Set alerts**: Proactive monitoring of engagement health

