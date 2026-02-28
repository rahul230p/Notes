# DHH Core - System Design Interview Summary

## Project Overview
**DHH (Data Hub/Harmonization)**: Enterprise-grade data integration platform by IQVIA that ingests, transforms, and delivers multi-source data through batch, real-time, and file-based processing into Snowflake.

---

## System Design - One Liners

### High-Level Architecture
- **Multi-source ingestion**: Supports SFTP, S3, ADLS, Snowflake, APIs, PostgreSQL with a unified processing engine.
- **Three-layer design**: Ingestion → Processing (Batch + Real-Time) → Target Storage.
- **Snowflake-centric**: Leverages Snowpark for distributed processing and Snowpipe for near-real-time file ingestion.

---

## Batch Processing Pipeline

### Data Ingestion Layer (`DataIngestionSnowpark`)
- **Entry point**: Single orchestrator processes batch jobs triggered by metadata-driven scheduler.
- **Payload-driven**: Accepts JSON configuration containing source, target, transformation logic.
- **Session management**: Creates isolated Snowflake sessions per job for concurrent execution.

### File Reading Layer (`FileReader`)
- **Format agnostic**: Handles 10+ formats (CSV, Excel, JSON, XML, Parquet, SAS, FHIR, etc.) with format-specific handlers.
- **Security built-in**: Auto-detects and decrypts PGP-encrypted files during stream processing.
- **Validation early**: XSD/schema validation occurs before DataFrame conversion to fail fast.

### Data Transformation & Quality
- **Schema validation**: Compares ingested schema with expected metadata, supports auto-correction or failure modes.
- **Quality checks**: Configurable business rules validation (nullability, domain, uniqueness, referential integrity).
- **Lookup enrichment**: Joins source data with reference tables (PostgreSQL/Snowflake) for data enrichment.
- **Masking & de-identification**: PII redaction applied before persistence.

### Change Data Capture (CDC) Engine (`CDCLoad`)
- **8 CDC patterns**: Type I (Cumulative), Type II (Incremental), SCD Type 1-2 (Historical), Partition Overwrite, Partial Incremental, Full Replace, Append-only.
- **Hash-based change detection**: Uses SHA256(primary_keys) and SHA256(row_data) to identify and apply changes.
- **Hard delete detection**: Identifies records in target not in source via left anti-join on pk_hash; applies soft delete flag.
- **Threshold validation**: Prevents accidental mass deletes by validating hard-delete count ratio.
- **Audit trail**: Adds tracking columns (created_date, updated_date, batch_id, process_flag: A/I/D, soft_delete_flag).

### Multi-Schema Persistence
- **Main schema**: MERGE operation on primary key hash for CDC.
- **History schema (_hist)**: INSERT-only for immutable historical records.
- **Archive schema**: Snapshots and backups for compliance.

### Feature Flags & Control
- **Continuous run mode**: Supports long-running processes with max duration limits.
- **Configurable retries**: Automatic retry logic with exponential backoff.
- **Cost optimization**: Skips processing when no data exists; resumes on subsequent triggers.
- **Pipeline state**: Tracks Stopped, Suspended, In-Progress states; supports instance tracking via MD5 hash.

---

## Near-Real-Time File-Based Processing (Snowpipe + Snowpark)

### Intake 1: File Landing & Ingestion (Snowpipe)
- **Event-driven**: Files uploaded to S3 trigger SNS/SQS notifications → Snowpipe auto-ingests.
- **Atomicity**: Uses S3 PutObject/multipart with structured paths (source/date/dataset).
- **Low latency**: Files land in Snowflake staging tables within seconds of upload.
- **Metadata registration**: Captures file name, checksum, target table; status tracked in PostgreSQL (NEW → LANDED).

### Intake 2: Transformation & CDC Processing (Snowpark)
- **Metadata-driven orchestration**: Queries PostgreSQL for LANDED, unprocessed files.
- **Controlled polling**: Low-frequency triggers avoid unnecessary warehouse wake-ups.
- **Snowpark transformations**: Applies quality checks, lookups, masking, CDC logic.
- **Idempotent finalization**: Updates file_info status (PROCESSED/FAILED); enables replay without re-ingestion.

### Design Rationale
- **Separation of concerns**: Ingestion (Snowpipe) decoupled from transformation (Snowpark) for reliability and scaling.
- **Cost efficient**: Avoids frequent warehouse spin-ups; transformation triggers only when data is ready.
- **Auditability**: Metadata-driven model enables replay, fault isolation, and compliance.

---

## Common Processing Components

