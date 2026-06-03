# Financial Month-End Close Pipeline

Source: https://datapathsala.com/system-design/month-end-close-pipeline

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Financial Month-End Close PipelineAdd
Note

# Financial Month-End Close Pipeline

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a month-end financial close and reporting pipeline for a multinational
corporation with operations in 47 countries. The company's primary ERP is SAP,
but 12 subsidiaries use local GL systems that export data via nightly file
drops. At the end of each month, finance teams in all 47 countries submit and
approve journal entries, intercompany transactions between subsidiaries must
be detected and eliminated before consolidation, all local currency amounts
must be converted to USD at the correct FX rate (different rates for P&L vs
Balance Sheet per ASC 830 / IAS 21), and consolidated financial statements
(P&L, Balance Sheet, Cash Flow) must be produced in compliance with US GAAP.
The entire close must complete within 5 business days of month-end. The CFO
needs a live dashboard showing close progress across all entities. Auditors
need to be able to trace any line item back to the originating journal entry.
Design this data pipeline end to end.”

Expand AllCollapse All16 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Unique

Month-end close is one of the most domain-specific data engineering design
questions. Candidates without finance domain knowledge treat it as "just
another ETL pipeline" and produce a generic answer. The interviewers are
evaluating whether you understand the business process constraints —
specifically, the three financial engineering hard problems that have no
analogue in typical data pipelines.

**Hard problem 1: Intercompany elimination at scale** When Entity A (US
subsidiary) sells services to Entity B (UK subsidiary), Entity A records
revenue and Entity B records an expense. For the consolidated group, this
transaction should not exist — it is internal. Before producing group-level
financial statements, you must find every intercompany pair across 47 entities
and generate elimination journals that cancel them out. The hard part:
elimination pairs must balance perfectly. If Entity A recorded $1.2M revenue
and Entity B recorded $1.18M expense, there is a $20K intercompany mismatch
that must be investigated and resolved before close can complete. At scale,
with hundreds of thousands of IC transactions, detecting and flagging these
mismatches is non-trivial.

**Hard problem 2: FX rate selection is not obvious** ASC 830 (US GAAP) and IAS
21 (IFRS) have specific rules about which exchange rate to use for which
financial statement line item. Balance Sheet accounts (cash, receivables,
payables) use the **closing rate** — the spot rate on the last day of the
period. P&L accounts (revenue, expenses) use the **average rate** — the
average daily rate over the period. Equity accounts use the **historical
rate** — the rate when the equity was originally recorded. Getting these wrong
produces materially incorrect financials. A naive "convert everything at
today's rate" design will be immediately challenged.

**Hard problem 3: Soft close vs hard close and period locking** Finance teams
don't close all 47 entities simultaneously. The process is:

  * Day 0: operational period ends (October 31)
  * Day 1-2: entities submit journals — the period is "open" for adjustments
  * Day 2-3: soft close — preliminary financials available for management review
  * Day 4-5: hard close — final adjusting journals posted, period locked After hard close, no more journal entries are allowed for that period. Your pipeline must enforce this: if an entity tries to post an adjusting entry on Day 6, the system should reject it with a period-locked error.

## How to Structure Your Answer (45 min)

Phase| Time| Key Points  
---|---|---  
Scoping| 5 min| Ask about GAAP standard, ERP systems, IC transaction volume,
close timeline, regulatory requirements  
Architecture| 8 min| 5-phase close pipeline: extract → IC elimination → FX
conversion → consolidation → reporting  
Intercompany elimination deep dive| 10 min| Detection algorithm, mismatch
handling, bilateral vs multilateral IC  
FX conversion rules| 8 min| Closing rate vs average rate vs historical rate,
rate sourcing, rate table design  
Audit trail + period lock| 7 min| Append-only GL, SOX Section 404, period lock
enforcement  
Monitoring + close progress| 7 min| CFO dashboard design, entity-by-entity
status, SLA risk detection  
  
## Opening Move

