# WBD Senior Data Engineer — Full Q&A Bank
## All 5 Scenarios · Interviewer Questions + Model Answers

**Round:** Software Architecture / System Design (Scale, Global)  
**Principles:** Empower Storytelling · Dream It & Own It  
**Format:** Study reference — questions a WBD panel will ask + canonical answers

---

# SCENARIO 1 — Real-time viewership pipeline (Max)

## Requirements & sizing

**Q: Walk me through your requirements before you design anything.**

A: Split into functional and non-functional.  
Functional: real-time OLAP on viewership events; end users are content and product teams; three metrics — live viewer counts, drop-off rates, buffering metrics; real-time dashboard + historical 7-day lookback.  
Non-functional: 30-second end-to-end SLA; TAU 100M subscribers; peak concurrent 20–30M (not full TAU — not all subscribers watch simultaneously); 10x spike multiplier; PII on user_id and device_id; hard data isolation by region for GDPR.

---

**Q: Why not design for 100M concurrent users?**

A: TAU is the capacity ceiling, not the operational steady state. Designing for 100% concurrency is 3–5x over-provisioned. WBD is actively deleveraging — an architecture that wastes 3x compute budget will get rejected in design review. The correct approach is design for realistic peak (20–30M concurrent) with elastic auto-scaling headroom to absorb full TAU bursts during NBA finals or HBO premieres.

---

**Q: Size the pipeline from scratch.**

A:
```
Peak concurrent         = 25M (25% of TAU)
Events/user/hour        = 50 (heartbeat every ~72 sec)
Baseline events/sec     = 25M × 50 / 3600 = ~350K/sec
Spike events/sec        = 350K × 10 = ~3.5M/sec
Event payload           = 0.5 KB
Peak throughput         = 3.5M × 0.5KB = ~1.75 GB/sec
Kafka partitions        = 1750 MB/sec ÷ 10 MB/sec = ~175 → round to 200
```

---

**Q: What fields must be in your event payload and why?**

A: event_id (dedup), event_type (play/pause/buffer/stop — drives active viewer logic), user_id (PII — masked), session_id (required to stitch drop-off funnel — without it you cannot compute where users stopped watching), content_id (the grouping key for all metrics), event_ts (event time not ingestion time — drives watermarking), buffering_ms (explicit requirement for buffering metrics — if not in payload cannot be measured downstream).

---

## Ingestion

**Q: Why REST proxy instead of direct Kafka producer from the SDK?**

A: Client devices — phones, smart TVs, browsers — cannot speak native Kafka binary protocol. REST proxy is a stateless HTTP-to-Kafka bridge. Being stateless means any instance handles any request — ALB routes freely with no sticky sessions. At 3.5M events/sec, managing millions of native Kafka connections from client devices would overwhelm broker connection limits.

---

**Q: What's your SPOF mitigation for the REST proxy fleet?**

A:
```
SDK local buffer (retries if ALB returns 503)
      ↓
AWS ALB (health checks, removes unhealthy instances in seconds)
      ↓
Confluent REST Proxy fleet (EC2 ASG, scales on CPU/request rate)
      ↓
MSK (ISR replication absorbs broker failures)
```
SDK-level local buffer is the last line of defence — during a proxy restart we cannot lose 30 seconds of viewership data from 30M users.

---

**Q: acks=1 or acks=all for viewership events?**

A: acks=1. Viewership counts are approximate by design. Losing 0.1% of events during a broker failover is not a business problem — the content team doesn't need exact counts, they need directional signals. Exact historical counts live in Snowflake after deduplication via Snowpipe. acks=all would add latency at every write — unacceptable at 3.5M events/sec with a 30-second SLA.

---

**Q: How does Kafka batching work inside the REST proxy?**

A: No custom code needed. The Kafka producer inside the proxy has three configs:
- linger.ms=10 — wait 10ms to accumulate events before flushing
- batch.size=65536 — flush if buffer hits 64KB before linger expires
- compression.type=lz4 — compress batch before sending

This collapses millions of individual events into thousands of compressed network round trips per second. SDK-side batching (every 5s) and producer-side batching (every linger.ms) work independently and complement each other.

---

## Stream processing

**Q: What Flink window type for live viewer counts and why?**

A: Sliding window — not tumbling, not session.
- Tumbling: fixed non-overlapping buckets — count only updates at bucket end, too infrequent for 30-sec SLA
- Session: gap-based — correct for session stitching, not for continuous live counts
- Sliding(size=1min, slide=10sec): emits a fresh count every 10 seconds covering the last 60 seconds. Count updates 6 times per minute — within 30-sec SLA.

