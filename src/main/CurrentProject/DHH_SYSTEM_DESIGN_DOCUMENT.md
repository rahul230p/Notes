# DHH Core - Data Hub/Harmonization System Design Document

## 1. Executive Summary

**DHH (Data Hub/Harmonization)** is an enterprise-grade data integration and processing platform built by IQVIA. The system orchestrates data ingestion, transformation, quality control, and delivery across multiple sources and targets, primarily leveraging **Snowflake** as the data warehouse with **Snowpark** for distributed data processing.

### Key Capabilities
- **Batch Processing**: File-based and database-to-database data ingestion
- **Real-time/Near-Real-time Processing**: API-driven data ingestion with Akka actors
- **Change Data Capture (CDC)**: Multiple CDC patterns (SCD Type I, II, Cumulative, Incremental, Partition)
- **Data Exchange**: Bidirectional data movement with multiple delivery mechanisms
- **Multi-Cloud Support**: AWS S3, Azure ADLS, SFTP, and Snowflake native storage

---

## 2. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                               DHH Core Architecture                                   │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                          DATA SOURCES (Ingestion Layer)                          │ │
│  ├─────────────────────────────────────────────────────────────────────────────────┤ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │ │
│  │  │  SFTP   │  │  AWS S3 │  │  ADLS   │  │Snowflake│  │  APIs   │  │PostgreSQL│ │ │
│  │  │  Files  │  │  Files  │  │  Files  │  │ Source  │  │(REST/   │  │  RDBMS   │ │ │
│  │  │         │  │         │  │         │  │         │  │ FHIR)   │  │          │ │ │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  │ │
│  └───────┼───────────┼───────────┼───────────┼───────────┼───────────┼──────────┘ │
│          │           │           │           │           │           │             │
│          ▼           ▼           ▼           ▼           ▼           ▼             │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                         PROCESSING LAYER (dhh-core)                             │ │
│  ├─────────────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                                  │ │
│  │  ┌──────────────────────────┐    ┌──────────────────────────────────────────┐   │ │
│  │  │   BATCH PROCESSING       │    │    REAL-TIME / API PROCESSING            │   │ │
│  │  │   (DataIngestionSnowpark)│    │    (APIProcessor + Akka Actors)          │   │ │
│  │  │                          │    │                                          │   │ │
│  │  │  • File Reading          │    │  • Parent API Actor                      │   │ │
│  │  │  • Schema Validation     │    │  • API Response Processor                │   │ │
│  │  │  • Transformation        │    │  • HTTP Response Handler                 │   │ │
│  │  │  • Quality Check         │    │  • API Storage Actor                     │   │ │
│  │  │  • Lookup Enrichment     │    │  • Logs Handling Actor                   │   │ │
│  │  │  • CDC Load              │    │  • Supervisor Strategy                   │   │ │
│  │  └──────────────────────────┘    └──────────────────────────────────────────┘   │ │
│  │                                                                                  │ │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    COMMON PROCESSING COMPONENTS                          │   │ │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │   │ │
│  │  │  │  CDC     │ │ Quality  │ │ Lookup   │ │ Scoring  │ │ Variable     │   │   │ │
│  │  │  │  Engine  │ │ Control  │ │ Engine   │ │ Engine   │ │ Mapping      │   │   │ │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │   │ │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────────────┐   │   │ │
│  │  │  │ Derived  │ │ Data     │ │ View     │ │ Measure Builder          │   │   │ │
│  │  │  │Variables │ │ Linkage  │ │Generator │ │ (Benchmark Calculation)  │   │   │ │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────────────────────┘   │   │ │
│  │  └──────────────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                             │
│                                         ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              TARGET / STORAGE LAYER                             │ │
│  ├─────────────────────────────────────────────────────────────────────────────────┤ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────┐  │ │
│  │  │  Snowflake  │  │   History   │  │   Archive   │  │    Data Exchange      │  │ │
│  │  │  (Default)  │  │   Schema    │  │   Schema    │  │    (Generation +      │  │ │
│  │  │             │  │   (_hist)   │  │  (snapshot) │  │     Delivery)         │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           METADATA & ORCHESTRATION                              │ │
│  ├─────────────────────────────────────────────────────────────────────────────────┤ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────┐  │ │
│  │  │  PostgreSQL │  │   Logging   │  │   Email     │  │   Pipeline State      │  │ │
│  │  │  Metadata   │  │   (V2)      │  │ Notification│  │   Management          │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Components Deep Dive

### 3.1 Data Ingestion Layer (`DataIngestionSnowPark`)

The main entry point for batch data processing located in `DataIngestionSnowpark.scala`.

