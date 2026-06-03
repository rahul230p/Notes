# Large-Scale Historical Backfill Pipeline

Source: https://datapathsala.com/system-design/historical-backfill-pipeline

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Large-Scale Historical BackfillAdd
Note

# Large-Scale Historical Backfill Pipeline

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Your data team discovers that the customer lifetime value metric — used in
executive dashboards, ML models, and budget planning — has been calculated
with a bug in the attribution logic for the past 3 years. You have 5 years of
raw event data stored in S3 in daily Parquet partitions: approximately 15
terabytes, 2 trillion events. The new corrected pipeline also adds 3 new
derived features the ML team needs. You must reprocess all 5 years of data
(1,825 partitions) within 2 weeks without impacting the live nightly pipeline
that runs on the same cluster and reads from the same source data. The
backfill must be resumable: if it fails at day 1,200 of 1,825, it should
continue from day 1,200, not restart from day 1. You must be able to roll back
if the new output is discovered to be wrong after promotion. Design this end
to end.”

Expand AllCollapse All15 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Unique

Historical backfill questions test a different skill set from forward-looking
pipeline design. The interviewer is evaluating whether you can manage risk,
isolate blast radius, and maintain operational correctness while running a
potentially month-long job that touches petabytes of data. The three hard
problems are not about Spark performance — they are about correctness under
failure and safe promotion.

**Hard problem 1: Resumability without data corruption** A 14-day job running
across 1,825 partitions will fail multiple times. The question is: when it
resumes, does it re-process partitions that already completed, and if so, does
that produce duplicate or corrupted output? Naive designs either restart from
scratch (24 hours of wasted work per failure) or skip re-processing but can't
detect which partitions produced partial output due to a mid-job crash. The
correct design is partition-level idempotent checkpointing: each partition job
writes to an isolated output path and atomically marks itself complete in the
checkpoint store. On resume, completed partitions are deterministically
skipped; in-flight partitions with stale heartbeats are detected and requeued.

**Hard problem 2: Isolation from the live pipeline** The live nightly pipeline
runs on the same source data and possibly the same cluster. During the 2-week
backfill, the live pipeline must continue to meet its 8-hour SLA. Two failure
modes: resource starvation (backfill consumes all Spark executors when the
live job needs them) and output contamination (backfill writes to the wrong
path and corrupts production data). Isolation requires either a separate
cluster, time-of-day throttling, or resource queues with guaranteed capacity
for the live pipeline.

**Hard problem 3: Rollback strategy after promotion** The backfill completes,
passes validation, and is promoted to production. A week later, a data
scientist notices that the new CLV metric has anomalous spikes for certain
customer segments. Rollback requires: the old output to still exist (or be
reproducible), a clean way to swap production back to the old version, and a
notification to all downstream consumers that relied on the new output. Most
candidates do not design for post-promotion rollback.

## How to Structure Your Answer (45 min)

Phase| Time| Key Points  
---|---|---  
Scoping| 5 min| Confirm partition structure, timeline, live pipeline SLA,
rollback window  
Architecture| 8 min| 5-phase model: plan → execute → validate → promote →
cleanup  
Checkpointing deep dive| 10 min| DynamoDB schema, heartbeat pattern, zombie
detection, idempotent output paths  
Live isolation| 8 min| Separate cluster + time-of-day pause, S3 path access
control  
Validation + promotion| 7 min| Statistical comparison, blue/green paths,
atomic rename  
Cost + timeline| 7 min| Parallelism math, spot instance strategy, 14-day
feasibility  
  
## Opening Move

> "Before I design anything, I want to flag three non-obvious hard problems.
> First: resumability requires partition-level idempotent checkpoints — not
> just job-level retry — because a single job covers hundreds of partitions
> and a crash mid-job must not re-process already-completed partitions or
> produce partial output. Second: isolation from the live pipeline is critical
> and the most common design failure I see — running backfill on the same
> cluster as production is an SLA risk. Third: post-promotion rollback is
> usually skipped but essential — once you promote backfill output, you need a
> clean path back if something is wrong. With that in mind, what is the
> partition granularity of the source data, and does the live pipeline read
> from the same S3 paths I'll be backfilling?"

Clarifying Questions

## High-Level Architecture

enumerate 1,825 partitionsenqueue partition jobs (recent-first)initialise
partition statusconsume jobsmax 50 concurrent jobsidempotency check before
runwrite to backfill/ pathmark complete/failednightly reads (isolated)compare
new vs old outputvalidation reportatomic promotion (approved)progress metrics