---

**Q: Close the SLA math for me.**

A:
```
Watermark        15 sec
+ Slide interval 10 sec
+ Flink proc      3 sec
+ Redis write     2 sec
─────────────────────────
Total            30 sec ✅
```
Watermark rule: watermark ≤ 15% of window size. Window=1min, watermark=15sec (25%) — slightly aggressive but acceptable at this latency budget.

---

**Q: What is your definition of an active viewer?**

A: Event-driven, not purely time-driven.
- play → active
- buffer → active (still consuming stream)
- pause → active for current 10-sec slide only
- stop → excluded immediately

Eviction: a user who pauses and sends no further event within 10 seconds falls out of the next window computation naturally. No separate KeyedProcessFunction timer needed — window expiry is the eviction mechanism. This solves the halftime problem: 40% of users pause during NBA halftime, within 10 seconds non-returning users drop from active count.

---

**Q: What happens to late events beyond your watermark?**

A: Dropped from the real-time path. This is the Lambda architecture tradeoff — own it explicitly. Late events beyond 15 seconds still land in S3 Bronze via Flink Job 2, get ingested into Snowflake via Snowpipe, and are included in the exact historical counts after deduplication. Real-time = approximate. Historical = exact.

---

**Q: How does PII masking work in Flink?**

A: Hash user_id with a deterministic daily salt stored in AWS Secrets Manager. Deterministic — not random — because a random salt per event means the same user hashes differently on each event, breaking distinct user counting. Deterministic salt rotates daily for security but stays consistent within a processing window. This happens as the first operator in Flink Job 1 before any write to Redis or S3.

---

## Storage & serving

**Q: Why Redis for the real-time serving layer?**

A: Sub-millisecond KV lookup. The dashboard needs live viewer counts per content_id — a single HGET per content piece. Redis Cluster sharded by content_id gives even key distribution with no cross-shard operations. No other technology gives sub-ms lookup at this scale.

**Q: What's the Redis failure mode at spike events and how do you mitigate?**

A: Memory pressure. At 25M concurrent users the Redis keyspace expands rapidly. If maxmemory is reached, Redis silently evicts keys under the allkeys-lru policy — viewer counts drop to zero on the dashboard. Not a pipeline failure — a capacity failure. Mitigation: Datadog alert at 70% memory utilisation (not 80%), pre-scale Redis cluster before known spike events (NBA schedule, HBO release calendar), shard by content_id for even key distribution.

---

**Q: Why CLUSTER BY (event_date, region) in Snowflake and not a partition key?**

A: Snowflake uses automatic micro-partitioning — there is no explicit partition key in the Hive or BigQuery sense. CLUSTER BY guides which columns Snowflake uses for micro-partition pruning. A 7-day drop-off query filtering on event_date prunes to exactly 7 micro-partition groups. Region as second clustering key optimises compliance-scoped queries (EU analysts querying EU data only) and maps to data residency requirements.

---

**Q: Write the drop-off Dynamic Table SQL.**

A:
```sql
CREATE OR REPLACE DYNAMIC TABLE content_dropoff_metrics
    TARGET_LAG = '1 hour'
    WAREHOUSE  = PROD_ANALYTICS_WH
AS
SELECT
    content_id,
    event_ts::DATE AS event_date,
    COUNT(DISTINCT CASE WHEN event_type='play' THEN user_id END) AS viewers_started,
    COUNT(DISTINCT CASE WHEN event_type='stop' THEN user_id END) AS viewers_stopped,
    ROUND(
      COUNT(DISTINCT CASE WHEN event_type='stop' THEN user_id END) * 100.0 /
      NULLIF(COUNT(DISTINCT CASE WHEN event_type='play' THEN user_id END),0)
    ,2) AS dropoff_rate_pct,
    AVG(buffering_ms) AS avg_buffering_ms
FROM viewership_events_silver
WHERE event_ts >= DATEADD(day,-7,CURRENT_TIMESTAMP)
GROUP BY content_id, event_date;
```

---

**Q: Viewer count flatlines to zero at 11pm during an HBO premiere. Walk me through incident response.**

A:
```
Step 1 — Kafka: consumer lag on flink-realtime-cg
  Lag spiking → Flink behind → scale task managers
  Lag flat    → problem downstream of Kafka

Step 2 — Flink UI: backpressure + checkpoint duration
  Backpressure high → scale task managers
  Checkpoint > 45s  → RocksDB state backend issue

Step 3 — Redis: memory + CPU
  Memory > 80% → eviction kicking in ← most likely cause at spike
  CPU throttle  → too many HINCRBY ops → shard more aggressively

Step 4 — Dashboard API: isolate by metric pattern
  All metrics zero    → Redis down / network partition
  Only viewer count   → Flink Job A failed, Job B running
  Historical stale    → Snowflake Dynamic Table refresh failed
```

