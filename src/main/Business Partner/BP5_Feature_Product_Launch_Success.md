# 📈 DoorDash – Business Partner: Feature/Product Launch & Success Measurement

## Problem Statement
How would you measure the success of [a DoorDash feature/product]? (e.g., DashPass, a promo, subscription, new recommendation system, or pricing change)

---

## Q1: What are the different types of DoorDash features/products?

### Answer:

**Feature Category Framework:**

```
FEATURE TYPES & THEIR GOALS

┌─────────────────────────────────────────────────────┐
│ 1. MONETIZATION FEATURES                            │
│    Examples: DashPass, delivery fees, surge pricing │
│    Goal: Increase revenue per user                  │
│    Success = Higher ARPU, LTV                       │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 2. ENGAGEMENT FEATURES                              │
│    Examples: Rewards, loyalty, personalized recs    │
│    Goal: Increase order frequency, stickiness       │
│    Success = Higher repeat rate, frequency          │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 3. OPERATIONAL FEATURES                             │
│    Examples: Smart routing, batch delivery          │
│    Goal: Reduce cost, improve speed                 │
│    Success = Lower CAC, faster delivery             │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 4. SUPPLY FEATURES                                  │
│    Examples: Dasher scheduling, transparency tools  │
│    Goal: Improve supply reliability                 │
│    Success = Better supply balance, retention       │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Q2: What would you measure for a SUBSCRIPTION feature (e.g., DashPass)?

### Answer:

**DashPass Success Framework:**

| Metric Category | Specific Metric | Target | Why It Matters |
|-----------------|-----------------|--------|-----------------|
| **Adoption** | Conversion rate (% of users subscribing) | 8-12% | Market fit |
| **Adoption** | Subscriber count | 2M in Year 1 | Scale |
| **Adoption** | Monthly new subscribers | 150K-200K | Growth velocity |
| **Monetization** | MRR (Monthly Recurring Revenue) | $50M+ | Revenue size |
| **Monetization** | ARPU increase (subscribers vs non) | +40% higher | Value per user |
| **Monetization** | Revenue from passes | $X00M annually | Top-line impact |
| **Engagement** | Repeat order rate (subscribers vs non) | +25% higher | Stickiness |
| **Engagement** | Orders per user (subscribers vs non) | +50% higher | Engagement |
| **Engagement** | Order frequency | 8+ orders/month for subscribers | Monthly activity |
| **Retention** | D30 retention (subscribers vs non) | +15% higher | Loyalty |
| **Retention** | Churn rate | <5% monthly churn | Business sustainability |
| **Retention** | Net Retention Rate (NRR) | >100% | Growth through existing users |
| **Economics** | LTV:CAC (subscriber cohort) | >5:1 | Profitability |
| **Economics** | Payback period for acquisition cost | <4 months | Quick ROI |
| **Satisfaction** | NPS (subscribers vs non-subscribers) | +5 points | Product satisfaction |
| **Satisfaction** | Subscriber satisfaction score | 80%+ very satisfied | Product quality |

---

## Q3: How would you measure a NEW RECOMMENDATION SYSTEM?

### Answer:

**Recommendation Feature Success Metrics:**

**Before vs After Comparison:**

```
CURRENT STATE (without rec system)
├─ Click-through rate to restaurant: 5%
├─ Avg restaurants viewed per session: 3
├─ First order usually from: Search (35%), Browse (40%), Ads (25%)
├─ Avg time to order: 4 min
└─ Satisfaction with restaurant choice: 3.8/5

NEW RECOMMENDATION ENGINE
├─ Hypothesis: Smarter recs → higher CTR, faster orders
│
├─ Expected improvements:
│  ├─ CTR: 8-10% (↑ 60%)
│  ├─ Restaurants viewed: 2 (↓ but higher relevance)
│  ├─ Time to order: 2.5 min (↓ 40%)
│  ├─ Conversion: +15%
│  └─ Satisfaction: 4.2/5 (↑ 10%)
│
└─ Revenue impact: +12-15% in order volume
```

**Key Performance Indicators:**

| Metric | Purpose | Target |
|--------|---------|--------|
| **Click-Through Rate (CTR)** | Recommendation relevance | 8-12% (vs 5% before) |
| **Conversion Rate** | Recommendation → Order | +15% uplift |
| **Order Value** | Recommendation quality | +5-10% higher AOV |
| **Time to Conversion** | User efficiency | -30% faster |
| **Re-order from Recommendation** | Learning from behavior | >40% |
| **Diversity of Orders** | System not over-fitting | >30% new restaurants tried |
| **User Satisfaction** | Recommendation quality | 4.2/5+ rating |
| **Repeat Recommendation Clicks** | Trust in system | >50% click-through on future recs |

---

## Q4: How would you measure a PRICING CHANGE (surge pricing adjustment)?

### Answer:

**Pricing Feature Impact Framework:**

**Scenario: Implementing dynamic pricing strategy**

```
CURRENT STATE
├─ Fixed delivery fee: $2.99
├─ Surge multiplier: Only during peak demand
└─ Average order value: $35

