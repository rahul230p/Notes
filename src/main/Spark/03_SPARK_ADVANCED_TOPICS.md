# Spark Advanced Topics & Streaming

## Table of Contents
1. [Spark SQL & Catalyst Optimizer](#spark-sql--catalyst-optimizer)
2. [Spark Streaming (DStream)](#spark-streaming-dstream)
3. [Structured Streaming](#structured-streaming)
4. [Performance Tuning](#performance-tuning)
5. [Distributed ML with MLlib](#distributed-ml-with-mllib)

---

## Spark SQL & Catalyst Optimizer

### Catalyst Optimizer Overview

```
Catalyst Optimizer Pipeline:
(Makes SQL queries 10-100x faster than RDDs)

SQL Query: "SELECT * FROM events WHERE amount > 100 
            GROUP BY user_id"
     │
     ▼
Parser → Analyzer → Logical Planner → Optimizer → Physical Planner
     │        │           │              │            │
     │        │           │              │            │
Syntax    Schema      Logical         Rewrite      Physical
Check    Validation    Tree           Rules       Strategies
     │        │           │              │            │
     └────────┴───────────┴──────────────┴────────────┘
                          │
                          ▼
                  Code Generation
                  (JIT Compilation)
                          │
                          ▼
                    Execution Engine
```

### Optimizer Rules (Examples)

```scala
// RULE 1: Predicate Pushdown
// ❌ Without optimizer
val result = events
  .join(users, "user_id")
  .filter(col("amount") > 100)

// Execution order: JOIN (100M x 1M) → FILTER
// Data processed: 100M rows in join

// ✅ With optimizer (automatic)
// Execution order: FILTER (100M → 10M) → JOIN (10M x 1M)
// Data processed: 10M rows in join (90% reduction)

// RULE 2: Column Pruning
// ❌ All columns loaded
val result = events
  .join(users, "user_id")
  .select(col("amount"))  // Only amount needed

// ✅ With optimizer (automatic)
// Only amount and join key loaded from source
// Reduces I/O significantly

// RULE 3: Constant Folding
val df = spark.sql("""
  SELECT * FROM events 
  WHERE timestamp > (current_date() - INTERVAL 30 DAY)
""")

// ❌ Without: Computed at every row
// ✅ With: Computed once at parse time → constant 2024-12-02

// RULE 4: Boolean Simplification
// ❌ Complex boolean expressions
val result = df.filter(
  (col("status") == "active") OR (col("status") == "pending")
)

// ✅ Optimized to
val result = df.filter(col("status").isin("active", "pending"))

// RULE 5: Join Reordering
val result = large_table
  .join(medium_table, "id1")
  .join(small_table, "id2")

// ❌ Order as written: LT × MT × ST
// ✅ Optimizer reorders: (LT × ST) × MT (broadcast ST first)
```

### SQL Performance Examples

```scala
// Example 1: Window Functions (efficient)
val df = spark.read.parquet("/events")

// Spark optimizes window operations well
val withRank = df
  .withColumn("rank", row_number()
    .over(Window.partitionBy("user_id")
                 .orderBy(col("timestamp").desc))
  )
  .filter(col("rank") <= 10)

// Execution: Partition → Sort → Window → Filter
// No unnecessary shuffles

// Example 2: Lateral Views / Explode
val events = spark.sql("""
  SELECT user_id, explode(actions) as action
  FROM user_events
  WHERE date = '2024-01-15'
""")

// Catalyst optimizes explode placement
// Pushes WHERE clause before EXPLODE

// Example 3: Aggregate Functions
val metrics = spark.sql("""
  SELECT 
    user_id,
    COUNT(*) as event_count,
    SUM(amount) as total_amount,
    AVG(page_load_ms) as avg_latency,
    PERCENTILE_APPROX(page_load_ms, 0.95) as p95_latency
  FROM events
  GROUP BY user_id
  HAVING event_count > 100
""")

// Single-pass aggregation (very efficient)
// Partial aggregation on each executor
// Final aggregation on reducer

// Example 4: Subqueries (optimizer flattens them)
val result = spark.sql("""
  SELECT e.*, u.name
  FROM (
    SELECT * FROM events WHERE amount > 100
  ) e
  JOIN users u ON e.user_id = u.id
  WHERE u.country = 'US'
""")

// ✅ Flattened to:
// SELECT e.*, u.name
// FROM events e
// JOIN users u ON e.user_id = u.id
// WHERE e.amount > 100 AND u.country = 'US'
```

---

## Spark Streaming (DStream)

### DStream Architecture

```
Spark Streaming (micro-batch processing):

Real-time Data Stream
     │ (every N seconds)
     ▼
Receiver (Kafka, Socket, etc.)
     │
     ├─ Batch 1 [t=0s-1s]   → RDD of events
     ├─ Batch 2 [t=1s-2s]   → RDD of events
     ├─ Batch 3 [t=2s-3s]   → RDD of events
     └─ Batch N [t=Ns-(N+1)s] → RDD of events
     │
     ▼
DStream (sequence of RDDs)
     │
     ├─ Transformation: map, filter, reduceByKey
     │
     ├─ Stateful: updateStateByKey (per-key state)
     │
     └─ Output: print, save, custom sink


Latency breakdown:
Batch Interval (1 sec)
     ├─ Batch creation (500ms)
     ├─ Processing (300ms)
     ├─ Scheduling (100ms)
     └─ Output writing (100ms)
     
Total latency ≈ 1-2 seconds
(vs Structured Streaming: 100ms - 1s)
```

### DStream Examples

```scala
// Setup
import org.apache.spark.streaming._

val ssc = new StreamingContext(sc, Seconds(1))  // 1-second batches

// Source 1: Kafka
val kafkaStream = KafkaUtils.createDirectStream[String, String](
  ssc,
  LocationStrategies.PreferConsistent,
  ConsumerStrategies.Subscribe[String, String](
    topics = Set("events"),
    kafkaParams = Map(
      "bootstrap.servers" -> "localhost:9092",
      "group.id" -> "spark-consumer"
    )
  )
)

val events = kafkaStream
  .map(record => parse(record.value()))
  .filter(_.amount > 100)

// Transformation: per-batch operations
val counts = events
  .map(e => (e.user_id, 1))
  .reduceByKey(_ + _)  // Sum within batch

// Output: print to console
counts.print()

// Stateful: aggregate across batches
val state = events
  .map(e => (e.user_id, e.amount))
  .updateStateByKey[Double] { case (values, existing) =>
    val current = values.sum
    val updated = existing.getOrElse(0.0) + current
    Some(updated)
  }

state.print()

// Output to sink
counts.saveAsTextFiles("/output/counts")

// Custom sink
counts.foreachRDD { rdd =>
  rdd.foreach { case (userId, count) =>
    sendToDatabase(userId, count)
  }
}

// Start streaming
ssc.start()
ssc.awaitTermination()
```

---

## Structured Streaming

### Architecture vs DStream

```
DStream (RDD-based):
Batch 1 ──┐
Batch 2 ──┼─► Process ──► Output
Batch 3 ──┘
(Micro-batch, but not unified)

Structured Streaming (SQL-based):
         
Input Stream
     │
     ▼
Incremental Streaming Table
     │
     ├─ Add new rows
     ├─ Update existing rows
     └─ Delete rows
     │
     ▼
Spark SQL Query
(Same as batch SQL)
     │
     ▼
Result Table (updated incrementally)
     │
     ▼
Output
```

### Structured Streaming Examples

```scala
import org.apache.spark.sql.functions._
import org.apache.spark.sql.streaming.Trigger

// Read stream from Kafka
val df = spark
  .readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "localhost:9092")
  .option("subscribe", "events")
  .load()

// Parse JSON
val schema = StructType(Seq(
  StructField("user_id", StringType),
  StructField("amount", DoubleType),
  StructField("timestamp", TimestampType),
  StructField("event_type", StringType)
))

val events = df
  .select(from_json(col("value").cast("string"), schema).alias("data"))
  .select("data.*")

// Transformation with time window
val aggregated = events
  .withWatermark("timestamp", "10 minutes")  // Late data tolerance
  .groupBy(
    window(col("timestamp"), "1 minute", "30 seconds"),
    col("event_type")
  )
  .agg(
    count("*").alias("count"),
    sum("amount").alias("total_amount"),
    avg("amount").alias("avg_amount")
  )

// Output modes
// 1. Append: Only new rows (smallest output)
val appendMode = aggregated
  .writeStream
  .format("parquet")
  .option("path", "/output/events")
  .option("checkpointLocation", "/checkpoint")
  .outputMode("append")
  .start()

// 2. Update: Changed rows (row count increases)
val updateMode = aggregated
  .writeStream
  .format("console")
  .outputMode("update")
  .start()

// 3. Complete: All rows (full result set each time)
val completeMode = aggregated
  .writeStream
  .format("console")
  .outputMode("complete")
  .start()

// Trigger options
val trigger1 = aggregated.writeStream
  .option("checkpointLocation", "/checkpoint")
  .trigger(Trigger.ProcessingTime("1 second"))  // Every 1 sec
  .start()

val trigger2 = aggregated.writeStream
  .option("checkpointLocation", "/checkpoint")
  .trigger(Trigger.Once())  // Process once then stop
  .start()

val trigger3 = aggregated.writeStream
  .option("checkpointLocation", "/checkpoint")
  .trigger(Trigger.Continuous("1 second"))  // Experimental
  .start()

// Stateful operation: Session windows
val sessions = events
  .withWatermark("timestamp", "10 minutes")
  .groupBy(
    col("user_id"),
    session_window(col("timestamp"), "5 minutes")
  )
  .agg(
    count("*").alias("events_in_session"),
    sum("amount").alias("session_total")
  )

// Fault tolerance with checkpoints
val query = events
  .groupBy(col("user_id"))
  .count()
  .writeStream
  .format("parquet")
  .option("path", "/output/counts")
  .option("checkpointLocation", "/tmp/checkpoint")  // Saves state
  .outputMode("update")
  .start()

// Monitor the query
println(s"Query status: ${query.status}")
println(s"Recent progress: ${query.recentProgress.toList}")

// Stop when needed
query.stop()
```

### Watermarking & Late Data

```scala
// Without watermark: Keeps state forever (memory leak)
val bad = events
  .groupBy(col("user_id"))
  .agg(count("*"))

// With watermark: Drops late data after threshold
val good = events
  .withWatermark("timestamp", "30 minutes")
  .groupBy(
    window(col("timestamp"), "1 minute"),
    col("user_id")
  )
  .agg(count("*"))

// Watermark visualization:
```
│
│ Current max event time: 10:30:00
│ Watermark (allowed lateness): 10:00:00 (30 min earlier)
│
├─ Events with timestamp >= 10:00:00 → processed
├─ Events with timestamp < 10:00:00 → dropped
│
└─ Event arrives at 10:35:00 with timestamp 10:05:00
   → still within watermark (10:35:00 - 10:05:00 = 30 min)
   → INCLUDED in output
   
├─ Event arrives at 10:35:00 with timestamp 09:50:00
│  → outside watermark (10:35:00 - 09:50:00 = 45 min)
│  → DROPPED (considered too late)
│
```

---

## Performance Tuning

### Tuning Parameters

```scala
// ============================================
// 1. BATCH PROCESSING TUNING
// ============================================

spark.conf.set("spark.sql.shuffle.partitions", "200")
// Default 200, increase if data > 5GB
// Reduce if data < 1GB and cluster is small

spark.conf.set("spark.default.parallelism", "100")
// Controls number of parallel tasks

spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10485760")
// 10MB default, increase to 50MB if you have memory

// ============================================
// 2. MEMORY TUNING
// ============================================

spark.conf.set("spark.executor.memory", "4g")
// Total memory per executor

spark.conf.set("spark.executor.cores", "4")
// Cores per executor

spark.conf.set("spark.driver.memory", "2g")
// Driver memory

spark.conf.set("spark.sql.shuffle.partitions", "200")
// More partitions = less memory per partition

// ============================================
// 3. NETWORK TUNING
// ============================================

spark.conf.set("spark.network.timeout", "600s")
// Timeout for network operations

spark.conf.set("spark.shuffle.compress", "true")
// Compress shuffle output

spark.conf.set("spark.shuffle.spill.compress", "true")
// Compress data spilled to disk

// ============================================
// 4. COMPUTATION TUNING
// ============================================

spark.conf.set("spark.sql.inMemoryColumnarStorage.batchSize", "10000")
// Batch size for columnar storage

spark.conf.set("spark.sql.adaptive.enabled", "true")
// Enable adaptive query execution (Spark 3.0+)

spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
// Handle skewed joins (Spark 3.0+)

// ============================================
// 5. LOGGING & MONITORING
// ============================================

spark.sparkContext.setLogLevel("WARN")
// TRACE, DEBUG, INFO, WARN, ERROR

spark.sparkContext.setEventLogDir("/path/to/logs")
// Save event logs for analysis

// ============================================
// 6. COMMON OPTIMIZATION PATTERNS
// ============================================

// Pattern 1: Filter early
val bad = df1.join(df2).filter(condition)
val good = df1.filter(condition).join(df2)

// Pattern 2: Broadcast small tables
val good = df1.join(broadcast(df2), key)

// Pattern 3: Select columns early
val bad = df1.join(df2).select("a", "b")
val good = df1.select("key", "a").join(df2)

// Pattern 4: Avoid repartition(1)
val bad = df.repartition(1)  // All data on 1 executor
val good = df.coalesce(N)    // N > 1

// Pattern 5: Cache before reuse
val expensive = df.filter(...).join(...).cache()
val a = expensive.count()
val b = expensive.filter(...)

// Pattern 6: Use native Spark functions
val bad = df.map(row => complexCalculation(row))  // Slow
val good = df.select(col("a") * col("b"))        // Fast (Tungsten)
```

### Performance Benchmarking

```scala
// Benchmark framework
object SparkBenchmark {
  def benchmark(name: String, N: Int)(f: => Unit): Unit = {
    val start = System.nanoTime()
    for (i <- 0 until N) f
    val duration = (System.nanoTime() - start) / 1e9
    println(s"$name: ${duration/N}s per run")
  }
}

// Example benchmark
val df = spark.read.parquet("/data")

SparkBenchmark.benchmark("Filter", 5) {
  df.filter(col("amount") > 100).count()
}

SparkBenchmark.benchmark("GroupBy", 5) {
  df.groupBy("user_id").count().collect()
}

// Output:
// Filter: 0.5s per run
// GroupBy: 2.3s per run

// Analyze with explain
df.filter(col("amount") > 100).explain(true)

// Save execution plan
df.explain(mode = "extended")
// Look for:
// - Unnecessary shuffles
// - Full table scans instead of partition pruning
// - Inefficient join strategies
```

---

## Distributed ML with MLlib

### MLlib Pipeline Architecture

```
Raw Data
   │
   ▼
┌─────────────────────┐
│  Data Preparation   │
├─────────────────────┤
│ - Clean             │
│ - Normalize         │
│ - Feature Selection │
└─────────────────────┘
   │
   ▼
┌─────────────────────┐
│ Feature Engineering │
├─────────────────────┤
│ - Tokenizer         │
│ - VectorAssembler   │
│ - StandardScaler    │
└─────────────────────┘
   │
   ▼
┌─────────────────────┐
│  Model Training     │
├─────────────────────┤
│ - LogisticRegression│
│ - RandomForest      │
│ - GradientBoosting  │
└─────────────────────┘
   │
   ▼
┌─────────────────────┐
│ Model Evaluation    │
├─────────────────────┤
│ - Accuracy          │
│ - Precision/Recall  │
│ - AUC               │
└─────────────────────┘
   │
   ▼
Trained Model
```

### MLlib Example

```scala
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.feature._
import org.apache.spark.ml.classification.LogisticRegression
import org.apache.spark.ml.evaluation.BinaryClassificationEvaluator

// Step 1: Load data
val data = spark.read
  .format("libsvm")
  .load("data/mllib/sample_libsvm_data.txt")

// Step 2: Feature engineering pipeline
val tokenizer = new Tokenizer()
  .setInputCol("text")
  .setOutputCol("words")

val vectorizer = new CountVectorizer()
  .setInputCol("words")
  .setOutputCol("features")
  .setVocabSize(10000)

val scaler = new StandardScaler()
  .setInputCol("features")
  .setOutputCol("scaledFeatures")
  .setWithMean(true)
  .setWithStd(true)

// Step 3: Model
val lr = new LogisticRegression()
  .setMaxIter(100)
  .setRegParam(0.01)
  .setFeaturesCol("scaledFeatures")
  .setLabelCol("label")

// Step 4: Pipeline
val pipeline = new Pipeline()
  .setStages(Array(tokenizer, vectorizer, scaler, lr))

// Step 5: Train/test split
val Array(trainingData, testData) = data.randomSplit(Array(0.7, 0.3))

// Step 6: Training
val model = pipeline.fit(trainingData)

// Step 7: Prediction
val predictions = model.transform(testData)

// Step 8: Evaluation
val evaluator = new BinaryClassificationEvaluator()
  .setLabelCol("label")
  .setRawPredictionCol("rawPrediction")

val auc = evaluator.evaluate(predictions)
println(s"AUC: $auc")

// Step 9: Cross-validation (optional)
import org.apache.spark.ml.tuning.CrossValidator

val crossval = new CrossValidator()
  .setEstimator(pipeline)
  .setEvaluator(evaluator)
  .setEstimatorParamMaps(paramGrid)
  .setNumFolds(5)

val cvModel = crossval.fit(trainingData)

// Step 10: Save model
model.save("/models/logistic_regression")
```

### Distributed Algorithms

```scala
// ============================================
// 1. REGRESSION
// ============================================

// Linear Regression (Spark optimizes via SGD)
val lr = new LinearRegression()
  .setMaxIter(100)
  .setRegParam(0.01)
  .setElasticNetParam(0.8)  // Mix L1 + L2

// Ridge (L2): regularization = 1.0
// Lasso (L1): elasticNetParam = 1.0

// ============================================
// 2. CLASSIFICATION
// ============================================

// Logistic Regression
val logReg = new LogisticRegression()
  .setMaxIter(100)
  .setThreshold(0.5)

// Decision Trees (parallel split finding)
val dt = new DecisionTreeClassifier()
  .setMaxDepth(5)
  .setMinInstancesPerNode(10)

// Random Forest (many trees in parallel)
val rf = new RandomForestClassifier()
  .setNumTrees(100)
  .setMaxDepth(5)

// Gradient Boosting (sequential trees, parallelized)
val gbt = new GBTClassifier()
  .setMaxIter(20)
  .setMaxDepth(5)

// ============================================
// 3. CLUSTERING
// ============================================

// K-means (distributed)
val kmeans = new KMeans()
  .setK(10)
  .setMaxIter(20)
  .setInitMode("k-means||")  // Smart initialization

val kmeansModel = kmeans.fit(data)

// ============================================
// 4. MATRIX FACTORIZATION
// ============================================

// ALS (Alternating Least Squares) for recommendations
val als = new ALS()
  .setMaxIter(5)
  .setRegParam(0.01)
  .setUserCol("userId")
  .setItemCol("movieId")
  .setRatingCol("rating")

val alsModel = als.fit(ratings)

// Distributed algorithms benefits:
// - Large datasets (TB scale)
// - Parallel training across executors
// - Built-in optimization (SGD, ALS, etc.)
// - Feature engineering integrated
```

---

## Summary Checklist

```
✓ Spark Architecture: Driver + Executors + RDDs/DataFrames
✓ Use DataFrames/SQL (not RDDs) for performance
✓ Catalyst optimizer handles query optimization
✓ Cache strategically (reuse > 1x, cost < benefit)
✓ Broadcast small tables (< 100MB)
✓ Monitor with explain(), UI, event logs
✓ Tune partitions (128MB-256MB target)
✓ Handle skew with salting or separate logic
✓ Structured Streaming over DStream for low latency
✓ MLlib for distributed ML at scale
✓ Test performance improvements with benchmarks
```


