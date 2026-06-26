# Data Pipeline Decision Tree — Batch & Real-Time

> **How to use:** Start at Step 1. Answer each question in sequence. By Step 4 you have a complete stack recommendation with tradeoff notes.

---

## Step 1 — What is your end-to-end SLA?

```
What latency does the consumer need?
│
├── < 30 seconds          → REAL-TIME path   (Section A)
├── 30 seconds – 5 min    → NEAR-REAL-TIME   (Section B)
├── 5 min – 1 hour        → MICRO-BATCH      (Section C)
└── > 1 hour              → BATCH path       (Section D)
```

---

## Section A — Real-Time (SLA < 30 seconds)

### A1 — Ingestion layer

```
Peak throughput?
│
├── > 1M events/sec
│     └── REST proxy + MSK (Kafka)
│           Why: Kafka partitions scale horizontally.
│                REST proxy decouples clients from broker.
│                SDK-level local buffer handles proxy restarts.
│                MSK auto-scales; no manual shard splitting.
│
├── 100K – 1M events/sec
│     └── Kinesis Data Streams  OR  MSK
│           Kinesis: simpler ops, AWS-native IAM, no broker mgmt.
│           MSK: better if you need >5 consumers or long retention.
│           Rule of thumb: Kinesis if team lacks Kafka expertise.
│
└── < 100K events/sec
      └── Kinesis  OR  SDK → Kafka direct
            Kinesis: serverless, zero ops, pay-per-shard.
            SDK direct: only if ultra-low latency critical (<5ms).
```

### A2 — Stream processing layer

```
Processing complexity?
│
├── Stateful (sessions, dedup, joins, windows)
│     └── Apache Flink (MSK managed or EMR)
│           Window types:
│             Tumbling  → fixed non-overlapping buckets (billing periods)
│             Sliding   → overlapping windows (active viewer counts)
│             Session   → gap-based grouping (user sessions)
│           SLA math: watermark + slide interval + write latency < SLA
│           Watermark rule: ≤ 15% of window size for clean results.
│           PII: hash+deterministic salt in Flink before any write.
│
├── Micro-batch acceptable (1–5 min latency ok)
│     └── Spark Structured Streaming (EMR or Databricks)
│           Better for teams already on Spark.
│           Easier backfill logic than Flink.
│           Not suitable for SLA < 60 seconds.
│
└── Simple filter / transform / enrich (no state)
      └── Kafka Streams  OR  Kinesis Data Analytics (Flink managed)
            Kafka Streams: no separate cluster, runs in app process.
            KDA: fully managed Flink, good for AWS-native stacks.
```

### A3 — Storage layer

```
Query pattern on real-time data?
│
├── Key-value lookup (live counts, flags, user state)
│     └── Redis Cluster
│           Data structures: HASH (content_id → count), ZSET (rankings)
│           Eviction: set TTL on keys; use maxmemory-policy allkeys-lru
│           Failure mode: memory pressure evicts keys → counts drop to zero
│           Fix: monitor memory > 80%, pre-scale or shard by content_id
│           Cluster: shard by content_id for even key distribution
│
├── Sub-second OLAP on fresh data (slice/dice, GROUP BY)
│     └── Apache Pinot  OR  Apache Druid
│           Pinot: real-time ingest from Kafka, star-tree index, 
│                  best for immutable append-only event data
│           Druid: stronger for roll-ups and approximate queries (HLL)
│           Both: columnar storage, pre-aggregated segments
│
└── Durable event store for replay + downstream consumption
      └── Kafka (MSK) with tiered storage (S3-backed)
            Retention: days to weeks without disk cost explosion
            Use case: multiple downstream consumers at different offsets
```

### A4 — Serving layer

```
Who is consuming and how?
│
├── Dashboard / product team (live metrics)
│     └── Redis + REST API (internal)
│           Redis GET/HGETALL per content_id
│           Cache-aside pattern; API owns TTL refresh logic
│           Latency target: < 10ms p99
│
├── Ad-tech / analytics team (slice by dimension)
│     └── Pinot / Druid query API
│           SQL interface; sub-second on billions of rows
│           Pre-aggregate at ingest time for common GROUP BYs
│
└── Data science / ML feature store
      └── Redis (online features)  +  S3/Iceberg (offline features)
            Online: low-latency model serving
            Offline: training data, point-in-time correct joins
```

---

## Section B — Near-Real-Time (SLA 30 sec – 5 min)

