# 🏪 DoorDash – Business Partner: Marketplace Health & KPI Prioritization

## Problem Statement
What KPIs would you prioritize for marketplace health (e.g., Dasher supply/demand balance, completion rate, cold food issues, AOV, retention)? How do you build an interconnected system of metrics?

---

## Q1: What does "marketplace health" really mean?

### Answer:

**Marketplace Health Definition:**

```
A healthy marketplace has:
├─ Growing demand (more orders, higher AOV)
├─ Reliable supply (fast delivery, available when needed)
├─ High quality (good food, good service)
├─ Sustainable economics (profitable for all parties)
└─ Strong retention (users return, partners stay engaged)
```

**Three Perspectives on Health:**

```
CUSTOMER PERSPECTIVE
├─ Can I get what I want when I want it?
├─ Will it arrive fast and good quality?
├─ Fair prices?
└─ Easy experience?

DASHER PERSPECTIVE
├─ Sufficient orders to earn good income?
├─ Fair pay for the work?
├─ Safe working conditions?
└─ Flexibility?

MERCHANT PERSPECTIVE
├─ Enough orders from the platform?
├─ Fair commission rates?
├─ Tools to manage the business?
└─ Support when issues arise?

DOORDASH PERSPECTIVE
├─ Growing GMV and profits?
├─ Unit economics improving?
├─ Customer lifetime value increasing?
└─ Sustainable competitive position?
```

---

## Q2: What are the CORE marketplace health KPIs?

### Answer:

**Foundational Metrics:**

```
┌──────────────────────────────────────────────────────┐
│         MARKETPLACE HEALTH METRIC HIERARCHY          │
├──────────────────────────────────────────────────────┤
│                                                      │
│ TIER 1: FUNDAMENTAL METRICS (Most Important)        │
│                                                      │
│ 1. Gross Merchandise Value (GMV)                    │
│    Definition: Total $ spent by customers           │
│    Target: $X00B annually, +15-20% YoY              │
│    Why: Primary revenue driver                      │
│                                                      │
│ 2. Order Volume (Orders/Day)                        │
│    Definition: # of orders placed daily             │
│    Target: 10M orders/day, +10% YoY                 │
│    Why: Scale indicator, demand health             │
│                                                      │
│ 3. Monthly Active Users (MAU)                       │
│    Definition: Unique users with ≥1 order/month     │
│    Target: 50M+ MAU globally                        │
│    Why: Market penetration, user base              │
│                                                      │
│ 4. Monthly Active Merchants (MAM)                   │
│    Definition: Restaurants with ≥1 order/month      │
│    Target: 1M+ merchants                            │
│    Why: Supply diversity, coverage                 │
│                                                      │
│ 5. Monthly Active Dashers (MAD)                     │
│    Definition: Drivers with ≥1 delivery/month       │
│    Target: 500K+ active drivers                     │
│    Why: Supply capacity, market coverage           │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Tier 2: Demand Health Metrics**

| Metric | Definition | Target | Why |
|--------|-----------|--------|-----|
| **Average Order Value (AOV)** | $ per order | $35-40 | Revenue per transaction |
| **Repeat Order Rate** | % of users ordering 2+ times | 55%+ | Stickiness, retention |
| **D7/D30 Retention** | % of new users returning | 35% D7, 20% D30 | User quality, habit formation |
| **Customer Satisfaction (NPS)** | Net Promoter Score | 50+ | Product satisfaction |

**Tier 3: Supply Health Metrics**

| Metric | Definition | Target | Why |
|--------|-----------|--------|-----|
| **Supply-Demand Ratio** | Dashers per order demand | 1 dasher per 5 orders | Balanced, no shortage |
| **Dasher Utilization Rate** | % time dasher is actively delivering | 60-70% | Economic viability for drivers |
| **Dasher Acceptance Rate** | % of orders accepted by dasher | 85%+ | Supply sufficiency |
| **Dasher Retention** | % of dashers returning month-over-month | 40%+ | Supply stability |

**Tier 4: Quality & Operational Metrics**

| Metric | Definition | Target | Why |
|--------|-----------|--------|-----|
| **Delivery Time** | Avg time from restaurant to customer | 30-35 mins | Customer experience |
| **On-Time Delivery %** | Orders arriving within promised time | 95%+ | Reliability |
| **Order Completion Rate** | % orders completed successfully | 99%+ | System reliability |
| **Restaurant Rating** | Avg star rating for restaurants | 4.2+ | Food quality perception |
| **Cold Food Complaints** | % of orders with quality complaints | <5% | Food freshness issue |

**Tier 5: Economics Metrics**

| Metric | Definition | Target | Why |
|--------|-----------|--------|-----|
| **Unit Economics (CAC:LTV)** | Customer acquisition cost to lifetime value ratio | 3:1+ | Profitability |
| **Contribution Margin** | (Revenue - variable costs) / Revenue | 20%+ | Business profitability |
| **Take Rate** | DoorDash revenue / GMV | 30-35% | Revenue efficiency |
| **Merchant Profitability** | Merchant revenue after DoorDash commission | 50%+ keep | Partner sustainability |

---

## Q3: How are these metrics CONNECTED?

### Answer:

**The Marketplace Health System:**

```
CUSTOMER DEMAND INDICATORS
├─ GMV growing? (+15% YoY) ✓
├─ AOV stable/growing? ($35-40) ✓
├─ Repeat rate high? (55%+) ✓
└─ Retention strong? (D30 20%+) ✓
        ↓
   DEMAND SIGNALS
        ↓
