# Real-Time Data Platform System Design (DoorDash Scale)

## 🚀 OPENING STATEMENT (Memorize This - 30 Seconds)

**Start with this exact framing:**

> "I'll design this system by separating workloads by SLA. We have three fundamentally different needs: millisecond realtime serving, sub-second operational analytics, and minute-level deep analytics and history. Each layer is optimized independently to avoid cascading failures."

This framing immediately puts you in **senior mode**. You're thinking about:
- **Isolation** (failures don't cascade)
- **SLA** (different systems for different latencies)
- **Failure domains** (boundaries, not monoliths)

---

## 0️⃣ CLARIFYING QUESTIONS (Ask First - 5 Max)

### Functional Requirements
1. **What are the primary use cases?** 
   - Real-time serving (order status, dasher location)?
   - Operational metrics (SLA monitoring, zone health)?
   - Deep analytics (business metrics, reporting, ML)?

2. **What event volumes?**
   - Normal: 100K-500K events/sec?
   - Peak: 10× spike multiplier?

3. **What SLAs required?**
   - Sub-millisecond (<1ms) for realtime serving?
   - Sub-second (<500ms) for operational dashboards?
   - Minutes (<2min) for analytics?

4. **What data types?**
   - Order events (placed, confirmed, delivered)?
   - Location pings (dasher movement)?
   - User interactions (app opened, searched)?
   - Merchant status (online/offline)?

5. **Retention policy?**
   - Hot data (realtime): hours/days?
   - Warm data (analytics): days/weeks?
   - Cold data (history): years?

### Non-Functional Requirements
- **Cost sensitivity?**
- **Team expertise?** (Kafka, Flink, Snowflake?)
- **Failure tolerance?** (Can serving go down? Analytics?)
- **Multi-region?** (Or single region OK?)
- **Compliance/PII?** (GDPR, PCI?)

### After Answers, Say:
> "I'll assume 500K events/sec peak with 10× spikes, three distinct SLA tiers (milliseconds/sub-second/minutes), diverse use cases (serving/ops/analytics), and experienced teams with Kafka/Flink/Snowflake expertise."

---

## 1️⃣ HIGH-LEVEL ARCHITECTURE (7 Layers)

### End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 0: PRODUCERS (Apps, Services, IoT SDKs)                       │
│          Mobile App → Order events, Location pings, User actions   │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 1: INGESTION BACKBONE (Apache Kafka)                          │
│          500K-1M events/sec | 250+ partitions | 3× replication     │
│          Purpose: Durability, replay, decoupling, backpressure     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 2: STREAM PROCESSOR (Apache Flink)                            │
│          Validation | Deduplication | Late-event handling          │
│          Event-time ordering | Small SLA-critical windows          │
│          Routing by SLA tier                                        │
└─────────────────────────────────────────────────────────────────────┘
        ↙                       ↓                       ↘
┌──────────────────┐  ┌─────────────────────┐  ┌────────────────────┐
│ LAYER 3:         │  │ LAYER 4:            │  │ LAYER 5:           │
│ REALTIME SERVING │  │ OPS ANALYTICS       │  │ IMMUTABLE HISTORY  │
│                  │  │                     │  │                    │
│ Redis            │  │ Pinot (OLAP)        │  │ S3 (Data Lake)     │
│ <1ms latency     │  │ <500ms latency      │  │ Parquet files      │
│ Order status     │  │ Live dashboards     │  │ Raw events         │
│ Dasher location  │  │ Zone health         │  │ Immutable          │
│ Active mappings  │  │ SLA monitoring      │  │ Replay capability  │
│ TTL: 1 hour      │  │ TTL: 7 days         │  │ TTL: 2+ years      │
└──────────────────┘  └─────────────────────┘  └────────────────────┘
                                                       ↓
                              ┌────────────────────────────────────────┐
                              │ LAYER 6: DEEP ANALYTICS & REPORTING    │
                              │                                        │
                              │ Snowflake (Data Warehouse)             │
                              │ - RAW (Bronze): 30 days                │
                              │ - SILVER: Cleaned & enriched           │
                              │ - GOLD: Business metrics               │
                              │ <2min latency | Full history           │
                              └────────────────────────────────────────┘
```

### SLA Tiers (Key Concept)

| Tier | Latency | System | Use Case | Failure Impact |
|------|---------|--------|----------|----------------|
| **Realtime Serving** | <1ms | Redis | Order status, dasher location | Customer-facing (CRITICAL) |
| **Ops Analytics** | <500ms | Pinot | SLA monitoring, zone health | Ops dashboards (URGENT) |
| **Deep Analytics** | <2min | Snowflake | Business metrics, reporting | Insights delayed (OK to wait) |

**Key Design Philosophy:**
- Each SLA tier is **independent**
- One tier failing ≠ others fail
- Different cost/complexity tradeoffs per tier

---

## 2️⃣ LAYER 0: PRODUCERS (Apps & Services)

### What Happens Here

Mobile apps, backend services, location SDKs emit events:
- **Order events**: placed, confirmed, collected, delivered
- **Dasher location pings**: every 2-5 seconds
- **Merchant status updates**: online/offline transitions
- **User interactions**: app opened, search query, item viewed
- **Delivery metrics**: duration, distance, issues encountered

### Producer Event Schema

```json
{
  "event_id": "uuid-12345",           // Idempotent key (CRITICAL)
  "event_type": "order_placed",       // Type identifier
  "event_version": 1,                 // For schema evolution
  "event_timestamp": "2026-02-12T10:30:45Z",  // When it happened
  "user_id": "user-456",              // Who did it
  "order_id": "order-789",            // Context
  "device_id": "device-001",          // Device identifier
  "payload": {                        // Custom data per event type
    "order_value": 25.99,
    "restaurant_id": "rest-123",
    "items": [...]
  },
  "producer_id": "order-service-v2",  // Which service emitted
  "trace_id": "trace-xyz"             // Debugging/tracing
}
```

### Key Concerns & Answers

#### Q: How do you handle spikes?
**A:** Producers write asynchronously to Kafka. No direct downstream coupling. Kafka absorbs spikes without overloading consumer systems.

#### Q: How do you avoid duplicate events?
**A:** 
1. Idempotent event IDs (generated at creation time, not send time)
2. Producer retries use same event_id
3. Downstream deduplication in Flink (additional safety layer)

#### Q: What if a producer fails?
**A:** Local queueing in the app SDK with exponential backoff retry. No impact on other producers.

### Trade-offs

- ✅ Slight duplicate events accepted → handled downstream
- ✅ Eventual consistency at producer level
- ✅ Non-blocking (async), no user-facing latency impact

---

## 3️⃣ LAYER 1: INGESTION BACKBONE — Apache Kafka

### Why Kafka (Not RabbitMQ, Kinesis, Pulsar, etc.)

| Aspect | Kafka | Advantage |
|--------|-------|-----------|
| **Throughput** | 1M+ events/sec | Designed for massive scale |
| **Replayability** | Built-in | Replay from any offset |
| **Backpressure** | Natural (partitions) | Prevents cascading failures |
| **Decoupling** | Clean separation | Producers ≠ Consumers |
| **Ecosystem** | Kafka Connect, Schema Registry | Mature, proven tooling |
| **Cost** | Efficient per event | Open-source, commodity hardware |

### Design Choices

#### 1. Partitioning Strategy (CRITICAL)

```
Partition Key Selection by Topic:

Topic: kafka-orders
  Key: order_id
  Reason: Keep all order events together → ordering guaranteed
  Partitions: 500
  
Topic: kafka-locations
  Key: dasher_id
  Reason: Preserve order for one dasher's movement
  Partitions: 500
  
Topic: kafka-users
  Key: user_id
  Reason: Track user session coherence
  Partitions: 200
  
Topic: kafka-merchants
  Key: merchant_id
  Reason: Consistent state per merchant
  Partitions: 200

TOTAL PARTITIONS: 1400 (across 50 brokers = 28 per broker)

Why not random partitioning?
→ Would lose ordering guarantees per entity.

Why not too many partitions?
→ Flink parallelism becomes unmanageable
→ Rebalancing slower (coordination overhead)
→ Broker CPU increases

Sweet spot: 250-500 partitions per topic
```

#### 2. Topic Topology

```
kafka-orders (500 partitions)
  └─ order_placed, order_confirmed, order_collected, order_delivered
  
kafka-locations (500 partitions)
  └─ dasher_location_update
  
kafka-users (200 partitions)
  └─ user_app_opened, user_search, user_item_viewed
  
kafka-merchants (200 partitions)
  └─ merchant_online, merchant_offline, merchant_status_update
  
kafka-errors (50 partitions)
  └─ All errors from producers and consumers
```

#### 3. Replication & Durability

```
Configuration:
  Replication factor: 3 (durability)
  Min in-sync replicas (ISR): 2
  
  Trade-off: 
    - Higher ISR = safer but slower
    - Lower ISR = faster but riskier
    - 2 is the sweet spot (1 broker can fail safely)

Compression:
  Type: SNAPPY (CPU-efficient, good compression ratio)
  Ratio: ~7:1 (7KB raw → 1KB compressed)
  
Retention:
  Short-lived: 12-24 hours
    └─ kafka-locations (old pings not useful)
  
  Long-lived: 24-48 hours
    └─ kafka-orders (backfill from S3 for older data)
  
  Compacted: Log-compacted (latest value per key)
    └─ kafka-merchant-state (always keep latest state)
```

#### 4. Schema Registry (CRITICAL for Data Governance)

**What is Schema Registry?**
- Centralized schema management for Kafka topics
- Enforces schema compatibility across producers/consumers
- Versioning and schema evolution
- Prevents bad data from entering the system

**Setup:**

```
Kafka Cluster (50 brokers)
    ↓
Schema Registry Cluster (3 nodes)
    ├─ Primary: Reads/Writes schemas
    ├─ Secondary: Read-only replicas
    └─ Tertiary: Read-only replicas

Storage:
  └─ Schemas stored in Kafka topic (_schemas)
  └─ Highly available, replicated
```

**Schema Definition (Avro Format):**

```json
{
  "type": "record",
  "name": "OrderEvent",
  "namespace": "com.doordash.events",
  "version": 2,
  "doc": "Order lifecycle event with schema versioning",
  "fields": [
    {
      "name": "event_id",
      "type": "string",
      "doc": "Unique idempotent identifier"
    },
    {
      "name": "event_type",
      "type": "string",
      "doc": "Type of order event"
    },
    {
      "name": "event_timestamp",
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "When event occurred (milliseconds since epoch)"
    },
    {
      "name": "order_id",
      "type": "string",
      "doc": "Order identifier"
    },
    {
      "name": "order_value",
      "type": "double",
      "doc": "Order total in USD"
    },
    {
      "name": "tip",
      "type": ["null", "double"],
      "default": null,
      "doc": "Optional dasher tip (added in v2)"
    },
    {
      "name": "delivery_notes",
      "type": ["null", "string"],
      "default": null,
      "doc": "Optional delivery notes (added in v2)"
    }
  ]
}
```

**Producer Integration:**

```java
// Initialize Schema Registry client
SchemaRegistryClient schemaRegistry = new CachedSchemaRegistryClient(
  "http://schema-registry:8081", 100);

// Get or register schema
int schemaId = schemaRegistry.register(
  "orders-value",  // subject name
  schema);         // Avro schema

// Create serializer
AvroSerializer<OrderEvent> serializer = 
  new AvroSerializer<>(schemaRegistry, OrderEvent.class);

// Send to Kafka with schema
ProducerRecord<String, OrderEvent> record = 
  new ProducerRecord<>("orders", 
    orderId,           // key
    event);            // value (auto-serialized with schema)
producer.send(record);
```

**Consumer Integration:**

```java
// Deserializer automatically handles schema
AvroDeserializer<OrderEvent> deserializer = 
  new AvroDeserializer<>(schemaRegistry, OrderEvent.class);

// Consumer automatically validates against schema
ConsumerRecord<String, OrderEvent> record = consumer.poll(...);
OrderEvent event = record.value();  // Deserialized with schema validation
```

**Schema Compatibility Modes:**

```
Mode 1: BACKWARD (default)
  ├─ New consumers can read old producer data
  ├─ Allow: Add optional fields
  ├─ Disallow: Remove required fields
  └─ Use: Safe for gradual producer rollout

Mode 2: FORWARD
  ├─ Old consumers can read new producer data
  ├─ Allow: Remove fields
  ├─ Disallow: Add required fields
  └─ Use: Safe for gradual consumer rollout

Mode 3: FULL
  ├─ Combines BACKWARD + FORWARD
  ├─ Allow: Add optional fields, remove fields
  ├─ Most restrictive (safest)
  └─ Use: Production environments (recommended)

Mode 4: TRANSITIVE
  ├─ Schemas compatible across multiple versions
  ├─ Example: v1 → v2 → v3 all compatible
  └─ Use: Long-lived topics with many versions

Our Configuration:
  └─ Mode: FULL (safety first)
  └─ Subject Naming: TopicNameStrategy (orders topic → orders-value)
```

**Schema Evolution Example:**

```
Version 1 (Current):
  {
    "event_id": "string",
    "order_id": "string",
    "order_value": "double"
  }

Version 2 (Add optional field):
  {
    "event_id": "string",
    "order_id": "string",
    "order_value": "double",
    "tip": ["null", "double"] ← NEW (optional, default null)
  }
  ✅ BACKWARD COMPATIBLE (old producer, new consumer OK)
  ✅ FORWARD COMPATIBLE (new producer, old consumer OK)
  ✅ Can push gradually

Version 3 (Add another optional field):
  {
    "event_id": "string",
    "order_id": "string",
    "order_value": "double",
    "tip": ["null", "double"],
    "delivery_notes": ["null", "string"] ← NEW
  }
  ✅ TRANSITIVE (v1 → v2 → v3 all compatible)
```

**Interview Q&A:**

**Q: Why use Schema Registry instead of JSON?**
> A: 
> 1. **Type safety**: Avro enforces types (prevents bad data)
> 2. **Backward compatibility**: Explicit versioning rules prevent breaking changes
> 3. **Space efficiency**: Binary format is 10× smaller than JSON
> 4. **Validation**: Schema Registry rejects invalid events at producer
> 5. **Documentation**: Schema serves as API contract between teams

**Q: What happens if producer sends incompatible schema?**
> A:
> 1. Producer calls Schema Registry: "I want to send this schema"
> 2. Registry checks compatibility: "Does this match FULL compatibility mode?"
> 3. If incompatible: Rejects with error
> 4. Producer must either:
>    - Fix schema (make it compatible)
>    - Change to new topic (if breaking change needed)
>    - Increment version (if backwards incompatible change allowed)
> 5. Prevents bad data from entering Kafka

**Q: How do you handle schema changes?**
> A: 
> 1. **Add optional field**: Just add with default value (no issue)
> 2. **Remove optional field**: Old data still works (just ignored)
> 3. **Breaking change needed**: 
>    - Create new topic (orders-v2)
>    - Migrate consumers over time
>    - Deprecate old topic (after 30 days)
> 4. **Migration example**:
>    ```
>    Timestamp | Action
>    ──────────────────────────────────
>    Day 1     | New schema registered
>    Day 2     | New producers start using new schema
>    Day 3     | New consumers start reading from both topics
>    Day 7     | Old consumers migrated to new topic
>    Day 30    | Old topic decommissioned
>    ```

**Monitoring Schema Registry:**

```
Metrics to track:
  ├─ Schema registration rate (alert if >10/hour = too many changes)
  ├─ Schema compatibility failures (alert if >1%)
  ├─ Schema Registry latency (alert if >100ms)
  ├─ Subject count (track schema growth)
  └─ Schema version count (alert if >50 versions = cleanup needed)

Alerts:
  ├─ Producer rejected due to schema incompatibility
  ├─ Consumer fails to deserialize (schema mismatch)
  ├─ Schema Registry unreachable (critical)
  └─ Breaking schema change attempted (requires approval)
```

**Cost Impact:**

```
Schema Registry Infrastructure:
  ├─ 3 nodes (t3.medium EC2): $50/month = $600/year
  ├─ Schema storage (Kafka topic, negligible): ~$0
  └─ Monitoring & logging: ~$100/year
  
TOTAL: ~$700/year (negligible)

Benefits:
  ├─ Prevents data quality issues (saves $100K+/year)
  ├─ Enables safe schema evolution (saves migration costs)
  ├─ Reduces debugging time (clear error messages)
  └─ Document API contracts (reduces integration issues)

ROI: 100+ × cost savings
```

### Kafka Handles

#### 🔥 Spikes
- Partitions buffer excess traffic automatically
- Consumer lag increases but data never lost
- Flink/Pinot consumers catch up when rate drops
- **Key line:** "Kafka is our shock absorber."

#### ❗ Failures
- **Broker down**: Partition re-replicates to other brokers (automatic)
- **Consumer lag**: Visible in monitoring, but safe (backlog auto-drained)
- **Network partition**: Leader election happens (seconds)

### Interview Questions

#### Q: Why not send data directly to Flink/Database?
**A:** Direct writes would cascade failures:
- If Flink slows down → producers back up or timeout
- If DB is slow → producers suffer latency
- Kafka provides:
  - **Replay**: Restart Flink = reprocess all events
  - **Backpressure**: Producers wait safely without affecting users
  - **Decoupling**: Independent scaling of producers and consumers
  - **Debugging**: Can re-run logic on historical data

#### Q: What about exactly-once semantics?
**A:** Kafka guarantees at-least-once per broker. We handle exactly-once through event_id + downstream deduplication in Flink.
- Consumer lag → visible but safe (backlog auto-drained)
- Network partition → leader election (seconds)

### Interview Question

**Q: Why not send data directly to Flink/Database?**

> **A:** Direct writes would cascade failures. If Flink slows down, producers would back up or timeout. If DB is slow, producers suffer. Kafka provides:
> - Replay (restart Flink = reprocess all)
> - Backpressure (producers wait safely)
> - Decoupling (independent scaling)
> - Debugging (can re-run logic on old data)

---

## 4️⃣ Layer 3: Stream Processing — Apache Flink

### This is the Brain

Flink does the heavy lifting: validation, deduplication, ordering, routing.

### What Flink Does (and Does NOT do)

#### ✅ Does (Core Responsibilities)

```
1. Event Validation
   - Schema validation
   - Range checks (e.g., order amount > 0)
   - Dead-letter routing

2. Deduplication
   - Group by event_id
   - Window: 24 hours
   - Idempotent output

3. Event-Time Ordering
   - Watermarks (handle late arrivals)
   - Allowed lateness: 5 minutes
   - Out-of-order reordering

4. Small SLA-Critical Windows
   - Last 5 min: "active orders"
   - Last 1 hour: "zone health"
   - Emit to Redis (for realtime serving)

5. State Management
   - RocksDB (embedded KV store)
   - Maintains: user sessions, order state, dasher state
   - Checkpoints every 10 seconds

6. Routing by SLA
   - Critical events → Redis (fast path)
   - Operational events → Pinot
   - Everything → S3 (immutable history)
```

#### ❌ Does NOT (Anti-patterns)

```
❌ Heavy analytics (too stateful)
❌ Complex joins (requires maintaining huge state)
❌ Long-term aggregations (bloats memory)
❌ Business logic that changes frequently
   (Flink changes = recompilation + restart)

If you try these, checkpoints get huge → restarts take forever.
```

### Late Events — How Flink Handles

#### The Problem

Events may arrive out-of-order:
- Location ping from 10 seconds ago arrives now
- Order completion from 2 minutes ago arrives late

#### The Solution

```java
// Event-time processing (not processing time)
DataStream<Event> events = ...

// Watermark: "all events before timestamp X have arrived"
events.assignTimestampsAndWatermarks(
  new WatermarkStrategy<Event>()
    .withTimestampAssigner((event, recordTimestamp) -> 
      event.getEventTimestamp())
    .withIdleness(Duration.ofSeconds(5))
);

// Window: Collect events for 5 minutes
events
  .keyBy(Event::getOrderId)
  .window(SlidingEventTimeWindows.of(
    Time.seconds(300), Time.seconds(10)))
  .allowedLateness(Time.minutes(5))  // Accept 5-min late arrivals
  .reduce((e1, e2) -> e2)  // Keep latest
  .addSink(new RedisSink());  // Output to Redis
```

#### What Happens

```
t=0:00  Event arrives (on-time) → Added to window
t=0:05  Window closes → Result sent to Redis
t=0:07  Late event arrives (2-min late) → Update triggered
        → Redis updated with correct result
t=5:05  Event too late → Discarded (allowed lateness exceeded)
```

#### Interview Answer

> "Flink uses event-time processing with watermarks. Late events within the allowed window (5 min) trigger result updates. Events too late are discarded. This ensures:
> - Order events within 5 min are always included
> - Location updates reflect latest available data
> - Old data doesn't corrupt new results"

### Failures — Flink Guarantees

#### Exactly-Once Semantics

```
1. Flink checkpoints state every 10 seconds
   - Saves to distributed storage (S3)
   - Records Kafka offset for each partition

2. On failure:
   - Recover from latest checkpoint
   - Restart consuming from saved Kafka offset
   - All intermediate results replayed

Result: No events lost, no duplication
```

#### Restart Strategy

```
Failure detected
    ↓
Pause all sources (Kafka consumption halted)
    ↓
Load latest checkpoint (state from S3)
    ↓
Resume from saved Kafka offset
    ↓
Catch up to current (replay all events since checkpoint)
    ↓
Resume live processing
```

#### State Backend

```
Option 1: RocksDB (Embedded)
  Pros: Fast, local
  Cons: Size limited by disk
  Use for: Small state (<100GB)

Option 2: External State (Redis/DynamoDB)
  Pros: Unlimited size
  Cons: Network latency
  Use for: Large state (>100GB)

We use RocksDB for most jobs, external for special cases.
```

### Trade-offs (Explicitly State These)

- ✅ Sub-second latency achievable
- ✅ Exactly-once semantics
- ✅ Late event handling
- ❌ Adds operational complexity (cluster management)
- ❌ Stateful jobs = harder restarts
- ❌ Checkpoint size matters (bigger = slower recovery)

**Defense:** "We intentionally keep Flink lightweight. Only SLA-critical streams run here. Heavy aggregations happen in Pinot/Snowflake."

---

## 5️⃣ Layer 4: Realtime Serving Path (Milliseconds)

### 🔴 Redis (The Serving Store)

**Flow:** Kafka → Flink → Redis → APIs → Apps

#### What Lives Here

```
Active Orders
├─ order_id → {
│    status: "confirmed" | "collecting" | "delivering" | "delivered",
│    dasher_id,
│    estimated_delivery_time,
│    current_location_of_dasher,
│    customer_location
│  }

Latest Dasher Locations
├─ dasher_id → {
│    lat, lng,
│    timestamp,
│    status: "online" | "on_delivery" | "paused"
│  }

Active Mappings
├─ order_id → dasher_id (current assignment)
```

#### Why Redis

| Property | Why |
|----------|-----|
| **<1ms latency** | In-memory, no disk |
| **Millions QPS** | Designed for throughput |
| **TTL/Eviction** | Auto-delete old data |
| **Pub/Sub** | Real-time push to clients |
| **Simple data model** | Key-value, no complex joins |

#### Redis Design

```
Data Structure: Hash

Redis SET (Flink output):
HSET active_orders:{order_id} \
  status "delivering" \
  dasher_id "d123" \
  estimated_eta "2026-02-09T14:30:00Z" \
  dasher_lat "37.7749" \
  dasher_lng "-122.4194"

Redis GET (API query):
GET active_orders:{order_id}
→ Returns JSON blob in microseconds

TTL:
EXPIRE active_orders:{order_id} 3600
(Auto-delete after 1 hour, prevents stale data)
```

#### High-Availability Setup

```
Redis Cluster
├─ Master (Primary writes)
├─ Replica 1 (Read-only, sync)
├─ Replica 2 (Read-only, sync)

Failover:
- Master down → Sentinel auto-promotes Replica 1
- RTO: 5-10 seconds
- Data loss: 0 (replicated)

Flink outputs to all nodes (tolerates failures)
Clients read from any replica
```

### Interview Questions

#### Q: What if Redis fails?
> **A:** 
> - Flink has the latest state (checkpointed to S3)
> - Clients see stale data briefly (cached in apps)
> - Redis restarts → Flink repopulates immediately
> - RTO: 30 seconds

#### Q: Can the serving store become inconsistent?
> **A:**
> - Redis is not a source of truth — it's a cache
> - Source of truth is Kafka
> - Inconsistency OK → Flink fixes it on next update
> - Clients eventually see correct data

#### Q: Why not use Snowflake for serving?
> **A:**
> - Snowflake: 100ms+ query latency
> - Redis: <1ms latency
> - Snowflake: Need SQL parsing overhead
> - Redis: Direct key lookup (O(1))
> - Snowflake: Not designed for millions of concurrent reads

---

## 6️⃣ Layer 5: Sub-Second Analytics Path

### ⚡ Apache Pinot (The Real-Time Analytics Engine)

**Flow:** Kafka → Flink → Pinot → Ops Dashboards

#### What Pinot Is Used For

```
Operational Metrics (Real-Time)
├─ Active orders: COUNT (last 5 min) by city
├─ Zone health: AVG(delivery_time) by zone
├─ Dasher utilization: COUNT(DISTINCT dasher_id) online
├─ Order SLA tracking: P50/P95/P99 delivery times
├─ Error rates: SUM(errors) / SUM(total_events)
└─ Surge pricing: Current demand by zone

All queryable in <500ms with auto-complete and drilldowns.
```

#### Why Pinot (Not Druid, Elasticsearch, etc.)

| Feature | Pinot | Why Better |
|---------|-------|-----------|
| **Column indexing** | Inverted + Range | Fast scans |
| **Real-time ingestion** | Sub-second | Live data |
| **High concurrency** | Built for ops dashboards | Handles 1000s QPS |
| **Aggregations** | Pre-computed | Fast rollups |
| **Retention tiers** | Real-time + Offline | Cost-efficient |
| **SQL interface** | Standard OLAP | Easy for analysts |

#### Pinot Design

```
Schema:

CREATE TABLE metrics__REALTIME (
  metric_timestamp TIMESTAMP,
  city STRING,
  zone STRING,
  order_count INT,
  delivery_time_ms INT,
  dasher_count INT,
  error_count INT
)
AGGREGATE BY SUM(order_count), AVG(delivery_time_ms), ...
```

#### Sample Queries (Real-Time)

```sql
-- "How many active orders in SF right now?"
SELECT SUM(order_count) FROM metrics WHERE city = 'sf' 
  AND metric_timestamp > CURRENT_TIMESTAMP() - INTERVAL '5' MINUTE;
-- Returns: <500ms

-- "What's the P95 delivery time by zone?"
SELECT zone, PERCENTILE(delivery_time_ms, 95) 
FROM metrics 
WHERE metric_timestamp > CURRENT_TIMESTAMP() - INTERVAL '1' HOUR 
GROUP BY zone;
-- Returns: <500ms

-- "Dasher utilization trend (1-hour rolling)"
SELECT metric_timestamp, city, AVG(dasher_count) 
FROM metrics 
WHERE metric_timestamp > CURRENT_TIMESTAMP() - INTERVAL '1' HOUR 
GROUP BY metric_timestamp, city;
-- Returns: <500ms
```

#### Aggregations — Handled in Flink

```java
// Flink pre-computes aggregations
DataStream<Event> events = ...

events
  .keyBy(e -> e.getCity() + "|" + e.getZone())
  .window(TumblingEventTimeWindows.of(Time.seconds(60)))  // 1-min windows
  .aggregate(
    new AggregateFunction<Event, Accumulator, Metric>() {
      public Accumulator createAccumulator() {...}
      public Accumulator add(Event e, Accumulator acc) {
        acc.orderCount++;
        acc.totalDeliveryTime += e.getDeliveryTime();
        return acc;
      }
      public Metric getResult(Accumulator acc) {
        return new Metric(
          acc.orderCount,
          acc.totalDeliveryTime / acc.orderCount  // Avg
        );
      }
    }
  )
  .addSink(new PinotSink());
```

**Why pre-compute?**
- Flink calculates once per minute
- Pinot just stores results
- Query is instant (no recalculation)

### Interview Questions

#### Q: Why not do all aggregations in Flink?
> **A:**
> - State explosion (millions of aggregate combinations)
> - Checkpoint bloat (takes minutes to recover)
> - Query latency increases (need to query live state)
> - Better to separate: Flink (small state) + Pinot (read path)

#### Q: What if Pinot fails?
> **A:**
> - Dashboards unavailable (degraded, not critical)
> - Core pipelines unaffected (Kafka, Flink still running)
> - Pinot restarts → Flink replays recent data
> - RTO: <5 minutes

---

## 7️⃣ Layer 6: Deep Analytics & History Path

### ❄️ S3 → Snowflake (The Data Lake & Warehouse)

**Flow:** Kafka / Flink → S3 → Snowflake (RAW → SILVER → GOLD)

#### Why This Separate Path

```
Reasons for independent deep analytics layer:

1. Cost
   - Keeping ALL events in Pinot = expensive
   - S3 is cheap ($0.023 per GB/month)
   - Snowflake for analysis only

2. Flexibility
   - Analysts need to recompute metrics
   - Don't want to modify Flink → restart
   - Snowflake allows ad-hoc SQL

3. History
   - Redis/Pinot: Recent data only
   - S3/Snowflake: Full history (years)

4. Compliance
   - Need to preserve full event trail
   - For audits, disputes, chargebacks
```

#### Architecture

```
Kafka → S3 (Raw Events)
          ↓ Glue/Spark Job (batch hourly)
        S3 (Partitioned by date/hour)
          ↓ Snowflake Ingestion
        SNOWFLAKE_RAW (Bronze)
          ↓ dbt / Snowflake Tasks
        SNOWFLAKE_SILVER (Cleaned)
          ↓ dbt / Dynamic Tables
        SNOWFLAKE_GOLD (Metrics)
          ↓
        BI Tools (Tableau, Looker)
```

#### Snowflake Design

```sql
-- Bronze: Immutable raw events
CREATE TABLE raw_events (
  event_id STRING,
  event_type STRING,
  event_timestamp TIMESTAMP,
  user_id STRING,
  payload VARIANT,
  _ingestion_time TIMESTAMP
)
CLUSTER BY DATE(event_timestamp), event_type;

-- Silver: Cleaned & enriched
CREATE DYNAMIC TABLE silver_events AS
SELECT
  event_id,
  event_type,
  event_timestamp,
  user_id,
  order_id,
  city,
  -- Enrich from user/order tables
  user_tier,
  order_value,
  delivery_status
FROM raw_events
WHERE event_timestamp >= DATEADD(day, -7, CURRENT_DATE());
TARGET_LAG = '1 hour';

-- Gold: Pre-aggregated metrics
CREATE DYNAMIC TABLE gold_metrics_daily AS
SELECT
  DATE(event_timestamp) AS metric_date,
  city,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS users,
  AVG(delivery_time_ms) AS avg_delivery_time,
  PERCENTILE_CONT(delivery_time_ms, 0.95) AS p95_delivery_time
FROM silver_events
WHERE event_type = 'delivery_completed'
GROUP BY DATE(event_timestamp), city
TARGET_LAG = '30 minutes';
```

#### Transformations (dbt or Snowflake Tasks)

```
RAW → SILVER (Data Quality & Normalization)
- Remove nulls
- Validate data types
- Denormalize nested JSON
- Enrich with dimension tables
- Handle late arrivals

SILVER → GOLD (Business Aggregations)
- DAU, retention, cohorts
- Revenue metrics
- Operational SLAs
- Finance reporting
```

#### Backfilling — How It Works

```
Scenario: We want to recompute last 30 days of metrics with new logic

Step 1: Update SILVER logic in dbt
Step 2: dbt run --select silver_events+ --models +30_days_back
Step 3: Re-calculate all GOLD metrics

Why not from Kafka?
- Kafka retention: 24 hours only
- S3 has 30 days of raw data
- Simpler than Kafka replay + Flink restart

"S3 is our system of record for replay."
```

### Interview Questions

#### Q: Why not query S3 directly?
> **A:**
> - S3 format (Parquet) requires full scans
> - Query latency: minutes
> - Snowflake adds indexing, compression
> - Query latency: seconds to minutes
> - Also: SQL interface, RBAC, audit logs

#### Q: What if Snowflake is down?
> **A:**
> - Ingestion pauses (backlog accumulates in S3)
> - Kafka/Flink unaffected (separate systems)
> - Analytics delayed (not customer-facing)
> - S3 buffers events; Snowflake catches up when back up
> - RTO: Self-healing (no action needed)

> - RTO: Self-healing (no action needed)

---

## 7️⃣ SCALING ANALYSIS (Events/Sec & Data Size)

### Baseline (500K events/sec)

```
Event Volume & Data Size by Layer:

PRODUCERS:
  Events/sec:  500K
  Peak:        500K × 10 = 5M events/sec
  Event size:  ~2KB average
  Data/sec:    500K × 2KB = 1GB/sec (baseline)
  Data/day:    1GB/sec × 86,400 = 86.4TB/day
  
KAFKA (24-hour retention):
  Total data:  86.4TB × 1 day = 86.4TB hot
  Compressed:  86.4TB / 7 (SNAPPY) = 12.3TB stored
  Replicas:    12.3TB × 3 (replication) = 36.9TB total
  Partitions:  500 (order_id, dasher_id, user_id, merchant_id)
  Throughput:  ~2K events/sec per partition (256 parallelism for Flink)
  
FLINK (Stream processing):
  Events/sec:  500K
  Deduplicated: ~450K (10% duplicates removed)
  State size:  ~100GB (RocksDB, SLA-critical aggregations only)
  Checkpoints: Every 10 seconds to S3
  Checkpoint size: ~500MB-1GB (for recovery)
  Output streams: 3 (Redis, Pinot, S3)
  
REDIS (1-hour TTL):
  Active keys:  ~50M (active orders, dashers, mappings)
  Value size:   ~1KB per key
  Memory:       50M × 1KB = 50GB total
  With replicas: 50GB × 3 = 150GB (cluster mode)
  Shards:       16 (10-15 QPS per shard, millions QPS total)
  
PINOT (7-day retention):
  Events/day:   500K × 86,400 = 43.2B events/day
  Raw size:     43.2B × 2KB = 86.4TB/day
  Aggregated:   ~10% of raw = 8.6TB/day
  7-day total:  8.6TB × 7 = 60.2TB
  Compressed:   60.2TB / 5 = 12TB (star-tree compression)
  Segments:     Hourly segments (168 segments for 7 days)
  
SNOWFLAKE (30-day retention):
  RAW layer:    86.4TB/day × 30 = 2.6PB raw
  Compressed:   2.6PB / 7 = ~371TB stored
  SILVER layer: 30% of raw (filtered, enriched) = ~111TB
  GOLD layer:   Pre-aggregated metrics = ~1TB
  Total:        ~483TB (3 layers combined)
```

### Scaling to 5M events/sec (10× Volume)

```
Multiply all numbers by 10:

PRODUCERS:
  Events/sec:  5M
  Data/sec:    10GB/sec
  Data/day:    864TB/day

KAFKA:
  Hot data:    864TB × 1 day
  Stored:      123TB (compressed)
  Replicas:    369TB total
  Partitions:  5,000 (10× more partitions needed)
  Brokers:     500 brokers (10× from 50)
  
FLINK:
  Events/sec:  5M
  State size:  ~1TB (RocksDB, scales with complexity)
  Checkpoints: 5-10GB per checkpoint
  Parallelism: 2,560 tasks (10× from 256)
  TaskManagers: 320 (10× from 32)
  
REDIS:
  Memory:      500GB total (10× from 50GB)
  Shards:      160 (10× from 16)
  
PINOT:
  7-day total: 602TB (10× from 60.2TB)
  Brokers:     200 (10× from 20)
  Ingestion:   86.4TB/day (vs 8.6TB/day now)
  
SNOWFLAKE:
  Total:       4.83TB (10× from 483TB)
  Ingestion cost: 10× higher
  Query latency: May degrade (10× data to scan)
```

### Cost Impact at Different Scales

```
                100K events/sec   500K events/sec   5M events/sec
                ───────────────   ───────────────   ─────────────
Kafka           $50K/year         $225K/year        $2.25M/year
Flink           $15K/year         $56K/year         $560K/year
Redis           $30K/year         $123K/year        $1.23M/year
Pinot           $50K/year         $187K/year        $1.87M/year
Snowflake       $200K/year        $1.37M/year       $13.7M/year ← PROBLEM!
─────────────────────────────────────────────────────────────────
TOTAL           $345K/year        $1.97M/year       $19.4M/year
```

### Scaling Recommendation

**At 5M events/sec, Snowflake becomes problematic.**

Solution:
```
1. Reduce Snowflake ingestion frequency
   ├─ Current: 1 min → New: 10 min
   ├─ Savings: 90% = $12.3M/year
   ├─ Trade-off: Analytics latency 1-2 min → 10-15 min

2. Replace Snowflake with data lake for deep analytics
   ├─ Use S3 + Athena/Trino
   ├─ Cost: $1.87M/year instead of $13.7M/year
   ├─ Trade-off: Query latency 10-60 sec vs 1-5 min

3. Keep Kafka/Flink/Redis/Pinot as-is (linear scaling)
   ├─ These components scale predictably
   ├─ Cost increase proportional to volume
```

---

## 8️⃣ COMPONENT TRADE-OFFS (Vs Alternatives)

### Kafka vs Kinesis vs RabbitMQ vs Pulsar

| Aspect | Kafka | Kinesis | RabbitMQ | Pulsar |
|--------|-------|---------|----------|--------|
| **Throughput** | 1M+/sec ⭐⭐⭐ | 1M+/sec ⭐⭐⭐ | 100K/sec ⭐ | 1M+/sec ⭐⭐⭐ |
| **Latency** | 5-10ms ⭐⭐ | 100ms ⭐ | 1ms ⭐⭐⭐ | 10ms ⭐⭐ |
| **Replayability** | Full ⭐⭐⭐ | Limited (24h) ⭐⭐ | Limited ⭐ | Full ⭐⭐⭐ |
| **Management** | Self-hosted ⭐ | Managed ⭐⭐⭐ | Self-hosted ⭐ | Self-hosted ⭐ |
| **Cost (1M/sec)** | $500K/yr ⭐⭐⭐ | $2M+/yr ⭐ | $100K/yr ⭐⭐⭐ | $300K/yr ⭐⭐ |
| **Ecosystem** | Excellent ⭐⭐⭐ | AWS-only ⭐⭐ | Limited ⭐ | Growing ⭐⭐ |
| **Partitioning** | Topic-level ⭐⭐⭐ | Stream-level ⭐⭐ | Queue-level ⭐ | Topic-level ⭐⭐⭐ |

**Our Choice: Kafka**
- ✅ Cost-effective at scale (500K-5M events/sec)
- ✅ Full replay capability (critical for backfills)
- ✅ Large ecosystem (Flink, Schema Registry, Kafka Connect)
- ✅ Proven at DoorDash/Uber scale
- ❌ Requires self-management (but worth it)

**Trade-off: Management burden vs cost savings ($1.5M/year vs $2M+/year with Kinesis)**

---

### Flink vs Spark Streaming vs Kafka Streams

| Aspect | Flink | Spark Streaming | Kafka Streams |
|--------|-------|-----------------|---------------|
| **Latency** | 10-100ms ⭐⭐⭐ | 500ms+ ⭐ | 5-100ms ⭐⭐⭐ |
| **State Management** | Excellent ⭐⭐⭐ | Good ⭐⭐ | Good ⭐⭐ |
| **Exactly-Once** | Native ⭐⭐⭐ | Via Spark ⭐⭐ | Native ⭐⭐⭐ |
| **Watermarks** | Full support ⭐⭐⭐ | Limited ⭐⭐ | No ⭐ |
| **Complexity** | Medium ⭐⭐ | High ⭐ | Low ⭐⭐⭐ |
| **Scalability** | 1M+ events/sec ⭐⭐⭐ | 100K+ events/sec ⭐⭐ | 500K+ events/sec ⭐⭐ |
| **Learning Curve** | Steep ⭐ | Steep ⭐ | Gentle ⭐⭐⭐ |

**Our Choice: Flink**
- ✅ Sub-second latency (SLA-critical for serving layer)
- ✅ Native watermarks (handles late events elegantly)
- ✅ Exactly-once semantics (no duplicate charges)
- ✅ Powerful state management (RocksDB)
- ❌ Steeper learning curve
- ❌ More complex to operate than Kafka Streams

**Trade-off: Complexity vs latency/features ($56K/year + ops burden vs simpler alternatives)**

---

### Redis vs Memcached vs In-Memory Database

| Aspect | Redis | Memcached | DynamoDB | In-Memory DB |
|--------|-------|-----------|----------|--------------|
| **Latency** | <1ms ⭐⭐⭐ | <1ms ⭐⭐⭐ | 5-10ms ⭐⭐ | <1ms ⭐⭐⭐ |
| **Data Structures** | Rich ⭐⭐⭐ | Simple ⭐ | Simple ⭐ | Very Rich ⭐⭐⭐ |
| **Persistence** | Optional ⭐⭐⭐ | None ⭐ | Automatic ⭐⭐⭐ | Optional ⭐⭐ |
| **Replication** | Multi-region ⭐⭐⭐ | Limited ⭐ | Multi-region ⭐⭐⭐ | Limited ⭐⭐ |
| **Cost (50GB)** | $100K/yr ⭐⭐⭐ | $80K/yr ⭐⭐⭐ | $500K+/yr ⭐ | $200K+/yr ⭐⭐ |
| **Ops Burden** | Medium ⭐⭐ | Low ⭐⭐⭐ | None ⭐⭐⭐ | High ⭐ |

**Our Choice: Redis**
- ✅ Rich data structures (strings, hashes, sets, sorted sets)
- ✅ Built-in persistence (RDB/AOF)
- ✅ Pub/Sub for real-time updates
- ✅ Cost-effective at scale ($123K/year)
- ✅ Cluster mode for high availability
- ❌ Requires operational management
- ❌ Not ideal if data loss acceptable (Memcached would be cheaper)

**Trade-off: Persistence/features vs simplicity (Redis $123K vs Memcached $80K, but Redis has replication)**

---

### Pinot vs Druid vs ClickHouse vs Elasticsearch

| Aspect | Pinot | Druid | ClickHouse | Elasticsearch |
|--------|-------|-------|-----------|----------------|
| **Query Latency** | 100-500ms ⭐⭐⭐ | 100-500ms ⭐⭐⭐ | 50-300ms ⭐⭐⭐ | 100-1000ms ⭐⭐ |
| **Ingestion Latency** | <1s ⭐⭐⭐ | <1s ⭐⭐⭐ | 1-5s ⭐⭐ | 100-500ms ⭐⭐ |
| **Concurrency** | Very High ⭐⭐⭐ | High ⭐⭐ | Medium ⭐⭐ | Medium ⭐⭐ |
| **Cost (60TB/7d)** | $187K/yr ⭐⭐⭐ | $200K/yr ⭐⭐⭐ | $150K/yr ⭐⭐⭐ | $300K+/yr ⭐ |
| **SQL Support** | Full ⭐⭐⭐ | Limited ⭐ | Full ⭐⭐⭐ | Partial ⭐⭐ |
| **Time-Series Opt** | Good ⭐⭐⭐ | Excellent ⭐⭐⭐ | Excellent ⭐⭐⭐ | Good ⭐⭐ |
| **Learning Curve** | Medium ⭐⭐ | Steep ⭐ | Medium ⭐⭐ | Easy ⭐⭐⭐ |

**Our Choice: Pinot**
- ✅ Optimized for OLAP dashboards
- ✅ Sub-second query latency at scale
- ✅ High concurrency (thousands concurrent queries)
- ✅ Full SQL support
- ✅ Excellent for time-series metrics
- ❌ Requires operational management
- ❌ Not ideal for full-text search (Elasticsearch better)

**Trade-off: Ops burden vs performance (Pinot $187K for OPS dashboards, Druid similar but worse SQL)**

---

### Snowflake vs BigQuery vs Redshift vs Data Lake (S3+Athena)

| Aspect | Snowflake | BigQuery | Redshift | S3+Athena |
|--------|-----------|----------|----------|-----------|
| **Query Latency** | 1-30sec ⭐⭐ | 1-30sec ⭐⭐ | 1-10sec ⭐⭐⭐ | 10-300sec ⭐ |
| **Cost per Query** | $5-50 ⭐⭐ | $0.01-10 ⭐⭐⭐ | $0.30-10 ⭐⭐ | $0.001-5 ⭐⭐⭐ |
| **Data Storage** | $40/TB/mo ⭐⭐ | $6-20/TB/mo ⭐⭐⭐ | $1/TB/mo ⭐⭐⭐ | $0.023/TB/mo ⭐⭐⭐ |
| **Operations** | Easy ⭐⭐⭐ | Very Easy ⭐⭐⭐ | Complex ⭐ | Very Complex ⭐ |
| **Warm Data (30d)** | $1,200 ⭐⭐ | $180 ⭐⭐⭐ | $30 ⭐⭐⭐ | $25 ⭐⭐⭐ |
| **Cold Data (2yr)** | $48K ⭐ | $7.2K ⭐⭐⭐ | $1.2K ⭐⭐⭐ | $400 ⭐⭐⭐ |
| **Ad-Hoc Queries** | Easy ⭐⭐⭐ | Easy ⭐⭐⭐ | Easy ⭐⭐⭐ | Complex ⭐ |

**Our Choice: Snowflake**
- ✅ Ease of use (SQL, no cluster management)
- ✅ Auto-scaling (handles spiky workloads)
- ✅ Separation of compute & storage
- ✅ Time travel & zero-copy clones
- ✅ Good for mixed workloads (analytics + ML)
- ❌ Expensive at large scales ($1.37M/year)
- ❌ Cost grows with data volume (unlike S3)

**Trade-off: Ease of use vs cost (Snowflake $1.37M vs S3+Athena $100K at 5M events/sec)**

---

## 9️⃣ KPIs COVERAGE MATRIX (Interview MUST-KNOW)

### Which Layer Tracks Which KPIs

| KPI | Layer(s) | Latency | Update Freq | Notes |
|-----|----------|---------|-------------|-------|
| **Orders Per Minute** | Pinot (Ops), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot), Per-hour (Snowflake) | Live ops dashboard |
| **Delivery SLA %** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot), Per-day (Snowflake) | P50/P95/P99 latency |
| **Popular Items Per City** | Pinot (Live), Snowflake (Trending) | <500ms (Pinot) | Per-minute (Pinot), Per-day (Snowflake) | Real-time trends |
| **Active Drivers** | Redis (Latest), Pinot (Analytics) | <1ms (Redis), <500ms (Pinot) | Real-time (Redis), Per-minute (Pinot) | Exact count in Pinot |
| **User Clickstream** | Snowflake (Silver), S3 (Raw) | <5min (Silver), <2hour (Raw) | Per-5min (Silver) | Session analysis |
| **DAU/MAU** | Snowflake (Gold) | <2min | Per-day (DAU), Per-month (MAU) | Historical tracking |
| **Conversion Rate** | Snowflake (Gold) | <2min | Per-day, Per-hour | Funnel analysis |
| **ARPU** | Snowflake (Gold) | <2min | Per-day | Average revenue per user |
| **LTV** | Snowflake (Gold) | <1day | Per-day | Lifetime value |
| **Churn Rate** | Snowflake (Gold) | <1day | Per-week | User retention |
| **Latency (P50/P95/P99)** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot) | SLA tracking |
| **Error Rate** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot) | Service health |

### Key Points

- **No KPI is missing** — Each has appropriate layers
- **Real-time KPIs**: Pinot (5-minute granularity)
- **Business KPIs**: Snowflake (hourly/daily granularity)
- **Live dashboards**: Query Pinot with caching (5-10 sec TTL)
- **Historical analysis**: Query Snowflake Gold layer (pre-aggregated)
- **Ad-hoc debugging**: Query Snowflake Silver layer (raw+enriched)

---

## 9️⃣ Who Uses What (Interview MUST-KNOW)

| Persona | System | Use Case | SLA |
|---------|--------|----------|-----|
| **Customer/Dasher Apps** | Redis | Order status, location tracking | <1ms |
| **Ops/SRE Team** | Pinot | SLA monitoring, alerts, dashboards | <500ms |
| **Business Dashboards** | Snowflake (Gold) | Daily KPIs, reporting | <2min |
| **Data Analysts** | Snowflake (Silver/Gold) | Ad-hoc analysis, debugging | <5min |
| **Data Scientists** | Snowflake/S3 | Offline ML features, model training | <1hour |
| **Online ML Systems** | Redis/Pinot | Real-time features (demand surge, ETA) | <100ms |
| **Finance Team** | Snowflake (Gold) | Revenue reporting, reconciliation | <1day |

---

## 9️⃣ End-to-End Failure Scenarios

### Scenario 1: Kafka Down

```
What happens:
1. Producers buffer locally (SDK retry logic)
2. Flink/Pinot/Snowflake continue on buffered data
3. No data loss (Kafka replicas eventually recover)

Recovery:
1. Kafka restarts
2. Producers flush buffered events
3. Flink catches up (few minutes)
4. Normal operation resumes

Duration: 5-30 minutes
Impact: Slight latency, no data loss
Customer-facing: No (Redis/Pinot have recent data)
```

### Scenario 2: Flink Down

```
What happens:
1. Redis becomes stale (no new updates)
2. Pinot becomes stale (no new aggregates)
3. Kafka backlog accumulates (safe)
4. Apps use stale Redis data (temporary)

Recovery:
1. Flink checkpoint restored from S3
2. Reprocess Kafka offsets since checkpoint
3. Redis/Pinot re-populated
4. Systems live again

Duration: 1-5 minutes (replay time depends on lag)
Impact: Slightly stale data for 1-5 min
Customer-facing: Yes (stale but functional)

Prevent:
- Run Flink on Kubernetes with auto-restart
- Use rolling deployments (canary 10%, then 50%, then 100%)
```

### Scenario 3: Redis Down

```
What happens:
1. APIs can't get order status → Return cached data to apps
2. Flink still running (writing to Redis fails, retries)
3. Dashboards still work (they read Pinot)

Recovery:
1. Redis restarts
2. Flink repopulates (queries latest state from Kafka offset)
3. Normal operation resumes

Duration: <1 minute
Impact: Stale data briefly (cached at app layer)
Customer-facing: No (falls back to cached)
```

### Scenario 4: Pinot Down

```
What happens:
1. Ops dashboards unavailable
2. Flink/Redis unaffected
3. Core business unaffected

Recovery:
1. Pinot restarts
2. Flink replays recent events (last few hours)
3. Dashboards live again

Duration: <5 minutes
Impact: Ops blind for 5 min
Customer-facing: No (no customer impact)
```

### Scenario 5: Snowflake Down

```
What happens:
1. Analytics delayed
2. Historical data unavailable
3. Kafka/Flink/Redis unaffected (live serving unaffected)

Recovery:
1. Snowflake restarts
2. S3 backlog auto-drained
3. Metrics caught up

Duration: <30 minutes
Impact: Delayed analytics (acceptable)
Customer-facing: No (no impact)
```

---

## 🔟 Key Trade-offs (Say These Explicitly)

### ✅ What We Gain

| Trade-off | Benefit |
|-----------|---------|
| **SLA isolation** | Serving failure doesn't break analytics |
| **Predictable latency** | Each system optimized for its SLA |
| **Cost control** | Pay for what you use (Redis small, Snowflake big) |
| **Replayability** | Can recompute from Kafka/S3 |
| **Failure isolation** | 5 independent systems, not 1 monolith |

### ❌ What We Accept

| Trade-off | Cost | Mitigation |
|-----------|------|-----------|
| **Data duplication** | 2-3 copies (Redis, Pinot, Snowflake) | Acceptable for this scale |
| **Eventual consistency** | Redis lags by 1-5 sec | Fine for serving use cases |
| **Operational complexity** | 5 systems to monitor | Benefit outweighs cost |
| **Learning curve** | Teams need Kafka/Flink expertise | Hire/train accordingly |

---

## 8️⃣ KPI COVERAGE MATRIX (Interview MUST-KNOW)

### Which Layer Tracks Which KPIs

| KPI | Layer(s) | Latency | Update Freq | Notes |
|-----|----------|---------|-------------|-------|
| **Orders Per Minute** | Pinot (Ops), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot), Per-hour (Snowflake) | Live ops dashboard |
| **Delivery SLA %** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot), Per-day (Snowflake) | P50/P95/P99 latency |
| **Popular Items Per City** | Pinot (Live), Snowflake (Trending) | <500ms (Pinot) | Per-minute (Pinot), Per-day (Snowflake) | Real-time trends |
| **Active Drivers** | Redis (Latest), Pinot (Analytics) | <1ms (Redis), <500ms (Pinot) | Real-time (Redis), Per-minute (Pinot) | Exact count in Pinot |
| **DAU/MAU** | Snowflake (Gold) | <2min | Per-day (DAU), Per-month (MAU) | Historical tracking |
| **Conversion Rate** | Snowflake (Gold) | <2min | Per-day, Per-hour | Funnel analysis |
| **ARPU** | Snowflake (Gold) | <2min | Per-day | Average revenue per user |
| **LTV** | Snowflake (Gold) | <1day | Per-day | Lifetime value |
| **Churn Rate** | Snowflake (Gold) | <1day | Per-week | User retention |
| **Latency (P50/P95/P99)** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot) | SLA tracking |
| **Error Rate** | Pinot (Live), Snowflake (Historical) | <500ms (Pinot) | Per-minute (Pinot) | Service health |

### Key Points
- **No KPI is missing** — Each has appropriate layers
- **Real-time KPIs**: Pinot (5-minute granularity)
- **Business KPIs**: Snowflake (hourly/daily granularity)

---

## 9️⃣ WHO USES WHAT (Interview MUST-KNOW)

| Persona | System | Use Case | SLA |
|---------|--------|----------|-----|
| **Customer/Dasher Apps** | Redis | Order status, location | <1ms |
| **Ops/SRE Dashboard** | Pinot | Zone health, SLA % | <500ms |
| **Business Dashboard** | Snowflake (Gold) | Daily KPIs | <2min |
| **Data Analysts** | Snowflake (Silver) | Ad-hoc analysis | <5min |
| **Data Scientists** | Snowflake/S3 | ML features | <1hour |
| **Online ML Systems** | Redis/Pinot | Real-time features | <100ms |
| **Finance Team** | Snowflake (Gold) | Revenue reporting | <1day |

---

## 1️⃣0️⃣ END-TO-END FAILURE SCENARIOS

> "**Kafka** is our ingestion backbone — high-throughput, durable, replayable.
> 
> **Flink** is our stream processor — validates, deduplicates, reorders, routes by SLA.
> 
> **Redis** serves realtime user experiences — sub-millisecond order status and locations.
> 
> **Pinot** powers ops dashboards — sub-second operational analytics.
> 
> **S3 + Snowflake** provide deep analytics — immutable history, business metrics, reporting.
> 
> Spikes are absorbed by Kafka. Late events are handled by Flink. Backfills come from S3. Failures are isolated by design.
> 
> Each SLA tier is independent — serving doesn't depend on analytics."

---

## 1️⃣1️⃣ Deployment & Scaling Strategy

### Kafka Scaling

```
Volume scaling:
- Add brokers (partitions auto-rebalance)
- Add partitions to topics
- Consumer group scales automatically

At 500K events/sec:
- 500 partitions across 50 brokers
- Replication factor 3
- Monthly cost: ~$50K AWS (including storage)
```

### Flink Scaling

```
Parallelism = number of task managers × slots per manager

Example:
- 50 task managers × 4 slots = 200 parallelism
- 200 parallel tasks processing 500K events/sec
- ~2500 events per task per sec (manageable)

Add more task managers as volume grows.
```

### Redis Scaling

```
Sharding Strategy:
- Order ID hash → shard 1-16
- Dasher ID hash → shard 1-16

Each shard:
- Master + 2 replicas
- <1ms latency maintained
- Can scale to 16+ shards if needed

Cost: $5K/month for 16 shards (16GB each)
```

### Pinot Scaling

```
Retention tiers:
- REALTIME: Last 7 days (hot, fast)
- OFFLINE: 7-90 days (archived, slower)
- COLD: >90 days (not queried)

Add more servers as data grows.
Cost: $30K/month for 7-day REALTIME + 90-day OFFLINE
```

### Snowflake Scaling

```
Auto-scaling:
- Partition by date (easy pruning)
- Cluster by event_type (query optimization)

As data grows:
- Increase warehouse size (1 credit/min → 4 credits/min)
- Add more warehouses (for concurrent analysts)

Cost: $50-100K/month for full history + active analysis
```

---

## 1️⃣2️⃣ Monitoring & Alerting

### Key Metrics to Monitor

```
Kafka:
- Consumer lag (alert if >5min behind)
- Broker health (disk space, CPU)
- Replication status

Flink:
- Checkpoint duration (alert if >30s)
- Backpressure (alert if >10%)
- Task failures (auto-restart)

Redis:
- Memory usage (alert if >90%)
- Replication lag (alert if >1s)
- Evictions (alert if increasing)

Pinot:
- Query latency P99 (alert if >1s)
- Ingestion lag (alert if >30s)
- Disk usage

Snowflake:
- Query queue time (alert if >5s)
- Failed queries (alert if >1%)
- Cost per query
```

### Dashboard Setup

```
Ops Dashboard (Pinot):
- Real-time metrics (5-sec granularity)
- Alerts for SLA breaches
- City-level health

Analytics Dashboard (Snowflake):
- Business KPIs
- Cohort analysis
- Trend reports

System Health Dashboard (Prometheus + Grafana):
- Kafka consumer lag
- Flink throughput
- Redis memory
- Pinot query latency
```

---

## 🎓 What Interviewers Look For

| Skill | Shown By | Example |
|-------|----------|---------|
| **Architecture thinking** | Choosing right tool for SLA | "Redis for <1ms, Pinot for <500ms" |
| **Failure thinking** | Isolating failures, independent systems | "Pinot down ≠ serving impact" |
| **Operational maturity** | Monitoring, recovery, scaling | "Checkpoints every 10s, RTO <5min" |
| **Trade-off thinking** | Admitting costs of design | "We pay in complexity to gain isolation" |
| **Scale-aware** | Handling 500K events/sec | "Kafka partitions scale independently" |

---

## 🏁 FINAL 30-SECOND SUMMARY (MEMORIZE THIS)

> "**Kafka** is our ingestion backbone — high-throughput, durable, replayable. It decouples producers from consumers and absorbs spikes without dropping data.
>
> **Flink** is our stream processor — validates, deduplicates, reorders events using watermarks, and handles late arrivals. It maintains small state (only SLA-critical) with exactly-once semantics.
>
> **Redis** serves realtime user experiences — sub-millisecond order status and locations. It's a cache, not a source of truth.
>
> **Pinot** powers ops dashboards — sub-second real-time analytics for zone health, SLA monitoring, and live metrics.
>
> **S3 + Snowflake** provide deep analytics — immutable history, business metrics, reporting, and ML features.
>
> **Failures are isolated by design**: Kafka down ≠ Flink down ≠ Pinot down. Each layer can fail independently without cascading.
>
> **Each SLA tier is independent** — serving doesn't depend on analytics. We accept eventual consistency and data duplication to gain isolation and cost efficiency."

---

## 1️⃣1️⃣ KEY TRADE-OFFS (Say These Explicitly)

### ✅ What We Gain

| Trade-off | Benefit | Why Worth It |
|-----------|---------|-------------|
| **SLA isolation** | Serving failure ≠ analytics failure | Prevents cascading |
| **Predictable latency** | Each system optimized for its SLA | Redis fast, Snowflake accurate |
| **Cost control** | Pay for what you use | Redis small, Snowflake big |
| **Replayability** | Can recompute from Kafka/S3 | Fixes bugs without data loss |
| **Failure isolation** | 5-6 independent systems, not 1 monolith | Limits blast radius |

### ❌ What We Accept

| Trade-off | Cost | Mitigation |
|-----------|------|-----------|
| **Data duplication** | 2-3 copies (Redis, Pinot, Snowflake) | Acceptable (1-2% cost increase) |
| **Eventual consistency** | Redis lags by 1-5 sec | Fine for serving use cases |
| **Operational complexity** | 6 systems to monitor | Tools/automation reduces burden |
| **Learning curve** | Teams need expertise | Hire/train accordingly |
| **Storage overhead** | 3 copies of data | S3 cheap; trade-off acceptable |

**Defense:** 
> "These are intentional trade-offs, not accidental complexity. We gain isolation, predictability, and cost efficiency at the cost of operational complexity. The business benefit outweighs the engineering cost."

---

## 1️⃣2️⃣ COMMON HARD QUESTIONS & STRONG ANSWERS

### Q: What's the weakest component in this architecture?
**A:** Flink. It's stateful and checkpoint-sensitive. If checkpoints corrupt or get large (>100GB), recovery takes hours. Mitigation: Keep state intentionally small, run on Kubernetes with auto-restart, test recovery procedures quarterly.

### Q: Why not use only Snowflake?
**A:** Snowflake can't hit sub-second SLAs for operational dashboards. It's designed for analytical queries (seconds to minutes), not realtime point reads (milliseconds). We use Snowflake for what it's good at: deep analytics + history.

### Q: Why not use only Kafka → Flink → Redis?
**A:** We'd lose historical analytics capability. No long-term retention. No ad-hoc query capability. Need Snowflake for compliance, auditing, and business intelligence.

### Q: How do you protect Pinot from dashboard overload?
**A:**
1. API layer (rate limiting, authentication)
2. Caching (5-10 sec TTL on dashboard queries)
3. Query quotas (max concurrency per user)
4. Read replicas (distribute load)
5. Fallback (serve cached data if Pinot slow)

### Q: What happens if event_id collision occurs?
**A:** Mathematically impossible with UUID v4 (36^32 possibilities). If it did happen, deduplication would see it as duplicate (expected behavior). Mitigation: Monitor collision rate (should be 0).

### Q: How do you scale to 5M events/sec (10× volume)?
**A:** 
1. Add Kafka brokers (50 → 500)
2. Add Flink task managers (32 → 320)
3. Add Redis shards (16 → 160)
4. Scale Pinot warehouses (add nodes)
5. Increase Snowflake warehouse size (4X-Large)
6. All scaling is linear; no architectural changes needed.

---

## 1️⃣3️⃣ INTERVIEW CHECKLIST

Before your interview, verify you can answer:

- [ ] Draw the full 6-layer architecture from memory
- [ ] Explain why each system is chosen (vs alternatives)
- [ ] Describe SLA tiers and failure isolation
- [ ] Walk through Kafka partitioning strategy for 500K events/sec
- [ ] Explain Flink late-event handling with watermarks and exactly-once
- [ ] Justify Redis vs Snowflake for serving
- [ ] Describe 3+ failure scenarios + recovery (RTO, data loss)
- [ ] Explain KPI coverage matrix (which layer tracks what)
- [ ] Calculate cost at 500K events/sec
- [ ] Scale to 10× volume (5M events/sec)
- [ ] Describe monitoring strategy (which metrics matter)
- [ ] Admit trade-offs confidently ("We accept X to gain Y")
- [ ] Answer 5 common follow-up questions
- [ ] Name one "weakest component" (Flink is hardest to operate)
- [ ] Explain backfill strategy (S3 is system of record)
- [ ] Describe deduplication strategy (event_id + window)
- [ ] Explain why each layer is independent (isolation first)

---

## 1️⃣4️⃣ SYSTEM HEALTH MONITORING

### Key Metrics to Monitor

```
Kafka:
  ├─ Consumer lag (alert if >5min behind)
  ├─ Broker health (disk space, CPU)
  ├─ Replication status
  └─ Topic volume spikes (alert if >5× baseline)

Flink:
  ├─ Checkpoint duration (alert if >30s)
  ├─ Backpressure % (alert if >10%)
  ├─ Task failures (auto-restart)
  ├─ State size (trending)
  └─ Watermark lag (alert if >10min)

Redis:
  ├─ Memory usage (alert if >90%)
  ├─ Replication lag (alert if >1s)
  ├─ Evictions (alert if increasing)
  └─ Connection count (anomaly detection)

Pinot:
  ├─ Query latency P99 (alert if >1s)
  ├─ Ingestion lag (alert if >30s)
  ├─ Disk usage
  └─ Failed queries (alert if >1%)

Snowflake:
  ├─ Query queue time (alert if >5s)
  ├─ Failed queries (alert if >1%)
  ├─ Cost per query
  └─ Warehouse utilization
```

---

END OF DOCUMENT
```

