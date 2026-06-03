# Fitness Tracker Data Platform

Source: https://datapathsala.com/system-design/fitness-tracker

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# Fitness Tracker Data Platform

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a data platform for a fitness wearable company (like Fitbit or Garmin)
that ingests real-time sensor data from 10 million active devices streaming
heart rate, steps, sleep stages, GPS coordinates, and SpO2 readings every 5
seconds. The platform must power real-time health alerts (abnormal heart rate,
fall detection, dangerous SpO2 drops), generate daily/weekly health reports
for users, feed ML models for activity classification, and support
longitudinal health studies. The system must handle 2 million events per
second at peak, store years of time-series data efficiently, comply with HIPAA
regulations, and gracefully handle devices that go offline and sync large
backlogs when reconnected. How would you design this end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Three hard problems make this question unique. Most candidates sketch a Kafka
pipeline and call it done. What separates a strong answer is showing you've
thought through what actually breaks at scale.

**1\. Offline sync micro-bursts can starve real-time health alerts.** A
wearable offline for 14 days buffers 241,920 readings (~9.7 MB). When it
reconnects, it dumps everything in ~24 seconds. If that burst lands on the
same Kafka topic as live sensor data, one device's backlog can create consumer
lag that delays a cardiac alert for another user. Strong answers isolate
offline sync onto a separate topic from the start.

**2\. One-size-fits-all alert thresholds cause alert fatigue or missed
events.** A marathon runner's resting HR of 42 bpm is normal. A sedentary
60-year-old at 42 bpm may be bradycardic. Absolute thresholds either spam
athletes with false alarms (they disable alerts entirely) or miss real events
in low-fitness users. Strong answers introduce per-user baselines computed
from rolling 30-day history and z-score detection layered on top of absolute
bounds.

**3\. HIPAA audit logging at 2M events/sec is operationally underestimated.**
HIPAA requires logging every PHI access: who, what, when, from where. At 2M
events/sec, that's 172 billion audit events per day. Storing them in the same
database as sensor data creates write contention. Strong answers propose an
append-only audit store (separate from the TSDB), write-once S3 Object Lock
for immutability, and a 7-year retention policy separate from the sensor data
lifecycle.

### What the Interviewer Is Testing

Signal| What a Strong Answer Does  
---|---  
IoT fundamentals| Chooses MQTT over HTTP, explains QoS levels and persistent
sessions  
Throughput intuition| Sizes Kafka correctly: 400 MB/sec needs 30-50 brokers,
not 3  
Real-time vs batch separation| Explains why health alerts and batch reports
must have independent consumer paths  
Time-series expertise| Knows TimescaleDB hypertables, continuous aggregates,
and compression ratios  
Operational depth| Covers offline sync isolation, device firmware bugs,
January spike planning  
  
### Structured Walkthrough

Step| Focus| Time  
---|---|---  
1| Clarify: alert latency SLA, HIPAA scope, offline sync max duration,
retention policy| 2-3 min  
2| Architecture: IoT Gateway → Kafka (two topics) → Flink alerts + S3 archive|
5 min  
3| Deep dive: MQTT QoS, Kafka partition strategy, Flink keyed state for per-
device anomaly detection| 15 min  
4| Data modeling: TimescaleDB hypertables, cascading continuous aggregates,
Iceberg data lake| 5 min  
5| Hard problems: offline sync isolation, personalized thresholds, HIPAA audit
at scale| 5 min  
  
### Your Opening Move

> "Before designing, let me confirm scope: 10M devices streaming at 2M
> events/sec, sub-10-second latency for health safety alerts, HIPAA compliance
> throughout, and devices that go offline for up to 14 days. The three hardest
> parts are: keeping offline sync bursts from starving the real-time alert
> path, personalizing alert thresholds per user to avoid fatigue, and audit
> logging at this throughput. Does that framing match what you're looking
> for?"

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

