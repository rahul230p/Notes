# 🚴 DoorDash Bike Delivery Expansion - Business Partner Use Case

## Problem Statement
DoorDash is expanding delivery options by introducing **bike delivery** in addition to traditional car/Dasher delivery. How would you approach measuring success, understanding the impact, and making data-driven decisions about this expansion?

---

## 🎯 Context: Why Bikes?

**Business drivers:**
- Cost efficiency: Bikes have lower operational costs than cars
- Urban penetration: Better for dense urban areas (NYC, SF, LA)
- Sustainability: Environmental benefits (marketing angle)
- Speed: Bikes can navigate congestion, potentially faster in cities
- New market: Can operate in areas where car delivery is too expensive

**Challenges:**
- Distance limits: Bikes can't deliver 10 miles away
- Weather: Rain, snow, extreme temperatures problematic
- Capacity: Can't carry as much (some orders too heavy)
- Safety: Cyclist safety concerns
- Coverage: Can't serve all neighborhoods equally

---

## 📊 Phase 1: Soft Launch (Pilot Phase)

### Phase 1 Success Metrics (What We Measure)

**Primary Metrics:**
```
1. ADOPTION METRICS
   ├─ Orders via bike: # and % of total orders
   ├─ Bike order volume: Daily trend
   ├─ Geographic coverage: # neighborhoods with bike option
   └─ Target: 10K bike orders/day in pilot cities by week 12

2. DELIVERY PERFORMANCE
   ├─ Delivery time (bikes vs cars)
   │  └─ Hypothesis: Bikes might be faster (10-15% faster in dense areas)
   │  └─ Target: <30 min avg (bikes), <35 min (cars)
   ├─ On-time delivery %
   ├─ Completion rate (% of bike orders delivered)
   └─ Target: 95% on-time, 99% completion

3. QUALITY METRICS
   ├─ Customer satisfaction (NPS, ratings)
   ├─ Cold food complaints (% of orders)
   ├─ Damaged goods complaints
   ├─ Dasher (cyclist) rating
   └─ Target: 4.2+ rating, <5% cold food complaints

4. SUPPLY METRICS
   ├─ Cyclist supply vs demand
   ├─ Acceptance rate (% of orders accepted by cyclists)
   ├─ Utilization (% time cyclists are active)
   ├─ Supply/demand ratio (cyclists per order demand)
   └─ Target: 85%+ acceptance, 60-70% utilization

5. ECONOMICS
   ├─ Cost per delivery
   ├─ Cost comparison: Bike vs Car
   ├─ Contribution margin per bike order
   ├─ Unit economics: CAC, LTV
   └─ Target: 20% cost reduction vs cars, 15%+ margin

6. CUSTOMER IMPACT
   ├─ New customer acquisition (via bike-only option)
   ├─ Order frequency for bike users
   ├─ AOV (Average Order Value) for bike orders
   ├─ Repeat rate for bike customers
   └─ Target: Attract price-sensitive segment, 40% repeat rate

7. SAFETY & COMPLIANCE
   ├─ Cyclist accidents/injuries
   ├─ Customer-cyclist incidents
   ├─ Insurance claims
   ├─ Regulatory compliance issues
   └─ Target: <0.1% incident rate, 100% compliance
```

---

## 🔍 Deep-Dive Analysis Questions

### Q1: What data would you need to understand if bike delivery is working?

**Answer:**

