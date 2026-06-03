# CDC Pipeline for Data Lake

Source: https://datapathsala.com/system-design/cdc-pipeline

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# CDC Pipeline for Data Lake

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a Change Data Capture (CDC) pipeline that replicates changes from 200+
source databases (PostgreSQL, MySQL, Oracle, SQL Server) into a centralized
data lake in near-real-time. The system must handle initial full-load
snapshots, incremental change streaming, schema evolution without breaking
downstream consumers, and fan-out to multiple targets including a lakehouse,
data warehouse, search index, and cache layer. Expect around 50,000 change
events per second aggregate across all sources, with individual tables ranging
from gigabytes to multi-terabyte initial snapshots. How would you design this
end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

> "Start by naming the three hardest problems specific to CDC, not generic
> distributed systems problems. Interviewers at data-engineering-focused
> companies have heard the generic answers. Naming schema evolution, snapshot-
> stream ordering, and multi-table consistency immediately signals that you
> have built this in production."

## The Three Hard Problems Unique to CDC Pipelines

### 1\. Schema changes in the source database are the most common production
incident

A developer adds a NOT NULL column or renames a column. Debezium captures the
DDL change. Downstream consumers that expect the old schema crash or silently
produce wrong data. This is not a theoretical problem, it happens every time a
source team runs a migration without coordinating with the CDC team.

Strong answers implement schema evolution via Confluent Schema Registry with
compatibility modes. BACKWARD compatibility means a new schema can always read
data written by the old schema, so adding a nullable column with a default is
safe and automatic. FORWARD compatibility means an old schema can read data
written by the new schema, protecting consumers that have not yet been
updated. Strong answers also enforce that DDL changes go through a review
process (a CDC schema change request filed 48 hours before the migration), and
deploy consumer schema updates before the source DDL change lands in
production. A breaking change like a column rename is treated as a multi-phase
migration: add the new column and dual-write to both, migrate all consumers to
the new column name, then drop the old column only after verifying no consumer
still references it.

### 2\. The initial snapshot while live changes arrive creates an ordering and
consistency problem

When first setting up CDC, you take a full table snapshot that may cover
millions or billions of rows. While the snapshot runs, live writes keep
arriving in the binlog. If you apply CDC events before the snapshot is
complete, you apply changes to rows that have not been loaded yet, producing
phantom updates or orphaned deletes.

Strong answers use a consistent snapshot with an LSN or SCN watermark: capture
all rows as of LSN X from a read replica, then apply only CDC events with LSN
greater than X, never mixing snapshot and stream data for the same row.
Debezium's incremental snapshot feature (available from Debezium 2.x via the
signal table) handles this correctly by interleaving snapshot chunks with live
streaming events using watermarking, so there is no global lock and no gap in
change capture. A weak answer says "just take a snapshot and then start CDC",
without acknowledging the watermark problem.

### 3\. Multi-table consistency for foreign key relationships

An order CDC event arrives before its order_items events (or vice versa). A
downstream consumer materializing a denormalized view sees an order with no
items, or orphaned items with no parent order. This happens because Kafka
assigns each table its own topic and partitions, so events from different
tables arrive at different consumer threads with no synchronization.

Strong answers use one of three patterns depending on the latency requirement.
For strict atomicity, use a Flink temporal join or a staging buffer that waits
for related events to arrive within a consistency window (for example, 30 to
60 seconds) before materializing the denormalized output. For looser
requirements, use a read-time reconciliation query that only joins rows where
both sides have been committed past the same watermark. For financial tables
where exact transactional atomicity is required, buffer all events between the
Debezium BEGIN and END transaction markers and flush atomically only after the
END marker arrives.

## What the Interviewer Is Testing

Dimension| What a Strong Answer Looks Like  
---|---  
Production awareness| Names schema evolution, snapshot ordering, and multi-
table consistency as the hard problems, not just "use Kafka"  
Schema evolution depth| Explains BACKWARD vs FORWARD compatibility modes,
dual-write migration for breaking changes, Schema Registry rejection behavior  
Operational maturity| Mentions replication slot WAL retention risk, GitOps
connector management, DLQ monitoring, daily reconciliation jobs  
Scalability reasoning| Derives broker count from event rate and event size,
explains partition count tradeoffs, sizes Flink TaskManagers from state size  
Trade-off thinking| Compares incremental vs full snapshot, exactly-once vs at-
least-once, compacted topics vs time-based retention  
  
## Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| Clarify requirements: event rate, lag SLA, number of sources, downstream
targets, schema evolution expectations| 2-3 min  
2| Draw the high-level architecture: sources, Debezium, Kafka with Schema
Registry, Flink, bronze/silver/gold, fan-out targets| 4-5 min  
3| Deep dive on the three hard problems: schema evolution strategy, snapshot
watermark approach, multi-table consistency pattern| 10-12 min  
4| Data modeling: CDC event schema in bronze (Iceberg), silver MERGE pattern,
Schema Registry schema design| 4-5 min  
5| Operational concerns: WAL retention management, connector GitOps, DLQ
handling, reconciliation, lag monitoring| 4-5 min  
  
