# 📚 Data Engineer / Analytics Engineer - Business Partner Round Guide

## Overview
This is a **comprehensive master file** for the **Data Engineer / Analytics Engineer Business Partner round** at DoorDash.

**What This Round Tests:**
- How you think through ambiguous problems WITH cross-functional teams
- Communication style: Can you explain technical concepts to non-technical people?
- Collaboration: How do you work with Product, Operations, and Business teams?
- Data quality & modeling thinking
- Iteration & feedback incorporation
- Real project experience working with stakeholders

---

## 🎯 Round Overview

**Duration**: 45 minutes  
**Format**: Highly interactive, scenario-based  
**Interviewer**: Usually a Business Partner or PM who works cross-functionally  
**Goal**: Assess your ability to:
1. Understand ambiguous business problems
2. Translate them to data solutions
3. Communicate effectively across functions
4. Iterate based on feedback
5. Focus on business impact, not just technical elegance

---

## 📋 What the Interviewer is Evaluating (For Data Engineers)

| Criterion | What They're Looking For | Red Flags |
|-----------|-------------------------|-----------|
| **Problem Understanding** | Do you ask clarifying questions? Do you break down ambiguous problems? | Jump to technical solution without understanding business need |
| **Communication** | Can you explain technical concepts simply? Can non-technical people follow you? | Use jargon, too technical, unclear explanations |
| **Data Thinking** | Do you think about data quality, modeling, schemas? | Ignore data challenges, assume data is perfect |
| **Cross-Functional Collaboration** | Do you show you've worked with PMs, Ops? How do you handle conflicts? | Siloed thinking, only technical perspective |
| **Iteration** | Do you show willingness to pivot based on feedback? | Rigid thinking, "my way is best" attitude |
| **Business Impact** | Do you connect your solution to business metrics? | Pure technical elegance without business context |
| **Pragmatism** | Do you balance perfection with speed? | Over-engineer, too idealistic |
| **Problem-Solving Process** | Do you structure your thinking? Can you explain your reasoning? | Chaotic thinking, hard to follow |

---

## 🔄 Generic Framework for ANY Business Partner Question

Use this framework for almost any prompt:

```
STEP 1: CLARIFY THE PROBLEM (First 5-7 minutes)
├─ Ask clarifying questions
├─ Understand stakeholders
├─ Define success criteria
└─ Confirm scope

STEP 2: DEFINE METRICS/KPIs (Next 5-7 minutes)
├─ Identify primary metrics
├─ Secondary/guardrail metrics
├─ Data sources needed
└─ Why these metrics matter

STEP 3: SHOW YOUR THINKING (Next 10-15 minutes)
├─ Walk through analysis approach
├─ Discuss segmentation strategy
├─ Explain expected patterns
└─ Discuss trade-offs

STEP 4: ADDRESS THE TWIST (Next 8-10 minutes)
├─ Interviewer throws curve ball
├─ Show adaptive thinking
├─ Discuss constraints/complexities
└─ Propose solutions

STEP 5: BUSINESS IMPACT (Last 3-5 minutes)
├─ Explain how this drives decisions
├─ Link to company strategy
├─ Discuss implementation next steps
└─ Offer forward-thinking ideas
```

---

## 🗣️ Critical Clarifying Questions to Ask

These questions work for ~80% of business partner prompts:

| Question | Why Ask | Example Follow-up |
|----------|--------|-------------------|
| **Who is the audience?** | Exec vs product vs ops need different views | "Is this for C-suite or product team?" |
| **What's the goal?** | Tracking vs optimization vs diagnostics | "Are we optimizing for growth or cost?" |
| **Who are we focused on?** | Customer vs dasher vs merchant vs company | "Should I think about supply-side impact too?" |
| **What's the business model impact?** | Revenue vs cost vs retention implications | "Does this metric affect monetization?" |
| **What are we trying to solve?** | Specific problem vs exploratory | "Is there a recent issue we're investigating?" |
| **What's the time horizon?** | Real-time vs daily vs long-term | "Are we optimizing for quick wins or sustainable growth?" |
| **Are there regulatory/privacy constraints?** | Can't always do what's optimal | "Any data privacy concerns?" |
| **What's the current state?** | Baseline for comparison | "How are we currently measuring this?" |

**PRO TIP**: Asking 3-4 clarifying questions shows thoughtfulness. Asking 0 looks like you don't care. Asking 10+ looks like you're stalling.

---

## 📊 Universal Metrics Framework

Most business partner rounds involve metrics. Use this mental model:

