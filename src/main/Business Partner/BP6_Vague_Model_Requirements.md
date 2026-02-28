# 🔍 DoorDash – Business Partner: Data Models & Dashboards for Vague Asks

## Problem Statement
A business partner asks you to build a model/dashboard for [vague ask, e.g., predicting recommendations, fraud detection, or personalization]. Walk me through your questions and approach.

---

## Q1: How do you approach a VAGUE requirement?

### Answer:

**Handling Vague Requirements Framework:**

```
VAGUE ASK RECEIVED
         ↓
    ┌────────────────────────────────────┐
    │  STEP 1: CLARIFY THE PROBLEM       │
    │  - What's the business problem?    │
    │  - Who are the stakeholders?       │
    │  - What decision will this enable? │
    │  - What's the success metric?      │
    └────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────┐
    │  STEP 2: UNDERSTAND SCOPE          │
    │  - Who is the user? (Ops, Exec?)   │
    │  - How will it be used?            │
    │  - Real-time vs batch?             │
    │  - Accuracy requirements?          │
    └────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────┐
    │  STEP 3: SCOPE THE DATA            │
    │  - What data exists?               │
    │  - Data quality/completeness?      │
    │  - Data latency?                   │
    │  - Privacy constraints?            │
    └────────────────────────────────────┘
         ↓
    ┌────────────────────────────────────┐
    │  STEP 4: PROPOSE SOLUTION          │
    │  - MVP approach first              │
    │  - Clear success criteria          │
    │  - Timeline & effort estimate      │
    └────────────────────────────────────┘
```

**Key Questions to Ask:**

| Category | Questions |
|----------|-----------|
| **Business** | What problem are we solving? What's the current state? What decision does this enable? |
| **Users** | Who will use this? What's their technical level? How frequently will they use it? |
| **Success** | How will we measure success? What are success metrics/KPIs? |
| **Data** | What data do we have? How fresh is it? What's missing? Data quality issues? |
| **Scope** | Is this needed for real-time or batch? 1 city or all? MVP or production? |
| **Constraints** | Budget/timeline? Privacy/regulatory? Technical limitations? |

---

## Q2: Example - "Build a fraud detection model"

### Answer:

**Vague Ask: "We're losing money to fraud. Build a model to detect it."**

**Step 1: Clarifying Questions & Answers**

```
Q: What types of fraud are we seeing?
A: Stolen payment info, account takeovers, returning false items

Q: What's the financial impact?
A: ~$2M annually (0.2% of GMV)

Q: Which fraud is most damaging?
A: Stolen cards (70%), account takeovers (20%), return fraud (10%)

Q: How are we currently detecting fraud?
A: Manual review, payment processor flags

Q: What's causing the gap?
A: Too many false positives → hard to review manually

Q: What's the threshold? Better to let $100 fraud through or block 10 good orders?
A: Probably let $100 fraud through (cost of false positive too high)
```

**Step 2: Problem Definition**

```
GOAL: Reduce fraud loss to <$1M annually while maintaining <0.5% false positive rate

PRIMARY FOCUS: Stolen card transactions (70% of fraud, easiest to detect)

SUCCESS CRITERIA:
├─ Precision: 80%+ (if we flag transaction, 80%+ chance it's fraud)
├─ Recall: 60%+ (catch 60%+ of actual fraud)
├─ False positive rate: <0.5% (don't block good transactions)
└─ Latency: <100ms (decision needed in real-time)
```

**Step 3: Data Sources**

```
DATA COLLECTION

┌─────────────────────────────────────────┐
│ ORDER-LEVEL FEATURES                    │
├─────────────────────────────────────────┤
│ • Amount, restaurant, delivery address  │
│ • Device, IP, user agent                │
│ • Time of day, day of week              │
│ • User account age                      │
│ • Frequency of orders (baseline)        │
│ • Typical order amount (baseline)       │
│ • Typical restaurant type               │
│ • Location deviation (usual vs new)     │
│                                         │
├─────────────────────────────────────────┤
│ USER-LEVEL FEATURES                     │
├─────────────────────────────────────────┤
│ • Account age                           │
│ • Total lifetime orders                 │
│ • Repeat restaurant preference          │
│ • Typical ordering time                 │
│ • Geographic pattern                    │
│ • Device history                        │
│ • Payment methods used                  │
│ • Account changes (password reset, etc) │
│                                         │
├─────────────────────────────────────────┤
│ PAYMENT-LEVEL FEATURES                  │
├─────────────────────────────────────────┤
│ • Card issuer, type (Visa, Amex, etc)   │
│ • Bin (card prefix) reputation          │
│ • AVS (address verification) match      │
│ • CVV match                             │
│ • 3D Secure status                      │
│ • Processor risk score                  │
│                                         │
├─────────────────────────────────────────┤
│ LABELS (Historical Fraud)               │
├─────────────────────────────────────────┤
│ • Chargeback within 30 days             │
│ • User reported unauthorized            │
│ • Payment processor flagged              │
│ • Manual review marked as fraud         │
│                                         │
└─────────────────────────────────────────┘
```