DASHER SUPPLY MUST MATCH
├─ Need more dashers? Yes
├─ Increase incentives
├─ Supply ratio at 1:5? ✓
└─ Acceptance rate 85%+? ✓
        ↓
OPERATIONAL EXECUTION
├─ Delivery time <35 mins? ✓
├─ On-time 95%+? ✓
├─ Completion rate 99%+? ✓
└─ Food quality 4.2 rating? ✓
        ↓
CUSTOMER SATISFACTION
├─ NPS 50+? ✓
├─ Repeat rate stays 55%+? ✓
└─ Low churn? ✓
        ↓
BUSINESS RESULTS
├─ CAC:LTV 3:1+? ✓
├─ Contribution margin 20%+? ✓
└─ Merchant profitability 50%+? ✓
```

**Causal Relationships:**

```
If Customer Demand ↑
├─ Need more Dasher supply ↑
├─ Must maintain Delivery time
├─ Quality shouldn't drop
└─ Then: GMV ↑, Revenue ↑, Profit ✓

If Delivery Time ↑ (Quality issue)
├─ Customer satisfaction ↓
├─ Repeat rate ↓
├─ Churn rate ↑
└─ Then: GMV ↓, Repeat rate ↓

If Dasher Supply < Demand
├─ Wait times ↑
├─ Order cancellations ↑
├─ Customer satisfaction ↓
└─ Then: GMV ↓, Lost orders

If Dasher Pay ↓ (economics pressure)
├─ Dasher churn ↑
├─ Supply ↓
├─ Wait times ↑
└─ Then: Customer satisfaction ↓, GMV ↓
```

---

## Q4: What leading indicators predict problems?

### Answer:

**Early Warning System:**

```
LEADING INDICATORS → OUTCOME INDICATORS → BUSINESS IMPACT

