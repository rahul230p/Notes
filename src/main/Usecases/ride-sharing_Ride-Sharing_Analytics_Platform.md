# Ride-Sharing Analytics Platform

Source: https://datapathsala.com/system-design/ride-sharing

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Ride-Sharing Analytics PlatformAdd
Note

# Ride-Sharing Analytics Platform

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a real-time analytics platform for a ride-sharing company like Uber or
Lyft. The system must ingest GPS location streams from 5 million active
drivers (reporting every 2 seconds), power dynamic surge pricing based on
supply-demand ratios per geographic zone, compute accurate ETAs, and produce
daily KPI dashboards, trip volume, revenue, driver utilization, rider wait
times, and city-level performance. The platform spans 500+ cities worldwide.
How would you design the data infrastructure end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Ride-sharing system design looks like a standard streaming pipeline question
until the interviewer starts probing. The three problems that separate strong
answers from average ones are each fundamentally different in nature:
geospatial indexing, stream-computed caching, and distributed state machine
consistency. Surface-level answers treat all three as database or Kafka
problems. Strong answers identify the right tool class for each.

### The Three Hard Problems Unique to Ride-Sharing

**Real-time geospatial driver matching is a geospatial index problem, not a
database query problem.** All 5 million active drivers update their location
every 3-5 seconds. When a rider requests a trip, the system must find the
nearest available driver within 2 seconds. A SQL SELECT with a distance
calculation over millions of driver rows cannot meet that latency budget, even
with a spatial index. Strong answers reach for Redis GEOSEARCH or H3/S2
hexagonal spatial indexing. With H3 at resolution 9, each cell covers roughly
0.1 square kilometers. Storing driver sets in Redis sorted sets keyed by H3
cell index gives O(1) lookup of all drivers in any cell, and k-ring expansion
to neighboring cells is a single arithmetic operation on the index, not a
radius scan. This is the foundation the entire matching system is built on.

**Surge pricing must be computed continuously but served from cache.** Surge
is a function of demand over supply per geographic cell, and it needs to be
recomputed every 30-60 seconds across 500,000 active H3 cells globally.
Recomputing on every pricing call, even with fast aggregation queries, would
require 500,000 parallel computations per request, which is prohibitively
expensive. The correct architecture pre-computes surge per H3 cell on a
sliding window using stream processing (Flink or Dataflow), writes results to
Redis with a TTL that matches the recalculation interval, and serves every
pricing call from cache. The stream processor owns the compute; Redis owns the
serve path. These two concerns must be separated.

**Trip state machine consistency across distributed services is where
financial data loss hides.** A trip moves through the states: requested,
accepted, driver_arriving, in_trip, completed, settled. Each transition is
triggered by a different actor (rider app, driver app, payment service) across
different services. Without strict guarantees, a network retry can double-
charge a rider, a crash between payment and driver payout can leave a driver
unpaid, or a stuck state can orphan a trip indefinitely. Strong answers define
the trip as an event-sourced state machine with Kafka as the durable event
log. Each state transition event carries an idempotency key and a version
number. Consumers are idempotent: processing the same event twice produces the
same result. This is the only architecture that provides exactly-once
semantics across distributed services without distributed transactions.

### What the Interviewer Is Testing

Signal| What a Strong Answer Does  
---|---  
Geospatial reasoning| Identifies H3/S2 hexagonal indexing as the right
primitive; explains why SQL distance queries fail at this scale  
Stream vs batch tradeoffs| Separates surge computation (stream) from surge
serving (cache); does not conflate them  
Consistency guarantees| Defines idempotency keys and version vectors for trip
state; cites event sourcing as the pattern  
Capacity reasoning| Derives 2.5M events/sec from 5M drivers at 2-second
intervals before picking Kafka partition count  
Failure mode thinking| Explains what happens to matching quality when Redis is
degraded, not just when it is healthy  
  
### Structured Walkthrough

Step| Focus| Time  
---|---|---  
1| Clarify scale: driver count, GPS interval, surge freshness, trip volume per
day| 3 min  
2| Draw the three data paths: GPS ingestion to Redis, surge computation loop,
trip event log| 5 min  
3| Deep dive geospatial matching: H3 resolution choice, k-ring expansion, ETA
ranking over straight-line distance| 8 min  
4| Deep dive surge pricing: sliding window in Flink, Redis write with TTL,
anti-gaming freeze rule| 7 min  
5| Deep dive trip state machine: idempotency keys, version vectors, Kafka as
durable log, reconciliation job| 7 min  
  
### Your Opening Move

> "Before I start designing, let me confirm the three workloads that drive
> every architecture decision here. First, 5 million drivers streaming GPS
> every 2 seconds is 2.5 million location updates per second, which rules out
> any real-time matching approach that touches a relational database. Second,
> surge pricing needs to reflect current supply and demand within 30 seconds,
> which means pre-computation on a stream processor writing to cache, not
> query-time aggregation. Third, trip state transitions touch payment, so I
> need exactly-once guarantees with idempotent consumers backed by Kafka as
> the durable log. Does that match what you are looking for?"

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

