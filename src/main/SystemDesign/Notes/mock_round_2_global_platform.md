# Mock Round 2 — Global multi-tenant data platform
## Canonical reference answers

**Company:** Warner Bros. Discovery  
**Role:** Senior Data Engineer  
**Round:** Software Architecture / System Design (Scale, Global)  
**Principles:** Empower Storytelling · Dream It & Own It

---

## Problem statement

WBD operates in 220+ countries. Max has launched across NA, LATAM, EU, and APAC. Each region has different content libraries, subscriber bases, and regulatory requirements. Post-merger each region built its own data platform:

- **North America:** Snowflake
- **Europe:** Redshift + on-prem Hadoop
- **APAC:** BigQuery (acquired)

Design a **global multi-tenant data platform** that unifies these regions, enforces data governance and compliance, and serves both analytical and operational use cases at WBD scale.

---

## Step 1 — Requirements elicitation (ask these before designing)

### Functional questions to ask
- What are the data sources and sinks?
- What file formats are inbound and what is the platform standard?
- Who are the end users and what do they need?
- What transformations are required on source datasets?

### Non-functional questions to ask
- What is the latency SLA for operational vs analytical layers?
- What is the source data volume?
- What is the data retention period?
- What are the PII and compliance requirements per region?
- Is hard data isolation required region-by-region?

### Answers (from business stakeholder)

**Data sources:**
- Max streaming events: 7M events/sec peak
- Content metadata: updated daily via CMS, ~500 GB/day
- Subscriber/identity: CDC from operational DBs, ~2 TB/day
- Ad impression and click events: 2M events/sec
- Third-party data (Nielsen, social sentiment): batch file drops daily

**Data sinks:**
- BI dashboards (Looker, Tableau)
- ML feature store (online + offline)
- Operational APIs (recommendation, entitlement checks)
- Regulatory reporting (per-region compliance exports)

**File formats:**
- Inbound: JSON (events), CSV (third-party), Avro (CDC)
- Platform standard: **Parquet with Zstd compression**
- Open table format: **Apache Iceberg** (see justification below)

**End users:**
- Data analysts (SQL, BI tools)
- Data scientists (Python, notebooks, ML)
- Platform/product engineers (operational APIs)
- Compliance and legal (audit trails, lineage)
- Regional business teams (LATAM, EMEA, APAC)

**Latency SLAs:**

| Layer | SLA | Serving technology |
|---|---|---|
| Operational (recommendation, entitlement) | < 50ms | Redis / DynamoDB |
| Near-real-time analytics (live dashboards) | < 5 minutes | Snowflake Dynamic Tables / Druid |
| Batch analytics (overnight reports, ML) | < 6 hours | Snowflake / Iceberg + Spark |

**Data volumes:** ~10 PB total historical across all regions  
**Retention:** raw events 90 days hot / 7 years cold; audit logs 7 years immutable  
**PII regulations:** GDPR (EU), LGPD (Brazil), CCPA (CA), PDPA (APAC)  
**Data isolation:** Hard requirement — EU data must not leave EU infrastructure including compute

---

## Step 2 — Foundational decisions

### Open table format — Apache Iceberg

At 10 PB across three legacy platforms, the platform needs an open format that:
- Avoids vendor lock-in across Snowflake, Redshift, and BigQuery
- Supports multi-engine reads (Spark, Trino, Athena, Snowflake external tables)
- Provides ACID transactions, time-travel, and schema evolution
- Enables incremental CDC ingestion natively

**Why Iceberg over Delta Lake or Hudi:**
```
Iceberg  → broadest engine support, best for multi-cloud/multi-engine WBD
Delta    → Databricks-native, strong but less portable
Hudi     → streaming-first, stronger for upsert-heavy CDC but narrower ecosystem
```

**Why not Snowflake-only at 10 PB:**
```
Problem 1: 10 PB migration is a 2-year programme, not an architecture decision
Problem 2: Snowflake SaaS does not give you compute-level EU data residency guarantees
Problem 3: Snowflake storage at 10 PB is significantly more expensive than S3 + Iceberg
Solution:  Iceberg on S3/GCS/ADLS as the storage layer
           Snowflake as the governed query and transformation layer on top
           This is the hybrid lakehouse pattern
```

### Tenancy model — region as tenant

