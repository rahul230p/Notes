# Incremental Lakehouse Architecture

Source: https://datapathsala.com/system-design/incremental-lakehouse

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Incremental Lakehouse ArchitectureAdd
Note

# Incremental Lakehouse Architecture

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design an enterprise data platform that unifies three disparate source types,
legacy flat files (CSV/XML dropped via SFTP), CDC streams from operational
databases (via Debezium), and real-time event streams (via Kafka), into a
single lakehouse with a medallion architecture (bronze/silver/gold). The
organization has 500 source tables, 50TB of existing historical data, and
ingests ~100GB of new/changed data daily. The system must support incremental
processing (no full reloads), SCD Type 2 for slowly changing dimensions,
schema evolution, and data quality gates. How would you design this end to
end?”

Expand AllCollapse All13 sections + 3 cloud implementations

How to Approach This Problem

## How to Approach This Problem

Most candidates treat this as a generic "design a data pipeline" question and
produce a generic answer. Incremental lakehouses have three hard, specific
problems that separate strong answers from weak ones. Address all three
explicitly.

### Three Hard Problems Unique to Incremental Lakehouses

**1\. Late-arriving data requires MERGE semantics, not INSERT.**

An event arrives 4 hours late due to a delayed upstream pipeline. If you
INSERT it into a time-partitioned Parquet table, the partition for that hour
has already been closed and read by downstream jobs. Strong answers use Delta
Lake MERGE INTO or Iceberg row-level upserts so late data lands in the correct
partition without rewriting it. They also explain the watermark strategy: how
late is "too late" to accept, and what happens to data beyond the watermark. A
candidate who says "just append it and fix the partition later" has revealed
they have not operated this system under real conditions.

**2\. The small file problem silently kills query performance in streaming
lakehouses.**

A micro-batch job writing every 5 minutes creates roughly 288 files per
partition per day. After a week, Athena, Spark, and Trino must open thousands
of 1-10 MB files where optimal performance needs a handful of 128-256 MB
files. Query latency degrades 10-100x. Strong answers implement a compaction
job (Delta OPTIMIZE or Iceberg rewrite_data_files) running on a schedule
alongside the ingestion pipeline. Weak answers describe the ingestion pipeline
in detail but never mention compaction, which means they have never actually
maintained a streaming lakehouse in production.

**3\. Partition scheme evolution breaks query plans when data access patterns
change.**

You partition by date. Six months later, queries filter by user_id or region.
Full partition scans become expensive. Changing the partition scheme means
rewriting all historical data. Strong answers use Iceberg hidden partitioning
or Delta Z-ordering and liquid clustering so the physical layout can evolve
independently of the logical schema without a full rewrite. Candidates who
propose a static partition-by-date scheme without discussing evolution have
not hit the six-month wall in a real system.

### What the Interviewer Is Testing

Signal| What They Want to See  
---|---  
Operational experience| Do you know what breaks after the system is running,
not just during the initial design?  
Table format depth| Can you explain the trade-offs between copy-on-write and
merge-on-read for each lakehouse layer?  
Incremental processing correctness| Do you understand watermarks, late data,
and idempotent writes beyond "use a checkpoint"?  
Compaction and maintenance| Do you know that a streaming lakehouse without a
compaction job degrades over days, not years?  
Partition evolution| Can you explain how Iceberg or Delta allows the physical
layout to change without a full rewrite?  
  
### Structured Walkthrough

Step| What to Cover| Time  
---|---|---  
1| Clarify requirements: source types, volume, freshness SLAs, late-arrival
window, downstream consumers| 2-3 min  
2| High-level architecture: unified Kafka bus, medallion layers, table format
choice| 5 min  
3| Deep dive: MERGE semantics for late data, watermark strategy, SCD Type 2
implementation| 10 min  
4| Compaction and maintenance: small file problem, compaction schedule,
rewrite strategies per layer| 5 min  
5| Partition evolution and query performance: hidden partitioning, Z-ordering,
evolving without rewrites| 5 min  
  
### Your Opening Move

> "Before I draw anything, I want to nail down three operational constraints
> that will drive every architectural decision. First, what is the late-
> arrival window? How late can a CDC event arrive and still be accepted into
> the correct partition? Second, what is the micro-batch frequency for
> streaming ingestion? Because that directly determines how aggressive the
> compaction schedule needs to be. Third, do query patterns change over time,
> or is partition-by-date a stable long-term choice? The answers to those
> three questions will determine whether I recommend Iceberg with hidden
> partitioning, Delta with liquid clustering, or a simpler static-partition
> design."

Clarifying Questions to Ask the Interviewer

## High-Level Architecture