### CDC Type Support
| Type | Pattern | Use Case |
|------|---------|----------|
| I | Cumulative Load | Full dataset sync; hard/soft delete tracking |
| II | Incremental | Delta-only changes; no delete detection |
| III | SCD Type 1 | Overwrite existing values |
| IV | SCD Type 2 | Historical tracking with effective dating |
| V | Partition Overwrite | Replace data by partition key |
| VI | Partial Incremental | Incremental within partitions |

### Quality Control Engine
- **Business rule validation**: Configurable domain, uniqueness, referential integrity checks.
- **Threshold-based rejection**: Rejects batches exceeding error thresholds.
- **Quarantine mechanism**: Stores failed records separately for investigation.

### Lookup Engine
- **Reference table joins**: Enriches source data with dimensions (e.g., region codes, product names).
- **Cache management**: In-memory caching of lookup tables for performance.
- **Fallback handling**: Configurable behavior for unmatched lookups (null, default, fail).

### Derived Variables & Variable Mapping
- **Expression engine**: Evaluates derived column expressions (e.g., age = current_date - birth_date).
- **Variable mapping**: Maps source columns to canonical target names per configuration.
- **Scoring engine**: Calculates risk scores, benchmarks, metrics.

### Measure Builder (Benchmark Calculation)
- **Aggregate metrics**: Computes benchmarks, quartiles, percentiles across cohorts.
- **Temporal comparisons**: YoY, MoM calculations and trend analysis.

---

## Target / Storage Layer

### Multi-Target Support
- **Snowflake (default)**: Primary data warehouse for analytics, CDC, historical tracking.
- **Data Exchange**: Generates and delivers curated datasets via SFTP, S3, ADLS, APIs.
- **Archive**: Long-term snapshots, compliance backups.

### Data Delivery Mechanisms
- **Push to S3/ADLS**: Encrypted file exports with PGP encryption option.
- **SFTP delivery**: Secure file transfer to partner systems.
- **API export**: RESTful endpoints for real-time data consumption.

---

## Metadata & Orchestration Layer

### Orchestration: Akka Actor System
- **Actor-based scheduling**: Akka actors manage job scheduling, state transitions, and concurrent execution.
- **Non-blocking execution**: Actor messaging ensures no thread blocking; leverages Futures for async composition.
- **Supervisor strategy**: Fault-tolerant orchestration with configurable restart policies for failed jobs.
- **Dynamic dispatch**: Actors spawn transformation jobs based on metadata; scales with workload.
- **State machine model**: Each pipeline execution tracked as actor state; prevents duplicate runs.

### Metadata Management (PostgreSQL)
- **Pipeline configuration**: Source/target mappings, CDC types, transformation rules.
- **File tracking**: file_info table tracks ingestion status (NEW → LANDED → PROCESSED).
- **Dataset registry**: Catalog of all datasets, schemas, lineage.
- **Orchestration state**: Execution history, job status, scheduling metadata persisted in PostgreSQL.

### Logging & Monitoring (Logging V2)
- **Structured logging**: JSON logs with execution timestamps, job_id, error stacks.
- **Audit trail**: Complete record of who changed what and when.
- **SLA tracking**: Pipeline duration, failure rates, retry counts.

### Notification & Alerting
- **Email notifications**: Success/failure alerts with summary metrics.
- **Slack integration**: Real-time alerting for critical failures.
- **SLA dashboards**: Monitoring and alerting on pipeline health.

### Pipeline State Management
- **Idempotency**: Rerun failed batches without re-ingesting source data.
- **Rollback capability**: Snapshot-based recovery; can revert to prior state.
- **Concurrent safety**: Actor-based coordination prevents duplicate parallel executions.

---

## Technology Stack Justification & Tradeoffs

### Core Processing Engine: Snowpark + Snowflake

**Why Snowpark?**
- **Distributed computing without infrastructure**: Write Scala/Python logic in Snowflake; scales automatically across warehouse nodes.
- **No ETL framework overhead**: Avoids Spark, Airflow, or Kubernetes complexity; integrates natively with data warehouse.
- **Cost efficiency**: Pay only for compute used; warehouse scales up/down with workload; no idle cluster costs.
- **Native data access**: Direct access to Snowflake tables; no intermediate staging or network transfers.

**Alternatives & Tradeoffs:**

