# Real-Time Fraud Detection Pipeline

Source: https://datapathsala.com/system-design/fraud-detection

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# Real-Time Fraud Detection Pipeline

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a real-time fraud detection pipeline for a payment processing platform
operating at Stripe/PayPal scale. The system must score every transaction in
under 100ms using a two-layer approach: a fast rule engine for velocity checks
and blocklists, plus an ML model (gradient-boosted trees) for behavioral
analysis. The pipeline processes 10,000 transactions per second, computes
real-time features (transaction velocity, geo-distance) and historical
features (spending patterns, device fingerprints), and produces a three-way
decision: approve, decline, or send to manual review. Fraud investigators
label flagged cases, and their feedback feeds back into model retraining. How
would you design this end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Fraud detection interviews test something different from generic system
design. The interviewer is not just checking whether you know Kafka and Redis.
They want to see whether you understand the three hard problems that make
fraud detection architecturally distinct from other real-time pipelines, and
whether your design decisions are grounded in those constraints.

### The Three Hard Problems Unique to Fraud Detection

**1\. Sub-100ms scoring with velocity features requires a pre-computed feature
store, not on-demand computation.**

Fraud detection fires on every transaction. The model needs velocity features:
transactions in the last 1 minute, 10 minutes, 1 hour, and 24 hours per card,
per merchant, and per device. Computing these from scratch on each transaction
means 4 or more database queries at peak transaction throughput. At 10,000
transactions per second, that is 40,000 or more database round-trips per
second on the scoring path alone, before you have even touched the ML model.
No disk-based database survives that load within a 100ms budget.

Strong answers pre-compute velocity counts in Redis sorted sets with TTL-based
sliding windows, updated in real-time from the transaction stream, so feature
lookup is a single O(1) Redis call per dimension. Flink (or Dataflow, or Kafka
Streams) consumes the transaction stream and continuously updates velocity
counters in Redis. At scoring time, the feature vector assembly is a single
HGETALL call that returns all 200 pre-computed features in 5-10ms. The model
never waits for a database scan.

**2\. Concept drift: fraud patterns change as fraudsters adapt.**

A model trained on last year's fraud patterns misses new attack vectors. New
card-testing patterns emerge as attackers learn to stay below velocity
thresholds. New merchant categories become targeted. Device fingerprinting
bypass techniques evolve. A static model that was 95% accurate at launch will
degrade to 80% or lower within months as fraudsters adapt, and the degradation
is silent because labeled data (chargebacks) arrives 30-60 days late.

Strong answers implement automated drift detection by monitoring the fraud
score distribution daily against a rolling 30-day baseline using KL-divergence
or Population Stability Index. When statistical drift exceeds a threshold (KL
> 0.1 or PSI > 0.2), an alert fires and retraining is triggered. The feedback
loop from fraud analyst labels back to the training dataset must be explicit
in the architecture: analyst labels arrive in real-time, customer reports
arrive within 24 hours, and card network alerts (TC40/SAFE) arrive within 3
days, all feeding a labeled dataset that keeps the model current well ahead of
the 30-day chargeback lag.

**3\. Exactly-once semantics at the fraud decision boundary is non-
negotiable.**

A retry that processes a transaction twice could charge a customer twice or
double-block a legitimate card. Unlike a recommendation system where a
duplicate event just means a slightly skewed model update, a duplicate fraud
decision event can cause a real financial transaction to execute twice.

Strong answers design idempotent consumers using transaction_id as a
deduplication key in Redis with an appropriate TTL (at minimum 24 hours,
ideally 7 days to cover delayed retries). They use Kafka transactional produce
for the fraud decision event sink so that the decision is written atomically,
and they ensure the downstream payment authorization service handles duplicate
decision events gracefully by checking whether the transaction has already
been finalized before acting on an incoming decision.

### What the Interviewer Is Testing

