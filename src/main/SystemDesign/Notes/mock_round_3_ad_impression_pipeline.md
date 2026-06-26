# Mock Round 3 — Ad-impression pipeline
## Canonical reference answers

**Company:** Warner Bros. Discovery  
**Role:** Senior Data Engineer  
**Round:** Software Architecture / System Design (Scale, Global)  
**Principles:** Empower Storytelling · Dream It & Own It

---

## Problem statement

Max has launched an ad-supported tier (AVOD) serving ads to 50M+ subscribers globally. Advertisers pay WBD based on **impressions delivered**. The current pipeline is losing impressions in transit, double-counting others, and reported impression counts don't match the ad-serving system. Last quarter this discrepancy cost **$4M in revenue** — over-reports led to advertiser credits, under-reports left money on the table.

Design an ad-impression pipeline that ingests impression events at scale, deduplicates with financial-grade accuracy, and produces a reconciled impression count that WBD can bill advertisers from.

---

## Step 1 — Requirements elicitation

### Questions to ask before designing

**Functional:**
- Who are the end users and what do they need?
- What are the incoming event types and sources?
- What are the downstream access patterns?
- Does the ML team need a feature store?
- Does Ad Ops need real-time OLAP?

**Non-functional:**
- What is the event volume and spike profile?
- What are the latency SLAs per consumer?
- What is the data retention policy?
- What PII masking is required?

### Answers

**End users:**

| User | Need |
|---|---|
| Ad Operations | Live campaign delivery, pacing, spend |
| Advertiser reporting | Hourly/daily impression counts per campaign |
| Finance / Revenue | Exact reconciled counts for billing (T+1) |
| Data Science / ML | Ad targeting and auction models |
| Legal / Compliance | Audit trail for advertiser disputes |

**Two incoming event sources — this is the critical insight:**

```
Source 1: Ad-serving system (supply side)
  Event:  impression_served — emitted when ad is delivered to device
  Topic:  ad.impressions.served
  Fields: impression_id, campaign_id, ad_id, user_id,
          content_id, served_ts, device_type, region

Source 2: Client SDK (demand side)
  Event:  impression_viewed — emitted when client confirms ad rendered
  Topic:  ad.impressions.viewed
  Fields: impression_id, user_id, view_ts, viewability_score,
          quartile (0/25/50/75/100% completion)

KEY: both sources carry the same impression_id
     Reconciliation = matching Source 1 vs Source 2
     Discrepancy = served but not viewed, OR viewed but not served
```

**Downstream access patterns:**

| Consumer | Pattern | Latency SLA |
|---|---|---|
| Ad Ops dashboard | Live counts by campaign (GROUP BY) | < 5 minutes |
| Advertiser reporting | Hourly/daily aggregations | < 1 hour |
| Finance billing | Exact reconciled counts, complex SQL | T+1 (daily batch) |
| ML feature store | Online: user ad engagement per request | < 50ms |
| ML feature store | Offline: training datasets | < 6 hours |
| Dispute resolution | Point-in-time exact counts + audit trail | On-demand |

**Latency SLAs:**

```
Ad Ops live dashboard      < 5 minutes   → Pinot or Redis
Advertiser hourly report   < 1 hour      → Snowflake Dynamic Tables
Finance billing            T+1           → Snowflake batch reconciliation
ML online features         < 50ms        → Redis feature store
```

**Data retention: 7 years** (financial records — billing disputes can arrive years later)  
This is significantly longer than viewership (90 days). Financial data has regulatory retention requirements.

**PII:** user_id masked at stream processing layer. Advertiser reports never contain user-level data — aggregated counts only.

**Spikes:** 5x on baseline (AVOD is subset of total subscribers — less extreme than viewership spikes)

---

## Step 2 — Back-of-envelope sizing

