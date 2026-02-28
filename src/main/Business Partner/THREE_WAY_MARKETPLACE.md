# 🔄 DoorDash 3-Way Marketplace Dynamics - Complete Guide

## Problem Statement
"DoorDash operates a 3-way marketplace with Customers, Dashers (drivers), and Merchants (restaurants). How would you approach understanding marketplace dynamics, designing experiments, and making decisions when one side affects the others?"

---

## 🎯 Why This Matters for Your Interview

The **3-way marketplace** is fundamentally different from a 2-sided marketplace because:
- Every decision affects ALL THREE parties
- Trade-offs are unavoidable (lower fees = better for customers but hurt merchants/dashers)
- Network effects are complex (more dashers → faster delivery → more customers → more merchants)
- You need to think about SYSTEM HEALTH, not just one metric

This is a **critical DoorDash concept** that will definitely come up.

---

## 📊 The 3-Way Marketplace Structure

```
                     CUSTOMERS
                    /    |    \
                   /     |     \
              Browse  Choose  Pay
                   \     |     /
                    \    |    /
                _____ DoorDash _____
                /                   \
               /                     \
          MERCHANTS              DASHERS
        (Restaurants)            (Drivers)
        
        Supply Food       Delivery Service
        (Receive orders)  (Pick up & deliver)
```

### The Relationships

```
CUSTOMER ←→ MERCHANT:
├─ Customer wants: Variety, quality, speed, price
├─ Merchant wants: Volume, higher AOV, retention
├─ Tension: Discounts reduce merchant revenue
└─ Balance: More customers ↑ merchant volume

CUSTOMER ←→ DASHER:
├─ Customer wants: Fast, careful, polite delivery
├─ Dasher wants: Tips, flexible schedule, fair pay
├─ Tension: Lower fees mean Dashers won't accept
└─ Balance: More customers ↑ dasher earnings

MERCHANT ←→ DASHER:
├─ Merchant wants: Fast pickup, careful handling
├─ Dasher wants: Easy orders, good pay
├─ Tension: Busy merchant = slower dasher earnings
└─ Balance: Smooth operations ↑ everyone's happiness

DOORDASH ←→ ALL:
├─ DoorDash wants: Growth, profitability, marketplace health
├─ But: Every pricing change affects all three sides
└─ Challenge: Optimize for all simultaneously
```

---

## 📈 Marketplace Health Metrics (The Full Picture)

### Customer Side

```
DEMAND METRICS:
├─ DAU/MAU: How many active customers
├─ Order frequency: Orders per user per week
├─ AOV: Average order value
├─ Repeat rate: % ordering 2+ times
└─ Churn: % inactive 30+ days

SATISFACTION METRICS:
├─ NPS: Net Promoter Score
├─ Rating: Average star rating
├─ Late delivery %: On-time rate
├─ Complaint rate: % of orders with issues
└─ Repeat after complaint: Recovery rate
```

### Dasher Side

```
SUPPLY METRICS:
├─ Active Dashers: # online at any time
├─ Utilization: % of time earning
├─ Orders/dasher: Completed deliveries
├─ Earnings/dasher: $ per hour
└─ Supply/Demand ratio: Are they in balance?

SATISFACTION METRICS:
├─ Acceptance rate: % of orders accepted
├─ Completion rate: % of accepted orders finished
├─ Rating: Star rating from customers
├─ Churn: % not returning week-to-week
└─ NPS: Are dashers happy working for us?
```

### Merchant Side

```
SUPPLY METRICS:
├─ Active merchants: # taking orders
├─ Orders/merchant: Volume throughput
├─ GMV/merchant: Gross merchandise value
├─ Repeat order rate: Same merchant reorders
└─ Merchant churn: % leaving the platform

SATISFACTION METRICS:
├─ Order accuracy: % orders correct
├─ Delivery quality: % delivered on time
├─ Customer ratings: Reflects on merchant
├─ Commission satisfaction: Do they feel fair?
└─ Support satisfaction: Easy to work with?
```

### System-Level Metrics

```
MARKETPLACE HEALTH:
├─ GMV: Total order value
├─ GMS: GMV - customer credits (true revenue)
├─ Order volume: Total orders/day
├─ Completion rate: % of orders delivered successfully
├─ Profit margin: Bottom line profitability
└─ Growth rate: Month-over-month expansion

BALANCE METRICS:
├─ Customer surplus: (Willingness to pay - price paid) = satisfaction
├─ Dasher earnings: $ per hour worked
├─ Merchant revenue: Net of commissions
└─ DoorDash profit: Our cut
```