| Stack | Pros | Cons | Why Not Used |
|-------|------|------|-------------|
| **Apache Spark** | Industry standard; flexible; distributed | Requires Kubernetes/Yarn infrastructure; high operational overhead; separate from DW | Managing K8s + Spark clusters doubles DevOps burden; data must move between Spark and Snowflake |
| **dbt (DBT)** | SQL-focused; DW-native; version control friendly | Limited for complex transformations; no orchestration; struggles with non-SQL logic | DHH requires Scala/advanced logic; dbt lacks programmatic orchestration control |
| **Apache Airflow** | Popular orchestrator; flexible scheduling | Requires infrastructure; metadata database overhead; can become complex at scale | DHH uses Airflow-like orchestration in PostgreSQL; Snowpark gives Snowflake-native execution |
| **AWS Glue** | Serverless; AWS-native | Vendor lock-in to AWS; limited to cloud; expensive for large jobs; less mature CDC | DHH must support multi-cloud (AWS, Azure, GCP); Snowflake is platform-agnostic |
| **Informatica/Talend** | Enterprise-grade; no-code UI | Expensive licenses; proprietary; limited transparency; vendor lock-in | IQVIA built custom → full control; open-source stack reduces cost |

**Verdict**: Snowpark balances **cost**, **simplicity**, and **DW-centricity** without enterprise software costs.

---

### Orchestration: Akka Actor System (not Airflow, not Kubernetes CronJobs)

**Why Akka Actor System for Orchestration?**
- **Lightweight, distributed orchestration**: Actor-based scheduling avoids operational overhead of Airflow; pure JVM-based.
- **Non-blocking concurrency**: Actor messaging model ensures no thread starvation; handles 1000s of concurrent jobs.
- **Fault tolerance built-in**: Supervisor strategies provide automatic restart, exponential backoff, and circuit breaker patterns.
- **Single runtime**: Orchestration and transformations run in same JVM; no inter-process communication overhead.
- **Dynamic job dispatch**: Actors spawn transformation jobs based on PostgreSQL metadata; enables runtime reconfiguration.
- **State consistency**: Actor state machine model prevents duplicate concurrent executions; strong ordering guarantees.

**Alternatives & Tradeoffs:**

| Stack | Pros | Cons | Why Not Used |
|-------|------|------|-------------|
| **Akka Actor System** (current) | Lightweight; non-blocking; fault-tolerant; JVM-native; scales to 1000s of concurrent jobs | Steeper learning curve; less mature UI/monitoring than Airflow | DHH priority: reliability + concurrency; Akka excels at both; no UI needed for metadata-driven execution |
| **Apache Airflow** | Industry standard; rich UI; DAG visualization; mature plugins | 10+ microservices (webserver, scheduler, executor, worker); operational complexity; scales poorly at 1000s of DAGs | Airflow designed for DAG orchestration; DHH uses simple metadata-driven model; Akka is lighter |
| **Prefect/Dagster** | Modern; better error handling; versioning | Still require multiple services; overkill for metadata-driven architecture; vendor-specific lock-in | DHH orchestration is state machine; doesn't need complex DAG composition |
| **Kubernetes CronJobs** | Native K8s; no extra services | Limited state management; no built-in retry/backoff; hard to track cross-job dependencies | DHH needs strong consistency guarantees; K8s eventual consistency unsuitable |
| **AWS Step Functions** | Serverless; managed; visual workflow editor | Vendor lock-in to AWS; state machine limited to JSON; poor for complex logic; expensive at scale | DHH must be multi-cloud; Step Functions ties to AWS; Akka is platform-agnostic |
| **Custom polling orchestrator** | Simple; lightweight | No fault tolerance; hard to handle concurrent jobs; no supervisor strategy; operational burden | Akka provides fault tolerance + concurrency for free; custom polling lacks both |

**Verdict**: Akka Actor System balances **simplicity**, **concurrency**, and **fault tolerance** without operational overhead of Airflow or cloud lock-in of Step Functions.

---

### Data Ingestion: Snowpipe + EventBridge + S3

**Why Snowpipe for File Ingestion?**
- **Fully managed**: Snowflake handles S3 polling, retries, error handling; no custom code.
- **Event-driven latency**: S3 upload triggers SNS → Snowpipe in seconds; no scheduled polling.
- **Integrated logging**: All Snowpipe events logged in Snowflake; query history integrated.
- **No infrastructure**: No containers, no servers; scales automatically.

**Alternatives & Tradeoffs:**

