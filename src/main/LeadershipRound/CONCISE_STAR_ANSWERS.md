# Concise STAR Answers - DoorDash Leadership (4 Points Per Story)
**Minimal words, maximum impact - Quick reference format**

---

## 1️⃣ INTRO: Who You Are (30-45 seconds)
**DoorDash Value:** Ownership + 1% Better

**S:** 5 years DE, batch + real-time platforms (Apple Maps 273 countries, Walmart real-time campaigns, IQVIA multi-tenant)  
**T:** Own pipelines end-to-end; balance performance, correctness, cost, stakeholder needs  
**A:** Worked at scale across 3 companies, different data verticals, business-critical systems  
**R:** Enable faster decisions, reliable data, reduced friction for downstream teams

---

## 2️⃣ APPLE MAPS PROJECT: Own End-to-End (2.5-3 min)
**DoorDash Value:** Ownership + Bias for Action

**S:** 42-hour OSM pipeline (273 countries) blocked releases; bottleneck = excessive materializations  
**T:** Reduce runtime + cost while maintaining correctness + Ops confidence  
**A:** Redesigned using Spark RDDs in-memory, removed intermediate formats, co-designed Neutron Diff validation with Ops  
**R:** 42h→8h (81%), $450→$150 (67%), became reference pattern for 10+ pipelines

---

## 3️⃣ OPS CO-DESIGN: Risk Mitigation (2.5-3 min)
**DoorDash Value:** Make Room at the Table

**S:** Removing artifacts risked losing Ops' trust despite better performance  
**T:** Preserve operational confidence while improving performance  
**A:** Paused, listened to Ops' needs, designed feature-level diffs (≤1% threshold), built Neutron Diff together  
**R:** Validation became objective, Ops' effort dropped hours→minutes, trust strengthened, zero rollout friction

---

## 4️⃣ TRADEOFFS: Performance vs Visualization (2.5-3 min)
**DoorDash Value:** Ownership + Bias for Action

**S:** Full visualization = performance cost; couldn't optimize both  
**T:** Decide which matters more; serve the other use case differently  
**A:** Chose performance + targeted diffs, offered on-demand full downloads, built rollback path  
**R:** 42h→8h gains, preserved Ops visibility, 99% of cases handled by diffs, 1% by downloads

---

## 5️⃣ OWNERSHIP FAILURE: Unclear Boundaries (2.5-3 min)
**DoorDash Value:** 1% Better + Make Room at the Table

**S:** DE + ML both applying geometry corrections; redundant work, confusion, coordination overhead  
**T:** Define clean ownership, enable independent teams  
**A:** Created ownership contracts (DE=base data, ML=downstream corrections), documented interfaces, added monitoring  
**R:** Eliminated redundancy, velocity improved, onboarding faster, quality better, boundaries clear

---

## 6️⃣ STAKEHOLDER: IQVIA Patient Records (2.5-3 min)
**DoorDash Value:** Make Room at the Table

**S:** AHA wanted millions of unfiltered patient records; violated platform SLA  
**T:** Serve need without breaking platform  
**A:** Asked how they use data→learned they filter first, proposed filters+downloads, prototyped, iterated  
**R:** Filtered view actually faster for them, platform SLA maintained, edge cases covered, no friction

---

## 7️⃣ COWORKER CONFLICT: Execution Order (2-2.5 min)
**DoorDash Value:** Make Room at the Table

**S:** Disagreed on mutator execution: I prioritized delivery order, teammate prioritized dependency order  
**T:** Resolve with correctness + velocity  
**A:** Listened to their reasoning, proposed combining both: dependency-based + delivery-priority-weighted  
**R:** Shipped on time, system more correct, teammate respected, framework reusable

---

## 8️⃣ AMBIGUITY: Incomplete Migration (2-2.5 min)
**DoorDash Value:** Bias for Action

**S:** Migration requirements incomplete + evolving, tight timeline  
**T:** Deliver value without perfect clarity  
**A:** Scoped minimal viable redesign (20% work = 80% value), shipped safely with rollback, iterated based on real data  
**R:** Early value delivered, direction improved from feedback, phase 2 was 40% more efficient, finished faster

---

## 9️⃣ REFLECTION: JDBC vs Export (2.5-3 min)
**DoorDash Value:** 1% Better

**S:** Original approach: Spark JDBC reads from Postgres; simple but high DB contention  
**T:** Would you do it differently knowing what you know now?  
**A:** Export to S3 first, then Spark process; validated with POC (measured latency, cost, runtime for both)  
**R:** POC proved export better; now apply to all migrations, reduced DB load, more predictable

---

## 1️⃣0️⃣ MEASURING SUCCESS: How You Track Impact (1.5-2 min)
**DoorDash Value:** Ownership

