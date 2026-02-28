//🧠 Fixed-Length Sliding Window — How to Identify
//  ✅ Use FIXED-LENGTH Sliding Window when:
//
//  The problem says “exactly K”
//
//Mentions “substring/subarray of size K”
//
//Says “K consecutive elements”
//
//Window size never changes
//
//❌ NOT fixed-length when:
//
//“at most K”
//
//“minimum / maximum length”
//
//“longest / shortest”
//
//🔑 Core Pattern (MEMORIZE)
//
//Add right → process window → remove left
//
//add(nums(right))
//
//if (right - left + 1 == k) {
//  process()
//  remove(nums(left))
//  left += 1
//}
//
//🚨 Edge Cases You MUST Handle
//
//input.length < k → return early
//
//Correct window size → right - left + 1
//
//Don’t forget to remove left
//
//Don’t use substring / nested loops

//✅ Scala Class: Fixed-Length Sliding Window
import scala.collection.mutable
import scala.collection.mutable.ListBuffer

class FixedLengthSlidingWindow {

  // --------------------------------------------------
  // Q1. Maximum Sum Subarray of Size K
  // --------------------------------------------------
  // Given an array and k, find the max sum of any
  // contiguous subarray of size k.
  // --------------------------------------------------

  def maxSumSubarray(nums: Array[Int], k: Int): Int = {
    if (nums.length < k) return 0

    var windowSum = 0
    var maxSum = 0
    var left = 0

    for (right <- nums.indices) {
      windowSum += nums(right)

      if (right - left + 1 == k) {
        maxSum = math.max(maxSum, windowSum)
        windowSum -= nums(left)
        left += 1
      }
    }
    maxSum
  }

  // --------------------------------------------------
  // Q2. Maximum Average Subarray of Size K
  // --------------------------------------------------

  def maxAverageSubarray(nums: Array[Int], k: Int): Double = {
    if (nums.length < k) return 0.0

    var sum = 0
    for (i <- 0 until k) sum += nums(i)

    var maxSum = sum
    for (i <- k until nums.length) {
      sum += nums(i)
      sum -= nums(i - k)
      maxSum = math.max(maxSum, sum)
    }
    maxSum.toDouble / k
  }

  // --------------------------------------------------
  // Q3. Find All Anagrams in a String
  // --------------------------------------------------
  // Fixed window = length of p
  // --------------------------------------------------

  def findAnagrams(s: String, p: String): List[Int] = {
    val result = ListBuffer[Int]()
    if (s.length < p.length) return result.toList

    val freq = Array.fill(26)(0)
    for (c <- p) freq(c - 'a') += 1

    var left = 0
    var count = p.length

    for (right <- s.indices) {
      if (freq(s(right) - 'a') > 0) count -= 1
      freq(s(right) - 'a') -= 1

      if (right - left + 1 == p.length) {
        if (count == 0) result += left

        if (freq(s(left) - 'a') >= 0) count += 1
        freq(s(left) - 'a') += 1
        left += 1
      }
    }
    result.toList
  }

  // --------------------------------------------------
  // Q4. Permutation in String
  // --------------------------------------------------
  // Same as anagrams but return boolean
  // --------------------------------------------------

  def checkInclusion(p: String, s: String): Boolean = {
    if (s.length < p.length) return false

    val freq = Array.fill(26)(0)
    for (c <- p) freq(c - 'a') += 1

    var left = 0
    var count = p.length

    for (right <- s.indices) {
      if (freq(s(right) - 'a') > 0) count -= 1
      freq(s(right) - 'a') -= 1

      if (right - left + 1 == p.length) {
        if (count == 0) return true

        if (freq(s(left) - 'a') >= 0) count += 1
        freq(s(left) - 'a') += 1
        left += 1
      }
    }
    false
  }

  // --------------------------------------------------
  // Q5. Maximum Number of Vowels in a Substring of Size K
  // --------------------------------------------------

  def maxVowels(s: String, k: Int): Int = {
    val vowels = Set('a', 'e', 'i', 'o', 'u')
    var count = 0
    var maxCount = 0
    var left = 0

    for (right <- s.indices) {
      if (vowels.contains(s(right))) count += 1

      if (right - left + 1 == k) {
        maxCount = math.max(maxCount, count)
        if (vowels.contains(s(left))) count -= 1
        left += 1
      }
    }
    maxCount
  }
}

//🗣️ What to Say in Interview (IMPORTANT)
//
//Use these exact lines:
//
//“This is a fixed-length sliding window problem.”
//
//“I add the right element and remove the left when the window hits size K.”
//
//“Each element enters and exits the window once, so it’s O(n).”
//
//⏱ Complexity (Always Mention)
//
//Time: O(n)
//
//Space: O(1) or O(26) for frequency array
//
//                           🎯 Final Takeaway
//
//                           If the problem says “exactly K”, your brain should instantly think:
//
//  Fixed sliding window → add → process → remove