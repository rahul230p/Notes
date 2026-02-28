# ⚡ Data Engineer Business Partner - 1-Page Cheat Sheet

## 🎯 What They're Evaluating (45 min round)

✅ **Problem Solving**: Can you break down ambiguous problems with cross-functional teams?  
✅ **Communication**: Can you explain technical concepts to non-technical people?  
✅ **Data Thinking**: Data quality? Modeling? Schemas? Tradeoffs?  
✅ **Collaboration**: Evidence of working well with other teams  
✅ **Iteration**: Do you adapt based on feedback?  

---

## 🗣️ Your 45-Minute Structure

```
0-5 min:     Warm-up, they describe scenario
5-10 min:    YOUR TURN: Ask 3-4 clarifying questions
10-20 min:   Propose approach (data problem → solution)
20-35 min:   Discuss, iterate, handle feedback
35-40 min:   "Tell me about your project" story
40-45 min:   Wrap-up, your questions
```

---

## 🎯 THE FRAMEWORK (Memorize This!)

### For ANY question, use this sequence:

**CLARIFY** (Ask first, don't assume)
```
What's the business problem? (not the data problem)
Who needs this? (PM, Ops, Finance?)
What will they do with it?
What data exists? Quality OK?
What's the timeline?
What success looks like?
Any constraints? (cost, latency)
```

**DATA PROBLEM** (Translate business → data)
```
What data sources?
What schema/modeling?
What's the grain? (customer-day? order-level?)
Data quality issues?
Latency requirements?
Scalability concerns?
```

**SOLUTION** (Propose approach)
```
Architecture/design
How will you handle quality?
What are trade-offs?
How will you test it?
What could go wrong?
```

**COLLABORATION** (How you'd work with teams)
```
Which teams involved?
How often would you communicate?
How would you handle changes?
How would you present to non-technical people?
```

**IMPACT** (Connect to business)
```
How does this help?
What business metric improves?
How will you measure success?
What feedback would you want?
```

---

## 💬 How to Sound Like You Know What You're Doing

**❌ DON'T SAY:**
- "We need to normalize the schema with slowly changing dimensions"
- "Let's implement a fact table with surrogate keys"
- "We'll use Spark for incremental processing"

**✅ DO SAY:**
- "We'll organize your data so it's fast and accurate"
- "I'd keep historical changes so you can see trends"
- "I'd make queries fast without using too much compute"

---

## 📖 Your Project Story (They WILL ask this!)

**Have ONE story ready that shows:**

1. **Business problem** - What did PMs/Ops/Finance need?
2. **Conflict** - Different teams wanted different things
3. **Your approach** - How you understood their needs
4. **Communication** - How you kept them updated
5. **Outcome** - Business impact (faster, cheaper, better decisions?)
6. **Learning** - What you'd do differently

**Time it**: 5-6 minutes, not more

**Practice it**: Say it out loud 5 times before interview

---

## 🚨 Red Flags to Avoid

❌ Jump to solution without questions  
❌ Use too much jargon  
❌ Only think about technical elegance  
❌ Don't mention communication/collaboration  
❌ Miss business context  
❌ Rigid ("my way is best")  
❌ Ignore data quality  
❌ Blame others for problems  

---

## ✅ Green Flags (What They Want)

✅ Ask clarifying questions first  
✅ Explain things simply  
✅ Mention working with other teams  
✅ Discuss trade-offs  
✅ Focus on business impact  
✅ Show flexibility ("I'd iterate based on feedback")  
✅ Propose monitoring/quality checks  
✅ Own problems ("Here's how I'd fix it")  

---

## 🎤 Question Types You'll Get

| They Ask... | You Start With... |
|---|---|
| "Build a data solution for X" | "Let me ask some clarifying questions..." |
| "Data quality is bad. Fix it." | "First, let me understand what 'bad' means..." |
| "Model X for us" | "Before I design, who will use this and how?" |
| "This pipeline is slow" | "When did it start? What changed recently?" |
| "Tell me about your project" | [Your prepared 5-min story] |

---

## 💡 Quick Answers for Common Scenarios

**"We need real-time data"**
```
"Real-time is expensive. Can we start with hourly or daily?
Let's measure: Do your decisions change faster than that?
Then we can upgrade if needed."
```

**"How do we ensure data quality?"**
```
"Monitoring. Tests. Clear ownership. Dashboards.
I'd set up alerts so we catch problems early, not when
your analysis breaks."
```

**"How would you communicate progress?"**
```
"Weekly standups with each team. Shared dashboard.
Clear 'here's what's done, here's what's next.'
No surprises at the end."
```

---

## 📊 Your Competitive Edge

**Most Data Engineers:**
- Jump to architecture/tools
- Use jargon
- Solo work, ignore teams

**You will:**
- Ask clarifying questions ✅
- Explain simply ✅
- Emphasize collaboration ✅
- Connect to business impact ✅
- Iterate based on feedback ✅

**This alone puts you top 20%**

---

## 📋 Day-Of Checklist

**Before Interview:**
- ☐ Project story practiced? (5 min, say it out loud)
- ☐ Know your 3-4 clarifying questions?
- ☐ Remember: This is collaborative, not a test
- ☐ Mindset: "How can I help?" not "Am I smart enough?"

**During Interview:**
- ☐ Ask clarifying questions (don't assume)
- ☐ Think out loud (show your process)
- ☐ Use simple language
- ☐ Listen actively
- ☐ Show you'd work cross-functionally
- ☐ Discuss trade-offs
- ☐ If stuck: "Let me think about that differently..."

**Remember:**
- They want to see HOW you think, not perfect answers
- Collaboration > Technical Elegance
- Simple > Complex
- Questions > Assumptions

---

## 🎯 5-Minute Pre-Interview Warm-Up

1. **Say your project story** (out loud) - 2 min
2. **Review the framework** (Clarify → Data → Solution → Collaboration → Impact) - 1 min
3. **Practice one question** (pick any scenario) - 1 min
4. **Take 3 deep breaths** - You've got this!

---

## 📚 Files to Review Before Interview

**MUST READ:**
1. This file (you're reading it!)
2. DE_SPECIFIC_GUIDE.md (framework for data engineers)
3. PROJECT_STORY_GUIDE.md (prepare your story)

**Should Read:**
4. DE_PRACTICE_SCENARIOS.md (practice at least 2 scenarios)

**Nice to Have:**
5. BP1_Master_Guide.md (general framework reference)

---

## 🎤 Your Opening Line

When they ask their first question, respond with:

```
"Great question. Before I dive in, can I ask a few clarifying questions
to make sure I understand the problem correctly?"

[Then ask 3-4 of your prepared questions]

This immediately shows:
✅ You think before you act
✅ You care about understanding the problem
✅ You're collaborative ("help me understand")
```

---

## 💪 What Success Looks Like

**They walk away thinking:**

"This person:
- Asked good questions before jumping to solutions
- Explained complex things clearly to me (non-technical)
- Clearly has worked cross-functionally
- Thinks about business impact, not just tech
- Would iterate and communicate well
- Someone I'd want on my team"

---

## 🚀 Final Reminders

✅ **Ask clarifying questions first** - Your superpower  
✅ **Explain simply** - Jargon ≠ intelligence  
✅ **Show collaboration** - This round is about teamwork  
✅ **Discuss trade-offs** - Shows mature thinking  
✅ **Tell your project story** - They WILL ask  

---

**You've got this! 🎯**

**Most important: Ask clarifying questions first. That's it. Do that and you're already ahead of 80% of candidates.**