**S:** DE success is indirect; can't just say "it's better"  
**T:** Define objective success metrics  
**A:** Tracked 4 categories: Reliability (SLA, error rate), Operational (runtime, cost, validation time), Downstream (adoption, support), Business (release velocity, cost savings)  
**R:** Maps pipeline: SLA 85%→98%, runtime 42h→8h, cost $450→$150, adoption 10+ pipelines

---

## 1️⃣1️⃣ SELF-LEARNING: Staying Current (2-2.5 min)
**DoorDash Value:** 1% Better

**S:** Data platforms evolve rapidly; chasing trends kills execution  
**T:** Stay current on fundamentals + important advances  
**A:** (1) Focus on fundamentals (distributed systems, data modeling, SQL, scaling), (2) Read engineering blogs/papers (Netflix, Uber), (3) POCs validate learnings, (4) Share knowledge with team  
**R:** Better architectural decisions, faster tool adoption, credible with team, consistent execution

---

## 1️⃣2️⃣ COWORKER CONFLICT: Resolver (2-2.5 min)
**DoorDash Value:** Make Room at the Table

**S:** Teammate wanted mutator execution: delivery order vs dependency order  
**T:** Resolve conflict; maintain correctness + velocity  
**A:** Listened, combined both ideas: dependency-based ordering + delivery-priority weighting  
**R:** Shipped on schedule, more correct, teammate respected, framework extensible

---

## 1️⃣3️⃣ CULTURE FIT: Why DoorDash? (1.5-2 min)
**DoorDash Value:** All 4 (Ownership + Make Room at Table + Bias for Action + 1% Better)

**S:** Career: Apple (freshness→maps), Walmart (optimization→campaigns), IQVIA (decisions→stakeholders)  
**T:** Why excited about DoorDash  
**A:** (1) Three-sided marketplace = complex scale I've handled, (2) Making room at table (Ops co-design example), (3) Bias for action (pilots over debates)  
**R:** Want to bring: reliable data faster, marketplace complexity expertise, operational perspectives from day one

---

## 1️⃣4️⃣ YOUR QUESTIONS: Ask Them (30-60 sec)

**Q1:** "What are the top 3 data reliability problems the team is solving?"  
**Q2:** "How does the team approach cross-functional collaboration—Ops, Analytics, Product involved in design?"

---

## 🎯 KEY NUMBERS (Memorize)

- **42h → 8h** (runtime improvement)
- **$450 → $150** (cost reduction)
- **85% → 98%** (SLA improvement)
- **273 countries** (scale handled)
- **10+ pipelines** (pattern adoption)

---

## 📋 TIMING PER QUESTION

- Q1 Intro: 30-45s
- Q2-6, Q9: 2.5-3 min each
- Q7-8, Q11: 2-2.5 min each
- Q10: 1.5-2 min
- Q12-13: 1-2 min

---

## 💡 DELIVERY CHECKLIST (Per Story)

✅ One-line outcome first  
✅ Situation = problem/context  
✅ Task = your role/responsibility  
✅ Action = specific steps (lead with key decision)  
✅ Result = metrics + impact  
✅ Use "I" for decisions, "we" for execution  
✅ Specific numbers, not vague  
✅ Authentic, not memorized

---

## 🏢 DOORDASH VALUES MAPPING

| Question | DoorDash Value(s) |
|----------|------------------|
| 1. Intro | Ownership + 1% Better |
| 2. Apple Maps | Ownership + Bias for Action |
| 3. Ops Co-design | Make Room at the Table |
| 4. Tradeoffs | Ownership + Bias for Action |
| 5. Ownership Failure | 1% Better + Make Room at the Table |
| 6. Stakeholder | Make Room at the Table |
| 7. Coworker Conflict | Make Room at the Table |
| 8. Ambiguity | Bias for Action |
| 9. Reflection | 1% Better |
| 10. Measuring Success | Ownership |
| 11. Self-Learning | 1% Better |
| 12. Coworker Conflict | Make Room at the Table |
| 13. Culture Fit | All 4 Values |

---

## 🔑 DOORDASH VALUES SUMMARY

**Ownership:** Questions 1, 2, 4, 10  
→ Taking end-to-end responsibility, driving results, measuring impact

**Make Room at the Table:** Questions 3, 5, 6, 7, 12, 13  
→ Listening, collaboration, including diverse perspectives, resolving conflicts

**Bias for Action:** Questions 2, 4, 8, 13  
→ Moving fast, pilots over debates, shipping incrementally, iterating

**1% Better:** Questions 1, 5, 9, 11, 13  
→ Continuous learning, reflection, improvement, growth mindset


