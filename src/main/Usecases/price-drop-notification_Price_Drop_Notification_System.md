# Price Drop Notification System

Source: https://datapathsala.com/system-design/price-drop-notification

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# Price Drop Notification System

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a data pipeline for an e-commerce platform that monitors product
prices across millions of SKUs, detects meaningful price drops, notifies
subscribed users across multiple channels (email, push, SMS), and measures
notification effectiveness, click-through rates, conversions, and revenue
attribution. The platform has 50 million registered users, 10 million products
with watchlists, and prices update roughly 5 times per product per day. How
would you design this end to end?”

Expand AllCollapse All15 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Unique

At first glance this sounds simple: detect a price drop, send a notification.
The trap is that candidates design for the happy path and miss the three hard
problems that actually define this system.

**Hard problem 1: Fan-out asymmetry** A single price event on a popular
product triggers millions of notifications. Your architecture must handle a
1,000,000:1 amplification ratio from one Kafka message to one million
deliveries without creating a thundering herd on downstream email and push
services.

**Hard problem 2: Price oscillation and deduplication** Prices bounce. A
product can drop, partially recover, and drop again multiple times a day.
Without a dedup strategy, users get spammed on the same product repeatedly.
The cooldown-plus-low-water-mark pattern is the key insight here.

**Hard problem 3: Effectiveness is correlation, not causation** "Users who
received a notification and purchased" is not the same as "notifications
caused purchases." Without holdout groups you are measuring correlation.
Bringing up incrementality testing unprompted is what separates a strong
answer from a textbook one.

## What the Interviewer Is Actually Testing

  * **Scope instinct** : Do you identify fan-out as the central challenge, or do you treat this like a simple CRUD notification job?
  * **Trade-off reasoning** : Every architectural choice here has a cost. Chunked fan-out adds latency. Fatigue caps risk missing real drops. Can you name those costs explicitly?
  * **Data modeling depth** : The effectiveness attribution schema with holdout group and attribution window is what shows you have built this kind of system before.
  * **Operational thinking** : Bad seller data (a $999 product accidentally at $9.99) triggering 1M false notifications is a real incident. Do you design for it proactively?

## How to Structure Your Answer (45 min)

