# 📊 DoorDash – Business Partner: Designing Dashboards & Metrics

## Problem Statement
Design metrics/dashboard for tracking [engagement, retention, or a new business initiative]. How would you set this up? What to include? How to make it actionable?

---

## Q1: What makes a dashboard EFFECTIVE vs just pretty?

### Answer:

**Good Dashboard Characteristics:**

```
❌ BAD DASHBOARD (Pretty but not useful)
├─ 50 metrics on one page (overwhelming)
├─ No context (numbers without baseline/target)
├─ No actionability (shows problem but no path to fix)
├─ No urgency indicators (everything looks the same)
├─ Outdated (refreshes only weekly)
├─ No drill-down (can't investigate deeper)
└─ Result: Executives stare, then ignore it


✅ GOOD DASHBOARD (Simple & actionable)
├─ 5-7 KEY metrics (focus on what matters)
├─ Context provided (target, trend, comparison)
├─ Clear signals (green/yellow/red status)
├─ Drill-down available (click to investigate)
├─ Real-time or near real-time (hourly refresh)
├─ Actionable recommendations (if red, suggests action)
└─ Result: Team takes action, metrics improve
```

**Design Principles:**

```
PRINCIPLE 1: HIERARCHY
├─ Executive view: Top 3-5 metrics only
├─ Manager view: 10-15 metrics by function
├─ Analyst view: Deep-dive data, drill-downs
└─ Progressive disclosure: Start simple, dig deeper if needed


PRINCIPLE 2: CONTEXT
├─ Current value (23.1K orders)
├─ Target (25K orders)
├─ Baseline (20K orders last week)
├─ Trend (↑ 15% week-over-week)
├─ vs last year (↑ 8% year-over-year)
└─ Status (🟡 Yellow, below target but improving)


PRINCIPLE 3: ACTIONABILITY
├─ Problem: "Orders down 5%"
├─ Actionable: "Orders down 5%, likely due to supply shortage
│             (dasher count -10%, acceptance rate -8%).
│             Recommendation: Increase dasher incentives 15%."


PRINCIPLE 4: VISUAL CLARITY
├─ Use color wisely (green = good, red = bad, yellow = warning)
├─ Use icons (↑ ↓ → for trends)
├─ Use sparklines (micro charts showing trend)
├─ Highlight anomalies (red flags, bold text)
└─ Avoid: Too many colors, cluttered design, hard-to-read fonts


PRINCIPLE 5: INTERACTIVITY
├─ Filters (by city, time period, user segment)
├─ Drill-down (click metric to see breakdown)
├─ Comparisons (side-by-side vs last week/year)
├─ Custom alerts (user sets thresholds)
└─ Export (download data for presentations)
```

---

## Q2: How would you design an ENGAGEMENT dashboard?

### Answer:

**Three-Level Engagement Dashboard Architecture:**

