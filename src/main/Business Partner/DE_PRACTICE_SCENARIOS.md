# 🎤 Data Engineer - Practice Scenarios

## How to Use This Guide

Each scenario below is realistic and similar to what you'll face. Practice each one for 45 minutes using the framework from **DE_SPECIFIC_GUIDE.md**.

**For each scenario:**
1. Read the prompt
2. Think through: Clarify → Data Problem → Solution → Collaboration → Impact
3. Speak your answer out loud (not just in your head)
4. Record if possible
5. Time yourself
6. Adjust based on learnings

---

## Scenario 1: Tracking Dasher Quality

### The Setup

**Interviewer says:**
"Our Dasher managers want to track driver quality metrics. Right now, they manually review feedback. We want to make it data-driven. How would you approach building this?"

### What They're Really Testing

- Can you translate vague business need to data solution?
- Do you ask clarifying questions?
- Do you think about data quality?
- Can you design something an analyst can use?
- How would you work with Dasher ops?

### Your Framework

```
CLARIFY (Start here!)
├─ What specific quality issues matter most?
│  └─ Late deliveries? Wrong orders? Rude drivers?
├─ Who will use this data?
│  └─ Individual managers? Executive team? Everyone?
├─ What should they do with this data?
│  └─ Monitor dashboards? Automated alerts? Weekly reports?
├─ What data exists currently?
│  └─ We have ratings, complaints, delivery times already?
├─ What's the timeline?
│  └─ Do we need this in 2 weeks or can we take 2 months?
└─ What's success?
   └─ How will we know if this improved driver quality?

DATA PROBLEM
├─ Data sources: Ratings, complaints, delivery times, customer feedback
├─ Data quality: Ratings might be biased. Complaints are subjective.
├─ Schema: Fact table (delivery) + dimensions (driver, time, etc)
├─ Latency: Daily OK? Or real-time monitoring?
└─ Challenges: How to aggregate ratings fairly? How to weight complaints?

SOLUTION
├─ Build a scoring model:
│  ├─ 70% on-time delivery %
│  ├─ 20% customer rating average
│  └─ 10% complaint rate
├─ Dashboard by manager showing their drivers' scores
├─ Weekly reports showing trends
└─ Alerts if driver score drops significantly

COLLABORATION
├─ Meet Dasher ops team:
│  ├─ Understand what metrics they care about
│  ├─ Get feedback on scoring model
│  └─ Show them early dashboard drafts
├─ Iterate with them:
│  ├─ If scoring seems unfair, adjust weights
│  ├─ If data quality is bad for some metrics, fix it
│  └─ If they need new metrics, add them
└─ Communication plan:
   ├─ Weekly standups with ops
   ├─ Shared dashboard of progress
   └─ Training session before launch

IMPACT
├─ Managers can now see quality trends daily
├─ Poor performers are identified quickly
├─ Can improve driver quality through data
└─ Estimated impact: 10% improvement in ratings
```

### Sample Answer (3-4 minutes)

```
"Good question. Before I jump into design, let me understand the problem better.

First, I'd ask: What specific quality issues are most important? Late deliveries?
Wrong orders? Rude drivers? And who will use this - individual managers or just
executives?

[Wait for their answer]

OK, so we care about delivery time and customer ratings. Managers need dashboards.

I'd propose:

1. First, understand your data:
   - We have ratings and delivery times already?
   - What's the quality like? Are ratings reliable?
   
2. Build a quality score:
   - Something like: 70% on-time, 20% customer rating, 10% complaint rate
   - This gives managers one number to track
   
3. Create a dashboard:
   - Each manager sees their drivers' quality scores
   - Trends over time
   - Alerts if score drops
   
4. Work with your Dasher ops team:
   - Show them the scoring model
   - Get feedback - does this feel fair?
   - Iterate if needed
   
5. Launch with training:
   - Show managers how to use it
   - Weekly updates so they know we have their feedback

The biggest challenge I see is: ratings can be biased. Some customers are harsher
than others. So we'd need to normalize ratings by customer type or do some analysis
to make sure we're being fair.

Does this direction make sense? What aspects are most important to you?"
```

### Follow-Up Questions They Might Ask

**"What if we have missing data?"**
```
Answer: "Good point. I'd first understand: how much is missing? For which drivers?
If it's random, we can handle it. If certain drivers have more missing data, that's
a problem - we might accidentally bias against them. I'd suggest:
1. Understand why it's missing
2. Adjust our aggregation to account for it
3. Set a minimum data threshold (e.g., need 50 deliveries to score)
"
```

