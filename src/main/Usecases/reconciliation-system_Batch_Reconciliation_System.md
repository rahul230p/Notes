# Batch Reconciliation System

Source: https://datapathsala.com/system-design/reconciliation-system

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

# Batch Reconciliation System

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a data reconciliation system for a fintech platform that processes 50
million payment transactions per day across three upstream sources (payment
gateway, bank ledger, internal wallet service). Each batch job runs at
midnight to reconcile the day's transactions. Some upstream jobs fail
partially, data arrives late, or records go missing. The business requires:
every transaction must be accounted for, discrepancies must be flagged and
resolved within 4 hours, and the reconciliation must be re-runnable without
creating duplicates. How would you design this end to end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Unique

Reconciliation is one of the most commonly asked data engineering system
design questions in fintech, payments, and banking interviews — and the one
most candidates answer incorrectly. The typical wrong answer is: "compare
tables A and B, find mismatches, send alerts." That describes a one-time
script, not a production-grade reconciliation system.

The hard problems are not the comparison logic. They are **re-runnability,
partial upstream failures, and late-arriving data** — and these interact with
each other in ways that break naive designs.

**Hard problem 1: Idempotency under re-runs** Upstream jobs fail. Your
reconciliation job will be re-run — by an on-call engineer at 2am, by an
automated retry, or by a scheduled backfill. Every re-run must produce the
same result and must not double-count, double-alert, or create duplicate
discrepancy records. Most candidates skip this entirely and design a system
that breaks on its second run.

**Hard problem 2: Partial upstream failure** "The upstream job failed" almost
never means zero data. It usually means 80% of records arrived and 20% are
missing. You need to distinguish between: data that hasn't arrived yet (wait),
data that will never arrive (escalate), and data that arrived corrupted
(reject and re-request). These three cases have different resolution paths.

**Hard problem 3: Late data and the reconciliation window** Transactions that
occur at 23:59 might not land in the source system until 01:30 the next day
due to settlement delays. A reconciliation job that runs at 00:05 will always
see these as missing. Your design must define a reconciliation window (e.g.,
T+4 hours) and handle records that arrive after the window closes.

## What the Interviewer Is Actually Testing

  * **Idempotency design** : Can you describe exactly how a re-run produces the same output without duplicates?
  * **Failure taxonomy** : Do you distinguish between "missing data" vs "wrong data" vs "late data"?
  * **Operational thinking** : What happens when 30% of transactions from the payment gateway are missing at 00:05? Who gets paged, what is the escalation path, and how does the system recover?
  * **Data modeling** : Can you design the reconciliation_runs and discrepancies tables with the right status state machine?

## How to Structure Your Answer (45 min)

Phase| Focus| What a Strong Answer Looks Like  
---|---|---  
**Scoping (5 min)**|  Define reconciliation window, SLA, upstream count| Ask
about partial failure handling and re-run requirements upfront  
**Architecture sketch (8 min)**|  Extractor → Staging → Recon Engine →
Resolution| Name idempotency as a first-class design concern before drawing
boxes  
**Idempotency deep-dive (10 min)**|  run_id, upsert patterns, status state
machine| Show exactly how a re-run behaves differently from a first run  
**Failure taxonomy (8 min)**|  Missing vs late vs corrupt, auto-resolve vs
manual| Define the 4-hour SLA as a trigger for escalation, not just alerting  
**Data modeling (8 min)**|  reconciliation_runs, discrepancies, audit_log|
Include status enum, resolution_reason, and version columns  
**Monitoring (6 min)**|  Gap rate trending, SLA breach detection, upstream
health| Connect metrics to business outcomes  
  
## Opening Move

> "Before I design anything, I want to flag the three hard problems here:
> idempotency — every re-run must be safe because upstream failures guarantee
> re-runs; partial failure taxonomy — we need to distinguish missing, late,
> and corrupt data because each has a different resolution path; and
> reconciliation window — settlement delays mean some transactions don't land
> until hours after midnight, so we need a defined window before we can
> declare a record truly missing. With those in mind, what is the 4-hour SLA
> measured from — midnight, or from when the upstream extract completes?"

This immediately signals you have operated reconciliation systems in
production.

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

batch pullraw filescheck run_idread partitionsrow counts / sumsmatched
recordsgaps / unmatchedchecksum failuresevery run loggedauto-resolvablemanual
reviewapply fixlog reason

Payment Gateway

Bank Ledger

Internal Wallet Service

![Source Extractor \(Airflow\)](/icons/tools/airflow.svg)Source Extractor
(Airflow)

Staging Layer (S3/GCS)

Idempotency Store (Redis)

![Recon Engine \(Spark\)](/icons/tools/spark.svg)Recon Engine (Spark)

Checksum Validator

Reconciliation DB (Postgres)

Discrepancy Queue