Dimension| What a Strong Answer Shows  
---|---  
Latency reasoning| Allocation of the 100ms budget across each hop, with
explicit justification for every design choice that touches the critical path  
Data architecture| Understanding of the difference between pre-computed
features (batch + streaming) versus on-demand computation, and why on-demand
fails at this scale  
ML ops| Awareness of concept drift, retraining triggers, champion/challenger
deployment, and the label delay problem specific to fraud  
Reliability| Idempotency at the decision boundary, fallback modes when the ML
scorer is down, and exactly-once semantics for financial events  
Adversarial thinking| Recognition that fraudsters adapt and that the system
must adapt faster, through ensemble diversity, unsupervised anomaly detection,
and rapid rule deployment  
  
### Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| **Clarify requirements** \- throughput (10K TPS?), latency SLA (p99 <
100ms?), decision output (three-way?), fraud types, feedback loop cadence| 2-3
min  
2| **High-level architecture** \- the two-layer scoring path (rule engine + ML
scorer in parallel), Kafka as the event bus, Redis as the feature store, Flink
for real-time features| 4-5 min  
3| **Feature store deep dive** \- why pre-computed, how Flink writes velocity
counters, how the scoring service reads them in a single Redis call, TTL
strategy for sliding windows| 4-5 min  
4| **ML model and drift** \- champion/challenger deployment, retraining
triggers, concept drift detection, the label delay problem and proxy signals|
4-5 min  
5| **Reliability and exactly-once** \- idempotency via transaction_id in
Redis, Kafka transactional produce, fallback to rule-engine-only, the three-
tier feature cache| 3-4 min  
  
### Your Opening Move

> "Before I design anything, I want to call out the three constraints that
> make fraud detection architecturally unique. First, the 100ms latency budget
> means I cannot query a database on the scoring path: all features must be
> pre-computed and sitting in Redis. Second, fraud patterns drift as attackers
> adapt, so the system needs automated drift detection and a feedback loop
> that is faster than the 30-day chargeback lag. Third, exactly-once semantics
> at the decision boundary is non-negotiable: a retry that processes a
> transaction twice can cause a real double charge. Let me design around those
> three constraints."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

10K txn/secpublish transactionsync scoring pathpass-through if not blockedrisk
scorevelocity + blocklistsfeature vectorreview queuestreaming featuresupdate
velocity + geoarchive raw transactionsbatch feature engineeringhistorical
featuresfraud analyticsinvestigator labelsfailed eventsreprocess after fix

Payment Service

API Gateway

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Rule Engine

ML Scorer

Feature Store (Redis)

Decision Service

Flink (Real-Time Features)

Case Management

![Spark \(Batch Features + Training\)](/icons/tools/spark.svg)Spark (Batch
Features + Training)

Data Lake (S3/GCS)

Data Warehouse

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

Real-Time Scoring Pipeline

Scalability & Fault Tolerance

Monitoring & Observability

Adversarial Attack & Defense

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

10K txn/secpublishrule scoringML scoringrisk scorefeaturesstreaming
featuresupdate featuresarchiveanalyticsfailed eventsreprocess

Payment Service

API Gateway

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Amazon Fraud Detector

SageMaker Endpoint

![DynamoDB \(Features\)](/icons/aws/dynamodb.svg)DynamoDB (Features)

Managed Flink

Decision Lambda

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around Kinesis for payment ingestion, Amazon Fraud
> Detector for managed rule/ML scoring, SageMaker for custom models, DynamoDB
> for the feature store, Managed Flink for real-time features, and S3 +
> Iceberg for the data lake."

### End-to-End Data Flow

    
    
    1. Payment Service sends transaction -> API Gateway authenticates + rate-limits
    2. API Gateway publishes to Kinesis Data Streams (partitioned by user_id for ordering)
    3. Kinesis -> Managed Flink (real-time feature computation: velocity, geo-velocity)
    4. Flink writes updated features to DynamoDB (feature store)
    5. Kinesis -> Amazon Fraud Detector (managed rule evaluation + built-in ML models)
    6. Fraud Detector checks DynamoDB for user features + velocity counters
    7. For custom scoring: Fraud Detector -> SageMaker Endpoint (XGBoost ensemble)
    8. SageMaker returns risk score -> Decision Lambda combines rule + ML signals
    9. Decision Lambda publishes verdict to Kinesis (decision topic) -> Payment Service
    10. Kinesis -> S3 + Iceberg (archive all transactions, decisions, features for compliance)
    11. S3 -> Redshift Serverless (fraud analytics, model performance dashboards)
    12. Failed events -> SQS DLQ -> inspect, fix, reprocess to Kinesis
    