┌─────────────────────────────────────────────────────────┐
│ LEADING INDICATORS (Early warnings, action now)         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 1. Dasher Acceptance Rate ↓ below 85%                  │
│    → Indicates: Supply shortage coming                 │
│    → Action: Increase incentives, promotions           │
│    → Monitor: Next week's delivery times               │
│                                                         │
│ 2. Dasher Utilization Rate ↓ below 60%                 │
│    → Indicates: Too many drivers, over-supply          │
│    → Action: Reduce driver recruitment, adjust pay     │
│    → Monitor: Margin impact next month                 │
│                                                         │
│ 3. Session Bounce Rate ↑ above 25%                     │
│    → Indicates: User frustration, app issues           │
│    → Action: Investigate app performance, UX          │
│    → Monitor: Repeat rate impact                       │
│                                                         │
│ 4. Dasher Churn ↑ above 5%/month                       │
│    → Indicates: Driver dissatisfaction                 │
│    → Action: Review pay, driver support               │
│    → Monitor: Supply shortage risk                     │
│                                                         │
│ 5. Restaurant Cancellation Rate ↑                      │
│    → Indicates: Merchant system issues or overload     │
│    → Action: Support merchants, infrastructure help    │
│    → Monitor: Order completion rate                    │
│                                                         │
└─────────────────────────────────────────────────────────┘

↓ (1-2 week lag)

┌─────────────────────────────────────────────────────────┐
│ OUTCOME INDICATORS (Measures of marketplace state)      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ • Delivery Time trending                               │
│ • On-time delivery %                                   │
│ • Customer satisfaction (NPS, ratings)                 │
│ • Repeat order rate                                    │
│ • Order completion rate                                │
│                                                         │
└─────────────────────────────────────────────────────────┘

↓ (2-4 week lag)

┌─────────────────────────────────────────────────────────┐
│ BUSINESS IMPACT (Revenue, profit, growth)              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ • GMV growth rate                                       │
│ • MAU growth                                            │
│ • Customer acquisition cost (CAC)                       │
│ • Customer lifetime value (LTV)                         │
│ • Contribution margin                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Q5: How would you build a Health Scorecard/Dashboard?

### Answer:

**Three-Level Dashboard Structure:**

```
LEVEL 1: EXECUTIVE DASHBOARD (C-suite, high-level)

┌────────────────────────────────────────────────┐
│  DOORDASH MARKETPLACE HEALTH SCORECARD         │
│  Updated: Daily                                │
├────────────────────────────────────────────────┤
│                                                │
│  GMV (This Month): $8.3B ↑ 12% YoY             │
│  Orders/Day: 9.8M ↑ 8% YoY                    │
│  MAU: 48M ↑ 5% YoY                            │
│  Customer NPS: 52 ↑ from 50                    │
│                                                │
│  OVERALL HEALTH: 🟢 GREEN                     │
│  Status: Marketplace performing well          │
│                                                │
│  Key Focus Areas:                             │
│  ├─ Dasher retention slightly down (39% vs 41%)
│  ├─ Cold food complaints ↑ 2% (investigation ongoing)
│  └─ Regional disparities in delivery time    │
│                                                │
└────────────────────────────────────────────────┘
```

```
LEVEL 2: OPERATIONS DASHBOARD (Ops leaders, drill-down)

┌──────────────────────────────────────────────────────┐
│  MARKETPLACE HEALTH (DETAILED)                       │
│  Filter: City, Time Period, Segment                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  DEMAND HEALTH                                       │
│  ├─ Orders (7-day): 68.5M ↑ 8%                      │
│  ├─ AOV: $36.50 (stable)                            │
│  ├─ Repeat Order Rate: 56% ↑ 1%                     │
│  └─ D30 Retention: 21% (target 22%)                 │
│                                                      │
│  SUPPLY HEALTH                                       │
│  ├─ Active Dashers: 495K (target 500K)              │
│  ├─ Dasher Utilization: 64% (target 70%)            │
│  ├─ Acceptance Rate: 83% (below target 85%)         │
│  └─ Dasher Churn: 4.2% (target <3%)                 │
│                                                      │
│  OPERATIONAL QUALITY                                │
│  ├─ Avg Delivery Time: 33 min (target <31)          │
│  ├─ On-Time %: 92% (target 95%)                     │
│  ├─ Completion Rate: 99.2% ✓                        │
│  └─ Food Quality Rating: 4.18/5 (target 4.2)        │
│                                                      │
│  ECONOMICS                                          │
│  ├─ CAC: $4.50                                      │
│  ├─ LTV: $156 (CAC:LTV ratio 1:35) ✓               │
│  ├─ Contribution Margin: 18% (target 20%)           │
│  └─ Merchant Profitability: 48% (target 50%)        │
│                                                      │
└──────────────────────────────────────────────────────┘
```

