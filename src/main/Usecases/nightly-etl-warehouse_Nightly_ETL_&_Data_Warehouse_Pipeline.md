# Nightly ETL & Data Warehouse Pipeline

Source: https://datapathsala.com/system-design/nightly-etl-warehouse

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Nightly ETL & Data Warehouse
PipelineAdd Note

# Nightly ETL & Data Warehouse Pipeline

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a nightly ETL pipeline for a retail company that ingests data from 8
source systems — ERP, CRM, point-of-sale, inventory management, logistics, web
analytics, returns processing, and supplier portal — into a central data
warehouse. The pipeline runs at 22:00 UTC and must complete before 06:00 UTC
when 300+ business analysts begin running reports and dashboards. The
warehouse currently holds 5 years of historical data (~12TB) and grows by
~50GB per day. Source schemas change without warning two to three times per
year. Design this end to end, with emphasis on incremental load strategies,
SCD Type 2 handling for slowly changing dimension data, dependency-ordered
orchestration across 8 sources, late-arriving data, data quality enforcement,
idempotent re-runs, and failure recovery.”

Expand AllCollapse All14 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Hard

A nightly ETL pipeline sounds like a solved problem — extract data, transform
it, load it. But interview candidates fail this question because they describe
a one-off script, not a production system that runs every night for years
without breaking. The real complexity lives in three areas that naive designs
completely miss.

**Hard problem 1: SCD Type 2 correctness under re-runs** Slowly Changing
Dimensions require versioned history rows. A customer who changes their email
address should have two rows in dim_customer: one closed (valid_to =
yesterday) and one current (valid_to = 9999-12-31). If your ETL re-runs for
the same business date — which it will, due to upstream failures, Airflow
retries, or engineer-triggered backfills — you must not create a third row.
The idempotent SCD merge is not obvious. Most candidates design a system that
produces duplicate history rows on re-run.

**Hard problem 2: DAG dependency hell across 8 sources** Facts depend on
dimensions. If the CRM dimension finishes loading before the ERP order facts
start, you get foreign key violations or orphaned fact records. With 8
independent sources that complete at unpredictable times, the DAG dependency
graph becomes critical. The wrong design runs everything sequentially (blows
the 8-hour window) or everything in parallel (produces bad data when a dim is
still loading when facts arrive). The right design: parallel extracts,
parallel DQ checks, all-dims-before-any-facts ordering, then parallel fact
loads.

**Hard problem 3: Schema drift without warning** Source teams add, rename, or
reorder columns without telling anyone. A naive pipeline crashes on the first
unexpected column. A production pipeline either enforces a schema contract
(reject the load, alert the source team) or applies schema evolution rules
(new nullable columns are accepted; non-nullable column additions are rejected
pending a warehouse migration). Most candidates do not address schema drift at
all.

## How to Structure Your Answer (45 min)

Phase| Time| Key Points  
---|---|---  
Scoping| 5 min| Ask about SCD requirements, backfill window, 8-hour SLA,
analyst workload pattern  
Architecture sketch| 8 min| Draw the 5-layer pipeline: sources → raw → DQ →
transform → warehouse → BI  
Incremental load deep-dive| 10 min| Watermark-based for transactional, CDC for
operational, full-snapshot diff for reference data  
SCD Type 2 merge| 8 min| Show the MERGE statement or Delta Lake merge —
idempotent re-run is the key point  
DAG dependency design| 7 min| Parallel extracts, all-dims-before-facts
ordering, runtime budget math  
Monitoring + schema drift| 7 min| DQ metrics, schema contract, alerting
runbook  
  
## Opening Move

> "Before I design anything, I want to flag three hard problems. First: SCD
> Type 2 merges must be idempotent — the same ETL run for the same date must
> produce the same result on re-run without creating duplicate history rows.
> Second: with 8 sources, DAG dependencies matter — facts must load after
> their dimensions, but if I serialise everything I won't finish in 8 hours.
> Third: source schema drift is inevitable — I need a schema contract that
> tells me whether to accept or reject unexpected columns instead of crashing
> silently. With that in mind, which of the 8 sources use CDC versus full
> daily snapshots?"

