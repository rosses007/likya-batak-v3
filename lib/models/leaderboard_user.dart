class LeaderboardUser {
  final String username;
  final int eloRating;
  final int totalWins;
  final int totalGames;

  LeaderboardUser({
    required this.username,
    required this.eloRating,
    required this.totalWins,
    required this.totalGames,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      username: json['username'] ?? 'Bilinmeyen',
      eloRating: json['elo_rating'] ?? 1000,
      totalWins: json['total_wins'] ?? 0,
      totalGames: json['total_games'] ?? 0,
    );
  }
}
