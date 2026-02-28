# DoorDash Leadership Round - Your STAR Stories (Optimized)
**Based on your prepared scenarios - Ready to deliver**

---

## 🎯 Story Selection Strategy

You have 12 scenarios. For the 60-min leadership round, you'll likely need **3-4 primary stories** that hit the key evaluation criteria:

| Criterion | Your Best Story | Why |
|-----------|-----------------|-----|
| **Relevant Experience** | Maps Pipeline Project (Story 2) | Scale, reliability, cross-team |
| **Ownership & Impact** | Maps Pipeline + Risk Mitigation (2-3) | End-to-end ownership, measurable results |
| **Make Room at Table** | AHA Stakeholder (Story 6) | Shows listening, collaboration, iteration |
| **1% Better Growth** | Mistake & Learning (Story 5) | Demonstrates reflection & process change |

---

## 📋 Core Stories Formatted for Delivery

### STORY 1: Your Intro (30-45 seconds)
**What you'll say when they ask "Tell me about yourself"**

```
"I'm Rahul, a data engineer with ~5 years building ingestion pipelines 
and data platforms. I focus on three things: reliability, data quality, 
and enabling downstream teams to act on fresh, correct data quickly.

Currently, I work on a multi-tenant integration platform where I onboard 
varied data sources—translating stakeholder needs into reliable, scalable 
pipelines that don't slow down the business."
```

**Why this works:**
- ✅ Problem → impact (not just tech)
- ✅ Shows your 3 core values
- ✅ Relevant to DoorDash's data infrastructure needs
- ✅ Ends with "doesn't slow down business" (bias for action)

---

### STORY 2: Maps Pipeline - End-to-End Ownership (2-3 minutes)
**Primary story - hits "Relevant Experience" + "Ownership & Impact"**

**ONE-SENTENCE OUTCOME (lead with this):**
```
"I reduced the pipeline runtime from 42 hours to 8 hours, cut per-run 
costs by 67%, and the design became the template for other regions."
```

**Full STAR:**

**Situation:**
```
We had a global OSM (OpenStreetMap) ingestion pipeline that processed 
massive geographic datasets. The pipeline ran 41-42 hours every cycle, 
which blocked downstream releases and was expensive.

I noticed we were materializing intermediate formats just for visualization, 
which consumed most of the runtime.
```

**Task:**
```
I took ownership to cut runtime and cost while preserving data correctness 
and not breaking downstream consumers.
```

**Action (lead with THE key decision):**
```
I analyzed the flow and identified the single bottleneck: materializing 
intermediate formats. So I redesigned the pipeline to:

1. Operate on in-memory data models (RDDs + internal geometry framework)
   instead of materializing intermediates
2. Eliminated unnecessary format conversions (e.g., GeoJSON roundtrips)
3. Applied row-level geometry & tag transforms in-pipeline
4. Implemented a phased rollout with validation (diff-based validation 
   framework comparing baseline vs new outputs—Neutron Diff)

For safety, I built diff reports showing feature-level changes (geometry 
vs tag diffs) and worked with Ops to agree on ≤1% diff threshold.
```

**Result:**
```
• Runtime: 42h → 8h (81% improvement)
• Cost per run: ~$450 → ~$150 (67% reduction)
• Zero data loss; Ops gained confidence via structured diffs
• The redesigned pattern was reused for other regions
```

**Follow-up prep:**
- *"How did you roll this out safely?"* → Mention diff validation + phased rollout
- *"Who did you convince?"* → Ops, downstream teams; showed diffs first
- *"What was the main risk?"* → Losing Ops' visibility; mitigated with Neutron Diff

---

### STORY 3: Risk Mitigation & Stakeholder Collaboration (2 minutes)
**Hits "Make Room at the Table"**

**ONE-SENTENCE OUTCOME:**
```
"By co-designing a diff-based validation framework with Ops, I preserved 
their confidence and operational transparency while unlocking the performance gains."
```

**Full STAR:**

**Situation:**
```
When I first redesigned the pipeline, I assumed automated checks would 
be enough. But Ops relied heavily on intermediate artifact visibility to 
validate runs—removing them made them lose confidence, even though the 
new system was objectively better.
```

**Task:**
```
My task was to deliver the performance gains WITHOUT breaking Ops' workflows 
or forcing manual processes.
```

**Action:**
```
Instead of pushing forward alone, I:

1. Paused the rollout and asked Ops: "What do you need to be confident?"
2. Learned they needed to see differences at the feature level (geometry 
   changes vs tag changes)
3. Co-designed Neutron Diff—a validation framework that produces 
   feature-level JSON diffs
4. Agreed on success criteria together (≤1% diff = safe to proceed)
5. Provided targeted visualization for diffs so Ops could inspect 
   problem areas

This was the "make room" moment—their insight literally shaped the 
solution.
```