Source Data Lake (15TB)

![Partition Planner](/icons/tools/airflow.svg)Partition Planner

Job Queue (SQS/Pub-Sub)

Checkpoint Store (DynamoDB)

Throttle Controller

![Spark Executor Pool \(Spot\)](/icons/tools/spark.svg)Spark Executor Pool
(Spot)

Live Nightly Pipeline

Output Staging Path

Statistical Validator

Promotion Gate

Production DWH

Progress Dashboard

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation

Architecture: The 5-Phase Model

Partitioning Strategy

Idempotency: Every Partition Job Must Be Safe to Re-Run

Checkpointing & Progress Tracking

Cost Optimization

Live Pipeline Isolation

Scaling and Timeline Risk

Monitoring the Backfill

Rollback Strategy

Technology Comparison

Follow-Up Q&A

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS — Architecture

list partitionsenqueue 1,825 jobsinit checkpoint tableSQS trigger Lambda → EMR
jobidempotency checkwrite to backfill/ prefixmark completeseparate cluster,
read isolationvalidate new vs old outputpromote on approval

![Source S3 \(15TB\)](/icons/aws/s3.svg)Source S3 (15TB)

Step Functions (Planner)

SQS (Job Queue)

DynamoDB (Checkpoints)

EMR Spot Fleet (Spark)

Live Pipeline EMR (Separate)

![S3 Staging \(backfill/\)](/icons/aws/s3.svg)S3 Staging (backfill/)

Glue DQ / Lambda Validator

![Production S3 Path](/icons/aws/s3.svg)Production S3 Path

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS I'd use Step Functions Express Workflows to enumerate 1,825
> partitions and enqueue them to SQS, a dedicated EMR Spot Fleet cluster
> isolated from the live pipeline, DynamoDB conditional writes for idempotent
> checkpointing, S3 staging with an IAM Deny on the production prefix, Glue DQ
> for statistical validation, and S3 Batch Operations for atomic promotion —
> the whole backfill comes in under $1,200."

### End-to-End Data Flow

    
    
    1.  Step Functions Express Workflow lists all s3://source/dt=*/ prefixes via S3 ListObjectsV2
        → 1,825 partition keys sorted most-recent-first (recent partitions enqueued first)
    2.  Map state fans out: for each partition, one parallel branch writes a PENDING item to
        DynamoDB and sends an SQS message {partition_date, source_path, backfill_run_id}
    3.  DynamoDB batch-write initialises 1,825 checkpoint items; GSI on status field for
        progress queries
    4.  Lambda polls SQS (event source mapping, concurrency=50) — checks DynamoDB before
        dispatching:
          • COMPLETED → delete SQS message, return (idempotent skip)
          • IN_PROGRESS + heartbeat < 5 min → skip (another worker running)
          • IN_PROGRESS + heartbeat > 5 min → mark FAILED, requeue (zombie recovery)
          • PENDING or FAILED → conditional-write IN_PROGRESS, submit EMR job
    5.  EMR Spot Fleet (separate cluster, dedicated backfill IAM role) runs one Spark job
        per partition; driver on On-Demand c5.xlarge, task nodes on m5.xlarge/m5a.xlarge Spot
    6.  Spark job applies corrected CLV logic + 3 new derived features; output written to
        s3://output/backfill/v1/dt={partition_date}/ (IAM Deny blocks writes to production/)
    7.  On job success: Lambda updates DynamoDB → COMPLETED with row_count, checksum, duration_ms;
        SQS message deleted within visibility timeout window
    8.  Zombie detector Lambda runs every 10 min; scans for IN_PROGRESS + stale heartbeat,
        marks FAILED, re-sends SQS message — automatic resurrection with no manual intervention
    9.  After all 1,825 partitions reach COMPLETED: Glue DQ job runs statistical validation
        (row count delta ≤ 5%, CLV median shift < 30%, null rate on new columns < 1%)
    10. Step Functions waits for human approval via SNS + manual activity token; sends Slack
        notification with validation report and one-click approve/reject link
    11. On approval: S3 Batch Operations job copies backfill/v1/ → production/ atomically;
        old production renamed to production-v0/ for 30-day rollback window
    12. Step Functions triggers cleanup Lambda: archives checkpoint table to S3, sets lifecycle
        rules on production-v0/ (expire after 30 days), posts completion metrics to CloudWatch
    