#### Pipeline Flow

```
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│   Payload     │───▶│   Session     │───▶│   Extract     │───▶│  Transform    │
│   (JSON)      │    │   Creation    │    │   Data        │    │   & Load      │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
                                                                        │
                                                                        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│   Notify &    │◀───│   Update      │◀───│   CDC Write   │◀───│   Quality     │
│   Complete    │    │   Status      │    │   to Target   │    │   Check       │
└───────────────┘    └───────────────┘    └───────────────┘    └───────────────┘
```

#### Key Features

| Feature | Description |
|---------|-------------|
| **Continuous Run Mode** | Supports long-running processes with configurable `max_duration_minutes` |
| **Retry Mechanism** | Configurable `max_retries` and `retry_delay_milli` for resilience |
| **Cost Optimization** | `cost_optimised_runner` mode to skip processing when no data exists |
| **Pipeline State Control** | Supports Stopped, Suspended, and In-Progress states |
| **Instance Tracking** | MD5 hash-based instance tracking for concurrent execution |

#### Supported Source Types

```scala
source_type match {
  case "snowflake_source"  => // Snowflake to Snowflake processing
  case "file_upload"       => // Internal file upload system
  case "sftp"              => // SFTP file sources
  case "adls"              => // Azure Data Lake Storage
  case "aws_s3"            => // Amazon S3
  case "rdbms"             => // PostgreSQL/Oracle via JDBC
  case "api"               => // REST API sources
}
```

---

### 3.2 File Reading Layer (`FileReader`)

Handles multiple file formats with format-specific processing:

#### Supported File Formats

| Format | Handler | Special Features |
|--------|---------|------------------|
| CSV | `process_stream_as_csv` | Custom delimiters, quoting, encoding |
| Excel (XLS/XLSX) | `convertxls` | Sheet selection, formula evaluation |
| JSON | `json_to_df` | JSON splitting, nested parsing |
| XML | `parse_xml` | XSD validation, XML splitting |
| Parquet | Native Snowpark | Schema inference |
| TXT | Custom parsers | Key-pair, fixed-length, delimited |
| DEF | Custom parser | Custom list and def file types |
| SAS | `process_stream_as_sas` | SAS7BDAT format |
| NDJSON | `process_stream_as_ndjson` | Newline-delimited JSON |
| FHIR Bundle | FHIR parser | Healthcare FHIR R4 bundles |

#### File Processing Pipeline

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Get File    │───▶│  Decrypt     │───▶│  Validate    │───▶│  Convert to  │
│  Stream      │    │  (if PGP)    │    │  (XSD/Schema)│    │  DataFrame   │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

---

### 3.3 Change Data Capture (CDC) Engine (`CDCLoad` + `CDCUtils`)

The CDC engine is the heart of data persistence, supporting multiple patterns:

#### CDC Types Overview

| CDC Type | Pattern | Use Case |
|----------|---------|----------|
| **CDC_TYPE_I** | Cumulative Load | Full dataset sync with hard/soft delete tracking |
| **CDC_TYPE_II** | Incremental Load | Delta-only changes, no delete detection |
| **CDC_TYPE_III** | SCD Type 1 | Overwrite existing dimension values |
| **CDC_TYPE_IV** | SCD Type 2 | Historical tracking with effective dating |
| **CDC_TYPE_V** | Partition Overwrite | Replace data by partition key |
| **CDC_TYPE_VI** | Partial Incremental | Incremental within partitions |
| **overwrite** | Full Replace | Complete table replacement |
| **append** | Append Only | Simple insert without merge |

#### CDC Processing Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         CDC PROCESSING FLOW                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐                                                         │
│  │ Source DF   │                                                         │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              Add Hash Columns (if not exists)                    │    │
│  │  • cdc_pk_hash = SHA256(primary_key_columns)                    │    │
│  │  • cdc_row_hash = SHA256(all_non_excluded_columns)              │    │
│  │  • dhh_pk_hash, dhh_row_hash (lowercase versions)               │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              Add Audit/Tracking Columns                          │    │
│  │  • dhh_cdt (created datetime)                                   │    │
│  │  • dhh_udt (updated datetime)                                   │    │
│  │  • dhh_batch_id                                                 │    │
│  │  • dhh_del_flg (soft delete flag)                               │    │
│  │  • dhh_prcs_flg (process flag: A/I/D)                           │    │
│  │  • dhh_cby, dhh_uby (created/updated by)                        │    │
│  │  • dhh_timezone, dhh_last_sync_date                             │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    CDC Write Operation                           │    │
│  │                                                                  │    │
│  │  ┌────────────────────┐  ┌────────────────────────────────────┐ │    │
│  │  │ Table Exists?      │  │ Schema Validation                  │ │    │
│  │  │ └─ YES: MERGE      │  │ └─ Match: Continue                 │ │    │
│  │  │ └─ NO: CREATE      │  │ └─ Mismatch + Overwrite: Recreate  │ │    │
│  │  │                    │  │ └─ Mismatch: ERROR                 │ │    │
│  │  └────────────────────┘  └────────────────────────────────────┘ │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │              Write to Target Tables                              │    │
│  │  • Default Schema: main table (MERGE with pk_hash)              │    │
│  │  • History Schema: _hist table (INSERT if row_hash not exists)  │    │
│  │  • Archive Schema: snapshots and backups                        │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

