# Customer 360 & Identity Resolution

Source: https://datapathsala.com/system-design/customer-360-identity-resolution

Tags: data engineering, SQL practice, PySpark problems, Pandas practice, DSA for data engineers, data modeling, system design, interview preparation, data engineer interview

[Home](/)[System Design](/system-design)Customer 360 & Identity ResolutionAdd
Note

# Customer 360 & Identity Resolution

Complete Senior Data Engineer Interview Guide

🎙

Interviewer Asks

“Design a Customer 360 data platform for a large e-commerce company with 200
million customers. Customer identity is fragmented across six source systems:
the main e-commerce database (email + order history), a mobile app (device IDs
and app events), a loyalty program (loyalty_id and points balance), offline
retail POS systems (store loyalty card swipes), a call center CRM (phone
numbers and support tickets), and a third-party demographic enrichment
provider (email and phone matching). A single customer may appear in all six
systems with completely different identifiers and no shared primary key.
Design a batch pipeline that resolves identities across all six systems,
creates a unified golden record for each customer, handles PII compliantly
under GDPR and CCPA, and refreshes the Customer 360 profile daily. The system
must handle identity merges (two profiles that were separate turn out to be
the same person) and identity splits (one profile that was merged turns out to
be two different people) without corrupting downstream analytics.”

Expand AllCollapse All15 sections + 3 cloud implementations

How to Approach This Problem

## What Makes This Problem Uniquely Hard

Customer 360 and identity resolution is one of the most commonly asked data
engineering design questions at e-commerce, retail, and tech companies — and
one of the most commonly answered poorly. The typical wrong answer is: "match
records on email address." That is a one-line script. The hard problems are
what happen when identity matching produces incorrect results, and how you
undo them.

**Hard problem 1: Identity merges that need to be undone (splits)**
Probabilistic matching produces false positives. You will eventually merge two
profiles that belong to different people — perhaps a father and son who share
a last name and live at the same address. When a downstream analyst notices
that "Bob Smith" has both a 20-year purchase history and a college student
buying pattern, the false merge must be undone. Splitting a merged identity
means updating the golden record, re-assigning historical transactions to the
correct sub-profiles, and propagating the split to every downstream system
that cached the merged profile. This cascade is expensive and painful — most
candidates design a system that cannot perform splits.

**Hard problem 2: Which source wins for a conflicting attribute?** The CRM
says the customer's phone is +1-415-555-1234. The loyalty program says it's
+1-650-555-9876. They are both "current" records updated today. Your golden
record can only have one phone number. The survivorship rule must be explicit,
documented, and consistent — not a runtime coin flip. Candidates who say "use
the most recently updated record" will be challenged immediately: what if one
source system's updated_at column is unreliable?

**Hard problem 3: GDPR right-to-erasure through a merged identity** A customer
submits a GDPR erasure request. Their identity was merged with records from
all 6 source systems. Erasing them means: removing their PII from all 6 source
records, deleting their token vault entries (so tokens become meaningless),
removing their golden record, and propagating the deletion to every downstream
ML model, analytics table, and real-time personalization system that cached
their profile. Most candidates describe PII masking (overwrite the field with
NULL), which is not erasure — the data still exists, just unreadable.

## How to Structure Your Answer (45 min)

Phase| Time| Key Points  
---|---|---  
Scoping| 5 min| Ask about matching key availability, GDPR jurisdiction, false
positive tolerance, downstream consumers of C360  
Architecture| 8 min| Draw the 6-layer pipeline: ingest -> tokenize -> block ->
score -> graph -> golden record  
Identity resolution deep dive| 10 min| Blocking strategy, scoring algorithm,
graph connected components — make the algorithm explicit  
Survivorship rules| 8 min| Attribute-level SOR hierarchy, conflict resolution,
freshness vs authority  
GDPR erasure| 7 min| Token vault + cascade deletion pattern  
Merge/split handling| 7 min| Profile versioning, downstream notification,
rollback  
  
## Opening Move

> "Before I design anything I want to flag three hard problems. First:
> identity merges must be reversible — probabilistic matching will produce
> false positives, and I need an architecture that can split a merged identity
> and propagate the split downstream without corrupting historical analytics.
> Second: survivorship rules must be explicit — when two sources disagree on a
> customer's phone number, the system needs a documented decision hierarchy,
> not a runtime tie-breaker. Third: GDPR erasure through a merged identity is
> complex — I can't just NULL out a field if that customer's record was merged
> with records from six systems. Erasure means making the token vault entries
> meaningless, cascading deletions to all six sources, and invalidating every
> downstream cache. With that in mind, which countries are the customers in,
> and what is our false positive tolerance?"

