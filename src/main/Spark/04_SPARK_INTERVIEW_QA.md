# Spark Interview Q&A - Most Common Questions

## Table of Contents
1. [Fundamentals](#fundamentals)
2. [Performance & Optimization](#performance--optimization)
3. [Streaming](#streaming)
4. [Data Structures](#data-structures)
5. [Real-World Problem Solving](#real-world-problem-solving)

---

## Fundamentals

### Q1: What is Spark and how is it different from Hadoop MapReduce?

**Answer:**

```
Spark vs Hadoop MapReduce:

SPARK
├─ In-memory computation (fast)
├─ Supports: Batch, Streaming, ML, Graph
├─ Lower latency (seconds)
├─ Easier to code (Scala/Python/SQL)
├─ Cache RDDs between operations
└─ 10-100x faster than MapReduce

HADOOP MAPREDUCE
├─ Disk-based computation (slow)
├─ Batch processing only
├─ High latency (minutes)
├─ Verbose code (Java)
├─ Reads/writes disk between jobs
└─ Better for fault tolerance edge cases

Key Differences:

Operation: Word Count

MapReduce (3 disk reads/writes):
Input → Map → Disk
         ↓
Disk → Shuffle → Disk
         ↓
Disk → Reduce → Output

Spark (all in memory):
Input → Map → Cache
         ↓
Cache → Reduce → Output
(1000x faster)

Data Flow:

MapReduce: Map → Shuffle (disk) → Reduce
Spark:     RDD → RDD → ... → Action
           (lazy evaluation, optimized)
```

---

### Q2: Explain lazy evaluation in Spark

**Answer:**

```scala
// Lazy evaluation: Operations not executed until action

// Transformations (lazy): Create new RDD, not computed
val rdd1 = sc.parallelize(1 to 1000)  // No computation yet
val rdd2 = rdd1.map(x => x * 2)       // Still lazy
val rdd3 = rdd2.filter(x => x > 100)  // Still lazy

// Timeline so far: 0 milliseconds of execution

// Actions (trigger computation)
val result = rdd3.count()  // NOW everything executes
// Timeline: 100ms of execution

// Benefits:
// ✓ Optimizer sees full plan (Catalyst)
// ✓ Can eliminate unnecessary operations
// ✓ Better resource utilization
// ✓ Pipelining: fuse operations

// Example: Catalyst optimization with lazy evaluation
val df = spark.read.parquet("/data")    // Lazy
  .filter(col("status") == "active")    // Lazy
  .select("id", "name")                 // Lazy (column pruning)

// ✓ Spark sees we only need 2 columns
// ✓ Optimizer pushes SELECT before FILTER
// ✓ Reads only needed columns from disk

// Without lazy evaluation:
// Would read all columns → filter → select
// (Wasted I/O on unused columns)

// Forcing computation for testing
val df = spark.read.parquet("/data")
val rdd = df.rdd  // Converts to RDD
val cached = df.cache()  // Still lazy
cached.count()  // Now computed
```

---

### Q3: What's the difference between persist() and cache()?

**Answer:**

```scala
// cache() is shorthand for persist(StorageLevel.MEMORY_ONLY)

// Equivalent:
rdd.cache()
rdd.persist(StorageLevel.MEMORY_ONLY)  // Same thing

// persist() has more options
rdd.persist(StorageLevel.MEMORY_ONLY)           // Memory only
rdd.persist(StorageLevel.MEMORY_AND_DISK)       // Memory + disk
rdd.persist(StorageLevel.MEMORY_ONLY_SER)       // Memory serialized
rdd.persist(StorageLevel.MEMORY_AND_DISK_SER)   // Memory + disk serialized
rdd.persist(StorageLevel.DISK_ONLY)             // Disk only
rdd.persist(StorageLevel.NONE)                  // Remove from cache

// Removing from cache
rdd.unpersist()  // Default: blocking = false
rdd.unpersist(blocking = true)  // Wait for removal

// When to use:
val expensive = data
  .filter(complexCondition)
  .groupBy("key")
  .cache()

val result1 = expensive.count()        // First use: compute + cache
val result2 = expensive.agg(sum("x"))  // Second use: from cache

expensive.unpersist()  // Free memory when done

// Without caching:
val result1 = expensive.count()        // Compute 100ms
val result2 = expensive.agg(sum("x"))  // Compute again 100ms
                                       // Total: 200ms

// With caching:
val result1 = expensive.count()        // Compute 100ms
val result2 = expensive.agg(sum("x"))  // From cache 2ms
                                       // Total: 102ms
```

---

### Q4: Explain RDD lineage

**Answer:**

```scala
// Lineage: DAG (Directed Acyclic Graph) of RDDs

val rdd1 = sc.parallelize(1 to 100)     // Stage 1
val rdd2 = rdd1.map(x => x * 2)         // Stage 1 (narrow)
val rdd3 = rdd2.filter(x => x > 50)     // Stage 1 (narrow)
val rdd4 = rdd3.reduceByKey(_+_)        // Stage 2 (wide - shuffle)

// Lineage visualization:
rdd1 (parallelize)
 │
 ├─→ rdd2 (map)
 │    │
 │    └─→ rdd3 (filter)
 │         │
 │         └─→ rdd4 (reduceByKey - SHUFFLE)

// Narrow dependencies: Each parent partition → One child partition
// Wide dependencies: Multiple parent partitions → One child partition

// Fault tolerance:
// If executor fails, Spark recomputes RDDs from lineage
// Example: rdd3 lost
// 1. Recompute rdd1
// 2. Recompute rdd2 from rdd1
// 3. Recompute rdd3 from rdd2

// View lineage
rdd4.toDebugString

// Output:
// (50) ShuffledRDD[3] at reduceByKey at <stdin>:13 []
//  +-(50) FilteredRDD[2] at filter at <stdin>:12 []
//     +-(50) MapPartitionsRDD[1] at map at <stdin>:11 []
//        +-(100) ParallelCollectionRDD[0] at parallelize at <stdin>:10 []

// Caching saves lineage computation
rdd3.cache()  // Keep in memory
rdd4.action()  // Faster recovery if rdd4 fails
```

---

## Performance & Optimization

### Q5: How would you handle data skew in Spark?

**Answer:**

```scala
// Data skew: Uneven partition distribution
// Impact: Some executors finish instantly, others take 10x longer

// EXAMPLE SKEW:
// Partition 0: 1M rows
// Partition 1: 1M rows
// Partition 2: 50M rows  ← Bottleneck!
// Partition 3: 1M rows

// SOLUTION 1: Salting (add random suffix)
val skewed = df.filter(col("city") == "New York")  // 50M rows

// Add random salt to distribute
val salted = skewed
  .withColumn("salt", (rand() * 10).cast("int"))
  .withColumn("city_salted", concat(col("city"), lit("_"), col("salt")))

val processed = salted
  .groupBy("city_salted")
  .agg(sum("amount"))
  .withColumn("city", regexp_replace(col("city_salted"), "_\\d+$", ""))
  .drop("salt", "city_salted")

// Now 50M rows split into 10 salted buckets (5M each)

// SOLUTION 2: Separate hot data
val hotData = df.filter(col("city") == "New York")  // 50M
val otherData = df.filter(col("city") != "New York")  // 3M

val hotProcessed = hotData
  .repartition(20, col("city"))  // More partitions
  .groupBy("city")
  .agg(sum("amount"))

val otherProcessed = otherData
  .groupBy("city")
  .agg(sum("amount"))

val result = hotProcessed.union(otherProcessed)

// SOLUTION 3: Broadcast for joins (skewed fact table)
// Fact: 100M rows, key heavily skewed
// Dim: 1M rows

// ❌ Regular join (skew preserved)
val bad = fact.join(dim, "key")

// ✅ Salted join (distribute fact skew)
val factSalted = fact
  .withColumn("salt", (rand() * 100).cast("int"))
  .withColumn("key_salted", concat(col("key"), lit("_"), col("salt")))

val dimReplicated = dim
  .join(
    spark.createDataFrame((0 until 100).map(i => (i,))).toDF("salt"),
    true  // cross join
  )
  .drop("salt")

val joined = factSalted
  .join(dimReplicated, col("key_salted.key") === col("dim.key"))

// SOLUTION 4: Use bucketing (pre-shuffle)
df.write
  .bucketBy(100, "city")  // 100 buckets
  .mode("overwrite")
  .parquet("/data/bucketed")

// Now reading bucketed data for joins is fast
val bucketed = spark.read.parquet("/data/bucketed")
bucketed.join(other, "city")  // Already bucketed on city!

// SOLUTION 5: Adaptive skew handling (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
// Spark automatically handles skew in joins
```

---

### Q6: Explain difference between narrow and wide transformations

**Answer:**

```
NARROW Transformations:
├─ One parent partition → One child partition
├─ No data movement between partitions
├─ Examples: map, filter, flatMap
└─ Fast, no shuffle required

Data flow:
Partition 1 → [map]     → Partition 1
Partition 2 → [filter]  → Partition 2
Partition 3 → [flatMap] → Partition 3


WIDE Transformations:
├─ Multiple parent partitions → One child partition
├─ Data shuffled between partitions
├─ Examples: groupByKey, reduceByKey, join, repartition
└─ Slow, requires shuffle + network I/O

Data flow:
Partition 1 \
Partition 2 --[shuffle]--[groupByKey]--[Partition 1]
Partition 3 /           [Partition 2]


Impact on Stages:
Narrow transformations: Same stage
Wide transformations: Start new stage

Example:

val rdd = sc.parallelize(1 to 100)
val narrow1 = rdd.map(x => x * 2)           // Stage 1
val narrow2 = narrow1.filter(x => x > 50)   // Stage 1
val wide = narrow2.reduceByKey(_+_)         // Stage 2 (SHUFFLE)
val narrow3 = wide.map(...)                 // Stage 2

// Only 2 stages due to 1 shuffle point
// Without shuffle: would be many stages


Implications:

1. Narrow operations are pipelined
   map(x => x*2).filter(x => x > 50)
   └─ Can combine into one operation (fused)

2. Wide operations create materialization points
   reduceByKey() must write output before next stage

3. Checkpoint strategies
   Narrow: Not critical
   Wide: Good checkpoint candidates
```

---

### Q7: How do you optimize a slow Spark job?

**Answer:**

```scala
// Step 1: IDENTIFY THE BOTTLENECK

// Enable event logging
spark.sparkContext.setEventLogDir("/path/to/logs")

// Check Spark UI (http://driver:4040)
// - Look for slow stages
// - Check task distribution (skew?)
// - Monitor memory usage

// Use explain()
df.explain(extended = true)

// Step 2: COMMON BOTTLENECKS & FIXES

// Bottleneck 1: Too many partitions
// Problem: 1M partitions = 1M tasks = overhead
val bad = df.repartition(1000000)
// Solution
val good = df.repartition(100)

// Bottleneck 2: Too few partitions
// Problem: 2 partitions with 100GB = 50GB per executor = OOM
val bad = df.coalesce(2)
// Solution
val good = df.coalesce(100)

// Bottleneck 3: Inefficient joins
val bad = largeTable.join(mediumTable)  // Both shuffled
// Solution
val good = largeTable.join(broadcast(mediumTable), "key")

// Bottleneck 4: Unnecessary shuffle
val bad = df.repartition(100).coalesce(10)  // Shuffle twice!
// Solution
val good = df.coalesce(10)  // No shuffle

// Bottleneck 5: Expensive operations in hot path
val bad = df
  .map(row => expensiveFunction(row))  // Runs N times
  .filter(condition)

// Solution
val good = df
  .filter(condition)  // Filter first
  .map(row => expensiveFunction(row))

// Bottleneck 6: Missing bucketing
// Every join shuffles
val bad = events.join(users, "user_id")

// Solution
events.write.bucketBy(100, "user_id").parquet("/events")
val bucketed = spark.read.parquet("/events")
bucketed.join(users, "user_id")  // Uses bucket info, faster!

// Step 3: OPTIMIZATION TECHNIQUES

// Technique 1: Push filters down
val bad = df1.join(df2, "id").filter(col("status") == "active")
val good = df1
  .filter(col("status") == "active")
  .join(df2, "id")

// Technique 2: Select columns early
val bad = df.join(other).select("a", "b")
val good = df.select("id", "a")
  .join(other.select("id", "b"), "id")

// Technique 3: Cache strategically
val expensive = df
  .filter(complex_condition)
  .join(another_df)
  .cache()

val result1 = expensive.count()
val result2 = expensive.groupBy(...).count()

// Technique 4: Use appropriate data format
// CSV: 1GB raw → slow parsing
// Parquet: 1GB raw → 100MB parquet → fast reads
spark.read.csv("/data.csv").write.parquet("/data.parquet")

// Technique 5: Increase parallelism
spark.conf.set("spark.sql.shuffle.partitions", "400")
// Default 200, increase if CPU underutilized

// Technique 6: Enable adaptive execution (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.enabled", "true")

// Step 4: MEASURE IMPROVEMENT
def time[T](name: String)(f: => T): T = {
  val start = System.nanoTime()
  val result = f
  println(s"$name: ${(System.nanoTime() - start) / 1e9}s")
  result
}

val optimized = time("optimized_query") {
  df.filter(...).join(...).groupBy(...).count()
}
```

---

## Streaming

### Q8: What's the difference between DStream and Structured Streaming?

**Answer:**

```
DStream vs Structured Streaming:

DStream (RDD-based):
├─ Micro-batches of RDDs (every N seconds)
├─ Low-level transformations (map, filter, etc.)
├─ Latency: 0.5-2 seconds per batch
├─ Stateful operations: updateStateByKey
└─ Limited SQL support

Structured Streaming (SQL-based):
├─ Treats stream as infinite table
├─ SQL & DataFrame API
├─ Latency: 100ms-1s (better)
├─ Stateful: window, groupBy aggregations
└─ Full SQL support + optimization


Architecture comparison:

DStream:
Batch 1 ──► RDD ──► transformations ──► Output
Batch 2 ──► RDD ──► transformations ──► Output
Batch 3 ──► RDD ──► transformations ──► Output

Structured Streaming:
Incremental table update
      │
      ├─ Add new rows
      ├─ Update state
      └─ Emit output

State management:

DStream:
├─ Explicit state: updateStateByKey
├─ Manual timeout handling
└─ Limited state info

Structured Streaming:
├─ Implicit state (watermarking)
├─ Automatic timeout
├─ Better state management
└─ Group state (advanced)


Example comparison:

DStream:
val ssc = new StreamingContext(sc, Seconds(1))
val stream = ssc.socketTextStream("localhost", 9999)

val counts = stream
  .flatMap(_.split(" "))
  .map((_, 1))
  .reduceByKey(_ + _)

counts.print()
ssc.start()

Structured Streaming:
val stream = spark
  .readStream
  .format("socket")
  .option("host", "localhost")
  .option("port", 9999)
  .load()

val words = stream.select(explode(split(col("value"), " ")))
val counts = words
  .groupBy("value")
  .count()

counts.writeStream
  .format("console")
  .start()

Recommendation:
✓ Use Structured Streaming for new code
✗ DStream is deprecated (legacy)
✓ Better performance
✓ Better fault tolerance
✓ Easier to reason about
```

---

### Q9: How do you handle late data in Structured Streaming?

**Answer:**

```scala
import org.apache.spark.sql.functions._

val events = spark
  .readStream
  .format("kafka")
  .load()

// Parse events with timestamp
val parsed = events
  .select(
    from_json(col("value").cast("string"), schema).alias("data")
  )
  .select("data.*", col("data.timestamp").alias("event_time"))

// WITHOUT watermarking: Keeps state forever
val bad = parsed
  .groupBy(col("event_time"))
  .count()

// WITH watermarking: Drops late data after threshold
val good = parsed
  .withWatermark("event_time", "10 minutes")  // Allow 10 min lateness
  .groupBy(
    window(col("event_time"), "1 minute"),
    col("user_id")
  )
  .agg(count("*"))

// Watermark behavior:

Timeline:
10:00 ├─ Watermark at 10:00
      │  Late data threshold: 10:00 - 10 min = 9:50
10:10 ├─ Watermark at 10:10
      │  Late data threshold: 10:10 - 10 min = 10:00
10:20 ├─ Watermark at 10:20
      │  Late data threshold: 10:20 - 10 min = 10:10

Event arrives at 10:20 with timestamp 10:05:
├─ Check: 10:05 > 10:10? NO
├─ Event is too late (more than 10 min)
└─ Dropped (not processed)

Event arrives at 10:20 with timestamp 10:15:
├─ Check: 10:15 > 10:10? YES
├─ Event is within watermark
└─ Included in processing


Output modes with watermarking:

Append mode (default):
├─ Only final results written to sink
├─ Once watermark passes, result is finalized
├─ Example: minute 1 → watermark passes at minute 11
├─ Then minute 1 result is written (final)
└─ Use for: Data warehouses (immutable writes)

Update mode:
├─ Updated rows sent each micro-batch
├─ Example: minute 1 aggregation updates multiple times
├─ Then finalized once watermark passes
└─ Use for: Real-time dashboards (overwrites)

Complete mode:
├─ All rows (old + new) sent each micro-batch
├─ Only for stateless queries
├─ Memory intensive
└─ Avoid: Uses unbounded memory


Tuning watermark:

Short watermark (1 minute):
├─ Drops late data quickly
├─ Lower memory (fewer incomplete groups)
├─ Risk: Loses legitimate late data
└─ Use for: High-throughput, low-error-tolerance

Long watermark (1 hour):
├─ Keeps state longer
├─ Higher memory (many incomplete groups)
├─ Better accuracy (fewer drops)
└─ Use for: Low-throughput, high-accuracy needs


Code example with multiple scenarios:

val events = parsed
  .withWatermark("event_time", "30 minutes")
  .groupBy(
    window(col("event_time"), "5 minute", "1 minute"),  // Tumbling window
    col("user_id")
  )
  .agg(
    count("*").alias("events"),
    sum("amount").alias("total"),
    max("event_time").alias("last_event")
  )
  .select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    col("user_id"),
    col("events"),
    col("total")
  )

events.writeStream
  .format("parquet")
  .option("path", "/output")
  .option("checkpointLocation", "/checkpoint")
  .outputMode("append")  // Only finalized windows
  .start()
```

---

## Data Structures

### Q10: When would you use RDD vs DataFrame vs Dataset?

**Answer:**

```scala
// RDD (Resilient Distributed Dataset)
// ✓ Use when: Unstructured data, complex logic
// ✗ Avoid: Structured/tabular data

val textRDD = sc.textFile("/logs")
val parsed = textRDD
  .map(line => CustomParser.parse(line))
  .filter(_.isValid)
  .map(obj => (obj.key, obj.value))
  .reduceByKey(_ + _)

// DataFrame
// ✓ Use when: Structured data, need SQL, want optimization
// ✗ Avoid: Complex custom logic, type safety needed

val events = spark.read.parquet("/events")
val result = events
  .filter(col("amount") > 100)
  .groupBy("user_id")
  .agg(sum("amount"), count("*"))
  .filter(col("count(1)") > 10)

// Dataset (Scala/Java only)
// ✓ Use when: Need type safety + performance
// ✗ Avoid: Python (not available), overkill for simple queries

case class Event(user_id: String, amount: Double, timestamp: Long)

val events = spark.read.parquet("/events").as[Event]
val highValue = events
  .filter(_.amount > 100)
  .groupByKey(_.user_id)
  .mapGroups { case (userId, events) =>
    (userId, events.map(_.amount).sum)
  }

// Comparison table:

                  │ RDD     │ DataFrame │ Dataset
──────────────────┼─────────┼───────────┼─────────
Type Safety       │ None    │ Partial   │ Full
Optimization      │ None    │ Yes       │ Yes
SQL Support       │ No      │ Yes       │ No
Performance       │ Slow    │ Fast      │ Fast
Language          │ All     │ All       │ Scala/Java
Memory Usage      │ High    │ Low       │ Low
Serialization     │ Java    │ Spark SQL │ Encoder

// Performance ranking (on 1TB dataset):
// RDD: 100 seconds
// DataFrame: 10 seconds
// Dataset: 12 seconds
```

---

## Real-World Problem Solving

### Q11: Design a real-time dashboard that shows user activity by location

**Answer:**

```scala
// Requirements:
// 1. Real-time updates (< 1 sec latency)
// 2. Aggregate by location (100+ cities)
// 3. Show top 10 locations
// 4. Update every 10 seconds
// 5. Handle late data (up to 5 minutes)

import org.apache.spark.sql.functions._

// Step 1: Read stream
val events = spark
  .readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "localhost:9092")
  .option("subscribe", "user_events")
  .load()

// Step 2: Parse and extract timestamp
val parsed = events
  .select(from_json(col("value").cast("string"), eventSchema).alias("data"))
  .select("data.*")
  .select(
    col("user_id"),
    col("location"),
    col("event_type"),
    from_unixtime(col("timestamp") / 1000).cast("timestamp").alias("event_time"),
    current_timestamp().alias("processing_time")
  )

// Step 3: Apply watermark for late data
val withWatermark = parsed
  .withWatermark("event_time", "5 minutes")

// Step 4: Aggregate by location (tumbling window)
val locationStats = withWatermark
  .groupBy(
    window(col("event_time"), "10 seconds"),  // 10-sec windows
    col("location")
  )
  .agg(
    count("*").alias("event_count"),
    count(distinct("user_id")).alias("unique_users"),
    collect_set("event_type").alias("event_types")
  )

// Step 5: Get top 10 locations (using dense_rank)
val top10 = locationStats
  .withColumn("rank", 
    row_number()
      .over(
        Window
          .partitionBy(col("window"))
          .orderBy(col("event_count").desc)
      )
  )
  .filter(col("rank") <= 10)
  .select(
    col("window.start").alias("window_time"),
    col("location"),
    col("event_count"),
    col("unique_users"),
    col("rank")
  )

// Step 6: Output to multiple sinks

// Sink 1: Console (for debugging)
val consoleQuery = top10
  .writeStream
  .format("console")
  .option("truncate", "false")
  .outputMode("update")
  .option("numRows", 20)
  .start()

// Sink 2: Parquet (for history)
val parquetQuery = top10
  .writeStream
  .format("parquet")
  .option("path", "/data/location_stats")
  .option("checkpointLocation", "/checkpoint/location_stats")
  .outputMode("append")
  .partitionBy("window_time")
  .start()

// Sink 3: Database (for dashboard)
val dbQuery = top10
  .writeStream
  .foreachBatch { (batchDF, batchId) =>
    batchDF.write
      .format("jdbc")
      .option("url", "jdbc:postgresql://localhost/dashboard")
      .option("dbtable", "location_stats")
      .option("user", "username")
      .option("password", "password")
      .mode("append")
      .save()
  }
  .option("checkpointLocation", "/checkpoint/location_db")
  .start()

// Step 7: Monitor
consoleQuery.awaitTermination()
```

---

### Q12: Design a recommendation engine using Spark MLlib

**Answer:**

```scala
// Recommendation Engine: User-based collaborative filtering

import org.apache.spark.ml.recommendation.ALS
import org.apache.spark.ml.feature.StringIndexer
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.evaluation.RegressionEvaluator

// Step 1: Load data (user-item interactions)
val ratings = spark.read
  .format("csv")
  .option("header", "true")
  .option("inferSchema", "true")
  .load("ratings.csv")  // userId, itemId, rating, timestamp

// Step 2: Prepare data (convert string IDs to numeric)
val userIndexer = new StringIndexer()
  .setInputCol("userId")
  .setOutputCol("userIdx")

val itemIndexer = new StringIndexer()
  .setInputCol("itemId")
  .setOutputCol("itemIdx")

val pipeline = new Pipeline()
  .setStages(Array(userIndexer, itemIndexer))

val indexed = pipeline.fit(ratings).transform(ratings)

// Step 3: Train/test split
val Array(trainData, testData) = indexed.randomSplit(Array(0.8, 0.2))

// Step 4: Train ALS model (Alternating Least Squares)
val als = new ALS()
  .setUserCol("userIdx")
  .setItemCol("itemIdx")
  .setRatingCol("rating")
  .setMaxIter(10)
  .setRegParam(0.1)
  .setRank(10)  // Latent factor dimension
  .setColdStartStrategy("drop")  // Handle cold start users

val model = als.fit(trainData)

// Step 5: Evaluate
val predictions = model.transform(testData)

val evaluator = new RegressionEvaluator()
  .setMetricName("rmse")
  .setLabelCol("rating")
  .setPredictionCol("prediction")

val rmse = evaluator.evaluate(predictions)
println(s"RMSE: $rmse")

// Step 6: Generate recommendations

// For specific user (top 10 items)
val userRecs = model.recommendForAllUsers(10)

val specificUser = userRecs
  .filter(col("userIdx") == 1)
  .select(
    col("recommendations.itemIdx"),
    col("recommendations.rating")
  )

// For all items (top 10 users interested)
val itemRecs = model.recommendForAllItems(10)

// For new users (content-based fallback)
// Use item metadata when user has no history

// Step 7: Store recommendations
userRecs
  .write
  .mode("overwrite")
  .parquet("/recommendations/users")

itemRecs
  .write
  .mode("overwrite")
  .parquet("/recommendations/items")

// Step 8: Serve predictions
// Option A: Batch scoring
def getRecommendations(userId: Int): DataFrame = {
  spark.read.parquet("/recommendations/users")
    .filter(col("userIdx") == userId)
}

// Option B: Real-time scoring
def predictRating(userId: Int, itemId: Int): Double = {
  val input = spark.createDataFrame(
    Seq((userId, itemId))
  ).toDF("userIdx", "itemIdx")
  
  model.transform(input)
    .select("prediction")
    .collect()(0)
    .getDouble(0)
}
```

---

### Q13: Handle scale: Process 1TB of data in < 1 hour

**Answer:**

```scala
// 1TB data → < 1 hour = 280 MB/sec throughput needed
// Need ~20-30 executors with proper tuning

// Configuration
val spark = SparkSession.builder()
  .appName("LargeScaleProcessing")
  .config("spark.executor.memory", "8g")
  .config("spark.executor.cores", "4")
  .config("spark.executor.instances", "30")  // 30 executors
  .config("spark.sql.shuffle.partitions", "400")
  .config("spark.sql.autoBroadcastJoinThreshold", "100MB")
  .config("spark.sql.adaptive.enabled", "true")
  .config("spark.sql.adaptive.skewJoin.enabled", "true")
  .config("spark.default.parallelism", "1200")  // 30 exec × 4 cores × 10
  .getOrCreate()

// Data processing strategy
val rawData = spark.read
  .format("parquet")
  .option("pathGlobFilter", "*.parquet")  // Parallel reads
  .load("/data/raw/*/")  // Multiple partitions

// Step 1: Early filtering (reduce data by 50%)
val filtered = rawData
  .filter(col("timestamp") >= "2024-01-01")
  .filter(col("status") == "active")
  // Now: 500GB

// Step 2: Selective column read (not all columns)
val selected = filtered
  .select("user_id", "amount", "category", "timestamp")
  // Reduces I/O bandwidth

// Step 3: Partition for optimal parallelism
val repartitioned = selected
  .repartition(400)  // 400 partitions × 300 executor cores
  // Each partition: ~1.25GB → processes in ~5 seconds on executor

// Step 4: Process with minimal operations
val aggregated = repartitioned
  .groupBy("category", "user_id")
  .agg(
    sum("amount").alias("total"),
    count("*").alias("count")
  )
  // Single-pass aggregation (efficient)

// Step 5: Write optimized format
aggregated
  .repartition(50)  // Fewer output partitions
  .write
  .format("parquet")
  .option("compression", "snappy")
  .partitionBy("category")  // Organize output
  .mode("overwrite")
  .save("/data/output")

// Performance checklist:
// ✓ Parallelism: 400 partitions / 120 cores = 3.3x
// ✓ Serialization: Parquet with snappy compression
// ✓ Memory: 30 exec × 8GB = 240GB (sufficient for 1TB processing)
// ✓ Network: Minimize shuffle (only 1 shuffle point)
// ✓ Disk: Use optimal format + compression
// ✓ Filter early: 1TB → 500GB before processing
// ✓ Column selection: Reduce I/O
// ✓ Single-pass aggregation: No unnecessary operations

// Expected performance:
// Filter + select: 2 min (I/O bound)
// Aggregation: 25 min (CPU bound)
// Write: 5 min (I/O bound)
// Total: ~35 minutes (within 1 hour target)

// If slower, optimize:
// 1. Increase executors (if cluster allows)
// 2. Increase executor memory (up to 16g)
// 3. Reduce shuffle partitions if CPU underutilized
// 4. Increase shuffle partitions if executors overloaded
// 5. Use bucketing for repeated operations
```

---

## Final Tips for Interview

```
✓ Always ask clarifying questions
✓ Discuss trade-offs (speed vs memory, etc.)
✓ Mention monitoring and metrics
✓ Consider fault tolerance
✓ Think about data skew early
✓ Propose multiple solutions (batch vs streaming)
✓ Discuss deployment and testing
✓ Performance: always consider "why" not just "how"
✓ Explain decisions to interviewer
✓ Ask about constraints (time, cost, accuracy)
```