Each region is a tenant with:
- Its own Snowflake **Business Critical account** in the correct cloud region
- Its own **S3/GCS bucket** for raw Iceberg storage, in-region
- Its own **IAM boundary** — cross-region access requires explicit Data Sharing or aggregated exports only
- **Zero raw PII** crossing regional boundaries under any circumstances

```
Tenancy hierarchy:
Region (hard isolation boundary)
  └── Business unit (DB-level isolation within regional account)
        └── Team (schema-level isolation)
              └── Role (row/column-level access policies)
```

---

## Step 3 — Architecture

### Per-region architecture (example: EU)

```
EU Data Sources
  ├── Max streaming events (Kafka/MSK EU)
  ├── Subscriber CDC (Debezium → Kafka)
  ├── Content metadata (CMS API)
  └── Legacy Redshift + Hadoop data

        ↓ ingestion layer

EU Ingestion
  ├── Kafka → Flink → Parquet → S3 EU (Bronze Iceberg)
  ├── CDC (Debezium) → Kafka → Snowflake Kafka Connector → RAW tables
  ├── Legacy Redshift → S3 unload (Parquet) → Snowflake External Table (bridge)
  └── Legacy Hadoop → S3 export → Snowflake External Table (bridge)

        ↓ transformation layer (Snowflake EU Business Critical account)

Medallion layers inside Snowflake EU:

  BRONZE (RAW schema)
    Append-only permanent tables
    Exact copy of source — no transformation, no masking
    Ingested via: Snowpipe, Kafka Connector, external tables
    Retention: 90 days hot

  SILVER (STAGING schema)
    Snowflake Streams capture DML changes from BRONZE
    Transformations via dbt incremental models:
      - Deduplication: QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_ts) = 1
      - PII tokenization (see GDPR section)
      - Data type casting and schema standardisation
      - Data quality checks (see DQ section)
      - Currency normalisation (multi-currency revenue)
      - Content catalog ID unification (HBO + Discovery + acquired IDs)
    Orchestration: Apache Airflow on MWAA

  GOLD (MARTS schema)
    Business-ready aggregated tables
    No raw PII — safe for Data Sharing
    Input to: BI tools, ML feature store, Snowflake Data Shares
    Refresh: Dynamic Tables (1-hour TARGET_LAG) or dbt scheduled models

        ↓ sharing layer

EU Snowflake Data Share → NA Snowflake Account
  Shares: GOLD layer only (aggregated, anonymised)
  EU PII: never leaves EU account
  Mechanism: metadata pointer, no physical data movement
  What can be shared: aggregated metrics, tokenised identifiers
  What cannot be shared: raw user_id, email, payment data
```

### Cross-region architecture

```
NA Snowflake Account (primary)          EU Snowflake Account
        │                                       │
        │ ◄── Secure Data Share (GOLD only) ────┤
        │                                       │
APAC Snowflake Account                  LATAM Snowflake Account
        │                                       │
        │ ◄── Secure Data Share (GOLD only) ────┘
        │
Global Analytics (NA account)
  Queries cross-region shares via:
    SELECT * FROM EU_SHARE.GOLD.content_metrics
    UNION ALL
    SELECT * FROM APAC_SHARE.GOLD.content_metrics
  Result: global dashboard without EU/APAC PII ever leaving home region
```

### Legacy platform bridge (non-Snowflake sources)

```
BigQuery (APAC legacy)
  → scheduled export to GCS (Parquet, daily)
  → Snowflake external table on GCS
  → dbt model reads external table, writes to APAC Snowflake BRONZE
  → migrate to native Snowflake tables incrementally over 12–18 months

Redshift (EU legacy)
  → UNLOAD to S3 (Parquet, daily or CDC via DMS)
  → Snowflake external table on S3
  → dbt model reads external table, writes to EU Snowflake BRONZE
  → migrate to native Snowflake tables incrementally

External table tradeoffs:
  ✅ No big-bang migration — query in place today
  ✅ Incremental — new files auto-detected via metadata refresh
  ⚠️  Slower than native Snowflake (no micro-partition pruning on external files)
  ⚠️  No DML on external tables
  ⚠️  GCS egress costs at 10 PB scale — budget for this
  Strategy: external tables as bridge, native Snowflake tables as end state
```

### Declarative pipeline and orchestration

