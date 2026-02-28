# DoorDash Metrics Platform - Expected Follow-up Questions

## Overview

After presenting the design, interviewers will probe deeper. This document covers the most common follow-up questions with detailed answers.

---

## 1️⃣ Data Consistency Questions

### Q1: "How do you guarantee exactly-once delivery?"

**Context:** Events might be sent multiple times; you need to prevent double-counting.

**Answer:**

> "We use idempotent event publishing:
> 
> 1. **App generates event_id**: UUID generated at event creation time (not send time)
> 2. **Kafka preserves event_id**: Used as the message key for partitioning
> 3. **Deduplication in Snowflake**: Snowpipe ingests all events (duplicates included) into a landing table. A task runs every minute, deduplicating by event_id before merging into RAW_APP_EVENTS.
> 
> **Why exactly-once?**
> - Event created once (event_id is immutable)
> - Stored once (deduplication task uses INSERT ... WHERE NOT EXISTS)
> - Query result: COUNT(DISTINCT event_id) = actual event count
> 
> **Trade-off:** We accept duplicates in transit (Kafka → Snowpipe) but remove them before they reach analytics. This is simpler than at-least-once semantics in streaming."

**Follow-up handling:**
- If asked about Kafka semantics: "Kafka guarantees at-least-once per broker, but event_id makes it idempotent"
- If asked about cost: "Deduplication task runs once per minute, costs ~$200/month"
- If asked about latency impact: "Adds 1-2 minute lag, which is acceptable for our SLA"

---

### Q2: "What about out-of-order events?"

**Context:** Events arrive late, but metrics for older time windows already computed.

**Answer:**

> "We handle late arrivals through Dynamic Tables with TARGET_LAG:
> 
> 1. **Dynamic Table Definition**:
> ```sql
> CREATE DYNAMIC TABLE METRICS_DAU AS
> SELECT DATE(event_timestamp) AS metric_date, ...
> FROM FILTERED_EVENTS
> WHERE event_timestamp >= DATEADD(day, -1, CURRENT_DATE())
> GROUP BY metric_date
> TARGET_LAG = '2 minutes';
> ```
> 
> 2. **How it works:**
>    - Every 2 minutes, checks if new events arrived
>    - If an event arrives for 'yesterday', metric for yesterday is recomputed
>    - Automatic correction, no manual intervention
> 
> 3. **Example timeline:**
>    - 10:00 AM: User opens app (event_timestamp)
>    - 10:05 AM: Event arrives, metric computed
>    - 10:02 AM → 10:04 AM: Late event arrives (network delay)
>    - 10:06 AM: Dynamic table detects new data for 10 AM, recomputes automatically
> 
> 4. **Monitoring**:
> ```sql
> SELECT
>   DATE(event_timestamp) AS event_date,
>   COUNT(*) AS total_events,
>   COUNT(*) FILTER (WHERE DATEDIFF('minute', event_timestamp, ingestion_timestamp) > 5) AS late_events
> FROM raw_app_events
> GROUP BY DATE(event_timestamp)
> ORDER BY event_date DESC;
> ```
> 
> If late arrival % is high (>5%), we increase TARGET_LAG."

**Follow-up handling:**
- If asked about metrics correctness: "Metrics are eventually consistent. They're accurate after TARGET_LAG window closes."
- If asked about SLA: "SLA is 2 minutes from event_timestamp, not ingestion_timestamp"
- If asked about 1-hour old events arriving: "Handled transparently; metric recomputed if it's still within retention window"

---

### Q3: "How do you detect and handle data quality issues?"

**Context:** Subtle bugs in transformation logic cause wrong metrics.

**Answer:**