```
TIER 1: FUNDAMENTAL METRICS (The "So What?")
├─ Revenue/GMV (total $ traded)
├─ Volume (orders, transactions)
├─ Active Users (DAU, MAU, WAU)
└─ Growth rate (YoY, MoM, WoW)

TIER 2: ENGAGEMENT METRICS (Are users coming back?)
├─ Repeat rate (% ordering 2+ times)
├─ Frequency (orders per user per period)
├─ Retention (D7, D30, D60, etc.)
└─ Churn (% leaving per period)

TIER 3: QUALITY METRICS (Are users satisfied?)
├─ Satisfaction (NPS, rating, reviews)
├─ Complaint rate (defects per order)
├─ Delivery performance (on-time %)
└─ Issue resolution time

TIER 4: UNIT ECONOMICS (Is it profitable?)
├─ CAC (customer acquisition cost)
├─ LTV (lifetime value)
├─ Margin per transaction
└─ CAC:LTV ratio

TIER 5: OPERATIONAL METRICS (Can we scale?)
├─ Supply adequacy (waitlist, acceptance rate)
├─ Performance (latency, uptime)
├─ Cost efficiency (cost per order)
└─ Quality consistency (across markets)
```

**KEY INSIGHT**: These metrics are **INTERCONNECTED**. Optimizing one often impacts others.

---

## 🔍 Common Business Partner Question Types

### Type 1: "How would you track/measure [something]?"
**Approach**: Define metrics → data sources → dashboard design → how to use it

**Example**: "How would you measure engagement?"  
**Answer**: "First, I'd clarify what 'engagement' means in your context..."

**Files to Review**: BP3, BP7, BP10

---

### Type 2: "If [metric] dropped, what would you do?"
**Approach**: Segmentation → root cause analysis → investigation framework → fixes

**Example**: "Orders dropped 12% this week. Investigate."  
**Answer**: "I'd systematically narrow down the cause by checking..."

**Files to Review**: BP9, BP7

---

### Type 3: "How would you approach [new market/feature]?"
**Approach**: Success criteria → metrics → phased approach → go/no-go gates

**Example**: "We're launching in Japan. How do we measure success?"  
**Answer**: "I'd define a phased approach with clear success metrics..."

**Files to Review**: BP4, BP5

---

### Type 4: "Design an experiment to test [hypothesis]"
**Approach**: Hypothesis → metrics → sample size → interpretation → decision rules

**Example**: "Test if lower delivery fees increase order frequency"  
**Answer**: "I'd set up a randomized test with clear success criteria..."

**Files to Review**: BP8

---

### Type 5: "Build a model/dashboard for [vague ask]"
**Approach**: Problem definition → clarifying questions → approach → challenges → success metrics

**Example**: "Build a fraud detection system"  
**Answer**: "First, let me understand the problem better..."

**Files to Review**: BP6, BP10

---

### Type 6: "What KPIs should we prioritize?"
**Approach**: Define business goals → metrics that align → trade-off analysis → recommendation

**Example**: "What metrics matter most for marketplace health?"  
**Answer**: "It depends on the business stage, but fundamentally..."

**Files to Review**: BP7, BP2

---

## 💡 Mental Models & Frameworks to Master

### Business Model Canvas
```
Most businesses = Supply + Demand + Monetization + Execution

Supply Side: Do we have enough?
Demand Side: Are users coming?
Monetization: Are we making money?
Execution: Can we deliver it?

If one breaks, whole system breaks.
```

### Metric Causality
```
Leading Indicator → (1-4 weeks) → Lagging Indicator → (4-12 weeks) → Business Outcome

Example:
High NPS → (weeks) → High Repeat Rate → (weeks) → Higher LTV → (quarters) → Better Margins

Don't skip steps. Correlation ≠ causation.
```

### Diagnostic Tree
```
Problem Detected
    ↓
Is it DEMAND?
    └─ DAU? Traffic? Conversion? AOV?
    
Is it SUPPLY?
    └─ Dasher count? Acceptance rate? Utilization?
    
Is it QUALITY?
    └─ Ratings? Delivery time? Complaints?
    
Is it OPERATIONS?
    └─ System down? Bug? Data issue?
    
Is it EXTERNAL?
    └─ Competitor? Market? Regulation?
```

### Unit Economics
```
CAC (Cost to Acquire) + LTV (Value They Generate) = Profitability

If CAC > LTV → Not sustainable
If LTV:CAC < 3:1 → Tough growth
If LTV:CAC > 5:1 → Good business

Always know the unit economics.
```

