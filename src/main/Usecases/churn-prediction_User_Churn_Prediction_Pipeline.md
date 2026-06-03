# User Churn Prediction Pipeline

Source: https://datapathsala.com/system-design/churn-prediction

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# User Churn Prediction Pipeline

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design an end-to-end churn prediction pipeline for a subscription SaaS
platform with 50 million users. The system must ingest user activity events,
billing events, support tickets, and feature usage logs, engineer behavioral
and engagement features, train and serve ML models (XGBoost/LightGBM), and
predict which users are likely to cancel their subscription within the next 30
days. The pipeline should support both daily batch scoring for the full user
base and real-time scoring for high-value accounts. How would you design this
end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Churn prediction looks straightforward on the surface, but it contains three
hard problems that most candidates miss entirely. A strong answer addresses
all three before touching infrastructure.

### Three Hard Problems Unique to Churn Prediction

**1\. Label definition shapes everything downstream and is rarely obvious.**

"Churned" sounds simple until you ask: 30 days inactive? Cancelled
subscription? Stopped opening the app? A user inactive for 45 days who returns
every weekend is not churned. Strong answers define the label precisely before
writing any code, for example, "no session event in the past 28 days AND no
scheduled future activity", and acknowledge that different label definitions
produce models with different business impacts. A 30-day inactivity label
optimizes for one intervention window; a cancellation-event label optimizes
for a completely different one. The choice is not technical, it is a business
decision that belongs in the requirements conversation.

**2\. Feature leakage across the training-prediction boundary invalidates
models silently.**

If features are computed at the prediction date but use data from after that
date (for example, a "last 7 days activity" feature computed during training
that inadvertently includes days in the label window), the model looks
accurate in training but fails in production. Strong answers enforce strict
temporal cuts: all features from strictly before the prediction date, all
labels from strictly after, with point-in-time correct feature computation.
This is not a nice-to-have; it is the most dangerous silent failure mode in ML
pipelines. A model with leakage can show AUC-ROC of 0.92 in training and 0.61
in production, and the only way to catch it is rigorous temporal bookkeeping.

**3\. As a data engineer, your job is to produce the feature data that enables
the model, not own the model itself.**

The ML scientist trains the churn classifier. The DE's job is: (1) building
the feature pipeline that computes churn signals at the correct temporal
boundaries, (2) maintaining a feature store so features are available at
scoring time with no leakage, and (3) ensuring training data distribution
matches production data distribution to prevent training-serving skew. Own the
data pipeline, not the model. In an interview, framing your answer around
these three DE responsibilities shows seniority. Candidates who spend 20
minutes on XGBoost hyperparameters and two minutes on the feature pipeline
have the ownership model backwards.

### What the Interviewer Is Testing

Dimension| What a Strong Answer Looks Like  
---|---  
Problem decomposition| Separates label definition, feature engineering, model
training, and serving as distinct concerns with distinct ownership  
DE vs ML boundary| Clearly articulates that DE owns the data pipeline and
feature store, not the model itself  
Temporal correctness| Proactively raises training-prediction leakage and
explains point-in-time correct joins  
Scale awareness| Ties architecture choices back to specific numbers (50M
users, 500M events/day, 10M paid users to score)  
Production thinking| Addresses model drift, feature freshness SLAs, feedback
loops, and the intervention bias problem  
  
### Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| Define the label precisely, state your prediction horizon, confirm with
interviewer| 2-3 min  
2| Clarify scale, data sources, latency SLAs, and action layer| 2-3 min  
3| Sketch the four-stage architecture: ingestion, feature engineering,
training, scoring| 5 min  
4| Deep dive the feature store and temporal correctness, this is your DE
showcase| 10 min  
5| Cover scoring paths (batch vs real-time), monitoring, feedback loop, and
failure modes| 5 min  
  
### Your Opening Move

> "Before I design anything, I want to nail down the label definition, because
> it shapes every downstream decision. I'll assume churn means a paid user
> cancels or does not renew within 30 days, and we want to predict this 30
> days in advance so the customer success team has time to intervene. That
> 30-day prediction horizon means I need features computed strictly before the
> prediction date and labels observed strictly after it, with a clean temporal
> cut. Let me walk through the four-stage pipeline with that constraint as the
> foundation."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