```
Transformation tool: dbt
  - Incremental models (append_only for events, merge for CDC)
  - Built-in lineage via dbt DAG
  - Data quality via dbt tests (not_null, unique, relationships, accepted_values)
  - CDC types:
      APPEND_ONLY          → streaming events, ad impressions
      INSERT_UPDATE_DELETE → subscriber profiles, content metadata

Snowflake native:
  - Snowflake Streams: captures DML changes on BRONZE tables for SILVER refresh
  - Dynamic Tables: incremental SQL transforms with automatic refresh
  - Zero-copy clone: dev/test environments, point-in-time audit snapshots,
                     cheap tenant isolation copies (within same account only)

Orchestration: Apache Airflow (MWAA)
  - Schedules dbt runs per region
  - Manages cross-region dependency ordering
  - Triggers backfills from Kafka retention on pipeline failure

Schema Registry: Confluent Schema Registry (per region)
  - Avro schemas for all Kafka topics
  - Compatibility mode: BACKWARD (can add optional fields safely)
  - Producers register schema → schema_id embedded in message header
  - Consumers fetch schema by id (cached after first fetch)
```

---

## Step 4 — Data governance

### PII and GDPR erasure

**Why hashing alone does not satisfy GDPR Article 17 (right to erasure):**
```
Hashing is deterministic — the hash of user_id still exists in:
  - BRONZE tables
  - SILVER tables
  - GOLD aggregations that include the user
  - Snowflake Time Travel (up to 90 days)
  - Snowflake Fail Safe (7 days after Time Travel)
  - Audit logs and query history
  - Data Shares sent to other regions

Hashing transforms PII but does not erase it.
```

**Correct solution — tokenization at ingest:**
```
Step 1: At BRONZE ingest, replace raw user_id with token_id
        Token mapping: user_id → token_id stored in Token Vault
                       (separate encrypted table, strict access control)
        All downstream tables (SILVER, GOLD, Shares) use token_id only

Step 2: GDPR erasure request received
        Delete the token_id → user_id mapping in Token Vault
        Result: token_id in all downstream tables is now orphaned
                — it maps to nothing, cannot be re-identified
                This satisfies pseudonymisation under GDPR Article 4(5)

Step 3: Time Travel cleanup
        SET DATA_RETENTION_TIME = 0 on Token Vault after erasure
        Removes historical snapshots containing the mapping

Step 4: BRONZE table purge
        Scheduled Snowpark job soft-deletes then hard-purges raw PII rows
        from BRONZE after erasure is confirmed

Step 5: Data Share update
        EU Data Share automatically excludes tokenised records
        whose token is no longer in the vault (JOIN-based exclusion)
```

**Soft delete for operational filtering (complement to tokenization):**
```sql
-- SILVER layer: add is_deleted flag
ALTER TABLE viewership_events_silver ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;

-- GOLD layer: always filter
CREATE OR REPLACE DYNAMIC TABLE content_metrics AS
SELECT * FROM viewership_events_silver
WHERE is_deleted = FALSE;

-- This handles real-time exclusion while tokenization handles GDPR compliance
```

### Dynamic Data Masking and role-based access

```sql
-- Role hierarchy
PHI_HIGH    → sees raw token_id (de-referenceable via Token Vault)
PHI_MEDIUM  → sees truncated token_id
ANALYST     → sees SHA2 hash of token_id (non-reversible)
COMPLIANCE  → sees full data for audit purposes (logged access)
DEFAULT     → sees REDACTED

-- Column masking policy on user_id
CREATE OR REPLACE MASKING POLICY user_id_mask AS (val STRING) RETURNS STRING ->
  CASE
    WHEN current_role() IN ('PHI_HIGH')    THEN val
    WHEN current_role() IN ('PHI_MEDIUM')  THEN LEFT(val, 8) || '****'
    WHEN current_role() IN ('ANALYST')     THEN SHA2(val)
    WHEN current_role() IN ('COMPLIANCE')  THEN val   -- logged via access history
    ELSE '***REDACTED***'
  END;

-- Row access policy for region isolation
CREATE OR REPLACE ROW ACCESS POLICY region_isolation AS (region_col STRING)
  RETURNS BOOLEAN ->
  CASE
    WHEN current_role() = 'EU_ANALYST'    THEN region_col = 'EU'
    WHEN current_role() = 'APAC_ANALYST'  THEN region_col = 'APAC'
    WHEN current_role() = 'GLOBAL_ADMIN'  THEN TRUE
    ELSE FALSE
  END;
```