---

## 📈 Answer Templates for Common Questions

### Template 1: "How would you track X?"

```
Great question. Before I jump in, let me clarify a few things:

1. CLARIFY
   - Who's the primary user? (Exec/product/ops)
   - What's the goal? (Tracking/optimization/diagnosis)
   - What's the context? (New initiative/problem investigation)

2. DEFINE METRICS
   - Primary metric: [main KPI]
   - Why: [business justification]
   - Secondary metrics: [supporting metrics]
   - Guardrails: [what we DON'T want to sacrifice]

3. DATA SOURCES
   - Source 1: [data type]
   - Source 2: [data type]
   - Source 3: [data type]

4. DASHBOARD DESIGN
   - Executive level: [3-5 key metrics]
   - Operational level: [10-15 metrics]
   - Diagnostic level: [drill-down capability]

5. HOW WE'D USE IT
   - Monitor for: [early warnings]
   - Investigate when: [thresholds]
   - Link to: [business decisions]

Does this approach make sense? Any aspects you'd like me to dive deeper on?
```

---

### Template 2: "A metric dropped. Investigate."

```
Good scenario. Let me work through this systematically:

1. VALIDATE THE SIGNAL
   - Is the drop real (not data issue)?
   - How sudden? (overnight vs gradual)
   - How widespread? (all segments or some?)

2. SEGMENT TO ISOLATE
   - By geography (all cities or some?)
   - By user type (new vs power users)
   - By device/platform (iOS, Android, web)
   - By time of day (peak vs off-peak)

3. FORM HYPOTHESES
   - Is it demand-side? (traffic/conversion down)
   - Is it supply-side? (Dashers/merchants unavailable)
   - Is it quality-side? (delivery time/rating down)
   - Is it product-side? (bug/change launched)
   - Is it external? (competition/market/weather)

4. ROOT CAUSE DIAGNOSIS
   - Check logs, dashboards, deployments
   - Compare to baseline (last week, last year, last 4 weeks)
   - Look for correlation with events

5. PROPOSE ACTIONS
   - Immediate: [quick fix if product/ops issue]
   - Short-term: [address root cause]
   - Long-term: [prevent recurrence]

6. MONITORING PLAN
   - Track: [specific metrics]
   - Alert: [thresholds for escalation]
   - Cadence: [when to check]

What time period are we looking at? Let's start there.
```

---

### Template 3: "Build a model/dashboard"

```
Interesting ask. Let me make sure I understand this right:

1. PROBLEM DEFINITION
   - What's the business problem? (not the solution!)
   - Who's the user?
   - How will they use it?
   - What decision does it enable?

2. SUCCESS CRITERIA
   - How will we know if this is successful?
   - What's the baseline/current state?
   - What's the target?

3. DATA LANDSCAPE
   - What data exists?
   - Data quality/completeness?
   - Data latency?
   - Privacy constraints?

4. APPROACH
   - MVP first or production-ready?
   - Real-time or batch?
   - Sophistication level (simple heuristic vs ML model)

5. PHASES
   - Phase 1: [MVP, what would we build first]
   - Phase 2: [enhancement, if Phase 1 proves value]
   - Phase 3: [optimization, long-term refinement]

6. RISKS & MITIGATIONS
   - What could go wrong?
   - How would we know?
   - How would we respond?

Can you help me understand the core problem we're solving?
```

---

### Template 4: "Run an experiment"

```
Great setup for an experiment. Here's how I'd approach it:

1. HYPOTHESIS
   - Clear statement of what we believe will happen
   - Why we believe it (theoretical basis)

2. PRIMARY METRIC
   - What are we optimizing for?
   - Current baseline?
   - Expected lift?
   - How do we measure it?

3. SAMPLE DESIGN
   - How many users do we need?
   - How long does it need to run?
   - How do we randomize?

4. GUARDRAILS
   - What metrics could we break?
   - What would be unacceptable?
   - Would we stop the test early?

5. INTERPRETATION
   - Statistically significant? (p < 0.05)
   - Practically significant? (big enough to matter)
   - Any subgroup effects?

6. DECISION RULES
   - If [result], then [action]
   - Do we launch? Iterate? Kill?

Should I walk through the sample size calculation?
```

---

## 🚨 Common Mistakes to Avoid