Clarifying Questions

## High-Level Architecture

nightly CDCevent batchfull snapshotdaily exportdelta syncweekly
enrichmenttokenise PIItokenised recordscandidate pairsmatch edges (score >=
0.85)identity clustersgolden recordsC360 featuresdetokenise for golden record

E-Commerce DB

Mobile App Events

Loyalty Program

Retail POS

Call Center CRM

3rd-Party Enrichment

Ingestion & Tokenizer

![Blocking Engine](/icons/tools/spark.svg)Blocking Engine

![Match Scoring Engine](/icons/tools/spark.svg)Match Scoring Engine

Identity Graph (Neptune/Spark)

Golden Record Builder

C360 Profile Store

Analytics & ML Features

PII Token Vault

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

Envelope Estimation

Architecture Walkthrough

Component Deep Dive

Identity Resolution: Deterministic vs Probabilistic

Data Modeling

PII & GDPR Compliance

Golden Record Survivorship

Scaling to 200M Customers

Monitoring & Alerting

Failure Modes

Technology Comparison

Follow-Up Q&A

Opening Statement

## Cloud-Specific Implementation

![AWS](/icons/aws/aws.svg)AWS![Azure](/icons/azure/azure.svg)Azure![GCP](/icons/gcp/gcp.svg)GCP

### AWS — Architecture

Fivetran / customPII scanraw recordsstore token mappingstokenised recordsmatch
edges (score >= 0.85)golden recordsC360 features for analytics

6 Source Systems

![S3 Raw Zone](/icons/aws/s3.svg)S3 Raw Zone

AWS Macie (PII Detection)

Glue: PII Tokenization

Secrets Manager (Token Vault)

EMR Serverless (Spark)

Amazon Neptune (Graph)

DynamoDB (C360 Store)

Redshift (Analytics)

React Flow mini map

Press enter or space to select a node.You can then use the arrow keys to move
the node around. Press delete to remove it and escape to cancel.

Press enter or space to select an edge. You can then press delete to remove it
or escape to cancel.

## AWS Architecture

> "On AWS, I'd build around S3 for the raw PII landing zone with SSE-KMS
> encryption and Object Lock, Macie for automatic PII field discovery on new
> partitions, Glue for the HMAC tokenization job using KMS-managed data keys,
> EMR Serverless for the Spark matching engine with GraphFrames, Neptune for
> the queryable identity graph, DynamoDB for the C360 profile store at
> sub-10ms P99, and Redshift for analyst queries downstream."