Audit Log (append-only)

Auto-Resolver

Alerting & Dashboard

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation

Idempotency: The Most Important Design Decision

Handling Partial Upstream Failures

Data Modeling

Monitoring & Alerting

Architecture Walkthrough

Component Deep Dive

Scalability & Fault Tolerance

Technology Comparison

Follow-Up Questions & Answers

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS — Architecture

batch drop_SUCCESS triggercheck run_idtrigger Spark jobmatched
recordsdiscrepanciesaudit eventsauto-resolvablemanual reviewapply fixlog
reason

Payment Gateway

Bank Ledger

Internal Wallet

![S3 \(Staging\)](/icons/aws/s3.svg)S3 (Staging)

MWAA (Airflow)

ElastiCache (Redis)

AWS Glue / EMR (Spark)

RDS PostgreSQL

SQS Discrepancy Queue

![S3 + Athena \(Audit Log\)](/icons/aws/s3.svg)S3 + Athena (Audit Log)

Lambda (Auto-Resolver)

SNS + CloudWatch

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around S3 for staging, MWAA (managed Airflow) for
> orchestration, AWS Glue or EMR for the Spark reconciliation job, ElastiCache
> Redis for idempotency locking, RDS PostgreSQL for discrepancy tracking, and
> S3 + Athena for the 7-year audit log."