### Why Each Component

### Source: S3 Read Safety at Scale

**Why reading from S3 is safe for a concurrent backfill?**

  * Strong read consistency (since December 2020): any object written is immediately visible to all readers — no stale-read risk when 150 concurrent jobs all list the same prefix simultaneously
  * S3 Select pushes predicate and projection filters into S3 itself: instead of reading a full 1.5GB Parquet partition, S3 Select reads only the columns the CLV transform needs — reduces data scanned by 40–80% and cuts per-job runtime from 10 minutes to 2–4 minutes
  * S3 request rate limit: 5,500 GET requests/second **per prefix**. With 150 concurrent jobs all reading from the same `events/dt=*/` prefix, peak GET rate = 150 × 12 requests/partition = 1,800/second — safely under the limit. If source data uses a flat prefix with no date hierarchy, add a hash-prefix sharding layer (`events/shard=0/`, `events/shard=1/`) to multiply available throughput by the shard count
  * Glacier/Deep Archive check before starting: if source data was auto-tiered, all 1,825 partitions appear in ListObjects but GET requests will 403 until restored. Run a RestoreObject pass first (Glacier restore: 3–5 hours, $0.03/GB; Deep Archive: 12–48 hours, $0.03/GB). Add this as a Phase 0 step in Step Functions before enqueueing

**Trade-off:** S3 Select requires Parquet files to be stored without nested
schemas and with compatible compression (Snappy or gzip). If source files use
complex nested structs, fall back to full-file reads and rely on Parquet
column projection in Spark.

**S3 Select predicate pushdown example:**

    
    
    import boto3
    
    s3 = boto3.client("s3")
    response = s3.select_object_content(
        Bucket="data-lake",
        Key=f"events/dt={partition_date}/part-00001.parquet",
        ExpressionType="SQL",
        Expression="""
            SELECT customer_id, event_type, revenue, attribution_source, event_ts
            FROM S3Object
            WHERE event_type IN ('purchase', 'refund', 'subscription')
        """,
        InputSerialization={"Parquet": {}},
        OutputSerialization={"JSON": {"RecordDelimiter": "\n"}},
    )
    # Returns only matching rows and selected columns — 60-75% less data scanned
    

### Orchestration: Step Functions (Partition Planner)

**Why Step Functions over Airflow for planning 1,825 partitions?**

  * Step Functions Map state natively fans out thousands of parallel branches with no scheduler bottleneck — Airflow with 1,825 dynamically-generated tasks would queue state transitions through a single scheduler process, causing scheduling lag of 10–30 minutes during burst creation
  * Express Workflows handle up to 100,000 state transitions/second — the entire 1,825-partition planning phase completes in under 10 seconds
  * Built-in retry with configurable backoff per state — no need to write retry logic in the planner code
  * Step Functions Activity Tasks enable the human approval gate (send token to approver, wait indefinitely until token is returned with approve/reject decision)

**Trade-off:** Step Functions vs Airflow 2.3+ Dynamic Task Mapping — Airflow's
dynamic task mapping supports fan-out but still serialises task state updates
through the scheduler. At 1,825 tasks completing in rapid succession,
scheduler lag compounds. Step Functions decouples orchestration state from any
single process. For teams already running MWAA, use Airflow for outer
orchestration (planning, validation, promotion) and SQS for the inner dispatch
loop.

**Cost:** Express Workflows: $0.025 per 1,000 state transitions. For 1,825
partitions × ~10 transitions each = 18,250 transitions = **$0.46 total** for
the entire planning phase.

**Map state example:**

    
    
    {
      "Type": "Map",
      "MaxConcurrency": 0,
      "ItemsPath": "$.partitions",
      "Iterator": {
        "StartAt": "EnqueuePartition",
        "States": {
          "EnqueuePartition": {
            "Type": "Task",
            "Resource": "arn:aws:states:::sqs:sendMessage",
            "Parameters": {
              "QueueUrl": "https://sqs.us-east-1.amazonaws.com/123/backfill-jobs",
              "MessageBody.$": "States.JsonToString($.partition)"
            },
            "Next": "InitCheckpoint"
          },
          "InitCheckpoint": {
            "Type": "Task",
            "Resource": "arn:aws:states:::dynamodb:putItem",
            "Parameters": {
              "TableName": "backfill_checkpoints",
              "Item": {
                "partition_date": {"S.$": "$.partition.partition_date"},
                "status": {"S": "PENDING"},
                "backfill_run_id": {"S.$": "$.backfill_run_id"}
              },
              "ConditionExpression": "attribute_not_exists(partition_date)"
            },
            "End": true
          }
        }
      }
    }
    

