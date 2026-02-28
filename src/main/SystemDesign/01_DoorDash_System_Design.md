# DoorDash Metrics & Analytics Platform - System Design

## 🚀 Opening Statement (CRITICAL)

**Start with this exact framing:**

> "I'll design a metrics platform that prioritizes correctness, replayability, and operational simplicity, while supporting near-real-time KPIs and historical analytics."

This framing immediately sets expectations and demonstrates understanding of trade-offs.

---

## 0️⃣ Clarifying Questions (Ask First – 3–5 max)

### Functional Requirements
- **What KPIs are required?** (DAU, MAU, conversion, latency, failures)
- **What is the SLA?** (seconds vs minutes)
- **Are metrics used for real-time ops or business reporting?**
- **Who are consumers?** (Executives, analysts, data scientists)

### Non-Functional Requirements
- **Event volume?** (events/sec)
- **Data retention requirements?**
- **PII / compliance needs?**
- **Cost sensitivity?**

### After Answers, Say:
> "I'll assume near-real-time (1–2 min SLA), high event volume (10K-100K events/sec), and analytics-first use cases."

---

## 1️⃣ High-Level Architecture (End-to-End)

```
Mobile / Web Apps
        ↓
Backend Services (Producers)
        ↓
Kafka (Durable Event Buffer)
        ↓
Snowpipe Streaming / Kafka Sink Connector
        ↓
RAW_APP_EVENTS (Bronze Layer)
        ↓
Dynamic Tables / Tasks
        ↓
FILTERED_EVENTS (Silver Layer)
        ↓
Dynamic Tables / Aggregation Tasks
        ↓
METRICS / SUMMARY TABLES (Gold Layer)
        ↓
Streamlit / BI Tools / Snowflake Notebooks
```

---

## 2️⃣ Why This Architecture (One-Line Justification)

> "Kafka decouples producers from consumers, Snowflake simplifies analytics at scale, and keeping transformations inside Snowflake reduces operational overhead while maintaining data immutability and replayability."

### Key Design Principles

| Principle | Rationale |
|-----------|-----------|
| **Immutability** | Raw events never change → enables replay and debugging |
| **Recomputation** | Fix errors via logic changes, not data patches |
| **Decoupling** | Kafka buffer isolates producers from consumer load |
| **Simplicity** | Single cloud data warehouse vs. multiple tools |
| **Replayability** | Can re-run any transformation for any time window |

---

## 3️⃣ Data Model (FINAL)

### 🟤 Bronze Layer – Raw Events (Source of Truth)

```sql
CREATE TABLE RAW_APP_EVENTS (
  event_id STRING,
  event_type STRING,
  event_version INT,
  user_id STRING,
  order_id STRING,
  device_id STRING,
  event_timestamp TIMESTAMP,
  ingestion_timestamp TIMESTAMP,
  payload VARIANT
)
CLUSTER BY DATE(event_timestamp), event_type;
```

#### Key Properties
- **Append-only:** Only INSERT operations
- **Immutable:** Never DELETE or UPDATE
- **Schema-on-read:** VARIANT payload handles schema evolution
- **Backfill & replay friendly:** Complete historical record
- **Clustering:** On `DATE(event_timestamp)` and `event_type` for query efficiency

#### Event Examples
```json
{
  "event_type": "order_placed",
  "user_id": "u123",
  "order_id": "o456",
  "event_timestamp": "2026-02-04T14:30:00Z",
  "payload": {
    "restaurant_id": "r789",
    "delivery_address": "123 Main St",
    "total_amount": 45.99,
    "items_count": 5
  }
}
```

---

### ⚪ Silver Layer – Filtered & Refined Events

```sql
CREATE DYNAMIC TABLE FILTERED_EVENTS AS
SELECT
  event_id,
  event_type,
  user_id,
  order_id,
  device_id,
  event_timestamp,
  DATE(event_timestamp) AS event_date,
  EXTRACT(YEAR FROM event_timestamp) AS event_year,
  EXTRACT(MONTH FROM event_timestamp) AS event_month,
  city_id,
  platform,
  app_version,
  CURRENT_TIMESTAMP() AS processed_timestamp
FROM RAW_APP_EVENTS
WHERE
  event_timestamp >= DATEADD(day, -7, CURRENT_DATE())
  AND user_id IS NOT NULL
  AND event_type IS NOT NULL
TARGET_LAG = '5 minutes'
WAREHOUSE = 'analytics_wh';
```

#### Responsibilities
- ✅ Data quality checks (null validation, schema validation)
- ✅ Deduplication (if applicable)
- ✅ Schema normalization (flatten nested structures)
- ✅ PII masking policies (hash sensitive fields)
- ✅ Version handling (handle schema evolution)
- ✅ Enrichment (join with dimension tables if needed)