#### Hard Delete Detection (Cumulative Load)

```sql
-- Hard deletes are identified by:
-- Records in TARGET but NOT in SOURCE (left anti-join on pk_hash)

merge into {target_table} tgt 
using {staging_hard_deletes} src 
on (tgt.cdc_pk_hash = src.cdc_pk_hash) 
when matched and tgt.cdc_row_hash != src.cdc_row_hash 
then update set dhh_del_flg = '1', dhh_prcs_flg = 'd', dhh_udt = {timestamp}
```

#### Threshold Validation

```scala
// Prevents accidental mass deletes
val count_match_percent = (hard_deletes_count / target_count) * 100
if (count_match_percent >= dhh_del_threshold) {
  throw new Exception("Threshold validation failed - more than expected hard deletes found")
}
```

---

### 3.4 Real-Time API Processing (`APIProcessor` + Akka Actors)

The real-time processing layer uses **Akka Actor System** for concurrent API processing.

#### Actor Hierarchy

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        AKKA ACTOR HIERARCHY                                │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│                    ┌─────────────────────────┐                             │
│                    │    ActorSystem          │                             │
│                    │   (implicit system)     │                             │
│                    └───────────┬─────────────┘                             │
│                                │                                           │
│        ┌───────────────────────┼───────────────────────┐                   │
│        │                       │                       │                   │
│        ▼                       ▼                       ▼                   │
│  ┌──────────────┐    ┌──────────────────┐    ┌────────────────────┐       │
│  │ApiStorage    │    │ParentApiProcess  │    │HttpResponseProcess │       │
│  │Actor         │    │Actor             │    │ActorManager        │       │
│  │              │    │                  │    │                    │       │
│  │• Store API   │    │• Flatten APIs    │    │• Store to SF       │       │
│  │  details     │    │• Process chunks  │    │• Coordinate writes │       │
│  │• Track status│    │• Execute queries │    │                    │       │
│  │• Clear cache │    │                  │    │                    │       │
│  └──────────────┘    └────────┬─────────┘    └────────────────────┘       │
│                               │                                            │
│                    ┌──────────┴──────────┐                                 │
│                    │                     │                                 │
│                    ▼                     ▼                                 │
│          ┌──────────────────┐   ┌──────────────────────┐                  │
│          │APIResponseProcess│   │LogsHandlingActor     │                  │
│          │Actor (Pool)      │   │                      │                  │
│          │                  │   │• Track API logs      │                  │
│          │• Process HTTP    │   │• Store execution     │                  │
│          │  responses       │   │  metadata            │                  │
│          │• R4 conversion   │   │                      │                  │
│          │• De-identification│  │                      │                  │
│          └──────────────────┘   └──────────────────────┘                  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### API Processing Types

| Execution Type | Description |
|----------------|-------------|
| `ecrf_fhir_resource_load_api` | ECRF FHIR resource loading with pagination |
| `gcp_fhir_resource_load_api` | Google Cloud FHIR store integration |
| `oneup_fhir_resource_load_api` | OneUp Health FHIR API |
| `hapi_fhir_resource_load_api` | HAPI FHIR server integration |
| `symedical_catalog_term_load` | Symedical terminology services |
| `loinc_data_load` | LOINC code loading |
| `web_based` | Generic web API calls |

#### Parallel Processing Strategy

```scala
// APIs are processed with configurable parallelism
parallel_jobs     // Number of concurrent parent API calls (default: 1)
sf_api_parallelism // Snowflake write parallelism (default: 10)
no_of_executions  // Execution query result parallelism

// Using Akka Streams for backpressure-aware processing
Source(apiDetails)
  .takeWhile(_ => check_process(...))  // Pipeline state check
  .mapAsync(parallelism) { api => ... }
  .runWith(Sink.fold(...))
```

---

### 3.5 Data Exchange Layer (`DataExchangeSnowpark`)

Handles outbound data movement with generation and delivery phases.

