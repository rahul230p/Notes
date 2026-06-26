# Mock Round 1 — Real-time viewership pipeline (Max)
## Canonical reference answers

**Company:** Warner Bros. Discovery  
**Role:** Senior Data Engineer  
**Round:** Software Architecture / System Design (Scale, Global)  
**Principles:** Empower Storytelling · Dream It & Own It

---

## Problem statement

Max streams to ~100M subscribers globally. During live NBA games or HBO premieres, viewership spikes 10x normal traffic. Design a real-time viewership pipeline delivering live viewer counts, drop-off rates, and buffering metrics with **≤ 30 seconds end-to-end latency**.

---

## Step 1 — Requirements

### Functional
- Real-time OLAP on viewership events
- End users: content team, product team
- Three explicit metrics: **live viewer counts, drop-off rates, buffering metrics**
- Real-time serving layer with dashboard
- Historical analytical layer for 7-day lookback

### Non-functional

| Dimension | Value | Reasoning |
|---|---|---|
| End-to-end SLA | 30 seconds | Product requirement |
| TAU | 100M subscribers | Capacity ceiling, not operational steady state |
| Peak concurrent | 20–30M (20–30% of TAU) | Not all subscribers watch simultaneously |
| Spike multiplier | 10x on peak | NBA / HBO premiere scenario |
| PII | user_id, device_id | GDPR (EU), LGPD (Brazil), CCPA (CA) |
| Data isolation | Required | EU data must not leave EU infrastructure |

**Why not design for 100M concurrent:** Over-provisioning for full TAU is 3x–5x wasteful. WBD is actively deleveraging. Design for realistic peak with elastic auto-scaling headroom to absorb TAU bursts.

---

## Step 2 — Back-of-envelope sizing

```
Peak concurrent viewers     = 25M  (25% of 100M TAU)
Events per user per hour    = 50   (one heartbeat every ~72 seconds)
Baseline events/hour        = 50 × 25M = 1.25B / hour
Spike events/hour           = 1.25B × 10 = 12.5B / hour
Spike events/sec            = ~3.5M events / sec

Event payload size          = 0.5 KB
Peak ingestion throughput   = 3.5M × 0.5 KB = ~1.75 GB / sec

Kafka partition sizing      = throughput / (10 MB/sec per partition)
                            = 1,750 MB/sec / 10 = ~175 partitions
                            → round to 200 partitions for headroom
```

---

## Step 3 — Event payload schema

```json
{
  "event_id":     "uuid-v4",
  "event_type":   "play | pause | buffer | stop",
  "user_id":      "string — PII, masked before any downstream write",
  "session_id":   "uuid — required to stitch drop-off funnel per session",
  "content_id":   "string",
  "event_ts":     "epoch_ms — event time, not ingestion time",
  "buffering_ms": "int — required for buffering metrics requirement",
  "device_type":  "mobile | desktop | tv | tablet",
  "region":       "NA | EU | APAC | LATAM"
}
```

**Why session_id is mandatory:** Without it you cannot stitch events into a session to compute where users dropped off. Event_id alone is per-event, not per-session.

**Why buffering_ms is mandatory:** It was an explicit requirement. If it is not in the event schema it cannot be measured downstream.

**PII handling:** user_id and device_id are PII in GDPR, LGPD, and CCPA jurisdictions. Mask via hash + deterministic salt in the Flink layer before any write to Redis or S3. Salt must be deterministic (daily rotating secret key stored in AWS Secrets Manager) — a random salt per event breaks distinct user counting because the same user hashes differently on each event.

---

## Step 4 — Architecture