2M events/sec (MQTT)BLE relay + offline syncvalidated sensor eventsreal-time
health streamabnormal HR / fall / SpO2hot time-series dataactivity
classificationenriched activity labelsraw sensor archivedaily/weekly
reportssleep analysis + aggregationscurated health datareal-time
metricshistorical reportsmalformed/failed eventsreprocess after fix

Wearable Devices

Mobile App (BLE Relay)

IoT Gateway / MQTT Broker

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Flink (Real-Time Alerts)

ML Model Service

Alert Service (Push/SMS)

Time-Series DB (TimescaleDB)

Data Lake (S3/GCS)

![Apache Airflow](/icons/tools/airflow.svg)Apache Airflow

![Spark \(Batch Analytics\)](/icons/tools/spark.svg)Spark (Batch Analytics)

Data Warehouse

Health Report API

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

IoT Protocol & Edge Computing

Scalability & Fault Tolerance

Monitoring & Observability

Health Alert System Design

Follow-Up Questions & Answers

Technology Comparison Table

Whiteboard Summary & Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

MQTT 10M devicesrules engine -> streamreal-time health alertshot time-
seriesabnormal HR/fall/SpO2activity classificationenriched activity dataraw
archive streamParquet micro-batchesdaily ETL + reportsaggregated health
datafailed eventsreprocess

Wearable Devices

AWS IoT Core

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Managed Flink (Alerts)

Amazon Timestream

SNS (Push/SMS Alerts)

SageMaker (ML)

![Kinesis Firehose](/icons/aws/kinesis.svg)Kinesis Firehose

![S3 Data Lake \(Iceberg\)](/icons/aws/s3.svg)S3 Data Lake (Iceberg)

![AWS Glue \(ETL\)](/icons/aws/glue.svg)AWS Glue (ETL)

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

![DynamoDB \(Profiles\)](/icons/aws/dynamodb.svg)DynamoDB (Profiles)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around IoT Core for MQTT device ingestion, Kinesis for
> streaming, Managed Flink for real-time health alerts, Timestream for hot
> time-series, and SageMaker for ML activity classification, all within a
> HIPAA-eligible service footprint."

### End-to-End Data Flow

    
    
    1. 10M wearables connect via MQTT -> AWS IoT Core (managed broker)
    2. IoT Core Rules Engine validates + routes to Kinesis Data Streams (partitioned by device_id)
    3. IoT Core also routes raw archive stream -> Kinesis Firehose -> S3 (Parquet micro-batches)
    4. Kinesis -> Managed Flink (real-time health alert detection with keyed state per device)
    5. Flink detects anomaly -> SNS (push notification + SMS to user and emergency contacts)
    6. Flink writes hot data -> Amazon Timestream (recent 30-day time-series for app queries)
    7. Kinesis -> SageMaker endpoint (real-time activity classification: running/sleeping/resting)
    8. SageMaker enriched labels -> DynamoDB (device state, current activity, user profiles)
    9. S3 data lake (Iceberg format) -> AWS Glue (daily ETL: sleep analysis, health summaries)
    10. Glue output -> Redshift Serverless (aggregated health reports, longitudinal studies)
    11. Failed events -> SQS DLQ -> inspect, fix, reprocess to Kinesis
    12. MWAA (Managed Airflow) orchestrates all batch jobs (Glue, report generation, ML retraining)
    

### Why Each Component

### Device Ingestion: AWS IoT Core

**Why IoT Core over self-managed EMQX on EC2?**

  * Fully managed MQTT broker supporting 10M+ simultaneous device connections
  * Built-in device registry and X.509 certificate-based authentication (no custom auth layer)
  * Device Shadow for tracking device state (online/offline, last sync time, firmware version), critical for managing offline sync
  * Rules Engine routes messages to Kinesis, S3, Lambda, or DynamoDB based on SQL-like filter expressions (e.g., route SpO2 < 90 directly to an alert Lambda)
  * Automatic device lifecycle events (connected, disconnected, subscribed) for monitoring fleet health
  * **HIPAA eligible** : IoT Core is on the AWS HIPAA eligible services list, meaning you can include it in your BAA
  * Cost: $0.08 per million messages (5KB each). At 2M events/sec = 172.8B/day = ~$13,800/day for messaging. Significant, but eliminates all broker management overhead.
  * Trade-off: Less flexible than EMQX for custom MQTT extensions. No shared subscriptions (must fan out via Rules Engine). At extreme scale, consider MSK (managed Kafka) as the primary bus with IoT Core only for MQTT termination.

