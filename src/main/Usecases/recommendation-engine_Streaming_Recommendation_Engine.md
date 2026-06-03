# Streaming Recommendation Engine

Source: https://datapathsala.com/system-design/recommendation-engine

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Streaming Recommendation EngineAdd
Note

# Streaming Recommendation Engine

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a streaming recommendation engine for a large-scale music or video
platform (think Spotify, Netflix, or YouTube). The system must deliver
personalized content recommendations to 100 million users using collaborative
filtering, content-based signals, and real-time user behavior. User
interaction events, plays, likes, skips, searches, and playlist additions,
arrive at 500K events per second. Recommendations must refresh in near-real-
time as users interact, while batch model training runs daily. How would you
design the end-to-end data pipeline, from event ingestion through embedding
generation to real-time serving?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Recommendation engines have three hard problems that separate generic system
design answers from ones that show genuine depth. Knowing these upfront shapes
every architectural decision you make.

### Three Hard Problems Unique to Recommendation Engines

**1\. The cold start problem requires a completely different strategy than
collaborative filtering.**

A new user has no interaction history. A new item has no ratings. Matrix
factorization fails silently, either returning generic recommendations or
errors. Strong answers have a dedicated cold start path: content-based
features for new items (genre, tags, metadata), popularity/trending fallback
for new users, and a graduated enrichment pipeline as interactions accumulate.
The progression looks like this: new user gets popular items, session-based
signals emerge after 5-10 interactions, and full personalization kicks in
after roughly 20-100 interactions. The key insight is that cold start is not a
one-time edge case. New users and new items arrive continuously, so the cold
start path must be production-grade and always-on.

**2\. Training-serving skew: the model was trained on yesterday's data but the
user acted 10 minutes ago.**

Batch-trained collaborative filtering models miss real-time session context. A
user just watched 5 action movies in a row but that signal is invisible to a
model scored from last night's run. Strong answers combine batch model scores
(updated daily or hourly) with a real-time re-ranking layer that applies
session-context features computed on the fly. The architecture implication is
a two-layer system: Flink or Dataflow computes fresh user feature vectors on
every event and writes them to a fast feature store like Redis, while the
batch model handles long-term preference signals. The serving pipeline merges
both at request time.

**3\. A/B testing recommendations is statistically harder than A/B testing a
button color.**

Recommendations have interference effects: items shown to experiment users get
discussed, shared, and affect behavior in control groups. A user in the
treatment arm tells their friend about a song they found, and the friend (in
the control arm) searches for it. That cross-contamination inflates treatment
effect estimates. Strong answers use time-based or geo-based splits rather
than random user assignment, measure downstream metrics beyond click-through
rate (watch time, 7-day retention, catalog diversity), and understand that
novelty bias inflates early experiment results as users explore the new model.
Interleaving experiments, where items from both models are interspersed in a
single list and clicks are attributed back to the source model, reach
statistical significance 10-100x faster than traditional A/B splits.

### What the Interviewer Is Testing

What They Want to See| Why It Matters  
---|---  
Awareness that real-time and batch are two separate systems that converge at
serving| Shows you understand latency constraints and the two-path
architecture  
A dedicated cold start strategy, not just "use content-based features"| Cold
start is always on; vague answers suggest you've never built one in production  
Understanding that offline metric improvement does not guarantee online
improvement| NDCG and recall are proxies; online CTR and retention are what
actually matter  
How the A/B testing setup accounts for recommendation-specific interference|
Shows you know that standard user-randomized splits are invalid for recs  
How you know the system is healthy without watching every recommendation|
Observability: feature freshness, embedding staleness, CTR by model version  
  
### Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| Clarify scale (users, catalog size, events/sec), freshness SLA, cold start
scope, A/B testing requirements| 2-3 min  
2| Sketch the dual-path architecture: event ingestion, real-time feature path
(Flink + feature store), batch training path (Spark + model registry),
convergence at the ranking service| 5 min  
3| Deep dive the ranking pipeline: candidate generation via ANN, pre-ranking,
full ranking, re-ranking for diversity and business rules| 10 min  
4| Address cold start explicitly: content-based embeddings for new items,
popularity fallback for new users, graduated enrichment pipeline| 5 min  
5| Cover observability, A/B testing design (why not simple user splits), and
failure modes (embedding store down, feature store down, stale model)| 5 min  
  
### Your Opening Move