```
Mobile / Web SDK
    ↓  buffer events locally, HTTP POST every 5s (reduces proxy connections)
AWS Application Load Balancer
    ↓  round-robin, health checks pull failed instances within seconds
Confluent REST Proxy fleet (stateless, auto-scaling on EC2 ASG)
    ↓  Kafka producer inside proxy:
       acks=1, linger.ms=10, batch.size=65536, compression.type=lz4
MSK (Kafka) — 200 partitions, replication factor=3, 2-day retention
    │
    ├─── Flink Job A: real-time aggregation path
    │       Consumer group: flink-realtime-cg
    │       ↓
    │    PII masking operator
    │    (hash user_id with deterministic daily salt)
    │       ↓
    │    SlidingWindow(size=1min, slide=10sec, watermark=15sec)
    │       ↓
    │    Aggregations:
    │      COUNT DISTINCT active user_id  → live viewer count
    │      COUNT WHERE event_type=buffer  → buffering metric
    │      COUNT WHERE event_type=stop    → drop-off signal
    │       ↓
    │    Redis Cluster (sharded by content_id)
    │       ↓
    │    Internal REST API → Dashboard    SLA: < 30 sec ✅
    │
    └─── Flink Job B: historical enrichment path
            Consumer group: flink-historical-cg
            ↓
         Enrich + serialize to Parquet
            ↓
         S3 Bronze layer (raw, append-only)
            ↓ Snowpipe auto-ingest (continuous micro-batch)
         Snowflake RAW schema
            ↓ dbt incremental models / Dynamic Tables
         Snowflake SILVER schema (deduped, typed, PII-safe)
            ↓
         Snowflake GOLD schema (aggregated marts, 1-hour refresh)
            ↓
         Looker / Tableau — 7-day drop-off, buffering analysis
```

---

## Step 5 — Layer deep-dives

### Ingestion — REST proxy + MSK

**Why REST proxy exists:**
Client devices (phones, smart TVs) cannot speak native Kafka binary protocol. The REST proxy is a stateless HTTP-to-Kafka bridge. Being stateless means any instance can handle any request — the ALB can route freely with no sticky sessions.

**SPOF mitigation:**
```
SDK local buffer (last line of defence — retries if ALB returns 503)
      ↓
AWS ALB (health checks, auto-removes unhealthy proxy instances)
      ↓
Confluent REST Proxy fleet (EC2 ASG, scales on CPU/request rate)
      ↓
MSK (Kafka) — ISR replication absorbs broker failures
```

**ACK=1 tradeoff:**
```
acks=0   → fire and forget, zero guarantee        → never acceptable
acks=1   → leader ACK, async ISR replication      → viewership events ✅
acks=all → wait for all ISR replicas to confirm   → billing, financial data

Failure window with acks=1:
  t=0  producer writes to leader, receives ACK
  t=1  leader crashes before replicating to ISR followers
  t=2  new leader elected from ISR — message is gone

This is acceptable because:
  - Viewership counts are approximate by design
  - Losing 0.1% of events during broker failover is not a business problem
  - Exact historical counts live in Snowflake after deduplication
```

**Producer batching (inside REST proxy — no custom code needed):**
```
linger.ms   = 10        wait 10ms to accumulate events before flushing
batch.size  = 65536     flush if buffer hits 64KB before linger expires
compression = lz4       compress batch — best speed/ratio for event streams

Effect: collapses millions of individual events into thousands of
        compressed network round trips per second
```

**SDK-side batching vs producer-side batching:**
```
SDK (client)           → HTTP POST every 5s     coarse, reduces proxy connections
Producer (proxy)       → flush every linger.ms  fine-grained, reduces broker I/O
Both layers complement each other independently
```

### Stream processing — Flink

**Window choice — sliding window:**
```
Tumbling window  → fixed non-overlapping buckets  → billing, hourly aggregations
Sliding window   → overlapping, continuous view   → live viewer counts ✅
Session window   → gap-based grouping             → user session stitching

Sliding(size=1min, slide=10sec):
  Every 10 seconds Flink emits a fresh count covering the last 60 seconds
  Viewer count updates 6 times per minute — well within 30-sec SLA
```

**SLA math — must close before finalising window params:**
```
watermark        15 sec   (wait for late-arriving events)
+ slide interval 10 sec   (how often window emits)
+ Flink proc      3 sec   (aggregation + serialisation)
+ Redis write     2 sec   (network + HSET)
─────────────────────────
Total            30 sec   ✅ exactly at SLA boundary
```

