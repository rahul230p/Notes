# 1M Requests/Sec Pipeline to Data Warehouse

Source: https://datapathsala.com/system-design/high-throughput-pipeline

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)1M Req/Sec Pipeline to WarehouseAdd
Note

# 1M Requests/Sec Pipeline to Data Warehouse

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a high-throughput data pipeline that ingests 1 million events per
second from distributed API servers, processes them with exactly-once
semantics, and loads the data into a data warehouse with less than 5-minute
freshness. The system must handle 10x traffic spikes gracefully using
backpressure mechanisms at every layer, support schema evolution without
downtime, and guarantee no data loss or duplication in the warehouse. How
would you architect this end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

> "Before you draw a single box, tell the interviewer: this problem has three
> hard subproblems that most candidates miss. Naming them upfront signals you
> have been burned by them in production."

### The Three Hard Problems Unique to High-Throughput Pipelines

**1\. Backpressure without data loss is harder than it looks.**

When consumers are slower than producers, you must buffer, drop, or slow the
producer. Naive implementations drop silently or cascade failures upstream.
The right answer uses Kafka as the decoupling buffer between producers, which
write at their rate, and consumers, which read at their rate. But naming Kafka
is not enough. You need to explain how consumer lag is monitored (records-lag-
max per partition in Prometheus), what threshold triggers action (5 minutes of
lag), and what action is taken (Flink parallelism increase via reactive
scaling). Strong candidates also explain the full backpressure chain: client
SDK exponential backoff, API server token bucket with HTTP 429, Kafka producer
buffer.memory with max.block.ms, Flink credit-based flow control between
operators, and warehouse COPY concurrency limits with a circuit breaker. Every
layer must have a valve, because a pipeline without backpressure at the
warehouse layer will absorb a 15-minute outage and then hammer the recovering
warehouse with 5 parallel COPY jobs and cause a second outage.

**2\. Exactly-once semantics requires coordination at every boundary
crossing.**

Each hop, meaning Kafka produce, Flink process, and sink write, can fail
independently. Without explicit coordination, retries produce duplicates. The
full chain is: Kafka idempotent producer (enable.idempotence=true, which
deduplicates retries within a producer session using sequence numbers), Kafka
transactional API (for atomic multi-partition writes when a single logical
event touches multiple topics), Flink two-phase commit checkpointing via the
Chandy-Lamport algorithm (the sink only makes S3 files visible after a
checkpoint is fully committed, so a Flink restart always replays from the last
committed checkpoint with no partial writes visible), and idempotent or
transactional sink writes at the warehouse (upsert by event_id using MERGE, so
even if the same Parquet file is loaded twice due to an Airflow retry, the
warehouse ends up with exactly one row per event). Break any link in this
chain and you get either duplicates or data loss. Interviewers specifically
listen for whether you understand that Flink two-phase commit is what connects
Flink processing state to S3 visibility, not just checkpointing in general.

**3\. Schema evolution is the unglamorous problem that breaks production
pipelines.**

A new field is added to an upstream event. Downstream consumers crash
expecting the old schema. This scenario plays out regularly at companies that
skip schema governance. The solution has three parts. First, introduce a
Schema Registry (Confluent Schema Registry is the standard) so that every
schema version is stored centrally and every producer and consumer validates
against a registered version before reading or writing. Second, use Avro or
Protobuf with explicit compatibility modes: BACKWARD compatibility means a new
schema can read data written with the old schema, which is the safe default
for adding optional fields. Third, consumers must provide default values for
new fields so that they do not crash when reading older records that predate
the new field. The dual-write pattern for breaking changes (add new field, run
both old and new fields in parallel for one retention window, migrate
consumers, then remove old field) is the only safe way to rename or remove a
field at 1M events/sec without downtime.

### What the Interviewer Is Testing

