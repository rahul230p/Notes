# 🔎 DoorDash – Business Partner: Sales/Order Drop Investigation

## Problem Statement
If there is a drop in sales/orders, how would you figure it out? What data sources/steps would you take?

---

## Q1: What's your investigation framework?

### Answer:

**Sales Drop Investigation Methodology:**

```
SALES DROP DETECTED
  ↓
STEP 1: SCOPE & QUANTIFY
├─ How big is the drop? (1% vs 10% vs 50%?)
├─ How sudden? (overnight vs gradual?)
├─ How widespread? (all cities or some?)
├─ How long? (1 day, 1 week, ongoing?)
└─ Output: Severity assessment (critical → monitor)

  ↓
STEP 2: IDENTIFY WHAT CHANGED
├─ Product: Any code changes, deployments?
├─ Data: Technical issues, tracking problems?
├─ External: Marketing spend, competitor moves?
├─ Market: Seasonality, weather, events?
└─ Output: Root cause hypothesis

  ↓
STEP 3: SEGMENT & INVESTIGATE
├─ By city/region
├─ By user type (new vs power users)
├─ By device (iOS vs Android)
├─ By time (peak vs off-peak)
└─ Output: Hotspot identification

  ↓
STEP 4: CORRELATE WITH EVENTS
├─ Recent deployments?
├─ Marketing changes?
├─ Competitor activity?
├─ Technical incidents?
└─ Output: Event correlation analysis

  ↓
STEP 5: ROOT CAUSE DETERMINATION
├─ Product issue
├─ Supply issue
├─ Demand issue
├─ External/market issue
└─ Output: Clear root cause diagnosis

  ↓
STEP 6: ACTION PLAN
├─ Immediate response
├─ Long-term fix
├─ Monitoring & prevention
└─ Output: Detailed recovery plan
```

---

## Q2: What data would you pull FIRST?

### Answer:

**Priority Data Pulls (in order):**

```
MINUTE 1-15: QUICK SNAPSHOT

1. Pull Daily Orders Trend
   ├─ Last 30 days of daily order volume
   ├─ Identify drop date and magnitude
   ├─ Compare to baseline (last week, last year same day)
   └─ Query: SELECT date, COUNT(orders) FROM orders 
             WHERE date >= NOW() - INTERVAL 30 DAY
             GROUP BY date ORDER BY date DESC

2. Check Recent Deployments
   ├─ Any code changes in last 24-48 hours?
   ├─ App version? API changes?
   ├─ Feature flags modified?
   └─ Correlation: Did drop start after deployment?

3. Check Infrastructure/Ops Alerts
   ├─ Any system alerts, outages, errors?
   ├─ Database performance degradation?
   ├─ API latency spikes?
   └─ Correlation: Timing match?

4. Check Competitive Activity
   ├─ Did a competitor launch promo?
   ├─ Did Uber Eats increase marketing?
   ├─ Are they offering lower prices?
   └─ Anecdotal: Customer/team reports?

5. Check Marketing Calendar
   ├─ Any marketing campaign changes?
   ├─ Budget increased/decreased?
   ├─ Channel performance?
   └─ Timing: Any pause or pause in campaigns?

OUTPUT AFTER 15 MIN:
├─ IF deployment obvious culprit → Rollback if possible
├─ IF infrastructure issue → Escalate to ops
├─ IF external/market → Continue investigation
└─ IF unclear → Go to STEP 2 deeper analysis
```

**MINUTE 15-60: DETAILED SEGMENTATION**

