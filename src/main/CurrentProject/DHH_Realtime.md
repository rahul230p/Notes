## Addendum: Near-Real-Time File-Based Processing (Snowpipe + Snowpark)

This section extends the existing DHH Core architecture to explicitly support **near-real-time, file-based processing** using Snowflake-native services. The design intentionally separates **ingestion** and **transformation** into two logical intakes to improve reliability, scalability, and operational control.

---

## 4.2 Near-Real-Time File-Based Processing Flow

### Overview

* **Intake 1 (Ingestion)**: Responsible only for landing files into Snowflake staging tables using Snowpipe.
* **Intake 2 (Transformation)**: Responsible for Snowpark-based transformations and CDC using metadata-driven orchestration.

This model ensures that file arrival, data landing, and business logic execution are fully decoupled.

---

## Intake 1: File Landing & Ingestion

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    NEAR-REAL-TIME FILE INGESTION (INTAKE 1)                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌──────────────┐                                                                 │
│   │ Source System│                                                                 │
│   │ (App / Batch │                                                                 │
│   │  Job / MFT)  │                                                                 │
│   └──────┬───────┘                                                                 │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  1. FILE UPLOAD TO S3                                                        │   │
│   │     • Files uploaded via SDKs, scheduled jobs, or managed file transfer      │   │
│   │     • Atomic uploads (PutObject or multipart)                                │   │
│   │     • Structured folder paths (source / date / dataset)                      │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  2. EXTERNAL STAGE                                                           │   │
│   │     • S3 bucket exposed to Snowflake via external stage                      │   │
│   │     • IAM role-based secure access                                           │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  3. SNOWPIPE AUTO-INGEST                                                     │   │
│   │     • Snowpipe listens to S3 event notifications (SNS/SQS)                  │   │
│   │     • Automatically COPY files into landing/staging tables                  │   │
│   │     • Handles parallelism, retries, and fault tolerance                     │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  4. FILE METADATA REGISTRATION                                               │   │
│   │     • Ingestion service captures file name, checksum, target table           │   │
│   │     • Status persisted in PostgreSQL file_info table                         │   │
│   │     • State transition: NEW → LANDED                                        │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Intake 2: Transformation & CDC Processing

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                 NEAR-REAL-TIME TRANSFORMATION (INTAKE 2)                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  1. METADATA-DRIVEN TRIGGER                                                  │   │
│   │     • Orchestrator queries PostgreSQL file_info table                        │   │
│   │     • Selects only LANDED, unprocessed files                                 │   │
│   │     • Controlled, low-frequency polling                                     │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  2. RESOLVE STAGING TABLES                                                   │   │
│   │     • Determine landing table names from metadata                            │   │
│   │     • Resolve batch_id and processing scope                                  │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  3. SNOWPARK TRANSFORMATIONS                                                 │   │
│   │     • Read incremental data from staging tables                              │   │
│   │     • Apply quality checks, lookups, masking                                 │   │
│   │     • Execute CDC engine (Type I–VI)                                         │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  4. FINALIZATION                                                             │   │
│   │     • Write to curated target tables                                         │   │
│   │     • Update file_info status: PROCESSED / FAILED                            │   │
│   │     • Enables replay without re-ingestion                                    │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Design Characteristics

| Aspect          | Description                                            |
| --------------- | ------------------------------------------------------ |
| Processing Type | Near-real-time, file-based                             |
| Latency         | Seconds to minutes                                     |
| Trigger Model   | Event-driven ingestion + metadata-driven orchestration |
| Cost Efficiency | Avoids frequent Snowflake warehouse wake-ups           |
| Reliability     | Idempotent via checksum and CDC                        |
| Scalability     | Independent scaling of ingestion and transformation    |

---

## Design Rationale

* Snowpipe is used strictly for **data landing**, not transformations
* Snowpark is used for **business logic, quality checks, and CDC**
* Metadata-driven orchestration enables **replay, auditability, and fault isolation**
* Two-intake model aligns with enterprise-grade data platform best practices

---

This extension integrates seamlessly with existing batch and API-based pipelines while providing a clear, defensible near-real-time processing model suitable for system design interviews.