Clarifying Questions

## High-Level Architecture

CDC / full extract±5M rows/night~800M events/dayraw Parquet filesrow count,
nulls, schemavalidated datatransformed recordsSCD merge + upsertdims +
factsmetrics + aggregatestrigger extractstrigger transforms

ERP (SAP)

CRM (Salesforce)

POS System

Inventory Mgmt

Web Analytics

![Source Extractor \(Airbyte/Fivetran\)](/icons/tools/airflow.svg)Source
Extractor (Airbyte/Fivetran)

Raw Staging Layer (S3/GCS)

DQ Checks (Great Expectations)

![Transform Engine \(Spark/dbt\)](/icons/tools/spark.svg)Transform Engine
(Spark/dbt)

Staging Schema (DWH)

Core Schema (Dims + Facts)

Semantic Layer (dbt metrics)

BI Tools (Tableau/Looker)

![Airflow DAG Scheduler](/icons/tools/airflow.svg)Airflow DAG Scheduler

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation

Architecture Walkthrough

Component Deep Dive

Data Modeling

Incremental Load Strategies

Late-Arriving Data

Scaling the Pipeline

Monitoring & Alerting

Failure Recovery

Technology Comparison

Follow-Up Q&A

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS — Architecture

Fivetran / Glue jobscrawler registers schemaDQ validationpass gatetrigger
Spark jobParquet outputCOPY command / Spectrumreports + dashboards

8 Source Systems

![S3 Raw Zone](/icons/aws/s3.svg)S3 Raw Zone

Glue Data Catalog

MWAA (Airflow)

Glue DQ / Deequ

EMR Serverless (Spark)

![S3 Curated Zone](/icons/aws/s3.svg)S3 Curated Zone

Amazon Redshift

QuickSight / Tableau

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around S3 for raw and curated landing zones, MWAA for
> orchestration, EMR Serverless for Spark transformation jobs, Glue Data
> Catalog as the schema registry, Amazon Redshift RA3 as the warehouse, and
> AWS Glue DQ backed by Deequ for data quality enforcement before any
> transform runs."

### End-to-End Data Flow

    
    
    1.  Fivetran or custom Glue connector jobs extract from 8 sources nightly starting at 22:00 UTC,
        writing raw Parquet to s3://company-raw-zone/source=*/dt=YYYY-MM-DD/
    2.  Each source writes a _SUCCESS sentinel file and a _metadata.json
        ({"expected_rows": N, "schema_version": "vX", "checksum_sha256": "..."})
        when its export is complete
    3.  MWAA S3KeySensor polls for _SUCCESS per source every 60 seconds;
        max wait 2h before firing a PagerDuty P2 alert to the source team
    4.  Glue crawler runs on the raw prefix (triggered by MWAA), auto-registers
        schema in Glue Data Catalog with column names, types, and partition layout
    5.  Glue DQ / Deequ rules execute: row count within ±5% of 30-day rolling avg,
        PK columns 100% non-null, schema matches stored contract version
    6.  DQ pass → MWAA triggers EMR Serverless Spark job per source group
        (dims fan-out first; facts blocked until all dims succeed)
    7.  Spark applies SCD Type 2 Delta MERGE for dimension tables and watermark-based
        incremental MERGE for fact tables; output written as Delta Lake Parquet to
        s3://company-curated-zone/layer=core/table=*/dt=*/run_id=*/
    8.  MWAA triggers Redshift COPY from curated zone into staging schema;
        then runs MERGE from staging into core dims and facts
    9.  dbt Cloud runs semantic layer models (metrics, pre-aggregates, RLS views)
        on top of Redshift core schema
    10. Analysts access Redshift via QuickSight or Tableau by 06:00 UTC;
        QuickSight SPICE cache warms during the load window for zero-latency dashboards
    

### Why Each Component

### S3 (Raw + Curated Zones)