**Watermark rule:** watermark should be ≤ 15% of window size  
→ Window = 1 min, watermark = 15 sec (25%) — slightly aggressive but acceptable at this latency budget  
→ Events arriving > 15 sec late are dropped from real-time path; they are captured in the S3/Snowflake historical path

**Active viewer definition — event-driven, not purely time-driven:**
```
event_type = play    → active ✅
event_type = buffer  → active ✅ (still consuming stream)
event_type = pause   → active for current 10-sec slide only
event_type = stop    → excluded from active count immediately

Eviction mechanism:
  A user who pauses and sends no further event within 10 seconds
  falls out of the next window computation naturally.
  No separate KeyedProcessFunction timer needed.
  The sliding window expiry is the eviction mechanism.

Halftime scenario (40% of users pause simultaneously):
  Within one slide interval (10 sec) paused non-returning users
  drop from the active count.
  Content team sees accurate signal within 10 seconds of the pause event.
```

**Late data strategy:**
```
Real-time path  → watermark 15 sec, late events dropped, approximate counts
Historical path → all events land in S3 regardless of arrival time
                  Snowflake dedup on event_ts gives exact historical counts
This is the Lambda architecture tradeoff — own it explicitly.
```

### Storage — Redis Cluster

```
Data structure:   HASH  key=content_id  field=metric  value=count
                  HSET viewership:tt-show-123 active_viewers 1847293

Sharding:         shard by content_id — ensures one content piece
                  always hits the same shard, no cross-shard ops needed

TTL:              set TTL on all keys to prevent unbounded memory growth
                  TTL = window size + buffer (e.g. 2 minutes)

Eviction policy:  maxmemory-policy allkeys-lru
                  Risk: memory pressure > 80% → Redis silently evicts keys
                        → dashboard reads zero (not pipeline failure)
                  Mitigation: Datadog alert at 80% memory, pre-scale
                              before known spike events (NBA schedule, releases)

Cluster sizing:   monitor key count × avg key size for capacity planning
                  scale horizontally before major live events
```

### Analytical layer — Snowflake

**Ingestion:**
```
S3 Bronze (Parquet) → Snowpipe (continuous auto-ingest) → Snowflake RAW
Snowpipe triggers on S3 event notifications — no polling, no scheduling
Latency: typically 1–3 minutes from S3 landing to Snowflake availability
```

**Base table:**
```sql
CREATE TABLE viewership_events_raw (
    event_id        VARCHAR         NOT NULL,
    user_id         VARCHAR,                    -- hashed, not raw PII
    session_id      VARCHAR,
    content_id      VARCHAR,
    event_type      VARCHAR,
    event_ts        TIMESTAMP_NTZ   NOT NULL,   -- event time, not ingestion
    buffering_ms    INT,
    device_type     VARCHAR,
    region          VARCHAR,
    ingestion_ts    TIMESTAMP_NTZ               -- when Snowpipe loaded it
);

-- Snowflake micro-partitioning is automatic.
-- CLUSTER BY controls which columns guide micro-partition pruning.
-- NOT a partition key in the Hive/BigQuery sense.
ALTER TABLE viewership_events_raw
    CLUSTER BY (event_ts::DATE, region);
```

**Deduplication — Silver layer:**
```sql
-- Kafka acks=1 + Snowpipe = at-least-once delivery
-- Same event_id can arrive twice. Deduplicate in Silver.
CREATE OR REPLACE VIEW viewership_events_silver AS
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY event_id
            ORDER BY event_ts
        ) AS rn
    FROM viewership_events_raw
)
WHERE rn = 1;
```