## Your Opening Move

> "Before I start drawing, I want to name the three hardest problems in CDC
> that I've seen break pipelines in production. First, schema evolution: a
> source developer adds a NOT NULL column and every downstream consumer
> crashes. Second, snapshot ordering: you start a full-table snapshot and live
> changes arrive concurrently, and if you apply them naively you corrupt the
> state. Third, multi-table consistency: an order arrives before its line
> items and a consumer materializing a denormalized view sees incomplete data.
> Everything I design will be specifically to solve those three problems."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

WAL / binlog / redo loginitial full load50K events/sec aggregatesnapshot
chunksenforce compatibilitystream consumeappend raw CDC eventsMERGE
upsert/deletegold aggregatesindex updatesorchestrates batch + backfillfailed /
poison eventsreprocess after fixlag + health checksconsumer lag

Source Databases (200+)

Debezium Connectors

Snapshot Service

![Apache Kafka \(CDC Events\)](/icons/tools/kafka.svg)Apache Kafka (CDC
Events)

Schema Registry

![Flink / Spark \(Transform + Merge\)](/icons/tools/spark.svg)Flink / Spark
(Transform + Merge)

![Airflow \(Orchestration\)](/icons/tools/airflow.svg)Airflow (Orchestration)

Bronze Lake (Raw CDC)

Silver Lake (Merged / Current)

Data Warehouse

Search Index (Elasticsearch)

Dead Letter Queue

Monitoring & Alerting

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation & Capacity Planning

Architecture Walkthrough

Component Deep Dive

Data Modeling & Schema Design

Debezium Operations & Schema Evolution

Scalability & Fault Tolerance

Monitoring & Observability

Data Consistency & Exactly-Once Guarantees

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

full-load + CDCchange eventsschema enforcementconsume CDC streambronze +
silver (Iceberg MERGE)gold tablesorchestratefailed eventsreprocess

Source Databases (RDS/On-Prem)

AWS DMS

![Amazon MSK](/icons/tools/kafka.svg)Amazon MSK

![Glue Schema Registry](/icons/aws/glue.svg)Glue Schema Registry

![AWS Glue ETL](/icons/aws/glue.svg)AWS Glue ETL

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

MWAA (Airflow)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around AWS DMS for CDC capture, Amazon MSK for the event
> bus, Glue Schema Registry for schema evolution, Glue ETL or Managed Flink
> for stream processing, S3 + Iceberg for the lakehouse, and Redshift
> Serverless for the data warehouse."

### End-to-End Data Flow

    
    
    1. Source databases (RDS, Aurora, on-prem via DMS) -> AWS DMS replication instances
    2. DMS captures full-load snapshots + ongoing CDC changes
    3. DMS writes change events to Amazon MSK (Kafka-compatible)
    4. Glue Schema Registry enforces Avro schema compatibility per topic
    5. MSK -> AWS Glue ETL (Spark Streaming) or Managed Flink for processing
    6. Bronze layer: Append raw CDC events to S3 + Iceberg (partitioned by date + table)
    7. Silver layer: MERGE INTO Iceberg tables for current-state view
    8. Redshift Serverless: Gold aggregations for BI dashboards
    9. Athena: Ad-hoc queries directly on S3 Iceberg tables (pay-per-query)
    10. MWAA (Managed Airflow): Orchestrates compaction, reconciliation, backfill
    11. Failed events -> SQS DLQ -> inspect, fix, reprocess to MSK
    

### AWS DMS vs Self-Managed Debezium

Dimension| AWS DMS| Debezium on MSK Connect  
---|---|---  
**Setup**|  Console/CloudFormation, minutes to configure| Connector JSON
configs, more knobs to tune  
**Source DB Support**|  RDS, Aurora, on-prem (via DMS agent)| Any DB with JDBC
+ WAL access  
**CDC Method**|  Log-based for most engines, query-based fallback| Strictly
log-based (WAL, binlog, redo log)  
**Schema Evolution**|  Basic (column add/drop auto-handled)| Full Avro schema
evolution with Schema Registry  
**Snapshot**|  Full-load task + ongoing CDC task| Incremental snapshot via
signal table (no global lock)  
**Target Flexibility**|  S3, Kinesis, Kafka, Redshift, DynamoDB| Kafka only
(fan-out from Kafka to other targets)  
**Monitoring**|  CloudWatch metrics, DMS task logs| JMX metrics, Kafka Connect
REST API  
**Cost**|  $0.018/hr per replication instance + storage| MSK Connect per-MCU
pricing + MSK cluster  
**Recommendation**|  Use for quick onboarding, AWS-native sources, <50 tables|
Use for full control, 200+ connectors, complex schema evolution  
  
**Hybrid approach:** Use DMS for simple sources (RDS PostgreSQL, Aurora MySQL)
where schema rarely changes. Use Debezium on MSK Connect for sources with
complex schema evolution, Oracle databases (DMS Oracle CDC has known
limitations), or when you need Debezium-specific features like incremental
snapshots and transaction metadata.