**Step 4: Model Approach**

```
FRAUD DETECTION MODEL DESIGN

Model Type: Binary Classification
  - Input: Transaction features + user history
  - Output: Fraud probability (0-1)
  - Decision: If P(fraud) > threshold, flag for manual review

Algorithm Options:
  1. Logistic Regression (fast, interpretable)
  2. Random Forest (robust, handles non-linearities)
  3. Gradient Boosting (best accuracy, more complex)
  4. Neural Network (if feature engineering helps)

Recommended: Start with Random Forest
  - Good accuracy-interpretability trade-off
  - Can handle missing data
  - Feature importance helps debug

TRAINING DATA:
  - 6 months of historical data
  - 50K transactions (rough estimate)
  - ~100 labeled frauds (0.2% fraud rate is typical)

HANDLING CLASS IMBALANCE:
  - Use stratified sampling in train/test split
  - Use oversampling (SMOTE) or class weights
  - Use appropriate metrics (precision/recall, not accuracy)

EVALUATION:
  - Test set: Hold out last 2 weeks of data
  - Precision: TP / (TP + FP)
  - Recall: TP / (TP + FN)
  - ROC-AUC: Overall discrimination ability
  - Target: 80%+ precision, 60%+ recall
```

**Step 5: Implementation & Dashboard**

```
DEPLOYMENT PLAN

┌─────────────────────────────────────┐
│ BATCH SCORING (Nightly)             │
│ Score yesterday's transactions       │
│ Flag high-risk for team review       │
│ → Risk Report Dashboard             │
│                                     │
├─────────────────────────────────────┤
│ REAL-TIME SCORING (At payment)      │
│ Score transaction in <100ms          │
│ Auto-block if P(fraud) > 95%         │
│ Soft-decline if 70-95% (ask 3D Sec)  │
│ → Risk API                          │
│                                     │
├─────────────────────────────────────┤
│ MONITORING DASHBOARD                │
│ Daily metrics:                       │
│ - Fraud rate trending               │
│ - False positive rate               │
│ - Model precision/recall            │
│ - Key feature importance            │
│                                     │
└─────────────────────────────────────┘
```

**Step 6: Success Metrics & Monitoring**

```
FRAUD DETECTION SCORECARD

Business Metrics:
├─ Fraud loss: $2M → Target: <$1M (50% reduction)
├─ False positive rate: 5% → Target: <0.5%
└─ Good transactions blocked: 2% → Target: <0.5%

Model Metrics:
├─ Precision: 80%+ (trust the model's predictions)
├─ Recall: 60%+ (catch most fraud)
├─ ROC-AUC: 0.85+ (overall discrimination)
└─ Model drift: Monitor feature distributions

Monitoring Queries:
├─ Weekly precision/recall on holdout set
├─ Monthly retraining to capture new fraud patterns
├─ Quarterly manual audit of false positives
└─ Ongoing feedback loop with fraud team

ALERT THRESHOLDS:
├─ If precision drops below 75% → Investigate
├─ If fraud loss increases by 20% → Retrain
├─ If false positive rate exceeds 1% → Dial back
```

---

## Q3: Example - "Build a personalization/recommendation model"

### Answer:

**Vague Ask: "How do we make personalized recommendations to each user?"**

**Step 1: Clarifying Questions**

```
Q: What should we recommend?
A: Restaurants to order from

Q: Where will recommendations appear?
A: Home screen (top 5 restaurants), search results

Q: How do we measure success?
A: Higher CTR on recs, more orders, better AOV

Q: What's the current baseline?
A: Random or trending restaurants shown

Q: How often do recommendations change?
A: Daily refresh for each user
```

**Step 2: Problem Definition**

```
GOAL: Show most relevant restaurants to each user
       → Higher CTR (8% vs current 3%)
       → Higher conversion to order (15% vs current 8%)

SUCCESS CRITERIA:
├─ CTR increase: >50% lift
├─ Conversion lift: >15%
├─ AOV impact: No negative impact or +5%
└─ Diversity: Users still try new restaurants
```

**Step 3: Data Sources**