> "Before I design anything, I want to flag three hard problems specific to
> financial close. First: intercompany elimination — with 47 entities, I need
> to find every IC pair and generate offsetting eliminations. When IC pairs
> don't balance — which happens frequently — that's a mismatch that blocks the
> close and must be resolved before consolidation can run. Second: FX rate
> selection is not 'one rate fits all' — Balance Sheet accounts use the
> closing spot rate, P&L accounts use the period average rate, and equity uses
> the historical transaction-date rate. A single FX table won't work; I need a
> rate selection engine. Third: period locking — after hard close, no GL
> entries can be posted to the period, but auditors sometimes need retroactive
> adjustments — the design needs to support a formal re-opening process with
> approval gate. With that in mind, which GAAP standard applies here — US GAAP
> (ASC 830) or IFRS (IAS 21)?"

Clarifying Questions

## High-Level Architecture

SAP BAPI extractfile drop / APIclosing + avg ratesenforce period closedjournal
lines (50M/month)every GL event loggedraw trial balanceseliminated trial
balanceUSD-converted balancesP&L, Balance Sheet, Cash Flowall eliminations
loggedversioned snapshot per closelive financialsregulatory filings

SAP ERP (35 entities)

Local GL Systems (12 entities)

FX Rate Feed (Bloomberg/ECB)

![GL Data Extractor \(Airflow\)](/icons/tools/airflow.svg)GL Data Extractor
(Airflow)

Period Lock Controller

Trial Balance Staging

![Intercompany Elimination Engine](/icons/tools/spark.svg)Intercompany
Elimination Engine

FX Conversion Engine

![Consolidation Engine \(Spark\)](/icons/tools/spark.svg)Consolidation Engine
(Spark)

Immutable Audit Log

Financial Statement Store

Versioned Snapshot Store

CFO Dashboard

Regulatory Reports

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation

Architecture: The 5-Phase Close Pipeline

Component Deep Dive

Data Modeling

FX Conversion: The Rules Matter

Audit Trail & SOX Compliance

Soft Close vs Hard Close

Regulatory Reporting

Scaling the Close Pipeline

Monitoring & CFO Dashboard

Failure Modes

Technology Comparison

Follow-Up Q&A

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS — Architecture

GL extracts + journal linesS3 sensor triggertrigger IC eliminationvalidated
trial balancestrigger consolidationeliminated + FX-convertedfinancial
statementsall events to audit logCFO dashboard

ERP / GL Sources (47 entities)

![S3 Raw Zone \(GL exports\)](/icons/aws/s3.svg)S3 Raw Zone (GL exports)

MWAA (Airflow)

Glue / EMR Spark

![S3 Curated \(Trial Balances\)](/icons/aws/s3.svg)S3 Curated (Trial Balances)

EMR Spark (Consolidation)

Redshift (Financial Statements)

![S3 + Athena \(Audit Log\)](/icons/aws/s3.svg)S3 + Athena (Audit Log)

QuickSight (CFO Dashboard)

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS I'd build around S3 for raw GL exports and the immutable audit log,
> MWAA for orchestration, Glue for intercompany elimination and EMR Spark for
> FX conversion and consolidation, Redshift for the financial statement store,
> S3 + Athena for the SOX audit log, and QuickSight for the CFO dashboard. The
> key design principle: every journal line that enters S3 is append-only and
> encrypted with SSE-KMS; after hard close the period partition is locked with
> Object Lock WORM so not even a root account can delete it."

### End-to-End Data Flow

    
    
    1. SAP BAPI extractor and local GL file-drop DAGs run in parallel for all 47 entities;
       each entity writes: s3://finance-raw/entity={code}/period={YYYY-MM}/journal_lines.parquet
       and a _SUCCESS sentinel when complete; SSE-KMS encrypts every object at write time
    
    2. MWAA S3KeySensor watches for all 47 _SUCCESS files; per-entity configurable SLA timeout
       (e.g., JP entity gets +2h due to timezone); late entities trigger a Level-1 Slack alert
    
    3. Glue Data Quality validates each entity: debits == credits (tolerance <$0.01);
       any imbalanced entity is quarantined and the finance controller is paged before IC step starts
    
    4. MWAA triggers the Glue ETL job for Intercompany Elimination:
       full-outer join across 47 entity trial balances on entity_code x trading_partner;
       matched IC pairs generate elimination journals; mismatches written to S3 mismatch report
       and routed to the responsible finance controller via SNS
    
    5. After IC elimination, MWAA triggers EMR Spark for FX Conversion:
       applies closing rate (Balance Sheet accounts) or average rate (P&L accounts) per ASC 830;
       FX translation adjustment (CTA) computed per entity and written to the curated zone
    
    6. EMR Spark Consolidation job sums all 47 USD-converted eliminated trial balances;
       applies the elimination journals; produces consolidated trial balance in S3 curated zone
    
    7. Redshift COPY loads the consolidated trial balance; stored procedures generate P&L,
       Balance Sheet, and Cash Flow statements; snapshot table financial_snapshot_{YYYYMM}
       written as an immutable record — no UPDATE or DELETE ever issued against snapshot tables
    
    8. Every journal line, IC elimination, FX conversion event, and consolidation adjustment
       is streamed to s3://finance-audit-log/ partitioned by period and event_type;
       Athena partition projection enables instant SOX audit queries without MSCK REPAIR TABLE
    
    9. After hard close, MWAA Lambda applies S3 Object Lock (Compliance mode, 2557-day retention)
       to the completed period's partition — prevents modification even by the AWS root account
    
    10. QuickSight SPICE refresh is triggered by MWAA after each consolidation run;
        RLS ensures each country finance director sees only their entity; CFO sees all 47;
        close progress dashboard shows entity submission status, IC mismatch count, days to SLA
    