> "Before I design anything, I want to confirm a few things that change the
> architecture significantly. How fresh do recommendations need to be after a
> user interaction, seconds or minutes? Do we need to handle cold start for
> both new users and new items? And are we expected to run A/B experiments on
> ranking models concurrently? The answers drive whether I need a real-time
> feature pipeline, a dedicated cold start path, and an experiment routing
> layer at the ranking service."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

500K events/secSchema Registry + publishreal-time streamuser features +
session contextreal-time featuresANN lookupmodel variant
routingrecommendationsraw events (bronze)training datatrained models +
embeddingspublish embeddingsdeploy ranking modelorchestratesgold (metrics +
features)enriched eventsfailed eventsreprocess after fix

User Apps (Web/Mobile)

API Gateway

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Flink (Real-Time Features)

Feature Store (Redis)

Ranking Service

Embedding Store

A/B Testing

![Spark \(Batch Training\)](/icons/tools/spark.svg)Spark (Batch Training)

![Airflow](/icons/tools/airflow.svg)Airflow

Model Registry

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

Cold Start & Multi-Stage Ranking

Scalability & Fault Tolerance

Monitoring & Observability

Real-Time Personalization & Experimentation

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

eventsvalidate + publishreal-time streamuser features + sessionreal-time
featuresFirehose (bronze)training datamodels + embeddingsdeploy modelgold
(analytics)failed eventsreprocess

User Apps

ALB + API Gateway

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Managed Flink

![DynamoDB \(Features\)](/icons/aws/dynamodb.svg)DynamoDB (Features)

SageMaker (Training)

Amazon Personalize

SageMaker Endpoints

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "Since we're on AWS, I'd build around Kinesis for event ingestion, Managed
> Flink for real-time feature computation, Amazon Personalize as the managed
> recommendation baseline, SageMaker for custom model training, and DynamoDB +
> ElastiCache for the feature store."

### End-to-End Data Flow

    
    
    1. User apps send interaction events -> ALB + API Gateway validates schema
    2. API Gateway publishes to Kinesis Data Streams (partitioned by user_id)
    3. Kinesis -> Managed Flink (real-time feature computation: session context, skip rate, category distribution)
    4. Flink -> DynamoDB (durable features) + ElastiCache Redis (hot features, sub-ms reads)
    5. Kinesis -> Firehose -> S3 (Iceberg format, bronze layer)
    6. S3 -> SageMaker Training Jobs (daily: ALS on Spark, Two-Tower on GPU instances)
    7. SageMaker -> Model Registry -> SageMaker Endpoints (ranking model serving)
    8. SageMaker -> S3 (embedding export) -> load into OpenSearch Serverless (ANN index)
    9. Amazon Personalize runs in parallel as managed baseline (auto-trains on S3 interaction data)
    10. Ranking Service (ECS/EKS): fetches features from ElastiCache + candidates from OpenSearch -> scores with SageMaker Endpoint -> re-ranks -> returns recommendations
    11. CloudWatch Evidently manages A/B testing (experiment assignment, metric tracking)
    12. S3 -> Redshift Serverless (gold layer analytics, dbt via MWAA)
    13. Failed events -> SQS DLQ -> inspect, fix, reprocess to Kinesis
    

### Why Each Component

### Event Ingestion: Kinesis Data Streams

**Why Kinesis over self-managed Kafka on AWS?**

  * Fully managed, no broker patching, ZooKeeper, or rebalancing headaches
  * On-demand mode eliminates shard capacity planning for 500K events/sec
  * Enhanced fan-out gives dedicated 2 MB/sec throughput per consumer (Flink + Firehose simultaneously)
  * Native integration with Managed Flink, Lambda, Firehose, and CloudWatch
  * 7-day retention for replay and reprocessing
  * Trade-off: Less flexible than Kafka (no compacted topics, 365-day max retention). Use MSK (Managed Kafka) if you need log compaction for changelog streams or cross-cloud portability.

**Config:** On-demand mode, 7-day retention, enhanced fan-out for both Flink
and Firehose consumers.

### Real-Time Features: Managed Flink

**Why Managed Flink?**

  * Same Flink engine as open-source, keyed state per user_id computes sliding-window features identically
  * Auto-scaling based on Kinesis consumer lag (backpressure-aware)
  * Managed checkpointing to S3, no RocksDB tuning needed
  * Computes: session category distribution, skip rate (30-min window), recent items list, price sensitivity
  * Pushes features to both DynamoDB (durable) and ElastiCache Redis (hot cache)
  * Cost: ~$0.11/KPU-hour, auto-scales based on event volume

