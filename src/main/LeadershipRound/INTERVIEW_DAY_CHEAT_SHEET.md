# Interview Day Cheat Sheet - DoorDash Leadership Round
**Quick reference for the 60-minute interview - Print this**

---

## ⏰ Interview Timeline (60 minutes)

```
0-3 min    → Greeting, small talk
3-8 min    → "Tell me about yourself" → YOUR INTRO (30-45s)
8-35 min   → 3-4 main questions + follow-ups
35-50 min  → Your questions + team discussion
50-60 min  → Wrap-up, next steps
```

---

## 🎯 The 4 Evaluation Criteria (What They're Assessing)

| # | Criterion | Signal | Your Story |
|---|-----------|--------|-----------|
| 1 | **Relevant Experience** | Can you handle DoorDash scale? | Maps Pipeline (42h → 8h) |
| 2 | **Ownership** | Do you drive measurable impact? | Maps Pipeline + Risk mitigation |
| 3 | **Make Room at Table** | Do you listen & collaborate? | Stakeholder (AHA) or Ops co-design |
| 4 | **1% Better** | Do you learn & improve? | Mistake & Learning story |

---

## 🔴 Top 5 Likely Questions & Your Story Map

| Question | Your Story | Key Metric |
|----------|-----------|-----------|
| "Tell me about a project you owned end-to-end" | Maps Pipeline (STAR: Redesigned for in-memory ops) | 42h → 8h, $450 → $150 |
| "What were the main risks and how did you handle them?" | Risk Mitigation (STAR: Co-designed Neutron Diff with Ops) | ≤1% diff threshold |
| "Tell me about a time you worked across teams" | Stakeholder (STAR: Asked how they use data, prototyped) | Preserved workflow + SLA |
| "Tell me about a mistake" | Mistake & Learning (STAR: Didn't involve Ops early, learned to co-design) | Now use validation checklist |
| "How do you measure impact?" | Any story + 2-3 primary metrics (runtime, cost, latency) + 2 secondary (tickets, adoption) | Show dashboard/weekly report |

---

## 📊 Your Key Numbers (Memorize These)

### Maps Pipeline Project
```
Baseline       New         % Improvement
42h     →      8h          81% faster
$450    →      $150        67% cheaper
Ops review: Long review → Diff-based (minutes, not hours)
Regions: 1    →      N     (pattern reused)
```

### Risk Mitigation
```
Validation: Manual artifacts → Neutron Diff (feature-level diffs)
Ops effort: High → Low (diffs are faster to review)
Diff threshold: ≤1% safe to proceed
Rollback: Phased + easy revert
```

### Stakeholder Collaboration
```
Problem: Millions of rows loaded (SLA violation)
Solution: Filters + downloads
Load time: X sec → Y sec
Task completion: X → Y tasks per user
Support tickets: Reduced
```

### Mistake & Learning
```
Lesson: Include Ops early in validation design
Before: Automated checks only → Ops loses confidence
After: Validation checklist + Ops sign-off before rollout
Impact: Smooth rollouts, less friction, trust restored
```

---

## 💬 How to Structure Each Answer (STAR Lite)

```
[ONE-LINE OUTCOME]
"I reduced runtime 81% and the design became the template for other regions."

[SITUATION] - 20 seconds
"We had a 42-hour ingestion pipeline that blocked releases and was expensive."

[TASK] - 15 seconds
"I took ownership to cut runtime and cost while preserving data correctness."

[ACTION] - 60 seconds (THE KEY DECISION FIRST)
"I identified that we were materializing intermediate formats unnecessarily.
I redesigned to use in-memory data models, eliminated format conversions,
and built Neutron Diff for validation with Ops to ensure safety."

[RESULT] - 30 seconds (METRICS + IMPACT)
"Runtime dropped 81%, cost fell 67%, and Ops' confidence was preserved 
because they could see feature-level diffs. The pattern got reused for other regions."

TOTAL: 2-2.5 minutes
```

---

## 🚨 Follow-up Handling (What to Expect)

### Type 1: "Tell me more about X"
```
→ Pause, take a breath, go 1-2 levels deeper
→ Use specific examples: "For instance, when we…"
→ Tie back to outcome: "This mattered because…"
```

### Type 2: "Why did you make that decision?"
```
→ State your reasoning: "Because we were blocked on [constraint]"
→ Show you weighed options: "We considered [alternative] but chose [choice] because…"
→ Defend it: "Looking back, that was right because [proof]"
```

### Type 3: "What would you do differently?"
```
→ Show reflection: "I learned that [lesson]"
→ Don't trash yourself: "At the time we had [constraints], so…"
→ Show process change: "Now I [new practice]"
```

### Type 4: "How did X react?"
```
→ Name the person/team: "Ops, the PM, downstream teams"
→ Give evidence: "They said… We measured… They adopted…"
→ Show relationship: "Trust was restored because…"
```

### Type 5: "What metrics prove this worked?"
```
→ Have 3 primary: Runtime/Cost/SLA, or Tasks completed/Load time/Tickets
→ Have 2 secondary: Adoption rate, team feedback, error rate
→ Show proof: "We tracked this in [system/dashboard]"
```

---

## ❓ Your 2 Questions to Ask Them

**Question 1 (Impact):**
```
"What are the top 3 data reliability problems the team is solving 
right now?"

→ Shows you think strategically
→ Lets them sell the role to you
→ You can mentally map your experience to their problems
```

**Question 2 (People/Culture):**
```
"How does the team approach cross-functional collaboration—like, how 
do you work with Ops, Analytics, and Product?"

→ Shows you care about team dynamics
→ Lets you assess if it's the right fit
→ References your strength (collaboration)
```

**Optional 3rd (if time):**
```
"What does success look like in the first 90 days for this role?"

→ Shows you're goal-oriented
→ Gets specificity on what they need
```

---

## ✅ Delivery Checklist (Read Before Interview)

### STORY DELIVERY
- [ ] Start with one-line outcome
- [ ] Use "I" for decisions, "we" for execution
- [ ] Include 2-3 specific numbers
- [ ] Pause between STAR sections
- [ ] Make eye contact
- [ ] Show genuine enthusiasm (not over-the-top)
- [ ] Tie technical detail back to impact or user

### FOLLOW-UP HANDLING
- [ ] Listen carefully to the question
- [ ] Pause before answering (it's okay to think!)
- [ ] Answer specifically (not vague)
- [ ] Use concrete examples
- [ ] Connect back to impact/learning

### TONE & ENERGY
- [ ] Smile during greeting
- [ ] Lean forward slightly (engaged)
- [ ] Speak clearly, not too fast
- [ ] Show you care (about reliability, users, team)
- [ ] Be authentic (not a script)

---

## 🎭 Things to Avoid

```
❌ Memorized script (sounds robotic)
❌ Taking credit for team's work (say "we executed")
❌ Vague improvements ("things got better")
❌ Bad-mouthing past employers
❌ Lying about technical details (they'll probe)
❌ Interrupting or dominating the conversation
❌ Going over time (2-3 min per story max)
❌ Not asking questions back (shows lack of interest)
```

---

## 🎬 Example Opening

```
Interviewer: "Tell me about a project you owned end-to-end."

YOU: "Sure. I'll tell you about our maps ingestion pipeline redesign.

[ONE-LINE OUTCOME]
I reduced the pipeline runtime from 42 hours to 8 hours—that's an 81% 
improvement—and cut per-run costs by 67%.

[SITUATION]
We had a global OSM ingestion pipeline processing massive geographic 
datasets. Every cycle took 41-42 hours, which blocked downstream releases 
and was expensive to run.

[TASK]
I took end-to-end ownership to cut runtime and cost while preserving 
data correctness and not breaking downstream consumers.

[ACTION - KEY DECISION FIRST]
I analyzed the flow and found we were materializing intermediate formats 
just for visualization. That was the bottleneck. So I redesigned the pipeline 
to operate on in-memory data models instead—eliminated unnecessary format 
conversions, applied row-level transforms in-pipeline.

For safety, I worked with Ops to build a diff-based validation framework 
that showed feature-level changes (geometry vs tag diffs). We agreed on a 
≤1% diff threshold as our success criteria.

[RESULT]
• Runtime dropped to 8h (from 42h)
• Cost fell to $150 per run (from $450)
• Ops' confidence was preserved—they could see diffs
• The design was reused for other regions

That's the story. Happy to dive into any part."
```

---

## 📱 Quick Reference During Interview

| If They Ask | Say | Then |
|-------------|-----|------|
| Tell me about yourself | [Your 30-45s intro] | Wait for next question |
| Project you owned | Maps Pipeline (STAR) | Listen for follow-up |
| Risks & mitigation | Story 3 (Risk mit.) or baked into 2 | Listen for follow-up |
| Worked across teams | Stakeholder OR Influence story | Listen for follow-up |
| Mistake & learning | Story 5 (Mistake & Learn.) | Emphasize process change |
| Why DoorDash | [Culture fit answer] | Connect to mission |
| Any questions | Q1 (data problems), Q2 (collab) | Listen & engage |

---

## 🧠 Mental Preps Before Walking In

```
□ Remember: They WANT to hire you (you made it to leadership round)
□ Remember: You have real, credible stories (not made up)
□ Remember: Slow down and breathe (pacing matters)
□ Remember: If you don't know an answer, say so (better than BS)
□ Remember: This is a conversation, not a quiz
□ Remember: Ask questions back (shows genuine interest)
□ Remember: Show up authentically (they want to know YOU)
```

---

## ⏰ Day-Of Timeline

```
1 hour before: Review this cheat sheet + your numbers
30 min before: Quick bathroom break, water, deep breaths
15 min before: Close this document; mentally review 3-4 key stories
5 min before: Test video/audio if virtual; smile & ground yourself
```

---

## 🚀 You're Ready

You've prepared well. Your stories are real, credible, and aligned with what 
DoorDash values. Trust your preparation. Be yourself. Show your impact.

**Good luck!**