```
DATA SOURCES:

1. ORDER-LEVEL DATA
   ├─ Order ID, timestamp, location (pickup & delivery)
   ├─ Order value ($ amount)
   ├─ Delivery mode selected (bike vs car)
   ├─ Actual delivery mode (what was used)
   ├─ Actual delivery time
   ├─ On-time indicator (delivered by ETA or not)
   ├─ Customer rating, feedback
   └─ Completion status (delivered/cancelled)

2. CYCLIST-LEVEL DATA
   ├─ Cyclist ID, sign-up date
   ├─ Assignments (# orders offered per shift)
   ├─ Acceptances (% orders accepted)
   ├─ Completion rate (% orders completed)
   ├─ Earnings (pay per order, hourly, incentives)
   ├─ Rating, feedback, complaints
   ├─ Shift duration, hours worked
   ├─ Accidents, incidents
   ├─ Equipment info (bike type, safety gear)
   └─ Experience level (new vs veteran)

3. CUSTOMER-LEVEL DATA
   ├─ Customer ID, signup date
   ├─ Previous orders (history)
   ├─ Bike orders placed (count, frequency)
   ├─ Car orders placed (count, frequency)
   ├─ Total spend (LTV)
   ├─ Churn indicator (30+ days inactive)
   ├─ Ratings given
   ├─ Customer segment (price-sensitive? urban?)
   └─ Location (distance to bike hubs)

4. GEOGRAPHIC DATA
   ├─ Neighborhood/zip code
   ├─ Population density
   ├─ Bike infrastructure (lanes, traffic)
   ├─ Weather data (rainfall, temperature)
   ├─ Bike hub locations
   ├─ Competitor activity
   └─ Restaurant density

5. OPERATIONAL DATA
   ├─ Bike availability (# of bikes, maintenance)
   ├─ Hub operations (opening hours, staffing)
   ├─ Weather conditions
   ├─ Traffic patterns
   ├─ System availability (app, payment)
   └─ Incidents, complaints by type

TRANSFORMATIONS/FEATURES:

├─ Segment orders:
│  ├─ By distance (0-2 mi, 2-5 mi, 5+ mi)
│  ├─ By time of day (peak vs off-peak)
│  ├─ By geography (bike-friendly vs not)
│  └─ By order type (groceries vs restaurants)
│
├─ Segment customers:
│  ├─ By acquisition source (bike-specific promo? general?)
│  ├─ By price sensitivity (frequent promo users?)
│  ├─ By geography (urban density)
│  └─ By repeat behavior
│
├─ Calculate KPIs:
│  ├─ Delivery time by mode
│  ├─ On-time % by distance
│  ├─ Cyclist utilization %
│  ├─ Customer repeat rate
│  ├─ LTV by mode
│  └─ Margin by mode
```

---

### Q2: How would you set up an experiment to measure bike delivery impact?

**Answer:**

```
EXPERIMENT DESIGN: Bike vs Car Delivery

HYPOTHESIS:
"Bike delivery will achieve same customer satisfaction as car delivery
while reducing cost by 20%, enabling us to serve price-sensitive customers
profitably."

PRIMARY METRIC:
├─ Delivery time (hypothesis: bikes 10-15% faster in dense areas)
├─ Cost per delivery (hypothesis: bikes 20% cheaper)
├─ Customer satisfaction (hypothesis: no significant difference)
└─ Repeat order rate (hypothesis: no significant difference)

SAMPLE DESIGN:
├─ User-level randomization (NOT order-level, to avoid cannibalization)
├─ 50% users see bike option, 50% see car only
├─ Only for eligible orders (0-3 miles, non-heavy)
├─ 5 pilot cities: NYC, SF, LA, Chicago, Boston
├─ Sample size: 100K users per arm (500K total)
├─ Duration: 8 weeks

WHAT WE'RE COMPARING:
├─ Group A (Control): Only car/Dasher option available
├─ Group B (Treatment): Bike + car options available
├─ Within Group B: Those who chose bike vs car

GUARDRAILS:
├─ Customer satisfaction (NPS) doesn't drop >5 points
├─ On-time delivery stays >92%
├─ Completion rate stays >98%
├─ No increase in incidents/complaints
├─ Business doesn't lose customers in test

SECONDARY METRICS:
├─ Segment analysis:
│  ├─ By distance (0-1 mi, 1-2 mi, 2-3 mi)
│  ├─ By time of day (peak vs off-peak)
│  ├─ By geography (bike-friendly areas vs not)
│  ├─ By order type (small/light vs large/heavy)
│  └─ By customer segment (new vs power users)

ANALYSIS:
├─ Primary outcomes with 95% confidence
├─ Subgroup heterogeneity (who benefits most from bikes?)
├─ Incremental impacts (bike orders don't cannibalize car orders)
├─ Long-term retention (do bike users stick around?)
└─ Cost-benefit analysis

GO/NO-GO DECISION:
├─ If delivery time worse AND cost not better → Kill
├─ If satisfaction drops significantly → Adjust and retest
├─ If cost good but satisfaction bad → Bike-only discount tier
├─ If both good → Scale gradually to new cities
```

---

### Q3: What would you measure to diagnose problems if bikes aren't working?

**Answer:**