---

# SCENARIO 2 — Global multi-tenant data platform

## Architecture decisions

**Q: You have 10 PB across Snowflake, Redshift, and BigQuery. What open table format do you standardise on?**

A: Apache Iceberg. Three reasons:
1. Broadest multi-engine support — Spark, Trino, Athena, Snowflake external tables all read Iceberg natively
2. ACID transactions, time-travel, schema evolution — required for CDC pipelines on subscriber data
3. Vendor-neutral — avoids lock-in across three legacy platforms during a multi-year migration
Delta Lake is Databricks-native, less portable. Hudi is stronger for upsert-heavy CDC but narrower ecosystem. At WBD's scale and multi-cloud footprint, Iceberg is the right choice.

---

**Q: Why not Snowflake-only at 10 PB?**

A: Three problems. First, migrating 10 PB is a 2-year programme — you need to serve the business while migration is in flight. Second, Snowflake is SaaS — you cannot guarantee EU compute never leaves EU infrastructure, which GDPR Article 44 requires for cross-border transfers. Third, Snowflake storage at 10 PB is significantly more expensive than S3 + Iceberg. Correct answer: Iceberg on S3 as the storage layer, Snowflake as the governed query and transformation layer on top — the hybrid lakehouse pattern.

---

**Q: How do you handle EU data residency with Snowflake Data Sharing?**

A:
```
EU Snowflake Account (Business Critical, eu-west-1)
  GOLD layer: aggregated metrics, no raw PII
  SHARE: eu_aggregated_metrics → NA Snowflake Account

What can be shared:   aggregated metrics, tokenised identifiers
What cannot be shared: raw user_id, email, payment data, row-level EU data

Mechanism: Data Share uses metadata pointers — no physical data movement
           EU data stays in EU storage
           NA account reads via secure share
```

---

**Q: How does GDPR right to erasure work in your pipeline? Is hashing enough?**

A: Hashing is NOT enough. Hashing is deterministic — the hash of user_id still exists in Bronze, Silver, Gold, Snowflake Time Travel (90 days), Fail Safe (7 days), audit logs, and Data Shares. It transforms PII but does not erase it.

Correct solution — tokenization at ingest:
```
1. At Bronze ingest: replace raw user_id with token_id
   Token mapping stored in encrypted Token Vault
   All downstream tables use token_id only

2. Erasure request received:
   Delete token_id → user_id mapping in Token Vault
   All downstream token_ids become orphaned — cannot be re-identified
   Satisfies pseudonymisation under GDPR Article 4(5)

3. SET DATA_RETENTION_TIME=0 on Token Vault → removes Time Travel snapshots
4. Scheduled Snowpark job purges raw PII rows from Bronze
5. Data Share updated to exclude orphaned tokens
```

---

**Q: When would you use Snowflake Dynamic Data Masking vs tokenization?**

A:
```
Dynamic Data Masking → query-time masking based on role
  Underlying data unchanged
  Different roles see different representations of same column
  Use for: analysts who need to see data but not raw PII
           PHI_HIGH sees raw token, ANALYST sees SHA2 hash

Tokenization → physical replacement at ingest time
  Underlying data changed permanently
  Use for: GDPR erasure (only way to truly satisfy Article 17)
           Cross-system PII removal

Rule: Dynamic Masking for access control. Tokenization for compliance.
```

---

**Q: How do you prevent a runaway query from consuming the entire platform compute budget?**

A: Three layers:
```
Layer 1 — Resource Monitors (hard stop)
  CREATE RESOURCE MONITOR analytics_monitor
    WITH CREDIT_QUOTA = 500
    TRIGGERS
      ON 75 PERCENT DO NOTIFY
      ON 90 PERCENT DO NOTIFY
      ON 100 PERCENT DO SUSPEND;

Layer 2 — Query timeout
  ALTER WAREHOUSE PROD_ANALYTICS_WH SET
    STATEMENT_TIMEOUT_IN_SECONDS = 3600
    STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;

Layer 3 — Workload isolation by type not team
  PROD_DASHBOARD_WH  XS  always-on       → live dashboards
  PROD_ANALYTICS_WH  M   auto-suspend    → ad-hoc queries
  PROD_ML_WH         XL  10pm–6am only   → ML training
  PROD_INGEST_WH     S   auto-suspend    → dbt/Snowpipe
```

