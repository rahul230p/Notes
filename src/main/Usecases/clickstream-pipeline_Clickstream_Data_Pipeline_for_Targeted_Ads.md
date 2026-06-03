# Clickstream Data Pipeline for Targeted Ads

Source: https://datapathsala.com/system-design/clickstream-pipeline

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# Clickstream Data Pipeline for Targeted Ads

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a real-time clickstream data pipeline for a large-scale e-commerce
platform. The system needs to capture user behavior, page views, clicks, add-
to-cart events, and purchases, across web and mobile, and process this data to
power targeted ad campaigns. Expect around 500K events per second at peak. How
would you design this end to end?”

Expand AllCollapse All17 sections + 3 cloud implementations

How to Approach This Problem

## What the Interviewer Is Actually Testing

The interviewer isn't checking if you know what Kafka is. They're evaluating:

  * **Judgment under ambiguity** : Can you define scope from a vague problem statement?
  * **Architectural reasoning** : Do you explain _why_ you picked each component, not just _what_?
  * **Awareness of failure modes** : Do you proactively call out what breaks before being asked?
  * **Cross-cutting ownership** : Can you speak to privacy, cost, and operational complexity, not just the happy path?
  * **Trade-off fluency** : Every architectural decision is a trade-off. Can you name the cost of your choice?

## Interview Approach (45–60 min)