#### Why Dynamic Tables?
- **Incremental refresh:** Only processes new/changed data
- **Handles late arrivals:** Gracefully handles out-of-order events
- **Automatic lineage:** Snowflake tracks dependencies
- **TARGET_LAG:** Guarantees freshness SLA

---

### 🟡 Gold Layer – Metrics & Summary Tables

#### Example 1: Daily Active Users

```sql
CREATE DYNAMIC TABLE METRICS_DAU AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  COUNT(DISTINCT user_id) AS dau
FROM FILTERED_EVENTS
WHERE event_type IN ('order_placed', 'delivery_completed')
GROUP BY DATE(event_timestamp), city_id
TARGET_LAG = '2 minutes'
WAREHOUSE = 'metrics_wh';
```

#### Example 2: Order Volume (Per Minute)

```sql
CREATE DYNAMIC TABLE METRICS_ORDERS_MINUTE AS
SELECT
  DATE_TRUNC('minute', event_timestamp) AS metric_minute,
  city_id,
  COUNT(*) AS orders_count,
  COUNT(DISTINCT user_id) AS unique_users,
  AVG(CAST(payload:total_amount AS FLOAT)) AS avg_order_value
FROM FILTERED_EVENTS
WHERE event_type = 'order_placed'
GROUP BY DATE_TRUNC('minute', event_timestamp), city_id
TARGET_LAG = '1 minute'
WAREHOUSE = 'metrics_wh';
```

#### Example 3: Conversion Funnel

```sql
CREATE DYNAMIC TABLE METRICS_CONVERSION_FUNNEL AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  COUNT(CASE WHEN event_type = 'app_opened' THEN 1 END) AS opens,
  COUNT(CASE WHEN event_type = 'search_completed' THEN 1 END) AS searches,
  COUNT(CASE WHEN event_type = 'restaurant_viewed' THEN 1 END) AS views,
  COUNT(CASE WHEN event_type = 'order_placed' THEN 1 END) AS orders,
  ROUND(100.0 * COUNT(CASE WHEN event_type = 'order_placed' THEN 1 END) 
        / NULLIF(COUNT(CASE WHEN event_type = 'app_opened' THEN 1 END), 0), 2) AS conversion_rate
FROM FILTERED_EVENTS
GROUP BY DATE(event_timestamp), city_id
TARGET_LAG = '2 minutes'
WAREHOUSE = 'metrics_wh';
```

#### Gold Layer Properties
- ✅ Pre-aggregated (optimized for queries)
- ✅ SLA-aligned refresh (1-2 minutes)
- ✅ Query-optimized (small result sets)
- ✅ Stable schema (rarely changes)
- ✅ Business semantics (KPIs, not raw events)

---

## 4️⃣ Ingestion Pipeline Design

### Step 1: App → Kafka

**Producer Configuration:**
```
Topic: app-events
Partitions: 100+ (by user_id or order_id)
Replication Factor: 3
Retention: 7 days
```

**App-side handling:**
- Async event publishing (non-blocking)
- Automatic retries with exponential backoff
- Batch multiple events before sending
- No user experience impact on failures

### Step 2: Kafka → Snowflake

**Option A: Snowpipe Streaming (Recommended)**
```
Advantages:
- Event-driven (near-real-time)
- Automatic schema detection
- Built-in deduplication
- Failures don't block pipeline

SLA: 1-5 minutes latency
Cost: Moderate
Complexity: Low
```

**Option B: Kafka Connect Snowflake Sink**
```
Advantages:
- Kafka-native tooling
- Better data transformation (SMTs)
- Easier debugging with Kafka Connect ecosystem

SLA: 2-10 minutes latency
Cost: Higher (manage separate cluster)
Complexity: Higher (more operational overhead)
```

### Step 3: Landing Zone

**Micro-batching approach:**
```sql
CREATE TABLE RAW_APP_EVENTS_LANDING (
  batch_id STRING,
  event_id STRING,
  event_type STRING,
  payload VARIANT,
  ingestion_timestamp TIMESTAMP,
  _received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Snowpipe appends batches every 5 minutes
-- Tasks merge from LANDING → RAW_APP_EVENTS
```

📌 **Important Note:**
> "Tasks are NOT used for Kafka ingestion; they are only used AFTER data lands in Snowflake. Snowpipe Streaming handles the ingestion."

---

## 5️⃣ Orchestration: Tasks vs Dynamic Tables

### Mental Model (MEMORIZE)

