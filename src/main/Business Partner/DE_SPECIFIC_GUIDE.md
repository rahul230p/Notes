# 🎯 Data Engineer / Analytics Engineer - Business Partner Round

## Quick Summary

**45-Minute Interview Focus:**
- ✅ Problem-solving with cross-functional teams
- ✅ Communication (explaining technical to non-technical)
- ✅ Data quality, data modeling approach
- ✅ Scenario questions
- ✅ Experience working with stakeholders

**What They DON'T Want:**
- ❌ Pure technical deep-dives without business context
- ❌ Jargon-heavy explanations
- ❌ Siloed thinking (only engineer perspective)
- ❌ Rigid solutions that don't adapt
- ❌ Missing business impact

---

## 🗣️ Critical Clarifying Questions for Data Engineers

When you get ANY question, ask these FIRST (adapted for data context):

| Question | Why Important | Example |
|----------|---------------|---------|
| **What's the business problem?** | Understanding business need before data solution | "Are we trying to optimize for speed, cost, or accuracy?" |
| **Who needs this data?** | Know your stakeholder (PM, Ops, Finance) | "Will this be used for real-time decisions or batch reporting?" |
| **What's the data quality/latency requirement?** | Define technical constraints | "Do we need 99.9% accuracy or is 95% acceptable?" |
| **Who will consume this?** | Affects how you model/present | "Will analysts query this or is it automated?" |
| **What's the current state?** | Understand existing constraints | "Do we have this data already or need to collect it?" |
| **What success looks like?** | Define KPIs for your data work | "How will we know if this solution worked?" |
| **Are there cross-functional constraints?** | Understand team dependencies | "Does Ops need to approve? Does Finance care about cost?" |
| **What's the timeline?** | Affects scope and approach | "Do we need this in 2 weeks or can we spend a month?" |

---

## 💡 Framework: Problem → Data → Solution → Impact

This is the framework Data Engineers should use (different from general business):

```
STEP 1: UNDERSTAND BUSINESS PROBLEM (3-5 min)
├─ What's the business challenge?
├─ Who are the stakeholders?
├─ What decisions will this enable?
└─ What's the business impact?

STEP 2: TRANSLATE TO DATA PROBLEM (3-5 min)
├─ What data do we need?
├─ What data quality/freshness?
├─ What schema/modeling approach?
└─ What constraints (scale, cost, latency)?

STEP 3: PROPOSE DATA SOLUTION (5-10 min)
├─ Architecture/approach
├─ Data pipeline design
├─ Quality/testing plan
└─ Trade-offs (cost vs speed, complexity vs elegance)

STEP 4: DISCUSS COLLABORATION (5-7 min)
├─ How will you work with PMs?
├─ How will you handle feedback?
├─ How will you communicate progress?
└─ What if requirements change?

STEP 5: CONNECT TO BUSINESS IMPACT (3-5 min)
├─ How does this enable business decisions?
├─ What's the ROI of this data work?
├─ How will you measure success?
└─ What feedback would you want?
```

---

## 🎤 Common Data Engineer / Analytics Engineer Interview Questions

### Type 1: "We need data for X. How would you approach it?"
**Example**: "We want to track Dasher performance metrics. How would you set this up?"

**Your Approach:**
1. **Clarify**: What metrics? What's the use case? Who consumes?
2. **Understand**: What data exists? What's the latency requirement?
3. **Propose**: Data schema, pipeline, quality checks
4. **Collaborate**: How will you work with the Dasher ops team?
5. **Impact**: How does this improve operations?

**What They Want to Hear:**
- "I'd ask the Dasher ops team what metrics matter most to them"
- "I'd understand the data quality requirements before designing"
- "I'd propose a scalable schema that's easy for analysts to query"
- "I'd set up monitoring so we catch data quality issues early"

---

### Type 2: "Our data pipeline is slow. Debug this."
**Example**: "Orders pipeline takes 2 hours to complete. What would you do?"

**Your Approach:**
1. **Validate**: Is 2 hours a problem? What's the SLA?
2. **Segment**: Where's the bottleneck? (Ingestion? Processing? Storage?)
3. **Root cause**: Is it volume? Schema? Infrastructure?
4. **Propose**: Quick fix vs long-term solution
5. **Collaborate**: How will you communicate with the team?

**What They Want to Hear:**
- "I'd look at the metrics to understand where time is spent"
- "I'd partner with the pipeline team to understand the constraints"
- "I'd propose a solution that doesn't break existing dependencies"
- "I'd communicate progress to stakeholders throughout"

---

### Type 3: "Model this for us" (Vague ask)
**Example**: "Build a data model for customer orders"

**Your Approach:**
1. **Clarify**: What's the use case? Who queries this? What's the query pattern?
2. **Understand**: What data quality matters? What's the scale?
3. **Propose**: Fact/dimension tables, schema design, relationships
4. **Trade-offs**: Normalized vs denormalized? Real-time vs batch?
5. **Iterate**: Get feedback from stakeholders

**What They Want to Hear:**
- "Before I design, I'd understand how this data will be used"
- "I'd work with the analytics team to understand their queries"
- "I'd design for the 80% use case, not edge cases"
- "I'd propose testing the schema with sample data first"