```
Peak concurrent AVOD viewers  = 50M subscribers
Ad impression events/sec      = 2M/sec per source × 2 sources = 4M events/sec
Event payload size            = 1 KB (richer than viewership — campaign metadata)
Peak ingestion throughput     = 4M × 1KB = 4 GB/sec
Spike throughput              = 4 GB/sec × 5x = 20 GB/sec

Duplicate overhead (~5%):
  Raw inbound                 = 4 GB/sec × 1.05 = ~4.2 GB/sec
  Post-dedup billable volume  = 4 GB/sec
  Dedup state overhead        = 0.2 GB/sec (size your state store for this)

Historical (7 years):
  4 GB/sec × 86400 × 365 × 7 = ~8.8 PB raw
  After Zstd 5x compression  = ~1.76 PB

OLAP layer (7 days rolling):
  4 GB/sec × 86400 × 7       = ~2.4 TB raw
  After compression           = ~480 GB

Kafka partition sizing:
  4 GB/sec / 10 MB/sec per partition = ~400 partitions
  Round to 500 with headroom
```

**OLAP tool choice — why both Pinot AND Snowflake:**

```
Pinot / Druid → Ad Ops live dashboard
  Sub-second GROUP BY on fresh streaming data
  High query concurrency
  Simple aggregations (COUNT, SUM by campaign_id, region)
  Ingests directly from Kafka

Snowflake → Finance billing + advertiser reporting
  Complex SQL (window functions, multi-way JOINs)
  Governed RBAC (advertiser data isolation)
  T+1 batch reconciliation against DoubleVerify
  Ad-hoc analyst queries

NOT either/or — both serve different consumers
```

---

## Step 3 — Root causes of duplicate impressions

**Must know all five — this drives the entire dedup architecture:**

```
Cause 1: At-least-once Kafka delivery
  Producer retries on network timeout → same message delivered twice
  Fix: enable.idempotence=true on producer

Cause 2: Client SDK retry logic (most common)
  SDK sends impression_viewed event
  Network drops before ACK received
  SDK retries → same impression_id arrives twice from client
  Fix: dedup on impression_id in Flink stateful layer

Cause 3: Two-source fan-in (primary cause of $4M discrepancy)
  Ad-serving system emits impression_served (Source 1)
  Client SDK emits impression_viewed (Source 2)
  Both carry same impression_id
  If pipeline doesn't distinguish sources → one impression counted twice
  Fix: Redis SETNX cross-source atomic dedup

Cause 4: Watermark failures / late event reprocessing
  Late-arriving events reprocessed after window closes
  Same impression_id appears in two window computations
  Fix: deterministic watermark + Silver layer dedup on impression_id

Cause 5: Pipeline replay / backfill after failure
  Flink crashes, replays from Kafka checkpoint offset
  Events already written to sink get written again
  Fix: idempotent writes keyed on impression_id at every sink
```

---

## Step 4 — Yield reconciliation defined

**Precise definition:**

Yield reconciliation = comparing two independent impression counts and explaining every unit of discrepancy before issuing an invoice.

```
Number 1: Impressions SERVED
  Source: ad-serving system (WBD supply side)
  Meaning: how many times WBD servers delivered an ad to a device

Number 2: Impressions VIEWED (verified)
  Source: client SDK + third-party verifier (DoubleVerify / IAS)
  Meaning: how many times a human confirmed the ad rendered on screen

Reconciliation gap = Served − Viewed

Three reconciliation outcomes:

  Case A: SERVED + VIEWED matched on impression_id → VERIFIED ✅
    → Billable impression
    → Count toward advertiser invoice

  Case B: SERVED, no VIEWED → UNVERIFIED_SERVE ⚠️
    → Ad delivered by server but client never confirmed render
    → Causes: ad blocker, page closed, SDK event lost in transit
    → NOT billable by default
    → Route to reconciliation table in Snowflake
    → Finance reviews: if > threshold % → flag for advertiser credit
    → This is how over-reporting happens → advertiser credits

  Case C: VIEWED, no SERVED → ORPHAN_VIEW 🚨
    → Client confirmed view but ad-server has no delivery record
    → Causes: ad-server event lost in Kafka, bot/fraud, clock skew
    → Hold in pending state for watermark duration
    → If no SERVED event after watermark → flag as SUSPICIOUS
    → Route to fraud detection pipeline
    → NOT counted as billable
    → This is how bot traffic inflates impression counts

WBD bills on VERIFIED impressions only (Case A)
```