| Concept | Role |
|---------|------|
| **Tasks** | Control plane (orchestration, conditional logic, side effects) |
| **Dynamic Tables** | Data plane (incremental transformations, automatic refresh) |

### When to Use What

| Layer | Tool | Why |
|-------|------|-----|
| **Ingestion** | Snowpipe Streaming | Event-driven, no dependencies |
| **Silver transforms** | Dynamic Tables | Incremental refresh, late data handling |
| **Gold metrics** | Dynamic Tables | Guaranteed freshness, SLA alignment |
| **Data quality checks** | Tasks | Conditional logic, alerts |
| **Backfills** | Tasks | Controlled replay, manual intervention |
| **Alerting** | Tasks | Side effects (send to Slack, PagerDuty) |

### Example: Task-Based Data Quality Check

```sql
CREATE OR REPLACE TASK CHECK_DATA_QUALITY
  WAREHOUSE = 'analytics_wh'
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  -- Check for late arrivals
  LET late_events := (
    SELECT COUNT(*) FROM RAW_APP_EVENTS 
    WHERE ingestion_timestamp > DATEADD(hour, 1, event_timestamp)
  );
  
  -- Alert if threshold exceeded
  IF late_events > 1000 THEN
    CALL notify_slack('⚠️ High volume of late events detected');
  END IF;
  
  -- Log metrics
  INSERT INTO QUALITY_LOG (check_name, event_count, check_timestamp)
  VALUES ('late_arrivals', late_events, CURRENT_TIMESTAMP());
END;
```

### Example: Task-Based Backfill

```sql
CREATE OR REPLACE TASK BACKFILL_METRICS
  WAREHOUSE = 'metrics_wh'
  SCHEDULE = 'USING CRON 0 3 * * * UTC'
AS
BEGIN
  -- Re-compute yesterday's metrics in case of late arrivals
  ALTER DYNAMIC TABLE METRICS_ORDERS_MINUTE REFRESH;
  ALTER DYNAMIC TABLE METRICS_DAU REFRESH;
  
  -- Log completion
  CALL notify_slack('✅ Daily backfill completed');
END;
```

📌 **Key Line:**
> "Tasks orchestrate execution; dynamic tables guarantee freshness."

---

## 6️⃣ SLA & Latency Handling

### Requirement: 1-2 Minute SLA

### Solution: Dynamic Table TARGET_LAG

```sql
-- For ops dashboards (stricter SLA)
CREATE DYNAMIC TABLE METRICS_ORDERS_MINUTE
...
TARGET_LAG = '1 minute'
WAREHOUSE = 'high_priority_wh';

-- For daily reports (relaxed SLA)
CREATE DYNAMIC TABLE METRICS_DAU
...
TARGET_LAG = '2 minutes'
WAREHOUSE = 'standard_wh';
```

### Why Not Per-Second Tasks?

| Approach | Latency | Cost | Reliability |
|----------|---------|------|-------------|
| **Per-second tasks** | 1-2 sec | 💰💰💰 Very high | ❌ Brittle |
| **Dynamic tables (1 min)** | 1-2 min | 💰 Moderate | ✅ Robust |
| **Hourly batch** | 30-60 min | 💰 Low | ✅ Very robust |

### Trade-off Justification
> "We use 1-2 minute SLA because ops dashboards don't need sub-second data, and the cost/reliability trade-off is poor for per-second refresh."

---

## 7️⃣ Streaming vs Batch Execution

### Same Architecture, Different Execution

```
┌─────────────────────────────────────┐
│     SAME DATA MODEL & LOGIC         │
│  (Bronze → Silver → Gold layers)    │
└─────────────────────────────────────┘
       ↙                     ↖
  STREAMING                 BATCH
  (Real-time ops)        (Finance reports)
```

### Comparison

| Aspect | Streaming | Batch |
|--------|-----------|-------|
| **Ingestion** | Snowpipe Streaming | COPY / Scheduled Snowpipe |
| **Refresh** | Every 1-2 minutes | Daily / Hourly |
| **Cost** | $$$$ (frequent compute) | $$ (scheduled compute) |
| **Use case** | Live dashboards, alerts | End-of-day reports, finance |
| **Example** | METRICS_ORDERS_MINUTE | METRICS_DAU (daily) |

### Implementation

```sql
-- STREAMING: High-frequency refresh
CREATE DYNAMIC TABLE METRICS_LIVE_ORDERS
...
TARGET_LAG = '1 minute'
WAREHOUSE = 'streaming_wh';

-- BATCH: Scheduled refresh
CREATE TASK METRICS_DAILY_REFRESH
  WAREHOUSE = 'batch_wh'
  SCHEDULE = 'USING CRON 0 1 * * * UTC'
AS
  ALTER DYNAMIC TABLE METRICS_DAU REFRESH;
```