---

**Q: How do you chargeback compute costs to business units?**

A:
```sql
-- Tag warehouses at creation
ALTER WAREHOUSE PROD_ANALYTICS_WH SET
    TAG business_unit='content_analytics', region='NA', team='product';

-- Weekly chargeback query
SELECT tag_value AS business_unit,
       SUM(credits_used) AS credits,
       ROUND(SUM(credits_used)*3.00,2) AS cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY m
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES t
    ON t.object_name = m.warehouse_name
WHERE m.start_time >= DATEADD(week,-1,CURRENT_TIMESTAMP)
GROUP BY business_unit ORDER BY credits DESC;

Rollout: Month 1–3 showback only → Month 4+ chargeback against team budget
```

---

**Q: A NA data scientist wants to train a global churn model. EU data cannot leave EU. How do you serve this?**

A: Federated learning.
```
EU Snowpark (EU compute):
  Trains local model on EU subscriber data
  Produces model weights (gradients) — not raw data
  Sends weights to NA aggregation layer

APAC Snowpark (APAC compute):
  Same process on APAC data
  Sends weights to NA

NA aggregation:
  Receives weights only (not raw data ✅)
  Federated averaging (FedAvg) produces global model
  Distributes global model back to regional serving layers

Why compliant: raw PII never leaves EU or APAC
               model weights are mathematical gradients — not re-identifiable
               compute runs in-region → satisfies GDPR Article 44
```

---

**Q: How does a GDPR auditor trace a user's data end-to-end?**

A: Two layers of lineage:
```
Layer 1 — Snowflake native:
  SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY → who queried which column when
  SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY  → full SQL of every query

Layer 2 — Cross-system (DataHub or Alation):
  DataHub Kafka connector → captures topic schemas and producer metadata
  DataHub Snowflake connector → table and column-level lineage
  dbt integration → ingests dbt manifest.json for model lineage
  Result: one lineage graph from raw event source to Looker dashboard

Auditor answer: "This EU user's token_id appears in:
  1. Kafka topic max.viewership.events.eu
  2. S3 path s3://wbd-eu-bronze/viewership/...
  3. Snowflake EU RAW.viewership_events_raw
  4. Snowflake EU STAGING.viewership_events_silver (tokenized)
  5. Snowflake EU MARTS.content_metrics (aggregated, no token_id)
  6. Data Share to NA: aggregated only"
```

---

# SCENARIO 3 — Ad-impression pipeline

## Deduplication

**Q: Name five root causes of duplicate impression_ids.**

A:
1. At-least-once Kafka delivery — producer retries on timeout → same message twice. Fix: enable.idempotence=true
2. Client SDK retry logic — SDK retries after network drop before ACK → same impression_id twice. Most common source
3. Two-source fan-in — ad-server emits impression_served, SDK emits impression_viewed, both carry same impression_id. If pipeline doesn't distinguish sources → one impression counted twice. Primary cause of WBD's $4M discrepancy
4. Watermark failures — late events reprocessed after window closes, same impression_id in two window computations
5. Pipeline replay after crash — Flink replays from checkpoint, events already written get written again. Fix: idempotent sinks

---

**Q: acks=1 or acks=all for ad impression events?**

A: acks=all — non-negotiable. Every lost impression is lost revenue. This is financial-grade data, not approximate telemetry.
```
acks=all config:
  acks                = all
  min.insync.replicas = 2
  enable.idempotence  = true
  transactional.id    = set

Contrast with viewership:
  Viewership → acks=1 (approximate acceptable)
  Ad billing → acks=all (exactly-once required)
```

---

**Q: What are the three reconciliation outcomes and what do you do with each?**

A:
```
Case A: served + viewed matched → VERIFIED ✅
  Billable impression → count toward invoice

Case B: served, no viewed → UNVERIFIED_SERVE ⚠️
  Ad delivered but client never confirmed render
  Causes: ad blocker, page closed, SDK event lost
  NOT billable → route to reconciliation table
  Finance reviews: if > threshold% → flag for advertiser credit
  This is how over-reporting happens

Case C: viewed, no served → ORPHAN_VIEW 🚨
  Client confirmed view but ad-server has no delivery record
  Causes: ad-server event lost, bot traffic, clock skew
  Hold in pending state for watermark duration
  If no served event after watermark → SUSPICIOUS → fraud pipeline
  NOT billable → this is how bot traffic inflates counts
```