---

### Type 4: "We have data quality issues. Help."
**Example**: "Our Dasher metrics are sometimes wrong. How do you fix?"

**Your Approach:**
1. **Validate**: Is it data quality or logic issue?
2. **Diagnose**: Where in pipeline? Which metrics?
3. **Root cause**: Bad source data? Transformation bug?
4. **Propose**: Quality checks, monitoring, testing
5. **Prevent**: How to catch this earlier?

**What They Want to Hear:**
- "I'd work with the source team to understand data"
- "I'd build tests and monitoring to catch this automatically"
- "I'd communicate the fix to all downstream users"
- "I'd propose a data quality framework to prevent future issues"

---

### Type 5: "Tell me about a project where you worked cross-functionally"
**Example**: "Share a time you worked with PMs/Ops on a data project"

**Your Approach:**
1. **Setup**: What was the business problem?
2. **Challenge**: What was hard about working cross-functionally?
3. **Solution**: How did you communicate? How did you handle conflicts?
4. **Outcome**: What was the result?
5. **Learning**: What would you do differently?

**What They Want to Hear:**
- "The PM had requirement X, but the data showed we should do Y"
- "I presented the data in a way the non-technical team understood"
- "I had to compromise between perfect and practical"
- "I communicated progress weekly so they were never surprised"
- "The result was [business impact]"

---

## 📊 Specific Skills to Highlight (Data Engineers)

### 1. Data Modeling Thinking
```
✅ Good Answer:
"I'd design a star schema with a fact table for orders and dimensions
for customers, restaurants, and time. This makes queries fast for analysts
while keeping the data normalized for accuracy."

❌ Bad Answer:
"I'd just create a big table with all the data"
```

### 2. Data Quality Mindset
```
✅ Good Answer:
"I'd build checks for: null values, duplicates, out-of-range values,
and staleness. I'd alert ops if anything fails, and have a dashboard
showing data quality metrics."

❌ Bad Answer:
"I hope the data is good" or "That's the data team's problem"
```

### 3. Communication with Non-Technical People
```
✅ Good Answer:
"I'd explain to the PM: 'We need 2 weeks to set up. Your analysts
can query it with SQL. If source data changes, we'll get new metrics
next day.'"

❌ Bad Answer:
"We need to optimize the ETL pipeline with incremental processing
and implement CDC patterns for real-time synchronization"
```

### 4. Pragmatism over Perfection
```
✅ Good Answer:
"We could build a perfect real-time system for $100K, or we could
batch daily for $20K. For this use case, daily is enough. Let's start
there and upgrade if needed."

❌ Bad Answer:
"We need the perfect, most scalable solution"
```

### 5. Collaboration & Iteration
```
✅ Good Answer:
"I showed the schema to analysts for feedback. They needed X field
we forgot. We iterated twice before launching. Throughout, I gave
the PM weekly updates so she knew we were on track."

❌ Bad Answer:
"I built the solution myself and delivered it"
```

---

## 🎯 Your Story: Cross-Functional Collaboration Project

**Before the interview, prepare ONE project story that shows:**

### The Setup
- What was the business problem?
- Who were the stakeholders? (PM, Ops, Analytics, Engineering)
- Why was this data work needed?

### The Challenge
- What was hard about working cross-functionally?
- Was there a disagreement? How did you handle it?
- What was the biggest blocker?

### Your Approach
- How did you communicate with each team?
- What cadence did you use? (Daily standup? Weekly reviews?)
- How did you translate technical to non-technical?

### The Outcome
- What did you deliver?
- How did it impact the business? (Better decisions? Faster? Cost savings?)
- What feedback did you get?

### The Learning
- What would you do differently?
- How did this shape how you work cross-functionally?

**Example Story:**
```
Situation: Product Manager needed to track customer order patterns
by delivery time. Ops wanted to optimize Dasher scheduling.

Challenge: PM and Ops had different data needs. The source data was
inconsistent. I had to understand both needs and find a unified approach.

Approach:
1. Met with PM weekly to understand her dashboards
2. Met with Ops bi-weekly to discuss data quality issues
3. Proposed a unified schema that served both use cases
4. Set up data quality checks to flag issues
5. Communicated progress in a shared dashboard

Outcome: Both teams got their metrics in 4 weeks. PM reported 20%
faster analysis time. Ops reduced scheduling time by 30%.

Learning: Understanding the business need first (before jumping to
technical solution) was key. Regular communication prevented surprises.
```

---

## ✅ Technical Topics to Be Ready For

### Data Modeling
- Star schema vs snowflake
- When to denormalize
- Fact and dimension tables
- Slowly changing dimensions (SCD)

### Data Quality
- How to detect data issues
- Monitoring and alerting
- Schema validation
- Data testing best practices

### Data Pipeline Concepts
- Batch vs real-time
- ETL vs ELT
- Incremental processing
- Data freshness vs accuracy

### Scale Thinking
- Handling volume growth
- Partitioning strategies
- Query optimization
- Cost optimization