**Role governance at scale — Okta SSO integration:**
```
Manual role assignment does not scale to 500+ analysts.
Correct pattern:
  Okta group "data-governance-approved" → maps to PHI_HIGH role in Snowflake
  Okta SSO + SCIM provisioning → roles auto-assigned on onboarding
  Access requests via ServiceNow/Jira → approval workflow → auto-provisioned
  Audit trail: who approved PHI_HIGH for which user and when
```

### Data quality framework

**Three-tier severity model:**

```
Tier 1 — LOW (single record anomaly)
  Checks: NULL on non-critical column, out-of-range buffering_ms
  Action: quarantine record to DQ_ERRORS table
          pass rest of batch through
          alert: Slack notification to data team channel

Tier 2 — MEDIUM (batch-level anomaly)
  Checks: > 1% of batch failing referential integrity
          ingestion_ts - event_ts lag > 5 minutes (replay/clock skew)
          NULL on event_id > 0.1% of batch
  Action: quarantine entire micro-batch to DQ_QUARANTINE table
          pause downstream Dynamic Tables (prevent bad data reaching GOLD)
          alert: PagerDuty to on-call data engineer

Tier 3 — HIGH (schema or systemic failure)
  Checks: event_id NULL > 5% of batch
          schema mismatch (new field, type change, missing required field)
          referential integrity failure > 10% (user_ids not in metadata)
  Action: fail pipeline entirely, reject batch
          alert: PagerDuty P1
          trigger backfill from Kafka retention (2-day window)
          rollback SILVER to last clean state via Snowflake Time Travel

Notification mechanism: SYSTEM$SEND_SNOWFLAKE_NOTIFICATION (email/SNS)
                        + Snowflake Alert objects for threshold-based triggers
```

**Three specific DQ checks for viewership events:**
```sql
-- Check 1: NULL on event_id (primary key — must never be null)
SELECT COUNT(*) FROM batch WHERE event_id IS NULL;
-- Tier 3 if > 0.1%

-- Check 2: Clock skew / late arrival check
SELECT COUNT(*) FROM batch
WHERE ABS(DATEDIFF('second', event_ts, ingestion_ts)) > 300;
-- Detects replayed events, misconfigured client clocks, or pipeline lag
-- Tier 2 if > 1% of batch

-- Check 3: Referential integrity — user_id must exist in subscriber metadata
SELECT COUNT(*) FROM batch b
LEFT JOIN subscriber_metadata s ON b.user_id = s.token_id
WHERE s.token_id IS NULL;
-- Tier 2 if > 1%, Tier 3 if > 10%
```

### Data lineage

**The GDPR auditor question:** "Show me every system that has touched this EU user's data from raw ingest to GOLD layer."

```
Two layers of lineage:

Layer 1 — Snowflake native (column-level, query-level)
  SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
    → which user queried which column at what time
  SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    → full SQL of every query executed
  Snowflake Data Lineage UI (Snowsight)
    → visual column-level lineage within Snowflake

Layer 2 — Cross-system lineage (end-to-end)
  Tool: DataHub (open source, LinkedIn) or Alation (enterprise)
  Coverage:
    Kafka topic → Flink job → S3 path → Snowflake table → dbt model → dashboard
  Integration:
    DataHub Kafka connector: captures topic schemas and producer metadata
    DataHub Snowflake connector: captures table-level and column-level lineage
    dbt integration: DataHub ingests dbt manifest.json for model lineage
  Result:
    One lineage graph from raw event source to Looker dashboard
    GDPR auditor can trace any column back to its origin system

Answering the auditor:
  "This EU user's token_id appears in:
   1. Kafka topic max.viewership.events.eu (ingested at t=...)
   2. S3 path s3://wbd-eu-bronze/viewership/... (Parquet file, partition date=...)
   3. Snowflake EU: RAW.viewership_events_raw (row inserted at t=...)
   4. Snowflake EU: STAGING.viewership_events_silver (deduped, PII tokenized)
   5. Snowflake EU: MARTS.content_metrics (aggregated, token_id not present)
   6. Data Share to NA: GOLD.content_metrics (aggregated only, no token_id)"
```

---

## Step 5 — Cost governance

### Warehouse isolation by workload type