```
LEVEL 3: DEEP-DIVE ANALYTICS (Data team, investigation)

Drill-down into any metric:
├─ Delivery Time by:
│  ├─ Geography (neighborhood, city)
│  ├─ Time of day (peak vs off-peak)
│  ├─ Restaurant type (fast food vs fine dining)
│  └─ Dasher experience level
│
├─ Supply-Demand Imbalance by:
│  ├─ Geography and hour
│  ├─ Dasher acceptance patterns
│  ├─ Incentive elasticity
│  └─ Compare to competitors
│
├─ Repeat Rate Decline by:
│  ├─ Cohort (when user joined)
│  ├─ User segment (power vs casual)
│  ├─ Restaurant type preference
│  └─ Quality issues correlation
│
└─ Retention Drivers:
   ├─ Which restaurants drive repeat?
   ├─ Which neighborhoods sticky?
   ├─ Impact of promotions on LTV
   └─ Competitor activity
```

---

## Q6: What are warning signs of marketplace degradation?

### Answer:

**Red Flags & Threshold Alerts:**

| Red Flag | Threshold | Severity | Action |
|----------|-----------|----------|--------|
| **GMV Growth** | <5% YoY | 🔴 Critical | Immediate exec review |
| **Order Completion** | <98% | 🔴 Critical | Tech investigation |
| **Delivery Time** | >40 minutes avg | 🟠 High | Supply/ops review |
| **On-Time %** | <90% | 🟠 High | Dasher/routing issue |
| **Dasher Acceptance** | <80% | 🟠 High | Increase incentives |
| **D30 Retention** | <18% | 🟡 Medium | Growth/engagement review |
| **Dasher Churn** | >6%/month | 🟡 Medium | Dasher experience review |
| **Customer NPS** | <40 | 🟡 Medium | Product/quality review |
| **Food Quality Rating** | <4.0 | 🟡 Medium | Merchant support |
| **CAC:LTV Ratio** | <2:1 | 🟠 High | Unit economics broken |

**Escalation Process:**

```
IF Metric Violates Threshold THEN

Level 1: Automated Alert
├─ Ops team notified
├─ Investigate cause
└─ Propose action within 4 hours

Level 2: Daily Stand-up
├─ Ops, Eng, Product lead discuss
├─ Root cause analysis
└─ Deploy fix or rollback within 24 hours

Level 3: Executive Review (if not resolved)
├─ VP/SVP notified
├─ Full incident review
└─ Post-mortem and prevention plan

EXAMPLE: On-time % drops from 95% to 88%
├─ Alert 1: Ops team sees this at 7am
├─ Hypothesis: Dasher pickup delays?
├─ Check: Restaurant prep time data
├─ Find: Restaurant #342 integration broken
├─ Fix: Disable that restaurant, reroute orders
├─ Monitor: On-time % recovers to 94% by 10am
└─ Root cause: DB sync issue (fix for next day)
```

---

## Q7: How would you prioritize which metrics to focus on?

### Answer:

**Metric Prioritization Matrix:**