### Managed Recommendations: Amazon Personalize

**Why include Personalize alongside custom models?**

  * Zero-ML-expertise baseline: feed interaction data to S3, Personalize auto-trains and serves
  * Supports real-time event ingestion via PutEvents API, recommendations update within seconds
  * Built-in recipes: USER_PERSONALIZATION, SIMILAR_ITEMS, TRENDING_NOW
  * Useful as a benchmark: if your custom Two-Tower model cannot beat Personalize, it is not worth the complexity
  * Trade-off: Black box (no access to embeddings), limited customization, cost scales with TPS ($0.05/1K recommendations)
  * Strategy: Run Personalize as control group in A/B tests against custom SageMaker models

### Custom Model Training: SageMaker

**Training pipeline:**

  * **SageMaker Processing Jobs:** Feature engineering on S3 data (Spark containers)
  * **SageMaker Training Jobs:** ALS on ml.m5.4xlarge (Spark), Two-Tower on ml.p3.8xlarge (4x V100 GPUs)
  * **SageMaker Experiments:** Track hyperparameters, metrics (recall@100, NDCG@10) per training run
  * **Model Registry:** Version control, approval workflows, lineage tracking
  * **SageMaker Endpoints:** Real-time inference with auto-scaling (2-50 instances based on QPS)
  * **Multi-model endpoints:** Host multiple ranking model variants on a single endpoint fleet for A/B testing

### Feature Store: DynamoDB + ElastiCache Redis

**DynamoDB** (durable feature store):

  * On-demand capacity, auto-scales to any traffic pattern
  * Stores user profiles, historical features, long-term preference vectors
  * DAX (in-memory cache) for frequently accessed user profiles
  * Global Tables for multi-region serving

**ElastiCache Redis** (hot feature cache):

  * Sub-millisecond reads for session features (recent items, category distribution, skip rate)
  * Cluster mode: 4 primaries + 4 replicas (64 GB each) for 120 GB feature data
  * TTL-based eviction: session features expire after 30 minutes of inactivity
  * Invalidation: Flink pushes feature updates on every user event

### Embedding Store: OpenSearch Serverless (Vector Search)

**Why OpenSearch Serverless for ANN?**

  * Managed vector search with HNSW indexing (FAISS-compatible)
  * Serverless, no cluster sizing, auto-scales with query volume
  * k-NN search with metadata filtering (filter by category, exclude blocked items)
  * Bulk index from S3 after daily model training
  * Trade-off: Higher latency than self-hosted FAISS (~10-15ms vs ~2ms). Acceptable within 50ms budget.

### A/B Testing: CloudWatch Evidently

  * Feature flags and experiment management
  * Consistent user-to-variant assignment (sticky bucketing)
  * Real-time metric dashboards (CTR, session time, skip rate, revenue)
  * Automatic launch/rollback based on metric thresholds
  * Integrates with CloudWatch for alerting on experiment degradation

### Analytics: S3 + Iceberg + Redshift Serverless

**S3 + Iceberg** for the data lake:

  * Bronze: raw events from Firehose (Parquet, partitioned by date)
  * Silver: enriched interactions (deduped, user features joined)
  * Gold: aggregated metrics, recommendation effectiveness, model evaluation
  * Lifecycle: Standard (90d) -> IA (1y) -> Glacier (archive)

**Redshift Serverless** for analytics:

  * Pay per query, no cluster management
  * dbt models run via MWAA (Managed Airflow)
  * QuickSight dashboards for recommendation quality, A/B test results, business KPIs

**MWAA (Managed Airflow)** for orchestration:

  * Daily DAG: data validation -> feature engineering -> model training -> evaluation -> deployment
  * Triggers SageMaker training jobs, monitors completion, promotes models to endpoints

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Kinesis| On-demand mode (auto-scales, no over-provisioning)| 30-50% vs
provisioned  
Managed Flink| Auto-scaling KPUs (scales down nights/weekends)| 40-60% vs
fixed  
DynamoDB| On-demand + DAX cache for hot reads| 40-60% vs provisioned  
SageMaker| Spot instances for training (70% cheaper), auto-scaling endpoints|
50-70% on training  
ElastiCache| Reserved nodes for baseline, auto-scaling for peak| 30-40%  
S3| Lifecycle policies + Intelligent Tiering| 60-80% on old data  
Redshift| Serverless (pay per query, not per cluster hour)| 50-70% for bursty
analytics  
Personalize| Use as baseline only, custom models for primary traffic| Control
costs at scale