**"How would you ensure this is fair to drivers?"**
```
Answer: "Great question. Fairness is critical. I'd:
1. Run the scoring model and show Dasher ops the results first (before launch)
2. Identify any outliers or unexpected patterns
3. Get feedback: 'Does this feel right?'
4. Have a data quality flag: 'This driver doesn't have enough data, so be careful'
5. Make the model transparent: Show them exactly how we calculate the score
6. Have an appeals process: If a driver disagrees with their score, we investigate
"
```

**"How would you handle driver turnover? New drivers won't have much data."**
```
Answer: "Exactly. I'd propose:
1. Have a separate 'new driver' scorecard for first 100 deliveries
2. Focus on safety and on-time for new drivers
3. Require more data before including in the standard score
4. Don't penalize them early - give them time to learn
5. Communicate this to managers: 'New drivers are learning, be patient'
"
```

---

## Scenario 2: Data Pipeline Debugging

### The Setup

**Interviewer says:**
"Our order metrics dashboard shows wrong numbers today. The last 4 hours of data
seems off. The analytics team is frustrated because they can't analyze today's
business. How would you debug this?"

### What They're Really Testing

- Can you think systematically about problems?
- Do you gather information before diagnosing?
- How do you communicate with stakeholders?
- Can you prioritize (quick fix vs root cause)?
- How do you handle pressure?

### Your Framework

```
VALIDATE & COMMUNICATE (Do this first!)
├─ Confirm the problem: Is it every metric or just some?
├─ Scope the blast radius: How many dashboards affected?
├─ Set expectations: When can we have a fix?
└─ Keep stakeholders updated: Every 15 minutes

ROOT CAUSE ANALYSIS
├─ When did it start? (Last 4 hours = something changed?)
├─ What changed?
│  ├─ New deployment in last 8 hours?
│  ├─ Data source changed?
│  ├─ Schema change?
│  └─ Volume spike?
├─ Where in pipeline?
│  ├─ Data ingestion broken?
│  ├─ Transformation issue?
│  ├─ Storage problem?
│  └─ Query problem?
└─ Quick diagnosis:
   ├─ Check: Is source data coming in?
   ├─ Check: Are transformations running?
   ├─ Check: Is output data in the warehouse?
   └─ Check: Can we query it?

SOLUTION OPTIONS
├─ Quick fix (restore yesterday's data temporarily)
├─ Medium fix (fix and rerun last 4 hours)
└─ Root cause fix (prevent it happening again)

COMMUNICATION
├─ Analytics team: "Here's what we found, here's our plan"
├─ Engineering team: "Do we have capacity to help investigate?"
└─ Everyone: "We're working on it, updates every 30 min"
```

### Sample Answer (3-4 minutes)

```
"OK, this is urgent. Here's what I'd do:

FIRST - Get the information:
'Which metrics are wrong - all of them or specific ones? When did you notice?
Was there any deployment or data source change recently?'

[Listen to their answers]

SECOND - Communicate with analytics:
'I know this is frustrating. Let me figure out what happened. I'll give you an
update in 15 minutes. For now, use yesterday's data if you need something urgently.'

THIRD - Systematic debugging:
1. Check the data source: Is fresh data coming in? I'd query the raw data table.
2. Check the transformation: Is our ETL process running? I'd check the job logs.
3. Check the output: Is data in the warehouse? I'd query directly.
4. Check recent changes: Was there a deployment? What changed?

FOURTH - Quick answer:
Once I find the issue, I have two paths:
- Quick fix: Restore last good data, roll back the change. Users can start working.
- Root cause: Investigate and permanently fix. Prevents recurrence.

I'd communicate to the team: 'I found the problem. It was [X]. Quick fix takes 10 min.
Root cause fix takes 2 hours. I recommend we do the quick fix now, get you working,
then root cause fix in the background.'

FIFTH - Prevention:
After it's fixed, I'd add:
- Monitor for this error in future
- Add tests to catch it before production
- Document what happened so we don't repeat it
"
```

### Follow-Up Questions

**"What if you can't find the root cause quickly?"**
```
Answer: "I'd propose: Let's do the quick fix now (restore yesterday's data), get
analytics working again. While they're working with that, I continue investigating
the root cause. Better to have them productive than both blocked."
```

**"How would you prevent this happening again?"**
```
Answer: "I'd add:
1. Data quality checks that catch this automatically
2. Alerts if data stops coming in or transforms fail
3. Tests in our pipeline to catch this before production
4. Documentation so future incidents are easier to debug"
```

---

## Scenario 3: Modeling Customer Behavior

### The Setup