> "We have a multi-layered data quality framework:
> 
> **Layer 1: Validation at Ingestion (Raw Layer)**
> ```sql
> CREATE OR REPLACE TASK VALIDATE_RAW_EVENTS
>   WAREHOUSE = validation_wh
>   SCHEDULE = 'USING CRON */10 * * * * UTC'
> AS
> BEGIN
>   -- Check for required fields
>   LET null_events := (
>     SELECT COUNT(*) FROM raw_app_events
>     WHERE DATE(ingestion_timestamp) = CURRENT_DATE()
>       AND (event_id IS NULL OR event_type IS NULL OR user_id IS NULL)
>   );
>   
>   IF null_events > 100 THEN
>     CALL alert_pagerduty(f'🚨 High NULL count: {null_events}');
>   END IF;
> END;
> ```
> 
> **Layer 2: Volume Anomaly Detection (Silver Layer)**
> ```sql
> -- Day-over-day comparison
> WITH today AS (
>   SELECT event_type, COUNT(*) as count FROM filtered_events
>   WHERE DATE(processed_timestamp) = CURRENT_DATE()
>   GROUP BY event_type
> ),
> yesterday AS (
>   SELECT event_type, COUNT(*) as count FROM filtered_events
>   WHERE DATE(processed_timestamp) = CURRENT_DATE() - 1
>   GROUP BY event_type
> )
> SELECT
>   t.event_type,
>   t.count as today_count,
>   y.count as yesterday_count,
>   ABS((t.count - y.count) * 100.0 / y.count) as pct_change
> FROM today t
> JOIN yesterday y ON t.event_type = y.event_type
> WHERE ABS((t.count - y.count) * 100.0 / y.count) > 50  -- >50% change
> ORDER BY pct_change DESC;
> ```
> 
> **Layer 3: Metric Validation (Gold Layer)**
> ```sql
> -- Sanity checks on final metrics
> SELECT
>   metric_date,
>   city_id,
>   dau,
>   -- Sanity: DAU should be 100-500K per city per day
>   CASE WHEN dau < 100 OR dau > 500000 THEN 'ANOMALY' ELSE 'OK' END as dau_status,
>   -- Sanity: DAU shouldn't drop >50% vs previous day
>   CASE WHEN dau < LAG(dau) OVER (PARTITION BY city_id ORDER BY metric_date) * 0.5 
>        THEN 'ANOMALY' ELSE 'OK' END as trend_status
> FROM metrics_dau
> WHERE metric_date >= CURRENT_DATE() - 7;
> ```
> 
> **Layer 4: Alert & Pause Pipeline**
> If any validation fails:
> 1. Alert on-call engineer (Slack + PagerDuty)
> 2. Pause downstream metrics tasks automatically
> 3. Don't propagate incorrect metrics to BI tools
> 4. Engineer investigates, fixes logic, manually resumes"

**Follow-up handling:**
- If asked about false positives: "We tune thresholds based on historical variance. Alert only if >3 sigma."
- If asked about silent bugs: "Some slip through (e.g., subtle logic error), but caught during BI team review"
- If asked about recovery: "Fix the transform logic, rerun the failed task for the affected time window"

---

## 2️⃣ Architecture Questions

### Q4: "Why Snowflake over Redshift/BigQuery?"

**Context:** Interviewers test if you've considered alternatives.

**Answer:**

> "Great question. The three main options:
> 
> | Feature | Snowflake | Redshift | BigQuery |
> |---------|-----------|----------|----------|
> | **Ease of use** | ✅ SQL + Python in notebooks | ⚠️ Complex clusters | ✅ Simple API |
> | **Scaling** | ✅ Auto-scale, no provisioning | ❌ Manual provisioning | ✅ Auto-scale |
> | **Pricing** | ✅ Pay per second (no idle cost) | ❌ Pay per hour (wasteful) | ⚠️ Per TB scanned |
> | **Dynamic Tables** | ✅ Native support | ❌ Manual orchestration | ⚠️ Via dbt, not native |
> | **Streaming** | ✅ Snowpipe Streaming | ❌ Not designed for streaming | ⚠️ BigQuery Streaming (batches) |
> | **Disaster Recovery** | ✅ Failover Groups | ❌ Complex manual setup | ✅ Multi-region replication |
> | **PII Masking** | ✅ Native masking policies | ❌ Not native | ⚠️ Via BigQuery ML |
> 
> **For DoorDash metrics specifically:**
> - Need 1-2 min latency → Snowpipe Streaming best-in-class
> - Need incremental refresh → Dynamic Tables avoid full table rescans
> - Need audit trail → Snowflake account_usage tables are gold standard
> - Need multi-tenancy → Masking policies are native and policy-based
> 
> **Trade-off we accept:**
> - Vendor lock-in (but buy us engineering velocity)
> - Higher cost than BigQuery for scan-based (but more predictable)
> - Larger team learning curve (but worth it)
> 
> **If I had to change:** Would only consider if we needed multi-cloud failover. But most companies don't need that."