**Offline sync handling:** IoT Core's persistent sessions retain messages for
offline devices (up to 1 hour on Standard tier, 7 days on Premium). For longer
offline periods, devices buffer locally and use the `retained message` feature
plus bulk MQTT publish on reconnect. The Rules Engine's Kinesis action handles
burst ingestion gracefully.

### Streaming: Kinesis Data Streams

**Why Kinesis?**

  * Native integration with IoT Core (single-click Rules Engine action)
  * On-demand capacity mode eliminates shard management, auto-scales to handle 2M events/sec peaks
  * Enhanced fan-out provides dedicated 2 MB/sec throughput per consumer (Flink, SageMaker, Firehose each get isolated throughput)
  * 7-day retention for replay, essential for reprocessing after a firmware bug discovery
  * Kinesis Data Firehose provides zero-code delivery to S3 in Parquet format (bronze layer of the data lake)
  * Cost: On-demand at $0.08/GB ingested + $0.04/GB retrieved. At 400 MB/sec sustained = ~$2,700/day for ingestion + retrieval per consumer.

### Real-Time Alerts: Amazon Managed Flink

**Why Managed Flink?**

  * Same Flink engine as open-source, keyed state per device_id for baseline tracking works identically
  * Auto-scaling based on Kinesis consumer lag (backpressure-aware scaling)
  * Managed checkpointing to S3, no RocksDB tuning or checkpoint storage management
  * VPC integration for HIPAA compliance, Flink workers run inside your VPC with no public internet access
  * Cost: ~$0.11/KPU-hour. For sustained 2M events/sec processing, estimate 50-80 KPUs = ~$130-210/day.
  * Trade-off: Slightly higher latency (~1-3 sec) vs self-hosted Flink (~100ms). Acceptable since our health alert SLA is sub-10 seconds.

### Time-Series Storage: Amazon Timestream

**Why Timestream over self-managed TimescaleDB on RDS?**

  * Serverless, no instances to manage, automatic scaling for 2M writes/sec
  * Built-in tiered storage: memory store (recent data, sub-ms queries) + magnetic store (historical, cost-optimized)
  * Automatic data lifecycle: data moves from memory to magnetic store based on retention policy
  * Native integration with Grafana for real-time dashboards
  * Cost: $0.50/GB for memory store writes, $0.01/GB for magnetic store. At 34.5 TB/day raw ingestion, use aggressive downsampling (5-sec -> 1-min aggregates for magnetic store) to control costs.
  * Trade-off: Timestream has a proprietary query language (SQL-like but different). No JOINs with external tables, need to denormalize user context into each reading. For complex analytical queries, prefer Redshift or Athena querying the Iceberg data lake.

### ML Serving: SageMaker Real-Time Endpoints

**Why SageMaker?**

  * Real-time inference endpoints with auto-scaling, handles 2M classification requests/sec with multi-model endpoints
  * Model registry + ML pipeline for automated retraining (weekly activity classifier updates)
  * A/B testing: deploy new model versions to 5% of traffic, compare accuracy metrics before full rollout
  * SageMaker Model Monitor: automatic data drift detection, alerts if incoming sensor data distribution shifts (e.g., new device model with different sensor characteristics)
  * HIPAA eligible with VPC endpoints, model inference never leaves your network
  * Cost: ml.c5.4xlarge instances ($0.68/hr) with auto-scaling. For sustained throughput, estimate 10-20 instances = ~$160-325/day.