**Interviewer says:**
"Our growth team wants to predict which customers will churn. Can you design a
data model/pipeline to support this? They'll build a model on top, but we need
clean data first."

### What They're Really Testing

- Can you design a schema for a specific use case?
- Do you think about data quality and completeness?
- Can you communicate with non-technical people?
- Do you understand what downstream needs?

### Your Framework

```
CLARIFY
├─ What do you mean by churn? (No order in 60 days? They told us they left?)
├─ What's the prediction timeline? (Predict next 30 days? 90 days?)
├─ What will the growth team do with predictions? (Send retention promos?)
├─ What historical data do we have? (How far back?)
└─ What accuracy is needed? (Perfect or 70% is OK?)

DATA PROBLEM
├─ What's the fact table? (Orders by customer_id, date)
├─ What's the grain? (Customer-day? Customer-month?)
├─ What features do we need?
│  ├─ Behavioral: Order frequency, recency, time since last order
│  ├─ Monetary: AOV, total LTV
│  ├─ Temporal: Signup date, last order date
│  └─ Demographic: Location, customer type
├─ Data quality: How fresh? How accurate?
└─ Latency: Daily updates? Weekly?

SCHEMA DESIGN
├─ Fact table: customer_churn_features (customer_id, date, [features])
├─ Features:
│  ├─ Orders in last 30 days
│  ├─ Orders in last 60 days
│  ├─ Days since last order
│  ├─ AOV last 3 orders
│  ├─ Total LTV
│  ├─ Customer signup date
│  └─ Churn label (0 or 1)
└─ Grain: One row per customer per day

DATA QUALITY
├─ Handle missing orders (customers with no activity - are they churned?)
├─ Handle anomalies (sudden spike, then nothing)
├─ Time consistency (make sure dates are accurate)
└─ Check: No gaps in data collection

COLLABORATION
├─ Meet with growth team:
│  ├─ Show sample data
│  ├─ Get feedback: Are these the right features?
│  └─ Understand their model needs
├─ Iterate:
│  ├─ If they need new features, add them
│  ├─ If data quality is bad, fix it
│  └─ If schema is wrong, adjust
└─ Documentation: How to use the table, data freshness, caveats
```

### Sample Answer (3-4 minutes)

```
"Good project. Before I design the schema, let me understand:

First, what do you mean by 'churn'? If a customer doesn't order for 60 days,
are they churned? Or do you have explicit 'they told us they left' data?

Second, what will you do with predictions? Send retention promos? Understanding
the use case helps me design the right features.

[Wait for answers]

OK, so churn = no order in 60 days. You'll use this to send retention offers.

I'd build a table like this:

One row per customer per day, with features:
- Orders in last 30 days (recent activity)
- Orders in last 60 days (trend)
- Days since last order (how long has it been?)
- Average order value last 3 orders (spending pattern)
- Total lifetime value (how valuable is this customer?)
- Days since signup (are they new or old?)
- And the label: did they churn in the next 7 days? (yes/no)

This gives you a clean dataset to build your model on.

The tricky part is data quality. Some customers might have gaps in their data
(maybe our logging was broken). Some might be dormant but not churned (seasonal
customers). So I'd add flags: 'This customer's data is incomplete' or 'This
customer is seasonal - don't predict churn for them'.

I'd also work with you to:
1. Show you sample data - 'Does this look right?'
2. Understand what features matter to you
3. Validate the labels - 'Is this who actually churned?'
4. Set up monitoring - 'If data quality drops, we know about it'

How does this sound? Would you want anything different?"
```

---

## Scenario 4: Data Quality Issue

### The Setup

**Interviewer says:**
"We discovered that Dasher location data is sometimes wrong - sometimes it updates
late, sometimes not at all. This breaks downstream analytics. How would you handle this?"

### Sample Answer

```
"This is important because bad location data cascades. Let me think through this:

FIRST - Understand the problem:
'How wrong is it? 5% of deliveries? 50%? And what does "wrong" mean - it's late
by minutes? Hours? Or completely missing?'

[Listen]

SECOND - Immediate action:
I'd add flags to the data: 'This location data is questionable'. Downstream users
know which rows to trust.

THIRD - Diagnosis:
I'd investigate:
- Is Dasher app not sending updates? (app issue)
- Is the data coming in but we're processing it wrong? (pipeline issue)  
- Is it certain types of deliveries? (edge case)

FOURTH - Solution options:
Option A: Fix the source (get Dasher app team to send better data)
Option B: Improve our ingestion (capture what we can, flag the rest)
Option C: Use alternative data (backup location source?)

FIFTH - Collaboration:
I'd work with:
- Dasher app team: 'Can you send location more reliably?'
- Analytics team: 'Use this flag column - don't trust unflagged data'
- Operations: 'This impacts your dashboards - here's the workaround'

SIXTH - Prevention:
I'd add monitoring: 'If location data quality drops below 95%, we alert'
"
```