```
LEVEL 1: EXECUTIVE DASHBOARD (1-2 minute view)

┌────────────────────────────────────────────────────────┐
│        DOORDASH ENGAGEMENT SCORECARD                   │
│        As of: Jan 15, 2026 | Updated: 1 hour ago       │
├────────────────────────────────────────────────────────┤
│                                                        │
│  📊 OVERALL ENGAGEMENT HEALTH: 🟢 GREEN               │
│     Engagement Score: 72/100 ↑ +2 pts week             │
│                                                        │
│  ┌──────────────────────────────────────────────┐    │
│  │ KEY METRICS                                  │    │
│  ├──────────────────────────────────────────────┤    │
│  │                                              │    │
│  │ 📈 Order Frequency                          │    │
│  │    2.4 orders/month (Target: 2.5)           │    │
│  │    ↑ 3% week-over-week                      │    │
│  │    ↑ 8% year-over-year                      │    │
│  │    Status: 🟡 Yellow (slightly below)       │    │
│  │                                              │    │
│  │ 🔄 Repeat Order Rate                        │    │
│  │    58% (Target: 60%)                        │    │
│  │    ↑ 2% week-over-week ✓                    │    │
│  │    Status: 🟡 Yellow (monitor)              │    │
│  │                                              │    │
│  │ 📅 D30 Retention                            │    │
│  │    42% (Target: 45%)                        │    │
│  │    ↓ 1% week-over-week ⚠️                   │    │
│  │    Status: 🟠 Orange (below target)         │    │
│  │                                              │    │
│  │ ⭐ Customer Satisfaction (NPS)              │    │
│  │    52 points (Target: 55)                   │    │
│  │    ↓ 2 points week-over-week ⚠️             │    │
│  │    Status: 🟡 Yellow                        │    │
│  │                                              │    │
│  │ 💰 Average Order Value                      │    │
│  │    $36.20 (Target: $38)                     │    │
│  │    ↓ 1.2% week-over-week                    │    │
│  │    Status: 🟡 Yellow                        │    │
│  │                                              │    │
│  └──────────────────────────────────────────────┘    │
│                                                        │
│  🎯 TOP ISSUES TO ADDRESS                            │
│  1. D30 Retention below target (-3 pts)              │
│     └─ Action: Launch engagement campaign           │
│  2. NPS declining (-2 pts)                           │
│     └─ Action: Quality investigation                │
│                                                        │
│  📍 SEGMENTS PERFORMING WELL                         │
│  • Power Users: +12% engagement                       │
│  • Urban Areas: Engagement stable                     │
│                                                        │
│  ⚠️ SEGMENTS AT RISK                                 │
│  • Occasional Users: -5% engagement                  │
│  • Suburbs: -8% engagement                           │
│                                                        │
└────────────────────────────────────────────────────────┘

CLICKABLE ELEMENTS:
├─ "🟡 Yellow" status → Drill to details
├─ Metric name → Historical trend chart
├─ Segment name → Detailed segment breakdown
└─ "TOP ISSUES" → Root cause analysis
```