**Why separate raw and curated buckets rather than a single bucket with
prefixes?**

  * IAM bucket policies enforce write-only on raw (ETL service account can write, not delete), read-write on curated (transform jobs write, analysts read) — tighter blast radius if credentials are compromised
  * S3 Event Notifications on raw bucket trigger MWAA sensor without polling; curated bucket events can trigger downstream consumers independently
  * S3 strong consistency guarantee (since November 2020): any object written is immediately visible to all readers — no stale reads on Spark job startup, no eventual-consistency race conditions
  * Multipart upload handles files larger than 5 GB without timeout; Fivetran and Glue both use it automatically for large source tables
  * Lifecycle policies differ per zone: raw stays Standard for 30 days (active re-processing window), then moves to S3 Standard-IA (90 days), then Glacier Deep Archive (~$0.00099/GB/month) for 7-year compliance retention; curated zone stays Standard for 90 days, then IA, never archived (always re-derivable from raw)

**Trade-off: S3 vs EFS for staging** S3 object storage is the right choice
here. EFS (NFS) would give POSIX semantics and lower latency for small random
reads, but Spark jobs read Parquet in large sequential chunks — S3's
throughput is identical to EFS at that access pattern, and S3 costs ~$0.023/GB
vs EFS ~$0.30/GB. EFS is only justified if you have a legacy application that
requires POSIX file semantics (e.g., reading line by line with `seek()`).
Parquet on S3 with the S3A connector is the industry standard.

**Partition layout:**

    
    
    s3://company-raw-zone/
      source=erp/dt=2024-01-15/
        orders.parquet          ← raw Parquet, schema version v3
        _SUCCESS
        _metadata.json          → {"expected_rows": 1250000, "schema_version": "v3"}
      source=pos/dt=2024-01-15/
        transactions.parquet
        _SUCCESS
    
    s3://company-curated-zone/
      layer=core/table=dim_customer/dt=2024-01-15/run_id=r001/
        part-00000.parquet      ← Delta Lake checkpoint
        _delta_log/
    

### MWAA (Managed Airflow)

**Why MWAA over Step Functions and EventBridge Pipes?**

  * S3KeySensor is a first-class Airflow operator: waits for `_SUCCESS` files with configurable poke interval (60s), timeout, and retries — no Lambda shims required
  * Backfill is built in: `airflow dags backfill --start-date 2024-01-01 --end-date 2024-01-14 nightly_etl` re-runs 14 dates in parallel with independent run IDs and idempotent output paths
  * DAG-level task dependency graph enforces dims-before-facts ordering at compile time — not at runtime, so you catch missing dependencies before the pipeline ever runs
  * Native `EmrServerlessStartJobRunOperator` submits EMR jobs and polls for completion without any custom code
  * Rich retry configuration: exponential backoff, per-task timeouts, separate on-failure callbacks for PagerDuty vs Slack

**Config:** mw1.small (2 schedulers, 5 Celery workers) costs ~~$300–500/month
and is sufficient for a nightly pipeline with 40 tasks at peak. Use mw1.micro
(~~ $200/month) if the pipeline runs only once per day.

**Cold start caveat:** MWAA scheduler takes ~3–5 minutes to warm up after a
period of inactivity. For a strictly nightly pipeline this is irrelevant, but
if you plan to add hourly CDC micro-batches later, consider keeping a keep-
alive DAG or switching to self-managed Airflow on EKS.