---

## Scenario 5: Cross-Functional Conflict

### The Setup

**Interviewer says:**
"You proposed a daily data pipeline, but the PM wants real-time. Ops says real-time
is too expensive. How do you handle this?"

### Sample Answer

```
"This is exactly why communication is key. Here's what I'd do:

FIRST - Understand both sides:
Meet with PM: 'What specifically needs real-time? Can we prioritize?'
Meet with Ops: 'What makes real-time expensive? What constraints do we have?'

Maybe the PM doesn't actually need 24/7 real-time. Maybe 1-hour latency is enough.

SECOND - Present options with trade-offs:
Option 1: Daily (cheap, sufficient for 80% of use cases)
Option 2: Hourly (medium cost, better for tactical decisions)
Option 3: Real-time (expensive, but enables live monitoring)

THIRD - Help them decide:
'Here's the cost difference. Here's what you gain. Which matters more?'

FOURTH - Find middle ground:
Maybe: 'Let's do hourly for the critical metrics, daily for everything else.'

FIFTH - Iterate:
Start with hourly. Monitor usage. If people don't need it that often, dial back.
If they do, upgrade to real-time.

The key: I'm helping THEM make the right decision, not imposing my solution."
```

---

## Scenario 6: New Business Model - Bike Delivery Expansion

### The Setup

**Interviewer says:**
"We're thinking about expanding into bike delivery alongside our current car-based delivery. This is a new business model for us. How would you approach measuring success and deciding whether to scale this?"

### What They're Really Testing

- Can you handle ambiguous, strategic business questions?
- Do you think about multiple perspectives (customers, cyclists, business)?
- Can you structure measurement for a NEW thing (not existing business)?
- Do you balance opportunity with risk?
- Do you think about phased expansion vs big bets?

### Your Framework

```
CLARIFY (Ask first!)
├─ What's the geography? (Dense urban? Suburban?)
├─ What's the customer segment? (Price-sensitive? Eco-conscious?)
├─ What are we comparing against? (Cost per delivery? Speed? Sustainability?)
├─ What's the risk tolerance? (Quick scale or careful pilot?)
└─ What's the strategic goal? (Revenue? Market share? Differentiation?)

DATA PROBLEM
├─ What are we tracking?
│  ├─ Bike order volume, frequency, distance
│  ├─ Cost per delivery (bikes vs cars)
│  ├─ Cyclist supply, utilization, earnings
│  ├─ Customer satisfaction (same for bikes vs cars?)
│  ├─ Repeat rate for bike customers vs car
│  └─ Safety incidents, regulatory compliance
│
├─ What's the baseline for comparison?
│  ├─ Current car delivery metrics
│  ├─ Industry benchmarks for bike services
│  └─ Competitive offerings
│
└─ What time horizon?
   ├─ Pilot phase metrics (8-12 weeks)
   ├─ Scale phase metrics (6+ months)
   └─ Long-term strategic metrics (annual)

SOLUTION
├─ Phase 1: Soft launch in 1-2 dense cities
│  ├─ Pilot size: 10K-50K bike orders/day
│  ├─ Success criteria: Volume, cost, satisfaction, safety
│  ├─ Duration: 8-12 weeks
│  └─ Decision: Go/No-go for national scale
│
├─ Phase 2: Expand to 10-15 cities
│  ├─ Replicate learnings from pilot
│  ├─ Monitor: Retention, economics, supply
│  └─ Duration: 6 months
│
└─ Phase 3: National scale or strategic focus
   ├─ Decision: Full rollout vs niche strategy
   └─ Long-term: Bikes as % of total delivery

COLLABORATION
├─ Product: How will customers choose bikes vs cars?
├─ Ops: How to manage cyclist supply, bikes, hubs?
├─ Finance: Cost modeling, profitability targets
├─ Legal: Regulatory compliance, insurance
├─ Marketing: Customer education, positioning
└─ Sustainability: Environmental messaging

IMPACT
├─ Customer impact: More affordable delivery option
├─ Business impact: New revenue, cost savings
├─ Market impact: Competitive differentiation
├─ Stakeholder impact: New job creation (cyclists)
└─ Strategic impact: Market positioning in urban delivery
```

### Sample Answer (4-5 minutes)

