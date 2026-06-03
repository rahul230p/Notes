# Spark Join Types - Internal Mechanics & Deep Dive

## Table of Contents
1. [Join Type Overview](#join-type-overview)
2. [Broadcast Hash Join](#broadcast-hash-join)
3. [Sort-Merge Join](#sort-merge-join)
4. [Hash Join (Shuffle Hash)](#hash-join-shuffle-hash)
5. [Nested Loop Join](#nested-loop-join)
6. [Performance Comparison](#performance-comparison)
7. [When to Use Which](#when-to-use-which)

---

## Join Type Overview

```
Spark Join Strategies:

┌─────────────────────────────────────────────────────────────┐
│                    JOIN DECISION TREE                       │
└─────────────────────────────────────────────────────────────┘
                            │
                    Is one side < 10MB?
                    (autoBroadcastJoinThreshold)
                    │               │
                   YES              NO
                    │               │
        ┌───────────▼──────┐  ┌────▼────────────────────┐
        │ Broadcast Hash   │  │ Check join conditions   │
        │ (1 stage)        │  │                         │
        └──────────────────┘  └────┬───────────────────┘
                                   │
                        Are both sides bucketed
                        on join key?
                        │               │
                       YES              NO
                        │               │
          ┌─────────────▼──┐  ┌────────▼────────────┐
          │ Bucketed Sort- │  │ Sort-Merge Join     │
          │ Merge Join     │  │ (3 stages)          │
          │ (2 stages)     │  │ - Shuffle both      │
          └────────────────┘  │ - Sort both         │
                              │ - Merge             │
                              └─────────────────────┘
```

---

## Broadcast Hash Join

### How It Works Internally

```
Broadcast Hash Join Process:

Step 1: BROADCAST PHASE (Driver → Executors)
┌─────────────────────────────────────┐
│         Small Table (100MB)         │
│  [Build Hash Table in Memory]       │
└─────────────────────────────────────┘
                │
        ┌───────┼───────┬───────┐
        │       │       │       │
    ┌───▼──┐ ┌──▼──┐ ┌──▼──┐ ┌──▼──┐
    │Exec 1│ │Exec2│ │Exec3│ │Exec4│
    │Cache │ │Cache│ │Cache│ │Cache│
    └──────┘ └─────┘ └─────┘ └─────┘
    (Each executor gets full small table)

Step 2: PROBE PHASE (Scan Large Table)
┌──────────────────────────────────────┐
│    Large Table (1TB) - Partitioned   │
└──────────────────────────────────────┘
    │
    ├─ Partition 1 ──┐
    ├─ Partition 2 ──┼─► [Probe Hash Table]
    ├─ Partition 3 ──┤   [Find matches]
    └─ Partition N ──┘   [Output results]

Output: Joined tuples
```

### Broadcast Hash Join Code

```scala
import org.apache.spark.sql.functions.broadcast

// Table sizes:
// largeTable: 1TB (1000 partitions)
// smallTable: 100MB (1 partition)

val largeTable = spark.read.parquet("/large/data")
val smallTable = spark.read.parquet("/small/data")

// EXPLICIT BROADCAST
val result = largeTable.join(
  broadcast(smallTable),
  col("large.id") === col("small.id"),
  "inner"
)

// AUTOMATIC BROADCAST (if smallTable < 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10MB")
val result = largeTable.join(smallTable, "id")
// Catalyst detects small table, automatically broadcasts

// Explain plan
result.explain(extended = true)
// Output will show: BroadcastHashJoin

// What happens internally:
// 1. Driver collects small table: O(100MB)
// 2. Broadcasts to all executors
// 3. Each executor builds hash table: O(100MB memory per executor)
// 4. Large table scanned in parallel
// 5. For each row in large table:
//    - Hash the join key
//    - Lookup in local hash table
//    - If match found, output joined row
```

### Time & Space Complexity

```
Time Complexity:
├─ Broadcast: O(n) where n = small table size
├─ Hash table build: O(m) where m = small table rows
├─ Probe: O(k) where k = large table rows
└─ Total: O(m + k)

Space Complexity:
├─ Broadcast network: O(n) bytes
├─ Hash table per executor: O(m) rows
└─ Total memory needed: m + (k / p) where p = partitions

Example with 100MB small table:
├─ Broadcast: 100MB from driver to all executors
├─ Hash table: 100MB in memory on each executor
├─ Large table: 1TB / 1000 partitions = 1GB per partition
└─ Each executor processes 1GB in parallel
```

### Advantages & Disadvantages

```
ADVANTAGES ✓
├─ Fastest join (single stage)
├─ No shuffle required
├─ Network efficient (broadcast only small table)
├─ Low memory overhead for large table (no sorting)
└─ Predictable performance

DISADVANTAGES ✗
├─ Requires small table < broadcast threshold
├─ Network cost to broadcast to all executors
├─ Driver memory limit (can't broadcast > driver memory)
├─ Not suitable for skewed data (still broadcasts all)
└─ Doesn't benefit from bucketing
```

### Real-World Example

```scala
// E-commerce: Join Orders (1TB) with Products (100MB)

val orders = spark.read.parquet("/orders")  // 1TB
val products = spark.read.parquet("/products")  // 100MB

// ✓ Perfect for broadcast join
val enriched = orders
  .join(
    broadcast(products),
    col("orders.product_id") === col("products.id"),
    "left"
  )
  .select(
    col("orders.order_id"),
    col("orders.amount"),
    col("products.name"),
    col("products.category")
  )

enriched.explain()
// Will show: BroadcastHashJoin

// Performance:
// - Time: ~30 seconds (parallel scan + hash lookup)
// - Network: 100MB × num_executors (small)
// - Memory: 100MB per executor + 1GB per executor (order partition)
// - No shuffle required
```

---

## Sort-Merge Join

### How It Works Internally

```
Sort-Merge Join Process:

Stage 1: SHUFFLE PHASE
┌────────────────────────────────────────┐
│  Left Table (1TB)  │  Right Table (1TB) │
└────────────────────────────────────────┘
         │                    │
    ┌────▼─────────┐  ┌──────▼──────┐
    │ Shuffle by   │  │ Shuffle by   │
    │ join key     │  │ join key     │
    │ (Repartition)│  │ (Repartition)│
    └────┬─────────┘  └──────┬───────┘
         │                    │
    ┌────▼──────────────────▼──┐
    │ Same join key             │
    │ same partition            │
    └────┬──────────────────────┘
         │
    ┌────▼─────────────────┐
    │ Partition 0: All key=A
    │ Partition 1: All key=B
    │ Partition N: All key=Z
    └─────────────────────┘

Stage 2: SORT PHASE (within each partition)
┌────────────────────────────────────┐
│ For each partition:                │
│ ├─ Sort left table by join key    │
│ ├─ Sort right table by join key   │
│ └─ (If bucketed, skip sort)       │
└────────────────────────────────────┘

Stage 3: MERGE PHASE
┌────────────────────────────────────┐
│ For each partition pair:           │
│ ├─ Pointer in left table: L       │
│ ├─ Pointer in right table: R      │
│ ├─ While L.key == R.key:          │
│ │  └─ Output (L, R) tuple        │
│ ├─ Move pointer where key changes │
│ └─ Repeat for next key            │
└────────────────────────────────────┘

Output: Sorted merged data
```

### Sort-Merge Join Code

```scala
// Table sizes:
// left: 1TB with join key "id"
// right: 1TB with join key "id"

val left = spark.read.parquet("/left/data")
val right = spark.read.parquet("/right/data")

// EXPLICIT SORT-MERGE JOIN
val result = left
  .join(
    right,
    col("left.id") === col("right.id"),
    "inner"
  )

// Configuration for sort-merge
spark.conf.set("spark.sql.join.preferSortMergeJoin", "true")
spark.conf.set("spark.sql.shuffle.partitions", "200")

// Explain plan
result.explain(extended = true)
// Output will show: SortMergeJoin with Exchange (shuffle)

// What happens internally:
// 1. SHUFFLE WRITE phase:
//    - For each row in left table:
//      * Hash(join_key) % num_partitions = target_partition
//      * Write to shuffle file
//
// 2. SHUFFLE READ phase:
//    - Each executor reads shuffle files for its partition
//    - Result: All rows with same join key = same executor
//
// 3. SORT phase:
//    - Sort left table by join key: O(n log n)
//    - Sort right table by join key: O(m log m)
//
// 4. MERGE phase:
//    - Two pointers technique (like merge sort)
//    - Single scan: O(n + m)
//    - Output matching rows
```

### Time & Space Complexity

```
Time Complexity:
├─ Shuffle write: O(n)
├─ Network shuffle: O(n)
├─ Sort phase: O(n log n) + O(m log m)
├─ Merge phase: O(n + m)
└─ Total: O(n log n + m log m)

Space Complexity:
├─ Shuffle buffers: O(n/p) where p = partitions
├─ Sort memory: O(n/p) per executor
├─ Output: O(result_size)
└─ Total memory per executor: O(n/p + m/p)

Example with 1TB × 1TB join:
├─ Shuffle: 2TB network I/O
├─ Sort: ~1 hour total (if CPU bound)
├─ Merge: Fast (linear scan)
└─ Total: ~1-2 hours depending on cluster
```

### Advantages & Disadvantages

```
ADVANTAGES ✓
├─ Handles large tables (no memory limit like broadcast)
├─ Efficient for large×large joins
├─ Works well with bucketed tables (skip shuffle)
├─ Can use existing sorted data
├─ Good for range joins
└─ Memory efficient for merge phase

DISADVANTAGES ✗
├─ Slow sorting (O(n log n))
├─ Network shuffle required (2x data movement)
├─ Many stages (shuffle → sort → merge)
├─ Sensitive to data skew in shuffle
├─ Spilling to disk if not enough memory
└─ Not ideal for small tables (overhead)
```

### Real-World Example

```scala
// Financial data: Join Transactions (500GB) with Accounts (500GB)

val transactions = spark.read.parquet("/transactions")
val accounts = spark.read.parquet("/accounts")

// Both tables are large - use sort-merge
val enriched = transactions
  .join(
    accounts,
    col("transactions.account_id") === col("accounts.id"),
    "inner"
  )
  .select(
    col("transactions.tx_id"),
    col("transactions.amount"),
    col("accounts.account_name"),
    col("accounts.balance")
  )

enriched.explain()
// Will show: SortMergeJoin with Exchange

// Optimization: Pre-sort and bucket
transactions.write
  .bucketBy(100, "account_id")
  .mode("overwrite")
  .parquet("/transactions_bucketed")

accounts.write
  .bucketBy(100, "id")
  .mode("overwrite")
  .parquet("/accounts_bucketed")

// Now joins skip shuffle!
val txBucketed = spark.read.parquet("/transactions_bucketed")
val acctBucketed = spark.read.parquet("/accounts_bucketed")

val fastJoin = txBucketed.join(acctBucketed, "account_id")
// Skips shuffle + sort, just merge!
// Performance: Much faster (no shuffle overhead)
```

---

## Hash Join (Shuffle Hash)

### How It Works Internally

```
Hash Join (Shuffle Hash) Process:

Stage 1: SHUFFLE HASH JOIN
┌──────────────────────────────────────────┐
│ Input: Left (1TB), Right (500GB)        │
└──────────────────────────────────────────┘
     │                    │
┌────▼────┐      ┌────────▼──────┐
│  SHUFFLE │      │  SHUFFLE      │
│  LEFT by │      │  RIGHT by     │
│  join key│      │  join key     │
└────┬────┘      └────────┬───────┘
     │                    │
┌────▼────────────────────▼──┐
│ Partition 0: All key=A     │
│ ├─ LEFT rows with key=A    │
│ ├─ RIGHT rows with key=A   │
│ └─ Build hash table (LEFT) │
│    Probe with RIGHT        │
├────────────────────────────┤
│ Partition 1: All key=B     │
│ ... (repeat)               │
└────────────────────────────┘

Output: Joined tuples
```

### Hash Join Code

```scala
// When used:
// - Both tables too large to broadcast
// - But prefer not to sort (data already ordered?)

val left = spark.read.parquet("/left")
val right = spark.read.parquet("/right")

// Hash join happens when:
// 1. Broadcast doesn't work (both large)
// 2. Sort-merge not preferred
// 3. Catalyst chooses hash join

val result = left.join(right, "id")

// Disable sort-merge to force hash join
spark.conf.set("spark.sql.join.preferSortMergeJoin", "false")

// Explain plan
result.explain()
// May show: HashAggregate, ShuffledHashJoin, or Exchange

// What happens internally:
// 1. Both tables shuffled by join key
// 2. For each partition:
//    - Build hash table from smaller side
//    - Probe with larger side
//    - Output matches
```

### Time & Space Complexity

```
Time Complexity:
├─ Shuffle: O(n + m)
├─ Hash table build: O(min(n,m))
├─ Hash probe: O(max(n,m))
└─ Total: O(n + m)

Space Complexity:
├─ Hash table: O(min(n,m)) per partition
├─ Shuffle buffers: O(max(n,m) / p)
└─ Total per executor: O(min(n,m) + max(n,m)/p)

vs Sort-Merge:
├─ Hash: O(n + m) time
├─ Sort-Merge: O(n log n + m log m) time
└─ Hash is faster if no sorting needed!
```

---

## Nested Loop Join

### How It Works Internally

```
Nested Loop Join (Cartesian Product):

Input: Left table × Right table
       (No join condition or WHERE condition)

For each row in Left:
  For each row in Right:
    Output (Left_row, Right_row)

Result size: |Left| × |Right|

Example:
Left: 1000 rows
Right: 500 rows
Result: 1,000 × 500 = 500,000 rows

If Left: 1M rows
   Right: 1M rows
Result: 1 trillion rows! ⚠️ DANGER
```

### Nested Loop Join Code

```scala
// Cross join / Cartesian product
val left = spark.read.parquet("/left")
val right = spark.read.parquet("/right")

// EXPLICIT CROSS JOIN
val result = left.join(right)  // No join condition
val result = left.crossJoin(right)

// Explain plan shows: CartesianProduct or CrossJoin

// What happens internally:
// 1. Broadcast join not possible (no condition)
// 2. Can't use hash/sort-merge (no join key)
// 3. Resort to nested loop
// 4. Very expensive! O(n × m)

// Example: Get all combinations
val users = spark.createDataFrame(Seq(
  (1, "Alice"), (2, "Bob")
)).toDF("id", "name")

val colors = spark.createDataFrame(Seq(
  ("Red"), ("Blue"), ("Green")
)).toDF("color")

val combinations = users.crossJoin(colors)
// Result:
// (1, Alice, Red)
// (1, Alice, Blue)
// (1, Alice, Green)
// (2, Bob, Red)
// (2, Bob, Blue)
// (2, Bob, Green)
// Total: 2 × 3 = 6 rows
```

### When Nested Loop Joins Occur

```
Scenario 1: Explicit Cross Join
val result = df1.join(df2)  // No join condition

Scenario 2: Complex Join Condition (no simple key)
val result = df1.join(
  df2,
  (col("df1.x") > col("df2.x")) && (col("df1.y") < col("df2.y"))
)

Scenario 3: Broadcast join can't fit in memory
val result = df1.join(df2, "id")
// If df2 > broadcast threshold and left with no partition info

Scenario 4: Multiple tables without join keys
val result = df1.join(df2).join(df3).join(df4)

Risk: Exponential explosion of rows!
```

---

## Performance Comparison

### Execution Time by Join Type

```
Scenario: Join 100GB table with 1GB table

Join Type              │ Time      │ Network │ Memory
───────────────────────┼───────────┼─────────┼──────────
Broadcast Hash Join    │ ██ 10s    │ 1GB     │ 1GB
Sort-Merge Join        │ ████████ 60s │ 100GB   │ 10GB
Shuffle Hash Join      │ ██████ 40s    │ 101GB   │ 5GB
Nested Loop Join       │ ████████████████ 300s │ 100GB │ 50GB

WINNER: Broadcast Hash Join (10x faster!)
```

### Join Decision Matrix

```
Join Type           │ When to Use          │ Pros           │ Cons
────────────────────┼──────────────────────┼────────────────┼─────────────
Broadcast Hash      │ Small×Large          │ Fastest        │ Memory limit
                    │ < 100MB × any        │ 1 stage        │ No large table
────────────────────┼──────────────────────┼────────────────┼─────────────
Sort-Merge Join     │ Large×Large          │ Scales well    │ Sort overhead
                    │ Both > 100MB         │ No memory limit│ Shuffle cost
                    │ Data already sorted  │ Bucketing help │ Multiple stages
────────────────────┼──────────────────────┼────────────────┼─────────────
Shuffle Hash Join   │ Large×Large          │ No sort        │ Hash overhead
                    │ Neither can broadcast│ Fair memory    │ Shuffle cost
────────────────────┼──────────────────────┼────────────────┼─────────────
Nested Loop Join    │ Few rows              │ Simple         │ VERY SLOW
                    │ Complex join logic   │ Works anytime  │ Cartesian
                    │ Small result set     │                │ Explosion
```

---

## When to Use Which

### Decision Tree

```
Start: Need to join two tables

Is one table < autoBroadcastJoinThreshold?
├─ YES → Use BROADCAST HASH JOIN
│        Benefits: 10x faster, single stage
│        Code: join(broadcast(smallTable))
│
└─ NO → Are both tables already bucketed on join key?
       ├─ YES → Use BUCKETED SORT-MERGE JOIN
       │        Benefits: Skip shuffle, skip sort
       │        Time: ~10s-30s for medium joins
       │
       └─ NO → Is data already sorted on join key?
              ├─ YES → Use SORT-MERGE JOIN (skip sort)
              │        Time: ~40s for large joins
              │
              └─ NO → Consider data characteristics
                     │
                     ├─ Is one side < 500MB?
                     │  └─ Increase broadcast threshold
                     │     Use: spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "500MB")
                     │
                     ├─ Are both sides > 1GB?
                     │  └─ Use SORT-MERGE JOIN
                     │     Benefits: Predictable performance
                     │
                     └─ Is join condition complex (non-equality)?
                        └─ Use NESTED LOOP (accept slowness)
                           Or rewrite query to use bucketing
```

### Real Examples

```scala
// EXAMPLE 1: E-Commerce Orders × Products
val orders = spark.read.parquet("/orders")     // 100GB
val products = spark.read.parquet("/products") // 50MB

// ✓ USE: Broadcast Hash Join
val result = orders.join(broadcast(products), "product_id")

// EXAMPLE 2: Orders × Customers (both large)
val orders = spark.read.parquet("/orders")       // 100GB
val customers = spark.read.parquet("/customers") // 50GB

// Option 1: Sort-Merge (if not bucketed)
spark.conf.set("spark.sql.join.preferSortMergeJoin", "true")
val result = orders.join(customers, "customer_id")

// Option 2: Pre-bucket, then join (fastest)
orders.write.bucketBy(100, "customer_id").parquet("/orders_bucketed")
customers.write.bucketBy(100, "id").parquet("/customers_bucketed")
val ordersB = spark.read.parquet("/orders_bucketed")
val customersB = spark.read.parquet("/customers_bucketed")
val result = ordersB.join(customersB, "customer_id")

// EXAMPLE 3: Multiple joins (chain)
val orders = spark.read.parquet("/orders")           // 100GB
val customers = spark.read.parquet("/customers")     // 50GB
val products = spark.read.parquet("/products")       // 10MB
val payments = spark.read.parquet("/payments")       // 30GB

// ✓ OPTIMIZE: Broadcast products early
val result = orders
  .join(broadcast(products), "product_id")          // Broadcast (fast)
  .join(customers, "customer_id")                   // Sort-Merge
  .join(broadcast(payments), "order_id")            // Broadcast (fast)

// Bad approach (many shuffles)
val bad = orders.join(customers)
  .join(products)
  .join(payments)
```

---

## Join Hints (Force Join Type)

```scala
// Spark SQL allows join hints
spark.sql("""
  SELECT /*+ BROADCAST(products) */ *
  FROM orders
  JOIN products ON orders.product_id = products.id
""")

// Available hints:
// - BROADCAST or BROADCASTJOIN
// - SHUFFLE_HASH
// - SHUFFLE_REPLICATE_NL (broadcast via shuffle)
// - MERGE
// - SHUFFLE (any shuffle join)

// DataFrame API equivalent
orders.join(
  products,
  col("orders.product_id") === col("products.id"),
  "inner"
)
// Use hint via SQL subquery if needed
```

---

## Summary

```
┌─────────────────────────────────────────────────────────┐
│ QUICK REFERENCE: Join Performance                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Fastest:      Broadcast Hash Join (< 20 seconds)      │
│ Fast:         Bucketed Sort-Merge (< 60 seconds)      │
│ Moderate:     Sort-Merge Join (< 120 seconds)         │
│ Slow:         Shuffle Hash Join (< 120 seconds)       │
│ Very Slow:    Nested Loop Join (> 300 seconds)        │
│                                                         │
│ Golden Rule: Always broadcast if possible!            │
│ Silver Rule: Use bucketing for frequent joins         │
│ Bronze Rule: Sort-merge for everything else           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```