---

## Step 5 — Deduplication architecture (4 layers)

**Critical rule: acks=ALL for financial pipelines, never acks=1**

```
Viewership pipeline  → acks=1  (approximate counts acceptable)
Ad billing pipeline  → acks=all (financial grade, every impression = revenue)

acks=all config:
  acks                = all
  min.insync.replicas = 2
  enable.idempotence  = true   ← prevents producer-retry duplicates
  transactional.id    = set    ← enables exactly-once producer semantics
```

**Four dedup layers:**

```
Layer 1 — Producer (prevent at source)
  enable.idempotence=true
  acks=all + min.insync.replicas=2
  Eliminates producer-retry duplicates before entering Kafka
  No custom code — Kafka producer config only

Layer 2 — Flink stateful dedup (within-source, streaming)
  KeyedStream on impression_id (per source topic separately)
  ValueState<Boolean> in RocksDB state backend
  TTL on state: 24 hours (impression_ids unique per day)
  Logic:
    seen = state.value()
    if seen is not None → duplicate → route to DLQ topic ❌ never drop silently
    else → first occurrence → emit downstream + state.update(True)
  Why RocksDB: handles millions of state lookups/sec,
               spills to disk, survives task manager restarts

Layer 3 — Redis SETNX (cross-source, atomic)
  Handles two-source fan-in duplicates Flink cannot catch
  (Source 1 and Source 2 are separate Kafka topics,
   separate Flink consumer groups — no shared state)

  Key:   impression:{impression_id}
  Value: {source, ts, campaign_id}
  TTL:   24 hours
  Op:    SETNX (SET if Not eXists) — atomic, single operation

  SETNX returns 1 → first occurrence across both sources → process
  SETNX returns 0 → already seen from other source → route to DLQ

  Why SETNX not GET+SET:
    GET then SET = two operations → race condition between them
    Two Flink writers can both GET (not found), both SET → duplicate survives
    SETNX is atomic — guaranteed exactly-once check at Redis level
    Critical for financial dedup accuracy

Layer 4 — Snowflake MERGE (batch, T+1 billing source of truth)
  Daily Silver layer dedup:
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY impression_id, source
    ORDER BY event_ts
  ) = 1
  Financial source of truth — this is where Snowflake MERGE belongs
  NOT in the streaming layer
```

**Why DLQ and never silent drop:**

```
Silent drop → can never prove to advertiser whether impression
              was duplicate or legitimately lost
              → cannot defend billing number in dispute

DLQ (ad.impressions.duplicates) → full audit trail
  Fields: impression_id, duplicate_ts, source, detection_layer
  Feeds anomaly detection:
    Sudden spike in duplicates = upstream bug in ad-server or SDK
    Alert Ad Ops before it becomes another $4M problem
  Feeds dispute resolution:
    Finance can inspect every rejected impression_id and justify count
```

---

## Step 6 — Full architecture