### Communication
- Explaining technical concepts simply
- Creating dashboards for non-technical people
- Presenting data issues clearly
- Negotiating trade-offs

---

## 🚨 Common Mistakes Data Engineers Make

| Mistake | Why Bad | Fix |
|---------|--------|-----|
| **Too technical immediately** | PM/Ops gets lost | Start simple, add complexity if asked |
| **Ignore business context** | Data doesn't solve the problem | Always ask "why" before "how" |
| **Over-engineer solution** | Overkill, takes too long | MVP first, upgrade later |
| **Assume data quality** | Surprises downstream | Assume data is messy, plan for it |
| **Don't communicate progress** | Stakeholders surprised at end | Weekly updates, shared dashboards |
| **Only technical perspective** | Miss business constraints | Involve stakeholders early |
| **Not collaborative** | Teams don't trust you | Ask for feedback, iterate |
| **Blame data source** | Defensive, unhelpful | Own the problem, find solutions |

---

## 💬 How to Communicate Like a Data Engineer

### When Explaining to Non-Technical People:

**❌ DON'T:**
- "We need to normalize the schema and implement CDC"
- "The ETL pipeline is having cardinality issues"
- "We'll use a fact table with slowly changing dimensions"

**✅ DO:**
- "We're organizing your data so queries are fast and accurate"
- "We found some data is coming in wrong, let me show you"
- "We're tracking historical changes to your data"

### When Presenting Data Quality Issues:

**❌ DON'T:**
- "The data pipeline failed due to null values in the source"

**✅ DO:**
- "Yesterday, some merchant data was missing. This affected 500 orders.
  Here's what we found, here's how we fixed it, and here's how we'll
  prevent it next time"

### When Proposing Solutions:

**❌ DON'T:**
- "We can build this with Spark and Kafka for real-time processing"

**✅ DO:**
- "We have two options: Option A is fast but costs $50K. Option B is slower
  but costs $5K. For your use case, B is probably fine. What do you think?"

---

## 📋 Interview Day Checklist

**Before You Walk In:**
- ☐ Have your project story ready (5 min version, 2 min version)
- ☐ Know your 3-4 clarifying questions
- ☐ Understand: Am I Data Engineer or Analytics Engineer? (affects focus)
- ☐ Remember: This is collaborative, not a test
- ☐ Mindset: "How can I help this team?" not "Am I smart enough?"

**During Interview:**
- ☐ Ask clarifying questions (don't assume)
- ☐ Explain your thinking (let them see your process)
- ☐ Use simple language (even if you know technical terms)
- ☐ Listen actively (adjust based on feedback)
- ☐ Show you'd work cross-functionally
- ☐ Connect to business impact
- ☐ Be collaborative (not "I know best")

**If Stuck:**
- "Let me clarify: Are you asking about X or Y?"
- "Can you help me understand what success looks like?"
- "That's a great point. Let me think about that differently..."
- "I don't know, but here's how I'd figure it out"

---

## 🎯 The Core Message You're Sending

**What you want them to think after interview:**

"This person:
- Asks good questions before jumping to solutions
- Understands business, not just technology
- Can explain complex things simply
- Collaborates well and listens to feedback
- Thinks about data quality and practical constraints
- Connects their work to business impact
- Someone I'd want on my team"

---

## ⏰ Time Breakdown (45 minutes)

```
0-5 min:    Warm-up, intro
5-10 min:   Scenario question (they ask)
10-20 min:  You work through it (ask questions, propose approach)
20-35 min:  Discussion, feedback, iteration
35-40 min:  "Tell me about a project" story
40-45 min:  Wrap-up, your questions
```

---

## 🚀 Your Competitive Advantage

Most Data Engineers:
- Jump to technical solution
- Don't ask clarifying questions
- Ignore business context
- Use too much jargon

You will:
- Ask 3-4 clarifying questions first ✅
- Explain simply to non-technical people ✅
- Connect to business impact ✅
- Show you work collaboratively ✅

This alone puts you in top 20% of candidates.

---

## 📚 Which Files to Review

**For Data Engineers specifically:**

1. **This file** - Read completely
2. **BP1_Master_Guide.md** - Review "Framework" section
3. **BP7_Marketplace_Health_KPIs.md** - Understand metrics and health
4. **BP9_Sales_Order_Drop_Investigation.md** - Root cause analysis
5. **BP10_Dashboard_and_Metrics_Design.md** - Data presentation
6. **BP3_Engagement_and_Retention_Tracking.md** - Data modeling example

**Don't spend time on:**
- BP2 (Supply optimization)
- BP4 (Market expansion)
- BP5 (Feature launch)
- BP6 (Vague model asks) - mostly for analysts

---

## 💪 Final Tips

1. **Lead with questions, not answers** - This is your superpower
2. **Explain like you're talking to your manager's manager** - Simple wins
3. **Show you've worked with people, not just code** - This round is about collaboration
4. **Prepare your project story** - They WILL ask this
5. **Embrace the unknown** - "I don't know, but here's how I'd figure it out" is powerful
6. **Iterate based on feedback** - Show flexibility
7. **Connect to business** - Why does this data work matter?

You've got this! 🚀

