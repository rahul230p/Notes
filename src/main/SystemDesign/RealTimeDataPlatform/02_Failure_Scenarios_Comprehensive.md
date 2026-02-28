# Real-Time Data Platform - Comprehensive Failure Scenarios & Recovery

## Overview

This document covers **15+ real-world failure scenarios** with detailed recovery procedures. Shows operational maturity and systems thinking.

---

## 1️⃣ PRODUCER FAILURES

### Scenario 1.1: App Event Publishing Fails

**What happens:**
- Mobile app tries to send event → HTTP POST to backend
- Network timeout / backend service down
- Event is lost (initially)

**Impact:**
- DAU/MAU metrics drop artificially
- Conversion rates appear lower
- Real-time dashboards show gaps

**Detection:**
- Monitor: "Events sent" vs "Events received by Kafka"
- Alert if rate drops >20%

**Solution: Async Publishing with Local Retry**

```
Producer SDK (App-side):
  1. Generate event_id (UUID)
  2. Try to send to Kafka (async, non-blocking)
  3. If fails → queue locally (retry buffer)
  4. Background worker retries with exponential backoff (2^n seconds)
  5. After 3 retries → log and drop (acceptable loss rate: 0.001%)
```

**Recovery (Automatic):**
- Network recovers → buffered events flushed
- RTO: Minutes (depends on retry backoff)
- Data loss: 0.001% (acceptable for analytics)

**Interview Answer:**
> "App events are published asynchronously. If publishing fails, the event goes into a local retry queue with exponential backoff (2^n seconds). After 3 retries, it's logged but doesn't block the user. This ensures event collection never impacts app performance."

---

### Scenario 1.2: Event Deduplication (Duplicate Sends)

**What happens:**
- Network timeout → app retries → event sent twice
- User sees duplicate event in metrics
- Orders counted twice

**Impact:**
- Revenue overstated
- Customer charged twice (critical!)
- Metrics corrupted

**Solution:**
1. **Producer side**: Idempotent event IDs
   - UUID generated at event creation time (not send time)
   - Producer can retry with same event_id

2. **Flink side**: Deduplication window
   - Window: 24 hours
   - Group by event_id
   - Keep first occurrence, drop duplicates
   - **Result**: Exactly-once processing

**Recovery (Automatic):**
- Flink deduplication window handles
- Detected in monitoring: "Duplicate events detected"
- RTO: Seconds (windowed processing)
- Data loss: 0 (exactly-once)

**Interview Answer:**
> "We use idempotent event IDs generated at creation time. Producer retries use the same ID. Flink deduplicates using a 24-hour window (event_id → keep first, discard rest). This ensures exactly-once semantics despite network retries."

---

## 2️⃣ KAFKA FAILURES

### Scenario 2.1: Single Broker Down

**What happens:**
- Broker-3 crashes (out of 50)
- 1/50th of partitions temporarily unavailable
- Clients see partition-level failures

**Timeline:**
```
t=0:00    Broker crashes
t=0:05    Clients detect broker down (heartbeat timeout)
t=0:10    New leader elected from replicas
t=0:15    Partition available again on new broker
t=1:00    Old broker restarts (rejoins cluster)
```

**Impact:**
- Producers: Clients auto-retry to other replicas (transparent)
- Consumers: Temporary lag (recoverable)
- Data loss: ZERO (replication factor = 3)

**Detection:**
- Alert: "Broker-3 offline"
- Monitoring: "Under-replicated partitions > 10"

**Recovery (Automatic):**
1. Kafka cluster detects broker down
2. Replicas on other brokers become leaders (already have data)
3. ISR (in-sync replicas) updated
4. Flink consumer reconnects automatically
5. Continues consuming from new leader

**Interview Answer:**
> "Kafka has replication factor 3, so 1 broker can fail without data loss. Leader election happens automatically (20-30 seconds). Flink consumer transparently fails over to the new leader and resumes from saved offset."

---

### Scenario 2.2: Multiple Brokers Down (Network Partition)