```
RECOMMENDATION DATA MODEL

┌──────────────────────────────────────┐
│ USER FEATURES                        │
├──────────────────────────────────────┤
│ • Past order history (restaurants)   │
│ • Cuisine preferences                │
│ • Typical order time                 │
│ • Price sensitivity (AOV analysis)   │
│ • Dietary preferences (if known)     │
│ • Ratings (which restaurants rated?) │
│ • Geographic location                │
│ • Device type                        │
│                                      │
├──────────────────────────────────────┤
│ RESTAURANT FEATURES                  │
├──────────────────────────────────────┤
│ • Cuisine type                       │
│ • Average rating                     │
│ • Delivery time                      │
│ • Price level ($, $$, $$$)           │
│ • Recent order volume                │
│ • Trending (getting popular?)        │
│ • New merchant (if just launched)    │
│ • Promotions active                  │
│                                      │
├──────────────────────────────────────┤
│ INTERACTION FEATURES                 │
├──────────────────────────────────────┤
│ • User clicked restaurant X?         │
│ • How many times user ordered there? │
│ • Time since last order              │
│ • Rating user left for restaurant    │
│ • Similar users ordered what?        │
│                                      │
└──────────────────────────────────────┘
```

**Step 4: Model Approach**

```
COLLABORATIVE FILTERING vs CONTENT-BASED vs HYBRID

COLLABORATIVE FILTERING
├─ Idea: "Users similar to you liked restaurant X"
├─ Data: User-restaurant interaction matrix
├─ Pro: Discovers new restaurants, good serendipity
├─ Con: Cold start (new users/restaurants)
└─ Algorithm: Matrix factorization, KNN

CONTENT-BASED
├─ Idea: "You liked Thai, these are similar Thai restaurants"
├─ Data: Restaurant features + user preferences
├─ Pro: Works for new restaurants, explainable
├─ Con: Limited discovery, "filter bubble"
└─ Algorithm: Similarity scoring

HYBRID APPROACH (RECOMMENDED)
├─ Combine both: 60% collaborative, 40% content
├─ Advantages: Coverage + discovery + relevance
├─ Handles cold start: New restaurant scores high on content
├─ Ensures diversity: Don't show only past favorites

RANKING APPROACH:
Step 1: Generate candidates (100 restaurants)
        ├─ Collaborative filtering (50)
        ├─ Content-based similar to past favorites (30)
        ├─ Trending/popular (20)
        └─ Sponsored (10)

Step 2: Rank candidates by predicted score
        ├─ User likelihood to order
        ├─ AOV prediction
        ├─ Diversity bonus (penalize too similar to past)
        └─ Business metrics (margin, inventory)

Step 3: Return top 5 for home screen
```

**Step 5: Implementation**

```
ARCHITECTURE

┌──────────────────────────────────┐
│ OFFLINE BATCH PROCESSING        │
│ (Daily, computes recommendations) │
├──────────────────────────────────┤
│ 1. Load user-restaurant data     │
│ 2. Train collaborative filtering │
│ 3. Compute similarity matrix     │
│ 4. Generate top-K per user       │
│ 5. Store in cache/DB             │
│                                  │
└────────┬─────────────────────────┘
         ▼
┌──────────────────────────────────┐
│ ONLINE RETRIEVAL (Real-time)     │
│ (When user opens app)            │
├──────────────────────────────────┤
│ 1. Look up pre-computed recs     │
│ 2. Apply real-time context       │
│    (time of day, location)       │
│ 3. Personalize ranking           │
│ 4. Return top 5 in <100ms        │
│                                  │
└────────┬─────────────────────────┘
         ▼
┌──────────────────────────────────┐
│ FEEDBACK LOOP                    │
│ (Track performance)              │
├──────────────────────────────────┤
│ • Click on recommendation?       │
│ • Ordered from recommended?      │
│ • Rating after order?            │
│ • Use to retrain model           │
│                                  │
└──────────────────────────────────┘
```

**Step 6: Dashboard**

```
RECOMMENDATION SYSTEM DASHBOARD

┌──────────────────────────────────────────┐
│ KEY METRICS (Real-Time)                  │
├──────────────────────────────────────────┤
│ • Recommendation CTR: 8.2% (Target 8%) ✓ │
│ • Conversion Rate: 16% (Target 15%) ✓    │
│ • Avg Order Value: $38 (stable) ✓       │
│ • Diversity Score: 65% (new restaurants)│
│                                          │
├──────────────────────────────────────────┤
│ MODEL PERFORMANCE                        │
├──────────────────────────────────────────┤
│ • Precision@5: 72%                       │
│ • Recall: 45%                            │
│ • Ranking loss: 0.12                     │
│ • Model drift: Low                       │
│                                          │
├──────────────────────────────────────────┤
│ BY SEGMENT                               │
├──────────────────────────────────────────┤
│ • Power users: 85% recommendation use    │
│ • New users: 35% recommendation use      │
│ • Price-sensitive: Thai, Indian (top)    │
│ • Premium segment: Upscale restaurants   │
│                                          │
└──────────────────────────────────────────┘
```