📌 **Strong Line:**
> "Architecture remains the same; only scheduling and cost profile change."

---

## 8️⃣ Schema Evolution

### Challenge: Handling App Updates

Apps release new features → Event schema changes

**Wrong approach:** Use Iceberg for multi-engine compatibility

**Right approach:** Leverage VARIANT + event versioning

### Solution: VARIANT + Explicit Versioning

```sql
-- Bronze: Raw events with schema flexibility
CREATE TABLE RAW_APP_EVENTS (
  event_id STRING,
  event_type STRING,
  event_version INT,  -- Track schema version
  payload VARIANT,    -- Schema-on-read
  ...
);

-- Silver: Version-aware transformation
CREATE DYNAMIC TABLE FILTERED_EVENTS AS
SELECT
  event_id,
  event_type,
  CASE 
    WHEN event_version = 1 THEN payload:user_id
    WHEN event_version = 2 THEN payload:customer_id
    WHEN event_version >= 3 THEN payload:user_profile.id
  END AS user_id,
  ...
FROM RAW_APP_EVENTS;
```

### Key Advantages

| Feature | Benefit |
|---------|---------|
| **VARIANT** | No schema enforcement → flexible ingestion |
| **event_version** | Explicit handling of breaking changes |
| **COALESCE** | Backward compatibility for renamed fields |
| **Dynamic Tables** | Automatic re-computation when logic changes |

### Migration Strategy

```
v1 Events          v2 Events          v3 Events
(old app)    →    (new app rollout)   →  (fully deployed)
     ↓             ↓                      ↓
  payload:         payload:             payload:
  user_id          customer_id          user_profile.id
     ←──────────────────────────────────→
      All handled by COALESCE() logic
```

📌 **Defense Against "Why Not Iceberg?"**

> "Iceberg adds value for multi-engine access (Spark, Presto, etc.), but here Snowflake natively handles schema evolution via VARIANT and Dynamic Tables. Iceberg would add unnecessary complexity."

---

## 9️⃣ Backfilling & Correctness

### Requirement: Fix errors in metrics

### Solution: Immutable Raw Data + Recomputation

```sql
-- Scenario: We discovered logic bug in conversion rate calculation
-- Discovery time: 2026-02-04 10:00 AM
-- Affected window: 2026-02-01 to 2026-02-04

-- Step 1: Fix the logic in the transformation
ALTER DYNAMIC TABLE METRICS_CONVERSION_FUNNEL 
  SET AS
  SELECT
    DATE(event_timestamp) AS metric_date,
    city_id,
    COUNT(CASE WHEN event_type = 'app_opened' THEN 1 END) AS opens,
    COUNT(CASE WHEN event_type = 'order_placed' THEN 1 END) AS orders,
    -- FIX: Only count organic opens, not ads
    ROUND(100.0 * COUNT(CASE WHEN event_type = 'order_placed' AND payload:source != 'ad' THEN 1 END)
          / COUNT(CASE WHEN event_type = 'app_opened' AND payload:source != 'ad' THEN 1 END), 2) AS conversion_rate
  FROM FILTERED_EVENTS
  WHERE event_timestamp >= '2026-02-01'::DATE
  GROUP BY DATE(event_timestamp), city_id;

-- Step 2: Manually trigger refresh for affected window
ALTER DYNAMIC TABLE METRICS_CONVERSION_FUNNEL REFRESH;

-- Step 3: Verify correctness
SELECT * FROM METRICS_CONVERSION_FUNNEL WHERE metric_date BETWEEN '2026-02-01' AND '2026-02-04';

-- Step 4: Resume normal operation
-- (automatic refresh resumes)
```

### Why This Approach?

| Aspect | Benefit |
|--------|---------|
| **Raw data immutability** | Never lose source of truth |
| **Recomputation** | Can fix logic for any historical window |
| **Auditability** | Track what changed and when |
| **Correctness** | Business metrics always derivable from source |

### Backfill from Kafka (If Needed)

```
Scenario: Complete data loss in Snowflake
         (OR) Disaster recovery from backup

1. Stop downstream Tasks
2. Drain Snowflake tables
3. Kafka has 7 days of retention
4. Replay Kafka topic into Snowflake
5. Verify data integrity
6. Resume downstream Tasks
```

📌 **Key Line:**
> "Events are immutable; correctness is achieved via recomputation of logic, not updates to data."

---

## 🔟 Partitioning, Clustering & Indexing

### Snowflake Fundamentals