---

**Q: Why session window for cross-source reconciliation, not sliding?**

A: Sliding window has a fixed time boundary. If impression_served arrives at t=0 and impression_viewed arrives at t=45sec, a 30-sec tumbling window puts them in different buckets — they never match. Session window groups events by impression_id with a gap timeout. As long as both events arrive within the gap, they are matched in the same session.
```
Session window config:
  KeyedStream(impression_id)
  Session gap = 2 minutes (SDK has up to 2min to confirm view)
  Watermark = 30 seconds
```

---

**Q: Why Redis SETNX instead of GET+SET for cross-source dedup?**

A:
```
GET + SET is two operations — race condition:
  t=0 Writer A: GET impression:abc → null
  t=0 Writer B: GET impression:abc → null  ← both see empty
  t=1 Writer A: SET impression:abc → OK
  t=1 Writer B: SET impression:abc → OK    ← duplicate survives

SETNX is atomic — single operation:
  t=0 Writer A: SETNX impression:abc → 1 (set, was empty) → process
  t=0 Writer B: SETNX impression:abc → 0 (not set, existed) → DLQ
  No race condition possible at Redis level
```

---

**Q: A Flink task manager crashes mid-window. What happens to 500K in-flight impression events?**

A:
```
1. Flink restores from last checkpoint (offset-based, not timestamp-based)
   Restores: Kafka consumer offsets per partition + RocksDB operator state

2. Kafka replays events from checkpointed offset
   ~500K events re-enter pipeline

3. RocksDB dedup state (TTL=24h) catches within-source duplicates on replay
   Second occurrence of same impression_id → DLQ, not processed again

4. Session windows rebuild from replayed events
   State lost between checkpoint and crash → sessions re-open from replay

5. Redis SETNX absorbs cross-source duplicates on replay
   Already-written impression_ids → SETNX returns 0 → DLQ

6. Snowflake MERGE deduplicates on impression_id in Silver layer
   Guarantees exactly-one row per impression regardless of replay count

Critical nuance: session window state between checkpoint and crash is lost
  → sessions rebuild from Kafka replay
  → checkpoint interval ≤ 60 seconds for financial pipelines
```

---

**Q: Advertiser claims 13% discrepancy vs DoubleVerify. Walk me through dispute resolution.**

A:
```sql
-- Step 1: Pull reconciliation record
SELECT wbd_verified_count, dv_verified_count,
       discrepancy_pct, reconciliation_status
FROM billing_reconciliation
WHERE campaign_id='disputed-id' AND billing_date BETWEEN x AND y;

-- Step 2: Break down by status
SELECT status, COUNT(*) AS count,
       ROUND(COUNT(*)*100.0/SUM(COUNT(*))OVER(),2) AS pct
FROM impressions_silver
WHERE campaign_id='disputed-id'
GROUP BY status;
-- Shows VERIFIED / UNVERIFIED_SERVE / ORPHAN_VIEW split

-- Step 3: Inspect Bronze for raw audit trail
SELECT impression_id, source, event_ts, ingestion_ts
FROM impressions_raw WHERE campaign_id='disputed-id';
```

Three most likely causes of 13% gap:
1. UNVERIFIED_SERVE counted by WBD but not DoubleVerify (~5–8%) — ad served but not rendered
2. Viewability threshold mismatch (~3–5%) — WBD counts any render, DV requires 50% pixels visible for 2 continuous seconds
3. Timezone/date boundary discrepancy (~1–2%) — WBD uses event_ts, DV uses their ingestion_ts, events near midnight cross differently

---

# SCENARIO 4 — Subscriber churn prediction pipeline

## Requirements

**Q: What are the data sources for a churn prediction pipeline?**

A:
```
Subscriber lifecycle events (CDC from operational DB):
  signup, upgrade, downgrade, cancel, reactivate
  Schema: user_id, event_type, plan_tier, event_ts, region

Engagement signals (streaming from Kafka):
  watch_time_minutes, content_completed, days_since_last_watch,
  session_count_7d, genre_affinity_score

Payment events:
  payment_success, payment_failed, refund_issued

Content signals:
  content_id watched, completion_rate, rating given

External signals:
  price_change_ts (did this user churn after a price increase?)
  content_removal_ts (did this user churn after a show was removed?)
```

---

**Q: What latency SLA does each consumer need?**

A:
```
ML model inference (next-best-action API)  < 50ms     → Redis online features
Near-real-time churn score dashboard       < 1 hour   → Snowflake Dynamic Tables
Daily churn report (marketing team)        T+1        → Snowflake Gold layer
ML model training (weekly retrain)         < 6 hours  → S3/Iceberg offline features
```