```
6. Segment by Geography
   ├─ City-by-city breakdown
   ├─ Identify: Drop everywhere or specific cities?
   └─ Query: SELECT city, COUNT(orders), 
             FROM orders 
             WHERE date >= NOW() - INTERVAL 2 DAY
             GROUP BY city
   
   PATTERN 1: ALL cities dropping
   └─ Likely: System-wide, product, or market issue
   
   PATTERN 2: SOME cities dropping
   └─ Likely: Regional issue, competitor, or local event
   
   PATTERN 3: Only NEW market dropping
   └─ Likely: Market-specific, not system issue

7. Segment by User Type
   ├─ New users: Orders, conversion rate
   ├─ Power users: Orders, frequency
   ├─ Inactive: Any reactivation?
   └─ Query: SELECT user_cohort, COUNT(orders), 
             FROM orders 
             WHERE date >= NOW() - INTERVAL 2 DAY
             GROUP BY user_cohort
   
   PATTERN 1: ALL user types dropping equally
   └─ Likely: Supply issue or platform quality
   
   PATTERN 2: NEW user orders dropping (power users flat)
   └─ Likely: Marketing or acquisition issue
   
   PATTERN 3: POWER users dropping (new users stable)
   └─ Likely: Quality issue, retention problem

8. Segment by Device/Platform
   ├─ iOS orders
   ├─ Android orders
   ├─ Web orders
   └─ Query: SELECT device_type, COUNT(orders) 
             FROM orders 
             WHERE date >= NOW() - INTERVAL 2 DAY
             GROUP BY device_type
   
   PATTERN: One device/app dropping
   └─ Likely: App bug, update issue, or iOS/Android specific problem

9. Segment by Time of Day
   ├─ Breakfast, lunch, dinner peaks
   ├─ When is the drop happening?
   └─ Query: SELECT HOUR(created_at), COUNT(orders) 
             FROM orders 
             WHERE date >= NOW() - INTERVAL 2 DAY
             GROUP BY HOUR(created_at)
   
   PATTERN 1: Drop across all hours
   └─ Likely: Broad issue (supply, product, market)
   
   PATTERN 2: Drop only during peak hours
   └─ Likely: Supply shortage during peak
   
   PATTERN 3: Drop only during off-peak
   └─ Likely: Pricing or promotion issue

10. Compare to Baseline
    ├─ Same day last week: Week-over-week
    ├─ Same day last year: Year-over-year
    ├─ Last 4 weeks average: Vs trend
    └─ Check for seasonality confounds
    
    QUERY: SELECT 
              DATE(created_at) as order_date,
              DAYOFWEEK(created_at) as dow,
              COUNT(*) as order_count
           FROM orders
           WHERE DATE(created_at) IN 
              (CURRENT_DATE, 
               DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY),
               DATE_SUB(CURRENT_DATE, INTERVAL 14 DAY),
               DATE_SUB(CURRENT_DATE, INTERVAL 365 DAY))
           GROUP BY order_date, dow

OUTPUT AFTER 60 MIN:
├─ Pinpoint: Where is the problem? (geo? user type? time?)
├─ Narrow hypothesis: Product, supply, demand, or external?
└─ Next: Deep-dive into most likely root cause
```

---

## Q3: What specific metrics would you investigate?

### Answer:

**Diagnostic Metrics by Root Cause Hypothesis:**