Phase| Focus| What a Strong Answer Looks Like  
---|---|---  
**Scoping (5 min)**|  Define functional + non-functional bounds| Ask about the
_specific hard problems_ : "Is identity resolution in scope? Do we need cross-
device attribution? What's the latency SLA for ad targeting?"  
**Architecture sketch (8 min)**|  Dual-path, name each component, state the
_why_|  Explain the architectural pattern first ("Lambda, because ad targeting
needs sub-second profiles AND heavy historical reprocessing, Kappa can't do
both cost-effectively")  
**Component deep-dives (20 min)**|  Walk each layer, proactively raise failure
modes| Don't wait to be asked. Say "The hard part here is identity resolution,
let me explain how I'd handle it"  
**Data modeling (5 min)**|  Schema, partitioning, SCD types| Cover
partitioning strategy and _explain the query patterns that drive it_  
**Operational concerns (5 min)**|  Backfill, GDPR, schema evolution, cost| Own
the system beyond the initial build. Bring up deletion, backfill, and schema
evolution without being prompted.  
**Monitoring & alerts (5 min)**| Which metrics, what thresholds, who gets
paged| Connect metrics to business outcomes ("consumer lag > 100K means ad
targeting is stale, direct revenue impact")  
  
## Common Pitfalls That Weaken an Answer

  * **Naming tools without justification** : "I'd use Kafka" with no rationale. Every choice needs a "because."
  * **Building in a vacuum** : Not mentioning GDPR, cost, or operational complexity until asked.
  * **Avoiding trade-offs** : If you say "I'd use Flink because it's better than Spark Streaming," you need to also say what you give up (operational complexity, team expertise requirement).
  * **Ignoring identity resolution** : This is the hardest problem in any clickstream system. If you don't bring it up, the interviewer will.
  * **Missing the feedback loop** : The pipeline feeds an ML model that feeds back into the pipeline. Not mentioning this signals you've never owned an end-to-end ML system.

## Opening Move (First 30 Seconds)

> "Before I design anything, let me make sure I understand the system
> boundaries. I'm assuming this pipeline needs to: (1) serve a real-time ad-
> targeting system with sub-second feature freshness, (2) build audience
> segments for batch-scheduled campaigns, and (3) power analytics dashboards.
> The hardest problems I see are identity resolution across anonymous and
> authenticated sessions, and the feedback loop between ad impressions and the
> targeting model. Does that framing sound right?"

Starting this way shows you've identified the non-obvious hard problems before
drawing a single box, that's what makes an answer stand out.

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

500K events/secSchema Registry + publishreal-time streamsession stateenriched
eventsbatch consumebronze → silvergold (aggregated)orchestratesfailed
eventsreprocess after fixbackfill

Web/Mobile SDK

API Gateway / ALB

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Flink (Real-Time)

Redis (User State)

![Spark \(Batch\)](/icons/tools/spark.svg)Spark (Batch)

![Airflow](/icons/tools/airflow.svg)Airflow

Data Lake (S3/GCS)

Data Warehouse

Dead Letter Queue

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation & Capacity Planning

Architecture Walkthrough, End-to-End Data Flow

Component Deep Dive

Identity Resolution & The Identity Graph

Ad Serving Integration & The Feedback Loop

Data Modeling & Schema Design

Backpressure Handling

Exactly-Once Delivery

Late Data Arrival

Scalability & Fault Tolerance

Privacy & Compliance

Monitoring & Observability

Common Follow-Up Questions

Technology Comparison Table

Whiteboard Summary & Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

eventsAPI Gateway → publishreal-time streamsession stateenriched eventsbatch
deliveryParquet (bronze)ETL (silver → gold)Gold tablesorchestrates +
backfillfailed eventsreprocess

Web/Mobile SDK

CloudFront + ALB

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Managed Flink

ElastiCache Redis

![Kinesis Firehose](/icons/aws/kinesis.svg)Kinesis Firehose

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![AWS Glue ETL](/icons/aws/glue.svg)AWS Glue ETL

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

MWAA (Airflow)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "Since we're on AWS, I'd build around Kinesis for ingestion, Managed Flink
> for stream processing, S3 + Iceberg as the lakehouse, and Redshift
> Serverless for the warehouse."

### End-to-End Data Flow

    
    
    1. SDK sends click events → CloudFront (CDN + edge caching) → API Gateway validates
    2. API Gateway publishes to Kinesis Data Streams (partitioned by user_id)
    3. TWO parallel paths from Kinesis:
    
       REAL-TIME PATH:
       Kinesis → Managed Flink → session windowing, identity resolution, feature computation
                               → writes session state to ElastiCache Redis (sub-ms reads)
                               → writes enriched events to S3 (Iceberg format)
    
       BATCH PATH:
       Kinesis → Kinesis Firehose → auto-delivers Parquet to S3 (bronze layer, zero code)
       S3 → AWS Glue ETL → dedup, enrich (silver) → aggregate (gold) → load to Redshift
    
    4. Failed events → SQS DLQ → inspect, fix, reprocess back to Kinesis
    5. MWAA (Airflow) orchestrates Glue batch jobs, backfills, GDPR deletion
    

### Why Each Component

### Event Ingestion: Kinesis Data Streams

**Why Kinesis over self-managed Kafka on AWS?**

  * Fully managed, no broker patching, ZooKeeper, or rebalancing
  * Native integration with Managed Flink, Firehose, Lambda, and CloudWatch
  * On-demand mode eliminates shard capacity planning (auto-scales to any throughput)
  * Trade-off: Less flexible than Kafka (no compacted topics, limited retention to 365 days, no multi-DC replication). If you need replay beyond 7 days or topic compaction, use Amazon MSK (managed Kafka) instead.

**Config for this pipeline:**

  * On-demand mode (auto-scaling, no shard management)
  * Enhanced fan-out for dedicated throughput per consumer (Flink gets isolated read throughput)
  * 7-day retention for replay capability

### Real-Time Processing: Amazon Managed Service for Apache Flink

**Why Managed Flink?**

  * Same Flink engine as open-source, no code changes if migrating from self-hosted
  * Auto-scaling based on CPU and backpressure (Kinesis consumer lag)
  * Managed checkpointing to S3, no RocksDB tuning needed
  * Native Kinesis connector with exactly-once via checkpoint-based offset tracking
  * Trade-off: Slightly higher latency (~1-3 sec) than self-hosted Flink (~100ms) due to managed overhead. Acceptable for this use case.

### Batch Delivery: Kinesis Data Firehose

**Why Firehose?**

  * Zero-code delivery from Kinesis to S3 in Parquet format with Snappy compression
  * Automatic batching (buffer size/interval), no Spark job needed for raw landing
  * Built-in data transformation via Lambda (e.g., add ingestion timestamp, flatten nested JSON)
  * Handles the Bronze layer of the medallion architecture with zero operational effort
  * Trade-off: Limited transformation capability. Complex enrichment still needs Flink or Glue.

### Data Lake: S3 + Apache Iceberg

**Why Iceberg on S3?**

  * ACID transactions on S3, concurrent reads/writes without corruption
  * Time travel for rollback and auditing (`SELECT * FROM table VERSION AS OF timestamp`)
  * Schema evolution, add/rename columns without rewriting data
  * Hidden partitioning, users don't need to know partition structure in queries
  * Open format, readable by Glue, Athena, Redshift Spectrum, Spark, Trino
  * Why Iceberg over Delta Lake on AWS: Iceberg has first-class AWS support (Athena, Glue, EMR), while Delta Lake is more Databricks-native. Both are good choices.

### Batch Processing: AWS Glue (Spark)

**Why Glue over EMR?**

  * Serverless, no cluster management, auto-scales workers, pay only for DPU-hours
  * Built-in Data Catalog (Hive metastore compatible), shared metadata across Athena, Redshift, Glue
  * Native Iceberg support for MERGE operations (dedup, SCD updates)
  * Glue Flex execution: up to 60% cost savings for non-time-critical batch jobs
  * Trade-off: Less control than EMR (no custom AMIs, limited Spark config tuning). For heavy ML or complex Spark jobs, EMR is better.

**Batch jobs orchestrated by MWAA (Airflow):**

  * Bronze → Silver: hourly dedup + enrichment (`MERGE INTO` on Iceberg)
  * Silver → Gold: daily aggregation for audience segments
  * Backfill: on-demand reprocessing triggered via Airflow DAG

### Data Warehouse: Redshift Serverless

**Why Redshift Serverless?**

  * Auto-scales compute, no cluster sizing, no node type selection
  * Pay-per-query, ideal for variable analytical workloads
  * Redshift Spectrum queries S3 data directly (no loading needed for ad-hoc analysis)
  * Native Iceberg table support, query the lake directly as external tables
  * Materialized views for pre-computed Gold layer aggregations
  * Trade-off: Less cost-effective than provisioned Redshift for steady-state high-concurrency. If query volume is predictable, consider provisioned RA3 nodes.

### Real-Time State: ElastiCache Redis

**Why ElastiCache Redis?**

  * Sub-millisecond reads, fast enough for real-time session state lookups
  * Redis Cluster mode for horizontal scaling (hash-slot-based sharding)
  * Automatic failover with Multi-AZ replicas
  * Key design: `user:{id}:session` → current session features (JSON), TTL 24h
  * Trade-off: In-memory = expensive for large datasets. For user event history (>7 days), use DynamoDB instead (cheaper, still single-digit ms latency).

### Orchestration: MWAA (Managed Airflow)

**Why MWAA?**

  * Fully managed Airflow, no worker scaling, no metadata DB, no webserver ops
  * Native AWS operators: GlueJobOperator, RedshiftDataOperator, S3 sensors
  * Handles: batch scheduling, backfill triggers, GDPR deletion pipelines, data quality checks
  * Trade-off: MWAA has cold-start delays and is more expensive than self-hosted. For cost-sensitive setups, Step Functions + EventBridge is cheaper but less flexible.

### Monitoring: CloudWatch

**Key Metrics to Watch:**

Metric| Source| Alert  
---|---|---  
`IncomingRecords`| Kinesis| Drop > 20% → ingestion failure  
`MillisBehindLatest`| Flink/KCL| > 60,000ms → consumer lag  
Flink checkpoint duration| CloudWatch Logs| > 30 sec → state too large  
Glue job duration| Glue metrics| > 2x baseline → data volume spike  
DLQ message count| SQS metrics| > 1,000 → schema/processing issue  
S3 storage growth| S3 metrics| Exceeds budget forecast  
  
### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Kinesis| On-demand mode (no over-provisioned shards)| 30-50%  
Glue| Flex execution for batch jobs| Up to 60%  
S3| Lifecycle: Standard → IA (30d) → Glacier (1y)| 60-80% on cold data  
Redshift| Serverless auto-pause when idle| Pay only when queried  
ElastiCache| Reserved instances for steady-state| 30-40%