```
DIAGNOSTIC FRAMEWORK: Why Might Bikes Fail?

ISSUE 1: ADOPTION PROBLEM (Nobody ordering bikes)

Diagnosis:
├─ Is the bike option visible to customers? (UI issue?)
├─ Is the bike option too expensive? (pricing problem?)
├─ Are bikes only available for small geographic area?
├─ Do customers not trust bike delivery?
└─ Are all orders too heavy for bikes?

Investigation:
├─ Traffic analysis: % of customers viewing bike option
├─ Conversion funnel: View → Select → Complete
├─ Pricing comparison: Bike vs car delivery fee
├─ Geographic analysis: Bike availability map
├─ Customer feedback: Why don't users choose bikes?

Fix:
├─ Make bikes default for short distances
├─ Offer discount for first bike order
├─ Expand geographic coverage
├─ Better marketing about bikes
└─ Adjust pricing strategy


ISSUE 2: DELIVERY PERFORMANCE PROBLEM (Bikes too slow)

Diagnosis:
├─ Are delivery times worse than cars?
├─ Are on-time rates dropping?
├─ Is weather a factor?
├─ Are cyclists taking wrong routes?
├─ Are bikes not suitable for all neighborhoods?

Investigation:
├─ Delivery time by distance tier
├─ On-time % by time of day
├─ Performance by weather conditions
├─ Route efficiency analysis
├─ Geographic heat map: Where do bikes struggle?

Fix:
├─ Restrict bikes to short distances (<2 miles)
├─ Only deploy during good weather
├─ Invest in better routing/navigation
├─ Cyclist training program
├─ Better bike infrastructure (e-bikes in hills)


ISSUE 3: SUPPLY PROBLEM (Not enough cyclists)

Diagnosis:
├─ Is supply/demand ratio too high?
├─ Are acceptance rates too low?
├─ Are cyclists churning?
├─ Are earnings too low?
├─ Are cyclists getting hurt?

Investigation:
├─ Cyclist supply vs demand trend
├─ Acceptance rate by shift, weather, area
├─ Cyclist retention: % returning weekly
├─ Earnings per cyclist per shift
├─ Incident reports, feedback

Fix:
├─ Increase cyclist incentives
├─ Improve safety equipment/training
├─ Flexible scheduling
├─ Health insurance / benefits
├─ Better working conditions


ISSUE 4: QUALITY PROBLEM (Customer satisfaction low)

Diagnosis:
├─ Are ratings lower for bike orders?
├─ What types of complaints?
│  ├─ Cold food?
│  ├─ Damaged goods?
│  ├─ Rude cyclist?
│  ├─ Wrong order?
│  └─ Never arrived?
├─ Is it specific to certain orders/neighborhoods?

Investigation:
├─ NPS by mode (bikes vs cars)
├─ Complaint analysis by category
├─ Correlation with distance, time of day, weather
├─ Cyclist rating distribution
├─ Customer feedback themes

Fix:
├─ Better insulation/containers for food
├─ Weight limit enforcement (don't assign too-heavy orders)
├─ Cyclist training on customer service
├─ Cyclist background checks
├─ Geographic restrictions (only bike-friendly areas)


ISSUE 5: ECONOMICS PROBLEM (Bikes not profitable)

Diagnosis:
├─ Is cost per delivery higher than expected?
├─ Is margin too low?
├─ What drives the cost?
│  ├─ Cyclist pay?
│  ├─ Bike maintenance?
│  ├─ Pickup/return overhead?
│  ├─ Customer service costs (complaints)?
│  └─ Marketing/acquisition?

Investigation:
├─ Cost breakdown: Each component
├─ Cost per delivery by distance
├─ Utilization rate (how many hours do bikes sit idle?)
├─ Customer LTV for bike orders
├─ Repeat rate (are they profitable long-term?)

Fix:
├─ Optimize cyclist pay model
├─ Increase bike utilization
├─ Only serve profitable distances
├─ Increase customer lifetime value (discounts for loyalty)
└─ Volume-based pricing (cheaper at scale)


ISSUE 6: SAFETY PROBLEM (Cyclists getting hurt)

Diagnosis:
├─ Incident rate trending up?
├─ What types of incidents?
│  ├─ Traffic accidents?
│  ├─ Falls from bike?
│  ├─ Theft?
│  ├─ Harassment?
│  └─ Overuse injuries?
├─ Specific geographies or times more dangerous?

Investigation:
├─ Incident reporting: Rate, severity
├─ Correlation with traffic patterns
├─ Equipment adequacy check
├─ Cyclist training effectiveness
├─ Insurance claim analysis

Fix:
├─ Mandatory safety equipment
├─ Better training program
├─ Restricted routes (avoid dangerous roads)
├─ Insurance/medical coverage
├─ Weather restrictions
└─ Cyclist + customer communication improvements
```

