# DoorDash Metrics Platform - Cost & Scaling

## Overview

Cost and scaling are critical in production systems. Interviewers expect you to:
1. Justify architectural choices based on cost
2. Show scaling strategies for 10x, 100x growth
3. Optimize without sacrificing correctness or SLA

---

## 1️⃣ Snowflake Cost Model

### What You Pay For

```
Snowflake Bill = Compute (60%) + Storage (25%) + Data Transfer (15%)
```

| Component | Cost Driver | Impact |
|-----------|-------------|--------|
| **Compute** | Warehouse seconds active | Every query, every second matters |
| **Storage** | Data on disk | Raw data retention, replicas |
| **Data Transfer** | GB transferred between regions | Cross-region replication |

### Warehouse Sizing & Cost

```
Warehouse Size   Credits/Hour   Annual Cost (24/7)*
Small            1              $8,760
Medium           2              $17,520
Large            4              $35,040
X-Large          8              $70,080
2X-Large         16             $140,160

* Assuming $10/credit, 24/7 operation
```

**Key Insight:**
- 1 Small warehouse running 24/7 = $8,760/year
- But you don't need to run 24/7!
- Auto-suspend + Auto-scale makes it much cheaper

---

## 2️⃣ Cost Breakdown: Metrics Platform

### Baseline: 50K events/sec, 2-minute SLA, 10 cities

#### Compute Costs

```
Ingestion Pipeline:
- Warehouse size: Large (4 credits/hour)
- Active time: 24/7 (continuous ingestion)
- Annual cost: 4 credits * 24 hours * 365 days * $10 = $350,400

Silver Layer (Filtering):
- Warehouse size: Medium (2 credits/hour)
- Active time: 24/7 (continuous refresh every 5 min)
- Annual cost: 2 credits * 24 hours * 365 days * $10 = $175,200

Gold Layer (Metrics):
- Warehouse size: Medium (2 credits/hour)
- Active time: 24/7 (continuous refresh every 1-2 min)
- Annual cost: 2 credits * 24 hours * 365 days * $10 = $175,200

Alerting/Monitoring:
- Warehouse size: Small (1 credit/hour)
- Active time: 24/7
- Annual cost: 1 credit * 24 hours * 365 days * $10 = $87,600

TOTAL COMPUTE: $788,400/year (or $65,700/month)
```

#### Storage Costs

```
Raw Events (7-day retention):
- 50K events/sec * 86,400 sec/day * 7 days = 30.24B events
- Average event size: 2KB
- Total: 60TB
- Snowflake storage rate: $40/TB/month
- Annual cost: 60TB * $40 * 12 = $28,800

Silver Events (30-day retention):
- After deduplication + filtering: 25TB
- Annual cost: 25TB * $40 * 12 = $12,000

Gold Metrics (1-year retention):
- Pre-aggregated, small: 100GB
- Annual cost: 0.1TB * $40 * 12 = $48

Backups / Failover (50% of active):
- 42.5TB * $40 * 12 = $20,400

TOTAL STORAGE: ~$61,248/year (or $5,104/month)
```

#### Data Transfer Costs

```
Snowflake to BI tools (Looker/Tableau):
- 10GB/day typical (dashboard refreshes, queries)
- Snowflake egress: $0.03/GB
- Annual cost: 10GB * 365 days * $0.03 = $109.50

Failover replication (US-East to US-West):
- Same data every 5 min: 500GB/day
- Snowflake replication (per 1GB): $0.02
- Annual cost: 500GB * 365 * $0.02 = $3,650

TOTAL DATA TRANSFER: ~$3,760/year
```

#### **ANNUAL TOTAL: ~$853,408 (~$71,117/month)**

---

## 3️⃣ Cost Optimization Strategies

### Strategy 1: Right-Size Warehouses

```sql
-- BEFORE: All workloads on one X-Large warehouse
CREATE WAREHOUSE main_wh WITH_SIZE = 'X-LARGE';  -- $70,080/year per warehouse

-- AFTER: Separate by workload
CREATE WAREHOUSE ingestion_wh WITH_SIZE = 'LARGE';    -- $35,040/year
CREATE WAREHOUSE analytics_wh WITH_SIZE = 'MEDIUM';   -- $17,520/year
CREATE WAREHOUSE ml_wh WITH_SIZE = 'LARGE';           -- $35,040/year

-- Total before: $70,080 * 3 = $210,240
-- Total after: $87,600
-- SAVINGS: $122,640/year (58% reduction)

-- Why: Each workload has different concurrency requirements
-- - Ingestion: Predictable load, needs throughput
-- - Analytics: Highly concurrent, many small queries
-- - ML: Heavy lifting, fewer but larger queries
```