```
"That's a great strategic question. Let me think through this systematically.

FIRST - Clarify:
'Before I measure, I need to understand: Is this a full-scale national strategy
or a pilot to learn? Are we targeting dense urban like NYC/SF or broader? And what's
the primary goal - cost reduction, sustainability positioning, new customer segment?'

[Wait for answers]

OK, so we're piloting in 1-2 dense cities first. That helps.

SECOND - Define what success looks like:

For a pilot, I'd measure:

Volume:
- Can we get to 10K+ bike orders per day?
- What % of customers choose bikes when available?
- Is it incremental (new customers) or cannibalizing cars?

Cost/Economics:
- Cost per delivery: How much cheaper than cars?
- If we target 20% savings, are we hitting that?
- Long-term LTV: Do bike customers have good lifetime value?

Quality:
- Delivery time: Are bikes faster or comparable?
- Customer satisfaction: Same ratings as cars?
- On-time delivery: Can we maintain 90%+ reliability?

Supply:
- Can we get enough cyclists?
- What's our utilization rate (% of time busy)?
- Are they happy with pay/flexibility?

Safety:
- Any incidents or complaints?
- Are cyclists safe?
- Regulatory compliance?

THIRD - Measurement approach:

I'd do two things in parallel:

1. Measure bikes in isolation:
   - Daily: Orders, delivery time, ratings, supply
   - Weekly: Trends, problem identification
   - Monthly: Deep analysis by neighborhood, customer type

2. A/B test bikes vs cars:
   - 50% of users see bike option, 50% see car-only
   - Measure: Do bikes cannibalize cars or add new volume?
   - Measure: Do bike customers have different LTV?

FOURTH - Phased approach:

Phase 1 (8-12 weeks):
- Pilot in 1-2 cities (NYC + SF)
- Hit targets? → Move to Phase 2
- Miss targets? → Diagnose and iterate or kill

Phase 2 (6 months):
- Expand to 10-15 cities
- Same metrics, same rigor
- Hit targets? → Plan national
- Issues? → Restrict strategy (only certain areas/distances)

Phase 3:
- Decision point: Scale nationally or stay niche?

FIFTH - Risk mitigation:

Big risks I'd watch for:
- Cyclist safety (insurance, liability)
- Customer satisfaction (weather, distance limits)
- Supply stability (not enough cyclists)
- Economics (costs higher than expected)
- Cannibalization (bikes steal car orders)

For each, I'd have early warning signals and clear decision thresholds.

SIXTH - Business impact:

Why measure this way:
- We get clear go/no-go decisions (not ambiguous)
- We understand where bikes succeed (which neighborhoods/distances?)
- We know customer and cyclist impacts
- We can calculate long-term ROI
- We have data to convince investors or stakeholders

Does this approach make sense? Any aspects you'd want me to dive deeper on?"
```

### Follow-Up Questions They Might Ask

**"What if bikes are popular but unprofitable?"**
```
Answer: "Great question - this is the key trade-off. I'd analyze:
1. Why unprofitable? Cost too high? LTV too low? Cannibalizing cars?
2. Can we fix it? Lower cyclist pay? Raise customer prices? Restrict to only
   profitable distances (0-2 miles)?
3. Strategic value: Are there non-financial benefits? (Environmental positioning,
   new customer segment, market differentiation?)
4. Decision: Only scale bikes if profitable, OR scale only in profitable
   neighborhoods/distances, OR accept short-term loss for strategic positioning.
The measurement framework tells us which lever to pull."
```

**"How would you handle cyclist safety concerns?"**
```
Answer: "Safety is non-negotiable. I'd:
1. Build it into success criteria: 'Zero critical incidents' is a guardrail
2. Measure proactively: Track near-misses, equipment issues, rider feedback
3. Mitigate: Mandatory safety training, insurance, equipment standards,
   weather-based service pausing, route optimization
4. Communicate: Clear reporting to cyclists and customers about safety
5. Decide: If safety metrics trend negative, pause expansion until fixed

This isn't just ethics - it's business. Cyclist injuries = liability + bad PR + supply loss."
```

**"How would you decide between 'scale nationally' vs 'niche urban-only' strategy?"**
```
Answer: "That decision comes from the pilot data:
- If bikes work everywhere: National scale
- If bikes work ONLY in dense urban (NYC, SF, LA): Niche strategy
- If bikes work ONLY for short distances: Restrict by distance tier
- If bikes work ONLY in good weather: Geographic/seasonal restrictions

The key insight: Don't force one strategy. Let data show where bikes have a
natural advantage. We might discover bikes are 'best in class' for 0-1.5 mile
urban deliveries but not competitive for suburbs.

The measurement framework tells us: What are the natural constraints?
And we build strategy around those, not against them."
```