**Result:**
```
• Ops' manual effort dropped significantly (diffs are faster to review 
  than intermediate artifacts)
• Validation became objective instead of gut-feel
• Rollout succeeded with stakeholder buy-in
• Built a reusable validation pattern for future changes
```

**Key line for DoorDash:**
```
"This taught me that operational insight is as valuable as technical 
insight. I now include Ops in the validation design BEFORE performance work."
```

**Follow-up prep:**
- *"How did you define the 1% threshold?"* → Worked with Ops, tested on historical runs
- *"What if diffs were larger?"* → We had a phased rollback plan

---

### STORY 4: Stakeholder Disagreement & Listening (2 minutes)
**Hits "Make Room at the Table"**

**ONE-SENTENCE OUTCOME:**
```
"By asking how they actually used the data, I discovered they didn't need 
the full dataset—they needed the filtered version, plus an escape hatch 
for edge cases."
```

**Full STAR:**

**Situation:**
```
A stakeholder (AHA) wanted me to replicate a legacy UI that loaded 
millions of rows per view. This would violate our platform SLAs for 
query latency and cost us significantly.
```

**Task:**
```
My goal was to meet their needs WITHOUT violating platform SLAs.
```

**Action:**
```
Instead of saying "no," I asked:
- "How do you actually use this data?"
- "Do you look at all rows every time?"

They admitted: "No, we always filter first, then act."

So I proposed:
1. Upfront filters in the UI (faster load)
2. Targeted downloads for the "I need to see everything" cases
3. Built a prototype and iterated based on their feedback

They saw that filtered view + download option solved their workflow 
without breaking the platform.
```

**Result:**
```
• Platform SLA maintained (page load time ≤ threshold)
• Stakeholder workflow preserved via new UX
• Downloads covered the edge case ("full-data dive")
• Precedent set: stakeholders now understand why filters matter
```

**Why this is "Making Room":**
```
I listened first. I didn't assume I knew their need. And the solution 
was shaped by their input—they chose the filtered UI.
```

**Follow-up prep:**
- *"What if they insisted on legacy behavior?"* → Would escalate to product/infra, but data showed cost trade-off
- *"How did you measure success?"* → Page load time, tasks completed, support tickets

---

### STORY 5: Mistake & Learning (2 minutes)
**Hits "1% Better" + Growth Mindset**

**ONE-SENTENCE OUTCOME:**
```
"I learned the hard way that Ops needs to be involved in validation design 
BEFORE performance changes, not after—and now I follow that discipline."
```

**Full STAR:**

**Situation:**
```
After the initial pipeline redesign, I underestimated how much Ops relied 
on immediate visibility to intermediate artifacts. I assumed automated 
checks would be sufficient.
```

**Task:**
```
Deliver faster runs without breaking Ops' workflows.
```

**Action (the mistake):**
```
I didn't involve Ops early enough. When I rolled out the new design, Ops 
couldn't validate runs the way they used to, and they lost confidence—even 
though the new system was objectively better.

WHAT I DID TO FIX IT:
1. Paused the rollout (didn't try to power through)
2. Asked Ops: "What do you need to trust this?"
3. Co-designed the diff framework with them
4. Got their buy-in before rolling out further

CONCRETE PROCESS CHANGE:
Now, before any performance work, I:
- Run a "validation workshop" with Ops early
- Get their sign-off on success metrics
- Build validation/visibility into the design phase
- Don't roll out until Ops is confident
```

**Result:**
```
• Rollout succeeded with Ops' full support
• Trust was restored
• New teams now adopt this checklist: 
  [validation signals] + [Ops sign-off] before full cutover
```

**Why this matters for DoorDash:**
```
"This taught me that moving fast (bias for action) doesn't mean moving 
alone. It means moving aligned—and that means including Ops early."
```

**Follow-up prep:**
- *"How much time did the pause cost?"* → ~2 weeks, but saved months of friction later
- *"How did you formalize this?"* → Added checklist to design doc template

---

### STORY 6: Influence Without Authority (2 minutes)
**Hits "Ownership"**

**ONE-SENTENCE OUTCOME:**
```
"By running a quick cost/perf pilot with clear metrics, I convinced the 
team to adopt a hybrid approach that both saved money and reduced latency."
```

**Full STAR:**

**Situation:**
```
We were planning a major migration. The PM wanted a fast lift-and-shift, 
and infra was worried about cost. There was tension—neither side wanted 
to compromise.
```