### Why Each Component

### Raw GL Store + Audit Log: S3

**Why S3 for financial data?**

  * SOX Section 404 requires an immutable audit trail: S3 Object Lock in Compliance mode means not even the AWS root account can delete or overwrite an object before the retention period expires — satisfying the 7-year SOX retention requirement at the storage layer, not just the application layer
  * SSE-KMS encryption is mandatory for financial data: KMS generates a per-object data key, and the KMS audit trail in CloudTrail logs every decrypt operation with the IAM principal, timestamp, and object ARN — giving auditors a complete record of "who decrypted which financial record and when"
  * S3 Versioning on the raw GL zone handles SAP re-exports: if SAP pushes a corrected GL file for entity US001 after the initial extract, both the original and the correction are retained with distinct version IDs — the pipeline processes the latest version but auditors can inspect the original
  * S3 Event Notifications trigger MWAA the moment the 47th `_SUCCESS` file lands — no polling latency
  * Partition layout `s3://finance-raw/entity={code}/period={YYYY-MM}/journal_lines.parquet` enables Athena partition pruning: a SOX audit query for a single entity and period scans only that one partition

**Audit log partition layout:**

    
    
    s3://finance-audit-log/
      year=2024/month=01/event_type=journal_posting/   -- ~3GB Parquet per month
      year=2024/month=01/event_type=ic_elimination/
      year=2024/month=01/event_type=fx_conversion/
      year=2024/month=01/event_type=period_lock/
    

**Trade-off:** S3 is not queryable without Athena — there is no built-in SQL
interface. Athena cold start (2–5 seconds) is acceptable for compliance
investigations. If auditors need sub-second lookup by document number, add a
DynamoDB index on `document_number` pointing to the S3 object key. For the
7-year archive, Athena's $5/TB pricing is 95% cheaper than keeping audit data
in Redshift.

**Pricing:** S3 Standard at $0.023/GB for the first 30 days; Intelligent-
Tiering after 30 days auto-transitions between frequent ($0.023/GB) and
infrequent ($0.0125/GB) tiers based on actual access patterns. Glacier Deep
Archive at $0.00099/GB for objects older than 13 months. For 100GB/month new
data with 7-year retention: ~$50/month total storage cost.

### Orchestration: MWAA (Managed Airflow)

**Why MWAA over Step Functions for the close pipeline?**

  * The close pipeline has conditional dependency logic that is awkward in Step Functions: wait for 47 entities each with a different upload SLA, validate each entity's trial balance before IC elimination starts, branch to a retry path if IC mismatches exceed threshold, backfill for restatements across multiple months
  * `S3KeySensor` and `ExternalTaskSensor` are first-class Airflow operators — the FX rate DAG and GL extraction DAG are separate; `ExternalTaskSensor` blocks the consolidation DAG until the FX rate DAG's `load_rates` task completes successfully
  * DAG parameterisation for the period: `dag_run.conf['period'] = '2024-01'` makes the same DAG reusable for every month; backfill for a restatement spanning 3 months is a single command: `airflow dags backfill --reset-dagruns -s 2024-01 -e 2024-03`
  * Rich retry configuration: exponential backoff per task; extraction tasks get 3 retries, consolidation tasks get 1 retry — consolidation failures need human investigation, not auto-retry