---

## 🎯 The Core Challenge: Trade-offs

Every major decision in a 3-way marketplace creates **trade-offs**:

### Example 1: Lower Delivery Fees

```
IF: We lower delivery fees by 10%

CUSTOMER SIDE: ✅ POSITIVE
├─ Lower prices (more attractive)
├─ More orders (higher frequency)
└─ Increased DAU

DASHER SIDE: ❌ NEGATIVE
├─ Lower earnings per order
├─ May accept fewer orders
├─ Potential supply shortage

MERCHANT SIDE: ➡️ NEUTRAL/SLIGHT NEGATIVE
├─ More orders (volume up)
├─ But customer might not tip dasher → dasher quality down
└─ Delivery speed might suffer

DOORDASH PROFIT: ❌ NEGATIVE
├─ Revenue per order down
└─ Margin compressed

ANALYSIS:
├─ Short-term: Customer growth, but dasher supply issues
├─ Medium-term: Delivery quality drops, customer complaints rise
├─ Long-term: Unsustainable if dasher supply drops too much
├─ Solution: Only if you can find efficiency gains elsewhere
```

### Example 2: Increase Commission on Merchants

```
IF: We increase merchant commission from 20% to 25%

MERCHANT SIDE: ❌ NEGATIVE
├─ Lower revenue per order
├─ Churn risk (switch to Uber Eats)
├─ May reduce menu prices to stay competitive

CUSTOMER SIDE: ➡️ NEGATIVE (INDIRECT)
├─ Merchant might raise prices
├─ Customer AOV increases
├─ Order frequency might drop (price sensitivity)

DASHER SIDE: ➡️ NEUTRAL
├─ No direct impact on earnings
└─ But customer orders down = fewer available

DOORDASH PROFIT: ✅ POSITIVE (SHORT-TERM)
├─ Revenue per order up
├─ But volume might drop

ANALYSIS:
├─ Short-term: Profit up
├─ Medium-term: Merchant churn, customer volume down
├─ Long-term: Unsustainable without retaliatory response from competitors
├─ Solution: Only sustainable if it enables better service elsewhere
```

### Example 3: Increase Dasher Incentives

```
IF: We increase dasher incentive bonus from $15 to $20 per order

DASHER SIDE: ✅ POSITIVE
├─ Higher earnings per order
├─ Acceptance rate increases
├─ Supply increases (more dashers available)

CUSTOMER SIDE: ✅ POSITIVE (INDIRECT)
├─ Better supply = faster delivery
├─ On-time % improves
├─ Customer satisfaction up

MERCHANT SIDE: ✅ POSITIVE (INDIRECT)
├─ Faster pickups (better dasher quality)
├─ Fewer complaints about delivery
├─ More reliable service

DOORDASH PROFIT: ❌ NEGATIVE
├─ Cost per order up
├─ Margin compressed

ANALYSIS:
├─ Short-term: Cost up, but quality/satisfaction improves
├─ Medium-term: More customers attracted, volume up, margins recover
├─ Long-term: Sustainable if volume growth offsets cost
├─ Solution: Worth it if it enables better positioning vs competitors
```

---

## 🧪 Designing Experiments in 3-Way Marketplace

### The Challenge

In a 2-way marketplace, you can A/B test freely. In a 3-way, you have **network effects**:

```
If you increase delivery fees for 50% of customers:
├─ Customers: Direct impact (they see higher prices)
├─ Dashers: Indirect impact (might get lower quality customer orders)
├─ Merchants: Indirect impact (demand from these customers down)
└─ Result: Complex spillover effects

You can't just look at customer conversion!
You need to measure ALL THREE SIDES.
```

### Proper 3-Way Marketplace Experiment Design