**Trade-off: MWAA vs self-managed Airflow on EKS** MWAA eliminates scheduler
HA management, executor scaling, and Airflow upgrade toil — worth the
$300–500/month if your team has fewer than 3 data engineers. Self-managed
Airflow on EKS with Kubernetes executor reduces cost to ~$80–150/month (spot
node groups) and gives full control over plugins, Spark operator versions, and
resource isolation between DAGs. Choose self-managed when you have the DevOps
maturity to maintain it and cost optimisation is a priority.

    
    
    # MWAA DAG: fan-out extracts → DQ gates → ordered transforms
    from airflow import DAG
    from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
    from airflow.providers.amazon.aws.operators.emr import EmrServerlessStartJobRunOperator
    from airflow.utils.trigger_rule import TriggerRule
    from datetime import datetime, timedelta
    
    SOURCES = ['erp', 'crm', 'pos', 'inventory', 'logistics', 'web', 'returns', 'supplier']
    DIMS    = ['dim_customer', 'dim_product', 'dim_store']
    FACTS   = ['fact_orders', 'fact_inventory', 'fact_web_sessions', 'fact_logistics', 'fact_returns']
    
    with DAG('nightly_etl',
             schedule_interval='0 22 * * *',
             start_date=datetime(2024, 1, 1),
             default_args={'retries': 2, 'retry_delay': timedelta(minutes=5)}) as dag:
    
        sensors    = [S3KeySensor(task_id=f'wait_{s}',
                                  bucket_key=f's3://raw-zone/source={s}/dt={{{{ ds }}}}/_SUCCESS',
                                  timeout=7200, poke_interval=60) for s in SOURCES]
        dq_tasks   = [EmrServerlessStartJobRunOperator(task_id=f'dq_{s}', ...) for s in SOURCES]
        dim_tasks  = [EmrServerlessStartJobRunOperator(task_id=f'transform_{d}', ...) for d in DIMS]
        fact_tasks = [EmrServerlessStartJobRunOperator(task_id=f'transform_{f}',
                                                       trigger_rule=TriggerRule.ALL_SUCCESS,
                                                       ...) for f in FACTS]
        load_task  = EmrServerlessStartJobRunOperator(task_id='load_redshift', ...)
    
        for sensor, dq in zip(sensors, dq_tasks):
            sensor >> dq
        for dq in dq_tasks:
            dq >> dim_tasks  # all DQ gates must pass before any dim transform starts
        for dim in dim_tasks:
            dim >> fact_tasks  # all dims must complete before any fact transform starts
        for fact in fact_tasks:
            fact >> load_task
    

### EMR Serverless (Spark Transforms)

**Why EMR Serverless over AWS Glue for this workload?**

  * Pre-initialized worker pools on EMR Serverless eliminate the 3–5 minute cold start that Glue jobs incur — for a pipeline with 8 source jobs that fan out in parallel, saving 5 minutes per job saves 40 minutes total
  * EMR Serverless supports Delta Lake 2.x natively; Glue requires a custom JAR and connector configuration that breaks on minor Glue version upgrades
  * Full Spark configuration control: set `spark.sql.shuffle.partitions`, `spark.executor.memoryOverhead`, and Delta Lake properties per job; Glue exposes only a subset of Spark config knobs
  * Spot instance support for executors: EMR Serverless application configured with `initialCapacity` on-demand for drivers and Spot for executors, yielding 60–70% cost reduction on compute

**SCD Type 2 Delta MERGE (run per dimension table):**

    
    
    from delta.tables import DeltaTable
    from pyspark.sql import functions as F
    
    def apply_scd2(spark, source_df, delta_path, natural_key, tracked_cols):
        delta_tbl = DeltaTable.forPath(spark, delta_path)
    
        (delta_tbl.alias("t")
            .merge(
                source_df.alias("s"),
                f"t.{natural_key} = s.{natural_key} AND t.is_current = true"
            )
            # Close changed rows
            .whenMatchedUpdate(
                condition=" OR ".join([f"t.{c} != s.{c}" for c in tracked_cols]),
                set={"is_current": "false",
                     "valid_to": F.date_sub(F.current_date(), 1).cast("string")}
            )
            # Insert new versions for changed rows AND brand-new natural keys
            .whenNotMatchedInsert(values={
                natural_key:   f"s.{natural_key}",
                **{c: f"s.{c}" for c in tracked_cols},
                "is_current":  "true",
                "valid_from":  "current_date()",
                "valid_to":    "date('9999-12-31')"
            })
            .execute())
        # Second pass: insert new-version rows for rows that were just closed
        # (whenMatchedUpdate closes old row; a separate INSERT adds the new version)
        spark.sql(f"""
            INSERT INTO delta.`{delta_path}`
            SELECT s.*, true AS is_current, current_date() AS valid_from, date('9999-12-31') AS valid_to
            FROM source_staging s
            JOIN delta.`{delta_path}` t
              ON t.{natural_key} = s.{natural_key} AND t.valid_to = date_sub(current_date(), 1)
        """)
    