```
PROD_DASHBOARD_WH   XS   always-on, AUTO_SUSPEND=300   → live dashboards < 5s
PROD_ANALYTICS_WH   M    AUTO_SUSPEND=60               → analyst ad-hoc queries
PROD_ML_WH          XL   scheduled 10pm–6am only       → ML training jobs
PROD_INGEST_WH      S    AUTO_SUSPEND=60               → Snowpipe, dbt loads
PROD_COMPLIANCE_WH  S    EU-network-policy-only         → audit queries

Multi-cluster config for analytics warehouse:
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3
  SCALING_POLICY    = ECONOMY  ← prefers queuing over spinning new clusters
                                 saves cost vs STANDARD which scales immediately
```

**Why workload type not team:** a data scientist running ML training should use PROD_ML_WH, not their team's general warehouse. One runaway ML query on a shared analytics warehouse kills dashboard latency for 500 analysts.

### Resource monitors — hard credit limits

```sql
-- Monthly credit cap per warehouse group
CREATE RESOURCE MONITOR analytics_monitor
    WITH CREDIT_QUOTA = 500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75  PERCENT DO NOTIFY          -- Slack alert
        ON 90  PERCENT DO NOTIFY          -- PagerDuty alert
        ON 100 PERCENT DO SUSPEND;        -- hard stop, no exceptions

ALTER WAREHOUSE PROD_ANALYTICS_WH
    SET RESOURCE_MONITOR = analytics_monitor;

-- Runaway query protection
ALTER WAREHOUSE PROD_ANALYTICS_WH SET
    STATEMENT_TIMEOUT_IN_SECONDS = 3600,   -- kill queries > 1 hour
    STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;  -- drop queue > 5 min wait
```

### Chargeback model

```sql
-- Tag every warehouse with business unit at creation
ALTER WAREHOUSE PROD_ANALYTICS_WH SET
    TAG business_unit = 'content_analytics',
        region        = 'NA',
        team          = 'product';

-- Weekly chargeback report (queried from ACCOUNT_USAGE)
SELECT
    wh.tag_value                        AS business_unit,
    SUM(m.credits_used)                 AS credits_consumed,
    ROUND(SUM(m.credits_used) * 3.00, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY m
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES wh
    ON wh.object_name = m.warehouse_name
    AND wh.tag_name = 'business_unit'
WHERE m.start_time >= DATEADD(week, -1, CURRENT_TIMESTAMP)
GROUP BY business_unit
ORDER BY credits_consumed DESC;

Rollout:
  Month 1–3: showback only (show teams their cost, no billing)
  Month 4+:  chargeback against team budget in FinOps system
```

### ML workload isolation — scheduled windows

```
ML training jobs are the biggest cost risk:
  - XL warehouse at full utilisation for 4+ hours
  - If run during business hours → kills dashboard latency

Solution:
  PROD_ML_WH scheduled via Airflow:
    suspend at 06:00 local time → resume at 22:00 local time
    all ML training jobs submit only during 22:00–06:00 window

  Result:
    ML jobs never compete with business-hours dashboard queries
    XL warehouse only billed during active training hours
```

---

## Step 6 — Global ML training under data residency constraints

**Problem:** A NA data scientist wants to train a global churn model. Subscriber data from all three regions is needed. EU data cannot leave EU. APAC data cannot leave APAC.

**Wrong answer:** copy EU and APAC subscriber data to NA for centralised training — violates GDPR and PDPA.

**Correct answer — Federated learning:**

```
Option A: Federated learning (privacy-preserving)

  EU Snowpark/Spark (EU compute)
    trains local model on EU subscriber data
    produces model weights (gradients) — not raw data
    sends weights to NA aggregation layer

  APAC Snowpark/Spark (APAC compute)
    trains local model on APAC subscriber data
    produces model weights
    sends weights to NA aggregation layer

  NA aggregation layer
    receives weights from EU and APAC (not raw data ✅)
    aggregates via federated averaging (FedAvg algorithm)
    produces global model from aggregated weights
    distributes global model back to regional serving layers

  Why this satisfies residency:
    Raw PII never leaves EU or APAC
    Model weights are mathematical gradients — not re-identifiable
    Compute runs in-region — satisfies GDPR Article 44 (transfer restrictions)

Option B: Aggregated feature export (simpler, less private)

  Each region pre-aggregates features in-region:
    EU GOLD: churn_score, avg_session_length, content_category_pct — by cohort (not user)
    APAC GOLD: same cohort-level aggregations
    No user-level data leaves region

  NA receives cohort-level features via Data Share
  Global model trained on cohort-level features
  Less powerful than user-level model but fully compliant

WBD recommendation:
  Use Option B for first iteration (faster, lower engineering cost)
  Invest in Option A (federated learning) for user-level personalisation
  where accuracy improvement justifies the infrastructure investment
```