### End-to-End Data Flow

    
    
    1. Upstream sources write daily snapshots to S3 (s3://staging/source=*/dt=*/)
    2. Each source writes a _SUCCESS sentinel file when its export is complete
    3. S3 Event Notification -> Lambda triggers Airflow DAG run (or MWAA sensor polls)
    4. MWAA checks all 3 _SUCCESS files; waits up to T+2h if any source is late
    5. Lambda acquires Redis SETNX lock: recon:run:{date} -> run_id
    6. Checksum validator Lambda reads _metadata.json per source, compares row counts and amount totals
    7. If checksums pass, MWAA triggers AWS Glue / EMR Spark job
    8. Spark performs 3-way full outer join on transaction_id, writes results:
       - Matched summary -> RDS PostgreSQL (reconciliation_runs)
       - Discrepancies -> SQS queue + RDS PostgreSQL (discrepancies via upsert)
       - All events -> S3 audit log (Parquet, partitioned by month)
    9. Lambda auto-resolver reads from SQS, applies resolution rules
    10. SNS -> CloudWatch alarms for gap rate > 0.1%, unresolved high-value discrepancies
    

### Why Each Component

### Staging Layer: S3

**Why S3 for staging?**

  * Effectively unlimited storage, no provisioning needed
  * S3 Event Notifications trigger Lambda the moment a `_SUCCESS` file lands — zero polling latency
  * Strong consistency (since 2021): any object written is immediately visible to all readers — no stale reads on Spark job startup
  * Lifecycle policies: Standard (30 days active reconciliation) → Infrequent Access (90 days) → Glacier Deep Archive (7-year compliance retention) at ~$0.004/GB/month
  * Multipart upload handles large source files (>5GB) without timeouts

**Trade-off:** S3 is not a message queue — you can't easily track which files
have been processed. The `_SUCCESS` sentinel pattern + Redis idempotency lock
handles this. If sources delivered via Kinesis instead of file drops, use
Kinesis Data Firehose to write to S3.

### Orchestration: MWAA (Managed Airflow)

**Why MWAA over Step Functions?**

  * S3KeySensor is a first-class Airflow operator — waits for `_SUCCESS` files with configurable timeout and retry logic
  * Backfill support is native: `airflow dags backfill -s 2024-01-01 -e 2024-01-14` reruns 14 days in parallel
  * DAG-level dependency management: checksum task must succeed before Spark task runs (enforced in the DAG graph)
  * Rich retry configuration: exponential backoff, alerting on failure, separate retry for each task

**Config:** mw1.small (2 schedulers, 5 workers) is sufficient for a nightly
batch job. Cost: ~$300-500/month.

**Trade-off:** MWAA has a ~3-5 minute cold start for the scheduler. For a
nightly job this is irrelevant, but it's worth knowing if you're considering
hourly runs. Step Functions has zero cold start but lacks file sensors
natively.

### Reconciliation Engine: AWS Glue vs EMR

**AWS Glue (serverless Spark):**

  * Zero cluster management, auto-scales workers
  * Native Glue Catalog integration (schema registry for staging Parquet files)
  * Glue Data Quality for pre-job checksum validation (built-in DQ rules)
  * Cost: ~$0.44/DPU-hour. A 50M record join using 20 DPUs takes ~20 min = ~$3/run.

**Amazon EMR (self-managed Spark):**

  * Full control over instance types, Spark config, and cluster sizing
  * Spot instances for executors: 60-70% cost reduction vs on-demand
  * Cost: 20 × m5.xlarge spot (~$0.06/hr each) for 20 min = ~$0.40/run
  * EMR Serverless: serverless mode with pre-initialized worker pools (eliminates 3-5 min cold start)

**Recommendation:** Start with Glue for simplicity. Migrate to EMR Serverless
if costs exceed ~$200/month or you need Spark configuration tuning.

### Idempotency Store: ElastiCache Redis

**Why ElastiCache Redis?**

  * SETNX is a single atomic operation — no race condition between two concurrent Airflow retries
  * TTL-based auto-expiry: if a job crashes, the lock releases automatically after 48h — no manual cleanup
  * Sub-millisecond latency (adds zero overhead to a 20-minute batch job)
  * Cost: cache.t3.micro (~$15/month) is sufficient — idempotency keys are tiny (<200 bytes each)

**DynamoDB with conditional writes** is a viable alternative for teams who
want zero Redis management:

    
    
    # DynamoDB conditional write (atomic, same as Redis SETNX)
    table.put_item(
        Item={'pk': f'recon:run:{business_date}', 'run_id': run_id, 'ttl': int(time.time()) + 172800},
        ConditionExpression='attribute_not_exists(pk)'
    )
    # Raises ConditionalCheckFailedException if key already exists
    

### Reconciliation DB: RDS PostgreSQL

**Why RDS PostgreSQL over DynamoDB for discrepancies?**

  * Discrepancies are an OLTP workload: status updates, point lookups by `transaction_id`, concurrent writes from the resolver
  * `ON CONFLICT DO UPDATE` (upsert) is a single SQL statement — DynamoDB requires a read-then-write pattern
  * The `discrepancies` table at 50K rows/day × 30 days = 1.5M rows — fits comfortably in Postgres, no need for a distributed DB
  * Finance team queries (`SELECT * FROM discrepancies WHERE status = 'open' AND amount_diff > 10000`) are SQL-native

**Config:** db.t3.medium Multi-AZ (~$120/month). Automated backups with 35-day
retention. Move closed discrepancies (status = manually_resolved) to S3 +
Athena after 30 days for long-term analytics.

### Audit Log: S3 + Athena

**Why S3 + Athena over Redshift for the audit log?**

  * Audit logs are write-once, read-rarely (mostly for compliance investigations)
  * Athena charges $5/TB scanned — with Parquet + partition pruning by month, a typical compliance query scans <1GB = $0.005
  * Redshift charges per cluster-hour regardless of whether you're running queries. For a rarely-queried audit log, Athena is 95% cheaper.
  * S3 Object Lock (WORM mode): set after 30 days, prevents any deletion for 7 years — meets SOX and PCI-DSS immutability requirements

**Partition layout:**

    
    
    s3://audit-log/year=2024/month=01/day=15/
      - events are Parquet, compressed with Snappy
      - Athena partition projection eliminates the need to run MSCK REPAIR TABLE
    

### Alerting: SNS + CloudWatch

**CloudWatch custom metrics** (published by the Spark job via EMF):

  * `recon.gap_rate` — alarm if > 0.1% for 2 consecutive data points
  * `recon.upstream_delay_minutes` — alarm per source if > 60 minutes
  * `recon.unresolved_high_value_count` — alarm if > 0 (immediate page)
  * `recon.job_duration_minutes` — alarm if > 60 (SLA risk)

**SNS topics:** separate topics for WARNING (Slack channel) and CRITICAL
(PagerDuty on-call).

### Cost Estimate (AWS)

Service| Monthly Cost| Notes  
---|---|---  
S3 (staging + audit)| $15–30| ~50GB/month staging + 2TB audit (lifecycle to
IA/Glacier)  
MWAA (mw1.small)| $300–500| Fixed cost regardless of run frequency  
AWS Glue (Spark)| $60–90| 30 runs/month × 20 DPU × 20 min × $0.44/DPU-hr  
ElastiCache (t3.micro)| $15| Idempotency store only  
RDS PostgreSQL (t3.medium Multi-AZ)| $120| Discrepancies + reconciliation_runs  
SNS + Lambda (resolver)| $5–10| Pay per invocation  
CloudWatch| $20–30| Custom metrics + alarms  
**Total**| **$535–795/month**|  For 50M transactions/day  
  
### Cost Optimization

Service| Optimization| Savings  
---|---|---  
EMR Spark (instead of Glue)| Spot instances for executors| 60-70% on compute  
S3 staging files| Parquet + Snappy compression (10-20× vs CSV)| 90% on storage  
RDS| Archive closed discrepancies to S3 after 30 days| Keeps DB small, avoids
storage scaling  
MWAA| Use a smaller environment (mw1.micro) if only running nightly| ~30%
savings  
Audit log (S3)| Lifecycle to Glacier Deep Archive after 90 days| 80% on
storage cost