NEW STRATEGY
├─ Dynamic delivery fees based on demand
├─ More granular surge pricing
└─ Incentivize off-peak ordering
```

**Success Metrics:**

| Metric | Before | After Target | Why It Matters |
|--------|--------|--------------|-----------------|
| **Revenue per Order** | $10.50 | $12.00 (+14%) | Direct revenue impact |
| **Total GMV** | $100M | $105M | Order volume might drop slightly |
| **Order Volume** | 2.9M orders | 2.8M orders (-3%) | Price elasticity hit |
| **AOV** | $35 | $36 | Customer mix shift |
| **Peak/Off-Peak Ratio** | 3:1 | 2.5:1 | Demand smoothing |
| **Customer Satisfaction (NPS)** | 45 | 40 (-5) | Price increases hurt satisfaction |
| **Dasher Satisfaction** | 7.2/10 | 8.5/10 | Better incentives attract more |
| **Delivery Time (Peak)** | 42 min | 35 min | Better supply → faster |
| **Delivery Time (Off-Peak)** | 28 min | 26 min | Already good, minor improve |
| **Dasher Supply Increase** | +0% | +20% | Better incentives attract drivers |

**Trade-off Analysis:**

```
REVENUE IMPACT
├─ Volume loss: -$4.5M (3% of $100M) [NEGATIVE]
├─ Price increase: +$18M (14% of revenue) [POSITIVE]
└─ Net impact: +$13.5M incremental revenue ✓

CUSTOMER IMPACT
├─ NPS decline: -5 points [NEGATIVE]
├─ But: Faster delivery (peak) [POSITIVE]
└─ Net: Likely neutral to slightly negative

DASHER IMPACT
├─ Better pay during peak [POSITIVE]
├─ Retention improvement: +5-10% [POSITIVE]
└─ Net: Positive ✓

DECISION: Proceed but phase in slowly to minimize churn
```

---

## Q5: How would you measure a NEW PROMO CAMPAIGN?

### Answer:

**Promotion Campaign Success Framework:**

**Example: "$5 off first 3 orders" campaign**

```
CONTROL GROUP (no promo)
├─ First order conversion: 100 users
├─ DAU after campaign: 35 users
├─ Repeat rate after 30 days: 20%
└─ Customer acquisition cost: $5

TEST GROUP (with promo)
├─ First order conversion: 180 users (↑80%)
├─ DAU after campaign: 95 users (↑ 170%)
├─ Repeat rate after 30 days: 35%
└─ Effective CAC: $15 / 1.75 conversion lift = $8.57
```

**Key Metrics:**

| Metric | Control | Promo | Uplift | ROI |
|--------|---------|-------|--------|-----|
| **Conversion Rate** | 5% | 9% | +80% | ✓ |
| **First Order AOV** | $28 | $32 | +14% | ✓ (promo inflated) |
| **D1 Retention** | 45% | 52% | +15% | ✓ |
| **D7 Retention** | 20% | 28% | +40% | ✓ |
| **Repeat Rate (30d)** | 12% | 18% | +50% | ✓ |
| **Incremental Orders** | - | +80 orders | - | ✓ |
| **Incremental Revenue (after costs)** | - | +$1,200 | - | ✓ |
| **CAC Payback** | 1 order | 2 orders | - | ? |

**Decision Framework:**

```
IF incremental revenue > promotion cost THEN Run campaign
   Promo cost: 80 users × $5 = $400
   Incremental GMV: 80 × $32 = $2,560
   Incremental revenue: $2,560 × 30% = $768
   Net profit: $768 - $400 = $368 ✓

IF repeat rate after promo ≥ control THEN Promo creates real habit
   Repeat rate promo: 18% > control: 12% ✓
   → Users aren't just attracted by discount
   → They come back even without it

ACTION: Run campaign, track post-campaign retention
```

---

## Q6: How would you set up a rigorous A/B test for a feature?

### Answer:

**A/B Testing Framework:**

**Experiment Design Checklist:**

```
EXPERIMENT: Impact of Personal Recommendation System