---

## 📈 Phase 2: Scale Decision (Go/No-Go Gates)

### Week 12 Decision: Should We Expand Bikes?

**GO Decision If:**
```
✅ Primary metrics hit targets:
   ├─ Delivery time: <30 min (vs <35 min cars)
   ├─ Cost per delivery: 20% lower than cars
   ├─ Customer satisfaction: 4.2+ rating (no diff from cars)
   ├─ On-time delivery: >92%
   ├─ Completion rate: >98%
   └─ Cyclist acceptance rate: >80%

✅ Secondary analysis looks good:
   ├─ Bike orders don't cannibalize car orders
   ├─ New customer acquisition from bike option
   ├─ Repeat rate for bike customers: >35%
   ├─ LTV for bike customers positive
   └─ No safety issues

✅ Operational readiness:
   ├─ Supply stable and scalable
   ├─ Customer support can handle volume
   ├─ No regulatory issues
   └─ Infrastructure ready for expansion
```

**NO-GO Decision If:**
```
❌ One or more critical failures:
   ├─ Delivery times worse than cars
   ├─ Cost per delivery not 15%+ cheaper
   ├─ Customer satisfaction significantly lower
   ├─ On-time % below 90%
   ├─ Completion rate below 97%
   └─ Safety issues or regulatory problems

→ Action: Pause, analyze root cause, iterate
→ Consider: Bikes only for certain distances/areas/times
```

**CONDITIONAL GO If:**
```
⚠️ Mixed results:
├─ Bikes work great for 0-1.5 miles but not 1.5-3 miles
│  → Scale for short distances only
│
├─ Bikes work well Mon-Fri but not weekends
│  → Deploy only weekdays
│
├─ Bikes work in Manhattan but not suburbs
│  → Geographic restriction (dense urban only)
│
├─ Bikes great for restaurants but bad for grocery
│  → Order type restrictions
│
└─ Cost savings offset by low repeat rate
   → Adjust pricing/promotions for customer LTV

→ Action: Scale selectively to most favorable segments
```

---

## 🚴 Phase 2: Scaled Expansion (Months 4-12)

### Expansion Strategy

**Month 4-6: Regional Expansion**
```
├─ Expand to 10 more cities
├─ Focus on dense urban areas (population >1M, bike-friendly)
├─ Measure: Same KPIs as pilot
├─ Decision at Month 6: Continue or adjust strategy
└─ Target: 150K bike orders/day
```

**Month 7-9: Optimization Phase**
```
├─ Refine based on learnings from 15 cities
├─ A/B test:
│  ├─ Pricing models (surge vs fixed)
│  ├─ Cyclist incentives (per-order vs hourly)
│  ├─ Marketing messages
│  └─ Feature combinations (bike + car combo?)
├─ Measure: Incremental improvements
└─ Target: 300K bike orders/day
```

**Month 10-12: Strategic Expansion**
```
├─ Decide on long-term vision
├─ Options:
│  ├─ Full national rollout (bikes in 50+ cities)
│  ├─ Premium urban-only service (bikes in 20 dense cities)
│  ├─ Weather-dependent (seasonal in cold climates)
│  └─ Partner model (local bike delivery companies)
│
└─ Measure: Business impact (revenue, market share, profit)
```

---

## 📊 Key KPIs for Bike Delivery (Dashboard)

### Executive Dashboard

