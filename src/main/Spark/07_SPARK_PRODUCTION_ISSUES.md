# Spark Production Issues & Troubleshooting Guide

## Table of Contents
1. [Out Of Memory (OOM) Errors](#out-of-memory-oom-errors)
2. [Data Skew Problems](#data-skew-problems)
3. [Long-Running Jobs](#long-running-jobs)
4. [Task Failures & Retries](#task-failures--retries)
5. [Shuffle Bottlenecks](#shuffle-bottlenecks)
6. [GC (Garbage Collection) Issues](#gc-garbage-collection-issues)
7. [Network & Disk I/O Issues](#network--disk-io-issues)
8. [Debugging Checklist](#debugging-checklist)

---

## Out Of Memory (OOM) Errors

### Types of OOM Errors

```
OOM Errors in Spark:

Type 1: DRIVER OOM
├─ Error: java.lang.OutOfMemoryError: Java heap space (in driver)
├─ Cause: collect() on large RDD, large broadcast variable
├─ Memory: spark.driver.memory (default 1GB)
└─ Solution: Increase driver memory or avoid collect()

Type 2: EXECUTOR OOM
├─ Error: java.lang.OutOfMemoryError: Java heap space (in executor)
├─ Cause: Large shuffle, large cache, large task
├─ Memory: spark.executor.memory (default 1GB)
└─ Solution: Increase executor memory or reduce partition size

Type 3: DIRECT BUFFER OOM
├─ Error: OutOfMemoryError: Direct buffer memory
├─ Cause: Network buffers, shuffle write buffers
├─ Memory: spark.network.maxBuffered
└─ Solution: Increase network buffers or reduce parallelism

Type 4: GC OVERHEAD OOM
├─ Error: OutOfMemoryError: GC overhead limit exceeded
├─ Cause: Object allocation > GC collection rate
├─ Memory: Heap too small for workload
└─ Solution: Increase memory or optimize code
```

### OOM Scenario 1: Collect on Large Dataset

```scala
// ❌ CAUSES OOM (1TB dataset)
val largeRDD = spark.read.parquet("/1tb_data")
val result = largeRDD.collect()  // Tries to load 1TB in driver memory!
// Error: java.lang.OutOfMemoryError: Java heap space

// ✓ FIX 1: Use take() instead
val sample = largeRDD.take(1000)  // Only first 1000 rows

// ✓ FIX 2: Save to file instead
largeRDD.write.parquet("/output/result")  // No collection

// ✓ FIX 3: Write in batches
largeRDD
  .foreachPartition { partition =>
    partition.foreach(row => {
      // Process one row at a time
      database.insert(row)
    })
  }

// ✓ FIX 4: Aggregate first, then collect
val aggregated = largeRDD
  .groupByKey()
  .agg(sum("value"))
  .limit(100)
val result = aggregated.collect()  // Much smaller dataset
```

### OOM Scenario 2: Large Broadcast Variable

```scala
// ❌ CAUSES OOM: Broadcasting 500MB to 50 executors
val largeMap = spark.read.parquet("/data")
  .collect()  // Loads into driver
  .map(row => (row.id, row.value))
  .toMap

val broadcast = spark.sparkContext.broadcast(largeMap)

// Error: Driver runs out of memory collecting data
// Error: Each executor needs 500MB for broadcast

// ✓ FIX 1: Pre-compute and save
val precomputed = spark.read.parquet("/lookup")  // Already distributed
val result = largeTable.join(precomputed, "id")

// ✓ FIX 2: Increase broadcast threshold
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")  // Disable auto-broadcast
// Then explicitly broadcast only when needed

// ✓ FIX 3: Use BloomFilter for filtering first
val bloomFilter = new BloomFilter(100000)
precomputed.select("id").collect().forEach { row =>
  bloomFilter.put(row.id)
}
val filtered = largeTable.filter(row => bloomFilter.mightContain(row.id))
val result = filtered.join(precomputed, "id")  // Smaller dataset

// ✓ FIX 4: Split broadcast into parts
val partSize = 10  // 50MB per partition
val parts = largeMap.toList.grouped(partSize).toList
val broadcasts = parts.map(part => spark.sparkContext.broadcast(part.toMap))
// Use different broadcast for different partition ranges
```

### OOM Scenario 3: Large Shuffle

```scala
// ❌ CAUSES OOM: Shuffle with 1TB data, too few partitions
val data = spark.read.parquet("/1tb_data")
val aggregated = data
  .repartition(10)  // Only 10 partitions = 100GB per partition!
  .groupBy("key")
  .agg(sum("value"))

// Error: Each executor has 100GB to sort
// spark.executor.memory is only 8GB

// ✓ FIX 1: Increase partitions
val aggregated = data
  .repartition(200)  // 200 partitions = 5GB per partition
  .groupBy("key")
  .agg(sum("value"))

// ✓ FIX 2: Use correct shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "500")
// Spark SQL automatically uses this

// ✓ FIX 3: Filter before aggregation
val aggregated = data
  .filter(col("status") == "active")  // Reduces 1TB → 200GB
  .groupBy("key")
  .agg(sum("value"))

// ✓ FIX 4: Use spilling to disk
spark.conf.set("spark.shuffle.spill", "true")
spark.conf.set("spark.shuffle.spill.compress", "true")
// Allows shuffle to overflow to disk (slower but works)
```

### OOM Scenario 4: Large Cache

```scala
// ❌ CAUSES OOM: Caching 1TB in 8GB executor
val data = spark.read.parquet("/1tb_data")
val cached = data.cache()  // Tries to cache entire 1TB
val result1 = cached.count()
val result2 = cached.filter(...).count()

// Error: OutOfMemoryError during cache

// ✓ FIX 1: Cache only necessary columns
val cached = data
  .select("col1", "col2", "col3")  // Reduced dataset
  .cache()

// ✓ FIX 2: Use serialized cache
val cached = data
  .persist(StorageLevel.MEMORY_ONLY_SER)  // 50-75% smaller

// ✓ FIX 3: Cache only filtered data
val cached = data
  .filter(col("status") == "active")  // 200GB → 50GB
  .cache()

// ✓ FIX 4: Memory-aware caching
import org.apache.spark.storage.StorageLevel
val cached = data.persist(StorageLevel.MEMORY_AND_DISK)
// Spills to disk if memory fills

// ✓ FIX 5: Cache only intermediate results
// Bad: cache raw data
// Good: cache after filtering/aggregation
val filtered = data.filter(condition)  // Not cached
val aggregated = filtered.groupBy("key").agg(...)  // Cache this
cached = aggregated.cache()
```

### Diagnosing OOM

```scala
// Enable GC logging
spark.conf.set("spark.driver.extraJavaOptions", 
  "-XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps " +
  "-XX:+PrintHeapAtGC -Xloggc:/path/to/gc.log")

// Check memory usage during execution
spark.sparkContext.statusTracker
  .executorInfos
  .foreach { exec =>
    println(s"Executor ${exec.executorId}: ${exec.maxMemory / 1e9} GB")
  }

// Monitor via Spark UI
// http://localhost:4040/executors/
// Look for: Memory usage, GC time, Tasks per executor

// Check if data is skewed
data.rdd.mapPartitions { partition =>
  Iterator(partition.size)
}
.collect()
.foreach(size => println(s"Partition size: $size"))
// If some partitions >> others, data is skewed
```

---

## Data Skew Problems

### Understanding Data Skew

```
Data Skew Visualization:

Balanced Data:
Partition 0: ████████ 100GB
Partition 1: ████████ 100GB
Partition 2: ████████ 100GB
Partition 3: ████████ 100GB
Average: 100GB per partition
Processing time: Equal across partitions

Skewed Data:
Partition 0: ████████████████████████ 400GB (Bottleneck!)
Partition 1: ██ 10GB
Partition 2: ██ 10GB
Partition 3: ██ 10GB
Average: 107.5GB
Processing time: Partition 0 takes 4x longer!

Result: Entire job limited by slowest partition
```

### Skew Scenario 1: Hot Keys in GroupBy

```scala
// Dataset: User activity logs
// Problem: Few users (e.g., admin) have 90% of traffic

val events = spark.read.parquet("/events")

// ❌ SKEWED AGGREGATION
val aggregated = events
  .groupBy("user_id")
  .agg(count("*").alias("count"))

// Some user_id partitions have 100M events
// Others have 100 events
// Partition with 100M events is bottleneck

// ✓ FIX 1: Salting (add random prefix to hot keys)
val salted = events
  .withColumn("salt", (rand() * 10).cast("int"))
  .withColumn("user_id_salted", 
    concat(col("user_id"), lit("_"), col("salt"))
  )

val aggregated = salted
  .groupBy("user_id_salted")
  .agg(count("*").alias("count"))
  .withColumn("user_id", 
    regexp_replace(col("user_id_salted"), "_\\d+$", "")
  )
  .groupBy("user_id")
  .agg(sum("count").alias("count"))

// Now 100M events split into 10 groups of 10M each
// All partitions process in parallel

// ✓ FIX 2: Separate hot data
val hotUsers = Seq("user123", "user456")  // Known hot keys
val hotData = events.filter(col("user_id").isin(hotUsers: _*))
val coldData = events.filter(!col("user_id").isin(hotUsers: _*))

val hotAgg = hotData
  .repartition(50)  // More partitions for hot data
  .groupBy("user_id")
  .agg(count("*"))

val coldAgg = coldData
  .groupBy("user_id")
  .agg(count("*"))

val result = hotAgg.union(coldAgg)

// ✓ FIX 3: Increase partitions
spark.conf.set("spark.sql.shuffle.partitions", "1000")  // Default 200
val aggregated = events.groupBy("user_id").agg(count("*"))
// More partitions distribute hot keys across more executors

// ✓ FIX 4: Use adaptive skew join (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
// Spark automatically detects and handles skew
```

### Skew Scenario 2: Skewed Join

```scala
// Two tables: Orders (1TB) × Products (1GB)
// Problem: Popular products have 10x more orders

val orders = spark.read.parquet("/orders")     // 1TB
val products = spark.read.parquet("/products") // 1GB

// ❌ SKEWED JOIN
val result = orders.join(products, "product_id")

// Product "A" (popular) has 100M orders
// Product "Z" (unpopular) has 1M orders
// product_id "A" partition = bottleneck

// ✓ FIX 1: Broadcast if possible
val result = orders.join(broadcast(products), "product_id")
// Products only 1GB, can broadcast
// No shuffle, no skew!

// ✓ FIX 2: Separate hot products
val hotProducts = Seq("A", "B", "C")
val hotOrders = orders.filter(col("product_id").isin(hotProducts: _*))
val coldOrders = orders.filter(!col("product_id").isin(hotProducts: _*))

val hotResult = hotOrders
  .repartition(100, col("product_id"))  // More partitions
  .join(products, "product_id")

val coldResult = coldOrders
  .join(products, "product_id")

val result = hotResult.union(coldResult)

// ✓ FIX 3: Replicate hot products
val hotProductIds = products
  .groupBy("product_id")
  .count()
  .filter(col("count") > threshold)
  .select("product_id")

val productsReplicated = products
  .join(hotProductIds, "product_id")  // Only hot products
  .select(col("*"), (rand() * 10).cast("int").alias("replica"))

val ordersExpanded = orders
  .join(
    productsReplicated.select("*"),
    concat(col("product_id"), lit("_"), col("replica")) === 
      concat(productsReplicated("product_id"), lit("_"), productsReplicated("replica"))
  )
  .drop("replica")

// Hot products replicated 10x, distributed across executors
```

### Detecting Skew

```scala
// Method 1: Check partition sizes
val df = spark.read.parquet("/data")

val sizes = df.rdd.mapPartitions { partition =>
  Iterator(partition.size)
}
.collect()

sizes.foreach(size => println(s"$size"))
// If some >> others, data is skewed

val maxSize = sizes.max
val minSize = sizes.min
val skewRatio = maxSize.toDouble / minSize
println(s"Skew ratio: ${skewRatio}x")
// If ratio > 10, significant skew

// Method 2: Via Spark UI
// http://localhost:4040/executors/
// Look at tasks per executor
// If some executors >> others, skewed

// Method 3: Look at stage details
df.groupBy("key").count().explain(true)
// Check shuffle write distribution

// Method 4: Use metrics
val metrics = df
  .groupBy("key")
  .count()
  .agg(
    max("count").alias("max_key_count"),
    min("count").alias("min_key_count"),
    avg("count").alias("avg_key_count")
  )
metrics.show()
// If max >> avg, skewed
```

---

## Long-Running Jobs

### Identifying Slow Stages

```
Long Job Analysis:

┌──────────────┬────────────┬──────────┐
│ Stage        │ Time       │ Status   │
├──────────────┼────────────┼──────────┤
│ Stage 1: Map │ 2 minutes  │ ✓ Fast  │
│ Stage 2: Flt │ 30 seconds │ ✓ Fast  │
│ Stage 3: Shf │ 20 minutes │ ✗ SLOW  │ ← Bottleneck
│ Stage 4: Agg │ 5 minutes  │ ✓ OK    │
├──────────────┼────────────┼──────────┤
│ TOTAL        │ 27.5 min   │          │
└──────────────┴────────────┴──────────┘

Root cause: Shuffle in Stage 3
- Could be: Data skew, too few partitions, large data

Solution: Increase partitions or address skew
```

### Long Job Scenario 1: Too Few Partitions

```scala
// Job takes 2 hours with 20 executors

val data = spark.read.parquet("/1tb_data")
// Default: 2 partitions (based on HDFS blocks)
// Each executor gets 500GB!

// ❌ SLOW
spark.conf.set("spark.sql.shuffle.partitions", "2")  // Default for parquet
val result = data.groupBy("key").agg(sum("value"))

// ✓ SOLUTION: Increase partitions
spark.conf.set("spark.sql.shuffle.partitions", "500")
val result = data.groupBy("key").agg(sum("value"))
// Now: 1TB / 500 = 2GB per partition
// Processing: 1TB / (20 exec × 4 cores / executor) = faster

// Quick rule: 
// partitions = cluster_cores × 2-4
// = 20 exec × 4 cores × 3 = 240 partitions
spark.conf.set("spark.sql.shuffle.partitions", "240")
```

### Long Job Scenario 2: Missing Column Pruning

```scala
// Reading 100GB table, using only 5 columns

// ❌ SLOW: Reads all columns
val df = spark.read.parquet("/100gb_data")
val result = df
  .filter(col("status") == "active")
  .select("col1", "col2", "col3")
  .groupBy("col1").agg(sum("col2"))
// Time: 20 minutes (reads all 100GB)

// ✓ FAST: Push select down
val df = spark.read.parquet("/100gb_data")
val result = df
  .select("col1", "col2", "col3", "status")  // Select early
  .filter(col("status") == "active")
  .groupBy("col1").agg(sum("col2"))
// Time: 5 minutes (reads only 20GB)

// ✓ BEST: Use SQL with column selection
val result = spark.sql("""
  SELECT col1, SUM(col2) as total
  FROM data
  WHERE status = 'active'
  GROUP BY col1
""")
// Catalyst optimizes column pruning automatically
// Time: 2 minutes (predicate pushdown + column pruning)
```

### Long Job Scenario 3: Expensive Operations in Hot Path

```scala
// ❌ SLOW: Expensive function on every row
val result = data
  .map(row => {
    // Complex computation (10 seconds per 1000 rows)
    expensiveTransformation(row.value)
  })
  .filter(condition)
  .groupBy("key")
  .agg(sum("value"))

// ✓ SOLUTION 1: Filter first
val result = data
  .filter(condition)  // Reduce rows first
  .map(row => expensiveTransformation(row.value))
  .groupBy("key")
  .agg(sum("value"))

// ✓ SOLUTION 2: Use native Spark functions
val result = data
  .filter(condition)
  .withColumn("transformed", col("value") * 2 + 100)  // Fast
  .groupBy("key")
  .agg(sum("transformed"))

// ✓ SOLUTION 3: Cache intermediate result
val filtered = data.filter(condition).cache()
filtered.count()  // Force computation
val result = filtered
  .withColumn("transformed", col("value") * 2)
  .groupBy("key")
  .agg(sum("transformed"))
```

### Long Job Scenario 4: Inefficient Joins

```scala
// ❌ SLOW: Multiple sequential joins
val result = orders
  .join(customers, "customer_id")    // Shuffle 1
  .join(products, "product_id")      // Shuffle 2
  .join(regions, "region_id")        // Shuffle 3
// 3 shuffles, takes 2 hours

// ✓ SOLUTION 1: Broadcast small tables
val result = orders
  .join(broadcast(customers), "customer_id")
  .join(broadcast(products), "product_id")
  .join(broadcast(regions), "region_id")
// 0 shuffles, takes 10 minutes

// ✓ SOLUTION 2: Use bucketing
orders.write.bucketBy(100, "customer_id").parquet("/orders_bucketed")
customers.write.bucketBy(100, "id").parquet("/customers_bucketed")
// Then join bucketed tables (no shuffle)

val result = spark.read.parquet("/orders_bucketed")
  .join(spark.read.parquet("/customers_bucketed"), "customer_id")
```

---

## Task Failures & Retries

### Task Failure Types

```
Task Failure Scenarios:

Type 1: NETWORK FAILURE
├─ Error: Connection timeout, shuffle fetch failure
├─ Cause: Network issue, slow executor
├─ Spark Retry: Default 3 retries
└─ Solution: Increase timeout, fix network

Type 2: EXECUTOR CRASH
├─ Error: Lost task executor
├─ Cause: OOM, process killed, host failure
├─ Spark Retry: Default 3 retries
└─ Solution: Fix OOM, stable hardware

Type 3: TASK TIMEOUT
├─ Error: Task exceeded timeout
├─ Cause: Stuck task, network slow, data skew
├─ Spark Retry: Maybe (depends on config)
└─ Solution: Increase timeout or optimize task

Type 4: DATA CORRUPTION
├─ Error: Checksum mismatch
├─ Cause: Disk failure, network corruption
├─ Spark Retry: Compute from lineage
└─ Solution: Fix hardware

Type 5: SHUFFLE FAILURE
├─ Error: Shuffle file not found
├─ Cause: Executor died, shuffle file lost
├─ Spark Retry: Recompute shuffle
└─ Solution: External shuffle service
```

### Retrying Configuration

```scala
// Control task retries
spark.conf.set("spark.task.maxFailures", "4")  // Default 3
// Retry failed task up to 4 times

spark.conf.set("spark.network.timeout", "300s")  // Default 120s
// Increase if network is slow

spark.conf.set("spark.shuffle.io.maxRetries", "5")  // Default 3
// Retry shuffle fetches

// For long-running tasks that might timeout
spark.conf.set("spark.executor.heartbeatInterval", "60s")
spark.conf.set("spark.network.timeoutInterval", "60s")

// Enable external shuffle service (resilient)
// In spark-defaults.conf:
// spark.shuffle.service.enabled=true
```

### Resilient Execution

```scala
// With Checkpointing
val df = spark.read.parquet("/data")

// Checkpoint after expensive operation
df.checkpoint()  // Writes to HDFS/S3, safe from node loss

val result = df
  .groupBy("key")
  .agg(sum("value"))
  .checkpoint()  // Can recover from this point

result.write.parquet("/output")

// Lineage Caching
val rdd = sc.parallelize(1 to 1000)
rdd.cache()
rdd.checkpoint()  // Both cache and checkpoint
// Cache for speed, checkpoint for safety
```

---

## Shuffle Bottlenecks

### Shuffle Process Visualization

```
Shuffle Process:

Shuffle Write Phase:
┌────────────────────────────────┐
│ Task 1: Key1→P0, Key2→P1, ... │
│ Write to: /shuffle/1/output0   │
│         + /shuffle/1/output1   │
│         + /shuffle/1/outputN   │
└────────────────────────────────┘

Network Transfer:
Executor 1 /shuffle/1/output0 ──┐
Executor 2 /shuffle/1/output1 ──┼──► Executor 0 (Partition 0)
Executor N /shuffle/1/outputN ──┘

Shuffle Read Phase:
┌────────────────────────────────┐
│ Task N+1: Read /shuffle/1/*    │
│ (network fetch)                │
│ Sort by key (if needed)        │
│ Output to next stage           │
└────────────────────────────────┘

Network I/O: 2× total data size
(write + read over network)
```

### Shuffle Optimization

```scala
// Problem: Shuffle taking 30 minutes

val data = spark.read.parquet("/1tb_data")

// ❌ SLOW SHUFFLE
val result = data
  .repartition(100)  // Too few
  .groupBy("key")
  .agg(sum("value"))

// ✓ FIX 1: More partitions
spark.conf.set("spark.sql.shuffle.partitions", "500")
val result = data.groupBy("key").agg(sum("value"))
// Smaller partitions = less I/O per executor

// ✓ FIX 2: Enable shuffle compression
spark.conf.set("spark.shuffle.compress", "true")
spark.conf.set("spark.shuffle.spill.compress", "true")
// Reduces network I/O by 30-50%

// ✓ FIX 3: Use external shuffle service
// In spark-defaults.conf:
// spark.shuffle.service.enabled=true
// Allows executors to fail without losing shuffle files

// ✓ FIX 4: Tune shuffle memory
spark.conf.set("spark.shuffle.memoryFraction", "0.2")  // 20% of executor memory
// More memory for shuffle = less spill to disk

// ✓ FIX 5: Filter before shuffle
val result = data
  .filter(col("status") == "active")  // Reduce by 50%
  .groupBy("key")
  .agg(sum("value"))
// Half the data to shuffle = half the time
```

---

## GC (Garbage Collection) Issues

### GC Pauses

```
GC Impact on Spark:

Normal Execution:
Task 1: ███ 5s
Task 2: ███ 5s
Task 3: ███ 5s
Total: 15s

With GC Pauses:
Task 1: ███░░░░░░░ 2s work + 8s GC = 10s
Task 2: ███░░░░░░░ 2s work + 8s GC = 10s
Task 3: ███░░░░░░░ 2s work + 8s GC = 10s
Total: 30s (2x slower!)

Worse case: Stop-the-world GC
All executors pause → entire job pauses
```

### GC Tuning

```scala
// Detect GC issues
spark.conf.set("spark.driver.extraJavaOptions", 
  "-XX:+PrintGCDetails -XX:+PrintGCTimeStamps " +
  "-Xloggc:gc.log")

// Tuning strategies
// 1. Reduce object allocation
spark.conf.set("spark.rdd.compress", "true")  // Compress RDD
spark.conf.set("spark.broadcast.compress", "true")

// 2. Increase young generation (faster GC)
spark.conf.set("spark.driver.extraJavaOptions", 
  "-XX:NewRatio=1")  // 50% young gen

// 3. Use G1GC (modern garbage collector)
spark.conf.set("spark.driver.extraJavaOptions",
  "-XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=35")

// 4. Avoid object creation
// ❌ Creates objects
val rdd = data.map(row => (row.key, row.value))
// ✓ Less object creation
val df = data.groupBy("key").agg(sum("value"))

// 5. Use serialized cache
data.persist(StorageLevel.MEMORY_ONLY_SER)
// Uses less memory, less GC pressure
```

---

## Network & Disk I/O Issues

### Network Bottleneck Detection

```scala
// Signs of network bottleneck
// 1. Shuffle taking >> 80% of job time
// 2. Executors idle (waiting for network)
// 3. Network bandwidth near limit

// Solutions
spark.conf.set("spark.network.timeout", "600s")  // Increase timeout
spark.conf.set("spark.shuffle.compress", "true")  // Compress data
spark.conf.set("spark.io.compression.codec", "snappy")

// Use bucketing to reduce shuffle
df.write.bucketBy(100, "key").parquet("/data_bucketed")

// Colocate data (same region as cluster)
// For S3: spark.hadoop.fs.s3a.endpoint = "s3-region.amazonaws.com"
```

### Disk I/O Bottleneck

```scala
// Slow disk reads
// 1. Use SSD instead of HDD
// 2. Increase parallelism (read multiple files)
// 3. Use better compression (snappy vs gzip)

// Slow writes
val result = df
  .write
  .mode("overwrite")
  .option("spark.sql.parquet.compression.codec", "snappy")
  .parquet("/output")

// Optimize partition size (avoid many small files)
result.write
  .repartition(100)  // Not too many small files
  .parquet("/output")
```

---

## Debugging Checklist

### For Any Slow Job

```
1. CHECK BASIC METRICS
   □ Total time: vs expected
   □ Number of tasks: too many? too few?
   □ Task duration: all similar or skewed?
   □ Executor utilization: all busy?

2. IDENTIFY BOTTLENECK STAGE
   □ Sort stages by duration
   □ Which stage takes most time?
   □ Is it I/O, shuffle, compute, or GC?

3. INVESTIGATE STAGE DETAILS
   □ Number of tasks in stage
   □ Task duration distribution
   □ Shuffle input/output size
   □ Memory usage per task

4. CHECK FOR DATA SKEW
   □ Partition sizes (map tasks)
   □ Key distribution (reduce side)
   □ Task duration variance

5. REVIEW RESOURCE USAGE
   □ Memory: % used, GC pauses
   □ CPU: utilization %
   □ Network: bytes sent/received
   □ Disk: I/O rate

6. LOOK AT CATALYST PLAN
   □ df.explain(extended=true)
   □ Are filters pushed down?
   □ Are columns pruned?
   □ Join strategy optimal?

7. TEST FIXES
   □ Make one change
   □ Measure improvement
   □ If better, keep it
   □ If worse, revert

8. REPEAT UNTIL SATISFIED
```

### Debugging Commands

```scala
// Check memory
spark.sparkContext.statusTracker.executorInfos.foreach { exec =>
  println(s"Executor ${exec.executorId}: " +
    s"max ${exec.maxMemory/1e9}GB")
}

// Check partition count
df.rdd.getNumPartitions

// Check partition sizes
df.rdd.mapPartitions(_.size).collect().foreach(println)

// Check execution plan
df.explain(extended = true)

// Check Spark UI
// http://localhost:4040/

// Check event logs
// spark-history-server.sh /path/to/logs

// Use scala to find slow tasks
spark.sql("""
  SELECT stage_id, task_id, duration FROM tasks 
  ORDER BY duration DESC LIMIT 10
""")
```

---

## Quick Fixes Reference

```
Problem              │ Quick Fix
─────────────────────┼──────────────────────────────────
Job very slow        │ Increase partitions × 2-3
OOM error            │ Increase executor memory or 
                     │ reduce partition count
Data skew            │ Use salting or separate hot keys
Join slow            │ Use broadcast if possible
Shuffle slow         │ Enable compression, more partitions
Long GC pauses       │ Use G1GC, tune young generation
Network slow         │ Enable compression, reduce data
Too many small files │ Coalesce before writing
```


