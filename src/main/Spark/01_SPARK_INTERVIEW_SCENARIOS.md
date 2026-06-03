# Spark Interview Questions - Scenario Based

## Table of Contents
1. [Scenario 1: Real-time Data Processing Pipeline](#scenario-1-real-time-data-processing-pipeline)
2. [Scenario 2: Large-scale ETL with Performance Issues](#scenario-2-large-scale-etl-with-performance-issues)
3. [Scenario 3: Streaming Data Aggregation](#scenario-3-streaming-data-aggregation)
4. [Scenario 4: Data Quality and Schema Evolution](#scenario-4-data-quality-and-schema-evolution)
5. [Scenario 5: Cost Optimization in Spark Clusters](#scenario-5-cost-optimization-in-spark-clusters)

---

## Scenario 1: Real-time Data Processing Pipeline

### Context
You are building a real-time data processing pipeline for an e-commerce platform that processes 10M events per day. Events include:
- User clicks
- Product views
- Add to cart
- Purchases
- Page load times

### Questions & Solutions

#### Q1.1: How would you design a Spark Streaming application to process these events?

**Answer:**
```scala
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._

val spark = SparkSession.builder()
  .appName("ECommerceEventProcessing")
  .config("spark.sql.streaming.schemaInference", "true")
  .getOrCreate()

// Define schema
val eventSchema = StructType(Seq(
  StructField("eventId", StringType),
  StructField("eventType", StringType),
  StructField("userId", StringType),
  StructField("productId", StringType),
  StructField("timestamp", LongType),
  StructField("value", DoubleType)
))

// Read from Kafka
val eventsDF = spark
  .readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "localhost:9092")
  .option("subscribe", "events")
  .option("startingOffsets", "latest")
  .load()

// Parse JSON
val parsedEvents = eventsDF
  .select(from_json(col("value").cast("string"), eventSchema).alias("data"))
  .select("data.*")

// Aggregate: events per minute per event type
val aggregated = parsedEvents
  .withWatermark("timestamp", "10 minutes")
  .groupBy(
    window(from_unixtime(col("timestamp") / 1000), "1 minute"),
    col("eventType")
  )
  .agg(
    count("*").alias("event_count"),
    avg("value").alias("avg_value"),
    collect_list("userId").alias("unique_users")
  )

// Write to console
val query = aggregated
  .writeStream
  .option("checkpointLocation", "/tmp/checkpoint")
  .outputMode("update")
  .option("truncate", "false")
  .format("console")
  .start()

query.awaitTermination()
```

**Key Concepts:**
- Watermarking for late data handling
- Micro-batch processing (default)
- Event time processing
- Output modes (append, update, complete)

---

#### Q1.2: How would you handle late-arriving data and duplicates?

**Answer:**

```scala
// Handle late data with watermarking
val withWatermark = parsedEvents
  .withWatermark("timestamp", "30 minutes")  // Allow 30 min late data
  .groupBy(
    window(from_unixtime(col("timestamp") / 1000), "5 minutes"),
    col("eventType")
  )
  .agg(count("*").alias("count"))

// Handle duplicates using deduplication
val deduplicated = parsedEvents
  .dropDuplicates(Seq("eventId"))  // Drop exact duplicates
  
// Or handle using window with deduplication
val deduplicatedWithWindow = parsedEvents
  .dropDuplicates(Seq("eventId"))  // Remove within batch
  .withWatermark("timestamp", "30 minutes")
  .groupBy(
    window(from_unixtime(col("timestamp") / 1000), "5 minutes"),
    col("eventType")
  )
  .count()

// Advanced: Stateful deduplication
def dedupWithState(eventsDF: DataFrame): DataFrame = {
  eventsDF
    .groupBy(col("eventId"))
    .agg(first(struct("*")).alias("event"))
    .select("event.*")
}
```

**Watermarking Diagram:**
```
Time ────────────────────────────────────────────>
     │
     ├─ Batch 1: 1000-2000ms
     ├─ Batch 2: 2000-3000ms  ◄── watermark moves
     ├─ Batch 3: 3000-4000ms
     │
     └─ Late event arrives at 3500ms (within watermark)
        Gets included in output
        
After watermark_delay (30min):
     Event timestamps < watermark are dropped
     (considered too late)
```

---

#### Q1.3: What metrics would you monitor for this pipeline?

**Answer:**

```scala
// Custom metrics tracking
val metricsDF = aggregated
  .withColumn("processing_delay_ms", 
    col("current_timestamp") - from_unixtime(col("timestamp") / 1000)
  )
  .withColumn("event_latency",
    col("processing_delay_ms") - lit(5000)  // 5s SLA
  )
  .filter(col("event_latency") > 0)  // Late events

// Monitor using structured logging
val withMetrics = aggregated
  .select(
    col("window"),
    col("eventType"),
    col("event_count"),
    col("avg_value"),
    (col("event_count").cast("double") / col("avg_value")).alias("throughput"),
    current_timestamp().alias("processing_time")
  )

// Key Metrics to Monitor:
val metrics = Map(
  "throughput" -> "events/second",
  "latency" -> "end-to-end processing time",
  "watermark_lag" -> "time behind max event timestamp",
  "batch_duration" -> "time to process each micro-batch",
  "number_output_rows" -> "rows per batch",
  "executor_memory" -> "memory utilization",
  "gc_time" -> "garbage collection pauses"
)
```

---

## Scenario 2: Large-scale ETL with Performance Issues

### Context
Your Spark job processes 100GB of raw data daily. It's currently taking 6 hours and needs to complete in 2 hours. The job:
1. Reads raw data from HDFS
2. Cleans and validates data
3. Joins with dimension tables
4. Aggregates and loads to warehouse

### Questions & Solutions

#### Q2.1: How would you identify performance bottlenecks?

**Answer:**

```scala
import org.apache.spark.sql.execution.streaming.progress.StreamingQueryProgress

// Enable detailed logging
spark.sparkContext.setLogLevel("DEBUG")

// Method 1: Using Spark UI and Event Log
spark.sparkContext.setEventLogDir("/path/to/event/logs")

// Method 2: Explicit timing
val startTime = System.currentTimeMillis()

val rawData = spark.read.parquet("/data/raw")
println(s"Read time: ${System.currentTimeMillis() - startTime}ms")

// Method 3: Explain plan analysis
rawData.explain(extended = true)

// Method 4: Query execution time tracking
def timeQuery[T](name: String)(block: => T): T = {
  val start = System.nanoTime()
  val result = block
  val duration = (System.nanoTime() - start) / 1e9
  println(s"$name took $duration seconds")
  result
}

val cleanedTime = timeQuery("Data Cleaning") {
  rawData.filter(col("id").isNotNull)
    .filter(col("amount") > 0)
}

// Method 5: Custom metrics with Accumulators
val invalidRecords = spark.sparkContext.longAccumulator("invalidRecords")

val cleaned = rawData.filter { row =>
  if (row.isNullAt(0)) {
    invalidRecords.add(1)
    false
  } else {
    true
  }
}

println(s"Invalid records: ${invalidRecords.value}")
```

**Common Bottlenecks:**
```
Bottleneck Analysis Checklist:
┌─────────────────────────────────────────┐
│ I/O Bottleneck                          │
├─────────────────────────────────────────┤
│ - Large shuffle operations               │
│ - Inefficient file format (CSV vs Parquet)
│ - Missing partitioning                   │
│ → Solution: Use Parquet, partition data  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Processing Bottleneck                   │
├─────────────────────────────────────────┤
│ - Skewed data distribution               │
│ - Inefficient joins                      │
│ - Full table scans                       │
│ → Solution: Pre-filter, use broadcast    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Memory Bottleneck                       │
├─────────────────────────────────────────┤
│ - OOM errors                             │
│ - Excessive GC pauses                    │
│ - Spilling to disk                       │
│ → Solution: Tune spark.sql.shuffle.partitions
└─────────────────────────────────────────┘
```

---

#### Q2.2: Your job has multiple joins with large dimension tables. How would you optimize?

**Answer:**

```scala
// Scenario: Fact table (1TB) joined with multiple dimension tables (100MB each)

// ❌ Bad approach: Let Spark decide
val result = factTable
  .join(dim1, "id")
  .join(dim2, "product_id")
  .join(dim3, "customer_id")

// ✅ Good approach: Broadcast small dimensions
val dim1Broadcast = broadcast(spark.read.parquet("/dim/dim1"))
val dim2Broadcast = broadcast(spark.read.parquet("/dim/dim2"))
val dim3Broadcast = broadcast(spark.read.parquet("/dim/dim3"))

val result = factTable
  .join(dim1Broadcast, "id")
  .join(dim2Broadcast, "product_id")
  .join(dim3Broadcast, "customer_id")

// Optimization: Enable broadcast hash join automatically
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "100MB")  // Default 10MB

// ✅ Better approach: Column pruning
val result = factTable
  .select("id", "product_id", "customer_id", "amount", "timestamp")
  .join(
    dim1.select("id", "category"),
    Seq("id"),
    "left"
  )
  .join(
    dim2.select("product_id", "product_name"),
    Seq("product_id"),
    "left"
  )

// Optimization: Hash join algorithm
spark.conf.set("spark.sql.join.preferSortMergeJoin", "false")

// ✅ Best approach: Pre-compute and cache
val factWithDim = factTable
  .join(broadcast(dim1), "id")
  .join(broadcast(dim2), "product_id")
  .persist(StorageLevel.MEMORY_AND_DISK)

val result1 = factWithDim.groupBy("category").count()
val result2 = factWithDim.filter(col("amount") > 1000)

factWithDim.unpersist()
```

**Join Strategy Visualization:**
```
Fact Table (1TB) ──┐
                   ├─► Broadcast Hash Join ◄─ Dimension1 (100MB)
                   │
                   ├─► Broadcast Hash Join ◄─ Dimension2 (100MB)
                   │
                   └─► Broadcast Hash Join ◄─ Dimension3 (100MB)

Result

Cost:
- Sort Merge Join: O(n log n) + network shuffle
- Broadcast Join: O(n) + broadcast overhead (small)
- Hash Join: O(n) + hash computation
```

---

#### Q2.3: How would you partition and organize the data for optimal performance?

**Answer:**

```scala
// Original data: Parquet, partitioned by date
val rawData = spark.read.parquet("/data/raw/date=2024-01-01")

// Current partition: Too fine-grained
// Partitions: 365 per year (many small files)

// Solution 1: Repartition to optimal number
val repartitioned = rawData.repartition(100)  // Fewer, larger partitions

// Solution 2: Smart partitioning based on usage patterns
val optimized = rawData
  .repartition(50, col("region"))  // Hot key partitioning
  .sortWithinPartitions("timestamp")
  .write.mode("overwrite")
  .partitionBy("region")
  .bucketBy(10, "customer_id")
  .parquet("/data/optimized")

// Solution 3: Coalesce for reducing partitions
val coalesced = rawData.coalesce(50)  // Reduce from N to 50 partitions

// Solution 4: Manual partition strategy
val result = rawData
  .withColumn("partition_key", 
    concat_ws("_", col("region"), col("date"))
  )
  .repartition(100, col("partition_key"))
  .groupBy("region", "product_category")
  .agg(
    sum("amount").alias("total_sales"),
    count("*").alias("transaction_count")
  )
  .write
  .partitionBy("region")
  .mode("overwrite")
  .parquet("/data/aggregated")

// Partition Statistics Check
val stats = rawData.rdd.partitions.length
println(s"Number of partitions: $stats")

// File size analysis
import scala.io.Source
val hdfsPath = "/data/raw"
// Check file sizes via HDFS CLI:
// hadoop fs -du -h /data/raw
```

**Partitioning Strategy Guide:**
```
Scenario 1: Time-series Data
├─ Partition by: date/hour
├─ Benefit: Efficient time-range queries
└─ Example: /data/events/date=2024-01-15/hour=10

Scenario 2: Geographic Data
├─ Partition by: region/country
├─ Benefit: Regional processing isolation
└─ Example: /data/sales/region=us/country=ca

Scenario 3: Multi-dimensional
├─ Partition by: date, region (2-level)
├─ Benefit: Balance between granularity and file count
└─ Example: /data/sales/date=2024-01-15/region=us

Rule of Thumb:
├─ Target partition size: 128MB - 256MB per partition
├─ Too many partitions: Overhead, small files problem
├─ Too few partitions: Uneven distribution, underutilization
└─ Optimal: 1-4 partitions per executor core
```

---

## Scenario 3: Streaming Data Aggregation

### Context
Real-time analytics dashboard requires minute-level aggregations of user activity across multiple dimensions. Data arrives from Kafka with slight delays and out-of-order events.

#### Q3.1: How would you implement stateful aggregation with exactly-once semantics?

**Answer:**

```scala
import org.apache.spark.sql.streaming.Trigger

// Exactly-once semantics setup
val checkpointDir = "/tmp/checkpoint"

val eventsDF = spark
  .readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "localhost:9092")
  .option("subscribe", "user_events")
  .load()

val parsedDF = eventsDF
  .select(
    from_json(col("value").cast("string"), eventSchema).alias("data")
  )
  .select("data.*")

// Time-windowed aggregation
val aggregated = parsedDF
  .withWatermark("event_timestamp", "15 minutes")
  .groupBy(
    window(col("event_timestamp"), "1 minute", "30 seconds"),
    col("user_id"),
    col("device_type")
  )
  .agg(
    count("*").alias("event_count"),
    sum("session_duration").alias("total_duration"),
    avg("page_load_time").alias("avg_load_time"),
    stddev("page_load_time").alias("stddev_load_time"),
    max("timestamp").alias("last_event_time")
  )

// Exactly-once output to sink
val query = aggregated
  .writeStream
  .format("parquet")
  .option("path", "/output/aggregations")
  .option("checkpointLocation", checkpointDir)
  .outputMode("update")  // "complete" for full view, "update" for changes
  .trigger(Trigger.ProcessingTime("10 seconds"))
  .start()

// Monitor query status
println(query.status)
println(query.recentProgress)
```

**Exactly-Once Semantics Guarantees:**
```
                    ┌──────────────────────────────┐
                    │  Spark Streaming            │
                    │  Checkpoint System          │
                    └──────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                        │
           ┌────────▼─────────┐   ┌─────────▼────────┐
           │  Offsets Tracked │   │  State Snapshots │
           │  (Kafka)         │   │  (Batch ID)      │
           └──────────────────┘   └──────────────────┘
                    │                        │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Idempotent Writes    │
                    │   (Deduplicated)       │
                    └───────────────────────┘
```

---

## Scenario 4: Data Quality and Schema Evolution

### Context
Your data pipeline processes customer data from multiple sources. Schema changes happen frequently, and data quality issues must be caught early.

#### Q4.1: How would you handle schema evolution?

**Answer:**

```scala
// Scenario: Customer schema evolves over time
// V1: id, name, email
// V2: Added phone_number
// V3: Added address (object), changed email to optional

import org.apache.spark.sql.types._

// Approach 1: Flexible schema with mergeSchema option
val evolvedDF = spark.read
  .option("mergeSchema", "true")  // Merge schemas from multiple files
  .parquet("/data/customers/*/")

// Approach 2: Explicit schema versioning
val schemaV1 = StructType(Seq(
  StructField("id", StringType),
  StructField("name", StringType),
  StructField("email", StringType)
))

val schemaV2 = StructType(Seq(
  StructField("id", StringType),
  StructField("name", StringType),
  StructField("email", StringType),
  StructField("phone_number", StringType)
))

// Helper function to evolve schema
def normalizeSchema(df: DataFrame, targetSchema: StructType): DataFrame = {
  // Add missing columns with null defaults
  var result = df
  for (field <- targetSchema.fields) {
    if (!df.columns.contains(field.name)) {
      result = result.withColumn(field.name, lit(null).cast(field.dataType))
    }
  }
  // Select and reorder to target schema
  result.select(targetSchema.fieldNames.head, targetSchema.fieldNames.tail: _*)
}

// Approach 3: Schema registry pattern (recommended)
object SchemaRegistry {
  def getLatestSchema(entity: String): StructType = {
    // Load from schema registry service
    StructType(Seq(
      StructField("id", StringType, false),
      StructField("name", StringType, true),
      StructField("email", StringType, true),
      StructField("phone_number", StringType, true),
      StructField("address", StructType(Seq(
        StructField("street", StringType),
        StructField("city", StringType)
      )), true)
    ))
  }
}

val latestSchema = SchemaRegistry.getLatestSchema("customer")
val normalizedDF = normalizeSchema(
  spark.read.parquet("/data/customers"),
  latestSchema
)

// Approach 4: Safe nested column access
val customerDF = spark.read.parquet("/data/customers")
  .select(
    col("id"),
    col("name"),
    col("email"),
    col("phone_number"),
    col("address.street"),
    col("address.city")
  )
  .na.fill("")  // Fill missing values

println(customerDF.printSchema())
```

---

#### Q4.2: How would you implement data quality checks?

**Answer:**

```scala
// Data Quality Framework
case class QualityRule(name: String, rule: DataFrame => Long)

object DataQuality {
  def validateData(df: DataFrame): Map[String, String] = {
    val results = scala.collection.mutable.Map[String, String]()
    
    // Rule 1: Check for null values
    val nullCounts = df.select(df.columns.map(c => 
      count(when(col(c).isNull, 1)).alias(s"${c}_nulls")
    ): _*).collect()(0)
    
    // Rule 2: Check for duplicates
    val duplicateCount = df.count() - df.dropDuplicates().count()
    results("duplicates") = s"Found $duplicateCount duplicate records"
    
    // Rule 3: Schema validation
    val expectedColumns = Seq("id", "name", "email", "phone_number")
    val missingColumns = expectedColumns.diff(df.columns)
    results("schema") = if (missingColumns.isEmpty) 
      "PASSED" else s"Missing columns: ${missingColumns.mkString(", ")}"
    
    // Rule 4: Data type validation
    val idIsString = df.schema("id").dataType == StringType
    results("data_types") = if (idIsString) "PASSED" else "FAILED"
    
    // Rule 5: Value range validation
    val invalidEmails = df.filter(
      !col("email").rlike("^[A-Za-z0-9+_.-]+@(.+)$")
    ).count()
    results("email_format") = s"Invalid emails: $invalidEmails"
    
    results.toMap
  }
  
  def enforceQualityGates(df: DataFrame): DataFrame = {
    df
      // Remove null IDs (critical field)
      .filter(col("id").isNotNull)
      // Remove invalid emails
      .filter(col("email").rlike("^[A-Za-z0-9+_.-]+@(.+)$"))
      // Remove duplicates by ID
      .dropDuplicates(Seq("id"))
      // Remove leading/trailing whitespace
      .withColumn("name", trim(col("name")))
      .withColumn("email", trim(col("email")))
  }
}

// Usage
val rawCustomers = spark.read.parquet("/data/raw_customers")
val qualityResults = DataQuality.validateData(rawCustomers)
println(qualityResults)

val cleanCustomers = DataQuality.enforceQualityGates(rawCustomers)
```

---

## Scenario 5: Cost Optimization in Spark Clusters

### Context
Your Spark cluster on cloud (AWS EMR / GCP Dataproc) costs $50K/month. Management wants to reduce costs by 40% without sacrificing performance.

#### Q5.1: How would you optimize cluster costs?

**Answer:**

```scala
// Cost Optimization Strategies

// 1. Right-sizing: Use smaller instance types for specific tasks
spark.conf.set("spark.driver.memory", "2g")  // Reduce from 4g
spark.conf.set("spark.executor.memory", "4g")  // Reduce from 8g
spark.conf.set("spark.executor.cores", "4")   // Reduce from 8

// 2. Dynamic allocation: Scale resources based on workload
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "10")
spark.conf.set("spark.dynamicAllocation.initialExecutors", "5")

// 3. Shuffle partitions optimization
spark.conf.set("spark.sql.shuffle.partitions", "200")  // Default 200, adjust based on data

// 4. Use spot instances for batch jobs
// AWS EMR configuration:
// {
//   "InstanceFleets": [
//     {
//       "InstanceFleetType": "CORE",
//       "TargetOnDemandCapacity": 1,
//       "TargetSpotCapacity": 4
//     }
//   ]
// }

// 5. Caching strategy
val expensiveDF = spark.read.parquet("/data/large")
expensiveDF.cache()
expensiveDF.count()  // Force materialization

// Use if accessing multiple times, remove if used once
expensiveDF.unpersist()

// 6. Incremental processing instead of full reprocessing
val today = "2024-01-15"
val newData = spark.read.parquet(s"/data/date=$today")

val previousResults = spark.read.parquet("/output/results")
val increment = newData
  .join(previousResults, Seq("id"), "left_anti")  // Only new records

val fullResults = previousResults.union(increment)

// 7. Data format optimization: CSV → Parquet → ORC
// CSV: 1GB raw file → 200MB with default compression
// Parquet: 1GB raw file → 100MB with snappy compression
// ORC: 1GB raw file → 80MB with snappy compression

val parquetSize = spark.read.csv("/data/raw.csv").write.parquet("/tmp/test.parquet")

// 8. Compression tuning
spark.conf.set("spark.sql.parquet.compression.codec", "snappy")  // Fast
// spark.conf.set("spark.sql.parquet.compression.codec", "gzip")  // Better compression

// Cost Tracking & Metrics
case class CostMetrics(
  totalExecutorCost: Double,
  driverCost: Double,
  computeTime: Double,
  costPerGB: Double
)

def trackCostMetrics(spark: SparkSession): CostMetrics = {
  val metrics = spark.sparkContext.statusTracker.executorInfos.length
  val computeTime = System.currentTimeMillis()
  
  CostMetrics(
    totalExecutorCost = metrics * 0.011,  // AWS price per executor-hour
    driverCost = 0.022,
    computeTime = computeTime,
    costPerGB = 0.011 / 1000  // per 1GB processed
  )
}
```

**Cost Optimization Comparison:**
```
Before Optimization:
├─ Instance Type: r5.4xlarge (16 vCPU, 128GB RAM)
├─ Quantity: 10 executors + 1 driver
├─ Monthly Cost: $50,000
└─ Utilization: 45% CPU, 30% Memory

After Optimization:
├─ Instance Type: r5.2xlarge (8 vCPU, 64GB RAM)
├─ Quantity: 5 executors + 1 driver (with dynamic scaling to 8)
├─ Monthly Cost: $28,000 (44% reduction)
└─ Utilization: 65% CPU, 45% Memory

Improvements:
├─ Dynamic allocation: -$8,000/month
├─ Spot instances: -$10,000/month
├─ Better compression (Parquet): -$3,000/month
├─ Optimized shuffle partitions: -1,000/month
└─ Total savings: $22,000/month (44%)
```

---

## Summary: Best Practices Checklist

```
□ Always use Parquet for storage (not CSV)
□ Partition large datasets (100GB+)
□ Use broadcast for small dimension tables (<100MB)
□ Enable dynamic allocation for variable workloads
□ Monitor checkpoint lag in streaming
□ Implement data quality checks early
□ Use accumulators for accurate metrics
□ Cache only if used multiple times
□ Tune shuffle partitions based on cluster
□ Enable event logging for debugging
□ Use columnar operations (select specific columns)
□ Avoid collect() on large datasets
□ Monitor memory and GC logs
□ Test schema evolution
□ Use spot instances for non-critical jobs
```