```
BIKE DELIVERY SCORECARD

Orders & Volume:
├─ Bike orders (daily): 50K ↑ 25% WoW
├─ Bike % of total orders: 5% ↑ 1pp
├─ Bike cities: 15 (expanding)
└─ Cumulative bike orders (YTD): 2.5M

Performance:
├─ Avg delivery time (bikes): 28 min (target: <30)
├─ On-time delivery %: 93% (target: >92%)
├─ Completion rate: 99% (target: >98%)
└─ Customer rating: 4.25/5 (target: >4.2)

Supply:
├─ Active cyclists: 3.2K
├─ Utilization rate: 65% (target: 60-70%)
├─ Acceptance rate: 82% (target: >80%)
└─ Cyclist satisfaction: 4.1/5

Economics:
├─ Cost per bike delivery: $3.50 (vs $4.50 cars)
├─ Contribution margin: 18% (target: >15%)
├─ Bike revenue (YTD): $125M
└─ Bike profitability: Positive ✓

Customer:
├─ Bike customer repeat rate: 38% (target: >35%)
├─ Bike customer LTV: $280 (vs $240 car-only)
├─ Net new customers from bikes: 500K (YTD)
└─ Churn rate (bike users): 3.2% (vs 3.8% overall)

OVERALL: 🟢 GREEN - On track for scale
```

---

## ⚠️ Risk Analysis

### Potential Risks & Mitigations

```
RISK 1: Cyclist Safety
├─ Impact: High (liability, retention, reputation)
├─ Likelihood: Medium (weather, traffic, fatigue)
├─ Mitigation:
│  ├─ Comprehensive insurance + medical coverage
│  ├─ Mandatory safety training + equipment
│  ├─ Weather-based restrictions
│  ├─ Route optimization (avoid dangerous roads)
│  └─ Real-time panic button, rider support

RISK 2: Customer Satisfaction (Quality)
├─ Impact: High (repeat rate, market perception)
├─ Likelihood: Medium (capacity, weather, distance)
├─ Mitigation:
│  ├─ Weight/size restrictions for orders
│  ├─ Insulated delivery containers
│  ├─ Only short-distance orders
│  ├─ Weather-based service pausing
│  └─ Proactive communication about ETA

RISK 3: Supply/Demand Mismatch
├─ Impact: Medium (service reliability)
├─ Likelihood: High (new supply model)
├─ Mitigation:
│  ├─ Dynamic incentive pricing
│  ├─ Flexible scheduling, gig model
│  ├─ Partner with local bike courier companies
│  └─ Gradual rollout with capacity planning

RISK 4: Regulatory/Legal Issues
├─ Impact: High (could halt program)
├─ Likelihood: Low-Medium (varies by city)
├─ Mitigation:
│  ├─ Proactive legal review by city
│  ├─ Lobbying for favorable regulations
│  ├─ Partnership with city governments
│  ├─ Insurance and compliance programs
│  └─ Transparent operations & reporting

RISK 5: Cannibalization (Bike steals car order)
├─ Impact: Medium (economics, customer mix)
├─ Likelihood: Medium (depends on pricing)
├─ Mitigation:
│  ├─ Segment orders (restricted set for bikes)
│  ├─ Pricing strategy (bike discount for price-sensitive)
│  ├─ Measure incremental customer value
│  └─ Only expand if not cannibalizing

RISK 6: Weather Dependency
├─ Impact: Medium (seasonality, unpredictability)
├─ Likelihood: High (rain, snow, extreme temps)
├─ Mitigation:
│  ├─ Weather-based service pausing
│  ├─ Geographic restrictions (avoid snowy cities)
│  ├─ E-bikes for hills
│  ├─ Rotating to car backup during bad weather
│  └─ Clear customer communication

RISK 7: Competitor Response
├─ Impact: Medium (market share)
├─ Likelihood: High (copycat threat)
├─ Mitigation:
│  ├─ Build moat through experience/network
│  ├─ Partner with local bike companies first
│  ├─ Community/sustainability narrative
│  ├─ Operational efficiency advantage
│  └─ Brand first-mover advantage
```

---

## 💡 Interview Questions for BP Round

**If interviewer asks about this scenario:**

### Q: "Walk us through how you'd measure success for bike delivery"