### End-to-End Data Flow

    
    
    1. Fivetran or custom Glue connectors land nightly extracts in S3 raw zone
       (s3://c360-raw/source=ecomm/dt=2024-01-15/) — SSE-KMS encryption on every object
    2. S3 Event Notification -> SNS -> triggers Macie scan job on the new partition only
       (not a full bucket re-scan — Macie bills $1/GB, scan only what's new)
    3. Macie findings published to EventBridge: if unexpected PII column detected (schema drift),
       SNS alert fires to the data governance team before tokenization proceeds
    4. EventBridge rule also triggers the Glue Tokenization job (step 5 only runs if Macie found no alerts)
    5. Glue calls KMS GenerateDataKey, uses the data key in memory to HMAC-SHA256 each PII field,
       discards the data key — the plaintext salt never leaves KMS at rest
    6. Glue writes tokenized records to S3 processed zone; stores token→encrypted_PII mappings
       in the token vault (DynamoDB table with KMS-encrypted attribute)
    7. Step Functions state machine triggers EMR Serverless Spark job (blocking + scoring)
       Blocking: self-join on email_token, phone_token, name3+ZIP — produces ~1.2B candidate pairs
       Scoring: composite Jaro-Winkler + exact-token score per pair
    8. Spark writes edges with score >= 0.85 to Neptune via Gremlin bulk loader (S3 staging format)
       and writes the full edge table to S3 as Parquet for GraphFrames connected components
    9. Neptune connected components query (Gremlin) identifies identity clusters for ad-hoc lookups
       GraphFrames on EMR computes the full connected-components table for batch golden record rebuild
    10. Golden Record Builder (Glue job) reads each cluster, applies survivorship rules,
        calls the token vault to detokenize PII for the golden record, writes to DynamoDB C360 store
    11. Step Functions notifies downstream: SNS message per affected cluster_id
        Personalization API, ML feature store, and marketing CDP consume the SNS topic
    12. Nightly Glue job exports C360 profiles to Redshift Spectrum (external tables over S3 Parquet)
        for analyst queries — Redshift never stores raw PII, only tokens
    

### Why Each Component

### Raw Zone: S3 with SSE-KMS

**Why S3 for raw PII data?**

  * Effectively unlimited storage — no provisioning decisions before the pipeline runs
  * SSE-KMS (not SSE-S3): KMS gives per-object key rotation audit trail required for GDPR. Every object encryption/decryption is logged in CloudTrail with the IAM principal — you can prove which service read which file containing PII and when
  * S3 Server Access Logging: captures every GET request by any principal — required for GDPR Art. 30 (Records of Processing) audit trail
  * S3 Object Lock (WORM mode) applied after processing: prevents accidental deletion of source evidence files for the 7-year compliance retention window
  * Lifecycle policies: Standard (30 days active processing) → Infrequent Access (90 days) → Glacier Deep Archive (7-year retention) at $0.00099/GB/month

**Trade-off:** S3 is not a streaming buffer — if sources deliver via Kafka
instead of file drops, use Kinesis Data Firehose to write to S3. The sentinel-
file pattern works well for batch sources but adds latency for near-real-time
sources.

**Why SSE-KMS over SSE-S3?**

  * SSE-S3 uses a single AWS-managed key — no audit trail per object, no key rotation control
  * SSE-KMS: each object can use a different CMK (Customer Master Key), and KMS logs every GenerateDataKey and Decrypt call with the requesting IAM principal
  * For GDPR: if a data subject requests erasure, you can rotate/delete their specific KMS key to render their data unreadable — this is the "cryptographic erasure" approach for large files
  * Cost: $0.03/10K KMS API calls — negligible for a batch pipeline

### PII Detection: AWS Macie

**Why Macie before tokenization?**

  * Macie auto-discovers PII fields (EMAIL_ADDRESS, PHONE_NUMBER, NAME, CREDIT_CARD_NUMBER, PASSPORT_NUMBER) even in sources that do not document their schema — critical when the 3rd-party enrichment provider changes their file format without notice
  * Macie findings trigger an SNS alert if an unexpected PII column appears: this is schema drift with PII implications — if the POS system starts including full_name in a column that was previously anonymous store_id, tokenization must be updated before that data reaches the matching engine
  * Macie runs only on new partitions (not the full bucket) — costs $1/GB for S3 scanning; for 500MB of new data per night = $0.50/run = ~$15/month

**Trade-off: Macie vs manual regex scanning**

  * Manual regex (e.g., `re.match(r'[^@]+@[^@]+.[^@]+')`) catches known PII formats but misses undocumented fields and evolving PII patterns
  * Macie uses ML models trained on billions of documents — catches PII in non-obvious column names (e.g., a column named `user_contact_string` that contains emails)
  * Cost: Macie is $1/GB; a regex scan in Glue is essentially free but blind to unknown columns
  * Recommendation: use Macie for the raw zone scan; use the Macie findings to drive which columns the Glue tokenization job processes

### Tokenization: AWS Glue with KMS-Managed HMAC

**Why Glue for the tokenization job?**

  * The tokenization job processes 500M+ records/day — Lambda's 15-minute timeout makes it unsuitable for batch tokenization of this scale
  * Glue auto-scales DPUs based on data volume; no cluster sizing decisions
  * Glue calls KMS GenerateDataKey once per Glue job run, uses the 256-bit data key in memory to compute HMAC-SHA256 for each PII field, then discards the key — the plaintext salt never persists in Glue's storage or logs

    
    
    import hmac, hashlib, boto3, base64
    
    kms = boto3.client('kms')
    
    def get_data_key(kms_key_id: str) -> bytes:
        """Call KMS once per job run. The plaintext key stays in memory only."""
        response = kms.generate_data_key(KeyId=kms_key_id, KeySpec='AES_256')
        return response['Plaintext']  # 32 bytes; discard after job completes
    
    DATA_KEY = get_data_key(os.environ['KMS_KEY_ID'])
    
    def tokenize_pii(value: str) -> str:
        """HMAC-SHA256 with KMS-managed key. Deterministic: same input -> same token always."""
        normalised = value.lower().strip()
        return hmac.new(DATA_KEY, normalised.encode('utf-8'), hashlib.sha256).hexdigest()
    
    # In Glue PySpark:
    tokenize_udf = udf(tokenize_pii, StringType())
    tokenized_df = raw_df.withColumn('email_token', tokenize_udf(col('email')))                      .withColumn('phone_token', tokenize_udf(col('phone')))                      .drop('email', 'phone')  # raw PII removed from tokenized dataset
    

**Why deterministic HMAC (same input → same token) over random UUID?**

  * Random UUIDs require a lookup table to join records from different sources — the UUID for the same email in ecomm is different from the UUID for the same email in loyalty
  * HMAC-SHA256 produces identical tokens for identical PII values across all sources — email "[j@example.com](mailto:j@example.com)" tokenizes to the same 64-char hex string in every source, enabling direct JOIN on the token column without touching the vault

**Trade-off: Glue vs Lambda for tokenization**

  * Lambda: 15-minute timeout, 10GB memory max — can tokenize ~10M records per invocation before hitting timeout
  * Glue: no timeout, scales to 100s of DPUs — handles the full 500M-record daily batch in one job
  * Cost: Glue at $0.44/DPU-hour × 5 DPU × 15 min = $0.55/run; Lambda at 15 min × 10K concurrent invocations = complex and expensive for this scale

### Identity Graph: Amazon Neptune

**Why Neptune over a flat table + Spark JOIN for the identity graph?**

  * Gremlin traversal for connected components is O(E) in the graph — Neptune walks each edge once
  * SQL recursive CTE (WITH RECURSIVE ...) for connected components is O(V²) at scale — at 700M nodes, recursive CTEs in RDS exhaust memory before completing
  * Neptune bulk loader reads from S3 in Gremlin CSV format — the initial 700M-node load takes ~4 hours with the bulk loader vs days with single Gremlin inserts
  * Property Graph vs RDF model: choose Property Graph (Gremlin) over RDF (SPARQL) for identity resolution — the property graph model maps naturally to nodes (source records) and edges (MATCHES relationships with confidence_score property)

    
    
    # Gremlin connected-components traversal: find all records in the same cluster as crm_record_12345
    # This runs in Neptune in O(cluster_size) time — no full table scan
    g.V('crm_record_12345')  .repeat(both('MATCHES').has('confidence_score', gte(0.85)).simplePath())  .emit()  .dedup()  .project('record_id', 'source_system', 'confidence')    .by('record_id')    .by('source_system')    .by(bothE('MATCHES').values('confidence_score').max())
    

**Instance sizing:** r5.xlarge (4 vCPU, 32GB RAM) handles a 196GB graph (700M
nodes × 200B + 560M edges × 100B). Neptune stores the graph in SSD-backed
cluster storage that auto-scales — no storage provisioning needed.

**Trade-off: Neptune ($250-350/month) vs GraphX on EMR (cheaper but batch-
only)**

  * Neptune: queryable at any time, sub-10ms Gremlin traversal for individual customer lookups by the data steward dashboard and the personalization API
  * GraphX on EMR: compute connected components in batch ($30-60/month compute), but the graph is not queryable after the job completes — you get a component_id column in S3, not an interactive graph
  * Recommendation: use Neptune if the identity graph needs to be queryable for operations (data steward splits, ad-hoc investigation). Use GraphX only if all you need is a batch cluster_id assignment.

### C360 Profile Store: DynamoDB

**Why DynamoDB over RDS PostgreSQL for the C360 profile store?**

  * 200M items at <10ms P99 read latency — RDS at this scale requires manual sharding; DynamoDB handles it natively with consistent single-digit millisecond reads at any throughput
  * Partition key design: use `customer_id` (the cluster_id from the identity graph) as the partition key — uniformly distributed, avoids hot partitions
  * On-demand capacity vs provisioned: use on-demand for the daily batch write (200M profile upserts happen in a 2-hour window — provisioned capacity would require massive over-provisioning for that burst)
  * Global tables for multi-region personalization API: if the C360 profiles are read by a personalization API in eu-west-1 and us-east-1, DynamoDB Global Tables replicates within 1 second — no cross-region latency for profile reads
  * DAX (DynamoDB Accelerator): if the personalization API needs sub-millisecond reads for the top 1% of active customers, add a DAX cluster in front of DynamoDB — caches hot profiles in memory for <1ms P99

**Cost math for 200M items:**

  * Storage: 200M items × 2KB average profile = 400GB × $0.25/GB = $100/month
  * On-demand reads (100K RCU/second peak): $0.25/million RCUs → at 100K RCU/s for 1 hour peak = 360M RCUs = $90/day = $2,700/month peak — provision read capacity units for predictable traffic instead
  * Provisioned: 10K RCU/s + 5K WCU/s (nightly batch window uses on-demand auto-scaling) = ~$150-200/month

**Trade-off: DynamoDB vs Redis as C360 store**

  * Redis (ElastiCache): sub-millisecond reads, but limited by RAM — 400GB of profiles requires a very large cluster ($2,000+/month). Use Redis as a cache layer in front of DynamoDB, not as the primary store.

### Matching Engine: EMR Serverless

**Why EMR Serverless over Glue for the matching job?**

  * The blocking + scoring + connected components job needs custom Spark configuration: GraphFrames library (external JAR), executor memory tuning for the 322GB graph working set, checkpoint directory configuration
  * Glue does not support attaching arbitrary custom JARs easily — GraphFrames is not on the Glue default classpath
  * EMR Serverless supports `--conf spark.jars=s3://bucket/jars/graphframes-0.8.3.jar` and custom `spark-defaults.conf`
  * Pre-initialized worker pools: EMR Serverless can maintain warm workers, eliminating the 3-5 minute cold start for the nightly job

**Spot instance config for executors:**

    
    
    {
      "workerTypeSpecifications": {
        "DRIVER": {"instanceType": "m5.4xlarge", "bidPriceAsPercentageOfOnDemandPrice": 100},
        "EXECUTOR": {"instanceType": "r5.4xlarge", "bidPriceAsPercentageOfOnDemandPrice": 40}
      }
    }
    

**Runtime math for 1.2B candidate pairs:**

  * 1.2B pairs × 3 similarity computations each = 3.6B operations
  * At 500M operations/second on 60 r5.4xlarge vCPUs = 7.2 seconds per batch
  * With Spark overhead, shuffle, and GraphFrames connected components: ~25-35 minutes total
  * Cost: 60 vCPUs × $0.052/vCPU-hour (Spot) × 0.5 hours = ~$1.56/run

### Cost Estimate (AWS)

Service| Monthly Cost| Notes  
---|---|---  
S3 (raw + processed + audit)| $50-90| ~500GB/month new data; lifecycle to IA +
Glacier  
AWS Macie (PII scanning)| $15-20| ~500MB new data/night × $1/GB  
AWS Glue (tokenization)| $15-25| 5 DPU × 15 min × 30 runs × $0.44/DPU-hr  
EMR Serverless (matching)| $45-70| 60 vCPU Spot × 35 min × 30 runs  
Amazon Neptune (r5.xlarge)| $250-350| Identity graph; dominant non-warehouse
cost  
DynamoDB (C360 store)| $150-250| 200M items; provisioned capacity + on-demand
burst  
MWAA / Step Functions| $5-300| Step Functions ~$5; MWAA $300+ if used  
Redshift (analytics)| $700-900| dc2.large cluster for analyst queries  
**Total**| **$1,230-2,005/month**|  Neptune + Redshift dominate; consider
GraphX + Athena to cut cost  
  
### Cost Optimization

Optimization| Change| Savings  
---|---|---  
Replace Neptune with GraphFrames on S3| Use GraphX for batch connected
components; skip Neptune for ad-hoc graph queries| $250-350/month  
Replace Redshift with Athena| Parquet + partition pruning in S3; pay $5/TB
scanned vs $700/month cluster| 70-80% on analytics  
EMR Spot executors| Already in design; r5.4xlarge Spot vs on-demand| 55-65% on
matching compute  
DynamoDB provisioned + auto-scaling| Provision baseline RCU/WCU; auto-scale
only during nightly batch window| 30-40% vs pure on-demand  
Glue tokenization: increase DPUs, reduce runtime| 20 DPU × 5 min vs 5 DPU × 15
min — same cost, faster pipeline| 0 cost change, 10-min faster SLA