**Follow-up handling:**
- If asked about cost comparison: "Snowflake ~$850K/yr vs BigQuery ~$950K/yr at our scale (Snowflake wins due to caching)"
- If asked about RedShift: "Redshift is legacy, slower adoption of new features"
- If asked about open source: "Apache Iceberg doesn't replace Snowflake; it's just storage format"

---

### Q5: "Why not use a simpler architecture like just S3 + Spark?"

**Context:** Testing if you're over-engineering.

**Answer:**

> "Valid concern. Simple approach would be:
> 
> S3 + Spark ETL:
> - Event files land in S3 from Kafka
> - Daily Spark job: transform + aggregate
> - Result: CSV in S3
> - Cost: ~$20K/year for compute + storage
> 
> **Why we don't do this:**
> 
> 1. **SLA:** Daily batch doesn't meet 1-2 min requirement for live dashboards
> 2. **Operational overhead:** Need Spark cluster orchestration (YARN, Airflow, etc.)
> 3. **Debugging:** Hard to rerun/debug transformations (blame is spread across many files)
> 4. **Schema evolution:** No native support for flexible schemas
> 5. **Late arrivals:** Have to rerun entire daily job if events arrive late
> 
> **When S3 + Spark makes sense:**
> - Batch analytics only (no real-time requirement)
> - High event volume but can tolerate delays
> - Team already has Spark expertise
> - Cost is critical
> 
> **For DoorDash**, speed-to-market and correctness are more important than raw cost."

**Follow-up handling:**
- If asked about cost-benefit: "We pay $850K/yr for velocity and correctness. Spark would save $20K but cost 10x in engineer time."
- If asked about when to switch: "If we were purely historical analytics (no real-time), Spark is better."

---

### Q6: "How do you handle schema changes in the app?"

**Context:** Apps release new features, event schemas change.

**Answer:**

> "Schema evolution happens naturally through our design:
> 
> **Scenario 1: New Field Added**
> ```
> v1 Event: { user_id, order_id, amount }
> v2 Event: { user_id, order_id, amount, tip_amount }
> ```
> 
> Our implementation:
> ```sql
> -- Bronze: VARIANT payload handles any schema
> CREATE TABLE raw_app_events (
>   event_id, event_type, event_version INT, payload VARIANT, ...
> );
> 
> -- App sends event_version = 2
> INSERT INTO raw_app_events VALUES
> ('e123', 'order_placed', 2, { 'amount': 45.99, 'tip_amount': 5.00 });
> 
> -- Silver: Version-aware transformation
> CREATE DYNAMIC TABLE filtered_events AS
> SELECT
>   event_id,
>   CASE
>     WHEN event_version = 1 THEN CAST(payload:amount AS FLOAT)
>     WHEN event_version >= 2 THEN CAST(payload:amount AS FLOAT) + COALESCE(CAST(payload:tip_amount AS FLOAT), 0)
>   END AS total_amount
> FROM raw_app_events;
> ```
> 
> **Scenario 2: Renamed Field**
> ```
> v1: { customer_id }
> v2: { user_id }  (same concept, different name)
> ```
> 
> ```sql
> CREATE DYNAMIC TABLE filtered_events AS
> SELECT
>   event_id,
>   COALESCE(payload:customer_id, payload:user_id) AS user_id
> FROM raw_app_events;
> ```
> 
> **Scenario 3: Breaking Change (Type Conversion)**
> ```
> v1: amount as STRING ('45.99')
> v2: amount as NUMERIC (45.99)
> ```
> 
> ```sql
> CREATE DYNAMIC TABLE filtered_events AS
> SELECT
>   event_id,
>   TRY_CAST(payload:amount AS FLOAT) AS amount  -- TRY_ doesn't fail on conversion error
> FROM raw_app_events;
> ```
> 
> **Key benefits:**
> - No migration downtime
> - Old + new versions coexist in same table
> - Transformation logic centralizes all version handling
> - Easy rollback (just change CASE logic)
> 
> **Trade-off:** VARIANT is less efficient than strong schemas, but for metrics data the cost is negligible."