#### Exchange Flow

```
┌───────────────────────────────────────────────────────────────────────────┐
│                       DATA EXCHANGE FLOW                                  │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                      GENERATION PHASE                                │ │
│  │                                                                      │ │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │ │
│  │  │ Execute SQL  │───▶│ Transform    │───▶│ Create       │          │ │
│  │  │ Query        │    │ Data         │    │ Formation    │          │ │
│  │  └──────────────┘    └──────────────┘    └──────────────┘          │ │
│  │                                                                      │ │
│  │  Formation Record contains:                                          │ │
│  │  • formation_id, layout_name, exchange_name                         │ │
│  │  • status: "Formation - Created" → "Generation - Completed"         │ │
│  │  • file_path, record_count, generation_timestamp                    │ │
│  │                                                                      │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                              │                                            │
│                              ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                      DELIVERY PHASE                                  │ │
│  │                                                                      │ │
│  │  ┌────────────────────────────────────────────────────────────────┐ │ │
│  │  │              DELIVERY TARGETS                                   │ │ │
│  │  │                                                                 │ │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐ │ │ │
│  │  │  │   SFTP     │  │   AWS S3   │  │   ADLS     │  │Snowflake │ │ │ │
│  │  │  │ (deliver_  │  │ (deliver_  │  │ (deliver_  │  │(deliver_ │ │ │ │
│  │  │  │  file)     │  │  file)     │  │  file)     │  │ data_to_ │ │ │ │
│  │  │  │            │  │            │  │            │  │snowflake)│ │ │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └──────────┘ │ │ │
│  │  │                                                                 │ │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────────────────────┐│ │ │
│  │  │  │   Email    │  │   RDBMS    │  │        ZIP/PGP             ││ │ │
│  │  │  │(SendGrid/  │  │(PostgreSQL)│  │    Encryption              ││ │ │
│  │  │  │   SMTP)    │  │            │  │                            ││ │ │
│  │  │  └────────────┘  └────────────┘  └────────────────────────────┘│ │ │
│  │  └────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                      │ │
│  │  Status: "Delivery - In-Progress" → "Delivery - Completed"          │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

### 3.6 Transformation Processing

Each transformation goes through a standardized processing pipeline:

#### Transformation Components

| Component | Module | Description |
|-----------|--------|-------------|
| **Lookup** | `Lookup.scala` | Reference data enrichment with case-based matching |
| **Quality Control** | `QualityControl.scala` | Data validation and cleansing rules |
| **Quality Check** | `QualityCheck.scala` | Statistical data quality metrics |
| **Variable Mapping** | `VariableMapping.scala` | Column mapping and renaming |
| **Derived Variables** | `DerivedVariables.scala` | Calculated/computed columns |
| **Data Linkage** | `DataLinkage.scala` | Record matching across datasets |
| **Scoring** | `ScoringImpl.scala` | Risk/propensity scoring |
| **Grouping** | `GroupingFunctionality.scala` | Aggregation and grouping |
| **View Generator** | `ViewGenerator.scala` | Dynamic view creation |
| **Measure Builder** | `MeasureSqlGenerator.scala` | Healthcare measure calculations |
| **Content Replacement** | `ContentReplacements.scala` | Data masking and substitution |
| **Benchmark Config** | `BenchMarkConfiguration2.scala` | Performance benchmarking |

#### Transformation Configuration Structure

```json
{
  "transformations": [
    {
      "transformation_name": "transform_patient_data",
      "transformation_id": "uuid",
      "transformation_instance_id": "intake::id1::id2::id3",
      "process_order": 1,
      "dest_table_name": "patient_harmonized",
      "cdc_load_type": "CDC_TYPE_I",
      "pk_columns": ["patient_id"],
      "governance_columns": ["ssn", "dob"],
      "transformation_reader_options": {
        "lookup_list": [...],
        "quality_check": {...},
        "variable_mapping": {...},
        "derived_variables": [...],
        "scoring_config": {...}
      }
    }
  ]
}
```

---

## 4. Data Flow Patterns

### 4.1 Batch Processing Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           BATCH PROCESSING FLOW                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────┐                                                                       │
│   │ Trigger │  (Scheduler / API Call / Manual)                                      │
│   └────┬────┘                                                                       │
│        │                                                                            │
│        ▼                                                                            │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  1. INITIALIZATION                                                          │   │
│   │     • Parse JSON payload → data_config Map                                  │   │
│   │     • Create PostgreSQL connection pool (HikariCP)                          │   │
│   │     • Check pipeline state (Stopped/Suspended check)                        │   │
│   │     • Initialize Snowpark session                                           │   │
│   │     • Set JDBC_QUERY_RESULT_FORMAT='JSON'                                   │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│        │                                                                            │
│        ▼                                                                            │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  2. EXTRACTION                                                              │   │
│   │     Based on source_type:                                                   │   │
│   │     • snowflake_source → Execute SQL, transfer between Snowflake accounts   │   │
│   │     • file_upload → Read from internal storage (ADLS/S3)                    │   │
│   │     • sftp/adls/aws_s3 → Stream files from external sources                 │   │
│   │     • rdbms → PostgreSQL/Oracle JDBC connection                             │   │
│   │                                                                             │   │
│   │     File Processing:                                                        │   │
│   │     • Decrypt PGP if encrypted                                              │   │
│   │     • Validate XSD schema (XML files)                                       │   │
│   │     • Parse format (CSV/JSON/XML/Excel/Parquet)                             │   │
│   │     • Create Snowpark DataFrame                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│        │                                                                            │
│        ▼                                                                            │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  3. TRANSFORMATION (process_df → transformation_process)                    │   │
│   │     For each transformation in process_order:                               │   │
│   │                                                                             │   │
│   │     a) Pre-processing:                                                      │   │
│   │        • Execute source SQL query                                           │   │
│   │        • Add intake metadata columns (dhh_file_name, dhh_file_id, etc.)     │   │
│   │        • Apply manual metadata if configured                                │   │
│   │                                                                             │   │
│   │     b) Quality Control:                                                     │   │
│   │        • Run data quality rules                                             │   │
│   │        • Populate dhh_crit_msg, dhh_warn_msg, dhh_info_msg columns          │   │
│   │        • Filter critical errors if configured                               │   │
│   │                                                                             │   │
│   │     c) Enrichment:                                                          │   │
│   │        • Lookup enrichment (case 1, 2, 3)                                   │   │
│   │        • Variable mapping                                                   │   │
│   │        • Derived variables calculation                                      │   │
│   │        • Scoring                                                            │   │
│   │        • Data linkage                                                       │   │
│   │        • Grouping/aggregation                                               │   │
│   │                                                                             │   │
│   │     d) Post-processing:                                                     │   │
│   │        • Content replacement/masking                                        │   │
│   │        • Nullification from error columns                                   │   │
│   │        • View generation                                                    │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│        │                                                                            │
│        ▼                                                                            │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  4. LOAD (cdcDataLoad)                                                      │   │
│   │     • Add hash columns (cdc_pk_hash, cdc_row_hash)                          │   │
│   │     • Add audit columns (dhh_cdt, dhh_udt, dhh_batch_id, etc.)              │   │
│   │     • Validate primary key not null                                         │   │
│   │     • Execute CDC type specific logic                                       │   │
│   │     • Write to default_schema (MERGE/INSERT)                                │   │
│   │     • Write to history_schema (_hist table)                                 │   │
│   │     • Archive snapshots if configured                                       │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│        │                                                                            │
│        ▼                                                                            │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  5. FINALIZATION                                                            │   │
│   │     • Update PostgreSQL status (Completed/Failed)                           │   │
│   │     • Update file_info status                                               │   │
│   │     • Send email notifications                                              │   │
│   │     • Write logs to dhh_logs_v2                                             │   │
│   │     • Close sessions and connections                                        │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Real-Time API Processing Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         REAL-TIME API PROCESSING FLOW                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌──────────────┐                                                                  │
│   │ API Request  │  (JSON payload with API details)                                 │
│   └──────┬───────┘                                                                  │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  1. ACTOR INITIALIZATION                                                    │   │
│   │     • Parse ApiDetailsWithInputDetails from JSON                            │   │
│   │     • Create unique processId for actor naming                              │   │
│   │     • Spawn actor hierarchy:                                                │   │
│   │       - ApiStorageActor                                                     │   │
│   │       - ParentApiProcessActor                                               │   │
│   │       - LogsHandlingActor                                                   │   │
│   │       - APIResponseProcessActor (RoundRobinPool)                            │   │
│   │       - HttpResponseProcessActorManager                                     │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  2. API FLATTENING & PREPARATION                                            │   │
│   │     • Flatten nested API structure (parent/child relationships)             │   │
│   │     • For each API:                                                         │   │
│   │       - Set source_name_origin for tracking                                 │   │
│   │       - Resolve query variables                                             │   │
│   │       - Create cdc_pk_hash from API details                                 │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  3. SNOWFLAKE QUERY EXECUTION (for exchange pipeline)                       │   │
│   │     • Get SQL query from PostgreSQL                                         │   │
│   │     • Execute in chunks (processSfChunkWiseData)                            │   │
│   │     • LIMIT {chunk_size} OFFSET {offset}                                    │   │
│   │     • Update API details with execution_query_result                        │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  4. PARALLEL API PROCESSING                                                 │   │
│   │     Based on type_of_execution:                                             │   │
│   │                                                                             │   │
│   │     • no_query_or_execution_result:                                         │   │
│   │       → processApisParallel()                                               │   │
│   │                                                                             │   │
│   │     • execution_query_result:                                               │   │
│   │       → processApisParallel() with noOfExecutions                           │   │
│   │                                                                             │   │
│   │     • FHIR/Paginated APIs:                                                  │   │
│   │       → generateIncrementalOrpaginatedApisAndProcess()                      │   │
│   │                                                                             │   │
│   │     Using Akka Streams with backpressure:                                   │   │
│   │     Source(apis).mapAsync(parallel_jobs) { api => ... }                     │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  5. RESPONSE PROCESSING                                                     │   │
│   │     • APIResponseProcessActor handles each response                         │   │
│   │     • Apply transformations:                                                │   │
│   │       - R4 FHIR conversion                                                  │   │
│   │       - De-identification                                                   │   │
│   │       - Data masking                                                        │   │
│   │     • Store in memory map: APiDetailsKey → ApiRequestResponseDetail         │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  6. SNOWFLAKE STORAGE                                                       │   │
│   │     • HttpResponseProcessActorManager receives StoreInSF message            │   │
│   │     • Batch all API responses                                               │   │
│   │     • Write to Snowflake target tables                                      │   │
│   │     • Update status in PostgreSQL                                           │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│          │                                                                          │
│          ▼                                                                          │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │  7. CLEANUP                                                                 │   │
│   │     • Kill all process-specific actors                                      │   │
│   │     • Return web_based data if applicable                                   │   │
│   │     • Update final status (Completed/Failed)                                │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Database Schema Design

### 5.1 Target Table Structure

Every CDC-managed table includes standard audit columns:

| Column | Type | Description |
|--------|------|-------------|
| `cdc_pk_hash` | VARCHAR | SHA256 hash of primary key columns |
| `cdc_row_hash` | VARCHAR | SHA256 hash of all row data |
| `dhh_pk_hash` | VARCHAR | Lowercase version of cdc_pk_hash |
| `dhh_row_hash` | VARCHAR | Lowercase version of cdc_row_hash |
| `dhh_cdt` | TIMESTAMP | Created datetime |
| `dhh_udt` | TIMESTAMP | Updated datetime |
| `dhh_batch_id` | VARCHAR | Batch identifier |
| `dhh_del_flg` | VARCHAR(1) | Soft delete flag (0/1) |
| `dhh_prcs_flg` | VARCHAR(1) | Process flag (A=Add, I=Inactive, D=Delete) |
| `dhh_cby` | VARCHAR | Created by user |
| `dhh_uby` | VARCHAR | Updated by user |
| `dhh_timezone` | VARCHAR | Timezone of the session |
| `dhh_last_sync_date` | TIMESTAMP | Last synchronization timestamp |
| `dhh_file_name` | VARCHAR | Source file name (file ingestion) |
| `dhh_file_id` | VARCHAR | Source file ID |
| `dhh_file_row_id` | INT | Row number within file |

### 5.2 Schema Organization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SNOWFLAKE SCHEMA ORGANIZATION                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DATABASE: {client_database}                                               │
│   │                                                                         │
│   ├── default_schema (configurable)                                         │
│   │   ├── table_name           # Current/active data                        │
│   │   ├── table_name_snapshot  # Point-in-time snapshots                    │
│   │   └── staging_tables       # Temporary processing tables                │
│   │                                                                         │
│   ├── history_schema (configurable)                                         │
│   │   └── table_name_hist      # Full history (row_hash based)              │
│   │                                                                         │
│   ├── archive_schema (configurable)                                         │
│   │   ├── table_name_YYYYMMDDHHMMSS           # Table backups               │
│   │   ├── table_name_hist_snapshot            # History snapshots           │
│   │   └── table_name_snapshot                 # Overwrite snapshots         │
│   │                                                                         │
│   └── vault_schema (optional - for data linkage)                            │
│       └── linkage_tables       # Encrypted/masked data                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 PostgreSQL Metadata Tables

```sql
-- Forms table (metadata registry)
form (
  id UUID PRIMARY KEY,
  form_name VARCHAR,      -- 'pipeline', 'transformation', 'sql', 'instance_tracking', etc.
  project_id UUID
)