### Strategy 2: Auto-Suspend & Scale

```sql
-- Configure auto-suspend to save money
ALTER WAREHOUSE ingestion_wh SET
  AUTO_SUSPEND = 300  -- Suspend after 5 min of inactivity
  AUTO_SCALE_MAX_CLUSTER_COUNT = 3
  SCALING_POLICY = 'ECONOMY';

-- Example: Ingestion warehouse
-- Reality: Events arrive continuously 24/7
-- So auto-suspend doesn't help much here

-- Better candidate: Analytics warehouse
ALTER WAREHOUSE analytics_wh SET
  AUTO_SUSPEND = 600   -- Suspend after 10 min
  AUTO_SCALE_MAX_CLUSTER_COUNT = 5
  SCALING_POLICY = 'ECONOMY';

-- Savings: Analytics only active during business hours (8 AM - 6 PM)
-- Active hours: 10 hours * 250 days = 2,500 hours/year
-- Cost reduction: (24-10)/24 = 41.67% reduction
-- Annual savings: $17,520 * 0.417 = $7,307/year
```

### Strategy 3: Query Optimization

```sql
-- Identify expensive queries
SELECT
  query_id,
  query_text,
  total_elapsed_time / 1000 AS elapsed_sec,
  bytes_scanned / 1024 / 1024 / 1024 AS gb_scanned,
  credits_used_compute,
  ROUND(credits_used_compute / NULLIF(total_elapsed_time / 1000, 0), 4) AS credits_per_sec
FROM snowflake.account_usage.query_history
WHERE execution_status = 'SUCCESS'
  AND start_time > DATEADD(day, -7, CURRENT_DATE())
ORDER BY credits_used_compute DESC
LIMIT 20;

-- BEFORE: Inefficient query scanning entire table
CREATE DYNAMIC TABLE metrics_dau AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  COUNT(DISTINCT user_id) AS dau
FROM filtered_events
WHERE event_timestamp > DATEADD(day, -30, CURRENT_DATE())  -- Scans 30 days every time
GROUP BY metric_date, city_id;

-- Cost: 10GB scanned * $0.06/GB = $0.60 per run
-- Runs 1440 times/day = $864/day = $315,360/year

-- AFTER: Incremental refresh with proper clustering
CREATE DYNAMIC TABLE metrics_dau AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  COUNT(DISTINCT user_id) AS dau
FROM filtered_events
WHERE event_timestamp >= DATEADD(day, -1, CURRENT_DATE())  -- Only yesterday + today
  AND event_timestamp < DATEADD(day, 1, CURRENT_DATE())
GROUP BY metric_date, city_id
TARGET_LAG = '2 minutes'
WAREHOUSE = metrics_wh
CLUSTER BY event_timestamp, city_id;

-- With clustering, only relevant partitions scanned
-- Cost: 1GB scanned * $0.06 = $0.06 per run
-- Savings: 90% = $283,824/year
```

### Strategy 4: Data Retention Optimization

```sql
-- Reduce retention where possible
-- Bronze: 7 days (replayability)
ALTER TABLE raw_app_events SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- Silver: 30 days (backfill window)
ALTER TABLE filtered_events SET DATA_RETENTION_TIME_IN_DAYS = 30;

-- Gold: 1 year (business reporting)
ALTER TABLE metrics_dau SET DATA_RETENTION_TIME_IN_DAYS = 365;

-- Fail-safe (time travel beyond retention): 0 days
ALTER TABLE raw_app_events SET DEFAULT_DDL_COLLATION = 'UTF-8'
  CHANGE_TRACKING = TRUE;

-- Storage calculation:
-- Before: 7 day * 60TB = 420TB
-- After: 7 day * 60TB * 0.8 (with compression) = 336TB
-- Savings: 84TB * $40 * 12 = $40,320/year

-- ⚠️ Trade-off: Can't recover data older than 7 days
-- ✅ Justification: Kafka keeps 7 days anyway, so redundant
```

### Strategy 5: Compression & File Format

```sql
-- Use efficient file formats
-- JSON (text): Large, slow
-- Parquet (columnar): 80% smaller, 10x faster

-- Configure Snowflake to use optimal formats
ALTER SESSION SET PARQUET_COMPRESSION = 'SNAPPY';

-- Example: 60TB raw JSON → 12TB Parquet
-- Storage reduction: 48TB * $40 * 12 = $23,040/year savings
```

### Strategy 6: Query Result Caching