**Follow-up handling:**
- If asked about Iceberg: "Iceberg is good for multi-engine access, but we're Snowflake-only. VARIANT is sufficient."
- If asked about versioning strategy: "Increment event_version on breaking changes. Non-breaking changes don't need versioning."

---

## 3️⃣ Operational Questions

### Q7: "How do you monitor SLA compliance?"

**Context:** 1-2 minute SLA is critical; how do you prove you're meeting it?

**Answer:**

> "SLA monitoring happens at multiple layers:
> 
> **Layer 1: Raw Data Freshness**
> ```sql
> CREATE DYNAMIC TABLE sla_raw_data_freshness AS
> SELECT
>   DATE_TRUNC('minute', CURRENT_TIMESTAMP()) AS check_time,
>   MAX(ingestion_timestamp) AS latest_ingestion,
>   DATEDIFF('second', MAX(ingestion_timestamp), CURRENT_TIMESTAMP()) AS lag_seconds,
>   CASE
>     WHEN DATEDIFF('second', MAX(ingestion_timestamp), CURRENT_TIMESTAMP()) <= 60 THEN 'PASS'
>     WHEN DATEDIFF('second', MAX(ingestion_timestamp), CURRENT_TIMESTAMP()) <= 120 THEN 'WARN'
>     ELSE 'FAIL'
>   END AS status
> FROM raw_app_events
> WHERE ingestion_timestamp > DATEADD(minute, -5, CURRENT_TIMESTAMP());
> ```
> 
> **Layer 2: Metrics Freshness**
> ```sql
> CREATE DYNAMIC TABLE sla_metrics_freshness AS
> SELECT
>   warehouse_name,
>   COUNT(*) as refresh_count,
>   AVG(DATEDIFF('second', max(computed_at), CURRENT_TIMESTAMP())) AS avg_lag_sec,
>   MAX(DATEDIFF('second', max(computed_at), CURRENT_TIMESTAMP())) AS max_lag_sec,
>   COUNT(CASE WHEN DATEDIFF('second', max(computed_at), CURRENT_TIMESTAMP()) <= 120 THEN 1 END) * 100.0 / COUNT(*) AS compliance_pct
> FROM metrics_dau
> GROUP BY warehouse_name;
> ```
> 
> **Layer 3: End-to-End SLA**
> ```sql
> -- From event creation to metric availability
> CREATE DYNAMIC TABLE sla_e2e AS
> SELECT
>   CURRENT_TIMESTAMP() AS check_time,
>   -- Latest event timestamp in raw table
>   (SELECT MAX(event_timestamp) FROM raw_app_events) AS latest_event_time,
>   -- Latest metric computed time
>   (SELECT MAX(computed_at) FROM metrics_dau) AS latest_metric_time,
>   DATEDIFF('second',
>     (SELECT MAX(event_timestamp) FROM raw_app_events),
>     CURRENT_TIMESTAMP()
>   ) AS e2e_lag_seconds,
>   CASE
>     WHEN DATEDIFF('second',
>       (SELECT MAX(event_timestamp) FROM raw_app_events),
>       CURRENT_TIMESTAMP()
>     ) <= 120 THEN 'PASS'
>     ELSE 'FAIL'
>   END AS sla_status;
> ```
> 
> **Alerting:**
> ```sql
> CREATE OR REPLACE TASK ALERT_SLA_BREACH
>   WAREHOUSE = alert_wh
>   SCHEDULE = 'USING CRON */1 * * * * UTC'
> AS
> BEGIN
>   IF (SELECT e2e_lag_seconds FROM sla_e2e ORDER BY check_time DESC LIMIT 1) > 120 THEN
>     CALL alert_pagerduty('🚨 P0: SLA breached - metrics delayed >2 min');
>   END IF;
> END;
> 
> -- Dashboard aggregation
> SELECT
>   DATE(check_time) as sla_date,
>   COUNT(CASE WHEN sla_status = 'PASS' THEN 1 END) * 100.0 / COUNT(*) AS daily_sla_compliance_pct
> FROM sla_e2e
> GROUP BY DATE(check_time)
> ORDER BY sla_date DESC;
> ```
> 
> **Weekly SLA Report:**
> - Target: 99.9% compliance (max 8.6 hours downtime per month)
> - Actual: Track separately
> - Report to stakeholders
> - Root cause analysis if <99.9%"