```
EXPERIMENT: Test lower delivery fees ($2 vs $3 in NYC)

RANDOMIZATION:
├─ CUSTOMER-level: 50% see $2 fee, 50% see $3
├─ BUT: They see the same pool of dashers and merchants
├─ (Can't randomize dashers/merchants - too operational)
└─ Result: Spillover effects captured

METRICS MEASURED:

CUSTOMER SIDE:
├─ Primary: Orders (incremental vs control)
├─ Secondary: Repeat rate, NPS, ATV
├─ Guardrail: Don't lower satisfaction

DASHER SIDE:
├─ Orders assigned: Did dasher workload change?
├─ Acceptance rate: Do dashers accept these orders?
├─ Earnings: Did they earn more (volume) or less (lower fees)?
├─ Utilization: Did supply/demand balance change?

MERCHANT SIDE:
├─ Orders received: Volume impact
├─ Merchant ratings: Quality impact
├─ Repeat rate: Does customer segment stick around?

BUSINESS:
├─ GMV (total order value)
├─ Revenue (GMV × take rate)
├─ Profit (revenue - costs)
├─ Unit economics: CAC impact?

ANALYSIS:
├─ Customer impact: +5% orders at lower fee
├─ Dasher impact: +3% orders, -1% acceptance rate (net zero)
├─ Merchant impact: +4% orders (same volume distributed)
├─ Business impact: +4% volume, -5% revenue = net negative ❌

DECISION:
└─ Don't launch at this price point
   Try: Different customer segment, different fee level, different time of day
```

---

## 🎯 How to Approach 3-Way Questions in Interview

### Question: "We're considering lowering delivery fees. What should we measure?"

**Answer Framework:**

```
"This is interesting because in a 3-way marketplace, we need to measure impact
on all three sides, not just customers.

FIRST - Clarify:
'Are we lowering fees for:
- All customers in all cities?
- Specific segment (e.g., new customers)?
- Specific time/day?
- Specific merchants?'

[Wait for answer]

SECOND - Propose Measurement Framework:

CUSTOMER SIDE:
├─ Primary: Do we get incremental orders? (not cannibalization)
├─ Secondary: Do these customers have good repeat rate?
└─ Guardrail: Don't damage satisfaction (NPS)

DASHER SIDE:
├─ Will they still accept these lower-fee orders?
├─ Will overall supply be affected?
├─ What's the impact on dasher earnings?
└─ Guardrail: Maintain acceptance rate >80%

MERCHANT SIDE:
├─ Do we get incremental volume or cannibalize existing?
├─ Does merchant quality hold up with extra orders?
├─ What's the merchant churn risk?
└─ Guardrail: Don't damage merchant satisfaction

BUSINESS:
├─ What's the unit economics? Revenue vs cost
├─ What's the lifetime value of these customers?
├─ What's the CAC payback period?
└─ Guardrail: Don't launch if negative unit economics

THIRD - Propose Experiment Design:

I'd run an A/B test:
├─ Test group: Lower fee ($2 vs $3)
├─ Control group: Current fee ($3)
├─ Geography: 1 city (isolation)
├─ Duration: 4 weeks (catch repeat patterns)
├─ Sample: 100K customers per arm
├─ Measure: All three sides

FOURTH - Decision Framework:

┌─ IF: Incremental orders + good repeat + no dasher issues + positive unit econ
│  └─ → Launch (good for everyone)
├─ IF: Incremental orders BUT low repeat + dasher acceptance drops
│  └─ → Don't launch (unsustainable)
├─ IF: Incremental orders + good repeat BUT negative unit econ
│  └─ → Consider launch if it achieves strategic goal (e.g., market share)
└─ IF: No incremental orders (pure cannibalization)
   └─ → Don't launch (wasteful)

FIFTH - Nuance:

'I should note: There's a timing element here. Even if unit econ is negative
today, if we can:
- Build scale (volume discounts)
- Improve operations (faster delivery = fewer dashers needed)
- Increase customer lifetime value (better retention)

...then it might become positive long-term. So we'd need a forward-looking
analysis, not just current unit econ.'
"
```

---

## 🔍 Common 3-Way Marketplace Questions

### Q1: "Orders are down. How would you investigate?"

```
WRONG APPROACH:
"Check customer acquisition and conversion metrics"

RIGHT APPROACH:
"I'd check THREE sides:

CUSTOMER SIDE:
├─ DAU/MAU down? (demand problem)
├─ Repeat rate down? (satisfaction problem)
└─ Conversion rate down? (pricing/availability issue)

DASHER SIDE:
├─ Active dashers down? (supply shortage)
├─ Acceptance rate down? (drivers rejecting orders)
├─ Utilization down? (not enough demand for available drivers)

MERCHANT SIDE:
├─ Merchant count down? (churn)
├─ Orders per merchant down? (volume per location down)
└─ Menu availability down? (items out of stock)

THEN correlate:
├─ If customer DAU up but orders down → Issue might be dasher supply
│  (customer wants to order, but no drivers available)
├─ If dasher supply stable but orders down → Issue might be customer satisfaction
│  (customers ordering less)
├─ If orders down but everything else stable → Might be merchant quality issue
│  (customers getting bad food/service)

This is systems thinking - one metric dropping might be caused by
issues in another part of the marketplace."
```

