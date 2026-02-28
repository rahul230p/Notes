🚗 DoorDash – Business Partner Round (45 mins)
🎯 Use Case: Dasher Supply Optimization

"How would you optimize Dasher (driver) supply to reduce delivery times and costs?"

This is a critical operational problem that directly impacts customer satisfaction and profitability.

⏱️ Minute-by-Minute Interview Simulation
🕐 0–3 min — Warm-up & Context

Interviewer:

Thanks for joining. Today, we're looking at a supply-side challenge.

(Setting up an operations/business strategy question.)

🕐 3–7 min — Core Prompt

Interviewer:

We have a Dasher supply problem. In peak hours, we're over-hiring (too many Dashers idle), and in off-peak, we're under-staffed (long wait times, high cancellations). How would you approach optimizing supply?

✅ Your Answer (CRITICAL OPENING)

You:

I'd approach this as a supply-demand forecasting and incentive optimization problem. I want to understand three things:

What demand patterns do we see?

Where and when are we inefficient?

What levers do we have to influence supply?

🔥 This shows you think systematically about trade-offs.

🕐 7–10 min — Clarifying Questions

You:

Are we optimizing for a single city or city-wide?

What's our primary constraint — cost, delivery time, or customer experience?

Do we currently have data on Dasher acceptance rates, completion rates, and idle time?

Are there regulatory constraints around surge pricing?

Interviewer:

Let's think city-wide. We care most about delivery time and cost. We have good historical data. No regulatory constraints currently.

🧠 What interviewer is evaluating

Do you prioritize business constraints over technical solutions?

Do you ask about data quality before proposing metrics?

🕐 10–15 min — Key Metrics & Problem Definition

You:

I'd define the problem through three metrics:

1. Delivery Time (P50, P95)
   - Current: 35 mins average
   - Target: 28 mins average

2. Dasher Utilization Rate
   - % of time Dashers are actively delivering
   - Current: ~45% (means 55% idle time)

3. Cost per Delivery
   - Total costs / deliveries
   - Need to separate fixed vs variable costs

The real issue is finding the optimal supply level where we balance short delivery times without excessive idle capacity.

Interviewer:

How would you even measure what optimal is?

You (strong answer):

I'd start by understanding the demand-supply curve:

Does adding 10% more Dashers reduce delivery time by 2 mins?

Or is it diminishing returns (only 0.5 mins improvement)?

Once I know the elasticity, I can model the trade-off between delivery time and cost.

✅ This is exactly what they want to hear.

🕐 15–22 min — Forecasting & Segmentation

You:

First, I'd forecast demand at a granular level:

By hour of day (lunch rush, dinner rush, late night)

By day of week (weekends vs weekdays)

By geography (downtown, residential, airport areas)

By merchant type (restaurants busier than groceries)

For each segment, I'd calculate:

Expected orders in next hour

Required Dashers to hit our delivery time SLA

Current supply

Then I can identify where we're over/under-supplied.

Interviewer:

That makes sense. But how do you actually change supply?

You:

Good question. We have multiple levers:

1. Incentives (surge multiplier on earnings)
   - Increase earnings → more Dashers accept orders
   
2. Scheduling (letting Dashers book shifts)
   - Can predict supply for the next week
   
3. Positioning (pre-positioning Dashers in hot zones)
   - Reduce travel time to pickup
   
4. Selective acceptance (prioritizing certain Dashers)
   - High-rated Dashers get orders first during crunch

I'd model the elasticity of each lever.

🕐 22–28 min — Data & Methodology

Interviewer:

What data would you need?

You:

I'd pull:

Historical orders (timestamp, location, merchant, customer)

Dasher supply (active Dashers by hour/area, acceptance rates, completion rates)

Delivery performance (pickup time, dropoff time, cancellations)

Surge multiplier applied (to measure price elasticity)

Restaurant preparation time (to understand end-to-end time)

This lets me understand the full journey and where delays come from.

🔥 Clean, structured, business-aligned.

🕐 28–33 min — Solution Design

Interviewer:

How would you solve this?

You:

I'd build a three-layer solution:

Layer 1 — Demand Forecasting
- Train a time-series model (LSTM or Prophet) on historical data
- Predict orders by hour/area for next 7 days
- Incorporate external factors (weather, local events)

Layer 2 — Supply Optimization
- Calculate optimal Dasher count per area/hour
- Factor in utilization target (say 70-80%)
- Account for diversity (new Dashers vs experienced)

Layer 3 — Dynamic Allocation
- Real-time surge pricing based on supply gap
- Incentivize Dashers to work peak hours
- Auto-accept orders for reliable Dashers

Expected outcome:
- 15-20% improvement in delivery time
- 25-30% reduction in Dasher idle time
- 10-15% reduction in cost per delivery

🕐 33–38 min — Business Scenario Twist

Interviewer:

We ran this and Dasher earnings dropped 12% because fewer Dashers were needed. Now we have Dasher churn. What's your next move?

You:

This is a real trade-off. I'd propose:

1. Phase the changes slowly (10% reduction per week)
   - Gives Dashers time to adapt
   
2. Offer retention bonuses for reliable Dashers
   - High-quality supply is more valuable than quantity
   
3. Shift low-utilization Dashers to different areas
   - Maybe they're better suited for suburban zones
   
4. Increase order volume through marketing
   - Growing the pie instead of cutting it

The key is: Don't optimize for cost alone. Optimize for sustainable supply and customer experience.

🕐 38–42 min — Decision Impact

Interviewer:

How does this solve our business problem?

You:

This enables:

Faster delivery times → higher customer NPS → more repeat orders

Lower cost per delivery → improved unit economics → better margins

Predictable supply → better Dasher retention → less recruiting friction

We go from reactive firefighting (surge multiplier chaos) to proactive planning.

🔥 This line is gold.

🕐 42–45 min — Close

Interviewer:

That makes sense. Anything you'd add?

You:

Yes. I'd recommend building experimentation into this:

Test different surge multipliers in different cities

A/B test incentive structures (bonus vs multiplier)

Measure Dasher satisfaction alongside efficiency

This way, we don't just deploy a model — we continuously refine it based on real-world behavior.

The goal is sustainable growth, not just cost optimization.