### Why Each Component

### Event Streaming: Kinesis Data Streams

**Why Kinesis over self-managed Kafka on AWS?**

  * Fully managed , no broker patching, ZooKeeper, or rebalancing headaches
  * On-demand mode eliminates shard capacity planning for variable transaction volumes
  * Enhanced fan-out provides dedicated 2 MB/sec read throughput per consumer (critical when Flink and Fraud Detector both read the same stream)
  * Native integration with Managed Flink, Lambda, and CloudWatch
  * 7-day retention for replay during incident investigation

**Config:** On-demand mode, enhanced fan-out for Flink and Fraud Detector
consumers, 7-day retention.

**Trade-off:** Less flexible than Kafka (no compacted topics, 365-day max
retention). If you need topic compaction for changelog streams or >365-day
retention, use MSK (managed Kafka) instead. At 10K TPS with 2 KB payloads (~20
MB/sec), Kinesis on-demand is cost-effective.

### Managed Rule + ML Scoring: Amazon Fraud Detector

**Why Amazon Fraud Detector?**

  * Purpose-built for fraud detection , comes with pre-trained models for online fraud, account takeover, and transaction fraud
  * Built-in rule engine with a visual rule editor (no custom DSL needed)
  * Automatic model training on your labeled data with no ML expertise required
  * Real-time API: send a transaction, get a risk score + rule outcomes in ~50 ms
  * Supports "event variables" (your features) and "outcomes" (approve/decline/review)

**When to add SageMaker:**

  * Fraud Detector's built-in models are good for 80% of use cases, but for custom ensemble models (XGBoost + LSTM with 200+ features), deploy on a SageMaker real-time endpoint
  * SageMaker supports ONNX Runtime, model A/B testing (production variants), and auto-scaling
  * Use SageMaker Pipelines for the weekly retraining workflow: data extraction from S3, feature engineering, training, evaluation, model registry, deployment

**SageMaker Endpoint config:** ml.c5.2xlarge (CPU) for XGBoost, ml.g4dn.xlarge
(GPU) for LSTM. Auto-scaling: min 2, max 20 instances, target invocations per
instance < 500/sec.

### Feature Store: DynamoDB + DAX

**Why DynamoDB for the feature store?**

  * Single-digit millisecond reads at any scale (200M+ items)
  * On-demand capacity mode , auto-scales to 10K+ reads/sec without provisioning
  * DAX (DynamoDB Accelerator) cache provides sub-millisecond reads for hot users
  * Global Tables for multi-region feature replication (supports multi-region scoring)
  * DynamoDB Streams for change data capture , trigger Lambda on feature updates for audit logging

**Table design:**

    
    
    PK: USER#{user_id}
    SK: FEATURES
    Attributes: txn_count_1h, txn_count_24h, geo_velocity_kmh, avg_amount_7d, ...
    TTL: None (continuously updated by Flink)
    
    PK: DEVICE#{device_hash}
    SK: PROFILE
    Attributes: first_seen, trust_score, associated_users_count, ...
    
    PK: BLOCKLIST#CARD_BIN
    SK: {card_bin}
    Attributes: reason, added_at, source
    TTL: 30 days
    

**Cost:** On-demand reads at ~$1.25/million. At 10K TPS x 2 reads (user
features + device profile) = 20K reads/sec = ~$2,160/day. DAX reduces this by
60-80% for hot users.

### Real-Time Features: Managed Flink

**Why Managed Flink on AWS?**

  * Same Flink engine as open-source , keyed state per user_id works identically
  * Auto-scaling based on Kinesis consumer lag (backpressure-aware)
  * Managed checkpointing to S3 , no RocksDB tuning needed
  * VPC integration for secure writes to DynamoDB