```
LEVEL 2: OPERATIONS DASHBOARD (Detailed view)

┌─────────────────────────────────────────────────────────┐
│          ENGAGEMENT DEEP-DIVE                           │
│ Filter: All Cities | Last 30 Days | Show All Users    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 📈 ENGAGEMENT BY USER SEGMENT                          │
│                                                         │
│ Power Users (4+ orders/month):  2.3M  ↑ 8%            │
│ ├─ Repeat rate: 92%                                    │
│ ├─ D30 retention: 78%                                  │
│ ├─ NPS: 64                                             │
│ ├─ Trend: 📈 Strong growth                             │
│ └─ Recommendation: Upsell to DashPass                  │
│                                                         │
│ Regular Users (2-3 orders/month): 5.1M  ↑ 2%          │
│ ├─ Repeat rate: 62%                                    │
│ ├─ D30 retention: 48%                                  │
│ ├─ NPS: 51                                             │
│ ├─ Trend: 📊 Stable but opportunity                    │
│ └─ Recommendation: Frequency increase campaign         │
│                                                         │
│ Occasional Users (1 order/month):  8.2M  ↓ 5%        │
│ ├─ Repeat rate: 28%                                    │
│ ├─ D30 retention: 18%                                  │
│ ├─ NPS: 38                                             │
│ ├─ Trend: 📉 Declining, needs attention               │
│ └─ Recommendation: Reactivation campaign, $5 promo    │
│                                                         │
│ At-Risk (no order 60+ days):  3.4M  (static)          │
│ ├─ Last order avg: 85 days ago                        │
│ ├─ Churn risk: HIGH                                   │
│ ├─ Recovery rate: 15%                                 │
│ └─ Recommendation: Win-back campaign, special offers  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ 📅 RETENTION COHORTS (Cohort Analysis)                 │
│                                                         │
│ Cohort    │ D7 Ret │ D14 Ret │ D30 Ret │ D60 Ret      │
│ ─────────────────────────────────────────────────────  │
│ Jan 2026  │ 58%    │  45%    │  42%    │  35%         │
│ Dec 2025  │ 61%    │  48%    │  45%    │  38%         │
│ Nov 2025  │ 62%    │  49%    │  46%    │  40%         │
│ Oct 2025  │ 60%    │  46%    │  42%    │  35%         │
│                                                         │
│ Interpretation:                                        │
│ • Recent cohorts have LOWER D30 retention (42% vs 45%)│
│ • Suggests: Product change or quality issue           │
│ • Action: Investigate what changed                    │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ 🌍 ENGAGEMENT BY GEOGRAPHY                              │
│                                                         │
│ City        │ Order Freq │ Repeat Rate │ NPS │ Status │
│ ────────────────────────────────────────────────────   │
│ New York    │ 2.8        │ 62%         │ 56  │ 🟢     │
│ LA          │ 2.5        │ 58%         │ 51  │ 🟡     │
│ Chicago     │ 2.4        │ 55%         │ 48  │ 🟡     │
│ Austin      │ 2.2        │ 52%         │ 45  │ 🟠     │
│ Denver      │ 2.1        │ 50%         │ 42  │ 🟠     │
│                                                         │
│ Insights:                                              │
│ • NYC strong, Denver struggling                        │
│ • Denver needs localized engagement push               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ 💡 DRIVERS OF ENGAGEMENT (Correlation Analysis)        │
│                                                         │
│ Factor                    │ Impact on Frequency        │
│ ──────────────────────────────────────────────────────  │
│ Number of restaurants     │ +0.12 orders per 100 rest. │
│ Avg delivery time         │ -0.08 orders per +5min     │
│ Food quality (rating)     │ +0.15 orders per +0.5 star │
│ Marketing spend           │ +0.08 orders per $1K       │
│ DashPass membership       │ +2.1 orders (vs non-member)│
│                                                         │
│ Key insight: Quality > Marketing in driving engagement │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

```
LEVEL 3: ANALYST VIEW (Deep-dive & Exploration)

Available Data:
├─ Individual user journey (order history, app sessions)
├─ Cohort analysis builder (custom cohort definitions)
├─ Funnel analysis (browse → search → order)
├─ Comparative analysis (segment A vs B)
├─ Time series analysis (trends, seasonality)
├─ Correlation analysis (what drives engagement?)
├─ SQL query interface (build custom queries)
└─ Export capabilities (download raw data)

Example Queries Available:
├─ "Show me users who ordered 2+ times in Dec but 0 times in Jan"
├─ "What's the lifetime value of users acquired via marketing?"
├─ "Which restaurants drive the highest repeat rate?"
├─ "Engagement trend by device type"
└─ "Correlation between delivery time and repeat rate"
```

---

## Q3: How would you design a RETENTION dashboard?

### Answer:

**Retention-Focused Dashboard:**

```
RETENTION DASHBOARD: "Are we keeping customers?"

