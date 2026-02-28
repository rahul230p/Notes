# 💰 DoorDash Cost Allocation Problem - Advanced Scenario

## Problem Statement
"A customer gets an order and complains about various issues (cold food, late delivery, wrong items, etc.). DoorDash incurs support costs including support agent time and credits/refunds issued. Given an order-level data table, how would you allocate a $1 Million annual support budget across orders to optimize support resource allocation?"

---

## 🎯 Why This Question Exists

This is a **complex business problem** that tests:
- How you think about **resource allocation** strategically
- Your ability to **prioritize** across competing needs
- Understanding of **business trade-offs** (cost vs retention)
- Data-driven **decision-making logic**
- Practical implementation thinking

It's asking: "How do you FAIRLY and STRATEGICALLY allocate a fixed budget?"

---

## 📊 The Data You Have

### Order-Level Table

```sql
orders (
  order_id,
  customer_id,
  order_value,           -- Revenue from this order
  complaint_flag,        -- Did customer complain? (1/0)
  complaint_category,    -- "cold_food", "late", "wrong_items", "other"
  complaint_severity,    -- 1-5 scale (1=minor, 5=critical)
  support_contact_flag,  -- Did customer contact support? (1/0)
  credit_issued,         -- Amount credited back to customer
  resolution_time_mins,  -- Time to resolve
  customer_lifetime_value, -- LTV of this customer
  customer_repeat_rate,  -- % of times they reorder after complaint
  dasher_quality_rating, -- Quality of dasher (1-5)
  merchant_quality_rating, -- Quality of food (1-5)
  is_critical_issue,     -- System determined critical (1/0)
  customer_retention_at_30d, -- Did they order again in 30 days? (1/0)
)
```

---

## 💡 The Core Question

**"How would you allocate $1M of support budget across 10M orders annually?"**

This could mean:
- Which orders get priority support?
- Which orders get proactive outreach?
- Which orders get larger credits?
- How do you prevent churn?
- How do you maintain profitability?

---

## 🎯 Your Answer Framework

### STEP 1: CLARIFY (Ask Questions First!)

```
"Before I create an allocation logic, I need to clarify the goal:

1. WHAT IS SUCCESS?
   ├─ Are we trying to minimize support costs?
   ├─ Or minimize churn?
   ├─ Or maximize customer lifetime value?
   ├─ Or balance cost vs retention?
   └─ Different goals → different allocation strategies

2. WHO ARE WE ALLOCATING TO?
   ├─ Are we allocating support agent time?
   ├─ Or credits/refunds?
   ├─ Or both?
   ├─ Or resources (chat bots vs humans)?
   └─ This changes the logic

3. WHAT COUNTS AS 'SUPPORT COSTS'?
   ├─ Agent salary allocated per interaction?
   ├─ Actual credits issued?
   ├─ Prevention costs (proactive outreach)?
   ├─ Infrastructure?
   └─ Understanding scope matters

4. WHAT'S THE CONSTRAINT?
   ├─ Is $1M truly fixed?
   ├─ Or is that a budget we can exceed if ROI is positive?
   ├─ Can we reallocate across months?
   └─ Constraints affect strategy

5. WHAT'S OUR RISK TOLERANCE?
   ├─ Do we focus on retaining high-value customers?
   ├─ Or on fairness (everyone gets support)?
   ├─ Or on ROI (only invest where it pays back)?
   └─ Values drive decisions
"
```

---

### STEP 2: DEFINE ALLOCATION PRINCIPLES

Once you understand the goal, propose **allocation logic**:

