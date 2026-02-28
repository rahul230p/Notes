# 🧪 DoorDash – Business Partner: Experimentation & A/B Testing

## Problem Statement
How would you set up an experiment/A/B test for [e.g., a pricing change, new feature, or promo]? What's the statistical framework? How do you interpret results?

---

## Q1: When should you run an A/B test vs just launch?

### Answer:

**Decision Tree:**

```
SHOULD WE A/B TEST?

┌─────────────────────────────────────────┐
│ Is this a MAJOR change?                 │
│ (Could significantly impact business)   │
│ ✓ YES → Continue                        │
│ ✗ NO → Launch with monitoring           │
│                                         │
├─────────────────────────────────────────┤
│ Do we understand the IMPACT?            │
│ (Can predict effect size?)              │
│ ✓ CONFIDENT → Direct rollout possible   │
│ ? UNCERTAIN → A/B test recommended      │
│                                         │
├─────────────────────────────────────────┤
│ Is there DOWNSIDE RISK?                 │
│ (Could hurt if it fails?)               │
│ ✓ YES → Test first                      │
│ ✗ NO → Can launch to learn              │
│                                         │
├─────────────────────────────────────────┤
│ Do we have SAMPLE SIZE?                 │
│ (Enough users/time for statistical sig?)│
│ ✓ YES → Can run proper test             │
│ ✗ NO → Direct rollout, monitor closely  │
│                                         │
└─────────────────────────────────────────┘

EXAMPLES:

Launch Directly (Low Risk):
├─ Bug fix that improves experience
├─ UI improvement (clearer, faster)
├─ New restaurant added to city
└─ Customer support messaging improvement

A/B Test Required (Medium/High Risk):
├─ Pricing change (revenue sensitive)
├─ Promotional strategy (budget impact)
├─ Algorithm change (could hurt UX)
├─ Feature rollout (adoption uncertain)
└─ Dasher pay changes (retention risk)

Monitor After Launch (Learning Mode):
├─ New vertical/geography (new market)
├─ Experimental feature (exploratory)
└─ Beta program (limited rollout)
```

---

## Q2: What's the anatomy of a proper A/B test?

### Answer:

**A/B Test Components:**