```
IMPORTANCE vs ACTIONABILITY

High Importance, High Actionability [FOCUS HERE]
├─ Dasher Acceptance Rate ← Easy to improve (incentives)
├─ Delivery Time ← Fixable (routing, supply, positioning)
├─ On-Time % ← Actionable (operations)
├─ GMV (through promotions/marketing) ← Controllable
└─ Customer Satisfaction ← Addressable through quality

High Importance, Low Actionability [MONITOR]
├─ Market Share ← Competitive, hard to control
├─ Consumer Macro Trends ← External
├─ Economic Cycles ← External
└─ Competitor Moves ← Can only react

Low Importance, High Actionability [NICE TO HAVE]
├─ App load time ← Fixable but minor impact
├─ Merchant support ticket response ← Fixable but niche
└─ Dasher communication quality ← Fixable but secondary

Low Importance, Low Actionability [IGNORE]
├─ Random user comments ← Anecdotal
├─ Press mentions ← PR metric
└─ Competitor employee changes ← Noise
```

**Recommended Focus (80/20 Rule):**

```
20% of metrics drive 80% of impact:

1. GMV & Order Volume (revenue)
2. Delivery Time (customer experience)
3. Repeat/Retention (unit economics)
4. Dasher Supply Balance (operations)
5. Customer Satisfaction (leading indicator)

ALLOCATE:
├─ 50% effort: Fix top 5 metrics
├─ 30% effort: Monitor next 10 metrics
├─ 20% effort: Track secondary metrics for context
```

---

## Q8: How would you detect a systemic problem?

### Answer:

**Problem Detection Matrix:**

```
SCENARIO 1: Localized Problem
Problem: On-time % down in LA only
Metric Pattern:
├─ National on-time: 93% (fine)
├─ LA on-time: 82% (down from 91%)
├─ Other cities: 94-95% (stable)

Root Cause Analysis:
├─ Check LA-specific factors
├─ Weather? Traffic patterns? New restaurants?
├─ Recent ops changes in that city?

Action:
├─ Increase driver incentives in LA
├─ Optimize routing for LA traffic patterns
├─ Monitor improvement over next week
└─ Don't overreact (limit to one city)

---

SCENARIO 2: Systemic Problem
Problem: On-time % down EVERYWHERE
Metric Pattern:
├─ National on-time: 91% (down from 95%)
├─ All cities: Declining 2-3% over past week
├─ Trend: Consistent decline, not seasonal

Root Cause Analysis:
├─ NOT geography → something national
├─ Check: New app version? Algorithm change?
├─ Check: Dasher supply crisis? Acceptance rate down?
├─ Check: Restaurant delays? Integration issue?
├─ Check: Competitor activity surge? Price war?

Action:
├─ IMMEDIATE: Rollback last app/algo change
├─ Increase driver pay nationally to attract supply
├─ Review all recent changes for regression
├─ Post-mortem on what failed to catch this

---

SCENARIO 3: Market-Wide Problem
Problem: All metrics declining
Metric Pattern:
├─ GMV: -8% YoY
├─ Orders: -6% YoY
├─ Repeat rate: 50% (down from 56%)
├─ Customer satisfaction: 42 (down from 52)
├─ Dasher churn: 7% (up from 4%)

Root Cause Analysis:
├─ NOT a single fix
├─ Macro factors? Recession? Seasonality?
├─ Competitor activity? New competitor?
├─ Product issue? General experience degraded?
├─ Supply-side crisis? Dasher shortage?

Action:
├─ Urgent exec review (VP level)
├─ Segment analysis: Which customers affected?
├─ Competitor analysis: What are they doing?
├─ Product QA: Any recent changes?
├─ Strategic response: Price cuts? Marketing?
├─ Long-term: Consider market position changes
```

---

## Summary: Marketplace Health Strategy

1. **Define core metrics**: 15-20 KPIs across demand, supply, quality, economics
2. **Connect them**: Understand causal relationships and trade-offs
3. **Build hierarchy**: Different dashboards for different stakeholders
4. **Lead, not lag**: Use leading indicators to catch problems early
5. **Alert system**: Automate thresholds, escalate when violated
6. **Prioritize ruthlessly**: Focus on 20% of metrics that drive 80% of impact
7. **Investigate deeply**: Localized vs systemic problems need different actions
8. **Iterate constantly**: Monthly reviews, adjust targets based on learnings