Phase| Focus| What a Strong Answer Looks Like  
---|---|---  
**Scoping (5 min)**|  Define "price drop", channels, latency SLA| Ask about
oscillation handling and effectiveness measurement — most candidates skip
these  
**Architecture sketch (8 min)**|  Three-stage pipeline: detect, match,
dispatch| Name fan-out as the central challenge before drawing a single box  
**Component deep-dives (20 min)**|  Flink keyed state, two-tier watchlist,
fatigue control| Proactively cover oscillation dedup and bad price detection  
**Data modeling (5 min)**|  Price history, notification log, effectiveness
schema| Show the holdout group column and attribution window in the schema  
**Effectiveness and attribution (5 min)**|  Holdout groups, incrementality|
Most candidates skip this entirely  
**Monitoring (5 min)**|  Pipeline health and business metrics| Connect metrics
to business outcomes ("unsubscribe rate rising means fatigue cap is too
loose")  
  
## Opening Move

> "Before I design anything, I want to flag the three hard problems in this
> system: fan-out, where one popular product price drop can trigger a million
> notifications from a single event; oscillation, where prices bounce
> repeatedly and we need to avoid spamming users; and effectiveness
> attribution, where we need holdout groups to measure whether notifications
> actually cause purchases or just correlate with them. With those in mind,
> what is the notification latency SLA and what constitutes a meaningful price
> drop?"

This frames the problem correctly from the start and signals you have thought
beyond the happy path.

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

50M updates/dayproduct metadataprice events streamstore price historyprice
drop eventsuser preferencesmatched notificationsemail channelpush channelSMS
channellog deliveryeffectiveness datafailed eventsreprocess after fixdelivery
failuresretry with backoff

Seller API / Price Feed

Product Catalog DB

![Apache Kafka](/icons/tools/kafka.svg)Apache Kafka

Price Change Detector (Flink)

Notification Matcher

Notification Dispatcher

Price History DB

User Watchlist Store

Notification Log

Data Lake (S3/GCS)

Email Service

Push Service

SMS Gateway

Dead Letter Queue

Retry Queue

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation & Capacity Planning

Architecture Walkthrough, End-to-End Data Flow

Component Deep Dive

Data Modeling & Schema Design

Notification Delivery, Multi-Channel at Scale

Effectiveness Measurement & Attribution

Scalability & Fault Tolerance

Deduplication & Price Oscillation Handling

Monitoring & Observability

Bad Price Data & Incident Prevention

Common Follow-Up Questions

Technology Comparison Table

Whiteboard Summary & Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

price updatesvalidate + publishdetect price dropslookup watchlistsprice drop
eventsfan-out notificationsemail deliverypush + SMSprice history +
logseffectiveness analyticsfailed eventsreprocess

Seller API / Feed

API Gateway

![Kinesis Data Streams](/icons/aws/kinesis.svg)Kinesis Data Streams

Managed Flink

![DynamoDB \(Watchlists\)](/icons/aws/dynamodb.svg)DynamoDB (Watchlists)

Lambda (Fan-Out)

SNS + SQS

SES (Email)

Pinpoint (Push/SMS)

![S3 + Iceberg](/icons/aws/s3.svg)S3 + Iceberg

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "Since we're on AWS, I'd build around Kinesis for price ingestion, Managed
> Flink for detection, DynamoDB for watchlists, Lambda for fan-out, and
> SNS/SES for multi-channel delivery."

### End-to-End Data Flow

    
    
    1. Seller API sends price updates -> API Gateway validates schema
    2. API Gateway publishes to Kinesis Data Streams (partitioned by product_id)
    3. Kinesis -> Managed Flink (price change detection with keyed state)
    4. Flink detects drop -> queries DynamoDB (user watchlists)
    5. Flink emits drop events -> Lambda (fan-out function)
    6. Lambda chunks subscribers -> SNS topics -> SQS queues per channel
    7. SQS -> SES (email), Pinpoint (push + SMS)
    8. Flink also writes all prices to S3 (Iceberg format)
    9. S3 -> Redshift Serverless (effectiveness analytics via dbt)
    10. Failed events -> SQS DLQ -> inspect, fix, reprocess to Kinesis
    

### Why Each Component

### Price Ingestion: Kinesis Data Streams

**Why Kinesis over self-managed Kafka on AWS?**

  * Fully managed, no broker patching, ZooKeeper, or rebalancing
  * On-demand mode eliminates shard capacity planning
  * Native integration with Managed Flink, Lambda, and CloudWatch
  * Enhanced fan-out gives dedicated throughput per consumer
  * Trade-off: Less flexible than Kafka (no compacted topics, 365-day max retention). At 580 events/sec average, Kinesis on-demand is cost-effective. Use MSK (managed Kafka) if you need topic compaction for changelog streams.

**Config:** On-demand mode, 7-day retention, enhanced fan-out for Flink
consumer.

### Price Detection: Managed Flink

**Why Managed Flink?**

  * Same Flink engine as open-source, keyed state per product_id works identically
  * Auto-scaling based on Kinesis consumer lag (backpressure-aware)
  * Managed checkpointing to S3, no RocksDB tuning needed
  * Cost: ~$0.11/KPU-hour, auto-scales down when price feed is quiet (nights/weekends)
  * Trade-off: Slightly higher latency (~1-3 sec) vs self-hosted (~100ms). Acceptable since our SLA is 5 minutes.

### Watchlist Store: DynamoDB

**Why DynamoDB for watchlists?**

  * Single-digit millisecond reads at any scale (200M items no problem)
  * On-demand capacity mode, no provisioning, auto-scales to any traffic pattern
  * GSI for user-facing queries (`PK=user_id`) without maintaining a second table
  * DynamoDB Streams for change data capture, trigger Lambda on watchlist changes to invalidate Redis cache
  * Global Tables for multi-region (if needed later)
  * Cost: ~$1.25/million reads on-demand. At 500K price drops/day × 20 avg subscribers = 10M reads/day = ~$12.50/day.

**ElastiCache Redis** in front for hot products: top 10K products cached, sub-
ms lookups, auto-populated via DynamoDB reads.

### Fan-Out: Lambda

**Why Lambda for fan-out?**

  * Triggered by Flink output (via Kinesis or direct invocation)
  * Each Lambda invocation handles one product's subscriber list
  * Reads from DynamoDB, chunks subscribers, publishes to SNS/SQS
  * Auto-scales to 1000+ concurrent executions (handles hot products)
  * Cost: 10M notifications/day × ~100ms per invoke = ~$0.20/day for compute
  * Trade-off: 15-minute max execution time. For 10M-subscriber products, use Step Functions to orchestrate multiple Lambda calls.

### Notification Delivery: SNS + SES + Pinpoint

**SNS** as the router:

  * SNS topic per notification priority (high/medium/low)
  * SNS -> SQS queues per channel (email queue, push queue, SMS queue)
  * SQS provides buffering, retry, and DLQ for each channel independently

**SES for email:**

  * $0.10 per 1,000 emails = $1,000/day for 10M emails
  * Dedicated IPs for reputation management
  * Configuration sets for tracking opens/clicks
  * SES events -> Kinesis Firehose -> S3 for click/open tracking data

**Pinpoint for push + SMS:**

  * Push: free up to 1M notifications/month, then $0.50/million
  * SMS: $0.00645/msg (US). At 500K SMS/day = ~$3,200/day. Use SMS sparingly (>20% drops only).
  * Pinpoint campaigns for A/B testing different templates

### Analytics: S3 + Iceberg + Redshift Serverless

**S3 + Iceberg** for the data lake (price history + notification log)

  * Lifecycle: S3 Standard (90 days) -> S3 IA (1 year) -> Glacier (archive)
  * Iceberg for ACID transactions, time travel, schema evolution

**Redshift Serverless** for effectiveness analytics

  * Pay per query, no cluster management
  * dbt models run on schedule via MWAA (managed Airflow)
  * Connects to QuickSight for dashboards

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Kinesis| On-demand mode (auto-scales, no over-provisioning)| 30-50% vs
provisioned  
DynamoDB| On-demand mode + DAX cache for hot reads| 40-60% vs provisioned  
Lambda| ARM64 (Graviton) execution, 128MB memory| 20% cheaper  
SES| Dedicated IPs only for high-volume senders| Better deliverability = fewer
retries  
S3| Lifecycle policies: Standard -> IA -> Glacier| 70-80% on old data  
Redshift| Serverless (pay per query, not per cluster hour)| 50-70% for bursty
analytics