CSV/XML dropschange eventsreal-time eventsparsed recordsCDC eventsbatch micro-
batchstreaming consumeraw landingstreaming ingestcleaned +
SCD2aggregatedorchestratesquality gatesserving layercurated tablesfailed
eventsreprocess after fixbackfill / reprocess

SFTP / Flat Files

CDC (Debezium)

![Kafka \(Events\)](/icons/tools/kafka.svg)Kafka (Events)

File Ingestion Service

![Kafka Connect](/icons/tools/kafka.svg)Kafka Connect

![Kafka \(Unified Bus\)](/icons/tools/kafka.svg)Kafka (Unified Bus)

![Spark \(Batch ETL\)](/icons/tools/spark.svg)Spark (Batch ETL)

Flink (Streaming ETL)

![Airflow \(Orchestrator\)](/icons/tools/airflow.svg)Airflow (Orchestrator)

Data Quality (GE)

Bronze Layer (Raw)

Silver Layer (Cleaned)

Gold Layer (Aggregated)

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

Medallion Architecture & Data Quality

Scalability & Fault Tolerance

Monitoring & Observability

Schema Evolution & Data Governance

Follow-Up Questions & Answers

Technology Comparison

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS-Native Solution — Architecture

file dropschange eventsstreaming eventsfile ETLCDC + streaming ETLbronze /
silver / goldgovernance + catalogserving layerorchestratesfailed
eventsreprocess

AWS Transfer Family

DMS (CDC)

Amazon MSK

![S3 \(Landing Zone\)](/icons/aws/s3.svg)S3 (Landing Zone)

MSK (Unified Bus)

![AWS Glue ETL](/icons/aws/glue.svg)AWS Glue ETL

Lake Formation

![S3 + Iceberg \(Lakehouse\)](/icons/aws/s3.svg)S3 + Iceberg (Lakehouse)

![Redshift Serverless](/icons/aws/redshift.svg)Redshift Serverless

MWAA (Airflow)

SQS DLQ

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around Transfer Family for SFTP ingestion, DMS for CDC,
> MSK for the unified Kafka bus, S3 + Iceberg for the lakehouse layers, Glue
> for ETL, Lake Formation for governance, and Redshift Serverless for the
> serving layer."

### End-to-End Data Flow

    
    
    1. Legacy partners drop CSV/XML files via AWS Transfer Family -> S3 landing zone
    2. S3 event notification -> SQS -> Glue ETL job parses files, produces to MSK
    3. DMS captures CDC from RDS/Oracle -> MSK topics (one per source table)
    4. MSK (unified bus) holds all events in canonical envelope format
    5. Glue ETL (Spark) consumes from MSK -> writes to S3 + Iceberg (bronze layer)
    6. Glue ETL transforms bronze -> silver (SCD2 MERGE, dedup, DQ gates)
    7. Glue ETL aggregates silver -> gold (business aggregates)
    8. Lake Formation enforces governance: catalog, access control, column masking
    9. Redshift Serverless queries gold/silver Iceberg tables for BI serving
    10. MWAA (Airflow) orchestrates all Glue jobs with cross-DAG dependencies
    11. Athena provides ad-hoc query access to any layer for data engineers
    12. Failed events -> SQS DLQ -> inspect, fix, reprocess to MSK
    

### File Ingestion: AWS Transfer Family

**Why Transfer Family for SFTP?**

  * Fully managed SFTP/FTPS/FTP server backed by S3, no EC2 instances to manage.
  * Partners continue using their existing SFTP clients. Zero migration effort on the source side.
  * S3 event notifications trigger downstream processing automatically on file arrival.
  * Custom identity provider integration (Lambda + Secrets Manager) for partner authentication.
  * Cost: $0.30/hour per server + $0.04/GB transferred. For 200 file sources at 30 GB/day, roughly $250/month.
  * Trade-off: Transfer Family has limited file transformation capability. Parsing and schema validation happen in Glue, not at the SFTP layer.

### CDC Ingestion: AWS DMS

**Why DMS over self-managed Debezium?**

  * Managed service, no Kafka Connect cluster to operate for CDC capture.
  * Supports Oracle, PostgreSQL, MySQL, SQL Server, and MongoDB as sources.
  * Full-load + CDC mode: performs initial historical load, then switches to continuous CDC.
  * Delivers to MSK (Kafka), Kinesis, or directly to S3, we choose MSK for the unified bus pattern.
  * Built-in table mapping rules for filtering columns and tables at the source.
  * Trade-off: DMS CDC format is proprietary. We add a Glue ETL normalization step to convert DMS output into our canonical envelope before it enters the unified bus. For teams that prefer open standards, Debezium on MSK Connect is a viable alternative.