2.5M loc/sectrip requestspublish eventslocation + demand streamsurge
multipliers per H3 cellGPS streamdriver location indexgeofence + city
zonestrip eventstrip telemetrybatch ETLKPI aggregatesorchestratesreal-time
featuresETA predictionsfailed eventsreprocess after fixbackfill

Driver App (GPS)

Rider App (Requests)

API Gateway

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Flink (Surge Pricing)

Flink (Geo Indexing)

Flink (Trip Lifecycle)

Redis (Driver Loc + Surge)

PostGIS (Geo Data)

![Spark \(Batch\)](/icons/tools/spark.svg)Spark (Batch)

![Airflow](/icons/tools/airflow.svg)Airflow

Data Lake (S3/GCS)

Data Warehouse

ML Service (ETA)

Dead Letter Queue

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation & Capacity Planning

Architecture Walkthrough

Component Deep Dive

Data Modeling

Surge Pricing & Supply-Demand Matching

Scalability & Fault Tolerance

Monitoring & Observability

ETA Prediction & Trip Analytics

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

2.5M loc/sectrip requestspublish eventsreal-time streamgeofencingdriver state
+ surgelocation index + cacheGPS trails + trip databatch ETLKPI
aggregatesorchestratesreal-time featuresfailed eventsreprocess

Driver App (GPS)

Rider App

API Gateway + NLB

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Managed Flink

Location Service

![DynamoDB \(Driver State\)](/icons/aws/dynamodb.svg)DynamoDB (Driver State)

ElastiCache Redis

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

AWS Glue ETL

MWAA (Airflow)

SageMaker (ETA)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around Kinesis for GPS ingestion, Managed Flink for real-
> time surge and geo-indexing, DynamoDB for driver state, ElastiCache Redis
> for real-time lookups, and S3 + Iceberg for the data lake."

### End-to-End Data Flow

    
    
    1. Driver App sends GPS heartbeats -> API Gateway + NLB (TLS termination, rate limiting)
    2. API Gateway publishes to Kinesis Data Streams (partitioned by city_id sub-key)
    3. Kinesis -> Managed Flink (three jobs: surge pricing, geo-indexing, trip lifecycle)
    4. Flink Surge -> ElastiCache Redis (surge multipliers per H3 cell, 30-sec refresh)
    5. Flink Geo -> ElastiCache Redis (driver location sorted sets per H3 cell)
    6. Flink Geo -> DynamoDB (driver availability state, current trip, vehicle info)
    7. Flink Trip -> S3 Iceberg (GPS trails, trip telemetry in Parquet)
    8. Rider request -> API Gateway -> ElastiCache (H3 k-ring driver lookup)
         -> Location Service (geofencing) -> OSRM on ECS (ETA ranking) -> match
    9. S3 -> Glue ETL (daily KPI aggregation) -> Redshift Serverless (dashboards)
    10. MWAA (Airflow) orchestrates Glue jobs, SageMaker retraining, data quality checks
    11. Failed events -> SQS DLQ -> CloudWatch alarm -> inspect, fix, replay to Kinesis
    

### GPS Ingestion: Kinesis Data Streams

**Why Kinesis for GPS at 2.5M events/sec?**

  * On-demand mode auto-scales shards, no manual capacity planning for bursty traffic
  * Enhanced fan-out provides dedicated 2 MB/sec per consumer per shard (Flink gets isolated throughput)
  * 7-day retention enables replay for backfill or incident recovery
  * Native integration with Managed Flink, no connector configuration
  * Trade-off: At 500 MB/sec sustained, Kinesis on-demand is expensive (~$36K/month for ingestion alone). For cost optimization, use provisioned mode with 500+ shards and auto-scaling policies. Alternatively, use Amazon MSK (managed Kafka) for even higher throughput at lower per-GB cost.

**Config:** On-demand mode (simplicity) or provisioned with 500 shards and
auto-scaling. Enhanced fan-out for each Flink consumer group.

### Real-Time Processing: Managed Flink

**Why Managed Flink?**

  * Same Apache Flink engine, keyed state per driver_id and per H3 cell works identically to open-source
  * Auto-scaling based on Kinesis consumer lag (IncomingRecords metric)
  * Managed checkpointing to S3, RocksDB state backend with incremental checkpoints
  * Three separate Flink applications: surge (50 KPUs), geo-indexing (200 KPUs), trip lifecycle (50 KPUs)
  * Cost: ~$0.11/KPU-hour. At 300 KPUs total = ~$24K/month
  * Managed Flink handles Apache ZooKeeper, JobManager HA, and TaskManager recovery automatically

### Driver State: DynamoDB