**Flink computes:**

  * Transaction velocity (1h, 24h, 7d tumbling windows)
  * Geo-velocity (event-driven, haversine distance / time delta)
  * Distinct merchants per user (24h sliding window)
  * Cumulative amount per card (1h tumbling window)

**Config:** 200+ KPUs (Kinesis Processing Units) for 10K TPS, checkpointing
every 10 seconds to S3.

### Data Lake + Analytics: S3 + Iceberg + Redshift Serverless

**S3 + Apache Iceberg** for the compliance data lake:

  * All transactions, decisions, and feature snapshots archived in Iceberg format
  * ACID transactions, time travel (query data as of any point in time , critical for audits)
  * 7-year retention for PCI-DSS and SOX compliance
  * Lifecycle: S3 Standard (90 days) -> S3 IA (1 year) -> Glacier Deep Archive (7 years)

**Redshift Serverless** for fraud analytics:

  * Pay per query , no cluster management
  * Connects to S3 Iceberg tables via Redshift Spectrum (query without loading data)
  * Dashboards in QuickSight: fraud rate trends, model performance, rule hit rates, analyst productivity

### Graph Fraud Detection: Amazon Neptune

**Why Neptune?**

  * Managed graph database supporting Gremlin and openCypher
  * Use for fraud ring detection: shared device fingerprints, shared IPs, shared shipping addresses across accounts
  * Batch-updated from S3 (daily Spark job exports graph edges)
  * Query: "Find all accounts within 3 hops of a confirmed fraudulent account that share a device or IP"

**Integration:** Neptune results feed back as features into DynamoDB (e.g.,
`fraud_ring_proximity_score` per user).

### ML Pipeline Orchestration: Step Functions + SageMaker Pipelines

**Weekly retraining pipeline:**

    
    
    Step Functions workflow:
    1. Glue Job: Extract 90-day labeled data from S3 Iceberg -> training dataset
    2. SageMaker Processing: Feature engineering + train/test split
    3. SageMaker Training: Train XGBoost + LSTM on ml.p3.2xlarge
    4. SageMaker Processing: Evaluate on holdout set (precision > 92%, recall > 85%)
    5. Conditional: If validation passes -> register model in SageMaker Model Registry
    6. SageMaker Endpoint: Deploy as challenger variant (5% traffic)
    7. CloudWatch: Monitor challenger performance for 48 hours
    8. Lambda: Promote challenger to champion if metrics are met
    

### Security + Monitoring: CloudWatch + GuardDuty

Concern| AWS Service| Implementation  
---|---|---  
Scoring latency SLA| CloudWatch Metrics + Alarms| Custom metric:
`decision_latency_p99`. Alarm if > 100 ms for 2 min.  
Fraud rate monitoring| CloudWatch custom dashboard| Real-time fraud rate,
false positive rate, approval rate  
Infrastructure security| GuardDuty| Detects anomalous API calls, credential
exfiltration, suspicious network activity  
Data encryption (PCI-DSS)| KMS| All data encrypted at rest (S3, DynamoDB,
Redshift) and in transit (TLS 1.2+)  
Access control| IAM + VPC| Least-privilege IAM roles per service; scoring
pipeline in private VPC  
Audit trail| CloudTrail| All API calls logged; immutable trail for SOX
compliance  
  
### Cost Estimate (AWS)

Service| Monthly Cost  
---|---  
Kinesis (on-demand, 10K TPS)| $8,000-12,000  
DynamoDB + DAX (on-demand)| $10,000-18,000  
Managed Flink (200 KPUs)| $12,000-16,000  
SageMaker Endpoints (auto-scaling)| $8,000-15,000  
Amazon Fraud Detector| $5,000-10,000  
S3 + Iceberg (50 TB/month)| $1,500-3,000  
Redshift Serverless| $3,000-8,000  
Neptune| $2,000-5,000  
**Total**| **$50,000-87,000/month**