**Task:**
```
I needed alignment to pursue a hybrid approach that balanced cost and 
latency without formal authority over either team.
```

**Action:**
```
I ran a short cost/perf analysis and proposed:

1. **Pilot proposal:** "Let's test the hybrid approach on critical metrics 
   only (high-traffic regions) for 2 weeks"
2. **Clear metrics:** cost per query ($/query), latency (p50, p99), 
   downstream impact
3. **Rollback plan:** Easy revert if metrics diverge
4. **I led the pilot** and collected results rigorously

Result: Pilot showed:
- 30% cost savings
- Latency within 5% of lift-and-shift
- Downstream latency improved (less contention)

Presented these numbers to both PM and infra.
```

**Result:**
```
• PM saw cost wasn't sacrificed
• Infra saw latency was acceptable
• Team adopted the hybrid design
• Later standardized the pattern
```

**Why this works at DoorDash:**
```
"This is persuasion by data—not opinion. I ran an experiment, showed 
numbers, and let the evidence speak."
```

**Follow-up prep:**
- *"What if pilot results were mixed?"* → Would have dug into why and proposed variant
- *"How did you choose which metrics to track?"* → Talked to both teams first

---

## 🎤 Delivery Checklist

### Before Each Story:
- [ ] Start with one-line outcome
- [ ] Label STAR in your head (say it silently)
- [ ] Use "I" for decisions you led
- [ ] Include 2-3 specific numbers
- [ ] Tie back to impact or user

### During Delivery:
- [ ] Slow down (pacing matters)
- [ ] Pause between STAR sections
- [ ] Make eye contact
- [ ] Show enthusiasm (not robotics)
- [ ] Listen to follow-up cues

### Numbers to Have Ready:
```
Maps Pipeline:
• 42h → 8h (runtime reduction)
• $450 → $150 (cost per run)
• ≤1% diff threshold (validation target)
• N regions adopted pattern

Stakeholder:
• Page load time: X sec → Y sec
• Tasks completed per user: X → Y
• Support tickets: X → Y

Pilot:
• 30% cost savings
• Latency p50/p99 within 5%
• Downstream impact metrics
```

---

## 🎯 DoorDash Alignment

### Bias for Action ✅
Your stories show:
- Fast decision-making (maps pipeline redesign)
- Pilots over endless planning (migration pilot)
- Iterate based on feedback (stakeholder story)

### Making Room at the Table ✅
Your stories show:
- Listening to Ops before rolling out
- Co-designing with stakeholders
- Asking "what do you need?" not "here's the answer"

### Ownership ✅
Your stories show:
- You took end-to-end ownership
- You drove measurable outcomes
- You didn't blame constraints—you worked within them

### 1% Better ✅
Your stories show:
- Learning from mistakes
- Process improvements based on learnings
- Reflection and adaptation

---

## ⏱️ Story Timing

| Story | Length | When to Tell |
|-------|--------|--------------|
| Intro | 30-45s | Opening |
| Maps Pipeline | 2-3 min | "Tell me about a project you owned" |
| Risk Mitigation | 2 min | (Extend Maps story OR standalone) |
| Stakeholder | 2 min | "How do you collaborate?" or "Tell me about a disagreement" |
| Mistake & Learning | 2 min | "Tell me about a mistake" |
| Influence | 2 min | "How do you drive decisions?" |

---

## 🔥 Pro Delivery Tips

1. **Lead with outcome.** "I reduced runtime 81% and cut costs 67%"—then STAR
2. **Defend past decisions.** "At the time, we prioritized X because Y"
3. **Show the tradeoff.** "We chose performance over visualization, and here's why"
4. **Mention stakeholders by role.** "Ops, downstream teams, product"
5. **Use "we" for execution, "I" for decisions.** "I decided to focus on materialization; we executed the refactor"
6. **Anticipate follow-ups.** "This raised a concern about validation…"

---

## 🎓 Interview Flow Prediction

```
Interviewer: "Tell me about a project you owned end-to-end"
→ YOU: Story 2 (Maps Pipeline) — 2-3 min

Interviewer: "What were the main risks?"
→ YOU: Story 3 (Risk Mitigation) — 1 min (or baked into Story 2)

Interviewer: "Tell me about a time you worked across teams"
→ YOU: Story 6 (Influence) or Story 4 (Stakeholder) — 2 min

Interviewer: "Tell me about a mistake and what you learned"
→ YOU: Story 5 (Mistake & Learning) — 2 min

Interviewer: "Why DoorDash? Why this role?"
→ YOU: Your culture-fit answer — 1-2 min

Interviewer: "Do you have questions?"
→ YOU: "What are the top 3 data reliability problems the team is solving?"
```