```
HYPOTHESIS 1: PRODUCT/TECHNICAL ISSUE

Investigate These Metrics:
├─ App Crash Rate
│  ├─ Any spike in crashes?
│  ├─ Specific to one version?
│  └─ Query: SELECT app_version, crash_count/session_count 
│            FROM app_metrics WHERE date >= YESTERDAY
│
├─ Session Completion Rate
│  ├─ Users starting but not completing checkout?
│  ├─ Funnel drop-off point?
│  └─ Query: 
│     WITH funnel AS (
│       SELECT session_id,
│         SUM(CASE WHEN event='browse' THEN 1 END) as browse,
│         SUM(CASE WHEN event='add_to_cart' THEN 1 END) as cart,
│         SUM(CASE WHEN event='checkout' THEN 1 END) as checkout,
│         SUM(CASE WHEN event='purchase' THEN 1 END) as purchase
│       FROM events WHERE date >= YESTERDAY
│       GROUP BY session_id
│     )
│     SELECT 
│       COUNT(CASE WHEN browse>0 THEN 1 END) / COUNT(*) as browse_rate,
│       COUNT(CASE WHEN cart>0 THEN 1 END) / COUNT(*) as cart_rate,
│       COUNT(CASE WHEN checkout>0 THEN 1 END) / COUNT(*) as checkout_rate,
│       COUNT(CASE WHEN purchase>0 THEN 1 END) / COUNT(*) as purchase_rate
│     FROM funnel
│
├─ Page Load Time
│  ├─ Home page latency increased?
│  ├─ Restaurant detail page slow?
│  └─ Query: SELECT page, PERCENTILE(load_time_ms, 0.5) as p50,
│                       PERCENTILE(load_time_ms, 0.95) as p95
│           FROM page_metrics WHERE date >= YESTERDAY GROUP BY page
│
├─ API Error Rate
│  ├─ Backend service errors?
│  ├─ Payment processing failures?
│  └─ Query: SELECT endpoint, COUNT(*), 
│                   SUM(CASE WHEN error_code IS NOT NULL THEN 1 END) as errors
│           FROM api_logs WHERE date >= YESTERDAY GROUP BY endpoint
│
└─ Feature Flag Status
   ├─ Any flags rolled back or changed?
   ├─ Gradual rollout stalled?
   └─ Check feature flag service logs

IF PRODUCT ISSUE:
├─ Severity: CRITICAL
├─ Action: Immediate rollback of recent changes
├─ Timeline: Fix in hours, not days
└─ Example: "Checkout bug introduced 2pm, fixed by 3pm, orders recovering"


HYPOTHESIS 2: SUPPLY ISSUE (Not enough Dashers)

Investigate These Metrics:
├─ Active Dasher Count
│  ├─ How many drivers online?
│  ├─ Sudden drop?
│  └─ Query: SELECT hour, COUNT(DISTINCT dasher_id) as active_dashers
│           FROM dasher_sessions WHERE date >= YESTERDAY
│           GROUP BY hour
│
├─ Order Wait Time (Time to Driver Assignment)
│  ├─ How long until order gets accepted?
│  ├─ Trending up?
│  └─ Query: SELECT 
│           PERCENTILE(UNIX_TIMESTAMP(assigned_at) - UNIX_TIMESTAMP(created_at), 0.5) as p50_wait,
│           PERCENTILE(UNIX_TIMESTAMP(assigned_at) - UNIX_TIMESTAMP(created_at), 0.95) as p95_wait
│         FROM orders WHERE date >= YESTERDAY
│
├─ Order Cancellation Rate
│  ├─ % of orders cancelled by dasher?
│  ├─ Drivers not accepting?
│  └─ Query: SELECT 
│           COUNT(CASE WHEN status='cancelled' THEN 1 END) / COUNT(*) as cancel_rate
│           FROM orders WHERE date >= YESTERDAY
│
├─ Dasher Acceptance Rate
│  ├─ % of orders offered that dashers accept?
│  ├─ Below threshold?
│  └─ Query: SELECT 
│           COUNT(CASE WHEN accepted=TRUE THEN 1 END) / COUNT(*) as acceptance_rate
│           FROM order_assignments WHERE date >= YESTERDAY
│
├─ Dasher Earnings
│  ├─ Average $ per dasher per hour
│  ├─ Dropped relative to competitors?
│  └─ Might explain supply shortage
│
└─ Surge Multiplier
   ├─ Is surge pricing high?
   ├─ Customers seeing higher prices?
   └─ Might suppress demand perception

IF SUPPLY ISSUE:
├─ Severity: HIGH
├─ Action: Increase dasher incentives, surge pricing, marketing
├─ Timeline: Effects seen within 4-6 hours
└─ Example: "Dasher supply down 15%, increased incentives, recovering"


HYPOTHESIS 3: DEMAND ISSUE (Customers not ordering)

Investigate These Metrics:
├─ App Opens (DAU)
│  ├─ Are users opening the app?
│  ├─ Baseline active users down?
│  └─ Query: SELECT date, COUNT(DISTINCT user_id) as dau 
│           FROM app_opens WHERE date >= YESTERDAY GROUP BY date
│
├─ Search Volume
│  ├─ Users searching for restaurants?
│  ├─ Baseline search activity?
│  └─ Query: SELECT date, COUNT(*) as search_count 
│           FROM searches WHERE date >= YESTERDAY GROUP BY date
│
├─ Browse Sessions
│  ├─ Are users browsing?
│  ├─ Session duration?
│  └─ Query: SELECT date, COUNT(DISTINCT session_id) as sessions,
│                   AVG(session_duration_sec) as avg_session_duration
│           FROM sessions WHERE date >= YESTERDAY GROUP BY date
│
├─ Conversion Rate (Browse → Order)
│  ├─ Of users browsing, what % convert?
│  ├─ Conversion dropping while traffic stable?
│  └─ Query: SELECT 
│           COUNT(DISTINCT user_id) as browsing_users,
│           COUNT(DISTINCT CASE WHEN has_order=TRUE THEN user_id END) as order_users,
│           COUNT(DISTINCT CASE WHEN has_order=TRUE THEN user_id END) / COUNT(DISTINCT user_id) as conversion
│         FROM user_activity WHERE date >= YESTERDAY
│
├─ Marketing Spend & Attribution
│  ├─ Marketing budget cut?
│  ├─ Channel performance down?
│  └─ Are paid users still converting?
│
├─ Customer Feedback/NPS
│  ├─ Are ratings dropping?
│  ├─ Complaints about prices, selection?
│  └─ Query: SELECT date, AVG(rating) as avg_rating,
│                   COUNT(*) as review_count
│           FROM ratings WHERE date >= YESTERDAY GROUP BY date
│
└─ Competitor Intelligence
   ├─ Did competitor launch promo?
   ├─ Are their ads everywhere?
   └─ Customer switching?

IF DEMAND ISSUE:
├─ Severity: MEDIUM
├─ Action: Analyze cause (supply, quality, pricing, competition)
├─ Timeline: Investigation + response in 24-48 hours
└─ Example: "Marketing spend cut 30%, DAU down proportionally"


HYPOTHESIS 4: QUALITY/RETENTION ISSUE

Investigate These Metrics:
├─ Customer Satisfaction Scores
│  ├─ Ratings trending?
│  ├─ Complaints increasing?
│  └─ Query: SELECT date, AVG(rating) as avg_rating 
│           FROM ratings WHERE date >= YESTERDAY GROUP BY date
│
├─ Complaint Categories
│  ├─ Cold food, late delivery, rude dasher?
│  ├─ One category spiking?
│  └─ Query: SELECT complaint_category, COUNT(*) as count
│           FROM complaints WHERE date >= YESTERDAY 
│           GROUP BY complaint_category
│
├─ Delivery Time Distribution
│  ├─ Is delivery slower than usual?
│  ├─ P95 delivery time increased?
│  └─ Query: SELECT 
│           PERCENTILE(delivery_time_minutes, 0.50) as p50,
│           PERCENTILE(delivery_time_minutes, 0.95) as p95,
│           PERCENTILE(delivery_time_minutes, 0.99) as p99
│         FROM deliveries WHERE date >= YESTERDAY
│
├─ On-Time Delivery Rate
│  ├─ % of orders arriving on time?
│  ├─ Dropped below target?
│  └─ Query: SELECT 
│           COUNT(CASE WHEN arrived_by_est=TRUE THEN 1 END) / COUNT(*) as ontime_pct
│           FROM deliveries WHERE date >= YESTERDAY
│
├─ Food Quality Issues
│  ├─ "Cold food" complaints?
│  ├─ "Wrong order" complaints?
│  └─ Any new restaurant quality problems?
│
├─ Repeat Order Rate
│  ├─ Are returning customers ordering again?
│  ├─ Cohorts from 2 weeks ago: any repeat yet?
│  └─ Query: 
│     WITH cohort_2wk_ago AS (
│       SELECT DISTINCT user_id 
│       FROM orders 
│       WHERE DATE(created_at) BETWEEN DATE_SUB(NOW(), INTERVAL 15 DAY) 
│                                      AND DATE_SUB(NOW(), INTERVAL 8 DAY)
│     )
│     SELECT COUNT(DISTINCT o.user_id) / COUNT(DISTINCT c.user_id) as repeat_rate
│     FROM cohort_2wk_ago c
│     LEFT JOIN orders o ON c.user_id = o.user_id 
│                      AND DATE(o.created_at) >= NOW() - INTERVAL 7 DAY
│
└─ Churn Rate
   ├─ Are users leaving (not ordering for 30 days)?
   ├─ Churn rate trending?
   └─ Any cohort particularly affected?

IF QUALITY ISSUE:
├─ Severity: MEDIUM
├─ Action: Quality investigation, merchant support, operations review
├─ Timeline: Root cause in 24 hours, fix in 3-7 days
└─ Example: "Delivery times up 8 min avg, on-time dropped to 89%"


HYPOTHESIS 5: EXTERNAL/MARKET ISSUE

Investigate These Metrics:
├─ Weather
│  ├─ Bad weather suppresses delivery demand?
│  ├─ Is it raining, snowing, extreme temps?
│  └─ Correlate with order drop
│
├─ Events
│  ├─ Major event, holiday, sports game?
│  ├─ Summer vacation season?
│  └─ These drive uncontrollable demand changes
│
├─ Competitor Activity
│  ├─ Uber Eats new promo?
│  ├─ Grubhub deep discount?
│  ├─ Monitor competitor app store rankings
│  └─ Check Twitter/social for complaints about competitors
│
├─ Macro Economic
│  ├─ Market downturn, recession signals?
│  ├─ Unemployment rate?
│  ├─ Consumer spending data?
│  └─ Could suppress discretionary spending (food delivery)
│
└─ Regulatory Changes
   ├─ New delivery fee rules?
   ├─ Wage laws affecting driver availability?
   └─ Could impact both supply and demand

IF EXTERNAL ISSUE:
├─ Severity: MEDIUM
├─ Action: Analyze, prepare scenarios, long-term strategy
├─ Timeline: Depends on nature and duration
└─ Example: "Snow storm in Midwest, suppressed orders 20%, normalizing today"
```