### Job Queue: SQS

**Why SQS over Kafka or RabbitMQ for job dispatch?**

  * At-least-once delivery is acceptable here because DynamoDB conditional writes provide idempotency — even if SQS delivers the same message twice, the second Lambda invocation checks the checkpoint and skips if COMPLETED
  * Visibility timeout: set to 15 minutes (slightly longer than the 8–12 minute max job duration). If a job doesn't delete its message within 15 minutes, the message becomes visible again automatically — zombie recovery without any daemon process required
  * Dead Letter Queue: messages that fail 3+ consecutive times are moved to a DLQ; CloudWatch alarm on DLQ depth > 5 triggers immediate investigation
  * SQS Standard Queue handles 3,000 messages/second — at 1,825 total messages over 14 days, throughput is essentially irrelevant. The main value is managed retries and DLQ, not throughput.
  * FIFO Queue is not needed: order doesn't matter for partition processing, and FIFO throughput is limited to 300/second (Standard is unlimited)

**Cost:** $0.40 per million messages. 1,825 messages × 3 average attempts +
DLQ traffic = ~5,500 messages = **$0.002 total**. Operationally free.

**SQS receive loop in Lambda:**

    
    
    import boto3, json
    from datetime import datetime, timezone
    
    sqs = boto3.client("sqs")
    dynamo = boto3.resource("dynamodb").Table("backfill_checkpoints")
    QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/123/backfill-jobs"
    
    def handler(event, context):
        for record in event["Records"]:
            msg = json.loads(record["body"])
            partition_date = msg["partition_date"]
            receipt_handle = record["receiptHandle"]
    
            # Check checkpoint before dispatching
            item = dynamo.get_item(Key={"partition_date": partition_date}).get("Item", {})
            status = item.get("status", "PENDING")
    
            if status == "COMPLETED":
                sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt_handle)
                return  # idempotent skip
    
            if status == "IN_PROGRESS":
                heartbeat = datetime.fromisoformat(item["heartbeat_at"])
                age_seconds = (datetime.now(timezone.utc) - heartbeat).total_seconds()
                if age_seconds < 300:
                    return  # another worker has it; let visibility timeout handle retry
                # Zombie: fall through to mark IN_PROGRESS again
    
            # Claim the partition with a conditional write
            dynamo.update_item(
                Key={"partition_date": partition_date},
                UpdateExpression="SET #s = :s, worker_id = :w, heartbeat_at = :h",
                ConditionExpression="#s IN (:pending, :failed)",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={
                    ":s": "IN_PROGRESS", ":w": context.aws_request_id,
                    ":h": datetime.now(timezone.utc).isoformat(),
                    ":pending": "PENDING", ":failed": "FAILED"
                }
            )
            submit_emr_job(partition_date, msg["backfill_run_id"])
    

### Checkpoint Store: DynamoDB

**Why DynamoDB over Redis for checkpoints?**

  * Redis is in-memory by default: a Redis restart (Spot preemption of the Redis host, ElastiCache failover) loses all checkpoint state. Recovering requires a full table scan of completed S3 output paths to reconstruct state — hours of manual work. DynamoDB persists to disk with synchronous replication across 3 AZs; restart loses nothing.
  * Conditional writes for atomic status transitions: the PENDING → IN_PROGRESS transition uses `ConditionExpression` to ensure only one worker can claim a partition even if two Lambda invocations race. Redis SETNX also provides this, but requires careful TTL management; DynamoDB's `attribute_not_exists` and `IN (:pending, :failed)` conditions are more expressive.
  * TTL for automatic cleanup: set TTL to 90 days on each item; DynamoDB removes expired items automatically — no separate cleanup Lambda needed.
  * GSI on `status` field: Query IN_PROGRESS items for the zombie scan, FAILED items for retry analysis, COMPLETED items for progress reporting — all without full table scans.
  * On-demand billing: 1,825 items × 10 writes each = 18,250 write units = **$0.02 total**. Operationally free.