```sql
-- Snowflake caches query results automatically (24 hour TTL)
-- If analyst runs same query, cache hit = FREE

-- Configure cache TTL
ALTER SESSION SET USE_CACHED_RESULT = TRUE;

-- Example: 100 analysts each run standard BI report
-- Query: "SELECT DAU by city, last 30 days"
-- Size: 500MB

-- Without cache:
-- 100 runs * 500MB * $0.06/GB = 30GB * $0.06 = $1.80 per day = $657/year

-- With cache (1st query hits disk, next 99 hit cache):
-- 1 run * 500MB * $0.06 = $0.018 per day ≈ $6.57/year
-- SAVINGS: 99% = $650/year (small but adds up)
```

### **Total Optimization Potential**

```
Original annual cost: $853,408

Strategy 1 (Right-size): -$122,640
Strategy 2 (Auto-suspend): -$7,307
Strategy 3 (Query opt): -$283,824
Strategy 4 (Retention): -$40,320
Strategy 5 (Compression): -$23,040
Strategy 6 (Caching): -$657

Optimized annual cost: ~$375,620 (56% reduction)
Monthly cost: ~$31,302
```

---

## 4️⃣ Scaling: 10x Event Volume

### Scenario: Events/sec grow from 50K to 500K

#### Impact Assessment

```
Current:
- Events/sec: 50K
- Raw data: 60TB (7 days)
- Warehouse size: Large

10x Growth:
- Events/sec: 500K (10x)
- Raw data: 600TB (10x)
- Compute needed: ???
```

### Compute Scaling

```sql
-- Current setup
Current Warehouse: Large (4 credits/hour)
Current latency: 2 minutes (SLA met)

-- At 10x volume, refresh time will increase
-- Why: More data to process, more comparisons in joins

-- Solution 1: Increase warehouse size
NEW Warehouse: X-Large (8 credits/hour)
Expected latency: Still 2 min (double compute, 10x data ≈ neutral)

-- Solution 2: Add more clusters
ALTER WAREHOUSE metrics_wh SET
  MAX_CLUSTER_COUNT = 10  -- Handle concurrency spike

-- Solution 3: Split workloads
CREATE WAREHOUSE metrics_by_city_wh WITH_SIZE = 'LARGE';
CREATE WAREHOUSE metrics_by_platform_wh WITH_SIZE = 'LARGE';

-- Rationale: Each warehouse handles subset of aggregations
-- Total compute: 2 * Large = 8 credits/hour (same as X-Large)
-- Benefit: Independent scaling, no contention
```

#### Storage Scaling

```
Current storage: 60TB raw + 25TB silver + 0.1TB gold = 85.1TB
At 10x: 851TB

Snowflake handles this natively (petabyte-scale storage)
No architectural changes needed
Cost: 851TB * $40/month = $34,040/month (vs current $5,104)

Mitigation:
- Implement aggressive time travel reduction
- Archive historical data to cloud storage (S3)
- Use Snowflake's table cloning for backups
```

#### Kafka Scaling

```
Current:
- 50K events/sec
- 100 partitions
- Throughput: 500 events/partition/sec

At 10x:
- 500K events/sec
- 1000 partitions (10x)
- Throughput: 500 events/partition/sec (same per partition)

Kafka scaling:
- Add brokers (non-disruptive, online)
- Rebalance partitions

No fundamental change, just scale numbers
```

#### Ingestion Scaling

```
Current:
- Snowpipe Streaming: 1 consumer per partition
- 100 partitions = 100 concurrent consumers
- Throughput: ~500 events/partition/sec

At 10x:
- 1000 partitions
- Snowpipe auto-scales to 1000 consumers
- Throughput: 500K events/sec total

Cost impact:
- Snowpipe charges per partition per day
- 100 partitions: 100 * $0.10 = $10/day = $3,650/year
- 1000 partitions: 1000 * $0.10 = $100/day = $36,500/year
- Increase: $32,850/year

Mitigation:
- Batch multiple events per partition
- Use micro-batching (50ms) vs streaming
```

### 10x Scaling Summary

| Component | Current | At 10x | Cost Change |
|-----------|---------|--------|-------------|
| **Compute** | $788K/yr | $1,051K/yr | +$263K |
| **Storage** | $61K/yr | $306K/yr | +$245K |
| **Data Transfer** | $4K/yr | $40K/yr | +$36K |
| **Snowpipe** | $4K/yr | $37K/yr | +$33K |
| **TOTAL** | $853K/yr | $1,434K/yr | +$581K |
| **% Cost increase** | - | - | +68% |

**Key insight:** Cost grows sub-linearly to volume (68% for 10x volume)

---

## 5️⃣ Scaling: 100x Event Volume