┌─────────────────────────────────────────────────────┐
│ 1. HYPOTHESIS                                       │
│    "Personalized recommendations increase CTR by    │
│     40% and conversion by 15% without cannibalizing │
│     other discovery channels"                       │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 2. PRIMARY & SECONDARY METRICS                      │
│    Primary: CTR on recommendations (baseline: 5%)   │
│    Secondary: Conversion rate, AOV, repeat rate     │
│    Guardrails: NPS (don't decrease by >5 points)    │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 3. SAMPLE SIZE CALCULATION                          │
│    Baseline: 5% CTR                                 │
│    Expected uplift: 40% (to 7%)                     │
│    Significance: 95%, Power: 80%                    │
│    → Need ~40K users per arm (2 weeks data)         │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 4. RANDOMIZATION                                    │
│    Method: User ID hash, split 50/50 control/test  │
│    Stratification: By city, user cohort             │
│    Lock-in: Users stay in same group for duration   │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 5. RUNTIME & MONITORING                             │
│    Duration: 2 weeks (cover weekend/weekday mix)    │
│    Daily monitoring: Check for unexpected patterns  │
│    Early stopping rule: If 95% confidence before    │
│    end date, can stop and declare winner            │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 6. ANALYSIS                                         │
│    Statistical test: Chi-square for CTR             │
│    Significance threshold: p-value < 0.05           │
│    Subgroup analysis: Results by city, user type    │
│    Sanity checks: Control vs historical baseline    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Results Interpretation:**

| Scenario | Decision | Action |
|----------|----------|--------|
| **Winner detected** (p < 0.05, uplift significant) | Deploy | Roll out to 100% users |
| **No clear winner** (p > 0.05) | Investigate | Analyze by subgroup, run longer |
| **Guardrail violated** (NPS down 10 points) | Stop | Investigate negative effects, refine |
| **Unexpected heterogeneity** (works in CA, not NY) | Localize | Deploy only in high-performing regions |

---

## Q7: What would cause a feature launch to FAIL?

### Answer:

**Common Failure Modes:**

| Failure Mode | Example | Detection |
|--------------|---------|-----------|
| **Low Adoption** | DashPass sign-up <2% | Conversion tracking shows flatline |
| **Churn After Launch** | Users try then leave | D7/D30 retention drops vs expected |
| **Unintended Consequences** | Recs degrade for some segments | Subgroup analysis shows hurt |
| **Technical Issues** | App crashes on new feature | Session completion drops, crash logs spike |
| **Market Rejection** | Pricing too high, customers leave | NPS drops, support tickets surge |
| **Competitive Response** | Competitor launches similar, better | Market share flat/declining despite launch |
| **Cannialization** | Feature shifts but doesn't grow | Total revenue flat, just moved between tiers |
| **Economics Don't Work** | Unit economics collapse | CAC too high, margin too low |

**Early Warning Dashboard:**

```
FEATURE HEALTH SCORECARD

Feature: DashPass Subscription
Launch Date: Jan 2026
Current Date: Jan 31, 2026

┌────────────────────────────────────────────┐
│ Metric              | Target | Actual | ⚠️  │
├────────────────────────────────────────────┤
│ Subscriber growth   | 50K    | 35K    | ⚠️ │
│ D7 retention        | 65%    | 62%    | ✓  │
│ Repeat rate (sub)   | 25%    | 22%    | ⚠️ │
│ NPS (vs non-sub)    | +5     | +2     | ⚠️ │
│ App stability       | 99%    | 98.5%  | ✓  │
│ CAC payback         | 4mo    | 5mo    | ⚠️ │
│ Churn rate          | <2%    | 3.2%   | ⚠️ │
│                                           │
│ OVERALL: Yellow (Monitor closely)         │
│ Recommendation: Focus on engagement       │
│ campaigns, fix repeat rate stagnation     │
│                                           │
└────────────────────────────────────────────┘
```

---

## Q8: How would you prioritize features to launch?

### Answer:

**Prioritization Framework (RICE Score):**

```
RICE = (Reach × Impact × Confidence) / Effort

Feature Evaluation:

┌─────────────────────────────────────────────────────┐
│ FEATURE A: Personalized Recommendations             │
│ Reach: 500K users impacted (high)                   │
│ Impact: +10% conversion (significant)               │
│ Confidence: 80% (we tested this)                    │
│ Effort: 8 weeks (high complexity)                   │
│                                                     │
│ RICE Score: (500K × 10% × 80%) / 8 weeks = 500K    │
│                                                     │
├─────────────────────────────────────────────────────┤
│ FEATURE B: One-click reorder                        │
│ Reach: 1.5M users impacted (very high)              │
│ Impact: +5% repeat rate (moderate)                  │
│ Confidence: 90% (very clear benefit)                │
│ Effort: 2 weeks (low complexity)                    │
│                                                     │
│ RICE Score: (1.5M × 5% × 90%) / 2 weeks = 3.375M   │
│                                                     │
├─────────────────────────────────────────────────────┤
│ FEATURE C: Advanced filters                         │
│ Reach: 300K users (niche need)                      │
│ Impact: +3% conversion for them (low)               │
│ Confidence: 70% (untested)                          │
│ Effort: 4 weeks                                     │
│                                                     │
│ RICE Score: (300K × 3% × 70%) / 4 weeks = 157.5K   │
│                                                     │
└─────────────────────────────────────────────────────┘

RANKING:
1. Feature B (One-click reorder) - 3.375M [HIGHEST ROI]
2. Feature A (Personalized recs) - 500K
3. Feature C (Advanced filters) - 157.5K

ACTION: Prioritize Feature B - highest impact relative to effort
```

---

## Summary: Feature Launch & Success Measurement

1. **Define clear goals**: What problem does the feature solve?
2. **Establish success metrics**: Primary, secondary, and guardrail metrics
3. **Measure impact rigorously**: A/B tests, statistical significance, subgroup analysis
4. **Track adoption**: Monitor conversion, retention, engagement
5. **Watch for failures**: Early warning signals, cannialization, tech issues
6. **Prioritize portfolio**: Use RICE scoring to decide what to build next
7. **Iterate**: Most features need refinement based on real-world data