---

## Q4: Example - "Build a model for [other vague ask]"

### Answer:

**General Framework for ANY Vague Model Request:**

```
FOR ANY VAGUE MODELING ASK:

STEP 1: Define Success
├─ What problem are we solving?
├─ How will we measure success?
└─ What's the business impact?

STEP 2: Understand Data
├─ What raw data exists?
├─ What's the quality?
├─ What's the latency?
└─ Do we have labels (if supervised)?

STEP 3: Propose Approach
├─ Problem type: Classification? Regression? Ranking?
├─ Algorithm: Simple first (logistic) → Complex
├─ Data prep: Features, transformations, validation split
└─ Baseline: How do we currently solve this?

STEP 4: Plan Experiments
├─ MVP first (simple model, 60% accuracy)
├─ Then iterate (refine features, try new algorithms)
├─ A/B test impact (offline vs online evaluation)
└─ Monitor in production (drift, feedback loop)

STEP 5: Build Dashboard & Monitor
├─ Track model performance (precision, recall, etc)
├─ Track business impact (revenue, conversion, etc)
├─ Set up alerts (if model degrades)
└─ Iterate based on feedback
```

---

## Q5: Common Modeling Use Cases at DoorDash

### Answer:

**Pre-built Frameworks for Common Asks:**

| Use Case | Goal | Model Type | Key Metrics |
|----------|------|-----------|-------------|
| **Fraud Detection** | Flag suspicious transactions | Classification | Precision, Recall, False Positive Rate |
| **Recommendation** | Show relevant restaurants | Ranking | CTR, Conversion, AOV |
| **Churn Prediction** | Identify users likely to leave | Classification | Precision, Recall, AUC |
| **Demand Forecasting** | Predict orders by hour/area | Regression | MAE, RMSE, MAPE |
| **Dasher Availability** | Predict driver willingness | Classification/Regression | Accuracy, precision at different thresholds |
| **Delivery Time** | Estimate time to customer | Regression | RMSE, P90 accuracy |
| **Price Optimization** | Suggest dynamic pricing | Optimization | Revenue per order, elasticity |
| **Customer Lifetime Value** | Predict user value | Regression | Correlation with actual LTV, decile analysis |
| **Restaurant Ranking** | Sort restaurants by relevance | Ranking | Click-through rate, conversion |

---

## Q6: How would you present a vague ask to your team?

### Answer:

**From Vague → Clear Scope Document:**

```
PROJECT: Fraud Detection Model

┌────────────────────────────────────────┐
│ 1. PROBLEM STATEMENT                   │
│                                        │
│ Current state: $2M fraud loss annually │
│ Goal: Reduce to <$1M                  │
│ Approach: Build ML fraud detection     │
│                                        │
├────────────────────────────────────────┤
│ 2. SUCCESS CRITERIA                    │
│                                        │
│ Primary: 80%+ precision, 60%+ recall   │
│ Secondary: <0.5% false positive rate   │
│ Business: 50% reduction in fraud loss  │
│                                        │
├────────────────────────────────────────┤
│ 3. DATA & SCOPE                        │
│                                        │
│ Data available: Yes (6 months history) │
│ Latency requirement: <100ms real-time  │
│ Scale: 10M orders/day                  │
│ Initial scope: Stolen card fraud (70%) │
│                                        │
├────────────────────────────────────────┤
│ 4. TIMELINE                            │
│                                        │
│ Week 1-2: Data exploration, features   │
│ Week 3-4: Model training, evaluation   │
│ Week 5: Integration, testing           │
│ Week 6: Launch MVP, monitor            │
│                                        │
├────────────────────────────────────────┤
│ 5. TEAM & EFFORT                       │
│                                        │
│ Data engineer: 2 weeks (features)      │
│ ML engineer: 4 weeks (model, deploy)   │
│ Analytics: 1 week (monitoring)         │
│ Ops: 1 week (integration)              │
│                                        │
└────────────────────────────────────────┘
```

---

## Summary: Approach to Vague Model Requests

1. **Ask clarifying questions first**: Business problem, success metrics, data availability
2. **Define scope explicitly**: MVP approach, realistic targets, clear success criteria
3. **Propose solution framework**: Problem type, algorithm, data sources, timeline
4. **Start simple**: Baseline model first (logistic regression, rules), iterate up
5. **Build monitoring**: Track model performance + business impact
6. **Iterate continuously**: Feedback loop from users, refine based on data
7. **Document everything**: Clear scope, success criteria, lessons learned