**Config:** mw1.medium (2 schedulers, 10 workers) — finance teams trigger
manual re-runs during the close window and need a responsive scheduler. Cost:
~$400–600/month.

**Trade-off:** MWAA vs Prefect for financial workflows. Prefect has a cleaner
Python-native API and better dynamic task mapping (useful for the 47-entity
fan-out pattern where each entity is an independent task). MWAA is the right
choice if the team already operates Airflow elsewhere. Prefect Cloud is worth
evaluating if you are greenfield — its `work_pool` model handles the 47-entity
fan-out more elegantly than Airflow's `DynamicTaskMapping`.

    
    
    # MWAA DAG: wait for all 47 entities with per-entity configurable SLA timeout
    with DAG('month_end_close', schedule_interval=None, params={'period': '2024-01'}) as dag:
        sensors = [
            S3KeySensor(
                task_id=f'wait_{entity}',
                bucket_key=f's3://finance-raw/entity={entity}/period={{{{ params.period }}}}/_SUCCESS',
                timeout=ENTITY_SLA_HOURS[entity] * 3600,  # per-entity SLA from config map
                poke_interval=300,
            )
            for entity in ENTITY_CODES  # list of 47 entity codes
        ]
        validate  = GlueJobOperator(task_id='validate_trial_balances', ...)
        ic_elim   = GlueJobOperator(task_id='ic_elimination', ...)
        consolidate = EmrAddStepsOperator(task_id='consolidation', ...)
        sensors >> validate >> ic_elim >> consolidate
    

### IC Elimination + FX Conversion: AWS Glue + EMR Spark

**Why two separate jobs — Glue for IC elimination and EMR for consolidation?**

  * IC elimination must complete before FX conversion: FX rates are applied to post-elimination balances (intercompany pairs are eliminated in local currency, then the net balance is converted to USD). Running them as a single job introduces sequencing complexity inside one Spark application
  * Glue for IC elimination: the IC detection algorithm is a SQL-style full-outer join across 47 entity trial balances — Glue's native Spark SQL and Glue Catalog integration make this straightforward without custom JARs. The IC logic is fully expressible as DynamicFrame joins
  * EMR for consolidation: the consolidation job needs a custom FX rate UDF (account-type-aware rate selection — closing vs average vs historical per ASC 830) and financial statement generation logic cleanest as a PySpark job with custom Python modules. EMR allows packaging code as a `.zip` distributed to all executors; Glue's `--extra-py-files` flag is more constrained

**Glue IC pair detection:**

    
    
    from awsglue.context import GlueContext
    from pyspark.sql import functions as F
    
    def run_ic_elimination(glue_ctx: GlueContext, period: str):
        tb = glue_ctx.create_dynamic_frame.from_catalog(
            database='finance', table_name='trial_balances'
        ).toDF().filter(F.col('period') == period)
    
        # Self-join on entity_code <-> trading_partner to find IC pairs
        ic = tb.filter(F.col('trading_partner').isNotNull())
        ic_b = ic.toDF(*[f'{c}_b' for c in ic.columns])
        matched = ic.join(ic_b,
            (ic.entity_code == ic_b.trading_partner_b) &
            (ic.trading_partner == ic_b.entity_code_b) &
            (ic.currency == ic_b.currency_b),
            'full_outer'
        ).withColumn('amount_diff', F.abs(F.col('amount_local') + F.col('amount_local_b')))
    
        mismatches   = matched.filter(F.col('amount_diff') > 0.01)
        matched_clean = matched.filter(F.col('amount_diff') <= 0.01)
        return matched_clean, mismatches
    

**Trade-off:** Glue DPU-based pricing ($0.44/DPU-hour) vs EMR Spot (~$0.06/hr
per m5.xlarge). For IC elimination (20 DPUs, ~25 min): Glue = ~$3.60/run; same
job on EMR Spot = ~$0.25/run. Glue is 10x more expensive per run but requires
zero cluster management — acceptable for once-a-month. Migrate to EMR
Serverless if the IC job runs >3 times per month due to restatements.

**EMR config for consolidation:** `m5.xlarge` driver (on-demand — prevents
mid-close interruption) + `m5.4xlarge` x 8 Spot workers. At 2AM on the 1st of
the month Spot availability is high and interruption probability is low. Cost:
~$12/close run for a 3-hour consolidation job.

### Financial Statement Store: Redshift

