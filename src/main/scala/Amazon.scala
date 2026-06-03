/*
Amazon Data Engineer II - Coding Round Cheat Sheet (Scala)

Focus Areas:
1. HashMap
2. HashSet
3. Sliding Window
4. Intervals
5. Prefix Sum

Each problem includes:
- Problem statement
- Pattern
- Time/Space Complexity
- Scala Solution
*/

import scala.collection.mutable
import scala.collection.mutable.ListBuffer

object AmazonDE2CodingGuide {

  // ------------------------------------------------------------------
  // 1. TWO SUM
  // Pattern: HashMap
  // Time: O(n)
  // Space: O(n)
  // ------------------------------------------------------------------

  def twoSum(nums: Array[Int], target: Int): (Int, Int) = {
    val map = mutable.Map[Int, Int]()

    for (i <- nums.indices) {
      val complement = target - nums(i)

      if (map.contains(complement))
        return (map(complement), i)

      map(nums(i)) = i
    }

    (-1, -1)
  }

  // ------------------------------------------------------------------
  // 2. COMMON KEYS BETWEEN TWO LISTS
  // Pattern: Hash Join
  // Time: O(n + m)
  // ------------------------------------------------------------------

  def commonKeys(
                  list1: List[(Int, String)],
                  list2: List[(Int, String)]
                ): List[(Int, (String, String))] = {

    val map2 = list2.toMap

    list1.collect {
      case (k, v) if map2.contains(k) =>
        (k, (v, map2(k)))
    }
  }

  // ------------------------------------------------------------------
  // 3. GROUP ANAGRAMS
  // Pattern: Group By Sorted String
  // Time: O(n * k log k)
  // ------------------------------------------------------------------

  def groupAnagrams(words: List[String]): List[List[String]] = {
    words.groupBy(_.sorted).values.toList
  }

  // ------------------------------------------------------------------
  // 4. TOP K FREQUENT ELEMENTS
  // Pattern: Frequency Map
  // Time: O(n log n)
  // ------------------------------------------------------------------

  def topKFrequent(nums: Array[Int], k: Int): List[Int] = {
    nums
      .groupBy(identity)
      .view
      .mapValues(_.length)
      .toList
      .sortBy(-_._2)
      .take(k)
      .map(_._1)
  }

  // ------------------------------------------------------------------
  // 5. FIRST NON-REPEATING CHARACTER
  // Pattern: Frequency Counting
  // Time: O(n)
  // ------------------------------------------------------------------

  def firstNonRepeating(str: String): Option[Char] = {

    val freq = mutable.Map[Char, Int]()

    str.foreach { ch =>
      freq(ch) = freq.getOrElse(ch, 0) + 1
    }

    str.find(ch => freq(ch) == 1)
  }

  // ------------------------------------------------------------------
  // 6. LONGEST SUBSTRING WITHOUT REPEATING CHARACTERS
  // Pattern: Sliding Window
  // Time: O(n)
  // ------------------------------------------------------------------

  def longestSubstringLength(str: String): Int = {

    val seen = mutable.Set[Char]()

    var left = 0
    var maxLen = 0

    for (right <- str.indices) {

      while (seen.contains(str(right))) {
        seen.remove(str(left))
        left += 1
      }

      seen.add(str(right))

      maxLen = math.max(maxLen, right - left + 1)
    }

    maxLen
  }

  // ------------------------------------------------------------------
  // 7. LONGEST CONSECUTIVE SEQUENCE
  // Pattern: HashSet
  // Time: O(n)
  // ------------------------------------------------------------------

  def longestConsecutive(nums: Array[Int]): Int = {

    val set = nums.toSet

    var longest = 0

    for (num <- set) {

      if (!set.contains(num - 1)) {

        var current = num
        var length = 1

        while (set.contains(current + 1)) {
          current += 1
          length += 1
        }

        longest = math.max(longest, length)
      }
    }

    longest
  }

  // ------------------------------------------------------------------
  // 8. MERGE INTERVALS
  // Pattern: Sort + Scan
  // Time: O(n log n)
  // ------------------------------------------------------------------

  def mergeIntervals(
                      intervals: List[(Int, Int)]
                    ): List[(Int, Int)] = {

    if (intervals.isEmpty)
      return List()

    val sorted = intervals.sortBy(_._1)

    val result = ListBuffer[(Int, Int)]()

    var current = sorted.head

    for (interval <- sorted.tail) {

      if (interval._1 <= current._2) {
        current =
          (current._1, math.max(current._2, interval._2))
      } else {
        result += current
        current = interval
      }
    }

    result += current

    result.toList
  }

  // ------------------------------------------------------------------
  // 9. MEETING ROOMS
  // Pattern: Interval Overlap
  // Time: O(n log n)
  // ------------------------------------------------------------------

  def canAttendMeetings(
                         meetings: List[(Int, Int)]
                       ): Boolean = {

    val sorted = meetings.sortBy(_._1)

    for (i <- 0 until sorted.length - 1) {

      if (sorted(i)._2 > sorted(i + 1)._1)
        return false
    }

    true
  }

  // ------------------------------------------------------------------
  // 10. SUBARRAY SUM EQUALS K
  // Pattern: Prefix Sum + HashMap
  // Time: O(n)
  // ------------------------------------------------------------------

  def subarraySum(nums: Array[Int], k: Int): Int = {

    val map = mutable.Map[Int, Int](0 -> 1)

    var prefixSum = 0
    var count = 0

    for (num <- nums) {

      prefixSum += num

      count += map.getOrElse(prefixSum - k, 0)

      map(prefixSum) =
        map.getOrElse(prefixSum, 0) + 1
    }

    count
  }


  def merge(intervals: Array[Array[Int]]): Array[Array[Int]] = {
    var i = 0
    var res = mutable.ListBuffer[Array[Int]]()
    var starting_interval = intervals(0)(0)
    var ending_interval = intervals(0)(1)
    for (i <- intervals.indices) {
      var current_start_interval: Int = intervals(i)(0)
      var current_end_interval: Int = intervals(i)(1)

      if (current_start_interval <= ending_interval) {
        ending_interval = current_end_interval
      }
      else {
        res = res.append(Array(starting_interval, ending_interval))
        starting_interval = current_start_interval
        ending_interval = current_end_interval
      }
    }
    res.toArray

  }

}