-- Form data (JSON-based configuration storage)
form_data (
  id UUID PRIMARY KEY,
  form_id UUID REFERENCES form(id),
  project_id UUID,
  json_string JSONB       -- Configuration stored as JSON
)

-- Key configurations stored:
-- • pipeline: Pipeline state and configuration
-- • transformation: Transformation definitions
-- • sql: Named SQL queries
-- • instance_tracking: Concurrent execution tracking
-- • file_info: File metadata and status
-- • exchange_formation: Exchange generation records
```

---

## 6. Configuration & Payload Structure

### 6.1 Main Payload Schema

```json
{
  // Identity
  "tenant_id": "string",
  "project_id": "string",
  "pipeline": "intake|exchange",
  "intake_name": "string",
  "intake_id": "string",
  "intake_id_1": "string",
  "intake_id_2": "string",
  "intake_id_3": "string",
  "batch_id": "string",
  
  // Source Configuration
  "source": {
    "source_type": "snowflake_source|file_upload|sftp|adls|aws_s3|rdbms|api",
    "source_name": "string",
    "url": "string",
    "storage_provider": "string",
    "host": "string",
    "username": "string",
    "password": "string",
    "database": "string",
    "default_schema": "string",
    "warehouse": "string",
    "role": "string",
    "private_key": "string (optional)",
    "reader_options": {
      "delimiter": ",",
      "field_enclosed_by": "\"",
      "encoding": "UTF-8",
      "skip_header": 1,
      "xsd_file_list": [],
      "sheet_name": "string (Excel)",
      "file_type": "key-pair|fixed-length|delimited",
      "continue_on_failure": "Y|N"
    }
  },
  
  // Target Configuration
  "target": {
    "host": "string",
    "username": "string",
    "password": "string",
    "database": "string",
    "default_schema": "string",
    "history_schema": "string",
    "archive_schema": "string",
    "vault_schema": "string (optional)",
    "warehouse": "string",
    "role": "string"
  },
  
  // Processing Options
  "intake_reader_options": {
    "max_retries": 3,
    "retry_delay_milli": 5000,
    "continuous_run_enabled": "Y|N",
    "max_duration_minutes": 60,
    "cost_optimised_runner": "Y|N",
    "metadata_overwrite": "Y|N"
  },
  
  // Transformations
  "transformations": [
    {
      "transformation_name": "string",
      "transformation_id": "uuid",
      "transformation_instance_id": "string",
      "process_order": 1,
      "dest_table_name": "string",
      "cdc_load_type": "CDC_TYPE_I|CDC_TYPE_II|...",
      "pk_columns": ["col1", "col2"],
      "governance_columns": ["sensitive_col"],
      "row_hash_drop_col": ["excluded_col"],
      "partition_columns": ["partition_col"],
      "threshold_percentage": "30",
      "transformation_reader_options": {...}
    }
  ],
  
  // Cloud Configuration
  "cloud_details": {
    "compute_cloud": "azure|aws",
    "cloud_region": "string",
    "container_name": "string"
  }
}
```

---

## 7. Key Design Decisions

### 7.1 Why Snowpark?

| Aspect | Benefit |
|--------|---------|
| **Push-down execution** | SQL operations execute in Snowflake, minimizing data movement |
| **DataFrame API** | Familiar Spark-like API for data manipulation |
| **Session management** | Connection pooling and session reuse |
| **Native integration** | Direct access to Snowflake stages, functions, and procedures |

### 7.2 Why Akka for Real-time?

| Aspect | Benefit |
|--------|---------|
| **Actor model** | Natural fit for concurrent API processing |
| **Supervision** | Built-in fault tolerance with supervisor strategies |
| **Backpressure** | Akka Streams for controlled throughput |
| **Location transparency** | Easy scaling to distributed systems |

### 7.3 Why PostgreSQL for Metadata?

| Aspect | Benefit |
|--------|---------|
| **JSONB support** | Flexible schema for configuration |
| **ACID transactions** | Reliable state management |
| **Concurrent access** | Row-level locking for instance tracking |
| **Query flexibility** | SQL + JSON path queries |

---

## 8. Error Handling & Resilience

### 8.1 Retry Mechanism

```scala
// Configurable retry with exponential backoff
while (retry_count <= max_retries && !exit_retry_loop) {
  try {
    // Processing logic
    exit_retry_loop = true
  } catch {
    case e: Exception =>
      retry_count += 1
      Thread.sleep(retry_delay_milli)
      // Reset sessions for fresh start
  }
}
```

### 8.2 Status Tracking

| Status | Meaning |
|--------|---------|
| `Not-Started` | Initial state |
| `In-Progress` | Currently processing |
| `Completed` | Successfully finished |
| `CompletedWithError` | Finished with non-fatal errors |
| `Failed` | Fatal error occurred |
| `Stopped` | Manually stopped |
| `Suspended` | Paused by user |
| `Cancelled` | Cancelled before completion |
| `Retrying` | In retry loop |

### 8.3 Logging Strategy

```scala
// Structured logging to dhh_logs_v2 table
write_logs_v2(
  session,
  data_config,
  log_map = Map(
    "source_details" -> source_map,
    "file_details" -> file_map,
    "process_details" -> process_map,
    "target_details" -> target_map
  ),
  level = "INFO|WARN|ERROR",
  status = "status_code",
  message = "human_readable_message",
  detailed_e_message = "stack_trace"
)
```

---

## 9. Security Features

### 9.1 Data Governance

- **Governance Columns**: Automatic SHA256 hashing + encryption for sensitive columns
- **PGP Encryption**: Support for PGP-encrypted file sources
- **Data Linkage Vault**: Separate schema for masked/encrypted linkage data

```scala
// Governance column processing
input_governance_columns.foldLeft(cdc_src_df) { (tempdf, colName) =>
  tempdf
    .withColumn(s"dhh_mask_${colName}", 
      sqlExpr(s"encrypt(TO_BINARY(HEX_ENCODE(\"$colName\")), '$client_id')"))
    .withColumn(colName, sha2(col(colName), 256))
}
```

### 9.2 Authentication

- Username/password authentication
- Private key authentication (RSA)
- Role-based access control (Snowflake RBAC)

---

## 10. Scalability Considerations

### 10.1 Horizontal Scaling

- **Actor parallelism**: Configurable `parallel_jobs` and `sf_api_parallelism`
- **Chunk processing**: Large datasets processed in configurable chunks
- **Instance isolation**: MD5-hash based instance tracking prevents conflicts

### 10.2 Resource Management

- **Connection pooling**: HikariCP for PostgreSQL
- **Session reuse**: Snowpark sessions cached within process
- **Memory management**: DataFrame caching with explicit cleanup

### 10.3 Performance Optimizations

- **Cost-optimized runner**: Skip processing when no data exists
- **Threshold validation**: Prevent accidental mass operations
- **Incremental processing**: Only process changed data (CDC)

---

## 11. Technology Stack Summary

| Layer | Technology |
|-------|------------|
| **Language** | Scala 2.12/2.13 |
| **Build** | Maven |
| **Data Processing** | Snowflake Snowpark |
| **Async/Concurrent** | Akka Actors + Akka Streams |
| **Connection Pool** | HikariCP |
| **JSON Processing** | json4s, Gson, Play JSON |
| **Cloud SDKs** | AWS SDK, Azure Storage SDK |
| **File Formats** | Apache POI (Excel), OpenCSV |
| **Security** | BouncyCastle (PGP) |
| **Logging** | SLF4J + Logback |
| **Email** | SendGrid, SMTP |

---

## 12. Interview Discussion Points

### Key Talking Points

1. **Why this architecture?**
   - Snowpark provides server-side execution without data movement
   - Actor model handles concurrent API calls with built-in fault tolerance
   - Metadata-driven configuration allows runtime flexibility

2. **How do you handle failures?**
   - Retry mechanism with configurable attempts and delays
   - Transaction isolation using hash-based instance tracking
   - Comprehensive logging and status tracking in PostgreSQL

3. **How does CDC work?**
   - Hash-based change detection (pk_hash for identity, row_hash for changes)
   - Multiple patterns for different use cases (cumulative, incremental, SCD)
   - History preservation for audit and compliance

4. **How do you ensure data quality?**
   - Schema validation before processing
   - Quality control rules with categorized messages (critical/warn/info)
   - Threshold validation prevents mass data corruption

5. **How do you handle scale?**
   - Chunk-based processing for large datasets
   - Parallel actor execution for API calls
   - Connection pooling and session reuse

---

## 13. Glossary

| Term | Definition |
|------|------------|
| **CDC** | Change Data Capture - tracking data changes |
| **DHH** | Data Hub/Harmonization |
| **SCD** | Slowly Changing Dimension |
| **FHIR** | Fast Healthcare Interoperability Resources |
| **PK** | Primary Key |
| **Snowpark** | Snowflake's DataFrame API |
| **Formation** | Exchange generation output record |
| **Intake** | Data ingestion pipeline |
| **Exchange** | Data delivery pipeline |
| **Transformation** | Data processing step within a pipeline |

---

*Document Version: 1.0*  
*Last Updated: February 2026*  
*Author: Generated from dhh-core codebase analysis*