| Stack | Pros | Cons | Why Not Used |
|-------|------|------|-------------|
| **Snowpipe** (current) | Managed; event-driven; cost-efficient | Limited transformation capability; no data cleaning before load | Intentional: separates ingestion (Snowpipe) from transformation (Snowpark); enables replay |
| **Lambda + S3 Events** | Serverless; flexible; can transform | Cold starts (1-5s latency); harder to integrate with Snowflake; hidden costs at scale | Snowpipe is purpose-built for Snowflake; adds latency vs Lambda |
| **Fivetran/Stitch** | Fully managed; connectors for 300+ sources | Expensive per connector; vendor lock-in; less control over transformation | IQVIA needs custom logic; pre-built connectors insufficient |
| **Custom Spark job** | Full control; flexible | Operational overhead; must manage retries, state, scaling; expensive | Defeats purpose of serverless; Snowpipe already solves the problem |
| **Direct S3 → Snowflake COPY** | Simplest; no extra service | Requires scheduled tasks; hard to track file history; no event-driven trigger | Snowpipe is wrapper around COPY with event-driven trigger; minimal overhead |

**Verdict**: Snowpipe is purpose-built for Snowflake file ingestion; event-driven avoids scheduling costs.

---

### Metadata Store: PostgreSQL (not Snowflake, not MongoDB)

**Why PostgreSQL for Metadata?**
- **ACID compliance**: Transactional metadata updates; prevents race conditions.
- **Rich querying**: SQL joins, complex predicates, window functions for orchestration logic.
- **Separation of concerns**: Metadata operational DB separate from analytical DW; no contention.
- **Cost**: PostgreSQL on RDS/Cloud SQL is cheaper than Snowflake for small metadata workloads.

**Alternatives & Tradeoffs:**

| Stack | Pros | Cons | Why Not Used |
|-------|------|------|-------------|
| **PostgreSQL** (current) | ACID; rich SQL; lightweight | Requires separate infrastructure | Cost is negligible; ACID guarantees crucial for orchestration state |
| **Snowflake** | Already licensed; integrated with DW | Expensive for small metadata workloads; separate metadata DB wastes Snowflake compute | Metadata queries are small; separate DB cheaper and avoids warehouse wake-ups |
| **MongoDB/DynamoDB** | Scalable; flexible schema | Weak querying; no ACID guarantees; harder to maintain orchestration invariants | ACID essential for pipeline state; SQL joins needed for complex orchestration |
| **Firestore/DynamoDB** | Managed; serverless | No rich querying; eventual consistency; complex transactions | Orchestration requires strong consistency; PostgreSQL ACID is non-negotiable |

**Verdict**: PostgreSQL is lightweight, ACID-compliant, cost-effective metadata store.

---

### Dual-Intake Architecture: Snowpipe (Ingestion) + Snowpark (Transformation)

**Why Separate Ingestion & Transformation?**

**Resilience:**
- **Ingestion failure**: File fails Snowpipe → retry exponentially → no transformation blocked.
- **Transformation failure**: Bad SQL logic → only that batch fails; re-ingest not needed (checksum in metadata).
- **Replay without re-ingestion**: Fix transformation bug → rerun same data → no need to wait for source system.

**Cost:**
- **No perpetual warehouse**: Snowpipe lands files automatically; warehouse only spins for transformation.
- **Compute efficiency**: Transformation job reads only relevant staging table partition; avoids full S3 scan.
- **Audit trail**: File ingestion events separate from transformation events; easier debugging.

**Operational Control:**
- **Different SLAs**: Ingestion SLA: 30 seconds. Transformation SLA: 5 minutes. Can tune independently.
- **Backpressure handling**: If transformation backed up, Snowpipe keeps landing files; no data loss.
- **Monitoring granularity**: Track file arrival vs transformation latency separately.

**Alternative: Single-Intake (Snowpipe → Transformation in Snowpipe Notification)**

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Dual-Intake** (current) | Resilience; auditability; replay; separate SLAs | Slightly more complex orchestration | **Better for enterprise** — compliance & reliability matter |
| **Single-Intake** | Simpler; fewer components | Hard to replay; cascade failures; no separation of concerns | **Simpler but risky** — production outage if transformation breaks |

**Verdict**: Dual-intake is enterprise best practice; separation of concerns prevents cascade failures.

---

### Change Data Capture: Hash-Based (not Timestamps, not Sequence Numbers)

**Why Hash-Based CDC?**
- **Source-system agnostic**: Works even if source has no timestamps, update flags, or sequence numbers.
- **Accurate change detection**: Compares actual row contents; detects soft updates (update to same value).
- **Delete detection**: Records in target not in source = hard deletes; no delete markers needed.
- **Deterministic**: Same input hash = same CDC action; fully reproducible.

**Alternatives & Tradeoffs:**

