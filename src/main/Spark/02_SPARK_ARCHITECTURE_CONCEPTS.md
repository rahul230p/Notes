# Spark Architecture & Core Concepts

## Table of Contents
1. [Spark Architecture](#spark-architecture)
2. [RDD vs DataFrame vs Dataset](#rdd-vs-dataframe-vs-dataset)
3. [Execution Plan & Query Optimization](#execution-plan--query-optimization)
4. [Memory Management](#memory-management)
5. [Partitioning & Shuffling](#partitioning--shuffling)
6. [Caching & Persistence](#caching--persistence)

---

## Spark Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SPARK APPLICATION                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              DRIVER PROGRAM (Main Process)               │  │
│  │                                                          │  │
│  │  ┌─────────────────────────────────────────────────┐   │  │
│  │  │  SparkContext/SparkSession                      │   │  │
│  │  │  - Creates RDDs, DataFrames                      │   │  │
│  │  │  - Submits tasks to cluster                      │   │  │
│  │  │  - Tracks job progress                          │   │  │
│  │  └─────────────────────────────────────────────────┘   │  │
│  │                         │                                │  │
│  └─────────────────────────┼────────────────────────────────┘  │
│                            │ (Task Submission via Cluster Mgr) │
└────────────────────────────┼──────────────────────────────────┘
                             │
                 ┌───────────┼───────────┐
                 │           │           │
        ┌────────▼────┐ ┌────▼───────┐ ┌─▼──────────┐
        │   Worker 1  │ │  Worker 2  │ │  Worker 3  │
        │ ┌──────────┐│ │┌──────────┐│ │┌──────────┐│
        │ │Executor 1││ ││Executor 2││ ││Executor 3││
        │ │ Task 1,2 ││ ││ Task 3,4 ││ ││ Task 5,6 ││
        │ │ Cache    ││ ││ Cache    ││ ││ Cache    ││
        │ └──────────┘│ │└──────────┘│ │└──────────┘│
        └─────────────┘ └────────────┘ └───────────┘
```

### Execution Flow

```
User Code
    │
    ▼
SparkContext.action() (count, collect, save, etc.)
    │
    ▼
DAG (Directed Acyclic Graph) Scheduler
    │ Creates logical plan
    ▼
Task Scheduler (Converts DAG to stages)
    │
    ▼
┌─────────────────────────────────────┐
│  Stage 1: Map Tasks (narrow)        │ ◄─── No shuffle
├─────────────────────────────────────┤
│  Shuffle Barrier                    │ ◄─── Wide transformation
├─────────────────────────────────────┤
│  Stage 2: Reduce Tasks (narrow)     │ ◄─── No shuffle
└─────────────────────────────────────┘
    │
    ▼
Task Executor (on Worker nodes)
    │
    ▼
Result back to Driver
```

### Key Components Explained

```scala
// 1. SPARK CONTEXT: Old API (RDDs)
val sc = SparkContext("local[4]", "AppName")
// - Represents connection to cluster
// - Creates RDDs
// - Deprecated in favor of SparkSession

// 2. SPARK SESSION: New API (DataFrames/Datasets)
val spark = SparkSession
  .builder()
  .appName("MyApp")
  .master("spark://master:7077")  // or "yarn", "k8s://", "local[*]"
  .config("spark.executor.memory", "4g")
  .getOrCreate()

// 3. SQL CONTEXT: For SQL operations
// Included in SparkSession now (spark.sql())

// 4. STREAMING CONTEXT: For streaming
val streamingContext = new StreamingContext(sc, Seconds(10))

// Configuration Hierarchy:
// 1. Command line flags (--conf spark.executor.memory=4g)
// 2. Application code (.config())
// 3. spark-defaults.conf
// 4. Hard-coded defaults
```

---

## RDD vs DataFrame vs Dataset

### Comparison Table

```
┌──────────────┬─────────────────┬───────────────────┬────────────────────┐
│ Aspect       │ RDD             │ DataFrame         │ Dataset            │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Type         │ Untyped         │ Partially Typed   │ Strongly Typed     │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Optimization │ No              │ Yes (Catalyst)    │ Yes (Catalyst)     │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Language     │ Scala, Python   │ All               │ Scala, Java        │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Performance  │ Slowest         │ Faster            │ Fastest            │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ API          │ Functional      │ SQL + Functional  │ Functional + OO    │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Schema       │ No              │ Yes               │ Yes                │
├──────────────┼─────────────────┼───────────────────┼────────────────────┤
│ Serialization│ Java            │ Spark SQL         │ Encoder            │
└──────────────┴─────────────────┴───────────────────┴────────────────────┘
```

### Code Examples

```scala
// RDD: Low-level API
val rdd = sc.parallelize(1 to 1000)
  .map(x => (x % 10, x))
  .groupByKey()
  .mapValues(_.sum)

// DataFrame: SQL-like API
val df = spark.createDataFrame(
  Seq((1, "a"), (2, "b"), (3, "c"))
).toDF("id", "name")

val result = df
  .groupBy("name")
  .agg(sum("id"))

// Dataset: Strongly-typed API
case class Person(id: Int, name: String)

val ds = spark.createDataset(
  Seq(Person(1, "Alice"), Person(2, "Bob"))
)

val result = ds
  .groupByKey(_.name)
  .mapGroups { case (name, persons) =>
    (name, persons.map(_.id).sum)
  }
```

### Performance Characteristics

```
Operation Performance Comparison:
(Lower is better)

Filtering 1M rows:
├─ RDD.filter(): ██████████ 100ms
├─ DataFrame.filter(): ██ 20ms (5x faster)
└─ Dataset.filter(): ██ 22ms

Aggregation on 1M rows:
├─ RDD.reduceByKey(): ████████ 80ms
├─ DataFrame.groupBy().agg(): ██ 15ms (5x faster)
└─ Dataset.groupByKey(): ██ 18ms

Join 2 DataFrames (1M x 100K rows):
├─ RDD.join(): ███████████████ 150ms
├─ DataFrame.join(): ███ 30ms (5x faster)
└─ Dataset.joinWith(): ███ 32ms

Why DataFrames are faster:
1. Catalyst Optimizer
2. Tungsten (memory optimization)
3. Predicate pushdown
4. Schema awareness
```

---

## Execution Plan & Query Optimization

### Query Optimization Pipeline

```
SQL Query / DataFrame API
    │
    ▼
┌────────────────────────────────┐
│ 1. Parser                       │ ◄─── Syntax check
└────────────────────────────────┘
    │
    ▼
┌────────────────────────────────┐
│ 2. Analyzer                     │ ◄─── Schema validation
│    - Table resolution           │      Type checking
│    - Column resolution          │
└────────────────────────────────┘
    │
    ▼
┌────────────────────────────────┐
│ 3. Logical Plan                 │ ◄─── Abstract syntax tree
│    - Filter, Project, Join      │
└────────────────────────────────┘
    │
    ▼
┌────────────────────────────────┐
│ 4. Optimizer (Catalyst)         │ ◄─── Query rewriting
│    - Predicate pushdown         │      Expression optimization
│    - Constant folding           │      Join ordering
│    - Column pruning             │
└────────────────────────────────┘
    │
    ▼
┌────────────────────────────────┐
│ 5. Physical Plan Selection      │ ◄─── Multiple strategies
│    - Broadcast Join?            │      Hash Join?
│    - Sort Merge Join?           │
└────────────────────────────────┘
    │
    ▼
┌────────────────────────────────┐
│ 6. Code Generation (Tungsten)   │ ◄─── Compile to bytecode
│    - Column-at-a-time exec      │
└────────────────────────────────┘
    │
    ▼
Task Execution
```

### Using EXPLAIN to Analyze Plans

```scala
val df = spark.read.parquet("/data/events")
  .filter(col("amount") > 100)
  .groupBy("category")
  .agg(sum("amount"))

// Logical plan only
df.explain(extended = false)

// Output example:
// == Physical Plan ==
// *(2) HashAggregate(keys=[category#10], 
//                    functions=[sum(amount#11)],
//                    output=[category#10, sum(amount)#12L])
// +- Exchange hashpartitioning(category#10, 200), 
//                               true, [id=#15]
//    +- *(1) HashAggregate(keys=[category#10], 
//                          functions=[partial_sum(amount#11)],
//                          output=[category#10, sum#14L])
//       +- *(1) Filter (amount#11 > 100)
//          +- *(1) FileScan parquet [amount#11,category#10]

// Full logical + physical plans
df.explain(extended = true)

// Show all stages of optimization
df.explain(mode = "extended")
```

### Optimization Techniques

```scala
// TECHNIQUE 1: Predicate Pushdown (automatic)
// ❌ Bad: Filter applied AFTER join
val bad = events.join(users, "user_id")
  .filter(col("events.amount") > 100)

// ✅ Good: Optimizer pushes filter before join
val good = events
  .filter(col("amount") > 100)
  .join(users, "user_id")

// TECHNIQUE 2: Column Pruning (automatic)
// ❌ Bad: Select all columns then filter
val bad = events.join(users, "user_id")
  .select(col("user_id"), col("name"))  // Only these needed

// ✅ Good: Select specific columns early
val good = events.select("user_id", "amount")
  .join(users.select("user_id", "name"), "user_id")

// TECHNIQUE 3: Join Reordering (automatic)
// ❌ Suboptimal: Large table first
val bad = largeTable.join(smallTable1).join(smallTable2)

// ✅ Optimal: Broadcast small tables
val good = largeTable
  .join(broadcast(smallTable1), "id1")
  .join(broadcast(smallTable2), "id2")

// TECHNIQUE 4: Constant Folding (automatic)
// ❌ Computed at runtime
val bad = df.filter(col("date") > (currentDate - 30))

// ✅ Computed at compile time
val good = df.filter(col("date") > "2024-01-15")

// TECHNIQUE 5: Early Filtering
// ❌ Processes all data in expensive join
val bad = df1.join(df2, "id")
  .filter(col("df1.status") == "active")

// ✅ Filters before join
val good = df1
  .filter(col("status") == "active")
  .join(df2, "id")
```

---

## Memory Management

### Memory Architecture

```
Total Executor Memory
│
├─ Reserved Memory (300MB minimum)
│  └─ System reserved
│
└─ Usable Memory (Total - Reserved)
   │
   ├─ Execution Memory (spark.memory.fraction default 0.6)
   │  │
   │  ├─ Shuffle buffers
   │  ├─ Sort buffers
   │  ├─ Join hash tables
   │  └─ Aggregation hash tables
   │
   ├─ Storage Memory (1 - spark.memory.fraction)
   │  │
   │  ├─ RDD Cache
   │  ├─ DataFrame Cache
   │  └─ Broadcast variables
   │
   └─ User Memory (Spark 3.0+)
      └─ Available for custom data structures


Example with executor.memory = 4GB:

4GB Total
│
├─ 300MB Reserved
│
└─ 3700MB Usable
   │
   ├─ 2220MB Execution (60%)
   │  ├─ Hash tables
   │  ├─ Sort buffers
   │  └─ Shuffle blocks
   │
   ├─ 1480MB Storage (40%)
   │  ├─ Cached RDDs
   │  ├─ Cached DataFrames
   │  └─ Broadcast variables
   │
   └─ User code memory
```

### Memory Tuning Strategies

```scala
// Configuration
spark.conf.set("spark.executor.memory", "8g")
spark.conf.set("spark.memory.fraction", 0.6)  // 60% for Spark operations
spark.conf.set("spark.memory.storageFraction", 0.5)  // 50% of usable for storage

// Monitor memory usage
spark.sparkContext.statusTracker.executorInfos.foreach { execInfo =>
  println(s"Executor ${execInfo.executorId}: ${execInfo.maxMemory}MB max")
}

// 1. Reduce memory usage: Use smaller data types
// ❌ Bad
val df = spark.createDataFrame(
  Seq((1.0, 2.0, 3.0, 4.0, 5.0))
).toDF("a", "b", "c", "d", "e")

// ✅ Good: Use Float instead of Double (4 bytes vs 8 bytes)
val df = spark.createDataFrame(
  Seq((1f, 2f, 3f, 4f, 5f))
).toDF("a", "b", "c", "d", "e")

// 2. Persist with right storage level
import org.apache.spark.storage.StorageLevel

rdd.persist(StorageLevel.MEMORY_ONLY)          // 1GB data = 1GB memory
rdd.persist(StorageLevel.MEMORY_AND_DISK)      // 1GB data = 1GB memory + overflow to disk
rdd.persist(StorageLevel.DISK_ONLY)            // Fast for reuse
rdd.persist(StorageLevel.MEMORY_AND_DISK_SER)  // Serialized = more compact

// Serialization saves space (50-75% reduction typical)
rdd.persist(StorageLevel.MEMORY_ONLY_SER)      // Serialized in memory

// 3. Monitor GC (Garbage Collection)
spark.conf.set("spark.driver.extraJavaOptions", "-XX:+PrintGCDetails -XX:+PrintGCTimeStamps")

// 4. Adjust shuffle memory fraction
spark.conf.set("spark.shuffle.memoryFraction", 0.2)  // 20% for shuffle
spark.conf.set("spark.shuffle.consolidateFiles", "true")

// 5. Spill configuration
spark.conf.set("spark.shuffle.spill", "true")      // Allow spill to disk
spark.conf.set("spark.shuffle.spill.compress", "true")

// 6. Broadcast variable memory
val largeList = (1 to 1000000).toList
val broadcastVar = spark.sparkContext.broadcast(largeList)
// Distributes to each executor once, reused by all tasks

// 7. Reduce shuffling - group operations
// ❌ Multiple shuffles
val result1 = df.groupBy("id").agg(sum("amount"))
val result2 = df.groupBy("id").agg(count("*"))

// ✅ Single shuffle
val result = df
  .groupBy("id")
  .agg(
    sum("amount").alias("total"),
    count("*").alias("count")
  )
```

---

## Partitioning & Shuffling

### Partitioning Concepts

```
RDD/DataFrame with 4 Partitions:

┌─────────────────────────────────────────────┐
│            Original Data                    │
│  [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16] │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │           │
    ┌───▼──┐   ┌───▼──┐   ┌───▼──┐   ┌───▼──┐
    │ P0   │   │ P1   │   │ P2   │   │ P3   │
    │1,2,3 │   │4,5,6 │   │7,8,9 │   │10... │
    │ 4,5  │   │ 7,8  │   │10,11 │   │...16 │
    │      │   │      │   │ 12   │   │      │
    └──────┘   └──────┘   └──────┘   └──────┘
    (Executor (Executor (Executor (Executor
      1)        2)        3)        4)


Partition Locality (Data Locality):
├─ PROCESS_LOCAL: Data on same JVM (best)
├─ NODE_LOCAL: Data on same node (2-3x slower)
├─ RACK_LOCAL: Data on same rack (10x slower)
└─ ANY: Data anywhere (30x slower)
```

### Shuffling Process

```
Shuffle Illustration:
(groupBy with key redistribution)

Input: RDD with (key, value) pairs

Partition 0: (A, 1), (B, 2), (A, 3)
Partition 1: (B, 4), (A, 5), (C, 6)
Partition 2: (A, 7), (C, 8), (B, 9)

                    │
                    ▼
        ┌──────────────────────┐
        │ Shuffle Write Phase  │
        │ (Partition locally)  │
        └──────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
    Partition 0: Partition 1: Partition 2:
    (A->1,3,5,7) (B->2,4,9)  (C->6,8)
        │           │           │
        └───────────┼───────────┘
                    │
                    ▼
        ┌──────────────────────┐
        │ Shuffle Read Phase   │
        │ (Network transfer)   │
        └──────────────────────┘
                    │
                    ▼
        ┌──────────────────────┐
        │ Reduce Task          │
        │ aggregate(A->sum=16) │
        └──────────────────────┘

Total Data Transferred = Shuffle overhead
```

### Partitioning Strategies

```scala
// Strategy 1: Default partitioning (hash)
val df = spark.read.parquet("/data/events")
val shuffled = df.groupBy("user_id").count()
// Partitions = spark.sql.shuffle.partitions (default 200)

// Strategy 2: Custom number of partitions
val repartitioned = df.repartition(100)  // Shuffle to N partitions
val coalesced = df.coalesce(50)          // Reduce without full shuffle

// Difference: repartition() vs coalesce()
// repartition(N):
//   └─ Always shuffles
//   └─ Can increase or decrease partitions
//   └─ Slower but more controlled
//   └─ Use when N > current partitions

// coalesce(N):
//   └─ Only shuffles if N < current
//   └─ Can only decrease partitions
//   └─ Faster for reducing partitions
//   └─ Use when N < current partitions

// Strategy 3: Partitioning by column (for storage)
val optimized = df.write
  .partitionBy("date", "region")
  .parquet("/output/data")

// Creates directory structure:
// /output/data/
// ├─ date=2024-01-01/region=us/...parquet
// ├─ date=2024-01-01/region=eu/...parquet
// └─ date=2024-01-02/region=us/...parquet

// Strategy 4: Bucketing (for joins)
df.write
  .bucketBy(10, "user_id")
  .mode("overwrite")
  .parquet("/output/bucketed")

// Creates sorted buckets -> faster joins
// Bucket 0: user_id hash % 10 == 0
// Bucket 1: user_id hash % 10 == 1
// ...

// Strategy 5: Custom partitioner for RDDs
val rdd = sc.parallelize(1 to 100)
val custom = rdd
  .map(x => (x % 5, x))
  .partitionBy(new org.apache.spark.HashPartitioner(5))

// Strategy 6: Monitor partition size
val df = spark.read.parquet("/data")
println(s"Number of partitions: ${df.rdd.getNumPartitions}")
println(s"Total rows: ${df.count()}")
println(s"Avg rows per partition: ${df.count() / df.rdd.getNumPartitions}")

// Optimal partition size: 128MB - 256MB per partition
val targetPartitionMB = 200
val totalSizeMB = 10000  // 10GB
val optimalPartitions = (totalSizeMB / targetPartitionMB).ceil.toInt
// = 50 partitions
```

---

## Caching & Persistence

### Cache Hierarchy

```
Storage Levels (trade-off: Speed vs Memory):

MEMORY_ONLY
├─ Speed: ██████████ (fastest)
├─ Size: Full size of RDD
├─ CPU: Low
└─ Risk: OOM if data > memory

MEMORY_AND_DISK
├─ Speed: █████████ (fast)
├─ Size: Memory + disk overflow
├─ CPU: Low
└─ Risk: Disk I/O if spill occurs

MEMORY_ONLY_SER
├─ Speed: ████████ (medium)
├─ Size: 50-75% reduction via serialization
├─ CPU: Medium (serialize/deserialize)
└─ Risk: Slower than MEMORY_ONLY

MEMORY_AND_DISK_SER
├─ Speed: ███████ (medium)
├─ Size: Serialized memory + disk
├─ CPU: Medium
└─ Risk: Balanced

DISK_ONLY
├─ Speed: ██ (slowest)
├─ Size: Disk (very large)
├─ CPU: I/O bound
└─ Risk: Disk latency
```

### When to Cache

```scala
// ✅ GOOD: Cache if used multiple times
val df = spark.read.parquet("/data")
val cached = df.cache()

val count = cached.count()      // First: Compute and cache
val filtered = cached.filter(...) // Second: Use cache
val grouped = cached.groupBy(...)  // Third: Use cache

cached.unpersist()

// ❌ BAD: Cache if used once
val result = df.cache().count()  // Unnecessary caching

// ❌ BAD: Cache large intermediate results
val huge = df.repartition(1000).cache()  // Could cause OOM

// ✅ GOOD: Cache expensive computations
val expensive = df
  .filter(complexCondition)
  .join(otherDF, "key")
  .cache()

val result1 = expensive.agg(...)
val result2 = expensive.filter(...)

// ✅ GOOD: Cache with appropriate storage level
val serialized = df.persist(StorageLevel.MEMORY_AND_DISK_SER)

// Monitoring cache
spark.sparkContext.getRDDStorageInfo.foreach { info =>
  println(s"RDD ${info.id}: ${info.memSize} bytes in memory")
}

// Cache eviction policy
// When memory fills up:
// 1. Evict oldest cached RDD
// 2. If all RDDs same priority: evict oldest partitions
// 3. LRU (Least Recently Used) strategy
```

---

## Interview Tips & Summary

### Key Takeaways

```
1. ARCHITECTURE
   └─ Driver submits tasks to executors via cluster manager
   └─ Executors process data in parallel
   └─ Data shuffled between stages

2. DATA STRUCTURES
   └─ RDD: Untyped, low-level (avoid for new code)
   └─ DataFrame: SQL-optimized, recommended
   └─ Dataset: Strongly-typed, Scala/Java

3. OPTIMIZATION
   └─ Let Catalyst optimize your queries
   └─ Broadcast small tables
   └─ Push filters early
   └─ Prune unnecessary columns

4. MEMORY
   └─ Monitor GC pauses
   └─ Cache strategically
   └─ Use serialization for large objects
   └─ Tune executor memory based on workload

5. PARTITIONING
   └─ 128MB - 256MB per partition
   └─ Partition storage by query access patterns
   └─ Avoid skew (uneven distribution)
   └─ Use bucketing for frequent joins

6. DEBUGGING
   └─ Use .explain() to understand plans
   └─ Monitor Spark UI
   └─ Check event logs
   └─ Use accumulators for metrics
```