### Amazon MSK (Managed Kafka)

**Why MSK over self-managed Kafka?**

  * Fully managed brokers, no ZooKeeper (MSK uses KRaft mode), automatic patching
  * MSK Serverless for variable workloads (auto-scales partitions and throughput)
  * MSK Connect for running Debezium connectors as managed Kafka Connect workers
  * Native integration with Glue Schema Registry, Lambda, Firehose
  * Tiered storage: automatically offloads old segments to S3 (infinite retention at low cost)

**Config for CDC:** MSK Provisioned with 15-25 brokers (kafka.m5.2xlarge),
`auto.create.topics.enable = true` for new source tables, default replication
factor 3, 7-day retention + log compaction on CDC topics.

### Glue Schema Registry

  * Drop-in replacement for Confluent Schema Registry (Avro, JSON Schema, Protobuf)
  * Integrated with MSK, producers and consumers use the Glue SerDe libraries
  * BACKWARD, FORWARD, FULL, and NONE compatibility modes per schema
  * Free (no additional cost beyond AWS API calls)
  * Trade-off: Fewer features than Confluent Schema Registry (no schema contexts, no schema linking). Sufficient for CDC schema evolution.

### AWS Glue ETL for Transforms

**Why Glue ETL?**

  * Serverless Spark, no cluster management, auto-scales workers
  * Native Iceberg support (Glue Data Catalog is the Iceberg catalog)
  * Glue Streaming ETL reads from MSK with micro-batch processing
  * Supports MERGE INTO Iceberg tables for silver layer upserts
  * Glue Crawlers auto-detect schema changes in bronze layer

**Processing pipeline:**

    
    
    MSK -> Glue Streaming ETL Job (Spark)
      -> Bronze: glueContext.write_dynamic_frame(iceberg_table, mode="append")
      -> Silver: spark.sql("MERGE INTO silver.orders USING staged ON pk = pk ...")
      -> Gold:   spark.sql("INSERT OVERWRITE gold.daily_order_summary SELECT ...")
    

**Alternative: Managed Flink on AWS.** For sub-second latency requirements,
use Amazon Managed Service for Apache Flink instead of Glue Streaming ETL.
Flink provides true event-at-a-time processing vs Glue's micro-batch approach.

### S3 + Iceberg for Bronze/Silver Layers

**S3 as the storage layer:**

  * Virtually unlimited storage at $0.023/GB/month (Standard)
  * Lifecycle policies: Standard (90d) -> Infrequent Access (1y) -> Glacier (archive)
  * S3 Express One Zone for frequently accessed bronze partitions (single-digit ms latency)

**Iceberg via Glue Data Catalog:**

  * Glue Data Catalog serves as the Iceberg catalog (metastore)
  * Row-level deletes for GDPR compliance (position delete files)
  * Time travel for debugging and recovery
  * Partition evolution: change partitioning scheme without rewriting data

### Lake Formation for Governance

  * Column-level security: mask PII columns (SSN, email) for non-privileged roles
  * Row-level filtering: restrict access by business unit or region
  * Cross-account sharing: share Iceberg tables with analytics accounts via RAM
  * Audit: CloudTrail logs all data access across Athena, Redshift, Glue

### Redshift Serverless for Warehouse

  * Pay per RPU-hour (no cluster management)
  * Direct query on S3 Iceberg tables via Redshift Spectrum (no data movement)
  * Materialized views on Iceberg for frequently accessed gold aggregations
  * Auto-scales based on query complexity

### MWAA (Managed Airflow) for Orchestration

Orchestrates batch operations around the streaming pipeline:

  * Daily reconciliation: compare source DB row counts vs Iceberg silver layer
  * Iceberg compaction: rewrite small files from streaming writes into larger files
  * Partition management: expire old partitions per retention policy
  * Backfill coordinator: trigger DMS full-load tasks for tables needing re-snapshot
  * SLA monitoring: query CloudWatch metrics for per-connector lag, alert if > 5 min

### Athena for Ad-Hoc Queries

  * Serverless SQL directly on S3 Iceberg tables (pay per TB scanned)
  * Useful for investigation: "Show me all CDC events for order_id=42 in the last 24 hours"
  * Federated queries to source databases for live comparison during debugging
  * Cost: $5 per TB scanned. Use Iceberg's partition pruning and column projection to minimize cost.

### Cost Estimate (AWS)

Service| Monthly Cost  
---|---  
MSK (20 brokers, kafka.m5.2xlarge)| $18,000-22,000  
DMS replication instances (200 sources)| $8,000-12,000  
Glue Streaming ETL (40 DPUs continuous)| $10,000-15,000  
S3 storage (20 TB/month growing)| $500-1,000  
Redshift Serverless (on-demand)| $5,000-12,000  
MWAA (medium environment)| $1,000-2,000  
Athena queries| $500-1,500  
Lake Formation + Glue Crawlers| $500-1,000  
**Total**| **$43,500-66,500/month**