**Trade-off:** DynamoDB conditional writes add ~5–10ms latency vs Redis SETNX
(~0.3ms). For an 8–12 minute job, this is completely irrelevant. Redis would
be the right choice only if you needed sub-millisecond checkpoint latency for
thousands of micro-jobs per second.

**Conditional write for IN_PROGRESS transition:**

    
    
    import boto3
    from botocore.exceptions import ClientError
    
    dynamo = boto3.resource("dynamodb").Table("backfill_checkpoints")
    
    def claim_partition(partition_date: str, worker_id: str) -> bool:
        try:
            dynamo.update_item(
                Key={"partition_date": partition_date},
                UpdateExpression="SET #s = :in_progress, worker_id = :w, heartbeat_at = :h",
                # Atomic: only succeeds if status is PENDING or FAILED (not IN_PROGRESS or COMPLETED)
                ConditionExpression="#s IN (:pending, :failed)",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={
                    ":in_progress": "IN_PROGRESS",
                    ":w": worker_id,
                    ":h": datetime.now(timezone.utc).isoformat(),
                    ":pending": "PENDING",
                    ":failed": "FAILED"
                }
            )
            return True  # successfully claimed
        except ClientError as e:
            if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                return False  # another worker got there first — skip
            raise
    

### Compute: EMR Spot Fleet

**Why EMR Spot Fleet over EMR Serverless for a 14-day backfill?**

  * EMR Serverless has a default quota of 720 vCPUs per account per region. At 150 concurrent jobs × 4 vCPUs = 600 vCPUs, you are at 83% of the default limit with zero headroom for bursting — any job that needs a few extra tasks will queue. EMR Spot Fleet with a dedicated cluster gives you a fixed, predictable capacity allocation independent of account-level quotas.
  * EMR Serverless cold start: 60–90 seconds per job × 1,825 jobs = up to 45 hours of accumulated startup overhead over the 14-day run. A pre-warmed persistent EMR cluster has <1 second job startup — saving calendar time at no extra cost.
  * Spot Fleet allocation strategy: `capacityOptimized` — picks the instance type with the most available Spot capacity in the AZ, minimising interruption probability. Do not use `lowestPrice` for a 14-day job; it chases the cheapest instance type which is also the most over-demanded.
  * Instance fleet with 3–4 types: m5.xlarge, m5a.xlarge, m4.xlarge, r5.large — broader diversification means Spot supply is almost always available even during capacity crunches.
  * Driver node: On-Demand c5.xlarge only. Never use Spot for the driver — if the driver is preempted, the entire Spark application fails and the worker has to wait for zombie detection + requeue. A $0.19/hr On-Demand driver protecting a $0.06/hr Spot fleet is the right trade.

**Trade-off:** EMR Serverless is operationally simpler (no cluster management,
per-second billing) and better for unpredictable or infrequent workloads. For
a planned 14-day backfill with known concurrency, the persistent Spot Fleet is
30–40% cheaper and faster to start jobs.

**Cost math:** 150 × m5.xlarge Spot ($0.06/hr) × 336 hours (14 days) = $3,024
baseline. With 15% Spot interruption overhead (interrupted jobs re-run once =
15% more compute): **~$3,478**. In practice, most backfills complete closer to
10 days of actual runtime due to batch-processing efficiency, bringing the
real cost to ~$2,400. Add 1 On-Demand c5.xlarge driver ($0.19/hr × 336 hrs =
$64).

**Cluster config snippet:**

    
    
    emr.run_job_flow(
        Name="backfill-v1-cluster",
        ReleaseLabel="emr-6.15.0",
        Instances={
            "InstanceFleets": [
                {   # Driver: always On-Demand
                    "InstanceFleetType": "MASTER",
                    "TargetOnDemandCapacity": 1,
                    "InstanceTypeConfigs": [{"InstanceType": "c5.xlarge"}],
                },
                {   # Executor pool: Spot with 4 instance type options
                    "InstanceFleetType": "TASK",
                    "TargetSpotCapacity": 150,
                    "LaunchSpecifications": {
                        "SpotSpecification": {
                            "AllocationStrategy": "CAPACITY_OPTIMIZED",
                            "TimeoutDurationMinutes": 5,
                            "TimeoutAction": "SWITCH_TO_ON_DEMAND",
                        }
                    },
                    "InstanceTypeConfigs": [
                        {"InstanceType": "m5.xlarge",  "WeightedCapacity": 1},
                        {"InstanceType": "m5a.xlarge", "WeightedCapacity": 1},
                        {"InstanceType": "m4.xlarge",  "WeightedCapacity": 1},
                        {"InstanceType": "r5.large",   "WeightedCapacity": 1},
                    ],
                }
            ]
        },
        # Separate cluster = separate IAM role = Deny write access to production/
        JobFlowRole="BackfillEMRProfile",
        ServiceRole="BackfillEMRRole",
    )
    