```
Source 1: Ad-serving system
  acks=all, idempotent producer
  → Kafka topic: ad.impressions.served (250 partitions)

Source 2: Client SDK
  HTTP POST → ALB → Confluent REST Proxy fleet
  acks=all
  → Kafka topic: ad.impressions.viewed (250 partitions)

════════════════════════════════════════════════════
FLINK JOB 1: Dedup + Standardise
════════════════════════════════════════════════════
Input:  ad.impressions.served + ad.impressions.viewed
        (separate consumer groups per topic)

Step 1: PII masking
        hash user_id with deterministic daily salt
        (random salt breaks distinct user counting)

Step 2: Stateful dedup per source
        KeyedStream(impression_id) per topic
        RocksDB ValueState<Boolean> TTL=24h
        Duplicate → ad.impressions.duplicates (DLQ)
        First occurrence → emit to next stage

Step 3: Campaign enrichment
        Broadcast join: impression + campaign metadata
        (campaign_id → advertiser, rate_card, target_CPM, daily_budget)

Output: ad.impressions.deduped

════════════════════════════════════════════════════
FLINK JOB 2: Cross-source reconciliation
════════════════════════════════════════════════════
Input: ad.impressions.deduped

Step 1: Redis SETNX cross-source atomic dedup
        SETNX impression:{impression_id} → deduplicate fan-in

Step 2: Session window matching
        KeyedStream(impression_id)
        Session gap = 2 minutes (SDK has up to 2min to confirm view)
        Watermark = 30 seconds

        Window closes with:
          served + viewed matched  → VERIFIED   → billable stream
          served only              → UNVERIFIED_SERVE → reconciliation table
          viewed only (after gap)  → ORPHAN_VIEW → fraud pipeline

Step 3: Emit reconciled events with status field

════════════════════════════════════════════════════
SINKS (four, each serving a different consumer)
════════════════════════════════════════════════════

Sink 1: S3 Bronze (Iceberg, all raw events)
  Purpose: immutable audit trail, 7-year retention
  All events pre-dedup, append-only
  Financial dispute evidence: "here is every raw event we received"

Sink 2: Redis (two key spaces)
  campaign:pacing:{campaign_id}:{date}
    HASH: impressions_delivered, impressions_budget, spend_usd, pacing_pct
    HINCRBY on every VERIFIED impression
    Ad Ops dashboard: is campaign on track / overpacing / underpacing?
    TTL: 48 hours
  impression:{impression_id}
    SETNX dedup cache, TTL 24h (Layer 3 dedup)

Sink 3: Apache Pinot (real-time OLAP)
  Input: VERIFIED billable stream from Flink Job 2
  Ingests directly from Kafka (Pinot real-time table)
  Ad Ops sub-minute GROUP BY:
    impressions by campaign_id, region, device_type, quartile
  SLA: < 5 minutes ✅

Sink 4: Snowflake (financial source of truth)
  RAW schema   → Snowpipe from S3 Bronze, append-only
  SILVER schema → dbt hourly, dedup + reconciliation status joined
  GOLD schema  → Dynamic Tables 1-hour refresh, aggregated metrics
  BILLING table → daily batch T+1, joined with DoubleVerify counts

════════════════════════════════════════════════════
FRAUD PIPELINE (ORPHAN_VIEW events)
════════════════════════════════════════════════════
  Separate Flink job consumes ORPHAN_VIEW stream
  ML model scores each event: bot probability
  High score → blacklist IP/device_id
  Low score  → route back to reconciliation as late-arrive candidate
```

---

## Step 7 — Snowflake schema and billing reconciliation

### Table structure

```sql
-- RAW: exact copy of all events, both sources, pre-dedup
CREATE TABLE impressions_raw (
    impression_id   VARCHAR         NOT NULL,
    source          VARCHAR         NOT NULL,  -- 'ad_server' | 'sdk'
    campaign_id     VARCHAR,
    ad_id           VARCHAR,
    user_id         VARCHAR,                   -- hashed+salted, not raw PII
    content_id      VARCHAR,
    event_ts        TIMESTAMP_NTZ   NOT NULL,
    served_ts       TIMESTAMP_NTZ,
    view_ts         TIMESTAMP_NTZ,
    quartile        INT,                       -- 0/25/50/75/100
    viewability_pct FLOAT,
    device_type     VARCHAR,
    region          VARCHAR,
    ingestion_ts    TIMESTAMP_NTZ
);

ALTER TABLE impressions_raw CLUSTER BY (event_ts::DATE, region, campaign_id);
```