| Approach | Pros | Cons | Why Not |
|----------|------|------|---------|
| **Timestamp-based** | Industry standard; fast (query `updated_at > last_sync_time`) | Requires source to maintain accurate timestamps; fails with timezone shifts; struggles with bulk updates | Not all sources have reliable timestamps; requires source cooperation |
| **Sequence numbers (LSN)** | Exact ordering; used by Postgres WAL, Oracle LogMiner | Requires source DBs to support; doesn't work for files, APIs, manual uploads | DHH ingests files & APIs; no sequence numbers available |
| **Change tables (Capture Denali)** | Native to SQL Server; accurate | Limited to SQL Server; expensive; vendor lock-in | DHH multi-source; Snowflake doesn't have equivalent |
| **Hash-based** (current) | Source-agnostic; works with any format; deterministic | Slight overhead (compute SHA256); slower than timestamp filtering on large tables | DHH prioritizes flexibility over speed; hash comparison is negligible vs I/O |

**Verdict**: Hash-based CDC enables flexibility; all DHH sources supported.

---

### Language Stack: Scala (not Python, not Go)

**Why Scala for Core Processing?**
- **Type safety**: Compile-time guarantees; catches errors before runtime in complex transformations.
- **Functional programming**: Immutable data structures; easier testing and parallelization.
- **JVM ecosystem**: Access to 20 years of Java libraries; mature, battle-tested.
- **Snowpark native**: Snowpark provides Scala APIs as first-class citizen; Python is second-class.

**Alternatives & Tradeoffs:**

| Language | Pros | Cons | Why Not |
|----------|------|------|---------|
| **Scala** (current) | Type-safe; functional; native Snowpark support; mature | Steeper learning curve; slower startup | DHH core engineers comfortable with Scala; type safety worth the tradeoff |
| **Python** | Easier to learn; faster development | Weak typing; runtime errors in production; Snowpark Python is slower | Data quality critical; type safety prevents production bugs |
| **Go** | Fast; concurrent; simple syntax | No Snowpark support; reinvents the wheel for data processing | Overkill for data transformations; Snowpark already provides concurrency model |
| **SQL only** | Simple; DW-native | No complex logic; hard to maintain; no version control | Some transformations require procedural logic (lookups, conditionals, error handling) |

**Verdict**: Scala balances type safety, Snowpark support, and maintainability.

---

## Summary: Why This Stack?

| Component | Choice | Key Reason | Tradeoff |
|-----------|--------|-----------|----------|
| Data warehouse | Snowflake | Cloud-native; multi-cloud; serverless | Higher per-compute cost vs on-prem |
| Processing | Snowpark | DW-native; no infrastructure | Less flexible than Spark for non-DW workloads |
| Ingestion | Snowpipe | Event-driven; managed; integrated | Limited to cloud object storage |
| Orchestration | Akka Actor System | Non-blocking concurrency; fault-tolerant; lightweight | Steeper learning curve than Airflow; less mature UI |
| Metadata Store | PostgreSQL | ACID; rich SQL; cost-effective | Separate infrastructure (negligible cost) |
| Architecture | Dual-intake | Resilience; replay; auditability | Slightly more components |
| CDC | Hash-based | Source-agnostic; flexible | Small compute overhead vs timestamp-based |
| Language | Scala | Type-safe; functional; Snowpark-native; Akka-native | Learning curve |

**Net Result**: Enterprise-grade, cost-efficient, resilient platform prioritizing **auditability**, **concurrency**, and **reliability** over operational simplicity.

---

## Summary for Interviewers

*"DHH is a metadata-driven, cloud-native data integration platform purposefully built on Snowflake + Snowpark for cost efficiency and auditability. It unifies batch and file-based ingestion through a dual-intake architecture: Snowpipe handles event-driven file landing; Snowpark executes transformations. Akka Actor System orchestrates scheduling and job execution—providing non-blocking concurrency, fault tolerance, and state consistency without Airflow's operational complexity. Hash-based CDC enables source-agnostic change detection across 8 patterns. PostgreSQL stores pipeline metadata (configurations, state, audit trail). The architecture prioritizes resilience (ingestion & transformation failure isolation), replay capability (fixes without re-ingestion), and compliance auditability. Why this stack? Snowflake is multi-cloud serverless; Snowpark avoids K8s complexity; Snowpipe is purpose-built; Akka provides lightweight, fault-tolerant orchestration; PostgreSQL ensures ACID guarantees. Tradeoffs: serverless higher per-compute cost, Akka has steeper learning curve than Airflow, hash-based CDC has compute overhead. Result: enterprise-grade platform that's simpler, cheaper, and more auditable than Spark/Airflow stacks."*