**Watermark-based incremental fact load:**

    
    
    def load_incremental_facts(spark, source_table, watermark_col, control_conn):
        last_wm = read_watermark(control_conn, source_table)  # e.g. 2024-01-14T22:00:00Z
        new_recs = (spark.read.jdbc(url=JDBC_URL, table=source_table)
                        .filter(F.col(watermark_col) > last_wm))
        deduped  = (new_recs
                    .withColumn("rn", F.row_number().over(
                        Window.partitionBy("order_id").orderBy(F.col(watermark_col).desc())))
                    .filter("rn = 1").drop("rn"))
        deduped.write.format("delta").mode("append").option("mergeSchema", "false").save(CURATED_PATH)
        # Update watermark only after successful write
        new_max = new_recs.agg(F.max(watermark_col)).collect()[0][0]
        update_watermark(control_conn, source_table, new_max)
    

**Cost math:**

    
    
    50GB Spark job (8 source groups, each ~6GB):
      20 vCPUs × (30 min / 60) hr × $0.052/vCPU-hr (on-demand) = $0.52/run
      With Spot executors (70% discount on 18 vCPUs, 2 on-demand driver vCPUs):
        2 vCPUs × $0.052 + 18 vCPUs × $0.016 = $0.39/run
      30 nights/month × $0.39 = ~$12/month per source group
      8 groups × $12 = ~$96/month total Spark compute
    

### Glue Data Catalog

**Why use Glue Data Catalog as the schema registry rather than a custom
metadata store?**

  * Crawler auto-discovers schemas from S3 Parquet files and registers them automatically — no manual `CREATE TABLE` DDL required after a source team delivers a new table format
  * Schema versioning: each time the crawler detects a column addition or type change, it creates a new schema version in the catalog, providing a complete audit trail of source schema evolution
  * Partition projection eliminates `MSCK REPAIR TABLE` commands: configure the catalog table with `projection.enabled = true` and `projection.dt.type = date` so new date partitions are visible to Athena and EMR Spark immediately without running a metadata repair job
  * Integrated with Athena for ad-hoc raw zone queries (analysts can inspect raw data without Spark) and with EMR Serverless (Spark reads table metadata from the catalog for schema inference)

**Crawler config for raw zone:**

    
    
    Crawler name: raw-zone-nightly-crawler
    Data store:   s3://company-raw-zone/
    Schedule:     On demand (triggered by MWAA after each source lands)
    Exclusions:   */_SUCCESS, */_metadata.json
    Output:       Database: raw_catalog, Table prefix: src_
    Schema change handling:
      - Add new columns: LOG + UPDATE schema
      - Remove columns: LOG + IGNORE (never drop from catalog)
      - Change column type: LOG + FREEZE (do not auto-update; trigger alert)
    

**Trade-off: Glue Catalog crawler vs manual table registration** Crawler auto-
discovery is convenient but can cause schema surprises if a source drops and
re-adds a column (the catalog sees a type change and freezes). For production
pipelines, register schemas manually via the Glue SDK after validating against
the schema contract — use the crawler only in development. This gives
deterministic catalog state at the cost of manual upkeep.

### Amazon Redshift (RA3)

**Why RA3 over DC2 for this workload?**

  * RA3 separates compute from storage: data lives in Redshift Managed Storage (RMS), backed by S3, so you can resize the compute cluster (add/remove nodes) without re-distributing data — critical for a 300-analyst workload where peak query load is unpredictable
  * Redshift Spectrum lets the ETL COPY pipeline query S3 curated zone directly as an external table during the load window, eliminating an intermediate staging step for large tables
  * DC2 nodes store data locally (SSD); at 12TB warehouse size you would need dc2.8xlarge nodes at ~$4.80/hr each — significantly more expensive than ra3.xlplus at ~$1.086/hr with unlimited managed storage

