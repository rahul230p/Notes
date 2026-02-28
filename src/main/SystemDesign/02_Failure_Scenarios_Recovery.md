# DoorDash Metrics Platform - Failure Scenarios & Recovery

## Overview

This document covers **real-world failure modes** you'll face in production and how to handle them. Interviewers love this because it shows operational maturity.

---

## 1️⃣ Producer (App) Failures

### Scenario 1.1: App Event Publishing Fails

**What happens:**
- Mobile app tries to send event → HTTP POST to backend
- Network timeout / backend service down
- Event is lost

**Impact:**
- DAU/MAU metrics drop artificially
- Conversion rates appear lower
- Real-time dashboards show gaps

**Solution: Async Publishing with Retry**

```python
# Producer-side (App Backend)
import queue
import time
from typing import Dict

class EventProducer:
    def __init__(self, kafka_brokers: list, max_retries=3):
        self.kafka_brokers = kafka_brokers
        self.max_retries = max_retries
        self.retry_queue = queue.Queue()
        self.start_retry_worker()
    
    def publish_event(self, event: Dict) -> bool:
        """
        Non-blocking event publish
        Returns immediately; retries happen in background
        """
        try:
            self.kafka_producer.send_and_forget(
                topic='app-events',
                value=event,
                key=event.get('user_id')  # Partition by user for ordering
            )
            return True
        except Exception as e:
            # Don't fail user-facing request; queue for retry
            self.retry_queue.put((event, 0))  # (event, retry_count)
            return False
    
    def start_retry_worker(self):
        """Background thread retries failed events"""
        def retry_worker():
            while True:
                try:
                    event, attempt = self.retry_queue.get(timeout=5)
                    if attempt >= self.max_retries:
                        # Give up after 3 retries
                        self._log_failed_event(event)
                        continue
                    
                    # Exponential backoff
                    wait_time = 2 ** attempt
                    time.sleep(wait_time)
                    
                    # Retry
                    self.kafka_producer.send_and_forget(
                        topic='app-events',
                        value=event,
                        key=event.get('user_id')
                    )
                except queue.Empty:
                    continue
        
        thread = Thread(target=retry_worker, daemon=True)
        thread.start()
```

