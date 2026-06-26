object RecommendationPipeline {
  case class ViewHistory(userId: String, contentId: String, genre: String, rating: Double)

  case class ContentScore(contentId: String, avgRating: Double)

  private def likedGenres(userHistory: List[ViewHistory]): Set[String] =
    userHistory.filter(_.rating >= 4.0).map(_.genre).toSet

  private def watchedContent(userHistory: List[ViewHistory]): Set[String] =
    userHistory.map(_.contentId).toSet

  private def averageRating(views: List[ViewHistory]): Double =
    views.map(_.rating).sum / views.size

  private def rankCandidates(candidates: List[ViewHistory]): List[String] =
    candidates
      .groupBy(_.contentId)
      .map { case (contentId, views) => ContentScore(contentId, averageRating(views)) }
      .toList
      .sortBy(-_.avgRating)
      .map(_.contentId)
      .take(3)

  def recommend(userId: String, history: List[ViewHistory]): List[String] = {
    val userHistory = history.filter(_.userId == userId)
    if (userHistory.isEmpty) return List.empty

    val genres  = likedGenres(userHistory)
    val watched = watchedContent(userHistory)

    val candidates = history.filter { e =>
      genres.contains(e.genre) && !watched.contains(e.contentId)
    }

    rankCandidates(candidates)
  }

  def batchRecommend(history: List[ViewHistory]): Map[String, List[String]] =
    history
      .map(_.userId)
      .distinct
      .map(userId => userId -> recommend(userId, history))
      .toMap

  def main(args: Array[String]): Unit = {
    val history = List(
      ViewHistory("u1", "batman",      "action", 4.5),
      ViewHistory("u1", "superman",    "action", 4.2),
      ViewHistory("u1", "friends",     "comedy", 2.0),
      ViewHistory("u2", "batman",      "action", 3.8),
      ViewHistory("u2", "dune",        "action", 4.9),
      ViewHistory("u2", "succession",  "drama",  4.7),
      ViewHistory("u3", "dune",        "action", 4.1),
      ViewHistory("u3", "inception",   "action", 4.8),
      ViewHistory("u3", "interstellar","action", 4.6)
    )

    println("=== Single User ===")
    println(s"u1 -> ${recommend("u1", history)}")

    println("\n=== Batch ===")
    batchRecommend(history).foreach { case (u, recs) =>
      println(s"$u -> $recs")
    }
  }
}