```
PRINCIPLE 1: RETENTION-FOCUSED ALLOCATION
"Allocate support where it prevents churn"

Logic:
├─ For each order, calculate: Churn Risk × Customer LTV × Effectiveness
├─ Churn Risk = Probability customer leaves after complaint
├─ LTV = Lifetime value of this customer
├─ Effectiveness = Likelihood support resolves the issue
├─ Allocate more budget to high-risk, high-value customers
└─ Example allocation:
   ├─ High LTV + High Churn Risk: $100 support budget per issue
   ├─ High LTV + Low Churn Risk: $20 support budget
   ├─ Low LTV + High Churn Risk: $10 support budget
   └─ Low LTV + Low Churn Risk: $5 support budget (automated)

Calculation Example:
├─ Order customer LTV: $500
├─ Probability they churn if not resolved: 30%
├─ Support effectiveness at preventing churn: 80%
├─ Expected customer value loss: $500 × 0.30 = $150
├─ ROI of spending $40 on support: Retain $120 value
├─ Allocation: Spend $40 on this order
└─ Rationale: If support prevents churn, we gain $120 vs $40 cost


PRINCIPLE 2: SEVERITY-BASED ALLOCATION
"Allocate based on how serious the problem is"

Logic:
├─ Critical issues (system down, food poisoning, safety): $200+ per order
├─ High severity (cold food, very late, dangerous dasher): $50-100
├─ Medium severity (slightly late, minor quality issue): $10-30
├─ Low severity (small UI issue, minor complaint): $2-10
└─ Not assigned (no complaint): $0

Advantages:
├─ Fair (customers with bad problems get more support)
├─ Simple to implement
├─ Intuitive to stakeholders

Disadvantages:
├─ Ignores customer value
├─ May waste money on low-value customers
└─ Doesn't optimize for retention


PRINCIPLE 3: PREVENTION-FOCUSED ALLOCATION
"Allocate to prevent problems before they happen"

Logic:
├─ Segment orders by risk: High quality, medium risk, high risk
├─ For high-risk orders (bad merchant + new customer):
│  ├─ Proactive quality check before delivery
│  ├─ Expedited support if complaint
│  └─ Preventive credit ($5 discount to ensure satisfaction)
├─ For medium-risk orders:
│  └─ Standard support process
├─ For low-risk orders:
│  └─ Self-service support (chatbot)
└─ Save $1M by preventing 80% of complaints through early action


PRINCIPLE 4: ROI-BASED ALLOCATION
"Only spend where return exceeds cost"

Logic:
├─ For each type of issue, calculate:
│  ├─ Cost to resolve (support agent time, credit)
│  ├─ Probability issue is resolved
│  ├─ Customer value saved (prevent churn)
│  ├─ ROI = Value Saved / Cost
│
├─ Allocate budget to issues with highest ROI first
├─ Example:
│  ├─ Cold food issues: $50 cost → $300 value saved → ROI = 6x ✓ (fund)
│  ├─ Minor UI issues: $10 cost → $15 value saved → ROI = 1.5x (limited funding)
│  └─ Duplicate order: $40 cost → $20 value saved → ROI = 0.5x (don't fund)
└─ Budget allocation:
   ├─ Phase 1: Allocate to all 6x+ ROI issues
   ├─ Phase 2: Allocate to all 3x+ ROI issues
   ├─ Phase 3: Allocate to all 1.5x+ ROI issues until budget exhausted
```

---

### STEP 3: PROPOSE YOUR SPECIFIC LOGIC

Here's a **data-driven approach** you could use:

```
HYBRID ALLOCATION MODEL: Retention × Severity × ROI

For each order with a complaint:

Calculate three scores (0-100 each):

1. RETENTION SCORE
   ├─ Base: Customer LTV percentile (0-100)
   ├─ Adjust: Historical churn rate for this segment
   ├─ Adjust: Repeat rate after complaint resolution
   ├─ Result: Importance of retaining this customer
   └─ Formula: (LTV_percentile × 0.5) + (retention_history × 0.5)

2. SEVERITY SCORE
   ├─ Base: Complaint severity rating (1-5 → 20-100)
   ├─ Adjust: Impact on customer (safety vs minor inconvenience)
   ├─ Adjust: Impact on DoorDash (reputation, liability)
   ├─ Result: How urgent/important is this issue
   └─ Formula: (complaint_severity × 20) + (issue_impact × adjustment)

3. ROI SCORE
   ├─ Base: Historical resolution effectiveness (0-100)
   ├─ Adjust: Cost of resolution vs customer value at risk
   ├─ Adjust: Whether proactive or reactive
   ├─ Result: How efficiently we can allocate budget here
   └─ Formula: (effectiveness × 0.6) + (cost_efficiency × 0.4)

FINAL ALLOCATION FORMULA:

allocation_budget = base_allocation × retention_score × severity_score × roi_score

Example calculation:
├─ Order: Customer LTV = $300 (70th percentile) = retention_score 70
├─ Issue: Cold food (severity 4) = severity_score 80
├─ Fix: Support can resolve 85% of cold food issues = roi_score 85
├─ Base allocation per complaint: $50
├─ Calculated budget: $50 × 0.70 × 0.80 × 0.85 = $23.80
└─ Interpretation: Spend $23.80 on support for this order

IMPLEMENTATION:

1. Score all 10M orders with complaints
2. Calculate allocation budget for each
3. Sum allocations: $X total
4. Scale all allocations by $1M / $X (to fit budget)

This ensures:
├─ High-value, serious issues get more budget
├─ High-ROI solutions get prioritized
├─ $1M budget is fully utilized
└─ Logic is transparent and defensible
```

---

## 📋 Different Allocation Strategies (Comparison)

```
STRATEGY 1: EQUAL ALLOCATION
├─ Allocate: $1M / (# of complaints) = $ per complaint
├─ Pros: Fair, simple to explain
├─ Cons: Wastes money on low-value customers, doesn't prevent churn
├─ Example: 500K complaints → $2,000 per complaint
└─ Use case: If you truly care about fairness over efficiency

STRATEGY 2: RETENTION-FOCUSED (My Recommendation)
├─ Allocate: Based on customer LTV × churn risk
├─ Pros: Optimizes for keeping valuable customers
├─ Cons: Low-value customers get less support (fairness concern)
├─ Example: High LTV = $50, Low LTV = $5
└─ Use case: If goal is to maximize customer lifetime value

STRATEGY 3: SEVERITY-FOCUSED
├─ Allocate: Based on problem severity
├─ Pros: Fair (big problems get more support), intuitive
├─ Cons: May waste money on low-value customers with big problems
├─ Example: Critical = $100, High = $50, Low = $10
└─ Use case: If goal is to fix big problems fairly

STRATEGY 4: PREVENTION-FOCUSED
├─ Allocate: To prevent problems before they happen
├─ Pros: Most efficient (prevent > resolve)
├─ Cons: Complex to measure ROI on prevention
├─ Example: Screen high-risk orders, offer proactive support
└─ Use case: If you can measure prevention effectiveness

STRATEGY 5: ROI-FOCUSED
├─ Allocate: Only where ROI > threshold
├─ Pros: Most profitable (every $ spent returns $X)
├─ Cons: May be perceived as unfair (some issues get no support)
├─ Example: Only fund issues where ROI > 3x
└─ Use case: If profitability is paramount

MY RECOMMENDATION:

Use Strategy 2 (Retention-Focused) but add elements of Strategy 3 & 4:

├─ Base allocation: Customer LTV × Churn Risk (retention-focused)
├─ Add: Minimum support for all critical issues (fairness)
├─ Add: Prevention budget for proactive outreach (efficiency)
├─ Result: $1M allocated as:
│  ├─ 60%: Retention-focused support ($600K)
│  ├─ 20%: Critical issue support ($200K)
│  └─ 20%: Prevention & proactive ($200K)
└─ This balances profit, retention, and fairness
```

---

## 🎯 Summary

This scenario tests:
✅ Strategic resource allocation  
✅ Business trade-offs (profit vs fairness)  
✅ Data-driven decision making  
✅ Practical implementation  
✅ Stakeholder communication  

Your answer should show:
✅ Clarifying questions first  
✅ Multiple approaches considered  
✅ Clear recommendation with rationale  
✅ How to measure if it works  
✅ How to implement practically