---

## Complete architecture summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    PER-REGION (example: EU)                     │
│                                                                 │
│  Sources → Kafka (MSK EU) → Flink → S3 EU (Iceberg Bronze)     │
│            CDC (Debezium) → Kafka Connector → Snowflake RAW     │
│            Legacy Redshift → S3 unload → External Table         │
│                                                                 │
│  Snowflake EU Business Critical Account                         │
│    RAW (Bronze)    → exact copy, append-only                    │
│    STAGING (Silver)→ dedup, tokenize PII, DQ checks, dbt        │
│    MARTS (Gold)    → aggregated, safe to share, Dynamic Tables  │
│                                                                 │
│  Governance                                                     │
│    Token Vault → GDPR erasure via token deletion               │
│    Column masking policies (PHI_HIGH/MEDIUM/ANALYST roles)      │
│    Row access policies (EU analysts see EU data only)           │
│    Resource monitors (credit caps per warehouse)                │
│    DataHub → end-to-end lineage Kafka → Snowflake → Dashboard  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Snowflake Secure Data Share
                            │ GOLD layer only (no PII)
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│               GLOBAL (NA primary account)                       │
│                                                                 │
│  Cross-region shares → global aggregated metrics               │
│  BI: Looker / Tableau                                           │
│  ML: federated training (weights only cross regions)           │
│  Operational: Redis (online features) + S3/Iceberg (offline)   │
│  Cost: warehouse tagging → chargeback per business unit        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key decisions reference card

| Decision | Correct answer | Why |
|---|---|---|
| Open table format | Apache Iceberg on S3 | Multi-engine, avoids lock-in, cost-efficient at 10 PB |
| Legacy platform bridge | External tables → incremental native migration | No big-bang migration; query in place today |
| Tenancy model | Region = tenant, separate Snowflake account per region | Hard data residency enforcement at account level |
| Cross-region data sharing | Snowflake Secure Data Share (GOLD only) | No physical data movement; PII stays in home region |
| GDPR erasure | Tokenization at ingest + Token Vault deletion | Hashing does not satisfy right to erasure |
| Role governance | Snowflake RBAC + Okta SSO SCIM | Manual assignment doesn't scale to 500+ analysts |
| Cost control | Resource monitors (hard credit caps) | Alerts alone don't prevent runaway spend |
| ML under residency | Federated learning (weights, not data) | Only approach that satisfies GDPR Article 44 |
| Data lineage | DataHub + Snowflake Access History | End-to-end lineage Kafka → dashboard for GDPR audit |
| DQ failure handling | Tiered severity (LOW/MEDIUM/HIGH) with backfill | Blanket rejection wastes good data; blanket pass propagates bad data |

---

## Critical concepts to know cold

### Snowflake-specific

```
Dynamic Tables:    declarative incremental transforms inside Snowflake
                   NOT an ingestion mechanism — transform, not ingest
                   TARGET_LAG controls refresh frequency

Snowflake Streams: captures DML changes (INSERT/UPDATE/DELETE) on tables
                   used to feed incremental dbt models in SILVER layer

Zero-copy clone:   creates metadata pointer to same data, no copy
                   use for: dev/test, audit snapshots, tenant isolation within account
                   NOT for: cross-account, cross-region, data migration

External tables:   Snowflake queries S3/GCS files without loading them
                   slower than native tables (no micro-partition pruning)
                   use as migration bridge, not permanent architecture

Resource monitors: hard credit caps on warehouses
                   SUSPEND action stops warehouse when quota hit
                   most important cost control feature in Snowflake

Data Sharing:      metadata pointer — no physical data movement
                   consumer account queries provider's storage directly
                   only works within same cloud + region (Snowflake limitation)

CLUSTER BY:        guides Snowflake micro-partition pruning
                   NOT a partition key in the Hive/BigQuery sense
                   Snowflake auto-partitions; CLUSTER BY optimises query pruning
```

### GDPR data residency

```
Article 17: right to erasure → tokenization, not hashing
Article 44: cross-border transfers → federated learning for ML
Article 4(5): pseudonymisation → tokenization satisfies this
Time Travel: DATA_RETENTION_TIME = 0 to remove historical PII snapshots
Fail Safe: 7 days after Time Travel — cannot be disabled, factor into erasure SLA
```