**Why DynamoDB for driver state?**

  * Single-digit millisecond reads/writes at any scale, critical for matching lookups
  * On-demand capacity mode handles the bursty pattern of ride requests (5K/sec normal, 50K/sec during events)
  * Global Tables for multi-region driver state (US, EU, APAC)
  * DynamoDB Streams for change data capture, trigger Lambda for driver analytics events
  * Partition key: `driver_id`. GSI on `city_id + status` for city-level driver queries
  * Cost: ~$1.25/million writes on-demand. At 2.5M driver state updates/sec from Flink: use provisioned mode with DAX cache to reduce write costs.

**ElastiCache Redis** complements DynamoDB for hot-path lookups: H3 driver
sorted sets and surge multiplier hashes stay in Redis (<1ms), while DynamoDB
holds the durable driver record.

### Real-Time Cache: ElastiCache Redis

**Why ElastiCache (Redis)?**

  * Sub-millisecond sorted set operations for H3 driver index (ZADD, ZRANGEBYSCORE)
  * Hash operations for surge multiplier cache per H3 cell
  * Redis Cluster mode: 3 shards with 1 replica each (6 nodes total, r6g.xlarge)
  * Total memory: ~1.6 GB active data with 30% headroom = well within 6-node cluster capacity
  * Automatic failover: replica promoted in <30 seconds if primary fails
  * Cost: ~$2,500/month for a 6-node r6g.xlarge cluster

### Routing: Amazon Location Service + OSRM on ECS

**Amazon Location Service** for geofencing:

  * Define geofences for airports, restricted zones, city boundaries
  * Evaluate driver GPS against geofences in real-time (Flink calls Location Service API)
  * Cost: $0.05 per 1,000 geofence evaluations

**OSRM on ECS Fargate** for ETA computation:

  * Self-hosted OSRM with pre-built road network graphs per region
  * ECS auto-scaling: 10-50 Fargate tasks based on ride request rate
  * ~50ms per route query, handles 10K routes/sec across the fleet
  * Cost: ~$3,000/month for ECS Fargate compute

### Data Lake: S3 + Apache Iceberg

**S3 + Iceberg for GPS telemetry and trip data:**

  * Flink writes GPS trails to S3 in Iceberg format with Parquet data files
  * Partitioning: `date / city_id / h3_index_r7` for efficient spatial + temporal queries
  * Iceberg snapshot isolation enables concurrent reads (Glue ETL) and writes (Flink) without conflict
  * Schema evolution: add new telemetry fields (e.g., accelerometer data) without rewriting existing partitions
  * S3 Lifecycle: Standard (90 days) -> S3 Intelligent-Tiering -> Glacier (1 year)
  * Cost: ~4.3 TB/day compressed = ~130 TB/month. S3 Standard: ~$3,000/month; after lifecycle policies: ~$1,500/month

### Analytics: Redshift Serverless + Glue

**Glue ETL** for batch processing:

  * Daily/hourly Spark jobs: trip aggregation, revenue rollup, driver utilization, rider wait times
  * Glue Data Catalog provides schema discovery for Iceberg tables
  * Glue crawlers auto-detect new partitions in S3

**Redshift Serverless** for analytics warehouse:

  * Pay-per-query: no cluster management, auto-scales RPUs based on query complexity
  * Materialized views for pre-computed city-level KPI dashboards
  * AQUA (Advanced Query Accelerator) for hardware-accelerated scans on large fact tables
  * Connects to QuickSight for operational dashboards

### ML: SageMaker for ETA Prediction

**SageMaker pipeline:**

  * **Training:** Daily retraining of LightGBM ETA correction model on last 30 days of trip data
  * **Feature Store:** Real-time features from Redis (current traffic speeds), batch features from S3 (historical patterns)
  * **Inference:** SageMaker real-time endpoint (ml.c5.xlarge, 5 instances, auto-scaling)
  * **Model monitoring:** SageMaker Model Monitor detects data drift in feature distributions
  * Cost: ~$5,000/month for training + inference endpoints

### Orchestration: MWAA (Managed Airflow)

**MWAA** for pipeline orchestration:

  * DAGs for: Glue ETL scheduling, SageMaker retraining triggers, data quality checks, Redshift refresh
  * Environment: mw1.medium (handles 50+ DAGs, 200+ tasks)
  * S3-backed DAG storage with Git sync for version control
  * Cost: ~$1,200/month

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Kinesis| Provisioned mode with auto-scaling (vs on-demand)| 30-40%  
Managed Flink| Right-size KPUs per job; auto-scale during off-peak| 20-30%  
DynamoDB| Provisioned + DAX cache (reduce direct reads by 80%)| 50-60%  
ElastiCache| Graviton-based instances (r7g vs r6g)| 15-20%  
S3| Intelligent-Tiering + Glacier lifecycle| 50-70% on aged data  
Redshift| Serverless (pay per query, not per cluster hour)| 40-60% for bursty
analytics  
SageMaker| Spot instances for training, auto-scaling for inference| 50-70% on
training  
OSRM/ECS| Fargate Spot for non-critical routing pre-computation| 60-70%