**DISTKEY + SORTKEY design for 300 analysts:**

    
    
    -- fact_orders: most joins are fact → dim_customer (for customer analytics)
    CREATE TABLE core.fact_orders (
        order_natural_key  VARCHAR(64) NOT NULL,
        customer_key       BIGINT NOT NULL,
        product_key        BIGINT NOT NULL,
        store_key          BIGINT NOT NULL,
        date_key           INT NOT NULL,
        order_amount       NUMERIC(18,4) NOT NULL,
        quantity           INT NOT NULL,
        etl_run_id         VARCHAR(64) NOT NULL
    )
    DISTKEY(customer_key)    -- co-locates with dim_customer on same node slice
    SORTKEY(date_key)        -- analysts filter by date range; sort key eliminates 95% of blocks
    ENCODE AUTO;             -- Redshift chooses optimal column compression per data distribution
    
    -- dim_customer: replicate small dims to all nodes to avoid redistribution
    CREATE TABLE core.dim_customer (
        customer_key         BIGINT NOT NULL,
        customer_natural_key VARCHAR(64) NOT NULL,
        email                VARCHAR(256),
        segment              VARCHAR(64),
        valid_from           DATE NOT NULL,
        valid_to             DATE NOT NULL,
        is_current           BOOLEAN NOT NULL
    )
    DISTSTYLE ALL;           -- small dim table replicated on every node slice
    

**WLM queue config (ETL vs analyst isolation):**

    
    
    {
      "wlm_json_configuration": [
        {
          "user_group": ["etl_service_account"],
          "query_concurrency": 5,
          "memory_percent_to_use": 60,
          "timeout": 0
        },
        {
          "user_group": ["analyst_*", "tableau_svc"],
          "query_concurrency": 20,
          "memory_percent_to_use": 35,
          "max_execution_time": 300000
        },
        {
          "query_group": ["adhoc"],
          "query_concurrency": 3,
          "memory_percent_to_use": 5,
          "max_execution_time": 120000
        }
      ]
    }
    

**COPY command from curated zone:**

    
    
    -- Load from Delta-format Parquet in curated zone (latest run_id partition)
    COPY staging.dim_customer_load
    FROM 's3://company-curated-zone/layer=core/table=dim_customer/dt=2024-01-15/run_id=r001/'
    IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftS3ReadRole'
    FORMAT AS PARQUET
    SERIALIZETOJSON;  -- preserves nested struct columns as JSON strings if any exist
    

**Trade-off: Redshift vs Snowflake vs BigQuery for this workload** Redshift
RA3 is the best choice when you are already on AWS and need tight integration
with S3, MWAA, and IAM. Snowflake offers superior multi-cluster auto-scaling
and a simpler pricing model but adds a third-party vendor dependency and is
20–40% more expensive at this query volume. BigQuery is the best choice on GCP
due to its serverless model; on AWS it would require cross-cloud data transfer
costs. For a retail company on AWS with 300 analysts doing mostly date-range
queries on columnar data, Redshift RA3 with proper DISTKEY/SORTKEY design is
the most cost-effective option.

### AWS Glue DQ / Deequ

**Why enforce DQ before transforms rather than after?**

  * A DQ failure discovered after the Spark transform wasted compute and wrote bad data to the curated zone; catching it before transform means zero wasted resources and no curated zone pollution
  * Source teams should own their data quality — blocking the pipeline on their bad data (and alerting them immediately) creates accountability that post-load DQ checks do not
  * Schema drift detection at this stage (column renamed or type changed) prevents silent type coercions that corrupt 5 years of historical data in the warehouse

**Deequ check suite (runs via MWAA → Glue DQ activity):**

    
    
    from pydeequ.checks import Check, CheckLevel
    from pydeequ.verification import VerificationSuite
    from pydeequ.analyzers import AnalysisRunner, Size, Completeness, Uniqueness
    
    # --- Structural checks (run first, fast) ---
    check = (Check(spark, CheckLevel.Error, "orders_dq")
        .hasSize(lambda s: s >= 1_000_000,
                 hint="ERP orders: expected >= 1M rows; got fewer — possible extract failure")
        .hasSize(lambda s: s <= 5_000_000,
                 hint="ERP orders: expected <= 5M rows; got more — possible duplicate extract")
        .isComplete("order_id")         # 100% non-null PK
        .isUnique("order_id")           # no duplicate PKs
        .isNonNegative("order_amount")  # no negative amounts
        .isContainedIn("status", ["pending", "confirmed", "shipped", "cancelled", "returned"])
        .hasDataType("order_date", ConstrainableDataTypes.Date)
        .satisfies("order_amount < 1000000", "order_amount sanity check"))  # no billion-dollar orders
    
    result = VerificationSuite(spark).onData(df).addCheck(check).run()
    if result.status != "Success":
        failed = [r for r in result.checkResults if r.status != "Success"]
        # Alert source team via SNS
        sns.publish(TopicArn=SOURCE_ALERT_TOPIC,
                    Message=f"DQ FAILED for erp.orders on {business_date}:\n" +
                            "\n".join([f"  - {r.check.description}: {r.status}" for r in failed]))
        raise AirflowException(f"DQ gate failed — pipeline halted. {len(failed)} checks failed.")
    