┌─────────────────────────────────────────────────────────┐
│          DOORDASH RETENTION SCORECARD                   │
│          Focus: User Lifecycle & Churn                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  RETENTION HEALTH SUMMARY                              │
│  Overall Trend: 🟡 Yellow (some concerns)              │
│  D30 Retention: 42% (↓ 2% from last week)              │
│  Churn Rate: 4.8% monthly (↑ from 4.5%)                │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ RETENTION CURVES (Cohort-based)                │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ All-Time Benchmark:                           │   │
│  │ 100% ├─ Jan Cohort                            │   │
│  │      │   ├─ D1: 52%                           │   │
│  │  80% │   ├─ D7: 32%                           │   │
│  │      │   ├─ D14: 24%                          │   │
│  │  60% │   ├─ D30: 18%                          │   │
│  │      │   ├─ D60: 12%                          │   │
│  │  40% │   └─ D90: 8%                           │   │
│  │      │                                         │   │
│  │  20% ├─ Industry benchmark (competitor)       │   │
│  │      │   ├─ D1: 45%                           │   │
│  │   0% └──────────────────────────────────      │   │
│  │       D1   D7   D14  D30  D60  D90             │   │
│  │                                                │   │
│  │ Interpretation: We're ABOVE average! ✓        │   │
│  │ But declining week-over-week (concerns)       │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ CHURN DRIVERS (Why people leave)               │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ Explicit Churn (Users marked account inactive)│   │
│  │ Count: 2,340 users this month                 │   │
│  │ Top Reason: "Too expensive" (45%)             │   │
│  │ 2nd Reason: "Delivery too slow" (28%)         │   │
│  │ 3rd Reason: "Food quality" (15%)              │   │
│  │                                                │   │
│  │ Implicit Churn (60+ days no orders)           │   │
│  │ Count: 125,000 users                          │   │
│  │ Most recent order: Avg 72 days ago            │   │
│  │ Recovery rate: 8% (very low)                  │   │
│  │                                                │   │
│  │ ACTION PLAN:                                   │   │
│  │ 1. Price-sensitive users: Offer DashPass      │   │
│  │ 2. Delivery time issue: Investigate supply    │   │
│  │ 3. Quality complaints: Merchant support       │   │
│  │ 4. Implicit churn: Win-back campaign          │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ EARLY CHURN INDICATORS (Predict before leave)│   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ Low-Risk Users: 80M                           │   │
│  │ ├─ Ordering 1-2x/month, stable               │   │
│  │ └─ Recovery if churned: 2%                    │   │
│  │                                                │   │
│  │ At-Risk Users: 2.5M ⚠️                        │   │
│  │ ├─ Frequency declining (was 3→now 1/month)  │   │
│  │ ├─ NPS dropped 10+ points                     │   │
│  │ ├─ Last order: 20+ days ago                   │   │
│  │ └─ Recovery if actioned: 15%                  │   │
│  │                                                │   │
│  │ CRITICAL (Next 7 days): 150K                 │   │
│  │ ├─ No order in 45+ days                       │   │
│  │ ├─ Extremely high churn probability          │   │
│  │ └─ Recovery if re-engaged: 5% (but urgent!)  │   │
│  │                                                │   │
│  │ RECOMMENDED ACTION:                            │   │
│  │ Send targeted win-back email to 150K users    │   │
│  │ Expected recovery: 7,500 reactivations        │   │
│  │ Expected revenue: $300K                       │   │
│  │ Cost: $50K (email + offer)                    │   │
│  │ ROI: 6x                                        │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ SEGMENT RETENTION COMPARISON                  │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ DashPass Members                              │   │
│  │ ├─ D30 Retention: 68%                         │   │
│  │ ├─ Monthly Churn: 2.1%                        │   │
│  │ ├─ Reason for churn: "Cost too high" (50%)   │   │
│  │ └─ Trend: ↓ Declining (investigate pricing)   │   │
│  │                                                │   │
│  │ Non-DashPass Members                          │   │
│  │ ├─ D30 Retention: 35%                         │   │
│  │ ├─ Monthly Churn: 5.8%                        │   │
│  │ ├─ Reason for churn: "Too expensive" (42%)   │   │
│  │ └─ Trend: → Stable                             │   │
│  │                                                │   │
│  │ INSIGHT: DashPass helps, but even members    │   │
│  │ churning. Review pricing strategy.             │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ RETENTION LEVERS & IMPACT                     │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ Lever             │ Impact on D30 Retention   │   │
│  │ ──────────────────────────────────────────    │   │
│  │ More restaurants  │ +2.1% per 100 new        │   │
│  │ Faster delivery   │ +3.2% per -5 min avg     │   │
│  │ Better quality    │ +4.5% per +0.5 star      │   │
│  │ Promotions        │ +1.8% per $1 discount    │   │
│  │ DashPass discount │ +15% (large effect)      │   │
│  │ Personalized recs │ +2.3% (estimated)        │   │
│  │                                                │   │
│  │ Most Impactful: Improve Quality & DashPass   │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Q4: How would you design a NEW INITIATIVE dashboard?