### Scenario: Events/sec grow from 50K to 5M

#### Architectural Changes Needed

```
At 100x volume, we hit Snowflake's practical limits:

1. Single warehouse can't handle 5M events/sec
2. Kafka partition coordination becomes complex
3. Data retention costs become prohibitive
4. Need to consider fan-out architectures
```

### Solution: Multi-Warehouse Fan-Out

```
Instead of single metrics warehouse:
- Metrics by city (10 warehouses)
- Metrics by platform (5 warehouses)
- Metrics by user segment (3 warehouses)

Benefits:
- Independent scaling
- No resource contention
- Easier failure isolation

Trade-off:
- Increased operational complexity
- Need orchestration layer to aggregate
```

### Alternative: Stream Processing Layer

```
Instead of direct Kafka → Snowflake:

Add intermediate layer:

Kafka (5M events/sec)
  ↓
Apache Kafka Streams / Flink (Fan-out)
  ├─ Stream 1: User metrics
  ├─ Stream 2: Restaurant metrics
  └─ Stream 3: Delivery metrics
       ↓ (each 1M-2M events/sec)
   Snowflake (3 warehouses)

Benefits:
- Decouple ingestion rate from Snowflake capacity
- Pre-aggregate at stream layer
- Snowflake only receives pre-processed events

Cost trade-off:
- Add: $50K/yr (stream processing cluster)
- Save: $200K/yr (smaller Snowflake warehouses)
- Net: -$150K/yr savings
```

### Data Retention at 100x

```
Current: 60TB * 7 days = 420TB storage cost
At 100x: 6,000TB * 7 days = expensive

Solutions:
1. Reduce retention to 3 days (conflicts with SLA)
2. Aggregate early (summarize after 7 days)
3. External storage (S3): $0.023/GB/month vs Snowflake $40/TB
   - 6000TB in S3: 6000 * $23 = $138K/month
   - vs Snowflake: 6000 * $40 = $240K/month
   - Savings: $102K/month = $1.22M/year

4. Tiered retention:
   - Raw (3 days, Snowflake): 1.8PB
   - Aggregated (30 days, S3): 10TB
   - Archive (1 year, Glacier): 100TB

```

### 100x Scaling Summary

```
At 100x volume, fundamental shift needed:

Components:
1. Kafka: Scale to 10,000 partitions (from 100)
2. Stream processing: Add Flink/Kafka Streams layer
3. Snowflake: 20-30 warehouses (parallel processing)
4. Storage: Tiered (Snowflake 3 days, S3 30 days, Glacier 1 year)
5. Orchestration: Add Airflow/Prefect for multi-warehouse coordination

Estimated cost:
- Current: $853K/year
- At 100x: $2.5-3M/year (3.5x increase for 100x volume)
- Per-event-sec cost: Unchanged (economies of scale)
```

---

## 6️⃣ Cost vs. Correctness Trade-offs

### Trade-off 1: Lower SLA = Lower Cost

```
Current: 1-2 minute SLA = $65,700/month compute

Option A: 5-minute SLA
- Run aggregations every 5 min instead of 1 min
- Warehouse active time reduced
- Estimated cost: $26,280/month (59% reduction)
- Loss: Real-time alert capability

Option B: 30-minute SLA (batch)
- Run aggregations every 30 min
- Use smaller warehouse, auto-suspend when not running
- Estimated cost: $8,760/month (87% reduction)
- Loss: No real-time insights, only end-of-hour snapshots
```

### Trade-off 2: Sampling = Lower Cost

```
Current: Process all 50K events/sec

Sampled approach:
- Process 10% of events (5K events/sec)
- Apply sampling correction (multiply metrics by 10x)
- Cost reduction: ~90%
- Trade-off: Loss of accuracy for rare events
```

### Trade-off 3: Async Writes = Lower Cost

```
Current: Real-time updates to metrics table

Async approach:
- Batch write metrics every 5 minutes
- Buffer updates in staging table
- Bulk insert to metrics
- Cost reduction: ~30%
- Trade-off: Slight delay in metric availability
```

### Recommendation

> "For DoorDash, correctness > cost. We can't sample revenue metrics or delay them by 30 minutes. However, we optimize:
> 1. Query efficiency (cache, clustering, materialized views)
> 2. Retention policies (7 days raw, 30 days silver, 1 year gold)
> 3. Warehouse sizing (right-size per workload)
> 
> This gives us 50% cost savings without sacrificing SLA or correctness."

---

## 7️⃣ Budgeting & Alerts

### Monthly Cost Projection

