import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/player_model.dart';
import '../models/leaderboard_user.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.bataknoir.com');

  /// Skorları backend'e gönderir
  static Future<void> saveMatchScore({
    required bool isMultiplayer,
    required List<Player> players,
    required int winnerIndex,
  }) async {
    final url = Uri.parse('$baseUrl/matches/score');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_multiplayer': isMultiplayer,
          'winner_name': players[winnerIndex].name,
          'players': players.map((p) => {'name': p.name, 'tricks': p.tricksWon}).toList(),
        }),
      );
    } catch (_) {}
  }

  /// Retrieves the leaderboard (top players) from the backend.
  static Future<List<LeaderboardUser>> getLeaderboard() async {
    final url = Uri.parse('$baseUrl/leaderboard?limit=10');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LeaderboardUser.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }
}