### Answer:

**Framework for New Initiative Dashboard:**

```
EXAMPLE: Launching "DoorDash Health" (healthy restaurant ordering)

NEW INITIATIVE DASHBOARD DESIGN

┌─────────────────────────────────────────────────────────┐
│        DOORDASH HEALTH - LAUNCH DASHBOARD               │
│        Initiative Launch Date: Jan 2026                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  INITIATIVE GOALS                                      │
│  • Capture health-conscious customer segment           │
│  • Target: 5M orders by EOY (Phase 1)                  │
│  • Revenue target: $50M GMV in first 6 months          │
│  • Build competitive advantage vs Uber Eats            │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ GO-NO-GO CRITERIA (Decision gates)             │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ ✅ LAUNCH SUCCESS (Month 1)                    │   │
│  │ ├─ 500K downloads                             │   │
│  │ ├─ 15%+ conversion to first order             │   │
│  │ ├─ 4.2+ rating                                │   │
│  │ ├─ 150+ restaurants onboarded                 │   │
│  │ └─ Economics: ≥15% margin                     │   │
│  │                                                │   │
│  │ 🟡 CONCERN THRESHOLDS                         │   │
│  │ ├─ <200K downloads → Increase marketing       │   │
│  │ ├─ <10% conversion → Investigate UX          │   │
│  │ ├─ <4.0 rating → Quality issue               │   │
│  │ ├─ <100 restaurants → Recruitment issue      │   │
│  │ └─ <12% margin → Pricing issue               │   │
│  │                                                │   │
│  │ 🔴 KILL CRITERIA (Month 1 or 2)               │   │
│  │ ├─ <100K downloads                           │   │
│  │ ├─ Conversion <8%                             │   │
│  │ ├─ Margin <10%                                │   │
│  │ └─ Retention D7 <20%                          │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ PHASE 1: SOFT LAUNCH (This Dashboard)         │   │
│  ├────────────────────────────────────────────────┤   │
│  │ Status: 🔵 LIVE (Week 2 of launch)            │   │
│  │                                                │   │
│  │ METRICS                     │ TARGET │ ACTUAL  │   │
│  │ ─────────────────────────────────────────────  │   │
│  │ Downloads                   │ 500K   │ 350K ⚠️  │   │
│  │ D1 Retention (users)        │ 55%    │ 52% 🟡   │   │
│  │ First Order Conversion      │ 15%    │ 13% 🟡   │   │
│  │ First Order AOV             │ $32    │ $28 🟡   │   │
│  │ Restaurant Count            │ 150    │ 128 ⚠️   │   │
│  │ Avg Rating                  │ 4.2    │ 4.18 ✓   │   │
│  │ Contribution Margin         │ 15%    │ 14% 🟡   │   │
│  │ GMV (cumulative)            │ $5M    │ $3.5M ⚠️  │   │
│  │ Repeat Order Rate           │ 25%    │ 22% 🟡   │   │
│  │                                                │   │
│  │ ASSESSMENT: 🟡 YELLOW                         │   │
│  │ Below target on most metrics, but early days  │   │
│  │                                                │   │
│  │ ACTIONS BEING TAKEN:                          │   │
│  │ 1. Increase marketing spend by 30%            │   │
│  │ 2. Improve app UX (checkout flow analysis)    │   │
│  │ 3. Aggressive restaurant recruitment          │   │
│  │ 4. Price optimization (AOV seems low)         │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ COMPETITIVE POSITIONING                       │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ Our Position: 128 restaurants, 350K users    │   │
│  │ Competitor A: 85 restaurants, 250K users      │   │
│  │ Competitor B: 200 restaurants, 600K users     │   │
│  │                                                │   │
│  │ We're: 2nd in restaurants, 2nd in users      │   │
│  │ Performance: Better than Comp A, catching up │   │
│  │             to Comp B (in progress)           │   │
│  │                                                │   │
│  │ Differentiation:                              │   │
│  │ ✓ Better ratings (4.18 vs 3.95 Comp A)       │   │
│  │ ✓ Faster delivery time in our restaurants     │   │
│  │ ⚠️ Lower AOV (need to improve)                │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ CUSTOMER FEEDBACK & SENTIMENT                 │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ App Store Rating: 4.18/5 (118 reviews)        │   │
│  │ Positive Comments (themes):                   │   │
│  │ ├─ "Love the healthy options" (45%)           │   │
│  │ ├─ "Easy to filter by nutrition" (30%)        │   │
│  │ └─ "Nutritional info really helpful" (25%)    │   │
│  │                                                │   │
│  │ Negative Comments (themes):                   │   │
│  │ ├─ "Selection limited vs main app" (40%)      │   │
│  │ ├─ "Some restaurants don't have all items" (30%)
│  │ └─ "Prices higher than main app" (30%)        │   │
│  │                                                │   │
│  │ Recommendation: Expand restaurant partnerships│   │
│  │                Add more items to menus        │   │
│  │                Review pricing strategy        │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ ROADMAP & MILESTONES                          │   │
│  ├────────────────────────────────────────────────┤   │
│  │                                                │   │
│  │ Phase 1 (Jan-Feb): Soft Launch, 5 cities     │   │
│  │ Status: 🟡 In Progress (Week 2)              │   │
│  │ Next milestone: 1M downloads (est: Feb 1)    │   │
│  │                                                │   │
│  │ Phase 2 (Mar-Apr): National Launch           │   │
│  │ Status: 📅 Pending                            │   │
│  │ Gate: Phase 1 metrics hit targets             │   │
│  │                                                │   │
│  │ Phase 3 (May+): Optimization & Features      │   │
│  │ Status: 📅 Pending                            │   │
│  │ Focus: Personalization, loyalty, expansion    │   │
│  │                                                │   │
│  └────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Q5: How do you decide which metrics to dashboard vs just monitor?

### Answer:

**Metric Classification Matrix:**

```
DASHBOARD (High visibility) vs MONITOR (Background tracking)