```sql
-- Track actual vs projected costs
CREATE TABLE cost_projections (
  projection_date DATE,
  year INT,
  month INT,
  projected_cost FLOAT,
  actual_cost FLOAT,
  variance FLOAT
);

-- Daily cost tracking
CREATE DYNAMIC TABLE daily_cost_summary AS
SELECT
  DATE(start_time) AS cost_date,
  warehouse_name,
  SUM(credits_used_compute) AS compute_credits,
  SUM(credits_used_cloud_services) AS service_credits,
  (SUM(credits_used_compute) + SUM(credits_used_cloud_services)) * 10 AS cost_usd
FROM snowflake.account_usage.query_history
WHERE DATE(start_time) = CURRENT_DATE()
GROUP BY DATE(start_time), warehouse_name;

-- Monthly projection
CREATE OR REPLACE TASK PROJECT_MONTHLY_COST
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 0 * * * UTC'  -- Daily
AS
BEGIN
  LET days_elapsed := DAYOFMONTH(CURRENT_DATE());
  LET daily_avg := (
    SELECT AVG(cost_usd) FROM daily_cost_summary
    WHERE DATETRUNC('month', cost_date) = DATETRUNC('month', CURRENT_DATE())
  );
  
  LET projected_monthly := daily_avg * 30;
  
  -- Alert if on track to exceed budget ($100K/month)
  IF projected_monthly > 100000 THEN
    CALL alert_slack(f'💰 Projected monthly cost: ${projected_monthly:,.2f} - exceeds budget');
  END IF;
  
  INSERT INTO cost_projections (projection_date, year, month, projected_cost)
  VALUES (CURRENT_DATE(), YEAR(CURRENT_DATE()), MONTH(CURRENT_DATE()), projected_monthly);
END;
```

### Cost Breakdown by Workload

```sql
-- Understand where money is being spent
CREATE DYNAMIC TABLE cost_by_warehouse AS
SELECT
  warehouse_name,
  COUNT(*) AS query_count,
  AVG(total_elapsed_time / 1000) AS avg_query_sec,
  SUM(credits_used_compute) AS total_credits,
  SUM(credits_used_compute) * 10 AS cost_usd
FROM snowflake.account_usage.query_history
WHERE DATE(start_time) = CURRENT_DATE()
GROUP BY warehouse_name
ORDER BY total_credits DESC;

-- Example output:
/*
warehouse_name       query_count  avg_query_sec  total_credits  cost_usd
metrics_wh           1200         15             450            4500
ingestion_wh         2800         2              200            2000
analytics_wh         350          45             150            1500
ml_wh                50           300            120            1200
*/

-- Use this to identify optimization opportunities
```

---

## Interview Talking Points

### On Cost

✅ **"We optimize for cost without sacrificing correctness by:**
- **Right-sizing warehouses** (separate compute for different workloads)
- **Query optimization** (efficient clustering, incremental refresh)
- **Retention policies** (7 days raw, 30 days silver)
- **Monitoring costs daily** (alert on budget overruns)

**Estimated cost: $71K/month, room to optimize to $31K with these techniques.**"

### On 10x Scaling

✅ **"At 10x volume:**
- **Compute scales** (warehouse size increase, auto-clustering)
- **Storage scales** (Snowflake handles it, ~10x cost increase)
- **Ingestion adapts** (Kafka partitions increase 10x)

**Cost increases ~68% for 10x volume (sub-linear due to economies of scale).**"

### On 100x Scaling

✅ **"At 100x volume, we add:**
- **Stream processing layer** (Kafka Streams/Flink for fan-out)
- **Multi-warehouse parallelism** (independent scaling)
- **Tiered storage** (S3 for 30-day, Glacier for archive)

**Cost increases ~3.5x for 100x volume (economies of scale kick in).**"

### On Trade-offs

✅ **"We refuse to trade correctness for cost:**
- Can't sample revenue metrics (accuracy matters)
- Can't delay metrics (business decisions depend on real-time)
- Can delay non-critical metrics (e.g., UX metrics can be hourly)

**We optimize infrastructure, not core logic.**"

---

## Cost Optimization Checklist

Before going into interview, verify:

- [ ] Understand Snowflake pricing model (compute, storage, transfer)
- [ ] Calculate baseline cost for given event volume
- [ ] Identify top 3 cost optimizations (query opt, right-size, retention)
- [ ] Explain how costs scale at 10x, 100x volume
- [ ] Describe trade-offs (cost vs. correctness, latency, availability)
- [ ] Have concrete numbers ready ($71K/month, 56% optimization, etc.)
- [ ] Discuss cost monitoring & alerting

---

**Good luck! 💰🚀**