**Key Design Principles:**
- ✅ Non-blocking (async)
- ✅ Automatic retries
- ✅ No user-facing impact
- ✅ Exponential backoff (don't hammer broker)
- ✅ Eventual consistency

📌 **Interview Answer:**
> "App events are published asynchronously to Kafka. If publishing fails, the event goes into a local retry queue with exponential backoff (2^n seconds). After 3 retries, it's logged but doesn't block the user. This ensures event collection never impacts app performance."

---

### Scenario 1.2: Event Deduplication (Duplicate Sends)

**What happens:**
- Network timeout → app retries → event sent twice
- User sees duplicate event in metrics
- Orders counted twice

**Impact:**
- DAU inflation
- Revenue metrics artificially inflated
- BI team creates wrong business decisions

**Solution: Idempotent Event Publishing**

```python
# Producer generates event_id on app
event = {
    'event_id': str(uuid4()),  # Unique per event instance
    'event_type': 'order_placed',
    'user_id': 'u123',
    'order_id': 'o456',
    'timestamp': time.time(),
    'payload': {...}
}

# Send to Kafka with event_id as key
kafka_producer.send(
    topic='app-events',
    key=event['event_id'],  # Idempotent key
    value=event
)
```

**Deduplication in Snowflake:**

```sql
-- Landing zone accepts all events
CREATE TABLE RAW_APP_EVENTS_LANDING (
  event_id STRING,
  event_type STRING,
  ...
  _ingestion_time TIMESTAMP
);

-- Task deduplicates and merges into main table
CREATE OR REPLACE TASK DEDUPLICATE_EVENTS
  WAREHOUSE = 'ingestion_wh'
  SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every minute
AS
BEGIN
  -- Insert only new events (by event_id)
  INSERT INTO RAW_APP_EVENTS (event_id, event_type, ...)
  SELECT event_id, event_type, ...
  FROM RAW_APP_EVENTS_LANDING L
  WHERE NOT EXISTS (
    SELECT 1 FROM RAW_APP_EVENTS R 
    WHERE R.event_id = L.event_id
  );
  
  -- Clean up landing zone
  DELETE FROM RAW_APP_EVENTS_LANDING
  WHERE _ingestion_time < DATEADD(hour, -1, CURRENT_TIMESTAMP());
END;
```

📌 **Interview Answer:**
> "Events are assigned a unique event_id by the app at creation time. Snowpipe ingests all events (including duplicates) into a landing table. A task runs every minute, deduplicating by event_id before merging into the main RAW_APP_EVENTS table. This is idempotent: re-running the deduplication task produces the same result."

---

## 2️⃣ Kafka Failures

### Scenario 2.1: Kafka Broker Failure

**What happens:**
- One Kafka broker crashes (server hardware failure)
- Leadership election happens
- Clients auto-reconnect

**Impact:**
- 30-60 second latency spike
- No data loss (replicated 3x)
- Automatic recovery

**Solution: Multi-AZ Deployment + Replication**

```yaml
# Kafka Cluster Configuration
brokers: 5 nodes (across 3 AZs)
replication_factor: 3
min_in_sync_replicas: 2

# Topic configuration for durability
topic:
  name: app-events
  partitions: 100
  replication_factor: 3
  config:
    min.insync.replicas: 2  # Wait for 2 replicas before ack
    retention.ms: 604800000  # 7 days
    compression.type: snappy
```

**Behavior:**
```
Broker-1 (Leader)           Broker-2 (Replica)       Broker-3 (Replica)
     ↓ CRASHES                    ↓                           ↓
  [DOWN]             Broker-2 becomes leader (auto-election)
                           ↓
                    Clients reconnect
                    Leadership stable in <30 sec
     
Data:
- All 100 copies safely in ISR (In-Sync Replicas)
- Zero data loss
- Client latency: 30-60 sec spike only
```

📌 **Interview Answer:**
> "Kafka runs on 5 brokers across 3 availability zones with replication factor 3. When a broker fails, Zookeeper automatically elects a new leader within 30 seconds. Clients auto-retry and reconnect. No data is lost because each message is replicated to 2 other brokers."

---

### Scenario 2.2: Kafka Partition Lag (Backlog)

**What happens:**
- Event volume spike (e.g., weekend, promotion)
- 100K events/sec suddenly becomes 1M events/sec
- Kafka buffers events, but processing can't keep up
- Consumer lag grows to 10+ minutes

**Impact:**
- Metrics dashboard shows old data
- Real-time alerts delayed
- No data loss (just backlog)

**Solution: Auto-scaling Consumer + Kafka Scaling**

```python
# Kafka Consumer with lag monitoring
from kafka import KafkaConsumer
import time

consumer = KafkaConsumer(
    'app-events',
    bootstrap_servers=['broker1:9092', 'broker2:9092'],
    group_id='snowflake-sink-consumer',
    max_poll_records=10000,  # Batch larger for throughput
    fetch_max_bytes=52428800  # 50MB per fetch
)

def monitor_consumer_lag():
    """Monitor and alert on lag"""
    while True:
        for partition in consumer.partitions():
            # Check current position
            current_offset = consumer.position(partition)
            # Check end position (latest)
            end_offset = consumer.end_offsets([partition])[partition]
            lag = end_offset - current_offset
            
            if lag > 1_000_000:  # Threshold: 1M messages behind
                alert_slack(f"⚠️ Consumer lag high: {lag} messages")
            
        time.sleep(30)

# Auto-scale Snowflake warehouse if lag detected
def auto_scale_warehouse():
    """Increase warehouse size if Kafka lag is high"""
    current_lag = get_consumer_lag()
    if current_lag > 1_000_000:
        # Scale up to X-Large temporarily
        alter_warehouse('sink_wh', 'X-LARGE')
```

**Kafka-Side Scaling:**

```bash
# Increase partitions (non-disruptive)
kafka-topics --bootstrap-server localhost:9092 \
  --alter --topic app-events \
  --partitions 200  # Scale from 100 to 200

# Why:
# - More partitions = more parallelism
# - Each Snowpipe consumer can be assigned a partition
# - Throughput can increase linearly
```

📌 **Interview Answer:**
> "If Kafka lag grows, we scale up the Snowflake warehouse consuming the topic (increase from Large to X-Large). We also increase Kafka partitions online to allow more parallel consumers. The lag is temporary; both mechanisms catch up within minutes."

---

### Scenario 2.3: Network Partition (Split Brain)

**What happens:**
- Network fault splits cluster into 2 groups
- Group A: has 3 brokers (can elect leader)
- Group B: has 2 brokers (cannot elect leader)
- Producers can't reach either group reliably

**Impact:**
- Events may be lost if produced to Group B
- Messages in Group A are safe
- Chaos across system

**Solution: Proper Quorum Configuration**

```
Kafka Cluster: 5 brokers
Zookeeper Ensemble: 3 nodes

If network splits 3 vs 2:
- 3 node partition: CAN elect leader, can accept writes ✅
- 2 node partition: CANNOT elect leader, REJECTS writes ✅

Result: No dual-write scenario; one partition is unavailable
        but data is safe in the other
```

**Monitoring & Detection:**

```sql
-- Monitor partition leaders in Snowflake
CREATE OR REPLACE TASK MONITOR_KAFKA_HEALTH
  WAREHOUSE = 'ops_wh'
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  -- Check Kafka broker metrics (via JMX export)
  CREATE TEMP TABLE kafka_broker_status AS
  SELECT
    broker_id,
    is_leader,
    pending_replica_count,
    under_replicated_partitions,
    _check_time
  FROM kafka_jmx_metrics
  WHERE _check_time > DATEADD(minute, -1, CURRENT_TIMESTAMP());
  
  -- Alert if under-replicated partitions > 0
  LET under_rep := (
    SELECT MAX(under_replicated_partitions) 
    FROM kafka_broker_status
  );
  
  IF under_rep > 0 THEN
    CALL alert_pagerduty('🚨 Kafka split brain detected');
  END IF;
END;
```

📌 **Interview Answer:**
> "We use a 5-broker Kafka cluster with 3-node Zookeeper ensemble. In a network partition, the 3-node side can elect a leader; the 2-node side cannot. Producers connecting to the minority partition are rejected, preventing dual-writes and data loss. Monitoring alerts us if partitions become under-replicated."

---

## 3️⃣ Snowpipe Streaming Failures

### Scenario 3.1: Snowpipe Failure / Data Loss Fear

**What happens:**
- Snowpipe Streaming breaks
- Events queue up in Kafka
- No data reaching RAW_APP_EVENTS table

**Impact:**
- Metrics dashboard goes stale
- Real-time insights lost
- BI team gets old data

**Solution: Monitoring + Manual Intervention**

```sql
-- Monitor Snowpipe Streaming status
CREATE OR REPLACE TASK MONITOR_SNOWPIPE_LAG
  WAREHOUSE = 'ops_wh'
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  -- Check Snowpipe pipe status
  SELECT pipe_name, definition, notification_channel 
  FROM information_schema.pipes;
  
  -- Check recent pipe copy events
  SELECT 
    pipe_catalog_name,
    file_name,
    bytes_copied,
    status,
    error_code,
    load_timestamp
  FROM snowflake.account_usage.pipe_usage_history
  WHERE DATE(load_timestamp) = CURRENT_DATE()
  ORDER BY load_timestamp DESC
  LIMIT 100;
  
  -- Alert if no successful copies in last 5 minutes
  LET last_copy := (
    SELECT MAX(load_timestamp) 
    FROM snowflake.account_usage.pipe_usage_history
    WHERE status = 'LOADED'
  );
  
  IF last_copy < DATEADD(minute, -5, CURRENT_TIMESTAMP()) THEN
    CALL alert_slack('🚨 Snowpipe no activity for 5 mins - check logs');
  END IF;
END;
```

**Recovery Procedure:**

```sql
-- Step 1: Check Snowpipe logs
SELECT * FROM snowflake.account_usage.pipe_usage_history
WHERE pipe_catalog_name = 'app_events_pipe'
ORDER BY load_timestamp DESC LIMIT 10;

-- Step 2: Restart pipe (if stuck)
ALTER PIPE app_events_pipe REFRESH;

-- Step 3: Check if events are stuck in staging
SELECT COUNT(*) FROM @kafka_stage;

-- Step 4: Verify data landed
SELECT COUNT(*) FROM raw_app_events_landing
WHERE _ingestion_time > DATEADD(hour, -1, CURRENT_TIMESTAMP());

-- Step 5: If manual intervention needed, manually copy
COPY INTO raw_app_events_landing
FROM @kafka_stage/app-events/
FILE_FORMAT = (TYPE = JSON);
```

**Why No Data Loss:**

```
Timeline:
- 10:00 AM: Snowpipe breaks
- 10:00 - 10:15 AM: Events queue in Kafka (7-day retention)
- 10:15 AM: On-call engineer sees alert
- 10:20 AM: Engineer fixes root cause (e.g., restart warehouse)
- 10:21 AM: Snowpipe resumes → backfill catches up within 5 min

Result: No data loss; just 20 minute delay in metrics
```

📌 **Interview Answer:**
> "Kafka retains events for 7 days, so even if Snowpipe fails, data is safe in the queue. We monitor Snowpipe via system tables (snowflake.account_usage.pipe_usage_history). If no copies succeed in 5 minutes, we alert. Recovery involves restarting the pipe or warehouse, and backfill completes within minutes."

---

### Scenario 3.2: Duplicate Events from Snowpipe

**What happens:**
- Snowpipe micro-batch succeeds
- But status notification never reaches Snowflake
- Snowpipe re-sends same batch
- Duplicates in RAW_APP_EVENTS_LANDING

**Solution: Event ID Deduplication (Already covered in 1.2)**

```sql
-- Snowpipe config to prevent duplicates
CREATE OR REPLACE PIPE app_events_pipe
  AS
    COPY INTO raw_app_events_landing 
      (event_id, event_type, payload, _source_file, _ingestion_time)
    FROM (
      SELECT $1:event_id, $1:event_type, $1:payload, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @kafka_stage/app-events/
    )
    FILE_FORMAT = (TYPE = JSON, STRIP_OUTER_ARRAY = FALSE)
    ON_ERROR = CONTINUE;  -- Don't fail on bad records

-- Deduplication task handles the rest
CREATE OR REPLACE TASK deduplicate_events
  WAREHOUSE = ingestion_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  INSERT INTO raw_app_events
  SELECT * FROM raw_app_events_landing
  WHERE event_id NOT IN (SELECT event_id FROM raw_app_events)
  ON CONFLICT DO NOTHING;
END;
```

---

## 4️⃣ Snowflake Layer Failures

### Scenario 4.1: Warehouse Failure / Out of Memory

**What happens:**
- Large transformation query running
- Uses more memory than warehouse allocated
- Query fails with OOM error
- Dynamic table refresh fails

**Impact:**
- Metrics don't update
- SLA breach (no data for 2+ minutes)
- BI teams see stale dashboard

**Solution: Query Optimization + Auto-scaling**

```sql
-- BEFORE: Inefficient query causing OOM
CREATE DYNAMIC TABLE metrics_user_conversion AS
SELECT
  user_id,
  event_timestamp,
  event_type,
  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) AS event_sequence,
  -- This creates large intermediate dataset
  LAG(event_type) OVER (PARTITION BY user_id ORDER BY event_timestamp) AS prev_event_type
FROM filtered_events
WHERE event_timestamp > DATEADD(day, -30, CURRENT_DATE());

-- AFTER: Optimized query
CREATE DYNAMIC TABLE metrics_user_conversion AS
SELECT
  DATE(event_timestamp) AS conversion_date,
  COUNT(CASE WHEN event_type = 'order_placed' THEN 1 END) AS conversions,
  COUNT(DISTINCT user_id) AS unique_users,
  MAX(event_timestamp) AS last_update
FROM filtered_events
WHERE event_timestamp > DATEADD(day, -1, CURRENT_DATE())
GROUP BY DATE(event_timestamp)
TARGET_LAG = '2 minutes'
WAREHOUSE = 'metrics_wh';  -- Auto-scale warehouse

-- Profile the query
EXPLAIN SELECT * FROM metrics_user_conversion;

-- Check warehouse resource usage
SELECT
  query_id,
  warehouse_name,
  total_elapsed_time,
  compilation_time,
  execution_time,
  bytes_scanned,
  bytes_produced,
  credits_used
FROM snowflake.account_usage.query_history
WHERE query_type = 'SELECT'
ORDER BY total_elapsed_time DESC
LIMIT 10;
```

**Auto-scaling Configuration:**

```sql
-- Configure warehouse to scale automatically
ALTER WAREHOUSE metrics_wh SET
  MAX_CLUSTER_COUNT = 5
  SCALING_POLICY = 'ECONOMY'
  AUTO_SUSPEND = 600;

-- Monitoring alert if max clusters reached
CREATE OR REPLACE TASK ALERT_MAX_CLUSTERS
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  SELECT warehouse_name, active_cluster_count
  FROM snowflake.account_usage.warehouse_metering_history
  WHERE active_cluster_count = (
    SELECT MAX_CLUSTER_COUNT FROM warehouses WHERE warehouse_name = 'metrics_wh'
  )
  AND HOUR(end_time) = HOUR(CURRENT_TIMESTAMP());
  
  IF (SELECT COUNT(*) FROM RESULT_SCAN(LAST_QUERY_ID())) > 0 THEN
    CALL alert_slack('⚠️ Warehouse at max cluster count - may need bigger warehouse');
  END IF;
END;
```

📌 **Interview Answer:**
> "If a query runs out of memory, we first optimize the query (avoid window functions on large datasets, aggregate early). Then we auto-scale the warehouse: if it reaches max clusters, we increase the warehouse size (Large → X-Large). Monitoring alerts us if we're consistently hitting the limit, indicating we need a permanent size increase."

---

### Scenario 4.2: Concurrent Query Contention

**What happens:**
- 50 analysts run reports simultaneously
- Same warehouse handling all queries
- Each query is slower due to resource sharing
- Some queries timeout

**Impact:**
- BI team frustrated with slow dashboards
- Queries fail mid-day during peak usage
- End users see cached/stale data

**Solution: Warehouse Isolation + Query Queues**

```sql
-- Create separate warehouses per workload
CREATE WAREHOUSE analytics_wh
  WITH_SIZE = 'MEDIUM'
  MAX_CLUSTER_COUNT = 3
  AUTO_SUSPEND = 600
  COMMENT = 'For business analysts and dashboards';

CREATE WAREHOUSE ml_wh
  WITH_SIZE = 'X-LARGE'
  MAX_CLUSTER_COUNT = 1
  AUTO_SUSPEND = 1200
  COMMENT = 'For data scientists heavy lifting';

CREATE WAREHOUSE ingestion_wh
  WITH_SIZE = 'LARGE'
  MAX_CLUSTER_COUNT = 2
  AUTO_SUSPEND = 300
  COMMENT = 'For data pipeline tasks';

-- Route queries to appropriate warehouse
GRANT USAGE ON WAREHOUSE analytics_wh TO ROLE analyst_role;
GRANT USAGE ON WAREHOUSE ml_wh TO ROLE data_science_role;
GRANT USAGE ON WAREHOUSE ingestion_wh TO ROLE data_engineer_role;

-- In application connection strings
-- Analysts: USE WAREHOUSE analytics_wh;
-- Data scientists: USE WAREHOUSE ml_wh;

-- Monitor warehouse contention
CREATE OR REPLACE TASK MONITOR_WAREHOUSE_CONTENTION
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  SELECT
    warehouse_name,
    AVG(avg_query_queued_time / 1000) AS avg_queue_wait_sec,
    COUNT(*) AS query_count,
    MAX(total_elapsed_time / 1000) AS max_query_duration_sec
  FROM snowflake.account_usage.query_history
  WHERE start_time > DATEADD(minute, -60, CURRENT_TIMESTAMP())
  GROUP BY warehouse_name
  HAVING AVG(avg_query_queued_time) > 5000  -- Alert if >5 sec queue
  ORDER BY avg_query_queued_time DESC;
END;
```

📌 **Interview Answer:**
> "We isolate workloads into separate warehouses: analytics (for BI), ML (for data scientists), ingestion (for pipelines). This prevents contention. Each warehouse auto-scales independently. We monitor query queue times and alert if queuing exceeds 5 seconds, indicating we need to increase warehouse size."

---

### Scenario 4.3: Data Corruption in Silver Layer

**What happens:**
- Bug in Silver layer transformation
- Bad logic deployed
- Filters silently drop millions of events
- Metrics become incorrect

**Example:**
```sql
-- BUGGY CODE (released to production)
CREATE DYNAMIC TABLE filtered_events AS
SELECT * FROM raw_app_events
WHERE city_id IS NOT NULL  -- ← OOPS! Drops all events with NULL city
  AND event_timestamp > DATEADD(day, -7, CURRENT_DATE());

-- Result: 20% of events dropped, metrics wrong
```

**Impact:**
- DAU is 20% lower than reality
- Business makes decisions on false data
- Audit finds discrepancy weeks later

**Solution: Data Quality Checks + Automated Rollback**

```sql
-- Test the transformation
CREATE OR REPLACE TASK TEST_SILVER_TRANSFORMATION
  WAREHOUSE = dev_wh
  SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM
AS
BEGIN
  -- Sanity checks on new Silver layer
  LET raw_count := (SELECT COUNT(*) FROM raw_app_events 
                    WHERE event_timestamp > DATEADD(day, -1, CURRENT_DATE()));
  LET silver_count := (SELECT COUNT(*) FROM filtered_events 
                       WHERE event_timestamp > DATEADD(day, -1, CURRENT_DATE()));
  
  -- Silver count should be 90-100% of raw (allowing for PII filtering)
  IF silver_count < raw_count * 0.9 THEN
    -- Something filtered too much
    LET pct_filtered := ROUND(100.0 * (raw_count - silver_count) / raw_count, 2);
    CALL alert_slack(f'⚠️ Silver layer filtering {pct_filtered}% of events');
    CALL alert_slack('Pausing downstream tasks for investigation');
    
    -- Pause downstream metrics tasks
    ALTER TASK compute_metrics_dau SUSPEND;
    ALTER TASK compute_metrics_conversion SUSPEND;
  END IF;
  
  -- Check for unexpected NULLs
  LET null_user_ids := (SELECT COUNT(*) FROM filtered_events 
                        WHERE user_id IS NULL);
  IF null_user_ids > 1000 THEN
    CALL alert_slack('🚨 High NULL count in user_id - possible bug');
    ALTER TASK compute_metrics_dau SUSPEND;
  END IF;
END;

-- Rollback procedure (manual for now, could be automated)
ALTER DYNAMIC TABLE filtered_events SET AS
SELECT * FROM raw_app_events
WHERE event_timestamp > DATEADD(day, -7, CURRENT_DATE());
-- ✅ Fixed: Removed the buggy city_id filter

-- Re-run downstream tasks
ALTER TASK compute_metrics_dau RESUME;
ALTER TASK compute_metrics_conversion RESUME;
```

**Catch in Testing:**

```sql
-- Unit test for transformation logic
CREATE OR REPLACE TASK TEST_CITY_FILTER
  WAREHOUSE = dev_wh
AS
BEGIN
  -- Create test data with mixed city_id values
  CREATE TEMP TABLE test_raw_events AS
  SELECT
    'e1' AS event_id,
    'order_placed' AS event_type,
    'u1' AS user_id,
    'NYC' AS city_id,
    CURRENT_TIMESTAMP() AS event_timestamp
  UNION ALL
  SELECT 'e2', 'search', 'u2', NULL, CURRENT_TIMESTAMP()  -- NULL city
  UNION ALL
  SELECT 'e3', 'order_placed', 'u3', 'LA', CURRENT_TIMESTAMP();
  
  -- Apply transformation
  CREATE TEMP TABLE test_filtered AS
  SELECT * FROM test_raw_events
  WHERE city_id IS NOT NULL;  -- Buggy line
  
  -- Assert: All non-null cities should be present
  ASSERT (SELECT COUNT(*) FROM test_filtered) = 2
  ELSE RAISE 'Test failed: expected 2 rows, got count mismatch';
  
  ASSERT (SELECT COUNT(DISTINCT city_id) FROM test_filtered) = 2
  ELSE RAISE 'Test failed: expected 2 cities';
END;
```

📌 **Interview Answer:**
> "Data quality checks run daily: we verify Silver layer row counts are 90-100% of raw (accounting for PII masking), check for unexpected NULLs, and validate key metrics. If a check fails, we pause downstream metrics tasks immediately and alert. The engineer investigates, fixes the bug, and manually resumes tasks after verification."

---

### Scenario 4.4: Task Dependencies & Cascading Failures

**What happens:**
- Task A (Silver layer) succeeds
- Task B (Gold layer, depends on A) fails
- Task C (Alerts, depends on B) never runs
- Alerts aren't sent, issue goes undetected

**Example DAG:**
```
Raw Events
    ↓
Task: deduplicate_events (1 min)
    ↓
Task: filter_events → SILVER (1 min)
    ↓
Task: compute_metrics_dau → GOLD (2 min)
    ↓
Task: alert_on_anomalies (1 min)  ← If this fails, alerts don't send
```

**Solution: Explicit Error Handling**

```sql
-- Task B: Depends on Task A via AFTER clause
CREATE OR REPLACE TASK compute_metrics_dau
  WAREHOUSE = metrics_wh
  AFTER deduplicate_events
  SCHEDULE = 'USING CRON */1 * * * * UTC'
AS
BEGIN
  TRY
    INSERT INTO metrics_dau
    SELECT
      DATE(event_timestamp) AS metric_date,
      city_id,
      COUNT(DISTINCT user_id) AS dau
    FROM filtered_events
    WHERE event_timestamp >= DATEADD(day, -1, CURRENT_DATE())
    GROUP BY DATE(event_timestamp), city_id;
    
    CALL log_task_success('compute_metrics_dau');
  CATCH (e) =>
    CALL log_task_failure('compute_metrics_dau', e.message);
    CALL alert_pagerduty(f'❌ Task failed: compute_metrics_dau - {e.message}');
    RETHROW;  -- Let orchestration see the failure
  END;
END;

-- Task C: Alert task, independent of data pipeline failures
CREATE OR REPLACE TASK alert_on_anomalies
  WAREHOUSE = alert_wh
  SCHEDULE = 'USING CRON */5 * * * * UTC'  -- Every 5 minutes
AS
BEGIN
  -- Check if metrics are fresh
  LET latest_dau := (
    SELECT MAX(metric_date) FROM metrics_dau
  );
  
  IF latest_dau < DATEADD(minute, -10, CURRENT_TIMESTAMP()) THEN
    CALL alert_pagerduty('🚨 Metrics are stale - over 10 min old');
  END IF;
  
  -- Check for metric anomalies even if upstream task failed
  IF (SELECT COUNT(*) FROM metrics_dau WHERE dau = 0) > 1 THEN
    CALL alert_pagerduty('⚠️ Zero DAU detected for some cities');
  END IF;
END;

-- Monitoring task (meta-monitoring)
CREATE OR REPLACE TASK monitor_task_health
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  -- Check if tasks are failing repeatedly
  SELECT
    task_name,
    state,
    last_error_message,
    attempt_count,
    next_scheduled_time
  FROM snowflake.account_usage.task_history
  WHERE DATE(query_start_time) = CURRENT_DATE()
    AND state = 'FAILED'
    AND attempt_count > 3
  ORDER BY query_start_time DESC;
  
  -- If query returned rows, alert
  IF (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 0 THEN
    CALL alert_slack('🚨 Multiple tasks failing repeatedly - investigate NOW');
  END IF;
END;

-- Logging/notification functions
CREATE OR REPLACE PROCEDURE log_task_success(task_name STRING)
RETURNS STRING
AS
$$
  BEGIN
    INSERT INTO task_execution_log (task_name, status, execution_time)
    VALUES (task_name, 'SUCCESS', CURRENT_TIMESTAMP());
    RETURN f'{task_name} succeeded';
  END;
$$;

CREATE OR REPLACE PROCEDURE log_task_failure(task_name STRING, error_msg STRING)
RETURNS STRING
AS
$$
  BEGIN
    INSERT INTO task_execution_log (task_name, status, error_message, execution_time)
    VALUES (task_name, 'FAILED', error_msg, CURRENT_TIMESTAMP());
    RETURN f'{task_name} failed: {error_msg}';
  END;
$$;
```

**Task Dependency DAG:**

```sql
-- Query task graph to visualize
SELECT
  task_name,
  prerequisites,
  state,
  next_scheduled_time
FROM snowflake.account_usage.task_history
WHERE state = 'FAILED'
ORDER BY query_start_time DESC;

-- Visual representation
-- SUCCESS: raw → silver → gold → alerts
-- FAILURE: raw ✅ → silver ❌ → gold ⏸️ → alerts ⏸️
-- FIX: Investigate silver, rerun, all resume
```

📌 **Interview Answer:**
> "Tasks are explicitly DAG'd with AFTER clauses. Each task logs success/failure to a table. If an upstream task fails, downstream tasks don't run. A separate 'meta-monitoring' task checks if tasks are failing repeatedly and alerts. If a task fails, we investigate, fix the root cause (usually in the query logic), and rerun. The DAG naturally replays downstream."

---

## 5️⃣ Business Logic Failures

### Scenario 5.1: Wrong Metric Calculation (Silent Bug)

**What happens:**
- Metric definition is subtly wrong
- Calculation runs successfully
- BI dashboard shows wrong numbers
- Business makes wrong decisions

**Example:**
```sql
-- BUGGY: Double-counting orders
CREATE DYNAMIC TABLE metrics_revenue_daily AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  SUM(CAST(payload:total_amount AS FLOAT)) AS revenue
FROM filtered_events
WHERE event_type = 'order_placed'
GROUP BY DATE(event_timestamp), city_id;

-- Problem: If an order has multiple events (e.g., placed + confirmed),
-- it gets counted twice!

-- FIXED:
CREATE DYNAMIC TABLE metrics_revenue_daily AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  SUM(CAST(payload:total_amount AS FLOAT)) AS revenue
FROM filtered_events
WHERE event_type = 'order_placed'
  AND payload:status = 'confirmed'  -- Only count confirmed orders
GROUP BY DATE(event_timestamp), city_id;
```

**Solution: Metrics Validation Framework**

```sql
-- Define metrics with explicit definitions + tests
CREATE TABLE metrics_definitions (
  metric_id STRING,
  metric_name STRING,
  definition STRING,
  expected_range_min FLOAT,
  expected_range_max FLOAT,
  validation_query STRING
);

INSERT INTO metrics_definitions VALUES
(
  'revenue_daily',
  'Daily Revenue by City',
  'SUM(order amount) for confirmed orders only',
  0,  -- min: should be > 0
  999999999,  -- max: sanity check
  'SELECT SUM(amount) FROM metrics_revenue_daily WHERE metric_date = CURRENT_DATE() - 1'
);

-- Validation task
CREATE OR REPLACE TASK validate_metrics_daily
  WAREHOUSE = validation_wh
  SCHEDULE = 'USING CRON 0 1 * * * UTC'  -- 1 AM daily
AS
BEGIN
  FOR metric_row IN (
    SELECT metric_id, metric_name, validation_query, expected_range_min, expected_range_max
    FROM metrics_definitions
  ) DO
    LET metric_value := (EXECUTE metric_row.validation_query);
    
    IF metric_value < metric_row.expected_range_min 
       OR metric_value > metric_row.expected_range_max THEN
      CALL alert_slack(f'⚠️ Metric {metric_row.metric_name} out of range: {metric_value}');
    END IF;
  END FOR;
END;

-- Comparison with previous day
CREATE OR REPLACE TASK check_metric_anomalies
  WAREHOUSE = validation_wh
  SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- 2 AM daily
AS
BEGIN
  WITH current_day AS (
    SELECT metric_date, city_id, dau FROM metrics_dau 
    WHERE metric_date = CURRENT_DATE() - 1
  ),
  previous_day AS (
    SELECT metric_date, city_id, dau FROM metrics_dau 
    WHERE metric_date = CURRENT_DATE() - 8  -- Same day of week
  )
  SELECT
    c.city_id,
    c.dau AS current_dau,
    p.dau AS previous_dau,
    ROUND(100.0 * (c.dau - p.dau) / p.dau, 2) AS pct_change
  FROM current_day c
  JOIN previous_day p ON c.city_id = p.city_id
  WHERE ABS((c.dau - p.dau) / p.dau) > 0.5  -- >50% change
  ORDER BY ABS((c.dau - p.dau) / p.dau) DESC;
  
  -- If query returns rows, anomalies detected
  IF (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 0 THEN
    CALL alert_slack('🚨 Metric anomaly detected - check for data quality issues');
  END IF;
END;
```

📌 **Interview Answer:**
> "We define expected ranges for each metric and validate them daily. We also compare day-over-day metrics to detect anomalies (e.g., >50% change). If a metric is out of range or has anomalous change, we alert. This catches silent bugs early."

---

### Scenario 5.2: Late Arrival Events (Out-of-Order Data)

**What happens:**
- Event happens at 10:00 AM (event_timestamp)
- Event arrives at Kafka at 11:30 AM (ingestion_timestamp)
- Metric for 10 AM already computed
- Late event doesn't get counted

**Example:**
```
10:00 AM: User opens app (event_timestamp)
10:05 AM: Metric computed: DAU = 1000
10:05 AM: DAU metric frozen for 10 AM
10:30 AM: Late event arrives in Kafka (user's connection was slow)
10:35 AM: Event lands in Snowflake
Result: DAU for 10 AM is undercounted (off by 1)
```

**Impact:**
- Metrics are slightly wrong for historical data
- Over long term, accumulates to significant error
- BI reports show wrong numbers

**Solution: Dynamic Tables with Late Arrival Handling**

```sql
-- Dynamic tables automatically recompute when new data arrives
CREATE DYNAMIC TABLE metrics_dau AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city_id,
  COUNT(DISTINCT user_id) AS dau,
  COUNT(*) AS total_events,
  MAX(ingestion_timestamp) AS max_ingestion_time,
  CURRENT_TIMESTAMP() AS computed_at
FROM filtered_events
WHERE event_timestamp >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY DATE(event_timestamp), city_id
TARGET_LAG = '2 minutes';
-- TARGET_LAG = '2 minutes' means:
-- Every 2 minutes, check if new events arrived for any metric date
-- If yes, recompute that date's metrics

-- Why dynamic tables fix late arrivals:
-- - Traditional task (runs at fixed time): computes once, never updates
-- - Dynamic table (with TARGET_LAG): recomputes continuously until lag tolerance reached

-- Example: Event arrives 30 minutes late
-- 10:00 AM: Metric computed (TARGET_LAG = 2 min)
-- 10:02 AM: Target lag satisfied, metric "finalized"
-- 10:30 AM: Late event arrives
-- 10:32 AM: Dynamic table detects new data, recomputes metric automatically
-- Result: DAU corrected, no manual intervention needed
```

**Monitoring Late Arrivals:**

```sql
-- Track how much data arrives late
CREATE OR REPLACE TASK monitor_late_arrivals
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
AS
BEGIN
  SELECT
    DATE(event_timestamp) AS event_date,
    COUNT(*) AS total_events,
    COUNT(CASE 
      WHEN DATEDIFF('minute', event_timestamp, ingestion_timestamp) > 5 
      THEN 1 
    END) AS late_events_count,
    ROUND(100.0 * COUNT(CASE WHEN DATEDIFF('minute', event_timestamp, ingestion_timestamp) > 5 THEN 1 END) 
          / COUNT(*), 2) AS pct_late
  FROM raw_app_events
  WHERE DATE(event_timestamp) = CURRENT_DATE() - 1
  GROUP BY DATE(event_timestamp);
  
  -- If >5% late arrivals, increase TARGET_LAG
  IF (SELECT MAX(pct_late) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 5 THEN
    CALL alert_slack('⚠️ >5% late arrivals - may need to increase TARGET_LAG');
  END IF;
END;

-- Backfill metrics that had late arrivals
CREATE OR REPLACE TASK backfill_metrics_for_late_arrivals
  WAREHOUSE = metrics_wh
  SCHEDULE = 'USING CRON 0 3 * * * UTC'  -- 3 AM daily
AS
BEGIN
  -- Force refresh of yesterday's metrics (in case late events arrived)
  ALTER DYNAMIC TABLE metrics_dau REFRESH;
  ALTER DYNAMIC TABLE metrics_conversion_funnel REFRESH;
  
  CALL log_task_success('backfill_metrics_for_late_arrivals');
END;
```

📌 **Interview Answer:**
> "Dynamic tables automatically recompute when new data arrives, up to the TARGET_LAG. If an event arrives late (>2 min after event_timestamp), the metric is recomputed and corrected automatically. We monitor the % of late arrivals; if it exceeds 5%, we increase TARGET_LAG. Nightly, we backfill yesterday's metrics in case late events arrived."

---

## 6️⃣ Network & Infrastructure Failures

### Scenario 6.1: Snowflake Region Down (Disaster Recovery)

**What happens:**
- Snowflake US-East region becomes unavailable (rare but possible)
- All queries fail
- Metrics pipeline halts
- BI dashboards go dark

**Impact:**
- Business can't see live metrics
- RTO: 30 min - 2 hours
- RPO: Data in last checkpoint (5 min)

**Solution: Failover Groups (Business Critical Edition)**

```sql
-- Primary account: US-East
-- Secondary account: US-West (or multi-region)

-- Create failover group
CREATE FAILOVER GROUP metrics_failover_group
  OBJECT_TYPES = TABLES, TASKS, DYNAMIC TABLES, WAREHOUSES
  ALLOWED_ACCOUNTS = 'primary_account', 'secondary_account'
  REPLICATION_SCHEDULE = 'EVERY 5 MINUTES'
  ACCOUNT = 'primary_account';

-- Replicate every 5 min (RPO = 5 min)
-- Manual failover (RTO = manual intervention + DNS update)

-- Monitor replication lag
CREATE OR REPLACE TASK monitor_failover_lag
  WAREHOUSE = ops_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  SELECT
    object_name,
    object_type,
    created_on,
    last_refreshed_on,
    DATEDIFF('minute', last_refreshed_on, CURRENT_TIMESTAMP()) AS lag_minutes
  FROM snowflake.account_usage.replication_usage_history
  WHERE DATEDIFF('minute', last_refreshed_on, CURRENT_TIMESTAMP()) > 10
  ORDER BY lag_minutes DESC;
  
  IF (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 0 THEN
    CALL alert_pagerduty('⚠️ Replication lag >10 min - check Failover Group');
  END IF;
END;

-- Manual failover runbook
/*
FAILOVER RUNBOOK:
1. Detect: Query to primary fails consistently (>5 min)
2. Verify: Call AWS support to confirm region outage
3. Alert: Page on-call database team
4. Execute: 
   ALTER FAILOVER GROUP metrics_failover_group PRIMARY SUSPEND;
   -- Wait 5 min for replication to catch up
   ALTER FAILOVER GROUP metrics_failover_group 
     PRIMARY TO ACCOUNT 'secondary_account';
5. Update: DNS/connection strings point to secondary
6. Monitor: Verify metrics pipeline working in secondary
7. Communicate: Notify stakeholders, ETA for return to primary
*/
```

**Application-Side:**

```python
# Connection string with automatic failover
from snowflake.connector import connect

def get_snowflake_connection():
    """Try primary, fall back to secondary"""
    primary = {
        'account': 'primary_account',
        'region': 'us-east-1',
        'user': 'metrics_user',
        'password': os.getenv('SNOWFLAKE_PASSWORD')
    }
    
    secondary = {
        'account': 'secondary_account',
        'region': 'us-west-2',
        'user': 'metrics_user',
        'password': os.getenv('SNOWFLAKE_PASSWORD')
    }
    
    try:
        conn = connect(**primary)
        return conn
    except Exception as e:
        print(f"Primary failed: {e}")
        print("Failover to secondary...")
        return connect(**secondary)
```

📌 **Interview Answer:**
> "We use Snowflake Failover Groups to replicate data to a secondary region every 5 minutes (RPO = 5 min). In case of primary region outage, we manually trigger failover: suspend the primary, wait for replication lag to clear, then promote secondary. RTO is ~15-30 minutes (includes manual detection + DNS update)."

---

### Scenario 6.2: Network Latency / Intermittent Connectivity

**What happens:**
- Network between Kafka broker and Snowpipe gets slow
- Requests timeout
- Snowpipe retries
- Backlog grows temporarily

**Solution: Retry Logic + Exponential Backoff**

```sql
-- Already built into Snowflake!
-- Snowpipe Streaming automatically retries failed batches

-- Configuration
CREATE OR REPLACE PIPE app_events_pipe
  AS
    COPY INTO raw_app_events_landing
    FROM @kafka_stage
    FILE_FORMAT = (TYPE = JSON)
    COMMENT = 'Auto-retries on network error'
    ERROR_INTEGRATION = 'kafka_error_integration'  -- For error handling

-- Error integration handles retries:
-- 1st attempt: Immediate
-- 2nd attempt: 10 sec later
-- 3rd attempt: 60 sec later
-- 4th attempt: 5 min later
-- Then pause and alert
```

---

## 7️⃣ Monitoring & Alerting Strategy

### Comprehensive Alert System

```sql
-- Layer 1: Data Freshness
CREATE OR REPLACE TASK alert_data_staleness
  WAREHOUSE = alert_wh
  SCHEDULE = 'USING CRON */5 * * * * UTC'  -- Every 5 min
AS
BEGIN
  LET latest_raw := (SELECT MAX(ingestion_timestamp) FROM raw_app_events);
  LET latest_silver := (SELECT MAX(processed_timestamp) FROM filtered_events);
  LET latest_gold := (SELECT MAX(computed_at) FROM metrics_dau);
  
  -- Alert if raw data >5 min old
  IF latest_raw < DATEADD(minute, -5, CURRENT_TIMESTAMP()) THEN
    CALL alert_pagerduty('🚨 P1: Raw events stale - ingestion pipeline down');
  END IF;
  
  -- Alert if silver data >10 min old
  IF latest_silver < DATEADD(minute, -10, CURRENT_TIMESTAMP()) THEN
    CALL alert_pagerduty('⚠️ P2: Silver events stale - transformation slow');
  END IF;
  
  -- Alert if gold metrics >5 min old
  IF latest_gold < DATEADD(minute, -5, CURRENT_TIMESTAMP()) THEN
    CALL alert_pagerduty('⚠️ P2: Metrics stale - aggregation lagging');
  END IF;
END;

-- Layer 2: Data Quality
CREATE OR REPLACE TASK alert_data_quality_issues
  WAREHOUSE = alert_wh
  SCHEDULE = 'USING CRON */10 * * * * UTC'
AS
BEGIN
  -- Check for unusual event distributions
  LET null_rate := (
    SELECT COUNT(*) FILTER (WHERE user_id IS NULL) * 100.0 / COUNT(*)
    FROM filtered_events
    WHERE processed_timestamp > DATEADD(minute, -10, CURRENT_TIMESTAMP())
  );
  
  IF null_rate > 1.0 THEN  -- >1% NULLs is bad
    CALL alert_pagerduty(f'⚠️ High NULL rate in user_id: {null_rate}%');
  END IF;
  
  -- Check for volume anomalies
  LET current_volume := (
    SELECT COUNT(*) FROM raw_app_events
    WHERE ingestion_timestamp > DATEADD(minute, -1, CURRENT_TIMESTAMP())
  );
  
  LET expected_volume := (
    SELECT AVG(hourly_count) * 1.5 FROM (
      SELECT COUNT(*) AS hourly_count
      FROM raw_app_events
      WHERE ingestion_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
      GROUP BY DATE_TRUNC('hour', ingestion_timestamp)
    )
  );
  
  IF current_volume < expected_volume * 0.5 THEN  -- <50% of expected
    CALL alert_slack(f'⚠️ Event volume low: {current_volume} vs expected {expected_volume}');
  END IF;
END;

-- Layer 3: Infrastructure Health
CREATE OR REPLACE TASK alert_infrastructure_health
  WAREHOUSE = alert_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  -- Check warehouse health
  SELECT
    warehouse_name,
    state,
    active_cluster_count,
    queued_load_percentage
  FROM snowflake.account_usage.warehouse_load_history
  WHERE DATE(end_time) = CURRENT_DATE()
    AND queued_load_percentage > 80  -- >80% queries queued
  ORDER BY end_time DESC;
  
  IF (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 0 THEN
    CALL alert_pagerduty('⚠️ Warehouse overloaded - high queue percentage');
  END IF;
  
  -- Check Snowflake credit consumption
  SELECT
    SUM(credits_used_compute) AS daily_credits
  FROM snowflake.account_usage.query_history
  WHERE DATE(start_time) = CURRENT_DATE();
  
  LET daily_credits := (SELECT SUM(credits_used_compute) 
                        FROM snowflake.account_usage.query_history
                        WHERE DATE(start_time) = CURRENT_DATE());
  
  IF daily_credits > 1000 THEN  -- Assuming $100/credit, this is $100k/day
    CALL alert_slack(f'💰 High credit consumption today: {daily_credits} credits');
  END IF;
END;

-- Layer 4: Task Execution Health
CREATE OR REPLACE TASK alert_task_failures
  WAREHOUSE = alert_wh
  SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
BEGIN
  SELECT
    task_name,
    state,
    last_error_message,
    query_start_time
  FROM snowflake.account_usage.task_history
  WHERE state = 'FAILED'
    AND query_start_time > DATEADD(hour, -1, CURRENT_TIMESTAMP())
  ORDER BY query_start_time DESC;
  
  IF (SELECT COUNT(*) FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))) > 0 THEN
    CALL alert_pagerduty('❌ P1: One or more tasks failed - check details');
  END IF;
END;
```

---

## Summary: Failure Recovery Decision Tree

```
EVENT: System detects something is wrong

├─ Is raw data stale (>5 min)?
│  ├─ YES: Check Kafka → Check Snowpipe → Restart Snowpipe
│  └─ NO: Continue
│
├─ Is silver data stale (>10 min)?
│  ├─ YES: Check Silver transform logic → Rerun task → Backfill
│  └─ NO: Continue
│
├─ Is gold metrics stale (>5 min)?
│  ├─ YES: Check warehouse health → Scale up if needed → Backfill metrics
│  └─ NO: Continue
│
├─ Is data quality bad (NULLs >1%)?
│  ├─ YES: Investigate data source → Pause downstream → Fix logic
│  └─ NO: Continue
│
├─ Is volume anomalous (<50% expected)?
│  ├─ YES: Check Kafka health → Check app event publishing → Investigate
│  └─ NO: System nominal

RESPONSE TEMPLATE:
1. DETECT: Automated alert fires
2. TRIAGE: Determine severity (P0/P1/P2)
3. INVESTIGATE: Check relevant system (Kafka/Snowpipe/Warehouse/Logic)
4. REMEDIATE: Fix root cause
5. VERIFY: Confirm data correctness
6. COMMUNICATE: Post-incident review
```

---

## Interview Tips

When discussing failures, say:

✅ **Good**: "If Kafka fails, data is safe because we have multi-AZ replication. We detect outages within 5 minutes and alert. Recovery is automatic leader election."

✅ **Better**: "If Snowpipe fails, Kafka retains data for 7 days. We monitor via system tables. If we detect no copies in 5 minutes, we restart the pipe or warehouse. Backfill completes within the SLA."

✅ **Best**: "For cascading failures, we use task dependencies and error handling. If silver transformation fails, downstream tasks pause automatically. We have alerting at each layer. Recovery involves fixing the root cause, rerunning the failing task, and dependent tasks resume naturally."

❌ **Avoid**: "I'm not sure what happens if..."
❌ **Avoid**: "That probably won't happen..."
❌ **Avoid**: "We'll just rebuild the pipeline from scratch..."

---

**Good luck! You've got this. 🚀**
