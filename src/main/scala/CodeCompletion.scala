object CodeCompletion {

  /**
   * Problem: Ad Break Optimizer
   * Warner Bros. Discovery's streaming platform inserts ad breaks into long-form content. The ad system receives a stream of content play sessions and must decide when to schedule ad breaks.
   * You are given:
   * scalacase class PlaySession(
   * userId: String,
   * contentId: String,
   * contentDurationSeconds: Int,  // total length of the content
   * watchedSeconds: Int           // how far the user has watched so far
   * )
   * And a set of ad break rules:
   *
   * Ad breaks are inserted at 25%, 50%, and 75% of content duration
   * A break is considered due if the user's watchedSeconds has crossed or hit that threshold
   * A break is considered already seen if the user has crossed the next threshold too
   * So a break is actionable only if it is due but not yet passed
   *
   * Write the following:
   * Function 1
   * scaladef actionableBreaks(session: PlaySession): List[Int]
   * Returns the list of percentage thresholds (e.g. List(25, 50)) where an ad break is actionable for this session.
   * Function 2
   * scaladef userBreakSummary(sessions: List[PlaySession]): Map[String, Map[String, List[Int]]]
   * Returns, for each userId → each contentId → list of actionable break percentages.
   * Function 3
   * scaladef mostMissedBreak(sessions: List[PlaySession]): Option[Int]
   * Returns the ad break threshold (25, 50, or 75) that has been skipped past (i.e. passed but not actionable) most frequently across all sessions. Returns None if no breaks have been skipped.
   *
   * Sample Input
   * scalaval sessions = List(
   * PlaySession("u1", "batman",  7200, 1900),  // 26% watched
   * PlaySession("u1", "dune",    9000, 4600),  // 51% watched
   * PlaySession("u2", "batman",  7200, 5500),  // 76% watched
   * PlaySession("u2", "inception",5400, 1200), // 22% watched
   * PlaySession("u3", "dune",    9000, 6800),  // 75% watched exactly
   * )
   * Expected Output
   * actionableBreaks:
   * u1/batman    -> List(25)         // crossed 25%, not yet at 50%
   * u1/dune      -> List(50)         // crossed 50%, not yet at 75%
   * u2/batman    -> List(75)         // crossed 75%, no threshold beyond
   * u2/inception -> List()           // hasn't crossed 25% yet
   * u3/dune      -> List(75)         // exactly at 75%
   *
   * userBreakSummary:
   * u1 -> { batman -> List(25), dune -> List(50) }
   * u2 -> { batman -> List(75), inception -> List() }
   * u3 -> { dune -> List(75) }
   *
   * mostMissedBreak:
   * Some(25)  // 25% has been skipped past most (u1/dune, u2/batman, u3/dune all passed it)
   */

  /**
   * 
   * @param userId
   * @param contentId
   * @param contentDurationSeconds
   * @param watchedSeconds
   */
  case class PlaySession(
                          userId: String,
                          contentId: String,
                          contentDurationSeconds: Int, // total length of the content
                          watchedSeconds: Int // how far the user has watched so far
                        )
  
  
  /**
   * 
   * @param session
   * @return
   */
  def actionableBreaks(session: PlaySession): List[Int] = {
    val watchTime = session.watchedSeconds
    val contentDuration = session.contentDurationSeconds
    val completionPercent = watchTime*100.0/contentDuration
    val resultSet = scala.collection.mutable.ListBuffer[Int]()
    completionPercent match {
      case value if value >= 25 && value < 50 =>  resultSet.addOne(25)
      case value if value >= 50 && value < 50 =>  resultSet.addOne(50)
      case value if value >= 75 && value < 50 =>  resultSet.addOne(75)
    }
    resultSet.toList
  }

}