```
┌──────────────────────────────────────────────────────────┐
│             A/B TEST DESIGN FRAMEWORK                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ 1. HYPOTHESIS                                           │
│    ┌──────────────────────────────────────────────┐     │
│    │ "Decreasing delivery fees from $2.99 to $1.99│     │
│    │  will increase order frequency by 15% without│     │
│    │  significantly harming profitability."       │     │
│    │                                              │     │
│    │ Assumptions:                                 │     │
│    │ • Price elasticity ~-1.5 (assumed)          │     │
│    │ • Customer won't substitute competitors      │     │
│    │ • Merchant satisfaction won't drop           │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 2. PRIMARY METRIC (what we're optimizing for)           │
│    ┌──────────────────────────────────────────────┐     │
│    │ Primary: Order frequency (orders/user/month) │     │
│    │ Current baseline: 2.1 orders/month           │     │
│    │ Expected uplift: 15% → 2.4 orders/month      │     │
│    │ What counts as success? ≥12% uplift (to be   │     │
│    │ conservative)                                │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 3. SECONDARY METRICS (to ensure no unintended harm)     │
│    ┌──────────────────────────────────────────────┐     │
│    │ • AOV (ensure prices don't drop disproportionately) │
│    │ • Repeat rate (ensure engagement stays strong)     │
│    │ • Dasher satisfaction (ensure earnings don't hit)  │
│    │ • Customer NPS (ensure satisfaction intact)        │
│    │ • Merchant complaints (ensure quality stable)      │
│    │ • Profitability (contribution margin)             │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 4. GUARDRAIL METRICS (stop the test if violated)        │
│    ┌──────────────────────────────────────────────┐     │
│    │ • AOV drops >3% → Stop (erosion too high)   │     │
│    │ • NPS drops >5 points → Stop (satisfaction) │     │
│    │ • Dasher churn >6% → Stop (supply risk)    │     │
│    │ • Contribution margin <15% → Stop (econ)   │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 5. SAMPLE SIZE & DURATION                               │
│    ┌──────────────────────────────────────────────┐     │
│    │ Power Analysis:                              │     │
│    │ • Baseline: 2.1 orders/month                │     │
│    │ • Effect size: 0.3 (15% improvement)        │     │
│    │ • Significance level: α = 0.05 (95%)        │     │
│    │ • Statistical power: β = 0.8 (80%)          │     │
│    │ • Result: Need 50K users per arm            │     │
│    │                                             │     │
│    │ Duration:                                   │     │
│    │ • 50K users × 40% weekly active = 125K WAU │     │
│    │ • Split 50/50 → 62.5K needed per arm       │     │
│    │ • At 10K new users/day → 6-7 days          │     │
│    │ → Run for 2 weeks (cover full week cycles) │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 6. RANDOMIZATION & STRATIFICATION                       │
│    ┌──────────────────────────────────────────────┐     │
│    │ Randomization Method:                       │     │
│    │ • User ID hash (deterministic, repeatable) │     │
│    │ • 50% hash % 2 == 0 → Control              │     │
│    │ • 50% hash % 2 == 1 → Variant              │     │
│    │                                             │     │
│    │ Stratification (ensure balance):            │     │
│    │ • By city (NYC behaves differently)        │     │
│    │ • By cohort (new vs old users)             │     │
│    │ • By device (iOS vs Android vs web)        │     │
│    │                                             │     │
│    │ Lock-in: Users stay in same group for      │     │
│    │ entire test duration                        │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 7. EXECUTION & MONITORING                               │
│    ┌──────────────────────────────────────────────┐     │
│    │ Weekly Monitoring:                          │     │
│    │ • Check sample sizes match (if not, debug) │     │
│    │ • Check metric trends (sanity check)       │     │
│    │ • Look for anomalies (technical issues?)   │     │
│    │                                             │     │
│    │ Daily Monitoring (Week 1):                 │     │
│    │ • Primary metric trending correctly?       │     │
│    │ • Any guardrail metrics violated?          │     │
│    │ • Technical issues, crashes?               │     │
│    │                                             │     │
│    │ Early Stopping Rule:                       │     │
│    │ • If statistical significance reached       │     │
│    │   before end (e.g., day 5), can call       │     │
│    │   the test, don't need full 2 weeks        │     │
│    │                                             │     │
│    │ BUT: Risk of overoptimism bias, usually    │     │
│    │ worth running full duration for trust      │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
├──────────────────────────────────────────────────────────┤
│ 8. ANALYSIS & INTERPRETATION                            │
│    ┌──────────────────────────────────────────────┐     │
│    │ Statistical Test:                           │     │
│    │ • T-test or chi-square (depends on metric) │     │
│    │ • Significance threshold: p < 0.05         │     │
│    │ • Report: Effect size, 95% CI              │     │
│    │                                             │     │
│    │ Results:                                    │     │
│    │ If p < 0.05 → Statistically significant ✓  │     │
│    │ If p > 0.05 → Not significant (no change)  │     │
│    │                                             │     │
│    │ Decision:                                   │     │
│    │ • Is it practically significant?            │     │
│    │   (12% uplift meets our threshold)          │     │
│    │ • Are guardrails OK?                       │     │
│    │   (No negative side effects?)               │     │
│    │ • Subgroup analysis: Works everywhere?     │     │
│    └──────────────────────────────────────────────┘     │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Q3: How do you calculate sample size?

### Answer:

**Sample Size Formula & Example:**

```
POWER ANALYSIS INPUTS:

Baseline Conversion Rate (p₁): 2.1 orders/month
Expected Uplift: 15%
Effect Size: d = 0.3 (Cohen's d)
Significance Level (α): 0.05 (95% confidence)
Statistical Power (1-β): 0.80 (80% power to detect effect)

Formula: n = (Zα/2 + Zβ)² × (p₁(1-p₁) + p₂(1-p₂)) / (p₁ - p₂)²

Where:
Zα/2 = 1.96 (95% confidence)
Zβ = 0.84 (80% power)

Calculation:
n = (1.96 + 0.84)² × (2.1×0.79 + 2.4×0.76) / (2.1 - 2.4)²
n = 7.84 × (1.66 + 1.82) / 0.09
n ≈ 50,000 per group

SAMPLE SIZE TABLE (Common scenarios):

Uplift Desired | Current | Target | Sample/Arm
─────────────────────────────────────────────
    5%        | 10%    | 10.5%  | 150K
   10%        | 10%    | 11%    | 40K
   15%        | 2.1    | 2.4    | 50K
   20%        | 50%    | 60%    | 4K
   25%        | 50%    | 62.5%  | 2.5K

Lower baseline rate → need bigger sample
Smaller uplift → need bigger sample
Want higher confidence → need bigger sample
```

---

## Q4: How do you interpret A/B test results?

### Answer:

**Results Interpretation Framework:**

```
SCENARIO 1: CLEAR WINNER (Recommended Path)

Control Group (Baseline):
├─ Orders/month: 2.1
├─ Confidence interval: 2.08 - 2.12
└─ Sample: 50,000 users

Treatment Group (Reduced Fee):
├─ Orders/month: 2.45
├─ Confidence interval: 2.43 - 2.47
└─ Sample: 50,000 users

Statistical Analysis:
├─ Difference: 0.35 orders/month (+16.7%)
├─ P-value: 0.0001 (highly significant, p < 0.05) ✓
├─ Effect size: 0.28 (medium effect)
└─ 95% CI: [0.32 - 0.38]

Secondary Metrics:
├─ AOV: -0.8% (within tolerance, <3% guard)
├─ Repeat rate: +1.2% (positive!)
├─ NPS: +0.5 (minimal change, OK)
├─ Dasher satisfaction: -1.2% (within range)
├─ Contribution margin: 18.2% (target 20%, slight miss but acceptable)

Guardrail Check:
├─ AOV drop > 3%? NO ✓
├─ NPS drop > 5? NO ✓
├─ Dasher churn > 6%? NO ✓
├─ Margin < 15%? NO ✓

DECISION: LAUNCH
└─ Clear winner with no major side effects
   Go to 100% rollout, monitor for 2 weeks


SCENARIO 2: UNCLEAR RESULT (Need More Analysis)

Control: 2.1 orders/month
Treatment: 2.18 orders/month (+3.8%)
P-value: 0.087 (not statistically significant at p<0.05)

Interpretation:
├─ Could be real (3.8% lift) but not confident
├─ 91% confidence (not our 95% bar)
├─ With more time, could become significant
├─ Or real effect is smaller than expected

Next Steps:
├─ Option 1: Run test longer (2 more weeks)
│  └─ Increase sample size, get more confidence
│
├─ Option 2: Check for subgroups
│  ├─ Does it work in NYC but not LA?
│  ├─ Works for new users but not power users?
│  └─ This reveals targeting opportunity
│
├─ Option 3: Accept uncertainty, deploy to segment
│  ├─ If low-risk change, try in 10% of market
│  ├─ Monitor for 2 weeks
│  └─ Full rollout if results hold
│
└─ Option 4: Don't launch, try different approach


SCENARIO 3: NEGATIVE RESULT (Don't Launch)

Control: 2.1 orders/month
Treatment: 1.98 orders/month (-5.7%)
P-value: 0.001 (statistically significant, negative)

Secondary Metrics:
├─ AOV: -2.1% (slightly down, OK)
├─ Repeat rate: -2.8% (concerning!)
├─ NPS: -3.2 (moderate drop)
├─ Dasher earnings: -8% (major impact)

Guardrail Violations:
├─ Dasher churn: 6.8% (exceeds 6% guardrail) ⚠️

DECISION: DO NOT LAUNCH
└─ Clear negative effect on frequency and dasher retention
   Return to drawing board, try different approach


SCENARIO 4: MIXED RESULTS (Heterogeneous Treatment Effect)

Overall:
├─ Control: 2.1 orders/month
├─ Treatment: 2.15 orders/month (+2.4%)
├─ P-value: 0.12 (not significant overall)

Subgroup Analysis:
├─ Power Users (4+ orders/month):
│  └─ Treatment: -1.2% (NEGATIVE) ⚠️
│
├─ Regular Users (2-3 orders/month):
│  └─ Treatment: +8.5% (POSITIVE) ✓
│
├─ Occasional Users (1-2 orders/month):
│  └─ Treatment: +12.3% (STRONG POSITIVE) ✓

DECISION: PARTIAL LAUNCH
├─ Launch for Occasional & Regular users
├─ Keep control for Power users (they're not elastic)
├─ This targets the customers most responsive to price
├─ Conditional rollout by segment = targeted approach
└─ Monitoring: Watch power user frequency closely


SCENARIO 5: GUARDRAIL VIOLATION (Stop Test)

Primary Metric:
├─ Control: 2.1 orders/month
├─ Treatment: 2.28 orders/month (+8.6%)
├─ Result: POSITIVE! ✓

BUT Guardrail Metric Violated:
├─ Dasher Churn: 6.5% (guardrail: <6%)
├─ Contribution Margin: 14.8% (guardrail: >15%)

DECISION: DO NOT LAUNCH (despite positive primary metric)
├─ Reason: Unacceptable cost to other stakeholders
├─ The primary win isn't worth losing drivers/margin
├─ Options:
│  ├─ Reduce discount magnitude (offer $1.50 instead of $1)
│  ├─ Limit discount to certain times/places
│  ├─ Pair with dasher pay increase
│  └─ Retest with modifications
└─ Lesson: Holistic view, not just primary metric
```

---

## Q5: How do you handle multiple comparisons?

### Answer:

**Multiple Testing Problem:**

```
THE PROBLEM: Multiple Comparison Inflation

If you test 20 secondary metrics at p<0.05 significance level:
├─ Expected false positives by chance: 20 × 0.05 = 1 metric
├─ Chance of at least one false positive: 64%
├─ You'll see something "significant" by chance alone
└─ This inflates Type I error (false positives)

SOLUTION: Multiple Comparison Correction

Option 1: Bonferroni Correction
├─ Adjust significance threshold for each metric
├─ New threshold: α / number_of_metrics
├─ Example: 0.05 / 20 = 0.0025 per test
├─ Pro: Conservative, prevents false positives
├─ Con: Very strict, might miss real effects (Type II error)

Option 2: Control Family-Wise Error Rate (FWER)
├─ Same as Bonferroni but slightly less strict
├─ Use Holm-Bonferroni: Still multiple testing adjustment
└─ Slightly better power than Bonferroni

Option 3: False Discovery Rate (FDR)
├─ Control % of false positives among all positives
├─ Less strict than FWER (more power)
├─ Better for exploratory analysis
├─ Example: Benjamini-Hochberg procedure
└─ Preferred for many secondary metrics

RECOMMENDATION AT DOORDASH:

Metric Categories:
├─ PRIMARY METRIC: No correction, use α=0.05
│  └─ This is what we optimized for
│
├─ SECONDARY METRICS (5-10 metrics): 
│  └─ Use FDR control (less strict)
│
├─ GUARDRAIL METRICS:
│  └─ One-sided test, directional check only
│  └─ Higher threshold (only alert on major violations)
│
└─ EXPLORATORY METRICS:
   └─ Report but don't use for decision
   └─ Hypothesis-generating only

EXAMPLE IMPLEMENTATION:

Test Results (20 secondary metrics):
├─ Metric 1 p=0.001 → SIGNIFICANT ✓
├─ Metric 2 p=0.012 → Check FDR correction
├─ Metric 3 p=0.045 → Check FDR correction
├─ ...
└─ Metric 20 p=0.91 → NOT SIGNIFICANT

Apply Benjamini-Hochberg (FDR α=0.05):
├─ Sort p-values
├─ Find largest i where p[i] ≤ (i/20)×0.05
├─ All tests with p ≤ this threshold are significant
└─ Protects against spurious findings while keeping power
```

---

## Q6: How do you account for seasonality?

### Answer:

**Seasonality Handling:**

```
PROBLEM: Seasonal Effects Confound Results

Example: Testing a new feature in December
├─ Holiday shopping surge (external to feature)
├─ Makes metrics look better than reality
├─ Can't tell if feature helps or just holiday boost

SOLUTIONS:

Option 1: Test During Off-Seasons
├─ Run test in "normal" week (Jan, Oct)
├─ Avoid: Holidays, major events, paydays
└─ Results more representative of steady state

Option 2: Year-over-Year Comparison
├─ Compare treatment week vs same week last year
├─ Baseline: Last December's performance
├─ Metric: This Dec vs Last Dec (in treatment group)
└─ Controls for seasonal pattern

Option 3: Seasonal Adjustment
├─ Remove seasonal component statistically
├─ Use time-series decomposition
├─ Compare "deseasonalized" metrics
└─ More complex but works with ongoing test

Option 4: Block Design
├─ Include multiple weeks of each type
├─ 1 week holiday, 1 week normal, 1 week low-demand
├─ Average out seasonal effects
└─ Longer test but more robust

Option 5: Stratified Sample
├─ Stratify by day-of-week in randomization
├─ Ensure each arm has similar day distribution
├─ Balance Monday/Tuesday/Wed/etc. across arms
└─ Simpler than deseasonalization

RECOMMENDATION:

For Most Tests at DoorDash:
├─ Option 1 (avoid known seasons) if possible
│  └─ Simplest, cleanest interpretation
│
├─ Option 5 (stratified by day-of-week) otherwise
│  └─ Accounts for weekly seasonality
│  └─ Still simple, improves robustness
│
└─ Document any seasonal effects
   └─ Helps contextualize results
```

---

## Q7: How do you handle network effects?

### Answer:

**Network Effect Problem:**

```
PROBLEM: Users interact with each other

Example: Testing recommendation algorithm
├─ New algorithm shows Restaurant A to users
├─ Restaurant A gets more orders
├─ This makes Restaurant A appear in more recommendations
├─ Which increases its visibility organically
├─ Hard to separate "algorithm effect" from "popularity feedback"

Network Effects at DoorDash:
├─ Dasher-user: More dashers → faster delivery → attracts users
├─ User-user: Popular restaurants → network effects
├─ Merchant-user: New merchants → more options
└─ These effects compound and create spillovers

SOLUTIONS:

Option 1: Cluster-Randomization (Geographic)
├─ Randomize at city or neighborhood level
├─ Entire neighborhood gets treatment
├─ Users within city still interact, but can't "contaminate" control group in different city
├─ Pro: Captures network effects properly
├─ Con: Need many cities for statistical power

Option 2: Temporal Separation
├─ Test in one city Week 1-2
├─ Launch in different city Week 3-4
├─ No simultaneous competition between arms
├─ Pro: Simpler, cleaner
├─ Con: Takes longer, seasonal confounds

Option 3: Marketplace Segmentation
├─ Restaurant-level randomization
├─ Some restaurants get new algo, some don't
├─ Users see mixed recommendations
├─ Hard to separate effects but captures some spillover

Option 4: Account for Spillover Statistically
├─ Model spillover effects explicitly
├─ Use econometric methods
├─ More complex but doable
└─ Report direct + spillover effects

RECOMMENDATION AT DOORDASH:

Dasher Supply Tests:
├─ Use cluster-randomization by city
├─ Can't A/B test driver supply in same neighborhood
├─ Different cities = independent markets

User-facing Feature Tests:
├─ User-level randomization acceptable
├─ Network effects usually small for individual user experience
├─ But use cluster for marketplace-wide changes

Merchant Tests:
├─ Restaurant-level randomization
├─ Some restaurants see new feature, users see mix
├─ Captures equilibrium effects better
```

---

## Q8: When is a test result actionable?

### Answer:

**Actionability Decision Matrix:**

```
STATISTICAL SIGNIFICANCE + PRACTICAL SIGNIFICANCE + CLEAR DECISION

┌────────────────────────────────────────────────────────┐
│ Statistically Significant? (p < 0.05)                 │
├────────────────────────────────────────────────────────┤
│ YES                           │  NO                    │
├───────────────────────────────┼────────────────────────┤
│ Practically Significant?      │ Could be real, just    │
│ (Effect size > threshold?)    │ not enough power       │
│                               │                        │
│ YES      │     NO            │  Decision: Don't launch│
│          │                   │  unless low-risk       │
│          │                   │                        │
├──────────┼───────────────────┼────────────────────────┤
│ LAUNCH ✓ │ DON'T LAUNCH      │  Consider:             │
│ (Often) │ (Optimization)    │  • Run longer          │
│          │  Diminishing      │  • Try different angle │
│          │  return on effort │  • Segment analysis    │
│          │                   │  • Accept & monitor    │
└──────────┴───────────────────┴────────────────────────┘

EXAMPLES:

Example 1: Pricing Test (CLEAR LAUNCH)
├─ Baseline: $2.99 delivery fee
├─ Treatment: $1.99 delivery fee
├─ Result: +16.7% orders (p=0.0001)
├─ Practical significance: YES (well above 5% threshold)
├─ Guardrails: All OK
└─ DECISION: LAUNCH ✓

Example 2: UI Simplification (CLEAR LAUNCH)
├─ Baseline: 3-click checkout
├─ Treatment: 1-click checkout
├─ Result: +3.2% conversion (p=0.001)
├─ Practical significance: YES (exceeds 2% target)
├─ Guardrails: All OK
└─ DECISION: LAUNCH ✓

Example 3: Feature Flag Optimization (NO LAUNCH)
├─ Baseline: 50% features A on/off
├─ Treatment: 60% features A on
├─ Result: +0.8% conversion (p=0.032)
├─ Practical significance: NO (too small)
├─ Not worth complexity for 0.8% gain
└─ DECISION: DON'T LAUNCH (accept baseline) ✗

Example 4: New Restaurant Search (SEGMENT LAUNCH)
├─ Baseline: Traditional search
├─ Treatment: AI search
├─ Overall: +1.5% conversion (p=0.089, not sig)
├─ BUT: Power users +8%, Casual users -1%
├─ Practical significance: YES for power users segment
└─ DECISION: LAUNCH for power users, keep control for casual ≈

Example 5: Dasher Incentive (MONITOR & ITERATE)
├─ Baseline: $0.50/delivery bonus
├─ Treatment: $1.00/delivery bonus
├─ Result: +4.2% dasher supply (p=0.15, not significant)
├─ Cost: $X million / day
├─ Could be real but expensive to confirm
└─ DECISION: Don't commit to full rollout yet
   Run in 5 cities for 2 weeks, then decide
```

---

## Summary: A/B Testing Best Practices

1. **Define hypothesis clearly**: What are we testing and why?
2. **Set success metrics**: Primary (what we optimize), secondary (safety checks), guardrails (stop points)
3. **Calculate sample size**: Use power analysis, don't fly blind
4. **Randomize properly**: Stratify to ensure balance
5. **Monitor continuously**: Watch for anomalies, guardrail violations
6. **Interpret with confidence**: Statistical significance + practical significance
7. **Adjust for multiple testing**: Use FDR for many secondary metrics
8. **Account for confounds**: Seasonality, network effects, spillovers
9. **Make clear decisions**: Launch, iterate, or don't launch based on data
10. **Document everything**: Hypothesis, results, lessons for next time