```sql
-- SILVER: deduped, reconciliation status, PII-safe
CREATE OR REPLACE DYNAMIC TABLE impressions_silver
    TARGET_LAG = '1 hour'
    WAREHOUSE  = PROD_INGEST_WH
AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY impression_id, source
            ORDER BY event_ts
        ) AS rn
    FROM impressions_raw
)
WHERE rn = 1;
```

```sql
-- GOLD: aggregated campaign metrics for advertiser reporting
CREATE OR REPLACE DYNAMIC TABLE campaign_metrics_gold
    TARGET_LAG = '1 hour'
    WAREHOUSE  = PROD_ANALYTICS_WH
AS
SELECT
    campaign_id,
    event_ts::DATE                                              AS report_date,
    region,
    device_type,
    COUNT(CASE WHEN status = 'VERIFIED' THEN 1 END)            AS verified_impressions,
    COUNT(CASE WHEN status = 'UNVERIFIED_SERVE' THEN 1 END)    AS unverified_impressions,
    COUNT(CASE WHEN quartile = 100 THEN 1 END)                 AS completions,
    ROUND(COUNT(CASE WHEN quartile = 100 THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN status = 'VERIFIED' THEN 1 END), 0), 2)
                                                               AS completion_rate_pct,
    SUM(cpm_rate / 1000.0)                                     AS gross_revenue_usd
FROM impressions_silver
WHERE event_ts >= DATEADD(day, -7, CURRENT_TIMESTAMP)
GROUP BY campaign_id, report_date, region, device_type;
```

```sql
-- BILLING: T+1 reconciliation table — financial source of truth
CREATE OR REPLACE TABLE billing_reconciliation (
    campaign_id             VARCHAR,
    billing_date            DATE,
    wbd_verified_count      INT,        -- WBD pipeline count
    dv_verified_count       INT,        -- DoubleVerify third-party count
    discrepancy_count       INT,        -- wbd - dv
    discrepancy_pct         FLOAT,      -- abs(discrepancy) / wbd * 100
    reconciliation_status   VARCHAR,    -- AUTO_APPROVED | FLAGGED_FOR_REVIEW
    invoice_amount_usd      FLOAT,
    created_ts              TIMESTAMP_NTZ
);

-- Auto-approve if discrepancy ≤ 10%, flag for finance review if > 10%
-- This is the gate that prevents the $4M problem:
--   Over-report caught before invoice → no advertiser credit needed
--   Under-report caught before invoice → no revenue left on table
```

---

## Step 8 — Flink recovery and exactly-once semantics

### What happens when a task manager crashes mid-window

```
Scenario:
  Last checkpoint: t=0
  Crash: t=8min
  In-flight: 500K events in session windows

Recovery sequence:

Step 1: Flink restores from last checkpoint (t=0)
        Restores: Kafka consumer offsets (per partition, per topic)
                  RocksDB operator state (dedup ValueState, window state)
        NOT timestamp-based — offset-based (timestamps are unreliable)

Step 2: Kafka replays 8 minutes of events from checkpointed offset
        ~500K events re-enter the pipeline

Step 3: RocksDB dedup state (TTL=24h) catches within-source duplicates
        Same impression_id seen on replay → second occurrence dropped to DLQ
        State was checkpointed at t=0 → events since t=0 reprocessed safely

Step 4: Session windows rebuild from replayed events
        Window state lost between t=0 and t=8min
        Sessions re-open from replayed events
        served + viewed events re-matched correctly

Step 5: Redis SETNX handles cross-source duplicates on replay
        If impression already written to Redis pre-crash:
          SETNX returns 0 → duplicate → dropped, not double-counted
        If not yet written (within replay window):
          SETNX returns 1 → first occurrence → process normally

Step 6: Idempotent sinks absorb replay
        S3 Bronze:   Parquet file write idempotent (same path = overwrite)
        Snowflake:   Snowpipe + MERGE on impression_id deduplicates
        Redis:       SETNX atomic, replay-safe
        Pinot:       idempotent on impression_id primary key

Result: zero impression loss, zero double-counting, billing correct ✅
```