**What happens:**
- 2-3 brokers network-partitioned from cluster
- If >1/2 brokers down → cluster loses quorum
- **Cluster goes read-only** (prevents data corruption)

**Timeline:**
```
t=0:00    Network partition occurs (brokers 1,2 isolated from 3-50)
t=0:30    Cluster detects (metadata sync fails)
t=0:45    Cluster switches to read-only (writes rejected)
t=5:00    Network heals
t=5:30    Cluster recovers (reads+writes resume)
```

**Impact:**
- Read: ALLOWED (stale data OK temporarily)
- Write: BLOCKED (prevents corruption)
- Data loss: ZERO (writes were rejected)

**Detection:**
- Alert: "Cluster leader election failed"
- Alert: "Write failures > 1%"

**Solution:**
- Setup: Cluster of 50+ brokers
  - Can tolerate 2 brokers down (25 > 12.5)
  - Quorum always maintained
- Config: min.insync.replicas=2
  - Writes blocked if <2 replicas ready
  - Prevents silent data loss

**Recovery (Automatic):**
1. Network heals
2. Partitions rejoin cluster
3. Resync data (automatic)
4. Writes resume
5. System heals itself

**Interview Answer:**
> "We run 50 brokers to handle multiple failures. With replication factor 3 and min.insync.replicas=2, we can lose 1 broker safely. If >1 broker fails, writes are rejected (read-only mode) to prevent data corruption. When partition heals, system auto-recovers."

---

### Scenario 2.3: Kafka Consumer Lag