**Follow-up handling:**
- If asked about P50 vs P99: "We monitor both P50 (median ~30 sec) and P99 (tail ~2 min)"
- If asked about SLA window: "SLA is defined per business hours (9 AM - 11 PM) vs 24/7"
- If asked about SLA for different metrics: "Conversion metrics stricter SLA than revenue due to cost sensitivity"

---

### Q8: "How do you debug when something goes wrong?"

**Context:** Production incident at 2 AM; how do you investigate?

**Answer:**

> "Debugging framework (CRITICAL on-call skill):
> 
> **Step 1: Triage (First 5 minutes)**
> - Alert tells us what failed (e.g., 'SLA breached - metrics delayed >2 min')
> - Check which layer is affected:
>   - Raw data stale? → Kafka issue
>   - Silver data stale? → Snowpipe or transformation issue
>   - Gold metrics stale? → Warehouse or aggregation issue
> 
> ```sql
> -- Quick health check query
> SELECT
>   'raw' as layer,
>   MAX(ingestion_timestamp) as latest_time,
>   DATEDIFF('minute', MAX(ingestion_timestamp), CURRENT_TIMESTAMP()) as lag_min
> FROM raw_app_events
> UNION ALL
> SELECT 'silver', MAX(processed_timestamp), DATEDIFF('minute', MAX(processed_timestamp), CURRENT_TIMESTAMP())
> FROM filtered_events
> UNION ALL
> SELECT 'gold', MAX(computed_at), DATEDIFF('minute', MAX(computed_at), CURRENT_TIMESTAMP())
> FROM metrics_dau;
> ```
> 
> **Step 2: Check Specific Component**
> 
> **If Raw layer stale:**
> ```sql
> -- Check Snowpipe status
> SELECT * FROM snowflake.account_usage.pipe_usage_history
> WHERE pipe_catalog_name = 'app_events_pipe'
> ORDER BY load_timestamp DESC LIMIT 20;
> 
> -- If no successful COPY: Snowpipe is stuck
> -- Check warehouse status
> SELECT warehouse_name, state, running_queries, queued_queries
> FROM snowflake.account_usage.warehouse_metering_history
> WHERE warehouse_name = 'ingestion_wh' AND end_time > DATEADD(hour, -1, CURRENT_TIMESTAMP());
> 
> -- Check Kafka consumer lag
> -- (Via Confluent Control Center or CLI)
> kafka-console-consumer --bootstrap-server broker:9092 \
>   --topic app-events --group snowflake-sink \
>   --describe
> ```
> 
> **If Silver layer stale:**
> ```sql
> -- Check task status
> SELECT task_name, state, last_error_message, query_start_time
> FROM snowflake.account_usage.task_history
> WHERE task_name LIKE '%filter%'
> ORDER BY query_start_time DESC LIMIT 5;
> 
> -- If FAILED: Check error message and logs
> SELECT * FROM snowflake.account_usage.query_history
> WHERE query_id = (
>   SELECT last_query_id FROM snowflake.account_usage.task_history
>   WHERE task_name = 'filter_events' AND state = 'FAILED'
>   ORDER BY query_start_time DESC LIMIT 1
> );
> ```
> 
> **If Gold layer stale:**
> ```sql
> -- Check warehouse compute
> SELECT
>   warehouse_name,
>   provisioned_clusters,
>   running_clusters,
>   queued_load_percentage
> FROM snowflake.account_usage.warehouse_load_history
> WHERE warehouse_name = 'metrics_wh'
> ORDER BY end_time DESC LIMIT 10;
> 
> -- If queued_load_percentage is 100%, warehouse is overloaded
> -- Solution: Temporarily scale up warehouse
> ALTER WAREHOUSE metrics_wh SET WAREHOUSE_SIZE = 'X-LARGE';
> ```
> 
> **Step 3: Apply Quick Fix**
> - Raw stale: Restart Snowpipe or warehouse
> - Silver stale: Rerun failed task or fix query logic
> - Gold stale: Scale up warehouse
> 
> **Step 4: Root Cause**
> - After metrics resume, investigate why issue happened
> - Was it infrastructure (Kafka down), config (wrong warehouse size), or logic (bad query)?
> 
> **Step 5: Remediation**
> - Fix the root cause (code change, config update, capacity planning)
> - Deploy to production (or manual SQL fix if urgent)
> - Monitor for recurrence"