**Drop-off Dynamic Table — Gold layer:**
```sql
CREATE OR REPLACE DYNAMIC TABLE content_dropoff_metrics
    TARGET_LAG = '1 hour'
    WAREHOUSE  = PROD_ANALYTICS_WH
AS
SELECT
    content_id,
    event_ts::DATE                                                        AS event_date,
    COUNT(DISTINCT CASE WHEN event_type = 'play'   THEN user_id END)     AS viewers_started,
    COUNT(DISTINCT CASE WHEN event_type = 'stop'   THEN user_id END)     AS viewers_stopped,
    ROUND(
        COUNT(DISTINCT CASE WHEN event_type = 'stop'  THEN user_id END)
        * 100.0 /
        NULLIF(COUNT(DISTINCT CASE WHEN event_type = 'play' THEN user_id END), 0)
    , 2)                                                                  AS dropoff_rate_pct,
    AVG(buffering_ms)                                                     AS avg_buffering_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY buffering_ms)           AS p95_buffering_ms
FROM viewership_events_silver
WHERE event_ts >= DATEADD(day, -7, CURRENT_TIMESTAMP)
GROUP BY content_id, event_ts::DATE;
```

**Latency contract:**
```
Real-time viewer counts   → Redis + REST API       < 30 seconds
Near-real-time ingestion  → Snowpipe               1–3 minutes
Historical drop-off       → Dynamic Table refresh  < 1 hour
```

---

## Step 6 — Incident response playbook

**Scenario:** 11pm. HBO premiere. 25M concurrent. Active viewer count flatlines to zero for 3 minutes.

```
Severity: P1 — content team is making live programming decisions on bad data

Step 1 — Check Kafka (Datadog)
  Metric: consumer_lag on flink-realtime-cg
  Lag spiking upward  → Flink cannot keep up → scale Flink task managers
  Lag flat near zero  → Flink is consuming fine → problem is downstream

Step 2 — Check Flink (Flink Web UI)
  Metric 1: backpressure indicator on window operator
    High backpressure → scale task managers (add parallelism)
  Metric 2: checkpoint duration
    Normal: 3–5 sec
    Elevated: 30–45 sec → RocksDB state backend overwhelmed
    Fix: increase managed memory, or switch to heap state backend

Step 3 — Check Redis (Datadog)
  Metric 1: memory_usage > 80%
    Most likely cause of flatline at spike events
    Redis evicting active viewer keys under memory pressure
    Fix: scale Redis cluster, add shards, or increase maxmemory
  Metric 2: CPU throttling
    Too many HINCRBY operations → shard by content_id more aggressively
  Metric 3: connected_clients
    Connection pool exhaustion from REST API → increase pool size

Step 4 — Isolate by metric pattern (Dashboard API)
  All metrics zero                → Redis down / network partition API→Redis
  Only viewer count zero          → Flink Job A failed, Job B still running
  Historical stale, realtime fine → Snowflake Dynamic Table refresh failed
  All metrics stale uniformly     → Kafka consumer lag — check Step 1

Remediation path (most likely — Redis memory eviction):
  1. Scale Redis cluster (add shards)
  2. Flink re-emits current window aggregation on next slide (10 sec)
  3. Dashboard recovers within 30 sec of Redis scaling
  4. Post-incident: set Datadog alert at 70% Redis memory (not 80%)
                    pre-scale before all NBA/HBO premiere events
```

---

## Key tradeoffs reference card

| Decision | What you gain | What you give up | Why acceptable |
|---|---|---|---|
| acks=1 | Throughput | Durability on leader crash | Viewership is approximate |
| Sliding vs tumbling | Continuous fresh counts | Higher state size in Flink | Required by 30-sec SLA |
| 15-sec watermark | Late event tolerance | 15 sec of SLA budget | Remaining 15 sec still closes SLA |
| Drop late events | SLA compliance | Exact real-time accuracy | Exact counts in Snowflake |
| Redis for serving | Sub-ms KV lookup | Memory eviction risk | Pre-scale before spikes |
| 1-hour DT refresh | Simple ops | Historical data 1hr stale | Acceptable for strategic analysis |
| Deterministic salt | Consistent distinct counts | Salt must be managed securely | Random salt breaks dedup |

---

## WBD business framing — say this in the interview

> "I'm choosing a 10-second slide interval so the content team gets fresh viewer counts during live events — that signal drives real-time programming decisions: ad slot timing, push notification triggers, and server capacity escalation. The 1-hour Snowflake refresh serves a different consumer — a content exec reviewing premiere performance the next morning. Two consumers, two different latency contracts, one pipeline."