┌─────────────────────────────────────────────────────┐
│                                                     │
│ HIGH IMPACT + VOLATILE                             │
│ → DASHBOARD (central focus)                        │
│                                                     │
│ Examples:                                          │
│ • Orders/day (core business metric)               │
│ • Delivery time (customer experience)             │
│ • Dasher supply (operational critical)            │
│ • Customer satisfaction (retention driver)        │
│ • GMV (revenue)                                   │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│ HIGH IMPACT + STABLE                              │
│ → MONITOR (track for anomalies)                   │
│                                                     │
│ Examples:                                          │
│ • Repeat order rate (stable indicator)            │
│ • Merchant count (slow moving)                    │
│ • App crash rate (usually good)                   │
│ • Payment success rate (stable)                   │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│ LOW IMPACT + VOLATILE                             │
│ → MONITOR (alert if anomaly)                      │
│                                                     │
│ Examples:                                          │
│ • A/B test results (exploratory)                 │
│ • New feature adoption (early stage)              │
│ • Geographic micro-trends                        │
│ • Competitor pricing (for intelligence)           │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│ LOW IMPACT + STABLE                               │
│ → IGNORE (not worth tracking)                     │
│                                                     │
│ Examples:                                          │
│ • Page load time (already optimized)              │
│ • Support ticket volume (not strategic)           │
│ • Niche features (rarely used)                    │
│                                                     │
└─────────────────────────────────────────────────────┘

DOORDASH DASHBOARD PRIORITIZATION:

TIER 1 (EXECUTIVE DASHBOARD - 5 metrics):
├─ GMV (revenue)
├─ Orders/Day (scale)
├─ Delivery Time (experience)
├─ Customer Satisfaction (leading indicator)
└─ Marketplace Health Score (composite)