### B1 — Ingestion layer

```
Source type?
│
├── Event stream (clickstream, telemetry, logs)
│     └── MSK (Kafka)  OR  Kinesis Data Streams
│
├── CDC (database changes)
│     └── Debezium → MSK  OR  AWS DMS → Kinesis
│           Debezium: battle-tested, rich connector ecosystem
│           DMS: simpler for RDS/Aurora sources in AWS
│
└── File / API pull
      └── S3 event notification → SQS → Lambda  OR  Airbyte
```

### B2 — Processing layer

```
└── Spark Structured Streaming (micro-batch, 1–5 min triggers)
      OR
    Flink with larger watermarks (1–2 min)

    Choose Spark when:
      - Team is Spark-native
      - Backfill and batch reprocessing needed on same codebase
      - Complex ML feature engineering in pipeline

    Choose Flink when:
      - True event-time processing required
      - Sub-minute latency still matters
      - Stateful session stitching needed
```

### B3 — Storage layer

```
└── Snowflake (via Snowpipe auto-ingest)
      OR
    Iceberg on S3 (via Flink/Spark write)

    Snowflake: governed SQL, RBAC, easy BI integration
               Snowpipe: continuous micro-batch from S3
               Dynamic Tables: incremental refresh, no dbt job needed
    
    Iceberg:   open format, multi-engine (Spark + Trino + Athena)
               ACID transactions, time-travel, schema evolution
               Better when avoiding Snowflake vendor lock-in
```

### B4 — Serving layer

```
└── Snowflake Dynamic Tables (refresh: 1–15 min)
      OR
    Druid / Pinot (if sub-minute query latency needed)
      OR
    dbt incremental model on Snowflake (scheduled via Airflow)
```

---

## Section C — Micro-Batch (SLA 5 min – 1 hour)

### C1 — Ingestion layer

```
└── Kinesis Firehose → S3   (simplest, serverless, no consumer code)
      OR
    MSK → Spark Streaming → S3
      OR
    AWS Glue Streaming
```

### C2 — Processing layer

```
└── Spark on EMR  OR  AWS Glue ETL
      OR
    dbt + Snowpipe (if transformation is SQL-only)

    Glue: serverless, good for sporadic workloads, pay-per-run
    Spark EMR: better for sustained high-volume, reuse cluster
```

### C3 — Storage layer

```
└── Snowflake (primary DWH)
      Partition strategy: CLUSTER BY (event_date, region, content_id)
      Note: Snowflake uses micro-partitioning — no explicit partition key
      
      OR
    
    Iceberg on S3 (open lakehouse)
      Partition: by event_date (pruning) + region (compliance)
      Format: Parquet with Zstandard compression
```

### C4 — Serving layer

```
└── Snowflake + BI tool (Looker, Tableau, PowerBI)
      Dynamic Tables for pre-aggregated metrics
      Materialized views for common dashboard queries
```

---

## Section D — Batch (SLA > 1 hour)

### D1 — Ingestion layer

```
Source type?
│
├── Files (CSV, Parquet, JSON)
│     └── S3 → Glue Crawler → Glue ETL
│
├── Database (Postgres, MySQL, Oracle)
│     └── AWS DMS  OR  Airbyte  OR  Sqoop (legacy Hadoop)
│
├── API / SaaS (Salesforce, Marketo, etc.)
│     └── Fivetran  OR  Airbyte  OR  custom Lambda
│
└── Event stream (historical replay)
      └── MSK → S3 via Firehose (buffer first, then batch process)
```

### D2 — Processing layer

```
Volume?
│
├── > 10 TB
│     └── Spark on EMR  OR  Databricks
│           Use columnar formats (Parquet/ORC) throughout
│           Partition output by date before writing
│           Avoid small files: coalesce/repartition before write
│
├── 100 GB – 10 TB
│     └── Spark on EMR  OR  AWS Glue  OR  dbt on Snowflake
│
└── < 100 GB
      └── dbt (SQL-only transformations in Snowflake)
            Simplest path; no cluster management
            Models: staging → intermediate → marts
```

### D3 — Storage layer