| Feature | Snowflake Support |
|---------|------------------|
| **Partitioning** | ❌ Manual partitioning not needed |
| **Indexes** | ❌ Traditional indexes not used |
| **Clustering** | ✅ Logical clustering on sort keys |

### Clustering Strategy (Automatic Optimization)

```sql
-- Bronze Layer
CREATE TABLE RAW_APP_EVENTS (...)
CLUSTER BY DATE(event_timestamp), event_type;
-- Why: Filter queries use event_timestamp and event_type

-- Silver Layer
CREATE DYNAMIC TABLE FILTERED_EVENTS (...)
CLUSTER BY DATE(event_date);
-- Why: Most queries filter by date

-- Gold Layer
CREATE DYNAMIC TABLE METRICS_DAU (...)
CLUSTER BY metric_date, city_id;
-- Why: Analytical queries often slice by date and geography
```

### Clustering Best Practices

| ✅ DO | ❌ DON'T |
|------|---------|
| Cluster on filter columns | Cluster on high-cardinality IDs (user_id, order_id) |
| 2-3 columns max | More than 3 clustering columns |
| Columns used in WHERE clauses | Columns rarely used in queries |
| Low-cardinality dimensions | Timestamp columns (already have micro-partitions) |

📌 **Why:**
> "We cluster only on columns used in filters and joins, avoiding high-cardinality IDs because that would create too many small partitions and hurt query performance."

---

## 1️⃣1️⃣ Security, Governance & Compliance

### PII Handling Strategy

```sql
-- Dynamic Masking Policies (Silver Layer)
CREATE MASKING POLICY mask_phone AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ANALYST', 'EXECUTIVE') THEN '***-***-****'
    WHEN CURRENT_ROLE() = 'DATA_ENGINEER' THEN val
    ELSE NULL
  END;

-- Apply to sensitive columns
ALTER TABLE FILTERED_EVENTS
  MODIFY COLUMN user_phone SET MASKING POLICY mask_phone;
```

### Role-Based Access Control (RBAC)

```sql
-- Analytics Team: Gold tables only
GRANT SELECT ON SCHEMA gold_layer TO ROLE analytics_role;
DENY SELECT ON SCHEMA silver_layer TO ROLE analytics_role;

-- Data Scientists: Silver + Fact tables
GRANT SELECT ON SCHEMA silver_layer TO ROLE data_science_role;
GRANT SELECT ON SCHEMA gold_layer TO ROLE data_science_role;

-- Data Engineers: Full access
GRANT ALL ON SCHEMA bronze_layer, silver_layer, gold_layer 
  TO ROLE data_engineer_role;
```

### Audit & Compliance

```sql
-- Enable query audit logs
ALTER SESSION SET QUERY_RESULT_FORMAT = 'PARQUET';

-- Track data lineage (Snowflake automatically)
SELECT * FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%FILTERED_EVENTS%'
ORDER BY start_time DESC;

-- Row Access Policies (for multi-tenancy)
CREATE ROW ACCESS POLICY city_access AS (city_id STRING) 
  RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('GLOBAL_ANALYST')
  OR city_id IN (
    SELECT city_id FROM allowed_cities 
    WHERE assigned_to_user = CURRENT_USER()
  );
```

---

## 1️⃣2️⃣ Consumer Access Patterns

### Data Analysts
```
Golden layer → Streamlit / Tableau / Looker
Requirements:
- Stable, pre-aggregated metrics
- 1-2 minute latency acceptable
- Read-only access
```

### Data Scientists
```
Silver layer → Snowflake Notebooks / Python SDK
Requirements:
- Detailed events for ML feature engineering
- Reproducible, version-controlled code
- Can perform ad-hoc analysis
```

### Executives / Product
```
Gold layer → BI Dashboard
Requirements:
- Business KPIs (DAU, conversion, revenue)
- Pre-computed, cacheable
- No raw data exposure
```

### Downstream ML Systems
```
Silver/Gold → ML Feature Store
Requirements:
- Consistent, point-in-time data
- Deterministic transformations
- Integration with model serving platform
```

---

## 1️⃣3️⃣ Disaster Recovery & High Availability

### Component-Level Failure Scenarios

#### 1. Kafka Broker Failure
```
Mitigation:
- Replication factor = 3 (automatic failover)
- Multi-AZ deployment
- Leader election within seconds
- Zero data loss
```

#### 2. Snowflake Warehouse Down
```
Mitigation:
- Auto-scaling warehouses (share compute)
- Automatic failover to backup warehouse
- RTO: 5-10 minutes
- RPO: Loss of last micro-batch only
```