### Data Lake: S3 + Iceberg + Glue

**S3** as the foundation:

  * Petabyte-scale storage at $0.023/GB/month (Standard)
  * Lifecycle policies: Standard (90 days) -> Intelligent Tiering -> Glacier Instant (1 year) -> Glacier Deep Archive (2+ years). Reduces long-term storage cost by 80%.
  * S3 Object Lock for HIPAA audit log immutability
  * S3 Access Points for fine-grained access control per team (data science, analytics, compliance)

**Apache Iceberg** for table format:

  * ACID transactions on S3, concurrent writes from Firehose, Glue, and Flink without corruption
  * Partition evolution: start with `device_id, day`, evolve to `region, age_cohort` for research queries without rewriting data
  * Time travel: query data as of any point in time, essential for auditing and debugging data quality issues
  * Row-level deletes for GDPR Right to Erasure compliance

**AWS Glue** for ETL:

  * Serverless Spark for daily health report generation (sleep analysis, weekly summaries, trend detection)
  * Glue Data Catalog as the centralized metastore for Iceberg tables
  * Glue Crawlers for automatic schema discovery on new data landing in S3
  * Cost: $0.44/DPU-hour. Daily batch jobs: ~20-30 DPU-hours = ~$9-13/day.

### Warehouse & Analytics: Redshift Serverless

**Why Redshift Serverless?**

  * Pay-per-query pricing, no cluster management for analytics workloads
  * Direct query federation to S3 Iceberg tables (Redshift Spectrum), no data copying needed
  * dbt models for health report materialization, run on schedule via MWAA
  * QuickSight integration for health analytics dashboards (medical research, population health)
  * RA3 instances with managed storage if workload grows to justify dedicated compute

### Notifications: SNS

  * SNS for multi-channel fan-out: push (APNS/FCM), SMS, email (SES)
  * SNS message filtering: route by alert severity (emergency -> SMS + push, informational -> push only)
  * SES for email health reports ($0.10/1K emails)
  * SMS reserved for emergency alerts only ($0.00645/msg US), at scale, SMS is the largest notification cost

### Device State: DynamoDB

  * On-demand mode for unpredictable access patterns (device reconnections are bursty)
  * Global tables for multi-region deployment (EU data sovereignty)
  * DynamoDB Streams for CDC, trigger Lambda on device status changes (e.g., device goes offline -> update monitoring dashboard)
  * DAX (DynamoDB Accelerator) for sub-ms reads on hot device profiles during Flink alert enrichment

### Orchestration: MWAA (Managed Airflow)

  * Managed Apache Airflow for scheduling batch pipelines (Glue ETL, ML retraining, health report generation)
  * DAGs for: daily_health_summary, weekly_trend_report, monthly_ml_retrain, gdpr_data_export, data_quality_checks
  * HIPAA eligible, runs within your VPC

### Cost Optimization Summary

Service| Optimization| Monthly Savings  
---|---|---  
IoT Core| Basic Ingest (reduced feature set, 50% cheaper)| 40-50% on messaging  
Kinesis| On-demand mode (auto-scales, no over-provisioning)| 30-50% vs
provisioned  
Timestream| Aggressive downsampling (5s -> 1min for magnetic store)| 12x
storage reduction  
SageMaker| Spot instances for training, auto-scaling for inference| 60-70% on
training, 30% on inference  
S3| Lifecycle policies: Standard -> Glacier Deep Archive| 80% on archived data  
Glue| Auto-scaling DPUs + job bookmarks (process only new data)| 50% on daily
ETL  
Redshift| Serverless (pay per query) vs provisioned cluster| 50-70% for bursty
analytics  
DynamoDB| On-demand + DAX cache for hot device lookups| 40-60% vs provisioned  
  
**Estimated total monthly cost (AWS): $120,000-200,000** depending on
optimization aggressiveness and traffic patterns. The largest cost drivers are
IoT Core messaging, Kinesis throughput, and S3 storage at petabyte scale.