500M events/daysubscription changesticket eventsfeature usageraw events200+
featuresprocessed datatraining featuresversioned modelspromoted modelserving
modeloffline featuresonline featureschurn scoresreal-time scoresanalytics +
alertsorchestratestriggers retrainingchurn outcomes (feedback)failed
eventsreprocess after fix

User Activity Events

Billing Events

Support Tickets

Feature Usage Logs

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

![Spark \(Feature Eng.\)](/icons/tools/spark.svg)Spark (Feature Eng.)

Feature Store

ML Training Pipeline

Model Registry

Batch Scoring (Daily)

Real-Time Scoring

![Airflow](/icons/tools/airflow.svg)Airflow

Data Lake (S3/GCS)

Data Warehouse

Churn Dashboard

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

Feature Engineering & Feature Store

Scalability & Fault Tolerance

Monitoring & Observability

Model Lifecycle & A/B Testing

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

eventsraw eventscomputed featuresprocessed datatraining datatrained
modeldeploy modelchurn scoresorchestratestriggers retrainingfailed
eventsreprocess

Event Sources

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

![AWS Glue \(Feature Eng.\)](/icons/aws/glue.svg)AWS Glue (Feature Eng.)

SageMaker Feature Store

SageMaker Training

Model Registry

SageMaker Endpoint

![S3 \(Data Lake\)](/icons/aws/s3.svg)S3 (Data Lake)

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

MWAA (Airflow)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "Since we're on AWS, I'd build around Kinesis for event ingestion, Glue for
> feature engineering ETL, SageMaker Feature Store for online + offline
> features, SageMaker Training/Endpoints for the ML lifecycle, and Step
> Functions for ML pipeline orchestration."

### End-to-End Data Flow

    
    
    1. Event sources (activity, billing, support, usage) -> Kinesis Data Streams (partitioned by user_id)
    2. Kinesis -> AWS Glue Streaming ETL (micro-batch feature aggregation, 5-min windows)
    3. Glue writes computed features -> SageMaker Feature Store (online + offline groups)
    4. SageMaker Feature Store (offline) -> SageMaker Training Job (XGBoost/LightGBM built-in algorithms)
    5. Trained model -> SageMaker Model Registry (versioned, with approval workflow)
    6. Promoted model -> SageMaker Batch Transform (daily scoring, 10M users)
    7. Promoted model -> SageMaker Real-Time Endpoint (auto-scaling, < 50ms p99)
    8. Churn scores -> Redshift Serverless (analytics + dashboard)
    9. MWAA (Managed Airflow) orchestrates data pipelines (Glue jobs, feature freshness checks)
    10. Step Functions orchestrates ML pipeline (training -> eval -> registry -> deploy)
    11. EventBridge triggers retraining on schedule or when CloudWatch alarm fires (model drift)
    12. Failed events -> SQS DLQ -> inspect, fix, reprocess to Kinesis
    

### Why Each Component

### Event Ingestion: Kinesis Data Streams