---

**Q: Walk me through the full churn pipeline architecture.**

A:
```
Sources:
  Subscriber CDC → Debezium → Kafka (sub.lifecycle.events)
  Engagement events → Flink → Kafka (sub.engagement.events)
  Payment events → Debezium → Kafka (sub.payment.events)

Flink Job 1: Feature computation
  KeyedStream(user_id)
  Sliding window(7 days, slide=1 hour):
    watch_time_7d, session_count_7d, days_inactive,
    genre_diversity_score, completion_rate_7d
  Tumbling window(30 days):
    payment_failures_30d, plan_changes_30d
  Output → Kafka (features.computed)

Flink Job 2: Churn signal aggregation
  Joins lifecycle + engagement + payment streams
  Computes: churn_risk_score (rule-based, before ML)
  Writes to:
    Redis → online feature store (< 50ms serving)
    S3 Iceberg → offline feature store (ML training)
    Kafka → features.churn_signals

Snowflake layer:
  RAW → Snowpipe from S3
  SILVER → dedup + PII tokenization + feature validation
  GOLD → churn_risk by segment, region, plan_tier
  Dynamic Tables → 1-hour refresh for dashboard

ML serving:
  Online: Redis feature store → model inference API → next-best-action
  Offline: S3 Iceberg features → SageMaker training → weekly model retrain
```

---

**Q: What is point-in-time correctness and why does it matter for churn?**

A: Point-in-time correctness means when training a churn model, the features used to predict churn at time T must only include data that was available before time T — not data that arrived later. Without it, the model leaks future information into training — label leakage.

Example: a user churned on Jan 15. Their engagement dropped significantly on Jan 10. If training features include engagement data from Jan 16 (after churn), the model learns a spurious pattern. In production, that data won't exist at prediction time — model performance degrades dramatically.

Fix: point-in-time joins using Iceberg time-travel:
```sql
SELECT f.*, l.churned
FROM features f
JOIN labels l ON f.user_id = l.user_id
  AND f.feature_ts < l.churn_ts  -- only features before churn event
```

---

**Q: What features are most predictive of churn at a streaming platform?**

A:
```
High signal:
  days_since_last_watch         → strongest single predictor
  watch_time_7d (trending down) → declining engagement
  payment_failed_count_30d      → involuntary churn signal
  plan_downgrade_event          → voluntary churn precursor (6-week lag)
  content_completion_rate       → low = not finding value

Medium signal:
  genre_diversity_score (low)   → narrow tastes = more churn risk
  session_count_7d decline      → engagement trend
  support_tickets_30d           → dissatisfaction signal

WBD-specific:
  churn_after_show_removal      → did user churn when specific show was removed?
  churn_after_price_increase    → price elasticity signal per plan tier
  content_id affinity score     → if key content expires, churn risk spikes
```

---

**Q: How does your pipeline handle a user who cancels and reactivates multiple times?**

A: This is the reactivation edge case. Standard churn labels break because the user appears as both churned and active.

```
Correct approach — subscription state machine:
  States: ACTIVE → CANCELLED → REACTIVATED → CANCELLED...

  Label: churned = True only if CANCELLED for > 30 days
         (distinguishes intentional churn from accidental cancellation)

  Feature: reactivation_count — how many times has user churned and returned?
           High reactivation_count = price-sensitive user, not true churner

  Flink stateful processor:
    KeyedState(user_id): tracks subscription state history
    On REACTIVATED event: clear churn label for that period
    Emit: lifecycle_segment = CHURNER | RETURNER | STABLE
```

---

**Q: How do you prevent training data leakage when content is removed?**

A: Content removal is a structural break in the feature distribution.
```
Problem: show X is removed on March 1.
  Users who watched show X before March 1 have high affinity for it.
  After March 1, that signal disappears from new users.
  Model trained on pre-March data will overfit to show X affinity.

Fix:
  1. Tag all training examples with content_availability_flag
     (was this content available at feature_ts?)
  2. Exclude features derived from removed content
  3. Retrain model within 2 weeks of any major content removal
  4. Monitor: if model performance degrades after a content removal,
              trigger emergency retrain
```

---

# SCENARIO 5 — Content recommendation feature store

## Architecture

**Q: What is the difference between an online and offline feature store?**