Dimension| What They Are Looking For  
---|---  
**Systems thinking**|  Do you treat the pipeline as a chain of contracts, not
a collection of services?  
**Failure-first reasoning**|  Do you describe what breaks before you describe
what works?  
**Throughput intuition**|  Can you do envelope math and translate numbers into
component sizing decisions?  
**Operational maturity**|  Do you address monitoring, runbooks, and graceful
degradation, not just the happy path?  
**Trade-off awareness**|  Do you explain why you chose Kafka over Kinesis,
Flink over Spark Streaming, MERGE over INSERT?  
  
### Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| **Clarify requirements** : Confirm 1M/sec sustained vs peak, exactly-once
scope, freshness SLA, schema change frequency, warehouse platform| 3 min  
2| **Name the three hard problems** : Backpressure chain, exactly-once chain,
schema evolution. Draw the three-stage pipeline with two buffers (Kafka and
S3)| 4 min  
3| **Deep dive each layer** : Kafka partition sizing, Flink checkpointing and
dedup state, micro-batch COPY with MERGE, backpressure at every hop| 15 min  
4| **Data modeling** : raw_events table, event_processing_log for lineage,
warehouse_load_batches for ops, DLQ table| 5 min  
5| **Fault tolerance and monitoring** : Circuit breaker on the warehouse,
Kafka lag as the primary health signal, Flink checkpoint duration, freshness
SLA breach alert escalation| 5 min  
  
### Your Opening Move

> "I'd design this as a three-stage decoupled pipeline, where each stage is
> separated by a durable buffer, specifically Kafka between ingestion and
> processing, and S3 between processing and warehouse loading. The reason for
> two buffers is that this problem has three fundamentally different speed
> domains: clients write at bursty rates, Flink processes at a sustained rate,
> and warehouses load at a batch rate. Without explicit buffers at both
> transitions, a 15-minute warehouse outage cascades into data loss. Let me
> walk through the three hard problems this architecture has to solve, and
> then we can go deep on any layer you want."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

1M events/secround-robin + health checksvalidate schemaidempotent
produceexactly-once consumecheckpoint-committed ParquetCOPY / MERGE
(staging)trigger micro-batch loadsorchestrate MERGEthrottle producersscale
parallelismpoison pills / failuresreprocess after fixlag + throughput
metricsSLA breach alerts

Client Applications

Load Balancer (L7)

API Servers (Stateless)

Schema Registry

![Apache Kafka \(500+ Partitions\)](/icons/tools/kafka.svg)Apache Kafka (500+
Partitions)

Apache Flink (Dedup + Transform)

Backpressure Controller

S3 Staging (Parquet/Iceberg)

![Airflow \(Orchestrator\)](/icons/tools/airflow.svg)Airflow (Orchestrator)

Data Warehouse

Dead Letter Queue

Monitoring / Alerting

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation & Capacity Planning

Architecture Walkthrough

Component Deep Dive

Data Modeling

Backpressure & Flow Control

Scalability & Fault Tolerance

Monitoring & Observability

Schema Evolution & Data Governance

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

1M events/secpublishexactly-once streamcheckpoint-committed ParquetCOPY
commandIceberg MERGE deduporchestrate loadstrigger COPY + MERGEfailed
eventsreprocess

Client Applications

NLB + API Gateway

![Amazon MSK \(Kafka\)](/icons/aws/kinesis.svg)Amazon MSK (Kafka)

Managed Flink

![S3 \(Staging + Iceberg\)](/icons/aws/s3.svg)S3 (Staging + Iceberg)

![AWS Glue \(MERGE\)](/icons/aws/glue.svg)AWS Glue (MERGE)

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

MWAA (Airflow)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around NLB + API Gateway for ingestion, MSK (Managed
> Kafka) for the message backbone, Managed Flink for stream processing, S3
> with Iceberg for staging, Glue for catalog and ETL, Redshift Serverless for
> the warehouse, and MWAA for orchestration."