#### 3. Snowpipe Streaming Interruption
```
Mitigation:
- Automatic retry logic built-in
- Duplicate detection (event_id)
- Kafka retains data 7 days
- RTO: <5 minutes
- RPO: Event arrivals resume from last checkpoint
```

#### 4. Data Corruption in Silver Layer
```
Mitigation:
- Recompute from raw (immutable source)
- No data patches; re-run transformation
- Audit trail of all computation
- Historical correctness guaranteed
```

### Cross-Region Disaster Recovery

```sql
-- Snowflake Failover Groups (Business Critical edition)
CREATE FAILOVER GROUP metrics_dr
  OBJECT_TYPES = TABLES, DYNAMIC TABLES, TASKS
  ALLOWED_ACCOUNTS = 'prod_account', 'dr_account'
  REPLICATION_SCHEDULE = 'EVERY 5 MINUTES';

-- Manual failover via runbook:
-- 1. Detect primary region failure
-- 2. Alert on-call engineer
-- 3. Run: ALTER FAILOVER GROUP metrics_dr PRIMARY SUSPEND;
-- 4. Wait for replication to catch up
-- 5. Run: ALTER FAILOVER GROUP metrics_dr PRIMARY TO dr_account;
-- 6. Update DNS / routing
-- 7. Verify metrics in DR region
```

📌 **Key Clarification:**
> "Business Critical edition enables replication, but teams must explicitly configure and manually trigger failover. It's not automatic."

---

## 1️⃣4️⃣ Cost Management & Optimization

### Cost Drivers in Snowflake

| Component | Cost Impact | Optimization |
|-----------|-------------|--------------|
| **Compute (credits)** | 40-50% | Auto-suspend, right-size warehouses, avoid overprovisioning |
| **Storage** | 20-30% | Time travel settings, fail-safe, compression |
| **Data transfer** | 10-20% | Snowflake-to-Snowflake replication (free), cache results |

### Cost Optimization Strategies

```sql
-- 1. Separate warehouses by workload
CREATE WAREHOUSE streaming_wh
  WITH_SIZE = 'LARGE'
  AUTO_SUSPEND = 60
  AUTO_SCALE_MAX_CLUSTER_COUNT = 5;

CREATE WAREHOUSE batch_wh
  WITH_SIZE = 'SMALL'
  AUTO_SUSPEND = 300;

-- 2. Profile query costs
SELECT 
  query_id,
  query_text,
  total_elapsed_time / 1000 AS elapsed_sec,
  credits_used_cloud_services,
  ROUND(credits_used_compute / NULLIF(total_elapsed_time / 1000, 0), 2) AS credits_per_sec
FROM snowflake.account_usage.query_history
WHERE execution_status = 'SUCCESS'
ORDER BY credits_used_compute DESC
LIMIT 10;

-- 3. Reduce time travel (default 1 day, only 0 days for non-critical)
ALTER TABLE raw_app_events SET DATA_RETENTION_TIME_IN_DAYS = 0;

-- 4. Query result caching
SELECT * FROM metrics_dau
WHERE metric_date = CURRENT_DATE() - 1;
-- Snowflake caches this; re-running = free
```

### Cost Monitoring Dashboard

```sql
-- Daily credit consumption
CREATE DYNAMIC TABLE cost_daily_summary AS
SELECT
  DATE(start_time) AS cost_date,
  warehouse_name,
  SUM(credits_used_compute) AS compute_credits,
  SUM(credits_used_cloud_services) AS service_credits,
  COUNT(*) AS query_count,
  ROUND(AVG(total_elapsed_time / 1000), 1) AS avg_query_sec
FROM snowflake.account_usage.query_history
GROUP BY DATE(start_time), warehouse_name
ORDER BY cost_date DESC, compute_credits DESC;
```

---

## 1️⃣5️⃣ Scaling Strategy

### Handling 10x Event Volume

#### 1. Kafka Scaling
```
Current: 100 partitions
Target: 500-1000 partitions
Action: Increase partitions online (no downtime)

Why: Each partition = 1 consumer max
     More partitions = more parallelism
```

#### 2. Snowflake Scaling
```
Current: Large warehouse (8 credits/hour)
Target: X-Large (16 credits/hour) + auto-scaling

Why: Snowflake handles scale within warehouse
     Beyond threshold, add clusters for concurrency

Configuration:
CREATE WAREHOUSE scaled_wh
  WITH_SIZE = 'X-LARGE'
  MAX_CLUSTER_COUNT = 10
  AUTO_SCALE_POLICY = 'ECONOMY';
```

#### 3. Data Volume Scaling
```
Current: 1TB raw data
Target: 10TB raw data

Mitigation:
- Snowflake handles petabytes natively
- Clustering remains efficient
- Query performance unchanged (due to pruning)
- Cost scales linearly with compute usage
```