A:
```
Online feature store:
  Purpose: serve features to the recommendation API in real-time
  Latency: < 50ms (model inference is in the critical path of page load)
  Storage: Redis (sub-ms lookup by user_id)
  Data: latest feature values only — no history
  Update: streaming writes from Flink as new engagement events arrive
  Example: user_id → {watch_time_24h, last_genre, completion_rate_7d}

Offline feature store:
  Purpose: provide training data for ML model retraining
  Latency: hours (batch process, not latency-sensitive)
  Storage: S3 + Iceberg (cheap, scalable, time-travel capable)
  Data: full feature history with timestamps
  Update: batch writes from Spark/Flink daily or weekly
  Example: user_id, feature_ts, watch_time_24h, last_genre, ...

Critical requirement: point-in-time correctness in offline store
  Training features at time T must only use data available before T
```

---

**Q: Walk me through the full recommendation pipeline.**

A:
```
Engagement events (play, complete, skip, rate, search)
  → Kafka (eng.events) via SDK → REST Proxy → MSK

Flink Job 1: User feature computation
  KeyedStream(user_id)
  Sliding window(24h, slide=15min):
    watch_time_24h, genres_watched, completion_rate,
    skip_rate, search_queries, time_of_day_preference
  Output → Kafka (features.user)

Flink Job 2: Content feature computation
  KeyedStream(content_id)
  Tumbling window(1h):
    total_views_1h, avg_completion_rate, trending_score,
    audience_overlap_score
  Output → Kafka (features.content)

Sinks:
  Redis Cluster → online feature store
    Hash key: user:{user_id} → {all user features}
    Hash key: content:{content_id} → {all content features}
    TTL: 48 hours (stale features worse than no features)

  S3 Iceberg → offline feature store
    Partitioned by feature_date, user_region
    Retention: 2 years (model training lookback)

Recommendation API:
  Request: user_id + context (device, time, location)
  Step 1: Redis HGETALL user:{user_id} → user features (< 5ms)
  Step 2: Candidate generation (pre-computed content embeddings)
  Step 3: Ranking model inference (online features as input)
  Step 4: Return ranked content list
  Total latency target: < 50ms
```

---

**Q: How do you handle cold start — a brand new user with no engagement history?**

A:
```
Three strategies, applied in order:

1. Onboarding signals (at signup):
   User selects 3 favourite genres + 5 favourite shows
   These become initial features: genre_affinity = {drama:1.0, comedy:0.8}
   Warm start — not truly cold

2. Demographic + regional defaults:
   New user in India at 9pm → trending content in India + Hindi language boost
   Content popular with similar demographics (age, region, device)
   Use collaborative filtering on similar user cohorts

3. Popularity-based fallback:
   Trending in user's region for their device type
   Gradually replaced as engagement signals accumulate
   Typically 3–5 sessions before personalisation kicks in

Feature store impact:
   New user → Redis key doesn't exist → API falls back to cohort features
   After 3 sessions → Redis populated → full personalisation
```

---

**Q: How do you ensure feature freshness — what happens if Flink falls behind?**

A:
```
Feature staleness is worse for some features than others:

High freshness required (< 15 min):
  watch_time_24h, last_genre_watched, session_active_flag
  Stale → recommend content user just watched → bad UX

Medium freshness acceptable (< 1 hour):
  completion_rate_7d, genre_diversity_score
  Slow-moving signals — 1-hour staleness acceptable

Low freshness required (daily):
  content_popularity_score, audience_overlap
  Batch-computed overnight — Flink not needed

Freshness monitoring:
  Each Redis key stores feature_computed_ts
  API checks: if NOW - feature_computed_ts > threshold → serve cohort fallback
  Datadog alert: Flink consumer lag > 5min → PagerDuty to data team

Flink falls behind (consumer lag spikes):
  Auto-scale Flink task managers (MSK → EMR managed scaling)
  Serve cohort-level features from S3 as fallback
  Alert: feature freshness SLA breached for X% of users
```

---

**Q: How do you handle A/B testing on the recommendation model?**

A:
```
Experimentation layer sits between feature store and ranking model:

User assignment:
  user_id → hash(user_id, experiment_id) % 100 → bucket
  Bucket 0–49  → Control (current model)
  Bucket 50–99 → Treatment (new model)
  Assignment stored in Redis: user:{user_id}:experiment → {exp_id, variant}
  Deterministic — same user always gets same variant (no flicker)

Feature store impact:
  Both variants read from same Redis feature store
  Model weights differ — features are the same
  Ensures any performance difference is model-driven, not feature-driven

Metrics pipeline:
  Each recommendation served tagged with: experiment_id, variant, user_id
  Engagement events joined back to experiment assignment
  Metrics: CTR, watch_time, completion_rate per variant
  Snowflake Dynamic Table: experiment_results refreshed hourly

Statistical significance:
  t-test on primary metric (CTR) per variant
  Minimum sample size: pre-computed before experiment launch
  Guardrail metrics: churn_rate, support_tickets (must not degrade)
  Auto-stop: if guardrail breached → kill treatment, rollback to control

Snowflake experiment results table:
  experiment_id, variant, users_assigned, ctr, watch_time_lift,
  p_value, is_significant, recommendation
```