**Follow-up handling:**
- If asked about RTO: "Detection: 1-5 min. Investigation: 5-15 min. Fix: 5-30 min. Total RTO: 15-60 min"
- If asked about runbooks: "We maintain on-call runbooks for top 5 failure scenarios"
- If asked about escalation: "If warehouse restart doesn't help, escalate to Snowflake support"

---

## 4️⃣ Advanced Questions

### Q9: "How do you handle distributed transactions?"

**Context:** What if an order event needs to update user AND restaurant metrics atomically?

**Answer:**

> "Good question, but we DON'T use distributed transactions. Here's why:
> 
> **The pattern we use:**
> 1. **Immutable raw events** (single source of truth)
> 2. **Independent transformations** (no cross-table dependencies)
> 3. **Recomputable metrics** (can fix by re-running logic)
> 
> **Example: Order metrics**
> ```
> Event: order_placed (immutable in raw table)
>   ├─ Updates user_revenue (derived from raw)
>   ├─ Updates restaurant_revenue (derived from raw)
>   └─ Updates city_metrics (derived from raw)
> 
> No coordination needed! Each is computed independently.
> ```
> 
> **If we had distributed transactions:**
> - Complexity explodes (2PC, consensus, rollback logic)
> - Latency increases (wait for multiple confirmations)
> - Failure recovery is hard (orphaned state)
> - Snowflake doesn't natively support this
> 
> **When would you use distributed transactions?**
> - Multi-database consistency (e.g., update both PostgreSQL and Cassandra atomically)
> - Not applicable here since we're single Snowflake warehouse
> 
> **If we needed cross-service consistency:**
> We'd use event sourcing pattern:
> 1. Publish event to Kafka
> 2. Each service consumes and updates independently
> 3. Handle eventual consistency (accept temporary divergence)
> 4. Reconciliation jobs find and fix inconsistencies"

**Follow-up handling:**
- If asked about consistency models: "We use eventual consistency. Metrics correct within 2 minutes."
- If asked about financial correctness: "Revenue metrics are derived from immutable events, so accurate"

---

### Q10: "How would you add real-time alerting (e.g., spike detection)?"

**Context:** DoorDash wants to detect anomalies within 10 seconds.

**Answer:**

> "Current 2-minute SLA is too slow for this. Here's how we'd enhance:
> 
> **Option 1: Stream Processing Layer (Kafka Streams)**
> ```
> Kafka Topic (50K events/sec)
>   ↓
> Kafka Streams (Real-time aggregations)
>   ├─ Tumbling window (10 sec): COUNT events by city, platform
>   └─ Alerting: If count > threshold, fire alert immediately
>       ↓
> Alert (via Kafka topic → Email/Slack)
> 
> Latency: 10-20 seconds
> Cost: $50K/year (stream cluster)
> ```
> 
> **Implementation:**
> ```java
> // Kafka Streams topol ogy
> KStream<String, Event> events = builder.stream(\"app-events\");
> 
> events
>   .map((k, v) -> new KeyValue<>(v.getCity(), v))
>   .groupByKey()
>   .windowedBy(TimeWindows.of(Duration.ofSeconds(10)))
>   .count()
>   .toStream()
>   .filter((k, count) -> count > THRESHOLD)  // e.g., > 10K events
>   .peek((k, count) -> {
>     alerting.fire(k, count);
>   });
> ```
> 
> **Option 2: Hybrid Approach (Stream + Snowflake)**
> - Use Kafka Streams for 10-20 sec alerts (high signal, low latency)
> - Use Snowflake for deeper analysis (1-2 min, higher accuracy)
> 
> **Option 3: Machine Learning (Advanced)**
> ```
> 1. Train ML model on historical metrics
> 2. Deploy model to stream processing layer
> 3. Real-time prediction of expected metric value
> 4. Alert if actual >> predicted (e.g., revenue spike)
> 
> Benefits:
> - Catches subtle anomalies (not just threshold-based)
> - Seasonal adjustments (expected higher load on weekends)
> 
> Complexity: High (requires ML ops)
> ```
> 
> **My recommendation:**
> - Short term: Add Kafka Streams layer for simple thresholds
> - Long term: Build ML-based anomaly detection
> - Both feed into same alerting system (Slack/PagerDuty)"