### Unified Bus: Amazon MSK

**Why MSK over Kinesis?**

  * Full Apache Kafka compatibility, existing Kafka clients, connectors, and tooling work unchanged.
  * MSK Connect for running Kafka Connect connectors (Debezium, S3 sink) as a managed service.
  * MSK Serverless eliminates broker provisioning, auto-scales based on throughput.
  * Tiered storage offloads cold data to S3 automatically, reducing broker disk costs.
  * Glue Schema Registry integrates natively for Avro/JSON schema validation on every message.
  * Cost: MSK Serverless pricing is $0.10/GB ingested + $0.05/GB stored. For 100 GB/day, roughly $10/day.

### ETL Processing: AWS Glue

**Why Glue for ETL?**

  * Serverless Spark, no cluster management, auto-scales workers per job.
  * Native Iceberg connector: read, write, MERGE INTO, schema evolution all supported.
  * Glue Data Catalog serves as the Hive Metastore for Iceberg tables, single catalog for all engines.
  * Glue Schema Registry validates incoming Kafka messages against registered Avro schemas.
  * Glue job bookmarks provide built-in watermarking for incremental reads from S3.
  * Flex execution mode (spot instances) reduces cost by 40-60% for non-time-critical batch jobs.
  * Cost: $0.44/DPU-hour. A typical bronze-to-silver job for 250 CDC tables runs 20 DPUs for 2 hours = $17.60/run.

**Glue ETL for SCD Type 2:**

    
    
    # Glue job: silver SCD2 merge for customers
    glue_context.write_dynamic_frame.from_options(
        frame=transformed_df,
        connection_type="iceberg",
        connection_options={
            "path": "glue_catalog.silver.customers",
            "merge_on": "customer_id",
            "merge_when_matched": "UPDATE SET effective_to = source.event_timestamp, is_current = false",
            "merge_when_not_matched": "INSERT"
        }
    )
    

### Governance: Lake Formation

**Why Lake Formation?**

  * Centralized permission model for the entire lakehouse, replaces per-service IAM policies.
  * **Fine-grained access control:**
    * Table-level: analysts can read gold but not bronze.
    * Column-level masking: PII columns (email, name) are masked for non-privileged roles.
    * Row-level: finance team sees only finance-domain rows via row filter expressions.
    * Cell-level: combine row and column filters for maximum granularity.
  * Tag-based access control (LF-Tags): tag tables/columns with `pii=true`, `domain=finance`, then create policies on tags instead of individual resources. When a new table is tagged, policies apply automatically.
  * Governed tables: Lake Formation manages Iceberg table transactions, ensuring ACID semantics across concurrent Glue jobs.
  * **Cross-account sharing:** Share lakehouse tables with other AWS accounts (data mesh pattern) without data copying.
  * Audit: Every data access logged to CloudTrail, who queried what table, which columns, when.

### Serving Layer: Redshift Serverless + Athena

**Redshift Serverless** for BI workloads:

  * Queries gold and silver Iceberg tables directly on S3, no data loading required.
  * Auto-scales compute (RPUs) based on query complexity.
  * Materialized views on Iceberg tables for sub-second BI dashboard queries.
  * Cost: $0.375/RPU-hour, only billed during query execution.

**Athena** for ad-hoc analysis:

  * Serverless SQL engine that queries any Iceberg table in the Glue Catalog.
  * Data engineers use Athena for exploration, debugging, and ad-hoc quality checks.
  * Integrates with QuickSight for self-service dashboards.
  * Cost: $5/TB scanned. Iceberg's metadata-driven pruning minimizes scan volume.

### Orchestration: MWAA (Managed Airflow)

  * Fully managed Apache Airflow, no Airflow infrastructure to operate.
  * Native integration with Glue, EMR, Redshift, S3, and MSK.
  * Dataset-aware scheduling (Airflow 2.4+): silver DAGs trigger automatically when bronze datasets are updated.
  * Auto-scaling workers handle burst scheduling during nightly batch windows.

### Cost Optimization Summary

Service| Optimization| Savings  
---|---|---  
Glue| Flex execution (spot) for batch jobs| 40-60%  
MSK| Serverless mode (auto-scales, no broker sizing)| 30-50% vs provisioned  
S3| Lifecycle policies: Standard -> IA (30d) -> Glacier (90d)| 70-80% on cold
data  
Redshift| Serverless (pay per query, not per cluster)| 50-70% for bursty BI  
Lake Formation| Tag-based policies reduce admin overhead| Operational cost
savings  
Athena| Iceberg metadata pruning reduces scan volume| 60-80% less data scanned

