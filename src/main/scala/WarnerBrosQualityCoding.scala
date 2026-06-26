import scala.collection.mutable

/**
 * Warner Bros Discovery
 * Senior Data Engineer
 * Quality Coding (Logical & Maintainable)
 *
 * Topics Covered:
 * 1. Validation
 * 2. Deduplication
 * 3. Aggregation
 * 4. Top-K Optimization
 * 5. Complexity Analysis
 * 6. Maintainable Design
 */
object WarnerBrosQualityCoding {

  case class WatchEvent(
                         eventId: String,
                         userId: String,
                         contentId: String,
                         watchDuration: Int,
                         eventTime: Long
                       )

  /**
   * Entry point
   */
  def main(args: Array[String]): Unit = {

    val events = List(
      WatchEvent("e1", "u1", "c1", 30, 1000),
      WatchEvent("e2", "u1", "c2", 40, 1001),
      WatchEvent("e3", "u2", "c1", 50, 1002),
      WatchEvent("e4", "u3", "c3", 20, 1003),

      // Duplicate Event
      WatchEvent("e1", "u1", "c1", 30, 1000),

      // Invalid Event
      WatchEvent("", "u4", "c4", -10, 1004)
    )

    val result = getTopUsers(events, 2)

    println("Top Users:")
    result.foreach(println)
  }

  /**
   * Public API
   */
  def getTopUsers(
                   events: List[WatchEvent],
                   k: Int
                 ): List[(String, Int)] = {

    require(k > 0, "k must be greater than 0")

    if (events.isEmpty) {
      return List.empty
    }

    val validEvents =
      validateEvents(events)

    val deduplicatedEvents =
      deduplicateEvents(validEvents)

    val watchTimePerUser =
      aggregateWatchTime(deduplicatedEvents)

    topKUsers(watchTimePerUser, k)
  }

  /**
   * Validation Layer
   *
   * Rules:
   * - eventId mandatory
   * - userId mandatory
   * - watchDuration > 0
   */
  def validateEvents(
                      events: List[WatchEvent]
                    ): List[WatchEvent] = {

    events.filter { event =>
      event.eventId.nonEmpty &&
        event.userId.nonEmpty &&
        event.watchDuration > 0
    }
  }


  /**
   * Deduplicate by eventId
   *
   * Time: O(n)
   * Space: O(unique eventIds)
   */
  def deduplicateEvents(
                         events: List[WatchEvent]
                       ): Seq[WatchEvent] = {

    val (_, deduplicatedEvents) =
      events.foldLeft(
        (Set.empty[String], List.empty[WatchEvent])
      ) {

        case ((seenIds, acc), event)
          if seenIds.contains(event.eventId) =>

          (seenIds, acc)

        case ((seenIds, acc), event) =>

          (
            seenIds + event.eventId,
            event :: acc
          )
      }

    deduplicatedEvents.reverse
  }

  /**
   * Aggregate Watch Time Per User
   *
   * Time: O(n)
   * Space: O(unique users)
   */
  def aggregateWatchTime(
                          events: List[WatchEvent]
                        ): Map[String, Int] = {

    events.foldLeft(Map.empty[String, Int]) {

      case (accumulator, event) =>

        accumulator.updated(
          event.userId,
          accumulator.getOrElse(event.userId, 0) +
            event.watchDuration
        )
    }
  }

  /**
   * Top-K Users Using Min Heap
   *
   * Complexity:
   * O(u log k)
   *
   * u = unique users
   */
  def topKUsers(
                 watchTimePerUser: Map[String, Int],
                 k: Int
               ): List[(String, Int)] = {

    implicit val minHeapOrdering:
      Ordering[(String, Int)] =
      Ordering.by[(String, Int), Int](_._2)
        .reverse

    val minHeap =
      mutable.PriorityQueue.empty[(String, Int)]

    watchTimePerUser.foreach {

      case userEntry @ (_, watchTime) =>

        if (minHeap.size < k) {

          minHeap.enqueue(userEntry)

        } else if (
          watchTime > minHeap.head._2
        ) {

          minHeap.dequeue()

          minHeap.enqueue(userEntry)
        }
    }

    minHeap.dequeueAll.reverse.toList
  }
}

/**
 * ============================================================
 * Interview Talking Points
 * ============================================================
 *
 * 1. Clarification Questions
 * ------------------------------------------------------------
 * - Can duplicates exist?
 * - Can watchDuration be negative?
 * - Can userId be empty?
 * - Is eventId globally unique?
 * - What should happen for k <= 0?
 *
 * 2. Validation
 * ------------------------------------------------------------
 * Validate records before processing.
 *
 * 3. Deduplication
 * ------------------------------------------------------------
 * Use Set[eventId]
 *
 * Time: O(n)
 *
 * 4. Aggregation
 * ------------------------------------------------------------
 * Use foldLeft instead of groupBy.
 *
 * Why?
 *
 * groupBy:
 *   Space O(n)
 *
 * foldLeft:
 *   Space O(unique users)
 *
 * 5. Top K Optimization
 * ------------------------------------------------------------
 * Naive:
 *
 * sortBy
 *
 * O(u log u)
 *
 * Optimized:
 *
 * PriorityQueue
 *
 * O(u log k)
 *
 * 6. Spark Batch Equivalent
 * ------------------------------------------------------------
 *
 * df
 *   .dropDuplicates("eventId")
 *   .groupBy("userId")
 *   .agg(sum("watchDuration"))
 *
 * 7. Spark Streaming Equivalent
 * ------------------------------------------------------------
 *
 * streamingDf
 *   .withWatermark(
 *      "eventTime",
 *      "30 minutes"
 *   )
 *   .dropDuplicates("eventId")
 *   .groupBy("userId")
 *   .agg(sum("watchDuration"))
 *
 * 8. Follow-Up Topics
 * ------------------------------------------------------------
 * - Watermark
 * - Late Events
 * - Checkpointing
 * - Data Skew
 * - AQE
 * - Salting
 * - CDC
 * - Idempotency
 *
 * ============================================================
 */