**Schema drift detection (runs before Deequ, cheaper):**

    
    
    actual_cols  = {f.name: str(f.dataType) for f in df.schema.fields}
    contract_ver = glue_catalog.get_table_version(database="raw_catalog", table="src_erp_orders",
                                                   version_id="LATEST")
    expected_cols = {c["Name"]: c["Type"] for c in contract_ver["Table"]["StorageDescriptor"]["Columns"]}
    
    new_cols     = set(actual_cols) - set(expected_cols)
    missing_cols = set(expected_cols) - set(actual_cols)
    type_changes = {c: (expected_cols[c], actual_cols[c]) for c in actual_cols
                    if c in expected_cols and actual_cols[c] != expected_cols[c]}
    
    if missing_cols or type_changes:
        raise AirflowException(f"BREAKING schema drift: missing={missing_cols}, type_changes={type_changes}")
    if new_cols:
        logging.warning(f"New nullable columns detected: {new_cols} — auto-updating contract")
        update_glue_schema_contract(new_cols, actual_cols)
    

**What happens on DQ failure:** The MWAA task fails with a descriptive error,
SNS sends an alert to the source team's Slack channel and the data engineering
on-call PagerDuty schedule, the downstream transform and warehouse load tasks
are not triggered (Airflow dependency graph), and the raw files remain in S3
for re-processing once the source team fixes their export. No bad data ever
reaches the warehouse.

### Cost Estimate (AWS)

Service| Monthly Cost| Notes  
---|---|---  
S3 (raw + curated zones)| $40–80| ~1.5TB/month new data; lifecycle IA after
90d, Glacier after 1y  
MWAA (mw1.small)| $300–500| Fixed orchestration cost; mw1.micro saves
~$100/month  
EMR Serverless (Spark)| $80–120| ~$0.39/run × 8 source groups × 30 nights;
Spot executors  
Glue Data Catalog + Crawlers| $10–20| Per-crawl pricing + catalog storage  
Glue DQ / Deequ| $15–30| DQ checks run as Glue jobs; ~$0.44/DPU-hr × 10 min  
Redshift RA3 (ra3.xlplus × 2)| $700–900| 2 nodes for 300 analysts; RA3
separates compute/storage  
Fivetran / Glue connectors| $200–400| Depends on rows synced across 8 sources  
QuickSight (SPICE)| $24/user/month| For BI dashboards; SPICE eliminates live
Redshift query load  
**Total**| **~$1,370–2,050/month**|  300 analysts, 8 sources, 50GB/day growth  
  
### Cost Optimization

Optimization| Service| Savings  
---|---|---  
Spot instances for EMR Serverless executors (keep driver on-demand)| EMR
Serverless| 60–70% on Spark compute → ~$50–70/month savings  
S3 Intelligent-Tiering for raw zone (auto-moves infrequently accessed files to
IA)| S3| 40–50% on raw zone storage; no retrieval fee for IA tier  
Redshift Concurrency Scaling instead of third RA3 node| Redshift| Concurrency
scaling credits cover ~1h/day free; avoid $350/month node  
Replace Fivetran with Airbyte self-hosted on ECS for high-volume sources|
Ingestion| $1,500–3,000/month savings on Fivetran MAR pricing at scale  
MWAA → mw1.micro for pipelines with ≤ 10 concurrent tasks| MWAA|
~$100–150/month savings