**Critical nuance — session window state loss:**

```
State at t=0 checkpoint:
  impression "abc-123": served event received, waiting for viewed event

Crash at t=4min:
  viewed event for "abc-123" arrived at t=2min
  written to sink → VERIFIED before crash ✅

  OR

  viewed event NOT yet arrived
  session was still open at crash time
  session state lost → on recovery, session re-opens
  if viewed event is in Kafka replay window → re-matched ✅
  if viewed event arrived AFTER Kafka retention (unlikely) → Case B ⚠️

This is why checkpoint interval matters:
  Checkpoint every 30sec → max 30sec of replay → minimal state loss risk
  Checkpoint every 8min  → 8min of potential session state to rebuild
  Recommendation: checkpoint interval ≤ 60 seconds for financial pipelines
```

---

## Step 9 — Advertiser dispute resolution

**Scenario:** Advertiser claims WBD reported 10M impressions. DoubleVerify shows 8.7M. That is a 13% discrepancy. They want a credit.

### Audit trail query

```sql
-- Step 1: Pull WBD count vs DoubleVerify count for disputed campaign
SELECT
    campaign_id,
    billing_date,
    wbd_verified_count,
    dv_verified_count,
    discrepancy_count,
    discrepancy_pct,
    reconciliation_status
FROM billing_reconciliation
WHERE campaign_id = 'disputed-campaign-id'
  AND billing_date BETWEEN '2024-10-01' AND '2024-10-31';

-- Step 2: Break down WBD count by reconciliation status
SELECT
    status,
    COUNT(*) AS impression_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM impressions_silver
WHERE campaign_id = 'disputed-campaign-id'
  AND event_ts::DATE BETWEEN '2024-10-01' AND '2024-10-31'
GROUP BY status;
-- Shows: VERIFIED / UNVERIFIED_SERVE / ORPHAN_VIEW breakdown

-- Step 3: Inspect raw events in Bronze for complete audit trail
SELECT impression_id, source, event_ts, ingestion_ts, status
FROM impressions_raw
WHERE campaign_id = 'disputed-campaign-id'
  AND event_ts::DATE = '2024-10-15'  -- spot check specific day
ORDER BY impression_id, source, event_ts;

-- Step 4: Check DLQ for duplicates detected for this campaign
SELECT impression_id, duplicate_ts, source, detection_layer
FROM impressions_dlq
WHERE campaign_id = 'disputed-campaign-id'
ORDER BY duplicate_ts;
```

### Three most likely causes of a 13% discrepancy

```
Cause 1: UNVERIFIED_SERVE counted by WBD, not by DoubleVerify (~5–8%)
  WBD ad-server recorded delivery (served event) ✅
  Client device never rendered ad (no viewed event) ❌
  WBD counted it; DoubleVerify did not
  Resolution: review UNVERIFIED_SERVE % for this campaign
              if > industry standard (5%) → issue partial credit
              Query: SELECT COUNT(*) WHERE status = 'UNVERIFIED_SERVE'

Cause 2: Viewability threshold mismatch (~3–5%)
  DoubleVerify requires 50% of ad pixels visible for 2 continuous seconds
  WBD counts impression on any render confirmation (quartile > 0)
  Below-the-fold ads that technically rendered but were never seen
  Resolution: filter WBD count to quartile ≥ 25 (industry MRC standard)
              recompute verified_impressions with viewability filter

Cause 3: Timezone / date boundary discrepancy (~1–2%)
  WBD uses event_ts (when impression occurred)
  DoubleVerify uses their ingestion_ts (when they received the event)
  Events near midnight cross date boundaries differently
  Resolution: rerun WBD count using same date definition as DoubleVerify
              typically UTC vs local timezone issue

What to show the advertiser:
  1. Raw event count from Bronze (immutable proof of delivery)
  2. Status breakdown: VERIFIED / UNVERIFIED_SERVE / ORPHAN_VIEW
  3. DLQ count: duplicates correctly excluded from billing
  4. Viewability-filtered recount if Cause 2 is the driver
  5. Proposed credit: only for UNVERIFIED_SERVE above industry threshold
                      not for the full 13% gap
```