**Why Kinesis?**

  * Fully managed, no broker patching, ZooKeeper, or rebalancing headaches
  * On-demand mode eliminates shard capacity planning for variable event volumes
  * Enhanced fan-out gives dedicated 2 MB/s throughput per consumer (Glue + archival consumers don't compete)
  * Native integration with Glue Streaming, Lambda, and Firehose for zero-code S3 archival
  * 7-day retention for replay during pipeline recovery
  * Cost: On-demand pricing at ~$0.08/GB ingested. At 300 GB/day raw events = ~$24/day
  * Trade-off: Less flexible than self-managed Kafka (no compacted topics, 365-day max retention). Use MSK if you need Kafka protocol compatibility or topic compaction for changelog streams

### Feature Engineering: AWS Glue

**Why Glue?**

  * Serverless Spark, no cluster management, auto-scales DPUs based on data volume
  * Glue Streaming ETL processes Kinesis events in configurable micro-batch windows (1-15 minutes)
  * Glue Data Catalog provides a centralized metadata store for feature definitions
  * Glue Job Bookmarks track what data has been processed (exactly-once semantics for batch)
  * Built-in support for Parquet, Delta Lake, and Iceberg on S3
  * Cost: $0.44/DPU-hour. Daily feature computation (~4 hours, 20 DPUs) = ~$35/day

**Glue writes to two destinations:**

  * **S3 (Data Lake):** Raw + processed events in Iceberg format, partitioned by date. Lifecycle: S3 Standard (90d) -> S3 IA (1y) -> Glacier (archive)
  * **SageMaker Feature Store:** Computed feature vectors for both online and offline consumption

### Feature Store: SageMaker Feature Store

**Why SageMaker Feature Store?**

  * Unified online + offline store from a single feature group definition
  * Online store: sub-10ms key-value lookups (backed by an internal low-latency store)
  * Offline store: automatic materialization to S3 in Iceberg/Parquet for training data generation
  * Point-in-time queries via `as_of` timestamp for training-serving consistency
  * Feature group versioning and metadata management
  * Native integration with SageMaker Training and Processing jobs

**Configuration:**

  * Online store enabled for real-time scoring features (200+ features per user)
  * Offline store on S3 with daily snapshots partitioned by `event_time`
  * TTL on online store: 90 days (users inactive > 90 days served from offline store)

### ML Training: SageMaker Training + Autopilot

**SageMaker Training Jobs:**

  * Built-in XGBoost and LightGBM algorithms (optimized containers, distributed training)
  * Spot instances for training (70% cost savings with managed interruption handling)
  * Automatic model tuning (Bayesian optimization) with up to 50 parallel trials
  * Training data read directly from Feature Store offline group (point-in-time correct)
  * Artifacts saved to S3 and registered in SageMaker Model Registry

**SageMaker Model Registry:**

  * Versioned model artifacts with approval workflow (staging -> approved -> production)
  * Model cards auto-generated with training metrics, data lineage, and bias assessment
  * CI/CD integration: approval triggers CodePipeline for automated deployment

### Model Serving: SageMaker Endpoints

**Batch scoring (daily):**

  * SageMaker Batch Transform: serverless, processes 10M users in ~45 minutes
  * Reads features from offline store, writes predictions to S3, then COPY into Redshift
  * Scheduled by MWAA (Airflow) DAG at 3 AM UTC

**Real-time scoring:**

  * SageMaker Real-Time Endpoint with auto-scaling (min 2 instances, max 20)
  * Multi-model endpoint: champion + shadow model served from the same endpoint
  * Target tracking scaling policy: scale on `InvocationsPerInstance` > 500
  * Endpoint latency: < 50ms p99 on ml.m5.xlarge instances

### Orchestration: MWAA + Step Functions + EventBridge

**MWAA (Managed Airflow)** for data pipelines:

  * Glue job scheduling (feature computation DAGs)
  * Feature freshness SLA checks (sensor tasks)
  * Data quality validation before scoring

**Step Functions** for ML pipeline:

  * Training -> evaluation -> registry -> approval -> deployment as a state machine
  * Built-in error handling, retry, and human approval steps
  * Visual workflow monitoring in AWS Console

**EventBridge** for event-driven triggers:

  * Scheduled rules: weekly retraining trigger
  * CloudWatch alarm rules: model drift detected -> trigger retraining Step Function
  * SageMaker events: training job complete -> notify Slack via SNS

### Monitoring: CloudWatch + SageMaker Model Monitor

**SageMaker Model Monitor:**

  * Data quality monitoring: feature drift detection (PSI, KS test) on every batch scoring run
  * Model quality monitoring: compare predictions vs actuals (after 30-day label window)
  * Bias drift monitoring: fairness metrics across user segments
  * Alerts routed to CloudWatch -> SNS -> PagerDuty

**CloudWatch dashboards:**

  * Feature freshness SLA compliance
  * Scoring endpoint latency and error rates
  * Kinesis consumer lag (feature computation delay)
  * DLQ depth and reprocessing rate

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Kinesis| On-demand mode (auto-scales, no over-provisioning)| 30-50% vs
provisioned  
Glue| Auto-scaling DPUs + Flex execution (non-urgent jobs)| 20-40%  
SageMaker Training| Spot instances with managed interruption| 60-70%  
SageMaker Endpoints| Auto-scaling + Savings Plans for baseline capacity|
30-50%  
S3| Lifecycle: Standard -> IA -> Glacier| 70-80% on historical data  
Redshift| Serverless (pay per query)| 50-70% vs provisioned cluster