**Answer Framework:**
```
1. CLARIFY (1 min)
   "Before I design metrics, let me understand:
   - Is this pilot or full rollout?
   - Geographic focus? (dense urban vs all areas?)
   - Customer segment? (price-sensitive? eco-conscious?)
   - Success definition? (profitability? market share? sustainability?)"

2. DEFINE TIERS (2 min)
   "I'd track metrics in these tiers:
   - Tier 1: Volume + Profitability (business fundamentals)
   - Tier 2: Quality + Experience (customer + cyclist)
   - Tier 3: Strategic (market position, future potential)"

3. SPECIFIC METRICS (2 min)
   "Key metrics I'd focus on:
   - Delivery time (bikes vs cars) - proxy for quality
   - Cost per delivery - proxy for profitability
   - Customer satisfaction - proxy for retention
   - Cyclist supply/utilization - proxy for scalability
   - Repeat order rate - proxy for LTV"

4. MEASUREMENT APPROACH (1 min)
   "I'd:
   - Set clear targets upfront (go/no-go gates)
   - Segment analysis (what works for bikes vs cars?)
   - A/B test rigorously (bikes vs cars, not just bikes)
   - Monthly reviews with decision points"

5. BUSINESS IMPACT (1 min)
   "Success metrics should ladder to:
   - Revenue impact (new customers, order frequency)
   - Cost impact (lower delivery costs)
   - Profit impact (unit economics)
   - Strategic impact (market differentiation)"
```

### Q: "What could go wrong with bike delivery?"

**Answer Framework:**
```
"Multiple things could fail, and I'd have a diagnostic plan:

1. ADOPTION PROBLEM
   "Nobody orders bikes"
   → Diagnosis: Check if visible, priced right, too limited
   → Fix: Marketing, pricing, geographic expansion

2. QUALITY PROBLEM
   "Bike orders have lower ratings"
   → Diagnosis: Is it distance? capacity? weather?
   → Fix: Restrict to short distances, light orders, good weather

3. SUPPLY PROBLEM
   "Not enough cyclists"
   → Diagnosis: Low pay? Safety concerns? Weather?
   → Fix: Better incentives, safety program, flexibility

4. SAFETY PROBLEM
   "Cyclists getting hurt"
   → Diagnosis: Traffic patterns? Equipment? Training?
   → Fix: Route optimization, safety program, restrictions

5. ECONOMICS PROBLEM
   "Not profitable"
   → Diagnosis: Cost too high? LTV too low?
   → Fix: Operational efficiency or pricing changes

For each, I'd have:
- Leading indicators to catch early
- Diagnostic framework to find root cause
- Clear decision point (continue, iterate, or kill)
"
```

### Q: "How would you structure the data infrastructure for bikes?"

**Answer Framework:**
```
"I'd design tables to track:

1. BIKE ORDERS TABLE
   ├─ order_id, cyclist_id, distance, time_taken
   ├─ customer_id, repeat_indicator, rating
   ├─ cost_breakdown, earnings
   └─ weather conditions, day/time

2. CYCLIST TABLE
   ├─ cyclist_id, shift_date, hours_worked, orders_completed
   ├─ earnings, acceptance_rate, ratings
   ├─ safety_incidents, equipment_type
   └─ supply/demand at the time

3. CUSTOMER TABLE
   ├─ customer_id, bike_vs_car_preference
   ├─ repeat_rate (bike), repeat_rate (car)
   ├─ LTV by mode, churn indicator
   └─ segment (price-sensitive, eco-conscious, etc)

4. GEOGRAPHY TABLE
   ├─ neighborhood_id, population_density
   ├─ bike_infrastructure_score, safety_score
   ├─ weather_patterns, traffic_patterns
   └─ competitor activity

Reporting:
- Daily operational dashboards
- Weekly performance by city
- Monthly cohort analysis (do bike customers stick?)
- Quarterly strategic reviews (scale? iterate? kill?)
"
```

---

## 🎯 Summary

**Bike Delivery Expansion = Perfect BP Interview Scenario Because:**

✅ **Ambiguous problem** - How do you measure success for a NEW delivery mode?  
✅ **Cross-functional** - Needs insights from ops, product, finance, legal, sustainability  
✅ **Data-driven** - Lots of data to collect, analyze, and decide on  
✅ **Trade-offs** - Cost vs quality, speed vs safety, scale vs caution  
✅ **Business impact** - Direct revenue, profitability, market position questions  
✅ **Iteration** - Not one answer, need to measure and adjust  

**Key Takeaway:**
When approaching a new business initiative like bikes, focus on:
1. Clear success criteria upfront (go/no-go gates)
2. Realistic measurement approach (A/B test, segmentation)
3. Risk mitigation (what could go wrong?)
4. Trade-off analysis (bikes vs cars, not either/or)
5. Phase-gated expansion (pilot → learn → scale)