### Output: S3 Staging Path + Promotion

**Why write to`backfill/v1/` first instead of directly to `production/`?**

  * The backfill cluster's IAM policy has an explicit Deny on `s3:PutObject` for the `production/` prefix. This is infrastructure-level blast radius containment — a configuration bug in the Spark job that writes to the wrong path will hit a permissions error, not silently corrupt production data.
  * Staging path structure: `s3://output/backfill/v1/dt={date}/` — isolated per-run, per-partition. If the backfill is restarted as v2, the v1 staging output is preserved until explicitly cleaned up.
  * S3 Batch Operations for promotion: instead of running 1,825 individual CopyObject API calls from a Lambda (which takes 30–60 minutes sequentially), S3 Batch Operations accepts a manifest CSV and executes all copies in parallel across AWS's internal copy fleet — 1,825 objects copy in ~2–5 minutes with no client-side concurrency management.
  * Rollback after promotion: S3 Versioning on the production bucket means the pre-promotion objects are retained as prior versions. Within the 30-day rollback window, a single `ListObjectVersions` \+ `DeleteObject` (to remove the delete markers) restores the old state without keeping a separate `production-v0/` copy.

**Cost:** S3 Batch Operations: $0.25 per job + $1.00 per million objects
copied. For 1,825 objects: $0.25 + $0.002 = **$0.25 total for promotion**. The
cheapest step in the entire pipeline.

**IAM Deny policy for backfill cluster:**

    
    
    {
      "Effect": "Deny",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::output/production/*",
      "Principal": { "AWS": "arn:aws:iam::123456789:role/BackfillEMRProfile" }
    }
    

### Cost Estimate (AWS)

Component| Monthly / Total Cost| Notes  
---|---|---  
EMR Spot Fleet (150 × m5.xlarge)| ~$2,400–3,500| $0.06/hr Spot × 150 nodes ×
~10–14 active days; includes 15% interruption overhead  
EMR On-Demand driver (c5.xlarge)| ~$64| $0.19/hr × 336 hours — never Spot  
S3 staging storage (16TB × 14 days)| ~$85–120| $0.023/GB/month prorated;
includes output size growth from 3 new features  
S3 request costs (GET + PUT)| ~$5–10| 1,825 partitions × 12 GETs + 12 PUTs =
43,800 requests = negligible  
DynamoDB (checkpoints)| ~$2–5| On-demand; 1,825 items × 10 operations; well
under free tier for writes  
Step Functions Express| ~$1| $0.025/1,000 transitions × 18,250 transitions =
$0.46  
Lambda (SQS dispatch)| ~$1–3| 1,825 invocations × 3 retries avg × 200ms
duration × 256MB = ~$0.01  
S3 Batch Operations (promotion)| ~$1| $0.25/job + $1/million objects; 1,825
objects = $0.25 total  
Glue DQ (validation job)| ~$5–15| 4 DPUs × 30 min × $0.44/DPU-hr = $0.88; plus
Glue catalog reads  
**Total backfill cost**| **~$2,564–3,718**|  Full 14-day run; ~$1,100–1,400
with 10-day Spot-optimised run  
  
### Cost Optimization

Optimization| Service| Savings  
---|---|---  
S3 Select predicate pushdown| S3 reads| 40–80% less data scanned → shorter job
time → fewer Spot node-hours  
Pause backfill 21:00–07:00 UTC (live pipeline window)| EMR cluster| No wasted
Spot hours overnight; costs nothing since the cluster idles to 0 task nodes  
Column projection (read only needed columns in Spark)| Spark / Parquet|
Reduces per-job I/O from 1.5GB to ~200MB if transform uses 4 of 40 columns  
Zstd compression for output (vs Snappy)| S3 staging| 20–30% smaller output →
~$25 saved on staging storage over 14 days  
EMR Spot instead of EMR Serverless| Compute| 30–40% cheaper for a planned
14-day run with known concurrency vs per-vCPU-second billing