---

## Key decisions reference card

| Decision | Correct answer | Why |
|---|---|---|
| Producer durability | acks=all + idempotent producer | Financial grade — every impression = revenue |
| Dedup layer 1 | Kafka idempotent producer | Eliminates retry duplicates at source |
| Dedup layer 2 | Flink RocksDB stateful (per source) | Within-source streaming dedup at millions/sec |
| Dedup layer 3 | Redis SETNX (cross-source atomic) | Handles two-source fan-in race condition |
| Dedup layer 4 | Snowflake MERGE (batch, T+1) | Financial source of truth, not streaming dedup |
| Duplicate routing | DLQ topic, never silent drop | Audit trail for advertiser disputes |
| Reconciliation window | Session window, 2-min gap | Served + viewed events can be minutes apart |
| Real-time OLAP | Pinot (Ad Ops) | Sub-second GROUP BY on fresh streaming data |
| Analytical layer | Snowflake (Finance + Advertisers) | Complex SQL, governed RBAC, T+1 reconciliation |
| Checkpoint interval | ≤ 60 seconds | Minimise session window state loss on recovery |
| Billing gate | Reconcile vs DoubleVerify before invoice | Catches over/under-report before it becomes a credit |

---

## Critical concepts to know cold

### Exactly-once semantics stack

```
Producer:  enable.idempotence=true + transactional.id
           → exactly-once from producer to Kafka broker

Flink:     checkpoint interval + RocksDB state backend
           → exactly-once within Flink operators
           → restore from checkpoint on failure, replay from Kafka offset

Sinks:     idempotent writes keyed on impression_id
           Redis SETNX, Snowflake MERGE, S3 Parquet overwrite
           → exactly-once end-to-end despite at-least-once delivery

Result:    financial-grade pipeline — no loss, no double-count
```

### Redis SETNX vs GET+SET

```
GET + SET (wrong):
  t=0  Flink writer A: GET impression:abc → null (not found)
  t=0  Flink writer B: GET impression:abc → null (not found)  ← race condition
  t=1  Flink writer A: SET impression:abc → OK
  t=1  Flink writer B: SET impression:abc → OK  ← duplicate survives

SETNX (correct):
  t=0  Flink writer A: SETNX impression:abc → 1 (set, was empty)  → process
  t=0  Flink writer B: SETNX impression:abc → 0 (not set, existed) → DLQ
  Atomic at Redis level — no race condition possible
```

### Session window vs sliding window for reconciliation

```
Sliding window (wrong for reconciliation):
  impression_served arrives at t=0  → window 1 (0–30s)
  impression_viewed arrives at t=45s → window 2 (15–45s)
  Different windows → never matched → every impression = Case B

Session window (correct):
  impression_served arrives at t=0  → session opens for impression_id
  impression_viewed arrives at t=55s → within 2-min gap → same session
  Matched → VERIFIED ✅
  Session closes when no event arrives for 2 minutes
```

### Viewership vs ad billing — key differences

| Dimension | Viewership (Round 1) | Ad billing (Round 3) |
|---|---|---|
| Producer acks | acks=1 (approximate ok) | acks=all (financial grade) |
| Dedup | Flink stateful only | 4 layers including Redis SETNX |
| Lost events | Acceptable | Every lost impression = revenue |
| Retention | 90 days | 7 years (financial records) |
| Window type | Sliding (live counts) | Session (cross-source matching) |
| Duplicate handling | Drop acceptable | DLQ mandatory (audit trail) |
| Accuracy | Approximate by design | Exactly-once end-to-end |
| Serving | Redis only | Redis + Pinot + Snowflake |
