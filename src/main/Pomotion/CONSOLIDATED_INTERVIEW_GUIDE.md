# Complete Data Engineering & Leadership Interview Guide
**Comprehensive Questions and Answers - All Topics**

## Table of Contents
1. [Apache Spark - Core Concepts](#apache-spark---core-concepts)
2. [Apache Spark - Performance & Optimization](#apache-spark---performance--optimization)
3. [Spark SQL & DataFrame API](#spark-sql--dataframe-api)
4. [Spark Streaming & Real-Time Processing](#spark-streaming--real-time-processing)
5. [Data Formats & File Storage](#data-formats--file-storage)
6. [Delta Lake](#delta-lake)
7. [Databricks](#databricks)
8. [Data Quality & Governance](#data-quality--governance)
9. [Data Warehouse & Data Lake Architecture](#data-warehouse--data-lake-architecture)
10. [ETL Patterns & Pipelines](#etl-patterns--pipelines)
11. [Data Modeling](#data-modeling)
12. [AWS Services](#aws-services)
13. [Azure Services](#azure-services)
14. [GCP & Cloud Services](#gcp--cloud-services)
15. [Orchestration Tools](#orchestration-tools)
16. [Apache Kafka](#apache-kafka)
17. [Cloud Computing & Infrastructure](#cloud-computing--infrastructure)
18. [Python Programming](#python-programming)
19. [Scala Programming](#scala-programming)
20. [Database Design & SQL](#database-design--sql)
21. [Docker & Containerization](#docker--containerization)
22. [CI/CD & DevOps](#cicd--devops)
23. [Team Leadership & Management](#team-leadership--management)
24. [Project Management & Agile](#project-management--agile)
25. [Task Estimation & Planning](#task-estimation--planning)
26. [Soft Skills & Communication](#soft-skills--communication)
27. [Testing & Quality Assurance](#testing--quality-assurance)
28. [Professional Development](#professional-development)
29. [GenAI & LLM Systems](#genai--llm-systems)
30. [System Design & Architecture](#system-design--architecture)

---

## Apache Spark - Core Concepts

### Q1: Why is RDD immutable?

**Answer:**
RDD (Resilient Distributed Dataset) immutability is fundamental to Spark's fault tolerance model:

- **Fault Tolerance**: Once created, RDDs cannot be changed. If a partition is lost, Spark can recompute it using the original transformation lineage
- **Deterministic Recomputation**: Every transformation is deterministic, ensuring identical results when recomputed
- **Lineage Tracking**: Immutability allows Spark to maintain DAG (Directed Acyclic Graph) of transformations
- **Parallel Safety**: Immutable objects are inherently thread-safe, enabling safe parallel processing without synchronization overhead
- **Memory Optimization**: Multiple versions don't need to be stored; only transformations are recorded

### Q2: How garbage collection happens in Spark?

**Answer:**
Spark's garbage collection involves multiple layers:

- **JVM Garbage Collection**: Executor processes run on JVM, which uses generational GC (Young and Old generation)
- **Executor Memory**: Divided into execution memory (shuffle/join operations) and storage memory (cached RDDs/DataFrames)
- **Serialization**: Objects are serialized before being sent across network, reducing GC pressure
- **Young Generation GC**: Fast, happens frequently on newly created objects
- **Full GC**: Occurs when old generation fills up, causing longer pauses
- **Tuning Tips**:
  - Increase executor memory if GC pauses are frequent
  - Use `spark.executor.memoryOverhead` for off-heap memory
  - Tune `spark.memory.fraction` to balance execution and storage
  - Monitor GC logs: `-XX:+PrintGCDetails -XX:+PrintGCTimeStamps`

### Q3: Describe Spark Framework - main capabilities and why it's called a framework?

**Answer:**
Spark is a unified analytics engine with several key capabilities:

**Spark Unified Analytics Platform Architecture:**
```
┌────────────────────────────────────────────────────────────────┐
│                   SPARK SQL & DATAFRAMES                       │
│  (Structured data processing, SQL queries, DataFrame API)      │
└────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼─────────────────────────────────┐
│                             │                                 │
▼                             ▼                                 ▼
┌──────────────────┐  ┌───────────────────┐  ┌──────────────────┐
│  SPARK STREAMING │  │  MLlib (ML)       │  │  GraphX (Graph)  │
│  (Real-time)     │  │  (Machine Learning)   │ (Graph Processing)
└──────────────────┘  └───────────────────┘  └──────────────────┘
│                             │                                 │
└─────────────────────────────┼─────────────────────────────────┘
                              │
                              ▼
                ┌──────────────────────────────┐
                │     SPARK CORE (RDD)         │
                │  - Low-level APIs            │
                │  - Fault tolerance           │
                │  - Task scheduling           │
                │  - DAG management            │
                └──────────────────────────────┘
                              │
                              ▼
            ┌──────────────────────────────────────┐
            │   CLUSTER MANAGER & SCHEDULER        │
            │  • Standalone  • YARN  • Mesos       │
            │  • Kubernetes  • Databricks          │
            └──────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
            ▼                 ▼                 ▼
         ┌─────────┐     ┌─────────┐     ┌─────────┐
         │Executor │     │Executor │     │Executor │
         │  Tasks  │     │  Tasks  │     │  Tasks  │
         └─────────┘     └─────────┘     └─────────┘
```

1. **Core Components:**
   - Spark Core: Low-level APIs (RDD)
   - Spark SQL: Structured data processing
   - Spark Streaming: Real-time streaming
   - MLlib: Machine learning
   - GraphX: Graph processing

2. **Why It's Called a Framework:**
   - Provides abstractions and APIs for data processing
   - Offers optimization layer (Catalyst optimizer)
   - Handles resource management and scheduling
   - Supports multiple programming languages (Python, Scala, Java, SQL, R)

### Q4: How does Spark run the code? Explain plan generation.

**Answer:**
Spark's execution pipeline:

**Visual Execution Flow:**
```
┌─────────────────────────────────────────────────────────────┐
│                    USER CODE / SQL QUERY                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              PARSE PHASE (SQL Parser / DAG)                 │
│  - Create AST (Abstract Syntax Tree)                        │
│  - Convert to logical operators                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         CATALYST OPTIMIZER (Logical → Optimized)            │
│  ✓ Predicate Pushdown    ✓ Column Pruning                   │
│  ✓ Constant Folding      ✓ Join Reordering                  │
│  ✓ Null Propagation      ✓ Expression Simplification        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         PHYSICAL PLANNING (Optimized → Physical)            │
│  - Multiple strategies evaluated                            │
│  - Cost-based selection                                     │
│  - Best execution plan chosen                               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│          CODE GENERATION & COMPILATION (Tungsten)           │
│  - Bytecode generation                                      │
│  - Memory optimization                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           EXECUTION ENGINE (DAG Scheduler)                  │
│  - DAG (Directed Acyclic Graph) created                     │
│  - Split into stages                                        │
│  - Stages split into tasks                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
      ┌──────────────────┼──────────────────┐
      ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Executor 1  │   │  Executor 2  │   │  Executor N  │
│  (Tasks)     │   │  (Tasks)     │   │  (Tasks)     │
└──────────────┘   └──────────────┘   └──────────────┘
      │                  │                  │
      └──────────────────┼──────────────────┘
                         │
                         ▼
               ┌─────────────────────┐
               │  RESULT COLLECTION  │
               │  (Back to Driver)   │
               └─────────────────────┘
```

1. **Parse Phase:**
   - User writes code/SQL query
   - Creates logical data structures (RDD, DataFrame, SQL AST)

2. **Plan Generation:**
   - **Logical Plan**: Shows transformations needed (Analyzer phase)
   - **Optimized Logical Plan**: Catalyst optimizer applies rules (predicate pushdown, constant folding)
   - **Physical Plan**: Multiple physical strategies evaluated, best one selected

3. **Execution Phase:**
   - Physical plan compiled to RDD operations
   - DAG (Directed Acyclic Graph) created
   - Stages and tasks created from DAG
   - Tasks distributed to executors
   - Results collected back to driver

4. **Optimization Examples:**
   - Predicate pushdown (filter early)
   - Column pruning
   - Constant folding
   - Join optimization (broadcast vs shuffle)

### Q5: When Spark might not be a good choice?

**Answer:**
Consider alternatives when:

1. **Ultra-low latency**: Needs <100ms response time → Use stream processing (Kafka Streams, Flink)
2. **Single-machine processing**: Small data (<1GB) → Use Pandas, Dask
3. **Complex iterative algorithms**: ML algorithms with many iterations → Use specialized ML frameworks (TensorFlow, PyTorch)
4. **OLTP operations**: Real-time transactional updates → Use databases (PostgreSQL, MongoDB)
5. **Unstructured data processing**: Heavy NLP/image tasks → Use specialized frameworks
6. **Cost constraints**: Overhead of cluster not justified for small workloads

**Alternatives:**
- Small data: Pandas, Polars, DuckDB
- Real-time: Kafka Streams, Flink, Kinesis
- ML: TensorFlow, PyTorch, Scikit-learn
- OLTP: PostgreSQL, MongoDB, DynamoDB

### Q6: How can we run Spark Jobs in AWS environment?

**Answer:**
Multiple approaches with advantages/disadvantages:

1. **EC2 (Manual Setup)**
   - Advantages: Full control, flexible
   - Disadvantages: Manual management, complex setup

2. **EMR (Elastic MapReduce)**
   - Advantages: Managed Hadoop/Spark, auto-scaling, cost-optimized
   - Disadvantages: Less control than EC2

3. **AWS Glue**
   - Advantages: Serverless, integrated with AWS services
   - Disadvantages: Limited flexibility, vendor lock-in

4. **Databricks**
   - Advantages: Fully managed, optimized, Unity Catalog
   - Disadvantages: Additional cost layer

5. **AWS Lambda**
   - Advantages: Serverless, no infrastructure
   - Disadvantages: Limited to small jobs (<15 min)

### Q7: When should you use Apache Spark vs Apache Flink?

**Answer:**

| Aspect | Apache Spark | Apache Flink |
|--------|-------------|------------|
| **Processing Model** | Micro-batch streaming | True/continuous streaming |
| **Latency** | Higher (batch intervals) | Lower (event-at-a-time) |
| **Exactly-Once Semantics** | Supported | Native support |
| **State Management** | Good | Better for complex state |
| **Ecosystem** | Larger (SQL, MLlib) | Growing ecosystem |
| **Learning Curve** | Easier for batch users | Steeper |

**When to use Spark:**
- Batch processing with occasional streaming
- Need for SQL/MLlib integration
- Larger ecosystem and community support
- Teams familiar with Spark

**When to use Flink:**
- Real-time processing with low latency (<1s)
- Complex event processing
- Stateful processing needs
- True streaming semantics required

### Q8: What built-in optimization mechanisms does Spark have?

**Answer:**

1. **Catalyst Optimizer**: Query optimization engine
   - Predicate pushdown
   - Column pruning
   - Constant folding
   - Join reordering

2. **Tungsten**: Memory and code generation
   - Efficient memory management
   - Optimized bytecode generation

3. **Adaptive Query Execution (AQE)**:
   - Dynamic coalescing
   - Skew join optimization
   - Broadcast join optimization

### Q9: What is horizontal and vertical scaling in Spark?

**Answer:**

**Vertical Scaling (Scale Up):**
- Increase resources per executor
- More CPU cores per executor
- More memory per executor
- **Pros**: Simpler, better GC behavior
- **Cons**: Hardware limitations, diminishing returns

**Horizontal Scaling (Scale Out):**
- Increase number of executors
- More worker nodes in cluster
- Distribute computation across machines
- **Pros**: Nearly linear scaling, unlimited growth
- **Cons**: Network overhead, coordination complexity

**When to Use:**
- **Vertical**: Single large job, 50-100GB data
- **Horizontal**: Multiple jobs, TBs of data
- **Hybrid**: Most enterprise scenarios

### Q10: Which cluster configuration is better - 100 nodes 10 cores or 5 nodes 200 cores?

**Answer:**

**100 Nodes × 10 Cores:**
- Advantages: Better parallelism, fault tolerance, scalability
- Disadvantages: Network overhead, coordination complexity
- Best for: Large datasets, high parallelism needs

**5 Nodes × 200 Cores:**
- Advantages: Less network traffic, simpler coordination
- Disadvantages: Single point of failure, limited fault tolerance
- Best for: Tightly coupled operations, shared memory needs

**Recommendation**: 100 nodes × 10 cores for large data processing

---

## Apache Spark - Performance & Optimization

### Q11: Steps when your Spark job runs for very long time?

**Answer:**

1. **Immediate Assessment:**
   - Check Spark UI for bottlenecks
   - Identify which stage is taking longest
   - Monitor resource usage (CPU, memory)
   - Check for data skew

2. **Investigation:**
   - Review execution plan: `df.explain()`
   - Check shuffle sizes between stages
   - Look for full table scans instead of filtered reads
   - Identify any cross joins or expensive operations

3. **Optimization Strategies:**
   - **Increase Parallelism**: Adjust partition count
   - **Enable AQE**: Adaptive Query Execution
   - **Bucketing**: Pre-bucket for joins
   - **Caching**: Cache intermediate results
   - **Predicate Pushdown**: Filter early
   - **Repartition**: Balance data across executors

4. **Configuration Tuning:**
   - Increase executor memory and cores
   - Adjust shuffle partitions
   - Enable aggressive compression

5. **If Still Slow:**
   - Consider algorithmic changes
   - Evaluate alternative architectures (Flink, batch vs streaming)
   - Profile with JVM tools (JProfiler, YourKit)

### Q12: Your data pipeline talks to Hive and Hive is a bottleneck. How to improve?

**Answer:**

1. **Assessment Phase:**
   - Profile Hive queries using EXPLAIN EXTENDED
   - Check table statistics: `ANALYZE TABLE table_name COMPUTE STATISTICS`
   - Identify slow queries using Hive logs

2. **Optimization Strategies:**
   - **Indexing**: Create indexes on frequently filtered columns
   - **Partitioning**: Partition tables by commonly filtered dimensions
   - **Bucketing**: Bucket tables for join optimization
   - **Statistics**: Keep table statistics updated
   - **Query Optimization**: Rewrite queries to use predicate pushdown

3. **Architectural Solutions:**
   - **Cache in Spark**: Load Hive data once and cache it
   ```scala
   val data = spark.sql("SELECT * FROM hive_table")
   data.cache()
   data.count()  // Force evaluation
   ```
   - **Switch to Delta/Parquet**: Migrate from Hive to Delta Lake for better performance
   - **Data Export**: ETL data from Hive to faster storage (S3, HDFS)
   - **Connection Pooling**: Use connection pooling for JDBC queries

4. **Configuration Tuning:**
   - Increase Hive fetch size: `hive.fetch.task.conversion=more`
   - Enable CBO: `hive.cbo.enable=true`
   - Parallel execution: `hive.exec.parallel=true`

### Q13: How would you measure performance of your Spark job?

**Answer:**

1. **Key Metrics to Track:**
   - **Job Duration**: Total time from start to finish
   - **Stage Duration**: Time per stage
   - **Task Duration**: Individual task execution time
   - **Shuffle Write/Read**: Data transferred
   - **GC Time**: Garbage collection overhead
   - **CPU and Memory Utilization**

2. **Measurement Tools/APIs:**
   - **Spark UI**: Built-in web interface (port 4040)
   - **Spark History Server**: Persisted logs
   - **Metrics from logs**: Application logs
   - **External tools**: Prometheus + Grafana, Datadog, CloudWatch

3. **Implementation Example:**
   ```python
   import time
   start = time.time()
   df.write.parquet("path")
   duration = time.time() - start
   print(f"Total time: {duration} seconds")
   ```

4. **Decision Framework:**
   - Compare against SLA
   - Analyze bottlenecks (CPU, I/O, Memory, Network)
   - Profile critical stages

### Q14: Explain partition pruning and predicate pushdown optimization

**Answer:**

Spark combines these strategies for maximum performance:

1. **Partition Pruning:**
   - Skips entire partitions based on filter predicates
   - Example: `WHERE year=2022` skips year=2023 directories
   - Works on directory structure: `/sales/year=2022/region=APAC/`

2. **Predicate Pushdown:**
   - Applies filters at file read time (within Parquet, Delta)
   - Reads only necessary columns and rows
   - Reduces data transferred to memory

3. **Combined Strategy:**
   ```
   Query: SELECT * FROM sales WHERE year=2022 AND region='APAC'
   
   Step 1 (Pruning): Skip /sales/year=2023/ directory entirely
   Step 2 (Pushdown): Within /sales/year=2022/ files, filter for region='APAC'
   Result: Only relevant data blocks are read
   ```

4. **Example Files:**
   - Files NOT read: `/sales/year=2023/region=APAC/file.parquet`
   - Files read with filtering: `/sales/year=2022/region=APAC/file.parquet`
   - Files read with filtering: `/sales/year=2022/region=EU/file.parquet`

### Q15: Best Spark job performance improvement techniques

**Answer:**

**Spark Configurations:**
```scala
spark.conf.set("spark.sql.adaptive.enabled", "true")  // AQE
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")

// Memory management
spark.conf.set("spark.memory.fraction", "0.6")  // 60% for execution/storage
spark.conf.set("spark.memory.storageFraction", "0.5")  // 50% of 60% for storage

// Shuffle optimization
spark.conf.set("spark.shuffle.partitions", "200")
spark.conf.set("spark.shuffle.compress", "true")

// Parallelism
spark.conf.set("spark.default.parallelism", "200")
spark.conf.set("spark.sql.files.maxPartitionBytes", "128mb")
```

**Cluster Configurations:**
- **Executor Memory**: Balance between GC time and processing capacity
- **Executor Cores**: 4-8 cores per executor for optimal performance
- **Number of Executors**: Scale horizontally, but monitor overhead
- **Driver Memory**: Usually 4-8GB (handles scheduling only)
- **Dynamic Allocation**: Enable to scale based on demand

### Q16: How to solve Java heap space and Out of Memory issues?

**Answer:**

**Heap Space Issues:**

1. **Increase Executor Memory:**
   ```bash
   spark-submit --executor-memory 8g --driver-memory 4g script.py
   ```

2. **Adjust Memory Fractions:**
   ```scala
   spark.conf.set("spark.memory.fraction", "0.7")
   spark.conf.set("spark.memory.storageFraction", "0.4")
   ```

3. **Partition Optimization:**
   ```scala
   df.repartition(500)  // Increase parallelism
   df.coalesce(50)      // Reduce partitions
   ```

4. **Broadcast Threshold:**
   ```scala
   spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 50 * 1024 * 1024)
   ```

**Out of Memory Issues:**

1. **Use Iterator-based Transformations:**
   ```scala
   rdd.mapPartitions(partition => {
     val result = partition.map(transform)
     result
   })
   ```

2. **Spill to Disk:**
   ```scala
   spark.conf.set("spark.shuffle.spill", "true")
   spark.conf.set("spark.shuffle.memoryFraction", "0.2")
   ```

3. **Data Serialization:**
   ```scala
   spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
   ```

4. **Process in Batches:**
   - Load data in chunks instead of all at once
   - Use `foreachPartition` for better memory management

### Q17: How do you ensure Spark job runs optimally for memory and CPU?

**Answer:**

1. **Monitoring:**
   - Use Spark UI to monitor memory/CPU usage
   - Set up metrics collection: Prometheus + Grafana
   - Monitor executor GC logs

2. **Memory Optimization:**
   - Right-size executor memory based on workload
   - Use efficient data formats (Parquet with compression)
   - Cache only necessary data
   - Clear cache when done: `df.unpersist()`

3. **CPU Optimization:**
   - Increase partition count for parallelism
   - Use bucketing for join operations
   - Enable AQE (Adaptive Query Execution)
   - Optimize shuffle: reduce shuffle size, use broadcast joins

4. **Resource Allocation:**
   - Enable dynamic allocation for flexibility
   - Set appropriate executor cores (4-8 recommended)
   - Balance between driver and executor resources

5. **Code Optimization:**
   - Use DataFrames/SQL instead of RDDs
   - Avoid collect() on large DataFrames
   - Use explain() to check execution plans
   - Filter data early (predicate pushdown)

### Q18: Suppose you need to read large CSV in PySpark with OOM errors. How to resolve?

**Answer:**

1. **Immediate Fixes:**
   ```python
   spark = SparkSession.builder \
       .appName("LargeCSV") \
       .config("spark.executor.memory", "8g") \
       .config("spark.driver.memory", "4g") \
       .getOrCreate()

   df = spark.read.option("inferSchema", "false") \
              .option("header", "true") \
              .csv("large_file.csv")
   ```

2. **Optimize Reading:**
   ```python
   from pyspark.sql.types import StructType, StructField, StringType
   schema = StructType([StructField("col1", StringType())])
   df = spark.read.schema(schema).csv("file.csv")

   // Use chunking with repartition
   df = spark.read.csv("file.csv")
   df = df.repartition(100)  // Distribute data across more partitions
   ```

3. **Data Processing:**
   ```python
   // Filter early
   df = df.filter(df.year == 2023)

   // Use iterator-based operations
   def process_partition(iterator):
       for row in iterator:
           yield transform(row)

   df.rdd.mapPartitions(process_partition)
   ```

4. **Advanced Strategies:**
   - Process in smaller chunks
   - Use Pandas UDFs for efficient processing
   - Stream data instead of loading all at once
   - Use Delta format for better compression

### Q19: Your Spark application failed with undescriptive error. How would you debug?

**Answer:**

1. **Immediate Steps:**
   - Check Spark UI: Stages tab for failed tasks
   - Review executor logs in `spark-submit` output
   - Check driver logs for error messages

2. **Common Root Causes:**
   - **Memory**: OutOfMemory errors
   - **Network**: Executors not reachable from driver
   - **Timeout**: Executor took too long to respond
   - **Serialization**: Cannot serialize objects

3. **Debugging Approach:**
   ```bash
   spark-submit --conf spark.executor.logs.rolling.maxSize=100m \
                --conf spark.driver.logLevel=DEBUG \
                --conf spark.executor.logLevel=DEBUG script.py
   ```

4. **Investigation Steps:**
   - Check `/var/log/spark/` or application logs
   - Review network connectivity between driver and executors
   - Validate data serialization: test with `pickle` in Python
   - Check resource constraints: CPU, memory, disk space
   - Review stage execution times: identify slow stages

5. **Solutions:**
   - Increase executor memory
   - Reduce partition size
   - Increase timeout: `spark.executor.heartbeatInterval=60s`
   - Use KryoSerializer for serialization

### Q20: How does data skew impact Spark job performance?

**Answer:**

Data skew causes uneven distribution of data across partitions:

**Data Skew Impact Visualization:**
```
WITHOUT SKEW (Balanced):        WITH SKEW (Imbalanced):
┌──────────────────┐            ┌──────────────────┐
│ Executor 1 │████│ 10s         │ Executor 1 │███████████████│ 45s (Slow!)
├──────────────────┤            ├──────────────────┤
│ Executor 2 │████│ 10s         │ Executor 2 │██│ 2s (Idle)
├──────────────────┤            ├──────────────────┤
│ Executor 3 │████│ 10s         │ Executor 3 │█│ 1s (Idle)
└──────────────────┘            └──────────────────┘
Total Time: 10s                 Total Time: 45s (4.5x slower!)

Partition Size Distribution:
Without Skew:          With Skew:
[1000, 1050, 950]      [900000, 50, 30]  ← 18000x difference!
```

**Impacts:**

1. **Performance Degradation:**
   - Stragglers: Some tasks take much longer
   - Memory pressure: Some executors run out of memory
   - Network bottleneck: Uneven shuffle data
   - Idle resources: Other executors waiting
   - Overall time = Slowest task (always)

2. **Detection Techniques:**
   - Analyze task execution times (histogram)
   - Monitor GC times per executor
   - Check partition sizes in Spark UI
   - Use `df.rdd.mapPartitions(lambda x: [len(list(x))]).collect()`

3. **Mitigation Strategies:**
   - **Salt Technique**: Add random suffix to skewed keys
   - **Broadcast Join**: Use for small dimension tables
   - **Bucketing**: Pre-organize data by key
   - **Custom Partitioning**: Distribute skewed keys manually
   - **Separate Processing**: Handle skewed keys differently
   - **AQE (Adaptive Query Execution)**: Automatic optimization

**Salting Example:**
```python
# Before: customer_id is skewed
# After: Add random salt
df_salted = df.withColumn(
    "salted_id",
    concat(col("customer_id"), lit("_"), (rand() * 10).cast("int"))
)
# Now 18000 keys distributed to 10 buckets more evenly
```

### Q21: What are the key features of Spark's AQE?

**Answer:**

1. **AQE (Adaptive Query Execution) Features:**
   - **Dynamic Coalescing**: Combines small partitions
   - **Skew Join Optimization**: Handles skewed data
   - **Broadcast Join Optimization**: Automatically broadcasts smaller tables

2. **Example Optimization:**
   ```scala
   spark.conf.set("spark.sql.adaptive.enabled", "true")
   spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

   // With 200 partitions but little data
   // AQE coalesces to, e.g., 20 partitions automatically
   ```

3. **Broadcast Join Decision:**
   - Default threshold: 10MB (configurable)
   - AQE monitors query at runtime
   - If table < threshold, automatically broadcasts
   - Avoids expensive shuffle joins

4. **Benefits:**
   - Reduces shuffle operations
   - Better resource utilization
   - No manual tuning needed
   - Faster execution for variable data sizes

---

## Spark SQL & DataFrame API

### Q22: Spark SQL vs DataFrame API - Performance comparison?

**Answer:**

Both execute through the same Catalyst optimizer, but there are nuances:

1. **Performance Comparison:**
   - Generally equivalent for same logic
   - Both compile to same physical plan
   - Spark SQL slightly better for complex queries (optimizer has more context)
   - DataFrame API better for complex procedural logic

2. **When to use Spark SQL:**
   - Complex aggregations and JOINs
   - Standard SQL operations
   - Legacy SQL expertise

3. **When to use DataFrame API:**
   - Complex procedural transformations
   - Dynamic query construction
   - Type safety (Scala/Java)
   - Chainable operations

4. **Example:**
   ```python
   # SQL approach
   spark.sql("SELECT col1, COUNT(*) as cnt FROM table GROUP BY col1").show()
   
   # DataFrame approach
   df.groupBy("col1").count().show()
   
   # Both generate identical execution plans
   ```

### Q23: How would you investigate SQL query performance problem?

**Answer:**

Systematic approach to optimize slow queries:

1. **Investigation Steps:**
   - Check execution plan with `EXPLAIN EXTENDED`
   - Analyze Spark UI for bottleneck stages
   - Check data distribution and skew
   - Review table statistics with `ANALYZE TABLE`

2. **Common Issues and Solutions:**
   - **Slow Joins**: Use broadcast for small tables
   - **Shuffle Operations**: Reduce partitions if necessary
   - **Filter Late**: Apply WHERE before GROUP BY
   - **Missing Statistics**: Update table stats

3. **Project Example:**
   ```
   Slow Query (40 min): SELECT * FROM events JOIN users ON event.user_id = users.id
   Problem: Full outer join causing shuffle
   Solution: Use broadcast join since users table < 100MB
   Result: Optimized to 5 min
   
   Implementation: df_events.join(broadcast(df_users), "user_id")
   ```

### Q24: Can you compare dense rank, rank, and row number?

**Answer:**

| Function | Behavior | Use Case |
|----------|----------|----------|
| **ROW_NUMBER()** | Unique sequential number, no gaps | Generate surrogate keys, unique IDs |
| **RANK()** | Same rank for ties, gaps after ties | Rankings with ties (sports scores) |
| **DENSE_RANK()** | Same rank for ties, no gaps | Continuous ranking (no gaps in numbering) |

Example:
```
Score  ROW_NUMBER()  RANK()  DENSE_RANK()
100    1             1       1
100    2             1       1
90     3             3       2
90     4             3       2
80     5             5       3
```

---

## Spark Streaming & Real-Time Processing

### Q25: What is checkpointing in Spark Streaming? Types available?

**Answer:**

1. **Checkpointing Purpose:**
   - Saves state periodically
   - Enables recovery from failures
   - Maintains exactly-once semantics

2. **Implementation:**
   ```python
   ssc = StreamingContext(sc, 2)  // 2-second batch
   ssc.checkpoint("s3://checkpoints/app")

   dstream = ssc.socketTextStream("localhost", 9999)
   dstream.checkpoint(10)  // Checkpoint every 10 batches
   ```

3. **Types:**
   - **Metadata Checkpointing**: Saves DAG information, recovers from driver failures
   - **Data Checkpointing**: Saves RDD data, needed for stateful operations

4. **When Needed:**
   - Stateful transformations (updateStateByKey)
   - Window operations
   - Failure recovery

### Q26: Compare Spark Streaming with other streaming engines

**Answer:**

| Aspect | Spark Streaming | Apache Flink | Kafka Streams |
|--------|-----------------|--------------|---------------|
| **Latency** | 500ms (micro-batch) | <100ms | Depends on processing |
| **Model** | Micro-batch | True streaming | Event processing |
| **Exactly-Once** | Supported | Native | Supported |
| **State** | Good | Better | Good |
| **Ecosystem** | Large | Growing | Stream-only |
| **Setup** | Complex | Complex | Simple |

**Recommendation:**
- **Spark Streaming**: Existing Spark pipelines, batch+stream
- **Flink**: Low-latency requirements, complex state
- **Kafka Streams**: Stream processing on Kafka

### Q27: What is kappa architecture?

**Answer:**

Kappa architecture is a stream-only approach:
- All data flows through streaming pipeline
- No separate batch layer
- Real-time + historical data in same pipeline
- Better for event-driven systems

### Q28: How will you handle late coming data in Dataflow?

**Answer:**

In Apache Beam/Dataflow:

```python
from apache_beam import windowing

windowed_values = (
    data
    | 'Window' >> windowing.Window(
        windowing.FixedWindows(size=60),  # 1-minute windows
        allowed_lateness=600,  # Allow 10 minutes late data
        trigger=windowing.trigger.AfterWatermark(
            early=windowing.trigger.AfterCount(1),
            late=windowing.trigger.AfterCount(1)
        )
    )
    | 'Sum' >> beam.CombinePerKey(sum)
)
```

**Strategies:**
1. **Increase Allowed Lateness**: Balance with staleness
2. **Session Windows**: Better for event-driven processing
3. **Late Data Handling**: Separate late metrics, update with corrections

### Q29: Build real-time pipeline from Kafka to Delta Lake table - key components?

**Answer:**

Architecture and components:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, window

spark = SparkSession.builder.appName("KafkaToDelta").getOrCreate()

# 1. Read from Kafka
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "events") \
    .load()

# 2. Parse JSON
schema = "event_id STRING, timestamp LONG, value DOUBLE"
parsed_df = kafka_df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

# 3. Window aggregation
windowed_df = parsed_df \
    .withWatermark("timestamp", "10 minutes") \
    .groupBy(window("timestamp", "1 minute")) \
    .agg({"value": "sum"})

# 4. Write to Delta Lake
query = windowed_df.writeStream \
    .format("delta") \
    .mode("append") \
    .option("checkpointLocation", "path/checkpoint") \
    .option("mergeSchema", "true") \
    .start("path/to/delta/table")

query.awaitTermination()
```

**Key Considerations:**
- Watermarking for late data handling
- Checkpoint directory for fault recovery
- Schema evolution support
- Exactly-once semantics with Delta

### Q30: Difference between streaming live tables and incremental tables in DLT?

**Answer:**

**Incremental Tables:**
- Process only new data since last run
- Used for append-only pipelines
- Faster and more efficient

```sql
CREATE OR REFRESH INCREMENTAL TABLE customers AS
SELECT * FROM raw_customers
WHERE _commit_timestamp > table_version_at(prev_timestamp)
```

**Streaming Live Tables:**
- Continuously process streaming data
- True real-time (event-at-a-time)
- Lower latency

```sql
CREATE OR REFRESH STREAMING LIVE TABLE events AS
SELECT * FROM cloud_files('abfss://path', 'json')
```

**Comparison:**

| Aspect | Incremental | Streaming |
|--------|------------|-----------|
| **Latency** | Minutes/Hours | Seconds |
| **Cost** | Lower | Higher |
| **Complexity** | Simple | Complex |
| **Use Case** | Daily batches | Real-time |

### Q31: Explain batch vs streaming architecture

**Answer:**

| Aspect | Batch | Streaming |
|--------|-------|-----------|
| **Latency** | Minutes/Hours | Milliseconds/Seconds |
| **Data Size** | Large volumes | Continuous small batches |
| **Use Case** | Reports, analytics | Real-time alerts, monitoring |
| **Complexity** | Simple, deterministic | Complex state management |
| **Example** | Daily report generation | Real-time fraud detection |

### Q32: What data format for efficient Apache Spark Streaming jobs?

**Answer:**

Best formats for streaming:

1. **Parquet**: Good compression, binary format
2. **Avro**: Schema evolution support, compact
3. **Protobuf**: Efficient serialization
4. **JSON**: Human-readable but less efficient

**Recommendation**: Avro or Parquet for streaming pipelines

---

## Data Formats & File Storage

### Q33: What formats of semi-structured data are supported by Databricks?

**Answer:**

Supported formats:
- **JSON**: Nested structures
- **Avro**: Schema evolution, compact
- **Parquet**: Columnar, efficient
- **ORC**: Optimized Row Columnar
- **CSV**: Text-based
- **Delta**: Databricks format with ACID

**Data formats used on projects and why:**
- **Landing Layer**: Parquet/Avro (preserve original format, compression)
- **Raw Layer**: Parquet (efficient storage, faster queries)
- **Curated Layer**: Delta (ACID transactions, schema enforcement)

### Q34: Explain Parquet vs CSV

**Answer:**

| Feature | Parquet | CSV |
|---------|---------|-----|
| **Format** | Columnar, Binary | Row-based, Text |
| **Compression** | Excellent (50-100x) | Poor (snappy 2-5x) |
| **Query Speed** | Fast (columnar operations) | Slow (full scan) |
| **Storage** | ~20-30% smaller | ~3-4x larger |
| **Schema** | Embedded, evolved easily | No schema, manual inference |
| **Type Safety** | Yes | No (all strings) |
| **Readability** | Not human-readable | Human-readable |
| **Use Case** | Data lakes, analytics | Data exchange, legacy systems |

**When to Use Parquet:**
- Large datasets (>1GB)
- Analytical queries
- Long-term storage
- Cost optimization
- Multiple reads with selective columns

**When to Use CSV:**
- Small datasets (<100MB)
- Data exchange/integration with external systems
- Human inspection needed
- Quick prototyping
- Daily reports for non-technical users

### Q35: Explain Delta vs Parquet

**Answer:**

| Feature | Delta | Parquet |
|---------|-------|---------|
| **Transaction Support** | ACID transactions | No |
| **Schema Evolution** | Supported | Not supported |
| **Time Travel** | Versions maintained | Not available |
| **Update/Delete** | Supported | Requires rewrite |
| **DML Operations** | Full support | Append-only |
| **Data Quality** | Schema enforcement | No validation |
| **Performance** | Optimized with statistics | Good |
| **Metadata** | Rich transaction log | Basic |

**Use Cases:**

**Parquet**: 
- Read-only data warehouses
- Immutable data lakes
- Simple data loading

**Delta**:
- Production pipelines
- Complex transformations
- Data governance requirements
- Real-time updates

### Q36: Use case where you would suggest Parquet instead of Delta?

**Answer:**

1. **Cost-Sensitive Systems:**
   - Delta adds overhead (transaction log)
   - Parquet is simpler and cheaper

2. **Immutable Data Warehouses:**
   - Data never updated/deleted
   - Traditional DW use cases
   - Read-only analytics

3. **External Integration:**
   - Many tools support Parquet natively
   - Wider ecosystem compatibility
   - Cloud platform integration

4. **Simple Analytics:**
   - No schema evolution needed
   - No time travel required
   - Straightforward transformations

**Example:**
```python
# Use Parquet for simple archive storage
historical_data.write.parquet("s3://data-lake/archive/2023/")
```

### Q37: What is proper parquet file size?

**Answer:**

**Recommended Size:** 128 MB - 1 GB per file

**Calculation:**
- Target partitions: 128 MB per partition
- Number of files = Total data / 128 MB

### Q38: What happens with Large, small many files?

**Answer:**

**Small File Problem:**
- Many small files = metadata overhead
- Slow reads
- Memory issues during listing

**Large File Problem:**
- Slow to process
- Long GC pauses
- Reduced parallelism

**Solution:** Repartition or coalesce during write
```python
df.coalesce(num_partitions).write.parquet("path")
```

### Q39: Can you overwrite particular partition in Spark DataFrame to Parquet?

**Answer:**

Yes, with dynamic partition overwrite:

```python
# Enable dynamic partition overwrite
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

# Write to specific partition
df.write.mode("overwrite").insertInto("table_name")

# Or using DataFrame writer
df.write \
    .partitionBy("year", "region") \
    .mode("overwrite") \
    .parquet("path/year=2022/region=APAC/")
```

This only overwrites matching partitions, not the entire table.

---

## Delta Lake

### Q40: What are key differences between classical Data Lake and Delta Lake?

**Answer:**

| Aspect | Classical Data Lake | Delta Lake |
|--------|-------------------|-----------|
| **Format** | Parquet, ORC | Delta format |
| **Transactions** | No | ACID |
| **Schema Enforcement** | No | Yes |
| **Updates/Deletes** | Rewrite all | Atomic operations |
| **Time Travel** | Not possible | Full history |
| **Data Quality** | Manual checks | Constraint enforcement |
| **Metadata** | Minimal | Rich transaction log |

**Classical Data Lake Issues:**
- Data corruption from concurrent writes
- Schema drift over time
- Difficult to implement SCD
- Hard to track data lineage
- No rollback capability

**Delta Lake Solutions:**
```python
# ACID transactions
delta_table = DeltaTable.forPath(spark, "s3://delta/data")
delta_table.update(
    condition=col("id") == 123,
    set={"amount": col("amount") * 1.1}
)

# Time travel
df = spark.read.option("versionAsOf", 1).delta("s3://delta/data")
```

### Q41: Use cases for Delta Lake vs classical Data Lake

**Answer:**

**Use Delta Lake When:**
- ACID transactions needed
- Schema evolution expected
- Data corrections/updates common
- Compliance/audit required
- SCD Type 2 implementation
- Real-time + batch processing

**Use Classical Data Lake (Parquet) When:**
- Cost is critical
- Immutable data (write-once)
- Simple read-only analytics
- No schema evolution
- External tool compatibility crucial
- Archive data (rarely accessed)

### Q42: What is Z-ordering in Delta Lake?

**Answer:**

1. **Purpose:** Optimize multi-dimensional queries
2. **How it works:** Co-locates related data together based on multiple columns
3. **Syntax:**
   ```sql
   OPTIMIZE table_name ZORDER BY (col1, col2)
   ```

4. **Differences from Partitioning:**
   - **Partitioning**: Separates data by key (directory level)
   - **Z-ordering**: Co-locates within file (file level)

5. **Trade-offs:**
   - **Advantage**: Better for queries on multiple columns
   - **Disadvantage**: Slower writes, requires periodic optimization

6. **When to use:**
   - Multi-column filters are common
   - Data size < 1TB
   - Read-heavy workloads

### Q43: You made 100 transactions on Delta table. What happens behind scenes?

**Answer:**

Behind the scenes:

1. **Transaction Log**: Each transaction recorded in `_delta_log/` directory
2. **Versions**: Each transaction creates new version
3. **Snapshots**: Snapshots created periodically
4. **Query**: Latest snapshot is read (accumulated transactions)

**Implementation:**
```python
# Each transaction
delta_table.merge(...).whenMatched().update(...).execute()

# Internally:
# - Write new parquet files
# - Write transaction record in delta log
# - Update version number
# - Update metadata

# When querying:
# - Read delta log to find latest version
# - Read corresponding parquet files
# - Construct view of current state
```

### Q44: What is the role of VACUUM in Databricks?

**Answer:**

**VACUUM Purpose:**
- Removes old data files
- Reclaims storage space
- Keeps only recent versions
- Improves performance

**How It Works:**
```sql
-- Keep files modified in last 7 days
VACUUM delta_table RETAIN 7 DAYS;

-- Keep specific number of hours
VACUUM delta_table RETAIN 168 HOURS;
```

**Considerations:**
- Default retention: 7 days
- Cannot restore beyond retention period
- Enables time travel up to retention period
- Should run periodically

**Example:**
```python
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "s3://delta/data")
delta_table.vacuum(7)  # Keep 7 days
```

### Q45: What Delta Lake features do you use on the project?

**Answer:**

Key features used in projects:

1. **Time Travel**: Query historical data
   ```sql
   SELECT * FROM table TIMESTAMP AS OF '2024-01-01'
   ```

2. **Unified Batch and Streaming**: Same table for both operations

3. **ACID Transactions**: Concurrent writes with isolation

4. **Data Retention**: Clean up old versions
   ```sql
   DELETE FROM table WHERE version < 5
   ```

5. **Constraints**: Business rule enforcement

### Q46: Describe data storage optimization techniques in Databricks Delta?

**Answer:**

**1. Optimize (Compaction):**
```sql
-- Compact small files into larger ones
OPTIMIZE table_name
ZORDER BY (column1, column2);
```

**2. Z-Ordering:**
```sql
-- Multi-column indexing
OPTIMIZE transactions
ZORDER BY (user_id, timestamp);
```

**3. Caching:**
```python
df = spark.read.delta("path")
df.cache()  # Keep in memory
df.count()  # Trigger evaluation
```

**4. Vectorized Operations:**
```python
spark.conf.set("spark.sql.execution.arrow.enabled", "true")
```

**5. Partition Pruning:**
```sql
SELECT * FROM table WHERE date = '2023-01-01'
-- Only reads relevant partitions
```

**6. VACUUM:**
```sql
-- Remove old snapshots
VACUUM table_name RETAIN 30 DAYS;
```

### Q47: What is Lakeflow Spark Declarative Pipelines (DLT)?

**Answer:**

**What is DLT:**
- Declarative framework for building data pipelines
- SQL or Python-based
- Automatic data quality checks
- Automatic optimization

**When to use DLT vs Manual Pipelines:**
- Use DLT: Simple ETL, need quality enforcement, team-wide consistency
- Use Manual: Complex logic, special optimizations needed, legacy integration

**Example DLT Pipeline:**
```python
@dlt.table(quality="check_data_quality")
def bronze_table():
    return spark.read.json("source")

@dlt.table
@dlt.expect_all({"col1 IS NOT NULL": "col1 not null"})
def silver_table():
    return dlt.read("bronze_table").filter("quality > 0.8")
```

---

## Databricks

### Q48: Traditional Spark vs Spark on Databricks?

**Answer:**

| Aspect | Traditional Spark | Databricks |
|--------|-------------------|-----------|
| **Management** | DIY, self-managed | Fully managed service |
| **Optimization** | Standard Catalyst | Enhanced Catalyst + Photon |
| **Performance** | Baseline | 10-30x faster with Photon |
| **Setup** | Complex, time-consuming | Quick, built-in clusters |
| **Security** | Manual configuration | Built-in compliance, RBAC |
| **Cost** | Infrastructure + operations | SaaS pricing |
| **Ecosystem** | Limited integrations | Rich integrations |

**Decision Factors:**
- Choose Databricks for managed service, performance optimization
- Choose Traditional Spark for on-prem, cost constraints

### Q49: How does Unity Catalog differ from Hive Metastore?

**Answer:**

| Aspect | Hive Metastore | Unity Catalog |
|--------|----------------|---------------|
| **Scope** | Single workspace | Multi-workspace |
| **Governance** | Basic ACLs | Row/column level |
| **Lineage** | Limited | Rich lineage |
| **Schema Evolution** | Limited | Full support |
| **Cross-Workspace** | No sharing | Easy sharing |
| **Data Sharing** | Complex | Native support |
| **Performance** | Good | Optimized |

**Unity Catalog Setup:**
```sql
-- Create catalog
CREATE CATALOG IF NOT EXISTS analytics;

-- Create schema
CREATE SCHEMA IF NOT EXISTS analytics.finance;

-- Grant permissions
GRANT SELECT ON CATALOG analytics TO user1@company.com;
```

**Benefits:**
- Centralized governance
- Cross-workspace sharing
- Data discovery
- Audit logging
- Lineage tracking

### Q50: Can Unity Catalog be shared across multiple workspaces?

**Answer:**

**Yes**, this is a key feature of Unity Catalog.

**How It Works:**
- Single metastore for entire org
- Data stored in cloud object storage
- Multiple workspaces access same data
- Permissions enforced centrally

### Q51: Can Hive Metastore and Unity Catalog coexist?

**Answer:**

**Yes**, but with limitations:

**Migration Path:**
```
Hive Metastore (Old) → Dual Mode → Unity Catalog (New)
```

**Considerations:**
- Hive metastore is workspace-scoped
- Unity Catalog is org-scoped
- Can't grant permissions across both
- Need migration strategy
- Eventually deprecate Hive metastore

### Q52: What additional features does Databricks offer vs vanilla Spark?

**Answer:**

1. **Security:**
   - DBFS encryption at rest
   - Network encryption in transit
   - Customer-managed keys (CMK)
   - RBAC (Role-Based Access Control)
   - Token-based authentication

2. **Performance:**
   - Photon engine (10-30x faster)
   - Enhanced Catalyst optimizer
   - Native GPU support
   - Auto-optimization

3. **Data Governance:**
   - Unity Catalog
   - Lineage tracking
   - Data quality enforcement
   - Compliance reporting

4. **Compliance:**
   - SOC2, HIPAA, GDPR compliance
   - Audit logs for all operations
   - Data masking capabilities

---

## Data Quality & Governance

### Q53: What is data provenance and data lineage? Differences?

**Answer:**

**Data Lineage:**
- Tracks data flow from source to destination
- Shows all transformations applied
- Answers "where did this data come from?"

**Data Provenance:**
- Detailed audit trail of all changes
- Who, what, when, why for each operation
- Answers "who changed this data and why?"

**Capturing Lineage:**
```python
# Metadata Collection
df = df.withColumn("source_table", lit("customer_raw"))
df = df.withColumn("loaded_at", current_timestamp())
df = df.withColumn("loaded_by", lit("etl_pipeline_v2"))

# Tools:
# - Apache Atlas: Metadata management
# - Collibra: Data governance
# - Informatica: Enterprise lineage
# - OpenMetadata: Standard format
```

### Q54: Why do we need data governance?

**Answer:**

**Benefits:**
1. **Data Quality**: Ensures accuracy, completeness, consistency
2. **Compliance**: Regulatory requirements (GDPR, CCPA, HIPAA)
3. **Security**: Control access to sensitive data
4. **Efficiency**: Reduce duplicate efforts, standardize processes
5. **Trust**: Stakeholders confident in data
6. **Cost**: Reduce storage and processing waste
7. **Risk Management**: Prevent data breaches, loss

**Key Components:**
- Data quality rules
- Master data management
- Metadata management
- Access control
- Lineage tracking
- Privacy/PII handling

### Q55: What is data lineage? How to capture it?

**Answer:**

**Definition**: Tracks data flow from source through transformations to destination

**Capture Methods:**

1. **Manual Annotation:**
   ```python
   lineage_info = {
       "source": "raw_customers",
       "target": "silver_customers",
       "transformations": ["deduplicate", "validate_email"],
       "timestamp": datetime.now(),
       "run_id": pipeline_run_id
   }
   ```

2. **Automatic Tracking:**
   - Spark lineage hooks
   - Metadata catalogs
   - ETL tool lineage

3. **Storage Approach:**
   - **Separate**: Dedicated metadata store (recommended)
   - **Together**: With business data (simpler but harder to maintain)

### Q56: Differences between data quality and data governance?

**Answer:**

| Aspect | Data Quality | Data Governance |
|--------|-------------|-----------------|
| **Focus** | Data correctness | Organizational processes |
| **Scope** | Technical validation | Policies and rules |
| **Ownership** | Data team | Executive leadership |
| **Goal** | Ensure accuracy | Enable compliance |
| **Actions** | Validate, clean, monitor | Create policies, assign responsibility |
| **Tools** | Great Expectations, validation | Collibra, Atlas, metadata management |

**Example:**
- **DQ**: "Customer email is invalid format"
- **Governance**: "Only sales team can access customer data"

### Q57: How do you check data quality on your project?

**Answer:**

**Framework:**

1. **Quality Dimensions:**
   - **Completeness**: No missing values
   - **Accuracy**: Data matches reality
   - **Consistency**: Uniform format/values
   - **Timeliness**: Data current and available
   - **Uniqueness**: No unwanted duplicates
   - **Validity**: Conforms to format

2. **Implementation:**
   ```python
   class DataQualityChecker:
       def __init__(self, df):
           self.df = df
       
       def check_null_values(self, columns, max_pct=0.05):
           for col in columns:
               null_pct = self.df.filter(col(col).isNull()).count() / self.df.count()
               assert null_pct <= max_pct, f"{col} has {null_pct}% nulls"
       
       def check_uniqueness(self, key_columns):
           total_rows = self.df.count()
           unique_rows = self.df.dropDuplicates(key_columns).count()
           assert total_rows == unique_rows, "Duplicate keys found"
   ```

### Q58: Dimensions of Data Quality?

**Answer:**

**Six Key Dimensions:**

1. **Accuracy**: Data correctness
   - Matches source of truth
   - Calculations correct
   - Validation against reference data

2. **Completeness**: No missing data
   - No null values where required
   - All expected records present
   - All fields populated

3. **Consistency**: Uniform representation
   - Same value formats across systems
   - No conflicting values
   - Standardized naming

4. **Timeliness**: Data freshness
   - Available when needed
   - Updated regularly
   - No stale data

5. **Uniqueness**: No duplicates
   - Primary key uniqueness
   - No unwanted duplicates
   - Deduplication applied

6. **Validity**: Conforms to format
   - Data type correctness
   - Range validation
   - Format compliance

### Q59: What can be causes of bad data?

**Answer:**

**Data Entry Issues:**
- Manual input errors
- Typos and formatting inconsistencies
- Missing information
- Duplicate entries

**System Issues:**
- Integration failures
- Data corruption during transfer
- Schema mismatches
- Encoding issues

**Operational Issues:**
- Insufficient validation
- Poor error handling
- No quality checks
- Inadequate testing

**External Factors:**
- Source system changes
- Third-party data quality issues
- Network failures during transfer
- Data decay over time

**Business Issues:**
- Undefined requirements
- Inconsistent processes
- Lack of governance
- No accountability

### Q60: How do you enforce data quality checks in pipelines?

**Answer:**

```python
# 1. Schema validation
expected_schema = StructType([
    StructField("id", IntegerType()),
    StructField("amount", DecimalType(10, 2))
])

df = spark.read.schema(expected_schema).parquet("data")

# 2. Custom checks
def quality_check(df):
    checks = {
        "no_nulls": df.filter(col("id").isNull()).count() == 0,
        "positive_amount": df.filter(col("amount") < 0).count() == 0,
        "valid_date": df.filter(col("date") > current_date()).count() == 0
    }
    
    failed = [k for k, v in checks.items() if not v]
    if failed:
        raise ValueError(f"Quality checks failed: {failed}")
    
    return df

# 3. Great Expectations
suite = ExpectationSuite(...)
result = suite.validate(df)

# 4. Aggregate checks
quality_metrics = {
    "row_count": df.count(),
    "null_count": df.filter(col("id").isNull()).count(),
    "duplicate_count": df.count() - df.dropDuplicates().count()
}

# 5. Alert on failures
if not result.success:
    send_alert(f"Data quality check failed: {result.failures}")
```

### Q61: How do you maintain DQ solution when changes occur?

**Answer:**

**Maintenance Strategy:**

1. **Monitor Changes:**
   - Track schema modifications
   - Monitor new data sources
   - Identify new business rules

2. **Update Checks:**
   ```python
   new_schema = StructType([...updated fields...])
   update_schema_definition(new_schema)
   
   update_quality_rules({
       "new_column_range": (min_val, max_val)
   })
   ```

3. **Version Control:**
   - Track quality rule changes
   - Maintain backward compatibility
   - Document change rationale

4. **Testing:**
   - Unit test quality rules
   - Test with sample data
   - Validate before deployment

5. **Communication:**
   - Notify stakeholders of changes
   - Document new rules
   - Training on new checks

### Q62: Can you explain the difference between code quality and data quality?

**Answer:**

| Aspect | Code Quality | Data Quality |
|--------|-------------|-------------|
| **Definition** | Quality of code implementation | Quality of data content |
| **Measurement** | Code review, static analysis | Data profiling, validation |
| **Metrics** | Complexity, duplication, coverage | Accuracy, completeness |
| **Example** | Readable, testable code | Correct, complete records |

**Project Metrics:**

1. **Code Quality:**
   - Code review coverage: 100%
   - Test coverage: >80%
   - Cyclomatic complexity: <10

2. **Data Quality:**
   - NULL rate: <5%
   - Duplicate rate: <0.1%
   - Invalid records: 0 (critical fields)

---

## Data Warehouse & Data Lake Architecture

### Q63: Key differences between data lakes and data warehouses?

**Answer:**

| Aspect | Data Lake | Data Warehouse |
|--------|-----------|----------------|
| **Data Structure** | Raw, unstructured | Structured, curated |
| **Schema** | Schema-on-read | Schema-on-write |
| **Cost** | Low (raw storage) | Higher (processing) |
| **Flexibility** | High (any data) | Lower (predefined) |
| **Performance** | Variable | Optimized queries |
| **Use Case** | Data exploration | Business reporting |
| **Governance** | Challenging | Built-in |

**When to Choose:**
- Data Lake: R&D, data exploration, all data sources
- Data Warehouse: Reporting, analytics, known requirements

### Q64: When would you choose one over the other?

**Answer:**

**Choose Data Lake when:**
- Exploring multiple data types
- Schema not yet defined
- Need raw data preservation
- Cost is primary concern
- Supporting data science

**Choose Data Warehouse when:**
- Known analytics requirements
- Regular reporting needed
- Performance is critical
- Controlled user base
- Enterprise governance

### Q65: Star schema vs snowflake schema?

**Answer:**

| Aspect | Star Schema | Snowflake Schema |
|--------|-----------|-----------------|
| **Structure** | Denormalized | Normalized |
| **Fact Table** | Connected to dimension tables | Connected to normalized dimensions |
| **Dimension Tables** | Single level | Multiple levels (hierarchies) |
| **Storage** | Larger dimension tables | Optimized storage |
| **Query Performance** | Faster (fewer joins) | Slower (more joins) |
| **Maintenance** | Simpler updates | Complex updates |
| **Redundancy** | More redundancy | Less redundancy |

**When to Use:**
- **Star**: Fast queries, simple design, OLAP
- **Snowflake**: Normalized data, storage optimization, complex hierarchies

### Q66: Key differences between OLAP and OLTP engines?

**Answer:**

| Aspect | OLAP | OLTP |
|--------|------|------|
| **Purpose** | Analysis | Transaction processing |
| **Workload** | Read-heavy, complex | Write-heavy, simple |
| **Data** | Historical, aggregated | Current, detailed |
| **Response Time** | Seconds to minutes | Milliseconds |
| **Volume** | Large datasets (TB-PB) | Individual records |
| **Indexing** | Columnar, aggregate functions | B-tree, indexes on primary keys |
| **Normalization** | Denormalized (star schema) | Highly normalized |
| **Examples** | BigQuery, Redshift, Snowflake | PostgreSQL, Oracle, MySQL |

### Q67: How is Delta Lake different from Data Warehouse?

**Answer:**

| Aspect | Data Warehouse | Delta Lake |
|--------|----------------|-----------|
| **Purpose** | Analytics/BI | Flexible analytics |
| **Schema** | Rigid, pre-defined | Flexible, evolving |
| **Updates** | Via ETL | Real-time |
| **Cost** | Fixed infrastructure | Variable usage |
| **Latency** | Hours | Minutes to real-time |
| **Flexibility** | Limited | High |

### Q68: Data Lakehouse Architecture?

**Answer:**

Combines best of both:
- Lake's flexibility + Warehouse's performance
- Implemented using Delta Lake or Iceberg
- ACID transactions, Schema enforcement, Performance optimization
- Benefits: Lower cost, better governance, faster queries

### Q69: Schema evolution in data lake - how to handle?

**Answer:**

**Strategy for evolving schemas:**

1. **Delta Lake Approach:**
   ```python
   df.write.format("delta") \
       .option("mergeSchema", "true") \
       .mode("append") \
       .save("path")
   ```

2. **Medallion Architecture:**
   - **Bronze**: Raw data, minimal schema enforcement
   - **Silver**: Standardized schema, data quality rules
   - **Gold**: Business-ready, final schema

3. **Pipeline Adaptation:**
   - Monitor schema changes
   - Version schemas
   - Document evolution history
   - Test new schema versions

---

## ETL Patterns & Pipelines

### Q70: ETL patterns used on project and why?

**Answer:**

**Common Patterns:**

1. **Batch ETL:**
   ```python
   # Traditional Extract-Transform-Load
   df = spark.read.parquet("s3://raw/")
   df = df.filter(col("status") == "active")
   df = df.withColumn("processed_date", current_date())
   df.write.mode("overwrite").parquet("s3://curated/")
   ```

2. **Lambda Pattern:**
   - Batch + Real-time processing
   - Batch for historical data
   - Stream for real-time

3. **Kappa Architecture:**
   - Stream-only processing
   - All data through event log
   - Better for real-time

4. **ELT Pattern:**
   - Load raw data first
   - Transform in data warehouse
   - Better for cloud data lakes

### Q71: Describe a good Data Pipeline and best practices?

**Answer:**

**Characteristics:**

1. **Reliability**: Idempotent, fault-tolerant, recoverable
2. **Performance**: Fast execution, optimized queries
3. **Scalability**: Handles data growth
4. **Maintainability**: Clear code, good documentation
5. **Observability**: Logging, monitoring, alerting

**Best Practices:**

```python
# 1. Idempotent operations
df.write.mode("overwrite").save("path")  # Safe to rerun

# 2. Data validation
assert df.count() > 0, "No data loaded"
assert df.filter(col("amount") < 0).count() == 0, "Invalid amounts"

# 3. Lineage tracking
df = df.withColumn("pipeline_run_id", lit(run_id))
df = df.withColumn("loaded_at", current_timestamp())

# 4. Error handling
try:
    df = spark.read.parquet("source")
except Exception as e:
    logger.error(f"Failed to load data: {e}")
    raise

# 5. Resource cleanup
df.unpersist()
spark.stop()
```

### Q72: Approaches to test Spark jobs?

**Answer:**

```python
import unittest
from pyspark.sql import SparkSession

class TestTransformations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spark = SparkSession.builder.appName("test").getOrCreate()
    
    def test_filter_logic(self):
        data = [("Alice", 25), ("Bob", 30)]
        df = self.spark.createDataFrame(data, ["name", "age"])
        
        result = df.filter(df.age > 25)
        assert result.count() == 1
        assert result.first()["name"] == "Bob"

# Integration testing
# - Test with sample data
# - Validate output schema
# - Check data quality rules
```

### Q73: Handling nested JSON flattening with failures?

**Answer:**

**Problem**: Unpredictable failures, OOM during nested transformation

**Solution:**

1. **Streamlined Flattening:**
   ```python
   df = spark.read.option("multiLine", "true").json("path")
   
   def flatten_json(df):
       for col_name in df.columns:
           if isinstance(df.select(col_name).schema[0].dataType, StructType):
               df = df.select("*", f"{col_name}.*")
               df = df.drop(col_name)
       return df
   ```

2. **Batch Processing:**
   - Process files in chunks
   - Repartition between stages
   - Clear cache regularly

3. **Resource Optimization:**
   - Increase executors for wide data
   - Use columnar formats
   - Sample data for testing

---

## Data Modeling

### Q74: How would you design SCD Type 2 in data warehouse?

**Answer:**

**Types of SCDs:**

1. **Type 1 (Overwrite):**
   - Overwrite old values
   - No history
   - Simple, loses historical context

2. **Type 2 (Add Rows):**
   - Add new rows for changes
   - Keep history with effective dates
   - Most common, maintains full history

3. **Type 3 (Add Columns):**
   - Add columns for previous values
   - Limited history

**Type 2 Implementation (Spark, billions of records):**

```python
from pyspark.sql.functions import col, row_number, max as spark_max, when
from pyspark.sql.window import Window

# Step 1: Merge with existing table
existing = spark.read.table("scd_table")
new_records = existing.union(new_data)

# Step 2: Mark end date for old records
window_spec = Window.partitionBy("id").orderBy(col("effective_date").desc())
new_records = new_records \
    .withColumn("rn", row_number().over(window_spec)) \
    .withColumn("end_date", 
        when(col("rn") > 1, col("effective_date")).otherwise(col("end_date")))

# Step 3: Handle multiple updates in single batch
# Use max effective date to avoid duplicates
```

### Q75: Slowly Changing Dimensions types?

**Answer:**

**Type 1**: Overwrite (simplest)
**Type 2**: Historical tracking (most common)
**Type 3**: Limited history (hybrid)
**Type 4**: Mini-dimensions (for composite keys)
**Type 5**: Hybrid (combination of 1 and 2)

### Q76: Implement SCD Type 2 with streaming pipelines?

**Answer:**

Use Delta Lake's merge operation:

```python
delta_table = DeltaTable.forPath(spark, "scd_path")

delta_table.merge(
    source_data.alias("source"),
    "target.id = source.id"
).whenMatched(
    "target.end_date IS NULL"
).update(
    set={"end_date": col("source.effective_date")}
).whenNotMatched().insert(
    values={
        "id": col("source.id"),
        "effective_date": col("source.effective_date"),
        "end_date": lit(None)
    }
).execute()
```

### Q77: Major disadvantages of bucketing in Spark?

**Answer:**

1. **Increased Write Time**: Bucketing adds overhead
2. **Fixed Bucket Count**: Cannot easily change
3. **Storage Overhead**: Empty buckets waste space
4. **Complex Maintenance**: Requires recreation for changes
5. **Limited Benefit**: Not always faster than partition pruning

---

## AWS Services

### Q78: How would you tackle AWS S3 consistency problem?

**Answer:**

**Solutions:**

1. **Application-Level:**
   - Add retry logic with exponential backoff
   - Use S3 VersionId for consistency
   - Implement idempotent operations

2. **Architectural:**
   ```python
   import boto3, time
   
   s3 = boto3.client('s3')
   
   def put_object_with_retry(bucket, key, data, retries=3):
       for attempt in range(retries):
           try:
               s3.put_object(Bucket=bucket, Key=key, Body=data)
               return
           except Exception as e:
               if attempt < retries - 1:
                   time.sleep(2 ** attempt)
               else:
                   raise
   ```

3. **Best Practices:**
   - Use S3 Transfer Acceleration
   - Enable versioning
   - Use tags for tracking
   - Implement DLQ for failed uploads
   - Use SQS for reliable processing order

### Q79: Minimize cost for storing objects in S3?

**Answer:**

**Cost Optimization:**

1. **Storage Classes:**
   ```python
   lifecycle_policy = {
       "Rules": [
           {
               "Id": "ArchiveRule",
               "Filter": {"Prefix": "data/"},
               "Transitions": [
                   {"Days": 30, "StorageClass": "STANDARD_IA"},  # 50% cheaper
                   {"Days": 90, "StorageClass": "GLACIER"}  # 80% cheaper
               ]
           }
       ]
   }
   ```

2. **Compression:**
   ```python
   df.write.format("parquet") \
       .option("compression", "snappy") \
       .save("s3://bucket/")
   ```

3. **Partitioning:**
   ```python
   df.write.partitionBy("year", "month") \
       .parquet("s3://bucket/data/")
   ```

4. **Intelligent-Tiering**: Automatically moves between access tiers

5. **Deletion Policies:**
   ```python
   {
       "Id": "DeleteRule",
       "Filter": {"Prefix": "temp/"},
       "Expiration": {"Days": 7}
   }
   ```

### Q80: How to minimize cost for storing objects in S3?

**Answer:** (See Q79 above)

### Q81: AWS Athena vs AWS Glue?

**Answer:**

| Aspect | Athena | Glue |
|--------|--------|------|
| **Purpose** | Query data | ETL transformation |
| **Language** | SQL | Python/Scala/Spark |
| **Pricing** | Per query | Per DPU-hour |
| **Latency** | Low for simple queries | Higher (batch job) |
| **Use** | Ad-hoc analysis | Complex transformations |
| **Catalog** | Glue Catalog | Glue Catalog |

### Q82: How can we query any data source with AWS Athena?

**Answer:**

**Data Sources:**

1. **S3 (Native):**
   ```sql
   SELECT * FROM s3.s3_table
   ```

2. **External Data Connectors:**
   - RDS/Aurora via Lambda
   - DynamoDB
   - HBase
   - OpenSearch
   - Kafka

3. **Using Federation:**
   ```sql
   CREATE EXTERNAL TABLE external_db
   USING "lambda:arn:aws:lambda:region:account:function:connector"
   WITH DATABASE "remote_db" TABLE "remote_table"
   
   SELECT * FROM external_db
   ```

### Q83: I would like daily ingestion - what tools would you recommend?

**Answer:**

**For 1 hour job, ~1GB daily data:**

1. **AWS Glue**: Cost-effective, managed
2. **Lambda + Spark**: Serverless option
3. **EC2 + Airflow**: More control
4. **AWS DataSync**: For file transfers
5. **AWS DMS**: For database replication

### Q84: Which AWS services to replace Snowflake?

**Answer:**

**AWS Alternatives:**

1. **Redshift** (Best replacement):
   - Data warehouse like Snowflake
   - Better for large data volumes
   - More cost-effective at scale
   - Native AWS integration

2. **BigQuery** (If using GCP):
   - Serverless data warehouse
   - Faster query performance
   - Better for ad-hoc analytics

3. **Athena**:
   - Serverless SQL on S3
   - Lower cost for small workloads
   - No infrastructure management

### Q85: Can you compare Hadoop HDFS and AWS S3?

**Answer:**

| Aspect | HDFS | AWS S3 |
|--------|------|--------|
| **Location** | On-premise | Cloud |
| **Cost** | Hardware + maintenance | Pay-per-use |
| **Scalability** | Limited by hardware | Unlimited |
| **Availability** | Managed locally | 99.99% uptime SLA |
| **Data Replication** | 3 copies default | Automatic replication |
| **Performance** | Local reads fast | Network dependent |
| **Compliance** | Easier for on-prem | More compliance options |

### Q86: You have to choose between 2 AWS technologies - how to persuade customer?

**Answer:**

1. **Understand Requirements:**
   - Current state
   - Future scalability needs
   - Budget constraints
   - Team expertise

2. **Present Comparison:**
   - Performance benchmarks
   - Cost analysis
   - Risk assessment
   - Proof of concept

3. **Recommendation:**
   - Based on data analysis
   - Document decision rationale
   - Plan migration if needed

### Q87: What is BigQuery caching mechanism?

**Answer:**

**Caching Features:**

1. **Query Results Caching**:
   - Results cached for 24 hours
   - Identical queries use cache
   - Reduces query time to milliseconds

2. **Slot Reservation**:
   - Guaranteed processing capacity
   - Better for consistent workloads

### Q88: Compare Cloud Service Models (IaaS, PaaS, SaaS)?

**Answer:**

| Model | IaaS | PaaS | SaaS |
|-------|------|------|------|
| **Control** | High | Medium | Low |
| **Example** | EC2, Azure VMs | App Engine, Heroku | Salesforce, Office 365 |
| **Management** | More manual | Partial | Fully managed |
| **Cost** | Variable | Medium | Fixed |

---

## Azure Services

### Q89: Transfer 10 PB data from Hadoop to Azure Blob Storage?

**Answer:**

**Strategy:**

1. **Planning Phase:**
   - Calculate transfer time at various speeds
   - Identify network bottlenecks
   - Plan for checkpointing

2. **Tool Selection:**
   - **Azure Data Box**: Physical devices for 1-40 PB
   - **Azure Data Factory**: 10-100 TB typical
   - **DistCp**: Hadoop native tool
   - **DistCp + Checksum**: For integrity

3. **Implementation:**
   ```bash
   hadoop distcp \
     -update \
     -delete \
     -m 100 \
     -checksum \
     -strategy dynamic \
     hdfs://hadoop-cluster/data \
     wasb://container@storage.blob.core.windows.net/data
   ```

4. **Data Integrity Checks:**
   - Checksum comparison (MD5, SHA-256)
   - Row count verification
   - Sample data validation
   - Schema validation

### Q90: Azure services categorization - PaaS, SaaS, IaaS?

**Answer:**

**IaaS Examples:**
- Azure VMs
- Azure Storage
- Azure Networking

**PaaS Examples:**
- Azure App Service
- Azure SQL Database
- Azure Data Factory

**SaaS Examples:**
- Office 365
- Dynamics 365
- Azure DevOps

### Q91: What is integration runtime in Azure Data Factory?

**Answer:**

**Types:**

1. **Azure Integration Runtime:**
   - Cloud-based
   - For cloud data sources
   - Managed by Azure

2. **Self-Hosted Integration Runtime:**
   - On-premises
   - For on-prem data sources
   - Customer-managed

**Use Case**: Connect on-prem databases to cloud

### Q92: Explain hierarchical namespace in Azure Data Lake Gen2?

**Answer:**

**Features:**

1. **Directory Structure**: True hierarchical file system
2. **Performance**: Better for big data operations
3. **Security**: Directory-level ACLs
4. **Compatibility**: Works with Hadoop APIs

### Q93: Compare orchestration - Databricks vs Azure Data Factory?

**Answer:**

| Aspect | Databricks | Azure ADF |
|--------|-----------|-----------|
| **Setup** | Managed Spark | Visual pipeline design |
| **Flexibility** | High (custom code) | Medium (connectors) |
| **Cost** | Higher | Lower for simple |
| **Ecosystem** | Spark-native | Azure-native |

### Q94: Cons and pros of Azure ADF?

**Answer:**

**Pros:**
- Fully managed service
- Rich connectors (100+)
- Built-in monitoring
- Serverless (no VM management)
- Integration with Microsoft ecosystem

**Cons:**
- Learning curve (different from other tools)
- Cost can be high for frequent runs
- Limited flexibility for complex logic
- Debugging can be challenging

---

## GCP & Cloud Services

### Q95: What is CAP theorem? Where is Cassandra?

**Answer:**

**CAP Theorem:**
- **Consistency**: All nodes have same data
- **Availability**: System always responds
- **Partition Tolerance**: Survives network failures

**Choose 2 of 3**:
- **CA**: Traditional databases
- **AP**: Web applications (eventual consistency)
- **CP**: Banking systems

**Cassandra**: AP (Availability + Partition Tolerance)
- Prioritizes availability
- Eventually consistent
- No single point of failure

### Q96: Limitations of Dataflow autoscaling?

**Answer:**

**Limitations:**

1. **Latency:**
   - Takes time to scale up
   - Cold start overhead
   - Metrics collection delay

2. **Predictability:**
   - Not responsive to sudden spikes
   - Based on historical metrics
   - May over-provision

3. **Cost:**
   - Can be expensive during scaling
   - Premium for guaranteed resources

4. **Fine-tuning:**
   - Hard to optimize scaling parameters
   - Different workloads need different configs

---

## Orchestration Tools

### Q97: Different orchestration tools - which is best for ETL?

**Answer:**

**Options:**

1. **Apache Airflow:**
   - Pros: Flexible, open-source, community support
   - Cons: Complex setup, self-managed
   - Best for: Complex workflows

2. **Databricks Workflows:**
   - Pros: Native Spark integration, managed
   - Cons: Vendor lock-in
   - Best for: Data engineering

3. **Azure Data Factory:**
   - Pros: Cloud-native, visual design
   - Cons: Limited flexibility
   - Best for: Azure ecosystem

4. **AWS Glue:**
   - Pros: Serverless, integrated
   - Cons: Limited flexibility
   - Best for: AWS-native solutions

**Recommendation**: Airflow for complex, Databricks for data engineering

### Q98: Airflow executors - K8s vs Celery?

**Answer:**

**Celery Executor:**
- Uses message queue (Redis, RabbitMQ)
- Separate worker processes
- Good for dynamic workloads
- Requires external dependencies

**Kubernetes Executor:**
- Runs tasks in K8s pods
- Native container orchestration
- Auto-scales with K8s
- Better isolation

**Comparison:**

| Aspect | Celery | K8s |
|--------|--------|-----|
| **Setup** | Simpler | Complex |
| **Scaling** | Manual | Automatic |
| **Isolation** | Process | Container |
| **Dependencies** | External queue | K8s cluster |
| **Cost** | Cheaper | Expensive |

---

## Apache Kafka

### Q99: Difference between pub-sub synchronous and asynchronous pulling?

**Answer:**

**Synchronous:**
- Consumer waits for message
- Blocking operation
- Simpler programming
- Lower throughput

**Asynchronous:**
- Consumer doesn't wait
- Non-blocking operation
- Higher throughput
- More complex

### Q100: Kafka delivery semantics - types and comparison?

**Answer:**

**Semantics:**

1. **At-Most-Once:**
   - Message might be lost
   - Offset committed before processing
   - Fastest, least reliable
   - Use: Logging, monitoring

2. **At-Least-Once:**
   - Message definitely processed
   - Offset committed after processing
   - Default, requires idempotency
   - Use: Most applications

3. **Exactly-Once:**
   - Message processed exactly once
   - Transactional writes
   - Slowest, most reliable
   - Use: Financial transactions

**Why Multiple Semantics:**
Different use cases have different requirements

---

## Cloud Computing & Infrastructure

### Q101: Benefits of cloud computing over on-prem servers?

**Answer:**

**Cost Benefits:**
- Pay-per-use (no capital investment)
- No hardware maintenance
- Automatic scaling reduces over-provisioning
- Reduced power/cooling costs

**Operational Benefits:**
- Automatic updates and patches
- High availability built-in
- Disaster recovery options
- Global infrastructure access

**Agility Benefits:**
- Rapid deployment (minutes vs weeks)
- Easy horizontal scaling
- Multiple service options
- Quick failure recovery

### Q102: How to manage resources on large datasets to stay within budget?

**Answer:**

**Strategies:**

1. **Resource Monitoring:**
   - Track CPU, memory, storage usage
   - Set up alerts for cost overruns
   - Daily/weekly cost reports

2. **Optimization:**
   - Use cheaper storage classes
   - Optimize query performance
   - Compress data
   - Delete obsolete data

3. **Scheduling:**
   - Run heavy jobs during off-peak hours
   - Use spot instances/preemptible VMs
   - Schedule resource cleanup

### Q103: Cost tracking metrics to evaluate efficiency?

**Answer:**

**Key Metrics:**

1. **Per-Query Cost:**
   - Cost per GB scanned
   - Cost per result

2. **Resource Utilization:**
   - CPU utilization %
   - Memory efficiency
   - Storage per GB

3. **Pipeline Efficiency:**
   - Cost per record processed
   - Cost per unit output

4. **Trend Analysis:**
   - Month-over-month cost growth
   - Cost per user/team
   - Waste metrics

### Q104: Cost optimization for cloud object storage?

**Answer:**

**Optimization:**

1. **Azure Blob Storage:**
   - Hot tier: Frequently accessed
   - Cool tier: 30+ days: 50% cheaper
   - Archive: 90+ days: 80% cheaper

2. **Google Cloud Storage:**
   - Standard: $0.02/GB
   - Nearline: $0.01/GB (30-day minimum)
   - Coldline: $0.004/GB (90-day minimum)

3. **Amazon S3:**
   - Standard: $0.023/GB
   - Intelligent-Tiering: 10-20% savings
   - Glacier: $0.004/GB (90-day minimum)

4. **General Strategies:**
   - Data deduplication
   - Compression (gzip, snappy)
   - Deletion of obsolete data
   - Reserved capacity

---

## Python Programming

### Q105: What is exception handling and custom exceptions in Python?

**Answer:**

**Exception Handling:**

```python
try:
    result = 10 / 0
except ZeroDivisionError as e:
    print(f"Error: {e}")
except Exception as e:
    print(f"Unexpected error: {e}")
finally:
    print("Cleanup code")
```

**Custom Exceptions:**

```python
class DataValidationError(Exception):
    pass

class MissingDataError(DataValidationError):
    pass

# Usage
if not data:
    raise MissingDataError("Data is empty")
```

### Q106: Global Interpreter Lock (GIL) in Python?

**Answer:**

**What is GIL:**
- Mutex protecting Python objects
- Only one thread executes Python bytecode at a time
- Exists because Python's memory management isn't thread-safe

**Impact:**
- True parallelism impossible for CPU-bound tasks
- I/O-bound tasks benefit from threading (GIL released during I/O)

**Solutions:**
- Use multiprocessing for CPU-bound
- Use asyncio for I/O-bound
- Use Numba/Cython for compute-intensive
- Use Spark for data processing

### Q107: How does GIL affect multi-threading in data processing?

**Answer:**

For data processing applications:

1. **Good for I/O-bound:**
   - Network requests
   - File I/O
   - Database calls

2. **Bad for CPU-bound:**
   - Large data transformations
   - Mathematical computations
   - Pandas operations

**Solution for data processing:**
- Use PySpark (no GIL)
- Use multiprocessing
- Use Pandas/NumPy (releases GIL)

### Q108: Difference between Python multithreading and multiprocessing?

**Answer:**

| Aspect | Multithreading | Multiprocessing |
|--------|----------------|-----------------|
| **GIL** | Limited (one thread at a time) | No GIL (true parallelism) |
| **Memory** | Shared (memory-efficient) | Separate (more memory) |
| **CPU-bound** | Poor | Good |
| **I/O-bound** | Good | Good |
| **Overhead** | Low | High |
| **IPC** | Queue, Lock, Event | Pipe, Queue |

### Q109: Deep copy vs shallow copy in Python?

**Answer:**

```python
import copy

a = [1, 2, [3, 4]]

# Shallow copy
b = a.copy()
b[2][0] = 999
print(a)  # [1, 2, [999, 4]] - NESTED LIST MODIFIED!

# Deep copy
c = copy.deepcopy(a)
c[2][0] = 999
print(a)  # [1, 2, [3, 4]] - UNCHANGED
```

**Key Difference:**
- Shallow: Copies reference to nested objects
- Deep: Recursively copies all nested objects

### Q110: Generator vs list?

**Answer:**

| Feature | Generator | List |
|---------|-----------|------|
| **Memory** | Lazy evaluation, low memory | Stores all items |
| **Speed** | Faster (on-demand) | Slower for large datasets |
| **Size** | Infinite possible | Fixed size |
| **Access** | Forward only | Random access |
| **Type** | Iterator | Sequence |

### Q111: What is difference between list, tuple, and set?

**Answer:**

| Aspect | List | Tuple | Set |
|--------|------|-------|-----|
| **Mutable** | Yes | No | Yes |
| **Ordered** | Yes | Yes | No |
| **Indexing** | Yes | Yes | No |
| **Duplicates** | Allowed | Allowed | Not allowed |
| **Syntax** | [] | () | {} |

### Q112: When would you use tuple in data pipelines?

**Answer:**

1. **Immutable Keys:**
   ```python
   column_mapping = {
       ("first_name", "last_name"): "full_name"
   }
   ```

2. **Function Returns:**
   ```python
   def get_user_data():
       return ("John", "Doe", 30)  # Fixed structure
   ```

3. **Unpacking:**
   ```python
   user_id, user_name, email = ("123", "John", "john@example.com")
   ```

### Q113: Explain garbage collection in Python?

**Answer:**

**Purpose:**
- Reclaims memory from unreferenced objects
- Prevents memory leaks
- Maintains Python's memory efficiency

**Key Mechanisms:**

1. **Reference Counting**:
   - Primary mechanism
   - Each object has ref count
   - When count reaches 0, memory freed immediately

2. **Cycle Detection**:
   - Handles circular references
   - Generational garbage collection
   - 3 generations (young, intermediate, old)

3. **Manual Control:**
   ```python
   import gc
   gc.collect()  # Force garbage collection
   gc.disable()  # Disable automatic
   ```

### Q114: How do you handle package management in Python?

**Answer:**

**Package Management:**

1. **Virtual Environments:**
   ```bash
   python -m venv venv
   source venv/bin/activate
   ```

2. **Requirements File:**
   ```bash
   pip freeze > requirements.txt
   pip install -r requirements.txt
   ```

3. **Poetry:**
   ```bash
   poetry add package_name
   poetry install
   ```

4. **Conda:**
   ```bash
   conda env create -f environment.yml
   ```

### Q115: Memory optimization strategies in Python?

**Answer:**

1. **Use Generators:**
   ```python
   # Instead of list
   for x in (i for i in range(1000000)):
       process(x)
   ```

2. **Del Statement:**
   ```python
   del large_object
   gc.collect()
   ```

3. **Weak References:**
   ```python
   import weakref
   ref = weakref.ref(obj)
   ```

4. **Data Structures:**
   - Use __slots__ for classes
   - Use arrays instead of lists for numeric data

### Q116: In plain Python, data structure for unique elements?

**Answer:**

**Set is fastest:**

```python
# List approach (slow)
def has_duplicates(data):
    for item in data:
        if data.count(item) > 1:
            return True

# Set approach (fast)
def has_duplicates(data):
    return len(data) != len(set(data))
```

### Q117: Why are set or dict lookups faster than lists?

**Answer:**

**Complexity:**
- **List lookup**: O(n) - must check each element
- **Set/Dict lookup**: O(1) - hash table based

**Why Hash Tables are Faster:**
- Hash function maps key to index
- Direct array access
- No iteration needed

---

## Scala Programming

### Q118: What is Scala and its key features?

**Answer:**

**Definition:**
Scala combines object-oriented and functional programming on the JVM

**Key Features:**

1. **Immutability by Default:**
   ```scala
   val name = "John"  // Immutable
   var age = 25       // Mutable
   ```

2. **Functional Programming:**
   ```scala
   val numbers = List(1, 2, 3, 4, 5)
   val squared = numbers.map(x => x * x)
   ```

3. **Pattern Matching:**
   ```scala
   x match {
       case 0 => "zero"
       case 1 => "one"
       case _ => "other"
   }
   ```

4. **Case Classes:**
   ```scala
   case class Person(name: String, age: Int)
   ```

### Q119: Scala vs Java differences?

**Answer:**

| Aspect | Scala | Java |
|--------|-------|------|
| **Syntax** | Concise | Verbose |
| **Type Inference** | Strong | Weak |
| **Functional** | Native | Limited (Java 8+) |
| **Immutability** | Default | Manual |
| **Null Handling** | Option[T] | nullPointerException |
| **Boilerplate** | Minimal | Significant |

### Q120: Higher-order functions and closures?

**Answer:**

**Higher-Order Functions:**
```scala
def applyOperation(a: Int, b: Int, op: (Int, Int) => Int): Int = op(a, b)

val add = (x: Int, y: Int) => x + y
applyOperation(5, 3, add)  // 8
```

**Closures:**
```scala
def makeMultiplier(x: Int) = (y: Int) => x * y
val doubler = makeMultiplier(2)
doubler(5)  // 10
```

### Q121: Scala collections - Lists, Sets, Maps?

**Answer:**

```scala
// Lists
val list = List(1, 2, 3, 4, 5)
val doubled = list.map(_ * 2)
val evens = list.filter(_ % 2 == 0)

// Sets
val set1 = Set(1, 2, 3)
val set2 = Set(3, 4, 5)
val union = set1 ++ set2

// Maps
val map = Map("john" -> 30, "jane" -> 28)
val age = map("john")
```

### Q122: Option type for null safety?

**Answer:**

```scala
val value: Option[String] = Some("hello")
val empty: Option[String] = None

// Pattern matching
value match {
    case Some(v) => println(v)
    case None => println("No value")
}

// Using getOrElse
value.getOrElse("default")
```

### Q123: For comprehensions?

**Answer:**

```scala
val numbers = List(1, 2, 3)
val letters = List('a', 'b')

val combinations = for {
    n <- numbers
    l <- letters
} yield (n, l)

// With guards
val evens = for {
    n <- numbers
    if n % 2 == 0
} yield n
```

### Q124: Spark with Scala - DataFrame operations?

**Answer:**

```scala
import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.functions._

val spark = SparkSession.builder().appName("App").getOrCreate()

// Read data
val df = spark.read.parquet("s3://bucket/data.parquet")

// Transformations
val result = df
    .filter(col("age") > 30)
    .groupBy("department")
    .agg(avg("salary").alias("avg_salary"))
    .orderBy(col("avg_salary").desc)

// Write data
result.write.format("delta").mode("overwrite").save("path")
```

---

## Database Design & SQL

### Q125: Explain ACID properties?

**Answer:**

**Atomicity:**
- Transaction completes fully or not at all
- No partial updates
- Example: Transfer money (debit + credit as one unit)

**Consistency:**
- Database moves from valid state to valid state
- Constraints enforced
- Referential integrity maintained

**Isolation:**
- Concurrent transactions don't interfere
- Prevents dirty reads, phantom reads
- Multiple isolation levels

**Durability:**
- Committed data survives failures
- Persistent storage
- Recovery mechanisms

### Q126: SQL database vs NoSQL database - when to choose?

**Answer:**

**Use SQL when:**
- Well-defined schema
- Complex joins needed
- ACID transactions required
- Data relationships important
- Examples: PostgreSQL, Oracle, MySQL

**Use NoSQL when:**
- Flexible schema needed
- Massive horizontal scaling
- High throughput required
- Simple queries
- Examples: MongoDB, DynamoDB, Cassandra

### Q127: What is predicate pushdown?

**Answer:**

**Purpose:**
- Apply filters at lowest level (file/storage)
- Reduce data read
- Improve performance

**How It Works:**
```sql
SELECT * FROM table WHERE age > 30

-- Without pushdown: Read all columns, then filter
-- With pushdown: Filter during read
```

**When It Works:**
- Parquet, ORC, Delta formats
- File-based storage
- Column-oriented systems

### Q128: If dataset partitioned by country, do we still need predicate pushdown?

**Answer:**

**Answer: Yes**, for additional benefits:

1. **Partition Pruning**: Skip entire directories
2. **Predicate Pushdown**: Within partition, filter at file level
3. **Combined**: Maximum efficiency

```sql
-- Query
SELECT * FROM sales WHERE country='USA' AND product_id=123

-- Step 1: Pruning skips non-USA partitions
-- Step 2: Pushdown filters product_id within USA files
```

### Q129: CDC - Change Data Capture advantages?

**Answer:**

**CDC Advantages:**

1. **Efficiency**: Only changed data processed
2. **Real-time**: Incremental updates possible
3. **Audit Trail**: Track all changes
4. **Reduced Load**: Smaller data volumes

**Implementations:**
- Log-based (most common)
- Query-based
- Timestamp-based

---

## Docker & Containerization

### Q130: Docker container possible states?

**Answer:**

**States:**

1. **Created:**
   ```bash
   docker create --name my_container image_name
   # Container exists but not running
   ```

2. **Running:**
   ```bash
   docker run -d image_name
   # Container is actively executing
   ```

3. **Paused:**
   ```bash
   docker pause container_id
   docker unpause container_id
   ```

4. **Stopped:**
   ```bash
   docker stop container_id
   docker start container_id  // Restart
   ```

5. **Exited:**
   - Process finished, cannot restart

6. **Killed:**
   ```bash
   docker kill container_id  // Force kill
   ```

### Q131: Optimize Docker image build in CI/CD?

**Answer:**

**Multi-Stage Build:**
```dockerfile
FROM python:3.10 as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.10-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY src/ .
CMD ["python", "app.py"]
```

**Optimization:**
1. Layer caching
2. BuildKit
3. Cache in CI/CD
4. Minimize final image

---

## CI/CD & DevOps

### Q132: What is CI/CD - purpose, parts, implementation?

**Answer:**

**Purpose:**
- Automated testing and deployment
- Faster feedback
- Reduced manual errors
- Continuous delivery

**Parts:**

1. **CI (Continuous Integration):**
   - Code commit triggers
   - Automated tests
   - Quality checks

2. **CD (Continuous Deployment):**
   - Automatic production deployment
   - Monitoring and alerting

3. **Continuous Delivery:**
   - Manual approval before deploy
   - Always release-ready

**Best Way to Implement Rollback:**
```yaml
Deployment strategies:
- Blue-Green: Switch traffic between versions
- Canary: Gradual rollout with monitoring
- Feature Flags: Enable/disable features
- Database Migrations: Version control scripts
```

### Q133: Terraform version error - how to resolve?

**Answer:**

**Solutions:**

1. **Update Terraform:**
   ```bash
   terraform version
   terraform init -upgrade
   terraform refresh
   ```

2. **State File Migration:**
   ```bash
   terraform state pull > state.json
   terraform state push state.json
   ```

3. **Version Constraints:**
   ```hcl
   terraform {
     required_version = ">= 1.0, < 2.0"
   }
   ```

---

## Team Leadership & Management

### Q134: What does "Senior" role mean to you?

**Answer:**

**Senior Responsibilities:**

1. **Technical Leadership:**
   - Architecture decisions
   - Code quality standards
   - Technology selection

2. **Mentoring:**
   - Guide junior engineers
   - Knowledge sharing
   - Career development

3. **Ownership:**
   - End-to-end accountability
   - Reliability focus
   - Proactive problem-solving

4. **Communication:**
   - Stakeholder updates
   - Clear documentation
   - Cross-team collaboration

### Q135: What senior activities do you already do?

**Answer:**

**Examples:**
- Code reviews for juniors
- Architecture design
- Incident response leadership
- Technical documentation
- Mentoring new team members
- Best practices advocacy

### Q136: Managing low-performing team members?

**Answer:**

**Approach:**

1. **Assessment:**
   - Private conversation
   - Understand root causes
   - Gather team feedback

2. **Action Plan:**
   - Clear expectations
   - Skills training
   - Realistic timeline (30-60-90 days)

3. **Support:**
   - Pair programming
   - Reduce complexity initially
   - Regular feedback

4. **If No Improvement:**
   - Formal performance plan
   - HR involvement
   - Document issues

### Q137: Two senior engineers with different technical opinions?

**Answer:**

**Resolution:**

1. **Understand Positions:**
   - Let each present case
   - Identify pros/cons
   - Find common ground

2. **Evaluate Objectively:**
   - Performance implications
   - Maintenance cost
   - Team expertise

3. **Decision:**
   - Merit-based
   - Document rationale
   - Plan alternative for future

### Q138: How to build culture of ownership in data team?

**Answer:**

**Strategies:**

1. **Clear Accountability:**
   - Each engineer owns end-to-end
   - Clear escalation paths
   - Incident response procedures

2. **Empowerment:**
   - Decision-making authority
   - Risk-taking encouragement
   - Learning opportunities

3. **Metrics & Visibility:**
   - Pipeline health dashboard
   - SLA tracking
   - Regular retrospectives

4. **Support:**
   - On-call support structure
   - Runbooks
   - Cross-training

### Q139: You're mentoring new member from different background?

**Answer:**

**Approach:**

1. **Assess Their Knowledge:**
   - What they know
   - What gaps exist
   - Learning style

2. **Create Learning Path:**
   - Small tasks first
   - Gradual complexity
   - Regular check-ins

3. **Support:**
   - Pair programming
   - Documentation access
   - Safe environment for questions

4. **Balance with Deadline:**
   - Prioritize critical path
   - Get help if needed
   - Realistic timeline

---

## Project Management & Agile

### Q140: Which development methodology is your favorite?

**Answer:**

**Agile/Scrum** (most common answer):
- Regular feedback cycles
- Adaptable to changes
- Team collaboration
- Transparent progress

**Advantages:**
- Quick iterations
- Early issue detection
- Customer feedback integration

**Disadvantages of Waterfall:**
- No feedback until end
- Difficult to accommodate changes
- High risk of failure
- Long release cycles

### Q141: Scrum vs Kanban - planning aspects?

**Answer:**

| Aspect | Scrum | Kanban |
|--------|-------|--------|
| **Iteration** | Fixed sprints | Continuous flow |
| **Planning** | Sprint planning | Continuous planning |
| **WIP Limit** | Implicit | Explicit |
| **Predictability** | Velocity | Flow metrics |
| **Change** | Between sprints | Anytime |

**Kanban Planning:**
- Has continuous planning (not "no planning")
- Prioritized backlog
- Regular refinement
- Different from ad-hoc work

### Q142: How to prevent unrealistic sprint commitments?

**Answer:**

**Strategies:**

1. **Velocity-Based:**
   - Track historical velocity
   - Plan based on past performance
   - Not aspirational

2. **Buffer:**
   - Plan 80-90% of capacity
   - Reserve 10-20% for emergencies

3. **Story Estimation:**
   - Engineers estimate
   - Compare to similar stories
   - Include testing/review

4. **Team Input:**
   - Context switching
   - Support/emergencies
   - Learning curve

---

## Soft Skills & Communication

### Q143: How to explain complex technical concepts to non-technical stakeholders?

**Answer:**

**Techniques:**

1. **Analogies:**
   - "Database is like a filing cabinet"
   - "API is like a restaurant waiter"
   - "Cache is like RAM"

2. **Visual Aids:**
   - Diagrams
   - Screenshots
   - Live demos

3. **Avoid Jargon:**
   - Use simple language
   - Define terms
   - Focus on business impact

### Q144: Client insists on impossible task. How to respond?

**Answer:**

**Example**: Migrate 10 years data in 1 week

**Communication:**
```
"I understand the urgency. Here's the math:
- 10 years of data = ~500TB
- Network bandwidth = 100Mbps = 11.5 hours to transfer
- That's just transfer time, not validation

Realistic options:
1. Phased migration over 3 months
2. Migrate last 1 year in 1 week, rest gradually
3. Increase budget for parallel infrastructure

Which aligns with your goals?"
```

### Q145: You're in middle of sprint, critical pipeline owned by another team is causing delays, team is unresponsive?

**Answer:**

**Escalation:**

1. **Immediate:**
   - Document blocking issue
   - Find alternative workaround
   - Continue with unblocked work

2. **Communication:**
   - Email documenting issue
   - Impact assessment
   - Request for timeline

3. **Escalation Path:**
   - After 2 days: Manager of other team
   - After 5 days: Project lead
   - After 1 week: Director level

4. **Alternative:**
   - Build temporary workaround
   - Reduce dependency
   - Replicate functionality

### Q146: During testing, critical bug days before release. How to manage?

**Answer:**

**Immediate Steps:**

1. **Assess Impact:**
   - Severity level
   - Affected users/features
   - Revenue impact

2. **Decision:**
   - **Option A**: Fix and delay (if high impact)
   - **Option B**: Release with workaround
   - **Option C**: Hotfix post-release

3. **If Fixing:**
   - Prioritize in queue
   - Expedited testing
   - Risk/benefit analysis

4. **Prevent Future:**
   - Earlier QA involvement
   - Automated testing coverage
   - Better staging environment
   - Code review process

### Q147: Handling git conflicts and code review process?

**Answer:**

**Git Workflow:**
1. Feature branches
2. Pull requests
3. Code review
4. Automated tests
5. Merge
6. Deploy

---

## Testing & Quality Assurance

### Q148: During testing, QA finds critical bug days before release?

**Answer:** (See Q146 above)

### Q149: BA asked to fix bug without QA phase?

**Answer:**

**Response:**

1. **Acknowledge:**
   - "I understand the urgency"
   - "I want to help"

2. **Explain Risks:**
   - "Skipping QA has 50% chance of new issues"
   - "Previous example showed impact"

3. **Propose:**
   ```
   Option A: Fast-track QA (2-3 hours)
   - Prioritize in QA queue
   - Parallel testing with review
   - Target: 4-hour deployment
   
   Option B: Limited hotfix
   - Scope change confirmed safe
   - Enhanced monitoring
   - Rollback plan ready
   ```

4. **If Forced:**
   - Document decision
   - Personal responsibility
   - Enhanced monitoring
   - Stakeholder awareness

---

## Professional Development

### Q150: You were asked to do something without proper technical skills?

**Answer:**

**Approach:**

1. **Assess Timeline:**
   - Is there time to learn?
   - Can someone else help?
   - What's the risk?

2. **Learning Strategy:**
   - Online courses (2-3 days)
   - Documentation reading
   - POC/small project
   - Pair with expert

3. **Implementation:**
   - Start small
   - Get feedback
   - Iterate
   - Document learnings

---

## GenAI & LLM Systems

### Q151: How is memory persistence addressed in GenAI systems?

**Answer:**

**Challenge:** LLMs don't have persistent memory

**Solutions:**

1. **Vector Databases:**
   - Store conversation embeddings
   - Retrieve relevant context
   - Tools: Pinecone, Weaviate

2. **Long-term Memory Store:**
   ```python
   class ChatAgent:
       def __init__(self):
           self.vector_db = PineconeDB()
           self.short_term = []
       
       def retrieve_context(self, query):
           return self.vector_db.search(query, top_k=5)
       
       def chat(self, user_input):
           context = self.retrieve_context(user_input)
           prompt = f"Context: {context}\nUser: {user_input}"
           return llm.generate(prompt)
   ```

3. **Graph Databases:**
   - Store relationships between facts
   - Tools: Neo4j

### Q152: Does LLM have its own state or memory?

**Answer:**

**No**, LLMs are stateless:

- Each inference is independent
- Context window is conversation history
- After conversation ends, information is lost
- External storage required for state

**Architecture for Stateful Behavior:**
```
User Input → Retrieve Memory → Add to Prompt → LLM → Store Result → Memory
```

---

## System Design & Architecture

### Q153: Could you explain architecture of your current project?

**Answer:**

**Standard Data Lakehouse:**

**Layers:**
1. **Ingestion**: Cloud Storage, Kafka, Databases
2. **Landing**: Raw data in Parquet
3. **Bronze**: Deduplicated, schema validated
4. **Silver**: Cleaned, enriched, quality checked
5. **Gold**: Analytics-ready, aggregated

**Technologies:**
- Processing: Apache Spark / Databricks
- Storage: Delta Lake / Cloud Storage
- Orchestration: Airflow / ADF
- Metadata: Unity Catalog
- BI: Tableau / Power BI

### Q154: What is difference between UDF and UDTF in Spark?

**Answer:**

**UDF (User Defined Function):**
- Takes single row input
- Returns single value
- Example: `df.withColumn("new_col", udf_func(col("old_col")))`

**UDTF (User Defined Table Function):**
- Takes single row input
- Returns multiple rows
- Example: Exploding nested arrays

**Comparison:**

| Aspect | UDF | UDTF |
|--------|-----|------|
| **Input** | Single row | Single row |
| **Output** | Single value | Multiple rows |
| **Use Case** | Transformation | Expansion |
| **Performance** | Faster | Slower |

---

## Miscellaneous

### Q155: How do you deal with sensitive/PII data?

**Answer:**

**Approaches:**

1. **Data Masking:**
   ```python
   df = df.withColumn(
       "email",
       when(col("email").isNotNull(), 
            concat(substring(col("email"), 1, 2), lit("***")))
   )
   ```

2. **Encryption:**
   - At rest: TDE, KMS
   - In transit: SSL/TLS
   - Column-level: Database encryption

3. **Access Control:**
   - RBAC
   - Row-level security
   - Column-level security

4. **Audit Logging:**
   - Track access
   - Monitor unusual patterns
   - Alert on violations

### Q156: Suppose you have 2 critical tasks to be delivered. How do you prioritize?

**Answer:**

**Prioritization Framework:**

1. **Assess Impact:**
   - Business value
   - Revenue impact
   - User count affected
   - Timeline criticality

2. **Complexity:**
   - Effort required
   - Resources needed
   - Risk level

3. **Dependencies:**
   - Blocking other work
   - Resource availability
   - External dependencies

4. **Decision:**
   - High impact + low effort = Start first
   - Communicate priorities to team
   - Document decision rationale

### Q157: You need to build a real-time data pipeline to process events from a streaming source (e.g., Kafka) and store the results in a Delta Lake table. What are the key components and considerations?

**Answer:**

**Key Components:**

1. **Data Source:**
   - Apache Kafka or equivalent streaming source
   - Message format (JSON, Avro, Protobuf)
   - Topic partitioning strategy

2. **Ingestion Layer:**
   - Spark Structured Streaming for real-time processing
   - Use readStream() API to consume from Kafka
   - Configure trigger and batch intervals

3. **Processing Logic:**
   - Stateless transformations
   - Windowed aggregations
   - Stateful operations (maintain state for joins, deduplication)

4. **Delta Lake Storage:**
   - Structured data format with ACID properties
   - Use writeStream() with append or update mode
   - Configure checkpointing for fault tolerance

5. **Considerations:**
   - **Late arriving data**: Handle with water marks
   - **Exactly-once semantics**: Use idempotent writes
   - **Schema evolution**: Use allowSchemaEvolution option
   - **Performance**: Partition data appropriately
   - **Monitoring**: Track lag, throughput, processing time

6. **Error Handling:**
   - Dead letter queue for invalid messages
   - Retry mechanisms
   - Alerting on failures

### Q158: What is the Global Interpreter Lock (GIL) in Python, and how does it affect threading? Can you tell us few scenarios where GIL can be used?

**Answer:**

**Global Interpreter Lock (GIL):**

**GIL Threading Model Visualization:**
```
WITHOUT GIL (True Parallelism):    WITH GIL (CPython - Sequential):
┌──────────────────────────┐       ┌──────────────────────────┐
│ Thread 1 │ Thread 2 │ T3 │       │ GIL Lock Holder          │
│ ████████ | ░░░░░░░░ | ░░ │       │                          │
│ Running  | Blocked  |Block│       │ Time: 0-2ms              │
│ Time: 5s │ Time: 0s │ 0s  │       │ Thread 1 executes        │
└──────────────────────────┘       ├──────────────────────────┤
Total Time: 5s                       │ GIL Lock Holder          │
True Parallelism!                    │ Time: 2-4ms              │
                                     │ Thread 2 executes        │
                                     ├──────────────────────────┤
                                     │ GIL Lock Holder          │
                                     │ Time: 4-6ms              │
                                     │ Thread 1 executes        │
                                     └──────────────────────────┘
                                     Total Time: 6ms
                                     Sequential - No true parallelism

I/O vs CPU Bound Work:
I/O OPERATIONS (Release GIL):       CPU OPERATIONS (Hold GIL):
Thread 1: [Computing] [Waiting] → Release GIL ✓
Thread 2:              [Computing] [Waiting] → Release GIL ✓
                       (Can run while T1 waits)

vs

Thread 1: [Computing...........................] Hold GIL
Thread 2: [Waiting..........][Computing...] Hold GIL
         (Blocked - can't run)
         Total time: longer!
```

**What is GIL:**
- A mutex that protects access to Python objects in CPython
- Only one thread can execute Python bytecode at a time
- Prevents memory management issues with reference counting

**Impact on Threading:**
- Prevents true parallelism in multi-threaded Python programs
- Only one thread executes Python code at a time
- I/O bound operations release GIL (network, file operations)
- CPU-bound operations suffer from GIL contention

**GIL Performance Comparison:**
```
┌─────────────────────────────────────────────────────────┐
│ Task Type         │ Single Thread │ Multi-threaded    │
├─────────────────────────────────────────────────────────┤
│ I/O Operations    │   10s (slow)  │ 3s (3x faster)   │
│  (Network/File)   │               │ ✓ Threads wait   │
├─────────────────────────────────────────────────────────┤
│ CPU Operations    │   10s (fast)  │ 10s (no gain)    │
│  (Math/Process)   │               │ ✗ GIL serializes │
└─────────────────────────────────────────────────────────┘
```

**Scenarios Where GIL is Used:**

1. **I/O-Bound Applications:**
   - Web scraping (downloads wait for network)
   - API calls (waiting for responses)
   - Database queries (waiting for DB responses)
   - File operations (disk I/O wait)
   - Network requests (network I/O wait)

2. **Concurrent I/O Operations:**
   - Multiple threads waiting for network responses
   - Each thread releases GIL during I/O wait
   - Effective parallelism for I/O operations

3. **When to Avoid:**
   - CPU-intensive computations
   - Matrix operations
   - Machine learning model inference
   - Scientific calculations

**Alternatives:**
- Use multiprocessing for CPU-bound tasks (separate processes, no GIL)
- Use asyncio for I/O-bound tasks (async/await, single-threaded but efficient)
- Use Cython or C extensions to release GIL

### Q159: How do you explain complex technical concepts to non-technical stakeholders?

**Answer:**

**Communication Strategy:**

1. **Know Your Audience:**
   - Understand their background
   - Identify their pain points
   - Learn what they care about

2. **Use Analogies:**
   - Compare to familiar concepts
   - Example: "Database indexing is like a library card catalog"
   - Make abstract concepts concrete

3. **Focus on Business Impact:**
   - Connect to business outcomes
   - Explain in terms of ROI
   - Show how it solves their problems

4. **Avoid Jargon:**
   - Use simple language
   - Define technical terms when necessary
   - Use layman's terms

5. **Visual Aids:**
   - Diagrams and flowcharts
   - Screenshots
   - Graphs showing metrics

6. **Tell Stories:**
   - Use real-world examples
   - Case studies
   - Success stories

7. **Encourage Questions:**
   - Create safe space to ask
   - Verify understanding
   - Clarify as needed

### Q160: How do you prevent unrealistic sprint commitments? What do you do if the team commits to too much work in a sprint?

**Answer:**

**Preventing Unrealistic Commitments:**

1. **Historical Data:**
   - Track velocity over multiple sprints
   - Use actual capacity, not wishful thinking
   - Account for meetings and other activities

2. **Team Capacity Planning:**
   - Consider team size and experience
   - Account for leaves and absences
   - Factor in onboarding time for new members

3. **Buffer:**
   - Don't commit 100% capacity
   - Reserve 20-30% for unexpected issues
   - Plan for interruptions

4. **Realistic Estimation:**
   - Break down into smaller tasks
   - Use estimation techniques (planning poker)
   - Validate estimates with team

**If Team Commits Too Much:**

1. **Immediate Actions:**
   - Identify the risk early
   - Communicate to stakeholders
   - Discuss with team

2. **Prioritize:**
   - Rank items by importance
   - Identify what can be cut
   - Move low-priority items to next sprint

3. **Negotiate:**
   - Adjust scope
   - Extend timeline
   - Reduce quality (not ideal)

4. **Lessons Learned:**
   - Review what went wrong
   - Adjust future estimates
   - Update velocity calculations

### Q161: What can be causes of bad data?

**Answer:**

**Sources of Bad Data:**

1. **Data Entry Errors:**
   - Typos and manual mistakes
   - Incomplete information
   - Wrong data type entered

2. **System Issues:**
   - Software bugs
   - Database corruption
   - ETL job failures
   - Network transmission errors

3. **Data Integration Problems:**
   - Mismatched schemas
   - Duplicate records
   - Missing values
   - Inconsistent formatting

4. **Process Issues:**
   - Lack of validation rules
   - No data quality checks
   - Missing error handling
   - Inadequate testing

5. **Source Data Problems:**
   - Unreliable data sources
   - Third-party API failures
   - Deprecated data formats
   - Legacy system data inconsistencies

6. **Human Factors:**
   - Lack of understanding
   - Inadequate training
   - Careless work
   - Intentional manipulation

7. **Infrastructure Issues:**
   - Disk corruption
   - Network failures
   - Insufficient storage
   - Clock synchronization issues

**Prevention:**

- Implement validation rules
- Set up data quality monitoring
- Use schema validation
- Implement automated tests
- Create data governance policies

### Q162: How do you estimate your tasks?

**Answer:**

**Estimation Techniques:**

1. **Planning Poker:**
   - Team discussion
   - Story points or time estimates
   - Converge on consensus
   - Quick and collaborative

2. **Three-Point Estimation:**
   - Optimistic, pessimistic, most likely
   - Formula: (optimistic + 4*most_likely + pessimistic) / 6
   - Accounts for uncertainty

3. **Comparison-Based:**
   - Compare to similar completed tasks
   - Use historical data
   - Relative sizing

4. **Task Breakdown:**
   - Break into smaller subtasks
   - Estimate each subtask
   - Sum up for total estimate

5. **Time-Based Estimation:**
   - Hours, days, weeks
   - Include overhead
   - Account for dependencies

**Factors to Consider:**

- Team experience
- Task complexity
- Unknowns and risks
- External dependencies
- Historical velocity

**Best Practices:**

- Estimate as a team
- Include buffer for unknowns
- Review and adjust estimates
- Track actual vs. estimated
- Use estimates for planning, not commitments

### Q163: What Databricks Delta Lake Optimizations do you know?

**Answer:**

**Delta Lake Optimizations:**

1. **OPTIMIZE Command:**
   - Compacts small files into larger files
   - Improves read performance
   - Syntax: `OPTIMIZE table_name`
   - Optional: `ZORDER BY column_name`

2. **Z-Ordering:**
   - Colocates related data within files
   - Improves query performance
   - Syntax: `OPTIMIZE table_name ZORDER BY (col1, col2)`
   - Reduces I/O for filtered queries

3. **Partitioning:**
   - Organize data by columns
   - Prune unnecessary partitions
   - Improves query speed

4. **Clustered Index (Liquid Clustering):**
   - Automatic data organization
   - No need to specify partition columns
   - Improves join performance

5. **VACUUM:**
   - Removes old file versions
   - Frees up storage
   - Syntax: `VACUUM table_name RETAIN 30 DAYS`

6. **Data Skipping:**
   - Bloom filters and min/max stats
   - Automatic file skipping
   - Reduces data read

7. **Caching:**
   - Cache frequently accessed tables
   - Improves query performance

### Q164: What SCD Types do you know?

**Answer:**

**Slowly Changing Dimensions (SCD) Types:**

1. **SCD Type 0:**
   - No changes allowed
   - Fixed historical data
   - Rarely used

2. **SCD Type 1:**
   - Overwrite old values
   - No history maintained
   - Simplest approach
   - Example: Correcting data errors

3. **SCD Type 2:**
   - Maintain full history
   - Add effective_date and end_date
   - Add is_current flag
   - New row for each change
   - Most common in data warehouses

4. **SCD Type 3:**
   - Maintain previous and current values
   - Limited history (one previous version)
   - Add current_value and previous_value columns
   - Balanced history and storage

5. **SCD Type 4:**
   - Separate historical table
   - Main table has current values
   - History table maintains changes
   - Efficient for frequent changes

6. **SCD Type 6:**
   - Hybrid approach (1 + 2 + 3)
   - Current values and history
   - Previous and effective dates
   - Most complex

**Implementation in Spark:**

```scala
// SCD Type 2 implementation
val updates = current_data.select("id", "name", "salary")
val merged = target.merge(
  target("id") === updates("id"),
  "matched and (target.salary <> updates.salary)" -> WHEN_MATCHED_UPDATE(
    col("end_date") -> current_date(),
    col("is_current") -> false
  ),
  "not matched" -> WHEN_NOT_MATCHED_INSERT(
    col("id") -> updates("id"),
    col("name") -> updates("name"),
    col("salary") -> updates("salary"),
    col("effective_date") -> current_date(),
    col("end_date") -> null,
    col("is_current") -> true
  )
)
```

### Q165: How would you install a culture of ownership in a data engineering team, ensuring engineers feel responsible for the end-to-end reliability of their pipelines?

**Answer:**

**Building Ownership Culture:**

1. **Clear Ownership:**
   - Assign each pipeline to an owner
   - Document ownership explicitly
   - Rotate ownership periodically for knowledge sharing

2. **Enable Autonomy:**
   - Allow engineers to make decisions
   - Empower to deploy and fix issues
   - Trust and support

3. **Visibility and Monitoring:**
   - Provide dashboards for pipeline health
   - Expose metrics and logs
   - Make problems visible early

4. **Alert Ownership:**
   - Engineer on call owns alerts
   - Quick response expectations
   - Post-mortems on failures

5. **Learning from Failures:**
   - Blameless post-mortems
   - Share learnings across team
   - Invest in improving reliability

6. **Recognition:**
   - Celebrate reliability achievements
   - Recognize problem-solving efforts
   - Acknowledge improvements

7. **Tooling and Automation:**
   - Provide testing frameworks
   - Automated deployment tools
   - Monitoring and alerting systems

8. **Career Development:**
   - Ownership ties to career growth
   - Senior roles focus on reliability
   - Technical leadership opportunities

### Q166: How would you handle a situation where two senior engineers in your team have fundamentally different technical opinions on a critical architecture decision?

**Answer:**

**Handling Technical Disagreements:**

1. **Encourage Discussion:**
   - Create safe space for debate
   - Ensure both sides are heard
   - Focus on ideas, not personalities

2. **Gather Evidence:**
   - Ask for trade-offs analysis
   - Request performance comparisons
   - Demand proof of concepts if needed

3. **Evaluate Options:**
   - List pros and cons of each approach
   - Consider team skills and experience
   - Evaluate maintenance burden
   - Consider scalability needs

4. **Decision Framework:**
   - Use data-driven approach
   - Consider risk levels
   - Factor in timeline
   - Evaluate technical debt implications

5. **Make Decision:**
   - Decide based on business needs
   - Explain reasoning clearly
   - Document decision

6. **Move Forward:**
   - Build consensus post-decision
   - Align entire team
   - Set clear success criteria
   - Plan review/retrospective

7. **Learn:**
   - Reflect on what worked
   - Use learnings for future decisions
   - Build decision-making framework

### Q167: How would you approach a situation where a client insists on a technical solution that you believe is inappropriate for their actual business needs?

**Answer:**

**Addressing Inappropriate Solutions:**

1. **Understand Their Perspective:**
   - Ask why they prefer this solution
   - Listen to their concerns
   - Understand their constraints

2. **Gather Data:**
   - Document business requirements
   - Analyze technical feasibility
   - Compare with industry standards

3. **Present Alternatives:**
   - Propose better solutions
   - Explain trade-offs clearly
   - Use data to support recommendations
   - Show pros and cons

4. **Communication:**
   - Be respectful and professional
   - Avoid being condescending
   - Use business language when possible
   - Translate technical concepts

5. **Document Concerns:**
   - Write formal risk assessment
   - Outline potential issues
   - Estimate costs of problems
   - Suggest mitigation strategies

6. **Collaborate:**
   - Find compromise if possible
   - Explore hybrid approaches
   - Schedule workshop with stakeholders

7. **Decision:**
   - If client insists: document in writing
   - Include liability disclaimers
   - Plan monitoring and checkpoints
   - Prepare exit strategy

### Q168: Can you explain the difference between storing data in delta lake and storing it in parquet files? What are the advantages of delta tables?

**Answer:**

**Parquet vs Delta Lake:**

| Feature | Parquet | Delta Lake |
|---------|---------|-----------|
| **Format** | Column-oriented storage format | Parquet + transaction log |
| **ACID** | Not supported | Fully supported |
| **Schema Evolution** | Limited | Full support |
| **Updates/Deletes** | Not supported | Fully supported (MERGE, UPDATE, DELETE) |
| **Time Travel** | Not supported | Supported (query historical versions) |
| **Data Validation** | None | Schema validation |
| **Scalability** | Good for read-heavy | Better for mixed workloads |

**Advantages of Delta Lake:**

1. **ACID Transactions:**
   - Atomicity: All or nothing
   - Consistency: Valid state always
   - Isolation: No dirty reads
   - Durability: Data persists

2. **Schema Evolution:**
   - Automatically adapt to new columns
   - Add, rename, or modify columns
   - No data migration needed

3. **Data Quality:**
   - Schema enforcement
   - Constraint support
   - Data validation

4. **Time Travel:**
   - Query previous versions
   - Audit historical changes
   - Rollback capability

5. **DML Support:**
   - UPDATE operations
   - DELETE operations
   - MERGE operations

6. **Performance:**
   - Predicate pushdown
   - Partition pruning
   - Z-ordering

7. **Unified Platform:**
   - Single format for all operations
   - Batch and streaming
   - ML and BI tools

8. **Compatibility:**
   - Compatible with Apache Spark
   - Works with Databricks
   - Open source format

### Q169: Can you describe what options we have in AWS to run Spark workloads? Which one do you choose?

**Answer:**

**AWS Spark Options Architecture:**
```
                         AWS SPARK ECOSYSTEM

        ┌─────────────────────────────────────────────────┐
        │         Your Spark Application                  │
        └────┬────────────────────────────────┬──────┬────┘
             │                                │      │
             ▼                                ▼      ▼
    ┌──────────────────┐  ┌──────────────┐  ┌──────────────┐
    │  DATABRICKS      │  │   GLUE       │  │    EMR       │
    │  (Managed)       │  │  (Serverless)│  │  (Cluster)   │
    │  ✓ Easiest       │  │  ✓ Minimal   │  │  ✓ Max       │
    │  ✓ Delta Lake    │  │  ✓ Pay/min   │  │  ✓ Control   │
    │  ✓ Enterprise    │  │  ✓ Quick     │  │  ✓ Flexible  │
    │  ✗ Higher cost   │  │  ✗ Limited   │  │  ✗ Complex   │
    └──────────┬───────┘  └──────┬───────┘  └──────┬───────┘
               │                 │                 │
               └──────┬──────────┴─────────────────┘
                      ▼
        ┌────────────────────────────────────────┐
        │    AWS Compute & Storage Services      │
        │  ┌──────────────┐  ┌────────────────┐ │
        │  │ EC2 (Virtual)│  │  S3 (Storage) │ │
        │  │ RDS (DB)     │  │ Lambda (Func) │ │
        │  └──────────────┘  └────────────────┘ │
        └────────────────────────────────────────┘

COST VS CONTROL TRADE-OFF:
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  High      EC2 (Manual) ─────┐                          │
│  Control                      ├─ EMR                    │
│            Databricks ────┐   │                         │
│            Low Control    ├─ Glue                       │
│  Low                      ┘                             │
│                                                          │
│  Low Cost (Glue)      ────────────────────> High Cost   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**AWS Options for Spark:**

1. **EMR (Elastic MapReduce):**
   - Fully managed cluster
   - Auto-scaling capabilities
   - Cost-effective for batch jobs
   - Full control over cluster configuration

2. **Databricks on AWS:**
   - Managed service
   - Optimized for Delta Lake
   - SQL endpoint
   - Jobs API
   - Higher cost but easier management

3. **EC2:**
   - Full control
   - Complex setup and management
   - Cost-effective if optimized
   - Manual scaling

4. **Glue (AWS Glue):**
   - Serverless Spark
   - Pay per minute
   - Good for small-to-medium jobs
   - Limited customization

5. **RDS/Redshift:**
   - Not Spark, but alternatives
   - SQL-based processing
   - Better for analytics

**Selection Matrix:**
```
┌──────────────────┬──────────┬──────────┬──────┬──────┐
│ Requirement      │Databricks│   EMR    │ Glue │ EC2  │
├──────────────────┼──────────┼──────────┼──────┼──────┤
│Management Effort │  Low     │  Medium  │ Low  │ High │
│Cost              │  High    │  Medium  │ Low  │Medium│
│Flexibility       │  High    │  High    │ Low  │ High │
│Setup Time        │  Fast    │  Medium  │ Fast │ Slow │
│Enterprise Ready  │  ✅ Yes  │  ✅ Yes  │  ❌  │ ⚠️   │
└──────────────────┴──────────┴──────────┴──────┴──────┘
```

**Selection Criteria:**

- **EMR**: Batch jobs, cost-sensitive, need full control
- **Databricks**: Production workloads, need enterprise features
- **Glue**: Small-to-medium workloads, serverless preference
- **EC2**: Specialized requirements, maximum control

**My Choice:**
- **Production**: Databricks on AWS for reliability and management
- **Batch**: EMR for cost optimization
- **Ad-hoc**: Glue for simplicity

### Q170: What are different orchestration tools that you have used, and which is best for the ETL pipelines/data pipelines? Explain Airflow?

**Answer:**

**Orchestration Tools Comparison:**
```
┌────────────────────────────────────────────────────────────┐
│         ORCHESTRATION TOOLS COMPARISON                     │
├──────────────┬────────────────┬────────────┬───────────────┤
│  Apache      │  Databricks    │   Azure    │   dbt / Prefect
│  Airflow     │    Jobs        │    ADF     │                │
├──────────────┼────────────────┼────────────┼───────────────┤
│ DAG-based    │ Native to DB   │ Visual     │ Modern DAG    │
│ Python Code  │ Simpler setup  │ Enterprise │ Better errors │
│ Flexible     │ Limited flex   │ Complex    │ Easier debug  │
│ Self-hosted  │ Managed        │ Cloud      │ Various       │
│ Large comm.  │ Good for       │ Good for   │ Growing comm. │
│              │ Spark jobs     │ Azure      │ Emerging      │
└──────────────┴────────────────┴────────────┴───────────────┘
```

**Apache Airflow Architecture & DAG Example:**

```
┌─────────────────────────────────────────────────────────────┐
│            APACHE AIRFLOW ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │  Webserver   │  │   Scheduler  │  │  Metadata DB    │ │
│  │  (UI & API)  │  │  (Triggers)  │  │  (State, Logs)  │ │
│  └──────────────┘  └──────────────┘  └──────────────────┘ │
│         │                  │                    │          │
│         └──────────────────┼────────────────────┘          │
│                            │                               │
│                    ┌───────▼────────┐                      │
│                    │   Executors    │                      │
│                    │ (Run Tasks)    │                      │
│                    └────────────────┘                      │
└─────────────────────────────────────────────────────────────┘

EXAMPLE DAG (Directed Acyclic Graph):

        ┌─────────────────┐
        │  Start Task     │
        │  (python_op)    │
        └────────┬────────┘
                 │
        ┌────────▼─────────┐
        │  Extract Data    │
        │  (bash_op)       │
        └────────┬─────────┘
                 │
      ┌──────────┴──────────┐
      │                     │
      ▼                     ▼
  ┌────────────┐      ┌────────────┐
  │ Transform  │      │  Validate  │
  │  (spark)   │      │   Data     │
  └─────┬──────┘      └──────┬─────┘
        │                    │
        │        ┌───────────┘
        │        │
        ▼        ▼
   ┌──────────────────┐
   │  Load to DW      │
   │  (SQL_op)        │
   └────────┬─────────┘
            │
        ┌───▼──────┐
        │  Success │
        │  (email) │
        └──────────┘
```

**Orchestration Tools:**

1. **Apache Airflow:**
   - DAG-based workflow
   - Python-based configuration
   - Rich monitoring UI
   - Extensive ecosystem

2. **Databricks Jobs:**
   - Native to Databricks
   - Good integration with Delta Lake
   - Simpler for Spark jobs
   - Less flexible

3. **Azure Data Factory:**
   - Microsoft's cloud solution
   - Good for Azure ecosystem
   - Visual pipeline builder
   - Cost can be high

4. **dbt (Data Build Tool):**
   - SQL-based transformations
   - Great for analytics
   - Version control integration
   - Community support

5. **Prefect/Dagster:**
   - Modern alternatives
   - Better error handling
   - Improved developer experience

**Apache Airflow Deep Dive:**

**Architecture:**
- Scheduler: Manages task scheduling
- Executor: Executes tasks
- Webserver: UI and API
- Metadata DB: DAG and task state

**Concepts:**
- DAG: Directed Acyclic Graph
- Task: Individual unit of work
- Operator: Type of task
- Hook: Connection to external systems

**Advantages:**
- Flexible and powerful
- Large community
- Extensive integrations
- Easy to debug

**Disadvantages:**
- Steep learning curve
- Operational overhead
- Not ideal for real-time
- Complex deployment

**Best For:**
- Complex ETL workflows
- Multiple data sources
- Need for flexibility
- Large-scale data pipelines

### Q171: As a team lead, what would you do if one of your teammates kept giving the same updates during daily standups?

**Answer:**

**Handling Stalled Progress:**

1. **Identify the Problem:**
   - Talk to team member privately
   - Ask what's blocking them
   - Understand the real issue
   - Listen without judgment

2. **Possible Root Causes:**
   - Task is too complex
   - Insufficient clarity
   - Blocked by external dependency
   - Lack of skills
   - Personal/external issues

3. **Actions to Take:**

   **If Lack of Clarity:**
   - Break down task further
   - Provide more details
   - Assign a mentor

   **If Blocked:**
   - Remove blockers immediately
   - Escalate if needed
   - Help with external coordination

   **If Skill Gap:**
   - Provide training/resources
   - Pair programming
   - Adjust task scope

   **If Personal Issues:**
   - Show empathy
   - Offer support
   - Adjust workload temporarily

4. **In Standup:**
   - Don't call out publicly
   - Address privately after standup
   - Focus on helping, not blaming

5. **Follow-up:**
   - Track progress
   - Check in frequently
   - Celebrate when they make progress

### Q172: You are in the middle of a sprint and suddenly the product owner comes up with a new requirement. What will you do?

**Answer:**

**Handling Mid-Sprint Changes:**

1. **Understand the Requirement:**
   - Get full details
   - Clarify priority
   - Understand deadline
   - Assess impact

2. **Evaluate Impact:**
   - Estimate effort needed
   - Check team capacity
   - Identify what gets displaced
   - Calculate risk

3. **Decision Options:**

   **Option 1: Add to Current Sprint**
   - If low effort (< 4 hours)
   - If it's truly urgent
   - If team has capacity
   - Identify what gets deferred

   **Option 2: Add to Next Sprint**
   - If can wait a week
   - Normal priority
   - Team is full

   **Option 3: Urgent/High Priority**
   - If critical bug or blocker
   - Interrupt current work
   - Plan compensation

4. **Communicate:**
   - Explain impact to PO
   - Discuss trade-offs
   - Get alignment
   - Document decision

5. **Adjust Plans:**
   - Update sprint board
   - Communicate changes to team
   - Reset expectations
   - Adjust velocity forecast

6. **Prevention:**
   - Establish change request process
   - Set sprint boundaries
   - Request advance planning
   - Regular alignment meetings

### Q173: When should you use Apache Spark, and when should you use Apache Flink? What are the main differences between them?

**Answer:**

**Processing Model Comparison:**
```
APACHE SPARK (Micro-Batch):        APACHE FLINK (True Streaming):
┌──────────────────────────┐       ┌──────────────────────────┐
│  Data Stream Input       │       │  Data Stream Input       │
└────────────┬─────────────┘       └────────────┬─────────────┘
             │                                  │
      [Batch Window 1]                [Event 1] [Event 2] [Event 3]...
      [Batch Window 2]                    │         │        │
      [Batch Window 3]                    ├────────┬┘        │
             │                            │        │         │
      ┌──────▼─────────┐          ┌──────▼┴───────┴────┐
      │  Micro-batch   │          │ Process Each Event │
      │  Processing    │          │    Individually    │
      │  (seconds)     │          │  (milliseconds)    │
      └──────┬─────────┘          └──────┬─────────────┘
             │                           │
     [Result 1][Result 2][Result 3]...  [Result 1][Result 2][Result 3]...
             │                           │
     Latency: Seconds                    Latency: Milliseconds
```

**Spark vs Flink Comparison:**

| Aspect | Apache Spark | Apache Flink |
|--------|-------------|-------------|
| **Processing Model** | Micro-batch | True streaming |
| **Latency** | Seconds | Milliseconds |
| **Throughput** | High | Very high |
| **Fault Tolerance** | RDD lineage | Checkpoint + state |
| **State Management** | Limited | Advanced |
| **Learning Curve** | Moderate | Steep |
| **Ecosystem** | Rich (ML, SQL) | Growing |
| **Setup Complexity** | Medium | Complex |

**Decision Matrix:**
```
┌─────────────────────────────────┬──────────┬─────────┐
│ Requirement                     │ Spark    │ Flink   │
├─────────────────────────────────┼──────────┼─────────┤
│ Low Latency (<1s)               │ ❌ No    │ ✅ Yes  │
│ High Latency (seconds OK)       │ ✅ Yes   │ ✅ Yes  │
│ Batch Processing                │ ✅ Yes   │ ❌ No   │
│ Complex Event Processing        │ ⚠️ Fair  │ ✅ Yes  │
│ Stateful Processing             │ ⚠️ Fair  │ ✅ Yes  │
│ ML/SQL Integration              │ ✅ Yes   │ ❌ No   │
│ Team Familiarity                │ ✅ Yes   │ ❌ No   │
│ Learning Curve                  │ ✅ Easy  │ ❌ Hard │
│ Ecosystem Maturity              │ ✅ Best  │ ✅ Good │
└─────────────────────────────────┴──────────┴─────────┘
```

**When to Use Spark:**

1. **Batch Processing:**
   - Daily/hourly jobs
   - Large data sets
   - Complex transformations

2. **Micro-batch Streaming:**
   - Latency in seconds acceptable
   - Cost optimization priority
   - Need for ML/SQL

3. **Mixed Workloads:**
   - Batch and streaming combined
   - Rapid development needed
   - Team familiar with Spark

**When to Use Flink:**

1. **Real-time Streaming:**
   - Millisecond latency required
   - Continuous data processing
   - Event-driven applications

2. **Complex Event Processing:**
   - Stateful transformations
   - Complex windows and joins
   - Advanced CEP patterns

3. **Event Time Processing:**
   - Out-of-order events
   - Late-arriving data important
   - Event time semantics critical

4. **High Throughput:**
   - Millions of events per second
   - Performance critical

**Recommendation:**

- Use **Spark** for most use cases (easier, richer ecosystem)
- Use **Flink** for true real-time with complex state

### Q174: What does CAP theorem state? Where is Cassandra in the CAP theorem?

**Answer:**

**CAP Theorem:**

**Visual CAP Theorem Model:**
```
                 ╔═══════════╗
                 ║  NETWORK  ║
                 ║PARTITION? ║
                 ╚═════╤═════╝
                       │
            ┌──────────┴──────────┐
            │                     │
           YES                   NO
            │                     │
    ┌───────▼────────┐    ┌──────▼──────────┐
    │  Choose ONE:   │    │  Can have:      │
    │  • Consistency │    │  • Consistency  │
    │    OR          │    │  • Availability │
    │  • Availability│    │  • Partition    │
    │                │    │    Tolerance    │
    └────────────────┘    └─────────────────┘

        ╔════════════════════════════════════════╗
        ║     The CAP TRIANGLE                   ║
        ║                                        ║
        ║          Consistency (C)               ║
        ║              /    \                    ║
        ║             /      \                   ║
        ║            /  CA    \  CP              ║
        ║           /          \                 ║
        ║       AP /            \ ACID Databases ║
        ║        /   Partition   \               ║
        ║       /    Tolerance    \              ║
        ║      /__________________\              ║
        ║   Availability (A)   (P)               ║
        ║                                        ║
        ║ Database Positioning:                  ║
        ║ • CA: Traditional SQL (no partition)   ║
        ║ • CP: Redis, BigTable, MongoDB        ║
        ║ • AP: Cassandra, DynamoDB, Riak      ║
        ╚════════════════════════════════════════╝
```

The CAP theorem states that a distributed system can guarantee only two of three properties:

1. **Consistency (C):**
   - All nodes see the same data
   - Reads return most recent writes
   - Strong consistency

2. **Availability (A):**
   - System remains operational
   - All requests get response
   - No single point of failure

3. **Partition Tolerance (P):**
   - System continues despite network partition
   - Handles node failures
   - Resilience to network issues

**Key Insight:**
In the presence of a network partition, you must choose between:
- Consistency (stop and wait for partition healing)
- Availability (return potentially stale data)

**Cassandra's Position:**

**Cassandra chooses: AP (Availability + Partition Tolerance)**

**Database Comparison:**
```
┌─────────────────────────────────────────────────────┐
│            DISTRIBUTED DATABASE CHOICES              │
├──────────────┬──────────────┬──────────────┬─────────┤
│   CA Model   │   CP Model   │   AP Model   │  Notes  │
├──────────────┼──────────────┼──────────────┼─────────┤
│ PostgreSQL   │ Redis        │ Cassandra    │ No      │
│ (Traditional)│ BigTable     │ DynamoDB     │network  │
│ MySQL        │ MongoDB*     │ Riak         │ issues  │
│ SQLite       │ HBase        │ Dynamo       │ in CA   │
│              │ Memcached    │ CouchDB      │ model   │
└──────────────┴──────────────┴──────────────┴─────────┘
```

**Characteristics:**

1. **High Availability:**
   - Data replicated across multiple nodes
   - No single point of failure
   - Continues operating despite node failures

2. **Partition Tolerant:**
   - Designed for distributed systems
   - Handles network partitions gracefully
   - Continues serving requests

3. **Eventual Consistency:**
   - Not strongly consistent
   - Eventually consistent model
   - Read repair and anti-entropy mechanisms

**Implications:**

**Advantages:**
- Highly available and fault-tolerant
- Can scale horizontally
- No blocking during partitions

**Disadvantages:**
- Data inconsistency possible
- Requires application-level handling
- Not suitable for financial transactions

**Trade-offs:**
- Tunable consistency with quorum reads/writes
- Balance availability and consistency
- W + R > N guarantees strong consistency

### Q175: How do you ensure high quality data is produced by your data pipeline?

**Answer:**

**Data Quality Assurance:**

1. **Input Validation:**
   - Schema validation
   - Data type checks
   - Range validation
   - Format validation
   - NULL checks

2. **Data Quality Rules:**
   - Completeness: No missing values
   - Uniqueness: No duplicates
   - Accuracy: Correct values
   - Consistency: Same across systems
   - Timeliness: Fresh data

3. **Testing:**
   - Unit tests for transformations
   - Integration tests for pipelines
   - Data validation tests
   - Edge case testing

4. **Monitoring:**
   - Monitor data volumes
   - Track quality metrics
   - Set up alerts for anomalies
   - Create SLOs for data quality

5. **Frameworks:**
   - Great Expectations (Python)
   - dbt tests (SQL)
   - Soda (Data monitoring)
   - Custom validation logic

6. **Error Handling:**
   - Quarantine bad data
   - Dead letter queues
   - Error notifications
   - Automatic retries

7. **Documentation:**
   - Document data definitions
   - Create data dictionary
   - Document quality rules
   - Version control configs

8. **Governance:**
   - Data ownership
   - Access control
   - Audit trails
   - Data lineage

### Q176: How would you organize effective work with a customer in a -10h time zone?

**Answer:**

**Managing Distributed Teams:**

1. **Communication Strategy:**
   - Identify overlap hours (if any)
   - Use asynchronous communication
   - Document decisions in writing
   - Create single source of truth

2. **Meeting Schedule:**
   - Find common working hours
   - Rotate meeting times when possible
   - Record meetings for those unable to attend
   - Use time zone converters

3. **Asynchronous Work:**
   - Use email, Slack, Jira
   - Create detailed specs upfront
   - Document decisions clearly
   - Use video recordings for complex topics

4. **Project Management:**
   - Clear task descriptions
   - Set expectations upfront
   - Detailed requirements
   - Multiple touchpoints

5. **Tools:**
   - Slack for quick updates
   - Jira/Trello for task tracking
   - Confluence for documentation
   - GitHub for code reviews

6. **Rituals:**
   - Daily async standup (Slack message)
   - Weekly sync meeting (if possible)
   - Sprint reviews (recorded)
   - Escalation process for urgent issues

7. **Build Trust:**
   - Be responsive during their business hours
   - Show progress regularly
   - Proactive communication
   - Keep commitments

### Q177: On your project, the architect doesn't accept any of your proposed solutions with no meaningful arguments. How would you try to resolve this issue?

**Answer:**

**Handling Architect Disagreement:**

1. **Understand Their Position:**
   - Ask for specific concerns
   - Request detailed feedback
   - Listen to their perspective
   - Ask "why" multiple times

2. **Request Criteria:**
   - What would make the solution acceptable?
   - What are the non-negotiables?
   - What are the trade-offs?
   - Document these

3. **Prepare Evidence:**
   - Benchmark similar solutions
   - Show proof of concepts
   - Provide performance data
   - Industry examples

4. **Propose Data-Driven Discussion:**
   - Set up meeting with clear agenda
   - Bring metrics and comparisons
   - Ask for specific objections
   - Request decision framework

5. **Escalate If Necessary:**
   - Involve team lead
   - Raise in architecture forum
   - Document concerns in writing
   - Request formal decision process

6. **Alternative Approaches:**
   - Ask what they would propose
   - Work collaboratively on solution
   - Find compromises
   - Explore hybrid approaches

7. **Document Decision:**
   - Write down the decision
   - Include reasoning
   - Record dissenting opinion if needed
   - Plan review point

8. **Move Forward:**
   - Accept decision professionally
   - Don't undermine publicly
   - Focus on implementation
   - Use learnings for future decisions

### Q178: What built-in optimization mechanisms does Spark have?

**Answer:**

**Spark Optimization Mechanisms:**

1. **Catalyst Optimizer:**
   - Optimizes logical plans
   - Applies optimization rules
   - Column pruning
   - Predicate pushdown
   - Constant folding
   - Dead code elimination

2. **Tungsten Project:**
   - Memory management improvements
   - Code generation
   - Cache-aware computation
   - Off-heap memory support

3. **Adaptive Query Execution (AQE):**
   - Dynamically optimize execution
   - Reoptimize based on runtime statistics
   - Skew handling
   - Join strategy adjustment
   - Partition coalescing

4. **Predicate Pushdown:**
   - Push filters to source
   - Reduce data read
   - Faster execution

5. **Partition Pruning:**
   - Skip partitions not needed
   - Faster scans

6. **Columnar Processing:**
   - Process column-at-a-time
   - Better CPU cache utilization
   - Compression benefits

7. **Bucketing:**
   - Pre-organize data
   - Speed up joins

8. **Caching:**
   - Cache intermediate results
   - Reuse across operations

### Q179: In what cases would you prefer to use a cluster with a large number of nodes but CPU cores (100 nodes, 10 CPU cores), and in what cases, on the contrary, few nodes but a lot of CPU cores (5 nodes, 200 CPU cores)?

**Answer:**

**Cluster Configuration Comparison:**

```
MANY SMALL NODES (100 × 10 cores):  FEW LARGE NODES (5 × 200 cores):

┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Node 1  │ Node 2  │ Node 3   │   │       Node 1 (Large)         │
│ ▯▯▯▯▯▯  │ ▯▯▯▯▯▯  │ ▯▯▯▯▯▯  │   │ ▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯         │
│ (10cores) (10cores) (10cores)  │   │ (200 cores)                  │
└──────────────────────────────┘   └──────────────────────────────┘
        ...100 nodes                        ...5 nodes

NETWORK & COMMUNICATION:            NETWORK & COMMUNICATION:
Many Partitions → More Shuffling    Few Partitions → Less Shuffling
Network Heavy ✓                      Network Light ✓

FAULT TOLERANCE:                    FAULT TOLERANCE:
Node Failure Impact:                Node Failure Impact:
• Low (1-2% tasks lost)             • High (20% tasks lost)
• Restart fast ✓                    • Restart slow ✗

MEMORY & CACHE:                     MEMORY & CACHE:
Local Cache: Small                  Local Cache: Large
L2/L3 Cache: Limited                L2/L3 Cache: Efficient
Total RAM: Limited per node         Total RAM: Abundant per node

PARALLELISM:                        PARALLELISM:
Fine-grained: High ✓               Fine-grained: Low ✗
Many tasks parallel                 Few tasks parallel
Better for I/O operations ✓         Better for compute ✓

COST COMPARISON (per hour):
Small Nodes: 100 × $0.50 = $50     Large Nodes: 5 × $2 = $10
                But network costs higher
                Effective: ~$65/hour
                                   Effective: ~$10/hour
```

**Decision Matrix:**
```
┌────────────────────────────┬──────────────┬────────────────┐
│ Characteristic             │ Many Small   │ Few Large      │
├────────────────────────────┼──────────────┼────────────────┤
│ Task Parallelism           │ ✅ Excellent │ ⚠️ Limited     │
│ I/O Throughput             │ ✅ High      │ ⚠️ Medium      │
│ CPU Computation            │ ⚠️ Medium    │ ✅ Excellent   │
│ Memory per Node            │ ✗ Low        │ ✅ High        │
│ Network Overhead           │ ⚠️ High      │ ✅ Low         │
│ Fault Tolerance            │ ✅ High      │ ✗ Low          │
│ Cluster Management         │ ✗ Complex    │ ✅ Simple      │
│ Setup Cost                 │ ⚠️ Medium    │ ⚠️ Medium      │
│ Operating Cost             │ ✗ High       │ ✅ Lower       │
│ Data Locality              │ ⚠️ Fair      │ ✅ Good        │
└────────────────────────────┴──────────────┴────────────────┘
```

**Cluster Configuration Decision:**

**Many Small Nodes (100 nodes, 10 cores each):**

Advantages:
- Better fault tolerance (fewer tasks affected by node failure)
- More parallelism for I/O operations
- Better for network-bound operations
- Easier to scale horizontally
- Better resource isolation

Use cases:
- Shuffle-heavy jobs
- High I/O operations
- Jobs with many small tasks
- Distributed computing benefits needed
- When failure tolerance critical

Disadvantages:
- More overhead (communication)
- Memory per node limited
- Complex management
- Higher network traffic
- Coordination overhead

**Few Large Nodes (5 nodes, 200 cores each):**

Advantages:
- Lower latency for data access
- Better for compute-intensive tasks
- More memory per node
- Less network overhead
- Simpler management
- Better for local caching

Use cases:
- CPU-intensive computations
- Memory-intensive operations
- Jobs with few large tasks
- Low latency requirements
- ML training jobs

Disadvantages:
- Lower fault tolerance
- Single node failure impacts more tasks
- Less parallelism for I/O
- Harder to scale dynamically

**Decision Factors:**

1. **Job Characteristics:**
   - I/O bound → Many small nodes
   - CPU bound → Few large nodes
   - Mixed → Depends on ratio

2. **Data Size:**
   - Large distributed data → Many small nodes
   - Fits in memory → Few large nodes

3. **Network Requirements:**
   - Heavy shuffle → Many small nodes
   - Minimal shuffle → Few large nodes

4. **Fault Tolerance:**
   - Critical → Many small nodes
   - Acceptable to retry → Few large nodes

### Q180: Explain the purpose of garbage collection (GC) in Python. What are the key mechanisms Python uses to manage memory and reclaim unused objects?

**Answer:**

**Garbage Collection in Python:**

**Python Memory Management Layers:**
```
┌─────────────────────────────────────────────────────────┐
│                    USER APPLICATION                     │
├─────────────────────────────────────────────────────────┤
│                  REFERENCE COUNTING                     │
│  ┌────────────────────────────────────────────────────┐ │
│  │ obj_a ref_count = 2     obj_b ref_count = 1       │ │
│  │   ↑                         ↑                      │ │
│  │   └─── Still allocated ─────┘                      │ │
│  │                                                    │ │
│  │ Delete reference → ref_count = 0 → Immediate free │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│            GENERATIONAL GARBAGE COLLECTION             │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Gen 0 (Young):     Collect frequently (fast)      │ │
│  │ ░░░░░░░░░░░░░░░░░                                 │ │
│  │                                                    │ │
│  │ Gen 1 (Mature):    Collect less often             │ │
│  │ ░░░░░░░░░░                                        │ │
│  │                                                    │ │
│  │ Gen 2 (Old):       Collect rarely (slow/thorough) │ │
│  │ ░░░░░░                                            │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│              CYCLE DETECTION & CLEANUP                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Circular Reference:                               │ │
│  │  obj_a → obj_b → obj_a (Cycle!)                   │ │
│  │  ref_count never reaches 0                         │ │
│  │  → GC detects and frees both                       │ │
│  └────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                     JVM MEMORY                          │
│  (Executors for Spark jobs, if applicable)             │
└─────────────────────────────────────────────────────────┘
```

**Reference Counting Example:**
```
a = [1, 2, 3]      → ref_count([1,2,3]) = 1
b = a              → ref_count([1,2,3]) = 2
del a              → ref_count([1,2,3]) = 1
del b              → ref_count([1,2,3]) = 0 → Memory FREE!

Circular Reference (No Fix):
node_a = Node()
node_b = Node()
node_a.next = node_b
node_b.next = node_a    → Each ref_count = 1 (won't free!)
del node_a              → ref_count = 1 (still allocated!)
del node_b              → ref_count = 1 (stuck in memory - LEAK!)

GC Cleanup (Fixes It):
gc.collect()            → Detects cycle → Frees both
```

**Purpose:**
- Reclaim memory from unused objects
- Prevent memory leaks
- Automatic memory management
- Free developers from manual memory deallocation

**Key Mechanisms:**

1. **Reference Counting:**
   - Every object has reference count
   - Increment on assignment
   - Decrement when reference removed
   - Delete when count reaches 0
   - Immediate cleanup

   **Advantages:**
   - Immediate memory reclamation
   - Low latency

   **Disadvantages:**
   - Circular references not detected
   - Memory overhead per object
   - Thread safety overhead

2. **Generational GC:**
   - Objects grouped by age
   - Young generation collected frequently
   - Old generation collected less often
   - Based on weak generational hypothesis

   **Generations:**
   - Gen 0: Newly created objects
   - Gen 1: Survived one collection
   - Gen 2: Long-lived objects

3. **Cycle Detection:**
   - Detects circular references
   - `gc` module handles cycles
   - Runs periodically
   - Can be tuned

4. **Mark and Sweep:**
   - Mark reachable objects
   - Sweep unreachable objects
   - Handles circular references

**Python GC Modules:**

```python
import gc

# Get collection stats
gc.get_count()  # Pending collections by generation

# Manual collection
gc.collect()  # Run garbage collection

# Disable automatic GC
gc.disable()
```

**Tuning GC:**

```python
import gc

# Set collection thresholds (objects before collection)
gc.set_threshold(700, 10, 10)
# Gen 0 threshold: 700 objects
# Gen 1 threshold: 10 collections
# Gen 2 threshold: 10 collections
```

**Best Practices:**

- Let Python handle GC automatically
- Understand reference cycles
- Use weakref for circular references
- Monitor GC impact with tools
- Tune if necessary

### Q181: How would you estimate a task that is not fully clear? How to avoid overtimes?

**Answer:**

**Estimating Unclear Tasks:**

1. **Clarify Requirements:**
   - Ask detailed questions
   - Break down unknowns
   - Research if needed
   - Create spike/PoC

2. **Spike Task:**
   - Time-boxed investigation
   - Research and explore
   - Create estimate based on findings
   - Typically 1-2 days

3. **Risk-Based Estimation:**
   - Estimate best case
   - Estimate worst case
   - Use three-point estimation
   - Add buffer

4. **Estimation Formula:**
   - Optimistic + 4*Most likely + Pessimistic / 6
   - Accounts for uncertainty

5. **Add Buffer:**
   - Add 20-30% for unknowns
   - Document assumptions
   - Build risk contingency

**Avoiding Overtimes:**

1. **Realistic Estimation:**
   - Don't underestimate
   - Include all work (testing, review)
   - Account for context switching
   - Factor in meetings

2. **Early Communication:**
   - Flag risks early
   - Communicate if at risk
   - Update estimates regularly
   - Don't wait until end

3. **Scope Management:**
   - Define done criteria
   - Manage scope creep
   - Say no to additions
   - Document scope

4. **Process Improvements:**
   - Track actual vs estimated
   - Analyze variances
   - Update estimation techniques
   - Learn from past projects

5. **Team Support:**
   - Pair programming for unknowns
   - Mentoring on complex tasks
   - Distribute work appropriately
   - Review capacity

6. **Work-Life Balance:**
   - Respect working hours
   - Don't glorify overtime
   - Manage team morale
   - Sustainable pace

### Q182: What is the project management methodology on your current project? Does it work for your team fully? If not, what would you change?

**Answer:**

**Project Management Methodologies:**

**Common Approaches:**

1. **Agile/Scrum:**
   - 2-week sprints
   - Daily standups
   - Sprint planning and retro
   - Iteration-based

2. **Kanban:**
   - Continuous flow
   - Work-in-progress limits
   - Pull system
   - Focus on cycle time

3. **Hybrid:**
   - Combine best practices
   - Structured planning + flexibility
   - Regular reviews

4. **Waterfall:**
   - Sequential phases
   - Detailed upfront planning
   - Less suitable for modern development

**Evaluation Criteria:**

- Team size and distribution
- Project complexity
- Change frequency
- Customer involvement
- Regulatory requirements

**Sample Assessment:**

"Our team uses Scrum, which works well for most of our work, but I'd suggest improvements:

1. **What Works:**
   - Clear sprint goals
   - Regular feedback loops
   - Team alignment

2. **What Needs Improvement:**
   - Too rigid for urgent items
   - Meetings could be shorter
   - Better capacity planning

3. **Suggested Changes:**
   - Add expedite lane for urgent items
   - Time-box meetings
   - Use velocity more actively
   - Better cross-team communication"

### Q183: What is the difference between Spark SQL and the Spark DataFrame API in terms of performance?

**Answer:**

**Spark SQL vs DataFrame API:**

| Aspect | Spark SQL | DataFrame API |
|--------|----------|---------------|
| **Interface** | SQL queries | API calls (Python/Scala) |
| **Optimizer** | Catalyst (full optimization) | Catalyst (full optimization) |
| **Performance** | Similar | Similar |
| **Flexibility** | SQL syntax | Programmatic |
| **Readability** | SQL familiar | Language familiar |
| **Join Optimization** | Excellent | Excellent |
| **Code Reuse** | SQL templates | Functions/libraries |

**Performance Comparison:**

**Key Point:**
- Both use Catalyst optimizer
- Both translate to same execution plan
- Performance is nearly identical

**Practical Example:**

```scala
// Spark SQL
spark.sql("""
  SELECT customer_id, SUM(amount) as total
  FROM orders
  WHERE date > '2024-01-01'
  GROUP BY customer_id
""")

// DataFrame API
orders
  .filter(col("date") > "2024-01-01")
  .groupBy("customer_id")
  .agg(sum("amount").as("total"))
  .select("customer_id", "total")

// BOTH produce identical execution plans and performance
```

**When to Use Each:**

**Use Spark SQL when:**
- Team knows SQL well
- Existing SQL queries to migrate
- Dynamic SQL generation needed
- BI tools integration

**Use DataFrame API when:**
- Complex programmatic logic
- Reusable functions needed
- Type safety (Scala/Java)
- Language consistency

**Hybrid Approach:**
- Use both where appropriate
- SQL for simple queries
- DataFrame for complex logic
- Combine for flexibility

### Q184: What is the role of the VACUUM command in Databricks?

**Answer:**

**VACUUM Command in Delta Lake:**

**Purpose:**
- Removes unused data files
- Reclaims storage space
- Cleans up old versions
- Maintains storage efficiency

**Basic Syntax:**

```sql
VACUUM table_name [RETAIN num_hours DAYS]
```

**Parameters:**
- RETAIN: Keep versions newer than specified duration
- Default: 7 days
- 0: Remove all historical versions

**Example:**

```sql
-- Remove files older than 30 days
VACUUM my_table RETAIN 30 DAYS

-- Remove all old versions
VACUUM my_table RETAIN 0 DAYS
```

**Key Considerations:**

1. **Time Travel Impact:**
   - Can't query deleted versions
   - Set retention appropriately

2. **Performance:**
   - Heavy I/O operation
   - Run during low usage
   - Can be parallelized

3. **Safety:**
   - Default 7-day retention safe
   - Test first
   - Monitor carefully

**Use Cases:**

1. **Cost Optimization:**
   - Large tables accumulate old versions
   - VACUUM reclaims space
   - Reduces cloud storage costs

2. **Storage Cleanup:**
   - Production tables
   - High write-volume tables
   - Long-running pipelines

3. **Compliance:**
   - Data retention policies
   - Remove old data as required

**Best Practices:**

- Schedule VACUUM during off-peak
- Monitor storage before/after
- Start with longer retention
- Automate with jobs

### Q185: What additional features - especially in the area of security - does Databricks offer compared to vanilla Apache Spark?

**Answer:**

**Databricks Security Features:**

1. **Access Control:**
   - Table-level access control
   - Row-level security (RLS)
   - Column-level security (CLS)
   - Fine-grained permissions

2. **Authentication:**
   - SSO/SAML integration
   - OAuth support
   - Service principals
   - API tokens with expiration

3. **Network Security:**
   - VPC support
   - Private endpoints
   - IP allowlisting
   - Network isolation

4. **Encryption:**
   - At-rest encryption
   - In-transit encryption (TLS)
   - BYOK (Bring Your Own Key)
   - Key management integration

5. **Audit and Compliance:**
   - Comprehensive audit logs
   - Query history
   - Access logs
   - Compliance reporting
   - SOC 2, PCI-DSS, HIPAA support

6. **Data Governance:**
   - Unity Catalog
   - Data discovery
   - Metadata management
   - Data lineage
   - PII detection

7. **Credential Management:**
   - Secrets management
   - Integration with key vaults
   - Secure credential storage
   - No hardcoded secrets

8. **Workspace Isolation:**
   - Multi-tenant isolation
   - Workspace-level access
   - Separate compute resources
   - Network isolation

9. **Advanced Features:**
   - IP access lists
   - MFA support
   - Privileged access management
   - Incident response tools

**Example Use Case:**

```python
# Secure credential access in Databricks
username = dbutils.secrets.get(scope="my-scope", key="username")
password = dbutils.secrets.get(scope="my-scope", key="password")

# Row-level security
# Only show data for user's region
SELECT * FROM sales WHERE region = current_user()
```

### Q186: Please name some of the Azure services you have worked with and categorize them under PaaS, SaaS, and IaaS models.

**Answer:**

**Azure Services Categorization:**

**Infrastructure as a Service (IaaS):**

1. **Virtual Machines (VMs):**
   - Compute on demand
   - Full OS control
   - Scaling options

2. **Azure Storage:**
   - Blob storage
   - File shares
   - Managed disks

3. **Virtual Networks:**
   - Network configuration
   - VPN connectivity
   - Network security groups

**Platform as a Service (PaaS):**

1. **App Service:**
   - Web app hosting
   - Auto-scaling
   - Built-in CI/CD

2. **Azure Functions:**
   - Serverless computing
   - Event-driven
   - Pay per execution

3. **Azure SQL Database:**
   - Managed relational database
   - Automatic backups
   - Built-in redundancy

4. **Azure Cosmos DB:**
   - NoSQL database
   - Global distribution
   - Multi-model support

5. **Azure Data Lake:**
   - Big data storage
   - Analytics capabilities
   - Hierarchical namespace

6. **Azure Synapse Analytics:**
   - Data warehouse
   - SQL and Spark analytics
   - Integrated analytics platform

7. **Azure Data Factory:**
   - Data pipeline orchestration
   - ETL/ELT
   - Visual workflow builder

**Software as a Service (SaaS):**

1. **Office 365:**
   - Email and productivity
   - Cloud collaboration
   - Mobile access

2. **Microsoft Teams:**
   - Communication platform
   - Video conferencing
   - Integration hub

3. **Power BI:**
   - Business analytics
   - Visualization
   - Self-service BI

**Comparison Table:**

| Model | Control | Flexibility | Management | Cost |
|-------|---------|------------|-----------|------|
| **IaaS** | High | High | Manual | Variable |
| **PaaS** | Medium | Medium | Reduced | Moderate |
| **SaaS** | Low | Low | Minimal | Fixed |

**Cost Considerations:**

- IaaS: Pay for compute/storage
- PaaS: Pricing varies by service
- SaaS: Subscription-based

### Q187: What is an integration runtime in Azure Data Factory, and what is a self-hosted integration runtime?

**Answer:**

**Integration Runtime (IR) in Azure Data Factory:**

**What is Integration Runtime:**
- Bridge between ADF and data sources
- Enables data movement and compute
- Hosts copy activities
- Runs transformations

**Types of Integration Runtime:**

1. **Azure Integration Runtime:**
   - Managed by Azure
   - Cloud-based
   - No maintenance
   - Limited to Azure resources
   - Default option

2. **Self-Hosted Integration Runtime:**
   - Installed on-premises
   - User managed
   - Can access on-premises resources
   - Hybrid connectivity
   - More control

3. **Azure-SSIS Integration Runtime:**
   - Specifically for SSIS packages
   - Lift-and-shift SSIS workloads
   - Enterprise edition available

**Self-Hosted IR Deep Dive:**

**Installation:**
- Install on-premises machine
- Register with ADF
- Configure ports and connectivity
- Enable access to local resources

**Architecture:**
```
On-Premises Data Sources
       ↓
Self-Hosted IR (Local Machine)
       ↓
Network/VPN
       ↓
Azure Data Factory (Cloud)
```

**Use Cases:**

1. **Access On-Premises Databases:**
   - SQL Server
   - Oracle
   - MySQL
   - Non-cloud databases

2. **File Shares:**
   - SMB shares
   - NFS
   - Local file systems

3. **Hybrid Scenarios:**
   - Cloud + On-premises data
   - Gradual migration
   - Mixed environments

4. **Security:**
   - Keep data on-premises
   - Avoid internet transfer
   - Secure internal networks

**Advantages:**
- Access to on-premises resources
- Hybrid cloud scenarios
- Data security
- Network isolation

**Disadvantages:**
- Requires maintenance
- Single point of failure risk
- Additional infrastructure cost
- Monitoring overhead

**Monitoring:**

```
ADF → Monitor Integration Runtime
     → Check connectivity
     → Monitor performance
     → View error logs
```

### Q188: What is the difference between code quality and data quality? How can we achieve good data quality in ETL pipelines?

**Answer:**

**Code Quality vs Data Quality:**

| Aspect | Code Quality | Data Quality |
|--------|-------------|--------------|
| **Focus** | Code correctness | Data correctness |
| **Tools** | Linters, SonarQube | Data profiling tools |
| **Metrics** | Complexity, coverage | Accuracy, completeness |
| **Testing** | Unit, integration tests | Data validation tests |
| **Maintenance** | Code reviews, refactoring | Data governance |

**Code Quality:**
- Does the program work?
- Is it readable and maintainable?
- Are there bugs?
- Performance efficiency

**Data Quality:**
- Is the data accurate?
- Is it complete?
- Is it consistent?
- Is it timely?

**Achieving Data Quality in ETL Pipelines:**

1. **Validation Rules:**
   ```python
   # Schema validation
   expected_schema = StructType([
       StructField("id", IntegerType()),
       StructField("name", StringType()),
   ])
   
   # Check schema matches
   assert df.schema == expected_schema
   ```

2. **Data Profiling:**
   - Analyze data distribution
   - Check null counts
   - Verify ranges
   - Identify patterns

3. **Quality Checks:**
   ```python
   # Completeness: No nulls
   df.where(col("id").isNull()).count() == 0
   
   # Uniqueness: No duplicates
   df.dropDuplicates().count() == df.count()
   
   # Accuracy: Values in range
   df.where((col("age") >= 0) & (col("age") <= 150)).count() == df.count()
   ```

4. **Great Expectations:**
   ```python
   from great_expectations.dataset import PandasDataset
   
   df_ge = PandasDataset(df)
   df_ge.expect_column_values_to_not_be_null("id")
   df_ge.expect_column_values_to_be_between("age", 0, 150)
   ```

5. **dbt Tests:**
   ```yaml
   - name: customers
     columns:
       - name: customer_id
         tests:
           - unique
           - not_null
   ```

6. **Quarantine and Alert:**
   - Route bad data to quarantine
   - Send alerts to team
   - Log failures
   - Create SLOs

7. **Documentation:**
   - Data dictionary
   - Quality rules
   - Ownership
   - SLAs

### Q189: Could you please compare Scrum and Kanban development processes in terms of planning?

**Answer:**

**Scrum vs Kanban Workflow Visualization:**

```
SCRUM (Time-Boxed Sprints):         KANBAN (Continuous Flow):

Sprint 1          Sprint 2          Week 1        Week 2
┌──────────┐     ┌──────────┐      ┌────────┐   ┌────────┐
│  2 Weeks │     │  2 Weeks │      │Flexible│   │Flexible│
└──────────┘     └──────────┘      └────────┘   └────────┘
   ↓                ↓                   ↓            ↓
Planning          Planning          Backlog    Backlog
   │                ├─ WIP Limit: 3
   ├─ Select        │
   ├─ Estimate      ├─ To Do
   └─ Commit        │  Task A
                    │  Task B
   Execution        │  Task C
   ├─ Daily         │
   ├─ Standup       ├─ In Progress  ├─ In Progress
   └─ Work          │  Task A       │  Task D
                    │               │
   Review          ├─ Done         ├─ Done
   ├─ Show Demo     │  Task X       │  Task B
   └─ Metrics      │  Task Y       │  Task E
                    │
   Retro            └─ Continuous Flow (24/7)
   └─ Improve

Predictability High        Predictability Low
Flexibility Low             Flexibility High
Change Impact: High         Change Impact: Low
Cycle Time: Known           Cycle Time: Variable
```

**Scrum vs Kanban:**

| Aspect | Scrum | Kanban |
|--------|-------|--------|
| **Planning** | Sprint-based | Continuous |
| **Iteration** | Fixed 1-4 weeks | Continuous flow |
| **Meetings** | Ceremonies | As-needed |
| **Roles** | Defined roles | Shared responsibility |
| **Metrics** | Velocity | Cycle time |
| **Flexibility** | Mid-sprint changes difficult | Highly flexible |

**Planning Comparison:**
```
┌──────────────────────────────────────────────────────────┐
│           SCRUM PLANNING CYCLE (2 weeks)                 │
├──────────────────────────────────────────────────────────┤
│  Day 1: Sprint Planning (4h)                             │
│  ├─ Define goal & scope                                  │
│  ├─ Select backlog items                                 │
│  ├─ Estimate with story points                           │
│  └─ Commit to sprint                                     │
│                                                          │
│  Days 2-9: Daily Standup (15 min) + Work                 │
│  ├─ What did you do?                                     │
│  ├─ What will you do?                                    │
│  └─ What blockers?                                       │
│                                                          │
│  Day 10: Sprint Review (2h) + Retro (1.5h)              │
│  ├─ Demo completed work                                  │
│  ├─ Review metrics                                       │
│  └─ Improve processes                                    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│        KANBAN PLANNING (Continuous)                      │
├──────────────────────────────────────────────────────────┤
│  Monday 9am: Prioritize backlog                          │
│  ├─ Check queue                                          │
│  ├─ Reorder priorities                                   │
│  └─ Pull new work (WIP limit: 3)                         │
│                                                          │
│  Daily: Pull when ready                                  │
│  ├─ Task completed → Pull from backlog                  │
│  ├─ Keep WIP limits                                      │
│  └─ Block collaboration                                  │
│                                                          │
│  Weekly: Metrics review                                  │
│  ├─ Cycle time trend                                     │
│  ├─ Throughput                                           │
│  └─ Lead time                                            │
└──────────────────────────────────────────────────────────┘
```

**Scrum Planning:**

1. **Sprint Planning:**
   - Select items for sprint
   - Estimate effort
   - Define definition of done
   - Commit to sprint goal

2. **Sprint Duration:**
   - Fixed 1-4 weeks
   - Team commits to sprint
   - No mid-sprint changes
   - Regular cadence

3. **Ceremonies:**
   - Sprint planning (4 hours for 2-week sprint)
   - Daily standup (15 min)
   - Sprint review (2 hours)
   - Sprint retrospective (1.5 hours)

4. **Forecasting:**
   - Based on velocity
   - Historical data
   - Predictable delivery

**Kanban Planning:**

1. **No Fixed Sprint:**
   - Continuous flow
   - Work in progress limits
   - Pull-based system
   - No planning ceremonies

2. **Flexibility:**
   - Add items anytime
   - Prioritize continuously
   - Respond to urgent requests
   - No sprint commitment

3. **Metrics:**
   - Cycle time (start to finish)
   - Throughput
   - Lead time
   - Work in progress

4. **Process:**
   - Backlog → To Do → In Progress → Done
   - Limit WIP at each stage
   - Pull when ready
   - Continuous improvement

**Is Kanban Planning-Free?**

**No**, Kanban still requires planning:
- Define workflow stages
- Set WIP limits
- Prioritize backlog
- Plan capacity
- Regular reviews

Kanban is continuous planning, not no planning.

**When to Use:**

**Scrum:**
- Need predictability
- Fixed delivery dates
- Large features
- Team needs structure
- Formal governance

**Kanban:**
- Support/maintenance work
- Urgent items expected
- Continuous delivery
- Small changes
- Team self-organized

**Hybrid (Scrumban):**
- Best of both
- Kanban on backlog management
- Sprints for planning cadence
- Flexibility + predictability

### Q190: Tell us about the Data Lakes you have built in your projects. Did you use the Medallion Architecture?

**Answer:**

**Data Lake Architecture:**

**Medallion Architecture (Layered Approach):**

```
┌──────────────────────────────────────────────────────────────────────┐
│                     ANALYTICS & BI LAYER                             │
│   (Dashboards, Reports, Machine Learning, Recommendations)           │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
            ┌────────────────▼──────────────────┐
            │   🏆 GOLD LAYER 🏆                │
            │  (Analytics Ready Data)           │
            │  ✓ Aggregations & KPIs            │
            │  ✓ Business Metrics               │
            │  ✓ Optimized for BI               │
            │  ✓ Access Control (Fine-grained) │
            │  Format: Delta Lake / Parquet     │
            └────────────────┬───────────────────┘
                             │
            ┌────────────────▼──────────────────┐
            │  🥈 SILVER LAYER 🥈               │
            │  (Cleaned & Transformed Data)     │
            │  ✓ Deduplication                  │
            │  ✓ Schema Enforcement             │
            │  ✓ Data Quality Checks            │
            │  ✓ SCD Type 2 Implementation      │
            │  Format: Delta Lake / Parquet     │
            └────────────────┬───────────────────┘
                             │
            ┌────────────────▼──────────────────┐
            │  🥉 BRONZE LAYER 🥉               │
            │  (Raw Ingestion)                  │
            │  ✓ Immutable & Append-only        │
            │  ✓ Minimal Transformation         │
            │  ✓ Complete History               │
            │  ✓ Schema-on-read                 │
            │  Format: Parquet / CSV / JSON     │
            └────────────────┬───────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
    ┌────────────┐   ┌────────────┐   ┌────────────┐
    │  Databases │   │   APIs     │   │   Files    │
    │  (OLTP/DW) │   │(REST/SOAP) │   │  (CSV/XML) │
    └────────────┘   └────────────┘   └────────────┘
    │                    │                    │
    └────────────────────┼────────────────────┘
                         │
                    Data Sources
```

**Three Layers:**

1. **Bronze (Raw):**
   - Raw data ingestion
   - Minimal transformation
   - Schema-on-read
   - Immutable copies
   - Example: Log files, API responses

2. **Silver (Cleaned):**
   - Data cleaning
   - Deduplication
   - Schema enforcement
   - Joined data
   - Example: Normalized customer data

3. **Gold (Analytics):**
   - Business-ready data
   - Aggregations and KPIs
   - Optimized for analytics
   - Fine-grained access control
   - Example: Dashboards, reports

**Advantages:**

1. **Separation of Concerns:**
   - Each layer has clear purpose
   - Easy to understand
   - Scalable approach

2. **Data Governance:**
   - Control at each layer
   - Quality enforcement
   - Audit trail

3. **Reusability:**
   - Silver data reused by multiple gold
   - Bronze trusted source
   - Single source of truth

4. **Scalability:**
   - Can be implemented with different tools
   - Easy to expand
   - Modular approach

5. **Debugging:**
   - Easy to isolate issues
   - Each layer testable
   - Clear lineage

**Disadvantages:**

1. **Complexity:**
   - More layers to manage
   - More storage (copies)
   - More processing

2. **Storage Cost:**
   - Data duplication
   - Multiple transformations
   - Large data sets replicated

3. **Latency:**
   - Multi-layer processing
   - Time to reach gold layer
   - Not ideal for real-time

4. **Maintenance:**
   - Multiple layer contracts
   - Version management
   - Pipeline coordination

**Alternatives:**

1. **Lakehouse (Delta Lake):**
   - Single layer with versioning
   - ACID transactions
   - No duplication needed

2. **Data Mesh:**
   - Domain-oriented architecture
   - Decentralized ownership
   - Domain-specific lakes

3. **Simple Raw/Curated:**
   - Just two layers
   - Simpler approach
   - Less overhead

**Example Implementation:**

```python
# Bronze: Raw ingestion
bronze_df = spark.read.json("/raw/orders/")
bronze_df.write.mode("append").parquet("/bronze/orders/")

# Silver: Cleaned and joined
silver_df = bronze_df \
  .drop_duplicates() \
  .where(col("amount") > 0)
  
silver_df.write.mode("overwrite").parquet("/silver/orders/")

# Gold: Analytics ready
gold_df = silver_df \
  .groupBy("customer_id") \
  .agg(sum("amount").as("total_spent")) \

gold_df.write.mode("overwrite").parquet("/gold/customer_analytics/")
```

**Best Practices:**

- Use Delta Lake format for transactions
- Implement data quality checks at each layer
- Document data contracts
- Use medallion with Spark for scalability
- Monitor layer SLOs
- Implement cost monitoring

### Q191: Have you worked with Spark on AWS Cloud? Please compare different methods of launching Spark jobs in AWS.

**Answer:**

**Running Spark on AWS:**

**1. Amazon EMR (Elastic MapReduce):**

**Pros:**
- Fully managed Hadoop/Spark cluster
- Auto-scaling
- Easy cluster creation
- Spot instance support
- Integration with S3, RDS

**Cons:**
- Manual cluster management needed
- Cluster lifecycle management
- Cost if not optimized
- Scaling can take time

**Example:**
```bash
aws emr create-cluster \
  --name my-spark-cluster \
  --release-label emr-6.x.0 \
  --applications Name=Spark \
  --instance-count 3 \
  --instance-type m5.xlarge
```

**2. AWS Glue:**

**Pros:**
- Serverless Spark
- Pay per minute
- Good for small-medium jobs
- Automatic scaling
- Python/Scala support

**Cons:**
- Limited customization
- Higher cost for large jobs
- Limited ecosystem
- Cold start delay

**Example:**
```python
import sys
from awsglue.transforms import *
from awsglue.context import GlueContext

glueContext = GlueContext(SparkContext.getOrCreate())
dyf = glueContext.create_dynamic_frame_from_options(
  "s3", 
  {"paths": ["s3://my-bucket/data/"]}
)
```

**3. Databricks on AWS:**

**Pros:**
- Fully managed Spark
- Optimized for Delta Lake
- Enterprise features
- SQL endpoint
- Advanced monitoring

**Cons:**
- Higher cost
- Requires Databricks account
- Vendor lock-in
- Overkill for simple jobs

**Example:**
```python
# Run job in Databricks
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.jobs import SubmitRun

client = WorkspaceClient()
client.jobs.submit(SubmitRun(
  new_cluster=...,
  spark_python_task=...
))
```

**4. EC2 Self-Managed:**

**Pros:**
- Full control
- Cost optimization possible
- Custom configurations
- No abstraction layers

**Cons:**
- Manual scaling
- Operational overhead
- Complex setup
- Team maintenance needed

**5. AWS Lambda + Spark (Limited):**

**Pros:**
- Serverless
- Event-driven
- Auto-scaling
- No management

**Cons:**
- Limited Spark support
- Not ideal for big Spark jobs
- Memory and time limits
- Primarily for triggering, not processing

**Comparison Table:**

| Feature | EMR | Glue | Databricks | EC2 | Lambda |
|---------|-----|------|-----------|-----|--------|
| **Management** | Managed | Serverless | Managed | Manual | Serverless |
| **Cost** | Variable | Per minute | Per DBU | Variable | Per invocation |
| **Complexity** | Medium | Low | Low | High | Low |
| **Scalability** | High | Auto | Auto | Manual | Limited |
| **Customization** | High | Low | Medium | High | Very Low |

**Selection Criteria:**

- **Small ad-hoc jobs** → Glue
- **Production pipelines** → Databricks
- **Complex requirements** → EMR
- **Simple/quick** → Glue or Lambda

### Q192: What formats of semi-structured data are supported by Databricks?

**Answer:**

**Semi-Structured Data Formats:**

1. **JSON:**
   ```python
   df = spark.read.json("path/to/file.json")
   ```
   - Flexible schema
   - Nested structures
   - Arrays and objects
   - Self-documenting

2. **Parquet:**
   ```python
   df = spark.read.parquet("path/to/file.parquet")
   ```
   - Columnar format
   - Compression
   - Schema preservation
   - Widely supported

3. **ORC:**
   ```python
   df = spark.read.orc("path/to/file.orc")
   ```
   - Optimized Row Columnar
   - Better compression
   - ACID support
   - Hive integration

4. **Avro:**
   ```python
   df = spark.read.format("avro").load("path/")
   ```
   - Schema evolution
   - Compact binary format
   - Kafka integration
   - Language agnostic

5. **Delta Format:**
   ```python
   df = spark.read.delta("path/to/delta/")
   ```
   - Parquet + transaction log
   - ACID transactions
   - Time travel
   - Schema enforcement

6. **CSV:**
   ```python
   df = spark.read.csv("path/to/file.csv", header=True)
   ```
   - Row-oriented
   - Human readable
   - Schema inference needed
   - Less efficient

7. **XML:**
   ```python
   df = spark.read.format("xml").load("path/")
   ```
   - Hierarchical data
   - Nested elements
   - Less common in data lakes

8. **Image Files:**
   ```python
   images_df = spark.read.format("image").load("path/")
   ```
   - ML pipelines
   - Binary format
   - Metadata extraction

**Databricks-Specific Support:**

- Native support for Delta
- Auto-loader for ingestion
- Schema inference
- Format optimization recommendations

**Format Selection:**

**Use Parquet/ORC when:**
- Columnar processing
- Compression important
- Storage optimization
- Analytics queries

**Use JSON when:**
- Semi-structured data
- Schema flexibility
- Nested objects
- API responses

**Use Avro when:**
- Kafka integration
- Schema evolution needed
- Language independence
- Message queues

**Best Practices:**

- Store as Parquet/Delta for efficiency
- Use Avro for message streams
- Convert JSON to columnar format
- Profile data characteristics first

### Q193: What Delta Lake features do you use on the project?

**Answer:**

**Delta Lake Features:**

1. **ACID Transactions:**
   ```python
   # All-or-nothing writes
   df.write.mode("append").option("mergeSchema", "true").delta("/path/")
   ```

2. **Time Travel:**
   ```python
   # Query historical versions
   spark.read.delta("/path/").option("versionAsOf", 5).load()
   spark.read.delta("/path/").option("timestampAsOf", "2024-01-15").load()
   ```

3. **Schema Evolution:**
   ```python
   df_new.write.mode("append") \
     .option("mergeSchema", "true") \
     .delta("/path/")
   ```

4. **Data Validation:**
   ```python
   spark.sql("""
     CREATE TABLE events
     (event_id INT NOT NULL,
      event_date DATE)
     USING DELTA
     CHECK (event_id > 0)
   """)
   ```

5. **MERGE for SCD:**
   ```python
   target.merge(source, "target.id = source.id") \
     .whenMatched().updateAll() \
     .whenNotMatched().insertAll() \
     .execute()
   ```

6. **DELETE/UPDATE:**
   ```python
   # Delete rows
   delta_table.delete("quantity <= 0")
   
   # Update rows
   delta_table.update(
     set={"price": col("price") * 1.1},
     condition="category = 'premium'"
   )
   ```

7. **Optimizations:**
   ```python
   # Compact files
   spark.sql("OPTIMIZE table_name ZORDER BY (customer_id)")
   
   # Remove old versions
   spark.sql("VACUUM table_name RETAIN 30 DAYS")
   ```

8. **Data Quality:**
   ```python
   # Constraints
   spark.sql("""
     ALTER TABLE orders ADD CONSTRAINT valid_amount CHECK (amount > 0)
   """)
   ```

**Project Usage:**

"On my project, we heavily use:
- MERGE for daily SCD Type 2 updates
- Time travel for audits and rollbacks
- Schema evolution for flexible ingestion
- Optimization for cost reduction
- DELETE for compliance (GDPR)
- Constraints for data quality"

### Q194: What is exception handling in Python and how do you create custom exceptions?

**Answer:**

**Exception Handling in Python:**

1. **Try-Except Block:**
   ```python
   try:
       result = 10 / 0
   except ZeroDivisionError:
       print("Cannot divide by zero")
   except Exception as e:
       print(f"Error: {e}")
   ```

2. **Try-Except-Else:**
   ```python
   try:
       file = open("data.txt")
   except FileNotFoundError:
       print("File not found")
   else:
       print("File opened successfully")
   ```

3. **Try-Finally:**
   ```python
   try:
       file = open("data.txt")
       data = file.read()
   finally:
       file.close()  # Always executes
   ```

4. **Try-Except-Else-Finally:**
   ```python
   try:
       result = 10 / 5
   except ZeroDivisionError:
       print("Error")
   else:
       print(f"Result: {result}")
   finally:
       print("Done")
   ```

**Built-in Exceptions:**

```python
ValueError      # Wrong value type
TypeError       # Wrong argument type
KeyError        # Dictionary key not found
IndexError      # List index out of range
FileNotFoundError # File doesn't exist
ZeroDivisionError # Division by zero
AttributeError  # Attribute doesn't exist
NameError       # Variable not defined
```

**Creating Custom Exceptions:**

1. **Simple Custom Exception:**
   ```python
   class ValidationError(Exception):
       pass
   
   try:
       if age < 0:
           raise ValidationError("Age cannot be negative")
   except ValidationError as e:
       print(f"Validation error: {e}")
   ```

2. **Custom Exception with Message:**
   ```python
   class InsufficientFundsError(Exception):
       def __init__(self, balance, amount):
           self.balance = balance
           self.amount = amount
           super().__init__(f"Insufficient funds: {balance} < {amount}")
   
   try:
       if balance < amount:
           raise InsufficientFundsError(balance, amount)
   except InsufficientFundsError as e:
       print(e)
   ```

3. **Custom Exception with Multiple Arguments:**
   ```python
   class DataProcessingError(Exception):
       def __init__(self, message, error_code, details=None):
           self.message = message
           self.error_code = error_code
           self.details = details
           super().__init__(self.message)
   
   raise DataProcessingError("Processing failed", 500, {"file": "data.csv"})
   ```

4. **Exception Hierarchy:**
   ```python
   class DataError(Exception):
       """Base exception for data errors"""
       pass
   
   class ValidationError(DataError):
       """Raised when validation fails"""
       pass
   
   class TransformationError(DataError):
       """Raised during transformation"""
       pass
   
   try:
       # some operation
       pass
   except ValidationError:
       print("Validation failed")
   except TransformationError:
       print("Transformation failed")
   except DataError:
       print("Other data error")
   ```

**Best Practices:**

- Create specific exceptions for different errors
- Inherit from appropriate base exceptions
- Include meaningful error messages
- Use exception hierarchy
- Don't catch generic Exception unless necessary
- Log exceptions appropriately

### Q195: Can you explain the difference between code quality and data quality? Also, what metrics or parameters would you use to measure each in your project?

**Answer:**

**Code Quality vs Data Quality (Deep Dive):**

**Comparison Matrix:**
```
┌──────────────────────────┬─────────────────────┬─────────────────────┐
│       Aspect             │   CODE QUALITY      │   DATA QUALITY      │
├──────────────────────────┼─────────────────────┼─────────────────────┤
│ Focus                    │ HOW is it built?    │ IS it correct?      │
│ Measurement              │ Static analysis     │ Runtime validation  │
│ Tools                    │ SonarQube, PyLint   │ Great Expectations  │
│ Timing                   │ Before deploy       │ After ingestion     │
│ Impact                   │ Maintainability     │ Business decisions  │
│ Owner                    │ Developers          │ Data engineers      │
│ Fix Cost                 │ Medium              │ High                │
├──────────────────────────┼─────────────────────┼─────────────────────┤
│ Examples                 │                     │                     │
│ • Readable code          │ ✓ Code Quality      │                     │
│ • Proper error handling  │ ✓ Code Quality      │                     │
│ • No null values         │                     │ ✓ Data Quality      │
│ • Accurate calculations  │                     │ ✓ Data Quality      │
│ • Efficient algorithms   │ ✓ Code Quality      │                     │
│ • No duplicates          │                     │ ✓ Data Quality      │
└──────────────────────────┴─────────────────────┴─────────────────────┘

CODE QUALITY DIMENSIONS:              DATA QUALITY DIMENSIONS:
┌─────────────────────┐              ┌─────────────────────┐
│ Readability         │              │ Completeness        │
│ Maintainability     │              │ Accuracy            │
│ Testability         │              │ Consistency         │
│ Efficiency          │              │ Timeliness          │
│ Security            │              │ Uniqueness (No Dups)│
│ Documentation       │              │ Validity            │
│ Complexity          │              │ Conformity          │
└─────────────────────┘              └─────────────────────┘
```

**Code Quality:**
- Does the software work correctly?
- Is it maintainable?
- How efficient is it?
- Can others understand it?

**Key Metrics:**
- Code coverage (80%+)
- Cyclomatic complexity (<10)
- Lines of code
- Technical debt ratio
- Bug density (bugs per 1000 LOC)
- Test pass rate (100%)
- Code duplication (<5%)

**Data Quality:**
- Is the data accurate?
- Is it complete?
- Is it consistent?
- Is it timely?

**Key Metrics:**
- Null/missing count
- Duplicate count
- Unique value count
- Data freshness (days old)
- Completeness % (1-(null count/total count))
- Duplicate % (duplicate rows/total rows)
- Invalid format count
- Schema compliance %

**Measurement Tools:**

| Aspect | Tool | Metric |
|--------|------|--------|
| Code | SonarQube | Coverage, complexity |
| Code | PyLint | Code style, errors |
| Code | CodeClimate | Maintainability |
| Data | Great Expectations | Quality checks |
| Data | Soda | Profiling, monitoring |
| Data | dbt | Test coverage |

**Project Implementation Targets:**

```
CODE QUALITY BASELINE:              DATA QUALITY BASELINE:
├─ 80%+ code coverage              ├─ 99%+ completeness
├─ Cyclomatic complexity < 10      ├─ <0.1% duplicates
├─ 0 critical bugs                 ├─ 100% schema compliance
├─ <5% code duplication            ├─ Data freshness < 24h
├─ 100% test pass rate             ├─ <1% invalid values
├─ Code review approval            ├─ Zero PII leaks
└─ Security scan passing           └─ Audit trail complete
```

**Quality Dashboard Example:**
```
CODE QUALITY SCORE: 8.5/10          DATA QUALITY SCORE: 9.2/10
┌─────────────────────────┐        ┌─────────────────────────┐
│ Coverage: 85% ████████░ │        │ Completeness: 99.5%████ │
│ Complexity: 8/10 ███░░░ │        │ Duplicates: 0.08%███░░░ │
│ Bugs/1KLOC: 0.2 ███░░░░ │        │ Freshness: 2h ████░░░░░ │
│ Duplication: 3% ███░░░░ │        │ Invalid: 0.8% █████░░░░ │
│ Tests Pass: 100%████████│        │ Schema OK: 100%████████ │
└─────────────────────────┘        └─────────────────────────┘
```

**Measurement Tools:**

| Aspect | Tool | Metric |
|--------|------|--------|
| Code | SonarQube | Coverage, complexity |
| Code | PyLint | Code style, errors |
| Code | CodeClimate | Maintainability |
| Data | Great Expectations | Quality checks |
| Data | Soda | Profiling, monitoring |
| Data | dbt | Test coverage |

**Project Implementation:**

```python
# Code Quality
- Maintain 80%+ code coverage
- Cyclomatic complexity < 10
- 0 critical bugs
- Code review approval before merge

# Data Quality
- 99%+ completeness
- <0.1% duplicates
- 100% schema compliance
- Data freshness < 24 hours
- <1% invalid values
```

### Q196: During testing, your QA team discovers a critical bug just days before the scheduled release. How would you manage this situation while ensuring minimal disruption?

**Answer:**

**Handling Critical Bugs Before Release:**

1. **Assess Impact:**
   - How critical is the bug?
   - How many users affected?
   - What's the business impact?
   - Reproducible reliably?

2. **Triage Decision:**
   - Fix and delay release (if fixable)
   - Release with workaround (if minor impact)
   - Hotfix after release (if low impact)
   - Delay release (if critical)

3. **If Decision: Fix and Release Delay:**
   - Root cause analysis
   - Minimal fix
   - Immediate review
   - Accelerated testing
   - Monitor

4. **If Decision: Release with Workaround:**
   - Document workaround
   - Communicate to users
   - Create hotfix backlog
   - Monitor closely
   - Fix in next release

5. **Risk Management:**
   - Run regression tests
   - Smoke test critical paths
   - Canary deployment (if possible)
   - Rollback plan ready
   - On-call team prepared

6. **Communication:**
   - Inform stakeholders immediately
   - Discuss options
   - Set expectations
   - Daily updates
   - Transparent about risks

7. **Prevention:**
   - More thorough testing earlier
   - Automated test coverage
   - Staging environment like production
   - Load testing
   - Integration testing

8. **Post-Release:**
   - Monitor closely first 48 hours
   - Have quick fix ready
   - Document lessons learned
   - Improve testing process

### Q197: What is the difference between a User Defined Function (UDF) and a User Defined Table Function (UDTF) in Spark?

**Answer:**

**UDF vs UDTF:**

| Aspect | UDF | UDTF |
|--------|-----|------|
| **Return Type** | Single value per row | Table (multiple rows) |
| **Output** | 1 value per input row | 0 or more rows per input |
| **Use Case** | Transformation | Explosion/flattening |
| **Performance** | Good | Better than UDF |
| **Syntax** | @udf decorator | @udtf decorator |

**User Defined Function (UDF):**

Returns a single value per input row

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import DoubleType

# Python UDF
@udf(returnType=DoubleType())
def fahrenheit_to_celsius(temp):
    return (temp - 32) * 5/9

# Use it
df = spark.createDataFrame([(32,), (86,)], ["fahrenheit"])
result = df.withColumn("celsius", fahrenheit_to_celsius(col("fahrenheit")))
# Output: one celsius value per row
```

**User Defined Table Function (UDTF):**

Returns a table (multiple rows/columns) per input row

```python
from pyspark.sql.functions import udtf
from pyspark.sql.types import StructType, StructField, StringType

# Python UDTF
@udtf(returnType="col1 string, col2 string")
def explode_name(name):
    for char in name:
        yield char, char.upper()

# Use it
df = spark.createDataFrame([("abc",)], ["name"])
result = df.select(explode_name(col("name")))
# Output: multiple rows per input (a,A), (b,B), (c,C)
```

**Performance Considerations:**

- UDFs: Serialization overhead
- Catalyst can't optimize UDFs
- Use vectorized UDFs when possible

```python
# Vectorized UDF (better performance)
import pandas as pd
from pyspark.sql.functions import pandas_udf

@pandas_udf("double")
def vectorized_celsius(batch_iter):
    for s in batch_iter:
        yield (s - 32) * 5/9

df.withColumn("celsius", vectorized_celsius(col("fahrenheit")))
```

**When to Use:**

**UDF:**
- Simple scalar transformations
- Business logic transformations

**UDTF:**
- Explode/flatten data
- Generate multiple rows
- Map one row to many

**Best Practices:**

- Prefer SQL functions if possible
- Use vectorized UDFs for performance
- Use UDTF for row explosion
- Minimize UDF usage
- Profile performance

### Q198: What does Senior role mean to you? What senior activities do you already do in your day-to-day job?

**Answer:**

**Senior Role Definition:**

A senior role means:
- Technical depth and breadth
- Ownership of complex problems
- Mentoring and leadership
- Influencing without authority
- Strategic thinking
- Accountability for outcomes

**Senior Activities I Currently Perform:**

1. **Technical Leadership:**
   - Design solutions for complex problems
   - Make architectural decisions
   - Review code and provide feedback
   - Establish technical standards
   - Define best practices

2. **Mentoring:**
   - Guide junior developers
   - Code reviews with teaching
   - Pair programming
   - Skill development plans
   - Career guidance

3. **Problem Solving:**
   - Troubleshoot production issues
   - Root cause analysis
   - Performance optimization
   - System design reviews
   - Technology evaluation

4. **Communication:**
   - Present to leadership
   - Explain technical concepts
   - Document architecture decisions
   - Communicate risks and trade-offs
   - Cross-team coordination

5. **Process Improvement:**
   - Identify bottlenecks
   - Suggest improvements
   - Implement best practices
   - Automate repetitive tasks
   - Optimize workflows

6. **Stakeholder Management:**
   - Manage expectations
   - Negotiate requirements
   - Balance quality and speed
   - Handle conflicts
   - Build trust

7. **Planning:**
   - Long-term strategy
   - Tech debt management
   - Resource planning
   - Risk mitigation
   - Roadmap definition

**Example:**

"Last quarter, I:
- Redesigned our data pipeline architecture (technical leadership)
- Mentored 2 junior engineers on data quality (mentoring)
- Led post-mortem on production outage (problem-solving)
- Presented to C-level on data strategy (communication)
- Implemented automated testing framework (process improvement)"

### Q199: How does data skew impact Spark job performance? What techniques have you used to detect and mitigate skew?

**Answer:**

**Data Skew Impact:**

**Problems:**
- Some partitions have much more data
- Executor handling large partition slow
- Other executors finish early (idle)
- GC issues from large partitions
- Memory pressure on specific executors
- Overall job slow as fastest task + slowest task

**Performance Impact:**

```
Without Skew:         With Skew:
Executor 1: ████      Executor 1: ████████████████ (slow)
Executor 2: ████      Executor 2: █
Executor 3: ████      Executor 3: █
All done quickly      Waits for executor 1
```

**Detection Techniques:**

1. **Check Partition Sizes:**
   ```python
   df.rdd.mapPartitions(lambda x: [sum(1 for _ in x)]).collect()
   # Output: [1000000, 50, 100]  <- Skew detected
   ```

2. **Analyze Data Distribution:**
   ```python
   df.groupBy("join_key").count().describe().show()
   # Look for high max/avg ratio
   ```

3. **Monitor Executor Metrics:**
   - Spark UI
   - Task duration histogram
   - Look for outliers

4. **Profile Data:**
   ```python
   df.groupBy("join_key").count() \
     .orderBy(desc("count")) \
     .limit(10).show()
   # Top 10 keys taking most resources
   ```

**Mitigation Techniques:**

1. **Salting (Add Artificial Key):**
   ```python
   # Before: join on customer_id (skewed)
   # After: add salt
   
   df_salted = df.withColumn(
       "salted_id", 
       concat(col("customer_id"), 
              lit("_"), 
              (rand() * 10).cast("int"))
   )
   
   # Now distributed across 10 buckets
   result = df_salted.join(other, "salted_id", "left")
   ```

2. **Bucketing:**
   ```python
   df.write \
     .bucketBy(256, "customer_id") \
     .mode("overwrite") \
     .saveAsTable("customers_bucketed")
   ```

3. **Pre-aggregation:**
   ```python
   # Instead of joining on raw data
   # Pre-aggregate large table first
   
   agg_data = large_table \
     .groupBy("customer_id") \
     .agg(sum("amount"))
   
   result = small_table.join(agg_data, "customer_id")
   ```

4. **Use Broadcast Join:**
   ```python
   from pyspark.sql.functions import broadcast
   
   result = large_df.join(
       broadcast(small_df), 
       "join_key", 
       "left"
   )
   # Broadcast avoids skew
   ```

5. **Adaptive Query Execution (AQE):**
   ```python
   # Enable AQE (Spark 3.0+)
   spark.conf.set("spark.sql.adaptive.enabled", "true")
   
   # Automatically:
   # - Switches join strategies
   # - Coalesces partitions
   # - Handles skew
   ```

6. **Repartition Strategically:**
   ```python
   df.repartition("customer_id") \
     .write.parquet("output/")
   # Creates more balanced partitions
   ```

**Best Practices:**

- Monitor data distribution early
- Use AQE when possible
- Salt high-cardinality keys
- Broadcast small tables
- Test with production data volume
- Document known skew situations

### Q200: What is Z-ordering in Delta Lake and when would you use it? How is it different from partitioning?

**Answer:**

**Z-Ordering in Delta Lake:**

**What is Z-Ordering:**
- Colocates related data within files
- Uses Z-order curve algorithm
- Improves query performance for filtered operations
- Works in multi-dimensional space

**Z-Order Curve:**
```
A spatial technique that maps multi-dimensional data to 1D
while preserving locality

Example: Customer data with age and income
Age/Income combinations close in Z-curve → same files
```

**Syntax:**

```sql
OPTIMIZE table_name ZORDER BY (column1, column2)
```

**Example:**

```python
df.write.mode("overwrite").option(
    "dataChange", "false"
).format("delta").save("path/")

spark.sql("""
    OPTIMIZE my_table 
    ZORDER BY (customer_id, purchase_date)
""")
```

**Z-Ordering vs Partitioning:**

| Aspect | Z-Ordering | Partitioning |
|--------|-----------|--------------|
| **Granularity** | File-level | Directory-level |
| **Overhead** | Computation during OPTIMIZE | Directory pruning |
| **Flexibility** | Multiple columns | Fewer columns |
| **Query Types** | Range queries, filters | Equality filters |
| **Performance** | Better for selective queries | Better for large filters |
| **Storage** | Same files, different order | Separate directories |
| **Maintenance** | Manual OPTIMIZE needed | Automatic on write |

**When to Use Z-Ordering:**

1. **Selective Queries:**
   ```python
   # Query filters on 2+ columns with high cardinality
   spark.sql("""
       SELECT * FROM sales 
       WHERE customer_id = 123 
       AND date BETWEEN '2024-01-01' AND '2024-03-31'
   """)
   # Z-ORDER BY (customer_id, date) helps
   ```

2. **High Cardinality Columns:**
   - Too many unique values to partition
   - Would create too many partitions

3. **Multi-column Filtering:**
   - Queries filter on multiple columns
   - Range queries common

4. **BI and Analytics Queries:**
   - Dashboard queries
   - Ad-hoc analysis
   - Report generation

**When to Use Partitioning:**

1. **Equality Filters:**
   ```python
   # Partition by region
   spark.sql("SELECT * FROM sales WHERE region = 'US'")
   ```

2. **Retention Policies:**
   ```python
   # Partition by date for easy deletion
   # Remove old partitions efficiently
   ```

3. **Low Cardinality:**
   - Few unique values
   - Few partitions created

**Example Implementation:**

```python
# Initial write with partitioning
df.write \
  .partitionBy("region", "year") \
  .mode("overwrite") \
  .delta("/path/sales/")

# Then optimize with Z-ordering
spark.sql("""
    OPTIMIZE sales 
    ZORDER BY (customer_id, purchase_date, product_id)
""")
```

**Performance Impact:**

Before optimization:
```
Query: WHERE customer_id = 123 AND date = '2024-01-15'
Scans all files in all partitions
```

After Z-ordering:
```
Query: WHERE customer_id = 123 AND date = '2024-01-15'
Skips most files (data collocated in few files)
Much faster
```

**Monitoring:**

```python
# Check optimization impact
spark.sql("""
    DESCRIBE DETAIL sales
""").show()
# Shows number of files, avg file size

# Run explain to see optimization
spark.sql("""
    EXPLAIN EXTENDED
    SELECT * FROM sales 
    WHERE customer_id = 123
""").show()
```

---

**Last Updated:** April 12, 2026
**Version:** 3.1 (Added 44 new Q's from Questions file: Q157-Q200)
**Total Questions:** 200
**Total Topics:** 30