**Follow-up handling:**
- If asked about false positives: "Use statistical tests (Z-score) to reduce false alerts"
- If asked about latency SLA: "Can achieve 10-20 sec with streaming, 1-2 min with Snowflake"

---

### Q11: "How do you handle data deletion requests (GDPR)?"

**Context:** User requests their data be deleted; it's immutable raw events.

**Answer:**

> "Data deletion is tricky with immutable raw data. Here's our strategy:
> 
> **Layer 1: Delete identifiable data (Silver/Gold)**
> ```sql
> -- Straightforward deletion (since silver/gold is derived)
> DELETE FROM filtered_events WHERE user_id = 'u123';
> DELETE FROM metrics_dau WHERE user_id = 'u123';  -- If stored (not recommended)
> ```
> 
> **Layer 2: Handle Raw Events (Tricky)**
> ```
> Option A: Soft Delete
> - Add 'is_deleted' flag to raw table
> - Filter out in Silver layer transformations
> - Keeps data intact for audit, hides from analytics
> 
> Option B: Hard Delete
> - DELETE FROM raw_app_events WHERE user_id = 'u123';
> - Irreversible (can't replay or debug)
> - Risk: Affects historical metrics
> 
> Option C: Anonymization (Recommended)
> - Hash user_id instead of deleting
> - Aggregate metrics still work (count of anonymous users)
> - No data loss, compliant with GDPR
> ```
> 
> **Implementation:**
> ```sql
> -- Soft delete approach (RECOMMENDED)
> ALTER TABLE raw_app_events ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
>
> CREATE OR REPLACE PROCEDURE delete_user_data(user_id STRING)
> RETURNS STRING
> AS
> $$
> BEGIN
>   -- Step 1: Soft delete raw events
>   UPDATE raw_app_events SET is_deleted = TRUE WHERE user_id = :user_id;
>   
>   -- Step 2: Delete from silver (will be filtered out automatically)
>   DELETE FROM filtered_events WHERE user_id = :user_id;
>   
>   -- Step 3: Delete from gold (if user-level metrics exist)
>   DELETE FROM metrics_user_level WHERE user_id = :user_id;
>   
>   -- Step 4: Log deletion for audit
>   INSERT INTO data_deletion_log (user_id, deleted_at, reason)
>   VALUES (:user_id, CURRENT_TIMESTAMP(), 'GDPR request');
>   
>   RETURN f'User {user_id} data deleted';
> END;
> $$;
> ```
> 
> **Impact Analysis:**
> - Raw events: Preserved but marked deleted (audit trail intact)
> - Silver events: Deleted (transformation layer filters out)
> - Gold metrics: NOT affected (aggregates don't contain PII)
>   - DAU still counts (uses COUNT DISTINCT)
>   - Revenue still correct (no user_id in aggregation)
> 
> **GDPR Compliance:**
> ✅ PII removed (filtered in transformations)
> ✅ Audit trail preserved (soft delete logged)
> ✅ Analytics preserved (metrics unchanged)
> ✅ Retroactive (can delete old events)"

**Follow-up handling:**
- If asked about data portability: "Export user's events from raw table via Data Export API"
- If asked about audit logging: "Track who deleted what and when in data_deletion_log table"

---

### Q12: "How would you add machine learning features (e.g., churn prediction)?"

**Context:** ML team wants historical features for training.

**Answer:**

> "ML feature store integration:
> 
> **Architecture:**
> ```
> Snowflake (Silver/Gold tables)
>   ↓
> Feature Engineering (SQL in Snowflake Notebooks)
>   ↓
> Feature Store (e.g., Tecton, Feast, Databricks)
>   ↓
> Model Training (scikit-learn, XGBoost)
>   ↓
> Model Serving (REST API, Batch scoring)
> ```
> 
> **Example: Churn Prediction Features**
> ```sql
> -- Feature table (created in Snowflake)
> CREATE DYNAMIC TABLE user_churn_features AS
> SELECT
>   user_id,
>   DATE(event_timestamp) AS feature_date,
>   -- Activity features
>   COUNT(*) FILTER (WHERE event_type = 'order_placed') AS orders_7d,
>   COUNT(DISTINCT DATE(event_timestamp)) AS active_days_7d,
>   AVG(CAST(payload:total_amount AS FLOAT)) AS avg_order_value_7d,
>   -- Trend features
>   LAG(COUNT(*)) OVER (PARTITION BY user_id ORDER BY DATE(event_timestamp)) AS orders_prev_day,
>   -- Engagement features
>   COUNT(*) FILTER (WHERE event_type = 'app_opened') AS opens_7d,
>   COUNT(*) FILTER (WHERE event_type = 'search_completed') AS searches_7d,
>   -- Target variable (for training)
>   MAX(CASE WHEN DATE(event_timestamp) > DATEADD(day, 7, feature_date) 
>            AND event_type = 'order_placed' THEN 1 ELSE 0 END) AS churned_7d_future
> FROM filtered_events
> WHERE DATE(event_timestamp) >= DATEADD(day, -90, CURRENT_DATE())
> GROUP BY user_id, DATE(event_timestamp);
> ```
> 
> **Point-in-Time Correctness (Critical for ML):**
> ```sql
> -- Get features as of a specific date (for training without leakage)
> SELECT
>   user_id,
>   feature_date,
>   orders_7d,
>   avg_order_value_7d,
>   churned_7d_future AS label
> FROM user_churn_features
> WHERE feature_date BETWEEN '2025-01-01' AND '2025-12-31'  -- Training window
>   AND feature_date < DATEADD(day, -7, CURRENT_DATE());  -- Avoid future data leakage
> ```
> 
> **Integration with Feast:**
> ```python
> # Register features in Feast
> @entity_df_event_timestamp_col = 'event_timestamp'
> @client
> def get_churn_features(entity_df: pd.DataFrame, features: List[str]):
>     feast_features = client.get_historical_features(
>         entity_df=entity_df,
>         features=features,
>         full_feature_names=True
>     )
>     return feast_features.to_df()
> ```
> 
> **Batch Scoring (Daily):**
> ```sql
> -- Compute churn probability daily
> INSERT INTO churn_predictions (user_id, churn_probability, prediction_date)
> SELECT
>   user_id,
>   ml_model.predict(user_churn_features) AS churn_probability,
>   CURRENT_DATE()
> FROM user_churn_features
> WHERE feature_date = CURRENT_DATE() - 1;
> 
> -- Alert if high churn probability (for retention campaigns)
> SELECT user_id FROM churn_predictions
> WHERE churn_probability > 0.7
>   AND prediction_date = CURRENT_DATE();
> ```
> 
> **Key Requirements:**
> - Point-in-time correctness (no future data leakage)
> - Versioning (track which feature set trained which model)
> - Monitoring (model performance degradation alerts)
> - Latency (scoring happens nightly, <1 hr)"

**Follow-up handling:**
- If asked about real-time scoring: "Batch is 1 day old, but often sufficient. Real-time would add stream processing layer."
- If asked about feature drift: "Monitor feature distributions; alert if mean/std changes >10%"

---

## Summary: Interview Success Checklist

✅ **Nail These Talking Points:**
- Exactly-once delivery (event_id deduplication)
- Late arrival handling (Dynamic Tables + TARGET_LAG)
- Data quality validation (multi-layer checks)
- SLA monitoring (end-to-end freshness)
- Debugging methodology (triage → investigate → fix)
- Cost optimization (56% reduction possible)
- Scaling strategy (10x, 100x volumes)

✅ **Admit Trade-offs:**
- Vendor lock-in (worth it for Snowflake features)
- Not sub-second latency (1-2 min SLA is reasonable)
- Compute cost (necessary for correctness and speed)
- Operational complexity (worth it for scale)

✅ **Show Humility:**
- "I haven't seen this exact scenario, but here's how I'd approach it..."
- "That's a trade-off between cost and correctness..."
- "We'd need to discuss with the team if..."

---

**Good luck in your interview! You've got this! 🚀**