---

## Q4: What's your prioritized investigation order?

### Answer:

**Decision Tree for Prioritization:**

```
WHEN SALES DROP IS DETECTED:

┌─ IMMEDIATE (Minutes 0-5)
│  ├─ Alert: Page/system down? Check status
│  ├─ Check: Recent deployment? Rollback if obvious
│  ├─ Check: System alerts, errors
│  └─ IF critical issue found → RESOLVE IMMEDIATELY
│                              → Skip to recovery plan
│
├─ QUICK DIAGNOSIS (Minutes 5-30)
│  ├─ Segment: Is drop everywhere or specific area?
│  ├─ Segment: All users or specific type?
│  ├─ Segment: All time periods or specific hours?
│  ├─ Data: Pull dashboards for these segments
│  └─ Hypothesis: Narrow to 2-3 most likely causes
│
├─ TARGETED INVESTIGATION (Minutes 30-120)
│  ├─ IF looks like PRODUCT issue:
│  │  └─ Deep-dive: App metrics, funnel analysis, error logs
│  │     → Isolate bug, fix, rollout
│  │     → Timeline: 1-4 hours
│  │
│  ├─ IF looks like SUPPLY issue:
│  │  └─ Deep-dive: Dasher availability, acceptance rates, incentives
│  │     → Increase incentives, adjust surge pricing
│  │     → Timeline: 4-6 hours for recovery
│  │
│  ├─ IF looks like DEMAND issue:
│  │  └─ Deep-dive: Conversion funnel, marketing, customer feedback
│  │     → Identify cause (quality, price, competition)
│  │     → Timeline: 24-48 hours for full analysis
│  │
│  ├─ IF looks like QUALITY issue:
│  │  └─ Deep-dive: Complaints, ratings, delivery time, specific restaurants
│  │     → Identify problematic restaurants or zones
│  │     → Timeline: 24-48 hours to fix
│  │
│  └─ IF looks like EXTERNAL issue:
│     └─ Deep-dive: Weather, events, competitor moves
│        → Monitor closely, prepare long-term response
│        → Timeline: Depends on external factor
│
└─ ROOT CAUSE + ACTION PLAN (Within 24 hours)
   ├─ Document: What we found, why it happened
   ├─ Immediate: Fix or workaround
   ├─ Short-term: Resolution path
   ├─ Monitoring: Metrics to track recovery
   └─ Prevention: How to catch this earlier next time
```