---

**Q: What is the risk of using online features for both model training and serving?**

A: Training-serving skew. If the model is trained on offline features from S3 but served with online features from Redis, any difference in how features are computed creates a distribution mismatch — the model sees different input at serving time than at training time. Performance degrades silently.

Fix:
```
Unified feature computation:
  Single Flink job writes to BOTH Redis (online) and S3 Iceberg (offline)
  Same computation logic, same feature definitions
  Guarantees: training features = serving features

Feature validation:
  Before model deployment: run inference on offline features
  Compare distribution: online Redis features vs offline S3 features
  Alert if drift > 5% on any feature — training-serving skew detected

Monitoring in production:
  Log feature values at inference time → compare vs training distribution
  Statistical drift detection (PSI score per feature)
  If PSI > 0.2 → trigger model retrain
```

---

# CROSS-CUTTING QUESTIONS (any scenario)

**Q: When do you use Flink vs Spark Streaming?**

A:
```
Flink:
  True event-time processing required
  Stateful operations (dedup, session windows, CEP)
  SLA < 60 seconds
  Complex watermarking strategies
  WBD use cases: viewership counts, ad dedup, churn feature computation

Spark Structured Streaming:
  Team already on Spark — same codebase for batch + streaming
  Micro-batch acceptable (1–5 min latency)
  Heavy ML feature engineering in pipeline
  Easier backfill logic (same Spark job, different input)
  WBD use cases: daily feature computation, content metadata processing
```

---

**Q: When do you use Kafka vs Kinesis?**

A:
```
Kafka (MSK):
  > 500K events/sec
  Multi-consumer fan-out (multiple Flink jobs same topic)
  Long retention needed (days to weeks for replay)
  Multi-cloud or portability required
  Complex consumer group management needed

Kinesis:
  < 500K events/sec
  AWS-native consumers (Lambda, Kinesis Analytics, Firehose)
  Team lacks Kafka expertise — zero broker management
  Cost predictability at moderate scale

WBD rule: MSK for all streaming pipelines > 500K events/sec
          Kinesis for low-volume internal feeds (CMS changes, metadata updates)
```

---

**Q: When do you use Redis vs Pinot vs Snowflake for serving?**

A:
```
Redis:
  Sub-ms KV lookup (live counts, user features, campaign pacing)
  Simple data structures (HASH, ZSET, STRING)
  Data fits in memory
  WBD: viewer counts, online features, ad pacing

Pinot / Druid:
  Sub-second OLAP on fresh streaming data
  High query concurrency (1000+ queries/sec)
  Simple GROUP BY aggregations on recent data
  WBD: Ad Ops live dashboard, content trending queries

Snowflake:
  Complex SQL (window functions, multi-way JOINs)
  Governed RBAC and data isolation
  Latency of 5–30 sec acceptable
  T+1 batch reconciliation and billing
  WBD: advertiser reporting, churn analysis, financial reconciliation
```

---

**Q: How do you anchor a system design decision to WBD business outcomes?**

A: Every technical decision should connect to a content or business metric. Examples:

```
"I'm choosing a 10-second slide interval so the content team gets
 fresh viewer counts during live events — that signal drives real-time
 programming decisions like ad slot timing and push notification triggers."

"I'm using tokenization not hashing for GDPR erasure because WBD operates
 in 220 countries — a failed erasure request in the EU is a regulatory risk
 that dwarfs the engineering cost of building a Token Vault."

"I'm separating ML training (10pm–6am) from dashboard queries (business hours)
 so a 4-hour model training job never impacts the content team's ability to
 monitor live viewership during a premiere."

"I'm choosing federated learning for the global churn model because moving
 EU subscriber data to NA would violate GDPR Article 44 — and the legal
 exposure is not worth the marginal accuracy improvement over
 federated weight aggregation."
```

The formula: [technical decision] + [because it enables/prevents] + [specific WBD business outcome]

---

*End of Q&A bank — 5 scenarios, 50+ questions, all model answers calibrated to WBD Senior Data Engineer bar.*