### End-to-End Data Flow

    
    
    1. Client applications send events -> NLB (L4, lowest latency) -> API Gateway (schema validation, throttling)
    2. API Gateway Lambda authorizer validates auth; request is forwarded to ECS/EKS API servers
    3. API servers produce to Amazon MSK (Managed Kafka) with idempotent producers
    4. MSK -> Managed Flink (exactly-once, checkpoint to S3)
    5. Flink writes checkpoint-committed Parquet files to S3 in Iceberg table format
    6. AWS Glue Data Catalog serves as the Iceberg catalog (Hive-compatible metastore)
    7. MWAA (Managed Airflow) orchestrates micro-batch COPY into Redshift Serverless
    8. Glue ETL jobs handle MERGE dedup on Iceberg staging tables before warehouse load
    9. Snowpipe-via-S3-notifications pattern: S3 event notifications -> SQS -> triggers COPY automatically
    10. CloudWatch + SNS for monitoring and alerting across all components
    

### Ingestion: NLB + API Gateway

**Why NLB over ALB?**

  * NLB operates at L4 (TCP), lowest latency (~100us vs ~5ms for ALB). For 1M events/sec, every millisecond matters at the ingestion layer.
  * NLB supports static IPs and PrivateLink, critical for VPC-peered producers in other accounts.
  * API Gateway sits behind NLB for schema validation, request throttling (account-level and per-client rate limits), and API key management.
  * API Gateway throttling acts as the first layer of backpressure: default 10,000 requests/sec per account, configurable up to millions with limit increase.

**Alternative for ultra-low-latency:** Skip API Gateway entirely. NLB ->
ECS/EKS API servers directly. Validate schemas in the application layer. Saves
~10ms per request but loses managed throttling.

### Message Backbone: Amazon MSK (Managed Kafka)

**Why MSK over Kinesis?**

  * MSK is Apache Kafka, same producer/consumer APIs, same exactly-once semantics, same partition model. No vendor lock-in on the messaging layer.
  * MSK Serverless mode eliminates broker sizing entirely, auto-scales partitions and throughput.
  * MSK Provisioned mode for predictable cost at sustained 1M events/sec (~30 brokers, kafka.m5.4xlarge).
  * MSK Connect for managed Kafka Connect connectors (S3 sink, Debezium CDC, etc.).
  * Tiered storage: MSK can offload cold segments to S3 automatically, reducing EBS costs for long retention.

**MSK configuration for this pipeline:**

    
    
    Broker type:            kafka.m5.4xlarge (16 vCPU, 64 GB RAM)
    Broker count:           30-50 (across 3 AZs)
    EBS per broker:         2 TB gp3
    Partitions:             500-1000 per topic
    Replication factor:     3
    min.insync.replicas:    2
    Encryption:             TLS in-transit, KMS at-rest
    Authentication:         IAM (recommended) or SASL/SCRAM
    

### Stream Processing: Managed Flink

**Why Managed Flink on AWS?**

  * Amazon Managed Service for Apache Flink, fully managed, auto-scales based on MSK consumer lag.
  * Managed checkpointing to S3, no RocksDB tuning or checkpoint storage management.
  * IAM integration for MSK, S3, Glue Catalog, and Secrets Manager access.
  * VPC deployment for private connectivity to MSK and Redshift.
  * Cost: ~$0.11/KPU-hour. For 500 parallelism: ~$55/hour = ~$40K/month.

**Flink sinks to S3 + Iceberg:**

  * Flink writes Parquet files using the Iceberg Flink sink.
  * Files are committed only after Flink checkpoint succeeds (two-phase commit).
  * Iceberg metadata is registered in AWS Glue Data Catalog automatically.
  * Partition layout: `s3://bucket/warehouse/events/dt=YYYY-MM-DD/hr=HH/`

### Staging: S3 + Iceberg + Glue Data Catalog