---

## Q5: How do you determine root cause in ambiguous cases?

### Answer:

**Root Cause Diagnosis Playbook:**

```
CASE 1: Sales down 8%, Can't tell why

Step 1: Check each hypothesis
├─ Product issue: No recent deployments, no errors, no crashes ✗
├─ Supply issue: Dasher count down 12%, acceptance rates down ✓
├─ Demand issue: DAU down 5%, but conversion rate stable ✗
├─ Quality issue: Ratings stable, complaints flat ✗
├─ External: Weather normal, competitor quiet ✗

LIKELY ROOT CAUSE: Supply shortage
├─ Dashers missing = orders unassigned = effective supply drop
├─ ACTION: Increase dasher incentives 20%, run targeted recruitment ads
├─ TIMELINE: Expect recovery in 4-6 hours


CASE 2: Sales down 12%, Multiple factors contributing

Breakdown:
├─ DAU down 10% (demand drop)
├─ Dasher supply down 8% (supply drop)
├─ Conversion rate down 3% (quality or product)
├─ Delivery time up 5 min (ops degradation)

Diagnosis:
├─ PRIMARY: Likely a quality cascade
│  └─ Quality dropped → delivery times up → satisfaction down
│  └─ This → customers ordering less → appearing as demand drop
│
├─ SECONDARY: Dasher side effect
│  └─ Longer delivery times → Dasher earnings down → supply leaves
│
└─ ROOT CAUSE: Something degraded operations (weather, system, merchant issue?)

ACTION:
├─ Immediate: Investigate what caused delivery time increase
│  └─ Weather? Routing algorithm? Merchant delays?
│
├─ Short-term: Increase dasher incentives to stabilize supply
│
├─ Quality: Fix root operations issue
│
├─ Demand: Once quality fixed, run retention campaign


CASE 3: Sales down 4%, Everything looks normal

This is tricky! Possible causes:
├─ Sampling variation (real 4% drop or just noise?)
├─ Slow churn (quality degradation not yet visible)
├─ Competitive pressure (customers slowly switching)
├─ Seasonal downturn (happens same time every year?)

Diagnosis:
├─ Check: Is 4% statistically significant? Or just variation?
│  └─ Compare to rolling std dev
│  └─ If <1 std dev, might be noise
│
├─ Check: Cohort analysis
│  └─ Are new cohorts worse than old?
│  └─ Might indicate product quality degradation
│
├─ Check: Long-term retention
│  └─ Are D30 retention rates declining?
│  └─ Subtle churn signal
│
├─ Check: Regional patterns
│  └─ Only some cities down?
│  └─ Might indicate local competition or event

ACTION:
├─ If noise: No action, monitor weekly
├─ If product issue: Investigate, run diagnostics
├─ If retention issue: Analyze why retention declining
├─ If competitive: Competitive response strategy
```