#### 4. Transformation Scaling
```
Current: Silver → Gold takes 2 minutes
Target: Same SLA at 10x volume

Mitigation:
Dynamic tables scale with warehouse
If 1 minute refresh is needed:
  - Increase warehouse size
  - Add more clusters
  - Or split metrics into separate tasks
```

### Example: Scaling Dynamic Tables

```sql
-- Before: Single large task
CREATE DYNAMIC TABLE METRICS_ALL
  TARGET_LAG = '2 minutes'
  WAREHOUSE = 'large_wh'
AS
SELECT * FROM metrics_by_city
UNION ALL
SELECT * FROM metrics_by_platform
...;

-- After: Split by dimension
CREATE DYNAMIC TABLE METRICS_BY_CITY
  TARGET_LAG = '1 minute'
  WAREHOUSE = 'metrics_city_wh'
AS SELECT * FROM metrics_by_city;

CREATE DYNAMIC TABLE METRICS_BY_PLATFORM
  TARGET_LAG = '1 minute'
  WAREHOUSE = 'metrics_platform_wh'
AS SELECT * FROM metrics_by_platform;
```

---

## 1️⃣6️⃣ Trade-offs (YOU MUST ADMIT)

### What You're Giving Up

| Trade-off | Impact | Mitigation |
|-----------|--------|-----------|
| **Vendor lock-in** | Snowflake proprietary SQL | Minimized by using standard SQL where possible |
| **Sub-second latency** | Not achievable; min 1-2 min SLA | Use cache for ultra-fresh data |
| **Compute cost** | Snowflake is expensive vs on-prem | Justified by operational simplicity |
| **Onboarding learning curve** | VARIANT, Dynamic Tables, Tasks | Worth the effort |

### Defense

> "We trade ultra-low latency and infrastructure portability for **correctness, simplicity, and iteration speed**. Correctness is non-negotiable for metrics; simplicity reduces operational burden."

---

## 1️⃣7️⃣ Sample 30-Second Closing (MEMORIZE)

> "This design uses **Kafka for durability and decoupling**, **Snowflake for scalable analytics**, **dynamic tables for automatic freshness**, and **tasks for orchestration and exceptions**. Raw data is **immutable**, metrics are **recomputable**, failures are **isolated**, and the **same architecture supports both streaming and batch** workloads. It prioritizes **correctness and operational simplicity** over ultra-low latency and multi-vendor portability."

---

## 1️⃣7️⃣ Version Control & Rollback

### Challenge: Managing SQL Changes in Production

**Problem:**
- Deploy new transformation logic → metrics become incorrect
- Need to rollback quickly without data loss
- Multiple team members making changes simultaneously

### Solution: Version Control + Deployment Strategy

#### 1. Source Control (Git)

```
doordash-metrics/
├── dbt/  (Preferred: Declarative SQL)
│   ├── models/
│   │   ├── bronze/
│   │   │   └── raw_events.sql
│   │   ├── silver/
│   │   │   └── filtered_events.sql
│   │   └── gold/
│   │       ├── metrics_dau.sql
│   │       └── metrics_conversion.sql
│   ├── tests/
│   │   └── schema_tests.yml
│   └── dbt_project.yml
├── snowpark/  (For complex Python logic)
│   ├── user_churn_ml.py
│   └── requirements.txt
└── README.md
```

#### 2. Deployment Strategy: Blue-Green

```sql
-- Current (BLUE) environment
CREATE DYNAMIC TABLE METRICS_DAU_BLUE AS
SELECT DATE(event_timestamp) AS date, COUNT(DISTINCT user_id) AS dau
FROM filtered_events
GROUP BY DATE(event_timestamp);

-- New (GREEN) environment
CREATE DYNAMIC TABLE METRICS_DAU_GREEN AS
SELECT DATE(event_timestamp) AS date, COUNT(DISTINCT user_id) AS dau
FROM filtered_events
WHERE payload:country = 'US'  -- NEW LOGIC
GROUP BY DATE(event_timestamp);

-- Validation step
SELECT
  COUNT(*) as total_rows,
  ABS(blue_count - green_count) as difference
FROM (
  SELECT COUNT(*) as blue_count FROM metrics_dau_blue
) b,
(
  SELECT COUNT(*) as green_count FROM metrics_dau_green
) g;

-- Switchover (if GREEN passes validation)
-- Step 1: Create synonym/alias
CREATE OR REPLACE VIEW metrics_dau AS SELECT * FROM metrics_dau_green;

-- Rollback (if issues detected)
CREATE OR REPLACE VIEW metrics_dau AS SELECT * FROM metrics_dau_blue;
```