**S3 as the universal staging buffer:**

  * S3 scales infinitely, no throughput limits per bucket (3,500 PUT/sec per prefix; distribute across prefixes).
  * S3 event notifications trigger downstream loading (SNS/SQS pattern).
  * S3 Intelligent-Tiering for automatic cost optimization on staging data.
  * S3 Object Lock for compliance (immutable raw data for regulatory retention).

**AWS Glue Data Catalog:**

  * Serves as the Iceberg catalog, both Flink and Redshift read the same table metadata.
  * Glue Crawlers auto-discover new partitions (optional; Iceberg manages this natively).
  * Glue ETL (Spark) handles MERGE dedup on Iceberg tables for complex transformations.

**Snowpipe-equivalent pattern on AWS:**

    
    
    S3 PUT event -> S3 Event Notification -> SQS Queue -> Lambda trigger -> Redshift COPY command
    

This gives Snowpipe-like auto-ingest with 1-3 minute latency. Alternatively,
use Redshift auto-copy (preview feature) for native S3-to-Redshift auto-
loading.

### Warehouse: Redshift Serverless

**Why Redshift Serverless?**

  * Pay per RPU-hour (compute), no cluster management, auto-scales to handle COPY spikes.
  * Native COPY from S3 Parquet, highly optimized, parallelized across compute nodes.
  * Full SQL MERGE support for dedup loading.
  * Redshift Spectrum: query S3 Iceberg tables directly without loading (for ad-hoc exploration of staging data).
  * Concurrency scaling: automatic transient clusters handle query spikes during COPY loads.
  * Cost: ~$0.375/RPU-hour. Baseline 128 RPU = ~$48/hour for COPY workloads.

**Alternative, Snowflake on AWS:**

  * If the organization uses Snowflake, replace Redshift with Snowflake.
  * Snowpipe consumes S3 event notifications natively, auto-ingests Parquet files with 1-2 min latency.
  * Snowflake External Tables can query S3 Iceberg tables directly via Glue Catalog integration.

### Orchestration: MWAA (Managed Airflow)

**Why MWAA?**

  * Managed Apache Airflow, same DAG authoring, no infrastructure management.
  * Native operators for Redshift (`RedshiftSQLOperator`), S3, Glue, and EMR.
  * Sensors for S3 key detection (`S3KeySensor`) to trigger micro-batch loads.
  * CloudWatch integration for DAG failure alerts.
  * Auto-scaling workers for parallel task execution.

### Monitoring: CloudWatch + Custom Dashboards

Component| Metric Source| Key Metrics  
---|---|---  
MSK| CloudWatch (built-in)| `MessagesInPerSec`, `UnderReplicatedPartitions`,
`ConsumerLag`  
Managed Flink| CloudWatch| `lastCheckpointDuration`, `numRecordsInPerSecond`,
`backPressured`  
S3| CloudWatch + S3 Inventory| `PutRequests`, `5xxErrors`, bucket size  
Redshift| CloudWatch + system tables| `QueryDuration`, `COPYDuration`,
`PercentageDiskSpaceUsed`  
MWAA| CloudWatch| DAG duration, task failures, scheduler heartbeat  
  
**Alerting:** CloudWatch Alarms -> SNS -> PagerDuty/Slack. Composite alarms
for multi-signal detection (e.g., high consumer lag AND high Flink
backpressure).

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
MSK| Tiered storage (offload to S3 after 24h)| 40-60% on broker EBS  
MSK| Serverless mode for dev/staging environments| Pay only for throughput  
Managed Flink| Auto-scaling (scale down during off-peak)| 30-50% vs fixed KPU  
S3| Intelligent-Tiering (auto hot/warm/cold)| 30-50% on staging data  
Redshift| Serverless (pay per RPU-hour, not per cluster)| 50-70% for bursty
COPY loads  
Glue ETL| Flex execution (preemptible workers)| 35% cheaper than standard  
MWAA| Right-size environment class (small vs large)| Up to 50%