**What happens:**
- Flink is slow (high backpressure or GC pauses)
- Lag increases (consumer can't keep up)
- Events pile up in Kafka

**Timeline:**
```
Normal:      Lag = 1-5 seconds (healthy)
Degrading:   Lag = 1 minute (concerning)
Critical:    Lag = 10+ minutes (alert!)
```

**Impact:**
- Realtime latency increases (Redis stale)
- Dashboards show outdated metrics
- But: NO data loss (safe, just delayed)

**Detection:**
```
Alert threshold:
  - Lag > 5 minutes → WARNING
  - Lag > 30 minutes → CRITICAL
  
Monitoring:
  SELECT
    topic,
    consumer_group,
    LAG_SEC,
    CURRENT_TIMESTAMP
  FROM consumer_lag
  WHERE LAG_SEC > 300
```

**Recovery:**
1. **If Flink slow:** Scale up (add more parallelism)
2. **If GC pausing:** Increase heap memory
3. **If backpressure:** Check downstream (Redis/Pinot/S3 slow?)
4. **Auto-scaling:** Kubernetes HPA auto-scales Flink

**Interview Answer:**
> "We monitor consumer lag continuously. If lag > 5 min, we investigate (usually Flink backpressure). Kubernetes auto-scales Flink tasks to catch up. No data is lost during lag—just delayed. Once Flink catches up, system returns to normal."

---

## 3️⃣ FLINK FAILURES

### Scenario 3.1: Flink Task Fails

**What happens:**
- Single TaskManager crashes (OOM, exception, etc.)
- State is lost temporarily
- Consumer lag increases

**Timeline:**
```
t=0:00    Task crashes
t=0:05    Checkpoint detected (every 10 sec)
t=0:10    State restored from S3
t=0:15    Resume consuming from saved offset
t=2:00    Caught up to real-time
t=2:05+   Normal processing resumes
```

**Impact:**
- Realtime latency: Increases by 1-2 min
- Redis: Stale (apps use cache as fallback)
- Data loss: ZERO (exactly-once)

**Detection:**
- Alert: "Task failure detected"
- Metric: "Checkpoints failed > 1"

**Recovery (Automatic):**
1. Kubernetes detects pod failure (readiness probe fails)
2. Restarts pod automatically
3. JobManager loads latest checkpoint from S3
4. Restores state from checkpoint
5. Resumes consuming from saved Kafka offset
6. Replays events since checkpoint

**Interview Answer:**
> "Flink checkpoints every 10 seconds to S3. On task failure, Kubernetes auto-restarts. JobManager automatically restores the latest checkpoint and resumes from the saved Kafka offset. RTO is 1-5 minutes. No data is lost—exactly-once semantics maintained."

---

### Scenario 3.2: Flink Cluster Degradation (50% Capacity Loss)

**What happens:**
- Cluster loses 20% of TaskManagers
- Parallelism reduces (slots decrease)
- Throughput drops but no data loss

**Timeline:**
```
Normal:       256 parallelism (32 TMs × 8 slots)
Degraded:     192 parallelism (24 TMs × 8 slots) = 25% loss
Recovering:   Kubernetes scales up, replaces lost TMs
Recovery:     Back to 256 parallelism (5-10 min)
```

**Impact:**
- Throughput: Reduced (lag increases)
- Latency: Increased (backpressure)
- Data loss: ZERO

**Detection:**
- Alert: "Available parallelism < required"
- Alert: "Consumer lag increasing > 1 min/sec"

**Mitigation:**
1. **Over-provision**: 64 TaskManagers (need only 32)
   - Gracefully handle 50% failure
2. **Auto-scaling**: Kubernetes HPA (add TMs if CPU >70%)
3. **Monitor**: If parallelism < min_required, alert

**Recovery (Automatic):**
1. Kubernetes detects missing pods
2. Schedules new TaskManagers
3. Joins cluster (re-balancing)
4. Parallelism restored
5. Lag caught up

**Interview Answer:**
> "We run Flink with 2× the required parallelism. If one TaskManager fails, others pick up the load. Kubernetes auto-scaling provisions new TMs. Consumer lag increases but recovers automatically. No data loss."

---

### Scenario 3.3: Flink Checkpoint Corruption

**What happens:**
- Checkpoint files in S3 become corrupt (rare)
- Recovery fails (can't restore state)
- Very rare (S3 has redundancy)

**Timeline:**
```
t=0:00    Task fails
t=0:10    Attempts to restore checkpoint
t=0:20    Checkpoint corrupt (recovery fails!)
t=0:30    Manual intervention needed (operator action)
t=1:00    Use older checkpoint (1 hour old)
t=2:00    Reprocessing events (lag increases)
t=4:00    Caught up with fresh 1-hour old state
```

**Impact:**
- Latency: Increases by 1 hour
- Data: Reprocessed (last 1 hour)
- But: NO permanent loss (older checkpoint available)

**Detection:**
- Alert: "Checkpoint recovery failed"
- Monitoring: "Checkpoint latency > 60s" (warning sign)

**Prevention:**
1. **Checkpoint validation job:** Runs hourly
   - Verifies latest checkpoint is readable
   - Detects corruption early
2. **Multiple checkpoints:** Keep last 10 (1 per 10 sec)
3. **Diverse storage:** Checkpoints in multiple S3 buckets
4. **Testing:** Monthly checkpoint recovery drills

**Recovery (Manual):**
1. Operator notified
2. Checks checkpoint history
3. Uses older checkpoint (worst case: 10 min old)
4. Restarts Flink job
5. Reprocesses delta (acceptable)

**Interview Answer:**
> "Checkpoints are stored in S3 with versioning. If corruption detected, we roll back to an older checkpoint (at most 10 min old). Results in 10 min of data being reprocessed. We validate checkpoints hourly to catch issues early."

---

## 4️⃣ REDIS FAILURES

### Scenario 4.1: Redis Replica Out of Sync

**What happens:**
- Master receives updates
- Replica lags behind (network slow)
- Stale data served to clients

**Timeline:**
```
Normal:      Replication lag = 10-50ms (healthy)
Degrading:   Lag = 500ms (alert if >1s)
Critical:    Lag = 5+ seconds (client timeout)
```

**Impact:**
- Order status stale (max 1 sec)
- Apps use local cache as fallback
- No data loss

**Detection:**
- Metric: "Redis replication_lag_ms"
- Alert if > 1000ms

**Solution:**
1. **Replication:** Sync 2/2 replicas (synchronous)
   - Trade-off: Slightly slower writes (wait for replica ack)
   - Benefit: No data loss on master failure
2. **Monitoring:** Alert if lag > 1 sec
3. **Client-side caching:** App caches old data locally
   - If Redis read fails → use cached value

**Recovery:**
1. Network improves
2. Replication catches up (automatic)
3. Lag returns to normal
4. System returns to normal

**Interview Answer:**
> "Redis replicates synchronously to 2 replicas. Replication lag is <100ms typically. If lag > 1 sec, we alert. Clients have local caching as fallback. If Redis down, apps use cached data until fixed."

---

### Scenario 4.2: Redis Master Fails

**What happens:**
- Redis master crashes
- Clients can't write/read immediately
- Sentinel detects and promotes replica

**Timeline:**
```
t=0:00    Master crashes
t=0:15    Sentinel detects (3 × 5-sec heartbeat)
t=0:20    Replica elected as new master
t=0:30    Other replicas sync from new master
t=0:45    All clients reconnected
```

**Impact:**
- Write failures: <45 seconds
- Reads still work (from old data in replicas)
- No data loss (replicated)

**Detection:**
- Alert: "Redis master down"
- Monitoring: "Connection failures > 1"

**Recovery (Automatic):**
1. Sentinel detects master heartbeat missing (15 sec)
2. Promotes largest replica to master
3. Other replicas sync from new master
4. Clients retried (connection pool handles)
5. System recovers

**Interview Answer:**
> "We run Redis with Sentinel for automatic failover. When master fails, Sentinel promotes a replica to master in 45 seconds. Clients retry failed operations and connect to new master. No data loss."

---

### Scenario 4.3: Redis Eviction (Out of Memory)

**What happens:**
- All cache slots full
- New write triggers eviction (LRU policy)
- Old order status gets evicted

**Timeline:**
```
t=0:00    Memory usage = 85% (normal)
t=0:30    Memory usage = 98% (alert!)
t=0:45    Memory usage = 100% (eviction starts)
t=1:00    Old keys evicted (LRU)
```

**Impact:**
- Order status queries return nil (not found)
- Flink repopulates on next update (1-5 sec)
- Apps fall back to database (slower)

**Detection:**
- Alert: "Redis memory usage > 80%"
- Alert: "Evictions per sec > 100"

**Prevention:**
1. **TTL on all keys:** 1 hour
   - Prevents unbounded growth
   - Auto-eviction before memory limit
2. **Monitoring:** Alert if > 80% (scale up)
3. **Capacity planning:** 2× expected peak

**Recovery:**
1. Scale up Redis (add shards)
2. Evictions stop
3. New data flows in
4. System returns to normal

**Interview Answer:**
> "Redis has 1-hour TTL on all keys, preventing unbounded growth. We monitor memory (alert if >80%). If eviction occurs, Flink repopulates on next event. This is acceptable—Redis is a cache, not a source of truth."

---

## 5️⃣ PINOT FAILURES

### Scenario 5.1: Pinot Query Timeout

**What happens:**
- Dashboard tries to query Pinot
- Query exceeds timeout (1 sec default)
- Timeout error returned

**Timeline:**
```
Normal query:       100-300ms (healthy)
Slow query:         500-800ms (concerning)
Timeout query:      >1000ms (return error)
```

**Impact:**
- Dashboard widget blank (no data)
- SLA monitoring unavailable (temporary)
- Core business: ZERO impact

**Detection:**
- Alert: "Query latency P99 > 1s"
- Monitoring: "Query timeouts > 1%"

**Solution:**
1. **Query caching:** 5-10 sec TTL on dashboard queries
   - Repeat queries served from cache instantly
   - Non-issue for repeated queries
2. **Query optimization:** Partition by date, cluster by dimensions
3. **Query quotas:** Rate limit per user/dashboard
4. **Fallback:** Serve cached result from 10 sec ago

**Recovery:**
1. Query completes (or times out)
2. Retry with 1-sec backoff
3. Serve cached result from 10 sec ago (acceptable)
4. No impact on core business

**Interview Answer:**
> "Pinot queries have 1-second timeout. We cache results for 5-10 seconds on dashboard. For repeated queries, cached hits avoid re-querying. Slow queries are optimized or rate-limited. No impact on core operations."

---

### Scenario 5.2: Pinot Cluster Down

**What happens:**
- All Pinot servers down (rare, catastrophic)
- Dashboard can't query
- Flink still sending data to Kafka

**Timeline:**
```
t=0:00    Pinot goes down (all nodes crash)
t=0:30    Alert fires
t=1:00    Operator investigates
t=2:00    Pinot restarts (or replaced)
t=3:00    Pinot operational (replayed 2 hours data)
t=4:00    Dashboards populated
```

**Impact:**
- Ops dashboards unavailable (URGENT but not CRITICAL)
- Core business: ZERO impact
- Kafka/Flink/Redis unaffected

**Detection:**
- Alert: "Pinot cluster unreachable"
- Alert: "Query failures > 50%"

**Prevention:**
1. **Redundancy:** Multiple Pinot clusters (warm standby)
2. **Monitoring:** Heartbeat alerts
3. **Capacity:** 2× peak load

**Recovery (Automatic/Manual):**
1. Pinot starts up
2. Flink replays last 2 hours of data
3. Dashboards populated
4. Time to recover: 3-5 minutes

**Interview Answer:**
> "Pinot is separate from core business logic. If down, dashboards are blind but customers are unaffected. Pinot restarts quickly and Flink replays data. RTO: <5 minutes. Not a critical path."

---

## 6️⃣ SNOWFLAKE FAILURES

### Scenario 6.1: Snowflake Warehouse Suspended

**What happens:**
- Long running query exhausts credits
- Warehouse suspended due to idleness
- New queries timeout

**Timeline:**
```
t=0:00    Query starts (expensive, full scan)
t=5:00    Query completes (100K credits burned!)
t=5:30    Warehouse suspended (idle for 5 min)
t=10:00   New query attempted
t=10:05   Warehouse resumes (takes 5-10 sec)
t=10:10   Query executes
```

**Impact:**
- Analytics delayed (<5 min)
- Ops unaffected
- Core business: ZERO impact

**Detection:**
- Alert: "Warehouse suspended"
- Alert: "Credits burned > $1K in 1 hour"

**Solution:**
1. **Auto-suspend:** Suspend after 5 min of inactivity
   - Automatically resumes on query
   - Saves cost
2. **Query monitoring:** Alert if query > 5 min
3. **Auto-scaling:** If queues form, scale warehouse
4. **Partitioning:** Partition data by date to avoid scans

**Recovery (Automatic):**
- Warehouse resumes on query (1-2 sec latency)
- Query executes
- System normal

**Interview Answer:**
> "Snowflake has auto-suspend/resume configured. If idle, warehouse suspends (saves cost). On query, it resumes automatically (+1-2 sec latency). Long queries are monitored and optimized."

---

### Scenario 6.2: Snowflake Down (Rare)

**What happens:**
- Snowflake service maintenance/failure (rare)
- Ingestion pipeline pauses
- S3 accumulates backlog

**Timeline:**
```
t=0:00    Snowflake down (maintenance or failure)
t=0:15    Snowpipe detects warehouse unreachable
t=0:20    S3 continues accumulating files (batched)
t=4:00    Snowflake up
t=4:15    Snowpipe resumes ingestion
t=6:00    Snowpipe catches up backlog (2 hours data)
```

**Impact:**
- Analytics delayed by 4-6 hours
- Kafka/Flink/Redis: ZERO impact
- Core business: ZERO impact

**Detection:**
- Alert: "Snowflake cluster unreachable"
- Alert: "Snowpipe ingestion lag > 1 hour"

**Prevention:**
1. **Snowpipe monitoring:** Health checks
2. **S3 monitoring:** Backlog size
3. **Manual COPY INTO:** If Snowpipe stuck

**Recovery (Automatic):**
1. Snowflake restarts
2. Snowpipe resumes (sees backlog in S3)
3. Ingests backlog automatically
4. No manual action needed

**Interview Answer:**
> "Snowflake is separate from realtime systems. If down, analytics are delayed but customers are unaffected. Snowpipe automatically resumes and catches up backlog (self-healing). No data loss."

---

## 7️⃣ MONITORING & ALERTING STRATEGY

### Critical Alerts (Page Oncall)

```
Kafka:
  [CRITICAL] Under-replicated partitions > 10
  [CRITICAL] Broker down > 2
  [WARNING] Consumer lag > 10 min

Flink:
  [CRITICAL] Checkpoint duration > 60s
  [CRITICAL] Task failures > 5/min
  [WARNING] Consumer lag > 10 min

Redis:
  [CRITICAL] Master down > 1 min
  [CRITICAL] Replication lag > 5 sec
  [WARNING] Memory usage > 90%

Pinot:
  [WARNING] Query latency P99 > 1 sec
  [WARNING] Ingestion lag > 60 sec
  [INFO] Failed queries > 1%

Snowflake:
  [WARNING] Query queue > 10
  [WARNING] Failed queries > 1%
  [INFO] Cost per query > $1
```

### Dashboard Setup

```
Realtime Dashboard (Prometheus + Grafana):
  ├─ Kafka: Broker health, lag per consumer group
  ├─ Flink: Checkpoint age, backpressure %, lag
  ├─ Redis: Memory, replication lag, evictions
  ├─ Pinot: Query latency P50/P99, ingestion lag
  └─ Snowflake: Query queue, load, cost

Business Dashboard (Pinot):
  ├─ Live metrics (ops team)
  ├─ Alerts for SLA breaches
  └─ City-level health

Analytics Dashboard (Snowflake):
  ├─ Daily KPIs
  ├─ Trend reports
  └─ Ad-hoc queries
```

---

## 8️⃣ RECOVERY PROCEDURES (Runbooks)

### Kafka Broker Down
1. Check broker status: `kafka-topics.sh --describe --under-replicated-partitions`
2. Monitor leader election (automatic)
3. Restart broker if hung
4. Verify ISR recovered

### Flink Task Failure
1. Check logs: `kubectl logs <pod>`
2. Verify checkpoint exists in S3
3. Monitor recovery (auto-restart enabled)
4. If stuck, scale down and up

### Redis Failover
1. Check master status: `redis-cli -p 26379 sentinel masters`
2. Monitor new leader election
3. Verify replication
4. Check clients reconnected

### Pinot Query Timeout
1. Identify slow query
2. Optimize or increase timeout
3. Monitor for pattern
4. Add index if needed

### Snowflake Delay
1. Check Snowpipe status
2. Monitor S3 backlog
3. Scale warehouse if needed
4. Check for query blocking

---

## 9️⃣ KEY TAKEAWAYS FOR INTERVIEW

### Remember These Lines

1. **"Failures are isolated by design"** — Kafka down ≠ Flink down ≠ Pinot down
2. **"No single point of failure"** — 6 independent systems, each can fail
3. **"Self-healing"** — Most failures are automatically recovered
4. **"Acceptable data loss"** — 0.001% for producer retries, 0 for core systems
5. **"Eventual consistency"** — Redis/Pinot may lag 1-5 min, acceptable
6. **"RTO < 5 minutes"** — Recovery time for major failures

### Interview Phrases

- "The weakness here is [X], mitigation is [Y]"
- "We trade [immediate consistency] for [availability]"
- "This tier fails independently from that tier"
- "We accept [slight lag] to gain [high availability]"
- "Recovery is automatic except for [rare cases]"

---

END OF DOCUMENT