#### 3. Feature Flags for Gradual Rollout

```sql
-- Add feature flag to transformation
CREATE TABLE feature_flags (
  flag_name STRING,
  enabled BOOLEAN,
  rollout_percentage INT,
  created_at TIMESTAMP,
  updated_by STRING
);

INSERT INTO feature_flags VALUES
('enhanced_revenue_calculation', TRUE, 100, NOW(), 'analytics_team');

-- Use in transformation
CREATE DYNAMIC TABLE metrics_revenue AS
SELECT
  DATE(event_timestamp) AS date,
  city_id,
  CASE
    WHEN (SELECT enabled FROM feature_flags WHERE flag_name = 'enhanced_revenue_calculation') THEN
      -- New logic: includes tips, refunds, adjustments
      SUM(CAST(payload:amount AS FLOAT) + 
          COALESCE(CAST(payload:tip AS FLOAT), 0) -
          COALESCE(CAST(payload:refund AS FLOAT), 0))
    ELSE
      -- Old logic: just base amount
      SUM(CAST(payload:amount AS FLOAT))
  END AS total_revenue
FROM filtered_events
WHERE event_type = 'order_completed'
GROUP BY DATE(event_timestamp), city_id;
```

#### 4. Automated Testing

```sql
-- Schema validation
-- Verify columns exist before transformation
CREATE OR REPLACE TASK validate_schema_before_transform
  WAREHOUSE = validation_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  LET missing_fields := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'FILTERED_EVENTS'
      AND COLUMN_NAME IN ('user_id', 'event_timestamp', 'city_id')
  );
  
  IF missing_fields < 3 THEN
    RAISE 'Schema validation failed: missing critical columns';
  END IF;
END;

-- Data quality tests
CREATE TABLE data_quality_tests (
  test_name STRING,
  test_query STRING,
  expected_result BOOLEAN,
  severity STRING  -- 'ERROR' or 'WARNING'
);

INSERT INTO data_quality_tests VALUES
('no_null_user_ids', 'SELECT COUNT(*) FROM filtered_events WHERE user_id IS NULL', FALSE, 'ERROR'),
('dau_within_range', 'SELECT COUNT(DISTINCT user_id) FROM filtered_events > 10000', TRUE, 'WARNING');
```

#### 5. Rollback Runbook

```
DEPLOYMENT ROLLBACK PROCEDURE

IF: Metrics appear wrong after deployment
THEN:
  1. Alert fires: "New metric version has drift from baseline"
  2. Engineer checks: git log (see what changed)
  3. Decision: 
     - If new logic wrong: Rollback via git revert + redeploy
     - If data issue: Investigate data quality, fix upstream
  
  4. Rollback steps:
     a. git revert [commit_hash]
     b. dbt run --models metrics_dau
     c. Verify metrics return to baseline
     d. Confirm with analytics team
  
  5. Post-mortem:
     - Why did tests miss it?
     - Add test to prevent recurrence
     - Update runbook if needed
```

#### 6. Monitoring Deployments

```sql
-- Track deployment history
CREATE TABLE deployment_log (
  deployment_id STRING,
  model_name STRING,
  old_version STRING,
  new_version STRING,
  deployed_by STRING,
  deployed_at TIMESTAMP,
  status STRING,  -- 'SUCCESS', 'ROLLBACK', 'IN_PROGRESS'
  metrics_deviation FLOAT
);

-- During deployment, compare old vs new
SELECT
  old.metric_date,
  old.dau as old_dau,
  new.dau as new_dau,
  ABS((new.dau - old.dau) * 100.0 / old.dau) as pct_change
FROM metrics_dau_blue old
JOIN metrics_dau_green new
  ON old.metric_date = new.metric_date
WHERE ABS((new.dau - old.dau) * 100.0 / old.dau) > 5  -- >5% change is anomaly
ORDER BY pct_change DESC;

-- If anomaly detected: STOP deployment, investigate
```

---

### Interview Answer Template

> "For version control and deployment:
>
> 1. **Source control:** All SQL in Git (dbt for declarative, Snowpark for complex logic)
> 2. **Testing:** Schema validation + data quality tests in CI/CD pipeline
> 3. **Deployment:** Blue-green with validation step before switchover
> 4. **Gradual rollout:** Feature flags allow 50% → 75% → 100% rollout
> 5. **Monitoring:** Compare old vs new metrics during deployment
> 6. **Rollback:** If metrics drift >5%, revert via git + redeploy previous version
>
> This ensures **zero data loss** and **fast recovery** from bad deploys."