```
Architecture choice?
│
├── Open lakehouse (avoid vendor lock-in, multi-engine)
│     └── Bronze/Silver/Gold on S3 with Iceberg
│           Bronze: raw ingest, schema-on-read
│           Silver: deduplicated, typed, PII masked
│           Gold: aggregated marts, business-ready
│           Engine: Spark (write) + Athena/Trino (query)
│
└── Cloud DWH (governed, SQL-first, BI-ready)
      └── Snowflake
            Layers: RAW → STAGING → MARTS schemas
            Dedup: QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_ts) = 1
            Clustering: CLUSTER BY (event_date, region)
            Refresh: Dynamic Tables or dbt scheduled jobs
```

### D4 — Serving layer

```
Consumer type?
│
├── BI / dashboards (Looker, Tableau, PowerBI)
│     └── Snowflake gold layer  OR  Redshift
│           Semantic layer: dbt metrics, Looker LookML
│
├── Data science / ML training
│     └── S3 (Parquet) + SageMaker  OR  Databricks Feature Store
│           Point-in-time correct joins for training sets
│           Versioned datasets via Iceberg snapshots
│
└── Operational reporting (internal apps, APIs)
      └── RDS (Postgres) or DynamoDB — push aggregated results
            Refresh via scheduled Glue/dbt job
            Keep analytical queries off operational DB
```

---

## Quick-Reference Cheat Sheet

| Dimension | < 30s (Real-Time) | 30s–5m (Near-RT) | 5m–1h (Micro-batch) | > 1h (Batch) |
|---|---|---|---|---|
| **Ingestion** | MSK + REST proxy | MSK / Kinesis | Firehose → S3 | DMS / Airbyte / S3 |
| **Processing** | Flink (stateful) | Spark Streaming / Flink | Glue / Spark | Spark EMR / dbt |
| **Storage** | Redis + Kafka | Snowflake / Iceberg | Snowflake | Iceberg / Snowflake |
| **Serving** | Redis REST API | Snowflake DT / Druid | Snowflake + BI | Snowflake + BI / S3 |
| **WBD example** | Viewer counts (Max) | Ad impression reports | Content metadata | 7-day drop-off |

---

## Key Decision Rules to Memorise

**SLA math (real-time):**
```
watermark + slide_interval + flink_processing + redis_write < end-to-end SLA
15s        + 10s          + 3s               + 2s          = 30s ✅
```

**Kafka vs Kinesis:**
```
> 500K events/sec     → MSK (Kafka)
< 500K events/sec     → Kinesis (simpler ops)
Multi-consumer fan-out → always MSK
Multi-cloud / portable → always MSK
```

**Flink vs Spark Streaming:**
```
SLA < 60s + stateful  → Flink
SLA > 60s + batch too → Spark Structured Streaming
Simple filter/enrich  → Kafka Streams
```

**Redis vs Pinot vs Snowflake:**
```
Sub-ms KV lookup           → Redis
Sub-second OLAP (fresh)    → Pinot / Druid
Governed SQL, hourly+      → Snowflake
Open format, multi-engine  → Iceberg on S3
```

**Snowflake modeling:**
```
Dedup:      QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_ts) = 1
Clustering: CLUSTER BY (event_date, region)         ← not partition key; Snowflake micro-partitions
Refresh:    Dynamic Tables for incremental SQL, dbt for complex transformations
```

**Watermark rule:**
```
Watermark should be ≤ 15% of window size
Window = 1 min → watermark ≤ 9 sec
Window = 10 min → watermark ≤ 90 sec
```

---

## WBD-Specific Stack Map

```
Client SDK (Max app)
    ↓ batch events every 5s
ALB → Confluent REST Proxy fleet (auto-scaling)
    ↓ ACK=1, ISR replication
MSK (Kafka) — 3.5 GB/sec, retention 2 days
    ↓
    ├── Flink Job 1: PII masking + sliding window (10s slide / 1min window / 15s watermark)
    │       ↓ active viewer counts, buffer metrics
    │   Redis Cluster (sharded by content_id)
    │       ↓
    │   REST API → Dashboard (< 30s SLA ✅)
    │
    └── Flink Job 2: raw event enrichment
            ↓ Parquet
        S3 (Bronze layer)
            ↓ Snowpipe auto-ingest
        Snowflake RAW schema
            ↓ dbt / Dynamic Tables (1h refresh)
        Snowflake MARTS schema
            ↓
        Looker / Tableau (7-day drop-off, buffering metrics)
```

---

*Decision tree covers: ingestion, stream processing, storage, and serving layers across all SLA tiers. Tradeoffs calibrated for media/streaming platforms (WBD/Max use cases).*