---

## Q6: What's your recovery monitoring plan?

### Answer:

**Post-Diagnosis Monitoring:**

```
ONCE ROOT CAUSE IDENTIFIED, IMPLEMENT FIXES + MONITOR

Example: Supply shortage identified + fixed

TIMELINE                 METRIC TO MONITOR
═══════════════════════════════════════════════════

T+0 (Action taken)
├─ Increased dasher incentives 20%
├─ Launched "urgent hiring" recruitment

T+30 minutes
├─ Track: New dasher sign-ups (expecting 20% increase)
├─ Track: Active dasher count (expecting +5-10%)
├─ Track: Order assignment time (expecting to improve)

T+2 hours
├─ Track: Delivery time (expecting improvement)
├─ Track: On-time delivery rate (expecting +2-3%)
├─ Track: Order volume (expecting to stabilize/recover)

T+4 hours
├─ Track: Daily order volume vs baseline (target: -3% or better)
├─ Track: Customer satisfaction (should stay stable)
├─ Track: Dasher satisfaction with incentives

T+24 hours
├─ Track: Full day order volume (target: -2% or better)
├─ Track: All key metrics back to baseline
├─ Track: Repeat rate stability

T+7 days
├─ Track: New cohort quality (any retention impact?)
├─ Track: Dasher retention (are they staying?)
├─ Track: Margin impact (did incentive cost worth it?)

RECOVERY SUCCESS CRITERIA:
├─ Order volume returns to baseline within 24-48 hours
├─ Customer satisfaction metrics stable
├─ Dasher supply stabilized
├─ No new issues emerged
└─ Margin impact acceptable

ESCALATION RULES:
├─ IF order volume not recovering after 6 hours → Escalate to VP
├─ IF customer satisfaction dropping → Halt fix, investigate
├─ IF problem returned after seeming fixed → Root cause different
└─ IF margin impact >10% → Re-evaluate strategy


DASHBOARD FOR RECOVERY MONITORING:

┌──────────────────────────────────────────────────┐
│ RECOVERY DASHBOARD (Real-time)                   │
│ Incident: Sales drop 12/15 2:30pm, Root: Supply │
│                                                  │
│ ORDERS (Last 24 hours)                          │
│ Baseline: 500K                                   │
│ Start of incident: 440K (↓ 12%) ⚠️              │
│ T+4hr: 480K (↓ 4%) 📈                           │
│ T+8hr: 510K (↑ 2%) ✓                            │
│ Current: 515K (↑ 3%) ✓                          │
│                                                  │
│ DASHER SUPPLY                                   │
│ Baseline: 5,000 active                          │
│ Start of incident: 4,400 (↓ 12%) ⚠️             │
│ T+4hr: 5,200 (↑ 4%) ✓                           │
│ Current: 5,350 (↑ 7%) ✓                         │
│                                                  │
│ DELIVERY TIME (P50)                             │
│ Baseline: 32 min                                │
│ Start of incident: 38 min ⚠️                    │
│ T+4hr: 34 min 📈                                │
│ Current: 32.5 min ✓                             │
│                                                  │
│ COST TO RECOVER                                 │
│ Dasher incentive spend: $2.1M extra             │
│ Revenue recovered: $3.2M                        │
│ Net ROI: 1.5x ✓                                 │
│                                                  │
│ STATUS: 🟢 RECOVERED                            │
│ Recovery time: 8 hours                          │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Summary: Order Drop Investigation Process

1. **Quantify**: How big, sudden, widespread? (Severity assessment)
2. **Quick check**: Recent changes, technical issues? (Immediate fixes)
3. **Segment**: By geography, user type, time? (Pinpoint problem)
4. **Diagnose**: Product, supply, demand, quality, or external?
5. **Deep-dive**: Pull specific metrics for that hypothesis
6. **Root cause**: Clear determination, not vague
7. **Action plan**: Immediate fix + long-term solution
8. **Monitor recovery**: Track metrics, confirm fix works
9. **Prevention**: Post-mortem, what signals caught this earlier?
10. **Document**: Share findings with team, build playbook