TIER 2 (FUNCTIONAL DASHBOARDS - 10-15 metrics each):
├─ Demand team: User acquisition, retention, repeat rate
├─ Supply team: Dasher supply, acceptance rates, utilization
├─ Ops team: Delivery time, on-time %, completion rate
├─ Product team: Feature adoption, engagement, NPS
└─ Finance team: Revenue, margin, CAC, LTV

TIER 3 (MONITORING - 30+ metrics):
├─ Alerts for anomalies
├─ Weekly/monthly reviews
├─ Trend analysis
└─ Support for investigations
```

---

## Q6: What makes a dashboard ACTIONABLE?

### Answer:

**From Metric to Action:**

```
GOOD DASHBOARD FLOW:

Problem Identified
        ↓
┌─────────────────────────────────────────┐
│ METRIC SHOWS ISSUE                      │
│ "D30 Retention dropped to 42% (was 45%)"│
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ CONTEXT PROVIDED                        │
│ • Threshold: 45% target                 │
│ • Trend: ↓ 3% week-over-week            │
│ • Segment affected: "Casual users (-5%)"│
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ ROOT CAUSE SUGGESTED                    │
│ • Delivery time up 5 min (quality issue)│
│ • NPS down 3 points (satisfaction)      │
│ • Cold food complaints +12%             │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ ACTION RECOMMENDED                      │
│ 1. Investigate quality with ops team    │
│ 2. Launch "quality improvement" sprint  │
│ 3. Contact top 50K at-risk users        │
│ 4. Expected impact: +2 point lift       │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ LINK TO OWNER                           │
│ Click → Escalate to Head of Ops         │
│ Schedule meeting for today 2pm          │
└─────────────────────────────────────────┘


EXAMPLE OF ACTIONABLE DASHBOARD ELEMENT:

Before (Not Actionable):
┌──────────────────────┐
│ D30 Retention: 42%   │
│ Target: 45%          │
│ Status: ⚠️            │
└──────────────────────┘

After (Actionable):
┌────────────────────────────────────────────────┐
│ D30 RETENTION: 42% 🔴                         │
│ ─────────────────────────────────────────────  │
│ Target: 45% | Gap: -3 points                   │
│                                                │
│ Trend:      ↓ -3% week-over-week              │
│ Forecast:   39% in 2 weeks if no action       │
│                                                │
│ Root Cause Hypothesis:                        │
│ └─ Quality issues (delivery time ↑, NPS ↓)    │
│                                                │
│ Most Affected Segments:                       │
│ └─ Casual Users: -5%                          │
│ └─ Android users: -4%                         │
│ └─ Suburbs: -3%                               │
│                                                │
│ Recommended Actions:                          │
│ ┌─ [URGENT] Quality investigation with ops    │
│ ├─ Send win-back email to 500K users          │
│ ├─ Launch "$10 off" promo for lapsed users    │
│ └─ Review restaurant quality metrics          │
│                                                │
│ Expected Impact (if all implemented):         │
│ └─ +2-3 point lift in D30 retention           │
│                                                │
│ 📅 NEXT REVIEW: Jan 18 (in 3 days)            │
│ 👤 OWNER: VP Growth                           │
│ 🔗 [Schedule Meeting]  [View Details]         │
│                                                │
└────────────────────────────────────────────────┘
```

---

## Summary: Dashboard Best Practices

1. **Start simple**: 5-7 key metrics, not 50
2. **Provide context**: Current, target, trend, baseline
3. **Signal urgency**: Color coding (green/yellow/red)
4. **Enable drill-down**: Click to investigate deeper
5. **Suggest actions**: "If metric is red, try this"
6. **Assign owners**: Clear who's responsible
7. **Refresh frequently**: Real-time or hourly beats daily
8. **Segment data**: By geography, user type, time
9. **Show causality**: Link metrics to root causes
10. **Measure dashboard value**: Is it driving decisions?