**Why Redshift over RDS for financial statements?**

  * Financial statement generation is analytical SQL: account hierarchy rollups (chart of accounts tree), multi-period comparisons (current vs prior year), segment breakdowns by geography and business unit. These aggregations scan the full trial balance — 50M journal lines. Redshift columnar storage is 10–50x faster than row-oriented RDS for these workloads
  * `DISTKEY` on `entity_code` co-locates all of a single entity's journal lines on the same compute node — entity-level statutory reports complete without cross-node data shuffles
  * `SORTKEY` on `period` means time-series scans skip irrelevant storage blocks entirely; Redshift uses the sort-key min/max zone maps to skip full 1MB blocks
  * Snapshot tables: `financial_snapshot_202401` — one immutable table per hard close, never overwritten. Analysts and auditors query a specific close by name; no `WHERE snapshot_version = ?` juggling

**P &L generation stored procedure:**

    
    
    CREATE OR REPLACE PROCEDURE sp_generate_pl(p_period CHAR(7))
    AS $$
    BEGIN
      EXECUTE 'INSERT INTO financial_statements.p_and_l_' || REPLACE(p_period, '-', '')
           || ' SELECT h.section, h.subsection, h.reporting_line,'
           || ' SUM(CASE WHEN tb.debit_credit = ''D'' THEN tb.amount_usd ELSE -tb.amount_usd END) AS amount_usd,'
           || ' tb.close_date'
           || ' FROM consolidated_trial_balance tb'
           || ' JOIN account_hierarchy h ON h.account_code = tb.account_code'
           || ' WHERE tb.period = ''' || p_period || ''' AND tb.statement_type = ''PL'' AND tb.is_final = TRUE'
           || ' GROUP BY h.section, h.subsection, h.reporting_line, tb.close_date'
           || ' ORDER BY h.sort_order';
    END;
    $$ LANGUAGE plpgsql;
    

**WLM queue configuration:** three queues — `wg_etl` (60% memory, Redshift
COPY and stored procedures during close window at 01:00–06:00), `wg_cfo` (30%
memory, CFO dashboard queries during business hours), `wg_analyst` (10%
memory, ad-hoc queries — throttled to prevent analyst queries from impacting
close jobs). Queue switching is automatic based on query group label set by
the application.

**Trade-off:** Redshift vs Snowflake for financial data. Snowflake's Time
Travel (up to 90 days on Enterprise tier) eliminates the need to maintain
separate snapshot tables — any historical state is queryable with `AT
(TIMESTAMP => '2024-01-31 23:59:59')`. Snowflake also auto-scales compute
without WLM tuning. Redshift with 1-year Reserved Instances gives predictable
cost — critical for a finance team that must budget IT costs upfront.

**Instance:** `ra3.4xlarge` x 2 nodes ($0.99/node/hour on-demand,
~$1,460/month for 2 nodes). Redshift Spectrum queries the S3 audit log from
Redshift SQL without loading it — useful for join queries between live
financial statements and historical audit records.

### Audit Log: S3 + Athena

**Why S3+Athena over loading the audit log into Redshift?**

  * Audit logs are write-once, read-rarely: written during the close window but queried only during SOX compliance checks, external audits, or SEC investigations — typically a few times per year, not daily
  * Redshift charges per cluster-hour regardless of query activity. Storing 7 years of audit log in Redshift (7 x 12 months x ~3GB/month = ~250GB) means permanently upsizing the cluster for rarely-queried data — adding ~$400/month indefinitely
  * Athena charges $5/TB scanned. With Parquet + Snappy and partition pruning by `year`, `month`, and `event_type`, a typical SOX audit query ("show all journal approvals for entity US001 in January 2024") scans a single partition (<500MB) = $0.0025. Annual cost for 50 audit investigations: ~$0.13 total
  * S3 Object Lock (Compliance mode) after hard close prevents deletion by any IAM principal — including root — before the 2,557-day retention expires, satisfying SOX at the infrastructure layer

**Athena partition projection config:**

    
    
    CREATE EXTERNAL TABLE audit_log_journal_lines (
        document_number  STRING,
        entity_code      STRING,
        account_code     STRING,
        amount_usd       DOUBLE,
        prepared_by      STRING,
        approved_by      STRING,
        approved_at      TIMESTAMP,
        etl_run_id       STRING
    )
    PARTITIONED BY (year INT, month INT, event_type STRING)
    STORED AS PARQUET
    LOCATION 's3://finance-audit-log/'
    TBLPROPERTIES (
      'projection.enabled'           = 'true',
      'projection.year.type'         = 'integer',
      'projection.year.range'        = '2024,2035',
      'projection.month.type'        = 'integer',
      'projection.month.range'       = '1,12',
      'projection.event_type.type'   = 'enum',
      'projection.event_type.values' = 'journal_posting,ic_elimination,fx_conversion,period_lock'
    );
    -- Workgroup: finance_sox_audit — query results encrypted SSE-KMS; per-query scan limit $0.10
    

### CFO Dashboard: QuickSight

**Why QuickSight over Tableau or Power BI for the CFO dashboard?**

  * QuickSight SPICE (Super-fast Parallel In-memory Calculation Engine): the CFO dashboard loads in <2 seconds even with 50M journal lines behind it — SPICE caches aggregated financial data in memory, not in Redshift. SPICE refresh is triggered by MWAA after each consolidation run, so the CFO sees updated numbers within minutes of each run
  * Row-level security via a dataset rules table: each country finance director is mapped to their `entity_code` and sees only that entity's data across all dashboards. The CFO role has no filter — sees all 47. RLS is enforced by QuickSight at the dataset layer, not the application layer
  * QuickSight embedding SDK: the close progress dashboard can be embedded inside the company's SAP Fiori portal without a separate QuickSight login — finance users see it as part of their existing workflow
  * Cost: $24/user/month (Standard) vs Tableau at $70/user/month for 50 users = $1,200/month vs $3,500/month. QuickSight Q (natural language queries) at $28/user lets finance users ask "what was APAC revenue in January vs December" without SQL

**Trade-off:** QuickSight vs Power BI for AWS shops. Power BI has a stronger
financial reporting feature set (paginated reports for pixel-perfect
regulatory output, better DAX for complex financial calculations) but requires
Microsoft 365 licensing and is optimised for Azure. For a company fully on
AWS, QuickSight's native IAM integration and VPC connectivity to Redshift (no
public endpoint needed) are meaningful operational wins. Use Power BI if the
finance team already has Microsoft 365 and demands pixel-perfect paginated
regulatory reports.

### Cost Estimate (AWS)

Service| Config| Monthly Cost| Notes  
---|---|---|---  
S3 (raw GL + audit log)| 100GB/month new, 7yr retention| $50–80| Intelligent-
Tiering + Glacier Deep Archive after 13 months  
MWAA| mw1.medium (2 schedulers, 10 workers)| $400–600| Fixed cost; responsive
during close window  
AWS Glue (IC elimination)| 20 DPU x 25 min x 1 run/month| $4–8| Serverless;
scales to zero between close runs  
EMR Spark (FX + consolidation)| m5.xlarge driver + m5.4xlarge x 8 Spot
workers| $10–20| Spot savings ~70%; on-demand driver for reliability  
Redshift (financial statements)| ra3.4xlarge x 2 nodes| $1,400–1,600| 1-yr RI
reduces to ~$900/month  
S3 + Athena (SOX audit queries)| Pay per query| $1–5| $5/TB; partitioned
Parquet keeps each query <1GB  
QuickSight| 50 Standard users| $1,200| SPICE refresh post-consolidation  
SNS + CloudWatch alarms| Close monitoring| $10–20| Per-entity submission
alarms + P&L anomaly alarms  
**Total**| | **$3,075–3,533/month**|  Redshift + QuickSight dominate; pause Redshift outside business hours for ~25% savings  
  
### Cost Optimization

Optimization| Approach| Savings  
---|---|---  
Redshift Reserved Instance| 1-year RI on ra3.4xlarge x 2| ~~40% vs on-demand
(~~ $560/month)  
Redshift auto-pause| Pause 20:00–06:00 weekdays + all weekend via Scheduler|
Additional ~~30% (~~ $250/month)  
EMR Spot workers| Spot for all worker nodes; on-demand driver only| ~~70% on
worker compute (~~ $8/month savings)  
S3 audit log lifecycle| Glacier Deep Archive after 13 months| 95% storage cost
reduction for data >1 year old  
Glue → EMR Serverless| Migrate IC job if running >3 times/month for
restatements| 75% per-run cost reduction at higher run frequency