| Mistake | Why It's Bad | How to Fix |
|---------|-------------|-----------|
| **Skip clarifying questions** | Solve wrong problem | Ask 3-4 questions first |
| **Only think about one stakeholder** | Miss important trade-offs | Consider customer, supply, merchant, company |
| **Metrics without business context** | No one cares about your number | Always explain "so what?" |
| **Ignore execution complexity** | Unrealistic recommendations | Think about what's actually doable |
| **Assume instead of confirming** | Off on wrong track | Verify assumptions with interviewer |
| **Too technical too fast** | Lose non-technical interviewer | Start simple, go technical if asked |
| **No trade-off discussion** | Naive thinking | Most decisions involve trade-offs |
| **Talking only about upside** | Miss critical risks | Discuss downside and mitigation |
| **Not connecting to strategy** | Sound disconnected from business | Link back to company goals |
| **Over-complicating** | Lose audience | Simple > complex every time |

---

## ⏰ Time Management in Interview

```
45-Minute Interview Allocation:

0-5 min:   Warm-up, clarifying questions
5-15 min:  Define problem, metrics, approach
15-30 min: Deep-dive on solution
30-40 min: Address twist/complications
40-45 min: Wrap-up, impact, next steps

KEY: Don't go too deep too fast
     Keep interviewer engaged with questions
     Be ready to shift directions quickly
```

---

## 📚 Reference Guide: Which BP File to Review?

| Question Type | Relevant BP Files | Key Concepts |
|---------------|------------------|--------------|
| Engagement/retention tracking | BP3, BP7, BP10 | Cohorts, retention curves, NPS |
| Market expansion | BP4 | Phase gates, go/no-go criteria |
| Feature launch | BP5 | Success metrics, RICE scoring |
| Vague asks | BP6 | Problem definition first |
| Marketplace health | BP7 | Metric hierarchy, interconnections |
| Experimentation | BP8 | Sample size, statistical significance |
| Investigation | BP9 | Root cause analysis, segmentation |
| Dashboard design | BP10 | Actionability, drill-down |
| Supply optimization | BP2 | Supply-demand dynamics |

---

## 🎤 Interview Tips & Tricks

**DO:**
- ✅ Ask clarifying questions (shows you care about solving right problem)
- ✅ Think out loud (let them see your process)
- ✅ Use frameworks (structured thinking is good)
- ✅ Discuss trade-offs (shows maturity)
- ✅ Connect to strategy (not just metrics)
- ✅ Listen actively (adjust based on feedback)
- ✅ Show flexibility (pivot when needed)
- ✅ Be specific (examples > vague statements)

**DON'T:**
- ❌ Assume without confirming
- ❌ Dive too deep too fast
- ❌ Ignore obvious questions
- ❌ Talk past the interviewer
- ❌ Only think about upside
- ❌ Propose unrealistic solutions
- ❌ Ignore execution constraints
- ❌ Forget the "so what?"

---

## 🎯 The Single Most Important Thing

**Ask clarifying questions first. Always.**

Most candidates jump straight to a solution. The good ones ask 3-4 questions first to make sure they understand the problem.

This ONE habit will set you apart.

---

## 📋 Pre-Interview Checklist

Before your interview, make sure you can:

- ☐ Define what a "good metric" looks like
- ☐ Explain supply-demand dynamics in marketplaces
- ☐ Design an experiment from scratch
- ☐ Investigate a business problem systematically
- ☐ Prioritize between competing metrics/goals
- ☐ Discuss trade-offs and complexities
- ☐ Ask clarifying questions before jumping to solutions
- ☐ Think about all stakeholders (customers, supply, merchants)
- ☐ Connect solutions back to business strategy
- ☐ Estimate what's realistic to build

---

## 📖 How to Use This Master Guide

1. **Start here** - Read this entire file first
2. **Reference frameworks** - Use the templates when practicing
3. **Dig deeper** - Review specific BP files for detailed examples
4. **Practice** - Answer each question type using the templates
5. **Refine** - Adjust your answers based on feedback
6. **Review** - Re-read this 30 minutes before interview

---

## 🚀 Final Tips

1. **Be conversational** - This isn't a presentation, it's a discussion
2. **Show your thinking** - Interviewer wants to understand your process
3. **Be humble** - "I don't know, but here's how I'd find out" is good
4. **Connect the dots** - Don't leave metrics in isolation
5. **Think like a partner** - You're helping the business, not just analyzing
6. **Ask for feedback** - "Does this direction make sense?" shows you care

---

**Good luck with your DoorDash Business Partner interview! 🎯**

Remember: **The best candidates ask questions first, then think strategically about solutions.**