### Q2: "How would you launch in a new city?"

```
WRONG APPROACH:
"Get merchants, launch app, hope customers come"

RIGHT APPROACH:
"I'd think about chicken-and-egg problem in 3-way marketplace:

PHASE 0: DEMAND VALIDATION
├─ Do customers want this service here?
├─ Run surveys, small pilot (food delivery app only)
└─ Goal: Confirm demand exists

PHASE 1: SUPPLY BUILD (parallel processes)
├─ MERCHANT SIDE:
│  ├─ Recruit restaurants (target quality ones)
│  ├─ Help with onboarding, technology
│  ├─ Set commissions to be competitive
│  └─ Goal: 100+ merchants ready on day 1
├─ DASHER SIDE:
│  ├─ Recruit drivers (local job ads)
│  ├─ Training on app, safety
│  ├─ Set incentives high for launch (cover launch costs)
│  └─ Goal: 100+ drivers available on day 1
└─ CUSTOMER SIDE:
   ├─ Launch marketing (awareness)
   ├─ Heavy discounts for early adopters
   ├─ Goal: Drive demand to match supply

PHASE 2: BALANCE & OPTIMIZE
├─ Monitor marketplace health:
│  ├─ Is supply meeting demand?
│  ├─ Are merchants happy?
│  ├─ Are dashers earning fair wages?
├─ Adjust incentives to maintain balance
├─ Goal: Sustainable, healthy marketplace

KEY METRICS AT LAUNCH:
├─ Dasher supply/demand ratio: 1 dasher per X customers
├─ Merchant orders/day: Average throughput
├─ Customer repeat rate: Are they staying?
├─ Unit economics: CAC, LTV, margin
└─ Marketplace health score: Balanced?

DECISION GATE:
└─ After 3 months:
   ├─ IF: Healthy marketplace metrics → Expand
   ├─ IF: Imbalanced (e.g., dasher shortage) → Adjust incentives, retry
   └─ IF: Can't achieve health → Consider if market is viable
"
```

---

## 💡 Key Takeaways for Interview

**What They're Testing:**
- Do you understand marketplace dynamics (not just one side)?
- Can you think about trade-offs and system health?
- Do you know how to design experiments with network effects?
- Can you make balanced decisions across stakeholders?

**What They Want to Hear:**
✅ "I'd measure all three sides"  
✅ "There are trade-offs here..."  
✅ "We need to maintain balance or..."  
✅ "A/B test design needs to account for spillovers"  
✅ "Let me think about what each side needs"  

**What They Don't Want:**
❌ Only thinking about customer side  
❌ Ignoring dasher/merchant impact  
❌ "Just launch and see what happens"  
❌ Designing experiments without thinking about network effects  
❌ Proposing changes that hurt one side  

---

## 🎯 The Golden Framework

Whenever you get a 3-way marketplace question:

1. **IDENTIFY THE THREE SIDES**
   - Customers, Dashers, Merchants
   - Sometimes: DoorDash as 4th (profitability)

2. **THINK ABOUT WHAT EACH WANTS**
   - Customers: Low price, fast, quality
   - Dashers: Fair pay, flexibility, tips
   - Merchants: High volume, repeat customers, fair commission
   - DoorDash: Growth, profit, sustainability

3. **IDENTIFY THE TRADE-OFFS**
   - Lower fees → Customers happy, Dashers sad, Merchants happy, DoorDash sad
   - Higher commission → Merchants sad, DoorDash happy (short-term), Customers/Dashers spillover
   - Higher dasher pay → Dashers happy, DoorDash sad, but spillovers: Customers/Merchants happy

4. **DESIGN FOR BALANCE**
   - Not pure profit optimization (unsustainable)
   - Not pure fairness (unprofitable)
   - But balance that works for all

5. **MEASURE ALL THREE SIDES**
   - Never just one metric
   - Always think about spillovers
   - Design experiments with network effects in mind

This is **systems thinking** - the hallmark of great analysts!

